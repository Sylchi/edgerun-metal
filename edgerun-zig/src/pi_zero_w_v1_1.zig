const std = @import("std");
const pi_mmc = @import("pi_mmc.zig");

pub const boot_log_block_bytes = 512;
pub const boot_checkpoint_block: u32 = 131072;
pub const boot_log_start_block: u32 = 131073;
pub const boot_log_block_count: u32 = 127;
pub const boot_log_pending_count = 32;
pub const boot_image_id: u32 = 0x20260522;
pub const boot_image_revision: u32 = 2;

const boot_log_magic: u32 = 0x4c425245;
const boot_log_version: u32 = 1;

pub const BootLogEventKind = enum(u32) {
    boot_entry = 1,
    uart_ready = 2,
    lcd_init = 3,
    identity_ready = 4,
    identity_failed = 5,
    ota_listen = 6,
    storage_ready = 7,
    storage_failed = 8,
    wifi_powered = 9,
    sdio_probed = 10,
    l2_ready = 11,
    l2_failed = 12,
    node_available_sent = 13,
    uart_ota_frame = 14,
    l2_ota_frame = 15,
    ota_block_written = 16,
    reboot_ready = 17,
};

pub const BootLogEvent = struct {
    event: BootLogEventKind,
    arg0: u32 = 0,
    arg1: u32 = 0,
    arg2: u32 = 0,
    arg3: u32 = 0,
};

pub const BootLogBlock = [boot_log_block_bytes]u8;

pub const BootLogWriteFn = *const fn (user: ?*anyopaque, block_address: u32, block: *const BootLogBlock) bool;

pub const BootLog = struct {
    boot_id: u32,
    next_sequence: u32 = 0,
    pending_count: usize = 0,
    dropped_count: u32 = 0,
    storage_enabled: bool = false,
    write_block: ?BootLogWriteFn = null,
    write_user: ?*anyopaque = null,
    pending: [boot_log_pending_count]BootLogEvent = [_]BootLogEvent{.{ .event = .boot_entry }} ** boot_log_pending_count,

    pub fn init(boot_id: u32) BootLog {
        return .{ .boot_id = boot_id };
    }

    pub fn enableStorage(self: *BootLog, write_block: BootLogWriteFn, write_user: ?*anyopaque) bool {
        self.storage_enabled = true;
        self.write_block = write_block;
        self.write_user = write_user;

        var index: usize = 0;
        while (index < self.pending_count) : (index += 1) {
            if (!self.writeEvent(self.pending[index])) return false;
        }
        self.pending_count = 0;
        return true;
    }

    pub fn append(self: *BootLog, event: BootLogEventKind, arg0: u32, arg1: u32, arg2: u32, arg3: u32) bool {
        const item = BootLogEvent{ .event = event, .arg0 = arg0, .arg1 = arg1, .arg2 = arg2, .arg3 = arg3 };
        if (!self.storage_enabled) {
            if (self.pending_count >= self.pending.len) {
                self.dropped_count +%= 1;
                return false;
            }
            self.pending[self.pending_count] = item;
            self.pending_count += 1;
            return true;
        }
        return self.writeEvent(item);
    }

    fn writeEvent(self: *BootLog, event: BootLogEvent) bool {
        const write = self.write_block orelse return false;
        var block = [_]u8{0} ** boot_log_block_bytes;
        const sequence = self.next_sequence;
        putLe32(block[0..4], boot_log_magic);
        putLe32(block[4..8], boot_log_version);
        putLe32(block[8..12], self.boot_id);
        putLe32(block[12..16], boot_image_id);
        putLe32(block[16..20], sequence);
        putLe32(block[20..24], self.dropped_count);
        putLe32(block[24..28], @intFromEnum(event.event));
        putLe32(block[28..32], event.arg0);
        putLe32(block[32..36], event.arg1);
        putLe32(block[36..40], event.arg2);
        putLe32(block[40..44], event.arg3);
        putLe32(block[44..48], boot_image_revision);
        putLe32(block[508..512], crc32(block[0..508]));

        const block_address = boot_log_start_block + (sequence % boot_log_block_count);
        if (!write(self.write_user, block_address, &block)) return false;
        self.next_sequence +%= 1;
        return true;
    }
};

pub const SdioIdentityPlan = struct {
    commands: [3]pi_mmc.Command,
    command_count: usize = 3,
};

pub const SdioClaimPlan = struct {
    commands: [2]pi_mmc.Command,
    command_count: usize = 2,
};

pub fn sdioIdentityPlan() SdioIdentityPlan {
    return .{ .commands = .{
        pi_mmc.commandPrepare(pi_mmc.cmd_go_idle_state, 0, .none).?,
        pi_mmc.commandPrepare(pi_mmc.cmd_io_send_op_cond, 0x00ff_8000, .r4).?,
        pi_mmc.commandPrepare(pi_mmc.cmd_send_relative_addr, 0, .r6).?,
    } };
}

pub fn sdioClaimPlan(relative_card_address: u32) ?SdioClaimPlan {
    if (relative_card_address == 0) return null;
    return .{ .commands = .{
        pi_mmc.commandPrepare(pi_mmc.cmd_select_card, pi_mmc.relativeCardArgument(relative_card_address), .r1).?,
        pi_mmc.commandPrepare(pi_mmc.cmd_io_rw_direct, pi_mmc.sdioCmd52Argument(true, pi_mmc.sdio_function_cccr, false, 0x02, 0x06), .r5).?,
    } };
}

pub fn crc32(bytes: []const u8) u32 {
    var crc: u32 = 0xffff_ffff;
    for (bytes) |byte| {
        crc ^= byte;
        var bit: u8 = 0;
        while (bit < 8) : (bit += 1) {
            const mask: u32 = if ((crc & 1) != 0) 0xedb8_8320 else 0;
            crc = (crc >> 1) ^ mask;
        }
    }
    return ~crc;
}

fn putLe32(out: []u8, value: u32) void {
    out[0] = @intCast(value & 0xff);
    out[1] = @intCast((value >> 8) & 0xff);
    out[2] = @intCast((value >> 16) & 0xff);
    out[3] = @intCast((value >> 24) & 0xff);
}

fn getLe32(value: []const u8) u32 {
    return @as(u32, value[0]) |
        (@as(u32, value[1]) << 8) |
        (@as(u32, value[2]) << 16) |
        (@as(u32, value[3]) << 24);
}

const TestBootLogIo = struct {
    calls: u32 = 0,
    block_address: [4]u32 = [_]u32{0} ** 4,
    block: [4]BootLogBlock = [_]BootLogBlock{[_]u8{0} ** boot_log_block_bytes} ** 4,
};

fn testBootLogWrite(user: ?*anyopaque, block_address: u32, block: *const BootLogBlock) bool {
    const io: *TestBootLogIo = @ptrCast(@alignCast(user.?));
    if (io.calls >= io.block.len) return false;
    io.block_address[io.calls] = block_address;
    @memcpy(&io.block[io.calls], block);
    io.calls += 1;
    return true;
}

test "persists Pi Zero W v1.1 boot log blocks" {
    try std.testing.expectEqual(@as(u32, 0xcbf4_3926), crc32("123456789"));
    var io = TestBootLogIo{};
    var log = BootLog.init(0x1234_5678);
    try std.testing.expect(log.append(.boot_entry, 1, 2, 3, 4));
    try std.testing.expectEqual(@as(u32, 0), io.calls);
    try std.testing.expect(log.enableStorage(testBootLogWrite, &io));
    try std.testing.expectEqual(@as(u32, 1), io.calls);
    try std.testing.expectEqual(boot_log_start_block, io.block_address[0]);
    try std.testing.expectEqual(boot_log_magic, getLe32(io.block[0][0..4]));
    try std.testing.expectEqual(boot_log_version, getLe32(io.block[0][4..8]));
    try std.testing.expectEqual(@as(u32, 0), getLe32(io.block[0][16..20]));
    try std.testing.expectEqual(@intFromEnum(BootLogEventKind.boot_entry), getLe32(io.block[0][24..28]));
    try std.testing.expectEqual(@as(u32, 1), getLe32(io.block[0][28..32]));
    try std.testing.expectEqual(crc32(io.block[0][0..508]), getLe32(io.block[0][508..512]));

    try std.testing.expect(log.append(.storage_ready, 5, 6, 7, 8));
    try std.testing.expectEqual(@as(u32, 2), io.calls);
    try std.testing.expectEqual(@as(u32, 1), getLe32(io.block[1][16..20]));
    try std.testing.expectEqual(@intFromEnum(BootLogEventKind.storage_ready), getLe32(io.block[1][24..28]));
}

test "plans Pi Zero W v1.1 SDIO identity and claim commands" {
    const identity = sdioIdentityPlan();
    try std.testing.expectEqual(@as(usize, 3), identity.command_count);
    try std.testing.expectEqual(pi_mmc.cmd_go_idle_state, identity.commands[0].command_index);
    try std.testing.expectEqual(pi_mmc.ResponseKind.none, identity.commands[0].response_kind);
    try std.testing.expectEqual(pi_mmc.cmd_io_send_op_cond, identity.commands[1].command_index);
    try std.testing.expectEqual(pi_mmc.ResponseKind.r4, identity.commands[1].response_kind);
    try std.testing.expectEqual(pi_mmc.cmd_send_relative_addr, identity.commands[2].command_index);
    try std.testing.expectEqual(pi_mmc.ResponseKind.r6, identity.commands[2].response_kind);

    try std.testing.expect(sdioClaimPlan(0) == null);
    const claim = sdioClaimPlan(0x1234).?;
    try std.testing.expectEqual(pi_mmc.cmd_select_card, claim.commands[0].command_index);
    try std.testing.expectEqual(@as(u32, 0x1234_0000), claim.commands[0].argument);
    try std.testing.expectEqual(pi_mmc.cmd_io_rw_direct, claim.commands[1].command_index);
    try std.testing.expectEqual(pi_mmc.ResponseKind.r5, claim.commands[1].response_kind);
}
