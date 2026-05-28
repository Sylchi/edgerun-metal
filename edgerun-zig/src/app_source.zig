const std = @import("std");
const app_chrome = @import("app_chrome.zig");
const app_design = @import("app_design.zig");
const icon_component = @import("ui/components/Icon.zig");
const button_component = @import("ui/components/Button.zig");
const component_common = @import("ui_component_common.zig");
const interaction = @import("ui_interaction.zig");
const ui = @import("ui.zig");

pub const compile_button_id: u32 = 32_001;
pub const download_button_id: u32 = 32_002;
pub const launch_button_id: u32 = 32_003;
pub const reset_button_id: u32 = 32_004;

pub const State = struct {
    scroll_y: f32 = 0.0,
    hover_x: f32 = -1.0,
    hover_y: f32 = -1.0,
    label: []const u8 = "",
    search_query: []const u8 = "",
    files: []const FileEntry = &.{},
    source: []const u8 = "",
    cursor: usize = 0,
    selection_anchor: usize = 0,
    selection_active: bool = false,
    scroll_line: usize = 0,
    workspace_bytes: usize = 0,
    file_bytes: usize = 0,
    release_bytes: usize = 0,
    resource_memory_bytes: usize = 0,
    resource_cpu_instructions: u64 = 0,
    dirty: bool = false,
    can_undo: bool = false,
    can_redo: bool = false,
    status: []const u8 = "",
    compile_phase: []const u8 = "",
    compile_progress: f32 = 0.0,
    compile_summary: []const u8 = "",
    diagnostic: []const u8 = "",
    diagnostic_line: usize = 0,
};

pub const FileEntry = struct {
    label: []const u8,
    dirty: bool = false,
};

const sidebar_w: f32 = 260.0;
const gutter_w: f32 = 56.0;
const code_pad: f32 = 18.0;
const code_gutter_w: f32 = 52.0;
const code_line_h: f32 = 20.0;
const code_char_w: f32 = 8.4;
const toolbar_h: f32 = 52.0;
const status_h: f32 = 24.0;
const panel_bg = ui.Color{ .r = 12, .g = 16, .b = 23 };
const sidebar_bg = ui.Color{ .r = 18, .g = 23, .b = 33 };
const border = ui.Color{ .r = 42, .g = 52, .b = 68 };
const text = ui.Color{ .r = 230, .g = 237, .b = 247 };
const muted = ui.Color{ .r = 140, .g = 155, .b = 178 };
const accent = ui.Color{ .r = 76, .g = 195, .b = 255 };
const code_bg = ui.Color{ .r = 8, .g = 12, .b = 18 };
const code_line = ui.Color{ .r = 194, .g = 203, .b = 216 };
const code_comment = ui.Color{ .r = 102, .g = 133, .b = 157 };
const code_keyword = ui.Color{ .r = 121, .g = 182, .b = 255 };
const code_string = ui.Color{ .r = 150, .g = 217, .b = 162 };
const code_number = ui.Color{ .r = 249, .g = 202, .b = 107 };
const error_color = ui.Color{ .r = 248, .g = 113, .b = 113 };

pub fn contentHeight(width: f32, state: State) f32 {
    _ = width;
    const visible_lines = @max(@as(usize, 1), countLines(state.source));
    return toolbar_h + status_h + @as(f32, @floatFromInt(visible_lines)) * code_line_h + 96.0;
}

pub fn renderWorkspaceTopBar(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State) !void {
    try fill(scene, bounds, sidebar_bg, 0.0);
    try fill(scene, ui.Rect.init(bounds.x, bounds.y + bounds.h - 1.0, bounds.w, 1.0), border, 0.0);
    try textAt(scene, bounds.x + 16.0, bounds.y + 16.0, 360.0, 18.0, state.label, text);
    try textAt(scene, bounds.x + 390.0, bounds.y + 17.0, 260.0, 14.0, state.status, muted);

    const button_y = bounds.y + 10.0;
    var x = bounds.x + bounds.w - 408.0;
    try button(scene, collector, ui.Rect.init(x, button_y, 92.0, 32.0), "Compile", compile_button_id, .primary, icon_component.Icon.named(.play), canCompile(state));
    x += 100.0;
    try button(scene, collector, ui.Rect.init(x, button_y, 92.0, 32.0), "Export", download_button_id, .secondary, icon_component.Icon.named(.download), canExport(state));
    x += 100.0;
    try button(scene, collector, ui.Rect.init(x, button_y, 84.0, 32.0), "Launch", launch_button_id, .secondary, icon_component.Icon.named(.external_link), canExport(state));
    x += 92.0;
    try button(scene, collector, ui.Rect.init(x, button_y, 84.0, 32.0), "Reset", reset_button_id, .ghost, icon_component.Icon.named(.refresh), true);
}

pub fn renderWorkspaceSidebar(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State) !void {
    try fill(scene, bounds, sidebar_bg, 0.0);
    try fill(scene, ui.Rect.init(bounds.x + bounds.w - 1.0, bounds.y, 1.0, bounds.h), border, 0.0);
    try textAt(scene, bounds.x + 16.0, bounds.y + 14.0, bounds.w - 32.0, 16.0, "WORKSPACE", text);
    try textAt(scene, bounds.x + 16.0, bounds.y + 36.0, bounds.w - 32.0, 14.0, formatBytes(state.workspace_bytes), muted);

    var y = bounds.y + 70.0;
    for (state.files, 0..) |file, index| {
        const row = ui.Rect.init(bounds.x + 8.0, y, bounds.w - 16.0, 38.0);
        try fill(scene, row, if (std.mem.eql(u8, file.label, state.label)) ui.Color{ .r = 34, .g = 47, .b = 66 } else ui.Color.clear, 8.0);
        try textAt(scene, row.x + 10.0, row.y + 9.0, row.w - 20.0, 16.0, file.label, if (file.dirty) accent else text);
        try collector.addHit(row, .row_item, @intCast(40_000 + index));
        y += 42.0;
    }
}

pub fn renderWorkspaceStatus(scene: *ui.Scene, bounds: ui.Rect, state: State) !void {
    try fill(scene, bounds, ui.Color{ .r = 0, .g = 92, .b = 160 }, 0.0);
    var status_buf: [192]u8 = undefined;
    const status = std.fmt.bufPrint(&status_buf, "{s} | file {s} | release {s} | memory {s} | instructions {}", .{
        state.compile_phase,
        formatBytes(state.file_bytes),
        formatBytes(state.release_bytes),
        formatBytes(state.resource_memory_bytes),
        state.resource_cpu_instructions,
    }) catch state.compile_phase;
    try textAt(scene, bounds.x + 12.0, bounds.y + 5.0, bounds.w - 24.0, 14.0, status, ui.Color{ .r = 255, .g = 255, .b = 255 });
}

pub fn renderWorkspace(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State) !void {
    try fill(scene, bounds, panel_bg, 0.0);
    const toolbar = ui.Rect.init(bounds.x, bounds.y, bounds.w, toolbar_h);
    const editor = ui.Rect.init(bounds.x, bounds.y + toolbar_h, bounds.w, @max(1.0, bounds.h - toolbar_h - status_h));
    const status = ui.Rect.init(bounds.x, bounds.y + bounds.h - status_h, bounds.w, status_h);
    try renderEditorToolbar(scene, toolbar, state);
    try renderCodeEditor(scene, collector, editor, state);
    try renderWorkspaceStatus(scene, status, state);
}

fn renderEditorToolbar(scene: *ui.Scene, bounds: ui.Rect, state: State) !void {
    try fill(scene, bounds, sidebar_bg, 0.0);
    try fill(scene, ui.Rect.init(bounds.x, bounds.y + bounds.h - 1.0, bounds.w, 1.0), border, 0.0);
    try textAt(scene, bounds.x + 18.0, bounds.y + 11.0, 420.0, 18.0, state.label, text);
    try textAt(scene, bounds.x + 18.0, bounds.y + 31.0, 600.0, 13.0, sourceSummary(state), muted);
    if (state.compile_progress > 0.0 and state.compile_progress < 1.0) {
        const track = ui.Rect.init(bounds.x + bounds.w - 220.0, bounds.y + 22.0, 180.0, 6.0);
        try fill(scene, track, ui.Color{ .r = 36, .g = 48, .b = 64 }, 3.0);
        try fill(scene, ui.Rect.init(track.x, track.y, track.w * state.compile_progress, track.h), accent, 3.0);
    }
}

fn renderCodeEditor(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State) !void {
    try fill(scene, bounds, code_bg, 0.0);
    try collector.addHit(bounds, .textarea, 45_000);
    const first_line = state.scroll_line;
    const visible_lines = @max(@as(usize, 1), @as(usize, @intFromFloat(@max(1.0, bounds.h / code_line_h))));
    var line_index: usize = 0;
    var byte_index: usize = 0;
    var y = bounds.y;
    var rendered: usize = 0;
    while (byte_index <= state.source.len and rendered < visible_lines) {
        const line_start = byte_index;
        while (byte_index < state.source.len and state.source[byte_index] != '\n') : (byte_index += 1) {}
        const line_end = byte_index;
        const next_index = if (byte_index < state.source.len) byte_index + 1 else state.source.len + 1;
        if (line_index >= first_line) {
            try renderCodeLine(scene, bounds, y, line_index + 1, state.source[line_start..line_end], state, line_start, line_end);
            y += code_line_h;
            rendered += 1;
        }
        if (byte_index >= state.source.len) break;
        byte_index = next_index;
        line_index += 1;
    }
}

fn renderCodeLine(scene: *ui.Scene, code_view: ui.Rect, y: f32, line_no: usize, line: []const u8, state: State, line_start: usize, line_end: usize) !void {
    const gutter = ui.Rect.init(code_view.x, y, code_gutter_w, code_line_h);
    try fill(scene, gutter, ui.Color{ .r = 10, .g = 14, .b = 20 }, 0.0);
    var num_buf: [16]u8 = undefined;
    const number = std.fmt.bufPrint(&num_buf, "{}", .{line_no}) catch "";
    try textAt(scene, gutter.x + 8.0, y + 3.0, gutter.w - 16.0, 14.0, number, ui.Color{ .r = 80, .g = 96, .b = 118 });
    try renderSelectionForLine(scene, code_view, y, line_start, line_end, state);
    try renderCodeTokens(scene, code_view.x + code_gutter_w + code_pad, y + 2.0, line);
    try renderCursorForLine(scene, code_view, y, line_start, line_end, state);
}

fn renderCodeTokens(scene: *ui.Scene, x: f32, y: f32, line: []const u8) !void {
    var cursor_x = x;
    var i: usize = 0;
    while (i < line.len) {
        const start = i;
        const color = tokenColor(line, &i);
        const text_slice = line[start..i];
        try textAt(scene, cursor_x, y, @as(f32, @floatFromInt(text_slice.len)) * code_char_w + 4.0, 16.0, text_slice, color);
        cursor_x += codeColumnWidth(line[0..i], i - start);
    }
}

fn tokenColor(line: []const u8, index: *usize) ui.Color {
    const i = index.*;
    if (i >= line.len) return code_line;
    const c = line[i];
    if (c == '/' and i + 1 < line.len and line[i + 1] == '/') {
        index.* = line.len;
        return code_comment;
    }
    if (c == '"') {
        index.* += 1;
        while (index.* < line.len and line[index.*] != '"') : (index.* += 1) {}
        if (index.* < line.len) index.* += 1;
        return code_string;
    }
    if (isDigit(c)) {
        while (index.* < line.len and isDigit(line[index.*])) : (index.* += 1) {}
        return code_number;
    }
    if (isIdentStart(c)) {
        while (index.* < line.len and isIdentContinue(line[index.*])) : (index.* += 1) {}
        const word = line[i..index.*];
        if (isKeyword(word)) return code_keyword;
        return code_line;
    }
    index.* += 1;
    return code_line;
}

fn renderCursorForLine(scene: *ui.Scene, code_view: ui.Rect, y: f32, line_start: usize, line_end: usize, state: State) !void {
    if (state.cursor < line_start or state.cursor > line_end) return;
    const line = state.source[line_start..line_end];
    const offset = codeColumnWidth(line, state.cursor - line_start);
    try fill(scene, ui.Rect.init(code_view.x + code_pad + code_gutter_w + offset, y + 2.0, 1.5, code_line_h - 4.0), accent, 0.0);
}

fn renderSelectionForLine(scene: *ui.Scene, code_view: ui.Rect, y: f32, line_start: usize, visible_end: usize, state: State) !void {
    if (!state.selection_active or state.selection_anchor == state.cursor) return;
    const selection = selectionBounds(state);
    const start = @max(selection.start, line_start);
    const end = @min(selection.end, visible_end);
    if (start >= end) return;
    const line = state.source[line_start..visible_end];
    const start_offset = codeColumnWidth(line, start - line_start);
    const end_offset = codeColumnWidth(line, end - line_start);
    const x = code_view.x + code_pad + code_gutter_w + start_offset;
    const w = @max(2.0, end_offset - start_offset);
    try fill(scene, ui.Rect.init(x, y, w, code_line_h), ui.Color{ .r = 9, .g = 71, .b = 113, .a = 210 }, 0.0);
}

fn button(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, label: []const u8, id: u32, variant: component_common.ButtonVariant, leading: icon_component.Icon, enabled: bool) !void {
    const component = button_component.Button{ .id = id, .label = label, .variant = variant, .icon_slot = icon_component.IconSlot.of(.leading, leading) };
    if (!enabled) {
        try component.render(scene, bounds, .{
            .style = app_design.style(),
            .control = .{ .disabled = true },
        });
        return;
    }
    try component.render(scene, bounds, .{ .style = app_design.style() });
    try component.collectInteractions(collector, bounds);
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
    return std.mem.startsWith(u8, status, "error:");
}

fn sourceSummary(state: State) []const u8 {
    _ = state;
    return "canonical workspace is edited in-memory and compiled to a release artifact";
}

fn selectionBounds(state: State) struct { start: usize, end: usize } {
    return if (state.selection_anchor < state.cursor) .{ .start = state.selection_anchor, .end = state.cursor } else .{ .start = state.cursor, .end = state.selection_anchor };
}

fn codeColumnWidth(line: []const u8, count: usize) f32 {
    var width: f32 = 0;
    var i: usize = 0;
    while (i < count and i < line.len) : (i += 1) width += if (line[i] == '\t') code_char_w * 4.0 else code_char_w;
    return width;
}

fn countLines(text_value: []const u8) usize {
    var count: usize = 1;
    for (text_value) |c| if (c == '\n') count += 1;
    return count;
}

fn formatBytes(value: usize) []const u8 {
    var buf: [32]u8 = undefined;
    if (value < 1024) return std.fmt.bufPrint(&buf, "{} B", .{value}) catch "0 B";
    if (value < 1024 * 1024) return std.fmt.bufPrint(&buf, "{} KB", .{value / 1024}) catch "0 KB";
    return std.fmt.bufPrint(&buf, "{} MB", .{value / (1024 * 1024)}) catch "0 MB";
}

fn fill(scene: *ui.Scene, bounds: ui.Rect, color: ui.Color, radius: f32) ui.RenderError!void {
    try scene.pushRect(bounds, color, .fill, radius, 0.0);
}

fn textAt(scene: *ui.Scene, x: f32, y: f32, w: f32, h: f32, value: []const u8, color: ui.Color) ui.RenderError!void {
    try scene.pushText(ui.Rect.init(x, y, w, h), value, color);
}

fn isKeyword(word: []const u8) bool {
    const keywords = [_][]const u8{ "fn", "let", "const", "var", "type", "pub", "return", "if", "else", "while", "for", "in", "match", "struct", "enum", "union", "import", "export" };
    for (keywords) |keyword| if (std.mem.eql(u8, word, keyword)) return true;
    return false;
}

fn isDigit(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn isIdentStart(c: u8) bool {
    return std.ascii.isAlphabetic(c) or c == '_';
}

fn isIdentContinue(c: u8) bool {
    return isIdentStart(c) or isDigit(c);
}
