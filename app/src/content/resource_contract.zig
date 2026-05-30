const bytes = @import("../bytes.zig");
const data_chunk = @import("data_chunk.zig");
const tpm_verifier = @import("tpm_verifier.zig");

pub const version: u8 = 1;
pub const no_period: u64 = 0;

pub const Error = data_chunk.Error || tpm_verifier.Error || error{
    BadArgument,
    Conflict,
    Duplicate,
    NoSpace,
    NotFound,
    OutOfBounds,
};

pub const ResourceKind = enum(u8) {
    memory = 1,
    cpu = 2,
    gpu = 3,
    display = 4,
    input = 5,
    tpm = 6,
    network = 7,
    storage = 8,
};

pub const PatternKind = enum(u8) {
    exclusive = 1,
    periodic = 2,
};

pub const Bounds = struct {
    offset: u64,
    length: u64,

    pub fn init(offset: u64, length: u64) Bounds {
        return .{
            .offset = offset,
            .length = length,
        };
    }

    pub fn valid(self: Bounds) bool {
        return self.length != 0 and checkedEnd(self.offset, self.length) != null;
    }
};

pub const Pattern = struct {
    kind: PatternKind,
    active_ticks: u64,
    period_ticks: u64,

    pub fn exclusive() Pattern {
        return .{
            .kind = .exclusive,
            .active_ticks = 0,
            .period_ticks = no_period,
        };
    }

    pub fn periodic(active_ticks: u64, period_ticks: u64) Pattern {
        return .{
            .kind = .periodic,
            .active_ticks = active_ticks,
            .period_ticks = period_ticks,
        };
    }

    pub fn valid(self: Pattern) bool {
        return switch (self.kind) {
            .exclusive => self.active_ticks == 0 and self.period_ticks == no_period,
            .periodic => self.active_ticks != 0 and self.period_ticks != 0 and self.active_ticks <= self.period_ticks,
        };
    }

    pub fn ownsTick(self: Pattern, start_tick: u64, tick: u64) bool {
        return switch (self.kind) {
            .exclusive => true,
            .periodic => {
                if (!self.valid() or tick < start_tick) return false;
                const relative_tick = tick - start_tick;
                return relative_tick % self.period_ticks < self.active_ticks;
            },
        };
    }
};

pub const Contract = struct {
    id: data_chunk.DataChunk,
    app: data_chunk.DataChunk,
    resource: data_chunk.DataChunk,
    kind: ResourceKind,
    start_tick: u64,
    end_tick: u64,
    bounds: Bounds,
    pattern: Pattern,

    pub fn init(
        id: data_chunk.DataChunk,
        app: data_chunk.DataChunk,
        resource: data_chunk.DataChunk,
        kind: ResourceKind,
        start_tick: u64,
        end_tick: u64,
        bounds: Bounds,
        pattern: Pattern,
    ) Contract {
        return .{
            .id = id,
            .app = app,
            .resource = resource,
            .kind = kind,
            .start_tick = start_tick,
            .end_tick = end_tick,
            .bounds = bounds,
            .pattern = pattern,
        };
    }

    pub fn valid(self: Contract) bool {
        return nonempty(self.id) and
            nonempty(self.app) and
            nonempty(self.resource) and
            self.start_tick < self.end_tick and
            self.bounds.valid() and
            self.pattern.valid();
    }

    pub fn ownsTick(self: Contract, resource: data_chunk.DataChunk, tick: u64) bool {
        return self.valid() and
            sameChunk(self.resource, resource) and
            tick >= self.start_tick and
            tick < self.end_tick and
            self.pattern.ownsTick(self.start_tick, tick);
    }
};

pub const Schedule = struct {
    contracts: []Contract,
    len: usize = 0,

    pub fn init(contracts: []Contract) Schedule {
        return .{ .contracts = contracts };
    }

    pub fn install(self: *Schedule, contract: Contract) Error!void {
        if (!contract.valid()) return error.BadArgument;
        if (self.findContract(contract.id)) |_| return error.Duplicate;
        if (self.conflicts(contract)) return error.Conflict;
        if (self.len == self.contracts.len) return error.NoSpace;
        self.contracts[self.len] = contract;
        self.len += 1;
    }

    pub fn installChecked(self: *Schedule, inventory: anytype, contract: Contract) Error!void {
        try inventory.requireContractFits(contract);
        try self.install(contract);
    }

    pub fn installVerified(
        self: *Schedule,
        comptime Executor: type,
        verifier: tpm_verifier.Verifier(Executor),
        contract: Contract,
        signed_contract: tpm_verifier.Signature,
        scratch: []u8,
    ) Error![tpm_verifier.digest_len]u8 {
        const canonical = try encode(contract, scratch);
        const digest = try verifier.verifySignedBytes(canonical, signed_contract);
        try self.install(contract);
        return digest;
    }

    pub fn installVerifiedChecked(
        self: *Schedule,
        inventory: anytype,
        comptime Executor: type,
        verifier: tpm_verifier.Verifier(Executor),
        contract: Contract,
        signed_contract: tpm_verifier.Signature,
        scratch: []u8,
    ) Error![tpm_verifier.digest_len]u8 {
        try inventory.requireContractFits(contract);
        return self.installVerified(Executor, verifier, contract, signed_contract, scratch);
    }

    pub fn ownerAt(self: Schedule, resource: data_chunk.DataChunk, tick: u64) ?data_chunk.DataChunk {
        for (self.contracts[0..self.len]) |contract| {
            if (contract.ownsTick(resource, tick)) return contract.app;
        }
        return null;
    }

    fn findContract(self: Schedule, contract_id: data_chunk.DataChunk) ?Contract {
        for (self.contracts[0..self.len]) |contract| {
            if (sameChunk(contract.id, contract_id)) return contract;
        }
        return null;
    }

    fn conflicts(self: Schedule, contract: Contract) bool {
        for (self.contracts[0..self.len]) |existing| {
            if (contractsConflict(existing, contract)) return true;
        }
        return false;
    }
};

pub fn encode(contract: Contract, out: []u8) Error![]u8 {
    if (!contract.valid()) return error.BadArgument;
    var cursor: usize = 0;
    try putByte(out, &cursor, version);
    cursor += (try contract.id.encode(out[cursor..])).len;
    cursor += (try contract.app.encode(out[cursor..])).len;
    cursor += (try contract.resource.encode(out[cursor..])).len;
    try putByte(out, &cursor, @intFromEnum(contract.kind));
    try putU64(out, &cursor, contract.start_tick);
    try putU64(out, &cursor, contract.end_tick);
    try putU64(out, &cursor, contract.bounds.offset);
    try putU64(out, &cursor, contract.bounds.length);
    try putByte(out, &cursor, @intFromEnum(contract.pattern.kind));
    try putU64(out, &cursor, contract.pattern.active_ticks);
    try putU64(out, &cursor, contract.pattern.period_ticks);
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

fn checkedEnd(offset: u64, length: u64) ?u64 {
    return @import("std").math.add(u64, offset, length) catch null;
}

fn contractsConflict(left: Contract, right: Contract) bool {
    if (!left.valid() or !right.valid()) return true;
    if (!sameChunk(left.resource, right.resource)) return false;
    if (left.kind != right.kind) return false;
    return rangesOverlap(left.start_tick, left.end_tick, right.start_tick, right.end_tick) and
        boundsOverlap(left.bounds, right.bounds);
}

fn rangesOverlap(left_start: u64, left_end: u64, right_start: u64, right_end: u64) bool {
    return left_start < right_end and right_start < left_end;
}

fn boundsOverlap(left: Bounds, right: Bounds) bool {
    const left_end = checkedEnd(left.offset, left.length) orelse return true;
    const right_end = checkedEnd(right.offset, right.length) orelse return true;
    return left.offset < right_end and right.offset < left_end;
}

fn nonempty(value: data_chunk.DataChunk) bool {
    return value.valid() and value.length != 0;
}

fn sameChunk(left: data_chunk.DataChunk, right: data_chunk.DataChunk) bool {
    return left.valid() and right.valid() and bytes.eql(left.body(), right.body());
}

fn chunk(value: []const u8) data_chunk.DataChunk {
    return data_chunk.DataChunk.init(value);
}

const test_digest = [_]u8{0x66} ** tpm_verifier.digest_len;
const test_key = [_]u8{0x77} ** tpm_verifier.p256_public_key_len;
const test_signature = [_]u8{0x88} ** tpm_verifier.p256_public_key_len;
const test_handle: u32 = 0x8100_0003;

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
        if (!bytes.eql(canonical_bytes, self.expected_data)) return null;
        self.state = .hashed;
        return test_digest;
    }

    pub fn loadP256VerifyKey(self: *RecordingExecutor, public_key: [tpm_verifier.p256_public_key_len]u8) ?u32 {
        if (self.state != .hashed) return null;
        if (!bytes.eql(&public_key, &test_key)) return null;
        self.state = .loaded;
        return test_handle;
    }

    pub fn verifyP256Sha256(self: *RecordingExecutor, handle: u32, digest: [tpm_verifier.digest_len]u8, signature: [tpm_verifier.p256_public_key_len]u8) bool {
        if (self.state != .loaded) return false;
        if (handle != test_handle) return false;
        if (!bytes.eql(&digest, &test_digest)) return false;
        if (!bytes.eql(&signature, &test_signature)) return false;
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

fn testSignature() tpm_verifier.Signature {
    return .{
        .public_key = test_key,
        .bytes = test_signature,
    };
}

test "resource contract installs once and answers exclusive ownership by tick" {
    const testing = @import("std").testing;
    var slots: [1]Contract = undefined;
    var schedule = Schedule.init(&slots);
    const contract = Contract.init(chunk("contract-a"), chunk("app-a"), chunk("mem-bank-a"), .memory, 10, 20, Bounds.init(0, 4096), Pattern.exclusive());

    try schedule.install(contract);

    try testing.expect(schedule.ownerAt(chunk("mem-bank-a"), 9) == null);
    try testing.expectEqualStrings("app-a", schedule.ownerAt(chunk("mem-bank-a"), 10).?.body());
    try testing.expectEqualStrings("app-a", schedule.ownerAt(chunk("mem-bank-a"), 19).?.body());
    try testing.expect(schedule.ownerAt(chunk("mem-bank-a"), 20) == null);
}

test "resource contract supports periodic cpu ownership without signatures per tick" {
    const testing = @import("std").testing;
    var slots: [1]Contract = undefined;
    var schedule = Schedule.init(&slots);
    const contract = Contract.init(chunk("contract-cpu"), chunk("app-a"), chunk("cpu-slot-0"), .cpu, 100, 120, Bounds.init(0, 1), Pattern.periodic(2, 5));

    try schedule.install(contract);

    try testing.expectEqualStrings("app-a", schedule.ownerAt(chunk("cpu-slot-0"), 100).?.body());
    try testing.expectEqualStrings("app-a", schedule.ownerAt(chunk("cpu-slot-0"), 101).?.body());
    try testing.expect(schedule.ownerAt(chunk("cpu-slot-0"), 102) == null);
    try testing.expectEqualStrings("app-a", schedule.ownerAt(chunk("cpu-slot-0"), 105).?.body());
    try testing.expect(schedule.ownerAt(chunk("cpu-slot-0"), 120) == null);
}

test "resource contract verifies signature before installing schedule" {
    const testing = @import("std").testing;
    const contract = Contract.init(chunk("contract-gpu"), chunk("app-a"), chunk("gpu-queue-0"), .gpu, 1, 10, Bounds.init(0, 8), Pattern.exclusive());
    var canonical: [160]u8 = undefined;
    const expected = try encode(contract, &canonical);
    var executor = RecordingExecutor{ .expected_data = expected };
    const verifier = tpm_verifier.Verifier(RecordingExecutor).init(&executor);
    var slots: [1]Contract = undefined;
    var schedule = Schedule.init(&slots);
    var scratch: [160]u8 = undefined;

    const digest = try schedule.installVerified(RecordingExecutor, verifier, contract, testSignature(), &scratch);

    try testing.expectEqual(test_digest, digest);
    try testing.expectEqual(@as(usize, 1), schedule.len);
    try testing.expectEqualStrings("app-a", schedule.ownerAt(chunk("gpu-queue-0"), 1).?.body());
    try testing.expectEqual(RecordingExecutor.State.flushed, executor.state);
}

test "resource contract leaves schedule unchanged when signature fails" {
    const testing = @import("std").testing;
    const contract = Contract.init(chunk("contract-gpu"), chunk("app-a"), chunk("gpu-queue-0"), .gpu, 1, 10, Bounds.init(0, 8), Pattern.exclusive());
    var canonical: [160]u8 = undefined;
    const expected = try encode(contract, &canonical);
    var executor = RecordingExecutor{
        .expected_data = expected,
        .verify_ok = false,
    };
    const verifier = tpm_verifier.Verifier(RecordingExecutor).init(&executor);
    var slots: [1]Contract = undefined;
    var schedule = Schedule.init(&slots);
    var scratch: [160]u8 = undefined;

    try testing.expectError(error.VerifyFailed, schedule.installVerified(RecordingExecutor, verifier, contract, testSignature(), &scratch));
    try testing.expectEqual(@as(usize, 0), schedule.len);
    try testing.expect(schedule.ownerAt(chunk("gpu-queue-0"), 1) == null);
    try testing.expectEqual(RecordingExecutor.State.flushed, executor.state);
}

test "resource contract can require boot inventory fit before install" {
    const testing = @import("std").testing;
    const inventory_mod = @import("resource_inventory.zig");
    var resources: [1]inventory_mod.Resource = undefined;
    var inventory = inventory_mod.Inventory.init(&resources);
    try inventory.add(inventory_mod.Resource.init(chunk("memory-bank-0"), .memory, Bounds.init(0, 4096)));

    var slots: [1]Contract = undefined;
    var schedule = Schedule.init(&slots);
    const contract = Contract.init(chunk("contract-a"), chunk("app-a"), chunk("memory-bank-0"), .memory, 1, 10, Bounds.init(1024, 1024), Pattern.exclusive());
    const out_of_bounds = Contract.init(chunk("contract-b"), chunk("app-a"), chunk("memory-bank-0"), .memory, 1, 10, Bounds.init(3072, 2048), Pattern.exclusive());

    try schedule.installChecked(inventory, contract);
    try testing.expectEqual(@as(usize, 1), schedule.len);
    try testing.expectError(error.OutOfBounds, schedule.installChecked(inventory, out_of_bounds));
}

test "resource contract rejects malformed schedules" {
    const testing = @import("std").testing;
    var slots: [1]Contract = undefined;
    var schedule = Schedule.init(&slots);

    try testing.expectError(error.BadArgument, schedule.install(Contract.init(chunk("bad"), chunk("app-a"), chunk("cpu-slot-0"), .cpu, 10, 10, Bounds.init(0, 1), Pattern.periodic(1, 2))));
    try testing.expectError(error.BadArgument, schedule.install(Contract.init(chunk("bad"), chunk("app-a"), chunk("cpu-slot-0"), .cpu, 10, 20, Bounds.init(0, 1), Pattern.periodic(3, 2))));
    try testing.expectError(error.BadArgument, schedule.install(Contract.init(chunk("bad"), chunk("app-a"), chunk("cpu-slot-0"), .cpu, 10, 20, Bounds.init(0, 0), Pattern.exclusive())));
}

test "resource contract rejects overlapping ownership on the same resource" {
    const testing = @import("std").testing;
    var contracts: [2]Contract = undefined;
    var schedule = Schedule.init(&contracts);
    const first = Contract.init(chunk("first-contract"), chunk("app-a"), chunk("memory-bank-0"), .memory, 10, 20, Bounds.init(0, 64), Pattern.exclusive());
    const overlap = Contract.init(chunk("overlap-contract"), chunk("app-b"), chunk("memory-bank-0"), .memory, 15, 25, Bounds.init(32, 64), Pattern.exclusive());
    const adjacent = Contract.init(chunk("adjacent-contract"), chunk("app-b"), chunk("memory-bank-0"), .memory, 15, 25, Bounds.init(64, 64), Pattern.exclusive());

    try schedule.install(first);
    try testing.expectError(error.Conflict, schedule.install(overlap));
    try schedule.install(adjacent);
}
