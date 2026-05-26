const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const icon = @import("../../icon.zig");
const layout = @import("../../layouts/Types.zig");
const text_metrics = @import("../../ui_text_metrics.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const icon_component = @import("Icon.zig");
const component_primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;
const measureFixed = component_primitives.measureFixed;

pub const Toast = struct {
    id: u32,
    title: []const u8,
    detail: []const u8,

    pub fn node(self: Toast) ui.Node {
        return ui.toastNode(self.id, self.title, self.detail);
    }

    pub fn accessibility(self: Toast) common.Accessibility {
        return .{ .role = .status, .label = self.title, .control_id = self.id };
    }

    pub fn render(self: Toast, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const toast = toastBounds(bounds);
        try scene.pushRect(toast, options.style.panel, .fill, toast_radius, 0.0);
        try scene.pushRect(toast, options.style.border, .border, toast_radius, 0.0);
        try icon_component.renderGlyph(scene, toastIconBounds(toast), .check, options.style.accent);
        const text_x = toast.x + toast_text_x;
        const text_w = @max(component_primitives.min_extent, toast.x + toast.w - text_x - toast_padding);
        const title_h = measuredTextHeight(self.title, text_w, titleMetrics(self.title));
        try scene.pushWrappedText(ui.Rect.init(text_x, toast.y + toast_padding, text_w, title_h), self.title, options.style.text, titleWrap(self.title));
        if (self.detail.len != 0) {
            const detail_y = toast.y + toast_padding + title_h + toast_text_gap;
            const detail_h = @max(component_primitives.min_extent, toast.y + toast.h - detail_y - toast_padding);
            try scene.pushWrappedText(ui.Rect.init(text_x, detail_y, text_w, detail_h), self.detail, options.style.muted, detailWrap(self.detail));
        }
    }

    pub fn collectInteractions(self: Toast, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(toastBounds(bounds), .button, self.id);
    }

    pub fn measure(self: Toast, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        const inner = constraints.inner(.{ .left = toast_text_x, .right = toast_padding });
        const title = layout.measureText(self.title, inner, titleMetrics(self.title));
        const detail = if (self.detail.len == 0)
            layout.Measurement.fixed(.{ .w = 0.0, .h = 0.0 })
        else
            layout.measureText(self.detail, inner, detailMetrics(self.detail));
        const gap: f32 = if (self.detail.len == 0) 0.0 else toast_text_gap;
        const preferred = component_primitives.constrainPreferredSize(.{
            .w = @max(toast_min_width, @max(title.preferred.w, detail.preferred.w) + toast_text_x + toast_padding),
            .h = toast_padding * 2.0 + title.preferred.h + gap + detail.preferred.h,
        }, constraints);
        return layout.Measurement.flexible(
            .{ .w = @min(toast_min_width, preferred.w), .h = @min(toast_min_height, preferred.h) },
            preferred,
            .{ .w = component_primitives.measure_max_width, .h = @max(preferred.h, preferred_toast.h) },
        ).applyExact(constraints);
    }

    pub fn toObject(self: Toast, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.toast, self.id, self.title, self.detail, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Toast, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .toast, self.id, self.title, self.detail);
    }

    pub fn fromView(view: object.View) Error!Toast {
        const toast = try component_codec.nodeView(view, .toast);
        return fromNode(toast);
    }

    pub fn fromNode(toast: @FieldType(ui.Node, "toast")) Error!Toast {
        return .{ .id = toast.id, .title = toast.title, .detail = toast.detail };
    }
};

fn toastBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y, bounds.w, @min(bounds.h, toast_h));
}

fn toastIconBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x + toast_icon_x, bounds.y + (bounds.h - toast_icon_size) * 0.5, toast_icon_size, toast_icon_size);
}

fn measuredTextHeight(value: []const u8, width: f32, metrics: layout.TextMetrics) f32 {
    return layout.measureText(value, .{ .width = .{ .at_most = width }, .text_wrap = .wrap }, metrics).preferred.h;
}

fn titleMetrics(value: []const u8) layout.TextMetrics {
    return .{ .line_height = toast_title_line_height, .average_char_width = text_metrics.averageWidth(value, toast_title_line_height), .max_lines = toast_text_max_lines };
}

fn detailMetrics(value: []const u8) layout.TextMetrics {
    return .{ .line_height = toast_detail_line_height, .average_char_width = text_metrics.averageWidth(value, toast_detail_line_height), .max_lines = toast_text_max_lines };
}

fn titleWrap(value: []const u8) ui.TextWrap {
    return .{ .line_height = toast_title_line_height, .average_char_width = text_metrics.averageWidth(value, toast_title_line_height), .max_lines = toast_text_max_lines };
}

fn detailWrap(value: []const u8) ui.TextWrap {
    return .{ .line_height = toast_detail_line_height, .average_char_width = text_metrics.averageWidth(value, toast_detail_line_height), .max_lines = toast_text_max_lines };
}

const toast_h: f32 = preferred_toast.h;
const toast_radius: f32 = 8.0;
const toast_padding: f32 = 10.0;
const toast_icon_x: f32 = 12.0;
const toast_icon_size: f32 = 16.0;
const toast_text_x: f32 = 38.0;
const toast_text_gap: f32 = 3.0;
const toast_min_width: f32 = 160.0;
const toast_min_height: f32 = 40.0;
const toast_title_line_height: f32 = 14.0;
const toast_detail_line_height: f32 = 12.0;
const toast_text_max_lines: usize = 2;
pub const preferred_toast = ui.Size{ .w = 240.0, .h = 52.0 };

test "toast component serializes to canonical object and deserializes" {
    const toast = Toast{ .id = 1002, .title = "Saved", .detail = "Notification" };
    var ui_raw: [192]u8 = undefined;
    var object_raw: [object.header_size + 192]u8 = undefined;

    const canonical = toast.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Toast.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(toast.id, decoded.id);
    try std.testing.expectEqualStrings(toast.title, decoded.title);
    try std.testing.expectEqualStrings(toast.detail, decoded.detail);
}

test "toast component renders title detail and hit region" {
    const toast = Toast{ .id = 1002, .title = "Saved", .detail = "Notification" };
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [1]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try toast.render(&scene, ui.Rect.init(0, 0, 240, 52), .{});
    try toast.collectInteractions(&collector, ui.Rect.init(0, 0, 240, 52));

    try std.testing.expect(component_test.hasText(scene.written(), "Saved"));
    try std.testing.expect(component_test.hasText(scene.written(), "Notification"));
    try std.testing.expectEqual(@as(usize, 1), collector.written().len);
    try std.testing.expectEqual(ui.HitKind.button, collector.written()[0].kind);
}

test "toast measurement wraps long content under narrow constraints" {
    const toast = Toast{
        .id = 1002,
        .title = "Saved secure runtime state",
        .detail = "Notification detail wraps inside narrow layouts",
    };

    const measured = toast.measure(.{ .width = .{ .at_most = toast_min_width }, .text_wrap = .wrap }, .{});

    try std.testing.expect(measured.preferred.w <= toast_min_width);
    try std.testing.expect(measured.preferred.h > preferred_toast.h);
}
