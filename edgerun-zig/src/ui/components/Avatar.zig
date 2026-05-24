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

pub const Avatar = struct {
    label: []const u8,

    pub fn node(self: Avatar) ui.Node {
        return ui.avatarNode(self.label);
    }

    pub fn render(self: Avatar, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return common.renderNode(scene, bounds, self.node(), options);
    }

    pub fn measure(self: Avatar, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return common.measureNode(self.node(), constraints);
    }

    pub fn toObject(self: Avatar, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return component_codec.oneStringObject(.avatar, 0, self.label, ui_out, object_out, req, epoch);
    }

    pub fn writeRecord(self: Avatar, writer: *component_codec.Writer, index: usize) bool {
        return component_codec.oneStringRecord(writer, index, .avatar, 0, self.label);
    }

    pub fn fromView(view: object.View) Error!Avatar {
        return switch (try component_codec.singleNode(view)) {
            .avatar => |avatar| .{ .label = avatar.label },
            else => error.UnsupportedComponent,
        };
    }

    pub fn toHtml(self: Avatar, out: []u8) HtmlError![]u8 {
        return writeHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, text_out: []u8) HtmlError!Avatar {
        return readHtml(html, text_out);
    }

    pub fn toMarkdown(self: Avatar, out: []u8) MarkdownError![]u8 {
        return writeMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Avatar {
        return readMarkdown(markdown, text_out);
    }
};

pub fn writeHtml(avatar: Avatar, out: []u8) HtmlError![]u8 {
    var writer = HtmlWriter.init(out);
    try writeHtmlInto(&writer, avatar);
    return writer.written();
}

pub fn writeHtmlInto(writer: *HtmlWriter, avatar: Avatar) HtmlError!void {
    try writer.writeAll("<span data-er-component=\"avatar\"");
    try writer.writeAttrText("aria-label", avatar.label);
    try writer.writeByte('>');
    try writer.writeEscapedText(avatar.label);
    try writer.writeAll("</span>");
}

pub fn readHtml(html: []const u8, text_out: []u8) HtmlError!Avatar {
    var arena = HtmlTextArena.init(text_out);
    return readHtmlWithArena(html, &arena);
}

pub fn readHtmlWithArena(html: []const u8, text: *HtmlTextArena) HtmlError!Avatar {
    const prefix = "<span data-er-component=\"avatar\" aria-label=\"";
    if (!std.mem.startsWith(u8, html, prefix)) return error.UnsupportedHtml;
    const after_label = html[prefix.len..];
    const label_end = std.mem.indexOf(u8, after_label, "\">") orelse return error.InvalidHtml;
    if (!std.mem.endsWith(u8, html, "</span>")) return error.InvalidHtml;
    const visible_start = prefix.len + label_end + "\">".len;
    const label = try text.unescape(after_label[0..label_end]);
    const visible = try text.unescape(html[visible_start .. html.len - "</span>".len]);
    if (!std.mem.eql(u8, label, visible)) return error.InvalidHtml;
    return .{ .label = label };
}

pub fn writeMarkdown(avatar: Avatar, out: []u8) MarkdownError![]u8 {
    var writer = MarkdownWriter.init(out);
    try writeMarkdownInto(&writer, avatar);
    return writer.written();
}

pub fn writeMarkdownInto(writer: *MarkdownWriter, avatar: Avatar) MarkdownError!void {
    if (avatar.label.len == 0) return error.InvalidMarkdown;
    try writer.beginDirective("avatar");
    try writer.fieldText("label", avatar.label);
    try writer.endDirective();
}

pub fn readMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Avatar {
    var arena = MarkdownTextArena.init(text_out);
    return readMarkdownWithArena(markdown, &arena);
}

pub fn readMarkdownWithArena(markdown: []const u8, arena: *MarkdownTextArena) MarkdownError!Avatar {
    const label = readSingleFieldDirectiveMarkdown(markdown, ":::avatar\nlabel: ", arena) catch |err| switch (err) {
        error.UnsupportedMarkdown => if (std.mem.startsWith(u8, markdown, ":::avatar")) return error.InvalidMarkdown else return error.UnsupportedMarkdown,
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

test "avatar component serializes to canonical object and deserializes" {
    const avatar = Avatar{ .label = "ER" };
    var ui_raw: [128]u8 = undefined;
    var object_raw: [object.header_size + 128]u8 = undefined;

    const canonical = avatar.toObject(&ui_raw, &object_raw, component_test.req(), component_test.epoch()).?;
    const decoded = try Avatar.fromView(try object.View.decode(canonical));

    try std.testing.expectEqualStrings("ER", decoded.label);
}
