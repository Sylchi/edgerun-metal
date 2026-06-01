const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../component_common.zig");
const interaction = @import("../interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../core.zig");
const text_component = @import("Text.zig");
const layout = @import("../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const icon_component = @import("Icon.zig");
const component_primitives = @import("Primitives.zig");
const list_layout = @import("ListLayout.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

const contentInset = component_primitives.contentInset;
const Icon = icon_component.Icon;

pub const NavigationMenu = struct {
    id: u32,
    flags: common.ComponentFlags = .{},
    first: []const u8,
    second: []const u8,
    active: u16 = 0,

    pub fn node(self: NavigationMenu) ui.Node {
        return ui.navigationMenuNode(self.id, self.first, self.second, list_layout.clampedIndex(self.active, navigation_menu_item_count));
    }

    pub fn accessibility(self: NavigationMenu) common.Accessibility {
        return .{ .role = .menu, .label = self.first, .control_id = self.id };
    }

    pub fn render(self: NavigationMenu, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const active = list_layout.clampedIndex(self.active, navigation_menu_item_count);
        const widths = itemWidths(self);
        try renderItem(scene, itemBounds(bounds, &widths, 0), self.first, active == 0, true, options);
        try renderItem(scene, itemBounds(bounds, &widths, 1), self.second, active == 1, true, options);
        try renderItem(scene, itemBounds(bounds, &widths, 2), navigation_menu_third_label, active == 2, false, options);
    }

    pub fn collectInteractions(self: NavigationMenu, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        const widths = itemWidths(self);
        try list_layout.collectItemStripHits(collector, bounds, self.id, &widths, navigation_menu_strip_layout);
    }

    pub fn measure(self: NavigationMenu, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        const widths = itemWidths(self);
        const preferred = component_primitives.constrainPreferredSize(.{
            .w = widths[0] + widths[1] + widths[2] + navigation_menu_gap * 2.0,
            .h = navigation_menu_item_h,
        }, constraints);
        return layout.Measurement.flexible(
            .{ .w = component_primitives.min_extent * 3.0 + navigation_menu_gap * 2.0, .h = navigation_menu_item_h },
            preferred,
            .{ .w = component_primitives.maxMeasuredWidth(constraints, preferred.w), .h = preferred.h },
        ).applyExact(constraints);
    }

    pub fn toObject(self: NavigationMenu, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.singleObjectFromRecord(@TypeOf(self), self, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: NavigationMenu, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .navigation_menu, list_layout.encodedIndexedId(self.id, self.active, navigation_menu_item_count), self.first, self.second);
    }

    pub fn fromView(view: object.View) Error!NavigationMenu {
        return component_codec.decodeFromView(NavigationMenu, .navigation_menu, view);
    }

    pub fn fromNode(menu: @FieldType(ui.Node, "navigation_menu")) Error!NavigationMenu {
        return .{ .id = menu.id, .first = menu.first, .second = menu.second, .active = list_layout.clampedIndex(menu.active, navigation_menu_item_count) };
    }
};

pub const navigation_menu_id_stride: u32 = navigation_menu_item_count;

fn renderItem(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, active: bool, show_chevron: bool, options: RenderOptions) ui.RenderError!void {
    try scene.pushRect(bounds, if (active) options.style.row else ui.Color.clear, .fill, component_primitives.control_radius, 0.0);
    const icon_space: f32 = if (show_chevron) navigation_menu_icon_space else 0.0;
    const text_bounds = ui.Rect.init(bounds.x, bounds.y, @max(component_primitives.min_extent, bounds.w - icon_space), bounds.h);
    const text_color = if (active) options.style.text else options.style.muted;
    if (contentInset(text_bounds, navigation_menu_text_padding)) |inner| {
        try text_component.Text.renderAligned(scene, inner.withHeightCentered(component_primitives.control_label_height), label, text_color, .center);
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

fn itemBounds(bounds: ui.Rect, widths: []const f32, index: usize) ui.Rect {
    return list_layout.itemStripBounds(bounds, index, widths, navigation_menu_strip_layout);
}

fn itemWidths(self: NavigationMenu) [navigation_menu_item_count]f32 {
    return .{
        itemWidth(self.first, true),
        itemWidth(self.second, true),
        itemWidth(navigation_menu_third_label, false),
    };
}

fn itemWidth(label: []const u8, show_chevron: bool) f32 {
    const icon_space: f32 = if (show_chevron) navigation_menu_icon_space else 0.0;
    return component_primitives.measuredLabelWidth(label, component_primitives.control_label_height, navigation_menu_label_max_lines, navigation_menu_text_padding) + icon_space;
}

pub const navigation_menu_item_count: u16 = 3;
const navigation_menu_gap: f32 = 4.0;
const navigation_menu_item_h: f32 = 36.0;
const navigation_menu_strip_layout = list_layout.ItemStripLayout{ .gap = navigation_menu_gap, .item_h = navigation_menu_item_h };
const navigation_menu_text_padding: f32 = 10.0;
const navigation_menu_icon_size: f32 = 12.0;
const navigation_menu_icon_space: f32 = 16.0;
const navigation_menu_icon_padding: f32 = 8.0;
const navigation_menu_third_label = "Blocks";
const navigation_menu_label_max_lines: usize = 1;

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

test "navigation menu measurement follows item labels" {
    const short = NavigationMenu{ .id = 210, .first = "D", .second = "C", .active = 0 };
    const long = NavigationMenu{ .id = 210, .first = "Runtime docs", .second = "Authority components", .active = 0 };

    try std.testing.expect(long.measure(.{}, .{}).preferred.w > short.measure(.{}, .{}).preferred.w);
}
