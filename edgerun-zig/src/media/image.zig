const jpeg = @import("jpeg.zig");
const png = @import("png.zig");
const tga = @import("tga.zig");
const webp = @import("webp/root.zig");
const common = @import("common.zig");
const runtime_image = @import("runtime_image.zig");
const ui = @import("../ui.zig");

pub const Header = common.Header;
pub const DecodeError = common.DecodeError;
pub const EncodeError = common.EncodeError;
pub const RuntimeImageError = DecodeError || EncodeError;
pub const RuntimeImageHeader = runtime_image.Header;
pub const RuntimeImageView = runtime_image.View;
pub const defaultRuntimeTileEdge = runtime_image.default_tile_edge;

pub const Format = enum {
    jpeg,
    png,
    tga,
    webp,
    erimg,
};

pub const WebpAnimationHeader = webp.WebpAnimationHeader;
pub const WebpAnimationFrameInfo = webp.WebpAnimationFrameInfo;
pub const WebpAnimationFrame = webp.WebpAnimationFrame;
pub const WebpAnimationCanvasDecoder = webp.WebpAnimationCanvasDecoder;

pub fn detectFormat(bytes: []const u8) DecodeError!Format {
    if (runtime_image.decode(bytes)) |_| return .erimg else |err| switch (err) {
        error.UnsupportedImage => {},
        error.BadImage, error.PixelBudget => return error.BadImage,
    }
    if (jpeg.isJpeg(bytes)) return .jpeg;
    if (png.isPng(bytes)) return .png;
    if (tga.isTga(bytes)) return .tga;
    if (webp.isWebp(bytes)) return .webp;
    return error.UnsupportedImage;
}

pub fn decodeHeader(bytes: []const u8) DecodeError!Header {
    return switch (try detectFormat(bytes)) {
        .jpeg => jpeg.decodeHeader(bytes),
        .png => png.decodePngHeader(bytes),
        .tga => tga.decodeTgaHeader(bytes),
        .webp => webp.decodeWebpHeader(bytes),
        .erimg => blk: {
            const view = try runtime_image.decode(bytes);
            break :blk .{ .width = view.header.width, .height = view.header.height };
        },
    };
}

pub fn decode(bytes: []const u8, out: []ui.Color) DecodeError!Header {
    return decodeWithScratch(bytes, out, &.{});
}

pub fn decodeWithScratch(bytes: []const u8, out: []ui.Color, scratch: []u8) DecodeError!Header {
    return switch (try detectFormat(bytes)) {
        .jpeg => jpeg.decode(bytes, out),
        .png => png.decodePng(bytes, out, scratch),
        .tga => tga.decodeTga(bytes, out),
        .webp => webp.decodeWebpWithScratch(bytes, out, scratch),
        .erimg => blk: {
            const header = try runtime_image.decodeRgbaInto(bytes, out);
            break :blk .{ .width = header.width, .height = header.height };
        },
    };
}

pub fn runtimeCanonicalLenForHeader(header: Header) RuntimeImageError!usize {
    return try runtime_image.rgbaCanonicalLen(header.width, header.height);
}

pub fn runtimeCanonicalLenForTiling(header: Header, tile_w: usize, tile_h: usize) RuntimeImageError!usize {
    return try runtime_image.rgbaCanonicalLenForTiling(header.width, header.height, tile_w, tile_h);
}

pub fn runtimeCanonicalLen(bytes: []const u8) RuntimeImageError!usize {
    return try runtimeCanonicalLenForHeader(try decodeHeader(bytes));
}

pub fn runtimeCanonicalLenTiled(bytes: []const u8, tile_w: usize, tile_h: usize) RuntimeImageError!usize {
    return try runtimeCanonicalLenForTiling(try decodeHeader(bytes), tile_w, tile_h);
}

pub fn decodeToRuntimeWithScratch(bytes: []const u8, pixels: []ui.Color, scratch: []u8, out: []u8) RuntimeImageError![]u8 {
    const header = try decodeHeader(bytes);
    return try decodeToRuntimeTiledWithScratch(bytes, header.width, header.height, pixels, scratch, out);
}

pub fn decodeToRuntimeTiledWithScratch(bytes: []const u8, tile_w: usize, tile_h: usize, pixels: []ui.Color, scratch: []u8, out: []u8) RuntimeImageError![]u8 {
    const format = detectFormat(bytes) catch |err| return err;
    if (format == .erimg) {
        _ = try runtime_image.decode(bytes);
        if (out.len < bytes.len) return error.OutputBudget;
        @memcpy(out[0..bytes.len], bytes);
        return out[0..bytes.len];
    }
    const decoded = try decodeWithScratch(bytes, pixels, scratch);
    return try runtime_image.encodeRgbaTiled(decoded.width, decoded.height, tile_w, tile_h, pixels, out);
}

pub fn decodeToRuntimeDefaultTiledWithScratch(bytes: []const u8, pixels: []ui.Color, scratch: []u8, out: []u8) RuntimeImageError![]u8 {
    const header = try decodeHeader(bytes);
    const tile_w = @min(defaultRuntimeTileEdge, header.width);
    const tile_h = @min(defaultRuntimeTileEdge, header.height);
    return try decodeToRuntimeTiledWithScratch(bytes, tile_w, tile_h, pixels, scratch, out);
}

pub fn decodeRuntimeImage(bytes: []const u8) DecodeError!RuntimeImageView {
    return try runtime_image.decode(bytes);
}

pub fn decodeRuntimeRgba(bytes: []const u8, out: []ui.Color) DecodeError!RuntimeImageHeader {
    return try runtime_image.decodeRgbaInto(bytes, out);
}

pub fn scratchByteLen(bytes: []const u8, width: usize, height: usize) usize {
    return switch (detectFormat(bytes) catch @panic("image scratch byte length format error")) {
        .jpeg, .tga, .erimg => 0,
        .png => png.pngScratchByteLen(bytes.len, width, height),
        .webp => webp.webpScratchByteLen(bytes, width, height),
    };
}

pub const pngScratchByteLen = png.pngScratchByteLen;
pub const decodePngHeader = png.decodePngHeader;
pub const decodePng = png.decodePng;

pub const decodeTgaHeader = tga.decodeTgaHeader;
pub const decodeTga = tga.decodeTga;
pub const encodeTgaRgba = tga.encodeTgaRgba;

pub const runtimeImageMagic = runtime_image.magic;
pub const runtimeImageHeaderSize = runtime_image.header_size;
pub const runtimeImageRgbaCanonicalLen = runtime_image.rgbaCanonicalLen;
pub const runtimeImageRgbaCanonicalLenForTiling = runtime_image.rgbaCanonicalLenForTiling;
pub const encodeRuntimeRgba = runtime_image.encodeRgba;
pub const encodeRuntimeRgbaTiled = runtime_image.encodeRgbaTiled;
pub const decodeRuntimeRgbaObject = runtime_image.decodeRgbaInto;

pub const webpScratchByteLen = webp.webpScratchByteLen;
pub const decodeWebpHeader = webp.decodeWebpHeader;
pub const decodeWebp = webp.decodeWebp;
pub const decodeWebpWithScratch = webp.decodeWebpWithScratch;
pub const decodeWebpAnimationHeader = webp.decodeWebpAnimationHeader;
pub const decodeWebpAnimationFrame = webp.decodeWebpAnimationFrame;
pub const decodeWebpAnimationFrameWithScratch = webp.decodeWebpAnimationFrameWithScratch;
pub const decodeWebpAnimationCanvasFrame = webp.decodeWebpAnimationCanvasFrame;
pub const decodeWebpAnimationCanvasFrameWithScratch = webp.decodeWebpAnimationCanvasFrameWithScratch;
pub const webpAnimationFrameScratchByteLen = webp.webpAnimationFrameScratchByteLen;
pub const webpAnimationCanvasScratchByteLen = webp.webpAnimationCanvasScratchByteLen;
pub const webpAnimationDecoderScratchByteLen = webp.webpAnimationDecoderScratchByteLen;

test "generic decoder rejects unknown bytes before format-specific decode" {
    var pixels: [1]ui.Color = undefined;
    try @import("std").testing.expectError(error.UnsupportedImage, decode("not an image", &pixels));
}

test "generic decoder accepts canonical runtime image objects" {
    const pixels = [_]ui.Color{.{ .r = 10, .g = 20, .b = 30, .a = 255 }};
    var canonical: [runtime_image.header_size + @sizeOf(ui.Color)]u8 = undefined;
    const encoded = try runtime_image.encodeRgba(1, 1, &pixels, &canonical);

    try @import("std").testing.expectEqual(Format.erimg, try detectFormat(encoded));
    var decoded_pixels: [1]ui.Color = undefined;
    const header = try decode(encoded, &decoded_pixels);
    try @import("std").testing.expectEqual(@as(usize, 1), header.width);
    try @import("std").testing.expectEqualSlices(ui.Color, &pixels, &decoded_pixels);
}

test "generic decoder converts imported images into runtime objects" {
    const pixels = [_]ui.Color{.{ .r = 3, .g = 4, .b = 5, .a = 6 }};
    var canonical: [runtime_image.header_size + @sizeOf(ui.Color)]u8 = undefined;
    const encoded = try runtime_image.encodeRgba(1, 1, &pixels, &canonical);
    var out: [runtime_image.header_size + @sizeOf(ui.Color)]u8 = undefined;
    var decoded_pixels: [1]ui.Color = undefined;
    const roundtrip = try decodeToRuntimeWithScratch(encoded, &decoded_pixels, &.{}, &out);
    try @import("std").testing.expectEqualSlices(u8, encoded, roundtrip);
}

test "generic decoder preserves existing ERIMG when tiled import is requested" {
    const pixels = [_]ui.Color{
        .{ .r = 1, .g = 0, .b = 0, .a = 255 },
        .{ .r = 2, .g = 0, .b = 0, .a = 255 },
        .{ .r = 3, .g = 0, .b = 0, .a = 255 },
        .{ .r = 4, .g = 0, .b = 0, .a = 255 },
    };
    var canonical: [runtime_image.header_size + pixels.len * @sizeOf(ui.Color)]u8 = undefined;
    const encoded = try runtime_image.encodeRgbaTiled(2, 2, 1, 1, &pixels, &canonical);
    var out: [runtime_image.header_size + pixels.len * @sizeOf(ui.Color)]u8 = undefined;
    var decoded_pixels: [pixels.len]ui.Color = undefined;
    const roundtrip = try decodeToRuntimeTiledWithScratch(encoded, 2, 2, &decoded_pixels, &.{}, &out);
    try @import("std").testing.expectEqualSlices(u8, encoded, roundtrip);
}

test {
    _ = jpeg;
    _ = png;
    _ = tga;
    _ = webp;
    _ = runtime_image;
}
