const common = @import("common.zig");
const std = @import("std");

const readU24Le = common.readU24Le;
const readU16Le = common.readU16Le;

pub const Error = common.DecodeError;
pub const Header = common.Header;

pub const FrameType = enum {
    key,
    inter,
};

pub const FrameTag = struct {
    frame_type: FrameType,
    version: u32,
    show_frame: bool,
    first_partition_len: usize,
};

pub const KeyFramePayload = struct {
    header: Header,
    tag: FrameTag,
    first_partition: []const u8,
    token_partitions: []const u8,
};

pub const frame_tag_size: usize = 3;
pub const key_frame_header_size: usize = 10;
const frame_type_key: u32 = 0;
const max_version: u32 = 3;
const show_frame: u32 = 1;
const first_part_size_shift: u5 = 5;
const first_partition_len_bits: u5 = 19;
const max_first_partition_len: usize = (@as(usize, 1) << first_partition_len_bits) - 1;
const frame_type_mask: u32 = 0x01;
const version_mask: u32 = 0x0e;
const version_shift: u5 = 1;
const show_frame_mask: u32 = 0x10;
const show_frame_shift: u5 = 4;
const start_code_offset: usize = 3;
const key_frame_start_code = [_]u8{ 0x9d, 0x01, 0x2a };
const dimension_mask: u16 = 0x3fff;

pub fn parseFrameTag(data: []const u8) Error!FrameTag {
    if (data.len < frame_tag_size) return error.BadImage;
    const tag = readU24Le(data[0..frame_tag_size]);
    const version = (tag & version_mask) >> version_shift;
    const visible = (tag & show_frame_mask) >> show_frame_shift;
    if (version > max_version) return error.UnsupportedImage;
    if (visible != show_frame) return error.UnsupportedImage;
    return .{
        .frame_type = if ((tag & frame_type_mask) == frame_type_key) .key else .inter,
        .version = version,
        .show_frame = true,
        .first_partition_len = @intCast(tag >> first_part_size_shift),
    };
}

pub fn writeVisibleKeyFrameTag(bytes: *[frame_tag_size]u8, first_partition_len: usize) Error!void {
    return writeVisibleFrameTag(bytes, .key, first_partition_len);
}

pub fn writeVisibleInterFrameTag(bytes: *[frame_tag_size]u8, first_partition_len: usize) Error!void {
    return writeVisibleFrameTag(bytes, .inter, first_partition_len);
}

fn writeVisibleFrameTag(bytes: *[frame_tag_size]u8, frame_type: FrameType, first_partition_len: usize) Error!void {
    if (first_partition_len > max_first_partition_len) return error.BadImage;
    const frame_type_bit: u32 = switch (frame_type) {
        .key => 0,
        .inter => frame_type_mask,
    };
    const frame_tag = frame_type_bit | @as(u32, show_frame_mask) | (@as(u32, @intCast(first_partition_len)) << first_part_size_shift);
    bytes[0] = @intCast(frame_tag & 0xff);
    bytes[1] = @intCast((frame_tag >> 8) & 0xff);
    bytes[2] = @intCast((frame_tag >> 16) & 0xff);
}

pub fn isKeyFrame(data: []const u8) Error!bool {
    return (try parseFrameTag(data)).frame_type == .key;
}

pub fn parseKeyFrameHeader(data: []const u8) Error!Header {
    const tag = try parseFrameTag(data);
    return parseKeyFrameHeaderWithTag(data, tag);
}

pub fn parseKeyFramePayload(data: []const u8) Error!KeyFramePayload {
    const tag = try parseFrameTag(data);
    const header = try parseKeyFrameHeaderWithTag(data, tag);
    if (tag.first_partition_len == 0) return error.BadImage;
    if (tag.first_partition_len > data.len - key_frame_header_size) return error.BadImage;
    const first_partition_start = key_frame_header_size;
    const first_partition_end = first_partition_start + tag.first_partition_len;
    return .{
        .header = header,
        .tag = tag,
        .first_partition = data[first_partition_start..first_partition_end],
        .token_partitions = data[first_partition_end..],
    };
}

fn parseKeyFrameHeaderWithTag(data: []const u8, tag: FrameTag) Error!Header {
    if (data.len < key_frame_header_size) return error.BadImage;
    switch (tag.frame_type) {
        .key => {},
        .inter => return error.UnsupportedImage,
    }
    if (!std.mem.eql(u8, data[start_code_offset..][0..key_frame_start_code.len], &key_frame_start_code)) return error.BadImage;
    const width = @as(usize, readU16Le(data[6..][0..2]) & dimension_mask);
    const height = @as(usize, readU16Le(data[8..][0..2]) & dimension_mask);
    if (width == 0 or height == 0) return error.BadImage;
    return .{ .width = width, .height = height };
}

test "vp8 frame tag parser classifies visible frames" {
    const key = try parseFrameTag(&[_]u8{ 0x30, 0x00, 0x00 });
    try std.testing.expectEqual(FrameType.key, key.frame_type);
    try std.testing.expectEqual(@as(u32, 0), key.version);
    try std.testing.expectEqual(true, key.show_frame);
    try std.testing.expectEqual(@as(usize, 1), key.first_partition_len);

    const inter = try parseFrameTag(&[_]u8{ 0x31, 0x00, 0x00 });
    try std.testing.expectEqual(FrameType.inter, inter.frame_type);
    try std.testing.expectEqual(false, try isKeyFrame(&[_]u8{ 0x31, 0x00, 0x00 }));
}

test "vp8 frame tag parser rejects unsupported tags" {
    try std.testing.expectError(error.BadImage, parseFrameTag(&[_]u8{ 0x30, 0x00 }));
    try std.testing.expectError(error.UnsupportedImage, parseFrameTag(&[_]u8{ 0x38, 0x00, 0x00 }));
    try std.testing.expectError(error.UnsupportedImage, parseFrameTag(&[_]u8{ 0x20, 0x00, 0x00 }));
}

test "vp8 frame tag writer emits visible key frames" {
    var bytes: [frame_tag_size]u8 = undefined;
    try writeVisibleKeyFrameTag(&bytes, 160);

    const parsed = try parseFrameTag(&bytes);
    try std.testing.expectEqual(FrameType.key, parsed.frame_type);
    try std.testing.expectEqual(@as(u32, 0), parsed.version);
    try std.testing.expectEqual(true, parsed.show_frame);
    try std.testing.expectEqual(@as(usize, 160), parsed.first_partition_len);
}

test "vp8 frame tag writer emits visible inter frames" {
    var bytes: [frame_tag_size]u8 = undefined;
    try writeVisibleInterFrameTag(&bytes, 19);

    const parsed = try parseFrameTag(&bytes);
    try std.testing.expectEqual(FrameType.inter, parsed.frame_type);
    try std.testing.expectEqual(@as(u32, 0), parsed.version);
    try std.testing.expectEqual(true, parsed.show_frame);
    try std.testing.expectEqual(@as(usize, 19), parsed.first_partition_len);
}

test "vp8 frame tag writer rejects out of range first partition sizes" {
    var bytes: [frame_tag_size]u8 = undefined;
    try std.testing.expectError(error.BadImage, writeVisibleKeyFrameTag(&bytes, max_first_partition_len + 1));
}

test "vp8 keyframe header parser exposes dimensions" {
    const header = try parseKeyFrameHeader(&[_]u8{
        0x30, 0x00, 0x00, 0x9d, 0x01, 0x2a, 0x02, 0x00, 0x03, 0x00,
    });
    try std.testing.expectEqual(@as(usize, 2), header.width);
    try std.testing.expectEqual(@as(usize, 3), header.height);
}

test "vp8 keyframe payload parser exposes partition boundaries" {
    var data = [_]u8{
        0x00, 0x00, 0x00, 0x9d, 0x01, 0x2a, 0x02, 0x00, 0x03, 0x00,
        0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff,
    };
    try writeVisibleKeyFrameTag(data[0..frame_tag_size], 4);

    const payload = try parseKeyFramePayload(&data);
    try std.testing.expectEqual(@as(usize, 2), payload.header.width);
    try std.testing.expectEqual(@as(usize, 3), payload.header.height);
    try std.testing.expectEqual(@as(usize, 4), payload.tag.first_partition_len);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xaa, 0xbb, 0xcc, 0xdd }, payload.first_partition);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xee, 0xff }, payload.token_partitions);
}

test "vp8 keyframe payload parser rejects malformed first partition sizes" {
    var empty_partition = [_]u8{
        0x00, 0x00, 0x00, 0x9d, 0x01, 0x2a, 0x02, 0x00, 0x03, 0x00,
    };
    try writeVisibleKeyFrameTag(empty_partition[0..frame_tag_size], 0);
    try std.testing.expectError(error.BadImage, parseKeyFramePayload(&empty_partition));

    var oversized_partition = [_]u8{
        0x00, 0x00, 0x00, 0x9d, 0x01, 0x2a, 0x02, 0x00, 0x03, 0x00,
        0xaa,
    };
    try writeVisibleKeyFrameTag(oversized_partition[0..frame_tag_size], 2);
    try std.testing.expectError(error.BadImage, parseKeyFramePayload(&oversized_partition));
}

test "vp8 keyframe header parser rejects malformed headers" {
    try std.testing.expectError(error.BadImage, parseKeyFrameHeader(&[_]u8{ 0x30, 0x00, 0x00 }));
    try std.testing.expectError(error.UnsupportedImage, parseKeyFrameHeader(&[_]u8{
        0x31, 0x00, 0x00, 0x9d, 0x01, 0x2a, 0x02, 0x00, 0x03, 0x00,
    }));
    try std.testing.expectError(error.BadImage, parseKeyFrameHeader(&[_]u8{
        0x30, 0x00, 0x00, 0x9d, 0x01, 0x2b, 0x02, 0x00, 0x03, 0x00,
    }));
}
