const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_render = @import("Render.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const Skeleton = struct {
    pub fn node(self: Skeleton) ui.Node {
        _ = self;
        return ui.skeletonNode();
    }

    pub fn render(self: Skeleton, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        _ = self;
        return component_render.renderSkeleton(scene, bounds, options);
    }

    pub fn measure(self: Skeleton, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_skeleton, constraints);
    }

    pub fn toObject(self: Skeleton, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        _ = self;
        return component_codec.emptyObject(.skeleton, ui_out, object_out, req, epoch);
    }

    pub fn writeRecord(self: Skeleton, writer: *component_codec.Writer, index: usize) bool {
        _ = self;
        return component_codec.emptyRecord(writer, index, .skeleton);
    }

    pub fn fromView(view: object.View) Error!Skeleton {
        return switch (try component_codec.singleNode(view)) {
            .skeleton => .{},
            else => error.UnsupportedComponent,
        };
    }
};

test "skeleton component serializes to canonical object and deserializes" {
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = (Skeleton{}).toObject(&ui_raw, &object_raw, component_test.req(), component_test.epoch()).?;
    _ = try Skeleton.fromView(try object.View.decode(canonical));
}

test "skeleton component renders muted accent pulse base" {
    var commands: [4]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try (Skeleton{}).render(&scene, ui.Rect.init(8, 12, 120, 20), .{});

    const rect = component_test.lastFillRect(scene.written()).?;
    try std.testing.expectEqual(ui.Rect.init(8, 12, 120, 20), rect);
}
