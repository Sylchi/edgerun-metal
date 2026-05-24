const std = @import("std");
const common = @import("../../ui_component_common.zig");
const base_progress_bar = @import("base/ProgressBar.zig");
const base_surface = @import("base/Surface.zig");
const interaction = @import("../../ui_interaction.zig");
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

pub const ProgressSummary = struct {
    id: u32,
    label: []const u8,
    completed: u32,
    total: u32,

    pub fn render(self: ProgressSummary, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return renderProgressSummary(self, scene, bounds, options);
    }

    pub fn collectInteractions(self: ProgressSummary, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return collectProgressSummaryInteractions(self, collector, bounds);
    }

    pub fn toHtml(self: ProgressSummary, out: []u8) HtmlError![]u8 {
        return writeHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, text_out: []u8) HtmlError!ProgressSummary {
        return readHtml(html, text_out);
    }

    pub fn toMarkdown(self: ProgressSummary, out: []u8) MarkdownError![]u8 {
        return writeMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!ProgressSummary {
        return readMarkdown(markdown, text_out);
    }

    pub fn register(registry: *ComponentRegistry) RegistryError!void {
        try registry.register(descriptor);
    }
};

pub const descriptor = common.ComponentDescriptor{
    .name = "progress-summary",
    .html_prefix = "<section data-er-component=\"progress-summary\"",
    .markdown_prefix = ":::progress",
    .render = renderRegistered,
    .collect_interactions = collectRegistered,
    .write_html = writeHtmlRegistered,
    .write_markdown = writeMarkdownRegistered,
};

pub fn register(registry: *ComponentRegistry) RegistryError!void {
    return ProgressSummary.register(registry);
}

pub fn renderProgressSummary(summary: ProgressSummary, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    if (summary.total == 0 or summary.completed > summary.total) return;
    const style = options.style;
    try base_surface.renderFrame(scene, bounds, options);

    const content = bounds.insetLtrb(progress_summary_padding_x, progress_summary_padding_y, progress_summary_padding_x, progress_summary_padding_y);
    try scene.pushAlignedText(ui.Rect.init(content.x, content.y, content.w, progress_summary_label_h), summary.label, style.text, .start);

    const bar_bounds = ui.Rect.init(content.x, content.y + progress_summary_bar_y, content.w, progress_summary_bar_h);
    const ratio = @as(f32, @floatFromInt(summary.completed)) / @as(f32, @floatFromInt(summary.total));
    try base_progress_bar.render(scene, bar_bounds, .{ .value = ratio }, options);
}

pub fn collectProgressSummaryInteractions(summary: ProgressSummary, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
    if (summary.total == 0 or summary.completed > summary.total) return;
    try collector.add(.{ .kind = .button, .id = summary.id, .bounds = bounds });
}

fn renderRegistered(component: *const anyopaque, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    const summary: *const ProgressSummary = @ptrCast(@alignCast(component));
    return renderProgressSummary(summary.*, scene, bounds, options);
}

fn collectRegistered(component: *const anyopaque, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
    const summary: *const ProgressSummary = @ptrCast(@alignCast(component));
    return collectProgressSummaryInteractions(summary.*, collector, bounds);
}

pub fn writeHtml(summary: ProgressSummary, out: []u8) HtmlError![]u8 {
    if (summary.label.len == 0 or summary.total == 0 or summary.completed > summary.total) return error.InvalidHtml;
    var writer = HtmlWriter.init(out);
    try writer.writeAll("<section data-er-component=\"progress-summary\"");
    try writer.writeAttrInt("data-er-id", summary.id);
    try writer.writeAll("><h2>");
    try writer.writeEscapedText(summary.label);
    try writer.writeAll("</h2><progress");
    try writer.writeAttrInt("value", summary.completed);
    try writer.writeAttrInt("max", summary.total);
    try writer.writeAll("></progress></section>");
    return writer.written();
}

fn writeHtmlRegistered(component: *const anyopaque, out: []u8) HtmlError![]u8 {
    const summary: *const ProgressSummary = @ptrCast(@alignCast(component));
    return writeHtml(summary.*, out);
}

pub fn writeMarkdown(summary: ProgressSummary, out: []u8) MarkdownError![]u8 {
    if (summary.label.len == 0 or summary.total == 0 or summary.completed > summary.total) return error.InvalidMarkdown;
    var writer = MarkdownWriter.init(out);
    try writer.beginDirective("progress");
    try writer.fieldInt("id", summary.id);
    try writer.fieldText("label", summary.label);
    try writer.fieldInt("completed", summary.completed);
    try writer.fieldInt("total", summary.total);
    try writer.endDirective();
    return writer.written();
}

fn writeMarkdownRegistered(component: *const anyopaque, out: []u8) MarkdownError![]u8 {
    const summary: *const ProgressSummary = @ptrCast(@alignCast(component));
    return writeMarkdown(summary.*, out);
}

pub fn readMarkdown(markdown: []const u8, text_out: []u8) MarkdownError!ProgressSummary {
    const prefix = ":::progress\nid: ";
    const body = try common.readMarkdownDirectiveBody(markdown, ":::progress", prefix);
    var cursor = MarkdownCursor.init(body);
    const id = try common.parseMarkdownU32(try cursor.fieldBetween("", "\nlabel: "));
    var text = MarkdownTextArena.init(text_out);
    const label = try text.unescapeInline(try cursor.fieldBetween("\nlabel: ", "\ncompleted: "));
    const completed = try common.parseMarkdownU32(try cursor.fieldBetween("\ncompleted: ", "\ntotal: "));
    const total = try common.parseMarkdownU32(try cursor.tailField("\ntotal: "));
    if (label.len == 0 or total == 0 or completed > total) return error.InvalidMarkdown;
    return .{ .id = id, .label = label, .completed = completed, .total = total };
}

pub fn readHtml(html: []const u8, text_out: []u8) HtmlError!ProgressSummary {
    const prefix = "<section data-er-component=\"progress-summary\" data-er-id=\"";
    if (!std.mem.startsWith(u8, html, prefix)) {
        if (std.mem.startsWith(u8, html, "<section")) return error.InvalidHtml;
        return error.UnsupportedHtml;
    }
    if (!std.mem.endsWith(u8, html, "</progress></section>")) return error.InvalidHtml;

    var text = HtmlTextArena.init(text_out);
    const after_id_start = prefix.len;
    const after_id = html[after_id_start..];
    const id_end = std.mem.indexOf(u8, after_id, "\"><h2>") orelse return error.InvalidHtml;
    const id = try common.parseHtmlU32(after_id[0..id_end]);
    const label_start = after_id_start + id_end + "\"><h2>".len;
    const label_end_relative = std.mem.indexOf(u8, html[label_start..], "</h2><progress value=\"") orelse return error.InvalidHtml;
    const completed_start = label_start + label_end_relative + "</h2><progress value=\"".len;
    const completed_end_relative = std.mem.indexOf(u8, html[completed_start..], "\" max=\"") orelse return error.InvalidHtml;
    const total_start = completed_start + completed_end_relative + "\" max=\"".len;
    const total_end_relative = std.mem.indexOf(u8, html[total_start..], "\"></progress></section>") orelse return error.InvalidHtml;
    const completed = try common.parseHtmlU32(html[completed_start .. completed_start + completed_end_relative]);
    const total = try common.parseHtmlU32(html[total_start .. total_start + total_end_relative]);
    const label = try text.unescape(html[label_start .. label_start + label_end_relative]);
    if (label.len == 0 or total == 0 or completed > total) return error.InvalidHtml;
    return .{ .id = id, .label = label, .completed = completed, .total = total };
}

const progress_summary_padding_x: f32 = 14.0;
const progress_summary_padding_y: f32 = 14.0;
const progress_summary_label_h: f32 = 16.0;
const progress_summary_bar_y: f32 = 30.0;
const progress_summary_bar_h: f32 = 10.0;

test "progress summary component renders progress and collects hit target" {
    const summary = ProgressSummary{ .id = 39001, .label = "Academy progress", .completed = 3, .total = 8 };
    var commands: [48]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try summary.render(&scene, ui.Rect.init(0, 0, 360, 96), .{});
    try summary.collectInteractions(&collector, ui.Rect.init(0, 0, 360, 96));

    try std.testing.expect(hasText(scene.written(), "Academy progress"));
    try std.testing.expect(ui_input.hitTest(scene.written(), 20, 20) == null);
    const hit = ui_input.regionHitTest(collector.written(), 20, 20).?;
    try std.testing.expectEqual(@as(u32, 39001), hit.id);
}

test "progress summary html codec roundtrips semantic progress" {
    const summary = ProgressSummary{ .id = 39101, .label = "Systems & Security", .completed = 5, .total = 12 };
    var html: [256]u8 = undefined;
    var text: [128]u8 = undefined;

    const encoded = try summary.toHtml(&html);
    const decoded = try ProgressSummary.fromHtml(encoded, &text);

    try std.testing.expectEqualStrings("<section data-er-component=\"progress-summary\" data-er-id=\"39101\"><h2>Systems &amp; Security</h2><progress value=\"5\" max=\"12\"></progress></section>", encoded);
    try std.testing.expectEqual(@as(u32, 39101), decoded.id);
    try std.testing.expectEqualStrings("Systems & Security", decoded.label);
    try std.testing.expectEqual(@as(u32, 5), decoded.completed);
    try std.testing.expectEqual(@as(u32, 12), decoded.total);
}

test "progress summary html codec rejects malformed progress" {
    var text: [128]u8 = undefined;

    try std.testing.expectError(error.InvalidHtml, ProgressSummary.fromHtml("<section><progress value=\"1\" max=\"2\"></progress></section>", &text));
    try std.testing.expectError(error.InvalidHtml, ProgressSummary.fromHtml("<section data-er-component=\"progress-summary\" data-er-id=\"1\"><h2></h2><progress value=\"1\" max=\"2\"></progress></section>", &text));
    try std.testing.expectError(error.InvalidHtml, ProgressSummary.fromHtml("<section data-er-component=\"progress-summary\" data-er-id=\"x\"><h2>Broken</h2><progress value=\"1\" max=\"2\"></progress></section>", &text));
    try std.testing.expectError(error.InvalidHtml, ProgressSummary.fromHtml("<section data-er-component=\"progress-summary\" data-er-id=\"1\"><h2>Broken</h2><progress value=\"3\" max=\"2\"></progress></section>", &text));
    try std.testing.expectError(error.InvalidHtml, ProgressSummary.fromHtml("<section data-er-component=\"progress-summary\" data-er-id=\"1\"><h2>Broken</h2><progress value=\"0\" max=\"0\"></progress></section>", &text));
}

test "progress summary registers explicit runtime descriptor" {
    const summary = ProgressSummary{ .id = 39201, .label = "Runtime progress", .completed = 2, .total = 5 };
    var entries: [1]common.ComponentDescriptor = undefined;
    var registry = ComponentRegistry.init(&entries);
    var html: [256]u8 = undefined;
    var markdown: [256]u8 = undefined;
    var commands: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [2]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try ProgressSummary.register(&registry);
    try std.testing.expectError(error.DuplicateComponent, ProgressSummary.register(&registry));
    try std.testing.expectEqualStrings("progress-summary", registry.matchHtml("<section data-er-component=\"progress-summary\"></section>").?.name);
    try std.testing.expectEqualStrings("progress-summary", registry.matchMarkdown(":::progress\nid: 1\n:::").?.name);

    const encoded_html = try registry.writeHtml("progress-summary", &summary, &html);
    const encoded_markdown = try registry.writeMarkdown("progress-summary", &summary, &markdown);
    try registry.render("progress-summary", &summary, &scene, ui.Rect.init(0, 0, 320, 96), .{});
    try registry.collectInteractions("progress-summary", &summary, &collector, ui.Rect.init(0, 0, 320, 96));

    try std.testing.expect(std.mem.indexOf(u8, encoded_html, "<section data-er-component=\"progress-summary\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded_markdown, ":::progress") != null);
    try std.testing.expect(hasText(scene.written(), "Runtime progress"));
    try std.testing.expectEqual(@as(u32, 39201), ui_input.regionHitTest(collector.written(), 20, 20).?.id);
}

fn hasText(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| {
        if (command == .text and std.mem.eql(u8, command.text.value, value)) return true;
    }
    return false;
}
