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

pub const Spinner = struct {
    pub fn node(self: Spinner) ui.Node {
        _ = self;
        return ui.spinnerNode();
    }

    pub fn render(self: Spinner, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        _ = self;
        return component_render.renderSpinner(scene, bounds, options);
    }

    pub fn measure(self: Spinner, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_spinner, constraints);
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
        return switch (try component_codec.singleNode(view)) {
            .spinner => .{},
            else => error.UnsupportedComponent,
        };
    }
};

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
