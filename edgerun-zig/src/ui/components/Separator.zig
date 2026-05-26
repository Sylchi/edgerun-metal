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

pub const Separator = struct {
    pub fn node(self: Separator) ui.Node {
        _ = self;
        return ui.separatorNode();
    }

    pub fn render(self: Separator, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        _ = self;
        return component_render.renderSeparator(scene, bounds, options);
    }

    pub fn measure(self: Separator, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_separator, constraints);
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
