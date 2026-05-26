const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const component_contract = @import("ComponentContract.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const registration = component_contract.registration("context_menu", ContextMenu);
const measureFixed = primitives.measureFixed;

pub const ContextMenu = struct {
    id: u32,
    first: []const u8,
    second: []const u8,

    pub fn node(self: ContextMenu) ui.Node {
        return ui.contextMenuNode(self.id, self.first, self.second);
    }

    pub fn accessibility(self: ContextMenu) common.Accessibility {
        return .{ .role = .menu, .label = self.first, .control_id = self.id };
    }

    pub fn render(self: ContextMenu, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        try primitives.renderSidePanelTrigger(scene, bounds, menu_panel_layout, options.style.accent, options.style.border, menu_trigger_padding, context_menu_trigger, options.style.bg);
        try primitives.renderTwoItemMenuPanel(scene, primitives.sidePanelContentBounds(bounds, menu_panel_layout), self.first, self.second, options, menu_radius, menu_list_layout);
    }

    pub fn collectInteractions(self: ContextMenu, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try primitives.collectSidePanelMenuHits(collector, bounds, menu_panel_layout, self.id, menu_list_layout, menu_item_count);
    }

    pub fn measure(self: ContextMenu, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_context_menu, constraints);
    }

    pub fn toObject(self: ContextMenu, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.context_menu, self.id, self.first, self.second, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: ContextMenu, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .context_menu, self.id, self.first, self.second);
    }

    pub fn fromView(view: object.View) Error!ContextMenu {
        const menu = try component_codec.nodeView(view, .context_menu);
        return fromNode(menu);
    }

    pub fn fromNode(menu: @FieldType(ui.Node, "context_menu")) Error!ContextMenu {
        return .{ .id = menu.id, .first = menu.first, .second = menu.second };
    }
};

const context_menu_trigger = "Context";
const menu_item_count: usize = 2;
const menu_panel_layout = primitives.SidePanelLayout{ .trigger_y = 4.0, .trigger_w = 64.0, .trigger_h = 30.0, .gap = 8.0 };
const menu_radius: f32 = 8.0;
const menu_list_layout = primitives.MenuListLayout{ .padding = 5.0, .item_h = 14.0, .item_pitch = 16.0, .item_radius = 4.0, .item_padding = 5.0, .item_text_h = 12.0 };
const menu_trigger_padding: f32 = 8.0;
const preferred_context_menu = ui.Size{ .w = 240.0, .h = 52.0 };

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
