const std = @import("std");
const common = @import("../../ui_component_common.zig");
const layout = @import("../../layouts/Types.zig");
const base_surface = @import("base/Surface.zig");
const ui = @import("../../ui.zig");
const ui_input = @import("../../input.zig");

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

pub const Details = struct {
    id: u32,
    summary: []const u8,
    body: []const u8,
    open: bool = false,

    pub fn render(self: Details, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return renderDetails(self, scene, bounds, options);
    }

    pub fn measure(self: Details, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return measureDetails(self, constraints);
    }

    pub fn toHtml(self: Details, out: []u8) HtmlError![]u8 {
        return writeHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, text_out: []u8) HtmlError!Details {
        return readHtml(html, text_out);
    }

    pub fn toMarkdown(self: Details, out: []u8) MarkdownError![]u8 {
        return writeMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Details {
        return readMarkdown(markdown, text_out);
    }

    pub fn register(registry: *ComponentRegistry) RegistryError!void {
        try registry.register(descriptor);
    }
};

pub const descriptor = common.ComponentDescriptor{
    .name = "details",
    .html_prefix = "<details data-er-component=\"details\"",
    .markdown_prefix = ":::details",
    .render = renderRegistered,
    .write_html = writeHtmlRegistered,
    .write_markdown = writeMarkdownRegistered,
};

pub fn register(registry: *ComponentRegistry) RegistryError!void {
    return Details.register(registry);
}

pub fn renderDetails(details: Details, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    const style = options.style;
    try base_surface.renderFrame(scene, bounds, options);

    const summary_bounds = ui.Rect.init(bounds.x + details_padding_x, bounds.y + details_padding_y, @max(1.0, bounds.w - details_padding_x * 2.0), details_summary_h);
    try scene.pushAlignedText(ui.Rect.init(summary_bounds.x, summary_bounds.y + details_summary_text_y, @max(1.0, summary_bounds.w - details_marker_w), details_summary_text_h), details.summary, style.text, .start);
    try scene.pushAlignedText(ui.Rect.init(summary_bounds.x + summary_bounds.w - details_marker_w, summary_bounds.y + details_summary_text_y, details_marker_w, details_summary_text_h), if (details.open) "v" else ">", style.accent, .center);
    try scene.pushHit(.{ .slot = 0, .kind = .button, .id = details.id, .bounds = summary_bounds });

    if (!details.open) return;
    const body_y = summary_bounds.y + summary_bounds.h + details_body_gap;
    if (body_y >= bounds.y + bounds.h - details_padding_y) return;
    try scene.pushWrappedText(ui.Rect.init(summary_bounds.x, body_y, summary_bounds.w, @max(1.0, bounds.y + bounds.h - details_padding_y - body_y)), details.body, style.muted, .{
        .line_height = details_body_line_h,
        .average_char_width = details_body_avg_w,
        .max_lines = details_body_max_lines,
    });
}

pub fn measureDetails(details: Details, constraints: layout.Constraints) layout.Measurement {
    const content_constraints = constraints.inner(detailsInsets());
    const summary_constraints = content_constraints.inner(.{ .right = details_marker_w });
    const summary = layout.measureText(details.summary, summary_constraints, .{
        .line_height = details_summary_text_h,
        .average_char_width = details_summary_avg_w,
        .max_lines = details_summary_max_lines,
    });
    var content_width = summary.preferred.w + details_marker_w;
    var content_height = @max(details_summary_h, summary.preferred.h);
    if (details.open) {
        const body = layout.measureText(details.body, content_constraints, .{
            .line_height = details_body_line_h,
            .average_char_width = details_body_avg_w,
            .max_lines = details_body_max_lines,
        });
        content_width = @max(content_width, body.preferred.w);
        content_height += details_body_gap + body.preferred.h;
    }
    return layout.Measurement.flexible(
        .{ .w = details_min_w, .h = details_padding_y * 2.0 + details_summary_h },
        .{ .w = content_width, .h = content_height },
        .{ .w = constraints.width.limit(content_width), .h = content_height },
    ).withInsets(detailsInsets()).applyExact(constraints);
}

fn renderRegistered(component: *const anyopaque, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    const details: *const Details = @ptrCast(@alignCast(component));
    return renderDetails(details.*, scene, bounds, options);
}

pub fn writeHtml(details: Details, out: []u8) HtmlError![]u8 {
    var writer = HtmlWriter.init(out);
    try writer.writeAll("<details data-er-component=\"details\"");
    try writer.writeAttrInt("data-er-id", details.id);
    try writer.writeAttrBool("data-er-open", details.open);
    try writer.writeAll("><summary>");
    try writer.writeEscapedText(details.summary);
    try writer.writeAll("</summary><p>");
    try writer.writeEscapedText(details.body);
    try writer.writeAll("</p></details>");
    return writer.written();
}

fn writeHtmlRegistered(component: *const anyopaque, out: []u8) HtmlError![]u8 {
    const details: *const Details = @ptrCast(@alignCast(component));
    return writeHtml(details.*, out);
}

pub fn writeMarkdown(details: Details, out: []u8) MarkdownError![]u8 {
    if (details.summary.len == 0 or details.body.len == 0) return error.InvalidMarkdown;
    var writer = MarkdownWriter.init(out);
    try writer.beginDirective("details");
    try writer.fieldInt("id", details.id);
    try writer.fieldBool("open", details.open);
    try writer.fieldText("summary", details.summary);
    try writer.fieldText("body", details.body);
    try writer.endDirective();
    return writer.written();
}

fn writeMarkdownRegistered(component: *const anyopaque, out: []u8) MarkdownError![]u8 {
    const details: *const Details = @ptrCast(@alignCast(component));
    return writeMarkdown(details.*, out);
}

pub fn readMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!Details {
    const prefix = ":::details\nid: ";
    const body = try common.readMarkdownDirectiveBody(markdown, ":::details", prefix);
    var cursor = MarkdownCursor.init(body);
    const id = try common.parseMarkdownU32(try cursor.fieldBetween("", "\nopen: "));
    const open = try common.parseMarkdownBool(try cursor.fieldBetween("\nopen: ", "\nsummary: "));
    var text = MarkdownTextArena.init(text_out);
    const summary = try text.unescapeInline(try cursor.fieldBetween("\nsummary: ", "\nbody: "));
    const content = try text.unescapeInline(try cursor.tailField("\nbody: "));
    if (summary.len == 0 or content.len == 0) return error.InvalidMarkdown;
    return .{ .id = id, .summary = summary, .body = content, .open = open };
}

pub fn readHtml(html: []const u8, text_out: []u8) HtmlError!Details {
    const prefix = "<details data-er-component=\"details\" data-er-id=\"";
    if (!std.mem.startsWith(u8, html, prefix)) {
        if (std.mem.startsWith(u8, html, "<details")) return error.InvalidHtml;
        return error.UnsupportedHtml;
    }
    const after_id = html[prefix.len..];
    const id_end = std.mem.indexOf(u8, after_id, "\" data-er-open=\"") orelse return error.InvalidHtml;
    const id = try common.parseHtmlU32(after_id[0..id_end]);
    const open_start = prefix.len + id_end + "\" data-er-open=\"".len;
    const after_open = html[open_start..];
    const open_end = std.mem.indexOf(u8, after_open, "\"><summary>") orelse return error.InvalidHtml;
    const open = try common.parseHtmlBool(after_open[0..open_end]);
    const summary_start = open_start + open_end + "\"><summary>".len;
    const summary_end_relative = std.mem.indexOf(u8, html[summary_start..], "</summary><p>") orelse return error.InvalidHtml;
    const body_start = summary_start + summary_end_relative + "</summary><p>".len;
    if (!std.mem.endsWith(u8, html, "</p></details>")) return error.InvalidHtml;

    var text = HtmlTextArena.init(text_out);
    return .{
        .id = id,
        .summary = try text.unescape(html[summary_start .. summary_start + summary_end_relative]),
        .body = try text.unescape(html[body_start .. html.len - "</p></details>".len]),
        .open = open,
    };
}

const details_padding_x: f32 = 14.0;
const details_padding_y: f32 = 12.0;
const details_summary_h: f32 = 28.0;
const details_summary_text_y: f32 = 7.0;
const details_summary_text_h: f32 = 14.0;
const details_summary_avg_w: f32 = 8.5;
const details_summary_max_lines: usize = 1;
const details_marker_w: f32 = 24.0;
const details_body_gap: f32 = 10.0;
const details_body_line_h: f32 = 18.0;
const details_body_avg_w: f32 = 9.0;
const details_body_max_lines: usize = 5;
const details_min_w: f32 = 180.0;

fn detailsInsets() layout.Insets {
    return .{ .top = details_padding_y, .right = details_padding_x, .bottom = details_padding_y, .left = details_padding_x };
}

test "details component renders summary and open body" {
    const details = Details{
        .id = 32001,
        .summary = "Why does DNS matter?",
        .body = "The name lookup decides where the next connection goes.",
        .open = true,
    };
    var commands: [64]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try details.render(&scene, ui.Rect.init(0, 0, 360, 120), .{});

    try std.testing.expect(hasText(scene.written(), "Why does DNS matter?"));
    try std.testing.expect(hasTextContaining(scene.written(), "name lookup"));
    const hit = ui_input.hitTest(scene.written(), 20, 20).?;
    try std.testing.expectEqual(@as(u32, 32001), hit.id);
}

test "details component hides body when closed" {
    const details = Details{
        .id = 32002,
        .summary = "What changes when it opens?",
        .body = "The expanded explanation becomes visible.",
    };
    var commands: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try details.render(&scene, ui.Rect.init(0, 0, 360, 120), .{});

    try std.testing.expect(hasText(scene.written(), "What changes when it opens?"));
    try std.testing.expect(!hasTextContaining(scene.written(), "expanded explanation"));
}

test "details measurement expands only when open" {
    const closed = Details{
        .id = 32005,
        .summary = "What changes when it opens?",
        .body = "The expanded explanation becomes visible and should contribute to measurement only when the disclosure is open.",
    };
    const open = Details{
        .id = closed.id,
        .summary = closed.summary,
        .body = closed.body,
        .open = true,
    };

    const closed_size = closed.measure(.{ .width = .{ .exact = 220 }, .text_wrap = .wrap }, .{});
    const open_size = open.measure(.{ .width = .{ .exact = 220 }, .text_wrap = .wrap }, .{});

    try std.testing.expectEqual(@as(f32, 220), open_size.preferred.w);
    try std.testing.expect(open_size.preferred.h > closed_size.preferred.h);
}

test "details html codec roundtrips semantic disclosure" {
    const details = Details{
        .id = 32003,
        .summary = "TLS < identity?",
        .body = "TLS protects a trip. Identity decides who is allowed to act.",
        .open = true,
    };
    var html: [512]u8 = undefined;
    var text: [256]u8 = undefined;

    const encoded = try details.toHtml(&html);
    const decoded = try Details.fromHtml(encoded, &text);

    try std.testing.expectEqualStrings("<details data-er-component=\"details\" data-er-id=\"32003\" data-er-open=\"true\"><summary>TLS &lt; identity?</summary><p>TLS protects a trip. Identity decides who is allowed to act.</p></details>", encoded);
    try std.testing.expectEqual(@as(u32, 32003), decoded.id);
    try std.testing.expect(decoded.open);
    try std.testing.expectEqualStrings("TLS < identity?", decoded.summary);
    try std.testing.expectEqualStrings("TLS protects a trip. Identity decides who is allowed to act.", decoded.body);
}

test "details html codec rejects malformed disclosure" {
    var text: [128]u8 = undefined;

    try std.testing.expectError(error.InvalidHtml, Details.fromHtml("<details><summary>Plain</summary><p>No marker</p></details>", &text));
    try std.testing.expectError(error.InvalidHtml, Details.fromHtml("<details data-er-component=\"details\" data-er-id=\"x\" data-er-open=\"false\"><summary>Broken</summary><p>Body</p></details>", &text));
    try std.testing.expectError(error.InvalidHtml, Details.fromHtml("<details data-er-component=\"details\" data-er-id=\"1\" data-er-open=\"maybe\"><summary>Broken</summary><p>Body</p></details>", &text));
}

test "details registers explicit runtime descriptor" {
    const details = Details{
        .id = 32004,
        .summary = "Who decides?",
        .body = "The registered app surface chooses its component set.",
        .open = true,
    };
    var entries: [1]common.ComponentDescriptor = undefined;
    var registry = ComponentRegistry.init(&entries);
    var html: [512]u8 = undefined;
    var markdown: [512]u8 = undefined;
    var commands: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try Details.register(&registry);
    try std.testing.expectError(error.DuplicateComponent, Details.register(&registry));
    try std.testing.expectEqualStrings("details", registry.matchHtml("<details data-er-component=\"details\" data-er-id=\"1\"></details>").?.name);
    try std.testing.expectEqualStrings("details", registry.matchMarkdown(":::details\nid: 1\n:::").?.name);

    const encoded_html = try registry.writeHtml("details", &details, &html);
    const encoded_markdown = try registry.writeMarkdown("details", &details, &markdown);
    try registry.render("details", &details, &scene, ui.Rect.init(0, 0, 320, 120), .{});

    try std.testing.expect(std.mem.indexOf(u8, encoded_html, "<details data-er-component=\"details\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded_markdown, ":::details") != null);
    try std.testing.expect(hasTextContaining(scene.written(), "registered app surface"));
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
