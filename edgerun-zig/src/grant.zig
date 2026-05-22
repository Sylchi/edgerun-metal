const std = @import("std");
const bytes = @import("bytes.zig");
const clock = @import("clock.zig");
const identity = @import("identity.zig");
const preimage = @import("preimage.zig");

pub const id_size = preimage.hash_size;

pub const Resource = enum(u16) {
    memory = 1,
    storage_bytes = 2,
    storage_slots = 3,
    read_only_memory = 4,
};

pub const Grant = struct {
    issuer: identity.Id,
    subject: identity.Id,
    resource: Resource,
    amount: u64,
    epoch: clock.Stamp,

    pub fn valid(self: Grant) bool {
        return self.issuer.valid() and
            self.subject.valid() and
            self.amount != 0 and
            self.epoch.valid();
    }

    pub fn id(self: Grant) ?[id_size]u8 {
        if (!self.valid()) return null;

        var raw: [144]u8 = undefined;
        var writer = preimage.Writer.init(&raw);
        if (!writer.id(self.issuer) or
            !writer.id(self.subject) or
            !writer.writeU16(@intFromEnum(self.resource)) or
            !writer.writeU64(self.amount) or
            !writer.epoch(self.epoch))
        {
            return null;
        }
        return preimage.hash("edgerun:zig:v1:grant", writer.written());
    }
};

pub const SpawnReceipt = struct {
    parent: identity.Id,
    child: identity.Id,
    memory: Grant,
    storage_bytes: Grant,
    storage_slots: Grant,

    pub fn valid(self: SpawnReceipt) bool {
        return self.parent.valid() and
            self.child.valid() and
            self.memory.valid() and
            self.storage_bytes.valid() and
            self.storage_slots.valid() and
            self.memory.resource == .memory and
            self.storage_bytes.resource == .storage_bytes and
            self.storage_slots.resource == .storage_slots and
            self.memory.issuer.eql(self.parent) and
            self.storage_bytes.issuer.eql(self.parent) and
            self.storage_slots.issuer.eql(self.parent) and
            self.memory.subject.eql(self.child) and
            self.storage_bytes.subject.eql(self.child) and
            self.storage_slots.subject.eql(self.child);
    }

    pub fn id(self: SpawnReceipt) ?[id_size]u8 {
        if (!self.valid()) return null;

        const memory_id = self.memory.id().?;
        const storage_bytes_id = self.storage_bytes.id().?;
        const storage_slots_id = self.storage_slots.id().?;
        var raw: [160]u8 = undefined;
        var writer = preimage.Writer.init(&raw);
        if (!writer.id(self.parent) or
            !writer.id(self.child) or
            !writer.hash(memory_id) or
            !writer.hash(storage_bytes_id) or
            !writer.hash(storage_slots_id))
        {
            return null;
        }
        return preimage.hash("edgerun:zig:v1:spawn-receipt", writer.written());
    }
};

pub const MemoryViewReceipt = struct {
    owner: identity.Id,
    reader: identity.Id,
    slice: preimage.Hash,
    offset: u64,
    memory: Grant,

    pub fn valid(self: MemoryViewReceipt) bool {
        return self.owner.valid() and
            self.reader.valid() and
            bytes.nonzero(&self.slice) and
            self.memory.valid() and
            self.memory.resource == .read_only_memory and
            self.memory.issuer.eql(self.owner) and
            self.memory.subject.eql(self.reader);
    }

    pub fn id(self: MemoryViewReceipt) ?[id_size]u8 {
        if (!self.valid()) return null;

        const grant_id = self.memory.id().?;
        var raw: [144]u8 = undefined;
        var writer = preimage.Writer.init(&raw);
        if (!writer.id(self.owner) or
            !writer.id(self.reader) or
            !writer.hash(self.slice) or
            !writer.writeU64(self.offset) or
            !writer.hash(grant_id))
        {
            return null;
        }
        return preimage.hash("edgerun:zig:v1:memory-view-receipt", writer.written());
    }
};

pub fn spawnReceipt(parent: identity.Identity, child: identity.Identity, epoch: clock.Stamp, memory_bytes: usize, storage_bytes: usize, storage_slots: usize) ?SpawnReceipt {
    const memory_amount = std.math.cast(u64, memory_bytes) orelse return null;
    const storage_amount = std.math.cast(u64, storage_bytes) orelse return null;
    const slot_amount = std.math.cast(u64, storage_slots) orelse return null;

    return .{
        .parent = parent.id,
        .child = child.id,
        .memory = .{
            .issuer = parent.id,
            .subject = child.id,
            .resource = .memory,
            .amount = memory_amount,
            .epoch = epoch,
        },
        .storage_bytes = .{
            .issuer = parent.id,
            .subject = child.id,
            .resource = .storage_bytes,
            .amount = storage_amount,
            .epoch = epoch,
        },
        .storage_slots = .{
            .issuer = parent.id,
            .subject = child.id,
            .resource = .storage_slots,
            .amount = slot_amount,
            .epoch = epoch,
        },
    };
}

pub fn memoryViewReceipt(owner: identity.Identity, reader: identity.Id, slice: preimage.Hash, epoch: clock.Stamp, offset: usize, bytes_len: usize) ?MemoryViewReceipt {
    const offset_amount = std.math.cast(u64, offset) orelse return null;
    const byte_amount = std.math.cast(u64, bytes_len) orelse return null;

    return .{
        .owner = owner.id,
        .reader = reader,
        .slice = slice,
        .offset = offset_amount,
        .memory = .{
            .issuer = owner.id,
            .subject = reader,
            .resource = .read_only_memory,
            .amount = byte_amount,
            .epoch = epoch,
        },
    };
}

test "spawn receipt deterministically records delegated resources" {
    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const parent = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("parent")).?, epoch).?;
    const child = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("child")).?, epoch).?;
    const receipt = spawnReceipt(parent, child, epoch, 16, 32, 2).?;

    try std.testing.expect(receipt.valid());
    try std.testing.expect(bytes.nonzero(&receipt.id().?));
    try std.testing.expectEqual(@as(u64, 16), receipt.memory.amount);
}

test "memory view receipt binds owner reader slice and byte range" {
    const keeper = clock.KeeperId{ .bytes = [_]u8{2} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const owner = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("memory owner")).?, epoch).?;
    const reader = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("memory reader")).?, epoch).?;
    const slice = preimage.hash("edgerun:zig:v1:test-slice", "ui-state");
    const receipt = memoryViewReceipt(owner, reader.id, slice, epoch, 8, 32).?;

    try std.testing.expect(receipt.valid());
    try std.testing.expect(bytes.nonzero(&receipt.id().?));
    try std.testing.expectEqual(Resource.read_only_memory, receipt.memory.resource);
    try std.testing.expectEqual(@as(u64, 32), receipt.memory.amount);
    try std.testing.expectEqual(@as(u64, 8), receipt.offset);
}
