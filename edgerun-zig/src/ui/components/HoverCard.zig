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

pub const HoverCard = struct {
    id: u32,
    trigger: []const u8,
    content: []const u8,

    pub fn node(self: HoverCard) ui.Node {
        return ui.hoverCardNode(self.id, self.trigger, self.content);
    }

    pub fn render(self: HoverCard, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderHoverCard(scene, bounds, self.trigger, self.content, options);
    }

    pub fn collectInteractions(self: HoverCard, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(component_render.hoverCardTriggerBounds(bounds), .button, self.id);
        try collector.addHit(component_render.hoverCardContentBounds(bounds), .button, self.id + 1);
    }

    pub fn measure(self: HoverCard, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_hover_card, constraints);
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
