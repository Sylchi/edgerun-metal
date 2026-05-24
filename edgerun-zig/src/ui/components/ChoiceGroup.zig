const std = @import("std");
const common = @import("../../ui_component_common.zig");
const interaction = @import("../../ui_interaction.zig");
const layout = @import("../../layouts/Types.zig");
const base_marker = @import("base/Marker.zig");
const base_surface = @import("base/Surface.zig");
const base_text_block = @import("base/TextBlock.zig");
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

pub const ChoiceOption = struct {
    id: u32,
    label: []const u8,
    selected: bool = false,
};

pub const ChoiceGroup = struct {
    id: u32,
    legend: []const u8,
    options: []const ChoiceOption,

    pub fn render(self: ChoiceGroup, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return renderChoiceGroup(self, scene, bounds, options);
    }

    pub fn collectInteractions(self: ChoiceGroup, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
        return collectChoiceGroupInteractions(self, collector, bounds);
    }

    pub fn measure(self: ChoiceGroup, constraints: layout.Constraints, options: RenderOptions) layout.Measurement {
        _ = options;
        return measureChoiceGroup(self, constraints);
    }

    pub fn toHtml(self: ChoiceGroup, out: []u8) HtmlError![]u8 {
        return writeHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, out_options: []ChoiceOption, text_out: []u8) HtmlError!ChoiceGroup {
        return readHtml(html, out_options, text_out);
    }

    pub fn toMarkdown(self: ChoiceGroup, out: []u8) MarkdownError![]u8 {
        return writeMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, out_options: []ChoiceOption, text_out: []u8) MarkdownError!ChoiceGroup {
        return readMarkdown(markdown, out_options, text_out);
    }

    pub fn register(registry: *ComponentRegistry) RegistryError!void {
        try registry.register(descriptor);
    }
};

pub const descriptor = common.ComponentDescriptor{
    .name = "choice-group",
    .html_prefix = "<fieldset data-er-component=\"choice-group\"",
    .markdown_prefix = ":::choice",
    .render = renderRegistered,
    .collect_interactions = collectRegistered,
    .write_html = writeHtmlRegistered,
    .write_markdown = writeMarkdownRegistered,
};

pub fn register(registry: *ComponentRegistry) RegistryError!void {
    return ChoiceGroup.register(registry);
}

pub fn renderChoiceGroup(group: ChoiceGroup, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    if (group.options.len == 0) return;
    const style = options.style;
    try base_surface.renderFrame(scene, bounds, options);

    const content_x = bounds.x + choice_padding_x;
    const content_w = @max(1.0, bounds.w - choice_padding_x * 2.0);
    var y = bounds.y + choice_padding_y;
    try base_text_block.render(scene, ui.Rect.init(content_x, y, content_w, choice_legend_h), group.legend, style.text, choice_legend_metrics);
    y += choice_legend_h + choice_option_gap;

    const bottom = bounds.y + bounds.h - choice_padding_y;
    for (group.options) |option| {
        if (y + choice_option_h > bottom) break;
        const option_bounds = ui.Rect.init(content_x, y, content_w, choice_option_h);
        if (option.selected) {
            try scene.pushRect(option_bounds, style.row, .fill, choice_option_radius, 0.0);
        }
        const marker_bounds = ui.Rect.init(option_bounds.x + choice_marker_x, option_bounds.y + choice_marker_y, choice_marker_size, choice_marker_size);
        try base_marker.renderRadio(scene, marker_bounds, style.border, style.accent, option.selected, choice_marker_selected_inset);
        try scene.pushAlignedText(ui.Rect.init(option_bounds.x + choice_label_x, option_bounds.y + choice_label_y, @max(1.0, option_bounds.w - choice_label_x - choice_option_padding_x), choice_label_h), option.label, style.text, .start);
        y += choice_option_h + choice_option_gap;
    }
}

pub fn collectChoiceGroupInteractions(group: ChoiceGroup, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
    if (group.options.len == 0) return;
    const content_x = bounds.x + choice_padding_x;
    const content_w = @max(1.0, bounds.w - choice_padding_x * 2.0);
    var y = bounds.y + choice_padding_y + choice_legend_h + choice_option_gap;
    const bottom = bounds.y + bounds.h - choice_padding_y;
    for (group.options) |option| {
        if (y + choice_option_h > bottom) break;
        try collector.add(.{ .kind = .button, .id = option.id, .bounds = ui.Rect.init(content_x, y, content_w, choice_option_h) });
        y += choice_option_h + choice_option_gap;
    }
}

pub fn measureChoiceGroup(group: ChoiceGroup, constraints: layout.Constraints) layout.Measurement {
    const content_constraints = constraints.inner(choiceInsets());
    const legend = base_text_block.measure(group.legend, content_constraints, choice_legend_metrics);
    var content_width = legend.preferred.w;
    var content_height = legend.preferred.h;
    for (group.options, 0..) |option, index| {
        const option_measure = base_text_block.measure(option.label, content_constraints.inner(.{ .left = choice_label_x, .right = choice_option_padding_x }), choice_label_metrics);
        content_width = @max(content_width, option_measure.preferred.w + choice_label_x + choice_option_padding_x);
        content_height += choice_option_gap + @max(choice_option_h, option_measure.preferred.h);
        if (index == 0) content_height += 0;
    }
    return layout.Measurement.flexible(
        .{ .w = choice_min_w, .h = choice_padding_y * 2.0 + choice_legend_line_h },
        .{ .w = content_width, .h = content_height },
        .{ .w = constraints.width.limit(content_width), .h = content_height },
    ).withInsets(choiceInsets()).applyExact(constraints);
}

fn renderRegistered(component: *const anyopaque, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    const group: *const ChoiceGroup = @ptrCast(@alignCast(component));
    return renderChoiceGroup(group.*, scene, bounds, options);
}

fn collectRegistered(component: *const anyopaque, collector: *interaction.Collector, bounds: ui.Rect) interaction.Error!void {
    const group: *const ChoiceGroup = @ptrCast(@alignCast(component));
    return collectChoiceGroupInteractions(group.*, collector, bounds);
}

pub fn writeHtml(group: ChoiceGroup, out: []u8) HtmlError![]u8 {
    if (group.legend.len == 0 or group.options.len == 0) return error.InvalidHtml;
    var writer = HtmlWriter.init(out);
    try writer.writeAll("<fieldset data-er-component=\"choice-group\"");
    try writer.writeAttrInt("data-er-id", group.id);
    try writer.writeAll("><legend>");
    try writer.writeEscapedText(group.legend);
    try writer.writeAll("</legend>");
    for (group.options) |option| {
        if (option.label.len == 0) return error.InvalidHtml;
        try writer.writeAll("<label");
        try writer.writeAttrInt("data-er-id", option.id);
        try writer.writeAttrBool("data-er-selected", option.selected);
        try writer.writeAll("><input type=\"radio\" name=\"choice-");
        try writer.writeInt(group.id);
        try writer.writeAll("\">");
        try writer.writeEscapedText(option.label);
        try writer.writeAll("</label>");
    }
    try writer.writeAll("</fieldset>");
    return writer.written();
}

fn writeHtmlRegistered(component: *const anyopaque, out: []u8) HtmlError![]u8 {
    const group: *const ChoiceGroup = @ptrCast(@alignCast(component));
    return writeHtml(group.*, out);
}

pub fn writeMarkdown(group: ChoiceGroup, out: []u8) MarkdownError![]u8 {
    if (group.legend.len == 0 or group.options.len == 0) return error.InvalidMarkdown;
    var writer = MarkdownWriter.init(out);
    try writer.beginDirective("choice");
    try writer.fieldInt("id", group.id);
    try writer.fieldText("legend", group.legend);
    for (group.options) |option| {
        if (option.label.len == 0) return error.InvalidMarkdown;
        try writer.fieldInt("option", option.id);
        try writer.fieldBool("selected", option.selected);
        try writer.fieldText("label", option.label);
    }
    try writer.endDirective();
    return writer.written();
}

fn writeMarkdownRegistered(component: *const anyopaque, out: []u8) MarkdownError![]u8 {
    const group: *const ChoiceGroup = @ptrCast(@alignCast(component));
    return writeMarkdown(group.*, out);
}

pub fn readMarkdown(markdown: []const u8, out_options: []ChoiceOption, text_out: []u8) MarkdownError!ChoiceGroup {
    const prefix = ":::choice\nid: ";
    const body = try common.readMarkdownDirectiveBody(markdown, ":::choice", prefix);
    var cursor = MarkdownCursor.init(body);
    const id = try common.parseMarkdownU32(try cursor.fieldBetween("", "\nlegend: "));
    var text = MarkdownTextArena.init(text_out);
    const legend = try text.unescapeInline(try cursor.fieldBetween("\nlegend: ", "\noption: "));
    if (legend.len == 0) return error.InvalidMarkdown;
    var option_count: usize = 0;
    try cursor.skipNewline();
    while (!cursor.done()) {
        if (option_count == out_options.len) return error.MarkdownBudgetExceeded;
        const option_id = try common.parseMarkdownU32(try cursor.lineAfter("option: "));
        const selected = try common.parseMarkdownBool(try cursor.fieldBetween("\nselected: ", "\nlabel: "));
        const label = try text.unescapeInline(try cursor.finalField("\nlabel: ", "\noption: "));
        if (label.len == 0) return error.InvalidMarkdown;
        out_options[option_count] = .{ .id = option_id, .label = label, .selected = selected };
        option_count += 1;
        try cursor.skipNewline();
    }
    if (option_count == 0) return error.InvalidMarkdown;
    return .{ .id = id, .legend = legend, .options = out_options[0..option_count] };
}

pub fn readHtml(html: []const u8, out_options: []ChoiceOption, text_out: []u8) HtmlError!ChoiceGroup {
    const prefix = "<fieldset data-er-component=\"choice-group\" data-er-id=\"";
    if (!std.mem.startsWith(u8, html, prefix)) {
        if (std.mem.startsWith(u8, html, "<fieldset")) return error.InvalidHtml;
        return error.UnsupportedHtml;
    }
    const after_id = html[prefix.len..];
    const id_end = std.mem.indexOf(u8, after_id, "\"><legend>") orelse return error.InvalidHtml;
    const id = try common.parseHtmlU32(after_id[0..id_end]);
    const legend_start = prefix.len + id_end + "\"><legend>".len;
    const legend_end_relative = std.mem.indexOf(u8, html[legend_start..], "</legend>") orelse return error.InvalidHtml;
    if (!std.mem.endsWith(u8, html, "</fieldset>")) return error.InvalidHtml;

    var text = HtmlTextArena.init(text_out);
    const legend = try text.unescape(html[legend_start .. legend_start + legend_end_relative]);
    if (legend.len == 0) return error.InvalidHtml;
    const options_start = legend_start + legend_end_relative + "</legend>".len;
    const options_html = html[options_start .. html.len - "</fieldset>".len];
    const options = try readOptionsHtml(options_html, id, out_options, &text);
    return .{ .id = id, .legend = legend, .options = options };
}

fn readOptionsHtml(html: []const u8, group_id: u32, out_options: []ChoiceOption, text: *HtmlTextArena) HtmlError![]const ChoiceOption {
    var expected_name_buffer: [17]u8 = undefined;
    const expected_name = std.fmt.bufPrint(&expected_name_buffer, "choice-{d}", .{group_id}) catch unreachable;
    var cursor = HtmlCursor.init(html);
    var option_count: usize = 0;
    while (!cursor.done()) {
        if (option_count == out_options.len) return error.HtmlBudgetExceeded;
        const id = try common.parseHtmlU32(try cursor.fieldBetween("<label data-er-id=\"", "\" data-er-selected=\""));
        const selected = try common.parseHtmlBool(try cursor.fieldBetween("\" data-er-selected=\"", "\"><input type=\"radio\" name=\""));
        const name = try cursor.fieldBetween("\"><input type=\"radio\" name=\"", "\">");
        if (!std.mem.eql(u8, name, expected_name)) return error.InvalidHtml;
        const label = try text.unescape(try cursor.fieldBetween("\">", "</label>"));
        try cursor.consume("</label>");
        if (label.len == 0) return error.InvalidHtml;
        out_options[option_count] = .{ .id = id, .label = label, .selected = selected };
        option_count += 1;
    }
    if (option_count == 0) return error.InvalidHtml;
    return out_options[0..option_count];
}

const choice_padding_x: f32 = 14.0;
const choice_padding_y: f32 = 14.0;
const choice_legend_h: f32 = 42.0;
const choice_legend_line_h: f32 = 20.0;
const choice_legend_avg_w: f32 = 9.5;
const choice_legend_max_lines: usize = 2;
const choice_option_h: f32 = 36.0;
const choice_option_gap: f32 = 6.0;
const choice_option_radius: f32 = 6.0;
const choice_option_padding_x: f32 = 10.0;
const choice_marker_x: f32 = 10.0;
const choice_marker_y: f32 = 10.0;
const choice_marker_size: f32 = 16.0;
const choice_marker_selected_inset: f32 = 4.0;
const choice_label_x: f32 = 36.0;
const choice_label_y: f32 = 10.0;
const choice_label_h: f32 = 14.0;
const choice_label_avg_w: f32 = 8.5;
const choice_label_max_lines: usize = 1;
const choice_min_w: f32 = 180.0;
const choice_legend_metrics = base_text_block.Metrics{
    .line_height = choice_legend_line_h,
    .average_char_width = choice_legend_avg_w,
    .max_lines = choice_legend_max_lines,
};
const choice_label_metrics = base_text_block.Metrics{
    .line_height = choice_label_h,
    .average_char_width = choice_label_avg_w,
    .max_lines = choice_label_max_lines,
};

fn choiceInsets() layout.Insets {
    return .{ .top = choice_padding_y, .right = choice_padding_x, .bottom = choice_padding_y, .left = choice_padding_x };
}

test "choice group component renders selected option and collects hit targets" {
    const options = [_]ChoiceOption{
        .{ .id = 33001, .label = "Browser asks DNS" },
        .{ .id = 33002, .label = "GPU opens a socket", .selected = true },
        .{ .id = 33003, .label = "Battery signs TLS" },
    };
    const group = ChoiceGroup{ .id = 33000, .legend = "Which part looks up a domain name?", .options = &options };
    var commands: [96]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [4]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try group.render(&scene, ui.Rect.init(0, 0, 380, 180), .{});
    try group.collectInteractions(&collector, ui.Rect.init(0, 0, 380, 180));

    try std.testing.expect(hasTextContaining(scene.written(), "domain name"));
    try std.testing.expect(hasText(scene.written(), "GPU opens a socket"));
    try std.testing.expect(ui_input.hitTest(scene.written(), 24, 104) == null);
    const hit = ui_input.regionHitTest(collector.written(), 24, 104).?;
    try std.testing.expectEqual(@as(u32, 33002), hit.id);
}

test "choice group measurement counts legend and options" {
    const options = [_]ChoiceOption{
        .{ .id = 33001, .label = "Browser asks DNS" },
        .{ .id = 33002, .label = "Resolver checks cache", .selected = true },
        .{ .id = 33003, .label = "Certificate proves route ownership" },
    };
    const group = ChoiceGroup{ .id = 33000, .legend = "Which part looks up a domain name?", .options = &options };

    const measured = group.measure(.{ .width = .{ .exact = 320 }, .text_wrap = .wrap }, .{});
    const empty = (ChoiceGroup{ .id = 33000, .legend = group.legend, .options = &.{} }).measure(.{ .width = .{ .exact = 320 }, .text_wrap = .wrap }, .{});

    try std.testing.expectEqual(@as(f32, 320), measured.preferred.w);
    try std.testing.expect(measured.preferred.h > empty.preferred.h);
}

test "choice group html codec roundtrips semantic radio options" {
    const options = [_]ChoiceOption{
        .{ .id = 33101, .label = "The app" },
        .{ .id = 33102, .label = "The resolver & cache", .selected = true },
    };
    const group = ChoiceGroup{ .id = 33100, .legend = "Who answers cached DNS?", .options = &options };
    var html: [768]u8 = undefined;
    var decoded_options: [2]ChoiceOption = undefined;
    var text: [256]u8 = undefined;

    const encoded = try group.toHtml(&html);
    const decoded = try ChoiceGroup.fromHtml(encoded, &decoded_options, &text);

    try std.testing.expectEqualStrings("<fieldset data-er-component=\"choice-group\" data-er-id=\"33100\"><legend>Who answers cached DNS?</legend><label data-er-id=\"33101\" data-er-selected=\"false\"><input type=\"radio\" name=\"choice-33100\">The app</label><label data-er-id=\"33102\" data-er-selected=\"true\"><input type=\"radio\" name=\"choice-33100\">The resolver &amp; cache</label></fieldset>", encoded);
    try std.testing.expectEqual(@as(u32, 33100), decoded.id);
    try std.testing.expectEqualStrings("Who answers cached DNS?", decoded.legend);
    try std.testing.expectEqual(@as(usize, 2), decoded.options.len);
    try std.testing.expectEqual(@as(u32, 33102), decoded.options[1].id);
    try std.testing.expect(decoded.options[1].selected);
    try std.testing.expectEqualStrings("The resolver & cache", decoded.options[1].label);
}

test "choice group html codec rejects malformed radio groups" {
    var options: [2]ChoiceOption = undefined;
    var text: [128]u8 = undefined;

    try std.testing.expectError(error.InvalidHtml, ChoiceGroup.fromHtml("<fieldset><legend>Plain</legend></fieldset>", &options, &text));
    try std.testing.expectError(error.InvalidHtml, ChoiceGroup.fromHtml("<fieldset data-er-component=\"choice-group\" data-er-id=\"x\"><legend>Broken</legend></fieldset>", &options, &text));
    try std.testing.expectError(error.InvalidHtml, ChoiceGroup.fromHtml("<fieldset data-er-component=\"choice-group\" data-er-id=\"1\"><legend>Broken</legend><label data-er-id=\"2\" data-er-selected=\"maybe\"><input type=\"radio\" name=\"choice-1\">Option</label></fieldset>", &options, &text));
    try std.testing.expectError(error.InvalidHtml, ChoiceGroup.fromHtml("<fieldset data-er-component=\"choice-group\" data-er-id=\"1\"><legend>Broken</legend><label data-er-id=\"2\" data-er-selected=\"false\"><input type=\"radio\" name=\"choice-9\">Option</label></fieldset>", &options, &text));
}

test "choice group registers explicit runtime descriptor" {
    const options = [_]ChoiceOption{
        .{ .id = 33201, .label = "The app" },
        .{ .id = 33202, .label = "The resolver and cache", .selected = true },
    };
    const group = ChoiceGroup{ .id = 33200, .legend = "Who answers cached DNS?", .options = &options };
    var entries: [1]common.ComponentDescriptor = undefined;
    var registry = ComponentRegistry.init(&entries);
    var html: [768]u8 = undefined;
    var markdown: [768]u8 = undefined;
    var commands: [96]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    var regions: [4]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);

    try ChoiceGroup.register(&registry);
    try std.testing.expectError(error.DuplicateComponent, ChoiceGroup.register(&registry));
    try std.testing.expectEqualStrings("choice-group", registry.matchHtml("<fieldset data-er-component=\"choice-group\"></fieldset>").?.name);
    try std.testing.expectEqualStrings("choice-group", registry.matchMarkdown(":::choice\nid: 1\n:::").?.name);

    const encoded_html = try registry.writeHtml("choice-group", &group, &html);
    const encoded_markdown = try registry.writeMarkdown("choice-group", &group, &markdown);
    try registry.render("choice-group", &group, &scene, ui.Rect.init(0, 0, 380, 180), .{});
    try registry.collectInteractions("choice-group", &group, &collector, ui.Rect.init(0, 0, 380, 180));

    try std.testing.expect(std.mem.indexOf(u8, encoded_html, "<fieldset data-er-component=\"choice-group\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded_markdown, ":::choice") != null);
    try std.testing.expect(hasText(scene.written(), "The resolver and cache"));
    try std.testing.expectEqual(@as(u32, 33202), ui_input.regionHitTest(collector.written(), 24, 104).?.id);
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
