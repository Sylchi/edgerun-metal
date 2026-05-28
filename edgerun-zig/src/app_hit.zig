const std = @import("std");
const ui = @import("ui.zig");

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

pub const RouteHit = union(enum) {
    top_level: u32,
    path: []const u8,
};

pub const ActionHit = union(enum) {
    source_compile,
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
    route: ?RouteHit = null,
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
        const key = std.fmt.bufPrint(&buf, "{}", .{index}) catch unreachable;
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

test "hit ids are deterministic and non-zero" {
    const source = scope("source");
    const a = source.id(.editor, "main");
    const b = source.id(.editor, "main");
    const c = source.indexed(.file, 7);
    try std.testing.expect(a != 0);
    try std.testing.expectEqual(a, b);
    try std.testing.expect(a != c);
}
