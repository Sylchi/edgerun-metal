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

pub const Separator = struct {
    pub fn node(self: Separator) ui.Node {
        _ = self;
        return ui.separatorNode();
    }

    pub fn render(self: Separator, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return common.renderNode(scene, bounds, self.node(), options);
    }

    pub fn measure(self: Separator, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return common.measureNode(self.node(), constraints);
    }

    pub fn toObject(self: Separator, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        _ = self;
        return component_codec.emptyObject(.separator, ui_out, object_out, req, epoch);
    }

    pub fn writeRecord(self: Separator, writer: *component_codec.Writer, index: usize) bool {
        _ = self;
        return component_codec.emptyRecord(writer, index, .separator);
    }

    pub fn fromView(view: object.View) Error!Separator {
        return switch (try component_codec.singleNode(view)) {
            .separator => .{},
            else => error.UnsupportedComponent,
        };
    }

    pub fn toHtml(self: Separator, out: []u8) HtmlError![]u8 {
        return writeHtml(self, out);
    }

    pub fn fromHtml(html: []const u8) HtmlError!Separator {
        return readHtml(html);
    }

    pub fn toMarkdown(self: Separator, out: []u8) MarkdownError![]u8 {
        return writeMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8) MarkdownError!Separator {
        return readMarkdown(markdown);
    }
};

pub fn writeHtml(separator: Separator, out: []u8) HtmlError![]u8 {
    var writer = HtmlWriter.init(out);
    try writeHtmlInto(&writer, separator);
    return writer.written();
}

pub fn writeHtmlInto(writer: *HtmlWriter, separator: Separator) HtmlError!void {
    _ = separator;
    try writer.writeAll("<hr data-er-component=\"separator\">");
}

pub fn readHtml(html: []const u8) HtmlError!Separator {
    if (!std.mem.eql(u8, html, "<hr data-er-component=\"separator\">")) return error.UnsupportedHtml;
    return .{};
}

pub fn writeMarkdown(separator: Separator, out: []u8) MarkdownError![]u8 {
    var writer = MarkdownWriter.init(out);
    try writeMarkdownInto(&writer, separator);
    return writer.written();
}

pub fn writeMarkdownInto(writer: *MarkdownWriter, separator: Separator) MarkdownError!void {
    _ = separator;
    try writer.writeAll("---");
}

pub fn readMarkdown(markdown: []const u8) MarkdownError!Separator {
    if (!std.mem.eql(u8, markdown, "---")) return error.UnsupportedMarkdown;
    return .{};
}

test "separator component serializes to canonical object and deserializes" {
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = (Separator{}).toObject(&ui_raw, &object_raw, component_test.req(), component_test.epoch()).?;
    _ = try Separator.fromView(try object.View.decode(canonical));
}
