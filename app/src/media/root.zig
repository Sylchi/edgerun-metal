pub const image = @import("image.zig");
pub const image_object = @import("image_object.zig");
pub const video = @import("video.zig");
pub const audio = @import("audio.zig");

pub const Header = image.Header;
pub const DecodeError = image.DecodeError;
pub const EncodeError = image.EncodeError;
pub const RuntimeImageError = image.RuntimeImageError;
pub const RuntimeImageHeader = image.RuntimeImageHeader;
pub const RuntimeImageView = image.RuntimeImageView;
pub const Format = image.Format;
pub const ImportFormat = image.ImportFormat;
pub const JxlKind = image.JxlKind;

pub const detectFormat = image.detectFormat;
pub const decodeHeader = image.decodeHeader;
pub const decode = image.decode;
pub const decodeRuntimeImage = image.decodeRuntimeImage;
pub const decodeRuntimeRgba = image.decodeRuntimeRgba;

pub const runtimeImageMagic = image.runtimeImageMagic;
pub const runtimeImageHeaderSize = image.runtimeImageHeaderSize;
pub const runtimeImageRgbaCanonicalLen = image.runtimeImageRgbaCanonicalLen;
pub const runtimeImageRgbaCanonicalLenForTiling = image.runtimeImageRgbaCanonicalLenForTiling;
pub const runtimeCanonicalLen = image.runtimeCanonicalLen;
pub const runtimeCanonicalLenForHeader = image.runtimeCanonicalLenForHeader;
pub const runtimeCanonicalLenForTiling = image.runtimeCanonicalLenForTiling;
pub const runtimeCanonicalLenTiled = image.runtimeCanonicalLenTiled;
pub const encodeRuntimeRgba = image.encodeRuntimeRgba;
pub const encodeRuntimeRgbaTiled = image.encodeRuntimeRgbaTiled;
pub const decodeRuntimeRgbaObject = image.decodeRuntimeRgbaObject;

pub const importDetectFormat = image.importDetectFormat;
pub const importJxlKind = image.importJxlKind;
pub const importHeader = image.importHeader;
pub const importScratchByteLen = image.importScratchByteLen;
pub const importToRuntimeWithScratch = image.importToRuntimeWithScratch;
pub const importToRuntimeTiledWithScratch = image.importToRuntimeTiledWithScratch;
pub const importToRuntimeDefaultTiledWithScratch = image.importToRuntimeDefaultTiledWithScratch;

pub const WebpAnimationHeader = image.WebpAnimationHeader;
pub const WebpAnimationFrameInfo = image.WebpAnimationFrameInfo;
pub const WebpAnimationFrame = image.WebpAnimationFrame;
pub const WebpAnimationCanvasDecoder = image.WebpAnimationCanvasDecoder;
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
    _ = image_object;
    _ = video;
    _ = audio;
}
