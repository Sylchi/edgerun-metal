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

pub const registration = .{ .name = "carousel", .Payload = Carousel };
const contentInset = component_primitives.contentInset;
const measureFixed = component_primitives.measureFixed;

pub const Carousel = struct {
    id: u32,
    label: []const u8,

    pub fn node(self: Carousel) ui.Node {
        return ui.carouselNode(self.id, self.label);
    }

    pub fn render(self: Carousel, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        try renderButton(scene, buttonBounds(bounds, 0), "<", options);
        const content = contentBounds(bounds);
        try scene.pushRect(content, options.style.row, .fill, carousel_radius, 0.0);
        if (contentInset(content, carousel_text_padding)) |inner| {
            try text_component.Text.renderAligned(scene, inner.withHeightCentered(component_primitives.control_label_height), self.label, options.style.muted, .center);
        }
        try renderButton(scene, buttonBounds(bounds, 1), ">", options);
    }

    pub fn collectInteractions(self: Carousel, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(buttonBounds(bounds, 0), .button, self.id);
        try collector.addHit(buttonBounds(bounds, 1), .button, self.id + 1);
    }

    pub fn measure(self: Carousel, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_carousel, constraints);
    }

    pub fn toObject(self: Carousel, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.oneStringObject(.carousel, self.id, self.label, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Carousel, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.oneStringRecord(writer, index, .carousel, self.id, self.label);
    }

    pub fn fromView(view: object.View) Error!Carousel {
        const carousel = try component_codec.nodeView(view, .carousel);
        return fromNode(carousel);
    }

    pub fn fromNode(carousel: @FieldType(ui.Node, "carousel")) Error!Carousel {
        return .{ .id = carousel.id, .label = carousel.label };
    }
};

fn renderButton(scene: *ui.Scene, bounds: ui.Rect, label: []const u8, options: RenderOptions) ui.RenderError!void {
    try scene.pushRect(bounds, ui.Color.clear, .fill, carousel_button_size * 0.5, 0.0);
    try scene.pushRect(bounds, options.style.border, .border, carousel_button_size * 0.5, 0.0);
    if (contentInset(bounds, carousel_button_text_padding)) |inner| {
        try text_component.Text.renderAligned(scene, inner.withHeightCentered(component_primitives.control_label_height), label, options.style.text, .center);
    }
}

fn buttonBounds(bounds: ui.Rect, index: usize) ui.Rect {
    const y = bounds.y + (bounds.h - carousel_button_size) * 0.5;
    return switch (index) {
        0 => ui.Rect.init(bounds.x, y, carousel_button_size, carousel_button_size),
        else => ui.Rect.init(bounds.x + bounds.w - carousel_button_size, y, carousel_button_size, carousel_button_size),
    };
}

fn contentBounds(bounds: ui.Rect) ui.Rect {
    const x = bounds.x + carousel_button_size + carousel_gap;
    return ui.Rect.init(x, bounds.y, @max(component_primitives.min_extent, bounds.w - carousel_button_size * 2.0 - carousel_gap * 2.0), bounds.h);
}

const carousel_button_size: f32 = 28.0;
const carousel_gap: f32 = 8.0;
const carousel_radius: f32 = 8.0;
const carousel_text_padding: f32 = 8.0;
const carousel_button_text_padding: f32 = 4.0;
pub const preferred_carousel = ui.Size{ .w = 240.0, .h = 40.0 };

test "carousel component serializes to canonical object and deserializes" {
    const carousel = Carousel{ .id = 990, .label = "Slide" };
    var ui_raw: [160]u8 = undefined;
    var object_raw: [object.header_size + 160]u8 = undefined;

    const canonical = carousel.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Carousel.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(carousel.id, decoded.id);
    try std.testing.expectEqualStrings(carousel.label, decoded.label);
}

test "carousel component renders content and button hit regions" {
    const carousel = Carousel{ .id = 990, .label = "Slide" };
    var commands: [24]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try carousel.render(&scene, ui.Rect.init(0, 0, 240, 40), .{});
    try carousel.collectInteractions(&collector, ui.Rect.init(0, 0, 240, 40));

    try std.testing.expect(component_test.hasText(scene.written(), "Slide"));
    try std.testing.expectEqual(@as(usize, 2), collector.written().len);
    try std.testing.expectEqual(@as(u32, 991), collector.written()[1].id);
}
