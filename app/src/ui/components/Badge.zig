const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../component_common.zig");
const layout = @import("../layouts/Types.zig");
const object = @import("../../object.zig");
const ui = @import("../core.zig");
const text_component = @import("Text.zig");
const text_metrics = @import("../text_metrics.zig");
const tokens = @import("../theme.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

const constrainPreferredSize = component_primitives.constrainPreferredSize;

pub const Badge = struct {
    label: []const u8,
    variant: common.BadgeVariant = .default,

    pub fn node(self: Badge) ui.Node {
        return ui.badgeVariantNode(self.label, variantTag(self.variant));
    }

    pub fn render(self: Badge, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const paint = badgePaint(self.variant, options);
        const resolved_height = @min(badge_height, bounds.h);
        const badge_bounds = ui.Rect.init(bounds.x, bounds.y + (bounds.h - resolved_height) * 0.5, bounds.w, resolved_height);
        if (paint.fill.a != 0) try scene.pushRect(badge_bounds, paint.fill, .fill, resolved_height * 0.5, 0.0);
        if (paint.border) |border| try scene.pushRect(badge_bounds, border, .border, resolved_height * 0.5, 0.0);
        try text_component.Text.renderAligned(scene, labelBounds(badge_bounds), self.label, paint.text, .center);
    }

    pub fn measure(self: Badge, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        const preferred_width = @max(badge_min_width, text_metrics.width(self.label, text_metrics.badge_label_px) + badge_padding_x * 2.0);
        const preferred = constrainPreferredSize(.{ .w = preferred_width, .h = badge_height }, constraints);
        return layout.Measurement.flexible(
            .{ .w = @min(badge_min_width, preferred.w), .h = @min(badge_height, preferred.h) },
            preferred,
            .{ .w = component_primitives.maxMeasuredWidth(constraints, preferred.w), .h = badge_height },
        ).applyExact(constraints);
    }

    pub fn toObject(self: Badge, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.singleObjectFromRecord(@TypeOf(self), self, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Badge, writer: *component_codec.Writer, index: usize) bool {
        const label_ref = writer.string(self.label) orelse return false;
        return writer.record(index, .badge, 0, label_ref, .{ .offset = variantTag(self.variant), .len = 0 });
    }

    pub fn fromView(view: object.View) Error!Badge {
        return component_codec.decodeFromView(Badge, .badge, view);
    }

    pub fn fromNode(badge: @FieldType(ui.Node, "badge")) Error!Badge {
        return .{ .label = badge.label, .variant = try variantFromTag(badge.variant) };
    }
};

const BadgePaint = struct {
    fill: ui.Color,
    text: ui.Color,
    border: ?ui.Color = null,
};

fn badgePaint(variant: common.BadgeVariant, options: RenderOptions) BadgePaint {
    return switch (variant) {
        .default => alphaPaint(options.style.accent, options.style.accent),
        .secondary => .{ .fill = options.style.row, .text = options.style.text },
        .destructive => alphaPaint(badge_danger, badge_danger),
        .outline => .{ .fill = ui.Color.clear, .text = options.style.text, .border = options.style.border },
        .ghost => .{ .fill = ui.Color.clear, .text = options.style.muted },
        .link => .{ .fill = ui.Color.clear, .text = options.style.accent },
    };
}

fn alphaPaint(color: ui.Color, text_color: ui.Color) BadgePaint {
    var fill = color;
    fill.a = badge_fill_alpha;
    return .{ .fill = fill, .text = text_color };
}

fn labelBounds(bounds: ui.Rect) ui.Rect {
    const resolved_padding = @min(badge_padding_x, bounds.w * 0.5);
    return ui.Rect.init(bounds.x + resolved_padding, bounds.y + (bounds.h - badge_text_height) * 0.5, @max(component_primitives.min_extent, bounds.w - resolved_padding * 2.0), badge_text_height);
}

pub const badge_height: f32 = tokens.Component.badge_height;
pub const badge_text_height: f32 = tokens.Component.badge_text_height;
pub const badge_padding_x: f32 = tokens.Component.badge_padding_x;
const badge_fill_alpha: u8 = 48;
const badge_min_width: f32 = 28.0;
const badge_danger = ui.Color{ .r = 239, .g = 68, .b = 68 };

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
    try (Badge{ .label = "Ready", .variant = .destructive }).render(&scene, ui.Rect.init(0, 0, 84, badge_height), .{});
    try (Badge{ .label = "Ready", .variant = .outline }).render(&scene, ui.Rect.init(0, 32, 84, badge_height), .{});
    try (Badge{ .label = "Ready", .variant = .link }).render(&scene, ui.Rect.init(0, 64, 84, badge_height), .{});

    try std.testing.expect(component_test.hasRectColor(scene.written(), ui.Color{ .r = 239, .g = 68, .b = 68, .a = 48 }));
    try std.testing.expect(component_test.hasBorderAt(scene.written(), ui.Rect.init(0, 32, 84, badge_height)));
    try std.testing.expect(!component_test.hasRectBounds(scene.written(), ui.Rect.init(0, 64, 84, badge_height)));
    try std.testing.expect(component_test.hasTextColor(scene.written(), ui.Color.accent));
}

test "badge component measurement respects at-most constraints" {
    const badge = Badge{ .label = "Production Ready" };
    const measured = badge.measure(.{ .width = .{ .at_most = 64.0 }, .height = .{ .at_most = 18.0 } }, .{});

    try std.testing.expectEqual(@as(f32, 64.0), measured.preferred.w);
    try std.testing.expectEqual(@as(f32, 18.0), measured.preferred.h);
}
