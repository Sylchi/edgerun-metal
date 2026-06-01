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
    if (!list.empty()) return error.TestExpectedTrue;
    if (!list.append(7)) return error.TestExpectedTrue;
    if (!list.append(8)) return error.TestExpectedTrue;
    if (list.append(9)) return error.TestExpectedFalse;
    if (!list.full()) return error.TestExpectedTrue;
    if (!equalSlices(u8, &.{ 7, 8 }, list.slice())) return error.TestExpectedEqual;
}

test "slice list uses caller provided storage" {
    var storage: [2]u16 = undefined;
    var list = SliceList(u16).init(&storage).?;
    if (!list.append(11)) return error.TestExpectedTrue;
    if (!list.append(12)) return error.TestExpectedTrue;
    if (list.append(13)) return error.TestExpectedFalse;
    if (!list.full()) return error.TestExpectedTrue;
    if (list.at(1).? != 12) return error.TestExpectedEqual;
}

fn equalSlices(comptime T: type, expected: []const T, actual: []const T) bool {
    if (expected.len != actual.len) return false;
    for (expected, actual) |expected_item, actual_item| {
        if (expected_item != actual_item) return false;
    }
    return true;
}
