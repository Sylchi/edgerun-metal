const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const tokens = @import("../../ui_tokens.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const HoverCard = struct {
    id: u32,
    trigger: []const u8,
    content: []const u8,

    pub fn node(self: HoverCard) ui.Node {
        return ui.hoverCardNode(self.id, self.trigger, self.content);
    }

    pub fn render(self: HoverCard, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        try renderControlFrame(scene, triggerBounds(bounds), options.style.panel, options.style.border, control_radius);
        try renderControlText(scene, triggerBounds(bounds), control_text_padding, control_label_height, self.trigger, options.style.text, .center);
        const content_bounds = contentBounds(bounds);
        try scene.pushRect(content_bounds, options.style.panel, .fill, hover_card_radius, 0.0);
        try scene.pushRect(content_bounds, options.style.border, .border, hover_card_radius, 0.0);
        try scene.pushText(ui.Rect.init(content_bounds.x + hover_card_padding, content_bounds.y + hover_card_title_y, @max(min_extent, content_bounds.w - hover_card_padding * 2.0), hover_card_title_h), self.content, options.style.text);
        try scene.pushText(ui.Rect.init(content_bounds.x + hover_card_padding, content_bounds.y + hover_card_detail_y, @max(min_extent, content_bounds.w - hover_card_padding * 2.0), hover_card_detail_h), hover_card_detail_label, options.style.muted);
    }

    pub fn collectInteractions(self: HoverCard, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(triggerBounds(bounds), .button, self.id);
        try collector.addHit(contentBounds(bounds), .button, self.id + 1);
    }

    pub fn measure(self: HoverCard, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_hover_card, constraints);
    }

    pub fn toObject(self: HoverCard, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.hover_card, self.id, self.trigger, self.content, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: HoverCard, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .hover_card, self.id, self.trigger, self.content);
    }

    pub fn fromView(view: object.View) Error!HoverCard {
        return switch (try component_codec.singleNode(view)) {
            .hover_card => |hover_card| .{ .id = hover_card.id, .trigger = hover_card.trigger, .content = hover_card.content },
            else => error.UnsupportedComponent,
        };
    }
};

fn triggerBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y + hover_card_trigger_y, hover_card_trigger_w, hover_card_trigger_h);
}

fn contentBounds(bounds: ui.Rect) ui.Rect {
    const x = bounds.x + hover_card_trigger_w + hover_card_gap;
    return ui.Rect.init(x, bounds.y, @max(min_extent, bounds.x + bounds.w - x), bounds.h);
}

fn renderControlFrame(scene: *ui.Scene, bounds: ui.Rect, fill: ui.Color, border: ui.Color, radius: f32) ui.RenderError!void {
    try scene.pushRect(bounds, fill, .fill, radius, 0.0);
    try scene.pushRect(bounds, border, .border, radius, 0.0);
}

fn renderControlText(scene: *ui.Scene, bounds: ui.Rect, padding: f32, height: f32, value: []const u8, color: ui.Color, alignment: ui.TextAlign) ui.RenderError!void {
    const clamped = @min(@max(padding, 0.0), @min(bounds.w, bounds.h) * 0.5);
    const text_bounds = bounds.insetUniform(clamped);
    if (text_bounds.valid()) try scene.pushAlignedText(text_bounds.withHeightCentered(height), value, color, alignment);
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
const hover_card_trigger_y: f32 = 6.0;
const hover_card_trigger_w: f32 = 66.0;
const hover_card_trigger_h: f32 = 30.0;
const hover_card_gap: f32 = 10.0;
const hover_card_radius: f32 = 8.0;
const hover_card_padding: f32 = 10.0;
const hover_card_title_y: f32 = 8.0;
const hover_card_title_h: f32 = 14.0;
const hover_card_detail_y: f32 = 25.0;
const hover_card_detail_h: f32 = 12.0;
const hover_card_detail_label = "Hover content";
const preferred_hover_card = ui.Size{ .w = 240.0, .h = 52.0 };

test "hover card component serializes to canonical object and deserializes" {
    const hover_card = HoverCard{ .id = 997, .trigger = "Hover", .content = "@shadcn" };
    var ui_raw: [192]u8 = undefined;
    var object_raw: [object.header_size + 192]u8 = undefined;

    const canonical = hover_card.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try HoverCard.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(hover_card.id, decoded.id);
    try std.testing.expectEqualStrings(hover_card.trigger, decoded.trigger);
    try std.testing.expectEqualStrings(hover_card.content, decoded.content);
}

test "hover card component renders trigger content and hit regions" {
    const hover_card = HoverCard{ .id = 997, .trigger = "Hover", .content = "@shadcn" };
    var commands: [20]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try hover_card.render(&scene, ui.Rect.init(0, 0, 240, 52), .{});
    try hover_card.collectInteractions(&collector, ui.Rect.init(0, 0, 240, 52));

    try std.testing.expect(component_test.hasText(scene.written(), "Hover"));
    try std.testing.expect(component_test.hasText(scene.written(), "@shadcn"));
    try std.testing.expectEqual(@as(usize, 2), collector.written().len);
    try std.testing.expectEqual(@as(u32, 998), collector.written()[1].id);
}
