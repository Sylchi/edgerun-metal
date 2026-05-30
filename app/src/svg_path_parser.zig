const std = @import("std");
const math = @import("math.zig");
const icon_vector = @import("icon_vector.zig");

pub const transform_epsilon: f32 = 0.00001;

pub const ViewBox = struct {
    min_x: f32 = 0.0,
    min_y: f32 = 0.0,
    width: f32 = 24.0,
    height: f32 = 24.0,
};

pub const Transform = struct {
    a: f32 = 1.0,
    b: f32 = 0.0,
    c: f32 = 0.0,
    d: f32 = 1.0,
    e: f32 = 0.0,
    f: f32 = 0.0,

    pub fn apply(self: Transform, value: icon_vector.Point) icon_vector.Point {
        return .{
            .x = value.x * self.a + value.y * self.c + self.e,
            .y = value.x * self.b + value.y * self.d + self.f,
        };
    }

    pub fn isAxisAligned(self: Transform) bool {
        return @abs(self.b) <= transform_epsilon and @abs(self.c) <= transform_epsilon;
    }

    pub fn isUniformRotationScale(self: Transform) bool {
        const sx = self.a * self.a + self.b * self.b;
        const sy = self.c * self.c + self.d * self.d;
        const dot = self.a * self.c + self.b * self.d;
        return sx > transform_epsilon and sy > transform_epsilon and @abs(sx - sy) <= transform_epsilon and @abs(dot) <= transform_epsilon;
    }

    pub fn scaleX(self: Transform, value: f32) f32 {
        return value * @sqrt(self.a * self.a + self.b * self.b);
    }

    pub fn scaleY(self: Transform, value: f32) f32 {
        return value * @sqrt(self.c * self.c + self.d * self.d);
    }

    pub fn rotationDegrees(self: Transform) f32 {
        return math.atan2F(self.b, self.a) * 180.0 / std.math.pi;
    }
};

pub fn isCommand(value: u8) bool {
    return switch (value) {
        'M', 'm', 'L', 'l', 'H', 'h', 'V', 'v', 'C', 'c', 'S', 's', 'Q', 'q', 'T', 't', 'A', 'a', 'Z', 'z' => true,
        else => false,
    };
}

pub fn isSvgWhitespace(byte: u8) bool {
    return switch (byte) {
        ' ', '\n', '\r', '\t' => true,
        else => false,
    };
}

pub fn isSvgNumberStart(byte: u8) bool {
    return switch (byte) {
        '0'...'9', '.', '-', '+' => true,
        else => false,
    };
}

fn previousSvgNumberCanTakeComma(data: []const u8, comma_index: usize) bool {
    if (comma_index == 0) return false;
    const prev = data[comma_index - 1];
    return prev == ')' or isSvgWhitespace(prev) or isSvgNumberStart(prev);
}

pub fn skipSvgNumberSeparators(data: []const u8, index: *usize) !void {
    while (index.* < data.len and isSvgWhitespace(data[index.*])) : (index.* += 1) {}
    if (index.* >= data.len or data[index.*] != ',') return;
    if (!previousSvgNumberCanTakeComma(data, index.*)) return error.InvalidSvg;
    index.* += 1;
    while (index.* < data.len and isSvgWhitespace(data[index.*])) : (index.* += 1) {}
    if (index.* >= data.len or !isSvgNumberStart(data[index.*])) return error.InvalidSvg;
}

fn parseFiniteSvgFloat(raw: []const u8) !f32 {
    const value = std.fmt.parseFloat(f32, raw) catch return error.InvalidSvg;
    if (!math.isFiniteF(value)) return error.InvalidSvg;
    return value;
}

pub fn parseSvgNumber(data: []const u8, index: *usize) !f32 {
    try skipSvgNumberSeparators(data, index);
    if (index.* >= data.len) return error.InvalidSvg;
    const start = index.*;
    if (data[index.*] == '-' or data[index.*] == '+') index.* += 1;
    var has_digit = false;
    while (index.* < data.len and std.ascii.isDigit(data[index.*])) : (index.* += 1) has_digit = true;
    if (index.* < data.len and data[index.*] == '.') {
        index.* += 1;
        while (index.* < data.len and std.ascii.isDigit(data[index.*])) : (index.* += 1) has_digit = true;
    }
    if (!has_digit) return error.InvalidSvg;
    if (index.* < data.len and (data[index.*] == 'e' or data[index.*] == 'E')) {
        index.* += 1;
        if (index.* < data.len and (data[index.*] == '-' or data[index.*] == '+')) index.* += 1;
        var exponent_digits = false;
        while (index.* < data.len and std.ascii.isDigit(data[index.*])) : (index.* += 1) exponent_digits = true;
        if (!exponent_digits) return error.InvalidSvg;
    }
    if (index.* == start) return error.InvalidSvg;
    return parseFiniteSvgFloat(data[start..index.*]);
}

pub const PathIterator = struct {
    data: []const u8,
    index: usize = 0,
    command: u8 = 0,
    view_box: ViewBox = .{},
    current: icon_vector.Point = .{ .x = 0.0, .y = 0.0 },
    subpath_start: icon_vector.Point = .{ .x = 0.0, .y = 0.0 },
    previous_cubic_control: ?icon_vector.Point = null,
    previous_quadratic_control: ?icon_vector.Point = null,
    transform: Transform = .{},
    started: bool = false,

    pub fn init(data: []const u8) PathIterator {
        return .{ .data = data };
    }

    pub fn initWithViewBox(data: []const u8, view_box: ViewBox) PathIterator {
        return .{ .data = data, .view_box = view_box };
    }

    pub fn next(self: *PathIterator) !?icon_vector.Op {
        try self.skipSeparators();
        if (self.index >= self.data.len) return null;
        if (isCommand(self.data[self.index])) {
            self.command = self.data[self.index];
            self.index += 1;
        }
        if (!self.started and self.command != 'M' and self.command != 'm') return error.InvalidPath;
        return switch (self.command) {
            'M', 'm' => self.moveTo(),
            'L', 'l' => self.lineTo(),
            'H', 'h' => self.horizontalLineTo(),
            'V', 'v' => self.verticalLineTo(),
            'C', 'c' => self.cubicTo(),
            'S', 's' => self.smoothCubicTo(),
            'Q', 'q' => self.quadraticTo(),
            'T', 't' => self.smoothQuadraticTo(),
            'A', 'a' => self.arcTo(),
            'Z', 'z' => self.closePath(),
            else => error.InvalidPath,
        };
    }

    fn moveTo(self: *PathIterator) !?icon_vector.Op {
        const relative = self.command == 'm';
        const target = try self.point(relative);
        self.current = target;
        self.subpath_start = target;
        self.previous_cubic_control = null;
        self.previous_quadratic_control = null;
        self.started = true;
        self.command = if (relative) 'l' else 'L';
        return .{ .move_to = self.normalizePoint(target) };
    }

    fn lineTo(self: *PathIterator) !?icon_vector.Op {
        const target = try self.point(self.command == 'l');
        self.current = target;
        self.previous_cubic_control = null;
        self.previous_quadratic_control = null;
        return .{ .line_to = self.normalizePoint(target) };
    }

    fn horizontalLineTo(self: *PathIterator) !?icon_vector.Op {
        const x = try self.number();
        const next_x = if (self.command == 'h') self.current.x + x else x;
        self.current = .{ .x = next_x, .y = self.current.y };
        self.previous_cubic_control = null;
        self.previous_quadratic_control = null;
        return .{ .line_to = self.normalizePoint(self.current) };
    }

    fn verticalLineTo(self: *PathIterator) !?icon_vector.Op {
        const y = try self.number();
        const next_y = if (self.command == 'v') self.current.y + y else y;
        self.current = .{ .x = self.current.x, .y = next_y };
        self.previous_cubic_control = null;
        self.previous_quadratic_control = null;
        return .{ .line_to = self.normalizePoint(self.current) };
    }

    fn cubicTo(self: *PathIterator) !?icon_vector.Op {
        const relative = self.command == 'c';
        const c0 = try self.point(relative);
        const c1 = try self.point(relative);
        const end = try self.point(relative);
        self.current = end;
        self.previous_cubic_control = c1;
        self.previous_quadratic_control = null;
        return .{ .cubic_to = .{ .control0 = self.normalizePoint(c0), .control1 = self.normalizePoint(c1), .end = self.normalizePoint(end) } };
    }

    fn smoothCubicTo(self: *PathIterator) !?icon_vector.Op {
        const relative = self.command == 's';
        const reflected = if (self.previous_cubic_control) |control| icon_vector.Point{
            .x = self.current.x * 2.0 - control.x,
            .y = self.current.y * 2.0 - control.y,
        } else self.current;
        const c1 = try self.point(relative);
        const end = try self.point(relative);
        self.current = end;
        self.previous_cubic_control = c1;
        self.previous_quadratic_control = null;
        return .{ .cubic_to = .{ .control0 = self.normalizePoint(reflected), .control1 = self.normalizePoint(c1), .end = self.normalizePoint(end) } };
    }

    fn quadraticTo(self: *PathIterator) !?icon_vector.Op {
        const relative = self.command == 'q';
        const control = try self.point(relative);
        const end = try self.point(relative);
        self.current = end;
        self.previous_cubic_control = null;
        self.previous_quadratic_control = control;
        return .{ .quad_to = .{ .control = self.normalizePoint(control), .end = self.normalizePoint(end) } };
    }

    fn smoothQuadraticTo(self: *PathIterator) !?icon_vector.Op {
        const relative = self.command == 't';
        const reflected = if (self.previous_quadratic_control) |control| icon_vector.Point{
            .x = self.current.x * 2.0 - control.x,
            .y = self.current.y * 2.0 - control.y,
        } else self.current;
        const end = try self.point(relative);
        self.current = end;
        self.previous_cubic_control = null;
        self.previous_quadratic_control = reflected;
        return .{ .quad_to = .{ .control = self.normalizePoint(reflected), .end = self.normalizePoint(end) } };
    }

    fn arcTo(self: *PathIterator) !?icon_vector.Op {
        const relative = self.command == 'a';
        const rx = @abs(try self.number());
        const ry = @abs(try self.number());
        const rotation = try self.number();
        const large_arc = try self.flag();
        const sweep = try self.flag();
        const end = try self.point(relative);
        if (rx <= transform_epsilon or ry <= transform_epsilon) {
            self.current = end;
            self.previous_cubic_control = null;
            self.previous_quadratic_control = null;
            return .{ .line_to = self.normalizePoint(end) };
        }
        if (!self.transform.isAxisAligned() and !self.transform.isUniformRotationScale()) return error.UnsupportedSvgElement;
        self.current = end;
        self.previous_cubic_control = null;
        self.previous_quadratic_control = null;
        const transformed_rx = self.transform.scaleX(rx);
        const transformed_ry = self.transform.scaleY(ry);
        if (transformed_rx <= transform_epsilon or transformed_ry <= transform_epsilon) return .{ .line_to = self.normalizePoint(end) };
        const transformed_rotation = if (self.transform.isUniformRotationScale()) rotation + self.transform.rotationDegrees() else rotation;
        return .{ .arc_to = .{
            .rx = transformed_rx / self.view_box.width,
            .ry = transformed_ry / self.view_box.height,
            .x_axis_rotation = transformed_rotation,
            .large_arc = large_arc,
            .sweep = sweep,
            .end = self.normalizePoint(end),
        } };
    }

    fn closePath(self: *PathIterator) !?icon_vector.Op {
        self.current = self.subpath_start;
        self.previous_cubic_control = null;
        self.previous_quadratic_control = null;
        self.command = 0;
        return .close_path;
    }

    fn point(self: *PathIterator, relative: bool) !icon_vector.Point {
        const x = try self.number();
        const y = try self.number();
        if (relative) return .{ .x = self.current.x + x, .y = self.current.y + y };
        return .{ .x = x, .y = y };
    }

    fn flag(self: *PathIterator) !bool {
        try self.skipSeparators();
        if (self.index >= self.data.len) return error.InvalidPath;
        const value = self.data[self.index];
        if (value == '0') {
            self.index += 1;
            return false;
        }
        if (value == '1') {
            self.index += 1;
            return true;
        }
        return error.InvalidPath;
    }

    fn number(self: *PathIterator) !f32 {
        return parseSvgNumber(self.data, &self.index);
    }

    fn skipSeparators(self: *PathIterator) !void {
        try skipSvgNumberSeparators(self.data, &self.index);
    }

    fn normalizePoint(self: PathIterator, value: icon_vector.Point) icon_vector.Point {
        const transformed = self.transform.apply(value);
        return .{
            .x = (transformed.x - self.view_box.min_x) / self.view_box.width,
            .y = (transformed.y - self.view_box.min_y) / self.view_box.height,
        };
    }
};
