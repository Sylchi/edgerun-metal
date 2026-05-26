const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const tokens = @import("../../ui_tokens.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

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
    try scene.pushRect(bounds, if (active) options.style.text else options.style.panel, .fill, 0.0, 0.0);
    try scene.pushRect(bounds, options.style.border, .border, 0.0, 0.0);
    const text_color = if (active) options.style.panel else options.style.text;
    if (contentInset(bounds, toggle_text_padding)) |text_bounds| {
        try scene.pushAlignedText(text_bounds.withHeightCentered(control_label_height), label, text_color, .center);
    }
}

fn segmentBounds(bounds: ui.Rect, index: usize) ui.Rect {
    const segment_w = @max(min_extent, bounds.w * 0.5);
    return ui.Rect.init(bounds.x + @as(f32, @floatFromInt(index)) * segment_w, bounds.y, segment_w, bounds.h);
}

fn contentInset(bounds: ui.Rect, padding: f32) ?ui.Rect {
    const clamped = @min(@max(padding, 0.0), @min(bounds.w, bounds.h) * 0.5);
    const out = bounds.insetUniform(clamped);
    return if (out.valid()) out else null;
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
const control_label_height: f32 = tokens.Component.control_label_height;
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
