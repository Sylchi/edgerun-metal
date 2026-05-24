const std = @import("std");
const common = @import("../../ui_component_common.zig");
const component_io = @import("ComponentIO.zig");

pub const HtmlError = common.HtmlError;
pub const HtmlTextArena = common.HtmlTextArena;
pub const HtmlWriter = common.HtmlWriter;
pub const MarkdownError = common.MarkdownError;
pub const MarkdownTextArena = common.MarkdownTextArena;
pub const MarkdownWriter = common.MarkdownWriter;

pub fn writeHtml(comptime Component: type, stack: anytype, out: []u8) HtmlError![]u8 {
    var writer = HtmlWriter.init(out);
    try writer.writeAll("<section data-er-component=\"stack\"");
    try writer.writeAttrRaw("data-er-axis", common.axisName(stack.axis));
    try writer.writeAttrInt("data-er-gap", stack.gap);
    try writer.writeAttrInt("data-er-padding", stack.padding);
    try writer.writeByte('>');
    for (stack.children) |child| try component_io.writeHtmlInto(Component, &writer, child);
    try writer.writeAll("</section>");
    return writer.written();
}

pub fn writeMarkdown(comptime Component: type, stack: anytype, out: []u8) MarkdownError![]u8 {
    if (stack.children.len == 0) return error.InvalidMarkdown;
    var writer = MarkdownWriter.init(out);
    try writer.beginDirective("stack");
    try writer.fieldRaw("axis", common.axisName(stack.axis));
    try writer.fieldInt("gap", stack.gap);
    try writer.fieldInt("padding", stack.padding);
    for (stack.children) |child| {
        try writer.writeByte('\n');
        try writer.writeAll(component_io.markdown_component_marker);
        try component_io.writeMarkdownInto(Component, &writer, child);
    }
    try writer.endDirective();
    return writer.written();
}

pub fn readHtml(comptime Stack: type, comptime Component: type, html: []const u8, out_components: []Component, text_out: []u8) HtmlError!Stack {
    const prefix = "<section data-er-component=\"stack\" data-er-axis=\"";
    if (!std.mem.startsWith(u8, html, prefix)) return error.UnsupportedHtml;
    const after_axis = html[prefix.len..];
    const axis_end = std.mem.indexOf(u8, after_axis, "\" data-er-gap=\"") orelse return error.InvalidHtml;
    const axis = common.parseAxisName(after_axis[0..axis_end]) orelse return error.InvalidHtml;
    const gap_start = prefix.len + axis_end + "\" data-er-gap=\"".len;
    const gap_end_relative = std.mem.indexOf(u8, html[gap_start..], "\" data-er-padding=\"") orelse return error.InvalidHtml;
    const gap = try common.parseHtmlU16(html[gap_start .. gap_start + gap_end_relative]);
    const padding_start = gap_start + gap_end_relative + "\" data-er-padding=\"".len;
    const padding_end_relative = std.mem.indexOf(u8, html[padding_start..], "\">") orelse return error.InvalidHtml;
    const padding = try common.parseHtmlU16(html[padding_start .. padding_start + padding_end_relative]);
    const children_start = padding_start + padding_end_relative + "\">".len;
    if (!std.mem.endsWith(u8, html, "</section>")) return error.InvalidHtml;
    const children_html = html[children_start .. html.len - "</section>".len];
    const children = try readChildrenHtml(Component, children_html, out_components, text_out);
    return .{
        .axis = axis,
        .gap = gap,
        .padding = padding,
        .children = children,
    };
}

pub fn readMarkdown(comptime Stack: type, comptime Component: type, markdown: []const u8, out_components: []Component, text_out: []u8) MarkdownError!Stack {
    const prefix = ":::stack\naxis: ";
    const body = try common.readMarkdownDirectiveBody(markdown, ":::stack", prefix);
    const axis_end_relative = std.mem.indexOf(u8, body, "\ngap: ") orelse return error.InvalidMarkdown;
    const axis = common.parseAxisName(body[0..axis_end_relative]) orelse return error.InvalidMarkdown;
    const gap_start = axis_end_relative + "\ngap: ".len;
    const gap_end_relative = std.mem.indexOf(u8, body[gap_start..], "\npadding: ") orelse return error.InvalidMarkdown;
    const gap = try common.parseMarkdownU16(body[gap_start .. gap_start + gap_end_relative]);
    const padding_start = gap_start + gap_end_relative + "\npadding: ".len;
    const padding_end_relative = std.mem.indexOf(u8, body[padding_start..], component_io.markdown_next_component_marker) orelse return error.InvalidMarkdown;
    const padding = try common.parseMarkdownU16(body[padding_start .. padding_start + padding_end_relative]);
    const children_start = padding_start + padding_end_relative + 1;
    const children = try readChildrenMarkdown(Component, body[children_start..], out_components, text_out);
    return .{
        .axis = axis,
        .gap = gap,
        .padding = padding,
        .children = children,
    };
}

pub fn readChildrenHtml(comptime Component: type, html: []const u8, out_components: []Component, text_out: []u8) HtmlError![]const Component {
    var text = HtmlTextArena.init(text_out);
    return component_io.readListHtmlWithArena(Component, html, out_components, &text);
}

pub fn readChildrenMarkdown(comptime Component: type, markdown: []const u8, out_components: []Component, text_out: []u8) MarkdownError![]const Component {
    var text = MarkdownTextArena.init(text_out);
    return component_io.readListMarkdownWithArena(Component, markdown, out_components, &text);
}
