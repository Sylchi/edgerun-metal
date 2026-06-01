const ui = @import("core.zig");

pub const header_h: f32 = 56.0;
pub const content_pad: f32 = 20.0;
pub const content_wide: f32 = 1180.0;
pub const surface_radius: f32 = 8.0;
pub const workspace_rail_pad: f32 = 12.0;
pub const workspace_icon_button: f32 = 36.0;
pub const workspace_rail_bg = ui.Color{ .r = 37, .g = 37, .b = 38 };
pub const workspace_sidebar_bg = ui.Color{ .r = 24, .g = 24, .b = 24 };
pub const workspace_main_bg = ui.Color{ .r = 10, .g = 12, .b = 16 };
pub const workspace_status_bg = ui.Color{ .r = 0, .g = 122, .b = 204 };

pub const Icon = struct {
    pub const button_box: f32 = 34.0;
    pub const logo_box: f32 = 24.0;
    pub const logo_inset: f32 = 5.0;
};

pub const Type = struct {
    pub const caption_h: f32 = 12.0;
    pub const body_h: f32 = 17.0;
    pub const body_line_h: f32 = 20.0;
    pub const section_h: f32 = 22.0;
    pub const title_h: f32 = 26.0;
    pub const title_line_h: f32 = 46.0;
    pub const code_h: f32 = 13.0;
    pub const average_body_w: f32 = 8.8;
};

pub const Palette = struct {
    pub const bg = ui.Color{ .r = 12, .g = 14, .b = 17 };
    pub const panel = ui.Color{ .r = 22, .g = 25, .b = 30 };
    pub const panel_alt = ui.Color{ .r = 28, .g = 32, .b = 38 };
    pub const panel_floor = ui.Color{ .r = 15, .g = 18, .b = 22 };
    pub const code_bg = ui.Color{ .r = 7, .g = 9, .b = 12 };
    pub const row = ui.Color{ .r = 31, .g = 35, .b = 42 };
    pub const border = ui.Color{ .r = 63, .g = 70, .b = 82 };
    pub const text = ui.Color{ .r = 239, .g = 243, .b = 248 };
    pub const muted = ui.Color{ .r = 158, .g = 168, .b = 180 };
    pub const dim = ui.Color{ .r = 111, .g = 123, .b = 138 };
    pub const active = ui.Color{ .r = 28, .g = 112, .b = 214 };
    pub const accent = ui.Color{ .r = 53, .g = 214, .b = 182 };
    pub const primary = accent;
    pub const danger = ui.Color{ .r = 248, .g = 113, .b = 113 };
    pub const yellow = ui.Color{ .r = 250, .g = 204, .b = 21 };
    pub const cyan = ui.Color{ .r = 34, .g = 211, .b = 238 };
};

pub const UniformGrid = struct {
    bounds: ui.Rect = emptyRect(),
    columns: usize = 0,
    rows: usize = 0,
    cell_w: f32 = 0.0,
    cell_h: f32 = 0.0,
    gap_x: f32 = 0.0,
    gap_y: f32 = 0.0,
};

pub const State = struct {
    pub const hover_border = ui.Color{ .r = 125, .g = 211, .b = 252 };
    pub const active_border = Palette.cyan;
    pub const focus_border = Palette.yellow;
    pub const invalid_border = Palette.danger;
    pub const disabled_tint = ui.Color{ .r = 10, .g = 14, .b = 20, .a = 142 };
    pub const loading_fill = ui.Color{ .r = 45, .g = 212, .b = 191 };
};

pub const Component = struct {
    pub const control_radius: f32 = 6.0;
    pub const focus_ring_outset: f32 = 2.0;
    pub const state_loading_h: f32 = 3.0;
    pub const row_radius: f32 = 4.0;
    pub const control_text_padding: f32 = 12.0;
    pub const control_label_height: f32 = 16.0;
    pub const control_average_char_width: f32 = 8.5;
    pub const surface_radius: f32 = 8.0;
    pub const surface_padding: f32 = 16.0;
    pub const surface_title_height: f32 = 18.0;
    pub const surface_detail_height: f32 = 16.0;
    pub const surface_detail_gap: f32 = 8.0;
    pub const badge_height: f32 = 24.0;
    pub const badge_text_height: f32 = 13.0;
    pub const badge_padding_x: f32 = 12.0;
};

pub fn appStyle() ui.Style {
    return .{
        .bg = Palette.bg,
        .panel = Palette.panel,
        .row = Palette.row,
        .border = Palette.border,
        .text = Palette.text,
        .muted = Palette.muted,
        .accent = Palette.accent,
    };
}

pub fn emptyRect() ui.Rect {
    return ui.Rect.init(0.0, 0.0, 0.0, 0.0);
}

pub fn uniformGrid(bounds: ui.Rect, columns: usize, rows: usize, gap_x: f32, gap_y: f32) UniformGrid {
    var grid = UniformGrid{};
    if (!bounds.valid() or columns == 0 or rows == 0 or gap_x < 0.0 or gap_y < 0.0) return grid;
    const total_gap_x = gap_x * @as(f32, @floatFromInt(columns - 1));
    const total_gap_y = gap_y * @as(f32, @floatFromInt(rows - 1));
    const cell_w = (bounds.w - total_gap_x) / @as(f32, @floatFromInt(columns));
    const cell_h = (bounds.h - total_gap_y) / @as(f32, @floatFromInt(rows));
    if (cell_w <= 0.0 or cell_h <= 0.0) return grid;
    grid.bounds = bounds;
    grid.columns = columns;
    grid.rows = rows;
    grid.cell_w = cell_w;
    grid.cell_h = cell_h;
    grid.gap_x = gap_x;
    grid.gap_y = gap_y;
    return grid;
}

pub fn uniformGridCell(grid: UniformGrid, index: usize) ui.Rect {
    if (grid.columns == 0 or grid.rows == 0 or grid.cell_w <= 0.0 or grid.cell_h <= 0.0 or !grid.bounds.valid()) return emptyRect();
    const column = index % grid.columns;
    const row = index / grid.columns;
    if (row >= grid.rows) return emptyRect();
    return ui.Rect.init(
        grid.bounds.x + (grid.cell_w + grid.gap_x) * @as(f32, @floatFromInt(column)),
        grid.bounds.y + (grid.cell_h + grid.gap_y) * @as(f32, @floatFromInt(row)),
        grid.cell_w,
        grid.cell_h,
    );
}

test "shared ui tokens expose deterministic app style and interaction colors" {
    const value = appStyle();
    if (value.bg != Palette.bg) return error.TestExpectedEqual;
    if (value.accent != Palette.accent) return error.TestExpectedEqual;
    if (State.focus_border != Palette.yellow) return error.TestExpectedEqual;
    if (State.invalid_border != Palette.danger) return error.TestExpectedEqual;
    if (Component.badge_height != 24.0) return error.TestExpectedEqual;
    const grid = uniformGrid(ui.Rect.init(0.0, 0.0, 220.0, 100.0), 2, 1, 20.0, 0.0);
    if (grid.columns != 2) return error.TestExpectedEqual;
    const cell_x = uniformGridCell(grid, 1).x;
    const diff = if (cell_x > 120.0) cell_x - 120.0 else 120.0 - cell_x;
    if (diff > 0.001) return error.TestExpectedApproxEqAbs;
}
