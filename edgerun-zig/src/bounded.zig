const std = @import("std");

pub fn FixedList(comptime T: type, comptime capacity: usize) type {
    if (capacity == 0) @compileError("FixedList capacity must be nonzero");

    return struct {
        const Self = @This();

        items: [capacity]T = undefined,
        len: usize = 0,

        pub fn append(self: *Self, value: T) bool {
            if (self.len == capacity) return false;
            self.items[self.len] = value;
            self.len += 1;
            return true;
        }

        pub fn slice(self: *const Self) []const T {
            return self.items[0..self.len];
        }

        pub fn mutableSlice(self: *Self) []T {
            return self.items[0..self.len];
        }

        pub fn full(self: Self) bool {
            return self.len == capacity;
        }

        pub fn empty(self: Self) bool {
            return self.len == 0;
        }

        pub fn capacityValue(_: Self) usize {
            return capacity;
        }
    };
}

pub fn SliceList(comptime T: type) type {
    return struct {
        const Self = @This();

        items: []T,
        len: usize = 0,

        pub fn from(items: []T) Self {
            return .{ .items = items };
        }

        pub fn init(items: []T) ?Self {
            if (items.len == 0) return null;
            return from(items);
        }

        pub fn append(self: *Self, value: T) bool {
            if (self.len == self.items.len) return false;
            self.items[self.len] = value;
            self.len += 1;
            return true;
        }

        pub fn at(self: Self, index: usize) ?T {
            if (index >= self.len) return null;
            return self.items[index];
        }

        pub fn slice(self: Self) []const T {
            return self.items[0..self.len];
        }

        pub fn mutableSlice(self: *Self) []T {
            return self.items[0..self.len];
        }

        pub fn atPtr(self: *Self, index: usize) ?*T {
            if (index >= self.len) return null;
            return &self.items[index];
        }

        pub fn clear(self: *Self) void {
            self.len = 0;
        }

        pub fn pop(self: *Self) ?T {
            if (self.len == 0) return null;
            self.len -= 1;
            return self.items[self.len];
        }

        pub fn full(self: Self) bool {
            return self.len == self.items.len;
        }
    };
}

test "fixed list appends without allocation" {
    var list = FixedList(u8, 2){};
    try std.testing.expect(list.empty());
    try std.testing.expect(list.append(7));
    try std.testing.expect(list.append(8));
    try std.testing.expect(!list.append(9));
    try std.testing.expect(list.full());
    try std.testing.expectEqualSlices(u8, &.{ 7, 8 }, list.slice());
}

test "slice list uses caller provided storage" {
    var storage: [2]u16 = undefined;
    var list = SliceList(u16).init(&storage).?;
    try std.testing.expect(list.append(11));
    try std.testing.expect(list.append(12));
    try std.testing.expect(!list.append(13));
    try std.testing.expect(list.full());
    try std.testing.expectEqual(@as(u16, 12), list.at(1).?);
}
