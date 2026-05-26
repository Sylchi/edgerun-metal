const std = @import("std");
const st7789 = @import("st7789.zig");

pub const gpio_base: u32 = 0x2020_0000;
pub const spi0_base: u32 = 0x2020_4000;

pub const gpio_gpfsel0: u32 = 0x00;
pub const gpio_gpfsel1: u32 = 0x04;
pub const gpio_gpfsel2: u32 = 0x08;
pub const gpio_gpset0: u32 = 0x1c;
pub const gpio_gpclr0: u32 = 0x28;
pub const gpio_gplev0: u32 = 0x34;
pub const gpio_gppud: u32 = 0x94;
pub const gpio_gppudclk0: u32 = 0x98;

pub const spi0_cs: u32 = 0x00;
pub const spi0_fifo: u32 = 0x04;
pub const spi0_clk: u32 = 0x08;
pub const spi0_cs_chip_select_0: u32 = 0x0000_0000;
pub const spi0_cs_clear_tx_rx: u32 = 0x0000_0030;
pub const spi0_cs_ta: u32 = 0x0000_0080;
pub const spi0_cs_done: u32 = 0x0001_0000;
pub const spi0_cs_rxd: u32 = 0x0002_0000;
pub const spi0_cs_txd: u32 = 0x0004_0000;
pub const spi0_clock_divisor: u32 = 64;

pub const pin_lcd_cs: u32 = 8;
pub const pin_lcd_mosi: u32 = 10;
pub const pin_lcd_sclk: u32 = 11;
pub const pin_lcd_bl: u32 = 24;
pub const pin_lcd_dc: u32 = 25;
pub const pin_lcd_rst: u32 = 27;
pub const pin_lcd_key1: u32 = 21;
pub const pin_lcd_key2: u32 = 20;
pub const pin_lcd_key3: u32 = 16;
pub const pin_lcd_joystick_up: u32 = 6;
pub const pin_lcd_joystick_down: u32 = 19;
pub const pin_lcd_joystick_left: u32 = 5;
pub const pin_lcd_joystick_right: u32 = 26;
pub const pin_lcd_joystick_press: u32 = 13;

pub const gpio_input: u32 = 0;
pub const gpio_output: u32 = 1;
pub const gpio_alt0: u32 = 4;
pub const gpio_pull_disable: u32 = 0;
pub const gpio_pull_up: u32 = 2;

pub const set_lcd_cs: u32 = 1 << pin_lcd_cs;
pub const set_lcd_mosi: u32 = 1 << pin_lcd_mosi;
pub const set_lcd_sclk: u32 = 1 << pin_lcd_sclk;
pub const set_lcd_bl: u32 = 1 << pin_lcd_bl;
pub const set_lcd_dc: u32 = 1 << pin_lcd_dc;
pub const set_lcd_rst: u32 = 1 << pin_lcd_rst;
pub const set_lcd_key1: u32 = 1 << pin_lcd_key1;
pub const set_lcd_key2: u32 = 1 << pin_lcd_key2;
pub const set_lcd_key3: u32 = 1 << pin_lcd_key3;
pub const set_lcd_joystick_up: u32 = 1 << pin_lcd_joystick_up;
pub const set_lcd_joystick_down: u32 = 1 << pin_lcd_joystick_down;
pub const set_lcd_joystick_left: u32 = 1 << pin_lcd_joystick_left;
pub const set_lcd_joystick_right: u32 = 1 << pin_lcd_joystick_right;
pub const set_lcd_joystick_press: u32 = 1 << pin_lcd_joystick_press;

pub const pull_clock_lcd: u32 = set_lcd_cs | set_lcd_mosi | set_lcd_sclk | set_lcd_bl | set_lcd_dc | set_lcd_rst;
pub const pull_clock_lcd_inputs: u32 = set_lcd_key1 | set_lcd_key2 | set_lcd_key3 | set_lcd_joystick_up | set_lcd_joystick_down | set_lcd_joystick_left | set_lcd_joystick_right | set_lcd_joystick_press;

pub const reset_delay_ticks: u32 = 20000;
pub const gpio_delay_ticks: u32 = 150;
pub const spi_poll_budget: u32 = 100000;

pub const Input = packed struct(u32) {
    up: bool = false,
    down: bool = false,
    left: bool = false,
    right: bool = false,
    press: bool = false,
    reserved0: u3 = 0,
    key1: bool = false,
    key2: bool = false,
    key3: bool = false,
    reserved1: u21 = 0,

    pub fn bits(self: Input) u32 {
        return @bitCast(self);
    }
};

pub const input_all: u32 = 0x0000_071f;

pub const DebugStatus = struct {
    heartbeat: u32 = 0,
    sdio_state: u32 = 0,
    storage_state: u32 = 0,
    wifi_state: u32 = 0,
    ota_status: u32 = 0,
    ota_offset: u32 = 0,
    l2_ready: u32 = 0,
    input_state: u32 = 0,
};

pub const GpioPlan = struct {
    fsel0: u32,
    fsel1: u32,
    fsel2: u32,
    output_pull_clock_mask: u32 = pull_clock_lcd,
    input_pull_clock_mask: u32 = pull_clock_lcd_inputs,
};

pub const Mmio = struct {
    user: ?*anyopaque = null,
    read32: *const fn (user: ?*anyopaque, base: u32, offset: u32) u32,
    write32: *const fn (user: ?*anyopaque, base: u32, offset: u32, value: u32) void,
    delay: ?*const fn (user: ?*anyopaque, ticks: u32) void = null,
};

pub const Hat = struct {
    mmio: Mmio,
    ready: bool = false,

    pub fn init(self: *Hat) bool {
        self.ready = false;
        self.applyGpioPlan(gpioPlan(
            self.mmio.read32(self.mmio.user, gpio_base, gpio_gpfsel0),
            self.mmio.read32(self.mmio.user, gpio_base, gpio_gpfsel1),
            self.mmio.read32(self.mmio.user, gpio_base, gpio_gpfsel2),
        ));
        self.mmio.write32(self.mmio.user, spi0_base, spi0_clk, spi0_clock_divisor);
        self.gpioSet(set_lcd_bl | set_lcd_rst);
        self.delay(reset_delay_ticks);
        self.gpioClear(set_lcd_rst);
        self.delay(reset_delay_ticks);
        self.gpioSet(set_lcd_rst);
        self.delay(reset_delay_ticks);

        const panel_bus = self.bus();
        if (!st7789.init(panel_bus) or
            !st7789.fillRect(panel_bus, 0, 0, st7789.width, st7789.height, .black) or
            !st7789.drawText(panel_bus, 8, 8, "EDGERUN", 3, .green, .black) or
            !st7789.drawText(panel_bus, 8, 40, "PI ZERO W", 2, .white, .black))
        {
            return false;
        }
        self.ready = true;
        return true;
    }

    pub fn inputState(self: *Hat) Input {
        return inputFromLevels(self.mmio.read32(self.mmio.user, gpio_base, gpio_gplev0));
    }

    pub fn status(self: *Hat, value: DebugStatus) bool {
        if (!self.ready) return false;
        const panel_bus = self.bus();
        if (!st7789.fillRect(panel_bus, 0, 62, st7789.width, st7789.height - 62, .black)) {
            self.ready = false;
            return false;
        }
        const ok =
            drawPair(panel_bus, 62, "SDIO", value.sdio_state, .yellow) and
            drawPair(panel_bus, 84, "STORE", value.storage_state, .white) and
            drawPair(panel_bus, 106, "WIFI", value.wifi_state, .cyan) and
            st7789.drawText(panel_bus, 8, 128, "L2", 2, .cyan, .black) and
            st7789.drawText(panel_bus, 8, 146, if (value.l2_ready != 0) "ON" else "OFF", 2, if (value.l2_ready != 0) .green else .red, .black) and
            drawPair(panel_bus, 150, "OTA", value.ota_status ^ value.ota_offset, .white) and
            drawPair(panel_bus, 172, "HB", value.heartbeat, .green) and
            drawPair(panel_bus, 194, "KEYS", value.input_state, .green);
        if (!ok) self.ready = false;
        return ok;
    }

    fn applyGpioPlan(self: *Hat, plan: GpioPlan) void {
        self.mmio.write32(self.mmio.user, gpio_base, gpio_gpfsel0, plan.fsel0);
        self.mmio.write32(self.mmio.user, gpio_base, gpio_gpfsel1, plan.fsel1);
        self.mmio.write32(self.mmio.user, gpio_base, gpio_gpfsel2, plan.fsel2);
        self.mmio.write32(self.mmio.user, gpio_base, gpio_gppud, gpio_pull_disable);
        self.delay(gpio_delay_ticks);
        self.mmio.write32(self.mmio.user, gpio_base, gpio_gppudclk0, plan.output_pull_clock_mask);
        self.delay(gpio_delay_ticks);
        self.mmio.write32(self.mmio.user, gpio_base, gpio_gppudclk0, gpio_pull_disable);
        self.mmio.write32(self.mmio.user, gpio_base, gpio_gppud, gpio_pull_up);
        self.delay(gpio_delay_ticks);
        self.mmio.write32(self.mmio.user, gpio_base, gpio_gppudclk0, plan.input_pull_clock_mask);
        self.delay(gpio_delay_ticks);
        self.mmio.write32(self.mmio.user, gpio_base, gpio_gppudclk0, gpio_pull_disable);
        self.mmio.write32(self.mmio.user, gpio_base, gpio_gppud, gpio_pull_disable);
    }

    fn bus(self: *Hat) st7789.Bus {
        return .{ .user = self, .write_command = writeCommand, .write_data = writeData, .delay = busDelay };
    }

    fn gpioSet(self: *Hat, mask: u32) void {
        self.mmio.write32(self.mmio.user, gpio_base, gpio_gpset0, mask);
    }

    fn gpioClear(self: *Hat, mask: u32) void {
        self.mmio.write32(self.mmio.user, gpio_base, gpio_gpclr0, mask);
    }

    fn delay(self: *Hat, ticks: u32) void {
        if (self.mmio.delay) |delay_fn| delay_fn(self.mmio.user, ticks);
    }
};

pub fn gpioFselAlt(current: u32, pin: u32, alt_function: u32) u32 {
    const shift = (pin % 10) * 3;
    const shift_amount: u5 = @intCast(shift);
    const mask: u32 = @as(u32, 7) << shift_amount;
    return (current & ~mask) | ((alt_function & 7) << shift_amount);
}

pub fn gpioPlan(fsel0_current: u32, fsel1_current: u32, fsel2_current: u32) GpioPlan {
    var fsel0 = fsel0_current;
    fsel0 = gpioFselAlt(fsel0, pin_lcd_joystick_left, gpio_input);
    fsel0 = gpioFselAlt(fsel0, pin_lcd_joystick_up, gpio_input);
    fsel0 = gpioFselAlt(fsel0, pin_lcd_cs, gpio_alt0);

    var fsel1 = fsel1_current;
    fsel1 = gpioFselAlt(fsel1, pin_lcd_joystick_press, gpio_input);
    fsel1 = gpioFselAlt(fsel1, pin_lcd_key3, gpio_input);
    fsel1 = gpioFselAlt(fsel1, pin_lcd_joystick_down, gpio_input);
    fsel1 = gpioFselAlt(fsel1, pin_lcd_mosi, gpio_alt0);
    fsel1 = gpioFselAlt(fsel1, pin_lcd_sclk, gpio_alt0);

    var fsel2 = fsel2_current;
    fsel2 = gpioFselAlt(fsel2, pin_lcd_key2, gpio_input);
    fsel2 = gpioFselAlt(fsel2, pin_lcd_key1, gpio_input);
    fsel2 = gpioFselAlt(fsel2, pin_lcd_bl, gpio_output);
    fsel2 = gpioFselAlt(fsel2, pin_lcd_dc, gpio_output);
    fsel2 = gpioFselAlt(fsel2, pin_lcd_joystick_right, gpio_input);
    fsel2 = gpioFselAlt(fsel2, pin_lcd_rst, gpio_output);
    return .{ .fsel0 = fsel0, .fsel1 = fsel1, .fsel2 = fsel2 };
}

pub fn inputFromLevels(levels: u32) Input {
    return .{
        .up = activeLow(levels, set_lcd_joystick_up),
        .down = activeLow(levels, set_lcd_joystick_down),
        .left = activeLow(levels, set_lcd_joystick_left),
        .right = activeLow(levels, set_lcd_joystick_right),
        .press = activeLow(levels, set_lcd_joystick_press),
        .key1 = activeLow(levels, set_lcd_key1),
        .key2 = activeLow(levels, set_lcd_key2),
        .key3 = activeLow(levels, set_lcd_key3),
    };
}

pub fn hex8(value: u32, out: *[10]u8) []const u8 {
    out[0] = '0';
    out[1] = 'X';
    var i: usize = 0;
    while (i < 8) : (i += 1) {
        const nibble: u8 = @intCast((value >> @intCast(28 - i * 4)) & 0x0f);
        out[i + 2] = if (nibble <= 9) '0' + nibble else 'A' + (nibble - 10);
    }
    return out;
}

fn drawPair(bus: st7789.Bus, y: u16, label: []const u8, value: u32, value_color: st7789.Color) bool {
    var raw: [10]u8 = undefined;
    const text = hex8(value, &raw);
    return st7789.drawText(bus, 8, y, label, 2, .cyan, .black) and
        st7789.drawText(bus, 8, y + 18, text, 2, value_color, .black);
}

fn activeLow(levels: u32, pin_mask: u32) bool {
    return (levels & pin_mask) == 0;
}

fn writeCommand(user: ?*anyopaque, command: u8) bool {
    const self: *Hat = @ptrCast(@alignCast(user.?));
    self.gpioClear(set_lcd_dc);
    return spiTransfer(self, &.{command});
}

fn writeData(user: ?*anyopaque, data: []const u8) bool {
    const self: *Hat = @ptrCast(@alignCast(user.?));
    self.gpioSet(set_lcd_dc);
    return spiTransfer(self, data);
}

fn busDelay(user: ?*anyopaque, ticks: u32) void {
    const self: *Hat = @ptrCast(@alignCast(user.?));
    self.delay(ticks);
}

fn spiTransfer(self: *Hat, data: []const u8) bool {
    self.mmio.write32(self.mmio.user, spi0_base, spi0_cs, spi0_cs_chip_select_0 | spi0_cs_clear_tx_rx | spi0_cs_ta);
    for (data) |byte| {
        if (!spiWait(self, spi0_cs_txd)) {
            self.mmio.write32(self.mmio.user, spi0_base, spi0_cs, spi0_cs_chip_select_0);
            return false;
        }
        self.mmio.write32(self.mmio.user, spi0_base, spi0_fifo, byte);
        while ((self.mmio.read32(self.mmio.user, spi0_base, spi0_cs) & spi0_cs_rxd) != 0) {
            _ = self.mmio.read32(self.mmio.user, spi0_base, spi0_fifo);
        }
    }
    if (!spiWait(self, spi0_cs_done)) {
        self.mmio.write32(self.mmio.user, spi0_base, spi0_cs, spi0_cs_chip_select_0);
        return false;
    }
    self.mmio.write32(self.mmio.user, spi0_base, spi0_cs, spi0_cs_chip_select_0);
    return true;
}

fn spiWait(self: *Hat, mask: u32) bool {
    var i: u32 = 0;
    while (i < spi_poll_budget) : (i += 1) {
        if ((self.mmio.read32(self.mmio.user, spi0_base, spi0_cs) & mask) != 0) return true;
    }
    return false;
}

const TestMmio = struct {
    writes: [32]struct { base: u32, offset: u32, value: u32 } = undefined,
    write_count: usize = 0,
    levels: u32 = 0xffff_ffff,
};

fn testRead(user: ?*anyopaque, base: u32, offset: u32) u32 {
    const io: *TestMmio = @ptrCast(@alignCast(user.?));
    if (base == gpio_base and offset == gpio_gplev0) return io.levels;
    if (base == spi0_base and offset == spi0_cs) return spi0_cs_txd | spi0_cs_done;
    return 0;
}

fn testWrite(user: ?*anyopaque, base: u32, offset: u32, value: u32) void {
    const io: *TestMmio = @ptrCast(@alignCast(user.?));
    if (io.write_count < io.writes.len) {
        io.writes[io.write_count] = .{ .base = base, .offset = offset, .value = value };
        io.write_count += 1;
    }
}

fn testDelay(user: ?*anyopaque, ticks: u32) void {
    _ = user;
    _ = ticks;
}

test "plans Pi Zero W LCD HAT GPIO and input semantics" {
    const plan = gpioPlan(0, 0, 0);
    try std.testing.expectEqual(@as(u32, 0x04000000), plan.fsel0);
    try std.testing.expectEqual(@as(u32, 0x00000024), plan.fsel1);
    try std.testing.expectEqual(@as(u32, 0x00209000), plan.fsel2);
    try std.testing.expectEqual(@as(u32, 0x04392060), pull_clock_lcd_inputs);
    try std.testing.expectEqual(input_all, (Input{ .up = true, .down = true, .left = true, .right = true, .press = true, .key1 = true, .key2 = true, .key3 = true }).bits());

    const levels = 0xffff_ffff & ~set_lcd_joystick_up & ~set_lcd_key2;
    const input = inputFromLevels(levels);
    try std.testing.expect(input.up);
    try std.testing.expect(input.key2);
    try std.testing.expect(!input.down);
}

test "initializes LCD HAT GPIO and SPI boundary" {
    var io = TestMmio{};
    var hat = Hat{ .mmio = .{ .user = &io, .read32 = testRead, .write32 = testWrite, .delay = testDelay } };
    try std.testing.expect(hat.init());
    try std.testing.expect(hat.ready);
    try std.testing.expect(io.write_count > 10);
    try std.testing.expectEqual(gpio_base, io.writes[0].base);
    try std.testing.expectEqual(gpio_gpfsel0, io.writes[0].offset);
}
