const audio_common = @import("audio_common.zig");
const webm_container = @import("audio_webm.zig");

pub const Error = audio_common.Error;
pub const Format = audio_common.Format;
pub const Codec = audio_common.Codec;
pub const Header = audio_common.Header;
pub const Packet = audio_common.Packet;

pub const Decoder = struct {
    bytes: []const u8,
    header: Header,
    cursor: usize,
    next_index: usize,
    webm_cursor_start: usize,
    webm_cursor_end: usize,
    webm_track_number: u64,
    webm_cluster_timecode: u64,

    pub fn init(bytes: []const u8) Error!Decoder {
        return switch (try detectFormat(bytes)) {
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
                };
            },
        };
    }

    pub fn reset(self: *Decoder) void {
        self.cursor = self.webm_cursor_start;
        self.next_index = 0;
        self.webm_cluster_timecode = 0;
    }

    pub fn nextPacket(self: *Decoder) Error!?Packet {
        const record = try webm_container.readNextPacketRecord(
            self.bytes,
            self.header,
            self.webm_track_number,
            self.cursor,
            self.webm_cursor_end,
            self.next_index,
            &self.webm_cluster_timecode,
        ) orelse return null;
        self.cursor = record.next_cursor;
        self.next_index += 1;
        return record.packet;
    }
};

pub fn detectFormat(bytes: []const u8) Error!Format {
    if (webm_container.is(bytes)) return .webm;
    return error.UnsupportedAudio;
}

pub fn decodeHeader(bytes: []const u8) Error!Header {
    return switch (try detectFormat(bytes)) {
        .webm => webm_container.decodeHeader(bytes),
    };
}

pub fn readPacket(bytes: []const u8, packet_index: usize) Error!Packet {
    return switch (try detectFormat(bytes)) {
        .webm => webm_container.readPacket(bytes, packet_index),
    };
}

pub fn isWebm(bytes: []const u8) bool {
    return webm_container.is(bytes);
}

test {
    _ = @import("audio_tests.zig");
}
