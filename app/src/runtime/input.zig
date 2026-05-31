const std = @import("std");
const bytes = @import("../bytes.zig");
const state = @import("state.zig");
const editor = @import("editor.zig");
const identity = @import("identity.zig");
const app_frame = @import("../route/frame.zig");
const component_gallery = @import("../ui/component_gallery.zig");

pub fn appKeyEvent(key: []const u8, ctrl: u32, meta: u32, alt: u32, shift: u32) u32 {
    if (editor.sourceEditorFocused()) {
        if (editor.handleSourceEditorKey(key, ctrl, meta, alt, shift)) return state.input_event_prevent_default | state.input_event_schedule_frame;
        return state.input_event_schedule_frame;
    }
    if (editor.sourceExplorerSearchFocused()) {
        if (editor.handleSourceSearchKey(key, ctrl, meta, alt)) return state.input_event_prevent_default | state.input_event_schedule_frame;
        return state.input_event_schedule_frame;
    }
    const input_kind = keyFromText(key, shift) orelse return 0;
    const action = state.runtime_state.keyDown(state.interaction_regions[0..state.last_region_count], input_kind);
    if (action.kind != .none) {
        state.last_action_kind = @intFromEnum(action.kind);
        state.last_action_hit_id = if (action.hit) |hit| hit.id else 0;
    }
    if (state.runtime_state.overlays.count == 0) {
        if (input_kind == .enter or input_kind == .space) {
            const hit_id = state.runtime_state.hoverHitId();
            if (state.app_navigation.fromHit(hit_id, state.native_input_state.route)) |route| {
                state.native_input_state.route = route;
                state.native_input_state.scroll_y = 0.0;
                state.context_menu_open = false;
            } else if (state.app_navigation.actionFromHit(hit_id)) |action_fn| switch (action_fn) {
                .reveal_identity => {
                    state.native_input_state.public_identity_ready = true;
                    state.native_input_state.public_identity = state.native_input_state.reveal_identity;
                },
                else => {},
            };
        }
        return state.input_event_prevent_default | state.input_event_schedule_frame;
    }
    return state.input_event_prevent_default | state.input_event_schedule_frame;
}

pub fn handleInputEventRecord(record: state.InputEventRecord, width: f32, height: f32) u32 {
    var result: u32 = 0;
    switch (record.kind) {
        .pointer_move => {
            state.pointer_hover_x = record.x;
            state.pointer_hover_y = record.y;
            identity.mixInteractionEntropy(.pointer_move, record.x, record.y);
            result = state.input_event_schedule_frame;
        },
        .pointer_leave => {
            state.pointer_hover_x = -1.0;
            state.pointer_hover_y = -1.0;
            identity.mixInteractionEntropy(.pointer_move, -1.0, -1.0);
            result = state.input_event_schedule_frame;
        },
        .pointer_down => {
            state.pointer_hover_x = record.x;
            state.pointer_hover_y = record.y;
            identity.mixInteractionEntropy(.pointer_down, record.x, record.y);
            if (editor.sourceEditorFocused()) {
                if (editor.handleSourcePointerDown(record.x, record.y, width, height)) {
                    return state.input_event_prevent_default | state.input_event_schedule_frame;
                }
            }
            const commands_slice = state.commands[0..state.last_command_count];
            const regions_slice = state.interaction_regions[0..state.last_region_count];
            state.app_native_input.processPointerEvent(&state.native_input_state, commands_slice, regions_slice, null, @enumFromInt(@intFromEnum(record.kind)));
            state.last_action_kind = @intFromEnum(state.native_input_state.last_action_kind);
            state.last_action_hit_id = state.native_input_state.runtime.hoverHitId();
            state.context_menu_open = false;
            result = state.input_event_prevent_default | state.input_event_schedule_frame;
        },
        .pointer_up => {
            identity.mixInteractionEntropy(.pointer_up, record.x, record.y);
            if (editor.sourceEditorFocused()) {
                state.source_pointer_drag_select = false;
            }
            const commands_slice = state.commands[0..state.last_command_count];
            const regions_slice = state.interaction_regions[0..state.last_region_count];
            state.app_native_input.processPointerEvent(&state.native_input_state, commands_slice, regions_slice, null, @enumFromInt(@intFromEnum(record.kind)));
            state.last_action_kind = @intFromEnum(state.native_input_state.last_action_kind);
            state.last_action_hit_id = state.native_input_state.runtime.hoverHitId();
            result = state.input_event_prevent_default | state.input_event_schedule_frame;
        },
        .wheel => {
            identity.mixInteractionEntropy(.pointer_move, record.x, record.y);
            if (editor.sourceEditorFocused()) {
                result = state.input_event_schedule_frame;
            } else {
                state.app_native_input.scrollBy(&state.native_input_state, width, height, record.delta_y);
                result = state.input_event_schedule_frame;
            }
            if (editor.sourceEditorFocused()) {
                if (editor.scrollSourceEditorByWheel(record.delta_y)) result |= state.input_event_prevent_default;
            }
        },
        .key_down => {
            result = appKeyEvent(record.key, record.ctrl, record.meta, record.alt, record.shift);
        },
        .key_up => {
            result = state.input_event_prevent_default;
        },
        .before_input, .input => {
            if (editor.sourceEditorFocused()) {
                if (editor.handleSourceEditorTextInput(record.input_type, record.data)) {
                    result = state.input_event_prevent_default | state.input_event_schedule_frame;
                } else {
                    result = state.input_event_schedule_frame;
                }
            } else if (editor.sourceExplorerSearchFocused()) {
                if (editor.handleSourceSearchTextInput(record.input_type, record.data)) {
                    result = state.input_event_prevent_default | state.input_event_schedule_frame;
                } else {
                    result = state.input_event_schedule_frame;
                }
            } else {
                result = state.input_event_schedule_frame;
            }
        },
        .composition_start, .composition_update, .composition_end => {
            result = state.input_event_prevent_default;
        },
        .click => {
            if (editor.sourceEditorFocused()) {
                if (editor.handleSourceDoubleClick(record.x, record.y, width, height)) {
                    result = state.input_event_prevent_default | state.input_event_schedule_frame;
                } else {
                    result = state.input_event_schedule_frame;
                }
            } else {
                result = state.input_event_prevent_default;
            }
        },
        .context_menu => {
            if (state.app_navigation.isSourceWorkspace(state.native_input_state.route)) {
                state.context_menu_open = true;
                state.context_menu_x = record.x;
                state.context_menu_y = record.y;
                if (state.source_editor_label.len > 0 and state.source_editor_label.len <= state.context_source_label_bytes.len) {
                    @memcpy(state.context_source_label_bytes[0..state.source_editor_label.len], state.source_editor_label);
                    state.context_source_label = state.context_source_label_bytes[0..state.source_editor_label.len];
                } else {
                    state.context_source_label = "";
                }
                result = state.input_event_prevent_default | state.input_event_schedule_frame;
            }
        },
        .resize => {
            result = state.input_event_schedule_frame;
        },
        .touch_start, .touch_move, .touch_end, .touch_cancel, .drag_start, .drag_end, .drop, .focus, .blur, .dbl_click, .popstate, .hashchange, .visibility_change, .change => {
            result = state.input_event_schedule_frame;
        },
    }
    return result;
}

pub fn handleSourceSearchKey(key: []const u8, ctrl: u32, meta: u32, alt: u32) bool {
    _ = ctrl;
    _ = meta;
    _ = alt;
    _ = key;
    return false;
}

fn keyFromText(value: []const u8, shift: u32) ?state.ui_runtime.Key {
    if (value.len == 0) return null;
    if (value.len == 1) {
        return switch (value[0]) {
            '\t' => state.ui_runtime.Key.tab,
            '\n', '\r' => state.ui_runtime.Key.enter,
            ' ' => state.ui_runtime.Key.space,
            else => if (shift != 0) null else switch (value[0]) {
                'A'...'Z', 'a'...'z', '0'...'9' => null,
                else => null,
            },
        };
    }
    return switch (value[0]) {
        'A'...'Z' => null,
        else => if (bytes.eql(value, "Tab")) .tab else if (bytes.eql(value, "Enter")) .enter else if (bytes.eql(value, " ")) .space else if (bytes.eql(value, "ArrowUp")) .arrow_up else if (bytes.eql(value, "ArrowDown")) .arrow_down else if (bytes.eql(value, "ArrowLeft")) .arrow_left else if (bytes.eql(value, "ArrowRight")) .arrow_right else if (bytes.eql(value, "Escape")) .escape else null,
    };
}

pub fn queueOutboxMessage(kind: u32) error{OutboxMessageBudget}!void {
    if (state.outbox_message_len >= state.outbox_capacity) return error.OutboxMessageBudget;
    state.outbox_messages[state.outbox_message_len] = .{
        .kind = @enumFromInt(kind),
        .id = nextOutboxMessageId(),
    };
    state.outbox_message_len += 1;
}

fn nextOutboxMessageId() u32 {
    const id = state.next_outbox_message_id;
    state.next_outbox_message_id +%= 1;
    return id;
}

pub fn clearOutboxMessages() void {
    state.outbox_message_len = 0;
}

pub fn applyRoute(route: state.app_navigation.Location) void {
    state.context_menu_open = false;
    state.app_native_input.applyLocation(&state.native_input_state, route);
}

pub fn currentLocation() state.app_navigation.Location {
    return state.native_input_state.route;
}

pub fn currentAppFrameState(hover_x: f32, hover_y: f32, frame_ms: f32) app_frame.State {
    state.native_input_state.hover_x = hover_x;
    state.native_input_state.hover_y = hover_y;
    var fs = state.native_input_state.frameState();
    fs.frame_ms = frame_ms;
    fs.public_identity = identity.publicIdentityText();
    fs.public_identity_ready = state.ephemeral_identity_ready;
    fs.drag_override = currentDragOverride();
    fs.context_menu = .{
        .open = state.context_menu_open,
        .x = state.context_menu_x,
        .y = state.context_menu_y,
        .source_path = state.context_source_label,
    };
    return fs;
}

fn currentDragOverride() ?component_gallery.DragOverride {
    const active = state.runtime_state.drag_value orelse state.runtime_state.persisted_value orelse return null;
    for (state.interaction_regions[0..state.last_region_count]) |r| {
        if (r.id == active.id and r.kind == .slider) {
            return .{ .id = active.id, .value = state.ui.clampUnit((active.pointer_x - r.bounds.x) / r.bounds.w) };
        }
    }
    return null;
}
