const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;
const measureFixed = primitives.measureFixed;
const renderControlText = primitives.renderControlText;

pub const Tabs = struct {
    id: u32,
    first: []const u8,
    second: []const u8,
    active: u16 = 0,

    pub fn node(self: Tabs) ui.Node {
        return ui.tabsNode(self.id, self.first, self.second, activeIndex(self.active));
    }

    pub fn render(self: Tabs, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const active = activeIndex(self.active);
        const list = listBounds(bounds);
        try scene.pushRect(list, options.style.row, .fill, tabs_list_radius, 0.0);
        try renderTrigger(scene, triggerBounds(list, 0), self.first, active == 0, options);
        try renderTrigger(scene, triggerBounds(list, 1), self.second, active == 1, options);
        const panel = ui.Rect.init(bounds.x, bounds.y + tabs_list_h + tabs_gap, bounds.w, @max(primitives.min_extent, bounds.h - tabs_list_h - tabs_gap));
        try scene.pushRect(panel, options.style.panel, .fill, primitives.control_radius, 0.0);
        try scene.pushRect(panel, options.style.border, .border, primitives.control_radius, 0.0);
        try scene.pushText(ui.Rect.init(panel.x + tabs_panel_padding, panel.y + tabs_panel_padding, @max(primitives.min_extent, panel.w - tabs_panel_padding * 2.0), primitives.control_label_height), if (active == 1) self.second else self.first, options.style.muted);
    }

    pub fn collectInteractions(self: Tabs, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        const list = listBounds(bounds);
        try collector.addHit(triggerBounds(list, 0), .button, self.id);
        try collector.addHit(triggerBounds(list, 1), .button, self.id + 1);
    }

    pub fn measure(self: Tabs, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_tabs, constraints);
    }

    pub fn toObject(self: Tabs, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        var writer = component_codec.Writer.init(ui_out, 1, 1, .column, 0, 0) orelse return null;
        if (!self.writeRecord(&writer, 0)) return null;
        return writer.objectNode(object_out, component_codec.requirements(), epoch);
    }

    pub fn writeRecord(self: Tabs, writer: *component_codec.Writer, index: usize) bool {
        const first_ref = writer.string(self.first) orelse return false;
        const second_ref = writer.string(self.second) orelse return false;
        return writer.record(index, .tabs, encodedId(self.id, self.active), first_ref, second_ref);
    }

    pub fn fromView(view: object.View) Error!Tabs {
        const tabs = try component_codec.nodeView(view, .tabs);
        return .{ .id = tabs.id, .first = tabs.first, .second = tabs.second, .active = activeIndex(tabs.active) };
    }
};

fn activeIndex(value: u16) u16 {
    return @min(value, 1);
}

fn encodedId(id: u32, active: u16) u32 {
    return id * tabs_id_stride + activeIndex(active);
}

fn listBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y, @min(bounds.w, tabs_list_w), tabs_list_h);
}

fn triggerBounds(list: ui.Rect, index: usize) ui.Rect {
    const trigger_w = @max(primitives.min_extent, (list.w - tabs_list_padding * 2.0) / 2.0);
    return ui.Rect.init(list.x + tabs_list_padding + @as(f32, @floatFromInt(index)) * trigger_w, list.y + tabs_list_padding, trigger_w, @max(primitives.min_extent, list.h - tabs_list_padding * 2.0));
}

fn renderTrigger(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, active: bool, options: RenderOptions) ui.RenderError!void {
    if (active) {
        try scene.pushRect(bounds, options.style.panel, .fill, primitives.control_radius, 0.0);
        try scene.pushRect(bounds, options.style.border, .border, primitives.control_radius, 0.0);
    }
    try renderControlText(scene, bounds, toggle_text_padding, primitives.control_label_height, label, if (active) options.style.text else options.style.muted, .center);
}

const tabs_id_stride: u32 = 2;
const preferred_tabs = ui.Size{ .w = 220.0, .h = 84.0 };
const tabs_list_w: f32 = 184.0;
const tabs_list_h: f32 = 36.0;
const tabs_list_padding: f32 = 3.0;
const tabs_list_radius: f32 = 8.0;
const tabs_gap: f32 = 8.0;
const tabs_panel_padding: f32 = 10.0;
const toggle_text_padding: f32 = 8.0;

test "tabs component serializes to canonical object and deserializes" {
    const tabs = Tabs{ .id = 80, .first = "Account", .second = "Password", .active = 1 };
    var ui_raw: [160]u8 = undefined;
    var object_raw: [object.header_size + 160]u8 = undefined;

    const canonical = tabs.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Tabs.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(tabs.id, decoded.id);
    try std.testing.expectEqualStrings(tabs.first, decoded.first);
    try std.testing.expectEqualStrings(tabs.second, decoded.second);
    try std.testing.expectEqual(@as(u16, 1), decoded.active);
}

test "tabs component renders active trigger and trigger hits" {
    const tabs = Tabs{ .id = 80, .first = "Account", .second = "Password", .active = 0 };
    var commands: [20]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try tabs.render(&scene, ui.Rect.init(0, 0, 220, 84), .{});
    try tabs.collectInteractions(&collector, ui.Rect.init(0, 0, 220, 84));

    try std.testing.expect(component_test.hasText(scene.written(), "Account"));
    try std.testing.expect(component_test.hasText(scene.written(), "Password"));
    try std.testing.expectEqual(@as(usize, 2), collector.written().len);
    try std.testing.expectEqual(@as(u32, 81), collector.written()[1].id);
}
