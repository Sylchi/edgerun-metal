const BoundedArena = @import("arena.zig").BoundedArena;
const authority = @import("authority.zig");
const bounded = @import("bounded.zig");
const bytes = @import("bytes.zig");
const clock = @import("clock.zig");
const grant = @import("grant.zig");
const identity = @import("identity.zig");
const intent = @import("intent.zig");
const object = @import("object.zig");
const preimage = @import("preimage.zig");
const relay = @import("relay.zig");
const seal = @import("seal.zig");
const store = @import("store.zig");
const tpmapp = @import("tpmapp.zig");
const component_common = @import("ui_component_common.zig");
const component_union = @import("ui/components/Component.zig");
const stack_component = @import("ui/components/Stack.zig");
const slot_component = @import("ui/components/Slot.zig");
const ui = @import("ui.zig");
const ui_resolver = @import("ui_resolver.zig");

const Component = component_union.Component;
const Stack = stack_component.Stack(Component);
const Slot = slot_component.Slot(Component);
const RenderOptions = component_common.RenderOptions;

const allocation_count_field_size = @sizeOf(u64);
const allocation_count_field_count = 6;
const allocation_count_body_size = allocation_count_field_size * allocation_count_field_count;
const allocation_justification_size = 64;
const allocation_body_size = allocation_count_body_size + allocation_justification_size + preimage.hash_size + identity.id_size;
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
const runtime_signature_size = preimage.hash_size;
const app_private_storage_proof_body = "edgerun app private storage proof";

const SpawnCodePolicy = enum {
    wasm_only,
    native_runtime_allowed,
};

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

pub const AppPrivateStorageProofError = object.EncryptionError || error{
    NoSpace,
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

pub const ExecutionHost = struct {
    id: identity.Identity,

    pub fn init(id: identity.Identity) ?ExecutionHost {
        if (id.kind != .device or !id.id.valid()) return null;
        return .{ .id = id };
    }

    pub fn valid(self: ExecutionHost) bool {
        return authority.Principal.device(self.id) != null;
    }

    pub fn spawnDeclared(self: ExecutionHost, parent: *App, allocator_id: identity.Identity, child_id: identity.Identity, epoch: clock.Stamp, authorization: intent.Receipt, allocation: App.DeclaredAllocation) SpawnError!App.HostChild {
        if (!self.valid()) return error.Unauthorized;
        return parent.spawnDeclared(allocator_id, child_id, epoch, authorization, allocation);
    }

    pub fn spawnDeclaredHandle(self: ExecutionHost, parent: *App, allocator_id: identity.Identity, child_id: identity.Identity, epoch: clock.Stamp, authorization: intent.Receipt, allocation: App.DeclaredAllocation) SpawnError!App.ChildHandle {
        const spawned = try self.spawnDeclared(parent, allocator_id, child_id, epoch, authorization, allocation);
        return spawned.handle() orelse error.NoReceipt;
    }

    pub fn spawnManifest(self: ExecutionHost, parent: *App, allocator_id: identity.Identity, child_id: identity.Identity, epoch: clock.Stamp, authorization: intent.Receipt, manifest_canonical: []const u8) SpawnError!App.HostChild {
        if (!self.valid()) return error.Unauthorized;
        return parent.spawnManifest(allocator_id, child_id, epoch, authorization, manifest_canonical, .wasm_only);
    }

    pub fn spawnManifestHandle(self: ExecutionHost, parent: *App, allocator_id: identity.Identity, child_id: identity.Identity, epoch: clock.Stamp, authorization: intent.Receipt, manifest_canonical: []const u8) SpawnError!App.ChildHandle {
        const spawned = try self.spawnManifest(parent, allocator_id, child_id, epoch, authorization, manifest_canonical);
        return spawned.handle() orelse error.NoReceipt;
    }

    pub fn spawnNativeRuntimeManifest(self: ExecutionHost, parent: *App, allocator_id: identity.Identity, child_id: identity.Identity, epoch: clock.Stamp, authorization: intent.Receipt, manifest_canonical: []const u8, runtime_signer: identity.Identity, runtime_signature_canonical: []const u8) SpawnError!App.HostChild {
        if (!self.valid()) return error.Unauthorized;
        const manifest = App.Manifest.fromObject(manifest_canonical) orelse return error.BadAllocation;
        if (!manifest.nativeRuntimeRequired()) return error.Unauthorized;
        if (!nativeRuntimeSignatureValid(runtime_signer, manifest_canonical, runtime_signature_canonical)) return error.Unauthorized;
        return parent.spawnManifest(allocator_id, child_id, epoch, authorization, manifest_canonical, .native_runtime_allowed);
    }

    pub fn reclaimChild(self: ExecutionHost, parent: *App, child: *App, receipt: grant.SpawnReceipt, epoch: clock.Stamp) ReclaimError!App.Reclaimed {
        if (!self.valid()) return error.Unauthorized;
        return parent.reclaimChild(child, receipt, epoch);
    }
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
        actor: authority.Principal,
        subject: authority.Principal,
        action: intent.Action,
        consequence: intent.Consequence,
        not_after: clock.Stamp,

        fn valid(self: AdmissionRecord) bool {
            return bytes.nonzero(&self.receipt) and
                self.actor.valid() and
                self.subject.valid() and
                self.not_after.valid();
        }

        fn matches(self: AdmissionRecord, authorization: intent.Receipt, epoch: clock.Stamp, actor: authority.Principal, subject: authority.Principal, action: intent.Action, consequence: intent.Consequence) bool {
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
        issuer: authority.Principal,
        actor: authority.Principal,
        subject: authority.Principal,
        receipt: preimage.Hash,

        fn permits(self: AdmissionCapability, app: authority.Principal, authorization: intent.Receipt) bool {
            const receipt_id = authorization.id() orelse return false;
            return self.issuer.eql(app) and
                bytes.eql(&self.receipt, &receipt_id) and
                authority.receiptPermits(authorization, authorization.intent.epoch, self.actor, self.subject, authorization.intent.action, authorization.intent.consequence);
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

    fn principal(self: App) ?authority.Principal {
        return authority.Principal.app(self.id);
    }

    fn admissionCapability(self: App, authorization: intent.Receipt, actor: identity.Identity, subject: identity.Identity) ?AdmissionCapability {
        if (!authorization.valid()) return null;
        const issuer = self.principal() orelse return null;
        const actor_principal = authority.dataActor(actor) orelse return null;
        const subject_principal = authority.dataActor(subject) orelse return null;
        return .{
            .issuer = issuer,
            .actor = actor_principal,
            .subject = subject_principal,
            .receipt = authorization.id() orelse return null,
        };
    }

    fn admitAuthorization(self: *App, authorization: intent.Receipt, capability: AdmissionCapability) AdmissionError!void {
        if (!authorization.valid()) return error.BadArgument;
        if (!capability.permits(self.principal() orelse return error.BadArgument, authorization)) return error.BadArgument;
        const receipt_id = authorization.id() orelse return error.BadArgument;
        for (self.state.admissions.slice()) |record| {
            if (!record.valid()) return error.BadArgument;
            if (bytes.eql(&record.receipt, &receipt_id)) return;
        }
        if (self.state.admissions.full()) return error.NoSpace;
        _ = self.state.admissions.append(.{
            .receipt = receipt_id,
            .actor = capability.actor,
            .subject = capability.subject,
            .action = authorization.intent.action,
            .consequence = authorization.intent.consequence,
            .not_after = authorization.not_after,
        });
    }

    pub fn admitOwnAuthorization(self: *App, authorization: intent.Receipt, actor: identity.Identity, subject: identity.Identity) AdmissionError!void {
        const capability = self.admissionCapability(authorization, actor, subject) orelse return error.BadArgument;
        try self.admitAuthorization(authorization, capability);
    }

    pub fn admitAuthorizationFromApp(self: *App, authorization: intent.Receipt, issuer: App, actor: identity.Identity, subject: identity.Identity) AdmissionError!void {
        const capability = issuer.admissionCapability(authorization, actor, subject) orelse return error.BadArgument;
        try self.admitAuthorization(authorization, capability);
    }

    // HostChild carries the live child runtime instance. Code that holds this
    // value is in the explicit runtime authority zone, not ordinary app code.
    pub const HostChild = struct {
        app: App,
        receipt: grant.SpawnReceipt,

        pub fn handle(self: HostChild) ?ChildHandle {
            const receipt_id = self.receipt.id() orelse return null;
            const allocation = allocationFromSpawnReceipt(self.receipt) orelse return null;
            return .{
                .child = self.app.id,
                .spawn_receipt = receipt_id,
                .allocation = allocation.id() orelse return null,
                .clock_start = self.receipt.memory.epoch,
            };
        }
    };

    // ChildHandle is the app-visible child reference: proof and identity only,
    // with no direct access to child memory, storage, or execution state.
    pub const ChildHandle = struct {
        child: identity.Identity,
        spawn_receipt: preimage.Hash,
        allocation: preimage.Hash,
        clock_start: clock.Stamp,

        pub fn valid(self: ChildHandle) bool {
            return authority.Principal.app(self.child) != null and
                bytes.nonzero(&self.spawn_receipt) and
                bytes.nonzero(&self.allocation) and
                self.clock_start.valid();
        }
    };

    pub const DeclaredAllocation = struct {
        memory_bytes: usize,
        storage_bytes: usize,
        storage_slots: usize,
        storage_justification: [allocation_justification_size]u8 = [_]u8{0} ** allocation_justification_size,
        execution_ticks: u64 = 1,
        route_handles: u64 = 0,
        device_handles: u64 = 0,
        route_handle: preimage.Hash = [_]u8{0} ** preimage.hash_size,
        device_handle: identity.Id = .{ .bytes = [_]u8{0} ** identity.id_size },

        pub fn valid(self: DeclaredAllocation) bool {
            return self.memory_bytes != 0 and
                self.storageDeclarationValid() and
                self.execution_ticks != 0 and
                ((self.route_handles == 0 and bytes.zeroed(&self.route_handle)) or
                    (self.route_handles != 0 and bytes.nonzero(&self.route_handle))) and
                ((self.device_handles == 0 and !self.device_handle.valid()) or
                    (self.device_handles != 0 and self.device_handle.valid()));
        }

        fn storageDeclarationValid(self: DeclaredAllocation) bool {
            if (self.storage_bytes == 0 and self.storage_slots == 0) return true;
            if (self.storage_bytes == 0 or self.storage_slots == 0) return false;
            return true;
        }

        pub fn hasStorage(self: DeclaredAllocation) bool {
            return self.storage_bytes != 0 and self.storage_slots != 0 and
                bytes.nonzero(&self.storage_justification);
        }

        pub fn id(self: DeclaredAllocation) ?preimage.Hash {
            if (!self.valid()) return null;
            const memory_amount = @as(u64, @intCast(self.memory_bytes));
            const storage_amount = @as(u64, @intCast(self.storage_bytes));
            const slot_amount = @as(u64, @intCast(self.storage_slots));
            var raw: [allocation_body_size]u8 = undefined;
            var writer = preimage.Writer.init(&raw);
            if (!writer.writeU64(memory_amount) or
                !writer.writeU64(storage_amount) or
                !writer.writeU64(slot_amount) or
                !writer.raw(&self.storage_justification) or
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
    pub const manifest_flag_native_runtime: u32 = 2;
    pub const manifest_flag_app_private_storage: u32 = 4;
    pub const manifest_allowed_flags: u32 = manifest_flag_child_spawn | manifest_flag_native_runtime | manifest_flag_app_private_storage;

    pub const Manifest = struct {
        code_hash: preimage.Hash,
        allocation: DeclaredAllocation,
        flags: u32 = 0,

        pub fn valid(self: Manifest) bool {
            return bytes.nonzero(&self.code_hash) and
                self.allocation.valid() and
                (self.flags & ~manifest_allowed_flags) == 0;
        }

        pub fn childSpawnAllowed(self: Manifest) bool {
            return (self.flags & manifest_flag_child_spawn) != 0;
        }

        pub fn nativeRuntimeRequired(self: Manifest) bool {
            return (self.flags & manifest_flag_native_runtime) != 0;
        }

        pub fn appPrivateStorageRequired(self: Manifest) bool {
            return (self.flags & manifest_flag_app_private_storage) != 0;
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

        pub fn fromObjectFor(canonical: []const u8, owner: identity.Identity) ?Manifest {
            const owner_principal = authority.Principal.app(owner) orelse return null;
            const view = object.View.decode(canonical) catch return null;
            if (view.header.kind != .bytes or view.body.len != manifest_body_size) return null;
            if (view.header.owner_count != 1) return null;
            const object_owner = view.ownerAt(0) catch return null;
            if (object_owner.kind != .app or !bytes.eql(&object_owner.node_id, &owner_principal.id.bytes)) return null;
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
        parent: identity.Identity,
        child: identity.Identity,
        epoch: clock.Stamp,
        receipt: grant.SpawnReceipt,

        pub fn valid(self: Reclaimed) bool {
            const parent_principal = authority.Principal.app(self.parent) orelse return false;
            const child_principal = authority.Principal.app(self.child) orelse return false;
            return self.epoch.valid() and
                self.receipt.valid() and
                self.receipt.parent.eql(parent_principal.id) and
                self.receipt.child.eql(child_principal.id);
        }

        pub fn id(self: Reclaimed) ?preimage.Hash {
            if (!self.valid()) return null;
            const receipt_id = self.receipt.id().?;
            var raw: [identity.id_size * 2 + preimage.hash_size + preimage.epoch_size]u8 = undefined;
            var writer = preimage.Writer.init(&raw);
            if (!writer.id(self.parent.id) or !writer.id(self.child.id) or !writer.hash(receipt_id) or !writer.epoch(self.epoch)) return null;
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
            const memory_amount = @as(u64, @intCast(self.allocation.memory_bytes));
            const storage_amount = @as(u64, @intCast(self.allocation.storage_bytes));
            const slot_amount = @as(u64, @intCast(self.allocation.storage_slots));
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
            const req = view.header.requirements;
            const wrr = workReceiptRequirements();
            if (req.durability != wrr.durability or
                req.confidentiality != wrr.confidentiality or
                req.portability != wrr.portability or
                req.integrity != wrr.integrity or
                req.lifetime != wrr.lifetime or
                req.visibility != wrr.visibility or
                req.access != wrr.access) return error.Corrupt;
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

    pub const WorkCompletionContext = struct {
        parent: identity.Identity,
        input: preimage.Hash,
        output: preimage.Hash,
        app_hash: preimage.Hash,
        manifest: preimage.Hash,
        clock_start: clock.Stamp,
        clock_end: clock.Stamp,
        allocation: DeclaredAllocation,
        spawn_receipt: grant.SpawnReceipt,
    };

    pub const SigningCapability = struct {
        signer: identity.Identity,
        authorization: intent.Receipt,
        algorithm: object.Algorithm = .ecdsa_p256_sha256,

        pub fn permits(self: SigningCapability, epoch: clock.Stamp, parent: identity.Identity) bool {
            const parent_principal = authority.Principal.app(parent) orelse return false;
            return self.signer.id.eql(parent.id) and
                self.algorithm != .none and
                authority.receiptPermits(self.authorization, epoch, parent_principal, parent_principal, .sign_data, .attests_state);
        }
    };

    pub const Received = struct {
        app: identity.Identity,
        route: preimage.Hash,
        envelope: preimage.Hash,
        action: intent.Action,
        consequence: intent.Consequence,
        epoch: clock.Stamp,

        pub fn valid(self: Received) bool {
            return authority.Principal.app(self.app) != null and
                bytes.nonzero(&self.route) and
                bytes.nonzero(&self.envelope) and
                self.epoch.valid();
        }

        pub fn id(self: Received) ?preimage.Hash {
            if (!self.valid()) return null;

            var raw: [164]u8 = undefined;
            var writer = preimage.Writer.init(&raw);
            if (!writer.id(self.app.id) or
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
        owner: identity.Identity,
        id: preimage.Hash,
        offset: usize,
        bytes: []u8,
        epoch: clock.Stamp,

        pub fn valid(self: SharedMemory) bool {
            return authority.Principal.app(self.owner) != null and
                bytes.nonzero(&self.id) and
                self.bytes.len != 0 and
                self.epoch.valid();
        }

        pub fn readOnly(self: SharedMemory) []const u8 {
            return self.bytes;
        }
    };

    pub const ReadOnlyMemory = struct {
        owner: identity.Identity,
        allocator: identity.Identity,
        reader: identity.Identity,
        slice: preimage.Hash,
        offset: usize,
        bytes: []const u8,
        receipt: grant.MemoryViewReceipt,

        pub fn valid(self: ReadOnlyMemory) bool {
            const owner_principal = authority.Principal.app(self.owner) orelse return false;
            const allocator_principal = authority.Principal.app(self.allocator) orelse return false;
            const reader_principal = authority.Principal.app(self.reader) orelse return false;
            return owner_principal.valid() and
                allocator_principal.valid() and
                reader_principal.valid() and
                bytes.nonzero(&self.slice) and
                self.bytes.len != 0 and
                self.receipt.valid() and
                self.receipt.owner.eql(owner_principal.id) and
                self.receipt.allocator.eql(allocator_principal.id) and
                self.receipt.reader.eql(reader_principal.id) and
                bytes.eql(&self.receipt.slice, &self.slice) and
                self.receipt.offset == self.offset and
                self.receipt.memory.amount == self.bytes.len;
        }
    };

    pub const UiScratch = struct {
        codec: []u8,
        object: []u8,
        resolved: []object.View,
        components: []Component,
        nodes: []ui.Node,
    };

    pub const PublishedUi = struct {
        app: identity.Identity,
        object_id: preimage.Hash,
        epoch: clock.Stamp,

        pub fn valid(self: PublishedUi) bool {
            return authority.Principal.app(self.app) != null and bytes.nonzero(&self.object_id) and self.epoch.valid();
        }

        pub fn id(self: PublishedUi) ?preimage.Hash {
            if (!self.valid()) return null;
            var raw: [identity.id_size + preimage.hash_size + preimage.epoch_size]u8 = undefined;
            var writer = preimage.Writer.init(&raw);
            if (!writer.id(self.app.id) or !writer.hash(self.object_id) or !writer.epoch(self.epoch)) return null;
            return preimage.hash("edgerun:zig:v1:app-ui-publication", writer.written());
        }
    };

    pub const AppPrivateStorageProof = struct {
        packet: authority.Packet,
        object_id: preimage.Hash,
        policy_id: preimage.Hash,
        seal_event: preimage.Hash,
        open_event: preimage.Hash,

        pub fn valid(self: AppPrivateStorageProof) bool {
            return self.packet.valid() and
                self.packet.kind == .storage_write and
                self.packet.hasCapability(.app_private_storage) and
                bytes.nonzero(&self.object_id) and
                bytes.nonzero(&self.policy_id) and
                bytes.nonzero(&self.seal_event) and
                bytes.nonzero(&self.open_event) and
                bytes.eql(&self.packet.output_root, &self.object_id) and
                bytes.eql(&self.packet.proof, &appPrivateStorageProofHash(self.policy_id, self.seal_event, self.open_event));
        }
    };

    pub const AppPrivateStorageProofContext = struct {
        manifest: preimage.Hash,
        code_hash: preimage.Hash,
        allocation: preimage.Hash,
        resource_grant: preimage.Hash,
        pre_state: preimage.Hash,
        input_root: preimage.Hash,
        clock_start: clock.Stamp,
        clock_end: clock.Stamp,

        pub fn valid(self: AppPrivateStorageProofContext) bool {
            return bytes.nonzero(&self.manifest) and
                bytes.nonzero(&self.code_hash) and
                bytes.nonzero(&self.allocation) and
                bytes.nonzero(&self.resource_grant) and
                bytes.nonzero(&self.pre_state) and
                bytes.nonzero(&self.input_root) and
                self.clock_start.valid() and
                self.clock_end.valid() and
                self.clock_start.sameKeeper(self.clock_end) and
                self.clock_start.order(self.clock_end) <= 0;
        }
    };

    fn spawnDeclared(self: *App, allocator_id: identity.Identity, child_id: identity.Identity, epoch: clock.Stamp, authorization: intent.Receipt, allocation: DeclaredAllocation) SpawnError!HostChild {
        if (!allocation.valid()) return error.BadAllocation;
        if (!self.state.can_spawn_children) return error.Unauthorized;
        const allocator_principal = authority.Principal.app(allocator_id) orelse return error.Unauthorized;
        const child_principal = authority.Principal.app(child_id) orelse return error.Unauthorized;
        if (!self.authorizationAccepted(authorization, epoch, allocator_principal, child_principal, .spawn_app, .delegates_resources)) return error.Unauthorized;
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

    fn spawnManifest(self: *App, allocator_id: identity.Identity, child_id: identity.Identity, epoch: clock.Stamp, authorization: intent.Receipt, manifest_canonical: []const u8, code_policy: SpawnCodePolicy) SpawnError!HostChild {
        const manifest = Manifest.fromObjectFor(manifest_canonical, child_id) orelse return error.BadAllocation;
        if (manifest.nativeRuntimeRequired() and code_policy != .native_runtime_allowed) return error.Unauthorized;
        if (manifest.appPrivateStorageRequired() and !manifest.allocation.hasStorage()) return error.NoStorage;
        if (manifest.allocation.storage_bytes != 0 and !manifest.allocation.hasStorage()) return error.NoStorage;
        const manifest_id = object.Header.id(manifest_canonical);
        var spawned = try self.spawnDeclared(allocator_id, child_id, epoch, authorization, manifest.allocation);
        spawned.app.state.can_spawn_children = manifest.childSpawnAllowed();
        self.bindSpawnManifest(child_id.id, spawned.receipt, manifest_id, manifest.code_hash) catch return error.NoReceipt;
        return spawned;
    }

    pub fn completeWork(self: App, parent: identity.Identity, input: preimage.Hash, output: preimage.Hash, app_hash: preimage.Hash, manifest: preimage.Hash, clock_start: clock.Stamp, clock_end: clock.Stamp, allocation: DeclaredAllocation, spawn_receipt: grant.SpawnReceipt) ?WorkReceipt {
        return (&self).completeWorkContext(&.{
            .parent = parent,
            .input = input,
            .output = output,
            .app_hash = app_hash,
            .manifest = manifest,
            .clock_start = clock_start,
            .clock_end = clock_end,
            .allocation = allocation,
            .spawn_receipt = spawn_receipt,
        });
    }

    pub fn completeWorkContext(self: *const App, context: *const WorkCompletionContext) ?WorkReceipt {
        const parent_principal = authority.Principal.app(context.parent) orelse return null;
        if (self.state.execution_ticks > context.allocation.execution_ticks) return null;
        const receipt = WorkReceipt{
            .parent = parent_principal.id,
            .app = self.id.id,
            .input = context.input,
            .output = context.output,
            .app_hash = context.app_hash,
            .manifest = context.manifest,
            .clock_start = context.clock_start,
            .clock_end = context.clock_end,
            .allocation = context.allocation,
            .execution_used = context.allocation.execution_ticks - self.state.execution_ticks,
            .spawn_receipt = context.spawn_receipt,
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
        const self_principal = self.principal() orelse return error.Unauthorized;
        if (!self.authorizationAccepted(cap.authorization, epoch, self_principal, self_principal, .sign_data, .attests_state)) return error.Unauthorized;
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

    fn reclaimChild(self: *App, child: *App, receipt: grant.SpawnReceipt, epoch: clock.Stamp) ReclaimError!Reclaimed {
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
            .parent = self.id,
            .child = child.id,
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

    fn authorizationAccepted(self: App, authorization: intent.Receipt, epoch: clock.Stamp, actor: authority.Principal, subject: authority.Principal, action: intent.Action, consequence: intent.Consequence) bool {
        return authority.receiptPermits(authorization, epoch, actor, subject, action, consequence) and
            self.hasAdmittedAuthorization(authorization, epoch, actor, subject, action, consequence);
    }

    fn hasAdmittedAuthorization(self: App, authorization: intent.Receipt, epoch: clock.Stamp, actor: authority.Principal, subject: authority.Principal, action: intent.Action, consequence: intent.Consequence) bool {
        for (self.state.admissions.slice()) |record| {
            if (record.matches(authorization, epoch, actor, subject, action, consequence)) return true;
        }
        return false;
    }

    pub fn createRelayEnvelope(self: App, route: relay.Route, sequence: u64, payload_object: preimage.Hash, payload_hash: preimage.Hash) ?relay.Envelope {
        if (self.state.route_handles == 0) return null;
        const route_id = route.id() orelse return null;
        if (!bytes.eql(&route_id, &self.state.route_handle)) return null;
        if (!route.source.eql(self.principal() orelse return null)) return null;
        var envelope = relay.Envelope.init(route, sequence, payload_object, payload_hash) orelse return null;
        if (!envelope.sign(self.id)) return null;
        return envelope;
    }

    pub fn receiveRelayEnvelope(self: App, route: relay.Route, envelope: relay.Envelope, transit: relay.TransitReceipt, now: clock.Stamp) relay.RouteError!Received {
        if (self.state.route_handles == 0) return error.WrongDestination;
        const route_id = route.id() orelse return error.InvalidRoute;
        if (!bytes.eql(&route_id, &self.state.route_handle)) return error.WrongDestination;
        try relay.deliverTo(route, envelope, transit, self.id, now);
        return .{
            .app = self.id,
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
            .owner = self.id,
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

    pub fn proveAppPrivateStorage(self: *App, device: identity.Identity, grant_user: identity.Identity, tpm: *tpmapp.App, seal_authorization: intent.Receipt, open_authorization: intent.Receipt, context: AppPrivateStorageProofContext, out: []u8) AppPrivateStorageProofError!AppPrivateStorageProof {
        if (device.kind != .device or !device.id.eql(tpm.device.id) or grant_user.kind != .user or !context.valid()) return error.BadArgument;
        if (!seal_authorization.intent.user.eql(grant_user.id) or !open_authorization.intent.user.eql(grant_user.id)) return error.Unauthorized;
        if (out.len < object.header_size + object.owner_size + object.envelope_size + app_private_storage_proof_body.len) return error.NoSpace;

        const req = sealedAppRequirements();
        const encrypted = try object.encryptWithTpm(req, app_private_storage_proof_body, .{
            .tpm = tpm,
            .caller = self.id,
            .authorization = seal_authorization,
        });
        const owner = object.Owner{
            .kind = .app,
            .node_id = self.id.id.bytes,
        };
        const canonical = try (object.NodeWriter{ .out = out }).bytesNodeOwned(req, context.clock_end, &.{owner}, &.{encrypted.envelope}, app_private_storage_proof_body);
        const object_id = self.state.storage.putObject(self.id.id, canonical) orelse return error.NoSpace;
        const view = self.state.storage.getObject(self.id.id, object_id) orelse return error.Corrupt;
        const open_event = try object.decryptWithTpm(view, encrypted.sealed, .{
            .tpm = tpm,
            .caller = self.id,
            .authorization = open_authorization,
        });
        const policy_id = encrypted.sealed.policy.id() orelse return error.BadArgument;
        const proof_hash = appPrivateStorageProofHash(policy_id, encrypted.sealed.event_id, open_event);
        const proof = AppPrivateStorageProof{
            .packet = .{
                .kind = .storage_write,
                .root = authority.Principal.user(grant_user) orelse return error.BadArgument,
                .device = authority.Principal.device(device) orelse return error.BadArgument,
                .actor = authority.Principal.app(self.id) orelse return error.BadArgument,
                .subject = authority.Principal.tpm(tpm.id) orelse return error.BadArgument,
                .manifest = context.manifest,
                .code_hash = context.code_hash,
                .capability_flags = @intFromEnum(authority.Capability.app_private_storage),
                .resource_grant = context.resource_grant,
                .allocation = context.allocation,
                .pre_state = context.pre_state,
                .post_state = object_id,
                .input_root = context.input_root,
                .output_root = object_id,
                .clock_start = context.clock_start,
                .clock_end = context.clock_end,
                .action = .seal_data,
                .consequence = .writes_private_state,
                .proof = proof_hash,
            },
            .object_id = object_id,
            .policy_id = policy_id,
            .seal_event = encrypted.sealed.event_id,
            .open_event = open_event,
        };
        if (!proof.valid()) return error.Corrupt;
        return proof;
    }

    fn objectSealedForApp(self: App, device: identity.Identity, user: identity.Identity, canonical: []const u8) bool {
        const view = object.View.decode(canonical) catch return false;
        if (!objectRequiresSeal(view.header.requirements)) return true;
        const expected_policy = object.sealPolicyForRequirements(view.header.requirements, device, self.id, policyUserForObject(view.header.requirements, user)) orelse return false;
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

    pub fn shareMemoryReadOnly(self: App, allocator: identity.Identity, reader: identity.Identity, slice: SharedMemory, epoch: clock.Stamp, authorization: intent.Receipt) MemoryShareError!ReadOnlyMemory {
        const allocator_principal = authority.Principal.app(allocator) orelse return error.Unauthorized;
        const reader_principal = authority.Principal.app(reader) orelse return error.Unauthorized;
        return self.shareMemoryReadOnlyPrincipal(allocator, allocator_principal, reader, reader_principal, slice, epoch, authorization);
    }

    fn shareMemoryReadOnlyPrincipal(self: App, allocator_identity: identity.Identity, allocator_principal: authority.Principal, reader_identity: identity.Identity, reader_principal: authority.Principal, slice: SharedMemory, epoch: clock.Stamp, authorization: intent.Receipt) MemoryShareError!ReadOnlyMemory {
        if (!slice.valid() or !allocator_principal.valid() or !reader_principal.valid() or !slice.owner.id.eql(self.id.id) or !epoch.valid()) return error.Corrupt;
        const offset = self.state.memory.offsetOf(slice.bytes) orelse return error.Corrupt;
        if (offset != slice.offset) return error.Corrupt;
        const expected_slice = sharedMemoryId(self.id.id, offset, slice.bytes.len, slice.epoch) orelse return error.Corrupt;
        if (!bytes.eql(&expected_slice, &slice.id)) return error.Corrupt;
        if (!self.authorizationAccepted(authorization, epoch, allocator_principal, reader_principal, .grant_resource, .exports_data)) return error.Unauthorized;

        const authorization_id = authorization.id() orelse return error.Unauthorized;
        const receipt = grant.memoryViewReceipt(self.id, allocator_identity, reader_identity, slice.id, authorization_id, epoch, offset, slice.bytes.len) orelse return error.Corrupt;
        return .{
            .owner = self.id,
            .allocator = allocator_identity,
            .reader = reader_identity,
            .slice = slice.id,
            .offset = offset,
            .bytes = slice.readOnly(),
            .receipt = receipt,
        };
    }

    pub fn publishUiComponent(self: *App, component: Component, epoch: clock.Stamp, scratch: UiScratch) UiError!PublishedUi {
        if (!epoch.valid()) return error.Corrupt;
        const canonical = component.toObject(scratch.codec, scratch.object, epoch) orelse return error.NoSpace;
        const object_id = self.putPublicObject(canonical) orelse return error.NoSpace;
        return .{ .app = self.id, .object_id = object_id, .epoch = epoch };
    }

    pub fn publishUiStack(self: *App, stack: Stack, epoch: clock.Stamp, scratch: UiScratch) UiError!PublishedUi {
        if (!epoch.valid()) return error.Corrupt;
        const canonical = stack.toObject(scratch.codec, scratch.object, epoch) orelse return error.NoSpace;
        const object_id = self.putPublicObject(canonical) orelse return error.NoSpace;
        return .{ .app = self.id, .object_id = object_id, .epoch = epoch };
    }

    fn putPublicObject(self: *App, canonical: []const u8) ?preimage.Hash {
        const view = object.View.decode(canonical) catch return null;
        if (objectRequiresSeal(view.header.requirements)) return null;
        return self.state.storage.putObject(self.id.id, canonical);
    }

    pub fn renderPublishedUi(self: App, publication: PublishedUi, scratch: UiScratch, scene: *ui.Scene, bounds: ui.Rect, style: ui.Style) UiError!void {
        if (!publication.valid() or !publication.app.id.eql(self.id.id)) return error.Corrupt;
        try self.renderStoredUi(publication.object_id, scratch, scene, bounds, style);
    }

    pub fn renderStoredUi(self: App, object_id: preimage.Hash, scratch: UiScratch, scene: *ui.Scene, bounds: ui.Rect, style: ui.Style) UiError!void {
        const view = self.state.storage.getObject(self.id.id, object_id) orelse return error.MissingObject;
        scene.clear();
        try self.renderUiView(view, scratch, scene, bounds, .{ .style = style });
    }

    fn renderUiView(self: App, view: object.View, scratch: UiScratch, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) UiError!void {
        if (view.header.kind == .tree) {
            const tree = ui_resolver.resolveTree(self.state.storage, self.id.id, view, scratch.resolved, scratch.components) catch |err| return mapResolverError(err);
            return switch (tree) {
                .stack => |stack| renderUiStack(stack, scene, bounds, options),
                .slot => |slot| renderUiSlot(slot, scene, bounds, options),
            };
        }

        const stack = Stack.fromView(view, scratch.components) catch |err| return mapComponentError(err);
        return renderUiStack(stack, scene, bounds, options);
    }
};

fn renderUiStack(stack: Stack, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) App.UiError!void {
    stack.render(scene, bounds, options) catch |err| return mapUiRenderError(err);
}

fn renderUiSlot(slot: Slot, scene: *ui.Scene, bounds: ui.Rect, options: RenderOptions) App.UiError!void {
    slot.render(scene, bounds, options) catch |err| return mapUiRenderError(err);
}

fn mapUiRenderError(err: ui.RenderError) App.UiError {
    return switch (err) {
        error.CommandBudgetExceeded, error.ClipBudgetExceeded => error.RenderBudgetExceeded,
        error.InvalidBounds => error.InvalidBounds,
        error.UnsupportedComponent => error.UnsupportedComponent,
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
    const policy = object.sealPolicyForRequirements(req, device, app_id, policyUserForObject(req, user)) orelse return null;
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

fn policyUserForObject(req: object.Requirements, user: identity.Identity) ?identity.Identity {
    return switch (req.confidentiality) {
        .public, .integrity_only, .app_private, .device_private => null,
        .user_private, .user_app_private, .layered => user,
    };
}

fn appPrivateStorageProofHash(policy_id: preimage.Hash, seal_event: preimage.Hash, open_event: preimage.Hash) preimage.Hash {
    var builder = preimage.Builder.init("edgerun:zig:v1:app-private-storage-proof");
    builder.hash(policy_id);
    builder.hash(seal_event);
    builder.hash(open_event);
    return builder.final();
}

fn writeAllocationBody(allocation: App.DeclaredAllocation, out: []u8) bool {
    if (!allocation.valid() or out.len < allocation_body_size) return false;
    const memory_amount = @as(u64, @intCast(allocation.memory_bytes));
    const storage_amount = @as(u64, @intCast(allocation.storage_bytes));
    const slot_amount = @as(u64, @intCast(allocation.storage_slots));
    const joff = allocation_count_body_size;
    const hoff = joff + allocation_justification_size;
    const doff = hoff + preimage.hash_size;
    return bytes.store64(out[0..8], memory_amount) and
        bytes.store64(out[8..16], storage_amount) and
        bytes.store64(out[16..24], slot_amount) and
        bytes.store64(out[24..32], allocation.execution_ticks) and
        bytes.store64(out[32..40], allocation.route_handles) and
        bytes.store64(out[40..48], allocation.device_handles) and
        bytes.copy(out[joff..hoff], &allocation.storage_justification) and
        bytes.copy(out[hoff..doff], &allocation.route_handle) and
        bytes.copy(out[doff..][0..identity.id_size], &allocation.device_handle.bytes);
}

fn readAllocationBody(in: []const u8) ?App.DeclaredAllocation {
    if (in.len < allocation_body_size) return null;
    const joff = allocation_count_body_size;
    const hoff = joff + allocation_justification_size;
    const doff = hoff + preimage.hash_size;
    var justification: [allocation_justification_size]u8 = undefined;
    var route_handle: preimage.Hash = undefined;
    var device_handle_bytes: [identity.id_size]u8 = undefined;
    _ = bytes.copy(&justification, in[joff..hoff]);
    _ = bytes.copy(&route_handle, in[hoff..doff]);
    _ = bytes.copy(&device_handle_bytes, in[doff..][0..identity.id_size]);
    const allocation = App.DeclaredAllocation{
        .memory_bytes = blk: {
            const v = bytes.load64(in[0..8]) orelse return null;
            break :blk @as(usize, @intCast(v));
        },
        .storage_bytes = blk: {
            const v = bytes.load64(in[8..16]) orelse return null;
            break :blk @as(usize, @intCast(v));
        },
        .storage_slots = blk: {
            const v = bytes.load64(in[16..24]) orelse return null;
            break :blk @as(usize, @intCast(v));
        },
        .execution_ticks = bytes.load64(in[24..32]) orelse return null,
        .route_handles = bytes.load64(in[32..40]) orelse return null,
        .device_handles = bytes.load64(in[40..48]) orelse return null,
        .storage_justification = justification,
        .route_handle = route_handle,
        .device_handle = .{ .bytes = device_handle_bytes },
    };
    return if (allocation.valid()) allocation else null;
}

fn allocationFromSpawnReceipt(receipt: grant.SpawnReceipt) ?App.DeclaredAllocation {
    if (!receipt.valid()) return null;
    const allocation = App.DeclaredAllocation{
        .memory_bytes = @as(usize, @intCast(receipt.memory.amount)),
        .storage_bytes = @as(usize, @intCast(receipt.storage_bytes.amount)),
        .storage_slots = @as(usize, @intCast(receipt.storage_slots.amount)),
        .execution_ticks = receipt.execution_ticks.amount,
        .route_handles = receipt.route_handles.amount,
        .device_handles = receipt.device_handles.amount,
        .route_handle = receipt.route_handle,
        .device_handle = receipt.device_handle,
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

fn nativeRuntimeSignature(runtime_signer: identity.Identity, manifest_canonical: []const u8) ?preimage.Hash {
    if (runtime_signer.kind != .app or !runtime_signer.id.valid()) return null;
    _ = App.Manifest.fromObject(manifest_canonical) orelse return null;
    var builder = preimage.Builder.init("edgerun:zig:v1:native-runtime-manifest-signature");
    builder.id(runtime_signer.id);
    builder.hash(object.Header.id(manifest_canonical));
    builder.bytes(manifest_canonical);
    return builder.final();
}

fn nativeRuntimeSignatureValid(runtime_signer: identity.Identity, manifest_canonical: []const u8, runtime_signature_canonical: []const u8) bool {
    const expected = nativeRuntimeSignature(runtime_signer, manifest_canonical) orelse return false;
    const info = object.decodeSignatureReceipt(runtime_signature_canonical) catch return false;
    const manifest_id = object.Header.id(manifest_canonical);
    return runtime_signer.kind == .app and
        bytes.eql(&info.signer_id, &runtime_signer.id.bytes) and
        bytes.eql(&info.subject_id, &manifest_id) and
        bytes.eql(&info.challenge_id, &manifest_id) and
        info.algorithm == .ecdsa_p256_sha256 and
        bytes.eql(info.signature, &expected);
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

fn mapComponentError(err: component_common.Error) App.UiError {
    return switch (err) {
        error.Corrupt => error.Corrupt,
        error.UnsupportedComponent => error.UnsupportedComponent,
        error.ComponentBudgetExceeded => error.ComponentBudgetExceeded,
        error.ChildMismatch => error.ChildMismatch,
    };
}

fn sharedMemoryId(owner: identity.Id, offset: usize, len: usize, epoch: clock.Stamp) ?preimage.Hash {
    const offset_amount = @as(u64, @intCast(offset));
    const len_amount = @as(u64, @intCast(len));
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

test "execution host identity is device authority only" {
    const testing = @import("testing.zig");
    const epoch = clock.Stamp{ .keeper = .{ .bytes = [_]u8{30} ++ [_]u8{0} ** 31 } };
    const device_id = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("host authority device")).?, epoch).?;
    const app_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("host authority app")).?, epoch).?;
    const user_id = identity.Identity.init(.user, identity.Source.prepare(.hash, &preimage.rawHash("host authority user")).?, epoch).?;

    try testing.expect((ExecutionHost.init(device_id) orelse return error.TestUnexpectedResult).valid());
    try testing.expect(ExecutionHost.init(app_id) == null);
    try testing.expect(ExecutionHost.init(user_id) == null);
}

test "manifest spawn transfers declared memory and storage to child" {
    const testing = @import("testing.zig");
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
    try parent.admitOwnAuthorization(authorization, allocator_id, child_id);
    const manifest = App.Manifest{
        .code_hash = preimage.hash("edgerun:zig:v1:test-code", "bounded child"),
        .allocation = .{
            .memory_bytes = 16,
            .storage_bytes = 288,
            .storage_slots = 2,
            .storage_justification = .{ 't' } ** 64,
        },
    };
    const manifest_canonical = try App.writeManifestObject(child_id, manifest, epoch, &manifest_raw);
    var spawned = try (ExecutionHost.init(device_id).?).spawnManifest(&parent, allocator_id, child_id, epoch, authorization, manifest_canonical);
    const child_handle = spawned.handle().?;
    try testing.expect(child_handle.valid());
    try testing.expect(child_handle.child.id.eql(child_id.id));
    var child = spawned.app;
    try testing.expectEqual(@as(usize, 48), parent.state.memory.remaining());
    try testing.expectEqual(@as(usize, 224), parent.state.storage.data.len());
    try testing.expectEqual(@as(usize, 2), parent.state.storage.slotCapacity());
    try testing.expectEqual(@as(usize, 16), child.state.memory.remaining());
    try testing.expectEqual(@as(usize, 288), child.state.storage.data.len());
    try testing.expectEqual(@as(usize, 2), child.state.storage.slotCapacity());

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
    try testing.expectEqual(@as(usize, 48), parent.state.memory.remaining());
    const oversized_manifest = App.Manifest{
        .code_hash = preimage.hash("edgerun:zig:v1:test-code", "oversized child"),
        .allocation = .{
            .memory_bytes = 56,
            .storage_bytes = 0,
            .storage_slots = 0,
        },
    };
    const oversized_canonical = try App.writeManifestObject(child_id, oversized_manifest, epoch, &manifest_raw);
    try testing.expectError(error.NoMemory, (ExecutionHost.init(device_id).?).spawnManifest(&parent, allocator_id, child_id, epoch, authorization, oversized_canonical));
    try testing.expect(spawned.receipt.valid());
    try testing.expectEqual(@as(u64, 288), spawned.receipt.storage_bytes.amount);

    const reclaimed = try (ExecutionHost.init(device_id).?).reclaimChild(&parent, &child, spawned.receipt, epoch);
    try testing.expect(reclaimed.valid());
    try testing.expect(bytes.nonzero(&reclaimed.id().?));
    try testing.expectEqual(@as(usize, 64), parent.state.memory.remaining());
    try testing.expectEqual(@as(usize, 512), parent.state.storage.data.len());
    try testing.expectEqual(@as(usize, 4), parent.state.storage.slotCapacity());
    try testing.expectEqual(@as(usize, 0), child.state.memory.remaining());
    try testing.expect(child.state.storage.getObject(child.id.id, child_hash) == null);
}

test "manifest spawn can run app with no ram object storage" {
    const testing = @import("testing.zig");
    const parent_memory_bytes = 64;
    const parent_storage_bytes = 128;
    const parent_storage_slots = 2;
    const child_memory_bytes = 16;
    const child_storage_bytes = 0;
    const child_storage_slots = 0;

    var memory_bytes: [parent_memory_bytes]u8 = undefined;
    var storage_bytes: [parent_storage_bytes]u8 = undefined;
    var slots: [parent_storage_slots]store.Blob = undefined;
    var manifest_raw: [object.header_size + object.owner_size + App.manifest_body_size]u8 = undefined;

    const keeper = clock.KeeperId{ .bytes = [_]u8{21} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const user_id = identity.Identity.init(.user, identity.Source.prepare(.hash, &preimage.rawHash("memory only user")).?, epoch).?;
    const device_id = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("memory only device")).?, epoch).?;
    const parent_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("memory only parent")).?, epoch).?;
    const child_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("memory only child")).?, epoch).?;

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
    const allocation = App.DeclaredAllocation{
        .memory_bytes = child_memory_bytes,
        .storage_bytes = child_storage_bytes,
        .storage_slots = child_storage_slots,
        .execution_ticks = 1,
    };
    const manifest = App.Manifest{
        .code_hash = preimage.hash("edgerun:zig:v1:test-code", "memory only child"),
        .allocation = allocation,
    };
    const manifest_canonical = try App.writeManifestObject(child_id, manifest, epoch, &manifest_raw);
    const authorization = intent.admit(user_id, device_id, parent_id, child_id, .spawn_app, .delegates_resources, epoch, intent.requestId("memory only spawn").?).?;
    try parent.admitOwnAuthorization(authorization, parent_id, child_id);
    const spawned = try (ExecutionHost.init(device_id).?).spawnManifest(&parent, parent_id, child_id, epoch, authorization, manifest_canonical);
    var child = spawned.app;

    try testing.expect(spawned.receipt.valid());
    try testing.expectEqual(@as(u64, child_storage_bytes), spawned.receipt.storage_bytes.amount);
    try testing.expectEqual(@as(u64, child_storage_slots), spawned.receipt.storage_slots.amount);
    try testing.expectEqual(@as(usize, parent_storage_bytes), parent.state.storage.data.len());
    try testing.expectEqual(@as(usize, parent_storage_slots), parent.state.storage.slotCapacity());
    try testing.expectEqual(@as(usize, child_storage_bytes), child.state.storage.data.len());
    try testing.expectEqual(@as(usize, child_storage_slots), child.state.storage.slotCapacity());
    try testing.expect(child.state.storage.putRawBlob("implicit durable state") == null);

    _ = try (ExecutionHost.init(device_id).?).reclaimChild(&parent, &child, spawned.receipt, epoch);
    try testing.expectEqual(@as(usize, parent_storage_bytes), parent.state.storage.data.len());
    try testing.expectEqual(@as(usize, parent_storage_slots), parent.state.storage.slotCapacity());
    try testing.expectEqual(@as(usize, 0), child.state.storage.data.len());
    try testing.expectEqual(@as(usize, 0), child.state.storage.slotCapacity());
}

test "manifest declares app private storage capability and requires storage grant" {
    const testing = @import("testing.zig");
    var memory_bytes: [64]u8 = undefined;
    var storage_bytes: [128]u8 = undefined;
    var slots: [2]store.Blob = undefined;
    var manifest_raw: [object.header_size + object.owner_size + App.manifest_body_size]u8 = undefined;

    const keeper = clock.KeeperId{ .bytes = [_]u8{8} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const user_id = identity.Identity.init(.user, identity.Source.prepare(.hash, &hashMaterial("private storage manifest user")).?, epoch).?;
    const device_id = identity.Identity.init(.device, identity.Source.prepare(.hash, &hashMaterial("private storage manifest device")).?, epoch).?;
    const parent_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &hashMaterial("private storage manifest parent")).?, epoch).?;
    const child_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &hashMaterial("private storage manifest child")).?, epoch).?;

    var parent = App.initAllocated(
        parent_id,
        BoundedArena.init(.{ .base = &memory_bytes }),
        store.Store.init(.{ .base = &storage_bytes }, &slots),
        .{
            .memory_bytes = memory_bytes.len,
            .storage_bytes = storage_bytes.len,
            .storage_slots = slots.len,
            .execution_ticks = 1,
        },
    ).?;
    const manifest = App.Manifest{
        .code_hash = hashMaterial("private storage manifest code"),
        .allocation = .{
            .memory_bytes = 16,
            .storage_bytes = 0,
            .storage_slots = 0,
        },
        .flags = App.manifest_flag_app_private_storage,
    };
    const manifest_canonical = try App.writeManifestObject(child_id, manifest, epoch, &manifest_raw);
    const authorization = intent.admit(user_id, device_id, parent_id, child_id, .spawn_app, .delegates_resources, epoch, intent.requestId("private storage manifest spawn").?).?;
    try parent.admitOwnAuthorization(authorization, parent_id, child_id);

    try testing.expect(manifest.appPrivateStorageRequired());
    try testing.expect(App.Manifest.fromObject(manifest_canonical).?.appPrivateStorageRequired());
    try testing.expectError(error.NoStorage, (ExecutionHost.init(device_id).?).spawnManifest(&parent, parent_id, child_id, epoch, authorization, manifest_canonical));
}

test "app proves app private storage seal and open capability" {
    const testing = @import("testing.zig");
    var memory_bytes: [64]u8 = undefined;
    var storage_bytes: [512]u8 = undefined;
    var slots: [4]store.Blob = undefined;
    var events: [4]tpmapp.Event = undefined;
    var proof_raw: [object.header_size + object.owner_size + object.envelope_size + app_private_storage_proof_body.len]u8 = undefined;

    const keeper = clock.KeeperId{ .bytes = [_]u8{12} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const user_id = identity.Identity.init(.user, identity.Source.prepare(.hash, &hashMaterial("private storage proof user")).?, epoch).?;
    const device_id = identity.Identity.init(.device, identity.Source.prepare(.hash, &hashMaterial("private storage proof device")).?, epoch).?;
    const app_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &hashMaterial("private storage proof app")).?, epoch).?;
    const tpm_public = [_]u8{0xb3} ** identity.p256_public_size;
    const tpm_id = identity.Identity.init(.app, identity.Source.prepare(.tpm_p256_public, &tpm_public).?, epoch).?;
    const manifest_id = hashMaterial("private storage proof manifest");
    const code_hash = hashMaterial("private storage proof code");
    const allocation = App.DeclaredAllocation{
        .memory_bytes = memory_bytes.len,
        .storage_bytes = storage_bytes.len,
        .storage_slots = slots.len,
    };

    var app = App.initAllocated(
        app_id,
        BoundedArena.init(.{ .base = &memory_bytes }),
        store.Store.init(.{ .base = &storage_bytes }, &slots),
        allocation,
    ).?;
    var tpm = tpmapp.App.init(tpm_id, device_id, clock.Clock.init(keeper, .{}).?, &events).?;
    const proof_window_end = clock.Stamp{ .keeper = keeper, .tick = 2 };
    const seal_authorization = intent.admitWindow(user_id, device_id, app_id, tpm_id, .seal_data, .writes_private_state, tpm.clock.now, tpm.clock.now, proof_window_end, intent.requestId("private storage proof seal").?).?;
    const open_authorization = intent.admitWindow(user_id, device_id, app_id, tpm_id, .unseal_data, .reads_private_state, tpm.clock.now, tpm.clock.now, proof_window_end, intent.requestId("private storage proof open").?).?;
    try tpm.admitCallerAuthorization(seal_authorization, app_id);
    try tpm.admitCallerAuthorization(open_authorization, app_id);

    const proof_context = App.AppPrivateStorageProofContext{
        .manifest = manifest_id,
        .code_hash = code_hash,
        .allocation = allocation.id().?,
        .resource_grant = seal_authorization.id().?,
        .pre_state = hashMaterial("private storage proof pre-state"),
        .input_root = hashMaterial("private storage proof input"),
        .clock_start = epoch,
        .clock_end = epoch,
    };
    const proof = try app.proveAppPrivateStorage(device_id, user_id, &tpm, seal_authorization, open_authorization, proof_context, &proof_raw);
    try testing.expect(proof.valid());
    try testing.expect(proof.packet.actor.eql(authority.Principal.app(app_id).?));
    try testing.expect(proof.packet.root.eql(authority.Principal.user(user_id).?));
    try testing.expect(proof.packet.subject.eql(authority.Principal.tpm(tpm_id).?));
    try testing.expect(proof.packet.actionPermittedBy(seal_authorization, epoch));
    try testing.expectEqual(authority.PacketKind.storage_write, proof.packet.kind);
    try testing.expect(proof.packet.hasCapability(.app_private_storage));
    try testing.expectEqualSlices(u8, &manifest_id, &proof.packet.manifest);
    try testing.expectEqualSlices(u8, &code_hash, &proof.packet.code_hash);
    const stored = app.state.storage.getObject(app.id.id, proof.object_id).?;
    const envelope = try stored.envelopeAt(0);
    try testing.expectEqual(object.EnvelopeKind.app, envelope.kind);
    try testing.expectEqual(@as(usize, 2), tpm.eventCount());
}

test "native runtime manifest requires edgerun runtime signature" {
    const testing = @import("testing.zig");
    var memory_bytes: [64]u8 = undefined;
    var storage_bytes: [512]u8 = undefined;
    var slots: [4]store.Blob = undefined;
    var manifest_raw: [object.header_size + object.owner_size + App.manifest_body_size]u8 = undefined;
    var signature_raw: [object.header_size + object.signature_fixed_body_size + runtime_signature_size]u8 = undefined;

    const keeper = clock.KeeperId{ .bytes = [_]u8{31} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const user_id = identity.Identity.init(.user, identity.Source.prepare(.hash, &preimage.rawHash("native user")).?, epoch).?;
    const device_id = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("native device")).?, epoch).?;
    const parent_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("native parent")).?, epoch).?;
    const child_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("native child")).?, epoch).?;
    const runtime_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("edgerun signed runtime")).?, epoch).?;
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
    const manifest = App.Manifest{
        .code_hash = preimage.hash("edgerun:zig:v1:test-code", "native runtime child"),
        .allocation = .{
            .memory_bytes = 16,
            .storage_bytes = 0,
            .storage_slots = 0,
        },
        .flags = App.manifest_flag_native_runtime,
    };
    const manifest_canonical = try App.writeManifestObject(child_id, manifest, epoch, &manifest_raw);
    const authorization = intent.admit(user_id, device_id, parent_id, child_id, .spawn_app, .delegates_resources, epoch, intent.requestId("native runtime spawn").?).?;
    try parent.admitOwnAuthorization(authorization, parent_id, child_id);
    const host = ExecutionHost.init(device_id).?;

    try testing.expectError(error.Unauthorized, host.spawnManifest(&parent, parent_id, child_id, epoch, authorization, manifest_canonical));
    try testing.expectError(error.Unauthorized, host.spawnNativeRuntimeManifest(&parent, parent_id, child_id, epoch, authorization, manifest_canonical, runtime_id, manifest_canonical));

    const signature = nativeRuntimeSignature(runtime_id, manifest_canonical).?;
    const signature_canonical = try object.writeSignatureReceipt(manifest_canonical, manifest_canonical, runtime_id.id.bytes, .ecdsa_p256_sha256, &signature, epoch, &signature_raw);
    var spawned = try host.spawnNativeRuntimeManifest(&parent, parent_id, child_id, epoch, authorization, manifest_canonical, runtime_id, signature_canonical);
    try testing.expect(spawned.receipt.valid());
    try testing.expectEqual(@as(usize, 48), parent.state.memory.remaining());
    try testing.expectEqual(@as(usize, 16), spawned.app.state.memory.remaining());
}

test "declared allocation bounds app child work receipts and clean reclaim" {
    const testing = @import("testing.zig");
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
    const relay_id = identity.Identity.init(.relay, identity.Source.prepare(.hash, &preimage.rawHash("declared relay")).?, start).?;
    var route = relay.Route.init(route_admission, child_id, grandchild_id, .sync_data, .exports_data, hashMaterial("declared route policy")).?;
    try testing.expect(route.appendRelay(relay_id));
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
        .storage_justification = @as([64]u8, @splat(@as(u8, 'c'))),
    };
    const child_manifest = App.Manifest{
        .code_hash = preimage.hash("edgerun:zig:v1:test-code", "declared child code"),
        .allocation = child_allocation,
        .flags = App.manifest_flag_child_spawn,
    };
    const child_manifest_canonical = try App.writeManifestObject(child_id, child_manifest, start, &child_manifest_raw);
    const child_manifest_id = object.Header.id(child_manifest_canonical);
    try testing.expectEqual(child_manifest.allocation, App.Manifest.fromObject(child_manifest_canonical).?.allocation);
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
    try parent.admitOwnAuthorization(child_authorization, parent_id, child_id);

    const spawned_child = try (ExecutionHost.init(device_id).?).spawnManifest(&parent, parent_id, child_id, start, child_authorization, child_manifest_canonical);
    var child = spawned_child.app;
    try testing.expectEqual(@as(usize, parent_memory_bytes - child_memory_bytes), parent.state.memory.remaining());
    try testing.expectEqual(@as(usize, child_memory_bytes), child.state.memory.remaining());
    try testing.expectEqual(@as(usize, child_storage_bytes), child.state.storage.data.len());
    try testing.expectEqual(@as(usize, child_storage_slots), child.state.storage.slotCapacity());
    try testing.expectEqual(@as(u64, parent_execution_ticks - child_execution_ticks), parent.state.execution_ticks);
    try testing.expectEqual(@as(u64, child_execution_ticks), child.state.execution_ticks);
    try testing.expectEqual(@as(u64, child_route_handles), child.state.route_handles);
    try testing.expectEqual(@as(u64, child_device_handles), child.state.device_handles);
    try testing.expect(!child.state.memory.owns(memory_bytes[0..4]));
    try testing.expect(!child.state.storage.owned.contains(storage_bytes[0..4]));

    const child_allocator = child.state.memory.allocator();
    _ = try child_allocator.alloc(u8, child_private_bytes);
    try testing.expectError(error.OutOfMemory, child_allocator.alloc(u8, child_memory_bytes));
    try testing.expect(child.state.storage.putRawBlob(&oversized_storage) == null);
    try testing.expect(!child.consumeExecution(child_execution_ticks + 1));
    try testing.expect(child.useDevice(device_id));
    try testing.expect(!child.useDevice(wrong_device_id));

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
    try child.admitOwnAuthorization(grandchild_authorization, child_id, grandchild_id);
    const forged_parent_slice = App.SharedMemory{
        .owner = child.id,
        .id = hashMaterial("forged parent memory slice"),
        .offset = 0,
        .bytes = memory_bytes[0..4],
        .epoch = start,
    };
    try testing.expectError(error.Corrupt, child.shareMemoryReadOnly(child_id, grandchild_id, forged_parent_slice, start, grandchild_authorization));
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
    try testing.expectError(error.NoMemory, (ExecutionHost.init(device_id).?).spawnDeclared(&child, child_id, grandchild_id, start, grandchild_authorization, impossible_grandchild));

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
    try testing.expectError(error.NoRoute, (ExecutionHost.init(device_id).?).spawnDeclared(&child, child_id, grandchild_id, start, grandchild_authorization, impossible_route_grandchild));

    const grandchild_allocation = App.DeclaredAllocation{
        .memory_bytes = grandchild_memory_bytes,
        .storage_bytes = grandchild_storage_bytes,
        .storage_slots = grandchild_storage_slots,
        .execution_ticks = grandchild_execution_ticks,
        .route_handles = grandchild_route_handles,
        .device_handles = grandchild_device_handles,
        .route_handle = route_id,
        .device_handle = device_id.id,
        .storage_justification = @as([64]u8, @splat(@as(u8, 'g'))),
    };
    const grandchild_manifest = App.Manifest{
        .code_hash = preimage.hash("edgerun:zig:v1:test-code", "declared grandchild code"),
        .allocation = grandchild_allocation,
    };
    const grandchild_manifest_canonical = try App.writeManifestObject(grandchild_id, grandchild_manifest, start, &grandchild_manifest_raw);
    const grandchild_manifest_id = object.Header.id(grandchild_manifest_canonical);
    const spawned_grandchild = try (ExecutionHost.init(device_id).?).spawnManifest(&child, child_id, grandchild_id, start, grandchild_authorization, grandchild_manifest_canonical);
    var grandchild = spawned_grandchild.app;
    try testing.expectEqual(@as(usize, grandchild_memory_bytes), grandchild.state.memory.remaining());
    try testing.expectEqual(@as(usize, grandchild_storage_bytes), grandchild.state.storage.data.len());
    try testing.expectEqual(@as(u64, child_execution_ticks - grandchild_execution_ticks), child.state.execution_ticks);
    try testing.expectEqual(@as(u64, 0), child.state.route_handles);
    try testing.expectEqual(@as(u64, 0), child.state.device_handles);
    try testing.expect(!child.useDevice(device_id));
    try testing.expect(grandchild.useDevice(device_id));
    try testing.expect(!grandchild.useDevice(wrong_device_id));
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
    try testing.expectError(error.Unauthorized, (ExecutionHost.init(device_id).?).spawnDeclared(&grandchild, grandchild_id, great_grandchild_id, start, great_grandchild_authorization, grandchild_allocation));

    try testing.expect(child.createRelayEnvelope(route, 1, hashMaterial("route object"), hashMaterial("route payload")) == null);
    try testing.expect(!grandchild.consumeExecution(grandchild_execution_ticks + 1));

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
    const work = grandchild.completeWork(child.id, input_hash, output_hash, grandchild_manifest.code_hash, grandchild_manifest_id, start, end, grandchild_allocation, spawned_grandchild.receipt).?;
    try testing.expect(work.valid());
    try testing.expect(bytes.nonzero(&work.id().?));
    try testing.expect(bytes.eql(&work.manifest, &grandchild_manifest_id));
    try testing.expect(bytes.nonzero(&child_manifest_id));
    try testing.expect(work.clock_start.order(work.clock_end) < 0);
    const work_receipt_object_id = try grandchild.putWorkReceipt(work, end, &work_receipt_raw);
    try testing.expect(bytes.eql(&work_receipt_object_id, &object.Header.id(&work_receipt_raw)));
    const stored_work_receipt = grandchild.state.storage.getReceipt(grandchild.id.id, work_receipt_object_id).?;
    try testing.expectEqual(object.Kind.receipt, stored_work_receipt.header.kind);
    try testing.expectEqual(workReceiptRequirements(), stored_work_receipt.header.requirements);
    const decoded_work_receipt = try App.WorkReceipt.decodeObject(&work_receipt_raw);
    try testing.expect(decoded_work_receipt.matches(work));
    try testing.expect(decoded_work_receipt.parent.eql(child.id.id));
    try testing.expect(decoded_work_receipt.app.eql(grandchild.id.id));
    try testing.expect(bytes.eql(&decoded_work_receipt.output, &output_hash));
    try testing.expect(bytes.eql(&decoded_work_receipt.app_hash, &grandchild_manifest.code_hash));
    try testing.expect(bytes.eql(&decoded_work_receipt.manifest, &grandchild_manifest_id));
    try testing.expect(App.WorkReceipt.decodeBody(stored_work_receipt.body).?.matches(work));
    try testing.expectError(error.Corrupt, App.WorkReceipt.decodeObject(output_canonical));
    var wrong_route_receipt = spawned_grandchild.receipt;
    wrong_route_receipt.route_handle = hashMaterial("wrong receipt route");
    try testing.expect(grandchild.completeWork(child.id, input_hash, output_hash, grandchild_manifest.code_hash, grandchild_manifest_id, start, end, grandchild_allocation, wrong_route_receipt) == null);

    try testing.expectError(error.Corrupt, (ExecutionHost.init(device_id).?).reclaimChild(&parent, &child, spawned_child.receipt, end));
    try testing.expectError(error.Corrupt, (ExecutionHost.init(device_id).?).reclaimChild(&child, &grandchild, wrong_route_receipt, end));
    const grandchild_reclaim = try (ExecutionHost.init(device_id).?).reclaimChild(&child, &grandchild, spawned_grandchild.receipt, end);
    try testing.expect(grandchild_reclaim.valid());
    try testing.expectEqual(@as(usize, 0), grandchild.state.memory.remaining());
    try testing.expect(grandchild.state.storage.getObject(grandchild.id.id, output_hash) == null);
    try testing.expectEqual(@as(u64, child_execution_ticks), child.state.execution_ticks);
    try testing.expectEqual(@as(u64, child_route_handles), child.state.route_handles);
    try testing.expectEqual(@as(u64, child_device_handles), child.state.device_handles);

    const child_reclaim = try (ExecutionHost.init(device_id).?).reclaimChild(&parent, &child, spawned_child.receipt, end);
    try testing.expect(child_reclaim.valid());
    try testing.expectEqual(@as(usize, parent_memory_bytes), parent.state.memory.remaining());
    try testing.expectEqual(@as(usize, parent_storage_bytes), parent.state.storage.data.len());
    try testing.expectEqual(@as(usize, parent_storage_slots), parent.state.storage.slotCapacity());
    try testing.expectEqual(@as(u64, parent_execution_ticks), parent.state.execution_ticks);
    try testing.expectEqual(@as(u64, parent_route_handles), parent.state.route_handles);
    try testing.expectEqual(@as(u64, parent_device_handles), parent.state.device_handles);
    try testing.expectEqual(@as(usize, 0), child.state.memory.remaining());
}

test "minimum containment memory storage and reclaim laws" {
    const testing = @import("testing.zig");
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
        .storage_justification = @as([64]u8, @splat(@as(u8, 'c'))),
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
    try parent.admitOwnAuthorization(child_authorization, parent_id, child_id);
    const spawned_child = try (ExecutionHost.init(device_id).?).spawnManifest(&parent, parent_id, child_id, epoch, child_authorization, child_manifest_canonical);
    var child = spawned_child.app;

    const child_allocator = child.state.memory.allocator();
    const child_memory = try child_allocator.alloc(u8, 1);
    child_memory[0] = 0x11;
    try testing.expect(!child.state.memory.owns(memory_bytes[0..1]));

    try testing.expect(child.state.storage.putRawBlob(&oversized_storage) == null);
    const sibling_secret = sibling.state.storage.putRawBlob("sibling secret").?;
    try testing.expect(child.state.storage.get(sibling_secret) == null);

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
    try child.admitOwnAuthorization(grandchild_authorization, child_id, grandchild_id);
    const grandchild_manifest = App.Manifest{
        .code_hash = preimage.hash("edgerun:zig:v1:test-code", "minimum laws grandchild code"),
        .allocation = .{
            .memory_bytes = grandchild_memory_bytes,
            .storage_bytes = grandchild_storage_bytes,
            .storage_slots = grandchild_storage_slots,
            .execution_ticks = grandchild_execution_ticks,
            .storage_justification = @as([64]u8, @splat(@as(u8, 'g'))),
        },
    };
    const grandchild_manifest_canonical = try App.writeManifestObject(grandchild_id, grandchild_manifest, epoch, &grandchild_manifest_raw);
    const spawned_grandchild = try (ExecutionHost.init(device_id).?).spawnManifest(&child, child_id, grandchild_id, epoch, grandchild_authorization, grandchild_manifest_canonical);
    var grandchild = spawned_grandchild.app;
    try testing.expectEqual(@as(u64, child_execution_ticks - grandchild_execution_ticks), child.state.execution_ticks);
    try testing.expectEqual(@as(usize, grandchild_memory_bytes), grandchild.state.memory.remaining());
    try testing.expectEqual(@as(usize, parent_memory_bytes - child_memory_bytes), parent.state.memory.remaining());

    try testing.expectError(error.Corrupt, (ExecutionHost.init(device_id).?).reclaimChild(&parent, &child, spawned_child.receipt, epoch));
    _ = try (ExecutionHost.init(device_id).?).reclaimChild(&child, &grandchild, spawned_grandchild.receipt, epoch);
    _ = try (ExecutionHost.init(device_id).?).reclaimChild(&parent, &child, spawned_child.receipt, epoch);
    try testing.expectEqual(@as(usize, parent_memory_bytes), parent.state.memory.remaining());
    try testing.expectEqual(@as(usize, parent_storage_bytes), parent.state.storage.data.len());
    try testing.expectEqual(@as(usize, 0), child.state.memory.remaining());
    try testing.expectEqual(@as(usize, 0), child.state.storage.data.len());
    try testing.expectError(error.Corrupt, (ExecutionHost.init(device_id).?).reclaimChild(&parent, &child, spawned_child.receipt, epoch));
}

test "minimum containment child cannot write byte past 4kb allocation" {
    const testing = @import("testing.zig");
    const child_memory_bytes = 4096;
    var memory_bytes: [child_memory_bytes]u8 = undefined;
    var arena = BoundedArena.init(.{ .base = &memory_bytes });
    const allocator = arena.allocator();

    const full_child_memory = try allocator.alloc(u8, child_memory_bytes);
    full_child_memory[child_memory_bytes - 1] = 0x11;
    try testing.expectError(error.OutOfMemory, allocator.alloc(u8, 1));
}

test "minimum containment rejects parent allocation id as child memory id" {
    const testing = @import("testing.zig");
    const parent_memory_bytes = 128;
    const parent_storage_bytes = 256;
    const parent_storage_slots = 4;
    const child_memory_bytes = 64;
    const child_storage_bytes = 0;
    const child_storage_slots = 0;

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
    try parent.admitOwnAuthorization(authorization, parent_id, child_id);
    const spawned = try (ExecutionHost.init(device_id).?).spawnManifest(&parent, parent_id, child_id, epoch, authorization, manifest_canonical);
    var child = spawned.app;
    const child_memory = try child.state.memory.allocator().alloc(u8, 1);
    const forged_allocation_slice = App.SharedMemory{
        .owner = child.id,
        .id = parent_allocation.id().?,
        .offset = 0,
        .bytes = child_memory,
        .epoch = epoch,
    };
    const share_authorization = intent.admit(user_id, device_id, child_id, reader_id, .grant_resource, .exports_data, epoch, intent.requestId("allocation id forged share").?).?;
    try testing.expectError(error.Corrupt, child.shareMemoryReadOnly(child_id, reader_id, forged_allocation_slice, epoch, share_authorization));
}

test "minimum containment routes devices receipts and revoked handles" {
    const testing = @import("testing.zig");
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
    const relay_id = identity.Identity.init(.relay, identity.Source.prepare(.hash, &preimage.rawHash("receipt laws relay")).?, start).?;
    var route = relay.Route.init(route_admission, child_id, other_id, .sync_data, .exports_data, hashMaterial("receipt laws route policy")).?;
    try testing.expect(route.appendRelay(relay_id));
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
        .storage_justification = @as([64]u8, @splat(@as(u8, 'r'))),
    };
    const child_manifest = App.Manifest{
        .code_hash = preimage.hash("edgerun:zig:v1:test-code", "receipt laws child code"),
        .allocation = child_allocation,
    };
    const child_manifest_canonical = try App.writeManifestObject(child_id, child_manifest, start, &child_manifest_raw);
    const child_manifest_id = object.Header.id(child_manifest_canonical);
    const authorization = intent.admit(user_id, device_id, parent_id, child_id, .spawn_app, .delegates_resources, start, intent.requestId("receipt laws spawn").?).?;
    try parent.admitOwnAuthorization(authorization, parent_id, child_id);
    const spawned = try (ExecutionHost.init(device_id).?).spawnManifest(&parent, parent_id, child_id, start, authorization, child_manifest_canonical);
    var child = spawned.app;

    try testing.expect(child.createRelayEnvelope(route, 1, hashMaterial("receipt laws object"), hashMaterial("receipt laws payload")) != null);
    child.state.route_handle = different_route_id;
    try testing.expect(child.createRelayEnvelope(route, 2, hashMaterial("receipt laws object"), hashMaterial("receipt laws payload")) == null);
    child.state.route_handle = route_id;
    try testing.expect(child.useDevice(device_id));
    try testing.expect(!child.useDevice(other_device_id));
    try testing.expect(child.consumeExecution(used_execution_ticks));

    const owner = object.Owner{ .kind = .app, .node_id = child.id.id.bytes };
    const output_req = sealedAppRequirements();
    const envelope = sealedEnvelopeForApp(device_id, child_id, user_id, output_req, "receipt laws output key").?;
    const output_canonical = try (object.NodeWriter{ .out = &work_output_raw }).bytesNodeOwned(output_req, start, &.{owner}, &.{envelope}, "output");
    const output_hash = child.putSealedObject(device_id, user_id, output_canonical).?;
    const input_hash = hashMaterial("receipt laws input");
    child.state.execution_ticks = child_execution_ticks;
    const work = child.completeWork(parent.id, input_hash, output_hash, child_manifest.code_hash, child_manifest_id, start, end, child_allocation, spawned.receipt).?;
    const first_receipt_id = try child.putWorkReceipt(work, end, &receipt_raw);
    const second_receipt_id = try child.putWorkReceipt(work, end, &receipt_again_raw);
    try testing.expectEqualSlices(u8, &receipt_raw, &receipt_again_raw);
    try testing.expect(bytes.eql(&first_receipt_id, &second_receipt_id));

    var tampered_receipt = receipt_raw;
    tampered_receipt[object.header_size + identity.id_size * 2] ^= 1;
    const tampered_info = try App.WorkReceipt.decodeObject(&tampered_receipt);
    try testing.expect(!tampered_info.matches(work));

    _ = try (ExecutionHost.init(device_id).?).reclaimChild(&parent, &child, spawned.receipt, end);
    try testing.expect(!child.useDevice(device_id));
    try testing.expect(child.createRelayEnvelope(route, 3, hashMaterial("receipt laws object"), hashMaterial("receipt laws payload")) == null);
    try testing.expect(!child.consumeExecution(1));
}

test "minimum containment work receipt records ticks used" {
    const testing = @import("testing.zig");
    const parent_memory_bytes = 128;
    const parent_storage_bytes = 1024;
    const parent_storage_slots = 4;
    const child_memory_bytes = 64;
    const child_storage_bytes = 0;
    const child_storage_slots = 0;
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
    try parent.admitOwnAuthorization(authorization, parent_id, child_id);
    const spawned = try (ExecutionHost.init(device_id).?).spawnManifest(&parent, parent_id, child_id, start, authorization, manifest_canonical);
    var child = spawned.app;

    try testing.expect(child.consumeExecution(used_execution_ticks));
    const work = child.completeWork(parent.id, hashMaterial("usage input"), hashMaterial("usage output"), manifest.code_hash, manifest_id, start, end, allocation, spawned.receipt).?;
    try testing.expectEqual(@as(u64, used_execution_ticks), work.execution_used);
}

test "parent signs validated work receipt drafts" {
    const testing = @import("testing.zig");
    const parent_memory_bytes = 128;
    const parent_storage_bytes = 1024;
    const parent_storage_slots = 4;
    const child_memory_bytes = 64;
    const child_storage_bytes = 0;
    const child_storage_slots = 0;
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
    try parent.admitOwnAuthorization(authorization, parent_id, child_id);
    const spawned = try (ExecutionHost.init(device_id).?).spawnManifest(&parent, parent_id, child_id, start, authorization, manifest_canonical);
    var child = spawned.app;
    const input_hash = hashMaterial("signed input");
    const output_hash = hashMaterial("signed output");
    const work = child.completeWork(parent.id, input_hash, output_hash, manifest.code_hash, manifest_id, start, end, allocation, spawned.receipt).?;
    const draft = try work.writeObject(end, &draft_raw);
    try testing.expectError(error.Corrupt, object.decodeSignatureReceipt(draft));

    const signing_authorization = intent.admit(user_id, device_id, parent_id, parent_id, .sign_data, .attests_state, end, intent.requestId("parent signs accepted work").?).?;
    try parent.admitOwnAuthorization(signing_authorization, parent_id, parent_id);
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
    try testing.expect(App.verifySignedWorkReceipt(draft, signed, capability));
    try testing.expectError(error.Corrupt, parent.signWorkReceiptDraft(draft, context, end, capability, &signed_raw));

    var tampered_draft = draft_raw;
    tampered_draft[object.header_size + identity.id_size * 2] ^= 1;
    try testing.expect(!App.verifySignedWorkReceipt(&tampered_draft, signed, capability));
    try testing.expectError(error.Corrupt, parent.signWorkReceiptDraft(&tampered_draft, context, end, capability, &signed_raw));

    var wrong_allocation_context = context;
    wrong_allocation_context.allocation.storage_bytes += 1;
    try testing.expectError(error.BadArgument, parent.signWorkReceiptDraft(draft, wrong_allocation_context, end, capability, &signed_raw));

    var impossible_usage_context = context;
    impossible_usage_context.execution_used = allocation.execution_ticks + 1;
    try testing.expectError(error.BadArgument, parent.signWorkReceiptDraft(draft, impossible_usage_context, end, capability, &signed_raw));

    const overlap_start = clock.Stamp{ .keeper = keeper, .tick = 15 };
    const overlap_end = clock.Stamp{ .keeper = keeper, .tick = 25 };
    const overlap_work = child.completeWork(parent.id, hashMaterial("overlap input"), hashMaterial("overlap output"), manifest.code_hash, manifest_id, overlap_start, overlap_end, allocation, spawned.receipt).?;
    const overlap_draft = try overlap_work.writeObject(overlap_end, &overlap_draft_raw);
    var overlap_context = context;
    overlap_context.input = hashMaterial("overlap input");
    overlap_context.output = hashMaterial("overlap output");
    overlap_context.clock_start = overlap_start;
    overlap_context.clock_end = overlap_end;
    try testing.expectError(error.Corrupt, parent.signWorkReceiptDraft(overlap_draft, overlap_context, end, capability, &signed_raw));

    const backward_start = clock.Stamp{ .keeper = keeper, .tick = 5 };
    const backward_end = clock.Stamp{ .keeper = keeper, .tick = 9 };
    const backward_work = child.completeWork(parent.id, hashMaterial("backward input"), hashMaterial("backward output"), manifest.code_hash, manifest_id, backward_start, backward_end, allocation, spawned.receipt).?;
    const backward_draft = try backward_work.writeObject(backward_end, &backward_draft_raw);
    var backward_context = context;
    backward_context.input = hashMaterial("backward input");
    backward_context.output = hashMaterial("backward output");
    backward_context.clock_start = backward_start;
    backward_context.clock_end = backward_end;
    try testing.expectError(error.Corrupt, parent.signWorkReceiptDraft(backward_draft, backward_context, end, capability, &signed_raw));

    const wrong_manifest_work = child.completeWork(parent.id, input_hash, output_hash, manifest.code_hash, hashMaterial("wrong manifest"), start, end, allocation, spawned.receipt).?;
    const wrong_manifest_draft = try wrong_manifest_work.writeObject(end, &wrong_manifest_draft_raw);
    try testing.expectError(error.Corrupt, parent.signWorkReceiptDraft(wrong_manifest_draft, context, end, capability, &signed_raw));

    const other_signing_authorization = intent.admit(user_id, device_id, other_parent_id, other_parent_id, .sign_data, .attests_state, end, intent.requestId("other parent signs accepted work").?).?;
    try other_parent.admitOwnAuthorization(other_signing_authorization, other_parent_id, other_parent_id);
    const other_capability = App.SigningCapability{
        .signer = other_parent_id,
        .authorization = other_signing_authorization,
    };
    try testing.expectError(error.BadArgument, other_parent.signWorkReceiptDraft(draft, context, end, other_capability, &signed_raw));

    const expired_authorization = intent.admitWindow(user_id, device_id, parent_id, parent_id, .sign_data, .attests_state, start, start, start, intent.requestId("expired parent signing").?).?;
    try parent.admitOwnAuthorization(expired_authorization, parent_id, parent_id);
    const expired_capability = App.SigningCapability{
        .signer = parent_id,
        .authorization = expired_authorization,
    };
    try testing.expectError(error.Unauthorized, parent.signWorkReceiptDraft(draft, context, end, expired_capability, &signed_raw));

    try testing.expectError(error.Unauthorized, parent.signWorkReceiptDraft(draft, context, end, null, &signed_raw));
}

test "app creates its store from its host-owned memory slice" {
    const testing = @import("testing.zig");
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
    try testing.expectEqualStrings("state", app.state.storage.getObject(app.id.id, hash).?.body);
    try testing.expect(app.state.memory.remaining() < 640);
}

test "app storage requires seal envelope for private durable objects" {
    const testing = @import("testing.zig");
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
    try testing.expect(app.putSealedObject(device_id, user_id, unsealed) == null);

    const wrong_envelope = sealedEnvelopeForApp(wrong_device_id, app_id, user_id, req, "state key").?;
    const wrong_sealed = try (object.NodeWriter{ .out = &wrong_seal_raw }).bytesNodeOwned(req, epoch, &.{owner}, &.{wrong_envelope}, "state");
    try testing.expect(app.putSealedObject(device_id, user_id, wrong_sealed) == null);

    const envelope = sealedEnvelopeForApp(device_id, app_id, user_id, req, "state key").?;
    const sealed_object = try (object.NodeWriter{ .out = &sealed_raw }).bytesNodeOwned(req, epoch, &.{owner}, &.{envelope}, "state");
    const object_id = app.putSealedObject(device_id, user_id, sealed_object).?;
    const stored = app.state.storage.getObject(app.id.id, object_id).?;
    try testing.expectEqual(object.Integrity.sealed, stored.header.requirements.integrity);
    try testing.expectEqual(object.EnvelopeKind.app, (try stored.envelopeAt(0)).kind);
}

test "app shares owned memory read only for direct ui updates" {
    const testing = @import("testing.zig");
    var producer_memory: [512]u8 = undefined;
    var ui_memory: [256]u8 = undefined;

    const keeper = clock.KeeperId{ .bytes = [_]u8{6} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const user_id = identity.Identity.init(.user, identity.Source.prepare(.hash, &preimage.rawHash("share user")).?, epoch).?;
    const device_id = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("share device")).?, epoch).?;
    const allocator_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("share allocator")).?, epoch).?;
    const producer_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("producer app")).?, epoch).?;
    const ui_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("ui app reader")).?, epoch).?;
    var producer = App.initFromHostSlice(producer_id, BoundedArena.init(.{ .base = &producer_memory }), 64, 2).?;
    _ = App.initFromHostSlice(ui_id, BoundedArena.init(.{ .base = &ui_memory }), 64, 2).?;

    var shared = try producer.reserveSharedMemory(16, "ui-state", epoch);
    _ = bytes.copy(shared.bytes[0..5], "ready");
    const authorization = intent.admit(
        user_id,
        device_id,
        allocator_id,
        ui_id,
        .grant_resource,
        .exports_data,
        epoch,
        intent.requestId("share ui state").?,
    ).?;
    try producer.admitOwnAuthorization(authorization, allocator_id, ui_id);

    const view = try producer.shareMemoryReadOnly(allocator_id, ui_id, shared, epoch, authorization);
    try testing.expect(view.valid());
    try testing.expect(view.allocator.id.eql(allocator_id.id));
    try testing.expect(view.receipt.allocator.eql(allocator_id.id));
    try testing.expect(bytes.eql(&view.receipt.authorization, &authorization.id().?));
    try testing.expectEqual(grant.Resource.read_only_memory, view.receipt.memory.resource);
    try testing.expectEqualStrings("ready", view.bytes[0..5]);

    _ = bytes.copy(shared.bytes[0..5], "paint");
    try testing.expectEqualStrings("paint", view.bytes[0..5]);
}

test "app publishes canonical ui component and renders from object storage" {
    const testing = @import("testing.zig");
    var host_memory: [4096]u8 = undefined;
    const keeper = clock.KeeperId{ .bytes = [_]u8{4} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const app_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("ui app")).?, epoch).?;
    var app = App.initFromHostSlice(app_id, BoundedArena.init(.{ .base = &host_memory }), 1024, 8).?;

    var codec_raw: [256]u8 = undefined;
    var object_raw: [object.header_size + 256]u8 = undefined;
    var resolved: [1]object.View = undefined;
    var component_scratch: [4]Component = undefined;
    var node_scratch: [4]ui.Node = undefined;
    const scratch = App.UiScratch{
        .codec = &codec_raw,
        .object = &object_raw,
        .resolved = &resolved,
        .components = &component_scratch,
        .nodes = &node_scratch,
    };

    const published = try app.publishUiComponent(.{ .button = .{ .id = 42, .label = "Open" } }, epoch, scratch);
    try testing.expect(published.valid());
    try testing.expect(bytes.nonzero(&published.id().?));

    const stored = app.state.storage.getObject(app.id.id, published.object_id).?;
    try testing.expectEqual(object.Kind.bytes, stored.header.kind);
    try testing.expectEqual(object.Confidentiality.app_private, stored.header.requirements.confidentiality);
    try testing.expectEqual(object.Visibility.app_namespace, stored.header.requirements.visibility);

    var commands: [16]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try app.renderPublishedUi(published, scratch, &scene, .{ .x = 0, .y = 0, .w = 160, .h = 64 }, .{});
    try testing.expect(scene.commandCount() > 0);
}

test "app publishes stack ui as one canonical render object" {
    const testing = @import("testing.zig");
    var host_memory: [8192]u8 = undefined;
    const keeper = clock.KeeperId{ .bytes = [_]u8{5} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const app_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("stack ui app")).?, epoch).?;
    var app = App.initFromHostSlice(app_id, BoundedArena.init(.{ .base = &host_memory }), 2048, 8).?;

    const children = [_]Component{
        .{ .text = .{ .value = "Objects" } },
        .{ .row_item = .{ .id = 7, .title = "Storage", .detail = "canonical" } },
        .{ .button = .{ .id = 8, .label = "Render" } },
    };
    const stack = Stack{ .axis = .column, .gap = 6, .padding = 8, .children = &children };

    var codec_raw: [512]u8 = undefined;
    var object_raw: [object.header_size + 512]u8 = undefined;
    var resolved: [1]object.View = undefined;
    var component_scratch: [4]Component = undefined;
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
    try testing.expect(scene.commandCount() >= 6);
}

test "apps exchange identity routed envelopes through relay boundary" {
    const testing = @import("testing.zig");
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
    try testing.expect(route.appendRelay(relay_id));
    const route_id = route.id().?;
    source.state.route_handles = 1;
    target.state.route_handles = 1;
    source.state.route_handle = route_id;
    target.state.route_handle = route_id;

    const envelope = source.createRelayEnvelope(route, 1, hashMaterial("message object"), hashMaterial("sealed to target")).?;
    var public_relay = relay.RelayApp.init(relay_id).?;
    const transit = try public_relay.forward(route, envelope, now);
    try testing.expect(transit.valid());

    var forged_transit = transit;
    forged_transit.to = authority.Principal.app(source_id).?;
    try testing.expectError(error.WrongRelay, target.receiveRelayEnvelope(route, envelope, forged_transit, now));

    const received = try target.receiveRelayEnvelope(route, envelope, transit, now);
    try testing.expect(received.valid());
    try testing.expect(bytes.nonzero(&received.id().?));
}
