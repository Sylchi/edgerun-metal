const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const layout = @import("../../layouts/Types.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const component_render = @import("Render.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const Badge = struct {
    label: []const u8,

    pub fn node(self: Badge) ui.Node {
        return ui.badgeNode(self.label);
    }

    pub fn render(self: Badge, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderBadge(scene, bounds, self.label, options);
    }

    pub fn measure(self: Badge, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return component_render.measureBadge(self.label, constraints);
    }

    pub fn toObject(self: Badge, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return component_codec.oneStringObject(.badge, 0, self.label, ui_out, object_out, req, epoch);
    }

    pub fn writeRecord(self: Badge, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.oneStringRecord(writer, index, .badge, 0, self.label);
    }

    pub fn fromView(view: object.View) Error!Badge {
        return switch (try component_codec.singleNode(view)) {
            .badge => |badge| .{ .label = badge.label },
            else => error.UnsupportedComponent,
        };
    }
};

test "badge component serializes to canonical object and deserializes" {
    const badge = Badge{ .label = "Ready" };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = badge.toObject(&ui_raw, &object_raw, component_test.req(), component_test.epoch()).?;
    const decoded = try Badge.fromView(try object.View.decode(canonical));

    try std.testing.expectEqualStrings("Ready", decoded.label);
}

test "badge component renders reference variants" {
    var commands: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    const badge = Badge{ .label = "Ready" };

    try badge.render(&scene, ui.Rect.init(0, 0, 84, component_render.badge_height), .{ .badge_variant = .destructive });
    try badge.render(&scene, ui.Rect.init(0, 32, 84, component_render.badge_height), .{ .badge_variant = .outline });
    try badge.render(&scene, ui.Rect.init(0, 64, 84, component_render.badge_height), .{ .badge_variant = .link });

    try std.testing.expect(component_test.hasRectColor(scene.written(), ui.Color{ .r = 239, .g = 68, .b = 68, .a = 48 }));
    try std.testing.expect(component_test.hasBorderAt(scene.written(), ui.Rect.init(0, 32, 84, component_render.badge_height)));
    try std.testing.expect(!component_test.hasRectBounds(scene.written(), ui.Rect.init(0, 64, 84, component_render.badge_height)));
    try std.testing.expect(component_test.hasTextColor(scene.written(), ui.Color.accent));
}

test "badge component measurement respects at-most constraints" {
    const badge = Badge{ .label = "Production Ready" };
    const measured = badge.measure(.{ .width = .{ .at_most = 64.0 }, .height = .{ .at_most = 18.0 } }, .{});

    try std.testing.expectEqual(@as(f32, 64.0), measured.preferred.w);
    try std.testing.expectEqual(@as(f32, 18.0), measured.preferred.h);
}
