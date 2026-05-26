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

pub const Separator = struct {
    pub fn node(self: Separator) ui.Node {
        _ = self;
        return ui.separatorNode();
    }

    pub fn render(self: Separator, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        _ = self;
        const line = ui.Rect.init(bounds.x, bounds.y + (bounds.h - separator_height) * 0.5, bounds.w, separator_height);
        try scene.pushRect(line, options.style.border, .fill, 0.0, 0.0);
    }

    pub fn measure(self: Separator, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_separator, constraints);
    }

    pub fn toObject(self: Separator, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        _ = self;
        return component_codec.emptyObject(.separator, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Separator, writer: *component_codec.Writer, index: usize) bool {
        _ = self;
        return component_codec.emptyRecord(writer, index, .separator);
    }

    pub fn fromView(view: object.View) Error!Separator {
        return switch (try component_codec.singleNode(view)) {
            .separator => .{},
            else => error.UnsupportedComponent,
        };
    }
};

const separator_height: f32 = 1.0;
pub const preferred_separator = ui.Size{ .w = 220.0, .h = 1.0 };

test "separator component serializes to canonical object and deserializes" {
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = (Separator{}).toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    _ = try Separator.fromView(try object.View.decode(canonical));
}

test "separator component renders centered border line" {
    var commands: [4]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    const border = ui.Color{ .r = 9, .g = 8, .b = 7 };

    try (Separator{}).render(&scene, ui.Rect.init(4, 10, 120, 9), .{ .style = .{ .border = border } });

    const line = component_test.fillRectColor(scene.written(), border).?;
    try std.testing.expectEqual(ui.Rect.init(4, 14, 120, 1), line);
}
