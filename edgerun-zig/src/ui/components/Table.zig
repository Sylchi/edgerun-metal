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

pub const Table = struct {
    id: u32,
    name: []const u8,
    role: []const u8,

    pub fn node(self: Table) ui.Node {
        return ui.tableNode(self.id, self.name, self.role);
    }

    pub fn render(self: Table, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return component_render.renderTable(scene, bounds, self.name, self.role, options);
    }

    pub fn collectInteractions(self: Table, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(component_render.tableRowBounds(bounds), .row_item, self.id);
    }

    pub fn measure(self: Table, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return component_render.measureFixed(component_render.preferred_table, constraints);
    }

    pub fn toObject(self: Table, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.table, self.id, self.name, self.role, ui_out, object_out, req, epoch);
    }

    pub fn writeRecord(self: Table, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .table, self.id, self.name, self.role);
    }

    pub fn fromView(view: object.View) Error!Table {
        return switch (try component_codec.singleNode(view)) {
            .table => |table| .{ .id = table.id, .name = table.name, .role = table.role },
            else => error.UnsupportedComponent,
        };
    }
};

test "table component serializes to canonical object and deserializes" {
    const table = Table{ .id = 660, .name = "Sarah Chen", .role = "Engineer" };
    var ui_raw: [192]u8 = undefined;
    var object_raw: [object.header_size + 192]u8 = undefined;

    const canonical = table.toObject(&ui_raw, &object_raw, component_test.req(), component_test.epoch()).?;
    const decoded = try Table.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(table.id, decoded.id);
    try std.testing.expectEqualStrings(table.name, decoded.name);
    try std.testing.expectEqualStrings(table.role, decoded.role);
}

test "table component renders header row and hit region" {
    const table = Table{ .id = 660, .name = "Sarah Chen", .role = "Engineer" };
    var commands: [24]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [1]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try table.render(&scene, ui.Rect.init(0, 0, 240, 64), .{});
    try table.collectInteractions(&collector, ui.Rect.init(0, 0, 240, 64));

    try std.testing.expect(component_test.hasText(scene.written(), "Name"));
    try std.testing.expect(component_test.hasText(scene.written(), "Role"));
    try std.testing.expect(component_test.hasText(scene.written(), "Sarah Chen"));
    try std.testing.expect(component_test.hasText(scene.written(), "Engineer"));
    try std.testing.expectEqual(@as(usize, 1), collector.written().len);
    try std.testing.expectEqual(@as(u32, 660), collector.written()[0].id);
}
