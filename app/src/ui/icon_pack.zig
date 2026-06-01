const bytes = @import("../bytes.zig");
const icon_vector = @import("icon_vector.zig");
const icon = @import("icon.zig");

const ir_src = @embedFile("../gen/icon_asset_pack_ir.bin");
const ir_storage: [ir_src.len]u8 align(4) = blk: {
    var arr: [ir_src.len]u8 align(4) = undefined;
    @memcpy(&arr, ir_src);
    break :blk arr;
};
const ir_bytes: []const u8 = &ir_storage;

const index_bytes = @embedFile("../gen/icon_asset_pack_index.bin");

const names_bytes = @embedFile("../gen/icon_names.bin");

pub const icon_count: u32 = bytes.load32(index_bytes[4..8]).?;

pub fn iconId(ic: icon.Icon) u32 {
    @setEvalBranchQuota(100000);
    const raw = @tagName(ic);
    var name_buf: [128]u8 = undefined;
    var j: usize = 0;
    for (raw) |c| {
        name_buf[j] = if (c == '_') '-' else c;
        j += 1;
    }
    const name = name_buf[0..j];
    var pos: u32 = 0;
    var off: usize = 0;
    while (off < names_bytes.len) {
        pos += 1;
        var end: usize = off;
        while (end < names_bytes.len and names_bytes[end] != 0) : (end += 1) {}
        if (end >= names_bytes.len) break;
        const n = names_bytes[off..end];
        if (bytes.eql(n, name)) return pos;
        off = end + 1;
    }
    return 0;
}

pub const cursor_pointer_2_icon_id: u32 = iconId(.pointer_2);
pub const cursor_hand_finger_icon_id: u32 = iconId(.hand_finger);

pub fn getIr(icon_id: u32) ?[]const f32 {
    if (icon_id == 0 or icon_id > icon_count) return null;
    const off: usize = 8 + (icon_id - 1) * 8;
    const ir_offset = bytes.load32(index_bytes[off..][0..4]).?;
    const ir_len = bytes.load32(index_bytes[off + 4 ..][0..4]).?;
    if (ir_offset + ir_len > ir_bytes.len) return null;
    const aligned: []align(4) const u8 = @alignCast(ir_bytes[ir_offset..][0..ir_len]);
    return @as([*]align(4) const f32, @ptrCast(aligned.ptr))[0 .. ir_len / @sizeOf(f32)];
}

test "asset pack has tabler icons" {
    if (icon_count <= 5000) return error.TestExpectedTrue;
}

test "iconId returns correct positions" {
    if (iconId(.dashboard) == 0) return error.TestExpectedTrue;
    if (iconId(.circle_check) == 0) return error.TestExpectedTrue;
    if (iconId(.circle_x) == 0) return error.TestExpectedTrue;
    if (iconId(.git_commit) == 0) return error.TestExpectedTrue;
    if (iconId(.dashboard) == iconId(.circle_check)) return error.TestExpectedNotEqual;
}

test "asset pack contains cursor icons" {
    if (getIr(cursor_pointer_2_icon_id) == null) return error.TestExpectedValue;
    if (getIr(cursor_hand_finger_icon_id) == null) return error.TestExpectedValue;
}

test "getIr returns non-empty data for cursor icons" {
    const pointer = getIr(cursor_pointer_2_icon_id) orelse return error.TestFailed;
    const hand = getIr(cursor_hand_finger_icon_id) orelse return error.TestFailed;
    if (pointer.len == 0) return error.TestExpectedTrue;
    if (hand.len == 0) return error.TestExpectedTrue;
}

test "getIr returns null for unknown icon id" {
    if (getIr(0) != null) return error.TestExpectedNull;
    if (getIr(999_999) != null) return error.TestExpectedNull;
}
