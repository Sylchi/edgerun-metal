const backend = @import("backends/gles.zig");
const renderer_font_atlas = @import("font_atlas.zig");
const renderer_ir = @import("ir.zig");
const ui = @import("../ui.zig");

pub const c = backend.c;
pub const Error = error{
    InvalidImageTexture,
    GlRendererUnavailable,
    SoftwareGlRendererRejected,
    InvalidFramebufferSize,
    BlankGpuFrame,
};
pub const RgbaTexture = backend.RgbaTexture;
pub const FrameProof = backend.FrameProof;

pub const Adapter = struct {
    state: backend.State,

    pub fn init(font_atlas: *renderer_font_atlas.Atlas, image: ?RgbaTexture) !Adapter {
        return .{ .state = try backend.init(font_atlas, image) };
    }

    pub fn deinit(self: *Adapter) void {
        backend.deinit(&self.state);
    }

    pub fn refreshFontTexture(self: Adapter, font_atlas: *const renderer_font_atlas.Atlas) void {
        backend.refreshFontTexture(self.state, font_atlas);
    }

    pub fn renderFrame(self: Adapter, width: i32, height: i32, buffers: renderer_ir.Buffers) !void {
        try backend.renderFrame(self.state, width, height, buffers);
    }

    pub fn renderFrameToViewport(self: Adapter, logical_width: i32, logical_height: i32, framebuffer_width: i32, framebuffer_height: i32, buffers: renderer_ir.Buffers) !void {
        try backend.renderFrameToViewport(self.state, logical_width, logical_height, framebuffer_width, framebuffer_height, buffers);
    }

    pub fn verifyFrameNonBlank(_: Adapter, width: i32, height: i32) !FrameProof {
        return backend.verifyFrameNonBlank(width, height);
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
