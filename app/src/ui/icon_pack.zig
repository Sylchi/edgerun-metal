const std = @import("std");
const mem = std.mem;
const icon_vector = @import("icon_vector.zig");
const icon = @import("icon.zig");

const ir_src = @embedFile("gen/icon_asset_pack_ir.bin");
const ir_storage: [ir_src.len]u8 align(4) = blk: {
    var arr: [ir_src.len]u8 align(4) = undefined;
    @memcpy(&arr, ir_src);
    break :blk arr;
};
const ir_bytes: []const u8 = &ir_storage;

const index_bytes = @embedFile("gen/icon_asset_pack_index.bin");

pub const icon_count: u32 = mem.readInt(u32, index_bytes[4..8], .little);

pub const cursor_pointer_2_icon_id: u32 = @intFromEnum(icon.Icon.pointer_2) + 1;
pub const cursor_hand_finger_icon_id: u32 = @intFromEnum(icon.Icon.hand_finger) + 1;

pub fn getIr(icon_id: u32) ?[]const f32 {
    if (icon_id == 0 or icon_id > icon_count) return null;
    const off: usize = 8 + (icon_id - 1) * 8;
    const ir_offset = mem.readInt(u32, index_bytes[off..][0..4], .little);
    const ir_len = mem.readInt(u32, index_bytes[off + 4 ..][0..4], .little);
    if (ir_offset + ir_len > ir_bytes.len) return null;
    const aligned: []align(4) const u8 = @alignCast(ir_bytes[ir_offset..][0..ir_len]);
    return std.mem.bytesAsSlice(f32, aligned);
}

test "asset pack has tabler icons" {
    try std.testing.expect(icon_count > 5000);
}

test "asset pack contains cursor icons" {
    try std.testing.expect(getIr(cursor_pointer_2_icon_id) != null);
    try std.testing.expect(getIr(cursor_hand_finger_icon_id) != null);
}

test "getIr returns non-empty data for cursor icons" {
    const pointer = getIr(cursor_pointer_2_icon_id) orelse return error.TestFailed;
    const hand = getIr(cursor_hand_finger_icon_id) orelse return error.TestFailed;
    try std.testing.expect(pointer.len > 0);
    try std.testing.expect(hand.len > 0);
}

test "getIr returns null for unknown icon id" {
    try std.testing.expectEqual(@as(?[]const f32, null), getIr(0));
    try std.testing.expectEqual(@as(?[]const f32, null), getIr(999_999));
}
