const std = @import("std");
const tpm = @import("../tpm.zig");
const tls_tpm = @import("../tls_tpm.zig");

pub const digest_len = tpm.sha256_digest_len;
pub const p256_public_key_len = tpm.p256_public_key_len;

pub const Error = error{
    BadArgument,
    FlushFailed,
    HashFailed,
    LoadKeyFailed,
    VerifyFailed,
};

pub const Signature = struct {
    public_key: [p256_public_key_len]u8,
    bytes: [p256_public_key_len]u8,
};

pub fn Verifier(comptime Executor: type) type {
    return struct {
        executor: *Executor,

        pub fn init(executor: *Executor) @This() {
            return .{ .executor = executor };
        }

        pub fn hash(self: @This(), canonical_bytes: []const u8) Error![digest_len]u8 {
            if (canonical_bytes.len == 0) return error.BadArgument;
            return self.executor.sha256(canonical_bytes) orelse error.HashFailed;
        }

        pub fn verifySignedBytes(self: @This(), canonical_bytes: []const u8, signature: Signature) Error![digest_len]u8 {
            const digest = try self.hash(canonical_bytes);
            try self.verifyDigest(digest, signature);
            return digest;
        }

        pub fn verifyDigest(self: @This(), digest: [digest_len]u8, signature: Signature) Error!void {
            const handle = self.executor.loadP256VerifyKey(signature.public_key) orelse return error.LoadKeyFailed;
            const verified = self.executor.verifyP256Sha256(handle, digest, signature.bytes);
            const flushed = self.executor.flush(handle);
            if (!flushed) return error.FlushFailed;
            if (!verified) return error.VerifyFailed;
        }
    };
}

pub const TpmExecutor = struct {
    context: *tls_tpm.Context,

    pub fn init(context: *tls_tpm.Context) TpmExecutor {
        return .{ .context = context };
    }

    pub fn sha256(self: *TpmExecutor, canonical_bytes: []const u8) ?[digest_len]u8 {
        return self.context.sha256(canonical_bytes);
    }

    pub fn loadP256VerifyKey(self: *TpmExecutor, public_key: [p256_public_key_len]u8) ?u32 {
        return self.context.loadP256VerifyKey(public_key);
    }

    pub fn verifyP256Sha256(self: *TpmExecutor, handle: u32, digest: [digest_len]u8, signature: [p256_public_key_len]u8) bool {
        return self.context.verifyP256Sha256(handle, digest, signature);
    }

    pub fn flush(self: *TpmExecutor, handle: u32) bool {
        return self.context.flush(handle);
    }
};

pub const SoftwareExecutor = struct {
    loaded_key: [p256_public_key_len]u8 = [_]u8{0} ** p256_public_key_len,
    loaded: bool = false,

    const handle: u32 = 1;
    const EcdsaP256Sha256 = std.crypto.sign.ecdsa.EcdsaP256Sha256;

    pub fn init() SoftwareExecutor {
        return .{};
    }

    pub fn sha256(self: *SoftwareExecutor, canonical_bytes: []const u8) ?[digest_len]u8 {
        _ = self;
        if (canonical_bytes.len == 0) return null;
        var out: [digest_len]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(canonical_bytes, &out, .{});
        return out;
    }

    pub fn loadP256VerifyKey(self: *SoftwareExecutor, public_key: [p256_public_key_len]u8) ?u32 {
        if (!nonzero(&public_key) or self.loaded) return null;
        self.loaded_key = public_key;
        self.loaded = true;
        return handle;
    }

    pub fn verifyP256Sha256(self: *SoftwareExecutor, loaded_handle: u32, digest: [digest_len]u8, signature: [p256_public_key_len]u8) bool {
        if (!self.loaded or loaded_handle != handle) return false;
        var public_key_sec1: [EcdsaP256Sha256.PublicKey.uncompressed_sec1_encoded_length]u8 = undefined;
        public_key_sec1[0] = 0x04;
        @memcpy(public_key_sec1[1..], &self.loaded_key);

        const public_key = EcdsaP256Sha256.PublicKey.fromSec1(&public_key_sec1) catch return false;
        const sig = EcdsaP256Sha256.Signature.fromBytes(signature);
        sig.verifyPrehashed(digest, public_key) catch return false;
        return true;
    }

    pub fn flush(self: *SoftwareExecutor, loaded_handle: u32) bool {
        if (!self.loaded or loaded_handle != handle) return false;
        self.loaded_key = [_]u8{0} ** p256_public_key_len;
        self.loaded = false;
        return true;
    }
};

const test_digest = [_]u8{0x42} ** digest_len;
const test_key = [_]u8{0x11} ** p256_public_key_len;
const test_signature = [_]u8{0x22} ** p256_public_key_len;
const test_handle: u32 = 0x8100_0001;

const RecordingExecutor = struct {
    expected_data: []const u8,
    state: State = .ready,
    hash_ok: bool = true,
    load_ok: bool = true,
    verify_ok: bool = true,
    flush_ok: bool = true,

    const State = enum {
        ready,
        hashed,
        loaded,
        verified,
        flushed,
    };

    fn sha256(self: *RecordingExecutor, canonical_bytes: []const u8) ?[digest_len]u8 {
        if (self.state != .ready) return null;
        if (!self.hash_ok) return null;
        if (!sameBytes(canonical_bytes, self.expected_data)) return null;
        self.state = .hashed;
        return test_digest;
    }

    fn loadP256VerifyKey(self: *RecordingExecutor, public_key: [p256_public_key_len]u8) ?u32 {
        if (self.state != .hashed) return null;
        if (!self.load_ok) return null;
        if (!sameBytes(&public_key, &test_key)) return null;
        self.state = .loaded;
        return test_handle;
    }

    fn verifyP256Sha256(self: *RecordingExecutor, handle: u32, digest: [digest_len]u8, signature: [p256_public_key_len]u8) bool {
        if (self.state != .loaded) return false;
        if (handle != test_handle) return false;
        if (!sameBytes(&digest, &test_digest)) return false;
        if (!sameBytes(&signature, &test_signature)) return false;
        self.state = .verified;
        return self.verify_ok;
    }

    fn flush(self: *RecordingExecutor, handle: u32) bool {
        if (self.state != .verified) return false;
        if (handle != test_handle) return false;
        self.state = .flushed;
        return self.flush_ok;
    }
};

fn sameBytes(left: []const u8, right: []const u8) bool {
    if (left.len != right.len) return false;
    for (left, right) |left_byte, right_byte| {
        if (left_byte != right_byte) return false;
    }
    return true;
}

fn nonzero(value: []const u8) bool {
    for (value) |byte| {
        if (byte != 0) return true;
    }
    return false;
}

fn testSignature() Signature {
    return .{
        .public_key = test_key,
        .bytes = test_signature,
    };
}

test "tpm verifier hashes canonical bytes and verifies p256 signature" {
    const testing = @import("std").testing;
    var executor = RecordingExecutor{ .expected_data = "canonical-transition" };
    const verifier = Verifier(RecordingExecutor).init(&executor);

    const digest = try verifier.verifySignedBytes("canonical-transition", testSignature());

    try testing.expectEqual(test_digest, digest);
    try testing.expectEqual(RecordingExecutor.State.flushed, executor.state);
}

test "tpm verifier rejects empty canonical bytes" {
    const testing = @import("std").testing;
    var executor = RecordingExecutor{ .expected_data = "" };
    const verifier = Verifier(RecordingExecutor).init(&executor);

    try testing.expectError(error.BadArgument, verifier.verifySignedBytes("", testSignature()));
    try testing.expectEqual(RecordingExecutor.State.ready, executor.state);
}

test "tpm verifier flushes loaded handles after failed verification" {
    const testing = @import("std").testing;
    var executor = RecordingExecutor{
        .expected_data = "canonical-transition",
        .verify_ok = false,
    };
    const verifier = Verifier(RecordingExecutor).init(&executor);

    try testing.expectError(error.VerifyFailed, verifier.verifySignedBytes("canonical-transition", testSignature()));
    try testing.expectEqual(RecordingExecutor.State.flushed, executor.state);
}

test "tpm verifier treats flush failure as fatal" {
    const testing = @import("std").testing;
    var executor = RecordingExecutor{
        .expected_data = "canonical-transition",
        .flush_ok = false,
    };
    const verifier = Verifier(RecordingExecutor).init(&executor);

    try testing.expectError(error.FlushFailed, verifier.verifySignedBytes("canonical-transition", testSignature()));
    try testing.expectEqual(RecordingExecutor.State.flushed, executor.state);
}

test "software verifier hashes and verifies p256 signatures without tpm" {
    const testing = @import("std").testing;
    const EcdsaP256Sha256 = SoftwareExecutor.EcdsaP256Sha256;
    const secret_key = try EcdsaP256Sha256.SecretKey.fromBytes([_]u8{1} ** EcdsaP256Sha256.SecretKey.encoded_length);
    const key_pair = try EcdsaP256Sha256.KeyPair.fromSecretKey(secret_key);
    const public_key_sec1 = key_pair.public_key.toUncompressedSec1();
    const signature_message = "pi software verifier canonical bytes";

    var digest: [digest_len]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(signature_message, &digest, .{});
    const software_signature = try key_pair.signPrehashed(digest, null);
    const signature_bytes = software_signature.toBytes();

    var public_key: [p256_public_key_len]u8 = undefined;
    @memcpy(&public_key, public_key_sec1[1..]);
    var executor = SoftwareExecutor.init();
    const verifier = Verifier(SoftwareExecutor).init(&executor);

    const verified_digest = try verifier.verifySignedBytes(signature_message, .{
        .public_key = public_key,
        .bytes = signature_bytes,
    });

    try testing.expectEqual(digest, verified_digest);
    try testing.expect(!executor.loaded);
}

test "software verifier rejects bad p256 signatures without installing fallback behavior" {
    const testing = @import("std").testing;
    const EcdsaP256Sha256 = SoftwareExecutor.EcdsaP256Sha256;
    const secret_key = try EcdsaP256Sha256.SecretKey.fromBytes([_]u8{2} ** EcdsaP256Sha256.SecretKey.encoded_length);
    const key_pair = try EcdsaP256Sha256.KeyPair.fromSecretKey(secret_key);
    const public_key_sec1 = key_pair.public_key.toUncompressedSec1();
    var public_key: [p256_public_key_len]u8 = undefined;
    @memcpy(&public_key, public_key_sec1[1..]);
    var executor = SoftwareExecutor.init();
    const verifier = Verifier(SoftwareExecutor).init(&executor);

    try testing.expectError(error.VerifyFailed, verifier.verifySignedBytes("message", .{
        .public_key = public_key,
        .bytes = [_]u8{0x5a} ** p256_public_key_len,
    }));
    try testing.expect(!executor.loaded);
}
