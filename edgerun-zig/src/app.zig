const std = @import("std");
const BoundedArena = @import("arena.zig").BoundedArena;
const bounded = @import("bounded.zig");
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
const work_receipt_hash_field_count = 6;
const work_receipt_epoch_field_count = 2;
const work_receipt_body_size = identity.id_size * work_receipt_id_field_count +
    preimage.hash_size * work_receipt_hash_field_count +
    preimage.epoch_size * work_receipt_epoch_field_count +
    @sizeOf(u64);
pub const work_receipt_object_size = object.header_size + work_receipt_body_size;
const admitted_authorization_capacity = 16;
const accepted_work_capacity = 8;
const spawned_child_capacity = 8;

pub const SpawnError = error{
    BadAllocation,
    NoExecution,
    NoMemory,
    NoStorage,
    NoReceipt,
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

pub const SigningError = ReceiptError || error{
    Unauthorized,
};

pub const AdmissionError = error{
    BadArgument,
    NoSpace,
};

pub const ReclaimError = error{
    Corrupt,
    Unauthorized,
};

pub const App = struct {
    id: identity.Identity,
    state: State,

    const AcceptedWork = struct {
        child: identity.Id,
        draft: preimage.Hash,
        clock_end: clock.Stamp,

        fn valid(self: AcceptedWork) bool {
            return self.child.valid() and bytes.nonzero(&self.draft) and self.clock_end.valid();
        }
    };

    const SpawnRecord = struct {
        child: identity.Id,
        receipt: grant.SpawnReceipt,
        receipt_id: preimage.Hash,
        manifest: preimage.Hash,
        code_hash: preimage.Hash,
        allocation: DeclaredAllocation,
        clock_start: clock.Stamp,
        active: bool,

        fn valid(self: SpawnRecord) bool {
            const allocation_id = self.allocation.id() orelse return false;
            _ = allocation_id;
            return self.child.valid() and
                self.receipt.valid() and
                bytes.nonzero(&self.receipt_id) and
                self.receipt.child.eql(self.child) and
                self.clock_start.valid();
        }

        fn matchesReceipt(self: SpawnRecord, child: identity.Id, receipt: grant.SpawnReceipt) bool {
            const receipt_id = receipt.id() orelse return false;
            return self.active and
                self.child.eql(child) and
                bytes.eql(&self.receipt_id, &receipt_id);
        }
    };

    const AdmissionRecord = struct {
        receipt: preimage.Hash,
        actor: identity.Id,
        subject: identity.Id,
        action: intent.Action,
        consequence: intent.Consequence,
        not_after: clock.Stamp,

        fn valid(self: AdmissionRecord) bool {
            return bytes.nonzero(&self.receipt) and
                self.actor.valid() and
                self.subject.valid() and
                self.not_after.valid();
        }

        fn matches(self: AdmissionRecord, authorization: intent.Receipt, epoch: clock.Stamp, actor: identity.Id, subject: identity.Id, action: intent.Action, consequence: intent.Consequence) bool {
            const receipt_id = authorization.id() orelse return false;
            return self.valid() and
                bytes.eql(&self.receipt, &receipt_id) and
                self.actor.eql(actor) and
                self.subject.eql(subject) and
                self.action == action and
                self.consequence == consequence and
                epoch.sameKeeper(self.not_after) and
                epoch.order(self.not_after) <= 0;
        }
    };

    const AdmissionCapability = struct {
        app: identity.Id,
        receipt: preimage.Hash,

        fn permits(self: AdmissionCapability, app: identity.Id, authorization: intent.Receipt) bool {
            const receipt_id = authorization.id() orelse return false;
            return self.app.eql(app) and bytes.eql(&self.receipt, &receipt_id);
        }
    };

    const State = struct {
        memory: BoundedArena,
        storage: store.Store,
        execution_ticks: u64 = 0,
        route_handles: u64 = 0,
        device_handles: u64 = 0,
        route_handle: preimage.Hash = [_]u8{0} ** preimage.hash_size,
        device_handle: identity.Id = .{ .bytes = [_]u8{0} ** identity.id_size },
        can_spawn_children: bool = true,
        admissions: bounded.FixedList(AdmissionRecord, admitted_authorization_capacity) = .{},
        accepted_work: bounded.FixedList(AcceptedWork, accepted_work_capacity) = .{},
        spawned_children: bounded.FixedList(SpawnRecord, spawned_child_capacity) = .{},
    };

    pub const ExecutionAllocation = struct {
        memory: []u8,
        execution_ticks: *u64,
    };

    pub fn init(id: identity.Identity, memory: BoundedArena, storage: store.Store) App {
        return .{
            .id = id,
            .state = .{
                .memory = memory,
                .storage = storage,
            },
        };
    }

    pub fn initAllocated(id: identity.Identity, memory: BoundedArena, storage: store.Store, allocation: DeclaredAllocation) ?App {
        if (!allocation.valid()) return null;
        return .{
            .id = id,
            .state = .{
                .memory = memory,
                .storage = storage,
                .execution_ticks = allocation.execution_ticks,
                .route_handles = allocation.route_handles,
                .device_handles = allocation.device_handles,
                .route_handle = allocation.route_handle,
                .device_handle = allocation.device_handle,
            },
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

    pub fn memoryRemaining(self: App) usize {
        return self.state.memory.remaining();
    }

    pub fn ownsMemory(self: App, slice: []const u8) bool {
        return self.state.memory.owns(slice);
    }

    pub fn storageDataRemaining(self: App) usize {
        return self.state.storage.data.len();
    }

    pub fn storageSlotCapacity(self: App) usize {
        return self.state.storage.slotCapacity();
    }

    pub fn storageStats(self: App) store.Stats {
        return self.state.storage.stats();
    }

    pub fn executionRemaining(self: App) u64 {
        return self.state.execution_ticks;
    }

    pub fn executionAllocation(self: *App) ExecutionAllocation {
        return .{
            .memory = self.state.memory.owned.base,
            .execution_ticks = &self.state.execution_ticks,
        };
    }

    pub fn routeHandleCount(self: App) u64 {
        return self.state.route_handles;
    }

    pub fn deviceHandleCount(self: App) u64 {
        return self.state.device_handles;
    }

    pub fn storedObject(self: App, object_id: preimage.Hash) ?object.View {
        return self.state.storage.getObject(self.id.id, object_id);
    }

    pub fn storedReceipt(self: App, receipt_id: preimage.Hash) ?object.View {
        return self.state.storage.getReceipt(self.id.id, receipt_id);
    }

    pub fn admissionCapability(self: App, authorization: intent.Receipt) ?AdmissionCapability {
        if (!authorization.valid()) return null;
        return .{
            .app = self.id.id,
            .receipt = authorization.id() orelse return null,
        };
    }

    pub fn admitAuthorization(self: *App, authorization: intent.Receipt, capability: AdmissionCapability) AdmissionError!void {
        if (!authorization.valid()) return error.BadArgument;
        if (!capability.permits(self.id.id, authorization)) return error.BadArgument;
        const receipt_id = authorization.id() orelse return error.BadArgument;
        for (self.state.admissions.slice()) |record| {
            if (!record.valid()) return error.BadArgument;
            if (bytes.eql(&record.receipt, &receipt_id)) return;
        }
        if (self.state.admissions.full()) return error.NoSpace;
        _ = self.state.admissions.append(.{
            .receipt = receipt_id,
            .actor = authorization.intent.actor,
            .subject = authorization.intent.subject,
            .action = authorization.intent.action,
            .consequence = authorization.intent.consequence,
            .not_after = authorization.not_after,
        });
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

        pub fn fromObjectFor(canonical: []const u8, owner: identity.Id) ?Manifest {
            if (!owner.valid()) return null;
            const view = object.View.decode(canonical) catch return null;
            if (view.header.kind != .bytes or view.body.len != manifest_body_size) return null;
            if (view.header.owner_count != 1) return null;
            const object_owner = view.ownerAt(0) catch return null;
            if (object_owner.kind != .app or !bytes.eql(&object_owner.node_id, &owner.bytes)) return null;
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
        app_hash: preimage.Hash,
        manifest: preimage.Hash,
        clock_start: clock.Stamp,
        clock_end: clock.Stamp,
        allocation: DeclaredAllocation,
        execution_used: u64,
        spawn_receipt: grant.SpawnReceipt,

        pub const Info = struct {
            parent: identity.Id,
            app: identity.Id,
            input: preimage.Hash,
            output: preimage.Hash,
            app_hash: preimage.Hash,
            manifest: preimage.Hash,
            clock_start: clock.Stamp,
            clock_end: clock.Stamp,
            allocation_id: preimage.Hash,
            spawn_receipt_id: preimage.Hash,
            execution_used: u64,

            pub fn valid(self: Info) bool {
                return self.parent.valid() and
                    self.app.valid() and
                    bytes.nonzero(&self.input) and
                    bytes.nonzero(&self.output) and
                    bytes.nonzero(&self.app_hash) and
                    bytes.nonzero(&self.manifest) and
                    self.clock_start.valid() and
                    self.clock_end.valid() and
                    self.clock_start.sameKeeper(self.clock_end) and
                    self.clock_start.order(self.clock_end) <= 0 and
                    bytes.nonzero(&self.allocation_id) and
                    bytes.nonzero(&self.spawn_receipt_id);
            }

            pub fn matches(self: Info, receipt: WorkReceipt) bool {
                if (!self.valid() or !receipt.valid()) return false;
                const allocation_id = receipt.allocation.id() orelse return false;
                const spawn_receipt_id = receipt.spawn_receipt.id() orelse return false;
                return self.parent.eql(receipt.parent) and
                    self.app.eql(receipt.app) and
                    bytes.eql(&self.input, &receipt.input) and
                    bytes.eql(&self.output, &receipt.output) and
                    bytes.eql(&self.app_hash, &receipt.app_hash) and
                    bytes.eql(&self.manifest, &receipt.manifest) and
                    self.clock_start.order(receipt.clock_start) == 0 and
                    self.clock_end.order(receipt.clock_end) == 0 and
                    bytes.eql(&self.allocation_id, &allocation_id) and
                    bytes.eql(&self.spawn_receipt_id, &spawn_receipt_id) and
                    self.execution_used == receipt.execution_used;
            }
        };

        pub fn valid(self: WorkReceipt) bool {
            const memory_amount = std.math.cast(u64, self.allocation.memory_bytes) orelse return false;
            const storage_amount = std.math.cast(u64, self.allocation.storage_bytes) orelse return false;
            const slot_amount = std.math.cast(u64, self.allocation.storage_slots) orelse return false;
            return self.parent.valid() and
                self.app.valid() and
                bytes.nonzero(&self.input) and
                bytes.nonzero(&self.output) and
                bytes.nonzero(&self.app_hash) and
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
                self.execution_used <= self.allocation.execution_ticks and
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

        pub fn decodeObject(canonical: []const u8) object.Error!Info {
            const view = try object.View.decode(canonical);
            if (view.header.kind != .receipt) return error.Corrupt;
            if (!std.meta.eql(view.header.requirements, workReceiptRequirements())) return error.Corrupt;
            if (view.body.len != work_receipt_body_size) return error.Corrupt;
            return decodeBody(view.body) orelse error.Corrupt;
        }

        pub fn decodeBody(body: []const u8) ?Info {
            if (body.len != work_receipt_body_size) return null;
            var cursor: usize = 0;
            const info = Info{
                .parent = readWorkReceiptId(body, &cursor) orelse return null,
                .app = readWorkReceiptId(body, &cursor) orelse return null,
                .input = readWorkReceiptHash(body, &cursor) orelse return null,
                .output = readWorkReceiptHash(body, &cursor) orelse return null,
                .app_hash = readWorkReceiptHash(body, &cursor) orelse return null,
                .manifest = readWorkReceiptHash(body, &cursor) orelse return null,
                .clock_start = readWorkReceiptEpoch(body, &cursor) orelse return null,
                .clock_end = readWorkReceiptEpoch(body, &cursor) orelse return null,
                .allocation_id = readWorkReceiptHash(body, &cursor) orelse return null,
                .spawn_receipt_id = readWorkReceiptHash(body, &cursor) orelse return null,
                .execution_used = readWorkReceiptU64(body, &cursor) orelse return null,
            };
            if (cursor != work_receipt_body_size or !info.valid()) return null;
            return info;
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
                !writer.hash(self.app_hash) or
                !writer.hash(self.manifest) or
                !writer.epoch(self.clock_start) or
                !writer.epoch(self.clock_end) or
                !writer.hash(allocation_id) or
                !writer.hash(spawn_id) or
                !writer.writeU64(self.execution_used))
            {
                return null;
            }
            return writer.written();
        }
    };

    pub const WorkReceiptDraftContext = struct {
        child: identity.Identity,
        input: preimage.Hash,
        output: preimage.Hash,
        app_hash: preimage.Hash,
        manifest: preimage.Hash,
        clock_start: clock.Stamp,
        clock_end: clock.Stamp,
        allocation: DeclaredAllocation,
        execution_used: u64,
        spawn_receipt: grant.SpawnReceipt,

        pub fn expected(self: WorkReceiptDraftContext, parent: identity.Identity) ?WorkReceipt {
            const receipt = WorkReceipt{
                .parent = parent.id,
                .app = self.child.id,
                .input = self.input,
                .output = self.output,
                .app_hash = self.app_hash,
                .manifest = self.manifest,
                .clock_start = self.clock_start,
                .clock_end = self.clock_end,
                .allocation = self.allocation,
                .execution_used = self.execution_used,
                .spawn_receipt = self.spawn_receipt,
            };
            if (!receipt.valid()) return null;
            return receipt;
        }
    };

    pub const SigningCapability = struct {
        signer: identity.Identity,
        authorization: intent.Receipt,
        algorithm: object.Algorithm = .ecdsa_p256_sha256,

        pub fn permits(self: SigningCapability, epoch: clock.Stamp, parent: identity.Identity) bool {
            return self.signer.id.eql(parent.id) and
                self.algorithm != .none and
                self.authorization.permitsAt(epoch, parent.id, parent.id, .sign_data, .attests_state);
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
        if (!self.state.can_spawn_children) return error.Unauthorized;
        if (!authorization.permitsAt(epoch, allocator_id.id, child_id.id, .spawn_app, .delegates_resources)) return error.Unauthorized;
        if (!self.hasAdmittedAuthorization(authorization, epoch, allocator_id.id, child_id.id, .spawn_app, .delegates_resources)) return error.Unauthorized;
        if (allocation.execution_ticks > self.state.execution_ticks) return error.NoExecution;
        if (allocation.route_handles > self.state.route_handles) return error.NoRoute;
        if (allocation.device_handles > self.state.device_handles) return error.NoDevice;
        if (allocation.route_handles != 0 and !bytes.eql(&allocation.route_handle, &self.state.route_handle)) return error.NoRoute;
        if (allocation.device_handles != 0 and !allocation.device_handle.eql(self.state.device_handle)) return error.NoDevice;
        const record_slot = try self.freeSpawnRecordSlot();

        const child_memory = self.state.memory.split(allocation.memory_bytes) orelse return error.NoMemory;
        const child_storage = self.state.storage.split(.{
            .data_bytes = allocation.storage_bytes,
            .slot_count = allocation.storage_slots,
        }) orelse return error.NoStorage;
        self.state.execution_ticks -= allocation.execution_ticks;
        self.state.route_handles -= allocation.route_handles;
        self.state.device_handles -= allocation.device_handles;
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
        const receipt_id = receipt.id() orelse return error.BadAllocation;
        self.recordSpawn(record_slot, .{
            .child = child_id.id,
            .receipt = receipt,
            .receipt_id = receipt_id,
            .manifest = [_]u8{0} ** preimage.hash_size,
            .code_hash = [_]u8{0} ** preimage.hash_size,
            .allocation = allocation,
            .clock_start = epoch,
            .active = true,
        });

        return .{
            .app = .{
                .id = child_id,
                .state = .{
                    .memory = child_memory,
                    .storage = child_storage,
                    .execution_ticks = allocation.execution_ticks,
                    .route_handles = allocation.route_handles,
                    .device_handles = allocation.device_handles,
                    .route_handle = allocation.route_handle,
                    .device_handle = allocation.device_handle,
                },
            },
            .receipt = receipt,
        };
    }

    pub fn spawnManifest(self: *App, allocator_id: identity.Identity, child_id: identity.Identity, epoch: clock.Stamp, authorization: intent.Receipt, manifest_canonical: []const u8) SpawnError!Spawned {
        const manifest = Manifest.fromObjectFor(manifest_canonical, child_id.id) orelse return error.BadAllocation;
        const manifest_id = object.Header.id(manifest_canonical);
        var spawned = try self.spawnDeclared(allocator_id, child_id, epoch, authorization, manifest.allocation);
        spawned.app.state.can_spawn_children = manifest.childSpawnAllowed();
        self.bindSpawnManifest(child_id.id, spawned.receipt, manifest_id, manifest.code_hash) catch return error.NoReceipt;
        return spawned;
    }

    pub fn completeWork(self: App, parent: identity.Id, input: preimage.Hash, output: preimage.Hash, app_hash: preimage.Hash, manifest: preimage.Hash, clock_start: clock.Stamp, clock_end: clock.Stamp, allocation: DeclaredAllocation, spawn_receipt: grant.SpawnReceipt) ?WorkReceipt {
        if (self.state.execution_ticks > allocation.execution_ticks) return null;
        const receipt = WorkReceipt{
            .parent = parent,
            .app = self.id.id,
            .input = input,
            .output = output,
            .app_hash = app_hash,
            .manifest = manifest,
            .clock_start = clock_start,
            .clock_end = clock_end,
            .allocation = allocation,
            .execution_used = allocation.execution_ticks - self.state.execution_ticks,
            .spawn_receipt = spawn_receipt,
        };
        if (!receipt.valid()) return null;
        return receipt;
    }

    pub fn putWorkReceipt(self: *App, receipt: WorkReceipt, epoch: clock.Stamp, out: []u8) ReceiptError!preimage.Hash {
        if (!receipt.valid() or !receipt.app.eql(self.id.id)) return error.BadArgument;
        const canonical = receipt.writeObject(epoch, out) catch |err| return mapObjectError(err);
        return self.state.storage.putReceipt(self.id.id, canonical) orelse error.NoSpace;
    }

    pub fn signWorkReceiptDraft(self: *App, draft_canonical: []const u8, context: WorkReceiptDraftContext, epoch: clock.Stamp, capability: ?SigningCapability, out: []u8) SigningError![]u8 {
        const cap = capability orelse return error.Unauthorized;
        if (!cap.permits(epoch, self.id)) return error.Unauthorized;
        if (!self.hasAdmittedAuthorization(cap.authorization, epoch, self.id.id, self.id.id, .sign_data, .attests_state)) return error.Unauthorized;
        const info = WorkReceipt.decodeObject(draft_canonical) catch |err| return mapObjectError(err);
        const expected = context.expected(self.id) orelse return error.BadArgument;
        if (!info.matches(expected)) return error.Corrupt;
        if (!self.workContextMatchesSpawn(context)) return error.Corrupt;
        const draft_id = object.Header.id(draft_canonical);
        const accepted_slot = try self.acceptedWorkSlot(context.child.id, draft_id, context.clock_start);
        const signature = workReceiptSignature(cap, draft_canonical) orelse return error.BadArgument;
        const signed = object.writeSignatureReceipt(draft_canonical, draft_canonical, cap.signer.id.bytes, cap.algorithm, &signature, epoch, out) catch |err| return mapObjectError(err);
        self.recordAcceptedWork(accepted_slot, .{
            .child = context.child.id,
            .draft = draft_id,
            .clock_end = context.clock_end,
        });
        return signed;
    }

    pub fn verifySignedWorkReceipt(draft_canonical: []const u8, signed_canonical: []const u8, capability: SigningCapability) bool {
        const info = object.decodeSignatureReceipt(signed_canonical) catch return false;
        const draft_id = object.Header.id(draft_canonical);
        if (!bytes.eql(&info.subject_id, &draft_id) or !bytes.eql(&info.challenge_id, &draft_id)) return false;
        if (!bytes.eql(&info.signer_id, &capability.signer.id.bytes)) return false;
        if (info.algorithm != capability.algorithm) return false;
        const expected_signature = workReceiptSignature(capability, draft_canonical) orelse return false;
        return bytes.eql(info.signature, &expected_signature);
    }

    fn acceptedWorkSlot(self: App, child: identity.Id, draft: preimage.Hash, clock_start: clock.Stamp) SigningError!?usize {
        if (!child.valid() or !bytes.nonzero(&draft) or !clock_start.valid()) return error.BadArgument;
        for (self.state.accepted_work.slice(), 0..) |entry, index| {
            if (!entry.child.eql(child)) continue;
            if (!entry.valid()) return error.Corrupt;
            if (bytes.eql(&entry.draft, &draft)) return error.Corrupt;
            if (!entry.clock_end.sameKeeper(clock_start)) return error.Corrupt;
            if (clock_start.order(entry.clock_end) <= 0) return error.Corrupt;
            return index;
        }
        if (self.state.accepted_work.full()) return error.NoSpace;
        return null;
    }

    fn recordAcceptedWork(self: *App, slot: ?usize, accepted: AcceptedWork) void {
        if (slot) |index| {
            self.state.accepted_work.items[index] = accepted;
            return;
        }
        _ = self.state.accepted_work.append(accepted);
    }

    pub fn reclaimChild(self: *App, child: *App, receipt: grant.SpawnReceipt, epoch: clock.Stamp) ReclaimError!Reclaimed {
        if (!epoch.valid() or !receipt.valid()) return error.Corrupt;
        if (!receipt.parent.eql(self.id.id) or !receipt.child.eql(child.id.id)) return error.Unauthorized;
        const record_slot = self.activeSpawnRecordSlot(child.id.id, receipt) orelse return error.Corrupt;
        if (child.hasActiveChildren()) return error.Corrupt;
        if (receipt.memory.amount != child.state.memory.owned.len()) return error.Corrupt;
        if (receipt.storage_bytes.amount != child.state.storage.owned.len()) return error.Corrupt;
        if (receipt.storage_slots.amount != child.state.storage.slotCapacity()) return error.Corrupt;
        if (receipt.execution_ticks.amount != child.state.execution_ticks) return error.Corrupt;
        if (receipt.route_handles.amount != child.state.route_handles) return error.Corrupt;
        if (receipt.device_handles.amount != child.state.device_handles) return error.Corrupt;
        if (!bytes.eql(&receipt.route_handle, &child.state.route_handle)) return error.Corrupt;
        if (!receipt.device_handle.eql(child.state.device_handle)) return error.Corrupt;
        if (!self.state.memory.canReclaim(child.state.memory) or !self.state.storage.canReclaim(child.state.storage)) return error.Corrupt;
        if (!self.state.memory.reclaim(&child.state.memory)) return error.Corrupt;
        if (!self.state.storage.reclaim(&child.state.storage)) return error.Corrupt;
        self.state.execution_ticks += child.state.execution_ticks;
        self.state.route_handles += child.state.route_handles;
        self.state.device_handles += child.state.device_handles;
        child.state.execution_ticks = 0;
        child.state.route_handles = 0;
        child.state.device_handles = 0;
        child.state.route_handle = [_]u8{0} ** preimage.hash_size;
        child.state.device_handle = .{ .bytes = [_]u8{0} ** identity.id_size };
        child.state.can_spawn_children = false;
        self.state.spawned_children.items[record_slot].active = false;
        return .{
            .parent = self.id.id,
            .child = child.id.id,
            .epoch = epoch,
            .receipt = receipt,
        };
    }

    fn freeSpawnRecordSlot(self: App) SpawnError!?usize {
        for (self.state.spawned_children.slice(), 0..) |record, index| {
            if (!record.valid()) return error.NoReceipt;
            if (!record.active) return index;
        }
        if (self.state.spawned_children.full()) return error.NoReceipt;
        return null;
    }

    fn recordSpawn(self: *App, slot: ?usize, record: SpawnRecord) void {
        if (slot) |index| {
            self.state.spawned_children.items[index] = record;
            return;
        }
        _ = self.state.spawned_children.append(record);
    }

    fn bindSpawnManifest(self: *App, child: identity.Id, receipt: grant.SpawnReceipt, manifest: preimage.Hash, code_hash: preimage.Hash) !void {
        if (!child.valid() or !bytes.nonzero(&manifest) or !bytes.nonzero(&code_hash)) return error.Corrupt;
        const index = self.activeSpawnRecordSlot(child, receipt) orelse return error.Corrupt;
        self.state.spawned_children.items[index].manifest = manifest;
        self.state.spawned_children.items[index].code_hash = code_hash;
    }

    fn activeSpawnRecordSlot(self: App, child: identity.Id, receipt: grant.SpawnReceipt) ?usize {
        for (self.state.spawned_children.slice(), 0..) |record, index| {
            if (!record.valid()) return null;
            if (record.matchesReceipt(child, receipt)) return index;
        }
        return null;
    }

    fn activeSpawnRecord(self: App, child: identity.Id, receipt: grant.SpawnReceipt) ?SpawnRecord {
        const index = self.activeSpawnRecordSlot(child, receipt) orelse return null;
        return self.state.spawned_children.items[index];
    }

    fn hasActiveChildren(self: App) bool {
        for (self.state.spawned_children.slice()) |record| {
            if (record.valid() and record.active) return true;
        }
        return false;
    }

    fn workContextMatchesSpawn(self: App, context: WorkReceiptDraftContext) bool {
        const record = self.activeSpawnRecord(context.child.id, context.spawn_receipt) orelse return false;
        const allocation_id = context.allocation.id() orelse return false;
        const record_allocation_id = record.allocation.id() orelse return false;
        return bytes.eql(&record.manifest, &context.manifest) and
            bytes.eql(&record.code_hash, &context.app_hash) and
            bytes.eql(&allocation_id, &record_allocation_id) and
            context.clock_start.order(record.clock_start) >= 0 and
            context.execution_used <= record.allocation.execution_ticks;
    }

    fn hasAdmittedAuthorization(self: App, authorization: intent.Receipt, epoch: clock.Stamp, actor: identity.Id, subject: identity.Id, action: intent.Action, consequence: intent.Consequence) bool {
        for (self.state.admissions.slice()) |record| {
            if (record.matches(authorization, epoch, actor, subject, action, consequence)) return true;
        }
        return false;
    }

    pub fn createRelayEnvelope(self: App, route: relay.Route, sequence: u64, payload_object: preimage.Hash, payload_hash: preimage.Hash) ?relay.Envelope {
        if (self.state.route_handles == 0) return null;
        const route_id = route.id() orelse return null;
        if (!bytes.eql(&route_id, &self.state.route_handle)) return null;
        if (!route.source.eql(self.id.id)) return null;
        var envelope = relay.Envelope.init(route, sequence, payload_object, payload_hash) orelse return null;
        if (!envelope.sign(self.id)) return null;
        return envelope;
    }

    pub fn receiveRelayEnvelope(self: App, route: relay.Route, envelope: relay.Envelope, now: clock.Stamp) relay.RouteError!Received {
        if (self.state.route_handles == 0) return error.WrongDestination;
        const route_id = route.id() orelse return error.InvalidRoute;
        if (!bytes.eql(&route_id, &self.state.route_handle)) return error.WrongDestination;
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
        const slice = self.state.memory.allocSlice(u8, size) orelse return error.NoMemory;
        const offset = self.state.memory.offsetOf(slice) orelse return error.Corrupt;
        const slice_id = sharedMemoryId(self.id.id, offset, slice.len, epoch) orelse return error.Corrupt;
        return .{
            .owner = self.id.id,
            .id = slice_id,
            .offset = offset,
            .bytes = slice,
            .epoch = epoch,
        };
    }

    pub fn consumeExecution(self: *App, ticks: u64) bool {
        if (ticks == 0 or ticks > self.state.execution_ticks) return false;
        self.state.execution_ticks -= ticks;
        return true;
    }

    pub fn useDevice(self: App, device: identity.Identity) bool {
        return self.state.device_handles != 0 and device.kind == .device and device.id.eql(self.state.device_handle);
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
        return self.state.storage.putObject(self.id.id, canonical);
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
        const offset = self.state.memory.offsetOf(slice.bytes) orelse return error.Corrupt;
        if (offset != slice.offset) return error.Corrupt;
        const expected_slice = sharedMemoryId(self.id.id, offset, slice.bytes.len, slice.epoch) orelse return error.Corrupt;
        if (!bytes.eql(&expected_slice, &slice.id)) return error.Corrupt;
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
        return self.state.storage.putObject(self.id.id, canonical);
    }

    pub fn renderPublishedUi(self: App, publication: PublishedUi, scratch: UiScratch, scene: *ui.Scene, bounds: ui.Rect, style: ui.Style) UiError!void {
        if (!publication.valid() or !publication.app.eql(self.id.id)) return error.Corrupt;
        try self.renderStoredUi(publication.object_id, scratch, scene, bounds, style);
    }

    pub fn renderStoredUi(self: App, object_id: preimage.Hash, scratch: UiScratch, scene: *ui.Scene, bounds: ui.Rect, style: ui.Style) UiError!void {
        const view = self.state.storage.getObject(self.id.id, object_id) orelse return error.MissingObject;
        const root = try self.uiRootFromView(view, scratch);
        scene.clear();
        ui.render(scene, root, bounds, style) catch |err| switch (err) {
            error.CommandBudgetExceeded, error.ClipBudgetExceeded => return error.RenderBudgetExceeded,
            error.InvalidBounds => return error.InvalidBounds,
        };
    }

    fn uiRootFromView(self: App, view: object.View, scratch: UiScratch) UiError!ui.Node {
        if (view.header.kind == .tree) {
            const tree = ui_resolver.resolveTree(self.state.storage, self.id.id, view, scratch.resolved, scratch.components) catch |err| return mapResolverError(err);
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

fn readWorkReceiptId(in: []const u8, cursor: *usize) ?identity.Id {
    if (cursor.* > in.len or identity.id_size > in.len - cursor.*) return null;
    var id_bytes: [identity.id_size]u8 = undefined;
    _ = bytes.copy(&id_bytes, in[cursor.*..][0..identity.id_size]);
    cursor.* += identity.id_size;
    return .{ .bytes = id_bytes };
}

fn readWorkReceiptHash(in: []const u8, cursor: *usize) ?preimage.Hash {
    if (cursor.* > in.len or preimage.hash_size > in.len - cursor.*) return null;
    var hash: preimage.Hash = undefined;
    _ = bytes.copy(&hash, in[cursor.*..][0..preimage.hash_size]);
    cursor.* += preimage.hash_size;
    return hash;
}

fn readWorkReceiptEpoch(in: []const u8, cursor: *usize) ?clock.Stamp {
    if (cursor.* > in.len or preimage.epoch_size > in.len - cursor.*) return null;
    const stamp = preimage.decodeEpoch(in[cursor.*..][0..preimage.epoch_size]) orelse return null;
    cursor.* += preimage.epoch_size;
    return stamp;
}

fn readWorkReceiptU64(in: []const u8, cursor: *usize) ?u64 {
    if (cursor.* > in.len or @sizeOf(u64) > in.len - cursor.*) return null;
    const value = bytes.load64(in[cursor.*..][0..@sizeOf(u64)]) orelse return null;
    cursor.* += @sizeOf(u64);
    return value;
}

fn mapObjectError(err: object.Error) ReceiptError {
    return switch (err) {
        error.BadArgument => error.BadArgument,
        error.Corrupt => error.Corrupt,
        error.NoSpace => error.NoSpace,
        error.Unsupported => error.Unsupported,
    };
}

fn workReceiptSignature(capability: App.SigningCapability, draft_canonical: []const u8) ?preimage.Hash {
    if (capability.algorithm == .none) return null;
    const authorization_id = capability.authorization.id() orelse return null;
    var builder = preimage.Builder.init("edgerun:zig:v1:parent-signed-work-receipt");
    builder.id(capability.signer.id);
    builder.hash(object.Header.id(draft_canonical));
    builder.hash(authorization_id);
    return builder.final();
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

fn sharedMemoryId(owner: identity.Id, offset: usize, len: usize, epoch: clock.Stamp) ?preimage.Hash {
    const offset_amount = std.math.cast(u64, offset) orelse return null;
    const len_amount = std.math.cast(u64, len) orelse return null;
    var raw: [identity.id_size + 16 + preimage.epoch_size]u8 = undefined;
    var writer = preimage.Writer.init(&raw);
    if (!writer.id(owner) or
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
    var storage_bytes: [512]u8 = undefined;
    var slots: [4]store.Blob = undefined;
    var manifest_raw: [object.header_size + object.owner_size + App.manifest_body_size]u8 = undefined;
    var child_state_raw: [object.header_size + object.owner_size + object.envelope_size + 11]u8 = undefined;

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
    try parent.admitAuthorization(authorization, parent.admissionCapability(authorization) orelse unreachable);
    const manifest = App.Manifest{
        .code_hash = preimage.hash("edgerun:zig:v1:test-code", "bounded child"),
        .allocation = .{
            .memory_bytes = 16,
            .storage_bytes = 288,
            .storage_slots = 2,
        },
    };
    const manifest_canonical = try App.writeManifestObject(child_id, manifest, epoch, &manifest_raw);
    var spawned = try parent.spawnManifest(allocator_id, child_id, epoch, authorization, manifest_canonical);
    var child = spawned.app;
    try std.testing.expectEqual(@as(usize, 48), parent.state.memory.remaining());
    try std.testing.expectEqual(@as(usize, 224), parent.state.storage.data.len());
    try std.testing.expectEqual(@as(usize, 2), parent.state.storage.slotCapacity());
    try std.testing.expectEqual(@as(usize, 16), child.state.memory.remaining());
    try std.testing.expectEqual(@as(usize, 288), child.state.storage.data.len());
    try std.testing.expectEqual(@as(usize, 2), child.state.storage.slotCapacity());

    const child_allocator = child.state.memory.allocator();
    _ = try child_allocator.alloc(u8, 8);
    const child_state_owner = object.Owner{
        .kind = .app,
        .node_id = child.id.id.bytes,
    };
    const child_state_req = sealedAppRequirements();
    const child_state_envelope = sealedEnvelopeForApp(device_id, child_id, user_id, child_state_req, "manifest child state key").?;
    const child_state_canonical = try (object.NodeWriter{ .out = &child_state_raw }).bytesNodeOwned(child_state_req, epoch, &.{child_state_owner}, &.{child_state_envelope}, "child state");
    const child_hash = child.putSealedObject(device_id, user_id, child_state_canonical).?;
    try std.testing.expectEqual(@as(usize, 48), parent.state.memory.remaining());
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
    try std.testing.expectEqual(@as(u64, 288), spawned.receipt.storage_bytes.amount);

    const reclaimed = try parent.reclaimChild(&child, spawned.receipt, epoch);
    try std.testing.expect(reclaimed.valid());
    try std.testing.expect(bytes.nonzero(&reclaimed.id().?));
    try std.testing.expectEqual(@as(usize, 64), parent.state.memory.remaining());
    try std.testing.expectEqual(@as(usize, 512), parent.state.storage.data.len());
    try std.testing.expectEqual(@as(usize, 4), parent.state.storage.slotCapacity());
    try std.testing.expectEqual(@as(usize, 0), child.state.memory.remaining());
    try std.testing.expect(child.state.storage.getObject(child.id.id, child_hash) == null);
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
    try parent.admitAuthorization(child_authorization, parent.admissionCapability(child_authorization) orelse unreachable);

    const spawned_child = try parent.spawnManifest(parent_id, child_id, start, child_authorization, child_manifest_canonical);
    var child = spawned_child.app;
    try std.testing.expectEqual(@as(usize, parent_memory_bytes - child_memory_bytes), parent.state.memory.remaining());
    try std.testing.expectEqual(@as(usize, child_memory_bytes), child.state.memory.remaining());
    try std.testing.expectEqual(@as(usize, child_storage_bytes), child.state.storage.data.len());
    try std.testing.expectEqual(@as(usize, child_storage_slots), child.state.storage.slotCapacity());
    try std.testing.expectEqual(@as(u64, parent_execution_ticks - child_execution_ticks), parent.state.execution_ticks);
    try std.testing.expectEqual(@as(u64, child_execution_ticks), child.state.execution_ticks);
    try std.testing.expectEqual(@as(u64, child_route_handles), child.state.route_handles);
    try std.testing.expectEqual(@as(u64, child_device_handles), child.state.device_handles);
    try std.testing.expect(!child.state.memory.owns(memory_bytes[0..4]));
    try std.testing.expect(!child.state.storage.owned.contains(storage_bytes[0..4]));

    const child_allocator = child.state.memory.allocator();
    _ = try child_allocator.alloc(u8, child_private_bytes);
    try std.testing.expectError(error.OutOfMemory, child_allocator.alloc(u8, child_memory_bytes));
    try std.testing.expect(child.state.storage.putRawBlob(&oversized_storage) == null);
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
    try child.admitAuthorization(grandchild_authorization, child.admissionCapability(grandchild_authorization) orelse unreachable);
    const forged_parent_slice = App.SharedMemory{
        .owner = child.id.id,
        .id = hashMaterial("forged parent memory slice"),
        .offset = 0,
        .bytes = memory_bytes[0..4],
        .epoch = start,
    };
    try std.testing.expectError(error.Corrupt, child.shareMemoryReadOnly(grandchild_id.id, forged_parent_slice, start, grandchild_authorization));
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
    try std.testing.expectEqual(@as(usize, grandchild_memory_bytes), grandchild.state.memory.remaining());
    try std.testing.expectEqual(@as(usize, grandchild_storage_bytes), grandchild.state.storage.data.len());
    try std.testing.expectEqual(@as(u64, child_execution_ticks - grandchild_execution_ticks), child.state.execution_ticks);
    try std.testing.expectEqual(@as(u64, 0), child.state.route_handles);
    try std.testing.expectEqual(@as(u64, 0), child.state.device_handles);
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
    const work = grandchild.completeWork(child.id.id, input_hash, output_hash, grandchild_manifest.code_hash, grandchild_manifest_id, start, end, grandchild_allocation, spawned_grandchild.receipt).?;
    try std.testing.expect(work.valid());
    try std.testing.expect(bytes.nonzero(&work.id().?));
    try std.testing.expect(bytes.eql(&work.manifest, &grandchild_manifest_id));
    try std.testing.expect(bytes.nonzero(&child_manifest_id));
    try std.testing.expect(work.clock_start.order(work.clock_end) < 0);
    const work_receipt_object_id = try grandchild.putWorkReceipt(work, end, &work_receipt_raw);
    try std.testing.expect(bytes.eql(&work_receipt_object_id, &object.Header.id(&work_receipt_raw)));
    const stored_work_receipt = grandchild.state.storage.getReceipt(grandchild.id.id, work_receipt_object_id).?;
    try std.testing.expectEqual(object.Kind.receipt, stored_work_receipt.header.kind);
    try std.testing.expectEqual(workReceiptRequirements(), stored_work_receipt.header.requirements);
    const decoded_work_receipt = try App.WorkReceipt.decodeObject(&work_receipt_raw);
    try std.testing.expect(decoded_work_receipt.matches(work));
    try std.testing.expect(decoded_work_receipt.parent.eql(child.id.id));
    try std.testing.expect(decoded_work_receipt.app.eql(grandchild.id.id));
    try std.testing.expect(bytes.eql(&decoded_work_receipt.output, &output_hash));
    try std.testing.expect(bytes.eql(&decoded_work_receipt.app_hash, &grandchild_manifest.code_hash));
    try std.testing.expect(bytes.eql(&decoded_work_receipt.manifest, &grandchild_manifest_id));
    try std.testing.expect(App.WorkReceipt.decodeBody(stored_work_receipt.body).?.matches(work));
    try std.testing.expectError(error.Corrupt, App.WorkReceipt.decodeObject(output_canonical));
    var wrong_route_receipt = spawned_grandchild.receipt;
    wrong_route_receipt.route_handle = hashMaterial("wrong receipt route");
    try std.testing.expect(grandchild.completeWork(child.id.id, input_hash, output_hash, grandchild_manifest.code_hash, grandchild_manifest_id, start, end, grandchild_allocation, wrong_route_receipt) == null);

    try std.testing.expectError(error.Corrupt, parent.reclaimChild(&child, spawned_child.receipt, end));
    try std.testing.expectError(error.Corrupt, child.reclaimChild(&grandchild, wrong_route_receipt, end));
    const grandchild_reclaim = try child.reclaimChild(&grandchild, spawned_grandchild.receipt, end);
    try std.testing.expect(grandchild_reclaim.valid());
    try std.testing.expectEqual(@as(usize, 0), grandchild.state.memory.remaining());
    try std.testing.expect(grandchild.state.storage.getObject(grandchild.id.id, output_hash) == null);
    try std.testing.expectEqual(@as(u64, child_execution_ticks), child.state.execution_ticks);
    try std.testing.expectEqual(@as(u64, child_route_handles), child.state.route_handles);
    try std.testing.expectEqual(@as(u64, child_device_handles), child.state.device_handles);

    const child_reclaim = try parent.reclaimChild(&child, spawned_child.receipt, end);
    try std.testing.expect(child_reclaim.valid());
    try std.testing.expectEqual(@as(usize, parent_memory_bytes), parent.state.memory.remaining());
    try std.testing.expectEqual(@as(usize, parent_storage_bytes), parent.state.storage.data.len());
    try std.testing.expectEqual(@as(usize, parent_storage_slots), parent.state.storage.slotCapacity());
    try std.testing.expectEqual(@as(u64, parent_execution_ticks), parent.state.execution_ticks);
    try std.testing.expectEqual(@as(u64, parent_route_handles), parent.state.route_handles);
    try std.testing.expectEqual(@as(u64, parent_device_handles), parent.state.device_handles);
    try std.testing.expectEqual(@as(usize, 0), child.state.memory.remaining());
}

test "minimum containment memory storage and reclaim laws" {
    const child_memory_bytes = 4096;
    const parent_memory_bytes = child_memory_bytes * 2;
    const child_storage_bytes = 1024;
    const parent_storage_bytes = child_storage_bytes * 4;
    const parent_storage_slots = 8;
    const child_storage_slots = 2;
    const parent_execution_ticks = 200;
    const child_execution_ticks = 100;
    const grandchild_memory_bytes = 1024;
    const grandchild_storage_bytes = 256;
    const grandchild_storage_slots = 1;
    const grandchild_execution_ticks = 80;

    var memory_bytes: [parent_memory_bytes]u8 = [_]u8{0xaa} ** parent_memory_bytes;
    var storage_bytes: [parent_storage_bytes]u8 = undefined;
    var slots: [parent_storage_slots]store.Blob = undefined;
    var child_manifest_raw: [object.header_size + object.owner_size + App.manifest_body_size]u8 = undefined;
    var grandchild_manifest_raw: [object.header_size + object.owner_size + App.manifest_body_size]u8 = undefined;
    var sibling_memory: [child_memory_bytes]u8 = undefined;
    var sibling_storage: [child_storage_bytes]u8 = undefined;
    var sibling_slots: [child_storage_slots]store.Blob = undefined;
    var oversized_storage: [child_storage_bytes * 2]u8 = [_]u8{0x55} ** (child_storage_bytes * 2);

    const keeper = clock.KeeperId{ .bytes = [_]u8{9} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const user_id = identity.Identity.init(.user, identity.Source.prepare(.hash, &preimage.rawHash("minimum laws user")).?, epoch).?;
    const device_id = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("minimum laws device")).?, epoch).?;
    const parent_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("minimum laws parent")).?, epoch).?;
    const child_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("minimum laws child")).?, epoch).?;
    const grandchild_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("minimum laws grandchild")).?, epoch).?;
    const sibling_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("minimum laws sibling")).?, epoch).?;

    const parent_allocation = App.DeclaredAllocation{
        .memory_bytes = parent_memory_bytes,
        .storage_bytes = parent_storage_bytes,
        .storage_slots = parent_storage_slots,
        .execution_ticks = parent_execution_ticks,
    };
    var parent = App.initAllocated(
        parent_id,
        BoundedArena.init(.{ .base = &memory_bytes }),
        store.Store.init(.{ .base = &storage_bytes }, &slots),
        parent_allocation,
    ).?;
    var sibling = App.initAllocated(
        sibling_id,
        BoundedArena.init(.{ .base = &sibling_memory }),
        store.Store.init(.{ .base = &sibling_storage }, &sibling_slots),
        .{
            .memory_bytes = child_memory_bytes,
            .storage_bytes = child_storage_bytes,
            .storage_slots = child_storage_slots,
            .execution_ticks = child_execution_ticks,
        },
    ).?;

    const child_allocation = App.DeclaredAllocation{
        .memory_bytes = child_memory_bytes,
        .storage_bytes = child_storage_bytes,
        .storage_slots = child_storage_slots,
        .execution_ticks = child_execution_ticks,
    };
    const child_manifest = App.Manifest{
        .code_hash = preimage.hash("edgerun:zig:v1:test-code", "minimum laws child code"),
        .allocation = child_allocation,
        .flags = App.manifest_flag_child_spawn,
    };
    const child_manifest_canonical = try App.writeManifestObject(child_id, child_manifest, epoch, &child_manifest_raw);
    const child_authorization = intent.admit(
        user_id,
        device_id,
        parent_id,
        child_id,
        .spawn_app,
        .delegates_resources,
        epoch,
        intent.requestId("minimum laws child spawn").?,
    ).?;
    try parent.admitAuthorization(child_authorization, parent.admissionCapability(child_authorization) orelse unreachable);
    const spawned_child = try parent.spawnManifest(parent_id, child_id, epoch, child_authorization, child_manifest_canonical);
    var child = spawned_child.app;

    const child_allocator = child.state.memory.allocator();
    const child_memory = try child_allocator.alloc(u8, 1);
    child_memory[0] = 0x11;
    try std.testing.expect(!child.state.memory.owns(memory_bytes[0..1]));

    try std.testing.expect(child.state.storage.putRawBlob(&oversized_storage) == null);
    const sibling_secret = sibling.state.storage.putRawBlob("sibling secret").?;
    try std.testing.expect(child.state.storage.get(sibling_secret) == null);

    const grandchild_authorization = intent.admit(
        user_id,
        device_id,
        child_id,
        grandchild_id,
        .spawn_app,
        .delegates_resources,
        epoch,
        intent.requestId("minimum laws grandchild spawn").?,
    ).?;
    try child.admitAuthorization(grandchild_authorization, child.admissionCapability(grandchild_authorization) orelse unreachable);
    const grandchild_manifest = App.Manifest{
        .code_hash = preimage.hash("edgerun:zig:v1:test-code", "minimum laws grandchild code"),
        .allocation = .{
            .memory_bytes = grandchild_memory_bytes,
            .storage_bytes = grandchild_storage_bytes,
            .storage_slots = grandchild_storage_slots,
            .execution_ticks = grandchild_execution_ticks,
        },
    };
    const grandchild_manifest_canonical = try App.writeManifestObject(grandchild_id, grandchild_manifest, epoch, &grandchild_manifest_raw);
    const spawned_grandchild = try child.spawnManifest(child_id, grandchild_id, epoch, grandchild_authorization, grandchild_manifest_canonical);
    var grandchild = spawned_grandchild.app;
    try std.testing.expectEqual(@as(u64, child_execution_ticks - grandchild_execution_ticks), child.state.execution_ticks);
    try std.testing.expectEqual(@as(usize, grandchild_memory_bytes), grandchild.state.memory.remaining());
    try std.testing.expectEqual(@as(usize, parent_memory_bytes - child_memory_bytes), parent.state.memory.remaining());

    try std.testing.expectError(error.Corrupt, parent.reclaimChild(&child, spawned_child.receipt, epoch));
    _ = try child.reclaimChild(&grandchild, spawned_grandchild.receipt, epoch);
    _ = try parent.reclaimChild(&child, spawned_child.receipt, epoch);
    try std.testing.expectEqual(@as(usize, parent_memory_bytes), parent.state.memory.remaining());
    try std.testing.expectEqual(@as(usize, parent_storage_bytes), parent.state.storage.data.len());
    try std.testing.expectEqual(@as(usize, 0), child.state.memory.remaining());
    try std.testing.expectEqual(@as(usize, 0), child.state.storage.data.len());
    try std.testing.expectError(error.Corrupt, parent.reclaimChild(&child, spawned_child.receipt, epoch));
}

test "minimum containment child cannot write byte past 4kb allocation" {
    const child_memory_bytes = 4096;
    var memory_bytes: [child_memory_bytes]u8 = undefined;
    var arena = BoundedArena.init(.{ .base = &memory_bytes });
    const allocator = arena.allocator();

    const full_child_memory = try allocator.alloc(u8, child_memory_bytes);
    full_child_memory[child_memory_bytes - 1] = 0x11;
    try std.testing.expectError(error.OutOfMemory, allocator.alloc(u8, 1));
}

test "minimum containment rejects parent allocation id as child memory id" {
    const parent_memory_bytes = 128;
    const parent_storage_bytes = 256;
    const parent_storage_slots = 4;
    const child_memory_bytes = 64;
    const child_storage_bytes = 128;
    const child_storage_slots = 2;

    var memory_bytes: [parent_memory_bytes]u8 = undefined;
    var storage_bytes: [parent_storage_bytes]u8 = undefined;
    var slots: [parent_storage_slots]store.Blob = undefined;
    var manifest_raw: [object.header_size + object.owner_size + App.manifest_body_size]u8 = undefined;

    const keeper = clock.KeeperId{ .bytes = [_]u8{12} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const user_id = identity.Identity.init(.user, identity.Source.prepare(.hash, &preimage.rawHash("allocation id user")).?, epoch).?;
    const device_id = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("allocation id device")).?, epoch).?;
    const parent_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("allocation id parent")).?, epoch).?;
    const child_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("allocation id child")).?, epoch).?;
    const reader_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("allocation id reader")).?, epoch).?;

    const parent_allocation = App.DeclaredAllocation{
        .memory_bytes = parent_memory_bytes,
        .storage_bytes = parent_storage_bytes,
        .storage_slots = parent_storage_slots,
        .execution_ticks = 1,
    };
    var parent = App.initAllocated(
        parent_id,
        BoundedArena.init(.{ .base = &memory_bytes }),
        store.Store.init(.{ .base = &storage_bytes }, &slots),
        parent_allocation,
    ).?;
    const manifest = App.Manifest{
        .code_hash = preimage.hash("edgerun:zig:v1:test-code", "allocation id child code"),
        .allocation = .{
            .memory_bytes = child_memory_bytes,
            .storage_bytes = child_storage_bytes,
            .storage_slots = child_storage_slots,
            .execution_ticks = 1,
        },
    };
    const manifest_canonical = try App.writeManifestObject(child_id, manifest, epoch, &manifest_raw);
    const authorization = intent.admit(user_id, device_id, parent_id, child_id, .spawn_app, .delegates_resources, epoch, intent.requestId("allocation id spawn").?).?;
    try parent.admitAuthorization(authorization, parent.admissionCapability(authorization) orelse unreachable);
    const spawned = try parent.spawnManifest(parent_id, child_id, epoch, authorization, manifest_canonical);
    var child = spawned.app;
    const child_memory = try child.state.memory.allocator().alloc(u8, 1);
    const forged_allocation_slice = App.SharedMemory{
        .owner = child.id.id,
        .id = parent_allocation.id().?,
        .offset = 0,
        .bytes = child_memory,
        .epoch = epoch,
    };
    const share_authorization = intent.admit(user_id, device_id, child_id, reader_id, .grant_resource, .exports_data, epoch, intent.requestId("allocation id forged share").?).?;
    try std.testing.expectError(error.Corrupt, child.shareMemoryReadOnly(reader_id.id, forged_allocation_slice, epoch, share_authorization));
}

test "minimum containment routes devices receipts and revoked handles" {
    const parent_memory_bytes = 128;
    const parent_storage_bytes = 1536;
    const parent_storage_slots = 6;
    const child_memory_bytes = 64;
    const child_storage_bytes = 1024;
    const child_storage_slots = 3;
    const child_execution_ticks = 100;
    const used_execution_ticks = 20;

    var memory_bytes: [parent_memory_bytes]u8 = undefined;
    var storage_bytes: [parent_storage_bytes]u8 = undefined;
    var slots: [parent_storage_slots]store.Blob = undefined;
    var child_manifest_raw: [object.header_size + object.owner_size + App.manifest_body_size]u8 = undefined;
    var work_output_raw: [object.header_size + object.owner_size + object.envelope_size + 6]u8 = undefined;
    var receipt_raw: [object.header_size + work_receipt_body_size]u8 = undefined;
    var receipt_again_raw: [object.header_size + work_receipt_body_size]u8 = undefined;

    const keeper = clock.KeeperId{ .bytes = [_]u8{11} ++ [_]u8{0} ** 31 };
    const start = clock.Stamp{ .keeper = keeper, .tick = 10 };
    const end = clock.Stamp{ .keeper = keeper, .tick = 20 };
    const user_id = identity.Identity.init(.user, identity.Source.prepare(.hash, &preimage.rawHash("receipt laws user")).?, start).?;
    const device_id = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("receipt laws device")).?, start).?;
    const other_device_id = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("receipt laws other device")).?, start).?;
    const parent_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("receipt laws parent")).?, start).?;
    const child_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("receipt laws child")).?, start).?;
    const other_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("receipt laws other app")).?, start).?;
    const route_admission = intent.admit(user_id, device_id, child_id, other_id, .sync_data, .exports_data, start, intent.requestId("receipt laws route").?).?;
    const route = relay.Route.init(route_admission, child_id, other_id, .sync_data, .exports_data, hashMaterial("receipt laws route policy")).?;
    const route_id = route.id().?;
    const different_route_id = hashMaterial("receipt laws different route");

    var parent = App.initAllocated(
        parent_id,
        BoundedArena.init(.{ .base = &memory_bytes }),
        store.Store.init(.{ .base = &storage_bytes }, &slots),
        .{
            .memory_bytes = parent_memory_bytes,
            .storage_bytes = parent_storage_bytes,
            .storage_slots = parent_storage_slots,
            .execution_ticks = child_execution_ticks,
            .route_handles = 1,
            .device_handles = 1,
            .route_handle = route_id,
            .device_handle = device_id.id,
        },
    ).?;
    const child_allocation = App.DeclaredAllocation{
        .memory_bytes = child_memory_bytes,
        .storage_bytes = child_storage_bytes,
        .storage_slots = child_storage_slots,
        .execution_ticks = child_execution_ticks,
        .route_handles = 1,
        .device_handles = 1,
        .route_handle = route_id,
        .device_handle = device_id.id,
    };
    const child_manifest = App.Manifest{
        .code_hash = preimage.hash("edgerun:zig:v1:test-code", "receipt laws child code"),
        .allocation = child_allocation,
    };
    const child_manifest_canonical = try App.writeManifestObject(child_id, child_manifest, start, &child_manifest_raw);
    const child_manifest_id = object.Header.id(child_manifest_canonical);
    const authorization = intent.admit(user_id, device_id, parent_id, child_id, .spawn_app, .delegates_resources, start, intent.requestId("receipt laws spawn").?).?;
    try parent.admitAuthorization(authorization, parent.admissionCapability(authorization) orelse unreachable);
    const spawned = try parent.spawnManifest(parent_id, child_id, start, authorization, child_manifest_canonical);
    var child = spawned.app;

    try std.testing.expect(child.createRelayEnvelope(route, 1, hashMaterial("receipt laws object"), hashMaterial("receipt laws payload")) != null);
    child.state.route_handle = different_route_id;
    try std.testing.expect(child.createRelayEnvelope(route, 2, hashMaterial("receipt laws object"), hashMaterial("receipt laws payload")) == null);
    child.state.route_handle = route_id;
    try std.testing.expect(child.useDevice(device_id));
    try std.testing.expect(!child.useDevice(other_device_id));
    try std.testing.expect(child.consumeExecution(used_execution_ticks));

    const owner = object.Owner{ .kind = .app, .node_id = child.id.id.bytes };
    const output_req = sealedAppRequirements();
    const envelope = sealedEnvelopeForApp(device_id, child_id, user_id, output_req, "receipt laws output key").?;
    const output_canonical = try (object.NodeWriter{ .out = &work_output_raw }).bytesNodeOwned(output_req, start, &.{owner}, &.{envelope}, "output");
    const output_hash = child.putSealedObject(device_id, user_id, output_canonical).?;
    const input_hash = hashMaterial("receipt laws input");
    child.state.execution_ticks = child_execution_ticks;
    const work = child.completeWork(parent.id.id, input_hash, output_hash, child_manifest.code_hash, child_manifest_id, start, end, child_allocation, spawned.receipt).?;
    const first_receipt_id = try child.putWorkReceipt(work, end, &receipt_raw);
    const second_receipt_id = try child.putWorkReceipt(work, end, &receipt_again_raw);
    try std.testing.expectEqualSlices(u8, &receipt_raw, &receipt_again_raw);
    try std.testing.expect(bytes.eql(&first_receipt_id, &second_receipt_id));

    var tampered_receipt = receipt_raw;
    tampered_receipt[object.header_size + identity.id_size * 2] ^= 1;
    const tampered_info = try App.WorkReceipt.decodeObject(&tampered_receipt);
    try std.testing.expect(!tampered_info.matches(work));

    _ = try parent.reclaimChild(&child, spawned.receipt, end);
    try std.testing.expect(!child.useDevice(device_id));
    try std.testing.expect(child.createRelayEnvelope(route, 3, hashMaterial("receipt laws object"), hashMaterial("receipt laws payload")) == null);
    try std.testing.expect(!child.consumeExecution(1));
}

test "minimum containment work receipt records ticks used" {
    const parent_memory_bytes = 128;
    const parent_storage_bytes = 1024;
    const parent_storage_slots = 4;
    const child_memory_bytes = 64;
    const child_storage_bytes = 512;
    const child_storage_slots = 2;
    const child_execution_ticks = 100;
    const used_execution_ticks = 20;

    var memory_bytes: [parent_memory_bytes]u8 = undefined;
    var storage_bytes: [parent_storage_bytes]u8 = undefined;
    var slots: [parent_storage_slots]store.Blob = undefined;
    var manifest_raw: [object.header_size + object.owner_size + App.manifest_body_size]u8 = undefined;

    const keeper = clock.KeeperId{ .bytes = [_]u8{13} ++ [_]u8{0} ** 31 };
    const start = clock.Stamp{ .keeper = keeper, .tick = 10 };
    const end = clock.Stamp{ .keeper = keeper, .tick = 20 };
    const user_id = identity.Identity.init(.user, identity.Source.prepare(.hash, &preimage.rawHash("usage receipt user")).?, start).?;
    const device_id = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("usage receipt device")).?, start).?;
    const parent_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("usage receipt parent")).?, start).?;
    const child_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("usage receipt child")).?, start).?;

    var parent = App.initAllocated(
        parent_id,
        BoundedArena.init(.{ .base = &memory_bytes }),
        store.Store.init(.{ .base = &storage_bytes }, &slots),
        .{
            .memory_bytes = parent_memory_bytes,
            .storage_bytes = parent_storage_bytes,
            .storage_slots = parent_storage_slots,
            .execution_ticks = child_execution_ticks,
        },
    ).?;
    const allocation = App.DeclaredAllocation{
        .memory_bytes = child_memory_bytes,
        .storage_bytes = child_storage_bytes,
        .storage_slots = child_storage_slots,
        .execution_ticks = child_execution_ticks,
    };
    const manifest = App.Manifest{
        .code_hash = preimage.hash("edgerun:zig:v1:test-code", "usage receipt child code"),
        .allocation = allocation,
    };
    const manifest_canonical = try App.writeManifestObject(child_id, manifest, start, &manifest_raw);
    const manifest_id = object.Header.id(manifest_canonical);
    const authorization = intent.admit(user_id, device_id, parent_id, child_id, .spawn_app, .delegates_resources, start, intent.requestId("usage receipt spawn").?).?;
    try parent.admitAuthorization(authorization, parent.admissionCapability(authorization) orelse unreachable);
    const spawned = try parent.spawnManifest(parent_id, child_id, start, authorization, manifest_canonical);
    var child = spawned.app;

    try std.testing.expect(child.consumeExecution(used_execution_ticks));
    const work = child.completeWork(parent.id.id, hashMaterial("usage input"), hashMaterial("usage output"), manifest.code_hash, manifest_id, start, end, allocation, spawned.receipt).?;
    try std.testing.expectEqual(@as(u64, used_execution_ticks), work.execution_used);
}

test "parent signs validated work receipt drafts" {
    const parent_memory_bytes = 128;
    const parent_storage_bytes = 1024;
    const parent_storage_slots = 4;
    const child_memory_bytes = 64;
    const child_storage_bytes = 512;
    const child_storage_slots = 2;
    const signature_bytes = preimage.hash_size;

    var memory_bytes: [parent_memory_bytes]u8 = undefined;
    var storage_bytes: [parent_storage_bytes]u8 = undefined;
    var slots: [parent_storage_slots]store.Blob = undefined;
    var other_storage_bytes: [parent_storage_bytes]u8 = undefined;
    var other_slots: [parent_storage_slots]store.Blob = undefined;
    var other_memory_bytes: [parent_memory_bytes]u8 = undefined;
    var manifest_raw: [object.header_size + object.owner_size + App.manifest_body_size]u8 = undefined;
    var draft_raw: [object.header_size + work_receipt_body_size]u8 = undefined;
    var overlap_draft_raw: [object.header_size + work_receipt_body_size]u8 = undefined;
    var backward_draft_raw: [object.header_size + work_receipt_body_size]u8 = undefined;
    var wrong_manifest_draft_raw: [object.header_size + work_receipt_body_size]u8 = undefined;
    var signed_raw: [object.header_size + object.signature_fixed_body_size + signature_bytes]u8 = undefined;

    const keeper = clock.KeeperId{ .bytes = [_]u8{14} ++ [_]u8{0} ** 31 };
    const start = clock.Stamp{ .keeper = keeper, .tick = 10 };
    const end = clock.Stamp{ .keeper = keeper, .tick = 20 };
    const user_id = identity.Identity.init(.user, identity.Source.prepare(.hash, &preimage.rawHash("signed receipt user")).?, start).?;
    const device_id = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("signed receipt device")).?, start).?;
    const parent_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("signed receipt parent")).?, start).?;
    const other_parent_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("signed receipt other parent")).?, start).?;
    const child_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("signed receipt child")).?, start).?;

    var parent = App.initAllocated(
        parent_id,
        BoundedArena.init(.{ .base = &memory_bytes }),
        store.Store.init(.{ .base = &storage_bytes }, &slots),
        .{
            .memory_bytes = parent_memory_bytes,
            .storage_bytes = parent_storage_bytes,
            .storage_slots = parent_storage_slots,
            .execution_ticks = 1,
        },
    ).?;
    var other_parent = App.initAllocated(
        other_parent_id,
        BoundedArena.init(.{ .base = &other_memory_bytes }),
        store.Store.init(.{ .base = &other_storage_bytes }, &other_slots),
        .{
            .memory_bytes = parent_memory_bytes,
            .storage_bytes = parent_storage_bytes,
            .storage_slots = parent_storage_slots,
            .execution_ticks = 1,
        },
    ).?;
    const allocation = App.DeclaredAllocation{
        .memory_bytes = child_memory_bytes,
        .storage_bytes = child_storage_bytes,
        .storage_slots = child_storage_slots,
        .execution_ticks = 1,
    };
    const manifest = App.Manifest{
        .code_hash = preimage.hash("edgerun:zig:v1:test-code", "signed receipt child code"),
        .allocation = allocation,
    };
    const manifest_canonical = try App.writeManifestObject(child_id, manifest, start, &manifest_raw);
    const manifest_id = object.Header.id(manifest_canonical);
    const authorization = intent.admit(user_id, device_id, parent_id, child_id, .spawn_app, .delegates_resources, start, intent.requestId("signed receipt spawn").?).?;
    try parent.admitAuthorization(authorization, parent.admissionCapability(authorization) orelse unreachable);
    const spawned = try parent.spawnManifest(parent_id, child_id, start, authorization, manifest_canonical);
    var child = spawned.app;
    const input_hash = hashMaterial("signed input");
    const output_hash = hashMaterial("signed output");
    const work = child.completeWork(parent.id.id, input_hash, output_hash, manifest.code_hash, manifest_id, start, end, allocation, spawned.receipt).?;
    const draft = try work.writeObject(end, &draft_raw);
    try std.testing.expectError(error.Corrupt, object.decodeSignatureReceipt(draft));

    const signing_authorization = intent.admit(user_id, device_id, parent_id, parent_id, .sign_data, .attests_state, end, intent.requestId("parent signs accepted work").?).?;
    try parent.admitAuthorization(signing_authorization, parent.admissionCapability(signing_authorization) orelse unreachable);
    const capability = App.SigningCapability{
        .signer = parent_id,
        .authorization = signing_authorization,
    };
    const context = App.WorkReceiptDraftContext{
        .child = child_id,
        .input = input_hash,
        .output = output_hash,
        .app_hash = manifest.code_hash,
        .manifest = manifest_id,
        .clock_start = start,
        .clock_end = end,
        .allocation = allocation,
        .execution_used = work.execution_used,
        .spawn_receipt = spawned.receipt,
    };
    const signed = try parent.signWorkReceiptDraft(draft, context, end, capability, &signed_raw);
    try std.testing.expect(App.verifySignedWorkReceipt(draft, signed, capability));
    try std.testing.expectError(error.Corrupt, parent.signWorkReceiptDraft(draft, context, end, capability, &signed_raw));

    var tampered_draft = draft_raw;
    tampered_draft[object.header_size + identity.id_size * 2] ^= 1;
    try std.testing.expect(!App.verifySignedWorkReceipt(&tampered_draft, signed, capability));
    try std.testing.expectError(error.Corrupt, parent.signWorkReceiptDraft(&tampered_draft, context, end, capability, &signed_raw));

    var wrong_allocation_context = context;
    wrong_allocation_context.allocation.storage_bytes += 1;
    try std.testing.expectError(error.BadArgument, parent.signWorkReceiptDraft(draft, wrong_allocation_context, end, capability, &signed_raw));

    var impossible_usage_context = context;
    impossible_usage_context.execution_used = allocation.execution_ticks + 1;
    try std.testing.expectError(error.BadArgument, parent.signWorkReceiptDraft(draft, impossible_usage_context, end, capability, &signed_raw));

    const overlap_start = clock.Stamp{ .keeper = keeper, .tick = 15 };
    const overlap_end = clock.Stamp{ .keeper = keeper, .tick = 25 };
    const overlap_work = child.completeWork(parent.id.id, hashMaterial("overlap input"), hashMaterial("overlap output"), manifest.code_hash, manifest_id, overlap_start, overlap_end, allocation, spawned.receipt).?;
    const overlap_draft = try overlap_work.writeObject(overlap_end, &overlap_draft_raw);
    var overlap_context = context;
    overlap_context.input = hashMaterial("overlap input");
    overlap_context.output = hashMaterial("overlap output");
    overlap_context.clock_start = overlap_start;
    overlap_context.clock_end = overlap_end;
    try std.testing.expectError(error.Corrupt, parent.signWorkReceiptDraft(overlap_draft, overlap_context, end, capability, &signed_raw));

    const backward_start = clock.Stamp{ .keeper = keeper, .tick = 5 };
    const backward_end = clock.Stamp{ .keeper = keeper, .tick = 9 };
    const backward_work = child.completeWork(parent.id.id, hashMaterial("backward input"), hashMaterial("backward output"), manifest.code_hash, manifest_id, backward_start, backward_end, allocation, spawned.receipt).?;
    const backward_draft = try backward_work.writeObject(backward_end, &backward_draft_raw);
    var backward_context = context;
    backward_context.input = hashMaterial("backward input");
    backward_context.output = hashMaterial("backward output");
    backward_context.clock_start = backward_start;
    backward_context.clock_end = backward_end;
    try std.testing.expectError(error.Corrupt, parent.signWorkReceiptDraft(backward_draft, backward_context, end, capability, &signed_raw));

    const wrong_manifest_work = child.completeWork(parent.id.id, input_hash, output_hash, manifest.code_hash, hashMaterial("wrong manifest"), start, end, allocation, spawned.receipt).?;
    const wrong_manifest_draft = try wrong_manifest_work.writeObject(end, &wrong_manifest_draft_raw);
    try std.testing.expectError(error.Corrupt, parent.signWorkReceiptDraft(wrong_manifest_draft, context, end, capability, &signed_raw));

    const other_signing_authorization = intent.admit(user_id, device_id, other_parent_id, other_parent_id, .sign_data, .attests_state, end, intent.requestId("other parent signs accepted work").?).?;
    try other_parent.admitAuthorization(other_signing_authorization, other_parent.admissionCapability(other_signing_authorization) orelse unreachable);
    const other_capability = App.SigningCapability{
        .signer = other_parent_id,
        .authorization = other_signing_authorization,
    };
    try std.testing.expectError(error.BadArgument, other_parent.signWorkReceiptDraft(draft, context, end, other_capability, &signed_raw));

    const expired_authorization = intent.admitWindow(user_id, device_id, parent_id, parent_id, .sign_data, .attests_state, start, start, start, intent.requestId("expired parent signing").?).?;
    try parent.admitAuthorization(expired_authorization, parent.admissionCapability(expired_authorization) orelse unreachable);
    const expired_capability = App.SigningCapability{
        .signer = parent_id,
        .authorization = expired_authorization,
    };
    try std.testing.expectError(error.Unauthorized, parent.signWorkReceiptDraft(draft, context, end, expired_capability, &signed_raw));

    try std.testing.expectError(error.Unauthorized, parent.signWorkReceiptDraft(draft, context, end, null, &signed_raw));
}

test "app creates its store from its host-owned memory slice" {
    var host_memory: [1024]u8 = undefined;
    var state_raw: [object.header_size + object.owner_size + object.envelope_size + 5]u8 = undefined;

    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const user_id = identity.Identity.init(.user, identity.Source.prepare(.hash, &preimage.rawHash("host slice user")).?, epoch).?;
    const device_id = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("host slice device")).?, epoch).?;
    const app_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("app")).?, epoch).?;
    var app = App.initFromHostSlice(
        app_id,
        BoundedArena.init(.{ .base = &host_memory }),
        384,
        4,
    ).?;

    const owner = object.Owner{
        .kind = .app,
        .node_id = app.id.id.bytes,
    };
    const req = sealedAppRequirements();
    const envelope = sealedEnvelopeForApp(device_id, app_id, user_id, req, "host slice state key").?;
    const canonical = try (object.NodeWriter{ .out = &state_raw }).bytesNodeOwned(req, epoch, &.{owner}, &.{envelope}, "state");
    const hash = app.putSealedObject(device_id, user_id, canonical).?;
    try std.testing.expectEqualStrings("state", app.state.storage.getObject(app.id.id, hash).?.body);
    try std.testing.expect(app.state.memory.remaining() < 640);
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
    const stored = app.state.storage.getObject(app.id.id, object_id).?;
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

    const stored = app.state.storage.getObject(app.id.id, published.object_id).?;
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
    source.state.route_handles = 1;
    target.state.route_handles = 1;
    source.state.route_handle = route_id;
    target.state.route_handle = route_id;

    const envelope = source.createRelayEnvelope(route, 1, hashMaterial("message object"), hashMaterial("sealed to target")).?;
    var public_relay = relay.RelayApp.init(relay_id).?;
    const transit = try public_relay.forward(route, envelope, now);
    try std.testing.expect(transit.valid());

    const received = try target.receiveRelayEnvelope(route, envelope, now);
    try std.testing.expect(received.valid());
    try std.testing.expect(bytes.nonzero(&received.id().?));
}
