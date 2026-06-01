const std = @import("er_std");
const renderer_gpu = @import("backends/gpu.zig");
const renderer_surface = @import("surface.zig");

pub const CpuFilledDevice = struct {
    began: usize = 0,
    uploaded: usize = 0,
    rendered: usize = 0,
    presented: usize = 0,
    last_sequence: u64 = 0,
    last_mode: renderer_surface.Mode = .{ .width = 1, .height = 1, .stride = 1, .refresh_hz = 1 },
    last_primitive_count: usize = 0,
    last_dirty_tile_count: usize = 0,

    pub fn device(self: *CpuFilledDevice) renderer_gpu.Device {
        return .{
            .context = self,
            .rasterization = .cpu_filled_gpu_buffer,
            .begin_frame = beginFrame,
            .upload_primitives = uploadPrimitives,
            .render_tiles = renderTiles,
            .present = present,
        };
    }

    fn beginFrame(context: *anyopaque, frame: renderer_gpu.Frame) bool {
        const self: *CpuFilledDevice = @ptrCast(@alignCast(context));
        if (frame.sequence == 0 or frame.primitives.len == 0 or frame.dirty_tiles.len == 0) return false;
        self.began += 1;
        self.last_mode = frame.mode;
        self.last_primitive_count = frame.primitives.len;
        self.last_dirty_tile_count = frame.dirty_tiles.len;
        return true;
    }

    fn uploadPrimitives(context: *anyopaque, primitives: []const renderer_gpu.Primitive) bool {
        const self: *CpuFilledDevice = @ptrCast(@alignCast(context));
        if (primitives.len == 0) return false;
        self.uploaded += primitives.len;
        return true;
    }

    fn renderTiles(context: *anyopaque, dirty_tiles: []const u32) bool {
        const self: *CpuFilledDevice = @ptrCast(@alignCast(context));
        if (dirty_tiles.len == 0) return false;
        self.rendered += dirty_tiles.len;
        return true;
    }

    fn present(context: *anyopaque, sequence: u64) bool {
        const self: *CpuFilledDevice = @ptrCast(@alignCast(context));
        if (sequence == 0) return false;
        self.presented += 1;
        self.last_sequence = sequence;
        return true;
    }
};

test "cpu filled gpu buffer device reports concrete rasterization origin" {
    var device_state = CpuFilledDevice{};
    const device = device_state.device();
    try std.testing.expectEqual(renderer_gpu.Rasterization.cpu_filled_gpu_buffer, device.rasterization);

    const primitive = renderer_gpu.Primitive{
        .kind = .rect,
        .bounds = .{ .x = 0, .y = 0, .w = 16, .h = 16 },
        .color = .accent,
    };
    const tile = [_]u32{0};
    const frame = renderer_gpu.Frame{
        .sequence = 1,
        .mode = .{ .width = 64, .height = 64, .stride = 64, .refresh_hz = 60 },
        .tile_plan = renderer_surface.tilePlanFromMode(.{ .width = 64, .height = 64, .stride = 64, .refresh_hz = 60 }, 16, 16, 16).?,
        .dirty_tiles = &tile,
        .primitives = &.{primitive},
    };

    try std.testing.expect(device.begin_frame(device.context, frame));
    try std.testing.expect(device.upload_primitives(device.context, frame.primitives));
    try std.testing.expect(device.render_tiles(device.context, frame.dirty_tiles));
    try std.testing.expect(device.present(device.context, frame.sequence));
    try std.testing.expectEqual(@as(usize, 1), device_state.began);
    try std.testing.expectEqual(@as(usize, 1), device_state.uploaded);
    try std.testing.expectEqual(@as(usize, 1), device_state.rendered);
    try std.testing.expectEqual(@as(usize, 1), device_state.presented);
    try std.testing.expectEqual(@as(u64, 1), device_state.last_sequence);
}
