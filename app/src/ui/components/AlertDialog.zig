const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const text_component = @import("Text.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const AlertDialog = struct {
    id: u32,
    title: []const u8,
    detail: []const u8,

    pub fn node(self: AlertDialog) ui.Node {
        return ui.alertDialogNode(self.id, self.title, self.detail);
    }

    pub fn accessibility(self: AlertDialog) common.Accessibility {
        return .{ .role = .dialog, .label = self.title, .control_id = self.id };
    }

    pub fn render(self: AlertDialog, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        try primitives.renderSidePanelTrigger(scene, bounds, dialog_layout, alert_danger, options.style.border, dialog_trigger_padding, dialog_delete_label, options.style.bg);
        if (options.overlay.isOpen(self.id)) {
            try primitives.renderTitleDetailPanel(scene, primitives.sidePanelContentBounds(bounds, dialog_layout), self.title, self.detail, options, dialog_panel, alert_danger, alert_danger);
        }
    }

    pub fn collectInteractions(self: AlertDialog, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try primitives.collectSidePanelLayoutHits(collector, bounds, dialog_layout, self.id);
    }

    pub fn measure(self: AlertDialog, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return primitives.measureSidePanelTitleDetail(dialog_delete_label, self.title, self.detail, constraints, dialog_layout, dialog_trigger_padding, dialog_panel);
    }

    pub fn toObject(self: AlertDialog, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.alert_dialog, self.id, self.title, self.detail, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: AlertDialog, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .alert_dialog, self.id, self.title, self.detail);
    }

    pub fn fromView(view: object.View) Error!AlertDialog {
        const dialog = try component_codec.nodeView(view, .alert_dialog);
        return fromNode(dialog);
    }

    pub fn fromNode(dialog: @FieldType(ui.Node, "alert_dialog")) Error!AlertDialog {
        return .{ .id = dialog.id, .title = dialog.title, .detail = dialog.detail };
    }
};

const alert_danger = ui.Color{ .r = 239, .g = 68, .b = 68 };
const dialog_layout = primitives.SidePanelLayout{ .trigger_y = 6.0, .trigger_w = 66.0, .trigger_h = 30.0, .gap = 12.0 };
const dialog_panel = primitives.TitleDetailPanel{ .radius = 10.0, .padding = 10.0, .title_y = 6.0, .title_h = 14.0, .detail_y = 22.0, .detail_h = 12.0 };
const dialog_trigger_padding: f32 = 8.0;
const dialog_delete_label = "Delete";

test "alert dialog component serializes to canonical object and deserializes" {
    const dialog = AlertDialog{ .id = 997, .title = "Are you sure?", .detail = "Modal content" };
    var ui_raw: [192]u8 = undefined;
    var object_raw: [object.header_size + 192]u8 = undefined;

    const canonical = dialog.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try AlertDialog.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(dialog.id, decoded.id);
    try std.testing.expectEqualStrings(dialog.title, decoded.title);
    try std.testing.expectEqualStrings(dialog.detail, decoded.detail);
}

test "alert dialog component renders destructive trigger and hit regions" {
    const dialog = AlertDialog{ .id = 997, .title = "Are you sure?", .detail = "Modal content" };
    var commands: [24]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try dialog.render(&scene, ui.Rect.init(0, 0, 240, 52), .{ .overlay = .{ .open_ids = &.{dialog.id} } });
    try dialog.collectInteractions(&collector, ui.Rect.init(0, 0, 240, 52));

    try std.testing.expect(component_test.hasText(scene.written(), "Delete"));
    try std.testing.expect(component_test.hasText(scene.written(), "Are you sure?"));
    try std.testing.expectEqual(@as(usize, 2), collector.written().len);
    try std.testing.expectEqual(@as(u32, 998), collector.written()[1].id);
}

test "alert dialog measurement follows title and detail text" {
    const short = AlertDialog{ .id = 997, .title = "Delete?", .detail = "Body" };
    const long = AlertDialog{ .id = 997, .title = "Delete runtime authority?", .detail = "This action changes receipt state" };

    try std.testing.expect(long.measure(.{}, .{}).preferred.w > short.measure(.{}, .{}).preferred.w);
}
