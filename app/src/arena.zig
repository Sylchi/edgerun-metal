const std = @import("std");
const Region = @import("region.zig").Region;

pub const BoundedArena = struct {
    region: Region,
    owned: Region,

    pub fn init(region: Region) BoundedArena {
        return .{
            .region = region,
            .owned = region,
        };
    }

    pub fn remaining(self: BoundedArena) usize {
        return self.region.len();
    }

    pub fn split(self: *BoundedArena, size: usize) ?BoundedArena {
        const child = self.region.split(size) orelse return null;
        const owned_start = @intFromPtr(self.owned.base.ptr);
        const child_start = @intFromPtr(child.base.ptr);
        if (child_start < owned_start) return null;
        self.owned.base = self.owned.base[0 .. child_start - owned_start];
        return .{
            .region = child,
            .owned = child,
        };
    }

    pub fn canReclaim(self: BoundedArena, child: BoundedArena) bool {
        return self.region.canAppendSuffix(child.owned) and self.owned.canAppendSuffix(child.owned);
    }

    pub fn reclaim(self: *BoundedArena, child: *BoundedArena) bool {
        if (!self.canReclaim(child.*)) return false;
        child.owned.zero();
        if (!self.region.appendSuffix(child.owned)) return false;
        if (!self.owned.appendSuffix(child.owned)) return false;
        child.region = .{ .base = child.region.base[0..0] };
        child.owned = .{ .base = child.owned.base[0..0] };
        return true;
    }

    pub fn takeRegion(self: *BoundedArena, size: usize) ?Region {
        const child = self.region.takePrefix(size) orelse return null;
        self.owned = self.region;
        return child;
    }

    pub fn owns(self: BoundedArena, slice: []const u8) bool {
        return self.owned.contains(slice);
    }

    pub fn offsetOf(self: BoundedArena, slice: []const u8) ?usize {
        return self.owned.offsetOf(slice);
    }

    pub fn allocSlice(self: *BoundedArena, comptime T: type, count: usize) ?[]T {
        if (count == 0) return null;
        const align_bytes = @max(@alignOf(T), 1);
        const base_addr = @intFromPtr(self.region.base.ptr);
        const aligned_addr = alignForward(base_addr, align_bytes);
        const prefix = aligned_addr - base_addr;
        const byte_len = @sizeOf(T) * count;
        const allocation = self.region.takePrefix(prefix + byte_len) orelse return null;
        const bytes = allocation.base[prefix..][0..byte_len];
        const aligned: []align(@alignOf(T)) u8 = @alignCast(bytes);
        return @as([*]T, @ptrCast(aligned.ptr))[0..count];
    }

    pub fn allocator(self: *BoundedArena) BoundedAllocator {
        return .{ .arena = self };
    }
};

pub const BoundedAllocator = struct {
    arena: *BoundedArena,

    pub fn alloc(self: BoundedAllocator, comptime T: type, count: usize) error{OutOfMemory}![]T {
        return self.arena.allocSlice(T, count) orelse error.OutOfMemory;
    }
};

fn alignForward(value: usize, alignment: usize) usize {
    const mask = alignment - 1;
    return (value + mask) & ~mask;
}

test "allocator cannot leave bounded region" {
    var memory: [32]u8 = undefined;
    var arena = BoundedArena.init(.{ .base = &memory });
    const allocator = arena.allocator();

    const first = try allocator.alloc(u8, 20);
    try std.testing.expectEqual(@as(usize, 20), first.len);
    try std.testing.expect(arena.remaining() <= 12);

    try std.testing.expectError(error.OutOfMemory, allocator.alloc(u8, 64));
}

test "parent can delegate child arena by splitting capability" {
    var memory: [64]u8 = undefined;
    var parent = BoundedArena.init(.{ .base = &memory });
    var child = parent.split(24).?;

    try std.testing.expectEqual(@as(usize, 40), parent.remaining());
    try std.testing.expectEqual(@as(usize, 24), child.remaining());

    const child_allocator = child.allocator();
    _ = try child_allocator.alloc(u8, 16);
    try std.testing.expectEqual(@as(usize, 40), parent.remaining());
    try std.testing.expect(child.remaining() <= 8);
    try std.testing.expect(!parent.owns(child.region.base));
}

test "parent reclaims delegated arena after child exit" {
    var memory: [64]u8 = [_]u8{7} ** 64;
    var parent = BoundedArena.init(.{ .base = &memory });
    var child = parent.split(24).?;

    const child_allocator = child.allocator();
    const private = try child_allocator.alloc(u8, 8);
    @memset(private, 3);

    try std.testing.expectEqual(@as(usize, 40), parent.remaining());
    try std.testing.expect(parent.reclaim(&child));
    try std.testing.expectEqual(@as(usize, 64), parent.remaining());
    try std.testing.expectEqual(@as(usize, 0), child.remaining());
    try std.testing.expectEqual(@as(u8, 0), memory[40]);
}

test "arena carves regions and typed slices from the same capability" {
    var memory: [128]u8 = undefined;
    var arena = BoundedArena.init(.{ .base = &memory });
    const region = arena.takeRegion(32).?;
    const slots = arena.allocSlice(u64, 4).?;

    try std.testing.expectEqual(@as(usize, 32), region.len());
    try std.testing.expectEqual(@as(usize, 4), slots.len);
    try std.testing.expect(arena.remaining() <= 64);
    try std.testing.expect(arena.owns(sliceAsBytes(u64, slots)));
    try std.testing.expectEqual(@as(usize, 0), arena.offsetOf(sliceAsBytes(u64, slots)).?);
}

fn sliceAsBytes(comptime T: type, value: []const T) []const u8 {
    return @as([*]const u8, @ptrCast(value.ptr))[0 .. value.len * @sizeOf(T)];
}

test "region transfer seals earlier allocations out of shareable ownership" {
    var memory: [64]u8 = undefined;
    var arena = BoundedArena.init(.{ .base = &memory });
    const consumed = arena.allocSlice(u8, 8).?;

    _ = arena.takeRegion(8).?;
    try std.testing.expect(!arena.owns(consumed));
}
