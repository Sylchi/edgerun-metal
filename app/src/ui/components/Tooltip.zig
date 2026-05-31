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

const Error = common.Error;
const RenderOptions = common.RenderOptions;

const constrainPreferredSize = component_primitives.constrainPreferredSize;

pub const Tooltip = struct {
    id: u32,
    flags: common.ComponentFlags = .{},
    trigger: []const u8,
    content: []const u8,

    pub fn node(self: Tooltip) ui.Node {
        return ui.tooltipNode(self.id, self.trigger, self.content);
    }

    pub fn render(self: Tooltip, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const trigger_bounds = triggerBounds(bounds);
        try component_primitives.renderControlTrigger(scene, trigger_bounds, options.style.panel, options.style.border, component_primitives.control_text_padding, self.trigger, options.style.text);
        if (options.overlay.isOpen(self.id)) {
            const tip = contentBounds(bounds, self.content);
            try scene.pushRect(tip, options.style.text, .fill, tooltip_radius, 0.0);
            if (component_primitives.contentInset(tip, tooltip_padding)) |inner| {
                const text_h = @min(inner.h, component_primitives.measuredTextHeight(self.content, inner.w, tooltip_text_h, tooltip_text_max_lines));
                try text_component.Text.renderWrapped(scene, inner.withHeightCentered(text_h), self.content, options.style.bg, component_primitives.textWrap(self.content, tooltip_text_h, tooltip_text_max_lines));
            }
        }
    }

    pub fn collectInteractions(self: Tooltip, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(triggerBounds(bounds), .overlay_trigger, self.id);
    }

    pub fn measure(self: Tooltip, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        const trigger = text_component.Text.measureValue(self.trigger, constraints, component_primitives.textMetrics(self.trigger, component_primitives.control_label_height, tooltip_trigger_max_lines));
        const content_constraints = constraints.inner(.{ .left = tooltip_trigger_w + tooltip_gap + tooltip_padding, .right = tooltip_padding });
        const content = text_component.Text.measureValue(self.content, content_constraints, component_primitives.textMetrics(self.content, tooltip_text_h, tooltip_text_max_lines));
        const preferred = constrainPreferredSize(.{
            .w = @max(tooltip_min_width, @max(trigger.preferred.w + component_primitives.control_text_padding * 2.0, tooltip_trigger_w) + tooltip_gap + content.preferred.w + tooltip_padding * 2.0),
            .h = @max(tooltip_min_height, @max(trigger.preferred.h, content.preferred.h + tooltip_padding * 2.0)),
        }, constraints);
        return layout.Measurement.flexible(
            .{ .w = @min(tooltip_min_width, preferred.w), .h = @min(tooltip_min_height, preferred.h) },
            preferred,
            .{ .w = component_primitives.maxMeasuredWidth(constraints, preferred.w), .h = preferred.h },
        ).applyExact(constraints);
    }

    pub fn toObject(self: Tooltip, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.tooltip, self.id, self.trigger, self.content, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Tooltip, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .tooltip, self.id, self.trigger, self.content);
    }

    pub fn fromView(view: object.View) Error!Tooltip {
        return component_codec.decodeFromView(Tooltip, .tooltip, view);
    }

    pub fn fromNode(tooltip: @FieldType(ui.Node, "tooltip")) Error!Tooltip {
        return .{ .id = tooltip.id, .trigger = tooltip.trigger, .content = tooltip.content };
    }
};

fn triggerBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y + tooltip_trigger_y, tooltip_trigger_w, tooltip_trigger_h);
}

fn contentBounds(bounds: ui.Rect, content: []const u8) ui.Rect {
    const x = bounds.x + tooltip_trigger_w + tooltip_gap;
    const width = @max(component_primitives.min_extent, bounds.x + bounds.w - x);
    const text_width = @max(component_primitives.min_extent, width - tooltip_padding * 2.0);
    const content_h = @max(tooltip_content_h, component_primitives.measuredTextHeight(content, text_width, tooltip_text_h, tooltip_text_max_lines) + tooltip_padding * 2.0);
    return ui.Rect.init(x, bounds.y + tooltip_content_y, width, @min(content_h, @max(component_primitives.min_extent, bounds.h - tooltip_content_y)));
}

const tooltip_trigger_y: f32 = 8.0;
const tooltip_trigger_w: f32 = 80.0;
const tooltip_trigger_h: f32 = 28.0;
const tooltip_gap: f32 = 10.0;
const tooltip_content_y: f32 = 7.0;
const tooltip_content_h: f32 = 24.0;
const tooltip_radius: f32 = 6.0;
const tooltip_padding: f32 = 8.0;
const tooltip_text_h: f32 = 12.0;
const tooltip_text_max_lines: usize = 2;
const tooltip_trigger_max_lines: usize = 2;
const tooltip_min_width: f32 = 160.0;
const tooltip_min_height: f32 = 44.0;

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

    try tooltip.render(&scene, ui.Rect.init(0, 0, 240, 44), .{ .overlay = .{ .open_ids = &.{tooltip.id} } });
    try tooltip.collectInteractions(&collector, ui.Rect.init(0, 0, 240, 44));

    try std.testing.expect(component_test.hasText(scene.written(), "Hover me"));
    try std.testing.expect(component_test.hasText(scene.written(), "Add to library"));
    try std.testing.expectEqual(@as(usize, 1), collector.written().len);
    try std.testing.expectEqual(ui.HitKind.overlay_trigger, collector.written()[0].kind);
}

test "tooltip measurement wraps long content under narrow constraints" {
    const tooltip = Tooltip{ .id = 994, .trigger = "Hover me", .content = "Inspect the signed runtime authority receipt" };

    const measured = tooltip.measure(.{ .width = .{ .at_most = tooltip_wrap_test_width }, .text_wrap = .wrap }, .{});
    const tip = contentBounds(ui.Rect.init(0, 0, tooltip_wrap_test_width, tooltip_min_height), tooltip.content);

    try std.testing.expect(measured.preferred.w <= tooltip_wrap_test_width);
    try std.testing.expect(tip.h > tooltip_content_h);
}

const tooltip_wrap_test_width: f32 = 120.0;
