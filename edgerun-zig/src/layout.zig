const std = @import("std");
const geometry = @import("geometry.zig");
const spacing = @import("spacing.zig");

pub const Rect = geometry.Rect;

pub const Error = error{
    InvalidArgument,
};

pub const Kind = enum {
    row,
    column,
    card,
    grid,
    masonry,
    bento_grid,
    scroll_area,
    conversation,
    leaf,
};

pub const max_children = 32;
pub const bento_max_rows = 16;
pub const bento_cell_aspect: f32 = 0.62;
pub const masonry_default_height_ratio: f32 = 0.72;
pub const masonry_step_height_ratio: f32 = 0.16;
pub const masonry_step_count: usize = 4;

pub const Node = struct {
    kind: Kind = .leaf,
    bounds: ?Rect = null,
    gap: f32 = 0.0,
    padding: f32 = 0.0,
    selected: usize = 0,
    number: f32 = 0.0,
    column_span: usize = 0,
    row_span: usize = 0,
    children: []const *const Node = &.{},

    pub fn resolveBounds(self: Node, fallback: Rect) Rect {
        if (self.bounds) |own| {
            if (own.valid()) return own;
        }
        return fallback;
    }

    pub fn childBounds(self: Node, child_index: usize, bounds: Rect) Error!Rect {
        const rect = self.resolveBounds(bounds);
        return switch (self.kind) {
            .row => linearChildBounds(self, child_index, rect, true),
            .column, .card => linearChildBounds(self, child_index, rect, false),
            .grid => gridChildBounds(self, child_index, rect),
            .masonry => masonryChildBounds(self, child_index, rect),
            .bento_grid => bentoChildBounds(self, child_index, rect),
            .scroll_area, .conversation => scrolledChildBounds(self, child_index, rect),
            .leaf => error.InvalidArgument,
        };
    }
};

fn childAt(node: Node, child_index: usize) Error!*const Node {
    if (child_index >= node.children.len) return error.InvalidArgument;
    return node.children[child_index];
}

fn linearChildBounds(node: Node, child_index: usize, bounds: Rect, row: bool) Error!Rect {
    const child = try childAt(node, child_index);
    if (node.children.len == 0) return error.InvalidArgument;
    const content = bounds.insetUniform(node.padding);
    const total_gap = node.gap * @as(f32, @floatFromInt(node.children.len - 1));
    const step = if (row) (content.w - total_gap) / @as(f32, @floatFromInt(node.children.len)) else (content.h - total_gap) / @as(f32, @floatFromInt(node.children.len));
    if (step <= 0.0) return error.InvalidArgument;
    var child_bounds = content;
    if (row) {
        child_bounds.x = content.x + (step + node.gap) * @as(f32, @floatFromInt(child_index));
        child_bounds.w = step;
    } else {
        child_bounds.y = content.y + (step + node.gap) * @as(f32, @floatFromInt(child_index));
        child_bounds.h = step;
    }
    return child.resolveBounds(child_bounds);
}

fn gridChildBounds(node: Node, child_index: usize, bounds: Rect) Error!Rect {
    const child = try childAt(node, child_index);
    if (node.children.len == 0) return error.InvalidArgument;
    var columns = if (node.selected == 0) 1 else node.selected;
    if (columns > node.children.len) columns = node.children.len;
    const rows = (node.children.len + columns - 1) / columns;
    const content = bounds.insetUniform(node.padding);
    const grid = spacing.uniformGrid(content, columns, rows, node.gap, node.gap);
    if (grid.columns == 0) return error.InvalidArgument;
    return child.resolveBounds(spacing.uniformGridCell(grid, child_index));
}

fn childRequestedHeight(child: *const Node, width: f32, child_index: usize) f32 {
    if (child.bounds) |own| {
        if (own.valid()) return own.h;
    }
    const step = @as(f32, @floatFromInt(child_index % masonry_step_count));
    return width * (masonry_default_height_ratio + masonry_step_height_ratio * step);
}

fn masonryChildBounds(node: Node, child_index: usize, bounds: Rect) Error!Rect {
    const child = try childAt(node, child_index);
    if (node.children.len == 0) return error.InvalidArgument;
    var columns = if (node.selected == 0) 1 else node.selected;
    columns = @min(columns, max_children);
    columns = @min(columns, node.children.len);
    const content = bounds.insetUniform(node.padding);
    const total_gap_x = node.gap * @as(f32, @floatFromInt(columns - 1));
    const column_w = (content.w - total_gap_x) / @as(f32, @floatFromInt(columns));
    if (column_w <= 0.0 or content.h <= 0.0) return error.InvalidArgument;

    var heights = [_]f32{0.0} ** max_children;
    var selected = content;
    var i: usize = 0;
    while (i <= child_index) : (i += 1) {
        var column: usize = 0;
        var min_height = heights[0];
        var candidate: usize = 1;
        while (candidate < columns) : (candidate += 1) {
            if (heights[candidate] < min_height) {
                column = candidate;
                min_height = heights[candidate];
            }
        }
        const requested_h = childRequestedHeight(node.children[i], column_w, i);
        const placed = Rect.init(content.x + (column_w + node.gap) * @as(f32, @floatFromInt(column)), content.y + heights[column], column_w, requested_h);
        if (i == child_index) selected = placed;
        heights[column] += requested_h + node.gap;
    }
    return child.resolveBounds(selected);
}

fn childColumnSpan(child: *const Node, columns: usize) usize {
    const span = if (child.column_span > 0) child.column_span else 1;
    return @min(span, columns);
}

fn childRowSpan(child: *const Node) usize {
    return if (child.row_span > 0) child.row_span else 1;
}

fn bentoCellsAvailable(occupied: *const [bento_max_rows][max_children]bool, row: usize, column: usize, row_span: usize, column_span: usize, columns: usize) bool {
    if (column + column_span > columns) return false;
    if (row + row_span > bento_max_rows) return false;
    var y = row;
    while (y < row + row_span) : (y += 1) {
        var x = column;
        while (x < column + column_span) : (x += 1) {
            if (occupied[y][x]) return false;
        }
    }
    return true;
}

fn bentoMarkCells(occupied: *[bento_max_rows][max_children]bool, row: usize, column: usize, row_span: usize, column_span: usize) void {
    var y = row;
    while (y < row + row_span) : (y += 1) {
        var x = column;
        while (x < column + column_span) : (x += 1) occupied[y][x] = true;
    }
}

fn bentoFindCell(occupied: *const [bento_max_rows][max_children]bool, row_span: usize, column_span: usize, columns: usize) Error!struct { row: usize, column: usize } {
    var row: usize = 0;
    while (row < bento_max_rows) : (row += 1) {
        var column: usize = 0;
        while (column < columns) : (column += 1) {
            if (bentoCellsAvailable(occupied, row, column, row_span, column_span, columns)) return .{ .row = row, .column = column };
        }
    }
    return error.InvalidArgument;
}

fn bentoChildBounds(node: Node, child_index: usize, bounds: Rect) Error!Rect {
    const child = try childAt(node, child_index);
    var columns = if (node.selected == 0) 1 else node.selected;
    columns = @min(columns, max_children);
    const content = bounds.insetUniform(node.padding);
    const total_gap_x = node.gap * @as(f32, @floatFromInt(columns - 1));
    const cell_w = (content.w - total_gap_x) / @as(f32, @floatFromInt(columns));
    const cell_h = cell_w * bento_cell_aspect;
    if (cell_w <= 0.0 or cell_h <= 0.0) return error.InvalidArgument;
    var occupied = [_][max_children]bool{[_]bool{false} ** max_children} ** bento_max_rows;
    var selected = content;
    var i: usize = 0;
    while (i <= child_index) : (i += 1) {
        const current = node.children[i];
        const col_span = childColumnSpan(current, columns);
        const row_span = childRowSpan(current);
        const cell = try bentoFindCell(&occupied, row_span, col_span, columns);
        const w = cell_w * @as(f32, @floatFromInt(col_span)) + node.gap * @as(f32, @floatFromInt(col_span - 1));
        const h = cell_h * @as(f32, @floatFromInt(row_span)) + node.gap * @as(f32, @floatFromInt(row_span - 1));
        const placed = Rect.init(
            content.x + (cell_w + node.gap) * @as(f32, @floatFromInt(cell.column)),
            content.y + (cell_h + node.gap) * @as(f32, @floatFromInt(cell.row)),
            w,
            h,
        );
        if (i == child_index) selected = placed;
        bentoMarkCells(&occupied, cell.row, cell.column, row_span, col_span);
    }
    return child.resolveBounds(selected);
}

fn scrolledChildBounds(node: Node, child_index: usize, bounds: Rect) Error!Rect {
    var scrolled = bounds;
    scrolled.y -= node.number;
    return linearChildBounds(node, child_index, scrolled, false);
}

fn expectRect(actual: Rect, expected: Rect) !void {
    try std.testing.expectApproxEqAbs(expected.x, actual.x, 0.0001);
    try std.testing.expectApproxEqAbs(expected.y, actual.y, 0.0001);
    try std.testing.expectApproxEqAbs(expected.w, actual.w, 0.0001);
    try std.testing.expectApproxEqAbs(expected.h, actual.h, 0.0001);
}

test "linear grid and scroll child bounds match C node layout" {
    const a = Node{};
    const b = Node{};
    const c = Node{};
    const children = [_]*const Node{ &a, &b, &c };

    const row = Node{ .kind = .row, .gap = 10.0, .padding = 5.0, .children = &children };
    try expectRect(try row.childBounds(1, Rect.init(0.0, 0.0, 320.0, 80.0)), Rect.init(111.666664, 5.0, 96.666664, 70.0));

    const grid = Node{ .kind = .grid, .selected = 2, .gap = 8.0, .padding = 4.0, .children = &children };
    try expectRect(try grid.childBounds(2, Rect.init(0.0, 0.0, 260.0, 120.0)), Rect.init(4.0, 64.0, 122.0, 52.0));

    const scroll = Node{ .kind = .scroll_area, .gap = 6.0, .number = 20.0, .children = &children };
    try expectRect(try scroll.childBounds(0, Rect.init(0.0, 100.0, 300.0, 90.0)), Rect.init(0.0, 80.0, 300.0, 26.0));
}

test "masonry and bento layout place previous children before requested child" {
    const a = Node{};
    const b = Node{ .bounds = Rect.init(0.0, 0.0, 1.0, 50.0) };
    const c = Node{};
    const children = [_]*const Node{ &a, &b, &c };

    const masonry = Node{ .kind = .masonry, .selected = 2, .gap = 10.0, .children = &children };
    const masonry_child = try masonry.childBounds(2, Rect.init(0.0, 0.0, 210.0, 300.0));
    try expectRect(masonry_child, Rect.init(110.0, 60.0, 100.0, 104.0));

    const wide = Node{ .column_span = 2, .row_span = 1 };
    const normal = Node{};
    const tall = Node{ .row_span = 2 };
    const bento_children = [_]*const Node{ &wide, &normal, &tall };
    const bento = Node{ .kind = .bento_grid, .selected = 3, .gap = 10.0, .children = &bento_children };
    try expectRect(try bento.childBounds(0, Rect.init(0.0, 0.0, 320.0, 200.0)), Rect.init(0.0, 0.0, 210.0, 62.0));
    try expectRect(try bento.childBounds(2, Rect.init(0.0, 0.0, 320.0, 200.0)), Rect.init(0.0, 72.0, 100.0, 134.0));
}
