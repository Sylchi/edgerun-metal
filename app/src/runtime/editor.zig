const std = @import("std");
const bytes = @import("../bytes.zig");
const object = @import("../object.zig");
const vfs = @import("../vfs.zig");
const state = @import("state.zig");
const compiler = @import("compiler.zig");

pub const FileEntry = struct {
    path: []const u8,
};

pub fn ensureSourceWorkspace() void {
    if (!state.source_workspace_ready) {
        const source_object = @import("embedded_source_object").bytes;
        state.source_workspace_len = @min(source_object.len, state.source_workspace.len);
        @memcpy(state.source_workspace[0..state.source_workspace_len], source_object[0..state.source_workspace_len]);
        state.source_workspace_ready = true;
    }
}

pub fn ensureSourceEditor() void {
    if (state.source_editor_loaded) return;
    ensureSourceWorkspace();
    state.source_editor_len = 0;
    state.source_editor_cursor = 0;
    state.source_editor_preferred_column = 0;
    state.source_editor_selection_anchor = 0;
    state.source_editor_selection_active = false;
    state.source_editor_scroll_line = 0;
    state.source_editor_undo_len = 0;
    state.source_editor_redo_len = 0;
    clearSourceEditorHistory();
    state.source_editor_status = loadSourceEditorFromWorkspace();
    state.source_editor_loaded = true;
}

pub fn loadSourceEditorFromWorkspace() state.SourceEditorStatus {
    const workspace_view = object.View.decode(state.source_workspace[0..state.source_workspace_len]) catch return .corrupt_workspace;
    const body = workspace_view.body;
    if (body.len < state.workspace_manifest_header_bytes) return .corrupt_workspace;
    const file_count = bytes.load32(body[12..16]) orelse return .corrupt_workspace;
    var index: usize = state.workspace_manifest_header_bytes;
    var remaining = file_count;
    while (remaining > 0) : (remaining -= 1) {
        if (index > body.len or vfs.object_label_ref_bytes > body.len - index) return .corrupt_workspace;
        const label_ref_raw = body[index..][0..vfs.object_label_ref_bytes];
        const label_ref = vfs.decodeObjectLabelRef(label_ref_raw) catch return .corrupt_workspace;
        index += vfs.object_label_ref_bytes;
        const file_len: usize = @intCast(label_ref.object_len);
        if (index > body.len or file_len > body.len - index) return .corrupt_workspace;
        const file_object = body[index..][0..file_len];
        index += file_len;
        if (bytes.eql(label_ref.labelSlice(), state.source_editor_label)) {
            const file_view = object.View.decode(file_object) catch return .corrupt_workspace;
            const file_body = file_view.body;
            if (file_body.len > state.source_editor_bytes.len) return .editor_too_large;
            @memcpy(state.source_editor_bytes[0..file_body.len], file_body);
            state.source_editor_len = file_body.len;
            return .ready;
        }
    }
    return .missing_file;
}

pub fn findWorkspaceFileBody(workspace_bytes: []const u8, label: []const u8) ![]const u8 {
    const workspace_view = try object.View.decode(workspace_bytes);
    const body = workspace_view.body;
    if (body.len < state.workspace_manifest_header_bytes) return error.CorruptWorkspace;
    const file_count = bytes.load32(body[12..16]) orelse return error.CorruptWorkspace;
    var index: usize = state.workspace_manifest_header_bytes;
    var remaining = file_count;
    while (remaining > 0) : (remaining -= 1) {
        if (index > body.len or vfs.object_label_ref_bytes > body.len - index) return error.CorruptWorkspace;
        const label_ref_raw = body[index..][0..vfs.object_label_ref_bytes];
        const label_ref = vfs.decodeObjectLabelRef(label_ref_raw) catch return error.CorruptWorkspace;
        index += vfs.object_label_ref_bytes;
        const file_len: usize = @intCast(label_ref.object_len);
        if (index > body.len or file_len > body.len - index) return error.CorruptWorkspace;
        if (bytes.eql(label_ref.labelSlice(), label)) {
            const file_object = body[index..][0..file_len];
            const file_view = try object.View.decode(file_object);
            return file_view.body;
        }
        index += file_len;
    }
    return error.FileNotFound;
}

pub fn currentSourceFiles() []const FileEntry {
    if (state.source_file_cache_workspace_len == state.source_workspace_len and state.source_file_count > 0) return state.source_file_entries[0..state.source_file_count];
    state.source_file_count = 0;
    state.source_file_label_bytes_len = 0;
    const workspace_view = object.View.decode(state.source_workspace[0..state.source_workspace_len]) catch return &.{};
    const body = workspace_view.body;
    if (body.len < state.workspace_manifest_header_bytes) return &.{};
    const file_count = bytes.load32(body[12..16]) orelse return &.{};
    var index: usize = state.workspace_manifest_header_bytes;
    var remaining = file_count;
    while (remaining > 0 and state.source_file_count < state.max_source_file_entries) : (remaining -= 1) {
        if (index > body.len or vfs.object_label_ref_bytes > body.len - index) return state.source_file_entries[0..state.source_file_count];
        const label_ref_raw = body[index..][0..vfs.object_label_ref_bytes];
        const label_ref = vfs.decodeObjectLabelRef(label_ref_raw) catch return state.source_file_entries[0..state.source_file_count];
        index += vfs.object_label_ref_bytes;
        const file_len: usize = @intCast(label_ref.object_len);
        if (index > body.len or file_len > body.len - index) return state.source_file_entries[0..state.source_file_count];
        index += file_len;
        const label_bytes = label_ref.labelSlice();
        const path = if (label_bytes.len > 0 and label_bytes[0] == '/')
            label_bytes
        else if (state.source_file_label_bytes_len + label_bytes.len + 1 > state.source_file_label_bytes.len)
            label_bytes
        else brk: {
            const prefix = "src/";
            @memcpy(state.source_file_label_bytes[state.source_file_label_bytes_len..][0..prefix.len], prefix);
            @memcpy(state.source_file_label_bytes[state.source_file_label_bytes_len + prefix.len ..][0..label_bytes.len], label_bytes);
            const full = state.source_file_label_bytes[state.source_file_label_bytes_len .. state.source_file_label_bytes_len + prefix.len + label_bytes.len];
            state.source_file_label_bytes_len += prefix.len + label_bytes.len;
            break :brk full;
        };
        state.source_file_entries[state.source_file_count] = .{ .path = path };
        state.source_file_count += 1;
    }
    state.source_file_cache_workspace_len = state.source_workspace_len;
    return state.source_file_entries[0..state.source_file_count];
}

pub fn selectSourceEditorLabel(label: []const u8) state.ErrorCode {
    ensureSourceWorkspace();
    const workspace_view = object.View.decode(state.source_workspace[0..state.source_workspace_len]) catch return .bad_input;
    const body = workspace_view.body;
    if (body.len < state.workspace_manifest_header_bytes) return .bad_input;
    const file_count = bytes.load32(body[12..16]) orelse return .bad_input;
    var index: usize = state.workspace_manifest_header_bytes;
    var remaining = file_count;
    while (remaining > 0) : (remaining -= 1) {
        if (index > body.len or vfs.object_label_ref_bytes > body.len - index) return .bad_input;
        const label_ref_raw = body[index..][0..vfs.object_label_ref_bytes];
        const label_ref = vfs.decodeObjectLabelRef(label_ref_raw) catch return .bad_input;
        index += vfs.object_label_ref_bytes;
        const file_len: usize = @intCast(label_ref.object_len);
        if (index > body.len or file_len > body.len - index) return .bad_input;
        index += file_len;
        if (bytes.eql(label_ref.labelSlice(), label)) {
            state.source_editor_label = label;
            state.source_editor_label = state.source_editor_label;
            state.source_editor_loaded = false;
            ensureSourceEditor();
            return .ok;
        }
    }
    return .bad_input;
}

pub fn handleSourceEditorKey(key: []const u8, ctrl: u32, meta: u32, alt: u32, shift: u32) bool {
    if (alt != 0) return false;
    ensureSourceEditor();
    if (state.source_editor_status != .ready and state.source_editor_status != .dirty) return false;
    if ((ctrl != 0 or meta != 0) and bytes.eql(key, "s")) {
        _ = compiler.compileWorkspaceInsideWasm();
        return true;
    }
    if ((ctrl != 0 or meta != 0) and bytes.eql(key, "Enter")) {
        _ = compiler.compileWorkspaceInsideWasm();
        return true;
    }
    if ((ctrl != 0 or meta != 0) and (bytes.eql(key, "a") or bytes.eql(key, "A"))) {
        state.source_editor_selection_anchor = 0;
        state.source_editor_cursor = state.source_editor_len;
        state.source_editor_selection_active = state.source_editor_len != 0;
        state.source_editor_preferred_column = sourceEditorColumn(state.source_editor_cursor);
        ensureSourceEditorCursorVisible();
        return true;
    }
    if ((ctrl != 0 or meta != 0) and (bytes.eql(key, "z") or bytes.eql(key, "Z"))) return undoSourceEditorEdit();
    if ((ctrl != 0 or meta != 0) and (bytes.eql(key, "y") or bytes.eql(key, "Y"))) return redoSourceEditorEdit();
    if ((ctrl != 0 or meta != 0) and bytes.eql(key, "ArrowLeft")) {
        moveSourceEditorCursor(sourceEditorWordLeft(), shift != 0);
        return true;
    }
    if ((ctrl != 0 or meta != 0) and bytes.eql(key, "ArrowRight")) {
        moveSourceEditorCursor(sourceEditorWordRight(), shift != 0);
        return true;
    }
    if (ctrl != 0 or meta != 0) return false;

    if (bytes.eql(key, "ArrowLeft")) {
        moveSourceEditorCursor(state.source_editor_cursor -| 1, shift != 0);
        return true;
    }
    if (bytes.eql(key, "ArrowRight")) {
        moveSourceEditorCursor(@min(state.source_editor_len, state.source_editor_cursor + 1), shift != 0);
        return true;
    }
    if (bytes.eql(key, "ArrowUp")) {
        moveSourceEditorVertical(.up, shift != 0);
        return true;
    }
    if (bytes.eql(key, "ArrowDown")) {
        moveSourceEditorVertical(.down, shift != 0);
        return true;
    }
    if (bytes.eql(key, "PageUp")) {
        moveSourceEditorPage(.up, shift != 0);
        return true;
    }
    if (bytes.eql(key, "PageDown")) {
        moveSourceEditorPage(.down, shift != 0);
        return true;
    }
    if (bytes.eql(key, "Home")) {
        moveSourceEditorCursor(currentSourceEditorLineStart(), shift != 0);
        return true;
    }
    if (bytes.eql(key, "End")) {
        moveSourceEditorCursor(currentSourceEditorLineEnd(), shift != 0);
        return true;
    }
    if (bytes.eql(key, "Backspace")) {
        return deleteSourceEditorBackward();
    }
    if (bytes.eql(key, "Delete")) {
        return deleteSourceEditorForward();
    }
    if (bytes.eql(key, "Enter")) return insertSourceEditorNewline();
    if (shift != 0 and bytes.eql(key, "Tab")) return outdentSourceEditorSelection();
    if (state.source_editor_selection_active and bytes.eql(key, "Tab")) return indentSourceEditorSelection();
    if (bytes.eql(key, "Tab")) return insertSourceEditorText(state.source_editor_tab);
    if (key.len == 1 and key[0] >= 0x20 and key[0] <= 0x7e) return insertSourceEditorText(key);
    return false;
}

pub fn handleSourceEditorTextInput(input_type: []const u8, data: []const u8) bool {
    ensureSourceEditor();
    if (state.source_editor_status != .ready and state.source_editor_status != .dirty) return false;
    if (bytes.eql(input_type, "insertText") or bytes.eql(input_type, "insertCompositionText") or bytes.eql(input_type, "insertFromPaste")) {
        var decoded: [state.max_input_bytes]u8 = undefined;
        const text = decodeInputEventData(data, &decoded) catch return false;
        return insertSourceEditorText(text);
    }
    if (bytes.eql(input_type, "insertLineBreak")) return insertSourceEditorText("\n");
    if (bytes.eql(input_type, "deleteContentBackward")) return deleteSourceEditorBackward();
    if (bytes.eql(input_type, "deleteContentForward")) return deleteSourceEditorForward();
    return false;
}

pub fn decodeInputEventData(data: []const u8, out: []u8) ![]const u8 {
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

pub fn insertSourceEditorText(text: []const u8) bool {
    if (text.len == 0) return true;
    recordSourceEditorUndo();
    deleteSourceEditorSelectionWithoutHistory();
    if (text.len > state.source_editor_bytes.len - state.source_editor_len) {
        state.source_editor_status = .editor_too_large;
        return true;
    }
    std.mem.copyBackwards(u8, state.source_editor_bytes[state.source_editor_cursor + text.len .. state.source_editor_len + text.len], state.source_editor_bytes[state.source_editor_cursor..state.source_editor_len]);
    @memcpy(state.source_editor_bytes[state.source_editor_cursor..][0..text.len], text);
    state.source_editor_cursor += text.len;
    state.source_editor_len += text.len;
    state.source_editor_preferred_column = sourceEditorColumn(state.source_editor_cursor);
    clearSourceEditorSelection();
    ensureSourceEditorCursorVisible();
    commitSourceEditorBytes();
    return true;
}

pub fn deleteSourceEditorBackward() bool {
    if (state.source_editor_selection_active and state.source_editor_selection_anchor != state.source_editor_cursor) {
        recordSourceEditorUndo();
        deleteSourceEditorSelectionWithoutHistory();
        commitSourceEditorBytes();
        return true;
    }
    if (state.source_editor_cursor == 0) return true;
    recordSourceEditorUndo();
    std.mem.copyForwards(u8, state.source_editor_bytes[state.source_editor_cursor - 1 .. state.source_editor_len - 1], state.source_editor_bytes[state.source_editor_cursor..state.source_editor_len]);
    state.source_editor_cursor -= 1;
    state.source_editor_len -= 1;
    state.source_editor_preferred_column = sourceEditorColumn(state.source_editor_cursor);
    clearSourceEditorSelection();
    ensureSourceEditorCursorVisible();
    commitSourceEditorBytes();
    return true;
}

pub fn deleteSourceEditorForward() bool {
    if (state.source_editor_selection_active and state.source_editor_selection_anchor != state.source_editor_cursor) {
        recordSourceEditorUndo();
        deleteSourceEditorSelectionWithoutHistory();
        commitSourceEditorBytes();
        return true;
    }
    if (state.source_editor_cursor >= state.source_editor_len) return true;
    recordSourceEditorUndo();
    std.mem.copyForwards(u8, state.source_editor_bytes[state.source_editor_cursor .. state.source_editor_len - 1], state.source_editor_bytes[state.source_editor_cursor + 1 .. state.source_editor_len]);
    state.source_editor_len -= 1;
    state.source_editor_preferred_column = sourceEditorColumn(state.source_editor_cursor);
    clearSourceEditorSelection();
    ensureSourceEditorCursorVisible();
    commitSourceEditorBytes();
    return true;
}

fn deleteSourceEditorSelectionWithoutHistory() void {
    const selection = sourceEditorSelectionBounds();
    if (selection.start == selection.end) return;
    std.mem.copyForwards(u8, state.source_editor_bytes[selection.start .. state.source_editor_len - (selection.end - selection.start)], state.source_editor_bytes[selection.end..state.source_editor_len]);
    state.source_editor_len -= selection.end - selection.start;
    state.source_editor_cursor = selection.start;
    state.source_editor_preferred_column = sourceEditorColumn(state.source_editor_cursor);
    clearSourceEditorSelection();
    ensureSourceEditorCursorVisible();
}

pub fn insertSourceEditorNewline() bool {
    var indent: [64]u8 = undefined;
    const line_start = currentSourceEditorLineStart();
    var indent_len: usize = 0;
    while (line_start + indent_len < state.source_editor_len and indent_len < indent.len) : (indent_len += 1) {
        const byte = state.source_editor_bytes[line_start + indent_len];
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
    const column = state.source_editor_preferred_column;
    const target_start = switch (direction) {
        .up => previousSourceEditorLineStart(line_start) orelse return,
        .down => if (line_end < state.source_editor_len) line_end + 1 else return,
    };
    const target_end = sourceEditorLineEnd(target_start);
    moveSourceEditorCursor(target_start + @min(column, target_end - target_start), extend_selection);
    state.source_editor_preferred_column = column;
}

fn moveSourceEditorPage(direction: VerticalMove, extend_selection: bool) void {
    var remaining = state.source_editor_page_lines;
    while (remaining > 0) : (remaining -= 1) moveSourceEditorVertical(direction, extend_selection);
    state.source_editor_scroll_line = switch (direction) {
        .up => state.source_editor_scroll_line -| state.source_editor_page_lines,
        .down => state.source_editor_scroll_line + state.source_editor_page_lines,
    };
}

fn currentSourceEditorLineStart() usize {
    var index = state.source_editor_cursor;
    while (index > 0 and state.source_editor_bytes[index - 1] != '\n') : (index -= 1) {}
    return index;
}

fn currentSourceEditorLineEnd() usize {
    return sourceEditorLineEnd(state.source_editor_cursor);
}

fn sourceEditorLineEnd(start_or_cursor: usize) usize {
    var index = start_or_cursor;
    while (index < state.source_editor_len and state.source_editor_bytes[index] != '\n') : (index += 1) {}
    return index;
}

fn previousSourceEditorLineStart(line_start: usize) ?usize {
    if (line_start == 0) return null;
    var index = line_start - 1;
    while (index > 0 and state.source_editor_bytes[index - 1] != '\n') : (index -= 1) {}
    return index;
}

fn sourceEditorColumn(cursor: usize) usize {
    var index = @min(cursor, state.source_editor_len);
    while (index > 0 and state.source_editor_bytes[index - 1] != '\n') : (index -= 1) {}
    return @min(cursor, state.source_editor_len) - index;
}

fn clearSourceEditorHistory() void {
    state.source_editor_undo_len = 0;
    state.source_editor_redo_len = 0;
}

fn pushSourceEditorSnapshot(stack: *[state.max_source_editor_undo_entries]state.SourceEditorSnapshot, len: *usize) void {
    if (len.* == state.max_source_editor_undo_entries) {
        std.mem.copyForwards(state.SourceEditorSnapshot, stack[0 .. state.max_source_editor_undo_entries - 1], stack[1..state.max_source_editor_undo_entries]);
        len.* -= 1;
    }
    const slot = &stack[len.*];
    @memcpy(slot.bytes[0..state.source_editor_len], state.source_editor_bytes[0..state.source_editor_len]);
    slot.len = state.source_editor_len;
    slot.cursor = state.source_editor_cursor;
    slot.selection_anchor = state.source_editor_selection_anchor;
    slot.selection_active = state.source_editor_selection_active;
    len.* += 1;
}

fn restoreSourceEditorSnapshot(snapshot: state.SourceEditorSnapshot) void {
    @memcpy(state.source_editor_bytes[0..snapshot.len], snapshot.bytes[0..snapshot.len]);
    state.source_editor_len = snapshot.len;
    state.source_editor_cursor = @min(snapshot.cursor, state.source_editor_len);
    state.source_editor_selection_anchor = @min(snapshot.selection_anchor, state.source_editor_len);
    state.source_editor_selection_active = snapshot.selection_active and state.source_editor_selection_anchor != state.source_editor_cursor;
    state.source_editor_preferred_column = sourceEditorColumn(state.source_editor_cursor);
    ensureSourceEditorCursorVisible();
    commitSourceEditorBytes();
}

fn recordSourceEditorUndo() void {
    pushSourceEditorSnapshot(&state.source_editor_undo, &state.source_editor_undo_len);
    state.source_editor_redo_len = 0;
}

pub fn undoSourceEditorEdit() bool {
    if (state.source_editor_undo_len == 0) return true;
    pushSourceEditorSnapshot(&state.source_editor_redo, &state.source_editor_redo_len);
    state.source_editor_undo_len -= 1;
    restoreSourceEditorSnapshot(state.source_editor_undo[state.source_editor_undo_len]);
    return true;
}

pub fn redoSourceEditorEdit() bool {
    if (state.source_editor_redo_len == 0) return true;
    pushSourceEditorSnapshot(&state.source_editor_undo, &state.source_editor_undo_len);
    state.source_editor_redo_len -= 1;
    restoreSourceEditorSnapshot(state.source_editor_redo[state.source_editor_redo_len]);
    return true;
}

pub fn setSourceEditorCursor(cursor: usize) void {
    ensureSourceEditor();
    state.source_editor_cursor = @min(cursor, state.source_editor_len);
    state.source_editor_selection_anchor = state.source_editor_cursor;
    state.source_editor_selection_active = false;
    state.source_editor_preferred_column = sourceEditorColumn(state.source_editor_cursor);
    ensureSourceEditorCursorVisible();
}

fn moveSourceEditorCursor(cursor: usize, extend_selection: bool) void {
    const clamped = @min(cursor, state.source_editor_len);
    if (extend_selection) {
        if (!state.source_editor_selection_active) state.source_editor_selection_anchor = state.source_editor_cursor;
        state.source_editor_selection_active = true;
    } else {
        state.source_editor_selection_anchor = clamped;
        state.source_editor_selection_active = false;
    }
    state.source_editor_cursor = clamped;
    if (state.source_editor_selection_anchor == state.source_editor_cursor) state.source_editor_selection_active = false;
    state.source_editor_preferred_column = sourceEditorColumn(state.source_editor_cursor);
    ensureSourceEditorCursorVisible();
}

fn sourceEditorSelectionBounds() struct { start: usize, end: usize } {
    if (!state.source_editor_selection_active or state.source_editor_selection_anchor == state.source_editor_cursor) return .{ .start = state.source_editor_cursor, .end = state.source_editor_cursor };
    return if (state.source_editor_selection_anchor < state.source_editor_cursor)
        .{ .start = state.source_editor_selection_anchor, .end = state.source_editor_cursor }
    else
        .{ .start = state.source_editor_cursor, .end = state.source_editor_selection_anchor };
}

fn clearSourceEditorSelection() void {
    state.source_editor_selection_anchor = state.source_editor_cursor;
    state.source_editor_selection_active = false;
}

fn ensureSourceEditorCursorVisible() void {
    const cursor_line = sourceEditorLineIndex(state.source_editor_cursor);
    if (cursor_line < state.source_editor_scroll_line + state.source_editor_scroll_margin_lines) {
        state.source_editor_scroll_line = cursor_line -| state.source_editor_scroll_margin_lines;
        return;
    }
    const visible_bottom = state.source_editor_scroll_line + state.source_editor_visible_lines -| state.source_editor_scroll_margin_lines;
    if (cursor_line >= visible_bottom) {
        state.source_editor_scroll_line = cursor_line -| (state.source_editor_visible_lines - state.source_editor_scroll_margin_lines - 1);
    }
}

fn sourceEditorLineIndex(cursor: usize) usize {
    const clamped = @min(cursor, state.source_editor_len);
    var line: usize = 0;
    for (state.source_editor_bytes[0..clamped]) |byte| {
        if (byte == '\n') line += 1;
    }
    return line;
}

fn sourceEditorLineCount() usize {
    if (state.source_editor_len == 0) return 1;
    var lines: usize = 1;
    for (state.source_editor_bytes[0..state.source_editor_len]) |byte| {
        if (byte == '\n') lines += 1;
    }
    return lines;
}

fn selectSourceEditorWordAt(cursor: usize) void {
    const clamped = @min(cursor, state.source_editor_len);
    var start = clamped;
    var end = clamped;
    if (start == state.source_editor_len and start > 0) start -= 1;
    if (start < state.source_editor_len and isSourceEditorSeparator(state.source_editor_bytes[start])) {
        state.source_editor_cursor = clamped;
        clearSourceEditorSelection();
        return;
    }
    while (start > 0 and !isSourceEditorSeparator(state.source_editor_bytes[start - 1])) : (start -= 1) {}
    while (end < state.source_editor_len and !isSourceEditorSeparator(state.source_editor_bytes[end])) : (end += 1) {}
    state.source_editor_selection_anchor = start;
    state.source_editor_cursor = end;
    state.source_editor_selection_active = end > start;
    state.source_editor_preferred_column = sourceEditorColumn(state.source_editor_cursor);
    ensureSourceEditorCursorVisible();
}

fn sourceEditorWordLeft() usize {
    var index = state.source_editor_cursor;
    while (index > 0 and isSourceEditorSeparator(state.source_editor_bytes[index - 1])) : (index -= 1) {}
    while (index > 0 and !isSourceEditorSeparator(state.source_editor_bytes[index - 1])) : (index -= 1) {}
    return index;
}

fn sourceEditorWordRight() usize {
    var index = state.source_editor_cursor;
    while (index < state.source_editor_len and !isSourceEditorSeparator(state.source_editor_bytes[index])) : (index += 1) {}
    while (index < state.source_editor_len and isSourceEditorSeparator(state.source_editor_bytes[index])) : (index += 1) {}
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
    while (line_start <= selection.end and line_start < state.source_editor_len) {
        if (state.source_editor_bytes[line_start] == '\t') {
            std.mem.copyForwards(u8, state.source_editor_bytes[line_start .. state.source_editor_len - 1], state.source_editor_bytes[line_start + 1 .. state.source_editor_len]);
            state.source_editor_len -= 1;
            changed = true;
        } else {
            var remove_spaces: usize = 0;
            while (remove_spaces < state.source_editor_tab.len and line_start + remove_spaces < state.source_editor_len and state.source_editor_bytes[line_start + remove_spaces] == ' ') : (remove_spaces += 1) {}
            if (remove_spaces != 0) {
                std.mem.copyForwards(u8, state.source_editor_bytes[line_start .. state.source_editor_len - remove_spaces], state.source_editor_bytes[line_start + remove_spaces .. state.source_editor_len]);
                state.source_editor_len -= remove_spaces;
                changed = true;
            }
        }
        const next = sourceEditorLineEnd(line_start);
        if (next >= state.source_editor_len) break;
        line_start = next + 1;
    }
    state.source_editor_cursor = @min(state.source_editor_cursor, state.source_editor_len);
    state.source_editor_selection_anchor = @min(state.source_editor_selection_anchor, state.source_editor_len);
    state.source_editor_preferred_column = sourceEditorColumn(state.source_editor_cursor);
    if (changed) commitSourceEditorBytes();
    return true;
}

fn indentSourceEditorSelection() bool {
    const selection = sourceEditorSelectionBounds();
    var line_start = sourceEditorLineStartAt(selection.start);
    var end_limit = selection.end;
    recordSourceEditorUndo();
    while (line_start <= end_limit and line_start <= state.source_editor_len) {
        if (state.source_editor_tab.len > state.source_editor_bytes.len - state.source_editor_len) {
            state.source_editor_status = .editor_too_large;
            return true;
        }
        std.mem.copyBackwards(u8, state.source_editor_bytes[line_start + state.source_editor_tab.len .. state.source_editor_len + state.source_editor_tab.len], state.source_editor_bytes[line_start..state.source_editor_len]);
        @memcpy(state.source_editor_bytes[line_start..][0..state.source_editor_tab.len], state.source_editor_tab);
        state.source_editor_len += state.source_editor_tab.len;
        end_limit += state.source_editor_tab.len;
        if (state.source_editor_cursor >= line_start) state.source_editor_cursor += state.source_editor_tab.len;
        if (state.source_editor_selection_anchor >= line_start) state.source_editor_selection_anchor += state.source_editor_tab.len;
        const next = sourceEditorLineEnd(line_start + state.source_editor_tab.len);
        if (next >= state.source_editor_len) break;
        line_start = next + 1;
    }
    state.source_editor_preferred_column = sourceEditorColumn(state.source_editor_cursor);
    commitSourceEditorBytes();
    return true;
}

fn sourceEditorLineStartAt(cursor: usize) usize {
    var index = @min(cursor, state.source_editor_len);
    while (index > 0 and state.source_editor_bytes[index - 1] != '\n') : (index -= 1) {}
    return index;
}

fn commitSourceEditorBytes() void {
    state.source_editor_status = rebuildSourceWorkspaceFromEditor();
    state.source_editor_dirty = state.source_editor_status == .dirty;
}

fn rebuildSourceWorkspaceFromEditor() state.SourceEditorStatus {
    ensureSourceWorkspace();
    const workspace_view = object.View.decode(state.source_workspace[0..state.source_workspace_len]) catch return .corrupt_workspace;
    if (!bytes.startsWith(workspace_view.body, "ERVFSWS1")) return .corrupt_workspace;
    if (workspace_view.body.len < state.workspace_manifest_header_bytes) return .corrupt_workspace;
    const file_count = bytes.load32(workspace_view.body[12..16]) orelse return .corrupt_workspace;
    if (state.compiler_runtime_memory.len < object.header_size + workspace_view.body.len) return .workspace_full;

    var body_len: usize = state.workspace_manifest_header_bytes;
    @memcpy(state.compiler_runtime_memory[object.header_size..][0..state.workspace_manifest_header_bytes], workspace_view.body[0..state.workspace_manifest_header_bytes]);

    var index: usize = state.workspace_manifest_header_bytes;
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

        if (bytes.eql(label_ref.labelSlice(), state.source_editor_label)) {
            const file_view = object.View.decode(file_object) catch return .corrupt_workspace;
            const label_pos = object.header_size + body_len;
            const file_pos = label_pos + vfs.object_label_ref_bytes;
            if (file_pos > state.compiler_runtime_memory.len) return .workspace_full;
            const new_file = (object.NodeWriter{ .out = state.compiler_runtime_memory[file_pos..] }).bytesNode(file_view.header.requirements, file_view.header.epoch, state.source_editor_bytes[0..state.source_editor_len]) catch return .workspace_full;
            const new_ref = vfs.prepareObjectLabelRef(state.source_editor_label, new_file) catch return .corrupt_workspace;
            vfs.encodeObjectLabelRef(new_ref, state.compiler_runtime_memory[label_pos..][0..vfs.object_label_ref_bytes]) catch return .workspace_full;
            body_len += vfs.object_label_ref_bytes + new_file.len;
            replaced = true;
        } else {
            const raw_len = vfs.object_label_ref_bytes + file_object.len;
            const out_pos = object.header_size + body_len;
            if (out_pos > state.compiler_runtime_memory.len or raw_len > state.compiler_runtime_memory.len - out_pos) return .workspace_full;
            @memcpy(state.compiler_runtime_memory[out_pos..][0..vfs.object_label_ref_bytes], label_ref_raw);
            @memcpy(state.compiler_runtime_memory[out_pos + vfs.object_label_ref_bytes ..][0..file_object.len], file_object);
            body_len += raw_len;
        }
    }
    if (!replaced or index != workspace_view.body.len) return .corrupt_workspace;

    const body = state.compiler_runtime_memory[object.header_size..][0..body_len];
    const canonical = (object.NodeWriter{ .out = &state.compiler_runtime_memory }).bytesNode(workspace_view.header.requirements, workspace_view.header.epoch, body) catch return .workspace_full;
    if (canonical.len > state.source_workspace.len) return .workspace_full;
    @memcpy(state.source_workspace[0..canonical.len], canonical);
    state.source_workspace_len = canonical.len;
    state.source_workspace_ready = true;
    state.source_file_cache_workspace_len = 0;
    state.release_artifact_len = 0;
    state.last_compile_phase = .idle;
    state.last_compile_progress_permille = 0;
    compiler.setSourceCompileSummary() catch {};
    return .dirty;
}

pub fn sourceEditorFocused() bool {
    ensureSourceEditor();
    return state.source_editor_status == .ready or state.source_editor_status == .dirty;
}

pub fn sourceExplorerSearchFocused() bool {
    return sourceEditorFocused();
}

pub fn handleSourcePointerDown(x: f32, y: f32, width: f32, height: f32) bool {
    _ = width;
    ensureSourceEditor();
    if (state.source_editor_status != .ready and state.source_editor_status != .dirty) return false;
    if (y < 0 or y >= height) return false;
    const line = @as(usize, @intCast(@as(u64, @intFromFloat(y)))) + state.source_editor_scroll_line;
    const clamped_line = @min(line, sourceEditorLineCount() -| 1);
    var target: usize = 0;
    var line_index: usize = 0;
    while (line_index < clamped_line) : (line_index += 1) {
        const end = sourceEditorLineEnd(target);
        target = @min(end + 1, state.source_editor_len);
    }
    const line_end = sourceEditorLineEnd(target);
    const col = @min(@as(usize, @intCast(@as(u64, @intFromFloat(x)))), line_end - target);
    state.source_editor_cursor = target + col;
    state.source_editor_selection_anchor = state.source_editor_cursor;
    state.source_editor_selection_active = false;
    state.source_editor_preferred_column = sourceEditorColumn(state.source_editor_cursor);
    state.source_pointer_drag_select = true;
    ensureSourceEditorCursorVisible();
    return true;
}

pub fn handleSourcePointerMove(x: f32, y: f32, width: f32, height: f32) bool {
    _ = width;
    if (!state.source_pointer_drag_select) return false;
    if (y < 0 or y >= height) return false;
    const line = @as(usize, @intCast(@as(u64, @intFromFloat(y)))) + state.source_editor_scroll_line;
    const clamped_line = @min(line, sourceEditorLineCount() -| 1);
    var target: usize = 0;
    var line_index: usize = 0;
    while (line_index < clamped_line) : (line_index += 1) {
        const end = sourceEditorLineEnd(target);
        target = @min(end + 1, state.source_editor_len);
    }
    const line_end = sourceEditorLineEnd(target);
    const col = @min(@as(usize, @intCast(@as(u64, @intFromFloat(x)))), line_end - target);
    state.source_editor_cursor = target + col;
    state.source_editor_selection_active = state.source_editor_selection_anchor != state.source_editor_cursor;
    state.source_editor_preferred_column = sourceEditorColumn(state.source_editor_cursor);
    ensureSourceEditorCursorVisible();
    return true;
}

pub fn handleSourceDoubleClick(x: f32, y: f32, width: f32, height: f32) bool {
    _ = x;
    _ = width;
    _ = height;
    ensureSourceEditor();
    if (state.source_editor_status != .ready and state.source_editor_status != .dirty) return false;
    if (y < 0) return false;
    const line = @as(usize, @intCast(@as(u64, @intFromFloat(y)))) + state.source_editor_scroll_line;
    const clamped_line = @min(line, sourceEditorLineCount() -| 1);
    var cursor: usize = 0;
    var line_index: usize = 0;
    while (line_index < clamped_line) : (line_index += 1) {
        cursor = sourceEditorLineEnd(cursor) + 1;
    }
    selectSourceEditorWordAt(cursor);
    return true;
}

pub fn scrollSourceEditorByWheel(delta_y: f32) bool {
    ensureSourceEditor();
    if (state.source_editor_status != .ready and state.source_editor_status != .dirty) return false;
    const magnitude = @abs(delta_y);
    const lines: usize = @max(1, @as(usize, @intFromFloat(magnitude / state.source_editor_wheel_pixels_per_line)));
    if (delta_y > 0) {
        state.source_editor_scroll_line = @min(sourceEditorLineCount() -| 1, state.source_editor_scroll_line + lines);
    } else if (delta_y < 0) {
        state.source_editor_scroll_line -|= lines;
    }
    return true;
}

pub fn sourceEditorStatusText(status: state.SourceEditorStatus) []const u8 {
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

pub fn sourceRuntimeMemoryBytes() usize {
    return state.max_pixels * @sizeOf(u32) + state.source_workspace_len + state.source_editor_len + state.release_artifact_len + state.source_search_len;
}

pub fn sourceDiagnosticLine(diagnostic: []const u8) usize {
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

pub fn sourceCursorFromPoint(x: f32, y: f32, width: f32, height: f32) usize {
    _ = x;
    _ = width;
    _ = height;
    ensureSourceEditor();
    if (state.source_editor_status != .ready and state.source_editor_status != .dirty) return 0;
    if (y < 0) return 0;
    const line = @as(usize, @intCast(@as(u64, @intFromFloat(y)))) + state.source_editor_scroll_line;
    const clamped_line = @min(line, sourceEditorLineCount() -| 1);
    var cursor: usize = 0;
    var line_index: usize = 0;
    while (line_index < clamped_line) : (line_index += 1) {
        cursor = sourceEditorLineEnd(cursor) + 1;
    }
    return cursor;
}

pub fn handleSourceSearchKey(key: []const u8, ctrl: u32, meta: u32, alt: u32) bool {
    if (alt != 0) return false;
    _ = meta;
    if (ctrl != 0 and bytes.eql(key, "a")) {
        state.source_search_len = 0;
        return true;
    }
    if (ctrl != 0) return false;
    if (bytes.eql(key, "Backspace") and state.source_search_len > 0) {
        state.source_search_len -= 1;
        return true;
    }
    if (key.len == 1 and key[0] >= 0x20 and key[0] <= 0x7e) {
        if (state.source_search_len < state.source_search_bytes.len) {
            state.source_search_bytes[state.source_search_len] = key[0];
            state.source_search_len += 1;
        }
        return true;
    }
    return false;
}

pub fn handleSourceSearchTextInput(input_type: []const u8, data: []const u8) bool {
    if (bytes.eql(input_type, "insertText") or bytes.eql(input_type, "insertCompositionText") or bytes.eql(input_type, "insertFromPaste")) {
        return insertSourceSearchText(data);
    }
    if (bytes.eql(input_type, "deleteContentBackward")) {
        if (state.source_search_len > 0) {
            state.source_search_len -= 1;
            return true;
        }
        return false;
    }
    if (bytes.eql(input_type, "deleteContentForward")) return true;
    return false;
}

fn insertSourceSearchText(text: []const u8) bool {
    for (text) |byte| {
        if (state.source_search_len >= state.source_search_bytes.len) return true;
        state.source_search_bytes[state.source_search_len] = byte;
        state.source_search_len += 1;
    }
    return true;
}
