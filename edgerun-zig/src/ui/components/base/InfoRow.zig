const std = @import("std");
const common = @import("../../../ui_component_common.zig");
const layout = @import("../../../layouts/Types.zig");
const ui = @import("../../../ui.zig");

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
    padding_x: f32 = default_padding_x,
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
    try scene.pushRect(bounds, options.style.row, .fill, metrics.radius, 0.0);
    const text_w = @max(1.0, bounds.w - metrics.padding_x * 2.0);
    try scene.pushAlignedText(ui.Rect.init(bounds.x + metrics.padding_x, bounds.y + metrics.title_y, text_w, metrics.title_height), params.title, options.style.text, .start);
    try scene.pushWrappedText(ui.Rect.init(bounds.x + metrics.padding_x, bounds.y + metrics.detail_y, text_w, metrics.detail_height), params.detail, options.style.muted, .{
        .line_height = metrics.detail_line_height,
        .average_char_width = metrics.detail_average_w,
        .max_lines = metrics.detail_max_lines,
    });
    try scene.pushHit(.{ .slot = 0, .kind = params.hit_kind, .id = params.id, .bounds = bounds });
}

pub fn measure(title: []const u8, detail: []const u8, constraints: layout.Constraints, metrics: Metrics) layout.Measurement {
    const text_constraints = constraints.inner(layout.Insets.uniform(metrics.padding_x));
    const title_measure = layout.measureText(title, text_constraints, .{
        .line_height = metrics.title_height,
        .average_char_width = metrics.title_average_w,
        .max_lines = metrics.title_max_lines,
    });
    const detail_measure = layout.measureText(detail, text_constraints, .{
        .line_height = metrics.detail_line_height,
        .average_char_width = metrics.detail_average_w,
        .max_lines = metrics.detail_max_lines,
    });
    const content_width = @max(title_measure.preferred.w, detail_measure.preferred.w) + metrics.padding_x * 2.0;
    const content_height = metrics.title_y + title_measure.preferred.h + (metrics.detail_y - metrics.title_y - metrics.title_height) + detail_measure.preferred.h;
    const resolved_height = @max(metrics.height, content_height);
    return layout.Measurement.flexible(
        .{ .w = metrics.min_width, .h = metrics.height },
        .{ .w = content_width, .h = resolved_height },
        .{ .w = constraints.width.limit(content_width), .h = resolved_height },
    ).applyExact(constraints);
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

test "base info row renders text and hit target" {
    var commands: [12]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try render(&scene, ui.Rect.init(0, 0, 240, default_height), .{ .id = 7, .title = "DNS", .detail = "Name lookup." }, .{}, .{});

    try std.testing.expect(scene.written().len >= 4);
}

test "base info row measurement grows with detail" {
    const short = measure("TLS", "Protects bytes.", .{}, .{});
    const long = measure("TLS", "Protects bytes while they travel between endpoints and need a little room.", .{ .width = .{ .exact = 160 }, .text_wrap = .wrap }, .{});

    try std.testing.expect(long.preferred.h >= short.preferred.h);
}
