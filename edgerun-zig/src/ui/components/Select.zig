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
const icon_component = @import("Icon.zig");
const icon = @import("../../icon.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;
const constrainPreferredSize = component_primitives.constrainPreferredSize;
const contentInset = component_primitives.contentInset;

pub const Select = struct {
    id: u32,
    label: []const u8,

    pub fn node(self: Select) ui.Node {
        return ui.selectNode(self.id, self.label);
    }

    pub fn accessibility(self: Select) common.Accessibility {
        return .{ .role = .input, .label = self.label, .control_id = self.id };
    }

    pub fn render(self: Select, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        try scene.pushRect(bounds, options.style.panel, .fill, component_primitives.control_radius, 0.0);
        try scene.pushRect(bounds, options.style.border, .border, component_primitives.control_radius, 0.0);
        if (contentInset(bounds, component_primitives.control_text_padding)) |label_bounds| {
            const text_bounds = ui.Rect.init(label_bounds.x, label_bounds.y, @max(component_primitives.min_extent, label_bounds.w - select_arrow_w), label_bounds.h);
            const text_h = @min(text_bounds.h, component_primitives.measuredTextHeight(self.label, text_bounds.w, component_primitives.control_label_height, select_label_max_lines));
            try scene.pushWrappedText(text_bounds.withHeightCentered(text_h), self.label, options.style.text, component_primitives.textWrap(self.label, component_primitives.control_label_height, select_label_max_lines));
            const arrow_bounds = ui.Rect.init(label_bounds.x + label_bounds.w - select_icon_size, label_bounds.y + (label_bounds.h - select_icon_size) * 0.5, select_icon_size, select_icon_size);
            try icon_component.renderGlyph(scene, arrow_bounds, .chevron_right, options.style.muted);
        }
    }

    pub fn collectInteractions(self: Select, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return common.collectHit(collector, bounds, .select, self.id);
    }

    pub fn measure(self: Select, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        const inner = constraints.inner(.{ .left = component_primitives.control_text_padding, .right = component_primitives.control_text_padding + select_arrow_w });
        const label = layout.measureText(self.label, inner, component_primitives.textMetrics(self.label, component_primitives.control_label_height, select_label_max_lines));
        const preferred = constrainPreferredSize(.{
            .w = @max(select_min_width, label.preferred.w + component_primitives.control_text_padding * 2.0 + select_arrow_w),
            .h = @max(preferred_select.h, label.preferred.h + component_primitives.control_text_padding * 2.0),
        }, constraints);
        return layout.Measurement.flexible(
            .{ .w = @min(select_min_width, preferred.w), .h = @min(preferred_select.h, preferred.h) },
            preferred,
            .{ .w = component_primitives.measure_max_width, .h = @max(preferred.h, preferred_select.h) },
        ).applyExact(constraints);
    }

    pub fn toObject(self: Select, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.oneStringObject(.select, self.id, self.label, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Select, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.oneStringRecord(writer, index, .select, self.id, self.label);
    }

    pub fn fromView(view: object.View) Error!Select {
        const select = try component_codec.nodeView(view, .select);
        return .{ .id = select.id, .label = select.label };
    }
};

const select_arrow_w: f32 = 18.0;
const select_icon_size: f32 = 14.0;
const select_label_max_lines: usize = 2;
const select_min_width: f32 = 112.0;
pub const preferred_select = ui.Size{ .w = 220.0, .h = 40.0 };

test "select component serializes to canonical object and deserializes" {
    const select = Select{ .id = 22, .label = "Production" };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = select.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Select.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(select.id, decoded.id);
    try std.testing.expectEqualStrings(select.label, decoded.label);
}

test "select component renders chevron through icon primitive" {
    const select = Select{ .id = 22, .label = "Production" };
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try select.render(&scene, ui.Rect.init(0, 0, 220, 40), .{});

    try std.testing.expect(component_test.hasIcon(scene.written(), icon.id(.chevron_right)));
    try std.testing.expect(!component_test.hasText(scene.written(), "v"));
}

test "select measurement wraps long labels under narrow constraints" {
    const select = Select{ .id = 22, .label = "Production runtime authority" };

    const measured = select.measure(.{ .width = .{ .at_most = select_min_width }, .text_wrap = .wrap }, .{});

    try std.testing.expect(measured.preferred.w <= select_min_width);
    try std.testing.expect(measured.preferred.h > preferred_select.h);
}
