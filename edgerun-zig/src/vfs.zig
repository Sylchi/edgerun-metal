const std = @import("std");
const bytes = @import("bytes.zig");
const clock = @import("clock.zig");
const object = @import("object.zig");
const preimage = @import("preimage.zig");

pub const abi_version: u16 = 1;
pub const label_max: usize = 160;
pub const object_packet_header_bytes: usize = 128;
pub const object_packet_bytes: usize = 1024;
pub const object_label_ref_bytes: usize = 236;

pub const compression_none: u16 = 0;
pub const compression_deflate_raw: u16 = 1;
pub const seal_none: u16 = 0;
pub const seal_blake3_stream_auth: u16 = 1;

const packet_index_max: u32 = 0xffff;
const packet_count_max: u32 = 0x10000;
const payload_domain = "edgerun:c:v1:vfs:object-payload";
const packet_domain = "edgerun:c:v1:vfs:object-packet";
const label_ref_domain = "edgerun:c:v1:vfs:object-label";
const transform_domain = "edgerun:c:v1:vfs:object-transform";

pub const Error = error{
    BadArgument,
    NoSpace,
    Corrupt,
};

pub const ObjectPacketHeader = struct {
    abi: u16,
    packet_index: u16,
    packet_count: u32,
    object_id: preimage.Hash,
    object_len: u64,
    offset: u64,
    payload_hash: preimage.Hash,
    packet_id: preimage.Hash,
    bytes_len: u32,
};

pub const ObjectPacket = struct {
    header: ObjectPacketHeader,
    bytes: [object_packet_bytes]u8 = [_]u8{0} ** object_packet_bytes,
};

pub const ObjectRef = struct {
    abi: u16,
    reserved: u16 = 0,
    object_id: preimage.Hash,
    object_len: u64,
};

pub const ObjectLabelRef = struct {
    abi: u16,
    label_len: u16,
    label: [label_max]u8 = [_]u8{0} ** label_max,
    object_id: preimage.Hash,
    object_len: u64,
    label_hash: preimage.Hash,

    pub fn labelSlice(self: *const ObjectLabelRef) []const u8 {
        return self.label[0..self.label_len];
    }
};

pub const ObjectTransformRef = struct {
    abi: u16,
    compression_kind: u16,
    seal_kind: u16,
    reserved: u16 = 0,
    plaintext_canonical_object_id: preimage.Hash,
    plaintext_len: u64,
    transport_object_id: preimage.Hash,
    transport_len: u64,
    transform_hash: preimage.Hash,
};

pub fn labelValid(label: []const u8) bool {
    if (label.len == 0 or label.len > label_max) return false;
    if (isSlash(label[0]) or isSlash(label[label.len - 1])) return false;

    var last_was_slash = false;
    var index: usize = 0;
    while (index < label.len) : (index += 1) {
        const c = label[index];
        if (c == 0 or c == '\\') return false;
        if (isSlash(c)) {
            if (last_was_slash) return false;
            last_was_slash = true;
            continue;
        }
        if (c == '.') {
            const at_part_start = index == 0 or isSlash(label[index - 1]);
            const at_part_end = index + 1 == label.len or isSlash(label[index + 1]);
            const dotdot = index + 1 < label.len and label[index + 1] == '.' and
                (index + 2 == label.len or isSlash(label[index + 2]));
            if (at_part_start and (at_part_end or dotdot)) return false;
        }
        last_was_slash = false;
    }
    return true;
}

pub fn prepareObjectPacket(
    canonical_object_bytes: []const u8,
    offset: usize,
    packet_index: u32,
    packet_count: u32,
) Error!ObjectPacket {
    if (packet_count == 0 or packet_count > packet_count_max or
        packet_index >= packet_count or packet_index > packet_index_max or
        offset > canonical_object_bytes.len)
    {
        return error.BadArgument;
    }

    const object_id = try canonicalObjectId(canonical_object_bytes);
    var out = ObjectPacket{
        .header = .{
            .abi = abi_version,
            .packet_index = @intCast(packet_index),
            .packet_count = packet_count,
            .object_id = object_id,
            .object_len = @intCast(canonical_object_bytes.len),
            .offset = @intCast(offset),
            .payload_hash = [_]u8{0} ** preimage.hash_size,
            .packet_id = [_]u8{0} ** preimage.hash_size,
            .bytes_len = 0,
        },
    };

    const chunk_len = @min(canonical_object_bytes.len - offset, object_packet_bytes);
    if (chunk_len > 0) @memcpy(out.bytes[0..chunk_len], canonical_object_bytes[offset..][0..chunk_len]);
    out.header.bytes_len = @intCast(chunk_len);
    out.header.payload_hash = hashPayload(out.bytes[0..chunk_len]);
    out.header.packet_id = hashPacketId(
        out.header.abi,
        packet_index,
        packet_count,
        out.header.offset,
        object_id,
        out.header.payload_hash,
    );
    return out;
}

pub fn objectPacketValid(packet: ObjectPacket) bool {
    if (!bytes.nonzero(&packet.header.object_id)) return false;
    return objectPacketMatches(
        packet,
        packet.header.object_id,
        packet.header.object_len,
        packet.header.packet_count,
        packet.header.packet_index,
    );
}

pub fn assembleObjectPackets(packets: []const ObjectPacket, out_object_bytes: []u8) Error!AssembledObject {
    if (packets.len == 0 or packets.len > packet_count_max) return error.BadArgument;

    const object_len = packets[0].header.object_len;
    const object_id = packets[0].header.object_id;
    const packet_count: u32 = @intCast(packets.len);
    if (object_len == 0 or object_len > out_object_bytes.len or
        object_len > @as(u64, packet_count) * object_packet_bytes or
        packet_count != expectedPacketCount(object_len))
    {
        return error.BadArgument;
    }

    for (packets, 0..) |packet, index| {
        const expected_index: u32 = @intCast(index);
        if (!objectPacketMatches(packet, object_id, object_len, packet_count, expected_index)) return error.Corrupt;
        const destination: usize = @intCast(packet.header.offset);
        const len: usize = @intCast(packet.header.bytes_len);
        if (len > 0) @memcpy(out_object_bytes[destination..][0..len], packet.bytes[0..len]);
    }

    const len: usize = @intCast(object_len);
    const assembled_id = try canonicalObjectId(out_object_bytes[0..len]);
    if (!bytes.eql(&assembled_id, &object_id)) return error.Corrupt;
    return .{ .object_len = len, .object_id = assembled_id };
}

pub const AssembledObject = struct {
    object_len: usize,
    object_id: preimage.Hash,
};

pub fn prepareObjectRef(canonical_object_bytes: []const u8) Error!ObjectRef {
    return prepareObjectRefFromObject(try canonicalObjectId(canonical_object_bytes), canonical_object_bytes.len);
}

pub fn prepareObjectRefFromObject(object_id: preimage.Hash, object_len: u64) Error!ObjectRef {
    if (object_len == 0 or !bytes.nonzero(&object_id)) return error.BadArgument;
    return .{
        .abi = abi_version,
        .object_id = object_id,
        .object_len = object_len,
    };
}

pub fn prepareObjectLabelRef(path_label: []const u8, canonical_object_bytes: []const u8) Error!ObjectLabelRef {
    return prepareObjectLabelRefFromObject(path_label, try canonicalObjectId(canonical_object_bytes), canonical_object_bytes.len);
}

pub fn prepareObjectLabelRefFromObject(path_label: []const u8, object_id: preimage.Hash, object_len: u64) Error!ObjectLabelRef {
    if (!labelValid(path_label) or object_len == 0 or !bytes.nonzero(&object_id)) return error.BadArgument;
    var out = ObjectLabelRef{
        .abi = abi_version,
        .label_len = @intCast(path_label.len),
        .object_id = object_id,
        .object_len = object_len,
        .label_hash = [_]u8{0} ** preimage.hash_size,
    };
    @memcpy(out.label[0..path_label.len], path_label);

    var len_be: [8]u8 = undefined;
    _ = bytes.storeBe64(&len_be, object_len);
    var builder = preimage.Builder.init(label_ref_domain);
    builder.bytes(path_label);
    builder.hash(object_id);
    builder.bytes(&len_be);
    out.label_hash = builder.final();
    return out;
}

pub fn encodeObjectLabelRef(ref: ObjectLabelRef, out: []u8) Error!void {
    if (out.len < object_label_ref_bytes) return error.NoSpace;
    if (!objectLabelRefValid(ref)) return error.BadArgument;

    _ = bytes.store16(out[0..2], ref.abi);
    _ = bytes.store16(out[2..4], ref.label_len);
    @memcpy(out[4..164], &ref.label);
    @memcpy(out[164..196], &ref.object_id);
    _ = bytes.store64(out[196..204], ref.object_len);
    @memcpy(out[204..236], &ref.label_hash);
}

pub fn decodeObjectLabelRef(in: []const u8) Error!ObjectLabelRef {
    if (in.len < object_label_ref_bytes) return error.Corrupt;
    const label_len = bytes.load16(in[2..4]) orelse return error.Corrupt;
    if (label_len > label_max) return error.Corrupt;

    var out = ObjectLabelRef{
        .abi = bytes.load16(in[0..2]) orelse return error.Corrupt,
        .label_len = label_len,
        .object_id = undefined,
        .object_len = bytes.load64(in[196..204]) orelse return error.Corrupt,
        .label_hash = undefined,
    };
    @memcpy(&out.label, in[4..164]);
    @memcpy(&out.object_id, in[164..196]);
    @memcpy(&out.label_hash, in[204..236]);
    if (!objectLabelRefValid(out)) return error.Corrupt;
    if (!zeroedPadding(out.label[label_len..])) return error.Corrupt;
    return out;
}

pub fn prepareTransformRef(
    plaintext_canonical_object_id: preimage.Hash,
    plaintext_len: u64,
    transport_object_id: preimage.Hash,
    transport_len: u64,
    compression_kind: u16,
    seal_kind: u16,
) Error!ObjectTransformRef {
    if (!bytes.nonzero(&plaintext_canonical_object_id) or !bytes.nonzero(&transport_object_id) or seal_kind == seal_none) return error.BadArgument;
    var out = ObjectTransformRef{
        .abi = abi_version,
        .compression_kind = compression_kind,
        .seal_kind = seal_kind,
        .plaintext_canonical_object_id = plaintext_canonical_object_id,
        .plaintext_len = plaintext_len,
        .transport_object_id = transport_object_id,
        .transport_len = transport_len,
        .transform_hash = [_]u8{0} ** preimage.hash_size,
    };

    var fields: [20]u8 = undefined;
    _ = bytes.storeBe16(fields[0..2], compression_kind);
    _ = bytes.storeBe16(fields[2..4], seal_kind);
    _ = bytes.storeBe64(fields[4..12], plaintext_len);
    _ = bytes.storeBe64(fields[12..20], transport_len);

    var builder = preimage.Builder.init(transform_domain);
    builder.hash(plaintext_canonical_object_id);
    builder.hash(transport_object_id);
    builder.bytes(&fields);
    out.transform_hash = builder.final();
    return out;
}

fn canonicalObjectId(canonical_object_bytes: []const u8) Error!preimage.Hash {
    const view = object.View.decode(canonical_object_bytes) catch return error.Corrupt;
    return view.id();
}

fn objectPacketMatches(
    packet: ObjectPacket,
    object_id: preimage.Hash,
    object_len: u64,
    packet_count: u32,
    packet_index: u32,
) bool {
    if (object_len == 0 or packet_count == 0 or packet_count > packet_count_max or
        packet_index >= packet_count or packet_index > packet_index_max or
        packet.header.abi != abi_version or
        packet.header.packet_index != @as(u16, @intCast(packet_index)) or
        packet.header.packet_count != packet_count or
        packet.header.object_len != object_len or
        packet.header.bytes_len > object_packet_bytes or
        !bytes.eql(&packet.header.object_id, &object_id) or
        !bytes.nonzero(&packet.header.payload_hash) or
        !bytes.nonzero(&packet.header.packet_id))
    {
        return false;
    }

    const expected_offset = @as(u64, packet_index) * object_packet_bytes;
    const expected_bytes = expectedPacketBytes(object_len, packet_index);
    if (packet.header.offset != expected_offset or packet.header.bytes_len != expected_bytes) return false;

    const bytes_len: usize = @intCast(packet.header.bytes_len);
    const expected_payload_hash = hashPayload(packet.bytes[0..bytes_len]);
    if (!bytes.eql(&expected_payload_hash, &packet.header.payload_hash)) return false;

    const expected_packet_id = hashPacketId(
        packet.header.abi,
        packet.header.packet_index,
        packet.header.packet_count,
        packet.header.offset,
        packet.header.object_id,
        packet.header.payload_hash,
    );
    return bytes.eql(&expected_packet_id, &packet.header.packet_id);
}

fn expectedPacketBytes(object_len: u64, packet_index: u32) u32 {
    const offset = @as(u64, packet_index) * object_packet_bytes;
    if (offset >= object_len) return 0;
    const remaining = object_len - offset;
    if (remaining > object_packet_bytes) return object_packet_bytes;
    return @intCast(remaining);
}

fn expectedPacketCount(object_len: u64) u32 {
    if (object_len == 0) return 1;
    const full_packets = object_len / object_packet_bytes;
    const remainder = object_len % object_packet_bytes;
    const extra: u64 = if (remainder == 0) 0 else 1;
    return @intCast(full_packets + extra);
}

fn hashPayload(payload: []const u8) preimage.Hash {
    return preimage.hash(payload_domain, payload);
}

fn hashPacketId(
    packet_abi: u16,
    packet_index: u32,
    packet_count: u32,
    offset: u64,
    object_id: preimage.Hash,
    payload_hash: preimage.Hash,
) preimage.Hash {
    var packet_preimage: [82]u8 = undefined;
    _ = bytes.storeBe16(packet_preimage[0..2], packet_abi);
    _ = bytes.storeBe32(packet_preimage[2..6], packet_index);
    _ = bytes.storeBe32(packet_preimage[6..10], packet_count);
    _ = bytes.storeBe64(packet_preimage[10..18], offset);
    @memcpy(packet_preimage[18..50], &object_id);
    @memcpy(packet_preimage[50..82], &payload_hash);
    return preimage.hash(packet_domain, &packet_preimage);
}

fn isSlash(value: u8) bool {
    return value == '/';
}

fn objectLabelRefValid(ref: ObjectLabelRef) bool {
    if (ref.abi != abi_version or
        ref.object_len == 0 or
        !bytes.nonzero(&ref.object_id) or
        !bytes.nonzero(&ref.label_hash) or
        !labelValid(ref.labelSlice()))
    {
        return false;
    }
    const expected = prepareObjectLabelRefFromObject(ref.labelSlice(), ref.object_id, ref.object_len) catch return false;
    return bytes.eql(&expected.label_hash, &ref.label_hash);
}

fn zeroedPadding(padding: []const u8) bool {
    for (padding) |byte| {
        if (byte != 0) return false;
    }
    return true;
}

fn testRequirements() object.Requirements {
    return .{
        .durability = .memory,
        .confidentiality = .public,
        .portability = .public_portable,
        .integrity = .hash_only,
        .lifetime = .session,
        .visibility = .public,
        .access = .explicit_io,
    };
}

fn testEpoch() clock.Stamp {
    return .{
        .keeper = .{ .bytes = [_]u8{
            0x76, 0x66, 0x73, 0x3a, 0x74, 0x65, 0x73, 0x74,
            0x3a, 0x65, 0x64, 0x67, 0x65, 0x72, 0x75, 0x6e,
            0x3a, 0x7a, 0x69, 0x67, 0x3a, 0x6f, 0x62, 0x6a,
            0x65, 0x63, 0x74, 0x00, 0x00, 0x00, 0x00, 0x01,
        } },
        .tick = 1,
        .slot = 1,
        .epoch = 1,
        .era = 1,
    };
}

fn buildCanonical(body: []const u8, out: []u8) ![]u8 {
    return try (object.NodeWriter{ .out = out }).bytesNode(testRequirements(), testEpoch(), body);
}

test "vfs rejects raw bytes and packetizes canonical object bytes" {
    const body = "vfs-obj";
    var canonical_raw: [object.header_size + body.len]u8 = undefined;
    const canonical = try buildCanonical(body, &canonical_raw);
    const canonical_id = object.Header.id(canonical);

    try std.testing.expectError(error.Corrupt, prepareObjectPacket(body, 0, 0, 1));

    const packet = try prepareObjectPacket(canonical, 0, 0, 1);
    try std.testing.expect(objectPacketValid(packet));
    try std.testing.expectEqualSlices(u8, &canonical_id, &packet.header.object_id);

    var assembled_raw: [object.header_size + body.len]u8 = undefined;
    const assembled = try assembleObjectPackets(&.{packet}, &assembled_raw);
    try std.testing.expectEqual(canonical.len, assembled.object_len);
    try std.testing.expectEqualSlices(u8, &canonical_id, &assembled.object_id);
    try std.testing.expectEqualSlices(u8, canonical, assembled_raw[0..assembled.object_len]);
}

test "vfs canonical object refs reject raw bytes and preserve labels" {
    const body = "pub fn main() void {}\n";
    var canonical_raw: [object.header_size + body.len]u8 = undefined;
    const canonical = try buildCanonical(body, &canonical_raw);
    const canonical_id = object.Header.id(canonical);

    try std.testing.expectError(error.Corrupt, prepareObjectRef(body));
    const ref = try prepareObjectRef(canonical);
    try std.testing.expectEqual(abi_version, ref.abi);
    try std.testing.expectEqualSlices(u8, &canonical_id, &ref.object_id);
    try std.testing.expectEqual(@as(u64, canonical.len), ref.object_len);

    const label = "src/main.zig";
    const label_ref = try prepareObjectLabelRef(label, canonical);
    try std.testing.expectEqualSlices(u8, label, label_ref.labelSlice());
    try std.testing.expectEqualSlices(u8, &canonical_id, &label_ref.object_id);
    try std.testing.expect(bytes.nonzero(&label_ref.label_hash));

    var label_ref_raw: [object_label_ref_bytes]u8 = undefined;
    try encodeObjectLabelRef(label_ref, &label_ref_raw);
    const decoded = try decodeObjectLabelRef(&label_ref_raw);
    try std.testing.expectEqualSlices(u8, label, decoded.labelSlice());
    try std.testing.expectEqualSlices(u8, &canonical_id, &decoded.object_id);
    try std.testing.expectEqual(@as(u64, canonical.len), decoded.object_len);
}

test "vfs labels reject ambient filesystem paths" {
    try std.testing.expect(labelValid("src/main.zig"));
    try std.testing.expect(labelValid("zig/lib/std/std.zig"));
    try std.testing.expect(!labelValid(""));
    try std.testing.expect(!labelValid("/src/main.zig"));
    try std.testing.expect(!labelValid("src/main.zig/"));
    try std.testing.expect(!labelValid("src//main.zig"));
    try std.testing.expect(!labelValid("src/./main.zig"));
    try std.testing.expect(!labelValid("src/../main.zig"));
    try std.testing.expect(!labelValid("src\\main.zig"));
}

test "vfs assembles multi-packet canonical object deterministically" {
    var body: [object_packet_bytes + 17]u8 = undefined;
    for (&body, 0..) |*byte, index| byte.* = @intCast(index % 251);

    var canonical_raw: [object.header_size + body.len]u8 = undefined;
    const canonical = try buildCanonical(&body, &canonical_raw);
    const packet_count = expectedPacketCount(canonical.len);
    try std.testing.expectEqual(@as(u32, 2), packet_count);

    const first = try prepareObjectPacket(canonical, 0, 0, packet_count);
    const second = try prepareObjectPacket(canonical, object_packet_bytes, 1, packet_count);
    try std.testing.expect(objectPacketValid(first));
    try std.testing.expect(objectPacketValid(second));

    var assembled_raw: [canonical_raw.len]u8 = undefined;
    const assembled = try assembleObjectPackets(&.{ first, second }, &assembled_raw);
    try std.testing.expectEqual(canonical.len, assembled.object_len);
    try std.testing.expectEqualSlices(u8, canonical, assembled_raw[0..assembled.object_len]);
}

test "vfs transform refs hash explicit transport fields" {
    const plaintext = preimage.rawHash("plaintext object");
    const transport = preimage.rawHash("transport object");
    const transform = try prepareTransformRef(
        plaintext,
        123,
        transport,
        456,
        compression_none,
        seal_blake3_stream_auth,
    );
    try std.testing.expectEqual(abi_version, transform.abi);
    try std.testing.expect(bytes.nonzero(&transform.transform_hash));
    try std.testing.expectError(error.BadArgument, prepareTransformRef(
        plaintext,
        123,
        transport,
        456,
        compression_none,
        seal_none,
    ));
}
