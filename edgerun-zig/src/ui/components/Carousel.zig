const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_render = @import("Render.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const Carousel = struct {
    id: u32,
    label: []const u8,

    pub fn node(self: Carousel) ui.Node {
        return ui.carouselNode(self.id, self.label);
    }

    pub fn render(self: Carousel, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderCarousel(scene, bounds, self.label, options);
    }

    pub fn collectInteractions(self: Carousel, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(component_render.carouselButtonBounds(bounds, 0), .button, self.id);
        try collector.addHit(component_render.carouselButtonBounds(bounds, 1), .button, self.id + 1);
    }

    pub fn measure(self: Carousel, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_carousel, constraints);
    }

    pub fn toObject(self: Carousel, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.oneStringObject(.carousel, self.id, self.label, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Carousel, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.oneStringRecord(writer, index, .carousel, self.id, self.label);
    }

    pub fn fromView(view: object.View) Error!Carousel {
        return switch (try component_codec.singleNode(view)) {
            .carousel => |carousel| .{ .id = carousel.id, .label = carousel.label },
            else => error.UnsupportedComponent,
        };
    }
};

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
