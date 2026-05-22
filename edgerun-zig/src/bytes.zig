pub fn zero(dst: []u8) void {
    for (dst) |*byte| byte.* = 0;
}

pub fn copy(dst: []u8, src: []const u8) bool {
    if (dst.len < src.len) return false;
    @memcpy(dst[0..src.len], src);
    return true;
}

pub fn nonzero(bytes: []const u8) bool {
    for (bytes) |byte| {
        if (byte != 0) return true;
    }
    return false;
}

pub fn eql(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    return @import("std").mem.eql(u8, a, b);
}

pub fn order(a: []const u8, b: []const u8) i2 {
    const len = @min(a.len, b.len);
    for (a[0..len], b[0..len]) |left, right| {
        if (left < right) return -1;
        if (left > right) return 1;
    }
    if (a.len < b.len) return -1;
    if (a.len > b.len) return 1;
    return 0;
}

pub fn store16(out: []u8, value: u16) bool {
    if (out.len < 2) return false;
    out[0] = @truncate(value);
    out[1] = @truncate(value >> 8);
    return true;
}

pub fn store32(out: []u8, value: u32) bool {
    if (out.len < 4) return false;
    out[0] = @truncate(value);
    out[1] = @truncate(value >> 8);
    out[2] = @truncate(value >> 16);
    out[3] = @truncate(value >> 24);
    return true;
}

pub fn store64(out: []u8, value: u64) bool {
    if (out.len < 8) return false;
    return store32(out[0..4], @truncate(value)) and
        store32(out[4..8], @truncate(value >> 32));
}

pub fn load16(in: []const u8) ?u16 {
    if (in.len < 2) return null;
    return @as(u16, in[0]) | (@as(u16, in[1]) << 8);
}

pub fn load32(in: []const u8) ?u32 {
    if (in.len < 4) return null;
    return @as(u32, in[0]) |
        (@as(u32, in[1]) << 8) |
        (@as(u32, in[2]) << 16) |
        (@as(u32, in[3]) << 24);
}

pub fn load64(in: []const u8) ?u64 {
    if (in.len < 8) return null;
    return @as(u64, load32(in[0..4]).?) |
        (@as(u64, load32(in[4..8]).?) << 32);
}

test "little endian roundtrip" {
    const testing = @import("std").testing;
    var raw: [8]u8 = undefined;

    try testing.expect(store64(&raw, 0x1122334455667788));
    try testing.expectEqual(@as(u64, 0x1122334455667788), load64(&raw).?);
}
