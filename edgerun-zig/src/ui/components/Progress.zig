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

pub const Progress = struct {
    value: f32,

    pub fn node(self: Progress) ui.Node {
        return ui.progressNode(self.value);
    }

    pub fn render(self: Progress, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const track = ui.Rect.init(bounds.x, bounds.y + (bounds.h - progress_height) * 0.5, bounds.w, progress_height);
        try renderTrack(scene, track, self.value, options);
    }

    pub fn measure(self: Progress, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_progress, constraints);
    }

    pub fn toObject(self: Progress, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.refObject(.progress, 0, component_codec.unitRef(self.value), ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Progress, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.refRecord(writer, index, .progress, 0, component_codec.unitRef(self.value));
    }

    pub fn fromView(view: object.View) Error!Progress {
        const progress = try component_codec.nodeView(view, .progress);
        return .{ .value = progress.value };
    }
};

fn renderTrack(scene: *ui.Scene, track: ui.Rect, value: f32, options: RenderOptions) ui.RenderError!void {
    if (track.w <= 0.0 or track.h <= 0.0) return;
    try scene.pushRect(track, options.style.row, .fill, progress_height * 0.5, 0.0);
    const clamped = ui.clampUnit(value);
    const fill_width = @min(track.w, @max(0.0, track.w * clamped));
    try scene.pushRect(ui.Rect.init(track.x, track.y, fill_width, track.h), options.style.accent, .fill, progress_height * 0.5, 0.0);
}

const progress_height: f32 = 8.0;
pub const preferred_progress = ui.Size{ .w = 220.0, .h = 10.0 };

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
