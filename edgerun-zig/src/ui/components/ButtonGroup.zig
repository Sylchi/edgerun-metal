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

pub const ButtonGroup = struct {
    id: u32,
    first: []const u8,
    second: []const u8,
    active: u16 = 0,

    pub fn node(self: ButtonGroup) ui.Node {
        return ui.buttonGroupNode(self.id, self.first, self.second, activeIndex(self.active));
    }

    pub fn render(self: ButtonGroup, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        try renderSegment(scene, segmentBounds(bounds, 0), self.first, activeIndex(self.active) == 0, options);
        try renderSegment(scene, segmentBounds(bounds, 1), self.second, activeIndex(self.active) == 1, options);
    }

    pub fn collectInteractions(self: ButtonGroup, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(segmentBounds(bounds, 0), .button, self.id);
        try collector.addHit(segmentBounds(bounds, 1), .button, self.id + 1);
    }

    pub fn measure(self: ButtonGroup, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_button_group, constraints);
    }

    pub fn toObject(self: ButtonGroup, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        var writer = component_codec.Writer.init(ui_out, 1, 1, .column, 0, 0) orelse return null;
        if (!self.writeRecord(&writer, 0)) return null;
        return writer.objectNode(object_out, component_codec.requirements(), epoch);
    }

    pub fn writeRecord(self: ButtonGroup, writer: *component_codec.Writer, index: usize) bool {
        const first_ref = writer.string(self.first) orelse return false;
        const second_ref = writer.string(self.second) orelse return false;
        return writer.record(index, .button_group, encodedId(self.id, self.active), first_ref, second_ref);
    }

    pub fn fromView(view: object.View) Error!ButtonGroup {
        return switch (try component_codec.singleNode(view)) {
            .button_group => |group| .{ .id = group.id, .first = group.first, .second = group.second, .active = activeIndex(group.active) },
            else => error.UnsupportedComponent,
        };
    }
};

fn activeIndex(value: u16) u16 {
    return @min(value, 1);
}

fn encodedId(id: u32, active: u16) u32 {
    return id * group_id_stride + activeIndex(active);
}

const group_id_stride: u32 = 2;

fn renderSegment(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, active: bool, options: RenderOptions) ui.RenderError!void {
    try component_primitives.renderTextCell(scene, bounds, label, if (active) options.style.text else options.style.panel, options.style.border, 0.0, toggle_text_padding, if (active) options.style.panel else options.style.text);
}

fn segmentBounds(bounds: ui.Rect, index: usize) ui.Rect {
    const segment_w = @max(component_primitives.min_extent, bounds.w * 0.5);
    return ui.Rect.init(bounds.x + @as(f32, @floatFromInt(index)) * segment_w, bounds.y, segment_w, bounds.h);
}

const toggle_text_padding: f32 = 8.0;
pub const preferred_button_group = ui.Size{ .w = 160.0, .h = 36.0 };

test "button group component serializes to canonical object and deserializes" {
    const group = ButtonGroup{ .id = 90, .first = "Left", .second = "Right", .active = 1 };
    var ui_raw: [160]u8 = undefined;
    var object_raw: [object.header_size + 160]u8 = undefined;

    const canonical = group.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try ButtonGroup.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(group.id, decoded.id);
    try std.testing.expectEqualStrings(group.first, decoded.first);
    try std.testing.expectEqualStrings(group.second, decoded.second);
    try std.testing.expectEqual(@as(u16, 1), decoded.active);
}

test "button group component renders segments and hit regions" {
    const group = ButtonGroup{ .id = 90, .first = "Left", .second = "Right", .active = 1 };
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try group.render(&scene, ui.Rect.init(0, 0, 160, 36), .{});
    try group.collectInteractions(&collector, ui.Rect.init(0, 0, 160, 36));

    try std.testing.expect(component_test.hasText(scene.written(), "Left"));
    try std.testing.expect(component_test.hasText(scene.written(), "Right"));
    try std.testing.expectEqual(@as(u32, 91), collector.written()[1].id);
}
