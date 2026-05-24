const std = @import("std");
const common = @import("../../ui_component_common.zig");
const ui = @import("../../ui.zig");
const layout = @import("../../layouts/Types.zig");
const base_accent_rail = @import("base/AccentRail.zig");
const base_surface = @import("base/Surface.zig");

const ComponentRegistry = common.ComponentRegistry;
const HtmlError = common.HtmlError;
const HtmlTextArena = common.HtmlTextArena;
const HtmlWriter = common.HtmlWriter;
const MarkdownError = common.MarkdownError;
const MarkdownTextArena = common.MarkdownTextArena;
const MarkdownWriter = common.MarkdownWriter;
const RegistryError = common.RegistryError;
const RenderOptions = common.RenderOptions;

pub const Callout = struct {
    value: []const u8,

    pub fn render(self: Callout, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return renderCallout(self, scene, bounds, options);
    }

    pub fn measure(self: Callout, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return measureCallout(self, constraints);
    }

    pub fn toHtml(self: Callout, out: []u8) HtmlError![]u8 {
        return writeHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, text_out: []u8) HtmlError!Callout {
        return readHtml(html, text_out);
    }

    pub fn toMarkdown(self: Callout, out: []u8) MarkdownError![]u8 {
        return writeMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Callout {
        return readMarkdown(markdown, text_out);
    }

    pub fn register(registry: *ComponentRegistry) RegistryError!void {
        try registry.register(descriptor);
    }
};

pub const descriptor = common.ComponentDescriptor{
    .name = "callout",
    .html_prefix = "<blockquote data-er-component=\"callout\"",
    .markdown_prefix = "> ",
    .render = renderRegistered,
    .write_html = writeHtmlRegistered,
    .write_markdown = writeMarkdownRegistered,
};

pub fn register(registry: *ComponentRegistry) RegistryError!void {
    return Callout.register(registry);
}

pub fn renderCallout(callout: Callout, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    var frame_options = options;
    frame_options.surface_variant = .subtle;
    try base_surface.renderFrame(scene, bounds, frame_options);
    try base_accent_rail.render(scene, bounds, options.style.accent, .{ .radius = base_surface.radius });
    try scene.pushWrappedText(bounds.insetLtrb(callout_text_x, callout_text_y, callout_text_x, callout_text_y), callout.value, options.style.text, .{
        .line_height = callout_line_h,
        .average_char_width = callout_avg_w,
        .max_lines = callout_max_lines,
    });
}

pub fn measureCallout(callout: Callout, constraints: layout.Constraints) layout.Measurement {
    const insets = calloutInsets();
    return layout.measureText(callout.value, constraints.inner(insets), .{
        .line_height = callout_line_h,
        .average_char_width = callout_avg_w,
        .max_lines = callout_max_lines,
    }).withInsets(insets).applyExact(constraints);
}

fn renderRegistered(component: *const anyopaque, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    const callout: *const Callout = @ptrCast(@alignCast(component));
    return renderCallout(callout.*, scene, bounds, options);
}

pub fn writeHtml(callout: Callout, out: []u8) HtmlError![]u8 {
    var writer = HtmlWriter.init(out);
    try writer.writeAll("<blockquote data-er-component=\"callout\">");
    try writer.writeEscapedText(callout.value);
    try writer.writeAll("</blockquote>");
    return writer.written();
}

fn writeHtmlRegistered(component: *const anyopaque, out: []u8) HtmlError![]u8 {
    const callout: *const Callout = @ptrCast(@alignCast(component));
    return writeHtml(callout.*, out);
}

pub fn writeMarkdown(callout: Callout, out: []u8) MarkdownError![]u8 {
    if (callout.value.len == 0) return error.InvalidMarkdown;
    var writer = MarkdownWriter.init(out);
    try writer.writeAll("> ");
    try writer.writeEscapedInline(callout.value);
    return writer.written();
}

fn writeMarkdownRegistered(component: *const anyopaque, out: []u8) MarkdownError![]u8 {
    const callout: *const Callout = @ptrCast(@alignCast(component));
    return writeMarkdown(callout.*, out);
}

pub fn readMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Callout {
    if (!std.mem.startsWith(u8, markdown, "> ")) {
        if (std.mem.startsWith(u8, markdown, ">")) return error.InvalidMarkdown;
        return error.UnsupportedMarkdown;
    }
    if (std.mem.indexOfScalar(u8, markdown, '\n') != null) return error.InvalidMarkdown;
    var text = MarkdownTextArena.init(text_out);
    const value = try text.unescapeInline(markdown["> ".len..]);
    if (value.len == 0) return error.InvalidMarkdown;
    return .{ .value = value };
}

pub fn readHtml(html: []const u8, text_out: []u8) HtmlError!Callout {
    var text = HtmlTextArena.init(text_out);
    if (common.takeWrapped(html, "<blockquote data-er-component=\"callout\">", "</blockquote>")) |value| {
        return .{ .value = try text.unescape(value) };
    }
    if (std.mem.startsWith(u8, html, "<blockquote")) return error.InvalidHtml;
    return error.UnsupportedHtml;
}

const callout_text_x: f32 = 18.0;
const callout_text_y: f32 = 14.0;
const callout_line_h: f32 = 18.0;
const callout_avg_w: f32 = 9.0;
const callout_max_lines: usize = 4;

fn calloutInsets() layout.Insets {
    return .{
        .top = callout_text_y,
        .right = callout_text_x,
        .bottom = callout_text_y,
        .left = callout_text_x,
    };
}

test "callout component renders accent and wrapped text" {
    const callout = Callout{ .value = "A name is a lookup, not an identity." };
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try callout.render(&scene, ui.Rect.init(0, 0, 360, 72), .{});

    try std.testing.expect(hasTextContaining(scene.written(), "lookup, not an identity"));
    try std.testing.expect(hasFilledRect(scene.written()));
}

test "callout measurement includes padding and wraps body text" {
    const callout = Callout{ .value = "A capability opens one specific door, and the layout should know how tall that explanation becomes." };

    const wide = callout.measure(.{ .width = .{ .exact = 360 }, .text_wrap = .wrap }, .{});
    const narrow = callout.measure(.{ .width = .{ .exact = 160 }, .text_wrap = .wrap }, .{});

    try std.testing.expectEqual(@as(f32, 360), wide.preferred.w);
    try std.testing.expect(narrow.preferred.h > wide.preferred.h);
}

test "callout html codec roundtrips escaped quote content" {
    const callout = Callout{ .value = "TLS < DNS & TPM" };
    var html: [160]u8 = undefined;
    var text: [96]u8 = undefined;

    const encoded = try callout.toHtml(&html);
    const decoded = try Callout.fromHtml(encoded, &text);

    try std.testing.expectEqualStrings("<blockquote data-er-component=\"callout\">TLS &lt; DNS &amp; TPM</blockquote>", encoded);
    try std.testing.expectEqualStrings("TLS < DNS & TPM", decoded.value);
}

test "callout html codec rejects plain browser quotes" {
    var text: [64]u8 = undefined;

    try std.testing.expectError(error.InvalidHtml, Callout.fromHtml("<blockquote>plain quote</blockquote>", &text));
    try std.testing.expectError(error.UnsupportedHtml, Callout.fromHtml("<p>plain paragraph</p>", &text));
}

test "callout markdown codec roundtrips escaped single line quote" {
    const callout = Callout{ .value = "A name is not identity." };
    var markdown: [128]u8 = undefined;
    var text: [96]u8 = undefined;

    const encoded = try callout.toMarkdown(&markdown);
    const decoded = try Callout.fromMarkdown(encoded, &text);

    try std.testing.expectEqualStrings("> A name is not identity\\.", encoded);
    try std.testing.expectEqualStrings("A name is not identity.", decoded.value);
}

test "callout markdown codec rejects ambiguous or multiline quotes" {
    var text: [64]u8 = undefined;

    try std.testing.expectError(error.InvalidMarkdown, Callout.fromMarkdown(">", &text));
    try std.testing.expectError(error.InvalidMarkdown, Callout.fromMarkdown("> ", &text));
    try std.testing.expectError(error.InvalidMarkdown, Callout.fromMarkdown("> One\n> Two", &text));
    try std.testing.expectError(error.UnsupportedMarkdown, Callout.fromMarkdown("plain paragraph", &text));
}

test "callout registers explicit runtime descriptor" {
    const callout = Callout{ .value = "A capability opens one specific door." };
    var entries: [1]common.ComponentDescriptor = undefined;
    var registry = ComponentRegistry.init(&entries);
    var html: [160]u8 = undefined;
    var markdown: [128]u8 = undefined;
    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try Callout.register(&registry);
    try std.testing.expectError(error.DuplicateComponent, Callout.register(&registry));
    try std.testing.expectEqualStrings("callout", registry.matchHtml("<blockquote data-er-component=\"callout\">Note</blockquote>").?.name);
    try std.testing.expectEqualStrings("callout", registry.matchMarkdown("> Note").?.name);

    const encoded_html = try registry.writeHtml("callout", &callout, &html);
    const encoded_markdown = try registry.writeMarkdown("callout", &callout, &markdown);
    try registry.render("callout", &callout, &scene, ui.Rect.init(0, 0, 360, 72), .{});

    try std.testing.expectEqualStrings("<blockquote data-er-component=\"callout\">A capability opens one specific door.</blockquote>", encoded_html);
    try std.testing.expectEqualStrings("> A capability opens one specific door\\.", encoded_markdown);
    try std.testing.expect(hasTextContaining(scene.written(), "A capability"));
}

fn hasTextContaining(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| {
        if (command == .text and std.mem.indexOf(u8, command.text.value, value) != null) return true;
    }
    return false;
}

fn hasFilledRect(commands: []const ui.Command) bool {
    for (commands) |command| {
        if (command == .rect and command.rect.mode == .fill) return true;
    }
    return false;
}
