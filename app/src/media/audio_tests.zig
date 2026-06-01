const std = @import("std");
const audio = @import("audio.zig");
const webm_container = @import("audio_webm.zig");
const webm_test = @import("test_webm_builder.zig");

const test_opus_packet = [_]u8{ 0xf8, 0xff, 0xfe };
const test_vorbis_packet = [_]u8{ 0x01, 'v', 'o', 'r', 'b', 'i', 's' };

test "webm audio header parses opus track metadata" {
    const allocator = std.testing.allocator;
    const webm = try buildTestAudioWebm(allocator, webm_container.codec_opus, 48_000, 2, &test_opus_packet, false);
    defer allocator.free(webm);

    const header = try audio.decodeHeader(webm);
    try std.testing.expectEqual(audio.Format.webm, header.format);
    try std.testing.expectEqual(audio.Codec.opus, header.codec);
    try std.testing.expectEqual(@as(u32, 48_000), header.sample_rate_hz);
    try std.testing.expectEqual(@as(u8, 2), header.channels);
    try std.testing.expectEqual(@as(?usize, null), header.packet_count);
}

test "webm audio reads opus packets from simple blocks" {
    const allocator = std.testing.allocator;
    const webm = try buildTestAudioWebm(allocator, webm_container.codec_opus, 48_000, 2, &test_opus_packet, false);
    defer allocator.free(webm);

    var decoder = try audio.Decoder.init(webm);
    const packet = (try decoder.nextPacket()) orelse return error.BadAudio;
    try std.testing.expectEqual(@as(usize, 0), packet.index);
    try std.testing.expectEqual(@as(u64, 23), packet.timestamp);
    try std.testing.expectEqualSlices(u8, &test_opus_packet, packet.payload);
    try std.testing.expectEqual(@as(?audio.Packet, null), try decoder.nextPacket());
}

test "webm audio reads vorbis packets from block groups" {
    const allocator = std.testing.allocator;
    const webm = try buildTestAudioWebm(allocator, webm_container.codec_vorbis, 44_100, 1, &test_vorbis_packet, true);
    defer allocator.free(webm);

    const packet = try audio.readPacket(webm, 0);
    try std.testing.expectEqual(audio.Codec.vorbis, packet.header.codec);
    try std.testing.expectEqual(@as(u32, 44_100), packet.header.sample_rate_hz);
    try std.testing.expectEqual(@as(u8, 1), packet.header.channels);
    try std.testing.expectEqualSlices(u8, &test_vorbis_packet, packet.payload);
}

test "webm audio rejects laced blocks" {
    const allocator = std.testing.allocator;
    const webm = try buildTestAudioWebm(allocator, webm_container.codec_opus, 48_000, 2, &test_opus_packet, false);
    defer allocator.free(webm);

    var laced = try allocator.dupe(u8, webm);
    defer allocator.free(laced);
    const flags_index = laced.len - test_opus_packet.len - 1;
    laced[flags_index] = 0x82;

    try std.testing.expectError(error.UnsupportedAudio, audio.readPacket(laced, 0));
}

test "webm audio rejects unsupported audio codec" {
    const allocator = std.testing.allocator;
    const webm = try buildTestAudioWebm(allocator, "A_FAKE", 48_000, 2, &test_opus_packet, false);
    defer allocator.free(webm);

    try std.testing.expectError(error.UnsupportedAudio, audio.decodeHeader(webm));
}

fn buildTestAudioWebm(
    allocator: std.mem.Allocator,
    codec_id: []const u8,
    sample_rate_hz: u32,
    channels: u8,
    packet_payload: []const u8,
    block_group: bool,
) ![]u8 {
    var segment: std.ArrayList(u8) = .empty;
    defer segment.deinit(allocator);
    try webm_test.appendTracks(allocator, &segment, &.{
        .{ .audio = .{
            .codec_id = codec_id,
            .sample_rate_hz = sample_rate_hz,
            .channels = channels,
        } },
    });
    try webm_test.appendCluster(allocator, &segment, .audio, 20, &.{
        .{ .payload = packet_payload, .relative_timecode = 3 },
    }, block_group);
    return webm_test.finish(allocator, segment.items);
}
