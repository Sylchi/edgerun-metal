const renderer_ir = @import("../render/ir.zig");

pub const max_commands: usize = 4096;
pub const max_clips: usize = 64;
pub const max_interaction_regions: usize = 1024;
pub const max_rects: usize = 8192;
pub const max_text_vertices: usize = 24576;
pub const max_icon_vertices: usize = 4096;
pub const max_icon_line_vertices: usize = 65536;
pub const max_image_vertices: usize = 384;
pub const max_overlay_rects: usize = 512;
pub const max_overlay_text_vertices: usize = 8192;
pub const max_overlay_icon_vertices: usize = 256;
pub const max_overlay_icon_line_vertices: usize = 16384;

pub const IrStorage = renderer_ir.FixedBuffers(
    max_rects,
    max_text_vertices,
    max_icon_vertices,
    max_image_vertices,
    max_overlay_rects,
    max_overlay_text_vertices,
    max_overlay_icon_vertices,
    max_icon_line_vertices,
    max_overlay_icon_line_vertices,
);
