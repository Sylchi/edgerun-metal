const std = @import("std");
const ui = @import("../ui.zig");
const common = @import("common.zig");

const Header = common.Header;
const DecodeError = common.DecodeError;
const EncodeError = common.EncodeError;
const readU16Le = common.readU16Le;
const writeU16 = common.writeU16;

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

pub fn decodeTgaHeader(bytes: []const u8) DecodeError!Header {
    if (bytes.len < tga_header_size) return error.BadImage;
    if (bytes[header_color_map_type_index] != 0) return error.UnsupportedImage;
    if (bytes[header_image_type_index] != tga_type_true_color) return error.UnsupportedImage;
    const depth = bytes[header_depth_index];
    if (depth != tga_depth_rgb and depth != tga_depth_rgba) return error.UnsupportedImage;
    const width = readU16Le(bytes[header_width_index..][0..2]);
    const height = readU16Le(bytes[header_height_index..][0..2]);
    if (width == 0 or height == 0) return error.BadImage;
    const pixel_bytes = bytesPerPixel(depth);
    const id_len: usize = bytes[header_id_len_index];
    const required = tga_header_size + id_len + @as(usize, width) * @as(usize, height) * pixel_bytes;
    if (required > bytes.len) return error.BadImage;
    return .{ .width = width, .height = height };
}

pub fn isTga(bytes: []const u8) bool {
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
    try std.testing.expect(isTga(encoded[0..len]));
    const header = try decodeTga(encoded[0..len], &decoded);
    try std.testing.expectEqual(@as(usize, 2), header.width);
    try std.testing.expectEqual(@as(usize, 2), header.height);
    try std.testing.expectEqualSlices(ui.Color, &pixels, &decoded);
}
