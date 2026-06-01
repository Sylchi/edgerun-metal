const bytes = @import("../../bytes.zig");
const common = @import("../component_common.zig");
const component_codec = @import("Codec.zig");
const object = @import("../../object.zig");
const ui = @import("../core.zig");

const Error = common.Error;

pub const tree_layout_magic = "ERUL001\x00";
pub const tree_layout_size = 16;
pub const slot_layout_magic = "ERUS001\x00";
pub const slot_layout_size = 16;
pub const tree_max_children = 64;

pub const TreeObjects = struct {
    layout: []const u8,
    tree: []const u8,
};

pub const TreeLayout = struct {
    axis: ui.Axis,
    gap: u16,
    padding: u16,
    child_count: usize,
};

pub fn encodeTreeLayout(axis: ui.Axis, gap: u16, padding: u16, child_count: u16, out: []u8) ?void {
    if (out.len < tree_layout_size) return null;
    @memset(out[0..tree_layout_size], 0);
    @memcpy(out[0..tree_layout_magic.len], tree_layout_magic);
    out[8] = switch (axis) {
        .column => 0,
        .row => 1,
    };
    out[9] = 0;
    _ = bytes.store16(out[10..12], gap);
    _ = bytes.store16(out[12..14], padding);
    _ = bytes.store16(out[14..16], child_count);
}

pub fn decodeTreeLayout(view: object.View) Error!TreeLayout {
    try component_codec.validateView(view);
    if (view.header.kind != .bytes or view.body.len != tree_layout_size) return error.Corrupt;
    if (!bytes.eql(view.body[0..tree_layout_magic.len], tree_layout_magic)) return error.Corrupt;
    if (view.body[9] != 0) return error.Corrupt;
    return .{
        .axis = switch (view.body[8]) {
            0 => .column,
            1 => .row,
            else => return error.Corrupt,
        },
        .gap = bytes.load16(view.body[10..12]) orelse return error.Corrupt,
        .padding = bytes.load16(view.body[12..14]) orelse return error.Corrupt,
        .child_count = bytes.load16(view.body[14..16]) orelse return error.Corrupt,
    };
}

pub fn isTreeLayout(view: object.View) bool {
    component_codec.validateView(view) catch return false;
    return view.header.kind == .bytes and
        view.body.len == tree_layout_size and
        bytes.eql(view.body[0..tree_layout_magic.len], tree_layout_magic);
}

pub fn encodeSlotLayout(id: u32, out: []u8) ?void {
    if (out.len < slot_layout_size) return null;
    @memset(out[0..slot_layout_size], 0);
    @memcpy(out[0..slot_layout_magic.len], slot_layout_magic);
    _ = bytes.store32(out[8..12], id);
}

pub fn decodeSlotLayout(view: object.View) Error!u32 {
    try component_codec.validateView(view);
    if (view.header.kind != .bytes or view.body.len != slot_layout_size) return error.Corrupt;
    if (!bytes.eql(view.body[0..slot_layout_magic.len], slot_layout_magic)) return error.Corrupt;
    return bytes.load32(view.body[8..12]) orelse error.Corrupt;
}

pub fn isSlotLayout(view: object.View) bool {
    component_codec.validateView(view) catch return false;
    return view.header.kind == .bytes and
        view.body.len == slot_layout_size and
        bytes.eql(view.body[0..slot_layout_magic.len], slot_layout_magic);
}

pub fn childRecord(view: object.View, offset: u64) Error!object.Child {
    return object.Child.fromView(view, offset) catch return error.Corrupt;
}

pub fn sameId(left: [object.id_size]u8, right: [object.id_size]u8) bool {
    return bytes.eql(&left, &right);
}
