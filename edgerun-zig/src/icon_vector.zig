const std = @import("std");
const icon = @import("icon.zig");

pub const op_polyline: f32 = 1.0;
pub const op_circle: f32 = 2.0;
pub const op_ellipse: f32 = 3.0;
pub const op_round_rect: f32 = 4.0;
pub const op_filled_circle: f32 = 5.0;

pub const min_op_len: usize = 1;
pub const polyline_header_len: usize = 2;
pub const polyline_min_points: usize = 2;
pub const point_float_count: usize = 2;
pub const circle_len: usize = 4;
pub const ellipse_len: usize = 6;
pub const round_rect_len: usize = 6;
pub const filled_circle_len: usize = 4;

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
        return error.InvalidIconVector;
    }
};

pub const Op = union(enum) {
    polyline: []const f32,
    circle: Circle,
    ellipse: Ellipse,
    round_rect: RoundRect,
    filled_circle: Circle,
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

pub fn dataForIconId(icon_id: u32) []const f32 {
    const value = icon.fromId(icon_id) orelse return &.{};
    return data(value);
}

pub fn data(value: icon.Icon) []const f32 {
    return switch (value) {
        .activity => &activity,
        .app => &app,
        .bell => &bell,
        .chat => &chat,
        .check => &check,
        .chevron_right => &chevron_right,
        .code => &code,
        .cpu => &cpu,
        .database, .storage => &database,
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
        .trust => &trust,
        .trash => &trash,
        .user => &user,
        .wallet => &wallet,
        .warning => &warning,
        .x => &x,
        .github => &github,
    };
}

const activity = [_]f32{ op_polyline, 7, 0.16, 0.55, 0.31, 0.55, 0.39, 0.31, 0.52, 0.72, 0.62, 0.44, 0.70, 0.55, 0.84, 0.55 };
const app = [_]f32{ op_round_rect, 0.18, 0.20, 0.64, 0.60, 0.08, op_polyline, 2, 0.18, 0.38, 0.82, 0.38, op_filled_circle, 0.30, 0.29, 0.025, op_filled_circle, 0.40, 0.29, 0.025 };
const bell = [_]f32{ op_polyline, 8, 0.30, 0.70, 0.36, 0.42, 0.42, 0.28, 0.50, 0.25, 0.58, 0.28, 0.64, 0.42, 0.70, 0.70, 0.30, 0.70, op_polyline, 2, 0.44, 0.78, 0.56, 0.78 };
const chat = [_]f32{ op_round_rect, 0.20, 0.24, 0.60, 0.45, 0.12, op_polyline, 3, 0.38, 0.69, 0.30, 0.80, 0.31, 0.66 };
const check = [_]f32{ op_polyline, 3, 0.22, 0.53, 0.42, 0.72, 0.78, 0.30 };
const chevron_right = [_]f32{ op_polyline, 3, 0.38, 0.24, 0.64, 0.50, 0.38, 0.76 };
const code = [_]f32{ op_polyline, 3, 0.38, 0.32, 0.22, 0.50, 0.38, 0.68, op_polyline, 3, 0.62, 0.32, 0.78, 0.50, 0.62, 0.68 };
const cpu = [_]f32{ op_round_rect, 0.30, 0.30, 0.40, 0.40, 0.06, op_round_rect, 0.40, 0.40, 0.20, 0.20, 0.03, op_polyline, 2, 0.36, 0.18, 0.36, 0.30, op_polyline, 2, 0.36, 0.70, 0.36, 0.82, op_polyline, 2, 0.50, 0.18, 0.50, 0.30, op_polyline, 2, 0.50, 0.70, 0.50, 0.82, op_polyline, 2, 0.64, 0.18, 0.64, 0.30, op_polyline, 2, 0.64, 0.70, 0.64, 0.82, op_polyline, 2, 0.18, 0.36, 0.30, 0.36, op_polyline, 2, 0.70, 0.36, 0.82, 0.36, op_polyline, 2, 0.18, 0.50, 0.30, 0.50, op_polyline, 2, 0.70, 0.50, 0.82, 0.50, op_polyline, 2, 0.18, 0.64, 0.30, 0.64, op_polyline, 2, 0.70, 0.64, 0.82, 0.64 };
const database = [_]f32{ op_ellipse, 0.50, 0.28, 0.28, 0.10, 1, op_polyline, 2, 0.22, 0.28, 0.22, 0.68, op_polyline, 2, 0.78, 0.28, 0.78, 0.68, op_ellipse, 0.50, 0.48, 0.28, 0.10, 0, op_ellipse, 0.50, 0.68, 0.28, 0.10, 0 };
const eye = [_]f32{ op_polyline, 9, 0.16, 0.50, 0.32, 0.30, 0.50, 0.23, 0.68, 0.30, 0.84, 0.50, 0.68, 0.70, 0.50, 0.77, 0.32, 0.70, 0.16, 0.50, op_circle, 0.50, 0.50, 0.12 };
const file = [_]f32{ op_polyline, 6, 0.30, 0.18, 0.56, 0.18, 0.72, 0.34, 0.72, 0.82, 0.30, 0.82, 0.30, 0.18, op_polyline, 3, 0.56, 0.18, 0.56, 0.34, 0.72, 0.34 };
const key = [_]f32{ op_circle, 0.36, 0.48, 0.16, op_polyline, 3, 0.50, 0.56, 0.80, 0.56, 0.80, 0.68, op_polyline, 2, 0.66, 0.56, 0.66, 0.65 };
const lock = [_]f32{ op_round_rect, 0.26, 0.44, 0.48, 0.36, 0.06, op_polyline, 7, 0.36, 0.44, 0.36, 0.34, 0.40, 0.22, 0.50, 0.20, 0.60, 0.22, 0.64, 0.34, 0.64, 0.44 };
const menu = [_]f32{ op_polyline, 2, 0.22, 0.31, 0.78, 0.31, op_polyline, 2, 0.22, 0.50, 0.78, 0.50, op_polyline, 2, 0.22, 0.69, 0.78, 0.69 };
const message_plus = [_]f32{ op_round_rect, 0.20, 0.24, 0.60, 0.45, 0.12, op_polyline, 3, 0.38, 0.69, 0.30, 0.80, 0.31, 0.66, op_polyline, 2, 0.50, 0.38, 0.50, 0.56, op_polyline, 2, 0.41, 0.47, 0.59, 0.47 };
const network = [_]f32{ op_circle, 0.50, 0.26, 0.08, op_circle, 0.27, 0.70, 0.08, op_circle, 0.73, 0.70, 0.08, op_polyline, 2, 0.47, 0.33, 0.31, 0.63, op_polyline, 2, 0.53, 0.33, 0.69, 0.63, op_polyline, 2, 0.36, 0.70, 0.64, 0.70 };
const route = [_]f32{ op_circle, 0.25, 0.25, 0.08, op_circle, 0.75, 0.75, 0.08, op_polyline, 4, 0.33, 0.25, 0.58, 0.30, 0.42, 0.70, 0.67, 0.75 };
const search = [_]f32{ op_circle, 0.46, 0.45, 0.22, op_polyline, 2, 0.62, 0.62, 0.78, 0.78 };
const send = [_]f32{ op_polyline, 2, 0.50, 0.78, 0.50, 0.22, op_polyline, 3, 0.30, 0.42, 0.50, 0.22, 0.70, 0.42 };
const server = [_]f32{ op_round_rect, 0.22, 0.22, 0.56, 0.20, 0.04, op_round_rect, 0.22, 0.58, 0.56, 0.20, 0.04, op_filled_circle, 0.34, 0.32, 0.025, op_filled_circle, 0.34, 0.68, 0.025 };
const settings = [_]f32{ op_circle, 0.50, 0.50, 0.14, op_polyline, 2, 0.75, 0.50, 0.84, 0.50, op_polyline, 2, 0.68, 0.68, 0.74, 0.74, op_polyline, 2, 0.50, 0.75, 0.50, 0.84, op_polyline, 2, 0.32, 0.68, 0.26, 0.74, op_polyline, 2, 0.25, 0.50, 0.16, 0.50, op_polyline, 2, 0.32, 0.32, 0.26, 0.26, op_polyline, 2, 0.50, 0.25, 0.50, 0.16, op_polyline, 2, 0.68, 0.32, 0.74, 0.26 };
const shield = [_]f32{ op_polyline, 7, 0.50, 0.16, 0.76, 0.27, 0.71, 0.62, 0.50, 0.82, 0.29, 0.62, 0.24, 0.27, 0.50, 0.16 };
const sparkles = [_]f32{ op_polyline, 9, 0.50, 0.16, 0.56, 0.38, 0.78, 0.44, 0.56, 0.50, 0.50, 0.72, 0.44, 0.50, 0.22, 0.44, 0.44, 0.38, 0.50, 0.16, op_polyline, 5, 0.76, 0.18, 0.78, 0.28, 0.88, 0.30, 0.78, 0.32, 0.76, 0.42 };
const terminal = [_]f32{ op_round_rect, 0.18, 0.24, 0.64, 0.52, 0.07, op_polyline, 3, 0.30, 0.42, 0.42, 0.52, 0.30, 0.62, op_polyline, 2, 0.50, 0.62, 0.70, 0.62 };
const trust = [_]f32{ op_polyline, 7, 0.50, 0.16, 0.76, 0.27, 0.71, 0.62, 0.50, 0.82, 0.29, 0.62, 0.24, 0.27, 0.50, 0.16, op_polyline, 3, 0.38, 0.50, 0.47, 0.59, 0.64, 0.40 };
const trash = [_]f32{ op_polyline, 2, 0.26, 0.30, 0.74, 0.30, op_polyline, 2, 0.42, 0.20, 0.58, 0.20, op_polyline, 4, 0.34, 0.30, 0.38, 0.80, 0.62, 0.80, 0.66, 0.30, op_polyline, 2, 0.46, 0.42, 0.46, 0.68, op_polyline, 2, 0.54, 0.42, 0.54, 0.68 };
const user = [_]f32{ op_circle, 0.50, 0.35, 0.14, op_polyline, 5, 0.25, 0.80, 0.38, 0.64, 0.50, 0.58, 0.62, 0.64, 0.75, 0.80 };
const wallet = [_]f32{ op_round_rect, 0.18, 0.30, 0.64, 0.44, 0.07, op_round_rect, 0.58, 0.43, 0.24, 0.18, 0.04, op_filled_circle, 0.68, 0.52, 0.02 };
const warning = [_]f32{ op_polyline, 4, 0.50, 0.18, 0.82, 0.78, 0.18, 0.78, 0.50, 0.18, op_polyline, 2, 0.50, 0.40, 0.50, 0.56, op_filled_circle, 0.50, 0.68, 0.025 };
const x = [_]f32{ op_polyline, 2, 0.28, 0.28, 0.72, 0.72, op_polyline, 2, 0.72, 0.28, 0.28, 0.72 };
const github = [_]f32{ op_circle, 0.50, 0.43, 0.26, op_polyline, 3, 0.32, 0.27, 0.28, 0.16, 0.42, 0.22, op_polyline, 3, 0.58, 0.22, 0.72, 0.16, 0.68, 0.27, op_polyline, 3, 0.42, 0.68, 0.36, 0.80, 0.26, 0.78, op_polyline, 3, 0.58, 0.68, 0.64, 0.80, 0.74, 0.78, op_polyline, 2, 0.50, 0.68, 0.50, 0.84 };

test "every icon has valid vector data" {
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
