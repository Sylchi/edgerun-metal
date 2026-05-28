const std = @import("std");
const uefi = std.os.uefi;
const app_frame = @import("app_frame.zig");
const app_images = @import("app_images.zig");
const gop_framebuffer = @import("boot/gop_framebuffer.zig");
const interaction = @import("ui_interaction.zig");
const renderer_font_atlas = @import("render/font_atlas_weighted.zig");
const renderer_ir = @import("render/ir.zig");
const renderer_pipeline = @import("render/pipeline.zig");
const renderer_software = @import("render/software.zig");
const ui = @import("ui.zig");
const virtio_gpu = @import("virtio_gpu.zig");

const debugcon_port: u16 = 0x402;
const line_max: usize = 192;
const uefi_page_bytes: usize = 4096;
// Keep the first full-app UEFI frame deliberately small: QEMU/OVMF runs the
// software renderer slowly, while virtio-gpu scanout is already proven.
const max_boot_width: u32 = 320;
const max_boot_height: u32 = 180;
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

    fn rebuildBootPanel(self: *SceneState, width: u32, height: u32) Error!renderer_ir.Buffers {
        var scene = ui.Scene.initWithClips(&self.commands, &self.clips);
        const w: f32 = @floatFromInt(width);
        const h: f32 = @floatFromInt(height);
        try scene.pushRect(ui.Rect.init(0, 0, w, h), ui.Color.bg, .fill, 0.0, 0.0);

        const margin: f32 = 28.0;
        const panel = ui.Rect.init(margin, margin, @max(1.0, w - margin * 2.0), @max(1.0, h - margin * 2.0));
        try scene.pushRect(panel, .{ .r = 18, .g = 26, .b = 38 }, .fill, 18.0, 0.0);
        try scene.pushRect(panel, .{ .r = 71, .g = 91, .b = 120 }, .border, 18.0, 0.0);

        const top = ui.Rect.init(panel.x + 20.0, panel.y + 20.0, @max(1.0, panel.w - 40.0), 16.0);
        try scene.pushRect(top, .{ .r = 34, .g = 211, .b = 238 }, .fill, 8.0, 0.0);
        try scene.pushRect(ui.Rect.init(top.x, top.y + 30.0, top.w * 0.62, 18.0), .{ .r = 232, .g = 238, .b = 247 }, .fill, 6.0, 0.0);
        try scene.pushRect(ui.Rect.init(top.x, top.y + 58.0, top.w * 0.78, 12.0), .{ .r = 148, .g = 163, .b = 184 }, .fill, 6.0, 0.0);
        try scene.pushRect(ui.Rect.init(top.x, top.y + 80.0, top.w * 0.52, 12.0), .{ .r = 148, .g = 163, .b = 184 }, .fill, 6.0, 0.0);

        const card_y = panel.y + 140.0;
        const gap: f32 = 16.0;
        const card_w = @max(1.0, (panel.w - 40.0 - gap * 2.0) / 3.0);
        var card_index: u32 = 0;
        while (card_index < 3) : (card_index += 1) {
            const x = panel.x + 20.0 + (@as(f32, @floatFromInt(card_index)) * (card_w + gap));
            const card = ui.Rect.init(x, card_y, card_w, 96.0);
            try scene.pushRect(card, .{ .r = 35, .g = 44, .b = 58 }, .fill, 10.0, 0.0);
            try scene.pushRect(card, .{ .r = 80, .g = 96, .b = 118 }, .border, 10.0, 0.0);
            try scene.pushRect(ui.Rect.init(card.x + 14.0, card.y + 16.0, card.w * 0.52, 12.0), .{ .r = 232, .g = 238, .b = 247 }, .fill, 6.0, 0.0);
            try scene.pushRect(ui.Rect.init(card.x + 14.0, card.y + 42.0, card.w - 28.0, 10.0), .{ .r = 148, .g = 163, .b = 184 }, .fill, 5.0, 0.0);
            try scene.pushRect(ui.Rect.init(card.x + 14.0, card.y + 62.0, (card.w - 28.0) * (0.42 + @as(f32, @floatFromInt(card_index)) * 0.16), 10.0), .{ .r = 91, .g = 219, .b = 134 }, .fill, 5.0, 0.0);
        }

        const rail_y = @max(panel.y + panel.h - 54.0, panel.y + 250.0);
        try scene.pushRect(ui.Rect.init(panel.x + 20.0, rail_y, panel.w - 40.0, 10.0), .{ .r = 80, .g = 96, .b = 118 }, .fill, 5.0, 0.0);
        try scene.pushRect(ui.Rect.init(panel.x + 20.0, rail_y, (panel.w - 40.0) * 0.72, 10.0), .{ .r = 34, .g = 211, .b = 238 }, .fill, 5.0, 0.0);

        const buffers = self.ir_storage.buffers();
        renderer_pipeline.packScene(buffers, &font_atlas, .atlas, scene.written()) catch return error.AppIrInvalid;
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
    framebuffer = gop_framebuffer.collect(boot_services) catch emptyFramebuffer();
    if (framebuffer.valid()) {
        framebuffer.drawDebugScreen(.pre_exit);
        printLine("check: gop fallback framebuffer ok");
    } else {
        printLine("check: gop fallback unavailable");
    }

    const width = if (framebuffer.valid()) @min(framebuffer.width, max_boot_width) else max_boot_width;
    const height = if (framebuffer.valid()) @min(framebuffer.height, max_boot_height) else max_boot_height;
    const native_pixels = try allocateNativePixels(boot_services, width, height);
    printLine("check: blessed native app renderer start");
    try renderBlessedNativeApp(width, height, native_pixels);
    printLine("check: blessed native app renderer ok");

    const scanout = try allocateVirtioScanout(boot_services, width, height);
    packBgrxScanout(scanout, native_pixels);
    try presentVirtioGpu(width, height, scanout);
    writeDebugconLine("check: blessed native pixels flushed to virtio-gpu");

    if (framebuffer.valid()) {
        framebuffer.blitUiColorBytes(width, height, std.mem.sliceAsBytes(native_pixels));
        writeDebugconLine("check: blessed native pixels copied to gop fallback");
    }
    writeDebugconLine("PASS immutable-kernel-app-runtime-qemu");
}

fn emptyFramebuffer() gop_framebuffer.Framebuffer {
    return .{
        .physical_base = 0,
        .byte_len = 0,
        .width = 0,
        .height = 0,
        .pixels_per_scan_line = 0,
        .format = .rgbx8888,
    };
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

fn renderBlessedNativeApp(width: u32, height: u32, pixels: []ui.Color) Error!void {
    writeDebugconLine("diag: font atlas init start");
    font_atlas.initUtf8();
    writeDebugconLine("diag: font atlas init ok");

    writeDebugconLine("diag: app frame pack start");
    const buffers = try scene_state.rebuild(width, height, &font_atlas);
    writeDebugconLine("diag: app frame pack ok");

    writeDebugconLine("diag: app image decode start");
    const image_texture = app_images.cloudMeme() catch return error.AppResourceInvalid;
    writeDebugconLine("diag: app image decode ok");

    writeDebugconLine("diag: software render start");
    const surface = renderer_software.Framebuffer.init(width, height, pixels) catch return error.NativeRenderFailed;
    try renderDiagnosticBatch(surface, buffers, image_texture, .rects);
    try renderDiagnosticBatch(surface, buffers, image_texture, .text);
    try renderDiagnosticBatch(surface, buffers, image_texture, .icons);
    _ = renderer_pipeline.renderSoftwareFrame(surface, buffers, renderer_pipeline.softwareResources(&font_atlas, image_texture), .bg) catch return error.NativeRenderFailed;
    writeDebugconLine("diag: software render ok");
}

const DiagnosticBatch = enum { rects, text, icons };

fn renderDiagnosticBatch(
    surface: renderer_software.Framebuffer,
    buffers: renderer_ir.Buffers,
    image_texture: renderer_software.RgbaTexture,
    batch: DiagnosticBatch,
) Error!void {
    const text_len = buffers.text_vertex_len.*;
    const icon_len = buffers.icon_vertex_len.*;
    const icon_line_len = buffers.icon_line_vertex_len.*;
    const image_len = buffers.image_vertex_len.*;
    const overlay_rect_len = buffers.overlay_rect_len.*;
    const overlay_text_len = buffers.overlay_text_vertex_len.*;
    const overlay_icon_len = buffers.overlay_icon_vertex_len.*;
    const overlay_icon_line_len = buffers.overlay_icon_line_vertex_len.*;

    buffers.text_vertex_len.* = if (batch == .text or batch == .icons) text_len else 0;
    buffers.icon_vertex_len.* = if (batch == .icons) icon_len else 0;
    buffers.icon_line_vertex_len.* = if (batch == .icons) icon_line_len else 0;
    buffers.image_vertex_len.* = if (batch == .icons) image_len else 0;
    buffers.overlay_rect_len.* = if (batch == .icons) overlay_rect_len else 0;
    buffers.overlay_text_vertex_len.* = if (batch == .icons) overlay_text_len else 0;
    buffers.overlay_icon_vertex_len.* = if (batch == .icons) overlay_icon_len else 0;
    buffers.overlay_icon_line_vertex_len.* = if (batch == .icons) overlay_icon_line_len else 0;

    switch (batch) {
        .rects => writeDebugconLine("diag: software rect batch start"),
        .text => writeDebugconLine("diag: software text batch start"),
        .icons => writeDebugconLine("diag: software icon batch start"),
    }
    _ = renderer_pipeline.renderSoftwareFrame(surface, buffers, renderer_pipeline.softwareResources(&font_atlas, image_texture), .bg) catch return error.NativeRenderFailed;
    switch (batch) {
        .rects => writeDebugconLine("diag: software rect batch ok"),
        .text => writeDebugconLine("diag: software text batch ok"),
        .icons => writeDebugconLine("diag: software icon batch ok"),
    }

    buffers.text_vertex_len.* = text_len;
    buffers.icon_vertex_len.* = icon_len;
    buffers.icon_line_vertex_len.* = icon_line_len;
    buffers.image_vertex_len.* = image_len;
    buffers.overlay_rect_len.* = overlay_rect_len;
    buffers.overlay_text_vertex_len.* = overlay_text_len;
    buffers.overlay_icon_vertex_len.* = overlay_icon_len;
    buffers.overlay_icon_line_vertex_len.* = overlay_icon_line_len;
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
    if (scanout.len > ~@as(u32, 0)) return error.VirtioScanoutTooLarge;
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

const Error = error{
    AppFrameBuildFailed,
    AppIrInvalid,
    AppResourceInvalid,
    BootServicesUnavailable,
    ClipBudgetExceeded,
    CommandBudgetExceeded,
    FramebufferBadFormat,
    FramebufferMissing,
    InvalidBounds,
    NativePixelAllocationFailed,
    NativeRenderFailed,
    UnsupportedComponent,
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
        error.UnsupportedPackedFrame => error.VirtioGpuUnsupported,
    };
}

fn printError(err: Error) void {
    switch (err) {
        error.AppFrameBuildFailed => printText("app-frame-build-failed"),
        error.AppIrInvalid => printText("app-ir-invalid"),
        error.AppResourceInvalid => printText("app-resource-invalid"),
        error.BootServicesUnavailable => printText("boot-services-unavailable"),
        error.ClipBudgetExceeded => printText("clip-budget-exceeded"),
        error.CommandBudgetExceeded => printText("command-budget-exceeded"),
        error.FramebufferBadFormat => printText("framebuffer-bad-format"),
        error.FramebufferMissing => printText("framebuffer-missing"),
        error.InvalidBounds => printText("invalid-bounds"),
        error.NativePixelAllocationFailed => printText("native-pixel-allocation-failed"),
        error.NativeRenderFailed => printText("native-render-failed"),
        error.UnsupportedComponent => printText("unsupported-component"),
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

fn writeDebugconLine(message: []const u8) void {
    writeDebugcon(message);
    writeDebugcon("\r\n");
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
