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
        const bounded_allocator = self.allocator();
        return bounded_allocator.alloc(T, count) catch null;
    }

    pub fn allocator(self: *BoundedArena) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    fn rawAlloc(ctx: *anyopaque, len: usize, alignment: std.mem.Alignment, _: usize) ?[*]u8 {
        const self: *BoundedArena = @ptrCast(@alignCast(ctx));
        const align_bytes = alignment.toByteUnits();
        const base_addr = @intFromPtr(self.region.base.ptr);
        const aligned_addr = std.mem.alignForward(usize, base_addr, align_bytes);
        const prefix = aligned_addr - base_addr;
        const total = prefix + len;
        const allocation = self.region.takePrefix(total) orelse return null;
        return allocation.base[prefix..].ptr;
    }

    fn rawResize(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) bool {
        return false;
    }

    fn rawRemap(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize, _: usize) ?[*]u8 {
        return null;
    }

    fn rawFree(_: *anyopaque, _: []u8, _: std.mem.Alignment, _: usize) void {}

    const vtable = std.mem.Allocator.VTable{
        .alloc = rawAlloc,
        .resize = rawResize,
        .remap = rawRemap,
        .free = rawFree,
    };
};

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

test "arena carves regions and typed slices from the same capability" {
    var memory: [128]u8 = undefined;
    var arena = BoundedArena.init(.{ .base = &memory });
    const region = arena.takeRegion(32).?;
    const slots = arena.allocSlice(u64, 4).?;

    try std.testing.expectEqual(@as(usize, 32), region.len());
    try std.testing.expectEqual(@as(usize, 4), slots.len);
    try std.testing.expect(arena.remaining() <= 64);
    try std.testing.expect(arena.owns(std.mem.sliceAsBytes(slots)));
    try std.testing.expectEqual(@as(usize, 0), arena.offsetOf(std.mem.sliceAsBytes(slots)).?);
}

test "region transfer seals earlier allocations out of shareable ownership" {
    var memory: [64]u8 = undefined;
    var arena = BoundedArena.init(.{ .base = &memory });
    const consumed = arena.allocSlice(u8, 8).?;

    _ = arena.takeRegion(8).?;
    try std.testing.expect(!arena.owns(consumed));
}
