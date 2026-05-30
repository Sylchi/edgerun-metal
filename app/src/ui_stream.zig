const std = @import("std");
const ui = @import("ui.zig");

pub const Error = error{
    Corrupt,
    UnsupportedPatchKind,
};

pub const MessageType = enum(u8) {
    tree = 0,
    patch = 1,
};

/// Wire format:
///   [0] kind          — PatchKind
///   [1] component_id  — target component (0-255)
///   [2..] payload     — kind-specific
///
/// Payload encodings:
///   bool:                         [1] 0/1
///   u16:                          [2] LE
///   f32:                          [4] LE
///   []const u8:                   [1 len] [N]
///   struct{title,detail}:         string string
///   struct{title,detail,bool}:    string string [1]
///   struct{first,second}:         string string
///   Color:                        [4] RGBA
///
/// Strings are encoded as: [1 len] [N bytes UTF-8], max 255 bytes.
pub const PatchKind = enum(u8) {
    text_value = 0,
    accordion_open = 1,
    alert = 2,
    alert_dialog = 3,
    calendar_selected_day = 4,
    carousel_label = 5,
    chart_label = 6,
    combobox_selected = 7,
    card_text = 8,
    empty_text = 9,
    badge_label = 10,
    avatar_label = 11,
    kbd_label = 12,
    label_value = 13,
    breadcrumb_current = 14,
    menubar_active = 15,
    navigation_menu_active = 16,
    command_placeholder = 17,
    context_menu = 18,
    dialog = 19,
    direction_active = 20,
    drawer = 21,
    dropdown_menu = 22,
    field_placeholder = 23,
    hover_card_content = 24,
    input_otp_value = 25,
    button_label = 26,
    button_group_active = 27,
    toggle_group_active = 28,
    toggle_pressed = 29,
    input_placeholder = 30,
    input_group_placeholder = 31,
    textarea_placeholder = 32,
    select_label = 33,
    checkbox_checked = 34,
    radio_selected = 35,
    switch_checked = 36,
    pagination_page = 37,
    popover_content = 38,
    resizable_ratio = 39,
    sheet = 40,
    sidebar_item = 41,
    progress_value = 42,
    slider_value = 43,
    tabs_active = 44,
    table_row = 45,
    tooltip_content = 46,
    toast = 47,
    row_item = 48,
    rect_color = 49,
    style_color = 50,
};

const header_len = 2;

fn encodeBool(buf: []u8, kind: PatchKind, component_id: u8, value: bool) ?[]u8 {
    if (buf.len < 3) return null;
    buf[0] = @intFromEnum(kind);
    buf[1] = component_id;
    buf[2] = if (value) 1 else 0;
    return buf[0..3];
}

fn encodeU16(buf: []u8, kind: PatchKind, component_id: u8, value: u16) ?[]u8 {
    if (buf.len < 4) return null;
    buf[0] = @intFromEnum(kind);
    buf[1] = component_id;
    std.mem.writeInt(u16, buf[2..4], value, .little);
    return buf[0..4];
}

fn encodeF32(buf: []u8, kind: PatchKind, component_id: u8, value: f32) ?[]u8 {
    if (buf.len < 6) return null;
    buf[0] = @intFromEnum(kind);
    buf[1] = component_id;
    std.mem.writeInt(u32, buf[2..6], @bitCast(value), .little);
    return buf[0..6];
}

fn encodeString(buf: []u8, kind: PatchKind, component_id: u8, value: []const u8) ?[]u8 {
    const len: u8 = @intCast(value.len);
    const total: usize = 3 + value.len;
    if (buf.len < total) return null;
    buf[0] = @intFromEnum(kind);
    buf[1] = component_id;
    buf[2] = len;
    @memcpy(buf[3..][0..value.len], value);
    return buf[0..total];
}

fn encodeTwoStrings(buf: []u8, kind: PatchKind, component_id: u8, a: []const u8, b: []const u8) ?[]u8 {
    const a_len: u8 = @intCast(a.len);
    const b_len: u8 = @intCast(b.len);
    const total: usize = 4 + a.len + b.len;
    if (buf.len < total) return null;
    buf[0] = @intFromEnum(kind);
    buf[1] = component_id;
    buf[2] = a_len;
    @memcpy(buf[3..][0..a.len], a);
    buf[3 + a.len] = b_len;
    @memcpy(buf[4 + a.len ..][0..b.len], b);
    return buf[0..total];
}

fn encodeTwoStringsBool(buf: []u8, kind: PatchKind, component_id: u8, a: []const u8, b: []const u8, flag: bool) ?[]u8 {
    const a_len: u8 = @intCast(a.len);
    const b_len: u8 = @intCast(b.len);
    const total: usize = 5 + a.len + b.len;
    if (buf.len < total) return null;
    buf[0] = @intFromEnum(kind);
    buf[1] = component_id;
    buf[2] = a_len;
    @memcpy(buf[3..][0..a.len], a);
    buf[3 + a.len] = b_len;
    @memcpy(buf[4 + a.len ..][0..b.len], b);
    buf[4 + a.len + b.len] = if (flag) 1 else 0;
    return buf[0..total];
}

fn encodeColor(buf: []u8, kind: PatchKind, component_id: u8, color: ui.Color) ?[]u8 {
    if (buf.len < 6) return null;
    buf[0] = @intFromEnum(kind);
    buf[1] = component_id;
    buf[2] = color.r;
    buf[3] = color.g;
    buf[4] = color.b;
    buf[5] = color.a;
    return buf[0..6];
}

pub fn encodePatch(buf: []u8, component_id: u8, patch: ui.Patch) ?[]u8 {
    return switch (patch) {
        .text_value => |v| encodeString(buf, .text_value, component_id, v),
        .accordion_open => |v| encodeBool(buf, .accordion_open, component_id, v),
        .alert => |v| encodeTwoStringsBool(buf, .alert, component_id, v.title, v.detail, v.destructive),
        .alert_dialog => |v| encodeTwoStrings(buf, .alert_dialog, component_id, v.title, v.detail),
        .calendar_selected_day => |v| encodeU16(buf, .calendar_selected_day, component_id, v),
        .carousel_label => |v| encodeString(buf, .carousel_label, component_id, v),
        .chart_label => |v| encodeString(buf, .chart_label, component_id, v),
        .combobox_selected => |v| encodeString(buf, .combobox_selected, component_id, v),
        .card_text => |v| encodeTwoStrings(buf, .card_text, component_id, v.title, v.detail),
        .empty_text => |v| encodeTwoStrings(buf, .empty_text, component_id, v.title, v.detail),
        .badge_label => |v| encodeString(buf, .badge_label, component_id, v),
        .avatar_label => |v| encodeString(buf, .avatar_label, component_id, v),
        .kbd_label => |v| encodeString(buf, .kbd_label, component_id, v),
        .label_value => |v| encodeString(buf, .label_value, component_id, v),
        .breadcrumb_current => |v| encodeString(buf, .breadcrumb_current, component_id, v),
        .menubar_active => |v| encodeU16(buf, .menubar_active, component_id, v),
        .navigation_menu_active => |v| encodeU16(buf, .navigation_menu_active, component_id, v),
        .command_placeholder => |v| encodeString(buf, .command_placeholder, component_id, v),
        .context_menu => |v| encodeTwoStrings(buf, .context_menu, component_id, v.first, v.second),
        .dialog => |v| encodeTwoStrings(buf, .dialog, component_id, v.title, v.detail),
        .direction_active => |v| encodeU16(buf, .direction_active, component_id, v),
        .drawer => |v| encodeTwoStrings(buf, .drawer, component_id, v.title, v.detail),
        .dropdown_menu => |v| encodeTwoStrings(buf, .dropdown_menu, component_id, v.first, v.second),
        .field_placeholder => |v| encodeString(buf, .field_placeholder, component_id, v),
        .hover_card_content => |v| encodeString(buf, .hover_card_content, component_id, v),
        .input_otp_value => |v| encodeString(buf, .input_otp_value, component_id, v),
        .button_label => |v| encodeString(buf, .button_label, component_id, v),
        .button_group_active => |v| encodeU16(buf, .button_group_active, component_id, v),
        .toggle_group_active => |v| encodeU16(buf, .toggle_group_active, component_id, v),
        .toggle_pressed => |v| encodeBool(buf, .toggle_pressed, component_id, v),
        .input_placeholder => |v| encodeString(buf, .input_placeholder, component_id, v),
        .input_group_placeholder => |v| encodeString(buf, .input_group_placeholder, component_id, v),
        .textarea_placeholder => |v| encodeString(buf, .textarea_placeholder, component_id, v),
        .select_label => |v| encodeString(buf, .select_label, component_id, v),
        .checkbox_checked => |v| encodeBool(buf, .checkbox_checked, component_id, v),
        .radio_selected => |v| encodeU16(buf, .radio_selected, component_id, v),
        .switch_checked => |v| encodeBool(buf, .switch_checked, component_id, v),
        .pagination_page => |v| encodeU16(buf, .pagination_page, component_id, v),
        .popover_content => |v| encodeString(buf, .popover_content, component_id, v),
        .resizable_ratio => |v| encodeF32(buf, .resizable_ratio, component_id, v),
        .sheet => |v| encodeTwoStrings(buf, .sheet, component_id, v.title, v.detail),
        .sidebar_item => |v| encodeString(buf, .sidebar_item, component_id, v),
        .progress_value => |v| encodeF32(buf, .progress_value, component_id, v),
        .slider_value => |v| encodeF32(buf, .slider_value, component_id, v),
        .tabs_active => |v| encodeU16(buf, .tabs_active, component_id, v),
        .table_row => |v| encodeTwoStrings(buf, .table_row, component_id, v.name, v.role),
        .tooltip_content => |v| encodeString(buf, .tooltip_content, component_id, v),
        .toast => |v| encodeTwoStrings(buf, .toast, component_id, v.title, v.detail),
        .row_item => |v| encodeTwoStrings(buf, .row_item, component_id, v.title, v.detail),
        .rect_color => |v| encodeColor(buf, .rect_color, component_id, v),
        .style_color => |v| encodeColor(buf, .style_color, component_id, v),
    };
}

fn decodeBool(buf: []const u8) ?struct { kind: PatchKind, component_id: u8, value: bool } {
    if (buf.len < 3) return null;
    const kind: PatchKind = @enumFromInt(buf[0]);
    return .{ .kind = kind, .component_id = buf[1], .value = buf[2] != 0 };
}

fn decodeU16(buf: []const u8) ?struct { kind: PatchKind, component_id: u8, value: u16 } {
    if (buf.len < 4) return null;
    const kind: PatchKind = @enumFromInt(buf[0]);
    return .{ .kind = kind, .component_id = buf[1], .value = std.mem.readInt(u16, buf[2..4], .little) };
}

fn decodeF32(buf: []const u8) ?struct { kind: PatchKind, component_id: u8, value: f32 } {
    if (buf.len < 6) return null;
    const kind: PatchKind = @enumFromInt(buf[0]);
    const bits = std.mem.readInt(u32, buf[2..6], .little);
    return .{ .kind = kind, .component_id = buf[1], .value = @bitCast(bits) };
}

fn decodeString(buf: []const u8) ?struct { kind: PatchKind, component_id: u8, value: []const u8 } {
    if (buf.len < 3) return null;
    const str_len: usize = buf[2];
    if (buf.len < 3 + str_len) return null;
    const kind: PatchKind = @enumFromInt(buf[0]);
    return .{ .kind = kind, .component_id = buf[1], .value = buf[3..][0..str_len] };
}

fn decodeTwoStrings(buf: []const u8) ?struct { kind: PatchKind, component_id: u8, a: []const u8, b: []const u8 } {
    if (buf.len < 4) return null;
    const a_len: usize = buf[2];
    if (buf.len < 3 + a_len + 1) return null;
    const b_len: usize = buf[3 + a_len];
    if (buf.len < 4 + a_len + b_len) return null;
    const kind: PatchKind = @enumFromInt(buf[0]);
    return .{
        .kind = kind,
        .component_id = buf[1],
        .a = buf[3..][0..a_len],
        .b = buf[4 + a_len ..][0..b_len],
    };
}

fn decodeTwoStringsBool(buf: []const u8) ?struct { kind: PatchKind, component_id: u8, a: []const u8, b: []const u8, flag: bool } {
    if (buf.len < 5) return null;
    const a_len: usize = buf[2];
    if (buf.len < 3 + a_len + 1) return null;
    const b_len: usize = buf[3 + a_len];
    if (buf.len < 5 + a_len + b_len) return null;
    const kind: PatchKind = @enumFromInt(buf[0]);
    return .{
        .kind = kind,
        .component_id = buf[1],
        .a = buf[3..][0..a_len],
        .b = buf[4 + a_len ..][0..b_len],
        .flag = buf[4 + a_len + b_len] != 0,
    };
}

fn decodeColor(buf: []const u8) ?struct { kind: PatchKind, component_id: u8, color: ui.Color } {
    if (buf.len < 6) return null;
    const kind: PatchKind = @enumFromInt(buf[0]);
    return .{
        .kind = kind,
        .component_id = buf[1],
        .color = .{
            .r = buf[2],
            .g = buf[3],
            .b = buf[4],
            .a = buf[5],
        },
    };
}

pub fn decodePatch(buf: []const u8) ?struct { component_id: u8, patch: ui.Patch } {
    if (buf.len < 2) return null;
    if (buf[0] > @intFromEnum(PatchKind.style_color)) return null;
    const kind: PatchKind = @enumFromInt(buf[0]);
    const tag = kind;
    return switch (tag) {
        .text_value => {
            const d = decodeString(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .text_value = d.value } };
        },
        .accordion_open => {
            const d = decodeBool(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .accordion_open = d.value } };
        },
        .alert => {
            const d = decodeTwoStringsBool(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .alert = .{ .title = d.a, .detail = d.b, .destructive = d.flag } } };
        },
        .alert_dialog => {
            const d = decodeTwoStrings(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .alert_dialog = .{ .title = d.a, .detail = d.b } } };
        },
        .calendar_selected_day => {
            const d = decodeU16(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .calendar_selected_day = d.value } };
        },
        .carousel_label => {
            const d = decodeString(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .carousel_label = d.value } };
        },
        .chart_label => {
            const d = decodeString(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .chart_label = d.value } };
        },
        .combobox_selected => {
            const d = decodeString(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .combobox_selected = d.value } };
        },
        .card_text => {
            const d = decodeTwoStrings(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .card_text = .{ .title = d.a, .detail = d.b } } };
        },
        .empty_text => {
            const d = decodeTwoStrings(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .empty_text = .{ .title = d.a, .detail = d.b } } };
        },
        .badge_label => {
            const d = decodeString(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .badge_label = d.value } };
        },
        .avatar_label => {
            const d = decodeString(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .avatar_label = d.value } };
        },
        .kbd_label => {
            const d = decodeString(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .kbd_label = d.value } };
        },
        .label_value => {
            const d = decodeString(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .label_value = d.value } };
        },
        .breadcrumb_current => {
            const d = decodeString(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .breadcrumb_current = d.value } };
        },
        .menubar_active => {
            const d = decodeU16(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .menubar_active = d.value } };
        },
        .navigation_menu_active => {
            const d = decodeU16(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .navigation_menu_active = d.value } };
        },
        .command_placeholder => {
            const d = decodeString(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .command_placeholder = d.value } };
        },
        .context_menu => {
            const d = decodeTwoStrings(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .context_menu = .{ .first = d.a, .second = d.b } } };
        },
        .dialog => {
            const d = decodeTwoStrings(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .dialog = .{ .title = d.a, .detail = d.b } } };
        },
        .direction_active => {
            const d = decodeU16(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .direction_active = d.value } };
        },
        .drawer => {
            const d = decodeTwoStrings(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .drawer = .{ .title = d.a, .detail = d.b } } };
        },
        .dropdown_menu => {
            const d = decodeTwoStrings(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .dropdown_menu = .{ .first = d.a, .second = d.b } } };
        },
        .field_placeholder => {
            const d = decodeString(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .field_placeholder = d.value } };
        },
        .hover_card_content => {
            const d = decodeString(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .hover_card_content = d.value } };
        },
        .input_otp_value => {
            const d = decodeString(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .input_otp_value = d.value } };
        },
        .button_label => {
            const d = decodeString(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .button_label = d.value } };
        },
        .button_group_active => {
            const d = decodeU16(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .button_group_active = d.value } };
        },
        .toggle_group_active => {
            const d = decodeU16(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .toggle_group_active = d.value } };
        },
        .toggle_pressed => {
            const d = decodeBool(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .toggle_pressed = d.value } };
        },
        .input_placeholder => {
            const d = decodeString(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .input_placeholder = d.value } };
        },
        .input_group_placeholder => {
            const d = decodeString(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .input_group_placeholder = d.value } };
        },
        .textarea_placeholder => {
            const d = decodeString(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .textarea_placeholder = d.value } };
        },
        .select_label => {
            const d = decodeString(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .select_label = d.value } };
        },
        .checkbox_checked => {
            const d = decodeBool(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .checkbox_checked = d.value } };
        },
        .radio_selected => {
            const d = decodeU16(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .radio_selected = d.value } };
        },
        .switch_checked => {
            const d = decodeBool(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .switch_checked = d.value } };
        },
        .pagination_page => {
            const d = decodeU16(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .pagination_page = d.value } };
        },
        .popover_content => {
            const d = decodeString(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .popover_content = d.value } };
        },
        .resizable_ratio => {
            const d = decodeF32(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .resizable_ratio = d.value } };
        },
        .sheet => {
            const d = decodeTwoStrings(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .sheet = .{ .title = d.a, .detail = d.b } } };
        },
        .sidebar_item => {
            const d = decodeString(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .sidebar_item = d.value } };
        },
        .progress_value => {
            const d = decodeF32(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .progress_value = d.value } };
        },
        .slider_value => {
            const d = decodeF32(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .slider_value = d.value } };
        },
        .tabs_active => {
            const d = decodeU16(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .tabs_active = d.value } };
        },
        .table_row => {
            const d = decodeTwoStrings(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .table_row = .{ .name = d.a, .role = d.b } } };
        },
        .tooltip_content => {
            const d = decodeString(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .tooltip_content = d.value } };
        },
        .toast => {
            const d = decodeTwoStrings(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .toast = .{ .title = d.a, .detail = d.b } } };
        },
        .row_item => {
            const d = decodeTwoStrings(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .row_item = .{ .title = d.a, .detail = d.b } } };
        },
        .rect_color => {
            const d = decodeColor(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .rect_color = d.color } };
        },
        .style_color => {
            const d = decodeColor(buf) orelse return null;
            return .{ .component_id = d.component_id, .patch = .{ .style_color = d.color } };
        },
    };
}

test "encode/decode accordion_open bool patch" {
    var buf: [8]u8 = undefined;
    const encoded = encodePatch(&buf, 1, ui.Patch{ .accordion_open = true }).?;
    try std.testing.expectEqual(@as(usize, 3), encoded.len);
    const decoded = decodePatch(encoded).?;
    try std.testing.expectEqual(@as(u8, 1), decoded.component_id);
    try std.testing.expectEqual(true, decoded.patch.accordion_open);
}

test "encode/decode toggle_pressed bool patch" {
    var buf: [8]u8 = undefined;
    const encoded = encodePatch(&buf, 2, ui.Patch{ .toggle_pressed = false }).?;
    try std.testing.expectEqual(@as(usize, 3), encoded.len);
    const decoded = decodePatch(encoded).?;
    try std.testing.expectEqual(@as(u8, 2), decoded.component_id);
    try std.testing.expectEqual(false, decoded.patch.toggle_pressed);
}

test "encode/decode checkbox_checked bool patch" {
    var buf: [8]u8 = undefined;
    const encoded = encodePatch(&buf, 3, ui.Patch{ .checkbox_checked = true }).?;
    try std.testing.expectEqual(@as(usize, 3), encoded.len);
    const decoded = decodePatch(encoded).?;
    try std.testing.expectEqual(@as(u8, 3), decoded.component_id);
    try std.testing.expectEqual(true, decoded.patch.checkbox_checked);
}

test "encode/decode switch_checked bool patch" {
    var buf: [8]u8 = undefined;
    const encoded = encodePatch(&buf, 4, ui.Patch{ .switch_checked = false }).?;
    try std.testing.expectEqual(@as(usize, 3), encoded.len);
    const decoded = decodePatch(encoded).?;
    try std.testing.expectEqual(@as(u8, 4), decoded.component_id);
    try std.testing.expectEqual(false, decoded.patch.switch_checked);
}

test "encode/decode f32 patch round-trips progress_value" {
    var buf: [8]u8 = undefined;
    const encoded = encodePatch(&buf, 5, ui.Patch{ .progress_value = 0.75 }).?;
    try std.testing.expectEqual(@as(usize, 6), encoded.len);
    const decoded = decodePatch(encoded).?;
    try std.testing.expectEqual(@as(u8, 5), decoded.component_id);
    try std.testing.expectEqual(@as(f32, 0.75), decoded.patch.progress_value);
}

test "encode/decode string patch round-trips label_value" {
    var buf: [16]u8 = undefined;
    const encoded = encodePatch(&buf, 2, ui.Patch{ .label_value = "23.5°C" }).?;
    try std.testing.expectEqual(@as(usize, 10), encoded.len);
    const decoded = decodePatch(encoded).?;
    try std.testing.expectEqual(@as(u8, 2), decoded.component_id);
    try std.testing.expectEqualStrings("23.5°C", decoded.patch.label_value);
}

test "encode/decode two-string patch round-trips card_text" {
    var buf: [32]u8 = undefined;
    const encoded = encodePatch(&buf, 3, ui.Patch{ .card_text = .{ .title = "Sensor", .detail = "Active" } }).?;
    const decoded = decodePatch(encoded).?;
    try std.testing.expectEqual(@as(u8, 3), decoded.component_id);
    try std.testing.expectEqualStrings("Sensor", decoded.patch.card_text.title);
    try std.testing.expectEqualStrings("Active", decoded.patch.card_text.detail);
}

test "encode/decode color patch round-trips rect_color" {
    var buf: [8]u8 = undefined;
    const encoded = encodePatch(&buf, 0, ui.Patch{ .rect_color = ui.Color.accent }).?;
    try std.testing.expectEqual(@as(usize, 6), encoded.len);
    const decoded = decodePatch(encoded).?;
    try std.testing.expectEqual(ui.Color.accent.r, decoded.patch.rect_color.r);
    try std.testing.expectEqual(ui.Color.accent.g, decoded.patch.rect_color.g);
    try std.testing.expectEqual(ui.Color.accent.b, decoded.patch.rect_color.b);
}

test "encode/decode fails on short buffer" {
    var buf: [2]u8 = undefined;
    try std.testing.expect(encodePatch(&buf, 0, ui.Patch{ .progress_value = 0.5 }) == null);
    // Empty slice (< 2 bytes) returns null
    try std.testing.expect(decodePatch(&.{}) == null);
}

test "encode returns correct BLE-friendly sizes" {
    var buf: [32]u8 = undefined;
    {
        const p = encodePatch(&buf, 1, ui.Patch{ .switch_checked = true }).?;
        try std.testing.expectEqual(@as(usize, 3), p.len);
    }
    {
        const p = encodePatch(&buf, 2, ui.Patch{ .progress_value = 0.5 }).?;
        try std.testing.expectEqual(@as(usize, 6), p.len);
    }
    {
        const p = encodePatch(&buf, 3, ui.Patch{ .label_value = "23.1" }).?;
        try std.testing.expectEqual(@as(usize, 7), p.len);
    }
}
