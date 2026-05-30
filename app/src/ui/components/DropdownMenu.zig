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

pub const DropdownMenu = struct {
    id: u32,
    first: []const u8,
    second: []const u8,

    pub fn node(self: DropdownMenu) ui.Node {
        return ui.dropdownMenuNode(self.id, self.first, self.second);
    }

    pub fn accessibility(self: DropdownMenu) common.Accessibility {
        return .{ .role = .menu, .label = self.first, .control_id = self.id };
    }

    pub fn render(self: DropdownMenu, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        try primitives.renderSidePanelTrigger(scene, bounds, menu_panel_layout, options.style.accent, options.style.border, menu_trigger_padding, dropdown_menu_trigger, options.style.bg);
        if (options.overlay.isOpen(self.id)) {
            try primitives.renderTwoItemMenuPanel(scene, primitives.sidePanelContentBounds(bounds, menu_panel_layout), self.first, self.second, options, menu_radius, menu_list_layout);
        }
    }

    pub fn collectInteractions(self: DropdownMenu, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try primitives.collectSidePanelMenuHits(collector, bounds, menu_panel_layout, self.id, menu_list_layout, menu_item_count);
    }

    pub fn measure(self: DropdownMenu, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return primitives.measureSidePanelMenu(dropdown_menu_trigger, self.first, self.second, constraints, menu_panel_layout, menu_trigger_padding, menu_list_layout);
    }

    pub fn toObject(self: DropdownMenu, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.dropdown_menu, self.id, self.first, self.second, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: DropdownMenu, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .dropdown_menu, self.id, self.first, self.second);
    }

    pub fn fromView(view: object.View) Error!DropdownMenu {
        const menu = try component_codec.nodeView(view, .dropdown_menu);
        return fromNode(menu);
    }

    pub fn fromNode(menu: @FieldType(ui.Node, "dropdown_menu")) Error!DropdownMenu {
        return .{ .id = menu.id, .first = menu.first, .second = menu.second };
    }
};

const dropdown_menu_trigger = "Open";
const menu_item_count: usize = 2;
const menu_panel_layout = primitives.SidePanelLayout{ .trigger_y = 4.0, .trigger_w = 64.0, .trigger_h = 30.0, .gap = 8.0 };
const menu_radius: f32 = 8.0;
const menu_list_layout = primitives.MenuListLayout{ .padding = 5.0, .item_h = 14.0, .item_pitch = 16.0, .item_radius = 4.0, .item_padding = 5.0, .item_text_h = 12.0 };
const menu_trigger_padding: f32 = 8.0;

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

    try menu.render(&scene, ui.Rect.init(0, 0, 240, 52), .{ .overlay = .{ .open_ids = &.{menu.id} } });
    try menu.collectInteractions(&collector, ui.Rect.init(0, 0, 240, 52));

    try std.testing.expect(component_test.hasText(scene.written(), "Open"));
    try std.testing.expect(component_test.hasText(scene.written(), "Profile"));
    try std.testing.expect(component_test.hasText(scene.written(), "Settings"));
    try std.testing.expectEqual(@as(usize, 3), collector.written().len);
    try std.testing.expectEqual(@as(u32, 1000), collector.written()[2].id);
}

test "dropdown menu measurement follows item text" {
    const short = DropdownMenu{ .id = 998, .first = "One", .second = "Two" };
    const long = DropdownMenu{ .id = 998, .first = "Runtime profile", .second = "Authority settings" };

    try std.testing.expect(long.measure(.{}, .{}).preferred.w > short.measure(.{}, .{}).preferred.w);
}
