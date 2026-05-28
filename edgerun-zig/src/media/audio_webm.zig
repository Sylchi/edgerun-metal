const std = @import("std");
const math = @import("../math.zig");
const bytes_mod = @import("../bytes.zig");
const audio_common = @import("audio_common.zig");

pub const Error = audio_common.Error;
pub const Format = audio_common.Format;
pub const Codec = audio_common.Codec;
pub const Header = audio_common.Header;
pub const Packet = audio_common.Packet;

pub const signature = [_]u8{ 0x1a, 0x45, 0xdf, 0xa3 };
pub const codec_opus = "A_OPUS";
pub const codec_vorbis = "A_VORBIS";
pub const track_type_audio: u64 = 2;

const webm_ebml_max_vint_bytes: usize = 8;
const webm_ebml_id_ebml: u64 = 0x1a45dfa3;
const webm_ebml_id_segment: u64 = 0x18538067;
const webm_ebml_id_tracks: u64 = 0x1654ae6b;
const webm_ebml_id_track_entry: u64 = 0xae;
const webm_ebml_id_track_number: u64 = 0xd7;
const webm_ebml_id_track_type: u64 = 0x83;
const webm_ebml_id_codec_id: u64 = 0x86;
const webm_ebml_id_audio: u64 = 0xe1;
const webm_ebml_id_sampling_frequency: u64 = 0xb5;
const webm_ebml_id_channels: u64 = 0x9f;
const webm_ebml_id_cluster: u64 = 0x1f43b675;
const webm_ebml_id_timecode: u64 = 0xe7;
const webm_ebml_id_simple_block: u64 = 0xa3;
const webm_ebml_id_block_group: u64 = 0xa0;
const webm_ebml_id_block: u64 = 0xa1;
const webm_no_lacing_mask: u8 = 0x06;
const webm_ebml_vint_marker_bits: usize = 7;
const webm_ebml_vint_full_byte: u8 = 0xff;
const webm_default_audio_sample_rate_hz: u32 = 8000;
const webm_default_audio_channels: u8 = 1;

pub const InitState = struct {
    header: Header,
    cursor_start: usize,
    cursor_end: usize,
    track_number: u64,
};

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
    sample_rate_hz: u32,
    channels: u8,
};

const WebmBlock = struct {
    track_number: u64,
    relative_timecode: i16,
    payload: []const u8,
};

const WebmAudioSettings = struct {
    sample_rate_hz: u32,
    channels: u8,
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

pub fn decodeHeader(bytes: []const u8) Error!Header {
    const track = try readTrack(bytes);
    return headerFromTrack(track);
}

pub fn headerFromTrack(track: Track) Header {
    return .{
        .format = .webm,
        .codec = track.codec,
        .sample_rate_hz = track.sample_rate_hz,
        .channels = track.channels,
        .packet_count = null,
    };
}

pub fn readSegmentElement(bytes: []const u8) Error!Element {
    var cursor: usize = 0;
    while (cursor < bytes.len) {
        const element = try readEbmlElement(bytes, cursor);
        switch (element.id) {
            webm_ebml_id_ebml => {},
            webm_ebml_id_segment => return element,
            else => return error.BadAudio,
        }
        cursor = element.next_cursor;
    }
    return error.BadAudio;
}

pub fn readTrack(bytes: []const u8) Error!Track {
    var cursor: usize = 0;
    while (cursor < bytes.len) {
        const element = try readEbmlElement(bytes, cursor);
        switch (element.id) {
            webm_ebml_id_ebml => {},
            webm_ebml_id_segment => return readWebmSegmentTrack(element.payload),
            else => return error.BadAudio,
        }
        cursor = element.next_cursor;
    }
    return error.BadAudio;
}

fn readWebmSegmentTrack(segment: []const u8) Error!Track {
    var cursor: usize = 0;
    while (cursor < segment.len) {
        const element = try readEbmlElement(segment, cursor);
        switch (element.id) {
            webm_ebml_id_tracks => return readTracks(element.payload),
            webm_ebml_id_cluster => return error.BadAudio,
            else => {},
        }
        cursor = element.next_cursor;
    }
    return error.BadAudio;
}

pub fn readTracks(tracks: []const u8) Error!Track {
    var cursor: usize = 0;
    while (cursor < tracks.len) {
        const element = try readEbmlElement(tracks, cursor);
        switch (element.id) {
            webm_ebml_id_track_entry => {
                const track = readTrackEntry(element.payload) catch |err| switch (err) {
                    error.UnsupportedAudio => null,
                    else => return err,
                };
                if (track) |audio_track| return audio_track;
            },
            else => return error.BadAudio,
        }
        cursor = element.next_cursor;
    }
    return error.UnsupportedAudio;
}

pub fn readTrackEntry(track_entry: []const u8) Error!Track {
    var cursor: usize = 0;
    var track_number: ?u64 = null;
    var track_type: ?u64 = null;
    var codec: ?Codec = null;
    var sample_rate_hz: u32 = webm_default_audio_sample_rate_hz;
    var channels: u8 = webm_default_audio_channels;

    while (cursor < track_entry.len) {
        const element = try readEbmlElement(track_entry, cursor);
        switch (element.id) {
            webm_ebml_id_track_number => track_number = try readEbmlUnsigned(element.payload),
            webm_ebml_id_track_type => track_type = try readEbmlUnsigned(element.payload),
            webm_ebml_id_codec_id => codec = try decodeWebmCodec(element.payload),
            webm_ebml_id_audio => {
                const settings = try readWebmAudioSettings(element.payload);
                sample_rate_hz = settings.sample_rate_hz;
                channels = settings.channels;
            },
            else => {},
        }
        cursor = element.next_cursor;
    }

    if ((track_type orelse return error.BadAudio) != track_type_audio) return error.UnsupportedAudio;
    const number = track_number orelse return error.BadAudio;
    if (number == 0) return error.BadAudio;
    return .{
        .number = number,
        .codec = codec orelse return error.UnsupportedAudio,
        .sample_rate_hz = sample_rate_hz,
        .channels = channels,
    };
}

fn readWebmAudioSettings(audio: []const u8) Error!WebmAudioSettings {
    var cursor: usize = 0;
    var sample_rate_hz: u32 = webm_default_audio_sample_rate_hz;
    var channels: u8 = webm_default_audio_channels;
    while (cursor < audio.len) {
        const element = try readEbmlElement(audio, cursor);
        switch (element.id) {
            webm_ebml_id_sampling_frequency => sample_rate_hz = try readWebmSampleRate(element.payload),
            webm_ebml_id_channels => channels = try readWebmChannels(element.payload),
            else => {},
        }
        cursor = element.next_cursor;
    }
    return .{
        .sample_rate_hz = sample_rate_hz,
        .channels = channels,
    };
}

fn readWebmSampleRate(payload: []const u8) Error!u32 {
    const value = try readEbmlFloat(payload);
    if (!math.isFiniteF(@as(f32, @floatCast(value))) or value < 1 or value > ~@as(u32, 0)) return error.BadAudio;
    const rounded = @round(value);
    if (rounded != value) return error.UnsupportedAudio;
    return @intFromFloat(rounded);
}

fn readWebmChannels(payload: []const u8) Error!u8 {
    const value = try readEbmlUnsigned(payload);
    if (value == 0 or value > 255) return error.BadAudio;
    return @intCast(value);
}

fn decodeWebmCodec(codec: []const u8) Error!Codec {
    if (bytes_mod.eql(codec, codec_opus)) return .opus;
    if (bytes_mod.eql(codec, codec_vorbis)) return .vorbis;
    return error.UnsupportedAudio;
}

pub fn readPacket(bytes: []const u8, packet_index: usize) Error!Packet {
    const track = try readTrack(bytes);
    const segment = try readSegmentElement(bytes);
    const header = headerFromTrack(track);
    var cursor = segment.payload_start;
    var index: usize = 0;
    var cluster_timecode: u64 = 0;
    while (true) {
        const record = try readNextPacketRecord(bytes, header, track.number, cursor, segment.next_cursor, index, &cluster_timecode) orelse return error.BadAudio;
        if (index == packet_index) return record.packet;
        cursor = record.next_cursor;
        index += 1;
    }
}

pub fn readNextPacketRecord(bytes: []const u8, header: Header, track_number: u64, cursor: usize, end: usize, packet_index: usize, cluster_timecode: *u64) Error!?audio_common.PacketRecord {
    if (cursor > end or end > bytes.len) return error.BadAudio;
    var current = cursor;
    while (current < end) {
        const element = try readEbmlElement(bytes, current);
        if (element.next_cursor > end) return error.BadAudio;
        switch (element.id) {
            webm_ebml_id_cluster => {
                cluster_timecode.* = 0;
                if (try readNextPacketRecord(bytes, header, track_number, element.payload_start, element.next_cursor, packet_index, cluster_timecode)) |record| {
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
                        .packet = try webmPacketFromBlock(header, packet_index, block, cluster_timecode.*),
                        .next_cursor = element.next_cursor,
                    };
                }
                current = element.next_cursor;
            },
            webm_ebml_id_block_group => {
                if (try readWebmBlockGroupNextPacket(element.payload, header, track_number, packet_index, cluster_timecode.*)) |record| {
                    return .{
                        .packet = record.packet,
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

fn readWebmBlockGroupNextPacket(block_group: []const u8, header: Header, track_number: u64, packet_index: usize, cluster_timecode: u64) Error!?audio_common.PacketRecord {
    var cursor: usize = 0;
    while (cursor < block_group.len) {
        const element = try readEbmlElement(block_group, cursor);
        switch (element.id) {
            webm_ebml_id_block => {
                const block = try readWebmBlock(element.payload);
                if (block.track_number == track_number) {
                    return .{
                        .packet = try webmPacketFromBlock(header, packet_index, block, cluster_timecode),
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

fn webmPacketFromBlock(header: Header, packet_index: usize, block: WebmBlock, cluster_timecode: u64) Error!Packet {
    return .{
        .header = header,
        .index = packet_index,
        .timestamp = try applyWebmRelativeTimecode(cluster_timecode, block.relative_timecode),
        .payload = block.payload,
    };
}

fn readWebmBlock(payload: []const u8) Error!WebmBlock {
    const track = try readEbmlVint(payload, 0, true);
    const header_size = std.math.add(usize, track.size, 3) catch return error.BadAudio;
    if (payload.len < header_size) return error.BadAudio;
    const timecode_index = track.size;
    const relative_timecode = readSignedI16Be(payload[timecode_index..][0..2]);
    const flags = payload[timecode_index + 2];
    if ((flags & webm_no_lacing_mask) != 0) return error.UnsupportedAudio;
    return .{
        .track_number = track.value,
        .relative_timecode = relative_timecode,
        .payload = payload[header_size..],
    };
}

fn applyWebmRelativeTimecode(cluster_timecode: u64, relative_timecode: i16) Error!u64 {
    if (relative_timecode >= 0) {
        return std.math.add(u64, cluster_timecode, @intCast(relative_timecode)) catch error.BadAudio;
    }
    const delta: u16 = @intCast(-relative_timecode);
    if (cluster_timecode < delta) return error.BadAudio;
    return cluster_timecode - delta;
}

fn readSignedI16Be(bytes: []const u8) i16 {
    std.debug.assert(bytes.len == 2);
    const unsigned = (@as(u16, bytes[0]) << 8) | @as(u16, bytes[1]);
    return @bitCast(unsigned);
}

fn readEbmlElement(bytes: []const u8, cursor: usize) Error!Element {
    const id = try readEbmlId(bytes, cursor);
    const size = try readEbmlVint(bytes, cursor + id.size, true);
    if (size.value > ~@as(usize, 0)) return error.BadAudio;
    const payload_start = std.math.add(usize, cursor + id.size, size.size) catch return error.BadAudio;
    const payload_end = std.math.add(usize, payload_start, @as(usize, @intCast(size.value))) catch return error.BadAudio;
    if (payload_end > bytes.len) return error.BadAudio;
    return .{
        .id = id.value,
        .payload = bytes[payload_start..payload_end],
        .payload_start = payload_start,
        .next_cursor = payload_end,
    };
}

fn readEbmlId(bytes: []const u8, cursor: usize) Error!VInt {
    const value = try readEbmlVint(bytes, cursor, false);
    if (value.value == 0) return error.BadAudio;
    return value;
}

fn readEbmlVint(bytes: []const u8, cursor: usize, remove_marker: bool) Error!VInt {
    if (cursor >= bytes.len) return error.BadAudio;
    const first = bytes[cursor];
    if (first == 0) return error.BadAudio;
    const size = ebmlVintSize(first) orelse return error.BadAudio;
    if (size > webm_ebml_max_vint_bytes or bytes.len - cursor < size) return error.BadAudio;
    const marker_mask: u8 = if (size == webm_ebml_max_vint_bytes) 0 else webm_ebml_vint_full_byte >> @intCast(size);
    var value: u64 = if (remove_marker) first & marker_mask else first;
    var index: usize = 1;
    while (index < size) : (index += 1) {
        value = (value << 8) | bytes[cursor + index];
    }
    if (remove_marker and isUnknownEbmlSize(value, size)) return error.UnsupportedAudio;
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
    if (payload.len == 0 or payload.len > @sizeOf(u64)) return error.BadAudio;
    var value: u64 = 0;
    for (payload) |byte| {
        value = (value << 8) | byte;
    }
    return value;
}

fn readEbmlFloat(payload: []const u8) Error!f64 {
    return switch (payload.len) {
        @sizeOf(f32) => @floatCast(@as(f32, @bitCast(readU32Be(payload)))),
        @sizeOf(f64) => @bitCast(readU64Be(payload)),
        else => error.BadAudio,
    };
}

fn readU32Be(bytes: []const u8) u32 {
    std.debug.assert(bytes.len == 4);
    return (@as(u32, bytes[0]) << 24) |
        (@as(u32, bytes[1]) << 16) |
        (@as(u32, bytes[2]) << 8) |
        bytes[3];
}

fn readU64Be(bytes: []const u8) u64 {
    std.debug.assert(bytes.len == 8);
    var value: u64 = 0;
    for (bytes) |byte| {
        value = (value << 8) | byte;
    }
    return value;
}

test "webm audio ebml vint parser accepts eight byte finite sizes" {
    const parsed = try readEbmlVint(&.{ 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10, 0x00 }, 0, true);
    try std.testing.expectEqual(@as(usize, webm_ebml_max_vint_bytes), parsed.size);
    try std.testing.expectEqual(@as(u64, 0x1000), parsed.value);
}
