const std = @import("std");
const BoundedArena = @import("arena.zig").BoundedArena;
const bytes = @import("bytes.zig");
const clock = @import("clock.zig");
const grant = @import("grant.zig");
const identity = @import("identity.zig");
const intent = @import("intent.zig");
const preimage = @import("preimage.zig");
const relay = @import("relay.zig");
const seal = @import("seal.zig");
const store = @import("store.zig");
const object = @import("object.zig");
const ui = @import("ui.zig");
const ui_components = @import("ui_components.zig");
const ui_resolver = @import("ui_resolver.zig");

const allocation_count_field_size = @sizeOf(u64);
const allocation_count_field_count = 6;
const allocation_count_body_size = allocation_count_field_size * allocation_count_field_count;
const allocation_body_size = allocation_count_body_size + preimage.hash_size + identity.id_size;
const work_receipt_id_field_count = 2;
const work_receipt_hash_field_count = 5;
const work_receipt_epoch_field_count = 2;
const work_receipt_body_size = identity.id_size * work_receipt_id_field_count +
    preimage.hash_size * work_receipt_hash_field_count +
    preimage.epoch_size * work_receipt_epoch_field_count;

pub const SpawnError = error{
    BadAllocation,
    NoExecution,
    NoMemory,
    NoStorage,
    NoRoute,
    NoDevice,
    Unauthorized,
};

pub const ReceiptError = error{
    BadArgument,
    Corrupt,
    NoSpace,
    Unsupported,
};

pub const ReclaimError = error{
    Corrupt,
    Unauthorized,
};

pub const App = struct {
    id: identity.Identity,
    memory: BoundedArena,
    storage: store.Store,
    execution_ticks: u64 = 0,
    route_handles: u64 = 0,
    device_handles: u64 = 0,
    route_handle: preimage.Hash = [_]u8{0} ** preimage.hash_size,
    device_handle: identity.Id = .{ .bytes = [_]u8{0} ** identity.id_size },
    can_spawn_children: bool = true,

    pub fn init(id: identity.Identity, memory: BoundedArena, storage: store.Store) App {
        return .{
            .id = id,
            .memory = memory,
            .storage = storage,
        };
    }

    pub fn initAllocated(id: identity.Identity, memory: BoundedArena, storage: store.Store, allocation: DeclaredAllocation) ?App {
        if (!allocation.valid()) return null;
        return .{
            .id = id,
            .memory = memory,
            .storage = storage,
            .execution_ticks = allocation.execution_ticks,
            .route_handles = allocation.route_handles,
            .device_handles = allocation.device_handles,
            .route_handle = allocation.route_handle,
            .device_handle = allocation.device_handle,
        };
    }

    pub fn initFromHostSlice(id: identity.Identity, host_memory: BoundedArena, storage_bytes: usize, storage_slots: usize) ?App {
        var memory = host_memory;
        const storage = store.Store.initFromArena(&memory, .{
            .data_bytes = storage_bytes,
            .slot_count = storage_slots,
        }) orelse return null;
        return init(id, memory, storage);
    }

    pub const Spawned = struct {
        app: App,
        receipt: grant.SpawnReceipt,
    };

    pub const DeclaredAllocation = struct {
        memory_bytes: usize,
        storage_bytes: usize,
        storage_slots: usize,
        execution_ticks: u64 = 1,
        route_handles: u64 = 0,
        device_handles: u64 = 0,
        route_handle: preimage.Hash = [_]u8{0} ** preimage.hash_size,
        device_handle: identity.Id = .{ .bytes = [_]u8{0} ** identity.id_size },

        pub fn valid(self: DeclaredAllocation) bool {
            return self.memory_bytes != 0 and
                self.storage_bytes != 0 and
                self.storage_slots != 0 and
                self.execution_ticks != 0 and
                ((self.route_handles == 0 and bytes.zeroed(&self.route_handle)) or
                    (self.route_handles != 0 and bytes.nonzero(&self.route_handle))) and
                ((self.device_handles == 0 and !self.device_handle.valid()) or
                    (self.device_handles != 0 and self.device_handle.valid()));
        }

        pub fn id(self: DeclaredAllocation) ?preimage.Hash {
            if (!self.valid()) return null;
            const memory_amount = std.math.cast(u64, self.memory_bytes) orelse return null;
            const storage_amount = std.math.cast(u64, self.storage_bytes) orelse return null;
            const slot_amount = std.math.cast(u64, self.storage_slots) orelse return null;
            var raw: [allocation_body_size]u8 = undefined;
            var writer = preimage.Writer.init(&raw);
            if (!writer.writeU64(memory_amount) or
                !writer.writeU64(storage_amount) or
                !writer.writeU64(slot_amount) or
                !writer.writeU64(self.execution_ticks) or
                !writer.writeU64(self.route_handles) or
                !writer.writeU64(self.device_handles) or
                !writer.hash(self.route_handle) or
                !writer.id(self.device_handle))
            {
                return null;
            }
            return preimage.hash("edgerun:zig:v1:app-declared-allocation", writer.written());
        }
    };

    pub const manifest_magic = "ERAPP001";
    pub const manifest_body_size = manifest_allocation_offset + allocation_body_size;
    pub const manifest_flags_offset = 8;
    pub const manifest_code_hash_offset = 16;
    pub const manifest_allocation_offset = 48;
    pub const manifest_flag_child_spawn: u32 = 1;

    pub const Manifest = struct {
        code_hash: preimage.Hash,
        allocation: DeclaredAllocation,
        flags: u32 = 0,

        pub fn valid(self: Manifest) bool {
            return bytes.nonzero(&self.code_hash) and
                self.allocation.valid() and
                (self.flags & ~manifest_flag_child_spawn) == 0;
        }

        pub fn childSpawnAllowed(self: Manifest) bool {
            return (self.flags & manifest_flag_child_spawn) != 0;
        }

        pub fn encodeBody(self: Manifest, out: []u8) bool {
            if (!self.valid() or out.len < manifest_body_size) return false;
            bytes.zero(out[0..manifest_body_size]);
            return bytes.copy(out[0..manifest_magic.len], manifest_magic) and
                bytes.store32(out[manifest_flags_offset..][0..4], self.flags) and
                bytes.copy(out[manifest_code_hash_offset..][0..preimage.hash_size], &self.code_hash) and
                writeAllocationBody(self.allocation, out[manifest_allocation_offset..][0..allocation_body_size]);
        }

        pub fn decodeBody(in: []const u8) ?Manifest {
            if (in.len != manifest_body_size or !bytes.eql(in[0..manifest_magic.len], manifest_magic)) return null;
            if (!bytes.zeroed(in[12..16])) return null;
            const flags = bytes.load32(in[manifest_flags_offset..][0..4]) orelse return null;
            var code_hash: preimage.Hash = undefined;
            _ = bytes.copy(&code_hash, in[manifest_code_hash_offset..][0..preimage.hash_size]);
            const manifest = Manifest{
                .code_hash = code_hash,
                .allocation = readAllocationBody(in[manifest_allocation_offset..][0..allocation_body_size]) orelse return null,
                .flags = flags,
            };
            return if (manifest.valid()) manifest else null;
        }

        pub fn fromObject(canonical: []const u8) ?Manifest {
            const view = object.View.decode(canonical) catch return null;
            if (view.header.kind != .bytes or view.body.len != manifest_body_size) return null;
            if (view.header.requirements.durability != .durable or
                view.header.requirements.integrity != .hash_only or
                view.header.requirements.access != .explicit_io)
            {
                return null;
            }
            return decodeBody(view.body);
        }
    };

    pub const Reclaimed = struct {
        parent: identity.Id,
        child: identity.Id,
        epoch: clock.Stamp,
        receipt: grant.SpawnReceipt,

        pub fn valid(self: Reclaimed) bool {
            return self.parent.valid() and
                self.child.valid() and
                self.epoch.valid() and
                self.receipt.valid() and
                self.receipt.parent.eql(self.parent) and
                self.receipt.child.eql(self.child);
        }

        pub fn id(self: Reclaimed) ?preimage.Hash {
            if (!self.valid()) return null;
            const receipt_id = self.receipt.id().?;
            var raw: [identity.id_size * 2 + preimage.hash_size + preimage.epoch_size]u8 = undefined;
            var writer = preimage.Writer.init(&raw);
            if (!writer.id(self.parent) or !writer.id(self.child) or !writer.hash(receipt_id) or !writer.epoch(self.epoch)) return null;
            return preimage.hash("edgerun:zig:v1:app-reclaim", writer.written());
        }
    };

    pub const WorkReceipt = struct {
        parent: identity.Id,
        app: identity.Id,
        input: preimage.Hash,
        output: preimage.Hash,
        manifest: preimage.Hash,
        clock_start: clock.Stamp,
        clock_end: clock.Stamp,
        allocation: DeclaredAllocation,
        spawn_receipt: grant.SpawnReceipt,

        pub fn valid(self: WorkReceipt) bool {
            const memory_amount = std.math.cast(u64, self.allocation.memory_bytes) orelse return false;
            const storage_amount = std.math.cast(u64, self.allocation.storage_bytes) orelse return false;
            const slot_amount = std.math.cast(u64, self.allocation.storage_slots) orelse return false;
            return self.parent.valid() and
                self.app.valid() and
                bytes.nonzero(&self.input) and
                bytes.nonzero(&self.output) and
                bytes.nonzero(&self.manifest) and
                self.clock_start.valid() and
                self.clock_end.valid() and
                self.clock_start.sameKeeper(self.clock_end) and
                self.clock_start.order(self.clock_end) <= 0 and
                self.allocation.valid() and
                self.spawn_receipt.valid() and
                self.spawn_receipt.parent.eql(self.parent) and
                self.spawn_receipt.child.eql(self.app) and
                self.spawn_receipt.memory.amount == memory_amount and
                self.spawn_receipt.storage_bytes.amount == storage_amount and
                self.spawn_receipt.storage_slots.amount == slot_amount and
                self.spawn_receipt.execution_ticks.amount == self.allocation.execution_ticks and
                self.spawn_receipt.route_handles.amount == self.allocation.route_handles and
                self.spawn_receipt.device_handles.amount == self.allocation.device_handles and
                bytes.eql(&self.spawn_receipt.route_handle, &self.allocation.route_handle) and
                self.spawn_receipt.device_handle.eql(self.allocation.device_handle);
        }

        pub fn id(self: WorkReceipt) ?preimage.Hash {
            if (!self.valid()) return null;
            var raw: [work_receipt_body_size]u8 = undefined;
            const body = self.encodeBody(&raw) orelse return null;
            return preimage.hash("edgerun:zig:v1:app-work-receipt", body);
        }

        pub fn writeObject(self: WorkReceipt, epoch: clock.Stamp, out: []u8) object.Error![]u8 {
            if (!epoch.valid()) return error.BadArgument;
            var body: [work_receipt_body_size]u8 = undefined;
            const encoded = self.encodeBody(&body) orelse return error.BadArgument;
            return try (object.NodeWriter{ .out = out }).receiptNode(workReceiptRequirements(), epoch, encoded);
        }

        fn encodeBody(self: WorkReceipt, out: []u8) ?[]const u8 {
            if (!self.valid() or out.len < work_receipt_body_size) return null;
            const allocation_id = self.allocation.id().?;
            const spawn_id = self.spawn_receipt.id().?;
            var writer = preimage.Writer.init(out[0..work_receipt_body_size]);
            if (!writer.id(self.parent) or
                !writer.id(self.app) or
                !writer.hash(self.input) or
                !writer.hash(self.output) or
                !writer.hash(self.manifest) or
                !writer.epoch(self.clock_start) or
                !writer.epoch(self.clock_end) or
                !writer.hash(allocation_id) or
                !writer.hash(spawn_id))
            {
                return null;
            }
            return writer.written();
        }
    };

    pub const Received = struct {
        app: identity.Id,
        route: preimage.Hash,
        envelope: preimage.Hash,
        action: intent.Action,
        consequence: intent.Consequence,
        epoch: clock.Stamp,

        pub fn valid(self: Received) bool {
            return self.app.valid() and
                bytes.nonzero(&self.route) and
                bytes.nonzero(&self.envelope) and
                self.epoch.valid();
        }

        pub fn id(self: Received) ?preimage.Hash {
            if (!self.valid()) return null;

            var raw: [164]u8 = undefined;
            var writer = preimage.Writer.init(&raw);
            if (!writer.id(self.app) or
                !writer.hash(self.route) or
                !writer.hash(self.envelope) or
                !writer.writeU16(@intFromEnum(self.action)) or
                !writer.writeU16(@intFromEnum(self.consequence)) or
                !writer.epoch(self.epoch))
            {
                return null;
            }
            return preimage.hash("edgerun:zig:v1:app-receive", writer.written());
        }
    };

    pub const UiError = error{
        NoSpace,
        Corrupt,
        Unsealed,
        MissingObject,
        ResolutionBudgetExceeded,
        UnsupportedComponent,
        ComponentBudgetExceeded,
        ChildMismatch,
        RenderBudgetExceeded,
        InvalidBounds,
    };

    pub const MemoryShareError = error{
        NoMemory,
        Corrupt,
        Unauthorized,
    };

    pub const SharedMemory = struct {
        owner: identity.Id,
        id: preimage.Hash,
        offset: usize,
        bytes: []u8,
        epoch: clock.Stamp,

        pub fn valid(self: SharedMemory) bool {
            return self.owner.valid() and
                bytes.nonzero(&self.id) and
                self.bytes.len != 0 and
                self.epoch.valid();
        }

        pub fn readOnly(self: SharedMemory) []const u8 {
            return self.bytes;
        }
    };

    pub const ReadOnlyMemory = struct {
        owner: identity.Id,
        reader: identity.Id,
        slice: preimage.Hash,
        offset: usize,
        bytes: []const u8,
        receipt: grant.MemoryViewReceipt,

        pub fn valid(self: ReadOnlyMemory) bool {
            return self.owner.valid() and
                self.reader.valid() and
                bytes.nonzero(&self.slice) and
                self.bytes.len != 0 and
                self.receipt.valid() and
                self.receipt.owner.eql(self.owner) and
                self.receipt.reader.eql(self.reader) and
                bytes.eql(&self.receipt.slice, &self.slice) and
                self.receipt.offset == self.offset and
                self.receipt.memory.amount == self.bytes.len;
        }
    };

    pub const UiScratch = struct {
        codec: []u8,
        object: []u8,
        resolved: []object.View,
        components: []ui_components.Component,
        nodes: []ui.Node,
    };

    pub const PublishedUi = struct {
        app: identity.Id,
        object_id: preimage.Hash,
        epoch: clock.Stamp,

        pub fn valid(self: PublishedUi) bool {
            return self.app.valid() and bytes.nonzero(&self.object_id) and self.epoch.valid();
        }

        pub fn id(self: PublishedUi) ?preimage.Hash {
            if (!self.valid()) return null;
            var raw: [identity.id_size + preimage.hash_size + preimage.epoch_size]u8 = undefined;
            var writer = preimage.Writer.init(&raw);
            if (!writer.id(self.app) or !writer.hash(self.object_id) or !writer.epoch(self.epoch)) return null;
            return preimage.hash("edgerun:zig:v1:app-ui-publication", writer.written());
        }
    };

    pub fn spawnDeclared(self: *App, allocator_id: identity.Identity, child_id: identity.Identity, epoch: clock.Stamp, authorization: intent.Receipt, allocation: DeclaredAllocation) SpawnError!Spawned {
        if (!allocation.valid()) return error.BadAllocation;
        if (!self.can_spawn_children) return error.Unauthorized;
        if (!authorization.permitsAt(epoch, allocator_id.id, child_id.id, .spawn_app, .delegates_resources)) return error.Unauthorized;
        if (allocation.execution_ticks > self.execution_ticks) return error.NoExecution;
        if (allocation.route_handles > self.route_handles) return error.NoRoute;
        if (allocation.device_handles > self.device_handles) return error.NoDevice;
        if (allocation.route_handles != 0 and !bytes.eql(&allocation.route_handle, &self.route_handle)) return error.NoRoute;
        if (allocation.device_handles != 0 and !allocation.device_handle.eql(self.device_handle)) return error.NoDevice;

        const child_memory = self.memory.split(allocation.memory_bytes) orelse return error.NoMemory;
        const child_storage = self.storage.split(.{
            .data_bytes = allocation.storage_bytes,
            .slot_count = allocation.storage_slots,
        }) orelse return error.NoStorage;
        self.execution_ticks -= allocation.execution_ticks;
        self.route_handles -= allocation.route_handles;
        self.device_handles -= allocation.device_handles;
        const receipt = grant.spawnReceiptAllocated(
            self.id,
            child_id,
            epoch,
            allocation.memory_bytes,
            allocation.storage_bytes,
            allocation.storage_slots,
            allocation.execution_ticks,
            allocation.route_handles,
            allocation.device_handles,
            allocation.route_handle,
            allocation.device_handle,
        ) orelse return error.BadAllocation;

        return .{
            .app = .{
                .id = child_id,
                .memory = child_memory,
                .storage = child_storage,
                .execution_ticks = allocation.execution_ticks,
                .route_handles = allocation.route_handles,
                .device_handles = allocation.device_handles,
                .route_handle = allocation.route_handle,
                .device_handle = allocation.device_handle,
            },
            .receipt = receipt,
        };
    }

    pub fn spawnManifest(self: *App, allocator_id: identity.Identity, child_id: identity.Identity, epoch: clock.Stamp, authorization: intent.Receipt, manifest_canonical: []const u8) SpawnError!Spawned {
        const manifest = Manifest.fromObject(manifest_canonical) orelse return error.BadAllocation;
        var spawned = try self.spawnDeclared(allocator_id, child_id, epoch, authorization, manifest.allocation);
        spawned.app.can_spawn_children = manifest.childSpawnAllowed();
        return spawned;
    }

    pub fn completeWork(self: App, parent: identity.Id, input: preimage.Hash, output: preimage.Hash, manifest: preimage.Hash, clock_start: clock.Stamp, clock_end: clock.Stamp, allocation: DeclaredAllocation, spawn_receipt: grant.SpawnReceipt) ?WorkReceipt {
        const receipt = WorkReceipt{
            .parent = parent,
            .app = self.id.id,
            .input = input,
            .output = output,
            .manifest = manifest,
            .clock_start = clock_start,
            .clock_end = clock_end,
            .allocation = allocation,
            .spawn_receipt = spawn_receipt,
        };
        if (!receipt.valid()) return null;
        return receipt;
    }

    pub fn putWorkReceipt(self: *App, receipt: WorkReceipt, epoch: clock.Stamp, out: []u8) ReceiptError!preimage.Hash {
        if (!receipt.valid() or !receipt.app.eql(self.id.id)) return error.BadArgument;
        const canonical = receipt.writeObject(epoch, out) catch |err| return mapObjectError(err);
        return self.storage.putReceipt(self.id.id, canonical) orelse error.NoSpace;
    }

    pub fn reclaimChild(self: *App, child: *App, receipt: grant.SpawnReceipt, epoch: clock.Stamp) ReclaimError!Reclaimed {
        if (!epoch.valid() or !receipt.valid()) return error.Corrupt;
        if (!receipt.parent.eql(self.id.id) or !receipt.child.eql(child.id.id)) return error.Unauthorized;
        if (receipt.memory.amount != child.memory.owned.len()) return error.Corrupt;
        if (receipt.storage_bytes.amount != child.storage.owned.len()) return error.Corrupt;
        if (receipt.storage_slots.amount != child.storage.slotCapacity()) return error.Corrupt;
        if (receipt.execution_ticks.amount != child.execution_ticks) return error.Corrupt;
        if (receipt.route_handles.amount != child.route_handles) return error.Corrupt;
        if (receipt.device_handles.amount != child.device_handles) return error.Corrupt;
        if (!bytes.eql(&receipt.route_handle, &child.route_handle)) return error.Corrupt;
        if (!receipt.device_handle.eql(child.device_handle)) return error.Corrupt;
        if (!self.memory.canReclaim(child.memory) or !self.storage.canReclaim(child.storage)) return error.Corrupt;
        if (!self.memory.reclaim(&child.memory)) return error.Corrupt;
        if (!self.storage.reclaim(&child.storage)) return error.Corrupt;
        self.execution_ticks += child.execution_ticks;
        self.route_handles += child.route_handles;
        self.device_handles += child.device_handles;
        child.execution_ticks = 0;
        child.route_handles = 0;
        child.device_handles = 0;
        child.route_handle = [_]u8{0} ** preimage.hash_size;
        child.device_handle = .{ .bytes = [_]u8{0} ** identity.id_size };
        child.can_spawn_children = false;
        return .{
            .parent = self.id.id,
            .child = child.id.id,
            .epoch = epoch,
            .receipt = receipt,
        };
    }

    pub fn createRelayEnvelope(self: App, route: relay.Route, sequence: u64, payload_object: preimage.Hash, payload_hash: preimage.Hash) ?relay.Envelope {
        if (self.route_handles == 0) return null;
        const route_id = route.id() orelse return null;
        if (!bytes.eql(&route_id, &self.route_handle)) return null;
        if (!route.source.eql(self.id.id)) return null;
        var envelope = relay.Envelope.init(route, sequence, payload_object, payload_hash) orelse return null;
        if (!envelope.sign(self.id)) return null;
        return envelope;
    }

    pub fn receiveRelayEnvelope(self: App, route: relay.Route, envelope: relay.Envelope, now: clock.Stamp) relay.RouteError!Received {
        if (self.route_handles == 0) return error.WrongDestination;
        const route_id = route.id() orelse return error.InvalidRoute;
        if (!bytes.eql(&route_id, &self.route_handle)) return error.WrongDestination;
        try relay.deliverTo(route, envelope, self.id, now);
        return .{
            .app = self.id.id,
            .route = route.id() orelse return error.InvalidRoute,
            .envelope = envelope.id() orelse return error.InvalidEnvelope,
            .action = envelope.action,
            .consequence = envelope.consequence,
            .epoch = now,
        };
    }

    pub fn reserveSharedMemory(self: *App, size: usize, label: []const u8, epoch: clock.Stamp) MemoryShareError!SharedMemory {
        if (size == 0 or !bytes.nonzero(label) or !epoch.valid()) return error.Corrupt;
        const slice = self.memory.allocSlice(u8, size) orelse return error.NoMemory;
        const offset = self.memory.offsetOf(slice) orelse return error.Corrupt;
        const slice_id = sharedMemoryId(self.id.id, offset, slice.len, label, epoch) orelse return error.Corrupt;
        return .{
            .owner = self.id.id,
            .id = slice_id,
            .offset = offset,
            .bytes = slice,
            .epoch = epoch,
        };
    }

    pub fn consumeExecution(self: *App, ticks: u64) bool {
        if (ticks == 0 or ticks > self.execution_ticks) return false;
        self.execution_ticks -= ticks;
        return true;
    }

    pub fn useDevice(self: App, device: identity.Identity) bool {
        return self.device_handles != 0 and device.kind == .device and device.id.eql(self.device_handle);
    }

    pub fn writeManifestObject(owner: identity.Identity, manifest: Manifest, epoch: clock.Stamp, out: []u8) object.Error![]u8 {
        var body: [manifest_body_size]u8 = undefined;
        if (!manifest.encodeBody(&body)) return error.BadArgument;
        const object_owner = object.Owner{
            .kind = .app,
            .node_id = owner.id.bytes,
        };
        return try (object.NodeWriter{ .out = out }).bytesNodeOwned(manifestRequirements(), epoch, &.{object_owner}, &.{}, &body);
    }

    pub fn putSealedObject(self: *App, device: identity.Identity, user: identity.Identity, canonical: []const u8) ?preimage.Hash {
        if (!self.objectSealedForApp(device, user, canonical)) return null;
        return self.storage.putObject(self.id.id, canonical);
    }

    fn objectSealedForApp(self: App, device: identity.Identity, user: identity.Identity, canonical: []const u8) bool {
        const view = object.View.decode(canonical) catch return false;
        if (!objectRequiresSeal(view.header.requirements)) return true;
        const expected_policy = seal.Policy.fromRequirements(view.header.requirements, device, self.id, user);
        const expected_policy_id = expected_policy.id() orelse return false;

        var index: usize = 0;
        while (index < view.header.envelope_count) : (index += 1) {
            const envelope = view.envelopeAt(index) catch return false;
            if (envelope.kind != .app or envelope.algorithm != .aes_gcm_256) continue;
            if (!bytes.eql(&envelope.metadata_hash, &expected_policy_id)) continue;
            const owner = view.ownerAt(envelope.owner_index) catch return false;
            if (owner.kind == .app and bytes.eql(&owner.node_id, &self.id.id.bytes)) return true;
        }
        return false;
    }

    pub fn shareMemoryReadOnly(self: App, reader: identity.Id, slice: SharedMemory, epoch: clock.Stamp, authorization: intent.Receipt) MemoryShareError!ReadOnlyMemory {
        if (!slice.valid() or !reader.valid() or !slice.owner.eql(self.id.id) or !epoch.valid()) return error.Corrupt;
        const offset = self.memory.offsetOf(slice.bytes) orelse return error.Corrupt;
        if (offset != slice.offset) return error.Corrupt;
        if (!authorization.permitsAt(epoch, self.id.id, reader, .grant_resource, .exports_data)) return error.Unauthorized;

        const receipt = grant.memoryViewReceipt(self.id, reader, slice.id, epoch, offset, slice.bytes.len) orelse return error.Corrupt;
        return .{
            .owner = self.id.id,
            .reader = reader,
            .slice = slice.id,
            .offset = offset,
            .bytes = slice.readOnly(),
            .receipt = receipt,
        };
    }

    pub fn publishUiComponent(self: *App, component: ui_components.Component, epoch: clock.Stamp, scratch: UiScratch) UiError!PublishedUi {
        if (!epoch.valid()) return error.Corrupt;
        const canonical = component.toObject(scratch.codec, scratch.object, uiObjectRequirements(), epoch) orelse return error.NoSpace;
        const object_id = self.putPublicObject(canonical) orelse return error.NoSpace;
        return .{ .app = self.id.id, .object_id = object_id, .epoch = epoch };
    }

    pub fn publishUiStack(self: *App, stack: ui_components.Stack, epoch: clock.Stamp, scratch: UiScratch) UiError!PublishedUi {
        if (!epoch.valid()) return error.Corrupt;
        const canonical = stack.toObject(scratch.codec, scratch.object, uiObjectRequirements(), epoch) orelse return error.NoSpace;
        const object_id = self.putPublicObject(canonical) orelse return error.NoSpace;
        return .{ .app = self.id.id, .object_id = object_id, .epoch = epoch };
    }

    fn putPublicObject(self: *App, canonical: []const u8) ?preimage.Hash {
        const view = object.View.decode(canonical) catch return null;
        if (objectRequiresSeal(view.header.requirements)) return null;
        return self.storage.putObject(self.id.id, canonical);
    }

    pub fn renderPublishedUi(self: App, publication: PublishedUi, scratch: UiScratch, scene: *ui.Scene, bounds: ui.Rect, style: ui.Style) UiError!void {
        if (!publication.valid() or !publication.app.eql(self.id.id)) return error.Corrupt;
        try self.renderStoredUi(publication.object_id, scratch, scene, bounds, style);
    }

    pub fn renderStoredUi(self: App, object_id: preimage.Hash, scratch: UiScratch, scene: *ui.Scene, bounds: ui.Rect, style: ui.Style) UiError!void {
        const view = self.storage.getObject(self.id.id, object_id) orelse return error.MissingObject;
        const root = try self.uiRootFromView(view, scratch);
        scene.clear();
        ui.render(scene, root, bounds, style) catch |err| switch (err) {
            error.CommandBudgetExceeded, error.ClipBudgetExceeded => return error.RenderBudgetExceeded,
            error.InvalidBounds => return error.InvalidBounds,
        };
    }

    fn uiRootFromView(self: App, view: object.View, scratch: UiScratch) UiError!ui.Node {
        if (view.header.kind == .tree) {
            const tree = ui_resolver.resolveTree(self.storage, self.id.id, view, scratch.resolved, scratch.components) catch |err| return mapResolverError(err);
            return tree.node(scratch.nodes) orelse error.ComponentBudgetExceeded;
        }

        const stack = ui_components.Stack.fromView(view, scratch.components) catch |err| return mapComponentError(err);
        return stack.node(scratch.nodes) orelse error.ComponentBudgetExceeded;
    }
};

pub fn uiObjectRequirements() object.Requirements {
    return .{
        .durability = .memory,
        .confidentiality = .app_private,
        .portability = .app_portable,
        .integrity = .hash_only,
        .lifetime = .session,
        .visibility = .app_namespace,
        .access = .hot_memory_allowed,
    };
}

pub fn manifestRequirements() object.Requirements {
    return .{
        .durability = .durable,
        .confidentiality = .app_private,
        .portability = .app_portable,
        .integrity = .hash_only,
        .lifetime = .retained,
        .visibility = .app_namespace,
        .access = .explicit_io,
    };
}

pub fn workReceiptRequirements() object.Requirements {
    return .{
        .durability = .durable,
        .confidentiality = .integrity_only,
        .portability = .app_portable,
        .integrity = .hash_only,
        .lifetime = .retained,
        .visibility = .app_namespace,
        .access = .explicit_io,
    };
}

pub fn sealedAppRequirements() object.Requirements {
    return .{
        .durability = .durable,
        .confidentiality = .app_private,
        .portability = .machine_bound,
        .integrity = .sealed,
        .lifetime = .retained,
        .visibility = .private,
        .access = .explicit_io,
    };
}

pub fn sealedEnvelopeForApp(device: identity.Identity, app_id: identity.Identity, user: identity.Identity, req: object.Requirements, key_material: []const u8) ?object.Envelope {
    const policy = seal.Policy.fromRequirements(req, device, app_id, user);
    return .{
        .kind = .app,
        .owner_index = 0,
        .algorithm = .aes_gcm_256,
        .flags = 0,
        .key_id = preimage.hash("edgerun:zig:v1:app-seal-key", key_material),
        .metadata_hash = policy.id() orelse return null,
    };
}

fn objectRequiresSeal(req: object.Requirements) bool {
    if (req.integrity == .sealed) return true;
    if (req.durability == .memory) return false;
    return req.confidentiality == .app_private or
        req.confidentiality == .user_private or
        req.confidentiality == .user_app_private or
        req.confidentiality == .device_private or
        req.confidentiality == .layered;
}

fn writeAllocationBody(allocation: App.DeclaredAllocation, out: []u8) bool {
    if (!allocation.valid() or out.len < allocation_body_size) return false;
    const memory_amount = std.math.cast(u64, allocation.memory_bytes) orelse return false;
    const storage_amount = std.math.cast(u64, allocation.storage_bytes) orelse return false;
    const slot_amount = std.math.cast(u64, allocation.storage_slots) orelse return false;
    return bytes.store64(out[0..8], memory_amount) and
        bytes.store64(out[8..16], storage_amount) and
        bytes.store64(out[16..24], slot_amount) and
        bytes.store64(out[24..32], allocation.execution_ticks) and
        bytes.store64(out[32..40], allocation.route_handles) and
        bytes.store64(out[40..48], allocation.device_handles) and
        bytes.copy(out[allocation_count_body_size..][0..preimage.hash_size], &allocation.route_handle) and
        bytes.copy(out[allocation_count_body_size + preimage.hash_size ..][0..identity.id_size], &allocation.device_handle.bytes);
}

fn readAllocationBody(in: []const u8) ?App.DeclaredAllocation {
    if (in.len < allocation_body_size) return null;
    var route_handle: preimage.Hash = undefined;
    var device_handle_bytes: [identity.id_size]u8 = undefined;
    _ = bytes.copy(&route_handle, in[allocation_count_body_size..][0..preimage.hash_size]);
    _ = bytes.copy(&device_handle_bytes, in[allocation_count_body_size + preimage.hash_size ..][0..identity.id_size]);
    const allocation = App.DeclaredAllocation{
        .memory_bytes = std.math.cast(usize, bytes.load64(in[0..8]) orelse return null) orelse return null,
        .storage_bytes = std.math.cast(usize, bytes.load64(in[8..16]) orelse return null) orelse return null,
        .storage_slots = std.math.cast(usize, bytes.load64(in[16..24]) orelse return null) orelse return null,
        .execution_ticks = bytes.load64(in[24..32]) orelse return null,
        .route_handles = bytes.load64(in[32..40]) orelse return null,
        .device_handles = bytes.load64(in[40..48]) orelse return null,
        .route_handle = route_handle,
        .device_handle = .{ .bytes = device_handle_bytes },
    };
    return if (allocation.valid()) allocation else null;
}

fn mapObjectError(err: object.Error) ReceiptError {
    return switch (err) {
        error.BadArgument => error.BadArgument,
        error.Corrupt => error.Corrupt,
        error.NoSpace => error.NoSpace,
        error.Unsupported => error.Unsupported,
    };
}

fn mapResolverError(err: ui_resolver.Error) App.UiError {
    return switch (err) {
        error.Corrupt => error.Corrupt,
        error.MissingObject => error.MissingObject,
        error.NoSpace => error.NoSpace,
        error.ResolutionBudgetExceeded => error.ResolutionBudgetExceeded,
        error.UnsupportedComponent => error.UnsupportedComponent,
        error.ComponentBudgetExceeded => error.ComponentBudgetExceeded,
        error.ChildMismatch => error.ChildMismatch,
    };
}

fn mapComponentError(err: ui_components.Error) App.UiError {
    return switch (err) {
        error.Corrupt => error.Corrupt,
        error.UnsupportedComponent => error.UnsupportedComponent,
        error.ComponentBudgetExceeded => error.ComponentBudgetExceeded,
        error.ChildMismatch => error.ChildMismatch,
    };
}

fn sharedMemoryId(owner: identity.Id, offset: usize, len: usize, label: []const u8, epoch: clock.Stamp) ?preimage.Hash {
    const offset_amount = std.math.cast(u64, offset) orelse return null;
    const len_amount = std.math.cast(u64, len) orelse return null;
    const label_hash = preimage.hash("edgerun:zig:v1:shared-memory-label", label);
    var raw: [identity.id_size + preimage.hash_size + 16 + preimage.epoch_size]u8 = undefined;
    var writer = preimage.Writer.init(&raw);
    if (!writer.id(owner) or
        !writer.hash(label_hash) or
        !writer.writeU64(offset_amount) or
        !writer.writeU64(len_amount) or
        !writer.epoch(epoch))
    {
        return null;
    }
    return preimage.hash("edgerun:zig:v1:shared-memory-slice", writer.written());
}

fn hashMaterial(material: []const u8) preimage.Hash {
    return preimage.hash("edgerun:zig:v1:test-material", material);
}

test "manifest spawn transfers declared memory and storage to child" {
    var memory_bytes: [64]u8 = undefined;
    var storage_bytes: [128]u8 = undefined;
    var slots: [4]store.Blob = undefined;
    var manifest_raw: [object.header_size + object.owner_size + App.manifest_body_size]u8 = undefined;

    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const user_id = identity.Identity.init(.user, identity.Source.prepare(.hash, &preimage.rawHash("user")).?, epoch).?;
    const device_id = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("device")).?, epoch).?;
    const allocator_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("allocator app")).?, epoch).?;
    const parent_source = identity.Source.prepare(.hash, &preimage.rawHash("parent app")).?;
    const child_source = identity.Source.prepare(.hash, &preimage.rawHash("child app")).?;
    const parent_id = identity.Identity.init(.app, parent_source, epoch).?;
    const child_id = identity.Identity.init(.app, child_source, epoch).?;

    var parent = App.initAllocated(
        parent_id,
        BoundedArena.init(.{ .base = &memory_bytes }),
        store.Store.init(.{ .base = &storage_bytes }, &slots),
        .{
            .memory_bytes = memory_bytes.len,
            .storage_bytes = storage_bytes.len,
            .storage_slots = slots.len,
            .execution_ticks = 2,
        },
    ).?;

    const authorization = intent.admit(
        user_id,
        device_id,
        allocator_id,
        child_id,
        .spawn_app,
        .delegates_resources,
        epoch,
        intent.requestId("spawn child app").?,
    ).?;
    const manifest = App.Manifest{
        .code_hash = preimage.hash("edgerun:zig:v1:test-code", "bounded child"),
        .allocation = .{
            .memory_bytes = 16,
            .storage_bytes = 32,
            .storage_slots = 2,
        },
    };
    const manifest_canonical = try App.writeManifestObject(child_id, manifest, epoch, &manifest_raw);
    var spawned = try parent.spawnManifest(allocator_id, child_id, epoch, authorization, manifest_canonical);
    var child = spawned.app;
    try std.testing.expectEqual(@as(usize, 48), parent.memory.remaining());
    try std.testing.expectEqual(@as(usize, 96), parent.storage.data.len());
    try std.testing.expectEqual(@as(usize, 2), parent.storage.slotCapacity());
    try std.testing.expectEqual(@as(usize, 16), child.memory.remaining());
    try std.testing.expectEqual(@as(usize, 32), child.storage.data.len());
    try std.testing.expectEqual(@as(usize, 2), child.storage.slotCapacity());

    const child_allocator = child.memory.allocator();
    _ = try child_allocator.alloc(u8, 8);
    const child_hash = child.storage.put("child state").?;
    try std.testing.expectEqual(@as(usize, 48), parent.memory.remaining());
    const oversized_manifest = App.Manifest{
        .code_hash = preimage.hash("edgerun:zig:v1:test-code", "oversized child"),
        .allocation = .{
            .memory_bytes = 56,
            .storage_bytes = 16,
            .storage_slots = 1,
        },
    };
    const oversized_canonical = try App.writeManifestObject(child_id, oversized_manifest, epoch, &manifest_raw);
    try std.testing.expectError(error.NoMemory, parent.spawnManifest(allocator_id, child_id, epoch, authorization, oversized_canonical));
    try std.testing.expect(spawned.receipt.valid());
    try std.testing.expectEqual(@as(u64, 32), spawned.receipt.storage_bytes.amount);

    const reclaimed = try parent.reclaimChild(&child, spawned.receipt, epoch);
    try std.testing.expect(reclaimed.valid());
    try std.testing.expect(bytes.nonzero(&reclaimed.id().?));
    try std.testing.expectEqual(@as(usize, 64), parent.memory.remaining());
    try std.testing.expectEqual(@as(usize, 128), parent.storage.data.len());
    try std.testing.expectEqual(@as(usize, 4), parent.storage.slotCapacity());
    try std.testing.expectEqual(@as(usize, 0), child.memory.remaining());
    try std.testing.expect(child.storage.get(child_hash) == null);
}

test "declared allocation bounds app child work receipts and clean reclaim" {
    const parent_memory_bytes = 128;
    const parent_storage_bytes = 2048;
    const parent_storage_slots = 8;
    const parent_execution_ticks = 16;
    const parent_route_handles = 1;
    const parent_device_handles = 1;
    const child_memory_bytes = 32;
    const child_storage_bytes = 1536;
    const child_storage_slots = 4;
    const child_execution_ticks = 8;
    const child_route_handles = 1;
    const child_device_handles = 1;
    const grandchild_memory_bytes = 8;
    const grandchild_storage_bytes = 1024;
    const grandchild_storage_slots = 2;
    const grandchild_execution_ticks = 4;
    const grandchild_route_handles = 1;
    const grandchild_device_handles = 1;
    const child_private_bytes = 12;

    var memory_bytes: [parent_memory_bytes]u8 = undefined;
    var storage_bytes: [parent_storage_bytes]u8 = undefined;
    var slots: [parent_storage_slots]store.Blob = undefined;
    var oversized_storage: [parent_storage_bytes]u8 = [_]u8{'x'} ** parent_storage_bytes;
    var child_manifest_raw: [object.header_size + object.owner_size + App.manifest_body_size]u8 = undefined;
    var grandchild_manifest_raw: [object.header_size + object.owner_size + App.manifest_body_size]u8 = undefined;
    var work_output_raw: [object.header_size + object.owner_size + object.envelope_size + 20]u8 = undefined;
    var work_receipt_raw: [object.header_size + work_receipt_body_size]u8 = undefined;
    var work_receipt_body: [work_receipt_body_size]u8 = undefined;

    const keeper = clock.KeeperId{ .bytes = [_]u8{7} ++ [_]u8{0} ** 31 };
    var local_clock = clock.Clock.init(keeper, .{}) orelse return error.SkipZigTest;
    const start = local_clock.now;
    const user_id = identity.Identity.init(.user, identity.Source.prepare(.hash, &preimage.rawHash("declared user")).?, start).?;
    const device_id = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("declared device")).?, start).?;
    const parent_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("declared parent")).?, start).?;
    const child_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("declared child")).?, start).?;
    const grandchild_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("declared grandchild")).?, start).?;
    const great_grandchild_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("declared great grandchild")).?, start).?;
    const route_admission = intent.admit(
        user_id,
        device_id,
        child_id,
        grandchild_id,
        .sync_data,
        .exports_data,
        start,
        intent.requestId("declared route use").?,
    ).?;
    const route = relay.Route.init(route_admission, child_id, grandchild_id, .sync_data, .exports_data, hashMaterial("declared route policy")).?;
    const route_id = route.id().?;
    const wrong_device_id = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("wrong declared device")).?, start).?;

    const parent_allocation = App.DeclaredAllocation{
        .memory_bytes = parent_memory_bytes,
        .storage_bytes = parent_storage_bytes,
        .storage_slots = parent_storage_slots,
        .execution_ticks = parent_execution_ticks,
        .route_handles = parent_route_handles,
        .device_handles = parent_device_handles,
        .route_handle = route_id,
        .device_handle = device_id.id,
    };
    var parent = App.initAllocated(
        parent_id,
        BoundedArena.init(.{ .base = &memory_bytes }),
        store.Store.init(.{ .base = &storage_bytes }, &slots),
        parent_allocation,
    ).?;

    const child_allocation = App.DeclaredAllocation{
        .memory_bytes = child_memory_bytes,
        .storage_bytes = child_storage_bytes,
        .storage_slots = child_storage_slots,
        .execution_ticks = child_execution_ticks,
        .route_handles = child_route_handles,
        .device_handles = child_device_handles,
        .route_handle = route_id,
        .device_handle = device_id.id,
    };
    const child_manifest = App.Manifest{
        .code_hash = preimage.hash("edgerun:zig:v1:test-code", "declared child code"),
        .allocation = child_allocation,
        .flags = App.manifest_flag_child_spawn,
    };
    const child_manifest_canonical = try App.writeManifestObject(child_id, child_manifest, start, &child_manifest_raw);
    const child_manifest_id = object.Header.id(child_manifest_canonical);
    try std.testing.expectEqual(child_manifest.allocation, App.Manifest.fromObject(child_manifest_canonical).?.allocation);
    const child_authorization = intent.admit(
        user_id,
        device_id,
        parent_id,
        child_id,
        .spawn_app,
        .delegates_resources,
        start,
        intent.requestId("declared child spawn").?,
    ).?;

    const spawned_child = try parent.spawnManifest(parent_id, child_id, start, child_authorization, child_manifest_canonical);
    var child = spawned_child.app;
    try std.testing.expectEqual(@as(usize, parent_memory_bytes - child_memory_bytes), parent.memory.remaining());
    try std.testing.expectEqual(@as(usize, child_memory_bytes), child.memory.remaining());
    try std.testing.expectEqual(@as(usize, child_storage_bytes), child.storage.data.len());
    try std.testing.expectEqual(@as(usize, child_storage_slots), child.storage.slotCapacity());
    try std.testing.expectEqual(@as(u64, parent_execution_ticks - child_execution_ticks), parent.execution_ticks);
    try std.testing.expectEqual(@as(u64, child_execution_ticks), child.execution_ticks);
    try std.testing.expectEqual(@as(u64, child_route_handles), child.route_handles);
    try std.testing.expectEqual(@as(u64, child_device_handles), child.device_handles);

    const child_allocator = child.memory.allocator();
    _ = try child_allocator.alloc(u8, child_private_bytes);
    try std.testing.expectError(error.OutOfMemory, child_allocator.alloc(u8, child_memory_bytes));
    try std.testing.expect(child.storage.put(&oversized_storage) == null);
    try std.testing.expect(!child.consumeExecution(child_execution_ticks + 1));
    try std.testing.expect(child.useDevice(device_id));
    try std.testing.expect(!child.useDevice(wrong_device_id));

    const grandchild_authorization = intent.admit(
        user_id,
        device_id,
        child_id,
        grandchild_id,
        .spawn_app,
        .delegates_resources,
        start,
        intent.requestId("declared grandchild spawn").?,
    ).?;
    const impossible_grandchild = App.DeclaredAllocation{
        .memory_bytes = child_memory_bytes,
        .storage_bytes = grandchild_storage_bytes,
        .storage_slots = grandchild_storage_slots,
        .execution_ticks = grandchild_execution_ticks,
        .route_handles = grandchild_route_handles,
        .device_handles = grandchild_device_handles,
        .route_handle = route_id,
        .device_handle = device_id.id,
    };
    try std.testing.expectError(error.NoMemory, child.spawnDeclared(child_id, grandchild_id, start, grandchild_authorization, impossible_grandchild));

    const impossible_route_grandchild = App.DeclaredAllocation{
        .memory_bytes = grandchild_memory_bytes,
        .storage_bytes = grandchild_storage_bytes,
        .storage_slots = grandchild_storage_slots,
        .execution_ticks = grandchild_execution_ticks,
        .route_handles = child_route_handles + 1,
        .device_handles = grandchild_device_handles,
        .route_handle = route_id,
        .device_handle = device_id.id,
    };
    try std.testing.expectError(error.NoRoute, child.spawnDeclared(child_id, grandchild_id, start, grandchild_authorization, impossible_route_grandchild));

    const grandchild_allocation = App.DeclaredAllocation{
        .memory_bytes = grandchild_memory_bytes,
        .storage_bytes = grandchild_storage_bytes,
        .storage_slots = grandchild_storage_slots,
        .execution_ticks = grandchild_execution_ticks,
        .route_handles = grandchild_route_handles,
        .device_handles = grandchild_device_handles,
        .route_handle = route_id,
        .device_handle = device_id.id,
    };
    const grandchild_manifest = App.Manifest{
        .code_hash = preimage.hash("edgerun:zig:v1:test-code", "declared grandchild code"),
        .allocation = grandchild_allocation,
    };
    const grandchild_manifest_canonical = try App.writeManifestObject(grandchild_id, grandchild_manifest, start, &grandchild_manifest_raw);
    const grandchild_manifest_id = object.Header.id(grandchild_manifest_canonical);
    const spawned_grandchild = try child.spawnManifest(child_id, grandchild_id, start, grandchild_authorization, grandchild_manifest_canonical);
    var grandchild = spawned_grandchild.app;
    try std.testing.expectEqual(@as(usize, grandchild_memory_bytes), grandchild.memory.remaining());
    try std.testing.expectEqual(@as(usize, grandchild_storage_bytes), grandchild.storage.data.len());
    try std.testing.expectEqual(@as(u64, child_execution_ticks - grandchild_execution_ticks), child.execution_ticks);
    try std.testing.expectEqual(@as(u64, 0), child.route_handles);
    try std.testing.expectEqual(@as(u64, 0), child.device_handles);
    try std.testing.expect(!child.useDevice(device_id));
    try std.testing.expect(grandchild.useDevice(device_id));
    try std.testing.expect(!grandchild.useDevice(wrong_device_id));
    const great_grandchild_authorization = intent.admit(
        user_id,
        device_id,
        grandchild_id,
        great_grandchild_id,
        .spawn_app,
        .delegates_resources,
        start,
        intent.requestId("blocked great grandchild spawn").?,
    ).?;
    try std.testing.expectError(error.Unauthorized, grandchild.spawnDeclared(grandchild_id, great_grandchild_id, start, great_grandchild_authorization, grandchild_allocation));

    try std.testing.expect(child.createRelayEnvelope(route, 1, hashMaterial("route object"), hashMaterial("route payload")) == null);
    try std.testing.expect(!grandchild.consumeExecution(grandchild_execution_ticks + 1));

    const input_hash = preimage.hash("edgerun:zig:v1:test-input", "declared work input");
    const output_owner = object.Owner{
        .kind = .app,
        .node_id = grandchild.id.id.bytes,
    };
    const output_req = sealedAppRequirements();
    const output_envelope = sealedEnvelopeForApp(device_id, grandchild_id, user_id, output_req, "declared work output key").?;
    const output_canonical = try (object.NodeWriter{ .out = &work_output_raw }).bytesNodeOwned(output_req, start, &.{output_owner}, &.{output_envelope}, "declared work output");
    const output_hash = grandchild.putSealedObject(device_id, user_id, output_canonical).?;
    _ = local_clock.advanceDefault() orelse return error.SkipZigTest;
    const end = local_clock.now;
    const work = grandchild.completeWork(child.id.id, input_hash, output_hash, grandchild_manifest_id, start, end, grandchild_allocation, spawned_grandchild.receipt).?;
    try std.testing.expect(work.valid());
    try std.testing.expect(bytes.nonzero(&work.id().?));
    try std.testing.expect(bytes.eql(&work.manifest, &grandchild_manifest_id));
    try std.testing.expect(bytes.nonzero(&child_manifest_id));
    try std.testing.expect(work.clock_start.order(work.clock_end) < 0);
    const work_receipt_object_id = try grandchild.putWorkReceipt(work, end, &work_receipt_raw);
    try std.testing.expect(bytes.eql(&work_receipt_object_id, &object.Header.id(&work_receipt_raw)));
    const stored_work_receipt = grandchild.storage.getReceipt(grandchild.id.id, work_receipt_object_id).?;
    try std.testing.expectEqual(object.Kind.receipt, stored_work_receipt.header.kind);
    try std.testing.expectEqual(workReceiptRequirements(), stored_work_receipt.header.requirements);
    try std.testing.expectEqualSlices(u8, work.encodeBody(&work_receipt_body).?, stored_work_receipt.body);
    var wrong_route_receipt = spawned_grandchild.receipt;
    wrong_route_receipt.route_handle = hashMaterial("wrong receipt route");
    try std.testing.expect(grandchild.completeWork(child.id.id, input_hash, output_hash, grandchild_manifest_id, start, end, grandchild_allocation, wrong_route_receipt) == null);

    try std.testing.expectError(error.Corrupt, parent.reclaimChild(&child, spawned_child.receipt, end));
    try std.testing.expectError(error.Corrupt, child.reclaimChild(&grandchild, wrong_route_receipt, end));
    const grandchild_reclaim = try child.reclaimChild(&grandchild, spawned_grandchild.receipt, end);
    try std.testing.expect(grandchild_reclaim.valid());
    try std.testing.expectEqual(@as(usize, 0), grandchild.memory.remaining());
    try std.testing.expect(grandchild.storage.getObject(grandchild.id.id, output_hash) == null);
    try std.testing.expectEqual(@as(u64, child_execution_ticks), child.execution_ticks);
    try std.testing.expectEqual(@as(u64, child_route_handles), child.route_handles);
    try std.testing.expectEqual(@as(u64, child_device_handles), child.device_handles);

    const child_reclaim = try parent.reclaimChild(&child, spawned_child.receipt, end);
    try std.testing.expect(child_reclaim.valid());
    try std.testing.expectEqual(@as(usize, parent_memory_bytes), parent.memory.remaining());
    try std.testing.expectEqual(@as(usize, parent_storage_bytes), parent.storage.data.len());
    try std.testing.expectEqual(@as(usize, parent_storage_slots), parent.storage.slotCapacity());
    try std.testing.expectEqual(@as(u64, parent_execution_ticks), parent.execution_ticks);
    try std.testing.expectEqual(@as(u64, parent_route_handles), parent.route_handles);
    try std.testing.expectEqual(@as(u64, parent_device_handles), parent.device_handles);
    try std.testing.expectEqual(@as(usize, 0), child.memory.remaining());
}

test "app creates its store from its host-owned memory slice" {
    var host_memory: [1024]u8 = undefined;

    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const app_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("app")).?, epoch).?;
    var app = App.initFromHostSlice(
        app_id,
        BoundedArena.init(.{ .base = &host_memory }),
        64,
        4,
    ).?;

    const hash = app.storage.putOwned(.blob, app.id.id, "state").?;
    try std.testing.expectEqualStrings("state", app.storage.getOwned(.blob, app.id.id, hash).?);
    try std.testing.expect(app.memory.remaining() < 960);
}

test "app storage requires seal envelope for private durable objects" {
    var host_memory: [2048]u8 = undefined;
    var unsealed_raw: [object.header_size + object.owner_size + 5]u8 = undefined;
    var sealed_raw: [object.header_size + object.owner_size + object.envelope_size + 5]u8 = undefined;
    var wrong_seal_raw: [object.header_size + object.owner_size + object.envelope_size + 5]u8 = undefined;

    const keeper = clock.KeeperId{ .bytes = [_]u8{8} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const user_id = identity.Identity.init(.user, identity.Source.prepare(.hash, &preimage.rawHash("seal user")).?, epoch).?;
    const device_id = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("seal device")).?, epoch).?;
    const app_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("seal app")).?, epoch).?;
    const wrong_device_id = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("wrong seal device")).?, epoch).?;
    var app = App.initFromHostSlice(app_id, BoundedArena.init(.{ .base = &host_memory }), 512, 4).?;

    const req = sealedAppRequirements();
    const owner = object.Owner{
        .kind = .app,
        .node_id = app_id.id.bytes,
    };
    const unsealed = try (object.NodeWriter{ .out = &unsealed_raw }).bytesNodeOwned(req, epoch, &.{owner}, &.{}, "state");
    try std.testing.expect(app.putSealedObject(device_id, user_id, unsealed) == null);

    const wrong_envelope = sealedEnvelopeForApp(wrong_device_id, app_id, user_id, req, "state key").?;
    const wrong_sealed = try (object.NodeWriter{ .out = &wrong_seal_raw }).bytesNodeOwned(req, epoch, &.{owner}, &.{wrong_envelope}, "state");
    try std.testing.expect(app.putSealedObject(device_id, user_id, wrong_sealed) == null);

    const envelope = sealedEnvelopeForApp(device_id, app_id, user_id, req, "state key").?;
    const sealed_object = try (object.NodeWriter{ .out = &sealed_raw }).bytesNodeOwned(req, epoch, &.{owner}, &.{envelope}, "state");
    const object_id = app.putSealedObject(device_id, user_id, sealed_object).?;
    const stored = app.storage.getObject(app.id.id, object_id).?;
    try std.testing.expectEqual(object.Integrity.sealed, stored.header.requirements.integrity);
    try std.testing.expectEqual(object.EnvelopeKind.app, (try stored.envelopeAt(0)).kind);
}

test "app shares owned memory read only for direct ui updates" {
    var producer_memory: [512]u8 = undefined;
    var ui_memory: [256]u8 = undefined;

    const keeper = clock.KeeperId{ .bytes = [_]u8{6} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const user_id = identity.Identity.init(.user, identity.Source.prepare(.hash, &preimage.rawHash("share user")).?, epoch).?;
    const device_id = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("share device")).?, epoch).?;
    const producer_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("producer app")).?, epoch).?;
    const ui_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("ui app reader")).?, epoch).?;
    var producer = App.initFromHostSlice(producer_id, BoundedArena.init(.{ .base = &producer_memory }), 64, 2).?;
    _ = App.initFromHostSlice(ui_id, BoundedArena.init(.{ .base = &ui_memory }), 64, 2).?;

    var shared = try producer.reserveSharedMemory(16, "ui-state", epoch);
    _ = bytes.copy(shared.bytes[0..5], "ready");
    const authorization = intent.admit(
        user_id,
        device_id,
        producer_id,
        ui_id,
        .grant_resource,
        .exports_data,
        epoch,
        intent.requestId("share ui state").?,
    ).?;

    const view = try producer.shareMemoryReadOnly(ui_id.id, shared, epoch, authorization);
    try std.testing.expect(view.valid());
    try std.testing.expectEqual(grant.Resource.read_only_memory, view.receipt.memory.resource);
    try std.testing.expectEqualStrings("ready", view.bytes[0..5]);

    _ = bytes.copy(shared.bytes[0..5], "paint");
    try std.testing.expectEqualStrings("paint", view.bytes[0..5]);
}

test "app publishes canonical ui component and renders from object storage" {
    var host_memory: [4096]u8 = undefined;
    const keeper = clock.KeeperId{ .bytes = [_]u8{4} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const app_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("ui app")).?, epoch).?;
    var app = App.initFromHostSlice(app_id, BoundedArena.init(.{ .base = &host_memory }), 1024, 8).?;

    var codec_raw: [256]u8 = undefined;
    var object_raw: [object.header_size + 256]u8 = undefined;
    var resolved: [1]object.View = undefined;
    var component_scratch: [4]ui_components.Component = undefined;
    var node_scratch: [4]ui.Node = undefined;
    const scratch = App.UiScratch{
        .codec = &codec_raw,
        .object = &object_raw,
        .resolved = &resolved,
        .components = &component_scratch,
        .nodes = &node_scratch,
    };

    const published = try app.publishUiComponent(.{ .button = .{ .id = 42, .label = "Open" } }, epoch, scratch);
    try std.testing.expect(published.valid());
    try std.testing.expect(bytes.nonzero(&published.id().?));

    const stored = app.storage.getObject(app.id.id, published.object_id).?;
    try std.testing.expectEqual(object.Kind.bytes, stored.header.kind);
    try std.testing.expectEqual(object.Confidentiality.app_private, stored.header.requirements.confidentiality);
    try std.testing.expectEqual(object.Visibility.app_namespace, stored.header.requirements.visibility);

    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try app.renderPublishedUi(published, scratch, &scene, .{ .x = 0, .y = 0, .w = 160, .h = 64 }, .{});
    try std.testing.expect(scene.commandCount() > 0);
}

test "app publishes stack ui as one canonical render object" {
    var host_memory: [8192]u8 = undefined;
    const keeper = clock.KeeperId{ .bytes = [_]u8{5} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const app_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("stack ui app")).?, epoch).?;
    var app = App.initFromHostSlice(app_id, BoundedArena.init(.{ .base = &host_memory }), 2048, 8).?;

    const children = [_]ui_components.Component{
        .{ .text = .{ .value = "Objects" } },
        .{ .row_item = .{ .id = 7, .title = "Storage", .detail = "canonical" } },
        .{ .button = .{ .id = 8, .label = "Render" } },
    };
    const stack = ui_components.Stack{ .axis = .column, .gap = 6, .padding = 8, .children = &children };

    var codec_raw: [512]u8 = undefined;
    var object_raw: [object.header_size + 512]u8 = undefined;
    var resolved: [1]object.View = undefined;
    var component_scratch: [4]ui_components.Component = undefined;
    var node_scratch: [4]ui.Node = undefined;
    const scratch = App.UiScratch{
        .codec = &codec_raw,
        .object = &object_raw,
        .resolved = &resolved,
        .components = &component_scratch,
        .nodes = &node_scratch,
    };

    const published = try app.publishUiStack(stack, epoch, scratch);
    var commands: [32]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try app.renderStoredUi(published.object_id, scratch, &scene, .{ .x = 0, .y = 0, .w = 320, .h = 200 }, .{});
    try std.testing.expect(scene.commandCount() >= 6);
}

test "apps exchange identity routed envelopes through relay boundary" {
    var source_memory: [256]u8 = undefined;
    var target_memory: [256]u8 = undefined;
    var relay_memory: [128]u8 = undefined;

    const keeper = clock.KeeperId{ .bytes = [_]u8{3} ++ [_]u8{0} ** 31 };
    const now = clock.Stamp{ .keeper = keeper, .tick = 3 };
    const user = identity.Identity.init(.user, identity.Source.prepare(.hash, &preimage.rawHash("routing user")).?, now).?;
    const device = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("routing device")).?, now).?;
    const source_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("routing source app")).?, now).?;
    const target_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("routing target app")).?, now).?;
    const relay_id = identity.Identity.init(.relay, identity.Source.prepare(.hash, &preimage.rawHash("routing relay app")).?, now).?;

    var source = App.initFromHostSlice(source_id, BoundedArena.init(.{ .base = &source_memory }), 64, 2).?;
    var target = App.initFromHostSlice(target_id, BoundedArena.init(.{ .base = &target_memory }), 64, 2).?;
    _ = App.initFromHostSlice(relay_id, BoundedArena.init(.{ .base = &relay_memory }), 32, 1).?;

    const admission = intent.admitWindow(
        user,
        device,
        source_id,
        target_id,
        .sync_data,
        .exports_data,
        now,
        now,
        .{ .keeper = keeper, .tick = 4 },
        intent.requestId("identity routed app message").?,
    ).?;
    var route = relay.Route.init(admission, source_id, target_id, .sync_data, .exports_data, hashMaterial("app route policy")).?;
    try std.testing.expect(route.appendRelay(relay_id));
    const route_id = route.id().?;
    source.route_handles = 1;
    target.route_handles = 1;
    source.route_handle = route_id;
    target.route_handle = route_id;

    const envelope = source.createRelayEnvelope(route, 1, hashMaterial("message object"), hashMaterial("sealed to target")).?;
    var public_relay = relay.RelayApp.init(relay_id).?;
    const transit = try public_relay.forward(route, envelope, now);
    try std.testing.expect(transit.valid());

    const received = try target.receiveRelayEnvelope(route, envelope, now);
    try std.testing.expect(received.valid());
    try std.testing.expect(bytes.nonzero(&received.id().?));
}
