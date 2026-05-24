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

pub const Select = struct {
    id: u32,
    label: []const u8,

    pub fn node(self: Select) ui.Node {
        return ui.selectNode(self.id, self.label);
    }

    pub fn render(self: Select, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return common.renderNode(scene, bounds, self.node(), options);
    }

    pub fn collectInteractions(self: Select, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return common.collectHit(collector, bounds, .select, self.id);
    }

    pub fn measure(self: Select, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return common.measureNode(self.node(), constraints);
    }

    pub fn toObject(self: Select, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return component_codec.oneStringObject(.select, self.id, self.label, ui_out, object_out, req, epoch);
    }

    pub fn writeRecord(self: Select, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.oneStringRecord(writer, index, .select, self.id, self.label);
    }

    pub fn fromView(view: object.View) Error!Select {
        return switch (try component_codec.singleNode(view)) {
            .select => |select| .{ .id = select.id, .label = select.label },
            else => error.UnsupportedComponent,
        };
    }

    pub fn toHtml(self: Select, out: []u8) HtmlError![]u8 {
        return writeHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, text_out: []u8) HtmlError!Select {
        return readHtml(html, text_out);
    }

    pub fn toMarkdown(self: Select, out: []u8) MarkdownError![]u8 {
        return writeMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Select {
        return readMarkdown(markdown, text_out);
    }
};

pub fn writeHtml(select: Select, out: []u8) HtmlError![]u8 {
    var writer = HtmlWriter.init(out);
    try writeHtmlInto(&writer, select);
    return writer.written();
}

pub fn writeHtmlInto(writer: *HtmlWriter, select: Select) HtmlError!void {
    try writer.writeAll("<select data-er-component=\"select\"");
    try writer.writeAttrInt("data-er-id", select.id);
    try writer.writeAll("><option selected>");
    try writer.writeEscapedText(select.label);
    try writer.writeAll("</option></select>");
}

pub fn readHtml(html: []const u8, text_out: []u8) HtmlError!Select {
    var text = HtmlTextArena.init(text_out);
    return readHtmlWithArena(html, &text);
}

pub fn readHtmlWithArena(html: []const u8, text: *HtmlTextArena) HtmlError!Select {
    const prefix = "<select data-er-component=\"select\" data-er-id=\"";
    if (!std.mem.startsWith(u8, html, prefix)) return error.UnsupportedHtml;
    const after_id_prefix = html[prefix.len..];
    const id_end = std.mem.indexOf(u8, after_id_prefix, "\"><option selected>") orelse return error.InvalidHtml;
    const id = try common.parseHtmlU32(after_id_prefix[0..id_end]);
    const label_start = prefix.len + id_end + "\"><option selected>".len;
    if (!std.mem.endsWith(u8, html, "</option></select>")) return error.InvalidHtml;
    const label = try text.unescape(html[label_start .. html.len - "</option></select>".len]);
    if (label.len == 0) return error.InvalidHtml;
    return .{ .id = id, .label = label };
}

pub fn writeMarkdown(select: Select, out: []u8) MarkdownError![]u8 {
    var writer = MarkdownWriter.init(out);
    try writeMarkdownInto(&writer, select);
    return writer.written();
}

pub fn writeMarkdownInto(writer: *MarkdownWriter, select: Select) MarkdownError!void {
    if (select.label.len == 0) return error.InvalidMarkdown;
    try writer.beginDirective("select");
    try writer.fieldInt("id", select.id);
    try writer.fieldText("label", select.label);
    try writer.endDirective();
}

pub fn readMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Select {
    var text = MarkdownTextArena.init(text_out);
    return readMarkdownWithArena(markdown, &text);
}

pub fn readMarkdownWithArena(markdown: []const u8, text: *MarkdownTextArena) MarkdownError!Select {
    const decoded = try component_codec.readIdTextDirectiveMarkdown(markdown, ":::select", ":::select\nid: ", "\nlabel: ", text);
    return .{ .id = decoded.id, .label = decoded.text };
}

test "select component serializes to canonical object and deserializes" {
    const select = Select{ .id = 22, .label = "Production" };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = select.toObject(&ui_raw, &object_raw, component_test.req(), component_test.epoch()).?;
    const decoded = try Select.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(select.id, decoded.id);
    try std.testing.expectEqualStrings(select.label, decoded.label);
}

test "select component html and markdown codecs roundtrip escaped label" {
    const select = Select{ .id = 22, .label = "Prod & staging" };
    var encoded: [256]u8 = undefined;
    var decoded_text: [64]u8 = undefined;

    const html = try select.toHtml(&encoded);
    try std.testing.expectEqualStrings("<select data-er-component=\"select\" data-er-id=\"22\"><option selected>Prod &amp; staging</option></select>", html);
    const html_decoded = try Select.fromHtml(html, &decoded_text);
    try std.testing.expectEqual(select.id, html_decoded.id);
    try std.testing.expectEqualStrings(select.label, html_decoded.label);

    const markdown = try select.toMarkdown(&encoded);
    try std.testing.expectEqualStrings(":::select\nid: 22\nlabel: Prod & staging\n:::", markdown);
    const markdown_decoded = try Select.fromMarkdown(markdown, &decoded_text);
    try std.testing.expectEqual(select.id, markdown_decoded.id);
    try std.testing.expectEqualStrings(select.label, markdown_decoded.label);
}
