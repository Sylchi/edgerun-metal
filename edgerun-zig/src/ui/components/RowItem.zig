const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const component_contract = @import("ComponentContract.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const text_metrics = @import("../../ui_text_metrics.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_primitives = @import("Primitives.zig");
const tokens = @import("../../ui_tokens.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const registration = component_contract.registration("row_item", RowItem);
const measureFixed = component_primitives.measureFixed;

pub const RowItem = struct {
    id: u32,
    title: []const u8,
    detail: []const u8,

    pub fn node(self: RowItem) ui.Node {
        return .{ .row_item = .{ .id = self.id, .title = self.title, .detail = self.detail } };
    }

    pub fn accessibility(self: RowItem) common.Accessibility {
        return .{ .role = .button, .label = self.title, .control_id = self.id };
    }

    pub fn render(self: RowItem, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        try scene.pushRect(bounds, options.style.row, .fill, row_radius, 0.0);
        if (self.detail.len == 0) {
            if (centeredTitleBounds(bounds, self.title)) |title_bounds| {
                try scene.pushWrappedText(title_bounds, self.title, options.style.text, titleWrap(self.title));
            }
            return;
        }
        if (stackedTitleBounds(bounds, self.title)) |title_bounds| {
            try scene.pushWrappedText(title_bounds, self.title, options.style.text, titleWrap(self.title));
        }
        if (detailBounds(bounds, self.title, self.detail)) |detail_bounds| {
            try scene.pushWrappedText(detail_bounds, self.detail, options.style.muted, detailWrap(self.detail));
        }
    }

    pub fn collectInteractions(self: RowItem, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return common.collectHit(collector, bounds, .row_item, self.id);
    }

    pub fn measure(self: RowItem, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        const inner = constraints.inner(.{ .left = row_text_padding_x, .right = row_text_padding_x });
        const title = layout.measureText(self.title, inner, titleMetrics(self.title));
        const detail = if (self.detail.len == 0)
            layout.Measurement.fixed(.{ .w = 0.0, .h = 0.0 })
        else
            layout.measureText(self.detail, inner, detailMetrics(self.detail));
        const gap: f32 = if (self.detail.len == 0) 0.0 else row_text_gap;
        const preferred = component_primitives.constrainPreferredSize(.{
            .w = @max(row_min_width, @max(title.preferred.w, detail.preferred.w) + row_text_padding_x * 2.0),
            .h = row_padding_y * 2.0 + title.preferred.h + gap + detail.preferred.h,
        }, constraints);
        return layout.Measurement.flexible(
            .{ .w = @min(row_min_width, preferred.w), .h = @min(row_min_height, preferred.h) },
            preferred,
            .{ .w = component_primitives.measure_max_width, .h = @max(preferred.h, preferred_row_item.h) },
        ).applyExact(constraints);
    }

    pub fn toObject(self: RowItem, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.row_item, self.id, self.title, self.detail, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: RowItem, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .row_item, self.id, self.title, self.detail);
    }

    pub fn fromView(view: object.View) Error!RowItem {
        const row = try component_codec.nodeView(view, .row_item);
        return fromNode(row);
    }

    pub fn fromNode(row: @FieldType(ui.Node, "row_item")) Error!RowItem {
        return .{ .id = row.id, .title = row.title, .detail = row.detail };
    }
};

fn centeredTitleBounds(bounds: ui.Rect, title: []const u8) ?ui.Rect {
    const text_w = textWidth(bounds);
    const text_h = @min(bounds.h, measuredTextHeight(title, text_w, titleMetrics(title)));
    return textBounds(bounds.withHeightCentered(text_h));
}

fn stackedTitleBounds(bounds: ui.Rect, title: []const u8) ?ui.Rect {
    const text_w = textWidth(bounds);
    const available_h = @max(component_primitives.min_extent, bounds.h - row_padding_y * 2.0);
    const text_h = @min(available_h, measuredTextHeight(title, text_w, titleMetrics(title)));
    return textBounds(ui.Rect.init(bounds.x, bounds.y + row_padding_y, bounds.w, text_h));
}

fn detailBounds(bounds: ui.Rect, title: []const u8, detail: []const u8) ?ui.Rect {
    const text_w = textWidth(bounds);
    const title_h = measuredTextHeight(title, text_w, titleMetrics(title));
    const y = bounds.y + row_padding_y + title_h + row_text_gap;
    const available_h = @max(component_primitives.min_extent, bounds.y + bounds.h - y - row_padding_y);
    const detail_h = @min(available_h, measuredTextHeight(detail, text_w, detailMetrics(detail)));
    return textBounds(ui.Rect.init(bounds.x, y, bounds.w, detail_h));
}

fn textBounds(bounds: ui.Rect) ?ui.Rect {
    const out = bounds.insetLtrb(row_text_padding_x, 0.0, row_text_padding_x, 0.0);
    return if (out.valid()) out else null;
}

fn textWidth(bounds: ui.Rect) f32 {
    return @max(component_primitives.min_extent, bounds.w - row_text_padding_x * 2.0);
}

fn measuredTextHeight(value: []const u8, width: f32, metrics: layout.TextMetrics) f32 {
    return layout.measureText(value, .{ .width = .{ .at_most = width }, .text_wrap = .wrap }, metrics).preferred.h;
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
const row_padding_y: f32 = 8.0;
const row_text_gap: f32 = 2.0;
const row_min_width: f32 = 96.0;
const row_min_height: f32 = 32.0;
const row_title_line_height: f32 = 18.0;
const row_detail_line_height: f32 = 16.0;
const row_text_max_lines: usize = 2;
pub const preferred_row_item = ui.Size{ .w = 260.0, .h = 48.0 };

test "row item component serializes to canonical object and deserializes" {
    const row = RowItem{ .id = 20, .title = "object graph", .detail = "canonical data" };
    var ui_raw: [160]u8 = undefined;
    var object_raw: [object.header_size + 160]u8 = undefined;

    const canonical = row.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try RowItem.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(row.id, decoded.id);
    try std.testing.expectEqualStrings(row.title, decoded.title);
    try std.testing.expectEqualStrings(row.detail, decoded.detail);
}

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

test "row item measurement wraps long content under narrow constraints" {
    const row = RowItem{
        .id = 20,
        .title = "object graph title wraps",
        .detail = "canonical data detail wraps",
    };

    const measured = row.measure(.{ .width = .{ .at_most = row_min_width }, .text_wrap = .wrap }, .{});

    try std.testing.expect(measured.preferred.w <= row_min_width);
    try std.testing.expect(measured.preferred.h > preferred_row_item.h);
}
