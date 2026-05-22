const std = @import("std");

pub const abi_version: u16 = 1;
pub const magic: u32 = 0x5552_4345;
pub const vendor_id: u16 = 0x4552;
pub const product_id: u16 = 0x5049;
pub const interface_class_vendor: u8 = 0xff;
pub const interface_subclass: u8 = 0x45;
pub const interface_protocol: u8 = 0x52;
pub const endpoint_out: u8 = 0x01;
pub const endpoint_in: u8 = 0x81;
pub const endpoint_interrupt: u8 = 0x82;
pub const endpoint_attr_bulk: u8 = 0x02;
pub const endpoint_attr_interrupt: u8 = 0x03;
pub const packet_bytes: u16 = 64;
pub const block_bytes: u32 = 512;
pub const max_transfer_bytes: u32 = 16_384;
pub const request_header_bytes: u16 = 40;
pub const response_header_bytes: u16 = 28;

pub const Flag = packed struct(u32) {
    write: bool = false,
    read: bool = false,
    response_required: bool = false,
    reserved: u29 = 0,
};

pub const flags_write_response: u32 = 0x0000_0005;
pub const flags_read_response: u32 = 0x0000_0006;
pub const flags_valid_mask: u32 = 0x0000_0007;

pub const Status = enum(u32) {
    ok = 0,
    bad_request = 1,
    unsupported = 2,
    io_error = 3,
};

pub const Command = enum(u32) {
    storage_read = 0x0001_0001,
    storage_write = 0x0001_0002,
    gpio_read = 0x0002_0001,
    gpio_write = 0x0002_0002,
    wifi_status = 0x0003_0001,
    wifi_tx_frame = 0x0003_0002,
    gpu_flush = 0x0004_0001,
    memory_read = 0x0005_0001,
    memory_write = 0x0005_0002,
};

pub const Class = enum(u32) {
    storage = 1,
    gpio = 2,
    wifi = 3,
    gpu = 4,
    memory = 5,
};

pub const Request = struct {
    sequence: u32,
    command: Command,
    flags: u32,
    address: u64 = 0,
    length: u32 = 0,
    value: u32 = 0,

    pub fn valid(self: Request) bool {
        if (self.sequence == 0 or (self.flags & ~flags_valid_mask) != 0) return false;
        const expected_flags = if (commandReads(self.command)) flags_read_response else flags_write_response;
        if (self.flags != expected_flags) return false;
        return lengthValid(self.command, self.length);
    }

    pub fn encode(self: Request, out: []u8) bool {
        if (!self.valid() or out.len < request_header_bytes) return false;
        @memset(out[0..request_header_bytes], 0);
        putLe32(out[0..4], magic);
        putLe16(out[4..6], abi_version);
        putLe16(out[6..8], request_header_bytes);
        putLe32(out[8..12], self.sequence);
        putLe32(out[12..16], @intFromEnum(self.command));
        putLe32(out[16..20], self.flags);
        putLe64(out[24..32], self.address);
        putLe32(out[32..36], self.length);
        putLe32(out[36..40], self.value);
        return true;
    }

    pub fn decode(in: []const u8) ?Request {
        if (in.len < request_header_bytes) return null;
        if (getLe32(in[0..4]) != magic or
            getLe16(in[4..6]) != abi_version or
            getLe16(in[6..8]) != request_header_bytes) return null;
        const command = enumFromInt(Command, getLe32(in[12..16])) orelse return null;
        const request = Request{
            .sequence = getLe32(in[8..12]),
            .command = command,
            .flags = getLe32(in[16..20]),
            .address = getLe64(in[24..32]),
            .length = getLe32(in[32..36]),
            .value = getLe32(in[36..40]),
        };
        return if (request.valid()) request else null;
    }
};

pub const Response = struct {
    sequence: u32,
    command: Command,
    status: Status,
    length: u32 = 0,
    value: u32 = 0,

    pub fn encode(self: Response, out: []u8) bool {
        if (self.sequence == 0 or out.len < response_header_bytes) return false;
        @memset(out[0..response_header_bytes], 0);
        putLe32(out[0..4], magic);
        putLe16(out[4..6], abi_version);
        putLe16(out[6..8], response_header_bytes);
        putLe32(out[8..12], self.sequence);
        putLe32(out[12..16], @intFromEnum(self.command));
        putLe32(out[16..20], @intFromEnum(self.status));
        putLe32(out[20..24], self.length);
        putLe32(out[24..28], self.value);
        return true;
    }

    pub fn decode(in: []const u8, request: Request) ?Response {
        if (in.len < response_header_bytes) return null;
        if (getLe32(in[0..4]) != magic or
            getLe16(in[4..6]) != abi_version or
            getLe16(in[6..8]) != response_header_bytes or
            getLe32(in[8..12]) != request.sequence or
            getLe32(in[12..16]) != @intFromEnum(request.command)) return null;
        const status = enumFromInt(Status, getLe32(in[16..20])) orelse return null;
        return .{
            .sequence = request.sequence,
            .command = request.command,
            .status = status,
            .length = getLe32(in[20..24]),
            .value = getLe32(in[24..28]),
        };
    }
};

pub fn commandSupported(raw_command: u32) bool {
    return enumFromInt(Command, raw_command) != null;
}

pub fn makeRequest(sequence: u32, command: Command, address: u64, length: u32, value: u32) ?Request {
    const request = Request{
        .sequence = sequence,
        .command = command,
        .flags = if (commandReads(command)) flags_read_response else flags_write_response,
        .address = address,
        .length = length,
        .value = value,
    };
    return if (request.valid()) request else null;
}

pub fn makeResponse(request: Request, status: Status, length: u32, value: u32) ?Response {
    if (!request.valid()) return null;
    return .{
        .sequence = request.sequence,
        .command = request.command,
        .status = status,
        .length = length,
        .value = value,
    };
}

pub fn commandClass(command: Command) Class {
    return switch (command) {
        .storage_read, .storage_write => .storage,
        .gpio_read, .gpio_write => .gpio,
        .wifi_status, .wifi_tx_frame => .wifi,
        .gpu_flush => .gpu,
        .memory_read, .memory_write => .memory,
    };
}

fn commandReads(command: Command) bool {
    return switch (command) {
        .storage_read, .gpio_read, .wifi_status, .memory_read => true,
        .storage_write, .gpio_write, .wifi_tx_frame, .gpu_flush, .memory_write => false,
    };
}

fn lengthValid(command: Command, length: u32) bool {
    return switch (command) {
        .storage_read, .storage_write => length != 0 and length <= max_transfer_bytes and length % block_bytes == 0,
        .gpio_read, .wifi_status => length == 4,
        .gpio_write, .gpu_flush => length == 0,
        .wifi_tx_frame, .memory_read, .memory_write => length != 0 and length <= max_transfer_bytes,
    };
}

fn enumFromInt(comptime E: type, value: u32) ?E {
    inline for (std.enums.values(E)) |candidate| {
        if (@intFromEnum(candidate) == value) return candidate;
    }
    return null;
}

fn putLe16(out: []u8, value: u16) void {
    out[0] = @intCast(value & 0xff);
    out[1] = @intCast((value >> 8) & 0xff);
}

fn putLe32(out: []u8, value: u32) void {
    out[0] = @intCast(value & 0xff);
    out[1] = @intCast((value >> 8) & 0xff);
    out[2] = @intCast((value >> 16) & 0xff);
    out[3] = @intCast((value >> 24) & 0xff);
}

fn putLe64(out: []u8, value: u64) void {
    putLe32(out[0..4], @intCast(value & 0xffff_ffff));
    putLe32(out[4..8], @intCast(value >> 32));
}

fn getLe16(in: []const u8) u16 {
    return @as(u16, in[0]) | (@as(u16, in[1]) << 8);
}

fn getLe32(in: []const u8) u32 {
    return @as(u32, in[0]) | (@as(u32, in[1]) << 8) | (@as(u32, in[2]) << 16) | (@as(u32, in[3]) << 24);
}

fn getLe64(in: []const u8) u64 {
    return @as(u64, getLe32(in[0..4])) | (@as(u64, getLe32(in[4..8])) << 32);
}

test "validates Pi USB control requests" {
    try std.testing.expect(commandSupported(@intFromEnum(Command.storage_read)));
    try std.testing.expect(!commandSupported(0xffff_ffff));

    var request = Request{
        .sequence = 7,
        .command = .storage_read,
        .flags = flags_read_response,
        .address = 512,
        .length = 1024,
    };
    try std.testing.expect(request.valid());
    request.length = 513;
    try std.testing.expect(!request.valid());
    request.length = 1024;
    request.flags = flags_write_response;
    try std.testing.expect(!request.valid());

    const gpio = Request{
        .sequence = 8,
        .command = .gpio_write,
        .flags = flags_write_response,
        .value = 0x20,
    };
    try std.testing.expect(gpio.valid());
    try std.testing.expectEqual(Class.gpio, commandClass(gpio.command));

    const made = makeRequest(9, .gpio_read, 47, 4, 0).?;
    try std.testing.expectEqual(flags_read_response, made.flags);
    try std.testing.expect(makeRequest(0, .gpio_read, 47, 4, 0) == null);
    try std.testing.expect(makeRequest(10, .storage_write, 0, block_bytes - 1, 0) == null);
    const made_response = makeResponse(made, .ok, made.length, 0).?;
    try std.testing.expectEqual(made.sequence, made_response.sequence);
    try std.testing.expectEqual(made.command, made_response.command);
}

test "round trips Pi USB control headers" {
    const request = Request{
        .sequence = 11,
        .command = .memory_write,
        .flags = flags_write_response,
        .address = 0x1234_5678_9abc_def0,
        .length = 128,
        .value = 0x55aa,
    };
    var raw: [request_header_bytes]u8 = undefined;
    try std.testing.expect(request.encode(&raw));
    const decoded = Request.decode(&raw).?;
    try std.testing.expectEqual(request.sequence, decoded.sequence);
    try std.testing.expectEqual(request.command, decoded.command);
    try std.testing.expectEqual(request.address, decoded.address);
    try std.testing.expectEqual(request.length, decoded.length);

    const response = Response{ .sequence = request.sequence, .command = request.command, .status = .ok, .length = 4, .value = 9 };
    var response_raw: [response_header_bytes]u8 = undefined;
    try std.testing.expect(response.encode(&response_raw));
    const decoded_response = Response.decode(&response_raw, request).?;
    try std.testing.expectEqual(Status.ok, decoded_response.status);
    try std.testing.expectEqual(@as(u32, 9), decoded_response.value);
}
