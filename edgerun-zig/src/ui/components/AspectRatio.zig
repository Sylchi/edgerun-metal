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

pub const AspectRatio = struct {
    ratio_w: u16 = 16,
    ratio_h: u16 = 9,

    pub fn node(self: AspectRatio) ui.Node {
        return ui.aspectRatioNode(self.ratio_w, self.ratio_h);
    }

    pub fn render(self: AspectRatio, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderAspectRatio(scene, bounds, self.ratio_w, self.ratio_h, options);
    }

    pub fn measure(self: AspectRatio, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_aspect_ratio, constraints);
    }

    pub fn toObject(self: AspectRatio, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.refObject(.aspect_ratio, 0, .{ .offset = self.ratio_w, .len = self.ratio_h }, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: AspectRatio, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.refRecord(writer, index, .aspect_ratio, 0, .{ .offset = self.ratio_w, .len = self.ratio_h });
    }

    pub fn fromView(view: object.View) Error!AspectRatio {
        return switch (try component_codec.singleNode(view)) {
            .aspect_ratio => |aspect_ratio| .{ .ratio_w = aspect_ratio.ratio_w, .ratio_h = aspect_ratio.ratio_h },
            else => error.UnsupportedComponent,
        };
    }
};

test "aspect ratio component serializes to canonical object and deserializes" {
    const ratio = AspectRatio{ .ratio_w = 16, .ratio_h = 9 };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = ratio.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try AspectRatio.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(@as(u16, 16), decoded.ratio_w);
    try std.testing.expectEqual(@as(u16, 9), decoded.ratio_h);
}

test "aspect ratio component keeps frame inside bounds" {
    const ratio = AspectRatio{ .ratio_w = 16, .ratio_h = 9 };
    var commands: [4]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try ratio.render(&scene, ui.Rect.init(0, 0, 160, 160), .{});

    const frame = component_test.lastFillRect(scene.written()).?;
    try std.testing.expectEqual(@as(f32, 160.0), frame.w);
    try std.testing.expect(frame.h < frame.w);
}
