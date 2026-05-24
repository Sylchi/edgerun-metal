const clock = @import("../../clock.zig");
const object = @import("../../object.zig");

pub fn req() object.Requirements {
    return .{
        .durability = .memory,
        .confidentiality = .public,
        .portability = .public_portable,
        .integrity = .hash_only,
        .lifetime = .transient,
        .visibility = .public,
        .access = .hot_memory_allowed,
    };
}

pub fn epoch() clock.Stamp {
    return .{ .keeper = .{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 } };
}
