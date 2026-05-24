const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const layout = @import("../../layouts/Types.zig");
const object = @import("../../object.zig");
const ui = @import("../../ui.zig");
const base_badge = @import("base/Badge.zig");
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

pub const Badge = struct {
    label: []const u8,

    pub fn node(self: Badge) ui.Node {
        return ui.badgeNode(self.label);
    }

    pub fn render(self: Badge, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return base_badge.render(scene, bounds, self.label, options);
    }

    pub fn measure(self: Badge, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return base_badge.measure(self.label, constraints);
    }

    pub fn toObject(self: Badge, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return component_codec.oneStringObject(.badge, 0, self.label, ui_out, object_out, req, epoch);
    }

    pub fn writeRecord(self: Badge, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.oneStringRecord(writer, index, .badge, 0, self.label);
    }

    pub fn fromView(view: object.View) Error!Badge {
        return switch (try component_codec.singleNode(view)) {
            .badge => |badge| .{ .label = badge.label },
            else => error.UnsupportedComponent,
        };
    }

    pub fn toHtml(self: Badge, out: []u8) HtmlError![]u8 {
        return writeHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, text_out: []u8) HtmlError!Badge {
        return readHtml(html, text_out);
    }

    pub fn toMarkdown(self: Badge, out: []u8) MarkdownError![]u8 {
        return writeMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Badge {
        return readMarkdown(markdown, text_out);
    }
};

pub fn writeHtmlInto(writer: *HtmlWriter, badge: Badge) HtmlError!void {
    try writer.writeAll("<span data-er-component=\"badge\">");
    try writer.writeEscapedText(badge.label);
    try writer.writeAll("</span>");
}

pub fn writeHtml(badge: Badge, out: []u8) HtmlError![]u8 {
    var writer = HtmlWriter.init(out);
    try writeHtmlInto(&writer, badge);
    return writer.written();
}

pub fn readHtml(html: []const u8, text_out: []u8) HtmlError!Badge {
    var arena = HtmlTextArena.init(text_out);
    const value = common.takeWrapped(html, "<span data-er-component=\"badge\">", "</span>") orelse return error.InvalidHtml;
    return .{ .label = try arena.unescape(value) };
}

pub fn writeMarkdown(badge: Badge, out: []u8) MarkdownError![]u8 {
    var writer = MarkdownWriter.init(out);
    try writeMarkdownInto(&writer, badge);
    return writer.written();
}

pub fn writeMarkdownInto(writer: *MarkdownWriter, badge: Badge) MarkdownError!void {
    if (badge.label.len == 0) return error.InvalidMarkdown;
    try writer.beginDirective("badge");
    try writer.fieldText("label", badge.label);
    try writer.endDirective();
}

pub fn readMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Badge {
    var arena = MarkdownTextArena.init(text_out);
    return readMarkdownWithArena(markdown, &arena);
}

pub fn readMarkdownWithArena(markdown: []const u8, arena: *MarkdownTextArena) MarkdownError!Badge {
    const label = readSingleFieldDirectiveMarkdown(markdown, ":::badge\nlabel: ", arena) catch |err| switch (err) {
        error.UnsupportedMarkdown => if (std.mem.startsWith(u8, markdown, ":::badge")) return error.InvalidMarkdown else return error.UnsupportedMarkdown,
        else => return error.InvalidMarkdown,
    };
    return .{ .label = label };
}

fn readSingleFieldDirectiveMarkdown(markdown: []const u8, prefix: []const u8, arena: *MarkdownTextArena) MarkdownError![]const u8 {
    if (!std.mem.startsWith(u8, markdown, prefix)) return error.UnsupportedMarkdown;
    if (!std.mem.endsWith(u8, markdown, "\n:::")) return error.InvalidMarkdown;
    const value = markdown[prefix.len .. markdown.len - "\n:::".len];
    if (value.len == 0 or std.mem.indexOfScalar(u8, value, '\n') != null) return error.InvalidMarkdown;
    return arena.unescapeInline(value);
}

test "badge component serializes to canonical object and deserializes" {
    const badge = Badge{ .label = "Ready" };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = badge.toObject(&ui_raw, &object_raw, component_test.req(), component_test.epoch()).?;
    const decoded = try Badge.fromView(try object.View.decode(canonical));

    try std.testing.expectEqualStrings("Ready", decoded.label);
}

test "badge component html and markdown codecs roundtrip escaped label" {
    const badge = Badge{ .label = "TLS & DNS" };
    var html: [128]u8 = undefined;
    var html_text: [64]u8 = undefined;
    var markdown: [128]u8 = undefined;
    var markdown_text: [64]u8 = undefined;

    const encoded_html = try badge.toHtml(&html);
    const html_decoded = try Badge.fromHtml(encoded_html, &html_text);
    const encoded_markdown = try badge.toMarkdown(&markdown);
    const markdown_decoded = try Badge.fromMarkdown(encoded_markdown, &markdown_text);

    try std.testing.expectEqualStrings(badge.label, html_decoded.label);
    try std.testing.expectEqualStrings(badge.label, markdown_decoded.label);
}
