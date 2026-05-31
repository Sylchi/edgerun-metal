const std = @import("std");
const bytes = @import("../../bytes.zig");
const clock = @import("../../clock.zig");
const common = @import("../component_common.zig");
const object = @import("../../object.zig");
const ui = @import("../core.zig");
const text_component = @import("Text.zig");
const layout = @import("../layouts/Types.zig");
const tokens = @import("../theme.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

const constrainPreferredSize = component_primitives.constrainPreferredSize;

pub const Card = struct {
    title: []const u8,
    detail: []const u8,
    variant: common.SurfaceVariant = .panel,

    pub fn node(self: Card) ui.Node {
        return ui.cardVariantNode(self.title, self.detail, variantTag(self.variant));
    }

    pub fn render(self: Card, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        try renderFrame(scene, bounds, self.variant, options);
        if (self.title.len != 0 or self.detail.len != 0) {
            const content_x = bounds.x + surface_padding;
            const content_w = @max(component_primitives.min_extent, bounds.w - surface_padding * 2.0);
            var cursor_y = bounds.y + surface_padding;
            if (self.title.len != 0) {
                const remaining_h = @max(component_primitives.min_extent, bounds.y + bounds.h - cursor_y - surface_padding);
                const title_h = @min(remaining_h, titleHeightFor(content_w, self.title));
                try text_component.Text.renderWrapped(scene, ui.Rect.init(content_x, cursor_y, content_w, title_h), self.title, options.style.text, .{
                    .line_height = surface_title_height,
                    .average_char_width = surface_title_average_w,
                    .max_lines = surface_title_max_lines,
                });
                cursor_y += title_h;
            }
            if (self.detail.len != 0) {
                if (self.title.len != 0) cursor_y += surface_detail_gap;
                try text_component.Text.renderWrapped(scene, ui.Rect.init(content_x, cursor_y, content_w, @max(component_primitives.min_extent, bounds.y + bounds.h - cursor_y - surface_padding)), self.detail, options.style.muted, .{
                    .line_height = surface_detail_height,
                    .average_char_width = surface_detail_average_w,
                    .max_lines = surface_detail_max_lines,
                });
            }
        }
        try component_primitives.renderControlStateOverlay(scene, bounds, options, radiusFor(self.variant));
    }

    pub fn measure(self: Card, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        const inner = constraints.inner(layout.Insets.uniform(surface_padding));
        const title_measure = if (self.title.len == 0)
            layout.Measurement.fixed(.{ .w = 0.0, .h = 0.0 })
        else
            text_component.Text.measureValue(self.title, inner, .{
                .line_height = surface_title_height,
                .average_char_width = surface_title_average_w,
                .max_lines = surface_title_max_lines,
            });
        const detail_measure = if (self.detail.len == 0)
            layout.Measurement.fixed(.{ .w = 0.0, .h = 0.0 })
        else
            text_component.Text.measureValue(self.detail, inner, .{
                .line_height = surface_detail_height,
                .average_char_width = surface_detail_average_w,
                .max_lines = surface_detail_max_lines,
            });
        const content_width = @max(title_measure.preferred.w, detail_measure.preferred.w);
        const content_gap: f32 = if (self.title.len != 0 and self.detail.len != 0) surface_detail_gap else 0.0;
        const content_height = title_measure.preferred.h + content_gap + detail_measure.preferred.h;
        const preferred = constrainPreferredSize(.{
            .w = content_width + surface_padding * 2.0,
            .h = @max(minHeight(self.title.len != 0, self.detail.len != 0), content_height + surface_padding * 2.0),
        }, constraints);
        return layout.Measurement.flexible(
            .{ .w = @min(surface_min_width, preferred.w), .h = @min(surface_padding * 2.0, preferred.h) },
            preferred,
            component_primitives.maxMeasuredSize(constraints, preferred),
        ).applyExact(constraints);
    }

    pub fn toObject(self: Card, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.singleObjectFromRecord(@TypeOf(self), self, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Card, writer: *component_codec.Writer, index: usize) bool {
        const title_ref = writer.string(self.title) orelse return false;
        const detail_ref = writer.string(self.detail) orelse return false;
        return writer.record(index, .card, variantTag(self.variant), title_ref, detail_ref);
    }

    pub fn fromView(view: object.View) Error!Card {
        return component_codec.decodeFromView(Card, .card, view);
    }

    pub fn fromNode(card: @FieldType(ui.Node, "card")) Error!Card {
        return .{ .title = card.title, .detail = card.detail, .variant = try variantFromTag(card.variant) };
    }
};

fn renderFrame(scene: *ui.Scene, bounds: ui.Rect, variant: common.SurfaceVariant, options: RenderOptions) ui.RenderError!void {
    const frame_radius = radiusFor(variant);
    if (variant == .elevated) {
        try scene.pushRect(bounds.insetUniform(-surface_shadow_inset), surface_shadow, .shadow, frame_radius, surface_shadow_size);
    }
    const fill_color = switch (variant) {
        .panel, .elevated => options.style.panel,
        .subtle => options.style.row,
    };
    try scene.pushGradientRect(bounds, fill_color, card_floor, frame_radius);
    if (variant == .elevated) {
        try scene.pushGradientRect(bounds.insetUniform(1.0), card_highlight, ui.Color.clear, frame_radius);
        try scene.pushRect(bounds.insetLtrb(1.0, 1.0, 1.0, bounds.h - card_rim_height), card_rim, .fill, frame_radius, 0.0);
    }
    try scene.pushRect(bounds, options.style.border, .border, frame_radius, 0.0);
}

fn radiusFor(variant: common.SurfaceVariant) f32 {
    return switch (variant) {
        .panel, .subtle => surface_radius,
        .elevated => surface_radius + surface_elevated_radius_extra,
    };
}

fn minHeight(has_title: bool, has_detail: bool) f32 {
    const content_height = if (has_title and has_detail)
        surface_title_height + surface_detail_gap + surface_detail_height
    else if (has_title)
        surface_title_height
    else if (has_detail)
        surface_detail_height
    else
        0.0;
    return surface_padding * 2.0 + content_height;
}

fn titleHeightFor(width: f32, title: []const u8) f32 {
    if (title.len == 0) return 0.0;
    const capacity = @max(@as(usize, 1), @as(usize, @intFromFloat(@max(1.0, width / surface_title_average_w))));
    var byte_cursor: usize = 0;
    var line_count: usize = 0;
    while (line_count < surface_title_max_lines) : (line_count += 1) {
        byte_cursor = ui.skipAsciiSpace(title, byte_cursor);
        if (byte_cursor >= title.len) break;
        byte_cursor = ui.wrappedLine(title, byte_cursor, capacity).next;
    }
    return @as(f32, @floatFromInt(@max(@as(usize, 1), line_count))) * surface_title_height;
}

pub const surface_padding: f32 = tokens.Component.surface_padding;
pub const surface_title_height: f32 = tokens.Component.surface_title_height;
pub const surface_detail_height: f32 = tokens.Component.surface_detail_height;
pub const surface_detail_gap: f32 = tokens.Component.surface_detail_gap;
pub const surface_radius: f32 = tokens.Component.surface_radius;
const surface_elevated_radius_extra: f32 = 0.0;
const surface_shadow = ui.Color{ .r = 0, .g = 0, .b = 0, .a = 112 };
const surface_shadow_size: f32 = 14.0;
const surface_shadow_inset: f32 = 1.0;
const card_highlight = ui.Color{ .r = 255, .g = 255, .b = 255, .a = 18 };
const card_floor = ui.Color{ .r = 10, .g = 12, .b = 16, .a = 44 };
const card_rim = ui.Color{ .r = 255, .g = 255, .b = 255, .a = 18 };
const card_rim_height: f32 = 1.0;
const surface_title_average_w: f32 = 8.5;
const surface_title_max_lines: usize = 2;
const surface_detail_average_w: f32 = 8.0;
const surface_detail_max_lines: usize = 3;
const surface_min_width: f32 = 160.0;

pub fn variantTag(variant: common.SurfaceVariant) u16 {
    return switch (variant) {
        .panel => 0,
        .elevated => 1,
        .subtle => 2,
    };
}

pub fn variantFromTag(tag: u16) Error!common.SurfaceVariant {
    return switch (tag) {
        0 => .panel,
        1 => .elevated,
        2 => .subtle,
        else => error.Corrupt,
    };
}

test "card component serializes to canonical object and deserializes" {
    const card = Card{ .title = "Project", .detail = "Interactive docs", .variant = .elevated };
    var ui_raw: [160]u8 = undefined;
    var object_raw: [object.header_size + 160]u8 = undefined;

    const canonical = card.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Card.fromView(try object.View.decode(canonical));

    try std.testing.expectEqualStrings(card.title, decoded.title);
    try std.testing.expectEqualStrings(card.detail, decoded.detail);
    try std.testing.expectEqual(common.SurfaceVariant.elevated, decoded.variant);
}

test "card component lays out detail-only content without empty title gap" {
    const card = Card{ .title = "", .detail = "Only detail" };
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try card.render(&scene, ui.Rect.init(0, 0, 220, 80), .{});

    const detail = component_test.textCommandPrefix(scene.written(), "Only").?;
    try std.testing.expectEqual(surface_padding, detail.text.origin.y);
    const measured = card.measure(.{}, .{});
    try std.testing.expectEqual(surface_padding * 2.0 + surface_detail_height, measured.preferred.h);
    try std.testing.expect(measured.preferred.h < (Card{ .title = "Title", .detail = "Only detail" }).measure(.{}, .{}).preferred.h);
}

test "card component renders its own surface variants" {
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try (Card{ .title = "Project", .detail = "Interactive docs", .variant = .elevated }).render(&scene, ui.Rect.init(0, 0, 220, 96), .{});
    try (Card{ .title = "Project", .detail = "Interactive docs", .variant = .subtle }).render(&scene, ui.Rect.init(0, 104, 220, 96), .{});

    try std.testing.expect(component_test.hasShadow(scene.written()));
    try std.testing.expect(component_test.hasRectColor(scene.written(), ui.Color.row));
}

test "card component title can occupy responsive wrapped lines" {
    const card = Card{ .title = "Runtime authority model", .detail = "Receipts stay readable.", .variant = .panel };
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try card.render(&scene, ui.Rect.init(0, 0, 132, 96), .{});

    var title_lines: usize = 0;
    var detail_y: f32 = 0.0;
    for (scene.written()) |command| {
        switch (command) {
            .text => |text| {
                if (bytes.eql(text.value, "Runtime")) title_lines += 1;
                if (bytes.startsWith(text.value, "Receipts")) detail_y = text.origin.y;
            },
            else => {},
        }
    }

    try std.testing.expect(title_lines == 1);
    try std.testing.expect(detail_y > surface_padding + surface_title_height);
}

test "card component measurement respects at-most constraints" {
    const card = Card{ .title = "Project", .detail = "Interactive docs" };
    const measured = card.measure(.{ .width = .{ .at_most = 120.0 }, .height = .{ .at_most = 44.0 } }, .{});

    try std.testing.expectEqual(@as(f32, 120.0), measured.preferred.w);
    try std.testing.expectEqual(@as(f32, 44.0), measured.preferred.h);
}
