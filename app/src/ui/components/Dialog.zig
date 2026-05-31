const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../component_common.zig");
const text_component = @import("Text.zig");
const interaction = @import("../interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../core.zig");
const layout = @import("../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const Dialog = struct {
    id: u32,
    title: []const u8,
    detail: []const u8,
    flags: common.ComponentFlags = .{},

    pub fn node(self: Dialog) ui.Node {
        return ui.dialogNode(self.id, self.title, self.detail);
    }

    pub fn accessibility(self: Dialog) common.Accessibility {
        return .{ .role = .dialog, .label = self.title, .control_id = self.id };
    }

    pub fn render(self: Dialog, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        try primitives.renderSidePanelTitleDetail(scene, bounds, self.id, options, dialog_layout, options.style.accent, options.style.border, dialog_trigger_padding, dialog_open_label, options.style.bg, dialog_panel, self.title, self.detail, options.style.text);
    }

    pub fn collectInteractions(self: Dialog, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try primitives.collectSidePanelLayoutHits(collector, bounds, dialog_layout, self.id);
    }

    pub fn measure(self: Dialog, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return primitives.measureSidePanelTitleDetail(dialog_open_label, self.title, self.detail, constraints, dialog_layout, dialog_trigger_padding, dialog_panel);
    }

    pub fn toObject(self: Dialog, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.dialog, self.id, self.title, self.detail, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Dialog, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .dialog, self.id, self.title, self.detail);
    }

    pub fn fromView(view: object.View) Error!Dialog {
        return component_codec.decodeFromView(Dialog, .dialog, view);
    }

    pub fn fromNode(dialog: @FieldType(ui.Node, "dialog")) Error!Dialog {
        return .{ .id = dialog.id, .title = dialog.title, .detail = dialog.detail };
    }
};

const dialog_layout = primitives.SidePanelLayout{ .trigger_y = 6.0, .trigger_w = 66.0, .trigger_h = 30.0, .gap = 12.0 };
const dialog_panel = primitives.TitleDetailPanel{ .radius = 10.0, .padding = 10.0, .title_y = 6.0, .title_h = 14.0, .detail_y = 22.0, .detail_h = 12.0 };
const dialog_trigger_padding: f32 = 8.0;
const dialog_open_label = "Open";

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

    try dialog.render(&scene, ui.Rect.init(0, 0, 240, 52), .{ .overlay = .{ .open_ids = &.{dialog.id} } });
    try dialog.collectInteractions(&collector, ui.Rect.init(0, 0, 240, 52));

    try std.testing.expect(component_test.hasText(scene.written(), "Edit profile"));
    try std.testing.expect(component_test.hasText(scene.written(), "Modal content"));
    try std.testing.expectEqual(@as(usize, 2), collector.written().len);
    try std.testing.expectEqual(@as(u32, 997), collector.written()[1].id);
}

test "dialog measurement follows title and detail text" {
    const short = Dialog{ .id = 996, .title = "Edit", .detail = "Body" };
    const long = Dialog{ .id = 996, .title = "Edit runtime authority", .detail = "Modal content with receipts" };

    try std.testing.expect(long.measure(.{}, .{}).preferred.w > short.measure(.{}, .{}).preferred.w);
}
