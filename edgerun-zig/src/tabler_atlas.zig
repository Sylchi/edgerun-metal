const std = @import("std");
const icon = @import("icon.zig");

pub const width: usize = 672;
pub const height: usize = 560;
pub const icon_size: usize = 96;
pub const alpha = @embedFile("assets/tabler_svg_atlas_alpha.bin");

pub const Rect = struct {
    x: u32,
    y: u32,
    w: u32,
    h: u32,
};

pub fn rect(value: icon.Icon) Rect {
    return switch (value) {
        .activity => at(8, 8),
        .warning => at(120, 8),
        .app => at(232, 8),
        .send => at(344, 8),
        .bell => at(456, 8),
        .check => at(568, 8),
        .chevron_right => at(8, 120),
        .code => at(120, 120),
        .cpu => at(232, 120),
        .database, .storage => at(344, 120),
        .eye => at(456, 120),
        .file => at(568, 120),
        .key => at(8, 232),
        .lock => at(120, 232),
        .menu => at(232, 232),
        .chat => at(344, 232),
        .message_plus => at(456, 232),
        .network => at(568, 232),
        .route => at(8, 344),
        .search => at(120, 344),
        .server => at(232, 344),
        .settings => at(344, 344),
        .shield, .trust => at(456, 344),
        .sparkles => at(568, 344),
        .terminal => at(8, 456),
        .trash => at(120, 456),
        .user => at(232, 456),
        .wallet => at(344, 456),
        .x => at(456, 456),
    };
}

fn at(x: u32, y: u32) Rect {
    return .{ .x = x, .y = y, .w = icon_size, .h = icon_size };
}

test "tabler atlas embeds canonical alpha bytes" {
    try std.testing.expectEqual(width * height, alpha.len);
    try std.testing.expectEqual(@as(u32, 232), rect(.app).x);
    try std.testing.expectEqual(@as(u32, 344), rect(.storage).x);
    try std.testing.expectEqual(@as(u32, 456), rect(.trust).x);
}
