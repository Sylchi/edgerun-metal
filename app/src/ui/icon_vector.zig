const math = @import("../math.zig");

pub const op_polyline: f32 = 1.0;
pub const op_circle: f32 = 2.0;
pub const op_ellipse: f32 = 3.0;
pub const op_round_rect: f32 = 4.0;
pub const op_filled_circle: f32 = 5.0;
pub const op_move_to: f32 = 6.0;
pub const op_line_to: f32 = 7.0;
pub const op_quad_to: f32 = 8.0;
pub const op_cubic_to: f32 = 9.0;
pub const op_arc_to: f32 = 10.0;
pub const op_close_path: f32 = 11.0;
pub const op_filled_ellipse: f32 = 12.0;
pub const op_filled_round_rect: f32 = 13.0;
pub const op_begin_fill_path: f32 = 14.0;
pub const op_end_fill_path: f32 = 15.0;
pub const op_begin_evenodd_fill_path: f32 = 16.0;
pub const op_paint_rgba: f32 = 17.0;
pub const op_paint_current_color: f32 = 18.0;
pub const op_paint_linear_gradient: f32 = 19.0;
pub const op_paint_radial_gradient: f32 = 20.0;
pub const op_paint_current_color_alpha: f32 = 21.0;
pub const op_stroke_width: f32 = 22.0;
pub const op_stroke_cap: f32 = 23.0;
pub const op_stroke_join: f32 = 24.0;
pub const op_stroke_miter_limit: f32 = 25.0;
pub const op_begin_clip_path: f32 = 26.0;
pub const op_end_clip_path: f32 = 27.0;
pub const op_clear_clip_path: f32 = 28.0;

pub const min_op_len: usize = 1;
pub const polyline_header_len: usize = 2;
pub const polyline_min_points: usize = 2;
pub const point_float_count: usize = 2;
pub const circle_len: usize = 4;
pub const ellipse_len: usize = 6;
pub const round_rect_len: usize = 6;
pub const filled_circle_len: usize = 4;
pub const move_to_len: usize = 3;
pub const line_to_len: usize = 3;
pub const quad_to_len: usize = 5;
pub const cubic_to_len: usize = 7;
pub const arc_to_len: usize = 8;
pub const close_path_len: usize = 1;
pub const filled_ellipse_len: usize = 6;
pub const filled_round_rect_len: usize = 6;
pub const begin_fill_path_len: usize = 1;
pub const end_fill_path_len: usize = 1;
pub const begin_evenodd_fill_path_len: usize = 1;
pub const paint_rgba_len: usize = 5;
pub const paint_current_color_len: usize = 1;
pub const paint_current_color_alpha_len: usize = 2;
pub const stroke_width_len: usize = 2;
pub const stroke_cap_len: usize = 2;
pub const stroke_join_len: usize = 2;
pub const stroke_miter_limit_len: usize = 2;
pub const begin_clip_path_len: usize = 1;
pub const end_clip_path_len: usize = 1;
pub const clear_clip_path_len: usize = 1;
pub const paint_linear_gradient_base_len: usize = 8;
pub const paint_radial_gradient_base_len: usize = 10;
pub const linear_gradient_stop_len: usize = 5;
pub const max_linear_gradient_stops: usize = 8;

pub const Iterator = struct {
    values: []const f32,
    index: usize = 0,

    pub fn init(values: []const f32) Iterator {
        return .{ .values = values };
    }

    pub fn next(self: *Iterator) !?Op {
        if (self.index == self.values.len) return null;
        if (self.index > self.values.len) return error.InvalidIconVector;

        const kind = self.values[self.index];
        if (kind == op_polyline) {
            if (self.index + polyline_header_len > self.values.len) return error.InvalidIconVector;
            const count_f = self.values[self.index + 1];
            if (count_f < @as(f32, @floatFromInt(polyline_min_points))) return error.InvalidIconVector;
            const count: usize = @intFromFloat(count_f);
            if (@as(f32, @floatFromInt(count)) != count_f) return error.InvalidIconVector;
            const point_values = count * point_float_count;
            const start = self.index + polyline_header_len;
            const end = start + point_values;
            if (end > self.values.len) return error.InvalidIconVector;
            self.index = end;
            return .{ .polyline = self.values[start..end] };
        }
        if (kind == op_circle) {
            if (self.index + circle_len > self.values.len) return error.InvalidIconVector;
            const start = self.index + 1;
            self.index += circle_len;
            return .{ .circle = .{
                .cx = self.values[start],
                .cy = self.values[start + 1],
                .radius = self.values[start + 2],
            } };
        }
        if (kind == op_ellipse) {
            if (self.index + ellipse_len > self.values.len) return error.InvalidIconVector;
            const start = self.index + 1;
            self.index += ellipse_len;
            return .{ .ellipse = .{
                .cx = self.values[start],
                .cy = self.values[start + 1],
                .rx = self.values[start + 2],
                .ry = self.values[start + 3],
                .full = self.values[start + 4] != 0.0,
            } };
        }
        if (kind == op_round_rect) {
            if (self.index + round_rect_len > self.values.len) return error.InvalidIconVector;
            const start = self.index + 1;
            self.index += round_rect_len;
            return .{ .round_rect = .{
                .x = self.values[start],
                .y = self.values[start + 1],
                .w = self.values[start + 2],
                .h = self.values[start + 3],
                .radius = self.values[start + 4],
            } };
        }
        if (kind == op_filled_circle) {
            if (self.index + filled_circle_len > self.values.len) return error.InvalidIconVector;
            const start = self.index + 1;
            self.index += filled_circle_len;
            return .{ .filled_circle = .{
                .cx = self.values[start],
                .cy = self.values[start + 1],
                .radius = self.values[start + 2],
            } };
        }
        if (kind == op_move_to) {
            if (self.index + move_to_len > self.values.len) return error.InvalidIconVector;
            const start = self.index + 1;
            self.index += move_to_len;
            return .{ .move_to = .{ .x = self.values[start], .y = self.values[start + 1] } };
        }
        if (kind == op_line_to) {
            if (self.index + line_to_len > self.values.len) return error.InvalidIconVector;
            const start = self.index + 1;
            self.index += line_to_len;
            return .{ .line_to = .{ .x = self.values[start], .y = self.values[start + 1] } };
        }
        if (kind == op_quad_to) {
            if (self.index + quad_to_len > self.values.len) return error.InvalidIconVector;
            const start = self.index + 1;
            self.index += quad_to_len;
            return .{ .quad_to = .{
                .control = .{ .x = self.values[start], .y = self.values[start + 1] },
                .end = .{ .x = self.values[start + 2], .y = self.values[start + 3] },
            } };
        }
        if (kind == op_cubic_to) {
            if (self.index + cubic_to_len > self.values.len) return error.InvalidIconVector;
            const start = self.index + 1;
            self.index += cubic_to_len;
            return .{ .cubic_to = .{
                .control0 = .{ .x = self.values[start], .y = self.values[start + 1] },
                .control1 = .{ .x = self.values[start + 2], .y = self.values[start + 3] },
                .end = .{ .x = self.values[start + 4], .y = self.values[start + 5] },
            } };
        }
        if (kind == op_arc_to) {
            if (self.index + arc_to_len > self.values.len) return error.InvalidIconVector;
            const start = self.index + 1;
            self.index += arc_to_len;
            return .{ .arc_to = .{
                .rx = self.values[start],
                .ry = self.values[start + 1],
                .x_axis_rotation = self.values[start + 2],
                .large_arc = self.values[start + 3] != 0.0,
                .sweep = self.values[start + 4] != 0.0,
                .end = .{ .x = self.values[start + 5], .y = self.values[start + 6] },
            } };
        }
        if (kind == op_close_path) {
            if (self.index + close_path_len > self.values.len) return error.InvalidIconVector;
            self.index += close_path_len;
            return .close_path;
        }
        if (kind == op_filled_ellipse) {
            if (self.index + filled_ellipse_len > self.values.len) return error.InvalidIconVector;
            const start = self.index + 1;
            self.index += filled_ellipse_len;
            return .{ .filled_ellipse = .{
                .cx = self.values[start],
                .cy = self.values[start + 1],
                .rx = self.values[start + 2],
                .ry = self.values[start + 3],
                .full = self.values[start + 4] != 0.0,
            } };
        }
        if (kind == op_filled_round_rect) {
            if (self.index + filled_round_rect_len > self.values.len) return error.InvalidIconVector;
            const start = self.index + 1;
            self.index += filled_round_rect_len;
            return .{ .filled_round_rect = .{
                .x = self.values[start],
                .y = self.values[start + 1],
                .w = self.values[start + 2],
                .h = self.values[start + 3],
                .radius = self.values[start + 4],
            } };
        }
        if (kind == op_begin_fill_path) {
            if (self.index + begin_fill_path_len > self.values.len) return error.InvalidIconVector;
            self.index += begin_fill_path_len;
            return .begin_fill_path;
        }
        if (kind == op_end_fill_path) {
            if (self.index + end_fill_path_len > self.values.len) return error.InvalidIconVector;
            self.index += end_fill_path_len;
            return .end_fill_path;
        }
        if (kind == op_begin_evenodd_fill_path) {
            if (self.index + begin_evenodd_fill_path_len > self.values.len) return error.InvalidIconVector;
            self.index += begin_evenodd_fill_path_len;
            return .begin_evenodd_fill_path;
        }
        if (kind == op_paint_rgba) {
            if (self.index + paint_rgba_len > self.values.len) return error.InvalidIconVector;
            const start = self.index + 1;
            self.index += paint_rgba_len;
            return .{ .paint_rgba = .{
                .r = byteFromFloat(self.values[start]) orelse return error.InvalidIconVector,
                .g = byteFromFloat(self.values[start + 1]) orelse return error.InvalidIconVector,
                .b = byteFromFloat(self.values[start + 2]) orelse return error.InvalidIconVector,
                .a = byteFromFloat(self.values[start + 3]) orelse return error.InvalidIconVector,
            } };
        }
        if (kind == op_paint_current_color) {
            if (self.index + paint_current_color_len > self.values.len) return error.InvalidIconVector;
            self.index += paint_current_color_len;
            return .paint_current_color;
        }
        if (kind == op_paint_current_color_alpha) {
            if (self.index + paint_current_color_alpha_len > self.values.len) return error.InvalidIconVector;
            const start = self.index + 1;
            self.index += paint_current_color_alpha_len;
            return .{ .paint_current_color_alpha = byteFromFloat(self.values[start]) orelse return error.InvalidIconVector };
        }
        if (kind == op_stroke_width) {
            if (self.index + stroke_width_len > self.values.len) return error.InvalidIconVector;
            const start = self.index + 1;
            self.index += stroke_width_len;
            const width = self.values[start];
            if (!math.isFiniteF(width) or width <= 0.0) return error.InvalidIconVector;
            return .{ .stroke_width = width };
        }
        if (kind == op_stroke_cap) {
            if (self.index + stroke_cap_len > self.values.len) return error.InvalidIconVector;
            const start = self.index + 1;
            self.index += stroke_cap_len;
            return .{ .stroke_cap = strokeCapFromFloat(self.values[start]) orelse return error.InvalidIconVector };
        }
        if (kind == op_stroke_join) {
            if (self.index + stroke_join_len > self.values.len) return error.InvalidIconVector;
            const start = self.index + 1;
            self.index += stroke_join_len;
            return .{ .stroke_join = strokeJoinFromFloat(self.values[start]) orelse return error.InvalidIconVector };
        }
        if (kind == op_stroke_miter_limit) {
            if (self.index + stroke_miter_limit_len > self.values.len) return error.InvalidIconVector;
            const start = self.index + 1;
            self.index += stroke_miter_limit_len;
            const limit = self.values[start];
            if (!math.isFiniteF(limit) or limit < 1.0) return error.InvalidIconVector;
            return .{ .stroke_miter_limit = limit };
        }
        if (kind == op_begin_clip_path) {
            if (self.index + begin_clip_path_len > self.values.len) return error.InvalidIconVector;
            self.index += begin_clip_path_len;
            return .begin_clip_path;
        }
        if (kind == op_end_clip_path) {
            if (self.index + end_clip_path_len > self.values.len) return error.InvalidIconVector;
            self.index += end_clip_path_len;
            return .end_clip_path;
        }
        if (kind == op_clear_clip_path) {
            if (self.index + clear_clip_path_len > self.values.len) return error.InvalidIconVector;
            self.index += clear_clip_path_len;
            return .clear_clip_path;
        }
        if (kind == op_paint_linear_gradient) {
            if (self.index + paint_linear_gradient_base_len > self.values.len) return error.InvalidIconVector;
            const start = self.index + 1;
            const stop_count_f = self.values[start + 6];
            const stop_count: usize = @intFromFloat(stop_count_f);
            if (@as(f32, @floatFromInt(stop_count)) != stop_count_f) return error.InvalidIconVector;
            if (stop_count < min_linear_gradient_stops or stop_count > max_linear_gradient_stops) return error.InvalidIconVector;
            const total_len = paint_linear_gradient_base_len + stop_count * linear_gradient_stop_len;
            if (self.index + total_len > self.values.len) return error.InvalidIconVector;
            var stops = [_]LinearGradientStop{.{ .offset = 0.0, .color = .{ .r = 0, .g = 0, .b = 0, .a = 0 } }} ** max_linear_gradient_stops;
            var stop_index: usize = 0;
            while (stop_index < stop_count) : (stop_index += 1) {
                const stop_start = start + 7 + stop_index * linear_gradient_stop_len;
                stops[stop_index] = .{
                    .offset = self.values[stop_start],
                    .color = .{
                        .r = byteFromFloat(self.values[stop_start + 1]) orelse return error.InvalidIconVector,
                        .g = byteFromFloat(self.values[stop_start + 2]) orelse return error.InvalidIconVector,
                        .b = byteFromFloat(self.values[stop_start + 3]) orelse return error.InvalidIconVector,
                        .a = byteFromFloat(self.values[stop_start + 4]) orelse return error.InvalidIconVector,
                    },
                };
            }
            self.index += total_len;
            const gradient = LinearGradient{
                .coordinate_space = gradientCoordinateSpaceFromFloat(self.values[start]) orelse return error.InvalidIconVector,
                .spread = gradientSpreadMethodFromFloat(self.values[start + 1]) orelse return error.InvalidIconVector,
                .x1 = self.values[start + 2],
                .y1 = self.values[start + 3],
                .x2 = self.values[start + 4],
                .y2 = self.values[start + 5],
                .stop_count = stop_count,
                .stops = stops,
            };
            return .{ .paint_linear_gradient = gradient };
        }
        if (kind == op_paint_radial_gradient) {
            if (self.index + paint_radial_gradient_base_len > self.values.len) return error.InvalidIconVector;
            const start = self.index + 1;
            const stop_count_f = self.values[start + 8];
            const stop_count: usize = @intFromFloat(stop_count_f);
            if (@as(f32, @floatFromInt(stop_count)) != stop_count_f) return error.InvalidIconVector;
            if (stop_count < min_linear_gradient_stops or stop_count > max_linear_gradient_stops) return error.InvalidIconVector;
            const total_len = paint_radial_gradient_base_len + stop_count * linear_gradient_stop_len;
            if (self.index + total_len > self.values.len) return error.InvalidIconVector;
            var stops = [_]LinearGradientStop{.{ .offset = 0.0, .color = .{ .r = 0, .g = 0, .b = 0, .a = 0 } }} ** max_linear_gradient_stops;
            var stop_index: usize = 0;
            while (stop_index < stop_count) : (stop_index += 1) {
                const stop_start = start + 9 + stop_index * linear_gradient_stop_len;
                stops[stop_index] = .{
                    .offset = self.values[stop_start],
                    .color = .{
                        .r = byteFromFloat(self.values[stop_start + 1]) orelse return error.InvalidIconVector,
                        .g = byteFromFloat(self.values[stop_start + 2]) orelse return error.InvalidIconVector,
                        .b = byteFromFloat(self.values[stop_start + 3]) orelse return error.InvalidIconVector,
                        .a = byteFromFloat(self.values[stop_start + 4]) orelse return error.InvalidIconVector,
                    },
                };
            }
            self.index += total_len;
            const gradient = RadialGradient{
                .coordinate_space = gradientCoordinateSpaceFromFloat(self.values[start]) orelse return error.InvalidIconVector,
                .spread = gradientSpreadMethodFromFloat(self.values[start + 1]) orelse return error.InvalidIconVector,
                .cx = self.values[start + 2],
                .cy = self.values[start + 3],
                .radius = self.values[start + 4],
                .fx = self.values[start + 5],
                .fy = self.values[start + 6],
                .focal_radius = self.values[start + 7],
                .stop_count = stop_count,
                .stops = stops,
            };
            return .{ .paint_radial_gradient = gradient };
        }
        return error.InvalidIconVector;
    }
};

pub const Op = union(enum) {
    polyline: []const f32,
    circle: Circle,
    ellipse: Ellipse,
    round_rect: RoundRect,
    filled_circle: Circle,
    move_to: Point,
    line_to: Point,
    quad_to: Quadratic,
    cubic_to: Cubic,
    arc_to: Arc,
    close_path,
    filled_ellipse: Ellipse,
    filled_round_rect: RoundRect,
    begin_fill_path,
    begin_evenodd_fill_path,
    end_fill_path,
    paint_rgba: Paint,
    paint_current_color,
    paint_current_color_alpha: u8,
    paint_linear_gradient: LinearGradient,
    paint_radial_gradient: RadialGradient,
    stroke_width: f32,
    stroke_cap: StrokeCap,
    stroke_join: StrokeJoin,
    stroke_miter_limit: f32,
    begin_clip_path,
    end_clip_path,
    clear_clip_path,
};

pub const Paint = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

pub const LinearGradient = struct {
    coordinate_space: GradientCoordinateSpace,
    spread: GradientSpreadMethod,
    x1: f32,
    y1: f32,
    x2: f32,
    y2: f32,
    stop_count: usize,
    stops: [max_linear_gradient_stops]LinearGradientStop,
};

pub const RadialGradient = struct {
    coordinate_space: GradientCoordinateSpace,
    spread: GradientSpreadMethod,
    cx: f32,
    cy: f32,
    radius: f32,
    fx: f32,
    fy: f32,
    focal_radius: f32,
    stop_count: usize,
    stops: [max_linear_gradient_stops]LinearGradientStop,
};

pub const LinearGradientStop = struct {
    offset: f32,
    color: Paint,
};

pub const GradientCoordinateSpace = enum(u8) {
    object_bounding_box = 0,
    user_space = 1,
};

pub const GradientSpreadMethod = enum(u8) {
    pad = 0,
    repeat = 1,
    reflect = 2,
};

pub const StrokeCap = enum(u8) {
    butt = 0,
    round = 1,
    square = 2,
};

pub const StrokeJoin = enum(u8) {
    miter = 0,
    round = 1,
    bevel = 2,
};

pub const min_linear_gradient_stops: usize = 2;

fn gradientCoordinateSpaceFromFloat(value: f32) ?GradientCoordinateSpace {
    if (value == @as(f32, @floatFromInt(@intFromEnum(GradientCoordinateSpace.object_bounding_box)))) return .object_bounding_box;
    if (value == @as(f32, @floatFromInt(@intFromEnum(GradientCoordinateSpace.user_space)))) return .user_space;
    return null;
}

fn gradientSpreadMethodFromFloat(value: f32) ?GradientSpreadMethod {
    if (value == @as(f32, @floatFromInt(@intFromEnum(GradientSpreadMethod.pad)))) return .pad;
    if (value == @as(f32, @floatFromInt(@intFromEnum(GradientSpreadMethod.repeat)))) return .repeat;
    if (value == @as(f32, @floatFromInt(@intFromEnum(GradientSpreadMethod.reflect)))) return .reflect;
    return null;
}

fn strokeCapFromFloat(value: f32) ?StrokeCap {
    if (value == @as(f32, @floatFromInt(@intFromEnum(StrokeCap.butt)))) return .butt;
    if (value == @as(f32, @floatFromInt(@intFromEnum(StrokeCap.round)))) return .round;
    if (value == @as(f32, @floatFromInt(@intFromEnum(StrokeCap.square)))) return .square;
    return null;
}

fn strokeJoinFromFloat(value: f32) ?StrokeJoin {
    if (value == @as(f32, @floatFromInt(@intFromEnum(StrokeJoin.miter)))) return .miter;
    if (value == @as(f32, @floatFromInt(@intFromEnum(StrokeJoin.round)))) return .round;
    if (value == @as(f32, @floatFromInt(@intFromEnum(StrokeJoin.bevel)))) return .bevel;
    return null;
}

pub const Point = struct {
    x: f32,
    y: f32,
};

pub const Circle = struct {
    cx: f32,
    cy: f32,
    radius: f32,
};

pub const Ellipse = struct {
    cx: f32,
    cy: f32,
    rx: f32,
    ry: f32,
    full: bool,
};

pub const RoundRect = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
    radius: f32,
};

pub const Quadratic = struct {
    control: Point,
    end: Point,
};

pub const Cubic = struct {
    control0: Point,
    control1: Point,
    end: Point,
};

pub const Arc = struct {
    rx: f32,
    ry: f32,
    x_axis_rotation: f32,
    large_arc: bool,
    sweep: bool,
    end: Point,
};

fn byteFromFloat(value: f32) ?u8 {
    if (value < 0.0 or value > 255.0) return null;
    const as_int: u8 = @intFromFloat(value);
    if (@as(f32, @floatFromInt(as_int)) != value) return null;
    return as_int;
}


test "iterator decodes linear gradient paint op" {
    const std = @import("er_std");
    const values = [_]f32{
        op_paint_linear_gradient,
        @floatFromInt(@intFromEnum(GradientCoordinateSpace.user_space)),
        @floatFromInt(@intFromEnum(GradientSpreadMethod.reflect)),
        0.0,
        0.0,
        1.0,
        0.0,
        3.0,
        0.0,
        255.0,
        0.0,
        0.0,
        255.0,
        0.5,
        0.0,
        255.0,
        0.0,
        255.0,
        1.0,
        0.0,
        0.0,
        255.0,
        128.0,
    };
    var iter = Iterator.init(&values);

    try std.testing.expectEqual(Op{ .paint_linear_gradient = .{
        .coordinate_space = .user_space,
        .spread = .reflect,
        .x1 = 0.0,
        .y1 = 0.0,
        .x2 = 1.0,
        .y2 = 0.0,
        .stop_count = 3,
        .stops = [_]LinearGradientStop{
            .{ .offset = 0.0, .color = .{ .r = 255, .g = 0, .b = 0, .a = 255 } },
            .{ .offset = 0.5, .color = .{ .r = 0, .g = 255, .b = 0, .a = 255 } },
            .{ .offset = 1.0, .color = .{ .r = 0, .g = 0, .b = 255, .a = 128 } },
            .{ .offset = 0.0, .color = .{ .r = 0, .g = 0, .b = 0, .a = 0 } },
            .{ .offset = 0.0, .color = .{ .r = 0, .g = 0, .b = 0, .a = 0 } },
            .{ .offset = 0.0, .color = .{ .r = 0, .g = 0, .b = 0, .a = 0 } },
            .{ .offset = 0.0, .color = .{ .r = 0, .g = 0, .b = 0, .a = 0 } },
            .{ .offset = 0.0, .color = .{ .r = 0, .g = 0, .b = 0, .a = 0 } },
        },
    } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?Op, null), try iter.next());
}

test "iterator decodes radial gradient paint op" {
    const std = @import("er_std");
    const values = [_]f32{
        op_paint_radial_gradient,
        @floatFromInt(@intFromEnum(GradientCoordinateSpace.object_bounding_box)),
        @floatFromInt(@intFromEnum(GradientSpreadMethod.repeat)),
        0.5,
        0.5,
        0.5,
        0.25,
        0.75,
        0.125,
        2.0,
        0.0,
        255.0,
        255.0,
        255.0,
        255.0,
        1.0,
        0.0,
        0.0,
        0.0,
        255.0,
    };
    var iter = Iterator.init(&values);

    try std.testing.expectEqual(Op{ .paint_radial_gradient = .{
        .coordinate_space = .object_bounding_box,
        .spread = .repeat,
        .cx = 0.5,
        .cy = 0.5,
        .radius = 0.5,
        .fx = 0.25,
        .fy = 0.75,
        .focal_radius = 0.125,
        .stop_count = 2,
        .stops = [_]LinearGradientStop{
            .{ .offset = 0.0, .color = .{ .r = 255, .g = 255, .b = 255, .a = 255 } },
            .{ .offset = 1.0, .color = .{ .r = 0, .g = 0, .b = 0, .a = 255 } },
            .{ .offset = 0.0, .color = .{ .r = 0, .g = 0, .b = 0, .a = 0 } },
            .{ .offset = 0.0, .color = .{ .r = 0, .g = 0, .b = 0, .a = 0 } },
            .{ .offset = 0.0, .color = .{ .r = 0, .g = 0, .b = 0, .a = 0 } },
            .{ .offset = 0.0, .color = .{ .r = 0, .g = 0, .b = 0, .a = 0 } },
            .{ .offset = 0.0, .color = .{ .r = 0, .g = 0, .b = 0, .a = 0 } },
            .{ .offset = 0.0, .color = .{ .r = 0, .g = 0, .b = 0, .a = 0 } },
        },
    } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?Op, null), try iter.next());
}

test "iterator decodes current color alpha paint op" {
    const std = @import("er_std");
    const values = [_]f32{
        op_paint_current_color_alpha,
        128.0,
    };
    var iter = Iterator.init(&values);

    try std.testing.expectEqual(Op{ .paint_current_color_alpha = 128 }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?Op, null), try iter.next());
}

test "iterator decodes stroke width op" {
    const std = @import("er_std");
    const values = [_]f32{
        op_stroke_width,
        1.5 / 24.0,
    };
    var iter = Iterator.init(&values);

    try std.testing.expectEqual(Op{ .stroke_width = 1.5 / 24.0 }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?Op, null), try iter.next());
}

test "iterator decodes stroke cap op" {
    const std = @import("er_std");
    const values = [_]f32{
        op_stroke_cap,
        @floatFromInt(@intFromEnum(StrokeCap.square)),
    };
    var iter = Iterator.init(&values);

    try std.testing.expectEqual(Op{ .stroke_cap = .square }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?Op, null), try iter.next());
}

test "iterator decodes stroke join op" {
    const std = @import("er_std");
    const values = [_]f32{
        op_stroke_join,
        @floatFromInt(@intFromEnum(StrokeJoin.bevel)),
    };
    var iter = Iterator.init(&values);

    try std.testing.expectEqual(Op{ .stroke_join = .bevel }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?Op, null), try iter.next());
}

test "iterator decodes stroke miter limit op" {
    const std = @import("er_std");
    const values = [_]f32{
        op_stroke_miter_limit,
        2.5,
    };
    var iter = Iterator.init(&values);

    try std.testing.expectEqual(Op{ .stroke_miter_limit = 2.5 }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?Op, null), try iter.next());
}

test "iterator decodes clip path control ops" {
    const std = @import("er_std");
    const values = [_]f32{
        op_begin_clip_path,
        op_end_clip_path,
        op_clear_clip_path,
    };
    var iter = Iterator.init(&values);

    switch ((try iter.next()).?) {
        .begin_clip_path => {},
        else => return error.TestExpectedEqual,
    }
    switch ((try iter.next()).?) {
        .end_clip_path => {},
        else => return error.TestExpectedEqual,
    }
    switch ((try iter.next()).?) {
        .clear_clip_path => {},
        else => return error.TestExpectedEqual,
    }
    try std.testing.expectEqual(@as(?Op, null), try iter.next());
}
