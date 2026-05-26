const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const text_metrics = @import("../../ui_text_metrics.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

const constrainPreferredSize = component_primitives.constrainPreferredSize;

pub const Text = struct {
    value: []const u8,

    pub fn node(self: Text) ui.Node {
        return .{ .text = .{ .value = self.value } };
    }

    pub fn accessibility(self: Text) common.Accessibility {
        return .{ .role = .text, .label = self.value };
    }

    pub fn render(self: Text, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const line_height = @min(text_line_height, @max(component_primitives.min_extent, bounds.h));
        try renderWrapped(scene, bounds, self.value, options.style.text, .{
            .line_height = line_height,
            .average_char_width = text_metrics.averageWidth(self.value, line_height),
            .max_lines = text_max_lines,
        });
    }

    pub fn measure(self: Text, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return measureValue(self.value, constraints, .{
            .line_height = text_line_height,
            .average_char_width = text_metrics.averageWidth(self.value, text_line_height),
            .max_lines = text_max_lines,
        });
    }

    pub fn measureValue(value: []const u8, constraints: layout.Constraints, metrics: layout.TextMetrics) layout.Measurement {
        const measured = layout.measureText(value, constraints, metrics);
        const preferred = constrainPreferredSize(measured.preferred, constraints);
        return layout.Measurement.flexible(
            .{ .w = @min(text_min_width, preferred.w), .h = @min(metrics.line_height, preferred.h) },
            preferred,
            measured.max,
        ).applyExact(constraints);
    }

    pub fn toObject(self: Text, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.oneStringObject(.text, 0, self.value, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Text, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.oneStringRecord(writer, index, .text, 0, self.value);
    }

    pub fn fromView(view: object.View) Error!Text {
        const text = try component_codec.nodeView(view, .text);
        return fromNode(text);
    }

    pub fn fromNode(text: @FieldType(ui.Node, "text")) Error!Text {
        return .{ .value = text.value };
    }

    pub fn renderPlain(scene: *ui.Scene, bounds: ui.Rect, value: []const u8, color: ui.Color) ui.RenderError!void {
        try scene.pushText(bounds, value, color);
    }

    pub fn renderAligned(scene: *ui.Scene, bounds: ui.Rect, value: []const u8, color: ui.Color, alignment: ui.TextAlign) ui.RenderError!void {
        try scene.pushAlignedText(bounds, value, color, alignment);
    }

    pub fn renderWrapped(scene: *ui.Scene, bounds: ui.Rect, value: []const u8, color: ui.Color, wrap: ui.TextWrap) ui.RenderError!void {
        try scene.pushWrappedText(bounds, value, color, wrap);
    }
};

const text_line_height: f32 = 18.0;
const text_max_lines: usize = 8;
const text_min_width: f32 = 24.0;

test "text component serializes to canonical object and deserializes" {
    const text = Text{ .value = "DNS asks, resolver answers." };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = text.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Text.fromView(try object.View.decode(canonical));

    try std.testing.expectEqualStrings(text.value, decoded.value);
}

test "text component renders its own text commands" {
    const text = Text{ .value = "DNS asks" };
    var commands: [4]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    const color = ui.Color{ .r = 2, .g = 4, .b = 6 };

    try text.render(&scene, ui.Rect.init(10, 20, 90, 18), .{ .style = .{ .text = color } });

    const command = component_test.textCommand(scene.written(), "DNS asks").?;
    try std.testing.expectEqual(color, command.text.color);
    try std.testing.expectEqual(ui.Rect.init(10, 20, 90, 18), command.text.origin);
}

test "text component wraps instead of clipping narrow bounds" {
    const text = Text{ .value = "Secure app runtime text wraps" };
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try text.render(&scene, ui.Rect.init(0, 0, 72, 54), .{});

    try std.testing.expect(scene.written().len > 1);
    for (scene.written()) |command| {
        try std.testing.expect(command.text.origin.w <= 72.0);
    }
}

test "text component measurement respects at-most height" {
    const text = Text{ .value = "DNS asks, resolver answers." };
    const measured = text.measure(.{ .height = .{ .at_most = 10.0 } }, .{});

    try std.testing.expectEqual(@as(f32, 10.0), measured.preferred.h);
}
