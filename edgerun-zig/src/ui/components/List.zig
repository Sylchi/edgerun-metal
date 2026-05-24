const std = @import("std");
const common = @import("../../ui_component_common.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const base_marker = @import("base/Marker.zig");
const base_text_block = @import("base/TextBlock.zig");

const ComponentRegistry = common.ComponentRegistry;
const HtmlCursor = common.HtmlCursor;
const HtmlError = common.HtmlError;
const HtmlTextArena = common.HtmlTextArena;
const HtmlWriter = common.HtmlWriter;
const MarkdownError = common.MarkdownError;
const MarkdownTextArena = common.MarkdownTextArena;
const MarkdownWriter = common.MarkdownWriter;
const RegistryError = common.RegistryError;
const RenderOptions = common.RenderOptions;

pub const List = struct {
    ordered: bool = false,
    items: []const []const u8,

    pub fn render(self: List, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return renderList(self, scene, bounds, options);
    }

    pub fn measure(self: List, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return measureList(self, constraints);
    }

    pub fn toHtml(self: List, out: []u8) HtmlError![]u8 {
        return writeHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, out_items: [][]const u8, text_out: []u8) HtmlError!List {
        return readHtml(html, out_items, text_out);
    }

    pub fn toMarkdown(self: List, out: []u8) MarkdownError![]u8 {
        return writeMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, out_items: [][]const u8, text_out: []u8) MarkdownError!List {
        return readMarkdown(markdown, out_items, text_out);
    }

    pub fn register(registry: *ComponentRegistry) RegistryError!void {
        try registry.register(descriptor);
    }
};

pub const descriptor = common.ComponentDescriptor{
    .name = "list",
    .html_prefix = "<ul data-er-component=\"list\"",
    .markdown_prefix = "- ",
    .render = renderRegistered,
    .write_html = writeHtmlRegistered,
    .write_markdown = writeMarkdownRegistered,
};

pub fn register(registry: *ComponentRegistry) RegistryError!void {
    return List.register(registry);
}

pub fn renderList(list: List, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    var y = bounds.y;
    for (list.items, 0..) |item, index| {
        if (y + list_item_h > bounds.y + bounds.h) break;
        const marker_bounds = ui.Rect.init(bounds.x, y + list_marker_y, list_marker_w, list_marker_h);
        if (list.ordered) {
            try scene.pushAlignedText(marker_bounds, orderedMarker(index), options.style.accent, .end);
        } else {
            try base_marker.renderFilled(scene, ui.Rect.init(bounds.x + list_bullet_x, y + list_bullet_y, list_bullet_size, list_bullet_size), options.style.accent);
        }
        try base_text_block.render(scene, ui.Rect.init(bounds.x + list_text_x, y, @max(1.0, bounds.w - list_text_x), list_item_h), item, options.style.text, list_item_metrics);
        y += list_item_h + list_item_gap;
    }
}

pub fn measureList(list: List, constraints: layout.Constraints) layout.Measurement {
    var preferred_width: f32 = 0;
    var preferred_height: f32 = 0;
    const text_constraints = constraints.inner(.{ .left = list_text_x });
    for (list.items) |item| {
        const item_measure = base_text_block.measure(item, text_constraints, list_item_metrics);
        preferred_width = @max(preferred_width, item_measure.preferred.w + list_text_x);
        preferred_height += @max(list_item_h, item_measure.preferred.h);
        if (preferred_height != 0) preferred_height += list_item_gap;
    }
    if (preferred_height > 0) preferred_height -= list_item_gap;
    return layout.Measurement.flexible(
        .{ .w = @min(preferred_width, constraints.width.limit(preferred_width)), .h = @min(list_item_h, preferred_height) },
        .{ .w = constraints.width.exactValue() orelse preferred_width, .h = constraints.height.exactValue() orelse preferred_height },
        .{ .w = @max(preferred_width, constraints.width.limit(preferred_width)), .h = preferred_height },
    );
}

fn renderRegistered(component: *const anyopaque, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    const list: *const List = @ptrCast(@alignCast(component));
    return renderList(list.*, scene, bounds, options);
}

pub fn writeHtml(list: List, out: []u8) HtmlError![]u8 {
    if (list.items.len == 0) return error.InvalidHtml;
    var writer = HtmlWriter.init(out);
    const tag = if (list.ordered) "ol" else "ul";
    try writer.writeByte('<');
    try writer.writeAll(tag);
    try writer.writeAll(" data-er-component=\"list\">");
    for (list.items) |item| {
        try writer.writeAll("<li>");
        try writer.writeEscapedText(item);
        try writer.writeAll("</li>");
    }
    try writer.writeAll("</");
    try writer.writeAll(tag);
    try writer.writeByte('>');
    return writer.written();
}

fn writeHtmlRegistered(component: *const anyopaque, out: []u8) HtmlError![]u8 {
    const list: *const List = @ptrCast(@alignCast(component));
    return writeHtml(list.*, out);
}

pub fn writeMarkdown(list: List, out: []u8) MarkdownError![]u8 {
    if (list.items.len == 0) return error.InvalidMarkdown;
    var writer = MarkdownWriter.init(out);
    for (list.items, 0..) |item, index| {
        if (item.len == 0) return error.InvalidMarkdown;
        if (index != 0) try writer.writeByte('\n');
        if (list.ordered) {
            try writer.writeInt(@intCast(index + 1));
            try writer.writeAll(". ");
        } else {
            try writer.writeAll("- ");
        }
        try writer.writeEscapedInline(item);
    }
    return writer.written();
}

fn writeMarkdownRegistered(component: *const anyopaque, out: []u8) MarkdownError![]u8 {
    const list: *const List = @ptrCast(@alignCast(component));
    return writeMarkdown(list.*, out);
}

pub fn readMarkdown(markdown: []const u8, out_items: [][]const u8, text_out: []u8) MarkdownError!List {
    if (markdown.len == 0) return error.InvalidMarkdown;
    const ordered = if (std.mem.startsWith(u8, markdown, "1. "))
        true
    else if (std.mem.startsWith(u8, markdown, "- "))
        false
    else if (std.mem.startsWith(u8, markdown, "1.") or std.mem.startsWith(u8, markdown, "-"))
        return error.InvalidMarkdown
    else
        return error.UnsupportedMarkdown;

    var text = MarkdownTextArena.init(text_out);
    var item_count: usize = 0;
    var line_iterator = std.mem.splitScalar(u8, markdown, '\n');
    while (line_iterator.next()) |line| {
        if (item_count == out_items.len) return error.MarkdownBudgetExceeded;
        const value = if (ordered) blk: {
            var prefix_buffer: [16]u8 = undefined;
            const prefix = std.fmt.bufPrint(&prefix_buffer, "{d}. ", .{item_count + 1}) catch unreachable;
            if (!std.mem.startsWith(u8, line, prefix)) return error.InvalidMarkdown;
            break :blk line[prefix.len..];
        } else blk: {
            if (!std.mem.startsWith(u8, line, "- ")) return error.InvalidMarkdown;
            break :blk line["- ".len..];
        };
        out_items[item_count] = try text.unescapeInline(value);
        if (out_items[item_count].len == 0) return error.InvalidMarkdown;
        item_count += 1;
    }
    if (item_count == 0) return error.InvalidMarkdown;
    return .{ .ordered = ordered, .items = out_items[0..item_count] };
}

pub fn readHtml(html: []const u8, out_items: [][]const u8, text_out: []u8) HtmlError!List {
    if (common.takeWrapped(html, "<ul data-er-component=\"list\">", "</ul>")) |body| {
        return .{ .ordered = false, .items = try readItemsHtml(body, out_items, text_out) };
    }
    if (common.takeWrapped(html, "<ol data-er-component=\"list\">", "</ol>")) |body| {
        return .{ .ordered = true, .items = try readItemsHtml(body, out_items, text_out) };
    }
    if (std.mem.startsWith(u8, html, "<ul") or std.mem.startsWith(u8, html, "<ol")) return error.InvalidHtml;
    return error.UnsupportedHtml;
}

fn readItemsHtml(html: []const u8, out_items: [][]const u8, text_out: []u8) HtmlError![]const []const u8 {
    var text = HtmlTextArena.init(text_out);
    var cursor = HtmlCursor.init(html);
    var item_count: usize = 0;
    while (!cursor.done()) {
        if (item_count == out_items.len) return error.HtmlBudgetExceeded;
        out_items[item_count] = try text.unescape(try cursor.fieldBetween("<li>", "</li>"));
        try cursor.consume("</li>");
        item_count += 1;
    }
    if (item_count == 0) return error.InvalidHtml;
    return out_items[0..item_count];
}

const list_item_h: f32 = 42.0;
const list_item_gap: f32 = 4.0;
const list_marker_w: f32 = 24.0;
const list_marker_h: f32 = 14.0;
const list_marker_y: f32 = 4.0;
const list_bullet_x: f32 = 4.0;
const list_bullet_y: f32 = 8.0;
const list_bullet_size: f32 = 5.0;
const list_text_x: f32 = 28.0;
const list_line_h: f32 = 18.0;
const list_avg_w: f32 = 9.0;
const list_item_max_lines: usize = 2;
const list_item_metrics = base_text_block.Metrics{
    .line_height = list_line_h,
    .average_char_width = list_avg_w,
    .max_lines = list_item_max_lines,
};

fn orderedMarker(index: usize) []const u8 {
    const markers = [_][]const u8{ "1.", "2.", "3.", "4.", "5.", "6.", "7.", "8.", "9." };
    if (index < markers.len) return markers[index];
    return "9.";
}

test "list component renders ordered markers and wrapped items" {
    const items = [_][]const u8{
        "Browser asks",
        "Resolver answers",
    };
    const list = List{ .ordered = true, .items = &items };
    var commands: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try list.render(&scene, ui.Rect.init(0, 0, 360, 110), .{});

    try std.testing.expect(hasText(scene.written(), "1."));
    try std.testing.expect(hasTextContaining(scene.written(), "Resolver answers"));
}

test "list measurement honors exact width and stable row height" {
    const items = [_][]const u8{
        "Browser asks a resolver for the address attached to a name",
        "Cache remembers the answer for a short time",
    };
    const list = List{ .ordered = true, .items = &items };

    const wide = list.measure(.{ .width = .{ .exact = 360 }, .text_wrap = .wrap }, .{});
    const narrow = list.measure(.{ .width = .{ .exact = 140 }, .text_wrap = .wrap }, .{});

    try std.testing.expectEqual(@as(f32, 360), wide.preferred.w);
    try std.testing.expectEqual(@as(f32, 140), narrow.preferred.w);
    try std.testing.expectEqual(wide.preferred.h, narrow.preferred.h);
}

test "list html codec roundtrips ordered escaped items" {
    const items = [_][]const u8{
        "Name",
        "TLS < DNS & TPM",
    };
    const list = List{ .ordered = true, .items = &items };
    var html: [256]u8 = undefined;
    var decoded_items: [2][]const u8 = undefined;
    var text: [128]u8 = undefined;

    const encoded = try list.toHtml(&html);
    const decoded = try List.fromHtml(encoded, &decoded_items, &text);

    try std.testing.expectEqualStrings("<ol data-er-component=\"list\"><li>Name</li><li>TLS &lt; DNS &amp; TPM</li></ol>", encoded);
    try std.testing.expect(decoded.ordered);
    try std.testing.expectEqual(@as(usize, 2), decoded.items.len);
    try std.testing.expectEqualStrings("TLS < DNS & TPM", decoded.items[1]);
}

test "list html codec rejects malformed lists" {
    var items: [2][]const u8 = undefined;
    var text: [64]u8 = undefined;

    try std.testing.expectError(error.InvalidHtml, List.fromHtml("<ul data-er-component=\"list\"></ul>", &items, &text));
    try std.testing.expectError(error.InvalidHtml, List.fromHtml("<ul><li>Plain</li></ul>", &items, &text));
    try std.testing.expectError(error.UnsupportedHtml, List.fromHtml("<p>Plain text</p>", &items, &text));
}

test "list markdown codec roundtrips ordered and unordered lists" {
    const ordered_items = [_][]const u8{ "Browser asks", "Resolver answers" };
    const unordered_items = [_][]const u8{ "Name", "Address" };
    var markdown: [256]u8 = undefined;
    var decoded_items: [2][]const u8 = undefined;
    var text: [128]u8 = undefined;

    const ordered = try (List{ .ordered = true, .items = &ordered_items }).toMarkdown(&markdown);
    const decoded_ordered = try List.fromMarkdown(ordered, &decoded_items, &text);
    try std.testing.expectEqualStrings("1. Browser asks\n2. Resolver answers", ordered);
    try std.testing.expect(decoded_ordered.ordered);
    try std.testing.expectEqualStrings("Resolver answers", decoded_ordered.items[1]);

    const unordered = try (List{ .items = &unordered_items }).toMarkdown(&markdown);
    const decoded_unordered = try List.fromMarkdown(unordered, &decoded_items, &text);
    try std.testing.expectEqualStrings("- Name\n- Address", unordered);
    try std.testing.expect(!decoded_unordered.ordered);
    try std.testing.expectEqualStrings("Address", decoded_unordered.items[1]);
}

test "list markdown codec rejects sequence gaps and empty items" {
    var items: [2][]const u8 = undefined;
    var text: [64]u8 = undefined;

    try std.testing.expectError(error.InvalidMarkdown, List.fromMarkdown("1. First\n3. Skips", &items, &text));
    try std.testing.expectError(error.InvalidMarkdown, List.fromMarkdown("- ", &items, &text));
    try std.testing.expectError(error.UnsupportedMarkdown, List.fromMarkdown("Plain paragraph", &items, &text));
}

test "list registers explicit runtime descriptor" {
    const items = [_][]const u8{ "Name", "Address" };
    const list = List{ .items = &items };
    var entries: [1]common.ComponentDescriptor = undefined;
    var registry = ComponentRegistry.init(&entries);
    var html: [256]u8 = undefined;
    var markdown: [128]u8 = undefined;
    var commands: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try List.register(&registry);
    try std.testing.expectError(error.DuplicateComponent, List.register(&registry));
    try std.testing.expectEqualStrings("list", registry.matchHtml("<ul data-er-component=\"list\"><li>Name</li></ul>").?.name);
    try std.testing.expectEqualStrings("list", registry.matchMarkdown("- Name").?.name);

    const encoded_html = try registry.writeHtml("list", &list, &html);
    const encoded_markdown = try registry.writeMarkdown("list", &list, &markdown);
    try registry.render("list", &list, &scene, ui.Rect.init(0, 0, 360, 110), .{});

    try std.testing.expectEqualStrings("<ul data-er-component=\"list\"><li>Name</li><li>Address</li></ul>", encoded_html);
    try std.testing.expectEqualStrings("- Name\n- Address", encoded_markdown);
    try std.testing.expect(hasTextContaining(scene.written(), "Address"));
}

fn hasText(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| {
        if (command == .text and std.mem.eql(u8, command.text.value, value)) return true;
    }
    return false;
}

fn hasTextContaining(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| {
        if (command == .text and std.mem.indexOf(u8, command.text.value, value) != null) return true;
    }
    return false;
}
