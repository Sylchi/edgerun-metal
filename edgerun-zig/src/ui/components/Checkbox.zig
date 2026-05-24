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

pub const Checkbox = struct {
    id: u32,
    label: []const u8,
    checked: bool,

    pub fn node(self: Checkbox) ui.Node {
        return ui.checkboxNode(self.id, self.label, self.checked);
    }

    pub fn render(self: Checkbox, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return common.renderNode(scene, bounds, self.node(), options);
    }

    pub fn collectInteractions(self: Checkbox, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return common.collectHit(collector, bounds, .checkbox, self.id);
    }

    pub fn measure(self: Checkbox, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return common.measureNode(self.node(), constraints);
    }

    pub fn toObject(self: Checkbox, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return component_codec.stringAndRefObject(.checkbox, self.id, self.label, component_codec.boolRef(self.checked), ui_out, object_out, req, epoch);
    }

    pub fn writeRecord(self: Checkbox, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.stringAndRefRecord(writer, index, .checkbox, self.id, self.label, component_codec.boolRef(self.checked));
    }

    pub fn fromView(view: object.View) Error!Checkbox {
        return switch (try component_codec.singleNode(view)) {
            .checkbox => |checkbox| .{ .id = checkbox.id, .label = checkbox.label, .checked = checkbox.checked },
            else => error.UnsupportedComponent,
        };
    }

    pub fn toHtml(self: Checkbox, out: []u8) HtmlError![]u8 {
        return writeHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, text_out: []u8) HtmlError!Checkbox {
        return readHtml(html, text_out);
    }

    pub fn toMarkdown(self: Checkbox, out: []u8) MarkdownError![]u8 {
        return writeMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Checkbox {
        return readMarkdown(markdown, text_out);
    }
};

pub fn writeHtml(checkbox: Checkbox, out: []u8) HtmlError![]u8 {
    var writer = HtmlWriter.init(out);
    try writeHtmlInto(&writer, checkbox);
    return writer.written();
}

pub fn writeHtmlInto(writer: *HtmlWriter, checkbox: Checkbox) HtmlError!void {
    try writer.writeAll("<label data-er-component=\"checkbox\"");
    try writer.writeAttrInt("data-er-id", checkbox.id);
    try writer.writeAttrBool("data-er-checked", checkbox.checked);
    try writer.writeAll("><input type=\"checkbox\"");
    if (checkbox.checked) try writer.writeAll(" checked");
    try writer.writeAll(">");
    try writer.writeEscapedText(checkbox.label);
    try writer.writeAll("</label>");
}

pub fn readHtml(html: []const u8, text_out: []u8) HtmlError!Checkbox {
    var text = HtmlTextArena.init(text_out);
    return readHtmlWithArena(html, &text);
}

pub fn readHtmlWithArena(html: []const u8, text: *HtmlTextArena) HtmlError!Checkbox {
    const prefix = "<label data-er-component=\"checkbox\" data-er-id=\"";
    if (!std.mem.startsWith(u8, html, prefix)) return error.UnsupportedHtml;
    const after_id_prefix = html[prefix.len..];
    const id_end = std.mem.indexOf(u8, after_id_prefix, "\" data-er-checked=\"") orelse return error.InvalidHtml;
    const id = try common.parseHtmlU32(after_id_prefix[0..id_end]);
    const checked_start = prefix.len + id_end + "\" data-er-checked=\"".len;
    const checked_end_relative = std.mem.indexOf(u8, html[checked_start..], "\">") orelse return error.InvalidHtml;
    const checked = try common.parseHtmlBool(html[checked_start .. checked_start + checked_end_relative]);
    const input_start = checked_start + checked_end_relative;
    const input_text = if (checked) "\"><input type=\"checkbox\" checked>" else "\"><input type=\"checkbox\">";
    if (!std.mem.startsWith(u8, html[input_start..], input_text)) return error.InvalidHtml;
    if (!std.mem.endsWith(u8, html, "</label>")) return error.InvalidHtml;
    const label_start = input_start + input_text.len;
    const label = try text.unescape(html[label_start .. html.len - "</label>".len]);
    if (label.len == 0) return error.InvalidHtml;
    return .{ .id = id, .label = label, .checked = checked };
}

pub fn writeMarkdown(checkbox: Checkbox, out: []u8) MarkdownError![]u8 {
    var writer = MarkdownWriter.init(out);
    try writeMarkdownInto(&writer, checkbox);
    return writer.written();
}

pub fn writeMarkdownInto(writer: *MarkdownWriter, checkbox: Checkbox) MarkdownError!void {
    if (checkbox.label.len == 0) return error.InvalidMarkdown;
    try writer.beginDirective("checkbox");
    try writer.fieldInt("id", checkbox.id);
    try writer.fieldBool("checked", checkbox.checked);
    try writer.fieldText("label", checkbox.label);
    try writer.endDirective();
}

pub fn readMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Checkbox {
    var text = MarkdownTextArena.init(text_out);
    return readMarkdownWithArena(markdown, &text);
}

pub fn readMarkdownWithArena(markdown: []const u8, text: *MarkdownTextArena) MarkdownError!Checkbox {
    const decoded = try component_codec.readCheckedTextDirectiveMarkdown(markdown, ":::checkbox", ":::checkbox\nid: ", text);
    return .{ .id = decoded.id, .label = decoded.text, .checked = decoded.checked };
}

test "checkbox component serializes to canonical object and deserializes" {
    const checkbox = Checkbox{ .id = 11, .label = "Enable sync", .checked = true };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = checkbox.toObject(&ui_raw, &object_raw, component_test.req(), component_test.epoch()).?;
    const decoded = try Checkbox.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(checkbox.id, decoded.id);
    try std.testing.expectEqualStrings(checkbox.label, decoded.label);
    try std.testing.expectEqual(checkbox.checked, decoded.checked);
}

test "checkbox component html and markdown codecs roundtrip checked label" {
    const checkbox = Checkbox{ .id = 11, .label = "Enable <sync>", .checked = true };
    var encoded: [256]u8 = undefined;
    var decoded_text: [64]u8 = undefined;

    const html = try checkbox.toHtml(&encoded);
    try std.testing.expectEqualStrings("<label data-er-component=\"checkbox\" data-er-id=\"11\" data-er-checked=\"true\"><input type=\"checkbox\" checked>Enable &lt;sync&gt;</label>", html);
    const html_decoded = try Checkbox.fromHtml(html, &decoded_text);
    try std.testing.expectEqual(checkbox.id, html_decoded.id);
    try std.testing.expectEqualStrings(checkbox.label, html_decoded.label);
    try std.testing.expectEqual(checkbox.checked, html_decoded.checked);

    const markdown = try checkbox.toMarkdown(&encoded);
    try std.testing.expectEqualStrings(":::checkbox\nid: 11\nchecked: true\nlabel: Enable <sync\\>\n:::", markdown);
    const markdown_decoded = try Checkbox.fromMarkdown(markdown, &decoded_text);
    try std.testing.expectEqual(checkbox.id, markdown_decoded.id);
    try std.testing.expectEqualStrings(checkbox.label, markdown_decoded.label);
    try std.testing.expectEqual(checkbox.checked, markdown_decoded.checked);
}
