const std = @import("std");
const bytes = @import("../bytes.zig");
const data_chunk = @import("data_chunk.zig");

pub const count_field_size: usize = @sizeOf(u64);

pub const Error = data_chunk.Error || error{
    BadArgument,
};

pub const DataObject = struct {
    definition: data_chunk.DataChunk,
    chunks: []const data_chunk.DataChunk,

    pub fn init(definition: data_chunk.DataChunk, chunks: []const data_chunk.DataChunk) DataObject {
        return .{
            .definition = definition,
            .chunks = chunks,
        };
    }

    pub fn valid(self: DataObject) bool {
        if (!self.definition.valid() or self.definition.length == 0) return false;
        for (self.chunks) |chunk| {
            if (!chunk.valid()) return false;
        }
        return true;
    }

    pub fn canonicalLen(self: DataObject) Error!usize {
        if (!self.valid()) return error.BadArgument;
        var total = try checkedAdd(count_field_size, self.definition.canonicalLen());
        for (self.chunks) |chunk| {
            total = try checkedAdd(total, chunk.canonicalLen());
        }
        return total;
    }

    pub fn encode(self: DataObject, out: []u8) Error![]u8 {
        const needed = try self.canonicalLen();
        if (out.len < needed) return error.NoSpace;
        _ = bytes.store64(out[0..count_field_size], @intCast(self.chunks.len));
        var cursor: usize = count_field_size;
        cursor += (try self.definition.encode(out[cursor..])).len;
        for (self.chunks) |chunk| {
            cursor += (try chunk.encode(out[cursor..])).len;
        }
        return out[0..cursor];
    }
};

pub fn decode(canonical: []const u8, out_chunks: []data_chunk.DataChunk) Error!DataObject {
    if (canonical.len < count_field_size) return error.Corrupt;
    const chunk_count_u64 = bytes.load64(canonical[0..count_field_size]) orelse return error.Corrupt;
    if (chunk_count_u64 > out_chunks.len) return error.NoSpace;
    const chunk_count: usize = @intCast(chunk_count_u64);
    var cursor: usize = count_field_size;

    const definition_decoded = try data_chunk.decodePrefix(canonical[cursor..]);
    cursor += definition_decoded.used;

    var index: usize = 0;
    while (index < chunk_count) : (index += 1) {
        const decoded = try data_chunk.decodePrefix(canonical[cursor..]);
        out_chunks[index] = decoded.chunk;
        cursor += decoded.used;
    }

    if (cursor != canonical.len) return error.Corrupt;
    const object = DataObject.init(definition_decoded.chunk, out_chunks[0..chunk_count]);
    if (!object.valid()) return error.Corrupt;
    return object;
}

fn checkedAdd(left: usize, right: usize) Error!usize {
    return std.math.add(usize, left, right) catch error.NoSpace;
}

test "data object gives ordered chunks a definition chunk" {
    const testing = @import("std").testing;
    const definition = data_chunk.DataChunk.init("edgerun.content/demo-pair-v1");
    const parts = [_]data_chunk.DataChunk{
        data_chunk.DataChunk.init("left"),
        data_chunk.DataChunk.init("right"),
    };
    const object = DataObject.init(definition, &parts);
    var canonical: [
        count_field_size +
            data_chunk.length_field_size + "edgerun.content/demo-pair-v1".len +
            data_chunk.length_field_size + "left".len +
            data_chunk.length_field_size + "right".len
    ]u8 = undefined;

    const encoded = try object.encode(&canonical);
    var decoded_parts: [2]data_chunk.DataChunk = undefined;
    const decoded = try decode(encoded, &decoded_parts);

    try testing.expect(decoded.valid());
    try testing.expectEqualStrings(definition.body(), decoded.definition.body());
    try testing.expectEqual(@as(usize, 2), decoded.chunks.len);
    try testing.expectEqualStrings("left", decoded.chunks[0].body());
    try testing.expectEqualStrings("right", decoded.chunks[1].body());
}

test "data object can define an empty ordered chunk set" {
    const testing = @import("std").testing;
    const definition = data_chunk.DataChunk.init("edgerun.content/empty-set-v1");
    const object = DataObject.init(definition, &.{});
    var canonical: [count_field_size + data_chunk.length_field_size + "edgerun.content/empty-set-v1".len]u8 = undefined;

    const encoded = try object.encode(&canonical);
    const decoded = try decode(encoded, &.{});

    try testing.expect(decoded.valid());
    try testing.expectEqualStrings(definition.body(), decoded.definition.body());
    try testing.expectEqual(@as(usize, 0), decoded.chunks.len);
}

test "data object rejects missing definition meaning" {
    const testing = @import("std").testing;
    const object = DataObject.init(data_chunk.DataChunk.init(""), &.{});
    var out: [count_field_size + data_chunk.length_field_size]u8 = undefined;

    try testing.expectError(error.BadArgument, object.encode(&out));
}

test "data object rejects trailing chunks beyond declared count" {
    const testing = @import("std").testing;
    const definition = data_chunk.DataChunk.init("edgerun.content/one-v1");
    const parts = [_]data_chunk.DataChunk{
        data_chunk.DataChunk.init("declared"),
        data_chunk.DataChunk.init("trailing"),
    };
    const object = DataObject.init(definition, &parts);
    var canonical: [
        count_field_size +
            data_chunk.length_field_size + "edgerun.content/one-v1".len +
            data_chunk.length_field_size + "declared".len +
            data_chunk.length_field_size + "trailing".len
    ]u8 = undefined;
    const encoded = try object.encode(&canonical);
    _ = bytes.store64(encoded[0..count_field_size], 1);
    var decoded_parts: [1]data_chunk.DataChunk = undefined;

    try testing.expectError(error.Corrupt, decode(encoded, &decoded_parts));
}
