const std = @import("std");
const clock = @import("clock.zig");
const icon = @import("icon.zig");
const identity = @import("identity.zig");
const input = @import("input.zig");
const renderer = @import("renderer_software.zig");
const renderer_ir = @import("renderer_ir.zig");
const renderer_present = @import("renderer_present.zig");
const component_gallery = @import("component_gallery.zig");
const site_apps = @import("site_apps.zig");
const site_blog = @import("site_blog.zig");
const site_chrome = @import("site_chrome.zig");
const site_landing = @import("site_landing.zig");
const tabler_atlas = @import("tabler_atlas.zig");
const ui = @import("ui.zig");
const ui_codec = @import("ui_codec.zig");
const ui_runtime = @import("ui_runtime.zig");
const varfont = @import("varfont.zig");

const max_width: usize = 4096;
const max_height: usize = 2880;
const max_pixels: usize = max_width * max_height;
const max_input_bytes: usize = 8192;
const max_nodes: usize = 256;
const max_commands: usize = 4096;
const gpu_rect_float_stride: usize = renderer_ir.rect_float_stride;
const gpu_text_vertex_float_stride: usize = renderer_ir.text_vertex_float_stride;
const gpu_icon_vertex_float_stride: usize = renderer_ir.icon_vertex_float_stride;
const gpu_image_vertex_float_stride: usize = renderer_ir.image_vertex_float_stride;
const max_gpu_rects: usize = 8192;
const max_gpu_text_vertices: usize = 24576;
const max_gpu_icon_vertices: usize = 4096;
const max_gpu_image_vertices: usize = 384;
const max_gpu_overlay_rects: usize = 512;
const max_gpu_overlay_text_vertices: usize = 8192;
const max_gpu_overlay_icon_vertices: usize = 256;
const max_clips: usize = 64;
const font_atlas_width: usize = 4096;
const font_atlas_height: usize = 4096;
const font_atlas_bytes: usize = font_atlas_width * font_atlas_height;
const font_glyph_capacity: usize = 1280;
const font_first_char: u8 = renderer_ir.font_first_char;
const font_last_char: u8 = renderer_ir.font_last_char;
const font_padding: usize = 8;
const font_row_gap: usize = 8;
const font_bitmap_bytes: usize = 8 * 1024 * 1024;
const icon_atlas_width: usize = tabler_atlas.width;
const icon_atlas_height: usize = tabler_atlas.height;
const post_image_bytes = @embedFile("assets/old-man-yells-at-cloud.webp");
const site_source_url = "https://github.com/edgerun";
const route_bytes_capacity: usize = 96;
const route_hash_bytes_capacity: usize = route_bytes_capacity + 1;
const search_query_capacity: usize = 64;
const search_result_limit: usize = 6;
const search_overlay_id: u32 = 70_000;
const search_input_id: u32 = 70_001;
const search_scrim_alpha: u8 = 204;
const search_panel_alpha: u8 = 255;
const search_result_alpha: u8 = 255;
const key_slash: u32 = '/';
const key_upper_k: u32 = 'K';
const key_lower_k: u32 = 'k';
const key_backspace_text = "Backspace";
const key_escape_text = "Escape";
const key_modifier_ctrl: u32 = 1 << 0;
const key_modifier_meta: u32 = 1 << 1;
const key_modifier_alt: u32 = 1 << 2;
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
var nodes: [max_nodes]ui.Node = undefined;
var commands: [max_commands]ui.Command = undefined;
var clips: [max_clips]ui.Rect = undefined;
var gpu_rect_floats: [max_gpu_rects * gpu_rect_float_stride]f32 = undefined;
var gpu_rect_float_len: usize = 0;
var gpu_text_vertex_floats: [max_gpu_text_vertices * gpu_text_vertex_float_stride]f32 = undefined;
var gpu_text_vertex_float_len: usize = 0;
var gpu_icon_vertex_floats: [max_gpu_icon_vertices * gpu_icon_vertex_float_stride]f32 = undefined;
var gpu_icon_vertex_float_len: usize = 0;
var gpu_image_vertex_floats: [max_gpu_image_vertices * gpu_image_vertex_float_stride]f32 = undefined;
var gpu_image_vertex_float_len: usize = 0;
var gpu_overlay_rect_floats: [max_gpu_overlay_rects * gpu_rect_float_stride]f32 = undefined;
var gpu_overlay_rect_float_len: usize = 0;
var gpu_overlay_text_vertex_floats: [max_gpu_overlay_text_vertices * gpu_text_vertex_float_stride]f32 = undefined;
var gpu_overlay_text_vertex_float_len: usize = 0;
var gpu_overlay_icon_vertex_floats: [max_gpu_overlay_icon_vertices * gpu_icon_vertex_float_stride]f32 = undefined;
var gpu_overlay_icon_vertex_float_len: usize = 0;
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
var last_present_primitive_count: usize = 0;
var last_present_transport: renderer_present.Transport = .webgl_buffers;
var last_error: ErrorCode = .ok;
var hover_hit_kind: u32 = hover_hit_kind_none;
var hover_hit_id: u32 = 0;
var runtime_state = ui_runtime.State{};
var last_action_kind: u32 = @intFromEnum(ui_runtime.ActionKind.none);
var last_action_hit_id: u32 = 0;
var last_action_scope_id: u32 = 0;
var last_action_from_index: u32 = 0;
var last_action_to_index: u32 = 0;
var gallery_list_order_scope_id: u32 = 0;
var gallery_list_order: [component_gallery.list_row_count]u8 = component_gallery.default_list_order;
var site_state = SiteState{};
var route_bytes: [route_bytes_capacity]u8 = undefined;
var route_len: usize = 0;
var route_hash_bytes: [route_hash_bytes_capacity]u8 = undefined;
var route_hash_len: usize = 0;
var entropy_pool: [entropy_pool_size]u8 = initialEntropyPool();
var entropy_event_count: u64 = 0;
var ephemeral_seed: [ephemeral_seed_size]u8 = [_]u8{0} ** ephemeral_seed_size;
var ephemeral_public_key: [identity.ed25519_public_size]u8 = [_]u8{0} ** identity.ed25519_public_size;
var ephemeral_identity_id: [identity.id_size]u8 = [_]u8{0} ** identity.id_size;
var public_identity_text: [public_identity_text_len]u8 = [_]u8{0} ** public_identity_text_len;
var ephemeral_identity_ready = false;
var gpu_source_context: u8 = 0;

const hover_hit_kind_none: u32 = 255;

const HostAction = enum(u32) {
    none = 0,
    open_url = 1,
};

const CursorKind = enum(u32) {
    default = 0,
    pointer = 1,
    text = 2,
    grabbing = 3,
};

const SiteView = enum(u32) {
    landing = 0,
    blog = 1,
    apps = 2,
};

const SiteState = struct {
    view: SiteView = .landing,
    selected_blog_post_id: u32 = 0,
    blog_arc_filter_index: ?usize = null,
    scroll_y: f32 = 0.0,
    host_action: HostAction = .none,
    search_open: bool = false,
    search_query: [search_query_capacity]u8 = [_]u8{0} ** search_query_capacity,
    search_query_len: usize = 0,

    fn resetHostAction(state: *SiteState) void {
        state.host_action = .none;
    }

    fn searchQuery(state: *const SiteState) []const u8 {
        return state.search_query[0..state.search_query_len];
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
    gpu_budget = 5,
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

fn gpuBuffers() renderer_ir.Buffers {
    return .{
        .rects = gpu_rect_floats[0..],
        .rect_len = &gpu_rect_float_len,
        .text_vertices = gpu_text_vertex_floats[0..],
        .text_vertex_len = &gpu_text_vertex_float_len,
        .icon_vertices = gpu_icon_vertex_floats[0..],
        .icon_vertex_len = &gpu_icon_vertex_float_len,
        .image_vertices = gpu_image_vertex_floats[0..],
        .image_vertex_len = &gpu_image_vertex_float_len,
        .overlay_rects = gpu_overlay_rect_floats[0..],
        .overlay_rect_len = &gpu_overlay_rect_float_len,
        .overlay_text_vertices = gpu_overlay_text_vertex_floats[0..],
        .overlay_text_vertex_len = &gpu_overlay_text_vertex_float_len,
        .overlay_icon_vertices = gpu_overlay_icon_vertex_floats[0..],
        .overlay_icon_vertex_len = &gpu_overlay_icon_vertex_float_len,
    };
}

fn gpuSources() renderer_ir.Sources {
    return .{
        .font = .{
            .context = &gpu_source_context,
            .metrics = fontMetricsForIr,
            .width = textWidthForIr,
            .glyph = fontGlyphForIr,
        },
        .icon = .{
            .context = &gpu_source_context,
            .rect = iconAtlasRectForIr,
        },
    };
}

fn fontMetricsForIr(_: *anyopaque, px: u8) renderer_ir.TextMetrics {
    return fontMetrics(px);
}

fn textWidthForIr(_: *anyopaque, value: []const u8, px: u8) f32 {
    return textWidth(value, px);
}

fn fontGlyphForIr(_: *anyopaque, ch: u8, px: u8) renderer_ir.Error!?renderer_ir.Glyph {
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

fn iconAtlasRectForIr(_: *anyopaque, atlas_id: u32) ?renderer_ir.AtlasRect {
    return iconAtlasRect(atlas_id);
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

export fn er_ui_gpu_rect_float_stride() u32 {
    return gpu_rect_float_stride;
}

export fn er_ui_gpu_rect_buffer_ptr() usize {
    return @intFromPtr(gpu_rect_floats[0..].ptr);
}

export fn er_ui_gpu_rect_buffer_len() usize {
    return gpu_rect_float_len;
}

export fn er_ui_gpu_text_vertex_float_stride() u32 {
    return gpu_text_vertex_float_stride;
}

export fn er_ui_gpu_text_vertex_buffer_ptr() usize {
    return @intFromPtr(gpu_text_vertex_floats[0..].ptr);
}

export fn er_ui_gpu_text_vertex_buffer_len() usize {
    return gpu_text_vertex_float_len;
}

export fn er_ui_gpu_icon_vertex_float_stride() u32 {
    return gpu_icon_vertex_float_stride;
}

export fn er_ui_gpu_icon_vertex_buffer_ptr() usize {
    return @intFromPtr(gpu_icon_vertex_floats[0..].ptr);
}

export fn er_ui_gpu_icon_vertex_buffer_len() usize {
    return gpu_icon_vertex_float_len;
}

export fn er_ui_gpu_image_vertex_float_stride() u32 {
    return gpu_image_vertex_float_stride;
}

export fn er_ui_gpu_image_vertex_buffer_ptr() usize {
    return @intFromPtr(gpu_image_vertex_floats[0..].ptr);
}

export fn er_ui_gpu_image_vertex_buffer_len() usize {
    return gpu_image_vertex_float_len;
}

export fn er_ui_gpu_overlay_rect_buffer_ptr() usize {
    return @intFromPtr(gpu_overlay_rect_floats[0..].ptr);
}

export fn er_ui_gpu_overlay_rect_buffer_len() usize {
    return gpu_overlay_rect_float_len;
}

export fn er_ui_gpu_overlay_text_vertex_buffer_ptr() usize {
    return @intFromPtr(gpu_overlay_text_vertex_floats[0..].ptr);
}

export fn er_ui_gpu_overlay_text_vertex_buffer_len() usize {
    return gpu_overlay_text_vertex_float_len;
}

export fn er_ui_gpu_overlay_icon_vertex_buffer_ptr() usize {
    return @intFromPtr(gpu_overlay_icon_vertex_floats[0..].ptr);
}

export fn er_ui_gpu_overlay_icon_vertex_buffer_len() usize {
    return gpu_overlay_icon_vertex_float_len;
}

export fn er_ui_post_image_webp_ptr() usize {
    return @intFromPtr(post_image_bytes.ptr);
}

export fn er_ui_post_image_webp_len() usize {
    return post_image_bytes.len;
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

export fn er_ui_icon_atlas_width() u32 {
    return icon_atlas_width;
}

export fn er_ui_icon_atlas_height() u32 {
    return icon_atlas_height;
}

export fn er_ui_icon_atlas_ptr() usize {
    return @intFromPtr(tabler_atlas.alpha.ptr);
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

export fn er_ui_hover_hit_kind() u32 {
    return hover_hit_kind;
}

export fn er_ui_hover_hit_id() u32 {
    return hover_hit_id;
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
    recordAction(runtime_state.pointerDown(lastCommands(), x, y));
    updateHoverHit(lastCommands(), x, y);
    return last_action_kind;
}

export fn er_ui_pointer_move(x: f32, y: f32) u32 {
    mixInteractionEntropy(.pointer_move, x, y);
    recordAction(runtime_state.pointerMove(lastCommands(), x, y));
    updateHoverHit(lastCommands(), x, y);
    return last_action_kind;
}

export fn er_ui_pointer_up(x: f32, y: f32) u32 {
    mixInteractionEntropy(.pointer_up, x, y);
    recordAction(runtime_state.pointerUp(lastCommands(), x, y));
    updateHoverHit(lastCommands(), x, y);
    return last_action_kind;
}

export fn er_ui_site_pointer_up(x: f32, y: f32) u32 {
    const action_kind = er_ui_pointer_up(x, y);
    if (action_kind == @intFromEnum(ui_runtime.ActionKind.reordered)) {
        return @intFromEnum(HostAction.none);
    }
    return er_ui_site_activate_hit(hover_hit_id);
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

export fn er_ui_site_search_button_id() u32 {
    return site_chrome.search_button_id;
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

export fn er_ui_site_host_action_kind() u32 {
    return @intFromEnum(site_state.host_action);
}

export fn er_ui_site_host_action_url_ptr() usize {
    return @intFromPtr(site_source_url.ptr);
}

export fn er_ui_site_host_action_url_len() usize {
    return site_source_url.len;
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

export fn er_ui_site_activate_hit(hit_id: u32) u32 {
    site_state.resetHostAction();
    switch (hit_id) {
        site_chrome.logo_button_id => {
            site_state.view = .landing;
            site_state.selected_blog_post_id = 0;
            site_state.blog_arc_filter_index = null;
            site_state.resetScroll();
            site_state.search_open = false;
        },
        site_chrome.search_button_id => {
            site_state.search_open = true;
        },
        site_chrome.docs_button_id => {
            site_state.view = .landing;
            site_state.selected_blog_post_id = 0;
            site_state.blog_arc_filter_index = null;
            site_state.resetScroll();
            site_state.search_open = false;
        },
        site_chrome.blog_button_id => {
            site_state.view = .blog;
            site_state.selected_blog_post_id = 0;
            site_state.blog_arc_filter_index = null;
            site_state.resetScroll();
            site_state.search_open = false;
        },
        site_chrome.apps_button_id => {
            site_state.view = .apps;
            site_state.selected_blog_post_id = 0;
            site_state.blog_arc_filter_index = null;
            site_state.resetScroll();
            site_state.search_open = false;
        },
        site_chrome.source_button_id => {
            site_state.host_action = .open_url;
        },
        site_landing.reveal_identity_button_id => {
            if (!ephemeral_identity_ready) {
                generateEphemeralIdentity() catch return finishError(.identity_failed);
            }
        },
        site_blog.back_button_id => {
            site_state.selected_blog_post_id = 0;
            site_state.resetScroll();
            site_state.search_open = false;
        },
        site_blog.all_lessons_button_id => {
            site_state.view = .blog;
            site_state.selected_blog_post_id = 0;
            site_state.blog_arc_filter_index = null;
            site_state.resetScroll();
            site_state.search_open = false;
        },
        else => if (site_blog.postById(hit_id) != null) {
            site_state.view = .blog;
            site_state.selected_blog_post_id = hit_id;
            site_state.resetScroll();
            site_state.search_open = false;
        } else if (site_blog.arcFilterIndexById(hit_id)) |index| {
            site_state.view = .blog;
            site_state.selected_blog_post_id = 0;
            site_state.blog_arc_filter_index = index;
            site_state.resetScroll();
            site_state.search_open = false;
        },
    }
    return @intFromEnum(site_state.host_action);
}

export fn er_ui_site_search_open() u32 {
    site_state.search_open = true;
    return 0;
}

export fn er_ui_site_search_close() u32 {
    site_state.search_open = false;
    site_state.search_query_len = 0;
    return 0;
}

export fn er_ui_site_search_is_open() u32 {
    return if (site_state.search_open) 1 else 0;
}

export fn er_ui_site_search_backspace() u32 {
    if (site_state.search_query_len > 0) site_state.search_query_len -= 1;
    return 0;
}

export fn er_ui_site_search_input_byte(byte: u32) u32 {
    if (byte < 32 or byte > 126) return finishError(.bad_input);
    if (site_state.search_query_len >= site_state.search_query.len) return finishError(.bad_input);
    site_state.search_query[site_state.search_query_len] = @intCast(byte);
    site_state.search_query_len += 1;
    last_error = .ok;
    return @intFromEnum(ErrorCode.ok);
}

export fn er_ui_site_key_event(key_len: usize, modifiers: u32) u32 {
    if (key_len == 0) return 0;
    if (key_len > input_bytes.len) return finishError(.bad_input);
    const key = input_bytes[0..key_len];
    const ctrl_or_meta = (modifiers & (key_modifier_ctrl | key_modifier_meta)) != 0;
    const alt = (modifiers & key_modifier_alt) != 0;

    const key_byte = singleAsciiKey(key);
    const search_shortcut = key_byte != null and (key_byte.? == key_lower_k or key_byte.? == key_upper_k) and ctrl_or_meta;
    if (search_shortcut or (key_byte != null and key_byte.? == key_slash and !site_state.search_open)) {
        site_state.search_open = true;
        last_error = .ok;
        return 1;
    }

    if (!site_state.search_open) return 0;
    if (std.mem.eql(u8, key, key_escape_text)) {
        site_state.search_open = false;
        site_state.search_query_len = 0;
        last_error = .ok;
        return 1;
    }
    if (std.mem.eql(u8, key, key_backspace_text)) {
        if (site_state.search_query_len > 0) site_state.search_query_len -= 1;
        last_error = .ok;
        return 1;
    }
    if (!ctrl_or_meta and !alt and key_byte != null and key_byte.? >= 32 and key_byte.? <= 126) {
        if (site_state.search_query_len >= site_state.search_query.len) return finishError(.bad_input);
        site_state.search_query[site_state.search_query_len] = key_byte.?;
        site_state.search_query_len += 1;
        last_error = .ok;
        return 1;
    }
    return 0;
}

fn singleAsciiKey(key: []const u8) ?u8 {
    if (key.len != 1) return null;
    return key[0];
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
    return site_landing.contentHeight(width);
}

export fn er_ui_site_blog_content_height(width: f32) f32 {
    return site_blog.indexContentHeight(width);
}

export fn er_ui_site_blog_post_content_height(width: f32, post_id: u32) f32 {
    return site_blog.postContentHeight(width, post_id);
}

export fn er_ui_site_apps_content_height(width: f32) f32 {
    return site_apps.contentHeight(width);
}

export fn er_ui_site_content_height(width: f32) f32 {
    return switch (site_state.view) {
        .landing => site_landing.contentHeight(width),
        .blog => if (site_state.selected_blog_post_id == 0)
            site_blog.indexContentHeightFiltered(width, site_state.blog_arc_filter_index)
        else
            site_blog.postContentHeight(width, site_state.selected_blog_post_id),
        .apps => site_apps.contentHeight(width),
    };
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
    component_gallery.renderComponentGallery(&scene, .{
        .x = 0,
        .y = 0,
        .w = @floatFromInt(frame_width),
        .h = @floatFromInt(frame_height),
    }, galleryState(layout_raw, grid_gap, scroll_y, hover_x, hover_y)) catch return finishError(.render_failed);

    return finishCpuSceneFrame(surface, scene, .{ .enabled = true, .x = hover_x, .y = hover_y }, .bg);
}

export fn er_ui_build_component_gallery_gpu_frame(width: u32, height: u32, scroll_y: f32) u32 {
    return er_ui_build_component_gallery_gpu_frame_layout_gap_hover(width, height, scroll_y, @intFromEnum(component_gallery.LayoutMode.masonry), component_gallery.grid_gap_default, -1.0, -1.0);
}

export fn er_ui_build_component_gallery_gpu_frame_layout_gap_hover(width: u32, height: u32, scroll_y: f32, layout_raw: u32, grid_gap: f32, hover_x: f32, hover_y: f32) u32 {
    if (!setFrameSize(width, height)) return finishError(.bad_size);

    var scene = ui.Scene.init(&commands);
    component_gallery.renderComponentGallery(&scene, .{
        .x = 0,
        .y = 0,
        .w = @floatFromInt(frame_width),
        .h = @floatFromInt(frame_height),
    }, galleryState(layout_raw, grid_gap, scroll_y, hover_x, hover_y)) catch return finishError(.render_failed);

    return finishGpuSceneFrame(scene, hover_x, hover_y);
}

export fn er_ui_build_site_landing_gpu_frame(width: u32, height: u32, scroll_y: f32, hover_x: f32, hover_y: f32, frame_ms: f32) u32 {
    if (!setFrameSize(width, height)) return finishError(.bad_size);

    var scene = ui.Scene.initWithClips(&commands, &clips);
    site_landing.render(&scene, .{
        .x = 0,
        .y = 0,
        .w = @floatFromInt(frame_width),
        .h = @floatFromInt(frame_height),
    }, .{
        .scroll_y = scroll_y,
        .hover_x = hover_x,
        .hover_y = hover_y,
        .frame_ms = frame_ms,
        .public_identity = publicIdentityText(),
        .public_identity_ready = ephemeral_identity_ready,
    }) catch return finishError(.render_failed);

    return finishGpuSceneFrame(scene, hover_x, hover_y);
}

export fn er_ui_build_site_blog_gpu_frame(width: u32, height: u32, scroll_y: f32, hover_x: f32, hover_y: f32, selected_post_id: u32) u32 {
    if (!setFrameSize(width, height)) return finishError(.bad_size);

    var scene = ui.Scene.initWithClips(&commands, &clips);
    site_blog.render(&scene, .{
        .x = 0,
        .y = 0,
        .w = @floatFromInt(frame_width),
        .h = @floatFromInt(frame_height),
    }, .{
        .scroll_y = scroll_y,
        .hover_x = hover_x,
        .hover_y = hover_y,
        .selected_post_id = selected_post_id,
    }) catch return finishError(.render_failed);

    return finishGpuSceneFrame(scene, hover_x, hover_y);
}

export fn er_ui_build_site_apps_gpu_frame(width: u32, height: u32, scroll_y: f32, hover_x: f32, hover_y: f32) u32 {
    if (!setFrameSize(width, height)) return finishError(.bad_size);

    var scene = ui.Scene.initWithClips(&commands, &clips);
    site_apps.render(&scene, .{
        .x = 0,
        .y = 0,
        .w = @floatFromInt(frame_width),
        .h = @floatFromInt(frame_height),
    }, .{
        .scroll_y = scroll_y,
        .hover_x = hover_x,
        .hover_y = hover_y,
    }) catch return finishError(.render_failed);

    return finishGpuSceneFrame(scene, hover_x, hover_y);
}

export fn er_ui_build_site_gpu_frame(width: u32, height: u32, hover_x: f32, hover_y: f32, frame_ms: f32) u32 {
    if (!setFrameSize(width, height)) return finishError(.bad_size);
    site_state.scroll_y = @min(site_state.scroll_y, siteScrollLimit(@floatFromInt(frame_width), @floatFromInt(frame_height)));

    var scene = ui.Scene.initWithClips(&commands, &clips);
    switch (site_state.view) {
        .landing => site_landing.render(&scene, .{
            .x = 0,
            .y = 0,
            .w = @floatFromInt(frame_width),
            .h = @floatFromInt(frame_height),
        }, .{
            .scroll_y = site_state.scroll_y,
            .hover_x = hover_x,
            .hover_y = hover_y,
            .frame_ms = frame_ms,
            .public_identity = publicIdentityText(),
            .public_identity_ready = ephemeral_identity_ready,
        }) catch return finishError(.render_failed),
        .blog => site_blog.render(&scene, .{
            .x = 0,
            .y = 0,
            .w = @floatFromInt(frame_width),
            .h = @floatFromInt(frame_height),
        }, .{
            .scroll_y = site_state.scroll_y,
            .hover_x = hover_x,
            .hover_y = hover_y,
            .selected_post_id = site_state.selected_blog_post_id,
            .arc_filter_index = site_state.blog_arc_filter_index,
        }) catch return finishError(.render_failed),
        .apps => site_apps.render(&scene, .{
            .x = 0,
            .y = 0,
            .w = @floatFromInt(frame_width),
            .h = @floatFromInt(frame_height),
        }, .{
            .scroll_y = site_state.scroll_y,
            .hover_x = hover_x,
            .hover_y = hover_y,
        }) catch return finishError(.render_failed),
    }
    const overlay_start = scene.written().len;
    if (site_state.search_open) renderSearchOverlay(&scene, hover_x, hover_y) catch return finishError(.render_failed);

    return finishGpuSceneFrameWithOverlay(scene, hover_x, hover_y, overlay_start);
}

fn finishGpuSceneFrame(scene: ui.Scene, hover_x: f32, hover_y: f32) u32 {
    last_command_count = scene.written().len;
    updateHoverHit(scene.written(), hover_x, hover_y);
    ensureFontAtlas() catch return finishError(.font_atlas);
    const buffers = gpuBuffers();
    renderer_ir.packScene(buffers, gpuSources(), scene.written()) catch return finishError(.gpu_budget);
    presentBrowserBuffers(buffers) catch return finishError(.render_failed);
    last_error = .ok;
    return @intFromEnum(ErrorCode.ok);
}

fn finishGpuSceneFrameWithOverlay(scene: ui.Scene, hover_x: f32, hover_y: f32, overlay_start: usize) u32 {
    last_command_count = scene.written().len;
    updateHoverHit(scene.written(), hover_x, hover_y);
    ensureFontAtlas() catch return finishError(.font_atlas);
    const buffers = gpuBuffers();
    renderer_ir.packSceneWithOverlay(buffers, gpuSources(), scene.written(), overlay_start) catch return finishError(.gpu_budget);
    presentBrowserBuffers(buffers) catch return finishError(.render_failed);
    last_error = .ok;
    return @intFromEnum(ErrorCode.ok);
}

const HoverUpdate = struct {
    enabled: bool,
    x: f32 = 0.0,
    y: f32 = 0.0,
};

fn finishCpuSceneFrame(surface: renderer.Surface, scene: ui.Scene, hover: HoverUpdate, background: ui.Color) u32 {
    last_command_count = scene.written().len;
    if (hover.enabled) updateHoverHit(scene.written(), hover.x, hover.y);
    renderSceneIr(surface, scene.written(), background) catch return finishError(.render_failed);
    last_error = .ok;
    return @intFromEnum(ErrorCode.ok);
}

export fn er_ui_render_input_object(input_len: usize, width: u32, height: u32) u32 {
    if (input_len == 0 or input_len > input_bytes.len) return finishError(.bad_input);
    const surface = beginFrame(width, height) orelse return finishError(.bad_size);

    const root = ui_codec.decodeObject(input_bytes[0..input_len], &nodes) catch return finishError(.bad_ui);
    var scene = ui.Scene.init(&commands);
    ui.render(&scene, root, .{
        .x = 0,
        .y = 0,
        .w = @floatFromInt(frame_width),
        .h = @floatFromInt(frame_height),
    }, .{}) catch return finishError(.render_failed);

    return finishCpuSceneFrame(surface, scene, .{ .enabled = false }, .bg);
}

fn beginFrame(width_raw: u32, height_raw: u32) ?renderer.Surface {
    const width: usize = width_raw;
    const height: usize = height_raw;
    if (!setFrameSize(width, height)) return null;
    return renderer.Surface.init(width, height, pixels[0 .. width * height]) catch null;
}

fn renderSceneIr(surface: renderer.Surface, scene_commands: []const ui.Command, background: ui.Color) !void {
    try ensureFontAtlas();
    const buffers = gpuBuffers();
    try renderer_ir.packScene(buffers, gpuSources(), scene_commands);
    surface.clear(background);
    const receipt = try surface.renderIrFrameWithAtlases(buffers, .{
        .font = .{ .width = font_atlas_width, .height = font_atlas_height, .alpha = &font_atlas_alpha },
        .icon = .{ .width = icon_atlas_width, .height = icon_atlas_height, .alpha = tabler_atlas.alpha },
    });
    recordPresentation(receipt);
}

fn presentBrowserBuffers(buffers: renderer_ir.Buffers) renderer_present.Error!void {
    const receipt = try renderer_present.present(.{
        .target = .{
            .kind = .browser,
            .width = @intCast(frame_width),
            .height = @intCast(frame_height),
        },
        .buffers = buffers,
        .resources = .{
            .font_atlas = true,
            .icon_atlas = true,
            .image_texture = true,
        },
    });
    recordPresentation(receipt);
}

fn recordPresentation(receipt: renderer_present.Receipt) void {
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

fn updateHoverHit(scene_commands: []const ui.Command, x: f32, y: f32) void {
    if (x < 0.0 or y < 0.0) {
        hover_hit_kind = hover_hit_kind_none;
        hover_hit_id = 0;
        return;
    }
    if (input.hitTest(scene_commands, x, y)) |hit| {
        hover_hit_kind = @intFromEnum(hit.kind);
        hover_hit_id = hit.id;
        return;
    }
    hover_hit_kind = hover_hit_kind_none;
    hover_hit_id = 0;
}

fn lastCommands() []const ui.Command {
    return commands[0..last_command_count];
}

fn galleryState(layout_raw: u32, grid_gap: f32, scroll_y: f32, hover_x: f32, hover_y: f32) component_gallery.ComponentGalleryState {
    return .{
        .layout = component_gallery.LayoutMode.fromRaw(layout_raw),
        .grid_gap = grid_gap,
        .scroll_y = scroll_y,
        .hover_x = hover_x,
        .hover_y = hover_y,
        .list_order_scope_id = gallery_list_order_scope_id,
        .list_order = gallery_list_order,
    };
}

fn applyRoutePath(path: []const u8) void {
    site_state.search_open = false;
    site_state.search_query_len = 0;
    site_state.resetScroll();
    const trimmed = trimRoute(path);
    if (std.mem.eql(u8, trimmed, "/academy")) {
        site_state.view = .blog;
        site_state.selected_blog_post_id = 0;
        site_state.blog_arc_filter_index = null;
        return;
    }
    if (std.mem.eql(u8, trimmed, "/apps")) {
        site_state.view = .apps;
        site_state.selected_blog_post_id = 0;
        site_state.blog_arc_filter_index = null;
        return;
    }
    if (std.mem.startsWith(u8, trimmed, "/academy/")) {
        const raw_id = std.fmt.parseUnsigned(u32, trimmed["/academy/".len..], 10) catch {
            site_state.view = .blog;
            site_state.selected_blog_post_id = 0;
            return;
        };
        site_state.view = .blog;
        site_state.selected_blog_post_id = if (site_blog.postById(raw_id) != null) raw_id else 0;
        site_state.blog_arc_filter_index = null;
        return;
    }
    site_state.view = .landing;
    site_state.selected_blog_post_id = 0;
    site_state.blog_arc_filter_index = null;
}

fn trimRoute(path: []const u8) []const u8 {
    if (path.len == 0) return "/";
    const query = std.mem.indexOfScalar(u8, path, '?') orelse path.len;
    const hash = std.mem.indexOfScalar(u8, path[0..query], '#') orelse query;
    const trimmed = path[0..hash];
    return if (trimmed.len == 0) "/" else trimmed;
}

fn refreshRoutePath() void {
    route_len = switch (site_state.view) {
        .landing => writeRoute("/"),
        .blog => if (site_state.selected_blog_post_id == 0)
            writeRoute("/academy")
        else
            writePostRoute(site_state.selected_blog_post_id),
        .apps => writeRoute("/apps"),
    };
}

fn refreshRouteHash() void {
    refreshRoutePath();
    if (route_len == 1 and route_bytes[0] == '/') {
        route_hash_len = 0;
        return;
    }
    route_hash_bytes[0] = '#';
    @memcpy(route_hash_bytes[1 .. route_len + 1], route_bytes[0..route_len]);
    route_hash_len = route_len + 1;
}

fn writeRoute(value: []const u8) usize {
    @memcpy(route_bytes[0..value.len], value);
    return value.len;
}

fn writePostRoute(post_id: u32) usize {
    const out = std.fmt.bufPrint(&route_bytes, "/academy/{d}", .{post_id}) catch unreachable;
    return out.len;
}

fn currentCursorKind() CursorKind {
    const action_kind: ui_runtime.ActionKind = @enumFromInt(@as(u8, @intCast(last_action_kind)));
    switch (action_kind) {
        .drag_started, .drag_moved => return .grabbing,
        .none, .hovered, .activated, .dropped, .reordered => {},
    }

    if (hover_hit_kind == hover_hit_kind_none) return .default;
    const hit_kind: ui.HitKind = @enumFromInt(@as(u8, @intCast(hover_hit_kind)));
    return switch (hit_kind) {
        .input, .textarea => .text,
        .button, .row_item, .checkbox, .switch_control, .slider, .select => .pointer,
    };
}

fn renderSearchOverlay(scene: *ui.Scene, hover_x: f32, hover_y: f32) ui.RenderError!void {
    _ = hover_x;
    _ = hover_y;
    const screen = ui.Rect.init(0.0, 0.0, @floatFromInt(frame_width), @floatFromInt(frame_height));
    try scene.pushRect(screen, .{ .r = 0, .g = 0, .b = 0, .a = search_scrim_alpha }, .fill, 0.0, 0.0);

    const panel_w = @min(720.0, @max(320.0, screen.w - 48.0));
    const panel = ui.Rect.init((screen.w - panel_w) * 0.5, 92.0, panel_w, 430.0);
    try scene.pushRect(panel, .{ .r = 5, .g = 5, .b = 5, .a = search_panel_alpha }, .fill, 10.0, 0.0);
    try scene.pushRect(panel, .{ .r = 64, .g = 64, .b = 64, .a = 255 }, .border, 10.0, 0.0);
    try scene.pushHit(.{ .slot = 0, .kind = .input, .id = search_overlay_id, .bounds = panel });

    const input_bounds = ui.Rect.init(panel.x + 22.0, panel.y + 22.0, panel.w - 44.0, 46.0);
    try scene.pushRect(input_bounds, .{ .r = 18, .g = 18, .b = 18, .a = 255 }, .fill, 7.0, 0.0);
    try scene.pushRect(input_bounds, .{ .r = 70, .g = 70, .b = 70, .a = 255 }, .border, 7.0, 0.0);
    try scene.pushIconQuad(.{ .bounds = ui.Rect.init(input_bounds.x + 14.0, input_bounds.y + 13.0, 20.0, 20.0), .atlas_id = icon.atlasId(.search), .color = .{ .r = 74, .g = 222, .b = 128 } });
    const query = site_state.searchQuery();
    const placeholder = if (query.len == 0) "Search lessons..." else query;
    const color = if (query.len == 0) ui.Color{ .r = 118, .g = 118, .b = 118 } else ui.Color{ .r = 242, .g = 242, .b = 242 };
    try scene.pushText(ui.Rect.init(input_bounds.x + 46.0, input_bounds.y + 14.0, input_bounds.w - 94.0, 18.0), placeholder, color);
    try scene.pushText(ui.Rect.init(input_bounds.x + input_bounds.w - 42.0, input_bounds.y + 15.0, 28.0, 14.0), "Esc", .{ .r = 118, .g = 118, .b = 118 });
    try scene.pushHit(.{ .slot = 0, .kind = .input, .id = search_input_id, .bounds = input_bounds });

    const results_y = input_bounds.y + input_bounds.h + 18.0;
    var rendered: usize = 0;
    for (site_blog.posts, 0..) |post, index| {
        if (rendered >= search_result_limit) break;
        if (query.len != 0 and !postMatches(post, query)) continue;
        const row = ui.Rect.init(panel.x + 22.0, results_y + @as(f32, @floatFromInt(rendered)) * 54.0, panel.w - 44.0, 46.0);
        const post_id = site_blog.postIdAt(index);
        try scene.pushRect(row, .{ .r = 18, .g = 18, .b = 18, .a = search_result_alpha }, .fill, 7.0, 0.0);
        try scene.pushRect(row, .{ .r = 48, .g = 48, .b = 48, .a = 255 }, .border, 7.0, 0.0);
        try scene.pushText(ui.Rect.init(row.x + 14.0, row.y + 8.0, row.w - 28.0, 15.0), post.title, .{ .r = 242, .g = 242, .b = 242 });
        try scene.pushText(ui.Rect.init(row.x + 14.0, row.y + 27.0, row.w - 28.0, 11.0), post.summary, .{ .r = 154, .g = 154, .b = 154 });
        try scene.pushHit(.{ .slot = 0, .kind = .button, .id = post_id, .bounds = row });
        rendered += 1;
    }
    if (rendered == 0) {
        try scene.pushText(ui.Rect.init(panel.x + 22.0, results_y + 10.0, panel.w - 44.0, 18.0), "No matching lessons", .{ .r = 154, .g = 154, .b = 154 });
    }
}

fn postMatches(post: site_blog.Post, query: []const u8) bool {
    return containsIgnoreCase(post.title, query) or containsIgnoreCase(post.summary, query) or containsIgnoreCase(post.arc, query);
}

fn containsIgnoreCase(value: []const u8, query: []const u8) bool {
    if (query.len == 0) return true;
    if (query.len > value.len) return false;
    var index: usize = 0;
    while (index + query.len <= value.len) : (index += 1) {
        var offset: usize = 0;
        while (offset < query.len and asciiLower(value[index + offset]) == asciiLower(query[offset])) : (offset += 1) {}
        if (offset == query.len) return true;
    }
    return false;
}

fn asciiLower(value: u8) u8 {
    return if (value >= 'A' and value <= 'Z') value + ('a' - 'A') else value;
}

fn recordAction(action: ui_runtime.Action) void {
    last_action_kind = @intFromEnum(action.kind);
    last_action_hit_id = if (action.hit) |hit| hit.id else 0;
    last_action_scope_id = if (action.source) |source| source.scope_id else 0;
    last_action_from_index = if (action.source) |source| @intCast(source.index) else 0;
    last_action_to_index = if (action.target) |target| @intCast(target.index) else 0;
    switch (action.kind) {
        .reordered => if (action.source) |source| {
            if (action.target) |target| applyGalleryListReorder(source.scope_id, source.index, target.index);
        },
        else => {},
    }
}

fn applyGalleryListReorder(scope_id: u32, from_index: usize, to_index: usize) void {
    if (from_index >= gallery_list_order.len or to_index >= gallery_list_order.len or from_index == to_index) return;
    if (gallery_list_order_scope_id != scope_id) {
        gallery_list_order_scope_id = scope_id;
        gallery_list_order = component_gallery.default_list_order;
    }

    const moving = gallery_list_order[from_index];
    if (from_index < to_index) {
        var index = from_index;
        while (index < to_index) : (index += 1) {
            gallery_list_order[index] = gallery_list_order[index + 1];
        }
    } else {
        var index = from_index;
        while (index > to_index) {
            gallery_list_order[index] = gallery_list_order[index - 1];
            index -= 1;
        }
    }
    gallery_list_order[to_index] = moving;
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

fn fontMetrics(px: u8) renderer_ir.TextMetrics {
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

fn iconAtlasRect(atlas_id: u32) ?renderer_ir.AtlasRect {
    const value = icon.fromAtlasId(atlas_id) orelse return null;
    const found = tabler_atlas.rect(value);
    return .{
        .u0 = (@as(f32, @floatFromInt(found.x)) + 0.5) / @as(f32, @floatFromInt(icon_atlas_width)),
        .v0 = (@as(f32, @floatFromInt(found.y)) + 0.5) / @as(f32, @floatFromInt(icon_atlas_height)),
        .u1 = (@as(f32, @floatFromInt(found.x + found.w)) - 0.5) / @as(f32, @floatFromInt(icon_atlas_width)),
        .v1 = (@as(f32, @floatFromInt(found.y + found.h)) - 0.5) / @as(f32, @floatFromInt(icon_atlas_height)),
    };
}

test "browser hover state exposes scene hit kind and id" {
    var local_commands: [4]ui.Command = undefined;
    var scene = ui.Scene.init(&local_commands);
    try scene.pushHit(.{ .slot = 0, .kind = .button, .id = 42, .bounds = ui.Rect.init(10, 20, 40, 30) });

    updateHoverHit(scene.written(), 20, 30);
    try std.testing.expectEqual(@intFromEnum(ui.HitKind.button), hover_hit_kind);
    try std.testing.expectEqual(@as(u32, 42), hover_hit_id);

    updateHoverHit(scene.written(), -1, -1);
    try std.testing.expectEqual(hover_hit_kind_none, hover_hit_kind);
    try std.testing.expectEqual(@as(u32, 0), hover_hit_id);
}

test "browser cpu ir finish preserves hover state when disabled" {
    hover_hit_kind = @intFromEnum(ui.HitKind.button);
    hover_hit_id = 99;
    var local_commands: [1]ui.Command = undefined;
    const scene = ui.Scene.init(&local_commands);
    var local_pixels: [4]ui.Color = undefined;
    const surface = try renderer.Surface.init(2, 2, &local_pixels);

    try std.testing.expectEqual(@as(u32, 0), finishCpuSceneFrame(surface, scene, .{ .enabled = false }, .bg));
    try std.testing.expectEqual(@intFromEnum(ui.HitKind.button), hover_hit_kind);
    try std.testing.expectEqual(@as(u32, 99), hover_hit_id);
}

test "browser component gallery builds packed webgl buffers and atlases" {
    font_atlas_ready = false;
    const code = er_ui_build_component_gallery_gpu_frame_layout_gap_hover(960, 640, 0.0, @intFromEnum(component_gallery.LayoutMode.masonry), component_gallery.grid_gap_default, -1.0, -1.0);
    try std.testing.expectEqual(@as(u32, 0), code);
    try std.testing.expect(font_atlas_ready);
    try std.testing.expectEqual(renderer_present.Transport.webgl_buffers, last_present_transport);
    try std.testing.expect(last_present_primitive_count > 0);
    try std.testing.expect(gpu_rect_float_len > 0);
    try std.testing.expect(gpu_text_vertex_float_len > 0);
    try std.testing.expect(gpu_icon_vertex_float_len > 0);
    try std.testing.expect(er_ui_font_atlas_ptr() != 0);
    try std.testing.expect(er_ui_icon_atlas_ptr() != 0);
}

test "browser component gallery cpu render uses canonical ir buffers" {
    const code = er_ui_render_component_gallery_layout_gap_hover(480, 360, 0.0, @intFromEnum(component_gallery.LayoutMode.masonry), component_gallery.grid_gap_default, -1.0, -1.0);
    try std.testing.expectEqual(@as(u32, 0), code);
    try std.testing.expectEqual(renderer_present.Transport.software_pixels, last_present_transport);
    try std.testing.expect(last_present_primitive_count > 0);
    try std.testing.expect(gpu_rect_float_len > 0);
    try std.testing.expect(gpu_text_vertex_float_len > 0);
    try std.testing.expect(gpu_icon_vertex_float_len > 0);
    var painted: usize = 0;
    for (pixels[0 .. frame_width * frame_height]) |pixel| {
        if (!std.meta.eql(pixel, ui.Color.bg)) painted += 1;
    }
    try std.testing.expect(painted > 0);
}

test "browser site landing builds packed webgl buffers and hit state" {
    const code = er_ui_build_site_landing_gpu_frame(1280, 800, 0.0, 1020.0, 32.0, 0.0);
    try std.testing.expectEqual(@as(u32, 0), code);
    try std.testing.expect(gpu_rect_float_len > 0);
    try std.testing.expect(gpu_text_vertex_float_len > 0);
    try std.testing.expect(gpu_icon_vertex_float_len > 0);
    try std.testing.expectEqual(site_landing.contentHeight(1280.0), er_ui_site_landing_content_height(1280.0));
    try std.testing.expectEqual(@intFromEnum(ui.HitKind.button), hover_hit_kind);
    try std.testing.expectEqual(site_chrome.search_button_id, hover_hit_id);
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
    _ = er_ui_build_site_landing_gpu_frame(1280, 800, 0.0, 108.0, 500.0, 333.0);
    _ = er_ui_pointer_down(108.0, 500.0);
    _ = er_ui_pointer_up(108.0, 500.0);
    try std.testing.expectEqual(@intFromEnum(HostAction.none), er_ui_site_activate_hit(site_landing.reveal_identity_button_id));
    try std.testing.expect(ephemeral_identity_ready);
    try std.testing.expectEqual(@as(usize, public_identity_text_len), publicIdentityText().len);
    try std.testing.expect(std.mem.startsWith(u8, publicIdentityText(), public_identity_prefix));
    try std.testing.expect(identity.Source.prepare(.ed25519_public, &ephemeral_public_key) != null);
}

test "browser site blog builds packed webgl buffers and post hit state" {
    const code = er_ui_build_site_blog_gpu_frame(1280, 800, 0.0, 340.0, 700.0, 0);
    try std.testing.expectEqual(@as(u32, 0), code);
    try std.testing.expect(gpu_rect_float_len > 0);
    try std.testing.expect(gpu_text_vertex_float_len > 0);
    try std.testing.expect(gpu_icon_vertex_float_len > 0);
    try std.testing.expect(gpu_image_vertex_float_len > 0);
    try std.testing.expect(er_ui_post_image_webp_ptr() != 0);
    try std.testing.expect(er_ui_post_image_webp_len() > 0);
    try std.testing.expectEqual(@as(u32, @intCast(site_blog.posts.len)), er_ui_blog_post_count());
    try std.testing.expect(er_ui_site_blog_content_height(1280.0) > 5200.0);
    try std.testing.expect(er_ui_site_blog_post_content_height(1280.0, site_blog.postIdAt(16)) > 1200.0);
    try std.testing.expectEqual(@intFromEnum(ui.HitKind.button), hover_hit_kind);
    try std.testing.expectEqual(site_blog.postIdAt(0), hover_hit_id);
}

test "browser site apps builds packed webgl buffers and hit state" {
    const code = er_ui_build_site_apps_gpu_frame(1280, 900, 0.0, 360.0, 700.0);
    try std.testing.expectEqual(@as(u32, 0), code);
    try std.testing.expect(gpu_rect_float_len > 0);
    try std.testing.expect(gpu_text_vertex_float_len > 0);
    try std.testing.expect(gpu_icon_vertex_float_len > 0);
    try std.testing.expectEqual(site_apps.contentHeight(1280.0), er_ui_site_apps_content_height(1280.0));
    try std.testing.expectEqual(@intFromEnum(ui.HitKind.button), hover_hit_kind);
    try std.testing.expectEqual(site_apps.first_app_button_id, hover_hit_id);
    try std.testing.expectEqual(@intFromEnum(CursorKind.pointer), er_ui_cursor_kind());
}

test "browser site activation keeps page state in wasm" {
    site_state = .{};
    defer site_state = .{};

    try std.testing.expectEqual(site_landing.contentHeight(1280.0), er_ui_site_content_height(1280.0));
    try std.testing.expectEqual(@intFromEnum(HostAction.none), er_ui_site_activate_hit(site_chrome.blog_button_id));
    try std.testing.expectEqual(site_blog.indexContentHeight(1280.0), er_ui_site_content_height(1280.0));
    try std.testing.expectEqual(@intFromEnum(HostAction.none), er_ui_site_activate_hit(site_blog.postIdAt(0)));
    try std.testing.expectEqual(site_blog.postContentHeight(1280.0, site_blog.postIdAt(0)), er_ui_site_content_height(1280.0));
    try std.testing.expectEqual(@intFromEnum(HostAction.open_url), er_ui_site_activate_hit(site_chrome.source_button_id));
    try std.testing.expectEqual(@intFromEnum(HostAction.open_url), er_ui_site_host_action_kind());
    try std.testing.expectEqual(site_source_url.len, er_ui_site_host_action_url_len());
    try std.testing.expect(er_ui_site_host_action_url_ptr() != 0);
    try std.testing.expectEqual(@intFromEnum(HostAction.none), er_ui_site_activate_hit(site_chrome.logo_button_id));
    try std.testing.expectEqual(site_landing.contentHeight(1280.0), er_ui_site_content_height(1280.0));
    try std.testing.expectEqual(@intFromEnum(HostAction.none), er_ui_site_activate_hit(site_blog.arcFilterButtonId(3)));
    try std.testing.expectEqual(site_blog.indexContentHeightFiltered(1280.0, 3), er_ui_site_content_height(1280.0));
    try std.testing.expectEqual(@intFromEnum(HostAction.none), er_ui_site_activate_hit(site_blog.all_lessons_button_id));
    try std.testing.expectEqual(site_blog.indexContentHeight(1280.0), er_ui_site_content_height(1280.0));
    try std.testing.expectEqual(@intFromEnum(HostAction.none), er_ui_site_activate_hit(site_chrome.apps_button_id));
    try std.testing.expectEqual(site_apps.contentHeight(1280.0), er_ui_site_content_height(1280.0));
}

test "browser native route sync owns URL path state" {
    site_state = .{};
    defer site_state = .{};

    @memcpy(input_bytes[0.."/academy".len], "/academy");
    try std.testing.expectEqual(@as(u32, 0), er_ui_site_set_route_path("/academy".len));
    try std.testing.expectEqual(site_blog.indexContentHeight(1280.0), er_ui_site_content_height(1280.0));
    try std.testing.expectEqualStrings("/academy", route_bytes[0..er_ui_site_route_path_len()]);
    try std.testing.expectEqualStrings("#/academy", route_hash_bytes[0..er_ui_site_route_hash_len()]);

    const route = "/academy/40100";
    @memcpy(input_bytes[0..route.len], route);
    try std.testing.expectEqual(@as(u32, 0), er_ui_site_set_route_path(route.len));
    try std.testing.expectEqual(site_blog.postContentHeight(1280.0, site_blog.postIdAt(0)), er_ui_site_content_height(1280.0));
    try std.testing.expectEqualStrings(route, route_bytes[0..er_ui_site_route_path_len()]);
    try std.testing.expectEqualStrings("#/academy/40100", route_hash_bytes[0..er_ui_site_route_hash_len()]);

    @memcpy(input_bytes[0.."/".len], "/");
    try std.testing.expectEqual(@as(u32, 0), er_ui_site_set_route_path("/".len));
    try std.testing.expectEqual(site_landing.contentHeight(1280.0), er_ui_site_content_height(1280.0));
    try std.testing.expectEqualStrings("/", route_bytes[0..er_ui_site_route_path_len()]);
    try std.testing.expectEqualStrings("", route_hash_bytes[0..er_ui_site_route_hash_len()]);

    @memcpy(input_bytes[0.."/apps".len], "/apps");
    try std.testing.expectEqual(@as(u32, 0), er_ui_site_set_route_path("/apps".len));
    try std.testing.expectEqual(site_apps.contentHeight(1280.0), er_ui_site_content_height(1280.0));
    try std.testing.expectEqualStrings("/apps", route_bytes[0..er_ui_site_route_path_len()]);
}

test "browser native search accepts keyboard text and renders overlay results" {
    site_state = .{};
    defer site_state = .{};

    try std.testing.expectEqual(@as(u32, 0), er_ui_site_search_open());
    try std.testing.expectEqual(@as(u32, 1), er_ui_site_search_is_open());
    for ("phone") |byte| try std.testing.expectEqual(@as(u32, 0), er_ui_site_search_input_byte(byte));
    try std.testing.expectEqualStrings("phone", site_state.searchQuery());

    const code = er_ui_build_site_gpu_frame(1280, 900, -1.0, -1.0, 0.0);
    try std.testing.expectEqual(@as(u32, 0), code);
    try std.testing.expect(gpu_rect_float_len > 0);
    try std.testing.expect(gpu_text_vertex_float_len > 0);
    try std.testing.expect(gpu_overlay_rect_float_len > 0);
    try std.testing.expect(gpu_overlay_text_vertex_float_len > 0);
    try std.testing.expect(gpu_overlay_icon_vertex_float_len > 0);
    try std.testing.expectEqual(@as(u32, 0), er_ui_site_search_backspace());
    try std.testing.expectEqualStrings("phon", site_state.searchQuery());
    try std.testing.expectEqual(@as(u32, 0), er_ui_site_search_close());
    try std.testing.expectEqual(@as(u32, 0), er_ui_site_search_is_open());
}

test "browser native key policy owns search shortcuts and text editing" {
    site_state = .{};
    defer site_state = .{};

    try std.testing.expectEqual(@as(u32, 1), er_ui_site_key_event(key_slash, 0));
    try std.testing.expectEqual(@as(u32, 1), er_ui_site_search_is_open());
    for ("phone") |byte| try std.testing.expectEqual(@as(u32, 1), er_ui_site_key_event(byte, 0));
    try std.testing.expectEqualStrings("phone", site_state.searchQuery());
    try std.testing.expectEqual(@as(u32, 1), er_ui_site_key_event(key_backspace, 0));
    try std.testing.expectEqualStrings("phon", site_state.searchQuery());
    try std.testing.expectEqual(@as(u32, 1), er_ui_site_key_event(key_escape, 0));
    try std.testing.expectEqual(@as(u32, 0), er_ui_site_search_is_open());

    try std.testing.expectEqual(@as(u32, 1), er_ui_site_key_event(key_lower_k, key_modifier_ctrl));
    try std.testing.expectEqual(@as(u32, 1), er_ui_site_search_is_open());
    try std.testing.expectEqual(@as(u32, 0), er_ui_site_key_event('x', key_modifier_alt));
    try std.testing.expectEqualStrings("", site_state.searchQuery());
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
    hover_hit_kind = hover_hit_kind_none;
    last_action_kind = @intFromEnum(ui_runtime.ActionKind.none);
    try std.testing.expectEqual(@intFromEnum(CursorKind.default), er_ui_cursor_kind());

    hover_hit_kind = @intFromEnum(ui.HitKind.input);
    try std.testing.expectEqual(@intFromEnum(CursorKind.text), er_ui_cursor_kind());

    hover_hit_kind = @intFromEnum(ui.HitKind.button);
    try std.testing.expectEqual(@intFromEnum(CursorKind.pointer), er_ui_cursor_kind());

    last_action_kind = @intFromEnum(ui_runtime.ActionKind.drag_started);
    try std.testing.expectEqual(@intFromEnum(CursorKind.grabbing), er_ui_cursor_kind());
}

test "browser native pointer up owns activation suppression policy" {
    var local_commands: [3]ui.Command = undefined;
    var scene = ui.Scene.init(&local_commands);
    try scene.pushHit(.{ .slot = 0, .kind = .button, .id = site_chrome.blog_button_id, .bounds = ui.Rect.init(0, 0, 40, 40) });
    last_command_count = scene.written().len;
    @memcpy(commands[0..last_command_count], scene.written());

    site_state = .{};
    runtime_state = .{};
    defer site_state = .{};
    defer runtime_state = .{};

    _ = er_ui_pointer_down(8, 8);
    try std.testing.expectEqual(@intFromEnum(HostAction.none), er_ui_site_pointer_up(8, 8));
    try std.testing.expectEqual(site_blog.indexContentHeight(1280.0), er_ui_site_content_height(1280.0));

    var drag_commands: [4]ui.Command = undefined;
    var drag_scene = ui.Scene.init(&drag_commands);
    try drag_scene.pushDragSource(.{ .scope_id = 81, .item_id = 1, .index = 0, .bounds = ui.Rect.init(0, 0, 40, 40) });
    try drag_scene.pushDropTarget(.{ .scope_id = 81, .index = 2, .bounds = ui.Rect.init(0, 70, 40, 40) });
    try drag_scene.pushHit(.{ .slot = 0, .kind = .button, .id = site_chrome.apps_button_id, .bounds = ui.Rect.init(0, 70, 40, 40) });
    last_command_count = drag_scene.written().len;
    @memcpy(commands[0..last_command_count], drag_scene.written());
    runtime_state = .{};
    site_state = .{};

    _ = er_ui_pointer_down(8, 8);
    _ = er_ui_pointer_move(8, 88);
    try std.testing.expectEqual(@intFromEnum(HostAction.none), er_ui_site_pointer_up(8, 88));
    try std.testing.expectEqual(site_landing.contentHeight(1280.0), er_ui_site_content_height(1280.0));
}

test "browser pointer runtime applies visible list reorder state" {
    runtime_state = .{};
    gallery_list_order_scope_id = 0;
    gallery_list_order = component_gallery.default_list_order;
    defer gallery_list_order_scope_id = 0;
    defer gallery_list_order = component_gallery.default_list_order;

    var scene = ui.Scene.init(&commands);
    try scene.pushDragSource(.{ .scope_id = 81, .item_id = 100, .index = 0, .bounds = ui.Rect.init(0, 0, 80, 40) });
    try scene.pushDropTarget(.{ .scope_id = 81, .index = 0, .bounds = ui.Rect.init(0, 0, 80, 40) });
    try scene.pushDropTarget(.{ .scope_id = 81, .index = 2, .bounds = ui.Rect.init(0, 80, 80, 40) });
    last_command_count = scene.written().len;

    try std.testing.expectEqual(@intFromEnum(ui_runtime.ActionKind.none), er_ui_pointer_down(8, 8));
    try std.testing.expectEqual(@intFromEnum(ui_runtime.ActionKind.drag_started), er_ui_pointer_move(8, 88));
    try std.testing.expectEqual(@intFromEnum(ui_runtime.ActionKind.reordered), er_ui_pointer_up(8, 88));
    try std.testing.expectEqual(@as(u32, 81), er_ui_last_action_scope_id());
    try std.testing.expectEqual(@as(u32, 0), er_ui_last_action_from_index());
    try std.testing.expectEqual(@as(u32, 2), er_ui_last_action_to_index());
    try std.testing.expectEqualSlices(u8, &[_]u8{ 1, 2, 0, 3 }, &gallery_list_order);
}

test "browser packed text preserves variable font descenders" {
    font_atlas_ready = false;
    try ensureFontAtlas();
    try std.testing.expectEqual(@as(usize, 0), font_glyph_count);
    gpu_text_vertex_float_len = 0;
    const bounds = ui.Rect.init(0, 0, 64, 14);
    try renderer_ir.pushText(gpuBuffers(), gpuSources().font, .base, bounds, "y", .text, .start);
    try std.testing.expect(gpu_text_vertex_float_len > 0);
    try std.testing.expect(font_glyph_count > 0);
    try std.testing.expect(font_glyph_count < 8);

    var max_y: f32 = 0.0;
    var index: usize = 1;
    while (index < gpu_text_vertex_float_len) : (index += gpu_text_vertex_float_stride) {
        max_y = @max(max_y, gpu_text_vertex_floats[index]);
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

    gpu_text_vertex_float_len = 0;
    try renderer_ir.pushText(gpuBuffers(), gpuSources().font, .base, ui.Rect.init(0, 0, 160, 18), "EdgeRun", .text, .start);
    try std.testing.expect(gpu_text_vertex_float_len > 0);
    try std.testing.expect(font_glyph_count > 0);
    try std.testing.expect(font_glyph_count < 16);
    try std.testing.expect(font_atlas_generation > initialized_generation);
}

test "browser icon atlas uv preserves canonical top-origin rows" {
    const found = tabler_atlas.rect(.search);
    const rect = iconAtlasRect(icon.atlasId(.search)).?;
    const expected_v0 = (@as(f32, @floatFromInt(found.y)) + 0.5) / @as(f32, @floatFromInt(icon_atlas_height));
    try std.testing.expectEqual(expected_v0, rect.v0);
}
