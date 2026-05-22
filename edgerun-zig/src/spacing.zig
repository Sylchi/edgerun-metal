const std = @import("std");
const geometry = @import("geometry.zig");

pub const Rect = geometry.Rect;

pub const space_1: f32 = 4.0;
pub const space_2: f32 = 6.0;
pub const space_3: f32 = 8.0;
pub const space_4: f32 = 10.0;
pub const space_5: f32 = 12.0;
pub const space_6: f32 = 14.0;
pub const space_7: f32 = 16.0;
pub const space_8: f32 = 18.0;
pub const space_9: f32 = 20.0;
pub const space_10: f32 = 22.0;
pub const space_11: f32 = 24.0;
pub const space_12: f32 = 32.0;
pub const space_13: f32 = 40.0;
pub const space_14: f32 = 48.0;
pub const space_15: f32 = 56.0;
pub const space_16: f32 = 64.0;

pub const card_radius_max = space_6;
pub const card_pad_x = space_11;
pub const card_pad_y = space_11;
pub const component_pad_x_dense = space_5;
pub const component_pad_y_dense = space_4;
pub const component_pad_x = card_pad_x;
pub const component_pad_y = card_pad_y;
pub const component_pad_x_spacious = space_12;
pub const component_pad_y_spacious = space_12;
pub const control_pad_x = space_4;
pub const compact_control_h = space_12;
pub const control_h: f32 = 36.0;
pub const large_control_h = space_13;
pub const row_pad_x = space_6;
pub const row_icon: f32 = 34.0;
pub const row_icon_gap = space_5;
pub const row_text_inset = row_pad_x + row_icon + row_icon_gap;
pub const row_h: f32 = 58.0;
pub const list_row_h = row_h;
pub const menu_row_h = space_14;
pub const command_row_h = space_14;
pub const table_row_h = space_16;
pub const operation_row_h: f32 = 78.0;
pub const narrow_viewport_w: f32 = 520.0;
pub const wide_viewport_w: f32 = 1180.0;
pub const surface_inset_x_narrow = space_4;
pub const surface_inset_y_narrow = space_4;
pub const surface_inset_x = space_6;
pub const surface_inset_y = space_6;
pub const surface_inset_x_wide = space_7;
pub const surface_inset_y_wide = space_7;
pub const surface_viewport_inset = space_4;
pub const surface_panel_gap = space_3;
pub const surface_topbar_h: f32 = 42.0;
pub const workspace_chrome_h: f32 = 34.0;
pub const workspace_gap = space_2;
pub const scrollbar_reserved_w = space_4;
pub const scrollbar_track_w: f32 = 3.0;
pub const scrollbar_hit_w = space_4;
pub const scrollbar_edge_inset = space_2;
pub const min_touch_target: f32 = 32.0;

pub const Density = enum {
    dense,
    default,
    spacious,
};

pub const Padding = struct {
    x: f32,
    y: f32,
};

pub const Tokens = struct {
    card_radius_max: f32,
    card_pad_x: f32,
    card_pad_y: f32,
    component_pad_dense: Padding,
    component_pad: Padding,
    component_pad_spacious: Padding,
    control_pad_x: f32,
    control_h: f32,
    compact_control_h: f32,
    large_control_h: f32,
    row_pad_x: f32,
    row_icon: f32,
    row_icon_gap: f32,
    row_text_inset: f32,
    row_h: f32,
    list_row_h: f32,
    menu_row_h: f32,
    command_row_h: f32,
    table_row_h: f32,
    operation_row_h: f32,
    surface_inset_x: f32,
    surface_inset_y: f32,
    surface_viewport_inset: f32,
    surface_panel_gap: f32,
    surface_topbar_h: f32,
    workspace_chrome_h: f32,
    workspace_gap: f32,
    min_touch_target: f32,
};

pub const ResponsiveGrid = struct {
    bounds: Rect = emptyRect(),
    columns: usize = 0,
    column_w: f32 = 0.0,
    gap_x: f32 = 0.0,
    gap_y: f32 = 0.0,
};

pub const UniformGrid = struct {
    bounds: Rect = emptyRect(),
    columns: usize = 0,
    rows: usize = 0,
    cell_w: f32 = 0.0,
    cell_h: f32 = 0.0,
    gap_x: f32 = 0.0,
    gap_y: f32 = 0.0,
};

pub const ResponsiveSidecar = struct {
    side: Rect = emptyRect(),
    main: Rect = emptyRect(),
    stacked: bool = false,
};

pub const VerticalFlow = struct {
    bounds: Rect = emptyRect(),
    cursor_y: f32 = 0.0,
    gap: f32 = 0.0,

    pub fn next(self: *VerticalFlow, preferred_h: f32) Rect {
        if (preferred_h <= 0.0 or !self.bounds.valid()) return emptyRect();
        const remaining_h = geometry.max(self.bounds.y + self.bounds.h - self.cursor_y, 0.0);
        const height = geometry.min(preferred_h, remaining_h);
        const item = Rect.init(self.bounds.x, self.cursor_y, self.bounds.w, height);
        self.cursor_y += height + self.gap;
        return item;
    }

    pub fn remaining(self: VerticalFlow) Rect {
        if (!self.bounds.valid()) return emptyRect();
        const height = geometry.max(self.bounds.y + self.bounds.h - self.cursor_y, 0.0);
        return Rect.init(self.bounds.x, self.cursor_y, self.bounds.w, height);
    }
};

pub const ScrollViewport = struct {
    viewport: Rect = emptyRect(),
    content: Rect = emptyRect(),
    track: Rect = emptyRect(),
    hit: Rect = emptyRect(),
    thumb: Rect = emptyRect(),
    overflow_h: f32 = 0.0,
    scroll_px: f32 = 0.0,
    scrollable: bool = false,
};

pub fn emptyRect() Rect {
    return Rect.init(0.0, 0.0, 0.0, 0.0);
}

pub fn componentPaddingForDensity(density: Density) Padding {
    return switch (density) {
        .dense => .{ .x = component_pad_x_dense, .y = component_pad_y_dense },
        .spacious => .{ .x = component_pad_x_spacious, .y = component_pad_y_spacious },
        .default => .{ .x = component_pad_x, .y = component_pad_y },
    };
}

pub fn componentContentRect(bounds: Rect, density: Density) Rect {
    const pad = componentPaddingForDensity(density);
    return bounds.inset(pad.x, pad.y);
}

pub fn defaultTokens() Tokens {
    return .{
        .card_radius_max = card_radius_max,
        .card_pad_x = card_pad_x,
        .card_pad_y = card_pad_y,
        .component_pad_dense = componentPaddingForDensity(.dense),
        .component_pad = componentPaddingForDensity(.default),
        .component_pad_spacious = componentPaddingForDensity(.spacious),
        .control_pad_x = control_pad_x,
        .control_h = control_h,
        .compact_control_h = compact_control_h,
        .large_control_h = large_control_h,
        .row_pad_x = row_pad_x,
        .row_icon = row_icon,
        .row_icon_gap = row_icon_gap,
        .row_text_inset = row_text_inset,
        .row_h = row_h,
        .list_row_h = list_row_h,
        .menu_row_h = menu_row_h,
        .command_row_h = command_row_h,
        .table_row_h = table_row_h,
        .operation_row_h = operation_row_h,
        .surface_inset_x = surface_inset_x,
        .surface_inset_y = surface_inset_y,
        .surface_viewport_inset = surface_viewport_inset,
        .surface_panel_gap = surface_panel_gap,
        .surface_topbar_h = surface_topbar_h,
        .workspace_chrome_h = workspace_chrome_h,
        .workspace_gap = workspace_gap,
        .min_touch_target = min_touch_target,
    };
}

pub fn responsiveSidecar(bounds: Rect, min_side_w: f32, preferred_side_w: f32, min_main_w: f32, gap: f32, stacked_side_h: f32) ResponsiveSidecar {
    var layout = ResponsiveSidecar{};
    if (!bounds.valid() or min_side_w <= 0.0 or preferred_side_w < min_side_w or min_main_w <= 0.0 or gap < 0.0 or stacked_side_h <= 0.0) return layout;

    const preferred_total_w = preferred_side_w + gap + min_main_w;
    if (bounds.w >= preferred_total_w) {
        layout.side = Rect.init(bounds.x, bounds.y, preferred_side_w, bounds.h);
        layout.main = Rect.init(bounds.x + preferred_side_w + gap, bounds.y, bounds.w - preferred_side_w - gap, bounds.h);
        return layout;
    }

    const minimum_total_w = min_side_w + gap + min_main_w;
    if (bounds.w >= minimum_total_w) {
        const side_w = geometry.max(min_side_w, bounds.w - gap - min_main_w);
        layout.side = Rect.init(bounds.x, bounds.y, side_w, bounds.h);
        layout.main = Rect.init(bounds.x + side_w + gap, bounds.y, bounds.w - side_w - gap, bounds.h);
        return layout;
    }

    layout.stacked = true;
    const side_h = geometry.min(stacked_side_h, bounds.h);
    const main_y = bounds.y + side_h + gap;
    layout.side = Rect.init(bounds.x, bounds.y, bounds.w, side_h);
    layout.main = Rect.init(bounds.x, main_y, bounds.w, geometry.max(bounds.y + bounds.h - main_y, 0.0));
    return layout;
}

pub fn responsiveGrid(bounds: Rect, min_column_w: f32, max_columns: usize, gap_x: f32, gap_y: f32) ResponsiveGrid {
    var grid = ResponsiveGrid{};
    if (!bounds.valid() or min_column_w <= 0.0 or max_columns == 0 or gap_x < 0.0 or gap_y < 0.0) return grid;
    grid.bounds = bounds;
    grid.columns = 1;
    grid.gap_x = gap_x;
    grid.gap_y = gap_y;
    while (grid.columns < max_columns) {
        const next_columns = grid.columns + 1;
        const required_w = min_column_w * @as(f32, @floatFromInt(next_columns)) + gap_x * @as(f32, @floatFromInt(next_columns - 1));
        if (required_w > bounds.w) break;
        grid.columns = next_columns;
    }
    const total_gap = gap_x * @as(f32, @floatFromInt(grid.columns - 1));
    grid.column_w = geometry.max((bounds.w - total_gap) / @as(f32, @floatFromInt(grid.columns)), 0.0);
    return grid;
}

pub fn responsiveGridCell(grid: ResponsiveGrid, index: usize, row_height: f32) Rect {
    return responsiveGridSpan(grid, index, 1, row_height);
}

pub fn responsiveGridRowCount(grid: ResponsiveGrid, item_count: usize) usize {
    if (grid.columns == 0 or item_count == 0) return 0;
    return (item_count + grid.columns - 1) / grid.columns;
}

pub fn responsiveGridRowHeight(grid: ResponsiveGrid, row_count: usize) f32 {
    if (grid.columns == 0 or row_count == 0 or !grid.bounds.valid()) return 0.0;
    return geometry.max((grid.bounds.h - grid.gap_y * @as(f32, @floatFromInt(row_count - 1))) / @as(f32, @floatFromInt(row_count)), 0.0);
}

pub fn responsiveGridHeight(grid: ResponsiveGrid, item_count: usize, row_height: f32) f32 {
    if (row_height <= 0.0) return 0.0;
    const rows = responsiveGridRowCount(grid, item_count);
    if (rows == 0) return 0.0;
    return row_height * @as(f32, @floatFromInt(rows)) + grid.gap_y * @as(f32, @floatFromInt(rows - 1));
}

pub fn responsiveGridSpan(grid: ResponsiveGrid, index: usize, column_span: usize, row_height: f32) Rect {
    if (grid.columns == 0 or grid.column_w <= 0.0 or row_height <= 0.0 or !grid.bounds.valid()) return emptyRect();
    if (column_span == 0) return emptyRect();
    const column = index % grid.columns;
    const row = index / grid.columns;
    const remaining_columns = grid.columns - column;
    const span = @min(column_span, remaining_columns);
    const width = grid.column_w * @as(f32, @floatFromInt(span)) + grid.gap_x * @as(f32, @floatFromInt(span - 1));
    return Rect.init(
        grid.bounds.x + (grid.column_w + grid.gap_x) * @as(f32, @floatFromInt(column)),
        grid.bounds.y + (row_height + grid.gap_y) * @as(f32, @floatFromInt(row)),
        width,
        row_height,
    );
}

pub fn uniformGrid(bounds: Rect, columns: usize, rows: usize, gap_x: f32, gap_y: f32) UniformGrid {
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

pub fn uniformGridCell(grid: UniformGrid, index: usize) Rect {
    return uniformGridSpan(grid, index, 1, 1);
}

pub fn uniformGridSpan(grid: UniformGrid, index: usize, column_span: usize, row_span: usize) Rect {
    if (grid.columns == 0 or grid.rows == 0 or grid.cell_w <= 0.0 or grid.cell_h <= 0.0 or !grid.bounds.valid()) return emptyRect();
    if (column_span == 0 or row_span == 0) return emptyRect();
    const column = index % grid.columns;
    const row = index / grid.columns;
    if (row >= grid.rows) return emptyRect();
    const columns = @min(column_span, grid.columns - column);
    const rows = @min(row_span, grid.rows - row);
    const width = grid.cell_w * @as(f32, @floatFromInt(columns)) + grid.gap_x * @as(f32, @floatFromInt(columns - 1));
    const height = grid.cell_h * @as(f32, @floatFromInt(rows)) + grid.gap_y * @as(f32, @floatFromInt(rows - 1));
    return Rect.init(
        grid.bounds.x + (grid.cell_w + grid.gap_x) * @as(f32, @floatFromInt(column)),
        grid.bounds.y + (grid.cell_h + grid.gap_y) * @as(f32, @floatFromInt(row)),
        width,
        height,
    );
}

pub fn verticalFlow(bounds: Rect, gap: f32) VerticalFlow {
    if (!bounds.valid() or gap < 0.0) return .{};
    return .{ .bounds = bounds, .cursor_y = bounds.y, .gap = gap };
}

pub fn rowIconSlot(row: Rect) Rect {
    return Rect.init(row.x + row_pad_x, row.y, row_icon, row.h).withHeightCentered(row_icon);
}

pub fn rowTextRect(row: Rect, trailing_reserved_w: f32) Rect {
    const width = geometry.max(row.w - row_text_inset - row_pad_x - trailing_reserved_w, 0.0);
    return Rect.init(row.x + row_text_inset, row.y, width, row.h);
}

pub fn surfacePaddingForWidth(width: f32) Padding {
    if (width <= narrow_viewport_w) return .{ .x = surface_inset_x_narrow, .y = surface_inset_y_narrow };
    if (width >= wide_viewport_w) return .{ .x = surface_inset_x_wide, .y = surface_inset_y_wide };
    return .{ .x = surface_inset_x, .y = surface_inset_y };
}

pub fn surfaceContentRect(bounds: Rect) Rect {
    const pad = surfacePaddingForWidth(bounds.w);
    return bounds.inset(pad.x, pad.y);
}

pub fn systemSurfaceSafeRect(bounds: Rect) Rect {
    return bounds.inset(surface_viewport_inset, surface_viewport_inset);
}

pub fn centeredSystemPanel(safe: Rect, min_w: f32, max_w: f32, preferred_h: f32, min_h: f32) Rect {
    const panel_w = if (safe.w >= min_w) geometry.clamp(safe.w, min_w, max_w) else geometry.max(safe.w, 0.0);
    const panel_h = if (safe.h >= min_h) geometry.max(geometry.min(preferred_h, safe.h), min_h) else geometry.max(safe.h, 0.0);
    return Rect.init(safe.x + (safe.w - panel_w) * 0.5, safe.y + (safe.h - panel_h) * 0.5, panel_w, panel_h);
}

pub fn scrollContentRect(bounds: Rect, padding_trbl: ?*const [4]f32) Rect {
    const padding = padding_trbl orelse return Rect.init(bounds.x, bounds.y, 0.0, 0.0);
    const top = padding[0];
    const edge_right = padding[1];
    const bottom = padding[2];
    const left = padding[3];
    return Rect.init(
        bounds.x + left,
        bounds.y + top,
        geometry.max(bounds.w - left - edge_right - scrollbar_reserved_w, 0.0),
        geometry.max(bounds.h - top - bottom, 0.0),
    );
}

pub fn scrollbarTrackRect(bounds: Rect, content: Rect) Rect {
    return Rect.init(bounds.x + bounds.w - scrollbar_edge_inset, content.y, scrollbar_track_w, content.h);
}

pub fn scrollbarHitRect(track: Rect) Rect {
    return Rect.init(track.x - (scrollbar_hit_w - track.w), track.y, scrollbar_hit_w, track.h);
}

pub fn scrollViewport(viewport: Rect, content_h: f32, scroll: f32, min_thumb_h: f32) ScrollViewport {
    var result = ScrollViewport{};
    if (!viewport.valid() or content_h < 0.0 or min_thumb_h < 0.0) return result;
    result.viewport = viewport;
    result.overflow_h = geometry.max(content_h - viewport.h, 0.0);
    result.scroll_px = result.overflow_h * geometry.clamp(scroll, 0.0, 1.0);
    result.content = Rect.init(viewport.x, viewport.y - result.scroll_px, viewport.w, content_h);
    result.scrollable = content_h > viewport.h;
    if (!result.scrollable) return result;
    result.track = scrollbarTrackRect(viewport, viewport);
    result.hit = scrollbarHitRect(result.track);
    var thumb_h = geometry.max(viewport.h * (viewport.h / content_h), min_thumb_h);
    thumb_h = geometry.min(thumb_h, result.track.h);
    const thumb_y = result.track.y + (result.track.h - thumb_h) * geometry.clamp(scroll, 0.0, 1.0);
    result.thumb = Rect.init(result.track.x, thumb_y, result.track.w, thumb_h);
    return result;
}

fn expectApprox(actual: f32, expected: f32) !void {
    try std.testing.expectApproxEqAbs(expected, actual, 0.0001);
}

fn expectRect(actual: Rect, expected: Rect) !void {
    try expectApprox(actual.x, expected.x);
    try expectApprox(actual.y, expected.y);
    try expectApprox(actual.w, expected.w);
    try expectApprox(actual.h, expected.h);
}

test "spacing default matches tokens" {
    const tokens = defaultTokens();
    try expectApprox(tokens.card_radius_max, card_radius_max);
    try expectApprox(tokens.card_pad_x, card_pad_x);
    try expectApprox(tokens.control_h, 36.0);
    try expectApprox(tokens.component_pad.x, component_pad_x);
    try expectApprox(tokens.row_text_inset, row_text_inset);
    try expectApprox(tokens.list_row_h, list_row_h);
    try expectApprox(tokens.workspace_gap, workspace_gap);
    try expectApprox(tokens.min_touch_target, min_touch_target);
}

test "component density padding and surface spacing" {
    const dense = componentPaddingForDensity(.dense);
    const normal = componentPaddingForDensity(.default);
    const spacious = componentPaddingForDensity(.spacious);
    try std.testing.expect(dense.x < normal.x);
    try std.testing.expect(dense.y < normal.y);
    try std.testing.expect(normal.x < spacious.x);
    try std.testing.expect(normal.y < spacious.y);
    try expectApprox(normal.x, card_pad_x);
    try expectApprox(normal.y, card_pad_y);
    try expectRect(
        componentContentRect(Rect.init(10.0, 20.0, 220.0, 140.0), .default),
        Rect.init(10.0 + normal.x, 20.0 + normal.y, 220.0 - normal.x * 2.0, 140.0 - normal.y * 2.0),
    );

    const narrow = surfacePaddingForWidth(390.0);
    const surface_normal = surfacePaddingForWidth(900.0);
    const wide = surfacePaddingForWidth(1440.0);
    try expectApprox(narrow.x, surface_inset_x_narrow);
    try expectApprox(surface_normal.x, surface_inset_x);
    try expectApprox(wide.x, surface_inset_x_wide);
    try std.testing.expect(narrow.x < surface_normal.x);
    try std.testing.expect(surface_normal.x < wide.x);
    try expectRect(surfaceContentRect(Rect.init(0.0, 0.0, 390.0, 260.0)), Rect.init(10.0, 10.0, 370.0, 240.0));
}

test "responsive grid derives columns and cell bounds" {
    const wide = responsiveGrid(Rect.init(10.0, 20.0, 720.0, 400.0), 220.0, 3, 16.0, 18.0);
    const narrow = responsiveGrid(Rect.init(10.0, 20.0, 360.0, 400.0), 220.0, 3, 16.0, 18.0);
    try std.testing.expectEqual(@as(usize, 1), narrow.columns);
    try expectApprox(narrow.column_w, 360.0);
    try std.testing.expectEqual(@as(usize, 3), wide.columns);
    try expectApprox(wide.column_w, (720.0 - 32.0) / 3.0);
    try std.testing.expectEqual(@as(usize, 2), responsiveGridRowCount(wide, 5));
    try expectApprox(responsiveGridRowHeight(wide, 2), (400.0 - 18.0) / 2.0);
    try expectApprox(responsiveGridHeight(wide, 5, 96.0), 96.0 * 2.0 + 18.0);
    try expectRect(responsiveGridCell(wide, 4, 96.0), Rect.init(10.0 + wide.column_w + 16.0, 20.0 + 96.0 + 18.0, wide.column_w, 96.0));
    try expectRect(responsiveGridSpan(wide, 3, 2, 96.0), Rect.init(10.0, 20.0 + 96.0 + 18.0, wide.column_w * 2.0 + 16.0, 96.0));
}

test "responsive sidecar adapts between horizontal and stacked" {
    const wide = responsiveSidecar(Rect.init(10.0, 20.0, 760.0, 420.0), 160.0, 220.0, 300.0, 24.0, 120.0);
    const compressed = responsiveSidecar(Rect.init(10.0, 20.0, 500.0, 420.0), 160.0, 220.0, 300.0, 24.0, 120.0);
    const stacked = responsiveSidecar(Rect.init(10.0, 20.0, 420.0, 420.0), 160.0, 220.0, 300.0, 24.0, 120.0);
    try std.testing.expect(!wide.stacked);
    try expectRect(wide.side, Rect.init(10.0, 20.0, 220.0, 420.0));
    try expectApprox(wide.main.x, wide.side.x + wide.side.w + 24.0);
    try std.testing.expect(!compressed.stacked);
    try expectApprox(compressed.side.w, 176.0);
    try expectApprox(compressed.main.w, 300.0);
    try std.testing.expect(stacked.stacked);
    try expectRect(stacked.side, Rect.init(10.0, 20.0, 420.0, 120.0));
    try expectApprox(stacked.main.y, stacked.side.y + stacked.side.h + 24.0);
}

test "uniform grid vertical flow row and scroll geometry" {
    const grid = uniformGrid(Rect.init(10.0, 20.0, 720.0, 260.0), 3, 2, 16.0, 18.0);
    try std.testing.expectEqual(@as(usize, 3), grid.columns);
    try std.testing.expectEqual(@as(usize, 2), grid.rows);
    try expectApprox(grid.cell_w, (720.0 - 32.0) / 3.0);
    try expectApprox(grid.cell_h, (260.0 - 18.0) / 2.0);
    try expectRect(uniformGridCell(grid, 4), Rect.init(10.0 + grid.cell_w + 16.0, 20.0 + grid.cell_h + 18.0, grid.cell_w, grid.cell_h));
    try expectRect(uniformGridSpan(grid, 3, 2, 1), Rect.init(10.0, 20.0 + grid.cell_h + 18.0, grid.cell_w * 2.0 + 16.0, grid.cell_h));

    var flow = verticalFlow(Rect.init(10.0, 20.0, 320.0, 260.0), 12.0);
    const first = flow.next(110.0);
    const second = flow.next(80.0);
    const remaining_rect = flow.remaining();
    try expectRect(first, Rect.init(10.0, 20.0, 320.0, 110.0));
    try expectRect(second, Rect.init(10.0, 20.0 + 110.0 + 12.0, 320.0, 80.0));
    try expectRect(remaining_rect, Rect.init(10.0, second.y + second.h + 12.0, 320.0, 260.0 - 110.0 - 80.0 - 12.0 * 2.0));
}

test "system panel row and scroll geometry" {
    const row = Rect.init(10.0, 20.0, 360.0, row_h);
    const icon = rowIconSlot(row);
    const text = rowTextRect(row, 120.0);
    try expectRect(icon, Rect.init(24.0, 32.0, row_icon, row_icon));
    try expectApprox(text.x, row.x + row_text_inset);
    try expectApprox(text.w, row.w - row_text_inset - row_pad_x - 120.0);

    const safe = systemSurfaceSafeRect(Rect.init(0.0, 0.0, 360.0, 260.0));
    const panel = centeredSystemPanel(safe, 320.0, 520.0, 320.0, 220.0);
    try expectRect(safe, Rect.init(10.0, 10.0, 340.0, 240.0));
    try std.testing.expect(panel.x >= safe.x);
    try std.testing.expect(panel.y >= safe.y);
    try std.testing.expect(panel.x + panel.w <= safe.x + safe.w);
    try std.testing.expect(panel.y + panel.h <= safe.y + safe.h);

    const bounds = Rect.init(10.0, 20.0, 220.0, 180.0);
    const padding = [4]f32{ 12.0, 14.0, 16.0, 18.0 };
    const content = scrollContentRect(bounds, &padding);
    const track = scrollbarTrackRect(bounds, content);
    const hit = scrollbarHitRect(track);
    try expectRect(content, Rect.init(28.0, 32.0, 220.0 - 18.0 - 14.0 - scrollbar_reserved_w, 180.0 - 12.0 - 16.0));
    try expectApprox(track.w, scrollbar_track_w);
    try expectApprox(track.h, content.h);
    try expectApprox(hit.w, scrollbar_hit_w);
    try expectApprox(hit.h, track.h);
    try std.testing.expect(hit.x <= track.x);

    const viewport = scrollViewport(bounds, 360.0, 0.25, 30.0);
    try std.testing.expect(viewport.scrollable);
    try expectApprox(viewport.overflow_h, 180.0);
    try expectApprox(viewport.scroll_px, 45.0);
    try expectRect(viewport.content, Rect.init(bounds.x, bounds.y - 45.0, bounds.w, 360.0));
    try expectRect(viewport.thumb, Rect.init(track.x, 42.5, track.w, 90.0));
}
