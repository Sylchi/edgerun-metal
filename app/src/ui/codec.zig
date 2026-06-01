const std = @import("std");
const bytes = @import("../bytes.zig");
const clock = @import("../clock.zig");
const object = @import("../object.zig");
const store = @import("../store.zig");
const identity = @import("../identity.zig");
const preimage = @import("../preimage.zig");
const ui = @import("core.zig");

pub const magic = "ERuI\x00\x00\x00\x00";
pub const header_size: usize = 20;
pub const record_size: usize = 16;

pub const RecordKind = enum(u16) {
    rect,
    text,
    slot,
    accordion,
    alert,
    alert_dialog,
    aspect_ratio,
    calendar,
    carousel,
    chart,
    combobox,
    empty,
    button,
    icon_button,
    button_group,
    toggle_group,
    input,
    input_group,
    input_otp,
    textarea,
    select,
    field,
    checkbox,
    switch_control,
    slider,
    radio_group,
    row_item,
    badge,
    card,
    avatar,
    kbd,
    label,
    table,
    separator,
    scroll_area,
    skeleton,
    spinner,
    progress,
    breadcrumb,
    menubar,
    navigation_menu,
    pagination,
    tabs,
    direction,
    command,
    context_menu,
    dialog,
    drawer,
    dropdown_menu,
    hover_card,
    popover,
    tooltip,
    toast,
    sheet,
    sidebar,
    icon,
    toggle,
    resizable,
    _,
};

test "ui writer round-trips through store" {
    var raw_ui: [128]u8 = undefined;
    var cursor = Writer.init(&raw_ui, 1, 1, .column, 0, 0).?;
    const label = cursor.string("From store");
    try std.testing.expect(cursor.record(0, .button, 42, label.?, .{}));

    var data: [512]u8 = undefined;
    var slots: [2]store.Blob = undefined;
    var s = store.Store.init(.{ .base = &data }, &slots);

    var keeper = [_]u8{0} ** 32;
    keeper[0] = 1;
    const epoch = clock.Stamp{ .keeper = .{ .bytes = keeper } };
    const app = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("ui")).?, epoch).?;
    const req = object.Requirements{
        .durability = .memory,
        .confidentiality = .public,
        .portability = .public_portable,
        .integrity = .hash_only,
        .lifetime = .transient,
        .visibility = .public,
        .access = .hot_memory_allowed,
    };

    var canonical: [object.header_size + 128]u8 = undefined;
    const canonical_node = cursor.objectNode(&canonical, req, epoch).?;
    const object_id = s.putObject(app.id, canonical_node).?;
    const view = s.getObject(app.id, object_id).?;

    var nodes: [1]ui.Node = undefined;
    const root = try decodeView(view, &nodes);
    try std.testing.expectEqual(@as(u32, 42), root.stack.children[0].button.id);
    try std.testing.expectEqualStrings("From store", root.stack.children[0].button.label);
}

test "ui writer rejects invalid budgets and out of range records" {
    var too_small: [header_size]u8 = undefined;
    try std.testing.expect(Writer.init(&too_small, 1, 1, .column, 0, 0) == null);

    var raw: [header_size + record_size + 4]u8 = undefined;
    var writer = Writer.init(&raw, 1, 1, .column, 0, 0).?;
    try std.testing.expect(Writer.init(&raw, 0, 0, .column, 0, 0) == null);
    try std.testing.expect(Writer.init(&raw, 1, 2, .column, 0, 0) == null);

    const label = writer.string("test").?;
    try std.testing.expect(writer.string("x") == null);
    try std.testing.expect(!writer.record(1, .button, 1, label, .{}));
    try std.testing.expect(writer.record(0, .button, 1, label, .{}));
}

test "ui writer wraps payloads as owned canonical objects" {
    var raw_ui: [128]u8 = undefined;
    var writer = Writer.init(&raw_ui, 1, 1, .column, 0, 0).?;
    const label = writer.string("Owned").?;
    try std.testing.expect(writer.record(0, .button, 5, label, .{}));

    var keeper = [_]u8{0} ** 32;
    keeper[0] = 1;
    const epoch = clock.Stamp{ .keeper = .{ .bytes = keeper } };
    const req = object.Requirements{
        .durability = .durable,
        .confidentiality = .app_private,
        .portability = .machine_bound,
        .integrity = .sealed,
        .lifetime = .retained,
        .visibility = .private,
        .access = .explicit_io,
    };
    const owner = object.Owner{
        .kind = .app,
        .node_id = [_]u8{1} ++ [_]u8{0} ** 31,
    };
    const envelope = object.Envelope{
        .kind = .app,
        .owner_index = 0,
        .algorithm = .aes_gcm_256,
        .flags = 0,
        .key_id = [_]u8{2} ++ [_]u8{0} ** 31,
        .metadata_hash = [_]u8{3} ++ [_]u8{0} ** 31,
    };

    var canonical: [object.header_size + object.owner_size + object.envelope_size + 128]u8 = undefined;
    const canonical_node = writer.objectNodeOwned(&canonical, req, epoch, &.{owner}, &.{envelope}).?;
    const view = try object.View.decode(canonical_node);
    try std.testing.expectEqual(object.Kind.bytes, view.header.kind);
    try std.testing.expectEqual(@as(u16, 1), view.header.owner_count);
    try std.testing.expectEqual(@as(u16, 1), view.header.envelope_count);

    var nodes: [1]ui.Node = undefined;
    const root = try decodeView(view, &nodes);
    try std.testing.expectEqual(@as(u32, 5), root.stack.children[0].button.id);
    try std.testing.expectEqualStrings("Owned", root.stack.children[0].button.label);
}

pub const StringRef = struct {
    offset: u16 = 0,
    len: u16 = 0,
};

pub const Writer = struct {
    raw: []u8,
    node_count: u16,
    cursor: usize,

    pub fn init(raw: []u8, node_count: u16, root_count: u16, axis: ui.Axis, gap: u16, padding: u16) ?Writer {
        if (node_count == 0 or root_count == 0 or root_count > node_count) return null;
        const records_len = @as(usize, node_count) * record_size;
        if (raw.len < header_size + records_len) return null;

        @memset(raw, 0);
        @memcpy(raw[0..magic.len], magic);
        _ = bytes.store16(raw[8..10], 1);
        _ = bytes.store16(raw[10..12], switch (axis) {
            .column => 0,
            .row => 1,
        });
        _ = bytes.store16(raw[12..14], gap);
        _ = bytes.store16(raw[14..16], padding);
        _ = bytes.store16(raw[16..18], node_count);
        _ = bytes.store16(raw[18..20], root_count);
        return .{
            .raw = raw,
            .node_count = node_count,
            .cursor = header_size + @as(usize, node_count) * record_size,
        };
    }

    pub fn string(self: *Writer, value: []const u8) ?StringRef {
        const table_start = header_size + @as(usize, self.node_count) * record_size;
        const offset = self.cursor - table_start;
        if (offset > 0xFFFF or value.len > 0xFFFF) return null;
        if (value.len > self.raw.len - self.cursor) return null;
        @memcpy(self.raw[self.cursor..][0..value.len], value);
        self.cursor += value.len;
        return .{ .offset = @intCast(offset), .len = @intCast(value.len) };
    }

    pub fn record(self: Writer, index: usize, kind: RecordKind, id: u32, first: StringRef, second: StringRef) bool {
        if (index >= self.node_count) return false;
        const offset = header_size + index * record_size;
        const record_bytes = self.raw[offset..][0..record_size];
        _ = bytes.store16(record_bytes[0..2], @intFromEnum(kind));
        _ = bytes.store32(record_bytes[4..8], id);
        _ = bytes.store16(record_bytes[8..10], first.offset);
        _ = bytes.store16(record_bytes[10..12], first.len);
        _ = bytes.store16(record_bytes[12..14], second.offset);
        _ = bytes.store16(record_bytes[14..16], second.len);
        return true;
    }

    pub fn written(self: Writer) []const u8 {
        return self.raw[0..self.cursor];
    }

    pub fn objectNode(self: Writer, out: []u8, req: object.Requirements, epoch: clock.Stamp) ?[]u8 {
        return self.objectNodeOwned(out, req, epoch, &.{}, &.{});
    }

    pub fn objectNodeOwned(self: Writer, out: []u8, req: object.Requirements, epoch: clock.Stamp, owners: []const object.Owner, envelopes: []const object.Envelope) ?[]u8 {
        const object_writer = object.NodeWriter{ .out = out };
        return object_writer.bytesNodeOwned(req, epoch, owners, envelopes, self.written()) catch return null;
    }
};

pub fn decodeView(view: object.View, nodes: []ui.Node) Error!ui.Node {
    if (view.header.kind != .bytes) return error.Corrupt;
    return decodeBytes(view.body, nodes) catch return error.Corrupt;
}

pub fn decodeBytes(bytes_in: []const u8, nodes: []ui.Node) Error!ui.Node {
    if (bytes_in.len < header_size) return error.Corrupt;
    const node_count: usize = std.mem.readInt(u16, bytes_in[16..18], .little);
    if (node_count == 0 or node_count > nodes.len) return error.Corrupt;
    const axis: ui.Axis = switch (std.mem.readInt(u16, bytes_in[10..12], .little)) {
        0 => .column,
        1 => .row,
        else => return error.Corrupt,
    };
    const gap = std.mem.readInt(u16, bytes_in[12..14], .little);
    const padding = std.mem.readInt(u16, bytes_in[14..16], .little);

    for (0..node_count) |i| {
        const offset = header_size + i * record_size;
        if (offset + record_size > bytes_in.len) return error.Corrupt;
        const record = bytes_in[offset..][0..record_size];
        const kind: RecordKind = @enumFromInt(std.mem.readInt(u16, record[0..2], .little));
        const id = std.mem.readInt(u32, record[4..8], .little);
        const first_ref = StringRef{
            .offset = std.mem.readInt(u16, record[8..10], .little),
            .len = std.mem.readInt(u16, record[10..12], .little),
        };
        const second_ref = StringRef{
            .offset = std.mem.readInt(u16, record[12..14], .little),
            .len = std.mem.readInt(u16, record[14..16], .little),
        };
        const table_start = header_size + node_count * record_size;
        const first_str = refToSlice(bytes_in, table_start, first_ref);
        const second_str = refToSlice(bytes_in, table_start, second_ref);

        nodes[i] = recordToNode(kind, id, first_str, second_str, second_ref);
    }

    return ui.Node{ .stack = .{
        .axis = axis,
        .gap = gap,
        .padding = padding,
        .children = nodes[0..node_count],
    } };
}

fn refToSlice(bytes_in: []const u8, table_start: usize, ref: StringRef) []const u8 {
    if (ref.len == 0) return "";
    const start = table_start + ref.offset;
    if (start + ref.len > bytes_in.len) return "";
    return bytes_in[start..][0..ref.len];
}

fn recordToNode(kind: RecordKind, id: u32, first: []const u8, second: []const u8, second_ref: StringRef) ui.Node {
    return switch (kind) {
        .rect => ui.Node{ .rect = .{ .color = ui.Color.clear } },
        .text => ui.Node{ .text = .{ .value = first } },
        .slot => ui.Node{ .slot = .{ .id = id, .child = undefined } },
        .accordion => ui.Node{ .accordion = .{ .id = id / 2, .title = first, .detail = second, .open = (id & 1) != 0 } },
        .alert => ui.Node{ .alert = .{ .title = first, .detail = second, .destructive = (id & 1) != 0, .icon = @truncate(id >> 1) } },
        .alert_dialog => ui.Node{ .alert_dialog = .{ .id = id, .title = first, .detail = second } },
        .button => {
            const tag = second_ref.offset;
            const trailing = (second_ref.len >> 8) != 0;
            return ui.Node{ .button = .{ .id = id, .label = first, .variant = second_ref.len & 0xFF, .leading_icon = if (trailing) 0 else tag, .trailing_icon = if (trailing) tag else 0 } };
        },
        .icon_button => ui.Node{ .icon_button = .{ .id = id, .label = first, .variant = second_ref.offset, .icon = second_ref.len } },
        .button_group => ui.Node{ .button_group = .{ .id = id / 2, .first = first, .second = second, .active = @truncate(id % 2) } },
        .toggle_group => ui.Node{ .toggle_group = .{ .id = id / 3, .first = first, .second = second, .active = @truncate(id % 3) } },
        .input => ui.Node{ .input = .{ .id = id, .placeholder = first, .leading_icon = second_ref.offset } },
        .input_group => ui.Node{ .input_group = .{ .id = id, .addon = first, .placeholder = second } },
        .input_otp => ui.Node{ .input_otp = .{ .id = id, .value = first } },
        .textarea => ui.Node{ .textarea = .{ .id = id, .placeholder = first } },
        .select => ui.Node{ .select = .{ .id = id, .label = first, .trailing_icon = second_ref.offset } },
        .field => ui.Node{ .field = .{ .id = id, .label = first, .placeholder = second } },
        .checkbox => ui.Node{ .checkbox = .{ .id = id, .label = first, .checked = second_ref.offset != 0 } },
        .switch_control => ui.Node{ .switch_control = .{ .id = id, .label = first, .checked = second_ref.offset != 0 } },
        .slider => ui.Node{ .slider = .{ .id = id, .label = first, .value = ui.decodeUnit(second_ref.offset) } },
        .radio_group => ui.Node{ .radio_group = .{ .id = id / 2, .first = first, .second = second, .selected = @truncate(id % 2) } },
        .row_item => ui.Node{ .row_item = .{ .id = id >> 14, .title = first, .detail = second, .icon = @truncate(id & 0x3FFF) } },
        .badge => ui.Node{ .badge = .{ .label = first, .variant = second_ref.offset } },
        .card => ui.Node{ .card = .{ .title = first, .detail = second, .variant = @truncate(id) } },
        .avatar => ui.Node{ .avatar = .{ .label = first } },
        .kbd => ui.Node{ .kbd = .{ .label = first } },
        .label => ui.Node{ .label = .{ .value = first } },
        .table => ui.Node{ .table = .{ .id = id, .name = first, .role = second } },
        .separator => ui.Node{ .separator = {} },
        .scroll_area => ui.Node{ .scroll_area = {} },
        .skeleton => ui.Node{ .skeleton = {} },
        .spinner => ui.Node{ .spinner = {} },
        .progress => ui.Node{ .progress = .{ .value = ui.decodeUnit(second_ref.offset) } },
        .breadcrumb => ui.Node{ .breadcrumb = .{ .id = id, .first = first, .current = second } },
        .menubar => ui.Node{ .menubar = .{ .id = id / 3, .first = first, .second = second, .active = @truncate(id % 3) } },
        .navigation_menu => ui.Node{ .navigation_menu = .{ .id = id / 3, .first = first, .second = second, .active = @truncate(id % 3) } },
        .pagination => ui.Node{ .pagination = .{ .id = id / 3, .page = @truncate(id % 3) } },
        .tabs => ui.Node{ .tabs = .{ .id = id / 2, .first = first, .second = second, .active = @truncate(id % 2) } },
        .direction => ui.Node{ .direction = .{ .id = id / 2, .active = @truncate(id % 2) } },
        .command => ui.Node{ .command = .{ .id = id, .placeholder = first, .leading_icon = second_ref.offset } },
        .context_menu => ui.Node{ .context_menu = .{ .id = id, .first = first, .second = second } },
        .dialog => ui.Node{ .dialog = .{ .id = id, .title = first, .detail = second } },
        .drawer => ui.Node{ .drawer = .{ .id = id, .title = first, .detail = second } },
        .dropdown_menu => ui.Node{ .dropdown_menu = .{ .id = id, .first = first, .second = second } },
        .hover_card => ui.Node{ .hover_card = .{ .id = id, .trigger = first, .content = second } },
        .popover => ui.Node{ .popover = .{ .id = id, .trigger = first, .content = second } },
        .tooltip => ui.Node{ .tooltip = .{ .id = id, .trigger = first, .content = second } },
        .toast => ui.Node{ .toast = .{ .id = id, .title = first, .detail = second } },
        .sheet => ui.Node{ .sheet = .{ .id = id, .title = first, .detail = second } },
        .sidebar => ui.Node{ .sidebar = .{ .id = id, .title = first, .item = second } },
        .icon => ui.Node{ .icon = .{ .label = first, .icon = second_ref.len } },
        .toggle => ui.Node{ .toggle = .{ .id = id, .label = first, .pressed = second_ref.offset != 0 } },
        .resizable => ui.Node{ .resizable = .{ .id = id, .ratio = ui.decodeUnit(second_ref.offset) } },
        .calendar => ui.Node{ .calendar = .{ .id = id, .month = first, .selected_day = second_ref.offset } },
        .carousel => ui.Node{ .carousel = .{ .id = id, .label = first } },
        .chart => ui.Node{ .chart = .{ .id = id, .label = first } },
        .combobox => ui.Node{ .combobox = .{ .id = id, .placeholder = first, .selected = second } },
        .empty => ui.Node{ .empty = .{ .title = first, .detail = second, .icon = @truncate(id) } },
        .aspect_ratio => ui.Node{ .aspect_ratio = .{ .ratio_w = second_ref.offset, .ratio_h = second_ref.len } },
        else => ui.Node{ .text = .{ .value = "" } },
    };
}

pub const Error = error{
    Corrupt,
};

/// Wire format: [kind:1][component_id:1][kind-specific payload]. Strings are
/// encoded as [len:1][bytes], so every string payload is bounded to 255 bytes.
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

pub const BleFrameKind = enum(u8) {
    patch = 1,
    tree = 2,
    heartbeat = 3,
    route = 4,
};

pub const ble_company_id: u16 = 0xffff;
pub const ble_frame_magic = "ERUI";
pub const ble_frame_version: u8 = 1;
pub const ble_frame_header_size: usize = 8;
pub const ble_legacy_ad_max: usize = 31;
const ble_manufacturer_type: u8 = 0xff;
const ble_company_id_size: usize = 2;
const ble_ad_header_size: usize = 2;
const ble_manufacturer_ad_overhead: usize = ble_ad_header_size + ble_company_id_size;
pub const ble_legacy_payload_max: usize = ble_legacy_ad_max - ble_manufacturer_ad_overhead;

pub const BleFrame = struct {
    stream_id: u8,
    sequence: u8,
    kind: BleFrameKind,
    body: []const u8,
};

pub const BleRoute = struct {
    route_id: u8,
    flags: u8,
    name: []const u8,
};

pub fn encodeBleFrame(buf: []u8, stream_id: u8, sequence: u8, kind: BleFrameKind, body: []const u8) ?[]u8 {
    const total = ble_frame_header_size + body.len;
    if (total > ble_legacy_payload_max or buf.len < total) return null;
    @memcpy(buf[0..ble_frame_magic.len], ble_frame_magic);
    buf[4] = ble_frame_version;
    buf[5] = stream_id;
    buf[6] = sequence;
    buf[7] = @intFromEnum(kind);
    @memcpy(buf[ble_frame_header_size..][0..body.len], body);
    return buf[0..total];
}

pub fn decodeBleFrame(buf: []const u8) ?BleFrame {
    if (buf.len < ble_frame_header_size or buf.len > ble_legacy_payload_max) return null;
    if (!std.mem.eql(u8, buf[0..ble_frame_magic.len], ble_frame_magic)) return null;
    if (buf[4] != ble_frame_version) return null;
    if (buf[7] < @intFromEnum(BleFrameKind.patch) or buf[7] > @intFromEnum(BleFrameKind.route)) return null;
    return .{
        .stream_id = buf[5],
        .sequence = buf[6],
        .kind = @enumFromInt(buf[7]),
        .body = buf[ble_frame_header_size..],
    };
}

pub fn encodeBleRoute(buf: []u8, route_id: u8, flags: u8, name: []const u8) ?[]u8 {
    const total = 3 + name.len;
    if (name.len > 0xff or total > buf.len) return null;
    buf[0] = route_id;
    buf[1] = flags;
    buf[2] = @intCast(name.len);
    @memcpy(buf[3..][0..name.len], name);
    return buf[0..total];
}

pub fn decodeBleRoute(buf: []const u8) ?BleRoute {
    if (buf.len < 3) return null;
    const name_len: usize = buf[2];
    if (buf.len != 3 + name_len) return null;
    return .{
        .route_id = buf[0],
        .flags = buf[1],
        .name = buf[3..],
    };
}

pub fn encodeBleManufacturerAd(buf: []u8, frame_payload: []const u8) ?[]u8 {
    const ad_len = 1 + ble_company_id_size + frame_payload.len;
    const total = ble_ad_header_size + ble_company_id_size + frame_payload.len;
    if (frame_payload.len > ble_legacy_payload_max or ad_len > 0xff or buf.len < total) return null;
    buf[0] = @intCast(ad_len);
    buf[1] = ble_manufacturer_type;
    std.mem.writeInt(u16, buf[2..4], ble_company_id, .little);
    @memcpy(buf[4..][0..frame_payload.len], frame_payload);
    return buf[0..total];
}

pub fn decodeBleManufacturerAd(scan_record: []const u8) ?BleFrame {
    var index: usize = 0;
    while (index < scan_record.len) {
        const ad_len: usize = scan_record[index];
        if (ad_len == 0) return null;
        const next = index + 1 + ad_len;
        if (next > scan_record.len) return null;
        const ad = scan_record[index + 1 .. next];
        if (ad.len >= 1 + ble_company_id_size and ad[0] == ble_manufacturer_type) {
            if (std.mem.readInt(u16, ad[1..3], .little) == ble_company_id) {
                return decodeBleFrame(ad[3..]);
            }
        }
        index = next;
    }
    return null;
}

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
    if (value.len > 0xff) return null;
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
    if (a.len > 0xff or b.len > 0xff) return null;
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
    if (a.len > 0xff or b.len > 0xff) return null;
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

test "ble frame wraps existing ui patch wire bytes" {
    var patch_buf: [16]u8 = undefined;
    const patch = encodePatch(&patch_buf, 1, ui.Patch{ .text_value = "ON" }).?;

    var frame_buf: [ble_legacy_payload_max]u8 = undefined;
    const frame = encodeBleFrame(&frame_buf, 7, 42, .patch, patch).?;
    try std.testing.expect(frame.len <= ble_legacy_payload_max);

    const decoded_frame = decodeBleFrame(frame).?;
    try std.testing.expectEqual(@as(u8, 7), decoded_frame.stream_id);
    try std.testing.expectEqual(@as(u8, 42), decoded_frame.sequence);
    try std.testing.expectEqual(BleFrameKind.patch, decoded_frame.kind);

    const decoded_patch = decodePatch(decoded_frame.body).?;
    try std.testing.expectEqual(@as(u8, 1), decoded_patch.component_id);
    try std.testing.expectEqualStrings("ON", decoded_patch.patch.text_value);
}

test "ble manufacturer advertisement decodes from tv scan record bytes" {
    var patch_buf: [16]u8 = undefined;
    const patch = encodePatch(&patch_buf, 1, ui.Patch{ .switch_checked = true }).?;

    var frame_buf: [ble_legacy_payload_max]u8 = undefined;
    const frame = encodeBleFrame(&frame_buf, 3, 21, .patch, patch).?;

    var scan_record: [ble_legacy_ad_max]u8 = undefined;
    const ad = encodeBleManufacturerAd(&scan_record, frame).?;

    const decoded_frame = decodeBleManufacturerAd(ad).?;
    try std.testing.expectEqual(@as(u8, 3), decoded_frame.stream_id);
    try std.testing.expectEqual(@as(u8, 21), decoded_frame.sequence);
    try std.testing.expectEqual(BleFrameKind.patch, decoded_frame.kind);

    const decoded_patch = decodePatch(decoded_frame.body).?;
    try std.testing.expectEqual(@as(u8, 1), decoded_patch.component_id);
    try std.testing.expect(decoded_patch.patch.switch_checked);
}

test "ble frame rejects corrupt or oversized payloads" {
    var frame_buf: [ble_legacy_payload_max]u8 = undefined;
    var oversized: [ble_legacy_payload_max - ble_frame_header_size + 1]u8 = undefined;
    try std.testing.expect(encodeBleFrame(&frame_buf, 0, 0, .patch, &oversized) == null);

    const frame = encodeBleFrame(&frame_buf, 1, 2, .heartbeat, &.{}) orelse return error.TestUnexpectedResult;
    frame_buf[0] = 'x';
    try std.testing.expect(decodeBleFrame(frame) == null);
}

test "ble route advertisement identifies a self route" {
    var route_buf: [16]u8 = undefined;
    const route = encodeBleRoute(&route_buf, 9, 1, "tv").?;

    var frame_buf: [ble_legacy_payload_max]u8 = undefined;
    const frame = encodeBleFrame(&frame_buf, 2, 8, .route, route).?;
    const decoded_frame = decodeBleFrame(frame).?;
    try std.testing.expectEqual(BleFrameKind.route, decoded_frame.kind);

    const decoded_route = decodeBleRoute(decoded_frame.body).?;
    try std.testing.expectEqual(@as(u8, 9), decoded_route.route_id);
    try std.testing.expectEqual(@as(u8, 1), decoded_route.flags);
    try std.testing.expectEqualStrings("tv", decoded_route.name);
}

test "encode/decode patch round-trips typed payloads" {
    const Case = struct {
        component_id: u8,
        patch: ui.Patch,
        encoded_len: usize,
    };
    const cases = [_]Case{
        .{ .component_id = 1, .patch = .{ .accordion_open = true }, .encoded_len = 3 },
        .{ .component_id = 2, .patch = .{ .toggle_pressed = false }, .encoded_len = 3 },
        .{ .component_id = 3, .patch = .{ .checkbox_checked = true }, .encoded_len = 3 },
        .{ .component_id = 4, .patch = .{ .switch_checked = false }, .encoded_len = 3 },
        .{ .component_id = 5, .patch = .{ .progress_value = 0.75 }, .encoded_len = 6 },
        .{ .component_id = 2, .patch = .{ .label_value = "23.5°C" }, .encoded_len = 10 },
        .{ .component_id = 3, .patch = .{ .card_text = .{ .title = "Sensor", .detail = "Active" } }, .encoded_len = 16 },
        .{ .component_id = 0, .patch = .{ .rect_color = ui.Color.accent }, .encoded_len = 6 },
    };

    for (cases) |case| {
        var buf: [32]u8 = undefined;
        const encoded = encodePatch(&buf, case.component_id, case.patch).?;
        try std.testing.expectEqual(case.encoded_len, encoded.len);
        const decoded = decodePatch(encoded).?;
        try std.testing.expectEqual(case.component_id, decoded.component_id);
        try expectPatchEqual(case.patch, decoded.patch);
    }
}

fn expectPatchEqual(expected: ui.Patch, actual: ui.Patch) !void {
    try std.testing.expectEqual(std.meta.activeTag(expected), std.meta.activeTag(actual));
    switch (expected) {
        .accordion_open => |value| try std.testing.expectEqual(value, actual.accordion_open),
        .toggle_pressed => |value| try std.testing.expectEqual(value, actual.toggle_pressed),
        .checkbox_checked => |value| try std.testing.expectEqual(value, actual.checkbox_checked),
        .switch_checked => |value| try std.testing.expectEqual(value, actual.switch_checked),
        .progress_value => |value| try std.testing.expectEqual(value, actual.progress_value),
        .label_value => |value| try std.testing.expectEqualStrings(value, actual.label_value),
        .card_text => |value| {
            try std.testing.expectEqualStrings(value.title, actual.card_text.title);
            try std.testing.expectEqualStrings(value.detail, actual.card_text.detail);
        },
        .rect_color => |value| try std.testing.expectEqual(value, actual.rect_color),
        else => return error.UnsupportedPatchTestCase,
    }
}

test "encode/decode fails on short buffer" {
    var buf: [2]u8 = undefined;
    try std.testing.expect(encodePatch(&buf, 0, ui.Patch{ .progress_value = 0.5 }) == null);
    // Empty slice (< 2 bytes) returns null
    try std.testing.expect(decodePatch(&.{}) == null);
}

test "encode rejects overlong string payloads without truncation" {
    var buf: [512]u8 = undefined;
    const long = "x" ** 256;
    try std.testing.expect(encodePatch(&buf, 1, ui.Patch{ .label_value = long }) == null);
    try std.testing.expect(encodePatch(&buf, 2, ui.Patch{ .card_text = .{ .title = long, .detail = "ok" } }) == null);
    try std.testing.expect(encodePatch(&buf, 3, ui.Patch{ .alert = .{ .title = "ok", .detail = long, .destructive = false } }) == null);
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
