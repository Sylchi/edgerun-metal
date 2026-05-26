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
const icon_component = @import("Icon.zig");
const component_primitives = @import("Primitives.zig");
const list_layout = @import("ListLayout.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const registration = component_contract.registration("navigation_menu", NavigationMenu);
const contentInset = component_primitives.contentInset;
const measureFixed = component_primitives.measureFixed;
const Icon = icon_component.Icon;

pub const NavigationMenu = struct {
    id: u32,
    first: []const u8,
    second: []const u8,
    active: u16 = 0,

    pub fn node(self: NavigationMenu) ui.Node {
        return ui.navigationMenuNode(self.id, self.first, self.second, activeIndex(self.active));
    }

    pub fn accessibility(self: NavigationMenu) common.Accessibility {
        return .{ .role = .menu, .label = self.first, .control_id = self.id };
    }

    pub fn render(self: NavigationMenu, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const active = activeIndex(self.active);
        try renderItem(scene, itemBounds(bounds, 0), self.first, active == 0, true, options);
        try renderItem(scene, itemBounds(bounds, 1), self.second, active == 1, true, options);
        try renderItem(scene, itemBounds(bounds, 2), navigation_menu_third_label, active == 2, false, options);
    }

    pub fn collectInteractions(self: NavigationMenu, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try list_layout.collectItemStripHits(collector, bounds, self.id, &navigation_menu_item_widths, navigation_menu_strip_layout);
    }

    pub fn measure(self: NavigationMenu, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_navigation_menu, constraints);
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
        const menu = try component_codec.nodeView(view, .navigation_menu);
        return fromNode(menu);
    }

    pub fn fromNode(menu: @FieldType(ui.Node, "navigation_menu")) Error!NavigationMenu {
        return .{ .id = menu.id, .first = menu.first, .second = menu.second, .active = activeIndex(menu.active) };
    }
};

fn activeIndex(value: u16) u16 {
    return list_layout.clampedIndex(value, navigation_menu_item_count);
}

fn encodedId(id: u32, active: u16) u32 {
    return list_layout.encodedIndexedId(id, active, navigation_menu_item_count);
}

pub const navigation_menu_id_stride: u32 = navigation_menu_item_count;

fn renderItem(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, active: bool, show_chevron: bool, options: RenderOptions) ui.RenderError!void {
    try scene.pushRect(bounds, if (active) options.style.row else ui.Color.clear, .fill, component_primitives.control_radius, 0.0);
    const icon_space: f32 = if (show_chevron) navigation_menu_icon_space else 0.0;
    const text_bounds = ui.Rect.init(bounds.x, bounds.y, @max(component_primitives.min_extent, bounds.w - icon_space), bounds.h);
    const text_color = if (active) options.style.text else options.style.muted;
    if (contentInset(text_bounds, navigation_menu_text_padding)) |inner| {
        try scene.pushAlignedText(inner.withHeightCentered(component_primitives.control_label_height), label, text_color, .center);
    }
    if (show_chevron) {
        try Icon.named(.chevron_right).renderColor(scene, ui.Rect.init(
            bounds.x + bounds.w - navigation_menu_icon_size - navigation_menu_icon_padding,
            bounds.y + (bounds.h - navigation_menu_icon_size) * 0.5,
            navigation_menu_icon_size,
            navigation_menu_icon_size,
        ), options.style.muted);
    }
}

fn itemBounds(bounds: ui.Rect, index: usize) ui.Rect {
    return list_layout.itemStripBounds(bounds, index, &navigation_menu_item_widths, navigation_menu_strip_layout);
}

pub const navigation_menu_item_count: u16 = 3;
const navigation_menu_gap: f32 = 4.0;
const navigation_menu_item_h: f32 = 36.0;
const navigation_menu_item_widths = [_]f32{ 62.0, 112.0, 56.0 };
const navigation_menu_strip_layout = list_layout.ItemStripLayout{ .gap = navigation_menu_gap, .item_h = navigation_menu_item_h };
const navigation_menu_text_padding: f32 = 10.0;
const navigation_menu_icon_size: f32 = 12.0;
const navigation_menu_icon_space: f32 = 16.0;
const navigation_menu_icon_padding: f32 = 8.0;
const navigation_menu_third_label = "Blocks";
pub const preferred_navigation_menu = ui.Size{ .w = 220.0, .h = 36.0 };

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
    var regions: [navigation_menu_item_count]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try menu.render(&scene, ui.Rect.init(0, 0, 220, 36), .{});
    try menu.collectInteractions(&collector, ui.Rect.init(0, 0, 220, 36));

    try std.testing.expect(component_test.hasText(scene.written(), "Docs"));
    try std.testing.expect(component_test.hasText(scene.written(), "Components"));
    try std.testing.expect(component_test.hasText(scene.written(), "Blocks"));
    try std.testing.expectEqual(@as(usize, navigation_menu_item_count), collector.written().len);
    try std.testing.expectEqual(@as(u32, 211), collector.written()[1].id);
}
