const std = @import("std");
const icon_vector = @import("../icon_vector.zig");
const renderer_ir = @import("ir.zig");
const ui = @import("../ui.zig");

pub const vertex_float_stride: usize = renderer_ir.icon_line_vertex_float_stride;
pub const vertex_x_index: usize = renderer_ir.icon_line_x_index;
pub const vertex_y_index: usize = renderer_ir.icon_line_y_index;
pub const vertex_color_r_index: usize = renderer_ir.icon_line_color_r_index;
pub const vertex_color_g_index: usize = renderer_ir.icon_line_color_g_index;
pub const vertex_color_b_index: usize = renderer_ir.icon_line_color_b_index;
pub const vertex_color_a_index: usize = renderer_ir.icon_line_color_a_index;
pub const line_vertex_count: usize = 6;
pub const filled_circle_segments: usize = 32;
pub const curve_segments: usize = 32;
pub const min_line_length: f32 = 0.001;
pub const min_stroke_width: f32 = 1.5;
pub const stroke_scale: f32 = 2.0 / 24.0;
pub const half: f32 = 0.5;
pub const quarter_arc_step: f32 = std.math.pi / 32.0;
pub const min_arc_segments: usize = 4;
pub const min_arc_denominator: f32 = 0.000001;
pub const color_channel_max: f32 = 255.0;
pub const max_instance_vertex_count: usize = 16384;
pub const max_instance_float_count: usize = max_instance_vertex_count * vertex_float_stride;

pub const Error = error{
    Budget,
    InvalidBuffer,
    InvalidIconVector,
    InvalidIconSvg,
};

const Point = struct {
    x: f32,
    y: f32,
};

const PathState = struct {
    current: ?icon_vector.Point = null,
    start: ?icon_vector.Point = null,

    fn moveTo(self: *PathState, point: icon_vector.Point) void {
        self.current = point;
        self.start = point;
    }

    fn lineTo(self: *PathState, point: icon_vector.Point) void {
        self.current = point;
    }
};

pub fn packIconInstances(instances: []const f32, out: []f32, out_len: *usize) Error!void {
    out_len.* = 0;
    var iter = renderer_ir.IconIterator.init(instances) catch return error.InvalidBuffer;
    while (iter.next() catch return error.InvalidBuffer) |instance| {
        try packIconInstance(instance, out, out_len);
    }
}

pub fn packIconInstance(instance: renderer_ir.IconInstance, out: []f32, out_len: *usize) Error!void {
    const bounds = instance.bounds;
    var iter = renderer_ir.iconOpIteratorForId(instance.icon_id);
    var path = PathState{};
    while (iter.next() catch return error.InvalidIconSvg) |op| {
        switch (op) {
            .polyline => |points| try polyline(out, out_len, bounds, instance.color, points),
            .circle => |circle| try ellipse(out, out_len, bounds, instance.color, circle.cx, circle.cy, circle.radius, circle.radius, true),
            .ellipse => |value| try ellipse(out, out_len, bounds, instance.color, value.cx, value.cy, value.rx, value.ry, value.full),
            .round_rect => |rect| try box(out, out_len, bounds, instance.color, rect.x, rect.y, rect.w, rect.h),
            .filled_circle => |circle| try filledCircle(out, out_len, bounds, instance.color, circle.cx, circle.cy, circle.radius),
            .filled_ellipse => |value| try ellipse(out, out_len, bounds, instance.color, value.cx, value.cy, value.rx, value.ry, value.full),
            .filled_round_rect => |rect| try box(out, out_len, bounds, instance.color, rect.x, rect.y, rect.w, rect.h),
            .begin_fill_path, .begin_evenodd_fill_path, .end_fill_path, .paint_rgba, .paint_current_color, .paint_current_color_alpha, .paint_linear_gradient, .paint_radial_gradient, .stroke_width, .stroke_cap, .stroke_join, .stroke_miter_limit, .begin_clip_path, .end_clip_path, .clear_clip_path => {},
            .move_to => |point| path.moveTo(point),
            .line_to => |point| {
                if (path.current) |current| try segment(out, out_len, bounds, instance.color, current, point);
                path.lineTo(point);
            },
            .quad_to => |quad| {
                if (path.current) |current| try quadratic(out, out_len, bounds, instance.color, current, quad.control, quad.end);
                path.lineTo(quad.end);
            },
            .cubic_to => |curve| {
                if (path.current) |current| try cubic(out, out_len, bounds, instance.color, current, curve.control0, curve.control1, curve.end);
                path.lineTo(curve.end);
            },
            .arc_to => |curve| {
                if (path.current) |current| try arc(out, out_len, bounds, instance.color, current, curve);
                path.lineTo(curve.end);
            },
            .close_path => if (path.current) |current| if (path.start) |start| {
                try segment(out, out_len, bounds, instance.color, current, start);
                path.lineTo(start);
            },
        }
    }
}

fn polyline(out: []f32, out_len: *usize, bounds: ui.Rect, color: ui.Color, points: []const f32) Error!void {
    if (points.len < 4) return;
    var index: usize = 2;
    while (index < points.len) : (index += 2) {
        try segment(out, out_len, bounds, color, .{ .x = points[index - 2], .y = points[index - 1] }, .{ .x = points[index], .y = points[index + 1] });
    }
}

fn box(out: []f32, out_len: *usize, bounds: ui.Rect, color: ui.Color, x: f32, y: f32, w: f32, h: f32) Error!void {
    try segment(out, out_len, bounds, color, .{ .x = x, .y = y }, .{ .x = x + w, .y = y });
    try segment(out, out_len, bounds, color, .{ .x = x + w, .y = y }, .{ .x = x + w, .y = y + h });
    try segment(out, out_len, bounds, color, .{ .x = x + w, .y = y + h }, .{ .x = x, .y = y + h });
    try segment(out, out_len, bounds, color, .{ .x = x, .y = y + h }, .{ .x = x, .y = y });
}

fn ellipse(out: []f32, out_len: *usize, bounds: ui.Rect, color: ui.Color, cx: f32, cy: f32, rx: f32, ry: f32, full: bool) Error!void {
    const start_turn: f32 = if (full) 0.0 else half;
    const span = 1.0 - start_turn;
    var previous = icon_vector.Point{
        .x = cx + @cos(start_turn * std.math.tau) * rx,
        .y = cy + @sin(start_turn * std.math.tau) * ry,
    };
    var index: usize = 1;
    while (index <= filled_circle_segments) : (index += 1) {
        const turn = start_turn + @as(f32, @floatFromInt(index)) * span / @as(f32, @floatFromInt(filled_circle_segments));
        const angle = turn * std.math.tau;
        const next = icon_vector.Point{ .x = cx + @cos(angle) * rx, .y = cy + @sin(angle) * ry };
        try segment(out, out_len, bounds, color, previous, next);
        previous = next;
    }
}

fn filledCircle(out: []f32, out_len: *usize, bounds: ui.Rect, color: ui.Color, cx: f32, cy: f32, radius: f32) Error!void {
    const size = @min(bounds.w, bounds.h);
    const center = Point{ .x = bounds.x + bounds.w * cx, .y = bounds.y + bounds.h * cy };
    const scaled_radius = size * radius;
    var index: usize = 0;
    while (index < filled_circle_segments) : (index += 1) {
        const a0 = @as(f32, @floatFromInt(index)) * std.math.tau / @as(f32, @floatFromInt(filled_circle_segments));
        const a1 = @as(f32, @floatFromInt(index + 1)) * std.math.tau / @as(f32, @floatFromInt(filled_circle_segments));
        try vertex(out, out_len, center.x, center.y, color);
        try vertex(out, out_len, center.x + @cos(a0) * scaled_radius, center.y + @sin(a0) * scaled_radius, color);
        try vertex(out, out_len, center.x + @cos(a1) * scaled_radius, center.y + @sin(a1) * scaled_radius, color);
    }
}

fn quadratic(out: []f32, out_len: *usize, bounds: ui.Rect, color: ui.Color, start: icon_vector.Point, control: icon_vector.Point, end: icon_vector.Point) Error!void {
    var previous = start;
    var step: usize = 1;
    while (step <= curve_segments) : (step += 1) {
        const t = @as(f32, @floatFromInt(step)) / @as(f32, @floatFromInt(curve_segments));
        const mt = 1.0 - t;
        const next = icon_vector.Point{
            .x = mt * mt * start.x + 2.0 * mt * t * control.x + t * t * end.x,
            .y = mt * mt * start.y + 2.0 * mt * t * control.y + t * t * end.y,
        };
        try segment(out, out_len, bounds, color, previous, next);
        previous = next;
    }
}

fn cubic(out: []f32, out_len: *usize, bounds: ui.Rect, color: ui.Color, start: icon_vector.Point, control0: icon_vector.Point, control1: icon_vector.Point, end: icon_vector.Point) Error!void {
    var previous = start;
    var step: usize = 1;
    while (step <= curve_segments) : (step += 1) {
        const t = @as(f32, @floatFromInt(step)) / @as(f32, @floatFromInt(curve_segments));
        const mt = 1.0 - t;
        const next = icon_vector.Point{
            .x = mt * mt * mt * start.x + 3.0 * mt * mt * t * control0.x + 3.0 * mt * t * t * control1.x + t * t * t * end.x,
            .y = mt * mt * mt * start.y + 3.0 * mt * mt * t * control0.y + 3.0 * mt * t * t * control1.y + t * t * t * end.y,
        };
        try segment(out, out_len, bounds, color, previous, next);
        previous = next;
    }
}

fn arc(out: []f32, out_len: *usize, bounds: ui.Rect, color: ui.Color, start: icon_vector.Point, value: icon_vector.Arc) Error!void {
    var rx = @abs(value.rx);
    var ry = @abs(value.ry);
    if (rx == 0.0 or ry == 0.0) {
        try segment(out, out_len, bounds, color, start, value.end);
        return;
    }
    const phi = value.x_axis_rotation * std.math.pi / 180.0;
    const cos_phi = @cos(phi);
    const sin_phi = @sin(phi);
    const dx = (start.x - value.end.x) * half;
    const dy = (start.y - value.end.y) * half;
    const x1p = cos_phi * dx + sin_phi * dy;
    const y1p = -sin_phi * dx + cos_phi * dy;
    const radius_scale = x1p * x1p / (rx * rx) + y1p * y1p / (ry * ry);
    if (radius_scale > 1.0) {
        const scale = @sqrt(radius_scale);
        rx *= scale;
        ry *= scale;
    }
    const numerator = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p;
    const denominator = rx * rx * y1p * y1p + ry * ry * x1p * x1p;
    const sign: f32 = if (value.large_arc == value.sweep) 1.0 else -1.0;
    const coefficient = sign * @sqrt(@max(0.0, numerator / @max(denominator, min_arc_denominator)));
    const cxp = coefficient * rx * y1p / ry;
    const cyp = coefficient * -ry * x1p / rx;
    const center = icon_vector.Point{
        .x = cos_phi * cxp - sin_phi * cyp + (start.x + value.end.x) * half,
        .y = sin_phi * cxp + cos_phi * cyp + (start.y + value.end.y) * half,
    };
    const v0 = icon_vector.Point{ .x = (x1p - cxp) / rx, .y = (y1p - cyp) / ry };
    const v1 = icon_vector.Point{ .x = (-x1p - cxp) / rx, .y = (-y1p - cyp) / ry };
    const start_angle = vectorAngle(.{ .x = 1.0, .y = 0.0 }, v0);
    var delta = vectorAngle(v0, v1);
    if (!value.sweep and delta > 0.0) delta -= std.math.tau;
    if (value.sweep and delta < 0.0) delta += std.math.tau;
    const steps: usize = @max(min_arc_segments, @as(usize, @intFromFloat(@ceil(@abs(delta) / quarter_arc_step))));
    var previous = start;
    var step: usize = 1;
    while (step <= steps) : (step += 1) {
        const angle = start_angle + delta * @as(f32, @floatFromInt(step)) / @as(f32, @floatFromInt(steps));
        const xp = rx * @cos(angle);
        const yp = ry * @sin(angle);
        const next = icon_vector.Point{
            .x = center.x + cos_phi * xp - sin_phi * yp,
            .y = center.y + sin_phi * xp + cos_phi * yp,
        };
        try segment(out, out_len, bounds, color, previous, next);
        previous = next;
    }
}

fn segment(out: []f32, out_len: *usize, bounds: ui.Rect, color: ui.Color, start: icon_vector.Point, end: icon_vector.Point) Error!void {
    const x0 = bounds.x + bounds.w * start.x;
    const y0 = bounds.y + bounds.h * start.y;
    const x1 = bounds.x + bounds.w * end.x;
    const y1 = bounds.y + bounds.h * end.y;
    const dx = x1 - x0;
    const dy = y1 - y0;
    const length = @sqrt(dx * dx + dy * dy);
    if (length <= min_line_length) return;
    const width = @max(min_stroke_width, @min(bounds.w, bounds.h) * stroke_scale);
    const nx = -dy / length * width * half;
    const ny = dx / length * width * half;
    try vertex(out, out_len, x0 + nx, y0 + ny, color);
    try vertex(out, out_len, x1 + nx, y1 + ny, color);
    try vertex(out, out_len, x1 - nx, y1 - ny, color);
    try vertex(out, out_len, x0 + nx, y0 + ny, color);
    try vertex(out, out_len, x1 - nx, y1 - ny, color);
    try vertex(out, out_len, x0 - nx, y0 - ny, color);
}

fn vertex(out: []f32, out_len: *usize, x: f32, y: f32, color: ui.Color) Error!void {
    if (out_len.* + vertex_float_stride > out.len) return error.Budget;
    const values = [_]f32{
        x,
        y,
        channel(color.r),
        channel(color.g),
        channel(color.b),
        channel(color.a),
    };
    @memcpy(out[out_len.* .. out_len.* + vertex_float_stride], &values);
    out_len.* += vertex_float_stride;
}

fn vectorAngle(left: icon_vector.Point, right: icon_vector.Point) f32 {
    const dot = left.x * right.x + left.y * right.y;
    const det = left.x * right.y - left.y * right.x;
    return std.math.atan2(det, dot);
}

fn channel(value: u8) f32 {
    return @as(f32, @floatFromInt(value)) / color_channel_max;
}

test "icon line buffer packs browser-ready vertices" {
    var instances_storage = renderer_ir.FixedBuffers(0, 0, 1, 0, 0, 0, 0, 0, 0){};
    try renderer_ir.pushIcon(instances_storage.buffers(), .base, .{
        .bounds = ui.Rect.init(10, 20, 24, 24),
        .color = .accent,
        .icon_id = @intFromEnum(@import("../icon.zig").Icon.search) + 1,
    });
    var out: [line_vertex_count * vertex_float_stride * filled_circle_segments * 8]f32 = undefined;
    var out_len: usize = 0;
    try packIconInstances(instances_storage.buffers().liveIconVertices(), &out, &out_len);
    try std.testing.expect(out_len > 0);
    try std.testing.expectEqual(@as(usize, 0), out_len % vertex_float_stride);
}

test "icon line buffer publishes packed vertex layout" {
    try std.testing.expectEqual(@as(usize, 6), vertex_float_stride);
    try std.testing.expectEqual(@as(usize, 0), vertex_x_index);
    try std.testing.expectEqual(@as(usize, 1), vertex_y_index);
    try std.testing.expectEqual(@as(usize, 2), vertex_color_r_index);
    try std.testing.expectEqual(@as(usize, 3), vertex_color_g_index);
    try std.testing.expectEqual(@as(usize, 4), vertex_color_b_index);
    try std.testing.expectEqual(vertex_float_stride - 1, vertex_color_a_index);
}

test "single icon line buffer budget fits built in icons" {
    const icon = @import("../icon.zig");
    var out: [max_instance_float_count]f32 = undefined;
    inline for (@typeInfo(icon.Icon).@"enum".fields) |field| {
        const value: icon.Icon = @enumFromInt(field.value);
        var out_len: usize = 0;
        try packIconInstance(.{
            .bounds = ui.Rect.init(0, 0, 24, 24),
            .color = .accent,
            .icon_id = @intFromEnum(value) + 1,
        }, &out, &out_len);
        try std.testing.expectEqual(@as(usize, 0), out_len % vertex_float_stride);
        try std.testing.expect(out_len <= max_instance_float_count);
    }
}
