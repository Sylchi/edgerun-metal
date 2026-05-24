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

pub const Slider = struct {
    id: u32,
    label: []const u8,
    value: f32,

    pub fn node(self: Slider) ui.Node {
        return ui.sliderNode(self.id, self.label, self.value);
    }

    pub fn render(self: Slider, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return common.renderNode(scene, bounds, self.node(), options);
    }

    pub fn collectInteractions(self: Slider, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return common.collectHit(collector, bounds, .slider, self.id);
    }

    pub fn measure(self: Slider, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return common.measureNode(self.node(), constraints);
    }

    pub fn toObject(self: Slider, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return component_codec.stringAndRefObject(.slider, self.id, self.label, component_codec.unitRef(self.value), ui_out, object_out, req, epoch);
    }

    pub fn writeRecord(self: Slider, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.stringAndRefRecord(writer, index, .slider, self.id, self.label, component_codec.unitRef(self.value));
    }

    pub fn fromView(view: object.View) Error!Slider {
        return switch (try component_codec.singleNode(view)) {
            .slider => |slider| .{ .id = slider.id, .label = slider.label, .value = slider.value },
            else => error.UnsupportedComponent,
        };
    }

    pub fn toHtml(self: Slider, out: []u8) HtmlError![]u8 {
        return writeHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, text_out: []u8) HtmlError!Slider {
        return readHtml(html, text_out);
    }

    pub fn toMarkdown(self: Slider, out: []u8) MarkdownError![]u8 {
        return writeMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Slider {
        return readMarkdown(markdown, text_out);
    }
};

pub fn writeHtml(slider: Slider, out: []u8) HtmlError![]u8 {
    var writer = HtmlWriter.init(out);
    try writeHtmlInto(&writer, slider);
    return writer.written();
}

pub fn writeHtmlInto(writer: *HtmlWriter, slider: Slider) HtmlError!void {
    try writer.writeAll("<label data-er-component=\"slider\"");
    try writer.writeAttrInt("data-er-id", slider.id);
    try writer.writeAll("><span>");
    try writer.writeEscapedText(slider.label);
    try writer.writeAll("</span><input type=\"range\" min=\"0\" max=\"100\" value=\"");
    try writer.writeInt(common.percentFromUnit(slider.value));
    try writer.writeAll("\"></label>");
}

pub fn readHtml(html: []const u8, text_out: []u8) HtmlError!Slider {
    var text = HtmlTextArena.init(text_out);
    return readHtmlWithArena(html, &text);
}

pub fn readHtmlWithArena(html: []const u8, text: *HtmlTextArena) HtmlError!Slider {
    const prefix = "<label data-er-component=\"slider\" data-er-id=\"";
    if (!std.mem.startsWith(u8, html, prefix)) return error.UnsupportedHtml;
    const after_id_prefix = html[prefix.len..];
    const id_end = std.mem.indexOf(u8, after_id_prefix, "\"><span>") orelse return error.InvalidHtml;
    const id = try common.parseHtmlU32(after_id_prefix[0..id_end]);
    const label_start = prefix.len + id_end + "\"><span>".len;
    const label_end_relative = std.mem.indexOf(u8, html[label_start..], "</span><input type=\"range\" min=\"0\" max=\"100\" value=\"") orelse return error.InvalidHtml;
    const value_start = label_start + label_end_relative + "</span><input type=\"range\" min=\"0\" max=\"100\" value=\"".len;
    const value_end_relative = std.mem.indexOf(u8, html[value_start..], "\"></label>") orelse return error.InvalidHtml;
    const label = try text.unescape(html[label_start .. label_start + label_end_relative]);
    const value = try common.parseHtmlPercent(html[value_start .. value_start + value_end_relative]);
    if (label.len == 0) return error.InvalidHtml;
    return .{ .id = id, .label = label, .value = value };
}

pub fn writeMarkdown(slider: Slider, out: []u8) MarkdownError![]u8 {
    var writer = MarkdownWriter.init(out);
    try writeMarkdownInto(&writer, slider);
    return writer.written();
}

pub fn writeMarkdownInto(writer: *MarkdownWriter, slider: Slider) MarkdownError!void {
    if (slider.label.len == 0) return error.InvalidMarkdown;
    try writer.beginDirective("slider");
    try writer.fieldInt("id", slider.id);
    try writer.fieldText("label", slider.label);
    try writer.fieldInt("value", common.percentFromUnit(slider.value));
    try writer.endDirective();
}

pub fn readMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Slider {
    var text = MarkdownTextArena.init(text_out);
    return readMarkdownWithArena(markdown, &text);
}

pub fn readMarkdownWithArena(markdown: []const u8, text: *MarkdownTextArena) MarkdownError!Slider {
    const prefix = ":::slider\nid: ";
    const body = try common.readMarkdownDirectiveBody(markdown, ":::slider", prefix);
    const id_end = std.mem.indexOf(u8, body, "\nlabel: ") orelse return error.InvalidMarkdown;
    const id = try common.parseMarkdownU32(body[0..id_end]);
    const label_start = id_end + "\nlabel: ".len;
    const label_end_relative = std.mem.indexOf(u8, body[label_start..], "\nvalue: ") orelse return error.InvalidMarkdown;
    const value_start = label_start + label_end_relative + "\nvalue: ".len;
    const label = try text.unescapeInline(body[label_start .. label_start + label_end_relative]);
    if (label.len == 0) return error.InvalidMarkdown;
    return .{ .id = id, .label = label, .value = try common.parseMarkdownPercent(body[value_start..]) };
}

test "slider component serializes to canonical object and deserializes" {
    const slider = Slider{ .id = 13, .label = "Brightness", .value = 0.72 };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = slider.toObject(&ui_raw, &object_raw, component_test.req(), component_test.epoch()).?;
    const decoded = try Slider.fromView(try object.View.decode(canonical));

    try std.testing.expectEqual(slider.id, decoded.id);
    try std.testing.expectEqualStrings(slider.label, decoded.label);
    try std.testing.expect(@abs(decoded.value - slider.value) < 0.001);
}

test "slider component html and markdown codecs roundtrip percent value" {
    const slider = Slider{ .id = 13, .label = "Bright > dim", .value = 0.72 };
    var encoded: [256]u8 = undefined;
    var decoded_text: [64]u8 = undefined;

    const html = try slider.toHtml(&encoded);
    try std.testing.expectEqualStrings("<label data-er-component=\"slider\" data-er-id=\"13\"><span>Bright &gt; dim</span><input type=\"range\" min=\"0\" max=\"100\" value=\"72\"></label>", html);
    const html_decoded = try Slider.fromHtml(html, &decoded_text);
    try std.testing.expectEqual(slider.id, html_decoded.id);
    try std.testing.expectEqualStrings(slider.label, html_decoded.label);
    try std.testing.expect(@abs(html_decoded.value - slider.value) < 0.001);

    const markdown = try slider.toMarkdown(&encoded);
    try std.testing.expectEqualStrings(":::slider\nid: 13\nlabel: Bright \\> dim\nvalue: 72\n:::", markdown);
    const markdown_decoded = try Slider.fromMarkdown(markdown, &decoded_text);
    try std.testing.expectEqual(slider.id, markdown_decoded.id);
    try std.testing.expectEqualStrings(slider.label, markdown_decoded.label);
    try std.testing.expect(@abs(markdown_decoded.value - slider.value) < 0.001);
}
