const ui = @import("../ui/core.zig");
const image_common = @import("common.zig");

pub const Error = error{
    BadVideo,
    UnsupportedVideo,
    PixelBudget,
};

pub const Format = enum {
    webm,
    ivf,
};

pub const Codec = enum {
    vp8,
};

pub const Header = struct {
    format: Format,
    codec: Codec,
    width: usize,
    height: usize,
    frame_count: ?usize,
};

pub const Frame = struct {
    header: Header,
    index: usize,
    timestamp: u64,
    payload: []const u8,
};

pub const FrameRecord = struct {
    frame: Frame,
    next_cursor: usize,
};

pub const FrameDecodeState = struct {
    pub fn reset(_: *FrameDecodeState) void {}
};

pub fn mapImageDecodeError(err: image_common.DecodeError) Error {
    return switch (err) {
        error.BadImage => error.BadVideo,
        error.UnsupportedImage => error.UnsupportedVideo,
        error.PixelBudget => error.PixelBudget,
    };
}

pub fn referenceScratchByteLen(header: Header) Error!usize {
    _ = header;
    return error.UnsupportedVideo;
}

pub fn decodeFramePayload(frame: Frame, out: []ui.Color, scratch: []u8) Error!void {
    var state = FrameDecodeState{};
    try decodeFramePayloadStateful(frame, out, scratch, &state);
}

pub fn decodeFramePayloadStateful(frame: Frame, out: []ui.Color, scratch: []u8, state: *FrameDecodeState) Error!void {
    _ = frame;
    _ = out;
    _ = scratch;
    _ = state;
    return error.UnsupportedVideo;
}
