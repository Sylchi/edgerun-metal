const std = @import("std");
const uefi = std.os.uefi;
const app_input_event = @import("app_input_event.zig");
const app_frame = @import("app_frame.zig");
const app_images = @import("app_images.zig");
const data_chunk = @import("content/data_chunk.zig");
const gop_framebuffer = @import("boot/gop_framebuffer.zig");
const input_i8042_keyboard = @import("input_i8042_keyboard.zig");
const interaction = @import("ui_interaction.zig");
const renderer_font_atlas = @import("render/font_atlas.zig");
const renderer_ir = @import("render/ir.zig");
const renderer_pipeline = @import("render/pipeline.zig");
const renderer_software = @import("render/software.zig");
const resource_contract = @import("content/resource_contract.zig");
const resource_inventory = @import("content/resource_inventory.zig");
const ui = @import("ui.zig");
const virtio_gpu = @import("virtio_gpu.zig");
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
const max_commands: usize = 4096;
const max_clips: usize = 64;
const max_interaction_regions: usize = 4096;
const max_rects: usize = 8192;
const max_text_vertices: usize = 24576;
const max_icon_vertices: usize = 4096;
const max_icon_line_vertices: usize = 65536;
const max_image_vertices: usize = 384;
const max_overlay_rects: usize = 512;
const max_overlay_text_vertices: usize = 8192;
const max_overlay_icon_vertices: usize = 256;
const max_overlay_icon_line_vertices: usize = 16384;
const input_contract_start_tick: u64 = 1;
const input_contract_end_tick: u64 = 100;
const input_contract_check_tick: u64 = 2;
const input_resource_offset: u64 = 0;
const input_resource_len: u64 = 1;
const app_runtime_event_error: u32 = 1 << 8;
const virtio_scanout_resource_id: u32 = 1;
const virtio_scanout_id: u32 = 0;

const IrStorage = renderer_ir.FixedBuffers(
    max_rects,
    max_text_vertices,
    max_icon_vertices,
    max_image_vertices,
    max_overlay_rects,
    max_overlay_text_vertices,
    max_overlay_icon_vertices,
    max_icon_line_vertices,
    max_overlay_icon_line_vertices,
);

var framebuffer: gop_framebuffer.Framebuffer = undefined;
var scene_state: SceneState = .{};
var font_atlas: renderer_font_atlas.Atlas = undefined;
var virtio_gpu_queue: virtio_gpu.QueueStorage = .{};
var wasm_storage: wasm.ExecutionStorage = .{};
var ticks: u64 = app_runtime_ticks;
var input_resource_slots: [1]resource_inventory.Resource = undefined;
var input_contract_slots: [1]resource_contract.Contract = undefined;
var native_keyboard_state: input_i8042_keyboard.State = .{};
var native_keyboard_event: [128]u8 = undefined;

const SceneState = struct {
    commands: [max_commands]ui.Command = undefined,
    clips: [max_clips]ui.Rect = undefined,
    regions: [max_interaction_regions]interaction.Region = undefined,
    ir_storage: IrStorage = .{},

    fn rebuild(self: *SceneState, width: u32, height: u32, atlas: *renderer_font_atlas.Atlas) Error!renderer_ir.Buffers {
        var scene = ui.Scene.initWithClips(&self.commands, &self.clips);
        var collector = interaction.Collector.init(&self.regions);
        app_frame.render(&scene, &collector, ui.Rect.init(0, 0, @floatFromInt(width), @floatFromInt(height)), .{
            .route = .{ .view = .landing },
            .public_identity = "blessed-native-renderer",
            .public_identity_ready = true,
        }) catch return error.AppFrameBuildFailed;
        const buffers = self.ir_storage.buffers();
        renderer_pipeline.packScene(buffers, atlas, .object, scene.written()) catch return error.AppIrInvalid;
        return buffers;
    }
};

pub fn main() noreturn {
    printLine("EdgeRun app-runtime virtio-gpu smoke");
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
    framebuffer = gop_framebuffer.collect(boot_services) catch .{};
    if (framebuffer.valid()) {
        framebuffer.drawDebugScreen(.pre_exit);
        printLine("check: gop fallback framebuffer ok");
    } else {
        printLine("check: gop fallback unavailable");
    }

    const app_memory = try allocateAppRuntimeMemory(boot_services);
    var runtime = wasm.Runtime.initWithMemoryPages(app_memory, &ticks, app_runtime_pages);
    _ = call(&runtime, "er_ui_boot", &.{}) catch |err| return mapWasmError(err);
    printLine("check: app-runtime boot ok");
    try installNativeKeyboardAndDeliverInput(&runtime, app_memory);
    printLine("check: native keyboard input delivered to wasm app");

    const width = @min(framebuffer.width, max_boot_width);
    const height = @min(framebuffer.height, max_boot_height);
    const native_pixels = try allocateNativePixels(boot_services, width, height);
    printLine("check: blessed native app renderer start");
    try renderBlessedNativeApp(width, height, native_pixels);
    printLine("check: blessed native app renderer ok");

    const scanout = try allocateVirtioScanout(boot_services, width, height);
    packBgrxScanout(scanout, native_pixels);
    try presentVirtioGpu(width, height, scanout);
    printLine("check: blessed native pixels flushed to virtio-gpu");

    if (framebuffer.valid()) {
        framebuffer.blitUiColorBytes(width, height, std.mem.sliceAsBytes(native_pixels));
        printLine("check: blessed native pixels copied to gop fallback");
    }
    printLine("PASS immutable-kernel-app-runtime-qemu");
}

fn allocateAppRuntimeMemory(boot_services: *uefi.tables.BootServices) Error![]u8 {
    const app_pages = boot_services.allocatePages(.any, .loader_data, app_runtime_uefi_pages) catch return error.AppMemoryAllocationFailed;
    const app_memory = std.mem.sliceAsBytes(app_pages);
    @memset(app_memory, 0);
    return app_memory;
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

fn allocateVirtioScanout(boot_services: *uefi.tables.BootServices, width: u32, height: u32) Error![]u8 {
    const pixel_count = std.math.mul(usize, width, height) catch return error.VirtioScanoutAllocationFailed;
    const byte_count = std.math.mul(usize, pixel_count, 4) catch return error.VirtioScanoutAllocationFailed;
    const pages = (byte_count + uefi_page_bytes - 1) / uefi_page_bytes;
    const bytes = boot_services.allocatePages(.any, .loader_data, pages) catch return error.VirtioScanoutAllocationFailed;
    const scanout = std.mem.sliceAsBytes(bytes)[0..byte_count];
    @memset(scanout, 0);
    return scanout;
}

fn installNativeKeyboardAndDeliverInput(runtime: *wasm.Runtime, app_memory: []u8) Error!void {
    const app = chunk("qemu-input-router-app");
    const resource = resource_inventory.Resource.init(
        chunk(input_i8042_keyboard.resource_id),
        .input,
        resource_contract.Bounds.init(input_resource_offset, input_resource_len),
    );
    var inventory = resource_inventory.Inventory.init(&input_resource_slots);
    inventory.add(resource) catch return error.NativeKeyboardInventoryFailed;
    var schedule = resource_contract.Schedule.init(&input_contract_slots);
    const contract = resource_contract.Contract.init(
        chunk("qemu-framework13-keyboard-input"),
        app,
        resource.id,
        .input,
        input_contract_start_tick,
        input_contract_end_tick,
        resource_contract.Bounds.init(input_resource_offset, input_resource_len),
        resource_contract.Pattern.exclusive(),
    );
    schedule.installChecked(inventory, contract) catch return error.NativeKeyboardContractFailed;
    const owner = schedule.ownerAt(resource.id, input_contract_check_tick) orelse return error.NativeKeyboardOwnerMissing;
    if (!sameChunk(owner, app)) return error.NativeKeyboardOwnerMismatch;

    native_keyboard_state.reset();
    const event_len = native_keyboard_state.pushByte(0x1e, &native_keyboard_event) catch return error.NativeKeyboardDecodeFailed;
    if (event_len == 0) return error.NativeKeyboardDecodeFailed;
    const record = app_input_event.parseBytes(native_keyboard_event[0..event_len]) catch return error.NativeKeyboardDecodeFailed;
    if (record.kind != .key_down or !std.mem.eql(u8, record.key, "a") or !std.mem.eql(u8, record.code, "KeyA")) return error.NativeKeyboardDecodeFailed;

    const input_ptr = try exportUsize(runtime, "er_ui_input_ptr");
    const input_capacity = try exportUsize(runtime, "er_ui_input_capacity");
    if (input_ptr > app_memory.len or input_capacity > app_memory.len - input_ptr) return error.AppInputBufferInvalid;
    if (event_len > input_capacity) return error.AppInputBufferInvalid;
    @memcpy(app_memory[input_ptr..][0..event_len], native_keyboard_event[0..event_len]);
    const result = call(runtime, "er_ui_event_bytes", &.{
        .{ .i32 = @intCast(event_len) },
        .{ .f32 = @floatFromInt(max_boot_width) },
        .{ .f32 = @floatFromInt(max_boot_height) },
        .{ .f32 = 0.0 },
    }) catch |err| return mapWasmError(err);
    const event_result: u32 = @bitCast(try resultI32(result));
    if ((event_result & app_runtime_event_error) != 0) return error.AppInputRejected;
}

fn renderBlessedNativeApp(width: u32, height: u32, pixels: []ui.Color) Error!void {
    font_atlas.initWithFontInPlace(renderer_font_atlas.geist_ascii_font.body());
    const buffers = try scene_state.rebuild(width, height, &font_atlas);
    const image_texture = app_images.cloudMeme() catch return error.AppResourceInvalid;
    const surface = renderer_software.Framebuffer.init(width, height, pixels) catch return error.NativeRenderFailed;
    _ = renderer_pipeline.renderSoftwareFrame(surface, buffers, renderer_pipeline.softwareResources(&font_atlas, image_texture), .bg) catch return error.NativeRenderFailed;
}

fn packBgrxScanout(out: []u8, pixels: []const ui.Color) void {
    var index: usize = 0;
    while (index < pixels.len and index * 4 + 3 < out.len) : (index += 1) {
        const color = pixels[index];
        const byte_index = index * 4;
        out[byte_index + 0] = color.b;
        out[byte_index + 1] = color.g;
        out[byte_index + 2] = color.r;
        out[byte_index + 3] = 0xff;
    }
}

fn presentVirtioGpu(width: u32, height: u32, scanout: []u8) Error!void {
    if (scanout.len > std.math.maxInt(u32)) return error.VirtioScanoutTooLarge;
    var device = virtio_gpu.Device.findAndInit(&virtio_gpu_queue) catch |err| return mapVirtioGpuError(err);
    const setup = virtio_gpu.Setup2d.init(
        virtio_scanout_resource_id,
        virtio_scanout_id,
        width,
        height,
        @intFromPtr(scanout.ptr),
        @intCast(scanout.len),
    );
    device.setup2d(&virtio_gpu_queue, setup) catch |err| return mapVirtioGpuError(err);
    device.flush2d(&virtio_gpu_queue, virtio_scanout_resource_id, width, height) catch |err| return mapVirtioGpuError(err);
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
    if (@intFromPtr(image_bytes.ptr) % @alignOf(ui.Color) != 0) return error.AppResourceInvalid;
    const image_pixels: [*]const ui.Color = @ptrCast(@alignCast(image_bytes.ptr));

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
    AppInputBufferInvalid,
    AppInputRejected,
    NativeKeyboardContractFailed,
    NativeKeyboardDecodeFailed,
    NativeKeyboardInventoryFailed,
    NativeKeyboardOwnerMismatch,
    NativeKeyboardOwnerMissing,
    VirtioGpuDeviceNotFound,
    VirtioGpuInvalidResponse,
    VirtioGpuQueueFailed,
    VirtioGpuTimeout,
    VirtioGpuUnsupported,
    VirtioScanoutAllocationFailed,
    VirtioScanoutTooLarge,
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

fn mapVirtioGpuError(err: virtio_gpu.Error) Error {
    return switch (err) {
        error.DeviceNotFound => error.VirtioGpuDeviceNotFound,
        error.DeviceTimeout => error.VirtioGpuTimeout,
        error.InvalidResponse => error.VirtioGpuInvalidResponse,
        error.FeatureNegotiationFailed,
        error.InvalidBar,
        error.MissingCapability,
        error.MissingTransport,
        error.QueueSetupFailed,
        error.QueueTooSmall,
        => error.VirtioGpuQueueFailed,
        error.UnsupportedDevice => error.VirtioGpuUnsupported,
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
        error.AppInputBufferInvalid => printText("app-input-buffer-invalid"),
        error.AppInputRejected => printText("app-input-rejected"),
        error.NativeKeyboardContractFailed => printText("native-keyboard-contract-failed"),
        error.NativeKeyboardDecodeFailed => printText("native-keyboard-decode-failed"),
        error.NativeKeyboardInventoryFailed => printText("native-keyboard-inventory-failed"),
        error.NativeKeyboardOwnerMismatch => printText("native-keyboard-owner-mismatch"),
        error.NativeKeyboardOwnerMissing => printText("native-keyboard-owner-missing"),
        error.VirtioGpuDeviceNotFound => printText("virtio-gpu-device-not-found"),
        error.VirtioGpuInvalidResponse => printText("virtio-gpu-invalid-response"),
        error.VirtioGpuQueueFailed => printText("virtio-gpu-queue-failed"),
        error.VirtioGpuTimeout => printText("virtio-gpu-timeout"),
        error.VirtioGpuUnsupported => printText("virtio-gpu-unsupported"),
        error.VirtioScanoutAllocationFailed => printText("virtio-scanout-allocation-failed"),
        error.VirtioScanoutTooLarge => printText("virtio-scanout-too-large"),
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

fn chunk(value: []const u8) data_chunk.DataChunk {
    return data_chunk.DataChunk.init(value);
}

fn sameChunk(left: data_chunk.DataChunk, right: data_chunk.DataChunk) bool {
    return left.valid() and right.valid() and std.mem.eql(u8, left.body(), right.body());
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
