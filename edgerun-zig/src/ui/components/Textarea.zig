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

pub const Textarea = struct {
    id: u32,
    placeholder: []const u8,

    pub fn node(self: Textarea) ui.Node {
        return ui.textareaNode(self.id, self.placeholder);
    }

    pub fn render(self: Textarea, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return common.renderNode(scene, bounds, self.node(), options);
    }

    pub fn collectInteractions(self: Textarea, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return common.collectHit(collector, bounds, .textarea, self.id);
    }

    pub fn measure(self: Textarea, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return common.measureNode(self.node(), constraints);
    }

    pub fn toObject(self: Textarea, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return component_codec.oneStringObject(.textarea, self.id, self.placeholder, ui_out, object_out, req, epoch);
    }

    pub fn writeRecord(self: Textarea, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.oneStringRecord(writer, index, .textarea, self.id, self.placeholder);
    }

    pub fn fromView(view: object.View) Error!Textarea {
        return switch (try component_codec.singleNode(view)) {
            .textarea => |textarea| .{ .id = textarea.id, .placeholder = textarea.placeholder },
            else => error.UnsupportedComponent,
        };
    }

    pub fn toHtml(self: Textarea, out: []u8) HtmlError![]u8 {
        return writeHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, text_out: []u8) HtmlError!Textarea {
        return readHtml(html, text_out);
    }

    pub fn toMarkdown(self: Textarea, out: []u8) MarkdownError![]u8 {
        return writeMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Textarea {
        return readMarkdown(markdown, text_out);
    }
};

pub fn writeHtml(textarea: Textarea, out: []u8) HtmlError![]u8 {
    var writer = HtmlWriter.init(out);
    try writeHtmlInto(&writer, textarea);
    return writer.written();
}

pub fn writeHtmlInto(writer: *HtmlWriter, textarea: Textarea) HtmlError!void {
    try writer.writeAll("<textarea data-er-component=\"textarea\"");
    try writer.writeAttrInt("data-er-id", textarea.id);
    try writer.writeAttrText("placeholder", textarea.placeholder);
    try writer.writeAll("></textarea>");
}

pub fn readHtml(html: []const u8, text_out: []u8) HtmlError!Textarea {
    var text = HtmlTextArena.init(text_out);
    return readHtmlWithArena(html, &text);
}

pub fn readHtmlWithArena(html: []const u8, text: *HtmlTextArena) HtmlError!Textarea {
    const prefix = "<textarea data-er-component=\"textarea\" data-er-id=\"";
    if (!std.mem.startsWith(u8, html, prefix)) return error.UnsupportedHtml;
    const after_id_prefix = html[prefix.len..];
    const id_end = std.mem.indexOf(u8, after_id_prefix, "\" placeholder=\"") orelse return error.InvalidHtml;
    const id = try common.parseHtmlU32(after_id_prefix[0..id_end]);
    const placeholder_start = prefix.len + id_end + "\" placeholder=\"".len;
    if (!std.mem.endsWith(u8, html, "\"></textarea>")) return error.InvalidHtml;
    const placeholder = try text.unescape(html[placeholder_start .. html.len - "\"></textarea>".len]);
    if (placeholder.len == 0) return error.InvalidHtml;
    return .{ .id = id, .placeholder = placeholder };
}

pub fn writeMarkdown(textarea: Textarea, out: []u8) MarkdownError![]u8 {
    var writer = MarkdownWriter.init(out);
    try writeMarkdownInto(&writer, textarea);
    return writer.written();
}

pub fn writeMarkdownInto(writer: *MarkdownWriter, textarea: Textarea) MarkdownError!void {
    if (textarea.placeholder.len == 0) return error.InvalidMarkdown;
    try writer.beginDirective("textarea");
    try writer.fieldInt("id", textarea.id);
    try writer.fieldText("placeholder", textarea.placeholder);
    try writer.endDirective();
}

pub fn readMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Textarea {
    var text = MarkdownTextArena.init(text_out);
    return readMarkdownWithArena(markdown, &text);
}

pub fn readMarkdownWithArena(markdown: []const u8, text: *MarkdownTextArena) MarkdownError!Textarea {
    const decoded = try component_codec.readIdTextDirectiveMarkdown(markdown, ":::textarea", ":::textarea\nid: ", "\nplaceholder: ", text);
    return .{ .id = decoded.id, .placeholder = decoded.text };
}

test "textarea component serializes to canonical object and deserializes" {
    const textarea = Textarea{ .id = 21, .placeholder = "Describe this app" };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = textarea.toObject(&ui_raw, &object_raw, component_test.req(), component_test.epoch()).?;
    const decoded = try Textarea.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(textarea.id, decoded.id);
    try std.testing.expectEqualStrings(textarea.placeholder, decoded.placeholder);
}

test "textarea component html and markdown codecs roundtrip escaped placeholder" {
    const textarea = Textarea{ .id = 21, .placeholder = "Describe <system>" };
    var encoded: [256]u8 = undefined;
    var decoded_text: [64]u8 = undefined;

    const html = try textarea.toHtml(&encoded);
    try std.testing.expectEqualStrings("<textarea data-er-component=\"textarea\" data-er-id=\"21\" placeholder=\"Describe &lt;system&gt;\"></textarea>", html);
    const html_decoded = try Textarea.fromHtml(html, &decoded_text);
    try std.testing.expectEqual(textarea.id, html_decoded.id);
    try std.testing.expectEqualStrings(textarea.placeholder, html_decoded.placeholder);

    const markdown = try textarea.toMarkdown(&encoded);
    try std.testing.expectEqualStrings(":::textarea\nid: 21\nplaceholder: Describe <system\\>\n:::", markdown);
    const markdown_decoded = try Textarea.fromMarkdown(markdown, &decoded_text);
    try std.testing.expectEqual(textarea.id, markdown_decoded.id);
    try std.testing.expectEqualStrings(textarea.placeholder, markdown_decoded.placeholder);
}
