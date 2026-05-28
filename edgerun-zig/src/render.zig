pub const compositor = @import("render/compositor.zig");
pub const font_atlas = @import("render/font_atlas_weighted.zig");
pub const gpu = @import("render/gpu.zig");
pub const gpu_buffer = @import("render/gpu_buffer.zig");
pub const gl_contract = @import("render/gl_contract.zig");
pub const icon_line_buffer = @import("render/icon_line_buffer.zig");
pub const icon_mask = @import("render/icon_mask.zig");
pub const ir = @import("render/ir.zig");
pub const native_present = @import("render/native_present.zig");
pub const parity = @import("render/parity.zig");
pub const pipeline = @import("render/pipeline.zig");
pub const present = @import("render/present.zig");
pub const software = @import("render/software.zig");
pub const surface = @import("render/surface.zig");

test {
    _ = compositor;
    _ = font_atlas;
    _ = gpu;
    _ = gpu_buffer;
    _ = gl_contract;
    _ = icon_line_buffer;
    _ = icon_mask;
    _ = ir;
    _ = native_present;
    _ = parity;
    _ = pipeline;
    _ = present;
    _ = software;
    _ = surface;
}
