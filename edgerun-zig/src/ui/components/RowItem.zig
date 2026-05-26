const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_primitives = @import("Primitives.zig");
const tokens = @import("../../ui_tokens.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;
const measureFixed = component_primitives.measureFixed;

pub const RowItem = struct {
    id: u32,
    title: []const u8,
    detail: []const u8,

    pub fn node(self: RowItem) ui.Node {
        return .{ .row_item = .{ .id = self.id, .title = self.title, .detail = self.detail } };
    }

    pub fn render(self: RowItem, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        try scene.pushRect(bounds, options.style.row, .fill, row_radius, 0.0);
        if (titleBounds(bounds, self.detail.len == 0)) |title_bounds| {
            try scene.pushText(title_bounds, self.title, options.style.text);
        }
        if (self.detail.len != 0) {
            if (detailBounds(bounds)) |detail_bounds| {
                try scene.pushText(detail_bounds, self.detail, options.style.muted);
            }
        }
    }

    pub fn collectInteractions(self: RowItem, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return common.collectHit(collector, bounds, .row_item, self.id);
    }

    pub fn measure(self: RowItem, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_row_item, constraints);
    }

    pub fn toObject(self: RowItem, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.row_item, self.id, self.title, self.detail, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: RowItem, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .row_item, self.id, self.title, self.detail);
    }

    pub fn fromView(view: object.View) Error!RowItem {
        const row = try component_codec.nodeView(view, .row_item);
        return .{ .id = row.id, .title = row.title, .detail = row.detail };
    }
};

fn titleBounds(bounds: ui.Rect, centered: bool) ?ui.Rect {
    const row_bounds = if (centered) bounds.withHeightCentered(row_title_height) else ui.Rect.init(bounds.x, bounds.y + row_title_offset_y, bounds.w, row_title_height);
    return textBounds(row_bounds);
}

fn detailBounds(bounds: ui.Rect) ?ui.Rect {
    return textBounds(ui.Rect.init(bounds.x, bounds.y + row_detail_offset_y, bounds.w, row_detail_height));
}

fn textBounds(bounds: ui.Rect) ?ui.Rect {
    const out = bounds.insetLtrb(row_text_padding_x, 0.0, row_text_padding_x, 0.0);
    return if (out.valid()) out else null;
}

const row_radius: f32 = tokens.Component.row_radius;
const row_text_padding_x: f32 = 12.0;
const row_title_offset_y: f32 = 8.0;
const row_detail_offset_y: f32 = 26.0;
const row_title_height: f32 = 18.0;
const row_detail_height: f32 = 16.0;
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
