const std = @import("std");
const uefi = std.os.uefi;
const gop_framebuffer = @import("boot/gop_framebuffer.zig");
const renderer_ir = @import("render/ir.zig");
const renderer_software = @import("render/software.zig");
const ui = @import("ui.zig");
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
    const build_result = call(&runtime, "er_ui_build_frame", &.{
        .{ .i32 = @intCast(width) },
        .{ .i32 = @intCast(height) },
        .{ .f32 = 0.0 },
    }) catch |err| return mapWasmError(err);
    if (try resultI32(build_result) != 0) return error.AppFrameBuildFailed;
    printLine("check: app-runtime frame ir built");

    const native_pixels = try allocateNativePixels(boot_services, width, height);
    try renderNativeAppFrame(&runtime, app_memory, width, height, native_pixels);
    printLine("check: blessed native renderer ok");

    framebuffer.blitUiColorBytes(width, height, std.mem.sliceAsBytes(native_pixels));
    printLine("check: blessed native pixels copied to gop");
    printLine("PASS immutable-kernel-app-runtime-qemu");
}

fn allocateNativePixels(boot_services: *uefi.tables.BootServices, width: u32, height: u32) Error![]ui.Color {
    const pixel_count = std.math.mul(usize, width, height) catch return error.NativePixelAllocationFailed;
    const byte_count = std.math.mul(usize, pixel_count, @sizeOf(ui.Color)) catch return error.NativePixelAllocationFailed;
    const pages = (byte_count + uefi_page_bytes - 1) / uefi_page_bytes;
    const bytes = boot_services.allocatePages(.any, .loader_data, pages) catch return error.NativePixelAllocationFailed;
    const pixel_bytes = std.mem.sliceAsBytes(bytes)[0..byte_count];
    @memset(pixel_bytes, 0);
    const pixels: [*]ui.Color = @ptrCast(pixel_bytes.ptr);
    return pixels[0..pixel_count];
}

fn renderNativeAppFrame(runtime: *wasm.Runtime, app_memory: []u8, width: u32, height: u32, pixels: []ui.Color) Error!void {
    var rect_len = try exportUsize(runtime, "er_ui_packed_rect_buffer_len");
    var text_len = try exportUsize(runtime, "er_ui_packed_text_vertex_buffer_len");
    var icon_len = try exportUsize(runtime, "er_ui_packed_icon_vertex_buffer_len");
    var icon_line_len = try exportUsize(runtime, "er_ui_packed_icon_line_vertex_buffer_len");
    var image_len = try exportUsize(runtime, "er_ui_packed_image_vertex_buffer_len");
    var overlay_rect_len = try exportUsize(runtime, "er_ui_packed_overlay_rect_buffer_len");
    var overlay_text_len = try exportUsize(runtime, "er_ui_packed_overlay_text_vertex_buffer_len");
    var overlay_icon_len = try exportUsize(runtime, "er_ui_packed_overlay_icon_vertex_buffer_len");
    var overlay_icon_line_len = try exportUsize(runtime, "er_ui_packed_overlay_icon_line_vertex_buffer_len");

    const buffers = renderer_ir.Buffers{
        .rects = try exportedF32Slice(runtime, app_memory, "er_ui_packed_rect_buffer_ptr", rect_len),
        .rect_len = &rect_len,
        .text_vertices = try exportedF32Slice(runtime, app_memory, "er_ui_packed_text_vertex_buffer_ptr", text_len),
        .text_vertex_len = &text_len,
        .icon_vertices = try exportedF32Slice(runtime, app_memory, "er_ui_packed_icon_vertex_buffer_ptr", icon_len),
        .icon_vertex_len = &icon_len,
        .icon_line_vertices = try exportedF32Slice(runtime, app_memory, "er_ui_packed_icon_line_vertex_buffer_ptr", icon_line_len),
        .icon_line_vertex_len = &icon_line_len,
        .image_vertices = try exportedF32Slice(runtime, app_memory, "er_ui_packed_image_vertex_buffer_ptr", image_len),
        .image_vertex_len = &image_len,
        .overlay_rects = try exportedF32Slice(runtime, app_memory, "er_ui_packed_overlay_rect_buffer_ptr", overlay_rect_len),
        .overlay_rect_len = &overlay_rect_len,
        .overlay_text_vertices = try exportedF32Slice(runtime, app_memory, "er_ui_packed_overlay_text_vertex_buffer_ptr", overlay_text_len),
        .overlay_text_vertex_len = &overlay_text_len,
        .overlay_icon_vertices = try exportedF32Slice(runtime, app_memory, "er_ui_packed_overlay_icon_vertex_buffer_ptr", overlay_icon_len),
        .overlay_icon_vertex_len = &overlay_icon_len,
        .overlay_icon_line_vertices = try exportedF32Slice(runtime, app_memory, "er_ui_packed_overlay_icon_line_vertex_buffer_ptr", overlay_icon_line_len),
        .overlay_icon_line_vertex_len = &overlay_icon_line_len,
    };
    renderer_ir.validateBuffers(buffers) catch return error.AppIrInvalid;

    const font_width = try exportUsize(runtime, "er_ui_font_atlas_width");
    const font_height = try exportUsize(runtime, "er_ui_font_atlas_height");
    const font_len = std.math.mul(usize, font_width, font_height) catch return error.AppResourceInvalid;
    const font_alpha = try exportedBytes(runtime, app_memory, "er_ui_font_atlas_ptr", font_len);

    const image_width = try exportUsize(runtime, "er_ui_post_image_width");
    const image_height = try exportUsize(runtime, "er_ui_post_image_height");
    const image_len_bytes = try exportUsize(runtime, "er_ui_post_image_rgba_len");
    const image_bytes = try exportedBytes(runtime, app_memory, "er_ui_post_image_rgba_ptr", image_len_bytes);
    if (image_len_bytes % @sizeOf(ui.Color) != 0) return error.AppResourceInvalid;
    const image_pixels: [*]const ui.Color = @ptrCast(image_bytes.ptr);

    const surface = renderer_software.Framebuffer.init(width, height, pixels) catch return error.NativeRenderFailed;
    surface.clear(.bg);
    _ = surface.renderIr(buffers, .{
        .font = .{
            .width = font_width,
            .height = font_height,
            .alpha = font_alpha,
        },
        .image = .{
            .width = image_width,
            .height = image_height,
            .pixels = image_pixels[0 .. image_len_bytes / @sizeOf(ui.Color)],
        },
    }) catch return error.NativeRenderFailed;
}

fn exportedF32Slice(runtime: *wasm.Runtime, app_memory: []u8, ptr_export: []const u8, float_len: usize) Error![]f32 {
    const byte_len = std.math.mul(usize, float_len, @sizeOf(f32)) catch return error.AppIrInvalid;
    const bytes = try exportedBytes(runtime, app_memory, ptr_export, byte_len);
    if (@intFromPtr(bytes.ptr) % @alignOf(f32) != 0) return error.AppIrInvalid;
    const values: [*]f32 = @ptrCast(@alignCast(bytes.ptr));
    return values[0..float_len];
}

fn exportedBytes(runtime: *wasm.Runtime, app_memory: []u8, ptr_export: []const u8, byte_len: usize) Error![]u8 {
    const ptr = try exportUsize(runtime, ptr_export);
    if (ptr > app_memory.len or byte_len > app_memory.len - ptr) return error.AppIrInvalid;
    return app_memory[ptr .. ptr + byte_len];
}

fn exportUsize(runtime: *wasm.Runtime, export_name: []const u8) Error!usize {
    const value = try callI32(runtime, export_name);
    if (value < 0) return error.AppRuntimeBadResult;
    return @intCast(value);
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
    AppFrameBuildFailed,
    AppIrInvalid,
    AppResourceInvalid,
    AppRuntimeBadResult,
    BootServicesUnavailable,
    FramebufferBadFormat,
    FramebufferMissing,
    NativePixelAllocationFailed,
    NativeRenderFailed,
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
        error.AppFrameBuildFailed => printText("app-frame-build-failed"),
        error.AppIrInvalid => printText("app-ir-invalid"),
        error.AppResourceInvalid => printText("app-resource-invalid"),
        error.AppRuntimeBadResult => printText("app-runtime-bad-result"),
        error.BootServicesUnavailable => printText("boot-services-unavailable"),
        error.FramebufferBadFormat => printText("framebuffer-bad-format"),
        error.FramebufferMissing => printText("framebuffer-missing"),
        error.NativePixelAllocationFailed => printText("native-pixel-allocation-failed"),
        error.NativeRenderFailed => printText("native-render-failed"),
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
