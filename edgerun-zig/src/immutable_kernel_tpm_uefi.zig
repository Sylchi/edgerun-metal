const std = @import("std");
const uefi = std.os.uefi;
const bytes = @import("bytes.zig");
const kernel = @import("content/kernel.zig");
const kernel_authority = @import("content/kernel_authority.zig");
const data_chunk = @import("content/data_chunk.zig");
const tpm = @import("tpm.zig");
const tls_tpm = @import("tls_tpm.zig");
const tpm_verifier = @import("content/tpm_verifier.zig");

const debugcon_port: u16 = 0x402;
const line_max: usize = 192;
const command_bytes = 512;
const response_bytes = 3968;

const Tcg2Protocol = extern struct {
    get_capability: *const fn (*Tcg2Protocol, *Tcg2BootServiceCapability) callconv(uefi.cc) uefi.Status,
    get_event_log: *const anyopaque,
    hash_log_extend_event: *const anyopaque,
    submit_command: *const fn (*Tcg2Protocol, u32, [*]const u8, u32, [*]u8) callconv(uefi.cc) uefi.Status,
    get_active_pcr_banks: *const anyopaque,
    set_active_pcr_banks: *const anyopaque,
    get_result_of_set_active_pcr_banks: *const anyopaque,

    pub const guid = uefi.Guid{
        .time_low = 0x607f_766c,
        .time_mid = 0x7455,
        .time_high_and_version = 0x42be,
        .clock_seq_high_and_reserved = 0x93,
        .clock_seq_low = 0x0b,
        .node = .{ 0xe4, 0xd7, 0x6d, 0xb2, 0x72, 0x0f },
    };
};

const Tcg2BootServiceCapability = extern struct {
    size: u8,
    structure_version: Tcg2Version,
    protocol_version: Tcg2Version,
    hash_algorithm_bitmap: u32,
    supported_event_logs: u32,
    tpm_present_flag: bool,
    max_command_size: u16,
    max_response_size: u16,
    manufacturer_id: u32,
    number_of_pcr_banks: u32,
    active_pcr_banks: u32,
};

const Tcg2Version = extern struct {
    major: u8,
    minor: u8,
};

const Tcg2Transport = struct {
    protocol: *Tcg2Protocol,
    last_response_len: usize = 0,

    fn transact(user: ?*anyopaque, command: []const u8, response: []u8) ?[]const u8 {
        if (command.len == 0 or command.len > std.math.maxInt(u32)) return null;
        if (response.len == 0 or response.len > std.math.maxInt(u32)) return null;
        const self: *Tcg2Transport = @ptrCast(@alignCast(user orelse return null));
        const status = self.protocol.submit_command(
            self.protocol,
            @intCast(command.len),
            command.ptr,
            @intCast(response.len),
            response.ptr,
        );
        if (status != .success) {
            printText("tcg2 submit status=0x");
            printHexUsize(@intFromEnum(status));
            printNewline();
            self.last_response_len = 0;
            return null;
        }
        const response_len = responseLength(response) orelse {
            printLine("tcg2 response length invalid");
            return null;
        };
        self.last_response_len = response_len;
        return response[0..response_len];
    }
};

pub fn main() uefi.Status {
    printLine("EdgeRun immutable kernel TPM swtpm smoke");
    return runChecks();
}

fn runChecks() uefi.Status {
    const boot_services = uefi.system_table.boot_services orelse return failText("boot-services unavailable");
    const protocol = (boot_services.locateProtocol(Tcg2Protocol, null) catch return failText("tcg2 locate failed")) orelse return failText("tcg2 missing");
    printLine("check: tcg2-protocol found");

    var capability = Tcg2BootServiceCapability{
        .size = @sizeOf(Tcg2BootServiceCapability),
        .structure_version = .{ .major = 1, .minor = 1 },
        .protocol_version = .{ .major = 0, .minor = 0 },
        .hash_algorithm_bitmap = 0,
        .supported_event_logs = 0,
        .tpm_present_flag = false,
        .max_command_size = 0,
        .max_response_size = 0,
        .manufacturer_id = 0,
        .number_of_pcr_banks = 0,
        .active_pcr_banks = 0,
    };
    if (protocol.get_capability(protocol, &capability) != .success) return failText("tcg2 capability failed");
    if (!capability.tpm_present_flag) return failText("tcg2 reports no tpm");
    printText("tcg2 max command=0x");
    printHexU32(capability.max_command_size);
    printText(" response=0x");
    printHexU32(capability.max_response_size);
    printNewline();
    printLine("check: swtpm present");

    var transport = Tcg2Transport{ .protocol = protocol };
    var command: [command_bytes]u8 = undefined;
    var response: [response_bytes]u8 = undefined;

    const algs = getAlgorithms(&transport, &command, &response) orelse return failText("tpm alg profile failed");
    const commands = getCommands(&transport, &command, &response) orelse return failText("tpm command profile failed");
    const info = tpm.Tpm2Info{ .found = true, .start_method = 6 };
    var ctx = tls_tpm.Context.init(Tcg2Transport.transact, &transport, info, algs, commands) orelse return failText("tls-tpm profile unsupported");
    printLine("check: tpm profile ok");

    const allocation = kernel.Allocation.init(chunk("qemu-swtpm-allocation"), chunk("boot-root"), 256);
    var canonical: [128]u8 = undefined;
    const signed_bytes = kernel_authority.encodeAddAllocation(allocation, &canonical) catch return failText("encode allocation failed");
    const digest = ctx.sha256(signed_bytes) orelse return failText("tpm sha256 failed");
    printLine("check: tpm sha256 ok");

    const primary = createSigningKey(&transport, &command, &response) orelse return failText("tpm create signing key failed");
    defer _ = ctx.flush(primary.handle);
    const action_signature = ctx.signP256Sha256(primary.handle, digest) orelse return failText("tpm sign failed");
    printLine("check: tpm sign ok");

    var executor = tpm_verifier.TpmExecutor.init(&ctx);
    const verifier = tpm_verifier.Verifier(tpm_verifier.TpmExecutor).init(&executor);
    var allocation_slots: [1]kernel.Allocation = undefined;
    var allocator = kernel.Allocator.init(&allocation_slots);
    var scratch: [128]u8 = undefined;
    _ = kernel_authority.addVerifiedAllocation(
        tpm_verifier.TpmExecutor,
        &allocator,
        verifier,
        allocation,
        .{ .public_key = primary.public_key, .bytes = action_signature },
        &scratch,
    ) catch return failText("kernel signed allocation failed");

    if (allocator.len != 1) return failText("verified allocation not recorded");
    if (!allocator.rangeValid(kernel.AddressRange.init(chunk("qemu-swtpm-allocation"), 0, 256))) return failText("verified allocation invalid");
    printLine("check: kernel tpm signature verified allocation ok");
    printLine("PASS immutable-kernel-swtpm-qemu");
    return .success;
}

fn getAlgorithms(transport: *Tcg2Transport, command: []u8, response: []u8) ?tpm.AlgorithmProfile {
    const get_cap = tpm.buildGetCapability(tpm.cap_algs, 0, 128, command) orelse return null;
    const cap_response = Tcg2Transport.transact(transport, get_cap, response) orelse return null;
    if (!tpm.responseSuccess(cap_response)) {
        printText("tpm alg response=0x");
        printHexU32(tpm.responseCode(cap_response));
        printNewline();
        return null;
    }
    return tpm.parseAlgorithmProfile(cap_response) orelse {
        printLine("tpm alg parse failed");
        return null;
    };
}

fn getCommands(transport: *Tcg2Transport, command: []u8, response: []u8) ?tpm.CommandProfile {
    const get_cap = tpm.buildGetCapability(tpm.cap_commands, 0, 128, command) orelse return null;
    const cap_response = Tcg2Transport.transact(transport, get_cap, response) orelse return null;
    if (!tpm.responseSuccess(cap_response)) {
        printText("tpm command response=0x");
        printHexU32(tpm.responseCode(cap_response));
        printNewline();
        return null;
    }
    return tpm.parseCommandProfile(cap_response) orelse {
        printLine("tpm command parse failed");
        return null;
    };
}

fn createSigningKey(transport: *Tcg2Transport, command: []u8, response: []u8) ?tpm.P256Primary {
    const create = tpm.buildCreatePrimaryP256Signing(command) orelse return null;
    const create_response = Tcg2Transport.transact(transport, create, response) orelse return null;
    if (!tpm.responseSuccess(create_response)) return null;
    return tpm.parseCreatePrimaryP256(create_response);
}

fn responseLength(response: []const u8) ?usize {
    if (response.len < tpm.header_len) return null;
    const len = bytes.loadBe32(response[2..6]) orelse return null;
    if (len < tpm.header_len or len > response.len) return null;
    return @intCast(len);
}

fn chunk(value: []const u8) data_chunk.DataChunk {
    return data_chunk.DataChunk.init(value);
}

fn failText(message: []const u8) uefi.Status {
    printText("FAIL ");
    printLine(message);
    return .aborted;
}

fn printLine(message: []const u8) void {
    printText(message);
    printNewline();
}

fn printNewline() void {
    printText("\r\n");
}

fn printText(message: []const u8) void {
    writeDebugcon(message);
    writeConsole(message);
}

fn printHexU32(value: u32) void {
    var shift: u5 = 28;
    while (true) {
        const nibble: u8 = @truncate((value >> shift) & 0xf);
        printByte(if (nibble < 10) '0' + nibble else 'a' + (nibble - 10));
        if (shift == 0) break;
        shift -= 4;
    }
}

fn printHexUsize(value: usize) void {
    var shift: std.math.Log2Int(usize) = @intCast((@sizeOf(usize) * 8) - 4);
    while (true) {
        const nibble: u8 = @truncate((value >> shift) & 0xf);
        printByte(if (nibble < 10) '0' + nibble else 'a' + (nibble - 10));
        if (shift == 0) break;
        shift -= 4;
    }
}

fn printByte(byte: u8) void {
    writeDebugcon(&.{byte});
    writeConsole(&.{byte});
}

fn writeConsole(message: []const u8) void {
    const out = uefi.system_table.con_out orelse return;
    var wide: [line_max:0]u16 = undefined;
    var index: usize = 0;
    while (index < message.len and index < line_max) : (index += 1) {
        wide[index] = message[index];
    }
    wide[index] = 0;
    _ = out.outputString(@ptrCast(&wide)) catch false;
}

fn writeDebugcon(message: []const u8) void {
    for (message) |byte| {
        outb(debugcon_port, byte);
    }
}

fn outb(port: u16, value: u8) void {
    asm volatile ("outb %[value], %[port]"
        :
        : [value] "{al}" (value),
          [port] "{dx}" (port),
    );
}
