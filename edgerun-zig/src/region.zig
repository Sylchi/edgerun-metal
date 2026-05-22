const std = @import("std");

pub const Region = struct {
    base: []u8,

    pub fn len(self: Region) usize {
        return self.base.len;
    }

    pub fn split(self: *Region, size: usize) ?Region {
        if (size > self.base.len) return null;

        const child_start = self.base.len - size;
        const child = self.base[child_start..];
        self.base = self.base[0..child_start];
        return .{ .base = child };
    }

    pub fn takePrefix(self: *Region, size: usize) ?Region {
        if (size > self.base.len) return null;

        const child = self.base[0..size];
        self.base = self.base[size..];
        return .{ .base = child };
    }

    pub fn zero(self: Region) void {
        @memset(self.base, 0);
    }

    pub fn contains(self: Region, slice: []const u8) bool {
        if (slice.len == 0) return false;
        const start = @intFromPtr(self.base.ptr);
        const end = start + self.base.len;
        const slice_start = @intFromPtr(slice.ptr);
        const slice_end = slice_start + slice.len;
        return start <= slice_start and slice_end <= end;
    }

    pub fn offsetOf(self: Region, slice: []const u8) ?usize {
        if (!self.contains(slice)) return null;
        return @intFromPtr(slice.ptr) - @intFromPtr(self.base.ptr);
    }
};

test "split transfers ownership out of parent" {
    var memory: [16]u8 = undefined;
    var parent = Region{ .base = &memory };
    const child = parent.split(6).?;

    try std.testing.expectEqual(@as(usize, 10), parent.len());
    try std.testing.expectEqual(@as(usize, 6), child.len());
}

test "region reports contained slice offset" {
    var memory: [16]u8 = undefined;
    const region = Region{ .base = &memory };
    const slice = memory[4..12];

    try std.testing.expect(region.contains(slice));
    try std.testing.expectEqual(@as(usize, 4), region.offsetOf(slice).?);
    try std.testing.expect(!region.contains(&.{}));
}
