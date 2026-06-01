const std = @import("er_std");

pub const TrackKind = enum {
    audio,
    video,
};

pub const Track = union(TrackKind) {
    audio: struct {
        codec_id: []const u8,
        sample_rate_hz: u32,
        channels: u8,
        track_number: u8 = 2,
    },
    video: struct {
        codec_id: []const u8,
        width: usize = 2,
        height: usize = 2,
        track_number: u8 = 1,
    },
};

pub const BlockTrack = enum(u8) {
    video = 0x81,
    audio = 0x82,
};

pub const ClusterBlock = struct {
    payload: []const u8,
    relative_timecode: u8,
};

pub fn appendElement(allocator: std.mem.Allocator, list: *std.ArrayList(u8), id: []const u8, payload: []const u8) !void {
    try list.appendSlice(allocator, id);
    try appendSize(allocator, list, payload.len);
    try list.appendSlice(allocator, payload);
}

pub fn appendSize(allocator: std.mem.Allocator, list: *std.ArrayList(u8), payload_len: usize) !void {
    if (payload_len < 0x7f) {
        try list.append(allocator, 0x80 | @as(u8, @intCast(payload_len)));
        return;
    }
    if (payload_len >= 0x3fff) return error.NoSpace;
    const high: u8 = @intCast(payload_len >> 8);
    const low: u8 = @intCast(payload_len & 0xff);
    try list.append(allocator, 0x40 | high);
    try list.append(allocator, low);
}

pub fn appendTracks(allocator: std.mem.Allocator, segment: *std.ArrayList(u8), tracks: []const Track) !void {
    var tracks_payload: std.ArrayList(u8) = .empty;
    defer tracks_payload.deinit(allocator);

    for (tracks) |track| {
        var track_entry: std.ArrayList(u8) = .empty;
        defer track_entry.deinit(allocator);

        switch (track) {
            .audio => |audio| {
                try appendElement(allocator, &track_entry, &[_]u8{0xd7}, &[_]u8{audio.track_number});
                try appendElement(allocator, &track_entry, &[_]u8{0x83}, &[_]u8{2});
                try appendElement(allocator, &track_entry, &[_]u8{0x86}, audio.codec_id);

                var audio_elements: std.ArrayList(u8) = .empty;
                defer audio_elements.deinit(allocator);
                var sample_rate: [8]u8 = undefined;
                std.mem.writeInt(u64, &sample_rate, @bitCast(@as(f64, @floatFromInt(audio.sample_rate_hz))), .big);
                try appendElement(allocator, &audio_elements, &[_]u8{0xb5}, &sample_rate);
                try appendElement(allocator, &audio_elements, &[_]u8{0x9f}, &[_]u8{audio.channels});
                try appendElement(allocator, &track_entry, &[_]u8{0xe1}, audio_elements.items);
            },
            .video => |video| {
                try appendElement(allocator, &track_entry, &[_]u8{0xd7}, &[_]u8{video.track_number});
                try appendElement(allocator, &track_entry, &[_]u8{0x83}, &[_]u8{1});
                try appendElement(allocator, &track_entry, &[_]u8{0x86}, video.codec_id);

                var video_elements: std.ArrayList(u8) = .empty;
                defer video_elements.deinit(allocator);
                try appendElement(allocator, &video_elements, &[_]u8{0xb0}, &[_]u8{@intCast(video.width)});
                try appendElement(allocator, &video_elements, &[_]u8{0xba}, &[_]u8{@intCast(video.height)});
                try appendElement(allocator, &track_entry, &[_]u8{0xe0}, video_elements.items);
            },
        }

        try appendElement(allocator, &tracks_payload, &[_]u8{0xae}, track_entry.items);
    }

    try appendElement(allocator, segment, &[_]u8{ 0x16, 0x54, 0xae, 0x6b }, tracks_payload.items);
}

pub fn appendCluster(
    allocator: std.mem.Allocator,
    segment: *std.ArrayList(u8),
    track: BlockTrack,
    timecode: u8,
    blocks: []const ClusterBlock,
    block_group: bool,
) !void {
    var block_payload: std.ArrayList(u8) = .empty;
    defer block_payload.deinit(allocator);

    var cluster: std.ArrayList(u8) = .empty;
    defer cluster.deinit(allocator);
    try appendElement(allocator, &cluster, &[_]u8{0xe7}, &[_]u8{timecode});

    for (blocks) |block| {
        block_payload.clearRetainingCapacity();
        try appendBlockPayload(allocator, &block_payload, track, block.relative_timecode, block.payload);
        if (block_group) {
            var group: std.ArrayList(u8) = .empty;
            defer group.deinit(allocator);
            try appendElement(allocator, &group, &[_]u8{0xa1}, block_payload.items);
            try appendElement(allocator, &cluster, &[_]u8{0xa0}, group.items);
        } else {
            try appendElement(allocator, &cluster, &[_]u8{0xa3}, block_payload.items);
        }
    }

    try appendElement(allocator, segment, &[_]u8{ 0x1f, 0x43, 0xb6, 0x75 }, cluster.items);
}

pub fn finish(allocator: std.mem.Allocator, segment: []const u8) ![]u8 {
    var webm: std.ArrayList(u8) = .empty;
    errdefer webm.deinit(allocator);
    try appendElement(allocator, &webm, &[_]u8{ 0x1a, 0x45, 0xdf, 0xa3 }, &.{});
    try appendElement(allocator, &webm, &[_]u8{ 0x18, 0x53, 0x80, 0x67 }, segment);
    return webm.toOwnedSlice(allocator);
}

fn appendBlockPayload(allocator: std.mem.Allocator, block: *std.ArrayList(u8), track: BlockTrack, relative_timecode: u8, payload: []const u8) !void {
    try block.append(allocator, @intFromEnum(track));
    try block.append(allocator, 0);
    try block.append(allocator, relative_timecode);
    try block.append(allocator, 0x80);
    try block.appendSlice(allocator, payload);
}
