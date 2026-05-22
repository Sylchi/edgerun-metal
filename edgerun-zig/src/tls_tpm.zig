const std = @import("std");
const bytes = @import("bytes.zig");
const tpm = @import("tpm.zig");

pub const command_bytes = 256;
pub const response_bytes = 512;
pub const sha256_oneshot_max_bytes = 238;
pub const sha256_update_max_bytes = 227;
const external_key_material_max_bytes = tpm.sha256_digest_len + tpm.aes_256_key_len;

pub const TransactFn = *const fn (
    user: ?*anyopaque,
    command: []const u8,
    response: []u8,
) ?[]const u8;

pub const Context = struct {
    transact: TransactFn,
    user: ?*anyopaque = null,
    record_mode: u16,
    last_response_len: usize = 0,
    command: [command_bytes]u8 = [_]u8{0} ** command_bytes,
    response: [response_bytes]u8 = [_]u8{0} ** response_bytes,

    pub fn init(
        transact: TransactFn,
        user: ?*anyopaque,
        info: tpm.Tpm2Info,
        algorithms: tpm.AlgorithmProfile,
        commands: tpm.CommandProfile,
    ) ?Context {
        const mode = tpm.selectRecordCipherMode(algorithms) orelse return null;
        if (!tpm.tlsProfileSupported(info, algorithms, commands)) return null;
        return .{
            .transact = transact,
            .user = user,
            .record_mode = mode,
        };
    }

    pub fn getRandom(self: *Context, out: []u8) bool {
        if (out.len == 0 or out.len > std.math.maxInt(u16)) return false;
        const command = tpm.buildGetRandom(@intCast(out.len), &self.command) orelse return false;
        const response = self.runOrScrub(command) orelse return false;
        const parsed = tpm.parseGetRandom(response, out) orelse return false;
        return parsed.len == out.len;
    }

    pub fn sha256(self: *Context, data: []const u8) ?[tpm.sha256_digest_len]u8 {
        if (data.len == 0 or data.len > std.math.maxInt(u16)) return null;
        if (data.len <= sha256_oneshot_max_bytes) {
            const command = self.buildSha256Finish(.oneshot, 0, data) orelse return null;
            return self.runDigest(command);
        }

        const start = tpm.buildHashSequenceStartSha256(&self.command) orelse return null;
        const start_response = self.runOrScrub(start) orelse return null;
        const sequence_handle = tpm.parseHandle(start_response) orelse {
            self.scrubCommand();
            return null;
        };

        var cursor: usize = 0;
        while (data.len - cursor > sha256_update_max_bytes) {
            const chunk = data[cursor..][0..sha256_update_max_bytes];
            const update = tpm.buildSequenceUpdate(sequence_handle, chunk, &self.command) orelse return null;
            const update_response = self.runOrScrub(update) orelse return null;
            if (!tpm.responseSuccess(update_response)) {
                self.scrubCommand();
                return null;
            }
            self.scrubCommand();
            cursor += chunk.len;
        }

        const finish = self.buildSha256Finish(.sequence_complete, sequence_handle, data[cursor..]) orelse return null;
        return self.runDigest(finish);
    }

    pub fn loadHmacSha256Key(self: *Context, key: []const u8) ?u32 {
        return self.loadExternalKey(.hmac_sha256, key, 0);
    }

    pub fn hmacSha256(self: *Context, handle: u32, data: []const u8) ?[tpm.sha256_digest_len]u8 {
        const command = tpm.buildHmacSha256(handle, data, &self.command) orelse return null;
        return self.runDigest(command);
    }

    pub fn loadAesKey(self: *Context, key: []const u8, key_bits: u16) ?u32 {
        return self.loadExternalKey(.aes, key, key_bits);
    }

    pub fn recordCrypt(self: *Context, handle: u32, decrypt: bool, iv: []const u8, input: []const u8) ?tpm.CryptResult {
        const command = tpm.buildEncryptDecrypt2(handle, decrypt, self.record_mode, iv, input, &self.command) orelse return null;
        const response = self.runOrScrub(command) orelse return null;
        const parsed = tpm.parseEncryptDecrypt2(response);
        self.scrubCommand();
        return parsed;
    }

    pub fn createP256EcdhKey(self: *Context) ?tpm.P256Primary {
        const command = tpm.buildCreatePrimaryP256Ecdh(&self.command) orelse return null;
        const response = self.run(command) orelse return null;
        return tpm.parseCreatePrimaryP256(response);
    }

    pub fn ecdhZgen(self: *Context, handle: u32, peer_public_key: [tpm.p256_public_key_len]u8) ?[tpm.p256_public_key_len]u8 {
        const command = tpm.buildEcdhZgenP256(handle, peer_public_key, &self.command) orelse return null;
        const response = self.run(command) orelse return null;
        return tpm.parseP256Point(response);
    }

    pub fn loadP256VerifyKey(self: *Context, public_key: [tpm.p256_public_key_len]u8) ?u32 {
        const command = tpm.buildLoadExternalP256VerifyKey(public_key, &self.command) orelse return null;
        const response = self.run(command) orelse return null;
        return tpm.parseHandle(response);
    }

    pub fn verifyP256Sha256(self: *Context, handle: u32, digest: [tpm.sha256_digest_len]u8, signature: [tpm.p256_public_key_len]u8) bool {
        const command = tpm.buildVerifyP256Sha256(handle, digest, signature, &self.command) orelse return false;
        const response = self.run(command) orelse return false;
        return tpm.parseVerifyTicket(response);
    }

    pub fn signP256Sha256(self: *Context, handle: u32, digest: [tpm.sha256_digest_len]u8) ?[tpm.p256_public_key_len]u8 {
        const command = tpm.buildSignP256Sha256(handle, digest, &self.command) orelse return null;
        const response = self.run(command) orelse return null;
        return tpm.parseP256Sha256Signature(response);
    }

    pub fn flush(self: *Context, handle: u32) bool {
        const command = tpm.buildFlushContext(handle, &self.command) orelse return false;
        const response = self.run(command) orelse return false;
        return tpm.responseSuccess(response);
    }

    fn run(self: *Context, command: []const u8) ?[]const u8 {
        if (command.len == 0) return null;
        const response = self.transact(self.user, command, &self.response) orelse {
            self.last_response_len = 0;
            return null;
        };
        if (response.len > self.response.len) {
            self.last_response_len = 0;
            return null;
        }
        self.last_response_len = response.len;
        return self.response[0..response.len];
    }

    fn runOrScrub(self: *Context, command: []const u8) ?[]const u8 {
        const response = self.run(command) orelse {
            self.scrubCommand();
            return null;
        };
        return response;
    }

    fn runDigest(self: *Context, command: []const u8) ?[tpm.sha256_digest_len]u8 {
        const response = self.runOrScrub(command) orelse return null;
        const digest = tpm.parseSha256Digest(response);
        self.scrubCommand();
        return digest;
    }

    fn scrubCommand(self: *Context) void {
        bytes.zero(&self.command);
    }

    const Sha256FinishKind = enum { oneshot, sequence_complete };

    fn buildSha256Finish(self: *Context, kind: Sha256FinishKind, sequence_handle: u32, data: []const u8) ?[]u8 {
        return switch (kind) {
            .oneshot => tpm.buildHashSha256(data, tpm.rh_null, &self.command),
            .sequence_complete => tpm.buildSequenceComplete(sequence_handle, data, tpm.rh_null, &self.command),
        };
    }

    const ExternalKeyKind = enum { hmac_sha256, aes };

    fn loadExternalKey(self: *Context, kind: ExternalKeyKind, key: []const u8, key_bits: u16) ?u32 {
        if (key.len == 0 or key.len > external_key_material_max_bytes - tpm.sha256_digest_len) return null;

        var seed: [tpm.sha256_digest_len]u8 = undefined;
        var unique: [tpm.sha256_digest_len]u8 = undefined;
        defer bytes.zero(&seed);
        defer bytes.zero(&unique);

        if (!self.externalKeyUnique(key, &seed, &unique)) return null;

        const command = switch (kind) {
            .hmac_sha256 => tpm.buildLoadExternalHmacSha256Key(key, seed, unique, &self.command),
            .aes => tpm.buildLoadExternalAesKey(key, key_bits, self.record_mode, seed, unique, &self.command),
        } orelse {
            self.scrubCommand();
            return null;
        };
        const response = self.runOrScrub(command) orelse return null;
        const handle = tpm.parseHandle(response);
        self.scrubCommand();
        return handle;
    }

    fn externalKeyUnique(self: *Context, key: []const u8, seed: *[tpm.sha256_digest_len]u8, unique: *[tpm.sha256_digest_len]u8) bool {
        if (!self.getRandom(seed)) return false;
        var material: [external_key_material_max_bytes]u8 = undefined;
        defer bytes.zero(&material);
        @memcpy(material[0..tpm.sha256_digest_len], seed);
        @memcpy(material[tpm.sha256_digest_len..][0..key.len], key);
        unique.* = self.sha256(material[0 .. tpm.sha256_digest_len + key.len]) orelse return false;
        return true;
    }
};

fn responseHeader(response: []u8, response_len: usize) void {
    response[0] = 0x80;
    response[1] = 0x01;
    putBe32(response[2..6], @intCast(response_len));
    putBe32(response[6..10], tpm.rc_success);
}

fn putBe16(out: []u8, value: u16) void {
    out[0] = @intCast((value >> 8) & 0xff);
    out[1] = @intCast(value & 0xff);
}

fn putBe32(out: []u8, value: u32) void {
    out[0] = @intCast((value >> 24) & 0xff);
    out[1] = @intCast((value >> 16) & 0xff);
    out[2] = @intCast((value >> 8) & 0xff);
    out[3] = @intCast(value & 0xff);
}

fn getBe32(in: []const u8) u32 {
    return (@as(u32, in[0]) << 24) |
        (@as(u32, in[1]) << 16) |
        (@as(u32, in[2]) << 8) |
        @as(u32, in[3]);
}

const TestScript = struct {
    calls: usize = 0,
    last_command_code: u32 = 0,
    last_command_len: usize = 0,
    last_command: [command_bytes]u8 = [_]u8{0} ** command_bytes,
};

fn testTransact(user: ?*anyopaque, command: []const u8, response: []u8) ?[]const u8 {
    const script: *TestScript = @ptrCast(@alignCast(user.?));
    if (command.len > script.last_command.len or response.len < tpm.header_len) return null;
    bytes.zero(&script.last_command);
    @memcpy(script.last_command[0..command.len], command);
    script.last_command_len = command.len;
    script.last_command_code = getBe32(command[6..10]);
    script.calls += 1;

    return switch (script.last_command_code) {
        tpm.cc_get_random => testRandomResponse(command, response),
        tpm.cc_hash, tpm.cc_hmac, tpm.cc_sequence_complete => testDigestResponse(response),
        tpm.cc_hash_sequence_start => testHandleResponse(response, 0x8000_0014),
        tpm.cc_load_external => if (command.len == 124) testHandleResponse(response, 0x8000_0011) else if (command.len == 136 and command[87] == tpm.alg_keyedhash) testHandleResponse(response, 0x8000_0010) else testHandleResponse(response, 0x8000_0012),
        tpm.cc_encrypt_decrypt2 => testCryptResponse(response),
        tpm.cc_create_primary => testCreatePrimaryResponse(response),
        tpm.cc_ecdh_zgen => testPointResponse(response),
        tpm.cc_verify_signature => testVerifyResponse(response),
        tpm.cc_sign => testSignatureResponse(response),
        tpm.cc_sequence_update, tpm.cc_flush_context => blk: {
            responseHeader(response, tpm.header_len);
            break :blk response[0..tpm.header_len];
        },
        else => null,
    };
}

fn testHandleResponse(response: []u8, handle: u32) ?[]const u8 {
    const len = tpm.header_len + 4;
    if (response.len < len) return null;
    responseHeader(response, len);
    putBe32(response[tpm.header_len..][0..4], handle);
    return response[0..len];
}

fn testDigestResponse(response: []u8) ?[]const u8 {
    const len = tpm.header_len + 2 + tpm.sha256_digest_len;
    if (response.len < len) return null;
    responseHeader(response, len);
    putBe16(response[tpm.header_len..][0..2], tpm.sha256_digest_len);
    @memset(response[tpm.header_len + 2 ..][0..tpm.sha256_digest_len], 0x33);
    return response[0..len];
}

fn testRandomResponse(command: []const u8, response: []u8) ?[]const u8 {
    const requested = (@as(u16, command[10]) << 8) | @as(u16, command[11]);
    const len = tpm.header_len + 2 + requested;
    if (response.len < len) return null;
    responseHeader(response, len);
    putBe16(response[tpm.header_len..][0..2], requested);
    @memset(response[tpm.header_len + 2 ..][0..requested], 0x90);
    return response[0..len];
}

fn testCryptResponse(response: []u8) ?[]const u8 {
    const block_len = 16;
    const len = tpm.header_len + 4 + 2 + block_len + 2 + block_len;
    if (response.len < len) return null;
    response[0] = 0x80;
    response[1] = 0x02;
    putBe32(response[2..6], len);
    putBe32(response[6..10], tpm.rc_success);
    putBe32(response[10..14], 4 + block_len + block_len);
    putBe16(response[14..16], block_len);
    @memset(response[16..][0..block_len], 0xa0);
    putBe16(response[32..34], block_len);
    @memset(response[34..][0..block_len], 0xb0);
    return response[0..len];
}

fn testPointResponse(response: []u8) ?[]const u8 {
    const len = tpm.header_len + 2 + 2 + 32 + 2 + 32;
    if (response.len < len) return null;
    responseHeader(response, len);
    putBe16(response[10..12], 68);
    putBe16(response[12..14], 32);
    @memset(response[14..][0..32], 0x44);
    putBe16(response[46..48], 32);
    @memset(response[48..][0..32], 0x64);
    return response[0..len];
}

fn testVerifyResponse(response: []u8) ?[]const u8 {
    const len = 18;
    if (response.len < len) return null;
    responseHeader(response, len);
    putBe16(response[10..12], tpm.st_hashcheck);
    putBe32(response[12..16], tpm.rh_null);
    putBe16(response[16..18], 0);
    return response[0..len];
}

fn testSignatureResponse(response: []u8) ?[]const u8 {
    const len = tpm.header_len + 4 + 2 + 32 + 2 + 32;
    if (response.len < len) return null;
    responseHeader(response, len);
    putBe16(response[10..12], tpm.alg_ecdsa);
    putBe16(response[12..14], tpm.alg_sha256);
    putBe16(response[14..16], 32);
    @memset(response[16..][0..32], 0x41);
    putBe16(response[48..50], 32);
    @memset(response[50..][0..32], 0x61);
    return response[0..len];
}

fn testCreatePrimaryResponse(response: []u8) ?[]const u8 {
    const len = 126;
    if (response.len < len) return null;
    response[0] = 0x80;
    response[1] = 0x02;
    putBe32(response[2..6], len);
    putBe32(response[6..10], tpm.rc_success);
    putBe32(response[10..14], 0x8000_0013);
    putBe32(response[14..18], 90);
    var offset: usize = 18;
    putBe16(response[offset..][0..2], 88);
    offset += 2;
    putBe16(response[offset..][0..2], tpm.alg_ecc);
    offset += 2;
    putBe16(response[offset..][0..2], tpm.alg_sha256);
    offset += 2;
    putBe32(response[offset..][0..4], 0x0004_0472);
    offset += 4;
    putBe16(response[offset..][0..2], 0);
    offset += 2;
    putBe16(response[offset..][0..2], tpm.alg_null);
    offset += 2;
    putBe16(response[offset..][0..2], tpm.alg_ecdsa);
    offset += 2;
    putBe16(response[offset..][0..2], tpm.alg_sha256);
    offset += 2;
    putBe16(response[offset..][0..2], tpm.ecc_nist_p256);
    offset += 2;
    putBe16(response[offset..][0..2], tpm.alg_null);
    offset += 2;
    putBe16(response[offset..][0..2], 32);
    offset += 2;
    @memset(response[offset..][0..32], 0x71);
    offset += 32;
    putBe16(response[offset..][0..2], 32);
    offset += 2;
    @memset(response[offset..][0..32], 0x91);
    return response[0..len];
}

fn testProfiles() struct { tpm.Tpm2Info, tpm.AlgorithmProfile, tpm.CommandProfile } {
    return .{
        .{ .found = true, .start_method = 6 },
        .{
            .has_sha256 = true,
            .has_hmac = true,
            .has_keyedhash = true,
            .has_ecc = true,
            .has_ecdh = true,
            .has_ecdsa = true,
            .has_aes = true,
            .has_symcipher = true,
            .has_ctr = true,
        },
        .{
            .has_create_primary = true,
            .has_ecdh_zgen = true,
            .has_encrypt_decrypt2 = true,
            .has_get_random = true,
            .has_hash = true,
            .has_hash_sequence_start = true,
            .has_hmac = true,
            .has_load_external = true,
            .has_sequence_complete = true,
            .has_sequence_update = true,
            .has_sign = true,
            .has_verify_signature = true,
        },
    };
}

test "tls tpm adapter ports deleted C operation layer" {
    var script = TestScript{};
    const profiles = testProfiles();
    var ctx = Context.init(testTransact, &script, profiles[0], profiles[1], profiles[2]).?;
    try std.testing.expectEqual(tpm.alg_ctr, ctx.record_mode);

    var incomplete = profiles[2];
    incomplete.has_hmac = false;
    try std.testing.expect(Context.init(testTransact, &script, profiles[0], profiles[1], incomplete) == null);

    var random: [tpm.sha256_digest_len]u8 = undefined;
    try std.testing.expect(ctx.getRandom(&random));
    try std.testing.expectEqual(tpm.cc_get_random, script.last_command_code);
    try std.testing.expectEqual(@as(u8, 0x90), random[0]);

    const digest = ctx.sha256(&random).?;
    try std.testing.expectEqual(tpm.cc_hash, script.last_command_code);
    try std.testing.expectEqual(@as(u8, 0x33), digest[0]);
    try std.testing.expect(!bytes.nonzero(&ctx.command));

    const hmac_handle = ctx.loadHmacSha256Key(&digest).?;
    try std.testing.expectEqual(@as(u32, 0x8000_0010), hmac_handle);
    try std.testing.expectEqual(@as(u8, 0x90), script.last_command[18]);
    try std.testing.expectEqual(@as(u8, 0x33), script.last_command[100]);
    try std.testing.expect(!bytes.nonzero(&ctx.command));

    const hmac_digest = ctx.hmacSha256(hmac_handle, &random).?;
    try std.testing.expectEqual(tpm.cc_hmac, script.last_command_code);
    try std.testing.expectEqual(@as(u8, 0x33), hmac_digest[0]);
    try std.testing.expect(!bytes.nonzero(&ctx.command));

    const key = [_]u8{0xc0} ** tpm.aes_128_key_len;
    const aes_handle = ctx.loadAesKey(&key, tpm.aes_128_key_bits).?;
    try std.testing.expectEqual(@as(u32, 0x8000_0011), aes_handle);
    try std.testing.expectEqual(@as(u8, 0x90), script.last_command[18]);
    try std.testing.expectEqual(@as(u8, 0x33), script.last_command[88]);
    try std.testing.expectEqual(@as(u8, tpm.alg_ctr), script.last_command[85]);
    try std.testing.expect(!bytes.nonzero(&ctx.command));

    const iv = [_]u8{0x50} ** 16;
    const crypt = ctx.recordCrypt(aes_handle, false, &iv, random[0..16]).?;
    try std.testing.expectEqual(tpm.cc_encrypt_decrypt2, script.last_command_code);
    try std.testing.expectEqual(@as(u8, 0xa0), crypt.data[0]);
    try std.testing.expectEqual(@as(u8, 0xb0), crypt.iv[0]);
    try std.testing.expect(!bytes.nonzero(&ctx.command));

    const primary = ctx.createP256EcdhKey().?;
    try std.testing.expectEqual(@as(u32, 0x8000_0013), primary.handle);
    try std.testing.expectEqual(@as(u8, 0x71), primary.public_key[0]);

    const point = ctx.ecdhZgen(primary.handle, primary.public_key).?;
    try std.testing.expectEqual(tpm.cc_ecdh_zgen, script.last_command_code);
    try std.testing.expectEqual(@as(u8, 0x44), point[0]);
    try std.testing.expectEqual(@as(u8, 0x64), point[32]);

    const verify_handle = ctx.loadP256VerifyKey(primary.public_key).?;
    try std.testing.expectEqual(@as(u32, 0x8000_0012), verify_handle);

    const signature_input = [_]u8{0x20} ** tpm.p256_public_key_len;
    try std.testing.expect(ctx.verifyP256Sha256(verify_handle, digest, signature_input));
    try std.testing.expectEqual(tpm.cc_verify_signature, script.last_command_code);

    const signature = ctx.signP256Sha256(primary.handle, digest).?;
    try std.testing.expectEqual(tpm.cc_sign, script.last_command_code);
    try std.testing.expectEqual(@as(u8, 0x41), signature[0]);
    try std.testing.expectEqual(@as(u8, 0x61), signature[32]);

    try std.testing.expect(ctx.flush(primary.handle));
    try std.testing.expectEqual(tpm.cc_flush_context, script.last_command_code);
    try std.testing.expectEqual(@as(usize, 16), script.calls);
}
