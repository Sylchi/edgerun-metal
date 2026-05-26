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

pub const Resizable = struct {
    id: u32,
    ratio: f32 = 0.58,

    pub fn node(self: Resizable) ui.Node {
        return ui.resizableNode(self.id, self.ratio);
    }

    pub fn render(self: Resizable, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderResizable(scene, bounds, self.ratio, options);
    }

    pub fn collectInteractions(self: Resizable, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(component_render.resizableHandleBounds(bounds, self.ratio).insetUniform(-component_render.resizable_handle_hit_outset), .slider, self.id);
    }

    pub fn measure(self: Resizable, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_resizable, constraints);
    }

    pub fn toObject(self: Resizable, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.refObject(.resizable, self.id, component_codec.unitRef(self.ratio), ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Resizable, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.refRecord(writer, index, .resizable, self.id, component_codec.unitRef(self.ratio));
    }

    pub fn fromView(view: object.View) Error!Resizable {
        return switch (try component_codec.singleNode(view)) {
            .resizable => |resizable| .{ .id = resizable.id, .ratio = resizable.ratio },
            else => error.UnsupportedComponent,
        };
    }
};

test "resizable component serializes to canonical object and deserializes" {
    const resizable = Resizable{ .id = 770, .ratio = 0.62 };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = resizable.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Resizable.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(resizable.id, decoded.id);
    try std.testing.expect(@abs(decoded.ratio - 0.62) < 0.001);
}

test "resizable component renders panels and handle hit region" {
    const resizable = Resizable{ .id = 770, .ratio = 0.58 };
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [1]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try resizable.render(&scene, ui.Rect.init(0, 0, 220, 36), .{});
    try resizable.collectInteractions(&collector, ui.Rect.init(0, 0, 220, 36));

    try std.testing.expect(scene.written().len >= 3);
    try std.testing.expectEqual(@as(usize, 1), collector.written().len);
    try std.testing.expectEqual(ui.HitKind.slider, collector.written()[0].kind);
    try std.testing.expectEqual(@as(u32, 770), collector.written()[0].id);
}
