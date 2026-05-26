const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;
const measureFixed = component_primitives.measureFixed;

pub const Toggle = struct {
    id: u32,
    label: []const u8,
    pressed: bool = false,

    pub fn node(self: Toggle) ui.Node {
        return ui.toggleNode(self.id, self.label, self.pressed);
    }

    pub fn render(self: Toggle, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const fill = if (self.pressed) options.style.row else ui.Color.clear;
        const text_color = if (self.pressed) options.style.text else options.style.muted;
        try component_primitives.renderTextCell(scene, bounds, self.label, fill, if (self.pressed) options.style.border else ui.Color.clear, component_primitives.control_radius, toggle_text_padding, text_color);
    }

    pub fn collectInteractions(self: Toggle, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return common.collectHit(collector, bounds, .button, self.id);
    }

    pub fn measure(self: Toggle, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_toggle, constraints);
    }

    pub fn toObject(self: Toggle, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.stringAndRefObject(.toggle, self.id, self.label, component_codec.boolRef(self.pressed), ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Toggle, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.stringAndRefRecord(writer, index, .toggle, self.id, self.label, component_codec.boolRef(self.pressed));
    }

    pub fn fromView(view: object.View) Error!Toggle {
        return switch (try component_codec.singleNode(view)) {
            .toggle => |toggle| .{ .id = toggle.id, .label = toggle.label, .pressed = toggle.pressed },
            else => error.UnsupportedComponent,
        };
    }
};

const toggle_text_padding: f32 = 8.0;
pub const preferred_toggle = ui.Size{ .w = 96.0, .h = 36.0 };

test "toggle component serializes to canonical object and deserializes" {
    const toggle = Toggle{ .id = 44, .label = "Bold", .pressed = true };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = toggle.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Toggle.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(toggle.id, decoded.id);
    try std.testing.expectEqualStrings(toggle.label, decoded.label);
    try std.testing.expect(decoded.pressed);
}

test "toggle component renders pressed state and collects button hit" {
    const toggle = Toggle{ .id = 44, .label = "Bold", .pressed = true };
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [1]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try toggle.render(&scene, ui.Rect.init(0, 0, 96, 36), .{});
    try toggle.collectInteractions(&collector, ui.Rect.init(0, 0, 96, 36));

    try std.testing.expect(component_test.hasFillColor(scene.written(), ui.Color.row));
    try std.testing.expectEqual(@as(u32, 44), collector.written()[0].id);
}
