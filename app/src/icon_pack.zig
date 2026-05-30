const std = @import("std");
const mem = std.mem;
const icon_vector = @import("icon_vector.zig");

const ir_data = @import("gen/icon_asset_pack_ir.zig").data;
const IndexEntry = @import("gen/icon_asset_pack_index.zig").Entry;
const index_entries = @import("gen/icon_asset_pack_index.zig").entries;

pub const cursor_pointer_2_icon_id: u32 = 40_001;
pub const cursor_hand_finger_icon_id: u32 = 40_002;

pub fn getIr(icon_id: u32) ?[]const f32 {
    const entry = getEntry(icon_id) orelse return null;
    const byte_start = entry.ir_offset;
    const byte_len = entry.ir_len;
    if (byte_start + byte_len > ir_data.len) return null;
    const slice = ir_data[byte_start..][0..byte_len];
    const aligned: []align(4) const u8 = @alignCast(slice);
    return std.mem.bytesAsSlice(f32, aligned);
}

fn getEntry(icon_id: u32) ?IndexEntry {
    if (icon_id == cursor_pointer_2_icon_id) return findEntryByName("pointer-2");
    if (icon_id == cursor_hand_finger_icon_id) return findEntryByName("hand-finger");
    if (icon_id == 0 or icon_id > index_entries.len) return null;
    return index_entries[icon_id - 1];
}

fn findEntryByName(name: []const u8) ?IndexEntry {
    for (index_entries) |entry| {
        if (std.mem.eql(u8, entry.name, name)) return entry;
    }
    return null;
}

test "asset pack has tabler icons" {
    try std.testing.expect(index_entries.len > 5000);
}

test "asset pack contains cursor icons" {
    try std.testing.expect(findEntryByName("pointer-2") != null);
    try std.testing.expect(findEntryByName("hand-finger") != null);
}

test "cursor icon ids resolve to valid entries" {
    const pointer = getIr(cursor_pointer_2_icon_id) orelse return error.TestFailed;
    const hand = getIr(cursor_hand_finger_icon_id) orelse return error.TestFailed;
    try std.testing.expect(pointer.len > 0);
    try std.testing.expect(hand.len > 0);
}

test "getIr returns null for unknown icon id" {
    try std.testing.expectEqual(@as(?[]const f32, null), getIr(0));
    try std.testing.expectEqual(@as(?[]const f32, null), getIr(999_999));
}
