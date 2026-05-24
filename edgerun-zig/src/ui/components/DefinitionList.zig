const std = @import("std");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const layout = @import("../../layouts/Types.zig");
const base_info_row = @import("base/InfoRow.zig");
const base_surface = @import("base/Surface.zig");
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

pub const DefinitionItem = struct {
    id: u32,
    term: []const u8,
    detail: []const u8,
};

pub const DefinitionList = struct {
    items: []const DefinitionItem,

    pub fn render(self: DefinitionList, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return renderDefinitionList(self, scene, bounds, options);
    }

    pub fn collectInteractions(self: DefinitionList, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return collectDefinitionListInteractions(self, collector, bounds);
    }

    pub fn measure(self: DefinitionList, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return measureDefinitionList(self, constraints);
    }

    pub fn toHtml(self: DefinitionList, out: []u8) HtmlError![]u8 {
        return writeHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, out_items: []DefinitionItem, text_out: []u8) HtmlError!DefinitionList {
        return readHtml(html, out_items, text_out);
    }

    pub fn toMarkdown(self: DefinitionList, out: []u8) MarkdownError![]u8 {
        return writeMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, out_items: []DefinitionItem, text_out: []u8) MarkdownError!DefinitionList {
        return readMarkdown(markdown, out_items, text_out);
    }

    pub fn register(registry: *ComponentRegistry) RegistryError!void {
        try registry.register(descriptor);
    }
};

pub const descriptor = common.ComponentDescriptor{
    .name = "definition-list",
    .html_prefix = "<dl data-er-component=\"definition-list\"",
    .markdown_prefix = ":::definitions",
    .render = renderRegistered,
    .collect_interactions = collectRegistered,
    .write_html = writeHtmlRegistered,
    .write_markdown = writeMarkdownRegistered,
};

pub fn register(registry: *ComponentRegistry) RegistryError!void {
    return DefinitionList.register(registry);
}

pub fn renderDefinitionList(list: DefinitionList, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    if (list.items.len == 0) return;
    try base_surface.renderFrame(scene, bounds, options);

    var y = bounds.y + definition_padding_y;
    const content_x = bounds.x + definition_padding_x;
    const content_w = @max(1.0, bounds.w - definition_padding_x * 2.0);
    const bottom = bounds.y + bounds.h - definition_padding_y;
    for (list.items) |item| {
        if (y + definition_row_metrics.height > bottom) break;
        const item_bounds = ui.Rect.init(content_x, y, content_w, definition_row_metrics.height);
        try base_info_row.render(scene, item_bounds, .{ .id = item.id, .title = item.term, .detail = item.detail }, definition_row_metrics, options);
        y += definition_row_metrics.height + definition_item_gap;
    }
}

pub fn collectDefinitionListInteractions(list: DefinitionList, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
    if (list.items.len == 0) return;
    var y = bounds.y + definition_padding_y;
    const content_x = bounds.x + definition_padding_x;
    const content_w = @max(1.0, bounds.w - definition_padding_x * 2.0);
    const bottom = bounds.y + bounds.h - definition_padding_y;
    for (list.items) |item| {
        if (y + definition_row_metrics.height > bottom) break;
        try base_info_row.collectInteractions(collector, ui.Rect.init(content_x, y, content_w, definition_row_metrics.height), .{ .id = item.id, .title = item.term, .detail = item.detail });
        y += definition_row_metrics.height + definition_item_gap;
    }
}

pub fn measureDefinitionList(list: DefinitionList, constraints: layout.Constraints) layout.Measurement {
    const content = constraints.inner(definitionInsets());
    var preferred_width: f32 = 0;
    var preferred_height: f32 = 0;
    for (list.items, 0..) |item, index| {
        if (index != 0) preferred_height += definition_item_gap;
        const row = measureDefinitionItem(item, content);
        preferred_width = @max(preferred_width, row.preferred.w);
        preferred_height += row.preferred.h;
    }
    return layout.Measurement.flexible(
        .{ .w = definition_row_metrics.min_width, .h = definition_padding_y * 2.0 },
        .{ .w = preferred_width, .h = preferred_height },
        .{ .w = constraints.width.limit(preferred_width), .h = preferred_height },
    ).withInsets(definitionInsets()).applyExact(constraints);
}

fn renderRegistered(component: *const anyopaque, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    const list: *const DefinitionList = @ptrCast(@alignCast(component));
    return renderDefinitionList(list.*, scene, bounds, options);
}

fn collectRegistered(component: *const anyopaque, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
    const list: *const DefinitionList = @ptrCast(@alignCast(component));
    return collectDefinitionListInteractions(list.*, collector, bounds);
}

pub fn writeHtml(list: DefinitionList, out: []u8) HtmlError![]u8 {
    if (list.items.len == 0) return error.InvalidHtml;
    var writer = HtmlWriter.init(out);
    try writer.writeAll("<dl data-er-component=\"definition-list\">");
    for (list.items) |item| {
        if (item.term.len == 0 or item.detail.len == 0) return error.InvalidHtml;
        try writer.writeAll("<div");
        try writer.writeAttrInt("data-er-id", item.id);
        try writer.writeAll("><dt>");
        try writer.writeEscapedText(item.term);
        try writer.writeAll("</dt><dd>");
        try writer.writeEscapedText(item.detail);
        try writer.writeAll("</dd></div>");
    }
    try writer.writeAll("</dl>");
    return writer.written();
}

fn writeHtmlRegistered(component: *const anyopaque, out: []u8) HtmlError![]u8 {
    const list: *const DefinitionList = @ptrCast(@alignCast(component));
    return writeHtml(list.*, out);
}

pub fn writeMarkdown(list: DefinitionList, out: []u8) MarkdownError![]u8 {
    if (list.items.len == 0) return error.InvalidMarkdown;
    var writer = MarkdownWriter.init(out);
    try writer.beginDirective("definitions");
    for (list.items) |item| {
        if (item.term.len == 0 or item.detail.len == 0) return error.InvalidMarkdown;
        try writer.fieldInt("item", item.id);
        try writer.fieldText("term", item.term);
        try writer.fieldText("detail", item.detail);
    }
    try writer.endDirective();
    return writer.written();
}

fn writeMarkdownRegistered(component: *const anyopaque, out: []u8) MarkdownError![]u8 {
    const list: *const DefinitionList = @ptrCast(@alignCast(component));
    return writeMarkdown(list.*, out);
}

pub fn readMarkdown(markdown: []const u8, out_items: []DefinitionItem, text_out: []u8) MarkdownError!DefinitionList {
    const prefix = ":::definitions\n";
    const body = try common.readMarkdownDirectiveBody(markdown, ":::definitions", prefix);
    var text = MarkdownTextArena.init(text_out);
    var item_count: usize = 0;
    var cursor = MarkdownCursor.init(body);
    while (!cursor.done()) {
        if (item_count == out_items.len) return error.MarkdownBudgetExceeded;
        const id = try common.parseMarkdownU32(try cursor.lineAfter("item: "));
        const term = try text.unescapeInline(try cursor.fieldBetween("\nterm: ", "\ndetail: "));
        const detail = try text.unescapeInline(try cursor.finalField("\ndetail: ", "\nitem: "));
        if (term.len == 0 or detail.len == 0) return error.InvalidMarkdown;
        out_items[item_count] = .{ .id = id, .term = term, .detail = detail };
        item_count += 1;
        try cursor.skipNewline();
    }
    if (item_count == 0) return error.InvalidMarkdown;
    return .{ .items = out_items[0..item_count] };
}

pub fn readHtml(html: []const u8, out_items: []DefinitionItem, text_out: []u8) HtmlError!DefinitionList {
    const body = common.takeWrapped(html, "<dl data-er-component=\"definition-list\">", "</dl>") orelse {
        if (std.mem.startsWith(u8, html, "<dl")) return error.InvalidHtml;
        return error.UnsupportedHtml;
    };
    var text = HtmlTextArena.init(text_out);
    const items = try readItemsHtml(body, out_items, &text);
    return .{ .items = items };
}

fn readItemsHtml(html: []const u8, out_items: []DefinitionItem, text: *HtmlTextArena) HtmlError![]const DefinitionItem {
    var cursor = HtmlCursor.init(html);
    var item_count: usize = 0;
    while (!cursor.done()) {
        if (item_count == out_items.len) return error.HtmlBudgetExceeded;
        const id = try common.parseHtmlU32(try cursor.fieldBetween("<div data-er-id=\"", "\"><dt>"));
        const term = try text.unescape(try cursor.fieldBetween("\"><dt>", "</dt><dd>"));
        const detail = try text.unescape(try cursor.fieldBetween("</dt><dd>", "</dd></div>"));
        try cursor.consume("</dd></div>");
        if (term.len == 0 or detail.len == 0) return error.InvalidHtml;
        out_items[item_count] = .{ .id = id, .term = term, .detail = detail };
        item_count += 1;
    }
    if (item_count == 0) return error.InvalidHtml;
    return out_items[0..item_count];
}

const definition_padding_x: f32 = 12.0;
const definition_padding_y: f32 = 12.0;
const definition_item_gap: f32 = 8.0;
const definition_row_metrics = base_info_row.Metrics{
    .height = 76.0,
    .detail_height = 34.0,
    .detail_line_height = 16.0,
};

fn measureDefinitionItem(item: DefinitionItem, constraints: layout.Constraints) layout.Measurement {
    return base_info_row.measure(item.term, item.detail, constraints, definition_row_metrics);
}

fn definitionInsets() layout.Insets {
    return .{ .top = definition_padding_y, .right = definition_padding_x, .bottom = definition_padding_y, .left = definition_padding_x };
}

test "definition list component renders glossary rows and collects hit targets" {
    const items = [_]DefinitionItem{
        .{ .id = 36001, .term = "DNS", .detail = "Turns a name into an address the network can route." },
        .{ .id = 36002, .term = "TLS", .detail = "Protects bytes while they travel between endpoints." },
    };
    const list = DefinitionList{ .items = &items };
    var commands: [64]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [4]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try list.render(&scene, ui.Rect.init(0, 0, 380, 200), .{});
    try list.collectInteractions(&collector, ui.Rect.init(0, 0, 380, 200));

    try std.testing.expect(hasText(scene.written(), "DNS"));
    try std.testing.expect(ui_input.hitTest(scene.written(), 24, 104) == null);
    const hit = ui_input.regionHitTest(collector.written(), 24, 104).?;
    try std.testing.expectEqual(@as(u32, 36002), hit.id);
}

test "definition list measurement grows with wrapped details" {
    const items = [_]DefinitionItem{
        .{ .id = 36001, .term = "DNS", .detail = "Turns a name into an address the network can route, cache, and explain to the browser." },
        .{ .id = 36002, .term = "TLS", .detail = "Protects bytes while they travel between endpoints." },
    };
    const list = DefinitionList{ .items = &items };

    const wide = list.measure(.{ .width = .{ .exact = 420 }, .text_wrap = .wrap }, .{});
    const narrow = list.measure(.{ .width = .{ .exact = 220 }, .text_wrap = .wrap }, .{});

    try std.testing.expectEqual(@as(f32, 420), wide.preferred.w);
    try std.testing.expectEqual(@as(f32, 220), narrow.preferred.w);
    try std.testing.expect(narrow.preferred.h >= wide.preferred.h);
}

test "definition list html codec roundtrips semantic terms" {
    const items = [_]DefinitionItem{
        .{ .id = 36101, .term = "Capability", .detail = "A concrete permission to do one thing." },
        .{ .id = 36102, .term = "Identity", .detail = "A key-backed claim about who can act & sign." },
    };
    const list = DefinitionList{ .items = &items };
    var html: [768]u8 = undefined;
    var decoded_items: [2]DefinitionItem = undefined;
    var text: [256]u8 = undefined;

    const encoded = try list.toHtml(&html);
    const decoded = try DefinitionList.fromHtml(encoded, &decoded_items, &text);

    try std.testing.expectEqualStrings("<dl data-er-component=\"definition-list\"><div data-er-id=\"36101\"><dt>Capability</dt><dd>A concrete permission to do one thing.</dd></div><div data-er-id=\"36102\"><dt>Identity</dt><dd>A key-backed claim about who can act &amp; sign.</dd></div></dl>", encoded);
    try std.testing.expectEqual(@as(usize, 2), decoded.items.len);
    try std.testing.expectEqual(@as(u32, 36102), decoded.items[1].id);
    try std.testing.expectEqualStrings("Identity", decoded.items[1].term);
    try std.testing.expectEqualStrings("A key-backed claim about who can act & sign.", decoded.items[1].detail);
}

test "definition list html codec rejects malformed terms" {
    var items: [2]DefinitionItem = undefined;
    var text: [128]u8 = undefined;

    try std.testing.expectError(error.InvalidHtml, DefinitionList.fromHtml("<dl><dt>Plain</dt><dd>No marker</dd></dl>", &items, &text));
    try std.testing.expectError(error.InvalidHtml, DefinitionList.fromHtml("<dl data-er-component=\"definition-list\"></dl>", &items, &text));
    try std.testing.expectError(error.InvalidHtml, DefinitionList.fromHtml("<dl data-er-component=\"definition-list\"><div data-er-id=\"x\"><dt>Broken</dt><dd>Bad id</dd></div></dl>", &items, &text));
    try std.testing.expectError(error.InvalidHtml, DefinitionList.fromHtml("<dl data-er-component=\"definition-list\"><div data-er-id=\"1\"><dt></dt><dd>Missing term</dd></div></dl>", &items, &text));
}

test "definition list registers explicit runtime descriptor" {
    const items = [_]DefinitionItem{
        .{ .id = 36201, .term = "Capability", .detail = "A concrete permission to do one thing." },
        .{ .id = 36202, .term = "Receipt", .detail = "A signed record of work that happened." },
    };
    const list = DefinitionList{ .items = &items };
    var entries: [1]common.ComponentDescriptor = undefined;
    var registry = ComponentRegistry.init(&entries);
    var html: [768]u8 = undefined;
    var markdown: [512]u8 = undefined;
    var commands: [64]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [4]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try DefinitionList.register(&registry);
    try std.testing.expectError(error.DuplicateComponent, DefinitionList.register(&registry));
    try std.testing.expectEqualStrings("definition-list", registry.matchHtml("<dl data-er-component=\"definition-list\"></dl>").?.name);
    try std.testing.expectEqualStrings("definition-list", registry.matchMarkdown(":::definitions\nitem: 1\n:::").?.name);

    const encoded_html = try registry.writeHtml("definition-list", &list, &html);
    const encoded_markdown = try registry.writeMarkdown("definition-list", &list, &markdown);
    try registry.render("definition-list", &list, &scene, ui.Rect.init(0, 0, 380, 200), .{});
    try registry.collectInteractions("definition-list", &list, &collector, ui.Rect.init(0, 0, 380, 200));

    try std.testing.expect(std.mem.indexOf(u8, encoded_html, "<dl data-er-component=\"definition-list\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded_markdown, ":::definitions") != null);
    try std.testing.expect(hasText(scene.written(), "Capability"));
    try std.testing.expectEqual(@as(u32, 36202), ui_input.regionHitTest(collector.written(), 24, 104).?.id);
}

fn hasText(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| {
        if (command == .text and std.mem.eql(u8, command.text.value, value)) return true;
    }
    return false;
}
