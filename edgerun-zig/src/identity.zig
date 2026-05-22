const std = @import("std");
const bytes = @import("bytes.zig");
const clock = @import("clock.zig");

pub const id_size = 32;
pub const material_max = 96;

pub const Kind = enum(u16) {
    user = 1,
    device = 2,
    app = 3,
    storage = 4,
    relay = 5,
    resource = 6,
    object = 7,
    ephemeral = 8,
    delegated = 9,
};

pub const SourceKind = enum(u16) {
    hash = 1,
    ed25519_public = 2,
    p256_public = 3,
    tpm_p256_public = 4,
    object_id = 5,
    endpoint = 6,
    derived = 7,
    delegation = 8,
    android_keystone_p256_public = 9,
};

pub const Id = struct {
    bytes: [id_size]u8,

    pub fn valid(self: Id) bool {
        return bytes.nonzero(&self.bytes);
    }

    pub fn eql(self: Id, other: Id) bool {
        return bytes.eql(&self.bytes, &other.bytes);
    }
};

pub const Source = struct {
    kind: SourceKind,
    material: [material_max]u8 = [_]u8{0} ** material_max,
    len: usize,

    pub fn init(kind: SourceKind, material: []const u8) ?Source {
        if (material.len == 0 or material.len > material_max) return null;
        if (!bytes.nonzero(material)) return null;

        var source = Source{ .kind = kind, .len = material.len };
        _ = bytes.copy(source.material[0..], material);
        return source;
    }

    pub fn active(self: Source) []const u8 {
        return self.material[0..self.len];
    }

    pub fn id(self: Source) Id {
        var hasher = std.crypto.hash.Blake3.init(.{});
        var header: [4]u8 = undefined;
        _ = bytes.store16(header[0..2], @intFromEnum(self.kind));
        _ = bytes.store16(header[2..4], @intCast(self.len));
        hasher.update("edgerun:zig:v1:identity-id");
        hasher.update(&header);
        hasher.update(self.active());

        var out: [id_size]u8 = undefined;
        hasher.final(&out);
        return .{ .bytes = out };
    }
};

pub const Identity = struct {
    kind: Kind,
    epoch: clock.Stamp,
    id: Id,
    source: Source,

    pub fn init(kind: Kind, source: Source, epoch: clock.Stamp) ?Identity {
        if (!epoch.valid()) return null;
        return .{
            .kind = kind,
            .epoch = epoch,
            .id = source.id(),
            .source = source,
        };
    }
};

test "source is explicit material with deterministic id" {
    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const source = Source.init(.hash, "app manifest").?;
    const a = Identity.init(.app, source, epoch).?;
    const b = Identity.init(.app, source, epoch).?;

    try std.testing.expect(a.id.eql(b.id));
}
