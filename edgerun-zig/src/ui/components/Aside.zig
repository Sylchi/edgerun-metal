const std = @import("std");
const common = @import("../../ui_component_common.zig");
const layout = @import("../../layouts/Types.zig");
const base_accent_rail = @import("base/AccentRail.zig");
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

pub const Aside = struct {
    title: []const u8,
    body: []const u8,

    pub fn render(self: Aside, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return renderAside(self, scene, bounds, options);
    }

    pub fn measure(self: Aside, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return measureAside(self, constraints);
    }

    pub fn toHtml(self: Aside, out: []u8) HtmlError![]u8 {
        return writeHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, text_out: []u8) HtmlError!Aside {
        return readHtml(html, text_out);
    }

    pub fn toMarkdown(self: Aside, out: []u8) MarkdownError![]u8 {
        return writeMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Aside {
        return readMarkdown(markdown, text_out);
    }

    pub fn register(registry: *ComponentRegistry) RegistryError!void {
        try registry.register(descriptor);
    }
};

pub const descriptor = common.ComponentDescriptor{
    .name = "aside",
    .html_prefix = "<aside data-er-component=\"aside\"",
    .markdown_prefix = ":::aside",
    .render = renderRegistered,
    .write_html = writeHtmlRegistered,
    .write_markdown = writeMarkdownRegistered,
};

pub fn register(registry: *ComponentRegistry) RegistryError!void {
    return Aside.register(registry);
}

pub fn renderAside(aside: Aside, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    const style = options.style;
    try base_surface.renderFrame(scene, bounds, options);
    try base_accent_rail.render(scene, bounds, style.accent, .{ .radius = base_surface.radius });

    const content = bounds.insetLtrb(aside_padding_x, aside_padding_y, aside_padding_x, aside_padding_y);
    try scene.pushWrappedText(ui.Rect.init(content.x, content.y, content.w, aside_title_h), aside.title, style.text, .{
        .line_height = aside_title_line_h,
        .average_char_width = aside_title_avg_w,
        .max_lines = aside_title_max_lines,
    });
    try scene.pushWrappedText(ui.Rect.init(content.x, content.y + aside_body_y, content.w, @max(1.0, content.h - aside_body_y)), aside.body, style.muted, .{
        .line_height = aside_body_line_h,
        .average_char_width = aside_body_avg_w,
        .max_lines = aside_body_max_lines,
    });
}

pub fn measureAside(aside: Aside, constraints: layout.Constraints) layout.Measurement {
    const content_constraints = constraints.inner(asideInsets());
    const title = layout.measureText(aside.title, content_constraints, .{
        .line_height = aside_title_line_h,
        .average_char_width = aside_title_avg_w,
        .max_lines = aside_title_max_lines,
    });
    const body = layout.measureText(aside.body, content_constraints, .{
        .line_height = aside_body_line_h,
        .average_char_width = aside_body_avg_w,
        .max_lines = aside_body_max_lines,
    });
    const content_width = @max(title.preferred.w, body.preferred.w);
    const content_height = title.preferred.h + aside_body_gap + body.preferred.h;
    return layout.Measurement.flexible(
        .{ .w = aside_min_w, .h = aside_padding_y * 2.0 + aside_title_line_h + aside_body_gap + aside_body_line_h },
        .{ .w = content_width, .h = content_height },
        .{ .w = constraints.width.limit(content_width), .h = content_height },
    ).withInsets(asideInsets()).applyExact(constraints);
}

fn renderRegistered(component: *const anyopaque, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    const aside: *const Aside = @ptrCast(@alignCast(component));
    return renderAside(aside.*, scene, bounds, options);
}

pub fn writeHtml(aside: Aside, out: []u8) HtmlError![]u8 {
    if (aside.title.len == 0 or aside.body.len == 0) return error.InvalidHtml;
    var writer = HtmlWriter.init(out);
    try writer.writeAll("<aside data-er-component=\"aside\"><h2>");
    try writer.writeEscapedText(aside.title);
    try writer.writeAll("</h2><p>");
    try writer.writeEscapedText(aside.body);
    try writer.writeAll("</p></aside>");
    return writer.written();
}

fn writeHtmlRegistered(component: *const anyopaque, out: []u8) HtmlError![]u8 {
    const aside: *const Aside = @ptrCast(@alignCast(component));
    return writeHtml(aside.*, out);
}

pub fn writeMarkdown(aside: Aside, out: []u8) MarkdownError![]u8 {
    if (aside.title.len == 0 or aside.body.len == 0) return error.InvalidMarkdown;
    var writer = MarkdownWriter.init(out);
    try writer.beginDirective("aside");
    try writer.fieldText("title", aside.title);
    try writer.fieldText("body", aside.body);
    try writer.endDirective();
    return writer.written();
}

fn writeMarkdownRegistered(component: *const anyopaque, out: []u8) MarkdownError![]u8 {
    const aside: *const Aside = @ptrCast(@alignCast(component));
    return writeMarkdown(aside.*, out);
}

pub fn readMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Aside {
    const prefix = ":::aside\ntitle: ";
    const directive_body = try common.readMarkdownDirectiveBody(markdown, ":::aside", prefix);
    var cursor = MarkdownCursor.init(directive_body);
    var text = MarkdownTextArena.init(text_out);
    const title = try text.unescapeInline(try cursor.fieldBetween("", "\nbody: "));
    const body = try text.unescapeInline(try cursor.tailField("\nbody: "));
    if (title.len == 0 or body.len == 0) return error.InvalidMarkdown;
    return .{ .title = title, .body = body };
}

pub fn readHtml(html: []const u8, text_out: []u8) HtmlError!Aside {
    const body = common.takeWrapped(html, "<aside data-er-component=\"aside\"><h2>", "</p></aside>") orelse {
        if (std.mem.startsWith(u8, html, "<aside")) return error.InvalidHtml;
        return error.UnsupportedHtml;
    };
    const title_end = std.mem.indexOf(u8, body, "</h2><p>") orelse return error.InvalidHtml;
    const body_start = title_end + "</h2><p>".len;
    var text = HtmlTextArena.init(text_out);
    const title = try text.unescape(body[0..title_end]);
    const content = try text.unescape(body[body_start..]);
    if (title.len == 0 or content.len == 0) return error.InvalidHtml;
    return .{ .title = title, .body = content };
}

const aside_padding_x: f32 = 18.0;
const aside_padding_y: f32 = 14.0;
const aside_title_h: f32 = 22.0;
const aside_title_line_h: f32 = 18.0;
const aside_title_avg_w: f32 = 9.0;
const aside_title_max_lines: usize = 1;
const aside_body_y: f32 = 30.0;
const aside_body_gap: f32 = 8.0;
const aside_body_line_h: f32 = 18.0;
const aside_body_avg_w: f32 = 9.0;
const aside_body_max_lines: usize = 4;
const aside_min_w: f32 = 180.0;

fn asideInsets() layout.Insets {
    return .{ .top = aside_padding_y, .right = aside_padding_x, .bottom = aside_padding_y, .left = aside_padding_x };
}

test "aside component renders title and body" {
    const aside = Aside{
        .title = "Mental model",
        .body = "Think of a capability as a key that only opens one specific door.",
    };
    var commands: [48]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try aside.render(&scene, ui.Rect.init(0, 0, 360, 120), .{});

    try std.testing.expect(hasText(scene.written(), "Mental model"));
    try std.testing.expect(hasTextContaining(scene.written(), "capability as a key"));
}

test "aside measurement follows wrapped body content" {
    const aside = Aside{
        .title = "Mental model",
        .body = "A capability is easier to understand when the layout lets the explanation wrap instead of guessing a fixed height.",
    };

    const wide = aside.measure(.{ .width = .{ .exact = 520 }, .text_wrap = .wrap }, .{});
    const narrow = aside.measure(.{ .width = .{ .exact = 180 }, .text_wrap = .wrap }, .{});

    try std.testing.expectEqual(@as(f32, 520), wide.preferred.w);
    try std.testing.expectEqual(@as(f32, 180), narrow.preferred.w);
    try std.testing.expect(narrow.preferred.h > wide.preferred.h);
}

test "aside html codec roundtrips semantic side note" {
    const aside = Aside{
        .title = "Why this matters",
        .body = "Security gets easier when authority is visible & narrow.",
    };
    var html: [384]u8 = undefined;
    var text: [256]u8 = undefined;

    const encoded = try aside.toHtml(&html);
    const decoded = try Aside.fromHtml(encoded, &text);

    try std.testing.expectEqualStrings("<aside data-er-component=\"aside\"><h2>Why this matters</h2><p>Security gets easier when authority is visible &amp; narrow.</p></aside>", encoded);
    try std.testing.expectEqualStrings("Why this matters", decoded.title);
    try std.testing.expectEqualStrings("Security gets easier when authority is visible & narrow.", decoded.body);
}

test "aside html codec rejects malformed side notes" {
    var text: [128]u8 = undefined;

    try std.testing.expectError(error.InvalidHtml, Aside.fromHtml("<aside><h2>Plain</h2><p>No component marker</p></aside>", &text));
    try std.testing.expectError(error.InvalidHtml, Aside.fromHtml("<aside data-er-component=\"aside\"><h2></h2><p>Missing title</p></aside>", &text));
    try std.testing.expectError(error.InvalidHtml, Aside.fromHtml("<aside data-er-component=\"aside\"><h2>Missing body</h2><p></p></aside>", &text));
}

test "aside registers explicit runtime descriptor" {
    const aside = Aside{
        .title = "Authority",
        .body = "The app registered the side-note component.",
    };
    var entries: [1]common.ComponentDescriptor = undefined;
    var registry = ComponentRegistry.init(&entries);
    var html: [384]u8 = undefined;
    var markdown: [384]u8 = undefined;
    var commands: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try Aside.register(&registry);
    try std.testing.expectError(error.DuplicateComponent, Aside.register(&registry));
    try std.testing.expectEqualStrings("aside", registry.matchHtml("<aside data-er-component=\"aside\"></aside>").?.name);
    try std.testing.expectEqualStrings("aside", registry.matchMarkdown(":::aside\ntitle: x\n:::").?.name);

    const encoded_html = try registry.writeHtml("aside", &aside, &html);
    const encoded_markdown = try registry.writeMarkdown("aside", &aside, &markdown);
    try registry.render("aside", &aside, &scene, ui.Rect.init(0, 0, 320, 120), .{});

    try std.testing.expect(std.mem.indexOf(u8, encoded_html, "<aside data-er-component=\"aside\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded_markdown, ":::aside") != null);
    try std.testing.expect(hasText(scene.written(), "Authority"));
}

fn hasText(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| {
        if (command == .text and std.mem.eql(u8, command.text.value, value)) return true;
    }
    return false;
}

fn hasTextContaining(commands: []const ui.Command, needle: []const u8) bool {
    for (commands) |command| {
        if (command == .text and std.mem.indexOf(u8, command.text.value, needle) != null) return true;
    }
    return false;
}
