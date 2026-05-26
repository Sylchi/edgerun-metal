const std = @import("std");

pub const Error = error{
    TextEditOverflow,
    InvalidCursor,
    InvalidTextInput,
};

pub const Key = enum {
    left,
    right,
    home,
    end,
    backspace,
    delete_forward,
};

pub const Buffer = struct {
    bytes: []u8,
    len: usize = 0,
    cursor: usize = 0,

    pub fn init(bytes: []u8) Buffer {
        return .{ .bytes = bytes };
    }

    pub fn set(self: *Buffer, value: []const u8) Error!void {
        try validatePrintable(value);
        if (value.len > self.bytes.len) return error.TextEditOverflow;
        @memcpy(self.bytes[0..value.len], value);
        self.len = value.len;
        self.cursor = value.len;
    }

    pub fn written(self: Buffer) []const u8 {
        return self.bytes[0..self.len];
    }

    pub fn insert(self: *Buffer, value: []const u8) Error!void {
        try self.validateCursor();
        try validatePrintable(value);
        if (value.len > self.bytes.len - self.len) return error.TextEditOverflow;
        std.mem.copyBackwards(u8, self.bytes[self.cursor + value.len .. self.len + value.len], self.bytes[self.cursor..self.len]);
        @memcpy(self.bytes[self.cursor..][0..value.len], value);
        self.cursor += value.len;
        self.len += value.len;
    }

    pub fn backspace(self: *Buffer) Error!void {
        try self.validateCursor();
        if (self.cursor == 0) return;
        std.mem.copyForwards(u8, self.bytes[self.cursor - 1 .. self.len - 1], self.bytes[self.cursor..self.len]);
        self.cursor -= 1;
        self.len -= 1;
    }

    pub fn deleteForward(self: *Buffer) Error!void {
        try self.validateCursor();
        if (self.cursor == self.len) return;
        std.mem.copyForwards(u8, self.bytes[self.cursor .. self.len - 1], self.bytes[self.cursor + 1 .. self.len]);
        self.len -= 1;
    }

    pub fn move(self: *Buffer, key: Key) Error!void {
        try self.validateCursor();
        switch (key) {
            .left => {
                if (self.cursor > 0) self.cursor -= 1;
            },
            .right => {
                if (self.cursor < self.len) self.cursor += 1;
            },
            .home => self.cursor = 0,
            .end => self.cursor = self.len,
            .backspace => try self.backspace(),
            .delete_forward => try self.deleteForward(),
        }
    }

    fn validateCursor(self: Buffer) Error!void {
        if (self.cursor > self.len or self.len > self.bytes.len) return error.InvalidCursor;
    }
};

pub fn validatePrintable(value: []const u8) Error!void {
    for (value) |byte| {
        if (byte < 0x20 or byte > 0x7e) return error.InvalidTextInput;
    }
}

test "text edit buffer inserts at cursor and preserves deterministic bytes" {
    var raw: [16]u8 = undefined;
    var buffer = Buffer.init(&raw);
    try buffer.set("EdgeRun");
    buffer.cursor = 4;
    try buffer.insert("-");

    try std.testing.expectEqualStrings("Edge-Run", buffer.written());
    try std.testing.expectEqual(@as(usize, 5), buffer.cursor);
}

test "text edit buffer handles backspace delete and cursor keys" {
    var raw: [16]u8 = undefined;
    var buffer = Buffer.init(&raw);
    try buffer.set("abc");
    try buffer.move(.left);
    try buffer.backspace();
    try std.testing.expectEqualStrings("ac", buffer.written());
    try std.testing.expectEqual(@as(usize, 1), buffer.cursor);

    try buffer.deleteForward();
    try std.testing.expectEqualStrings("a", buffer.written());
    try buffer.move(.home);
    try std.testing.expectEqual(@as(usize, 0), buffer.cursor);
    try buffer.move(.end);
    try std.testing.expectEqual(buffer.len, buffer.cursor);
}

test "text edit buffer rejects overflow invalid cursor and control bytes" {
    var raw: [4]u8 = undefined;
    var buffer = Buffer.init(&raw);
    try std.testing.expectError(error.InvalidTextInput, buffer.set("bad\n"));
    try buffer.set("abcd");
    try std.testing.expectError(error.TextEditOverflow, buffer.insert("e"));
    buffer.cursor = 8;
    try std.testing.expectError(error.InvalidCursor, buffer.insert("x"));
}
