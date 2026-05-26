const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const icon = @import("../../icon.zig");
const tokens = @import("../../ui_tokens.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const Checkbox = struct {
    id: u32,
    label: []const u8,
    checked: bool,

    pub fn node(self: Checkbox) ui.Node {
        return ui.checkboxNode(self.id, self.label, self.checked);
    }

    pub fn render(self: Checkbox, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const box = ui.Rect.init(bounds.x, bounds.y + (bounds.h - checkbox_box_size) * 0.5, checkbox_box_size, checkbox_box_size);
        try scene.pushRect(box, if (self.checked) options.style.accent else options.style.panel, .fill, control_radius, 0.0);
        try scene.pushRect(box, if (self.checked) options.style.accent else options.style.border, .border, control_radius, 0.0);
        if (self.checked) {
            try scene.pushIconQuad(.{ .bounds = box.insetUniform(checkbox_icon_inset), .icon_id = icon.id(.check), .color = options.style.bg });
        }
        const label_x = box.x + box.w + checkbox_text_gap;
        try scene.pushText(ui.Rect.init(label_x, bounds.y, @max(min_extent, bounds.x + bounds.w - label_x), bounds.h).withHeightCentered(control_label_height), self.label, options.style.text);
    }

    pub fn collectInteractions(self: Checkbox, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return common.collectHit(collector, bounds, .checkbox, self.id);
    }

    pub fn measure(self: Checkbox, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_checkbox, constraints);
    }

    pub fn toObject(self: Checkbox, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.stringAndRefObject(.checkbox, self.id, self.label, component_codec.boolRef(self.checked), ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Checkbox, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.stringAndRefRecord(writer, index, .checkbox, self.id, self.label, component_codec.boolRef(self.checked));
    }

    pub fn fromView(view: object.View) Error!Checkbox {
        return switch (try component_codec.singleNode(view)) {
            .checkbox => |checkbox| .{ .id = checkbox.id, .label = checkbox.label, .checked = checkbox.checked },
            else => error.UnsupportedComponent,
        };
    }
};

fn measureFixed(preferred: ui.Size, constraints: layout.Constraints) layout.Measurement {
    const resolved_preferred = constrainPreferredSize(preferred, constraints);
    return layout.Measurement.flexible(
        .{ .w = @min(preferred.w, resolved_preferred.w), .h = @min(preferred.h, resolved_preferred.h) },
        resolved_preferred,
        .{ .w = measure_max_width, .h = preferred.h },
    ).applyExact(constraints);
}

fn constrainPreferredSize(preferred: ui.Size, constraints: layout.Constraints) ui.Size {
    return .{
        .w = constraints.width.limit(preferred.w),
        .h = constraints.height.limit(preferred.h),
    };
}

const min_extent: f32 = 1.0;
const measure_max_width: f32 = 4096.0;
const control_radius: f32 = tokens.Component.control_radius;
const control_label_height: f32 = tokens.Component.control_label_height;
const checkbox_box_size: f32 = 18.0;
const checkbox_icon_inset: f32 = 3.0;
const checkbox_text_gap: f32 = 10.0;
pub const preferred_checkbox = ui.Size{ .w = 220.0, .h = 28.0 };

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

    try std.testing.expectEqual(@as(usize, 1), component_test.iconCount(scene.written(), icon.id(.check)));
}
