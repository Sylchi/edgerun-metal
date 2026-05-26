const std = @import("std");
const icon = @import("icon.zig");
const interaction = @import("ui_interaction.zig");
const ui = @import("ui.zig");
const components = @import("ui_components.zig");
const site_chrome = @import("site_chrome.zig");

pub const compile_button_id: u32 = 32_001;
pub const download_button_id: u32 = 32_002;
pub const launch_button_id: u32 = 32_003;
pub const reset_button_id: u32 = 32_004;

const header_h: f32 = site_chrome.header_h;
const content_wide: f32 = 1180.0;
const content_pad: f32 = 28.0;
const page_top_pad: f32 = 48.0;
const page_bottom_pad: f32 = 120.0;
const panel_radius: f32 = site_chrome.surface_radius;
const toolbar_h: f32 = 112.0;
const editor_h_wide: f32 = 760.0;
const editor_h_compact: f32 = 620.0;
const status_h: f32 = 116.0;
const gap: f32 = 18.0;
const code_pad: f32 = 18.0;
const code_line_h: f32 = 18.0;
const code_gutter_w: f32 = 56.0;
const code_char_w: f32 = 7.4;
const compact_w: f32 = 720.0;
const max_rendered_lines: usize = 40;

const palette = struct {
    const bg = ui.Color{ .r = 9, .g = 10, .b = 12 };
    const panel = ui.Color{ .r = 18, .g = 19, .b = 22 };
    const panel_alt = ui.Color{ .r = 23, .g = 25, .b = 29 };
    const code_bg = ui.Color{ .r = 6, .g = 7, .b = 9 };
    const border = ui.Color{ .r = 58, .g = 61, .b = 68 };
    const text = ui.Color{ .r = 242, .g = 245, .b = 248 };
    const dim = ui.Color{ .r = 156, .g = 163, .b = 175 };
    const muted = ui.Color{ .r = 101, .g = 109, .b = 122 };
    const primary = ui.Color{ .r = 74, .g = 222, .b = 128 };
    const cyan = ui.Color{ .r = 34, .g = 211, .b = 238 };
    const amber = ui.Color{ .r = 245, .g = 158, .b = 11 };
};

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
};

pub fn contentHeight(width: f32, _: State) f32 {
    const content_w = @min(content_wide, @max(1.0, width - content_pad * 2.0));
    return header_h + page_top_pad + toolbar_h + gap + editorHeight(content_w) + gap + status_h + page_bottom_pad;
}

pub fn render(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State) !void {
    const content_w = @min(content_wide, @max(1.0, bounds.w - content_pad * 2.0));
    const content = ui.Rect.init(bounds.x + (bounds.w - content_w) * 0.5, bounds.y, content_w, header_h);
    try fill(scene, bounds, palette.bg, 0.0);

    const top = bounds.y + header_h + page_top_pad - state.scroll_y;
    const toolbar = ui.Rect.init(content.x, top, content.w, toolbar_h);
    try renderToolbar(scene, collector, toolbar, state);

    const editor = ui.Rect.init(content.x, toolbar.y + toolbar.h + gap, content.w, editorHeight(content.w));
    try renderEditor(scene, editor, state);

    const status = ui.Rect.init(content.x, editor.y + editor.h + gap, content.w, status_h);
    try renderStatus(scene, status, state);

    try site_chrome.renderHeader(scene, collector, ui.Rect.init(bounds.x, bounds.y, bounds.w, header_h), content, .source);
}

fn renderToolbar(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, state: State) !void {
    try fill(scene, bounds, palette.panel, panel_radius);
    try stroke(scene, bounds, palette.border, panel_radius);
    try text(scene, bounds.x + 18.0, bounds.y + 18.0, bounds.w - 36.0, 18.0, "Source workspace", palette.primary);
    try text(scene, bounds.x + 18.0, bounds.y + 44.0, bounds.w - 36.0, 20.0, state.label, palette.text);
    try text(scene, bounds.x + 18.0, bounds.y + 74.0, bounds.w - 36.0, 16.0, if (state.dirty) "edited canonical workspace" else "canonical workspace loaded", if (state.dirty) palette.amber else palette.dim);

    const button_y = bounds.y + 18.0;
    const button_w: f32 = if (bounds.w < compact_w) 92.0 else 132.0;
    const button_gap = 10.0;
    const reset = ui.Rect.init(bounds.x + bounds.w - button_w, button_y, button_w, 34.0);
    const launch = ui.Rect.init(reset.x - button_gap - button_w, button_y, button_w, 34.0);
    const download = ui.Rect.init(launch.x - button_gap - button_w, button_y, button_w, 34.0);
    const compile = ui.Rect.init(download.x - button_gap - button_w, button_y, button_w, 34.0);
    try button(scene, collector, compile, "Compile", compile_button_id, .primary, .cpu);
    try button(scene, collector, download, "Export", download_button_id, .secondary, .file);
    try button(scene, collector, launch, "Run", launch_button_id, .secondary, .send);
    try button(scene, collector, reset, "Reset", reset_button_id, .ghost, .trash);
}

fn renderEditor(scene: *ui.Scene, bounds: ui.Rect, state: State) !void {
    try fill(scene, bounds, palette.code_bg, panel_radius);
    try stroke(scene, bounds, palette.border, panel_radius);

    var line_start: usize = 0;
    var rendered: usize = 0;
    var y = bounds.y + code_pad;
    while (rendered < max_rendered_lines and line_start <= state.source.len and y + code_line_h <= bounds.y + bounds.h - code_pad) : (rendered += 1) {
        const line_end = lineEnd(state.source, line_start);
        const line = state.source[line_start..line_end];
        const visible = line[0..@min(line.len, maxVisibleColumns(bounds.w))];
        try text(scene, bounds.x + code_pad + code_gutter_w, y, bounds.w - code_pad * 2.0 - code_gutter_w, code_line_h, visible, palette.text);
        if (state.cursor >= line_start and state.cursor <= line_end) {
            const column = @min(state.cursor - line_start, visible.len);
            const caret_x = bounds.x + code_pad + code_gutter_w + @as(f32, @floatFromInt(column)) * code_char_w;
            try fill(scene, ui.Rect.init(caret_x, y + 2.0, 2.0, code_line_h - 4.0), palette.primary, 0.0);
        }
        y += code_line_h;
        if (line_end == state.source.len) break;
        line_start = line_end + 1;
    }

    if (state.source.len == 0) {
        try text(scene, bounds.x + code_pad + code_gutter_w, bounds.y + code_pad, bounds.w - code_pad * 2.0 - code_gutter_w, code_line_h, "empty source file", palette.muted);
    }
}

fn renderStatus(scene: *ui.Scene, bounds: ui.Rect, state: State) !void {
    try fill(scene, bounds, palette.panel_alt, panel_radius);
    try stroke(scene, bounds, palette.border, panel_radius);
    try text(scene, bounds.x + 18.0, bounds.y + 18.0, bounds.w - 36.0, 18.0, "Compiler path", palette.cyan);
    try text(scene, bounds.x + 18.0, bounds.y + 44.0, bounds.w - 36.0, 16.0, "The editor writes canonical VFS bytes in wasm memory. Compile consumes that object and emits the release wasm artifact.", palette.dim);
    try text(scene, bounds.x + 18.0, bounds.y + 74.0, bounds.w - 36.0, 16.0, state.status, palette.text);
    _ = state.workspace_bytes;
    _ = state.file_bytes;
    _ = state.release_bytes;
}

fn button(scene: *ui.Scene, collector: *interaction.Collector, bounds: ui.Rect, label: []const u8, id: u32, variant: components.ButtonVariant, leading: icon.Icon) !void {
    try components.renderComponent(scene, bounds, .{ .button = .{ .id = id, .label = label, .variant = variant, .leading_icon = leading } }, .{ .style = site_chrome.style() });
    try components.collectComponentInteractions(collector, bounds, .{ .button = .{ .id = id, .label = label } });
}

fn editorHeight(content_w: f32) f32 {
    return if (content_w < compact_w) editor_h_compact else editor_h_wide;
}

fn maxVisibleColumns(width: f32) usize {
    const code_w = @max(1.0, width - code_pad * 2.0 - code_gutter_w);
    return @max(1, @as(usize, @intFromFloat(code_w / code_char_w)));
}

fn lineEnd(source: []const u8, start: usize) usize {
    if (start >= source.len) return source.len;
    return start + (std.mem.indexOfScalar(u8, source[start..], '\n') orelse (source.len - start));
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
        .label = "src/ui_browser.zig",
        .source = "const std = @import(\"std\");\n",
        .status = "ready",
    });
    try expectHit(collector.written(), compile_button_id);
    try expectHit(collector.written(), download_button_id);
    try expectHit(collector.written(), launch_button_id);
    try expectHit(collector.written(), reset_button_id);
}

fn expectHit(regions: []const interaction.Region, id: u32) !void {
    for (regions) |region| if (region.id == id) return;
    return error.MissingHit;
}
