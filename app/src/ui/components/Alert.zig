const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../component_common.zig");
const object = @import("../../object.zig");
const ui = @import("../core.zig");
const text_component = @import("Text.zig");
const layout = @import("../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const icon_component = @import("Icon.zig");
const component_primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

const constrainPreferredSize = component_primitives.constrainPreferredSize;
const Icon = icon_component.Icon;
const IconSlot = icon_component.IconSlot;

pub const Alert = struct {
    title: []const u8,
    detail: []const u8,
    destructive: bool = false,
    icon_slot: IconSlot = .none,

    pub fn node(self: Alert) ui.Node {
        return ui.alertNode(self.title, self.detail, self.destructive, statusIconTag(self));
    }

    pub fn render(self: Alert, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const content_color = if (self.destructive) alert_danger else options.style.text;
        try scene.pushRect(bounds, options.style.panel, .fill, alert_radius, 0.0);
        try scene.pushRect(bounds, if (self.destructive) alert_danger else options.style.border, .border, alert_radius, 0.0);
        try statusIcon(self).renderColor(scene, ui.Rect.init(bounds.x + alert_padding_x, bounds.y + alert_padding_y, alert_icon_size, alert_icon_size), content_color);
        const text_w = textWidth(bounds);
        const title_h = component_primitives.measuredTextHeight(self.title, text_w, alert_title_height, alert_title_max_lines);
        try text_component.Text.renderWrapped(scene, ui.Rect.init(bounds.x + alert_text_x, bounds.y + alert_padding_y - 1.0, text_w, title_h), self.title, content_color, component_primitives.textWrap(self.title, alert_title_height, alert_title_max_lines));
        try text_component.Text.renderWrapped(scene, ui.Rect.init(bounds.x + alert_text_x, bounds.y + alert_padding_y + title_h + alert_detail_gap, text_w, @max(component_primitives.min_extent, bounds.h - alert_padding_y * 2.0 - title_h)), self.detail, if (self.destructive) alert_danger else options.style.muted, component_primitives.textWrap(self.detail, alert_detail_height, alert_detail_max_lines));
    }

    pub fn measure(self: Alert, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        const inner = constraints.inner(.{ .left = alert_text_x, .right = alert_padding_x });
        const title = text_component.Text.measureValue(self.title, inner, component_primitives.textMetrics(self.title, alert_title_height, alert_title_max_lines));
        const detail = text_component.Text.measureValue(self.detail, inner, component_primitives.textMetrics(self.detail, alert_detail_height, alert_detail_max_lines));
        const preferred = constrainPreferredSize(.{
            .w = @max(alert_min_width, @max(title.preferred.w, detail.preferred.w) + alert_text_x + alert_padding_x),
            .h = alert_padding_y * 2.0 + @max(alert_icon_size, title.preferred.h + alert_detail_gap + detail.preferred.h),
        }, constraints);
        return layout.Measurement.flexible(
            .{ .w = @min(alert_min_width, preferred.w), .h = @min(alert_min_height, preferred.h) },
            preferred,
            .{ .w = component_primitives.maxMeasuredWidth(constraints, preferred.w), .h = preferred.h },
        ).applyExact(constraints);
    }

    pub fn toObject(self: Alert, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        var writer = component_codec.Writer.init(ui_out, 1, 1, .column, 0, 0) orelse return null;
        if (!self.writeRecord(&writer, 0)) return null;
        return writer.objectNode(object_out, component_codec.requirements(), epoch);
    }

    pub fn writeRecord(self: Alert, writer: *component_codec.Writer, index: usize) bool {
        const title_ref = writer.string(self.title) orelse return false;
        const detail_ref = writer.string(self.detail) orelse return false;
        return writer.record(index, .alert, packedAlertId(self.destructive, statusIconTag(self)), title_ref, detail_ref);
    }

    pub fn fromView(view: object.View) Error!Alert {
        const alert = try component_codec.nodeView(view, .alert);
        return fromNode(alert);
    }

    pub fn fromNode(alert: @FieldType(ui.Node, "alert")) Error!Alert {
        return .{ .title = alert.title, .detail = alert.detail, .destructive = alert.destructive, .icon_slot = try IconSlot.fromTag(.status, alert.icon) };
    }
};

fn statusIcon(self: Alert) Icon {
    if (self.icon_slot.optional()) |slot| return slot;
    return Icon.named(if (self.destructive) .alert_circle else .shield);
}

fn statusIconTag(self: Alert) u16 {
    return self.icon_slot.tag();
}

pub fn packedAlertId(destructive: bool, icon_tag: u16) u32 {
    const destructive_bit: u32 = if (destructive) 1 else 0;
    return destructive_bit | (@as(u32, icon_tag) << alert_icon_shift);
}

fn textWidth(bounds: ui.Rect) f32 {
    return @max(component_primitives.min_extent, bounds.w - alert_text_x - alert_padding_x);
}

const alert_radius: f32 = 8.0;
const alert_padding_x: f32 = 16.0;
const alert_padding_y: f32 = 12.0;
const alert_icon_size: f32 = 16.0;
const alert_text_x: f32 = 44.0;
const alert_title_height: f32 = 16.0;
const alert_title_max_lines: usize = 2;
const alert_detail_gap: f32 = 2.0;
const alert_detail_height: f32 = 16.0;
const alert_detail_max_lines: usize = 2;
const alert_min_width: f32 = 160.0;
const alert_min_height: f32 = 48.0;
const alert_icon_shift: u5 = 1;
const alert_danger = ui.Color{ .r = 239, .g = 68, .b = 68 };

test "alert component serializes icon slot to canonical object and deserializes" {
    const alert = Alert{ .title = "Heads up", .detail = "Status message", .destructive = true, .icon_slot = IconSlot.named(.status, .alert_circle) };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = alert.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Alert.fromView(try object.View.decode(canonical));

    try std.testing.expectEqualStrings(alert.title, decoded.title);
    try std.testing.expectEqualStrings(alert.detail, decoded.detail);
    try std.testing.expect(decoded.destructive);
    try std.testing.expectEqual(Icon.named(.alert_circle).value, decoded.icon_slot.status.value);
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

test "alert measurement wraps long title and detail under narrow constraints" {
    const alert = Alert{
        .title = "Runtime authority warning",
        .detail = "The signed runtime path must explain the blocked action",
        .destructive = true,
    };
    const compact = Alert{ .title = "Heads up", .detail = "Status message", .destructive = true };

    const measured = alert.measure(.{ .width = .{ .at_most = alert_min_width }, .text_wrap = .wrap }, .{});
    const compact_measured = compact.measure(.{ .width = .{ .at_most = alert_min_width }, .text_wrap = .wrap }, .{});

    try std.testing.expect(measured.preferred.w <= alert_min_width);
    try std.testing.expect(measured.preferred.h > compact_measured.preferred.h);
}
