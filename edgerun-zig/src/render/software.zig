const std = @import("std");
const backend = @import("backends/software.zig");
const renderer_ir = @import("ir.zig");
const renderer_present = @import("present.zig");
const ui = @import("../ui.zig");

pub const Error = backend.Error;
pub const TuningError = backend.TuningError;
pub const IconTuning = backend.IconTuning;
pub const default_icon_tuning = backend.default_icon_tuning;
pub const AlphaAtlas = backend.AlphaAtlas;
pub const RgbaTexture = backend.RgbaTexture;
pub const Resources = backend.IrResources;

pub const Framebuffer = struct {
    width: usize,
    height: usize,
    pixels: []ui.Color,

    pub fn init(width: usize, height: usize, pixels: []ui.Color) Error!Framebuffer {
        const surface = try backend.Surface.init(width, height, pixels);
        return .{
            .width = surface.width,
            .height = surface.height,
            .pixels = surface.pixels,
        };
    }

    pub fn clear(self: Framebuffer, color: ui.Color) void {
        (backend.Surface{ .width = self.width, .height = self.height, .pixels = self.pixels }).clear(color);
    }

    pub fn renderIr(self: Framebuffer, buffers: renderer_ir.Buffers, resources: Resources) Error!renderer_present.Receipt {
        return (backend.Surface{ .width = self.width, .height = self.height, .pixels = self.pixels }).renderIrFrameWithResources(buffers, resources);
    }

    pub fn blendPixel(self: Framebuffer, x: usize, y: usize, color: ui.Color, alpha: u8) void {
        (backend.Surface{ .width = self.width, .height = self.height, .pixels = self.pixels }).blendPixel(x, y, color, alpha);
    }
};

pub fn setIconTuningForTest(tuning: IconTuning) TuningError!void {
    try backend.setIconTuningForTest(tuning);
}

pub fn resetIconTuningForTest() void {
    backend.resetIconTuningForTest();
}

test {
    _ = backend;
}

test "software adapter exposes only receipt based ir rendering" {
    const source = @embedFile("software.zig");
    const void_raster = "pub fn " ++ "rasterizeIr(";
    try std.testing.expect(std.mem.indexOf(u8, source, void_raster) == null);
    try std.testing.expect(std.mem.indexOf(u8, source, "pub fn renderIr(") != null);
}
