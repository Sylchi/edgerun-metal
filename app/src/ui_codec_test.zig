const codec = @import("ui/codec.zig");
const device_tree = @import("ui/device_tree.zig");
const wayland_options = @import("wayland/options.zig");

comptime {
    _ = codec;
    _ = device_tree;
    _ = wayland_options;
}
