const std = @import("std");
const bytes = @import("../bytes.zig");
const data_chunk = @import("data_chunk.zig");

pub const field_tag_size: usize = @sizeOf(u8);
pub const field_header_size: usize = field_tag_size + @sizeOf(u64);
pub const field_count_size: usize = @sizeOf(u64);

pub const Error = data_chunk.Error || error{
    BadArgument,
};

pub const Cardinality = enum(u8) {
    required = 1,
    optional = 2,
    repeated = 3,
};

pub const Field = struct {
    id: data_chunk.DataChunk,
    cardinality: Cardinality,
    definition: ?data_chunk.DataChunk = null,

    pub fn init(id: data_chunk.DataChunk, cardinality: Cardinality, definition: ?data_chunk.DataChunk) Field {
        return .{
            .id = id,
            .cardinality = cardinality,
            .definition = definition,
        };
    }

    pub fn valid(self: Field) bool {
        if (!self.id.valid() or self.id.length == 0) return false;
        if (self.definition) |definition| {
            if (!definition.valid() or definition.length == 0) return false;
        }
        return true;
    }

    pub fn canonicalLen(self: Field) Error!usize {
        if (!self.valid()) return error.BadArgument;
        const definition_len = if (self.definition) |definition| definition.canonicalLen() else 0;
        return checkedAdd(field_header_size, checkedAdd(self.id.canonicalLen(), definition_len) catch return error.NoSpace);
    }

    pub fn encode(self: Field, out: []u8) Error![]u8 {
        const needed = try self.canonicalLen();
        if (out.len < needed) return error.NoSpace;
        out[0] = @intFromEnum(self.cardinality);
        _ = bytes.store64(out[field_tag_size..field_header_size], if (self.definition) |_| 1 else 0);
        var cursor: usize = field_header_size;
        cursor += (try self.id.encode(out[cursor..])).len;
        if (self.definition) |definition| {
            cursor += (try definition.encode(out[cursor..])).len;
        }
        return out[0..cursor];
    }
};

pub const Definition = struct {
    id: data_chunk.DataChunk,
    fields: []const Field,

    pub fn init(id: data_chunk.DataChunk, fields: []const Field) Definition {
        return .{
            .id = id,
            .fields = fields,
        };
    }

    pub fn valid(self: Definition) bool {
        if (!self.id.valid() or self.id.length == 0) return false;
        for (self.fields) |field| {
            if (!field.valid()) return false;
        }
        return true;
    }

    pub fn canonicalLen(self: Definition) Error!usize {
        if (!self.valid()) return error.BadArgument;
        var total = try checkedAdd(field_count_size, self.id.canonicalLen());
        for (self.fields) |field| {
            total = try checkedAdd(total, try field.canonicalLen());
        }
        return total;
    }

    pub fn encode(self: Definition, out: []u8) Error![]u8 {
        const needed = try self.canonicalLen();
        if (out.len < needed) return error.NoSpace;
        _ = bytes.store64(out[0..field_count_size], @intCast(self.fields.len));
        var cursor: usize = field_count_size;
        cursor += (try self.id.encode(out[cursor..])).len;
        for (self.fields) |field| {
            cursor += (try field.encode(out[cursor..])).len;
        }
        return out[0..cursor];
    }
};

pub const DecodedField = struct {
    field: Field,
    used: usize,
};

pub fn decode(canonical: []const u8, out_fields: []Field) Error!Definition {
    if (canonical.len < field_count_size) return error.Corrupt;
    const field_count_u64 = bytes.load64(canonical[0..field_count_size]) orelse return error.Corrupt;
    if (field_count_u64 > out_fields.len) return error.NoSpace;
    const field_count: usize = @intCast(field_count_u64);
    var cursor: usize = field_count_size;

    const id_decoded = try data_chunk.decodePrefix(canonical[cursor..]);
    cursor += id_decoded.used;

    var index: usize = 0;
    while (index < field_count) : (index += 1) {
        const decoded = try decodeFieldPrefix(canonical[cursor..]);
        out_fields[index] = decoded.field;
        cursor += decoded.used;
    }

    if (cursor != canonical.len) return error.Corrupt;
    const definition = Definition.init(id_decoded.chunk, out_fields[0..field_count]);
    if (!definition.valid()) return error.Corrupt;
    return definition;
}

pub fn decodeFieldPrefix(canonical: []const u8) Error!DecodedField {
    if (canonical.len < field_header_size) return error.Corrupt;
    const cardinality = enumFromTag(canonical[0]) orelse return error.Corrupt;
    const definition_count = bytes.load64(canonical[field_tag_size..field_header_size]) orelse return error.Corrupt;
    if (definition_count > 1) return error.Corrupt;
    var cursor: usize = field_header_size;

    const id_decoded = try data_chunk.decodePrefix(canonical[cursor..]);
    cursor += id_decoded.used;

    const definition = if (definition_count == 1) blk: {
        const decoded = try data_chunk.decodePrefix(canonical[cursor..]);
        cursor += decoded.used;
        break :blk decoded.chunk;
    } else null;

    const field = Field.init(id_decoded.chunk, cardinality, definition);
    if (!field.valid()) return error.Corrupt;
    return .{
        .field = field,
        .used = cursor,
    };
}

pub fn required(id: []const u8, definition: ?[]const u8) Field {
    return fieldFromBytes(id, .required, definition);
}

pub fn optional(id: []const u8, definition: ?[]const u8) Field {
    return fieldFromBytes(id, .optional, definition);
}

pub fn repeated(id: []const u8, definition: ?[]const u8) Field {
    return fieldFromBytes(id, .repeated, definition);
}

fn fieldFromBytes(id: []const u8, cardinality: Cardinality, definition: ?[]const u8) Field {
    return Field.init(data_chunk.DataChunk.init(id), cardinality, if (definition) |value| data_chunk.DataChunk.init(value) else null);
}

fn enumFromTag(tag: u8) ?Cardinality {
    return switch (tag) {
        @intFromEnum(Cardinality.required) => .required,
        @intFromEnum(Cardinality.optional) => .optional,
        @intFromEnum(Cardinality.repeated) => .repeated,
        else => null,
    };
}

fn checkedAdd(left: usize, right: usize) Error!usize {
    return std.math.add(usize, left, right) catch error.NoSpace;
}

test "data definition describes fields over ordered chunks" {
    const testing = @import("std").testing;
    const fields = [_]Field{
        required("title", "edgerun.content/utf8-v1"),
        optional("description", "edgerun.content/utf8-v1"),
        repeated("tag", "edgerun.content/utf8-v1"),
    };
    const definition = Definition.init(data_chunk.DataChunk.init("edgerun.content/note-v1"), &fields);
    var canonical: [
        field_count_size +
            data_chunk.length_field_size + "edgerun.content/note-v1".len +
            field_header_size + data_chunk.length_field_size + "title".len + data_chunk.length_field_size + "edgerun.content/utf8-v1".len +
            field_header_size + data_chunk.length_field_size + "description".len + data_chunk.length_field_size + "edgerun.content/utf8-v1".len +
            field_header_size + data_chunk.length_field_size + "tag".len + data_chunk.length_field_size + "edgerun.content/utf8-v1".len
    ]u8 = undefined;

    const encoded = try definition.encode(&canonical);
    var decoded_fields: [3]Field = undefined;
    const decoded = try decode(encoded, &decoded_fields);

    try testing.expect(decoded.valid());
    try testing.expectEqualStrings("edgerun.content/note-v1", decoded.id.body());
    try testing.expectEqual(@as(usize, 3), decoded.fields.len);
    try testing.expectEqual(Cardinality.required, decoded.fields[0].cardinality);
    try testing.expectEqualStrings("title", decoded.fields[0].id.body());
    try testing.expectEqualStrings("edgerun.content/utf8-v1", decoded.fields[0].definition.?.body());
    try testing.expectEqual(Cardinality.optional, decoded.fields[1].cardinality);
    try testing.expectEqual(Cardinality.repeated, decoded.fields[2].cardinality);
}

test "data definition permits primitive fields without nested definition" {
    const testing = @import("std").testing;
    const fields = [_]Field{
        required("body", null),
    };
    const definition = Definition.init(data_chunk.DataChunk.init("edgerun.content/raw-body-v1"), &fields);
    var canonical: [
        field_count_size +
            data_chunk.length_field_size + "edgerun.content/raw-body-v1".len +
            field_header_size + data_chunk.length_field_size + "body".len
    ]u8 = undefined;

    const encoded = try definition.encode(&canonical);
    var decoded_fields: [1]Field = undefined;
    const decoded = try decode(encoded, &decoded_fields);

    try testing.expect(decoded.valid());
    try testing.expect(decoded.fields[0].definition == null);
}

test "data definition rejects empty ids" {
    const testing = @import("std").testing;
    const invalid_definition = Definition.init(data_chunk.DataChunk.init(""), &.{});
    var out: [field_count_size + data_chunk.length_field_size]u8 = undefined;

    try testing.expectError(error.BadArgument, invalid_definition.encode(&out));

    const invalid_field = Definition.init(data_chunk.DataChunk.init("edgerun.content/bad-v1"), &.{required("", null)});
    var field_out: [field_count_size + data_chunk.length_field_size + "edgerun.content/bad-v1".len + field_header_size + data_chunk.length_field_size]u8 = undefined;

    try testing.expectError(error.BadArgument, invalid_field.encode(&field_out));
}

test "data definition rejects malformed field headers" {
    const testing = @import("std").testing;
    const fields = [_]Field{required("body", null)};
    const definition = Definition.init(data_chunk.DataChunk.init("edgerun.content/raw-body-v1"), &fields);
    var canonical: [
        field_count_size +
            data_chunk.length_field_size + "edgerun.content/raw-body-v1".len +
            field_header_size + data_chunk.length_field_size + "body".len
    ]u8 = undefined;
    const encoded = try definition.encode(&canonical);
    const field_start = field_count_size + data_chunk.length_field_size + "edgerun.content/raw-body-v1".len;
    encoded[field_start] = 99;
    var decoded_fields: [1]Field = undefined;

    try testing.expectError(error.Corrupt, decode(encoded, &decoded_fields));
}
