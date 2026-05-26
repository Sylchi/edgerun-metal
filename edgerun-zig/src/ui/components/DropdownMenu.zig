const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const tokens = @import("../../ui_tokens.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");

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
        const trigger_bounds = triggerBounds(bounds);
        try renderControlFrame(scene, trigger_bounds, options.style.accent, options.style.border, control_radius);
        try renderControlText(scene, trigger_bounds, menu_trigger_padding, control_label_height, dropdown_menu_trigger, options.style.bg, .center);

        const content = contentBounds(bounds);
        try scene.pushRect(content, options.style.panel, .fill, menu_radius, 0.0);
        try scene.pushRect(content, options.style.border, .border, menu_radius, 0.0);
        try renderMenuItem(scene, itemBounds(content, 0), self.first, options);
        try renderMenuItem(scene, itemBounds(content, 1), self.second, options);
    }

    pub fn collectInteractions(self: DropdownMenu, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(triggerBounds(bounds), .button, self.id);
        const content = contentBounds(bounds);
        try collector.addHit(itemBounds(content, 0), .row_item, self.id + 1);
        try collector.addHit(itemBounds(content, 1), .row_item, self.id + 2);
    }

    pub fn measure(self: DropdownMenu, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_dropdown_menu, constraints);
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

fn triggerBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y + menu_trigger_y, menu_trigger_w, menu_trigger_h);
}

fn contentBounds(bounds: ui.Rect) ui.Rect {
    const x = bounds.x + menu_trigger_w + menu_gap;
    return ui.Rect.init(x, bounds.y, @max(min_extent, bounds.x + bounds.w - x), bounds.h);
}

fn itemBounds(content: ui.Rect, index: usize) ui.Rect {
    return ui.Rect.init(content.x + menu_padding, content.y + menu_padding + @as(f32, @floatFromInt(index)) * menu_item_pitch, @max(min_extent, content.w - menu_padding * 2.0), menu_item_h);
}

fn renderMenuItem(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, options: RenderOptions) ui.RenderError!void {
    try scene.pushRect(bounds, options.style.row, .fill, menu_item_radius, 0.0);
    try renderControlText(scene, bounds, menu_item_padding, menu_item_text_h, label, options.style.text, .start);
}

fn renderControlFrame(scene: *ui.Scene, bounds: ui.Rect, fill: ui.Color, border: ui.Color, radius: f32) ui.RenderError!void {
    try scene.pushRect(bounds, fill, .fill, radius, 0.0);
    try scene.pushRect(bounds, border, .border, radius, 0.0);
}

fn renderControlText(scene: *ui.Scene, bounds: ui.Rect, padding: f32, height: f32, value: []const u8, color: ui.Color, alignment: ui.TextAlign) ui.RenderError!void {
    const clamped = @min(@max(padding, 0.0), @min(bounds.w, bounds.h) * 0.5);
    const text_bounds = bounds.insetUniform(clamped);
    if (text_bounds.valid()) try scene.pushAlignedText(text_bounds.withHeightCentered(height), value, color, alignment);
}

fn measureFixed(preferred: ui.Size, constraints: layout.Constraints) layout.Measurement {
    const resolved_preferred = constrainPreferredSize(preferred, constraints);
    return layout.Measurement.flexible(
        .{ .w = @min(preferred.w, resolved_preferred.w), .h = @min(preferred.h, resolved_preferred.h) },
        resolved_preferred,
        .{ .w = measure_max_width, .h = preferred.h },
    ).applyExact(constraints);
}

fn constrainPreferredSize(preferred: ui.Size, constraints: layout.Constraints) ui.Size {
    return .{
        .w = constraints.width.limit(preferred.w),
        .h = constraints.height.limit(preferred.h),
    };
}

const min_extent: f32 = 1.0;
const measure_max_width: f32 = 4096.0;
const control_radius: f32 = tokens.Component.control_radius;
const control_label_height: f32 = tokens.Component.control_label_height;
const dropdown_menu_trigger = "Open";
const menu_trigger_y: f32 = 4.0;
const menu_trigger_w: f32 = 64.0;
const menu_trigger_h: f32 = 30.0;
const menu_gap: f32 = 8.0;
const menu_radius: f32 = 8.0;
const menu_padding: f32 = 5.0;
const menu_item_h: f32 = 14.0;
const menu_item_pitch: f32 = 16.0;
const menu_item_radius: f32 = 4.0;
const menu_item_padding: f32 = 5.0;
const menu_item_text_h: f32 = 12.0;
const menu_trigger_padding: f32 = 8.0;
const preferred_dropdown_menu = ui.Size{ .w = 240.0, .h = 52.0 };

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
