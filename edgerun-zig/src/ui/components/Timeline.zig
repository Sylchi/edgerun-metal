const std = @import("std");
const common = @import("../../ui_component_common.zig");
const layout = @import("../../layouts/Types.zig");
const base_surface = @import("base/Surface.zig");
const ui = @import("../../ui.zig");
const ui_input = @import("../../input.zig");

const ComponentRegistry = common.ComponentRegistry;
const HtmlCursor = common.HtmlCursor;
const HtmlError = common.HtmlError;
const HtmlTextArena = common.HtmlTextArena;
const HtmlWriter = common.HtmlWriter;
const MarkdownCursor = common.MarkdownCursor;
const MarkdownError = common.MarkdownError;
const MarkdownTextArena = common.MarkdownTextArena;
const MarkdownWriter = common.MarkdownWriter;
const RegistryError = common.RegistryError;
const RenderOptions = common.RenderOptions;

pub const TimelineEvent = struct {
    id: u32,
    time: []const u8,
    title: []const u8,
    detail: []const u8,
};

pub const Timeline = struct {
    events: []const TimelineEvent,

    pub fn render(self: Timeline, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return renderTimeline(self, scene, bounds, options);
    }

    pub fn measure(self: Timeline, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return measureTimeline(self, constraints);
    }

    pub fn toHtml(self: Timeline, out: []u8) HtmlError![]u8 {
        return writeHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, out_events: []TimelineEvent, text_out: []u8) HtmlError!Timeline {
        return readHtml(html, out_events, text_out);
    }

    pub fn toMarkdown(self: Timeline, out: []u8) MarkdownError![]u8 {
        return writeMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, out_events: []TimelineEvent, text_out: []u8) MarkdownError!Timeline {
        return readMarkdown(markdown, out_events, text_out);
    }

    pub fn register(registry: *ComponentRegistry) RegistryError!void {
        try registry.register(descriptor);
    }
};

pub const descriptor = common.ComponentDescriptor{
    .name = "timeline",
    .html_prefix = "<ol data-er-component=\"timeline\"",
    .markdown_prefix = ":::timeline",
    .render = renderRegistered,
    .write_html = writeHtmlRegistered,
    .write_markdown = writeMarkdownRegistered,
};

pub fn register(registry: *ComponentRegistry) RegistryError!void {
    return Timeline.register(registry);
}

pub fn renderTimeline(timeline: Timeline, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    if (timeline.events.len == 0) return;
    const style = options.style;
    try base_surface.renderFrame(scene, bounds, options);

    var y = bounds.y + timeline_padding_y;
    const content_x = bounds.x + timeline_padding_x;
    const content_w = @max(1.0, bounds.w - timeline_padding_x * 2.0);
    const bottom = bounds.y + bounds.h - timeline_padding_y;
    for (timeline.events) |event| {
        if (y + timeline_event_h > bottom) break;
        const event_bounds = ui.Rect.init(content_x, y, content_w, timeline_event_h);
        const marker_bounds = ui.Rect.init(event_bounds.x + timeline_marker_x, event_bounds.y + timeline_marker_y, timeline_marker_size, timeline_marker_size);
        try scene.pushRect(marker_bounds, style.accent, .fill, timeline_marker_size * 0.5, 0.0);
        try scene.pushAlignedText(ui.Rect.init(event_bounds.x + timeline_text_x, event_bounds.y + timeline_time_y, timeline_time_w, timeline_time_h), event.time, style.accent, .start);
        try scene.pushAlignedText(ui.Rect.init(event_bounds.x + timeline_text_x + timeline_time_w + timeline_text_gap, event_bounds.y + timeline_title_y, @max(1.0, event_bounds.w - timeline_text_x - timeline_time_w - timeline_text_gap - timeline_text_padding_x), timeline_title_h), event.title, style.text, .start);
        try scene.pushWrappedText(ui.Rect.init(event_bounds.x + timeline_text_x, event_bounds.y + timeline_detail_y, @max(1.0, event_bounds.w - timeline_text_x - timeline_text_padding_x), timeline_detail_h), event.detail, style.muted, .{
            .line_height = timeline_detail_line_h,
            .average_char_width = timeline_detail_avg_w,
            .max_lines = timeline_detail_max_lines,
        });
        try scene.pushHit(.{ .slot = 0, .kind = .row_item, .id = event.id, .bounds = event_bounds });
        y += timeline_event_h + timeline_event_gap;
    }
}

pub fn measureTimeline(timeline: Timeline, constraints: layout.Constraints) layout.Measurement {
    const content = constraints.inner(timelineInsets());
    var preferred_width: f32 = 0;
    var preferred_height: f32 = 0;
    for (timeline.events, 0..) |event, index| {
        if (index != 0) preferred_height += timeline_event_gap;
        const row = measureTimelineEvent(event, content);
        preferred_width = @max(preferred_width, row.preferred.w);
        preferred_height += row.preferred.h;
    }
    return layout.Measurement.flexible(
        .{ .w = timeline_min_w, .h = timeline_padding_y * 2.0 },
        .{ .w = preferred_width, .h = preferred_height },
        .{ .w = constraints.width.limit(preferred_width), .h = preferred_height },
    ).withInsets(timelineInsets()).applyExact(constraints);
}

fn renderRegistered(component: *const anyopaque, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    const timeline: *const Timeline = @ptrCast(@alignCast(component));
    return renderTimeline(timeline.*, scene, bounds, options);
}

pub fn writeHtml(timeline: Timeline, out: []u8) HtmlError![]u8 {
    if (timeline.events.len == 0) return error.InvalidHtml;
    var writer = HtmlWriter.init(out);
    try writer.writeAll("<ol data-er-component=\"timeline\">");
    for (timeline.events) |event| {
        if (event.time.len == 0 or event.title.len == 0 or event.detail.len == 0) return error.InvalidHtml;
        try writer.writeAll("<li");
        try writer.writeAttrInt("data-er-id", event.id);
        try writer.writeAll("><time>");
        try writer.writeEscapedText(event.time);
        try writer.writeAll("</time><strong>");
        try writer.writeEscapedText(event.title);
        try writer.writeAll("</strong><p>");
        try writer.writeEscapedText(event.detail);
        try writer.writeAll("</p></li>");
    }
    try writer.writeAll("</ol>");
    return writer.written();
}

fn writeHtmlRegistered(component: *const anyopaque, out: []u8) HtmlError![]u8 {
    const timeline: *const Timeline = @ptrCast(@alignCast(component));
    return writeHtml(timeline.*, out);
}

pub fn writeMarkdown(timeline: Timeline, out: []u8) MarkdownError![]u8 {
    if (timeline.events.len == 0) return error.InvalidMarkdown;
    var writer = MarkdownWriter.init(out);
    try writer.beginDirective("timeline");
    for (timeline.events) |event| {
        if (event.time.len == 0 or event.title.len == 0 or event.detail.len == 0) return error.InvalidMarkdown;
        try writer.fieldInt("event", event.id);
        try writer.fieldText("time", event.time);
        try writer.fieldText("title", event.title);
        try writer.fieldText("detail", event.detail);
    }
    try writer.endDirective();
    return writer.written();
}

fn writeMarkdownRegistered(component: *const anyopaque, out: []u8) MarkdownError![]u8 {
    const timeline: *const Timeline = @ptrCast(@alignCast(component));
    return writeMarkdown(timeline.*, out);
}

pub fn readMarkdown(markdown: []const u8, out_events: []TimelineEvent, text_out: []u8) MarkdownError!Timeline {
    const prefix = ":::timeline\n";
    const body = try common.readMarkdownDirectiveBody(markdown, ":::timeline", prefix);
    var text = MarkdownTextArena.init(text_out);
    var event_count: usize = 0;
    var cursor = MarkdownCursor.init(body);
    while (!cursor.done()) {
        if (event_count == out_events.len) return error.MarkdownBudgetExceeded;
        const id = try common.parseMarkdownU32(try cursor.lineAfter("event: "));
        const time = try text.unescapeInline(try cursor.fieldBetween("\ntime: ", "\ntitle: "));
        const title = try text.unescapeInline(try cursor.fieldBetween("\ntitle: ", "\ndetail: "));
        const detail = try text.unescapeInline(try cursor.finalField("\ndetail: ", "\nevent: "));
        if (time.len == 0 or title.len == 0 or detail.len == 0) return error.InvalidMarkdown;
        out_events[event_count] = .{ .id = id, .time = time, .title = title, .detail = detail };
        event_count += 1;
        try cursor.skipNewline();
    }
    if (event_count == 0) return error.InvalidMarkdown;
    return .{ .events = out_events[0..event_count] };
}

pub fn readHtml(html: []const u8, out_events: []TimelineEvent, text_out: []u8) HtmlError!Timeline {
    const body = common.takeWrapped(html, "<ol data-er-component=\"timeline\">", "</ol>") orelse {
        if (std.mem.startsWith(u8, html, "<ol")) return error.InvalidHtml;
        return error.UnsupportedHtml;
    };
    var text = HtmlTextArena.init(text_out);
    const events = try readEventsHtml(body, out_events, &text);
    return .{ .events = events };
}

fn readEventsHtml(html: []const u8, out_events: []TimelineEvent, text: *HtmlTextArena) HtmlError![]const TimelineEvent {
    var cursor = HtmlCursor.init(html);
    var event_count: usize = 0;
    while (!cursor.done()) {
        if (event_count == out_events.len) return error.HtmlBudgetExceeded;
        const id = try common.parseHtmlU32(try cursor.fieldBetween("<li data-er-id=\"", "\"><time>"));
        const time = try text.unescape(try cursor.fieldBetween("\"><time>", "</time><strong>"));
        const title = try text.unescape(try cursor.fieldBetween("</time><strong>", "</strong><p>"));
        const detail = try text.unescape(try cursor.fieldBetween("</strong><p>", "</p></li>"));
        try cursor.consume("</p></li>");
        if (time.len == 0 or title.len == 0 or detail.len == 0) return error.InvalidHtml;
        out_events[event_count] = .{ .id = id, .time = time, .title = title, .detail = detail };
        event_count += 1;
    }
    if (event_count == 0) return error.InvalidHtml;
    return out_events[0..event_count];
}

const timeline_padding_x: f32 = 12.0;
const timeline_padding_y: f32 = 12.0;
const timeline_event_h: f32 = 82.0;
const timeline_event_gap: f32 = 8.0;
const timeline_marker_x: f32 = 10.0;
const timeline_marker_y: f32 = 14.0;
const timeline_marker_size: f32 = 12.0;
const timeline_text_x: f32 = 34.0;
const timeline_time_y: f32 = 9.0;
const timeline_time_w: f32 = 74.0;
const timeline_time_h: f32 = 14.0;
const timeline_time_avg_w: f32 = 7.5;
const timeline_text_gap: f32 = 10.0;
const timeline_title_y: f32 = 9.0;
const timeline_title_h: f32 = 16.0;
const timeline_title_avg_w: f32 = 8.5;
const timeline_detail_y: f32 = 34.0;
const timeline_detail_h: f32 = 38.0;
const timeline_detail_line_h: f32 = 17.0;
const timeline_detail_avg_w: f32 = 8.5;
const timeline_detail_max_lines: usize = 2;
const timeline_text_padding_x: f32 = 10.0;
const timeline_text_max_lines: usize = 1;
const timeline_min_w: f32 = 180.0;

fn measureTimelineEvent(event: TimelineEvent, constraints: layout.Constraints) layout.Measurement {
    const text_constraints = constraints.inner(.{ .left = timeline_text_x, .right = timeline_text_padding_x });
    const time = layout.measureText(event.time, .{ .width = .{ .exact = timeline_time_w }, .text_wrap = .nowrap }, .{
        .line_height = timeline_time_h,
        .average_char_width = timeline_time_avg_w,
        .max_lines = timeline_text_max_lines,
    });
    const title = layout.measureText(event.title, text_constraints.inner(.{ .left = timeline_time_w + timeline_text_gap }), .{
        .line_height = timeline_title_h,
        .average_char_width = timeline_title_avg_w,
        .max_lines = timeline_text_max_lines,
    });
    const detail = layout.measureText(event.detail, text_constraints, .{
        .line_height = timeline_detail_line_h,
        .average_char_width = timeline_detail_avg_w,
        .max_lines = timeline_detail_max_lines,
    });
    const header_width = timeline_text_x + time.preferred.w + timeline_text_gap + title.preferred.w + timeline_text_padding_x;
    const detail_width = timeline_text_x + detail.preferred.w + timeline_text_padding_x;
    const content_height = timeline_title_y + @max(time.preferred.h, title.preferred.h) + (timeline_detail_y - timeline_title_y - timeline_title_h) + detail.preferred.h;
    return layout.Measurement.flexible(
        .{ .w = timeline_min_w, .h = timeline_event_h },
        .{ .w = @max(header_width, detail_width), .h = @max(timeline_event_h, content_height) },
        .{ .w = constraints.width.limit(@max(header_width, detail_width)), .h = @max(timeline_event_h, content_height) },
    ).applyExact(constraints);
}

fn timelineInsets() layout.Insets {
    return .{ .top = timeline_padding_y, .right = timeline_padding_x, .bottom = timeline_padding_y, .left = timeline_padding_x };
}

test "timeline component renders events and hit targets" {
    const events = [_]TimelineEvent{
        .{ .id = 37001, .time = "1", .title = "Browser asks", .detail = "The app asks for a name to become an address." },
        .{ .id = 37002, .time = "2", .title = "Resolver answers", .detail = "A cached or authoritative answer comes back." },
    };
    const timeline = Timeline{ .events = &events };
    var commands: [96]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try timeline.render(&scene, ui.Rect.init(0, 0, 380, 210), .{});

    try std.testing.expect(hasText(scene.written(), "Browser asks"));
    try std.testing.expect(hasText(scene.written(), "Resolver answers"));
    const hit = ui_input.hitTest(scene.written(), 24, 104).?;
    try std.testing.expectEqual(@as(u32, 37002), hit.id);
}

test "timeline measurement counts event rows" {
    const one = [_]TimelineEvent{
        .{ .id = 37001, .time = "1", .title = "Browser asks", .detail = "The app asks for a name to become an address." },
    };
    const many = [_]TimelineEvent{
        one[0],
        .{ .id = 37002, .time = "2", .title = "Resolver answers", .detail = "A cached or authoritative answer comes back." },
    };

    const single = (Timeline{ .events = &one }).measure(.{ .width = .{ .exact = 320 }, .text_wrap = .wrap }, .{});
    const full = (Timeline{ .events = &many }).measure(.{ .width = .{ .exact = 320 }, .text_wrap = .wrap }, .{});

    try std.testing.expectEqual(@as(f32, 320), full.preferred.w);
    try std.testing.expect(full.preferred.h > single.preferred.h);
}

test "timeline html codec roundtrips semantic events" {
    const events = [_]TimelineEvent{
        .{ .id = 37101, .time = "t0", .title = "Key exists", .detail = "The device already has a root of authority." },
        .{ .id = 37102, .time = "t1", .title = "Receipt written", .detail = "The work result is bound to an object & signer." },
    };
    const timeline = Timeline{ .events = &events };
    var html: [768]u8 = undefined;
    var decoded_events: [2]TimelineEvent = undefined;
    var text: [256]u8 = undefined;

    const encoded = try timeline.toHtml(&html);
    const decoded = try Timeline.fromHtml(encoded, &decoded_events, &text);

    try std.testing.expectEqualStrings("<ol data-er-component=\"timeline\"><li data-er-id=\"37101\"><time>t0</time><strong>Key exists</strong><p>The device already has a root of authority.</p></li><li data-er-id=\"37102\"><time>t1</time><strong>Receipt written</strong><p>The work result is bound to an object &amp; signer.</p></li></ol>", encoded);
    try std.testing.expectEqual(@as(usize, 2), decoded.events.len);
    try std.testing.expectEqual(@as(u32, 37102), decoded.events[1].id);
    try std.testing.expectEqualStrings("t1", decoded.events[1].time);
    try std.testing.expectEqualStrings("Receipt written", decoded.events[1].title);
    try std.testing.expectEqualStrings("The work result is bound to an object & signer.", decoded.events[1].detail);
}

test "timeline html codec rejects malformed events" {
    var events: [2]TimelineEvent = undefined;
    var text: [128]u8 = undefined;

    try std.testing.expectError(error.InvalidHtml, Timeline.fromHtml("<ol><li>Plain</li></ol>", &events, &text));
    try std.testing.expectError(error.InvalidHtml, Timeline.fromHtml("<ol data-er-component=\"timeline\"></ol>", &events, &text));
    try std.testing.expectError(error.InvalidHtml, Timeline.fromHtml("<ol data-er-component=\"timeline\"><li data-er-id=\"x\"><time>1</time><strong>Broken</strong><p>Bad id</p></li></ol>", &events, &text));
    try std.testing.expectError(error.InvalidHtml, Timeline.fromHtml("<ol data-er-component=\"timeline\"><li data-er-id=\"1\"><time></time><strong>Broken</strong><p>Missing time</p></li></ol>", &events, &text));
}

test "timeline registers explicit runtime descriptor" {
    const events = [_]TimelineEvent{
        .{ .id = 37201, .time = "t0", .title = "Key exists", .detail = "The device already has a root of authority." },
        .{ .id = 37202, .time = "t1", .title = "Receipt written", .detail = "The work result is bound to an object and signer." },
    };
    const timeline = Timeline{ .events = &events };
    var entries: [1]common.ComponentDescriptor = undefined;
    var registry = ComponentRegistry.init(&entries);
    var html: [768]u8 = undefined;
    var markdown: [768]u8 = undefined;
    var commands: [96]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try Timeline.register(&registry);
    try std.testing.expectError(error.DuplicateComponent, Timeline.register(&registry));
    try std.testing.expectEqualStrings("timeline", registry.matchHtml("<ol data-er-component=\"timeline\"></ol>").?.name);
    try std.testing.expectEqualStrings("timeline", registry.matchMarkdown(":::timeline\nevent: 1\n:::").?.name);

    const encoded_html = try registry.writeHtml("timeline", &timeline, &html);
    const encoded_markdown = try registry.writeMarkdown("timeline", &timeline, &markdown);
    try registry.render("timeline", &timeline, &scene, ui.Rect.init(0, 0, 380, 210), .{});

    try std.testing.expect(std.mem.indexOf(u8, encoded_html, "<ol data-er-component=\"timeline\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded_markdown, ":::timeline") != null);
    try std.testing.expect(hasText(scene.written(), "Receipt written"));
}

fn hasText(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| {
        if (command == .text and std.mem.eql(u8, command.text.value, value)) return true;
    }
    return false;
}
