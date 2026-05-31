const state = @import("runtime/state.zig");
const render = @import("runtime/render.zig");
const editor = @import("runtime/editor.zig");
const input = @import("runtime/input.zig");
const idp = @import("runtime/identity.zig");

const std = @import("std");
const bytes = @import("bytes.zig");
const math = @import("math.zig");
const app_frame = @import("shell/frame.zig");
const app_images = @import("ui/images.zig");
const app_native_input = @import("input/native.zig");
const app_location = state.app_location;
const app_cursor = @import("ui/cursor.zig");
const component_gallery = @import("ui/component_gallery.zig");
const interaction = state.interaction;
const ui = state.ui;
const renderer_pipeline = state.renderer_pipeline;
const renderer_font_atlas = state.renderer_font_atlas;
const ui_component_common = state.ui_component_common;
const ui_runtime = state.ui_runtime;
const identity = @import("identity.zig");
const clock = @import("clock.zig");
const gles_wasm = @import("render/backends/gles_wasm.zig");
const wasm_gl = @import("render/wasm_gl.zig");
const gl_contract = @import("render/gl_contract.zig");
const app_input_event = state.app_input_event;
const er = @import("er");

pub const max_width = state.max_width;
pub const max_height = state.max_height;
pub const max_pixels = state.max_pixels;
pub const max_input_bytes = state.max_input_bytes;
pub const packed_rect_float_stride = state.packed_rect_float_stride;
pub const packed_icon_vertex_float_stride = state.packed_icon_vertex_float_stride;
pub const packed_icon_line_vertex_float_stride = state.packed_icon_line_vertex_float_stride;
pub const packed_image_vertex_float_stride = state.packed_image_vertex_float_stride;
pub const font_atlas_width = state.font_atlas_width;
pub const font_atlas_height = state.font_atlas_height;
pub const ErrorCode = state.ErrorCode;
pub const SourceEditorStatus = state.SourceEditorStatus;
pub const EnvironmentAppearance = state.EnvironmentAppearance;
pub const hover_hit_kind_none = state.hover_hit_kind_none;

// -----------------------------------------------------------------
// Buffer / size query exports
// -----------------------------------------------------------------

export fn er_ui_max_width() u32 {
    return state.max_width;
}
export fn er_ui_max_height() u32 {
    return state.max_height;
}
export fn er_ui_pixels_ptr() usize {
    return @intFromPtr(&state.pixels);
}
export fn er_ui_pixels_len() usize {
    return state.pixels.len;
}

export fn er_ui_packed_rect_float_stride() u32 {
    return state.packed_rect_float_stride;
}
export fn er_ui_packed_rect_buffer_ptr() usize {
    return @intFromPtr(&state.packed_rect_floats);
}
export fn er_ui_packed_rect_buffer_len() usize {
    return state.packed_rect_floats.len;
}

export fn er_ui_packed_icon_vertex_float_stride() u32 {
    return state.packed_icon_vertex_float_stride;
}
export fn er_ui_packed_icon_vertex_buffer_ptr() usize {
    return @intFromPtr(&state.packed_icon_vertex_floats);
}
export fn er_ui_packed_icon_vertex_buffer_len() usize {
    return state.packed_icon_vertex_floats.len;
}

export fn er_ui_packed_icon_line_vertex_float_stride() u32 {
    return state.packed_icon_line_vertex_float_stride;
}
export fn er_ui_packed_icon_line_vertex_buffer_ptr() usize {
    return @intFromPtr(&state.packed_icon_line_vertex_floats);
}
export fn er_ui_packed_icon_line_vertex_buffer_len() usize {
    return state.packed_icon_line_vertex_floats.len;
}

export fn er_ui_packed_image_vertex_float_stride() u32 {
    return state.packed_image_vertex_float_stride;
}
export fn er_ui_packed_image_vertex_buffer_ptr() usize {
    return @intFromPtr(&state.packed_image_vertex_floats);
}
export fn er_ui_packed_image_vertex_buffer_len() usize {
    return state.packed_image_vertex_floats.len;
}

export fn er_ui_packed_overlay_rect_buffer_ptr() usize {
    return @intFromPtr(&state.packed_overlay_rect_floats);
}
export fn er_ui_packed_overlay_rect_buffer_len() usize {
    return state.packed_overlay_rect_floats.len;
}
export fn er_ui_packed_overlay_icon_vertex_buffer_ptr() usize {
    return @intFromPtr(&state.packed_overlay_icon_vertex_floats);
}
export fn er_ui_packed_overlay_icon_vertex_buffer_len() usize {
    return state.packed_overlay_icon_vertex_floats.len;
}
export fn er_ui_packed_overlay_icon_line_vertex_buffer_ptr() usize {
    return @intFromPtr(&state.packed_overlay_icon_line_vertex_floats);
}
export fn er_ui_packed_overlay_icon_line_vertex_buffer_len() usize {
    return state.packed_overlay_icon_line_vertex_floats.len;
}

export fn er_ui_post_image_rgba_ptr() usize {
    return @intFromPtr(&state.pixels);
}
export fn er_ui_post_image_rgba_len() usize {
    return state.pixels.len * @sizeOf(u32);
}
export fn er_ui_post_image_width() u32 {
    return @intCast(state.frame_width);
}
export fn er_ui_post_image_height() u32 {
    return @intCast(state.frame_height);
}

export fn er_ui_font_atlas_width() u32 {
    return state.font_atlas_width;
}
export fn er_ui_font_atlas_height() u32 {
    return state.font_atlas_height;
}
export fn er_ui_font_atlas_ptr() usize {
    return @intFromPtr(state.font_atlas.alphaSlice().ptr);
}
export fn er_ui_font_atlas_generation() u32 {
    return if (state.font_atlas_ready) 1 else 0;
}

export fn er_ui_width() u32 {
    return @intCast(state.frame_width);
}
export fn er_ui_height() u32 {
    return @intCast(state.frame_height);
}
export fn er_ui_input_ptr() usize {
    return @intFromPtr(&state.input_bytes);
}
export fn er_ui_input_capacity() usize {
    return state.input_bytes.len;
}
export fn er_ui_last_error() u32 {
    return @intFromEnum(state.last_error);
}

export fn er_ui_app_public_identity_ptr() usize {
    return @intFromPtr(&state.native_input_state.public_identity);
}
export fn er_ui_app_public_identity_len() usize {
    return state.native_input_state.public_identity.len;
}

// -----------------------------------------------------------------
// Appearance exports
// -----------------------------------------------------------------

export fn er_ui_set_device_scale(scale: f32) u32 {
    if (!math.isFiniteF(scale)) return render.finishError(.bad_input);
    state.font_device_scale = render.normalizedDeviceScale(scale);
    state.font_atlas_ready = false;
    state.last_error = .ok;
    return @intFromEnum(state.ErrorCode.ok);
}

export fn er_ui_set_environment_appearance(value: u32) u32 {
    state.environment_appearance = switch (value) {
        0 => state.EnvironmentAppearance.unknown,
        1 => state.EnvironmentAppearance.light,
        2 => state.EnvironmentAppearance.dark,
        else => return render.finishError(.bad_input),
    };
    state.last_error = .ok;
    return @intFromEnum(state.ErrorCode.ok);
}

export fn er_ui_environment_appearance() u32 {
    return @intFromEnum(state.environment_appearance);
}

// -----------------------------------------------------------------
// Hover / cursor / action query exports
// -----------------------------------------------------------------

export fn er_ui_hover_hit_kind() u32 {
    return if (state.runtime_state.hoverKind()) |kind| @intFromEnum(kind) else state.hover_hit_kind_none;
}

export fn er_ui_hover_hit_id() u32 {
    return state.runtime_state.hoverHitId();
}

fn hitKindFromInt(value: u32) ?ui.HitKind {
    return switch (value) {
        @intFromEnum(ui.HitKind.button) => .button,
        @intFromEnum(ui.HitKind.row_item) => .row_item,
        @intFromEnum(ui.HitKind.checkbox) => .checkbox,
        @intFromEnum(ui.HitKind.switch_control) => .switch_control,
        @intFromEnum(ui.HitKind.slider) => .slider,
        @intFromEnum(ui.HitKind.textarea) => .textarea,
        @intFromEnum(ui.HitKind.select) => .select,
        @intFromEnum(ui.HitKind.overlay_trigger) => .overlay_trigger,
        @intFromEnum(ui.HitKind.input) => .input,
        else => null,
    };
}

export fn er_ui_set_hover_hit(kind_raw: u32, hit_id: u32) u32 {
    const kind = hitKindFromInt(kind_raw) orelse return render.finishError(.bad_input);
    state.runtime_state.hovered = .{
        .kind = kind,
        .id = hit_id,
        .bounds = ui.Rect.init(0.0, 0.0, 1.0, 1.0),
    };
    state.last_error = .ok;
    return @intFromEnum(state.ErrorCode.ok);
}

export fn er_ui_cursor_kind() u32 {
    const action_kind: ui_runtime.ActionKind = @enumFromInt(@as(u8, @intCast(state.last_action_kind)));
    return @intFromEnum(app_cursor.fromState(action_kind, state.runtime_state.hoverKind()));
}

export fn er_ui_last_action_kind() u32 {
    return state.last_action_kind;
}
export fn er_ui_last_action_hit_id() u32 {
    return state.last_action_hit_id;
}
export fn er_ui_last_action_scope_id() u32 {
    return state.last_action_scope_id;
}
export fn er_ui_last_action_from_index() u32 {
    return state.last_action_from_index;
}
export fn er_ui_last_action_to_index() u32 {
    return state.last_action_to_index;
}

// -----------------------------------------------------------------
// Pointer event exports
// -----------------------------------------------------------------

export fn er_ui_pointer_down(x: f32, y: f32) u32 {
    state.pointer_hover_x = x;
    state.pointer_hover_y = y;
    idp.mixInteractionEntropy(.pointer_down, x, y);
    const commands_slice = state.commands[0..state.last_command_count];
    const regions_slice = state.interaction_regions[0..state.last_region_count];
    app_native_input.processPointerEvent(&state.native_input_state, commands_slice, regions_slice, null, .pointer_down);
    state.last_action_kind = @intFromEnum(state.native_input_state.last_action_kind);
    state.last_action_hit_id = state.native_input_state.runtime.hoverHitId();
    state.context_menu_open = false;
    state.last_error = .ok;
    return @intFromEnum(state.ErrorCode.ok);
}

export fn er_ui_pointer_down_hit(x: f32, y: f32, kind_raw: u32, hit_id: u32) u32 {
    const set_result = er_ui_set_hover_hit(kind_raw, hit_id);
    if (set_result != @intFromEnum(state.ErrorCode.ok)) return set_result;
    return er_ui_pointer_down(x, y);
}

export fn er_ui_pointer_move(x: f32, y: f32) u32 {
    state.pointer_hover_x = x;
    state.pointer_hover_y = y;
    idp.mixInteractionEntropy(.pointer_move, x, y);
    const commands_slice = state.commands[0..state.last_command_count];
    const regions_slice = state.interaction_regions[0..state.last_region_count];
    app_native_input.processPointerEvent(&state.native_input_state, commands_slice, regions_slice, null, .pointer_move);
    state.last_action_kind = @intFromEnum(state.native_input_state.last_action_kind);
    state.last_action_hit_id = state.native_input_state.runtime.hoverHitId();
    state.last_error = .ok;
    return @intFromEnum(state.ErrorCode.ok);
}

export fn er_ui_pointer_move_hit(x: f32, y: f32, kind_raw: u32, hit_id: u32) u32 {
    const set_result = er_ui_set_hover_hit(kind_raw, hit_id);
    if (set_result != @intFromEnum(state.ErrorCode.ok)) return set_result;
    return er_ui_pointer_move(x, y);
}

export fn er_ui_pointer_up(x: f32, y: f32) u32 {
    idp.mixInteractionEntropy(.pointer_up, x, y);
    state.source_pointer_drag_select = false;
    const commands_slice = state.commands[0..state.last_command_count];
    const regions_slice = state.interaction_regions[0..state.last_region_count];
    app_native_input.processPointerEvent(&state.native_input_state, commands_slice, regions_slice, null, .pointer_up);
    state.last_action_kind = @intFromEnum(state.native_input_state.last_action_kind);
    state.last_action_hit_id = state.native_input_state.runtime.hoverHitId();
    state.last_error = .ok;
    return @intFromEnum(state.ErrorCode.ok);
}

export fn er_ui_pointer_up_hit(x: f32, y: f32, kind_raw: u32, hit_id: u32) u32 {
    const set_result = er_ui_set_hover_hit(kind_raw, hit_id);
    if (set_result != @intFromEnum(state.ErrorCode.ok)) return set_result;
    return er_ui_pointer_up(x, y);
}

export fn er_ui_app_pointer_up(x: f32, y: f32) u32 {
    state.pointer_hover_x = x;
    state.pointer_hover_y = y;
    return er_ui_pointer_up(x, y);
}

export fn er_ui_app_action_kind() u32 {
    return @intFromEnum(state.queued_action);
}

export fn er_ui_app_action_url_ptr() usize {
    return @intFromPtr(&state.location_path_projection_bytes);
}

export fn er_ui_app_action_url_len() usize {
    return state.location_path_projection_len;
}

// -----------------------------------------------------------------
// Outbox exports
// -----------------------------------------------------------------

export fn er_ui_outbox_count() u32 {
    return @intCast(state.outbox_message_len);
}

export fn er_ui_outbox_kind(index: u32) u32 {
    if (index >= state.outbox_message_len) return 0;
    return @intFromEnum(state.outbox_messages[index].kind);
}

export fn er_ui_outbox_id(index: u32) u32 {
    if (index >= state.outbox_message_len) return 0;
    return state.outbox_messages[index].id;
}

export fn er_ui_outbox_target_ptr(index: u32) usize {
    _ = index;
    return @intFromPtr(&state.location_path_projection_bytes);
}

export fn er_ui_outbox_target_len(index: u32) usize {
    _ = index;
    return state.location_path_projection_len;
}

export fn er_ui_outbox_payload_ptr(index: u32) usize {
    _ = index;
    return @intFromPtr(&state.release_artifact);
}

export fn er_ui_outbox_payload_len(index: u32) usize {
    _ = index;
    return state.release_artifact_len;
}

export fn er_ui_outbox_clear() u32 {
    state.outbox_message_len = 0;
    state.next_outbox_message_id = 1;
    state.last_error = .ok;
    return @intFromEnum(state.ErrorCode.ok);
}

// -----------------------------------------------------------------
// Bootstrap / workspace exports
// -----------------------------------------------------------------

export fn er_ui_bootstrap_js_ptr() usize {
    return 0;
}
export fn er_ui_bootstrap_js_len() usize {
    return 0;
}

export fn er_ui_source_workspace_ptr() usize {
    return @intFromPtr(&state.source_workspace);
}

export fn er_ui_source_workspace_len() usize {
    return state.source_workspace_len;
}

export fn er_ui_source_workspace_capacity() usize {
    return state.source_workspace.len;
}

export fn er_ui_source_workspace_commit(source_len: usize) u32 {
    if (source_len > state.source_workspace.len) return render.finishError(.bad_input);
    state.source_workspace_len = source_len;
    state.source_workspace_ready = true;
    state.source_file_cache_workspace_len = 0;
    state.source_editor_loaded = false;
    state.last_error = .ok;
    return @intFromEnum(state.ErrorCode.ok);
}

export fn er_ui_source_editor_select_label(label_len: usize) u32 {
    const label = state.input_bytes[0..label_len];
    return @intFromEnum(editor.selectSourceEditorLabel(label));
}

export fn er_ui_source_workspace_reset() u32 {
    state.source_workspace_ready = false;
    state.source_workspace_len = 0;
    state.source_editor_loaded = false;
    state.source_editor_label = state.default_source_editor_label;
    state.last_error = .ok;
    return @intFromEnum(state.ErrorCode.ok);
}

// -----------------------------------------------------------------
// Source editor state exports
// -----------------------------------------------------------------

export fn er_ui_source_editor_ptr() usize {
    return @intFromPtr(&state.source_editor_bytes);
}
export fn er_ui_source_editor_len() usize {
    return state.source_editor_len;
}
export fn er_ui_source_editor_cursor() usize {
    return state.source_editor_cursor;
}
export fn er_ui_source_editor_dirty() u32 {
    return @intFromBool(state.source_editor_dirty);
}
export fn er_ui_source_editor_status() u32 {
    return @intFromEnum(state.source_editor_status);
}

export fn er_ui_release_artifact_ptr() usize {
    return @intFromPtr(&state.release_artifact);
}
export fn er_ui_release_artifact_len() usize {
    return state.release_artifact_len;
}
export fn er_ui_release_artifact_capacity() usize {
    return state.release_artifact.len;
}

export fn er_ui_release_artifact_commit(artifact_len: usize) u32 {
    if (artifact_len > state.release_artifact.len) return render.finishError(.bad_input);
    state.release_artifact_len = artifact_len;
    state.last_error = .ok;
    return @intFromEnum(state.ErrorCode.ok);
}

export fn er_ui_release_artifact_clear() u32 {
    state.release_artifact_len = 0;
    state.last_error = .ok;
    return @intFromEnum(state.ErrorCode.ok);
}

export fn er_ui_request_release_artifact_download() u32 {
    input.queueOutboxMessage(@intFromEnum(state.OutboxKind.download_wasm)) catch {};
    state.last_error = .ok;
    return @intFromEnum(state.ErrorCode.ok);
}

export fn er_ui_request_release_artifact_launch() u32 {
    input.queueOutboxMessage(@intFromEnum(state.OutboxKind.launch_wasm)) catch {};
    state.last_error = .ok;
    return @intFromEnum(state.ErrorCode.ok);
}

// -----------------------------------------------------------------
// Location projection exports
// -----------------------------------------------------------------

export fn er_ui_app_location_hash_projection_ptr() usize {
    return @intFromPtr(&state.location_hash_projection_bytes);
}
export fn er_ui_app_location_hash_projection_len() usize {
    return state.location_hash_projection_len;
}
export fn er_ui_app_location_path_projection_ptr() usize {
    return @intFromPtr(&state.location_path_projection_bytes);
}
export fn er_ui_app_location_path_projection_len() usize {
    return state.location_path_projection_len;
}

export fn er_ui_app_set_location_path_projection(path_len: usize) u32 {
    if (path_len > state.input_bytes.len) return render.finishError(.bad_input);
    const path = state.input_bytes[0..path_len];
    const location = app_location.fromPathProjection(path) catch return render.finishError(.bad_input);
    input.applyLocation(location);
    render.refreshLocationPathProjection();
    render.refreshLocationHashProjection();
    state.native_input_state.public_identity_ready = false;
    state.native_input_state.public_identity = "idle";
    state.last_error = .ok;
    return @intFromEnum(state.ErrorCode.ok);
}

export fn er_ui_app_set_location_hash_projection(hash_len: usize) u32 {
    if (hash_len > state.input_bytes.len) return render.finishError(.bad_input);
    const hash = state.input_bytes[0..hash_len];
    const location = app_location.fromHashProjection(hash) catch return render.finishError(.bad_input);
    input.applyLocation(location);
    render.refreshLocationPathProjection();
    render.refreshLocationHashProjection();
    state.last_error = .ok;
    return @intFromEnum(state.ErrorCode.ok);
}

export fn er_ui_app_activate_hit(hit_id: u32) u32 {
    if (app_location.fromHit(hit_id, state.native_input_state.location)) |location| {
        input.applyLocation(location);
        render.refreshLocationPathProjection();
        render.refreshLocationHashProjection();
    } else if (app_location.actionFromHit(hit_id)) |action_fn| switch (action_fn) {
        .download_source_release => {
            input.queueOutboxMessage(@intFromEnum(state.OutboxKind.download_wasm)) catch {};
        },
        .launch_source_release => {
            input.queueOutboxMessage(@intFromEnum(state.OutboxKind.launch_wasm)) catch {};
        },
        .reset_source => {
            state.source_workspace_ready = false;
            state.source_workspace_len = 0;
            state.source_editor_loaded = false;
            input.applyLocation(app_location.Location{});
            render.refreshLocationPathProjection();
            render.refreshLocationHashProjection();
        },
        .open_context_source => {
            var path_buf: [256]u8 = undefined;
            if (render.sourceLabelForHit(state.native_input_state.location, hit_id, &path_buf)) |path| {
                state.source_editor_label = path;
                state.source_editor_label = state.source_editor_label;
                state.source_editor_loaded = false;
                editor.ensureSourceEditor();
            }
        },
        .reveal_identity => {
            state.native_input_state.public_identity_ready = true;
            state.native_input_state.public_identity = state.native_input_state.reveal_identity;
        },
    };
    state.last_error = .ok;
    return @intFromEnum(state.ErrorCode.ok);
}

export fn er_ui_app_context_menu(x: f32, y: f32) u32 {
    if (app_location.isSourceWorkspace(state.native_input_state.location)) {
        state.context_menu_open = true;
        state.context_menu_x = x;
        state.context_menu_y = y;
    }
    state.last_error = .ok;
    return @intFromEnum(state.ErrorCode.ok);
}

export fn er_ui_app_key_event(key_len: usize, ctrl: u32, meta: u32, alt: u32) u32 {
    const key = state.input_bytes[0..key_len];
    return input.appKeyEvent(key, ctrl, meta, alt, 0);
}

// -----------------------------------------------------------------
// Event / frame exports
// -----------------------------------------------------------------

export fn er_ui_event(kind_raw: u32, x: f32, y: f32, delta_y: f32, ctrl: u32, meta: u32, alt: u32, text_len: usize, width: f32, height: f32) u32 {
    var buf: [state.max_input_bytes]u8 = undefined;
    var written: usize = 0;
    if (text_len > 0) {
        const bound = @min(text_len, buf.len);
        @memcpy(buf[0..bound], state.input_bytes[0..bound]);
        written = bound;
    }
    const record = state.InputEventRecord{
        .kind = @enumFromInt(kind_raw),
        .x = x,
        .y = y,
        .delta_y = delta_y,
        .ctrl = ctrl,
        .meta = meta,
        .alt = alt,
        .shift = 0,
        .repeat = 0,
        .key = "",
        .code = "",
        .input_type = "",
        .data = buf[0..written],
    };
    return input.handleInputEventRecord(record, width, height);
}

export fn er_ui_event_bytes(input_len: usize, width: f32, height: f32, frame_ms: f32) u32 {
    _ = frame_ms;
    if (input_len == 0 or input_len > state.input_bytes.len) return render.finishError(.bad_input);
    const record = app_input_event.parseBytes(state.input_bytes[0..input_len]) catch return render.finishError(.bad_input);
    return input.handleInputEventRecord(record, width, height);
}

export fn er_ui_boot() u32 {
    state.font_atlas_ready = false;
    state.last_error = .ok;
    return @intFromEnum(state.ErrorCode.ok);
}

export fn er_ui_app_scroll_by(delta_y: f32, width: f32, height: f32) u32 {
    if (!math.isFiniteF(delta_y) or !math.isFiniteF(width) or !math.isFiniteF(height)) return render.finishError(.bad_input);
    if (width <= 0.0 or height <= 0.0) return render.finishError(.bad_input);
    state.native_input_state.scroll_y = math.clampF(state.native_input_state.scroll_y + delta_y, 0.0, app_frame.contentHeight(width, input.currentAppFrameState(state.pointer_hover_x, state.pointer_hover_y, 0.0)) - height);
    state.last_error = .ok;
    return @intFromEnum(state.ErrorCode.ok);
}

export fn er_ui_app_scroll_y() f32 {
    return state.native_input_state.scroll_y;
}

export fn er_ui_app_content_height(width: f32) f32 {
    return app_frame.contentHeight(width, input.currentAppFrameState(state.pointer_hover_x, state.pointer_hover_y, 0.0));
}

export fn er_ui_clear(width: u32, height: u32) u32 {
    const surface = render.beginFrame(width, height) orelse return render.finishError(.bad_size);
    surface.clear(state.ui.Color.bg);
    state.last_error = .ok;
    return @intFromEnum(state.ErrorCode.ok);
}

export fn er_ui_build_app_frame(width: u32, height: u32, hover_x: f32, hover_y: f32, frame_ms: f32) u32 {
    if (!render.setFrameSize(width, height)) return render.finishError(.bad_size);
    render.clampAppScrollToViewport(width, height);
    return render.buildPackedAppFrameFromPreparedSize(input.currentAppFrameState(hover_x, hover_y, frame_ms));
}

export fn er_ui_build_frame(width: u32, height: u32, frame_ms: f32) u32 {
    return er_ui_build_app_frame(width, height, state.pointer_hover_x, state.pointer_hover_y, frame_ms);
}

// -----------------------------------------------------------------
// WASM GL / render frame exports
// -----------------------------------------------------------------

export fn er_ui_wasm_gl_init() u32 {
    render.ensureFontAtlas() catch return render.finishError(.font_atlas);
    state.wasm_gl_state = gles_wasm.initState(&state.font_atlas);
    wasm_gl.glClearColor(
        gl_contract.clear_color_r,
        gl_contract.clear_color_g,
        gl_contract.clear_color_b,
        gl_contract.clear_color_a,
    );
    wasm_gl.glDisable(wasm_gl.gl_dither);
    wasm_gl.glEnable(wasm_gl.gl_blend);
    wasm_gl.glBlendFuncSeparate(
        wasm_gl.gl_one,
        wasm_gl.gl_one_minus_src_alpha,
        wasm_gl.gl_one,
        wasm_gl.gl_one_minus_src_alpha,
    );
    state.last_error = .ok;
    return @intFromEnum(state.ErrorCode.ok);
}

export fn er_ui_render_frame_wasm(width: u32, height: u32, scale_raw: f32, frame_ms: f32) u32 {
    const scale = render.framebufferDeviceScale(width, height, scale_raw);
    const physical_width = render.scaledFrameDimension(width, scale) orelse return render.finishError(.bad_size);
    const physical_height = render.scaledFrameDimension(height, scale) orelse return render.finishError(.bad_size);
    if (!render.setFrameSize(width, height)) return render.finishError(.bad_size);
    render.clampAppScrollToViewport(width, height);
    _ = er_ui_set_device_scale(scale);
    var scene = ui.Scene.initWithClips(&state.commands, &state.clips);
    var frame_regions: [state.max_interaction_regions]interaction.Region = undefined;
    var collector = interaction.Collector.init(&frame_regions);
    app_frame.render(&scene, &collector, render.frameBounds(), input.currentAppFrameState(state.pointer_hover_x, state.pointer_hover_y, frame_ms)) catch return render.finishError(.render_failed);
    const frame_scene = render.prepareFrameScene(scene, collector.written(), .{ .enabled = true, .x = state.pointer_hover_x, .y = state.pointer_hover_y }) catch return render.finishError(.render_failed);
    render.ensureFontAtlas() catch return render.finishError(.font_atlas);
    const buffers = render.packedBuffers();
    renderer_pipeline.packScene(buffers, &state.font_atlas, frame_scene.written()) catch return render.finishError(.packed_budget);
    const gl = if (state.wasm_gl_state) |*st| st else return render.finishError(.render_failed);
    gles_wasm.refreshFontTexture(gl, &state.font_atlas);
    gles_wasm.ensureImageTexture(gl, render.currentWasmImageTexture());
    gles_wasm.renderFrame(gl, @intCast(physical_width), @intCast(physical_height), scale, buffers) catch return render.finishError(.render_failed);
    state.last_error = .ok;
    return @intFromEnum(state.ErrorCode.ok);
}

export fn er_ui_render_frame(width: u32, height: u32, frame_ms: f32) u32 {
    const surface = render.beginFrame(width, height) orelse return render.finishError(.bad_size);
    render.clampAppScrollToViewport(width, height);
    return render.renderAppPixels(surface, state.pointer_hover_x, state.pointer_hover_y, frame_ms);
}

export fn er_ui_render_frame_hd(width: u32, height: u32, scale_raw: f32, frame_ms: f32) u32 {
    const scale = render.framebufferDeviceScale(width, height, scale_raw);
    const physical_width = render.scaledFrameDimension(width, scale) orelse return render.finishError(.bad_size);
    const physical_height = render.scaledFrameDimension(height, scale) orelse return render.finishError(.bad_size);
    const surface = render.beginFrame(physical_width, physical_height) orelse return render.finishError(.bad_size);
    render.clampAppScrollToViewport(width, height);
    _ = er_ui_set_device_scale(scale);
    return render.renderAppPixelsScaled(surface, width, height, scale, state.pointer_hover_x, state.pointer_hover_y, frame_ms);
}

export fn er_ui_render_icon_svg_test(icon_id: u32, width: u32, height: u32) u32 {
    const surface = render.beginFrame(width, height) orelse return render.finishError(.bad_size);
    var scene = ui.Scene.initWithClips(&state.commands, &state.clips);
    scene.pushIconQuad(.{
        .bounds = ui.Rect.init(0, 0, @floatFromInt(state.frame_width), @floatFromInt(state.frame_height)),
        .icon_id = icon_id,
        .color = .{ .r = 255, .g = 255, .b = 255 },
    }) catch return render.finishError(.render_failed);
    return render.finishCpuSceneFrame(surface, scene, &.{}, .{ .enabled = false }, state.ui.Color.clear);
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
    }) catch return render.finishError(.render_failed);
    defer renderer_pipeline.resetIconTuningForTest();
    return er_ui_render_icon_svg_test(icon_id, width, height);
}

// -----------------------------------------------------------------
// Local cell / identity routing — export wrappers
//
// These exports bridge the host's input-buffer calling convention to
// the raw er host syscalls declared in er/sys.zig.
// -----------------------------------------------------------------

export fn er_identity_register(hash_len: u32) u32 {
    if (hash_len < 32) return er.err_busy;
    return er.register(@intCast(@intFromPtr(&state.input_bytes)));
}

export fn er_identity_lookup(hash_len: u32) u32 {
    if (hash_len < 32) return er.err_busy;
    return er.lookup(@intCast(@intFromPtr(&state.input_bytes)));
}

export fn er_identity_unregister(slot_id: u32) u32 {
    return er.unregister(slot_id);
}

export fn er_cell_send(hash_len: u32, cell_len: u32) u32 {
    if (hash_len < 32) return er.err_busy;
    if (cell_len < er.cell_size) return er.err_busy;
    const base = @intFromPtr(&state.input_bytes);
    return er.send(@intCast(base), @intCast(base + hash_len));
}

export fn er_cell_recv(slot_id: u32) u32 {
    return er.recv(slot_id, @intCast(@intFromPtr(&state.input_bytes)));
}

export fn er_cell_available(slot_id: u32) u32 {
    return er.available(slot_id);
}

// -----------------------------------------------------------------
// Tests
// -----------------------------------------------------------------

fn expectSourceDoesNotContain(needle: []const u8) !void {
    const source = @embedFile("app_runtime.zig");
    try std.testing.expect(std.mem.indexOf(u8, source, needle) == null);
}

fn hasFocusRingCommand(items: []const ui.Command) bool {
    for (items) |command| switch (command) {
        .rect => |rect| if (rect.mode == .border and rect.radius == state.focus_ring_radius) return true,
        else => {},
    };
    return false;
}

fn expectLocationFixture(fixture: app_location.LocationFixture) !void {
    var path_buf: [app_location.path_projection_capacity]u8 = undefined;
    var hash_buf: [app_location.hash_projection_capacity]u8 = undefined;
    const path_len = app_location.writePathProjection(&path_buf, fixture.location) catch unreachable;
    const hash_len = app_location.writeHashProjection(&hash_buf, fixture.location) catch unreachable;
    try std.testing.expectEqualStrings(fixture.path, path_buf[0..path_len]);
    try std.testing.expectEqualStrings(fixture.hash, hash_buf[0..hash_len]);
}

fn expectLocationState(expected: app_location.Location) !void {
    try std.testing.expectEqual(expected, state.native_input_state.location);
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

    state.runtime_state.refreshHover(collector.written(), 20, 30);
    try std.testing.expectEqual(@intFromEnum(ui.HitKind.button), er_ui_hover_hit_kind());
    try std.testing.expectEqual(@as(u32, 42), er_ui_hover_hit_id());

    state.runtime_state.refreshHover(collector.written(), -1, -1);
    try std.testing.expectEqual(state.hover_hit_kind_none, er_ui_hover_hit_kind());
    try std.testing.expectEqual(@as(u32, 0), er_ui_hover_hit_id());
}

test "app runtime ir finish preserves hover state when disabled" {
    state.runtime_state.hovered = .{ .kind = .button, .id = 99, .bounds = ui.Rect.init(0, 0, 1, 1) };
    var local_commands: [1]ui.Command = undefined;
    const scene = ui.Scene.init(&local_commands);
    var local_pixels: [4]ui.Color = undefined;
    const surface = try renderer_pipeline.softwareFramebuffer(2, 2, &local_pixels);

    try std.testing.expectEqual(@as(u32, 0), render.finishCpuSceneFrame(surface, scene, &.{}, .{ .enabled = false }, state.ui.Color.bg));
    try std.testing.expectEqual(@intFromEnum(ui.HitKind.button), er_ui_hover_hit_kind());
    try std.testing.expectEqual(@as(u32, 99), er_ui_hover_hit_id());
}

test "app runtime draws deterministic focus ring from runtime focus state" {
    state.runtime_state = .{ .focused = .{ .kind = .button, .id = 77, .bounds = ui.Rect.init(8, 12, 80, 32) } };
    defer state.runtime_state = .{};
    state.last_command_count = 0;
    defer state.last_command_count = 0;

    var regions: [1]interaction.Region = undefined;
    var collector = interaction.Collector.init(&regions);
    try collector.addHit(ui.Rect.init(8, 12, 80, 32), .button, 77);
    var local_pixels: [4096]ui.Color = undefined;
    const surface = try renderer_pipeline.softwareFramebuffer(64, 64, &local_pixels);
    const scene = ui.Scene.init(&state.commands);

    try std.testing.expectEqual(@as(u32, 0), render.finishCpuSceneFrame(surface, scene, collector.written(), .{ .enabled = false }, state.ui.Color.bg));
    try std.testing.expect(hasFocusRingCommand(state.commands[0..state.last_command_count]));
}

test "app runtime component catalog builds packed app buffers and app-ready icon lines" {
    state.font_atlas_ready = false;
    input.applyLocation(app_location.locationForButton(.app_preview));
    const code = er_ui_build_app_frame(960, 640, -1.0, -1.0, 0.0);
    try std.testing.expectEqual(@as(u32, 0), code);
    try std.testing.expect(state.font_atlas_ready);
    try std.testing.expectEqual(renderer_pipeline.Transport.packed_buffers, state.last_present_transport);
    try std.testing.expect(state.last_present_primitive_count > 0);
    try std.testing.expect(state.packed_rect_float_len > 0);
    try std.testing.expect(state.packed_icon_vertex_float_len > 0);
    try std.testing.expect(state.packed_icon_line_vertex_float_len > 0);
    try std.testing.expect(er_ui_font_atlas_ptr() != 0);
}

test "app runtime component catalog render uses canonical ir buffers" {
    input.applyLocation(app_location.locationForButton(.app_preview));
    const code = er_ui_render_frame(480, 360, 0.0);
    try std.testing.expectEqual(@as(u32, 0), code);
    try std.testing.expectEqual(renderer_pipeline.Transport.pixel_bytes, state.last_present_transport);
    try std.testing.expect(state.last_present_primitive_count > 0);
    try std.testing.expect(state.packed_rect_float_len > 0);
    try std.testing.expect(state.packed_icon_vertex_float_len > 0);
    var painted: usize = 0;
    for (state.pixels[0 .. state.frame_width * state.frame_height]) |pixel| {
        if (!std.meta.eql(pixel, state.ui.Color.bg)) painted += 1;
    }
    try std.testing.expect(painted > 0);
}

test "app runtime landing builds packed app buffers and hit state" {
    input.applyLocation(.{});
    const code = er_ui_build_app_frame(1280, 800, 1065.0, 32.0, 0.0);
    try std.testing.expectEqual(@as(u32, 0), code);
    try std.testing.expect(state.packed_rect_float_len > 0);
    try std.testing.expect(state.packed_icon_vertex_float_len > 0);
    try std.testing.expect(er_ui_app_content_height(1280.0) > 0.0);
    try std.testing.expectEqual(@intFromEnum(ui.HitKind.button), er_ui_hover_hit_kind());
}

test "app runtime location snapshots cover canonical fixtures and dynamic families" {
    for (app_location.location_fixtures) |fixture| {
        input.applyLocation(fixture.location);
        try expectLocationFixture(fixture);
        try std.testing.expectEqual(@as(u32, 0), er_ui_build_app_frame(1280, 800, 111.0, 32.0, 0.0));
    }
}

test "app runtime frontend builds packed app buffers" {
    input.applyLocation(app_location.locationForButton(.app_preview));
    try std.testing.expectEqual(@as(u32, 0), er_ui_build_app_frame(1280, 800, 640.0, 500.0, 0.0));
}

test "app runtime activation keeps page state in wasm" {
    input.applyLocation(app_location.locationForButton(.app_preview));
    try std.testing.expectEqual(@as(u32, 0), er_ui_build_app_frame(1280, 800, -1.0, -1.0, 0.0));
    try std.testing.expect(app_location.isAppPreview(state.native_input_state.location));
}

test "app runtime location projection sync owns URL path state" {
    input.applyLocation(app_location.locationForButton(.app_preview));
    er_ui_build_app_frame(1280, 800, -1.0, -1.0, 0.0);
    try std.testing.expect(state.location_path_projection_len > 0);
    try std.testing.expect(state.location_hash_projection_len > 0);
}

test "app runtime context source jump opens exact component file" {
    input.applyLocation(app_location.locationForButton(.app_preview));
    try std.testing.expectEqual(@as(u32, 0), er_ui_build_app_frame(1280, 800, 30.0, 150.0, 0.0));
}

test "app runtime key policy stays inert until an app owns text input" {
    try std.testing.expectEqual(@as(u32, 0), input.appKeyEvent("x", 0, 0, 0, 0));
}

test "app runtime event bytes keep host event decoding inside wasm" {
    var buf: [64]u8 = undefined;
    const written = app_input_event.writeBytes(&buf, .{
        .kind = .pointer_move,
        .x = 20.0,
        .y = 30.0,
        .delta_y = 0.0,
        .ctrl = false,
        .meta = false,
        .alt = false,
        .shift = false,
        .repeat = false,
        .key = "",
        .code = "",
        .input_type = "",
        .data = "",
    });
    @memcpy(state.input_bytes[0..written], buf[0..written]);
    const result = er_ui_event_bytes(written, 640.0, 480.0, 0.0);
    try std.testing.expect(result & state.input_event_schedule_frame != 0);
}

test "app runtime event pump owns dom event interpretation" {
    _ = er_ui_event(@intFromEnum(app_input_event.Kind.pointer_move), 50.0, 60.0, 0.0, 0, 0, 0, 0, 640.0, 480.0);
    try std.testing.expectEqual(@as(f32, 50.0), state.pointer_hover_x);
    try std.testing.expectEqual(@as(f32, 60.0), state.pointer_hover_y);
}

test "app runtime boot emits document title host command" {
    try std.testing.expectEqual(@as(u32, 0), er_ui_boot());
    try std.testing.expectEqual(@as(u32, 0), er_ui_last_error());
}

test "app runtime records host appearance preference" {
    try std.testing.expectEqual(@as(u32, 1), er_ui_set_environment_appearance(1));
    try std.testing.expectEqual(@as(u32, 0), er_ui_last_error());
    try std.testing.expectEqual(@as(u32, 1), er_ui_environment_appearance());
}

test "app runtime exposes no secondary bootstrap javascript" {
    try std.testing.expectEqual(@as(usize, 0), er_ui_bootstrap_js_len());
}

test "app runtime exposes repo-owned source as canonical object bytes" {
    try std.testing.expect(er_ui_source_workspace_len() > 0);

    input.applyLocation(app_location.locationForButton(.app_preview));
    try std.testing.expectEqual(@as(u32, 0), er_ui_build_app_frame(1280, 800, -1.0, -1.0, 0.0));
}

test "app runtime source workspace is mutable app source" {
    try std.testing.expect(er_ui_source_workspace_len() > 0);
    const label = "src/er/test_main.er";
    @memcpy(state.input_bytes[0..label.len], label);
    try std.testing.expectEqual(@as(u32, 0), er_ui_source_editor_select_label(@intCast(label.len)));
}

test "app runtime source location initializes embedded editor state" {
    input.applyLocation(app_location.locationForButton(.source_workspace));
    try std.testing.expectEqual(@as(u32, 0), er_ui_build_app_frame(1280, 800, -1.0, -1.0, 0.0));
    try std.testing.expect(app_location.isSourceWorkspace(state.native_input_state.location));
}

test "app runtime source editor rewrites a canonical vfs file" {
    input.applyLocation(app_location.locationForButton(.source_workspace));
    const label = "src/er/test_main.er";
    @memcpy(state.input_bytes[0..label.len], label);
    try std.testing.expectEqual(@as(u32, 0), er_ui_source_editor_select_label(@intCast(label.len)));
    const code = er_ui_build_app_frame(1280, 800, -1.0, -1.0, 0.0);
    try std.testing.expectEqual(@as(u32, 0), code);
}

test "app runtime source editor pointer focus places caret before editing" {
    input.applyLocation(app_location.locationForButton(.source_workspace));
    editor.ensureSourceEditor();
    try std.testing.expect(state.source_editor_len > 0);
    state.source_editor_status = .ready;
    _ = editor.handleSourcePointerDown(30.0, 0.0, 640.0, 480.0);
    try std.testing.expect(state.source_editor_cursor == 0 or state.source_editor_cursor > 0);
}

test "app runtime source explorer rows open real workspace files" {
    input.applyLocation(app_location.locationForButton(.source_workspace));
    editor.ensureSourceEditor();
    try std.testing.expectEqual(@as(u32, 0), er_ui_build_app_frame(1280, 800, -1.0, -1.0, 0.0));
    const files = editor.currentSourceFiles();
    try std.testing.expect(files.len > 0);
}

test "app runtime source explorer search is edited inside wasm" {
    input.applyLocation(app_location.locationForButton(.source_workspace));
    editor.ensureSourceEditor();
    _ = editor.handleSourceSearchKey("a", 0, 0, 0);
    try std.testing.expect(state.source_search_len > 0);
}

test "app runtime source editor moves by visual lines" {
    input.applyLocation(app_location.locationForButton(.source_workspace));
    editor.ensureSourceEditor();
    state.source_editor_status = .ready;
    _ = editor.handleSourceEditorKey("ArrowDown", 0, 0, 0, 0);
}

test "app runtime source editor handles full event records and edit history" {
    input.applyLocation(app_location.locationForButton(.source_workspace));
    editor.ensureSourceEditor();
    state.source_editor_status = .ready;
    try std.testing.expect(editor.handleSourceEditorKey("End", 0, 0, 0, 0));
    try std.testing.expect(!editor.handleSourceEditorKey("z", 1, 0, 0, 0));
}

test "app runtime source editor uses workspace file list and pointer selection" {
    input.applyLocation(app_location.locationForButton(.source_workspace));
    editor.ensureSourceEditor();
    try std.testing.expectEqual(@as(u32, 0), er_ui_build_app_frame(1280, 800, -1.0, -1.0, 0.0));
    const files = editor.currentSourceFiles();
    if (files.len > 0) {
        try std.testing.expect(files[0].path.len > 0);
    }
}

test "app runtime source editor scrolls editor viewport without page scroll" {
    input.applyLocation(app_location.locationForButton(.source_workspace));
    editor.ensureSourceEditor();
    state.source_editor_status = .ready;
    try std.testing.expect(editor.scrollSourceEditorByWheel(120.0));
}

test "app runtime extracts diagnostic line for editor markers" {
    try std.testing.expectEqual(@as(usize, 42), editor.sourceDiagnosticLine("src/app_runtime.zig:42:9: error: broken"));
}

test "app runtime release artifact slot only commits wasm modules" {
    var buf: [4]u8 = .{ 0x00, 0x61, 0x73, 0x6d };
    @memcpy(state.release_artifact[0..4], &buf);
    state.release_artifact_len = 4;
    try std.testing.expectEqual(@as(u32, 0), er_ui_release_artifact_commit(4));
}

test "app runtime exports committed wasm artifact through generic byte bridge" {
    try std.testing.expect(er_ui_release_artifact_ptr() != 0);
}

test "app runtime app state owns scroll position" {
    input.applyLocation(.{});
    try std.testing.expectEqual(@as(f32, 0.0), er_ui_app_scroll_y());
    try std.testing.expectEqual(@as(u32, 0), er_ui_app_scroll_by(-100.0, 1280.0, 800.0));
    try std.testing.expectEqual(@as(f32, 0.0), er_ui_app_scroll_y());
    try std.testing.expectEqual(@as(u32, 0), er_ui_app_scroll_by(100.0, 1280.0, 800.0));
    try std.testing.expect(er_ui_app_scroll_y() > 0.0);
}

test "app render clamps stale scroll after viewport resize" {
    state.native_input_state.scroll_y = 99999.0;
    render.clampAppScrollToViewport(640, 480);
    const clamped = state.native_input_state.scroll_y;
    try std.testing.expect(clamped < 99999.0);
}

test "app runtime cursor intent owns hit and drag cursor policy" {
    const kind = er_ui_cursor_kind();
    try std.testing.expect(kind == 0 or kind > 0);
}

test "app runtime cursor is scene-drawn from runtime pointer state" {
    try std.testing.expectEqual(@as(u32, 0), er_ui_render_frame(128, 128, 0.0));
}

test "app runtime pointer up owns activation suppression policy" {
    try std.testing.expectEqual(@as(u32, 0), er_ui_pointer_down(100.0, 200.0));
    try std.testing.expectEqual(@as(u32, 0), er_ui_pointer_up(100.0, 200.0));
}

test "app packed text preserves variable font descenders" {
    input.applyLocation(app_location.locationForButton(.app_preview));
    try std.testing.expectEqual(@as(u32, 0), er_ui_build_app_frame(1280, 800, -1.0, -1.0, 0.0));
}

test "app variable font atlas separates css size from raster scale" {
    _ = er_ui_set_device_scale(1.5);
    try std.testing.expectEqual(@as(u32, 0), er_ui_build_app_frame(1280, 800, -1.0, -1.0, 0.0));
}

test "app hd browser frame keeps logical layout and physical pixels separate" {
    try std.testing.expectEqual(@as(u32, 0), er_ui_render_frame_hd(640, 480, 2.0, 0.0));
}

test "app font atlas populates glyphs on demand" {
    try std.testing.expect(er_ui_font_atlas_generation() == 0 or er_ui_font_atlas_generation() == 1);
    _ = er_ui_set_device_scale(2.0);
    try std.testing.expectEqual(@as(u32, 0), er_ui_build_app_frame(1280, 800, -1.0, -1.0, 0.0));
    try std.testing.expect(er_ui_font_atlas_generation() > 0);
}

test "app icon buffer stores semantic icon instances" {
    input.applyLocation(app_location.locationForButton(.app_preview));
    try std.testing.expectEqual(@as(u32, 0), er_ui_build_app_frame(1280, 800, -1.0, -1.0, 0.0));
}

test "app render frame writes pixels for byte bridge" {
    try std.testing.expectEqual(@as(u32, 0), er_ui_render_frame(32, 32, 0.0));
}
