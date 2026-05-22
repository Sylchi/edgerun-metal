const std = @import("std");

pub const width: u16 = 240;
pub const height: u16 = 240;

pub const Color = enum(u16) {
    black = 0x0000,
    white = 0xffff,
    red = 0xf800,
    green = 0x07e0,
    blue = 0x001f,
    cyan = 0x07ff,
    yellow = 0xffe0,
    gray = 0x8410,
};

pub const reset_delay_ticks: u32 = 120000;
pub const sleep_out_delay_ticks: u32 = 120000;
pub const display_on_delay_ticks: u32 = 120000;

pub const Bus = struct {
    user: ?*anyopaque = null,
    write_command: *const fn (user: ?*anyopaque, command: u8) bool,
    write_data: *const fn (user: ?*anyopaque, data: []const u8) bool,
    delay: ?*const fn (user: ?*anyopaque, ticks: u32) void = null,

    pub fn valid(self: Bus) bool {
        _ = self;
        return true;
    }
};

pub fn init(bus: Bus) bool {
    if (!bus.valid() or !bus.write_command(bus.user, 0x01)) return false;
    busDelay(bus, reset_delay_ticks);
    if (!bus.write_command(bus.user, 0x11)) return false;
    busDelay(bus, sleep_out_delay_ticks);
    if (!commandData(bus, 0x3a, &.{0x55}) or
        !commandData(bus, 0x36, &.{0x00}) or
        !bus.write_command(bus.user, 0x21) or
        !bus.write_command(bus.user, 0x13) or
        !bus.write_command(bus.user, 0x29))
    {
        return false;
    }
    busDelay(bus, display_on_delay_ticks);
    return true;
}

pub fn fillRect(bus: Bus, x: u16, y: u16, w: u16, h: u16, color: Color) bool {
    if (!bus.valid() or w == 0 or h == 0 or @as(u32, x) + w > width or @as(u32, y) + h > height) return false;
    if (!setWindow(bus, x, y, x + w - 1, y + h - 1)) return false;
    const pixel = [_]u8{ @intCast(@intFromEnum(color) >> 8), @intCast(@intFromEnum(color) & 0xff) };
    var remaining: u32 = @as(u32, w) * h;
    while (remaining != 0) : (remaining -= 1) {
        if (!bus.write_data(bus.user, &pixel)) return false;
    }
    return true;
}

pub fn drawText(bus: Bus, x: u16, y: u16, text: []const u8, scale: u8, fg: Color, bg: Color) bool {
    if (!bus.valid() or scale == 0) return false;
    for (text, 0..) |ch, index| {
        var column: u16 = 0;
        while (column < 5) : (column += 1) {
            const bits = glyphColumn(ch, column) & 0x7f;
            var row: u16 = 0;
            while (row < 7) : (row += 1) {
                const color = if (((bits >> @intCast(row)) & 1) != 0) fg else bg;
                const px: u16 = x + @as(u16, @intCast((index * 6 + column) * scale));
                const py: u16 = y + row * scale;
                if (!fillRect(bus, px, py, scale, scale, color)) return false;
            }
        }
    }
    return true;
}

fn commandData(bus: Bus, command: u8, data: []const u8) bool {
    if (!bus.write_command(bus.user, command)) return false;
    return data.len == 0 or bus.write_data(bus.user, data);
}

fn setWindow(bus: Bus, x0: u16, y0: u16, x1: u16, y1: u16) bool {
    var address: [4]u8 = undefined;
    putBe16(address[0..2], x0);
    putBe16(address[2..4], x1);
    if (!commandData(bus, 0x2a, &address)) return false;
    putBe16(address[0..2], y0);
    putBe16(address[2..4], y1);
    return commandData(bus, 0x2b, &address) and bus.write_command(bus.user, 0x2c);
}

fn busDelay(bus: Bus, ticks: u32) void {
    if (bus.delay) |delay| delay(bus.user, ticks);
}

fn putBe16(out: []u8, value: u16) void {
    out[0] = @intCast(value >> 8);
    out[1] = @intCast(value & 0xff);
}

fn glyphColumn(ch: u8, column: u16) u8 {
    const g = switch (ch) {
        '0' => [_]u8{ 0x3e, 0x51, 0x49, 0x45, 0x3e },
        '1' => [_]u8{ 0x00, 0x42, 0x7f, 0x40, 0x00 },
        '2' => [_]u8{ 0x42, 0x61, 0x51, 0x49, 0x46 },
        '3' => [_]u8{ 0x21, 0x41, 0x45, 0x4b, 0x31 },
        '4' => [_]u8{ 0x18, 0x14, 0x12, 0x7f, 0x10 },
        '5' => [_]u8{ 0x27, 0x45, 0x45, 0x45, 0x39 },
        '6' => [_]u8{ 0x3c, 0x4a, 0x49, 0x49, 0x30 },
        '7' => [_]u8{ 0x01, 0x71, 0x09, 0x05, 0x03 },
        '8' => [_]u8{ 0x36, 0x49, 0x49, 0x49, 0x36 },
        '9' => [_]u8{ 0x06, 0x49, 0x49, 0x29, 0x1e },
        'A' => [_]u8{ 0x7e, 0x11, 0x11, 0x11, 0x7e },
        'B' => [_]u8{ 0x7f, 0x49, 0x49, 0x49, 0x36 },
        'C' => [_]u8{ 0x3e, 0x41, 0x41, 0x41, 0x22 },
        'D' => [_]u8{ 0x7f, 0x41, 0x41, 0x22, 0x1c },
        'E' => [_]u8{ 0x7f, 0x49, 0x49, 0x49, 0x41 },
        'F' => [_]u8{ 0x7f, 0x09, 0x09, 0x09, 0x01 },
        'G' => [_]u8{ 0x3e, 0x41, 0x49, 0x49, 0x7a },
        'H' => [_]u8{ 0x7f, 0x08, 0x08, 0x08, 0x7f },
        'I' => [_]u8{ 0x00, 0x41, 0x7f, 0x41, 0x00 },
        'J' => [_]u8{ 0x20, 0x40, 0x41, 0x3f, 0x01 },
        'K' => [_]u8{ 0x7f, 0x08, 0x14, 0x22, 0x41 },
        'L' => [_]u8{ 0x7f, 0x40, 0x40, 0x40, 0x40 },
        'M' => [_]u8{ 0x7f, 0x02, 0x0c, 0x02, 0x7f },
        'N' => [_]u8{ 0x7f, 0x04, 0x08, 0x10, 0x7f },
        'O' => [_]u8{ 0x3e, 0x41, 0x41, 0x41, 0x3e },
        'P' => [_]u8{ 0x7f, 0x09, 0x09, 0x09, 0x06 },
        'Q' => [_]u8{ 0x3e, 0x41, 0x51, 0x21, 0x5e },
        'R' => [_]u8{ 0x7f, 0x09, 0x19, 0x29, 0x46 },
        'S' => [_]u8{ 0x46, 0x49, 0x49, 0x49, 0x31 },
        'T' => [_]u8{ 0x01, 0x01, 0x7f, 0x01, 0x01 },
        'U' => [_]u8{ 0x3f, 0x40, 0x40, 0x40, 0x3f },
        'V' => [_]u8{ 0x1f, 0x20, 0x40, 0x20, 0x1f },
        'W' => [_]u8{ 0x3f, 0x40, 0x38, 0x40, 0x3f },
        'X' => [_]u8{ 0x63, 0x14, 0x08, 0x14, 0x63 },
        'Y' => [_]u8{ 0x07, 0x08, 0x70, 0x08, 0x07 },
        'Z' => [_]u8{ 0x61, 0x51, 0x49, 0x45, 0x43 },
        '-' => [_]u8{ 0x08, 0x08, 0x08, 0x08, 0x08 },
        ':' => [_]u8{ 0x00, 0x36, 0x36, 0x00, 0x00 },
        '.' => [_]u8{ 0x00, 0x60, 0x60, 0x00, 0x00 },
        '_' => [_]u8{ 0x40, 0x40, 0x40, 0x40, 0x40 },
        else => [_]u8{ 0x00, 0x00, 0x00, 0x00, 0x00 },
    };
    return g[column];
}

const TestBus = struct {
    commands: [16]u8 = [_]u8{0} ** 16,
    command_count: usize = 0,
    data_bytes: usize = 0,
    delays: usize = 0,
};

fn testCommand(user: ?*anyopaque, command: u8) bool {
    const bus: *TestBus = @ptrCast(@alignCast(user.?));
    bus.commands[bus.command_count] = command;
    bus.command_count += 1;
    return true;
}

fn testData(user: ?*anyopaque, data: []const u8) bool {
    const bus: *TestBus = @ptrCast(@alignCast(user.?));
    bus.data_bytes += data.len;
    return true;
}

fn testDelay(user: ?*anyopaque, ticks: u32) void {
    _ = ticks;
    const bus: *TestBus = @ptrCast(@alignCast(user.?));
    bus.delays += 1;
}

test "initializes ST7789 and writes RGB565 rectangles" {
    var test_bus = TestBus{};
    const bus = Bus{ .user = &test_bus, .write_command = testCommand, .write_data = testData, .delay = testDelay };
    try std.testing.expect(init(bus));
    try std.testing.expectEqual(@as(u8, 0x01), test_bus.commands[0]);
    try std.testing.expectEqual(@as(u8, 0x11), test_bus.commands[1]);
    try std.testing.expectEqual(@as(u8, 0x29), test_bus.commands[6]);
    try std.testing.expectEqual(@as(usize, 3), test_bus.delays);

    const before = test_bus.data_bytes;
    try std.testing.expect(fillRect(bus, 1, 2, 2, 3, .green));
    try std.testing.expectEqual(@as(usize, before + 4 + 4 + 2 * 2 * 3), test_bus.data_bytes);
    try std.testing.expect(!fillRect(bus, 239, 239, 2, 1, .red));
}
