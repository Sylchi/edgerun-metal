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

pub const Toast = struct {
    id: u32,
    title: []const u8,
    detail: []const u8,

    pub fn node(self: Toast) ui.Node {
        return ui.toastNode(self.id, self.title, self.detail);
    }

    pub fn render(self: Toast, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderToast(scene, bounds, self.title, self.detail, options);
    }

    pub fn collectInteractions(self: Toast, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(component_render.toastBounds(bounds), .button, self.id);
    }

    pub fn measure(self: Toast, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_toast, constraints);
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
