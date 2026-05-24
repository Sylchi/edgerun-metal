const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
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

pub const RowItem = struct {
    id: u32,
    title: []const u8,
    detail: []const u8,

    pub fn node(self: RowItem) ui.Node {
        return .{ .row_item = .{ .id = self.id, .title = self.title, .detail = self.detail } };
    }

    pub fn render(self: RowItem, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return common.renderNode(scene, bounds, self.node(), options);
    }

    pub fn collectInteractions(self: RowItem, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return common.collectHit(collector, bounds, .row_item, self.id);
    }

    pub fn measure(self: RowItem, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return common.measureNode(self.node(), constraints);
    }

    pub fn toObject(self: RowItem, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return component_codec.twoStringObject(.row_item, self.id, self.title, self.detail, ui_out, object_out, req, epoch);
    }

    pub fn writeRecord(self: RowItem, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.twoStringRecord(writer, index, .row_item, self.id, self.title, self.detail);
    }

    pub fn fromView(view: object.View) Error!RowItem {
        return switch (try component_codec.singleNode(view)) {
            .row_item => |row| .{ .id = row.id, .title = row.title, .detail = row.detail },
            else => error.UnsupportedComponent,
        };
    }

    pub fn toHtml(self: RowItem, out: []u8) HtmlError![]u8 {
        return writeHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, text_out: []u8) HtmlError!RowItem {
        return readHtml(html, text_out);
    }

    pub fn toMarkdown(self: RowItem, out: []u8) MarkdownError![]u8 {
        return writeMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!RowItem {
        return readMarkdown(markdown, text_out);
    }
};

pub fn writeHtml(row: RowItem, out: []u8) HtmlError![]u8 {
    var writer = HtmlWriter.init(out);
    try writeHtmlInto(&writer, row);
    return writer.written();
}

pub fn writeHtmlInto(writer: *HtmlWriter, row: RowItem) HtmlError!void {
    try writer.writeAll("<div data-er-component=\"row-item\"");
    try writer.writeAttrInt("data-er-id", row.id);
    try writer.writeAll("><strong>");
    try writer.writeEscapedText(row.title);
    try writer.writeAll("</strong><span>");
    try writer.writeEscapedText(row.detail);
    try writer.writeAll("</span></div>");
}

pub fn readHtml(html: []const u8, text_out: []u8) HtmlError!RowItem {
    var text = HtmlTextArena.init(text_out);
    return readHtmlWithArena(html, &text);
}

pub fn readHtmlWithArena(html: []const u8, text: *HtmlTextArena) HtmlError!RowItem {
    const prefix = "<div data-er-component=\"row-item\" data-er-id=\"";
    if (!std.mem.startsWith(u8, html, prefix)) return error.UnsupportedHtml;
    const after_id_prefix = html[prefix.len..];
    const id_end = std.mem.indexOf(u8, after_id_prefix, "\"><strong>") orelse return error.InvalidHtml;
    const id = try common.parseHtmlU32(after_id_prefix[0..id_end]);
    const title_start = prefix.len + id_end + "\"><strong>".len;
    const title_end_relative = std.mem.indexOf(u8, html[title_start..], "</strong><span>") orelse return error.InvalidHtml;
    const detail_start = title_start + title_end_relative + "</strong><span>".len;
    if (!std.mem.endsWith(u8, html, "</span></div>")) return error.InvalidHtml;
    const title = try text.unescape(html[title_start .. title_start + title_end_relative]);
    const detail = try text.unescape(html[detail_start .. html.len - "</span></div>".len]);
    if (title.len == 0 or detail.len == 0) return error.InvalidHtml;
    return .{ .id = id, .title = title, .detail = detail };
}

pub fn writeMarkdown(row: RowItem, out: []u8) MarkdownError![]u8 {
    var writer = MarkdownWriter.init(out);
    try writeMarkdownInto(&writer, row);
    return writer.written();
}

pub fn writeMarkdownInto(writer: *MarkdownWriter, row: RowItem) MarkdownError!void {
    if (row.title.len == 0 or row.detail.len == 0) return error.InvalidMarkdown;
    try writer.beginDirective("row-item");
    try writer.fieldInt("id", row.id);
    try writer.fieldText("title", row.title);
    try writer.fieldText("detail", row.detail);
    try writer.endDirective();
}

pub fn readMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!RowItem {
    var text = MarkdownTextArena.init(text_out);
    return readMarkdownWithArena(markdown, &text);
}

pub fn readMarkdownWithArena(markdown: []const u8, text: *MarkdownTextArena) MarkdownError!RowItem {
    const decoded = try component_codec.readIdTwoTextDirectiveMarkdown(markdown, ":::row-item", ":::row-item\nid: ", "\ntitle: ", "\ndetail: ", text);
    return .{ .id = decoded.id, .title = decoded.first, .detail = decoded.second };
}

test "row item component serializes to canonical object and deserializes" {
    const row = RowItem{ .id = 20, .title = "object graph", .detail = "canonical data" };
    var ui_raw: [160]u8 = undefined;
    var object_raw: [object.header_size + 160]u8 = undefined;

    const canonical = row.toObject(&ui_raw, &object_raw, component_test.req(), component_test.epoch()).?;
    const decoded = try RowItem.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(row.id, decoded.id);
    try std.testing.expectEqualStrings(row.title, decoded.title);
    try std.testing.expectEqualStrings(row.detail, decoded.detail);
}

test "row item component html and markdown codecs roundtrip escaped fields" {
    const row = RowItem{ .id = 20, .title = "object <graph>", .detail = "canonical & typed" };
    var encoded: [256]u8 = undefined;
    var decoded_text: [96]u8 = undefined;

    const html = try row.toHtml(&encoded);
    try std.testing.expectEqualStrings("<div data-er-component=\"row-item\" data-er-id=\"20\"><strong>object &lt;graph&gt;</strong><span>canonical &amp; typed</span></div>", html);
    const html_decoded = try RowItem.fromHtml(html, &decoded_text);
    try std.testing.expectEqual(row.id, html_decoded.id);
    try std.testing.expectEqualStrings(row.title, html_decoded.title);
    try std.testing.expectEqualStrings(row.detail, html_decoded.detail);

    const markdown = try row.toMarkdown(&encoded);
    try std.testing.expectEqualStrings(":::row-item\nid: 20\ntitle: object <graph\\>\ndetail: canonical & typed\n:::", markdown);
    const markdown_decoded = try RowItem.fromMarkdown(markdown, &decoded_text);
    try std.testing.expectEqual(row.id, markdown_decoded.id);
    try std.testing.expectEqualStrings(row.title, markdown_decoded.title);
    try std.testing.expectEqualStrings(row.detail, markdown_decoded.detail);
}
