const std = @import("std");
const math = @import("../math.zig");
const icon_vector = @import("../icon_vector.zig");
const renderer_ir = @import("ir.zig");

pub const max_width: usize = 128;
pub const max_height: usize = 128;
pub const max_pixels: usize = max_width * max_height;
const max_fill_path_points: usize = 512;
const max_fill_path_subpaths: usize = 64;
const min_fill_path_points: usize = 3;
const curve_segments: usize = 8;
const stroke_curve_segments: usize = 4;
const stroke_arc_step_divisor: f32 = 40.0;
const stroke_large_arc_step_divisor: f32 = 10.0;
const default_stroke_width: f32 = 2.0 / 24.0;
const min_stroke_px: f32 = 1.5;
const stroke_antialias_width: f32 = 0.5;
const round_cap_antialias_width: f32 = 0.588086;
const line_stroke_coverage_boost: f32 = 1.2;
const curve_stroke_coverage_boost: f32 = 0.05;
const arc_stroke_coverage_boost: f32 = 1.4;
const stroke_coverage_boost_floor: f32 = 0.5;
const axis_epsilon: f32 = 0.00001;

const max_alpha: u8 = 255;
const fill_sample_offsets = [_]icon_vector.Point{
    .{ .x = 0.25, .y = 0.25 },
    .{ .x = 0.75, .y = 0.25 },
    .{ .x = 0.25, .y = 0.75 },
    .{ .x = 0.75, .y = 0.75 },
};

pub const Mask = struct {
    width: usize,
    height: usize,
    alpha: []const u8,
    painted: bool,

    pub fn valid(self: Mask) bool {
        return self.width != 0 and self.height != 0 and self.alpha.len >= self.width * self.height;
    }
};

const FillRule = enum {
    nonzero,
    evenodd,
};

const Path = struct {
    current: ?icon_vector.Point = null,
    start: ?icon_vector.Point = null,
    fill_rule: FillRule = .nonzero,
    points: [max_fill_path_points]icon_vector.Point = undefined,
    subpaths: [max_fill_path_subpaths]usize = undefined,
    point_len: usize = 0,
    subpath_len: usize = 0,

    fn begin(self: *Path, rule: FillRule) void {
        self.current = null;
        self.start = null;
        self.fill_rule = rule;
        self.point_len = 0;
        self.subpath_len = 0;
    }

    fn moveTo(self: *Path, point: icon_vector.Point) void {
        if (self.subpath_len >= self.subpaths.len) return;
        self.subpaths[self.subpath_len] = self.point_len;
        self.subpath_len += 1;
        self.current = point;
        self.start = point;
        self.append(point);
    }

    fn lineTo(self: *Path, point: icon_vector.Point) void {
        if (self.subpath_len == 0) self.moveTo(point) else self.append(point);
        self.current = point;
    }

    fn close(self: *Path) void {
        if (self.start) |start_point| self.current = start_point;
    }

    fn clear(self: *Path) void {
        self.current = null;
        self.start = null;
        self.point_len = 0;
        self.subpath_len = 0;
    }

    fn append(self: *Path, point: icon_vector.Point) void {
        if (self.point_len >= self.points.len) return;
        self.points[self.point_len] = point;
        self.point_len += 1;
    }
};

pub fn rasterizeIconFill(icon_id: u32, width: usize, height: usize, out: []u8) !Mask {
    if (width == 0 or height == 0 or width > max_width or height > max_height) return error.InvalidIconMaskSize;
    const pixel_count = width * height;
    if (out.len < pixel_count) return error.InvalidIconMaskBuffer;
    @memset(out[0..pixel_count], 0);
    var iter = renderer_ir.iconOpIteratorForId(icon_id);
    var path = Path{};
    var fill_active = false;
    var painted = false;
    while (iter.next() catch return error.InvalidIconVector) |op| {
        switch (op) {
            .begin_fill_path => {
                path.begin(.nonzero);
                fill_active = true;
            },
            .begin_evenodd_fill_path => {
                path.begin(.evenodd);
                fill_active = true;
            },
            .end_fill_path => {
                if (fill_active) {
                    painted = rasterizePath(path, width, height, out[0..pixel_count]) or painted;
                    path.clear();
                    fill_active = false;
                }
            },
            .move_to => |point| if (fill_active) path.moveTo(point),
            .line_to => |point| if (fill_active) path.lineTo(point),
            .quad_to => |quad| if (fill_active) {
                if (path.current) |current| flattenQuadratic(&path, current, quad.control, quad.end);
                path.lineTo(quad.end);
            },
            .cubic_to => |curve| if (fill_active) {
                if (path.current) |current| flattenCubic(&path, current, curve.control0, curve.control1, curve.end);
                path.lineTo(curve.end);
            },
            .arc_to => |arc| if (fill_active) path.lineTo(arc.end),
            .close_path => if (fill_active) path.close(),
            else => {},
        }
    }
    if (fill_active) painted = rasterizePath(path, width, height, out[0..pixel_count]) or painted;
    return .{ .width = width, .height = height, .alpha = out[0..pixel_count], .painted = painted };
}

pub fn rasterizeIconAlpha(icon_id: u32, width: usize, height: usize, out: []u8) !Mask {
    if (width == 0 or height == 0 or width > max_width or height > max_height) return error.InvalidIconMaskSize;
    const pixel_count = width * height;
    if (out.len < pixel_count) return error.InvalidIconMaskBuffer;
    @memset(out[0..pixel_count], 0);
    var iter = renderer_ir.iconOpIteratorForId(icon_id);
    var path = Path{};
    var fill_active = false;
    var stroke_width = default_stroke_width;
    var stroke_cap = icon_vector.StrokeCap.round;
    var painted = false;
    while (iter.next() catch return error.InvalidIconVector) |op| {
        switch (op) {
            .begin_fill_path => {
                path.begin(.nonzero);
                fill_active = true;
            },
            .begin_evenodd_fill_path => {
                path.begin(.evenodd);
                fill_active = true;
            },
            .end_fill_path => {
                if (fill_active) {
                    painted = rasterizePath(path, width, height, out[0..pixel_count]) or painted;
                    path.clear();
                    fill_active = false;
                }
            },
            .stroke_width => |value| stroke_width = value,
            .stroke_cap => |value| stroke_cap = value,
            .move_to => |point| {
                if (fill_active) {
                    path.moveTo(point);
                } else {
                    path.current = point;
                    path.start = point;
                }
            },
            .line_to => |point| {
                if (fill_active) {
                    path.lineTo(point);
                } else {
                    if (path.current) |current| {
                        strokeSegment(width, height, out[0..pixel_count], stroke_width, current, point, stroke_antialias_width, line_stroke_coverage_boost);
                        if (stroke_cap == .round) {
                            strokeRoundPoint(width, height, out[0..pixel_count], stroke_width, current, round_cap_antialias_width, 0.0);
                            strokeRoundPoint(width, height, out[0..pixel_count], stroke_width, point, round_cap_antialias_width, 0.0);
                        }
                        painted = true;
                    }
                    path.current = point;
                }
            },
            .quad_to => |quad| {
                if (fill_active) {
                    if (path.current) |current| flattenQuadratic(&path, current, quad.control, quad.end);
                    path.lineTo(quad.end);
                } else {
                    if (path.current) |current| {
                        strokeQuadratic(width, height, out[0..pixel_count], stroke_width, stroke_cap, current, quad.control, quad.end);
                        painted = true;
                    }
                    path.current = quad.end;
                }
            },
            .cubic_to => |curve| {
                if (fill_active) {
                    if (path.current) |current| flattenCubic(&path, current, curve.control0, curve.control1, curve.end);
                    path.lineTo(curve.end);
                } else {
                    if (path.current) |current| {
                        strokeCubic(width, height, out[0..pixel_count], stroke_width, stroke_cap, current, curve.control0, curve.control1, curve.end);
                        painted = true;
                    }
                    path.current = curve.end;
                }
            },
            .arc_to => |arc| {
                if (fill_active) {
                    flattenArc(&path, path.current orelse arc.end, arc);
                    path.lineTo(arc.end);
                } else {
                    if (path.current) |current| {
                        strokeArc(width, height, out[0..pixel_count], stroke_width, stroke_cap, current, arc);
                        painted = true;
                    }
                    path.current = arc.end;
                }
            },
            .close_path => {
                if (fill_active) {
                    path.close();
                } else if (path.current) |current| if (path.start) |start| {
                    strokeSegment(width, height, out[0..pixel_count], stroke_width, current, start, stroke_antialias_width, line_stroke_coverage_boost);
                    path.current = start;
                    painted = true;
                };
            },
            .polyline => |points| {
                strokePolyline(width, height, out[0..pixel_count], stroke_width, stroke_cap, points);
                painted = true;
            },
            .circle => |circle| {
                strokeCircle(width, height, out[0..pixel_count], stroke_width, circle.cx, circle.cy, circle.radius);
                painted = true;
            },
            .ellipse => |ellipse| {
                strokeEllipse(width, height, out[0..pixel_count], stroke_width, ellipse.cx, ellipse.cy, ellipse.rx, ellipse.ry, ellipse.full);
                painted = true;
            },
            else => {},
        }
    }
    if (fill_active) painted = rasterizePath(path, width, height, out[0..pixel_count]) or painted;
    return .{ .width = width, .height = height, .alpha = out[0..pixel_count], .painted = painted };
}

fn flattenQuadratic(path: *Path, p0: icon_vector.Point, p1: icon_vector.Point, p2: icon_vector.Point) void {
    var index: usize = 1;
    while (index <= curve_segments) : (index += 1) {
        const t = @as(f32, @floatFromInt(index)) / @as(f32, @floatFromInt(curve_segments));
        path.append(icon_vector.bezierQuadraticPoint(p0, p1, p2, t));
    }
}

fn flattenCubic(path: *Path, p0: icon_vector.Point, p1: icon_vector.Point, p2: icon_vector.Point, p3: icon_vector.Point) void {
    var index: usize = 1;
    while (index <= curve_segments) : (index += 1) {
        const t = @as(f32, @floatFromInt(index)) / @as(f32, @floatFromInt(curve_segments));
        path.append(icon_vector.bezierCubicPoint(p0, p1, p2, p3, t));
    }
}

fn flattenArc(path: *Path, start: icon_vector.Point, arc: icon_vector.Arc) void {
    const geometry = icon_vector.svgArcGeometry(start, arc) orelse {
        path.append(arc.end);
        return;
    };
    const divisor: f32 = if (arc.large_arc) stroke_large_arc_step_divisor else stroke_arc_step_divisor;
    const steps = @max(4, @as(usize, @intFromFloat(@ceil(@abs(geometry.delta) * divisor / math.pi))));
    var step: usize = 1;
    while (step <= steps) : (step += 1) path.append(geometry.pointAt(step, steps));
}

fn strokePolyline(width: usize, height: usize, out: []u8, stroke_width: f32, stroke_cap: icon_vector.StrokeCap, points: []const f32) void {
    if (points.len < icon_vector.polyline_min_points * icon_vector.point_float_count) return;
    var index: usize = icon_vector.point_float_count;
    while (index < points.len) : (index += icon_vector.point_float_count) {
        const start = icon_vector.Point{ .x = points[index - 2], .y = points[index - 1] };
        const end = icon_vector.Point{ .x = points[index], .y = points[index + 1] };
        strokeSegment(width, height, out, stroke_width, start, end, stroke_antialias_width, line_stroke_coverage_boost);
        if (stroke_cap == .round) {
            strokeRoundPoint(width, height, out, stroke_width, start, round_cap_antialias_width, 0.0);
            strokeRoundPoint(width, height, out, stroke_width, end, round_cap_antialias_width, 0.0);
        }
    }
}

fn strokeQuadratic(width: usize, height: usize, out: []u8, stroke_width: f32, stroke_cap: icon_vector.StrokeCap, p0: icon_vector.Point, p1: icon_vector.Point, p2: icon_vector.Point) void {
    var previous = p0;
    var index: usize = 1;
    while (index <= stroke_curve_segments) : (index += 1) {
        const t = @as(f32, @floatFromInt(index)) / @as(f32, @floatFromInt(stroke_curve_segments));
        const inv = 1.0 - t;
        const next = icon_vector.Point{
            .x = inv * inv * p0.x + 2.0 * inv * t * p1.x + t * t * p2.x,
            .y = inv * inv * p0.y + 2.0 * inv * t * p1.y + t * t * p2.y,
        };
        strokeSegment(width, height, out, stroke_width, previous, next, stroke_antialias_width, curve_stroke_coverage_boost);
        if (stroke_cap == .round) strokeRoundPoint(width, height, out, stroke_width, next, round_cap_antialias_width, 0.0);
        previous = next;
    }
}

fn strokeCubic(width: usize, height: usize, out: []u8, stroke_width: f32, stroke_cap: icon_vector.StrokeCap, p0: icon_vector.Point, p1: icon_vector.Point, p2: icon_vector.Point, p3: icon_vector.Point) void {
    var previous = p0;
    var index: usize = 1;
    while (index <= stroke_curve_segments) : (index += 1) {
        const t = @as(f32, @floatFromInt(index)) / @as(f32, @floatFromInt(stroke_curve_segments));
        const inv = 1.0 - t;
        const next = icon_vector.Point{
            .x = inv * inv * inv * p0.x + 3.0 * inv * inv * t * p1.x + 3.0 * inv * t * t * p2.x + t * t * t * p3.x,
            .y = inv * inv * inv * p0.y + 3.0 * inv * inv * t * p1.y + 3.0 * inv * t * t * p2.y + t * t * t * p3.y,
        };
        strokeSegment(width, height, out, stroke_width, previous, next, stroke_antialias_width, curve_stroke_coverage_boost);
        if (stroke_cap == .round) strokeRoundPoint(width, height, out, stroke_width, next, round_cap_antialias_width, 0.0);
        previous = next;
    }
}

fn strokeArc(width: usize, height: usize, out: []u8, stroke_width: f32, stroke_cap: icon_vector.StrokeCap, start: icon_vector.Point, arc: icon_vector.Arc) void {
    const geometry = icon_vector.svgArcGeometry(start, arc) orelse {
        strokeSegment(width, height, out, stroke_width, start, arc.end, stroke_antialias_width, line_stroke_coverage_boost);
        return;
    };
    const divisor: f32 = if (arc.large_arc) stroke_large_arc_step_divisor else stroke_arc_step_divisor;
    const steps = @max(4, @as(usize, @intFromFloat(@ceil(@abs(geometry.delta) * divisor / math.pi))));
    var previous = start;
    var step: usize = 1;
    while (step <= steps) : (step += 1) {
        const next = geometry.pointAt(step, steps);
        strokeSegment(width, height, out, stroke_width, previous, next, stroke_antialias_width, arc_stroke_coverage_boost);
        if (stroke_cap == .round) strokeRoundPoint(width, height, out, stroke_width, next, round_cap_antialias_width, 0.0);
        previous = next;
    }
}

fn strokeCircle(width: usize, height: usize, out: []u8, stroke_width: f32, cx: f32, cy: f32, radius: f32) void {
    strokeEllipse(width, height, out, stroke_width, cx, cy, radius, radius, true);
}

fn strokeEllipse(width: usize, height: usize, out: []u8, stroke_width: f32, cx: f32, cy: f32, rx: f32, ry: f32, full: bool) void {
    const start_turn: f32 = if (full) 0.0 else 0.5;
    const end_turn: f32 = 1.0;
    const span = end_turn - start_turn;
    var previous = icon_vector.Point{
        .x = cx + @cos(start_turn * math.tau) * rx,
        .y = cy + @sin(start_turn * math.tau) * ry,
    };
    var step: usize = 1;
    while (step <= stroke_curve_segments * 4) : (step += 1) {
        const turn = start_turn + @as(f32, @floatFromInt(step)) * span / @as(f32, @floatFromInt(stroke_curve_segments * 4));
        const next = icon_vector.Point{
            .x = cx + @cos(turn * math.tau) * rx,
            .y = cy + @sin(turn * math.tau) * ry,
        };
        strokeSegment(width, height, out, stroke_width, previous, next, stroke_antialias_width, curve_stroke_coverage_boost);
        previous = next;
    }
}

fn strokeSegment(width: usize, height: usize, out: []u8, stroke_width: f32, start: icon_vector.Point, end: icon_vector.Point, antialias_width_value: f32, coverage_boost: f32) void {
    const x0 = start.x * @as(f32, @floatFromInt(width));
    const y0 = start.y * @as(f32, @floatFromInt(height));
    const x1 = end.x * @as(f32, @floatFromInt(width));
    const y1 = end.y * @as(f32, @floatFromInt(height));
    const radius = iconStroke(width, height, stroke_width) * 0.5;
    const x_start = clampCoord(@intFromFloat(@floor(@min(x0, x1) - radius - antialias_width_value)), width);
    const y_start = clampCoord(@intFromFloat(@floor(@min(y0, y1) - radius - antialias_width_value)), height);
    const x_end = clampCoord(@intFromFloat(@ceil(@max(x0, x1) + radius + antialias_width_value)), width);
    const y_end = clampCoord(@intFromFloat(@ceil(@max(y0, y1) + radius + antialias_width_value)), height);
    const dx = x1 - x0;
    const dy = y1 - y0;
    const denom = dx * dx + dy * dy;
    if (denom <= 0.0) return;
    const boost_coverage = isSlopedSegment(dx, dy);
    var y = y_start;
    while (y < y_end) : (y += 1) {
        var x = x_start;
        while (x < x_end) : (x += 1) {
            const px = @as(f32, @floatFromInt(x)) + 0.5;
            const py = @as(f32, @floatFromInt(y)) + 0.5;
            const t = ((px - x0) * dx + (py - y0) * dy) / denom;
            if (t < 0.0 or t > 1.0) continue;
            const cx = x0 + dx * t;
            const cy = y0 + dy * t;
            const dist = @sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy));
            writeMax(out, width, x, y, strokeCoverageAlpha(radius, dist, antialias_width_value, boost_coverage, coverage_boost));
        }
    }
}

fn strokeRoundPoint(width: usize, height: usize, out: []u8, stroke_width: f32, point: icon_vector.Point, antialias_width_value: f32, coverage_boost: f32) void {
    const cx = point.x * @as(f32, @floatFromInt(width));
    const cy = point.y * @as(f32, @floatFromInt(height));
    const radius = iconStroke(width, height, stroke_width) * 0.5;
    const x_start = clampCoord(@intFromFloat(@floor(cx - radius - antialias_width_value)), width);
    const y_start = clampCoord(@intFromFloat(@floor(cy - radius - antialias_width_value)), height);
    const x_end = clampCoord(@intFromFloat(@ceil(cx + radius + antialias_width_value)), width);
    const y_end = clampCoord(@intFromFloat(@ceil(cy + radius + antialias_width_value)), height);
    var y = y_start;
    while (y < y_end) : (y += 1) {
        var x = x_start;
        while (x < x_end) : (x += 1) {
            const px = @as(f32, @floatFromInt(x)) + 0.5 - cx;
            const py = @as(f32, @floatFromInt(y)) + 0.5 - cy;
            const dist = @sqrt(px * px + py * py);
            writeMax(out, width, x, y, strokeCoverageAlpha(radius, dist, antialias_width_value, true, coverage_boost));
        }
    }
}

fn rasterizePath(path: Path, width: usize, height: usize, out: []u8) bool {
    if (path.point_len < min_fill_path_points or path.subpath_len == 0) return false;
    var painted = false;
    var y: usize = 0;
    while (y < height) : (y += 1) {
        var x: usize = 0;
        while (x < width) : (x += 1) {
            var hits: usize = 0;
            for (fill_sample_offsets) |offset| {
                const point = icon_vector.Point{
                    .x = (@as(f32, @floatFromInt(x)) + offset.x) / @as(f32, @floatFromInt(width)),
                    .y = (@as(f32, @floatFromInt(y)) + offset.y) / @as(f32, @floatFromInt(height)),
                };
                if (pathContainsPoint(&path, point)) hits += 1;
            }
            if (hits != 0) {
                out[y * width + x] = @intCast((hits * 255) / fill_sample_offsets.len);
                painted = true;
            }
        }
    }
    return painted;
}

fn pathContainsPoint(path: *const Path, point: icon_vector.Point) bool {
    return switch (path.fill_rule) {
        .nonzero => pathContainsPointNonzero(path, point),
        .evenodd => pathContainsPointEvenOdd(path, point),
    };
}

fn pathContainsPointNonzero(path: *const Path, point: icon_vector.Point) bool {
    var winding: isize = 0;
    var subpath_index: usize = 0;
    while (subpath_index < path.subpath_len) : (subpath_index += 1) {
        const start = path.subpaths[subpath_index];
        const end = if (subpath_index + 1 < path.subpath_len) path.subpaths[subpath_index + 1] else path.point_len;
        if (end <= start + 1) continue;
        var previous = path.points[end - 1];
        var index = start;
        while (index < end) : (index += 1) {
            const current = path.points[index];
            if (previous.y <= point.y) {
                if (current.y > point.y and isLeftOfEdge(previous, current, point) > 0.0) winding += 1;
            } else if (current.y <= point.y and isLeftOfEdge(previous, current, point) < 0.0) {
                winding -= 1;
            }
            previous = current;
        }
    }
    return winding != 0;
}

fn pathContainsPointEvenOdd(path: *const Path, point: icon_vector.Point) bool {
    var crossings: usize = 0;
    var subpath_index: usize = 0;
    while (subpath_index < path.subpath_len) : (subpath_index += 1) {
        const start = path.subpaths[subpath_index];
        const end = if (subpath_index + 1 < path.subpath_len) path.subpaths[subpath_index + 1] else path.point_len;
        if (end <= start + 1) continue;
        var previous = path.points[end - 1];
        var index = start;
        while (index < end) : (index += 1) {
            const current = path.points[index];
            if ((previous.y > point.y) != (current.y > point.y)) {
                const intersection_x = previous.x + (point.y - previous.y) * (current.x - previous.x) / (current.y - previous.y);
                if (intersection_x > point.x) crossings += 1;
            }
            previous = current;
        }
    }
    return crossings % 2 == 1;
}

fn isLeftOfEdge(start: icon_vector.Point, end: icon_vector.Point, point: icon_vector.Point) f32 {
    return (end.x - start.x) * (point.y - start.y) - (point.x - start.x) * (end.y - start.y);
}



fn iconStroke(width: usize, height: usize, stroke_width: f32) f32 {
    return @max(min_stroke_px, @as(f32, @floatFromInt(@min(width, height))) * stroke_width);
}

fn clampCoord(coord: isize, limit: usize) usize {
    if (coord <= 0) return 0;
    const value: usize = @intCast(coord);
    return @min(value, limit);
}

fn writeMax(out: []u8, width: usize, x: usize, y: usize, alpha: u8) void {
    if (alpha == 0) return;
    const offset = y * width + x;
    out[offset] = @max(out[offset], alpha);
}

fn isSlopedSegment(dx: f32, dy: f32) bool {
    return @abs(dx) > axis_epsilon and @abs(dy) > axis_epsilon;
}

fn strokeCoverageAlpha(radius: f32, distance: f32, antialias_width_value: f32, boost_coverage: bool, coverage_boost: f32) u8 {
    if (distance <= radius - antialias_width_value) return max_alpha;
    if (distance >= radius + antialias_width_value) return 0;
    const t = (radius + antialias_width_value - distance) / (antialias_width_value * 2.0);
    const coverage = if (boost_coverage and t > stroke_coverage_boost_floor)
        t + coverage_boost * (t - stroke_coverage_boost_floor) * (1.0 - t)
    else
        t;
    return @intFromFloat(@round(math.clampF(coverage, 0.0, 1.0) * 255.0));
}

test "icon mask leaves github outline path unpainted" {
    var alpha: [max_pixels]u8 = undefined;
    const mask = try rasterizeIconFill(32, 22, 22, &alpha);
    try std.testing.expect(mask.valid());
    try std.testing.expect(!mask.painted);
    var sum: usize = 0;
    for (mask.alpha) |value| sum += value;
    try std.testing.expectEqual(@as(usize, 0), sum);
}

test "icon mask rasterizes github stroke path" {
    var alpha: [max_pixels]u8 = undefined;
    const mask = try rasterizeIconAlpha(32, 22, 22, &alpha);
    try std.testing.expect(mask.valid());
    try std.testing.expect(mask.painted);
    var sum: usize = 0;
    for (mask.alpha) |value| sum += value;
    try std.testing.expect(sum != 0);
}

test "icon mask rasterizes mapped svg strokes" {
    var icon_id: u32 = 1;
    while (icon_id <= 32) : (icon_id += 1) {
        var alpha: [max_pixels]u8 = undefined;
        const mask = try rasterizeIconAlpha(icon_id, 22, 22, &alpha);
        try std.testing.expect(mask.valid());
        try std.testing.expect(mask.painted);
    }
}

test "icon mask covers code slash parity pixel" {
    var alpha: [max_pixels]u8 = undefined;
    const mask = try rasterizeIconAlpha(7, 22, 22, &alpha);
    try std.testing.expect(mask.painted);
    try std.testing.expectEqual(@as(u8, 21), mask.alpha[6 * 22 + 13]);
}

test "icon mask rasterizes filled path geometry" {
    var alpha: [max_pixels]u8 = undefined;
    @memset(&alpha, 0);
    var path = Path{};
    path.begin(.nonzero);
    path.moveTo(.{ .x = 0.2, .y = 0.2 });
    path.lineTo(.{ .x = 0.8, .y = 0.2 });
    path.lineTo(.{ .x = 0.5, .y = 0.8 });
    path.close();

    try std.testing.expect(rasterizePath(path, 22, 22, alpha[0 .. 22 * 22]));
    var sum: usize = 0;
    for (alpha[0 .. 22 * 22]) |value| sum += value;
    try std.testing.expect(sum != 0);
}
