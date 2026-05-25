const std = @import("std");
const browser_runtime_js = @import("browser_runtime_js.zig");
const clock = @import("clock.zig");
const icon = @import("icon.zig");
const icon_line_buffer = @import("icon_line_buffer.zig");
const identity = @import("identity.zig");
const interaction = @import("ui_interaction.zig");
const renderer = @import("renderer_software.zig");
const renderer_ir = @import("renderer_ir.zig");
const renderer_present = @import("renderer_present.zig");
const component_gallery = @import("component_gallery.zig");
const site_apps = @import("site_apps.zig");
const site_blog = @import("site_blog.zig");
const site_chrome = @import("site_chrome.zig");
const site_cursor = @import("site_cursor.zig");
const site_images = @import("site_images.zig");
const site_landing = @import("site_landing.zig");
const site_navigation = @import("site_navigation.zig");
const ui = @import("ui.zig");
const ui_codec = @import("ui_codec.zig");
const ui_components = @import("ui_components.zig");
const ui_runtime = @import("ui_runtime.zig");
const varfont = @import("varfont.zig");

const max_width: usize = 4096;
const max_height: usize = 2880;
const max_pixels: usize = max_width * max_height;
const max_input_bytes: usize = 8192;
const max_nodes: usize = 256;
const max_commands: usize = 4096;
const max_interaction_regions: usize = 4096;
const gpu_rect_float_stride: usize = renderer_ir.rect_float_stride;
const gpu_text_vertex_float_stride: usize = renderer_ir.text_vertex_float_stride;
const gpu_icon_vertex_float_stride: usize = renderer_ir.icon_instance_float_stride;
const gpu_icon_line_vertex_float_stride: usize = icon_line_buffer.vertex_float_stride;
const gpu_image_vertex_float_stride: usize = renderer_ir.image_vertex_float_stride;
const max_gpu_rects: usize = 32768;
const max_gpu_text_vertices: usize = 98304;
const max_gpu_icon_vertices: usize = 16384;
const max_gpu_icon_line_vertices: usize = 4194304;
const max_gpu_image_vertices: usize = 384;
const max_gpu_overlay_rects: usize = 512;
const max_gpu_overlay_text_vertices: usize = 8192;
const max_gpu_overlay_icon_vertices: usize = 1024;
const max_gpu_overlay_icon_line_vertices: usize = 1048576;
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
const site_source_url = "https://github.com/edgerun";
const route_bytes_capacity: usize = site_navigation.route_path_capacity;
const route_hash_bytes_capacity: usize = site_navigation.route_hash_capacity;
const host_command_capacity: usize = 4;
const title_text = "EdgeRun Academy";
const dom_surface_id = "edgerun-dom";
const boot_dom_html = "";
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
var interaction_regions: [max_interaction_regions]interaction.Region = undefined;
var clips: [max_clips]ui.Rect = undefined;
var gpu_rect_floats: [max_gpu_rects * gpu_rect_float_stride]f32 = undefined;
var gpu_rect_float_len: usize = 0;
var gpu_text_vertex_floats: [max_gpu_text_vertices * gpu_text_vertex_float_stride]f32 = undefined;
var gpu_text_vertex_float_len: usize = 0;
var gpu_icon_vertex_floats: [max_gpu_icon_vertices * gpu_icon_vertex_float_stride]f32 = undefined;
var gpu_icon_vertex_float_len: usize = 0;
var gpu_icon_line_vertex_floats: [max_gpu_icon_line_vertices * gpu_icon_line_vertex_float_stride]f32 = undefined;
var gpu_icon_line_vertex_float_len: usize = 0;
var gpu_image_vertex_floats: [max_gpu_image_vertices * gpu_image_vertex_float_stride]f32 = undefined;
var gpu_image_vertex_float_len: usize = 0;
var gpu_overlay_rect_floats: [max_gpu_overlay_rects * gpu_rect_float_stride]f32 = undefined;
var gpu_overlay_rect_float_len: usize = 0;
var gpu_overlay_text_vertex_floats: [max_gpu_overlay_text_vertices * gpu_text_vertex_float_stride]f32 = undefined;
var gpu_overlay_text_vertex_float_len: usize = 0;
var gpu_overlay_icon_vertex_floats: [max_gpu_overlay_icon_vertices * gpu_icon_vertex_float_stride]f32 = undefined;
var gpu_overlay_icon_vertex_float_len: usize = 0;
var gpu_overlay_icon_line_vertex_floats: [max_gpu_overlay_icon_line_vertices * gpu_icon_line_vertex_float_stride]f32 = undefined;
var gpu_overlay_icon_line_vertex_float_len: usize = 0;
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
var last_present_transport: renderer_present.Transport = .webgl_buffers;
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
var browser_hover_x: f32 = -1.0;
var browser_hover_y: f32 = -1.0;
var host_commands: [host_command_capacity]HostCommand = [_]HostCommand{.{}} ** host_command_capacity;
var host_command_len: usize = 0;
var next_host_command_id: u32 = 1;
var entropy_pool: [entropy_pool_size]u8 = initialEntropyPool();
var entropy_event_count: u64 = 0;
var ephemeral_seed: [ephemeral_seed_size]u8 = [_]u8{0} ** ephemeral_seed_size;
var ephemeral_public_key: [identity.ed25519_public_size]u8 = [_]u8{0} ** identity.ed25519_public_size;
var ephemeral_identity_id: [identity.id_size]u8 = [_]u8{0} ** identity.id_size;
var public_identity_text: [public_identity_text_len]u8 = [_]u8{0} ** public_identity_text_len;
var ephemeral_identity_ready = false;
var gpu_source_context: u8 = 0;
var host_appearance: HostAppearance = .unknown;

const hover_hit_kind_none: u32 = 255;

const HostAppearance = enum(u32) {
    unknown = 0,
    light = 1,
    dark = 2,
};

const HostAction = enum(u32) {
    none = 0,
    open_url = 1,
};

const HostCommandKind = enum(u32) {
    none = 0,
    open_url = 1,
    push_route_hash = 2,
    set_title = 3,
    set_element_html = 4,
};

const HostCommand = struct {
    kind: HostCommandKind = .none,
    id: u32 = 0,
};

const BrowserEventKind = enum(u32) {
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

const browser_event_prevent_default: u32 = 1 << 0;
const browser_event_schedule_frame: u32 = 1 << 1;
const browser_event_host_command: u32 = 1 << 3;
const browser_event_capture_pointer: u32 = 1 << 4;
const browser_event_release_pointer: u32 = 1 << 5;
const browser_event_error: u32 = 1 << 8;

const CursorKind = site_cursor.Kind;

const SiteView = site_navigation.View;

const SiteState = struct {
    view: SiteView = .landing,
    selected_blog_post_id: u32 = 0,
    blog_arc_filter_index: ?usize = null,
    selected_component_index: ?usize = null,
    scroll_y: f32 = 0.0,
    host_action: HostAction = .none,

    fn resetHostAction(state: *SiteState) void {
        state.host_action = .none;
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

export fn er_ui_gpu_icon_line_vertex_float_stride() u32 {
    return gpu_icon_line_vertex_float_stride;
}

export fn er_ui_gpu_icon_line_vertex_buffer_ptr() usize {
    return @intFromPtr(gpu_icon_line_vertex_floats[0..].ptr);
}

export fn er_ui_gpu_icon_line_vertex_buffer_len() usize {
    return gpu_icon_line_vertex_float_len;
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

export fn er_ui_gpu_overlay_icon_line_vertex_buffer_ptr() usize {
    return @intFromPtr(gpu_overlay_icon_line_vertex_floats[0..].ptr);
}

export fn er_ui_gpu_overlay_icon_line_vertex_buffer_len() usize {
    return gpu_overlay_icon_line_vertex_float_len;
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

export fn er_ui_set_host_appearance(value: u32) u32 {
    host_appearance = hostAppearanceFromInt(value);
    return @intFromEnum(host_appearance);
}

export fn er_ui_host_appearance() u32 {
    return @intFromEnum(host_appearance);
}

fn hostAppearanceFromInt(value: u32) HostAppearance {
    return switch (value) {
        @intFromEnum(HostAppearance.light) => .light,
        @intFromEnum(HostAppearance.dark) => .dark,
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
        return @intFromEnum(HostAction.none);
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

export fn er_ui_site_host_action_kind() u32 {
    return @intFromEnum(site_state.host_action);
}

export fn er_ui_site_host_action_url_ptr() usize {
    return @intFromPtr(site_source_url.ptr);
}

export fn er_ui_site_host_action_url_len() usize {
    return site_source_url.len;
}

export fn er_ui_host_command_count() u32 {
    return @intCast(host_command_len);
}

export fn er_ui_host_command_kind(index: u32) u32 {
    if (index >= host_command_len) return @intFromEnum(HostCommandKind.none);
    return @intFromEnum(host_commands[index].kind);
}

export fn er_ui_host_command_id(index: u32) u32 {
    if (index >= host_command_len) return 0;
    return host_commands[index].id;
}

export fn er_ui_host_command_target_ptr(index: u32) usize {
    if (index >= host_command_len) return 0;
    return switch (host_commands[index].kind) {
        .none, .open_url, .push_route_hash, .set_title => 0,
        .set_element_html => @intFromPtr(dom_surface_id.ptr),
    };
}

export fn er_ui_host_command_target_len(index: u32) usize {
    if (index >= host_command_len) return 0;
    return switch (host_commands[index].kind) {
        .none, .open_url, .push_route_hash, .set_title => 0,
        .set_element_html => dom_surface_id.len,
    };
}

export fn er_ui_host_command_payload_ptr(index: u32) usize {
    if (index >= host_command_len) return 0;
    return switch (host_commands[index].kind) {
        .none => 0,
        .open_url => @intFromPtr(site_source_url.ptr),
        .push_route_hash => {
            refreshRouteHash();
            return @intFromPtr(route_hash_bytes[0..].ptr);
        },
        .set_title => @intFromPtr(title_text.ptr),
        .set_element_html => @intFromPtr(boot_dom_html.ptr),
    };
}

export fn er_ui_host_command_payload_len(index: u32) usize {
    if (index >= host_command_len) return 0;
    return switch (host_commands[index].kind) {
        .none => 0,
        .open_url => site_source_url.len,
        .push_route_hash => {
            refreshRouteHash();
            return route_hash_len;
        },
        .set_title => title_text.len,
        .set_element_html => boot_dom_html.len,
    };
}

export fn er_ui_host_command_clear() u32 {
    clearHostCommands();
    site_state.resetHostAction();
    last_error = .ok;
    return @intFromEnum(ErrorCode.ok);
}

export fn er_ui_bootstrap_js_ptr() usize {
    return @intFromPtr(browser_runtime_js.source.ptr);
}

export fn er_ui_bootstrap_js_len() usize {
    return browser_runtime_js.source.len;
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

export fn er_ui_site_set_browser_route_hash(hash_len: usize) u32 {
    if (hash_len > input_bytes.len) return finishError(.bad_input);
    const route_path = routePathFromBrowserHash(input_bytes[0..hash_len]) catch return finishError(.bad_input);
    applyRoutePath(route_path);
    last_error = .ok;
    return @intFromEnum(ErrorCode.ok);
}

export fn er_ui_site_activate_hit(hit_id: u32) u32 {
    site_state.resetHostAction();
    clearHostCommands();
    if (site_navigation.fromHit(hit_id, currentRoute())) |route| {
        applyRoute(route);
        return @intFromEnum(site_state.host_action);
    }
    switch (hit_id) {
        site_chrome.source_button_id => {
            site_state.host_action = .open_url;
            queueHostCommand(.open_url) catch return finishError(.bad_input);
        },
        site_landing.reveal_identity_button_id => {
            if (!ephemeral_identity_ready) {
                generateEphemeralIdentity() catch return finishError(.identity_failed);
            }
        },
        else => {},
    }
    return @intFromEnum(site_state.host_action);
}

export fn er_ui_site_key_event(key_len: usize, ctrl: u32, meta: u32, alt: u32) u32 {
    _ = ctrl;
    _ = meta;
    _ = alt;
    if (key_len > input_bytes.len) return finishError(.bad_input);
    last_error = .ok;
    return 0;
}

export fn er_ui_browser_event(kind_raw: u32, x: f32, y: f32, delta_y: f32, ctrl: u32, meta: u32, alt: u32, text_len: usize, width: f32, height: f32) u32 {
    const kind: BrowserEventKind = switch (kind_raw) {
        @intFromEnum(BrowserEventKind.resize) => .resize,
        @intFromEnum(BrowserEventKind.wheel) => .wheel,
        @intFromEnum(BrowserEventKind.pointer_move) => .pointer_move,
        @intFromEnum(BrowserEventKind.pointer_leave) => .pointer_leave,
        @intFromEnum(BrowserEventKind.pointer_down) => .pointer_down,
        @intFromEnum(BrowserEventKind.pointer_up) => .pointer_up,
        @intFromEnum(BrowserEventKind.popstate) => .popstate,
        @intFromEnum(BrowserEventKind.hashchange) => .hashchange,
        @intFromEnum(BrowserEventKind.key_down) => .key_down,
        else => {
            _ = finishError(.bad_input);
            return browser_event_error;
        },
    };

    switch (kind) {
        .resize => return browser_event_schedule_frame,
        .wheel => {
            const code = er_ui_site_scroll_by(delta_y, width, height);
            if (code != @intFromEnum(ErrorCode.ok)) return browser_event_error;
            return browser_event_prevent_default | browser_event_schedule_frame;
        },
        .pointer_move => {
            browser_hover_x = x;
            browser_hover_y = y;
            _ = er_ui_pointer_move(x, y);
            return browser_event_schedule_frame;
        },
        .pointer_leave => {
            browser_hover_x = -1.0;
            browser_hover_y = -1.0;
            runtime_state.clearHover();
            return browser_event_schedule_frame;
        },
        .pointer_down => {
            browser_hover_x = x;
            browser_hover_y = y;
            _ = er_ui_pointer_down(x, y);
            return browser_event_capture_pointer | browser_event_schedule_frame;
        },
        .pointer_up => {
            browser_hover_x = x;
            browser_hover_y = y;
            _ = er_ui_site_pointer_up(x, y);
            queueHostCommand(.push_route_hash) catch return browser_event_error;
            const result = browser_event_release_pointer | browser_event_host_command | browser_event_schedule_frame;
            return result;
        },
        .popstate, .hashchange => {
            const code = er_ui_site_set_browser_route_hash(text_len);
            if (code != @intFromEnum(ErrorCode.ok)) return browser_event_error;
            return browser_event_schedule_frame;
        },
        .key_down => {
            const handled = er_ui_site_key_event(text_len, ctrl, meta, alt);
            if (handled == 0) return 0;
            if (handled != 1) return browser_event_error;
            return browser_event_prevent_default | browser_event_schedule_frame;
        },
    }
}

export fn er_ui_browser_event_bytes(input_len: usize, width: f32, height: f32, frame_ms: f32) u32 {
    _ = frame_ms;
    if (input_len > input_bytes.len) return finishError(.bad_input);
    const envelope = input_bytes[0..input_len];
    var fields = std.mem.splitScalar(u8, envelope, '\n');
    const event_name = fields.next() orelse return finishError(.bad_input);
    const kind = browserEventKindFromName(event_name) orelse {
        last_error = .ok;
        return 0;
    };
    const x = parseBrowserEventFloat(fields.next() orelse "") catch return finishError(.bad_input);
    const y = parseBrowserEventFloat(fields.next() orelse "") catch return finishError(.bad_input);
    const delta_y = parseBrowserEventFloat(fields.next() orelse "") catch return finishError(.bad_input);
    const ctrl = parseBrowserEventFlag(fields.next() orelse "") catch return finishError(.bad_input);
    const meta = parseBrowserEventFlag(fields.next() orelse "") catch return finishError(.bad_input);
    const alt = parseBrowserEventFlag(fields.next() orelse "") catch return finishError(.bad_input);
    const text = fields.next() orelse "";
    if (text.len > input_bytes.len) return finishError(.bad_input);
    const kind_raw = @intFromEnum(kind);
    std.mem.copyForwards(u8, input_bytes[0..text.len], text);
    return er_ui_browser_event(kind_raw, x, y, delta_y, ctrl, meta, alt, text.len, width, height);
}

export fn er_ui_browser_boot() u32 {
    clearHostCommands();
    queueHostCommand(.set_title) catch return finishError(.bad_input);
    queueHostCommand(.set_element_html) catch return finishError(.bad_input);
    last_error = .ok;
    return browser_event_host_command | browser_event_schedule_frame;
}

fn browserEventKindFromName(name: []const u8) ?BrowserEventKind {
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

fn parseBrowserEventFloat(value: []const u8) !f32 {
    if (value.len == 0) return 0.0;
    return std.fmt.parseFloat(f32, value);
}

fn parseBrowserEventFlag(value: []const u8) !u32 {
    if (std.mem.eql(u8, value, "1")) return 1;
    if (std.mem.eql(u8, value, "0") or value.len == 0) return 0;
    return error.InvalidBrowserEventFlag;
}

fn queueHostCommand(kind: HostCommandKind) error{HostCommandBudget}!void {
    if (host_command_len >= host_commands.len) return error.HostCommandBudget;
    host_commands[host_command_len] = .{ .kind = kind, .id = nextHostCommandId() };
    host_command_len += 1;
}

fn nextHostCommandId() u32 {
    const value = next_host_command_id;
    next_host_command_id +%= 1;
    if (next_host_command_id == 0) next_host_command_id = 1;
    return value;
}

fn clearHostCommands() void {
    for (host_commands[0..host_command_len]) |*command| command.* = .{};
    host_command_len = 0;
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
        .components => component_gallery.contentHeightForState(width, galleryState(0, component_gallery.grid_gap_default, site_state.scroll_y, browser_hover_x, browser_hover_y)),
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
    var frame_regions: [max_interaction_regions]interaction.Region = undefined;
    var collector = interaction.Collector.init(&frame_regions);
    component_gallery.renderComponentGallery(&scene, &collector, .{
        .x = 0,
        .y = 0,
        .w = @floatFromInt(frame_width),
        .h = @floatFromInt(frame_height),
    }, galleryState(layout_raw, grid_gap, scroll_y, hover_x, hover_y)) catch return finishError(.render_failed);

    return finishCpuSceneFrame(surface, scene, collector.written(), .{ .enabled = true, .x = hover_x, .y = hover_y }, .bg);
}

export fn er_ui_build_component_gallery_gpu_frame(width: u32, height: u32, scroll_y: f32) u32 {
    return er_ui_build_component_gallery_gpu_frame_layout_gap_hover(width, height, scroll_y, @intFromEnum(component_gallery.LayoutMode.masonry), component_gallery.grid_gap_default, -1.0, -1.0);
}

export fn er_ui_build_component_gallery_gpu_frame_layout_gap_hover(width: u32, height: u32, scroll_y: f32, layout_raw: u32, grid_gap: f32, hover_x: f32, hover_y: f32) u32 {
    if (!setFrameSize(width, height)) return finishError(.bad_size);

    var scene = ui.Scene.init(&commands);
    var frame_regions: [max_interaction_regions]interaction.Region = undefined;
    var collector = interaction.Collector.init(&frame_regions);
    component_gallery.renderComponentGallery(&scene, &collector, .{
        .x = 0,
        .y = 0,
        .w = @floatFromInt(frame_width),
        .h = @floatFromInt(frame_height),
    }, galleryState(layout_raw, grid_gap, scroll_y, hover_x, hover_y)) catch return finishError(.render_failed);

    return finishGpuSceneFrame(scene, collector.written(), hover_x, hover_y);
}

export fn er_ui_build_site_landing_gpu_frame(width: u32, height: u32, scroll_y: f32, hover_x: f32, hover_y: f32, frame_ms: f32) u32 {
    if (!setFrameSize(width, height)) return finishError(.bad_size);

    var scene = ui.Scene.initWithClips(&commands, &clips);
    var frame_regions: [max_interaction_regions]interaction.Region = undefined;
    var collector = interaction.Collector.init(&frame_regions);
    site_landing.render(&scene, &collector, .{
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

    return finishGpuSceneFrame(scene, collector.written(), hover_x, hover_y);
}

export fn er_ui_build_site_blog_gpu_frame(width: u32, height: u32, scroll_y: f32, hover_x: f32, hover_y: f32, selected_post_id: u32) u32 {
    if (!setFrameSize(width, height)) return finishError(.bad_size);

    var scene = ui.Scene.initWithClips(&commands, &clips);
    var frame_regions: [max_interaction_regions]interaction.Region = undefined;
    var collector = interaction.Collector.init(&frame_regions);
    site_blog.render(&scene, &collector, .{
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

    return finishGpuSceneFrame(scene, collector.written(), hover_x, hover_y);
}

export fn er_ui_build_site_apps_gpu_frame(width: u32, height: u32, scroll_y: f32, hover_x: f32, hover_y: f32) u32 {
    if (!setFrameSize(width, height)) return finishError(.bad_size);

    var scene = ui.Scene.initWithClips(&commands, &clips);
    var frame_regions: [max_interaction_regions]interaction.Region = undefined;
    var collector = interaction.Collector.init(&frame_regions);
    site_apps.render(&scene, &collector, .{
        .x = 0,
        .y = 0,
        .w = @floatFromInt(frame_width),
        .h = @floatFromInt(frame_height),
    }, .{
        .scroll_y = scroll_y,
        .hover_x = hover_x,
        .hover_y = hover_y,
    }) catch return finishError(.render_failed);

    return finishGpuSceneFrame(scene, collector.written(), hover_x, hover_y);
}

export fn er_ui_build_site_gpu_frame(width: u32, height: u32, hover_x: f32, hover_y: f32, frame_ms: f32) u32 {
    if (!setFrameSize(width, height)) return finishError(.bad_size);
    site_state.scroll_y = @min(site_state.scroll_y, siteScrollLimit(@floatFromInt(frame_width), @floatFromInt(frame_height)));

    var scene = ui.Scene.initWithClips(&commands, &clips);
    var frame_regions: [max_interaction_regions]interaction.Region = undefined;
    var collector = interaction.Collector.init(&frame_regions);
    switch (site_state.view) {
        .landing => site_landing.render(&scene, &collector, .{
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
        .blog => site_blog.render(&scene, &collector, .{
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
        .apps => site_apps.render(&scene, &collector, .{
            .x = 0,
            .y = 0,
            .w = @floatFromInt(frame_width),
            .h = @floatFromInt(frame_height),
        }, .{
            .scroll_y = site_state.scroll_y,
            .hover_x = hover_x,
            .hover_y = hover_y,
        }) catch return finishError(.render_failed),
        .components => component_gallery.renderComponentGallery(&scene, &collector, .{
            .x = 0,
            .y = 0,
            .w = @floatFromInt(frame_width),
            .h = @floatFromInt(frame_height),
        }, galleryState(@intFromEnum(component_gallery.LayoutMode.masonry), component_gallery.grid_gap_default, site_state.scroll_y, hover_x, hover_y)) catch return finishError(.render_failed),
    }
    return finishGpuSceneFrame(scene, collector.written(), hover_x, hover_y);
}

export fn er_ui_build_browser_frame(width: u32, height: u32, frame_ms: f32) u32 {
    return er_ui_build_site_gpu_frame(width, height, browser_hover_x, browser_hover_y, frame_ms);
}

export fn er_ui_render_browser_frame(width: u32, height: u32, frame_ms: f32) u32 {
    const surface = beginFrame(width, height) orelse return finishError(.bad_size);
    _ = frame_ms;
    return renderBrowserSiteCpu(surface, browser_hover_x, browser_hover_y);
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

fn renderBrowserSiteCpu(surface: renderer.Surface, hover_x: f32, hover_y: f32) u32 {
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var frame_regions: [max_interaction_regions]interaction.Region = undefined;
    var collector = interaction.Collector.init(&frame_regions);
    switch (site_state.view) {
        .landing => site_landing.render(&scene, &collector, .{
            .x = 0,
            .y = 0,
            .w = @floatFromInt(frame_width),
            .h = @floatFromInt(frame_height),
        }, .{
            .scroll_y = site_state.scroll_y,
            .hover_x = hover_x,
            .hover_y = hover_y,
        }) catch return finishError(.render_failed),
        .blog => site_blog.render(&scene, &collector, .{
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
        .apps => site_apps.render(&scene, &collector, .{
            .x = 0,
            .y = 0,
            .w = @floatFromInt(frame_width),
            .h = @floatFromInt(frame_height),
        }, .{
            .scroll_y = site_state.scroll_y,
            .hover_x = hover_x,
            .hover_y = hover_y,
        }) catch return finishError(.render_failed),
        .components => component_gallery.renderComponentGallery(&scene, &collector, .{
            .x = 0,
            .y = 0,
            .w = @floatFromInt(frame_width),
            .h = @floatFromInt(frame_height),
        }, galleryState(@intFromEnum(component_gallery.LayoutMode.masonry), component_gallery.grid_gap_default, site_state.scroll_y, hover_x, hover_y)) catch return finishError(.render_failed),
    }
    return finishCpuSceneFrame(surface, scene, collector.written(), .{ .enabled = true, .x = hover_x, .y = hover_y }, .bg);
}

fn finishGpuSceneFrame(scene: ui.Scene, regions: []const interaction.Region, hover_x: f32, hover_y: f32) u32 {
    storeLastRegions(regions) catch return finishError(.render_failed);
    runtime_state.refreshHover(lastRegions(), hover_x, hover_y);
    var frame_scene = scene;
    site_cursor.render(&frame_scene, hover_x, hover_y, currentCursorKind()) catch return finishError(.render_failed);
    last_command_count = frame_scene.written().len;
    ensureFontAtlas() catch return finishError(.font_atlas);
    const buffers = gpuBuffers();
    renderer_ir.packScene(buffers, gpuSources(), frame_scene.written()) catch return finishError(.gpu_budget);
    packBrowserIconLines() catch return finishError(.gpu_budget);
    presentBrowserBuffers(buffers) catch return finishError(.render_failed);
    last_error = .ok;
    return @intFromEnum(ErrorCode.ok);
}

const HoverUpdate = struct {
    enabled: bool,
    x: f32 = 0.0,
    y: f32 = 0.0,
};

fn finishCpuSceneFrame(surface: renderer.Surface, scene: ui.Scene, regions: []const interaction.Region, hover: HoverUpdate, background: ui.Color) u32 {
    storeLastRegions(regions) catch return finishError(.render_failed);
    if (hover.enabled) runtime_state.refreshHover(lastRegions(), hover.x, hover.y);
    var frame_scene = scene;
    if (hover.enabled) site_cursor.render(&frame_scene, hover.x, hover.y, currentCursorKind()) catch return finishError(.render_failed);
    last_command_count = frame_scene.written().len;
    renderSceneIr(surface, frame_scene.written(), background) catch return finishError(.render_failed);
    last_error = .ok;
    return @intFromEnum(ErrorCode.ok);
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
    const image_texture = try site_images.cloudMeme();
    const receipt = try surface.renderIrFrameWithResources(buffers, .{
        .font = .{ .width = font_atlas_width, .height = font_atlas_height, .alpha = &font_atlas_alpha },
        .image = image_texture,
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
            .image_texture = true,
        },
    });
    recordPresentation(receipt);
}

fn packBrowserIconLines() icon_line_buffer.Error!void {
    try icon_line_buffer.packIconInstances(
        gpu_icon_vertex_floats[0..gpu_icon_vertex_float_len],
        &gpu_icon_line_vertex_floats,
        &gpu_icon_line_vertex_float_len,
    );
    try icon_line_buffer.packIconInstances(
        gpu_overlay_icon_vertex_floats[0..gpu_overlay_icon_vertex_float_len],
        &gpu_overlay_icon_line_vertex_floats,
        &gpu_overlay_icon_line_vertex_float_len,
    );
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

fn galleryState(layout_raw: u32, grid_gap: f32, scroll_y: f32, hover_x: f32, hover_y: f32) component_gallery.ComponentGalleryState {
    return .{
        .layout = component_gallery.LayoutMode.fromRaw(layout_raw),
        .grid_gap = grid_gap,
        .scroll_y = scroll_y,
        .hover_x = hover_x,
        .hover_y = hover_y,
        .selected_component_index = site_state.selected_component_index,
    };
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

fn routePathFromBrowserHash(hash: []const u8) error{InvalidBrowserRoute}![]const u8 {
    return site_navigation.pathFromBrowserHash(hash);
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

test "browser cpu ir finish preserves hover state when disabled" {
    runtime_state.hovered = .{ .kind = .button, .id = 99, .bounds = ui.Rect.init(0, 0, 1, 1) };
    var local_commands: [1]ui.Command = undefined;
    const scene = ui.Scene.init(&local_commands);
    var local_pixels: [4]ui.Color = undefined;
    const surface = try renderer.Surface.init(2, 2, &local_pixels);

    try std.testing.expectEqual(@as(u32, 0), finishCpuSceneFrame(surface, scene, &.{}, .{ .enabled = false }, .bg));
    try std.testing.expectEqual(@intFromEnum(ui.HitKind.button), er_ui_hover_hit_kind());
    try std.testing.expectEqual(@as(u32, 99), er_ui_hover_hit_id());
}

test "browser component gallery builds packed webgl buffers and browser-ready icon lines" {
    font_atlas_ready = false;
    const code = er_ui_build_component_gallery_gpu_frame_layout_gap_hover(960, 640, 0.0, @intFromEnum(component_gallery.LayoutMode.masonry), component_gallery.grid_gap_default, -1.0, -1.0);
    try std.testing.expectEqual(@as(u32, 0), code);
    try std.testing.expect(font_atlas_ready);
    try std.testing.expectEqual(renderer_present.Transport.webgl_buffers, last_present_transport);
    try std.testing.expect(last_present_primitive_count > 0);
    try std.testing.expect(gpu_rect_float_len > 0);
    try std.testing.expect(gpu_text_vertex_float_len > 0);
    try std.testing.expect(gpu_icon_vertex_float_len > 0);
    try std.testing.expect(gpu_icon_line_vertex_float_len > 0);
    try std.testing.expect(er_ui_font_atlas_ptr() != 0);
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
    const code = er_ui_build_site_landing_gpu_frame(1280, 800, 0.0, 1065.0, 32.0, 0.0);
    try std.testing.expectEqual(@as(u32, 0), code);
    try std.testing.expect(gpu_rect_float_len > 0);
    try std.testing.expect(gpu_text_vertex_float_len > 0);
    try std.testing.expect(gpu_icon_vertex_float_len > 0);
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

test "browser site apps builds packed webgl buffers and hit state" {
    const code = er_ui_build_site_apps_gpu_frame(1280, 900, 0.0, 360.0, 700.0);
    try std.testing.expectEqual(@as(u32, 0), code);
    try std.testing.expect(gpu_rect_float_len > 0);
    try std.testing.expect(gpu_text_vertex_float_len > 0);
    try std.testing.expect(gpu_icon_vertex_float_len > 0);
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
    try std.testing.expectEqual(@intFromEnum(HostAction.none), er_ui_site_activate_hit(site_chrome.blog_button_id));
    try std.testing.expectEqual(site_blog.indexContentHeight(1280.0), er_ui_site_content_height(1280.0));
    try std.testing.expectEqual(@intFromEnum(HostAction.none), er_ui_site_activate_hit(site_blog.postIdAt(0)));
    try std.testing.expectEqual(site_blog.postContentHeight(1280.0, site_blog.postIdAt(0)), er_ui_site_content_height(1280.0));
    try std.testing.expectEqual(@intFromEnum(HostAction.open_url), er_ui_site_activate_hit(site_chrome.source_button_id));
    try std.testing.expectEqual(@intFromEnum(HostAction.open_url), er_ui_site_host_action_kind());
    try std.testing.expectEqual(site_source_url.len, er_ui_site_host_action_url_len());
    try std.testing.expect(er_ui_site_host_action_url_ptr() != 0);
    try std.testing.expectEqual(@as(u32, 1), er_ui_host_command_count());
    try std.testing.expectEqual(@intFromEnum(HostCommandKind.open_url), er_ui_host_command_kind(0));
    try std.testing.expect(er_ui_host_command_id(0) != 0);
    try std.testing.expectEqual(site_source_url.len, er_ui_host_command_payload_len(0));
    try std.testing.expect(er_ui_host_command_payload_ptr(0) != 0);
    try std.testing.expectEqual(@as(u32, 0), er_ui_host_command_clear());
    try std.testing.expectEqual(@as(u32, 0), er_ui_host_command_count());
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

    try std.testing.expectEqual(@as(u32, 0), er_ui_site_set_browser_route_hash(writeInputForTest("#/academy")));
    try std.testing.expectEqual(site_blog.indexContentHeight(1280.0), er_ui_site_content_height(1280.0));
    try std.testing.expectEqualStrings("/academy", route_bytes[0..er_ui_site_route_path_len()]);
    try std.testing.expectEqualStrings("#/academy", route_hash_bytes[0..er_ui_site_route_hash_len()]);

    const route = "#/academy/40100";
    try std.testing.expectEqual(@as(u32, 0), er_ui_site_set_browser_route_hash(writeInputForTest(route)));
    try std.testing.expectEqual(site_blog.postContentHeight(1280.0, site_blog.postIdAt(0)), er_ui_site_content_height(1280.0));
    try std.testing.expectEqualStrings("/academy/40100", route_bytes[0..er_ui_site_route_path_len()]);
    try std.testing.expectEqualStrings("#/academy/40100", route_hash_bytes[0..er_ui_site_route_hash_len()]);

    try std.testing.expectEqual(@as(u32, 0), er_ui_site_set_browser_route_hash(writeInputForTest("")));
    try std.testing.expectEqual(site_landing.contentHeight(1280.0), er_ui_site_content_height(1280.0));
    try std.testing.expectEqualStrings("/", route_bytes[0..er_ui_site_route_path_len()]);
    try std.testing.expectEqualStrings("", route_hash_bytes[0..er_ui_site_route_hash_len()]);

    try std.testing.expectEqual(@as(u32, 0), er_ui_site_set_browser_route_hash(writeInputForTest("#/apps")));
    try std.testing.expectEqual(site_apps.contentHeight(1280.0), er_ui_site_content_height(1280.0));
    try std.testing.expectEqualStrings("/apps", route_bytes[0..er_ui_site_route_path_len()]);

    try std.testing.expectEqual(@as(u32, 0), er_ui_site_set_browser_route_hash(writeInputForTest("#/docs/components/button")));
    const button_index = component_gallery.indexBySlug("button").?;
    try std.testing.expectEqual(button_index, site_state.selected_component_index.?);
    try std.testing.expectEqual(component_gallery.contentHeightForState(1280.0, .{ .selected_component_index = button_index }), er_ui_site_content_height(1280.0));
    try std.testing.expectEqualStrings("/docs/components/button", route_bytes[0..er_ui_site_route_path_len()]);

    try std.testing.expectEqual(@as(u32, @intFromEnum(ErrorCode.bad_input)), er_ui_site_set_browser_route_hash(writeInputForTest("#academy")));
    try std.testing.expectEqualStrings("/docs/components/button", route_bytes[0..er_ui_site_route_path_len()]);
}

fn writeInputForTest(value: []const u8) usize {
    @memcpy(input_bytes[0..value.len], value);
    return value.len;
}

fn browserEventBytesForTest(value: []const u8, width: f32, height: f32) u32 {
    return er_ui_browser_event_bytes(writeInputForTest(value), width, height, 0);
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
    browser_hover_x = -1.0;
    browser_hover_y = -1.0;
    defer site_state = .{};
    defer runtime_state = .{};

    try std.testing.expectEqual(
        browser_event_schedule_frame,
        browserEventBytesForTest("pointermove\n42\n88\n0\n0\n0\n0\n", 1280.0, 900.0),
    );
    try std.testing.expectEqual(@as(f32, 42.0), browser_hover_x);
    try std.testing.expectEqual(@as(f32, 88.0), browser_hover_y);

    try std.testing.expectEqual(
        browser_event_prevent_default | browser_event_schedule_frame,
        browserEventBytesForTest("wheel\n0\n0\n120\n0\n0\n0\n", 1280.0, 900.0),
    );
    try std.testing.expectEqual(@as(f32, 120.0), site_state.scroll_y);

    try std.testing.expectEqual(
        browser_event_schedule_frame,
        browserEventBytesForTest("hashchange\n0\n0\n0\n0\n0\n0\n#/apps", 1280.0, 900.0),
    );
    try std.testing.expectEqualStrings("/apps", route_bytes[0..er_ui_site_route_path_len()]);

    try std.testing.expectEqual(@as(u32, 0), browserEventBytesForTest("keyup\n0\n0\n0\n0\n0\n0\nk", 1280.0, 900.0));
}

test "browser native event pump owns dom event interpretation" {
    site_state = .{};
    runtime_state = .{};
    clearHostCommands();
    browser_hover_x = -1.0;
    browser_hover_y = -1.0;
    last_command_count = 0;
    defer site_state = .{};
    defer runtime_state = .{};
    defer clearHostCommands();

    try std.testing.expectEqual(browser_event_schedule_frame, er_ui_browser_event(@intFromEnum(BrowserEventKind.resize), 0, 0, 0, 0, 0, 0, 0, 1280.0, 900.0));

    const wheel_result = er_ui_browser_event(@intFromEnum(BrowserEventKind.wheel), 0, 0, 320.0, 0, 0, 0, 0, 1280.0, 900.0);
    try std.testing.expectEqual(browser_event_prevent_default | browser_event_schedule_frame, wheel_result);
    try std.testing.expectEqual(@as(f32, 320.0), site_state.scroll_y);

    try std.testing.expectEqual(browser_event_schedule_frame, er_ui_browser_event(@intFromEnum(BrowserEventKind.pointer_move), 42.0, 88.0, 0, 0, 0, 0, 0, 1280.0, 900.0));
    try std.testing.expectEqual(@as(f32, 42.0), browser_hover_x);
    try std.testing.expectEqual(@as(f32, 88.0), browser_hover_y);
    try std.testing.expectEqual(browser_event_schedule_frame, er_ui_browser_event(@intFromEnum(BrowserEventKind.pointer_leave), 0, 0, 0, 0, 0, 0, 0, 1280.0, 900.0));
    try std.testing.expectEqual(@as(f32, -1.0), browser_hover_x);
    try std.testing.expectEqual(@as(f32, -1.0), browser_hover_y);

    try std.testing.expectEqual(@as(u32, 0), er_ui_browser_event(@intFromEnum(BrowserEventKind.key_down), 0, 0, 0, 0, 0, 0, writeInputForTest("/"), 1280.0, 900.0));

    try std.testing.expectEqual(browser_event_schedule_frame, er_ui_browser_event(@intFromEnum(BrowserEventKind.hashchange), 0, 0, 0, 0, 0, 0, writeInputForTest("#/apps"), 1280.0, 900.0));
    try std.testing.expectEqualStrings("/apps", route_bytes[0..er_ui_site_route_path_len()]);

    try std.testing.expectEqual(browser_event_error, er_ui_browser_event(@intFromEnum(BrowserEventKind.hashchange), 0, 0, 0, 0, 0, 0, writeInputForTest("#apps"), 1280.0, 900.0));
    try std.testing.expectEqual(@intFromEnum(ErrorCode.bad_input), er_ui_last_error());
    try std.testing.expectEqualStrings("/apps", route_bytes[0..er_ui_site_route_path_len()]);

    site_state.host_action = .none;
    last_command_count = 0;
    try storeLastRegions(&.{.{ .slot = 0, .kind = .button, .id = site_chrome.source_button_id, .bounds = ui.Rect.init(0, 0, 40, 40) }});
    const pointer_result = er_ui_browser_event(@intFromEnum(BrowserEventKind.pointer_up), 8.0, 8.0, 0, 0, 0, 0, 0, 1280.0, 900.0);
    try std.testing.expectEqual(browser_event_release_pointer | browser_event_schedule_frame | browser_event_host_command, pointer_result);
    try std.testing.expectEqual(@as(u32, 2), er_ui_host_command_count());
    try std.testing.expectEqual(@intFromEnum(HostCommandKind.open_url), er_ui_host_command_kind(0));
    try std.testing.expectEqual(@intFromEnum(HostCommandKind.push_route_hash), er_ui_host_command_kind(1));
    try std.testing.expect(er_ui_host_command_id(0) != 0);
    try std.testing.expect(er_ui_host_command_id(1) != 0);
    try std.testing.expect(er_ui_host_command_id(0) != er_ui_host_command_id(1));
    try std.testing.expectEqualStrings("#/apps", (@as([*]const u8, @ptrFromInt(er_ui_host_command_payload_ptr(1))))[0..er_ui_host_command_payload_len(1)]);
}

test "browser native boot emits document title host command" {
    clearHostCommands();
    defer clearHostCommands();

    const result = er_ui_browser_boot();
    try std.testing.expectEqual(browser_event_host_command | browser_event_schedule_frame, result);
    try std.testing.expectEqual(@as(u32, 2), er_ui_host_command_count());
    try std.testing.expectEqual(@intFromEnum(HostCommandKind.set_title), er_ui_host_command_kind(0));
    try std.testing.expect(er_ui_host_command_id(0) != 0);
    try std.testing.expectEqual(@as(usize, 0), er_ui_host_command_target_len(0));
    try std.testing.expectEqualStrings(title_text, (@as([*]const u8, @ptrFromInt(er_ui_host_command_payload_ptr(0))))[0..er_ui_host_command_payload_len(0)]);
    try std.testing.expectEqual(@intFromEnum(HostCommandKind.set_element_html), er_ui_host_command_kind(1));
    try std.testing.expect(er_ui_host_command_id(1) != 0);
    try std.testing.expect(er_ui_host_command_id(0) != er_ui_host_command_id(1));
    try std.testing.expectEqualStrings(dom_surface_id, (@as([*]const u8, @ptrFromInt(er_ui_host_command_target_ptr(1))))[0..er_ui_host_command_target_len(1)]);
    try std.testing.expectEqualStrings(boot_dom_html, (@as([*]const u8, @ptrFromInt(er_ui_host_command_payload_ptr(1))))[0..er_ui_host_command_payload_len(1)]);
}

test "browser native records host appearance preference" {
    try std.testing.expectEqual(@as(u32, 1), er_ui_set_host_appearance(1));
    try std.testing.expectEqual(@as(u32, 1), er_ui_host_appearance());
    try std.testing.expectEqual(@as(u32, 2), er_ui_set_host_appearance(2));
    try std.testing.expectEqual(@as(u32, 2), er_ui_host_appearance());
    try std.testing.expectEqual(@as(u32, 0), er_ui_set_host_appearance(99));
    try std.testing.expectEqual(@as(u32, 0), er_ui_host_appearance());
}

test "browser native exposes eval bootstrap javascript bytes" {
    const bootstrap_js: [*]const u8 = @ptrFromInt(er_ui_bootstrap_js_ptr());
    const bytes = bootstrap_js[0..er_ui_bootstrap_js_len()];

    try std.testing.expectEqualStrings(browser_runtime_js.source, bytes);
    try std.testing.expect(std.mem.indexOf(u8, bytes, "document.body.innerHTML") != null);
    try std.testing.expect(std.mem.indexOf(u8, bytes, "WebAssembly.instantiateStreaming") == null);
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
    const surface = try renderer.Surface.init(8, 8, &local_pixels);

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
    try std.testing.expectEqual(@intFromEnum(HostAction.none), er_ui_site_pointer_up(8, 8));
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
    try std.testing.expectEqual(@intFromEnum(HostAction.none), er_ui_site_pointer_up(8, 88));
    try std.testing.expectEqual(site_landing.contentHeight(1280.0), er_ui_site_content_height(1280.0));
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

test "browser icon buffer stores semantic icon instances" {
    gpu_icon_vertex_float_len = 0;
    try renderer_ir.pushIcon(gpuBuffers(), .base, .{
        .bounds = ui.Rect.init(1, 2, 3, 4),
        .color = .accent,
        .icon_id = icon.id(.search),
    });
    const instance = try renderer_ir.iconAt(gpu_icon_vertex_floats[0..gpu_icon_vertex_float_len], 0);
    try std.testing.expectEqual(ui.Rect.init(1, 2, 3, 4), instance.bounds);
    try std.testing.expectEqual(icon.id(.search), instance.icon_id);
}

test "browser cpu render frame writes pixels for byte bridge" {
    const code = er_ui_render_browser_frame(640, 480, 0.0);
    try std.testing.expectEqual(@as(u32, 0), code);
    try std.testing.expectEqual(renderer_present.Transport.software_pixels, last_present_transport);
    try std.testing.expect(er_ui_pixels_ptr() != 0);
}
