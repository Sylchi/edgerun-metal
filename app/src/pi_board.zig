const std = @import("std");
const pi_mmc = @import("pi_mmc.zig");

pub const Peripheral = struct {
    offset: u32,
    bytes: u32,
};

pub const WifiKind = enum {
    none,
    cyw43438_sdio,
    cyw43439_sdio,
};

pub const BluetoothKind = enum {
    none,
    cyw43438_hci_uart,
    cyw43439_hci_uart,
};

pub const BoardProfile = struct {
    peripheral_base: u32,
    peripheral_bytes: u32,
    mailbox: Peripheral,
    gpio: Peripheral,
    sdhost: Peripheral,
    emmc: Peripheral,
    aux: Peripheral,
    wifi: WifiKind,
    bluetooth: BluetoothKind,
    wireless_channel: u8,

    pub fn absolute(self: BoardProfile, peripheral: Peripheral) Peripheral {
        return .{
            .offset = self.peripheral_base + peripheral.offset,
            .bytes = peripheral.bytes,
        };
    }
};

pub const LocalStorageKind = enum {
    none,
    sd_card,
};

pub const UpdateBlockedReason = enum {
    none,
    no_wifi,
    wifi_not_ready,
};

pub const RuntimeCapabilities = struct {
    wifi: WifiKind = .none,
    wifi_ready: bool = false,
    wifi_channel: u8 = 0,
    bluetooth: BluetoothKind = .none,
    bluetooth_ready: bool = false,
    local_storage: LocalStorageKind = .none,
    local_storage_ready: bool = false,
    storage_block_bytes: u32 = 0,
    storage_transfer_bytes: u32 = 0,
    update_artifact_store_ready: bool = false,
    update_blocked_reason: UpdateBlockedReason = .none,

    pub fn updateBlocked(self: RuntimeCapabilities) bool {
        return self.update_blocked_reason != .none;
    }
};

pub const BoardInventory = struct {
    collected_before_exit_boot_services: bool = true,
    peripheral: Peripheral,
    mailbox: Peripheral,
    gpio: Peripheral,
    sdhost: Peripheral,
    emmc: Peripheral,
    aux: Peripheral,
    runtime: RuntimeCapabilities,
};

pub const pi_zero_2_w = BoardProfile{
    .peripheral_base = 0x3f00_0000,
    .peripheral_bytes = 0x0100_0000,
    .mailbox = .{ .offset = 0x0000_b880, .bytes = 0x24 },
    .gpio = .{ .offset = 0x0020_0000, .bytes = 0xb4 },
    .sdhost = .{ .offset = 0x0020_2000, .bytes = 0x100 },
    .emmc = .{ .offset = 0x0030_0000, .bytes = 0x100 },
    .aux = .{ .offset = 0x0021_5000, .bytes = 0x100 },
    .wifi = .cyw43439_sdio,
    .bluetooth = .cyw43439_hci_uart,
    .wireless_channel = 6,
};

pub fn runtimeCapabilities(profile: BoardProfile) RuntimeCapabilities {
    return .{
        .wifi = profile.wifi,
        .wifi_ready = false,
        .wifi_channel = profile.wireless_channel,
        .bluetooth = profile.bluetooth,
        .bluetooth_ready = false,
        .local_storage = .sd_card,
        .local_storage_ready = false,
        .storage_block_bytes = pi_mmc.emmc_block_bytes,
        .storage_transfer_bytes = pi_mmc.emmc_block_bytes,
        .update_artifact_store_ready = false,
        .update_blocked_reason = if (profile.wifi == .none) .no_wifi else .wifi_not_ready,
    };
}

pub fn preExitBoardInventory(profile: BoardProfile) BoardInventory {
    return .{
        .peripheral = .{ .offset = profile.peripheral_base, .bytes = profile.peripheral_bytes },
        .mailbox = profile.absolute(profile.mailbox),
        .gpio = profile.absolute(profile.gpio),
        .sdhost = profile.absolute(profile.sdhost),
        .emmc = profile.absolute(profile.emmc),
        .aux = profile.absolute(profile.aux),
        .runtime = runtimeCapabilities(profile),
    };
}

pub const pi_zero_w_v1_1 = BoardProfile{
    .peripheral_base = 0x2000_0000,
    .peripheral_bytes = 0x0100_0000,
    .mailbox = .{ .offset = 0x0000_b880, .bytes = 0x24 },
    .gpio = .{ .offset = 0x0020_0000, .bytes = 0xb4 },
    .sdhost = .{ .offset = 0x0020_2000, .bytes = 0x100 },
    .emmc = .{ .offset = 0x0030_0000, .bytes = 0x100 },
    .aux = .{ .offset = 0x0021_5000, .bytes = 0x100 },
    .wifi = .cyw43438_sdio,
    .bluetooth = .cyw43438_hci_uart,
    .wireless_channel = 6,
};

pub const mailbox_property_channel: u32 = 8;
pub const mailbox_request_code: u32 = 0;
pub const mailbox_tag_get_board_model: u32 = 0x0001_0001;
pub const mailbox_tag_get_arm_memory: u32 = 0x0001_0005;
pub const mailbox_tag_get_clock_rate: u32 = 0x0003_0002;
pub const mailbox_tag_set_clock_rate: u32 = 0x0003_8002;
pub const mailbox_tag_last: u32 = 0;
pub const mailbox_two_value_words: usize = 8;
pub const mailbox_two_value_bytes: u32 = mailbox_two_value_words * 4;

pub const MailboxTwoValueMessage = struct {
    size_bytes: u32 = mailbox_two_value_bytes,
    request_code: u32 = mailbox_request_code,
    tag_id: u32,
    value_buffer_bytes: u32 = 8,
    request_value_bytes: u32 = 0,
    value0: u32,
    value1: u32,
    end_tag: u32 = mailbox_tag_last,

    pub fn encode(self: MailboxTwoValueMessage) [mailbox_two_value_words]u32 {
        return .{
            self.size_bytes,
            self.request_code,
            self.tag_id,
            self.value_buffer_bytes,
            self.request_value_bytes,
            self.value0,
            self.value1,
            self.end_tag,
        };
    }
};

pub const SdMemoryIdentityPlan = struct {
    commands: [6]pi_mmc.Command,
    command_count: usize = 6,
};

pub const SdMemoryClaimPlan = struct {
    commands: [1]pi_mmc.Command,
    command_count: usize = 1,
};

pub const SdioIdentityPlan = struct {
    commands: [3]pi_mmc.Command,
    command_count: usize = 3,
};

pub const SdioClaimPlan = struct {
    commands: [2]pi_mmc.Command,
    command_count: usize = 2,
};

pub const SdioBringupState = struct {
    command_count: usize = 0,
    completed_count: usize = 0,
    relative_card_address: u32 = 0,
    responses: [8]u32 = [_]u32{0} ** 8,
    last_interrupt_value: u32 = 0,
    completed: bool = false,
    has_error: bool = false,
};

pub const SdMemoryBringupState = struct {
    command_count: usize = 0,
    completed_count: usize = 0,
    relative_card_address: u32 = 0,
    operating_conditions: u32 = 0,
    responses: [8]u32 = [_]u32{0} ** 8,
    last_interrupt_value: u32 = 0,
    completed: bool = false,
    has_error: bool = false,
};

pub fn sdMemoryIdentityPlan() SdMemoryIdentityPlan {
    return .{ .commands = .{
        pi_mmc.commandPrepare(pi_mmc.cmd_go_idle_state, 0, .none).?,
        pi_mmc.commandPrepare(pi_mmc.cmd_send_if_cond, 0x0000_01aa, .r7).?,
        pi_mmc.commandPrepare(pi_mmc.cmd_app_cmd, 0, .r1).?,
        pi_mmc.commandPrepare(pi_mmc.acmd_sd_send_op_cond, 0x4030_0000, .r3).?,
        pi_mmc.commandPrepare(pi_mmc.cmd_all_send_cid, 0, .r2).?,
        pi_mmc.commandPrepare(pi_mmc.cmd_send_relative_addr, 0, .r6).?,
    } };
}

pub fn sdMemoryClaimPlan(relative_card_address: u32) ?SdMemoryClaimPlan {
    if (relative_card_address == 0 or relative_card_address > 0xffff) return null;
    return .{ .commands = .{
        pi_mmc.commandPrepare(pi_mmc.cmd_select_card, pi_mmc.relativeCardArgument(relative_card_address), .r1).?,
    } };
}

pub fn sdioIdentityPlan() SdioIdentityPlan {
    return .{ .commands = .{
        pi_mmc.commandPrepare(pi_mmc.cmd_go_idle_state, 0, .none).?,
        pi_mmc.commandPrepare(pi_mmc.cmd_io_send_op_cond, 0x0030_0000, .r4).?,
        pi_mmc.commandPrepare(pi_mmc.cmd_send_relative_addr, 0, .r6).?,
    } };
}

pub fn sdioClaimPlan(relative_card_address: u32) ?SdioClaimPlan {
    if (relative_card_address == 0 or relative_card_address > 0xffff) return null;
    return .{ .commands = .{
        pi_mmc.commandPrepare(pi_mmc.cmd_select_card, pi_mmc.relativeCardArgument(relative_card_address), .r1).?,
        pi_mmc.commandPrepare(pi_mmc.cmd_io_rw_direct, pi_mmc.sdioCmd52Argument(false, pi_mmc.sdio_function_backplane, false, 0, 0), .r5).?,
    } };
}

pub fn executeSdMemoryIdentityPlan(ops: *const pi_mmc.MmioOps, plan: SdMemoryIdentityPlan, poll_budget_per_command: u32) SdMemoryBringupState {
    return executeSdMemoryCommands(ops, plan.commands[0..plan.command_count], poll_budget_per_command);
}

pub fn executeSdMemoryClaimPlan(ops: *const pi_mmc.MmioOps, plan: SdMemoryClaimPlan, poll_budget_per_command: u32) SdMemoryBringupState {
    return executeSdMemoryCommands(ops, plan.commands[0..plan.command_count], poll_budget_per_command);
}

pub fn executeSdioIdentityPlan(ops: *const pi_mmc.MmioOps, plan: SdioIdentityPlan, poll_budget_per_command: u32) SdioBringupState {
    return executeSdioCommands(ops, plan.commands[0..plan.command_count], poll_budget_per_command);
}

pub fn executeSdioClaimPlan(ops: *const pi_mmc.MmioOps, plan: SdioClaimPlan, poll_budget_per_command: u32) SdioBringupState {
    return executeSdioCommands(ops, plan.commands[0..plan.command_count], poll_budget_per_command);
}

fn executeSdMemoryCommands(ops: *const pi_mmc.MmioOps, commands: []const pi_mmc.Command, poll_budget_per_command: u32) SdMemoryBringupState {
    var state = SdMemoryBringupState{ .command_count = commands.len };
    if (commands.len == 0 or commands.len > state.responses.len or poll_budget_per_command == 0) {
        state.has_error = true;
        return state;
    }
    for (commands, 0..) |command, index| {
        const result = pi_mmc.commandExecuteWithOps(ops, command, poll_budget_per_command);
        state.last_interrupt_value = result.interrupt_value;
        if (!result.completed or result.has_error) {
            state.has_error = true;
            return state;
        }
        state.responses[index] = result.response0;
        state.completed_count += 1;
        if (command.response_kind == .r3) state.operating_conditions = result.response0;
        if (command.response_kind == .r6) {
            state.relative_card_address = pi_mmc.relativeCardFromR6(result.response0);
            if (state.relative_card_address == 0) {
                state.has_error = true;
                return state;
            }
        }
    }
    state.completed = true;
    return state;
}

fn executeSdioCommands(ops: *const pi_mmc.MmioOps, commands: []const pi_mmc.Command, poll_budget_per_command: u32) SdioBringupState {
    var state = SdioBringupState{ .command_count = commands.len };
    if (commands.len == 0 or commands.len > state.responses.len or poll_budget_per_command == 0) {
        state.has_error = true;
        return state;
    }
    for (commands, 0..) |command, index| {
        const result = pi_mmc.commandExecuteWithOps(ops, command, poll_budget_per_command);
        state.last_interrupt_value = result.interrupt_value;
        if (!result.completed or result.has_error) {
            state.has_error = true;
            return state;
        }
        state.responses[index] = result.response0;
        state.completed_count += 1;
        if (command.response_kind == .r6) {
            state.relative_card_address = pi_mmc.relativeCardFromR6(result.response0);
            if (state.relative_card_address == 0) {
                state.has_error = true;
                return state;
            }
        }
    }
    state.completed = true;
    return state;
}

pub const SdioProbeStatus = enum(u32) {
    none = 0,
    cmd0_done = 1,
    cmd5_done = 2,
    cmd3_done = 3,
    cmd7_done = 4,
    cmd52_done = 5,
    cmd53_done = 6,
    l2_ready = 7,
    owned_firmware_loaded = 12,
    cm3_active = 13,
    d11_tx_fifo_ready = 14,
    d11_tx_template_loaded = 15,
    d11_tx_pio_attempted = 16,
    d11_mac_tx_attempted = 17,
    ota_listening = 18,
    raw_rx_unsupported = 19,
    error_status = 0xffff_ffff,
};

test "describes Pi Zero board peripheral windows" {
    try std.testing.expectEqual(@as(u32, 0x3f00_0000), pi_zero_2_w.peripheral_base);
    try std.testing.expectEqual(@as(u32, 0x2000_0000), pi_zero_w_v1_1.peripheral_base);
    try std.testing.expectEqual(WifiKind.cyw43439_sdio, pi_zero_2_w.wifi);
    try std.testing.expectEqual(WifiKind.cyw43438_sdio, pi_zero_w_v1_1.wifi);
    try std.testing.expectEqual(@as(u32, 0x2020_0000), pi_zero_w_v1_1.absolute(pi_zero_w_v1_1.gpio).offset);
}

test "builds pre-ExitBootServices Pi board inventory" {
    const zero2 = preExitBoardInventory(pi_zero_2_w);
    try std.testing.expect(zero2.collected_before_exit_boot_services);
    try std.testing.expectEqual(@as(u32, 0x3f00_0000), zero2.peripheral.offset);
    try std.testing.expectEqual(@as(u32, 0x3f00_b880), zero2.mailbox.offset);
    try std.testing.expectEqual(@as(u32, 0x3f20_0000), zero2.gpio.offset);
    try std.testing.expectEqual(@as(u32, 0x3f30_0000), zero2.emmc.offset);
    try std.testing.expectEqual(WifiKind.cyw43439_sdio, zero2.runtime.wifi);
    try std.testing.expectEqual(BluetoothKind.cyw43439_hci_uart, zero2.runtime.bluetooth);
    try std.testing.expectEqual(LocalStorageKind.sd_card, zero2.runtime.local_storage);
    try std.testing.expectEqual(pi_mmc.emmc_block_bytes, zero2.runtime.storage_block_bytes);
    try std.testing.expectEqual(@as(u8, 6), zero2.runtime.wifi_channel);
    try std.testing.expectEqual(UpdateBlockedReason.wifi_not_ready, zero2.runtime.update_blocked_reason);
    try std.testing.expect(zero2.runtime.updateBlocked());

    const zero_w = preExitBoardInventory(pi_zero_w_v1_1);
    try std.testing.expectEqual(@as(u32, 0x2000_0000), zero_w.peripheral.offset);
    try std.testing.expectEqual(@as(u32, 0x2020_0000), zero_w.gpio.offset);
    try std.testing.expectEqual(WifiKind.cyw43438_sdio, zero_w.runtime.wifi);
    try std.testing.expectEqual(BluetoothKind.cyw43438_hci_uart, zero_w.runtime.bluetooth);
}

test "encodes Raspberry Pi mailbox two value messages" {
    const message = MailboxTwoValueMessage{
        .tag_id = mailbox_tag_set_clock_rate,
        .value0 = pi_mmc.clock_id_emmc,
        .value1 = 250_000_000,
    };
    const words = message.encode();
    try std.testing.expectEqual(@as(u32, 32), words[0]);
    try std.testing.expectEqual(mailbox_tag_set_clock_rate, words[2]);
    try std.testing.expectEqual(@as(u32, 8), words[3]);
    try std.testing.expectEqual(pi_mmc.clock_id_emmc, words[5]);
    try std.testing.expectEqual(@as(u32, 250_000_000), words[6]);
    try std.testing.expectEqual(@as(u32, 0), words[7]);
}

test "plans SD memory and SDIO card bringup" {
    const sd = sdMemoryIdentityPlan();
    try std.testing.expectEqual(pi_mmc.cmd_go_idle_state, sd.commands[0].command_index);
    try std.testing.expectEqual(pi_mmc.cmd_send_if_cond, sd.commands[1].command_index);
    try std.testing.expectEqual(@as(u32, 0x0000_01aa), sd.commands[1].argument);
    try std.testing.expectEqual(pi_mmc.acmd_sd_send_op_cond, sd.commands[3].command_index);
    try std.testing.expectEqual(@as(u32, 0x4030_0000), sd.commands[3].argument);
    try std.testing.expectEqual(pi_mmc.cmd_all_send_cid, sd.commands[4].command_index);
    try std.testing.expectEqual(pi_mmc.cmd_send_relative_addr, sd.commands[5].command_index);
    try std.testing.expect(sdMemoryClaimPlan(0) == null);
    try std.testing.expect(sdMemoryClaimPlan(0x1_0000) == null);
    try std.testing.expectEqual(@as(u32, 0x1234_0000), sdMemoryClaimPlan(0x1234).?.commands[0].argument);

    const sdio = sdioIdentityPlan();
    try std.testing.expectEqual(pi_mmc.cmd_io_send_op_cond, sdio.commands[1].command_index);
    try std.testing.expectEqual(@as(u32, 0x0030_0000), sdio.commands[1].argument);
    try std.testing.expect(sdioClaimPlan(0) == null);
    try std.testing.expect(sdioClaimPlan(0x1_0000) == null);
    const claim = sdioClaimPlan(0x1234).?;
    try std.testing.expectEqual(pi_mmc.cmd_select_card, claim.commands[0].command_index);
    try std.testing.expectEqual(@as(u32, 0x1234_0000), claim.commands[0].argument);
    try std.testing.expectEqual(@as(u32, 0x1000_0000), claim.commands[1].argument);
}

const TestPlanOpsCtx = struct {
    response_index: usize = 0,
    responses: [8]u32 = [_]u32{0} ** 8,
    writes: u32 = 0,
    interrupt_reads: u32 = 0,
};

fn testPlanRead32(user: ?*anyopaque, offset: u32, out_value: *u32) bool {
    const ctx: *TestPlanOpsCtx = @ptrCast(@alignCast(user.?));
    switch (offset) {
        pi_mmc.emmc_reg_interrupt => {
            ctx.interrupt_reads += 1;
            out_value.* = pi_mmc.emmc_interrupt_cmd_done;
            return true;
        },
        pi_mmc.emmc_reg_resp0 => {
            out_value.* = ctx.responses[ctx.response_index];
            ctx.response_index += 1;
            return true;
        },
        else => {
            out_value.* = 0;
            return true;
        },
    }
}

fn testPlanWrite32(user: ?*anyopaque, offset: u32, value: u32) bool {
    _ = offset;
    _ = value;
    const ctx: *TestPlanOpsCtx = @ptrCast(@alignCast(user.?));
    ctx.writes += 1;
    return true;
}

test "executes SD memory and SDIO bringup plans with injected MMC ops" {
    var ctx = TestPlanOpsCtx{ .responses = .{
        0x0000_01aa,
        0,
        0x4030_0000,
        0,
        0x1234_0000,
        0,
        0,
        0,
    } };
    const ops = pi_mmc.MmioOps{ .user = &ctx, .read32 = testPlanRead32, .write32 = testPlanWrite32 };

    const sd = executeSdMemoryIdentityPlan(&ops, sdMemoryIdentityPlan(), 1);
    try std.testing.expect(sd.completed);
    try std.testing.expect(!sd.has_error);
    try std.testing.expectEqual(@as(usize, 6), sd.command_count);
    try std.testing.expectEqual(@as(usize, 6), sd.completed_count);
    try std.testing.expectEqual(@as(u32, 0x4030_0000), sd.operating_conditions);
    try std.testing.expectEqual(@as(u32, 0x1234), sd.relative_card_address);
    try std.testing.expectEqual(pi_mmc.emmc_interrupt_cmd_done, sd.last_interrupt_value);

    ctx = .{ .responses = .{ 0, 0x5678_0000, 0, 0, 0, 0, 0, 0 } };
    const sdio = executeSdioIdentityPlan(&ops, sdioIdentityPlan(), 1);
    try std.testing.expect(sdio.completed);
    try std.testing.expect(!sdio.has_error);
    try std.testing.expectEqual(@as(usize, 3), sdio.completed_count);
    try std.testing.expectEqual(@as(u32, 0x5678), sdio.relative_card_address);

    ctx = .{ .responses = .{ 0, 0, 0, 0, 0, 0, 0, 0 } };
    const bad = executeSdioIdentityPlan(&ops, sdioIdentityPlan(), 1);
    try std.testing.expect(!bad.completed);
    try std.testing.expect(bad.has_error);
    try std.testing.expectEqual(@as(usize, 3), bad.completed_count);
}
