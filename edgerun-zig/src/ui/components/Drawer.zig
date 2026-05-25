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

pub const Drawer = struct {
    id: u32,
    title: []const u8,
    detail: []const u8,

    pub fn node(self: Drawer) ui.Node {
        return ui.drawerNode(self.id, self.title, self.detail);
    }

    pub fn render(self: Drawer, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderDrawer(scene, bounds, self.title, self.detail, options);
    }

    pub fn collectInteractions(self: Drawer, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(component_render.drawerTriggerBounds(bounds), .button, self.id);
        try collector.addHit(component_render.drawerContentBounds(bounds), .button, self.id + 1);
    }

    pub fn measure(self: Drawer, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_drawer, constraints);
    }

    pub fn toObject(self: Drawer, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.drawer, self.id, self.title, self.detail, ui_out, object_out, req, epoch);
    }

    pub fn writeRecord(self: Drawer, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .drawer, self.id, self.title, self.detail);
    }

    pub fn fromView(view: object.View) Error!Drawer {
        return switch (try component_codec.singleNode(view)) {
            .drawer => |drawer| .{ .id = drawer.id, .title = drawer.title, .detail = drawer.detail },
            else => error.UnsupportedComponent,
        };
    }
};

test "drawer component serializes to canonical object and deserializes" {
    const drawer = Drawer{ .id = 998, .title = "Edit profile", .detail = "Drawer content" };
    var ui_raw: [192]u8 = undefined;
    var object_raw: [object.header_size + 192]u8 = undefined;

    const canonical = drawer.toObject(&ui_raw, &object_raw, component_test.req(), component_test.epoch()).?;
    const decoded = try Drawer.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(drawer.id, decoded.id);
    try std.testing.expectEqualStrings(drawer.title, decoded.title);
    try std.testing.expectEqualStrings(drawer.detail, decoded.detail);
}

test "drawer component renders trigger content and hit regions" {
    const drawer = Drawer{ .id = 998, .title = "Edit profile", .detail = "Drawer content" };
    var commands: [24]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try drawer.render(&scene, ui.Rect.init(0, 0, 240, 76), .{});
    try drawer.collectInteractions(&collector, ui.Rect.init(0, 0, 240, 76));

    try std.testing.expect(component_test.hasText(scene.written(), "Edit profile"));
    try std.testing.expect(component_test.hasText(scene.written(), "Drawer content"));
    try std.testing.expectEqual(@as(usize, 2), collector.written().len);
    try std.testing.expectEqual(@as(u32, 999), collector.written()[1].id);
}
