const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const text_component = @import("Text.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_primitives = @import("Primitives.zig");
const list_layout = @import("ListLayout.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

const contentInset = component_primitives.contentInset;

pub const Menubar = struct {
    id: u32,
    first: []const u8,
    second: []const u8,
    active: u16 = 0,

    pub fn node(self: Menubar) ui.Node {
        return ui.menubarNode(self.id, self.first, self.second, activeIndex(self.active));
    }

    pub fn accessibility(self: Menubar) common.Accessibility {
        return .{ .role = .menu, .label = self.first, .control_id = self.id };
    }

    pub fn render(self: Menubar, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const active = activeIndex(self.active);
        try scene.pushRect(bounds, options.style.panel, .fill, component_primitives.control_radius, 0.0);
        try scene.pushRect(bounds, options.style.border, .border, component_primitives.control_radius, 0.0);
        const widths = itemWidths(self);
        try renderItem(scene, itemBounds(bounds, &widths, 0), self.first, active == 0, options);
        try renderItem(scene, itemBounds(bounds, &widths, 1), self.second, active == 1, options);
        try renderItem(scene, itemBounds(bounds, &widths, 2), menubar_third_label, active == 2, options);
    }

    pub fn collectInteractions(self: Menubar, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        const widths = itemWidths(self);
        try list_layout.collectItemStripHits(collector, bounds, self.id, &widths, menubar_strip_layout);
    }

    pub fn measure(self: Menubar, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        const widths = itemWidths(self);
        const preferred = component_primitives.constrainPreferredSize(.{
            .w = widths[0] + widths[1] + widths[2] + menubar_padding * 2.0,
            .h = menubar_item_h + menubar_padding * 2.0,
        }, constraints);
        return layout.Measurement.flexible(
            .{ .w = component_primitives.min_extent * 3.0 + menubar_padding * 2.0, .h = menubar_item_h + menubar_padding * 2.0 },
            preferred,
            .{ .w = component_primitives.maxMeasuredWidth(constraints, preferred.w), .h = preferred.h },
        ).applyExact(constraints);
    }

    pub fn toObject(self: Menubar, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        var writer = component_codec.Writer.init(ui_out, 1, 1, .column, 0, 0) orelse return null;
        if (!self.writeRecord(&writer, 0)) return null;
        return writer.objectNode(object_out, component_codec.requirements(), epoch);
    }

    pub fn writeRecord(self: Menubar, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .menubar, encodedId(self.id, self.active), self.first, self.second);
    }

    pub fn fromView(view: object.View) Error!Menubar {
        const menubar = try component_codec.nodeView(view, .menubar);
        return fromNode(menubar);
    }

    pub fn fromNode(menubar: @FieldType(ui.Node, "menubar")) Error!Menubar {
        return .{ .id = menubar.id, .first = menubar.first, .second = menubar.second, .active = activeIndex(menubar.active) };
    }
};

fn activeIndex(value: u16) u16 {
    return list_layout.clampedIndex(value, menubar_item_count);
}

fn encodedId(id: u32, active: u16) u32 {
    return list_layout.encodedIndexedId(id, active, menubar_item_count);
}

pub const menubar_id_stride: u32 = menubar_item_count;

fn renderItem(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, active: bool, options: RenderOptions) ui.RenderError!void {
    try scene.pushRect(bounds, if (active) options.style.row else ui.Color.clear, .fill, component_primitives.control_radius, 0.0);
    const text_color = if (active) options.style.text else options.style.muted;
    if (contentInset(bounds, menubar_item_padding_x)) |text_bounds| {
        try text_component.Text.renderAligned(scene, text_bounds.withHeightCentered(component_primitives.control_label_height), label, text_color, .center);
    }
}

fn itemBounds(bounds: ui.Rect, widths: []const f32, index: usize) ui.Rect {
    return list_layout.itemStripBounds(bounds, index, widths, menubar_strip_layout);
}

fn itemWidths(self: Menubar) [menubar_item_count]f32 {
    return .{
        itemWidth(self.first),
        itemWidth(self.second),
        itemWidth(menubar_third_label),
    };
}

fn itemWidth(label: []const u8) f32 {
    const measured = text_component.Text.measureValue(label, .{ .width = .unconstrained, .text_wrap = .nowrap }, component_primitives.textMetrics(label, component_primitives.control_label_height, menubar_label_max_lines));
    return measured.preferred.w + menubar_item_padding_x * 2.0;
}

pub const menubar_item_count: u16 = 3;
const menubar_padding: f32 = 4.0;
const menubar_item_h: f32 = 28.0;
const menubar_strip_layout = list_layout.ItemStripLayout{ .padding = menubar_padding, .item_h = menubar_item_h };
const menubar_item_padding_x: f32 = 8.0;
const menubar_third_label = "View";
const menubar_label_max_lines: usize = 1;

test "menubar component serializes to canonical object and deserializes" {
    const menubar = Menubar{ .id = 120, .first = "File", .second = "Edit", .active = 2 };
    var ui_raw: [160]u8 = undefined;
    var object_raw: [object.header_size + 160]u8 = undefined;

    const canonical = menubar.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Menubar.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(menubar.id, decoded.id);
    try std.testing.expectEqualStrings(menubar.first, decoded.first);
    try std.testing.expectEqualStrings(menubar.second, decoded.second);
    try std.testing.expectEqual(@as(u16, 2), decoded.active);
}

test "menubar component renders items and hit regions" {
    const menubar = Menubar{ .id = 120, .first = "File", .second = "Edit", .active = 1 };
    var commands: [24]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [menubar_item_count]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try menubar.render(&scene, ui.Rect.init(0, 0, 170, 36), .{});
    try menubar.collectInteractions(&collector, ui.Rect.init(0, 0, 170, 36));

    try std.testing.expect(component_test.hasText(scene.written(), "File"));
    try std.testing.expect(component_test.hasText(scene.written(), "Edit"));
    try std.testing.expect(component_test.hasText(scene.written(), "View"));
    try std.testing.expectEqual(@as(usize, menubar_item_count), collector.written().len);
    try std.testing.expectEqual(@as(u32, 122), collector.written()[2].id);
}

test "menubar measurement follows item labels" {
    const short = Menubar{ .id = 120, .first = "F", .second = "E", .active = 0 };
    const long = Menubar{ .id = 120, .first = "Runtime", .second = "Authority", .active = 0 };

    try std.testing.expect(long.measure(.{}, .{}).preferred.w > short.measure(.{}, .{}).preferred.w);
}
