const bytes = @import("bytes.zig");
const clock = @import("clock.zig");
const identity = @import("identity.zig");
const preimage = @import("preimage.zig");

pub const id_size = preimage.hash_size;
const spawn_receipt_id_body_size = identity.id_size * 2 + preimage.hash_size * 6 + preimage.hash_size + identity.id_size;

pub const Resource = enum(u16) {
    memory = 1,
    storage_bytes = 2,
    storage_slots = 3,
    read_only_memory = 4,
    execution_ticks = 5,
    route_handles = 6,
    device_handles = 7,
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
            (self.amount != 0 or zeroAmountAllowed(self.resource)) and
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

fn zeroAmountAllowed(resource: Resource) bool {
    return switch (resource) {
        .storage_bytes,
        .storage_slots,
        .route_handles,
        .device_handles,
        => true,
        .memory,
        .read_only_memory,
        .execution_ticks,
        => false,
    };
}

pub const SpawnReceipt = struct {
    parent: identity.Id,
    child: identity.Id,
    memory: Grant,
    storage_bytes: Grant,
    storage_slots: Grant,
    execution_ticks: Grant,
    route_handles: Grant,
    device_handles: Grant,
    route_handle: preimage.Hash = [_]u8{0} ** preimage.hash_size,
    device_handle: identity.Id = .{ .bytes = [_]u8{0} ** identity.id_size },

    pub fn valid(self: SpawnReceipt) bool {
        return self.parent.valid() and
            self.child.valid() and
            self.memory.valid() and
            self.storage_bytes.valid() and
            self.storage_slots.valid() and
            self.execution_ticks.valid() and
            self.route_handles.valid() and
            self.device_handles.valid() and
            self.memory.resource == .memory and
            self.storage_bytes.resource == .storage_bytes and
            self.storage_slots.resource == .storage_slots and
            self.execution_ticks.resource == .execution_ticks and
            self.route_handles.resource == .route_handles and
            self.device_handles.resource == .device_handles and
            self.memory.issuer.eql(self.parent) and
            self.storage_bytes.issuer.eql(self.parent) and
            self.storage_slots.issuer.eql(self.parent) and
            self.execution_ticks.issuer.eql(self.parent) and
            self.route_handles.issuer.eql(self.parent) and
            self.device_handles.issuer.eql(self.parent) and
            self.memory.subject.eql(self.child) and
            self.storage_bytes.subject.eql(self.child) and
            self.storage_slots.subject.eql(self.child) and
            self.execution_ticks.subject.eql(self.child) and
            self.route_handles.subject.eql(self.child) and
            self.device_handles.subject.eql(self.child) and
            ((self.route_handles.amount == 0 and bytes.zeroed(&self.route_handle)) or
                (self.route_handles.amount != 0 and bytes.nonzero(&self.route_handle))) and
            ((self.device_handles.amount == 0 and !self.device_handle.valid()) or
                (self.device_handles.amount != 0 and self.device_handle.valid()));
    }

    pub fn permitsRoute(self: SpawnReceipt, route_handle: preimage.Hash) bool {
        return self.valid() and
            self.route_handles.amount != 0 and
            bytes.eql(&self.route_handle, &route_handle);
    }

    pub fn permitsDevice(self: SpawnReceipt, device_handle: identity.Id) bool {
        return self.valid() and
            self.device_handles.amount != 0 and
            self.device_handle.eql(device_handle);
    }

    pub fn id(self: SpawnReceipt) ?[id_size]u8 {
        if (!self.valid()) return null;

        const memory_id = self.memory.id().?;
        const storage_bytes_id = self.storage_bytes.id().?;
        const storage_slots_id = self.storage_slots.id().?;
        const execution_id = self.execution_ticks.id().?;
        const route_id = self.route_handles.id().?;
        const device_id = self.device_handles.id().?;
        var raw: [spawn_receipt_id_body_size]u8 = undefined;
        var writer = preimage.Writer.init(&raw);
        if (!writer.id(self.parent) or
            !writer.id(self.child) or
            !writer.hash(memory_id) or
            !writer.hash(storage_bytes_id) or
            !writer.hash(storage_slots_id) or
            !writer.hash(execution_id) or
            !writer.hash(route_id) or
            !writer.hash(device_id) or
            !writer.hash(self.route_handle) or
            !writer.id(self.device_handle))
        {
            return null;
        }
        return preimage.hash("edgerun:zig:v1:spawn-receipt", writer.written());
    }
};

pub const MemoryViewReceipt = struct {
    owner: identity.Id,
    allocator: identity.Id,
    reader: identity.Id,
    slice: preimage.Hash,
    offset: u64,
    authorization: preimage.Hash,
    memory: Grant,

    pub fn valid(self: MemoryViewReceipt) bool {
        return self.owner.valid() and
            self.allocator.valid() and
            self.reader.valid() and
            bytes.nonzero(&self.slice) and
            bytes.nonzero(&self.authorization) and
            self.memory.valid() and
            self.memory.resource == .read_only_memory and
            self.memory.issuer.eql(self.allocator) and
            self.memory.subject.eql(self.reader);
    }

    pub fn id(self: MemoryViewReceipt) ?[id_size]u8 {
        if (!self.valid()) return null;

        const grant_id = self.memory.id().?;
        var raw: [208]u8 = undefined;
        var writer = preimage.Writer.init(&raw);
        if (!writer.id(self.owner) or
            !writer.id(self.allocator) or
            !writer.id(self.reader) or
            !writer.hash(self.slice) or
            !writer.writeU64(self.offset) or
            !writer.hash(self.authorization) or
            !writer.hash(grant_id))
        {
            return null;
        }
        return preimage.hash("edgerun:zig:v1:memory-view-receipt", writer.written());
    }
};

pub fn spawnReceipt(parent: identity.Identity, child: identity.Identity, epoch: clock.Stamp, memory_bytes: usize, storage_bytes: usize, storage_slots: usize) ?SpawnReceipt {
    return spawnReceiptAllocated(parent, child, epoch, memory_bytes, storage_bytes, storage_slots, 1, 0, 0, [_]u8{0} ** preimage.hash_size, .{ .bytes = [_]u8{0} ** identity.id_size });
}

pub fn spawnReceiptAllocated(parent: identity.Identity, child: identity.Identity, epoch: clock.Stamp, memory_bytes: usize, storage_bytes: usize, storage_slots: usize, execution_ticks: u64, route_handles: u64, device_handles: u64, route_handle: preimage.Hash, device_handle: identity.Id) ?SpawnReceipt {
    const memory_amount = @as(u64, @intCast(memory_bytes));
    const storage_amount = @as(u64, @intCast(storage_bytes));
    const slot_amount = @as(u64, @intCast(storage_slots));
    if (execution_ticks == 0) return null;
    if (route_handles == 0 and bytes.nonzero(&route_handle)) return null;
    if (route_handles != 0 and bytes.zeroed(&route_handle)) return null;
    if (device_handles == 0 and device_handle.valid()) return null;
    if (device_handles != 0 and !device_handle.valid()) return null;

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
        .execution_ticks = .{
            .issuer = parent.id,
            .subject = child.id,
            .resource = .execution_ticks,
            .amount = execution_ticks,
            .epoch = epoch,
        },
        .route_handles = .{
            .issuer = parent.id,
            .subject = child.id,
            .resource = .route_handles,
            .amount = route_handles,
            .epoch = epoch,
        },
        .device_handles = .{
            .issuer = parent.id,
            .subject = child.id,
            .resource = .device_handles,
            .amount = device_handles,
            .epoch = epoch,
        },
        .route_handle = route_handle,
        .device_handle = device_handle,
    };
}

pub fn memoryViewReceipt(owner: identity.Identity, allocator: identity.Identity, reader: identity.Identity, slice: preimage.Hash, authorization: preimage.Hash, epoch: clock.Stamp, offset: usize, bytes_len: usize) ?MemoryViewReceipt {
    const offset_amount = @as(u64, @intCast(offset));
    const byte_amount = @as(u64, @intCast(bytes_len));

    return .{
        .owner = owner.id,
        .allocator = allocator.id,
        .reader = reader.id,
        .slice = slice,
        .offset = offset_amount,
        .authorization = authorization,
        .memory = .{
            .issuer = allocator.id,
            .subject = reader.id,
            .resource = .read_only_memory,
            .amount = byte_amount,
            .epoch = epoch,
        },
    };
}

test "spawn receipt deterministically records delegated resources" {
    const std = @import("std");
    const testing = std.testing;
    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const parent = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("parent")).?, epoch).?;
    const child = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("child")).?, epoch).?;
    const device = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("spawn receipt device")).?, epoch).?;
    const route_handle = preimage.hash("edgerun:zig:v1:test-route", "spawn receipt route");
    const receipt = spawnReceipt(parent, child, epoch, 16, 32, 2).?;
    const allocated_receipt = spawnReceiptAllocated(parent, child, epoch, 16, 32, 2, 4, 1, 1, route_handle, device.id).?;
    const memory_only_receipt = spawnReceiptAllocated(parent, child, epoch, 16, 0, 0, 4, 0, 0, [_]u8{0} ** preimage.hash_size, .{ .bytes = [_]u8{0} ** identity.id_size }).?;

    try testing.expect(receipt.valid());
    try testing.expect(bytes.nonzero(&receipt.id().?));
    try testing.expectEqual(@as(u64, 16), receipt.memory.amount);
    try testing.expectEqual(Resource.execution_ticks, receipt.execution_ticks.resource);
    try testing.expectEqual(@as(u64, 0), receipt.route_handles.amount);
    try testing.expectEqual(@as(u64, 0), receipt.device_handles.amount);
    try testing.expect(allocated_receipt.valid());
    try testing.expectEqual(@as(u64, 1), allocated_receipt.route_handles.amount);
    try testing.expectEqual(@as(u64, 1), allocated_receipt.device_handles.amount);
    try testing.expect(bytes.eql(&route_handle, &allocated_receipt.route_handle));
    try testing.expect(allocated_receipt.device_handle.eql(device.id));
    try testing.expect(allocated_receipt.permitsRoute(route_handle));
    try testing.expect(allocated_receipt.permitsDevice(device.id));
    try testing.expect(!receipt.permitsRoute(route_handle));
    try testing.expect(!receipt.permitsDevice(device.id));
    try testing.expect(memory_only_receipt.valid());
    try testing.expectEqual(@as(u64, 0), memory_only_receipt.storage_bytes.amount);
    try testing.expectEqual(@as(u64, 0), memory_only_receipt.storage_slots.amount);
    try testing.expect(!memory_only_receipt.permitsRoute(route_handle));
    try testing.expect(!memory_only_receipt.permitsDevice(device.id));
    try testing.expect(spawnReceiptAllocated(parent, child, epoch, 16, 32, 2, 4, 1, 1, [_]u8{0} ** preimage.hash_size, device.id) == null);
    try testing.expect(spawnReceiptAllocated(parent, child, epoch, 16, 32, 2, 4, 1, 1, route_handle, .{ .bytes = [_]u8{0} ** identity.id_size }) == null);
}

test "memory view receipt binds owner reader slice and byte range" {
    const std = @import("std");
    const testing = std.testing;
    const keeper = clock.KeeperId{ .bytes = [_]u8{2} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const owner = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("memory owner")).?, epoch).?;
    const allocator = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("memory allocator")).?, epoch).?;
    const reader = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("memory reader")).?, epoch).?;
    const slice = preimage.hash("edgerun:zig:v1:test-slice", "ui-state");
    const authorization = preimage.hash("edgerun:zig:v1:test-memory-grant", "allocator approved");
    const receipt = memoryViewReceipt(owner, allocator, reader, slice, authorization, epoch, 8, 32).?;

    try testing.expect(receipt.valid());
    try testing.expect(bytes.nonzero(&receipt.id().?));
    try testing.expect(receipt.allocator.eql(allocator.id));
    try testing.expect(bytes.eql(&receipt.authorization, &authorization));
    try testing.expectEqual(Resource.read_only_memory, receipt.memory.resource);
    try testing.expectEqual(@as(u64, 32), receipt.memory.amount);
    try testing.expectEqual(@as(u64, 8), receipt.offset);
}
