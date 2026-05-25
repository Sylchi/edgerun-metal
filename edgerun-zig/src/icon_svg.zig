const std = @import("std");
const icon = @import("icon.zig");
const icon_vector = @import("icon_vector.zig");

const viewbox_size: f32 = 24.0;

pub const Error = error{
    InvalidSvg,
    InvalidPath,
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

    pub fn init(svg: []const u8) Iterator {
        return .{ .svg = svg };
    }

    pub fn next(self: *Iterator) Error!?icon_vector.Op {
        while (true) {
            if (self.path) |*path| {
                if (try path.next()) |op| return op;
                self.path = null;
            }
            const d = try self.nextPathData() orelse return null;
            self.path = PathIterator.init(d);
        }
    }

    pub fn nextPathData(self: *Iterator) Error!?[]const u8 {
        const path_pos = std.mem.indexOf(u8, self.svg[self.search_index..], "<path") orelse return null;
        const path_start = self.search_index + path_pos;
        const tag_end_offset = std.mem.indexOfScalar(u8, self.svg[path_start..], '>') orelse return error.InvalidSvg;
        const tag = self.svg[path_start .. path_start + tag_end_offset];
        self.search_index = path_start + tag_end_offset + 1;
        const d_pos = std.mem.indexOf(u8, tag, "d=\"") orelse return error.InvalidSvg;
        const d_start = d_pos + 3;
        const d_end_offset = std.mem.indexOfScalar(u8, tag[d_start..], '"') orelse return error.InvalidSvg;
        return tag[d_start .. d_start + d_end_offset];
    }
};

pub const PathIterator = struct {
    data: []const u8,
    index: usize = 0,
    command: u8 = 0,
    current: icon_vector.Point = .{ .x = 0.0, .y = 0.0 },
    subpath_start: icon_vector.Point = .{ .x = 0.0, .y = 0.0 },
    previous_cubic_control: ?icon_vector.Point = null,

    pub fn init(data: []const u8) PathIterator {
        return .{ .data = data };
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
        self.command = if (relative) 'l' else 'L';
        return .{ .move_to = normalize(target) };
    }

    fn lineTo(self: *PathIterator) Error!?icon_vector.Op {
        const target = try self.point(self.command == 'l');
        self.current = target;
        self.previous_cubic_control = null;
        return .{ .line_to = normalize(target) };
    }

    fn horizontalLineTo(self: *PathIterator) Error!?icon_vector.Op {
        const x = try self.number();
        const next_x = if (self.command == 'h') self.current.x + x else x;
        self.current = .{ .x = next_x, .y = self.current.y };
        self.previous_cubic_control = null;
        return .{ .line_to = normalize(self.current) };
    }

    fn verticalLineTo(self: *PathIterator) Error!?icon_vector.Op {
        const y = try self.number();
        const next_y = if (self.command == 'v') self.current.y + y else y;
        self.current = .{ .x = self.current.x, .y = next_y };
        self.previous_cubic_control = null;
        return .{ .line_to = normalize(self.current) };
    }

    fn cubicTo(self: *PathIterator) Error!?icon_vector.Op {
        const relative = self.command == 'c';
        const c0 = try self.point(relative);
        const c1 = try self.point(relative);
        const end = try self.point(relative);
        self.current = end;
        self.previous_cubic_control = c1;
        return .{ .cubic_to = .{ .control0 = normalize(c0), .control1 = normalize(c1), .end = normalize(end) } };
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
        return .{ .cubic_to = .{ .control0 = normalize(reflected), .control1 = normalize(c1), .end = normalize(end) } };
    }

    fn arcTo(self: *PathIterator) Error!?icon_vector.Op {
        const relative = self.command == 'a';
        const rx = try self.number();
        const ry = try self.number();
        const rotation = try self.number();
        const large_arc = try self.flag();
        const sweep = try self.flag();
        const end = try self.point(relative);
        self.current = end;
        self.previous_cubic_control = null;
        return .{ .arc_to = .{
            .rx = rx / viewbox_size,
            .ry = ry / viewbox_size,
            .x_axis_rotation = rotation,
            .large_arc = large_arc,
            .sweep = sweep,
            .end = normalize(end),
        } };
    }

    fn closePath(self: *PathIterator) Error!?icon_vector.Op {
        self.current = self.subpath_start;
        self.previous_cubic_control = null;
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
        const value = try self.number();
        if (value == 0.0) return false;
        if (value == 1.0) return true;
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
};

fn isCommand(value: u8) bool {
    return switch (value) {
        'M', 'm', 'L', 'l', 'H', 'h', 'V', 'v', 'C', 'c', 'S', 's', 'A', 'a', 'Z', 'z' => true,
        else => false,
    };
}

fn normalize(point: icon_vector.Point) icon_vector.Point {
    return .{ .x = point.x / viewbox_size, .y = point.y / viewbox_size };
}

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

test "all mapped tabler svgs parse without invalid path data" {
    inline for (std.meta.fields(icon.Icon)) |field| {
        var iter = Iterator.init(source(@enumFromInt(field.value)));
        var count: usize = 0;
        while (try iter.next()) |_| count += 1;
        try std.testing.expect(count > 0);
    }
}
