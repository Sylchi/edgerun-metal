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
const HtmlTextArena = common.HtmlTextArena;
const HtmlWriter = common.HtmlWriter;
const MarkdownError = common.MarkdownError;
const MarkdownTextArena = common.MarkdownTextArena;
const MarkdownWriter = common.MarkdownWriter;
const RenderOptions = common.RenderOptions;

pub const Kbd = struct {
    label: []const u8,

    pub fn node(self: Kbd) ui.Node {
        return ui.kbdNode(self.label);
    }

    pub fn render(self: Kbd, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return common.renderNode(scene, bounds, self.node(), options);
    }

    pub fn measure(self: Kbd, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return common.measureNode(self.node(), constraints);
    }

    pub fn toObject(self: Kbd, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return component_codec.oneStringObject(.kbd, 0, self.label, ui_out, object_out, req, epoch);
    }

    pub fn writeRecord(self: Kbd, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.oneStringRecord(writer, index, .kbd, 0, self.label);
    }

    pub fn fromView(view: object.View) Error!Kbd {
        return switch (try component_codec.singleNode(view)) {
            .kbd => |kbd| .{ .label = kbd.label },
            else => error.UnsupportedComponent,
        };
    }

    pub fn toHtml(self: Kbd, out: []u8) HtmlError![]u8 {
        return writeHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, text_out: []u8) HtmlError!Kbd {
        return readHtml(html, text_out);
    }

    pub fn toMarkdown(self: Kbd, out: []u8) MarkdownError![]u8 {
        return writeMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Kbd {
        return readMarkdown(markdown, text_out);
    }
};

pub fn writeHtml(kbd: Kbd, out: []u8) HtmlError![]u8 {
    var writer = HtmlWriter.init(out);
    try writeHtmlInto(&writer, kbd);
    return writer.written();
}

pub fn writeHtmlInto(writer: *HtmlWriter, kbd: Kbd) HtmlError!void {
    try writer.writeAll("<kbd data-er-component=\"kbd\">");
    try writer.writeEscapedText(kbd.label);
    try writer.writeAll("</kbd>");
}

pub fn readHtml(html: []const u8, text_out: []u8) HtmlError!Kbd {
    var arena = HtmlTextArena.init(text_out);
    return readHtmlWithArena(html, &arena);
}

pub fn readHtmlWithArena(html: []const u8, text: *HtmlTextArena) HtmlError!Kbd {
    const value = common.takeWrapped(html, "<kbd data-er-component=\"kbd\">", "</kbd>") orelse return error.UnsupportedHtml;
    return .{ .label = try text.unescape(value) };
}

pub fn writeMarkdown(kbd: Kbd, out: []u8) MarkdownError![]u8 {
    var writer = MarkdownWriter.init(out);
    try writeMarkdownInto(&writer, kbd);
    return writer.written();
}

pub fn writeMarkdownInto(writer: *MarkdownWriter, kbd: Kbd) MarkdownError!void {
    if (kbd.label.len == 0) return error.InvalidMarkdown;
    try writer.beginDirective("kbd");
    try writer.fieldText("label", kbd.label);
    try writer.endDirective();
}

pub fn readMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Kbd {
    var arena = MarkdownTextArena.init(text_out);
    return readMarkdownWithArena(markdown, &arena);
}

pub fn readMarkdownWithArena(markdown: []const u8, arena: *MarkdownTextArena) MarkdownError!Kbd {
    const label = readSingleFieldDirectiveMarkdown(markdown, ":::kbd\nlabel: ", arena) catch |err| switch (err) {
        error.UnsupportedMarkdown => if (std.mem.startsWith(u8, markdown, ":::kbd")) return error.InvalidMarkdown else return error.UnsupportedMarkdown,
        else => return error.InvalidMarkdown,
    };
    return .{ .label = label };
}

fn readSingleFieldDirectiveMarkdown(markdown: []const u8, prefix: []const u8, arena: *MarkdownTextArena) MarkdownError![]const u8 {
    if (!std.mem.startsWith(u8, markdown, prefix)) return error.UnsupportedMarkdown;
    if (!std.mem.endsWith(u8, markdown, "\n:::")) return error.InvalidMarkdown;
    const value = markdown[prefix.len .. markdown.len - "\n:::".len];
    if (value.len == 0 or std.mem.indexOfScalar(u8, value, '\n') != null) return error.InvalidMarkdown;
    return arena.unescapeInline(value);
}

test "kbd component serializes to canonical object and deserializes" {
    const kbd = Kbd{ .label = "Ctrl-K" };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = kbd.toObject(&ui_raw, &object_raw, component_test.req(), component_test.epoch()).?;
    const decoded = try Kbd.fromView(try object.View.decode(canonical));

    try std.testing.expectEqualStrings("Ctrl-K", decoded.label);
}
