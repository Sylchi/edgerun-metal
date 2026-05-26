const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const text_metrics = @import("../../ui_text_metrics.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const tokens = @import("../../ui_tokens.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const InputGroup = struct {
    id: u32,
    addon: []const u8,
    placeholder: []const u8,

    pub fn node(self: InputGroup) ui.Node {
        return ui.inputGroupNode(self.id, self.addon, self.placeholder);
    }

    pub fn render(self: InputGroup, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        try scene.pushRect(bounds, options.style.panel, .fill, control_radius, 0.0);
        try scene.pushRect(bounds, options.style.border, .border, control_radius, 0.0);
        const addon_w = @min(input_group_addon_max_w, @max(input_group_addon_min_w, text_metrics.width(self.addon, control_label_height) + input_group_addon_padding * 2.0));
        const addon_bounds = ui.Rect.init(bounds.x, bounds.y, addon_w, bounds.h);
        if (contentInset(addon_bounds, input_group_addon_padding)) |inner| {
            try scene.pushAlignedText(inner.withHeightCentered(control_label_height), self.addon, options.style.muted, .center);
        }
        try scene.pushRect(ui.Rect.init(addon_bounds.x + addon_bounds.w, bounds.y + input_group_separator_inset, separator_height, @max(min_extent, bounds.h - input_group_separator_inset * 2.0)), options.style.border, .fill, 0.0, 0.0);
        const control_bounds = ui.Rect.init(addon_bounds.x + addon_bounds.w + input_group_control_gap, bounds.y, @max(min_extent, bounds.w - addon_w - input_group_control_gap), bounds.h);
        if (contentInset(control_bounds, control_text_padding)) |inner| {
            try scene.pushText(inner.withHeightCentered(control_label_height), self.placeholder, options.style.muted);
        }
    }

    pub fn collectInteractions(self: InputGroup, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return common.collectHit(collector, bounds, .input, self.id);
    }

    pub fn measure(self: InputGroup, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_input_group, constraints);
    }

    pub fn toObject(self: InputGroup, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.input_group, self.id, self.addon, self.placeholder, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: InputGroup, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .input_group, self.id, self.addon, self.placeholder);
    }

    pub fn fromView(view: object.View) Error!InputGroup {
        return switch (try component_codec.singleNode(view)) {
            .input_group => |input_group| .{ .id = input_group.id, .addon = input_group.addon, .placeholder = input_group.placeholder },
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
const separator_height: f32 = 1.0;
const control_radius: f32 = tokens.Component.control_radius;
const control_text_padding: f32 = tokens.Component.control_text_padding;
const control_label_height: f32 = tokens.Component.control_label_height;
const input_group_addon_min_w: f32 = 42.0;
const input_group_addon_max_w: f32 = 96.0;
const input_group_addon_padding: f32 = 10.0;
const input_group_control_gap: f32 = 8.0;
const input_group_separator_inset: f32 = 8.0;
pub const preferred_input_group = ui.Size{ .w = 260.0, .h = 40.0 };

test "input group component serializes to canonical object and deserializes" {
    const input_group = InputGroup{ .id = 91, .addon = "https://", .placeholder = "example.com" };
    var ui_raw: [160]u8 = undefined;
    var object_raw: [object.header_size + 160]u8 = undefined;

    const canonical = input_group.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try InputGroup.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(input_group.id, decoded.id);
    try std.testing.expectEqualStrings(input_group.addon, decoded.addon);
    try std.testing.expectEqualStrings(input_group.placeholder, decoded.placeholder);
}

test "input group component renders addon placeholder and input hit" {
    const input_group = InputGroup{ .id = 91, .addon = "https://", .placeholder = "example.com" };
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [1]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try input_group.render(&scene, ui.Rect.init(0, 0, 260, 40), .{});
    try input_group.collectInteractions(&collector, ui.Rect.init(0, 0, 260, 40));

    try std.testing.expect(component_test.hasText(scene.written(), "https://"));
    try std.testing.expect(component_test.hasText(scene.written(), "example.com"));
    try std.testing.expectEqual(ui.HitKind.input, collector.written()[0].kind);
}
