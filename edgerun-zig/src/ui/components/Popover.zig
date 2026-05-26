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

pub const Popover = struct {
    id: u32,
    trigger: []const u8,
    content: []const u8,

    pub fn node(self: Popover) ui.Node {
        return ui.popoverNode(self.id, self.trigger, self.content);
    }

    pub fn render(self: Popover, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        try renderControlFrame(scene, triggerBounds(bounds), options.style.accent, options.style.border, control_radius);
        try renderControlText(scene, triggerBounds(bounds), control_text_padding, control_label_height, self.trigger, options.style.bg, .center);
        const content_bounds = contentBounds(bounds);
        try scene.pushRect(content_bounds, options.style.panel, .fill, popover_radius, 0.0);
        try scene.pushRect(content_bounds, options.style.border, .border, popover_radius, 0.0);
        try renderControlText(scene, content_bounds, popover_padding, control_label_height, self.content, options.style.text, .start);
    }

    pub fn collectInteractions(self: Popover, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(triggerBounds(bounds), .button, self.id);
        try collector.addHit(contentBounds(bounds), .button, self.id + 1);
    }

    pub fn measure(self: Popover, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_popover, constraints);
    }

    pub fn toObject(self: Popover, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.popover, self.id, self.trigger, self.content, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Popover, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .popover, self.id, self.trigger, self.content);
    }

    pub fn fromView(view: object.View) Error!Popover {
        return switch (try component_codec.singleNode(view)) {
            .popover => |popover| .{ .id = popover.id, .trigger = popover.trigger, .content = popover.content },
            else => error.UnsupportedComponent,
        };
    }
};

fn triggerBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y + popover_trigger_y, popover_trigger_w, popover_trigger_h);
}

fn contentBounds(bounds: ui.Rect) ui.Rect {
    const x = bounds.x + popover_trigger_w + popover_gap;
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
const popover_trigger_y: f32 = 6.0;
const popover_trigger_w: f32 = 64.0;
const popover_trigger_h: f32 = 30.0;
const popover_gap: f32 = 10.0;
const popover_radius: f32 = 8.0;
const popover_padding: f32 = 10.0;
const preferred_popover = ui.Size{ .w = 240.0, .h = 52.0 };

test "popover component serializes to canonical object and deserializes" {
    const popover = Popover{ .id = 995, .trigger = "Open", .content = "Place content" };
    var ui_raw: [192]u8 = undefined;
    var object_raw: [object.header_size + 192]u8 = undefined;

    const canonical = popover.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Popover.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(popover.id, decoded.id);
    try std.testing.expectEqualStrings(popover.trigger, decoded.trigger);
    try std.testing.expectEqualStrings(popover.content, decoded.content);
}

test "popover component renders trigger content and hit regions" {
    const popover = Popover{ .id = 995, .trigger = "Open", .content = "Place content" };
    var commands: [20]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try popover.render(&scene, ui.Rect.init(0, 0, 240, 52), .{});
    try popover.collectInteractions(&collector, ui.Rect.init(0, 0, 240, 52));

    try std.testing.expect(component_test.hasText(scene.written(), "Open"));
    try std.testing.expect(component_test.hasText(scene.written(), "Place content"));
    try std.testing.expectEqual(@as(usize, 2), collector.written().len);
    try std.testing.expectEqual(@as(u32, 996), collector.written()[1].id);
}
