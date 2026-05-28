const std = @import("std");
const common = @import("common.zig");
const ui = @import("../ui.zig");

pub const magic = "ERIMG001";
pub const abi_version: u16 = 1;
pub const header_size: usize = 40;
pub const tile_count_single: u32 = 1;
pub const default_tile_edge: usize = 256;

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

    pub fn tilesX(self: Header) common.DecodeError!usize {
        if (self.tile_w == 0) return error.BadImage;
        return divRoundUp(self.width, self.tile_w);
    }

    pub fn tilesY(self: Header) common.DecodeError!usize {
        if (self.tile_h == 0) return error.BadImage;
        return divRoundUp(self.height, self.tile_h);
    }

    pub fn validRgba(self: Header) bool {
        if (self.width == 0 or self.height == 0) return false;
        if (self.width > std.math.maxInt(u16) or self.height > std.math.maxInt(u16)) return false;
        if (self.tile_w == 0 or self.tile_h == 0) return false;
        if (self.tile_w > self.width or self.tile_h > self.height) return false;
        if (self.tile_w > std.math.maxInt(u16) or self.tile_h > std.math.maxInt(u16)) return false;
        if (self.format != .rgba8 or self.flags != 0) return false;
        const expected_tiles = tileCountFor(self.width, self.height, self.tile_w, self.tile_h) catch return false;
        if (self.tile_count != expected_tiles) return false;
        const expected_payload_len = rgbaPayloadLenForTiling(self.width, self.height, self.tile_w, self.tile_h) catch return false;
        return self.payload_len == expected_payload_len;
    }

    pub fn validSingleRgba(self: Header) bool {
        return self.tile_w == self.width and self.tile_h == self.height and self.tile_count == tile_count_single and self.validRgba();
    }
};

pub const TileBounds = struct {
    x: usize,
    y: usize,
    width: usize,
    height: usize,
};

pub const View = struct {
    header: Header,
    payload: []const u8,

    pub fn tileBounds(self: View, tile_index: usize) common.DecodeError!TileBounds {
        return tileBoundsFor(self.header, tile_index);
    }

    pub fn tilePayload(self: View, tile_index: usize) common.DecodeError![]const u8 {
        const bounds = try self.tileBounds(tile_index);
        const offset = try tilePayloadOffset(self.header, tile_index);
        const len = try common.checkedMul(try common.checkedMul(bounds.width, bounds.height), @sizeOf(ui.Color));
        if (offset > self.payload.len or len > self.payload.len - offset) return error.BadImage;
        return self.payload[offset..][0..len];
    }
};

pub fn tileCountFor(width: usize, height: usize, tile_w: usize, tile_h: usize) common.DecodeError!u32 {
    if (width == 0 or height == 0 or tile_w == 0 or tile_h == 0) return error.BadImage;
    const count = try common.checkedMul(divRoundUp(width, tile_w), divRoundUp(height, tile_h));
    if (count > std.math.maxInt(u32)) return error.PixelBudget;
    return @intCast(count);
}

pub fn rgbaPayloadLen(width: usize, height: usize) common.DecodeError!usize {
    return rgbaPayloadLenForTiling(width, height, width, height);
}

pub fn rgbaPayloadLenForTiling(width: usize, height: usize, tile_w: usize, tile_h: usize) common.DecodeError!usize {
    if (width == 0 or height == 0 or tile_w == 0 or tile_h == 0) return error.BadImage;
    var total: usize = 0;
    const count: usize = @intCast(try tileCountFor(width, height, tile_w, tile_h));
    var index: usize = 0;
    while (index < count) : (index += 1) {
        const bounds = try tileBoundsForValues(width, height, tile_w, tile_h, index);
        total = try common.checkedAdd(total, try common.checkedMul(try common.checkedMul(bounds.width, bounds.height), @sizeOf(ui.Color)));
    }
    return total;
}

pub fn rgbaCanonicalLen(width: usize, height: usize) common.DecodeError!usize {
    return rgbaCanonicalLenForTiling(width, height, width, height);
}

pub fn rgbaCanonicalLenForTiling(width: usize, height: usize, tile_w: usize, tile_h: usize) common.DecodeError!usize {
    return try common.checkedAdd(header_size, try rgbaPayloadLenForTiling(width, height, tile_w, tile_h));
}

pub fn encodeRgba(width: usize, height: usize, pixels: []const ui.Color, out: []u8) common.EncodeError![]u8 {
    return encodeRgbaTiled(width, height, width, height, pixels, out);
}

pub fn encodeRgbaTiled(width: usize, height: usize, tile_w: usize, tile_h: usize, pixels: []const ui.Color, out: []u8) common.EncodeError![]u8 {
    if (width == 0 or height == 0 or tile_w == 0 or tile_h == 0) return error.BadImage;
    if (width > std.math.maxInt(u16) or height > std.math.maxInt(u16)) return error.BadImage;
    if (tile_w > width or tile_h > height) return error.BadImage;
    if (tile_w > std.math.maxInt(u16) or tile_h > std.math.maxInt(u16)) return error.BadImage;
    const pixel_count = std.math.mul(usize, width, height) catch return error.OutputBudget;
    if (pixels.len < pixel_count) return error.BadImage;
    const payload_len = rgbaPayloadLenForTiling(width, height, tile_w, tile_h) catch return error.OutputBudget;
    const total = std.math.add(usize, header_size, payload_len) catch return error.OutputBudget;
    if (out.len < total) return error.OutputBudget;
    const tile_count = tileCountFor(width, height, tile_w, tile_h) catch return error.OutputBudget;

    @memset(out[0..header_size], 0);
    @memcpy(out[0..magic.len], magic);
    writeU16Le(out[8..10], abi_version);
    writeU16Le(out[10..12], @intFromEnum(Format.rgba8));
    writeU32Le(out[12..16], 0);
    writeU32Le(out[16..20], @intCast(width));
    writeU32Le(out[20..24], @intCast(height));
    writeU16Le(out[24..26], @intCast(tile_w));
    writeU16Le(out[26..28], @intCast(tile_h));
    writeU32Le(out[28..32], tile_count);
    writeU64Le(out[32..40], @intCast(payload_len));

    var cursor: usize = header_size;
    var tile_index: usize = 0;
    while (tile_index < tile_count) : (tile_index += 1) {
        const bounds = tileBoundsForValues(width, height, tile_w, tile_h, tile_index) catch return error.BadImage;
        var y: usize = 0;
        while (y < bounds.height) : (y += 1) {
            const source = pixels[(bounds.y + y) * width + bounds.x ..][0..bounds.width];
            const source_bytes = std.mem.sliceAsBytes(source);
            @memcpy(out[cursor..][0..source_bytes.len], source_bytes);
            cursor += source_bytes.len;
        }
    }
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
    if (!header.validRgba()) return error.BadImage;
    if (canonical.len != header_size + header.payload_len) return error.BadImage;
    return .{ .header = header, .payload = canonical[header_size..] };
}

pub fn decodeRgbaInto(canonical: []const u8, out: []ui.Color) common.DecodeError!Header {
    const view = try decode(canonical);
    const pixel_count = try view.header.pixelCount();
    if (out.len < pixel_count) return error.PixelBudget;
    var tile_index: usize = 0;
    while (tile_index < view.header.tile_count) : (tile_index += 1) {
        const bounds = try view.tileBounds(tile_index);
        const payload = try view.tilePayload(tile_index);
        var cursor: usize = 0;
        var y: usize = 0;
        while (y < bounds.height) : (y += 1) {
            const row_bytes_len = bounds.width * @sizeOf(ui.Color);
            const row_bytes = payload[cursor..][0..row_bytes_len];
            const dest = out[(bounds.y + y) * view.header.width + bounds.x ..][0..bounds.width];
            @memcpy(std.mem.sliceAsBytes(dest), row_bytes);
            cursor += row_bytes_len;
        }
    }
    return view.header;
}

pub fn tileBoundsFor(header: Header, tile_index: usize) common.DecodeError!TileBounds {
    return tileBoundsForValues(header.width, header.height, header.tile_w, header.tile_h, tile_index);
}

fn tileBoundsForValues(width: usize, height: usize, tile_w: usize, tile_h: usize, tile_index: usize) common.DecodeError!TileBounds {
    if (width == 0 or height == 0 or tile_w == 0 or tile_h == 0) return error.BadImage;
    const tiles_x = divRoundUp(width, tile_w);
    const tiles_y = divRoundUp(height, tile_h);
    const count = try common.checkedMul(tiles_x, tiles_y);
    if (tile_index >= count) return error.BadImage;
    const tile_x = tile_index % tiles_x;
    const tile_y = tile_index / tiles_x;
    const x = tile_x * tile_w;
    const y = tile_y * tile_h;
    return .{
        .x = x,
        .y = y,
        .width = @min(tile_w, width - x),
        .height = @min(tile_h, height - y),
    };
}

fn tilePayloadOffset(header: Header, tile_index: usize) common.DecodeError!usize {
    var offset: usize = 0;
    var index: usize = 0;
    while (index < tile_index) : (index += 1) {
        const bounds = try tileBoundsFor(header, index);
        offset = try common.checkedAdd(offset, try common.checkedMul(try common.checkedMul(bounds.width, bounds.height), @sizeOf(ui.Color)));
    }
    return offset;
}

fn divRoundUp(numerator: usize, denominator: usize) usize {
    return (numerator + denominator - 1) / denominator;
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
    try testing.expect(decoded.validSingleRgba());
    try testing.expectEqualSlices(ui.Color, &pixels, &decoded_pixels);
}

test "runtime image encodes tiled rgba in canonical tile order" {
    const pixels = [_]ui.Color{
        .{ .r = 1, .g = 0, .b = 0, .a = 255 },
        .{ .r = 2, .g = 0, .b = 0, .a = 255 },
        .{ .r = 3, .g = 0, .b = 0, .a = 255 },
        .{ .r = 4, .g = 0, .b = 0, .a = 255 },
        .{ .r = 5, .g = 0, .b = 0, .a = 255 },
        .{ .r = 6, .g = 0, .b = 0, .a = 255 },
    };
    var canonical: [header_size + pixels.len * @sizeOf(ui.Color)]u8 = undefined;
    const encoded = try encodeRgbaTiled(3, 2, 2, 1, &pixels, &canonical);
    const view = try decode(encoded);
    try std.testing.expectEqual(@as(u32, 4), view.header.tile_count);
    try std.testing.expectEqual(@as(usize, 2), view.header.tile_w);
    try std.testing.expectEqual(@as(usize, 1), view.header.tile_h);

    var decoded_pixels: [pixels.len]ui.Color = undefined;
    _ = try decodeRgbaInto(encoded, &decoded_pixels);
    try std.testing.expectEqualSlices(ui.Color, &pixels, &decoded_pixels);

    const last = try view.tileBounds(3);
    try std.testing.expectEqual(@as(usize, 2), last.x);
    try std.testing.expectEqual(@as(usize, 1), last.y);
    try std.testing.expectEqual(@as(usize, 1), last.width);
    try std.testing.expectEqual(@as(usize, 1), last.height);
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
