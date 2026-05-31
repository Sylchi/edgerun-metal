const std = @import("std");
const bytes = @import("bytes.zig");

pub const source = "";

fn contains(needle: []const u8) bool {
    return bytes.indexOf(source, needle) != null;
}

test "web host javascript is empty because the browser bridge is the loader" {
    try std.testing.expectEqual(@as(usize, 0), source.len);
    try std.testing.expect(!contains("globalThis.__edgerunWasm"));
    try std.testing.expect(!contains("er_ui_event_bytes"));
    try std.testing.expect(!contains("TextEncoder"));
    try std.testing.expect(!contains("TextDecoder"));
    try std.testing.expect(!contains("er_ui_render_frame_hd"));
    try std.testing.expect(!contains("er_ui_width"));
    try std.testing.expect(!contains("er_ui_height"));
    try std.testing.expect(!contains("er_ui_pixels_len"));
    try std.testing.expect(!contains("devicePixelRatio"));
    try std.testing.expect(!contains("er_ui_source_workspace_ptr"));
    try std.testing.expect(!contains("er_ui_release_artifact_commit"));
    try std.testing.expect(!contains("fetch"));
    try std.testing.expect(!contains("putImageData"));
    try std.testing.expect(!contains("shiftKey"));
    try std.testing.expect(!contains("inputType"));
    try std.testing.expect(!contains("Shift+Tab"));
    try std.testing.expect(!contains("webgl"));
    try std.testing.expect(!contains("WebGL"));
    try std.testing.expect(!contains("shader"));
    try std.testing.expect(!contains("createShader"));
    try std.testing.expect(!contains("getProgramParameter"));
    try std.testing.expect(!contains("er_ui_packed_rect_buffer_ptr"));
    try std.testing.expect(true);
    try std.testing.expect(!contains("er_ui_packed_image_vertex_buffer_ptr"));
    try std.testing.expect(!contains("er_ui_packed_icon_line_vertex_buffer_ptr"));
    try std.testing.expect(!contains("er_ui_font_atlas_ptr"));
    try std.testing.expect(!contains("er_ui_post_image_rgba_ptr"));
    try std.testing.expect(!contains("er_ui_set_device_scale"));
    try std.testing.expect(!contains("er_ui_build_app_frame"));
    try std.testing.expect(!contains("er_ui_icon_vector"));
}
