const std = @import("std");

pub const Header = struct {
    width: usize,
    height: usize,
};

pub const DecodeError = error{
    BadImage,
    UnsupportedImage,
    PixelBudget,
};

pub const EncodeError = error{
    BadImage,
    OutputBudget,
};

pub const alpha_opaque: u8 = 255;

const ascii_upper_a: u8 = 'A';
const ascii_upper_z: u8 = 'Z';
const ascii_lower_a: u8 = 'a';
const ascii_lower_z: u8 = 'z';

pub fn checkedAdd(a: usize, b: usize) DecodeError!usize {
    return std.math.add(usize, a, b) catch error.PixelBudget;
}

pub fn checkedMul(a: usize, b: usize) DecodeError!usize {
    return std.math.mul(usize, a, b) catch error.PixelBudget;
}

pub fn pixelCount(header: Header) DecodeError!usize {
    if (header.width > ~@as(usize, 0) / header.height) return error.PixelBudget;
    return header.width * header.height;
}

pub fn divRoundUp(numerator: usize, denominator: usize) usize {
    return (numerator + denominator - 1) / denominator;
}

pub fn clampU8(value: i32) u8 {
    if (value < 0) return 0;
    if (value > 255) return 255;
    return @intCast(value);
}

pub fn isAsciiLetter(byte: u8) bool {
    return (byte >= ascii_upper_a and byte <= ascii_upper_z) or
        (byte >= ascii_lower_a and byte <= ascii_lower_z);
}

pub fn isAsciiUpper(byte: u8) bool {
    return byte >= ascii_upper_a and byte <= ascii_upper_z;
}

pub fn readU16(bytes: *const [2]u8) u16 {
    return (@as(u16, bytes[0]) << 8) | @as(u16, bytes[1]);
}

pub fn readU16Le(bytes: *const [2]u8) u16 {
    return @as(u16, bytes[0]) | (@as(u16, bytes[1]) << 8);
}

pub fn readU24Le(bytes: *const [3]u8) u32 {
    return @as(u32, bytes[0]) |
        (@as(u32, bytes[1]) << 8) |
        (@as(u32, bytes[2]) << 16);
}

pub fn readU32Le(bytes: *const [4]u8) u32 {
    return @as(u32, bytes[0]) |
        (@as(u32, bytes[1]) << 8) |
        (@as(u32, bytes[2]) << 16) |
        (@as(u32, bytes[3]) << 24);
}

pub fn readU64Le(bytes: *const [8]u8) u64 {
    return @as(u64, bytes[0]) |
        (@as(u64, bytes[1]) << 8) |
        (@as(u64, bytes[2]) << 16) |
        (@as(u64, bytes[3]) << 24) |
        (@as(u64, bytes[4]) << 32) |
        (@as(u64, bytes[5]) << 40) |
        (@as(u64, bytes[6]) << 48) |
        (@as(u64, bytes[7]) << 56);
}

pub fn readU32Be(bytes: *const [4]u8) u32 {
    return (@as(u32, bytes[0]) << 24) |
        (@as(u32, bytes[1]) << 16) |
        (@as(u32, bytes[2]) << 8) |
        @as(u32, bytes[3]);
}

pub fn writeU32Be(bytes: *[4]u8, value: u32) void {
    bytes[0] = @intCast((value >> 24) & 0xff);
    bytes[1] = @intCast((value >> 16) & 0xff);
    bytes[2] = @intCast((value >> 8) & 0xff);
    bytes[3] = @intCast(value & 0xff);
}

pub fn writeU32Le(bytes: *[4]u8, value: usize) void {
    bytes[0] = @intCast(value & 0xff);
    bytes[1] = @intCast((value >> 8) & 0xff);
    bytes[2] = @intCast((value >> 16) & 0xff);
    bytes[3] = @intCast((value >> 24) & 0xff);
}

pub fn writeU24Le(bytes: *[3]u8, value: usize) void {
    bytes[0] = @intCast(value & 0xff);
    bytes[1] = @intCast((value >> 8) & 0xff);
    bytes[2] = @intCast((value >> 16) & 0xff);
}

pub fn writeU16(bytes: *[2]u8, value: usize) void {
    std.debug.assert(value <= 0xFFFF);
    bytes[0] = @intCast(value & 0xff);
    bytes[1] = @intCast((value >> 8) & 0xff);
}
