pub const app = @import("app.zig");
pub const assets = @import("assets.zig");
pub const compositor = @import("compositor.zig");
pub const hardware_inventory_app = @import("hardware_inventory_app.zig");
pub const icon = @import("icon.zig");
pub const input = @import("input.zig");
pub const painter = @import("painter.zig");
pub const renderer_gpu = @import("renderer_gpu.zig");
pub const renderer_software = @import("renderer_software.zig");
pub const renderer_surface = @import("renderer_surface.zig");
pub const component_gallery = @import("component_gallery.zig");
pub const ui = @import("ui.zig");
pub const ui_codec = @import("ui_codec.zig");
pub const ui_components = @import("ui_components.zig");
pub const ui_resolver = @import("ui_resolver.zig");
pub const varfont = @import("varfont.zig");

test {
    _ = app;
    _ = assets;
    _ = compositor;
    _ = hardware_inventory_app;
    _ = icon;
    _ = input;
    _ = painter;
    _ = renderer_gpu;
    _ = renderer_software;
    _ = renderer_surface;
    _ = component_gallery;
    _ = ui;
    _ = ui_codec;
    _ = ui_components;
    _ = ui_resolver;
    _ = varfont;
}
