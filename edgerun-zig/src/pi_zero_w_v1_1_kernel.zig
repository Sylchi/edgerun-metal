const bringup = @import("pi_zero_w_v1_1_bringup.zig");
const kernel_path = @import("pi_zero_w_v1_1_kernel_path.zig");

fn reg32(base: u32, offset: u32) *volatile u32 {
    return @ptrFromInt(base + offset);
}

fn mmioRead32(user: ?*anyopaque, base: u32, offset: u32) u32 {
    _ = user;
    return reg32(base, offset).*;
}

fn mmioWrite32(user: ?*anyopaque, base: u32, offset: u32, value: u32) void {
    _ = user;
    reg32(base, offset).* = value;
}

fn delay(user: ?*anyopaque, ticks: u32) void {
    _ = user;
    var i: u32 = 0;
    while (i < ticks) : (i += 1) {
        asm volatile ("nop");
    }
}

export fn kernelMain() callconv(.c) noreturn {
    var board = bringup.Board{ .mmio = .{
        .read32 = mmioRead32,
        .write32 = mmioWrite32,
        .delay = delay,
    } };
    board.initEarly();
    board.putString("\r\nER ZIG PI ZERO W V1.1 BOOT\r\n");

    const arm_memory = board.queryArmMemory() orelse {
        board.putString("boot-resource-map=arm-memory-failed\r\n");
        board.signalFailure(24);
    };
    var runtime = kernel_path.Runtime{};
    runtime.initFromArmMemory(arm_memory.physical_start, arm_memory.byte_len) catch {
        board.putString("boot-resource-map=software-verifier-failed\r\n");
        board.signalFailure(25);
    };
    const boot_memory = runtime.bootMemoryResource();
    board.putString("boot-resource-map=ok verifier=software-p256-sha256 start=");
    board.putHex32(@intCast(boot_memory.bounds.offset));
    board.putString(" bytes=");
    board.putHex32(@intCast(boot_memory.bounds.length));
    board.putString("\r\n");

    if (!board.logToSd()) {
        board.putString("sd=unavailable continuing=usb-boot\r\n");
    }
    board.heartbeat();
}

export fn _start() callconv(.naked) noreturn {
    asm volatile (
        \\mov sp, #0x8000
        \\bl kernelMain
        \\1: b 1b
    );
}
