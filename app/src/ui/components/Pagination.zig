const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../component_common.zig");
const interaction = @import("../interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../core.zig");
const layout = @import("../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_primitives = @import("Primitives.zig");
const list_layout = @import("ListLayout.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const Pagination = struct {
    id: u32,
    flags: common.ComponentFlags = .{},
    page: u16 = 0,

    pub fn node(self: Pagination) ui.Node {
        return ui.paginationNode(self.id, self.page);
    }

    pub fn render(self: Pagination, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        const page = selectedPage(self.page);
        for (0..pagination_item_count) |index| {
            const item = itemBounds(bounds, index);
            const active = index == page + 1;
            const label = itemLabel(index);
            try component_primitives.renderTextCell(scene, item, label, if (active) options.style.panel else ui.Color.clear, if (active) options.style.border else ui.Color.clear, component_primitives.control_radius, pagination_text_padding, if (active) options.style.text else options.style.muted);
        }
    }

    pub fn collectInteractions(self: Pagination, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try list_layout.collectEqualSegmentHitsWithGap(collector, bounds, self.id, pagination_item_count, pagination_gap);
    }

    pub fn measure(self: Pagination, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return list_layout.measureSegments(&pagination_labels, constraints, .{
            .item_count = pagination_item_count,
            .gap = pagination_gap,
            .padding = pagination_text_padding,
        });
    }

    pub fn toObject(self: Pagination, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.refObject(.pagination, encodedId(self.id, self.page), .{}, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Pagination, writer: *component_codec.Writer, index: usize) bool {
        return writer.record(index, .pagination, encodedId(self.id, self.page), .{}, .{});
    }

    pub fn fromView(view: object.View) Error!Pagination {
        const pagination = try component_codec.nodeView(view, .pagination);
        return fromNode(pagination);
    }

    pub fn fromNode(pagination: @FieldType(ui.Node, "pagination")) Error!Pagination {
        return .{ .id = pagination.id, .page = selectedPage(pagination.page) };
    }
};

fn selectedPage(page: u16) u16 {
    return list_layout.clampedIndex(page, pagination_page_count);
}

fn encodedId(id: u32, page: u16) u32 {
    return list_layout.encodedIndexedId(id, page, pagination_page_count);
}

const pagination_page_count: u16 = 3;
const pagination_item_count: usize = 5;

fn itemBounds(bounds: ui.Rect, index: usize) ui.Rect {
    return list_layout.equalSegmentBoundsWithGap(bounds, index, pagination_item_count, pagination_gap);
}

fn itemLabel(index: usize) []const u8 {
    return pagination_labels[@min(index, pagination_labels.len - 1)];
}

const pagination_gap: f32 = 4.0;
const pagination_text_padding: f32 = 2.0;
const pagination_labels = [_][]const u8{ "<", "1", "2", "3", ">" };

test "pagination component serializes to canonical object and deserializes" {
    const pagination = Pagination{ .id = 120, .page = 2 };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = pagination.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Pagination.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(pagination.id, decoded.id);
    try std.testing.expectEqual(@as(u16, 2), decoded.page);
}

test "pagination component renders pages and hit regions" {
    const pagination = Pagination{ .id = 120, .page = 1 };
    var commands: [24]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [5]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try pagination.render(&scene, ui.Rect.init(0, 0, 240, 36), .{});
    try pagination.collectInteractions(&collector, ui.Rect.init(0, 0, 240, 36));

    try std.testing.expect(component_test.hasText(scene.written(), "1"));
    try std.testing.expect(component_test.hasText(scene.written(), "2"));
    try std.testing.expect(component_test.hasText(scene.written(), "3"));
    try std.testing.expectEqual(@as(usize, 5), collector.written().len);
    try std.testing.expectEqual(@as(u32, 124), collector.written()[4].id);
}

test "pagination measurement follows labels and shared segment layout" {
    const pagination = Pagination{ .id = 120, .page = 1 };
    const measured = pagination.measure(.{}, .{});

    try std.testing.expect(measured.min.w < measured.preferred.w);
    try std.testing.expect(measured.preferred.h >= component_primitives.control_label_height);
}
