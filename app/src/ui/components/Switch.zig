const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const text_component = @import("Text.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

const constrainPreferredSize = component_primitives.constrainPreferredSize;

pub const Switch = struct {
    id: u32,
    label: []const u8,
    checked: bool,

    pub fn node(self: Switch) ui.Node {
        return ui.switchNode(self.id, self.label, self.checked);
    }

    pub fn accessibility(self: Switch) common.Accessibility {
        return .{ .role = .switch_control, .label = self.label, .control_id = self.id };
    }

    pub fn render(self: Switch, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const pill = ui.Rect.init(bounds.x + bounds.w - switch_width, bounds.y + (bounds.h - switch_height) * 0.5, switch_width, switch_height);
        try scene.pushRect(pill, if (self.checked) options.style.accent else options.style.row, .fill, switch_height * 0.5, 0.0);
        try scene.pushRect(pill, options.style.border, .border, switch_height * 0.5, 0.0);
        const knob_x = if (self.checked) pill.x + pill.w - switch_knob_size - switch_knob_inset else pill.x + switch_knob_inset;
        const knob = ui.Rect.init(knob_x, pill.y + switch_knob_inset, switch_knob_size, switch_knob_size);
        try scene.pushRect(knob, options.style.panel, .fill, switch_knob_size * 0.5, 0.0);
        const label_w = @max(component_primitives.min_extent, pill.x - bounds.x - switch_label_gap);
        const label_h = @min(bounds.h, component_primitives.measuredTextHeight(self.label, label_w, switch_label_height, switch_label_max_lines));
        try text_component.Text.renderWrapped(scene, ui.Rect.init(bounds.x, bounds.y, label_w, bounds.h).withHeightCentered(label_h), self.label, options.style.text, component_primitives.textWrap(self.label, switch_label_height, switch_label_max_lines));
    }

    pub fn collectInteractions(self: Switch, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return common.collectHit(collector, bounds, .switch_control, self.id);
    }

    pub fn measure(self: Switch, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        const label_constraints = constraints.inner(.{ .right = switch_width + switch_label_gap });
        const label = text_component.Text.measureValue(self.label, label_constraints, component_primitives.textMetrics(self.label, switch_label_height, switch_label_max_lines));
        const preferred = constrainPreferredSize(.{
            .w = @max(switch_min_width, label.preferred.w + switch_label_gap + switch_width),
            .h = @max(switch_height, label.preferred.h),
        }, constraints);
        return layout.Measurement.flexible(
            .{ .w = @min(switch_min_width, preferred.w), .h = @min(switch_height, preferred.h) },
            preferred,
            .{ .w = component_primitives.maxMeasuredWidth(constraints, preferred.w), .h = preferred.h },
        ).applyExact(constraints);
    }

    pub fn toObject(self: Switch, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.stringAndRefObject(.switch_control, self.id, self.label, component_codec.boolRef(self.checked), ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Switch, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.stringAndRefRecord(writer, index, .switch_control, self.id, self.label, component_codec.boolRef(self.checked));
    }

    pub fn fromView(view: object.View) Error!Switch {
        const switch_control = try component_codec.nodeView(view, .switch_control);
        return fromNode(switch_control);
    }

    pub fn fromNode(switch_control: @FieldType(ui.Node, "switch_control")) Error!Switch {
        return .{ .id = switch_control.id, .label = switch_control.label, .checked = switch_control.checked };
    }
};

const switch_width: f32 = 42.0;
const switch_height: f32 = 24.0;
const switch_knob_size: f32 = 18.0;
const switch_knob_inset: f32 = 3.0;
const switch_label_gap: f32 = 10.0;
const switch_label_height: f32 = component_primitives.control_label_height;
const switch_label_max_lines: usize = 2;
const switch_min_width: f32 = 112.0;

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

test "switch measurement wraps long labels under narrow constraints" {
    const short = Switch{ .id = 12, .label = "Private", .checked = true };
    const switch_control = Switch{ .id = 12, .label = "Require private runtime approvals", .checked = true };

    const short_measured = short.measure(.{ .width = .{ .at_most = switch_min_width }, .text_wrap = .wrap }, .{});
    const measured = switch_control.measure(.{ .width = .{ .at_most = switch_min_width }, .text_wrap = .wrap }, .{});

    try std.testing.expect(measured.preferred.w <= switch_min_width);
    try std.testing.expect(measured.preferred.h > short_measured.preferred.h);
}
