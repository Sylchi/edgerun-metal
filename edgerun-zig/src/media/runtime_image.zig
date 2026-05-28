const std = @import("std");
const common = @import("common.zig");
const ui = @import("../ui.zig");

pub const magic = "ERIMG001";
pub const abi_version: u16 = 1;
pub const header_size: usize = 40;
pub const tile_count_single: u32 = 1;

pub const Format = enum(u16) {
    rgba8 = 1,
};

pub const Header = struct {
    width: usize,
    height: usize,
    format: Format,
    flags: u32,
    tile_w: usize,
    tile_h: usize,
    tile_count: u32,
    payload_len: usize,

    pub fn pixelCount(self: Header) common.DecodeError!usize {
        return common.pixelCount(.{ .width = self.width, .height = self.height });
    }

    pub fn validSingleRgba(self: Header) bool {
        if (self.width == 0 or self.height == 0) return false;
        if (self.width > std.math.maxInt(u16) or self.height > std.math.maxInt(u16)) return false;
        if (self.format != .rgba8 or self.flags != 0) return false;
        if (self.tile_w != self.width or self.tile_h != self.height or self.tile_count != tile_count_single) return false;
        const pixel_count = std.math.mul(usize, self.width, self.height) catch return false;
        const expected_payload_len = std.math.mul(usize, pixel_count, @sizeOf(ui.Color)) catch return false;
        return self.payload_len == expected_payload_len;
    }
};

pub const View = struct {
    header: Header,
    payload: []const u8,
};

pub fn rgbaPayloadLen(width: usize, height: usize) common.DecodeError!usize {
    return try common.checkedMul(try common.checkedMul(width, height), @sizeOf(ui.Color));
}

pub fn rgbaCanonicalLen(width: usize, height: usize) common.DecodeError!usize {
    return try common.checkedAdd(header_size, try rgbaPayloadLen(width, height));
}

pub fn encodeRgba(width: usize, height: usize, pixels: []const ui.Color, out: []u8) common.EncodeError![]u8 {
    if (width == 0 or height == 0) return error.BadImage;
    if (width > std.math.maxInt(u16) or height > std.math.maxInt(u16)) return error.BadImage;
    if (width > std.math.maxInt(u32) or height > std.math.maxInt(u32)) return error.BadImage;
    const pixel_count = std.math.mul(usize, width, height) catch return error.OutputBudget;
    if (pixels.len < pixel_count) return error.BadImage;
    const payload_len = std.math.mul(usize, pixel_count, @sizeOf(ui.Color)) catch return error.OutputBudget;
    const total = std.math.add(usize, header_size, payload_len) catch return error.OutputBudget;
    if (out.len < total) return error.OutputBudget;

    @memset(out[0..header_size], 0);
    @memcpy(out[0..magic.len], magic);
    writeU16Le(out[8..10], abi_version);
    writeU16Le(out[10..12], @intFromEnum(Format.rgba8));
    writeU32Le(out[12..16], 0);
    writeU32Le(out[16..20], @intCast(width));
    writeU32Le(out[20..24], @intCast(height));
    writeU16Le(out[24..26], @intCast(width));
    writeU16Le(out[26..28], @intCast(height));
    writeU32Le(out[28..32], tile_count_single);
    writeU64Le(out[32..40], @intCast(payload_len));

    const pixel_bytes = std.mem.sliceAsBytes(pixels[0..pixel_count]);
    @memcpy(out[header_size..][0..payload_len], pixel_bytes);
    return out[0..total];
}

pub fn decode(canonical: []const u8) common.DecodeError!View {
    if (canonical.len < header_size) return error.BadImage;
    if (!std.mem.eql(u8, canonical[0..magic.len], magic)) return error.UnsupportedImage;
    if (readU16Le(canonical[8..10]) != abi_version) return error.UnsupportedImage;
    const format: Format = switch (readU16Le(canonical[10..12])) {
        @intFromEnum(Format.rgba8) => .rgba8,
        else => return error.UnsupportedImage,
    };
    const header = Header{
        .format = format,
        .flags = readU32Le(canonical[12..16]),
        .width = readU32Le(canonical[16..20]),
        .height = readU32Le(canonical[20..24]),
        .tile_w = readU16Le(canonical[24..26]),
        .tile_h = readU16Le(canonical[26..28]),
        .tile_count = readU32Le(canonical[28..32]),
        .payload_len = @intCast(readU64Le(canonical[32..40])),
    };
    if (!header.validSingleRgba()) return error.BadImage;
    if (canonical.len != header_size + header.payload_len) return error.BadImage;
    return .{ .header = header, .payload = canonical[header_size..] };
}

pub fn decodeRgbaInto(canonical: []const u8, out: []ui.Color) common.DecodeError!Header {
    const view = try decode(canonical);
    const pixel_count = try view.header.pixelCount();
    if (out.len < pixel_count) return error.PixelBudget;
    const out_bytes = std.mem.sliceAsBytes(out[0..pixel_count]);
    @memcpy(out_bytes, view.payload);
    return view.header;
}

fn writeU16Le(out: []u8, value: u16) void {
    out[0] = @intCast(value & 0xff);
    out[1] = @intCast((value >> 8) & 0xff);
}

fn writeU32Le(out: []u8, value: u32) void {
    out[0] = @intCast(value & 0xff);
    out[1] = @intCast((value >> 8) & 0xff);
    out[2] = @intCast((value >> 16) & 0xff);
    out[3] = @intCast((value >> 24) & 0xff);
}

fn writeU64Le(out: []u8, value: u64) void {
    out[0] = @intCast(value & 0xff);
    out[1] = @intCast((value >> 8) & 0xff);
    out[2] = @intCast((value >> 16) & 0xff);
    out[3] = @intCast((value >> 24) & 0xff);
    out[4] = @intCast((value >> 32) & 0xff);
    out[5] = @intCast((value >> 40) & 0xff);
    out[6] = @intCast((value >> 48) & 0xff);
    out[7] = @intCast((value >> 56) & 0xff);
}

fn readU16Le(in: []const u8) u16 {
    return @as(u16, in[0]) | (@as(u16, in[1]) << 8);
}

fn readU32Le(in: []const u8) u32 {
    return @as(u32, in[0]) |
        (@as(u32, in[1]) << 8) |
        (@as(u32, in[2]) << 16) |
        (@as(u32, in[3]) << 24);
}

fn readU64Le(in: []const u8) u64 {
    return @as(u64, in[0]) |
        (@as(u64, in[1]) << 8) |
        (@as(u64, in[2]) << 16) |
        (@as(u64, in[3]) << 24) |
        (@as(u64, in[4]) << 32) |
        (@as(u64, in[5]) << 40) |
        (@as(u64, in[6]) << 48) |
        (@as(u64, in[7]) << 56);
}

test "runtime image encodes deterministic single-tile rgba" {
    const testing = std.testing;
    const pixels = [_]ui.Color{
        .{ .r = 1, .g = 2, .b = 3, .a = 4 },
        .{ .r = 5, .g = 6, .b = 7, .a = 8 },
    };
    var canonical: [header_size + pixels.len * @sizeOf(ui.Color)]u8 = undefined;
    const encoded = try encodeRgba(2, 1, &pixels, &canonical);
    try testing.expectEqual(@as(usize, canonical.len), encoded.len);
    try testing.expectEqualStrings(magic, encoded[0..magic.len]);

    var decoded_pixels: [pixels.len]ui.Color = undefined;
    const decoded = try decodeRgbaInto(encoded, &decoded_pixels);
    try testing.expectEqual(@as(usize, 2), decoded.width);
    try testing.expectEqual(@as(usize, 1), decoded.height);
    try testing.expectEqualSlices(ui.Color, &pixels, &decoded_pixels);
}

test "runtime image rejects noncanonical trailing bytes" {
    const pixels = [_]ui.Color{.{ .r = 1, .g = 2, .b = 3, .a = 255 }};
    var canonical: [header_size + @sizeOf(ui.Color) + 1]u8 = undefined;
    const encoded = try encodeRgba(1, 1, &pixels, &canonical);
    try std.testing.expectError(error.BadImage, decode(canonical[0 .. encoded.len + 1]));
}

test "runtime image rejects oversized single-tile dimensions" {
    const pixels = [_]ui.Color{.{ .r = 1, .g = 2, .b = 3, .a = 255 }};
    var canonical: [header_size + @sizeOf(ui.Color)]u8 = undefined;
    try std.testing.expectError(error.BadImage, encodeRgba(std.math.maxInt(u16) + 1, 1, &pixels, &canonical));
}
