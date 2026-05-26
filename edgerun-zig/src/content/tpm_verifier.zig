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
