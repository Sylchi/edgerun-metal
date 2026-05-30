const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../component_common.zig");
const interaction = @import("../interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../core.zig");
const text_component = @import("Text.zig");
const layout = @import("../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_primitives = @import("Primitives.zig");
const icon_component = @import("Icon.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

const constrainPreferredSize = component_primitives.constrainPreferredSize;
const Icon = icon_component.Icon;

pub const Checkbox = struct {
    id: u32,
    label: []const u8,
    checked: bool,

    pub fn node(self: Checkbox) ui.Node {
        return ui.checkboxNode(self.id, self.label, self.checked);
    }

    pub fn accessibility(self: Checkbox) common.Accessibility {
        return .{ .role = .checkbox, .label = self.label, .control_id = self.id };
    }

    pub fn render(self: Checkbox, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const box = ui.Rect.init(bounds.x, bounds.y + (bounds.h - checkbox_box_size) * 0.5, checkbox_box_size, checkbox_box_size);
        try scene.pushRect(box, if (self.checked) options.style.accent else options.style.panel, .fill, component_primitives.control_radius, 0.0);
        try scene.pushRect(box, if (self.checked) options.style.accent else options.style.border, .border, component_primitives.control_radius, 0.0);
        if (self.checked) {
            try Icon.named(.check).renderColor(scene, box.insetUniform(checkbox_icon_inset), options.style.bg);
        }
        const label_x = box.x + box.w + checkbox_text_gap;
        const label_w = @max(component_primitives.min_extent, bounds.x + bounds.w - label_x);
        const label_h = @min(bounds.h, component_primitives.measuredTextHeight(self.label, label_w, checkbox_label_height, checkbox_label_max_lines));
        try text_component.Text.renderWrapped(scene, ui.Rect.init(label_x, bounds.y, label_w, bounds.h).withHeightCentered(label_h), self.label, options.style.text, component_primitives.textWrap(self.label, checkbox_label_height, checkbox_label_max_lines));
    }

    pub fn collectInteractions(self: Checkbox, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return common.collectHit(collector, bounds, .checkbox, self.id);
    }

    pub fn measure(self: Checkbox, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        const label_constraints = constraints.inner(.{ .left = checkbox_box_size + checkbox_text_gap });
        const label = text_component.Text.measureValue(self.label, label_constraints, component_primitives.textMetrics(self.label, checkbox_label_height, checkbox_label_max_lines));
        const preferred = constrainPreferredSize(.{
            .w = @max(checkbox_min_width, checkbox_box_size + checkbox_text_gap + label.preferred.w),
            .h = @max(checkbox_box_size, label.preferred.h),
        }, constraints);
        return layout.Measurement.flexible(
            .{ .w = @min(checkbox_min_width, preferred.w), .h = @min(checkbox_box_size, preferred.h) },
            preferred,
            .{ .w = component_primitives.maxMeasuredWidth(constraints, preferred.w), .h = preferred.h },
        ).applyExact(constraints);
    }

    pub fn toObject(self: Checkbox, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.stringAndRefObject(.checkbox, self.id, self.label, component_codec.boolRef(self.checked), ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Checkbox, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.stringAndRefRecord(writer, index, .checkbox, self.id, self.label, component_codec.boolRef(self.checked));
    }

    pub fn fromView(view: object.View) Error!Checkbox {
        const checkbox = try component_codec.nodeView(view, .checkbox);
        return fromNode(checkbox);
    }

    pub fn fromNode(checkbox: @FieldType(ui.Node, "checkbox")) Error!Checkbox {
        return .{ .id = checkbox.id, .label = checkbox.label, .checked = checkbox.checked };
    }
};

const checkbox_box_size: f32 = 18.0;
const checkbox_icon_inset: f32 = 3.0;
const checkbox_text_gap: f32 = 10.0;
const checkbox_label_height: f32 = component_primitives.control_label_height;
const checkbox_label_max_lines: usize = 2;
const checkbox_min_width: f32 = 96.0;

test "checkbox component serializes to canonical object and deserializes" {
    const checkbox = Checkbox{ .id = 11, .label = "Enable sync", .checked = true };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = checkbox.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Checkbox.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(checkbox.id, decoded.id);
    try std.testing.expectEqualStrings(checkbox.label, decoded.label);
    try std.testing.expectEqual(checkbox.checked, decoded.checked);
}

test "checkbox component renders checked mark through icon primitive" {
    const checked = Checkbox{ .id = 11, .label = "Enable sync", .checked = true };
    const unchecked = Checkbox{ .id = 12, .label = "Disable sync", .checked = false };
    var commands: [24]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try checked.render(&scene, ui.Rect.init(0, 0, 220, 28), .{});
    try unchecked.render(&scene, ui.Rect.init(0, 36, 220, 28), .{});

    try std.testing.expectEqual(@as(usize, 1), component_test.iconCount(scene.written(), Icon.named(.check).tag()));
}

test "checkbox measurement wraps long labels under narrow constraints" {
    const checkbox = Checkbox{ .id = 11, .label = "Enable signed runtime synchronization", .checked = true };
    const compact = Checkbox{ .id = 11, .label = "Enable", .checked = true };

    const measured = checkbox.measure(.{ .width = .{ .at_most = checkbox_min_width }, .text_wrap = .wrap }, .{});
    const compact_measured = compact.measure(.{ .width = .{ .at_most = checkbox_min_width }, .text_wrap = .wrap }, .{});

    try std.testing.expect(measured.preferred.w <= checkbox_min_width);
    try std.testing.expect(measured.preferred.h > compact_measured.preferred.h);
}
