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

pub const Sidebar = struct {
    id: u32,
    title: []const u8,
    item: []const u8,

    pub fn node(self: Sidebar) ui.Node {
        return ui.sidebarNode(self.id, self.title, self.item);
    }

    pub fn render(self: Sidebar, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderSidebar(scene, bounds, self.title, self.item, options);
    }

    pub fn collectInteractions(self: Sidebar, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(component_render.sidebarTriggerBounds(bounds), .button, self.id);
        try collector.addHit(component_render.sidebarItemBounds(bounds), .row_item, self.id + 1);
    }

    pub fn measure(self: Sidebar, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_sidebar, constraints);
    }

    pub fn toObject(self: Sidebar, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.sidebar, self.id, self.title, self.item, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Sidebar, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .sidebar, self.id, self.title, self.item);
    }

    pub fn fromView(view: object.View) Error!Sidebar {
        return switch (try component_codec.singleNode(view)) {
            .sidebar => |sidebar| .{ .id = sidebar.id, .title = sidebar.title, .item = sidebar.item },
            else => error.UnsupportedComponent,
        };
    }
};

test "sidebar component serializes to canonical object and deserializes" {
    const sidebar = Sidebar{ .id = 1003, .title = "Workspace", .item = "Nav" };
    var ui_raw: [192]u8 = undefined;
    var object_raw: [object.header_size + 192]u8 = undefined;

    const canonical = sidebar.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Sidebar.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(sidebar.id, decoded.id);
    try std.testing.expectEqualStrings(sidebar.title, decoded.title);
    try std.testing.expectEqualStrings(sidebar.item, decoded.item);
}

test "sidebar component renders rail item and hit regions" {
    const sidebar = Sidebar{ .id = 1003, .title = "Workspace", .item = "Nav" };
    var commands: [24]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try sidebar.render(&scene, ui.Rect.init(0, 0, 240, 64), .{});
    try sidebar.collectInteractions(&collector, ui.Rect.init(0, 0, 240, 64));

    try std.testing.expect(component_test.hasText(scene.written(), "Workspace"));
    try std.testing.expect(component_test.hasText(scene.written(), "Nav"));
    try std.testing.expectEqual(@as(usize, 2), collector.written().len);
    try std.testing.expectEqual(ui.HitKind.row_item, collector.written()[1].kind);
}
