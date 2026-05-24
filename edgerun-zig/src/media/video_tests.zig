const std = @import("std");
const ui = @import("../ui.zig");
const video_module = @import("video.zig");
const ivf_container = @import("video_ivf.zig");
const webm_container = @import("video_webm.zig");

const Format = video_module.Format;
const Codec = video_module.Codec;
const Decoder = video_module.Decoder;
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

test "ivf vp8 frame decoder rejects malformed vp8 payload" {
    var pixels: [1]ui.Color = undefined;
    var ivf = [_]u8{0} ** (ivf_container.header_size + ivf_container.frame_header_size + 3);
    @memcpy(ivf[0..ivf_container.signature.len], ivf_container.signature);
    @memcpy(ivf[ivf_container.codec_index..][0..ivf_container.codec_size], ivf_container.codec_vp8);
    ivf[ivf_container.width_index] = 1;
    ivf[ivf_container.height_index] = 1;
    ivf[ivf_container.frame_count_index] = 1;
    ivf[ivf_container.header_size + ivf_container.frame_size_index] = 3;
    ivf[ivf_container.header_size + ivf_container.frame_timestamp_index] = 9;
    @memcpy(ivf[ivf_container.header_size + ivf_container.frame_header_size ..], &test_vp8_truncated_keyframe_payload);

    try std.testing.expectError(error.BadVideo, decodeFrame(&ivf, 0, &pixels, &.{}));
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

test "ivf vp8 frame decoder reconstructs first frame pixels" {
    var ivf = [_]u8{0} ** (ivf_container.header_size + ivf_container.frame_header_size + test_vp8_gray_payload.len);
    @memcpy(ivf[0..ivf_container.signature.len], ivf_container.signature);
    @memcpy(ivf[ivf_container.codec_index..][0..ivf_container.codec_size], ivf_container.codec_vp8);
    ivf[ivf_container.width_index] = 2;
    ivf[ivf_container.height_index] = 2;
    ivf[ivf_container.frame_count_index] = 1;
    ivf[ivf_container.header_size + ivf_container.frame_size_index] = test_vp8_gray_payload.len;
    @memcpy(ivf[ivf_container.header_size + ivf_container.frame_header_size ..], &test_vp8_gray_payload);

    var pixels: [4]ui.Color = undefined;
    const frame = try decodeFrame(&ivf, 0, &pixels, &.{});
    try std.testing.expectEqual(@as(usize, 0), frame.index);
    try std.testing.expectEqual(Codec.vp8, frame.header.codec);
    try expectTestGrayFrame(&pixels);
}

test "ivf decoder stores vp8 reference frames in caller scratch" {
    var ivf = [_]u8{0} ** (ivf_container.header_size + ivf_container.frame_header_size + test_vp8_gray_payload.len);
    @memcpy(ivf[0..ivf_container.signature.len], ivf_container.signature);
    @memcpy(ivf[ivf_container.codec_index..][0..ivf_container.codec_size], ivf_container.codec_vp8);
    ivf[ivf_container.width_index] = 2;
    ivf[ivf_container.height_index] = 2;
    ivf[ivf_container.frame_count_index] = 1;
    ivf[ivf_container.header_size + ivf_container.frame_size_index] = test_vp8_gray_payload.len;
    @memcpy(ivf[ivf_container.header_size + ivf_container.frame_header_size ..], &test_vp8_gray_payload);

    try std.testing.expectEqual(@as(usize, @sizeOf(ui.Color) * 4), scratchByteLen(&ivf, 2, 2));
    var decoder = try Decoder.init(&ivf);
    var pixels: [4]ui.Color = undefined;
    var scratch: [@sizeOf(ui.Color) * 4]u8 = undefined;
    _ = try decoder.nextFrame(&pixels, &scratch);

    try std.testing.expectEqual(true, decoder.frame_state.has_vp8_reference);
    try std.testing.expectEqualSlices(u8, std.mem.sliceAsBytes(&pixels), &scratch);
}

test "ivf vp8 decoder steps sequential frames and resets" {
    const frame_record_size = ivf_container.frame_header_size + test_vp8_gray_payload.len;
    var ivf = [_]u8{0} ** (ivf_container.header_size + 2 * frame_record_size);
    @memcpy(ivf[0..ivf_container.signature.len], ivf_container.signature);
    @memcpy(ivf[ivf_container.codec_index..][0..ivf_container.codec_size], ivf_container.codec_vp8);
    ivf[ivf_container.width_index] = 2;
    ivf[ivf_container.height_index] = 2;
    ivf[ivf_container.frame_count_index] = 2;

    var cursor: usize = ivf_container.header_size;
    writeTestIvfFrame(ivf[cursor..][0..frame_record_size], 11, &test_vp8_gray_payload);
    cursor += frame_record_size;
    writeTestIvfFrame(ivf[cursor..][0..frame_record_size], 12, &test_vp8_gray_payload);

    var decoder = try Decoder.init(&ivf);
    var pixels: [4]ui.Color = undefined;
    const first = (try decoder.nextFrame(&pixels, &.{})).?;
    try std.testing.expectEqual(@as(usize, 0), first.index);
    try std.testing.expectEqual(@as(u64, 11), first.timestamp);
    try expectTestGrayFrame(&pixels);

    const second = (try decoder.nextFrame(&pixels, &.{})).?;
    try std.testing.expectEqual(@as(usize, 1), second.index);
    try std.testing.expectEqual(@as(u64, 12), second.timestamp);
    try expectTestGrayFrame(&pixels);

    try std.testing.expect((try decoder.nextFrame(&pixels, &.{})) == null);
    decoder.reset();
    const first_again = (try decoder.nextFrame(&pixels, &.{})).?;
    try std.testing.expectEqual(@as(usize, 0), first_again.index);
    try std.testing.expectEqual(@as(u64, 11), first_again.timestamp);
}

test "ivf vp8 decoder reconstructs zero-motion interframes from reference" {
    var inter_payload: [test_vp8_inter_zero_payload_len]u8 = undefined;
    const inter_frame = writeTestVp8InterZeroFrame(&inter_payload);
    const first_record_size = ivf_container.frame_header_size + test_vp8_gray_payload.len;
    const second_record_size = ivf_container.frame_header_size + test_vp8_inter_zero_payload_len;
    var ivf = [_]u8{0} ** (ivf_container.header_size + first_record_size + second_record_size);
    @memcpy(ivf[0..ivf_container.signature.len], ivf_container.signature);
    @memcpy(ivf[ivf_container.codec_index..][0..ivf_container.codec_size], ivf_container.codec_vp8);
    ivf[ivf_container.width_index] = 2;
    ivf[ivf_container.height_index] = 2;
    ivf[ivf_container.frame_count_index] = 2;

    var cursor: usize = ivf_container.header_size;
    writeTestIvfFrame(ivf[cursor..][0..first_record_size], 21, &test_vp8_gray_payload);
    cursor += first_record_size;
    writeTestIvfFrame(ivf[cursor..][0..second_record_size], 22, inter_frame);

    var decoder = try Decoder.init(&ivf);
    var pixels: [4]ui.Color = undefined;
    var scratch: [@sizeOf(ui.Color) * 4]u8 = undefined;
    const first = (try decoder.nextFrame(&pixels, &scratch)).?;
    try std.testing.expectEqual(@as(usize, 0), first.index);
    try expectTestGrayFrame(&pixels);

    const second = (try decoder.nextFrame(&pixels, &scratch)).?;
    try std.testing.expectEqual(@as(usize, 1), second.index);
    try std.testing.expectEqual(@as(u64, 22), second.timestamp);
    try expectTestGrayFrame(&pixels);
}

test "ivf header rejects unsupported codec explicitly" {
    var ivf = [_]u8{0} ** ivf_container.header_size;
    @memcpy(ivf[0..ivf_container.signature.len], ivf_container.signature);
    @memcpy(ivf[ivf_container.codec_index..][0..ivf_container.codec_size], "VP90");
    ivf[ivf_container.width_index] = 1;
    ivf[ivf_container.height_index] = 1;
    try std.testing.expectError(error.UnsupportedVideo, decodeHeader(&ivf));
}

test "ivf vp8 frame decoder reconstructs intra-coded interframes" {
    var ivf = [_]u8{0} ** (ivf_container.header_size + ivf_container.frame_header_size + test_vp8_interframe_payload.len);
    @memcpy(ivf[0..ivf_container.signature.len], ivf_container.signature);
    @memcpy(ivf[ivf_container.codec_index..][0..ivf_container.codec_size], ivf_container.codec_vp8);
    ivf[ivf_container.width_index] = 2;
    ivf[ivf_container.height_index] = 2;
    ivf[ivf_container.frame_count_index] = 1;
    ivf[ivf_container.header_size + ivf_container.frame_size_index] = test_vp8_interframe_payload.len;
    @memcpy(ivf[ivf_container.header_size + ivf_container.frame_header_size ..], &test_vp8_interframe_payload);

    var pixels: [4]ui.Color = undefined;
    _ = try decodeFrame(&ivf, 0, &pixels, &.{});
    try expectTestNeutralFrame(&pixels);
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

test "webm vp8 frame decoder reconstructs simpleblock pixels" {
    const webm = try buildTestWebm(std.testing.allocator, false, webm_container.codec_vp8);
    defer std.testing.allocator.free(webm);

    var pixels: [4]ui.Color = undefined;
    const frame = try decodeFrame(webm, 0, &pixels, &.{});
    try std.testing.expectEqual(@as(usize, 0), frame.index);
    try std.testing.expectEqual(@as(u64, 23), frame.timestamp);
    try expectTestGrayFrame(&pixels);
}

test "webm vp8 decoder steps sequential simpleblock frames and resets" {
    const webm = try buildTestWebm(std.testing.allocator, true, webm_container.codec_vp8);
    defer std.testing.allocator.free(webm);

    var decoder = try Decoder.init(webm);
    var pixels: [4]ui.Color = undefined;
    const first = (try decoder.nextFrame(&pixels, &.{})).?;
    try std.testing.expectEqual(@as(usize, 0), first.index);
    try std.testing.expectEqual(@as(u64, 23), first.timestamp);
    try expectTestGrayFrame(&pixels);

    const second = (try decoder.nextFrame(&pixels, &.{})).?;
    try std.testing.expectEqual(@as(usize, 1), second.index);
    try std.testing.expectEqual(@as(u64, 24), second.timestamp);
    try expectTestGrayFrame(&pixels);

    try std.testing.expect((try decoder.nextFrame(&pixels, &.{})) == null);
    decoder.reset();
    const first_again = (try decoder.nextFrame(&pixels, &.{})).?;
    try std.testing.expectEqual(@as(usize, 0), first_again.index);
    try std.testing.expectEqual(@as(u64, 23), first_again.timestamp);
}

test "webm vp8 decoder reconstructs zero-motion interframes from reference" {
    var inter_payload: [test_vp8_inter_zero_payload_len]u8 = undefined;
    const inter_frame = writeTestVp8InterZeroFrame(&inter_payload);
    const webm = try buildTestWebmWithPayloads(std.testing.allocator, &test_vp8_gray_payload, inter_frame, webm_container.codec_vp8);
    defer std.testing.allocator.free(webm);

    var decoder = try Decoder.init(webm);
    var pixels: [4]ui.Color = undefined;
    var scratch: [@sizeOf(ui.Color) * 4]u8 = undefined;
    const first = (try decoder.nextFrame(&pixels, &scratch)).?;
    try std.testing.expectEqual(@as(usize, 0), first.index);
    try expectTestGrayFrame(&pixels);

    const second = (try decoder.nextFrame(&pixels, &scratch)).?;
    try std.testing.expectEqual(@as(usize, 1), second.index);
    try std.testing.expectEqual(@as(u64, 24), second.timestamp);
    try expectTestGrayFrame(&pixels);
}

test "webm vp8 frame decoder reconstructs blockgroup pixels" {
    const webm = try buildTestWebmBlockGroup(std.testing.allocator);
    defer std.testing.allocator.free(webm);

    var pixels: [4]ui.Color = undefined;
    const frame = try decodeFrame(webm, 0, &pixels, &.{});
    try std.testing.expectEqual(@as(usize, 0), frame.index);
    try std.testing.expectEqual(@as(u64, 25), frame.timestamp);
    try expectTestGrayFrame(&pixels);
}

test "webm vp8 decoder keeps cluster cursor bounded" {
    const webm = try buildTestWebmTwoClusters(std.testing.allocator);
    defer std.testing.allocator.free(webm);

    var decoder = try Decoder.init(webm);
    var pixels: [4]ui.Color = undefined;
    const first = (try decoder.nextFrame(&pixels, &.{})).?;
    try std.testing.expectEqual(@as(usize, 0), first.index);
    try std.testing.expectEqual(@as(u64, 33), first.timestamp);
    try expectTestGrayFrame(&pixels);
    try std.testing.expect((try decoder.nextFrame(&pixels, &.{})) == null);
}

test "webm header rejects unsupported codec explicitly" {
    const webm = try buildTestWebm(std.testing.allocator, false, "V_VP9");
    defer std.testing.allocator.free(webm);
    try std.testing.expectError(error.UnsupportedVideo, decodeHeader(webm));
}

test "webm vp8 frame decoder reconstructs intra-coded interframes" {
    const webm = try buildTestWebmWithPayload(std.testing.allocator, &test_vp8_interframe_payload, false, webm_container.codec_vp8);
    defer std.testing.allocator.free(webm);

    var pixels: [4]ui.Color = undefined;
    _ = try decodeFrame(webm, 0, &pixels, &.{});
    try expectTestNeutralFrame(&pixels);
}

const test_vp8_gray_payload = [_]u8{
    0x50, 0x01, 0x00, 0x9d, 0x01, 0x2a, 0x02, 0x00,
    0x02, 0x00, 0x01, 0x40, 0x26, 0x25, 0xa4, 0x00,
    0x04, 0x74, 0x00, 0x00, 0xe4, 0x40, 0x00, 0x00,
};

const test_vp8_interframe_payload = [_]u8{ 0x11, 0x0a, 0x00 } ++ ([_]u8{0x00} ** 80) ++ ([_]u8{0x00} ** 8);
const test_vp8_truncated_keyframe_payload = [_]u8{ 0x30, 0x00, 0x00 };
const test_vp8_inter_zero_payload = [_]u8{
    0x51, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10,
    0x00, 0x30, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x80, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00,
};
const test_vp8_inter_zero_payload_len: usize = test_vp8_inter_zero_payload.len;

fn writeTestIvfFrame(bytes: []u8, timestamp: u8, payload: []const u8) void {
    std.debug.assert(bytes.len == ivf_container.frame_header_size + payload.len);
    @memset(bytes[0..ivf_container.frame_header_size], 0);
    bytes[ivf_container.frame_size_index] = @intCast(payload.len);
    bytes[ivf_container.frame_timestamp_index] = timestamp;
    @memcpy(bytes[ivf_container.frame_header_size..], payload);
}

fn writeTestVp8InterZeroFrame(bytes: *[test_vp8_inter_zero_payload_len]u8) []const u8 {
    @memcpy(bytes, &test_vp8_inter_zero_payload);
    return bytes;
}

fn expectTestGrayFrame(pixels: []const ui.Color) !void {
    try std.testing.expectEqualSlices(ui.Color, &[_]ui.Color{
        .{ .r = 126, .g = 126, .b = 126, .a = 255 },
        .{ .r = 126, .g = 126, .b = 126, .a = 255 },
        .{ .r = 126, .g = 126, .b = 126, .a = 255 },
        .{ .r = 126, .g = 126, .b = 126, .a = 255 },
    }, pixels);
}

fn expectTestNeutralFrame(pixels: []const ui.Color) !void {
    try std.testing.expectEqualSlices(ui.Color, &[_]ui.Color{
        .{ .r = 128, .g = 128, .b = 128, .a = 255 },
        .{ .r = 128, .g = 128, .b = 128, .a = 255 },
        .{ .r = 128, .g = 128, .b = 128, .a = 255 },
        .{ .r = 128, .g = 128, .b = 128, .a = 255 },
    }, pixels);
}

fn buildTestWebm(allocator: std.mem.Allocator, two_frames: bool, codec_id: []const u8) ![]u8 {
    return buildTestWebmWithPayload(allocator, &test_vp8_gray_payload, two_frames, codec_id);
}

fn buildTestWebmBlockGroup(allocator: std.mem.Allocator) ![]u8 {
    return buildTestWebmContainer(allocator, &test_vp8_gray_payload, false, webm_container.codec_vp8, true);
}

fn buildTestWebmTwoClusters(allocator: std.mem.Allocator) ![]u8 {
    var segment: std.ArrayList(u8) = .empty;
    defer segment.deinit(allocator);
    try appendTestWebmTracks(allocator, &segment, webm_container.codec_vp8);
    try appendTestWebmCluster(allocator, &segment, &test_vp8_gray_payload, 20, &.{}, false);
    try appendTestWebmCluster(allocator, &segment, &test_vp8_gray_payload, 30, &[_]u8{3}, false);
    return buildTestWebmFromSegment(allocator, segment.items);
}

fn buildTestWebmWithPayload(allocator: std.mem.Allocator, payload: []const u8, two_frames: bool, codec_id: []const u8) ![]u8 {
    return buildTestWebmContainer(allocator, payload, two_frames, codec_id, false);
}

fn buildTestWebmWithPayloads(allocator: std.mem.Allocator, first_payload: []const u8, second_payload: []const u8, codec_id: []const u8) ![]u8 {
    var segment: std.ArrayList(u8) = .empty;
    defer segment.deinit(allocator);
    try appendTestWebmTracks(allocator, &segment, codec_id);
    try appendTestWebmClusterPayloads(allocator, &segment, first_payload, second_payload, 20, 3, 4);
    return buildTestWebmFromSegment(allocator, segment.items);
}

fn buildTestWebmContainer(allocator: std.mem.Allocator, payload: []const u8, two_frames: bool, codec_id: []const u8, block_group: bool) ![]u8 {
    var segment: std.ArrayList(u8) = .empty;
    defer segment.deinit(allocator);
    try appendTestWebmTracks(allocator, &segment, codec_id);
    if (two_frames) {
        try appendTestWebmCluster(allocator, &segment, payload, 20, &[_]u8{ 3, 4 }, block_group);
    } else {
        try appendTestWebmCluster(allocator, &segment, payload, 20, &[_]u8{if (block_group) 5 else 3}, block_group);
    }
    return buildTestWebmFromSegment(allocator, segment.items);
}

fn appendTestWebmTracks(allocator: std.mem.Allocator, segment: *std.ArrayList(u8), codec_id: []const u8) !void {
    var track_entry: std.ArrayList(u8) = .empty;
    defer track_entry.deinit(allocator);
    try appendTestEbmlElement(allocator, &track_entry, &[_]u8{0xd7}, &[_]u8{1});
    try appendTestEbmlElement(allocator, &track_entry, &[_]u8{0x83}, &[_]u8{@intCast(webm_container.track_type_video)});
    try appendTestEbmlElement(allocator, &track_entry, &[_]u8{0x86}, codec_id);

    var video_elements: std.ArrayList(u8) = .empty;
    defer video_elements.deinit(allocator);
    try appendTestEbmlElement(allocator, &video_elements, &[_]u8{0xb0}, &[_]u8{2});
    try appendTestEbmlElement(allocator, &video_elements, &[_]u8{0xba}, &[_]u8{2});
    try appendTestEbmlElement(allocator, &track_entry, &[_]u8{0xe0}, video_elements.items);

    var tracks: std.ArrayList(u8) = .empty;
    defer tracks.deinit(allocator);
    try appendTestEbmlElement(allocator, &tracks, &[_]u8{0xae}, track_entry.items);
    try appendTestEbmlElement(allocator, segment, &[_]u8{ 0x16, 0x54, 0xae, 0x6b }, tracks.items);
}

fn appendTestWebmCluster(allocator: std.mem.Allocator, segment: *std.ArrayList(u8), payload: []const u8, timecode: u8, relative_timecodes: []const u8, block_group: bool) !void {
    var block: std.ArrayList(u8) = .empty;
    defer block.deinit(allocator);

    var cluster: std.ArrayList(u8) = .empty;
    defer cluster.deinit(allocator);
    try appendTestEbmlElement(allocator, &cluster, &[_]u8{0xe7}, &[_]u8{timecode});

    for (relative_timecodes) |relative_timecode| {
        block.clearRetainingCapacity();
        try appendTestWebmBlockPayload(allocator, &block, relative_timecode, payload);
        if (block_group) {
            var group: std.ArrayList(u8) = .empty;
            defer group.deinit(allocator);
            try appendTestEbmlElement(allocator, &group, &[_]u8{0xa1}, block.items);
            try appendTestEbmlElement(allocator, &cluster, &[_]u8{0xa0}, group.items);
        } else {
            try appendTestEbmlElement(allocator, &cluster, &[_]u8{0xa3}, block.items);
        }
    }

    try appendTestEbmlElement(allocator, segment, &[_]u8{ 0x1f, 0x43, 0xb6, 0x75 }, cluster.items);
}

fn appendTestWebmClusterPayloads(
    allocator: std.mem.Allocator,
    segment: *std.ArrayList(u8),
    first_payload: []const u8,
    second_payload: []const u8,
    timecode: u8,
    first_relative_timecode: u8,
    second_relative_timecode: u8,
) !void {
    var block: std.ArrayList(u8) = .empty;
    defer block.deinit(allocator);

    var cluster: std.ArrayList(u8) = .empty;
    defer cluster.deinit(allocator);
    try appendTestEbmlElement(allocator, &cluster, &[_]u8{0xe7}, &[_]u8{timecode});

    try appendTestWebmBlockPayload(allocator, &block, first_relative_timecode, first_payload);
    try appendTestEbmlElement(allocator, &cluster, &[_]u8{0xa3}, block.items);

    block.clearRetainingCapacity();
    try appendTestWebmBlockPayload(allocator, &block, second_relative_timecode, second_payload);
    try appendTestEbmlElement(allocator, &cluster, &[_]u8{0xa3}, block.items);

    try appendTestEbmlElement(allocator, segment, &[_]u8{ 0x1f, 0x43, 0xb6, 0x75 }, cluster.items);
}

fn buildTestWebmFromSegment(allocator: std.mem.Allocator, segment: []const u8) ![]u8 {
    var webm: std.ArrayList(u8) = .empty;
    errdefer webm.deinit(allocator);
    try appendTestEbmlElement(allocator, &webm, &[_]u8{ 0x1a, 0x45, 0xdf, 0xa3 }, &.{});
    try appendTestEbmlElement(allocator, &webm, &[_]u8{ 0x18, 0x53, 0x80, 0x67 }, segment);
    return webm.toOwnedSlice(allocator);
}

fn appendTestWebmBlockPayload(allocator: std.mem.Allocator, block: *std.ArrayList(u8), relative_timecode: u8, payload: []const u8) !void {
    try block.append(allocator, 0x81);
    try block.append(allocator, 0);
    try block.append(allocator, relative_timecode);
    try block.append(allocator, 0x80);
    try block.appendSlice(allocator, payload);
}

fn appendTestEbmlElement(allocator: std.mem.Allocator, list: *std.ArrayList(u8), id: []const u8, payload: []const u8) !void {
    try list.appendSlice(allocator, id);
    try appendTestEbmlSize(allocator, list, payload.len);
    try list.appendSlice(allocator, payload);
}

fn appendTestEbmlSize(allocator: std.mem.Allocator, list: *std.ArrayList(u8), payload_len: usize) !void {
    if (payload_len < 0x7f) {
        try list.append(allocator, 0x80 | @as(u8, @intCast(payload_len)));
        return;
    }
    if (payload_len >= 0x3fff) return error.BadVideo;
    const high: u8 = @intCast(payload_len >> 8);
    const low: u8 = @intCast(payload_len & 0xff);
    try list.append(allocator, 0x40 | high);
    try list.append(allocator, low);
}
