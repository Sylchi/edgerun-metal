const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const component_contract = @import("ComponentContract.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const registration = component_contract.registration("skeleton", Skeleton);
const measureFixed = component_primitives.measureFixed;

pub const Skeleton = struct {
    pub fn node(self: Skeleton) ui.Node {
        _ = self;
        return ui.skeletonNode();
    }

    pub fn render(self: Skeleton, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        _ = self;
        var fill = options.style.accent;
        fill.a = skeleton_alpha;
        try scene.pushRect(bounds, fill, .fill, skeleton_radius, 0.0);
    }

    pub fn measure(self: Skeleton, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_skeleton, constraints);
    }

    pub fn toObject(self: Skeleton, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        _ = self;
        return component_codec.emptyObject(.skeleton, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Skeleton, writer: *component_codec.Writer, index: usize) bool {
        _ = self;
        return component_codec.emptyRecord(writer, index, .skeleton);
    }

    pub fn fromView(view: object.View) Error!Skeleton {
        return fromNode(try component_codec.nodeView(view, .skeleton));
    }

    pub fn fromNode(skeleton: @FieldType(ui.Node, "skeleton")) Error!Skeleton {
        _ = skeleton;
        return .{};
    }
};

const skeleton_alpha: u8 = 32;
const skeleton_radius: f32 = 6.0;
pub const preferred_skeleton = ui.Size{ .w = 220.0, .h = 20.0 };

test "skeleton component serializes to canonical object and deserializes" {
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = (Skeleton{}).toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    _ = try Skeleton.fromView(try object.View.decode(canonical));
}

test "skeleton component renders muted accent pulse base" {
    var commands: [4]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try (Skeleton{}).render(&scene, ui.Rect.init(8, 12, 120, 20), .{});

    const rect = component_test.lastFillRect(scene.written()).?;
    try std.testing.expectEqual(ui.Rect.init(8, 12, 120, 20), rect);
}
