const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;
const measureFixed = primitives.measureFixed;
const renderControlFrame = primitives.renderControlFrame;
const renderControlText = primitives.renderControlText;

pub const Dialog = struct {
    id: u32,
    title: []const u8,
    detail: []const u8,

    pub fn node(self: Dialog) ui.Node {
        return ui.dialogNode(self.id, self.title, self.detail);
    }

    pub fn render(self: Dialog, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const trigger = triggerBounds(bounds);
        try renderControlFrame(scene, trigger, options.style.accent, options.style.border, primitives.control_radius);
        try renderControlText(scene, trigger, dialog_trigger_padding, primitives.control_label_height, dialog_open_label, options.style.bg, .center);

        const content = contentBounds(bounds);
        try scene.pushRect(content, options.style.panel, .fill, dialog_radius, 0.0);
        try scene.pushRect(content, options.style.border, .border, dialog_radius, 0.0);
        try scene.pushText(ui.Rect.init(content.x + dialog_padding, content.y + dialog_title_y, @max(primitives.min_extent, content.w - dialog_padding * 2.0), dialog_title_h), self.title, options.style.text);
        try scene.pushText(ui.Rect.init(content.x + dialog_padding, content.y + dialog_detail_y, @max(primitives.min_extent, content.w - dialog_padding * 2.0), dialog_detail_h), self.detail, options.style.muted);
    }

    pub fn collectInteractions(self: Dialog, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try primitives.collectSidePanelHits(collector, triggerBounds(bounds), contentBounds(bounds), self.id);
    }

    pub fn measure(self: Dialog, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_dialog, constraints);
    }

    pub fn toObject(self: Dialog, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.dialog, self.id, self.title, self.detail, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Dialog, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .dialog, self.id, self.title, self.detail);
    }

    pub fn fromView(view: object.View) Error!Dialog {
        const dialog = try component_codec.nodeView(view, .dialog);
        return .{ .id = dialog.id, .title = dialog.title, .detail = dialog.detail };
    }
};

fn triggerBounds(bounds: ui.Rect) ui.Rect {
    return primitives.sidePanelTriggerBounds(bounds, dialog_layout);
}

fn contentBounds(bounds: ui.Rect) ui.Rect {
    return primitives.sidePanelContentBounds(bounds, dialog_layout);
}

const dialog_layout = primitives.SidePanelLayout{ .trigger_y = 6.0, .trigger_w = 66.0, .trigger_h = 30.0, .gap = 12.0 };
const dialog_radius: f32 = 10.0;
const dialog_padding: f32 = 10.0;
const dialog_title_y: f32 = 6.0;
const dialog_title_h: f32 = 14.0;
const dialog_detail_y: f32 = 22.0;
const dialog_detail_h: f32 = 12.0;
const dialog_trigger_padding: f32 = 8.0;
const dialog_open_label = "Open";
const preferred_dialog = ui.Size{ .w = 240.0, .h = 52.0 };

test "dialog component serializes to canonical object and deserializes" {
    const dialog = Dialog{ .id = 996, .title = "Edit profile", .detail = "Modal content" };
    var ui_raw: [192]u8 = undefined;
    var object_raw: [object.header_size + 192]u8 = undefined;

    const canonical = dialog.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Dialog.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(dialog.id, decoded.id);
    try std.testing.expectEqualStrings(dialog.title, decoded.title);
    try std.testing.expectEqualStrings(dialog.detail, decoded.detail);
}

test "dialog component renders trigger content and hit regions" {
    const dialog = Dialog{ .id = 996, .title = "Edit profile", .detail = "Modal content" };
    var commands: [24]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try dialog.render(&scene, ui.Rect.init(0, 0, 240, 52), .{});
    try dialog.collectInteractions(&collector, ui.Rect.init(0, 0, 240, 52));

    try std.testing.expect(component_test.hasText(scene.written(), "Edit profile"));
    try std.testing.expect(component_test.hasText(scene.written(), "Modal content"));
    try std.testing.expectEqual(@as(usize, 2), collector.written().len);
    try std.testing.expectEqual(@as(u32, 997), collector.written()[1].id);
}
