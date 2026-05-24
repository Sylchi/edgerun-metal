const std = @import("std");
const common = @import("../../ui_component_common.zig");
const layout = @import("../../layouts/Types.zig");
const base_info_row = @import("base/InfoRow.zig");
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

pub const StepState = enum {
    done,
    current,
    todo,
};

pub const StepItem = struct {
    id: u32,
    title: []const u8,
    detail: []const u8,
    state: StepState = .todo,
};

pub const StepList = struct {
    steps: []const StepItem,

    pub fn render(self: StepList, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return renderStepList(self, scene, bounds, options);
    }

    pub fn measure(self: StepList, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return measureStepList(self, constraints);
    }

    pub fn toHtml(self: StepList, out: []u8) HtmlError![]u8 {
        return writeHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, out_steps: []StepItem, text_out: []u8) HtmlError!StepList {
        return readHtml(html, out_steps, text_out);
    }

    pub fn toMarkdown(self: StepList, out: []u8) MarkdownError![]u8 {
        return writeMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, out_steps: []StepItem, text_out: []u8) MarkdownError!StepList {
        return readMarkdown(markdown, out_steps, text_out);
    }

    pub fn register(registry: *ComponentRegistry) RegistryError!void {
        try registry.register(descriptor);
    }
};

pub const descriptor = common.ComponentDescriptor{
    .name = "step-list",
    .html_prefix = "<ol data-er-component=\"step-list\"",
    .markdown_prefix = ":::steps",
    .render = renderRegistered,
    .write_html = writeHtmlRegistered,
    .write_markdown = writeMarkdownRegistered,
};

pub fn register(registry: *ComponentRegistry) RegistryError!void {
    return StepList.register(registry);
}

pub fn renderStepList(list: StepList, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    if (list.steps.len == 0) return;
    const style = options.style;
    try base_surface.renderFrame(scene, bounds, options);

    var y = bounds.y + step_padding_y;
    const content_x = bounds.x + step_padding_x;
    const content_w = @max(1.0, bounds.w - step_padding_x * 2.0);
    const bottom = bounds.y + bounds.h - step_padding_y;
    for (list.steps) |step| {
        var row_metrics = step_row_metrics;
        row_metrics.fill = step.state == .current;
        if (y + row_metrics.height > bottom) break;
        const step_bounds = ui.Rect.init(content_x, y, content_w, row_metrics.height);
        try base_info_row.render(scene, step_bounds, .{ .id = step.id, .title = step.title, .detail = step.detail }, row_metrics, options);
        const marker_bounds = ui.Rect.init(step_bounds.x + step_marker_x, step_bounds.y + step_marker_y, step_marker_size, step_marker_size);
        try scene.pushRect(marker_bounds, stepStateColor(step.state, style), .fill, step_marker_size * 0.5, 0.0);
        y += row_metrics.height + step_item_gap;
    }
}

pub fn measureStepList(list: StepList, constraints: layout.Constraints) layout.Measurement {
    const content = constraints.inner(stepInsets());
    var preferred_width: f32 = 0;
    var preferred_height: f32 = 0;
    for (list.steps, 0..) |step, index| {
        if (index != 0) preferred_height += step_item_gap;
        const row = measureStepItem(step, content);
        preferred_width = @max(preferred_width, row.preferred.w);
        preferred_height += row.preferred.h;
    }
    return layout.Measurement.flexible(
        .{ .w = step_row_metrics.min_width, .h = step_padding_y * 2.0 },
        .{ .w = preferred_width, .h = preferred_height },
        .{ .w = constraints.width.limit(preferred_width), .h = preferred_height },
    ).withInsets(stepInsets()).applyExact(constraints);
}

fn renderRegistered(component: *const anyopaque, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    const list: *const StepList = @ptrCast(@alignCast(component));
    return renderStepList(list.*, scene, bounds, options);
}

pub fn writeHtml(list: StepList, out: []u8) HtmlError![]u8 {
    if (list.steps.len == 0) return error.InvalidHtml;
    var writer = HtmlWriter.init(out);
    try writer.writeAll("<ol data-er-component=\"step-list\">");
    for (list.steps) |step| {
        if (step.title.len == 0 or step.detail.len == 0) return error.InvalidHtml;
        try writer.writeAll("<li");
        try writer.writeAttrInt("data-er-id", step.id);
        try writer.writeAttrRaw("data-er-state", stepStateName(step.state));
        try writer.writeAll("><strong>");
        try writer.writeEscapedText(step.title);
        try writer.writeAll("</strong><span>");
        try writer.writeEscapedText(step.detail);
        try writer.writeAll("</span></li>");
    }
    try writer.writeAll("</ol>");
    return writer.written();
}

fn writeHtmlRegistered(component: *const anyopaque, out: []u8) HtmlError![]u8 {
    const list: *const StepList = @ptrCast(@alignCast(component));
    return writeHtml(list.*, out);
}

pub fn writeMarkdown(list: StepList, out: []u8) MarkdownError![]u8 {
    if (list.steps.len == 0) return error.InvalidMarkdown;
    var writer = MarkdownWriter.init(out);
    try writer.beginDirective("steps");
    for (list.steps) |step| {
        if (step.title.len == 0 or step.detail.len == 0) return error.InvalidMarkdown;
        try writer.fieldInt("step", step.id);
        try writer.fieldRaw("state", stepStateName(step.state));
        try writer.fieldText("title", step.title);
        try writer.fieldText("detail", step.detail);
    }
    try writer.endDirective();
    return writer.written();
}

fn writeMarkdownRegistered(component: *const anyopaque, out: []u8) MarkdownError![]u8 {
    const list: *const StepList = @ptrCast(@alignCast(component));
    return writeMarkdown(list.*, out);
}

pub fn readMarkdown(markdown: []const u8, out_steps: []StepItem, text_out: []u8) MarkdownError!StepList {
    const prefix = ":::steps\n";
    const body = try common.readMarkdownDirectiveBody(markdown, ":::steps", prefix);
    var text = MarkdownTextArena.init(text_out);
    var step_count: usize = 0;
    var cursor = MarkdownCursor.init(body);
    while (!cursor.done()) {
        if (step_count == out_steps.len) return error.MarkdownBudgetExceeded;
        const id = try common.parseMarkdownU32(try cursor.lineAfter("step: "));
        const state = parseStepStateName(try cursor.fieldBetween("\nstate: ", "\ntitle: ")) orelse return error.InvalidMarkdown;
        const title = try text.unescapeInline(try cursor.fieldBetween("\ntitle: ", "\ndetail: "));
        const detail = try text.unescapeInline(try cursor.finalField("\ndetail: ", "\nstep: "));
        if (title.len == 0 or detail.len == 0) return error.InvalidMarkdown;
        out_steps[step_count] = .{ .id = id, .title = title, .detail = detail, .state = state };
        step_count += 1;
        try cursor.skipNewline();
    }
    if (step_count == 0) return error.InvalidMarkdown;
    return .{ .steps = out_steps[0..step_count] };
}

pub fn readHtml(html: []const u8, out_steps: []StepItem, text_out: []u8) HtmlError!StepList {
    const body = common.takeWrapped(html, "<ol data-er-component=\"step-list\">", "</ol>") orelse {
        if (std.mem.startsWith(u8, html, "<ol")) return error.InvalidHtml;
        return error.UnsupportedHtml;
    };
    var text = HtmlTextArena.init(text_out);
    const steps = try readItemsHtml(body, out_steps, &text);
    return .{ .steps = steps };
}

fn readItemsHtml(html: []const u8, out_steps: []StepItem, text: *HtmlTextArena) HtmlError![]const StepItem {
    var cursor = HtmlCursor.init(html);
    var step_count: usize = 0;
    while (!cursor.done()) {
        if (step_count == out_steps.len) return error.HtmlBudgetExceeded;
        const id = try common.parseHtmlU32(try cursor.fieldBetween("<li data-er-id=\"", "\" data-er-state=\""));
        const state = parseStepStateName(try cursor.fieldBetween("\" data-er-state=\"", "\"><strong>")) orelse return error.InvalidHtml;
        const title = try text.unescape(try cursor.fieldBetween("\"><strong>", "</strong><span>"));
        const detail = try text.unescape(try cursor.fieldBetween("</strong><span>", "</span></li>"));
        try cursor.consume("</span></li>");
        if (title.len == 0 or detail.len == 0) return error.InvalidHtml;
        out_steps[step_count] = .{ .id = id, .title = title, .detail = detail, .state = state };
        step_count += 1;
    }
    if (step_count == 0) return error.InvalidHtml;
    return out_steps[0..step_count];
}

fn stepStateColor(state: StepState, style: ui.Style) ui.Color {
    return switch (state) {
        .done => style.accent,
        .current => style.text,
        .todo => style.border,
    };
}

fn stepStateName(state: StepState) []const u8 {
    return switch (state) {
        .done => "done",
        .current => "current",
        .todo => "todo",
    };
}

fn parseStepStateName(value: []const u8) ?StepState {
    if (std.mem.eql(u8, value, "done")) return .done;
    if (std.mem.eql(u8, value, "current")) return .current;
    if (std.mem.eql(u8, value, "todo")) return .todo;
    return null;
}

const step_padding_x: f32 = 14.0;
const step_padding_y: f32 = 14.0;
const step_item_gap: f32 = 8.0;
const step_marker_x: f32 = 12.0;
const step_marker_y: f32 = 18.0;
const step_marker_size: f32 = 16.0;
const step_row_metrics = base_info_row.Metrics{
    .height = 58.0,
    .padding_left = 42.0,
    .padding_right = 10.0,
    .title_y = 11.0,
    .title_height = 16.0,
    .detail_y = 32.0,
    .detail_height = 14.0,
    .detail_line_height = 14.0,
    .detail_max_lines = 1,
};

fn measureStepItem(step: StepItem, constraints: layout.Constraints) layout.Measurement {
    return base_info_row.measure(step.title, step.detail, constraints, step_row_metrics);
}

fn stepInsets() layout.Insets {
    return .{ .top = step_padding_y, .right = step_padding_x, .bottom = step_padding_y, .left = step_padding_x };
}

test "step list component renders lesson state and hit targets" {
    const steps = [_]StepItem{
        .{ .id = 34001, .title = "Device", .detail = "Name the parts of the machine.", .state = .done },
        .{ .id = 34002, .title = "Network", .detail = "Follow a packet across a boundary.", .state = .current },
        .{ .id = 34003, .title = "Identity", .detail = "Bind authority to a key." },
    };
    const list = StepList{ .steps = &steps };
    var commands: [96]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try list.render(&scene, ui.Rect.init(0, 0, 380, 220), .{});

    try std.testing.expect(hasText(scene.written(), "Network"));
    try std.testing.expect(hasTextContaining(scene.written(), "packet across"));
    const hit = ui_input.hitTest(scene.written(), 24, 92).?;
    try std.testing.expectEqual(@as(u32, 34002), hit.id);
}

test "step list measurement counts every lesson row" {
    const one = [_]StepItem{
        .{ .id = 34001, .title = "Device", .detail = "Name the parts of the machine.", .state = .done },
    };
    const many = [_]StepItem{
        one[0],
        .{ .id = 34002, .title = "Network", .detail = "Follow a packet across a boundary.", .state = .current },
        .{ .id = 34003, .title = "Identity", .detail = "Bind authority to a key." },
    };

    const single = (StepList{ .steps = &one }).measure(.{ .width = .{ .exact = 320 }, .text_wrap = .wrap }, .{});
    const full = (StepList{ .steps = &many }).measure(.{ .width = .{ .exact = 320 }, .text_wrap = .wrap }, .{});

    try std.testing.expectEqual(@as(f32, 320), full.preferred.w);
    try std.testing.expect(full.preferred.h > single.preferred.h);
}

test "step list html codec roundtrips semantic ordered steps" {
    const steps = [_]StepItem{
        .{ .id = 34101, .title = "RAM desk", .detail = "Temporary work surface.", .state = .done },
        .{ .id = 34102, .title = "Storage", .detail = "Long term memory & files.", .state = .current },
    };
    const list = StepList{ .steps = &steps };
    var html: [768]u8 = undefined;
    var decoded_steps: [2]StepItem = undefined;
    var text: [256]u8 = undefined;

    const encoded = try list.toHtml(&html);
    const decoded = try StepList.fromHtml(encoded, &decoded_steps, &text);

    try std.testing.expectEqualStrings("<ol data-er-component=\"step-list\"><li data-er-id=\"34101\" data-er-state=\"done\"><strong>RAM desk</strong><span>Temporary work surface.</span></li><li data-er-id=\"34102\" data-er-state=\"current\"><strong>Storage</strong><span>Long term memory &amp; files.</span></li></ol>", encoded);
    try std.testing.expectEqual(@as(usize, 2), decoded.steps.len);
    try std.testing.expectEqual(@as(u32, 34102), decoded.steps[1].id);
    try std.testing.expectEqual(StepState.current, decoded.steps[1].state);
    try std.testing.expectEqualStrings("Storage", decoded.steps[1].title);
    try std.testing.expectEqualStrings("Long term memory & files.", decoded.steps[1].detail);
}

test "step list html codec rejects malformed steps" {
    var steps: [2]StepItem = undefined;
    var text: [128]u8 = undefined;

    try std.testing.expectError(error.InvalidHtml, StepList.fromHtml("<ol><li>Plain</li></ol>", &steps, &text));
    try std.testing.expectError(error.InvalidHtml, StepList.fromHtml("<ol data-er-component=\"step-list\"></ol>", &steps, &text));
    try std.testing.expectError(error.InvalidHtml, StepList.fromHtml("<ol data-er-component=\"step-list\"><li data-er-id=\"x\" data-er-state=\"todo\"><strong>Broken</strong><span>Bad id</span></li></ol>", &steps, &text));
    try std.testing.expectError(error.InvalidHtml, StepList.fromHtml("<ol data-er-component=\"step-list\"><li data-er-id=\"1\" data-er-state=\"later\"><strong>Broken</strong><span>Bad state</span></li></ol>", &steps, &text));
}

test "step list registers explicit runtime descriptor" {
    const steps = [_]StepItem{
        .{ .id = 34201, .title = "Device", .detail = "Name the parts of the machine.", .state = .done },
        .{ .id = 34202, .title = "Network", .detail = "Follow a packet across a boundary.", .state = .current },
    };
    const list = StepList{ .steps = &steps };
    var entries: [1]common.ComponentDescriptor = undefined;
    var registry = ComponentRegistry.init(&entries);
    var html: [768]u8 = undefined;
    var markdown: [768]u8 = undefined;
    var commands: [96]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    try StepList.register(&registry);
    try std.testing.expectError(error.DuplicateComponent, StepList.register(&registry));
    try std.testing.expectEqualStrings("step-list", registry.matchHtml("<ol data-er-component=\"step-list\"></ol>").?.name);
    try std.testing.expectEqualStrings("step-list", registry.matchMarkdown(":::steps\nstep: 1\n:::").?.name);

    const encoded_html = try registry.writeHtml("step-list", &list, &html);
    const encoded_markdown = try registry.writeMarkdown("step-list", &list, &markdown);
    try registry.render("step-list", &list, &scene, ui.Rect.init(0, 0, 380, 220), .{});

    try std.testing.expect(std.mem.indexOf(u8, encoded_html, "<ol data-er-component=\"step-list\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded_markdown, ":::steps") != null);
    try std.testing.expect(hasText(scene.written(), "Network"));
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
