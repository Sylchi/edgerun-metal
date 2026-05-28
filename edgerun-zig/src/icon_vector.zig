const std = @import("std");
const math = @import("math.zig");
const icon = @import("icon.zig");

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

pub fn dataForIconId(icon_id: u32) []const f32 {
    const value = icon.fromId(icon_id) orelse return &.{};
    return data(value);
}

pub fn data(value: icon.Icon) []const f32 {
    return switch (value) {
        .activity => &activity,
        .apps => &app,
        .bell => &bell,
        .message => &chat,
        .check => &check,
        .chevron_right => &chevron_right,
        .code => &code,
        .cpu => &cpu,
        .database => &database,
        .eye => &eye,
        .file => &file,
        .key => &key,
        .lock => &lock,
        .menu => &menu,
        .message_plus => &message_plus,
        .network => &network,
        .route => &route,
        .search => &search,
        .send => &send,
        .server => &server,
        .settings => &settings,
        .shield => &shield,
        .sparkles => &sparkles,
        .terminal => &terminal,
        .trash => &trash,
        .user => &user,
        .wallet => &wallet,
        .alert_triangle => &warning,
        .x => &x,
        .brand_github => &github,
    };
}

const activity = [_]f32{ op_move_to, 0.1250, 0.5000, op_line_to, 0.2917, 0.5000, op_line_to, 0.4167, 0.8333, op_line_to, 0.5833, 0.1667, op_line_to, 0.7083, 0.5000, op_line_to, 0.8750, 0.5000 };
const app = [_]f32{ op_move_to, 0.1667, 0.2083, op_arc_to, 0.0417, 0.0417, 0.0000, 0, 1, 0.2083, 0.1667, op_line_to, 0.3750, 0.1667, op_arc_to, 0.0417, 0.0417, 0.0000, 0, 1, 0.4167, 0.2083, op_line_to, 0.4167, 0.3750, op_arc_to, 0.0417, 0.0417, 0.0000, 0, 1, 0.3750, 0.4167, op_line_to, 0.2083, 0.4167, op_arc_to, 0.0417, 0.0417, 0.0000, 0, 1, 0.1667, 0.3750, op_line_to, 0.1667, 0.2083, op_move_to, 0.1667, 0.6250, op_arc_to, 0.0417, 0.0417, 0.0000, 0, 1, 0.2083, 0.5833, op_line_to, 0.3750, 0.5833, op_arc_to, 0.0417, 0.0417, 0.0000, 0, 1, 0.4167, 0.6250, op_line_to, 0.4167, 0.7917, op_arc_to, 0.0417, 0.0417, 0.0000, 0, 1, 0.3750, 0.8333, op_line_to, 0.2083, 0.8333, op_arc_to, 0.0417, 0.0417, 0.0000, 0, 1, 0.1667, 0.7917, op_line_to, 0.1667, 0.6250, op_move_to, 0.5833, 0.6250, op_arc_to, 0.0417, 0.0417, 0.0000, 0, 1, 0.6250, 0.5833, op_line_to, 0.7917, 0.5833, op_arc_to, 0.0417, 0.0417, 0.0000, 0, 1, 0.8333, 0.6250, op_line_to, 0.8333, 0.7917, op_arc_to, 0.0417, 0.0417, 0.0000, 0, 1, 0.7917, 0.8333, op_line_to, 0.6250, 0.8333, op_arc_to, 0.0417, 0.0417, 0.0000, 0, 1, 0.5833, 0.7917, op_line_to, 0.5833, 0.6250, op_move_to, 0.5833, 0.2917, op_line_to, 0.8333, 0.2917, op_move_to, 0.7083, 0.1667, op_line_to, 0.7083, 0.4167 };
const bell = [_]f32{ op_move_to, 0.4167, 0.2083, op_arc_to, 0.0833, 0.0833, 0.0000, 1, 1, 0.5833, 0.2083, op_arc_to, 0.2917, 0.2917, 0.0000, 0, 1, 0.7500, 0.4583, op_line_to, 0.7500, 0.5833, op_arc_to, 0.1667, 0.1667, 0.0000, 0, 0, 0.8333, 0.7083, op_line_to, 0.1667, 0.7083, op_arc_to, 0.1667, 0.1667, 0.0000, 0, 0, 0.2500, 0.5833, op_line_to, 0.2500, 0.4583, op_arc_to, 0.2917, 0.2917, 0.0000, 0, 1, 0.4167, 0.2083, op_move_to, 0.3750, 0.7083, op_line_to, 0.3750, 0.7500, op_arc_to, 0.1250, 0.1250, 0.0000, 0, 0, 0.6250, 0.7500, op_line_to, 0.6250, 0.7083 };
const chat = [_]f32{ op_move_to, 0.1250, 0.8333, op_line_to, 0.1792, 0.6708, op_cubic_to, 0.0823, 0.5276, 0.1197, 0.3428, 0.2667, 0.2386, op_cubic_to, 0.4136, 0.1344, 0.6246, 0.1429, 0.7602, 0.2586, op_cubic_to, 0.8958, 0.3743, 0.9142, 0.5613, 0.8031, 0.6961, op_cubic_to, 0.6920, 0.8309, 0.4858, 0.8718, 0.3208, 0.7917, op_line_to, 0.1250, 0.8333 };
const check = [_]f32{ op_move_to, 0.2083, 0.5000, op_line_to, 0.4167, 0.7083, op_line_to, 0.8333, 0.2917 };
const chevron_right = [_]f32{ op_move_to, 0.3750, 0.2500, op_line_to, 0.6250, 0.5000, op_line_to, 0.3750, 0.7500 };
const code = [_]f32{ op_move_to, 0.2917, 0.3333, op_line_to, 0.1250, 0.5000, op_line_to, 0.2917, 0.6667, op_move_to, 0.7083, 0.3333, op_line_to, 0.8750, 0.5000, op_line_to, 0.7083, 0.6667, op_move_to, 0.5833, 0.1667, op_line_to, 0.4167, 0.8333 };
const cpu = [_]f32{ op_move_to, 0.2083, 0.2500, op_arc_to, 0.0417, 0.0417, 0.0000, 0, 1, 0.2500, 0.2083, op_line_to, 0.7500, 0.2083, op_arc_to, 0.0417, 0.0417, 0.0000, 0, 1, 0.7917, 0.2500, op_line_to, 0.7917, 0.7500, op_arc_to, 0.0417, 0.0417, 0.0000, 0, 1, 0.7500, 0.7917, op_line_to, 0.2500, 0.7917, op_arc_to, 0.0417, 0.0417, 0.0000, 0, 1, 0.2083, 0.7500, op_line_to, 0.2083, 0.2500, op_move_to, 0.3750, 0.3750, op_line_to, 0.6250, 0.3750, op_line_to, 0.6250, 0.6250, op_line_to, 0.3750, 0.6250, op_line_to, 0.3750, 0.3750, op_move_to, 0.1250, 0.4167, op_line_to, 0.2083, 0.4167, op_move_to, 0.1250, 0.5833, op_line_to, 0.2083, 0.5833, op_move_to, 0.4167, 0.1250, op_line_to, 0.4167, 0.2083, op_move_to, 0.5833, 0.1250, op_line_to, 0.5833, 0.2083, op_move_to, 0.8750, 0.4167, op_line_to, 0.7917, 0.4167, op_move_to, 0.8750, 0.5833, op_line_to, 0.7917, 0.5833, op_move_to, 0.5833, 0.8750, op_line_to, 0.5833, 0.7917, op_move_to, 0.4167, 0.8750, op_line_to, 0.4167, 0.7917 };
const database = [_]f32{ op_move_to, 0.1667, 0.2500, op_arc_to, 0.3333, 0.1250, 0.0000, 1, 0, 0.8333, 0.2500, op_arc_to, 0.3333, 0.1250, 0.0000, 1, 0, 0.1667, 0.2500, op_move_to, 0.1667, 0.2500, op_line_to, 0.1667, 0.5000, op_arc_to, 0.3333, 0.1250, 0.0000, 0, 0, 0.8333, 0.5000, op_line_to, 0.8333, 0.2500, op_move_to, 0.1667, 0.5000, op_line_to, 0.1667, 0.7500, op_arc_to, 0.3333, 0.1250, 0.0000, 0, 0, 0.8333, 0.7500, op_line_to, 0.8333, 0.5000 };
const eye = [_]f32{ op_move_to, 0.4167, 0.5000, op_arc_to, 0.0833, 0.0833, 0.0000, 1, 0, 0.5833, 0.5000, op_arc_to, 0.0833, 0.0833, 0.0000, 0, 0, 0.4167, 0.5000, op_move_to, 0.8750, 0.5000, op_cubic_to, 0.7750, 0.6667, 0.6500, 0.7500, 0.5000, 0.7500, op_cubic_to, 0.3500, 0.7500, 0.2250, 0.6667, 0.1250, 0.5000, op_cubic_to, 0.2250, 0.3333, 0.3500, 0.2500, 0.5000, 0.2500, op_cubic_to, 0.6500, 0.2500, 0.7750, 0.3333, 0.8750, 0.5000 };
const file = [_]f32{ op_move_to, 0.5833, 0.1250, op_line_to, 0.5833, 0.2917, op_arc_to, 0.0417, 0.0417, 0.0000, 0, 0, 0.6250, 0.3333, op_line_to, 0.7917, 0.3333, op_move_to, 0.7083, 0.8750, op_line_to, 0.2917, 0.8750, op_arc_to, 0.0833, 0.0833, 0.0000, 0, 1, 0.2083, 0.7917, op_line_to, 0.2083, 0.2083, op_arc_to, 0.0833, 0.0833, 0.0000, 0, 1, 0.2917, 0.1250, op_line_to, 0.5833, 0.1250, op_line_to, 0.7917, 0.3333, op_line_to, 0.7917, 0.7917, op_arc_to, 0.0833, 0.0833, 0.0000, 0, 1, 0.7083, 0.8750 };
const key = [_]f32{ op_move_to, 0.6898, 0.1601, op_line_to, 0.8399, 0.3102, op_arc_to, 0.1199, 0.1199, 0.0000, 0, 1, 0.8399, 0.4797, op_line_to, 0.7298, 0.5899, op_arc_to, 0.1199, 0.1199, 0.0000, 0, 1, 0.5602, 0.5899, op_line_to, 0.5477, 0.5773, op_line_to, 0.2744, 0.8506, op_arc_to, 0.0833, 0.0833, 0.0000, 0, 1, 0.2228, 0.8747, op_line_to, 0.2155, 0.8750, op_line_to, 0.1667, 0.8750, op_arc_to, 0.0417, 0.0417, 0.0000, 0, 1, 0.1253, 0.8382, op_line_to, 0.1250, 0.8333, op_line_to, 0.1250, 0.7845, op_arc_to, 0.0833, 0.0833, 0.0000, 0, 1, 0.1445, 0.7310, op_line_to, 0.1494, 0.7256, op_line_to, 0.1667, 0.7083, op_line_to, 0.2500, 0.7083, op_line_to, 0.2500, 0.6250, op_line_to, 0.3333, 0.6250, op_line_to, 0.3333, 0.5417, op_line_to, 0.4227, 0.4523, op_line_to, 0.4101, 0.4398, op_arc_to, 0.1199, 0.1199, 0.0000, 0, 1, 0.4101, 0.2703, op_line_to, 0.5203, 0.1601, op_arc_to, 0.1199, 0.1199, 0.0000, 0, 1, 0.6898, 0.1601, op_move_to, 0.6250, 0.3750, op_line_to, 0.6254, 0.3750 };
const lock = [_]f32{ op_move_to, 0.2083, 0.5417, op_arc_to, 0.0833, 0.0833, 0.0000, 0, 1, 0.2917, 0.4583, op_line_to, 0.7083, 0.4583, op_arc_to, 0.0833, 0.0833, 0.0000, 0, 1, 0.7917, 0.5417, op_line_to, 0.7917, 0.7917, op_arc_to, 0.0833, 0.0833, 0.0000, 0, 1, 0.7083, 0.8750, op_line_to, 0.2917, 0.8750, op_arc_to, 0.0833, 0.0833, 0.0000, 0, 1, 0.2083, 0.7917, op_line_to, 0.2083, 0.5417, op_move_to, 0.4583, 0.6667, op_arc_to, 0.0417, 0.0417, 0.0000, 1, 0, 0.5417, 0.6667, op_arc_to, 0.0417, 0.0417, 0.0000, 0, 0, 0.4583, 0.6667, op_move_to, 0.3333, 0.4583, op_line_to, 0.3333, 0.2917, op_arc_to, 0.1667, 0.1667, 0.0000, 1, 1, 0.6667, 0.2917, op_line_to, 0.6667, 0.4583 };
const menu = [_]f32{ op_move_to, 0.1667, 0.2500, op_line_to, 0.8333, 0.2500, op_move_to, 0.1667, 0.5000, op_line_to, 0.8333, 0.5000, op_move_to, 0.1667, 0.7500, op_line_to, 0.8333, 0.7500 };
const message_plus = [_]f32{ op_move_to, 0.3333, 0.3750, op_line_to, 0.6667, 0.3750, op_move_to, 0.3333, 0.5417, op_line_to, 0.5833, 0.5417, op_move_to, 0.5004, 0.7748, op_line_to, 0.3333, 0.8750, op_line_to, 0.3333, 0.7500, op_line_to, 0.2500, 0.7500, op_arc_to, 0.1250, 0.1250, 0.0000, 0, 1, 0.1250, 0.6250, op_line_to, 0.1250, 0.2917, op_arc_to, 0.1250, 0.1250, 0.0000, 0, 1, 0.2500, 0.1667, op_line_to, 0.7500, 0.1667, op_arc_to, 0.1250, 0.1250, 0.0000, 0, 1, 0.8750, 0.2917, op_line_to, 0.8750, 0.5208, op_move_to, 0.6667, 0.7917, op_line_to, 0.9167, 0.7917, op_move_to, 0.7917, 0.6667, op_line_to, 0.7917, 0.9167 };
const network = [_]f32{ op_move_to, 0.2500, 0.3750, op_arc_to, 0.2500, 0.2500, 0.0000, 1, 0, 0.7500, 0.3750, op_arc_to, 0.2500, 0.2500, 0.0000, 0, 0, 0.2500, 0.3750, op_move_to, 0.5000, 0.1250, op_cubic_to, 0.5555, 0.1389, 0.5833, 0.2222, 0.5833, 0.3750, op_cubic_to, 0.5833, 0.5278, 0.5555, 0.6111, 0.5000, 0.6250, op_move_to, 0.5000, 0.1250, op_cubic_to, 0.4445, 0.1389, 0.4167, 0.2222, 0.4167, 0.3750, op_cubic_to, 0.4167, 0.5278, 0.4445, 0.6111, 0.5000, 0.6250, op_move_to, 0.2500, 0.3750, op_line_to, 0.7500, 0.3750, op_move_to, 0.1250, 0.8333, op_line_to, 0.4167, 0.8333, op_move_to, 0.5833, 0.8333, op_line_to, 0.8750, 0.8333, op_move_to, 0.4167, 0.8333, op_arc_to, 0.0833, 0.0833, 0.0000, 1, 0, 0.5833, 0.8333, op_arc_to, 0.0833, 0.0833, 0.0000, 0, 0, 0.4167, 0.8333, op_move_to, 0.5000, 0.6250, op_line_to, 0.5000, 0.7500 };
const route = [_]f32{ op_move_to, 0.1250, 0.7917, op_arc_to, 0.0833, 0.0833, 0.0000, 1, 0, 0.2917, 0.7917, op_arc_to, 0.0833, 0.0833, 0.0000, 0, 0, 0.1250, 0.7917, op_move_to, 0.7917, 0.2917, op_arc_to, 0.0833, 0.0833, 0.0000, 1, 0, 0.7917, 0.1250, op_arc_to, 0.0833, 0.0833, 0.0000, 0, 0, 0.7917, 0.2917, op_move_to, 0.4583, 0.7917, op_line_to, 0.6875, 0.7917, op_arc_to, 0.1458, 0.1458, 0.0000, 0, 0, 0.6875, 0.5000, op_line_to, 0.3542, 0.5000, op_arc_to, 0.1458, 0.1458, 0.0000, 0, 1, 0.3542, 0.2083, op_line_to, 0.5417, 0.2083 };
const search = [_]f32{ op_move_to, 0.1250, 0.4167, op_arc_to, 0.2917, 0.2917, 0.0000, 1, 0, 0.7083, 0.4167, op_arc_to, 0.2917, 0.2917, 0.0000, 1, 0, 0.1250, 0.4167, op_move_to, 0.8750, 0.8750, op_line_to, 0.6250, 0.6250 };
const send = [_]f32{ op_move_to, 0.5000, 0.2083, op_line_to, 0.5000, 0.7917, op_move_to, 0.7500, 0.4583, op_line_to, 0.5000, 0.2083, op_move_to, 0.2500, 0.4583, op_line_to, 0.5000, 0.2083 };
const server = [_]f32{ op_move_to, 0.1250, 0.2917, op_arc_to, 0.1250, 0.1250, 0.0000, 0, 1, 0.2500, 0.1667, op_line_to, 0.7500, 0.1667, op_arc_to, 0.1250, 0.1250, 0.0000, 0, 1, 0.8750, 0.2917, op_line_to, 0.8750, 0.3750, op_arc_to, 0.1250, 0.1250, 0.0000, 0, 1, 0.7500, 0.5000, op_line_to, 0.2500, 0.5000, op_arc_to, 0.1250, 0.1250, 0.0000, 0, 1, 0.1250, 0.3750, op_move_to, 0.1250, 0.6250, op_arc_to, 0.1250, 0.1250, 0.0000, 0, 1, 0.2500, 0.5000, op_line_to, 0.7500, 0.5000, op_arc_to, 0.1250, 0.1250, 0.0000, 0, 1, 0.8750, 0.6250, op_line_to, 0.8750, 0.7083, op_arc_to, 0.1250, 0.1250, 0.0000, 0, 1, 0.7500, 0.8333, op_line_to, 0.2500, 0.8333, op_arc_to, 0.1250, 0.1250, 0.0000, 0, 1, 0.1250, 0.7083, op_line_to, 0.1250, 0.6250, op_move_to, 0.2917, 0.3333, op_line_to, 0.2917, 0.3338, op_move_to, 0.2917, 0.6667, op_line_to, 0.2917, 0.6671 };
const settings = [_]f32{ op_move_to, 0.4302, 0.1799, op_cubic_to, 0.4480, 0.1067, 0.5520, 0.1067, 0.5698, 0.1799, op_arc_to, 0.0718, 0.0718, 0.0000, 0, 0, 0.6770, 0.2243, op_cubic_to, 0.7413, 0.1851, 0.8149, 0.2587, 0.7757, 0.3230, op_arc_to, 0.0718, 0.0718, 0.0000, 0, 0, 0.8201, 0.4302, op_cubic_to, 0.8933, 0.4480, 0.8933, 0.5520, 0.8201, 0.5698, op_arc_to, 0.0718, 0.0718, 0.0000, 0, 0, 0.7757, 0.6770, op_cubic_to, 0.8149, 0.7413, 0.7413, 0.8149, 0.6770, 0.7757, op_arc_to, 0.0718, 0.0718, 0.0000, 0, 0, 0.5698, 0.8201, op_cubic_to, 0.5520, 0.8933, 0.4480, 0.8933, 0.4302, 0.8201, op_arc_to, 0.0718, 0.0718, 0.0000, 0, 0, 0.3230, 0.7757, op_cubic_to, 0.2587, 0.8149, 0.1851, 0.7413, 0.2243, 0.6770, op_arc_to, 0.0718, 0.0718, 0.0000, 0, 0, 0.1799, 0.5698, op_cubic_to, 0.1067, 0.5520, 0.1067, 0.4480, 0.1799, 0.4302, op_arc_to, 0.0718, 0.0718, 0.0000, 0, 0, 0.2243, 0.3230, op_cubic_to, 0.1851, 0.2587, 0.2587, 0.1851, 0.3230, 0.2243, op_cubic_to, 0.3647, 0.2496, 0.4187, 0.2272, 0.4302, 0.1799, op_move_to, 0.3750, 0.5000, op_arc_to, 0.1250, 0.1250, 0.0000, 1, 0, 0.6250, 0.5000, op_arc_to, 0.1250, 0.1250, 0.0000, 0, 0, 0.3750, 0.5000 };
const shield = [_]f32{ op_move_to, 0.4775, 0.8686, op_arc_to, 0.5000, 0.5000, 0.0000, 0, 1, 0.1458, 0.2500, op_arc_to, 0.5000, 0.5000, 0.0000, 0, 0, 0.5000, 0.1250, op_arc_to, 0.5000, 0.5000, 0.0000, 0, 0, 0.8542, 0.2500, op_arc_to, 0.5000, 0.5000, 0.0000, 0, 1, 0.8504, 0.5442, op_move_to, 0.6250, 0.7917, op_line_to, 0.7083, 0.8750, op_line_to, 0.8750, 0.7083 };
const sparkles = [_]f32{ op_move_to, 0.6667, 0.7500, op_arc_to, 0.0833, 0.0833, 0.0000, 0, 1, 0.7500, 0.8333, op_arc_to, 0.0833, 0.0833, 0.0000, 0, 1, 0.8333, 0.7500, op_arc_to, 0.0833, 0.0833, 0.0000, 0, 1, 0.7500, 0.6667, op_arc_to, 0.0833, 0.0833, 0.0000, 0, 1, 0.6667, 0.7500, op_move_to, 0.6667, 0.2500, op_arc_to, 0.0833, 0.0833, 0.0000, 0, 1, 0.7500, 0.3333, op_arc_to, 0.0833, 0.0833, 0.0000, 0, 1, 0.8333, 0.2500, op_arc_to, 0.0833, 0.0833, 0.0000, 0, 1, 0.7500, 0.1667, op_arc_to, 0.0833, 0.0833, 0.0000, 0, 1, 0.6667, 0.2500, op_move_to, 0.3750, 0.7500, op_arc_to, 0.2500, 0.2500, 0.0000, 0, 1, 0.6250, 0.5000, op_arc_to, 0.2500, 0.2500, 0.0000, 0, 1, 0.3750, 0.2500, op_arc_to, 0.2500, 0.2500, 0.0000, 0, 1, 0.1250, 0.5000, op_arc_to, 0.2500, 0.2500, 0.0000, 0, 1, 0.3750, 0.7500 };
const terminal = [_]f32{ op_move_to, 0.3333, 0.3750, op_line_to, 0.4583, 0.5000, op_line_to, 0.3333, 0.6250, op_move_to, 0.5417, 0.6250, op_line_to, 0.6667, 0.6250, op_move_to, 0.1250, 0.2500, op_arc_to, 0.0833, 0.0833, 0.0000, 0, 1, 0.2083, 0.1667, op_line_to, 0.7917, 0.1667, op_arc_to, 0.0833, 0.0833, 0.0000, 0, 1, 0.8750, 0.2500, op_line_to, 0.8750, 0.7500, op_arc_to, 0.0833, 0.0833, 0.0000, 0, 1, 0.7917, 0.8333, op_line_to, 0.2083, 0.8333, op_arc_to, 0.0833, 0.0833, 0.0000, 0, 1, 0.1250, 0.7500, op_line_to, 0.1250, 0.2500 };
const trash = [_]f32{ op_move_to, 0.1667, 0.2917, op_line_to, 0.8333, 0.2917, op_move_to, 0.4167, 0.4583, op_line_to, 0.4167, 0.7083, op_move_to, 0.5833, 0.4583, op_line_to, 0.5833, 0.7083, op_move_to, 0.2083, 0.2917, op_line_to, 0.2500, 0.7917, op_arc_to, 0.0833, 0.0833, 0.0000, 0, 0, 0.3333, 0.8750, op_line_to, 0.6667, 0.8750, op_arc_to, 0.0833, 0.0833, 0.0000, 0, 0, 0.7500, 0.7917, op_line_to, 0.7917, 0.2917, op_move_to, 0.3750, 0.2917, op_line_to, 0.3750, 0.1667, op_arc_to, 0.0417, 0.0417, 0.0000, 0, 1, 0.4167, 0.1250, op_line_to, 0.5833, 0.1250, op_arc_to, 0.0417, 0.0417, 0.0000, 0, 1, 0.6250, 0.1667, op_line_to, 0.6250, 0.2917 };
const user = [_]f32{ op_move_to, 0.3333, 0.2917, op_arc_to, 0.1667, 0.1667, 0.0000, 1, 0, 0.6667, 0.2917, op_arc_to, 0.1667, 0.1667, 0.0000, 0, 0, 0.3333, 0.2917, op_move_to, 0.2500, 0.8750, op_line_to, 0.2500, 0.7917, op_arc_to, 0.1667, 0.1667, 0.0000, 0, 1, 0.4167, 0.6250, op_line_to, 0.5833, 0.6250, op_arc_to, 0.1667, 0.1667, 0.0000, 0, 1, 0.7500, 0.7917, op_line_to, 0.7500, 0.8750 };
const wallet = [_]f32{ op_move_to, 0.7083, 0.3333, op_line_to, 0.7083, 0.2083, op_arc_to, 0.0417, 0.0417, 0.0000, 0, 0, 0.6667, 0.1667, op_line_to, 0.2500, 0.1667, op_arc_to, 0.0833, 0.0833, 0.0000, 0, 0, 0.2500, 0.3333, op_line_to, 0.7500, 0.3333, op_arc_to, 0.0417, 0.0417, 0.0000, 0, 1, 0.7917, 0.3750, op_line_to, 0.7917, 0.5000, op_move_to, 0.7917, 0.6667, op_line_to, 0.7917, 0.7917, op_arc_to, 0.0417, 0.0417, 0.0000, 0, 1, 0.7500, 0.8333, op_line_to, 0.2500, 0.8333, op_arc_to, 0.0833, 0.0833, 0.0000, 0, 1, 0.1667, 0.7500, op_line_to, 0.1667, 0.2500, op_move_to, 0.8333, 0.5000, op_line_to, 0.8333, 0.6667, op_line_to, 0.6667, 0.6667, op_arc_to, 0.0833, 0.0833, 0.0000, 0, 1, 0.6667, 0.5000, op_line_to, 0.8333, 0.5000 };
const warning = [_]f32{ op_move_to, 0.5000, 0.3750, op_line_to, 0.5000, 0.5417, op_move_to, 0.4318, 0.1496, op_line_to, 0.0940, 0.7135, op_arc_to, 0.0798, 0.0798, 0.0000, 0, 0, 0.1622, 0.8332, op_line_to, 0.8378, 0.8332, op_arc_to, 0.0798, 0.0798, 0.0000, 0, 0, 0.9060, 0.7136, op_line_to, 0.5682, 0.1496, op_arc_to, 0.0798, 0.0798, 0.0000, 0, 0, 0.4318, 0.1496, op_move_to, 0.5000, 0.6667, op_line_to, 0.5004, 0.6667 };
const x = [_]f32{ op_move_to, 0.7500, 0.2500, op_line_to, 0.2500, 0.7500, op_move_to, 0.2500, 0.2500, op_line_to, 0.7500, 0.7500 };
const github = [_]f32{ op_move_to, 0.3750, 0.7917, op_cubic_to, 0.1958, 0.8500, 0.1958, 0.6875, 0.1250, 0.6667, op_move_to, 0.6250, 0.8750, op_line_to, 0.6250, 0.7292, op_cubic_to, 0.6250, 0.6875, 0.6292, 0.6708, 0.6042, 0.6458, op_cubic_to, 0.7208, 0.6333, 0.8333, 0.5875, 0.8333, 0.3958, op_arc_to, 0.1917, 0.1917, 0.0000, 0, 0, 0.7792, 0.2625, op_arc_to, 0.1750, 0.1750, 0.0000, 0, 0, 0.7750, 0.1292, op_cubic_to, 0.7750, 0.1292, 0.7292, 0.1167, 0.6292, 0.1833, op_arc_to, 0.5125, 0.5125, 0.0000, 0, 0, 0.3708, 0.1833, op_cubic_to, 0.2708, 0.1167, 0.2250, 0.1292, 0.2250, 0.1292, op_arc_to, 0.1750, 0.1750, 0.0000, 0, 0, 0.2208, 0.2625, op_arc_to, 0.1917, 0.1917, 0.0000, 0, 0, 0.1667, 0.3958, op_cubic_to, 0.1667, 0.5875, 0.2792, 0.6333, 0.3958, 0.6458, op_cubic_to, 0.3708, 0.6708, 0.3708, 0.6958, 0.3750, 0.7292, op_line_to, 0.3750, 0.8750 };

test "every icon has valid vector data" {
    @setEvalBranchQuota(10000);
    inline for (@typeInfo(icon.Icon).@"enum".fields) |field| {
        const value: icon.Icon = @enumFromInt(field.value);
        var iter = Iterator.init(data(value));
        var count: usize = 0;
        while (try iter.next()) |_| count += 1;
        try std.testing.expect(count > 0);
    }
}

test "invalid icon ids return no vector data" {
    try std.testing.expectEqual(@as(usize, 0), dataForIconId(0).len);
    try std.testing.expectEqual(@as(usize, 0), dataForIconId(255).len);
}

test "icon vectors keep svg path commands instead of baked polylines" {
    try std.testing.expect(hasOp(data(.brand_github), op_cubic_to));
    try std.testing.expect(hasOp(data(.search), op_arc_to));
    try std.testing.expect(hasOp(data(.apps), op_arc_to));
    try std.testing.expectEqualSlices(f32, data(.database), data(.database));
    try std.testing.expectEqualSlices(f32, data(.shield), data(.shield));
}

test "iterator decodes linear gradient paint op" {
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
    const values = [_]f32{
        op_paint_current_color_alpha,
        128.0,
    };
    var iter = Iterator.init(&values);

    try std.testing.expectEqual(Op{ .paint_current_color_alpha = 128 }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?Op, null), try iter.next());
}

test "iterator decodes stroke width op" {
    const values = [_]f32{
        op_stroke_width,
        1.5 / 24.0,
    };
    var iter = Iterator.init(&values);

    try std.testing.expectEqual(Op{ .stroke_width = 1.5 / 24.0 }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?Op, null), try iter.next());
}

test "iterator decodes stroke cap op" {
    const values = [_]f32{
        op_stroke_cap,
        @floatFromInt(@intFromEnum(StrokeCap.square)),
    };
    var iter = Iterator.init(&values);

    try std.testing.expectEqual(Op{ .stroke_cap = .square }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?Op, null), try iter.next());
}

test "iterator decodes stroke join op" {
    const values = [_]f32{
        op_stroke_join,
        @floatFromInt(@intFromEnum(StrokeJoin.bevel)),
    };
    var iter = Iterator.init(&values);

    try std.testing.expectEqual(Op{ .stroke_join = .bevel }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?Op, null), try iter.next());
}

test "iterator decodes stroke miter limit op" {
    const values = [_]f32{
        op_stroke_miter_limit,
        2.5,
    };
    var iter = Iterator.init(&values);

    try std.testing.expectEqual(Op{ .stroke_miter_limit = 2.5 }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?Op, null), try iter.next());
}

test "iterator decodes clip path control ops" {
    const values = [_]f32{
        op_begin_clip_path,
        op_end_clip_path,
        op_clear_clip_path,
    };
    var iter = Iterator.init(&values);

    try std.testing.expectEqual(Op.begin_clip_path, (try iter.next()).?);
    try std.testing.expectEqual(Op.end_clip_path, (try iter.next()).?);
    try std.testing.expectEqual(Op.clear_clip_path, (try iter.next()).?);
    try std.testing.expectEqual(@as(?Op, null), try iter.next());
}

fn hasOp(values: []const f32, op: f32) bool {
    for (values) |value| if (value == op) return true;
    return false;
}
