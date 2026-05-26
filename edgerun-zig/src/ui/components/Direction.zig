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

pub const Direction = struct {
    id: u32,
    active: u16,

    pub fn node(self: Direction) ui.Node {
        return ui.directionNode(self.id, self.active);
    }

    pub fn render(self: Direction, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderDirection(scene, bounds, self.active, options);
    }

    pub fn collectInteractions(self: Direction, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(component_render.directionItemBounds(bounds, 0), .button, self.id);
        try collector.addHit(component_render.directionItemBounds(bounds, 1), .button, self.id + 1);
    }

    pub fn measure(self: Direction, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_direction, constraints);
    }

    pub fn toObject(self: Direction, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        var writer = component_codec.Writer.init(ui_out, 1, 1, .column, 0, 0) orelse return null;
        if (!self.writeRecord(&writer, 0)) return null;
        return writer.objectNode(object_out, component_codec.requirements(), epoch);
    }

    pub fn writeRecord(self: Direction, writer: *component_codec.Writer, index: usize) bool {
        return writer.record(index, .direction, self.id * component_render.direction_item_count + @min(self.active, component_render.direction_item_count - 1), .{}, .{});
    }

    pub fn fromView(view: object.View) Error!Direction {
        return switch (try component_codec.singleNode(view)) {
            .direction => |direction| .{ .id = direction.id, .active = direction.active },
            else => error.UnsupportedComponent,
        };
    }
};

test "direction component serializes to canonical object and deserializes" {
    const direction = Direction{ .id = 1004, .active = 1 };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = direction.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Direction.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(direction.id, decoded.id);
    try std.testing.expectEqual(direction.active, decoded.active);
}

test "direction component renders choices and hit regions" {
    const direction = Direction{ .id = 1004, .active = 1 };
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try direction.render(&scene, ui.Rect.init(0, 0, 150, 36), .{});
    try direction.collectInteractions(&collector, ui.Rect.init(0, 0, 150, 36));

    try std.testing.expect(component_test.hasText(scene.written(), "LTR"));
    try std.testing.expect(component_test.hasText(scene.written(), "RTL"));
    try std.testing.expectEqual(@as(usize, 2), collector.written().len);
    try std.testing.expectEqual(@as(u32, 1005), collector.written()[1].id);
}
