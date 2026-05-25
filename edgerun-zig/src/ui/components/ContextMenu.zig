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

pub const ContextMenu = struct {
    id: u32,
    first: []const u8,
    second: []const u8,

    pub fn node(self: ContextMenu) ui.Node {
        return ui.contextMenuNode(self.id, self.first, self.second);
    }

    pub fn render(self: ContextMenu, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderMenu(scene, bounds, component_render.context_menu_trigger, self.first, self.second, options);
    }

    pub fn collectInteractions(self: ContextMenu, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try component_render.collectMenuInteractions(collector, bounds, self.id);
    }

    pub fn measure(self: ContextMenu, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_menu, constraints);
    }

    pub fn toObject(self: ContextMenu, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.context_menu, self.id, self.first, self.second, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: ContextMenu, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .context_menu, self.id, self.first, self.second);
    }

    pub fn fromView(view: object.View) Error!ContextMenu {
        return switch (try component_codec.singleNode(view)) {
            .context_menu => |menu| .{ .id = menu.id, .first = menu.first, .second = menu.second },
            else => error.UnsupportedComponent,
        };
    }
};

test "context menu component serializes to canonical object and deserializes" {
    const menu = ContextMenu{ .id = 999, .first = "Profile", .second = "Settings" };
    var ui_raw: [224]u8 = undefined;
    var object_raw: [object.header_size + 224]u8 = undefined;

    const canonical = menu.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try ContextMenu.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(menu.id, decoded.id);
    try std.testing.expectEqualStrings(menu.first, decoded.first);
    try std.testing.expectEqualStrings(menu.second, decoded.second);
}

test "context menu component renders menu rows and hit regions" {
    const menu = ContextMenu{ .id = 999, .first = "Profile", .second = "Settings" };
    var commands: [24]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [3]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try menu.render(&scene, ui.Rect.init(0, 0, 240, 52), .{});
    try menu.collectInteractions(&collector, ui.Rect.init(0, 0, 240, 52));

    try std.testing.expect(component_test.hasText(scene.written(), "Context"));
    try std.testing.expect(component_test.hasText(scene.written(), "Profile"));
    try std.testing.expectEqual(@as(usize, 3), collector.written().len);
    try std.testing.expectEqual(@as(u32, 1001), collector.written()[2].id);
}
