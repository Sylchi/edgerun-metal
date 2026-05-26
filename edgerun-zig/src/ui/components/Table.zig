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
const constrainPreferredSize = primitives.constrainPreferredSize;

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

    pub fn accessibility(self: Table) common.Accessibility {
        return .{ .role = .table, .label = self.name, .control_id = self.id };
    }

    pub fn render(self: Table, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        try scene.pushRect(bounds, options.style.panel, .fill, table_radius, 0.0);
        try scene.pushRect(bounds, options.style.border, .border, table_radius, 0.0);
        try renderHeader(scene, bounds, .name, options);
        try renderHeader(scene, bounds, .role, options);
        try scene.pushRect(ui.Rect.init(bounds.x, bounds.y + table_header_h, bounds.w, separator_height), options.style.border, .fill, 0.0, 0.0);
        const row = rowBounds(bounds);
        try scene.pushRect(row.insetUniform(table_row_inset), options.style.row, .fill, table_row_radius, 0.0);
        try scene.pushWrappedText(bodyCellBounds(bounds, 0, self.name), self.name, options.style.text, primitives.textWrap(self.name, table_body_text_h, table_body_max_lines));
        try scene.pushWrappedText(bodyCellBounds(bounds, 1, self.role), self.role, options.style.muted, primitives.textWrap(self.role, table_body_text_h, table_body_max_lines));
    }

    pub fn collectInteractions(self: Table, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        try collector.addHit(headerBounds(bounds, .name, table_header_name), .button, self.id + name_header_id_offset);
        try collector.addHit(headerBounds(bounds, .role, table_header_role), .button, self.id + role_header_id_offset);
        try collector.addHit(rowBounds(bounds), .row_item, self.id + row_id_offset);
    }

    pub fn measure(self: Table, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        const width = constraints.width.limit(preferred_table.w);
        const name_w = @max(primitives.min_extent, width * table_name_column_ratio - table_padding_x);
        const role_w = @max(primitives.min_extent, width * (1.0 - table_name_column_ratio) - table_padding_x);
        const name = layout.measureText(self.name, .{ .width = .{ .at_most = name_w }, .text_wrap = .wrap }, primitives.textMetrics(self.name, table_body_text_h, table_body_max_lines));
        const role = layout.measureText(self.role, .{ .width = .{ .at_most = role_w }, .text_wrap = .wrap }, primitives.textMetrics(self.role, table_body_text_h, table_body_max_lines));
        const row_h = @max(table_body_text_h, @max(name.preferred.h, role.preferred.h)) + table_row_inset * 2.0;
        const preferred = constrainPreferredSize(.{
            .w = @max(table_min_width, @max(name.preferred.w + role.preferred.w + table_padding_x * 2.0, preferred_table.w)),
            .h = table_header_h + separator_height + row_h,
        }, constraints);
        return layout.Measurement.flexible(
            .{ .w = @min(table_min_width, preferred.w), .h = @min(table_min_height, preferred.h) },
            preferred,
            .{ .w = primitives.measure_max_width, .h = @max(preferred.h, preferred_table.h) },
        ).applyExact(constraints);
    }

    pub fn toObject(self: Table, ui_out: []u8, object_out: []u8, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.table, self.id, self.name, self.role, ui_out, object_out, epoch);
    }

    pub fn writeRecord(self: Table, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .table, self.id, self.name, self.role);
    }

    pub fn fromView(view: object.View) Error!Table {
        const table = try component_codec.nodeView(view, .table);
        return fromNode(table);
    }

    pub fn fromNode(table: @FieldType(ui.Node, "table")) Error!Table {
        return .{ .id = table.id, .name = table.name, .role = table.role };
    }
};

fn renderHeader(scene: *ui.Scene, bounds: ui.Rect, column: common.TableColumn, options: RenderOptions) ui.RenderError!void {
    const active = if (options.table_sort) |sort| sort.column == column else false;
    const label = headerLabel(column, options.table_sort);
    if (active) try scene.pushRect(headerBounds(bounds, column, label).insetLtrb(table_row_inset, table_row_inset, table_row_inset, table_row_inset), options.style.row, .fill, table_row_radius, 0.0);
    const text_color = if (active) options.style.text else options.style.muted;
    switch (column) {
        .name => try scene.pushWrappedText(headerBounds(bounds, column, label), label, text_color, primitives.textWrap(label, table_header_text_h, table_header_max_lines)),
        .role => try scene.pushWrappedText(headerBounds(bounds, column, label), label, text_color, primitives.textWrap(label, table_header_text_h, table_header_max_lines)),
    }
}

fn headerBounds(bounds: ui.Rect, column: common.TableColumn, label: []const u8) ui.Rect {
    return cellBounds(bounds, columnIndex(column), table_header_y, textHeight(bounds, columnIndex(column), label, table_header_text_h, table_header_max_lines));
}

fn bodyCellBounds(bounds: ui.Rect, column: usize, value: []const u8) ui.Rect {
    return cellBounds(bounds, column, table_body_y, textHeight(bounds, column, value, table_body_text_h, table_body_max_lines));
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

fn textHeight(bounds: ui.Rect, column: usize, value: []const u8, line_height: f32, max_lines: usize) f32 {
    const text_bounds = cellBounds(bounds, column, 0.0, line_height);
    return @min(bounds.h, primitives.measuredTextHeight(value, text_bounds.w, line_height, max_lines));
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
const table_header_max_lines: usize = 1;
const table_body_y: f32 = 35.0;
const table_body_text_h: f32 = 14.0;
const table_body_max_lines: usize = 2;
const table_name_column_ratio: f32 = 0.55;
const table_row_inset: f32 = 4.0;
const table_row_radius: f32 = 4.0;
const table_min_width: f32 = 160.0;
const table_min_height: f32 = 48.0;
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

test "table component measurement wraps long row cells under narrow constraints" {
    const short = Table{ .id = 660, .name = "Sarah Chen", .role = "Engineer" };
    const table = Table{ .id = 660, .name = "Sarah Chen Runtime Operator", .role = "Principal Engineer" };

    const short_measured = short.measure(.{ .width = .{ .at_most = table_min_width }, .text_wrap = .wrap }, .{});
    const measured = table.measure(.{ .width = .{ .at_most = table_min_width }, .text_wrap = .wrap }, .{});

    try std.testing.expect(measured.preferred.w <= table_min_width);
    try std.testing.expect(measured.preferred.h > short_measured.preferred.h);
}
