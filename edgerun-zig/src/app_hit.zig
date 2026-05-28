const std = @import("std");
const app_navigation = @import("app_navigation.zig");
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

pub const SourceHit = union(enum) {
    editor,
    search,
    file: usize,
};

pub const Hit = struct {
    kind: ui.HitKind,
    id: HitId,
    route: ?app_navigation.Route = null,
    action: ?app_navigation.Action = null,
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
    var hasher = std.hash.Wyhash.init(0x9d76_12aa_4f65_3b29);
    hasher.update("edgerun:ui-hit:v1");
    hasher.update(namespace);
    hasher.update(&.{0});
    hasher.update(role);
    hasher.update(&.{0});
    hasher.update(key);
    const value: u32 = @truncate(hasher.final());
    return if (value == 0) 1 else value;
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
