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
