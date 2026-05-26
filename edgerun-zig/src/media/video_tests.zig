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
    var scratch: [test_vp8_gray_reference_len]u8 = undefined;
    const frame = try decodeFrame(&ivf, 0, &pixels, &scratch);
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

    const rgba_reference_len = @sizeOf(ui.Color) * 4;
    const yuv_reference_len = 6;
    const reference_len = rgba_reference_len + yuv_reference_len * 4;
    try std.testing.expectEqual(@as(usize, reference_len), scratchByteLen(&ivf, 2, 2));
    var decoder = try Decoder.init(&ivf);
    var pixels: [4]ui.Color = undefined;
    var scratch: [reference_len]u8 = undefined;
    _ = try decoder.nextFrame(&pixels, &scratch);

    try std.testing.expectEqual(true, decoder.frame_state.has_vp8_reference);
    try std.testing.expectEqualSlices(u8, std.mem.sliceAsBytes(&pixels), scratch[0..rgba_reference_len]);
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
    var scratch: [test_vp8_gray_reference_len]u8 = undefined;
    const first = (try decoder.nextFrame(&pixels, &scratch)).?;
    try std.testing.expectEqual(@as(usize, 0), first.index);
    try std.testing.expectEqual(@as(u64, 11), first.timestamp);
    try expectTestGrayFrame(&pixels);

    const second = (try decoder.nextFrame(&pixels, &scratch)).?;
    try std.testing.expectEqual(@as(usize, 1), second.index);
    try std.testing.expectEqual(@as(u64, 12), second.timestamp);
    try expectTestGrayFrame(&pixels);

    try std.testing.expect((try decoder.nextFrame(&pixels, &scratch)) == null);
    decoder.reset();
    const first_again = (try decoder.nextFrame(&pixels, &scratch)).?;
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
    var scratch: [test_vp8_gray_reference_len]u8 = undefined;
    const first = (try decoder.nextFrame(&pixels, &scratch)).?;
    try std.testing.expectEqual(@as(usize, 0), first.index);
    try expectTestGrayFrame(&pixels);
    try std.testing.expectEqualSlices(u8, std.mem.sliceAsBytes(&pixels), scratch[0 .. @sizeOf(ui.Color) * 4]);

    const second = (try decoder.nextFrame(&pixels, &scratch)).?;
    try std.testing.expectEqual(@as(usize, 1), second.index);
    try std.testing.expectEqual(@as(u64, 22), second.timestamp);
    try expectTestGrayFrame(&pixels);
}

test "ivf vp8 decoder reconstructs multi-macroblock zero-motion interframes" {
    var inter_payload: [test_vp8_inter_zero_payload_len]u8 = undefined;
    const inter_frame = writeTestVp8InterZeroFrame(&inter_payload);
    const first_record_size = ivf_container.frame_header_size + test_vp8_wide_gray_payload.len;
    const second_record_size = ivf_container.frame_header_size + test_vp8_inter_zero_payload_len;
    var ivf = [_]u8{0} ** (ivf_container.header_size + first_record_size + second_record_size);
    @memcpy(ivf[0..ivf_container.signature.len], ivf_container.signature);
    @memcpy(ivf[ivf_container.codec_index..][0..ivf_container.codec_size], ivf_container.codec_vp8);
    ivf[ivf_container.width_index] = test_vp8_wide_gray_width;
    ivf[ivf_container.height_index] = test_vp8_wide_gray_height;
    ivf[ivf_container.frame_count_index] = 2;

    var cursor: usize = ivf_container.header_size;
    writeTestIvfFrame(ivf[cursor..][0..first_record_size], 31, &test_vp8_wide_gray_payload);
    cursor += first_record_size;
    writeTestIvfFrame(ivf[cursor..][0..second_record_size], 32, inter_frame);

    var decoder = try Decoder.init(&ivf);
    var pixels: [test_vp8_wide_gray_width * test_vp8_wide_gray_height]ui.Color = undefined;
    var scratch: [test_vp8_wide_gray_reference_len]u8 = undefined;
    _ = (try decoder.nextFrame(&pixels, &scratch)).?;
    try expectTestWideGrayFrame(&pixels);

    const second = (try decoder.nextFrame(&pixels, &scratch)).?;
    try std.testing.expectEqual(@as(usize, 1), second.index);
    try std.testing.expectEqual(@as(u64, 32), second.timestamp);
    try expectTestWideGrayFrame(&pixels);
}

test "ivf vp8 decoder reconstructs interframe residuals" {
    var inter_payload: [test_vp8_inter_residual_payload_len]u8 = undefined;
    const inter_frame = writeTestVp8InterResidualFrame(&inter_payload);
    const first_record_size = ivf_container.frame_header_size + test_vp8_wide_gray_payload.len;
    const second_record_size = ivf_container.frame_header_size + test_vp8_inter_residual_payload_len;
    var ivf = [_]u8{0} ** (ivf_container.header_size + first_record_size + second_record_size);
    @memcpy(ivf[0..ivf_container.signature.len], ivf_container.signature);
    @memcpy(ivf[ivf_container.codec_index..][0..ivf_container.codec_size], ivf_container.codec_vp8);
    ivf[ivf_container.width_index] = test_vp8_wide_gray_width;
    ivf[ivf_container.height_index] = test_vp8_wide_gray_height;
    ivf[ivf_container.frame_count_index] = 2;

    var cursor: usize = ivf_container.header_size;
    writeTestIvfFrame(ivf[cursor..][0..first_record_size], 41, &test_vp8_wide_gray_payload);
    cursor += first_record_size;
    writeTestIvfFrame(ivf[cursor..][0..second_record_size], 42, inter_frame);

    var decoder = try Decoder.init(&ivf);
    var pixels: [test_vp8_wide_gray_width * test_vp8_wide_gray_height]ui.Color = undefined;
    var scratch: [test_vp8_wide_gray_reference_len]u8 = undefined;
    _ = (try decoder.nextFrame(&pixels, &scratch)).?;
    try expectTestWideGrayFrame(&pixels);

    const second = (try decoder.nextFrame(&pixels, &scratch)).?;
    try std.testing.expectEqual(@as(usize, 1), second.index);
    try std.testing.expectEqual(@as(u64, 42), second.timestamp);
    try expectTestWideLightFrame(&pixels);
}

test "ivf vp8 decoder reconstructs shifted interframes" {
    var inter_payload: [test_vp8_inter_shift_payload_len]u8 = undefined;
    const inter_frame = writeTestVp8InterShiftFrame(&inter_payload);
    const first_record_size = ivf_container.frame_header_size + test_vp8_stripe_payload.len;
    const second_record_size = ivf_container.frame_header_size + test_vp8_inter_shift_payload_len;
    var ivf = [_]u8{0} ** (ivf_container.header_size + first_record_size + second_record_size);
    @memcpy(ivf[0..ivf_container.signature.len], ivf_container.signature);
    @memcpy(ivf[ivf_container.codec_index..][0..ivf_container.codec_size], ivf_container.codec_vp8);
    ivf[ivf_container.width_index] = test_vp8_stripe_width;
    ivf[ivf_container.height_index] = test_vp8_stripe_height;
    ivf[ivf_container.frame_count_index] = 2;

    var cursor: usize = ivf_container.header_size;
    writeTestIvfFrame(ivf[cursor..][0..first_record_size], 51, &test_vp8_stripe_payload);
    cursor += first_record_size;
    writeTestIvfFrame(ivf[cursor..][0..second_record_size], 52, inter_frame);

    var decoder = try Decoder.init(&ivf);
    var pixels: [test_vp8_stripe_pixel_count]ui.Color = undefined;
    var scratch: [test_vp8_stripe_reference_len]u8 = undefined;
    _ = (try decoder.nextFrame(&pixels, &scratch)).?;
    try expectTestStripeFrame(&pixels, 0);

    const second = (try decoder.nextFrame(&pixels, &scratch)).?;
    try std.testing.expectEqual(@as(usize, 1), second.index);
    try std.testing.expectEqual(@as(u64, 52), second.timestamp);
    try expectTestStripeFrame(&pixels, test_vp8_stripe_shift);
}

test "ivf vp8 decoder reconstructs fractional-motion interframes" {
    var inter_payload: [test_vp8_inter_fractional_payload_len]u8 = undefined;
    const inter_frame = writeTestVp8InterFractionalFrame(&inter_payload);
    const first_record_size = ivf_container.frame_header_size + test_vp8_stripe_payload.len;
    const second_record_size = ivf_container.frame_header_size + test_vp8_inter_fractional_payload_len;
    var ivf = [_]u8{0} ** (ivf_container.header_size + first_record_size + second_record_size);
    @memcpy(ivf[0..ivf_container.signature.len], ivf_container.signature);
    @memcpy(ivf[ivf_container.codec_index..][0..ivf_container.codec_size], ivf_container.codec_vp8);
    ivf[ivf_container.width_index] = test_vp8_stripe_width;
    ivf[ivf_container.height_index] = test_vp8_stripe_height;
    ivf[ivf_container.frame_count_index] = 2;

    var cursor: usize = ivf_container.header_size;
    writeTestIvfFrame(ivf[cursor..][0..first_record_size], 61, &test_vp8_stripe_payload);
    cursor += first_record_size;
    writeTestIvfFrame(ivf[cursor..][0..second_record_size], 62, inter_frame);

    var decoder = try Decoder.init(&ivf);
    var pixels: [test_vp8_stripe_pixel_count]ui.Color = undefined;
    var scratch: [test_vp8_stripe_reference_len]u8 = undefined;
    _ = (try decoder.nextFrame(&pixels, &scratch)).?;
    try expectTestStripeFrame(&pixels, 0);

    const second = (try decoder.nextFrame(&pixels, &scratch)).?;
    try std.testing.expectEqual(@as(usize, 1), second.index);
    try std.testing.expectEqual(@as(u64, 62), second.timestamp);
    try expectTestStripeFractionalFrame(&pixels);
}

test "ivf vp8 decoder applies loop filter to fractional-motion interframes" {
    var inter_payload: [test_vp8_inter_fractional_filtered_payload_len]u8 = undefined;
    const inter_frame = writeTestVp8InterFractionalFilteredFrame(&inter_payload);
    const first_record_size = ivf_container.frame_header_size + test_vp8_stripe_payload.len;
    const second_record_size = ivf_container.frame_header_size + test_vp8_inter_fractional_filtered_payload_len;
    var ivf = [_]u8{0} ** (ivf_container.header_size + first_record_size + second_record_size);
    @memcpy(ivf[0..ivf_container.signature.len], ivf_container.signature);
    @memcpy(ivf[ivf_container.codec_index..][0..ivf_container.codec_size], ivf_container.codec_vp8);
    ivf[ivf_container.width_index] = test_vp8_stripe_width;
    ivf[ivf_container.height_index] = test_vp8_stripe_height;
    ivf[ivf_container.frame_count_index] = 2;

    var cursor: usize = ivf_container.header_size;
    writeTestIvfFrame(ivf[cursor..][0..first_record_size], 71, &test_vp8_stripe_payload);
    cursor += first_record_size;
    writeTestIvfFrame(ivf[cursor..][0..second_record_size], 72, inter_frame);

    var decoder = try Decoder.init(&ivf);
    var pixels: [test_vp8_stripe_pixel_count]ui.Color = undefined;
    var scratch: [test_vp8_stripe_reference_len]u8 = undefined;
    _ = (try decoder.nextFrame(&pixels, &scratch)).?;
    try expectTestStripeFrame(&pixels, 0);

    const second = (try decoder.nextFrame(&pixels, &scratch)).?;
    try std.testing.expectEqual(@as(usize, 1), second.index);
    try std.testing.expectEqual(@as(u64, 72), second.timestamp);
    try expectTestStripeFractionalFilteredFrame(&pixels);
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
    var scratch: [test_vp8_gray_reference_len]u8 = undefined;
    _ = try decodeFrame(&ivf, 0, &pixels, &scratch);
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
    var scratch: [test_vp8_gray_reference_len]u8 = undefined;
    const frame = try decodeFrame(webm, 0, &pixels, &scratch);
    try std.testing.expectEqual(@as(usize, 0), frame.index);
    try std.testing.expectEqual(@as(u64, 23), frame.timestamp);
    try expectTestGrayFrame(&pixels);
}

test "webm vp8 decoder steps sequential simpleblock frames and resets" {
    const webm = try buildTestWebm(std.testing.allocator, true, webm_container.codec_vp8);
    defer std.testing.allocator.free(webm);

    var decoder = try Decoder.init(webm);
    var pixels: [4]ui.Color = undefined;
    var scratch: [test_vp8_gray_reference_len]u8 = undefined;
    const first = (try decoder.nextFrame(&pixels, &scratch)).?;
    try std.testing.expectEqual(@as(usize, 0), first.index);
    try std.testing.expectEqual(@as(u64, 23), first.timestamp);
    try expectTestGrayFrame(&pixels);

    const second = (try decoder.nextFrame(&pixels, &scratch)).?;
    try std.testing.expectEqual(@as(usize, 1), second.index);
    try std.testing.expectEqual(@as(u64, 24), second.timestamp);
    try expectTestGrayFrame(&pixels);

    try std.testing.expect((try decoder.nextFrame(&pixels, &scratch)) == null);
    decoder.reset();
    const first_again = (try decoder.nextFrame(&pixels, &scratch)).?;
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
    var scratch: [test_vp8_gray_reference_len]u8 = undefined;
    const first = (try decoder.nextFrame(&pixels, &scratch)).?;
    try std.testing.expectEqual(@as(usize, 0), first.index);
    try expectTestGrayFrame(&pixels);

    const second = (try decoder.nextFrame(&pixels, &scratch)).?;
    try std.testing.expectEqual(@as(usize, 1), second.index);
    try std.testing.expectEqual(@as(u64, 24), second.timestamp);
    try expectTestGrayFrame(&pixels);
}

test "webm vp8 decoder reconstructs multi-macroblock zero-motion interframes" {
    var inter_payload: [test_vp8_inter_zero_payload_len]u8 = undefined;
    const inter_frame = writeTestVp8InterZeroFrame(&inter_payload);
    const webm = try buildTestWebmWithSizedPayloads(
        std.testing.allocator,
        test_vp8_wide_gray_width,
        test_vp8_wide_gray_height,
        &test_vp8_wide_gray_payload,
        inter_frame,
        webm_container.codec_vp8,
    );
    defer std.testing.allocator.free(webm);

    var decoder = try Decoder.init(webm);
    var pixels: [test_vp8_wide_gray_width * test_vp8_wide_gray_height]ui.Color = undefined;
    var scratch: [test_vp8_wide_gray_reference_len]u8 = undefined;
    _ = (try decoder.nextFrame(&pixels, &scratch)).?;
    try expectTestWideGrayFrame(&pixels);

    const second = (try decoder.nextFrame(&pixels, &scratch)).?;
    try std.testing.expectEqual(@as(usize, 1), second.index);
    try std.testing.expectEqual(@as(u64, 24), second.timestamp);
    try expectTestWideGrayFrame(&pixels);
}

test "webm vp8 decoder reconstructs interframe residuals" {
    var inter_payload: [test_vp8_inter_residual_payload_len]u8 = undefined;
    const inter_frame = writeTestVp8InterResidualFrame(&inter_payload);
    const webm = try buildTestWebmWithSizedPayloads(
        std.testing.allocator,
        test_vp8_wide_gray_width,
        test_vp8_wide_gray_height,
        &test_vp8_wide_gray_payload,
        inter_frame,
        webm_container.codec_vp8,
    );
    defer std.testing.allocator.free(webm);

    var decoder = try Decoder.init(webm);
    var pixels: [test_vp8_wide_gray_width * test_vp8_wide_gray_height]ui.Color = undefined;
    var scratch: [test_vp8_wide_gray_reference_len]u8 = undefined;
    _ = (try decoder.nextFrame(&pixels, &scratch)).?;
    try expectTestWideGrayFrame(&pixels);

    const second = (try decoder.nextFrame(&pixels, &scratch)).?;
    try std.testing.expectEqual(@as(usize, 1), second.index);
    try std.testing.expectEqual(@as(u64, 24), second.timestamp);
    try expectTestWideLightFrame(&pixels);
}

test "webm vp8 decoder reconstructs shifted interframes" {
    var inter_payload: [test_vp8_inter_shift_payload_len]u8 = undefined;
    const inter_frame = writeTestVp8InterShiftFrame(&inter_payload);
    const webm = try buildTestWebmWithSizedPayloads(
        std.testing.allocator,
        test_vp8_stripe_width,
        test_vp8_stripe_height,
        &test_vp8_stripe_payload,
        inter_frame,
        webm_container.codec_vp8,
    );
    defer std.testing.allocator.free(webm);

    var decoder = try Decoder.init(webm);
    var pixels: [test_vp8_stripe_pixel_count]ui.Color = undefined;
    var scratch: [test_vp8_stripe_reference_len]u8 = undefined;
    _ = (try decoder.nextFrame(&pixels, &scratch)).?;
    try expectTestStripeFrame(&pixels, 0);

    const second = (try decoder.nextFrame(&pixels, &scratch)).?;
    try std.testing.expectEqual(@as(usize, 1), second.index);
    try std.testing.expectEqual(@as(u64, 24), second.timestamp);
    try expectTestStripeFrame(&pixels, test_vp8_stripe_shift);
}

test "webm vp8 decoder reconstructs fractional-motion interframes" {
    var inter_payload: [test_vp8_inter_fractional_payload_len]u8 = undefined;
    const inter_frame = writeTestVp8InterFractionalFrame(&inter_payload);
    const webm = try buildTestWebmWithSizedPayloads(
        std.testing.allocator,
        test_vp8_stripe_width,
        test_vp8_stripe_height,
        &test_vp8_stripe_payload,
        inter_frame,
        webm_container.codec_vp8,
    );
    defer std.testing.allocator.free(webm);

    var decoder = try Decoder.init(webm);
    var pixels: [test_vp8_stripe_pixel_count]ui.Color = undefined;
    var scratch: [test_vp8_stripe_reference_len]u8 = undefined;
    _ = (try decoder.nextFrame(&pixels, &scratch)).?;
    try expectTestStripeFrame(&pixels, 0);

    const second = (try decoder.nextFrame(&pixels, &scratch)).?;
    try std.testing.expectEqual(@as(usize, 1), second.index);
    try std.testing.expectEqual(@as(u64, 24), second.timestamp);
    try expectTestStripeFractionalFrame(&pixels);
}

test "webm vp8 decoder applies loop filter to fractional-motion interframes" {
    var inter_payload: [test_vp8_inter_fractional_filtered_payload_len]u8 = undefined;
    const inter_frame = writeTestVp8InterFractionalFilteredFrame(&inter_payload);
    const webm = try buildTestWebmWithSizedPayloads(
        std.testing.allocator,
        test_vp8_stripe_width,
        test_vp8_stripe_height,
        &test_vp8_stripe_payload,
        inter_frame,
        webm_container.codec_vp8,
    );
    defer std.testing.allocator.free(webm);

    var decoder = try Decoder.init(webm);
    var pixels: [test_vp8_stripe_pixel_count]ui.Color = undefined;
    var scratch: [test_vp8_stripe_reference_len]u8 = undefined;
    _ = (try decoder.nextFrame(&pixels, &scratch)).?;
    try expectTestStripeFrame(&pixels, 0);

    const second = (try decoder.nextFrame(&pixels, &scratch)).?;
    try std.testing.expectEqual(@as(usize, 1), second.index);
    try std.testing.expectEqual(@as(u64, 24), second.timestamp);
    try expectTestStripeFractionalFilteredFrame(&pixels);
}

test "webm vp8 frame decoder reconstructs blockgroup pixels" {
    const webm = try buildTestWebmBlockGroup(std.testing.allocator);
    defer std.testing.allocator.free(webm);

    var pixels: [4]ui.Color = undefined;
    var scratch: [test_vp8_gray_reference_len]u8 = undefined;
    const frame = try decodeFrame(webm, 0, &pixels, &scratch);
    try std.testing.expectEqual(@as(usize, 0), frame.index);
    try std.testing.expectEqual(@as(u64, 25), frame.timestamp);
    try expectTestGrayFrame(&pixels);
}

test "webm vp8 decoder keeps cluster cursor bounded" {
    const webm = try buildTestWebmTwoClusters(std.testing.allocator);
    defer std.testing.allocator.free(webm);

    var decoder = try Decoder.init(webm);
    var pixels: [4]ui.Color = undefined;
    var scratch: [test_vp8_gray_reference_len]u8 = undefined;
    const first = (try decoder.nextFrame(&pixels, &scratch)).?;
    try std.testing.expectEqual(@as(usize, 0), first.index);
    try std.testing.expectEqual(@as(u64, 33), first.timestamp);
    try expectTestGrayFrame(&pixels);
    try std.testing.expect((try decoder.nextFrame(&pixels, &scratch)) == null);
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
    var scratch: [test_vp8_gray_reference_len]u8 = undefined;
    _ = try decodeFrame(webm, 0, &pixels, &scratch);
    try expectTestNeutralFrame(&pixels);
}

const test_vp8_gray_payload = [_]u8{
    0x50, 0x01, 0x00, 0x9d, 0x01, 0x2a, 0x02, 0x00,
    0x02, 0x00, 0x01, 0x40, 0x26, 0x25, 0xa4, 0x00,
    0x04, 0x74, 0x00, 0x00, 0xe4, 0x40, 0x00, 0x00,
};
const test_vp8_gray_reference_len: usize = @sizeOf(ui.Color) * 4 + 6 * 4;

const test_vp8_wide_gray_width: usize = 32;
const test_vp8_wide_gray_height: usize = 16;
const test_vp8_wide_gray_reference_len: usize = @sizeOf(ui.Color) * test_vp8_wide_gray_width * test_vp8_wide_gray_height +
    (test_vp8_wide_gray_width * test_vp8_wide_gray_height +
        (test_vp8_wide_gray_width / 2) * (test_vp8_wide_gray_height / 2) * 2) * 4;
const test_vp8_wide_gray_payload = [_]u8{
    0xb0, 0x02, 0x00, 0x9d, 0x01, 0x2a, 0x20, 0x00,
    0x10, 0x00, 0x3e, 0x6d, 0x2c, 0x93, 0x45, 0xa4,
    0x22, 0xa1, 0x98, 0x04, 0x00, 0x40, 0x06, 0xc4,
    0xb4, 0x80, 0x00, 0x4a, 0xc4, 0x00, 0x00, 0xe4,
    0x40, 0x00,
};
const test_vp8_interframe_payload = [_]u8{ 0x11, 0x0a, 0x00 } ++ ([_]u8{0x00} ** 80) ++ ([_]u8{0x00} ** 8);
const test_vp8_truncated_keyframe_payload = [_]u8{ 0x30, 0x00, 0x00 };
const test_vp8_inter_zero_payload = [_]u8{
    0xb1, 0x01, 0x00, 0x01, 0x10, 0x30, 0x00, 0x18,
    0x00, 0x24, 0x57, 0xf4, 0x0c, 0x00, 0x31, 0x80,
    0xfe, 0x68, 0x00,
};
const test_vp8_inter_zero_payload_len: usize = test_vp8_inter_zero_payload.len;
const test_vp8_inter_residual_payload = [_]u8{
    0xb1, 0x01, 0x00, 0x01, 0x10, 0x10, 0x00, 0x18,
    0x00, 0x24, 0x57, 0xf4, 0x0c, 0x00, 0x31, 0x80,
    0xfe, 0xef, 0x38, 0x80,
};
const test_vp8_inter_residual_payload_len: usize = test_vp8_inter_residual_payload.len;
const test_vp8_stripe_width: usize = 32;
const test_vp8_stripe_height: usize = 16;
const test_vp8_stripe_shift: usize = 4;
const test_vp8_stripe_pixel_count: usize = test_vp8_stripe_width * test_vp8_stripe_height;
const test_vp8_stripe_reference_len: usize = @sizeOf(ui.Color) * test_vp8_stripe_pixel_count +
    (test_vp8_stripe_pixel_count +
        (test_vp8_stripe_width / 2) * (test_vp8_stripe_height / 2) * 2) * 4;
const test_vp8_stripe_payload = [_]u8{
    0xf0, 0x02, 0x00, 0x9d, 0x01, 0x2a, 0x20, 0x00,
    0x10, 0x00, 0x00, 0x47, 0x08, 0x85, 0x85, 0x88,
    0x99, 0x84, 0x88, 0x02, 0x02, 0x00, 0x0c, 0x0d,
    0x39, 0xf9, 0x29, 0x37, 0x8b, 0x27, 0x73, 0x43,
    0x00, 0xfe, 0xff, 0x56, 0xc1, 0xff, 0xc8, 0xa0,
    0xa6, 0xff, 0x8a, 0x10, 0x00,
};
const test_vp8_inter_shift_payload = [_]u8{
    0xd1, 0x01, 0x00, 0x01, 0x10, 0x10, 0x00, 0x18,
    0x00, 0x18, 0x58, 0x2f, 0xf4, 0x00, 0x57, 0x95,
    0x20, 0x00,
};
const test_vp8_inter_shift_payload_len: usize = test_vp8_inter_shift_payload.len;
const test_vp8_inter_fractional_payload = [_]u8{
    0xb1, 0x01, 0x00, 0x0f, 0x11, 0xfc, 0x00, 0x18,
    0x00, 0x18, 0x58, 0x2f, 0xf4, 0x00, 0x45, 0x30,
    0x00,
};
const test_vp8_inter_fractional_payload_len: usize = test_vp8_inter_fractional_payload.len;
const test_vp8_inter_fractional_filtered_payload = [_]u8{
    0xf1, 0x02, 0x00, 0x01, 0x10, 0x10, 0x00, 0x1b,
    0x72, 0x06, 0xf8, 0x1f, 0xd8, 0x0b, 0xa0, 0x3a,
    0xbf, 0xc0, 0x0e, 0xf8, 0x8e, 0xfc, 0x40, 0x14,
    0xb0, 0x00, 0xcc, 0xff, 0xc3, 0x6f, 0xfc, 0x5c,
    0xcf, 0xfc, 0xcb, 0x48, 0x92, 0x87, 0xf7, 0x28,
    0xff, 0xf6, 0x1e, 0xb6, 0xa2, 0x7f, 0x28, 0x2b,
    0xcf, 0x20, 0x27, 0xfa, 0xe1, 0xff, 0x81, 0xb9,
    0xff, 0x3b, 0xea, 0xf0, 0xdc, 0xb6, 0x7f, 0x16,
    0xda, 0x54, 0x0c, 0x3c, 0xf2, 0xc4, 0xaf, 0x53,
    0x64, 0x5a, 0x00,
};
const test_vp8_inter_fractional_filtered_payload_len: usize = test_vp8_inter_fractional_filtered_payload.len;
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

fn writeTestVp8InterResidualFrame(bytes: *[test_vp8_inter_residual_payload_len]u8) []const u8 {
    @memcpy(bytes, &test_vp8_inter_residual_payload);
    return bytes;
}

fn writeTestVp8InterShiftFrame(bytes: *[test_vp8_inter_shift_payload_len]u8) []const u8 {
    @memcpy(bytes, &test_vp8_inter_shift_payload);
    return bytes;
}

fn writeTestVp8InterFractionalFrame(bytes: *[test_vp8_inter_fractional_payload_len]u8) []const u8 {
    @memcpy(bytes, &test_vp8_inter_fractional_payload);
    return bytes;
}

fn writeTestVp8InterFractionalFilteredFrame(bytes: *[test_vp8_inter_fractional_filtered_payload_len]u8) []const u8 {
    @memcpy(bytes, &test_vp8_inter_fractional_filtered_payload);
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

fn expectTestWideGrayFrame(pixels: []const ui.Color) !void {
    try std.testing.expectEqual(@as(usize, test_vp8_wide_gray_width * test_vp8_wide_gray_height), pixels.len);
    for (pixels) |pixel| {
        try std.testing.expectEqual(ui.Color{ .r = 126, .g = 126, .b = 126, .a = 255 }, pixel);
    }
}

fn expectTestWideLightFrame(pixels: []const ui.Color) !void {
    try std.testing.expectEqual(@as(usize, test_vp8_wide_gray_width * test_vp8_wide_gray_height), pixels.len);
    for (pixels) |pixel| {
        try std.testing.expectEqual(ui.Color{ .r = 140, .g = 140, .b = 140, .a = 255 }, pixel);
    }
}

fn expectTestStripeFrame(pixels: []const ui.Color, shift: usize) !void {
    try std.testing.expectEqual(@as(usize, test_vp8_stripe_pixel_count), pixels.len);
    for (pixels, 0..) |pixel, index| {
        const x = (index % test_vp8_stripe_width) + shift;
        const shifted_x = x % test_vp8_stripe_width;
        const luma: u8 = if (shifted_x >= 8 and shifted_x < 24) 180 else 80;
        try std.testing.expectEqual(ui.Color{ .r = luma, .g = luma, .b = luma, .a = 255 }, pixel);
    }
}

fn expectTestStripeFractionalFrame(pixels: []const ui.Color) !void {
    const row = [_]u8{
        80,  80,  80,  80,  80,  80,  82,  70,
        130, 190, 178, 180, 180, 180, 180, 180,
        180, 180, 180, 180, 180, 180, 178, 190,
        130, 70,  82,  80,  80,  80,  80,  80,
    };
    try std.testing.expectEqual(@as(usize, test_vp8_stripe_pixel_count), pixels.len);
    for (pixels, 0..) |pixel, index| {
        const luma = row[index % test_vp8_stripe_width];
        try std.testing.expectEqual(ui.Color{ .r = luma, .g = luma, .b = luma, .a = 255 }, pixel);
    }
}

fn expectTestStripeFractionalFilteredFrame(pixels: []const ui.Color) !void {
    const row = [_]u8{
        80,  80,  80,  80,  80,  80,  80,  80,
        131, 180, 180, 179, 180, 180, 180, 180,
        180, 180, 180, 180, 180, 180, 180, 180,
        130, 80,  80,  80,  80,  80,  80,  80,
    };
    try std.testing.expectEqual(@as(usize, test_vp8_stripe_pixel_count), pixels.len);
    for (pixels[0..test_vp8_stripe_width], 0..) |pixel, index| {
        const luma = row[index];
        try std.testing.expectEqual(ui.Color{ .r = luma, .g = luma, .b = luma, .a = 255 }, pixel);
    }
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
    return buildTestWebmWithSizedPayloads(allocator, 2, 2, first_payload, second_payload, codec_id);
}

fn buildTestWebmWithSizedPayloads(allocator: std.mem.Allocator, width: usize, height: usize, first_payload: []const u8, second_payload: []const u8, codec_id: []const u8) ![]u8 {
    var segment: std.ArrayList(u8) = .empty;
    defer segment.deinit(allocator);
    try appendTestWebmTracksSized(allocator, &segment, codec_id, width, height);
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
    return appendTestWebmTracksSized(allocator, segment, codec_id, 2, 2);
}

fn appendTestWebmTracksSized(allocator: std.mem.Allocator, segment: *std.ArrayList(u8), codec_id: []const u8, width: usize, height: usize) !void {
    var track_entry: std.ArrayList(u8) = .empty;
    defer track_entry.deinit(allocator);
    try appendTestEbmlElement(allocator, &track_entry, &[_]u8{0xd7}, &[_]u8{1});
    try appendTestEbmlElement(allocator, &track_entry, &[_]u8{0x83}, &[_]u8{@intCast(webm_container.track_type_video)});
    try appendTestEbmlElement(allocator, &track_entry, &[_]u8{0x86}, codec_id);

    var video_elements: std.ArrayList(u8) = .empty;
    defer video_elements.deinit(allocator);
    try appendTestEbmlElement(allocator, &video_elements, &[_]u8{0xb0}, &[_]u8{@intCast(width)});
    try appendTestEbmlElement(allocator, &video_elements, &[_]u8{0xba}, &[_]u8{@intCast(height)});
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
