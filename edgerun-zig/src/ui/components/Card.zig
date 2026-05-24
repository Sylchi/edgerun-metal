const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const base_surface = @import("base/Surface.zig");
const component_test = @import("TestSupport.zig");
const component_codec = @import("Codec.zig");

const Error = common.Error;
const HtmlError = common.HtmlError;
const HtmlTextArena = common.HtmlTextArena;
const HtmlWriter = common.HtmlWriter;
const MarkdownError = common.MarkdownError;
const MarkdownTextArena = common.MarkdownTextArena;
const MarkdownWriter = common.MarkdownWriter;
const RenderOptions = common.RenderOptions;

pub const Card = struct {
    title: []const u8,
    detail: []const u8,

    pub fn node(self: Card) ui.Node {
        return ui.cardNode(self.title, self.detail);
    }

    pub fn render(self: Card, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return base_surface.render(scene, bounds, .{ .title = self.title, .detail = self.detail }, options);
    }

    pub fn measure(self: Card, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return base_surface.measure(.{ .title = self.title, .detail = self.detail }, constraints);
    }

    pub fn toObject(self: Card, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.card, 0, self.title, self.detail, ui_out, object_out, req, epoch);
    }

    pub fn writeRecord(self: Card, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .card, 0, self.title, self.detail);
    }

    pub fn fromView(view: object.View) Error!Card {
        return switch (try component_codec.singleNode(view)) {
            .card => |card| .{ .title = card.title, .detail = card.detail },
            else => error.UnsupportedComponent,
        };
    }

    pub fn toHtml(self: Card, out: []u8) HtmlError![]u8 {
        return writeHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, text_out: []u8) HtmlError!Card {
        return readHtml(html, text_out);
    }

    pub fn toMarkdown(self: Card, out: []u8) MarkdownError![]u8 {
        return writeMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Card {
        return readMarkdown(markdown, text_out);
    }
};

pub fn writeHtml(card: Card, out: []u8) HtmlError![]u8 {
    var writer = HtmlWriter.init(out);
    try writeHtmlInto(&writer, card);
    return writer.written();
}

pub fn writeHtmlInto(writer: *HtmlWriter, card: Card) HtmlError!void {
    try writer.writeAll("<article data-er-component=\"card\"><h2>");
    try writer.writeEscapedText(card.title);
    try writer.writeAll("</h2><p>");
    try writer.writeEscapedText(card.detail);
    try writer.writeAll("</p></article>");
}

pub fn readHtml(html: []const u8, text_out: []u8) HtmlError!Card {
    var text = HtmlTextArena.init(text_out);
    return readHtmlWithArena(html, &text);
}

pub fn readHtmlWithArena(html: []const u8, text: *HtmlTextArena) HtmlError!Card {
    const prefix = "<article data-er-component=\"card\"><h2>";
    if (!std.mem.startsWith(u8, html, prefix)) return error.UnsupportedHtml;
    const title_end_relative = std.mem.indexOf(u8, html[prefix.len..], "</h2><p>") orelse return error.InvalidHtml;
    const detail_start = prefix.len + title_end_relative + "</h2><p>".len;
    if (!std.mem.endsWith(u8, html, "</p></article>")) return error.InvalidHtml;
    const title = try text.unescape(html[prefix.len .. prefix.len + title_end_relative]);
    const detail = try text.unescape(html[detail_start .. html.len - "</p></article>".len]);
    if (title.len == 0 or detail.len == 0) return error.InvalidHtml;
    return .{ .title = title, .detail = detail };
}

pub fn writeMarkdown(card: Card, out: []u8) MarkdownError![]u8 {
    var writer = MarkdownWriter.init(out);
    try writeMarkdownInto(&writer, card);
    return writer.written();
}

pub fn writeMarkdownInto(writer: *MarkdownWriter, card: Card) MarkdownError!void {
    if (card.title.len == 0 or card.detail.len == 0) return error.InvalidMarkdown;
    try writer.beginDirective("card");
    try writer.fieldText("title", card.title);
    try writer.fieldText("detail", card.detail);
    try writer.endDirective();
}

pub fn readMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Card {
    var text = MarkdownTextArena.init(text_out);
    return readMarkdownWithArena(markdown, &text);
}

pub fn readMarkdownWithArena(markdown: []const u8, text: *MarkdownTextArena) MarkdownError!Card {
    const prefix = ":::card\ntitle: ";
    const body = try common.readMarkdownDirectiveBody(markdown, ":::card", prefix);
    const title_end_relative = std.mem.indexOf(u8, body, "\ndetail: ") orelse return error.InvalidMarkdown;
    const detail_start = title_end_relative + "\ndetail: ".len;
    const title = try text.unescapeInline(body[0..title_end_relative]);
    const detail = try text.unescapeInline(body[detail_start..]);
    if (title.len == 0 or detail.len == 0) return error.InvalidMarkdown;
    return .{ .title = title, .detail = detail };
}

test "card component serializes to canonical object and deserializes" {
    const card = Card{ .title = "Project", .detail = "Interactive docs" };
    var ui_raw: [160]u8 = undefined;
    var object_raw: [object.header_size + 160]u8 = undefined;

    const canonical = card.toObject(&ui_raw, &object_raw, component_test.req(), component_test.epoch()).?;
    const decoded = try Card.fromView(try object.View.decode(canonical));

    try std.testing.expectEqualStrings(card.title, decoded.title);
    try std.testing.expectEqualStrings(card.detail, decoded.detail);
}

test "card component html and markdown codecs roundtrip escaped fields" {
    const card = Card{ .title = "Router & switch", .detail = "Moves packets > frames" };
    var encoded: [192]u8 = undefined;
    var text: [96]u8 = undefined;

    const html = try card.toHtml(&encoded);
    try std.testing.expectEqualStrings("<article data-er-component=\"card\"><h2>Router &amp; switch</h2><p>Moves packets &gt; frames</p></article>", html);
    const html_decoded = try Card.fromHtml(html, &text);
    try std.testing.expectEqualStrings(card.title, html_decoded.title);
    try std.testing.expectEqualStrings(card.detail, html_decoded.detail);

    const markdown = try card.toMarkdown(&encoded);
    const markdown_decoded = try Card.fromMarkdown(markdown, &text);

    try std.testing.expectEqualStrings(card.title, markdown_decoded.title);
    try std.testing.expectEqualStrings(card.detail, markdown_decoded.detail);
}
