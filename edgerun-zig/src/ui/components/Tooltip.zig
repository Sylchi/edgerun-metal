const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const tokens = @import("../../ui_tokens.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const Tooltip = struct {
    id: u32,
    trigger: []const u8,
    content: []const u8,

    pub fn node(self: Tooltip) ui.Node {
        return ui.tooltipNode(self.id, self.trigger, self.content);
    }

    pub fn render(self: Tooltip, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const trigger_bounds = triggerBounds(bounds);
        try scene.pushRect(trigger_bounds, options.style.panel, .fill, control_radius, 0.0);
        try scene.pushRect(trigger_bounds, options.style.border, .border, control_radius, 0.0);
        if (contentInset(trigger_bounds, control_text_padding)) |inner| {
            try scene.pushAlignedText(inner.withHeightCentered(control_label_height), self.trigger, options.style.text, .center);
        }
        const tip = contentBounds(bounds);
        try scene.pushRect(tip, options.style.text, .fill, tooltip_radius, 0.0);
        if (contentInset(tip, tooltip_padding)) |inner| {
            try scene.pushAlignedText(inner.withHeightCentered(tooltip_text_h), self.content, options.style.bg, .center);
        }
    }

    pub fn collectInteractions(self: Tooltip, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(triggerBounds(bounds), .button, self.id);
    }

    pub fn measure(self: Tooltip, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_tooltip, constraints);
    }

    pub fn toObject(self: Tooltip, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.tooltip, self.id, self.trigger, self.content, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Tooltip, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .tooltip, self.id, self.trigger, self.content);
    }

    pub fn fromView(view: object.View) Error!Tooltip {
        return switch (try component_codec.singleNode(view)) {
            .tooltip => |tooltip| .{ .id = tooltip.id, .trigger = tooltip.trigger, .content = tooltip.content },
            else => error.UnsupportedComponent,
        };
    }
};

fn triggerBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y + tooltip_trigger_y, tooltip_trigger_w, tooltip_trigger_h);
}

fn contentBounds(bounds: ui.Rect) ui.Rect {
    const x = bounds.x + tooltip_trigger_w + tooltip_gap;
    return ui.Rect.init(x, bounds.y + tooltip_content_y, @max(min_extent, bounds.x + bounds.w - x), tooltip_content_h);
}

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
const tooltip_trigger_y: f32 = 8.0;
const tooltip_trigger_w: f32 = 80.0;
const tooltip_trigger_h: f32 = 28.0;
const tooltip_gap: f32 = 10.0;
const tooltip_content_y: f32 = 7.0;
const tooltip_content_h: f32 = 24.0;
const tooltip_radius: f32 = 6.0;
const tooltip_padding: f32 = 8.0;
const tooltip_text_h: f32 = 12.0;
pub const preferred_tooltip = ui.Size{ .w = 240.0, .h = 44.0 };

test "tooltip component serializes to canonical object and deserializes" {
    const tooltip = Tooltip{ .id = 994, .trigger = "Hover me", .content = "Add to library" };
    var ui_raw: [192]u8 = undefined;
    var object_raw: [object.header_size + 192]u8 = undefined;

    const canonical = tooltip.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Tooltip.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(tooltip.id, decoded.id);
    try std.testing.expectEqualStrings(tooltip.trigger, decoded.trigger);
    try std.testing.expectEqualStrings(tooltip.content, decoded.content);
}

test "tooltip component renders trigger content and hit region" {
    const tooltip = Tooltip{ .id = 994, .trigger = "Hover me", .content = "Add to library" };
    var commands: [20]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [1]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try tooltip.render(&scene, ui.Rect.init(0, 0, 240, 44), .{});
    try tooltip.collectInteractions(&collector, ui.Rect.init(0, 0, 240, 44));

    try std.testing.expect(component_test.hasText(scene.written(), "Hover me"));
    try std.testing.expect(component_test.hasText(scene.written(), "Add to library"));
    try std.testing.expectEqual(@as(usize, 1), collector.written().len);
    try std.testing.expectEqual(ui.HitKind.button, collector.written()[0].kind);
}
