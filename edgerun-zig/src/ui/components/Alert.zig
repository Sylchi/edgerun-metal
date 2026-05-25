const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_render = @import("Render.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const Alert = struct {
    title: []const u8,
    detail: []const u8,
    destructive: bool = false,

    pub fn node(self: Alert) ui.Node {
        return ui.alertNode(self.title, self.detail, self.destructive);
    }

    pub fn render(self: Alert, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderAlert(scene, bounds, self.title, self.detail, self.destructive, options);
    }

    pub fn measure(self: Alert, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_alert, constraints);
    }

    pub fn toObject(self: Alert, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        var writer = component_codec.Writer.init(ui_out, 1, 1, .column, 0, 0) orelse return null;
        if (!self.writeRecord(&writer, 0)) return null;
        return writer.objectNode(object_out, req, epoch);
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

test "alert component serializes to canonical object and deserializes" {
    const alert = Alert{ .title = "Heads up", .detail = "Status message", .destructive = true };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = alert.toObject(&ui_raw, &object_raw, component_test.req(), component_test.epoch()).?;
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
