const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../component_common.zig");
const text_component = @import("Text.zig");
const interaction = @import("../interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../core.zig");
const layout = @import("../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const Toggle = struct {
    id: u32,
    flags: common.ComponentFlags = .{},
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
        _ = options;
        const label = text_component.Text.measureValue(self.label, .{ .width = .unconstrained, .text_wrap = .nowrap }, component_primitives.textMetrics(self.label, component_primitives.control_label_height, toggle_label_max_lines));
        const preferred = component_primitives.constrainPreferredSize(.{
            .w = label.preferred.w + toggle_text_padding * 2.0,
            .h = label.preferred.h + toggle_text_padding * 2.0,
        }, constraints);
        return layout.Measurement.flexible(
            .{ .w = component_primitives.min_extent + toggle_text_padding * 2.0, .h = component_primitives.control_label_height + toggle_text_padding * 2.0 },
            preferred,
            .{ .w = component_primitives.maxMeasuredWidth(constraints, preferred.w), .h = preferred.h },
        ).applyExact(constraints);
    }

    pub fn toObject(self: Toggle, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.stringAndRefObject(.toggle, self.id, self.label, component_codec.boolRef(self.pressed), ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Toggle, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.stringAndRefRecord(writer, index, .toggle, self.id, self.label, component_codec.boolRef(self.pressed));
    }

    pub fn fromView(view: object.View) Error!Toggle {
        const toggle = try component_codec.nodeView(view, .toggle);
        return fromNode(toggle);
    }

    pub fn fromNode(toggle: @FieldType(ui.Node, "toggle")) Error!Toggle {
        return .{ .id = toggle.id, .label = toggle.label, .pressed = toggle.pressed };
    }
};

const toggle_text_padding: f32 = 8.0;
const toggle_label_max_lines: usize = 1;

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

test "toggle measurement follows label text" {
    const short = Toggle{ .id = 44, .label = "B", .pressed = true };
    const long = Toggle{ .id = 44, .label = "Runtime authority", .pressed = true };

    try std.testing.expect(long.measure(.{}, .{}).preferred.w > short.measure(.{}, .{}).preferred.w);
}
