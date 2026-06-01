const std = @import("er_std");
const ui = @import("../ui/core.zig");
const video_module = @import("video.zig");
const ivf_container = @import("video_ivf.zig");
const webm_container = @import("video_webm.zig");
const webm_test = @import("test_webm_builder.zig");

const Format = video_module.Format;
const Codec = video_module.Codec;
const detectFormat = video_module.detectFormat;
const decodeHeader = video_module.decodeHeader;
const decodeFrame = video_module.decodeFrame;
const readFrame = video_module.readFrame;
const scratchByteLen = video_module.scratchByteLen;

test "video format detection is explicit" {
    try std.testing.expectEqual(Format.webm, try detectFormat(&webm_container.signature));

    var ivf = [_]u8{0} ** ivf_container.header_size;
    @memcpy(ivf[0..ivf_container.signature.len], ivf_container.signature);
    @memcpy(ivf[ivf_container.codec_index..][0..ivf_container.codec_size], ivf_container.codec_vp8);
    try std.testing.expectEqual(Format.ivf, try detectFormat(&ivf));

    try std.testing.expectError(error.UnsupportedVideo, detectFormat("not media"));
}

test "ivf header exposes deterministic dimensions and frame count" {
    var ivf = [_]u8{0} ** ivf_container.header_size;
    @memcpy(ivf[0..ivf_container.signature.len], ivf_container.signature);
    @memcpy(ivf[ivf_container.codec_index..][0..ivf_container.codec_size], ivf_container.codec_vp8);
    ivf[ivf_container.width_index] = 64;
    ivf[ivf_container.height_index] = 32;
    ivf[ivf_container.frame_count_index] = 7;

    const header = try decodeHeader(&ivf);
    try std.testing.expectEqual(Format.ivf, header.format);
    try std.testing.expectEqual(Codec.vp8, header.codec);
    try std.testing.expectEqual(@as(usize, 64), header.width);
    try std.testing.expectEqual(@as(usize, 32), header.height);
    try std.testing.expectEqual(@as(?usize, 7), header.frame_count);
}

test "ivf frame parser exposes payload and timestamp" {
    var ivf = [_]u8{0} ** (ivf_container.header_size + ivf_container.frame_header_size + 2 + ivf_container.frame_header_size + 3);
    @memcpy(ivf[0..ivf_container.signature.len], ivf_container.signature);
    @memcpy(ivf[ivf_container.codec_index..][0..ivf_container.codec_size], ivf_container.codec_vp8);
    ivf[ivf_container.width_index] = 16;
    ivf[ivf_container.height_index] = 9;
    ivf[ivf_container.frame_count_index] = 2;

    var cursor: usize = ivf_container.header_size;
    ivf[cursor + ivf_container.frame_size_index] = 2;
    ivf[cursor + ivf_container.frame_timestamp_index] = 5;
    @memcpy(ivf[cursor + ivf_container.frame_header_size ..][0..2], &[_]u8{ 0xaa, 0xbb });
    cursor += ivf_container.frame_header_size + 2;
    ivf[cursor + ivf_container.frame_size_index] = 3;
    ivf[cursor + ivf_container.frame_timestamp_index] = 6;
    @memcpy(ivf[cursor + ivf_container.frame_header_size ..][0..3], &[_]u8{ 0xcc, 0xdd, 0xee });

    const frame = try readFrame(&ivf, 1);
    try std.testing.expectEqual(@as(usize, 1), frame.index);
    try std.testing.expectEqual(@as(u64, 6), frame.timestamp);
    try std.testing.expectEqual(@as(usize, 16), frame.header.width);
    try std.testing.expectEqual(@as(usize, 9), frame.header.height);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xcc, 0xdd, 0xee }, frame.payload);
}

test "ivf frame parser rejects truncated frame records" {
    var missing_payload = [_]u8{0} ** (ivf_container.header_size + ivf_container.frame_header_size + 1);
    @memcpy(missing_payload[0..ivf_container.signature.len], ivf_container.signature);
    @memcpy(missing_payload[ivf_container.codec_index..][0..ivf_container.codec_size], ivf_container.codec_vp8);
    missing_payload[ivf_container.width_index] = 1;
    missing_payload[ivf_container.height_index] = 1;
    missing_payload[ivf_container.frame_count_index] = 1;
    missing_payload[ivf_container.header_size + ivf_container.frame_size_index] = 2;
    try std.testing.expectError(error.BadVideo, readFrame(&missing_payload, 0));

    var missing_header = [_]u8{0} ** (ivf_container.header_size + ivf_container.frame_header_size - 1);
    @memcpy(missing_header[0..ivf_container.signature.len], ivf_container.signature);
    @memcpy(missing_header[ivf_container.codec_index..][0..ivf_container.codec_size], ivf_container.codec_vp8);
    missing_header[ivf_container.width_index] = 1;
    missing_header[ivf_container.height_index] = 1;
    missing_header[ivf_container.frame_count_index] = 1;
    try std.testing.expectError(error.BadVideo, readFrame(&missing_header, 0));
}

test "ivf header rejects unsupported codec explicitly" {
    var ivf = [_]u8{0} ** ivf_container.header_size;
    @memcpy(ivf[0..ivf_container.signature.len], ivf_container.signature);
    @memcpy(ivf[ivf_container.codec_index..][0..ivf_container.codec_size], "VP90");
    ivf[ivf_container.width_index] = 1;
    ivf[ivf_container.height_index] = 1;
    try std.testing.expectError(error.UnsupportedVideo, decodeHeader(&ivf));
}

test "webm header exposes vp8 track dimensions" {
    const webm = try buildTestWebm(std.testing.allocator, false, webm_container.codec_vp8);
    defer std.testing.allocator.free(webm);

    const header = try decodeHeader(webm);
    try std.testing.expectEqual(Format.webm, header.format);
    try std.testing.expectEqual(Codec.vp8, header.codec);
    try std.testing.expectEqual(@as(usize, 2), header.width);
    try std.testing.expectEqual(@as(usize, 2), header.height);
    try std.testing.expectEqual(@as(?usize, null), header.frame_count);
}

test "webm header rejects unsupported codec explicitly" {
    const webm = try buildTestWebm(std.testing.allocator, false, "V_VP9");
    defer std.testing.allocator.free(webm);
    try std.testing.expectError(error.UnsupportedVideo, decodeHeader(webm));
}

test "app-side vp8 decode is owned by host asm" {
    var pixels: [1]ui.Color = undefined;
    var ivf = [_]u8{0} ** (ivf_container.header_size + ivf_container.frame_header_size + 3);
    @memcpy(ivf[0..ivf_container.signature.len], ivf_container.signature);
    @memcpy(ivf[ivf_container.codec_index..][0..ivf_container.codec_size], ivf_container.codec_vp8);
    ivf[ivf_container.width_index] = 1;
    ivf[ivf_container.height_index] = 1;
    ivf[ivf_container.frame_count_index] = 1;
    ivf[ivf_container.header_size + ivf_container.frame_size_index] = 3;
    try std.testing.expectEqual(@as(usize, 0), scratchByteLen(&ivf, 1, 1));
    try std.testing.expectError(error.UnsupportedVideo, decodeFrame(&ivf, 0, &pixels, &.{}));
}

fn buildTestWebm(allocator: std.mem.Allocator, two_frames: bool, codec: []const u8) ![]u8 {
    var segment: std.ArrayList(u8) = .empty;
    defer segment.deinit(allocator);
    try webm_test.appendTracks(allocator, &segment, &.{.{ .video = .{ .codec_id = codec, .width = 2, .height = 2 } }});
    const blocks = if (two_frames)
        &[_]webm_test.ClusterBlock{
            .{ .payload = &.{ 0x50, 0x01, 0x00 }, .relative_timecode = 23 },
            .{ .payload = &.{ 0x50, 0x01, 0x00 }, .relative_timecode = 24 },
        }
    else
        &[_]webm_test.ClusterBlock{.{ .payload = &.{ 0x50, 0x01, 0x00 }, .relative_timecode = 23 }};
    try webm_test.appendCluster(allocator, &segment, .video, 0, blocks, false);
    return webm_test.finish(allocator, segment.items);
}
