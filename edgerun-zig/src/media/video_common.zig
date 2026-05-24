const std = @import("std");
const ui = @import("../ui.zig");
const image_common = @import("common.zig");
const webp = @import("webp/root.zig");

const color_byte_len: usize = @sizeOf(ui.Color);

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
    has_vp8_reference: bool = false,

    pub fn reset(self: *FrameDecodeState) void {
        self.has_vp8_reference = false;
    }
};

pub fn mapImageDecodeError(err: image_common.DecodeError) Error {
    return switch (err) {
        error.BadImage => error.BadVideo,
        error.UnsupportedImage => error.UnsupportedVideo,
        error.PixelBudget => error.PixelBudget,
    };
}

pub fn referenceScratchByteLen(header: Header) Error!usize {
    const count = image_common.pixelCount(.{ .width = header.width, .height = header.height }) catch |err| return mapImageDecodeError(err);
    return std.math.mul(usize, count, color_byte_len) catch error.PixelBudget;
}

pub fn decodeFramePayload(frame: Frame, out: []ui.Color, scratch: []u8) Error!void {
    var state = FrameDecodeState{};
    try decodeFramePayloadStateful(frame, out, scratch, &state);
}

pub fn decodeFramePayloadStateful(frame: Frame, out: []ui.Color, scratch: []u8, state: *FrameDecodeState) Error!void {
    switch (frame.header.codec) {
        .vp8 => {
            const reference = vp8Reference(frame.header, scratch, state);
            _ = webp.decodeVp8VideoFrameWithReference(
                frame.payload,
                .{ .width = frame.header.width, .height = frame.header.height },
                out,
                reference,
            ) catch |err| return mapImageDecodeError(err);
            try storeVp8Reference(frame.header, out, scratch, state);
        },
    }
}

fn vp8Reference(header: Header, scratch: []const u8, state: *const FrameDecodeState) ?[]const u8 {
    if (!state.has_vp8_reference) return null;
    const byte_len = referenceScratchByteLen(header) catch return null;
    if (scratch.len < byte_len) return null;
    return scratch[0..byte_len];
}

fn storeVp8Reference(header: Header, out: []const ui.Color, scratch: []u8, state: *FrameDecodeState) Error!void {
    const byte_len = try referenceScratchByteLen(header);
    if (scratch.len < byte_len) {
        state.has_vp8_reference = false;
        return;
    }
    const pixel_count = byte_len / color_byte_len;
    if (out.len < pixel_count) return error.PixelBudget;
    @memcpy(scratch[0..byte_len], std.mem.sliceAsBytes(out[0..pixel_count]));
    state.has_vp8_reference = true;
}
