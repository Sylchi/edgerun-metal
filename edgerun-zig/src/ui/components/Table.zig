const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");
const primitives = @import("Primitives.zig");

const Error = common.Error;
const RenderOptions = common.RenderOptions;
const measureFixed = primitives.measureFixed;

pub const row_id_offset: u32 = 0;
pub const name_header_id_offset: u32 = 1;
pub const role_header_id_offset: u32 = 2;

pub const Table = struct {
    id: u32,
    name: []const u8,
    role: []const u8,

    pub fn node(self: Table) ui.Node {
        return ui.tableNode(self.id, self.name, self.role);
    }

    pub fn render(self: Table, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        try scene.pushRect(bounds, options.style.panel, .fill, table_radius, 0.0);
        try scene.pushRect(bounds, options.style.border, .border, table_radius, 0.0);
        try renderHeader(scene, bounds, .name, options);
        try renderHeader(scene, bounds, .role, options);
        try scene.pushRect(ui.Rect.init(bounds.x, bounds.y + table_header_h, bounds.w, separator_height), options.style.border, .fill, 0.0, 0.0);
        const row = rowBounds(bounds);
        try scene.pushRect(row.insetUniform(table_row_inset), options.style.row, .fill, table_row_radius, 0.0);
        try scene.pushText(bodyCellBounds(bounds, 0), self.name, options.style.text);
        try scene.pushAlignedText(bodyCellBounds(bounds, 1), self.role, options.style.muted, .end);
    }

    pub fn collectInteractions(self: Table, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(headerBounds(bounds, .name), .button, self.id + name_header_id_offset);
        try collector.addHit(headerBounds(bounds, .role), .button, self.id + role_header_id_offset);
        try collector.addHit(rowBounds(bounds), .row_item, self.id + row_id_offset);
    }

    pub fn measure(self: Table, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = self;
        _ = options;
        return measureFixed(preferred_table, constraints);
    }

    pub fn toObject(self: Table, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.table, self.id, self.name, self.role, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Table, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .table, self.id, self.name, self.role);
    }

    pub fn fromView(view: object.View) Error!Table {
        const table = try component_codec.nodeView(view, .table);
        return .{ .id = table.id, .name = table.name, .role = table.role };
    }
};

fn renderHeader(scene: *ui.Scene, bounds: ui.Rect, column: common.TableColumn, options: RenderOptions) ui.RenderError!void {
    const active = if (options.table_sort) |sort| sort.column == column else false;
    if (active) try scene.pushRect(headerBounds(bounds, column).insetLtrb(table_row_inset, table_row_inset, table_row_inset, table_row_inset), options.style.row, .fill, table_row_radius, 0.0);
    const label = headerLabel(column, options.table_sort);
    const text_color = if (active) options.style.text else options.style.muted;
    switch (column) {
        .name => try scene.pushText(headerBounds(bounds, column), label, text_color),
        .role => try scene.pushAlignedText(headerBounds(bounds, column), label, text_color, .end),
    }
}

fn headerBounds(bounds: ui.Rect, column: common.TableColumn) ui.Rect {
    return cellBounds(bounds, columnIndex(column), table_header_y, table_header_text_h);
}

fn bodyCellBounds(bounds: ui.Rect, column: usize) ui.Rect {
    return cellBounds(bounds, column, table_body_y, table_body_text_h);
}

fn cellBounds(bounds: ui.Rect, column: usize, y_offset: f32, height: f32) ui.Rect {
    const left_w = bounds.w * table_name_column_ratio;
    return switch (column) {
        0 => ui.Rect.init(bounds.x + table_padding_x, bounds.y + y_offset, @max(primitives.min_extent, left_w - table_padding_x), height),
        else => ui.Rect.init(bounds.x + left_w, bounds.y + y_offset, @max(primitives.min_extent, bounds.w - left_w - table_padding_x), height),
    };
}

fn rowBounds(bounds: ui.Rect) ui.Rect {
    return ui.Rect.init(bounds.x, bounds.y + table_header_h + separator_height, bounds.w, @max(primitives.min_extent, bounds.h - table_header_h - separator_height));
}

fn headerLabel(column: common.TableColumn, sort: ?common.TableSort) []const u8 {
    const sorted = if (sort) |value| value.column == column else false;
    return switch (column) {
        .name => if (sorted) sortedLabel(sort.?.direction, table_header_name_asc, table_header_name_desc) else table_header_name,
        .role => if (sorted) sortedLabel(sort.?.direction, table_header_role_asc, table_header_role_desc) else table_header_role,
    };
}

fn sortedLabel(direction: common.SortDirection, asc: []const u8, desc: []const u8) []const u8 {
    return switch (direction) {
        .ascending => asc,
        .descending => desc,
    };
}

fn columnIndex(column: common.TableColumn) usize {
    return switch (column) {
        .name => 0,
        .role => 1,
    };
}

const preferred_table = ui.Size{ .w = 260.0, .h = 64.0 };
const table_radius: f32 = 6.0;
const table_padding_x: f32 = 8.0;
const table_header_h: f32 = 24.0;
const table_header_y: f32 = 5.0;
const table_header_text_h: f32 = 14.0;
const table_body_y: f32 = 35.0;
const table_body_text_h: f32 = 14.0;
const table_name_column_ratio: f32 = 0.55;
const table_row_inset: f32 = 4.0;
const table_row_radius: f32 = 4.0;
const table_header_name = "Name";
const table_header_role = "Role";
const table_header_name_asc = "Name ^";
const table_header_name_desc = "Name v";
const table_header_role_asc = "Role ^";
const table_header_role_desc = "Role v";
const separator_height: f32 = 1.0;

test "table component serializes to canonical object and deserializes" {
    const table = Table{ .id = 660, .name = "Sarah Chen", .role = "Engineer" };
    var ui_raw: [192]u8 = undefined;
    var object_raw: [object.header_size + 192]u8 = undefined;

    const canonical = table.toObject(&ui_raw, &object_raw, component_test.epoch()).?;
    const decoded = try Table.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(table.id, decoded.id);
    try std.testing.expectEqualStrings(table.name, decoded.name);
    try std.testing.expectEqualStrings(table.role, decoded.role);
}

test "table component renders header row and hit region" {
    const table = Table{ .id = 660, .name = "Sarah Chen", .role = "Engineer" };
    var commands: [24]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [3]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try table.render(&scene, ui.Rect.init(0, 0, 240, 64), .{});
    try table.collectInteractions(&collector, ui.Rect.init(0, 0, 240, 64));

    try std.testing.expect(component_test.hasText(scene.written(), "Name"));
    try std.testing.expect(component_test.hasText(scene.written(), "Role"));
    try std.testing.expect(component_test.hasText(scene.written(), "Sarah Chen"));
    try std.testing.expect(component_test.hasText(scene.written(), "Engineer"));
    try std.testing.expectEqual(@as(usize, 3), collector.written().len);
    try std.testing.expectEqual(@as(u32, 660 + name_header_id_offset), collector.written()[0].id);
    try std.testing.expectEqual(@as(u32, 660 + role_header_id_offset), collector.written()[1].id);
    try std.testing.expectEqual(@as(u32, 660 + row_id_offset), collector.written()[2].id);
}

test "table component renders sorted column state without changing row hit" {
    const table = Table{ .id = 660, .name = "Sarah Chen", .role = "Engineer" };
    var commands: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [3]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try table.render(&scene, ui.Rect.init(0, 0, 240, 64), .{
        .table_sort = .{ .column = .role, .direction = .descending },
    });
    try table.collectInteractions(&collector, ui.Rect.init(0, 0, 240, 64));

    try std.testing.expect(component_test.hasText(scene.written(), "Role v"));
    try std.testing.expectEqual(@as(u32, 660 + row_id_offset), collector.written()[2].id);
    try std.testing.expect(collector.written()[0].bounds.x < collector.written()[1].bounds.x);
    try std.testing.expect(collector.written()[2].bounds.y > collector.written()[0].bounds.y);
}
