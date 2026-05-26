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

pub const RadioGroup = struct {
    id: u32,
    first: []const u8,
    second: []const u8,
    selected: u16 = 0,

    pub fn node(self: RadioGroup) ui.Node {
        return ui.radioGroupNode(self.id, self.first, self.second, selectedIndex(self.selected));
    }

    pub fn render(self: RadioGroup, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const selected = selectedIndex(self.selected);
        try renderOption(scene, optionBounds(bounds, 0), self.first, selected == 0, options);
        try renderOption(scene, optionBounds(bounds, 1), self.second, selected == 1, options);
    }

    pub fn collectInteractions(self: RadioGroup, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(optionBounds(bounds, 0), .button, self.id);
        try collector.addHit(optionBounds(bounds, 1), .button, self.id + 1);
    }

    pub fn measure(self: RadioGroup, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        const first = labelMeasure(self.first);
        const second = labelMeasure(self.second);
        const option_h = optionHeight();
        const preferred = component_primitives.constrainPreferredSize(.{
            .w = radio_box_size + radio_text_gap + @max(first.preferred.w, second.preferred.w),
            .h = option_h * @as(f32, @floatFromInt(radio_item_count)) + radio_option_gap * @as(f32, @floatFromInt(radio_item_count - 1)),
        }, constraints);
        return layout.Measurement.flexible(
            .{ .w = radio_box_size + radio_text_gap + component_primitives.min_extent, .h = option_h },
            preferred,
            .{ .w = component_primitives.maxMeasuredWidth(constraints, preferred.w), .h = preferred.h },
        ).applyExact(constraints);
    }

    pub fn toObject(self: RadioGroup, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        var writer = component_codec.Writer.init(ui_out, 1, 1, .column, 0, 0) orelse return null;
        if (!self.writeRecord(&writer, 0)) return null;
        return writer.objectNode(object_out, component_codec.requirements(), epoch);
    }

    pub fn writeRecord(self: RadioGroup, writer: *component_codec.Writer, index: usize) bool {
        const first_ref = writer.string(self.first) orelse return false;
        const second_ref = writer.string(self.second) orelse return false;
        return writer.record(index, .radio_group, encodedId(self.id, self.selected), first_ref, second_ref);
    }

    pub fn fromView(view: object.View) Error!RadioGroup {
        const radio = try component_codec.nodeView(view, .radio_group);
        return fromNode(radio);
    }

    pub fn fromNode(radio: @FieldType(ui.Node, "radio_group")) Error!RadioGroup {
        return .{ .id = radio.id, .first = radio.first, .second = radio.second, .selected = selectedIndex(radio.selected) };
    }
};

fn selectedIndex(value: u16) u16 {
    return list_layout.clampedIndex(value, radio_item_count);
}

fn encodedId(id: u32, selected: u16) u32 {
    return list_layout.encodedIndexedId(id, selected, radio_item_count);
}

const radio_item_count: u16 = 2;

fn renderOption(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, selected: bool, options: RenderOptions) ui.RenderError!void {
    const outer = ui.Rect.init(bounds.x, bounds.y + (bounds.h - radio_box_size) * 0.5, radio_box_size, radio_box_size);
    try scene.pushRect(outer, options.style.panel, .fill, radio_box_size * 0.5, 0.0);
    try scene.pushRect(outer, options.style.border, .border, radio_box_size * 0.5, 0.0);
    if (selected) {
        const dot = ui.Rect.init(outer.x + (outer.w - radio_dot_size) * 0.5, outer.y + (outer.h - radio_dot_size) * 0.5, radio_dot_size, radio_dot_size);
        try scene.pushRect(dot, options.style.accent, .fill, radio_dot_size * 0.5, 0.0);
    }
    const label_x = outer.x + outer.w + radio_text_gap;
    try text_component.Text.renderPlain(scene, ui.Rect.init(label_x, bounds.y, @max(component_primitives.min_extent, bounds.x + bounds.w - label_x), bounds.h).withHeightCentered(component_primitives.control_label_height), label, options.style.text);
}

fn optionBounds(bounds: ui.Rect, index: usize) ui.Rect {
    const option_h = optionHeight();
    const y = bounds.y + @as(f32, @floatFromInt(index)) * (option_h + radio_option_gap);
    return ui.Rect.init(bounds.x, y, bounds.w, option_h);
}

fn optionHeight() f32 {
    return @max(radio_box_size, component_primitives.control_label_height);
}

fn labelMeasure(value: []const u8) layout.Measurement {
    return text_component.Text.measureValue(value, .{ .width = .unconstrained, .text_wrap = .nowrap }, component_primitives.textMetrics(value, component_primitives.control_label_height, radio_label_max_lines));
}

const radio_box_size: f32 = 18.0;
const radio_text_gap: f32 = 10.0;
const radio_dot_size: f32 = 8.0;
const radio_option_gap: f32 = 6.0;
const radio_label_max_lines: usize = 1;

test "radio group component serializes to canonical object and deserializes" {
    const radio = RadioGroup{ .id = 70, .first = "Default", .second = "Comfortable", .selected = 1 };
    var ui_raw: [160]u8 = undefined;
    var object_raw: [object.header_size + 160]u8 = undefined;

    const canonical = radio.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try RadioGroup.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(radio.id, decoded.id);
    try std.testing.expectEqualStrings(radio.first, decoded.first);
    try std.testing.expectEqualStrings(radio.second, decoded.second);
    try std.testing.expectEqual(@as(u16, 1), decoded.selected);
}

test "radio group component renders selected indicator and option hits" {
    const radio = RadioGroup{ .id = 70, .first = "Default", .second = "Comfortable", .selected = 1 };
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try radio.render(&scene, ui.Rect.init(0, 0, 220, 52), .{});
    try radio.collectInteractions(&collector, ui.Rect.init(0, 0, 220, 52));

    try std.testing.expect(component_test.hasFillColor(scene.written(), ui.Color.accent));
    try std.testing.expectEqual(@as(usize, 2), collector.written().len);
    try std.testing.expectEqual(@as(u32, 71), collector.written()[1].id);
}

test "radio group measurement follows option labels" {
    const short = RadioGroup{ .id = 70, .first = "A", .second = "B", .selected = 0 };
    const long = RadioGroup{ .id = 70, .first = "Default", .second = "Comfortable runtime mode", .selected = 1 };

    try std.testing.expect(long.measure(.{}, .{}).preferred.w > short.measure(.{}, .{}).preferred.w);
}
