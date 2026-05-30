const std = @import("std");
const ui = @import("../ui/core.zig");
const video_common = @import("video_common.zig");
const ivf_container = @import("video_ivf.zig");
const webm_container = @import("video_webm.zig");

pub const Error = video_common.Error;
pub const Format = video_common.Format;
pub const Codec = video_common.Codec;
pub const Header = video_common.Header;
pub const Frame = video_common.Frame;
pub const FrameDecodeState = video_common.FrameDecodeState;

pub const Decoder = struct {
    bytes: []const u8,
    header: Header,
    cursor: usize,
    next_index: usize,
    webm_cursor_start: usize,
    webm_cursor_end: usize,
    webm_track_number: u64,
    webm_cluster_timecode: u64,
    frame_state: FrameDecodeState,

    pub fn init(bytes: []const u8) Error!Decoder {
        return switch (try detectFormat(bytes)) {
            .ivf => .{
                .bytes = bytes,
                .header = try ivf_container.decodeHeader(bytes),
                .cursor = ivf_container.header_size,
                .next_index = 0,
                .webm_cursor_start = 0,
                .webm_cursor_end = 0,
                .webm_track_number = 0,
                .webm_cluster_timecode = 0,
                .frame_state = .{},
            },
            .webm => blk: {
                const state = try webm_container.initState(bytes);
                break :blk .{
                    .bytes = bytes,
                    .header = state.header,
                    .cursor = state.cursor_start,
                    .next_index = 0,
                    .webm_cursor_start = state.cursor_start,
                    .webm_cursor_end = state.cursor_end,
                    .webm_track_number = state.track_number,
                    .webm_cluster_timecode = 0,
                    .frame_state = .{},
                };
            },
        };
    }

    pub fn reset(self: *Decoder) void {
        self.cursor = switch (self.header.format) {
            .ivf => ivf_container.header_size,
            .webm => self.webm_cursor_start,
        };
        self.next_index = 0;
        self.webm_cluster_timecode = 0;
        self.frame_state.reset();
    }

    pub fn nextFrame(self: *Decoder, out: []ui.Color, scratch: []u8) Error!?Frame {
        if (self.header.frame_count) |count| {
            if (self.next_index >= count) return null;
        }
        const record = switch (self.header.format) {
            .ivf => blk: {
                if (self.cursor == self.bytes.len) return null;
                break :blk try ivf_container.readFrameRecord(self.bytes, self.header, self.cursor, self.next_index);
            },
            .webm => try webm_container.readNextFrameRecord(
                self.bytes,
                self.header,
                self.webm_track_number,
                self.cursor,
                self.webm_cursor_end,
                self.next_index,
                &self.webm_cluster_timecode,
            ) orelse return null,
        };
        try video_common.decodeFramePayloadStateful(record.frame, out, scratch, &self.frame_state);
        self.cursor = record.next_cursor;
        self.next_index += 1;
        return record.frame;
    }
};

pub fn detectFormat(bytes: []const u8) Error!Format {
    if (ivf_container.is(bytes)) return .ivf;
    if (webm_container.is(bytes)) return .webm;
    return error.UnsupportedVideo;
}

pub fn decodeHeader(bytes: []const u8) Error!Header {
    return switch (try detectFormat(bytes)) {
        .ivf => ivf_container.decodeHeader(bytes),
        .webm => webm_container.decodeHeader(bytes),
    };
}

pub fn scratchByteLen(bytes: []const u8, width: usize, height: usize) usize {
    const header = decodeHeader(bytes) catch return 0;
    if (header.width != width or header.height != height) return 0;
    return video_common.referenceScratchByteLen(header) catch 0;
}

pub fn decodeFrame(bytes: []const u8, frame_index: usize, out: []ui.Color, scratch: []u8) Error!Frame {
    const frame = try readFrame(bytes, frame_index);
    try video_common.decodeFramePayload(frame, out, scratch);
    return frame;
}

pub fn readFrame(bytes: []const u8, frame_index: usize) Error!Frame {
    return switch (try detectFormat(bytes)) {
        .ivf => ivf_container.readFrame(bytes, frame_index),
        .webm => webm_container.readFrame(bytes, frame_index),
    };
}

pub fn isWebm(bytes: []const u8) bool {
    return webm_container.is(bytes);
}

pub fn isIvf(bytes: []const u8) bool {
    return ivf_container.is(bytes);
}

test {
    _ = @import("video_tests.zig");
}
