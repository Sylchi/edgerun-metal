const std = @import("std");
const bytes = @import("bytes.zig");
const linux = std.os.linux;
const tpm = @import("tpm.zig");
const tls_tpm = @import("tls_tpm.zig");

const device_path = "/dev/tpmrm0";
const command_bytes = 512;
const response_bytes = 4096;

const CheckError = error{
    OpenTpmFailed,
    TpmWriteFailed,
    TpmShortWrite,
    TpmReadFailed,
    TpmEmptyResponse,
    BuildCommandFailed,
    TpmCommandFailed,
    ParseResponseFailed,
    UnsupportedProfile,
    DigestMismatch,
};

pub fn main() !void {
    var command: [command_bytes]u8 = undefined;
    var response: [response_bytes]u8 = undefined;

    var fd = try openTpm();
    defer _ = linux.close(fd);

    std.debug.print("real TPM device: {s}\n", .{device_path});

    const random_command = tpm.buildGetRandom(16, &command) orelse return error.BuildCommandFailed;
    const random_response = try transactFd(fd, random_command, &response);
    if (!tpm.responseSuccess(random_response)) return error.TpmCommandFailed;
    var random: [16]u8 = undefined;
    _ = tpm.parseGetRandom(random_response, &random) orelse return error.ParseResponseFailed;
    printHex("get_random(16)", &random);

    const algs = try getAlgorithms(fd, &command, &response);
    const commands = try getCommands(fd, &command, &response);
    const info = tpm.Tpm2Info{ .found = true, .start_method = 6 };
    std.debug.print("profile: sha256={} hmac={} aes={} ecc={} ecdsa={} ecdh={} ctr={} cfb={} cbc={}\n", .{
        algs.has_sha256,
        algs.has_hmac,
        algs.has_aes,
        algs.has_ecc,
        algs.has_ecdsa,
        algs.has_ecdh,
        algs.has_ctr,
        algs.has_cfb,
        algs.has_cbc,
    });
    std.debug.print("commands: random={} hash={} load_external={} hmac={} create_primary={} sign={} verify={} crypt={}\n", .{
        commands.has_get_random,
        commands.has_hash,
        commands.has_load_external,
        commands.has_hmac,
        commands.has_create_primary,
        commands.has_sign,
        commands.has_verify_signature,
        commands.has_encrypt_decrypt2,
    });

    var ctx = tls_tpm.Context.init(transactContext, &fd, info, algs, commands) orelse return error.UnsupportedProfile;

    var tls_random: [16]u8 = undefined;
    if (!ctx.getRandom(&tls_random)) return error.TpmCommandFailed;
    printHex("tls_tpm.getRandom(16)", &tls_random);

    const sample = "edgerun real tpm sha256";
    const tpm_digest = ctx.sha256(sample) orelse return error.TpmCommandFailed;
    var software_digest: [tpm.sha256_digest_len]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(sample, &software_digest, .{});
    if (!bytes.eql(&tpm_digest, &software_digest)) return error.DigestMismatch;
    printHex("tls_tpm.sha256", &tpm_digest);

    var long_data: [300]u8 = undefined;
    for (&long_data, 0..) |*byte, index| byte.* = @intCast(index & 0xff);
    const long_tpm_digest = ctx.sha256(&long_data) orelse return error.TpmCommandFailed;
    std.crypto.hash.sha2.Sha256.hash(&long_data, &software_digest, .{});
    if (!bytes.eql(&long_tpm_digest, &software_digest)) return error.DigestMismatch;
    printHex("tls_tpm.sha256(sequence)", &long_tpm_digest);

    const hmac_key = [_]u8{0x31} ** tpm.sha256_digest_len;
    const hmac_handle = ctx.loadHmacSha256Key(&hmac_key) orelse return error.TpmCommandFailed;
    defer _ = ctx.flush(hmac_handle);
    const hmac_digest = ctx.hmacSha256(hmac_handle, sample) orelse return error.TpmCommandFailed;
    std.debug.print("tls_tpm.hmacSha256 handle=0x{x}: ", .{hmac_handle});
    printHexRaw(&hmac_digest);
    std.debug.print("\n", .{});

    var signing_command: [command_bytes]u8 = undefined;
    const create_signing = tpm.buildCreatePrimaryP256Signing(&signing_command) orelse return error.BuildCommandFailed;
    const create_response = try transactFd(fd, create_signing, &response);
    if (!tpm.responseSuccess(create_response)) {
        std.debug.print("create_primary(signing) response_code=0x{x}; skipping sign/verify\n", .{tpm.responseCode(create_response)});
        return;
    }

    const primary = tpm.parseCreatePrimaryP256(create_response) orelse return error.ParseResponseFailed;
    defer _ = ctx.flush(primary.handle);
    const signature = ctx.signP256Sha256(primary.handle, tpm_digest) orelse return error.TpmCommandFailed;
    const verify_handle = ctx.loadP256VerifyKey(primary.public_key) orelse return error.TpmCommandFailed;
    defer _ = ctx.flush(verify_handle);
    if (!ctx.verifyP256Sha256(verify_handle, tpm_digest, signature)) return error.TpmCommandFailed;
    std.debug.print("tls_tpm.sign/verify p256_sha256: signing_handle=0x{x} verify_handle=0x{x} signature=", .{
        primary.handle,
        verify_handle,
    });
    printHexRaw(&signature);
    std.debug.print("\n", .{});
}

fn printHex(label: []const u8, value: []const u8) void {
    std.debug.print("{s}: ", .{label});
    printHexRaw(value);
    std.debug.print("\n", .{});
}

fn printHexRaw(value: []const u8) void {
    for (value) |byte| std.debug.print("{x:0>2}", .{byte});
}

fn openTpm() CheckError!i32 {
    const rc = linux.open(device_path, .{ .ACCMODE = .RDWR, .CLOEXEC = true }, 0);
    if (linux.errno(rc) != .SUCCESS) return error.OpenTpmFailed;
    return @intCast(rc);
}

fn transactContext(user: ?*anyopaque, command: []const u8, response: []u8) ?[]const u8 {
    const fd_ptr: *const i32 = @ptrCast(@alignCast(user orelse return null));
    return transactFd(fd_ptr.*, command, response) catch null;
}

fn transactFd(fd: i32, command: []const u8, response: []u8) CheckError![]const u8 {
    const write_rc = linux.write(fd, command.ptr, command.len);
    if (linux.errno(write_rc) != .SUCCESS) return error.TpmWriteFailed;
    if (write_rc != command.len) return error.TpmShortWrite;

    const read_rc = linux.read(fd, response.ptr, response.len);
    if (linux.errno(read_rc) != .SUCCESS) return error.TpmReadFailed;
    if (read_rc == 0) return error.TpmEmptyResponse;
    return response[0..read_rc];
}

fn getAlgorithms(fd: i32, command: []u8, response: []u8) CheckError!tpm.AlgorithmProfile {
    const get_cap = tpm.buildGetCapability(tpm.cap_algs, 0, 128, command) orelse return error.BuildCommandFailed;
    const cap_response = try transactFd(fd, get_cap, response);
    if (!tpm.responseSuccess(cap_response)) return error.TpmCommandFailed;
    return tpm.parseAlgorithmProfile(cap_response) orelse error.ParseResponseFailed;
}

fn getCommands(fd: i32, command: []u8, response: []u8) CheckError!tpm.CommandProfile {
    const get_cap = tpm.buildGetCapability(tpm.cap_commands, 0, 128, command) orelse return error.BuildCommandFailed;
    const cap_response = try transactFd(fd, get_cap, response);
    if (!tpm.responseSuccess(cap_response)) return error.TpmCommandFailed;
    return tpm.parseCommandProfile(cap_response) orelse error.ParseResponseFailed;
}
