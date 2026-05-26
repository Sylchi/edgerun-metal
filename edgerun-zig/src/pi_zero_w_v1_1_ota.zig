const std = @import("std");
const bytes = @import("bytes.zig");
const object = @import("object.zig");

pub const erwire_magic: u32 = 0x3157_5245;
pub const erwire_version: u16 = 1;
pub const erwire_header_bytes: usize = 32;
pub const erwire_kind_vfs_object_packet: u16 = 48;
pub const erwire_flag_first: u16 = 0x0001;
pub const erwire_flag_last: u16 = 0x0002;
pub const stream_id: u32 = 0x4552_5a57;
pub const block_bytes: u32 = 512;
pub const packet_capacity: u32 = 64;
pub const default_slot_block: u32 = 262_144;
pub const max_payload_bytes: usize = 1536;

pub const eth_header_bytes: usize = 14;
pub const eth_type_edgerun: u16 = 0x88b5;
pub const mac_bytes: usize = 6;
pub const broadcast_mac = [_]u8{0xff} ** mac_bytes;

pub const wifi_action_frame_control: u16 = 0x00d0;
pub const wifi_addr1_offset: usize = 4;
pub const wifi_body_offset: usize = 24;
pub const wifi_vendor_category: u8 = 127;
pub const wifi_vendor_oui = [_]u8{ 0x45, 0x52, 0x00 };
pub const wifi_vendor_type_update: u8 = 1;
pub const wifi_vendor_header_bytes: usize = 5;

pub const OtaStatus = enum(u32) {
    idle = 0,
    receiving = 1,
    committed = 2,
    rejected = 3,
    write_failed = 4,
    stored_unbootable = 5,
};

pub const ErwireHeader = struct {
    stream: u32,
    sequence: u32,
    kind: u16,
    flags: u16,
    payload_len: u32,
    payload_crc: u32,
};

pub const Packet = struct {
    header: ErwireHeader,
    payload: []const u8,
};

pub const L2Packet = struct {
    packet: Packet,
    payload: []const u8,
};

pub const CanonicalObjectPayload = struct {
    id: [object.id_size]u8,
    canonical: []const u8,
    view: object.View,
};

pub fn buildPacket(sequence: u32, kind: u16, flags: u16, payload: []const u8, out: []u8) ?usize {
    if (payload.len > max_payload_bytes or out.len < erwire_header_bytes + payload.len) return null;
    putLe32(out[0..4], erwire_magic);
    putLe16(out[4..6], erwire_version);
    putLe16(out[6..8], erwire_header_bytes);
    putLe32(out[8..12], stream_id);
    putLe32(out[12..16], sequence);
    putLe16(out[16..18], kind);
    putLe16(out[18..20], flags);
    putLe32(out[20..24], @intCast(payload.len));
    putLe32(out[24..28], crc32(payload));
    putLe32(out[28..32], 0);
    @memcpy(out[erwire_header_bytes .. erwire_header_bytes + payload.len], payload);
    return erwire_header_bytes + payload.len;
}

pub fn parsePacket(frame: []const u8) ?Packet {
    if (frame.len < erwire_header_bytes) return null;
    const payload_len = getLe32(frame[20..24]);
    const expected_len = erwire_header_bytes + @as(usize, @intCast(payload_len));
    if (getLe32(frame[0..4]) != erwire_magic or
        getLe16(frame[4..6]) != erwire_version or
        getLe16(frame[6..8]) != erwire_header_bytes or
        payload_len > max_payload_bytes or
        getLe32(frame[28..32]) != 0 or
        expected_len != frame.len) return null;
    const payload = frame[erwire_header_bytes..expected_len];
    if (crc32(payload) != getLe32(frame[24..28])) return null;
    return .{
        .header = .{
            .stream = getLe32(frame[8..12]),
            .sequence = getLe32(frame[12..16]),
            .kind = getLe16(frame[16..18]),
            .flags = getLe16(frame[18..20]),
            .payload_len = payload_len,
            .payload_crc = getLe32(frame[24..28]),
        },
        .payload = payload,
    };
}

pub fn unwrapL2(input: []const u8, expected_mac: *const [mac_bytes]u8) ?[]const u8 {
    if (parseEthernet(input, expected_mac)) |payload| return payload;
    return unwrapWifiVendorAction(input, expected_mac);
}

pub fn parseL2Packet(input: []const u8, expected_mac: *const [mac_bytes]u8) ?L2Packet {
    const payload = unwrapL2(input, expected_mac) orelse return null;
    const packet = parsePacket(payload) orelse return null;
    return .{ .packet = packet, .payload = packet.payload };
}

pub fn parseCanonicalObjectPayload(frame: []const u8) ?CanonicalObjectPayload {
    const packet = parsePacket(frame) orelse return null;
    return canonicalObjectFromPacket(packet);
}

pub fn parseL2CanonicalObjectPayload(input: []const u8, expected_mac: *const [mac_bytes]u8) ?CanonicalObjectPayload {
    const l2 = parseL2Packet(input, expected_mac) orelse return null;
    return canonicalObjectFromPacket(l2.packet);
}

pub fn buildEthernetFrame(src_mac: *const [mac_bytes]u8, dst_mac: *const [mac_bytes]u8, payload: []const u8, out: []u8) ?usize {
    if (payload.len == 0 or payload.len > 1500 or out.len < eth_header_bytes + payload.len) return null;
    @memcpy(out[0..mac_bytes], dst_mac);
    @memcpy(out[mac_bytes .. mac_bytes * 2], src_mac);
    putBe16(out[12..14], eth_type_edgerun);
    @memcpy(out[eth_header_bytes .. eth_header_bytes + payload.len], payload);
    return eth_header_bytes + payload.len;
}

pub fn buildWifiVendorActionFrame(src_mac: *const [mac_bytes]u8, dst_mac: *const [mac_bytes]u8, ethernet_frame: []const u8, out: []u8) ?usize {
    const len = wifi_body_offset + wifi_vendor_header_bytes + ethernet_frame.len;
    if (ethernet_frame.len == 0 or out.len < len) return null;
    @memset(out[0..len], 0);
    putLe16(out[0..2], wifi_action_frame_control);
    @memcpy(out[wifi_addr1_offset .. wifi_addr1_offset + mac_bytes], dst_mac);
    @memcpy(out[10..16], src_mac);
    @memcpy(out[16..22], dst_mac);
    out[wifi_body_offset] = wifi_vendor_category;
    @memcpy(out[wifi_body_offset + 1 .. wifi_body_offset + 4], &wifi_vendor_oui);
    out[wifi_body_offset + 4] = wifi_vendor_type_update;
    @memcpy(out[wifi_body_offset + wifi_vendor_header_bytes .. len], ethernet_frame);
    return len;
}

fn parseEthernet(frame: []const u8, expected_mac: *const [mac_bytes]u8) ?[]const u8 {
    if (frame.len <= eth_header_bytes) return null;
    const dst = frame[0..mac_bytes];
    if (!macMatches(dst, expected_mac) and !macMatches(dst, &broadcast_mac)) return null;
    if (getBe16(frame[12..14]) != eth_type_edgerun) return null;
    return frame[eth_header_bytes..];
}

fn unwrapWifiVendorAction(frame: []const u8, expected_mac: *const [mac_bytes]u8) ?[]const u8 {
    if (frame.len <= wifi_body_offset + wifi_vendor_header_bytes) return null;
    if (getLe16(frame[0..2]) != wifi_action_frame_control) return null;
    const dst = frame[wifi_addr1_offset .. wifi_addr1_offset + mac_bytes];
    if (!macMatches(dst, expected_mac) and !macMatches(dst, &broadcast_mac)) return null;
    const body = frame[wifi_body_offset..];
    if (body[0] != wifi_vendor_category or
        !std.mem.eql(u8, body[1..4], &wifi_vendor_oui) or
        body[4] != wifi_vendor_type_update) return null;
    return parseEthernet(body[wifi_vendor_header_bytes..], expected_mac);
}

pub fn crc32(data: []const u8) u32 {
    var crc: u32 = 0xffff_ffff;
    for (data) |byte| {
        crc ^= byte;
        var bit: u8 = 0;
        while (bit < 8) : (bit += 1) {
            const mask: u32 = if ((crc & 1) != 0) 0xedb8_8320 else 0;
            crc = (crc >> 1) ^ mask;
        }
    }
    return ~crc;
}

fn macMatches(candidate: []const u8, expected: *const [mac_bytes]u8) bool {
    return candidate.len == mac_bytes and std.mem.eql(u8, candidate, expected);
}

fn canonicalObjectFromPacket(packet: Packet) ?CanonicalObjectPayload {
    if (packet.header.stream != stream_id or
        packet.header.kind != erwire_kind_vfs_object_packet or
        (packet.header.flags & (erwire_flag_first | erwire_flag_last)) != (erwire_flag_first | erwire_flag_last)) return null;
    const view = object.View.decode(packet.payload) catch return null;
    const id = view.id();
    if (!bytes.eql(&id, &object.Header.id(packet.payload))) return null;
    return .{ .id = id, .canonical = packet.payload, .view = view };
}

fn putLe16(out: []u8, value: u16) void {
    _ = bytes.store16(out, value);
}

fn putLe32(out: []u8, value: u32) void {
    _ = bytes.store32(out, value);
}

fn putBe16(out: []u8, value: u16) void {
    _ = bytes.storeBe16(out, value);
}

fn getLe16(in: []const u8) u16 {
    return bytes.load16(in) orelse 0;
}

fn getLe32(in: []const u8) u32 {
    return bytes.load32(in) orelse 0;
}

fn getBe16(in: []const u8) u16 {
    return bytes.loadBe16(in) orelse 0;
}

test "builds and parses Pi Zero OTA erwire packets" {
    try std.testing.expectEqual(@as(u32, 0xcbf4_3926), crc32("123456789"));
    const payload = "canonical object packet bytes";
    var raw: [128]u8 = undefined;
    const len = buildPacket(3, erwire_kind_vfs_object_packet, erwire_flag_first | erwire_flag_last, payload, &raw).?;
    const packet = parsePacket(raw[0..len]).?;
    try std.testing.expectEqual(stream_id, packet.header.stream);
    try std.testing.expectEqual(@as(u32, 3), packet.header.sequence);
    try std.testing.expectEqual(erwire_kind_vfs_object_packet, packet.header.kind);
    try std.testing.expectEqual(@as(u32, payload.len), packet.header.payload_len);
    try std.testing.expect(std.mem.eql(u8, payload, packet.payload));
    raw[24] ^= 1;
    try std.testing.expect(parsePacket(raw[0..len]) == null);
}

test "unwraps EdgeRun Ethernet and vendor action frames" {
    const expected = [_]u8{ 1, 2, 3, 4, 5, 6 };
    const src = [_]u8{ 6, 5, 4, 3, 2, 1 };
    var eth = [_]u8{0} ** 64;
    @memcpy(eth[0..6], &expected);
    @memcpy(eth[6..12], &src);
    eth[12] = 0x88;
    eth[13] = 0xb5;
    @memcpy(eth[14..18], "ERW1");
    try std.testing.expect(std.mem.eql(u8, "ERW1", unwrapL2(eth[0..18], &expected).?));

    var action = [_]u8{0} ** 96;
    action[0] = 0xd0;
    action[1] = 0x00;
    @memcpy(action[4..10], &broadcast_mac);
    action[wifi_body_offset] = wifi_vendor_category;
    @memcpy(action[wifi_body_offset + 1 .. wifi_body_offset + 4], &wifi_vendor_oui);
    action[wifi_body_offset + 4] = wifi_vendor_type_update;
    @memcpy(action[wifi_body_offset + 5 .. wifi_body_offset + 5 + 18], eth[0..18]);
    try std.testing.expect(std.mem.eql(u8, "ERW1", unwrapL2(action[0 .. wifi_body_offset + 5 + 18], &expected).?));
}

test "parses OTA L2 frames only as canonical object payloads" {
    const keeper = [_]u8{1} ** 32;
    const epoch = @import("clock.zig").Stamp{ .keeper = .{ .bytes = keeper }, .tick = 1, .slot = 2, .epoch = 3, .era = 4 };
    const req = object.Requirements{
        .durability = .durable,
        .confidentiality = .public,
        .portability = .machine_bound,
        .integrity = .hash_only,
        .lifetime = .retained,
        .visibility = .public,
        .access = .explicit_io,
    };
    var canonical_raw: [object.header_size + 16]u8 = undefined;
    const canonical = try (object.NodeWriter{ .out = &canonical_raw }).bytesNode(req, epoch, "ota-image");
    var erwire: [256]u8 = undefined;
    const erwire_len = buildPacket(1, erwire_kind_vfs_object_packet, erwire_flag_first | erwire_flag_last, canonical, &erwire).?;

    const src = [_]u8{ 6, 5, 4, 3, 2, 1 };
    const dst = [_]u8{ 1, 2, 3, 4, 5, 6 };
    var eth: [320]u8 = undefined;
    const eth_len = buildEthernetFrame(&src, &dst, erwire[0..erwire_len], &eth).?;
    const payload = parseL2CanonicalObjectPayload(eth[0..eth_len], &dst).?;
    try std.testing.expect(bytes.eql(&payload.id, &object.Header.id(canonical)));
    try std.testing.expectEqual(object.Kind.bytes, payload.view.header.kind);
    try std.testing.expect(std.mem.eql(u8, "ota-image", payload.view.body));

    erwire[16] = 1;
    const bad_eth_len = buildEthernetFrame(&src, &dst, erwire[0..erwire_len], &eth).?;
    try std.testing.expect(parseL2CanonicalObjectPayload(eth[0..bad_eth_len], &dst) == null);
}
