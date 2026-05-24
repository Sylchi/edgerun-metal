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

pub const Input = struct {
    id: u32,
    placeholder: []const u8,

    pub fn node(self: Input) ui.Node {
        return .{ .input = .{ .id = self.id, .placeholder = self.placeholder } };
    }

    pub fn render(self: Input, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return common.renderNode(scene, bounds, self.node(), options);
    }

    pub fn collectInteractions(self: Input, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return common.collectHit(collector, bounds, .input, self.id);
    }

    pub fn measure(self: Input, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return common.measureNode(self.node(), constraints);
    }

    pub fn toObject(self: Input, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return component_codec.oneStringObject(.input, self.id, self.placeholder, ui_out, object_out, req, epoch);
    }

    pub fn writeRecord(self: Input, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.oneStringRecord(writer, index, .input, self.id, self.placeholder);
    }

    pub fn fromView(view: object.View) Error!Input {
        return switch (try component_codec.singleNode(view)) {
            .input => |input| .{ .id = input.id, .placeholder = input.placeholder },
            else => error.UnsupportedComponent,
        };
    }

    pub fn toHtml(self: Input, out: []u8) HtmlError![]u8 {
        return writeHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, text_out: []u8) HtmlError!Input {
        return readHtml(html, text_out);
    }

    pub fn toMarkdown(self: Input, out: []u8) MarkdownError![]u8 {
        return writeMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Input {
        return readMarkdown(markdown, text_out);
    }
};

pub fn writeHtml(input: Input, out: []u8) HtmlError![]u8 {
    var writer = HtmlWriter.init(out);
    try writeHtmlInto(&writer, input);
    return writer.written();
}

pub fn writeHtmlInto(writer: *HtmlWriter, input: Input) HtmlError!void {
    try writer.writeAll("<input data-er-component=\"input\"");
    try writer.writeAttrInt("data-er-id", input.id);
    try writer.writeAttrText("placeholder", input.placeholder);
    try writer.writeByte('>');
}

pub fn readHtml(html: []const u8, text_out: []u8) HtmlError!Input {
    var text = HtmlTextArena.init(text_out);
    return readHtmlWithArena(html, &text);
}

pub fn readHtmlWithArena(html: []const u8, text: *HtmlTextArena) HtmlError!Input {
    const prefix = "<input data-er-component=\"input\" data-er-id=\"";
    if (!std.mem.startsWith(u8, html, prefix)) return error.UnsupportedHtml;
    const after_id_prefix = html[prefix.len..];
    const id_end = std.mem.indexOf(u8, after_id_prefix, "\" placeholder=\"") orelse return error.InvalidHtml;
    const id = try common.parseHtmlU32(after_id_prefix[0..id_end]);
    const placeholder_start = prefix.len + id_end + "\" placeholder=\"".len;
    if (!std.mem.endsWith(u8, html, "\">")) return error.InvalidHtml;
    const placeholder = try text.unescape(html[placeholder_start .. html.len - "\">".len]);
    if (placeholder.len == 0) return error.InvalidHtml;
    return .{ .id = id, .placeholder = placeholder };
}

pub fn writeMarkdown(input: Input, out: []u8) MarkdownError![]u8 {
    var writer = MarkdownWriter.init(out);
    try writeMarkdownInto(&writer, input);
    return writer.written();
}

pub fn writeMarkdownInto(writer: *MarkdownWriter, input: Input) MarkdownError!void {
    if (input.placeholder.len == 0) return error.InvalidMarkdown;
    try writer.beginDirective("input");
    try writer.fieldInt("id", input.id);
    try writer.fieldText("placeholder", input.placeholder);
    try writer.endDirective();
}

pub fn readMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Input {
    var text = MarkdownTextArena.init(text_out);
    return readMarkdownWithArena(markdown, &text);
}

pub fn readMarkdownWithArena(markdown: []const u8, text: *MarkdownTextArena) MarkdownError!Input {
    const decoded = try component_codec.readIdTextDirectiveMarkdown(markdown, ":::input", ":::input\nid: ", "\nplaceholder: ", text);
    return .{ .id = decoded.id, .placeholder = decoded.text };
}

test "input component serializes to canonical object and deserializes" {
    const input = Input{ .id = 10, .placeholder = "Search objects" };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = input.toObject(&ui_raw, &object_raw, component_test.req(), component_test.epoch()).?;
    const decoded = try Input.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(input.id, decoded.id);
    try std.testing.expectEqualStrings(input.placeholder, decoded.placeholder);
}

test "input component html and markdown codecs roundtrip escaped placeholder" {
    const input = Input{ .id = 10, .placeholder = "Find \"object\"" };
    var encoded: [256]u8 = undefined;
    var decoded_text: [64]u8 = undefined;

    const html = try input.toHtml(&encoded);
    try std.testing.expectEqualStrings("<input data-er-component=\"input\" data-er-id=\"10\" placeholder=\"Find &quot;object&quot;\">", html);
    const html_decoded = try Input.fromHtml(html, &decoded_text);
    try std.testing.expectEqual(input.id, html_decoded.id);
    try std.testing.expectEqualStrings(input.placeholder, html_decoded.placeholder);

    const markdown = try input.toMarkdown(&encoded);
    try std.testing.expectEqualStrings(":::input\nid: 10\nplaceholder: Find \"object\"\n:::", markdown);
    const markdown_decoded = try Input.fromMarkdown(markdown, &decoded_text);
    try std.testing.expectEqual(input.id, markdown_decoded.id);
    try std.testing.expectEqualStrings(input.placeholder, markdown_decoded.placeholder);
}
