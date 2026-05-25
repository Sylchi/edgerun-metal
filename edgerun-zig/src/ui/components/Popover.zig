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

pub const Popover = struct {
    id: u32,
    trigger: []const u8,
    content: []const u8,

    pub fn node(self: Popover) ui.Node {
        return ui.popoverNode(self.id, self.trigger, self.content);
    }

    pub fn render(self: Popover, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderPopover(scene, bounds, self.trigger, self.content, options);
    }

    pub fn collectInteractions(self: Popover, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(component_render.popoverTriggerBounds(bounds), .button, self.id);
        try collector.addHit(component_render.popoverContentBounds(bounds), .button, self.id + 1);
    }

    pub fn measure(self: Popover, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_popover, constraints);
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
