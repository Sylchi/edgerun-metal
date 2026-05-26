const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;
const constrainPreferredSize = component_primitives.constrainPreferredSize;

pub const Label = struct {
    value: []const u8,

    pub fn node(self: Label) ui.Node {
        return ui.labelNode(self.value);
    }

    pub fn render(self: Label, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const text_h = @min(bounds.h, component_primitives.measuredTextHeight(self.value, bounds.w, label_height, label_max_lines));
        try scene.pushWrappedText(bounds.withHeightCentered(text_h), self.value, options.style.text, component_primitives.textWrap(self.value, label_height, label_max_lines));
    }

    pub fn measure(self: Label, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        const measured = layout.measureText(self.value, constraints, component_primitives.textMetrics(self.value, label_height, label_max_lines));
        const preferred = constrainPreferredSize(measured.preferred, constraints);
        return layout.Measurement.flexible(
            .{ .w = @min(label_min_width, preferred.w), .h = @min(label_height, preferred.h) },
            preferred,
            measured.max,
        ).applyExact(constraints);
    }

    pub fn toObject(self: Label, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.oneStringObject(.label, 0, self.value, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Label, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.oneStringRecord(writer, index, .label, 0, self.value);
    }

    pub fn fromView(view: object.View) Error!Label {
        const label = try component_codec.nodeView(view, .label);
        return .{ .value = label.value };
    }
};

const label_height: f32 = 16.0;
const label_min_width: f32 = 24.0;
const label_max_lines: usize = 2;
pub const preferred_label = ui.Size{ .w = 96.0, .h = 16.0 };

test "label component serializes to canonical object and deserializes" {
    const label = Label{ .value = "Email" };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = label.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Label.fromView(try object.View.decode(canonical));

    try std.testing.expectEqualStrings(label.value, decoded.value);
}

test "label component renders its own text slot" {
    const label = Label{ .value = "Email" };
    var commands: [4]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try label.render(&scene, ui.Rect.init(0, 0, 96, 24), .{});

    const text_command = component_test.textCommand(scene.written(), "Email").?;
    try std.testing.expectEqual(ui.Color.text, text_command.text.color);
    try std.testing.expectEqual(@as(f32, 4.0), text_command.text.origin.y);
}

test "label measurement wraps long values under narrow constraints" {
    const label = Label{ .value = "Runtime authority label" };

    const measured = label.measure(.{ .width = .{ .at_most = preferred_label.w * 0.5 }, .text_wrap = .wrap }, .{});

    try std.testing.expect(measured.preferred.w <= preferred_label.w * 0.5);
    try std.testing.expect(measured.preferred.h > preferred_label.h);
}
