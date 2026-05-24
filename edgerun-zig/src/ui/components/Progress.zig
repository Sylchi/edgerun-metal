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
const HtmlWriter = common.HtmlWriter;
const MarkdownError = common.MarkdownError;
const MarkdownWriter = common.MarkdownWriter;
const RenderOptions = common.RenderOptions;

pub const Progress = struct {
    value: f32,

    pub fn node(self: Progress) ui.Node {
        return ui.progressNode(self.value);
    }

    pub fn render(self: Progress, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return common.renderNode(scene, bounds, self.node(), options);
    }

    pub fn measure(self: Progress, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return common.measureNode(self.node(), constraints);
    }

    pub fn toObject(self: Progress, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return component_codec.refObject(.progress, 0, component_codec.unitRef(self.value), ui_out, object_out, req, epoch);
    }

    pub fn writeRecord(self: Progress, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.refRecord(writer, index, .progress, 0, component_codec.unitRef(self.value));
    }

    pub fn fromView(view: object.View) Error!Progress {
        return switch (try component_codec.singleNode(view)) {
            .progress => |progress| .{ .value = progress.value },
            else => error.UnsupportedComponent,
        };
    }

    pub fn toHtml(self: Progress, out: []u8) HtmlError![]u8 {
        return writeHtml(self, out);
    }

    pub fn fromHtml(html: []const u8) HtmlError!Progress {
        return readHtml(html);
    }

    pub fn toMarkdown(self: Progress, out: []u8) MarkdownError![]u8 {
        return writeMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8) MarkdownError!Progress {
        return readMarkdown(markdown);
    }
};

pub fn writeHtml(progress: Progress, out: []u8) HtmlError![]u8 {
    var writer = HtmlWriter.init(out);
    try writeHtmlInto(&writer, progress);
    return writer.written();
}

pub fn writeHtmlInto(writer: *HtmlWriter, progress: Progress) HtmlError!void {
    try writer.writeAll("<progress data-er-component=\"progress\"");
    try writer.writeAttrInt("value", common.percentFromUnit(progress.value));
    try writer.writeAttrRaw("max", "100");
    try writer.writeAll("></progress>");
}

pub fn readHtml(html: []const u8) HtmlError!Progress {
    const prefix = "<progress data-er-component=\"progress\" value=\"";
    if (!std.mem.startsWith(u8, html, prefix)) return error.UnsupportedHtml;
    const value_end_relative = std.mem.indexOf(u8, html[prefix.len..], "\" max=\"100\"></progress>") orelse return error.InvalidHtml;
    const value = try common.parseHtmlPercent(html[prefix.len .. prefix.len + value_end_relative]);
    return .{ .value = value };
}

pub fn writeMarkdown(progress: Progress, out: []u8) MarkdownError![]u8 {
    var writer = MarkdownWriter.init(out);
    try writeMarkdownInto(&writer, progress);
    return writer.written();
}

pub fn writeMarkdownInto(writer: *MarkdownWriter, progress: Progress) MarkdownError!void {
    try writer.beginDirective("progress-control");
    try writer.fieldInt("value", common.percentFromUnit(progress.value));
    try writer.endDirective();
}

pub fn readMarkdown(markdown: []const u8) MarkdownError!Progress {
    const body = try common.readMarkdownDirectiveBody(markdown, ":::progress-control", ":::progress-control\nvalue: ");
    return .{ .value = try common.parseMarkdownPercent(body) };
}

test "progress component serializes to canonical object and deserializes" {
    const progress = Progress{ .value = 0.64 };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = progress.toObject(&ui_raw, &object_raw, component_test.req(), component_test.epoch()).?;
    const decoded = try Progress.fromView(try object.View.decode(canonical));

    try std.testing.expect(@abs(decoded.value - progress.value) < 0.001);
}

test "progress component html and markdown codecs roundtrip percent value" {
    const progress = Progress{ .value = 0.64 };
    var encoded: [128]u8 = undefined;

    const html = try progress.toHtml(&encoded);
    try std.testing.expectEqualStrings("<progress data-er-component=\"progress\" value=\"64\" max=\"100\"></progress>", html);
    const html_decoded = try Progress.fromHtml(html);
    try std.testing.expect(@abs(html_decoded.value - progress.value) < 0.001);

    const markdown = try progress.toMarkdown(&encoded);
    try std.testing.expectEqualStrings(":::progress-control\nvalue: 64\n:::", markdown);
    const markdown_decoded = try Progress.fromMarkdown(markdown);
    try std.testing.expect(@abs(markdown_decoded.value - progress.value) < 0.001);
}
