const bytes_mod = @import("../bytes.zig");
const media_common = @import("common.zig");
const video_common = @import("video_common.zig");

pub const Error = video_common.Error;
pub const Format = video_common.Format;
pub const Codec = video_common.Codec;
pub const Header = video_common.Header;
pub const Frame = video_common.Frame;
pub const FrameRecord = video_common.FrameRecord;

pub const signature = "DKIF";
pub const header_size: usize = 32;
pub const codec_index: usize = 8;
pub const codec_size: usize = 4;
pub const width_index: usize = 12;
pub const height_index: usize = 14;
pub const frame_count_index: usize = 24;
pub const frame_header_size: usize = 12;
pub const frame_size_index: usize = 0;
pub const frame_timestamp_index: usize = 4;
pub const codec_vp8 = "VP80";

pub fn is(bytes: []const u8) bool {
    return bytes.len >= signature.len and bytes_mod.eql(bytes[0..signature.len], signature);
}

pub fn decodeHeader(bytes: []const u8) Error!Header {
    if (!is(bytes)) return error.UnsupportedVideo;
    if (bytes.len < header_size) return error.BadVideo;
    const codec = decodeCodec(bytes[codec_index..][0..codec_size]) orelse return error.UnsupportedVideo;
    const width = media_common.readU16Le(bytes[width_index..][0..2]);
    const height = media_common.readU16Le(bytes[height_index..][0..2]);
    if (width == 0 or height == 0) return error.BadVideo;
    return .{
        .format = .ivf,
        .codec = codec,
        .width = width,
        .height = height,
        .frame_count = media_common.readU32Le(bytes[frame_count_index..][0..4]),
    };
}

fn decodeCodec(codec: []const u8) ?Codec {
    if (bytes_mod.eql(codec, codec_vp8)) return .vp8;
    return null;
}

pub fn readFrame(bytes: []const u8, frame_index: usize) Error!Frame {
    const header = try decodeHeader(bytes);
    if (header.frame_count) |count| {
        if (frame_index >= count) return error.BadVideo;
    }

    var cursor: usize = header_size;
    var index: usize = 0;
    while (cursor < bytes.len) : (index += 1) {
        const record = try readFrameRecord(bytes, header, cursor, index);
        if (index == frame_index) {
            return record.frame;
        }
        cursor = record.next_cursor;
    }
    return error.BadVideo;
}

pub fn readFrameRecord(bytes: []const u8, header: Header, cursor: usize, index: usize) Error!FrameRecord {
    if (cursor > bytes.len) return error.BadVideo;
    if (bytes.len - cursor < frame_header_size) return error.BadVideo;
    const frame_size: usize = media_common.readU32Le(bytes[cursor + frame_size_index ..][0..4]);
    const timestamp = media_common.readU64Le(bytes[cursor + frame_timestamp_index ..][0..8]);
    const payload_start = cursor + frame_header_size;
    const payload_end = media_common.checkedAdd(payload_start, frame_size) catch return error.BadVideo;
    if (payload_end > bytes.len) return error.BadVideo;
    return .{
        .frame = .{
            .header = header,
            .index = index,
            .timestamp = timestamp,
            .payload = bytes[payload_start..payload_end],
        },
        .next_cursor = payload_end,
    };
}
