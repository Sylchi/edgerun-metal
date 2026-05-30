const std = @import("std");
const bytes = @import("bytes.zig");
const tpm = @import("tpm.zig");
const tls_tpm = @import("tls_tpm.zig");

pub const random_bytes = 32;
pub const p256_raw_public_bytes = tpm.p256_public_key_len;
pub const p256_sec1_public_bytes = p256_raw_public_bytes + 1;
pub const client_hello_max_bytes = 256;
pub const handshake_max_bytes = 512;
pub const sha256_bytes = tpm.sha256_digest_len;
pub const aes_128_key_bytes = tpm.aes_128_key_len;
pub const record_iv_bytes = tpm.aes_128_key_len;
pub const record_tag_bytes = tpm.sha256_digest_len;
pub const finished_verify_bytes = tpm.sha256_digest_len;
pub const record_plaintext_max_bytes = 1024;
pub const record_wire_max_bytes = record_header_bytes + record_plaintext_max_bytes + record_tag_bytes;

pub const Status = enum(u8) {
    ok = 0,
    invalid_argument = 1,
    buffer_too_small = 2,
    tpm_failure = 3,
    parse_failure = 4,
    unsupported = 5,
};

pub const Error = error{
    invalid_argument,
    buffer_too_small,
    tpm_failure,
    parse_failure,
    unsupported,
};

pub const Handshake = struct {
    client_random: [random_bytes]u8 = [_]u8{0} ** random_bytes,
    server_random: [random_bytes]u8 = [_]u8{0} ** random_bytes,
    client_public_key: [p256_raw_public_bytes]u8 = [_]u8{0} ** p256_raw_public_bytes,
    server_public_key: [p256_raw_public_bytes]u8 = [_]u8{0} ** p256_raw_public_bytes,
    shared_point: [p256_raw_public_bytes]u8 = [_]u8{0} ** p256_raw_public_bytes,
    ecdh_handle: u32 = 0,
    cipher_suite: u16 = 0,
    supported_version: u16 = 0,
    server_authenticated: bool = false,
    server_finished_verified: bool = false,
    client_finished_built: bool = false,
    ready: bool = false,
};

pub const RecordKeys = struct {
    client_aes_handle: u32 = 0,
    server_aes_handle: u32 = 0,
    client_hmac_handle: u32 = 0,
    server_hmac_handle: u32 = 0,
    client_iv: [record_iv_bytes]u8 = [_]u8{0} ** record_iv_bytes,
    server_iv: [record_iv_bytes]u8 = [_]u8{0} ** record_iv_bytes,
    client_sequence: u64 = 0,
    server_sequence: u64 = 0,
    ready: bool = false,
};

pub const ServerHello = struct {
    record_version: u16 = 0,
    random: [random_bytes]u8 = [_]u8{0} ** random_bytes,
    cipher_suite: u16 = 0,
    supported_version: u16 = 0,
    has_supported_version: bool = false,
    server_public_key: [p256_raw_public_bytes]u8 = [_]u8{0} ** p256_raw_public_bytes,
    has_server_public_key: bool = false,
};

const record_handshake: u8 = 22;
const record_application_data: u8 = 23;
const record_header_bytes = 5;
const record_version: u16 = 0x0303;
const handshake_client_hello: u8 = 1;
const handshake_server_hello: u8 = 2;
const handshake_certificate_verify: u8 = 15;
const handshake_finished: u8 = 20;
const tls_version_1_3: u16 = 0x0304;
const cipher_tls_aes_128_gcm_sha256: u16 = 0x1301;
const extension_server_name: u16 = 0x0000;
const extension_supported_groups: u16 = 0x000a;
const extension_signature_algorithms: u16 = 0x000d;
const extension_supported_versions: u16 = 0x002b;
const extension_key_share: u16 = 0x0033;
const named_group_secp256r1: u16 = 0x0017;
const signature_ecdsa_secp256r1_sha256: u16 = 0x0403;
const host_name_type: u8 = 0;
const null_compression_bytes: u8 = 2;
const u24_max: u32 = 0x00ff_ffff;
const sec1_uncompressed: u8 = 0x04;
const record_auth_prefix_bytes = 13;
const handshake_header_bytes = 4;
const record_sequence_bytes = 8;
const cert_verify_body_min_bytes = 4;
const cert_verify_prefix_space_bytes = 64;
const p256_signature_bytes = 64;
const finished_message_bytes = handshake_header_bytes + finished_verify_bytes;
const derive_label_client_key: u8 = 1;
const derive_label_server_key: u8 = 2;
const derive_label_client_iv: u8 = 3;
const derive_label_server_iv: u8 = 4;
const derive_label_client_mac: u8 = 5;
const derive_label_server_mac: u8 = 6;
const record_version_offset = 1;
const record_length_offset = 3;
const server_key_share_group_offset = 0;
const server_key_share_key_len_offset = 2;
const server_key_share_format_offset = 4;
const server_key_share_public_offset = 5;
const extension_header_bytes = 4;
const server_hello_version_bytes = 2;
const session_id_length_bytes = 1;
const cipher_suite_bytes = 2;
const compression_method_bytes = 1;
const extension_vector_len_bytes = 2;
const supported_versions_list_bytes = 2;
const supported_versions_extension_bytes = session_id_length_bytes + supported_versions_list_bytes;
const named_group_list_bytes = 2;
const supported_groups_extension_bytes = extension_vector_len_bytes + named_group_list_bytes;
const signature_algorithm_list_bytes = 2;
const signature_algorithms_extension_bytes = extension_vector_len_bytes + signature_algorithm_list_bytes;
const key_share_entry_header_bytes = named_group_list_bytes + extension_vector_len_bytes;
const key_share_extension_bytes = extension_vector_len_bytes + key_share_entry_header_bytes + p256_sec1_public_bytes;
const server_hello_min_tail_bytes = cipher_suite_bytes + compression_method_bytes + extension_vector_len_bytes;
const server_certificate_verify_context = "TLS 1.3, server CertificateVerify";

const Writer = struct {
    out: []u8,
    len: usize = 0,

    fn writeBytes(self: *Writer, value: []const u8) bool {
        if (value.len > self.out.len or self.len > self.out.len - value.len) return false;
        @memcpy(self.out[self.len..][0..value.len], value);
        self.len += value.len;
        return true;
    }

    fn writeU8(self: *Writer, value: u8) bool {
        return self.writeBytes((&value)[0..1]);
    }

    fn writeU16(self: *Writer, value: u16) bool {
        var raw: [2]u8 = undefined;
        _ = bytes.storeBe16(&raw, value);
        return self.writeBytes(&raw);
    }

    fn writeU24(self: *Writer, value: u32) bool {
        if (value > u24_max) return false;
        var raw = [_]u8{
            @truncate(value >> 16),
            @truncate(value >> 8),
            @truncate(value),
        };
        return self.writeBytes(&raw);
    }

    fn patchU16(self: Writer, offset: usize, value: u16) bool {
        if (offset > self.len or self.len - offset < 2) return false;
        return bytes.storeBe16(self.out[offset..][0..2], value);
    }

    fn patchU24(self: Writer, offset: usize, value: u32) bool {
        if (value > u24_max or offset > self.len or self.len - offset < 3) return false;
        self.out[offset] = @truncate(value >> 16);
        self.out[offset + 1] = @truncate(value >> 8);
        self.out[offset + 2] = @truncate(value);
        return true;
    }
};

pub fn buildClientHello(ctx: *tls_tpm.Context, handshake: *Handshake, host: []const u8, out: []u8) Error![]u8 {
    if (!hostValid(host) or out.len < client_hello_max_bytes) return error.invalid_argument;
    handshake.* = .{};

    if (!ctx.getRandom(&handshake.client_random)) return error.tpm_failure;
    const ecdh = ctx.createP256EcdhKey() orelse return error.tpm_failure;
    handshake.ecdh_handle = ecdh.handle;
    handshake.client_public_key = ecdh.public_key;

    var writer = Writer{ .out = out };
    if (!writer.writeU8(record_handshake) or !writer.writeU16(record_version)) return error.buffer_too_small;
    const record_len_offset = writer.len;
    if (!writer.writeU16(0) or !writer.writeU8(handshake_client_hello)) return error.buffer_too_small;
    const handshake_len_offset = writer.len;
    if (!writer.writeU24(0)) return error.buffer_too_small;
    const body_start = writer.len;
    if (!writer.writeU16(record_version) or
        !writer.writeBytes(&handshake.client_random) or
        !writer.writeU8(0) or
        !writer.writeU16(2) or
        !writer.writeU16(cipher_tls_aes_128_gcm_sha256) or
        !writer.writeU8(null_compression_bytes) or
        !writer.writeU8(0)) return error.buffer_too_small;

    const extension_len_offset = writer.len;
    if (!writer.writeU16(0)) return error.buffer_too_small;
    const extension_start = writer.len;
    if (!writeSupportedVersionsExtension(&writer) or
        !writeSupportedGroupsExtension(&writer) or
        !writeSignatureAlgorithmsExtension(&writer) or
        !writeKeyShareExtension(&writer, handshake.client_public_key) or
        !writeSniExtension(&writer, host) or
        !writer.patchU16(extension_len_offset, @intCast(writer.len - extension_start)) or
        !writer.patchU24(handshake_len_offset, @intCast(writer.len - body_start)) or
        !writer.patchU16(record_len_offset, @intCast(writer.len - record_header_bytes))) return error.buffer_too_small;

    return out[0..writer.len];
}

pub fn parseServerHello(raw: []const u8) Error!ServerHello {
    if (raw.len < record_header_bytes + handshake_header_bytes or
        raw[0] != record_handshake or
        readU16(raw[record_version_offset..]) != record_version) return error.parse_failure;

    const record_len = readU16(raw[record_length_offset..]);
    if (record_len > raw.len - record_header_bytes or raw[record_header_bytes] != handshake_server_hello) return error.parse_failure;

    const body_len = readU24(raw[record_header_bytes + 1 ..]);
    if (body_len > u24_max or body_len > record_len - handshake_header_bytes) return error.parse_failure;

    const body_start: usize = record_header_bytes + handshake_header_bytes;
    const body_end = body_start + body_len;
    if (body_end > raw.len or body_end - body_start < server_hello_version_bytes + random_bytes + session_id_length_bytes) return error.parse_failure;

    var out: ServerHello = .{};
    var pos = body_start;
    out.record_version = readU16(raw[pos..]);
    pos += server_hello_version_bytes;
    @memcpy(&out.random, raw[pos..][0..random_bytes]);
    pos += random_bytes;

    const session_len = raw[pos];
    pos += session_id_length_bytes;
    if (session_len > body_end - pos) return error.parse_failure;
    pos += session_len;
    if (body_end - pos < server_hello_min_tail_bytes) return error.parse_failure;

    out.cipher_suite = readU16(raw[pos..]);
    pos += cipher_suite_bytes;
    if (raw[pos] != 0) return error.unsupported;
    pos += compression_method_bytes;

    const extension_len = readU16(raw[pos..]);
    pos += extension_vector_len_bytes;
    if (extension_len > body_end - pos) return error.parse_failure;
    const extension_end = pos + extension_len;
    while (pos < extension_end) {
        if (extension_end - pos < extension_header_bytes) return error.parse_failure;
        const extension_type = readU16(raw[pos..]);
        const current_len = readU16(raw[pos + extension_vector_len_bytes ..]);
        pos += extension_header_bytes;
        if (current_len > extension_end - pos) return error.parse_failure;
        try parseServerHelloExtension(&out, extension_type, raw[pos..][0..current_len]);
        pos += current_len;
    }

    if (out.record_version != record_version or
        out.cipher_suite != cipher_tls_aes_128_gcm_sha256 or
        !out.has_supported_version or
        out.supported_version != tls_version_1_3 or
        !out.has_server_public_key) return error.unsupported;
    return out;
}

pub fn acceptServerHello(ctx: *tls_tpm.Context, handshake: *Handshake, raw: []const u8) Error!void {
    const server_hello = try parseServerHello(raw);
    handshake.shared_point = ctx.ecdhZgen(handshake.ecdh_handle, server_hello.server_public_key) orelse return error.tpm_failure;
    handshake.server_random = server_hello.random;
    handshake.server_public_key = server_hello.server_public_key;
    handshake.cipher_suite = server_hello.cipher_suite;
    handshake.supported_version = server_hello.supported_version;
    handshake.ready = true;
}

pub fn acceptCertificateVerify(ctx: *tls_tpm.Context, handshake: *Handshake, server_verify_key: [p256_raw_public_bytes]u8, transcript: []const u8, message: []const u8) Error!void {
    if (!handshake.ready or transcript.len == 0 or message.len < handshake_header_bytes + cert_verify_body_min_bytes) return error.invalid_argument;
    if (message[0] != handshake_certificate_verify) return error.parse_failure;
    const body_len = readU24(message[1..]);
    if (body_len != message.len - handshake_header_bytes or body_len < cert_verify_body_min_bytes) return error.parse_failure;
    const signature_scheme = readU16(message[handshake_header_bytes..]);
    const signature_len = readU16(message[handshake_header_bytes + 2 ..]);
    if (signature_scheme != signature_ecdsa_secp256r1_sha256 or
        signature_len != p256_signature_bytes or
        body_len != cert_verify_body_min_bytes + p256_signature_bytes) return error.unsupported;

    const transcript_hash = ctx.sha256(transcript) orelse return error.tpm_failure;
    var signed_content: [cert_verify_prefix_space_bytes + server_certificate_verify_context.len + 1 + sha256_bytes]u8 = undefined;
    @memset(signed_content[0..cert_verify_prefix_space_bytes], 0x20);
    @memcpy(signed_content[cert_verify_prefix_space_bytes..][0..server_certificate_verify_context.len], server_certificate_verify_context);
    signed_content[cert_verify_prefix_space_bytes + server_certificate_verify_context.len] = 0;
    @memcpy(signed_content[cert_verify_prefix_space_bytes + server_certificate_verify_context.len + 1 ..], &transcript_hash);
    const signed_hash = ctx.sha256(&signed_content) orelse return error.tpm_failure;
    const verify_handle = ctx.loadP256VerifyKey(server_verify_key) orelse return error.tpm_failure;
    const ok = ctx.verifyP256Sha256(verify_handle, signed_hash, toArray64(message[handshake_header_bytes + cert_verify_body_min_bytes ..][0..p256_signature_bytes]));
    if (!ctx.flush(verify_handle)) return error.tpm_failure;
    if (!ok) return error.tpm_failure;
    handshake.server_authenticated = true;
}

pub fn closeHandshake(ctx: *tls_tpm.Context, handshake: *Handshake) Error!void {
    const handle = handshake.ecdh_handle;
    handshake.* = .{};
    if (handle != 0 and !ctx.flush(handle)) return error.tpm_failure;
}

pub fn deriveRecordKeys(ctx: *tls_tpm.Context, handshake: Handshake, transcript: []const u8, out_keys: *RecordKeys) Error!void {
    if (!handshake.ready or !handshake.server_authenticated or transcript.len == 0) return error.invalid_argument;
    out_keys.* = .{};
    const transcript_hash = ctx.sha256(transcript) orelse return error.tpm_failure;
    const secret_handle = ctx.loadHmacSha256Key(handshake.shared_point[0..sha256_bytes]) orelse return error.tpm_failure;

    const client_key = deriveMaterial(ctx, secret_handle, derive_label_client_key, transcript_hash) orelse return error.tpm_failure;
    const server_key = deriveMaterial(ctx, secret_handle, derive_label_server_key, transcript_hash) orelse return error.tpm_failure;
    const client_iv = deriveMaterial(ctx, secret_handle, derive_label_client_iv, transcript_hash) orelse return error.tpm_failure;
    const server_iv = deriveMaterial(ctx, secret_handle, derive_label_server_iv, transcript_hash) orelse return error.tpm_failure;
    const client_mac = deriveMaterial(ctx, secret_handle, derive_label_client_mac, transcript_hash) orelse return error.tpm_failure;
    const server_mac = deriveMaterial(ctx, secret_handle, derive_label_server_mac, transcript_hash) orelse return error.tpm_failure;

    if (!ctx.flush(secret_handle)) return error.tpm_failure;
    out_keys.client_aes_handle = ctx.loadAesKey(client_key[0..aes_128_key_bytes], tpm.aes_128_key_bits) orelse return error.tpm_failure;
    out_keys.server_aes_handle = ctx.loadAesKey(server_key[0..aes_128_key_bytes], tpm.aes_128_key_bits) orelse return error.tpm_failure;
    out_keys.client_hmac_handle = ctx.loadHmacSha256Key(&client_mac) orelse return error.tpm_failure;
    out_keys.server_hmac_handle = ctx.loadHmacSha256Key(&server_mac) orelse return error.tpm_failure;
    @memcpy(&out_keys.client_iv, client_iv[0..record_iv_bytes]);
    @memcpy(&out_keys.server_iv, server_iv[0..record_iv_bytes]);
    out_keys.ready = true;
}

pub fn acceptServerFinished(ctx: *tls_tpm.Context, handshake: *Handshake, keys: RecordKeys, transcript: []const u8, message: []const u8) Error!void {
    if (!keys.ready or !handshake.ready or !handshake.server_authenticated or transcript.len == 0) return error.invalid_argument;
    if (message.len != finished_message_bytes or message[0] != handshake_finished or readU24(message[1..]) != finished_verify_bytes) return error.parse_failure;
    const expected = finishedData(ctx, keys.server_hmac_handle, transcript) orelse return error.tpm_failure;
    if (!constantTimeEql(&expected, message[handshake_header_bytes..][0..finished_verify_bytes])) return error.parse_failure;
    handshake.server_finished_verified = true;
}

pub fn buildClientFinished(ctx: *tls_tpm.Context, handshake: *Handshake, keys: RecordKeys, transcript: []const u8, out: []u8) Error![]u8 {
    if (!keys.ready or !handshake.server_finished_verified or transcript.len == 0) return error.invalid_argument;
    if (out.len < finished_message_bytes) return error.buffer_too_small;
    out[0] = handshake_finished;
    putU24(out[1..][0..3], finished_verify_bytes);
    const verify = finishedData(ctx, keys.client_hmac_handle, transcript) orelse return error.tpm_failure;
    @memcpy(out[handshake_header_bytes..][0..finished_verify_bytes], &verify);
    handshake.client_finished_built = true;
    return out[0..finished_message_bytes];
}

pub fn protectRecord(ctx: *tls_tpm.Context, keys: *RecordKeys, from_client: bool, plaintext: []const u8, out: []u8) Error![]u8 {
    if (!keys.ready or plaintext.len == 0 or plaintext.len > record_plaintext_max_bytes or out.len < record_header_bytes + plaintext.len + record_tag_bytes) return error.invalid_argument;
    const direction = recordDirection(keys, from_client);
    out[0] = record_application_data;
    _ = bytes.storeBe16(out[record_version_offset..][0..2], record_version);
    _ = bytes.storeBe16(out[record_length_offset..][0..2], @intCast(plaintext.len + record_tag_bytes));
    const crypt = ctx.recordCrypt(direction.aes_handle, false, direction.iv.*, plaintext) orelse return error.tpm_failure;
    if (crypt.data.len != plaintext.len or crypt.iv.len != record_iv_bytes) return error.tpm_failure;
    @memcpy(out[record_header_bytes..][0..plaintext.len], crypt.data);
    @memcpy(direction.iv.*, crypt.iv);
    const tag = recordMac(ctx, direction.hmac_handle, direction.sequence.*, out[0..record_header_bytes], out[record_header_bytes..][0..plaintext.len]) orelse return error.tpm_failure;
    @memcpy(out[record_header_bytes + plaintext.len ..][0..record_tag_bytes], &tag);
    advanceSequence(keys, from_client);
    return out[0 .. record_header_bytes + plaintext.len + record_tag_bytes];
}

pub fn unprotectRecord(ctx: *tls_tpm.Context, keys: *RecordKeys, from_client: bool, record: []const u8, out: []u8) Error![]u8 {
    if (!keys.ready or record.len < record_header_bytes + record_tag_bytes or
        record[0] != record_application_data or readU16(record[record_version_offset..]) != record_version) return error.invalid_argument;
    const encrypted_len = readU16(record[record_length_offset..]);
    if (encrypted_len != record.len - record_header_bytes or encrypted_len < record_tag_bytes) return error.parse_failure;
    const plaintext_len = encrypted_len - record_tag_bytes;
    if (plaintext_len > out.len or plaintext_len > record_plaintext_max_bytes) return error.buffer_too_small;
    const direction = recordDirection(keys, from_client);
    const expected_tag = recordMac(ctx, direction.hmac_handle, direction.sequence.*, record[0..record_header_bytes], record[record_header_bytes..][0..plaintext_len]) orelse return error.parse_failure;
    if (!constantTimeEql(&expected_tag, record[record_header_bytes + plaintext_len ..][0..record_tag_bytes])) return error.parse_failure;
    const crypt = ctx.recordCrypt(direction.aes_handle, true, direction.iv.*, record[record_header_bytes..][0..plaintext_len]) orelse return error.tpm_failure;
    if (crypt.data.len != plaintext_len or crypt.iv.len != record_iv_bytes) return error.tpm_failure;
    @memcpy(out[0..plaintext_len], crypt.data);
    @memcpy(direction.iv.*, crypt.iv);
    advanceSequence(keys, from_client);
    return out[0..plaintext_len];
}

pub fn closeRecordKeys(ctx: *tls_tpm.Context, keys: *RecordKeys) Error!void {
    var ok = true;
    if (keys.client_aes_handle != 0 and !ctx.flush(keys.client_aes_handle)) ok = false;
    if (keys.server_aes_handle != 0 and !ctx.flush(keys.server_aes_handle)) ok = false;
    if (keys.client_hmac_handle != 0 and !ctx.flush(keys.client_hmac_handle)) ok = false;
    if (keys.server_hmac_handle != 0 and !ctx.flush(keys.server_hmac_handle)) ok = false;
    keys.* = .{};
    if (!ok) return error.tpm_failure;
}

fn writeExtensionHeader(writer: *Writer, extension_type: u16, extension_len: u16) bool {
    return writer.writeU16(extension_type) and writer.writeU16(extension_len);
}

fn writeSniExtension(writer: *Writer, host: []const u8) bool {
    const extension_len: u16 = @intCast(2 + 1 + 2 + host.len);
    const list_len: u16 = @intCast(1 + 2 + host.len);
    return writeExtensionHeader(writer, extension_server_name, extension_len) and
        writer.writeU16(list_len) and
        writer.writeU8(host_name_type) and
        writer.writeU16(@intCast(host.len)) and
        writer.writeBytes(host);
}

fn writeSupportedVersionsExtension(writer: *Writer) bool {
    return writeExtensionHeader(writer, extension_supported_versions, supported_versions_extension_bytes) and
        writer.writeU8(supported_versions_list_bytes) and
        writer.writeU16(tls_version_1_3);
}

fn writeSupportedGroupsExtension(writer: *Writer) bool {
    return writeExtensionHeader(writer, extension_supported_groups, supported_groups_extension_bytes) and
        writer.writeU16(named_group_list_bytes) and
        writer.writeU16(named_group_secp256r1);
}

fn writeSignatureAlgorithmsExtension(writer: *Writer) bool {
    return writeExtensionHeader(writer, extension_signature_algorithms, signature_algorithms_extension_bytes) and
        writer.writeU16(signature_algorithm_list_bytes) and
        writer.writeU16(signature_ecdsa_secp256r1_sha256);
}

fn writeKeyShareExtension(writer: *Writer, raw_public: [p256_raw_public_bytes]u8) bool {
    return writeExtensionHeader(writer, extension_key_share, key_share_extension_bytes) and
        writer.writeU16(key_share_entry_header_bytes + p256_sec1_public_bytes) and
        writer.writeU16(named_group_secp256r1) and
        writer.writeU16(p256_sec1_public_bytes) and
        writer.writeU8(sec1_uncompressed) and
        writer.writeBytes(&raw_public);
}

fn parseServerHelloExtension(out: *ServerHello, extension_type: u16, data: []const u8) Error!void {
    switch (extension_type) {
        extension_supported_versions => {
            if (data.len != 2) return error.parse_failure;
            out.supported_version = readU16(data);
            out.has_supported_version = true;
        },
        extension_key_share => try parseServerKeyShare(out, data),
        else => {},
    }
}

fn parseServerKeyShare(out: *ServerHello, data: []const u8) Error!void {
    if (data.len != key_share_entry_header_bytes + p256_sec1_public_bytes or
        readU16(data[server_key_share_group_offset..]) != named_group_secp256r1) return error.parse_failure;
    const key_len = readU16(data[server_key_share_key_len_offset..]);
    if (key_len != p256_sec1_public_bytes or data[server_key_share_format_offset] != sec1_uncompressed) return error.parse_failure;
    @memcpy(&out.server_public_key, data[server_key_share_public_offset..][0..p256_raw_public_bytes]);
    out.has_server_public_key = true;
}

fn hostValid(host: []const u8) bool {
    if (host.len == 0 or host.len > 0xFFFF) return false;
    for (host) |c| {
        switch (c) {
            'a'...'z', 'A'...'Z', '0'...'9', '.', '-' => {},
            else => return false,
        }
    }
    return true;
}

fn deriveMaterial(ctx: *tls_tpm.Context, secret_handle: u32, label: u8, transcript_hash: [sha256_bytes]u8) ?[sha256_bytes]u8 {
    var input: [1 + sha256_bytes]u8 = undefined;
    input[0] = label;
    @memcpy(input[1..], &transcript_hash);
    return ctx.hmacSha256(secret_handle, &input);
}

fn finishedData(ctx: *tls_tpm.Context, hmac_handle: u32, transcript: []const u8) ?[finished_verify_bytes]u8 {
    const transcript_hash = ctx.sha256(transcript) orelse return null;
    return ctx.hmacSha256(hmac_handle, &transcript_hash);
}

fn recordMac(ctx: *tls_tpm.Context, hmac_handle: u32, sequence: u64, header: []const u8, data: []const u8) ?[record_tag_bytes]u8 {
    if (header.len != record_header_bytes or data.len > record_plaintext_max_bytes) return null;
    var mac_input: [record_auth_prefix_bytes + record_plaintext_max_bytes]u8 = undefined;
    writeSeq(mac_input[0..record_sequence_bytes], sequence);
    @memcpy(mac_input[record_sequence_bytes..][0..record_header_bytes], header);
    @memcpy(mac_input[record_auth_prefix_bytes..][0..data.len], data);
    return ctx.hmacSha256(hmac_handle, mac_input[0 .. record_auth_prefix_bytes + data.len]);
}

const RecordDirection = struct {
    aes_handle: u32,
    hmac_handle: u32,
    iv: *[record_iv_bytes]u8,
    sequence: *u64,
};

fn recordDirection(keys: *RecordKeys, from_client: bool) RecordDirection {
    if (from_client) {
        return .{ .aes_handle = keys.client_aes_handle, .hmac_handle = keys.client_hmac_handle, .iv = &keys.client_iv, .sequence = &keys.client_sequence };
    }
    return .{ .aes_handle = keys.server_aes_handle, .hmac_handle = keys.server_hmac_handle, .iv = &keys.server_iv, .sequence = &keys.server_sequence };
}

fn advanceSequence(keys: *RecordKeys, from_client: bool) void {
    if (from_client) {
        keys.client_sequence += 1;
    } else {
        keys.server_sequence += 1;
    }
}

fn constantTimeEql(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    var diff: u8 = 0;
    for (a, b) |left, right| diff |= left ^ right;
    return diff == 0;
}

fn readU16(raw: []const u8) u16 {
    return bytes.loadBe16(raw[0..2]).?;
}

fn readU24(raw: []const u8) u32 {
    return (@as(u32, raw[0]) << 16) | (@as(u32, raw[1]) << 8) | @as(u32, raw[2]);
}

fn putU24(out: []u8, value: u32) void {
    out[0] = @truncate(value >> 16);
    out[1] = @truncate(value >> 8);
    out[2] = @truncate(value);
}

fn writeSeq(out: []u8, value: u64) void {
    var i: usize = 0;
    while (i < record_sequence_bytes) : (i += 1) {
        const shift: u6 = @intCast((record_sequence_bytes - 1 - i) * 8);
        out[i] = @truncate(value >> shift);
    }
}

fn toArray64(raw: []const u8) [64]u8 {
    var out: [64]u8 = undefined;
    @memcpy(&out, raw[0..64]);
    return out;
}

test "server hello parser accepts TLS 1.3 P256 AES128 response" {
    var server_public: [p256_raw_public_bytes]u8 = undefined;
    for (&server_public, 0..) |*byte, index| byte.* = @intCast(index + 1);

    var raw: [record_header_bytes + handshake_header_bytes + 128]u8 = undefined;
    var writer = Writer{ .out = &raw };
    try std.testing.expect(writer.writeU8(record_handshake));
    try std.testing.expect(writer.writeU16(record_version));
    const record_len_offset = writer.len;
    try std.testing.expect(writer.writeU16(0));
    try std.testing.expect(writer.writeU8(handshake_server_hello));
    const handshake_len_offset = writer.len;
    try std.testing.expect(writer.writeU24(0));
    const body_start = writer.len;
    try std.testing.expect(writer.writeU16(record_version));
    var random: [random_bytes]u8 = undefined;
    for (&random, 0..) |*byte, index| byte.* = @intCast(0xa0 + index);
    try std.testing.expect(writer.writeBytes(&random));
    try std.testing.expect(writer.writeU8(0));
    try std.testing.expect(writer.writeU16(cipher_tls_aes_128_gcm_sha256));
    try std.testing.expect(writer.writeU8(0));
    const extension_len_offset = writer.len;
    try std.testing.expect(writer.writeU16(0));
    const extension_start = writer.len;
    try std.testing.expect(writeExtensionHeader(&writer, extension_supported_versions, 2));
    try std.testing.expect(writer.writeU16(tls_version_1_3));
    try std.testing.expect(writeExtensionHeader(&writer, extension_key_share, key_share_entry_header_bytes + p256_sec1_public_bytes));
    try std.testing.expect(writer.writeU16(named_group_secp256r1));
    try std.testing.expect(writer.writeU16(p256_sec1_public_bytes));
    try std.testing.expect(writer.writeU8(sec1_uncompressed));
    try std.testing.expect(writer.writeBytes(&server_public));
    try std.testing.expect(writer.patchU16(extension_len_offset, @intCast(writer.len - extension_start)));
    try std.testing.expect(writer.patchU24(handshake_len_offset, @intCast(writer.len - body_start)));
    try std.testing.expect(writer.patchU16(record_len_offset, @intCast(writer.len - record_header_bytes)));

    const parsed = try parseServerHello(raw[0..writer.len]);
    try std.testing.expectEqual(record_version, parsed.record_version);
    try std.testing.expectEqual(cipher_tls_aes_128_gcm_sha256, parsed.cipher_suite);
    try std.testing.expectEqual(tls_version_1_3, parsed.supported_version);
    try std.testing.expect(bytes.eql(&server_public, &parsed.server_public_key));
}

test "server hello parser rejects missing key share" {
    var raw = [_]u8{
        record_handshake,       0x03, 0x03, 0x00, 0x32,
        handshake_server_hello, 0x00, 0x00, 0x2e, 0x03,
        0x03,
    } ++ ([_]u8{0x11} ** random_bytes) ++ [_]u8{
        0x00,
        0x13,
        0x01,
        0x00,
        0x00,
        0x06,
        0x00,
        0x2b,
        0x00,
        0x02,
        0x03,
        0x04,
    };
    try std.testing.expectError(error.unsupported, parseServerHello(&raw));
}
