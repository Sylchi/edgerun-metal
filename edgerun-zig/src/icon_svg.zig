const std = @import("std");
const icon = @import("icon.zig");
const icon_vector = @import("icon_vector.zig");

const default_view_box = ViewBox{ .min_x = 0.0, .min_y = 0.0, .width = 24.0, .height = 24.0 };

pub const ViewBox = struct {
    min_x: f32,
    min_y: f32,
    width: f32,
    height: f32,
};

const Transform = struct {
    a: f32 = 1.0,
    b: f32 = 0.0,
    c: f32 = 0.0,
    d: f32 = 1.0,
    e: f32 = 0.0,
    f: f32 = 0.0,

    fn apply(self: Transform, value: icon_vector.Point) icon_vector.Point {
        return .{
            .x = value.x * self.a + value.y * self.c + self.e,
            .y = value.x * self.b + value.y * self.d + self.f,
        };
    }

    fn scaleX(self: Transform, value: f32) f32 {
        return value * @sqrt(self.a * self.a + self.b * self.b);
    }

    fn scaleY(self: Transform, value: f32) f32 {
        return value * @sqrt(self.c * self.c + self.d * self.d);
    }

    fn isAxisAligned(self: Transform) bool {
        return @abs(self.b) <= transform_epsilon and @abs(self.c) <= transform_epsilon;
    }

    fn isAxisAlignedPositive(self: Transform) bool {
        return self.isAxisAligned() and self.a > 0.0 and self.d > 0.0;
    }

    fn isUniformRotationScale(self: Transform) bool {
        const sx = self.scaleX(1.0);
        const sy = self.scaleY(1.0);
        const dot = self.a * self.c + self.b * self.d;
        return sx > transform_epsilon and sy > transform_epsilon and @abs(sx - sy) <= transform_epsilon and @abs(dot) <= transform_epsilon;
    }

    fn rotationDegrees(self: Transform) f32 {
        return radiansToDegrees(std.math.atan2(self.b, self.a));
    }
};

pub const Error = error{
    InvalidSvg,
    InvalidPath,
    UnsupportedSvgElement,
    UnsupportedSvgStroke,
};

pub fn sourceForIconId(icon_id: u32) []const u8 {
    const value = icon.fromId(icon_id) orelse return "";
    return source(value);
}

pub fn source(value: icon.Icon) []const u8 {
    return switch (value) {
        .activity => @embedFile("icons/tabler/activity.svg"),
        .app => @embedFile("icons/tabler/apps.svg"),
        .bell => @embedFile("icons/tabler/bell.svg"),
        .chat => @embedFile("icons/tabler/message-circle.svg"),
        .check => @embedFile("icons/tabler/check.svg"),
        .chevron_right => @embedFile("icons/tabler/chevron-right.svg"),
        .code => @embedFile("icons/tabler/code.svg"),
        .cpu => @embedFile("icons/tabler/cpu.svg"),
        .database, .storage => @embedFile("icons/tabler/database.svg"),
        .eye => @embedFile("icons/tabler/eye.svg"),
        .file => @embedFile("icons/tabler/file.svg"),
        .key => @embedFile("icons/tabler/key.svg"),
        .lock => @embedFile("icons/tabler/lock.svg"),
        .menu => @embedFile("icons/tabler/menu-2.svg"),
        .message_plus => @embedFile("icons/tabler/message-plus.svg"),
        .network => @embedFile("icons/tabler/network.svg"),
        .route => @embedFile("icons/tabler/route.svg"),
        .search => @embedFile("icons/tabler/search.svg"),
        .send => @embedFile("icons/tabler/arrow-up.svg"),
        .server => @embedFile("icons/tabler/server.svg"),
        .settings => @embedFile("icons/tabler/settings.svg"),
        .shield, .trust => @embedFile("icons/tabler/shield-check.svg"),
        .sparkles => @embedFile("icons/tabler/sparkles.svg"),
        .terminal => @embedFile("icons/tabler/terminal-2.svg"),
        .trash => @embedFile("icons/tabler/trash.svg"),
        .user => @embedFile("icons/tabler/user.svg"),
        .wallet => @embedFile("icons/tabler/wallet.svg"),
        .warning => @embedFile("icons/tabler/alert-triangle.svg"),
        .x => @embedFile("icons/tabler/x.svg"),
        .github => @embedFile("icons/tabler/brand-github.svg"),
    };
}

pub const Iterator = struct {
    svg: []const u8,
    search_index: usize = 0,
    path: ?PathIterator = null,
    view_box: ViewBox = default_view_box,
    invalid_svg: bool = false,
    line_points: [4]f32 = .{ 0.0, 0.0, 0.0, 0.0 },
    pending_ops: [max_pending_ops]icon_vector.Op = undefined,
    pending_start: usize = 0,
    pending_len: usize = 0,
    transform_stack: [max_transform_depth]Transform = undefined,
    transform_depth: usize = 0,

    pub fn init(svg: []const u8) Iterator {
        const parsed_view_box = parseSvgRoot(svg) catch return .{ .svg = svg, .invalid_svg = true };
        return .{
            .svg = svg,
            .view_box = parsed_view_box,
        };
    }

    pub fn next(self: *Iterator) Error!?icon_vector.Op {
        if (self.invalid_svg) return error.InvalidSvg;
        while (true) {
            if (self.takePending()) |op| return op;
            if (self.path) |*path| {
                if (try path.next()) |op| return op;
                self.path = null;
            }
            const element = try self.nextElement() orelse return null;
            switch (element.kind) {
                .path => {
                    const d = try attrValue(element.tag, "d");
                    self.path = PathIterator.initWithViewBoxTransform(d, self.view_box, try combineElementTransform(element.transform, element.tag));
                },
                .circle => return try self.circleOp(element.tag),
                .ellipse => return try self.ellipseOp(element.tag),
                .line => return try self.lineOp(element.tag),
                .polyline => {
                    try self.enqueuePointList(element.tag, false);
                    return self.takePending();
                },
                .polygon => {
                    try self.enqueuePointList(element.tag, true);
                    return self.takePending();
                },
                .rect => return try self.rectOp(element.tag),
            }
        }
    }

    pub fn nextPathData(self: *Iterator) Error!?[]const u8 {
        const element = try self.nextElement() orelse return null;
        if (element.kind != .path) return error.InvalidSvg;
        const value = try attrValue(element.tag, "d");
        return value;
    }

    fn nextElement(self: *Iterator) Error!?SvgElement {
        while (self.search_index < self.svg.len) {
            const tag_start_offset = std.mem.indexOfScalar(u8, self.svg[self.search_index..], '<') orelse return null;
            const tag_start = self.search_index + tag_start_offset;
            const tag_end_offset = std.mem.indexOfScalar(u8, self.svg[tag_start..], '>') orelse return error.InvalidSvg;
            const tag = self.svg[tag_start .. tag_start + tag_end_offset];
            self.search_index = tag_start + tag_end_offset + 1;

            if (isIgnorableTag(tag)) continue;
            if (isGroupCloseTag(tag)) {
                if (self.transform_depth == 0) return error.InvalidSvg;
                self.transform_depth -= 1;
                continue;
            }
            if (isGroupOpenTag(tag)) {
                try validateSupportedPresentationTag(tag);
                try self.pushTransform(try combineElementTransform(self.currentTransform(), tag));
                if (isSelfClosingTag(tag)) self.popTransform();
                continue;
            }
            if (isMetadataTag(tag)) continue;
            if (unsupportedElementTag(tag)) return error.UnsupportedSvgElement;
            if (supportedElementKind(tag)) |kind| {
                try validateSupportedPresentationTag(tag);
                return .{ .kind = kind, .tag = tag, .transform = self.currentTransform() };
            }
            return error.UnsupportedSvgElement;
        }
        return null;
    }

    fn circleOp(self: *Iterator, tag: []const u8) Error!icon_vector.Op {
        const transform = try combineElementTransform(self.currentTransform(), tag);
        if (!transform.isAxisAligned() and !transform.isUniformRotationScale()) return error.UnsupportedSvgElement;
        const center = try self.normalizePoint(transform.apply(.{ .x = try attrNumber(tag, "cx"), .y = try attrNumber(tag, "cy") }));
        const rx = try self.normalizeWidth(transform.scaleX(try attrNumber(tag, "r")));
        const ry = try self.normalizeHeight(transform.scaleY(try attrNumber(tag, "r")));
        const cx = center.x;
        const cy = center.y;
        if (rx == ry) return .{ .circle = .{ .cx = cx, .cy = cy, .radius = rx } };
        return .{ .ellipse = .{ .cx = cx, .cy = cy, .rx = rx, .ry = ry, .full = true } };
    }

    fn ellipseOp(self: *Iterator, tag: []const u8) Error!icon_vector.Op {
        const transform = try combineElementTransform(self.currentTransform(), tag);
        if (!transform.isAxisAlignedPositive()) return error.UnsupportedSvgElement;
        const center = try self.normalizePoint(transform.apply(.{ .x = try attrNumber(tag, "cx"), .y = try attrNumber(tag, "cy") }));
        return .{ .ellipse = .{
            .cx = center.x,
            .cy = center.y,
            .rx = try self.normalizeWidth(transform.scaleX(try attrNumber(tag, "rx"))),
            .ry = try self.normalizeHeight(transform.scaleY(try attrNumber(tag, "ry"))),
            .full = true,
        } };
    }

    fn lineOp(self: *Iterator, tag: []const u8) Error!icon_vector.Op {
        const transform = try combineElementTransform(self.currentTransform(), tag);
        const start = try self.normalizePoint(transform.apply(.{ .x = try attrNumber(tag, "x1"), .y = try attrNumber(tag, "y1") }));
        const end = try self.normalizePoint(transform.apply(.{ .x = try attrNumber(tag, "x2"), .y = try attrNumber(tag, "y2") }));
        self.line_points = .{
            start.x,
            start.y,
            end.x,
            end.y,
        };
        return .{ .polyline = self.line_points[0..] };
    }

    fn rectOp(self: *Iterator, tag: []const u8) Error!icon_vector.Op {
        const transform = try combineElementTransform(self.currentTransform(), tag);
        if (!transform.isAxisAlignedPositive()) return error.UnsupportedSvgElement;
        const width = try attrNumber(tag, "width");
        const height = try attrNumber(tag, "height");
        const rx = (try attrNumberOptional(tag, "rx")) orelse 0.0;
        const x = (try attrNumberOptional(tag, "x")) orelse 0.0;
        const y = (try attrNumberOptional(tag, "y")) orelse 0.0;
        const origin = try self.normalizePoint(transform.apply(.{ .x = x, .y = y }));
        return .{ .round_rect = .{
            .x = origin.x,
            .y = origin.y,
            .w = try self.normalizeWidth(transform.scaleX(width)),
            .h = try self.normalizeHeight(transform.scaleY(height)),
            .radius = try self.normalizeWidth(transform.scaleX(rx)),
        } };
    }

    fn enqueuePointList(self: *Iterator, tag: []const u8, close: bool) Error!void {
        if (self.pending_len != 0) return error.InvalidSvg;
        const points = try attrValue(tag, "points");
        var values = NumberList.init(points);
        const first_x = try values.next();
        const first_y = try values.next();
        const transform = try combineElementTransform(self.currentTransform(), tag);
        const first = try self.normalizePoint(transform.apply(.{ .x = first_x, .y = first_y }));
        self.pushPending(.{ .move_to = first });
        while (try values.hasMore()) {
            const next_x = try values.next();
            const next_y = try values.next();
            const normalized = try self.normalizePoint(transform.apply(.{ .x = next_x, .y = next_y }));
            const next_point = icon_vector.Point{
                .x = normalized.x,
                .y = normalized.y,
            };
            self.pushPending(.{ .line_to = next_point });
        }
        if (close) self.pushPending(.close_path);
    }

    fn pushPending(self: *Iterator, op: icon_vector.Op) void {
        if (self.pending_len >= max_pending_ops) unreachable;
        self.pending_ops[self.pending_len] = op;
        self.pending_len += 1;
    }

    fn takePending(self: *Iterator) ?icon_vector.Op {
        if (self.pending_start >= self.pending_len) {
            self.pending_start = 0;
            self.pending_len = 0;
            return null;
        }
        const op = self.pending_ops[self.pending_start];
        self.pending_start += 1;
        return op;
    }

    fn normalizeX(self: Iterator, value: f32) Error!f32 {
        return (value - self.view_box.min_x) / self.view_box.width;
    }

    fn normalizeY(self: Iterator, value: f32) Error!f32 {
        return (value - self.view_box.min_y) / self.view_box.height;
    }

    fn normalizePoint(self: Iterator, value: icon_vector.Point) Error!icon_vector.Point {
        return .{ .x = try self.normalizeX(value.x), .y = try self.normalizeY(value.y) };
    }

    fn normalizeWidth(self: Iterator, value: f32) Error!f32 {
        if (value < 0.0) return error.InvalidSvg;
        return value / self.view_box.width;
    }

    fn normalizeHeight(self: Iterator, value: f32) Error!f32 {
        if (value < 0.0) return error.InvalidSvg;
        return value / self.view_box.height;
    }

    fn currentTransform(self: Iterator) Transform {
        if (self.transform_depth == 0) return .{};
        return self.transform_stack[self.transform_depth - 1];
    }

    fn pushTransform(self: *Iterator, transform: Transform) Error!void {
        if (self.transform_depth >= max_transform_depth) return error.InvalidSvg;
        self.transform_stack[self.transform_depth] = transform;
        self.transform_depth += 1;
    }

    fn popTransform(self: *Iterator) void {
        self.transform_depth -= 1;
    }
};

pub fn validateSupportedTablerStroke(svg: []const u8) Error!void {
    const svg_pos = std.mem.indexOf(u8, svg, "<svg") orelse return error.InvalidSvg;
    const svg_end_offset = std.mem.indexOfScalar(u8, svg[svg_pos..], '>') orelse return error.InvalidSvg;
    const tag = svg[svg_pos .. svg_pos + svg_end_offset];
    try validateSupportedPresentationTag(tag);
    if (!std.mem.containsAtLeast(u8, svg, 1, "stroke-width")) return error.UnsupportedSvgStroke;
    if (!std.mem.containsAtLeast(u8, svg, 1, "stroke-linecap")) return error.UnsupportedSvgStroke;
    if (!std.mem.containsAtLeast(u8, svg, 1, "stroke-linejoin")) return error.UnsupportedSvgStroke;

    for (unsupported_svg_elements) |element| {
        if (svgContainsElementTag(svg, element)) return error.UnsupportedSvgElement;
    }
}

pub const PathIterator = struct {
    data: []const u8,
    index: usize = 0,
    command: u8 = 0,
    view_box: ViewBox = default_view_box,
    current: icon_vector.Point = .{ .x = 0.0, .y = 0.0 },
    subpath_start: icon_vector.Point = .{ .x = 0.0, .y = 0.0 },
    previous_cubic_control: ?icon_vector.Point = null,
    previous_quadratic_control: ?icon_vector.Point = null,
    transform: Transform = .{},

    pub fn init(data: []const u8) PathIterator {
        return .{ .data = data };
    }

    pub fn initWithViewBox(data: []const u8, view_box: ViewBox) PathIterator {
        return .{ .data = data, .view_box = view_box };
    }

    pub fn initWithViewBoxTransform(data: []const u8, view_box: ViewBox, transform: Transform) PathIterator {
        return .{ .data = data, .view_box = view_box, .transform = transform };
    }

    pub fn next(self: *PathIterator) Error!?icon_vector.Op {
        self.skipSeparators();
        if (self.index >= self.data.len) return null;
        if (isCommand(self.data[self.index])) {
            self.command = self.data[self.index];
            self.index += 1;
        }
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

    fn moveTo(self: *PathIterator) Error!?icon_vector.Op {
        const relative = self.command == 'm';
        const target = try self.point(relative);
        self.current = target;
        self.subpath_start = target;
        self.previous_cubic_control = null;
        self.previous_quadratic_control = null;
        self.command = if (relative) 'l' else 'L';
        return .{ .move_to = self.normalizePoint(target) };
    }

    fn lineTo(self: *PathIterator) Error!?icon_vector.Op {
        const target = try self.point(self.command == 'l');
        self.current = target;
        self.previous_cubic_control = null;
        self.previous_quadratic_control = null;
        return .{ .line_to = self.normalizePoint(target) };
    }

    fn horizontalLineTo(self: *PathIterator) Error!?icon_vector.Op {
        const x = try self.number();
        const next_x = if (self.command == 'h') self.current.x + x else x;
        self.current = .{ .x = next_x, .y = self.current.y };
        self.previous_cubic_control = null;
        self.previous_quadratic_control = null;
        return .{ .line_to = self.normalizePoint(self.current) };
    }

    fn verticalLineTo(self: *PathIterator) Error!?icon_vector.Op {
        const y = try self.number();
        const next_y = if (self.command == 'v') self.current.y + y else y;
        self.current = .{ .x = self.current.x, .y = next_y };
        self.previous_cubic_control = null;
        self.previous_quadratic_control = null;
        return .{ .line_to = self.normalizePoint(self.current) };
    }

    fn cubicTo(self: *PathIterator) Error!?icon_vector.Op {
        const relative = self.command == 'c';
        const c0 = try self.point(relative);
        const c1 = try self.point(relative);
        const end = try self.point(relative);
        self.current = end;
        self.previous_cubic_control = c1;
        self.previous_quadratic_control = null;
        return .{ .cubic_to = .{ .control0 = self.normalizePoint(c0), .control1 = self.normalizePoint(c1), .end = self.normalizePoint(end) } };
    }

    fn smoothCubicTo(self: *PathIterator) Error!?icon_vector.Op {
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

    fn quadraticTo(self: *PathIterator) Error!?icon_vector.Op {
        const relative = self.command == 'q';
        const control = try self.point(relative);
        const end = try self.point(relative);
        self.current = end;
        self.previous_cubic_control = null;
        self.previous_quadratic_control = control;
        return .{ .quad_to = .{ .control = self.normalizePoint(control), .end = self.normalizePoint(end) } };
    }

    fn smoothQuadraticTo(self: *PathIterator) Error!?icon_vector.Op {
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

    fn arcTo(self: *PathIterator) Error!?icon_vector.Op {
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
        const transformed_rotation = if (self.transform.isUniformRotationScale()) rotation + self.transform.rotationDegrees() else rotation;
        return .{ .arc_to = .{
            .rx = self.transform.scaleX(rx) / self.view_box.width,
            .ry = self.transform.scaleY(ry) / self.view_box.height,
            .x_axis_rotation = transformed_rotation,
            .large_arc = large_arc,
            .sweep = sweep,
            .end = self.normalizePoint(end),
        } };
    }

    fn closePath(self: *PathIterator) Error!?icon_vector.Op {
        self.current = self.subpath_start;
        self.previous_cubic_control = null;
        self.previous_quadratic_control = null;
        self.command = 0;
        return .close_path;
    }

    fn point(self: *PathIterator, relative: bool) Error!icon_vector.Point {
        const x = try self.number();
        const y = try self.number();
        if (relative) return .{ .x = self.current.x + x, .y = self.current.y + y };
        return .{ .x = x, .y = y };
    }

    fn flag(self: *PathIterator) Error!bool {
        self.skipSeparators();
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

    fn number(self: *PathIterator) Error!f32 {
        self.skipSeparators();
        const start = self.index;
        if (self.index < self.data.len and (self.data[self.index] == '-' or self.data[self.index] == '+')) self.index += 1;
        var has_digit = false;
        while (self.index < self.data.len and std.ascii.isDigit(self.data[self.index])) : (self.index += 1) has_digit = true;
        if (self.index < self.data.len and self.data[self.index] == '.') {
            self.index += 1;
            while (self.index < self.data.len and std.ascii.isDigit(self.data[self.index])) : (self.index += 1) has_digit = true;
        }
        if (!has_digit) return error.InvalidPath;
        if (self.index < self.data.len and (self.data[self.index] == 'e' or self.data[self.index] == 'E')) {
            self.index += 1;
            if (self.index < self.data.len and (self.data[self.index] == '-' or self.data[self.index] == '+')) self.index += 1;
            var exponent_digits = false;
            while (self.index < self.data.len and std.ascii.isDigit(self.data[self.index])) : (self.index += 1) exponent_digits = true;
            if (!exponent_digits) return error.InvalidPath;
        }
        return std.fmt.parseFloat(f32, self.data[start..self.index]) catch error.InvalidPath;
    }

    fn skipSeparators(self: *PathIterator) void {
        while (self.index < self.data.len) : (self.index += 1) {
            switch (self.data[self.index]) {
                ' ', '\n', '\r', '\t', ',' => {},
                else => return,
            }
        }
    }

    fn normalizePoint(self: PathIterator, value: icon_vector.Point) icon_vector.Point {
        const transformed = self.transform.apply(value);
        return .{
            .x = (transformed.x - self.view_box.min_x) / self.view_box.width,
            .y = (transformed.y - self.view_box.min_y) / self.view_box.height,
        };
    }
};

fn isCommand(value: u8) bool {
    return switch (value) {
        'M', 'm', 'L', 'l', 'H', 'h', 'V', 'v', 'C', 'c', 'S', 's', 'Q', 'q', 'T', 't', 'A', 'a', 'Z', 'z' => true,
        else => false,
    };
}

const SvgElementKind = enum {
    path,
    circle,
    ellipse,
    line,
    polyline,
    polygon,
    rect,
};

const SvgElement = struct {
    kind: SvgElementKind,
    tag: []const u8,
    transform: Transform,
};

fn parseSvgRoot(svg: []const u8) Error!ViewBox {
    const svg_pos = std.mem.indexOf(u8, svg, "<svg") orelse return error.InvalidSvg;
    const svg_end_offset = std.mem.indexOfScalar(u8, svg[svg_pos..], '>') orelse return error.InvalidSvg;
    const tag = svg[svg_pos .. svg_pos + svg_end_offset];
    try validateSupportedPresentationTag(tag);
    const raw = try attrValue(tag, "viewBox");
    var values = NumberList.init(raw);
    const min_x = try values.next();
    const min_y = try values.next();
    const width = try values.next();
    const height = try values.next();
    if (try values.hasMore()) return error.InvalidSvg;
    if (width <= 0.0 or height <= 0.0) return error.InvalidSvg;
    return .{ .min_x = min_x, .min_y = min_y, .width = width, .height = height };
}

fn attrNumber(tag: []const u8, name: []const u8) Error!f32 {
    return std.fmt.parseFloat(f32, try attrValue(tag, name)) catch error.InvalidSvg;
}

fn attrNumberOptional(tag: []const u8, name: []const u8) Error!?f32 {
    const value = (try attrValueOptional(tag, name)) orelse return null;
    return std.fmt.parseFloat(f32, value) catch error.InvalidSvg;
}

fn attrValue(tag: []const u8, name: []const u8) Error![]const u8 {
    return (try attrValueOptional(tag, name)) orelse error.InvalidSvg;
}

fn attrValueOptional(tag: []const u8, name: []const u8) Error!?[]const u8 {
    var search_index: usize = 0;
    while (search_index < tag.len) {
        const relative_pos = std.mem.indexOf(u8, tag[search_index..], name) orelse return null;
        const name_pos = search_index + relative_pos;
        search_index = name_pos + name.len;
        if (name_pos > 0 and !std.ascii.isWhitespace(tag[name_pos - 1])) continue;
        var index = search_index;
        while (index < tag.len and std.ascii.isWhitespace(tag[index])) : (index += 1) {}
        if (index >= tag.len or tag[index] != '=') continue;
        index += 1;
        while (index < tag.len and std.ascii.isWhitespace(tag[index])) : (index += 1) {}
        if (index >= tag.len) return error.InvalidSvg;
        const quote = tag[index];
        if (quote != '"' and quote != '\'') return error.InvalidSvg;
        index += 1;
        const value_start = index;
        while (index < tag.len and tag[index] != quote) : (index += 1) {}
        if (index >= tag.len) return error.InvalidSvg;
        return tag[value_start..index];
    }
    return null;
}

fn validateSupportedPresentationTag(tag: []const u8) Error!void {
    if (try attrValueOptional(tag, "style") != null) return error.UnsupportedSvgStroke;
    if (try attrValueOptional(tag, "class") != null) return error.UnsupportedSvgStroke;
    if (try attrValueOptional(tag, "opacity") != null) return error.UnsupportedSvgStroke;
    if (try attrValueOptional(tag, "fill-opacity") != null) return error.UnsupportedSvgStroke;
    if (try attrValueOptional(tag, "stroke-opacity") != null) return error.UnsupportedSvgStroke;
    if (try attrValueOptional(tag, "display")) |value| {
        if (!std.mem.eql(u8, value, "inline")) return error.UnsupportedSvgStroke;
    }
    if (try attrValueOptional(tag, "fill")) |value| {
        if (!std.mem.eql(u8, value, "none")) return error.UnsupportedSvgStroke;
    }
    if (try attrValueOptional(tag, "stroke")) |value| {
        if (!isSupportedStrokePaint(value)) return error.UnsupportedSvgStroke;
    }
    if (try attrValueOptional(tag, "stroke-width")) |value| {
        if (!std.mem.eql(u8, value, "2")) return error.UnsupportedSvgStroke;
    }
    if (try attrValueOptional(tag, "stroke-linecap")) |value| {
        if (!std.mem.eql(u8, value, "round")) return error.UnsupportedSvgStroke;
    }
    if (try attrValueOptional(tag, "stroke-linejoin")) |value| {
        if (!std.mem.eql(u8, value, "round")) return error.UnsupportedSvgStroke;
    }
}

fn isSupportedStrokePaint(value: []const u8) bool {
    return std.mem.eql(u8, value, "currentColor") or
        std.mem.eql(u8, value, "white") or
        std.mem.eql(u8, value, "#fff") or
        std.mem.eql(u8, value, "#ffffff");
}

fn elementTransform(tag: []const u8) Error!Transform {
    const raw = (try attrValueOptional(tag, "transform")) orelse return .{};
    return parseTransform(raw);
}

fn combineElementTransform(inherited: Transform, tag: []const u8) Error!Transform {
    return appendTransform(inherited, try elementTransform(tag));
}

fn parseTransform(raw: []const u8) Error!Transform {
    var result = Transform{};
    var index: usize = 0;
    while (true) {
        skipTransformSeparators(raw, &index);
        if (index >= raw.len) return result;
        const name_start = index;
        while (index < raw.len and std.ascii.isAlphabetic(raw[index])) : (index += 1) {}
        if (name_start == index) return error.InvalidSvg;
        const name = raw[name_start..index];
        skipTransformSeparators(raw, &index);
        if (index >= raw.len or raw[index] != '(') return error.InvalidSvg;
        index += 1;
        const args_start = index;
        while (index < raw.len and raw[index] != ')') : (index += 1) {}
        if (index >= raw.len) return error.InvalidSvg;
        const args = raw[args_start..index];
        index += 1;
        result = appendTransform(result, try parseTransformFunction(name, args));
    }
}

fn parseTransformFunction(name: []const u8, args: []const u8) Error!Transform {
    if (std.mem.eql(u8, name, "matrix")) return parseMatrix(args);
    if (std.mem.eql(u8, name, "translate")) return parseTranslate(args);
    if (std.mem.eql(u8, name, "scale")) return parseScale(args);
    if (std.mem.eql(u8, name, "rotate")) return parseRotate(args);
    if (std.mem.eql(u8, name, "skewX")) return parseSkewX(args);
    if (std.mem.eql(u8, name, "skewY")) return parseSkewY(args);
    return error.UnsupportedSvgElement;
}

fn parseMatrix(args: []const u8) Error!Transform {
    var values = NumberList.init(args);
    const a = try values.next();
    const b = try values.next();
    const c = try values.next();
    const d = try values.next();
    const e = try values.next();
    const f = try values.next();
    if (try values.hasMore()) return error.InvalidSvg;
    return .{ .a = a, .b = b, .c = c, .d = d, .e = e, .f = f };
}

fn parseTranslate(args: []const u8) Error!Transform {
    var values = NumberList.init(args);
    const tx = try values.next();
    const ty = if (try values.hasMore()) try values.next() else 0.0;
    if (try values.hasMore()) return error.InvalidSvg;
    return .{ .e = tx, .f = ty };
}

fn parseScale(args: []const u8) Error!Transform {
    var values = NumberList.init(args);
    const sx = try values.next();
    const sy = if (try values.hasMore()) try values.next() else sx;
    if (try values.hasMore()) return error.InvalidSvg;
    if (sx <= 0.0 or sy <= 0.0) return error.UnsupportedSvgElement;
    return .{ .a = sx, .d = sy };
}

fn parseRotate(args: []const u8) Error!Transform {
    var values = NumberList.init(args);
    const angle = degreesToRadians(try values.next());
    const cos_value = @cos(angle);
    const sin_value = @sin(angle);
    const rotation = Transform{
        .a = cos_value,
        .b = sin_value,
        .c = -sin_value,
        .d = cos_value,
    };
    if (!(try values.hasMore())) return rotation;
    const cx = try values.next();
    const cy = try values.next();
    if (try values.hasMore()) return error.InvalidSvg;
    return appendTransform(appendTransform(.{ .e = cx, .f = cy }, rotation), .{ .e = -cx, .f = -cy });
}

fn parseSkewX(args: []const u8) Error!Transform {
    var values = NumberList.init(args);
    const angle = degreesToRadians(try values.next());
    if (try values.hasMore()) return error.InvalidSvg;
    return .{ .c = @tan(angle) };
}

fn parseSkewY(args: []const u8) Error!Transform {
    var values = NumberList.init(args);
    const angle = degreesToRadians(try values.next());
    if (try values.hasMore()) return error.InvalidSvg;
    return .{ .b = @tan(angle) };
}

fn appendTransform(current: Transform, next: Transform) Transform {
    return .{
        .a = current.a * next.a + current.c * next.b,
        .b = current.b * next.a + current.d * next.b,
        .c = current.a * next.c + current.c * next.d,
        .d = current.b * next.c + current.d * next.d,
        .e = current.a * next.e + current.c * next.f + current.e,
        .f = current.b * next.e + current.d * next.f + current.f,
    };
}

fn skipTransformSeparators(raw: []const u8, index: *usize) void {
    while (index.* < raw.len) : (index.* += 1) {
        switch (raw[index.*]) {
            ' ', '\n', '\r', '\t', ',' => {},
            else => return,
        }
    }
}

fn degreesToRadians(value: f32) f32 {
    return value * std.math.pi / half_turn_degrees;
}

fn radiansToDegrees(value: f32) f32 {
    return value * half_turn_degrees / std.math.pi;
}

fn isIgnorableTag(tag: []const u8) bool {
    return std.mem.startsWith(u8, tag, "<!") or std.mem.startsWith(u8, tag, "<?") or std.mem.startsWith(u8, tag, "<svg") or std.mem.startsWith(u8, tag, "</svg");
}

fn isGroupOpenTag(tag: []const u8) bool {
    return tagHasName(tag, "g");
}

fn isGroupCloseTag(tag: []const u8) bool {
    return std.mem.startsWith(u8, tag, "</g") and tagNameBoundary(tag, 3);
}

fn isMetadataTag(tag: []const u8) bool {
    return tagHasName(tag, "title") or
        tagHasName(tag, "desc") or
        (std.mem.startsWith(u8, tag, "</title") and tagNameBoundary(tag, 7)) or
        (std.mem.startsWith(u8, tag, "</desc") and tagNameBoundary(tag, 6));
}

fn isSelfClosingTag(tag: []const u8) bool {
    var index = tag.len;
    while (index > 0) {
        index -= 1;
        if (std.ascii.isWhitespace(tag[index])) continue;
        return tag[index] == '/';
    }
    return false;
}

fn supportedElementKind(tag: []const u8) ?SvgElementKind {
    inline for (svg_element_names) |entry| {
        if (tagHasName(tag, entry.name)) return entry.kind;
    }
    return null;
}

fn unsupportedElementTag(tag: []const u8) bool {
    inline for (unsupported_svg_elements) |name| {
        if (tagHasName(tag, name)) return true;
    }
    return false;
}

fn svgContainsElementTag(svg: []const u8, name: []const u8) bool {
    var search_index: usize = 0;
    while (search_index < svg.len) {
        const tag_start_offset = std.mem.indexOfScalar(u8, svg[search_index..], '<') orelse return false;
        const tag_start = search_index + tag_start_offset;
        const tag_end_offset = std.mem.indexOfScalar(u8, svg[tag_start..], '>') orelse return false;
        const tag = svg[tag_start .. tag_start + tag_end_offset];
        if (tagHasName(tag, name)) return true;
        search_index = tag_start + tag_end_offset + 1;
    }
    return false;
}

fn tagHasName(tag: []const u8, name: []const u8) bool {
    if (tag.len < name.len + 1) return false;
    if (tag[0] != '<') return false;
    if (!std.mem.eql(u8, tag[1 .. 1 + name.len], name)) return false;
    return tagNameBoundary(tag, 1 + name.len);
}

fn tagNameBoundary(tag: []const u8, index: usize) bool {
    if (index >= tag.len) return true;
    return switch (tag[index]) {
        ' ', '\n', '\r', '\t', '/', '>' => true,
        else => false,
    };
}

const NumberList = struct {
    data: []const u8,
    index: usize = 0,

    fn init(data: []const u8) NumberList {
        return .{ .data = data };
    }

    fn next(self: *NumberList) Error!f32 {
        self.skipSeparators();
        const start = self.index;
        if (self.index < self.data.len and (self.data[self.index] == '-' or self.data[self.index] == '+')) self.index += 1;
        var has_digit = false;
        while (self.index < self.data.len and std.ascii.isDigit(self.data[self.index])) : (self.index += 1) has_digit = true;
        if (self.index < self.data.len and self.data[self.index] == '.') {
            self.index += 1;
            while (self.index < self.data.len and std.ascii.isDigit(self.data[self.index])) : (self.index += 1) has_digit = true;
        }
        if (!has_digit) return error.InvalidSvg;
        if (self.index < self.data.len and (self.data[self.index] == 'e' or self.data[self.index] == 'E')) {
            self.index += 1;
            if (self.index < self.data.len and (self.data[self.index] == '-' or self.data[self.index] == '+')) self.index += 1;
            var exponent_digits = false;
            while (self.index < self.data.len and std.ascii.isDigit(self.data[self.index])) : (self.index += 1) exponent_digits = true;
            if (!exponent_digits) return error.InvalidSvg;
        }
        return std.fmt.parseFloat(f32, self.data[start..self.index]) catch error.InvalidSvg;
    }

    fn hasMore(self: *NumberList) Error!bool {
        self.skipSeparators();
        return self.index < self.data.len;
    }

    fn skipSeparators(self: *NumberList) void {
        while (self.index < self.data.len) : (self.index += 1) {
            switch (self.data[self.index]) {
                ' ', '\n', '\r', '\t', ',' => {},
                else => return,
            }
        }
    }
};

const supported_stroke_width_attr = "stroke-width=\"2\"";
const supported_stroke_linecap_attr = "stroke-linecap=\"round\"";
const supported_stroke_linejoin_attr = "stroke-linejoin=\"round\"";
const svg_element_names = [_]struct {
    name: []const u8,
    kind: SvgElementKind,
}{
    .{ .name = "path", .kind = .path },
    .{ .name = "circle", .kind = .circle },
    .{ .name = "ellipse", .kind = .ellipse },
    .{ .name = "line", .kind = .line },
    .{ .name = "polyline", .kind = .polyline },
    .{ .name = "polygon", .kind = .polygon },
    .{ .name = "rect", .kind = .rect },
};
const unsupported_svg_elements = [_][]const u8{
    "clipPath",
    "defs",
    "linearGradient",
    "mask",
    "radialGradient",
    "style",
    "symbol",
    "use",
};
const max_pending_ops: usize = 128;
const max_transform_depth: usize = 16;
const half_turn_degrees: f32 = 180.0;
const transform_epsilon: f32 = 0.00001;

test "tabler search svg parses real path commands" {
    var iter = Iterator.init(source(.search));
    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.125, .y = 10.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .arc_to = .{
        .rx = 7.0 / 24.0,
        .ry = 7.0 / 24.0,
        .x_axis_rotation = 0.0,
        .large_arc = true,
        .sweep = false,
        .end = .{ .x = 17.0 / 24.0, .y = 10.0 / 24.0 },
    } }, (try iter.next()).?);
}

test "path parser supports quadratic and smooth quadratic commands" {
    var iter = PathIterator.init("M 2 2 Q 6 10 10 2 T 18 2");

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 2.0 / 24.0, .y = 2.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .quad_to = .{
        .control = .{ .x = 6.0 / 24.0, .y = 10.0 / 24.0 },
        .end = .{ .x = 10.0 / 24.0, .y = 2.0 / 24.0 },
    } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .quad_to = .{
        .control = .{ .x = 14.0 / 24.0, .y = -6.0 / 24.0 },
        .end = .{ .x = 18.0 / 24.0, .y = 2.0 / 24.0 },
    } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator normalizes path coordinates through viewBox" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="10 20 100 200" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path d='M 10 20 L 110 220 A 50 100 0 0 1 60 120'/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.0, .y = 0.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 1.0, .y = 1.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .arc_to = .{
        .rx = 0.5,
        .ry = 0.5,
        .x_axis_rotation = 0.0,
        .large_arc = false,
        .sweep = true,
        .end = .{ .x = 0.5, .y = 0.5 },
    } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator lowers basic shape elements" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 10" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <circle cx="10" cy="5" r="2"/>
        \\  <ellipse cx="5" cy="5" rx="4" ry="2"/>
        \\  <line x1="0" y1="0" x2="20" y2="10"/>
        \\  <polyline points="0,10 10,0 20,10"/>
        \\  <polygon points="2,2 18,2 10,8"/>
        \\  <rect x="2" y="1" width="6" height="4" rx="1"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .ellipse = .{ .cx = 0.5, .cy = 0.5, .rx = 0.1, .ry = 0.2, .full = true } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .ellipse = .{ .cx = 0.25, .cy = 0.5, .rx = 0.2, .ry = 0.2, .full = true } }, (try iter.next()).?);
    const line = (try iter.next()).?.polyline;
    try std.testing.expectEqualSlices(f32, &.{ 0.0, 0.0, 1.0, 1.0 }, line);
    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.0, .y = 1.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 0.5, .y = 0.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 1.0, .y = 1.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.1, .y = 0.2 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 0.9, .y = 0.2 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 0.5, .y = 0.8 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op.close_path, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .round_rect = .{ .x = 0.1, .y = 0.1, .w = 0.3, .h = 0.4, .radius = 0.05 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator applies translate and scale transforms" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path transform="translate(10 20) scale(2)" d="M 0 0 L 5 10"/>
        \\  <circle transform="scale(2)" cx="10" cy="10" r="5"/>
        \\  <line transform="translate(5,10)" x1="0" y1="0" x2="10" y2="20"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.1, .y = 0.2 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 0.2, .y = 0.4 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .circle = .{ .cx = 0.2, .cy = 0.2, .radius = 0.1 } }, (try iter.next()).?);
    const line = (try iter.next()).?.polyline;
    try std.testing.expectEqualSlices(f32, &.{ 0.05, 0.1, 0.15, 0.3 }, line);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator supports rotate and matrix transforms" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path transform="rotate(45)" d="M 0 0 L 1 1"/>
        \\  <path transform="matrix(1 0 0 1 2 3)" d="M 1 1 L 2 2"/>
        \\</svg>
    );

    const start = (try iter.next()).?.move_to;
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), start.x, transform_epsilon);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), start.y, transform_epsilon);
    const rotated = (try iter.next()).?.line_to;
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), rotated.x, transform_epsilon);
    try std.testing.expectApproxEqAbs(@as(f32, @sqrt(@as(f32, 2.0)) / 24.0), rotated.y, transform_epsilon);
    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 3.0 / 24.0, .y = 4.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 4.0 / 24.0, .y = 5.0 / 24.0 } }, (try iter.next()).?);
}

test "svg iterator supports skew transforms for path geometry" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path transform="skewX(45)" d="M 0 0 L 1 1"/>
        \\  <path transform="skewY(45)" d="M 1 1 L 2 1"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.0, .y = 0.0 } }, (try iter.next()).?);
    const skew_x = (try iter.next()).?.line_to;
    try std.testing.expectApproxEqAbs(@as(f32, 2.0 / 24.0), skew_x.x, transform_epsilon);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0 / 24.0), skew_x.y, transform_epsilon);
    const skew_y_start = (try iter.next()).?.move_to;
    try std.testing.expectApproxEqAbs(@as(f32, 1.0 / 24.0), skew_y_start.x, transform_epsilon);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0 / 24.0), skew_y_start.y, transform_epsilon);
    const skew_y_end = (try iter.next()).?.line_to;
    try std.testing.expectApproxEqAbs(@as(f32, 2.0 / 24.0), skew_y_end.x, transform_epsilon);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0 / 24.0), skew_y_end.y, transform_epsilon);
}

test "svg iterator rejects unsupported transform functions" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <path transform="notARealSvgTransform(45)" d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectError(error.UnsupportedSvgElement, iter.next());
}

test "svg iterator applies nested group transforms" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <g transform="translate(1 1)">
        \\    <g transform="scale(2)">
        \\      <path d="M 1 1 L 2 2"/>
        \\    </g>
        \\    <path d="M 0 0 L 1 1"/>
        \\  </g>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 3.0 / 24.0, .y = 3.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 5.0 / 24.0, .y = 5.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 2.0 / 24.0, .y = 2.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "svg iterator rejects unsupported containers instead of skipping them" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <defs>
        \\    <path id="x" d="M 0 0 L 1 1"/>
        \\  </defs>
        \\</svg>
    );

    try std.testing.expectError(error.UnsupportedSvgElement, iter.next());
}

test "svg iterator skips metadata and rejects unknown elements" {
    var with_metadata = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <title>Search</title>
        \\  <desc>Decorative icon</desc>
        \\  <path d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 0.0, .y = 0.0 } }, (try with_metadata.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try with_metadata.next()).?);

    var unknown = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <foreignObject width="24" height="24"/>
        \\</svg>
    );

    try std.testing.expectError(error.UnsupportedSvgElement, unknown.next());
}

test "svg iterator rejects malformed optional rect attributes" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        \\  <rect x="wat" y="0" width="10" height="10"/>
        \\</svg>
    );

    try std.testing.expectError(error.InvalidSvg, iter.next());
}

test "svg iterator rejects missing viewBox in strict icon svg path" {
    var iter = Iterator.init(
        \\<svg xmlns="http://www.w3.org/2000/svg">
        \\  <path d="M 0 0 L 1 1"/>
        \\</svg>
    );

    try std.testing.expectError(error.InvalidSvg, iter.next());
}

test "path parser supports relative quadratic commands" {
    var iter = PathIterator.init("M 4 4 q 4 6 8 0 t 8 0");

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 4.0 / 24.0, .y = 4.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .quad_to = .{
        .control = .{ .x = 8.0 / 24.0, .y = 10.0 / 24.0 },
        .end = .{ .x = 12.0 / 24.0, .y = 4.0 / 24.0 },
    } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .quad_to = .{
        .control = .{ .x = 16.0 / 24.0, .y = -2.0 / 24.0 },
        .end = .{ .x = 20.0 / 24.0, .y = 4.0 / 24.0 },
    } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "path parser follows svg arc radius normalization" {
    var iter = PathIterator.init("M 1 1 A -4 -5 0 0 1 9 9 A 0 5 0 0 1 12 12");

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .arc_to = .{
        .rx = 4.0 / 24.0,
        .ry = 5.0 / 24.0,
        .x_axis_rotation = 0.0,
        .large_arc = false,
        .sweep = true,
        .end = .{ .x = 9.0 / 24.0, .y = 9.0 / 24.0 },
    } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .line_to = .{ .x = 12.0 / 24.0, .y = 12.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "path parser accepts packed svg arc flags" {
    var iter = PathIterator.init("M 1 1 A 5 6 0 0110 10");

    try std.testing.expectEqual(icon_vector.Op{ .move_to = .{ .x = 1.0 / 24.0, .y = 1.0 / 24.0 } }, (try iter.next()).?);
    try std.testing.expectEqual(icon_vector.Op{ .arc_to = .{
        .rx = 5.0 / 24.0,
        .ry = 6.0 / 24.0,
        .x_axis_rotation = 0.0,
        .large_arc = false,
        .sweep = true,
        .end = .{ .x = 10.0 / 24.0, .y = 10.0 / 24.0 },
    } }, (try iter.next()).?);
    try std.testing.expectEqual(@as(?icon_vector.Op, null), try iter.next());
}

test "smooth quadratic resets after non quadratic command" {
    var iter = PathIterator.init("M 2 2 Q 6 10 10 2 L 12 2 T 18 2");

    _ = try iter.next();
    _ = try iter.next();
    _ = try iter.next();
    try std.testing.expectEqual(icon_vector.Op{ .quad_to = .{
        .control = .{ .x = 12.0 / 24.0, .y = 2.0 / 24.0 },
        .end = .{ .x = 18.0 / 24.0, .y = 2.0 / 24.0 },
    } }, (try iter.next()).?);
}

test "all mapped tabler svgs parse without invalid path data" {
    inline for (std.meta.fields(icon.Icon)) |field| {
        var iter = Iterator.init(source(@enumFromInt(field.value)));
        var count: usize = 0;
        while (try iter.next()) |_| count += 1;
        try std.testing.expect(count > 0);
    }
}

test "all mapped tabler svgs match supported stroke contract" {
    inline for (std.meta.fields(icon.Icon)) |field| {
        try validateSupportedTablerStroke(source(@enumFromInt(field.value)));
    }
}
