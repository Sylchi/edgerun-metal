const std = @import("std");
const BoundedArena = @import("arena.zig").BoundedArena;
const bytes = @import("bytes.zig");
const clock = @import("clock.zig");
const grant = @import("grant.zig");
const identity = @import("identity.zig");
const intent = @import("intent.zig");
const preimage = @import("preimage.zig");
const relay = @import("relay.zig");
const store = @import("store.zig");
const object = @import("object.zig");
const ui = @import("ui.zig");
const ui_components = @import("ui_components.zig");
const ui_resolver = @import("ui_resolver.zig");

pub const SpawnError = error{
    NoMemory,
    NoStorage,
    Unauthorized,
};

pub const App = struct {
    id: identity.Identity,
    memory: BoundedArena,
    storage: store.Store,

    pub fn init(id: identity.Identity, memory: BoundedArena, storage: store.Store) App {
        return .{
            .id = id,
            .memory = memory,
            .storage = storage,
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

    pub fn spawn(self: *App, allocator_id: identity.Identity, child_id: identity.Identity, epoch: clock.Stamp, authorization: intent.Receipt, memory_bytes: usize, storage_bytes: usize, storage_slots: usize) SpawnError!Spawned {
        if (!authorization.permitsAt(epoch, allocator_id.id, child_id.id, .spawn_app, .delegates_resources)) {
            return error.Unauthorized;
        }

        const child_memory = self.memory.split(memory_bytes) orelse return error.NoMemory;
        const child_storage = self.storage.split(.{
            .data_bytes = storage_bytes,
            .slot_count = storage_slots,
        }) orelse return error.NoStorage;
        const receipt = grant.spawnReceipt(self.id, child_id, epoch, memory_bytes, storage_bytes, storage_slots) orelse return error.NoMemory;

        return .{
            .app = .{
                .id = child_id,
                .memory = child_memory,
                .storage = child_storage,
            },
            .receipt = receipt,
        };
    }

    pub fn createRelayEnvelope(self: App, route: relay.Route, sequence: u64, payload_object: preimage.Hash, payload_hash: preimage.Hash) ?relay.Envelope {
        if (!route.source.eql(self.id.id)) return null;
        var envelope = relay.Envelope.init(route, sequence, payload_object, payload_hash) orelse return null;
        if (!envelope.sign(self.id)) return null;
        return envelope;
    }

    pub fn receiveRelayEnvelope(self: App, route: relay.Route, envelope: relay.Envelope, now: clock.Stamp) relay.RouteError!Received {
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
        const object_id = self.storage.putObject(self.id.id, canonical) orelse return error.NoSpace;
        return .{ .app = self.id.id, .object_id = object_id, .epoch = epoch };
    }

    pub fn publishUiStack(self: *App, stack: ui_components.Stack, epoch: clock.Stamp, scratch: UiScratch) UiError!PublishedUi {
        if (!epoch.valid()) return error.Corrupt;
        const canonical = stack.toObject(scratch.codec, scratch.object, uiObjectRequirements(), epoch) orelse return error.NoSpace;
        const object_id = self.storage.putObject(self.id.id, canonical) orelse return error.NoSpace;
        return .{ .app = self.id.id, .object_id = object_id, .epoch = epoch };
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

test "spawn transfers bounded memory and storage to child" {
    var memory_bytes: [64]u8 = undefined;
    var storage_bytes: [128]u8 = undefined;
    var slots: [4]store.Blob = undefined;

    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const user_id = identity.Identity.init(.user, identity.Source.prepare(.hash, &preimage.rawHash("user")).?, epoch).?;
    const device_id = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("device")).?, epoch).?;
    const allocator_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("allocator app")).?, epoch).?;
    const parent_source = identity.Source.prepare(.hash, &preimage.rawHash("parent app")).?;
    const child_source = identity.Source.prepare(.hash, &preimage.rawHash("child app")).?;
    const parent_id = identity.Identity.init(.app, parent_source, epoch).?;
    const child_id = identity.Identity.init(.app, child_source, epoch).?;

    var parent = App.init(
        parent_id,
        BoundedArena.init(.{ .base = &memory_bytes }),
        store.Store.init(.{ .base = &storage_bytes }, &slots),
    );

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
    var spawned = try parent.spawn(allocator_id, child_id, epoch, authorization, 16, 32, 2);
    var child = spawned.app;
    try std.testing.expectEqual(@as(usize, 48), parent.memory.remaining());
    try std.testing.expectEqual(@as(usize, 96), parent.storage.data.len());
    try std.testing.expectEqual(@as(usize, 2), parent.storage.slotCapacity());
    try std.testing.expectEqual(@as(usize, 16), child.memory.remaining());
    try std.testing.expectEqual(@as(usize, 32), child.storage.data.len());
    try std.testing.expectEqual(@as(usize, 2), child.storage.slotCapacity());

    const child_allocator = child.memory.allocator();
    _ = try child_allocator.alloc(u8, 8);
    try std.testing.expectEqual(@as(usize, 48), parent.memory.remaining());
    try std.testing.expect(spawned.receipt.valid());
    try std.testing.expectEqual(@as(u64, 32), spawned.receipt.storage_bytes.amount);
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

    const source = App.initFromHostSlice(source_id, BoundedArena.init(.{ .base = &source_memory }), 64, 2).?;
    const target = App.initFromHostSlice(target_id, BoundedArena.init(.{ .base = &target_memory }), 64, 2).?;
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

    const envelope = source.createRelayEnvelope(route, 1, hashMaterial("message object"), hashMaterial("sealed to target")).?;
    var public_relay = relay.RelayApp.init(relay_id).?;
    const transit = try public_relay.forward(route, envelope, now);
    try std.testing.expect(transit.valid());

    const received = try target.receiveRelayEnvelope(route, envelope, now);
    try std.testing.expect(received.valid());
    try std.testing.expect(bytes.nonzero(&received.id().?));
}
