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
const icon_component = @import("Icon.zig");
const primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

const constrainPreferredSize = primitives.constrainPreferredSize;
const Icon = icon_component.Icon;

pub const Sidebar = struct {
    id: u32,
    title: []const u8,
    item: []const u8,

    pub fn node(self: Sidebar) ui.Node {
        return ui.sidebarNode(self.id, self.title, self.item);
    }

    pub fn render(self: Sidebar, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const rail = railBounds(bounds);
        try scene.pushRect(rail, options.style.panel, .fill, sidebar_radius, 0.0);
        try scene.pushRect(rail, options.style.border, .border, sidebar_radius, 0.0);
        try Icon.named(.menu).renderColor(scene, triggerBounds(bounds), options.style.text);
        try text_component.Text.renderWrapped(scene, titleBounds(bounds, self.title), self.title, options.style.muted, primitives.textWrap(self.title, sidebar_title_h, sidebar_title_max_lines));
        const item_bounds = itemBounds(bounds, self.title, self.item);
        try scene.pushRect(item_bounds, options.style.row, .fill, sidebar_item_radius, 0.0);
        const item_text = itemTextBounds(item_bounds, self.item);
        try text_component.Text.renderWrapped(scene, item_text, self.item, options.style.text, primitives.textWrap(self.item, sidebar_item_text_h, sidebar_item_max_lines));
        const content = contentBounds(bounds);
        try scene.pushRect(content, options.style.row, .fill, sidebar_radius, 0.0);
    }

    pub fn collectInteractions(self: Sidebar, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(triggerBounds(bounds), .button, self.id);
        try collector.addHit(itemBounds(bounds, self.title, self.item), .row_item, self.id + 1);
    }

    pub fn measure(self: Sidebar, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        const title_inner_width = sidebar_rail_w - sidebar_item_x * 2.0;
        const title = text_component.Text.measureValue(self.title, .{ .width = .{ .at_most = title_inner_width }, .text_wrap = .wrap }, primitives.textMetrics(self.title, sidebar_title_h, sidebar_title_max_lines));
        const item_inner_width = sidebar_rail_w - sidebar_item_x * 2.0 - sidebar_item_padding * 2.0;
        const item = text_component.Text.measureValue(self.item, .{ .width = .{ .at_most = item_inner_width }, .text_wrap = .wrap }, primitives.textMetrics(self.item, sidebar_item_text_h, sidebar_item_max_lines));
        const rail_h = sidebar_item_y + title.preferred.h - sidebar_title_h + @max(sidebar_item_h, item.preferred.h + sidebar_item_padding * 2.0) + sidebar_item_bottom_padding;
        const preferred = constrainPreferredSize(.{
            .w = @max(sidebar_min_width, sidebar_rail_w + sidebar_content_gap + sidebar_content_min_w),
            .h = @max(sidebar_min_height, rail_h),
        }, constraints);
        return layout.Measurement.flexible(
            .{ .w = @min(sidebar_min_width, preferred.w), .h = @min(sidebar_min_height, preferred.h) },
            preferred,
            .{ .w = primitives.maxMeasuredWidth(constraints, preferred.w), .h = preferred.h },
        ).applyExact(constraints);
    }

    pub fn toObject(self: Sidebar, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.sidebar, self.id, self.title, self.item, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Sidebar, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .sidebar, self.id, self.title, self.item);
    }

    pub fn fromView(view: object.View) Error!Sidebar {
        const sidebar = try component_codec.nodeView(view, .sidebar);
        return fromNode(sidebar);
    }

    pub fn fromNode(sidebar: @FieldType(ui.Node, "sidebar")) Error!Sidebar {
        return .{ .id = sidebar.id, .title = sidebar.title, .item = sidebar.item };
    }
};

fn railBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y, @min(bounds.w, sidebar_rail_w), bounds.h);
}

fn triggerBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x + sidebar_trigger_x, bounds.y + sidebar_trigger_y, sidebar_trigger_size, sidebar_trigger_size);
}

fn itemBounds(bounds: ui.Rect, title: []const u8, item: []const u8) ui.Rect {
    const item_w = @max(primitives.min_extent, sidebar_rail_w - sidebar_item_x * 2.0);
    const title_h = titleBounds(bounds, title).h;
    const text_w = @max(primitives.min_extent, item_w - sidebar_item_padding * 2.0);
    const text_h = primitives.measuredTextHeight(item, text_w, sidebar_item_text_h, sidebar_item_max_lines);
    return ui.Rect.init(bounds.x + sidebar_item_x, bounds.y + sidebar_item_y + title_h - sidebar_title_h, item_w, @max(sidebar_item_h, text_h + sidebar_item_padding * 2.0));
}

fn titleBounds(bounds: ui.Rect, title: []const u8) ui.Rect {
    const width = @max(primitives.min_extent, sidebar_rail_w - sidebar_item_x * 2.0);
    const height = primitives.measuredTextHeight(title, width, sidebar_title_h, sidebar_title_max_lines);
    return ui.Rect.init(bounds.x + sidebar_item_x, bounds.y + sidebar_title_y, width, height);
}

fn itemTextBounds(bounds: ui.Rect, item: []const u8) ui.Rect {
    const width = @max(primitives.min_extent, bounds.w - sidebar_item_padding * 2.0);
    const height = @min(bounds.h, primitives.measuredTextHeight(item, width, sidebar_item_text_h, sidebar_item_max_lines));
    return ui.Rect.init(bounds.x + sidebar_item_padding, bounds.y + (bounds.h - height) * 0.5, width, height);
}

fn contentBounds(bounds: ui.Rect) ui.Rect {
    const x = bounds.x + sidebar_rail_w + sidebar_content_gap;
    return ui.Rect.init(x, bounds.y, @max(primitives.min_extent, bounds.x + bounds.w - x), bounds.h);
}

const sidebar_rail_w: f32 = 62.0;
const sidebar_content_gap: f32 = 10.0;
const sidebar_radius: f32 = 8.0;
const sidebar_trigger_x: f32 = 8.0;
const sidebar_trigger_y: f32 = 8.0;
const sidebar_trigger_size: f32 = 16.0;
const sidebar_title_y: f32 = 10.0;
const sidebar_title_h: f32 = 12.0;
const sidebar_title_max_lines: usize = 2;
const sidebar_item_x: f32 = 6.0;
const sidebar_item_y: f32 = 34.0;
const sidebar_item_h: f32 = 20.0;
const sidebar_item_bottom_padding: f32 = 10.0;
const sidebar_item_radius: f32 = 4.0;
const sidebar_item_padding: f32 = 5.0;
const sidebar_item_text_h: f32 = 12.0;
const sidebar_item_max_lines: usize = 2;
const sidebar_content_min_w: f32 = 120.0;
const sidebar_min_width: f32 = 160.0;
const sidebar_min_height: f32 = 48.0;

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

    try std.testing.expect(component_test.textCommandPrefix(scene.written(), "Work") != null);
    try std.testing.expect(component_test.hasText(scene.written(), "Nav"));
    try std.testing.expectEqual(@as(usize, 2), collector.written().len);
    try std.testing.expectEqual(ui.HitKind.row_item, collector.written()[1].kind);
}

test "sidebar component measurement wraps long rail text" {
    const sidebar = Sidebar{ .id = 1003, .title = "Work", .item = "Nav" };
    const long_sidebar = Sidebar{ .id = 1003, .title = "Runtime Workspace Authority", .item = "Receipt History" };

    const short = sidebar.measure(.{}, .{});
    const long = long_sidebar.measure(.{}, .{});

    try std.testing.expect(long.preferred.h > short.preferred.h);
}
