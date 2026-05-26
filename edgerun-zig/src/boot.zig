pub const resource_map = @import("boot_resource_map.zig");
pub const pi_resource_map = @import("boot/pi_resource_map.zig");
pub const uefi_resource_map = @import("boot/uefi_resource_map.zig");

test {
    _ = resource_map;
    _ = pi_resource_map;
    _ = uefi_resource_map;
}
