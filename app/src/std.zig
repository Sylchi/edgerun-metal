const zig = @import("std");

pub const ArrayList = zig.ArrayList;
pub const ArrayListUnmanaged = zig.ArrayListUnmanaged;
pub const DynLib = zig.DynLib;
pub const Io = zig.Io;
pub const atomic = zig.atomic;
pub const compress = zig.compress;
pub const crypto = zig.crypto;
pub const fs = zig.fs;
pub const hash = zig.hash;
pub const heap = zig.heap;
pub const os = zig.os;
pub const posix = zig.posix;
pub const process = zig.process;
pub const time = zig.time;

pub const ascii = struct {
    pub fn isDigit(value: u8) bool {
        return value >= '0' and value <= '9';
    }

    pub fn isAlphabetic(value: u8) bool {
        return (value >= 'a' and value <= 'z') or (value >= 'A' and value <= 'Z');
    }

    pub fn isAlphanumeric(value: u8) bool {
        return isAlphabetic(value) or isDigit(value);
    }

    pub fn toLower(value: u8) u8 {
        return if (value >= 'A' and value <= 'Z') value + ('a' - 'A') else value;
    }

    pub fn eqlIgnoreCase(a: []const u8, b: []const u8) bool {
        if (a.len != b.len) return false;
        for (a, b) |left, right| {
            if (toLower(left) != toLower(right)) return false;
        }
        return true;
    }
};

pub const debug = struct {
    pub fn assert(condition: bool) void {
        if (!condition) unreachable;
    }

    pub const print = zig.debug.print;
};

pub const fmt = struct {
    pub const format = zig.fmt.format;
    pub const parseInt = zig.fmt.parseInt;
    pub const parseUnsigned = zig.fmt.parseUnsigned;
    pub const bufPrint = zig.fmt.bufPrint;
    pub const bufPrintZ = zig.fmt.bufPrintZ;
    pub const bytesToHex = zig.fmt.bytesToHex;
    pub const parseFloat = zig.fmt.parseFloat;
};

pub const math = struct {
    pub fn add(comptime T: type, a: T, b: T) error{Overflow}!T {
        const result = @addWithOverflow(a, b);
        if (result[1] != 0) return error.Overflow;
        return result[0];
    }

    pub fn mul(comptime T: type, a: T, b: T) error{Overflow}!T {
        const result = @mulWithOverflow(a, b);
        if (result[1] != 0) return error.Overflow;
        return result[0];
    }

    pub fn clamp(value: anytype, low: @TypeOf(value), high: @TypeOf(value)) @TypeOf(value) {
        if (value < low) return low;
        if (value > high) return high;
        return value;
    }

    pub fn maxInt(comptime T: type) T {
        return switch (@typeInfo(T).int.signedness) {
            .signed => @intCast((@as(zig.meta.Int(.unsigned, @typeInfo(T).int.bits), 1) << (@typeInfo(T).int.bits - 1)) - 1),
            .unsigned => ~@as(T, 0),
        };
    }

    pub const pi: f32 = 3.14159265358979323846;
};

pub const mem = struct {
    pub const Allocator = zig.mem.Allocator;

    pub fn eql(comptime T: type, a: []const T, b: []const T) bool {
        if (a.len != b.len) return false;
        for (a, b) |left, right| {
            if (left != right) return false;
        }
        return true;
    }

    pub fn startsWith(comptime T: type, haystack: []const T, needle: []const T) bool {
        if (needle.len > haystack.len) return false;
        return eql(T, haystack[0..needle.len], needle);
    }

    pub fn endsWith(comptime T: type, haystack: []const T, needle: []const T) bool {
        if (needle.len > haystack.len) return false;
        return eql(T, haystack[haystack.len - needle.len ..], needle);
    }

    pub fn indexOf(comptime T: type, haystack: []const T, needle: []const T) ?usize {
        if (needle.len > haystack.len) return null;
        var index: usize = 0;
        while (index <= haystack.len - needle.len) : (index += 1) {
            if (eql(T, haystack[index..][0..needle.len], needle)) return index;
        }
        return null;
    }

    pub fn indexOfScalar(comptime T: type, haystack: []const T, needle: T) ?usize {
        for (haystack, 0..) |value, index| {
            if (value == needle) return index;
        }
        return null;
    }

    pub fn copyForwards(comptime T: type, dest: []T, source: []const T) void {
        var index: usize = 0;
        while (index < source.len) : (index += 1) dest[index] = source[index];
    }

    pub fn swap(comptime T: type, a: *T, b: *T) void {
        const tmp = a.*;
        a.* = b.*;
        b.* = tmp;
    }

    pub fn alignForward(comptime T: type, value: T, alignment: T) T {
        const mask = alignment - 1;
        return (value + mask) & ~mask;
    }

    pub fn readInt(comptime T: type, buffer: *const [@divExact(@typeInfo(T).int.bits, 8)]u8, endian: zig.builtin.Endian) T {
        return switch (endian) {
            .little => readIntLittle(T, buffer),
            .big => readIntBig(T, buffer),
        };
    }

    pub fn writeInt(comptime T: type, buffer: *[@divExact(@typeInfo(T).int.bits, 8)]u8, value: T, endian: zig.builtin.Endian) void {
        switch (endian) {
            .little => writeIntLittle(T, buffer, value),
            .big => writeIntBig(T, buffer, value),
        }
    }

    pub fn sliceAsBytes(slice: anytype) []const u8 {
        const Child = @TypeOf(slice[0]);
        return @as([*]const u8, @ptrCast(slice.ptr))[0 .. slice.len * @sizeOf(Child)];
    }

    pub const tokenizeAny = zig.mem.tokenizeAny;
    pub const splitScalar = zig.mem.splitScalar;
    pub const splitSequence = zig.mem.splitSequence;
    pub const trim = zig.mem.trim;
    pub const trimEnd = zig.mem.trimEnd;
    pub const lastIndexOfScalar = zig.mem.lastIndexOfScalar;

    fn readIntLittle(comptime T: type, buffer: *const [@divExact(@typeInfo(T).int.bits, 8)]u8) T {
        var out: T = 0;
        for (buffer, 0..) |byte, index| out |= @as(T, @intCast(byte)) << @intCast(index * 8);
        return out;
    }

    fn readIntBig(comptime T: type, buffer: *const [@divExact(@typeInfo(T).int.bits, 8)]u8) T {
        var out: T = 0;
        for (buffer) |byte| out = (out << 8) | @as(T, @intCast(byte));
        return out;
    }

    fn writeIntLittle(comptime T: type, buffer: *[@divExact(@typeInfo(T).int.bits, 8)]u8, value: T) void {
        for (buffer, 0..) |*byte, index| byte.* = @truncate(value >> @intCast(index * 8));
    }

    fn writeIntBig(comptime T: type, buffer: *[@divExact(@typeInfo(T).int.bits, 8)]u8, value: T) void {
        var remaining = value;
        var index = buffer.len;
        while (index > 0) {
            index -= 1;
            buffer[index] = @truncate(remaining);
            remaining >>= 8;
        }
    }
};

pub const meta = zig.meta;
pub const testing = zig.testing;

test "owned std byte and math helpers" {
    try testing.expect(mem.eql(u8, "edgerun", "edgerun"));
    try testing.expectEqual(@as(usize, 8), try math.mul(usize, 2, 4));
    try testing.expectEqual(@as(usize, 8), mem.alignForward(usize, 5, 4));
    try testing.expect(ascii.eqlIgnoreCase("ASM", "asm"));
}
