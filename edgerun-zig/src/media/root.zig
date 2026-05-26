pub const image = @import("image.zig");
pub const video = @import("video.zig");
pub const audio = @import("audio.zig");

pub const Header = image.Header;
pub const DecodeError = image.DecodeError;
pub const EncodeError = image.EncodeError;
pub const Format = image.Format;

pub const WebpAnimationHeader = image.WebpAnimationHeader;
pub const WebpAnimationFrameInfo = image.WebpAnimationFrameInfo;
pub const WebpAnimationFrame = image.WebpAnimationFrame;
pub const WebpAnimationCanvasDecoder = image.WebpAnimationCanvasDecoder;

pub const detectFormat = image.detectFormat;
pub const decodeHeader = image.decodeHeader;
pub const decode = image.decode;
pub const decodeWithScratch = image.decodeWithScratch;
pub const scratchByteLen = image.scratchByteLen;

pub const pngScratchByteLen = image.pngScratchByteLen;
pub const decodePngHeader = image.decodePngHeader;
pub const decodePng = image.decodePng;

pub const decodeTgaHeader = image.decodeTgaHeader;
pub const decodeTga = image.decodeTga;
pub const encodeTgaRgba = image.encodeTgaRgba;

pub const webpScratchByteLen = image.webpScratchByteLen;
pub const decodeWebpHeader = image.decodeWebpHeader;
pub const decodeWebp = image.decodeWebp;
pub const decodeWebpWithScratch = image.decodeWebpWithScratch;
pub const decodeWebpAnimationHeader = image.decodeWebpAnimationHeader;
pub const decodeWebpAnimationFrame = image.decodeWebpAnimationFrame;
pub const decodeWebpAnimationFrameWithScratch = image.decodeWebpAnimationFrameWithScratch;
pub const decodeWebpAnimationCanvasFrame = image.decodeWebpAnimationCanvasFrame;
pub const decodeWebpAnimationCanvasFrameWithScratch = image.decodeWebpAnimationCanvasFrameWithScratch;
pub const webpAnimationFrameScratchByteLen = image.webpAnimationFrameScratchByteLen;
pub const webpAnimationCanvasScratchByteLen = image.webpAnimationCanvasScratchByteLen;
pub const webpAnimationDecoderScratchByteLen = image.webpAnimationDecoderScratchByteLen;

test {
    _ = image;
    _ = video;
    _ = audio;
}
