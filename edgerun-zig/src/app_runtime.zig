const std = @import("std");
const bytes = @import("bytes.zig");
const web_host_js = @import("web_host_js.zig");
const clock = @import("clock.zig");
const source_object = @import("embedded_source_object").bytes;
const compiler_wasm = @import("embedded_wasm_compiler").bytes;
const icon = @import("icon.zig");
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
const app_landing = @import("app_landing.zig");
const app_navigation = @import("app_navigation.zig");
const app_source = @import("app_source.zig");
const component_union = @import("ui/components/Component.zig");
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
const default_source_editor_label = "src/app_runtime.zig";
const max_source_editor_label_bytes: usize = 128;
const max_source_editor_bytes: usize = 512 * 1024;
const source_editor_tab = "    ";
const source_editor_page_lines: usize = 16;
const source_editor_visible_lines: usize = 32;
const source_editor_scroll_margin_lines: usize = 3;
const max_source_editor_undo_entries: usize = 8;
const max_source_file_entries: usize = 32;
const max_source_file_label_bytes: usize = 4096;
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
    context_menu = 10,
    key_up = 11,
    input = 12,
    change = 13,
    click = 14,
    dbl_click = 15,
    visibility_change = 16,
    focus = 17,
    blur = 18,
    before_input = 19,
    composition_start = 20,
    composition_update = 21,
    composition_end = 22,
    touch_start = 23,
    touch_move = 24,
    touch_end = 25,
    touch_cancel = 26,
    drag_start = 27,
    drag_end = 28,
    drop = 29,
};

const input_event_prevent_default: u32 = 1 << 0;
const input_event_schedule_frame: u32 = 1 << 1;
const input_event_outbox: u32 = 1 << 3;
const input_event_capture_pointer: u32 = 1 << 4;
const input_event_release_pointer: u32 = 1 << 5;
const input_event_error: u32 = 1 << 8;
const input_event_record_header_bytes: usize = 36;
const input_event_record_kind_offset: usize = 0;
const input_event_record_x_offset: usize = 4;
const input_event_record_y_offset: usize = 8;
const input_event_record_delta_y_offset: usize = 12;
const input_event_record_flags_offset: usize = 16;
const input_event_record_key_len_offset: usize = 20;
const input_event_record_code_len_offset: usize = 24;
const input_event_record_input_type_len_offset: usize = 28;
const input_event_record_data_len_offset: usize = 32;
const input_event_flag_ctrl: u32 = 1 << 0;
const input_event_flag_meta: u32 = 1 << 1;
const input_event_flag_alt: u32 = 1 << 2;
const input_event_flag_shift: u32 = 1 << 3;
const input_event_flag_repeat: u32 = 1 << 4;

const CursorKind = app_cursor.Kind;

const AppView = app_navigation.View;

const InputEventRecord = struct {
    kind: InputEventKind,
    x: f32,
    y: f32,
    delta_y: f32,
    ctrl: u32,
    meta: u32,
    alt: u32,
    shift: u32,
    repeat: u32,
    key: []const u8,
    code: []const u8,
    input_type: []const u8,
    data: []const u8,
};

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

export fn er_ui_app_pointer_up(x: f32, y: f32) u32 {
    const action_kind = er_ui_pointer_up(x, y);
    if (action_kind == @intFromEnum(ui_runtime.ActionKind.reordered)) {
        return @intFromEnum(UiAction.none);
    }
    return er_ui_app_activate_hit(currentHoverHitId());
}

export fn er_ui_app_docs_button_id() u32 {
    return app_chrome.docs_button_id;
}

export fn er_ui_app_source_button_id() u32 {
    return app_chrome.source_button_id;
}

export fn er_ui_app_blog_button_id() u32 {
    return app_chrome.blog_button_id;
}

export fn er_ui_blog_back_button_id() u32 {
    return app_blog.back_button_id;
}

export fn er_ui_blog_first_post_button_id() u32 {
    return app_blog.first_post_button_id;
}

export fn er_ui_blog_post_count() u32 {
    return app_blog.posts.len;
}

export fn er_ui_app_action_kind() u32 {
    return @intFromEnum(app_state.queued_action);
}

export fn er_ui_app_action_url_ptr() usize {
    return @intFromPtr(app_source_url.ptr);
}

export fn er_ui_app_action_url_len() usize {
    return app_source_url.len;
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
        .open_url => @intFromPtr(app_source_url.ptr),
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
        .open_url => app_source_url.len,
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
    app_state.resetUiAction();
    last_error = .ok;
    return @intFromEnum(ErrorCode.ok);
}

export fn er_ui_bootstrap_js_ptr() usize {
    return @intFromPtr(web_host_js.source.ptr);
}

export fn er_ui_bootstrap_js_len() usize {
    return web_host_js.source.len;
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
    if (source_len == 0) return finishError(.bad_input);
    const source_body = findWorkspaceFileBody(source_workspace[0..source_len], source_editor_label) catch return finishError(.bad_input);
    if (source_body.len == 0) return finishError(.bad_input);
    source_workspace_len = source_len;
    source_workspace_ready = true;
    source_file_cache_workspace_len = 0;
    source_editor_loaded = false;
    source_editor_dirty = false;
    source_editor_status = .not_loaded;
    source_editor_preferred_column = 0;
    source_editor_selection_anchor = 0;
    source_editor_selection_active = false;
    source_editor_scroll_line = 0;
    clearSourceEditorHistory();
    last_error = .ok;
    return @intFromEnum(ErrorCode.ok);
}

export fn er_ui_source_editor_select_label(label_len: usize) u32 {
    if (label_len == 0 or label_len > input_bytes.len or label_len > source_editor_label_bytes.len) return finishError(.bad_input);
    return @intFromEnum(selectSourceEditorLabel(input_bytes[0..label_len]));
}

fn selectSourceEditorLabel(label: []const u8) ErrorCode {
    if (label.len == 0 or label.len > source_editor_label_bytes.len) return finishErrorCode(.bad_input);
    const source_body = findWorkspaceFileBody(source_workspace[0..er_ui_source_workspace_len()], label) catch return finishErrorCode(.bad_input);
    if (source_body.len == 0) return finishErrorCode(.bad_input);
    @memcpy(source_editor_label_bytes[0..label.len], label);
    source_editor_label = source_editor_label_bytes[0..label.len];
    source_editor_loaded = false;
    source_editor_dirty = false;
    source_editor_status = .not_loaded;
    source_editor_preferred_column = 0;
    source_editor_selection_anchor = 0;
    source_editor_selection_active = false;
    source_editor_scroll_line = 0;
    clearSourceEditorHistory();
    last_error = .ok;
    return .ok;
}

export fn er_ui_source_workspace_reset() u32 {
    source_workspace_ready = false;
    ensureSourceWorkspace();
    source_file_cache_workspace_len = 0;
    source_editor_loaded = false;
    source_editor_dirty = false;
    source_editor_status = .not_loaded;
    source_editor_selection_anchor = 0;
    source_editor_selection_active = false;
    source_editor_scroll_line = 0;
    clearSourceEditorHistory();
    last_compile_phase = .idle;
    last_compile_progress_permille = 0;
    last_compile_instructions = 0;
    last_compile_function_entries = 0;
    last_compile_memory_loads = 0;
    release_artifact_len = 0;
    setSourceCompileSummary() catch {};
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

export fn er_ui_last_compile_phase() u32 {
    return @intFromEnum(last_compile_phase);
}

export fn er_ui_last_compile_progress_permille() u32 {
    return last_compile_progress_permille;
}

export fn er_ui_last_compile_instructions() u64 {
    return last_compile_instructions;
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

export fn er_ui_app_route_hash_ptr() usize {
    refreshRouteHash();
    return @intFromPtr(route_hash_bytes[0..].ptr);
}

export fn er_ui_app_route_hash_len() usize {
    refreshRouteHash();
    return route_hash_len;
}

export fn er_ui_app_route_path_ptr() usize {
    refreshRoutePath();
    return @intFromPtr(route_bytes[0..].ptr);
}

export fn er_ui_app_route_path_len() usize {
    refreshRoutePath();
    return route_len;
}

export fn er_ui_app_set_route_path(path_len: usize) u32 {
    if (path_len > input_bytes.len) return finishError(.bad_input);
    applyRoutePath(input_bytes[0..path_len]);
    last_error = .ok;
    return @intFromEnum(ErrorCode.ok);
}

export fn er_ui_app_set_route_hash(hash_len: usize) u32 {
    if (hash_len > input_bytes.len) return finishError(.bad_input);
    const route_path = routePathFromHash(input_bytes[0..hash_len]) catch return finishError(.bad_input);
    applyRoutePath(route_path);
    last_error = .ok;
    return @intFromEnum(ErrorCode.ok);
}

export fn er_ui_app_activate_hit(hit_id: u32) u32 {
    app_state.resetUiAction();
    clearOutboxMessages();
    if (hit_id != app_navigation.context_source_button_id) context_menu_open = false;
    if (app_navigation.fromHit(hit_id, currentRoute())) |route| {
        applyRoute(route);
        return @intFromEnum(app_state.queued_action);
    }
    if (app_navigation.actionFromHit(hit_id)) |action| switch (action) {
        .reveal_identity => {
            if (!ephemeral_identity_ready) {
                generateEphemeralIdentity() catch return finishError(.identity_failed);
            }
        },
        .compile_source => {
            _ = compileWorkspaceInsideWasm();
        },
        .download_source_release => {
            if (release_artifact_len == 0 and compileWorkspaceInsideWasm() != .ok) return @intFromEnum(app_state.queued_action);
            queueOutboxMessage(.download_wasm) catch return finishError(.bad_input);
        },
        .launch_source_release => {
            if (release_artifact_len == 0 and compileWorkspaceInsideWasm() != .ok) return @intFromEnum(app_state.queued_action);
            queueOutboxMessage(.launch_wasm) catch return finishError(.bad_input);
        },
        .reset_source => {
            _ = er_ui_source_workspace_reset();
        },
        .open_context_source => {
            if (context_source_label.len == 0) return @intFromEnum(app_state.queued_action);
            if (selectSourceEditorLabel(context_source_label) == .ok) {
                applyRoute(.{ .view = .source });
            }
            context_menu_open = false;
        },
    };
    return @intFromEnum(app_state.queued_action);
}

export fn er_ui_app_context_menu(x: f32, y: f32) u32 {
    pointer_hover_x = x;
    pointer_hover_y = y;
    runtime_state.refreshHover(lastRegions(), x, y);
    const hit_id = currentHoverHitId();
    if (sourceLabelForHit(currentRoute(), hit_id, &context_source_label_bytes)) |label| {
        context_menu_open = true;
        context_menu_x = x;
        context_menu_y = y;
        context_source_label = label;
        last_error = .ok;
        return @intFromEnum(ErrorCode.ok);
    }
    context_menu_open = false;
    context_source_label = "";
    return finishError(.bad_input);
}

export fn er_ui_app_key_event(key_len: usize, ctrl: u32, meta: u32, alt: u32) u32 {
    if (key_len > input_bytes.len) return finishError(.bad_input);
    return appKeyEvent(input_bytes[0..key_len], ctrl, meta, alt, 0);
}

fn appKeyEvent(key: []const u8, ctrl: u32, meta: u32, alt: u32, shift: u32) u32 {
    if (sourceEditorFocused() and handleSourceEditorKey(key, ctrl, meta, alt, shift)) {
        last_error = .ok;
        return 1;
    }
    if (ctrl != 0 or meta != 0 or alt != 0) {
        last_error = .ok;
        return 0;
    }
    if (keyFromText(key, shift)) |runtime_key| {
        const focused_before = runtime_state.focusHitId();
        const action = runtime_state.keyDown(lastRegions(), runtime_key);
        recordAction(action);
        if (action.kind == .activated) {
            _ = er_ui_app_activate_hit(runtime_state.focusHitId());
            last_error = .ok;
            return 1;
        }
        last_error = .ok;
        if (action.kind == .focused or focused_before != runtime_state.focusHitId()) return 1;
        return 0;
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
        @intFromEnum(InputEventKind.context_menu) => .context_menu,
        else => {
            _ = finishError(.bad_input);
            return input_event_error;
        },
    };

    switch (kind) {
        .resize => return input_event_schedule_frame,
        .wheel => {
            pointer_hover_x = x;
            pointer_hover_y = y;
            _ = er_ui_pointer_move(x, y);
            if (scrollSourceEditorByWheel(delta_y)) return input_event_prevent_default | input_event_schedule_frame;
            const code = er_ui_app_scroll_by(delta_y, width, height);
            if (code != @intFromEnum(ErrorCode.ok)) return input_event_error;
            return input_event_prevent_default | input_event_schedule_frame;
        },
        .pointer_move => {
            pointer_hover_x = x;
            pointer_hover_y = y;
            _ = er_ui_pointer_move(x, y);
            _ = handleSourcePointerMove(x, y, width, height);
            return input_event_schedule_frame;
        },
        .pointer_leave => {
            pointer_hover_x = -1.0;
            pointer_hover_y = -1.0;
            source_pointer_drag_select = false;
            runtime_state.clearHover();
            return input_event_schedule_frame;
        },
        .pointer_down => {
            pointer_hover_x = x;
            pointer_hover_y = y;
            context_menu_open = false;
            _ = er_ui_pointer_down(x, y);
            _ = handleSourcePointerDown(x, y, width, height);
            return input_event_capture_pointer | input_event_schedule_frame;
        },
        .pointer_up => {
            pointer_hover_x = x;
            pointer_hover_y = y;
            source_pointer_drag_select = false;
            _ = er_ui_app_pointer_up(x, y);
            queueOutboxMessage(.push_route_hash) catch return input_event_error;
            const result = input_event_release_pointer | input_event_outbox | input_event_schedule_frame;
            return result;
        },
        .popstate, .hashchange => {
            const code = er_ui_app_set_route_hash(text_len);
            if (code != @intFromEnum(ErrorCode.ok)) return input_event_error;
            return input_event_schedule_frame;
        },
        .key_down => {
            if (text_len > input_bytes.len) return input_event_error;
            const handled = appKeyEvent(input_bytes[0..text_len], ctrl, meta, alt, 0);
            if (handled == 0) return 0;
            if (handled != 1) return input_event_error;
            return input_event_prevent_default | input_event_schedule_frame;
        },
        .context_menu => {
            const code = er_ui_app_context_menu(x, y);
            if (code != @intFromEnum(ErrorCode.ok)) return input_event_prevent_default | input_event_schedule_frame;
            return input_event_prevent_default | input_event_schedule_frame;
        },
        .key_up,
        .input,
        .change,
        .click,
        .dbl_click,
        .visibility_change,
        .focus,
        .blur,
        .before_input,
        .composition_start,
        .composition_update,
        .composition_end,
        .touch_start,
        .touch_move,
        .touch_end,
        .touch_cancel,
        .drag_start,
        .drag_end,
        .drop,
        => return input_event_schedule_frame,
    }
}

fn sourceEditorFocused() bool {
    return app_state.view == .source and runtime_state.focusKind() == .textarea and runtime_state.focusHitId() == app_source.editor_textarea_id;
}

fn handleSourcePointerDown(x: f32, y: f32, width: f32, height: f32) bool {
    if (app_state.view != .source) return false;
    const hit_id = currentHoverHitId();
    if (hit_id == app_source.editor_textarea_id) {
        setSourceEditorCursor(sourceCursorFromPoint(x, y, width, height));
        source_pointer_drag_select = true;
        return true;
    }
    if (sourceFileLabelFromHit(hit_id)) |label| {
        if (selectSourceEditorLabel(label) != .ok) return false;
        ensureSourceEditor();
        return true;
    }
    return false;
}

fn handleSourcePointerMove(x: f32, y: f32, width: f32, height: f32) bool {
    if (!source_pointer_drag_select or app_state.view != .source) return false;
    const cursor = sourceCursorFromPoint(x, y, width, height);
    moveSourceEditorCursor(cursor, true);
    return true;
}

fn handleSourceDoubleClick(x: f32, y: f32, width: f32, height: f32) bool {
    if (app_state.view != .source) return false;
    runtime_state.refreshHover(lastRegions(), x, y);
    if (currentHoverHitId() != app_source.editor_textarea_id) return false;
    const cursor = sourceCursorFromPoint(x, y, width, height);
    selectSourceEditorWordAt(cursor);
    return true;
}

fn sourceCursorFromPoint(x: f32, y: f32, width: f32, height: f32) usize {
    const state = currentSourceState(x, y);
    const editor_bounds = lastRegionBounds(app_source.editor_textarea_id) catch return app_source.cursorFromPoint(ui.Rect.init(0.0, 0.0, width, height), state, x, y);
    return app_source.cursorFromTextAreaBounds(editor_bounds, state, x, y);
}

fn scrollSourceEditorByWheel(delta_y: f32) bool {
    if (app_state.view != .source or currentHoverHitId() != app_source.editor_textarea_id) return false;
    const magnitude = @abs(delta_y);
    const lines: usize = @max(1, @as(usize, @intFromFloat(magnitude / source_editor_wheel_pixels_per_line)));
    if (delta_y > 0) {
        source_editor_scroll_line = @min(sourceEditorLineCount() -| 1, source_editor_scroll_line + lines);
    } else if (delta_y < 0) {
        source_editor_scroll_line -|= lines;
    }
    return true;
}

export fn er_ui_event_bytes(input_len: usize, width: f32, height: f32, frame_ms: f32) u32 {
    _ = frame_ms;
    if (input_len > input_bytes.len) return finishError(.bad_input);
    const envelope = input_bytes[0..input_len];
    const record = parseInputEventRecordBytes(envelope) catch return finishError(.bad_input);
    return handleInputEventRecord(record, width, height);
}

fn parseInputEventRecordBytes(envelope: []const u8) !InputEventRecord {
    if (envelope.len < input_event_record_header_bytes) return error.BadInput;
    const kind = inputEventKindFromInt(loadEventU32(envelope, input_event_record_kind_offset) orelse return error.BadInput) orelse return error.UnknownInputEvent;
    const x = loadEventF32(envelope, input_event_record_x_offset) orelse return error.BadInput;
    const y = loadEventF32(envelope, input_event_record_y_offset) orelse return error.BadInput;
    const delta_y = loadEventF32(envelope, input_event_record_delta_y_offset) orelse return error.BadInput;
    const flags = loadEventU32(envelope, input_event_record_flags_offset) orelse return error.BadInput;
    const key_len: usize = @intCast(loadEventU32(envelope, input_event_record_key_len_offset) orelse return error.BadInput);
    const code_len: usize = @intCast(loadEventU32(envelope, input_event_record_code_len_offset) orelse return error.BadInput);
    const input_type_len: usize = @intCast(loadEventU32(envelope, input_event_record_input_type_len_offset) orelse return error.BadInput);
    const data_len: usize = @intCast(loadEventU32(envelope, input_event_record_data_len_offset) orelse return error.BadInput);
    var offset: usize = input_event_record_header_bytes;
    const key = nextEventBytes(envelope, &offset, key_len) orelse return error.BadInput;
    const code = nextEventBytes(envelope, &offset, code_len) orelse return error.BadInput;
    const input_type = nextEventBytes(envelope, &offset, input_type_len) orelse return error.BadInput;
    const data = nextEventBytes(envelope, &offset, data_len) orelse return error.BadInput;
    if (offset != envelope.len) return error.BadInput;
    return .{
        .kind = kind,
        .x = x,
        .y = y,
        .delta_y = delta_y,
        .ctrl = if ((flags & input_event_flag_ctrl) != 0) 1 else 0,
        .meta = if ((flags & input_event_flag_meta) != 0) 1 else 0,
        .alt = if ((flags & input_event_flag_alt) != 0) 1 else 0,
        .shift = if ((flags & input_event_flag_shift) != 0) 1 else 0,
        .repeat = if ((flags & input_event_flag_repeat) != 0) 1 else 0,
        .key = key,
        .code = code,
        .input_type = input_type,
        .data = data,
    };
}

fn loadEventU32(envelope: []const u8, offset: usize) ?u32 {
    if (offset > envelope.len or 4 > envelope.len - offset) return null;
    return bytes.load32(envelope[offset..][0..4]);
}

fn loadEventF32(envelope: []const u8, offset: usize) ?f32 {
    return @as(f32, @bitCast(loadEventU32(envelope, offset) orelse return null));
}

fn nextEventBytes(envelope: []const u8, offset: *usize, len: usize) ?[]const u8 {
    if (offset.* > envelope.len or len > envelope.len - offset.*) return null;
    const out = envelope[offset.*..][0..len];
    offset.* += len;
    return out;
}

fn inputEventKindFromInt(value: u32) ?InputEventKind {
    return switch (value) {
        @intFromEnum(InputEventKind.resize) => .resize,
        @intFromEnum(InputEventKind.wheel) => .wheel,
        @intFromEnum(InputEventKind.pointer_move) => .pointer_move,
        @intFromEnum(InputEventKind.pointer_leave) => .pointer_leave,
        @intFromEnum(InputEventKind.pointer_down) => .pointer_down,
        @intFromEnum(InputEventKind.pointer_up) => .pointer_up,
        @intFromEnum(InputEventKind.popstate) => .popstate,
        @intFromEnum(InputEventKind.hashchange) => .hashchange,
        @intFromEnum(InputEventKind.key_down) => .key_down,
        @intFromEnum(InputEventKind.context_menu) => .context_menu,
        @intFromEnum(InputEventKind.key_up) => .key_up,
        @intFromEnum(InputEventKind.input) => .input,
        @intFromEnum(InputEventKind.change) => .change,
        @intFromEnum(InputEventKind.click) => .click,
        @intFromEnum(InputEventKind.dbl_click) => .dbl_click,
        @intFromEnum(InputEventKind.visibility_change) => .visibility_change,
        @intFromEnum(InputEventKind.focus) => .focus,
        @intFromEnum(InputEventKind.blur) => .blur,
        @intFromEnum(InputEventKind.before_input) => .before_input,
        @intFromEnum(InputEventKind.composition_start) => .composition_start,
        @intFromEnum(InputEventKind.composition_update) => .composition_update,
        @intFromEnum(InputEventKind.composition_end) => .composition_end,
        @intFromEnum(InputEventKind.touch_start) => .touch_start,
        @intFromEnum(InputEventKind.touch_move) => .touch_move,
        @intFromEnum(InputEventKind.touch_end) => .touch_end,
        @intFromEnum(InputEventKind.touch_cancel) => .touch_cancel,
        @intFromEnum(InputEventKind.drag_start) => .drag_start,
        @intFromEnum(InputEventKind.drag_end) => .drag_end,
        @intFromEnum(InputEventKind.drop) => .drop,
        else => null,
    };
}

fn handleInputEventRecord(record: InputEventRecord, width: f32, height: f32) u32 {
    switch (record.kind) {
        .resize => return input_event_schedule_frame,
        .wheel => {
            pointer_hover_x = record.x;
            pointer_hover_y = record.y;
            _ = er_ui_pointer_move(record.x, record.y);
            if (scrollSourceEditorByWheel(record.delta_y)) return input_event_prevent_default | input_event_schedule_frame;
            const code = er_ui_app_scroll_by(record.delta_y, width, height);
            if (code != @intFromEnum(ErrorCode.ok)) return input_event_error;
            return input_event_prevent_default | input_event_schedule_frame;
        },
        .pointer_move => {
            pointer_hover_x = record.x;
            pointer_hover_y = record.y;
            _ = er_ui_pointer_move(record.x, record.y);
            _ = handleSourcePointerMove(record.x, record.y, width, height);
            return input_event_schedule_frame;
        },
        .pointer_leave => {
            pointer_hover_x = -1.0;
            pointer_hover_y = -1.0;
            source_pointer_drag_select = false;
            runtime_state.clearHover();
            return input_event_schedule_frame;
        },
        .pointer_down => {
            pointer_hover_x = record.x;
            pointer_hover_y = record.y;
            context_menu_open = false;
            _ = er_ui_pointer_down(record.x, record.y);
            _ = handleSourcePointerDown(record.x, record.y, width, height);
            return input_event_capture_pointer | input_event_schedule_frame;
        },
        .pointer_up => {
            pointer_hover_x = record.x;
            pointer_hover_y = record.y;
            source_pointer_drag_select = false;
            _ = er_ui_app_pointer_up(record.x, record.y);
            queueOutboxMessage(.push_route_hash) catch return input_event_error;
            return input_event_release_pointer | input_event_outbox | input_event_schedule_frame;
        },
        .popstate, .hashchange => {
            const code = applyRouteHashBytes(record.data);
            if (code != @intFromEnum(ErrorCode.ok)) return input_event_error;
            return input_event_schedule_frame;
        },
        .key_down => {
            const handled = appKeyEvent(record.key, record.ctrl, record.meta, record.alt, record.shift);
            if (handled == 0) return 0;
            if (handled != 1) return input_event_error;
            return input_event_prevent_default | input_event_schedule_frame;
        },
        .dbl_click => {
            if (handleSourceDoubleClick(record.x, record.y, width, height)) return input_event_prevent_default | input_event_schedule_frame;
            return input_event_schedule_frame;
        },
        .before_input => {
            if (!sourceEditorFocused()) return 0;
            if (record.data.len == 0) return 0;
            if (!handleSourceEditorTextInput(record.input_type, record.data)) return 0;
            return input_event_prevent_default | input_event_schedule_frame;
        },
        .context_menu => {
            const code = er_ui_app_context_menu(record.x, record.y);
            if (code != @intFromEnum(ErrorCode.ok)) return input_event_prevent_default | input_event_schedule_frame;
            return input_event_prevent_default | input_event_schedule_frame;
        },
        .key_up,
        .input,
        .change,
        .click,
        .visibility_change,
        .focus,
        .blur,
        .composition_start,
        .composition_update,
        .composition_end,
        .touch_start,
        .touch_move,
        .touch_end,
        .touch_cancel,
        .drag_start,
        .drag_end,
        .drop,
        => return input_event_schedule_frame,
    }
}

export fn er_ui_boot() u32 {
    clearOutboxMessages();
    queueOutboxMessage(.set_title) catch return finishError(.bad_input);
    queueOutboxMessage(.set_element_html) catch return finishError(.bad_input);
    last_error = .ok;
    return input_event_outbox | input_event_schedule_frame;
}

fn keyFromText(value: []const u8, shift: u32) ?ui_runtime.Key {
    if (shift != 0 and std.mem.eql(u8, value, "Tab")) return .shift_tab;
    if (std.mem.eql(u8, value, "Tab")) return .tab;
    if (std.mem.eql(u8, value, "Enter")) return .enter;
    if (std.mem.eql(u8, value, " ") or std.mem.eql(u8, value, "Spacebar")) return .space;
    if (std.mem.eql(u8, value, "ArrowUp")) return .arrow_up;
    if (std.mem.eql(u8, value, "ArrowDown")) return .arrow_down;
    if (std.mem.eql(u8, value, "ArrowLeft")) return .arrow_left;
    if (std.mem.eql(u8, value, "ArrowRight")) return .arrow_right;
    if (std.mem.eql(u8, value, "Escape")) return .escape;
    return null;
}

fn applyRouteHashBytes(hash: []const u8) u32 {
    if (hash.len > input_bytes.len) return finishError(.bad_input);
    std.mem.copyForwards(u8, input_bytes[0..hash.len], hash);
    return er_ui_app_set_route_hash(hash.len);
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
    source_editor_preferred_column = 0;
    source_editor_selection_anchor = 0;
    source_editor_selection_active = false;
    source_editor_scroll_line = 0;
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
    source_editor_preferred_column = 0;
    source_editor_selection_anchor = 0;
    source_editor_selection_active = false;
    source_editor_scroll_line = 0;
    clearSourceEditorHistory();
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

fn currentSourceFiles() []const app_source.FileEntry {
    ensureSourceWorkspace();
    if (source_file_cache_workspace_len == source_workspace_len and source_file_count != 0) return source_file_entries[0..source_file_count];
    source_file_count = 0;
    source_file_label_bytes_len = 0;
    source_file_cache_workspace_len = source_workspace_len;
    const workspace_view = object.View.decode(source_workspace[0..source_workspace_len]) catch return source_file_entries[0..0];
    if (!std.mem.startsWith(u8, workspace_view.body, "ERVFSWS1")) return source_file_entries[0..0];
    if (workspace_view.body.len < workspace_manifest_header_bytes) return source_file_entries[0..0];
    const file_count = bytes.load32(workspace_view.body[12..16]) orelse return source_file_entries[0..0];
    var index: usize = workspace_manifest_header_bytes;
    var remaining = file_count;
    while (remaining > 0 and source_file_count < source_file_entries.len) : (remaining -= 1) {
        if (index > workspace_view.body.len or vfs.object_label_ref_bytes > workspace_view.body.len - index) break;
        const label_ref = vfs.decodeObjectLabelRef(workspace_view.body[index..][0..vfs.object_label_ref_bytes]) catch break;
        index += vfs.object_label_ref_bytes;
        const file_len: usize = @intCast(label_ref.object_len);
        if (index > workspace_view.body.len or file_len > workspace_view.body.len - index) break;
        index += file_len;
        const label = label_ref.labelSlice();
        if (label.len > source_file_label_bytes.len - source_file_label_bytes_len) break;
        const start = source_file_label_bytes_len;
        @memcpy(source_file_label_bytes[start..][0..label.len], label);
        source_file_label_bytes_len += label.len;
        source_file_entries[source_file_count] = .{ .path = source_file_label_bytes[start..source_file_label_bytes_len] };
        source_file_count += 1;
    }
    return source_file_entries[0..source_file_count];
}

fn sourceFileLabelFromHit(hit_id: u32) ?[]const u8 {
    const index = app_source.sourceIndexFromHit(hit_id) orelse return null;
    const files = currentSourceFiles();
    if (index >= files.len) return null;
    return files[index].path;
}

fn handleSourceEditorKey(key: []const u8, ctrl: u32, meta: u32, alt: u32, shift: u32) bool {
    if (alt != 0) return false;
    ensureSourceEditor();
    if (source_editor_status != .ready and source_editor_status != .dirty) return false;
    if ((ctrl != 0 or meta != 0) and std.mem.eql(u8, key, "s")) {
        _ = compileWorkspaceInsideWasm();
        return true;
    }
    if ((ctrl != 0 or meta != 0) and std.mem.eql(u8, key, "Enter")) {
        _ = compileWorkspaceInsideWasm();
        return true;
    }
    if ((ctrl != 0 or meta != 0) and (std.mem.eql(u8, key, "a") or std.mem.eql(u8, key, "A"))) {
        source_editor_selection_anchor = 0;
        source_editor_cursor = source_editor_len;
        source_editor_selection_active = source_editor_len != 0;
        source_editor_preferred_column = sourceEditorColumn(source_editor_cursor);
        ensureSourceEditorCursorVisible();
        return true;
    }
    if ((ctrl != 0 or meta != 0) and (std.mem.eql(u8, key, "z") or std.mem.eql(u8, key, "Z"))) return undoSourceEditorEdit();
    if ((ctrl != 0 or meta != 0) and (std.mem.eql(u8, key, "y") or std.mem.eql(u8, key, "Y"))) return redoSourceEditorEdit();
    if ((ctrl != 0 or meta != 0) and std.mem.eql(u8, key, "ArrowLeft")) {
        moveSourceEditorCursor(sourceEditorWordLeft(), shift != 0);
        return true;
    }
    if ((ctrl != 0 or meta != 0) and std.mem.eql(u8, key, "ArrowRight")) {
        moveSourceEditorCursor(sourceEditorWordRight(), shift != 0);
        return true;
    }
    if (ctrl != 0 or meta != 0) return false;

    if (std.mem.eql(u8, key, "ArrowLeft")) {
        moveSourceEditorCursor(source_editor_cursor -| 1, shift != 0);
        return true;
    }
    if (std.mem.eql(u8, key, "ArrowRight")) {
        moveSourceEditorCursor(@min(source_editor_len, source_editor_cursor + 1), shift != 0);
        return true;
    }
    if (std.mem.eql(u8, key, "ArrowUp")) {
        moveSourceEditorVertical(.up, shift != 0);
        return true;
    }
    if (std.mem.eql(u8, key, "ArrowDown")) {
        moveSourceEditorVertical(.down, shift != 0);
        return true;
    }
    if (std.mem.eql(u8, key, "PageUp")) {
        moveSourceEditorPage(.up, shift != 0);
        return true;
    }
    if (std.mem.eql(u8, key, "PageDown")) {
        moveSourceEditorPage(.down, shift != 0);
        return true;
    }
    if (std.mem.eql(u8, key, "Home")) {
        moveSourceEditorCursor(currentSourceEditorLineStart(), shift != 0);
        return true;
    }
    if (std.mem.eql(u8, key, "End")) {
        moveSourceEditorCursor(currentSourceEditorLineEnd(), shift != 0);
        return true;
    }
    if (std.mem.eql(u8, key, "Backspace")) {
        return deleteSourceEditorBackward();
    }
    if (std.mem.eql(u8, key, "Delete")) {
        return deleteSourceEditorForward();
    }
    if (std.mem.eql(u8, key, "Enter")) return insertSourceEditorNewline();
    if (shift != 0 and std.mem.eql(u8, key, "Tab")) return outdentSourceEditorSelection();
    if (source_editor_selection_active and std.mem.eql(u8, key, "Tab")) return indentSourceEditorSelection();
    if (std.mem.eql(u8, key, "Tab")) return insertSourceEditorText(source_editor_tab);
    if (key.len == 1 and key[0] >= 0x20 and key[0] <= 0x7e) return insertSourceEditorText(key);
    return false;
}

fn handleSourceEditorTextInput(input_type: []const u8, data: []const u8) bool {
    ensureSourceEditor();
    if (source_editor_status != .ready and source_editor_status != .dirty) return false;
    if (std.mem.eql(u8, input_type, "insertText") or std.mem.eql(u8, input_type, "insertCompositionText") or std.mem.eql(u8, input_type, "insertFromPaste")) {
        var decoded: [max_input_bytes]u8 = undefined;
        const text = decodeInputEventData(data, &decoded) catch return false;
        return insertSourceEditorText(text);
    }
    if (std.mem.eql(u8, input_type, "insertLineBreak")) return insertSourceEditorText("\n");
    if (std.mem.eql(u8, input_type, "deleteContentBackward")) return deleteSourceEditorBackward();
    if (std.mem.eql(u8, input_type, "deleteContentForward")) return deleteSourceEditorForward();
    return false;
}

fn decodeInputEventData(data: []const u8, out: []u8) ![]const u8 {
    var read: usize = 0;
    var written: usize = 0;
    while (read < data.len) : (read += 1) {
        if (written >= out.len) return error.InputEventDataTooLarge;
        if (data[read] == '\\' and read + 1 < data.len and data[read + 1] == 'n') {
            out[written] = '\n';
            written += 1;
            read += 1;
        } else {
            out[written] = data[read];
            written += 1;
        }
    }
    return out[0..written];
}

fn insertSourceEditorText(text: []const u8) bool {
    if (text.len == 0) return true;
    recordSourceEditorUndo();
    deleteSourceEditorSelectionWithoutHistory();
    if (text.len > source_editor_bytes.len - source_editor_len) {
        source_editor_status = .editor_too_large;
        return true;
    }
    std.mem.copyBackwards(u8, source_editor_bytes[source_editor_cursor + text.len .. source_editor_len + text.len], source_editor_bytes[source_editor_cursor..source_editor_len]);
    @memcpy(source_editor_bytes[source_editor_cursor..][0..text.len], text);
    source_editor_cursor += text.len;
    source_editor_len += text.len;
    source_editor_preferred_column = sourceEditorColumn(source_editor_cursor);
    clearSourceEditorSelection();
    ensureSourceEditorCursorVisible();
    commitSourceEditorBytes();
    return true;
}

fn deleteSourceEditorBackward() bool {
    if (source_editor_selection_active and source_editor_selection_anchor != source_editor_cursor) {
        recordSourceEditorUndo();
        deleteSourceEditorSelectionWithoutHistory();
        commitSourceEditorBytes();
        return true;
    }
    if (source_editor_cursor == 0) return true;
    recordSourceEditorUndo();
    std.mem.copyForwards(u8, source_editor_bytes[source_editor_cursor - 1 .. source_editor_len - 1], source_editor_bytes[source_editor_cursor..source_editor_len]);
    source_editor_cursor -= 1;
    source_editor_len -= 1;
    source_editor_preferred_column = sourceEditorColumn(source_editor_cursor);
    clearSourceEditorSelection();
    ensureSourceEditorCursorVisible();
    commitSourceEditorBytes();
    return true;
}

fn deleteSourceEditorForward() bool {
    if (source_editor_selection_active and source_editor_selection_anchor != source_editor_cursor) {
        recordSourceEditorUndo();
        deleteSourceEditorSelectionWithoutHistory();
        commitSourceEditorBytes();
        return true;
    }
    if (source_editor_cursor >= source_editor_len) return true;
    recordSourceEditorUndo();
    std.mem.copyForwards(u8, source_editor_bytes[source_editor_cursor .. source_editor_len - 1], source_editor_bytes[source_editor_cursor + 1 .. source_editor_len]);
    source_editor_len -= 1;
    source_editor_preferred_column = sourceEditorColumn(source_editor_cursor);
    clearSourceEditorSelection();
    ensureSourceEditorCursorVisible();
    commitSourceEditorBytes();
    return true;
}

fn deleteSourceEditorSelectionWithoutHistory() void {
    const selection = sourceEditorSelectionBounds();
    if (selection.start == selection.end) return;
    std.mem.copyForwards(u8, source_editor_bytes[selection.start .. source_editor_len - (selection.end - selection.start)], source_editor_bytes[selection.end..source_editor_len]);
    source_editor_len -= selection.end - selection.start;
    source_editor_cursor = selection.start;
    source_editor_preferred_column = sourceEditorColumn(source_editor_cursor);
    clearSourceEditorSelection();
    ensureSourceEditorCursorVisible();
}

fn insertSourceEditorNewline() bool {
    var indent: [64]u8 = undefined;
    const line_start = currentSourceEditorLineStart();
    var indent_len: usize = 0;
    while (line_start + indent_len < source_editor_len and indent_len < indent.len) : (indent_len += 1) {
        const byte = source_editor_bytes[line_start + indent_len];
        if (byte != ' ' and byte != '\t') break;
        indent[indent_len] = byte;
    }
    var text_buf: [indent.len + 1]u8 = undefined;
    text_buf[0] = '\n';
    @memcpy(text_buf[1..][0..indent_len], indent[0..indent_len]);
    return insertSourceEditorText(text_buf[0 .. indent_len + 1]);
}

const VerticalMove = enum {
    up,
    down,
};

fn moveSourceEditorVertical(direction: VerticalMove, extend_selection: bool) void {
    const line_start = currentSourceEditorLineStart();
    const line_end = currentSourceEditorLineEnd();
    const column = source_editor_preferred_column;
    const target_start = switch (direction) {
        .up => previousSourceEditorLineStart(line_start) orelse return,
        .down => if (line_end < source_editor_len) line_end + 1 else return,
    };
    const target_end = sourceEditorLineEnd(target_start);
    moveSourceEditorCursor(target_start + @min(column, target_end - target_start), extend_selection);
    source_editor_preferred_column = column;
}

fn moveSourceEditorPage(direction: VerticalMove, extend_selection: bool) void {
    var remaining = source_editor_page_lines;
    while (remaining > 0) : (remaining -= 1) moveSourceEditorVertical(direction, extend_selection);
    source_editor_scroll_line = switch (direction) {
        .up => source_editor_scroll_line -| source_editor_page_lines,
        .down => source_editor_scroll_line + source_editor_page_lines,
    };
}

fn currentSourceEditorLineStart() usize {
    var index = source_editor_cursor;
    while (index > 0 and source_editor_bytes[index - 1] != '\n') : (index -= 1) {}
    return index;
}

fn currentSourceEditorLineEnd() usize {
    return sourceEditorLineEnd(source_editor_cursor);
}

fn sourceEditorLineEnd(start_or_cursor: usize) usize {
    var index = start_or_cursor;
    while (index < source_editor_len and source_editor_bytes[index] != '\n') : (index += 1) {}
    return index;
}

fn previousSourceEditorLineStart(line_start: usize) ?usize {
    if (line_start == 0) return null;
    var index = line_start - 1;
    while (index > 0 and source_editor_bytes[index - 1] != '\n') : (index -= 1) {}
    return index;
}

fn sourceEditorColumn(cursor: usize) usize {
    var index = @min(cursor, source_editor_len);
    while (index > 0 and source_editor_bytes[index - 1] != '\n') : (index -= 1) {}
    return @min(cursor, source_editor_len) - index;
}

fn clearSourceEditorHistory() void {
    source_editor_undo_len = 0;
    source_editor_redo_len = 0;
}

fn pushSourceEditorSnapshot(stack: *[max_source_editor_undo_entries]SourceEditorSnapshot, len: *usize) void {
    if (len.* == max_source_editor_undo_entries) {
        std.mem.copyForwards(SourceEditorSnapshot, stack[0 .. max_source_editor_undo_entries - 1], stack[1..max_source_editor_undo_entries]);
        len.* -= 1;
    }
    const slot = &stack[len.*];
    @memcpy(slot.bytes[0..source_editor_len], source_editor_bytes[0..source_editor_len]);
    slot.len = source_editor_len;
    slot.cursor = source_editor_cursor;
    slot.selection_anchor = source_editor_selection_anchor;
    slot.selection_active = source_editor_selection_active;
    len.* += 1;
}

fn restoreSourceEditorSnapshot(snapshot: SourceEditorSnapshot) void {
    @memcpy(source_editor_bytes[0..snapshot.len], snapshot.bytes[0..snapshot.len]);
    source_editor_len = snapshot.len;
    source_editor_cursor = @min(snapshot.cursor, source_editor_len);
    source_editor_selection_anchor = @min(snapshot.selection_anchor, source_editor_len);
    source_editor_selection_active = snapshot.selection_active and source_editor_selection_anchor != source_editor_cursor;
    source_editor_preferred_column = sourceEditorColumn(source_editor_cursor);
    ensureSourceEditorCursorVisible();
    commitSourceEditorBytes();
}

fn recordSourceEditorUndo() void {
    pushSourceEditorSnapshot(&source_editor_undo, &source_editor_undo_len);
    source_editor_redo_len = 0;
}

fn undoSourceEditorEdit() bool {
    if (source_editor_undo_len == 0) return true;
    pushSourceEditorSnapshot(&source_editor_redo, &source_editor_redo_len);
    source_editor_undo_len -= 1;
    restoreSourceEditorSnapshot(source_editor_undo[source_editor_undo_len]);
    return true;
}

fn redoSourceEditorEdit() bool {
    if (source_editor_redo_len == 0) return true;
    pushSourceEditorSnapshot(&source_editor_undo, &source_editor_undo_len);
    source_editor_redo_len -= 1;
    restoreSourceEditorSnapshot(source_editor_redo[source_editor_redo_len]);
    return true;
}

fn setSourceEditorCursor(cursor: usize) void {
    ensureSourceEditor();
    source_editor_cursor = @min(cursor, source_editor_len);
    source_editor_selection_anchor = source_editor_cursor;
    source_editor_selection_active = false;
    source_editor_preferred_column = sourceEditorColumn(source_editor_cursor);
    ensureSourceEditorCursorVisible();
}

fn moveSourceEditorCursor(cursor: usize, extend_selection: bool) void {
    const clamped = @min(cursor, source_editor_len);
    if (extend_selection) {
        if (!source_editor_selection_active) source_editor_selection_anchor = source_editor_cursor;
        source_editor_selection_active = true;
    } else {
        source_editor_selection_anchor = clamped;
        source_editor_selection_active = false;
    }
    source_editor_cursor = clamped;
    if (source_editor_selection_anchor == source_editor_cursor) source_editor_selection_active = false;
    source_editor_preferred_column = sourceEditorColumn(source_editor_cursor);
    ensureSourceEditorCursorVisible();
}

fn sourceEditorSelectionBounds() struct { start: usize, end: usize } {
    if (!source_editor_selection_active or source_editor_selection_anchor == source_editor_cursor) return .{ .start = source_editor_cursor, .end = source_editor_cursor };
    return if (source_editor_selection_anchor < source_editor_cursor)
        .{ .start = source_editor_selection_anchor, .end = source_editor_cursor }
    else
        .{ .start = source_editor_cursor, .end = source_editor_selection_anchor };
}

fn clearSourceEditorSelection() void {
    source_editor_selection_anchor = source_editor_cursor;
    source_editor_selection_active = false;
}

fn ensureSourceEditorCursorVisible() void {
    const cursor_line = sourceEditorLineIndex(source_editor_cursor);
    if (cursor_line < source_editor_scroll_line + source_editor_scroll_margin_lines) {
        source_editor_scroll_line = cursor_line -| source_editor_scroll_margin_lines;
        return;
    }
    const visible_bottom = source_editor_scroll_line + source_editor_visible_lines -| source_editor_scroll_margin_lines;
    if (cursor_line >= visible_bottom) {
        source_editor_scroll_line = cursor_line -| (source_editor_visible_lines - source_editor_scroll_margin_lines - 1);
    }
}

fn sourceEditorLineIndex(cursor: usize) usize {
    const clamped = @min(cursor, source_editor_len);
    var line: usize = 0;
    for (source_editor_bytes[0..clamped]) |byte| {
        if (byte == '\n') line += 1;
    }
    return line;
}

fn sourceEditorLineCount() usize {
    if (source_editor_len == 0) return 1;
    var lines: usize = 1;
    for (source_editor_bytes[0..source_editor_len]) |byte| {
        if (byte == '\n') lines += 1;
    }
    return lines;
}

fn selectSourceEditorWordAt(cursor: usize) void {
    const clamped = @min(cursor, source_editor_len);
    var start = clamped;
    var end = clamped;
    if (start == source_editor_len and start > 0) start -= 1;
    if (start < source_editor_len and isSourceEditorSeparator(source_editor_bytes[start])) {
        source_editor_cursor = clamped;
        clearSourceEditorSelection();
        return;
    }
    while (start > 0 and !isSourceEditorSeparator(source_editor_bytes[start - 1])) : (start -= 1) {}
    while (end < source_editor_len and !isSourceEditorSeparator(source_editor_bytes[end])) : (end += 1) {}
    source_editor_selection_anchor = start;
    source_editor_cursor = end;
    source_editor_selection_active = end > start;
    source_editor_preferred_column = sourceEditorColumn(source_editor_cursor);
    ensureSourceEditorCursorVisible();
}

fn sourceEditorWordLeft() usize {
    var index = source_editor_cursor;
    while (index > 0 and isSourceEditorSeparator(source_editor_bytes[index - 1])) : (index -= 1) {}
    while (index > 0 and !isSourceEditorSeparator(source_editor_bytes[index - 1])) : (index -= 1) {}
    return index;
}

fn sourceEditorWordRight() usize {
    var index = source_editor_cursor;
    while (index < source_editor_len and !isSourceEditorSeparator(source_editor_bytes[index])) : (index += 1) {}
    while (index < source_editor_len and isSourceEditorSeparator(source_editor_bytes[index])) : (index += 1) {}
    return index;
}

fn isSourceEditorSeparator(byte: u8) bool {
    return switch (byte) {
        'A'...'Z', 'a'...'z', '0'...'9', '_' => false,
        else => true,
    };
}

fn outdentSourceEditorSelection() bool {
    const selection = sourceEditorSelectionBounds();
    var line_start = sourceEditorLineStartAt(selection.start);
    var changed = false;
    recordSourceEditorUndo();
    while (line_start <= selection.end and line_start < source_editor_len) {
        if (source_editor_bytes[line_start] == '\t') {
            std.mem.copyForwards(u8, source_editor_bytes[line_start .. source_editor_len - 1], source_editor_bytes[line_start + 1 .. source_editor_len]);
            source_editor_len -= 1;
            changed = true;
        } else {
            var remove_spaces: usize = 0;
            while (remove_spaces < source_editor_tab.len and line_start + remove_spaces < source_editor_len and source_editor_bytes[line_start + remove_spaces] == ' ') : (remove_spaces += 1) {}
            if (remove_spaces != 0) {
                std.mem.copyForwards(u8, source_editor_bytes[line_start .. source_editor_len - remove_spaces], source_editor_bytes[line_start + remove_spaces .. source_editor_len]);
                source_editor_len -= remove_spaces;
                changed = true;
            }
        }
        const next = sourceEditorLineEnd(line_start);
        if (next >= source_editor_len) break;
        line_start = next + 1;
    }
    source_editor_cursor = @min(source_editor_cursor, source_editor_len);
    source_editor_selection_anchor = @min(source_editor_selection_anchor, source_editor_len);
    source_editor_preferred_column = sourceEditorColumn(source_editor_cursor);
    if (changed) commitSourceEditorBytes();
    return true;
}

fn indentSourceEditorSelection() bool {
    const selection = sourceEditorSelectionBounds();
    var line_start = sourceEditorLineStartAt(selection.start);
    var end_limit = selection.end;
    recordSourceEditorUndo();
    while (line_start <= end_limit and line_start <= source_editor_len) {
        if (source_editor_tab.len > source_editor_bytes.len - source_editor_len) {
            source_editor_status = .editor_too_large;
            return true;
        }
        std.mem.copyBackwards(u8, source_editor_bytes[line_start + source_editor_tab.len .. source_editor_len + source_editor_tab.len], source_editor_bytes[line_start..source_editor_len]);
        @memcpy(source_editor_bytes[line_start..][0..source_editor_tab.len], source_editor_tab);
        source_editor_len += source_editor_tab.len;
        end_limit += source_editor_tab.len;
        if (source_editor_cursor >= line_start) source_editor_cursor += source_editor_tab.len;
        if (source_editor_selection_anchor >= line_start) source_editor_selection_anchor += source_editor_tab.len;
        const next = sourceEditorLineEnd(line_start + source_editor_tab.len);
        if (next >= source_editor_len) break;
        line_start = next + 1;
    }
    source_editor_preferred_column = sourceEditorColumn(source_editor_cursor);
    commitSourceEditorBytes();
    return true;
}

fn sourceEditorLineStartAt(cursor: usize) usize {
    var index = @min(cursor, source_editor_len);
    while (index > 0 and source_editor_bytes[index - 1] != '\n') : (index -= 1) {}
    return index;
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
    source_file_cache_workspace_len = 0;
    release_artifact_len = 0;
    last_compile_phase = .idle;
    last_compile_progress_permille = 0;
    setSourceCompileSummary() catch {};
    return .dirty;
}

fn compileWorkspaceInsideWasm() ErrorCode {
    ensureSourceWorkspace();
    setCompileProgress(.loading_workspace);
    if (source_workspace_len == 0 or source_workspace_len > source_workspace.len) return finishCompileError(.bad_input);

    const source_offset = alignForward(compiler_memory_offset_bytes + compiler_work_memory_bytes + compiler_source_gap_bytes, 16);
    if (source_offset > compiler_runtime_memory.len) return finishCompileError(.bad_input);
    if (source_workspace_len > compiler_runtime_memory.len - source_offset) return finishCompileError(.bad_input);

    @memset(&compiler_runtime_memory, 0);
    @memcpy(compiler_runtime_memory[source_offset .. source_offset + source_workspace_len], source_workspace[0..source_workspace_len]);

    setCompileProgress(.init_compiler);
    var execution_ticks: u64 = compiler_execution_tick_budget;
    var runtime = wasm_interpreter.Runtime.initWithMemoryPages(&compiler_runtime_memory, &execution_ticks, pagesForBytes(source_offset + source_workspace_len));
    var trace: wasm_interpreter.ExecutionTrace = .{};
    runtime.trace = &trace;
    const compiler_memory_ptr: i32 = @intCast(compiler_memory_offset_bytes);
    const compiler_memory_len: i32 = @intCast(compiler_work_memory_bytes);
    const source_ptr: i32 = @intCast(source_offset);
    const source_len: i32 = @intCast(source_workspace_len);
    const init_args = [_]wasm_interpreter.Value{
        .{ .i32 = compiler_memory_ptr },
        .{ .i32 = compiler_memory_len },
    };
    const init_result = wasm_interpreter.executeExportValueArgs(&runtime, &compiler_wasm, "er_wasm_compiler_init", &init_args) catch return finishCompileError(.render_failed);
    last_compiler_status = @intCast(init_result.valueI32(0) catch return finishCompileError(.render_failed));
    if (last_compiler_status != 0) {
        recordCompilerDiagnostic(&runtime);
        return finishCompileError(.bad_input);
    }

    setCompileProgress(.compiling);
    const compile_args = [_]wasm_interpreter.Value{
        .{ .i32 = compiler_memory_ptr },
        .{ .i32 = compiler_memory_len },
        .{ .i32 = 0 },
        .{ .i32 = 0 },
        .{ .i32 = source_ptr },
        .{ .i32 = source_len },
    };
    const compile_result = wasm_interpreter.executeExportValueArgs(&runtime, &compiler_wasm, "er_wasm_compiler_compile_wasm", &compile_args) catch return finishCompileError(.render_failed);
    last_compiler_status = @intCast(compile_result.valueI32(0) catch return finishCompileError(.render_failed));
    if (last_compiler_status != 0) {
        recordCompilerDiagnostic(&runtime);
        last_compile_instructions = trace.instructions;
        last_compile_function_entries = trace.function_entries;
        last_compile_memory_loads = trace.memory_loads;
        return finishCompileError(.bad_input);
    }

    setCompileProgress(.collecting_artifact);
    const output_len_result = wasm_interpreter.executeExportValueArgs(&runtime, &compiler_wasm, "er_wasm_compiler_output_len", &.{}) catch return finishCompileError(.render_failed);
    const output_ptr_result = wasm_interpreter.executeExportValueArgs(&runtime, &compiler_wasm, "er_wasm_compiler_output_ptr", &.{}) catch return finishCompileError(.render_failed);
    const output_ptr: usize = @intCast(output_ptr_result.valueI32(0) catch return finishCompileError(.render_failed));
    const output_len: usize = @intCast(output_len_result.valueI32(0) catch return finishCompileError(.render_failed));
    if (output_len < 4 or output_len > release_artifact.len) return finishCompileError(.bad_input);
    if (output_ptr > compiler_runtime_memory.len or output_len > compiler_runtime_memory.len - output_ptr) return finishCompileError(.bad_input);
    if (!std.mem.eql(u8, compiler_runtime_memory[output_ptr..][0..4], &.{ 0x00, 0x61, 0x73, 0x6d })) return finishCompileError(.bad_input);

    @memcpy(release_artifact[0..output_len], compiler_runtime_memory[output_ptr .. output_ptr + output_len]);
    release_artifact_len = output_len;
    last_compile_instructions = trace.instructions;
    last_compile_function_entries = trace.function_entries;
    last_compile_memory_loads = trace.memory_loads;
    setCompileProgress(.complete);
    setSourceCompileSummary() catch {};
    last_compiler_status = 0;
    last_compiler_diagnostic_len = 0;
    last_error = .ok;
    return .ok;
}

fn setCompileProgress(phase: CompilePhase) void {
    last_compile_phase = phase;
    last_compile_progress_permille = switch (phase) {
        .idle => 0,
        .loading_workspace => 80,
        .init_compiler => 180,
        .compiling => 520,
        .collecting_artifact => 880,
        .complete => 1000,
        .failed => last_compile_progress_permille,
    };
    setSourceCompileSummary() catch {};
}

fn finishCompileError(code: ErrorCode) ErrorCode {
    last_compile_phase = .failed;
    if (last_compile_progress_permille == 0) last_compile_progress_permille = 1;
    setSourceCompileSummary() catch {};
    return finishErrorCode(code);
}

fn setSourceCompileSummary() !void {
    const rendered = try std.fmt.bufPrint(&source_compile_summary, "workspace {d} bytes | file {d} bytes | release {d} bytes | {d} instructions | {d} calls | {d} loads", .{
        source_workspace_len,
        source_editor_len,
        release_artifact_len,
        last_compile_instructions,
        last_compile_function_entries,
        last_compile_memory_loads,
    });
    source_compile_summary_len = rendered.len;
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

export fn er_ui_app_scroll_by(delta_y: f32, width: f32, height: f32) u32 {
    if (!std.math.isFinite(delta_y) or !std.math.isFinite(width) or !std.math.isFinite(height)) return finishError(.bad_input);
    if (width <= 0.0 or height <= 0.0) return finishError(.bad_input);
    const limit = appScrollLimit(width, height);
    app_state.scroll_y = std.math.clamp(app_state.scroll_y + delta_y, 0.0, limit);
    last_error = .ok;
    return @intFromEnum(ErrorCode.ok);
}

export fn er_ui_app_scroll_y() f32 {
    return app_state.scroll_y;
}

export fn er_ui_app_blog_post_content_height(width: f32, post_id: u32) f32 {
    return app_frame.contentHeight(width, .{ .route = .{ .view = .blog, .selected_blog_post_id = post_id } });
}

export fn er_ui_app_content_height(width: f32) f32 {
    return app_frame.contentHeight(width, currentAppFrameState(pointer_hover_x, pointer_hover_y, 0.0));
}

fn appScrollLimit(width: f32, height: f32) f32 {
    return @max(0.0, er_ui_app_content_height(width) - height);
}

fn clampAppScrollToViewport(width: u32, height: u32) void {
    app_state.scroll_y = @min(app_state.scroll_y, appScrollLimit(@floatFromInt(width), @floatFromInt(height)));
}

export fn er_ui_clear(width: u32, height: u32) u32 {
    const surface = beginFrame(width, height) orelse return finishError(.bad_size);
    surface.clear(.bg);
    last_error = .ok;
    return @intFromEnum(ErrorCode.ok);
}

export fn er_ui_build_app_frame(width: u32, height: u32, hover_x: f32, hover_y: f32, frame_ms: f32) u32 {
    if (!setFrameSize(width, height)) return finishError(.bad_size);
    clampAppScrollToViewport(width, height);

    return buildPackedAppFrameFromPreparedSize(currentAppFrameState(hover_x, hover_y, frame_ms));
}

fn buildPackedAppFrameFromPreparedSize(state: app_frame.State) u32 {
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var frame_regions: [max_interaction_regions]interaction.Region = undefined;
    var collector = interaction.Collector.init(&frame_regions);
    app_frame.render(&scene, &collector, frameBounds(), state) catch return finishError(.render_failed);
    return finishPackedFrame(scene, collector.written(), state.hover_x, state.hover_y);
}

export fn er_ui_build_frame(width: u32, height: u32, frame_ms: f32) u32 {
    return er_ui_build_app_frame(width, height, pointer_hover_x, pointer_hover_y, frame_ms);
}

export fn er_ui_render_frame(width: u32, height: u32, frame_ms: f32) u32 {
    const surface = beginFrame(width, height) orelse return finishError(.bad_size);
    clampAppScrollToViewport(width, height);
    return renderAppPixels(surface, pointer_hover_x, pointer_hover_y, frame_ms);
}

export fn er_ui_render_frame_hd(width: u32, height: u32, scale_raw: f32, frame_ms: f32) u32 {
    const scale = framebufferDeviceScale(width, height, scale_raw);
    const physical_width = scaledFrameDimension(width, scale) orelse return finishError(.bad_size);
    const physical_height = scaledFrameDimension(height, scale) orelse return finishError(.bad_size);
    const surface = beginFrame(physical_width, physical_height) orelse return finishError(.bad_size);
    clampAppScrollToViewport(width, height);
    _ = er_ui_set_device_scale(scale);
    return renderAppPixelsScaled(surface, width, height, scale, pointer_hover_x, pointer_hover_y, frame_ms);
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

fn renderAppPixels(surface: renderer_pipeline.SoftwareFramebuffer, hover_x: f32, hover_y: f32, frame_ms: f32) u32 {
    var scene = ui.Scene.initWithClips(&commands, &clips);
    var frame_regions: [max_interaction_regions]interaction.Region = undefined;
    var collector = interaction.Collector.init(&frame_regions);
    app_frame.render(&scene, &collector, frameBounds(), currentAppFrameState(hover_x, hover_y, frame_ms)) catch return finishError(.render_failed);
    return finishCpuSceneFrame(surface, scene, collector.written(), .{ .enabled = true, .x = hover_x, .y = hover_y }, .bg);
}

fn renderAppPixelsScaled(surface: renderer_pipeline.SoftwareFramebuffer, logical_width: u32, logical_height: u32, scale: f32, hover_x: f32, hover_y: f32, frame_ms: f32) u32 {
    const physical_width = frame_width;
    const physical_height = frame_height;
    frame_width = @intCast(logical_width);
    frame_height = @intCast(logical_height);
    defer {
        frame_width = physical_width;
        frame_height = physical_height;
    }

    var scene = ui.Scene.initWithClips(&commands, &clips);
    var frame_regions: [max_interaction_regions]interaction.Region = undefined;
    var collector = interaction.Collector.init(&frame_regions);
    app_frame.render(&scene, &collector, frameBounds(), currentAppFrameState(hover_x, hover_y, frame_ms)) catch return finishError(.render_failed);
    const frame_scene = prepareFrameScene(scene, collector.written(), .{ .enabled = true, .x = hover_x, .y = hover_y }) catch return finishError(.render_failed);
    scaleSceneCommands(commands[0..frame_scene.commandCount()], scale);
    renderSceneIr(surface, frame_scene.written(), .bg) catch return finishError(.render_failed);
    last_error = .ok;
    return @intFromEnum(ErrorCode.ok);
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
    runtime_state.refreshFocus(lastRegions());
    try renderRuntimeFocusRing(&frame_scene);
    if (hover.enabled) try app_cursor.render(&frame_scene, hover.x, hover.y, currentCursorKind());
    last_command_count = frame_scene.written().len;
    return frame_scene;
}

fn renderRuntimeFocusRing(scene: *ui.Scene) ui.RenderError!void {
    if (runtime_state.focused) |hit| {
        try scene.pushRect(hit.bounds.insetUniform(-focus_ring_outset), ui_component_common.state_focus_border, .border, focus_ring_radius, 0.0);
    }
}

fn scaleSceneCommands(scene_commands: []ui.Command, scale: f32) void {
    if (@abs(scale - 1.0) <= 0.001) return;
    for (scene_commands) |*command| scaleSceneCommand(command, scale);
}

fn scaleSceneCommand(command: *ui.Command, scale: f32) void {
    switch (command.*) {
        .rect => |*rect| {
            scaleRect(&rect.bounds, scale);
            rect.radius *= scale;
            rect.shadow *= scale;
        },
        .border => |*border| scaleRect(&border.bounds, scale),
        .text => |*text| scaleRect(&text.origin, scale),
        .drag_source => |*source| scaleRect(&source.bounds, scale),
        .drop_target => |*target| scaleRect(&target.bounds, scale),
        .icon_quad => |*quad| scaleRect(&quad.bounds, scale),
        .text_quad => |*quad| scaleRect(&quad.bounds, scale),
        .image_quad => |*quad| scaleRect(&quad.bounds, scale),
        .transition => {},
    }
}

fn scaleRect(rect: *ui.Rect, scale: f32) void {
    rect.x *= scale;
    rect.y *= scale;
    rect.w *= scale;
    rect.h *= scale;
}

export fn er_ui_render_input_object(input_len: usize, width: u32, height: u32) u32 {
    if (input_len == 0 or input_len > input_bytes.len) return finishError(.bad_input);
    const surface = beginFrame(width, height) orelse return finishError(.bad_size);

    const root = ui_codec.decodeObject(input_bytes[0..input_len], &nodes) catch return finishError(.bad_ui);
    var scene = ui.Scene.init(&commands);
    node_renderer.renderNode(component_union.Component, &scene, .{
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
    const image_texture = try app_images.cloudMeme();
    const receipt = try renderer_pipeline.renderSoftwareFrame(surface, buffers, renderer_pipeline.softwareResourcesFromAlphaAtlas(.{
        .width = font_atlas_width,
        .height = font_atlas_height,
        .alpha = font_atlas.alphaSlice(),
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
    hasher.update("edgerun:zig:wasm-app:interaction-event:v1");
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
    hasher.update("edgerun:zig:wasm-app:ephemeral-ed25519-seed:v1");
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

fn currentAppFrameState(hover_x: f32, hover_y: f32, frame_ms: f32) app_frame.State {
    return .{
        .route = currentRoute(),
        .scroll_y = app_state.scroll_y,
        .hover_x = hover_x,
        .hover_y = hover_y,
        .frame_ms = frame_ms,
        .public_identity = publicIdentityText(),
        .public_identity_ready = ephemeral_identity_ready,
        .source = if (app_state.view == .source) currentSourceState(hover_x, hover_y) else .{},
        .context_menu = .{
            .open = context_menu_open,
            .x = context_menu_x,
            .y = context_menu_y,
            .source_path = context_source_label,
        },
    };
}

fn currentSourceState(hover_x: f32, hover_y: f32) app_source.State {
    ensureSourceWorkspace();
    ensureSourceEditor();
    return .{
        .scroll_y = app_state.scroll_y,
        .hover_x = hover_x,
        .hover_y = hover_y,
        .label = source_editor_label,
        .files = currentSourceFiles(),
        .source = source_editor_bytes[0..source_editor_len],
        .cursor = source_editor_cursor,
        .selection_anchor = source_editor_selection_anchor,
        .selection_active = source_editor_selection_active,
        .scroll_line = source_editor_scroll_line,
        .workspace_bytes = source_workspace_len,
        .file_bytes = source_editor_len,
        .release_bytes = release_artifact_len,
        .dirty = source_editor_dirty,
        .can_undo = source_editor_undo_len != 0,
        .can_redo = source_editor_redo_len != 0,
        .status = sourceEditorStatusText(source_editor_status),
        .compile_phase = compilePhaseText(last_compile_phase),
        .compile_progress = @as(f32, @floatFromInt(last_compile_progress_permille)) / 1000.0,
        .compile_summary = sourceCompileSummaryText(),
        .diagnostic = last_compiler_diagnostic[0..last_compiler_diagnostic_len],
        .diagnostic_line = sourceDiagnosticLine(last_compiler_diagnostic[0..last_compiler_diagnostic_len]),
    };
}

fn sourceEditorStatusText(status: SourceEditorStatus) []const u8 {
    return switch (status) {
        .not_loaded => "source editor not loaded",
        .ready => "ready: editing selected file inside the app-owned VFS object",
        .dirty => "dirty: canonical workspace rebuilt in wasm memory",
        .missing_file => "error: source file missing from workspace object",
        .corrupt_workspace => "error: source workspace object is corrupt",
        .editor_too_large => "error: source file exceeds editor memory budget",
        .workspace_full => "error: rewritten workspace exceeds app memory budget",
    };
}

fn compilePhaseText(phase: CompilePhase) []const u8 {
    return switch (phase) {
        .idle => "idle",
        .loading_workspace => "loading workspace into compiler memory",
        .init_compiler => "initializing embedded Zig-to-wasm compiler",
        .compiling => "compiling app workspace",
        .collecting_artifact => "collecting release wasm artifact",
        .complete => "compile complete",
        .failed => "compile failed",
    };
}

fn sourceCompileSummaryText() []const u8 {
    if (source_compile_summary_len == 0) {
        setSourceCompileSummary() catch return "";
    }
    return source_compile_summary[0..source_compile_summary_len];
}

fn sourceDiagnosticLine(diagnostic: []const u8) usize {
    if (diagnostic.len == 0) return 0;
    var index: usize = 0;
    while (index < diagnostic.len) : (index += 1) {
        if (diagnostic[index] != ':') continue;
        const line_start = index + 1;
        if (line_start >= diagnostic.len or !isAsciiDigit(diagnostic[line_start])) continue;
        var line_end = line_start;
        while (line_end < diagnostic.len and isAsciiDigit(diagnostic[line_end])) : (line_end += 1) {}
        if (line_end >= diagnostic.len or diagnostic[line_end] != ':') continue;
        return std.fmt.parseUnsigned(usize, diagnostic[line_start..line_end], 10) catch 0;
    }
    return 0;
}

fn isAsciiDigit(byte: u8) bool {
    return byte >= '0' and byte <= '9';
}

fn frameBounds() ui.Rect {
    return ui.Rect.init(0, 0, @floatFromInt(frame_width), @floatFromInt(frame_height));
}

fn applyRoutePath(path: []const u8) void {
    applyRoute(app_navigation.fromPath(path));
}

fn applyRoute(route: app_navigation.Route) void {
    context_menu_open = false;
    app_state.resetScroll();
    app_state.view = route.view;
    app_state.selected_blog_post_id = route.selected_blog_post_id;
    app_state.blog_arc_filter_index = route.blog_arc_filter_index;
    app_state.selected_doc_index = route.selected_doc_index;
    app_state.selected_component_index = route.selected_component_index;
}

fn trimRoute(path: []const u8) []const u8 {
    return app_navigation.trimPath(path);
}

fn routePathFromHash(hash: []const u8) error{InvalidRouteHash}![]const u8 {
    return app_navigation.pathFromHash(hash);
}

fn refreshRoutePath() void {
    route_len = app_navigation.writePath(&route_bytes, currentRoute()) catch unreachable;
}

fn refreshRouteHash() void {
    route_hash_len = app_navigation.writeHash(&route_hash_bytes, currentRoute()) catch unreachable;
}

fn currentRoute() app_navigation.Route {
    return .{
        .view = app_state.view,
        .selected_blog_post_id = app_state.selected_blog_post_id,
        .blog_arc_filter_index = app_state.blog_arc_filter_index,
        .selected_doc_index = app_state.selected_doc_index,
        .selected_component_index = app_state.selected_component_index,
    };
}

fn sourceLabelForHit(route: app_navigation.Route, hit_id: u32, out: []u8) ?[]const u8 {
    if (hit_id == 0) return null;
    const index = switch (route.view) {
        .components, .docs => component_gallery.indexByCatalogHit(hit_id) orelse component_gallery.indexByPreviewHit(hit_id),
        else => null,
    } orelse return null;
    return component_gallery.sourcePathForIndex(index, out);
}

fn currentCursorKind() CursorKind {
    const action_kind: ui_runtime.ActionKind = @enumFromInt(@as(u8, @intCast(last_action_kind)));
    return app_cursor.fromState(action_kind, runtime_state.hoverKind());
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

fn hasIconId(items: []const ui.Command, icon_id: u32) bool {
    for (items) |command| switch (command) {
        .icon_quad => |quad| if (quad.icon_id == icon_id) return true,
        else => {},
    };
    return false;
}

fn ensureFontAtlas() !void {
    if (font_atlas_ready) return;
    font_atlas = renderer_font_atlas.Atlas.initWithFont(renderer_font_atlas.geist_ascii_font.body());
    font_atlas.setDeviceScale(font_device_scale);
    font_atlas_generation +%= 1;
    font_atlas_ready = true;
}

fn normalizedDeviceScale(scale: f32) f32 {
    if (!std.math.isFinite(scale)) return default_device_scale;
    return std.math.clamp(scale, min_device_scale, max_device_scale);
}

fn framebufferDeviceScale(width: u32, height: u32, scale_raw: f32) f32 {
    const requested = normalizedDeviceScale(scale_raw);
    if (width == 0 or height == 0) return requested;
    const width_limit = @as(f32, @floatFromInt(max_width)) / @as(f32, @floatFromInt(width));
    const height_limit = @as(f32, @floatFromInt(max_height)) / @as(f32, @floatFromInt(height));
    return std.math.clamp(@min(requested, width_limit, height_limit), min_device_scale, max_device_scale);
}

fn scaledFrameDimension(value: u32, scale: f32) ?u32 {
    if (value == 0 or !std.math.isFinite(scale)) return null;
    const scaled = @ceil(@as(f32, @floatFromInt(value)) * scale);
    if (scaled < 1.0 or scaled > @as(f32, @floatFromInt(std.math.maxInt(u32)))) return null;
    return @intFromFloat(scaled);
}

fn expectSourceDoesNotContain(needle: []const u8) !void {
    const source = @embedFile("app_runtime.zig");
    try std.testing.expect(std.mem.indexOf(u8, source, needle) == null);
}

test "wasm render bridge exports neutral frame and outbox names" {
    try expectSourceDoesNotContain("er_ui_" ++ "gpu_");
    try expectSourceDoesNotContain("er_ui_" ++ "web_");
    try expectSourceDoesNotContain("er_ui_" ++ "host_");
    try expectSourceDoesNotContain("gpu_" ++ "budget");
    try expectSourceDoesNotContain("present" ++ "HostFrame");
}

test "app runtime hover state exposes interaction region kind and id" {
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

test "app runtime ir finish preserves hover state when disabled" {
    runtime_state.hovered = .{ .kind = .button, .id = 99, .bounds = ui.Rect.init(0, 0, 1, 1) };
    var local_commands: [1]ui.Command = undefined;
    const scene = ui.Scene.init(&local_commands);
    var local_pixels: [4]ui.Color = undefined;
    const surface = try renderer_pipeline.softwareFramebuffer(2, 2, &local_pixels);

    try std.testing.expectEqual(@as(u32, 0), finishCpuSceneFrame(surface, scene, &.{}, .{ .enabled = false }, .bg));
    try std.testing.expectEqual(@intFromEnum(ui.HitKind.button), er_ui_hover_hit_kind());
    try std.testing.expectEqual(@as(u32, 99), er_ui_hover_hit_id());
}

test "app runtime draws deterministic focus ring from runtime focus state" {
    runtime_state = .{ .focused = .{ .kind = .button, .id = 77, .bounds = ui.Rect.init(8, 12, 80, 32) } };
    defer runtime_state = .{};
    last_command_count = 0;
    defer last_command_count = 0;

    var regions: [1]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    try collector.addHit(ui.Rect.init(8, 12, 80, 32), .button, 77);
    var local_pixels: [4096]ui.Color = undefined;
    const surface = try renderer_pipeline.softwareFramebuffer(64, 64, &local_pixels);
    const scene = ui.Scene.init(&commands);

    try std.testing.expectEqual(@as(u32, 0), finishCpuSceneFrame(surface, scene, collector.written(), .{ .enabled = false }, .bg));
    try std.testing.expect(hasFocusRingCommand(commands[0..last_command_count]));
}

test "app runtime component catalog builds packed app buffers and app-ready icon lines" {
    font_atlas_ready = false;
    applyRoute(.{ .view = .docs, .selected_doc_index = app_docs.indexBySlug("component-system") });
    const code = er_ui_build_app_frame(960, 640, -1.0, -1.0, 0.0);
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

test "app runtime component catalog render uses canonical ir buffers" {
    applyRoute(.{ .view = .docs, .selected_doc_index = app_docs.indexBySlug("component-system") });
    const code = er_ui_render_frame(480, 360, 0.0);
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

test "app runtime landing builds packed app buffers and hit state" {
    applyRoute(.{});
    const code = er_ui_build_app_frame(1280, 800, 1065.0, 32.0, 0.0);
    try std.testing.expectEqual(@as(u32, 0), code);
    try std.testing.expect(packed_rect_float_len > 0);
    try std.testing.expect(packed_text_vertex_float_len > 0);
    try std.testing.expect(packed_icon_vertex_float_len > 0);
    try std.testing.expectEqual(app_landing.contentHeight(1280.0), er_ui_app_content_height(1280.0));
    try std.testing.expectEqual(@intFromEnum(ui.HitKind.button), er_ui_hover_hit_kind());
    try std.testing.expectEqual(app_chrome.source_button_id, er_ui_hover_hit_id());
}

test "app runtime reveal derives public identity inside wasm from interaction" {
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
    applyRoute(.{});
    _ = er_ui_build_app_frame(1280, 800, 108.0, 500.0, 333.0);
    _ = er_ui_pointer_down(108.0, 500.0);
    _ = er_ui_pointer_up(108.0, 500.0);
    try std.testing.expectEqual(@intFromEnum(UiAction.none), er_ui_app_activate_hit(app_landing.reveal_identity_button_id));
    try std.testing.expect(ephemeral_identity_ready);
    try std.testing.expectEqual(@as(usize, public_identity_text_len), publicIdentityText().len);
    try std.testing.expect(std.mem.startsWith(u8, publicIdentityText(), public_identity_prefix));
    try std.testing.expect(identity.Source.prepare(.ed25519_public, &ephemeral_public_key) != null);
}

test "app runtime blog builds packed app buffers and post hit state" {
    applyRoute(.{ .view = .blog });
    const code = er_ui_build_app_frame(1280, 800, 340.0, 700.0, 0.0);
    try std.testing.expectEqual(@as(u32, 0), code);
    try std.testing.expect(packed_rect_float_len > 0);
    try std.testing.expect(packed_text_vertex_float_len > 0);
    try std.testing.expect(packed_icon_vertex_float_len > 0);
    try std.testing.expect(packed_image_vertex_float_len > 0);
    try std.testing.expect(er_ui_post_image_rgba_ptr() != 0);
    try std.testing.expectEqual(app_images.cloud_meme_width, er_ui_post_image_width());
    try std.testing.expectEqual(app_images.cloud_meme_height, er_ui_post_image_height());
    try std.testing.expectEqual(app_images.cloud_meme_pixel_count * @sizeOf(ui.Color), er_ui_post_image_rgba_len());
    try std.testing.expectEqual(@as(u32, @intCast(app_blog.posts.len)), er_ui_blog_post_count());
    try std.testing.expect(er_ui_app_content_height(1280.0) > 5200.0);
    try std.testing.expect(er_ui_app_blog_post_content_height(1280.0, app_blog.postIdAt(16)) > 1200.0);
    try std.testing.expectEqual(@intFromEnum(ui.HitKind.button), er_ui_hover_hit_kind());
    try std.testing.expectEqual(app_blog.postIdAt(0), er_ui_hover_hit_id());
}

test "app runtime activation keeps page state in wasm" {
    app_state = .{};
    defer app_state = .{};

    try std.testing.expectEqual(app_landing.contentHeight(1280.0), er_ui_app_content_height(1280.0));
    try std.testing.expectEqual(@intFromEnum(UiAction.none), er_ui_app_activate_hit(app_chrome.blog_button_id));
    try std.testing.expectEqual(app_blog.indexContentHeight(1280.0), er_ui_app_content_height(1280.0));
    try std.testing.expectEqual(@intFromEnum(UiAction.none), er_ui_app_activate_hit(app_blog.postIdAt(0)));
    try std.testing.expectEqual(app_blog.postContentHeight(1280.0, app_blog.postIdAt(0)), er_ui_app_content_height(1280.0));
    try std.testing.expectEqual(@intFromEnum(UiAction.none), er_ui_app_activate_hit(app_chrome.source_button_id));
    try std.testing.expectEqualStrings("/source", route_bytes[0..er_ui_app_route_path_len()]);
    try std.testing.expectEqual(@intFromEnum(UiAction.none), er_ui_app_action_kind());
    try std.testing.expectEqual(@as(u32, 0), er_ui_outbox_count());
    try std.testing.expectEqual(@as(u32, 0), er_ui_outbox_clear());
    try std.testing.expectEqual(@as(u32, 0), er_ui_outbox_count());
    try std.testing.expectEqual(@intFromEnum(UiAction.none), er_ui_app_activate_hit(app_chrome.logo_button_id));
    try std.testing.expectEqual(app_landing.contentHeight(1280.0), er_ui_app_content_height(1280.0));
    try std.testing.expectEqual(@intFromEnum(UiAction.none), er_ui_app_activate_hit(app_chrome.blog_button_id));
    try std.testing.expectEqual(@intFromEnum(UiAction.none), er_ui_app_activate_hit(app_blog.arcFilterButtonId(3)));
    try std.testing.expectEqual(app_blog.indexContentHeightFiltered(1280.0, 3), er_ui_app_content_height(1280.0));
    try std.testing.expectEqual(@intFromEnum(UiAction.none), er_ui_app_activate_hit(app_blog.all_lessons_button_id));
    try std.testing.expectEqual(app_blog.indexContentHeight(1280.0), er_ui_app_content_height(1280.0));
    try std.testing.expectEqual(@intFromEnum(UiAction.none), er_ui_app_activate_hit(app_chrome.docs_button_id));
    try std.testing.expectEqual(app_docs.contentHeight(1280.0), er_ui_app_content_height(1280.0));
    try std.testing.expectEqual(@intFromEnum(UiAction.none), er_ui_app_activate_hit(app_docs.component_catalog_button_id));
    try std.testing.expectEqual(component_gallery.contentHeightForState(1280.0, .{}), er_ui_app_content_height(1280.0));
}

test "app runtime route sync owns URL path state" {
    app_state = .{};
    defer app_state = .{};

    try std.testing.expectEqual(@as(u32, 0), er_ui_app_set_route_hash(writeInputForTest("#/academy")));
    try std.testing.expectEqual(app_blog.indexContentHeight(1280.0), er_ui_app_content_height(1280.0));
    try std.testing.expectEqualStrings("/academy", route_bytes[0..er_ui_app_route_path_len()]);
    try std.testing.expectEqualStrings("#/academy", route_hash_bytes[0..er_ui_app_route_hash_len()]);

    const route = "#/academy/40100";
    try std.testing.expectEqual(@as(u32, 0), er_ui_app_set_route_hash(writeInputForTest(route)));
    try std.testing.expectEqual(app_blog.postContentHeight(1280.0, app_blog.postIdAt(0)), er_ui_app_content_height(1280.0));
    try std.testing.expectEqualStrings("/academy/40100", route_bytes[0..er_ui_app_route_path_len()]);
    try std.testing.expectEqualStrings("#/academy/40100", route_hash_bytes[0..er_ui_app_route_hash_len()]);

    try std.testing.expectEqual(@as(u32, 0), er_ui_app_set_route_hash(writeInputForTest("")));
    try std.testing.expectEqual(app_landing.contentHeight(1280.0), er_ui_app_content_height(1280.0));
    try std.testing.expectEqualStrings("/", route_bytes[0..er_ui_app_route_path_len()]);
    try std.testing.expectEqualStrings("", route_hash_bytes[0..er_ui_app_route_hash_len()]);

    try std.testing.expectEqual(@as(u32, 0), er_ui_app_set_route_hash(writeInputForTest("#/apps")));
    try std.testing.expectEqual(app_landing.contentHeight(1280.0), er_ui_app_content_height(1280.0));
    try std.testing.expectEqualStrings("/", route_bytes[0..er_ui_app_route_path_len()]);

    try std.testing.expectEqual(@as(u32, 0), er_ui_app_set_route_hash(writeInputForTest("#/docs/media")));
    const media_index = app_docs.indexBySlug("media").?;
    try std.testing.expectEqual(media_index, app_state.selected_doc_index.?);
    try std.testing.expectEqual(app_docs.contentHeightForState(1280.0, .{ .selected_doc_index = media_index }), er_ui_app_content_height(1280.0));
    try std.testing.expectEqualStrings("/docs/media", route_bytes[0..er_ui_app_route_path_len()]);
    try std.testing.expectEqualStrings("#/docs/media", route_hash_bytes[0..er_ui_app_route_hash_len()]);

    try std.testing.expectEqual(@as(u32, 0), er_ui_app_set_route_hash(writeInputForTest("#/docs")));
    try std.testing.expectEqual(app_docs.contentHeight(1280.0), er_ui_app_content_height(1280.0));
    try std.testing.expectEqualStrings("/docs", route_bytes[0..er_ui_app_route_path_len()]);
    try std.testing.expectEqualStrings("#/docs", route_hash_bytes[0..er_ui_app_route_hash_len()]);

    try std.testing.expectEqual(@as(u32, 0), er_ui_app_set_route_hash(writeInputForTest("#/docs/component-system")));
    const component_system_index = app_docs.indexBySlug("component-system").?;
    try std.testing.expectEqual(component_system_index, app_state.selected_doc_index.?);
    try std.testing.expectEqual(app_docs.contentHeightForState(1280.0, .{ .selected_doc_index = component_system_index }), er_ui_app_content_height(1280.0));
    try std.testing.expectEqualStrings("/docs/component-system", route_bytes[0..er_ui_app_route_path_len()]);
    try std.testing.expectEqualStrings("#/docs/component-system", route_hash_bytes[0..er_ui_app_route_hash_len()]);

    try std.testing.expectEqual(@as(u32, 0), er_ui_app_set_route_hash(writeInputForTest("#/docs/components/button")));
    const button_index = component_gallery.indexBySlug("button").?;
    try std.testing.expectEqual(button_index, app_state.selected_component_index.?);
    try std.testing.expectEqual(component_gallery.contentHeightForState(1280.0, .{ .selected_component_index = button_index }), er_ui_app_content_height(1280.0));
    try std.testing.expectEqualStrings("/docs/components/button", route_bytes[0..er_ui_app_route_path_len()]);

    try std.testing.expectEqual(@as(u32, @intFromEnum(ErrorCode.bad_input)), er_ui_app_set_route_hash(writeInputForTest("#academy")));
    try std.testing.expectEqualStrings("/docs/components/button", route_bytes[0..er_ui_app_route_path_len()]);
}

test "app runtime context source jump opens exact component file" {
    app_state = .{};
    runtime_state = .{};
    context_menu_open = false;
    context_source_label = "";
    defer app_state = .{};
    defer runtime_state = .{};
    defer _ = er_ui_source_workspace_reset();

    const button_index = component_gallery.indexBySlug("button").?;
    const preview_id = component_gallery.preview_base_id + 7000 + @as(u32, @intCast(button_index)) * 32;
    applyRoute(.{ .view = .docs, .selected_doc_index = app_docs.indexBySlug("component-system"), .selected_component_index = button_index });
    try storeLastRegions(&.{.{ .slot = 0, .kind = .button, .id = preview_id, .bounds = ui.Rect.init(40, 40, 200, 80) }});

    try std.testing.expectEqual(@as(u32, 0), er_ui_app_context_menu(80.0, 60.0));
    try std.testing.expect(context_menu_open);
    try std.testing.expectEqualStrings("src/ui/components/Button.zig", context_source_label);
    try std.testing.expectEqual(@intFromEnum(UiAction.none), er_ui_app_activate_hit(app_navigation.context_source_button_id));
    try std.testing.expectEqualStrings("/source", route_bytes[0..er_ui_app_route_path_len()]);
    try std.testing.expectEqualStrings("src/ui/components/Button.zig", source_editor_label);
    try std.testing.expectEqual(@intFromEnum(SourceEditorStatus.ready), er_ui_source_editor_status());
}

fn writeInputForTest(value: []const u8) usize {
    @memcpy(input_bytes[0..value.len], value);
    return value.len;
}

fn eventBytesForTest(kind: InputEventKind, x: f32, y: f32, delta_y: f32, flags: u32, key: []const u8, code: []const u8, input_type: []const u8, data: []const u8, width: f32, height: f32) u32 {
    const input_len = writeEventRecordForTest(kind, x, y, delta_y, flags, key, code, input_type, data);
    return er_ui_event_bytes(input_len, width, height, 0);
}

fn writeEventRecordForTest(kind: InputEventKind, x: f32, y: f32, delta_y: f32, flags: u32, key: []const u8, code: []const u8, input_type: []const u8, data: []const u8) usize {
    _ = bytes.store32(input_bytes[input_event_record_kind_offset..][0..4], @intFromEnum(kind));
    storeEventF32ForTest(input_event_record_x_offset, x);
    storeEventF32ForTest(input_event_record_y_offset, y);
    storeEventF32ForTest(input_event_record_delta_y_offset, delta_y);
    _ = bytes.store32(input_bytes[input_event_record_flags_offset..][0..4], flags);
    _ = bytes.store32(input_bytes[input_event_record_key_len_offset..][0..4], @intCast(key.len));
    _ = bytes.store32(input_bytes[input_event_record_code_len_offset..][0..4], @intCast(code.len));
    _ = bytes.store32(input_bytes[input_event_record_input_type_len_offset..][0..4], @intCast(input_type.len));
    _ = bytes.store32(input_bytes[input_event_record_data_len_offset..][0..4], @intCast(data.len));
    var offset: usize = input_event_record_header_bytes;
    @memcpy(input_bytes[offset..][0..key.len], key);
    offset += key.len;
    @memcpy(input_bytes[offset..][0..code.len], code);
    offset += code.len;
    @memcpy(input_bytes[offset..][0..input_type.len], input_type);
    offset += input_type.len;
    @memcpy(input_bytes[offset..][0..data.len], data);
    offset += data.len;
    return offset;
}

fn storeEventF32ForTest(offset: usize, value: f32) void {
    _ = bytes.store32(input_bytes[offset..][0..4], @as(u32, @bitCast(value)));
}

fn keyEventForTest(value: []const u8, ctrl: bool, meta: bool, alt: bool) u32 {
    return er_ui_app_key_event(
        writeInputForTest(value),
        if (ctrl) 1 else 0,
        if (meta) 1 else 0,
        if (alt) 1 else 0,
    );
}

fn lastRegionBounds(id: u32) !ui.Rect {
    for (lastRegions()) |region| {
        if (region.id == id) return region.bounds;
    }
    return error.MissingHit;
}

fn hasFocusRingCommand(items: []const ui.Command) bool {
    for (items) |command| switch (command) {
        .rect => |rect| {
            if (rect.mode == .border and std.meta.eql(rect.color, ui_component_common.state_focus_border)) return true;
        },
        else => {},
    };
    return false;
}

test "app runtime key policy stays inert until an app owns text input" {
    app_state = .{};
    defer app_state = .{};

    try std.testing.expectEqual(@as(u32, 0), keyEventForTest("/", false, false, false));
    try std.testing.expectEqual(@as(u32, 0), keyEventForTest("k", true, false, false));
    try std.testing.expectEqual(@as(u32, 0), keyEventForTest("K", false, true, false));
    try std.testing.expectEqual(@as(u32, 0), keyEventForTest("x", false, false, true));
    try std.testing.expectEqual(@as(u32, 0), keyEventForTest("ArrowDown", false, false, false));
}

test "app runtime event bytes keep host event decoding inside wasm" {
    app_state = .{};
    runtime_state = .{};
    pointer_hover_x = -1.0;
    pointer_hover_y = -1.0;
    defer app_state = .{};
    defer runtime_state = .{};

    try std.testing.expectEqual(
        input_event_schedule_frame,
        eventBytesForTest(.pointer_move, 42.0, 88.0, 0.0, 0, "", "", "", "", 1280.0, 900.0),
    );
    try std.testing.expectEqual(@as(f32, 42.0), pointer_hover_x);
    try std.testing.expectEqual(@as(f32, 88.0), pointer_hover_y);

    try std.testing.expectEqual(
        input_event_prevent_default | input_event_schedule_frame,
        eventBytesForTest(.wheel, 0.0, 0.0, 120.0, 0, "", "", "", "", 1280.0, 900.0),
    );
    try std.testing.expectEqual(@as(f32, 120.0), app_state.scroll_y);

    try std.testing.expectEqual(
        input_event_schedule_frame,
        eventBytesForTest(.hashchange, 0.0, 0.0, 0.0, 0, "", "", "", "#/apps", 1280.0, 900.0),
    );
    try std.testing.expectEqualStrings("/", route_bytes[0..er_ui_app_route_path_len()]);

    try std.testing.expectEqual(input_event_schedule_frame, eventBytesForTest(.key_up, 0.0, 0.0, 0.0, 0, "k", "KeyK", "", "", 1280.0, 900.0));
}

test "app runtime event pump owns dom event interpretation" {
    app_state = .{};
    runtime_state = .{};
    clearOutboxMessages();
    pointer_hover_x = -1.0;
    pointer_hover_y = -1.0;
    last_command_count = 0;
    defer app_state = .{};
    defer runtime_state = .{};
    defer clearOutboxMessages();

    try std.testing.expectEqual(input_event_schedule_frame, er_ui_event(@intFromEnum(InputEventKind.resize), 0, 0, 0, 0, 0, 0, 0, 1280.0, 900.0));

    const wheel_result = er_ui_event(@intFromEnum(InputEventKind.wheel), 0, 0, 320.0, 0, 0, 0, 0, 1280.0, 900.0);
    try std.testing.expectEqual(input_event_prevent_default | input_event_schedule_frame, wheel_result);
    try std.testing.expectEqual(@as(f32, 320.0), app_state.scroll_y);

    try std.testing.expectEqual(input_event_schedule_frame, er_ui_event(@intFromEnum(InputEventKind.pointer_move), 42.0, 88.0, 0, 0, 0, 0, 0, 1280.0, 900.0));
    try std.testing.expectEqual(@as(f32, 42.0), pointer_hover_x);
    try std.testing.expectEqual(@as(f32, 88.0), pointer_hover_y);
    try std.testing.expectEqual(input_event_schedule_frame, er_ui_event(@intFromEnum(InputEventKind.pointer_leave), 0, 0, 0, 0, 0, 0, 0, 1280.0, 900.0));
    try std.testing.expectEqual(@as(f32, -1.0), pointer_hover_x);
    try std.testing.expectEqual(@as(f32, -1.0), pointer_hover_y);

    try std.testing.expectEqual(@as(u32, 0), er_ui_event(@intFromEnum(InputEventKind.key_down), 0, 0, 0, 0, 0, 0, writeInputForTest("/"), 1280.0, 900.0));

    try std.testing.expectEqual(input_event_schedule_frame, er_ui_event(@intFromEnum(InputEventKind.hashchange), 0, 0, 0, 0, 0, 0, writeInputForTest("#/apps"), 1280.0, 900.0));
    try std.testing.expectEqualStrings("/", route_bytes[0..er_ui_app_route_path_len()]);

    try std.testing.expectEqual(input_event_error, er_ui_event(@intFromEnum(InputEventKind.hashchange), 0, 0, 0, 0, 0, 0, writeInputForTest("#apps"), 1280.0, 900.0));
    try std.testing.expectEqual(@intFromEnum(ErrorCode.bad_input), er_ui_last_error());
    try std.testing.expectEqualStrings("/", route_bytes[0..er_ui_app_route_path_len()]);

    app_state.queued_action = .none;
    last_command_count = 0;
    try storeLastRegions(&.{.{ .slot = 0, .kind = .button, .id = app_chrome.source_button_id, .bounds = ui.Rect.init(0, 0, 40, 40) }});
    const pointer_result = er_ui_event(@intFromEnum(InputEventKind.pointer_up), 8.0, 8.0, 0, 0, 0, 0, 0, 1280.0, 900.0);
    try std.testing.expectEqual(input_event_release_pointer | input_event_schedule_frame | input_event_outbox, pointer_result);
    try std.testing.expectEqual(@as(u32, 1), er_ui_outbox_count());
    try std.testing.expectEqual(@intFromEnum(OutboxKind.push_route_hash), er_ui_outbox_kind(0));
    try std.testing.expect(er_ui_outbox_id(0) != 0);
    try std.testing.expectEqualStrings("#/source", (@as([*]const u8, @ptrFromInt(er_ui_outbox_payload_ptr(0))))[0..er_ui_outbox_payload_len(0)]);
}

test "app runtime boot emits document title host command" {
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

test "app runtime records host appearance preference" {
    try std.testing.expectEqual(@as(u32, 1), er_ui_set_environment_appearance(1));
    try std.testing.expectEqual(@as(u32, 1), er_ui_environment_appearance());
    try std.testing.expectEqual(@as(u32, 2), er_ui_set_environment_appearance(2));
    try std.testing.expectEqual(@as(u32, 2), er_ui_environment_appearance());
    try std.testing.expectEqual(@as(u32, 0), er_ui_set_environment_appearance(99));
    try std.testing.expectEqual(@as(u32, 0), er_ui_environment_appearance());
}

test "app runtime exposes no secondary bootstrap javascript" {
    const bootstrap_js: [*]const u8 = @ptrFromInt(er_ui_bootstrap_js_ptr());
    const js_bytes = bootstrap_js[0..er_ui_bootstrap_js_len()];

    try std.testing.expectEqualStrings(web_host_js.source, js_bytes);
    try std.testing.expectEqual(@as(usize, 0), js_bytes.len);
    try std.testing.expect(std.mem.indexOf(u8, js_bytes, "document.body.innerHTML") == null);
    try std.testing.expect(std.mem.indexOf(u8, js_bytes, "WebAssembly.instantiate(") == null);
    try std.testing.expect(std.mem.indexOf(u8, js_bytes, "er_ui_compiler_wasm_ptr") == null);
    try std.testing.expect(std.mem.indexOf(u8, js_bytes, "er_wasm_compiler_compile_wasm") == null);
    try std.testing.expect(std.mem.indexOf(u8, js_bytes, "fetch(") == null);
}

test "app runtime exposes repo-owned source as canonical object bytes" {
    const source: [*]const u8 = @ptrFromInt(er_ui_compiler_source_ptr());
    const source_bytes = source[0..er_ui_compiler_source_len()];
    const view = try object.View.decode(source_bytes);

    try std.testing.expectEqual(object.Kind.bytes, view.header.kind);
    try std.testing.expect(std.mem.startsWith(u8, view.body, "ERVFSWS1"));
    const file_count = bytes.load32(view.body[12..16]) orelse return error.Corrupt;
    try std.testing.expect(file_count > 0);

    var index: usize = 16;
    var saw_runtime = false;
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

        if (std.mem.eql(u8, label_ref.labelSlice(), "src/app_runtime.zig")) saw_runtime = true;
        if (std.mem.eql(u8, label_ref.labelSlice(), "compiler/zig/src/edgerun_wasm_compiler.zig")) saw_compiler = true;
    }
    try std.testing.expectEqual(view.body.len, index);
    try std.testing.expect(saw_runtime);
    try std.testing.expect(saw_compiler);
}

test "app runtime embeds compiler wasm bytes into parent app" {
    const wasm_bytes: [*]const u8 = @ptrFromInt(er_ui_compiler_wasm_ptr());
    const compiler_bytes = wasm_bytes[0..er_ui_compiler_wasm_len()];

    try std.testing.expect(compiler_bytes.len > 0);
    try std.testing.expectEqualSlices(u8, &.{ 0x00, 0x61, 0x73, 0x6d }, compiler_bytes[0..4]);
}

test "app runtime source workspace is mutable app source" {
    try std.testing.expectEqual(@as(u32, 0), er_ui_source_workspace_reset());
    defer _ = er_ui_source_workspace_reset();
    const workspace: [*]u8 = @ptrFromInt(er_ui_source_workspace_ptr());
    const initial = workspace[0..er_ui_source_workspace_len()];
    const view = try object.View.decode(initial);
    try std.testing.expect(std.mem.indexOf(u8, view.body, "er_wasm_compiler_compile_wasm") != null);

    const edited = "pub export fn edited() void {}";
    @memcpy(workspace[0..edited.len], edited);
    try std.testing.expectEqual(@intFromEnum(ErrorCode.bad_input), er_ui_source_workspace_commit(edited.len));
    try std.testing.expectEqual(initial.len, er_ui_source_workspace_len());
    @memcpy(workspace[0..source_object.len], source_object[0..]);
    try std.testing.expectEqual(@as(u32, 0), er_ui_source_workspace_commit(source_object.len));
    try std.testing.expectEqual(source_object.len, er_ui_source_workspace_len());
}

test "app runtime source route initializes embedded editor state" {
    source_workspace_ready = false;
    source_workspace_len = 0;
    source_editor_loaded = false;
    source_editor_len = 0;
    source_editor_status = .not_loaded;
    applyRoute(.{ .view = .source });
    defer _ = er_ui_source_workspace_reset();

    const code = er_ui_build_app_frame(960, 640, -1.0, -1.0, 0.0);
    try std.testing.expectEqual(@as(u32, 0), code);
    try std.testing.expect(source_workspace_len > 0);
    try std.testing.expect(source_editor_len > 0);
    try std.testing.expectEqual(SourceEditorStatus.ready, source_editor_status);
}

test "app runtime source editor rewrites a canonical vfs file" {
    try std.testing.expectEqual(@as(u32, 0), er_ui_source_workspace_reset());
    defer _ = er_ui_source_workspace_reset();
    applyRoute(.{ .view = .source });
    runtime_state.focused = .{ .kind = .textarea, .id = app_source.editor_textarea_id, .bounds = ui.Rect.init(0.0, 0.0, 1.0, 1.0) };
    defer runtime_state = .{};

    const original = try findWorkspaceFileBody(source_object[0..], source_editor_label);
    const editor: [*]const u8 = @ptrFromInt(er_ui_source_editor_ptr());
    try std.testing.expectEqual(@intFromEnum(SourceEditorStatus.ready), er_ui_source_editor_status());
    try std.testing.expectEqualStrings(original, editor[0..er_ui_source_editor_len()]);

    try std.testing.expectEqual(@as(u32, 1), er_ui_app_key_event(writeInputForTest("/"), 0, 0, 0));
    try std.testing.expectEqual(@intFromEnum(SourceEditorStatus.dirty), er_ui_source_editor_status());
    const edited = try findWorkspaceFileBody(source_workspace[0..source_workspace_len], source_editor_label);
    try std.testing.expectEqual(original.len + 1, edited.len);
    try std.testing.expectEqual(@as(u8, '/'), edited[0]);
    try std.testing.expectEqualStrings(original, edited[1..]);

    try std.testing.expectEqual(@as(u32, 1), er_ui_app_key_event(writeInputForTest("Backspace"), 0, 0, 0));
    const restored = try findWorkspaceFileBody(source_workspace[0..source_workspace_len], source_editor_label);
    try std.testing.expectEqualStrings(original, restored);
}

test "app runtime source editor pointer focus places caret before editing" {
    try std.testing.expectEqual(@as(u32, 0), er_ui_source_workspace_reset());
    defer _ = er_ui_source_workspace_reset();
    app_state = .{};
    runtime_state = .{};
    defer app_state = .{};
    defer runtime_state = .{};

    applyRoute(.{ .view = .source });
    const code = er_ui_build_app_frame(1280, 800, -1.0, -1.0, 0.0);
    try std.testing.expectEqual(@as(u32, 0), code);
    const editor_bounds = try lastRegionBounds(app_source.editor_textarea_id);
    const click_x = editor_bounds.x + 90.0;
    const click_y = editor_bounds.y + 20.0;

    const pointer_result = er_ui_event(@intFromEnum(InputEventKind.pointer_down), click_x, click_y, 0.0, 0, 0, 0, 0, 1280.0, 800.0);
    try std.testing.expectEqual(input_event_capture_pointer | input_event_schedule_frame, pointer_result);
    try std.testing.expectEqual(ui.HitKind.textarea, runtime_state.focusKind().?);
    try std.testing.expectEqual(app_source.editor_textarea_id, runtime_state.focusHitId());
    try std.testing.expectEqual(@as(usize, 0), source_editor_cursor);

    try std.testing.expectEqual(@as(u32, 1), er_ui_app_key_event(writeInputForTest("z"), 0, 0, 0));
    try std.testing.expectEqual(@as(u8, 'z'), source_editor_bytes[0]);
}

test "app runtime source explorer rows open real workspace files" {
    try std.testing.expectEqual(@as(u32, 0), er_ui_source_workspace_reset());
    defer _ = er_ui_source_workspace_reset();
    app_state = .{};
    runtime_state = .{};
    defer app_state = .{};
    defer runtime_state = .{};

    applyRoute(.{ .view = .source });
    const code = er_ui_build_app_frame(1280, 800, -1.0, -1.0, 0.0);
    try std.testing.expectEqual(@as(u32, 0), code);
    const row_bounds = try lastRegionBounds(app_source.explorer_file_id_base + 1);
    const pointer_result = er_ui_event(@intFromEnum(InputEventKind.pointer_down), row_bounds.x + 12.0, row_bounds.y + 12.0, 0.0, 0, 0, 0, 0, 1280.0, 800.0);

    try std.testing.expectEqual(input_event_capture_pointer | input_event_schedule_frame, pointer_result);
    try std.testing.expectEqualStrings("src/app_source.zig", source_editor_label);
    try std.testing.expectEqual(SourceEditorStatus.ready, source_editor_status);
    try std.testing.expect(source_editor_len > 0);
}

test "app runtime source editor moves by visual lines" {
    const sample = "aa\nbbbb\nc";
    @memcpy(source_editor_bytes[0..sample.len], sample);
    source_editor_len = sample.len;
    source_editor_cursor = 1;
    source_editor_preferred_column = 1;
    source_editor_loaded = true;
    source_editor_status = .ready;
    source_editor_dirty = false;
    defer {
        source_editor_loaded = false;
        source_editor_len = 0;
        source_editor_cursor = 0;
        source_editor_preferred_column = 0;
        source_editor_status = .not_loaded;
        source_editor_dirty = false;
    }

    try std.testing.expect(handleSourceEditorKey("ArrowDown", 0, 0, 0, 0));
    try std.testing.expectEqual(@as(usize, 4), source_editor_cursor);
    try std.testing.expect(handleSourceEditorKey("ArrowDown", 0, 0, 0, 0));
    try std.testing.expectEqual(@as(usize, 9), source_editor_cursor);
    try std.testing.expect(handleSourceEditorKey("ArrowUp", 0, 0, 0, 0));
    try std.testing.expectEqual(@as(usize, 4), source_editor_cursor);
    try std.testing.expect(handleSourceEditorKey("Home", 0, 0, 0, 0));
    try std.testing.expectEqual(@as(usize, 3), source_editor_cursor);
    try std.testing.expect(handleSourceEditorKey("End", 0, 0, 0, 0));
    try std.testing.expectEqual(@as(usize, 7), source_editor_cursor);
}

test "app runtime source editor handles full event records and edit history" {
    try std.testing.expectEqual(@as(u32, 0), er_ui_source_workspace_reset());
    defer _ = er_ui_source_workspace_reset();
    app_state = .{};
    runtime_state = .{};
    defer app_state = .{};
    defer runtime_state = .{};

    applyRoute(.{ .view = .source });
    ensureSourceEditor();
    runtime_state.focused = .{ .kind = .textarea, .id = app_source.editor_textarea_id, .bounds = ui.Rect.init(0.0, 0.0, 1.0, 1.0) };
    const original_len = source_editor_len;
    const original_first = source_editor_bytes[0];

    try std.testing.expectEqual(
        input_event_prevent_default | input_event_schedule_frame,
        eventBytesForTest(.before_input, 0.0, 0.0, 0.0, 0, "", "", "insertText", "q", 1280.0, 900.0),
    );
    try std.testing.expectEqual(original_len + 1, source_editor_len);
    try std.testing.expectEqual(@as(u8, 'q'), source_editor_bytes[0]);
    try std.testing.expect(source_editor_undo_len != 0);

    try std.testing.expectEqual(
        input_event_prevent_default | input_event_schedule_frame,
        eventBytesForTest(.key_down, 0.0, 0.0, 0.0, input_event_flag_ctrl, "z", "KeyZ", "", "", 1280.0, 900.0),
    );
    try std.testing.expectEqual(original_len, source_editor_len);
    try std.testing.expectEqual(original_first, source_editor_bytes[0]);
    try std.testing.expect(source_editor_redo_len != 0);

    try std.testing.expectEqual(
        input_event_prevent_default | input_event_schedule_frame,
        eventBytesForTest(.key_down, 0.0, 0.0, 0.0, input_event_flag_ctrl, "y", "KeyY", "", "", 1280.0, 900.0),
    );
    try std.testing.expectEqual(original_len + 1, source_editor_len);
    try std.testing.expectEqual(@as(u8, 'q'), source_editor_bytes[0]);

    try std.testing.expectEqual(
        input_event_prevent_default | input_event_schedule_frame,
        eventBytesForTest(.key_down, 0.0, 0.0, 0.0, input_event_flag_ctrl, "a", "KeyA", "", "", 1280.0, 900.0),
    );
    try std.testing.expect(source_editor_selection_active);
    try std.testing.expectEqual(@as(usize, 0), source_editor_selection_anchor);
    try std.testing.expectEqual(source_editor_len, source_editor_cursor);
}

test "app runtime source editor uses workspace file list and pointer selection" {
    try std.testing.expectEqual(@as(u32, 0), er_ui_source_workspace_reset());
    defer _ = er_ui_source_workspace_reset();
    app_state = .{};
    runtime_state = .{};
    defer app_state = .{};
    defer runtime_state = .{};

    applyRoute(.{ .view = .source });
    const files = currentSourceFiles();
    try std.testing.expect(files.len > 4);
    try std.testing.expectEqualStrings(files[0].path, sourceFileLabelFromHit(app_source.explorer_file_id_base).?);

    const sample = "alpha beta\ngamma";
    @memcpy(source_editor_bytes[0..sample.len], sample);
    source_editor_len = sample.len;
    source_editor_cursor = 0;
    source_editor_preferred_column = 0;
    source_editor_selection_anchor = 0;
    source_editor_selection_active = false;
    source_editor_loaded = true;
    source_editor_status = .ready;
    source_editor_dirty = false;

    selectSourceEditorWordAt(2);
    try std.testing.expect(source_editor_selection_active);
    try std.testing.expectEqual(@as(usize, 0), source_editor_selection_anchor);
    try std.testing.expectEqual(@as(usize, 5), source_editor_cursor);

    moveSourceEditorCursor(10, true);
    try std.testing.expect(source_editor_selection_active);
    try std.testing.expectEqual(@as(usize, 5), source_editor_selection_anchor);
    try std.testing.expectEqual(@as(usize, 10), source_editor_cursor);
}

test "app runtime source editor scrolls editor viewport without page scroll" {
    const sample =
        "0\n1\n2\n3\n4\n5\n6\n7\n8\n9\n" ++
        "10\n11\n12\n13\n14\n15\n16\n17\n18\n19\n" ++
        "20\n21\n22\n23\n24\n25\n26\n27\n28\n29\n" ++
        "30\n31\n32\n33\n34\n35\n36\n37\n38\n39\n";
    @memcpy(source_editor_bytes[0..sample.len], sample);
    source_editor_len = sample.len;
    source_editor_cursor = 0;
    source_editor_preferred_column = 0;
    source_editor_selection_anchor = 0;
    source_editor_selection_active = false;
    source_editor_scroll_line = 0;
    source_editor_loaded = true;
    source_editor_status = .ready;
    source_editor_dirty = false;
    app_state = .{ .view = .source };
    runtime_state = .{};
    defer app_state = .{};
    defer runtime_state = .{};
    defer {
        source_editor_loaded = false;
        source_editor_len = 0;
        source_editor_cursor = 0;
        source_editor_preferred_column = 0;
        source_editor_selection_anchor = 0;
        source_editor_selection_active = false;
        source_editor_scroll_line = 0;
        source_editor_status = .not_loaded;
        source_editor_dirty = false;
    }

    try storeLastRegions(&.{.{ .slot = 0, .kind = .textarea, .id = app_source.editor_textarea_id, .bounds = ui.Rect.init(40, 40, 400, 400) }});
    runtime_state.refreshHover(lastRegions(), 80.0, 80.0);
    try std.testing.expect(scrollSourceEditorByWheel(180.0));
    try std.testing.expect(source_editor_scroll_line > 0);
    try std.testing.expectEqual(@as(f32, 0.0), app_state.scroll_y);
}

test "app runtime extracts diagnostic line for editor markers" {
    try std.testing.expectEqual(@as(usize, 42), sourceDiagnosticLine("src/app_runtime.zig:42:9: error: broken"));
    try std.testing.expectEqual(@as(usize, 7), sourceDiagnosticLine("error at compiler/zig/main.zig:7:1"));
    try std.testing.expectEqual(@as(usize, 0), sourceDiagnosticLine("compile failed without a source span"));
}

test "app runtime release artifact slot only commits wasm modules" {
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

test "app runtime emits successor artifact with source workspace embedded" {
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

test "app runtime exports committed wasm artifact through generic byte bridge" {
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

test "app runtime app state owns scroll position" {
    app_state = .{};
    defer app_state = .{};

    try std.testing.expectEqual(@as(u32, 0), er_ui_app_scroll_by(320.0, 1280.0, 900.0));
    try std.testing.expectEqual(@as(f32, 320.0), er_ui_app_scroll_y());
    try std.testing.expectEqual(@as(u32, 0), er_ui_app_activate_hit(app_chrome.blog_button_id));
    try std.testing.expectEqual(@as(f32, 0.0), er_ui_app_scroll_y());
    try std.testing.expectEqual(@as(u32, 0), er_ui_app_scroll_by(200000.0, 1280.0, 900.0));
    try std.testing.expectEqual(appScrollLimit(1280.0, 900.0), er_ui_app_scroll_y());
}

test "app render clamps stale scroll after viewport resize" {
    app_state = .{};
    defer app_state = .{};

    try std.testing.expectEqual(@as(u32, 0), er_ui_app_scroll_by(200000.0, 360.0, 320.0));
    const narrow_limit = appScrollLimit(360.0, 320.0);
    try std.testing.expectEqual(narrow_limit, er_ui_app_scroll_y());
    try std.testing.expect(narrow_limit > appScrollLimit(1280.0, 900.0));

    try std.testing.expectEqual(@as(u32, 0), er_ui_render_frame_hd(1280, 900, 2.0, 0.0));
    try std.testing.expectEqual(appScrollLimit(1280.0, 900.0), er_ui_app_scroll_y());
}

test "app runtime cursor intent owns hit and drag cursor policy" {
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

test "app runtime cursor is scene-drawn from runtime pointer state" {
    var local_commands: [16]ui.Command = undefined;
    const scene = ui.Scene.init(&local_commands);
    var local_pixels: [64]ui.Color = undefined;
    const surface = try renderer_pipeline.softwareFramebuffer(8, 8, &local_pixels);

    last_action_kind = @intFromEnum(ui_runtime.ActionKind.none);
    const regions = [_]interaction.Region{.{ .slot = 0, .kind = .button, .id = 4, .bounds = ui.Rect.init(0, 0, 8, 8) }};
    try std.testing.expectEqual(@as(u32, 0), finishCpuSceneFrame(surface, scene, &regions, .{ .enabled = true, .x = 4.0, .y = 4.0 }, .bg));
    try std.testing.expectEqual(@intFromEnum(CursorKind.pointer), er_ui_cursor_kind());
    try std.testing.expect(hasIconId(local_commands[0..last_command_count], icon_svg.cursor_hand_finger_icon_id));
}

test "app runtime pointer up owns activation suppression policy" {
    last_command_count = 0;
    try storeLastRegions(&.{.{ .slot = 0, .kind = .button, .id = app_chrome.blog_button_id, .bounds = ui.Rect.init(0, 0, 40, 40) }});

    app_state = .{};
    runtime_state = .{};
    defer app_state = .{};
    defer runtime_state = .{};

    _ = er_ui_pointer_down(8, 8);
    try std.testing.expectEqual(@intFromEnum(UiAction.none), er_ui_app_pointer_up(8, 8));
    try std.testing.expectEqual(app_blog.indexContentHeight(1280.0), er_ui_app_content_height(1280.0));

    var drag_commands: [2]ui.Command = undefined;
    var drag_scene = ui.Scene.init(&drag_commands);
    try drag_scene.pushDragSource(.{ .scope_id = 81, .item_id = 1, .index = 0, .bounds = ui.Rect.init(0, 0, 40, 40) });
    try drag_scene.pushDropTarget(.{ .scope_id = 81, .index = 2, .bounds = ui.Rect.init(0, 70, 40, 40) });
    last_command_count = drag_scene.written().len;
    @memcpy(commands[0..last_command_count], drag_scene.written());
    try storeLastRegions(&.{.{ .slot = 0, .kind = .button, .id = app_chrome.docs_button_id, .bounds = ui.Rect.init(0, 70, 40, 40) }});
    runtime_state = .{};
    app_state = .{};

    _ = er_ui_pointer_down(8, 8);
    _ = er_ui_pointer_move(8, 88);
    try std.testing.expectEqual(@intFromEnum(UiAction.none), er_ui_app_pointer_up(8, 88));
    try std.testing.expectEqual(app_landing.contentHeight(1280.0), er_ui_app_content_height(1280.0));
}

test "app packed text preserves variable font descenders" {
    font_atlas_ready = false;
    try ensureFontAtlas();
    try std.testing.expectEqual(@as(usize, 0), font_atlas.cachedGlyphCount());
    packed_text_vertex_float_len = 0;
    const bounds = ui.Rect.init(0, 0, 64, 14);
    try renderer_pipeline.pushText(packedBuffers(), packedSources().font, .base, bounds, "y", .text, .start);
    try std.testing.expect(packed_text_vertex_float_len > 0);
    try std.testing.expect(font_atlas.cachedGlyphCount() > 0);
    try std.testing.expect(font_atlas.cachedGlyphCount() < 8);

    var max_y: f32 = 0.0;
    var index: usize = 1;
    while (index < packed_text_vertex_float_len) : (index += packed_text_vertex_float_stride) {
        max_y = @max(max_y, packed_text_vertex_floats[index]);
    }
    try std.testing.expect(max_y > bounds.y + bounds.h);
}

test "app variable font atlas separates css size from raster scale" {
    font_atlas_ready = false;
    _ = er_ui_set_device_scale(2.0);
    try ensureFontAtlas();
    try std.testing.expectEqual(@as(usize, 0), font_atlas.cachedGlyphCount());
    const source_2x = packedSources().font;
    const glyph_2x = (try source_2x.glyph(source_2x.context, 'M', 14)).?;

    _ = er_ui_set_device_scale(3.0);
    try ensureFontAtlas();
    try std.testing.expectEqual(@as(usize, 0), font_atlas.cachedGlyphCount());
    const source_3x = packedSources().font;
    const glyph_3x = (try source_3x.glyph(source_3x.context, 'M', 14)).?;

    try std.testing.expect((glyph_3x.u1 - glyph_3x.u0) > (glyph_2x.u1 - glyph_2x.u0));
    try std.testing.expectApproxEqAbs(glyph_2x.w, glyph_3x.w, 1.5);
    try std.testing.expectApproxEqAbs(glyph_2x.advance, glyph_3x.advance, 0.75);
}

test "app hd browser frame keeps logical layout and physical pixels separate" {
    font_atlas_ready = false;
    const code = er_ui_render_frame_hd(320, 200, 2.0, 0.0);

    try std.testing.expectEqual(@as(u32, 0), code);
    try std.testing.expectEqual(@as(u32, 640), er_ui_width());
    try std.testing.expectEqual(@as(u32, 400), er_ui_height());
    try std.testing.expectEqual(@as(f32, 2.0), font_atlas.deviceScale());
}

test "app font atlas populates glyphs on demand" {
    font_atlas_ready = false;
    try ensureFontAtlas();
    try std.testing.expectEqual(@as(usize, 0), font_atlas.cachedGlyphCount());

    packed_text_vertex_float_len = 0;
    try renderer_pipeline.pushText(packedBuffers(), packedSources().font, .base, ui.Rect.init(0, 0, 160, 18), "EdgeRun", .text, .start);
    try std.testing.expect(packed_text_vertex_float_len > 0);
    try std.testing.expect(font_atlas.cachedGlyphCount() > 0);
    try std.testing.expect(font_atlas.cachedGlyphCount() < 16);
}

test "app icon buffer stores semantic icon instances" {
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

test "app render frame writes pixels for byte bridge" {
    const code = er_ui_render_frame(640, 480, 0.0);
    try std.testing.expectEqual(@as(u32, 0), code);
    try std.testing.expectEqual(renderer_pipeline.Transport.pixel_bytes, last_present_transport);
    try std.testing.expect(er_ui_pixels_ptr() != 0);
}
