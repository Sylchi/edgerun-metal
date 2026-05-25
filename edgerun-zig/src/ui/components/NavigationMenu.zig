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

pub const NavigationMenu = struct {
    id: u32,
    first: []const u8,
    second: []const u8,
    active: u16 = 0,

    pub fn node(self: NavigationMenu) ui.Node {
        return ui.navigationMenuNode(self.id, self.first, self.second, activeIndex(self.active));
    }

    pub fn render(self: NavigationMenu, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderNavigationMenu(scene, bounds, self.first, self.second, activeIndex(self.active), options);
    }

    pub fn collectInteractions(self: NavigationMenu, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        for (0..component_render.navigation_menu_item_count) |index| {
            try collector.addHit(component_render.navigationMenuItemBounds(bounds, index), .button, self.id + @as(u32, @intCast(index)));
        }
    }

    pub fn measure(self: NavigationMenu, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_navigation_menu, constraints);
    }

    pub fn toObject(self: NavigationMenu, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        var writer = component_codec.Writer.init(ui_out, 1, 1, .column, 0, 0) orelse return null;
        if (!self.writeRecord(&writer, 0)) return null;
        return writer.objectNode(object_out, component_codec.requirements(), epoch);
    }

    pub fn writeRecord(self: NavigationMenu, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .navigation_menu, encodedId(self.id, self.active), self.first, self.second);
    }

    pub fn fromView(view: object.View) Error!NavigationMenu {
        return switch (try component_codec.singleNode(view)) {
            .navigation_menu => |menu| .{ .id = menu.id, .first = menu.first, .second = menu.second, .active = activeIndex(menu.active) },
            else => error.UnsupportedComponent,
        };
    }
};

fn activeIndex(value: u16) u16 {
    return @min(value, component_render.navigation_menu_item_count - 1);
}

fn encodedId(id: u32, active: u16) u32 {
    return id * navigation_menu_id_stride + activeIndex(active);
}

pub const navigation_menu_id_stride: u32 = component_render.navigation_menu_item_count;

test "navigation menu component serializes to canonical object and deserializes" {
    const menu = NavigationMenu{ .id = 210, .first = "Docs", .second = "Components", .active = 1 };
    var ui_raw: [192]u8 = undefined;
    var object_raw: [object.header_size + 192]u8 = undefined;

    const canonical = menu.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try NavigationMenu.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(menu.id, decoded.id);
    try std.testing.expectEqualStrings(menu.first, decoded.first);
    try std.testing.expectEqualStrings(menu.second, decoded.second);
    try std.testing.expectEqual(@as(u16, 1), decoded.active);
}

test "navigation menu component renders triggers and hit regions" {
    const menu = NavigationMenu{ .id = 210, .first = "Docs", .second = "Components", .active = 1 };
    var commands: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [component_render.navigation_menu_item_count]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try menu.render(&scene, ui.Rect.init(0, 0, 220, 36), .{});
    try menu.collectInteractions(&collector, ui.Rect.init(0, 0, 220, 36));

    try std.testing.expect(component_test.hasText(scene.written(), "Docs"));
    try std.testing.expect(component_test.hasText(scene.written(), "Components"));
    try std.testing.expect(component_test.hasText(scene.written(), "Blocks"));
    try std.testing.expectEqual(@as(usize, component_render.navigation_menu_item_count), collector.written().len);
    try std.testing.expectEqual(@as(u32, 211), collector.written()[1].id);
}
