const std = @import("std");
const common = @import("../../ui_component_common.zig");
const component_io = @import("ComponentIO.zig");

pub const HtmlError = common.HtmlError;
pub const HtmlTextArena = common.HtmlTextArena;
pub const HtmlWriter = common.HtmlWriter;
pub const MarkdownError = common.MarkdownError;
pub const MarkdownTextArena = common.MarkdownTextArena;
pub const MarkdownWriter = common.MarkdownWriter;

pub fn writeHtml(comptime Component: type, region: anytype, out: []u8) HtmlError![]u8 {
    if (region.children.len == 0) return error.InvalidHtml;
    var writer = HtmlWriter.init(out);
    const tag = tagName(@TypeOf(region.tag), region.tag);
    try writer.writeByte('<');
    try writer.writeAll(tag);
    try writer.writeAttrRaw("data-er-component", "region");
    try writer.writeAttrText("aria-label", region.label);
    try writer.writeByte('>');
    for (region.children) |child| try component_io.writeHtmlInto(Component, &writer, child);
    try writer.writeAll("</");
    try writer.writeAll(tag);
    try writer.writeByte('>');
    return writer.written();
}

pub fn writeMarkdown(comptime Component: type, region: anytype, out: []u8) MarkdownError![]u8 {
    if (region.children.len == 0) return error.InvalidMarkdown;
    var writer = MarkdownWriter.init(out);
    try writer.beginDirective("region");
    try writer.fieldRaw("tag", tagName(@TypeOf(region.tag), region.tag));
    try writer.fieldText("label", region.label);
    for (region.children) |child| {
        try writer.writeByte('\n');
        try writer.writeAll(component_io.markdown_component_marker);
        try component_io.writeMarkdownInto(Component, &writer, child);
    }
    try writer.endDirective();
    return writer.written();
}

pub fn readHtml(comptime Region: type, comptime RegionTag: type, comptime Component: type, html: []const u8, out_components: []Component, text_out: []u8) HtmlError!Region {
    inline for (.{ .header, .main, .footer, .section, .article }) |tag| {
        const decoded = try readHtmlForTag(Region, RegionTag, Component, tag, html, out_components, text_out);
        if (decoded) |region| return region;
    }
    if (std.mem.startsWith(u8, html, "<header") or
        std.mem.startsWith(u8, html, "<main") or
        std.mem.startsWith(u8, html, "<footer") or
        std.mem.startsWith(u8, html, "<section") or
        std.mem.startsWith(u8, html, "<article") or
        std.mem.indexOf(u8, html, "data-er-component=\"region\"") != null) return error.InvalidHtml;
    return error.UnsupportedHtml;
}

pub fn readMarkdown(comptime Region: type, comptime RegionTag: type, comptime Component: type, markdown: []const u8, out_components: []Component, text_out: []u8) MarkdownError!Region {
    const prefix = ":::region\ntag: ";
    const body = try common.readMarkdownDirectiveBody(markdown, ":::region", prefix);
    const tag_end_relative = std.mem.indexOf(u8, body, "\nlabel: ") orelse return error.InvalidMarkdown;
    const tag = parseTagName(RegionTag, body[0..tag_end_relative]) orelse return error.InvalidMarkdown;
    const label_start = tag_end_relative + "\nlabel: ".len;
    const label_end_relative = std.mem.indexOf(u8, body[label_start..], component_io.markdown_next_component_marker) orelse return error.InvalidMarkdown;
    var text = MarkdownTextArena.init(text_out);
    const label = try text.unescapeInline(body[label_start .. label_start + label_end_relative]);
    const children_start = label_start + label_end_relative + 1;
    const children = try component_io.readListMarkdownWithArena(Component, body[children_start..], out_components, &text);
    return .{
        .tag = tag,
        .label = label,
        .children = children,
    };
}

fn readHtmlForTag(
    comptime Region: type,
    comptime RegionTag: type,
    comptime Component: type,
    comptime tag: RegionTag,
    html: []const u8,
    out_components: []Component,
    text_out: []u8,
) HtmlError!?Region {
    const prefix = switch (tag) {
        .header => "<header data-er-component=\"region\" aria-label=\"",
        .main => "<main data-er-component=\"region\" aria-label=\"",
        .footer => "<footer data-er-component=\"region\" aria-label=\"",
        .section => "<section data-er-component=\"region\" aria-label=\"",
        .article => "<article data-er-component=\"region\" aria-label=\"",
    };
    if (!std.mem.startsWith(u8, html, prefix)) return null;
    const after_label = html[prefix.len..];
    const label_end = std.mem.indexOf(u8, after_label, "\">") orelse return error.InvalidHtml;
    const suffix = switch (tag) {
        .header => "</header>",
        .main => "</main>",
        .footer => "</footer>",
        .section => "</section>",
        .article => "</article>",
    };
    if (!std.mem.endsWith(u8, html, suffix)) return error.InvalidHtml;

    var text = HtmlTextArena.init(text_out);
    const label = try text.unescape(after_label[0..label_end]);
    const children_start = prefix.len + label_end + "\">".len;
    const children_html = html[children_start .. html.len - suffix.len];
    const children = try component_io.readListHtmlWithArena(Component, children_html, out_components, &text);
    if (children.len == 0) return error.InvalidHtml;
    return .{ .tag = tag, .label = label, .children = children };
}

pub fn tagName(comptime RegionTag: type, tag: RegionTag) []const u8 {
    return switch (tag) {
        .header => "header",
        .main => "main",
        .footer => "footer",
        .section => "section",
        .article => "article",
    };
}

pub fn parseTagName(comptime RegionTag: type, value: []const u8) ?RegionTag {
    if (std.mem.eql(u8, value, "header")) return .header;
    if (std.mem.eql(u8, value, "main")) return .main;
    if (std.mem.eql(u8, value, "footer")) return .footer;
    if (std.mem.eql(u8, value, "section")) return .section;
    if (std.mem.eql(u8, value, "article")) return .article;
    return null;
}
