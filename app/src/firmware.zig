const std = @import("std");
const bytes = @import("bytes.zig");
const clock = @import("clock.zig");
const object = @import("object.zig");
const preimage = @import("preimage.zig");

pub const max_image_bytes = 2 * 1024 * 1024;
pub const max_blocks = 4096;

pub const ResolveObjectFn = *const fn (
    user: ?*anyopaque,
    object_id: [object.id_size]u8,
) ?[]const u8;

pub const Source = struct {
    vendor_id: u16,
    device_id: u16,
    instance: u8 = 0,

    pub fn valid(self: Source) bool {
        return self.vendor_id != 0 and self.vendor_id != 0xffff and
            self.device_id != 0 and self.device_id != 0xffff;
    }

    pub fn id(self: Source) ?[object.id_size]u8 {
        if (!self.valid()) return null;

        var raw: [8]u8 = [_]u8{0} ** 8;
        _ = bytes.store16(raw[0..2], self.vendor_id);
        _ = bytes.store16(raw[2..4], self.device_id);
        raw[4] = self.instance;
        return preimage.hash("edgerun:zig:v1:firmware-source", &raw);
    }

    pub fn owner(self: Source) ?object.Owner {
        return .{
            .kind = .device,
            .node_id = self.id() orelse return null,
        };
    }
};

pub const LoadedImage = struct {
    source: Source,
    image_id: [object.id_size]u8,
    bytes_len: usize,
    block_count: usize,

    pub fn valid(self: LoadedImage) bool {
        return self.source.valid() and bytes.nonzero(&self.image_id) and
            self.bytes_len != 0 and self.bytes_len <= max_image_bytes and
            self.block_count != 0 and self.block_count <= max_blocks;
    }
};

pub const Error = error{
    BadSource,
    BadManifest,
    BadBlock,
    MissingBlock,
    NoSpace,
};

pub fn imageRequirements() object.Requirements {
    return .{
        .durability = .durable,
        .confidentiality = .public,
        .portability = .public_portable,
        .integrity = .hash_only,
        .lifetime = .pinned,
        .visibility = .public,
        .access = .explicit_io,
    };
}

pub fn blockRequirements() object.Requirements {
    return .{
        .durability = .durable,
        .confidentiality = .public,
        .portability = .public_portable,
        .integrity = .hash_only,
        .lifetime = .pinned,
        .visibility = .public,
        .access = .explicit_io,
    };
}

pub fn blockChild(canonical_block: []const u8, logical_offset: u64) ?object.Child {
    const view = object.View.decode(canonical_block) catch return null;
    if (view.header.kind != .bytes or !bytes.eql(&view.header.requirements.hash(), &blockRequirements().hash())) return null;
    return object.Child.fromView(view, logical_offset) catch null;
}

pub fn writeImageManifest(
    source: Source,
    epoch: clock.Stamp,
    children: []const object.Child,
    out: []u8,
) ?[]u8 {
    if (!source.valid() or children.len == 0 or children.len > max_blocks) return null;
    const owner = source.owner() orelse return null;
    return (object.NodeWriter{ .out = out }).treeNodeOwned(
        imageRequirements(),
        epoch,
        &.{owner},
        &.{},
        children,
    ) catch return null;
}

pub fn loadImage(
    source: Source,
    manifest_canonical: []const u8,
    resolve_object: ResolveObjectFn,
    resolve_user: ?*anyopaque,
    out: []u8,
) Error!LoadedImage {
    if (!source.valid()) return error.BadSource;
    const manifest = object.View.decode(manifest_canonical) catch return error.BadManifest;
    if (manifest.header.kind != .tree or
        manifest.header.child_count == 0 or
        manifest.header.child_count > max_blocks or
        !bytes.eql(&manifest.header.requirements.hash(), &imageRequirements().hash()))
    {
        return error.BadManifest;
    }

    const owner = manifest.ownerAt(0) catch return error.BadManifest;
    const expected_owner = source.owner() orelse return error.BadSource;
    if (manifest.header.owner_count != 1 or owner.kind != .device or !bytes.eql(&owner.node_id, &expected_owner.node_id)) {
        return error.BadManifest;
    }

    const total_len = std.math.cast(usize, manifest.header.logical_len) orelse return error.BadManifest;
    if (total_len == 0 or total_len > max_image_bytes or out.len < total_len) return error.NoSpace;

    const block_req_hash = blockRequirements().hash();
    var child_index: usize = 0;
    var written: usize = 0;
    while (child_index < manifest.header.child_count) : (child_index += 1) {
        const child = manifest.childAt(child_index) catch return error.BadManifest;
        if (child.kind != .bytes or !bytes.eql(&child.requirements_hash, &block_req_hash)) return error.BadManifest;
        const block_canonical = resolve_object(resolve_user, child.object_id) orelse return error.MissingBlock;
        const block = object.View.decode(block_canonical) catch return error.BadBlock;
        if (block.header.kind != .bytes or
            !bytes.eql(&block.id(), &child.object_id) or
            !bytes.eql(&block.header.requirements.hash(), &block_req_hash) or
            block.body.len != child.logical_len or
            child.logical_offset != written)
        {
            return error.BadBlock;
        }
        const end = written + block.body.len;
        if (end > total_len) return error.BadBlock;
        @memcpy(out[written..end], block.body);
        written = end;
    }
    if (written != total_len) return error.BadManifest;

    const loaded = LoadedImage{
        .source = source,
        .image_id = manifest.id(),
        .bytes_len = written,
        .block_count = manifest.header.child_count,
    };
    if (!loaded.valid()) return error.BadManifest;
    return loaded;
}

const TestResolver = struct {
    first_id: [object.id_size]u8,
    first: []const u8,
    second_id: [object.id_size]u8,
    second: []const u8,
};

fn testResolve(user: ?*anyopaque, object_id: [object.id_size]u8) ?[]const u8 {
    const resolver: *const TestResolver = @ptrCast(@alignCast(user.?));
    if (bytes.eql(&object_id, &resolver.first_id)) return resolver.first;
    if (bytes.eql(&object_id, &resolver.second_id)) return resolver.second;
    return null;
}

test "loads vendor firmware image from canonical object blocks" {
    const keeper = clock.KeeperId{ .bytes = [_]u8{7} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const source = Source{ .vendor_id = 0x02d0, .device_id = 0xa9a6, .instance = 1 };

    var block0_raw: [object.header_size + 4]u8 = undefined;
    const block0 = try (object.NodeWriter{ .out = &block0_raw }).bytesNode(blockRequirements(), epoch, "firm");
    var block1_raw: [object.header_size + 4]u8 = undefined;
    const block1 = try (object.NodeWriter{ .out = &block1_raw }).bytesNode(blockRequirements(), epoch, "ware");

    const child0 = blockChild(block0, 0).?;
    const child1 = blockChild(block1, child0.logical_len).?;
    var manifest_raw: [object.header_size + object.owner_size + 2 * object.child_size]u8 = undefined;
    const manifest = writeImageManifest(source, epoch, &.{ child0, child1 }, &manifest_raw).?;

    const resolver = TestResolver{
        .first_id = child0.object_id,
        .first = block0,
        .second_id = child1.object_id,
        .second = block1,
    };
    var out: [16]u8 = undefined;
    const loaded = try loadImage(source, manifest, testResolve, @constCast(&resolver), &out);
    try std.testing.expect(loaded.valid());
    try std.testing.expectEqual(@as(usize, 8), loaded.bytes_len);
    try std.testing.expectEqual(@as(usize, 2), loaded.block_count);
    try std.testing.expectEqualStrings("firmware", out[0..loaded.bytes_len]);
}

test "rejects firmware manifest for the wrong vendor source" {
    const keeper = clock.KeeperId{ .bytes = [_]u8{8} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const source = Source{ .vendor_id = 0x1234, .device_id = 0x5678 };
    const other = Source{ .vendor_id = 0x1234, .device_id = 0x5679 };

    var block_raw: [object.header_size + 3]u8 = undefined;
    const block = try (object.NodeWriter{ .out = &block_raw }).bytesNode(blockRequirements(), epoch, "bin");
    const child = blockChild(block, 0).?;
    var manifest_raw: [object.header_size + object.owner_size + object.child_size]u8 = undefined;
    const manifest = writeImageManifest(source, epoch, &.{child}, &manifest_raw).?;

    const resolver = TestResolver{
        .first_id = child.object_id,
        .first = block,
        .second_id = [_]u8{0} ** object.id_size,
        .second = "",
    };
    var out: [8]u8 = undefined;
    try std.testing.expectError(error.BadManifest, loadImage(other, manifest, testResolve, @constCast(&resolver), &out));
}
