const std = @import("std");
const common = @import("../../ui_component_common.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const base_text_block = @import("base/TextBlock.zig");

const ComponentRegistry = common.ComponentRegistry;
const HtmlError = common.HtmlError;
const HtmlTextArena = common.HtmlTextArena;
const HtmlWriter = common.HtmlWriter;
const MarkdownError = common.MarkdownError;
const MarkdownTextArena = common.MarkdownTextArena;
const MarkdownWriter = common.MarkdownWriter;
const RegistryError = common.RegistryError;
const RenderOptions = common.RenderOptions;

pub const Heading = struct {
    level: u8,
    value: []const u8,

    pub fn render(self: Heading, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return renderHeading(self, scene, bounds, options);
    }

    pub fn measure(self: Heading, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return measureHeading(self, constraints);
    }

    pub fn toHtml(self: Heading, out: []u8) HtmlError![]u8 {
        return writeHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, text_out: []u8) HtmlError!Heading {
        return readHtml(html, text_out);
    }

    pub fn toMarkdown(self: Heading, out: []u8) MarkdownError![]u8 {
        return writeMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Heading {
        return readMarkdown(markdown, text_out);
    }

    pub fn register(registry: *ComponentRegistry) RegistryError!void {
        return common.registerDescriptor(registry, descriptor);
    }
};

pub const descriptor = common.ComponentDescriptor{
    .name = "heading",
    .html_prefix = "<h",
    .markdown_prefix = "#",
    .render = common.renderAdapter(Heading, renderHeading),
    .write_html = common.writeHtmlAdapter(Heading, writeHtml),
    .write_markdown = common.writeMarkdownAdapter(Heading, writeMarkdown),
};

pub fn register(registry: *ComponentRegistry) RegistryError!void {
    return common.registerDescriptor(registry, descriptor);
}

pub fn renderHeading(heading: Heading, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    if (!validHeadingLevel(heading.level)) return;
    try base_text_block.render(scene, bounds, heading.value, options.style.text, headingMetrics(heading.level));
}

pub fn measureHeading(heading: Heading, constraints: layout.Constraints) layout.Measurement {
    if (!validHeadingLevel(heading.level)) return layout.Measurement.fixed(.{ .w = 0, .h = 0 });
    return base_text_block.measure(heading.value, constraints, headingMetrics(heading.level));
}

pub fn writeHtml(heading: Heading, out: []u8) HtmlError![]u8 {
    if (!validHeadingLevel(heading.level)) return error.InvalidHtml;
    var writer = HtmlWriter.init(out);
    try writer.writeByte('<');
    try writer.writeByte('h');
    try writer.writeByte('0' + heading.level);
    try writer.writeAll(" data-er-component=\"heading\">");
    try writer.writeEscapedText(heading.value);
    try writer.writeAll("</h");
    try writer.writeByte('0' + heading.level);
    try writer.writeByte('>');
    return writer.written();
}

pub fn writeMarkdown(heading: Heading, out: []u8) MarkdownError![]u8 {
    if (!validHeadingLevel(heading.level) or heading.value.len == 0) return error.InvalidMarkdown;
    var writer = MarkdownWriter.init(out);
    var level: u8 = 0;
    while (level < heading.level) : (level += 1) try writer.writeByte('#');
    try writer.writeByte(' ');
    try writer.writeEscapedInline(heading.value);
    return writer.written();
}

pub fn readMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Heading {
    if (std.mem.indexOfScalar(u8, markdown, '\n') != null) return error.InvalidMarkdown;
    const level: u8 = if (std.mem.startsWith(u8, markdown, "### "))
        3
    else if (std.mem.startsWith(u8, markdown, "## "))
        2
    else if (std.mem.startsWith(u8, markdown, "# "))
        1
    else if (std.mem.startsWith(u8, markdown, "#"))
        return error.InvalidMarkdown
    else
        return error.UnsupportedMarkdown;
    const value_start: usize = @as(usize, level) + 1;
    var text = MarkdownTextArena.init(text_out);
    const value = try text.unescapeInline(markdown[value_start..]);
    if (value.len == 0) return error.InvalidMarkdown;
    return .{ .level = level, .value = value };
}

pub fn readHtml(html: []const u8, text_out: []u8) HtmlError!Heading {
    var text = HtmlTextArena.init(text_out);
    inline for (.{ 1, 2, 3 }) |level| {
        var prefix: [32]u8 = undefined;
        const prefix_text = std.fmt.bufPrint(&prefix, "<h{d} data-er-component=\"heading\">", .{level}) catch unreachable;
        var suffix: [6]u8 = undefined;
        const suffix_text = std.fmt.bufPrint(&suffix, "</h{d}>", .{level}) catch unreachable;
        if (common.takeWrapped(html, prefix_text, suffix_text)) |value| {
            return .{ .level = level, .value = try text.unescape(value) };
        }
    }
    if (std.mem.startsWith(u8, html, "<h")) return error.InvalidHtml;
    return error.UnsupportedHtml;
}

const heading_h1_line_h: f32 = 34.0;
const heading_h2_line_h: f32 = 26.0;
const heading_h3_line_h: f32 = 21.0;
const heading_h1_avg_w: f32 = 15.0;
const heading_h2_avg_w: f32 = 12.0;
const heading_h3_avg_w: f32 = 10.5;
const heading_max_lines: u32 = 3;

fn validHeadingLevel(level: u8) bool {
    return level >= 1 and level <= 3;
}

fn headingLineHeight(level: u8) f32 {
    return switch (level) {
        1 => heading_h1_line_h,
        2 => heading_h2_line_h,
        3 => heading_h3_line_h,
        else => unreachable,
    };
}

fn headingAverageWidth(level: u8) f32 {
    return switch (level) {
        1 => heading_h1_avg_w,
        2 => heading_h2_avg_w,
        3 => heading_h3_avg_w,
        else => unreachable,
    };
}

fn headingMetrics(level: u8) base_text_block.Metrics {
    return .{
        .line_height = headingLineHeight(level),
        .average_char_width = headingAverageWidth(level),
        .max_lines = heading_max_lines,
    };
}

test "heading component renders wrapped title text" {
    const heading = Heading{ .level = 2, .value = "Lookup path" };
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try heading.render(&scene, ui.Rect.init(0, 0, 360, 64), .{});

    try std.testing.expect(hasText(scene.written(), "Lookup path"));
}

test "heading measurement responds to constrained wrap width" {
    const heading = Heading{ .level = 2, .value = "DNS and TLS form a simple path when each part has one job" };

    const wide = heading.measure(.{ .width = .{ .exact = 420 }, .text_wrap = .wrap }, .{});
    const narrow = heading.measure(.{ .width = .{ .exact = 120 }, .text_wrap = .wrap }, .{});

    try std.testing.expectEqual(@as(f32, 420), wide.preferred.w);
    try std.testing.expect(narrow.preferred.h > wide.preferred.h);
}

test "heading html codec roundtrips semantic level and escaped text" {
    const heading = Heading{ .level = 2, .value = "TLS < DNS & TPM" };
    var html: [128]u8 = undefined;
    var text: [128]u8 = undefined;

    const encoded = try heading.toHtml(&html);
    const decoded = try Heading.fromHtml(encoded, &text);

    try std.testing.expectEqualStrings("<h2 data-er-component=\"heading\">TLS &lt; DNS &amp; TPM</h2>", encoded);
    try std.testing.expectEqual(@as(u8, 2), decoded.level);
    try std.testing.expectEqualStrings("TLS < DNS & TPM", decoded.value);
}

test "heading html codec rejects unsupported heading shapes" {
    var text: [64]u8 = undefined;

    try std.testing.expectError(error.InvalidHtml, Heading.fromHtml("<h4 data-er-component=\"heading\">Too deep</h4>", &text));
    try std.testing.expectError(error.InvalidHtml, Heading.fromHtml("<h2>Plain browser heading</h2>", &text));
    try std.testing.expectError(error.UnsupportedHtml, Heading.fromHtml("<p>Plain text</p>", &text));
}

test "heading markdown codec roundtrips escaped inline title" {
    const heading = Heading{ .level = 3, .value = "DNS & TLS: simple path" };
    var markdown: [128]u8 = undefined;
    var text: [128]u8 = undefined;

    const encoded = try heading.toMarkdown(&markdown);
    const decoded = try Heading.fromMarkdown(encoded, &text);

    try std.testing.expectEqualStrings("### DNS & TLS\\: simple path", encoded);
    try std.testing.expectEqual(@as(u8, 3), decoded.level);
    try std.testing.expectEqualStrings("DNS & TLS: simple path", decoded.value);
}

test "heading markdown codec rejects ambiguous or empty headings" {
    var text: [64]u8 = undefined;

    try std.testing.expectError(error.InvalidMarkdown, Heading.fromMarkdown("#### Too deep", &text));
    try std.testing.expectError(error.InvalidMarkdown, Heading.fromMarkdown("#", &text));
    try std.testing.expectError(error.InvalidMarkdown, Heading.fromMarkdown("# ", &text));
    try std.testing.expectError(error.UnsupportedMarkdown, Heading.fromMarkdown("Plain paragraph", &text));
}

test "heading registers explicit runtime descriptor" {
    const heading = Heading{ .level = 1, .value = "How DNS Works" };
    var entries: [1]common.ComponentDescriptor = undefined;
    var registry = ComponentRegistry.init(&entries);
    var html: [128]u8 = undefined;
    var markdown: [128]u8 = undefined;
    var commands: [8]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try Heading.register(&registry);
    try std.testing.expectError(error.DuplicateComponent, Heading.register(&registry));
    try std.testing.expectEqualStrings("heading", registry.matchHtml("<h2 data-er-component=\"heading\">Title</h2>").?.name);
    try std.testing.expectEqualStrings("heading", registry.matchMarkdown("## Title").?.name);

    const encoded_html = try registry.writeHtml("heading", &heading, &html);
    const encoded_markdown = try registry.writeMarkdown("heading", &heading, &markdown);
    try registry.render("heading", &heading, &scene, ui.Rect.init(0, 0, 360, 64), .{});

    try std.testing.expectEqualStrings("<h1 data-er-component=\"heading\">How DNS Works</h1>", encoded_html);
    try std.testing.expectEqualStrings("# How DNS Works", encoded_markdown);
    try std.testing.expect(hasText(scene.written(), "How DNS Works"));
}

fn hasText(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| {
        if (command == .text and std.mem.eql(u8, command.text.value, value)) return true;
    }
    return false;
}
