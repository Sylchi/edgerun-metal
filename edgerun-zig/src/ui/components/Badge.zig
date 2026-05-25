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
    variant: common.BadgeVariant = .default,

    pub fn node(self: Badge) ui.Node {
        return ui.badgeVariantNode(self.label, variantTag(self.variant));
    }

    pub fn render(self: Badge, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderBadge(scene, bounds, self.label, self.variant, options);
    }

    pub fn measure(self: Badge, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return component_render.measureBadge(self.label, constraints);
    }

    pub fn toObject(self: Badge, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        var writer = component_codec.Writer.init(ui_out, 1, 1, .column, 0, 0) orelse return null;
        if (!self.writeRecord(&writer, 0)) return null;
        return writer.objectNode(object_out, component_codec.requirements(), epoch);
    }

    pub fn writeRecord(self: Badge, writer: *component_codec.Writer, index: usize) bool {
        const label_ref = writer.string(self.label) orelse return false;
        return writer.record(index, .badge, 0, label_ref, .{ .offset = variantTag(self.variant), .len = 0 });
    }

    pub fn fromView(view: object.View) Error!Badge {
        return switch (try component_codec.singleNode(view)) {
            .badge => |badge| .{ .label = badge.label, .variant = try variantFromTag(badge.variant) },
            else => error.UnsupportedComponent,
        };
    }
};

pub fn variantTag(variant: common.BadgeVariant) u16 {
    return switch (variant) {
        .default => 0,
        .secondary => 1,
        .destructive => 2,
        .outline => 3,
        .ghost => 4,
        .link => 5,
    };
}

pub fn variantFromTag(tag: u16) Error!common.BadgeVariant {
    return switch (tag) {
        0 => .default,
        1 => .secondary,
        2 => .destructive,
        3 => .outline,
        4 => .ghost,
        5 => .link,
        else => error.Corrupt,
    };
}

test "badge component serializes to canonical object and deserializes" {
    const badge = Badge{ .label = "Ready", .variant = .outline };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = badge.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Badge.fromView(try object.View.decode(canonical));

    try std.testing.expectEqualStrings("Ready", decoded.label);
    try std.testing.expectEqual(common.BadgeVariant.outline, decoded.variant);
}

test "badge component renders reference variants" {
    var commands: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try (Badge{ .label = "Ready", .variant = .destructive }).render(&scene, ui.Rect.init(0, 0, 84, component_render.badge_height), .{});
    try (Badge{ .label = "Ready", .variant = .outline }).render(&scene, ui.Rect.init(0, 32, 84, component_render.badge_height), .{});
    try (Badge{ .label = "Ready", .variant = .link }).render(&scene, ui.Rect.init(0, 64, 84, component_render.badge_height), .{});

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
