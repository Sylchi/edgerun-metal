const bytes_mod = @import("bytes.zig");
const clock = @import("clock.zig");
const crypto = @import("crypto.zig");
const identity = @import("identity.zig");

pub const hash_size = 32;
pub const epoch_size = 64;
pub const Hash = [hash_size]u8;

pub fn hash(domain: []const u8, value: []const u8) Hash {
    var builder = Builder.init(domain);
    builder.bytes(value);
    return builder.final();
}

pub fn rawHash(value: []const u8) Hash {
    var out: Hash = undefined;
    crypto.blake3.hash(value, &out, .{});
    return out;
}

pub const Builder = struct {
    hasher: crypto.blake3,

    pub fn init(domain: []const u8) Builder {
        var hasher = crypto.blake3.init(.{});
        hasher.update(domain);
        return .{ .hasher = hasher };
    }

    pub fn bytes(self: *Builder, value: []const u8) void {
        self.hasher.update(value);
    }

    pub fn id(self: *Builder, value: identity.Id) void {
        self.hasher.update(&value.bytes);
    }

    pub fn hash(self: *Builder, value: Hash) void {
        self.hasher.update(&value);
    }

    pub fn writeU64(self: *Builder, value: u64) void {
        var raw: [8]u8 = undefined;
        _ = bytes_mod.store64(&raw, value);
        self.hasher.update(&raw);
    }

    pub fn final(self: *Builder) Hash {
        var out: Hash = undefined;
        self.hasher.final(&out);
        return out;
    }
};

pub const Writer = struct {
    buf: []u8,
    pos: usize = 0,

    pub fn init(buf: []u8) Writer {
        bytes_mod.zero(buf);
        return .{ .buf = buf };
    }

    pub fn written(self: Writer) []const u8 {
        return self.buf[0..self.pos];
    }

    pub fn writeU16(self: *Writer, value: u16) bool {
        if (!self.reserve(2)) return false;
        const out = self.buf[self.pos..][0..2];
        self.pos += 2;
        return bytes_mod.store16(out, value);
    }

    pub fn writeU32(self: *Writer, value: u32) bool {
        if (!self.reserve(4)) return false;
        const out = self.buf[self.pos..][0..4];
        self.pos += 4;
        return bytes_mod.store32(out, value);
    }

    pub fn writeU64(self: *Writer, value: u64) bool {
        if (!self.reserve(8)) return false;
        const out = self.buf[self.pos..][0..8];
        self.pos += 8;
        return bytes_mod.store64(out, value);
    }

    pub fn id(self: *Writer, value: identity.Id) bool {
        return self.raw(&value.bytes);
    }

    pub fn hash(self: *Writer, value: Hash) bool {
        return self.raw(&value);
    }

    pub fn epoch(self: *Writer, value: clock.Stamp) bool {
        if (!value.valid()) return false;
        if (!self.reserve(epoch_size)) return false;
        const out = self.buf[self.pos..][0..epoch_size];
        self.pos += epoch_size;
        return encodeEpoch(value, out);
    }

    pub fn raw(self: *Writer, value: []const u8) bool {
        if (!self.reserve(value.len)) return false;
        _ = bytes_mod.copy(self.buf[self.pos..][0..value.len], value);
        self.pos += value.len;
        return true;
    }

    fn reserve(self: Writer, len: usize) bool {
        return self.pos <= self.buf.len and len <= self.buf.len - self.pos;
    }
};

pub fn encodeEpoch(epoch: clock.Stamp, out: []u8) bool {
    if (out.len < epoch_size or !epoch.valid()) return false;
    return bytes_mod.copy(out[0..32], &epoch.keeper.bytes) and
        bytes_mod.store64(out[32..40], epoch.tick) and
        bytes_mod.store64(out[40..48], epoch.slot) and
        bytes_mod.store64(out[48..56], epoch.epoch) and
        bytes_mod.store64(out[56..64], epoch.era);
}

pub fn decodeEpoch(in: []const u8) ?clock.Stamp {
    if (in.len < epoch_size) return null;
    var keeper_bytes: [clock.keeper_id_size]u8 = undefined;
    _ = bytes_mod.copy(&keeper_bytes, in[0..clock.keeper_id_size]);

    const stamp = clock.Stamp{
        .keeper = .{ .bytes = keeper_bytes },
        .tick = bytes_mod.load64(in[32..40]) orelse return null,
        .slot = bytes_mod.load64(in[40..48]) orelse return null,
        .epoch = bytes_mod.load64(in[48..56]) orelse return null,
        .era = bytes_mod.load64(in[56..64]) orelse return null,
    };
    return if (stamp.valid()) stamp else null;
}

test "writer encodes ids integers and epochs deterministically" {
    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const stamp = clock.Stamp{ .keeper = keeper, .tick = 2 };
    const id_value = identity.Id{ .bytes = [_]u8{3} ++ [_]u8{0} ** 31 };
    var raw: [106]u8 = undefined;
    var writer = Writer.init(&raw);

    try expect(writer.id(id_value));
    try expect(writer.writeU16(4));
    try expect(writer.writeU64(5));
    try expect(writer.epoch(stamp));
    try expectEqual(raw.len, writer.written().len);
    try expect(stamp.order(decodeEpoch(raw[42..106]).?) == 0);
    try expect(bytes_mod.nonzero(&hash("edgerun:zig:v1:test", writer.written())));
}

fn expect(condition: bool) !void {
    if (!condition) return error.TestExpectedTrue;
}

fn expectEqual(expected: anytype, actual: @TypeOf(expected)) !void {
    if (actual != expected) return error.TestExpectedEqual;
}
