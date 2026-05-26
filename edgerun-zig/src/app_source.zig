const std = @import("std");
const icon = @import("icon.zig");
const interaction = @import("ui_interaction.zig");
const ui = @import("ui.zig");
const components = @import("ui_components.zig");
const app_chrome = @import("app_chrome.zig");
const design = @import("app_design.zig");

pub const compile_button_id: u32 = 32_001;
pub const download_button_id: u32 = 32_002;
pub const launch_button_id: u32 = 32_003;
pub const reset_button_id: u32 = 32_004;

const header_h: f32 = app_chrome.header_h;
const content_wide: f32 = design.content_wide;
const content_pad: f32 = design.content_pad;
const page_top_pad: f32 = 48.0;
const page_bottom_pad: f32 = 120.0;
const panel_radius: f32 = app_chrome.surface_radius;
const gap: f32 = 18.0;
const panel_pad: f32 = 18.0;
const toolbar_label_h: f32 = 18.0;
const toolbar_title_h: f32 = 20.0;
const toolbar_detail_h: f32 = 16.0;
const toolbar_row_gap: f32 = 10.0;
const toolbar_action_gap: f32 = 10.0;
const source_action_h: f32 = design.compact_control_h + 2.0;
const compiler_title_h: f32 = 18.0;
const compiler_text_h: f32 = 16.0;
const compiler_bar_h: f32 = 8.0;
const compiler_stage_h: f32 = 18.0;
const compiler_diagnostic_h: f32 = 16.0;
const code_pad: f32 = 18.0;
const code_line_h: f32 = 18.0;
const code_gutter_w: f32 = 68.0;
const code_char_w: f32 = 7.4;
const editor_status_h: f32 = 30.0;
const compile_stage_count: usize = 4;
const compact_w: f32 = 720.0;
const max_rendered_lines: usize = 40;
const min_editor_lines_compact: usize = 18;
const min_editor_lines_wide: usize = 24;
const max_editor_lines_compact: usize = 28;
const max_editor_lines_wide: usize = 40;
const line_number_label_bytes: usize = 8;
const editor_info_label_bytes: usize = 96;

const palette = design.palette;
const syntax_keyword = ui.Color{ .r = 125, .g = 211, .b = 252 };
const syntax_type = ui.Color{ .r = 196, .g = 181, .b = 253 };
const syntax_string = ui.Color{ .r = 134, .g = 239, .b = 172 };
const syntax_number = ui.Color{ .r = 253, .g = 186, .b = 116 };
const syntax_comment = ui.Color{ .r = 113, .g = 113, .b = 122 };
const syntax_builtin = ui.Color{ .r = 252, .g = 211, .b = 77 };
const syntax_punctuation = ui.Color{ .r = 148, .g = 163, .b = 184 };
const active_line = ui.Color{ .r = 22, .g = 30, .b = 38 };
const gutter_bg = ui.Color{ .r = 10, .g = 12, .b = 16 };
const status_bg = ui.Color{ .r = 13, .g = 15, .b = 19 };

var line_number_labels: [max_rendered_lines][line_number_label_bytes]u8 = undefined;
var editor_info_label: [editor_info_label_bytes]u8 = undefined;

pub const State = struct {
    scroll_y: f32 = 0.0,
    hover_x: f32 = -1.0,
    hover_y: f32 = -1.0,
    label: []const u8 = "",
    source: []const u8 = "",
    cursor: usize = 0,
    workspace_bytes: usize = 0,
    file_bytes: usize = 0,
    release_bytes: usize = 0,
    dirty: bool = false,
    status: []const u8 = "",
    compile_phase: []const u8 = "idle",
    compile_progress: f32 = 0.0,
    compile_summary: []const u8 = "",
    diagnostic: []const u8 = "",
};

pub fn contentHeight(width: f32, state: State) f32 {
    const content_w = @min(content_wide, @max(1.0, width - content_pad * 2.0));
    return header_h + page_top_pad + toolbarHeight(content_w) + gap + editorHeight(content_w, state) + gap + statusHeight(content_w, state) + page_bottom_pad;
}

pub fn render(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State) !void {
    const content_w = @min(content_wide, @max(1.0, bounds.w - content_pad * 2.0));
    const content = ui.Rect.init(bounds.x + (bounds.w - content_w) * 0.5, bounds.y, content_w, header_h);
    try fill(scene, bounds, palette.bg, 0.0);

    const top = bounds.y + header_h + page_top_pad - state.scroll_y;
    const toolbar = ui.Rect.init(content.x, top, content.w, toolbarHeight(content.w));
    try renderToolbar(scene, collector, toolbar, state);

    const editor = ui.Rect.init(content.x, toolbar.y + toolbar.h + gap, content.w, editorHeight(content.w, state));
    try renderEditor(scene, editor, state);

    const status = ui.Rect.init(content.x, editor.y + editor.h + gap, content.w, statusHeight(content.w, state));
    try renderStatus(scene, status, state);

    try app_chrome.renderHeader(scene, collector, ui.Rect.init(bounds.x, bounds.y, bounds.w, header_h), content, .source);
}

fn renderToolbar(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State) !void {
    try fill(scene, bounds, palette.panel, panel_radius);
    try stroke(scene, bounds, palette.border, panel_radius);
    try text(scene, bounds.x + panel_pad, bounds.y + panel_pad, bounds.w - panel_pad * 2.0, toolbar_label_h, "Source workspace", palette.primary);
    try text(scene, bounds.x + panel_pad, bounds.y + panel_pad + toolbar_label_h + toolbar_row_gap, bounds.w - panel_pad * 2.0, toolbar_title_h, state.label, palette.text);
    try text(scene, bounds.x + panel_pad, bounds.y + panel_pad + toolbar_label_h + toolbar_row_gap + toolbar_title_h + toolbar_row_gap, bounds.w - panel_pad * 2.0, toolbar_detail_h, toolbarDetail(state), toolbarDetailColor(state));

    const compact = bounds.w < compact_w;
    const button_w: f32 = if (compact) @max(design.min_touch_target, (bounds.w - panel_pad * 2.0 - toolbar_action_gap * 3.0) / 4.0) else @min(132.0, @max(design.min_touch_target, (bounds.w - panel_pad * 2.0 - toolbar_action_gap * 3.0) / 4.0));
    const button_y = if (compact) bounds.y + bounds.h - panel_pad - source_action_h else bounds.y + panel_pad;
    const icon_only = compact and button_w < 92.0;
    const reset = ui.Rect.init(bounds.x + bounds.w - panel_pad - button_w, button_y, button_w, source_action_h);
    const launch = ui.Rect.init(reset.x - toolbar_action_gap - button_w, button_y, button_w, source_action_h);
    const download = ui.Rect.init(launch.x - toolbar_action_gap - button_w, button_y, button_w, source_action_h);
    const compile = ui.Rect.init(download.x - toolbar_action_gap - button_w, button_y, button_w, source_action_h);
    try button(scene, collector, compile, if (icon_only) "" else "Compile", compile_button_id, .primary, .cpu, canCompile(state));
    try button(scene, collector, download, if (icon_only) "" else "Export", download_button_id, .secondary, .file, canExport(state));
    try button(scene, collector, launch, if (icon_only) "" else "Run", launch_button_id, .secondary, .send, canRun(state));
    try button(scene, collector, reset, if (icon_only) "" else "Reset", reset_button_id, .ghost, .trash, true);
}

fn renderEditor(scene: *ui.Scene, bounds: ui.Rect, state: State) !void {
    try fill(scene, bounds, palette.code_bg, panel_radius);
    try stroke(scene, bounds, palette.border, panel_radius);
    const status_y = bounds.y + bounds.h - editor_status_h;
    try fill(scene, ui.Rect.init(bounds.x, bounds.y, code_pad + code_gutter_w - 10.0, bounds.h - editor_status_h), gutter_bg, panel_radius);

    const cursor_line = lineIndexAt(state.source, state.cursor);
    const code_h = @max(1.0, bounds.h - editor_status_h);
    const visible_lines = @min(max_rendered_lines, @max(@as(usize, 1), @as(usize, @intFromFloat(@max(1.0, (code_h - code_pad * 2.0) / code_line_h)))));
    const first_line = if (cursor_line > visible_lines / 2) cursor_line - visible_lines / 2 else 0;
    var line_start = lineStartAt(state.source, first_line);
    var line_number = first_line + 1;
    var rendered: usize = 0;
    var y = bounds.y + code_pad;
    while (rendered < max_rendered_lines and line_start <= state.source.len and y + code_line_h <= status_y - code_pad) : (rendered += 1) {
        const line_end = lineEnd(state.source, line_start);
        const line = state.source[line_start..line_end];
        const visible = line[0..@min(line.len, maxVisibleColumns(bounds.w))];
        const is_cursor_line = state.cursor >= line_start and state.cursor <= line_end;
        if (is_cursor_line) {
            try fill(scene, ui.Rect.init(bounds.x + code_pad + code_gutter_w - 4.0, y - 1.0, bounds.w - code_pad - code_gutter_w, code_line_h + 2.0), active_line, 4.0);
        }
        try text(scene, bounds.x + 12.0, y, code_gutter_w - 18.0, code_line_h, lineNumberLabel(rendered, line_number), if (is_cursor_line) palette.primary else palette.muted);
        try renderSyntaxLine(scene, bounds.x + code_pad + code_gutter_w, y, bounds.w - code_pad * 2.0 - code_gutter_w, visible);
        if (is_cursor_line) {
            const column = @min(state.cursor - line_start, visible.len);
            const caret_x = bounds.x + code_pad + code_gutter_w + @as(f32, @floatFromInt(column)) * code_char_w;
            try fill(scene, ui.Rect.init(caret_x, y + 2.0, 2.0, code_line_h - 4.0), palette.primary, 0.0);
        }
        y += code_line_h;
        if (line_end == state.source.len) break;
        line_start = line_end + 1;
        line_number += 1;
    }

    if (state.source.len == 0) {
        try text(scene, bounds.x + code_pad + code_gutter_w, bounds.y + code_pad, bounds.w - code_pad * 2.0 - code_gutter_w, code_line_h, emptyEditorLabel(state), emptyEditorColor(state));
    }

    try renderEditorStatus(scene, ui.Rect.init(bounds.x, status_y, bounds.w, editor_status_h), state);
}

fn renderStatus(scene: *ui.Scene, bounds: ui.Rect, state: State) !void {
    try fill(scene, bounds, palette.panel_alt, panel_radius);
    try stroke(scene, bounds, palette.border, panel_radius);
    try text(scene, bounds.x + panel_pad, bounds.y + panel_pad, bounds.w - panel_pad * 2.0, compiler_title_h, "Compiler", palette.cyan);
    try text(scene, bounds.x + panel_pad, bounds.y + 44.0, bounds.w - panel_pad * 2.0, compiler_text_h, state.status, palette.text);
    try text(scene, bounds.x + panel_pad, bounds.y + 70.0, bounds.w - panel_pad * 2.0, compiler_text_h, state.compile_summary, palette.dim);

    const bar = ui.Rect.init(bounds.x + panel_pad, bounds.y + 100.0, @max(1.0, bounds.w - panel_pad * 2.0), compiler_bar_h);
    try fill(scene, bar, palette.neutral_soft, 4.0);
    try fill(scene, ui.Rect.init(bar.x, bar.y, bar.w * std.math.clamp(state.compile_progress, 0.0, 1.0), bar.h), progressColor(state.compile_progress), 4.0);
    try renderCompileStages(scene, ui.Rect.init(bar.x, bar.y - 5.0, bar.w, compiler_stage_h), state.compile_progress);
    try text(scene, bounds.x + panel_pad, bounds.y + 116.0, bounds.w - panel_pad * 2.0, compiler_text_h, state.compile_phase, palette.primary);
    if (state.diagnostic.len != 0) try text(scene, bounds.x + panel_pad, bounds.y + 132.0, bounds.w - panel_pad * 2.0, compiler_diagnostic_h, state.diagnostic, palette.danger);
}

fn renderEditorStatus(scene: *ui.Scene, bounds: ui.Rect, state: State) !void {
    try fill(scene, bounds, status_bg, 0.0);
    try stroke(scene, ui.Rect.init(bounds.x, bounds.y, bounds.w, 1.0), palette.border, 0.0);
    const info = editorInfoLabel(state);
    try text(scene, bounds.x + 14.0, bounds.y + 7.0, bounds.w - 28.0, 16.0, info, palette.dim);
    const dirty_label = editorSaveLabel(state);
    const dirty_color = editorSaveColor(state);
    try text(scene, bounds.x + @max(0.0, bounds.w - 112.0), bounds.y + 7.0, 96.0, 16.0, dirty_label, dirty_color);
}

fn renderCompileStages(scene: *ui.Scene, bounds: ui.Rect, progress: f32) !void {
    const labels = [_][]const u8{ "VFS", "INIT", "COMPILE", "ARTIFACT" };
    const thresholds = [_]f32{ 0.08, 0.18, 0.52, 0.88 };
    const segment = bounds.w / @as(f32, @floatFromInt(compile_stage_count));
    for (labels, 0..) |label, index| {
        const x = bounds.x + segment * @as(f32, @floatFromInt(index));
        const color = if (progress >= thresholds[index]) palette.primary else palette.muted;
        try fill(scene, ui.Rect.init(x, bounds.y + 3.0, 2.0, 12.0), color, 0.0);
        try text(scene, x + 6.0, bounds.y, @max(1.0, segment - 8.0), 12.0, label, color);
    }
}

fn button(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, label: []const u8, id: u32, variant: components.ButtonVariant, leading: icon.Icon, enabled: bool) !void {
    if (!enabled) {
        try components.renderComponent(scene, bounds, .{ .button = .{ .id = id, .label = label, .variant = variant, .leading_icon = leading } }, .{
            .style = app_chrome.style(),
            .control = .{ .disabled = true },
        });
        return;
    }
    try components.renderComponent(scene, bounds, .{ .button = .{ .id = id, .label = label, .variant = variant, .leading_icon = leading } }, .{ .style = app_chrome.style() });
    try components.collectComponentInteractions(collector, bounds, .{ .button = .{ .id = id, .label = label } });
}

fn canCompile(state: State) bool {
    return state.workspace_bytes != 0 and state.file_bytes != 0 and !isErrorStatus(state.status);
}

fn canExport(state: State) bool {
    return state.release_bytes != 0;
}

fn canRun(state: State) bool {
    return state.release_bytes != 0;
}

fn isErrorStatus(status: []const u8) bool {
    return std.mem.startsWith(u8, status, "error:") or std.mem.indexOf(u8, status, "not loaded") != null;
}

fn toolbarDetail(state: State) []const u8 {
    if (state.workspace_bytes == 0) return "workspace not loaded";
    if (state.file_bytes == 0) return state.status;
    if (state.dirty) return "edited canonical workspace";
    return "canonical workspace loaded";
}

fn toolbarDetailColor(state: State) ui.Color {
    if (state.workspace_bytes == 0 or state.file_bytes == 0 or isErrorStatus(state.status)) return palette.danger;
    if (state.dirty) return palette.amber;
    return palette.dim;
}

fn emptyEditorLabel(state: State) []const u8 {
    if (state.workspace_bytes == 0) return "workspace not loaded";
    if (state.status.len != 0) return state.status;
    return "empty source file";
}

fn emptyEditorColor(state: State) ui.Color {
    if (state.workspace_bytes == 0 or isErrorStatus(state.status)) return palette.danger;
    return palette.muted;
}

fn editorSaveLabel(state: State) []const u8 {
    if (state.workspace_bytes == 0 or state.file_bytes == 0 or isErrorStatus(state.status)) return "unavailable";
    return if (state.dirty) "modified" else "saved";
}

fn editorSaveColor(state: State) ui.Color {
    if (state.workspace_bytes == 0 or state.file_bytes == 0 or isErrorStatus(state.status)) return palette.danger;
    return if (state.dirty) palette.amber else palette.primary;
}

fn editorHeight(content_w: f32, state: State) f32 {
    const compact = content_w < compact_w;
    const min_lines = if (compact) min_editor_lines_compact else min_editor_lines_wide;
    const max_lines = if (compact) max_editor_lines_compact else max_editor_lines_wide;
    const source_lines = lineCount(state.source);
    const measured_lines = std.math.clamp(source_lines + 2, min_lines, max_lines);
    return editor_status_h + code_pad * 2.0 + @as(f32, @floatFromInt(measured_lines)) * code_line_h;
}

fn toolbarHeight(content_w: f32) f32 {
    const text_h = panel_pad + toolbar_label_h + toolbar_row_gap + toolbar_title_h + toolbar_row_gap + toolbar_detail_h + panel_pad;
    if (content_w >= compact_w) return @max(text_h, panel_pad + source_action_h + panel_pad);
    return text_h + toolbar_row_gap + source_action_h + panel_pad;
}

fn statusHeight(_: f32, state: State) f32 {
    const diagnostic_h = if (state.diagnostic.len == 0) 0.0 else compiler_diagnostic_h;
    return panel_pad + compiler_title_h + 8.0 + compiler_text_h + 10.0 + compiler_text_h + 14.0 + compiler_stage_h + 8.0 + compiler_text_h + diagnostic_h + panel_pad;
}

fn maxVisibleColumns(width: f32) usize {
    const code_w = @max(1.0, width - code_pad * 2.0 - code_gutter_w);
    return @max(1, @as(usize, @intFromFloat(code_w / code_char_w)));
}

fn renderSyntaxLine(scene: *ui.Scene, x: f32, y: f32, w: f32, line: []const u8) !void {
    var index: usize = 0;
    while (index < line.len) {
        const token = nextToken(line, index);
        try text(scene, x + @as(f32, @floatFromInt(token.start)) * code_char_w, y, @max(1.0, w - @as(f32, @floatFromInt(token.start)) * code_char_w), code_line_h, line[token.start..token.end], token.color);
        index = token.end;
    }
}

const SyntaxToken = struct {
    start: usize,
    end: usize,
    color: ui.Color,
};

fn nextToken(line: []const u8, start: usize) SyntaxToken {
    if (start >= line.len) return .{ .start = start, .end = start, .color = palette.text };
    const byte = line[start];
    if (byte == '/' and start + 1 < line.len and line[start + 1] == '/') return .{ .start = start, .end = line.len, .color = syntax_comment };
    if (byte == '"') return .{ .start = start, .end = stringEnd(line, start + 1), .color = syntax_string };
    if (byte == '@') return .{ .start = start, .end = identifierEnd(line, start + 1), .color = syntax_builtin };
    if (isDigit(byte)) return .{ .start = start, .end = numberEnd(line, start + 1), .color = syntax_number };
    if (isIdentifierStart(byte)) {
        const end = identifierEnd(line, start + 1);
        const word = line[start..end];
        return .{ .start = start, .end = end, .color = if (isKeyword(word)) syntax_keyword else if (isTypeWord(word)) syntax_type else palette.text };
    }
    if (isPunctuation(byte)) return .{ .start = start, .end = start + 1, .color = syntax_punctuation };
    return .{ .start = start, .end = start + 1, .color = palette.text };
}

fn stringEnd(line: []const u8, start: usize) usize {
    var index = start;
    while (index < line.len) : (index += 1) {
        if (line[index] == '\\') {
            index += 1;
            continue;
        }
        if (line[index] == '"') return index + 1;
    }
    return line.len;
}

fn identifierEnd(line: []const u8, start: usize) usize {
    var index = start;
    while (index < line.len and isIdentifierContinue(line[index])) : (index += 1) {}
    return index;
}

fn numberEnd(line: []const u8, start: usize) usize {
    var index = start;
    while (index < line.len and (isIdentifierContinue(line[index]) or line[index] == '.')) : (index += 1) {}
    return index;
}

fn isIdentifierStart(byte: u8) bool {
    return switch (byte) {
        'A'...'Z', 'a'...'z', '_' => true,
        else => false,
    };
}

fn isIdentifierContinue(byte: u8) bool {
    return switch (byte) {
        'A'...'Z', 'a'...'z', '0'...'9', '_' => true,
        else => false,
    };
}

fn isDigit(byte: u8) bool {
    return byte >= '0' and byte <= '9';
}

fn isPunctuation(byte: u8) bool {
    return switch (byte) {
        '.', ',', ':', ';', '(', ')', '{', '}', '[', ']', '=', '+', '-', '*', '/', '<', '>', '!', '?', '&', '|', '%' => true,
        else => false,
    };
}

fn isKeyword(word: []const u8) bool {
    return std.mem.eql(u8, word, "const") or
        std.mem.eql(u8, word, "var") or
        std.mem.eql(u8, word, "fn") or
        std.mem.eql(u8, word, "pub") or
        std.mem.eql(u8, word, "export") or
        std.mem.eql(u8, word, "return") or
        std.mem.eql(u8, word, "if") or
        std.mem.eql(u8, word, "else") or
        std.mem.eql(u8, word, "switch") or
        std.mem.eql(u8, word, "while") or
        std.mem.eql(u8, word, "for") or
        std.mem.eql(u8, word, "defer") or
        std.mem.eql(u8, word, "try") or
        std.mem.eql(u8, word, "catch") or
        std.mem.eql(u8, word, "orelse") or
        std.mem.eql(u8, word, "struct") or
        std.mem.eql(u8, word, "enum") or
        std.mem.eql(u8, word, "union");
}

fn isTypeWord(word: []const u8) bool {
    return std.mem.eql(u8, word, "usize") or
        std.mem.eql(u8, word, "u8") or
        std.mem.eql(u8, word, "u16") or
        std.mem.eql(u8, word, "u32") or
        std.mem.eql(u8, word, "u64") or
        std.mem.eql(u8, word, "i32") or
        std.mem.eql(u8, word, "f32") or
        std.mem.eql(u8, word, "bool") or
        std.mem.eql(u8, word, "void") or
        std.mem.eql(u8, word, "anyerror");
}

fn progressColor(progress: f32) ui.Color {
    if (progress >= 1.0) return palette.primary;
    if (progress > 0.0) return palette.cyan;
    return palette.muted;
}

fn lineNumberLabel(slot: usize, line_number: usize) []const u8 {
    if (slot >= line_number_labels.len) return "";
    return std.fmt.bufPrint(&line_number_labels[slot], "{d}", .{line_number}) catch "";
}

fn editorInfoLabel(state: State) []const u8 {
    const line = lineIndexAt(state.source, state.cursor) + 1;
    const column = state.cursor - lineStartAt(state.source, line - 1) + 1;
    const lines = lineCount(state.source);
    return std.fmt.bufPrint(&editor_info_label, "Ln {d}, Col {d} | {d} lines | file {d} B | workspace {d} B | release {d} B", .{
        line,
        column,
        lines,
        state.file_bytes,
        state.workspace_bytes,
        state.release_bytes,
    }) catch "";
}

fn lineEnd(source: []const u8, start: usize) usize {
    if (start >= source.len) return source.len;
    return start + (std.mem.indexOfScalar(u8, source[start..], '\n') orelse (source.len - start));
}

fn lineIndexAt(source: []const u8, cursor: usize) usize {
    const clamped = @min(cursor, source.len);
    var line: usize = 0;
    for (source[0..clamped]) |byte| {
        if (byte == '\n') line += 1;
    }
    return line;
}

fn lineStartAt(source: []const u8, target_line: usize) usize {
    var line: usize = 0;
    var index: usize = 0;
    while (index < source.len and line < target_line) : (index += 1) {
        if (source[index] == '\n') line += 1;
    }
    return index;
}

fn lineCount(source: []const u8) usize {
    if (source.len == 0) return 1;
    var lines: usize = 1;
    for (source) |byte| {
        if (byte == '\n') lines += 1;
    }
    return lines;
}

fn fill(scene: *ui.Scene, bounds: ui.Rect, color: ui.Color, r: f32) ui.RenderError!void {
    try scene.pushRect(bounds, color, .fill, r, 0.0);
}

fn stroke(scene: *ui.Scene, bounds: ui.Rect, color: ui.Color, r: f32) ui.RenderError!void {
    try scene.pushRect(bounds, color, .border, r, 1.0);
}

fn text(scene: *ui.Scene, x: f32, y: f32, w: f32, h: f32, value: []const u8, color: ui.Color) ui.RenderError!void {
    try scene.pushAlignedText(ui.Rect.init(x, y, @max(1.0, w), @max(1.0, h)), value, color, .start);
}

test "source page renders editor controls through shared ui" {
    var commands: [256]ui.Command = undefined;
    var clips: [8]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var regions: [32]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    try render(&scene, &collector, ui.Rect.init(0, 0, 1280, contentHeight(1280.0, .{})), .{
        .label = "src/app_runtime.zig",
        .source = "const std = @import(\"std\");\n",
        .workspace_bytes = 2048,
        .file_bytes = 28,
        .release_bytes = 4096,
        .status = "ready: editing src/app_runtime.zig inside the app-owned VFS object",
    });
    try expectHit(collector.written(), compile_button_id);
    try expectHit(collector.written(), download_button_id);
    try expectHit(collector.written(), launch_button_id);
    try expectHit(collector.written(), reset_button_id);
}

test "source page does not claim empty workspace is loaded" {
    var commands: [256]ui.Command = undefined;
    var clips: [8]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var regions: [32]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    try render(&scene, &collector, ui.Rect.init(0, 0, 1280, contentHeight(1280.0, .{})), .{
        .label = "src/app_runtime.zig",
        .status = "source editor not loaded",
    });

    try expectNoHit(collector.written(), compile_button_id);
    try expectNoHit(collector.written(), download_button_id);
    try expectNoHit(collector.written(), launch_button_id);
    try expectHit(collector.written(), reset_button_id);
}

test "source compact toolbar keeps action hits separated" {
    var commands: [256]ui.Command = undefined;
    var clips: [8]ui.Rect = undefined;
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var regions: [32]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    try render(&scene, &collector, ui.Rect.init(0, 0, 390, contentHeight(390.0, .{})), .{
        .label = "src/app.zig",
        .source = "pub fn main() void {}\n",
        .workspace_bytes = 2048,
        .file_bytes = 22,
        .release_bytes = 4096,
        .status = "ready: editing src/app_runtime.zig inside the app-owned VFS object",
    });

    try expectNoHorizontalOverlap(try hitRect(collector.written(), compile_button_id), try hitRect(collector.written(), download_button_id));
    try expectNoHorizontalOverlap(try hitRect(collector.written(), download_button_id), try hitRect(collector.written(), launch_button_id));
    try expectNoHorizontalOverlap(try hitRect(collector.written(), launch_button_id), try hitRect(collector.written(), reset_button_id));
}

test "source page height responds to source and diagnostic content" {
    const long_source =
        "a\n" ++ "a\n" ++ "a\n" ++ "a\n" ++ "a\n" ++ "a\n" ++
        "a\n" ++ "a\n" ++ "a\n" ++ "a\n" ++ "a\n" ++ "a\n" ++
        "a\n" ++ "a\n" ++ "a\n" ++ "a\n" ++ "a\n" ++ "a\n" ++
        "a\n" ++ "a\n" ++ "a\n" ++ "a\n" ++ "a\n" ++ "a\n" ++
        "a\n" ++ "a\n" ++ "a\n" ++ "a\n" ++ "a\n" ++ "a\n" ++
        "a\n" ++ "a\n" ++ "a\n" ++ "a\n" ++ "a\n" ++ "a\n";
    const short = State{ .source = "pub fn main() void {}\n" };
    const long = State{ .source = long_source };
    const diagnostic = State{ .source = "pub fn main() void {}\n", .diagnostic = "compile error" };

    try std.testing.expect(editorHeight(1180.0, long) > editorHeight(1180.0, short));
    try std.testing.expect(statusHeight(1180.0, diagnostic) > statusHeight(1180.0, short));
    try std.testing.expect(toolbarHeight(390.0) > toolbarHeight(1280.0));
}

fn expectHit(regions: []const interaction.Region, id: u32) !void {
    for (regions) |region| if (region.id == id) return;
    return error.MissingHit;
}

fn expectNoHit(regions: []const interaction.Region, id: u32) !void {
    for (regions) |region| if (region.id == id) return error.UnexpectedHit;
}

fn hitRect(regions: []const interaction.Region, id: u32) !ui.Rect {
    for (regions) |region| if (region.id == id) return region.bounds;
    return error.MissingHit;
}

fn expectNoHorizontalOverlap(left: ui.Rect, right: ui.Rect) !void {
    try std.testing.expect(left.x + left.w <= right.x or right.x + right.w <= left.x);
}
