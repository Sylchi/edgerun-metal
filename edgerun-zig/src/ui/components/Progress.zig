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

pub const Progress = struct {
    value: f32,

    pub fn node(self: Progress) ui.Node {
        return ui.progressNode(self.value);
    }

    pub fn render(self: Progress, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderProgress(scene, bounds, self.value, options);
    }

    pub fn measure(self: Progress, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_progress, constraints);
    }

    pub fn toObject(self: Progress, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.refObject(.progress, 0, component_codec.unitRef(self.value), ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Progress, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.refRecord(writer, index, .progress, 0, component_codec.unitRef(self.value));
    }

    pub fn fromView(view: object.View) Error!Progress {
        return switch (try component_codec.singleNode(view)) {
            .progress => |progress| .{ .value = progress.value },
            else => error.UnsupportedComponent,
        };
    }
};

test "progress component serializes to canonical object and deserializes" {
    const progress = Progress{ .value = 0.64 };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = progress.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Progress.fromView(try object.View.decode(canonical));

    try std.testing.expect(@abs(decoded.value - progress.value) < 0.001);
}

test "progress component clamps rendered fill to track" {
    const progress = Progress{ .value = 2.0 };
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    const bounds = ui.Rect.init(0, 0, 120, 10);

    try progress.render(&scene, bounds, .{});

    const fill = component_test.fillRectColor(scene.written(), ui.Color.accent).?;
    try std.testing.expectEqual(@as(f32, 120.0), fill.w);
    try std.testing.expect(fill.x + fill.w <= bounds.x + bounds.w);
}
