const std = @import("std");
const common = @import("../../ui_component_common.zig");
const base_label_hit = @import("base/LabelHit.zig");
const ui = @import("../../ui.zig");
const ui_input = @import("../../input.zig");

const ComponentRegistry = common.ComponentRegistry;
const HtmlCursor = common.HtmlCursor;
const HtmlError = common.HtmlError;
const HtmlTextArena = common.HtmlTextArena;
const HtmlWriter = common.HtmlWriter;
const MarkdownCursor = common.MarkdownCursor;
const MarkdownError = common.MarkdownError;
const MarkdownTextArena = common.MarkdownTextArena;
const MarkdownWriter = common.MarkdownWriter;
const RegistryError = common.RegistryError;
const RenderOptions = common.RenderOptions;

pub const BreadcrumbItem = struct {
    id: u32,
    label: []const u8,
    href: []const u8 = "",
    current: bool = false,
};

pub const Breadcrumb = struct {
    items: []const BreadcrumbItem,

    pub fn render(self: Breadcrumb, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return renderBreadcrumb(self, scene, bounds, options);
    }

    pub fn toHtml(self: Breadcrumb, out: []u8) HtmlError![]u8 {
        return writeHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, out_items: []BreadcrumbItem, text_out: []u8) HtmlError!Breadcrumb {
        return readHtml(html, out_items, text_out);
    }

    pub fn toMarkdown(self: Breadcrumb, out: []u8) MarkdownError![]u8 {
        return writeMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, out_items: []BreadcrumbItem, text_out: []u8) MarkdownError!Breadcrumb {
        return readMarkdown(markdown, out_items, text_out);
    }

    pub fn register(registry: *ComponentRegistry) RegistryError!void {
        try registry.register(descriptor);
    }
};

pub const descriptor = common.ComponentDescriptor{
    .name = "breadcrumb",
    .html_prefix = "<nav data-er-component=\"breadcrumb\"",
    .markdown_prefix = ":::breadcrumb",
    .render = renderRegistered,
    .write_html = writeHtmlRegistered,
    .write_markdown = writeMarkdownRegistered,
};

pub fn register(registry: *ComponentRegistry) RegistryError!void {
    return Breadcrumb.register(registry);
}

pub fn renderBreadcrumb(breadcrumb: Breadcrumb, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    if (breadcrumb.items.len == 0) return;
    var cursor_x = bounds.x + breadcrumb_padding_x;
    const y = bounds.y + @max(0.0, (bounds.h - breadcrumb_item_h) * 0.5);
    const right = bounds.x + bounds.w - breadcrumb_padding_x;
    for (breadcrumb.items, 0..) |item, index| {
        const item_w = breadcrumbItemWidth(item.label);
        if (cursor_x + item_w > right) break;
        const item_bounds = ui.Rect.init(cursor_x, y, item_w, breadcrumb_item_h);
        try base_label_hit.render(scene, item_bounds, .{ .id = item.id, .label = item.label, .color = if (item.current) options.style.text else options.style.muted, .alignment = .start }, breadcrumb_label_insets);
        cursor_x += item_w;
        if (index + 1 < breadcrumb.items.len) {
            if (cursor_x + breadcrumb_separator_w > right) break;
            try scene.pushAlignedText(ui.Rect.init(cursor_x, y + breadcrumb_text_y, breadcrumb_separator_w, breadcrumb_text_h), "/", options.style.border, .center);
            cursor_x += breadcrumb_separator_w;
        }
    }
}

fn renderRegistered(component: *const anyopaque, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    const breadcrumb: *const Breadcrumb = @ptrCast(@alignCast(component));
    return renderBreadcrumb(breadcrumb.*, scene, bounds, options);
}

pub fn writeHtml(breadcrumb: Breadcrumb, out: []u8) HtmlError![]u8 {
    if (breadcrumb.items.len == 0) return error.InvalidHtml;
    var writer = HtmlWriter.init(out);
    try writer.writeAll("<nav data-er-component=\"breadcrumb\" aria-label=\"Breadcrumb\"><ol>");
    for (breadcrumb.items) |item| {
        if (item.label.len == 0) return error.InvalidHtml;
        try writer.writeAll("<li");
        try writer.writeAttrInt("data-er-id", item.id);
        try writer.writeAttrBool("data-er-current", item.current);
        try writer.writeAll("><a");
        try writer.writeAttrText("href", item.href);
        try writer.writeByte('>');
        try writer.writeEscapedText(item.label);
        try writer.writeAll("</a></li>");
    }
    try writer.writeAll("</ol></nav>");
    return writer.written();
}

fn writeHtmlRegistered(component: *const anyopaque, out: []u8) HtmlError![]u8 {
    const breadcrumb: *const Breadcrumb = @ptrCast(@alignCast(component));
    return writeHtml(breadcrumb.*, out);
}

pub fn writeMarkdown(breadcrumb: Breadcrumb, out: []u8) MarkdownError![]u8 {
    if (breadcrumb.items.len == 0) return error.InvalidMarkdown;
    var writer = MarkdownWriter.init(out);
    try writer.beginDirective("breadcrumb");
    for (breadcrumb.items) |item| {
        if (item.label.len == 0) return error.InvalidMarkdown;
        try writer.fieldInt("item", item.id);
        try writer.fieldBool("current", item.current);
        try writer.fieldText("href", item.href);
        try writer.fieldText("label", item.label);
    }
    try writer.endDirective();
    return writer.written();
}

fn writeMarkdownRegistered(component: *const anyopaque, out: []u8) MarkdownError![]u8 {
    const breadcrumb: *const Breadcrumb = @ptrCast(@alignCast(component));
    return writeMarkdown(breadcrumb.*, out);
}

pub fn readMarkdown(markdown: []const u8, out_items: []BreadcrumbItem, text_out: []u8) MarkdownError!Breadcrumb {
    const prefix = ":::breadcrumb\n";
    const body = try common.readMarkdownDirectiveBody(markdown, ":::breadcrumb", prefix);
    var text = MarkdownTextArena.init(text_out);
    var item_count: usize = 0;
    var cursor = MarkdownCursor.init(body);
    while (!cursor.done()) {
        if (item_count == out_items.len) return error.MarkdownBudgetExceeded;
        const id = try common.parseMarkdownU32(try cursor.lineAfter("item: "));
        const current = try common.parseMarkdownBool(try cursor.fieldBetween("\ncurrent: ", "\nhref: "));
        const href = try text.unescapeInline(try cursor.fieldBetween("\nhref: ", "\nlabel: "));
        const label = try text.unescapeInline(try cursor.finalField("\nlabel: ", "\nitem: "));
        if (label.len == 0) return error.InvalidMarkdown;
        out_items[item_count] = .{ .id = id, .label = label, .href = href, .current = current };
        item_count += 1;
        try cursor.skipNewline();
    }
    if (item_count == 0) return error.InvalidMarkdown;
    return .{ .items = out_items[0..item_count] };
}

pub fn readHtml(html: []const u8, out_items: []BreadcrumbItem, text_out: []u8) HtmlError!Breadcrumb {
    const prefix = "<nav data-er-component=\"breadcrumb\" aria-label=\"Breadcrumb\"><ol>";
    const suffix = "</ol></nav>";
    const body = common.takeWrapped(html, prefix, suffix) orelse {
        if (std.mem.startsWith(u8, html, "<nav")) return error.InvalidHtml;
        return error.UnsupportedHtml;
    };
    var text = HtmlTextArena.init(text_out);
    const items = try readItemsHtml(body, out_items, &text);
    return .{ .items = items };
}

fn readItemsHtml(html: []const u8, out_items: []BreadcrumbItem, text: *HtmlTextArena) HtmlError![]const BreadcrumbItem {
    var cursor = HtmlCursor.init(html);
    var item_count: usize = 0;
    while (!cursor.done()) {
        if (item_count == out_items.len) return error.HtmlBudgetExceeded;
        const id = try common.parseHtmlU32(try cursor.fieldBetween("<li data-er-id=\"", "\" data-er-current=\""));
        const current = try common.parseHtmlBool(try cursor.fieldBetween("\" data-er-current=\"", "\"><a href=\""));
        const href = try text.unescape(try cursor.fieldBetween("\"><a href=\"", "\">"));
        const label = try text.unescape(try cursor.fieldBetween("\">", "</a></li>"));
        try cursor.consume("</a></li>");
        if (label.len == 0) return error.InvalidHtml;
        out_items[item_count] = .{
            .id = id,
            .label = label,
            .href = href,
            .current = current,
        };
        item_count += 1;
    }
    if (item_count == 0) return error.InvalidHtml;
    return out_items[0..item_count];
}

const breadcrumb_padding_x: f32 = 4.0;
const breadcrumb_item_h: f32 = 28.0;
const breadcrumb_item_padding_x: f32 = 6.0;
const breadcrumb_text_y: f32 = 7.0;
const breadcrumb_text_h: f32 = 14.0;
const breadcrumb_avg_w: f32 = 8.0;
const breadcrumb_min_w: f32 = 18.0;
const breadcrumb_separator_w: f32 = 16.0;
const breadcrumb_label_insets = base_label_hit.Insets{ .x = breadcrumb_item_padding_x, .y = breadcrumb_text_y };
const breadcrumb_width_metrics = base_label_hit.WidthMetrics{
    .average_char_width = breadcrumb_avg_w,
    .min_width = breadcrumb_min_w,
    .padding_x = breadcrumb_item_padding_x,
};

fn breadcrumbItemWidth(label: []const u8) f32 {
    return base_label_hit.width(label, breadcrumb_width_metrics);
}

test "breadcrumb component renders path and hit targets" {
    const items = [_]BreadcrumbItem{
        .{ .id = 35001, .label = "Academy", .href = "#/academy" },
        .{ .id = 35002, .label = "Systems", .href = "#/systems" },
        .{ .id = 35003, .label = "DNS", .href = "#/dns", .current = true },
    };
    const breadcrumb = Breadcrumb{ .items = &items };
    var commands: [64]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try breadcrumb.render(&scene, ui.Rect.init(0, 0, 360, 40), .{});

    try std.testing.expect(hasText(scene.written(), "Academy"));
    try std.testing.expect(hasText(scene.written(), "DNS"));
    const hit = ui_input.hitTest(scene.written(), 92, 20).?;
    try std.testing.expectEqual(@as(u32, 35002), hit.id);
}

test "breadcrumb html codec roundtrips semantic navigation path" {
    const items = [_]BreadcrumbItem{
        .{ .id = 35101, .label = "Academy", .href = "#/academy" },
        .{ .id = 35102, .label = "Security & Identity", .href = "#/security", .current = true },
    };
    const breadcrumb = Breadcrumb{ .items = &items };
    var html: [512]u8 = undefined;
    var decoded_items: [2]BreadcrumbItem = undefined;
    var text: [256]u8 = undefined;

    const encoded = try breadcrumb.toHtml(&html);
    const decoded = try Breadcrumb.fromHtml(encoded, &decoded_items, &text);

    try std.testing.expectEqualStrings("<nav data-er-component=\"breadcrumb\" aria-label=\"Breadcrumb\"><ol><li data-er-id=\"35101\" data-er-current=\"false\"><a href=\"#/academy\">Academy</a></li><li data-er-id=\"35102\" data-er-current=\"true\"><a href=\"#/security\">Security &amp; Identity</a></li></ol></nav>", encoded);
    try std.testing.expectEqual(@as(usize, 2), decoded.items.len);
    try std.testing.expectEqual(@as(u32, 35102), decoded.items[1].id);
    try std.testing.expect(decoded.items[1].current);
    try std.testing.expectEqualStrings("#/security", decoded.items[1].href);
    try std.testing.expectEqualStrings("Security & Identity", decoded.items[1].label);
}

test "breadcrumb html codec rejects malformed paths" {
    var items: [2]BreadcrumbItem = undefined;
    var text: [128]u8 = undefined;

    try std.testing.expectError(error.InvalidHtml, Breadcrumb.fromHtml("<nav><ol><li>Plain</li></ol></nav>", &items, &text));
    try std.testing.expectError(error.InvalidHtml, Breadcrumb.fromHtml("<nav data-er-component=\"breadcrumb\" aria-label=\"Breadcrumb\"><ol></ol></nav>", &items, &text));
    try std.testing.expectError(error.InvalidHtml, Breadcrumb.fromHtml("<nav data-er-component=\"breadcrumb\" aria-label=\"Breadcrumb\"><ol><li data-er-id=\"x\" data-er-current=\"false\"><a href=\"#\">Broken</a></li></ol></nav>", &items, &text));
    try std.testing.expectError(error.InvalidHtml, Breadcrumb.fromHtml("<nav data-er-component=\"breadcrumb\" aria-label=\"Breadcrumb\"><ol><li data-er-id=\"1\" data-er-current=\"maybe\"><a href=\"#\">Broken</a></li></ol></nav>", &items, &text));
}

test "breadcrumb registers explicit runtime descriptor" {
    const items = [_]BreadcrumbItem{
        .{ .id = 35201, .label = "Academy", .href = "#/academy" },
        .{ .id = 35202, .label = "DNS", .href = "#/dns", .current = true },
    };
    const breadcrumb = Breadcrumb{ .items = &items };
    var entries: [1]common.ComponentDescriptor = undefined;
    var registry = ComponentRegistry.init(&entries);
    var html: [512]u8 = undefined;
    var markdown: [512]u8 = undefined;
    var commands: [64]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try Breadcrumb.register(&registry);
    try std.testing.expectError(error.DuplicateComponent, Breadcrumb.register(&registry));
    try std.testing.expectEqualStrings("breadcrumb", registry.matchHtml("<nav data-er-component=\"breadcrumb\"></nav>").?.name);
    try std.testing.expectEqualStrings("breadcrumb", registry.matchMarkdown(":::breadcrumb\nitem: 1\n:::").?.name);

    const encoded_html = try registry.writeHtml("breadcrumb", &breadcrumb, &html);
    const encoded_markdown = try registry.writeMarkdown("breadcrumb", &breadcrumb, &markdown);
    try registry.render("breadcrumb", &breadcrumb, &scene, ui.Rect.init(0, 0, 360, 40), .{});

    try std.testing.expect(std.mem.indexOf(u8, encoded_html, "<nav data-er-component=\"breadcrumb\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded_markdown, ":::breadcrumb") != null);
    try std.testing.expect(hasText(scene.written(), "DNS"));
}

fn hasText(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| {
        if (command == .text and std.mem.eql(u8, command.text.value, value)) return true;
    }
    return false;
}
