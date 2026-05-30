const std = @import("std");

pub const clock_id_emmc: u32 = 1;
pub const clock_id_uart: u32 = 2;

pub const cmd_go_idle_state: u32 = 0;
pub const cmd_all_send_cid: u32 = 2;
pub const cmd_send_relative_addr: u32 = 3;
pub const cmd_io_send_op_cond: u32 = 5;
pub const cmd_select_card: u32 = 7;
pub const cmd_send_if_cond: u32 = 8;
pub const cmd_read_single_block: u32 = 17;
pub const cmd_write_block: u32 = 24;
pub const acmd_sd_send_op_cond: u32 = 41;
pub const cmd_io_rw_direct: u32 = 52;
pub const cmd_io_rw_extended: u32 = 53;
pub const cmd_app_cmd: u32 = 55;

pub const ResponseKind = enum(u32) {
    none = 0,
    r1 = 1,
    r2 = 2,
    r3 = 3,
    r4 = 4,
    r5 = 5,
    r6 = 6,
    r7 = 7,
};

pub const sdio_function_cccr: u8 = 0;
pub const sdio_function_backplane: u8 = 1;
pub const sdio_function_wlan: u8 = 2;

pub const sdio_read: bool = false;
pub const sdio_write: bool = true;
pub const sdio_no_raw: bool = false;
pub const sdio_raw: bool = true;
pub const sdio_fixed_address: bool = false;
pub const sdio_incrementing_address: bool = true;
pub const sdio_byte_mode: bool = false;
pub const sdio_block_mode: bool = true;

pub const emmc_block_bytes: u32 = 512;
pub const emmc_reg_blksizecnt: u32 = 0x04;
pub const emmc_reg_arg1: u32 = 0x08;
pub const emmc_reg_cmdtm: u32 = 0x0c;
pub const emmc_reg_resp0: u32 = 0x10;
pub const emmc_reg_resp1: u32 = 0x14;
pub const emmc_reg_resp2: u32 = 0x18;
pub const emmc_reg_resp3: u32 = 0x1c;
pub const emmc_reg_data: u32 = 0x20;
pub const emmc_reg_interrupt: u32 = 0x30;
pub const emmc_word_bytes: u32 = 4;

pub const emmc_interrupt_cmd_done: u32 = 0x0000_0001;
pub const emmc_interrupt_data_done: u32 = 0x0000_0002;
pub const emmc_interrupt_write_ready: u32 = 0x0000_0010;
pub const emmc_interrupt_read_ready: u32 = 0x0000_0020;
pub const emmc_interrupt_all: u32 = 0xffff_ffff;
pub const emmc_interrupt_error_mask: u32 = 0xffff_0000;

const sdio_function_bits = 28;
const sdio_raw_or_block_mode_bit = 27;
const sdio_incrementing_address_bit = 26;
const sdio_address_bits = 9;
const sdio_rw_flag_bit = 31;
const sdio_function_mask = 0x07;
const sdio_address_mask = 0x0001_ffff;
const sdio_cmd53_count_mask = 0x01ff;
const mmc_rca_mask = 0x0000_ffff;
const mmc_rca_argument_bits = 16;
const emmc_cmdtm_response_bits = 16;
const emmc_cmdtm_response_none = 0;
const emmc_cmdtm_response_136 = 1;
const emmc_cmdtm_response_48 = 2;
const emmc_cmdtm_block_count_enable: u32 = 1 << 1;
const emmc_cmdtm_data_read: u32 = 1 << 4;
const emmc_cmdtm_crc_check: u32 = 1 << 19;
const emmc_cmdtm_index_check: u32 = 1 << 20;
const emmc_cmdtm_is_data: u32 = 1 << 21;
const emmc_cmdtm_index_bits = 24;

pub const Command = struct {
    command_index: u32,
    argument: u32,
    response_kind: ResponseKind,
};

pub const CommandIo = struct {
    interrupt_offset: u32,
    interrupt_clear_value: u32,
    argument_offset: u32,
    argument_value: u32,
    command_offset: u32,
    command_value: u32,
    response_offset: u32,
    response_kind: ResponseKind,
};

pub const CommandResult = struct {
    io: CommandIo = empty_command_io,
    interrupt_value: u32 = 0,
    response0: u32 = 0,
    response1: u32 = 0,
    response2: u32 = 0,
    response3: u32 = 0,
    completed: bool = false,
    has_error: bool = false,
};

pub const BlockIo = struct {
    block_size_count_offset: u32,
    block_size_count_value: u32,
    data_offset: u32,
    command_io: CommandIo,
    read: bool,
};

pub const BlockResult = struct {
    io: BlockIo = empty_block_io,
    interrupt_value: u32 = 0,
    response0: u32 = 0,
    completed: bool = false,
    has_error: bool = false,
};

pub const SdioTransferIo = struct {
    block_size_count_offset: u32,
    block_size_count_value: u32,
    data_offset: u32,
    data_len: u32,
    command_io: CommandIo,
    read: bool,
};

pub const SdioTransferResult = struct {
    io: SdioTransferIo = empty_sdio_transfer_io,
    interrupt_value: u32 = 0,
    response0: u32 = 0,
    completed: bool = false,
    has_error: bool = false,
};

pub const Read32Fn = *const fn (user: ?*anyopaque, offset: u32, out_value: *u32) bool;
pub const Write32Fn = *const fn (user: ?*anyopaque, offset: u32, value: u32) bool;
pub const Read8Fn = *const fn (user: ?*anyopaque, offset: u32, out_value: *u8) bool;
pub const Write8Fn = *const fn (user: ?*anyopaque, offset: u32, value: u8) bool;

pub const MmioOps = struct {
    user: ?*anyopaque = null,
    read32: Read32Fn,
    write32: Write32Fn,
    read8: ?Read8Fn = null,
    write8: ?Write8Fn = null,
};

const empty_command_io = CommandIo{
    .interrupt_offset = 0,
    .interrupt_clear_value = 0,
    .argument_offset = 0,
    .argument_value = 0,
    .command_offset = 0,
    .command_value = 0,
    .response_offset = 0,
    .response_kind = .none,
};

const empty_block_io = BlockIo{
    .block_size_count_offset = 0,
    .block_size_count_value = 0,
    .data_offset = 0,
    .command_io = empty_command_io,
    .read = false,
};

const empty_sdio_transfer_io = SdioTransferIo{
    .block_size_count_offset = 0,
    .block_size_count_value = 0,
    .data_offset = 0,
    .data_len = 0,
    .command_io = empty_command_io,
    .read = false,
};

pub fn sdioCmd52Argument(write: bool, function: u8, raw: bool, address: u32, data: u8) u32 {
    var argument: u32 = 0;
    if (write) argument |= 1 << sdio_rw_flag_bit;
    argument |= (@as(u32, function) & sdio_function_mask) << sdio_function_bits;
    if (raw) argument |= 1 << sdio_raw_or_block_mode_bit;
    argument |= (address & sdio_address_mask) << sdio_address_bits;
    argument |= data;
    return argument;
}

pub fn sdioCmd53Argument(write: bool, function: u8, block_mode: bool, incrementing_address: bool, address: u32, count: u32) u32 {
    var argument: u32 = 0;
    if (write) argument |= 1 << sdio_rw_flag_bit;
    argument |= (@as(u32, function) & sdio_function_mask) << sdio_function_bits;
    if (block_mode) argument |= 1 << sdio_raw_or_block_mode_bit;
    if (incrementing_address) argument |= 1 << sdio_incrementing_address_bit;
    argument |= (address & sdio_address_mask) << sdio_address_bits;
    argument |= count & sdio_cmd53_count_mask;
    return argument;
}

pub fn relativeCardArgument(relative_card_address: u32) u32 {
    return (relative_card_address & mmc_rca_mask) << mmc_rca_argument_bits;
}

pub fn relativeCardFromR6(response: u32) u32 {
    return (response >> mmc_rca_argument_bits) & mmc_rca_mask;
}

pub fn commandPrepare(command_index: u32, argument: u32, response_kind: ResponseKind) ?Command {
    const ok = switch (command_index) {
        cmd_go_idle_state => response_kind == .none,
        cmd_all_send_cid => response_kind == .r2,
        cmd_io_send_op_cond => response_kind == .r4,
        cmd_send_relative_addr => response_kind == .r6,
        cmd_select_card => response_kind == .r1,
        cmd_send_if_cond => response_kind == .r7,
        cmd_read_single_block, cmd_write_block => response_kind == .r1,
        acmd_sd_send_op_cond => response_kind == .r3,
        cmd_io_rw_direct, cmd_io_rw_extended => response_kind == .r5,
        cmd_app_cmd => response_kind == .r1,
        else => false,
    };
    if (!ok) return null;
    return .{ .command_index = command_index, .argument = argument, .response_kind = response_kind };
}

pub fn commandIoPrepare(command: Command) ?CommandIo {
    const prepared = commandPrepare(command.command_index, command.argument, command.response_kind) orelse return null;
    return .{
        .interrupt_offset = emmc_reg_interrupt,
        .interrupt_clear_value = emmc_interrupt_all,
        .argument_offset = emmc_reg_arg1,
        .argument_value = prepared.argument,
        .command_offset = emmc_reg_cmdtm,
        .command_value = if (commandIsBlockData(prepared.command_index)) emmcBlockCommandValue(prepared) else emmcCommandValue(prepared),
        .response_offset = emmc_reg_resp0,
        .response_kind = prepared.response_kind,
    };
}

pub fn blockIoPrepare(command_index: u32, block_address: u32) ?BlockIo {
    if (command_index != cmd_read_single_block and command_index != cmd_write_block) return null;
    const command = commandPrepare(command_index, block_address, .r1) orelse return null;
    return .{
        .block_size_count_offset = emmc_reg_blksizecnt,
        .block_size_count_value = blockSizeCountValue(),
        .data_offset = emmc_reg_data,
        .command_io = commandIoPrepare(command).?,
        .read = command_index == cmd_read_single_block,
    };
}

pub fn sdioTransferIoPrepare(write: bool, function: u8, block_mode: bool, incrementing_address: bool, address: u32, block_size: u32, transfer_count: u32, data_len: u32) ?SdioTransferIo {
    if (function == sdio_function_cccr or block_size == 0 or transfer_count == 0 or data_len == 0) return null;
    if (transfer_count > sdio_cmd53_count_mask or address > sdio_address_mask) return null;
    if (!block_mode and (data_len > emmc_block_bytes or block_size != data_len or data_len != transfer_count)) return null;
    if (block_mode and data_len != block_size * transfer_count) return null;
    const command = Command{
        .command_index = cmd_io_rw_extended,
        .argument = sdioCmd53Argument(write, function, block_mode, incrementing_address, address, transfer_count),
        .response_kind = .r5,
    };
    var command_io = commandIoPrepare(command).?;
    command_io.command_value |= emmc_cmdtm_block_count_enable | emmc_cmdtm_is_data;
    if (!write) command_io.command_value |= emmc_cmdtm_data_read;
    return .{
        .block_size_count_offset = emmc_reg_blksizecnt,
        .block_size_count_value = if (block_mode) (transfer_count << 16) | block_size else (1 << 16) | data_len,
        .data_offset = emmc_reg_data,
        .data_len = data_len,
        .command_io = command_io,
        .read = !write,
    };
}

pub fn commandBeginWithOps(ops: *const MmioOps, command: Command) ?CommandIo {
    if (commandRequiresDataPath(command.command_index)) return null;
    const io = commandIoPrepare(command) orelse return null;
    if (!ops.write32(ops.user, io.interrupt_offset, io.interrupt_clear_value) or
        !ops.write32(ops.user, io.argument_offset, io.argument_value) or
        !ops.write32(ops.user, io.command_offset, io.command_value)) return null;
    return io;
}

pub fn commandPollWithOps(ops: *const MmioOps, io: CommandIo, poll_budget: u32) CommandResult {
    var result = CommandResult{};
    if (poll_budget == 0) return result;
    var poll: u32 = 0;
    while (poll < poll_budget) : (poll += 1) {
        var interrupt: u32 = 0;
        if (!ops.read32(ops.user, io.interrupt_offset, &interrupt)) {
            result.has_error = true;
            return result;
        }
        result.interrupt_value = interrupt;
        if (interruptIsError(interrupt) or interruptIsCommandDone(interrupt)) {
            return commandFinishWithOps(ops, io, interrupt);
        }
    }
    return result;
}

pub fn commandExecuteWithOps(ops: *const MmioOps, command: Command, poll_budget: u32) CommandResult {
    const io = commandBeginWithOps(ops, command) orelse return .{ .has_error = true };
    return commandPollWithOps(ops, io, poll_budget);
}

pub fn readBlockWithOps(ops: *const MmioOps, block_address: u32, out_block: *[emmc_block_bytes]u8, poll_budget: u32) BlockResult {
    const io = blockIoPrepare(cmd_read_single_block, block_address) orelse return .{ .has_error = true };
    var result = beginBlockWithOps(ops, io, emmc_interrupt_read_ready, poll_budget) orelse return .{ .has_error = true };
    var word_index: usize = 0;
    while (word_index < emmc_block_bytes / emmc_word_bytes) : (word_index += 1) {
        var data_word: u32 = 0;
        if (!ops.read32(ops.user, io.data_offset, &data_word)) {
            result.has_error = true;
            result.completed = false;
            return result;
        }
        const byte_index = word_index * emmc_word_bytes;
        out_block[byte_index] = @intCast(data_word & 0xff);
        out_block[byte_index + 1] = @intCast((data_word >> 8) & 0xff);
        out_block[byte_index + 2] = @intCast((data_word >> 16) & 0xff);
        out_block[byte_index + 3] = @intCast((data_word >> 24) & 0xff);
    }
    return waitDataDoneWithOps(ops, result, poll_budget);
}

pub fn writeBlockWithOps(ops: *const MmioOps, block_address: u32, block: *const [emmc_block_bytes]u8, poll_budget: u32) BlockResult {
    const io = blockIoPrepare(cmd_write_block, block_address) orelse return .{ .has_error = true };
    var result = beginBlockWithOps(ops, io, emmc_interrupt_write_ready, poll_budget) orelse return .{ .has_error = true };
    var word_index: usize = 0;
    while (word_index < emmc_block_bytes / emmc_word_bytes) : (word_index += 1) {
        const byte_index = word_index * emmc_word_bytes;
        const word_value = @as(u32, block[byte_index]) |
            (@as(u32, block[byte_index + 1]) << 8) |
            (@as(u32, block[byte_index + 2]) << 16) |
            (@as(u32, block[byte_index + 3]) << 24);
        if (!ops.write32(ops.user, io.data_offset, word_value)) {
            result.has_error = true;
            result.completed = false;
            return result;
        }
    }
    return waitDataDoneWithOps(ops, result, poll_budget);
}

pub fn sdioReadBytesWithOps(ops: *const MmioOps, function: u8, incrementing_address: bool, address: u32, out_bytes: []u8, poll_budget: u32) SdioTransferResult {
    return sdioTransferBytesWithOps(ops, false, function, incrementing_address, address, null, out_bytes, poll_budget);
}

pub fn sdioWriteBytesWithOps(ops: *const MmioOps, function: u8, incrementing_address: bool, address: u32, in_bytes: []const u8, poll_budget: u32) SdioTransferResult {
    return sdioTransferBytesWithOps(ops, true, function, incrementing_address, address, in_bytes, null, poll_budget);
}

fn emmcCommandValue(command: Command) u32 {
    var value = command.command_index << emmc_cmdtm_index_bits;
    value |= responseBits(command.response_kind) << emmc_cmdtm_response_bits;
    if (responseRequiresCrc(command.response_kind)) value |= emmc_cmdtm_crc_check;
    if (responseRequiresIndex(command.response_kind)) value |= emmc_cmdtm_index_check;
    return value;
}

fn emmcBlockCommandValue(command: Command) u32 {
    var value = emmcCommandValue(command);
    value |= emmc_cmdtm_block_count_enable | emmc_cmdtm_is_data;
    if (command.command_index == cmd_read_single_block) value |= emmc_cmdtm_data_read;
    return value;
}

fn responseBits(response_kind: ResponseKind) u32 {
    return switch (response_kind) {
        .none => emmc_cmdtm_response_none,
        .r2 => emmc_cmdtm_response_136,
        .r1, .r3, .r4, .r5, .r6, .r7 => emmc_cmdtm_response_48,
    };
}

fn responseRequiresCrc(response_kind: ResponseKind) bool {
    return switch (response_kind) {
        .r1, .r2, .r5, .r6, .r7 => true,
        .none, .r3, .r4 => false,
    };
}

fn responseRequiresIndex(response_kind: ResponseKind) bool {
    return switch (response_kind) {
        .r1, .r5, .r6, .r7 => true,
        .none, .r2, .r3, .r4 => false,
    };
}

fn commandIsBlockData(command_index: u32) bool {
    return command_index == cmd_read_single_block or command_index == cmd_write_block;
}

fn commandRequiresDataPath(command_index: u32) bool {
    return commandIsBlockData(command_index) or command_index == cmd_io_rw_extended;
}

fn blockSizeCountValue() u32 {
    return (1 << 16) | emmc_block_bytes;
}

fn interruptIsError(interrupt_value: u32) bool {
    return (interrupt_value & emmc_interrupt_error_mask) != 0;
}

fn interruptIsCommandDone(interrupt_value: u32) bool {
    return (interrupt_value & emmc_interrupt_cmd_done) != 0;
}

fn commandFinishWithOps(ops: *const MmioOps, io: CommandIo, interrupt_value: u32) CommandResult {
    var result = CommandResult{
        .io = io,
        .interrupt_value = interrupt_value,
        .has_error = interruptIsError(interrupt_value),
        .completed = !interruptIsError(interrupt_value) and interruptIsCommandDone(interrupt_value),
    };
    if (io.response_kind != .none) {
        if (!ops.read32(ops.user, io.response_offset, &result.response0)) {
            result.has_error = true;
            result.completed = false;
            return result;
        }
        if (io.response_kind == .r2) {
            if (!ops.read32(ops.user, emmc_reg_resp1, &result.response1) or
                !ops.read32(ops.user, emmc_reg_resp2, &result.response2) or
                !ops.read32(ops.user, emmc_reg_resp3, &result.response3))
            {
                result.has_error = true;
                result.completed = false;
                return result;
            }
        }
    }
    if (!ops.write32(ops.user, io.interrupt_offset, interrupt_value)) {
        result.has_error = true;
        result.completed = false;
    }
    return result;
}

fn pollInterruptWithOps(ops: *const MmioOps, needed_interrupt: u32, poll_budget: u32, out_interrupt: *u32) bool {
    if (needed_interrupt == 0 or poll_budget == 0) return false;
    out_interrupt.* = 0;
    var poll: u32 = 0;
    while (poll < poll_budget) : (poll += 1) {
        var interrupt: u32 = 0;
        if (!ops.read32(ops.user, emmc_reg_interrupt, &interrupt)) return false;
        out_interrupt.* = interrupt;
        if (interruptIsError(interrupt)) return false;
        if ((interrupt & needed_interrupt) != 0) return true;
    }
    return false;
}

fn blockBeginWithOps(ops: *const MmioOps, io: BlockIo) bool {
    return ops.write32(ops.user, io.command_io.interrupt_offset, io.command_io.interrupt_clear_value) and
        ops.write32(ops.user, io.block_size_count_offset, io.block_size_count_value) and
        ops.write32(ops.user, io.command_io.argument_offset, io.command_io.argument_value) and
        ops.write32(ops.user, io.command_io.command_offset, io.command_io.command_value);
}

fn beginBlockWithOps(ops: *const MmioOps, io: BlockIo, ready_interrupt: u32, poll_budget: u32) ?BlockResult {
    if (!blockBeginWithOps(ops, io)) return null;
    var interrupt: u32 = 0;
    if (!pollInterruptWithOps(ops, ready_interrupt, poll_budget, &interrupt)) return null;
    return .{ .io = io, .interrupt_value = interrupt };
}

fn waitDataDoneWithOps(ops: *const MmioOps, result: BlockResult, poll_budget: u32) BlockResult {
    var out = result;
    var interrupt: u32 = 0;
    if (!pollInterruptWithOps(ops, emmc_interrupt_data_done, poll_budget, &interrupt)) {
        out.has_error = true;
        out.completed = false;
        return out;
    }
    out.interrupt_value = interrupt;
    if (!ops.read32(ops.user, out.io.command_io.response_offset, &out.response0) or
        !ops.write32(ops.user, out.io.command_io.interrupt_offset, interrupt))
    {
        out.has_error = true;
        out.completed = false;
        return out;
    }
    out.completed = true;
    return out;
}

fn sdioTransferBytesWithOps(
    ops: *const MmioOps,
    write: bool,
    function: u8,
    incrementing_address: bool,
    address: u32,
    write_bytes: ?[]const u8,
    read_bytes: ?[]u8,
    poll_budget: u32,
) SdioTransferResult {
    const bytes_len = if (write) (write_bytes orelse return .{ .has_error = true }).len else (read_bytes orelse return .{ .has_error = true }).len;
    if (bytes_len == 0 or bytes_len > emmc_block_bytes) return .{ .has_error = true };
    if (write and ops.write8 == null) return .{ .has_error = true };
    if (!write and ops.read8 == null) return .{ .has_error = true };

    const len32: u32 = @intCast(bytes_len);
    const io = sdioTransferIoPrepare(write, function, sdio_byte_mode, incrementing_address, address, len32, len32, len32) orelse return .{ .has_error = true };
    if (!sdioTransferBeginWithOps(ops, io)) return .{ .has_error = true };

    var interrupt: u32 = 0;
    const ready_interrupt = if (write) emmc_interrupt_write_ready else emmc_interrupt_read_ready;
    if (!pollInterruptWithOps(ops, ready_interrupt, poll_budget, &interrupt)) return .{ .io = io, .has_error = true };

    var result = SdioTransferResult{ .io = io, .interrupt_value = interrupt };
    var index: usize = 0;
    while (index < bytes_len) : (index += 1) {
        if (write) {
            if (!ops.write8.?(ops.user, io.data_offset, write_bytes.?[index])) {
                result.has_error = true;
                return result;
            }
        } else {
            if (!ops.read8.?(ops.user, io.data_offset, &read_bytes.?[index])) {
                result.has_error = true;
                return result;
            }
        }
    }
    return sdioTransferDoneWithOps(ops, result, poll_budget);
}

fn sdioTransferBeginWithOps(ops: *const MmioOps, io: SdioTransferIo) bool {
    return ops.write32(ops.user, io.command_io.interrupt_offset, io.command_io.interrupt_clear_value) and
        ops.write32(ops.user, io.block_size_count_offset, io.block_size_count_value) and
        ops.write32(ops.user, io.command_io.argument_offset, io.command_io.argument_value) and
        ops.write32(ops.user, io.command_io.command_offset, io.command_io.command_value);
}

fn sdioTransferDoneWithOps(ops: *const MmioOps, result: SdioTransferResult, poll_budget: u32) SdioTransferResult {
    var out = result;
    var interrupt: u32 = 0;
    if (!pollInterruptWithOps(ops, emmc_interrupt_data_done, poll_budget, &interrupt)) {
        out.has_error = true;
        out.completed = false;
        return out;
    }
    out.interrupt_value = interrupt;
    if (!ops.read32(ops.user, out.io.command_io.response_offset, &out.response0) or
        !ops.write32(ops.user, out.io.command_io.interrupt_offset, interrupt))
    {
        out.has_error = true;
        out.completed = false;
        return out;
    }
    out.completed = true;
    return out;
}

test "packs Pi SDIO arguments and RCA helpers" {
    try std.testing.expectEqual(@as(u32, 0x9000_aa55), sdioCmd52Argument(true, sdio_function_backplane, false, 0x55, 0x55));
    try std.testing.expectEqual(@as(u32, 0xa400_6008), sdioCmd53Argument(true, sdio_function_wlan, false, true, 0x30, 8));
    try std.testing.expectEqual(@as(u32, 0x1234_0000), relativeCardArgument(0x1234));
    try std.testing.expectEqual(@as(u32, 0x1234), relativeCardFromR6(0x1234_abcd));
}

test "prepares Pi EMMC command and transfer register plans" {
    const cmd0 = commandPrepare(cmd_go_idle_state, 0, .none).?;
    const cmd0_io = commandIoPrepare(cmd0).?;
    try std.testing.expectEqual(emmc_reg_interrupt, cmd0_io.interrupt_offset);
    try std.testing.expectEqual(emmc_reg_arg1, cmd0_io.argument_offset);
    try std.testing.expectEqual(emmc_reg_cmdtm, cmd0_io.command_offset);
    try std.testing.expectEqual(@as(u32, 0), cmd0_io.command_value);

    const cmd5 = commandPrepare(cmd_io_send_op_cond, 0x00ff_8000, .r4).?;
    const cmd5_io = commandIoPrepare(cmd5).?;
    try std.testing.expectEqual(@as(u32, (5 << 24) | (2 << 16)), cmd5_io.command_value);
    try std.testing.expect(commandPrepare(cmd_io_send_op_cond, 0, .r1) == null);

    const read = blockIoPrepare(cmd_read_single_block, 42).?;
    try std.testing.expect(read.read);
    try std.testing.expectEqual(blockSizeCountValue(), read.block_size_count_value);
    try std.testing.expectEqual(@as(u32, (17 << 24) | (2 << 16) | emmc_cmdtm_crc_check | emmc_cmdtm_index_check | emmc_cmdtm_block_count_enable | emmc_cmdtm_is_data | emmc_cmdtm_data_read), read.command_io.command_value);

    const transfer = sdioTransferIoPrepare(false, sdio_function_wlan, false, true, 0x30, 8, 8, 8).?;
    try std.testing.expect(transfer.read);
    try std.testing.expectEqual(@as(u32, (1 << 16) | 8), transfer.block_size_count_value);
    try std.testing.expectEqual(sdioCmd53Argument(false, sdio_function_wlan, false, true, 0x30, 8), transfer.command_io.argument_value);
    try std.testing.expectEqual(@as(u32, (53 << 24) | (2 << 16) | emmc_cmdtm_crc_check | emmc_cmdtm_index_check | emmc_cmdtm_block_count_enable | emmc_cmdtm_is_data | emmc_cmdtm_data_read), transfer.command_io.command_value);
    try std.testing.expect(sdioTransferIoPrepare(false, sdio_function_cccr, false, true, 0x30, 8, 8, 8) == null);
    try std.testing.expect(sdioTransferIoPrepare(false, sdio_function_wlan, false, true, 0x30, 7, 8, 8) == null);
}

const TestOpsCtx = struct {
    interrupt_read_count: u32 = 0,
    ready_interrupt: u32 = emmc_interrupt_write_ready,
    data_read_count: u32 = 0,
    data_write_count: u32 = 0,
    first_data_read_word: u32 = 0,
    last_data_read_word: u32 = 0,
    first_data_word: u32 = 0,
    last_data_word: u32 = 0,
    byte_read_count: u32 = 0,
    byte_write_count: u32 = 0,
    first_byte: u8 = 0,
    last_byte: u8 = 0,
};

fn testRead32(user: ?*anyopaque, offset: u32, out_value: *u32) bool {
    const ctx: *TestOpsCtx = @ptrCast(@alignCast(user.?));
    switch (offset) {
        emmc_reg_interrupt => {
            ctx.interrupt_read_count += 1;
            out_value.* = if (ctx.interrupt_read_count == 1) ctx.ready_interrupt else emmc_interrupt_data_done;
            return true;
        },
        emmc_reg_resp0 => {
            out_value.* = 0x1a2b_3c4d;
            return true;
        },
        emmc_reg_data => {
            out_value.* = ctx.first_data_read_word + ctx.data_read_count;
            ctx.last_data_read_word = out_value.*;
            ctx.data_read_count += 1;
            return true;
        },
        else => {
            out_value.* = 0;
            return true;
        },
    }
}

fn testWrite32(user: ?*anyopaque, offset: u32, value: u32) bool {
    const ctx: *TestOpsCtx = @ptrCast(@alignCast(user.?));
    switch (offset) {
        emmc_reg_data => {
            if (ctx.data_write_count == 0) ctx.first_data_word = value;
            ctx.last_data_word = value;
            ctx.data_write_count += 1;
            return true;
        },
        emmc_reg_interrupt, emmc_reg_blksizecnt, emmc_reg_arg1, emmc_reg_cmdtm => return true,
        else => return false,
    }
}

fn testRead8(user: ?*anyopaque, offset: u32, out_value: *u8) bool {
    if (offset != emmc_reg_data) return false;
    const ctx: *TestOpsCtx = @ptrCast(@alignCast(user.?));
    out_value.* = @intCast(0xa0 + ctx.byte_read_count);
    if (ctx.byte_read_count == 0) ctx.first_byte = out_value.*;
    ctx.last_byte = out_value.*;
    ctx.byte_read_count += 1;
    return true;
}

fn testWrite8(user: ?*anyopaque, offset: u32, value: u8) bool {
    if (offset != emmc_reg_data) return false;
    const ctx: *TestOpsCtx = @ptrCast(@alignCast(user.?));
    if (ctx.byte_write_count == 0) ctx.first_byte = value;
    ctx.last_byte = value;
    ctx.byte_write_count += 1;
    return true;
}

test "executes Pi EMMC block IO with injected MMIO ops" {
    var block: [emmc_block_bytes]u8 = undefined;
    for (&block, 0..) |*byte, i| byte.* = @intCast(i & 0xff);

    var ctx = TestOpsCtx{ .ready_interrupt = emmc_interrupt_write_ready };
    const ops = MmioOps{ .user = &ctx, .read32 = testRead32, .write32 = testWrite32 };
    const write = writeBlockWithOps(&ops, 7, &block, 2);
    try std.testing.expect(write.completed);
    try std.testing.expect(!write.has_error);
    try std.testing.expectEqual(@as(u32, emmc_block_bytes / emmc_word_bytes), ctx.data_write_count);
    try std.testing.expectEqual(@as(u32, 0x0302_0100), ctx.first_data_word);
    try std.testing.expectEqual(@as(u32, 0xfffe_fdfc), ctx.last_data_word);

    ctx = .{ .ready_interrupt = emmc_interrupt_read_ready, .first_data_read_word = 0x1112_1314 };
    const read = readBlockWithOps(&ops, 7, &block, 2);
    try std.testing.expect(read.completed);
    try std.testing.expect(!read.has_error);
    try std.testing.expectEqual(@as(u8, 0x14), block[0]);
    try std.testing.expectEqual(@as(u8, 0x11), block[3]);
    try std.testing.expectEqual(@as(u32, 0x1112_1393), ctx.last_data_read_word);
}

test "executes Pi EMMC SDIO byte transfers with injected MMIO ops" {
    var ctx = TestOpsCtx{ .ready_interrupt = emmc_interrupt_write_ready };
    const ops = MmioOps{ .user = &ctx, .read32 = testRead32, .write32 = testWrite32, .read8 = testRead8, .write8 = testWrite8 };
    const out = [_]u8{ 0x11, 0x22, 0x33, 0x44 };
    const write = sdioWriteBytesWithOps(&ops, sdio_function_wlan, sdio_incrementing_address, 0x40, &out, 2);
    try std.testing.expect(write.completed);
    try std.testing.expect(!write.has_error);
    try std.testing.expectEqual(@as(u32, 4), ctx.byte_write_count);
    try std.testing.expectEqual(@as(u8, 0x11), ctx.first_byte);
    try std.testing.expectEqual(@as(u8, 0x44), ctx.last_byte);

    ctx = .{ .ready_interrupt = emmc_interrupt_read_ready };
    var input: [4]u8 = undefined;
    const read = sdioReadBytesWithOps(&ops, sdio_function_wlan, sdio_incrementing_address, 0x40, &input, 2);
    try std.testing.expect(read.completed);
    try std.testing.expect(!read.has_error);
    try std.testing.expectEqual(@as(u32, 4), ctx.byte_read_count);
    try std.testing.expectEqual(@as(u8, 0xa0), input[0]);
    try std.testing.expectEqual(@as(u8, 0xa3), input[3]);

    const no_byte_ops = MmioOps{ .user = &ctx, .read32 = testRead32, .write32 = testWrite32 };
    const rejected = sdioReadBytesWithOps(&no_byte_ops, sdio_function_wlan, sdio_incrementing_address, 0x40, &input, 2);
    try std.testing.expect(rejected.has_error);
}
