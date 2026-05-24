const std = @import("std");
const common = @import("../../ui_component_common.zig");
const ui = @import("../../ui.zig");

const ComponentRegistry = common.ComponentRegistry;
const HtmlError = common.HtmlError;
const HtmlTextArena = common.HtmlTextArena;
const HtmlWriter = common.HtmlWriter;
const MarkdownError = common.MarkdownError;
const MarkdownWriter = common.MarkdownWriter;
const RegistryError = common.RegistryError;
const RenderOptions = common.RenderOptions;

pub const CodeBlock = struct {
    language: []const u8 = "",
    lines: []const []const u8,

    pub fn render(self: CodeBlock, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
        return renderCodeBlock(self, scene, bounds, options);
    }

    pub fn toHtml(self: CodeBlock, out: []u8) HtmlError![]u8 {
        return writeHtml(self, out);
    }

    pub fn fromHtml(html: []const u8, out_lines: [][]const u8, text_out: []u8) HtmlError!CodeBlock {
        return readHtml(html, out_lines, text_out);
    }

    pub fn toMarkdown(self: CodeBlock, out: []u8) MarkdownError![]u8 {
        return writeMarkdown(self, out);
    }

    pub fn fromMarkdown(markdown: []const u8, out_lines: [][]const u8) MarkdownError!CodeBlock {
        return readMarkdown(markdown, out_lines);
    }

    pub fn register(registry: *ComponentRegistry) RegistryError!void {
        try registry.register(descriptor);
    }
};

pub const descriptor = common.ComponentDescriptor{
    .name = "code-block",
    .html_prefix = "<pre data-er-component=\"code-block\"",
    .markdown_prefix = "```",
    .render = renderRegistered,
    .write_html = writeHtmlRegistered,
    .write_markdown = writeMarkdownRegistered,
};

pub fn register(registry: *ComponentRegistry) RegistryError!void {
    return CodeBlock.register(registry);
}

pub fn renderCodeBlock(block: CodeBlock, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    try scene.pushRect(bounds, options.style.bg, .fill, code_radius, 0.0);
    try scene.pushRect(bounds, options.style.border, .border, code_radius, 0.0);
    if (try scene.pushClip(bounds.insetUniform(code_clip_inset))) {
        defer scene.popClip();
        var y = bounds.y + code_padding_y;
        for (block.lines) |line| {
            if (y + code_line_height > bounds.y + bounds.h - code_padding_y) break;
            try scene.pushAlignedText(ui.Rect.init(bounds.x + code_padding_x, y, @max(1.0, bounds.w - code_padding_x * 2.0), code_text_height), line, options.style.accent, .start);
            y += code_line_height;
        }
    }
}

fn renderRegistered(component: *const anyopaque, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) ui.RenderError!void {
    const block: *const CodeBlock = @ptrCast(@alignCast(component));
    return renderCodeBlock(block.*, scene, bounds, options);
}

pub fn writeHtml(block: CodeBlock, out: []u8) HtmlError![]u8 {
    var writer = HtmlWriter.init(out);
    try writer.writeAll("<pre data-er-component=\"code-block\"><code");
    try writer.writeAttrText("data-er-lang", block.language);
    try writer.writeByte('>');
    for (block.lines, 0..) |line, index| {
        if (index != 0) try writer.writeByte('\n');
        try writer.writeEscapedText(line);
    }
    try writer.writeAll("</code></pre>");
    return writer.written();
}

fn writeHtmlRegistered(component: *const anyopaque, out: []u8) HtmlError![]u8 {
    const block: *const CodeBlock = @ptrCast(@alignCast(component));
    return writeHtml(block.*, out);
}

pub fn writeMarkdown(block: CodeBlock, out: []u8) MarkdownError![]u8 {
    if (!validMarkdownFenceLanguage(block.language)) return error.InvalidMarkdown;
    var writer = MarkdownWriter.init(out);
    try writer.writeAll("```");
    try writer.writeAll(block.language);
    try writer.writeByte('\n');
    for (block.lines, 0..) |line, index| {
        if (std.mem.indexOf(u8, line, "```") != null) return error.InvalidMarkdown;
        if (index != 0) try writer.writeByte('\n');
        try writer.writeAll(line);
    }
    try writer.writeAll("\n```");
    return writer.written();
}

fn writeMarkdownRegistered(component: *const anyopaque, out: []u8) MarkdownError![]u8 {
    const block: *const CodeBlock = @ptrCast(@alignCast(component));
    return writeMarkdown(block.*, out);
}

pub fn readMarkdown(markdown: []const u8, out_lines: [][]const u8) MarkdownError!CodeBlock {
    if (!std.mem.startsWith(u8, markdown, "```")) return error.UnsupportedMarkdown;
    const language_start = "```".len;
    const language_end_relative = std.mem.indexOfScalar(u8, markdown[language_start..], '\n') orelse return error.InvalidMarkdown;
    const language = markdown[language_start .. language_start + language_end_relative];
    if (!validMarkdownFenceLanguage(language)) return error.InvalidMarkdown;
    if (!std.mem.endsWith(u8, markdown, "\n```")) return error.InvalidMarkdown;
    const body_start = language_start + language_end_relative + 1;
    const body_end = markdown.len - "\n```".len;
    const lines = try readMarkdownLines(markdown[body_start..body_end], out_lines);
    return .{ .language = language, .lines = lines };
}

fn readMarkdownLines(body: []const u8, out_lines: [][]const u8) MarkdownError![]const []const u8 {
    if (body.len == 0) return out_lines[0..0];
    var line_count: usize = 0;
    var cursor = LineCursor.init(body);
    while (cursor.next()) |line| {
        if (line_count == out_lines.len) return error.MarkdownBudgetExceeded;
        if (std.mem.indexOf(u8, line, "```") != null) return error.InvalidMarkdown;
        out_lines[line_count] = line;
        line_count += 1;
    }
    return out_lines[0..line_count];
}

pub fn readHtml(html: []const u8, out_lines: [][]const u8, text_out: []u8) HtmlError!CodeBlock {
    const prefix = "<pre data-er-component=\"code-block\"><code data-er-lang=\"";
    if (!std.mem.startsWith(u8, html, prefix)) {
        if (std.mem.startsWith(u8, html, "<pre")) return error.InvalidHtml;
        return error.UnsupportedHtml;
    }
    const after_lang = html[prefix.len..];
    const lang_end = std.mem.indexOf(u8, after_lang, "\">") orelse return error.InvalidHtml;
    if (!std.mem.endsWith(u8, html, "</code></pre>")) return error.InvalidHtml;
    var text = HtmlTextArena.init(text_out);
    const language = try text.unescape(after_lang[0..lang_end]);
    const code_start = prefix.len + lang_end + "\">".len;
    const body = html[code_start .. html.len - "</code></pre>".len];
    const lines = try readHtmlLines(body, out_lines, &text);
    return .{ .language = language, .lines = lines };
}

fn readHtmlLines(html: []const u8, out_lines: [][]const u8, text: *HtmlTextArena) HtmlError![]const []const u8 {
    var line_count: usize = 0;
    var cursor = LineCursor.init(html);
    while (cursor.next()) |line| {
        if (line_count == out_lines.len) return error.HtmlBudgetExceeded;
        out_lines[line_count] = try text.unescape(line);
        line_count += 1;
    }
    return out_lines[0..line_count];
}

const code_radius: f32 = 10.0;
const code_padding_x: f32 = 18.0;
const code_padding_y: f32 = 18.0;
const code_line_height: f32 = 17.0;
const code_text_height: f32 = 12.0;
const code_clip_inset: f32 = 1.0;

const LineCursor = struct {
    body: []const u8,
    cursor: usize = 0,

    fn init(body: []const u8) LineCursor {
        return .{ .body = body };
    }

    fn next(self: *LineCursor) ?[]const u8 {
        if (self.cursor > self.body.len) return null;
        if (self.body.len == 0) return null;
        const end = std.mem.indexOfScalarPos(u8, self.body, self.cursor, '\n') orelse self.body.len;
        const line = self.body[self.cursor..end];
        self.cursor = if (end == self.body.len) self.body.len + 1 else end + 1;
        return line;
    }
};

fn validMarkdownFenceLanguage(value: []const u8) bool {
    for (value) |byte| {
        switch (byte) {
            'a'...'z', 'A'...'Z', '0'...'9', '-', '_' => {},
            else => return false,
        }
    }
    return true;
}

test "code block component renders clipped source lines" {
    const lines = [_][]const u8{ "const dns = lookup(name);", "try dns.await();" };
    const block = CodeBlock{ .language = "zig", .lines = &lines };
    var commands: [32]ui.Command = undefined;
    var clips: [2]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);

    try block.render(&scene, ui.Rect.init(0, 0, 360, 64), .{});

    try std.testing.expect(hasText(scene.written(), "const dns = lookup(name);"));
}

test "code block html codec roundtrips escaped language and source" {
    const lines = [_][]const u8{ "if (tls < dns) {", "    return &root;" };
    const block = CodeBlock{ .language = "zig", .lines = &lines };
    var html: [256]u8 = undefined;
    var decoded_lines: [2][]const u8 = undefined;
    var text: [128]u8 = undefined;

    const encoded = try block.toHtml(&html);
    const decoded = try CodeBlock.fromHtml(encoded, &decoded_lines, &text);

    try std.testing.expectEqualStrings("<pre data-er-component=\"code-block\"><code data-er-lang=\"zig\">if (tls &lt; dns) {\n    return &amp;root;</code></pre>", encoded);
    try std.testing.expectEqualStrings("zig", decoded.language);
    try std.testing.expectEqual(@as(usize, 2), decoded.lines.len);
    try std.testing.expectEqualStrings("    return &root;", decoded.lines[1]);
}

test "code block html codec rejects malformed blocks" {
    var lines: [2][]const u8 = undefined;
    var text: [64]u8 = undefined;

    try std.testing.expectError(error.InvalidHtml, CodeBlock.fromHtml("<pre><code>plain</code></pre>", &lines, &text));
    try std.testing.expectError(error.UnsupportedHtml, CodeBlock.fromHtml("<p>plain</p>", &lines, &text));
}

test "code block markdown codec roundtrips fenced source" {
    const lines = [_][]const u8{ "const port = 443;", "try connect(port);" };
    const block = CodeBlock{ .language = "zig", .lines = &lines };
    var markdown: [160]u8 = undefined;
    var decoded_lines: [2][]const u8 = undefined;

    const encoded = try block.toMarkdown(&markdown);
    const decoded = try CodeBlock.fromMarkdown(encoded, &decoded_lines);

    try std.testing.expectEqualStrings("```zig\nconst port = 443;\ntry connect(port);\n```", encoded);
    try std.testing.expectEqualStrings("zig", decoded.language);
    try std.testing.expectEqualStrings("try connect(port);", decoded.lines[1]);
}

test "code block markdown codec rejects bad fences and languages" {
    var lines: [2][]const u8 = undefined;

    try std.testing.expectError(error.InvalidMarkdown, CodeBlock.fromMarkdown("```zig\nbad ``` fence\n```", &lines));
    try std.testing.expectError(error.InvalidMarkdown, CodeBlock.fromMarkdown("```zig lang\nbad\n```", &lines));
    try std.testing.expectError(error.UnsupportedMarkdown, CodeBlock.fromMarkdown("plain paragraph", &lines));
}

test "code block registers explicit runtime descriptor" {
    const lines = [_][]const u8{"const app = try edge.compile(source);"};
    const block = CodeBlock{ .language = "zig", .lines = &lines };
    var entries: [1]common.ComponentDescriptor = undefined;
    var registry = ComponentRegistry.init(&entries);
    var html: [192]u8 = undefined;
    var markdown: [128]u8 = undefined;
    var commands: [16]ui.Command = undefined;
    var clips: [1]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);

    try CodeBlock.register(&registry);
    try std.testing.expectError(error.DuplicateComponent, CodeBlock.register(&registry));
    try std.testing.expectEqualStrings("code-block", registry.matchHtml("<pre data-er-component=\"code-block\"><code data-er-lang=\"zig\"></code></pre>").?.name);
    try std.testing.expectEqualStrings("code-block", registry.matchMarkdown("```zig\n").?.name);

    const encoded_html = try registry.writeHtml("code-block", &block, &html);
    const encoded_markdown = try registry.writeMarkdown("code-block", &block, &markdown);
    try registry.render("code-block", &block, &scene, ui.Rect.init(0, 0, 360, 64), .{});

    try std.testing.expect(std.mem.indexOf(u8, encoded_html, "<pre data-er-component=\"code-block\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, encoded_markdown, "```zig") != null);
    try std.testing.expect(hasText(scene.written(), "const app = try edge.compile(source);"));
}

fn hasText(commands: []const ui.Command, value: []const u8) bool {
    for (commands) |command| {
        if (command == .text and std.mem.eql(u8, command.text.value, value)) return true;
    }
    return false;
}
