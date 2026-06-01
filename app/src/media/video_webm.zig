const std = @import("er_std");
const media_common = @import("common.zig");
const bytes_mod = @import("../bytes.zig");
const video_common = @import("video_common.zig");

pub const Error = video_common.Error;
pub const Format = video_common.Format;
pub const Codec = video_common.Codec;
pub const Header = video_common.Header;
pub const Frame = video_common.Frame;

pub const signature = [_]u8{ 0x1a, 0x45, 0xdf, 0xa3 };
pub const codec_vp8 = "V_VP8";
const webm_ebml_max_vint_bytes: usize = 8;
const webm_ebml_id_ebml: u64 = 0x1a45dfa3;
const webm_ebml_id_segment: u64 = 0x18538067;
const webm_ebml_id_tracks: u64 = 0x1654ae6b;
const webm_ebml_id_track_entry: u64 = 0xae;
const webm_ebml_id_track_number: u64 = 0xd7;
const webm_ebml_id_track_type: u64 = 0x83;
const webm_ebml_id_codec_id: u64 = 0x86;
const webm_ebml_id_video: u64 = 0xe0;
const webm_ebml_id_pixel_width: u64 = 0xb0;
const webm_ebml_id_pixel_height: u64 = 0xba;
const webm_ebml_id_cluster: u64 = 0x1f43b675;
const webm_ebml_id_timecode: u64 = 0xe7;
const webm_ebml_id_simple_block: u64 = 0xa3;
const webm_ebml_id_block_group: u64 = 0xa0;
const webm_ebml_id_block: u64 = 0xa1;
pub const track_type_video: u64 = 1;
const webm_no_lacing_mask: u8 = 0x06;
const webm_ebml_vint_marker_bits: usize = 7;
const webm_ebml_vint_full_byte: u8 = 0xff;

pub const InitState = struct {
    header: Header,
    cursor_start: usize,
    cursor_end: usize,
    track_number: u64,
};

pub fn is(bytes: []const u8) bool {
    return bytes.len >= signature.len and bytes_mod.eql(bytes[0..signature.len], &signature);
}

pub fn initState(bytes: []const u8) Error!InitState {
    const track = try readTrack(bytes);
    const segment = try readSegmentElement(bytes);
    return .{
        .header = headerFromTrack(track),
        .cursor_start = segment.payload_start,
        .cursor_end = segment.next_cursor,
        .track_number = track.number,
    };
}

pub const Element = struct {
    id: u64,
    payload: []const u8,
    payload_start: usize,
    next_cursor: usize,
};

const VInt = struct {
    value: u64,
    size: usize,
};

pub const Track = struct {
    number: u64,
    codec: Codec,
    width: usize,
    height: usize,
};

const WebmBlock = struct {
    track_number: u64,
    relative_timecode: i16,
    payload: []const u8,
};

pub fn decodeHeader(bytes: []const u8) Error!Header {
    const track = try readTrack(bytes);
    return headerFromTrack(track);
}

pub fn headerFromTrack(track: Track) Header {
    return .{
        .format = .webm,
        .codec = track.codec,
        .width = track.width,
        .height = track.height,
        .frame_count = null,
    };
}

pub fn readSegmentElement(bytes: []const u8) Error!Element {
    var cursor: usize = 0;
    while (cursor < bytes.len) {
        const element = try readEbmlElement(bytes, cursor);
        switch (element.id) {
            webm_ebml_id_ebml => {},
            webm_ebml_id_segment => return element,
            else => return error.BadVideo,
        }
        cursor = element.next_cursor;
    }
    return error.BadVideo;
}

pub fn readTrack(bytes: []const u8) Error!Track {
    var cursor: usize = 0;
    while (cursor < bytes.len) {
        const element = try readEbmlElement(bytes, cursor);
        switch (element.id) {
            webm_ebml_id_ebml => {},
            webm_ebml_id_segment => return readWebmSegmentTrack(element.payload),
            else => return error.BadVideo,
        }
        cursor = element.next_cursor;
    }
    return error.BadVideo;
}

fn readWebmSegmentTrack(segment: []const u8) Error!Track {
    var cursor: usize = 0;
    while (cursor < segment.len) {
        const element = try readEbmlElement(segment, cursor);
        switch (element.id) {
            webm_ebml_id_tracks => return readTracks(element.payload),
            webm_ebml_id_cluster => return error.BadVideo,
            else => {},
        }
        cursor = element.next_cursor;
    }
    return error.BadVideo;
}

pub fn readTracks(tracks: []const u8) Error!Track {
    var cursor: usize = 0;
    while (cursor < tracks.len) {
        const element = try readEbmlElement(tracks, cursor);
        switch (element.id) {
            webm_ebml_id_track_entry => {
                const track = try readTrackEntry(element.payload);
                if (track.codec == .vp8) return track;
            },
            else => return error.BadVideo,
        }
        cursor = element.next_cursor;
    }
    return error.UnsupportedVideo;
}

pub fn readTrackEntry(track_entry: []const u8) Error!Track {
    var cursor: usize = 0;
    var track_number: ?u64 = null;
    var track_type: ?u64 = null;
    var codec: ?Codec = null;
    var width: ?usize = null;
    var height: ?usize = null;

    while (cursor < track_entry.len) {
        const element = try readEbmlElement(track_entry, cursor);
        switch (element.id) {
            webm_ebml_id_track_number => track_number = try readEbmlUnsigned(element.payload),
            webm_ebml_id_track_type => track_type = try readEbmlUnsigned(element.payload),
            webm_ebml_id_codec_id => codec = try decodeWebmCodec(element.payload),
            webm_ebml_id_video => {
                const dimensions = try readWebmVideoDimensions(element.payload);
                width = dimensions.width;
                height = dimensions.height;
            },
            else => {},
        }
        cursor = element.next_cursor;
    }

    if ((track_type orelse return error.BadVideo) != track_type_video) return error.UnsupportedVideo;
    const number = track_number orelse return error.BadVideo;
    if (number == 0) return error.BadVideo;
    return .{
        .number = number,
        .codec = codec orelse return error.UnsupportedVideo,
        .width = width orelse return error.BadVideo,
        .height = height orelse return error.BadVideo,
    };
}

const WebmDimensions = struct {
    width: usize,
    height: usize,
};

fn readWebmVideoDimensions(video: []const u8) Error!WebmDimensions {
    var cursor: usize = 0;
    var width: ?usize = null;
    var height: ?usize = null;
    while (cursor < video.len) {
        const element = try readEbmlElement(video, cursor);
        switch (element.id) {
            webm_ebml_id_pixel_width => width = try readWebmDimension(element.payload),
            webm_ebml_id_pixel_height => height = try readWebmDimension(element.payload),
            else => {},
        }
        cursor = element.next_cursor;
    }
    return .{
        .width = width orelse return error.BadVideo,
        .height = height orelse return error.BadVideo,
    };
}

fn readWebmDimension(payload: []const u8) Error!usize {
    const value = try readEbmlUnsigned(payload);
    if (value == 0 or value > ~@as(usize, 0)) return error.BadVideo;
    return @intCast(value);
}

fn decodeWebmCodec(codec: []const u8) Error!Codec {
    if (bytes_mod.eql(codec, codec_vp8)) return .vp8;
    return error.UnsupportedVideo;
}

pub fn readFrame(bytes: []const u8, frame_index: usize) Error!Frame {
    const track = try readTrack(bytes);
    const segment = try readSegmentElement(bytes);
    const header = headerFromTrack(track);
    var cursor = segment.payload_start;
    var index: usize = 0;
    var cluster_timecode: u64 = 0;
    while (true) {
        const record = try readNextFrameRecord(bytes, header, track.number, cursor, segment.next_cursor, index, &cluster_timecode) orelse return error.BadVideo;
        if (index == frame_index) return record.frame;
        cursor = record.next_cursor;
        index += 1;
    }
}

pub fn readNextFrameRecord(bytes: []const u8, header: Header, track_number: u64, cursor: usize, end: usize, frame_index: usize, cluster_timecode: *u64) Error!?video_common.FrameRecord {
    if (cursor > end or end > bytes.len) return error.BadVideo;
    var current = cursor;
    while (current < end) {
        const element = try readEbmlElement(bytes, current);
        if (element.next_cursor > end) return error.BadVideo;
        switch (element.id) {
            webm_ebml_id_cluster => {
                cluster_timecode.* = 0;
                if (try readNextFrameRecord(bytes, header, track_number, element.payload_start, element.next_cursor, frame_index, cluster_timecode)) |record| {
                    return record;
                }
                current = element.next_cursor;
            },
            webm_ebml_id_timecode => {
                cluster_timecode.* = try readEbmlUnsigned(element.payload);
                current = element.next_cursor;
            },
            webm_ebml_id_simple_block => {
                const block = try readWebmBlock(element.payload);
                if (block.track_number == track_number) {
                    return .{
                        .frame = try webmFrameFromBlock(header, frame_index, block, cluster_timecode.*),
                        .next_cursor = element.next_cursor,
                    };
                }
                current = element.next_cursor;
            },
            webm_ebml_id_block_group => {
                if (try readWebmBlockGroupNextFrame(element.payload, header, track_number, frame_index, cluster_timecode.*)) |record| {
                    return .{
                        .frame = record.frame,
                        .next_cursor = element.next_cursor,
                    };
                }
                current = element.next_cursor;
            },
            webm_ebml_id_segment => current = element.payload_start,
            else => current = element.next_cursor,
        }
    }
    return null;
}

fn readWebmBlockGroupNextFrame(block_group: []const u8, header: Header, track_number: u64, frame_index: usize, cluster_timecode: u64) Error!?video_common.FrameRecord {
    var cursor: usize = 0;
    while (cursor < block_group.len) {
        const element = try readEbmlElement(block_group, cursor);
        switch (element.id) {
            webm_ebml_id_block => {
                const block = try readWebmBlock(element.payload);
                if (block.track_number == track_number) {
                    return .{
                        .frame = try webmFrameFromBlock(header, frame_index, block, cluster_timecode),
                        .next_cursor = element.next_cursor,
                    };
                }
            },
            else => {},
        }
        cursor = element.next_cursor;
    }
    return null;
}

fn webmFrameFromBlock(header: Header, frame_index: usize, block: WebmBlock, cluster_timecode: u64) Error!Frame {
    return .{
        .header = header,
        .index = frame_index,
        .timestamp = try applyWebmRelativeTimecode(cluster_timecode, block.relative_timecode),
        .payload = block.payload,
    };
}

fn readWebmBlock(payload: []const u8) Error!WebmBlock {
    const track = try readEbmlVint(payload, 0, true);
    const header_size = media_common.checkedAdd(track.size, 3) catch return error.BadVideo;
    if (payload.len < header_size) return error.BadVideo;
    const timecode_index = track.size;
    const relative_timecode = readSignedI16Be(payload[timecode_index..][0..2]);
    const flags = payload[timecode_index + 2];
    if ((flags & webm_no_lacing_mask) != 0) return error.UnsupportedVideo;
    return .{
        .track_number = track.value,
        .relative_timecode = relative_timecode,
        .payload = payload[header_size..],
    };
}

fn applyWebmRelativeTimecode(cluster_timecode: u64, relative_timecode: i16) Error!u64 {
    if (relative_timecode >= 0) {
        return checkedAddU64(cluster_timecode, @intCast(relative_timecode)) orelse error.BadVideo;
    }
    const delta: u16 = @intCast(-relative_timecode);
    if (cluster_timecode < delta) return error.BadVideo;
    return cluster_timecode - delta;
}

fn readSignedI16Be(bytes: []const u8) i16 {
    const unsigned = (@as(u16, bytes[0]) << 8) | @as(u16, bytes[1]);
    return @bitCast(unsigned);
}

fn readEbmlElement(bytes: []const u8, cursor: usize) Error!Element {
    const id = try readEbmlId(bytes, cursor);
    const size = try readEbmlVint(bytes, cursor + id.size, true);
    if (size.value > ~@as(usize, 0)) return error.BadVideo;
    const payload_start = media_common.checkedAdd(cursor + id.size, size.size) catch return error.BadVideo;
    const payload_end = media_common.checkedAdd(payload_start, @as(usize, @intCast(size.value))) catch return error.BadVideo;
    if (payload_end > bytes.len) return error.BadVideo;
    return .{
        .id = id.value,
        .payload = bytes[payload_start..payload_end],
        .payload_start = payload_start,
        .next_cursor = payload_end,
    };
}

fn checkedAddU64(a: u64, b: u64) ?u64 {
    const sum = a +% b;
    return if (sum < a) null else sum;
}

fn readEbmlId(bytes: []const u8, cursor: usize) Error!VInt {
    const value = try readEbmlVint(bytes, cursor, false);
    if (value.value == 0) return error.BadVideo;
    return value;
}

fn readEbmlVint(bytes: []const u8, cursor: usize, remove_marker: bool) Error!VInt {
    if (cursor >= bytes.len) return error.BadVideo;
    const first = bytes[cursor];
    if (first == 0) return error.BadVideo;
    const size = ebmlVintSize(first) orelse return error.BadVideo;
    if (size > webm_ebml_max_vint_bytes or bytes.len - cursor < size) return error.BadVideo;
    const marker_mask: u8 = if (size == webm_ebml_max_vint_bytes) 0 else webm_ebml_vint_full_byte >> @intCast(size);
    var value: u64 = if (remove_marker) first & marker_mask else first;
    var index: usize = 1;
    while (index < size) : (index += 1) {
        value = (value << 8) | bytes[cursor + index];
    }
    if (remove_marker and isUnknownEbmlSize(value, size)) return error.UnsupportedVideo;
    return .{ .value = value, .size = size };
}

fn ebmlVintSize(first: u8) ?usize {
    var mask: u8 = 0x80;
    var size: usize = 1;
    while (size <= webm_ebml_max_vint_bytes) : (size += 1) {
        if ((first & mask) != 0) return size;
        mask >>= 1;
    }
    return null;
}

fn isUnknownEbmlSize(value: u64, size: usize) bool {
    const bits: u6 = @intCast(webm_ebml_vint_marker_bits * size);
    return value == (@as(u64, 1) << bits) - 1;
}

fn readEbmlUnsigned(payload: []const u8) Error!u64 {
    if (payload.len == 0 or payload.len > @sizeOf(u64)) return error.BadVideo;
    var value: u64 = 0;
    for (payload) |byte| {
        value = (value << 8) | byte;
    }
    return value;
}

test "webm ebml vint parser accepts eight byte finite sizes" {
    const parsed = try readEbmlVint(&.{ 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10, 0x00 }, 0, true);
    try std.testing.expectEqual(@as(usize, webm_ebml_max_vint_bytes), parsed.size);
    try std.testing.expectEqual(@as(u64, 0x1000), parsed.value);
}
