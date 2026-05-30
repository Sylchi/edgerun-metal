const bytes = @import("../bytes.zig");
const data_chunk = @import("data_chunk.zig");
const kernel = @import("kernel.zig");
const tpm_verifier = @import("tpm_verifier.zig");

pub const version: u8 = 1;

pub const Error = kernel.Error || data_chunk.Error || tpm_verifier.Error;

pub const ActionKind = enum(u8) {
    add_allocation = 1,
};

pub fn addVerifiedAllocation(
    comptime Executor: type,
    allocator: *kernel.Allocator,
    verifier: tpm_verifier.Verifier(Executor),
    allocation: kernel.Allocation,
    signed_action: tpm_verifier.Signature,
    scratch: []u8,
) Error![tpm_verifier.digest_len]u8 {
    const canonical = try encodeAddAllocation(allocation, scratch);
    const digest = try verifier.verifySignedBytes(canonical, signed_action);
    try allocator.addAllocation(allocation);
    return digest;
}

pub fn encodeAddAllocation(allocation: kernel.Allocation, out: []u8) Error![]u8 {
    if (!allocation.valid()) return error.BadArgument;
    var cursor: usize = 0;
    try putByte(out, &cursor, version);
    try putByte(out, &cursor, @intFromEnum(ActionKind.add_allocation));
    cursor += (try allocation.id.encode(out[cursor..])).len;
    cursor += (try allocation.owner.encode(out[cursor..])).len;
    try putU64(out, &cursor, allocation.capacity);
    return out[0..cursor];
}

fn putByte(out: []u8, cursor: *usize, value: u8) data_chunk.Error!void {
    if (out.len - cursor.* < 1) return error.NoSpace;
    out[cursor.*] = value;
    cursor.* += 1;
}

fn putU64(out: []u8, cursor: *usize, value: u64) data_chunk.Error!void {
    if (out.len - cursor.* < @sizeOf(u64)) return error.NoSpace;
    _ = bytes.store64(out[cursor.*..][0..@sizeOf(u64)], value);
    cursor.* += @sizeOf(u64);
}

const test_digest = [_]u8{0x33} ** tpm_verifier.digest_len;
const test_key = [_]u8{0x44} ** tpm_verifier.p256_public_key_len;
const test_signature = [_]u8{0x55} ** tpm_verifier.p256_public_key_len;
const test_handle: u32 = 0x8100_0002;

const RecordingExecutor = struct {
    expected_data: []const u8,
    state: State = .ready,
    verify_ok: bool = true,

    const State = enum {
        ready,
        hashed,
        loaded,
        verified,
        flushed,
    };

    pub fn sha256(self: *RecordingExecutor, canonical_bytes: []const u8) ?[tpm_verifier.digest_len]u8 {
        if (self.state != .ready) return null;
        if (!sameBytes(canonical_bytes, self.expected_data)) return null;
        self.state = .hashed;
        return test_digest;
    }

    pub fn loadP256VerifyKey(self: *RecordingExecutor, public_key: [tpm_verifier.p256_public_key_len]u8) ?u32 {
        if (self.state != .hashed) return null;
        if (!sameBytes(&public_key, &test_key)) return null;
        self.state = .loaded;
        return test_handle;
    }

    pub fn verifyP256Sha256(self: *RecordingExecutor, handle: u32, digest: [tpm_verifier.digest_len]u8, action_signature: [tpm_verifier.p256_public_key_len]u8) bool {
        if (self.state != .loaded) return false;
        if (handle != test_handle) return false;
        if (!sameBytes(&digest, &test_digest)) return false;
        if (!sameBytes(&action_signature, &test_signature)) return false;
        self.state = .verified;
        return self.verify_ok;
    }

    pub fn flush(self: *RecordingExecutor, handle: u32) bool {
        if (self.state != .verified) return false;
        if (handle != test_handle) return false;
        self.state = .flushed;
        return true;
    }
};

fn sameBytes(left: []const u8, right: []const u8) bool {
    if (left.len != right.len) return false;
    for (left, right) |left_byte, right_byte| {
        if (left_byte != right_byte) return false;
    }
    return true;
}

fn chunk(value: []const u8) data_chunk.DataChunk {
    return data_chunk.DataChunk.init(value);
}

fn testSignature() tpm_verifier.Signature {
    return .{
        .public_key = test_key,
        .bytes = test_signature,
    };
}

test "kernel authority verifies signed allocation before mutating allocator" {
    const testing = @import("std").testing;
    const allocation = kernel.Allocation.init(chunk("alloc-a"), chunk("root-user"), 128);
    var canonical: [64]u8 = undefined;
    const expected = try encodeAddAllocation(allocation, &canonical);
    var executor = RecordingExecutor{ .expected_data = expected };
    const verifier = tpm_verifier.Verifier(RecordingExecutor).init(&executor);
    var allocation_slots: [1]kernel.Allocation = undefined;
    var allocator = kernel.Allocator.init(&allocation_slots);
    var scratch: [64]u8 = undefined;

    const digest = try addVerifiedAllocation(RecordingExecutor, &allocator, verifier, allocation, testSignature(), &scratch);

    try testing.expectEqual(test_digest, digest);
    try testing.expectEqual(@as(usize, 1), allocator.len);
    try testing.expect(allocator.rangeValid(kernel.AddressRange.init(chunk("alloc-a"), 0, 128)));
    try testing.expectEqual(RecordingExecutor.State.flushed, executor.state);
}

test "kernel authority leaves allocator unchanged when signature verification fails" {
    const testing = @import("std").testing;
    const allocation = kernel.Allocation.init(chunk("alloc-a"), chunk("root-user"), 128);
    var canonical: [64]u8 = undefined;
    const expected = try encodeAddAllocation(allocation, &canonical);
    var executor = RecordingExecutor{
        .expected_data = expected,
        .verify_ok = false,
    };
    const verifier = tpm_verifier.Verifier(RecordingExecutor).init(&executor);
    var allocation_slots: [1]kernel.Allocation = undefined;
    var allocator = kernel.Allocator.init(&allocation_slots);
    var scratch: [64]u8 = undefined;

    try testing.expectError(error.VerifyFailed, addVerifiedAllocation(RecordingExecutor, &allocator, verifier, allocation, testSignature(), &scratch));
    try testing.expectEqual(@as(usize, 0), allocator.len);
    try testing.expectEqual(RecordingExecutor.State.flushed, executor.state);
}
