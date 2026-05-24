const std = @import("std");
const common = @import("../../ui_component_common.zig");
const layout = @import("../../layouts/Types.zig");
const base_frame = @import("base/Frame.zig");
const base_surface = @import("base/Surface.zig");
const ui = @import("../../ui.zig");

const ComponentRegistry = common.ComponentRegistry;
const HtmlError = common.HtmlError;
const HtmlTextArena = common.HtmlTextArena;
const HtmlWriter = common.HtmlWriter;
const MarkdownCursor = common.MarkdownCursor;
const MarkdownError = common.MarkdownError;
const MarkdownTextArena = common.MarkdownTextArena;
const MarkdownWriter = common.MarkdownWriter;
const RegistryError = common.RegistryError;
const RenderOptions = common.RenderOptions;

pub const Figure = struct {
    src: []const u8,
    alt: []const u8,
    caption: []const u8,

    pub fn render(self: Figure, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return renderFigure(self, scene, bounds, options);
    }

    pub fn measure(self: Figure, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return measureFigure(self, constraints);
    }

    pub fn toHtml(self: Figure, out: []u8) HtmlError![]u8 {
        return writeHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, text_out: []u8) HtmlError!Figure {
        return readHtml(html, text_out);
    }

    pub fn toMarkdown(self: Figure, out: []u8) MarkdownError![]u8 {
        return writeMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Figure {
        return readMarkdown(markdown, text_out);
    }

    pub fn register(registry: *ComponentRegistry) RegistryError!void {
        try registry.register(descriptor);
    }
};

pub const descriptor = common.ComponentDescriptor{
    .name = "figure",
    .html_prefix = "<figure data-er-component=\"figure\"",
    .markdown_prefix = ":::figure",
    .render = renderRegistered,
    .write_html = writeHtmlRegistered,
    .write_markdown = writeMarkdownRegistered,
};

pub fn register(registry: *ComponentRegistry) RegistryError!void {
    return Figure.register(registry);
}

pub fn renderFigure(figure: Figure, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    const style = options.style;
    try base_surface.renderFrame(scene, bounds, options);

    const media_bounds = ui.Rect.init(bounds.x + figure_padding_x, bounds.y + figure_padding_y, @max(1.0, bounds.w - figure_padding_x * 2.0), @max(1.0, bounds.h - figure_padding_y * 2.0 - figure_caption_h - figure_caption_gap));
    try base_frame.render(scene, media_bounds, .{ .fill = style.row, .border = style.border, .radius = figure_media_radius });
    try scene.pushWrappedText(media_bounds.insetUniform(figure_alt_padding), figure.alt, style.muted, .{
        .line_height = figure_alt_line_h,
        .average_char_width = figure_alt_avg_w,
        .max_lines = figure_alt_max_lines,
    });

    const caption_y = media_bounds.y + media_bounds.h + figure_caption_gap;
    try scene.pushWrappedText(ui.Rect.init(media_bounds.x, caption_y, media_bounds.w, figure_caption_h), figure.caption, style.text, .{
        .line_height = figure_caption_line_h,
        .average_char_width = figure_caption_avg_w,
        .max_lines = figure_caption_max_lines,
    });
}

pub fn measureFigure(figure: Figure, constraints: layout.Constraints) layout.Measurement {
    const inner = constraints.inner(figureInsets());
    const width = inner.width.limit(figure_default_media_w);
    const media_height = @max(figure_min_media_h, width * figure_media_aspect_h_over_w);
    const caption = layout.measureText(figure.caption, inner, .{
        .line_height = figure_caption_line_h,
        .average_char_width = figure_caption_avg_w,
        .max_lines = figure_caption_max_lines,
    });
    const alt = layout.measureText(figure.alt, .{ .width = .{ .exact = width - figure_alt_padding * 2.0 }, .text_wrap = constraints.text_wrap }, .{
        .line_height = figure_alt_line_h,
        .average_char_width = figure_alt_avg_w,
        .max_lines = figure_alt_max_lines,
    });
    const content_height = @max(media_height, alt.preferred.h + figure_alt_padding * 2.0) + figure_caption_gap + caption.preferred.h;
    return layout.Measurement.flexible(
        .{ .w = figure_min_w, .h = figure_padding_y * 2.0 + figure_min_media_h + figure_caption_gap + figure_caption_line_h },
        .{ .w = width, .h = content_height },
        .{ .w = constraints.width.limit(width), .h = content_height },
    ).withInsets(figureInsets()).applyExact(constraints);
}

fn renderRegistered(component: *const anyopaque, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    const figure: *const Figure = @ptrCast(@alignCast(component));
    return renderFigure(figure.*, scene, bounds, options);
}

pub fn writeHtml(figure: Figure, out: []u8) HtmlError![]u8 {
    if (figure.src.len == 0 or figure.alt.len == 0 or figure.caption.len == 0) return error.InvalidHtml;
    var writer = HtmlWriter.init(out);
    try writer.writeAll("<figure data-er-component=\"figure\"><img");
    try writer.writeAttrText("src", figure.src);
    try writer.writeAttrText("alt", figure.alt);
    try writer.writeAll("><figcaption>");
    try writer.writeEscapedText(figure.caption);
    try writer.writeAll("</figcaption></figure>");
    return writer.written();
}

fn writeHtmlRegistered(component: *const anyopaque, out: []u8) HtmlError![]u8 {
    const figure: *const Figure = @ptrCast(@alignCast(component));
    return writeHtml(figure.*, out);
}

pub fn writeMarkdown(figure: Figure, out: []u8) MarkdownError![]u8 {
    if (figure.src.len == 0 or figure.alt.len == 0 or figure.caption.len == 0) return error.InvalidMarkdown;
    var writer = MarkdownWriter.init(out);
    try writer.beginDirective("figure");
    try writer.fieldText("src", figure.src);
    try writer.fieldText("alt", figure.alt);
    try writer.fieldText("caption", figure.caption);
    try writer.endDirective();
    return writer.written();
}

fn writeMarkdownRegistered(component: *const anyopaque, out: []u8) MarkdownError![]u8 {
    const figure: *const Figure = @ptrCast(@alignCast(component));
    return writeMarkdown(figure.*, out);
}

pub fn readMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Figure {
    const prefix = ":::figure\nsrc: ";
    const body = try common.readMarkdownDirectiveBody(markdown, ":::figure", prefix);
    var cursor = MarkdownCursor.init(body);
    var text = MarkdownTextArena.init(text_out);
    const src = try text.unescapeInline(try cursor.fieldBetween("", "\nalt: "));
    const alt = try text.unescapeInline(try cursor.fieldBetween("\nalt: ", "\ncaption: "));
    const caption = try text.unescapeInline(try cursor.tailField("\ncaption: "));
    if (src.len == 0 or alt.len == 0 or caption.len == 0) return error.InvalidMarkdown;
    return .{ .src = src, .alt = alt, .caption = caption };
}

pub fn readHtml(html: []const u8, text_out: []u8) HtmlError!Figure {
    const prefix = "<figure data-er-component=\"figure\"><img src=\"";
    if (!std.mem.startsWith(u8, html, prefix)) {
        if (std.mem.startsWith(u8, html, "<figure")) return error.InvalidHtml;
        return error.UnsupportedHtml;
    }
    const after_src = html[prefix.len..];
    const src_end = std.mem.indexOf(u8, after_src, "\" alt=\"") orelse return error.InvalidHtml;
    const alt_start = prefix.len + src_end + "\" alt=\"".len;
    const after_alt = html[alt_start..];
    const alt_end = std.mem.indexOf(u8, after_alt, "\"><figcaption>") orelse return error.InvalidHtml;
    const caption_start = alt_start + alt_end + "\"><figcaption>".len;
    if (!std.mem.endsWith(u8, html, "</figcaption></figure>")) return error.InvalidHtml;

    var text = HtmlTextArena.init(text_out);
    const src = try text.unescape(after_src[0..src_end]);
    const alt = try text.unescape(after_alt[0..alt_end]);
    const caption = try text.unescape(html[caption_start .. html.len - "</figcaption></figure>".len]);
    if (src.len == 0 or alt.len == 0 or caption.len == 0) return error.InvalidHtml;
    return .{ .src = src, .alt = alt, .caption = caption };
}

const figure_media_radius: f32 = 6.0;
const figure_padding_x: f32 = 12.0;
const figure_padding_y: f32 = 12.0;
const figure_alt_padding: f32 = 14.0;
const figure_alt_line_h: f32 = 18.0;
const figure_alt_avg_w: f32 = 9.0;
const figure_alt_max_lines: usize = 3;
const figure_caption_gap: f32 = 10.0;
const figure_caption_h: f32 = 42.0;
const figure_caption_line_h: f32 = 18.0;
const figure_caption_avg_w: f32 = 9.0;
const figure_caption_max_lines: usize = 2;
const figure_default_media_w: f32 = 360.0;
const figure_min_w: f32 = 180.0;
const figure_min_media_h: f32 = 96.0;
const figure_media_aspect_h_over_w: f32 = 0.45;

fn figureInsets() layout.Insets {
    return .{ .top = figure_padding_y, .right = figure_padding_x, .bottom = figure_padding_y, .left = figure_padding_x };
}

test "figure component renders alt text and caption" {
    const figure = Figure{
        .src = "/assets/dns-path.png",
        .alt = "Packet path from browser to resolver",
        .caption = "DNS translates a name before the browser can connect.",
    };
    var commands: [64]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try figure.render(&scene, ui.Rect.init(0, 0, 360, 180), .{});

    try std.testing.expect(hasTextContaining(scene.written(), "Packet path"));
    try std.testing.expect(hasTextContaining(scene.written(), "DNS translates"));
}

test "figure measurement keeps media and caption responsive" {
    const figure = Figure{
        .src = "/assets/dns-path.png",
        .alt = "Packet path from browser to resolver with each boundary labelled",
        .caption = "DNS translates a name before the browser can connect to the next hop.",
    };

    const wide = figure.measure(.{ .width = .{ .exact = 360 }, .text_wrap = .wrap }, .{});
    const narrow = figure.measure(.{ .width = .{ .exact = 200 }, .text_wrap = .wrap }, .{});

    try std.testing.expectEqual(@as(f32, 360), wide.preferred.w);
    try std.testing.expectEqual(@as(f32, 200), narrow.preferred.w);
    try std.testing.expect(wide.preferred.h > narrow.preferred.h);
}

test "figure html codec roundtrips semantic media" {
    const figure = Figure{
        .src = "/assets/device-city.png?size=wide",
        .alt = "Device < city map",
        .caption = "A device is easier to understand when it is drawn as rooms and borders.",
    };
    var html: [512]u8 = undefined;
    var text: [256]u8 = undefined;

    const encoded = try figure.toHtml(&html);
    const decoded = try Figure.fromHtml(encoded, &text);

    try std.testing.expectEqualStrings("<figure data-er-component=\"figure\"><img src=\"/assets/device-city.png?size=wide\" alt=\"Device &lt; city map\"><figcaption>A device is easier to understand when it is drawn as rooms and borders.</figcaption></figure>", encoded);
    try std.testing.expectEqualStrings("/assets/device-city.png?size=wide", decoded.src);
    try std.testing.expectEqualStrings("Device < city map", decoded.alt);
    try std.testing.expectEqualStrings("A device is easier to understand when it is drawn as rooms and borders.", decoded.caption);
}

test "figure html codec rejects malformed figures" {
    var text: [128]u8 = undefined;

    try std.testing.expectError(error.InvalidHtml, Figure.fromHtml("<figure><img src=\"/x.png\" alt=\"x\"><figcaption>x</figcaption></figure>", &text));
    try std.testing.expectError(error.InvalidHtml, Figure.fromHtml("<figure data-er-component=\"figure\"><img src=\"\" alt=\"x\"><figcaption>x</figcaption></figure>", &text));
    try std.testing.expectError(error.InvalidHtml, Figure.fromHtml("<figure data-er-component=\"figure\"><img src=\"/x.png\"><figcaption>x</figcaption></figure>", &text));
}

test "figure registers explicit runtime descriptor" {
    const figure = Figure{
        .src = "/assets/demo.png",
        .alt = "Demo image",
        .caption = "The app registered the media component.",
    };
    var entries: [1]common.ComponentDescriptor = undefined;
    var registry = ComponentRegistry.init(&entries);
    var html: [512]u8 = undefined;
    var markdown: [512]u8 = undefined;
    var commands: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try Figure.register(&registry);
    try std.testing.expectError(error.DuplicateComponent, Figure.register(&registry));
    try std.testing.expectEqualStrings("figure", registry.matchHtml("<figure data-er-component=\"figure\"></figure>").?.name);
    try std.testing.expectEqualStrings("figure", registry.matchMarkdown(":::figure\nsrc: /x\n:::").?.name);

    const encoded_html = try registry.writeHtml("figure", &figure, &html);
    const encoded_markdown = try registry.writeMarkdown("figure", &figure, &markdown);
    try registry.render("figure", &figure, &scene, ui.Rect.init(0, 0, 320, 160), .{});

    try std.testing.expect(std.mem.indexOf(u8, encoded_html, "<figure data-er-component=\"figure\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded_markdown, ":::figure") != null);
    try std.testing.expect(hasTextContaining(scene.written(), "registered the media"));
}

fn hasTextContaining(commands: []const ui.Command, needle: []const u8) bool {
    for (commands) |command| {
        if (command == .text and std.mem.indexOf(u8, command.text.value, needle) != null) return true;
    }
    return false;
}
