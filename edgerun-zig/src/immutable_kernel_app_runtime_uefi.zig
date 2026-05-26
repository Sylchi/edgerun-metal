const std = @import("std");
const uefi = std.os.uefi;
const gop_framebuffer = @import("boot/gop_framebuffer.zig");
const wasm = @import("wasm/root.zig");

const app_runtime_wasm = @import("embedded_app_runtime_wasm").bytes;

const debugcon_port: u16 = 0x402;
const line_max: usize = 192;
const wasm_page_bytes: usize = 64 * 1024;
const uefi_page_bytes: usize = 4096;
const uefi_pages_per_wasm_page: usize = wasm_page_bytes / uefi_page_bytes;
const app_runtime_initial_pages: usize = 10484;
const app_runtime_extra_pages: usize = 32;
const app_runtime_pages: usize = app_runtime_initial_pages + app_runtime_extra_pages;
const app_runtime_uefi_pages: usize = app_runtime_pages * uefi_pages_per_wasm_page;
const app_runtime_ticks: u64 = 200_000_000;
const max_boot_width: u32 = 640;
const max_boot_height: u32 = 360;

var framebuffer: gop_framebuffer.Framebuffer = undefined;
var wasm_storage: wasm.ExecutionStorage = .{};
var ticks: u64 = app_runtime_ticks;

pub fn main() noreturn {
    printLine("EdgeRun app-runtime GOP smoke");
    run() catch |err| {
        printText("FAIL ");
        printError(err);
        printNewline();
        if (framebuffer.valid()) framebuffer.drawDebugScreen(.post_exit);
        haltForever();
    };
    haltForever();
}

fn run() Error!void {
    const boot_services = uefi.system_table.boot_services orelse return error.BootServicesUnavailable;
    framebuffer = gop_framebuffer.collect(boot_services) catch |err| return mapFramebufferError(err);
    framebuffer.drawDebugScreen(.pre_exit);
    printLine("check: gop framebuffer handoff ok");

    const app_pages = boot_services.allocatePages(.any, .loader_data, app_runtime_uefi_pages) catch return error.AppMemoryAllocationFailed;
    const app_memory = std.mem.sliceAsBytes(app_pages);
    @memset(app_memory, 0);
    printLine("check: app-runtime memory allocated");

    var runtime = wasm.Runtime.initWithMemoryPages(app_memory, &ticks, app_runtime_pages);
    _ = call(&runtime, "er_ui_boot", &.{}) catch |err| return mapWasmError(err);
    printLine("check: app-runtime boot ok");

    const width = @min(framebuffer.width, max_boot_width);
    const height = @min(framebuffer.height, max_boot_height);
    const render_result = call(&runtime, "er_ui_render_frame", &.{
        .{ .i32 = @intCast(width) },
        .{ .i32 = @intCast(height) },
        .{ .f32 = 0.0 },
    }) catch |err| return mapWasmError(err);
    if (try resultI32(render_result) != 0) return error.AppRenderFailed;
    printLine("check: app-runtime render ok");

    const pixel_ptr = try callI32(&runtime, "er_ui_pixels_ptr");
    const pixel_len = try callI32(&runtime, "er_ui_pixels_len");
    if (pixel_ptr < 0 or pixel_len <= 0) return error.AppPixelsInvalid;
    const start: usize = @intCast(pixel_ptr);
    const len: usize = @intCast(pixel_len);
    if (start > app_memory.len or len > app_memory.len - start) return error.AppPixelsInvalid;

    framebuffer.blitUiColorBytes(width, height, app_memory[start .. start + len]);
    printLine("check: app-runtime pixels copied to gop");
    printLine("PASS immutable-kernel-app-runtime-qemu");
}

fn call(runtime: *wasm.Runtime, export_name: []const u8, args: []const wasm.Value) wasm.Error!wasm.ExecutionResult {
    return wasm.executeExportValueArgsWithStorage(runtime, &app_runtime_wasm, export_name, args, &wasm_storage);
}

fn callI32(runtime: *wasm.Runtime, export_name: []const u8) Error!i32 {
    return resultI32(call(runtime, export_name, &.{}) catch |err| return mapWasmError(err));
}

fn resultI32(result: wasm.ExecutionResult) Error!i32 {
    if (result.count != 1) return error.AppRuntimeBadResult;
    return result.valueI32(0) catch error.AppRuntimeBadResult;
}

const Error = error{
    AppMemoryAllocationFailed,
    AppPixelsInvalid,
    AppRenderFailed,
    AppRuntimeBadResult,
    BootServicesUnavailable,
    FramebufferBadFormat,
    FramebufferMissing,
    WasmBadArgument,
    WasmCorrupt,
    WasmMissingExport,
    WasmMemoryGrowthRequiresAuthority,
    WasmNoExecution,
    WasmNoMemory,
    WasmUnsupported,
    WasmTrap,
};

fn mapFramebufferError(err: gop_framebuffer.Error) Error {
    return switch (err) {
        error.NoGraphicsOutput => error.FramebufferMissing,
        error.UnsupportedPixelFormat => error.FramebufferBadFormat,
    };
}

fn mapWasmError(err: wasm.Error) Error {
    return switch (err) {
        error.BadArgument => error.WasmBadArgument,
        error.Corrupt => error.WasmCorrupt,
        error.MissingExport => error.WasmMissingExport,
        error.MemoryGrowthRequiresAuthority => error.WasmMemoryGrowthRequiresAuthority,
        error.NoExecution => error.WasmNoExecution,
        error.NoMemory => error.WasmNoMemory,
        error.Unsupported, error.TableGrowthRequiresAuthority => error.WasmUnsupported,
        error.Trap, error.ArithmeticTrap, error.StackOverflow, error.StackUnderflow, error.MissingImport => error.WasmTrap,
    };
}

fn printError(err: Error) void {
    switch (err) {
        error.AppMemoryAllocationFailed => printText("app-memory-allocation-failed"),
        error.AppPixelsInvalid => printText("app-pixels-invalid"),
        error.AppRenderFailed => printText("app-render-failed"),
        error.AppRuntimeBadResult => printText("app-runtime-bad-result"),
        error.BootServicesUnavailable => printText("boot-services-unavailable"),
        error.FramebufferBadFormat => printText("framebuffer-bad-format"),
        error.FramebufferMissing => printText("framebuffer-missing"),
        error.WasmBadArgument => printText("wasm-bad-argument"),
        error.WasmCorrupt => printText("wasm-corrupt"),
        error.WasmMissingExport => printText("wasm-missing-export"),
        error.WasmMemoryGrowthRequiresAuthority => printText("wasm-memory-growth-requires-authority"),
        error.WasmNoExecution => printText("wasm-no-execution"),
        error.WasmNoMemory => printText("wasm-no-memory"),
        error.WasmUnsupported => printText("wasm-unsupported"),
        error.WasmTrap => printText("wasm-trap"),
    }
}

fn printLine(message: []const u8) void {
    printText(message);
    printNewline();
}

fn printNewline() void {
    printText("\r\n");
}

fn printText(message: []const u8) void {
    writeDebugcon(message);
    writeConsole(message);
}

fn writeConsole(message: []const u8) void {
    const out = uefi.system_table.con_out orelse return;
    var wide: [line_max:0]u16 = undefined;
    var index: usize = 0;
    while (index < message.len and index < line_max) : (index += 1) {
        wide[index] = message[index];
    }
    wide[index] = 0;
    _ = out.outputString(@ptrCast(&wide)) catch false;
}

fn writeDebugcon(message: []const u8) void {
    for (message) |byte| {
        outb(debugcon_port, byte);
    }
}

fn outb(port: u16, value: u8) void {
    asm volatile ("outb %[value], %[port]"
        :
        : [value] "{al}" (value),
          [port] "{dx}" (port),
    );
}

fn haltForever() noreturn {
    while (true) {
        asm volatile ("hlt");
    }
}
