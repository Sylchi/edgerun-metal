const std = @import("std");
const bytes = @import("../bytes.zig");
const clock = @import("../clock.zig");
const object = @import("../object.zig");
const ui = @import("core.zig");

pub const HitId = u32;

pub const Role = enum {
    nav,
    action,
    input,
    textarea,
    row,
    file,
    editor,
    search,
};

pub const LocationHit = union(enum) {
    top_level: u32,
    path: []const u8,
};

pub const ActionHit = union(enum) {
    source_download,
    source_launch,
    source_reset,
    open_context_source,
    reveal_identity,
};

pub const SourceHit = union(enum) {
    editor,
    search,
    file: usize,
};

pub const Hit = struct {
    kind: ui.HitKind,
    id: HitId,
    location: ?LocationHit = null,
    action: ?ActionHit = null,
    source: ?SourceHit = null,
};

pub const Scope = struct {
    namespace: []const u8,

    pub fn init(namespace: []const u8) Scope {
        return .{ .namespace = namespace };
    }

    pub fn id(self: Scope, role: Role, key: []const u8) HitId {
        return stableHash32(self.namespace, @tagName(role), key);
    }

    pub fn indexed(self: Scope, role: Role, index: usize) HitId {
        var buf: [32]u8 = undefined;
        const key = std.fmt.bufPrint(&buf, "{}", .{index}) catch return self.id(role, "");
        return self.id(role, key);
    }
};

pub fn scope(namespace: []const u8) Scope {
    return Scope.init(namespace);
}

fn stableHash32(namespace: []const u8, role: []const u8, key: []const u8) HitId {
    var hash: u32 = 0x811c9dc5;
    hash = updateHash(hash, "edgerun:ui-hit:v1");
    hash = updateHash(hash, namespace);
    hash = updateHash(hash, &.{0});
    hash = updateHash(hash, role);
    hash = updateHash(hash, &.{0});
    hash = updateHash(hash, key);
    return if (hash == 0) 1 else hash;
}

fn updateHash(initial: u32, value: []const u8) u32 {
    var hash = initial;
    for (value) |byte| {
        hash ^= byte;
        hash *%= 0x01000193;
    }
    return hash;
}

const location_tag_none: u8 = 0;
const location_tag_top_level: u8 = 1;
const location_tag_path: u8 = 2;

const action_tag_none: u8 = 0;
const action_tag_source_download: u8 = 2;
const action_tag_source_launch: u8 = 3;
const action_tag_source_reset: u8 = 4;
const action_tag_open_context_source: u8 = 5;
const action_tag_reveal_identity: u8 = 6;

const source_tag_none: u8 = 0;
const source_tag_editor: u8 = 1;
const source_tag_search: u8 = 2;
const source_tag_file: u8 = 3;

pub fn requirements() object.Requirements {
    return .{
        .durability = .memory,
        .confidentiality = .public,
        .portability = .machine_bound,
        .integrity = .hash_only,
        .lifetime = .transient,
        .visibility = .private,
        .access = .hot_memory_allowed,
    };
}

pub fn writeBytes(out: []u8, hit: Hit) !usize {
    var offset: usize = 0;
    if (out.len < 8) return error.NoSpace;
    offset += writeU32(out, @intFromEnum(hit.kind));
    offset += writeU32(out[offset..], hit.id);

    // location
    if (hit.location) |location| {
        switch (location) {
            .top_level => |val| {
                out[offset] = location_tag_top_level;
                offset += 1;
                if (offset + 4 > out.len) return error.NoSpace;
                offset += writeU32(out[offset..], val);
            },
            .path => |val| {
                out[offset] = location_tag_path;
                offset += 1;
                if (offset + 4 + val.len > out.len) return error.NoSpace;
                offset += writeU32(out[offset..], @as(u32, @intCast(val.len)));
                @memcpy(out[offset..][0..val.len], val);
                offset += val.len;
            },
        }
    } else {
        if (offset + 1 > out.len) return error.NoSpace;
        out[offset] = location_tag_none;
        offset += 1;
    }

    // action
    if (hit.action) |action| {
        out[offset] = switch (action) {
            .source_download => action_tag_source_download,
            .source_launch => action_tag_source_launch,
            .source_reset => action_tag_source_reset,
            .open_context_source => action_tag_open_context_source,
            .reveal_identity => action_tag_reveal_identity,
        };
        offset += 1;
    } else {
        if (offset + 1 > out.len) return error.NoSpace;
        out[offset] = action_tag_none;
        offset += 1;
    }

    // source
    if (hit.source) |source| {
        switch (source) {
            .editor => {
                out[offset] = source_tag_editor;
                offset += 1;
            },
            .search => {
                out[offset] = source_tag_search;
                offset += 1;
            },
            .file => |val| {
                out[offset] = source_tag_file;
                offset += 1;
                if (offset + 4 > out.len) return error.NoSpace;
                offset += writeU32(out[offset..], @as(u32, @intCast(val)));
            },
        }
    } else {
        if (offset + 1 > out.len) return error.NoSpace;
        out[offset] = source_tag_none;
        offset += 1;
    }

    return offset;
}

pub fn parseBytes(in: []const u8) !Hit {
    var offset: usize = 0;
    if (in.len < 8) return error.Corrupt;
    const kind_val = try readU32(in, &offset);
    const kind = if (kind_val < @typeInfo(ui.HitKind).@"enum".fields.len)
        @as(ui.HitKind, @enumFromInt(@as(u8, @intCast(kind_val))))
    else
        return error.Corrupt;
    const id = try readU32(in, &offset);
    const location: ?LocationHit = location: {
        const tag = try readU8(in, &offset);
        break :location switch (tag) {
            location_tag_none => null,
            location_tag_top_level => .{ .top_level = try readU32(in, &offset) },
            location_tag_path => .{ .path = try readBytes(in, &offset) },
            else => return error.Corrupt,
        };
    };
    const action: ?ActionHit = action: {
        const tag = try readU8(in, &offset);
        break :action switch (tag) {
            action_tag_none => null,
            action_tag_source_download => .source_download,
            action_tag_source_launch => .source_launch,
            action_tag_source_reset => .source_reset,
            action_tag_open_context_source => .open_context_source,
            action_tag_reveal_identity => .reveal_identity,
            else => return error.Corrupt,
        };
    };
    const source: ?SourceHit = source: {
        const tag = try readU8(in, &offset);
        break :source switch (tag) {
            source_tag_none => null,
            source_tag_editor => .editor,
            source_tag_search => .search,
            source_tag_file => .{ .file = try readU32(in, &offset) },
            else => return error.Corrupt,
        };
    };
    if (offset != in.len) return error.Corrupt;
    return .{ .kind = kind, .id = id, .location = location, .action = action, .source = source };
}

pub fn encodeObject(hit: Hit, epoch: clock.Stamp, out: []u8) ![]u8 {
    var body_buf: [512]u8 = undefined;
    const body_len = try writeBytes(&body_buf, hit);
    return try (object.NodeWriter{ .out = out }).bytesNode(requirements(), epoch, body_buf[0..body_len]);
}

pub fn decodeObject(canonical: []const u8) !Hit {
    const view = try object.View.decode(canonical);
    if (view.header.kind != .bytes) return error.Corrupt;
    return try parseBytes(view.body);
}

fn readU8(in: []const u8, offset: *usize) !u8 {
    if (offset.* >= in.len) return error.Corrupt;
    defer offset.* += 1;
    return in[offset.*];
}

fn readU32(in: []const u8, offset: *usize) !u32 {
    if (offset.* + 4 > in.len) return error.Corrupt;
    const val = bytes.load32(in[offset.*..][0..4]) orelse return error.Corrupt;
    offset.* += 4;
    return val;
}

fn readBytes(in: []const u8, offset: *usize) ![]const u8 {
    const len = try readU32(in, offset);
    if (offset.* + len > in.len) return error.Corrupt;
    defer offset.* += len;
    return in[offset.*..][0..len];
}

fn writeU32(out: []u8, value: u32) usize {
    _ = bytes.store32(out[0..4], value);
    return 4;
}

test "hit serialization round trips all field combinations" {
    const epoch = clock.Stamp{ .keeper = .{ .bytes = [_]u8{0x69} ** 32 }, .tick = 1, .slot = 1, .epoch = 1, .era = 1 };
    var object_buf: [1024]u8 = undefined;

    const hits = [_]Hit{
        .{ .kind = .button, .id = 42 },
        .{ .kind = .input, .id = 7, .location = .{ .top_level = 3 }, .action = .source_download },
        .{ .kind = .checkbox, .id = 99, .location = .{ .path = "/apps/editor" }, .source = .{ .file = 12 } },
        .{ .kind = .slider, .id = 0, .action = .reveal_identity, .source = .editor },
    };

    for (&hits) |hit| {
        const canonical = try encodeObject(hit, epoch, &object_buf);
        const decoded = try decodeObject(canonical);
        try std.testing.expectEqual(hit.kind, decoded.kind);
        try std.testing.expectEqual(hit.id, decoded.id);
        if (hit.location) |r| {
            const d = decoded.location orelse return error.TestUnexpectedResult;
            switch (r) {
                .top_level => |v| try std.testing.expectEqual(v, d.top_level),
                .path => |p| try std.testing.expectEqualStrings(p, d.path),
            }
        } else try std.testing.expect(decoded.location == null);
        try std.testing.expectEqual(hit.action, decoded.action);
        if (hit.source) |s| {
            const d = decoded.source orelse return error.TestUnexpectedResult;
            switch (s) {
                .editor => try std.testing.expect(d == .editor),
                .search => try std.testing.expect(d == .search),
                .file => |v| try std.testing.expectEqual(v, d.file),
            }
        } else try std.testing.expect(decoded.source == null);
    }
}

test "hit decode object rejects non-bytes kind" {
    const epoch = clock.Stamp{ .keeper = .{ .bytes = [_]u8{0x69} ** 32 }, .tick = 1, .slot = 1, .epoch = 1, .era = 1 };
    var obj_buf: [512]u8 = undefined;
    const tree = try (object.NodeWriter{ .out = &obj_buf }).treeNode(requirements(), epoch, &.{});
    try std.testing.expectError(error.Corrupt, decodeObject(tree));
}

test "hit parse rejects truncated data" {
    var buf: [8]u8 = undefined;
    _ = bytes.store32(buf[0..4], @intFromEnum(ui.HitKind.button));
    _ = bytes.store32(buf[4..8], @as(u32, 1));
    try std.testing.expectError(error.Corrupt, parseBytes(buf[0..7]));
    try std.testing.expectError(error.Corrupt, parseBytes(buf[0..4]));
}

test "hit parse rejects trailing bytes" {
    var buf: [16]u8 = undefined;
    const hit = Hit{ .kind = .input, .id = 5 };
    const len = try writeBytes(&buf, hit);
    try std.testing.expectError(error.Corrupt, parseBytes(buf[0 .. len + 1]));
}

test "hit parse rejects unknown location tag" {
    var buf: [16]u8 = undefined;
    _ = bytes.store32(buf[0..4], @intFromEnum(ui.HitKind.button));
    _ = bytes.store32(buf[4..8], @as(u32, 1));
    buf[8] = 0xFF;
    try std.testing.expectError(error.Corrupt, parseBytes(&buf));
}

test "hit ids are deterministic and non-zero" {
    const source = scope("source");
    const a = source.id(.editor, "main");
    const b = source.id(.editor, "main");
    const c = source.indexed(.file, 7);
    try std.testing.expect(a != 0);
    try std.testing.expectEqual(a, b);
    try std.testing.expect(a != c);
}
