const std = @import("std");
const backend = @import("backends/gles.zig");
const renderer_font_atlas = @import("font_atlas.zig");
const renderer_ir = @import("ir.zig");
const renderer_present = @import("present.zig");
const ui = @import("../ui.zig");

pub const c = backend.c;
pub const Error = error{
    InvalidImageTexture,
    GlRendererUnavailable,
    SoftwareGlRendererRejected,
    InvalidFramebufferSize,
    BlankGpuFrame,
    GlFramebufferIncomplete,
};
pub const RgbaTexture = backend.RgbaTexture;
pub const FrameProof = backend.FrameProof;
pub const Receipt = renderer_present.Receipt;

pub const Adapter = struct {
    state: backend.State,
    image_texture_ready: bool,

    pub fn init(font_atlas: *renderer_font_atlas.Atlas, image: ?RgbaTexture) !Adapter {
        return .{ .state = try backend.init(font_atlas, image), .image_texture_ready = image != null };
    }

    pub fn deinit(self: *Adapter) void {
        backend.deinit(&self.state);
    }

    pub fn refreshFontTexture(self: Adapter, font_atlas: *const renderer_font_atlas.Atlas) void {
        backend.refreshFontTexture(self.state, font_atlas);
    }

    pub fn renderFrame(self: Adapter, width: i32, height: i32, buffers: renderer_ir.Buffers) !Receipt {
        const receipt = try self.receiptForFrame(width, height, buffers);
        try backend.renderFrame(self.state, width, height, buffers);
        return receipt;
    }

    pub fn renderFrameToViewport(self: Adapter, logical_width: i32, logical_height: i32, framebuffer_width: i32, framebuffer_height: i32, buffers: renderer_ir.Buffers) !Receipt {
        const receipt = try self.receiptForFrame(logical_width, logical_height, buffers);
        try backend.renderFrameToViewport(self.state, logical_width, logical_height, framebuffer_width, framebuffer_height, buffers);
        return receipt;
    }

    pub fn verifyFrameNonBlank(_: Adapter, width: i32, height: i32) !FrameProof {
        return backend.verifyFrameNonBlank(width, height);
    }

    pub fn readFramePixels(_: Adapter, width: i32, height: i32, out: []ui.Color) !void {
        try backend.readFramePixels(width, height, out);
    }

    pub fn renderFrameToRgbaPixels(self: Adapter, width: i32, height: i32, buffers: renderer_ir.Buffers, out: []ui.Color) !Receipt {
        const receipt = try self.receiptForFrame(width, height, buffers);
        try backend.renderFrameToRgbaPixels(self.state, width, height, buffers, out);
        return receipt;
    }

    fn receiptForFrame(self: Adapter, width: i32, height: i32, buffers: renderer_ir.Buffers) renderer_present.Error!Receipt {
        if (width <= 0 or height <= 0) return error.InvalidTarget;
        return renderer_present.present(.{
            .target = .{
                .destination = .command_frame,
                .width = @intCast(width),
                .height = @intCast(height),
            },
            .buffers = buffers,
            .resources = .{
                .font_atlas = true,
                .image_texture = self.image_texture_ready,
            },
        });
    }
};

pub fn requireHardwareGl() !void {
    try backend.requireHardwareGl();
}

pub fn isSoftwareRenderer(renderer: []const u8) bool {
    return backend.isSoftwareRenderer(renderer);
}

test {
    _ = ui;
    _ = backend;
}

test "gles adapter records canonical presentation receipt for ir frame" {
    var storage = renderer_ir.FixedBuffers(1, 0, 0, 0, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    try renderer_ir.pushRect(buffers, .base, ui.Rect.init(0, 0, 8, 8), .accent, .clear, 0, 0, 0);
    const adapter = Adapter{
        .state = undefined,
        .image_texture_ready = false,
    };
    const receipt = try adapter.receiptForFrame(8, 8, buffers);
    try std.testing.expectEqual(renderer_present.Transport.command_stream, receipt.transport);
    try std.testing.expectEqual(renderer_present.Destination.command_frame, receipt.destination);
    try std.testing.expect(receipt.valid());
}

test "gles host callers retain presentation receipts" {
    try expectSourceContains(@embedFile("../wayland_egl_host.zig"), "const receipt = try gl.renderFrameToViewport(");
    try expectSourceContains(@embedFile("../wayland_egl_host.zig"), "if (!receipt.valid()) return error.InvalidGlesReceipt;");
    try expectSourceContains(@embedFile("../drm_gbm_host.zig"), "const receipt = try gl.renderFrame(");
    try expectSourceContains(@embedFile("../drm_gbm_host.zig"), "if (!receipt.valid()) return error.InvalidGlesReceipt;");
}

fn expectSourceContains(source: []const u8, needle: []const u8) !void {
    try std.testing.expect(std.mem.indexOf(u8, source, needle) != null);
}
