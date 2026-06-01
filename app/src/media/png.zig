const std = @import("er_std");
const bytes_mod = @import("../bytes.zig");
const ui = @import("../ui/core.zig");
const common = @import("common.zig");

const Header = common.Header;
const DecodeError = common.DecodeError;
const checkedMul = common.checkedMul;
const readU32Be = common.readU32Be;
const writeU32Be = common.writeU32Be;

const png_signature = "\x89PNG\r\n\x1a\n";
const png_length_size: usize = 4;
const png_type_size: usize = 4;
const png_crc_size: usize = 4;
const png_chunk_header_size: usize = png_length_size + png_type_size;
const png_chunk_overhead: usize = png_chunk_header_size + png_crc_size;
const test_png_rgba_2x1_idat_payload_len: usize = 17;
const png_ihdr_data_size: usize = 13;
const png_width_index: usize = 0;
const png_height_index: usize = 4;
const png_bit_depth_index: usize = 8;
const png_color_type_index: usize = 9;
const png_compression_index: usize = 10;
const png_filter_index: usize = 11;
const png_interlace_index: usize = 12;
const png_bit_depth_u8: u8 = 8;
const png_color_grayscale: u8 = 0;
const png_color_rgb: u8 = 2;
const png_color_grayscale_alpha: u8 = 4;
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
const ascii_upper_a: u8 = 'A';
const ascii_upper_z: u8 = 'Z';
const ascii_lower_a: u8 = 'a';
const ascii_lower_z: u8 = 'z';
const png_chunk_ancillary_bit: u8 = 1 << 5;
const png_chunk_reserved_index: usize = 2;
pub fn pngScratchByteLen(encoded_len: usize, width: usize, height: usize) usize {
    return pngScratchByteLenChecked(encoded_len, width, height) catch @panic("png scratch byte length overflow");
}

pub fn decodePngHeader(bytes: []const u8) DecodeError!Header {
    return (try parsePng(bytes, null)).header;
}

pub fn isPng(bytes: []const u8) bool {
    return bytes.len >= png_signature.len and bytes_mod.eql(bytes[0..png_signature.len], png_signature);
}
pub fn decodePng(bytes: []const u8, out: []ui.Color, scratch: []u8) DecodeError!Header {
    const info = try parsePng(bytes, scratch);
    const count = try pixelCount(info.header);
    if (out.len < count) return error.PixelBudget;
    const channels = try pngChannels(info.color_type);
    const decoded_len = try pngDecodedByteLen(info.header, channels);
    const idat_len = info.idat_total;
    const required_scratch_len = try pngScratchLayoutByteLen(idat_len, decoded_len);
    if (scratch.len < required_scratch_len) return error.PixelBudget;

    const compressed = scratch[0..idat_len];
    const decoded = scratch[idat_len..][0..decoded_len];
    const window = scratch[idat_len + decoded_len ..][0..std.compress.flate.max_window_len];
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
        try validatePngChunkType(chunk_type);
        if (length > bytes.len - cursor - png_crc_size) return error.BadImage;
        const data = bytes[cursor..][0..length];
        cursor += length;
        const expected_crc = readU32Be(bytes[cursor..][0..png_crc_size]);
        cursor += png_crc_size;
        if (pngChunkCrc(chunk_type, data) != expected_crc) return error.BadImage;

        if (bytes_mod.eql(chunk_type, png_chunk_ihdr)) {
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
        } else if (bytes_mod.eql(chunk_type, png_chunk_idat)) {
            if (header == null or closed_idat) return error.BadImage;
            saw_idat = true;
            if (idat_total > ~@as(usize, 0) - length) return error.PixelBudget;
            idat_total += length;
            if (maybe_idat_out) |idat_out| {
                if (idat_cursor + length > idat_out.len) return error.PixelBudget;
                @memcpy(idat_out[idat_cursor..][0..length], data);
                idat_cursor += length;
            }
        } else if (bytes_mod.eql(chunk_type, png_chunk_iend)) {
            if (header == null or !saw_idat or idat_total == 0 or length != 0) return error.BadImage;
            if (cursor != bytes.len) return error.BadImage;
            return .{
                .header = header.?,
                .color_type = color_type,
                .idat_total = idat_total,
            };
        } else if (header == null) {
            return error.BadImage;
        } else if (isCriticalPngChunk(chunk_type)) {
            return error.UnsupportedImage;
        } else if (saw_idat) {
            closed_idat = true;
        }
    }

    return error.BadImage;
}

fn validatePngChunkType(chunk_type: []const u8) DecodeError!void {
    if (chunk_type.len != png_type_size) return error.BadImage;
    for (chunk_type) |byte| {
        if (!isAsciiLetter(byte)) return error.BadImage;
    }
    if ((chunk_type[png_chunk_reserved_index] & png_chunk_ancillary_bit) != 0) return error.BadImage;
}

fn isCriticalPngChunk(chunk_type: []const u8) bool {
    std.debug.assert(chunk_type.len == png_type_size);
    return (chunk_type[0] & png_chunk_ancillary_bit) == 0;
}

fn isAsciiLetter(byte: u8) bool {
    return (byte >= ascii_upper_a and byte <= ascii_upper_z) or
        (byte >= ascii_lower_a and byte <= ascii_lower_z);
}

fn isAsciiUpper(byte: u8) bool {
    return byte >= ascii_upper_a and byte <= ascii_upper_z;
}

fn pngChannels(color_type: u8) DecodeError!usize {
    return switch (color_type) {
        png_color_grayscale => 1,
        png_color_rgb => 3,
        png_color_grayscale_alpha => 2,
        png_color_rgba => png_rgba_channels,
        else => return error.UnsupportedImage,
    };
}

fn pngDecodedByteLen(header: Header, channels: usize) DecodeError!usize {
    if (header.width > (~@as(usize, 0) - 1) / channels) return error.PixelBudget;
    const row_body = header.width * channels;
    if (header.height > ~@as(usize, 0) / (row_body + 1)) return error.PixelBudget;
    return header.height * (row_body + 1);
}

fn pngScratchByteLenChecked(encoded_len: usize, width: usize, height: usize) DecodeError!usize {
    const decoded_len = try pngDecodedByteLen(.{ .width = width, .height = height }, png_rgba_channels);
    return pngScratchLayoutByteLen(encoded_len, decoded_len);
}

fn pngScratchLayoutByteLen(idat_len: usize, decoded_len: usize) DecodeError!usize {
    const image_bytes = std.math.add(usize, idat_len, decoded_len) catch return error.PixelBudget;
    return std.math.add(usize, image_bytes, std.compress.flate.max_window_len) catch return error.PixelBudget;
}

fn pixelCount(header: Header) DecodeError!usize {
    if (header.width > ~@as(usize, 0) / header.height) return error.PixelBudget;
    return header.width * header.height;
}

fn divRoundUp(numerator: usize, denominator: usize) usize {
    return (numerator + denominator - 1) / denominator;
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
            const gray = row[source];
            out[y * width + x] = .{
                .r = gray,
                .g = switch (channels) {
                    1, 2 => gray,
                    else => row[source + 1],
                },
                .b = switch (channels) {
                    1, 2 => gray,
                    else => row[source + 2],
                },
                .a = switch (channels) {
                    2 => row[source + 1],
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
test "png rgba decoder validates chunks and returns canonical pixels" {
    const bytes = testPngRgba2x1();
    var pixels: [2]ui.Color = undefined;
    var scratch: [pngScratchByteLen(bytes.len, 2, 1)]u8 = undefined;
    try std.testing.expect(isPng(bytes));
    const header = try decodePng(bytes, &pixels, &scratch);
    try std.testing.expectEqual(@as(usize, 2), header.width);
    try std.testing.expectEqual(@as(usize, 1), header.height);
    try std.testing.expectEqual(ui.Color{ .r = 255, .g = 0, .b = 0, .a = 255 }, pixels[0]);
    try std.testing.expectEqual(ui.Color{ .r = 0, .g = 255, .b = 0, .a = 128 }, pixels[1]);
}

test "png grayscale decoder expands luma to opaque rgb pixels" {
    const bytes = testPngGrayscale2x1();
    var pixels: [2]ui.Color = undefined;
    var scratch: [pngScratchByteLen(bytes.len, 2, 1)]u8 = undefined;
    const header = try decodePng(bytes, &pixels, &scratch);
    try std.testing.expectEqual(@as(usize, 2), header.width);
    try std.testing.expectEqual(@as(usize, 1), header.height);
    try std.testing.expectEqual(ui.Color{ .r = 0x20, .g = 0x20, .b = 0x20, .a = 255 }, pixels[0]);
    try std.testing.expectEqual(ui.Color{ .r = 0xe0, .g = 0xe0, .b = 0xe0, .a = 255 }, pixels[1]);
}

test "png grayscale alpha decoder expands luma and preserves alpha" {
    const bytes = testPngGrayscaleAlpha2x1();
    var pixels: [2]ui.Color = undefined;
    var scratch: [pngScratchByteLen(bytes.len, 2, 1)]u8 = undefined;
    const header = try decodePng(bytes, &pixels, &scratch);
    try std.testing.expectEqual(@as(usize, 2), header.width);
    try std.testing.expectEqual(@as(usize, 1), header.height);
    try std.testing.expectEqual(ui.Color{ .r = 0x20, .g = 0x20, .b = 0x20, .a = 0x80 }, pixels[0]);
    try std.testing.expectEqual(ui.Color{ .r = 0xe0, .g = 0xe0, .b = 0xe0, .a = 0x40 }, pixels[1]);
}

test "png decoder requires explicit scratch" {
    const bytes = testPngRgba2x1();
    var pixels: [2]ui.Color = undefined;
    try std.testing.expectError(error.PixelBudget, decodePng(bytes, &pixels, &.{}));
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

test "png decoder rejects invalid chunk type names" {
    var bytes = testPngRgba2x1().*;
    const chunk_offset = findPngChunkOffset(&bytes, png_chunk_idat);
    bytes[chunk_offset + png_length_size + png_chunk_reserved_index] = ascii_lower_a;
    try std.testing.expectError(error.BadImage, decodePngHeader(&bytes));
}

test "png decoder rejects unknown critical chunks explicitly" {
    var bytes = testPngRgba2x1().*;
    const chunk_offset = findPngChunkOffset(&bytes, png_chunk_idat);
    const length: usize = readU32Be(bytes[chunk_offset..][0..png_length_size]);
    const chunk_type = bytes[chunk_offset + png_length_size ..][0..png_type_size];
    @memcpy(chunk_type, "JDAT");
    const data = bytes[chunk_offset + png_chunk_header_size ..][0..length];
    writeU32Be(bytes[chunk_offset + png_chunk_header_size + length ..][0..png_crc_size], pngChunkCrc(chunk_type, data));
    try std.testing.expectError(error.UnsupportedImage, decodePngHeader(&bytes));
}

test "png decoder rejects empty idat streams" {
    const bytes = testPngRgba2x1();
    const chunk_offset = findPngChunkOffset(bytes, png_chunk_idat);
    const iend_offset = chunk_offset + png_chunk_overhead + test_png_rgba_2x1_idat_payload_len;
    var empty_idat: [testPngRgba2x1().len - test_png_rgba_2x1_idat_payload_len]u8 = undefined;
    @memcpy(empty_idat[0..chunk_offset], bytes[0..chunk_offset]);
    writeU32Be(empty_idat[chunk_offset..][0..png_length_size], 0);
    @memcpy(empty_idat[chunk_offset + png_length_size ..][0..png_type_size], png_chunk_idat);
    writeU32Be(empty_idat[chunk_offset + png_chunk_header_size ..][0..png_crc_size], pngChunkCrc(png_chunk_idat, &.{}));
    @memcpy(
        empty_idat[chunk_offset + png_chunk_overhead ..],
        bytes[iend_offset..],
    );
    try std.testing.expectError(error.BadImage, decodePngHeader(&empty_idat));
}

test "png scratch length calculation rejects overflow" {
    try std.testing.expectError(
        error.PixelBudget,
        pngScratchByteLenChecked(~@as(usize, 0), 1, 1),
    );
    try std.testing.expectError(
        error.PixelBudget,
        pngScratchByteLenChecked(1, ~@as(usize, 0), 1),
    );
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

fn testPngRgba2x1() *const [74]u8 {
    return &[_]u8{
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
}

fn testPngGrayscale2x1() *const [71]u8 {
    return &[_]u8{
        0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
        0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x00, 0x00, 0x00, 0x00, 0xd1, 0x49, 0x20,
        0x56, 0x00, 0x00, 0x00, 0x0e, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x01, 0x01, 0x03, 0x00, 0xfc, 0xff,
        0x00, 0x20, 0xe0, 0x01, 0x23, 0x01, 0x01, 0x1c,
        0x95, 0x37, 0xd3, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82,
    };
}

fn testPngGrayscaleAlpha2x1() *const [73]u8 {
    return &[_]u8{
        0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
        0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x04, 0x00, 0x00, 0x00, 0x5e, 0x2b, 0xb7,
        0x01, 0x00, 0x00, 0x00, 0x10, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x01, 0x01, 0x05, 0x00, 0xfa, 0xff,
        0x00, 0x20, 0x80, 0xe0, 0x40, 0x04, 0x05, 0x01,
        0xc1, 0x56, 0xb2, 0x3a, 0xf1, 0x00, 0x00, 0x00,
        0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60,
        0x82,
    };
}

fn findPngChunkOffset(bytes: []const u8, chunk_name: []const u8) usize {
    var cursor: usize = png_signature.len;
    while (cursor + png_chunk_overhead <= bytes.len) {
        const length: usize = readU32Be(bytes[cursor..][0..png_length_size]);
        const chunk_type = bytes[cursor + png_length_size ..][0..png_type_size];
        if (bytes_mod.eql(chunk_type, chunk_name)) return cursor;
        cursor += png_chunk_overhead + length;
    }
    unreachable;
}
