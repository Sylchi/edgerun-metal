const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_render = @import("Render.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const Dialog = struct {
    id: u32,
    title: []const u8,
    detail: []const u8,

    pub fn node(self: Dialog) ui.Node {
        return ui.dialogNode(self.id, self.title, self.detail);
    }

    pub fn render(self: Dialog, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderDialog(scene, bounds, self.title, self.detail, false, options);
    }

    pub fn collectInteractions(self: Dialog, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(component_render.dialogTriggerBounds(bounds), .button, self.id);
        try collector.addHit(component_render.dialogContentBounds(bounds), .button, self.id + 1);
    }

    pub fn measure(self: Dialog, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_dialog, constraints);
    }

    pub fn toObject(self: Dialog, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.dialog, self.id, self.title, self.detail, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Dialog, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .dialog, self.id, self.title, self.detail);
    }

    pub fn fromView(view: object.View) Error!Dialog {
        return switch (try component_codec.singleNode(view)) {
            .dialog => |dialog| .{ .id = dialog.id, .title = dialog.title, .detail = dialog.detail },
            else => error.UnsupportedComponent,
        };
    }
};

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
