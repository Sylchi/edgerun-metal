const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_render = @import("Render.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const Text = struct {
    value: []const u8,

    pub fn node(self: Text) ui.Node {
        return .{ .text = .{ .value = self.value } };
    }

    pub fn render(self: Text, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderText(scene, bounds, self.value, options);
    }

    pub fn measure(self: Text, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return component_render.measureText(self.value, constraints);
    }

    pub fn toObject(self: Text, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.oneStringObject(.text, 0, self.value, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Text, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.oneStringRecord(writer, index, .text, 0, self.value);
    }

    pub fn fromView(view: object.View) Error!Text {
        return switch (try component_codec.singleNode(view)) {
            .text => |text| .{ .value = text.value },
            else => error.UnsupportedComponent,
        };
    }
};

test "text component serializes to canonical object and deserializes" {
    const text = Text{ .value = "DNS asks, resolver answers." };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = text.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Text.fromView(try object.View.decode(canonical));

    try std.testing.expectEqualStrings(text.value, decoded.value);
}

test "text component renders through shared text renderer" {
    const text = Text{ .value = "DNS asks" };
    var commands: [4]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    const color = ui.Color{ .r = 2, .g = 4, .b = 6 };

    try text.render(&scene, ui.Rect.init(10, 20, 90, 18), .{ .style = .{ .text = color } });

    const command = component_test.textCommand(scene.written(), "DNS asks").?;
    try std.testing.expectEqual(color, command.text.color);
    try std.testing.expectEqual(ui.Rect.init(10, 20, 90, 18), command.text.origin);
}

test "text component measurement respects at-most height" {
    const text = Text{ .value = "DNS asks, resolver answers." };
    const measured = text.measure(.{ .height = .{ .at_most = 10.0 } }, .{});

    try std.testing.expectEqual(@as(f32, 10.0), measured.preferred.h);
}
