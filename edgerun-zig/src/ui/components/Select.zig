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

pub const Select = struct {
    id: u32,
    label: []const u8,

    pub fn node(self: Select) ui.Node {
        return ui.selectNode(self.id, self.label);
    }

    pub fn render(self: Select, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        try scene.pushRect(bounds, options.style.panel, .fill, control_radius, 0.0);
        try scene.pushRect(bounds, options.style.border, .border, control_radius, 0.0);
        if (contentInset(bounds, control_text_padding)) |label_bounds| {
            const text_bounds = ui.Rect.init(label_bounds.x, label_bounds.y, @max(min_extent, label_bounds.w - select_arrow_w), label_bounds.h);
            try scene.pushText(text_bounds.withHeightCentered(control_label_height), self.label, options.style.text);
            const arrow_bounds = ui.Rect.init(label_bounds.x + label_bounds.w - select_icon_size, label_bounds.y + (label_bounds.h - select_icon_size) * 0.5, select_icon_size, select_icon_size);
            try scene.pushIconQuad(.{ .bounds = arrow_bounds, .icon_id = icon.id(.chevron_right), .color = options.style.muted });
        }
    }

    pub fn collectInteractions(self: Select, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return common.collectHit(collector, bounds, .select, self.id);
    }

    pub fn measure(self: Select, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_select, constraints);
    }

    pub fn toObject(self: Select, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.oneStringObject(.select, self.id, self.label, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Select, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.oneStringRecord(writer, index, .select, self.id, self.label);
    }

    pub fn fromView(view: object.View) Error!Select {
        return switch (try component_codec.singleNode(view)) {
            .select => |select| .{ .id = select.id, .label = select.label },
            else => error.UnsupportedComponent,
        };
    }
};

fn contentInset(bounds: ui.Rect, padding: f32) ?ui.Rect {
    const clamped = @min(@max(padding, 0.0), @min(bounds.w, bounds.h) * 0.5);
    const out = bounds.insetUniform(clamped);
    return if (out.valid()) out else null;
}

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
const control_text_padding: f32 = tokens.Component.control_text_padding;
const control_label_height: f32 = tokens.Component.control_label_height;
const select_arrow_w: f32 = 18.0;
const select_icon_size: f32 = 14.0;
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
