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

pub fn zeroed(value: []const u8) bool {
    return !nonzero(value);
}

pub fn eql(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |left, right| {
        if (left != right) return false;
    }
    return true;
}

pub fn eqlLen(a: []const u8, b: []const u8, len: usize) bool {
    if (a.len < len or b.len < len) return false;
    var index: usize = 0;
    while (index < len) : (index += 1) {
        if (a[index] != b[index]) return false;
    }
    return true;
}

pub fn compareLen(a: []const u8, b: []const u8, len: usize) i2 {
    if (a.len < len or b.len < len) return 0;
    var index: usize = 0;
    while (index < len) : (index += 1) {
        if (a[index] < b[index]) return -1;
        if (a[index] > b[index]) return 1;
    }
    return 0;
}

pub fn startsWith(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;
    for (haystack[0..needle.len], needle) |h, n| {
        if (h != n) return false;
    }
    return true;
}

pub fn endsWith(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;
    const offset = haystack.len - needle.len;
    for (haystack[offset..], needle) |h, n| {
        if (h != n) return false;
    }
    return true;
}

pub fn indexOf(haystack: []const u8, needle: []const u8) ?usize {
    if (needle.len > haystack.len) return null;
    const end = haystack.len - needle.len;
    var i: usize = 0;
    while (i <= end) : (i += 1) {
        var matched = true;
        var j: usize = 0;
        while (j < needle.len) : (j += 1) {
            if (haystack[i + j] != needle[j]) {
                matched = false;
                break;
            }
        }
        if (matched) return i;
    }
    return null;
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

pub fn stored64(value: u64) [8]u8 {
    const bits_per_byte = 8;
    const byte_count = 8;
    var out: [byte_count]u8 = undefined;
    var index: usize = 0;
    while (index < byte_count) : (index += 1) {
        const shift: u6 = @intCast(index * bits_per_byte);
        out[index] = @truncate(value >> shift);
    }
    return out;
}

pub fn storeBe16(out: []u8, value: u16) bool {
    if (out.len < 2) return false;
    out[0] = @truncate(value >> 8);
    out[1] = @truncate(value);
    return true;
}

pub fn storeBe32(out: []u8, value: u32) bool {
    if (out.len < 4) return false;
    out[0] = @truncate(value >> 24);
    out[1] = @truncate(value >> 16);
    out[2] = @truncate(value >> 8);
    out[3] = @truncate(value);
    return true;
}

pub fn storeBe64(out: []u8, value: u64) bool {
    if (out.len < 8) return false;
    return storeBe32(out[0..4], @truncate(value >> 32)) and
        storeBe32(out[4..8], @truncate(value));
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

pub fn loadBe16(in: []const u8) ?u16 {
    if (in.len < 2) return null;
    return (@as(u16, in[0]) << 8) | @as(u16, in[1]);
}

pub fn loadBe32(in: []const u8) ?u32 {
    if (in.len < 4) return null;
    return (@as(u32, in[0]) << 24) |
        (@as(u32, in[1]) << 16) |
        (@as(u32, in[2]) << 8) |
        @as(u32, in[3]);
}

test "little endian roundtrip" {
    var raw: [8]u8 = undefined;

    try expect(store64(&raw, 0x1122334455667788));
    try expectEqual(@as(u64, 0x1122334455667788), load64(&raw).?);
    try expectEqualSlices(&raw, &stored64(0x1122334455667788));
}

test "byte zero copy and fixed length compare match C helpers" {
    var dst = [_]u8{ 9, 9, 9, 9 };
    const src = [_]u8{ 1, 2, 3, 4 };

    try expect(copy(&dst, &src));
    try expect(eql(&dst, &src));
    try expect(nonzero(&dst));
    try expect(!zeroed(&dst));
    zero(&dst);
    try expect(zeroed(&dst));
    try expect(eqlLen(&src, &[_]u8{ 1, 2, 9, 9 }, 2));
    try expect(!eqlLen(&src, &[_]u8{ 1, 9, 3, 4 }, 2));
    try expectEqual(@as(i2, -1), compareLen(&[_]u8{ 1, 2, 3 }, &[_]u8{ 1, 3, 0 }, 3));
    try expectEqual(@as(i2, 1), compareLen(&[_]u8{ 1, 4, 3 }, &[_]u8{ 1, 3, 9 }, 3));
    try expectEqual(@as(i2, 0), compareLen(&[_]u8{ 1, 4, 3 }, &[_]u8{ 1, 3, 9 }, 1));
}

test "big endian roundtrip" {
    var raw: [8]u8 = undefined;

    try expect(storeBe32(&raw, 0x11223344));
    try expectEqual(@as(u32, 0x11223344), loadBe32(&raw).?);
    try expect(storeBe16(raw[0..2], 0xaabb));
    try expectEqual(@as(u16, 0xaabb), loadBe16(raw[0..2]).?);
    try expect(storeBe64(&raw, 0x1122334455667788));
    try expectEqualSlices(&.{ 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88 }, &raw);
}

fn expect(condition: bool) !void {
    if (!condition) return error.TestExpectedTrue;
}

fn expectEqual(expected: anytype, actual: @TypeOf(expected)) !void {
    if (actual != expected) return error.TestExpectedEqual;
}

fn expectEqualSlices(expected: []const u8, actual: []const u8) !void {
    if (!eql(expected, actual)) return error.TestExpectedEqual;
}
