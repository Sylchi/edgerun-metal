const pi_mmc = @import("pi_mmc.zig");
const pi_zero = @import("pi_zero_w_v1_1.zig");
const bytes = @import("bytes.zig");

pub const gpio_base: u32 = 0x2020_0000;
pub const emmc_base: u32 = 0x2030_0000;
pub const aux_base: u32 = 0x2021_5000;

pub const gpio_fsel1: u32 = 0x04;
pub const gpio_fsel4: u32 = 0x10;
pub const gpio_set1: u32 = 0x20;
pub const gpio_clr1: u32 = 0x2c;
pub const gpio_pud: u32 = 0x94;
pub const gpio_pudclk0: u32 = 0x98;

pub const aux_enables: u32 = 0x04;
pub const aux_mu_io: u32 = 0x40;
pub const aux_mu_ier: u32 = 0x44;
pub const aux_mu_iir: u32 = 0x48;
pub const aux_mu_lcr: u32 = 0x4c;
pub const aux_mu_mcr: u32 = 0x50;
pub const aux_mu_lsr: u32 = 0x54;
pub const aux_mu_cntl: u32 = 0x60;
pub const aux_mu_baud: u32 = 0x68;

pub const emmc_reg_status: u32 = 0x24;
pub const emmc_reg_control1: u32 = 0x2c;
pub const emmc_reg_irpt_mask: u32 = 0x34;
pub const emmc_reg_irpt_en: u32 = 0x38;
pub const emmc_status_cmd_inhibit: u32 = 0x0000_0001;
pub const emmc_status_data_inhibit: u32 = 0x0000_0002;
pub const emmc_control1_clk_intlen: u32 = 0x0000_0001;
pub const emmc_control1_clk_stable: u32 = 0x0000_0002;
pub const emmc_control1_clk_en: u32 = 0x0000_0004;
pub const emmc_control1_clk_gensel: u32 = 0x0000_0020;
pub const emmc_control1_srst_hc: u32 = 0x0100_0000;
pub const emmc_ident_clock_divisor: u32 = 626;

pub const sd_if_cond_3v3_check: u32 = 0x0000_01aa;
pub const sd_ocr_3v3_hcs: u32 = 0x4030_0000;
pub const sd_ocr_ready: u32 = 0x8000_0000;
pub const sd_poll_budget: u32 = 1_000_000;
pub const sd_ocr_poll_budget: u32 = 1_000;

pub const pin_uart_tx: u32 = 14;
pub const pin_uart_rx: u32 = 15;
pub const pin_act_led: u32 = 47;
pub const gpio_output: u32 = 1;
pub const gpio_alt5: u32 = 2;

pub const RawLogState = struct {
    stage: u32 = 0,
    interrupt: u32 = 0,
    response: u32 = 0,
    relative_card_address: u32 = 0,
    write_result: u32 = 0,
};

pub const Mmio = struct {
    user: ?*anyopaque = null,
    read32: *const fn (user: ?*anyopaque, base: u32, offset: u32) u32,
    write32: *const fn (user: ?*anyopaque, base: u32, offset: u32, value: u32) void,
    delay: *const fn (user: ?*anyopaque, ticks: u32) void,
};

pub const Board = struct {
    mmio: Mmio,
    raw_log: RawLogState = .{},

    pub fn initEarly(self: *Board) void {
        self.actLedInit();
        self.actLedOff();
        self.uartInit();
    }

    pub fn putString(self: *Board, text: []const u8) void {
        for (text) |byte| self.putByte(byte);
    }

    pub fn putHex32(self: *Board, value: u32) void {
        self.putString("0x");
        var shift: u5 = 28;
        while (true) {
            const nibble: u8 = @intCast((value >> shift) & 0x0f);
            self.putByte(if (nibble <= 9) '0' + nibble else 'a' + (nibble - 10));
            if (shift == 0) break;
            shift -= 4;
        }
    }

    pub fn logToSd(self: *Board) bool {
        if (!self.sdMemoryInit()) {
            self.putString("sd=init-fail stage=");
            self.putHex32(self.raw_log.stage);
            self.putString(" intr=");
            self.putHex32(self.raw_log.interrupt);
            self.putString(" resp=");
            self.putHex32(self.raw_log.response);
            self.putString("\r\n");
            return false;
        }
        var block = rawLogBlock(self.raw_log, 0x10);
        if (!self.writeBlock(pi_zero.boot_checkpoint_block, &block)) {
            self.putString("sd=write-fail checkpoint write=");
            self.putHex32(self.raw_log.write_result);
            self.putString(" intr=");
            self.putHex32(self.raw_log.interrupt);
            self.putString(" resp=");
            self.putHex32(self.raw_log.response);
            self.putString("\r\n");
            return false;
        }
        block = rawLogBlock(self.raw_log, 0x11);
        if (!self.writeBlock(pi_zero.boot_log_start_block, &block)) {
            self.putString("sd=write-fail event write=");
            self.putHex32(self.raw_log.write_result);
            self.putString(" intr=");
            self.putHex32(self.raw_log.interrupt);
            self.putString(" resp=");
            self.putHex32(self.raw_log.response);
            self.putString("\r\n");
            return false;
        }
        self.putString("sd=logged stage=");
        self.putHex32(self.raw_log.stage);
        self.putString(" rca=");
        self.putHex32(self.raw_log.relative_card_address);
        self.putString(" write=");
        self.putHex32(self.raw_log.write_result);
        self.putString("\r\n");
        return true;
    }

    pub fn failureCode(self: *Board) u32 {
        if ((self.raw_log.write_result & 0x8000_0000) != 0) return self.raw_log.write_result & 0xff;
        if ((self.raw_log.stage & 0x8000_0000) != 0) return self.raw_log.stage & 0xff;
        return 31;
    }

    pub fn signalFailure(self: *Board, raw_code: u32) noreturn {
        const code = if (raw_code == 0) 31 else if (raw_code > 31) 31 else raw_code;
        self.putString("led=failure-code ");
        self.putHex32(code);
        self.putString("\r\n");
        while (true) {
            self.actLedOff();
            self.mmio.delay(self.mmio.user, 2_500_000);
            var i: u32 = 0;
            while (i < code) : (i += 1) {
                self.actLedOn();
                self.mmio.delay(self.mmio.user, 180_000);
                self.actLedOff();
                self.mmio.delay(self.mmio.user, 180_000);
            }
            self.mmio.delay(self.mmio.user, 1_000_000);
        }
    }

    pub fn heartbeat(self: *Board) noreturn {
        while (true) {
            self.actLedOn();
            self.putString("ER ZIG ALIVE\r\n");
            self.mmio.delay(self.mmio.user, 800_000);
            self.actLedOff();
            self.mmio.delay(self.mmio.user, 800_000);
        }
    }

    fn uartInit(self: *Board) void {
        var fsel1 = self.read(gpio_base, gpio_fsel1);
        fsel1 = gpioFselAlt(fsel1, pin_uart_tx, gpio_alt5);
        fsel1 = gpioFselAlt(fsel1, pin_uart_rx, gpio_alt5);
        self.write(gpio_base, gpio_fsel1, fsel1);
        self.write(gpio_base, gpio_pud, 0);
        self.mmio.delay(self.mmio.user, 150);
        self.write(gpio_base, gpio_pudclk0, (1 << pin_uart_tx) | (1 << pin_uart_rx));
        self.mmio.delay(self.mmio.user, 150);
        self.write(gpio_base, gpio_pudclk0, 0);

        self.write(aux_base, aux_enables, 1);
        self.write(aux_base, aux_mu_cntl, 0);
        self.write(aux_base, aux_mu_ier, 0);
        self.write(aux_base, aux_mu_iir, 0xc6);
        self.write(aux_base, aux_mu_lcr, 3);
        self.write(aux_base, aux_mu_mcr, 0);
        self.write(aux_base, aux_mu_baud, 270);
        self.write(aux_base, aux_mu_cntl, 3);
    }

    fn putByte(self: *Board, byte: u8) void {
        while ((self.read(aux_base, aux_mu_lsr) & 0x20) == 0) {}
        self.write(aux_base, aux_mu_io, byte);
    }

    fn actLedInit(self: *Board) void {
        var fsel4 = self.read(gpio_base, gpio_fsel4);
        fsel4 = gpioFselAlt(fsel4, pin_act_led, gpio_output);
        self.write(gpio_base, gpio_fsel4, fsel4);
    }

    fn actLedOn(self: *Board) void {
        self.write(gpio_base, gpio_clr1, 1 << (pin_act_led - 32));
    }

    fn actLedOff(self: *Board) void {
        self.write(gpio_base, gpio_set1, 1 << (pin_act_led - 32));
    }

    fn emmcInit(self: *Board) bool {
        const divisor = emmc_ident_clock_divisor;
        var control1: u32 = emmc_control1_clk_intlen | emmc_control1_clk_gensel | (0x0e << 16);
        control1 |= (divisor & 0xff) << 8;
        control1 |= (divisor & 0x300) >> 6;

        self.write(emmc_base, emmc_reg_control1, emmc_control1_srst_hc);
        if (!self.waitClear(emmc_reg_control1, emmc_control1_srst_hc, 100_000)) return false;
        self.write(emmc_base, emmc_reg_irpt_en, 0);
        self.write(emmc_base, emmc_reg_irpt_mask, 0);
        self.write(emmc_base, pi_mmc.emmc_reg_interrupt, pi_mmc.emmc_interrupt_all);
        self.write(emmc_base, emmc_reg_control1, control1);
        if (!self.waitSet(emmc_reg_control1, emmc_control1_clk_stable, 100_000)) return false;
        self.write(emmc_base, emmc_reg_control1, control1 | emmc_control1_clk_en);
        return true;
    }

    fn sdMemoryInit(self: *Board) bool {
        self.raw_log = .{};
        if (!self.emmcInit()) return self.fail(0x8000_0001);
        if (!self.command(pi_mmc.cmd_go_idle_state, 0, .none)) return self.fail(0x8000_0002);
        if (!self.command(pi_mmc.cmd_send_if_cond, sd_if_cond_3v3_check, .r7)) return self.fail(0x8000_0003);
        self.raw_log.stage = 1;
        var poll: u32 = 0;
        while (poll < sd_ocr_poll_budget) : (poll += 1) {
            if (!self.command(pi_mmc.cmd_app_cmd, 0, .r1)) return self.fail(0x8000_0004);
            if (!self.command(pi_mmc.acmd_sd_send_op_cond, sd_ocr_3v3_hcs, .r3)) return self.fail(0x8000_0005);
            if ((self.raw_log.response & sd_ocr_ready) != 0) break;
        }
        if ((self.raw_log.response & sd_ocr_ready) == 0) return self.fail(0x8000_0006);
        self.raw_log.stage = 2;
        if (!self.command(pi_mmc.cmd_all_send_cid, 0, .r2)) return self.fail(0x8000_0007);
        self.raw_log.stage = 3;
        if (!self.command(pi_mmc.cmd_send_relative_addr, 0, .r6)) return self.fail(0x8000_0008);
        self.raw_log.relative_card_address = pi_mmc.relativeCardFromR6(self.raw_log.response);
        if (self.raw_log.relative_card_address == 0) return self.fail(0x8000_0009);
        self.raw_log.stage = 4;
        if (!self.command(pi_mmc.cmd_select_card, pi_mmc.relativeCardArgument(self.raw_log.relative_card_address), .r1)) return self.fail(0x8000_000a);
        self.raw_log.stage = 5;
        return true;
    }

    fn command(self: *Board, index: u32, argument: u32, response_kind: pi_mmc.ResponseKind) bool {
        const command_value = pi_mmc.commandIoPrepare(.{ .command_index = index, .argument = argument, .response_kind = response_kind }) orelse return false;
        if (!self.waitClear(emmc_reg_status, emmc_status_cmd_inhibit | emmc_status_data_inhibit, 100_000)) return false;
        self.write(emmc_base, command_value.interrupt_offset, command_value.interrupt_clear_value);
        self.write(emmc_base, command_value.argument_offset, command_value.argument_value);
        self.write(emmc_base, command_value.command_offset, command_value.command_value);
        if (!self.waitInterrupt(pi_mmc.emmc_interrupt_cmd_done)) return false;
        if (response_kind != .none) self.raw_log.response = self.read(emmc_base, command_value.response_offset);
        self.write(emmc_base, command_value.interrupt_offset, self.raw_log.interrupt);
        return true;
    }

    fn writeBlock(self: *Board, block_address: u32, block: *const pi_zero.BootLogBlock) bool {
        const io = pi_mmc.blockIoPrepare(pi_mmc.cmd_write_block, block_address) orelse return false;
        if (!self.waitClear(emmc_reg_status, emmc_status_cmd_inhibit | emmc_status_data_inhibit, 100_000)) {
            self.raw_log.write_result = 0x8000_0010;
            return false;
        }
        self.write(emmc_base, io.command_io.interrupt_offset, io.command_io.interrupt_clear_value);
        self.write(emmc_base, io.block_size_count_offset, io.block_size_count_value);
        self.write(emmc_base, io.command_io.argument_offset, io.command_io.argument_value);
        self.write(emmc_base, io.command_io.command_offset, io.command_io.command_value);
        if (!self.waitInterrupt(pi_mmc.emmc_interrupt_write_ready)) {
            self.raw_log.write_result = 0x8000_0011;
            return false;
        }
        var word_index: usize = 0;
        while (word_index < pi_mmc.emmc_block_bytes / pi_mmc.emmc_word_bytes) : (word_index += 1) {
            const byte_index = word_index * pi_mmc.emmc_word_bytes;
            const word = @as(u32, block[byte_index]) |
                (@as(u32, block[byte_index + 1]) << 8) |
                (@as(u32, block[byte_index + 2]) << 16) |
                (@as(u32, block[byte_index + 3]) << 24);
            self.write(emmc_base, io.data_offset, word);
        }
        if (!self.waitInterrupt(pi_mmc.emmc_interrupt_data_done)) {
            self.raw_log.write_result = 0x8000_0012;
            return false;
        }
        self.raw_log.response = self.read(emmc_base, io.command_io.response_offset);
        self.write(emmc_base, io.command_io.interrupt_offset, self.raw_log.interrupt);
        self.raw_log.write_result = 1;
        return true;
    }

    fn waitInterrupt(self: *Board, wanted: u32) bool {
        var poll: u32 = 0;
        while (poll < sd_poll_budget) : (poll += 1) {
            const interrupt = self.read(emmc_base, pi_mmc.emmc_reg_interrupt);
            if ((interrupt & pi_mmc.emmc_interrupt_error_mask) != 0) {
                self.raw_log.interrupt = interrupt;
                return false;
            }
            if ((interrupt & wanted) != 0) {
                self.raw_log.interrupt = interrupt;
                return true;
            }
        }
        return false;
    }

    fn waitClear(self: *Board, offset: u32, mask: u32, poll_budget: u32) bool {
        var poll: u32 = 0;
        while (poll < poll_budget) : (poll += 1) {
            if ((self.read(emmc_base, offset) & mask) == 0) return true;
        }
        return false;
    }

    fn waitSet(self: *Board, offset: u32, mask: u32, poll_budget: u32) bool {
        var poll: u32 = 0;
        while (poll < poll_budget) : (poll += 1) {
            if ((self.read(emmc_base, offset) & mask) == mask) return true;
        }
        return false;
    }

    fn fail(self: *Board, stage: u32) bool {
        self.raw_log.stage = stage;
        return false;
    }

    fn read(self: *Board, base: u32, offset: u32) u32 {
        return self.mmio.read32(self.mmio.user, base, offset);
    }

    fn write(self: *Board, base: u32, offset: u32, value: u32) void {
        self.mmio.write32(self.mmio.user, base, offset, value);
    }
};

pub fn rawLogBlock(state: RawLogState, event: u32) pi_zero.BootLogBlock {
    var block = [_]u8{0} ** pi_zero.boot_log_block_bytes;
    putLe32(block[0..4], 0x4744_5245);
    putLe32(block[4..8], 1);
    putLe32(block[8..12], pi_zero.boot_image_id);
    putLe32(block[12..16], 4);
    putLe32(block[16..20], event);
    putLe32(block[20..24], state.stage);
    putLe32(block[24..28], state.interrupt);
    putLe32(block[28..32], state.response);
    putLe32(block[32..36], state.relative_card_address);
    putLe32(block[36..40], state.write_result);
    @memcpy(block[64..81], "ER ZIG PI SD DIAG");
    return block;
}

pub fn gpioFselAlt(current: u32, pin: u32, alt_function: u32) u32 {
    const shift: u5 = @intCast((pin % 10) * 3);
    const mask = @as(u32, 7) << shift;
    return (current & ~mask) | ((alt_function & 7) << shift);
}

fn putLe32(out: []u8, value: u32) void {
    _ = bytes.store32(out, value);
}

test "builds raw Pi Zero W v1.1 SD log blocks" {
    const block = rawLogBlock(.{ .stage = 5, .interrupt = 1, .response = 2, .relative_card_address = 0x1234, .write_result = 1 }, 0x10);
    try @import("std").testing.expectEqual(@as(u32, 0x45), block[0]);
    try @import("std").testing.expectEqual(@as(u8, 'E'), block[64]);
    try @import("std").testing.expectEqual(@as(u8, 'G'), block[69]);
}
