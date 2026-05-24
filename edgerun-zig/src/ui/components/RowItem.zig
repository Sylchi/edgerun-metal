const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const component_render = @import("Render.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;

pub const RowItem = struct {
    id: u32,
    title: []const u8,
    detail: []const u8,

    pub fn node(self: RowItem) ui.Node {
        return .{ .row_item = .{ .id = self.id, .title = self.title, .detail = self.detail } };
    }

    pub fn render(self: RowItem, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderRowItem(scene, bounds, self.title, self.detail, options);
    }

    pub fn collectInteractions(self: RowItem, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return common.collectHit(collector, bounds, .row_item, self.id);
    }

    pub fn measure(self: RowItem, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_row_item, constraints);
    }

    pub fn toObject(self: RowItem, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.row_item, self.id, self.title, self.detail, ui_out, object_out, req, epoch);
    }

    pub fn writeRecord(self: RowItem, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .row_item, self.id, self.title, self.detail);
    }

    pub fn fromView(view: object.View) Error!RowItem {
        return switch (try component_codec.singleNode(view)) {
            .row_item => |row| .{ .id = row.id, .title = row.title, .detail = row.detail },
            else => error.UnsupportedComponent,
        };
    }
};

test "row item component serializes to canonical object and deserializes" {
    const row = RowItem{ .id = 20, .title = "object graph", .detail = "canonical data" };
    var ui_raw: [160]u8 = undefined;
    var object_raw: [object.header_size + 160]u8 = undefined;

    const canonical = row.toObject(&ui_raw, &object_raw, component_test.req(), component_test.epoch()).?;
    const decoded = try RowItem.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(row.id, decoded.id);
    try std.testing.expectEqualStrings(row.title, decoded.title);
    try std.testing.expectEqualStrings(row.detail, decoded.detail);
}
