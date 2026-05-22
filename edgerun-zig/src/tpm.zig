const std = @import("std");
const bytes = @import("bytes.zig");

pub const header_len = 10;
pub const crb_max_buffer_size = 65536;

pub const st_no_sessions: u16 = 0x8001;
pub const st_sessions: u16 = 0x8002;
pub const st_hashcheck: u16 = 0x8024;

pub const rc_success: u32 = 0x00000000;
pub const rc_metal_protocol: u32 = 0xffff_fffc;

pub const cc_startup: u32 = 0x0000_0144;
pub const cc_create_primary: u32 = 0x0000_0131;
pub const cc_ecdh_zgen: u32 = 0x0000_0154;
pub const cc_hmac: u32 = 0x0000_0155;
pub const cc_load_external: u32 = 0x0000_0167;
pub const cc_get_capability: u32 = 0x0000_017a;
pub const cc_get_random: u32 = 0x0000_017b;
pub const cc_hash: u32 = 0x0000_017d;
pub const cc_encrypt_decrypt2: u32 = 0x0000_0193;
pub const cc_hash_sequence_start: u32 = 0x0000_0186;
pub const cc_sequence_complete: u32 = 0x0000_013e;
pub const cc_sequence_update: u32 = 0x0000_015c;
pub const cc_sign: u32 = 0x0000_015d;
pub const cc_verify_signature: u32 = 0x0000_0177;
pub const cc_flush_context: u32 = 0x0000_0165;

pub const su_clear: u16 = 0x0000;
pub const rs_pw: u32 = 0x4000_0009;
pub const rh_owner: u32 = 0x4000_0001;
pub const rh_endorsement: u32 = 0x4000_000b;
pub const rh_platform: u32 = 0x4000_000c;
pub const rh_null: u32 = 0x4000_0007;

pub const alg_null: u16 = 0x0010;
pub const alg_aes: u16 = 0x0006;
pub const alg_hmac: u16 = 0x0005;
pub const alg_keyedhash: u16 = 0x0008;
pub const alg_sha256: u16 = 0x000b;
pub const alg_ecdsa: u16 = 0x0018;
pub const alg_ecc: u16 = 0x0023;
pub const alg_ecdh: u16 = 0x0019;
pub const alg_symcipher: u16 = 0x0025;
pub const alg_ctr: u16 = 0x0040;
pub const alg_ofb: u16 = 0x0041;
pub const alg_cbc: u16 = 0x0042;
pub const alg_cfb: u16 = 0x0043;
pub const alg_ecb: u16 = 0x0044;
pub const ecc_nist_p256: u16 = 0x0003;

pub const cap_algs: u32 = 0x0000_0000;
pub const cap_commands: u32 = 0x0000_0002;
pub const cap_tpm_properties: u32 = 0x0000_0006;
pub const pt_nv_index_max: u32 = 0x0000_0117;
pub const pt_nv_buffer_max: u32 = 0x0000_012c;

pub const sha256_digest_len = 32;
pub const p256_public_key_len = 64;
pub const aes_128_key_len = 16;
pub const aes_256_key_len = 32;
pub const aes_128_key_bits = 128;
pub const aes_256_key_bits = 256;

const command_size_offset = 2;
const command_code_offset = 6;
const response_size_offset = 2;
const response_code_offset = 6;
const random_bytes_offset = 12;

const startup_command_len = 12;
const get_random_command_len = 12;
const hash_command_fixed_len = 18;
const hmac_command_fixed_len = 31;
const hash_sequence_start_command_len = 14;
const sequence_update_command_fixed_len = 29;
const sequence_complete_command_fixed_len = 33;
const get_capability_command_len = 22;
const create_primary_command_len = 65;
const create_primary_public_len = 24;
const empty_sensitive_create_len = 4;
const auth_value_len = 9;
const read_public_command_len = 14;
const load_external_p256_command_len = 106;
const load_external_p256_public_area_len = 88;
const load_external_keyedhash_fixed_len = 104;
const load_external_symcipher_fixed_len = 108;
const load_external_key_seed_len = sha256_digest_len;
const load_external_key_unique_len = sha256_digest_len;
const load_external_keyedhash_public_area_len = 46;
const load_external_symcipher_public_area_len = 50;
const load_external_hmac_sensitive_header_len = 8;
const load_external_aes_sensitive_header_len = 8;
const sign_command_len = 73;
const verify_p256_sha256_command_len = 120;
const encrypt_decrypt2_command_fixed_len = 34;
const ecdh_zgen_command_len = 97;
const p256_point_body_len = 68;
const flush_context_command_len = 14;
const pw_auth_area_len = 9;
const tpm2b_len_bytes = 2;
const p256_point_bytes = 32;
const signature_scheme_and_hash_len = 4;
const signature_max_component_len = 32;
const tpma_object_fixed_tpm: u32 = 0x0000_0002;
const tpma_object_fixed_parent: u32 = 0x0000_0010;
const tpma_object_sensitive_data_origin: u32 = 0x0000_0020;
const tpma_object_user_with_auth: u32 = 0x0000_0040;
const tpma_object_noda: u32 = 0x0000_0400;
const tpma_object_decrypt: u32 = 0x0002_0000;
const tpma_object_sign_encrypt: u32 = 0x0004_0000;
const tpmt_public_fixed_len = 10;
const ecc_params_len = 10;
const public_auth_policy_offset = 8;
const tagged_property_len = 8;

pub const Tpm2Info = struct {
    found: bool = false,
    start_method: u32 = 0,

    pub fn isCrb(self: Tpm2Info) bool {
        return self.found and (self.start_method == 6 or self.start_method == 7 or self.start_method == 8);
    }
};

pub const NvLimits = struct {
    nv_index_max: u32,
    nv_buffer_max: u32,
};

pub const P256Primary = struct {
    handle: u32,
    public_key: [p256_public_key_len]u8,
};

pub const AlgorithmProfile = struct {
    has_sha256: bool = false,
    has_hmac: bool = false,
    has_keyedhash: bool = false,
    has_ecc: bool = false,
    has_ecdh: bool = false,
    has_ecdsa: bool = false,
    has_aes: bool = false,
    has_symcipher: bool = false,
    has_ctr: bool = false,
    has_ofb: bool = false,
    has_cbc: bool = false,
    has_cfb: bool = false,
    has_ecb: bool = false,
};

pub const CommandProfile = struct {
    has_create_primary: bool = false,
    has_ecdh_zgen: bool = false,
    has_encrypt_decrypt2: bool = false,
    has_get_random: bool = false,
    has_hash: bool = false,
    has_hash_sequence_start: bool = false,
    has_hmac: bool = false,
    has_load_external: bool = false,
    has_sequence_complete: bool = false,
    has_sequence_update: bool = false,
    has_sign: bool = false,
    has_verify_signature: bool = false,
};

pub const CryptResult = struct {
    data: []const u8,
    iv: []const u8,
};

pub const Error = error{
    BadArgument,
    NoSpace,
    Corrupt,
};

pub const Writer = struct {
    out: []u8,
    offset: usize = header_len,

    pub fn init(out: []u8) Writer {
        return .{ .out = out };
    }

    pub fn putU8(self: *Writer, value: u8) bool {
        if (self.offset >= self.out.len) return false;
        self.out[self.offset] = value;
        self.offset += 1;
        return true;
    }

    pub fn putU16(self: *Writer, value: u16) bool {
        if (self.out.len - self.offset < 2) return false;
        putBe16(self.out[self.offset..][0..2], value);
        self.offset += 2;
        return true;
    }

    pub fn putU32(self: *Writer, value: u32) bool {
        if (self.out.len - self.offset < 4) return false;
        putBe32(self.out[self.offset..][0..4], value);
        self.offset += 4;
        return true;
    }

    pub fn putBytes(self: *Writer, value: []const u8) bool {
        if (self.out.len - self.offset < value.len) return false;
        @memcpy(self.out[self.offset..][0..value.len], value);
        self.offset += value.len;
        return true;
    }

    pub fn putTpm2b(self: *Writer, value: []const u8) bool {
        if (value.len > std.math.maxInt(u16)) return false;
        return self.putU16(@intCast(value.len)) and self.putBytes(value);
    }

    pub fn putP256Point(self: *Writer, point: [p256_public_key_len]u8) bool {
        return self.putTpm2b(point[0..p256_point_bytes]) and self.putTpm2b(point[p256_point_bytes..p256_public_key_len]);
    }

    pub fn putPwAuthHandle(self: *Writer, handle: u32) bool {
        return self.putU32(handle) and
            self.putU32(pw_auth_area_len) and
            self.putU32(rs_pw) and
            self.putU16(0) and
            self.putU8(0) and
            self.putU16(0);
    }

    pub fn finish(self: Writer, expected_len: usize) bool {
        return self.offset == expected_len;
    }
};

pub fn buildStartup(startup_type: u16, out: []u8) ?[]u8 {
    const command = buildHeader(st_no_sessions, startup_command_len, cc_startup, out) orelse return null;
    putBe16(command[header_len..][0..2], startup_type);
    return command;
}

pub fn buildCreatePrimaryP256Signing(out: []u8) ?[]u8 {
    return buildCreatePrimaryP256(alg_ecdsa, tpma_object_sign_encrypt, out);
}

pub fn buildCreatePrimaryP256Ecdh(out: []u8) ?[]u8 {
    return buildCreatePrimaryP256(alg_ecdh, tpma_object_decrypt, out);
}

pub fn buildGetRandom(bytes_requested: u16, out: []u8) ?[]u8 {
    if (bytes_requested == 0) return null;
    const command = buildHeader(st_no_sessions, get_random_command_len, cc_get_random, out) orelse return null;
    putBe16(command[header_len..][0..2], bytes_requested);
    return command;
}

pub fn buildReadPublic(handle: u32, out: []u8) ?[]u8 {
    if (handle == 0) return null;
    const command = buildHeader(st_no_sessions, read_public_command_len, 0x0000_0173, out) orelse return null;
    putBe32(command[header_len..][0..4], handle);
    return command;
}

pub fn buildLoadExternalP256VerifyKey(public_key: [p256_public_key_len]u8, out: []u8) ?[]u8 {
    const command = buildHeader(st_no_sessions, load_external_p256_command_len, cc_load_external, out) orelse return null;
    var writer = Writer.init(command);
    if (!writer.putU16(0) or
        !writer.putU16(load_external_p256_public_area_len) or
        !writer.putU16(alg_ecc) or
        !writer.putU16(alg_sha256) or
        !writer.putU32(tpma_object_sign_encrypt) or
        !writer.putU16(0) or
        !writer.putU16(alg_null) or
        !writer.putU16(alg_ecdsa) or
        !writer.putU16(alg_sha256) or
        !writer.putU16(ecc_nist_p256) or
        !writer.putU16(alg_null) or
        !writer.putTpm2b(public_key[0..p256_point_bytes]) or
        !writer.putTpm2b(public_key[p256_point_bytes..p256_public_key_len]) or
        !writer.putU32(rh_null)) return null;
    if (!writer.finish(load_external_p256_command_len)) return null;
    return command;
}

pub fn buildHashSha256(data: []const u8, hierarchy: u32, out: []u8) ?[]u8 {
    if (data.len == 0 or data.len > std.math.maxInt(u16) or !validHierarchy(hierarchy)) return null;
    const command_len = hash_command_fixed_len + data.len;
    const command = buildHeader(st_no_sessions, command_len, cc_hash, out) orelse return null;
    var writer = Writer.init(command);
    if (!writer.putTpm2b(data) or !writer.putU16(alg_sha256) or !writer.putU32(hierarchy)) return null;
    if (!writer.finish(command_len)) return null;
    return command;
}

pub fn buildHmacSha256(handle: u32, data: []const u8, out: []u8) ?[]u8 {
    if (handle == 0 or data.len == 0 or data.len > std.math.maxInt(u16)) return null;
    const command_len = hmac_command_fixed_len + data.len;
    const command = buildHeader(st_sessions, command_len, cc_hmac, out) orelse return null;
    var writer = Writer.init(command);
    if (!writer.putPwAuthHandle(handle) or !writer.putTpm2b(data) or !writer.putU16(alg_sha256)) return null;
    if (!writer.finish(command_len)) return null;
    return command;
}

pub fn buildHashSequenceStartSha256(out: []u8) ?[]u8 {
    const command = buildHeader(st_no_sessions, hash_sequence_start_command_len, cc_hash_sequence_start, out) orelse return null;
    var writer = Writer.init(command);
    if (!writer.putU16(0) or !writer.putU16(alg_sha256)) return null;
    if (!writer.finish(hash_sequence_start_command_len)) return null;
    return command;
}

pub fn buildSequenceUpdate(handle: u32, data: []const u8, out: []u8) ?[]u8 {
    if (handle == 0 or data.len == 0 or data.len > std.math.maxInt(u16)) return null;
    const command_len = sequence_update_command_fixed_len + data.len;
    const command = buildHeader(st_sessions, command_len, cc_sequence_update, out) orelse return null;
    var writer = Writer.init(command);
    if (!writer.putPwAuthHandle(handle) or !writer.putTpm2b(data)) return null;
    if (!writer.finish(command_len)) return null;
    return command;
}

pub fn buildSequenceComplete(handle: u32, data: []const u8, hierarchy: u32, out: []u8) ?[]u8 {
    if (handle == 0 or data.len == 0 or data.len > std.math.maxInt(u16) or !validHierarchy(hierarchy)) return null;
    const command_len = sequence_complete_command_fixed_len + data.len;
    const command = buildHeader(st_sessions, command_len, cc_sequence_complete, out) orelse return null;
    var writer = Writer.init(command);
    if (!writer.putPwAuthHandle(handle) or !writer.putTpm2b(data) or !writer.putU32(hierarchy)) return null;
    if (!writer.finish(command_len)) return null;
    return command;
}

pub fn buildGetCapability(capability: u32, property: u32, property_count: u32, out: []u8) ?[]u8 {
    if (property_count == 0) return null;
    const command = buildHeader(st_no_sessions, get_capability_command_len, cc_get_capability, out) orelse return null;
    putBe32(command[10..14], capability);
    putBe32(command[14..18], property);
    putBe32(command[18..22], property_count);
    return command;
}

pub fn buildLoadExternalHmacSha256Key(key: []const u8, seed: [sha256_digest_len]u8, unique: [sha256_digest_len]u8, out: []u8) ?[]u8 {
    if (key.len == 0 or key.len > std.math.maxInt(u16) - load_external_hmac_sensitive_header_len - load_external_key_seed_len) return null;
    const sensitive_area_len: u16 = @intCast(load_external_hmac_sensitive_header_len + load_external_key_seed_len + key.len);
    const command_len = load_external_keyedhash_fixed_len + key.len;
    const command = buildHeader(st_no_sessions, command_len, cc_load_external, out) orelse return null;
    var writer = Writer.init(command);
    if (!putLoadExternalSensitive(&writer, sensitive_area_len, alg_keyedhash, key, seed) or
        !putLoadExternalPublicPrefix(&writer, load_external_keyedhash_public_area_len, alg_keyedhash) or
        !writer.putU16(alg_null) or
        !writer.putTpm2b(&unique) or
        !writer.putU32(rh_null)) return null;
    if (!writer.finish(command_len)) return null;
    return command;
}

pub fn buildLoadExternalAesKey(key: []const u8, key_bits: u16, mode: u16, seed: [sha256_digest_len]u8, unique: [sha256_digest_len]u8, out: []u8) ?[]u8 {
    switch (key_bits) {
        aes_128_key_bits => if (key.len != aes_128_key_len) return null,
        aes_256_key_bits => if (key.len != aes_256_key_len) return null,
        else => return null,
    }
    if (!symmetricModeSupported(mode)) return null;

    const sensitive_area_len: u16 = @intCast(load_external_aes_sensitive_header_len + load_external_key_seed_len + key.len);
    const command_len = load_external_symcipher_fixed_len + key.len;
    const command = buildHeader(st_no_sessions, command_len, cc_load_external, out) orelse return null;
    var writer = Writer.init(command);
    if (!putLoadExternalSensitive(&writer, sensitive_area_len, alg_symcipher, key, seed) or
        !putLoadExternalPublicPrefix(&writer, load_external_symcipher_public_area_len, alg_symcipher) or
        !writer.putU16(alg_aes) or
        !writer.putU16(key_bits) or
        !writer.putU16(mode) or
        !writer.putTpm2b(&unique) or
        !writer.putU32(rh_null)) return null;
    if (!writer.finish(command_len)) return null;
    return command;
}

pub fn buildSignP256Sha256(handle: u32, digest: [sha256_digest_len]u8, out: []u8) ?[]u8 {
    if (handle == 0) return null;
    const command = buildHeader(st_sessions, sign_command_len, cc_sign, out) orelse return null;
    var writer = Writer.init(command);
    if (!writer.putPwAuthHandle(handle) or
        !writer.putTpm2b(&digest) or
        !writer.putU16(alg_ecdsa) or
        !writer.putU16(alg_sha256) or
        !writer.putU16(st_hashcheck) or
        !writer.putU32(rh_null) or
        !writer.putU16(0)) return null;
    if (!writer.finish(sign_command_len)) return null;
    return command;
}

pub fn buildVerifyP256Sha256(handle: u32, digest: [sha256_digest_len]u8, signature: [p256_public_key_len]u8, out: []u8) ?[]u8 {
    if (handle == 0) return null;
    const command = buildHeader(st_no_sessions, verify_p256_sha256_command_len, cc_verify_signature, out) orelse return null;
    var writer = Writer.init(command);
    if (!writer.putU32(handle) or
        !writer.putTpm2b(&digest) or
        !writer.putU16(alg_ecdsa) or
        !writer.putU16(alg_sha256) or
        !writer.putTpm2b(signature[0..p256_point_bytes]) or
        !writer.putTpm2b(signature[p256_point_bytes..p256_public_key_len])) return null;
    if (!writer.finish(verify_p256_sha256_command_len)) return null;
    return command;
}

pub fn buildEncryptDecrypt2(handle: u32, decrypt: bool, mode: u16, iv: []const u8, input: []const u8, out: []u8) ?[]u8 {
    if (handle == 0 or !symmetricModeSupported(mode) or iv.len == 0 or input.len == 0 or iv.len > std.math.maxInt(u16) or input.len > std.math.maxInt(u16)) return null;
    const command_len = encrypt_decrypt2_command_fixed_len + iv.len + input.len;
    const command = buildHeader(st_sessions, command_len, cc_encrypt_decrypt2, out) orelse return null;
    var writer = Writer.init(command);
    if (!writer.putPwAuthHandle(handle) or
        !writer.putTpm2b(input) or
        !writer.putU8(if (decrypt) 1 else 0) or
        !writer.putU16(mode) or
        !writer.putTpm2b(iv)) return null;
    if (!writer.finish(command_len)) return null;
    return command;
}

pub fn buildEcdhZgenP256(handle: u32, peer_public_key: [p256_public_key_len]u8, out: []u8) ?[]u8 {
    if (handle == 0) return null;
    const command = buildHeader(st_sessions, ecdh_zgen_command_len, cc_ecdh_zgen, out) orelse return null;
    var writer = Writer.init(command);
    if (!writer.putPwAuthHandle(handle) or
        !writer.putU16(p256_point_body_len) or
        !writer.putP256Point(peer_public_key)) return null;
    if (!writer.finish(ecdh_zgen_command_len)) return null;
    return command;
}

pub fn buildFlushContext(handle: u32, out: []u8) ?[]u8 {
    if (handle == 0) return null;
    const command = buildHeader(st_no_sessions, flush_context_command_len, cc_flush_context, out) orelse return null;
    putBe32(command[header_len..][0..4], handle);
    return command;
}

pub fn responseCode(response: []const u8) u32 {
    if (response.len < header_len) return rc_metal_protocol;
    const claimed_len = getBe32(response[response_size_offset..][0..4]);
    if (claimed_len != response.len) return rc_metal_protocol;
    return getBe32(response[response_code_offset..][0..4]);
}

pub fn responseSuccess(response: []const u8) bool {
    return responseCode(response) == rc_success;
}

pub fn parseGetRandom(response: []const u8, out: []u8) ?[]u8 {
    if (!responseSuccess(response) or response.len < random_bytes_offset) return null;
    const random_len = getBe16(response[header_len..][0..2]);
    if (random_len > out.len or random_bytes_offset + random_len > response.len) return null;
    @memcpy(out[0..random_len], response[random_bytes_offset..][0..random_len]);
    return out[0..random_len];
}

pub fn parseSha256Digest(response: []const u8) ?[sha256_digest_len]u8 {
    if (!responseSuccess(response)) return null;
    var cursor: usize = header_len;
    const parameter_end = responseParameterWindow(response, &cursor) orelse return null;
    if (parameter_end - cursor < tpm2b_len_bytes) return null;
    const digest_len = getBe16(response[cursor..][0..2]);
    cursor += tpm2b_len_bytes;
    if (digest_len != sha256_digest_len or parameter_end - cursor < sha256_digest_len) return null;
    var out: [sha256_digest_len]u8 = undefined;
    @memcpy(&out, response[cursor..][0..sha256_digest_len]);
    return out;
}

pub fn parseHandle(response: []const u8) ?u32 {
    if (!responseSuccess(response) or response.len < header_len + 4) return null;
    const handle = getBe32(response[header_len..][0..4]);
    if (handle == 0) return null;
    return handle;
}

pub fn parseVerifyTicket(response: []const u8) bool {
    if (!responseSuccess(response) or response.len < header_len + 8) return false;
    var cursor: usize = header_len;
    if (getBe16(response[cursor..][0..2]) != st_hashcheck) return false;
    cursor += 2;
    cursor += 4;
    const digest_len = getBe16(response[cursor..][0..2]);
    cursor += 2;
    return digest_len <= response.len - cursor and cursor + digest_len == response.len;
}

pub fn parseNvStorageLimits(response: []const u8) ?NvLimits {
    if (!responseSuccess(response) or response.len < 19) return null;
    var cursor: usize = header_len + 1;
    if (getBe32(response[cursor..][0..4]) != cap_tpm_properties) return null;
    cursor += 4;
    const count = getBe32(response[cursor..][0..4]);
    cursor += 4;
    if (count > (response.len - cursor) / tagged_property_len) return null;

    var has_index = false;
    var has_buffer = false;
    var index_max: u32 = 0;
    var buffer_max: u32 = 0;
    var i: usize = 0;
    while (i < count) : (i += 1) {
        const property = getBe32(response[cursor..][0..4]);
        cursor += 4;
        const value = getBe32(response[cursor..][0..4]);
        cursor += 4;
        switch (property) {
            pt_nv_index_max => {
                has_index = true;
                index_max = value;
            },
            pt_nv_buffer_max => {
                has_buffer = true;
                buffer_max = value;
            },
            else => {},
        }
    }
    if (cursor != response.len or !has_index or !has_buffer) return null;
    return .{ .nv_index_max = index_max, .nv_buffer_max = buffer_max };
}

pub fn parseCreatePrimaryP256(response: []const u8) ?P256Primary {
    if (!responseSuccess(response) or response.len < header_len + 6) return null;
    var cursor: usize = header_len;
    const handle = getBe32(response[cursor..][0..4]);
    cursor += 4;
    if (handle == 0) return null;
    const parameter_end = responseParameterWindow(response, &cursor) orelse return null;
    const public_area = readTpm2b(response, parameter_end, &cursor) orelse return null;
    const public_key = parseP256PublicArea(public_area) orelse return null;
    return .{ .handle = handle, .public_key = public_key };
}

pub fn parseEncryptDecrypt2(response: []const u8) ?CryptResult {
    if (!responseSuccess(response)) return null;
    var cursor: usize = header_len;
    const parameter_end = responseParameterWindow(response, &cursor) orelse return null;
    const data = readTpm2b(response, parameter_end, &cursor) orelse return null;
    const iv = readTpm2b(response, parameter_end, &cursor) orelse return null;
    if (cursor != parameter_end) return null;
    return .{ .data = data, .iv = iv };
}

pub fn parseP256Point(response: []const u8) ?[p256_public_key_len]u8 {
    if (!responseSuccess(response)) return null;
    var cursor: usize = header_len;
    const parameter_end = responseParameterWindow(response, &cursor) orelse return null;
    const point = readTpm2b(response, parameter_end, &cursor) orelse return null;
    if (cursor != parameter_end) return null;
    return parseP256PointWire(point);
}

pub fn parseP256Sha256Signature(response: []const u8) ?[p256_public_key_len]u8 {
    if (!responseSuccess(response)) return null;
    var cursor: usize = header_len;
    const parameter_end = responseParameterWindow(response, &cursor) orelse return null;
    if (cursor > parameter_end or parameter_end - cursor < signature_scheme_and_hash_len) return null;
    const scheme = getBe16(response[cursor..][0..2]);
    cursor += 2;
    const hash = getBe16(response[cursor..][0..2]);
    cursor += 2;
    const r = readTpm2b(response, parameter_end, &cursor) orelse return null;
    const s = readTpm2b(response, parameter_end, &cursor) orelse return null;
    if (scheme != alg_ecdsa or hash != alg_sha256 or r.len > signature_max_component_len or s.len > signature_max_component_len or cursor != parameter_end) return null;

    var out = [_]u8{0} ** p256_public_key_len;
    @memcpy(out[p256_point_bytes - r.len .. p256_point_bytes], r);
    @memcpy(out[p256_public_key_len - s.len .. p256_public_key_len], s);
    return out;
}

pub fn parseAlgorithmProfile(response: []const u8) ?AlgorithmProfile {
    if (!responseSuccess(response) or response.len < 19) return null;
    var cursor: usize = header_len + 1;
    if (getBe32(response[cursor..][0..4]) != cap_algs) return null;
    cursor += 4;
    const count = getBe32(response[cursor..][0..4]);
    cursor += 4;
    if (count > (response.len - cursor) / 6) return null;

    var out = AlgorithmProfile{};
    var index: usize = 0;
    while (index < count) : (index += 1) {
        const algorithm = getBe16(response[cursor..][0..2]);
        cursor += 6;
        switch (algorithm) {
            alg_sha256 => out.has_sha256 = true,
            alg_hmac => out.has_hmac = true,
            alg_keyedhash => out.has_keyedhash = true,
            alg_ecc => out.has_ecc = true,
            alg_ecdh => out.has_ecdh = true,
            alg_ecdsa => out.has_ecdsa = true,
            alg_aes => out.has_aes = true,
            alg_symcipher => out.has_symcipher = true,
            alg_ctr => out.has_ctr = true,
            alg_ofb => out.has_ofb = true,
            alg_cbc => out.has_cbc = true,
            alg_cfb => out.has_cfb = true,
            alg_ecb => out.has_ecb = true,
            else => {},
        }
    }
    if (cursor != response.len) return null;
    return out;
}

pub fn parseCommandProfile(response: []const u8) ?CommandProfile {
    if (!responseSuccess(response) or response.len < 19) return null;
    var cursor: usize = header_len + 1;
    if (getBe32(response[cursor..][0..4]) != cap_commands) return null;
    cursor += 4;
    const count = getBe32(response[cursor..][0..4]);
    cursor += 4;
    if (count > (response.len - cursor) / 4) return null;

    var out = CommandProfile{};
    var index: usize = 0;
    while (index < count) : (index += 1) {
        const command = getBe32(response[cursor..][0..4]) & 0xffff;
        cursor += 4;
        switch (command) {
            cc_create_primary => out.has_create_primary = true,
            cc_ecdh_zgen => out.has_ecdh_zgen = true,
            cc_encrypt_decrypt2 => out.has_encrypt_decrypt2 = true,
            cc_get_random => out.has_get_random = true,
            cc_hash => out.has_hash = true,
            cc_hash_sequence_start => out.has_hash_sequence_start = true,
            cc_hmac => out.has_hmac = true,
            cc_load_external => out.has_load_external = true,
            cc_sequence_complete => out.has_sequence_complete = true,
            cc_sequence_update => out.has_sequence_update = true,
            cc_sign => out.has_sign = true,
            cc_verify_signature => out.has_verify_signature = true,
            else => {},
        }
    }
    if (cursor != response.len) return null;
    return out;
}

pub fn selectRecordCipherMode(algorithms: AlgorithmProfile) ?u16 {
    if (algorithms.has_ctr) return alg_ctr;
    if (algorithms.has_cfb) return alg_cfb;
    if (algorithms.has_cbc) return alg_cbc;
    return null;
}

pub fn tlsProfileSupported(info: Tpm2Info, algorithms: AlgorithmProfile, commands: CommandProfile) bool {
    return info.isCrb() and
        algorithms.has_sha256 and
        algorithms.has_hmac and
        algorithms.has_keyedhash and
        algorithms.has_ecc and
        algorithms.has_ecdh and
        algorithms.has_ecdsa and
        algorithms.has_aes and
        algorithms.has_symcipher and
        selectRecordCipherMode(algorithms) != null and
        commands.has_create_primary and
        commands.has_ecdh_zgen and
        commands.has_encrypt_decrypt2 and
        commands.has_get_random and
        commands.has_hash and
        commands.has_hash_sequence_start and
        commands.has_hmac and
        commands.has_load_external and
        commands.has_sequence_complete and
        commands.has_sequence_update and
        commands.has_sign and
        commands.has_verify_signature;
}

fn buildHeader(tag: u16, size: usize, command_code: u32, out: []u8) ?[]u8 {
    if (size < header_len or size > crb_max_buffer_size or out.len < size) return null;
    const command = out[0..size];
    putBe16(command[0..2], tag);
    putBe32(command[command_size_offset..][0..4], @intCast(size));
    putBe32(command[command_code_offset..][0..4], command_code);
    return command;
}

fn buildCreatePrimaryP256(scheme: u16, crypto_attribute: u32, out: []u8) ?[]u8 {
    if (scheme != alg_ecdsa and scheme != alg_ecdh) return null;
    const command = buildHeader(st_sessions, create_primary_command_len, cc_create_primary, out) orelse return null;
    const object_attributes = tpma_object_fixed_tpm |
        tpma_object_fixed_parent |
        tpma_object_sensitive_data_origin |
        tpma_object_user_with_auth |
        tpma_object_noda |
        crypto_attribute;

    var writer = Writer.init(command);
    if (!writer.putU32(rh_owner) or
        !writer.putU32(auth_value_len) or
        !writer.putU32(rs_pw) or
        !writer.putU16(0) or
        !writer.putU8(0) or
        !writer.putU16(0) or
        !writer.putU16(empty_sensitive_create_len) or
        !writer.putU16(0) or
        !writer.putU16(0) or
        !writer.putU16(create_primary_public_len) or
        !writer.putU16(alg_ecc) or
        !writer.putU16(alg_sha256) or
        !writer.putU32(object_attributes) or
        !writer.putU16(0) or
        !writer.putU16(alg_null) or
        !writer.putU16(scheme) or
        !writer.putU16(alg_sha256) or
        !writer.putU16(ecc_nist_p256) or
        !writer.putU16(alg_null) or
        !writer.putU16(0) or
        !writer.putU16(0) or
        !writer.putU16(0) or
        !writer.putU32(0)) return null;
    if (!writer.finish(create_primary_command_len)) return null;
    return command;
}

fn responseParameterWindow(response: []const u8, cursor: *usize) ?usize {
    if (response.len < header_len) return null;
    var parameter_end = response.len;
    if (getBe16(response[0..2]) == st_sessions) {
        if (response.len - cursor.* < 4) return null;
        const parameter_size = getBe32(response[cursor.*..][0..4]);
        cursor.* += 4;
        if (parameter_size > response.len - cursor.*) return null;
        parameter_end = cursor.* + parameter_size;
    }
    return parameter_end;
}

fn readTpm2b(value: []const u8, limit: usize, cursor: *usize) ?[]const u8 {
    if (cursor.* > limit or limit - cursor.* < 2) return null;
    const len = getBe16(value[cursor.*..][0..2]);
    cursor.* += 2;
    if (limit - cursor.* < len) return null;
    const out = value[cursor.*..][0..len];
    cursor.* += len;
    return out;
}

fn parseP256PointWire(point: []const u8) ?[p256_public_key_len]u8 {
    var cursor: usize = 0;
    const x = readTpm2b(point, point.len, &cursor) orelse return null;
    const y = readTpm2b(point, point.len, &cursor) orelse return null;
    if (cursor != point.len or x.len == 0 or y.len == 0 or x.len > p256_point_bytes or y.len > p256_point_bytes) return null;
    var out = [_]u8{0} ** p256_public_key_len;
    @memcpy(out[p256_point_bytes - x.len .. p256_point_bytes], x);
    @memcpy(out[p256_public_key_len - y.len .. p256_public_key_len], y);
    return out;
}

fn parseP256PublicArea(public_area: []const u8) ?[p256_public_key_len]u8 {
    if (public_area.len < 24 or getBe16(public_area[0..2]) != alg_ecc or getBe16(public_area[2..4]) != alg_sha256) return null;
    const auth_policy_len = getBe16(public_area[public_auth_policy_offset..][0..2]);
    if (public_area.len < tpmt_public_fixed_len + auth_policy_len + ecc_params_len + 4) return null;
    var cursor: usize = tpmt_public_fixed_len + auth_policy_len;
    if (getBe16(public_area[cursor..][0..2]) != alg_null or
        getBe16(public_area[cursor + 2 ..][0..2]) != alg_ecdsa or
        getBe16(public_area[cursor + 4 ..][0..2]) != alg_sha256 or
        getBe16(public_area[cursor + 6 ..][0..2]) != ecc_nist_p256 or
        getBe16(public_area[cursor + 8 ..][0..2]) != alg_null) return null;
    cursor += ecc_params_len;
    const x = readTpm2b(public_area, public_area.len, &cursor) orelse return null;
    const y = readTpm2b(public_area, public_area.len, &cursor) orelse return null;
    if (cursor != public_area.len or x.len == 0 or y.len == 0 or x.len > p256_point_bytes or y.len > p256_point_bytes) return null;
    var out = [_]u8{0} ** p256_public_key_len;
    @memcpy(out[p256_point_bytes - x.len .. p256_point_bytes], x);
    @memcpy(out[p256_public_key_len - y.len .. p256_public_key_len], y);
    return out;
}

fn putLoadExternalSensitive(writer: *Writer, sensitive_area_len: u16, sensitive_type: u16, key: []const u8, seed: [sha256_digest_len]u8) bool {
    return writer.putU16(sensitive_area_len) and
        writer.putU16(sensitive_type) and
        writer.putU16(0) and
        writer.putTpm2b(&seed) and
        writer.putTpm2b(key);
}

fn putLoadExternalPublicPrefix(writer: *Writer, public_area_len: u16, public_type: u16) bool {
    return writer.putU16(public_area_len) and
        writer.putU16(public_type) and
        writer.putU16(alg_sha256) and
        writer.putU32(0x0004_0040 | 0x0002_0000) and
        writer.putU16(0);
}

fn validHierarchy(hierarchy: u32) bool {
    return hierarchy == rh_owner or hierarchy == rh_endorsement or hierarchy == rh_platform or hierarchy == rh_null;
}

fn symmetricModeSupported(mode: u16) bool {
    return mode == alg_ctr or mode == alg_ofb or mode == alg_cbc or mode == alg_cfb or mode == alg_ecb;
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

fn getBe16(in: []const u8) u16 {
    return (@as(u16, in[0]) << 8) | @as(u16, in[1]);
}

fn getBe32(in: []const u8) u32 {
    return (@as(u32, in[0]) << 24) |
        (@as(u32, in[1]) << 16) |
        (@as(u32, in[2]) << 8) |
        @as(u32, in[3]);
}

test "builds startup and get random commands like C TPM library" {
    var raw: [32]u8 = undefined;
    const startup = buildStartup(su_clear, &raw).?;
    try std.testing.expectEqual(@as(usize, 12), startup.len);
    try std.testing.expectEqual(st_no_sessions, getBe16(startup[0..2]));
    try std.testing.expectEqual(@as(u32, 12), getBe32(startup[2..6]));
    try std.testing.expectEqual(cc_startup, getBe32(startup[6..10]));
    try std.testing.expectEqual(su_clear, getBe16(startup[10..12]));

    const random = buildGetRandom(32, &raw).?;
    try std.testing.expectEqual(@as(usize, 12), random.len);
    try std.testing.expectEqual(cc_get_random, getBe32(random[6..10]));
    try std.testing.expectEqual(@as(u16, 32), getBe16(random[10..12]));
    try std.testing.expect(buildGetRandom(0, &raw) == null);
}

test "builds create primary and read public commands" {
    var raw: [96]u8 = undefined;
    const signing = buildCreatePrimaryP256Signing(&raw).?;
    try std.testing.expectEqual(@as(usize, create_primary_command_len), signing.len);
    try std.testing.expectEqual(st_sessions, getBe16(signing[0..2]));
    try std.testing.expectEqual(cc_create_primary, getBe32(signing[6..10]));
    try std.testing.expectEqual(rh_owner, getBe32(signing[10..14]));
    try std.testing.expectEqual(alg_ecdsa, getBe16(signing[47..49]));

    const ecdh = buildCreatePrimaryP256Ecdh(&raw).?;
    try std.testing.expectEqual(alg_ecdh, getBe16(ecdh[47..49]));

    const read_public = buildReadPublic(0x8100_0001, &raw).?;
    try std.testing.expectEqual(@as(usize, read_public_command_len), read_public.len);
    try std.testing.expectEqual(@as(u32, 0x0000_0173), getBe32(read_public[6..10]));
    try std.testing.expectEqual(@as(u32, 0x8100_0001), getBe32(read_public[10..14]));
}

test "builds hash and session commands" {
    var raw: [128]u8 = undefined;
    const hash = buildHashSha256("abc", rh_null, &raw).?;
    try std.testing.expectEqual(@as(usize, hash_command_fixed_len + 3), hash.len);
    try std.testing.expectEqual(cc_hash, getBe32(hash[6..10]));
    try std.testing.expectEqual(@as(u16, 3), getBe16(hash[10..12]));
    try std.testing.expectEqual(@as(u8, 'a'), hash[12]);
    try std.testing.expectEqual(alg_sha256, getBe16(hash[15..17]));
    try std.testing.expectEqual(rh_null, getBe32(hash[17..21]));
    try std.testing.expect(buildHashSha256("", rh_null, &raw) == null);

    const hmac = buildHmacSha256(0x8100_0001, "abc", &raw).?;
    try std.testing.expectEqual(st_sessions, getBe16(hmac[0..2]));
    try std.testing.expectEqual(cc_hmac, getBe32(hmac[6..10]));
    try std.testing.expectEqual(@as(u32, 0x8100_0001), getBe32(hmac[10..14]));
}

test "builds capability sign verify and flush commands" {
    var raw: [160]u8 = undefined;
    const cap = buildGetCapability(cap_algs, 0x100, 4, &raw).?;
    try std.testing.expectEqual(@as(usize, 22), cap.len);
    try std.testing.expectEqual(cc_get_capability, getBe32(cap[6..10]));
    try std.testing.expectEqual(cap_algs, getBe32(cap[10..14]));
    try std.testing.expectEqual(@as(u32, 4), getBe32(cap[18..22]));

    const digest = [_]u8{1} ++ [_]u8{0} ** 31;
    const sign = buildSignP256Sha256(0x8100_0002, digest, &raw).?;
    try std.testing.expectEqual(@as(usize, sign_command_len), sign.len);
    try std.testing.expectEqual(cc_sign, getBe32(sign[6..10]));

    const signature = [_]u8{2} ** 64;
    const verify = buildVerifyP256Sha256(0x8100_0003, digest, signature, &raw).?;
    try std.testing.expectEqual(@as(usize, verify_p256_sha256_command_len), verify.len);
    try std.testing.expectEqual(cc_verify_signature, getBe32(verify[6..10]));

    const flush = buildFlushContext(0x8100_0004, &raw).?;
    try std.testing.expectEqual(@as(usize, flush_context_command_len), flush.len);
    try std.testing.expectEqual(cc_flush_context, getBe32(flush[6..10]));
}

test "builds load external aes hmac record crypt and ecdh commands" {
    var raw: [256]u8 = undefined;
    const seed = [_]u8{1} ** sha256_digest_len;
    const unique = [_]u8{2} ** sha256_digest_len;

    const hmac_key = [_]u8{3} ** 16;
    const hmac = buildLoadExternalHmacSha256Key(&hmac_key, seed, unique, &raw).?;
    try std.testing.expectEqual(cc_load_external, getBe32(hmac[6..10]));
    try std.testing.expectEqual(@as(usize, load_external_keyedhash_fixed_len + hmac_key.len), hmac.len);
    try std.testing.expectEqual(alg_keyedhash, getBe16(hmac[12..14]));

    const aes_key = [_]u8{4} ** aes_256_key_len;
    const aes = buildLoadExternalAesKey(&aes_key, aes_256_key_bits, alg_cfb, seed, unique, &raw).?;
    try std.testing.expectEqual(cc_load_external, getBe32(aes[6..10]));
    try std.testing.expectEqual(@as(usize, load_external_symcipher_fixed_len + aes_key.len), aes.len);
    try std.testing.expect(buildLoadExternalAesKey(&aes_key, aes_128_key_bits, alg_cfb, seed, unique, &raw) == null);
    try std.testing.expect(buildLoadExternalAesKey(&aes_key, aes_256_key_bits, alg_null, seed, unique, &raw) == null);

    const crypt = buildEncryptDecrypt2(0x8100_0001, true, alg_cfb, "iviv", "block", &raw).?;
    try std.testing.expectEqual(st_sessions, getBe16(crypt[0..2]));
    try std.testing.expectEqual(cc_encrypt_decrypt2, getBe32(crypt[6..10]));
    try std.testing.expectEqual(@as(u32, 0x8100_0001), getBe32(crypt[10..14]));

    const peer = [_]u8{5} ** p256_public_key_len;
    const ecdh = buildEcdhZgenP256(0x8100_0002, peer, &raw).?;
    try std.testing.expectEqual(@as(usize, ecdh_zgen_command_len), ecdh.len);
    try std.testing.expectEqual(cc_ecdh_zgen, getBe32(ecdh[6..10]));
    try std.testing.expectEqual(@as(u16, p256_point_body_len), getBe16(ecdh[27..29]));
}

test "parses basic TPM responses" {
    const random_response = [_]u8{
        0x80, 0x01, 0x00, 0x00, 0x00, 0x10, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x04, 0xaa, 0xbb, 0xcc, 0xdd,
    };
    var random: [8]u8 = undefined;
    const parsed = parseGetRandom(&random_response, &random).?;
    try std.testing.expectEqual(@as(usize, 4), parsed.len);
    try std.testing.expectEqual(@as(u8, 0xaa), parsed[0]);
    try std.testing.expectEqual(@as(u8, 0xdd), parsed[3]);

    const digest_response = [_]u8{
        0x80, 0x01, 0x00, 0x00, 0x00, 0x2c, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x20,
    } ++ ([_]u8{7} ** 32);
    const digest = parseSha256Digest(&digest_response).?;
    try std.testing.expectEqual(@as(u8, 7), digest[0]);
    try std.testing.expectEqual(@as(u8, 7), digest[31]);

    const handle_response = [_]u8{
        0x80, 0x01, 0x00, 0x00, 0x00, 0x0e, 0x00, 0x00, 0x00, 0x00,
        0x81, 0x00, 0x00, 0x01,
    };
    try std.testing.expectEqual(@as(u32, 0x8100_0001), parseHandle(&handle_response).?);

    const ticket_response = [_]u8{
        0x80, 0x01, 0x00, 0x00, 0x00, 0x14, 0x00, 0x00, 0x00, 0x00,
        0x80, 0x24, 0x40, 0x00, 0x00, 0x07, 0x00, 0x02, 0xaa, 0xbb,
    };
    try std.testing.expect(parseVerifyTicket(&ticket_response));
}

test "parses crypt point signature and profile responses" {
    const crypt_response = [_]u8{
        0x80, 0x02, 0x00, 0x00, 0x00, 0x1a, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x0c, 0x00, 0x04, 'd',  'a',  't',  'a',
        0x00, 0x04, 'i',  'v',  '0',  '1',
    };
    const crypt = parseEncryptDecrypt2(&crypt_response).?;
    try std.testing.expectEqualStrings("data", crypt.data);
    try std.testing.expectEqualStrings("iv01", crypt.iv);

    const point_response = [_]u8{
        0x80, 0x01, 0x00, 0x00, 0x00, 0x50, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x44, 0x00, 0x20,
    } ++ ([_]u8{0x11} ** 32) ++ [_]u8{ 0x00, 0x20 } ++ ([_]u8{0x22} ** 32);
    const point = parseP256Point(&point_response).?;
    try std.testing.expectEqual(@as(u8, 0x11), point[0]);
    try std.testing.expectEqual(@as(u8, 0x22), point[32]);

    const signature_response = [_]u8{
        0x80, 0x01, 0x00, 0x00, 0x00, 0x51, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x18, 0x00, 0x0b, 0x00, 0x1f,
    } ++ ([_]u8{0x33} ** 31) ++ [_]u8{ 0x00, 0x20 } ++ ([_]u8{0x44} ** 32);
    const signature = parseP256Sha256Signature(&signature_response).?;
    try std.testing.expectEqual(@as(u8, 0), signature[0]);
    try std.testing.expectEqual(@as(u8, 0x33), signature[1]);
    try std.testing.expectEqual(@as(u8, 0x44), signature[32]);

    const alg_response = [_]u8{
        0x80, 0x01, 0x00, 0x00, 0x00, 0x1f, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x02, 0x00,
        0x0b, 0x00, 0x00, 0x00, 0x00, 0x00, 0x43, 0x00, 0x00, 0x00,
        0x00,
    };
    const algs = parseAlgorithmProfile(&alg_response).?;
    try std.testing.expect(algs.has_sha256);
    try std.testing.expect(algs.has_cfb);

    const command_response = [_]u8{
        0x80, 0x01, 0x00, 0x00, 0x00, 0x1b, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x02, 0x00,
        0x00, 0x01, 0x7b, 0x00, 0x00, 0x01, 0x93,
    };
    const commands = parseCommandProfile(&command_response).?;
    try std.testing.expect(commands.has_get_random);
    try std.testing.expect(commands.has_encrypt_decrypt2);
}

test "parses nv limits create primary and tls profile helpers" {
    const limits_response = [_]u8{
        0x80, 0x01, 0x00, 0x00, 0x00, 0x23, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00, 0x02, 0x00,
        0x00, 0x01, 0x17, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00, 0x01,
        0x2c, 0x00, 0x00, 0x04, 0x00,
    };
    const limits = parseNvStorageLimits(&limits_response).?;
    try std.testing.expectEqual(@as(u32, 2048), limits.nv_index_max);
    try std.testing.expectEqual(@as(u32, 1024), limits.nv_buffer_max);

    const public_area = [_]u8{
        0x00, 0x23, 0x00, 0x0b,
        0x00, 0x00, 0x00, 0x40,
        0x00, 0x00, 0x00, 0x10,
        0x00, 0x18, 0x00, 0x0b,
        0x00, 0x03, 0x00, 0x10,
        0x00, 0x20,
    } ++ ([_]u8{0x55} ** 32) ++ [_]u8{ 0x00, 0x20 } ++ ([_]u8{0x66} ** 32);
    const primary_response = [_]u8{
        0x80, 0x01, 0x00, 0x00, 0x00, 0x68, 0x00, 0x00, 0x00, 0x00,
        0x81, 0x00, 0x00, 0x01, 0x00, 0x58,
    } ++ public_area;
    const primary = parseCreatePrimaryP256(&primary_response).?;
    try std.testing.expectEqual(@as(u32, 0x8100_0001), primary.handle);
    try std.testing.expectEqual(@as(u8, 0x55), primary.public_key[0]);
    try std.testing.expectEqual(@as(u8, 0x66), primary.public_key[32]);

    const algs = AlgorithmProfile{
        .has_sha256 = true,
        .has_hmac = true,
        .has_keyedhash = true,
        .has_ecc = true,
        .has_ecdh = true,
        .has_ecdsa = true,
        .has_aes = true,
        .has_symcipher = true,
        .has_cfb = true,
    };
    try std.testing.expectEqual(alg_cfb, selectRecordCipherMode(algs).?);
    const commands = CommandProfile{
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
    };
    try std.testing.expect(tlsProfileSupported(.{ .found = true, .start_method = 6 }, algs, commands));
    try std.testing.expect(!tlsProfileSupported(.{ .found = true, .start_method = 1 }, algs, commands));
}
