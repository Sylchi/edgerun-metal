const std = @import("std");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const flex = @import("../../layouts/Flex.zig");
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

pub const ResourceItem = struct {
    id: u32,
    label: []const u8,
    href: []const u8,
    detail: []const u8,
};

pub const ResourceList = struct {
    items: []const ResourceItem,

    pub fn render(self: ResourceList, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return renderResourceList(self, scene, bounds, options);
    }

    pub fn collectInteractions(self: ResourceList, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return collectResourceListInteractions(self, collector, bounds);
    }

    pub fn measure(self: ResourceList, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return measureResourceList(self, constraints);
    }

    pub fn toHtml(self: ResourceList, out: []u8) HtmlError![]u8 {
        return writeHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, out_items: []ResourceItem, text_out: []u8) HtmlError!ResourceList {
        return readHtml(html, out_items, text_out);
    }

    pub fn toMarkdown(self: ResourceList, out: []u8) MarkdownError![]u8 {
        return writeMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, out_items: []ResourceItem, text_out: []u8) MarkdownError!ResourceList {
        return readMarkdown(markdown, out_items, text_out);
    }

    pub fn register(registry: *ComponentRegistry) RegistryError!void {
        return common.registerDescriptor(registry, descriptor);
    }
};

pub const descriptor = common.ComponentDescriptor{
    .name = "resource-list",
    .html_prefix = "<ul data-er-component=\"resource-list\"",
    .markdown_prefix = ":::resources",
    .render = common.renderAdapter(ResourceList, renderResourceList),
    .collect_interactions = common.collectAdapter(ResourceList, collectResourceListInteractions),
    .write_html = common.writeHtmlAdapter(ResourceList, writeHtml),
    .write_markdown = common.writeMarkdownAdapter(ResourceList, writeMarkdown),
};

pub fn register(registry: *ComponentRegistry) RegistryError!void {
    return common.registerDescriptor(registry, descriptor);
}

pub fn renderResourceList(list: ResourceList, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    if (list.items.len == 0) return;
    try base_surface.renderFrame(scene, bounds, options);

    var cursor = resourceCursor(bounds);
    for (list.items) |item| {
        const item_bounds = cursor.nextWithinBounds(measureResourceItem(item, .{})) orelse break;
        try base_info_row.render(scene, item_bounds, .{ .id = item.id, .title = item.label, .detail = item.detail, .hit_kind = .button }, resource_row_metrics, options);
    }
}

pub fn collectResourceListInteractions(list: ResourceList, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
    if (list.items.len == 0) return;
    var cursor = resourceCursor(bounds);
    for (list.items) |item| {
        const item_bounds = cursor.nextWithinBounds(measureResourceItem(item, .{})) orelse break;
        try base_info_row.collectInteractions(collector, item_bounds, .{ .id = item.id, .title = item.label, .detail = item.detail, .hit_kind = .button });
    }
}

pub fn measureResourceList(list: ResourceList, constraints: layout.Constraints) layout.Measurement {
    const content = constraints.inner(resourceInsets());
    var preferred_width: f32 = 0;
    var preferred_height: f32 = 0;
    for (list.items, 0..) |item, index| {
        if (index != 0) preferred_height += resource_item_gap;
        const row = measureResourceItem(item, content);
        preferred_width = @max(preferred_width, row.preferred.w);
        preferred_height += row.preferred.h;
    }
    return layout.Measurement.flexible(
        .{ .w = resource_row_metrics.min_width, .h = resource_padding_y * 2.0 },
        .{ .w = preferred_width, .h = preferred_height },
        .{ .w = constraints.width.limit(preferred_width), .h = preferred_height },
    ).withInsets(resourceInsets()).applyExact(constraints);
}

pub fn writeHtml(list: ResourceList, out: []u8) HtmlError![]u8 {
    if (list.items.len == 0) return error.InvalidHtml;
    var writer = HtmlWriter.init(out);
    try writer.writeAll("<ul data-er-component=\"resource-list\">");
    for (list.items) |item| {
        if (item.label.len == 0 or item.href.len == 0 or item.detail.len == 0) return error.InvalidHtml;
        try writer.writeAll("<li");
        try writer.writeAttrInt("data-er-id", item.id);
        try writer.writeAll("><a");
        try writer.writeAttrText("href", item.href);
        try writer.writeByte('>');
        try writer.writeEscapedText(item.label);
        try writer.writeAll("</a><p>");
        try writer.writeEscapedText(item.detail);
        try writer.writeAll("</p></li>");
    }
    try writer.writeAll("</ul>");
    return writer.written();
}

pub fn writeMarkdown(list: ResourceList, out: []u8) MarkdownError![]u8 {
    if (list.items.len == 0) return error.InvalidMarkdown;
    var writer = MarkdownWriter.init(out);
    try writer.beginDirective("resources");
    for (list.items) |item| {
        if (item.label.len == 0 or item.href.len == 0 or item.detail.len == 0) return error.InvalidMarkdown;
        try writer.fieldInt("item", item.id);
        try writer.fieldText("label", item.label);
        try writer.fieldText("href", item.href);
        try writer.fieldText("detail", item.detail);
    }
    try writer.endDirective();
    return writer.written();
}

pub fn readMarkdown(markdown: []const u8, out_items: []ResourceItem, text_out: []u8) MarkdownError!ResourceList {
    const prefix = ":::resources\n";
    const body = try common.readMarkdownDirectiveBody(markdown, ":::resources", prefix);
    var text = MarkdownTextArena.init(text_out);
    var item_count: usize = 0;
    var cursor = MarkdownCursor.init(body);
    while (!cursor.done()) {
        if (item_count == out_items.len) return error.MarkdownBudgetExceeded;
        const id = try common.parseMarkdownU32(try cursor.lineAfter("item: "));
        const label = try text.unescapeInline(try cursor.fieldBetween("\nlabel: ", "\nhref: "));
        const href = try text.unescapeInline(try cursor.fieldBetween("\nhref: ", "\ndetail: "));
        const detail = try text.unescapeInline(try cursor.finalField("\ndetail: ", "\nitem: "));
        if (label.len == 0 or href.len == 0 or detail.len == 0) return error.InvalidMarkdown;
        out_items[item_count] = .{ .id = id, .label = label, .href = href, .detail = detail };
        item_count += 1;
        try cursor.skipNewline();
    }
    if (item_count == 0) return error.InvalidMarkdown;
    return .{ .items = out_items[0..item_count] };
}

pub fn readHtml(html: []const u8, out_items: []ResourceItem, text_out: []u8) HtmlError!ResourceList {
    const body = common.takeWrapped(html, "<ul data-er-component=\"resource-list\">", "</ul>") orelse {
        if (std.mem.startsWith(u8, html, "<ul")) return error.InvalidHtml;
        return error.UnsupportedHtml;
    };
    var text = HtmlTextArena.init(text_out);
    const items = try readItemsHtml(body, out_items, &text);
    return .{ .items = items };
}

fn readItemsHtml(html: []const u8, out_items: []ResourceItem, text: *HtmlTextArena) HtmlError![]const ResourceItem {
    var cursor = HtmlCursor.init(html);
    var item_count: usize = 0;
    while (!cursor.done()) {
        if (item_count == out_items.len) return error.HtmlBudgetExceeded;
        const id = try common.parseHtmlU32(try cursor.fieldBetween("<li data-er-id=\"", "\"><a href=\""));
        const href = try text.unescape(try cursor.fieldBetween("\"><a href=\"", "\">"));
        const label = try text.unescape(try cursor.fieldBetween("\">", "</a><p>"));
        const detail = try text.unescape(try cursor.fieldBetween("</a><p>", "</p></li>"));
        try cursor.consume("</p></li>");
        if (href.len == 0 or label.len == 0 or detail.len == 0) return error.InvalidHtml;
        out_items[item_count] = .{ .id = id, .label = label, .href = href, .detail = detail };
        item_count += 1;
    }
    if (item_count == 0) return error.InvalidHtml;
    return out_items[0..item_count];
}

const resource_padding_x: f32 = 12.0;
const resource_padding_y: f32 = 12.0;
const resource_item_gap: f32 = 8.0;
const resource_row_metrics = base_info_row.Metrics{};

fn measureResourceItem(item: ResourceItem, constraints: layout.Constraints) layout.Measurement {
    return base_info_row.measure(item.label, item.detail, constraints, resource_row_metrics);
}

fn resourceCursor(bounds: ui.Rect) flex.Cursor {
    return flex.Cursor.init(bounds, .{ .axis = .vertical, .gap = resource_item_gap, .padding = resourceInsets() });
}

fn resourceInsets() layout.Insets {
    return .{ .top = resource_padding_y, .right = resource_padding_x, .bottom = resource_padding_y, .left = resource_padding_x };
}

test "resource list component renders links and collects hit targets" {
    const items = [_]ResourceItem{
        .{ .id = 38001, .label = "DNS simulator", .href = "#/demo/dns", .detail = "Watch the resolver answer a cached name." },
        .{ .id = 38002, .label = "TLS walkthrough", .href = "#/demo/tls", .detail = "Follow a protected connection from client to server." },
    };
    const list = ResourceList{ .items = &items };
    var commands: [96]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [4]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try list.render(&scene, ui.Rect.init(0, 0, 380, 190), .{});
    try list.collectInteractions(&collector, ui.Rect.init(0, 0, 380, 190));

    try std.testing.expect(hasText(scene.written(), "DNS simulator"));
    try std.testing.expect(hasText(scene.written(), "TLS walkthrough"));
    const hit = ui_input.hitTest(collector.written(), 24, 96).?;
    try std.testing.expectEqual(@as(u32, 38002), hit.id);
}

test "resource list measurement counts link rows" {
    const one = [_]ResourceItem{
        .{ .id = 38001, .label = "DNS simulator", .href = "#/demo/dns", .detail = "Watch the resolver answer a cached name." },
    };
    const many = [_]ResourceItem{
        one[0],
        .{ .id = 38002, .label = "TLS walkthrough", .href = "#/demo/tls", .detail = "Follow a protected connection from client to server." },
    };

    const single = (ResourceList{ .items = &one }).measure(.{ .width = .{ .exact = 320 }, .text_wrap = .wrap }, .{});
    const full = (ResourceList{ .items = &many }).measure(.{ .width = .{ .exact = 320 }, .text_wrap = .wrap }, .{});

    try std.testing.expectEqual(@as(f32, 320), full.preferred.w);
    try std.testing.expect(full.preferred.h > single.preferred.h);
}

test "resource list html codec roundtrips semantic links" {
    const items = [_]ResourceItem{
        .{ .id = 38101, .label = "Receipt viewer", .href = "#/tools/receipts", .detail = "Inspect object ids and signatures." },
        .{ .id = 38102, .label = "Identity & keys", .href = "#/lessons/identity", .detail = "Learn why accounts are not identity." },
    };
    const list = ResourceList{ .items = &items };
    var html: [768]u8 = undefined;
    var decoded_items: [2]ResourceItem = undefined;
    var text: [256]u8 = undefined;

    const encoded = try list.toHtml(&html);
    const decoded = try ResourceList.fromHtml(encoded, &decoded_items, &text);

    try std.testing.expectEqualStrings("<ul data-er-component=\"resource-list\"><li data-er-id=\"38101\"><a href=\"#/tools/receipts\">Receipt viewer</a><p>Inspect object ids and signatures.</p></li><li data-er-id=\"38102\"><a href=\"#/lessons/identity\">Identity &amp; keys</a><p>Learn why accounts are not identity.</p></li></ul>", encoded);
    try std.testing.expectEqual(@as(usize, 2), decoded.items.len);
    try std.testing.expectEqual(@as(u32, 38102), decoded.items[1].id);
    try std.testing.expectEqualStrings("Identity & keys", decoded.items[1].label);
    try std.testing.expectEqualStrings("#/lessons/identity", decoded.items[1].href);
    try std.testing.expectEqualStrings("Learn why accounts are not identity.", decoded.items[1].detail);
}

test "resource list html codec rejects malformed links" {
    var items: [2]ResourceItem = undefined;
    var text: [128]u8 = undefined;

    try std.testing.expectError(error.InvalidHtml, ResourceList.fromHtml("<ul><li><a href=\"#\">Plain</a></li></ul>", &items, &text));
    try std.testing.expectError(error.InvalidHtml, ResourceList.fromHtml("<ul data-er-component=\"resource-list\"></ul>", &items, &text));
    try std.testing.expectError(error.InvalidHtml, ResourceList.fromHtml("<ul data-er-component=\"resource-list\"><li data-er-id=\"x\"><a href=\"#\">Broken</a><p>Bad id</p></li></ul>", &items, &text));
    try std.testing.expectError(error.InvalidHtml, ResourceList.fromHtml("<ul data-er-component=\"resource-list\"><li data-er-id=\"1\"><a href=\"\">Broken</a><p>Missing href</p></li></ul>", &items, &text));
}

test "resource list registers explicit runtime descriptor" {
    const items = [_]ResourceItem{
        .{ .id = 38201, .label = "Receipt viewer", .href = "#/tools/receipts", .detail = "Inspect object ids and signatures." },
        .{ .id = 38202, .label = "Identity keys", .href = "#/lessons/identity", .detail = "Learn why accounts are not identity." },
    };
    const list = ResourceList{ .items = &items };
    var entries: [1]common.ComponentDescriptor = undefined;
    var registry = ComponentRegistry.init(&entries);
    var html: [768]u8 = undefined;
    var markdown: [768]u8 = undefined;
    var commands: [96]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [4]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try ResourceList.register(&registry);
    try std.testing.expectError(error.DuplicateComponent, ResourceList.register(&registry));
    try std.testing.expectEqualStrings("resource-list", registry.matchHtml("<ul data-er-component=\"resource-list\"></ul>").?.name);
    try std.testing.expectEqualStrings("resource-list", registry.matchMarkdown(":::resources\nitem: 1\n:::").?.name);

    const encoded_html = try registry.writeHtml("resource-list", &list, &html);
    const encoded_markdown = try registry.writeMarkdown("resource-list", &list, &markdown);
    try registry.render("resource-list", &list, &scene, ui.Rect.init(0, 0, 380, 190), .{});
    try registry.collectInteractions("resource-list", &list, &collector, ui.Rect.init(0, 0, 380, 190));

    try std.testing.expect(std.mem.indexOf(u8, encoded_html, "<ul data-er-component=\"resource-list\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded_markdown, ":::resources") != null);
    try std.testing.expect(hasText(scene.written(), "Receipt viewer"));
    try std.testing.expectEqual(@as(u32, 38202), ui_input.hitTest(collector.written(), 24, 96).?.id);
}

fn hasText(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| {
        if (command == .text and std.mem.eql(u8, command.text.value, value)) return true;
    }
    return false;
}
