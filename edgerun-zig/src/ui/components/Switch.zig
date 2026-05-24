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

pub const Switch = struct {
    id: u32,
    label: []const u8,
    checked: bool,

    pub fn node(self: Switch) ui.Node {
        return ui.switchNode(self.id, self.label, self.checked);
    }

    pub fn render(self: Switch, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return common.renderNode(scene, bounds, self.node(), options);
    }

    pub fn collectInteractions(self: Switch, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return common.collectHit(collector, bounds, .switch_control, self.id);
    }

    pub fn measure(self: Switch, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return common.measureNode(self.node(), constraints);
    }

    pub fn toObject(self: Switch, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return component_codec.stringAndRefObject(.switch_control, self.id, self.label, component_codec.boolRef(self.checked), ui_out, object_out, req, epoch);
    }

    pub fn writeRecord(self: Switch, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.stringAndRefRecord(writer, index, .switch_control, self.id, self.label, component_codec.boolRef(self.checked));
    }

    pub fn fromView(view: object.View) Error!Switch {
        return switch (try component_codec.singleNode(view)) {
            .switch_control => |switch_control| .{ .id = switch_control.id, .label = switch_control.label, .checked = switch_control.checked },
            else => error.UnsupportedComponent,
        };
    }

    pub fn toHtml(self: Switch, out: []u8) HtmlError![]u8 {
        return writeHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, text_out: []u8) HtmlError!Switch {
        return readHtml(html, text_out);
    }

    pub fn toMarkdown(self: Switch, out: []u8) MarkdownError![]u8 {
        return writeMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Switch {
        return readMarkdown(markdown, text_out);
    }
};

pub fn writeHtml(switch_control: Switch, out: []u8) HtmlError![]u8 {
    var writer = HtmlWriter.init(out);
    try writeHtmlInto(&writer, switch_control);
    return writer.written();
}

pub fn writeHtmlInto(writer: *HtmlWriter, switch_control: Switch) HtmlError!void {
    try writer.writeAll("<button data-er-component=\"switch\"");
    try writer.writeAttrInt("data-er-id", switch_control.id);
    try writer.writeAttrBool("aria-pressed", switch_control.checked);
    try writer.writeByte('>');
    try writer.writeEscapedText(switch_control.label);
    try writer.writeAll("</button>");
}

pub fn readHtml(html: []const u8, text_out: []u8) HtmlError!Switch {
    var text = HtmlTextArena.init(text_out);
    return readHtmlWithArena(html, &text);
}

pub fn readHtmlWithArena(html: []const u8, text: *HtmlTextArena) HtmlError!Switch {
    const prefix = "<button data-er-component=\"switch\" data-er-id=\"";
    if (!std.mem.startsWith(u8, html, prefix)) return error.UnsupportedHtml;
    const after_id_prefix = html[prefix.len..];
    const id_end = std.mem.indexOf(u8, after_id_prefix, "\" aria-pressed=\"") orelse return error.InvalidHtml;
    const id = try common.parseHtmlU32(after_id_prefix[0..id_end]);
    const pressed_start = prefix.len + id_end + "\" aria-pressed=\"".len;
    const pressed_end_relative = std.mem.indexOf(u8, html[pressed_start..], "\">") orelse return error.InvalidHtml;
    const checked = try common.parseHtmlBool(html[pressed_start .. pressed_start + pressed_end_relative]);
    if (!std.mem.endsWith(u8, html, "</button>")) return error.InvalidHtml;
    const label_start = pressed_start + pressed_end_relative + "\">".len;
    const label = try text.unescape(html[label_start .. html.len - "</button>".len]);
    if (label.len == 0) return error.InvalidHtml;
    return .{ .id = id, .label = label, .checked = checked };
}

pub fn writeMarkdown(switch_control: Switch, out: []u8) MarkdownError![]u8 {
    var writer = MarkdownWriter.init(out);
    try writeMarkdownInto(&writer, switch_control);
    return writer.written();
}

pub fn writeMarkdownInto(writer: *MarkdownWriter, switch_control: Switch) MarkdownError!void {
    if (switch_control.label.len == 0) return error.InvalidMarkdown;
    try writer.beginDirective("switch");
    try writer.fieldInt("id", switch_control.id);
    try writer.fieldBool("checked", switch_control.checked);
    try writer.fieldText("label", switch_control.label);
    try writer.endDirective();
}

pub fn readMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Switch {
    var text = MarkdownTextArena.init(text_out);
    return readMarkdownWithArena(markdown, &text);
}

pub fn readMarkdownWithArena(markdown: []const u8, text: *MarkdownTextArena) MarkdownError!Switch {
    const decoded = try component_codec.readCheckedTextDirectiveMarkdown(markdown, ":::switch", ":::switch\nid: ", text);
    return .{ .id = decoded.id, .label = decoded.text, .checked = decoded.checked };
}

test "switch component serializes to canonical object and deserializes" {
    const switch_control = Switch{ .id = 12, .label = "Public", .checked = false };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = switch_control.toObject(&ui_raw, &object_raw, component_test.req(), component_test.epoch()).?;
    const decoded = try Switch.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(switch_control.id, decoded.id);
    try std.testing.expectEqualStrings(switch_control.label, decoded.label);
    try std.testing.expectEqual(switch_control.checked, decoded.checked);
}

test "switch component html and markdown codecs roundtrip checked label" {
    const switch_control = Switch{ .id = 12, .label = "Public & trusted", .checked = false };
    var encoded: [256]u8 = undefined;
    var decoded_text: [64]u8 = undefined;

    const html = try switch_control.toHtml(&encoded);
    try std.testing.expectEqualStrings("<button data-er-component=\"switch\" data-er-id=\"12\" aria-pressed=\"false\">Public &amp; trusted</button>", html);
    const html_decoded = try Switch.fromHtml(html, &decoded_text);
    try std.testing.expectEqual(switch_control.id, html_decoded.id);
    try std.testing.expectEqualStrings(switch_control.label, html_decoded.label);
    try std.testing.expectEqual(switch_control.checked, html_decoded.checked);

    const markdown = try switch_control.toMarkdown(&encoded);
    try std.testing.expectEqualStrings(":::switch\nid: 12\nchecked: false\nlabel: Public & trusted\n:::", markdown);
    const markdown_decoded = try Switch.fromMarkdown(markdown, &decoded_text);
    try std.testing.expectEqual(switch_control.id, markdown_decoded.id);
    try std.testing.expectEqualStrings(switch_control.label, markdown_decoded.label);
    try std.testing.expectEqual(switch_control.checked, markdown_decoded.checked);
}
