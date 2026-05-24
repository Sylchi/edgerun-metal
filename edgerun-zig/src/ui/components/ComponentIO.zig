const std = @import("std");
const clock = @import("../../clock.zig");
const common = @import("../../ui_component_common.zig");
const codec = @import("../../ui_codec.zig");
const object = @import("../../object.zig");

const avatar_component = @import("Avatar.zig");
const badge_component = @import("Badge.zig");
const button_component = @import("Button.zig");
const card_component = @import("Card.zig");
const checkbox_component = @import("Checkbox.zig");
const input_component = @import("Input.zig");
const kbd_component = @import("Kbd.zig");
const progress_component = @import("Progress.zig");
const row_item_component = @import("RowItem.zig");
const select_component = @import("Select.zig");
const separator_component = @import("Separator.zig");
const slider_component = @import("Slider.zig");
const switch_component = @import("Switch.zig");
const text_component = @import("Text.zig");
const textarea_component = @import("Textarea.zig");

pub const HtmlError = common.HtmlError;
pub const HtmlTextArena = common.HtmlTextArena;
pub const HtmlWriter = common.HtmlWriter;
pub const MarkdownError = common.MarkdownError;
pub const MarkdownTextArena = common.MarkdownTextArena;
pub const MarkdownWriter = common.MarkdownWriter;

pub const markdown_component_marker = "--- component ---\n";
pub const markdown_next_component_marker = "\n--- component ---\n";

pub fn writeObject(comptime Component: type, component: Component, ui_out: []u8, object_out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
    var writer = codec.Writer.init(ui_out, 1, 1, .column, 0, 0) orelse return null;
    if (!writeRecord(Component, &writer, 0, component)) return null;
    return writer.objectNode(object_out, req, epoch);
}

pub fn writeRecord(comptime Component: type, writer: *codec.Writer, index: usize, component: Component) bool {
    return switch (component) {
        .text => |text| text.writeRecord(writer, index),
        .card => |card| card.writeRecord(writer, index),
        .badge => |badge| badge.writeRecord(writer, index),
        .avatar => |avatar| avatar.writeRecord(writer, index),
        .kbd => |kbd| kbd.writeRecord(writer, index),
        .separator => |separator| separator.writeRecord(writer, index),
        .button => |button| button.writeRecord(writer, index),
        .input => |input| input.writeRecord(writer, index),
        .textarea => |textarea| textarea.writeRecord(writer, index),
        .select => |select| select.writeRecord(writer, index),
        .checkbox => |checkbox| checkbox.writeRecord(writer, index),
        .switch_control => |switch_control| switch_control.writeRecord(writer, index),
        .progress => |progress| progress.writeRecord(writer, index),
        .slider => |slider| slider.writeRecord(writer, index),
        .row_item => |row| row.writeRecord(writer, index),
    };
}

pub fn writeHtml(comptime Component: type, component: Component, out: []u8) HtmlError![]u8 {
    var writer = HtmlWriter.init(out);
    try writeHtmlInto(Component, &writer, component);
    return writer.written();
}

pub fn writeHtmlInto(comptime Component: type, writer: *HtmlWriter, component: Component) HtmlError!void {
    switch (component) {
        .text => |text| try text_component.writeHtmlInto(writer, text),
        .card => |card| try card_component.writeHtmlInto(writer, card),
        .badge => |badge| try badge_component.writeHtmlInto(writer, badge),
        .avatar => |avatar| try avatar_component.writeHtmlInto(writer, avatar),
        .kbd => |kbd| try kbd_component.writeHtmlInto(writer, kbd),
        .separator => |separator| try separator_component.writeHtmlInto(writer, separator),
        .button => |button| try button_component.writeHtmlInto(writer, button),
        .input => |input| try input_component.writeHtmlInto(writer, input),
        .textarea => |textarea| try textarea_component.writeHtmlInto(writer, textarea),
        .select => |select| try select_component.writeHtmlInto(writer, select),
        .checkbox => |checkbox| try checkbox_component.writeHtmlInto(writer, checkbox),
        .switch_control => |switch_control| try switch_component.writeHtmlInto(writer, switch_control),
        .progress => |progress| try progress_component.writeHtmlInto(writer, progress),
        .slider => |slider| try slider_component.writeHtmlInto(writer, slider),
        .row_item => |row| try row_item_component.writeHtmlInto(writer, row),
    }
}

pub fn writeMarkdown(comptime Component: type, component: Component, out: []u8) MarkdownError![]u8 {
    var writer = MarkdownWriter.init(out);
    try writeMarkdownInto(Component, &writer, component);
    return writer.written();
}

pub fn writeMarkdownInto(comptime Component: type, writer: *MarkdownWriter, component: Component) MarkdownError!void {
    switch (component) {
        .text => |text| try text_component.writeMarkdownInto(writer, text),
        .card => |card| try card_component.writeMarkdownInto(writer, card),
        .badge => |badge| try badge_component.writeMarkdownInto(writer, badge),
        .avatar => |avatar| try avatar_component.writeMarkdownInto(writer, avatar),
        .kbd => |kbd| try kbd_component.writeMarkdownInto(writer, kbd),
        .separator => |separator| try separator_component.writeMarkdownInto(writer, separator),
        .button => |button| try button_component.writeMarkdownInto(writer, button),
        .input => |input| try input_component.writeMarkdownInto(writer, input),
        .textarea => |textarea| try textarea_component.writeMarkdownInto(writer, textarea),
        .select => |select| try select_component.writeMarkdownInto(writer, select),
        .checkbox => |checkbox| try checkbox_component.writeMarkdownInto(writer, checkbox),
        .switch_control => |switch_control| try switch_component.writeMarkdownInto(writer, switch_control),
        .progress => |progress| try progress_component.writeMarkdownInto(writer, progress),
        .slider => |slider| try slider_component.writeMarkdownInto(writer, slider),
        .row_item => |row| try row_item_component.writeMarkdownInto(writer, row),
    }
}

pub fn readMarkdown(comptime Component: type, markdown: []const u8, text_out: []u8) MarkdownError!Component {
    var text = MarkdownTextArena.init(text_out);
    return readMarkdownWithArena(Component, markdown, &text);
}

pub fn readMarkdownWithArena(comptime Component: type, markdown: []const u8, text: *MarkdownTextArena) MarkdownError!Component {
    if (std.mem.eql(u8, markdown, "---")) return .{ .separator = try separator_component.readMarkdown(markdown) };
    if (std.mem.startsWith(u8, markdown, ":::card")) return .{ .card = try card_component.readMarkdownWithArena(markdown, text) };
    if (std.mem.startsWith(u8, markdown, ":::badge")) return .{ .badge = try badge_component.readMarkdownWithArena(markdown, text) };
    if (std.mem.startsWith(u8, markdown, ":::avatar")) return .{ .avatar = try avatar_component.readMarkdownWithArena(markdown, text) };
    if (std.mem.startsWith(u8, markdown, ":::kbd")) return .{ .kbd = try kbd_component.readMarkdownWithArena(markdown, text) };
    if (std.mem.startsWith(u8, markdown, ":::button")) return .{ .button = try button_component.readMarkdownWithArena(markdown, text) };
    if (std.mem.startsWith(u8, markdown, ":::input")) return .{ .input = try input_component.readMarkdownWithArena(markdown, text) };
    if (std.mem.startsWith(u8, markdown, ":::textarea")) return .{ .textarea = try textarea_component.readMarkdownWithArena(markdown, text) };
    if (std.mem.startsWith(u8, markdown, ":::select")) return .{ .select = try select_component.readMarkdownWithArena(markdown, text) };
    if (std.mem.startsWith(u8, markdown, ":::checkbox")) return .{ .checkbox = try checkbox_component.readMarkdownWithArena(markdown, text) };
    if (std.mem.startsWith(u8, markdown, ":::switch")) return .{ .switch_control = try switch_component.readMarkdownWithArena(markdown, text) };
    if (std.mem.startsWith(u8, markdown, ":::progress-control")) return .{ .progress = try progress_component.readMarkdown(markdown) };
    if (std.mem.startsWith(u8, markdown, ":::slider")) return .{ .slider = try slider_component.readMarkdownWithArena(markdown, text) };
    if (std.mem.startsWith(u8, markdown, ":::row-item")) return .{ .row_item = try row_item_component.readMarkdownWithArena(markdown, text) };
    if (std.mem.startsWith(u8, markdown, ":::")) return error.UnsupportedMarkdown;
    if (markdown.len == 0 or std.mem.indexOfScalar(u8, markdown, '\n') != null) return error.InvalidMarkdown;
    return .{ .text = try text_component.readMarkdownWithArena(markdown, text) };
}

pub fn readHtml(comptime Component: type, html: []const u8, text_out: []u8) HtmlError!Component {
    var text = HtmlTextArena.init(text_out);
    return readHtmlWithArena(Component, html, &text);
}

pub fn readHtmlWithArena(comptime Component: type, html: []const u8, text: *HtmlTextArena) HtmlError!Component {
    if (common.takeWrapped(html, "<p data-er-component=\"text\">", "</p>")) |value| {
        return .{ .text = .{ .value = try text.unescape(value) } };
    }
    if (common.takeWrapped(html, "<span data-er-component=\"badge\">", "</span>")) |value| {
        return .{ .badge = .{ .label = try text.unescape(value) } };
    }
    if (std.mem.startsWith(u8, html, "<span data-er-component=\"avatar\" aria-label=\"")) return .{ .avatar = try avatar_component.readHtmlWithArena(html, text) };
    if (std.mem.startsWith(u8, html, "<kbd data-er-component=\"kbd\">")) return .{ .kbd = try kbd_component.readHtmlWithArena(html, text) };
    if (std.mem.eql(u8, html, "<hr data-er-component=\"separator\">")) return .{ .separator = try separator_component.readHtml(html) };
    if (std.mem.startsWith(u8, html, "<button data-er-component=\"button\" data-er-id=\"")) return .{ .button = try button_component.readHtmlWithArena(html, text) };
    if (std.mem.startsWith(u8, html, "<input data-er-component=\"input\" data-er-id=\"")) return .{ .input = try input_component.readHtmlWithArena(html, text) };
    if (std.mem.startsWith(u8, html, "<textarea data-er-component=\"textarea\" data-er-id=\"")) return .{ .textarea = try textarea_component.readHtmlWithArena(html, text) };
    if (std.mem.startsWith(u8, html, "<select data-er-component=\"select\" data-er-id=\"")) return .{ .select = try select_component.readHtmlWithArena(html, text) };
    if (std.mem.startsWith(u8, html, "<label data-er-component=\"checkbox\" data-er-id=\"")) return .{ .checkbox = try checkbox_component.readHtmlWithArena(html, text) };
    if (std.mem.startsWith(u8, html, "<button data-er-component=\"switch\" data-er-id=\"")) return .{ .switch_control = try switch_component.readHtmlWithArena(html, text) };
    if (std.mem.startsWith(u8, html, "<progress data-er-component=\"progress\" value=\"")) return .{ .progress = try progress_component.readHtml(html) };
    if (std.mem.startsWith(u8, html, "<label data-er-component=\"slider\" data-er-id=\"")) return .{ .slider = try slider_component.readHtmlWithArena(html, text) };
    if (std.mem.startsWith(u8, html, "<article data-er-component=\"card\"><h2>")) return .{ .card = try card_component.readHtmlWithArena(html, text) };
    if (std.mem.startsWith(u8, html, "<div data-er-component=\"row-item\" data-er-id=\"")) return .{ .row_item = try row_item_component.readHtmlWithArena(html, text) };
    return error.UnsupportedHtml;
}

pub fn readListMarkdownWithArena(comptime Component: type, markdown: []const u8, out_components: []Component, text: *MarkdownTextArena) MarkdownError![]const Component {
    var component_count: usize = 0;
    var cursor: usize = 0;
    while (cursor < markdown.len) {
        if (component_count == out_components.len) return error.MarkdownBudgetExceeded;
        if (!std.mem.startsWith(u8, markdown[cursor..], markdown_component_marker)) return error.InvalidMarkdown;
        const child_start = cursor + markdown_component_marker.len;
        const child_end_relative = std.mem.indexOf(u8, markdown[child_start..], markdown_next_component_marker) orelse markdown[child_start..].len;
        const child_end = child_start + child_end_relative;
        const child_markdown = markdown[child_start..child_end];
        if (child_markdown.len == 0) return error.InvalidMarkdown;
        out_components[component_count] = try readMarkdownWithArena(Component, child_markdown, text);
        component_count += 1;
        cursor = child_end;
        if (cursor < markdown.len) cursor += 1;
    }
    if (component_count == 0) return error.InvalidMarkdown;
    return out_components[0..component_count];
}

pub fn readListHtmlWithArena(comptime Component: type, html: []const u8, out_components: []Component, text: *HtmlTextArena) HtmlError![]const Component {
    var component_count: usize = 0;
    var cursor: usize = 0;
    while (cursor < html.len) {
        if (component_count == out_components.len) return error.HtmlBudgetExceeded;
        const end = childHtmlEnd(html[cursor..]) orelse return error.InvalidHtml;
        out_components[component_count] = try readHtmlWithArena(Component, html[cursor .. cursor + end], text);
        component_count += 1;
        cursor += end;
    }
    return out_components[0..component_count];
}

fn childHtmlEnd(html: []const u8) ?usize {
    const shapes = [_]HtmlShape{
        .{ .prefix = "<p data-er-component=\"text\">", .suffix = "</p>" },
        .{ .prefix = "<span data-er-component=\"badge\">", .suffix = "</span>" },
        .{ .prefix = "<span data-er-component=\"avatar\" aria-label=\"", .suffix = "</span>" },
        .{ .prefix = "<kbd data-er-component=\"kbd\">", .suffix = "</kbd>" },
        .{ .prefix = "<hr data-er-component=\"separator\">", .suffix = "" },
        .{ .prefix = "<button data-er-component=\"button\" data-er-id=\"", .suffix = "</button>" },
        .{ .prefix = "<input data-er-component=\"input\" data-er-id=\"", .suffix = ">" },
        .{ .prefix = "<textarea data-er-component=\"textarea\" data-er-id=\"", .suffix = "</textarea>" },
        .{ .prefix = "<select data-er-component=\"select\" data-er-id=\"", .suffix = "</select>" },
        .{ .prefix = "<label data-er-component=\"checkbox\" data-er-id=\"", .suffix = "</label>" },
        .{ .prefix = "<button data-er-component=\"switch\" data-er-id=\"", .suffix = "</button>" },
        .{ .prefix = "<progress data-er-component=\"progress\" value=\"", .suffix = "</progress>" },
        .{ .prefix = "<label data-er-component=\"slider\" data-er-id=\"", .suffix = "</label>" },
        .{ .prefix = "<article data-er-component=\"card\"><h2>", .suffix = "</p></article>" },
        .{ .prefix = "<div data-er-component=\"row-item\" data-er-id=\"", .suffix = "</span></div>" },
    };
    for (shapes) |shape| {
        if (!std.mem.startsWith(u8, html, shape.prefix)) continue;
        if (shape.suffix.len == 0) return shape.prefix.len;
        const suffix_start = std.mem.indexOf(u8, html, shape.suffix) orelse return null;
        return suffix_start + shape.suffix.len;
    }
    return null;
}

const HtmlShape = struct {
    prefix: []const u8,
    suffix: []const u8,
};
