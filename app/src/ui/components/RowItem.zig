const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../component_common.zig");
const interaction = @import("../interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../core.zig");
const text_component = @import("Text.zig");
const icon_component = @import("Icon.zig");
const layout = @import("../layouts/Types.zig");
const text_metrics = @import("../text_metrics.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_primitives = @import("Primitives.zig");
const tokens = @import("../theme.zig");

const IconSlot = icon_component.IconSlot;

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const RowItem = struct {
    id: u32,
    flags: common.ComponentFlags = .{},
    title: []const u8,
    detail: []const u8,
    leading_icon: IconSlot = .none,

    pub fn node(self: RowItem) ui.Node {
        const icon_tag = self.leading_icon.tag();
        return .{ .row_item = .{
            .id = (self.id << 14) | icon_tag,
            .title = self.title,
            .detail = self.detail,
            .icon = icon_tag,
        } };
    }

    pub fn accessibility(self: RowItem) common.Accessibility {
        return .{ .role = .button, .label = self.title, .control_id = self.id };
    }

    pub fn render(self: RowItem, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        try scene.pushGradientRect(bounds, options.style.row, row_floor, row_radius);
        try scene.pushRect(bounds.insetLtrb(1.0, 1.0, 1.0, bounds.h - row_rim_height), row_rim, .fill, row_radius, 0.0);
        try scene.pushRect(bounds, options.style.border, .border, row_radius, 0.0);
        if (self.leading_icon.optional()) |icon| {
            const chip = ui.Rect.init(bounds.x + row_text_padding_x, bounds.y + (bounds.h - row_icon_chip_size) * 0.5, row_icon_chip_size, row_icon_chip_size);
            try scene.pushRect(chip, row_icon_chip_fill, .fill, row_icon_chip_radius, 0.0);
            try scene.pushRect(chip, options.style.border, .border, row_icon_chip_radius, 0.0);
            try icon.renderColor(scene, chip.withHeightCentered(row_icon_size).withWidthCentered(row_icon_size), options.style.accent);
        }
        if (self.detail.len == 0) {
            if (centeredTitleBounds(bounds, self.title, self)) |title_bounds| {
                try text_component.Text.renderWrapped(scene, title_bounds, self.title, options.style.text, titleWrap(self.title));
            }
            try component_primitives.renderControlStateOverlay(scene, bounds, options, row_radius);
            return;
        }
        if (stackedTitleBounds(bounds, self.title, self)) |title_bounds| {
            try text_component.Text.renderWrapped(scene, title_bounds, self.title, options.style.text, titleWrap(self.title));
        }
        if (detailBounds(bounds, self.title, self.detail, self)) |detail_bounds| {
            try text_component.Text.renderWrapped(scene, detail_bounds, self.detail, options.style.muted, detailWrap(self.detail));
        }
        try component_primitives.renderControlStateOverlay(scene, bounds, options, row_radius);
    }

    pub fn collectInteractions(self: RowItem, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return common.collectHit(collector, bounds, .row_item, self.id);
    }

    pub fn measure(self: RowItem, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        const icon_extra: f32 = if (hasIcon(self)) row_icon_chip_size + row_icon_text_gap else 0.0;
        const inner = constraints.inner(.{ .left = row_text_padding_x + icon_extra, .right = row_text_padding_x });
        const title = text_component.Text.measureValue(self.title, inner, titleMetrics(self.title));
        const detail = if (self.detail.len == 0)
            layout.Measurement.fixed(.{ .w = 0.0, .h = 0.0 })
        else
            text_component.Text.measureValue(self.detail, inner, detailMetrics(self.detail));
        const gap: f32 = if (self.detail.len == 0) 0.0 else row_text_gap;
        const preferred = component_primitives.constrainPreferredSize(.{
            .w = @max(row_min_width, @max(title.preferred.w, detail.preferred.w) + row_text_padding_x * 2.0 + icon_extra),
            .h = @max(row_padding_y * 2.0 + title.preferred.h + gap + detail.preferred.h, row_icon_chip_size + row_padding_y * 2.0),
        }, constraints);
        return layout.Measurement.flexible(
            .{ .w = @min(row_min_width, preferred.w), .h = @min(row_min_height, preferred.h) },
            preferred,
            .{ .w = component_primitives.maxMeasuredWidth(constraints, preferred.w), .h = preferred.h },
        ).applyExact(constraints);
    }

    pub fn toObject(self: RowItem, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        const packed_id = (self.id << 14) | self.leading_icon.tag();
        return component_codec.twoStringObject(.row_item, packed_id, self.title, self.detail, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: RowItem, writer: *component_codec.Writer, index: usize) bool {
        const icon_tag = self.leading_icon.tag();
        const packed_id = (self.id << 14) | icon_tag;
        return component_codec.twoStringRecord(writer, index, .row_item, packed_id, self.title, self.detail);
    }

    pub fn fromView(view: object.View) Error!RowItem {
        return component_codec.decodeFromView(RowItem, .row_item, view);
    }

    pub fn fromNode(row: @FieldType(ui.Node, "row_item")) Error!RowItem {
        return .{ .id = row.id, .title = row.title, .detail = row.detail, .leading_icon = try IconSlot.fromTag(.leading, row.icon) };
    }
};

fn hasIcon(self: RowItem) bool {
    return self.leading_icon.optional() != null;
}

fn centeredTitleBounds(bounds: ui.Rect, title: []const u8, row: RowItem) ?ui.Rect {
    const text_w = textWidth(bounds, hasIcon(row));
    const text_h = @min(bounds.h, measuredTextHeight(title, text_w, titleMetrics(title)));
    return textBounds(bounds.withHeightCentered(text_h), hasIcon(row));
}

fn stackedTitleBounds(bounds: ui.Rect, title: []const u8, row: RowItem) ?ui.Rect {
    const text_w = textWidth(bounds, hasIcon(row));
    const available_h = @max(component_primitives.min_extent, bounds.h - row_padding_y * 2.0);
    const text_h = @min(available_h, measuredTextHeight(title, text_w, titleMetrics(title)));
    return textBounds(ui.Rect.init(bounds.x, bounds.y + row_padding_y, bounds.w, text_h), hasIcon(row));
}

fn detailBounds(bounds: ui.Rect, title: []const u8, detail: []const u8, row: RowItem) ?ui.Rect {
    const text_w = textWidth(bounds, hasIcon(row));
    const title_h = measuredTextHeight(title, text_w, titleMetrics(title));
    const y = bounds.y + row_padding_y + title_h + row_text_gap;
    const available_h = @max(component_primitives.min_extent, bounds.y + bounds.h - y - row_padding_y);
    const detail_h = @min(available_h, measuredTextHeight(detail, text_w, detailMetrics(detail)));
    return textBounds(ui.Rect.init(bounds.x, y, bounds.w, detail_h), hasIcon(row));
}

fn textBounds(bounds: ui.Rect, has_icon: bool) ?ui.Rect {
    const icon_left: f32 = if (has_icon) row_icon_chip_size + row_icon_text_gap else 0.0;
    const out = bounds.insetLtrb(row_text_padding_x + icon_left, 0.0, row_text_padding_x, 0.0);
    return if (out.valid()) out else null;
}

fn textWidth(bounds: ui.Rect, has_icon: bool) f32 {
    const icon_left: f32 = if (has_icon) row_icon_chip_size + row_icon_text_gap else 0.0;
    return @max(component_primitives.min_extent, bounds.w - row_text_padding_x * 2.0 - icon_left);
}

fn measuredTextHeight(value: []const u8, width: f32, metrics: layout.TextMetrics) f32 {
    return text_component.Text.measureValue(value, .{ .width = .{ .at_most = width }, .text_wrap = .wrap }, metrics).preferred.h;
}

fn titleMetrics(value: []const u8) layout.TextMetrics {
    return .{ .line_height = row_title_line_height, .average_char_width = text_metrics.averageWidth(value, row_title_line_height), .max_lines = row_text_max_lines };
}

fn detailMetrics(value: []const u8) layout.TextMetrics {
    return .{ .line_height = row_detail_line_height, .average_char_width = text_metrics.averageWidth(value, row_detail_line_height), .max_lines = row_text_max_lines };
}

fn titleWrap(value: []const u8) ui.TextWrap {
    return .{ .line_height = row_title_line_height, .average_char_width = text_metrics.averageWidth(value, row_title_line_height), .max_lines = row_text_max_lines };
}

fn detailWrap(value: []const u8) ui.TextWrap {
    return .{ .line_height = row_detail_line_height, .average_char_width = text_metrics.averageWidth(value, row_detail_line_height), .max_lines = row_text_max_lines };
}

const row_radius: f32 = tokens.Component.row_radius;
const row_text_padding_x: f32 = 12.0;
const row_padding_y: f32 = 6.0;
const row_text_gap: f32 = 2.0;
const row_min_width: f32 = 96.0;
const row_min_height: f32 = 32.0;
const row_title_line_height: f32 = 15.0;
const row_detail_line_height: f32 = 13.0;
const row_text_max_lines: usize = 1;
const row_icon_size: f32 = 16.0;
const row_icon_chip_size: f32 = 26.0;
const row_icon_chip_radius: f32 = 8.0;
const row_icon_text_gap: f32 = 10.0;
const row_floor = ui.Color{ .r = 6, .g = 9, .b = 12, .a = 18 };
const row_rim = ui.Color{ .r = 255, .g = 255, .b = 255, .a = 6 };
const row_icon_chip_fill = ui.Color{ .r = 13, .g = 19, .b = 23, .a = 186 };
const row_rim_height: f32 = 1.0;

test "row item component renders title and detail through shared row renderer" {
    const row = RowItem{ .id = 20, .title = "object graph", .detail = "canonical data" };
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try row.render(&scene, ui.Rect.init(0, 0, 260, 48), .{});

    const title = component_test.textCommand(scene.written(), "object graph").?;
    const detail = component_test.textCommand(scene.written(), "canonical data").?;
    try std.testing.expectEqual(ui.Color.text, title.text.color);
    try std.testing.expectEqual(ui.Color.muted, detail.text.color);
    try std.testing.expect(detail.text.origin.y > title.text.origin.y);
}

test "row item renders compact data rows as one title line and one detail line" {
    const row = RowItem{ .id = 20, .title = "object graph wraps when allowed", .detail = "canonical data detail wraps when allowed" };
    var commands: [12]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try row.render(&scene, ui.Rect.init(0, 0, 120, 52), .{});

    var text_count: usize = 0;
    for (scene.written()) |command| switch (command) {
        .text => text_count += 1,
        else => {},
    };
    try std.testing.expectEqual(@as(usize, 2), text_count);
}

test "row item measurement keeps data rows compact under narrow constraints" {
    const row = RowItem{
        .id = 20,
        .title = "object graph title wraps",
        .detail = "canonical data detail wraps",
    };
    const compact = RowItem{ .id = 20, .title = "object", .detail = "data" };

    const measured = row.measure(.{ .width = .{ .at_most = row_min_width }, .text_wrap = .wrap }, .{});
    const compact_measured = compact.measure(.{ .width = .{ .at_most = row_min_width }, .text_wrap = .wrap }, .{});

    try std.testing.expect(measured.preferred.w <= row_min_width);
    try std.testing.expectEqual(compact_measured.preferred.h, measured.preferred.h);
}

test "row item with icon serializes icon tag through round-trip" {
    const icon = icon_component.Icon.named(.battery);
    const row = RowItem{ .id = 42, .title = "Power", .detail = "85%", .leading_icon = .{ .leading = icon } };
    var ui_raw: [160]u8 = undefined;
    var object_raw: [object.header_size + 160]u8 = undefined;
    const canonical = row.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try RowItem.fromView(try object.View.decode(canonical));
    try std.testing.expectEqual(row.id, decoded.id);
    try std.testing.expectEqualStrings(row.title, decoded.title);
    try std.testing.expectEqualStrings(row.detail, decoded.detail);
    try std.testing.expectEqual(@as(u16, row.leading_icon.tag()), decoded.leading_icon.tag());
}

test "row item with icon renders icon command" {
    const icon_instance = icon_component.Icon.named(.battery);
    const row = RowItem{ .id = 42, .title = "Power", .detail = "85%", .leading_icon = .{ .leading = icon_instance } };
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try row.render(&scene, ui.Rect.init(0, 0, 260, 48), .{});
    try std.testing.expect(component_test.iconCount(scene.written(), @as(u32, @intCast(icon_instance.tag()))) > 0);
}
