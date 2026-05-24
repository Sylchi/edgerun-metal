const std = @import("std");
const common = @import("../../ui_component_common.zig");
const ui = @import("../../ui.zig");
const ui_input = @import("../../input.zig");

const HtmlCursor = common.HtmlCursor;
const HtmlError = common.HtmlError;
const HtmlTextArena = common.HtmlTextArena;
const HtmlWriter = common.HtmlWriter;
const ComponentRegistry = common.ComponentRegistry;
const MarkdownError = common.MarkdownError;
const MarkdownTextArena = common.MarkdownTextArena;
const MarkdownWriter = common.MarkdownWriter;
const RegistryError = common.RegistryError;
const RenderOptions = common.RenderOptions;

pub const TableCell = struct {
    value: []const u8,
    alignment: ui.TextAlign = .start,
};

pub const TableRow = struct {
    id: u32,
    cells: []const TableCell,
};

pub const Table = struct {
    id: u32,
    headers: []const TableCell,
    rows: []const TableRow,

    pub fn render(self: Table, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return renderTable(self, scene, bounds, options);
    }

    pub fn toHtml(self: Table, out: []u8) HtmlError![]u8 {
        return writeHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, out_rows: []TableRow, out_cells: []TableCell, text_out: []u8) HtmlError!Table {
        return readHtml(html, out_rows, out_cells, text_out);
    }

    pub fn toMarkdown(self: Table, out: []u8) MarkdownError![]u8 {
        return writeMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, out_rows: []TableRow, out_cells: []TableCell, text_out: []u8) MarkdownError!Table {
        return readMarkdown(markdown, out_rows, out_cells, text_out);
    }

    pub fn register(registry: *ComponentRegistry) RegistryError!void {
        return registry.register(descriptor);
    }
};

pub const descriptor = common.ComponentDescriptor{
    .name = "table",
    .html_prefix = "<table data-er-component=\"table\"",
    .markdown_prefix = ":::table",
    .render = renderRegistered,
    .write_html = writeHtmlRegistered,
    .write_markdown = writeMarkdownRegistered,
};

pub fn register(registry: *ComponentRegistry) RegistryError!void {
    return Table.register(registry);
}

pub fn renderTable(table: Table, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    if (table.headers.len == 0) return;
    const style = options.style;
    try scene.pushRect(bounds, style.panel, .fill, table_radius, 0.0);
    try scene.pushRect(bounds, style.border, .border, table_radius, 0.0);

    const column_count = table.headers.len;
    const column_w = @max(1.0, (bounds.w - table_padding_x * 2.0) / @as(f32, @floatFromInt(column_count)));
    const header_y = bounds.y + table_padding_y;
    for (table.headers, 0..) |header, index| {
        const cell_bounds = tableCellBounds(bounds, column_w, header_y, index);
        try scene.pushAlignedText(cell_bounds, header.value, style.muted, header.alignment);
    }

    var y = header_y + table_header_h + table_row_gap;
    for (table.rows) |row| {
        if (row.cells.len != column_count) continue;
        if (y + table_row_h > bounds.y + bounds.h - table_padding_y) break;
        const row_bounds = ui.Rect.init(bounds.x + table_row_inset, y, @max(1.0, bounds.w - table_row_inset * 2.0), table_row_h);
        try scene.pushRect(row_bounds, style.row, .fill, table_row_radius, 0.0);
        for (row.cells, 0..) |cell, index| {
            const cell_bounds = tableCellBounds(bounds, column_w, y + table_text_y, index);
            try scene.pushAlignedText(cell_bounds, cell.value, style.text, cell.alignment);
        }
        try scene.pushHit(.{ .slot = 0, .kind = .row_item, .id = row.id, .bounds = row_bounds });
        y += table_row_h + table_row_gap;
    }
}

fn renderRegistered(component: *const anyopaque, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    const table: *const Table = @ptrCast(@alignCast(component));
    return renderTable(table.*, scene, bounds, options);
}

pub fn writeHtml(table: Table, out: []u8) HtmlError![]u8 {
    if (table.headers.len == 0) return error.InvalidHtml;
    var writer = HtmlWriter.init(out);
    try writer.writeAll("<table data-er-component=\"table\"");
    try writer.writeAttrInt("data-er-id", table.id);
    try writer.writeAll("><thead><tr>");
    for (table.headers) |header| {
        try writer.writeAll("<th");
        try writer.writeAttrRaw("data-er-align", common.alignName(header.alignment));
        try writer.writeByte('>');
        try writer.writeEscapedText(header.value);
        try writer.writeAll("</th>");
    }
    try writer.writeAll("</tr></thead><tbody>");
    for (table.rows) |row| {
        if (row.cells.len != table.headers.len) return error.InvalidHtml;
        try writer.writeAll("<tr");
        try writer.writeAttrInt("data-er-row-id", row.id);
        try writer.writeByte('>');
        for (row.cells) |cell| {
            try writer.writeAll("<td");
            try writer.writeAttrRaw("data-er-align", common.alignName(cell.alignment));
            try writer.writeByte('>');
            try writer.writeEscapedText(cell.value);
            try writer.writeAll("</td>");
        }
        try writer.writeAll("</tr>");
    }
    try writer.writeAll("</tbody></table>");
    return writer.written();
}

fn writeHtmlRegistered(component: *const anyopaque, out: []u8) HtmlError![]u8 {
    const table: *const Table = @ptrCast(@alignCast(component));
    return writeHtml(table.*, out);
}

pub fn writeMarkdown(table: Table, out: []u8) MarkdownError![]u8 {
    if (table.headers.len == 0) return error.InvalidMarkdown;
    var writer = MarkdownWriter.init(out);
    try writer.beginDirective("table");
    try writer.fieldInt("id", table.id);
    for (table.headers) |header| {
        if (header.value.len == 0) return error.InvalidMarkdown;
        try writer.fieldPrefix("header");
        try writer.writeAll(common.alignName(header.alignment));
        try writer.writeAll(" ");
        try writer.writeEscapedInline(header.value);
    }
    for (table.rows) |row| {
        if (row.cells.len != table.headers.len) return error.InvalidMarkdown;
        try writer.fieldInt("row", row.id);
        for (row.cells) |cell| {
            try writer.fieldPrefix("cell");
            try writer.writeAll(common.alignName(cell.alignment));
            try writer.writeAll(" ");
            try writer.writeEscapedInline(cell.value);
        }
    }
    try writer.endDirective();
    return writer.written();
}

fn writeMarkdownRegistered(component: *const anyopaque, out: []u8) MarkdownError![]u8 {
    const table: *const Table = @ptrCast(@alignCast(component));
    return writeMarkdown(table.*, out);
}

pub fn readMarkdown(markdown: []const u8, out_rows: []TableRow, out_cells: []TableCell, text_out: []u8) MarkdownError!Table {
    const prefix = ":::table\nid: ";
    const body = try common.readMarkdownDirectiveBody(markdown, ":::table", prefix);
    const id_end_relative = std.mem.indexOfScalar(u8, body, '\n') orelse return error.InvalidMarkdown;
    const id = try common.parseMarkdownU32(body[0..id_end_relative]);
    var text = MarkdownTextArena.init(text_out);
    var cell_count: usize = 0;
    var row_count: usize = 0;
    var cursor = id_end_relative + 1;
    while (cursor < body.len and std.mem.startsWith(u8, body[cursor..], "header: ")) {
        if (cell_count == out_cells.len) return error.MarkdownBudgetExceeded;
        const line_end_relative = std.mem.indexOfScalar(u8, body[cursor..], '\n') orelse body[cursor..].len;
        out_cells[cell_count] = try readMarkdownCellLine(body[cursor .. cursor + line_end_relative], "header: ", &text);
        if (out_cells[cell_count].value.len == 0) return error.InvalidMarkdown;
        cell_count += 1;
        cursor += line_end_relative;
        if (cursor < body.len) cursor += 1;
    }
    const header_count = cell_count;
    if (header_count == 0) return error.InvalidMarkdown;
    while (cursor < body.len) {
        if (row_count == out_rows.len) return error.MarkdownBudgetExceeded;
        if (!std.mem.startsWith(u8, body[cursor..], "row: ")) return error.InvalidMarkdown;
        const row_id_start = cursor + "row: ".len;
        const row_id_end_relative = std.mem.indexOfScalar(u8, body[row_id_start..], '\n') orelse return error.InvalidMarkdown;
        const row_id = try common.parseMarkdownU32(body[row_id_start .. row_id_start + row_id_end_relative]);
        cursor = row_id_start + row_id_end_relative + 1;
        const row_cells_start = cell_count;
        var row_cell_index: usize = 0;
        while (row_cell_index < header_count) : (row_cell_index += 1) {
            if (cell_count == out_cells.len) return error.MarkdownBudgetExceeded;
            if (!std.mem.startsWith(u8, body[cursor..], "cell: ")) return error.InvalidMarkdown;
            const line_end_relative = std.mem.indexOfScalar(u8, body[cursor..], '\n') orelse body[cursor..].len;
            out_cells[cell_count] = try readMarkdownCellLine(body[cursor .. cursor + line_end_relative], "cell: ", &text);
            cell_count += 1;
            cursor += line_end_relative;
            if (cursor < body.len) cursor += 1;
        }
        out_rows[row_count] = .{ .id = row_id, .cells = out_cells[row_cells_start..cell_count] };
        row_count += 1;
    }
    if (row_count == 0) return error.InvalidMarkdown;
    return .{ .id = id, .headers = out_cells[0..header_count], .rows = out_rows[0..row_count] };
}

pub fn readHtml(html: []const u8, out_rows: []TableRow, out_cells: []TableCell, text_out: []u8) HtmlError!Table {
    const prefix = "<table data-er-component=\"table\" data-er-id=\"";
    if (!std.mem.startsWith(u8, html, prefix)) return error.UnsupportedHtml;
    const after_id = html[prefix.len..];
    const id_end = std.mem.indexOf(u8, after_id, "\"><thead><tr>") orelse return error.InvalidHtml;
    const id = try common.parseHtmlU32(after_id[0..id_end]);
    const headers_start = prefix.len + id_end + "\"><thead><tr>".len;
    const headers_end_relative = std.mem.indexOf(u8, html[headers_start..], "</tr></thead><tbody>") orelse return error.InvalidHtml;
    const headers_html = html[headers_start .. headers_start + headers_end_relative];
    const rows_start = headers_start + headers_end_relative + "</tr></thead><tbody>".len;
    if (!std.mem.endsWith(u8, html, "</tbody></table>")) return error.InvalidHtml;
    const rows_html = html[rows_start .. html.len - "</tbody></table>".len];

    var text = HtmlTextArena.init(text_out);
    var cell_count: usize = 0;
    const headers = try readHtmlCells(headers_html, "th", out_cells, &cell_count, &text);
    if (headers.len == 0) return error.InvalidHtml;
    const rows = try readHtmlRows(rows_html, headers.len, out_rows, out_cells, &cell_count, &text);
    return .{ .id = id, .headers = headers, .rows = rows };
}

fn readMarkdownCellLine(line: []const u8, prefix: []const u8, text: *MarkdownTextArena) MarkdownError!TableCell {
    if (!std.mem.startsWith(u8, line, prefix)) return error.InvalidMarkdown;
    const after_prefix = line[prefix.len..];
    const align_end = std.mem.indexOfScalar(u8, after_prefix, ' ') orelse return error.InvalidMarkdown;
    const alignment = common.parseAlignName(after_prefix[0..align_end]) orelse return error.InvalidMarkdown;
    const value = try text.unescapeInline(after_prefix[align_end + 1 ..]);
    return .{ .value = value, .alignment = alignment };
}

fn readHtmlRows(html: []const u8, column_count: usize, out_rows: []TableRow, out_cells: []TableCell, cell_count: *usize, text: *HtmlTextArena) HtmlError![]const TableRow {
    var cursor = HtmlCursor.init(html);
    var row_count: usize = 0;
    while (!cursor.done()) {
        if (row_count == out_rows.len) return error.HtmlBudgetExceeded;
        const id = try common.parseHtmlU32(try cursor.fieldBetween("<tr data-er-row-id=\"", "\">"));
        const cells_html = try cursor.fieldBetween("\">", "</tr>");
        const cells = try readHtmlCells(cells_html, "td", out_cells, cell_count, text);
        try cursor.consume("</tr>");
        if (cells.len != column_count) return error.InvalidHtml;
        out_rows[row_count] = .{ .id = id, .cells = cells };
        row_count += 1;
    }
    return out_rows[0..row_count];
}

fn readHtmlCells(html: []const u8, comptime tag: []const u8, out_cells: []TableCell, cell_count: *usize, text: *HtmlTextArena) HtmlError![]const TableCell {
    const start = cell_count.*;
    var cursor = HtmlCursor.init(html);
    while (!cursor.done()) {
        if (cell_count.* == out_cells.len) return error.HtmlBudgetExceeded;
        const prefix = "<" ++ tag ++ " data-er-align=\"";
        const close = "</" ++ tag ++ ">";
        const alignment = common.parseAlignName(try cursor.fieldBetween(prefix, "\">")) orelse return error.InvalidHtml;
        out_cells[cell_count.*] = .{
            .value = try text.unescape(try cursor.fieldBetween("\">", close)),
            .alignment = alignment,
        };
        try cursor.consume(close);
        cell_count.* += 1;
    }
    return out_cells[start..cell_count.*];
}

fn tableCellBounds(bounds: ui.Rect, column_w: f32, y: f32, index: usize) ui.Rect {
    return ui.Rect.init(bounds.x + table_padding_x + column_w * @as(f32, @floatFromInt(index)), y, @max(1.0, column_w - table_column_gap), table_text_h);
}

const table_radius: f32 = 8.0;
const table_row_radius: f32 = 6.0;
const table_padding_x: f32 = 14.0;
const table_padding_y: f32 = 14.0;
const table_header_h: f32 = 18.0;
const table_row_h: f32 = 38.0;
const table_row_gap: f32 = 6.0;
const table_row_inset: f32 = 8.0;
const table_text_y: f32 = 12.0;
const table_text_h: f32 = 14.0;
const table_column_gap: f32 = 10.0;

test "table component renders rows and right aligned numeric cells" {
    const headers = [_]TableCell{
        .{ .value = "Item" },
        .{ .value = "Amount", .alignment = .end },
    };
    const row0 = [_]TableCell{
        .{ .value = "Net Royalties" },
        .{ .value = "$0.00", .alignment = .end },
    };
    const row1 = [_]TableCell{
        .{ .value = "Processing Fee" },
        .{ .value = "-$0.00", .alignment = .end },
    };
    const rows = [_]TableRow{
        .{ .id = 701, .cells = &row0 },
        .{ .id = 702, .cells = &row1 },
    };
    const table = Table{ .id = 7, .headers = &headers, .rows = &rows };
    var commands: [64]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try table.render(&scene, ui.Rect.init(0, 0, 360, 160), .{});

    try std.testing.expectEqual(ui.TextAlign.end, textCommand(scene.written(), "Amount").?.text.alignment);
    try std.testing.expectEqual(ui.TextAlign.end, textCommand(scene.written(), "$0.00").?.text.alignment);
    const hit = ui_input.hitTest(scene.written(), 20, 58).?;
    try std.testing.expectEqual(@as(u32, 701), hit.id);
}

test "table html codec roundtrips semantic table" {
    const headers = [_]TableCell{
        .{ .value = "Layer" },
        .{ .value = "Authority" },
    };
    const row0 = [_]TableCell{
        .{ .value = "Browser" },
        .{ .value = "host IO" },
    };
    const row1 = [_]TableCell{
        .{ .value = "WASM app" },
        .{ .value = "routing and render policy" },
    };
    const rows = [_]TableRow{
        .{ .id = 81, .cells = &row0 },
        .{ .id = 82, .cells = &row1 },
    };
    const table = Table{ .id = 8, .headers = &headers, .rows = &rows };
    var html: [1024]u8 = undefined;
    var decoded_rows: [2]TableRow = undefined;
    var decoded_cells: [6]TableCell = undefined;
    var text: [256]u8 = undefined;

    const encoded = try table.toHtml(&html);
    const decoded = try Table.fromHtml(encoded, &decoded_rows, &decoded_cells, &text);

    try std.testing.expect(std.mem.indexOf(u8, encoded, "<table data-er-component=\"table\" data-er-id=\"8\">") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded, "<th data-er-align=\"start\">Layer</th>") != null);
    try std.testing.expectEqual(@as(u32, 8), decoded.id);
    try std.testing.expectEqual(@as(usize, 2), decoded.headers.len);
    try std.testing.expectEqual(@as(usize, 2), decoded.rows.len);
    try std.testing.expectEqualStrings("Layer", decoded.headers[0].value);
    try std.testing.expectEqualStrings("WASM app", decoded.rows[1].cells[0].value);
    try std.testing.expectEqualStrings("routing and render policy", decoded.rows[1].cells[1].value);
}

test "table html codec rejects malformed tables" {
    var rows: [2]TableRow = undefined;
    var cells: [4]TableCell = undefined;
    var text: [128]u8 = undefined;

    try std.testing.expectError(error.UnsupportedHtml, Table.fromHtml("<table><tr><td>plain</td></tr></table>", &rows, &cells, &text));
    try std.testing.expectError(error.InvalidHtml, Table.fromHtml("<table data-er-component=\"table\" data-er-id=\"x\"><thead><tr></tr></thead><tbody></tbody></table>", &rows, &cells, &text));
    try std.testing.expectError(error.InvalidHtml, Table.fromHtml("<table data-er-component=\"table\" data-er-id=\"1\"><thead><tr><th data-er-align=\"left\">A</th></tr></thead><tbody></tbody></table>", &rows, &cells, &text));
}

test "table registers explicit runtime descriptor" {
    const headers = [_]TableCell{.{ .value = "Layer" }};
    const cells = [_]TableCell{.{ .value = "WASM" }};
    const rows = [_]TableRow{.{ .id = 91, .cells = &cells }};
    const table = Table{ .id = 9, .headers = &headers, .rows = &rows };
    var entries: [1]common.ComponentDescriptor = undefined;
    var registry = ComponentRegistry.init(&entries);
    var html: [512]u8 = undefined;
    var markdown: [512]u8 = undefined;
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try Table.register(&registry);
    try std.testing.expectError(error.DuplicateComponent, Table.register(&registry));
    try std.testing.expectEqualStrings("table", registry.matchHtml("<table data-er-component=\"table\" data-er-id=\"9\"></table>").?.name);
    try std.testing.expectEqualStrings("table", registry.matchMarkdown(":::table\nid: 9\n:::").?.name);

    const encoded_html = try registry.writeHtml("table", &table, &html);
    const encoded_markdown = try registry.writeMarkdown("table", &table, &markdown);
    try registry.render("table", &table, &scene, ui.Rect.init(0, 0, 240, 100), .{});

    try std.testing.expect(std.mem.indexOf(u8, encoded_html, "<table data-er-component=\"table\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded_markdown, ":::table") != null);
    try std.testing.expect(textCommand(scene.written(), "WASM") != null);
}

test "table registry descriptor can be updated at runtime" {
    var entries: [1]common.ComponentDescriptor = undefined;
    var registry = ComponentRegistry.init(&entries);
    var updated = descriptor;
    updated.html_prefix = "<table data-er-component=\"table-v2\"";

    try Table.register(&registry);
    try registry.update(updated);

    try std.testing.expect(registry.matchHtml("<table data-er-component=\"table\" data-er-id=\"1\"></table>") == null);
    try std.testing.expectEqualStrings("table", registry.matchHtml("<table data-er-component=\"table-v2\" data-er-id=\"1\"></table>").?.name);
}

fn textCommand(commands: []const ui.Command, value: []const u8) ?ui.Command {
    for (commands) |command| {
        if (command == .text and std.mem.eql(u8, command.text.value, value)) return command;
    }
    return null;
}
