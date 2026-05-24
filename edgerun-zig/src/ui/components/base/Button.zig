const std = @import("std");
const common = @import("../../../ui_component_common.zig");
const icon = @import("../../../icon.zig");
const layout = @import("../../../layouts/Types.zig");
const ui = @import("../../../ui.zig");

const RenderOptions = common.RenderOptions;

pub const Params = struct {
    id: u32,
    label: []const u8,
};

pub fn render(scene: *ui.Scene, bounds: ui.Rect, params: Params, options: RenderOptions) ui.RenderError!void {
    const text_color = switch (options.button_variant) {
        .primary => options.style.bg,
        .outline => options.style.text,
        .ghost => options.style.muted,
    };
    switch (options.button_variant) {
        .primary => {
            try scene.pushRect(bounds, options.style.accent, .fill, radius, 0.0);
            try scene.pushRect(bounds, options.style.accent, .border, radius, 0.0);
        },
        .outline => {
            try scene.pushRect(bounds, options.style.panel, .fill, radius, 0.0);
            try scene.pushRect(bounds, options.style.border, .border, radius, 0.0);
        },
        .ghost => {
            try scene.pushRect(bounds, ui.Color.clear, .fill, radius, 0.0);
        },
    }
    try renderContent(scene, bounds, params.label, text_color, options.button_leading_icon, options.button_trailing_icon);
    try scene.pushHit(.{ .slot = 0, .kind = .button, .id = params.id, .bounds = bounds });
}

pub fn measure(label: []const u8, constraints: layout.Constraints) layout.Measurement {
    const preferred_width = @max(min_width, estimatedLabelWidth(label) + label_padding * 2.0);
    return layout.Measurement.flexible(
        .{ .w = min_width, .h = height },
        .{ .w = preferred_width, .h = height },
        .{ .w = max_width, .h = height },
    ).applyExact(constraints);
}

fn renderContent(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, text_color: ui.Color, leading_icon: ?icon.Icon, trailing_icon: ?icon.Icon) ui.RenderError!void {
    const has_leading = leading_icon != null;
    const has_trailing = trailing_icon != null;
    if (!has_leading and !has_trailing) {
        try scene.pushAlignedText(textBounds(bounds), label, text_color, .center);
        return;
    }

    const icon_count: usize = @intFromBool(has_leading) + @intFromBool(has_trailing);
    const label_w = estimatedLabelWidth(label);
    const content_w = label_w +
        @as(f32, @floatFromInt(icon_count)) * icon_size +
        @as(f32, @floatFromInt(icon_count)) * icon_gap;
    var cursor_x = bounds.x + @max(content_min_x, (bounds.w - content_w) * 0.5);
    const icon_y = bounds.y + (bounds.h - icon_size) * 0.5;
    const text_y = bounds.y + (bounds.h - label_height) * 0.5;

    if (leading_icon) |value| {
        try scene.pushIconQuad(.{
            .bounds = ui.Rect.init(cursor_x, icon_y, icon_size, icon_size),
            .atlas_id = icon.atlasId(value),
            .color = text_color,
        });
        cursor_x += icon_size + icon_gap;
    }

    try scene.pushAlignedText(ui.Rect.init(cursor_x, text_y, label_w, label_height), label, text_color, .start);
    cursor_x += label_w + icon_gap;

    if (trailing_icon) |value| {
        try scene.pushIconQuad(.{
            .bounds = ui.Rect.init(cursor_x, icon_y, icon_size, icon_size),
            .atlas_id = icon.atlasId(value),
            .color = text_color,
        });
    }
}

fn textBounds(bounds: ui.Rect) ui.Rect {
    const margin = @min(label_padding, bounds.w * 0.5);
    return ui.Rect.init(bounds.x + margin, bounds.y + (bounds.h - label_height) * 0.5, @max(1.0, bounds.w - margin * 2.0), label_height);
}

fn estimatedLabelWidth(label: []const u8) f32 {
    return @max(label_min_width, @as(f32, @floatFromInt(label.len)) * label_average_w);
}

pub const radius: f32 = 7.0;
pub const height: f32 = 36.0;
pub const label_height: f32 = 16.0;
pub const label_padding: f32 = 14.0;

const label_average_w: f32 = 8.0;
const label_min_width: f32 = 8.0;
const icon_size: f32 = 18.0;
const icon_gap: f32 = 8.0;
const content_min_x: f32 = 14.0;
const min_width: f32 = 44.0;
const max_width: f32 = 4096.0;

test "base button measurement follows label width" {
    const short = measure("Go", .{});
    const long = measure("Continue lesson", .{});

    try std.testing.expect(long.preferred.w > short.preferred.w);
    try std.testing.expectEqual(height, long.preferred.h);
}
