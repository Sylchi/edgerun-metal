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

pub const Switch = struct {
    id: u32,
    label: []const u8,
    checked: bool,

    pub fn node(self: Switch) ui.Node {
        return ui.switchNode(self.id, self.label, self.checked);
    }

    pub fn render(self: Switch, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const pill = ui.Rect.init(bounds.x + bounds.w - switch_width, bounds.y + (bounds.h - switch_height) * 0.5, switch_width, switch_height);
        try scene.pushRect(pill, if (self.checked) options.style.accent else options.style.row, .fill, switch_height * 0.5, 0.0);
        try scene.pushRect(pill, options.style.border, .border, switch_height * 0.5, 0.0);
        const knob_x = if (self.checked) pill.x + pill.w - switch_knob_size - switch_knob_inset else pill.x + switch_knob_inset;
        const knob = ui.Rect.init(knob_x, pill.y + switch_knob_inset, switch_knob_size, switch_knob_size);
        try scene.pushRect(knob, options.style.panel, .fill, switch_knob_size * 0.5, 0.0);
        try scene.pushText(ui.Rect.init(bounds.x, bounds.y, @max(component_primitives.min_extent, pill.x - bounds.x - switch_label_gap), bounds.h).withHeightCentered(component_primitives.control_label_height), self.label, options.style.text);
    }

    pub fn collectInteractions(self: Switch, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return common.collectHit(collector, bounds, .switch_control, self.id);
    }

    pub fn measure(self: Switch, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_switch, constraints);
    }

    pub fn toObject(self: Switch, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.stringAndRefObject(.switch_control, self.id, self.label, component_codec.boolRef(self.checked), ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Switch, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.stringAndRefRecord(writer, index, .switch_control, self.id, self.label, component_codec.boolRef(self.checked));
    }

    pub fn fromView(view: object.View) Error!Switch {
        return switch (try component_codec.singleNode(view)) {
            .switch_control => |switch_control| .{ .id = switch_control.id, .label = switch_control.label, .checked = switch_control.checked },
            else => error.UnsupportedComponent,
        };
    }
};

const switch_width: f32 = 42.0;
const switch_height: f32 = 24.0;
const switch_knob_size: f32 = 18.0;
const switch_knob_inset: f32 = 3.0;
const switch_label_gap: f32 = 10.0;
pub const preferred_switch = ui.Size{ .w = 220.0, .h = 32.0 };

test "switch component serializes to canonical object and deserializes" {
    const switch_control = Switch{ .id = 12, .label = "Public", .checked = false };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = switch_control.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Switch.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(switch_control.id, decoded.id);
    try std.testing.expectEqualStrings(switch_control.label, decoded.label);
    try std.testing.expectEqual(switch_control.checked, decoded.checked);
}

test "switch component uses panel token for knob" {
    const switch_control = Switch{ .id = 12, .label = "Public", .checked = true };
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    const panel = ui.Color{ .r = 1, .g = 2, .b = 3 };

    try switch_control.render(&scene, ui.Rect.init(0, 0, 220, 32), .{ .style = .{ .panel = panel } });

    try std.testing.expect(component_test.hasFillColor(scene.written(), panel));
}
