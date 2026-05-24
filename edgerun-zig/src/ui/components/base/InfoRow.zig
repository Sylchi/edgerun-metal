const std = @import("std");
const common = @import("../../../ui_component_common.zig");
const interaction = @import("../../../ui_interaction.zig");
const layout = @import("../../../layouts/Types.zig");
const ui = @import("../../../ui.zig");
const ui_input = @import("../../../input.zig");
const base_text_block = @import("TextBlock.zig");

const RenderOptions = common.RenderOptions;

pub const Params = struct {
    id: u32,
    title: []const u8,
    detail: []const u8,
    hit_kind: ui.HitKind = .row_item,
};

pub const Metrics = struct {
    height: f32 = default_height,
    radius: f32 = default_radius,
    padding_left: f32 = default_padding_x,
    padding_right: f32 = default_padding_x,
    fill: bool = true,
    title_y: f32 = default_title_y,
    title_height: f32 = default_title_height,
    title_average_w: f32 = default_title_average_w,
    title_max_lines: usize = default_title_max_lines,
    detail_y: f32 = default_detail_y,
    detail_height: f32 = default_detail_height,
    detail_line_height: f32 = default_detail_line_height,
    detail_average_w: f32 = default_detail_average_w,
    detail_max_lines: usize = default_detail_max_lines,
    min_width: f32 = default_min_width,
};

pub fn render(scene: *ui.Scene, bounds: ui.Rect, params: Params, metrics: Metrics, options: RenderOptions) ui.RenderError!void {
    if (metrics.fill) {
        try scene.pushRect(bounds, options.style.row, .fill, metrics.radius, 0.0);
    }
    const text_bounds = textBounds(bounds, metrics);
    try scene.pushAlignedText(ui.Rect.init(text_bounds.x, bounds.y + metrics.title_y, text_bounds.w, metrics.title_height), params.title, options.style.text, .start);
    try base_text_block.render(scene, ui.Rect.init(text_bounds.x, bounds.y + metrics.detail_y, text_bounds.w, metrics.detail_height), params.detail, options.style.muted, detailMetrics(metrics));
}

pub fn collectInteractions(collector: *interaction.Collector, bounds: ui.Rect, params: Params) interaction.Error!void {
    try collector.add(.{ .kind = params.hit_kind, .id = params.id, .bounds = bounds });
}

pub fn measure(title: []const u8, detail: []const u8, constraints: layout.Constraints, metrics: Metrics) layout.Measurement {
    const text_constraints = constraints.inner(textInsets(metrics));
    const title_measure = base_text_block.measure(title, text_constraints, titleMetrics(metrics));
    const detail_measure = base_text_block.measure(detail, text_constraints, detailMetrics(metrics));
    const content_width = @max(title_measure.preferred.w, detail_measure.preferred.w) + metrics.padding_left + metrics.padding_right;
    const content_height = metrics.title_y + title_measure.preferred.h + (metrics.detail_y - metrics.title_y - metrics.title_height) + detail_measure.preferred.h;
    const resolved_height = @max(metrics.height, content_height);
    return layout.Measurement.flexible(
        .{ .w = metrics.min_width, .h = metrics.height },
        .{ .w = content_width, .h = resolved_height },
        .{ .w = constraints.width.limit(content_width), .h = resolved_height },
    ).applyExact(constraints);
}

fn textBounds(bounds: ui.Rect, metrics: Metrics) ui.Rect {
    return ui.Rect.init(bounds.x + metrics.padding_left, bounds.y, @max(1.0, bounds.w - metrics.padding_left - metrics.padding_right), bounds.h);
}

fn textInsets(metrics: Metrics) layout.Insets {
    return .{ .left = metrics.padding_left, .right = metrics.padding_right };
}

fn titleMetrics(metrics: Metrics) base_text_block.Metrics {
    return .{
        .line_height = metrics.title_height,
        .average_char_width = metrics.title_average_w,
        .max_lines = metrics.title_max_lines,
    };
}

fn detailMetrics(metrics: Metrics) base_text_block.Metrics {
    return .{
        .line_height = metrics.detail_line_height,
        .average_char_width = metrics.detail_average_w,
        .max_lines = metrics.detail_max_lines,
    };
}

pub const default_height: f32 = 70.0;
pub const default_radius: f32 = 6.0;
pub const default_padding_x: f32 = 12.0;
pub const default_title_y: f32 = 11.0;
pub const default_title_height: f32 = 16.0;
pub const default_detail_y: f32 = 34.0;
pub const default_detail_height: f32 = 30.0;
pub const default_detail_line_height: f32 = 15.0;
pub const default_min_width: f32 = 180.0;

const default_title_average_w: f32 = 8.5;
const default_title_max_lines: usize = 1;
const default_detail_average_w: f32 = 8.5;
const default_detail_max_lines: usize = 2;

test "base info row renders text and collects hit target" {
    var commands: [12]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try render(&scene, ui.Rect.init(0, 0, 240, default_height), .{ .id = 7, .title = "DNS", .detail = "Name lookup." }, .{}, .{});
    try collectInteractions(&collector, ui.Rect.init(0, 0, 240, default_height), .{ .id = 7, .title = "DNS", .detail = "Name lookup." });

    try std.testing.expect(scene.written().len >= 3);
    try std.testing.expect(ui_input.hitTest(scene.written(), 20, 20) == null);
    try std.testing.expectEqual(@as(u32, 7), ui_input.regionHitTest(collector.written(), 20, 20).?.id);
}

test "base info row measurement grows with detail" {
    const short = measure("TLS", "Protects bytes.", .{}, .{});
    const long = measure("TLS", "Protects bytes while they travel between endpoints and need a little room.", .{ .width = .{ .exact = 160 }, .text_wrap = .wrap }, .{});

    try std.testing.expect(long.preferred.h >= short.preferred.h);
}

test "base info row supports leading affordance space without drawing row fill" {
    var commands: [12]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    const metrics = Metrics{ .padding_left = 42.0, .padding_right = 10.0, .fill = false };

    try render(&scene, ui.Rect.init(0, 0, 240, default_height), .{ .id = 8, .title = "Network", .detail = "Follow packets." }, metrics, .{});

    const written = scene.written();
    try std.testing.expectEqual(@as(usize, 0), countRects(written));
    try std.testing.expectEqual(@as(f32, 42.0), firstTextX(written));
}

fn countRects(commands: []const ui.Command) usize {
    var count: usize = 0;
    for (commands) |command| {
        switch (command) {
            .rect => count += 1,
            else => {},
        }
    }
    return count;
}

fn firstTextX(commands: []const ui.Command) f32 {
    for (commands) |command| {
        switch (command) {
            .text => |text| return text.origin.x,
            else => {},
        }
    }
    return 0.0;
}
