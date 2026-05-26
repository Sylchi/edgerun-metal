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

pub const Spinner = struct {
    pub fn node(self: Spinner) ui.Node {
        _ = self;
        return ui.spinnerNode();
    }

    pub fn render(self: Spinner, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        _ = self;
        const size = @min(spinner_size, @max(component_primitives.min_extent, @min(bounds.w, bounds.h)));
        const spinner = ui.Rect.init(bounds.x + (bounds.w - size) * 0.5, bounds.y + (bounds.h - size) * 0.5, size, size);
        try scene.pushRect(spinner, options.style.border, .border, size * 0.5, 0.0);
        try scene.pushPieSlice(spinner.insetUniform(spinner_slice_inset), options.style.accent, spinner_start_turn, spinner_end_turn);
    }

    pub fn measure(self: Spinner, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_spinner, constraints);
    }

    pub fn toObject(self: Spinner, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        _ = self;
        return component_codec.emptyObject(.spinner, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Spinner, writer: *component_codec.Writer, index: usize) bool {
        _ = self;
        return component_codec.emptyRecord(writer, index, .spinner);
    }

    pub fn fromView(view: object.View) Error!Spinner {
        _ = try component_codec.nodeView(view, .spinner);
        return .{};
    }
};

const spinner_size: f32 = 28.0;
const spinner_slice_inset: f32 = 3.0;
const spinner_start_turn: f32 = 0.08;
const spinner_end_turn: f32 = 0.78;
pub const preferred_spinner = ui.Size{ .w = 32.0, .h = 32.0 };

test "spinner component serializes to canonical object and deserializes" {
    const spinner = Spinner{};
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = spinner.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    _ = try Spinner.fromView(try object.View.decode(canonical));
}

test "spinner component renders deterministic status mark" {
    const spinner = Spinner{};
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try spinner.render(&scene, ui.Rect.init(0, 0, 32, 32), .{});

    try std.testing.expectEqual(@as(usize, 2), scene.written().len);
    try std.testing.expectEqual(ui.RectMode.border, scene.written()[0].rect.mode);
    try std.testing.expectEqual(ui.RectMode.pie_slice, scene.written()[1].rect.mode);
}
