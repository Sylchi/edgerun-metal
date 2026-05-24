const std = @import("std");
const common = @import("../../ui_component_common.zig");
const base_label_hit = @import("base/LabelHit.zig");
const base_surface = @import("base/Surface.zig");
const interaction = @import("../../ui_interaction.zig");
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

pub const NavItem = struct {
    id: u32,
    label: []const u8,
    href: []const u8 = "",
    active: bool = false,
};

pub const Nav = struct {
    label: []const u8 = "",
    items: []const NavItem,

    pub fn render(self: Nav, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return renderNav(self, scene, bounds, options);
    }

    pub fn collectInteractions(self: Nav, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return collectNavInteractions(self, collector, bounds);
    }

    pub fn toHtml(self: Nav, out: []u8) HtmlError![]u8 {
        return writeHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, out_items: []NavItem, text_out: []u8) HtmlError!Nav {
        return readHtml(html, out_items, text_out);
    }

    pub fn toMarkdown(self: Nav, out: []u8) MarkdownError![]u8 {
        return writeMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, out_items: []NavItem, text_out: []u8) MarkdownError!Nav {
        return readMarkdown(markdown, out_items, text_out);
    }

    pub fn register(registry: *ComponentRegistry) RegistryError!void {
        return common.registerDescriptor(registry, descriptor);
    }
};

pub const descriptor = common.ComponentDescriptor{
    .name = "nav",
    .html_prefix = "<nav data-er-component=\"nav\"",
    .markdown_prefix = ":::nav",
    .render = common.renderAdapter(Nav, renderNav),
    .collect_interactions = common.collectAdapter(Nav, collectNavInteractions),
    .write_html = common.writeHtmlAdapter(Nav, writeHtml),
    .write_markdown = common.writeMarkdownAdapter(Nav, writeMarkdown),
};

pub fn register(registry: *ComponentRegistry) RegistryError!void {
    return common.registerDescriptor(registry, descriptor);
}

pub fn renderNav(nav: Nav, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    if (nav.items.len == 0) return;
    const style = options.style;
    try base_surface.renderFrame(scene, bounds, options);

    var cursor_x = bounds.x + nav_padding_x;
    const item_y = bounds.y + @max(0.0, (bounds.h - nav_item_h) * 0.5);
    const item_right = bounds.x + bounds.w - nav_padding_x;
    for (nav.items) |item| {
        const item_w = navItemWidth(item.label);
        if (cursor_x + item_w > item_right) break;
        const item_bounds = ui.Rect.init(cursor_x, item_y, item_w, nav_item_h);
        if (item.active) {
            try scene.pushRect(item_bounds, style.row, .fill, nav_item_radius, 0.0);
            try scene.pushRect(ui.Rect.init(item_bounds.x + nav_active_inset_x, item_bounds.y + item_bounds.h - nav_active_h, @max(1.0, item_bounds.w - nav_active_inset_x * 2.0), nav_active_h), style.accent, .fill, nav_active_h * 0.5, 0.0);
        }
        try base_label_hit.render(scene, item_bounds, .{ .id = item.id, .label = item.label, .color = if (item.active) style.text else style.muted }, nav_label_insets);
        cursor_x += item_w + nav_item_gap;
    }
}

pub fn collectNavInteractions(nav: Nav, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
    if (nav.items.len == 0) return;
    var cursor_x = bounds.x + nav_padding_x;
    const item_y = bounds.y + @max(0.0, (bounds.h - nav_item_h) * 0.5);
    const item_right = bounds.x + bounds.w - nav_padding_x;
    for (nav.items) |item| {
        const item_w = navItemWidth(item.label);
        if (cursor_x + item_w > item_right) break;
        try base_label_hit.collect(collector, ui.Rect.init(cursor_x, item_y, item_w, nav_item_h), .{ .id = item.id, .label = item.label, .color = ui.Color.text });
        cursor_x += item_w + nav_item_gap;
    }
}

pub fn writeHtml(nav: Nav, out: []u8) HtmlError![]u8 {
    if (nav.items.len == 0) return error.InvalidHtml;
    var writer = HtmlWriter.init(out);
    try writer.writeAll("<nav data-er-component=\"nav\"");
    try writer.writeAttrText("aria-label", nav.label);
    try writer.writeByte('>');
    for (nav.items) |item| {
        try writer.writeAll("<a");
        try writer.writeAttrInt("data-er-id", item.id);
        try writer.writeAttrBool("data-er-active", item.active);
        try writer.writeAttrText("href", item.href);
        try writer.writeByte('>');
        try writer.writeEscapedText(item.label);
        try writer.writeAll("</a>");
    }
    try writer.writeAll("</nav>");
    return writer.written();
}

pub fn writeMarkdown(nav: Nav, out: []u8) MarkdownError![]u8 {
    if (nav.items.len == 0) return error.InvalidMarkdown;
    var writer = MarkdownWriter.init(out);
    try writer.beginDirective("nav");
    try writer.fieldText("label", nav.label);
    for (nav.items) |item| {
        if (item.label.len == 0) return error.InvalidMarkdown;
        try writer.fieldInt("item", item.id);
        try writer.fieldBool("active", item.active);
        try writer.fieldText("href", item.href);
        try writer.fieldText("label", item.label);
    }
    try writer.endDirective();
    return writer.written();
}

pub fn readMarkdown(markdown: []const u8, out_items: []NavItem, text_out: []u8) MarkdownError!Nav {
    const prefix = ":::nav\nlabel: ";
    const body = try common.readMarkdownDirectiveBody(markdown, ":::nav", prefix);
    const label_end_relative = std.mem.indexOf(u8, body, "\nitem: ") orelse return error.InvalidMarkdown;
    var text = MarkdownTextArena.init(text_out);
    const nav_label = try text.unescapeInline(body[0..label_end_relative]);
    var item_count: usize = 0;
    var cursor = MarkdownCursor.init(body[label_end_relative + 1 ..]);
    while (!cursor.done()) {
        if (item_count == out_items.len) return error.MarkdownBudgetExceeded;
        const id = try common.parseMarkdownU32(try cursor.lineAfter("item: "));
        const active = try common.parseMarkdownBool(try cursor.fieldBetween("\nactive: ", "\nhref: "));
        const href = try text.unescapeInline(try cursor.fieldBetween("\nhref: ", "\nlabel: "));
        const item_label = try text.unescapeInline(try cursor.finalField("\nlabel: ", "\nitem: "));
        if (item_label.len == 0) return error.InvalidMarkdown;
        out_items[item_count] = .{ .id = id, .label = item_label, .href = href, .active = active };
        item_count += 1;
        try cursor.skipNewline();
    }
    if (item_count == 0) return error.InvalidMarkdown;
    return .{ .label = nav_label, .items = out_items[0..item_count] };
}

pub fn readHtml(html: []const u8, out_items: []NavItem, text_out: []u8) HtmlError!Nav {
    const prefix = "<nav data-er-component=\"nav\" aria-label=\"";
    if (!std.mem.startsWith(u8, html, prefix)) {
        if (std.mem.startsWith(u8, html, "<nav")) return error.InvalidHtml;
        return error.UnsupportedHtml;
    }
    const after_label = html[prefix.len..];
    const label_end = std.mem.indexOf(u8, after_label, "\">") orelse return error.InvalidHtml;
    if (!std.mem.endsWith(u8, html, "</nav>")) return error.InvalidHtml;

    var text = HtmlTextArena.init(text_out);
    const label = try text.unescape(after_label[0..label_end]);
    const items_start = prefix.len + label_end + "\">".len;
    const items_html = html[items_start .. html.len - "</nav>".len];
    const items = try readItemsHtml(items_html, out_items, &text);
    return .{ .label = label, .items = items };
}

fn readItemsHtml(html: []const u8, out_items: []NavItem, text: *HtmlTextArena) HtmlError![]const NavItem {
    var cursor = HtmlCursor.init(html);
    var item_count: usize = 0;
    while (!cursor.done()) {
        if (item_count == out_items.len) return error.HtmlBudgetExceeded;
        const id = try common.parseHtmlU32(try cursor.fieldBetween("<a data-er-id=\"", "\" data-er-active=\""));
        const active = try common.parseHtmlBool(try cursor.fieldBetween("\" data-er-active=\"", "\" href=\""));
        const href = try text.unescape(try cursor.fieldBetween("\" href=\"", "\">"));
        const label = try text.unescape(try cursor.fieldBetween("\">", "</a>"));
        try cursor.consume("</a>");
        out_items[item_count] = .{
            .id = id,
            .label = label,
            .href = href,
            .active = active,
        };
        item_count += 1;
    }
    if (item_count == 0) return error.InvalidHtml;
    return out_items[0..item_count];
}

const nav_padding_x: f32 = 8.0;
const nav_item_h: f32 = 34.0;
const nav_item_gap: f32 = 6.0;
const nav_item_radius: f32 = 7.0;
const nav_item_padding_x: f32 = 14.0;
const nav_item_text_y: f32 = 9.0;
const nav_item_avg_w: f32 = 8.5;
const nav_item_min_w: f32 = 44.0;
const nav_active_h: f32 = 3.0;
const nav_active_inset_x: f32 = 12.0;
const nav_label_insets = base_label_hit.Insets{ .x = nav_item_padding_x, .y = nav_item_text_y };
const nav_width_metrics = base_label_hit.WidthMetrics{
    .average_char_width = nav_item_avg_w,
    .min_width = nav_item_min_w,
    .padding_x = nav_item_padding_x,
};

fn navItemWidth(label: []const u8) f32 {
    return base_label_hit.width(label, nav_width_metrics);
}

test "nav component renders active item and collects hit targets" {
    const items = [_]NavItem{
        .{ .id = 30011, .label = "Academy", .href = "#/academy", .active = true },
        .{ .id = 30012, .label = "Systems", .href = "#/systems" },
        .{ .id = 30013, .label = "Security", .href = "#/security" },
    };
    const nav = Nav{ .label = "Academy sections", .items = &items };
    var commands: [64]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [8]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try nav.render(&scene, ui.Rect.init(0, 0, 360, 48), .{});
    try nav.collectInteractions(&collector, ui.Rect.init(0, 0, 360, 48));

    try std.testing.expect(hasText(scene.written(), "Academy"));
    try std.testing.expect(hasText(scene.written(), "Security"));
    const hit = ui_input.hitTest(collector.written(), 20, 24).?;
    try std.testing.expectEqual(@as(u32, 30011), hit.id);
}

test "nav html codec roundtrips semantic nav" {
    const items = [_]NavItem{
        .{ .id = 30021, .label = "Start & Map", .href = "#/start?mode=human", .active = true },
        .{ .id = 30022, .label = "Network < DNS", .href = "#/network" },
    };
    const nav = Nav{ .label = "Academy & Lessons", .items = &items };
    var html: [512]u8 = undefined;
    var decoded_items: [2]NavItem = undefined;
    var text: [256]u8 = undefined;

    const encoded = try nav.toHtml(&html);
    const decoded = try Nav.fromHtml(encoded, &decoded_items, &text);

    try std.testing.expectEqualStrings("<nav data-er-component=\"nav\" aria-label=\"Academy &amp; Lessons\"><a data-er-id=\"30021\" data-er-active=\"true\" href=\"#/start?mode=human\">Start &amp; Map</a><a data-er-id=\"30022\" data-er-active=\"false\" href=\"#/network\">Network &lt; DNS</a></nav>", encoded);
    try std.testing.expectEqualStrings("Academy & Lessons", decoded.label);
    try std.testing.expectEqual(@as(usize, 2), decoded.items.len);
    try std.testing.expectEqual(@as(u32, 30021), decoded.items[0].id);
    try std.testing.expect(decoded.items[0].active);
    try std.testing.expectEqualStrings("#/start?mode=human", decoded.items[0].href);
    try std.testing.expectEqualStrings("Network < DNS", decoded.items[1].label);
}

test "nav html codec rejects malformed nav" {
    var items: [2]NavItem = undefined;
    var text: [128]u8 = undefined;

    try std.testing.expectError(error.InvalidHtml, Nav.fromHtml("<nav><a href=\"#\">Plain</a></nav>", &items, &text));
    try std.testing.expectError(error.InvalidHtml, Nav.fromHtml("<nav data-er-component=\"nav\" aria-label=\"Main\"><a data-er-id=\"x\" data-er-active=\"false\" href=\"#\">Broken</a></nav>", &items, &text));
    try std.testing.expectError(error.InvalidHtml, Nav.fromHtml("<nav data-er-component=\"nav\" aria-label=\"Main\"><a data-er-id=\"1\" data-er-active=\"maybe\" href=\"#\">Broken</a></nav>", &items, &text));
    try std.testing.expectError(error.InvalidHtml, Nav.fromHtml("<nav data-er-component=\"nav\" aria-label=\"Main\"></nav>", &items, &text));
}

test "nav registers explicit runtime descriptor" {
    const items = [_]NavItem{
        .{ .id = 30031, .label = "Academy", .href = "#/academy", .active = true },
        .{ .id = 30032, .label = "Security", .href = "#/security" },
    };
    const nav = Nav{ .label = "Academy sections", .items = &items };
    var entries: [1]common.ComponentDescriptor = undefined;
    var registry = ComponentRegistry.init(&entries);
    var html: [512]u8 = undefined;
    var markdown: [512]u8 = undefined;
    var commands: [64]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [4]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try Nav.register(&registry);
    try std.testing.expectError(error.DuplicateComponent, Nav.register(&registry));
    try std.testing.expectEqualStrings("nav", registry.matchHtml("<nav data-er-component=\"nav\"></nav>").?.name);
    try std.testing.expectEqualStrings("nav", registry.matchMarkdown(":::nav\nlabel: Main\n:::").?.name);

    const encoded_html = try registry.writeHtml("nav", &nav, &html);
    const encoded_markdown = try registry.writeMarkdown("nav", &nav, &markdown);
    try registry.render("nav", &nav, &scene, ui.Rect.init(0, 0, 360, 48), .{});
    try registry.collectInteractions("nav", &nav, &collector, ui.Rect.init(0, 0, 360, 48));

    try std.testing.expect(std.mem.indexOf(u8, encoded_html, "<nav data-er-component=\"nav\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded_markdown, ":::nav") != null);
    try std.testing.expect(hasText(scene.written(), "Academy"));
    try std.testing.expectEqual(@as(u32, 30031), ui_input.hitTest(collector.written(), 20, 24).?.id);
}

fn hasText(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| {
        if (command == .text and std.mem.eql(u8, command.text.value, value)) return true;
    }
    return false;
}
