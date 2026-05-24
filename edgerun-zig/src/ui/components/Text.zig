const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
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

pub const Text = struct {
    value: []const u8,

    pub fn node(self: Text) ui.Node {
        return .{ .text = .{ .value = self.value } };
    }

    pub fn render(self: Text, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return common.renderNode(scene, bounds, self.node(), options);
    }

    pub fn measure(self: Text, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        const measured = layout.measureText(self.value, constraints, .{
            .line_height = text_line_height,
            .average_char_width = text_average_w,
            .max_lines = text_max_lines,
        });
        return layout.Measurement.flexible(
            .{ .w = @min(text_min_width, measured.preferred.w), .h = @min(text_line_height, measured.preferred.h) },
            measured.preferred,
            measured.max,
        ).applyExact(constraints);
    }

    pub fn toObject(self: Text, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return component_codec.oneStringObject(.text, 0, self.value, ui_out, object_out, req, epoch);
    }

    pub fn writeRecord(self: Text, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.oneStringRecord(writer, index, .text, 0, self.value);
    }

    pub fn fromView(view: object.View) Error!Text {
        return switch (try component_codec.singleNode(view)) {
            .text => |text| .{ .value = text.value },
            else => error.UnsupportedComponent,
        };
    }

    pub fn toHtml(self: Text, out: []u8) HtmlError![]u8 {
        return writeHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, text_out: []u8) HtmlError!Text {
        return readHtml(html, text_out);
    }

    pub fn toMarkdown(self: Text, out: []u8) MarkdownError![]u8 {
        return writeMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Text {
        return readMarkdown(markdown, text_out);
    }
};

const text_line_height: f32 = 18.0;
const text_average_w: f32 = 8.0;
const text_max_lines: usize = 8;
const text_min_width: f32 = 24.0;

pub fn writeHtmlInto(writer: *HtmlWriter, text: Text) HtmlError!void {
    try writer.writeAll("<p data-er-component=\"text\">");
    try writer.writeEscapedText(text.value);
    try writer.writeAll("</p>");
}

pub fn writeHtml(text: Text, out: []u8) HtmlError![]u8 {
    var writer = HtmlWriter.init(out);
    try writeHtmlInto(&writer, text);
    return writer.written();
}

pub fn readHtml(html: []const u8, text_out: []u8) HtmlError!Text {
    var arena = HtmlTextArena.init(text_out);
    const value = common.takeWrapped(html, "<p data-er-component=\"text\">", "</p>") orelse return error.InvalidHtml;
    return .{ .value = try arena.unescape(value) };
}

pub fn writeMarkdown(text: Text, out: []u8) MarkdownError![]u8 {
    var writer = MarkdownWriter.init(out);
    try writeMarkdownInto(&writer, text);
    return writer.written();
}

pub fn writeMarkdownInto(writer: *MarkdownWriter, text: Text) MarkdownError!void {
    if (text.value.len == 0) return error.InvalidMarkdown;
    try writer.writeEscapedInline(text.value);
}

pub fn readMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Text {
    var arena = MarkdownTextArena.init(text_out);
    return readMarkdownWithArena(markdown, &arena);
}

pub fn readMarkdownWithArena(markdown: []const u8, arena: *MarkdownTextArena) MarkdownError!Text {
    if (markdown.len == 0 or std.mem.indexOfScalar(u8, markdown, '\n') != null) return error.InvalidMarkdown;
    if (std.mem.startsWith(u8, markdown, ":::")) return error.UnsupportedMarkdown;
    return .{ .value = try arena.unescapeInline(markdown) };
}

test "text component serializes to canonical object and deserializes" {
    const text = Text{ .value = "DNS asks, resolver answers." };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = text.toObject(&ui_raw, &object_raw, component_test.req(), component_test.epoch()).?;
    const decoded = try Text.fromView(try object.View.decode(canonical));

    try std.testing.expectEqualStrings(text.value, decoded.value);
}

test "text component html and markdown codecs roundtrip escaped text" {
    const text = Text{ .value = "TLS > DNS & cache" };
    var html: [128]u8 = undefined;
    var html_text: [64]u8 = undefined;
    var markdown: [128]u8 = undefined;
    var markdown_text: [64]u8 = undefined;

    const encoded_html = try text.toHtml(&html);
    const html_decoded = try Text.fromHtml(encoded_html, &html_text);
    const encoded_markdown = try text.toMarkdown(&markdown);
    const markdown_decoded = try Text.fromMarkdown(encoded_markdown, &markdown_text);

    try std.testing.expectEqualStrings(text.value, html_decoded.value);
    try std.testing.expectEqualStrings(text.value, markdown_decoded.value);
}
