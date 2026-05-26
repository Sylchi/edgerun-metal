pub const resource_map = @import("boot_resource_map.zig");
pub const gop_framebuffer = @import("boot/gop_framebuffer.zig");
pub const pi_resource_map = @import("boot/pi_resource_map.zig");
pub const uefi_resource_map = @import("boot/uefi_resource_map.zig");
pub const virtio = @import("virtio.zig");
pub const virtio_gpu = @import("virtio_gpu.zig");

test {
    _ = resource_map;
    _ = gop_framebuffer;
    _ = pi_resource_map;
    _ = uefi_resource_map;
    _ = virtio;
    _ = virtio_gpu;
}
