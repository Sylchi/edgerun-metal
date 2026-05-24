const std = @import("std");
const image_jpeg = @import("image_jpeg.zig");
const ui = @import("ui.zig");

pub const Header = struct {
    width: usize,
    height: usize,
};

pub const Format = enum {
    jpeg,
    png,
    tga,
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

const tga_header_size: usize = 18;
const tga_footer_size: usize = 26;
const tga_type_true_color: u8 = 2;
const tga_origin_top: u8 = 1 << 5;
const tga_alpha_bits: u8 = 8;
const tga_depth_rgb: u8 = 24;
const tga_depth_rgba: u8 = 32;
const tga_descriptor_rgba_top_left: u8 = tga_origin_top | tga_alpha_bits;
const tga_signature = "TRUEVISION-XFILE.\x00";

const header_id_len_index: usize = 0;
const header_color_map_type_index: usize = 1;
const header_image_type_index: usize = 2;
const header_width_index: usize = 12;
const header_height_index: usize = 14;
const header_depth_index: usize = 16;
const header_descriptor_index: usize = 17;

const png_signature = "\x89PNG\r\n\x1a\n";
const png_length_size: usize = 4;
const png_type_size: usize = 4;
const png_crc_size: usize = 4;
const png_chunk_header_size: usize = png_length_size + png_type_size;
const png_chunk_overhead: usize = png_chunk_header_size + png_crc_size;
const png_ihdr_data_size: usize = 13;
const png_width_index: usize = 0;
const png_height_index: usize = 4;
const png_bit_depth_index: usize = 8;
const png_color_type_index: usize = 9;
const png_compression_index: usize = 10;
const png_filter_index: usize = 11;
const png_interlace_index: usize = 12;
const png_bit_depth_u8: u8 = 8;
const png_color_rgb: u8 = 2;
const png_color_rgba: u8 = 6;
const png_method_deflate: u8 = 0;
const png_filter_standard: u8 = 0;
const png_interlace_none: u8 = 0;
const png_filter_none: u8 = 0;
const png_filter_sub: u8 = 1;
const png_filter_up: u8 = 2;
const png_filter_average: u8 = 3;
const png_filter_paeth: u8 = 4;
const png_alpha_opaque: u8 = 255;
const png_chunk_ihdr = "IHDR";
const png_chunk_idat = "IDAT";
const png_chunk_iend = "IEND";
const png_rgba_channels: usize = 4;

pub fn detectFormat(bytes: []const u8) DecodeError!Format {
    if (image_jpeg.isJpeg(bytes)) return .jpeg;
    if (isPng(bytes)) return .png;
    if (isTga(bytes)) return .tga;
    return error.UnsupportedImage;
}

pub fn decodeHeader(bytes: []const u8) DecodeError!Header {
    return switch (try detectFormat(bytes)) {
        .jpeg => image_jpeg.decodeHeader(bytes),
        .png => decodePngHeader(bytes),
        .tga => decodeTgaHeader(bytes),
    };
}

pub fn decode(bytes: []const u8, out: []ui.Color) DecodeError!Header {
    return decodeWithScratch(bytes, out, &.{});
}

pub fn decodeWithScratch(bytes: []const u8, out: []ui.Color, scratch: []u8) DecodeError!Header {
    return switch (try detectFormat(bytes)) {
        .jpeg => image_jpeg.decode(bytes, out),
        .png => decodePng(bytes, out, scratch),
        .tga => decodeTga(bytes, out),
    };
}

pub fn pngScratchByteLen(encoded_len: usize, width: usize, height: usize) usize {
    return encoded_len + height * (1 + width * png_rgba_channels) + std.compress.flate.max_window_len;
}

pub fn decodePngHeader(bytes: []const u8) DecodeError!Header {
    return (try parsePng(bytes, null)).header;
}

fn isPng(bytes: []const u8) bool {
    return bytes.len >= png_signature.len and std.mem.eql(u8, bytes[0..png_signature.len], png_signature);
}

pub fn decodePng(bytes: []const u8, out: []ui.Color, scratch: []u8) DecodeError!Header {
    const info = try parsePng(bytes, scratch);
    const count = try pixelCount(info.header);
    if (out.len < count) return error.PixelBudget;
    const channels = try pngChannels(info.color_type);
    const decoded_len = try pngDecodedByteLen(info.header, channels);
    const idat_len = info.idat_total;
    const window_len = std.compress.flate.max_window_len;
    if (scratch.len < idat_len + decoded_len + window_len) return error.PixelBudget;

    const compressed = scratch[0..idat_len];
    const decoded = scratch[idat_len..][0..decoded_len];
    const window = scratch[idat_len + decoded_len ..][0..window_len];
    try inflateZlib(compressed, decoded, window);
    try unfilterPng(decoded, info.header.width, info.header.height, channels);
    writePngPixels(decoded, info.header.width, info.header.height, channels, out[0..count]);
    return info.header;
}

const PngInfo = struct {
    header: Header,
    color_type: u8,
    idat_total: usize,
};

fn parsePng(bytes: []const u8, maybe_idat_out: ?[]u8) DecodeError!PngInfo {
    if (!isPng(bytes)) return error.UnsupportedImage;

    var cursor: usize = png_signature.len;
    var header: ?Header = null;
    var color_type: u8 = 0;
    var idat_total: usize = 0;
    var idat_cursor: usize = 0;
    var saw_idat = false;
    var closed_idat = false;

    while (cursor + png_chunk_overhead <= bytes.len) {
        const length: usize = readU32Be(bytes[cursor..][0..png_length_size]);
        cursor += png_length_size;
        const chunk_type = bytes[cursor..][0..png_type_size];
        cursor += png_type_size;
        if (length > bytes.len - cursor - png_crc_size) return error.BadImage;
        const data = bytes[cursor..][0..length];
        cursor += length;
        const expected_crc = readU32Be(bytes[cursor..][0..png_crc_size]);
        cursor += png_crc_size;
        if (pngChunkCrc(chunk_type, data) != expected_crc) return error.BadImage;

        if (std.mem.eql(u8, chunk_type, png_chunk_ihdr)) {
            if (header != null or cursor != png_signature.len + png_chunk_overhead + png_ihdr_data_size) return error.BadImage;
            if (length != png_ihdr_data_size) return error.BadImage;
            const width = readU32Be(data[png_width_index..][0..4]);
            const height = readU32Be(data[png_height_index..][0..4]);
            if (width == 0 or height == 0) return error.BadImage;
            if (data[png_bit_depth_index] != png_bit_depth_u8) return error.UnsupportedImage;
            color_type = data[png_color_type_index];
            _ = try pngChannels(color_type);
            if (data[png_compression_index] != png_method_deflate) return error.UnsupportedImage;
            if (data[png_filter_index] != png_filter_standard) return error.UnsupportedImage;
            if (data[png_interlace_index] != png_interlace_none) return error.UnsupportedImage;
            header = .{ .width = @intCast(width), .height = @intCast(height) };
        } else if (std.mem.eql(u8, chunk_type, png_chunk_idat)) {
            if (header == null or closed_idat) return error.BadImage;
            saw_idat = true;
            if (idat_total > std.math.maxInt(usize) - length) return error.PixelBudget;
            idat_total += length;
            if (maybe_idat_out) |idat_out| {
                if (idat_cursor + length > idat_out.len) return error.PixelBudget;
                @memcpy(idat_out[idat_cursor..][0..length], data);
                idat_cursor += length;
            }
        } else if (std.mem.eql(u8, chunk_type, png_chunk_iend)) {
            if (header == null or !saw_idat or length != 0) return error.BadImage;
            if (cursor != bytes.len) return error.BadImage;
            return .{
                .header = header.?,
                .color_type = color_type,
                .idat_total = idat_total,
            };
        } else if (saw_idat) {
            closed_idat = true;
        } else if (header == null) {
            return error.BadImage;
        }
    }

    return error.BadImage;
}

fn pngChannels(color_type: u8) DecodeError!usize {
    return switch (color_type) {
        png_color_rgb => 3,
        png_color_rgba => png_rgba_channels,
        else => return error.UnsupportedImage,
    };
}

fn pngDecodedByteLen(header: Header, channels: usize) DecodeError!usize {
    if (header.width > (std.math.maxInt(usize) - 1) / channels) return error.PixelBudget;
    const row_body = header.width * channels;
    if (header.height > std.math.maxInt(usize) / (row_body + 1)) return error.PixelBudget;
    return header.height * (row_body + 1);
}

fn pixelCount(header: Header) DecodeError!usize {
    if (header.width > std.math.maxInt(usize) / header.height) return error.PixelBudget;
    return header.width * header.height;
}

fn inflateZlib(compressed: []const u8, decoded: []u8, window: []u8) DecodeError!void {
    var reader: std.Io.Reader = .fixed(compressed);
    var decompress: std.compress.flate.Decompress = .init(&reader, .zlib, window);
    decompress.reader.readSliceAll(decoded) catch return error.BadImage;
    var extra: [1]u8 = undefined;
    const extra_len = decompress.reader.readSliceShort(&extra) catch return error.BadImage;
    if (extra_len != 0) return error.BadImage;
}

fn unfilterPng(decoded: []u8, width: usize, height: usize, channels: usize) DecodeError!void {
    const row_body = width * channels;
    var y: usize = 0;
    while (y < height) : (y += 1) {
        const row_start = y * (row_body + 1);
        const filter = decoded[row_start];
        const row = decoded[row_start + 1 ..][0..row_body];
        const previous: []const u8 = if (y == 0) &.{} else decoded[row_start - row_body ..][0..row_body];
        switch (filter) {
            png_filter_none => {},
            png_filter_sub => unfilterSub(row, channels),
            png_filter_up => unfilterUp(row, previous),
            png_filter_average => unfilterAverage(row, previous, channels),
            png_filter_paeth => unfilterPaeth(row, previous, channels),
            else => return error.UnsupportedImage,
        }
    }
}

fn unfilterSub(row: []u8, channels: usize) void {
    var index: usize = channels;
    while (index < row.len) : (index += 1) {
        row[index] +%= row[index - channels];
    }
}

fn unfilterUp(row: []u8, previous: []const u8) void {
    if (previous.len == 0) return;
    for (row, previous) |*byte, above| {
        byte.* +%= above;
    }
}

fn unfilterAverage(row: []u8, previous: []const u8, channels: usize) void {
    var index: usize = 0;
    while (index < row.len) : (index += 1) {
        const left = if (index >= channels) row[index - channels] else 0;
        const above = if (previous.len == 0) 0 else previous[index];
        row[index] +%= @intCast((@as(u16, left) + @as(u16, above)) / 2);
    }
}

fn unfilterPaeth(row: []u8, previous: []const u8, channels: usize) void {
    var index: usize = 0;
    while (index < row.len) : (index += 1) {
        const left = if (index >= channels) row[index - channels] else 0;
        const above = if (previous.len == 0) 0 else previous[index];
        const upper_left = if (index >= channels and previous.len != 0) previous[index - channels] else 0;
        row[index] +%= paethPredictor(left, above, upper_left);
    }
}

fn paethPredictor(left: u8, above: u8, upper_left: u8) u8 {
    const left_i: i16 = left;
    const above_i: i16 = above;
    const upper_left_i: i16 = upper_left;
    const estimate = left_i + above_i - upper_left_i;
    const left_distance = absI16(estimate - left_i);
    const above_distance = absI16(estimate - above_i);
    const upper_left_distance = absI16(estimate - upper_left_i);
    if (left_distance <= above_distance and left_distance <= upper_left_distance) return left;
    if (above_distance <= upper_left_distance) return above;
    return upper_left;
}

fn absI16(value: i16) u16 {
    return @intCast(if (value < 0) -value else value);
}

fn writePngPixels(decoded: []const u8, width: usize, height: usize, channels: usize, out: []ui.Color) void {
    const row_body = width * channels;
    var y: usize = 0;
    while (y < height) : (y += 1) {
        const row = decoded[y * (row_body + 1) + 1 ..][0..row_body];
        var x: usize = 0;
        while (x < width) : (x += 1) {
            const source = x * channels;
            out[y * width + x] = .{
                .r = row[source + 0],
                .g = row[source + 1],
                .b = row[source + 2],
                .a = switch (channels) {
                    png_rgba_channels => row[source + 3],
                    else => png_alpha_opaque,
                },
            };
        }
    }
}

fn pngChunkCrc(chunk_type: []const u8, data: []const u8) u32 {
    var crc = std.hash.Crc32.init();
    crc.update(chunk_type);
    crc.update(data);
    return crc.final();
}

pub fn decodeTgaHeader(bytes: []const u8) DecodeError!Header {
    if (bytes.len < tga_header_size) return error.BadImage;
    if (bytes[header_color_map_type_index] != 0) return error.UnsupportedImage;
    if (bytes[header_image_type_index] != tga_type_true_color) return error.UnsupportedImage;
    const depth = bytes[header_depth_index];
    if (depth != tga_depth_rgb and depth != tga_depth_rgba) return error.UnsupportedImage;
    const width = readU16(bytes[header_width_index..][0..2]);
    const height = readU16(bytes[header_height_index..][0..2]);
    if (width == 0 or height == 0) return error.BadImage;
    const pixel_bytes = bytesPerPixel(depth);
    const id_len: usize = bytes[header_id_len_index];
    const required = tga_header_size + id_len + @as(usize, width) * @as(usize, height) * pixel_bytes;
    if (required > bytes.len) return error.BadImage;
    return .{ .width = width, .height = height };
}

fn isTga(bytes: []const u8) bool {
    if (bytes.len < tga_header_size) return false;
    if (bytes[header_color_map_type_index] != 0) return false;
    if (bytes[header_image_type_index] != tga_type_true_color) return false;
    const depth = bytes[header_depth_index];
    return depth == tga_depth_rgb or depth == tga_depth_rgba;
}

pub fn decodeTga(bytes: []const u8, out: []ui.Color) DecodeError!Header {
    const header = try decodeTgaHeader(bytes);
    const count = header.width * header.height;
    if (out.len < count) return error.PixelBudget;

    const depth = bytes[header_depth_index];
    const pixel_bytes = bytesPerPixel(depth);
    const id_len: usize = bytes[header_id_len_index];
    const data = bytes[tga_header_size + id_len ..];
    const top_origin = (bytes[header_descriptor_index] & tga_origin_top) != 0;

    var y: usize = 0;
    while (y < header.height) : (y += 1) {
        const source_y = if (top_origin) y else header.height - 1 - y;
        var x: usize = 0;
        while (x < header.width) : (x += 1) {
            const source = (source_y * header.width + x) * pixel_bytes;
            out[y * header.width + x] = decodePixel(data[source..], depth);
        }
    }
    return header;
}

pub fn encodeTgaRgba(pixels: []const ui.Color, width: usize, height: usize, out: []u8) EncodeError!usize {
    if (width == 0 or height == 0 or pixels.len < width * height) return error.BadImage;
    const body_len = width * height * 4;
    const total_len = tga_header_size + body_len + tga_footer_size;
    if (out.len < total_len) return error.OutputBudget;

    @memset(out[0..total_len], 0);
    out[header_image_type_index] = tga_type_true_color;
    writeU16(out[header_width_index..][0..2], width);
    writeU16(out[header_height_index..][0..2], height);
    out[header_depth_index] = tga_depth_rgba;
    out[header_descriptor_index] = tga_descriptor_rgba_top_left;

    var cursor: usize = tga_header_size;
    for (pixels[0 .. width * height]) |pixel| {
        out[cursor + 0] = pixel.b;
        out[cursor + 1] = pixel.g;
        out[cursor + 2] = pixel.r;
        out[cursor + 3] = pixel.a;
        cursor += 4;
    }
    @memcpy(out[cursor + 8 .. cursor + 8 + tga_signature.len], tga_signature);
    return total_len;
}

fn decodePixel(bytes: []const u8, depth: u8) ui.Color {
    return switch (depth) {
        tga_depth_rgb => .{ .r = bytes[2], .g = bytes[1], .b = bytes[0], .a = 255 },
        tga_depth_rgba => .{ .r = bytes[2], .g = bytes[1], .b = bytes[0], .a = bytes[3] },
        else => unreachable,
    };
}

fn bytesPerPixel(depth: u8) usize {
    return switch (depth) {
        tga_depth_rgb => 3,
        tga_depth_rgba => 4,
        else => unreachable,
    };
}

fn readU16(bytes: *const [2]u8) u16 {
    return @as(u16, bytes[0]) | (@as(u16, bytes[1]) << 8);
}

fn readU32Be(bytes: *const [4]u8) u32 {
    return (@as(u32, bytes[0]) << 24) |
        (@as(u32, bytes[1]) << 16) |
        (@as(u32, bytes[2]) << 8) |
        @as(u32, bytes[3]);
}

fn writeU16(bytes: *[2]u8, value: usize) void {
    std.debug.assert(value <= std.math.maxInt(u16));
    bytes[0] = @intCast(value & 0xff);
    bytes[1] = @intCast((value >> 8) & 0xff);
}

test "tga rgba encoding roundtrips pixels" {
    const pixels = [_]ui.Color{
        .{ .r = 255, .g = 0, .b = 0, .a = 255 },
        .{ .r = 0, .g = 255, .b = 0, .a = 128 },
        .{ .r = 0, .g = 0, .b = 255, .a = 64 },
        .{ .r = 255, .g = 255, .b = 255, .a = 0 },
    };
    var encoded: [tga_header_size + pixels.len * 4 + tga_footer_size]u8 = undefined;
    const len = try encodeTgaRgba(&pixels, 2, 2, &encoded);
    var decoded: [pixels.len]ui.Color = undefined;
    try std.testing.expectEqual(Format.tga, try detectFormat(encoded[0..len]));
    const header = try decode(encoded[0..len], &decoded);
    try std.testing.expectEqual(@as(usize, 2), header.width);
    try std.testing.expectEqual(@as(usize, 2), header.height);
    try std.testing.expectEqualSlices(ui.Color, &pixels, &decoded);
}

test "png rgba decoder validates chunks and returns canonical pixels" {
    const bytes = [_]u8{
        0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
        0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0xf4, 0x22, 0x7f,
        0x8a, 0x00, 0x00, 0x00, 0x11, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9c, 0x63, 0xf8, 0xcf, 0xc0, 0xf0,
        0x9f, 0xe1, 0x3f, 0x43, 0x03, 0x00, 0x10, 0x79,
        0x03, 0x7e, 0x21, 0xc0, 0xfd, 0x8d, 0x00, 0x00,
        0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42,
        0x60, 0x82,
    };
    var pixels: [2]ui.Color = undefined;
    var scratch: [pngScratchByteLen(bytes.len, 2, 1)]u8 = undefined;
    try std.testing.expectEqual(Format.png, try detectFormat(&bytes));
    const header = try decodeWithScratch(&bytes, &pixels, &scratch);
    try std.testing.expectEqual(@as(usize, 2), header.width);
    try std.testing.expectEqual(@as(usize, 1), header.height);
    try std.testing.expectEqual(ui.Color{ .r = 255, .g = 0, .b = 0, .a = 255 }, pixels[0]);
    try std.testing.expectEqual(ui.Color{ .r = 0, .g = 255, .b = 0, .a = 128 }, pixels[1]);
}

test "png decoder requires explicit scratch" {
    const bytes = [_]u8{
        0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
        0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0xf4, 0x22, 0x7f,
        0x8a, 0x00, 0x00, 0x00, 0x11, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9c, 0x63, 0xf8, 0xcf, 0xc0, 0xf0,
        0x9f, 0xe1, 0x3f, 0x43, 0x03, 0x00, 0x10, 0x79,
        0x03, 0x7e, 0x21, 0xc0, 0xfd, 0x8d, 0x00, 0x00,
        0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42,
        0x60, 0x82,
    };
    var pixels: [2]ui.Color = undefined;
    try std.testing.expectError(error.PixelBudget, decode(&bytes, &pixels));
}

test "png decoder rejects corrupt chunk crc" {
    var bytes = [_]u8{
        0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
        0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4,
        0x89, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e,
        0x44, 0xae, 0x42, 0x60, 0x82,
    };
    bytes[bytes.len - 1] ^= 1;
    try std.testing.expectError(error.BadImage, decodePngHeader(&bytes));
}

test "png scanline filters reconstruct bytes deterministically" {
    const channels = 3;
    const width = 2;
    const height = 5;
    var decoded = [_]u8{
        png_filter_none,    10, 20, 30, 40, 50, 60,
        png_filter_sub,     1,  2,  3,  4,  5,  6,
        png_filter_up,      1,  1,  1,  1,  1,  1,
        png_filter_average, 5,  5,  5,  5,  5,  5,
        png_filter_paeth,   5,  5,  5,  5,  5,  5,
    };
    try unfilterPng(&decoded, width, height, channels);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 10, 20, 30, 40, 50, 60 }, decoded[1..7]);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 1, 2, 3, 5, 7, 9 }, decoded[8..14]);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 2, 3, 4, 6, 8, 10 }, decoded[15..21]);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 6, 6, 7, 11, 12, 13 }, decoded[22..28]);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 11, 11, 12, 16, 17, 18 }, decoded[29..35]);
}

test "generic decoder rejects unknown bytes before format-specific decode" {
    const bytes = [_]u8{ 0x42, 0x41, 0x44, 0x00 };
    var pixels: [1]ui.Color = undefined;
    try std.testing.expectError(error.UnsupportedImage, detectFormat(&bytes));
    try std.testing.expectError(error.UnsupportedImage, decode(&bytes, &pixels));
}

test "tga decoder rejects unsupported compressed image type" {
    var bytes = [_]u8{0} ** tga_header_size;
    bytes[header_image_type_index] = 10;
    bytes[header_width_index] = 1;
    bytes[header_height_index] = 1;
    bytes[header_depth_index] = tga_depth_rgba;
    try std.testing.expectError(error.UnsupportedImage, decodeTgaHeader(&bytes));
}
