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
const component_primitives = @import("Primitives.zig");
const list_layout = @import("ListLayout.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

const contentInset = component_primitives.contentInset;
const measureFixed = component_primitives.measureFixed;
const Icon = icon_component.Icon;

pub const Direction = struct {
    id: u32,
    active: u16,

    pub fn node(self: Direction) ui.Node {
        return ui.directionNode(self.id, self.active);
    }

    pub fn render(self: Direction, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const active = activeIndex(self.active);
        try renderItem(scene, itemBounds(bounds, 0), direction_ltr_label, active == 0, options);
        try Icon.named(.route).renderColor(scene, iconBounds(bounds), options.style.muted);
        try renderItem(scene, itemBounds(bounds, 1), direction_rtl_label, active == 1, options);
    }

    pub fn collectInteractions(self: Direction, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(itemBounds(bounds, 0), .button, self.id);
        try collector.addHit(itemBounds(bounds, 1), .button, self.id + 1);
    }

    pub fn measure(self: Direction, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_direction, constraints);
    }

    pub fn toObject(self: Direction, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        var writer = component_codec.Writer.init(ui_out, 1, 1, .column, 0, 0) orelse return null;
        if (!self.writeRecord(&writer, 0)) return null;
        return writer.objectNode(object_out, component_codec.requirements(), epoch);
    }

    pub fn writeRecord(self: Direction, writer: *component_codec.Writer, index: usize) bool {
        return writer.record(index, .direction, list_layout.encodedIndexedId(self.id, self.active, direction_item_count), .{}, .{});
    }

    pub fn fromView(view: object.View) Error!Direction {
        const direction = try component_codec.nodeView(view, .direction);
        return fromNode(direction);
    }

    pub fn fromNode(direction: @FieldType(ui.Node, "direction")) Error!Direction {
        return .{ .id = direction.id, .active = direction.active };
    }
};

fn activeIndex(value: u16) u16 {
    return list_layout.clampedIndex(value, direction_item_count);
}

fn renderItem(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, active: bool, options: RenderOptions) ui.RenderError!void {
    try scene.pushRect(bounds, if (active) options.style.accent else options.style.row, .fill, direction_item_radius, 0.0);
    try scene.pushRect(bounds, options.style.border, .border, direction_item_radius, 0.0);
    const text_color = if (active) options.style.bg else options.style.text;
    if (contentInset(bounds, direction_item_padding)) |inner| {
        try text_component.Text.renderAligned(scene, inner.withHeightCentered(direction_item_text_h), label, text_color, .center);
    }
}

fn itemBounds(bounds: ui.Rect, index: usize) ui.Rect {
    return switch (index) {
        0 => ui.Rect.init(bounds.x, bounds.y + direction_item_y, direction_item_w, direction_item_h),
        else => ui.Rect.init(bounds.x + direction_second_x, bounds.y + direction_item_y, direction_item_w, direction_item_h),
    };
}

fn iconBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x + direction_icon_x, bounds.y + direction_icon_y, direction_icon_size, direction_icon_size);
}

pub const direction_item_count: u16 = 2;
const direction_ltr_label = "LTR";
const direction_rtl_label = "RTL";
const direction_item_y: f32 = 8.0;
const direction_item_w: f32 = 42.0;
const direction_item_h: f32 = 20.0;
const direction_item_radius: f32 = 6.0;
const direction_item_padding: f32 = 5.0;
const direction_item_text_h: f32 = 12.0;
const direction_icon_x: f32 = 54.0;
const direction_icon_y: f32 = 11.0;
const direction_icon_size: f32 = 18.0;
const direction_second_x: f32 = 84.0;
pub const preferred_direction = ui.Size{ .w = 150.0, .h = 36.0 };

test "direction component serializes to canonical object and deserializes" {
    const direction = Direction{ .id = 1004, .active = 1 };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = direction.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Direction.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(direction.id, decoded.id);
    try std.testing.expectEqual(direction.active, decoded.active);
}

test "direction component renders choices and hit regions" {
    const direction = Direction{ .id = 1004, .active = 1 };
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try direction.render(&scene, ui.Rect.init(0, 0, 150, 36), .{});
    try direction.collectInteractions(&collector, ui.Rect.init(0, 0, 150, 36));

    try std.testing.expect(component_test.hasText(scene.written(), "LTR"));
    try std.testing.expect(component_test.hasText(scene.written(), "RTL"));
    try std.testing.expectEqual(@as(usize, 2), collector.written().len);
    try std.testing.expectEqual(@as(u32, 1005), collector.written()[1].id);
}
