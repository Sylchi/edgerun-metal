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
const contentInset = component_primitives.contentInset;
const measureFixed = component_primitives.measureFixed;

pub const Kbd = struct {
    label: []const u8,

    pub fn node(self: Kbd) ui.Node {
        return ui.kbdNode(self.label);
    }

    pub fn render(self: Kbd, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const height = @min(kbd_height, @max(component_primitives.min_extent, bounds.h));
        const kbd_bounds = ui.Rect.init(bounds.x, bounds.y + (bounds.h - height) * 0.5, bounds.w, height);
        try scene.pushRect(kbd_bounds, options.style.row, .fill, component_primitives.control_radius, 0.0);
        try scene.pushRect(kbd_bounds, options.style.border, .border, component_primitives.control_radius, 0.0);
        if (contentInset(kbd_bounds, kbd_label_padding)) |text_bounds| {
            try scene.pushAlignedText(text_bounds.withHeightCentered(kbd_text_height), self.label, options.style.text, .center);
        }
    }

    pub fn measure(self: Kbd, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_kbd, constraints);
    }

    pub fn toObject(self: Kbd, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.oneStringObject(.kbd, 0, self.label, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Kbd, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.oneStringRecord(writer, index, .kbd, 0, self.label);
    }

    pub fn fromView(view: object.View) Error!Kbd {
        const kbd = try component_codec.nodeView(view, .kbd);
        return .{ .label = kbd.label };
    }
};

const kbd_height: f32 = 24.0;
const kbd_text_height: f32 = 12.0;
const kbd_label_padding: f32 = 8.0;
pub const preferred_kbd = ui.Size{ .w = 48.0, .h = 24.0 };

test "kbd component serializes to canonical object and deserializes" {
    const kbd = Kbd{ .label = "Ctrl-K" };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = kbd.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Kbd.fromView(try object.View.decode(canonical));

    try std.testing.expectEqualStrings("Ctrl-K", decoded.label);
}

test "kbd component centers label through shared control text" {
    const kbd = Kbd{ .label = "Ctrl" };
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try kbd.render(&scene, ui.Rect.init(10, 20, 48, 32), .{});

    const label = component_test.textCommand(scene.written(), "Ctrl").?;
    try std.testing.expectEqual(ui.TextAlign.center, label.text.alignment);
    try std.testing.expectEqual(@as(f32, 18.0), label.text.origin.x);
    try std.testing.expectEqual(@as(f32, 32.0), label.text.origin.y);
    try std.testing.expectEqual(@as(f32, 8.0), label.text.origin.h);
}
