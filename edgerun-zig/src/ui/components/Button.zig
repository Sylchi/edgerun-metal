const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const layout = @import("../../layouts/Types.zig");
const object = @import("../../object.zig");
const std = @import("std");
const ui = @import("../../ui.zig");
const base_button = @import("base/Button.zig");
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

pub const Button = struct {
    id: u32,
    label: []const u8,

    pub fn node(self: Button) ui.Node {
        return .{ .button = .{ .id = self.id, .label = self.label } };
    }

    pub fn render(self: Button, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return base_button.render(scene, bounds, .{ .id = self.id, .label = self.label }, options);
    }

    pub fn collectInteractions(self: Button, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return base_button.collectInteractions(collector, bounds, .{ .id = self.id, .label = self.label });
    }

    pub fn measure(self: Button, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return base_button.measure(self.label, constraints);
    }

    pub fn toObject(self: Button, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return component_codec.oneStringObject(.button, self.id, self.label, ui_out, object_out, req, epoch);
    }

    pub fn writeRecord(self: Button, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.oneStringRecord(writer, index, .button, self.id, self.label);
    }

    pub fn fromView(view: object.View) Error!Button {
        return switch (try component_codec.singleNode(view)) {
            .button => |button| .{ .id = button.id, .label = button.label },
            else => error.UnsupportedComponent,
        };
    }

    pub fn toHtml(self: Button, out: []u8) HtmlError![]u8 {
        return writeHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, text_out: []u8) HtmlError!Button {
        return readHtml(html, text_out);
    }

    pub fn toMarkdown(self: Button, out: []u8) MarkdownError![]u8 {
        return writeMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Button {
        return readMarkdown(markdown, text_out);
    }
};

pub fn writeHtml(button: Button, out: []u8) HtmlError![]u8 {
    var writer = HtmlWriter.init(out);
    try writeHtmlInto(&writer, button);
    return writer.written();
}

pub fn writeHtmlInto(writer: *HtmlWriter, button: Button) HtmlError!void {
    try writer.writeAll("<button data-er-component=\"button\"");
    try writer.writeAttrInt("data-er-id", button.id);
    try writer.writeByte('>');
    try writer.writeEscapedText(button.label);
    try writer.writeAll("</button>");
}

pub fn readHtml(html: []const u8, text_out: []u8) HtmlError!Button {
    var text = HtmlTextArena.init(text_out);
    return readHtmlWithArena(html, &text);
}

pub fn readHtmlWithArena(html: []const u8, text: *HtmlTextArena) HtmlError!Button {
    const prefix = "<button data-er-component=\"button\" data-er-id=\"";
    if (!std.mem.startsWith(u8, html, prefix)) return error.UnsupportedHtml;
    const after_id_prefix = html[prefix.len..];
    const id_end = std.mem.indexOf(u8, after_id_prefix, "\">") orelse return error.InvalidHtml;
    const id = try common.parseHtmlU32(after_id_prefix[0..id_end]);
    const label_start = prefix.len + id_end + "\">".len;
    if (!std.mem.endsWith(u8, html, "</button>")) return error.InvalidHtml;
    const label = try text.unescape(html[label_start .. html.len - "</button>".len]);
    if (label.len == 0) return error.InvalidHtml;
    return .{ .id = id, .label = label };
}

pub fn writeMarkdown(button: Button, out: []u8) MarkdownError![]u8 {
    var writer = MarkdownWriter.init(out);
    try writeMarkdownInto(&writer, button);
    return writer.written();
}

pub fn writeMarkdownInto(writer: *MarkdownWriter, button: Button) MarkdownError!void {
    if (button.label.len == 0) return error.InvalidMarkdown;
    try writer.beginDirective("button");
    try writer.fieldInt("id", button.id);
    try writer.fieldText("label", button.label);
    try writer.endDirective();
}

pub fn readMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Button {
    var text = MarkdownTextArena.init(text_out);
    return readMarkdownWithArena(markdown, &text);
}

pub fn readMarkdownWithArena(markdown: []const u8, text: *MarkdownTextArena) MarkdownError!Button {
    const decoded = try component_codec.readIdTextDirectiveMarkdown(markdown, ":::button", ":::button\nid: ", "\nlabel: ", text);
    return .{ .id = decoded.id, .label = decoded.text };
}

test "button component serializes to canonical object and deserializes" {
    const button = Button{ .id = 7, .label = "Run" };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = button.toObject(&ui_raw, &object_raw, component_test.req(), component_test.epoch()).?;
    const decoded = try Button.fromView(try object.View.decode(canonical));

    try @import("std").testing.expectEqual(@as(u32, 7), decoded.id);
    try @import("std").testing.expectEqualStrings("Run", decoded.label);
}

test "button component html and markdown codecs roundtrip escaped label" {
    const testing = @import("std").testing;
    const button = Button{ .id = 7, .label = "Run <safe>" };
    var encoded: [256]u8 = undefined;
    var decoded_text: [64]u8 = undefined;

    const html = try button.toHtml(&encoded);
    try testing.expectEqualStrings("<button data-er-component=\"button\" data-er-id=\"7\">Run &lt;safe&gt;</button>", html);
    const html_decoded = try Button.fromHtml(html, &decoded_text);
    try testing.expectEqual(@as(u32, 7), html_decoded.id);
    try testing.expectEqualStrings(button.label, html_decoded.label);

    const markdown = try button.toMarkdown(&encoded);
    try testing.expectEqualStrings(":::button\nid: 7\nlabel: Run <safe\\>\n:::", markdown);
    const markdown_decoded = try Button.fromMarkdown(markdown, &decoded_text);
    try testing.expectEqual(@as(u32, 7), markdown_decoded.id);
    try testing.expectEqualStrings(button.label, markdown_decoded.label);
}
