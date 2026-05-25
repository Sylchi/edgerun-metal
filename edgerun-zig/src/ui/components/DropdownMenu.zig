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

pub const DropdownMenu = struct {
    id: u32,
    first: []const u8,
    second: []const u8,

    pub fn node(self: DropdownMenu) ui.Node {
        return ui.dropdownMenuNode(self.id, self.first, self.second);
    }

    pub fn render(self: DropdownMenu, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderMenu(scene, bounds, component_render.dropdown_menu_trigger, self.first, self.second, options);
    }

    pub fn collectInteractions(self: DropdownMenu, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try component_render.collectMenuInteractions(collector, bounds, self.id);
    }

    pub fn measure(self: DropdownMenu, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_menu, constraints);
    }

    pub fn toObject(self: DropdownMenu, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.dropdown_menu, self.id, self.first, self.second, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: DropdownMenu, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .dropdown_menu, self.id, self.first, self.second);
    }

    pub fn fromView(view: object.View) Error!DropdownMenu {
        return switch (try component_codec.singleNode(view)) {
            .dropdown_menu => |menu| .{ .id = menu.id, .first = menu.first, .second = menu.second },
            else => error.UnsupportedComponent,
        };
    }
};

test "dropdown menu component serializes to canonical object and deserializes" {
    const menu = DropdownMenu{ .id = 998, .first = "Profile", .second = "Settings" };
    var ui_raw: [224]u8 = undefined;
    var object_raw: [object.header_size + 224]u8 = undefined;

    const canonical = menu.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try DropdownMenu.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(menu.id, decoded.id);
    try std.testing.expectEqualStrings(menu.first, decoded.first);
    try std.testing.expectEqualStrings(menu.second, decoded.second);
}

test "dropdown menu component renders menu rows and hit regions" {
    const menu = DropdownMenu{ .id = 998, .first = "Profile", .second = "Settings" };
    var commands: [24]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [3]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try menu.render(&scene, ui.Rect.init(0, 0, 240, 52), .{});
    try menu.collectInteractions(&collector, ui.Rect.init(0, 0, 240, 52));

    try std.testing.expect(component_test.hasText(scene.written(), "Open"));
    try std.testing.expect(component_test.hasText(scene.written(), "Profile"));
    try std.testing.expect(component_test.hasText(scene.written(), "Settings"));
    try std.testing.expectEqual(@as(usize, 3), collector.written().len);
    try std.testing.expectEqual(@as(u32, 1000), collector.written()[2].id);
}
