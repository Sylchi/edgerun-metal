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
const measureFixed = component_primitives.measureFixed;

pub const AspectRatio = struct {
    ratio_w: u16 = 16,
    ratio_h: u16 = 9,

    pub fn node(self: AspectRatio) ui.Node {
        return ui.aspectRatioNode(self.ratio_w, self.ratio_h);
    }

    pub fn render(self: AspectRatio, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const frame = frameBounds(bounds, self.ratio_w, self.ratio_h);
        try scene.pushRect(frame, options.style.row, .fill, component_primitives.control_radius, 0.0);
        try scene.pushRect(frame, options.style.border, .border, component_primitives.control_radius, 0.0);
    }

    pub fn measure(self: AspectRatio, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_aspect_ratio, constraints);
    }

    pub fn toObject(self: AspectRatio, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.refObject(.aspect_ratio, 0, .{ .offset = self.ratio_w, .len = self.ratio_h }, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: AspectRatio, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.refRecord(writer, index, .aspect_ratio, 0, .{ .offset = self.ratio_w, .len = self.ratio_h });
    }

    pub fn fromView(view: object.View) Error!AspectRatio {
        const aspect_ratio = try component_codec.nodeView(view, .aspect_ratio);
        return .{ .ratio_w = aspect_ratio.ratio_w, .ratio_h = aspect_ratio.ratio_h };
    }
};

fn frameBounds(bounds: ui.Rect, ratio_w: u16, ratio_h: u16) ui.Rect {
    const safe_w = @max(@as(f32, @floatFromInt(ratio_w)), component_primitives.min_extent);
    const safe_h = @max(@as(f32, @floatFromInt(ratio_h)), component_primitives.min_extent);
    const frame_w = @min(bounds.w, bounds.h * safe_w / safe_h);
    const frame_h = @min(bounds.h, frame_w * safe_h / safe_w);
    return ui.Rect.init(bounds.x + (bounds.w - frame_w) * 0.5, bounds.y + (bounds.h - frame_h) * 0.5, frame_w, frame_h);
}

pub const preferred_aspect_ratio = ui.Size{ .w = 220.0, .h = 124.0 };

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
