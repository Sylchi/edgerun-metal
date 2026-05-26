const std = @import("std");
const interaction = @import("ui_interaction.zig");
const ui = @import("ui.zig");
const button_component = @import("ui/components/Button.zig");
const icon_component = @import("ui/components/Icon.zig");
const progress_component = @import("ui/components/Progress.zig");
const row_item_component = @import("ui/components/RowItem.zig");
const textarea_component = @import("ui/components/Textarea.zig");
const component_common = @import("ui_component_common.zig");
const app_chrome = @import("app_chrome.zig");
const design = @import("app_design.zig");
const app_layout = @import("app_layout.zig");

pub const compile_button_id: u32 = 32_001;
pub const download_button_id: u32 = 32_002;
pub const launch_button_id: u32 = 32_003;
pub const reset_button_id: u32 = 32_004;
pub const editor_textarea_id: u32 = 32_101;
pub const explorer_file_id_base: u32 = 32_200;

const header_h: f32 = app_chrome.header_h;
const source_content_wide: f32 = 1600.0;
const content_pad: f32 = design.content_pad;
const page_top_pad: f32 = 16.0;
const page_bottom_pad: f32 = 48.0;
const panel_radius: f32 = 6.0;
const panel_pad: f32 = 14.0;
const command_bar_h: f32 = 48.0;
const command_bar_compact_h: f32 = 92.0;
const toolbar_label_h: f32 = 16.0;
const toolbar_detail_h: f32 = 14.0;
const toolbar_action_gap: f32 = 10.0;
const source_action_h: f32 = design.compact_control_h + 2.0;
const source_action_min_w: f32 = 132.0;
const compiler_panel_h: f32 = 72.0;
const compiler_title_h: f32 = 16.0;
const compiler_text_h: f32 = 14.0;
const compiler_bar_h: f32 = 8.0;
const compiler_stage_h: f32 = 16.0;
const compiler_diagnostic_h: f32 = 14.0;
const compiler_text_average_w: f32 = 8.6;
const code_pad: f32 = 18.0;
const code_line_h: f32 = 18.0;
const code_gutter_w: f32 = 68.0;
const code_char_w: f32 = 10.4;
const editor_status_h: f32 = 24.0;
const editor_titlebar_h: f32 = 34.0;
const editor_breadcrumb_h: f32 = 26.0;
const activity_rail_w: f32 = 48.0;
const explorer_w: f32 = 250.0;
const minimap_w: f32 = 88.0;
const minimap_gap: f32 = 14.0;
const explorer_threshold_w: f32 = 900.0;
const minimap_threshold_w: f32 = 1180.0;
const explorer_row_h: f32 = 24.0;
const explorer_heading_h: f32 = 30.0;
const compile_stage_count: usize = 4;
const compact_w: f32 = 720.0;
const max_rendered_lines: usize = 40;
const min_editor_lines_compact: usize = 18;
const min_editor_lines_wide: usize = 24;
const max_editor_lines_compact: usize = 28;
const max_editor_lines_wide: usize = 40;
const line_number_label_bytes: usize = 8;
const editor_info_label_bytes: usize = 96;
const explorer_file_count: usize = 4;

const EditorChrome = struct {
    titlebar: bool = true,
    toolbar: bool = true,
    activity: bool = true,
    explorer: bool = true,
    status_bar: bool = true,
    rounded: bool = true,
};

pub const FileEntry = struct {
    path: []const u8,
};

const palette = design.palette;
const fill = app_layout.fill;
const stroke = app_layout.stroke;
const text = app_layout.text;
const wrappedText = app_layout.wrappedTextWith;
const syntax_keyword = ui.Color{ .r = 125, .g = 211, .b = 252 };
const syntax_type = ui.Color{ .r = 196, .g = 181, .b = 253 };
const syntax_string = ui.Color{ .r = 134, .g = 239, .b = 172 };
const syntax_number = ui.Color{ .r = 253, .g = 186, .b = 116 };
const syntax_comment = ui.Color{ .r = 113, .g = 113, .b = 122 };
const syntax_builtin = ui.Color{ .r = 252, .g = 211, .b = 77 };
const syntax_punctuation = ui.Color{ .r = 148, .g = 163, .b = 184 };
const active_line = ui.Color{ .r = 22, .g = 30, .b = 38 };
const gutter_bg = ui.Color{ .r = 10, .g = 12, .b = 16 };
const status_bg = ui.Color{ .r = 0, .g = 122, .b = 204 };
const vscode_titlebar = ui.Color{ .r = 30, .g = 30, .b = 30 };
const vscode_activity = ui.Color{ .r = 37, .g = 37, .b = 38 };
const vscode_sidebar = ui.Color{ .r = 24, .g = 24, .b = 24 };
const vscode_editor = ui.Color{ .r = 30, .g = 30, .b = 30 };
const vscode_tab = ui.Color{ .r = 30, .g = 30, .b = 30 };
const vscode_tab_inactive = ui.Color{ .r = 45, .g = 45, .b = 45 };
const vscode_line = ui.Color{ .r = 63, .g = 63, .b = 70 };
const vscode_selection = ui.Color{ .r = 9, .g = 71, .b = 113 };
const vscode_status_text = ui.Color{ .r = 255, .g = 255, .b = 255 };

var line_number_labels: [max_rendered_lines][line_number_label_bytes]u8 = undefined;
var editor_info_label: [editor_info_label_bytes]u8 = undefined;

const explorer_files = [_][]const u8{
    "src/app_runtime.zig",
    "src/app_source.zig",
    "src/ui/components/Component.zig",
    "src/render/font_atlas.zig",
};

const default_file_entries = [_]FileEntry{
    .{ .path = explorer_files[0] },
    .{ .path = explorer_files[1] },
    .{ .path = explorer_files[2] },
    .{ .path = explorer_files[3] },
};

pub const State = struct {
    scroll_y: f32 = 0.0,
    hover_x: f32 = -1.0,
    hover_y: f32 = -1.0,
    label: []const u8 = "",
    files: []const FileEntry = &.{},
    source: []const u8 = "",
    cursor: usize = 0,
    selection_anchor: usize = 0,
    selection_active: bool = false,
    scroll_line: usize = 0,
    workspace_bytes: usize = 0,
    file_bytes: usize = 0,
    release_bytes: usize = 0,
    dirty: bool = false,
    can_undo: bool = false,
    can_redo: bool = false,
    status: []const u8 = "",
    compile_phase: []const u8 = "idle",
    compile_progress: f32 = 0.0,
    compile_summary: []const u8 = "",
    diagnostic: []const u8 = "",
    diagnostic_line: usize = 0,
};

pub fn contentHeight(width: f32, state: State) f32 {
    const content_w = @min(source_content_wide, @max(1.0, width - content_pad * 2.0));
    return header_h + page_top_pad + editorHeight(content_w, state) + page_bottom_pad;
}

pub fn render(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State) !void {
    const content_w = @min(source_content_wide, @max(1.0, bounds.w - content_pad * 2.0));
    const content = ui.Rect.init(bounds.x + (bounds.w - content_w) * 0.5, bounds.y, content_w, header_h);
    try fill(scene, bounds, palette.bg, 0.0);

    const top = bounds.y + header_h + page_top_pad - state.scroll_y;
    const editor = ui.Rect.init(content.x, top, content.w, editorHeight(content.w, state));
    try renderEditor(scene, collector, editor, state);

    try app_chrome.renderHeader(scene, collector, ui.Rect.init(bounds.x, bounds.y, bounds.w, header_h), content, .source);
}

pub fn renderWorkspace(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State) !void {
    try fill(scene, bounds, palette.bg, 0.0);
    try renderEditorWithChrome(scene, collector, bounds, state, .{
        .titlebar = false,
        .toolbar = false,
        .activity = false,
        .explorer = false,
        .status_bar = false,
        .rounded = false,
    });
}

pub fn renderWorkspaceTopBar(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State) !void {
    try renderToolbar(scene, collector, bounds, state);
}

pub fn renderWorkspaceSidebar(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State) !void {
    try renderExplorer(scene, collector, bounds, state);
}

pub fn renderWorkspaceStatus(scene: *ui.Scene, bounds: ui.Rect, state: State) !void {
    try renderEditorStatus(scene, bounds, state);
}

fn renderToolbar(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State) !void {
    try fill(scene, bounds, vscode_titlebar, 0.0);
    try stroke(scene, ui.Rect.init(bounds.x, bounds.y + bounds.h - 1.0, bounds.w, 1.0), vscode_line, 0.0);
    const text_w = toolbarTextWidth(bounds);
    try icon_component.Icon.named(.app).renderColor(scene, ui.Rect.init(bounds.x + panel_pad, bounds.y + 14.0, 18.0, 18.0), palette.primary);
    try text(scene, bounds.x + panel_pad + 28.0, bounds.y + 8.0, text_w, toolbar_label_h, "EdgeRun Workspace", palette.primary);
    try text(scene, bounds.x + panel_pad + 28.0, bounds.y + 26.0, text_w, toolbar_detail_h, state.label, palette.text);

    const actions = toolbarActions(bounds);
    try button(scene, collector, actions.compile, "Compile", compile_button_id, .primary, icon_component.Icon.named(.cpu), canCompile(state));
    try button(scene, collector, actions.download, "Export", download_button_id, .secondary, icon_component.Icon.named(.file), canExport(state));
    try button(scene, collector, actions.launch, "Run", launch_button_id, .secondary, icon_component.Icon.named(.send), canRun(state));
    try button(scene, collector, actions.reset, "Reset", reset_button_id, .ghost, icon_component.Icon.named(.trash), true);
}

fn renderEditor(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State) !void {
    try renderEditorWithChrome(scene, collector, bounds, state, .{});
}

fn renderEditorWithChrome(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State, chrome: EditorChrome) !void {
    const radius = if (chrome.rounded) panel_radius else 0.0;
    try fill(scene, bounds, vscode_editor, radius);
    try stroke(scene, bounds, palette.border, radius);
    const titlebar_h = if (chrome.titlebar) editor_titlebar_h else 0.0;
    const command_h = if (chrome.toolbar) toolbarHeight(bounds.w) else 0.0;
    const compiler_h = statusHeight(bounds.w, state);
    const status_bar_h = if (chrome.status_bar) editor_status_h else 0.0;
    const status_y = bounds.y + bounds.h - status_bar_h;
    const compiler_y = @max(bounds.y + titlebar_h + command_h, status_y - compiler_h);
    const body_y = bounds.y + titlebar_h + command_h;
    const body_h = @max(1.0, compiler_y - body_y);
    const show_explorer = chrome.explorer and bounds.w >= explorer_threshold_w;
    const show_minimap = bounds.w >= minimap_threshold_w;
    const activity_width = if (chrome.activity) activity_rail_w else 0.0;
    const explorer_width = if (show_explorer) explorer_w else 0.0;
    const minimap_width = if (show_minimap) minimap_w else 0.0;
    const code_x = bounds.x + activity_width + explorer_width;
    const code_w = @max(1.0, bounds.w - activity_width - explorer_width - minimap_width - minimap_gap);
    const editor_body = ui.Rect.init(code_x, body_y, code_w, body_h);
    const breadcrumb = ui.Rect.init(editor_body.x, editor_body.y, editor_body.w, editor_breadcrumb_h);
    const code_view = ui.Rect.init(editor_body.x, editor_body.y + editor_breadcrumb_h, editor_body.w, @max(1.0, editor_body.h - editor_breadcrumb_h));

    if (chrome.titlebar) try renderEditorTitlebar(scene, ui.Rect.init(bounds.x, bounds.y, bounds.w, titlebar_h), state, activity_width);
    if (chrome.toolbar) try renderToolbar(scene, collector, ui.Rect.init(bounds.x, bounds.y + titlebar_h, bounds.w, command_h), state);
    if (chrome.activity) try renderActivityRail(scene, ui.Rect.init(bounds.x, body_y, activity_rail_w, body_h));
    if (show_explorer) try renderExplorer(scene, collector, ui.Rect.init(bounds.x + activity_width, body_y, explorer_width, body_h), state);
    try fill(scene, code_view, palette.code_bg, 0.0);
    try (textarea_component.Textarea{ .id = editor_textarea_id, .placeholder = "source editor" }).collectInteractions(collector, code_view);
    try renderBreadcrumb(scene, breadcrumb, state);
    try fill(scene, ui.Rect.init(code_view.x, code_view.y, code_pad + code_gutter_w - 10.0, code_view.h), gutter_bg, 0.0);

    const first_line = visibleFirstLine(state, visibleLineCapacity(code_view));
    var line_start = lineStartAt(state.source, first_line);
    var line_number = first_line + 1;
    var rendered: usize = 0;
    var y = code_view.y + code_pad;
    while (rendered < max_rendered_lines and line_start <= state.source.len and y + code_line_h <= code_view.y + code_view.h - code_pad) : (rendered += 1) {
        const line_end = lineEnd(state.source, line_start);
        const line = state.source[line_start..line_end];
        const visible = line[0..@min(line.len, maxVisibleColumns(code_view.w))];
        const is_cursor_line = state.cursor >= line_start and state.cursor <= line_end;
        const is_diagnostic_line = state.diagnostic_line != 0 and state.diagnostic_line == line_number;
        if (is_cursor_line) {
            try fill(scene, ui.Rect.init(code_view.x + code_pad + code_gutter_w - 4.0, y - 1.0, code_view.w - code_pad - code_gutter_w, code_line_h + 2.0), active_line, 0.0);
        }
        if (is_diagnostic_line) try diagnosticMarker(scene, ui.Rect.init(code_view.x + code_pad + code_gutter_w - 16.0, y + 5.0, 6.0, 6.0));
        try renderSelectionForLine(scene, code_view, y, line_start, line_start + visible.len, state);
        try text(scene, code_view.x + 12.0, y, code_gutter_w - 18.0, code_line_h, lineNumberLabel(rendered, line_number), if (is_cursor_line) palette.primary else palette.muted);
        try renderSyntaxLine(scene, code_view.x + code_pad + code_gutter_w, y, code_view.w - code_pad * 2.0 - code_gutter_w, visible);
        if (is_cursor_line) {
            const column = @min(state.cursor - line_start, visible.len);
            const caret_x = code_view.x + code_pad + code_gutter_w + @as(f32, @floatFromInt(column)) * code_char_w;
            try fill(scene, ui.Rect.init(caret_x, y + 2.0, 2.0, code_line_h - 4.0), palette.primary, 0.0);
        }
        y += code_line_h;
        if (line_end == state.source.len) break;
        line_start = line_end + 1;
        line_number += 1;
    }

    if (state.source.len == 0) {
        try text(scene, code_view.x + code_pad + code_gutter_w, code_view.y + code_pad, code_view.w - code_pad * 2.0 - code_gutter_w, code_line_h, emptyEditorLabel(state), emptyEditorColor(state));
    }

    if (show_minimap) try renderMinimap(scene, ui.Rect.init(bounds.x + bounds.w - minimap_w - 10.0, code_view.y + 8.0, minimap_w, @max(1.0, code_view.h - 16.0)), state, visibleLineCapacity(code_view));
    try renderStatus(scene, ui.Rect.init(bounds.x, compiler_y, bounds.w, compiler_h), state);
    if (chrome.status_bar) try renderEditorStatus(scene, ui.Rect.init(bounds.x, status_y, bounds.w, status_bar_h), state);
}

fn renderStatus(scene: *ui.Scene, bounds: ui.Rect, state: State) !void {
    try fill(scene, bounds, vscode_titlebar, 0.0);
    try stroke(scene, ui.Rect.init(bounds.x, bounds.y, bounds.w, 1.0), vscode_line, 0.0);
    const text_w = @max(1.0, bounds.w - panel_pad * 2.0);
    const bar_y = bounds.y + 36.0;
    try text(scene, bounds.x + panel_pad, bounds.y + 10.0, 110.0, compiler_title_h, "Compiler", palette.cyan);
    try text(scene, bounds.x + panel_pad + 112.0, bounds.y + 10.0, @max(1.0, text_w - 112.0), compiler_text_h, state.status, palette.text);
    try text(scene, bounds.x + panel_pad, bounds.y + bounds.h - compiler_text_h - 8.0, text_w, compiler_text_h, state.compile_summary, palette.dim);

    const bar = ui.Rect.init(bounds.x + panel_pad, bar_y, text_w, compiler_bar_h);
    var progress_style = app_chrome.style();
    progress_style.panel = palette.neutral_soft;
    progress_style.accent = progressColor(state.compile_progress);
    try (progress_component.Progress{ .value = state.compile_progress }).render(scene, bar, .{ .style = progress_style });
    try renderCompileStages(scene, ui.Rect.init(bar.x, bar.y - 5.0, bar.w, compiler_stage_h), state.compile_progress);
    if (state.diagnostic.len != 0) {
        try wrappedText(scene, ui.Rect.init(bounds.x + panel_pad, bar.y + compiler_bar_h + 6.0, text_w, compiler_diagnostic_h), state.diagnostic, palette.danger, compiler_diagnostic_h, compiler_text_average_w, 1);
    }
}

fn renderEditorStatus(scene: *ui.Scene, bounds: ui.Rect, state: State) !void {
    try fill(scene, bounds, status_bg, 0.0);
    const info = editorInfoLabel(state);
    try text(scene, bounds.x + 14.0, bounds.y + 5.0, bounds.w - 28.0, 14.0, info, vscode_status_text);
    const dirty_label = editorSaveLabel(state);
    try text(scene, bounds.x + @max(0.0, bounds.w - 112.0), bounds.y + 5.0, 96.0, 14.0, dirty_label, vscode_status_text);
}

fn renderEditorTitlebar(scene: *ui.Scene, bounds: ui.Rect, state: State, activity_width: f32) !void {
    try fill(scene, bounds, vscode_titlebar, panel_radius);
    const tab_x = bounds.x + activity_width;
    const tab_w = @min(260.0, @max(120.0, bounds.w * 0.28));
    try fill(scene, ui.Rect.init(tab_x, bounds.y, tab_w, bounds.h), vscode_tab, 0.0);
    try text(scene, tab_x + 12.0, bounds.y + 9.0, 220.0, 14.0, fileName(state.label), palette.text);
    if (state.dirty) try fill(scene, ui.Rect.init(tab_x + @min(236.0, @max(96.0, bounds.w * 0.28 - 24.0)), bounds.y + 14.0, 6.0, 6.0), palette.amber, 3.0);
    try fill(scene, ui.Rect.init(tab_x, bounds.y + bounds.h - 2.0, tab_w, 2.0), palette.primary, 0.0);
    try fill(scene, ui.Rect.init(tab_x + tab_w, bounds.y, 132.0, bounds.h), vscode_tab_inactive, 0.0);
    try text(scene, tab_x + tab_w + 12.0, bounds.y + 9.0, 112.0, 14.0, "artifact.wasm", palette.muted);
}

fn renderActivityRail(scene: *ui.Scene, bounds: ui.Rect) !void {
    try fill(scene, bounds, vscode_activity, 0.0);
    const icons = [_]icon_component.Icon{ icon_component.Icon.named(.file), icon_component.Icon.named(.search), icon_component.Icon.named(.route), icon_component.Icon.named(.terminal), icon_component.Icon.named(.settings) };
    var y = bounds.y + 14.0;
    for (icons, 0..) |value, index| {
        const color = if (index == 0) palette.text else palette.muted;
        try value.renderColor(scene, ui.Rect.init(bounds.x + 13.0, y, 22.0, 22.0), color);
        y += 44.0;
    }
    try fill(scene, ui.Rect.init(bounds.x, bounds.y + 8.0, 2.0, 34.0), palette.primary, 0.0);
}

fn renderExplorer(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State) !void {
    try fill(scene, bounds, vscode_sidebar, 0.0);
    try stroke(scene, ui.Rect.init(bounds.x + bounds.w - 1.0, bounds.y, 1.0, bounds.h), vscode_line, 0.0);
    try text(scene, bounds.x + 14.0, bounds.y + 10.0, bounds.w - 28.0, 12.0, "EXPLORER", palette.dim);
    try text(scene, bounds.x + 14.0, bounds.y + explorer_heading_h + 8.0, bounds.w - 28.0, 14.0, "EDGERUN-C", palette.text);
    const rows_y = bounds.y + explorer_heading_h + 38.0;
    try explorerRow(scene, bounds.x, rows_y, bounds.w, "src", icon_component.Icon.named(.chevron_right), false);
    const files = explorerFilesForState(state);
    for (files, 0..) |entry, index| {
        const y = rows_y + explorer_row_h * @as(f32, @floatFromInt(index + 1));
        const row_bounds = ui.Rect.init(bounds.x, y, bounds.w, explorer_row_h);
        const path = entry.path;
        try explorerRow(scene, bounds.x, y, bounds.w, fileName(path), icon_component.Icon.named(.file), std.mem.eql(u8, state.label, path));
        try (row_item_component.RowItem{ .id = explorerFileHitId(index), .title = path, .detail = "" }).collectInteractions(collector, row_bounds);
    }
    try text(scene, bounds.x + 14.0, bounds.y + bounds.h - 46.0, bounds.w - 28.0, 12.0, "APP-OWNED VFS", palette.dim);
    try text(scene, bounds.x + 14.0, bounds.y + bounds.h - 26.0, bounds.w - 28.0, 12.0, toolbarDetail(state), toolbarDetailColor(state));
}

fn explorerFilesForState(state: State) []const FileEntry {
    return if (state.files.len == 0) &default_file_entries else state.files;
}

pub fn sourceLabelFromHit(hit_id: u32) ?[]const u8 {
    if (hit_id < explorer_file_id_base) return null;
    const index: usize = @intCast(hit_id - explorer_file_id_base);
    if (index >= explorer_file_count) return null;
    return explorer_files[index];
}

pub fn sourceIndexFromHit(hit_id: u32) ?usize {
    if (hit_id < explorer_file_id_base) return null;
    return @intCast(hit_id - explorer_file_id_base);
}

pub fn cursorFromPoint(bounds: ui.Rect, state: State, x: f32, y: f32) usize {
    const content_w = @min(source_content_wide, @max(1.0, bounds.w - content_pad * 2.0));
    const content = ui.Rect.init(bounds.x + (bounds.w - content_w) * 0.5, bounds.y, content_w, header_h);
    const top = bounds.y + header_h + page_top_pad - state.scroll_y;
    const editor = ui.Rect.init(content.x, top, content.w, editorHeight(content.w, state));
    const code_view = editorCodeView(editor, state);
    const first_line = visibleFirstLine(state, visibleLineCapacity(code_view));
    return textarea_component.cursorFromPoint(state.source, code_view, x, y, .{
        .first_line = first_line,
        .line_height = code_line_h,
        .char_width = code_char_w,
        .gutter_width = code_gutter_w,
        .padding_left = code_pad,
        .padding_top = code_pad,
    });
}

pub fn cursorFromTextAreaBounds(code_view: ui.Rect, state: State, x: f32, y: f32) usize {
    const first_line = visibleFirstLine(state, visibleLineCapacity(code_view));
    return textarea_component.cursorFromPoint(state.source, code_view, x, y, .{
        .first_line = first_line,
        .line_height = code_line_h,
        .char_width = code_char_w,
        .gutter_width = code_gutter_w,
        .padding_left = code_pad,
        .padding_top = code_pad,
    });
}

fn explorerFileHitId(index: usize) u32 {
    return explorer_file_id_base + @as(u32, @intCast(index));
}

fn editorCodeView(bounds: ui.Rect, state: State) ui.Rect {
    const command_h = toolbarHeight(bounds.w);
    const compiler_h = statusHeight(bounds.w, state);
    const status_y = bounds.y + bounds.h - editor_status_h;
    const compiler_y = @max(bounds.y + editor_titlebar_h + command_h, status_y - compiler_h);
    const body_y = bounds.y + editor_titlebar_h + command_h;
    const body_h = @max(1.0, compiler_y - body_y);
    const show_explorer = bounds.w >= explorer_threshold_w;
    const show_minimap = bounds.w >= minimap_threshold_w;
    const explorer_width = if (show_explorer) explorer_w else 0.0;
    const minimap_width = if (show_minimap) minimap_w else 0.0;
    const code_x = bounds.x + activity_rail_w + explorer_width;
    const code_w = @max(1.0, bounds.w - activity_rail_w - explorer_width - minimap_width - minimap_gap);
    const editor_body = ui.Rect.init(code_x, body_y, code_w, body_h);
    return ui.Rect.init(editor_body.x, editor_body.y + editor_breadcrumb_h, editor_body.w, @max(1.0, editor_body.h - editor_breadcrumb_h));
}

fn visibleFirstLine(state: State, visible_lines: usize) usize {
    const max_first = lineCount(state.source) -| visible_lines;
    return @min(state.scroll_line, max_first);
}

fn visibleLineCapacity(code_view: ui.Rect) usize {
    return @min(max_rendered_lines, @max(@as(usize, 1), @as(usize, @intFromFloat(@max(1.0, (code_view.h - code_pad * 2.0) / code_line_h)))));
}

fn explorerRow(scene: *ui.Scene, x: f32, y: f32, w: f32, label: []const u8, icon_value: icon_component.Icon, selected: bool) !void {
    if (selected) try fill(scene, ui.Rect.init(x, y, w, explorer_row_h), vscode_selection, 0.0);
    try icon_value.renderColor(scene, ui.Rect.init(x + 14.0, y + 5.0, 14.0, 14.0), if (selected) palette.text else palette.muted);
    try text(scene, x + 36.0, y + 5.0, w - 44.0, 14.0, label, if (selected) palette.text else palette.dim);
}

fn renderBreadcrumb(scene: *ui.Scene, bounds: ui.Rect, state: State) !void {
    try fill(scene, bounds, vscode_editor, 0.0);
    try stroke(scene, ui.Rect.init(bounds.x, bounds.y + bounds.h - 1.0, bounds.w, 1.0), vscode_line, 0.0);
    try text(scene, bounds.x + 14.0, bounds.y + 7.0, bounds.w - 28.0, 12.0, state.label, palette.dim);
}

fn renderMinimap(scene: *ui.Scene, bounds: ui.Rect, state: State, visible_lines: usize) !void {
    try fill(scene, bounds, ui.Color{ .r = 22, .g = 22, .b = 22, .a = 180 }, 0.0);
    const total_lines = lineCount(state.source);
    const viewport_y = bounds.y + (@as(f32, @floatFromInt(@min(state.scroll_line, total_lines))) / @as(f32, @floatFromInt(@max(total_lines, 1)))) * bounds.h;
    const viewport_h = @max(12.0, (@as(f32, @floatFromInt(@max(visible_lines, 1))) / @as(f32, @floatFromInt(@max(total_lines, 1)))) * bounds.h);
    try fill(scene, ui.Rect.init(bounds.x, viewport_y, bounds.w, @min(bounds.h, viewport_h)), ui.Color{ .r = 38, .g = 79, .b = 120, .a = 150 }, 0.0);
    var y = bounds.y + 6.0;
    var line_start: usize = 0;
    var row: usize = 0;
    while (line_start <= state.source.len and row < max_rendered_lines and y < bounds.y + bounds.h - 4.0) : (row += 1) {
        const line_end_value = lineEnd(state.source, line_start);
        const line_len = line_end_value - line_start;
        const line_w = @min(bounds.w - 12.0, @as(f32, @floatFromInt(line_len)) * 1.2);
        const color = if (line_len == 0) vscode_line else palette.muted;
        try fill(scene, ui.Rect.init(bounds.x + 6.0, y, @max(2.0, line_w), 2.0), color, 0.0);
        if (state.diagnostic_line != 0 and state.diagnostic_line == row + 1) try fill(scene, ui.Rect.init(bounds.x + bounds.w - 8.0, y - 1.0, 4.0, 4.0), palette.danger, 2.0);
        if (line_end_value == state.source.len) break;
        line_start = line_end_value + 1;
        y += 5.0;
    }
}

fn diagnosticMarker(scene: *ui.Scene, bounds: ui.Rect) !void {
    try fill(scene, bounds, palette.danger, 3.0);
}

fn renderSelectionForLine(scene: *ui.Scene, code_view: ui.Rect, y: f32, line_start: usize, visible_end: usize, state: State) !void {
    if (!state.selection_active or state.selection_anchor == state.cursor) return;
    const selection = selectionBounds(state);
    const start = @max(selection.start, line_start);
    const end = @min(selection.end, visible_end);
    if (start >= end) return;
    const x = code_view.x + code_pad + code_gutter_w + @as(f32, @floatFromInt(start - line_start)) * code_char_w;
    const w = @max(2.0, @as(f32, @floatFromInt(end - start)) * code_char_w);
    try fill(scene, ui.Rect.init(x, y, w, code_line_h), ui.Color{ .r = 9, .g = 71, .b = 113, .a = 210 }, 0.0);
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

fn button(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, label: []const u8, id: u32, variant: component_common.ButtonVariant, leading: icon_component.Icon, enabled: bool) !void {
    const component = button_component.Button{ .id = id, .label = label, .variant = variant, .icon_slot = icon_component.IconSlot.of(.leading, leading) };
    if (!enabled) {
        try component.render(scene, bounds, .{
            .style = app_chrome.style(),
            .control = .{ .disabled = true },
        });
        return;
    }
    try component.render(scene, bounds, .{ .style = app_chrome.style() });
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

fn fileName(path: []const u8) []const u8 {
    if (std.mem.lastIndexOfScalar(u8, path, '/')) |index| return path[index + 1 ..];
    return path;
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
    return editor_titlebar_h + toolbarHeight(content_w) + code_pad * 2.0 + @as(f32, @floatFromInt(measured_lines)) * code_line_h + statusHeight(content_w, state) + editor_status_h;
}

fn toolbarHeight(content_w: f32) f32 {
    return if (content_w >= compact_w) command_bar_h else command_bar_compact_h;
}

fn statusHeight(_: f32, state: State) f32 {
    const diagnostic_h = if (state.diagnostic.len == 0) 0.0 else compiler_diagnostic_h;
    return compiler_panel_h + diagnostic_h;
}

fn maxVisibleColumns(width: f32) usize {
    const code_w = @max(1.0, width - code_pad * 2.0 - code_gutter_w);
    return @max(1, @as(usize, @intFromFloat(code_w / code_char_w)));
}

const ToolbarActions = struct {
    compile: ui.Rect,
    download: ui.Rect,
    launch: ui.Rect,
    reset: ui.Rect,
};

fn toolbarTextWidth(bounds: ui.Rect) f32 {
    if (bounds.w < compact_w) return @max(1.0, bounds.w - panel_pad * 2.0);
    const action_w = toolbarActionsWidth(bounds.w);
    return @max(1.0, bounds.w - panel_pad * 3.0 - action_w);
}

fn toolbarActions(bounds: ui.Rect) ToolbarActions {
    const action_area = ui.Rect.init(bounds.x + panel_pad, bounds.y + bounds.h - panel_pad - toolbarActionsHeight(bounds.w), @max(1.0, bounds.w - panel_pad * 2.0), toolbarActionsHeight(bounds.w));
    const compact = bounds.w < compact_w;
    const columns: usize = if (compact and !toolbarActionsFitOneRow(bounds.w)) 2 else 4;
    const layout_w = if (compact) action_area.w else toolbarActionsWidth(bounds.w);
    const button_w = @max(design.min_touch_target, (layout_w - toolbar_action_gap * @as(f32, @floatFromInt(columns - 1))) / @as(f32, @floatFromInt(columns)));
    const row_h = source_action_h;
    const start_x = if (!compact) bounds.x + bounds.w - panel_pad - toolbarActionsWidth(bounds.w) else action_area.x;
    const start_y = if (!compact) bounds.y + (bounds.h - row_h) * 0.5 else action_area.y;
    if (columns == 2) {
        return .{
            .compile = ui.Rect.init(start_x, start_y, button_w, row_h),
            .download = ui.Rect.init(start_x + button_w + toolbar_action_gap, start_y, button_w, row_h),
            .launch = ui.Rect.init(start_x, start_y + row_h + toolbar_action_gap, button_w, row_h),
            .reset = ui.Rect.init(start_x + button_w + toolbar_action_gap, start_y + row_h + toolbar_action_gap, button_w, row_h),
        };
    }
    return .{
        .compile = ui.Rect.init(start_x, start_y, button_w, row_h),
        .download = ui.Rect.init(start_x + button_w + toolbar_action_gap, start_y, button_w, row_h),
        .launch = ui.Rect.init(start_x + (button_w + toolbar_action_gap) * 2.0, start_y, button_w, row_h),
        .reset = ui.Rect.init(start_x + (button_w + toolbar_action_gap) * 3.0, start_y, button_w, row_h),
    };
}

fn toolbarActionsHeight(width: f32) f32 {
    return if (width < compact_w and !toolbarActionsFitOneRow(width)) source_action_h * 2.0 + toolbar_action_gap else source_action_h;
}

fn toolbarActionsWidth(width: f32) f32 {
    const inner_w = @max(1.0, width - panel_pad * 2.0);
    if (width < compact_w) return inner_w;
    return @min(inner_w, source_action_min_w * 4.0 + toolbar_action_gap * 3.0);
}

fn toolbarActionsFitOneRow(width: f32) bool {
    return width - panel_pad * 2.0 >= source_action_min_w * 4.0 + toolbar_action_gap * 3.0;
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

const SelectionBounds = struct {
    start: usize,
    end: usize,
};

fn selectionBounds(state: State) SelectionBounds {
    return if (state.selection_anchor <= state.cursor)
        .{ .start = state.selection_anchor, .end = state.cursor }
    else
        .{ .start = state.cursor, .end = state.selection_anchor };
}

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
    try expectHit(collector.written(), editor_textarea_id);
    try expectHit(collector.written(), explorer_file_id_base);
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
