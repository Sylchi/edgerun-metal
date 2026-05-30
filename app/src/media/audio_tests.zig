const std = @import("std");
const audio = @import("audio.zig");
const webm_container = @import("audio_webm.zig");

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
    try appendTestAudioTracks(allocator, &segment, codec_id, sample_rate_hz, channels);
    try appendTestAudioCluster(allocator, &segment, packet_payload, 20, 3, block_group);
    return buildTestWebmFromSegment(allocator, segment.items);
}

fn appendTestAudioTracks(
    allocator: std.mem.Allocator,
    segment: *std.ArrayList(u8),
    codec_id: []const u8,
    sample_rate_hz: u32,
    channels: u8,
) !void {
    var track_entry: std.ArrayList(u8) = .empty;
    defer track_entry.deinit(allocator);
    try appendTestEbmlElement(allocator, &track_entry, &[_]u8{0xd7}, &[_]u8{2});
    try appendTestEbmlElement(allocator, &track_entry, &[_]u8{0x83}, &[_]u8{@intCast(webm_container.track_type_audio)});
    try appendTestEbmlElement(allocator, &track_entry, &[_]u8{0x86}, codec_id);

    var audio_elements: std.ArrayList(u8) = .empty;
    defer audio_elements.deinit(allocator);
    var sample_rate: [8]u8 = undefined;
    std.mem.writeInt(u64, &sample_rate, @bitCast(@as(f64, @floatFromInt(sample_rate_hz))), .big);
    try appendTestEbmlElement(allocator, &audio_elements, &[_]u8{0xb5}, &sample_rate);
    try appendTestEbmlElement(allocator, &audio_elements, &[_]u8{0x9f}, &[_]u8{channels});
    try appendTestEbmlElement(allocator, &track_entry, &[_]u8{0xe1}, audio_elements.items);

    var tracks: std.ArrayList(u8) = .empty;
    defer tracks.deinit(allocator);
    try appendTestEbmlElement(allocator, &tracks, &[_]u8{0xae}, track_entry.items);
    try appendTestEbmlElement(allocator, segment, &[_]u8{ 0x16, 0x54, 0xae, 0x6b }, tracks.items);
}

fn appendTestAudioCluster(
    allocator: std.mem.Allocator,
    segment: *std.ArrayList(u8),
    payload: []const u8,
    timecode: u8,
    relative_timecode: u8,
    block_group: bool,
) !void {
    var block: std.ArrayList(u8) = .empty;
    defer block.deinit(allocator);

    var cluster: std.ArrayList(u8) = .empty;
    defer cluster.deinit(allocator);
    try appendTestEbmlElement(allocator, &cluster, &[_]u8{0xe7}, &[_]u8{timecode});

    try appendTestAudioBlockPayload(allocator, &block, relative_timecode, payload);
    if (block_group) {
        var group: std.ArrayList(u8) = .empty;
        defer group.deinit(allocator);
        try appendTestEbmlElement(allocator, &group, &[_]u8{0xa1}, block.items);
        try appendTestEbmlElement(allocator, &cluster, &[_]u8{0xa0}, group.items);
    } else {
        try appendTestEbmlElement(allocator, &cluster, &[_]u8{0xa3}, block.items);
    }

    try appendTestEbmlElement(allocator, segment, &[_]u8{ 0x1f, 0x43, 0xb6, 0x75 }, cluster.items);
}

fn buildTestWebmFromSegment(allocator: std.mem.Allocator, segment: []const u8) ![]u8 {
    var webm: std.ArrayList(u8) = .empty;
    errdefer webm.deinit(allocator);
    try appendTestEbmlElement(allocator, &webm, &[_]u8{ 0x1a, 0x45, 0xdf, 0xa3 }, &.{});
    try appendTestEbmlElement(allocator, &webm, &[_]u8{ 0x18, 0x53, 0x80, 0x67 }, segment);
    return webm.toOwnedSlice(allocator);
}

fn appendTestAudioBlockPayload(allocator: std.mem.Allocator, block: *std.ArrayList(u8), relative_timecode: u8, payload: []const u8) !void {
    try block.append(allocator, 0x82);
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
    if (payload_len >= 0x3fff) return error.BadAudio;
    const high: u8 = @intCast(payload_len >> 8);
    const low: u8 = @intCast(payload_len & 0xff);
    try list.append(allocator, 0x40 | high);
    try list.append(allocator, low);
}
