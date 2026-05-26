const backend = @import("backends/gpu.zig");
const renderer_ir = @import("ir.zig");
const renderer_present = @import("present.zig");
const renderer_surface = @import("surface.zig");

pub const Error = backend.Error;
pub const Rasterization = backend.Rasterization;
pub const SurfaceFormat = backend.SurfaceFormat;
pub const BufferKind = backend.BufferKind;
pub const SurfaceBuffer = backend.SurfaceBuffer;
pub const Surface = backend.Surface;
pub const Primitive = backend.Primitive;
pub const Frame = backend.Frame;
pub const Receipt = backend.Receipt;
pub const Device = backend.Device;

pub const Workspace = struct {
    primitives: []Primitive,
    tile_marks: []u8,
    dirty_ids: []u32,
};

pub fn renderIr(
    device: Device,
    mode: renderer_surface.Mode,
    tile_width: u32,
    tile_height: u32,
    surfaces: []const Surface,
    buffers: renderer_ir.Buffers,
    resources: renderer_present.Resources,
    workspace: Workspace,
) Error!Receipt {
    var renderer = try backend.Renderer.init(
        device,
        mode,
        tile_width,
        tile_height,
        workspace.primitives,
        workspace.tile_marks,
        workspace.dirty_ids,
    );
    return renderer.renderIrWithResources(surfaces, buffers, resources);
}

pub fn available(mode: renderer_surface.Mode) bool {
    return backend.available(mode);
}

test {
    _ = backend;
}
