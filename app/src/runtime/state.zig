const std = @import("std");
const math = @import("../math.zig");
const bytes = @import("../bytes.zig");
const web_host_js = @import("../web_host_js.zig");
const clock = @import("../clock.zig");
const source_object = @import("embedded_source_object").bytes;

const identity_core = @import("../identity.zig");
pub const interaction = @import("../ui/interaction.zig");
const object = @import("../object.zig");
pub const renderer_font_atlas = @import("../render/font_atlas_weighted.zig");
pub const renderer_ir = @import("../render/ir.zig");
pub const renderer_pipeline = @import("../render/pipeline.zig");
const gles_wasm = @import("../render/backends/gles_wasm.zig");
const wasm_gl = @import("../render/wasm_gl.zig");
const gl_contract = @import("../render/gl_contract.zig");
const component_gallery = @import("../component_gallery.zig");
const app_chrome = @import("../ui/chrome.zig");
const app_cursor = @import("../ui/cursor.zig");
const app_frame = @import("../route/frame.zig");
const app_images = @import("../app_images.zig");
const app_input_event = @import("../app_input_event.zig");
pub const app_native_input = @import("../input/native.zig");
pub const app_navigation = @import("../app_navigation.zig");
const component_union = @import("../ui/components/Component.zig");
const icon_component = @import("../ui/components/Icon.zig");
const node_renderer = @import("../ui/components/NodeRenderer.zig");
pub const ui = @import("../ui/core.zig");
const ui_codec = @import("../ui/codec.zig");
pub const ui_component_common = @import("../ui/component_common.zig");
const vfs = @import("../vfs.zig");
pub const ui_runtime = @import("../ui/runtime.zig");

pub const max_width: usize = 4096;
pub const max_height: usize = 2880;
pub const max_pixels: usize = max_width * max_height;
pub const max_input_bytes: usize = 8192;
pub const max_source_workspace_bytes: usize = 32 * 1024 * 1024;
pub const max_release_artifact_bytes: usize = 64 * 1024 * 1024;
pub const compiler_memory_offset_bytes: usize = 16 * 1024 * 1024;
pub const compiler_work_memory_bytes: usize = 288 * 1024 * 1024;
pub const compiler_source_gap_bytes: usize = 64 * 1024;
pub const max_compiler_runtime_bytes: usize = compiler_memory_offset_bytes + compiler_work_memory_bytes + compiler_source_gap_bytes + max_source_workspace_bytes;
pub const compiler_execution_tick_budget: u64 = 1_000_000_000;
pub const wasm_page_bytes: usize = 64 * 1024;
pub const workspace_manifest_header_bytes: usize = 16;
pub const default_source_editor_label = "src/er/self_host/main.er";
pub const max_source_editor_label_bytes: usize = 128;
pub const max_source_editor_bytes: usize = 512 * 1024;
pub const source_editor_tab = "    ";
pub const source_editor_page_lines: usize = 16;
pub const source_editor_visible_lines: usize = 32;
pub const source_editor_scroll_margin_lines: usize = 3;
pub const max_source_editor_undo_entries: usize = 8;
pub const max_source_file_entries: usize = 128;
pub const max_source_file_label_bytes: usize = 16 * 1024;
pub const max_source_search_bytes: usize = 128;
pub const source_editor_wheel_pixels_per_line: f32 = 36.0;
pub const max_compiler_diagnostic_bytes: usize = 192;
pub const max_source_compile_summary_bytes: usize = 192;
pub const max_nodes: usize = 256;
pub const max_commands: usize = 4096;
pub const max_interaction_regions: usize = 4096;
pub const packed_rect_float_stride: usize = renderer_pipeline.rect_float_stride;
pub const packed_icon_vertex_float_stride: usize = renderer_pipeline.icon_instance_float_stride;
pub const packed_icon_line_vertex_float_stride: usize = renderer_pipeline.icon_line_vertex_float_stride;
pub const packed_image_vertex_float_stride: usize = renderer_pipeline.image_vertex_float_stride;
pub const max_packed_rects: usize = 32768;
pub const max_packed_icon_vertices: usize = 16384;
pub const max_packed_icon_line_vertices: usize = 4194304;
pub const max_packed_image_vertices: usize = 384;
pub const max_packed_overlay_rects: usize = 512;
pub const max_packed_overlay_icon_vertices: usize = 1024;
pub const max_packed_overlay_icon_line_vertices: usize = 1048576;
pub const max_clips: usize = 64;
pub const focus_ring_outset: f32 = 3.0;
pub const focus_ring_radius: f32 = 8.0;
pub const font_atlas_width: usize = renderer_font_atlas.width;
pub const font_atlas_height: usize = renderer_font_atlas.height;
pub const min_device_scale: f32 = 1.0;
pub const default_device_scale: f32 = 1.0;
pub const max_device_scale: f32 = 4.0;
pub const app_source_url = "https://github.com/edgerun";
pub const route_bytes_capacity: usize = app_navigation.route_path_capacity;
pub const route_hash_bytes_capacity: usize = app_navigation.route_hash_capacity;
pub const outbox_capacity: usize = 4;
pub const title_text = "EdgeRun Academy";
pub const dom_surface_id = "edgerun-dom";
pub const boot_dom_html = "";
pub const release_artifact_filename = "edgerun-app.wasm";
pub const entropy_pool_size: usize = 32;
pub const ephemeral_seed_size: usize = std.crypto.sign.Ed25519.KeyPair.seed_length;
pub const public_identity_prefix = "er1:";
pub const public_identity_text_len: usize = public_identity_prefix.len + identity_core.id_size * 2;
pub const initial_entropy_pool = [_]u8{
    0x65, 0x64, 0x67, 0x65, 0x72, 0x75, 0x6e, 0x3a,
    0x77, 0x61, 0x73, 0x6d, 0x3a, 0x69, 0x64, 0x3a,
    0x63, 0x6c, 0x69, 0x63, 0x6b, 0x2d, 0x65, 0x6e,
    0x74, 0x72, 0x6f, 0x70, 0x79, 0x3a, 0x76, 0x31,
};

pub var pixels: [max_pixels]ui.Color = undefined;
pub var input_bytes: [max_input_bytes]u8 = undefined;
pub var source_workspace: [max_source_workspace_bytes]u8 = undefined;
pub var source_workspace_len: usize = 0;
pub var source_workspace_ready = false;
pub var source_editor_bytes: [max_source_editor_bytes]u8 = undefined;
pub var source_editor_len: usize = 0;
pub var source_editor_cursor: usize = 0;
pub var source_editor_preferred_column: usize = 0;
pub var source_editor_selection_anchor: usize = 0;
pub var source_editor_selection_active = false;
pub var source_editor_scroll_line: usize = 0;
pub var source_editor_loaded = false;
pub var source_editor_dirty = false;
pub var source_editor_status: SourceEditorStatus = .not_loaded;
pub var source_editor_label: []const u8 = default_source_editor_label;
pub var source_editor_label_bytes: [max_source_editor_label_bytes]u8 = undefined;
pub var source_editor_undo: [max_source_editor_undo_entries]SourceEditorSnapshot = undefined;
pub var source_editor_undo_len: usize = 0;
pub var source_editor_redo: [max_source_editor_undo_entries]SourceEditorSnapshot = undefined;
pub var source_editor_redo_len: usize = 0;
pub var source_file_entries: [max_source_file_entries]struct {} = .{struct {}} ** max_source_file_entries;
pub var source_file_label_bytes: [max_source_file_label_bytes]u8 = undefined;
pub var source_file_count: usize = 0;
pub var source_file_label_bytes_len: usize = 0;
pub var source_file_cache_workspace_len: usize = 0;
pub var source_search_bytes: [max_source_search_bytes]u8 = undefined;
pub var source_search_len: usize = 0;
pub var source_pointer_drag_select = false;
pub var context_menu_open = false;
pub var context_menu_x: f32 = 0.0;
pub var context_menu_y: f32 = 0.0;
pub var context_source_label: []const u8 = "";
pub var context_source_label_bytes: [max_source_editor_label_bytes]u8 = undefined;
pub var last_compiler_status: u32 = 0;
pub var last_compiler_diagnostic: [max_compiler_diagnostic_bytes]u8 = undefined;
pub var last_compiler_diagnostic_len: usize = 0;
pub var last_compile_phase: CompilePhase = .idle;
pub var last_compile_progress_permille: u32 = 0;
pub var last_compile_instructions: u64 = 0;
pub var last_compile_function_entries: u64 = 0;
pub var last_compile_memory_loads: u64 = 0;
pub var source_compile_summary: [max_source_compile_summary_bytes]u8 = undefined;
pub var source_compile_summary_len: usize = 0;
pub var release_artifact: [max_release_artifact_bytes]u8 = undefined;
pub var release_artifact_len: usize = 0;
pub var compiler_runtime_memory: [max_compiler_runtime_bytes]u8 align(16) = undefined;
pub var nodes: [max_nodes]ui.Node = undefined;
pub var commands: [max_commands]ui.Command = undefined;
pub var interaction_regions: [max_interaction_regions]interaction.Region = undefined;
pub var clips: [max_clips]ui.Rect = undefined;
pub var packed_rect_floats: [max_packed_rects * packed_rect_float_stride]f32 = undefined;
pub var packed_rect_float_len: usize = 0;
pub var packed_icon_vertex_floats: [max_packed_icon_vertices * packed_icon_vertex_float_stride]f32 = undefined;
pub var packed_icon_vertex_float_len: usize = 0;
pub var packed_icon_line_vertex_floats: [max_packed_icon_line_vertices * packed_icon_line_vertex_float_stride]f32 = undefined;
pub var packed_icon_line_vertex_float_len: usize = 0;
pub var packed_image_vertex_floats: [max_packed_image_vertices * packed_image_vertex_float_stride]f32 = undefined;
pub var packed_image_vertex_float_len: usize = 0;
pub var packed_overlay_rect_floats: [max_packed_overlay_rects * packed_rect_float_stride]f32 = undefined;
pub var packed_overlay_rect_float_len: usize = 0;
pub var packed_overlay_icon_vertex_floats: [max_packed_overlay_icon_vertices * packed_icon_vertex_float_stride]f32 = undefined;
pub var packed_overlay_icon_vertex_float_len: usize = 0;
pub var packed_overlay_icon_line_vertex_floats: [max_packed_overlay_icon_line_vertices * packed_icon_line_vertex_float_stride]f32 = undefined;
pub var packed_overlay_icon_line_vertex_float_len: usize = 0;
pub var font_atlas: renderer_font_atlas.Atlas = undefined;
pub var font_atlas_ready = false;
pub var font_device_scale: f32 = 1.0;

pub var frame_width: usize = 0;
pub var frame_height: usize = 0;
pub var last_command_count: usize = 0;
pub var last_region_count: usize = 0;
pub var last_present_primitive_count: usize = 0;
pub var last_present_transport: renderer_pipeline.Transport = .packed_buffers;
pub var last_error: ErrorCode = .ok;
pub var runtime_state = ui_runtime.State{};
pub var last_action_kind: u32 = @intFromEnum(ui_runtime.ActionKind.none);
pub var last_action_hit_id: u32 = 0;
pub var last_action_scope_id: u32 = 0;
pub var last_action_from_index: u32 = 0;
pub var last_action_to_index: u32 = 0;
pub var native_input_state: app_native_input.State = .{ .public_identity = "edgerun-wasm", .reveal_identity = "edgerun-wasm" };
pub var queued_action: UiAction = .none;
pub var route_bytes: [route_bytes_capacity]u8 = undefined;
pub var route_len: usize = 0;
pub var route_hash_bytes: [route_hash_bytes_capacity]u8 = undefined;
pub var route_hash_len: usize = 0;
pub var pointer_hover_x: f32 = -1.0;
pub var pointer_hover_y: f32 = -1.0;
pub var outbox_messages: [outbox_capacity]OutboxMessage = [_]OutboxMessage{.{}} ** outbox_capacity;
pub var outbox_message_len: usize = 0;
pub var next_outbox_message_id: u32 = 1;
pub var entropy_pool: [entropy_pool_size]u8 = initial_entropy_pool;
pub var entropy_event_count: u64 = 0;
pub var ephemeral_seed: [ephemeral_seed_size]u8 = [_]u8{0} ** ephemeral_seed_size;
pub var ephemeral_public_key: [identity_core.ed25519_public_size]u8 = [_]u8{0} ** identity_core.ed25519_public_size;
pub var ephemeral_identity_id: [identity_core.id_size]u8 = [_]u8{0} ** identity_core.id_size;
pub var public_identity_text: [public_identity_text_len]u8 = [_]u8{0} ** public_identity_text_len;
pub var ephemeral_identity_ready = false;
pub var environment_appearance: EnvironmentAppearance = .unknown;
pub var wasm_gl_state: ?gles_wasm.State = null;

pub const hover_hit_kind_none: u32 = 255;

pub const EnvironmentAppearance = enum(u32) {
    unknown = 0,
    light = 1,
    dark = 2,
};

pub const SourceEditorStatus = enum(u32) {
    not_loaded = 0,
    ready = 1,
    dirty = 2,
    missing_file = 3,
    corrupt_workspace = 4,
    editor_too_large = 5,
    workspace_full = 6,
};

pub const CompilePhase = enum(u32) {
    idle = 0,
    loading_workspace = 1,
    init_compiler = 2,
    compiling = 3,
    collecting_artifact = 4,
    complete = 5,
    failed = 6,
};

pub const UiAction = enum(u32) {
    none = 0,
    open_url = 1,
};

pub const OutboxKind = enum(u32) {
    none = 0,
    open_url = 1,
    push_route_hash = 2,
    set_title = 3,
    set_element_html = 4,
    download_wasm = 5,
    launch_wasm = 6,
};

pub const OutboxMessage = struct {
    kind: OutboxKind = .none,
    id: u32 = 0,
};

pub const input_event_prevent_default: u32 = 1 << 0;
pub const input_event_schedule_frame: u32 = 1 << 1;
pub const input_event_outbox: u32 = 1 << 3;
pub const input_event_capture_pointer: u32 = 1 << 4;
pub const input_event_release_pointer: u32 = 1 << 5;
pub const input_event_error: u32 = 1 << 8;

pub const CursorKind = app_cursor.Kind;

pub const AppView = app_navigation.View;
pub const InputEventKind = app_input_event.Kind;
pub const InputEventRecord = app_input_event.Record;
pub const input_event_flag_ctrl = app_input_event.flag_ctrl;
pub const input_event_record_kind_offset = app_input_event.kind_offset;

pub const SourceEditorSnapshot = struct {
    bytes: [max_source_editor_bytes]u8 = undefined,
    len: usize = 0,
    cursor: usize = 0,
    selection_anchor: usize = 0,
    selection_active: bool = false,
};

pub const ErrorCode = enum(u32) {
    ok = 0,
    bad_size = 1,
    bad_input = 2,
    bad_ui = 3,
    render_failed = 4,
    packed_budget = 5,
    font_atlas = 6,
    identity_failed = 7,
};

pub const HoverUpdate = struct {
    enabled: bool,
    x: f32 = 0.0,
    y: f32 = 0.0,
};

pub const EntropyEvent = enum(u8) {
    pointer_down = 1,
    pointer_move = 2,
    pointer_up = 3,
};
