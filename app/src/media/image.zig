const jpeg = @import("jpeg.zig");
const jxl = @import("jxl.zig");
const png = @import("png.zig");
const tga = @import("tga.zig");
const webp = @import("webp/root.zig");
const common = @import("common.zig");
const runtime_image = @import("runtime_image.zig");
const ui = @import("../ui/core.zig");

pub const Header = common.Header;
pub const DecodeError = common.DecodeError;
pub const EncodeError = common.EncodeError;
pub const RuntimeImageError = DecodeError || EncodeError;
pub const RuntimeImageHeader = runtime_image.Header;
pub const RuntimeImageView = runtime_image.View;
pub const defaultRuntimeTileEdge = runtime_image.default_tile_edge;

pub const Format = enum {
    erimg,
};

pub const ImportFormat = enum {
    jpeg,
    jxl,
    png,
    tga,
    webp,
};

pub const JxlKind = jxl.Kind;
pub const WebpAnimationHeader = webp.WebpAnimationHeader;
pub const WebpAnimationFrameInfo = webp.WebpAnimationFrameInfo;
pub const WebpAnimationFrame = webp.WebpAnimationFrame;
pub const WebpAnimationCanvasDecoder = webp.WebpAnimationCanvasDecoder;

pub fn detectFormat(bytes: []const u8) DecodeError!Format {
    _ = try runtime_image.decode(bytes);
    return .erimg;
}

pub fn decodeHeader(bytes: []const u8) DecodeError!Header {
    const view = try runtime_image.decode(bytes);
    return .{ .width = view.header.width, .height = view.header.height };
}

pub fn decode(bytes: []const u8, out: []ui.Color) DecodeError!Header {
    const header = try runtime_image.decodeRgbaInto(bytes, out);
    return .{ .width = header.width, .height = header.height };
}

pub fn decodeRuntimeImage(bytes: []const u8) DecodeError!RuntimeImageView {
    return try runtime_image.decode(bytes);
}

pub fn decodeRuntimeRgba(bytes: []const u8, out: []ui.Color) DecodeError!RuntimeImageHeader {
    return try runtime_image.decodeRgbaInto(bytes, out);
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

pub fn importDetectFormat(bytes: []const u8) DecodeError!ImportFormat {
    if (jpeg.isJpeg(bytes)) return .jpeg;
    if (jxl.isJxl(bytes)) return .jxl;
    if (png.isPng(bytes)) return .png;
    if (tga.isTga(bytes)) return .tga;
    if (webp.isWebp(bytes)) return .webp;
    return error.UnsupportedImage;
}

pub fn importJxlKind(bytes: []const u8) DecodeError!JxlKind {
    return try jxl.detectKind(bytes);
}

pub fn importHeader(bytes: []const u8) DecodeError!Header {
    return switch (try importDetectFormat(bytes)) {
        .jpeg => jpeg.decodeHeader(bytes),
        .jxl => jxl.decodeHeader(bytes),
        .png => png.decodePngHeader(bytes),
        .tga => tga.decodeTgaHeader(bytes),
        .webp => webp.decodeWebpHeader(bytes),
    };
}

pub fn importScratchByteLen(bytes: []const u8, width: usize, height: usize) usize {
    return switch (importDetectFormat(bytes) catch @panic("image import scratch byte length format error")) {
        .jpeg, .jxl, .tga => 0,
        .png => png.pngScratchByteLen(bytes.len, width, height),
        .webp => webp.webpScratchByteLen(bytes, width, height),
    };
}

fn importDecodeWithScratch(bytes: []const u8, out: []ui.Color, scratch: []u8) DecodeError!Header {
    return switch (try importDetectFormat(bytes)) {
        .jpeg => jpeg.decode(bytes, out),
        .jxl => jxl.decodeHeader(bytes),
        .png => png.decodePng(bytes, out, scratch),
        .tga => tga.decodeTga(bytes, out),
        .webp => webp.decodeWebpWithScratch(bytes, out, scratch),
    };
}

pub fn importToRuntimeWithScratch(bytes: []const u8, pixels: []ui.Color, scratch: []u8, out: []u8) RuntimeImageError![]u8 {
    const header = try importHeader(bytes);
    return try importToRuntimeTiledWithScratch(bytes, header.width, header.height, pixels, scratch, out);
}

pub fn importToRuntimeTiledWithScratch(bytes: []const u8, tile_w: usize, tile_h: usize, pixels: []ui.Color, scratch: []u8, out: []u8) RuntimeImageError![]u8 {
    const decoded = try importDecodeWithScratch(bytes, pixels, scratch);
    return try runtime_image.encodeRgbaTiled(decoded.width, decoded.height, tile_w, tile_h, pixels, out);
}

pub fn importToRuntimeDefaultTiledWithScratch(bytes: []const u8, pixels: []ui.Color, scratch: []u8, out: []u8) RuntimeImageError![]u8 {
    const header = try importHeader(bytes);
    const tile_w = @min(defaultRuntimeTileEdge, header.width);
    const tile_h = @min(defaultRuntimeTileEdge, header.height);
    return try importToRuntimeTiledWithScratch(bytes, tile_w, tile_h, pixels, scratch, out);
}

pub const runtimeImageMagic = runtime_image.magic;
pub const runtimeImageHeaderSize = runtime_image.header_size;
pub const runtimeImageRgbaCanonicalLen = runtime_image.rgbaCanonicalLen;
pub const runtimeImageRgbaCanonicalLenForTiling = runtime_image.rgbaCanonicalLenForTiling;
pub const encodeRuntimeRgba = runtime_image.encodeRgba;
pub const encodeRuntimeRgbaTiled = runtime_image.encodeRgbaTiled;
pub const decodeRuntimeRgbaObject = runtime_image.decodeRgbaInto;

pub const decodeWebpAnimationHeader = webp.decodeWebpAnimationHeader;
pub const decodeWebpAnimationFrame = webp.decodeWebpAnimationFrame;
pub const decodeWebpAnimationFrameWithScratch = webp.decodeWebpAnimationFrameWithScratch;
pub const decodeWebpAnimationCanvasFrame = webp.decodeWebpAnimationCanvasFrame;
pub const decodeWebpAnimationCanvasFrameWithScratch = webp.decodeWebpAnimationCanvasFrameWithScratch;
pub const webpAnimationFrameScratchByteLen = webp.webpAnimationFrameScratchByteLen;
pub const webpAnimationCanvasScratchByteLen = webp.webpAnimationCanvasScratchByteLen;
pub const webpAnimationDecoderScratchByteLen = webp.webpAnimationDecoderScratchByteLen;

test "runtime decoder rejects foreign image bytes" {
    var pixels: [1]ui.Color = undefined;
    if (decode("not-an-erimg-file-byte-stream-here-no-magic", &pixels)) return error.TestExpectedError else |err| {
        if (err != error.UnsupportedImage) return err;
    }
}

test "runtime decoder accepts canonical ERIMG only" {
    const pixels = [_]ui.Color{.{ .r = 10, .g = 20, .b = 30, .a = 255 }};
    var canonical: [runtime_image.header_size + @sizeOf(ui.Color)]u8 = undefined;
    const encoded = try runtime_image.encodeRgba(1, 1, &pixels, &canonical);

    if (try detectFormat(encoded) != .erimg) return error.TestExpectedEqual;
    var decoded_pixels: [1]ui.Color = undefined;
    const header = try decode(encoded, &decoded_pixels);
    if (header.width != 1) return error.TestExpectedEqual;
    if (!equalSlices(ui.Color, &pixels, &decoded_pixels)) return error.TestExpectedEqual;
}

test "import path requires foreign image bytes and preserves existing runtime bytes separately" {
    const pixels = [_]ui.Color{.{ .r = 3, .g = 4, .b = 5, .a = 6 }};
    var canonical: [runtime_image.header_size + @sizeOf(ui.Color)]u8 = undefined;
    const encoded = try runtime_image.encodeRgba(1, 1, &pixels, &canonical);
    if (importDetectFormat(encoded)) return error.TestExpectedError else |err| {
        if (err != error.UnsupportedImage) return err;
    }
}

test "import path detects jpeg xl codestream and container" {
    const codestream = [_]u8{ 0xff, 0x0a, 0x00, 0x01 };
    const container = jxl.container_signature ++ [_]u8{ 0x00, 0x00, 0x00, 0x00 };
    if (try importDetectFormat(&codestream) != .jxl) return error.TestExpectedEqual;
    if (try importJxlKind(&codestream) != .codestream) return error.TestExpectedEqual;
    if (try importDetectFormat(&container) != .jxl) return error.TestExpectedEqual;
    if (try importJxlKind(&container) != .container) return error.TestExpectedEqual;
}

test "runtime decoder accepts tiled ERIMG" {
    const pixels = [_]ui.Color{
        .{ .r = 1, .g = 0, .b = 0, .a = 255 },
        .{ .r = 2, .g = 0, .b = 0, .a = 255 },
        .{ .r = 3, .g = 0, .b = 0, .a = 255 },
        .{ .r = 4, .g = 0, .b = 0, .a = 255 },
    };
    var canonical: [runtime_image.header_size + pixels.len * @sizeOf(ui.Color)]u8 = undefined;
    const encoded = try runtime_image.encodeRgbaTiled(2, 2, 1, 1, &pixels, &canonical);
    var decoded_pixels: [pixels.len]ui.Color = undefined;
    const header = try decode(encoded, &decoded_pixels);
    if (header.width != 2) return error.TestExpectedEqual;
    if (!equalSlices(ui.Color, &pixels, &decoded_pixels)) return error.TestExpectedEqual;
}

fn equalSlices(comptime T: type, expected: []const T, actual: []const T) bool {
    if (expected.len != actual.len) return false;
    for (expected, actual) |expected_item, actual_item| {
        if (expected_item != actual_item) return false;
    }
    return true;
}

test {
    _ = jpeg;
    _ = jxl;
    _ = png;
    _ = tga;
    _ = webp;
    _ = runtime_image;
}
