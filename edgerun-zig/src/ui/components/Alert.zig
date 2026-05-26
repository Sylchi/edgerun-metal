const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const icon = @import("../../icon.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;
const measureFixed = component_primitives.measureFixed;

pub const Alert = struct {
    title: []const u8,
    detail: []const u8,
    destructive: bool = false,

    pub fn node(self: Alert) ui.Node {
        return ui.alertNode(self.title, self.detail, self.destructive);
    }

    pub fn render(self: Alert, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const content_color = if (self.destructive) alert_danger else options.style.text;
        try scene.pushRect(bounds, options.style.panel, .fill, alert_radius, 0.0);
        try scene.pushRect(bounds, if (self.destructive) alert_danger else options.style.border, .border, alert_radius, 0.0);
        try scene.pushIconQuad(.{
            .bounds = ui.Rect.init(bounds.x + alert_padding_x, bounds.y + alert_padding_y, alert_icon_size, alert_icon_size),
            .icon_id = icon.id(if (self.destructive) .warning else .shield),
            .color = content_color,
        });
        try scene.pushText(ui.Rect.init(bounds.x + alert_text_x, bounds.y + alert_padding_y - 1.0, @max(component_primitives.min_extent, bounds.w - alert_text_x - alert_padding_x), alert_title_height), self.title, content_color);
        try scene.pushWrappedText(ui.Rect.init(bounds.x + alert_text_x, bounds.y + alert_padding_y + alert_title_height + alert_detail_gap, @max(component_primitives.min_extent, bounds.w - alert_text_x - alert_padding_x), @max(component_primitives.min_extent, bounds.h - alert_padding_y * 2.0 - alert_title_height)), self.detail, if (self.destructive) alert_danger else options.style.muted, .{
            .line_height = alert_detail_height,
            .average_char_width = alert_detail_average_w,
            .max_lines = alert_detail_max_lines,
        });
    }

    pub fn measure(self: Alert, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_alert, constraints);
    }

    pub fn toObject(self: Alert, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        var writer = component_codec.Writer.init(ui_out, 1, 1, .column, 0, 0) orelse return null;
        if (!self.writeRecord(&writer, 0)) return null;
        return writer.objectNode(object_out, component_codec.requirements(), epoch);
    }

    pub fn writeRecord(self: Alert, writer: *component_codec.Writer, index: usize) bool {
        const title_ref = writer.string(self.title) orelse return false;
        const detail_ref = writer.string(self.detail) orelse return false;
        const destructive_id: u32 = if (self.destructive) 1 else 0;
        return writer.record(index, .alert, destructive_id, title_ref, detail_ref);
    }

    pub fn fromView(view: object.View) Error!Alert {
        return switch (try component_codec.singleNode(view)) {
            .alert => |alert| .{ .title = alert.title, .detail = alert.detail, .destructive = alert.destructive },
            else => error.UnsupportedComponent,
        };
    }
};

const alert_radius: f32 = 8.0;
const alert_padding_x: f32 = 16.0;
const alert_padding_y: f32 = 12.0;
const alert_icon_size: f32 = 16.0;
const alert_text_x: f32 = 44.0;
const alert_title_height: f32 = 16.0;
const alert_detail_gap: f32 = 2.0;
const alert_detail_height: f32 = 16.0;
const alert_detail_average_w: f32 = 7.5;
const alert_detail_max_lines: usize = 2;
const alert_danger = ui.Color{ .r = 239, .g = 68, .b = 68 };
pub const preferred_alert = ui.Size{ .w = 260.0, .h = 64.0 };

test "alert component serializes to canonical object and deserializes" {
    const alert = Alert{ .title = "Heads up", .detail = "Status message", .destructive = true };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = alert.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Alert.fromView(try object.View.decode(canonical));

    try std.testing.expectEqualStrings(alert.title, decoded.title);
    try std.testing.expectEqualStrings(alert.detail, decoded.detail);
    try std.testing.expect(decoded.destructive);
}

test "alert component renders title detail and destructive variant" {
    const alert = Alert{ .title = "Heads up", .detail = "Status message", .destructive = true };
    var commands: [12]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try alert.render(&scene, ui.Rect.init(0, 0, 260, 64), .{});

    try std.testing.expect(component_test.hasText(scene.written(), "Heads up"));
    try std.testing.expect(component_test.hasText(scene.written(), "Status message"));
    try std.testing.expect(component_test.hasBorderAt(scene.written(), ui.Rect.init(0, 0, 260, 64)));
}
