const app = @import("app.zig");
pub const assets = @import("assets.zig");
pub const hardware_inventory_app = @import("hardware_inventory_app.zig");
pub const icon = @import("icon.zig");
pub const input = @import("input.zig");
pub const painter = @import("painter.zig");
pub const render = @import("render.zig");
pub const component_gallery = @import("component_gallery.zig");
pub const app_frame = @import("app_frame.zig");
pub const ui = @import("ui.zig");
pub const ui_codec = @import("ui_codec.zig");
const ui_component_tests = @import("ui/components/ComponentTests.zig");
pub const ui_resolver = @import("ui_resolver.zig");
pub const varfont = @import("varfont.zig");

test {
    _ = app;
    _ = assets;
    _ = hardware_inventory_app;
    _ = icon;
    _ = input;
    _ = painter;
    _ = render;
    _ = component_gallery;
    _ = ui;
    _ = ui_codec;
    _ = ui_component_tests;
    _ = ui_resolver;
    _ = varfont;
}
