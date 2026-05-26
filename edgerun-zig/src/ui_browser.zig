const std = @import("std");
const bytes = @import("bytes.zig");
const browser_runtime_js = @import("browser_runtime_js.zig");
const clock = @import("clock.zig");
const source_object = @import("embedded_source_object").bytes;
const compiler_wasm = @import("embedded_wasm_compiler").bytes;
const icon = @import("icon.zig");
const identity = @import("identity.zig");
const interaction = @import("ui_interaction.zig");
const object = @import("object.zig");
const renderer_pipeline = @import("render/pipeline.zig");
const component_gallery = @import("component_gallery.zig");
const site_apps = @import("site_apps.zig");
const site_blog = @import("site_blog.zig");
const site_chrome = @import("site_chrome.zig");
const site_cursor = @import("site_cursor.zig");
const site_docs = @import("site_docs.zig");
const site_frame = @import("site_frame.zig");
const site_images = @import("site_images.zig");
const site_landing = @import("site_landing.zig");
const site_navigation = @import("site_navigation.zig");
const site_source = @import("site_source.zig");
const ui = @import("ui.zig");
const ui_codec = @import("ui_codec.zig");
const ui_components = @import("ui_components.zig");
const vfs = @import("vfs.zig");
const ui_runtime = @import("ui_runtime.zig");
const varfont = @import("varfont.zig");
const wasm_interpreter = @import("wasm/root.zig");

const max_width: usize = 4096;
const max_height: usize = 2880;
const max_pixels: usize = max_width * max_height;
const max_input_bytes: usize = 8192;
const max_source_workspace_bytes: usize = 32 * 1024 * 1024;
const max_release_artifact_bytes: usize = 64 * 1024 * 1024;
const compiler_memory_offset_bytes: usize = 16 * 1024 * 1024;
const compiler_work_memory_bytes: usize = 288 * 1024 * 1024;
const compiler_source_gap_bytes: usize = 64 * 1024;
const max_compiler_runtime_bytes: usize = compiler_memory_offset_bytes + compiler_work_memory_bytes + compiler_source_gap_bytes + max_source_workspace_bytes;
const compiler_execution_tick_budget: u64 = 1_000_000_000;
const wasm_page_bytes: usize = 64 * 1024;
const workspace_manifest_header_bytes: usize = 16;
const source_editor_label = "src/ui_browser.zig";
const max_source_editor_bytes: usize = 512 * 1024;
const source_editor_tab = "    ";
const max_compiler_diagnostic_bytes: usize = 192;
const max_nodes: usize = 256;
const max_commands: usize = 4096;
const max_interaction_regions: usize = 4096;
const packed_rect_float_stride: usize = renderer_pipeline.rect_float_stride;
const packed_text_vertex_float_stride: usize = renderer_pipeline.text_vertex_float_stride;
const packed_icon_vertex_float_stride: usize = renderer_pipeline.icon_instance_float_stride;
const packed_icon_line_vertex_float_stride: usize = renderer_pipeline.icon_line_vertex_float_stride;
const packed_image_vertex_float_stride: usize = renderer_pipeline.image_vertex_float_stride;
const max_packed_rects: usize = 32768;
const max_packed_text_vertices: usize = 98304;
const max_packed_icon_vertices: usize = 16384;
const max_packed_icon_line_vertices: usize = 4194304;
const max_packed_image_vertices: usize = 384;
const max_packed_overlay_rects: usize = 512;
const max_packed_overlay_text_vertices: usize = 8192;
const max_packed_overlay_icon_vertices: usize = 1024;
const max_packed_overlay_icon_line_vertices: usize = 1048576;
const max_clips: usize = 64;
const font_atlas_width: usize = 4096;
const font_atlas_height: usize = 4096;
const font_atlas_bytes: usize = font_atlas_width * font_atlas_height;
const font_glyph_capacity: usize = 1280;
const font_first_char: u8 = renderer_pipeline.font_first_char;
const font_last_char: u8 = renderer_pipeline.font_last_char;
const font_padding: usize = 8;
const font_row_gap: usize = 8;
const font_bitmap_bytes: usize = 8 * 1024 * 1024;
const site_source_url = "https://github.com/edgerun";
const route_bytes_capacity: usize = site_navigation.route_path_capacity;
const route_hash_bytes_capacity: usize = site_navigation.route_hash_capacity;
const outbox_capacity: usize = 4;
const title_text = "EdgeRun Academy";
const dom_surface_id = "edgerun-dom";
const boot_dom_html = "";
const release_artifact_filename = "edgerun-app.wasm";
const entropy_pool_size: usize = 32;
const ephemeral_seed_size: usize = std.crypto.sign.Ed25519.KeyPair.seed_length;
const public_identity_prefix = "er1:";
const public_identity_text_len: usize = public_identity_prefix.len + identity.id_size * 2;
const initial_entropy_pool = [_]u8{
    0x65, 0x64, 0x67, 0x65, 0x72, 0x75, 0x6e, 0x3a,
    0x77, 0x61, 0x73, 0x6d, 0x3a, 0x69, 0x64, 0x3a,
    0x63, 0x6c, 0x69, 0x63, 0x6b, 0x2d, 0x65, 0x6e,
    0x74, 0x72, 0x6f, 0x70, 0x79, 0x3a, 0x76, 0x31,
};

var pixels: [max_pixels]ui.Color = undefined;
var input_bytes: [max_input_bytes]u8 = undefined;
var source_workspace: [max_source_workspace_bytes]u8 = undefined;
var source_workspace_len: usize = 0;
var source_workspace_ready = false;
var source_editor_bytes: [max_source_editor_bytes]u8 = undefined;
var source_editor_len: usize = 0;
var source_editor_cursor: usize = 0;
var source_editor_loaded = false;
var source_editor_dirty = false;
var source_editor_status: SourceEditorStatus = .not_loaded;
var last_compiler_status: u32 = 0;
var last_compiler_diagnostic: [max_compiler_diagnostic_bytes]u8 = undefined;
var last_compiler_diagnostic_len: usize = 0;
var release_artifact: [max_release_artifact_bytes]u8 = undefined;
var release_artifact_len: usize = 0;
var compiler_runtime_memory: [max_compiler_runtime_bytes]u8 align(16) = undefined;
var nodes: [max_nodes]ui.Node = undefined;
var commands: [max_commands]ui.Command = undefined;
var interaction_regions: [max_interaction_regions]interaction.Region = undefined;
var clips: [max_clips]ui.Rect = undefined;
var packed_rect_floats: [max_packed_rects * packed_rect_float_stride]f32 = undefined;
var packed_rect_float_len: usize = 0;
var packed_text_vertex_floats: [max_packed_text_vertices * packed_text_vertex_float_stride]f32 = undefined;
var packed_text_vertex_float_len: usize = 0;
var packed_icon_vertex_floats: [max_packed_icon_vertices * packed_icon_vertex_float_stride]f32 = undefined;
var packed_icon_vertex_float_len: usize = 0;
var packed_icon_line_vertex_floats: [max_packed_icon_line_vertices * packed_icon_line_vertex_float_stride]f32 = undefined;
var packed_icon_line_vertex_float_len: usize = 0;
var packed_image_vertex_floats: [max_packed_image_vertices * packed_image_vertex_float_stride]f32 = undefined;
var packed_image_vertex_float_len: usize = 0;
var packed_overlay_rect_floats: [max_packed_overlay_rects * packed_rect_float_stride]f32 = undefined;
var packed_overlay_rect_float_len: usize = 0;
var packed_overlay_text_vertex_floats: [max_packed_overlay_text_vertices * packed_text_vertex_float_stride]f32 = undefined;
var packed_overlay_text_vertex_float_len: usize = 0;
var packed_overlay_icon_vertex_floats: [max_packed_overlay_icon_vertices * packed_icon_vertex_float_stride]f32 = undefined;
var packed_overlay_icon_vertex_float_len: usize = 0;
var packed_overlay_icon_line_vertex_floats: [max_packed_overlay_icon_line_vertices * packed_icon_line_vertex_float_stride]f32 = undefined;
var packed_overlay_icon_line_vertex_float_len: usize = 0;
var font_atlas_alpha: [font_atlas_bytes]u8 = [_]u8{0} ** font_atlas_bytes;
var font_bitmap: [font_bitmap_bytes]u8 = undefined;
var font_glyphs: [font_glyph_capacity]FontGlyph = undefined;
var font_glyph_count: usize = 0;
var font_atlas_ready = false;
var font_device_scale: f32 = 1.0;
var font_atlas_device_scale: f32 = 0.0;
var font_atlas_x: usize = font_padding;
var font_atlas_y: usize = font_padding;
var font_atlas_row_h: usize = 0;
var font_atlas_generation: u32 = 0;
var frame_width: usize = 0;
var frame_height: usize = 0;
var last_command_count: usize = 0;
var last_region_count: usize = 0;
var last_present_primitive_count: usize = 0;
var last_present_transport: renderer_pipeline.Transport = .packed_buffers;
var last_error: ErrorCode = .ok;
var runtime_state = ui_runtime.State{};
var last_action_kind: u32 = @intFromEnum(ui_runtime.ActionKind.none);
var last_action_hit_id: u32 = 0;
var last_action_scope_id: u32 = 0;
var last_action_from_index: u32 = 0;
var last_action_to_index: u32 = 0;
var site_state = SiteState{};
var route_bytes: [route_bytes_capacity]u8 = undefined;
var route_len: usize = 0;
var route_hash_bytes: [route_hash_bytes_capacity]u8 = undefined;
var route_hash_len: usize = 0;
var pointer_hover_x: f32 = -1.0;
var pointer_hover_y: f32 = -1.0;
var outbox_messages: [outbox_capacity]OutboxMessage = [_]OutboxMessage{.{}} ** outbox_capacity;
var outbox_message_len: usize = 0;
var next_outbox_message_id: u32 = 1;
var entropy_pool: [entropy_pool_size]u8 = initialEntropyPool();
var entropy_event_count: u64 = 0;
var ephemeral_seed: [ephemeral_seed_size]u8 = [_]u8{0} ** ephemeral_seed_size;
var ephemeral_public_key: [identity.ed25519_public_size]u8 = [_]u8{0} ** identity.ed25519_public_size;
var ephemeral_identity_id: [identity.id_size]u8 = [_]u8{0} ** identity.id_size;
var public_identity_text: [public_identity_text_len]u8 = [_]u8{0} ** public_identity_text_len;
var ephemeral_identity_ready = false;
var packed_source_context: u8 = 0;
var environment_appearance: EnvironmentAppearance = .unknown;

const hover_hit_kind_none: u32 = 255;

const EnvironmentAppearance = enum(u32) {
    unknown = 0,
    light = 1,
    dark = 2,
};

const SourceEditorStatus = enum(u32) {
    not_loaded = 0,
    ready = 1,
    dirty = 2,
    missing_file = 3,
    corrupt_workspace = 4,
    editor_too_large = 5,
    workspace_full = 6,
};

const UiAction = enum(u32) {
    none = 0,
    open_url = 1,
};

const OutboxKind = enum(u32) {
    none = 0,
    open_url = 1,
    push_route_hash = 2,
    set_title = 3,
    set_element_html = 4,
    download_wasm = 5,
    launch_wasm = 6,
};

const OutboxMessage = struct {
    kind: OutboxKind = .none,
    id: u32 = 0,
};

const InputEventKind = enum(u32) {
    resize = 1,
    wheel = 2,
    pointer_move = 3,
    pointer_leave = 4,
    pointer_down = 5,
    pointer_up = 6,
    popstate = 7,
    hashchange = 8,
    key_down = 9,
};

const input_event_prevent_default: u32 = 1 << 0;
const input_event_schedule_frame: u32 = 1 << 1;
const input_event_outbox: u32 = 1 << 3;
const input_event_capture_pointer: u32 = 1 << 4;
const input_event_release_pointer: u32 = 1 << 5;
const input_event_error: u32 = 1 << 8;

const CursorKind = site_cursor.Kind;

const SiteView = site_navigation.View;

const SiteState = struct {
    view: SiteView = .landing,
    selected_blog_post_id: u32 = 0,
    blog_arc_filter_index: ?usize = null,
    selected_component_index: ?usize = null,
    scroll_y: f32 = 0.0,
    queued_action: UiAction = .none,

    fn resetUiAction(state: *SiteState) void {
        state.queued_action = .none;
    }

    fn resetScroll(state: *SiteState) void {
        state.scroll_y = 0.0;
    }
};

const ErrorCode = enum(u32) {
    ok = 0,
    bad_size = 1,
    bad_input = 2,
    bad_ui = 3,
    render_failed = 4,
    packed_budget = 5,
    font_atlas = 6,
    identity_failed = 7,
};

const FontGlyph = struct {
    ch: u8,
    px: u8,
    u0: f32,
    v0: f32,
    u1: f32,
    v1: f32,
    w: f32,
    h: f32,
    source_w: u16,
    source_h: u16,
    left: f32,
    top: f32,
    advance: f32,
};

fn packedBuffers() renderer_pipeline.Buffers {
    return .{
        .rects = packed_rect_floats[0..],
        .rect_len = &packed_rect_float_len,
        .text_vertices = packed_text_vertex_floats[0..],
        .text_vertex_len = &packed_text_vertex_float_len,
        .icon_vertices = packed_icon_vertex_floats[0..],
        .icon_vertex_len = &packed_icon_vertex_float_len,
        .image_vertices = packed_image_vertex_floats[0..],
        .image_vertex_len = &packed_image_vertex_float_len,
        .overlay_rects = packed_overlay_rect_floats[0..],
        .overlay_rect_len = &packed_overlay_rect_float_len,
        .overlay_text_vertices = packed_overlay_text_vertex_floats[0..],
        .overlay_text_vertex_len = &packed_overlay_text_vertex_float_len,
        .overlay_icon_vertices = packed_overlay_icon_vertex_floats[0..],
        .overlay_icon_vertex_len = &packed_overlay_icon_vertex_float_len,
    };
}

fn packedSources() renderer_pipeline.Sources {
    return .{
        .font = .{
            .context = &packed_source_context,
            .metrics = fontMetricsForIr,
            .width = textWidthForIr,
            .glyph = fontGlyphForIr,
        },
    };
}

fn fontMetricsForIr(_: *anyopaque, px: u8) renderer_pipeline.TextMetrics {
    return fontMetrics(px);
}

fn textWidthForIr(_: *anyopaque, value: []const u8, px: u8) f32 {
    return textWidth(value, px);
}

fn fontGlyphForIr(_: *anyopaque, ch: u8, px: u8) renderer_pipeline.IrError!?renderer_pipeline.Glyph {
    const glyph = (getFontGlyph(ch, px) catch return error.Budget) orelse return null;
    return .{
        .u0 = glyph.u0,
        .v0 = glyph.v0,
        .u1 = glyph.u1,
        .v1 = glyph.v1,
        .w = glyph.w,
        .h = glyph.h,
        .left = glyph.left,
        .top = glyph.top,
        .advance = glyph.advance,
    };
}

export fn er_ui_max_width() u32 {
    return max_width;
}

export fn er_ui_max_height() u32 {
    return max_height;
}

export fn er_ui_pixels_ptr() usize {
    return @intFromPtr(&pixels);
}

export fn er_ui_pixels_len() usize {
    return frame_width * frame_height * @sizeOf(ui.Color);
}

export fn er_ui_packed_rect_float_stride() u32 {
    return packed_rect_float_stride;
}

export fn er_ui_packed_rect_buffer_ptr() usize {
    return @intFromPtr(packed_rect_floats[0..].ptr);
}

export fn er_ui_packed_rect_buffer_len() usize {
    return packed_rect_float_len;
}

export fn er_ui_packed_text_vertex_float_stride() u32 {
    return packed_text_vertex_float_stride;
}

export fn er_ui_packed_text_vertex_buffer_ptr() usize {
    return @intFromPtr(packed_text_vertex_floats[0..].ptr);
}

export fn er_ui_packed_text_vertex_buffer_len() usize {
    return packed_text_vertex_float_len;
}

export fn er_ui_packed_icon_vertex_float_stride() u32 {
    return packed_icon_vertex_float_stride;
}

export fn er_ui_packed_icon_vertex_buffer_ptr() usize {
    return @intFromPtr(packed_icon_vertex_floats[0..].ptr);
}

export fn er_ui_packed_icon_vertex_buffer_len() usize {
    return packed_icon_vertex_float_len;
}

export fn er_ui_packed_icon_line_vertex_float_stride() u32 {
    return packed_icon_line_vertex_float_stride;
}

export fn er_ui_packed_icon_line_vertex_buffer_ptr() usize {
    return @intFromPtr(packed_icon_line_vertex_floats[0..].ptr);
}

export fn er_ui_packed_icon_line_vertex_buffer_len() usize {
    return packed_icon_line_vertex_float_len;
}

export fn er_ui_packed_image_vertex_float_stride() u32 {
    return packed_image_vertex_float_stride;
}

export fn er_ui_packed_image_vertex_buffer_ptr() usize {
    return @intFromPtr(packed_image_vertex_floats[0..].ptr);
}

export fn er_ui_packed_image_vertex_buffer_len() usize {
    return packed_image_vertex_float_len;
}

export fn er_ui_packed_overlay_rect_buffer_ptr() usize {
    return @intFromPtr(packed_overlay_rect_floats[0..].ptr);
}

export fn er_ui_packed_overlay_rect_buffer_len() usize {
    return packed_overlay_rect_float_len;
}

export fn er_ui_packed_overlay_text_vertex_buffer_ptr() usize {
    return @intFromPtr(packed_overlay_text_vertex_floats[0..].ptr);
}

export fn er_ui_packed_overlay_text_vertex_buffer_len() usize {
    return packed_overlay_text_vertex_float_len;
}

export fn er_ui_packed_overlay_icon_vertex_buffer_ptr() usize {
    return @intFromPtr(packed_overlay_icon_vertex_floats[0..].ptr);
}

export fn er_ui_packed_overlay_icon_vertex_buffer_len() usize {
    return packed_overlay_icon_vertex_float_len;
}

export fn er_ui_packed_overlay_icon_line_vertex_buffer_ptr() usize {
    return @intFromPtr(packed_overlay_icon_line_vertex_floats[0..].ptr);
}

export fn er_ui_packed_overlay_icon_line_vertex_buffer_len() usize {
    return packed_overlay_icon_line_vertex_float_len;
}

export fn er_ui_post_image_rgba_ptr() usize {
    return site_images.cloudMemeRgbaPtr();
}

export fn er_ui_post_image_rgba_len() usize {
    return site_images.cloudMemeRgbaLen();
}

export fn er_ui_post_image_width() u32 {
    return site_images.cloud_meme_width;
}

export fn er_ui_post_image_height() u32 {
    return site_images.cloud_meme_height;
}

export fn er_ui_font_atlas_width() u32 {
    return font_atlas_width;
}

export fn er_ui_font_atlas_height() u32 {
    return font_atlas_height;
}

export fn er_ui_font_atlas_ptr() usize {
    ensureFontAtlas() catch return 0;
    return @intFromPtr(font_atlas_alpha[0..].ptr);
}

export fn er_ui_font_atlas_generation() u32 {
    ensureFontAtlas() catch return 0;
    return font_atlas_generation;
}

export fn er_ui_width() u32 {
    return @intCast(frame_width);
}

export fn er_ui_height() u32 {
    return @intCast(frame_height);
}

export fn er_ui_input_ptr() usize {
    return @intFromPtr(&input_bytes);
}

export fn er_ui_input_capacity() usize {
    return input_bytes.len;
}

export fn er_ui_last_error() u32 {
    return @intFromEnum(last_error);
}

export fn er_ui_site_public_identity_ptr() usize {
    return @intFromPtr(publicIdentityText().ptr);
}

export fn er_ui_site_public_identity_len() usize {
    return publicIdentityText().len;
}

export fn er_ui_set_device_scale(scale: f32) u32 {
    const next = normalizedDeviceScale(scale);
    if (@abs(next - font_device_scale) <= 0.001) return 0;
    font_device_scale = next;
    font_atlas_ready = false;
    return 1;
}

export fn er_ui_set_environment_appearance(value: u32) u32 {
    environment_appearance = hostAppearanceFromInt(value);
    return @intFromEnum(environment_appearance);
}

export fn er_ui_environment_appearance() u32 {
    return @intFromEnum(environment_appearance);
}

fn hostAppearanceFromInt(value: u32) EnvironmentAppearance {
    return switch (value) {
        @intFromEnum(EnvironmentAppearance.light) => .light,
        @intFromEnum(EnvironmentAppearance.dark) => .dark,
        else => .unknown,
    };
}

export fn er_ui_hover_hit_kind() u32 {
    return currentHoverHitKind();
}

export fn er_ui_hover_hit_id() u32 {
    return currentHoverHitId();
}

export fn er_ui_cursor_kind() u32 {
    return @intFromEnum(currentCursorKind());
}

export fn er_ui_last_action_kind() u32 {
    return last_action_kind;
}

export fn er_ui_last_action_hit_id() u32 {
    return last_action_hit_id;
}

export fn er_ui_last_action_scope_id() u32 {
    return last_action_scope_id;
}

export fn er_ui_last_action_from_index() u32 {
    return last_action_from_index;
}

export fn er_ui_last_action_to_index() u32 {
    return last_action_to_index;
}

export fn er_ui_pointer_down(x: f32, y: f32) u32 {
    mixInteractionEntropy(.pointer_down, x, y);
    recordAction(runtime_state.pointerDown(lastCommands(), lastRegions(), x, y));
    return last_action_kind;
}

export fn er_ui_pointer_move(x: f32, y: f32) u32 {
    mixInteractionEntropy(.pointer_move, x, y);
    recordAction(runtime_state.pointerMove(lastCommands(), lastRegions(), x, y));
    return last_action_kind;
}

export fn er_ui_pointer_up(x: f32, y: f32) u32 {
    mixInteractionEntropy(.pointer_up, x, y);
    recordAction(runtime_state.pointerUp(lastCommands(), lastRegions(), x, y));
    return last_action_kind;
}

export fn er_ui_site_pointer_up(x: f32, y: f32) u32 {
    const action_kind = er_ui_pointer_up(x, y);
    if (action_kind == @intFromEnum(ui_runtime.ActionKind.reordered)) {
        return @intFromEnum(UiAction.none);
    }
    return er_ui_site_activate_hit(currentHoverHitId());
}

export fn er_ui_component_gallery_layout_masonry_id() u32 {
    return component_gallery.layout_masonry_id;
}

export fn er_ui_component_gallery_layout_grid_id() u32 {
    return component_gallery.layout_grid_id;
}

export fn er_ui_component_gallery_gap_compact_id() u32 {
    return component_gallery.gap_compact_id;
}

export fn er_ui_component_gallery_gap_default_id() u32 {
    return component_gallery.gap_default_id;
}

export fn er_ui_component_gallery_gap_wide_id() u32 {
    return component_gallery.gap_wide_id;
}

export fn er_ui_site_docs_button_id() u32 {
    return site_chrome.docs_button_id;
}

export fn er_ui_site_apps_button_id() u32 {
    return site_chrome.apps_button_id;
}

export fn er_ui_site_launch_button_id() u32 {
    return site_chrome.launch_button_id;
}

export fn er_ui_site_source_button_id() u32 {
    return site_chrome.source_button_id;
}

export fn er_ui_site_blog_button_id() u32 {
    return site_chrome.blog_button_id;
}

export fn er_ui_blog_back_button_id() u32 {
    return site_blog.back_button_id;
}

export fn er_ui_blog_first_post_button_id() u32 {
    return site_blog.first_post_button_id;
}

export fn er_ui_blog_post_count() u32 {
    return site_blog.posts.len;
}

export fn er_ui_site_action_kind() u32 {
    return @intFromEnum(site_state.queued_action);
}

export fn er_ui_site_action_url_ptr() usize {
    return @intFromPtr(site_source_url.ptr);
}

export fn er_ui_site_action_url_len() usize {
    return site_source_url.len;
}

export fn er_ui_outbox_count() u32 {
    return @intCast(outbox_message_len);
}

export fn er_ui_outbox_kind(index: u32) u32 {
    if (index >= outbox_message_len) return @intFromEnum(OutboxKind.none);
    return @intFromEnum(outbox_messages[index].kind);
}

export fn er_ui_outbox_id(index: u32) u32 {
    if (index >= outbox_message_len) return 0;
    return outbox_messages[index].id;
}

export fn er_ui_outbox_target_ptr(index: u32) usize {
    if (index >= outbox_message_len) return 0;
    return switch (outbox_messages[index].kind) {
        .none, .open_url, .push_route_hash, .set_title, .launch_wasm => 0,
        .set_element_html => @intFromPtr(dom_surface_id.ptr),
        .download_wasm => @intFromPtr(release_artifact_filename.ptr),
    };
}

export fn er_ui_outbox_target_len(index: u32) usize {
    if (index >= outbox_message_len) return 0;
    return switch (outbox_messages[index].kind) {
        .none, .open_url, .push_route_hash, .set_title, .launch_wasm => 0,
        .set_element_html => dom_surface_id.len,
        .download_wasm => release_artifact_filename.len,
    };
}

export fn er_ui_outbox_payload_ptr(index: u32) usize {
    if (index >= outbox_message_len) return 0;
    return switch (outbox_messages[index].kind) {
        .none => 0,
        .open_url => @intFromPtr(site_source_url.ptr),
        .download_wasm, .launch_wasm => if (release_artifact_len == 0) 0 else @intFromPtr(&release_artifact),
        .push_route_hash => {
            refreshRouteHash();
            return @intFromPtr(route_hash_bytes[0..].ptr);
        },
        .set_title => @intFromPtr(title_text.ptr),
        .set_element_html => @intFromPtr(boot_dom_html.ptr),
    };
}

export fn er_ui_outbox_payload_len(index: u32) usize {
    if (index >= outbox_message_len) return 0;
    return switch (outbox_messages[index].kind) {
        .none => 0,
        .open_url => site_source_url.len,
        .download_wasm, .launch_wasm => release_artifact_len,
        .push_route_hash => {
            refreshRouteHash();
            return route_hash_len;
        },
        .set_title => title_text.len,
        .set_element_html => boot_dom_html.len,
    };
}

export fn er_ui_outbox_clear() u32 {
    clearOutboxMessages();
    site_state.resetUiAction();
    last_error = .ok;
    return @intFromEnum(ErrorCode.ok);
}

export fn er_ui_bootstrap_js_ptr() usize {
    return @intFromPtr(browser_runtime_js.source.ptr);
}

export fn er_ui_bootstrap_js_len() usize {
    return browser_runtime_js.source.len;
}

export fn er_ui_compiler_source_ptr() usize {
    return @intFromPtr(&source_object);
}

export fn er_ui_compiler_source_len() usize {
    return source_object.len;
}

export fn er_ui_source_workspace_ptr() usize {
    ensureSourceWorkspace();
    return @intFromPtr(&source_workspace);
}

export fn er_ui_source_workspace_len() usize {
    ensureSourceWorkspace();
    return source_workspace_len;
}

export fn er_ui_source_workspace_capacity() usize {
    return source_workspace.len;
}

export fn er_ui_source_workspace_commit(source_len: usize) u32 {
    if (source_len > source_workspace.len) return finishError(.bad_input);
    source_workspace_len = source_len;
    source_workspace_ready = true;
    source_editor_loaded = false;
    source_editor_dirty = false;
    source_editor_status = .not_loaded;
    last_error = .ok;
    return @intFromEnum(ErrorCode.ok);
}

export fn er_ui_source_workspace_reset() u32 {
    source_workspace_ready = false;
    ensureSourceWorkspace();
    source_editor_loaded = false;
    source_editor_dirty = false;
    source_editor_status = .not_loaded;
    last_error = .ok;
    return @intFromEnum(ErrorCode.ok);
}

export fn er_ui_source_editor_ptr() usize {
    ensureSourceEditor();
    return @intFromPtr(&source_editor_bytes);
}

export fn er_ui_source_editor_len() usize {
    ensureSourceEditor();
    return source_editor_len;
}

export fn er_ui_source_editor_cursor() usize {
    ensureSourceEditor();
    return source_editor_cursor;
}

export fn er_ui_source_editor_dirty() u32 {
    return if (source_editor_dirty) 1 else 0;
}

export fn er_ui_source_editor_status() u32 {
    ensureSourceEditor();
    return @intFromEnum(source_editor_status);
}

export fn er_ui_last_compiler_status() u32 {
    return last_compiler_status;
}

export fn er_ui_last_compiler_diagnostic_ptr() usize {
    return @intFromPtr(&last_compiler_diagnostic);
}

export fn er_ui_last_compiler_diagnostic_len() usize {
    return last_compiler_diagnostic_len;
}

export fn er_ui_compiler_wasm_ptr() usize {
    return @intFromPtr(&compiler_wasm);
}

export fn er_ui_compiler_wasm_len() usize {
    return compiler_wasm.len;
}

export fn er_ui_release_artifact_ptr() usize {
    return @intFromPtr(&release_artifact);
}

export fn er_ui_release_artifact_len() usize {
    return release_artifact_len;
}

export fn er_ui_release_artifact_capacity() usize {
    return release_artifact.len;
}

export fn er_ui_release_artifact_commit(artifact_len: usize) u32 {
    if (artifact_len > release_artifact.len) return finishError(.bad_input);
    if (artifact_len < 4) return finishError(.bad_input);
    if (!std.mem.eql(u8, release_artifact[0..4], &.{ 0x00, 0x61, 0x73, 0x6d })) return finishError(.bad_input);
    release_artifact_len = artifact_len;
    last_error = .ok;
    return @intFromEnum(ErrorCode.ok);
}

export fn er_ui_release_artifact_clear() u32 {
    release_artifact_len = 0;
    last_error = .ok;
    return @intFromEnum(ErrorCode.ok);
}

export fn er_ui_compile_workspace_wasm() u32 {
    return @intFromEnum(compileWorkspaceInsideWasm());
}

export fn er_ui_request_release_artifact_download() u32 {
    if (release_artifact_len == 0) return finishError(.bad_input);
    queueOutboxMessage(.download_wasm) catch return finishError(.bad_input);
    last_error = .ok;
    return @intFromEnum(ErrorCode.ok);
}

export fn er_ui_request_release_artifact_launch() u32 {
    if (release_artifact_len == 0) return finishError(.bad_input);
    queueOutboxMessage(.launch_wasm) catch return finishError(.bad_input);
    last_error = .ok;
    return @intFromEnum(ErrorCode.ok);
}

export fn er_ui_site_route_hash_ptr() usize {
    refreshRouteHash();
    return @intFromPtr(route_hash_bytes[0..].ptr);
}

export fn er_ui_site_route_hash_len() usize {
    refreshRouteHash();
    return route_hash_len;
}

export fn er_ui_site_route_path_ptr() usize {
    refreshRoutePath();
    return @intFromPtr(route_bytes[0..].ptr);
}

export fn er_ui_site_route_path_len() usize {
    refreshRoutePath();
    return route_len;
}

export fn er_ui_site_set_route_path(path_len: usize) u32 {
    if (path_len > input_bytes.len) return finishError(.bad_input);
    applyRoutePath(input_bytes[0..path_len]);
    last_error = .ok;
    return @intFromEnum(ErrorCode.ok);
}

export fn er_ui_site_set_route_hash(hash_len: usize) u32 {
    if (hash_len > input_bytes.len) return finishError(.bad_input);
    const route_path = routePathFromHash(input_bytes[0..hash_len]) catch return finishError(.bad_input);
    applyRoutePath(route_path);
    last_error = .ok;
    return @intFromEnum(ErrorCode.ok);
}

export fn er_ui_site_activate_hit(hit_id: u32) u32 {
    site_state.resetUiAction();
    clearOutboxMessages();
    if (site_navigation.fromHit(hit_id, currentRoute())) |route| {
        applyRoute(route);
        return @intFromEnum(site_state.queued_action);
    }
    if (site_navigation.actionFromHit(hit_id)) |action| switch (action) {
        .launch_app => {
            if (compileWorkspaceInsideWasm() == .ok) {
                queueOutboxMessage(.launch_wasm) catch return finishError(.bad_input);
            }
        },
        .reveal_identity => {
            if (!ephemeral_identity_ready) {
                generateEphemeralIdentity() catch return finishError(.identity_failed);
            }
        },
        .compile_source => {
            _ = compileWorkspaceInsideWasm();
        },
        .download_source_release => {
            if (release_artifact_len == 0 and compileWorkspaceInsideWasm() != .ok) return @intFromEnum(site_state.queued_action);
            queueOutboxMessage(.download_wasm) catch return finishError(.bad_input);
        },
        .launch_source_release => {
            if (release_artifact_len == 0 and compileWorkspaceInsideWasm() != .ok) return @intFromEnum(site_state.queued_action);
            queueOutboxMessage(.launch_wasm) catch return finishError(.bad_input);
        },
        .reset_source => {
            _ = er_ui_source_workspace_reset();
        },
    };
    return @intFromEnum(site_state.queued_action);
}

export fn er_ui_site_key_event(key_len: usize, ctrl: u32, meta: u32, alt: u32) u32 {
    if (key_len > input_bytes.len) return finishError(.bad_input);
    if (site_state.view == .source and handleSourceEditorKey(input_bytes[0..key_len], ctrl, meta, alt)) {
        last_error = .ok;
        return 1;
    }
    last_error = .ok;
    return 0;
}

export fn er_ui_event(kind_raw: u32, x: f32, y: f32, delta_y: f32, ctrl: u32, meta: u32, alt: u32, text_len: usize, width: f32, height: f32) u32 {
    const kind: InputEventKind = switch (kind_raw) {
        @intFromEnum(InputEventKind.resize) => .resize,
        @intFromEnum(InputEventKind.wheel) => .wheel,
        @intFromEnum(InputEventKind.pointer_move) => .pointer_move,
        @intFromEnum(InputEventKind.pointer_leave) => .pointer_leave,
        @intFromEnum(InputEventKind.pointer_down) => .pointer_down,
        @intFromEnum(InputEventKind.pointer_up) => .pointer_up,
        @intFromEnum(InputEventKind.popstate) => .popstate,
        @intFromEnum(InputEventKind.hashchange) => .hashchange,
        @intFromEnum(InputEventKind.key_down) => .key_down,
        else => {
            _ = finishError(.bad_input);
            return input_event_error;
        },
    };

    switch (kind) {
        .resize => return input_event_schedule_frame,
        .wheel => {
            const code = er_ui_site_scroll_by(delta_y, width, height);
            if (code != @intFromEnum(ErrorCode.ok)) return input_event_error;
            return input_event_prevent_default | input_event_schedule_frame;
        },
        .pointer_move => {
            pointer_hover_x = x;
            pointer_hover_y = y;
            _ = er_ui_pointer_move(x, y);
            return input_event_schedule_frame;
        },
        .pointer_leave => {
            pointer_hover_x = -1.0;
            pointer_hover_y = -1.0;
            runtime_state.clearHover();
            return input_event_schedule_frame;
        },
        .pointer_down => {
            pointer_hover_x = x;
            pointer_hover_y = y;
            _ = er_ui_pointer_down(x, y);
            return input_event_capture_pointer | input_event_schedule_frame;
        },
        .pointer_up => {
            pointer_hover_x = x;
            pointer_hover_y = y;
            _ = er_ui_site_pointer_up(x, y);
            queueOutboxMessage(.push_route_hash) catch return input_event_error;
            const result = input_event_release_pointer | input_event_outbox | input_event_schedule_frame;
            return result;
        },
        .popstate, .hashchange => {
            const code = er_ui_site_set_route_hash(text_len);
            if (code != @intFromEnum(ErrorCode.ok)) return input_event_error;
            return input_event_schedule_frame;
        },
        .key_down => {
            const handled = er_ui_site_key_event(text_len, ctrl, meta, alt);
            if (handled == 0) return 0;
            if (handled != 1) return input_event_error;
            return input_event_prevent_default | input_event_schedule_frame;
        },
    }
}

export fn er_ui_event_bytes(input_len: usize, width: f32, height: f32, frame_ms: f32) u32 {
    _ = frame_ms;
    if (input_len > input_bytes.len) return finishError(.bad_input);
    const envelope = input_bytes[0..input_len];
    var fields = std.mem.splitScalar(u8, envelope, '\n');
    const event_name = fields.next() orelse return finishError(.bad_input);
    const kind = inputEventKindFromName(event_name) orelse {
        last_error = .ok;
        return 0;
    };
    const x = parseInputEventFloat(fields.next() orelse "") catch return finishError(.bad_input);
    const y = parseInputEventFloat(fields.next() orelse "") catch return finishError(.bad_input);
    const delta_y = parseInputEventFloat(fields.next() orelse "") catch return finishError(.bad_input);
    const ctrl = parseInputEventFlag(fields.next() orelse "") catch return finishError(.bad_input);
    const meta = parseInputEventFlag(fields.next() orelse "") catch return finishError(.bad_input);
    const alt = parseInputEventFlag(fields.next() orelse "") catch return finishError(.bad_input);
    const text = fields.next() orelse "";
    if (text.len > input_bytes.len) return finishError(.bad_input);
    const kind_raw = @intFromEnum(kind);
    std.mem.copyForwards(u8, input_bytes[0..text.len], text);
    return er_ui_event(kind_raw, x, y, delta_y, ctrl, meta, alt, text.len, width, height);
}

export fn er_ui_boot() u32 {
    clearOutboxMessages();
    queueOutboxMessage(.set_title) catch return finishError(.bad_input);
    queueOutboxMessage(.set_element_html) catch return finishError(.bad_input);
    last_error = .ok;
    return input_event_outbox | input_event_schedule_frame;
}

fn inputEventKindFromName(name: []const u8) ?InputEventKind {
    if (std.mem.eql(u8, name, "resize")) return .resize;
    if (std.mem.eql(u8, name, "wheel")) return .wheel;
    if (std.mem.eql(u8, name, "pointermove")) return .pointer_move;
    if (std.mem.eql(u8, name, "pointerleave")) return .pointer_leave;
    if (std.mem.eql(u8, name, "pointercancel")) return .pointer_leave;
    if (std.mem.eql(u8, name, "pointerdown")) return .pointer_down;
    if (std.mem.eql(u8, name, "pointerup")) return .pointer_up;
    if (std.mem.eql(u8, name, "popstate")) return .popstate;
    if (std.mem.eql(u8, name, "hashchange")) return .hashchange;
    if (std.mem.eql(u8, name, "keydown")) return .key_down;
    if (std.mem.eql(u8, name, "contextmenu")) return .pointer_leave;
    return null;
}

fn parseInputEventFloat(value: []const u8) !f32 {
    if (value.len == 0) return 0.0;
    return std.fmt.parseFloat(f32, value);
}

fn parseInputEventFlag(value: []const u8) !u32 {
    if (std.mem.eql(u8, value, "1")) return 1;
    if (std.mem.eql(u8, value, "0") or value.len == 0) return 0;
    return error.InvalidInputEventFlag;
}

fn queueOutboxMessage(kind: OutboxKind) error{OutboxMessageBudget}!void {
    if (outbox_message_len >= outbox_messages.len) return error.OutboxMessageBudget;
    outbox_messages[outbox_message_len] = .{ .kind = kind, .id = nextOutboxMessageId() };
    outbox_message_len += 1;
}

fn nextOutboxMessageId() u32 {
    const value = next_outbox_message_id;
    next_outbox_message_id +%= 1;
    if (next_outbox_message_id == 0) next_outbox_message_id = 1;
    return value;
}

fn clearOutboxMessages() void {
    for (outbox_messages[0..outbox_message_len]) |*command| command.* = .{};
    outbox_message_len = 0;
}

fn ensureSourceWorkspace() void {
    if (source_workspace_ready) return;
    const initial_len = @min(source_object.len, source_workspace.len);
    @memcpy(source_workspace[0..initial_len], source_object[0..initial_len]);
    source_workspace_len = initial_len;
    source_workspace_ready = true;
}

fn ensureSourceEditor() void {
    if (source_editor_loaded) return;
    source_editor_loaded = true;
    source_editor_dirty = false;
    source_editor_len = 0;
    source_editor_cursor = 0;
    source_editor_status = loadSourceEditorFromWorkspace();
}

fn loadSourceEditorFromWorkspace() SourceEditorStatus {
    ensureSourceWorkspace();
    const body = findWorkspaceFileBody(source_workspace[0..source_workspace_len], source_editor_label) catch return .corrupt_workspace;
    if (body.len == 0) return .missing_file;
    if (body.len > source_editor_bytes.len) return .editor_too_large;
    @memcpy(source_editor_bytes[0..body.len], body);
    source_editor_len = body.len;
    source_editor_cursor = 0;
    return .ready;
}

fn findWorkspaceFileBody(workspace_bytes: []const u8, label: []const u8) ![]const u8 {
    const workspace_view = try object.View.decode(workspace_bytes);
    if (!std.mem.startsWith(u8, workspace_view.body, "ERVFSWS1")) return error.CorruptWorkspace;
    if (workspace_view.body.len < workspace_manifest_header_bytes) return error.CorruptWorkspace;
    const file_count = bytes.load32(workspace_view.body[12..16]) orelse return error.CorruptWorkspace;
    var index: usize = workspace_manifest_header_bytes;
    var remaining = file_count;
    while (remaining > 0) : (remaining -= 1) {
        if (index > workspace_view.body.len or vfs.object_label_ref_bytes > workspace_view.body.len - index) return error.CorruptWorkspace;
        const label_ref = try vfs.decodeObjectLabelRef(workspace_view.body[index..][0..vfs.object_label_ref_bytes]);
        index += vfs.object_label_ref_bytes;
        const file_len: usize = @intCast(label_ref.object_len);
        if (index > workspace_view.body.len or file_len > workspace_view.body.len - index) return error.CorruptWorkspace;
        const file_object = workspace_view.body[index..][0..file_len];
        index += file_len;
        if (std.mem.eql(u8, label_ref.labelSlice(), label)) {
            const file_view = try object.View.decode(file_object);
            const file_id = file_view.id();
            if (!std.mem.eql(u8, &label_ref.object_id, &file_id)) return error.CorruptWorkspace;
            return file_view.body;
        }
    }
    if (index != workspace_view.body.len) return error.CorruptWorkspace;
    return "";
}

fn handleSourceEditorKey(key: []const u8, ctrl: u32, meta: u32, alt: u32) bool {
    if (ctrl != 0 or meta != 0 or alt != 0) return false;
    ensureSourceEditor();
    if (source_editor_status != .ready and source_editor_status != .dirty) return false;

    if (std.mem.eql(u8, key, "ArrowLeft")) {
        if (source_editor_cursor > 0) source_editor_cursor -= 1;
        return true;
    }
    if (std.mem.eql(u8, key, "ArrowRight")) {
        if (source_editor_cursor < source_editor_len) source_editor_cursor += 1;
        return true;
    }
    if (std.mem.eql(u8, key, "Home")) {
        source_editor_cursor = 0;
        return true;
    }
    if (std.mem.eql(u8, key, "End")) {
        source_editor_cursor = source_editor_len;
        return true;
    }
    if (std.mem.eql(u8, key, "Backspace")) {
        if (source_editor_cursor > 0) {
            std.mem.copyForwards(u8, source_editor_bytes[source_editor_cursor - 1 .. source_editor_len - 1], source_editor_bytes[source_editor_cursor..source_editor_len]);
            source_editor_cursor -= 1;
            source_editor_len -= 1;
            commitSourceEditorBytes();
        }
        return true;
    }
    if (std.mem.eql(u8, key, "Delete")) {
        if (source_editor_cursor < source_editor_len) {
            std.mem.copyForwards(u8, source_editor_bytes[source_editor_cursor .. source_editor_len - 1], source_editor_bytes[source_editor_cursor + 1 .. source_editor_len]);
            source_editor_len -= 1;
            commitSourceEditorBytes();
        }
        return true;
    }
    if (std.mem.eql(u8, key, "Enter")) return insertSourceEditorText("\n");
    if (std.mem.eql(u8, key, "Tab")) return insertSourceEditorText(source_editor_tab);
    if (key.len == 1 and key[0] >= 0x20 and key[0] <= 0x7e) return insertSourceEditorText(key);
    return false;
}

fn insertSourceEditorText(text: []const u8) bool {
    if (text.len == 0) return true;
    if (text.len > source_editor_bytes.len - source_editor_len) {
        source_editor_status = .editor_too_large;
        return true;
    }
    std.mem.copyBackwards(u8, source_editor_bytes[source_editor_cursor + text.len .. source_editor_len + text.len], source_editor_bytes[source_editor_cursor..source_editor_len]);
    @memcpy(source_editor_bytes[source_editor_cursor..][0..text.len], text);
    source_editor_cursor += text.len;
    source_editor_len += text.len;
    commitSourceEditorBytes();
    return true;
}

fn commitSourceEditorBytes() void {
    source_editor_status = rebuildSourceWorkspaceFromEditor();
    source_editor_dirty = source_editor_status == .dirty;
}

fn rebuildSourceWorkspaceFromEditor() SourceEditorStatus {
    ensureSourceWorkspace();
    const workspace_view = object.View.decode(source_workspace[0..source_workspace_len]) catch return .corrupt_workspace;
    if (!std.mem.startsWith(u8, workspace_view.body, "ERVFSWS1")) return .corrupt_workspace;
    if (workspace_view.body.len < workspace_manifest_header_bytes) return .corrupt_workspace;
    const file_count = bytes.load32(workspace_view.body[12..16]) orelse return .corrupt_workspace;
    if (compiler_runtime_memory.len < object.header_size + workspace_view.body.len) return .workspace_full;

    var body_len: usize = workspace_manifest_header_bytes;
    @memcpy(compiler_runtime_memory[object.header_size..][0..workspace_manifest_header_bytes], workspace_view.body[0..workspace_manifest_header_bytes]);

    var index: usize = workspace_manifest_header_bytes;
    var remaining = file_count;
    var replaced = false;
    while (remaining > 0) : (remaining -= 1) {
        if (index > workspace_view.body.len or vfs.object_label_ref_bytes > workspace_view.body.len - index) return .corrupt_workspace;
        const label_ref_raw = workspace_view.body[index..][0..vfs.object_label_ref_bytes];
        const label_ref = vfs.decodeObjectLabelRef(label_ref_raw) catch return .corrupt_workspace;
        index += vfs.object_label_ref_bytes;
        const file_len: usize = @intCast(label_ref.object_len);
        if (index > workspace_view.body.len or file_len > workspace_view.body.len - index) return .corrupt_workspace;
        const file_object = workspace_view.body[index..][0..file_len];
        index += file_len;

        if (std.mem.eql(u8, label_ref.labelSlice(), source_editor_label)) {
            const file_view = object.View.decode(file_object) catch return .corrupt_workspace;
            const label_pos = object.header_size + body_len;
            const file_pos = label_pos + vfs.object_label_ref_bytes;
            if (file_pos > compiler_runtime_memory.len) return .workspace_full;
            const new_file = (object.NodeWriter{ .out = compiler_runtime_memory[file_pos..] }).bytesNode(file_view.header.requirements, file_view.header.epoch, source_editor_bytes[0..source_editor_len]) catch return .workspace_full;
            const new_ref = vfs.prepareObjectLabelRef(source_editor_label, new_file) catch return .corrupt_workspace;
            vfs.encodeObjectLabelRef(new_ref, compiler_runtime_memory[label_pos..][0..vfs.object_label_ref_bytes]) catch return .workspace_full;
            body_len += vfs.object_label_ref_bytes + new_file.len;
            replaced = true;
        } else {
            const raw_len = vfs.object_label_ref_bytes + file_object.len;
            const out_pos = object.header_size + body_len;
            if (out_pos > compiler_runtime_memory.len or raw_len > compiler_runtime_memory.len - out_pos) return .workspace_full;
            @memcpy(compiler_runtime_memory[out_pos..][0..vfs.object_label_ref_bytes], label_ref_raw);
            @memcpy(compiler_runtime_memory[out_pos + vfs.object_label_ref_bytes ..][0..file_object.len], file_object);
            body_len += raw_len;
        }
    }
    if (!replaced or index != workspace_view.body.len) return .corrupt_workspace;

    const body = compiler_runtime_memory[object.header_size..][0..body_len];
    const canonical = (object.NodeWriter{ .out = &compiler_runtime_memory }).bytesNode(workspace_view.header.requirements, workspace_view.header.epoch, body) catch return .workspace_full;
    if (canonical.len > source_workspace.len) return .workspace_full;
    @memcpy(source_workspace[0..canonical.len], canonical);
    source_workspace_len = canonical.len;
    source_workspace_ready = true;
    release_artifact_len = 0;
    return .dirty;
}

fn compileWorkspaceInsideWasm() ErrorCode {
    ensureSourceWorkspace();
    if (source_workspace_len == 0 or source_workspace_len > source_workspace.len) return finishErrorCode(.bad_input);

    const source_offset = alignForward(compiler_memory_offset_bytes + compiler_work_memory_bytes + compiler_source_gap_bytes, 16);
    if (source_offset > compiler_runtime_memory.len) return finishErrorCode(.bad_input);
    if (source_workspace_len > compiler_runtime_memory.len - source_offset) return finishErrorCode(.bad_input);

    @memset(&compiler_runtime_memory, 0);
    @memcpy(compiler_runtime_memory[source_offset .. source_offset + source_workspace_len], source_workspace[0..source_workspace_len]);

    var execution_ticks: u64 = compiler_execution_tick_budget;
    var runtime = wasm_interpreter.Runtime.initWithMemoryPages(&compiler_runtime_memory, &execution_ticks, pagesForBytes(source_offset + source_workspace_len));
    const compiler_memory_ptr: i32 = @intCast(compiler_memory_offset_bytes);
    const compiler_memory_len: i32 = @intCast(compiler_work_memory_bytes);
    const source_ptr: i32 = @intCast(source_offset);
    const source_len: i32 = @intCast(source_workspace_len);
    const init_args = [_]wasm_interpreter.Value{
        .{ .i32 = compiler_memory_ptr },
        .{ .i32 = compiler_memory_len },
    };
    const init_result = wasm_interpreter.executeExportValueArgs(&runtime, &compiler_wasm, "er_wasm_compiler_init", &init_args) catch return finishErrorCode(.render_failed);
    last_compiler_status = @intCast(init_result.valueI32(0) catch return finishErrorCode(.render_failed));
    if (last_compiler_status != 0) {
        recordCompilerDiagnostic(&runtime);
        return finishErrorCode(.bad_input);
    }

    const compile_args = [_]wasm_interpreter.Value{
        .{ .i32 = compiler_memory_ptr },
        .{ .i32 = compiler_memory_len },
        .{ .i32 = 0 },
        .{ .i32 = 0 },
        .{ .i32 = source_ptr },
        .{ .i32 = source_len },
    };
    const compile_result = wasm_interpreter.executeExportValueArgs(&runtime, &compiler_wasm, "er_wasm_compiler_compile_wasm", &compile_args) catch return finishErrorCode(.render_failed);
    last_compiler_status = @intCast(compile_result.valueI32(0) catch return finishErrorCode(.render_failed));
    if (last_compiler_status != 0) {
        recordCompilerDiagnostic(&runtime);
        return finishErrorCode(.bad_input);
    }

    const output_len_result = wasm_interpreter.executeExportValueArgs(&runtime, &compiler_wasm, "er_wasm_compiler_output_len", &.{}) catch return finishErrorCode(.render_failed);
    const output_ptr_result = wasm_interpreter.executeExportValueArgs(&runtime, &compiler_wasm, "er_wasm_compiler_output_ptr", &.{}) catch return finishErrorCode(.render_failed);
    const output_ptr: usize = @intCast(output_ptr_result.valueI32(0) catch return finishErrorCode(.render_failed));
    const output_len: usize = @intCast(output_len_result.valueI32(0) catch return finishErrorCode(.render_failed));
    if (output_len < 4 or output_len > release_artifact.len) return finishErrorCode(.bad_input);
    if (output_ptr > compiler_runtime_memory.len or output_len > compiler_runtime_memory.len - output_ptr) return finishErrorCode(.bad_input);
    if (!std.mem.eql(u8, compiler_runtime_memory[output_ptr..][0..4], &.{ 0x00, 0x61, 0x73, 0x6d })) return finishErrorCode(.bad_input);

    @memcpy(release_artifact[0..output_len], compiler_runtime_memory[output_ptr .. output_ptr + output_len]);
    release_artifact_len = output_len;
    last_compiler_status = 0;
    last_compiler_diagnostic_len = 0;
    last_error = .ok;
    return .ok;
}

fn recordCompilerDiagnostic(runtime: *wasm_interpreter.Runtime) void {
    const ptr_result = wasm_interpreter.executeExportValueArgs(runtime, &compiler_wasm, "er_wasm_compiler_diagnostic_ptr", &.{}) catch {
        last_compiler_diagnostic_len = 0;
        return;
    };
    const len_result = wasm_interpreter.executeExportValueArgs(runtime, &compiler_wasm, "er_wasm_compiler_diagnostic_len", &.{}) catch {
        last_compiler_diagnostic_len = 0;
        return;
    };
    const ptr: usize = @intCast(ptr_result.valueI32(0) catch {
        last_compiler_diagnostic_len = 0;
        return;
    });
    const len: usize = @intCast(len_result.valueI32(0) catch {
        last_compiler_diagnostic_len = 0;
        return;
    });
    if (ptr > runtime.memory.len) {
        last_compiler_diagnostic_len = 0;
        return;
    }
    const bounded_len = @min(len, @min(last_compiler_diagnostic.len, runtime.memory.len - ptr));
    if (bounded_len > 0) @memcpy(last_compiler_diagnostic[0..bounded_len], runtime.memory[ptr..][0..bounded_len]);
    last_compiler_diagnostic_len = bounded_len;
}

fn finishErrorCode(code: ErrorCode) ErrorCode {
    last_error = code;
    return code;
}

fn alignForward(value: usize, alignment: usize) usize {
    const remainder = value % alignment;
    if (remainder == 0) return value;
    return value + (alignment - remainder);
}

fn pagesForBytes(value: usize) usize {
    return (value + wasm_page_bytes - 1) / wasm_page_bytes;
}

export fn er_ui_site_scroll_by(delta_y: f32, width: f32, height: f32) u32 {
    if (!std.math.isFinite(delta_y) or !std.math.isFinite(width) or !std.math.isFinite(height)) return finishError(.bad_input);
    if (width <= 0.0 or height <= 0.0) return finishError(.bad_input);
    const limit = siteScrollLimit(width, height);
    site_state.scroll_y = std.math.clamp(site_state.scroll_y + delta_y, 0.0, limit);
    last_error = .ok;
    return @intFromEnum(ErrorCode.ok);
}

export fn er_ui_site_scroll_y() f32 {
    return site_state.scroll_y;
}

export fn er_ui_site_landing_content_height(width: f32) f32 {
    return site_frame.contentHeight(width, .{ .route = .{ .view = .landing } });
}

export fn er_ui_site_blog_content_height(width: f32) f32 {
    return site_frame.contentHeight(width, .{ .route = .{ .view = .blog } });
}

export fn er_ui_site_blog_post_content_height(width: f32, post_id: u32) f32 {
    return site_frame.contentHeight(width, .{ .route = .{ .view = .blog, .selected_blog_post_id = post_id } });
}

export fn er_ui_site_apps_content_height(width: f32) f32 {
    return site_frame.contentHeight(width, .{ .route = .{ .view = .apps } });
}

export fn er_ui_site_docs_content_height(width: f32) f32 {
    return site_frame.contentHeight(width, .{ .route = .{ .view = .docs } });
}

export fn er_ui_site_content_height(width: f32) f32 {
    return site_frame.contentHeight(width, currentSiteFrameState(pointer_hover_x, pointer_hover_y, 0.0));
}

fn siteScrollLimit(width: f32, height: f32) f32 {
    return @max(0.0, er_ui_site_content_height(width) - height);
}

export fn er_ui_clear(width: u32, height: u32) u32 {
    const surface = beginFrame(width, height) orelse return finishError(.bad_size);
    surface.clear(.bg);
    last_error = .ok;
    return @intFromEnum(ErrorCode.ok);
}

export fn er_ui_render_component_gallery(width: u32, height: u32) u32 {
    return er_ui_render_component_gallery_scroll(width, height, 0.0);
}

export fn er_ui_render_component_gallery_scroll(width: u32, height: u32, scroll_y: f32) u32 {
    return er_ui_render_component_gallery_layout_gap_hover(width, height, scroll_y, @intFromEnum(component_gallery.LayoutMode.masonry), component_gallery.grid_gap_default, -1.0, -1.0);
}

export fn er_ui_render_component_gallery_layout_gap_hover(width: u32, height: u32, scroll_y: f32, layout_raw: u32, grid_gap: f32, hover_x: f32, hover_y: f32) u32 {
    const surface = beginFrame(width, height) orelse return finishError(.bad_size);

    var scene = ui.Scene.init(&commands);
    var frame_regions: [max_interaction_regions]interaction.Region = undefined;
    var collector = interaction.Collector.init(&frame_regions);
    site_frame.render(&scene, &collector, frameBounds(), componentGalleryFrameState(layout_raw, grid_gap, scroll_y, hover_x, hover_y)) catch return finishError(.render_failed);

    return finishCpuSceneFrame(surface, scene, collector.written(), .{ .enabled = true, .x = hover_x, .y = hover_y }, .bg);
}

export fn er_ui_build_component_gallery_frame(width: u32, height: u32, scroll_y: f32) u32 {
    return er_ui_build_component_gallery_frame_layout_gap_hover(width, height, scroll_y, @intFromEnum(component_gallery.LayoutMode.masonry), component_gallery.grid_gap_default, -1.0, -1.0);
}

export fn er_ui_build_component_gallery_frame_layout_gap_hover(width: u32, height: u32, scroll_y: f32, layout_raw: u32, grid_gap: f32, hover_x: f32, hover_y: f32) u32 {
    if (!setFrameSize(width, height)) return finishError(.bad_size);

    return buildPackedSiteFrameFromPreparedSize(componentGalleryFrameState(layout_raw, grid_gap, scroll_y, hover_x, hover_y));
}

export fn er_ui_build_site_landing_frame(width: u32, height: u32, scroll_y: f32, hover_x: f32, hover_y: f32, frame_ms: f32) u32 {
    return buildPackedSiteFrame(width, height, .{
        .route = .{ .view = .landing },
        .scroll_y = scroll_y,
        .hover_x = hover_x,
        .hover_y = hover_y,
        .frame_ms = frame_ms,
        .public_identity = publicIdentityText(),
        .public_identity_ready = ephemeral_identity_ready,
    });
}

export fn er_ui_build_site_blog_frame(width: u32, height: u32, scroll_y: f32, hover_x: f32, hover_y: f32, selected_post_id: u32) u32 {
    return buildPackedSiteFrame(width, height, .{
        .route = .{ .view = .blog, .selected_blog_post_id = selected_post_id },
        .scroll_y = scroll_y,
        .hover_x = hover_x,
        .hover_y = hover_y,
    });
}

export fn er_ui_build_site_apps_frame(width: u32, height: u32, scroll_y: f32, hover_x: f32, hover_y: f32) u32 {
    return buildPackedSiteFrame(width, height, .{
        .route = .{ .view = .apps },
        .scroll_y = scroll_y,
        .hover_x = hover_x,
        .hover_y = hover_y,
    });
}

export fn er_ui_build_site_frame(width: u32, height: u32, hover_x: f32, hover_y: f32, frame_ms: f32) u32 {
    if (!setFrameSize(width, height)) return finishError(.bad_size);
    site_state.scroll_y = @min(site_state.scroll_y, siteScrollLimit(@floatFromInt(frame_width), @floatFromInt(frame_height)));

    return buildPackedSiteFrameFromPreparedSize(currentSiteFrameState(hover_x, hover_y, frame_ms));
}

fn buildPackedSiteFrame(width: u32, height: u32, state: site_frame.State) u32 {
    if (!setFrameSize(width, height)) return finishError(.bad_size);
    return buildPackedSiteFrameFromPreparedSize(state);
}

fn buildPackedSiteFrameFromPreparedSize(state: site_frame.State) u32 {
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var frame_regions: [max_interaction_regions]interaction.Region = undefined;
    var collector = interaction.Collector.init(&frame_regions);
    site_frame.render(&scene, &collector, frameBounds(), state) catch return finishError(.render_failed);
    return finishPackedFrame(scene, collector.written(), state.hover_x, state.hover_y);
}

export fn er_ui_build_frame(width: u32, height: u32, frame_ms: f32) u32 {
    return er_ui_build_site_frame(width, height, pointer_hover_x, pointer_hover_y, frame_ms);
}

export fn er_ui_render_frame(width: u32, height: u32, frame_ms: f32) u32 {
    const surface = beginFrame(width, height) orelse return finishError(.bad_size);
    return renderSitePixels(surface, pointer_hover_x, pointer_hover_y, frame_ms);
}

export fn er_ui_render_icon_svg_test(icon_id: u32, width: u32, height: u32) u32 {
    const surface = beginFrame(width, height) orelse return finishError(.bad_size);
    var scene = ui.Scene.initWithClips(&commands, &clips);
    scene.pushIconQuad(.{
        .bounds = ui.Rect.init(0, 0, @floatFromInt(frame_width), @floatFromInt(frame_height)),
        .icon_id = icon_id,
        .color = .{ .r = 255, .g = 255, .b = 255 },
    }) catch return finishError(.render_failed);
    return finishCpuSceneFrame(surface, scene, &.{}, .{ .enabled = false }, .clear);
}

export fn er_ui_render_icon_svg_tuning_test(icon_id: u32, width: u32, height: u32, curve_segments: u32, stroke_antialias_width: f32, round_cap_antialias_width: f32, line_stroke_coverage_boost: f32, curve_stroke_coverage_boost: f32, arc_stroke_coverage_boost: f32, arc_antialias_width: f32, large_arc_antialias_width: f32, arc_step_divisor: f32, large_arc_step_divisor: f32) u32 {
    renderer_pipeline.setIconTuningForTest(.{
        .curve_segments = @intCast(curve_segments),
        .stroke_antialias_width = stroke_antialias_width,
        .round_cap_antialias_width = round_cap_antialias_width,
        .line_stroke_coverage_boost = line_stroke_coverage_boost,
        .curve_stroke_coverage_boost = curve_stroke_coverage_boost,
        .arc_stroke_coverage_boost = arc_stroke_coverage_boost,
        .arc_antialias_width = arc_antialias_width,
        .large_arc_antialias_width = large_arc_antialias_width,
        .arc_step_divisor = arc_step_divisor,
        .large_arc_step_divisor = large_arc_step_divisor,
    }) catch return finishError(.render_failed);
    defer renderer_pipeline.resetIconTuningForTest();
    return er_ui_render_icon_svg_test(icon_id, width, height);
}

fn renderSitePixels(surface: renderer_pipeline.SoftwareFramebuffer, hover_x: f32, hover_y: f32, frame_ms: f32) u32 {
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var frame_regions: [max_interaction_regions]interaction.Region = undefined;
    var collector = interaction.Collector.init(&frame_regions);
    site_frame.render(&scene, &collector, frameBounds(), currentSiteFrameState(hover_x, hover_y, frame_ms)) catch return finishError(.render_failed);
    return finishCpuSceneFrame(surface, scene, collector.written(), .{ .enabled = true, .x = hover_x, .y = hover_y }, .bg);
}

fn finishPackedFrame(scene: ui.Scene, regions: []const interaction.Region, hover_x: f32, hover_y: f32) u32 {
    const frame_scene = prepareFrameScene(scene, regions, .{ .enabled = true, .x = hover_x, .y = hover_y }) catch return finishError(.render_failed);
    ensureFontAtlas() catch return finishError(.font_atlas);
    const buffers = packedBuffers();
    renderer_pipeline.packSceneWithSources(buffers, packedSources(), frame_scene.written()) catch return finishError(.packed_budget);
    packPackedIconLines() catch return finishError(.packed_budget);
    presentPackedBuffers(buffers) catch return finishError(.render_failed);
    last_error = .ok;
    return @intFromEnum(ErrorCode.ok);
}

const HoverUpdate = struct {
    enabled: bool,
    x: f32 = 0.0,
    y: f32 = 0.0,
};

fn finishCpuSceneFrame(surface: renderer_pipeline.SoftwareFramebuffer, scene: ui.Scene, regions: []const interaction.Region, hover: HoverUpdate, background: ui.Color) u32 {
    const frame_scene = prepareFrameScene(scene, regions, hover) catch return finishError(.render_failed);
    renderSceneIr(surface, frame_scene.written(), background) catch return finishError(.render_failed);
    last_error = .ok;
    return @intFromEnum(ErrorCode.ok);
}

fn prepareFrameScene(scene: ui.Scene, regions: []const interaction.Region, hover: HoverUpdate) !ui.Scene {
    try storeLastRegions(regions);
    if (hover.enabled) runtime_state.refreshHover(lastRegions(), hover.x, hover.y);
    var frame_scene = scene;
    if (hover.enabled) try site_cursor.render(&frame_scene, hover.x, hover.y, currentCursorKind());
    last_command_count = frame_scene.written().len;
    return frame_scene;
}

export fn er_ui_render_input_object(input_len: usize, width: u32, height: u32) u32 {
    if (input_len == 0 or input_len > input_bytes.len) return finishError(.bad_input);
    const surface = beginFrame(width, height) orelse return finishError(.bad_size);

    const root = ui_codec.decodeObject(input_bytes[0..input_len], &nodes) catch return finishError(.bad_ui);
    var scene = ui.Scene.init(&commands);
    ui_components.renderNode(&scene, .{
        .x = 0,
        .y = 0,
        .w = @floatFromInt(frame_width),
        .h = @floatFromInt(frame_height),
    }, root, .{}) catch return finishError(.render_failed);

    return finishCpuSceneFrame(surface, scene, &.{}, .{ .enabled = false }, .bg);
}

fn beginFrame(width_raw: u32, height_raw: u32) ?renderer_pipeline.SoftwareFramebuffer {
    const width: usize = width_raw;
    const height: usize = height_raw;
    if (!setFrameSize(width, height)) return null;
    return renderer_pipeline.softwareFramebuffer(width, height, pixels[0 .. width * height]) catch null;
}

fn renderSceneIr(surface: renderer_pipeline.SoftwareFramebuffer, scene_commands: []const ui.Command, background: ui.Color) !void {
    try ensureFontAtlas();
    const buffers = packedBuffers();
    try renderer_pipeline.packSceneWithSources(buffers, packedSources(), scene_commands);
    const image_texture = try site_images.cloudMeme();
    const receipt = try renderer_pipeline.renderSoftwareFrame(surface, buffers, renderer_pipeline.softwareResourcesFromAlphaAtlas(.{
        .width = font_atlas_width,
        .height = font_atlas_height,
        .alpha = &font_atlas_alpha,
    }, image_texture), background);
    recordPresentation(receipt);
}

fn presentPackedBuffers(buffers: renderer_pipeline.Buffers) renderer_pipeline.Error!void {
    const receipt = try renderer_pipeline.presentPackedFrame(
        @intCast(frame_width),
        @intCast(frame_height),
        buffers,
        renderer_pipeline.presentationResources(true, true),
    );
    recordPresentation(receipt);
}

fn packPackedIconLines() renderer_pipeline.IconLineError!void {
    try renderer_pipeline.packIconLines(
        packed_icon_vertex_floats[0..packed_icon_vertex_float_len],
        &packed_icon_line_vertex_floats,
        &packed_icon_line_vertex_float_len,
    );
    try renderer_pipeline.packIconLines(
        packed_overlay_icon_vertex_floats[0..packed_overlay_icon_vertex_float_len],
        &packed_overlay_icon_line_vertex_floats,
        &packed_overlay_icon_line_vertex_float_len,
    );
}

fn recordPresentation(receipt: renderer_pipeline.Receipt) void {
    last_present_primitive_count = receipt.primitive_count;
    last_present_transport = receipt.transport;
}

fn setFrameSize(width: usize, height: usize) bool {
    if (width == 0 or height == 0 or width > max_width or height > max_height) return false;
    frame_width = width;
    frame_height = height;
    return true;
}

fn finishError(code: ErrorCode) u32 {
    last_error = code;
    return @intFromEnum(code);
}

const EntropyEvent = enum(u8) {
    pointer_down = 1,
    pointer_move = 2,
    pointer_up = 3,
};

fn initialEntropyPool() [entropy_pool_size]u8 {
    return initial_entropy_pool;
}

fn mixInteractionEntropy(event: EntropyEvent, x: f32, y: f32) void {
    entropy_event_count +%= 1;
    var hasher = std.crypto.hash.Blake3.init(.{});
    hasher.update("edgerun:zig:wasm-site:interaction-event:v1");
    hasher.update(&entropy_pool);
    var record: [21]u8 = undefined;
    record[0] = @intFromEnum(event);
    writeU64(record[1..9], entropy_event_count);
    writeU32(record[9..13], @bitCast(x));
    writeU32(record[13..17], @bitCast(y));
    writeU32(record[17..21], @as(u32, @truncate(last_command_count)));
    hasher.update(&record);
    hasher.final(&entropy_pool);
}

fn generateEphemeralIdentity() !void {
    var hasher = std.crypto.hash.Blake3.init(.{});
    hasher.update("edgerun:zig:wasm-site:ephemeral-ed25519-seed:v1");
    hasher.update(&entropy_pool);
    var event_bytes: [8]u8 = undefined;
    writeU64(&event_bytes, entropy_event_count);
    hasher.update(&event_bytes);
    hasher.final(&ephemeral_seed);

    const keypair = try std.crypto.sign.Ed25519.KeyPair.generateDeterministic(ephemeral_seed);
    ephemeral_public_key = keypair.public_key.toBytes();
    const source = identity.Source.prepare(.ed25519_public, &ephemeral_public_key) orelse return error.Identity;
    const value = identity.Identity.init(.ephemeral, source, epochFromPublicKey(&ephemeral_public_key)) orelse return error.Identity;
    if (!value.valid()) return error.Identity;
    ephemeral_identity_id = value.id.bytes;
    writePublicIdentityText(&ephemeral_identity_id);
    ephemeral_identity_ready = true;
}

fn epochFromPublicKey(public_key: *const [identity.ed25519_public_size]u8) clock.Stamp {
    var keeper: [clock.keeper_id_size]u8 = undefined;
    std.crypto.hash.Blake3.hash(public_key, &keeper, .{});
    return .{ .keeper = .{ .bytes = keeper } };
}

fn publicIdentityText() []const u8 {
    if (!ephemeral_identity_ready) return "click reveal";
    return public_identity_text[0..];
}

fn writePublicIdentityText(id: *const [identity.id_size]u8) void {
    @memcpy(public_identity_text[0..public_identity_prefix.len], public_identity_prefix);
    writeHex(public_identity_text[public_identity_prefix.len..], id);
}

fn writeHex(out: []u8, value: []const u8) void {
    std.debug.assert(out.len == value.len * 2);
    for (value, 0..) |byte, index| {
        out[index * 2] = hexChar(byte >> 4);
        out[index * 2 + 1] = hexChar(byte & 0x0f);
    }
}

fn hexChar(value: u8) u8 {
    return switch (value) {
        0...9 => '0' + value,
        10...15 => 'a' + value - 10,
        else => unreachable,
    };
}

fn writeU64(out: []u8, value: u64) void {
    std.debug.assert(out.len == 8);
    for (0..8) |index| out[index] = @intCast((value >> @intCast(index * 8)) & 0xff);
}

fn writeU32(out: []u8, value: u32) void {
    std.debug.assert(out.len == 4);
    for (0..4) |index| out[index] = @intCast((value >> @intCast(index * 8)) & 0xff);
}

fn lastCommands() []const ui.Command {
    return commands[0..last_command_count];
}

fn lastRegions() []const interaction.Region {
    return interaction_regions[0..last_region_count];
}

fn storeLastRegions(regions: []const interaction.Region) error{InteractionBudgetExceeded}!void {
    if (regions.len > interaction_regions.len) return error.InteractionBudgetExceeded;
    @memcpy(interaction_regions[0..regions.len], regions);
    last_region_count = regions.len;
}

fn componentGalleryFrameState(layout_raw: u32, grid_gap: f32, scroll_y: f32, hover_x: f32, hover_y: f32) site_frame.State {
    return .{
        .route = .{
            .view = .components,
            .selected_component_index = site_state.selected_component_index,
        },
        .scroll_y = scroll_y,
        .hover_x = hover_x,
        .hover_y = hover_y,
        .component_layout = component_gallery.LayoutMode.fromRaw(layout_raw),
        .component_grid_gap = grid_gap,
    };
}

fn currentSiteFrameState(hover_x: f32, hover_y: f32, frame_ms: f32) site_frame.State {
    return .{
        .route = currentRoute(),
        .scroll_y = site_state.scroll_y,
        .hover_x = hover_x,
        .hover_y = hover_y,
        .frame_ms = frame_ms,
        .public_identity = publicIdentityText(),
        .public_identity_ready = ephemeral_identity_ready,
        .source = if (site_state.view == .source) currentSourceFrameState(hover_x, hover_y) else .{},
    };
}

fn currentSourceFrameState(hover_x: f32, hover_y: f32) site_source.State {
    ensureSourceEditor();
    return .{
        .scroll_y = site_state.scroll_y,
        .hover_x = hover_x,
        .hover_y = hover_y,
        .label = source_editor_label,
        .source = source_editor_bytes[0..source_editor_len],
        .cursor = source_editor_cursor,
        .workspace_bytes = source_workspace_len,
        .file_bytes = source_editor_len,
        .release_bytes = release_artifact_len,
        .dirty = source_editor_dirty,
        .status = sourceEditorStatusText(source_editor_status),
    };
}

fn sourceEditorStatusText(status: SourceEditorStatus) []const u8 {
    return switch (status) {
        .not_loaded => "source editor not loaded",
        .ready => "ready: editing src/ui_browser.zig inside the app-owned VFS object",
        .dirty => "dirty: canonical workspace rebuilt in wasm memory",
        .missing_file => "error: source file missing from workspace object",
        .corrupt_workspace => "error: source workspace object is corrupt",
        .editor_too_large => "error: source file exceeds editor memory budget",
        .workspace_full => "error: rewritten workspace exceeds app memory budget",
    };
}

fn frameBounds() ui.Rect {
    return ui.Rect.init(0, 0, @floatFromInt(frame_width), @floatFromInt(frame_height));
}

fn applyRoutePath(path: []const u8) void {
    applyRoute(site_navigation.fromPath(path));
}

fn applyRoute(route: site_navigation.Route) void {
    site_state.resetScroll();
    site_state.view = route.view;
    site_state.selected_blog_post_id = route.selected_blog_post_id;
    site_state.blog_arc_filter_index = route.blog_arc_filter_index;
    site_state.selected_component_index = route.selected_component_index;
}

fn trimRoute(path: []const u8) []const u8 {
    return site_navigation.trimPath(path);
}

fn routePathFromHash(hash: []const u8) error{InvalidRouteHash}![]const u8 {
    return site_navigation.pathFromHash(hash);
}

fn refreshRoutePath() void {
    route_len = site_navigation.writePath(&route_bytes, currentRoute()) catch unreachable;
}

fn refreshRouteHash() void {
    route_hash_len = site_navigation.writeHash(&route_hash_bytes, currentRoute()) catch unreachable;
}

fn currentRoute() site_navigation.Route {
    return .{
        .view = site_state.view,
        .selected_blog_post_id = site_state.selected_blog_post_id,
        .blog_arc_filter_index = site_state.blog_arc_filter_index,
        .selected_component_index = site_state.selected_component_index,
    };
}

fn currentCursorKind() CursorKind {
    const action_kind: ui_runtime.ActionKind = @enumFromInt(@as(u8, @intCast(last_action_kind)));
    return site_cursor.fromState(action_kind, runtime_state.hoverKind());
}

fn currentHoverHitKind() u32 {
    return if (runtime_state.hoverKind()) |kind| @intFromEnum(kind) else hover_hit_kind_none;
}

fn currentHoverHitId() u32 {
    return runtime_state.hoverHitId();
}

fn recordAction(action: ui_runtime.Action) void {
    last_action_kind = @intFromEnum(action.kind);
    last_action_hit_id = if (action.hit) |hit| hit.id else 0;
    last_action_scope_id = if (action.source) |source| source.scope_id else 0;
    last_action_from_index = if (action.source) |source| @intCast(source.index) else 0;
    last_action_to_index = if (action.target) |target| @intCast(target.index) else 0;
}

fn hasRectColor(items: []const ui.Command, color: ui.Color) bool {
    for (items) |command| switch (command) {
        .rect => |rect| if (std.meta.eql(rect.color, color)) return true,
        else => {},
    };
    return false;
}

fn ensureFontAtlas() !void {
    if (font_atlas_ready) return;
    @memset(&font_atlas_alpha, 0);
    font_glyph_count = 0;
    font_atlas_x = font_padding;
    font_atlas_y = font_padding;
    font_atlas_row_h = 0;
    font_atlas_device_scale = font_device_scale;
    font_atlas_generation +%= 1;
    font_atlas_ready = true;
}

fn getFontGlyph(ch: u8, px: u8) error{Budget}!?FontGlyph {
    try ensureFontAtlas();
    if (findFontGlyph(ch, px)) |glyph| return glyph;
    return cacheFontGlyph(ch, px) catch |err| switch (err) {
        error.GlyphBitmapBudgetExceeded, error.GlyphCacheFull => error.Budget,
        error.InvalidFont,
        error.MissingTable,
        error.UnsupportedCmap,
        error.UnsupportedGlyph,
        error.GlyphPointBudgetExceeded,
        error.GlyphEdgeBudgetExceeded,
        => null,
    };
}

fn cacheFontGlyph(ch: u8, px: u8) varfont.Error!FontGlyph {
    if (font_glyph_count >= font_glyphs.len) return error.GlyphCacheFull;
    const face = try varfont.Face.geist();
    var cache = varfont.Cache.init(face, &font_bitmap);
    _ = cache.setAxis("wght", 560.0);

    const glyph_id = face.glyphId(ch);
    const bake_px = @as(f32, @floatFromInt(px)) * font_atlas_device_scale;
    const cached = try cache.bakeGlyph(glyph_id, bake_px);
    const view = cache.bitmapView(cached);
    const gw: usize = view.width;
    const gh: usize = view.height;
    var atlas_x = font_atlas_x;
    var atlas_y = font_atlas_y;
    var atlas_u0: f32 = 0.0;
    var atlas_v0: f32 = 0.0;
    var atlas_u1: f32 = 0.0;
    var atlas_v1: f32 = 0.0;

    if (gw > 0 and gh > 0) {
        if (font_atlas_x + gw + font_padding >= font_atlas_width) {
            font_atlas_x = font_padding;
            font_atlas_y += font_atlas_row_h + font_row_gap;
            font_atlas_row_h = 0;
        }
        if (font_atlas_y + gh + font_padding >= font_atlas_height) return error.GlyphBitmapBudgetExceeded;
        atlas_x = font_atlas_x;
        atlas_y = font_atlas_y;
        copyFontGlyphBitmap(atlas_x, atlas_y, gw, gh, view.pixels);
        font_atlas_row_h = @max(font_atlas_row_h, gh);
        font_atlas_x += gw + font_row_gap;
        atlas_u0 = (@as(f32, @floatFromInt(atlas_x)) + 0.5) / @as(f32, @floatFromInt(font_atlas_width));
        atlas_v0 = (@as(f32, @floatFromInt(atlas_y)) + 0.5) / @as(f32, @floatFromInt(font_atlas_height));
        atlas_u1 = (@as(f32, @floatFromInt(atlas_x + gw)) - 0.5) / @as(f32, @floatFromInt(font_atlas_width));
        atlas_v1 = (@as(f32, @floatFromInt(atlas_y + gh)) - 0.5) / @as(f32, @floatFromInt(font_atlas_height));
        font_atlas_generation +%= 1;
    }

    const glyph: FontGlyph = .{
        .ch = ch,
        .px = px,
        .u0 = atlas_u0,
        .v0 = atlas_v0,
        .u1 = atlas_u1,
        .v1 = atlas_v1,
        .w = scaledFontValue(@floatFromInt(gw)),
        .h = scaledFontValue(@floatFromInt(gh)),
        .source_w = view.width,
        .source_h = view.height,
        .left = scaledFontValue(@floatFromInt(cached.left)),
        .top = scaledFontValue(@floatFromInt(cached.top)),
        .advance = scaledFontValue(cached.advance),
    };
    font_glyphs[font_glyph_count] = glyph;
    font_glyph_count += 1;
    return glyph;
}

fn copyFontGlyphBitmap(x: usize, y: usize, w: usize, h: usize, source: []const u8) void {
    var row: usize = 0;
    while (row < h) : (row += 1) {
        const dst = (y + row) * font_atlas_width + x;
        const src = row * w;
        @memcpy(font_atlas_alpha[dst .. dst + w], source[src .. src + w]);
    }
}

fn findFontGlyph(ch: u8, px: u8) ?FontGlyph {
    for (font_glyphs[0..font_glyph_count]) |glyph| {
        if (glyph.ch == ch and glyph.px == px) return glyph;
    }
    return null;
}

fn scaledFontValue(value: f32) f32 {
    return value / font_atlas_device_scale;
}

fn normalizedDeviceScale(scale: f32) f32 {
    if (!std.math.isFinite(scale)) return 2.0;
    return std.math.clamp(scale, 2.0, 4.0);
}

fn fontMetrics(px: u8) renderer_pipeline.TextMetrics {
    const face = varfont.Face.geist() catch unreachable;
    const metrics = face.metrics(@floatFromInt(px));
    return .{ .ascender = metrics.ascender, .descender = metrics.descender };
}

fn textWidth(value: []const u8, px: u8) f32 {
    const face = varfont.Face.geist() catch return 0.0;
    const px_size: f32 = @floatFromInt(px);
    var out: f32 = 0.0;
    var previous: u16 = 0;
    for (value) |byte| {
        if (byte < font_first_char or byte > font_last_char) continue;
        const glyph_id = face.glyphId(byte);
        if (previous != 0) out += face.kern(previous, glyph_id, px_size);
        out += face.advance(glyph_id, px_size);
        previous = glyph_id;
    }
    return out;
}

fn expectSourceDoesNotContain(needle: []const u8) !void {
    const source = @embedFile("ui_browser.zig");
    try std.testing.expect(std.mem.indexOf(u8, source, needle) == null);
}

test "wasm render bridge exports neutral frame and outbox names" {
    try expectSourceDoesNotContain("er_ui_" ++ "gpu_");
    try expectSourceDoesNotContain("er_ui_" ++ "browser_");
    try expectSourceDoesNotContain("er_ui_" ++ "host_");
    try expectSourceDoesNotContain("gpu_" ++ "budget");
    try expectSourceDoesNotContain("present" ++ "BrowserFrame");
}

test "browser hover state exposes interaction region kind and id" {
    var regions: [1]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    try collector.addHit(ui.Rect.init(10, 20, 40, 30), .button, 42);

    runtime_state.refreshHover(collector.written(), 20, 30);
    try std.testing.expectEqual(@intFromEnum(ui.HitKind.button), er_ui_hover_hit_kind());
    try std.testing.expectEqual(@as(u32, 42), er_ui_hover_hit_id());

    runtime_state.refreshHover(collector.written(), -1, -1);
    try std.testing.expectEqual(hover_hit_kind_none, er_ui_hover_hit_kind());
    try std.testing.expectEqual(@as(u32, 0), er_ui_hover_hit_id());
}

test "browser ir finish preserves hover state when disabled" {
    runtime_state.hovered = .{ .kind = .button, .id = 99, .bounds = ui.Rect.init(0, 0, 1, 1) };
    var local_commands: [1]ui.Command = undefined;
    const scene = ui.Scene.init(&local_commands);
    var local_pixels: [4]ui.Color = undefined;
    const surface = try renderer_pipeline.softwareFramebuffer(2, 2, &local_pixels);

    try std.testing.expectEqual(@as(u32, 0), finishCpuSceneFrame(surface, scene, &.{}, .{ .enabled = false }, .bg));
    try std.testing.expectEqual(@intFromEnum(ui.HitKind.button), er_ui_hover_hit_kind());
    try std.testing.expectEqual(@as(u32, 99), er_ui_hover_hit_id());
}

test "browser component gallery builds packed browser buffers and browser-ready icon lines" {
    font_atlas_ready = false;
    const code = er_ui_build_component_gallery_frame_layout_gap_hover(960, 640, 0.0, @intFromEnum(component_gallery.LayoutMode.masonry), component_gallery.grid_gap_default, -1.0, -1.0);
    try std.testing.expectEqual(@as(u32, 0), code);
    try std.testing.expect(font_atlas_ready);
    try std.testing.expectEqual(renderer_pipeline.Transport.packed_buffers, last_present_transport);
    try std.testing.expect(last_present_primitive_count > 0);
    try std.testing.expect(packed_rect_float_len > 0);
    try std.testing.expect(packed_text_vertex_float_len > 0);
    try std.testing.expect(packed_icon_vertex_float_len > 0);
    try std.testing.expect(packed_icon_line_vertex_float_len > 0);
    try std.testing.expect(er_ui_font_atlas_ptr() != 0);
}

test "browser component gallery render uses canonical ir buffers" {
    const code = er_ui_render_component_gallery_layout_gap_hover(480, 360, 0.0, @intFromEnum(component_gallery.LayoutMode.masonry), component_gallery.grid_gap_default, -1.0, -1.0);
    try std.testing.expectEqual(@as(u32, 0), code);
    try std.testing.expectEqual(renderer_pipeline.Transport.pixel_bytes, last_present_transport);
    try std.testing.expect(last_present_primitive_count > 0);
    try std.testing.expect(packed_rect_float_len > 0);
    try std.testing.expect(packed_text_vertex_float_len > 0);
    try std.testing.expect(packed_icon_vertex_float_len > 0);
    var painted: usize = 0;
    for (pixels[0 .. frame_width * frame_height]) |pixel| {
        if (!std.meta.eql(pixel, ui.Color.bg)) painted += 1;
    }
    try std.testing.expect(painted > 0);
}

test "browser site landing builds packed browser buffers and hit state" {
    const code = er_ui_build_site_landing_frame(1280, 800, 0.0, 1065.0, 32.0, 0.0);
    try std.testing.expectEqual(@as(u32, 0), code);
    try std.testing.expect(packed_rect_float_len > 0);
    try std.testing.expect(packed_text_vertex_float_len > 0);
    try std.testing.expect(packed_icon_vertex_float_len > 0);
    try std.testing.expectEqual(site_landing.contentHeight(1280.0), er_ui_site_landing_content_height(1280.0));
    try std.testing.expectEqual(@intFromEnum(ui.HitKind.button), er_ui_hover_hit_kind());
    try std.testing.expectEqual(site_chrome.source_button_id, er_ui_hover_hit_id());
}

test "browser site reveal derives public identity inside wasm from interaction" {
    ephemeral_identity_ready = false;
    entropy_pool = initialEntropyPool();
    entropy_event_count = 0;
    defer {
        ephemeral_identity_ready = false;
        entropy_pool = initialEntropyPool();
        entropy_event_count = 0;
    }

    const before = publicIdentityText();
    try std.testing.expectEqualStrings("click reveal", before);
    _ = er_ui_build_site_landing_frame(1280, 800, 0.0, 108.0, 500.0, 333.0);
    _ = er_ui_pointer_down(108.0, 500.0);
    _ = er_ui_pointer_up(108.0, 500.0);
    try std.testing.expectEqual(@intFromEnum(UiAction.none), er_ui_site_activate_hit(site_landing.reveal_identity_button_id));
    try std.testing.expect(ephemeral_identity_ready);
    try std.testing.expectEqual(@as(usize, public_identity_text_len), publicIdentityText().len);
    try std.testing.expect(std.mem.startsWith(u8, publicIdentityText(), public_identity_prefix));
    try std.testing.expect(identity.Source.prepare(.ed25519_public, &ephemeral_public_key) != null);
}

test "browser site blog builds packed browser buffers and post hit state" {
    const code = er_ui_build_site_blog_frame(1280, 800, 0.0, 340.0, 700.0, 0);
    try std.testing.expectEqual(@as(u32, 0), code);
    try std.testing.expect(packed_rect_float_len > 0);
    try std.testing.expect(packed_text_vertex_float_len > 0);
    try std.testing.expect(packed_icon_vertex_float_len > 0);
    try std.testing.expect(packed_image_vertex_float_len > 0);
    try std.testing.expect(er_ui_post_image_rgba_ptr() != 0);
    try std.testing.expectEqual(site_images.cloud_meme_width, er_ui_post_image_width());
    try std.testing.expectEqual(site_images.cloud_meme_height, er_ui_post_image_height());
    try std.testing.expectEqual(site_images.cloud_meme_pixel_count * @sizeOf(ui.Color), er_ui_post_image_rgba_len());
    try std.testing.expectEqual(@as(u32, @intCast(site_blog.posts.len)), er_ui_blog_post_count());
    try std.testing.expect(er_ui_site_blog_content_height(1280.0) > 5200.0);
    try std.testing.expect(er_ui_site_blog_post_content_height(1280.0, site_blog.postIdAt(16)) > 1200.0);
    try std.testing.expectEqual(@intFromEnum(ui.HitKind.button), er_ui_hover_hit_kind());
    try std.testing.expectEqual(site_blog.postIdAt(0), er_ui_hover_hit_id());
}

test "browser site apps builds packed browser buffers and hit state" {
    const code = er_ui_build_site_apps_frame(1280, 900, 0.0, 360.0, 700.0);
    try std.testing.expectEqual(@as(u32, 0), code);
    try std.testing.expect(packed_rect_float_len > 0);
    try std.testing.expect(packed_text_vertex_float_len > 0);
    try std.testing.expect(packed_icon_vertex_float_len > 0);
    try std.testing.expectEqual(site_apps.contentHeight(1280.0), er_ui_site_apps_content_height(1280.0));
    try std.testing.expectEqual(@intFromEnum(ui.HitKind.button), er_ui_hover_hit_kind());
    try std.testing.expectEqual(site_apps.first_app_button_id, er_ui_hover_hit_id());
    try std.testing.expectEqual(@intFromEnum(CursorKind.pointer), er_ui_cursor_kind());
    try std.testing.expect(hasRectColor(lastCommands(), site_cursor.accent));
}

test "browser site activation keeps page state in wasm" {
    site_state = .{};
    defer site_state = .{};

    try std.testing.expectEqual(site_landing.contentHeight(1280.0), er_ui_site_content_height(1280.0));
    try std.testing.expectEqual(@intFromEnum(UiAction.none), er_ui_site_activate_hit(site_chrome.blog_button_id));
    try std.testing.expectEqual(site_blog.indexContentHeight(1280.0), er_ui_site_content_height(1280.0));
    try std.testing.expectEqual(@intFromEnum(UiAction.none), er_ui_site_activate_hit(site_blog.postIdAt(0)));
    try std.testing.expectEqual(site_blog.postContentHeight(1280.0, site_blog.postIdAt(0)), er_ui_site_content_height(1280.0));
    try std.testing.expectEqual(@intFromEnum(UiAction.none), er_ui_site_activate_hit(site_chrome.source_button_id));
    try std.testing.expectEqualStrings("/source", route_bytes[0..er_ui_site_route_path_len()]);
    try std.testing.expectEqual(@intFromEnum(UiAction.none), er_ui_site_action_kind());
    try std.testing.expectEqual(@as(u32, 0), er_ui_outbox_count());
    try std.testing.expectEqual(@as(u32, 0), er_ui_outbox_clear());
    try std.testing.expectEqual(@as(u32, 0), er_ui_outbox_count());
    try std.testing.expectEqual(@intFromEnum(UiAction.none), er_ui_site_activate_hit(site_chrome.launch_button_id));
    try std.testing.expectEqual(@as(u32, 1), er_ui_outbox_count());
    try std.testing.expectEqual(@intFromEnum(OutboxKind.launch_wasm), er_ui_outbox_kind(0));
    try std.testing.expectEqual(er_ui_release_artifact_len(), er_ui_outbox_payload_len(0));
    try std.testing.expect(er_ui_outbox_payload_ptr(0) != 0);
    try std.testing.expectEqual(@as(usize, 0), er_ui_outbox_target_len(0));
    try std.testing.expectEqual(@as(u32, 0), er_ui_outbox_clear());
    try std.testing.expectEqual(@intFromEnum(UiAction.none), er_ui_site_activate_hit(site_chrome.logo_button_id));
    try std.testing.expectEqual(site_landing.contentHeight(1280.0), er_ui_site_content_height(1280.0));
    try std.testing.expectEqual(@intFromEnum(UiAction.none), er_ui_site_activate_hit(site_chrome.blog_button_id));
    try std.testing.expectEqual(@intFromEnum(UiAction.none), er_ui_site_activate_hit(site_blog.arcFilterButtonId(3)));
    try std.testing.expectEqual(site_blog.indexContentHeightFiltered(1280.0, 3), er_ui_site_content_height(1280.0));
    try std.testing.expectEqual(@intFromEnum(UiAction.none), er_ui_site_activate_hit(site_blog.all_lessons_button_id));
    try std.testing.expectEqual(site_blog.indexContentHeight(1280.0), er_ui_site_content_height(1280.0));
    try std.testing.expectEqual(@intFromEnum(UiAction.none), er_ui_site_activate_hit(site_chrome.apps_button_id));
    try std.testing.expectEqual(site_apps.contentHeight(1280.0), er_ui_site_content_height(1280.0));
    try std.testing.expectEqual(@intFromEnum(UiAction.none), er_ui_site_activate_hit(site_chrome.docs_button_id));
    try std.testing.expectEqual(site_docs.contentHeight(1280.0), er_ui_site_content_height(1280.0));
    try std.testing.expectEqual(@intFromEnum(UiAction.none), er_ui_site_activate_hit(site_docs.component_catalog_button_id));
    try std.testing.expectEqual(component_gallery.contentHeightForState(1280.0, .{}), er_ui_site_content_height(1280.0));
}

test "browser native route sync owns URL path state" {
    site_state = .{};
    defer site_state = .{};

    try std.testing.expectEqual(@as(u32, 0), er_ui_site_set_route_hash(writeInputForTest("#/academy")));
    try std.testing.expectEqual(site_blog.indexContentHeight(1280.0), er_ui_site_content_height(1280.0));
    try std.testing.expectEqualStrings("/academy", route_bytes[0..er_ui_site_route_path_len()]);
    try std.testing.expectEqualStrings("#/academy", route_hash_bytes[0..er_ui_site_route_hash_len()]);

    const route = "#/academy/40100";
    try std.testing.expectEqual(@as(u32, 0), er_ui_site_set_route_hash(writeInputForTest(route)));
    try std.testing.expectEqual(site_blog.postContentHeight(1280.0, site_blog.postIdAt(0)), er_ui_site_content_height(1280.0));
    try std.testing.expectEqualStrings("/academy/40100", route_bytes[0..er_ui_site_route_path_len()]);
    try std.testing.expectEqualStrings("#/academy/40100", route_hash_bytes[0..er_ui_site_route_hash_len()]);

    try std.testing.expectEqual(@as(u32, 0), er_ui_site_set_route_hash(writeInputForTest("")));
    try std.testing.expectEqual(site_landing.contentHeight(1280.0), er_ui_site_content_height(1280.0));
    try std.testing.expectEqualStrings("/", route_bytes[0..er_ui_site_route_path_len()]);
    try std.testing.expectEqualStrings("", route_hash_bytes[0..er_ui_site_route_hash_len()]);

    try std.testing.expectEqual(@as(u32, 0), er_ui_site_set_route_hash(writeInputForTest("#/apps")));
    try std.testing.expectEqual(site_apps.contentHeight(1280.0), er_ui_site_content_height(1280.0));
    try std.testing.expectEqualStrings("/apps", route_bytes[0..er_ui_site_route_path_len()]);

    try std.testing.expectEqual(@as(u32, 0), er_ui_site_set_route_hash(writeInputForTest("#/docs")));
    try std.testing.expectEqual(site_docs.contentHeight(1280.0), er_ui_site_content_height(1280.0));
    try std.testing.expectEqualStrings("/docs", route_bytes[0..er_ui_site_route_path_len()]);
    try std.testing.expectEqualStrings("#/docs", route_hash_bytes[0..er_ui_site_route_hash_len()]);

    try std.testing.expectEqual(@as(u32, 0), er_ui_site_set_route_hash(writeInputForTest("#/docs/components/button")));
    const button_index = component_gallery.indexBySlug("button").?;
    try std.testing.expectEqual(button_index, site_state.selected_component_index.?);
    try std.testing.expectEqual(component_gallery.contentHeightForState(1280.0, .{ .selected_component_index = button_index }), er_ui_site_content_height(1280.0));
    try std.testing.expectEqualStrings("/docs/components/button", route_bytes[0..er_ui_site_route_path_len()]);

    try std.testing.expectEqual(@as(u32, @intFromEnum(ErrorCode.bad_input)), er_ui_site_set_route_hash(writeInputForTest("#academy")));
    try std.testing.expectEqualStrings("/docs/components/button", route_bytes[0..er_ui_site_route_path_len()]);
}

fn writeInputForTest(value: []const u8) usize {
    @memcpy(input_bytes[0..value.len], value);
    return value.len;
}

fn eventBytesForTest(value: []const u8, width: f32, height: f32) u32 {
    return er_ui_event_bytes(writeInputForTest(value), width, height, 0);
}

fn keyEventForTest(value: []const u8, ctrl: bool, meta: bool, alt: bool) u32 {
    return er_ui_site_key_event(
        writeInputForTest(value),
        if (ctrl) 1 else 0,
        if (meta) 1 else 0,
        if (alt) 1 else 0,
    );
}

test "browser native key policy stays inert until an app owns text input" {
    site_state = .{};
    defer site_state = .{};

    try std.testing.expectEqual(@as(u32, 0), keyEventForTest("/", false, false, false));
    try std.testing.expectEqual(@as(u32, 0), keyEventForTest("k", true, false, false));
    try std.testing.expectEqual(@as(u32, 0), keyEventForTest("K", false, true, false));
    try std.testing.expectEqual(@as(u32, 0), keyEventForTest("x", false, false, true));
    try std.testing.expectEqual(@as(u32, 0), keyEventForTest("ArrowDown", false, false, false));
}

test "browser native event bytes keep browser decoding inside wasm" {
    site_state = .{};
    runtime_state = .{};
    pointer_hover_x = -1.0;
    pointer_hover_y = -1.0;
    defer site_state = .{};
    defer runtime_state = .{};

    try std.testing.expectEqual(
        input_event_schedule_frame,
        eventBytesForTest("pointermove\n42\n88\n0\n0\n0\n0\n", 1280.0, 900.0),
    );
    try std.testing.expectEqual(@as(f32, 42.0), pointer_hover_x);
    try std.testing.expectEqual(@as(f32, 88.0), pointer_hover_y);

    try std.testing.expectEqual(
        input_event_prevent_default | input_event_schedule_frame,
        eventBytesForTest("wheel\n0\n0\n120\n0\n0\n0\n", 1280.0, 900.0),
    );
    try std.testing.expectEqual(@as(f32, 120.0), site_state.scroll_y);

    try std.testing.expectEqual(
        input_event_schedule_frame,
        eventBytesForTest("hashchange\n0\n0\n0\n0\n0\n0\n#/apps", 1280.0, 900.0),
    );
    try std.testing.expectEqualStrings("/apps", route_bytes[0..er_ui_site_route_path_len()]);

    try std.testing.expectEqual(@as(u32, 0), eventBytesForTest("keyup\n0\n0\n0\n0\n0\n0\nk", 1280.0, 900.0));
}

test "browser native event pump owns dom event interpretation" {
    site_state = .{};
    runtime_state = .{};
    clearOutboxMessages();
    pointer_hover_x = -1.0;
    pointer_hover_y = -1.0;
    last_command_count = 0;
    defer site_state = .{};
    defer runtime_state = .{};
    defer clearOutboxMessages();

    try std.testing.expectEqual(input_event_schedule_frame, er_ui_event(@intFromEnum(InputEventKind.resize), 0, 0, 0, 0, 0, 0, 0, 1280.0, 900.0));

    const wheel_result = er_ui_event(@intFromEnum(InputEventKind.wheel), 0, 0, 320.0, 0, 0, 0, 0, 1280.0, 900.0);
    try std.testing.expectEqual(input_event_prevent_default | input_event_schedule_frame, wheel_result);
    try std.testing.expectEqual(@as(f32, 320.0), site_state.scroll_y);

    try std.testing.expectEqual(input_event_schedule_frame, er_ui_event(@intFromEnum(InputEventKind.pointer_move), 42.0, 88.0, 0, 0, 0, 0, 0, 1280.0, 900.0));
    try std.testing.expectEqual(@as(f32, 42.0), pointer_hover_x);
    try std.testing.expectEqual(@as(f32, 88.0), pointer_hover_y);
    try std.testing.expectEqual(input_event_schedule_frame, er_ui_event(@intFromEnum(InputEventKind.pointer_leave), 0, 0, 0, 0, 0, 0, 0, 1280.0, 900.0));
    try std.testing.expectEqual(@as(f32, -1.0), pointer_hover_x);
    try std.testing.expectEqual(@as(f32, -1.0), pointer_hover_y);

    try std.testing.expectEqual(@as(u32, 0), er_ui_event(@intFromEnum(InputEventKind.key_down), 0, 0, 0, 0, 0, 0, writeInputForTest("/"), 1280.0, 900.0));

    try std.testing.expectEqual(input_event_schedule_frame, er_ui_event(@intFromEnum(InputEventKind.hashchange), 0, 0, 0, 0, 0, 0, writeInputForTest("#/apps"), 1280.0, 900.0));
    try std.testing.expectEqualStrings("/apps", route_bytes[0..er_ui_site_route_path_len()]);

    try std.testing.expectEqual(input_event_error, er_ui_event(@intFromEnum(InputEventKind.hashchange), 0, 0, 0, 0, 0, 0, writeInputForTest("#apps"), 1280.0, 900.0));
    try std.testing.expectEqual(@intFromEnum(ErrorCode.bad_input), er_ui_last_error());
    try std.testing.expectEqualStrings("/apps", route_bytes[0..er_ui_site_route_path_len()]);

    site_state.queued_action = .none;
    last_command_count = 0;
    try storeLastRegions(&.{.{ .slot = 0, .kind = .button, .id = site_chrome.source_button_id, .bounds = ui.Rect.init(0, 0, 40, 40) }});
    const pointer_result = er_ui_event(@intFromEnum(InputEventKind.pointer_up), 8.0, 8.0, 0, 0, 0, 0, 0, 1280.0, 900.0);
    try std.testing.expectEqual(input_event_release_pointer | input_event_schedule_frame | input_event_outbox, pointer_result);
    try std.testing.expectEqual(@as(u32, 1), er_ui_outbox_count());
    try std.testing.expectEqual(@intFromEnum(OutboxKind.push_route_hash), er_ui_outbox_kind(0));
    try std.testing.expect(er_ui_outbox_id(0) != 0);
    try std.testing.expectEqualStrings("#/source", (@as([*]const u8, @ptrFromInt(er_ui_outbox_payload_ptr(0))))[0..er_ui_outbox_payload_len(0)]);
}

test "browser native boot emits document title host command" {
    clearOutboxMessages();
    defer clearOutboxMessages();

    const result = er_ui_boot();
    try std.testing.expectEqual(input_event_outbox | input_event_schedule_frame, result);
    try std.testing.expectEqual(@as(u32, 2), er_ui_outbox_count());
    try std.testing.expectEqual(@intFromEnum(OutboxKind.set_title), er_ui_outbox_kind(0));
    try std.testing.expect(er_ui_outbox_id(0) != 0);
    try std.testing.expectEqual(@as(usize, 0), er_ui_outbox_target_len(0));
    try std.testing.expectEqualStrings(title_text, (@as([*]const u8, @ptrFromInt(er_ui_outbox_payload_ptr(0))))[0..er_ui_outbox_payload_len(0)]);
    try std.testing.expectEqual(@intFromEnum(OutboxKind.set_element_html), er_ui_outbox_kind(1));
    try std.testing.expect(er_ui_outbox_id(1) != 0);
    try std.testing.expect(er_ui_outbox_id(0) != er_ui_outbox_id(1));
    try std.testing.expectEqualStrings(dom_surface_id, (@as([*]const u8, @ptrFromInt(er_ui_outbox_target_ptr(1))))[0..er_ui_outbox_target_len(1)]);
    try std.testing.expectEqualStrings(boot_dom_html, (@as([*]const u8, @ptrFromInt(er_ui_outbox_payload_ptr(1))))[0..er_ui_outbox_payload_len(1)]);
}

test "browser native records host appearance preference" {
    try std.testing.expectEqual(@as(u32, 1), er_ui_set_environment_appearance(1));
    try std.testing.expectEqual(@as(u32, 1), er_ui_environment_appearance());
    try std.testing.expectEqual(@as(u32, 2), er_ui_set_environment_appearance(2));
    try std.testing.expectEqual(@as(u32, 2), er_ui_environment_appearance());
    try std.testing.expectEqual(@as(u32, 0), er_ui_set_environment_appearance(99));
    try std.testing.expectEqual(@as(u32, 0), er_ui_environment_appearance());
}

test "browser native exposes eval bootstrap javascript bytes" {
    const bootstrap_js: [*]const u8 = @ptrFromInt(er_ui_bootstrap_js_ptr());
    const js_bytes = bootstrap_js[0..er_ui_bootstrap_js_len()];

    try std.testing.expectEqualStrings(browser_runtime_js.source, js_bytes);
    try std.testing.expect(std.mem.indexOf(u8, js_bytes, "document.body.innerHTML") != null);
    try std.testing.expect(std.mem.indexOf(u8, js_bytes, "WebAssembly.instantiate(") != null);
    try std.testing.expect(std.mem.indexOf(u8, js_bytes, "er_ui_compiler_wasm_ptr") == null);
    try std.testing.expect(std.mem.indexOf(u8, js_bytes, "er_wasm_compiler_compile_wasm") == null);
    try std.testing.expect(std.mem.indexOf(u8, js_bytes, "fetch(") == null);
}

test "browser native exposes repo-owned source as canonical object bytes" {
    const source: [*]const u8 = @ptrFromInt(er_ui_compiler_source_ptr());
    const source_bytes = source[0..er_ui_compiler_source_len()];
    const view = try object.View.decode(source_bytes);

    try std.testing.expectEqual(object.Kind.bytes, view.header.kind);
    try std.testing.expect(std.mem.startsWith(u8, view.body, "ERVFSWS1"));
    const file_count = bytes.load32(view.body[12..16]) orelse return error.Corrupt;
    try std.testing.expect(file_count > 0);

    var index: usize = 16;
    var saw_browser = false;
    var saw_compiler = false;
    var remaining = file_count;
    while (remaining > 0) : (remaining -= 1) {
        const label_ref = try vfs.decodeObjectLabelRef(view.body[index..][0..vfs.object_label_ref_bytes]);
        index += vfs.object_label_ref_bytes;
        const file_len: usize = @intCast(label_ref.object_len);
        const file_object = view.body[index..][0..file_len];
        const file_view = try object.View.decode(file_object);
        const file_id = file_view.id();
        try std.testing.expectEqualSlices(u8, &label_ref.object_id, &file_id);
        index += file_len;

        if (std.mem.eql(u8, label_ref.labelSlice(), "src/ui_browser.zig")) saw_browser = true;
        if (std.mem.eql(u8, label_ref.labelSlice(), "compiler/zig/src/edgerun_wasm_compiler.zig")) saw_compiler = true;
    }
    try std.testing.expectEqual(view.body.len, index);
    try std.testing.expect(saw_browser);
    try std.testing.expect(saw_compiler);
}

test "browser native embeds compiler wasm bytes into parent app" {
    const wasm_bytes: [*]const u8 = @ptrFromInt(er_ui_compiler_wasm_ptr());
    const compiler_bytes = wasm_bytes[0..er_ui_compiler_wasm_len()];

    try std.testing.expect(compiler_bytes.len > 0);
    try std.testing.expectEqualSlices(u8, &.{ 0x00, 0x61, 0x73, 0x6d }, compiler_bytes[0..4]);
}

test "browser native source workspace is mutable app source" {
    try std.testing.expectEqual(@as(u32, 0), er_ui_source_workspace_reset());
    defer _ = er_ui_source_workspace_reset();
    const workspace: [*]u8 = @ptrFromInt(er_ui_source_workspace_ptr());
    const initial = workspace[0..er_ui_source_workspace_len()];
    const view = try object.View.decode(initial);
    try std.testing.expect(std.mem.indexOf(u8, view.body, "er_wasm_compiler_compile_wasm") != null);

    const edited = "pub export fn edited() void {}";
    @memcpy(workspace[0..edited.len], edited);
    try std.testing.expectEqual(@as(u32, 0), er_ui_source_workspace_commit(edited.len));
    try std.testing.expectEqualStrings(edited, workspace[0..er_ui_source_workspace_len()]);
}

test "browser native source editor rewrites a canonical vfs file" {
    try std.testing.expectEqual(@as(u32, 0), er_ui_source_workspace_reset());
    defer _ = er_ui_source_workspace_reset();
    applyRoute(.{ .view = .source });

    const original = try findWorkspaceFileBody(source_object[0..], source_editor_label);
    const editor: [*]const u8 = @ptrFromInt(er_ui_source_editor_ptr());
    try std.testing.expectEqual(@intFromEnum(SourceEditorStatus.ready), er_ui_source_editor_status());
    try std.testing.expectEqualStrings(original, editor[0..er_ui_source_editor_len()]);

    try std.testing.expectEqual(@as(u32, 1), er_ui_site_key_event(writeInputForTest("/"), 0, 0, 0));
    try std.testing.expectEqual(@intFromEnum(SourceEditorStatus.dirty), er_ui_source_editor_status());
    const edited = try findWorkspaceFileBody(source_workspace[0..source_workspace_len], source_editor_label);
    try std.testing.expectEqual(original.len + 1, edited.len);
    try std.testing.expectEqual(@as(u8, '/'), edited[0]);
    try std.testing.expectEqualStrings(original, edited[1..]);

    try std.testing.expectEqual(@as(u32, 1), er_ui_site_key_event(writeInputForTest("Backspace"), 0, 0, 0));
    const restored = try findWorkspaceFileBody(source_workspace[0..source_workspace_len], source_editor_label);
    try std.testing.expectEqualStrings(original, restored);
}

test "browser native release artifact slot only commits wasm modules" {
    const artifact: [*]u8 = @ptrFromInt(er_ui_release_artifact_ptr());
    try std.testing.expect(er_ui_release_artifact_capacity() >= er_ui_compiler_wasm_len());
    try std.testing.expectEqual(@as(u32, @intFromEnum(ErrorCode.bad_input)), er_ui_release_artifact_commit(0));

    const compiler_bytes: [*]const u8 = @ptrFromInt(er_ui_compiler_wasm_ptr());
    @memcpy(artifact[0..er_ui_compiler_wasm_len()], compiler_bytes[0..er_ui_compiler_wasm_len()]);
    try std.testing.expectEqual(@as(u32, 0), er_ui_release_artifact_commit(er_ui_compiler_wasm_len()));
    try std.testing.expectEqual(er_ui_compiler_wasm_len(), er_ui_release_artifact_len());
    try std.testing.expectEqualSlices(u8, &.{ 0x00, 0x61, 0x73, 0x6d }, artifact[0..4]);
    try std.testing.expectEqual(@as(u32, 0), er_ui_release_artifact_clear());
    try std.testing.expectEqual(@as(usize, 0), er_ui_release_artifact_len());
}

test "browser native emits successor artifact with source workspace embedded" {
    try std.testing.expectEqual(@as(u32, 0), er_ui_release_artifact_clear());
    try std.testing.expectEqual(@as(u32, 0), er_ui_source_workspace_reset());

    try std.testing.expectEqual(@as(u32, 0), er_ui_compile_workspace_wasm());
    try std.testing.expect(er_ui_release_artifact_len() > er_ui_source_workspace_len());
    const artifact: [*]const u8 = @ptrFromInt(er_ui_release_artifact_ptr());
    const artifact_bytes = artifact[0..er_ui_release_artifact_len()];
    try std.testing.expectEqualSlices(u8, &.{ 0x00, 0x61, 0x73, 0x6d }, artifact_bytes[0..4]);
    const source: [*]const u8 = @ptrFromInt(er_ui_compiler_source_ptr());
    try std.testing.expect(std.mem.indexOf(u8, artifact_bytes, source[0..er_ui_compiler_source_len()]) != null);
}

test "browser native exports committed wasm artifact through generic byte bridge" {
    try std.testing.expectEqual(@as(u32, 0), er_ui_release_artifact_clear());
    const artifact: [*]u8 = @ptrFromInt(er_ui_release_artifact_ptr());
    const compiler_bytes: [*]const u8 = @ptrFromInt(er_ui_compiler_wasm_ptr());
    @memcpy(artifact[0..er_ui_compiler_wasm_len()], compiler_bytes[0..er_ui_compiler_wasm_len()]);
    try std.testing.expectEqual(@as(u32, 0), er_ui_release_artifact_commit(er_ui_compiler_wasm_len()));

    try std.testing.expectEqual(@as(u32, 0), er_ui_request_release_artifact_download());
    try std.testing.expectEqual(@as(u32, 1), er_ui_outbox_count());
    try std.testing.expectEqual(@intFromEnum(OutboxKind.download_wasm), er_ui_outbox_kind(0));
    try std.testing.expectEqualStrings(release_artifact_filename, (@as([*]const u8, @ptrFromInt(er_ui_outbox_target_ptr(0))))[0..er_ui_outbox_target_len(0)]);
    try std.testing.expectEqual(er_ui_release_artifact_len(), er_ui_outbox_payload_len(0));
    try std.testing.expectEqual(@as(u32, 0), er_ui_outbox_clear());
    try std.testing.expectEqual(@as(u32, 0), er_ui_request_release_artifact_launch());
    try std.testing.expectEqual(@intFromEnum(OutboxKind.launch_wasm), er_ui_outbox_kind(0));
}

test "browser native site state owns scroll position" {
    site_state = .{};
    defer site_state = .{};

    try std.testing.expectEqual(@as(u32, 0), er_ui_site_scroll_by(320.0, 1280.0, 900.0));
    try std.testing.expectEqual(@as(f32, 320.0), er_ui_site_scroll_y());
    try std.testing.expectEqual(@as(u32, 0), er_ui_site_activate_hit(site_chrome.blog_button_id));
    try std.testing.expectEqual(@as(f32, 0.0), er_ui_site_scroll_y());
    try std.testing.expectEqual(@as(u32, 0), er_ui_site_scroll_by(200000.0, 1280.0, 900.0));
    try std.testing.expectEqual(siteScrollLimit(1280.0, 900.0), er_ui_site_scroll_y());
}

test "browser native cursor intent owns hit and drag cursor policy" {
    runtime_state.clearHover();
    last_action_kind = @intFromEnum(ui_runtime.ActionKind.none);
    try std.testing.expectEqual(@intFromEnum(CursorKind.default), er_ui_cursor_kind());

    runtime_state.hovered = .{ .kind = .input, .id = 1, .bounds = ui.Rect.init(0, 0, 1, 1) };
    try std.testing.expectEqual(@intFromEnum(CursorKind.text), er_ui_cursor_kind());

    runtime_state.hovered = .{ .kind = .button, .id = 2, .bounds = ui.Rect.init(0, 0, 1, 1) };
    try std.testing.expectEqual(@intFromEnum(CursorKind.pointer), er_ui_cursor_kind());

    last_action_kind = @intFromEnum(ui_runtime.ActionKind.drag_started);
    try std.testing.expectEqual(@intFromEnum(CursorKind.grabbing), er_ui_cursor_kind());
}

test "browser native cursor is scene-drawn from runtime pointer state" {
    var local_commands: [16]ui.Command = undefined;
    const scene = ui.Scene.init(&local_commands);
    var local_pixels: [64]ui.Color = undefined;
    const surface = try renderer_pipeline.softwareFramebuffer(8, 8, &local_pixels);

    last_action_kind = @intFromEnum(ui_runtime.ActionKind.none);
    const regions = [_]interaction.Region{.{ .slot = 0, .kind = .button, .id = 4, .bounds = ui.Rect.init(0, 0, 8, 8) }};
    try std.testing.expectEqual(@as(u32, 0), finishCpuSceneFrame(surface, scene, &regions, .{ .enabled = true, .x = 4.0, .y = 4.0 }, .bg));
    try std.testing.expectEqual(@intFromEnum(CursorKind.pointer), er_ui_cursor_kind());
    try std.testing.expect(hasRectColor(local_commands[0..last_command_count], site_cursor.accent));
}

test "browser native pointer up owns activation suppression policy" {
    last_command_count = 0;
    try storeLastRegions(&.{.{ .slot = 0, .kind = .button, .id = site_chrome.blog_button_id, .bounds = ui.Rect.init(0, 0, 40, 40) }});

    site_state = .{};
    runtime_state = .{};
    defer site_state = .{};
    defer runtime_state = .{};

    _ = er_ui_pointer_down(8, 8);
    try std.testing.expectEqual(@intFromEnum(UiAction.none), er_ui_site_pointer_up(8, 8));
    try std.testing.expectEqual(site_blog.indexContentHeight(1280.0), er_ui_site_content_height(1280.0));

    var drag_commands: [2]ui.Command = undefined;
    var drag_scene = ui.Scene.init(&drag_commands);
    try drag_scene.pushDragSource(.{ .scope_id = 81, .item_id = 1, .index = 0, .bounds = ui.Rect.init(0, 0, 40, 40) });
    try drag_scene.pushDropTarget(.{ .scope_id = 81, .index = 2, .bounds = ui.Rect.init(0, 70, 40, 40) });
    last_command_count = drag_scene.written().len;
    @memcpy(commands[0..last_command_count], drag_scene.written());
    try storeLastRegions(&.{.{ .slot = 0, .kind = .button, .id = site_chrome.apps_button_id, .bounds = ui.Rect.init(0, 70, 40, 40) }});
    runtime_state = .{};
    site_state = .{};

    _ = er_ui_pointer_down(8, 8);
    _ = er_ui_pointer_move(8, 88);
    try std.testing.expectEqual(@intFromEnum(UiAction.none), er_ui_site_pointer_up(8, 88));
    try std.testing.expectEqual(site_landing.contentHeight(1280.0), er_ui_site_content_height(1280.0));
}

test "browser packed text preserves variable font descenders" {
    font_atlas_ready = false;
    try ensureFontAtlas();
    try std.testing.expectEqual(@as(usize, 0), font_glyph_count);
    packed_text_vertex_float_len = 0;
    const bounds = ui.Rect.init(0, 0, 64, 14);
    try renderer_pipeline.pushText(packedBuffers(), packedSources().font, .base, bounds, "y", .text, .start);
    try std.testing.expect(packed_text_vertex_float_len > 0);
    try std.testing.expect(font_glyph_count > 0);
    try std.testing.expect(font_glyph_count < 8);

    var max_y: f32 = 0.0;
    var index: usize = 1;
    while (index < packed_text_vertex_float_len) : (index += packed_text_vertex_float_stride) {
        max_y = @max(max_y, packed_text_vertex_floats[index]);
    }
    try std.testing.expect(max_y > bounds.y + bounds.h);
}

test "browser variable font atlas separates css size from raster scale" {
    font_atlas_ready = false;
    _ = er_ui_set_device_scale(2.0);
    try ensureFontAtlas();
    try std.testing.expectEqual(@as(usize, 0), font_glyph_count);
    const glyph_2x = (try getFontGlyph('M', 14)).?;

    _ = er_ui_set_device_scale(3.0);
    try ensureFontAtlas();
    try std.testing.expectEqual(@as(usize, 0), font_glyph_count);
    const glyph_3x = (try getFontGlyph('M', 14)).?;

    try std.testing.expect(glyph_3x.source_w > glyph_2x.source_w);
    try std.testing.expectApproxEqAbs(glyph_2x.w, glyph_3x.w, 1.5);
    try std.testing.expectApproxEqAbs(glyph_2x.advance, glyph_3x.advance, 0.75);
}

test "browser font atlas populates glyphs on demand" {
    font_atlas_ready = false;
    try ensureFontAtlas();
    const initialized_generation = font_atlas_generation;
    try std.testing.expectEqual(@as(usize, 0), font_glyph_count);

    packed_text_vertex_float_len = 0;
    try renderer_pipeline.pushText(packedBuffers(), packedSources().font, .base, ui.Rect.init(0, 0, 160, 18), "EdgeRun", .text, .start);
    try std.testing.expect(packed_text_vertex_float_len > 0);
    try std.testing.expect(font_glyph_count > 0);
    try std.testing.expect(font_glyph_count < 16);
    try std.testing.expect(font_atlas_generation > initialized_generation);
}

test "browser icon buffer stores semantic icon instances" {
    packed_icon_vertex_float_len = 0;
    try renderer_pipeline.pushIcon(packedBuffers(), .base, .{
        .bounds = ui.Rect.init(1, 2, 3, 4),
        .color = .accent,
        .icon_id = icon.id(.search),
    });
    const instance = try renderer_pipeline.iconAt(packed_icon_vertex_floats[0..packed_icon_vertex_float_len], 0);
    try std.testing.expectEqual(ui.Rect.init(1, 2, 3, 4), instance.bounds);
    try std.testing.expectEqual(icon.id(.search), instance.icon_id);
}

test "browser render frame writes pixels for byte bridge" {
    const code = er_ui_render_frame(640, 480, 0.0);
    try std.testing.expectEqual(@as(u32, 0), code);
    try std.testing.expectEqual(renderer_pipeline.Transport.pixel_bytes, last_present_transport);
    try std.testing.expect(er_ui_pixels_ptr() != 0);
}
