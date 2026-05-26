const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;
const measureFixed = component_primitives.measureFixed;

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
        _ = self;
        _ = options;
        return measureFixed(preferred_radio_group, constraints);
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
        return switch (try component_codec.singleNode(view)) {
            .radio_group => |radio| .{ .id = radio.id, .first = radio.first, .second = radio.second, .selected = selectedIndex(radio.selected) },
            else => error.UnsupportedComponent,
        };
    }
};

fn selectedIndex(value: u16) u16 {
    return @min(value, 1);
}

fn encodedId(id: u32, selected: u16) u32 {
    return id * radio_id_stride + selectedIndex(selected);
}

const radio_id_stride: u32 = 2;

fn renderOption(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, selected: bool, options: RenderOptions) ui.RenderError!void {
    const outer = ui.Rect.init(bounds.x, bounds.y + (bounds.h - radio_box_size) * 0.5, radio_box_size, radio_box_size);
    try scene.pushRect(outer, options.style.panel, .fill, radio_box_size * 0.5, 0.0);
    try scene.pushRect(outer, options.style.border, .border, radio_box_size * 0.5, 0.0);
    if (selected) {
        const dot = ui.Rect.init(outer.x + (outer.w - radio_dot_size) * 0.5, outer.y + (outer.h - radio_dot_size) * 0.5, radio_dot_size, radio_dot_size);
        try scene.pushRect(dot, options.style.accent, .fill, radio_dot_size * 0.5, 0.0);
    }
    const label_x = outer.x + outer.w + radio_text_gap;
    try scene.pushText(ui.Rect.init(label_x, bounds.y, @max(component_primitives.min_extent, bounds.x + bounds.w - label_x), bounds.h).withHeightCentered(component_primitives.control_label_height), label, options.style.text);
}

fn optionBounds(bounds: ui.Rect, index: usize) ui.Rect {
    const y = bounds.y + @as(f32, @floatFromInt(index)) * radio_option_pitch;
    return ui.Rect.init(bounds.x, y, bounds.w, radio_option_h);
}

const radio_box_size: f32 = 18.0;
const radio_text_gap: f32 = 10.0;
const radio_dot_size: f32 = 8.0;
const radio_option_h: f32 = 20.0;
const radio_option_pitch: f32 = 26.0;
pub const preferred_radio_group = ui.Size{ .w = 220.0, .h = 52.0 };

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
