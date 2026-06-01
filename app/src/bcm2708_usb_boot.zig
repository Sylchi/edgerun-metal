const std = @import("er_std");
const bytes = @import("bytes.zig");

pub const abi_version: u16 = 1;
pub const vendor_id: u16 = 0x0a5c;
pub const product_id: u16 = 0x2763;
pub const interface_class_vendor: u8 = 0xff;
pub const interface_subclass: u8 = 0;
pub const interface_protocol: u8 = 0;
pub const endpoint_out: u8 = 0x01;
pub const endpoint_in: u8 = 0x82;
pub const endpoint_attr_bulk: u8 = 0x02;
pub const packet_bytes: u16 = 64;
pub const max_bulk_bytes: u32 = 16_384;
pub const signature_bytes: usize = 20;
pub const second_stage_header_bytes: usize = 24;
pub const control_vendor_out: u8 = 0x40;
pub const control_vendor_in: u8 = 0xc0;
pub const control_request: u8 = 0;
pub const return_code_bytes: u16 = 4;

pub const Transport = struct {
    bulk_out_endpoint: u8 = endpoint_out,
    bulk_in_endpoint: u8 = endpoint_in,
    packet_size: u16 = packet_bytes,
};

pub const PayloadPlan = struct {
    payload_bytes: u32,
    packet_bytes: u16 = packet_bytes,
    full_packet_count: u32,
    final_packet_bytes: u8,
    packet_count: u32,
};

pub const ControlRequest = struct {
    request_type: u8,
    request: u8 = control_request,
    value: u16,
    index: u16,
    length: u16,
};

pub const BulkPlan = struct {
    payload_bytes: u32,
    max_transfer_bytes: u32 = max_bulk_bytes,
    full_transfer_count: u32,
    final_transfer_bytes: u32,
    transfer_count: u32,
};

pub fn deviceSupported(vendor: u16, product: u16) bool {
    return vendor == vendor_id and product == product_id;
}

pub fn payloadPlan(payload_bytes: u32) ?PayloadPlan {
    if (payload_bytes == 0) return null;
    const full = payload_bytes / packet_bytes;
    const final = payload_bytes % packet_bytes;
    return .{
        .payload_bytes = payload_bytes,
        .full_packet_count = full,
        .final_packet_bytes = @intCast(final),
        .packet_count = full + @as(u32, if (final != 0) 1 else 0),
    };
}

pub fn writeControlRequest(payload_bytes: u32) ControlRequest {
    return .{
        .request_type = control_vendor_out,
        .value = @intCast(payload_bytes & 0xffff),
        .index = @intCast((payload_bytes >> 16) & 0xffff),
        .length = 0,
    };
}

pub fn readControlRequest(payload_bytes: u32) ControlRequest {
    return .{
        .request_type = control_vendor_in,
        .value = @intCast(payload_bytes & 0xffff),
        .index = @intCast((payload_bytes >> 16) & 0xffff),
        .length = @intCast(payload_bytes & 0xffff),
    };
}

pub fn bulkPlan(payload_bytes: u32) ?BulkPlan {
    if (payload_bytes == 0) return null;
    const full = payload_bytes / max_bulk_bytes;
    const final = payload_bytes % max_bulk_bytes;
    return .{
        .payload_bytes = payload_bytes,
        .full_transfer_count = full,
        .final_transfer_bytes = final,
        .transfer_count = full + @as(u32, if (final != 0) 1 else 0),
    };
}

pub fn secondStageHeader(bootcode_bytes: u32, signature: ?*const [signature_bytes]u8) [second_stage_header_bytes]u8 {
    var out = [_]u8{0} ** second_stage_header_bytes;
    putLe32(out[0..4], bootcode_bytes);
    if (signature) |sig| @memcpy(out[4..24], sig);
    return out;
}

pub fn parseConfiguration(descriptors: []const u8) ?Transport {
    var in_vendor_interface = false;
    var have_out = false;
    var have_in = false;
    var cursor: usize = 0;
    while (cursor + 2 <= descriptors.len) {
        const len = descriptors[cursor];
        const dtype = descriptors[cursor + 1];
        if (len < 2 or cursor + len > descriptors.len) return null;
        const desc = descriptors[cursor .. cursor + len];
        switch (dtype) {
            4 => {
                in_vendor_interface = len >= 9 and desc[5] == interface_class_vendor and desc[6] == interface_subclass and desc[7] == interface_protocol;
                have_out = false;
                have_in = false;
            },
            5 => if (in_vendor_interface and len >= 7 and (desc[3] & 0x03) == endpoint_attr_bulk and getLe16(desc[4..6]) == packet_bytes) {
                if (desc[2] == endpoint_out) have_out = true;
                if (desc[2] == endpoint_in) have_in = true;
                if (have_out and have_in) return .{};
            },
            else => {},
        }
        cursor += len;
    }
    return null;
}

fn putLe32(out: []u8, value: u32) void {
    _ = bytes.store32(out, value);
}

fn getLe16(in: []const u8) u16 {
    return bytes.load16(in) orelse 0;
}

test "plans BCM2708 boot ROM transfers" {
    try std.testing.expect(deviceSupported(vendor_id, product_id));
    try std.testing.expect(!deviceSupported(0, product_id));

    const payload = payloadPlan(130).?;
    try std.testing.expectEqual(@as(u32, 2), payload.full_packet_count);
    try std.testing.expectEqual(@as(u8, 2), payload.final_packet_bytes);
    try std.testing.expectEqual(@as(u32, 3), payload.packet_count);
    try std.testing.expect(payloadPlan(0) == null);

    const bulk = bulkPlan(33_000).?;
    try std.testing.expectEqual(@as(u32, 2), bulk.full_transfer_count);
    try std.testing.expectEqual(@as(u32, 232), bulk.final_transfer_bytes);
    try std.testing.expectEqual(@as(u32, 3), bulk.transfer_count);
}

test "parses BCM2708 USB configuration descriptors" {
    const descriptors = [_]u8{
        9,    4,    0,    0,    2,  0xff, 0, 0, 0,
        7,    5,    0x01, 0x02, 64, 0,    0, 7, 5,
        0x82, 0x02, 64,   0,    0,
    };
    const transport = parseConfiguration(&descriptors).?;
    try std.testing.expectEqual(endpoint_out, transport.bulk_out_endpoint);
    try std.testing.expectEqual(endpoint_in, transport.bulk_in_endpoint);
    try std.testing.expectEqual(packet_bytes, transport.packet_size);

    var bad = descriptors;
    bad[6] = 1;
    try std.testing.expect(parseConfiguration(&bad) == null);
}

test "builds BCM2708 control requests and second stage header" {
    const write = writeControlRequest(0x1234_5678);
    try std.testing.expectEqual(control_vendor_out, write.request_type);
    try std.testing.expectEqual(@as(u16, 0x5678), write.value);
    try std.testing.expectEqual(@as(u16, 0x1234), write.index);
    try std.testing.expectEqual(@as(u16, 0), write.length);

    const read = readControlRequest(0x1234_5678);
    try std.testing.expectEqual(control_vendor_in, read.request_type);
    try std.testing.expectEqual(@as(u16, 0x5678), read.length);

    const sig = [_]u8{0xaa} ** signature_bytes;
    const header = secondStageHeader(0x1234_5678, &sig);
    try std.testing.expectEqual(@as(u8, 0x78), header[0]);
    try std.testing.expectEqual(@as(u8, 0x56), header[1]);
    try std.testing.expectEqual(@as(u8, 0xaa), header[4]);
    try std.testing.expectEqual(@as(u8, 0xaa), header[23]);
}
