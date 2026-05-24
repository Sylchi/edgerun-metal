const std = @import("std");
const common = @import("../../../ui_component_common.zig");
const layout = @import("../../../layouts/Types.zig");
const ui = @import("../../../ui.zig");

const RenderOptions = common.RenderOptions;

pub const Params = struct {
    title: []const u8 = "",
    detail: []const u8 = "",
};

pub fn render(scene: *ui.Scene, bounds: ui.Rect, params: Params, options: RenderOptions) ui.RenderError!void {
    try renderFrame(scene, bounds, options);
    if (params.title.len == 0 and params.detail.len == 0) return;

    const title_bounds = ui.Rect.init(bounds.x + padding, bounds.y + padding, @max(1.0, bounds.w - padding * 2.0), title_height);
    if (params.title.len != 0) {
        try scene.pushAlignedText(title_bounds, params.title, options.style.text, .start);
    }
    if (params.detail.len != 0) {
        const detail_y = title_bounds.y + title_bounds.h + detail_gap;
        const detail_bounds = ui.Rect.init(title_bounds.x, detail_y, title_bounds.w, @max(1.0, bounds.y + bounds.h - detail_y - padding));
        try scene.pushWrappedText(detail_bounds, params.detail, options.style.muted, .{
            .line_height = detail_height,
            .average_char_width = detail_average_w,
            .max_lines = detail_max_lines,
        });
    }
}

pub fn renderFrame(scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    const frame_radius = radiusFor(options.surface_variant);
    if (options.surface_variant == .elevated) {
        try scene.pushRect(bounds.insetUniform(-shadow_inset), shadow, .shadow, frame_radius, shadow_size);
    }
    try scene.pushRect(bounds, fillColor(options), .fill, frame_radius, 0.0);
    try scene.pushRect(bounds, options.style.border, .border, frame_radius, 0.0);
}

pub fn measure(params: Params, constraints: layout.Constraints) layout.Measurement {
    const inner = constraints.inner(layout.Insets.uniform(padding));
    const title = layout.measureText(params.title, inner, .{
        .line_height = title_height,
        .average_char_width = title_average_w,
        .max_lines = title_max_lines,
    });
    const detail = layout.measureText(params.detail, inner, .{
        .line_height = detail_height,
        .average_char_width = detail_average_w,
        .max_lines = detail_max_lines,
    });
    const content_width = @max(title.preferred.w, detail.preferred.w);
    const content_height = title.preferred.h + detail_gap + detail.preferred.h;
    return layout.Measurement.flexible(
        .{ .w = min_width, .h = padding * 2.0 + title_height },
        .{ .w = content_width + padding * 2.0, .h = content_height + padding * 2.0 },
        .{ .w = max_width, .h = content_height + padding * 2.0 },
    ).applyExact(constraints);
}

pub fn frameInsets() layout.Insets {
    return layout.Insets.uniform(padding);
}

pub fn radiusFor(variant: common.SurfaceVariant) f32 {
    return switch (variant) {
        .panel => radius,
        .elevated => radius + elevated_radius_extra,
        .subtle => radius,
    };
}

fn fillColor(options: RenderOptions) ui.Color {
    return switch (options.surface_variant) {
        .panel, .elevated => options.style.panel,
        .subtle => options.style.row,
    };
}

pub const radius: f32 = 10.0;
pub const padding: f32 = 16.0;
pub const title_height: f32 = 18.0;
pub const detail_height: f32 = 16.0;
pub const detail_gap: f32 = 8.0;

const elevated_radius_extra: f32 = 2.0;
const shadow = ui.Color{ .r = 0, .g = 0, .b = 0, .a = 96 };
const shadow_size: f32 = 8.0;
const shadow_inset: f32 = 1.0;
const title_average_w: f32 = 8.5;
const title_max_lines: usize = 1;
const detail_average_w: f32 = 8.0;
const detail_max_lines: usize = 3;
const min_width: f32 = 160.0;
const max_width: f32 = 4096.0;

test "base surface renders frame and text" {
    var commands: [12]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try render(&scene, ui.Rect.init(0, 0, 220, 90), .{ .title = "Surface", .detail = "Shared primitive." }, .{});

    try std.testing.expect(scene.written().len >= 4);
}
