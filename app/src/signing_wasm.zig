const std = @import("std");

const Ed25519 = std.crypto.sign.Ed25519;
const Curve = std.crypto.ecc.Edwards25519;
const Sha512 = std.crypto.hash.sha2.Sha512;

const ERR_NULL: i32 = -1;
const ERR_VERIFY: i32 = -2;
const ERR_INVALID: i32 = -3;

const SEED_LEN = 32;
const PUBLIC_KEY_LEN = 32;
const SIGNATURE_LEN = 64;
const RH_BLIND_STRING = "Derive temporary signing key hash input";

export fn edgerun_signing_public_key(seed_ptr: ?*const [SEED_LEN]u8, out_ptr: ?*volatile [PUBLIC_KEY_LEN]u8) i32 {
    const seed = seed_ptr orelse return ERR_NULL;
    const out = out_ptr orelse return ERR_NULL;

    const key_pair = Ed25519.KeyPair.generateDeterministic(seed.*) catch return ERR_INVALID;
    out.* = key_pair.public_key.toBytes();
    return 0;
}

export fn edgerun_signing_sign(
    seed_ptr: ?*const [SEED_LEN]u8,
    msg_ptr: ?[*]const u8,
    msg_len: usize,
    out_ptr: ?*volatile [SIGNATURE_LEN]u8,
) i32 {
    const seed = seed_ptr orelse return ERR_NULL;
    const out = out_ptr orelse return ERR_NULL;
    if (msg_ptr == null and msg_len != 0) return ERR_NULL;

    const message = if (msg_ptr) |ptr| ptr[0..msg_len] else "";
    const key_pair = Ed25519.KeyPair.generateDeterministic(seed.*) catch return ERR_INVALID;
    const signature = key_pair.sign(message, null) catch return ERR_INVALID;
    out.* = signature.toBytes();
    return 0;
}

export fn edgerun_signing_verify(
    public_key_ptr: ?*const [PUBLIC_KEY_LEN]u8,
    msg_ptr: ?[*]const u8,
    msg_len: usize,
    signature_ptr: ?*const [SIGNATURE_LEN]u8,
) i32 {
    const public_key_bytes = public_key_ptr orelse return ERR_NULL;
    const signature_bytes = signature_ptr orelse return ERR_NULL;
    if (msg_ptr == null and msg_len != 0) return ERR_NULL;

    const message = if (msg_ptr) |ptr| ptr[0..msg_len] else "";
    const public_key = Ed25519.PublicKey.fromBytes(public_key_bytes.*) catch return ERR_INVALID;
    const signature = Ed25519.Signature.fromBytes(signature_bytes.*);
    signature.verify(message, public_key) catch return ERR_VERIFY;
    return 0;
}

export fn edgerun_signing_blind_public_key(
    public_key_ptr: ?*const [PUBLIC_KEY_LEN]u8,
    blinding_factor_ptr: ?*const [SEED_LEN]u8,
    out_ptr: ?*volatile [PUBLIC_KEY_LEN]u8,
) i32 {
    const public_key_bytes = public_key_ptr orelse return ERR_NULL;
    const blinding_factor = blinding_factor_ptr orelse return ERR_NULL;
    const out = out_ptr orelse return ERR_NULL;

    const point = Curve.fromBytes(public_key_bytes.*) catch return ERR_INVALID;
    const blind_scalar = clampedScalar(blinding_factor.*);
    const blinded = point.mul(blind_scalar) catch return ERR_INVALID;
    out.* = blinded.toBytes();
    return 0;
}

export fn edgerun_signing_blind_sign(
    seed_ptr: ?*const [SEED_LEN]u8,
    blinding_factor_ptr: ?*const [SEED_LEN]u8,
    msg_ptr: ?[*]const u8,
    msg_len: usize,
    out_sig_ptr: ?*volatile [SIGNATURE_LEN]u8,
    out_public_key_ptr: ?*volatile [PUBLIC_KEY_LEN]u8,
) i32 {
    const seed = seed_ptr orelse return ERR_NULL;
    const blinding_factor = blinding_factor_ptr orelse return ERR_NULL;
    const out_sig = out_sig_ptr orelse return ERR_NULL;
    if (msg_ptr == null and msg_len != 0) return ERR_NULL;

    const message = if (msg_ptr) |ptr| ptr[0..msg_len] else "";
    const result = blindSign(seed.*, blinding_factor.*, message) catch return ERR_INVALID;
    out_sig.* = result.signature;
    if (out_public_key_ptr) |out_public_key| {
        out_public_key.* = result.public_key;
    }
    return 0;
}

fn clampedScalar(bytes: [SEED_LEN]u8) [SEED_LEN]u8 {
    var scalar = bytes;
    Curve.scalar.clamp(&scalar);
    return Curve.scalar.reduce(scalar);
}

fn blindSign(seed: [SEED_LEN]u8, blinding_factor: [SEED_LEN]u8, message: []const u8) !struct {
    signature: [SIGNATURE_LEN]u8,
    public_key: [PUBLIC_KEY_LEN]u8,
} {
    var seed_hash: [Sha512.digest_length]u8 = undefined;
    Sha512.hash(&seed, &seed_hash, .{});

    const identity_scalar = clampedScalar(seed_hash[0..SEED_LEN].*);
    const blind_scalar = clampedScalar(blinding_factor);
    const blinded_scalar = Curve.scalar.mul(blind_scalar, identity_scalar);
    const blinded_public_key = (try Curve.basePoint.mul(blinded_scalar)).toBytes();

    var rh_digest = Sha512.init(.{});
    rh_digest.update(RH_BLIND_STRING);
    rh_digest.update(seed_hash[SEED_LEN..Sha512.digest_length]);
    var rh_hash: [Sha512.digest_length]u8 = undefined;
    rh_digest.final(&rh_hash);

    var nonce_digest = Sha512.init(.{});
    nonce_digest.update(rh_hash[0..SEED_LEN]);
    nonce_digest.update(message);
    var nonce_hash: [Sha512.digest_length]u8 = undefined;
    nonce_digest.final(&nonce_hash);
    const nonce = Curve.scalar.reduce64(nonce_hash);
    const r_bytes = (try Curve.basePoint.mul(nonce)).toBytes();

    var challenge_digest = Sha512.init(.{});
    challenge_digest.update(&r_bytes);
    challenge_digest.update(&blinded_public_key);
    challenge_digest.update(message);
    var challenge_hash: [Sha512.digest_length]u8 = undefined;
    challenge_digest.final(&challenge_hash);
    const challenge = Curve.scalar.reduce64(challenge_hash);
    const s = Curve.scalar.mulAdd(challenge, blinded_scalar, nonce);

    var signature: [SIGNATURE_LEN]u8 = undefined;
    signature[0..PUBLIC_KEY_LEN].* = r_bytes;
    signature[PUBLIC_KEY_LEN..SIGNATURE_LEN].* = s;
    return .{ .signature = signature, .public_key = blinded_public_key };
}

test "signing wasm public key and signature are deterministic" {
    const seed = try hex32("8052030376d47112be7f73ed7a019293dd12ad910b654455798b4667d73de166");
    const message = "test";

    var public_key: [PUBLIC_KEY_LEN]u8 = undefined;
    try std.testing.expectEqual(@as(i32, 0), edgerun_signing_public_key(&seed, &public_key));
    try std.testing.expectEqualSlices(u8, &try hex32("2d6f7455d97b4a3a10d7293909d1a4f2058cb9a370e43fa8154bb280db839083"), &public_key);

    var signature: [SIGNATURE_LEN]u8 = undefined;
    try std.testing.expectEqual(@as(i32, 0), edgerun_signing_sign(&seed, message.ptr, message.len, &signature));
    try std.testing.expectEqualSlices(u8, &try hex64("10a442b4a80cc4225b154f43bef28d2472ca80221951262eb8e0df9091575e2687cc486e77263c3418c757522d54f84b0359236abbbd4acd20dc297fdca66808"), &signature);
}

test "signing wasm verifies and rejects modified messages" {
    const seed = [_]u8{0x42} ** SEED_LEN;
    const message = "edgerun signing wasm";
    const modified = "edgerun signing wasp";

    var public_key: [PUBLIC_KEY_LEN]u8 = undefined;
    var signature: [SIGNATURE_LEN]u8 = undefined;
    try std.testing.expectEqual(@as(i32, 0), edgerun_signing_public_key(&seed, &public_key));
    try std.testing.expectEqual(@as(i32, 0), edgerun_signing_sign(&seed, message.ptr, message.len, &signature));
    try std.testing.expectEqual(@as(i32, 0), edgerun_signing_verify(&public_key, message.ptr, message.len, &signature));
    try std.testing.expectEqual(ERR_VERIFY, edgerun_signing_verify(&public_key, modified.ptr, modified.len, &signature));
}

test "signing wasm blinded signing is deterministic" {
    const seed = [_]u8{0x11} ** SEED_LEN;
    const blinding_factor = [_]u8{0x22} ** SEED_LEN;
    const message = "blind message";

    var public_key: [PUBLIC_KEY_LEN]u8 = undefined;
    var blinded_from_public: [PUBLIC_KEY_LEN]u8 = undefined;
    var signature: [SIGNATURE_LEN]u8 = undefined;
    var blinded_from_sign: [PUBLIC_KEY_LEN]u8 = undefined;

    try std.testing.expectEqual(@as(i32, 0), edgerun_signing_public_key(&seed, &public_key));
    try std.testing.expectEqual(@as(i32, 0), edgerun_signing_blind_public_key(&public_key, &blinding_factor, &blinded_from_public));
    try std.testing.expectEqual(@as(i32, 0), edgerun_signing_blind_sign(&seed, &blinding_factor, message.ptr, message.len, &signature, &blinded_from_sign));
    try std.testing.expectEqualSlices(u8, &blinded_from_public, &blinded_from_sign);
    try std.testing.expectEqual(@as(i32, 0), edgerun_signing_verify(&blinded_from_sign, message.ptr, message.len, &signature));
}

fn hex32(comptime text: []const u8) ![32]u8 {
    var out: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&out, text);
    return out;
}

fn hex64(comptime text: []const u8) ![64]u8 {
    var out: [64]u8 = undefined;
    _ = try std.fmt.hexToBytes(&out, text);
    return out;
}
