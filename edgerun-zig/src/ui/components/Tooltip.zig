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

pub const Tooltip = struct {
    id: u32,
    trigger: []const u8,
    content: []const u8,

    pub fn node(self: Tooltip) ui.Node {
        return ui.tooltipNode(self.id, self.trigger, self.content);
    }

    pub fn render(self: Tooltip, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderTooltip(scene, bounds, self.trigger, self.content, options);
    }

    pub fn collectInteractions(self: Tooltip, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(component_render.tooltipTriggerBounds(bounds), .button, self.id);
    }

    pub fn measure(self: Tooltip, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_tooltip, constraints);
    }

    pub fn toObject(self: Tooltip, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.tooltip, self.id, self.trigger, self.content, ui_out, object_out, req, epoch);
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

test "tooltip component serializes to canonical object and deserializes" {
    const tooltip = Tooltip{ .id = 994, .trigger = "Hover me", .content = "Add to library" };
    var ui_raw: [192]u8 = undefined;
    var object_raw: [object.header_size + 192]u8 = undefined;

    const canonical = tooltip.toObject(&ui_raw, &object_raw, component_test.req(), component_test.epoch()).?;
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
