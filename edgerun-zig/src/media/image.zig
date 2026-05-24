const jpeg = @import("jpeg.zig");
const png = @import("png.zig");
const tga = @import("tga.zig");
const webp = @import("webp/root.zig");
const common = @import("common.zig");
const ui = @import("../ui.zig");

pub const Header = common.Header;
pub const DecodeError = common.DecodeError;
pub const EncodeError = common.EncodeError;

pub const Format = enum {
    jpeg,
    png,
    tga,
    webp,
};

pub const WebpAnimationHeader = webp.WebpAnimationHeader;
pub const WebpAnimationFrameInfo = webp.WebpAnimationFrameInfo;
pub const WebpAnimationFrame = webp.WebpAnimationFrame;
pub const WebpAnimationCanvasDecoder = webp.WebpAnimationCanvasDecoder;

pub fn detectFormat(bytes: []const u8) DecodeError!Format {
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
    };
}

pub fn scratchByteLen(bytes: []const u8, width: usize, height: usize) usize {
    return switch (detectFormat(bytes) catch @panic("image scratch byte length format error")) {
        .jpeg, .tga => 0,
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

test {
    _ = jpeg;
    _ = png;
    _ = tga;
    _ = webp;
}
