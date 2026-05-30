const bytes = @import("../bytes.zig");

pub const length_field_size: usize = @sizeOf(u64);

pub const Error = error{
    NoSpace,
    Corrupt,
};

pub const DecodedPrefix = struct {
    chunk: DataChunk,
    used: usize,
};

pub const DataChunk = struct {
    length: u64,
    bytes: []const u8,

    pub fn init(chunk_bytes: []const u8) DataChunk {
        return .{
            .length = @intCast(chunk_bytes.len),
            .bytes = chunk_bytes,
        };
    }

    pub fn valid(self: DataChunk) bool {
        return self.length == self.bytes.len;
    }

    pub fn canonicalLen(self: DataChunk) usize {
        return length_field_size + self.bytes.len;
    }

    pub fn encode(self: DataChunk, out: []u8) Error![]u8 {
        if (!self.valid()) return error.Corrupt;
        const needed = self.canonicalLen();
        if (out.len < needed) return error.NoSpace;
        _ = bytes.store64(out[0..length_field_size], self.length);
        _ = bytes.copy(out[length_field_size..needed], self.bytes);
        return out[0..needed];
    }

    pub fn body(self: DataChunk) []const u8 {
        return self.bytes;
    }
};

pub fn decode(canonical: []const u8) Error!DataChunk {
    const decoded = try decodePrefix(canonical);
    if (decoded.used != canonical.len) return error.Corrupt;
    return decoded.chunk;
}

pub fn decodePrefix(canonical: []const u8) Error!DecodedPrefix {
    if (canonical.len < length_field_size) return error.Corrupt;
    const length = bytes.load64(canonical[0..length_field_size]) orelse return error.Corrupt;
    if (length > canonical.len - length_field_size) return error.Corrupt;
    const body_len: usize = @intCast(length);
    const used = length_field_size + body_len;
    return .{
        .chunk = .{
            .length = length,
            .bytes = canonical[length_field_size..used],
        },
        .used = used,
    };
}

test "data chunk is exact bytes with explicit canonical length" {
    const testing = @import("std").testing;
    const body_bytes = "hello";
    const chunk = DataChunk.init(body_bytes);
    var canonical: [length_field_size + body_bytes.len]u8 = undefined;

    const encoded = try chunk.encode(&canonical);
    try testing.expectEqual(@as(usize, canonical.len), encoded.len);
    try testing.expectEqual(@as(u64, body_bytes.len), bytes.load64(encoded[0..length_field_size]).?);
    try testing.expectEqualStrings(body_bytes, encoded[length_field_size..]);

    const decoded = try decode(encoded);
    try testing.expect(decoded.valid());
    try testing.expectEqual(@as(u64, body_bytes.len), decoded.length);
    try testing.expectEqualStrings(body_bytes, decoded.body());
}

test "data chunk accepts empty content as a finite byte sequence" {
    const testing = @import("std").testing;
    const chunk = DataChunk.init("");
    var canonical: [length_field_size]u8 = undefined;

    const encoded = try chunk.encode(&canonical);
    const decoded = try decode(encoded);
    try testing.expect(decoded.valid());
    try testing.expectEqual(@as(u64, 0), decoded.length);
    try testing.expectEqual(@as(usize, 0), decoded.body().len);
}

test "data chunk rejects mismatched canonical length" {
    const testing = @import("std").testing;
    var too_short: [length_field_size + 2]u8 = undefined;
    _ = bytes.store64(too_short[0..length_field_size], 3);
    too_short[length_field_size] = 1;
    too_short[length_field_size + 1] = 2;

    try testing.expectError(error.Corrupt, decode(&too_short));

    var trailing: [length_field_size + 2]u8 = undefined;
    _ = bytes.store64(trailing[0..length_field_size], 1);
    trailing[length_field_size] = 1;
    trailing[length_field_size + 1] = 2;

    try testing.expectError(error.Corrupt, decode(&trailing));
}

test "data chunk prefix decode leaves following canonical data untouched" {
    const testing = @import("std").testing;
    const first = DataChunk.init("one");
    const second = DataChunk.init("two");
    var canonical: [length_field_size + 3 + length_field_size + 3]u8 = undefined;
    var cursor: usize = 0;

    const first_encoded = try first.encode(canonical[cursor..]);
    cursor += first_encoded.len;
    const second_encoded = try second.encode(canonical[cursor..]);
    cursor += second_encoded.len;

    const decoded = try decodePrefix(&canonical);
    try testing.expectEqual(@as(usize, first_encoded.len), decoded.used);
    try testing.expectEqualStrings("one", decoded.chunk.body());
    try testing.expectEqualStrings("two", (try decode(canonical[decoded.used..cursor])).body());
}

test "data chunk rejects noncanonical in-memory length claims" {
    const testing = @import("std").testing;
    const invalid = DataChunk{
        .length = 4,
        .bytes = "abc",
    };
    var out: [length_field_size + 4]u8 = undefined;

    try testing.expectError(error.Corrupt, invalid.encode(&out));
}
