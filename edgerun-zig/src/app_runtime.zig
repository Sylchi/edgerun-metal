const std = @import("std");
const bytes = @import("bytes.zig");
const web_host_js = @import("web_host_js.zig");
const clock = @import("clock.zig");
const source_object = @import("embedded_source_object").bytes;
const compiler_wasm = @import("embedded_wasm_compiler").bytes;
const icon_svg = @import("icon_svg.zig");
const identity = @import("identity.zig");
const interaction = @import("ui_interaction.zig");
const object = @import("object.zig");
const renderer_font_atlas = @import("render/font_atlas.zig");
const renderer_pipeline = @import("render/pipeline.zig");
const component_gallery = @import("component_gallery.zig");
const app_blog = @import("app_blog.zig");
const app_chrome = @import("app_chrome.zig");
const app_cursor = @import("app_cursor.zig");
const app_docs = @import("app_docs.zig");
const app_frame = @import("app_frame.zig");
const app_images = @import("app_images.zig");
const app_input_event = @import("app_input_event.zig");
const app_landing = @import("app_landing.zig");
const app_navigation = @import("app_navigation.zig");
const app_source = @import("app_source.zig");
const component_union = @import("ui/components/Component.zig");
const icon_component = @import("ui/components/Icon.zig");
const node_renderer = @import("ui/components/NodeRenderer.zig");
const ui = @import("ui.zig");
const ui_codec = @import("ui_codec.zig");
const ui_component_common = @import("ui_component_common.zig");
const vfs = @import("vfs.zig");
const ui_runtime = @import("ui_runtime.zig");
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
const default_source_editor_label = "src/er/self_host/main.er";
const max_source_editor_label_bytes: usize = 128;
const max_source_editor_bytes: usize = 512 * 1024;
const source_editor_tab = "    ";
const source_editor_page_lines: usize = 16;
const source_editor_visible_lines: usize = 32;
const source_editor_scroll_margin_lines: usize = 3;
const max_source_editor_undo_entries: usize = 8;
const max_source_file_entries: usize = 128;
const max_source_file_label_bytes: usize = 16 * 1024;
const max_source_search_bytes: usize = 128;
const source_editor_wheel_pixels_per_line: f32 = 36.0;
const max_compiler_diagnostic_bytes: usize = 192;
const max_source_compile_summary_bytes: usize = 192;
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
const focus_ring_outset: f32 = 3.0;
const focus_ring_radius: f32 = 8.0;
const font_atlas_width: usize = renderer_font_atlas.width;
const font_atlas_height: usize = renderer_font_atlas.height;
const min_device_scale: f32 = 1.0;
const default_device_scale: f32 = 1.0;
const max_device_scale: f32 = 4.0;
const app_source_url = "https://github.com/edgerun";
const route_bytes_capacity: usize = app_navigation.route_path_capacity;
const route_hash_bytes_capacity: usize = app_navigation.route_hash_capacity;
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
var source_editor_preferred_column: usize = 0;
var source_editor_selection_anchor: usize = 0;
var source_editor_selection_active = false;
var source_editor_scroll_line: usize = 0;
var source_editor_loaded = false;
var source_editor_dirty = false;
var source_editor_status: SourceEditorStatus = .not_loaded;
var source_editor_label: []const u8 = default_source_editor_label;
var source_editor_label_bytes: [max_source_editor_label_bytes]u8 = undefined;
var source_editor_undo: [max_source_editor_undo_entries]SourceEditorSnapshot = undefined;
var source_editor_undo_len: usize = 0;
var source_editor_redo: [max_source_editor_undo_entries]SourceEditorSnapshot = undefined;
var source_editor_redo_len: usize = 0;
var source_file_entries: [max_source_file_entries]app_source.FileEntry = undefined;
var source_file_label_bytes: [max_source_file_label_bytes]u8 = undefined;
var source_file_count: usize = 0;
var source_file_label_bytes_len: usize = 0;
var source_file_cache_workspace_len: usize = 0;
var source_search_bytes: [max_source_search_bytes]u8 = undefined;
var source_search_len: usize = 0;
var source_pointer_drag_select = false;
var context_menu_open = false;
var context_menu_x: f32 = 0.0;
var context_menu_y: f32 = 0.0;
var context_source_label: []const u8 = "";
var context_source_label_bytes: [max_source_editor_label_bytes]u8 = undefined;
var last_compiler_status: u32 = 0;
var last_compiler_diagnostic: [max_compiler_diagnostic_bytes]u8 = undefined;
var last_compiler_diagnostic_len: usize = 0;
var last_compile_phase: CompilePhase = .idle;
var last_compile_progress_permille: u32 = 0;
var last_compile_instructions: u64 = 0;
var last_compile_function_entries: u64 = 0;
var last_compile_memory_loads: u64 = 0;
var source_compile_summary: [max_source_compile_summary_bytes]u8 = undefined;
var source_compile_summary_len: usize = 0;
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
var font_atlas: renderer_font_atlas.Atlas = undefined;
var font_atlas_ready = false;
var font_device_scale: f32 = 1.0;
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
var app_state = AppRuntimeState{};
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

const CompilePhase = enum(u32) {
    idle = 0,
    loading_workspace = 1,
    init_compiler = 2,
    compiling = 3,
    collecting_artifact = 4,
    complete = 5,
    failed = 6,
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

const input_event_prevent_default: u32 = 1 << 0;
const input_event_schedule_frame: u32 = 1 << 1;
const input_event_outbox: u32 = 1 << 3;
const input_event_capture_pointer: u32 = 1 << 4;
const input_event_release_pointer: u32 = 1 << 5;
const input_event_error: u32 = 1 << 8;

const CursorKind = app_cursor.Kind;

const AppView = app_navigation.View;
const InputEventKind = app_input_event.Kind;
const InputEventRecord = app_input_event.Record;
const input_event_flag_ctrl = app_input_event.flag_ctrl;
const input_event_record_kind_offset = app_input_event.kind_offset;

const SourceEditorSnapshot = struct {
    bytes: [max_source_editor_bytes]u8 = undefined,
    len: usize = 0,
    cursor: usize = 0,
    selection_anchor: usize = 0,
    selection_active: bool = false,
};

const AppRuntimeState = struct {
    view: AppView = .source,
    selected_blog_post_id: u32 = 0,
    blog_arc_filter_index: ?usize = null,
    selected_doc_index: ?usize = null,
    selected_component_index: ?usize = null,
    scroll_y: f32 = 0.0,
    queued_action: UiAction = .none,

    fn resetUiAction(state: *AppRuntimeState) void {
        state.queued_action = .none;
    }

    fn resetScroll(state: *AppRuntimeState) void {
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

fn packedBuffers() renderer_pipeline.Buffers {
    return .{
        .rects = packed_rect_floats[0..],
        .rect_len = &packed_rect_float_len,
        .text_vertices = packed_text_vertex_floats[0..],
        .text_vertex_len = &packed_text_vertex_float_len,
        .icon_vertices = packed_icon_vertex_floats[0..],
        .icon_vertex_len = &packed_icon_vertex_float_len,
        .icon_line_vertices = packed_icon_line_vertex_floats[0..],
        .icon_line_vertex_len = &packed_icon_line_vertex_float_len,
        .image_vertices = packed_image_vertex_floats[0..],
        .image_vertex_len = &packed_image_vertex_float_len,
        .overlay_rects = packed_overlay_rect_floats[0..],
        .overlay_rect_len = &packed_overlay_rect_float_len,
        .overlay_text_vertices = packed_overlay_text_vertex_floats[0..],
        .overlay_text_vertex_len = &packed_overlay_text_vertex_float_len,
        .overlay_icon_vertices = packed_overlay_icon_vertex_floats[0..],
        .overlay_icon_vertex_len = &packed_overlay_icon_vertex_float_len,
        .overlay_icon_line_vertices = packed_overlay_icon_line_vertex_floats[0..],
        .overlay_icon_line_vertex_len = &packed_overlay_icon_line_vertex_float_len,
    };
}

fn packedSources() renderer_pipeline.Sources {
    return renderer_pipeline.sources(&font_atlas, .object);
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
    return app_images.cloudMemeRgbaPtr();
}

export fn er_ui_post_image_rgba_len() usize {
    return app_images.cloudMemeRgbaLen();
}

export fn er_ui_post_image_runtime_ptr() usize {
    return app_images.cloudMemeRuntimePtr();
}

export fn er_ui_post_image_runtime_len() usize {
    return app_images.cloudMemeRuntimeLen();
}

export fn er_ui_post_image_width() u32 {
    return app_images.cloud_meme_width;
}

export fn er_ui_post_image_height() u32 {
    return app_images.cloud_meme_height;
}

export fn er_ui_font_atlas_width() u32 {
    return font_atlas_width;
}

export fn er_ui_font_atlas_height() u32 {
    return font_atlas_height;
}

export fn er_ui_font_atlas_ptr() usize {
    ensureFontAtlas() catch return 0;
    return @intFromPtr(font_atlas.alphaSlice().ptr);
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

export fn er_ui_app_public_identity_ptr() usize {
    return @intFromPtr(publicIdentityText().ptr);
}

export fn er_ui_app_public_identity_len() usize {
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

export fn er_ui_render_frame(width: u32, height: u32) u32 {
    return renderFrame(width, height, input_bytes[0..0]);
}

export fn er_ui_render_frame_with_input(width: u32, height: u32, input_len: usize) u32 {
    if (input_len > input_bytes.len) {
        last_error = .bad_input;
        return @intFromEnum(last_error);
    }
    return renderFrame(width, height, input_bytes[0..input_len]);
}

export fn er_ui_render_packed_frame(width: u32, height: u32, input_len: usize) u32 {
    return renderPackedFrame(width, height, input_len, true);
}

export fn er_ui_build_app_frame(width: u32, height: u32, input_len: usize) u32 {
    return renderPackedFrame(width, height, input_len, false);
}

export fn er_ui_last_command_count() usize {
    return last_command_count;
}

export fn er_ui_last_region_count() usize {
    return last_region_count;
}

export fn er_ui_last_present_primitive_count() usize {
    return last_present_primitive_count;
}

export fn er_ui_last_present_transport() u32 {
    return @intFromEnum(last_present_transport);
}

export fn er_ui_region_id(index: usize) u32 {
    if (index >= last_region_count) return 0;
    return interaction_regions[index].id;
}

export fn er_ui_region_kind(index: usize) u32 {
    if (index >= last_region_count) return hover_hit_kind_none;
    return @intFromEnum(interaction_regions[index].kind);
}

export fn er_ui_region_bounds(index: usize, out: [*]f32) void {
    if (index >= last_region_count) return;
    const b = interaction_regions[index].bounds;
    out[0] = b.x;
    out[1] = b.y;
    out[2] = b.w;
    out[3] = b.h;
}

export fn er_ui_region_cursor(index: usize) u32 {
    if (index >= last_region_count) return @intFromEnum(CursorKind.default);
    return @intFromEnum(interaction_regions[index].cursor);
}

export fn er_ui_region_scope_id(index: usize) u32 {
    if (index >= last_region_count) return 0;
    return interaction_regions[index].scope_id;
}

export fn er_ui_region_item_id(index: usize) u32 {
    if (index >= last_region_count) return 0;
    return interaction_regions[index].item_id;
}

export fn er_ui_region_index(index: usize) usize {
    if (index >= last_region_count) return 0;
    return interaction_regions[index].index;
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

export fn er_ui_route_ptr() usize {
    return @intFromPtr(route_bytes[0..route_len].ptr);
}

export fn er_ui_route_len() usize {
    return route_len;
}

export fn er_ui_set_route_hash_len(len: usize) u32 {
    if (len > route_hash_bytes.len) return 0;
    route_hash_len = len;
    return 1;
}

export fn er_ui_route_hash_ptr() usize {
    return @intFromPtr(route_hash_bytes[0..].ptr);
}

export fn er_ui_route_hash_len() usize {
    return route_hash_len;
}

export fn er_ui_source_workspace_ptr() usize {
    return @intFromPtr(source_workspace[0..].ptr);
}

export fn er_ui_source_workspace_len() usize {
    return source_workspace_len;
}

export fn er_ui_source_workspace_capacity() usize {
    return source_workspace.len;
}

export fn er_ui_source_workspace_loaded() u32 {
    ensureSourceWorkspaceLoaded() catch return 0;
    return if (source_workspace_ready) 1 else 0;
}

export fn er_ui_source_file_count() usize {
    ensureSourceWorkspaceLoaded() catch return 0;
    return source_file_count;
}

export fn er_ui_source_file_label_ptr(index: usize) usize {
    ensureSourceWorkspaceLoaded() catch return 0;
    if (index >= source_file_count) return 0;
    return @intFromPtr(source_file_entries[index].label.ptr);
}

export fn er_ui_source_file_label_len(index: usize) usize {
    ensureSourceWorkspaceLoaded() catch return 0;
    if (index >= source_file_count) return 0;
    return source_file_entries[index].label.len;
}

export fn er_ui_source_file_body_ptr(index: usize) usize {
    ensureSourceWorkspaceLoaded() catch return 0;
    if (index >= source_file_count) return 0;
    return @intFromPtr(source_file_entries[index].body.ptr);
}

export fn er_ui_source_file_body_len(index: usize) usize {
    ensureSourceWorkspaceLoaded() catch return 0;
    if (index >= source_file_count) return 0;
    return source_file_entries[index].body.len;
}

export fn er_ui_source_editor_status() u32 {
    ensureSourceEditorLoaded() catch return @intFromEnum(SourceEditorStatus.corrupt_workspace);
    return @intFromEnum(source_editor_status);
}

export fn er_ui_source_editor_ptr() usize {
    ensureSourceEditorLoaded() catch return 0;
    return @intFromPtr(source_editor_bytes[0..source_editor_len].ptr);
}

export fn er_ui_source_editor_len() usize {
    ensureSourceEditorLoaded() catch return 0;
    return source_editor_len;
}

export fn er_ui_source_editor_cursor() usize {
    ensureSourceEditorLoaded() catch return 0;
    return source_editor_cursor;
}

export fn er_ui_source_editor_selection_anchor() usize {
    ensureSourceEditorLoaded() catch return 0;
    return source_editor_selection_anchor;
}

export fn er_ui_source_editor_selection_active() u32 {
    ensureSourceEditorLoaded() catch return 0;
    return if (source_editor_selection_active) 1 else 0;
}

export fn er_ui_source_editor_label_ptr() usize {
    ensureSourceEditorLoaded() catch return 0;
    return @intFromPtr(source_editor_label.ptr);
}

export fn er_ui_source_editor_label_len() usize {
    ensureSourceEditorLoaded() catch return 0;
    return source_editor_label.len;
}

export fn er_ui_source_editor_scroll_line() usize {
    ensureSourceEditorLoaded() catch return 0;
    return source_editor_scroll_line;
}

export fn er_ui_source_search_ptr() usize {
    return @intFromPtr(source_search_bytes[0..].ptr);
}

export fn er_ui_source_search_capacity() usize {
    return source_search_bytes.len;
}

export fn er_ui_set_source_search_len(len: usize) u32 {
    if (len > source_search_bytes.len) return 0;
    source_search_len = len;
    return 1;
}

export fn er_ui_source_search_len() usize {
    return source_search_len;
}

export fn er_ui_source_context_label_ptr() usize {
    return @intFromPtr(context_source_label.ptr);
}

export fn er_ui_source_context_label_len() usize {
    return context_source_label.len;
}

export fn er_ui_compiler_diagnostic_ptr() usize {
    return @intFromPtr(last_compiler_diagnostic[0..last_compiler_diagnostic_len].ptr);
}

export fn er_ui_compiler_diagnostic_len() usize {
    return last_compiler_diagnostic_len;
}

export fn er_ui_compile_phase() u32 {
    return @intFromEnum(last_compile_phase);
}

export fn er_ui_compile_progress_permille() u32 {
    return last_compile_progress_permille;
}

export fn er_ui_compile_instructions() u64 {
    return last_compile_instructions;
}

export fn er_ui_compile_function_entries() u64 {
    return last_compile_function_entries;
}

export fn er_ui_compile_memory_loads() u64 {
    return last_compile_memory_loads;
}

export fn er_ui_source_compile_summary_ptr() usize {
    return @intFromPtr(source_compile_summary[0..source_compile_summary_len].ptr);
}

export fn er_ui_source_compile_summary_len() usize {
    return source_compile_summary_len;
}

export fn er_ui_release_artifact_ptr() usize {
    return @intFromPtr(release_artifact[0..release_artifact_len].ptr);
}

export fn er_ui_release_artifact_len() usize {
    return release_artifact_len;
}

export fn er_ui_release_artifact_capacity() usize {
    return release_artifact.len;
}

export fn er_ui_release_artifact_filename_ptr() usize {
    return @intFromPtr(release_artifact_filename.ptr);
}

export fn er_ui_release_artifact_filename_len() usize {
    return release_artifact_filename.len;
}

export fn er_ui_release_artifact_commit() u32 {
    return compileSourceWorkspace();
}

export fn er_ui_release_artifact_clear() void {
    release_artifact_len = 0;
    last_compile_phase = .idle;
    last_compile_progress_permille = 0;
    last_compiler_status = 0;
    last_compiler_diagnostic_len = 0;
    source_compile_summary_len = 0;
}

export fn er_ui_outbox_count() usize {
    return outbox_message_len;
}

export fn er_ui_outbox_kind(index: usize) u32 {
    if (index >= outbox_message_len) return @intFromEnum(OutboxKind.none);
    return @intFromEnum(outbox_messages[index].kind);
}

export fn er_ui_outbox_id(index: usize) u32 {
    if (index >= outbox_message_len) return 0;
    return outbox_messages[index].id;
}

export fn er_ui_outbox_ack(id: u32) u32 {
    for (outbox_messages[0..outbox_message_len], 0..) |message, index| {
        if (message.id == id) {
            var cursor = index;
            while (cursor + 1 < outbox_message_len) : (cursor += 1) outbox_messages[cursor] = outbox_messages[cursor + 1];
            outbox_message_len -= 1;
            return 1;
        }
    }
    return 0;
}

export fn er_ui_static_html_ptr() usize {
    _ = web_host_js.source;
    return @intFromPtr(boot_dom_html.ptr);
}

export fn er_ui_static_html_len() usize {
    return boot_dom_html.len;
}

export fn er_ui_app_source_url_ptr() usize {
    return @intFromPtr(app_source_url.ptr);
}

export fn er_ui_app_source_url_len() usize {
    return app_source_url.len;
}

export fn er_ui_icon_source_ptr(icon_id: u32) usize {
    const source = icon_svg.sourceForIconId(icon_id);
    return @intFromPtr(source.ptr);
}

export fn er_ui_icon_source_len(icon_id: u32) usize {
    return icon_svg.sourceForIconId(icon_id).len;
}

export fn er_ui_icon_vector_ptr(icon_id: u32) usize {
    const source = icon_component.vectorPathForId(icon_id);
    return @intFromPtr(source.ptr);
}

export fn er_ui_icon_vector_len(icon_id: u32) usize {
    return icon_component.vectorPathForId(icon_id).len;
}

export fn er_ui_embedded_source_ptr() usize {
    return @intFromPtr(source_object.ptr);
}

export fn er_ui_embedded_source_len() usize {
    return source_object.len;
}

export fn er_ui_compiler_wasm_ptr() usize {
    return @intFromPtr(compiler_wasm.ptr);
}

export fn er_ui_compiler_wasm_len() usize {
    return compiler_wasm.len;
}

export fn er_ui_wasm_run_ptr() usize {
    return @intFromPtr(compiler_runtime_memory[0..].ptr);
}

export fn er_ui_wasm_run_capacity() usize {
    return compiler_runtime_memory.len;
}

export fn er_ui_wasm_run(memory_len: usize) u32 {
    if (memory_len > compiler_runtime_memory.len) return 0;
    var instance = wasm_interpreter.Instance.init(compiler_runtime_memory[0..memory_len]) catch return 0;
    instance.run() catch return 0;
    return 1;
}

export fn er_ui_wasm_run_last_instructions() u64 {
    return wasm_interpreter.lastInstructions();
}

export fn er_ui_app_ephemeral_identity_ready() u32 {
    ensureEphemeralIdentity() catch return 0;
    return if (ephemeral_identity_ready) 1 else 0;
}

export fn er_ui_app_ephemeral_public_key_ptr() usize {
    ensureEphemeralIdentity() catch return 0;
    return @intFromPtr(ephemeral_public_key[0..].ptr);
}

export fn er_ui_app_ephemeral_public_key_len() usize {
    ensureEphemeralIdentity() catch return 0;
    return ephemeral_public_key.len;
}

export fn er_ui_app_entropy_event_count() u64 {
    return entropy_event_count;
}

export fn er_ui_app_add_entropy(ptr: usize, len: usize) u32 {
    if (len == 0 or len > entropy_pool.len) return 0;
    const bytes_in = @as([*]const u8, @ptrFromInt(ptr))[0..len];
    mixEntropy(bytes_in);
    return 1;
}

fn renderFrame(width: u32, height: u32, input: []const u8) u32 {
    if (width == 0 or height == 0 or width > max_width or height > max_height) {
        last_error = .bad_size;
        return @intFromEnum(last_error);
    }
    frame_width = width;
    frame_height = height;
    resetTransientUiState();

    var scene = ui.Scene.init(&commands);
    buildScene(&scene, input) catch {
        last_error = .bad_ui;
        return @intFromEnum(last_error);
    };
    last_command_count = scene.len();

    var hit_builder = interaction.Builder.init(&interaction_regions, &clips, @floatFromInt(width), @floatFromInt(height));
    const metrics = hit_builder.build(scene.written()) catch {
        last_error = .bad_ui;
        return @intFromEnum(last_error);
    };
    last_region_count = metrics.regions;

    const framebuffer = renderer_pipeline.softwareFramebuffer(width, height, &pixels) catch {
        last_error = .bad_size;
        return @intFromEnum(last_error);
    };
    ensureFontAtlas() catch {
        last_error = .font_atlas;
        return @intFromEnum(last_error);
    };
    const texture = app_images.cloudMeme() catch null;
    const render_receipt = renderer_pipeline.renderSoftwareFrame(
        framebuffer,
        packedBuffers(),
        renderer_pipeline.softwareResources(&font_atlas, texture),
        .bg,
    ) catch {
        last_error = .render_failed;
        return @intFromEnum(last_error);
    };
    last_present_transport = render_receipt.transport;
    last_present_primitive_count = render_receipt.primitive_count;
    last_error = .ok;
    return @intFromEnum(last_error);
}

fn renderPackedFrame(width: u32, height: u32, input_len: usize, present_frame: bool) u32 {
    if (width == 0 or height == 0 or width > max_width or height > max_height) {
        last_error = .bad_size;
        return @intFromEnum(last_error);
    }
    if (input_len > input_bytes.len) {
        last_error = .bad_input;
        return @intFromEnum(last_error);
    }
    frame_width = width;
    frame_height = height;
    resetTransientUiState();
    clearPackedBuffers();
    const input = input_bytes[0..input_len];

    ensureFontAtlas() catch {
        last_error = .font_atlas;
        return @intFromEnum(last_error);
    };
    var scene = ui.Scene.init(&commands);
    buildScene(&scene, input) catch {
        last_error = .bad_ui;
        return @intFromEnum(last_error);
    };
    last_command_count = scene.len();

    var hit_builder = interaction.Builder.init(&interaction_regions, &clips, @floatFromInt(width), @floatFromInt(height));
    const metrics = hit_builder.build(scene.written()) catch {
        last_error = .bad_ui;
        return @intFromEnum(last_error);
    };
    last_region_count = metrics.regions;

    renderer_pipeline.packSceneWithSources(packedBuffers(), packedSources(), scene.written()) catch {
        last_error = .packed_budget;
        return @intFromEnum(last_error);
    };
    const resource_set = renderer_pipeline.presentationResources(font_atlas_ready, app_images.cloudMeme() != null);
    const render_receipt = if (present_frame)
        renderer_pipeline.presentPackedFrame(width, height, packedBuffers(), resource_set) catch {
            last_error = .render_failed;
            return @intFromEnum(last_error);
        }
    else
        renderer_pipeline.Receipt{
            .transport = .packed_buffers,
            .destination = .packed_frame,
            .width = width,
            .height = height,
            .primitive_count = renderer_pipeline.presentPackedFrame(width, height, packedBuffers(), resource_set) catch 0,
        };
    last_present_transport = render_receipt.transport;
    last_present_primitive_count = render_receipt.primitive_count;
    last_error = .ok;
    return @intFromEnum(last_error);
}

fn clearPackedBuffers() void {
    packed_rect_float_len = 0;
    packed_text_vertex_float_len = 0;
    packed_icon_vertex_float_len = 0;
    packed_icon_line_vertex_float_len = 0;
    packed_image_vertex_float_len = 0;
    packed_overlay_rect_float_len = 0;
    packed_overlay_text_vertex_float_len = 0;
    packed_overlay_icon_vertex_float_len = 0;
    packed_overlay_icon_line_vertex_float_len = 0;
}

fn buildScene(scene: *ui.Scene, input: []const u8) !void {
    ensureSourceWorkspaceLoaded() catch {};
    ensureSourceEditorLoaded() catch {};
    updateRouteFromInput(input);
    handleInput(input);
    const style = styleForEnvironment();
    try app_frame.build(.{
        .scene = scene,
        .view = app_state.view,
        .style = style,
        .route = route_bytes[0..route_len],
        .scroll_y = app_state.scroll_y,
        .hover_x = pointer_hover_x,
        .hover_y = pointer_hover_y,
        .selected_blog_post_id = app_state.selected_blog_post_id,
        .selected_doc_index = app_state.selected_doc_index,
        .selected_component_index = app_state.selected_component_index,
        .source = .{
    ...
