const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const text_component = @import("Text.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const icon_component = @import("Icon.zig");
const component_primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const registration = .{ .name = "empty", .Payload = Empty };
const constrainPreferredSize = component_primitives.constrainPreferredSize;
const Icon = icon_component.Icon;
const IconSlot = icon_component.IconSlot;

pub const Empty = struct {
    title: []const u8,
    detail: []const u8,
    icon_slot: IconSlot = IconSlot.named(.media, .sparkles),

    pub fn node(self: Empty) ui.Node {
        return ui.emptyNode(self.title, self.detail, self.icon_slot.tag());
    }

    pub fn render(self: Empty, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        try scene.pushRect(bounds, ui.Color.clear, .fill, empty_radius, 0.0);
        try scene.pushRect(bounds, options.style.border, .border, empty_radius, 0.0);
        const media = ui.Rect.init(bounds.x + (bounds.w - empty_media_size) * 0.5, bounds.y + empty_padding, empty_media_size, empty_media_size);
        try scene.pushRect(media, options.style.row, .fill, media.w * 0.5, 0.0);
        try mediaIcon(self).renderColor(scene, media.insetUniform(empty_media_icon_inset), options.style.text);
        const text_w = textWidth(bounds);
        const title_y = media.y + media.h + empty_gap;
        const title_h = component_primitives.measuredTextHeight(self.title, text_w, empty_title_height, empty_title_max_lines);
        try text_component.Text.renderWrapped(scene, ui.Rect.init(bounds.x + empty_padding, title_y, text_w, title_h), self.title, options.style.text, component_primitives.textWrap(self.title, empty_title_height, empty_title_max_lines));
        try text_component.Text.renderWrapped(scene, ui.Rect.init(bounds.x + empty_padding, title_y + title_h + empty_detail_gap, text_w, @max(component_primitives.min_extent, bounds.y + bounds.h - title_y - title_h - empty_detail_gap - empty_padding)), self.detail, options.style.muted, component_primitives.textWrap(self.detail, empty_detail_height, empty_detail_max_lines));
    }

    pub fn measure(self: Empty, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        const inner = constraints.inner(.{ .left = empty_padding, .right = empty_padding });
        const title = layout.measureText(self.title, inner, component_primitives.textMetrics(self.title, empty_title_height, empty_title_max_lines));
        const detail = layout.measureText(self.detail, inner, component_primitives.textMetrics(self.detail, empty_detail_height, empty_detail_max_lines));
        const preferred = constrainPreferredSize(.{
            .w = @max(empty_min_width, @max(empty_media_size, @max(title.preferred.w, detail.preferred.w)) + empty_padding * 2.0),
            .h = empty_padding * 2.0 + empty_media_size + empty_gap + title.preferred.h + empty_detail_gap + detail.preferred.h,
        }, constraints);
        return layout.Measurement.flexible(
            .{ .w = @min(empty_min_width, preferred.w), .h = @min(empty_min_height, preferred.h) },
            preferred,
            .{ .w = component_primitives.measure_max_width, .h = @max(preferred.h, preferred_empty.h) },
        ).applyExact(constraints);
    }

    pub fn toObject(self: Empty, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.empty, self.icon_slot.tag(), self.title, self.detail, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Empty, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .empty, self.icon_slot.tag(), self.title, self.detail);
    }

    pub fn fromView(view: object.View) Error!Empty {
        const empty = try component_codec.nodeView(view, .empty);
        return fromNode(empty);
    }

    pub fn fromNode(empty: @FieldType(ui.Node, "empty")) Error!Empty {
        return .{ .title = empty.title, .detail = empty.detail, .icon_slot = try IconSlot.fromTag(.media, empty.icon) };
    }
};

fn mediaIcon(self: Empty) Icon {
    if (self.icon_slot.optional()) |slot| return slot;
    return Icon.named(.sparkles);
}

fn textWidth(bounds: ui.Rect) f32 {
    return @max(component_primitives.min_extent, bounds.w - empty_padding * 2.0);
}

const empty_radius: f32 = 8.0;
const empty_padding: f32 = 24.0;
const empty_media_size: f32 = 40.0;
const empty_media_icon_inset: f32 = 8.0;
const empty_gap: f32 = 10.0;
const empty_title_height: f32 = 20.0;
const empty_title_max_lines: usize = 2;
const empty_detail_gap: f32 = 4.0;
const empty_detail_height: f32 = 16.0;
const empty_detail_max_lines: usize = 2;
const empty_min_width: f32 = 144.0;
const empty_min_height: f32 = 96.0;
pub const preferred_empty = ui.Size{ .w = 260.0, .h = 132.0 };

test "empty component serializes icon slot to canonical object and deserializes" {
    const empty = Empty{ .title = "No results", .detail = "Try another filter.", .icon_slot = IconSlot.named(.media, .search) };
    var ui_raw: [160]u8 = undefined;
    var object_raw: [object.header_size + 160]u8 = undefined;

    const canonical = empty.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Empty.fromView(try object.View.decode(canonical));

    try std.testing.expectEqualStrings(empty.title, decoded.title);
    try std.testing.expectEqualStrings(empty.detail, decoded.detail);
    try std.testing.expectEqual(Icon.named(.search).value, decoded.icon_slot.media.value);
}

test "empty component renders media title and description" {
    const empty = Empty{ .title = "No results", .detail = "Try another filter." };
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try empty.render(&scene, ui.Rect.init(0, 0, 260, 132), .{});

    try std.testing.expect(component_test.hasText(scene.written(), "No results"));
    try std.testing.expect(component_test.hasText(scene.written(), "Try another filter."));
}

test "empty measurement wraps long copy under narrow constraints" {
    const empty = Empty{
        .title = "No matching runtime objects",
        .detail = "Try another authority filter or inspect the stored receipt list.",
    };

    const measured = empty.measure(.{ .width = .{ .at_most = empty_min_width }, .text_wrap = .wrap }, .{});

    try std.testing.expect(measured.preferred.w <= empty_min_width);
    try std.testing.expect(measured.preferred.h > preferred_empty.h);
}
