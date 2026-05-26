const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const icon = @import("../../icon.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const Toast = struct {
    id: u32,
    title: []const u8,
    detail: []const u8,

    pub fn node(self: Toast) ui.Node {
        return ui.toastNode(self.id, self.title, self.detail);
    }

    pub fn render(self: Toast, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const toast = toastBounds(bounds);
        try scene.pushRect(toast, options.style.panel, .fill, toast_radius, 0.0);
        try scene.pushRect(toast, options.style.border, .border, toast_radius, 0.0);
        try scene.pushIconQuad(.{ .bounds = toastIconBounds(toast), .icon_id = icon.id(.check), .color = options.style.accent });
        const text_x = toast.x + toast_text_x;
        try scene.pushText(ui.Rect.init(text_x, toast.y + toast_title_y, @max(min_extent, toast.x + toast.w - text_x - toast_padding), toast_title_h), self.title, options.style.text);
        try scene.pushText(ui.Rect.init(text_x, toast.y + toast_detail_y, @max(min_extent, toast.x + toast.w - text_x - toast_padding), toast_detail_h), self.detail, options.style.muted);
    }

    pub fn collectInteractions(self: Toast, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(toastBounds(bounds), .button, self.id);
    }

    pub fn measure(self: Toast, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_toast, constraints);
    }

    pub fn toObject(self: Toast, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.toast, self.id, self.title, self.detail, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Toast, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .toast, self.id, self.title, self.detail);
    }

    pub fn fromView(view: object.View) Error!Toast {
        return switch (try component_codec.singleNode(view)) {
            .toast => |toast| .{ .id = toast.id, .title = toast.title, .detail = toast.detail },
            else => error.UnsupportedComponent,
        };
    }
};

fn toastBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y, bounds.w, @min(bounds.h, toast_h));
}

fn toastIconBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x + toast_icon_x, bounds.y + (bounds.h - toast_icon_size) * 0.5, toast_icon_size, toast_icon_size);
}

fn measureFixed(preferred: ui.Size, constraints: layout.Constraints) layout.Measurement {
    const resolved_preferred = constrainPreferredSize(preferred, constraints);
    return layout.Measurement.flexible(
        .{ .w = @min(preferred.w, resolved_preferred.w), .h = @min(preferred.h, resolved_preferred.h) },
        resolved_preferred,
        .{ .w = measure_max_width, .h = preferred.h },
    ).applyExact(constraints);
}

fn constrainPreferredSize(preferred: ui.Size, constraints: layout.Constraints) ui.Size {
    return .{
        .w = constraints.width.limit(preferred.w),
        .h = constraints.height.limit(preferred.h),
    };
}

const min_extent: f32 = 1.0;
const measure_max_width: f32 = 4096.0;
const toast_h: f32 = 52.0;
const toast_radius: f32 = 8.0;
const toast_padding: f32 = 10.0;
const toast_icon_x: f32 = 12.0;
const toast_icon_size: f32 = 16.0;
const toast_text_x: f32 = 38.0;
const toast_title_y: f32 = 10.0;
const toast_title_h: f32 = 14.0;
const toast_detail_y: f32 = 27.0;
const toast_detail_h: f32 = 12.0;
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
