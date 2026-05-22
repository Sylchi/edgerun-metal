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
        const storage = store.Store.initFromArena(&memory, storage_bytes, storage_slots) orelse return null;
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

    pub fn spawn(self: *App, allocator_id: identity.Identity, child_id: identity.Identity, epoch: clock.Stamp, authorization: intent.Receipt, memory_bytes: usize, storage_bytes: usize, storage_slots: usize) SpawnError!Spawned {
        if (!authorization.permitsAt(epoch, allocator_id.id, child_id.id, .spawn_app, .delegates_resources)) {
            return error.Unauthorized;
        }

        const child_memory = self.memory.split(memory_bytes) orelse return error.NoMemory;
        const child_storage = self.storage.split(storage_bytes, storage_slots) orelse return error.NoStorage;
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
};

fn hashMaterial(material: []const u8) preimage.Hash {
    return preimage.hash("edgerun:zig:v1:test-material", material);
}

test "spawn transfers bounded memory and storage to child" {
    var memory_bytes: [64]u8 = undefined;
    var storage_bytes: [128]u8 = undefined;
    var slots: [4]store.Blob = undefined;

    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const user_id = identity.Identity.init(.user, identity.Source.init(.hash, "user").?, epoch).?;
    const device_id = identity.Identity.init(.device, identity.Source.init(.hash, "device").?, epoch).?;
    const allocator_id = identity.Identity.init(.app, identity.Source.init(.hash, "allocator app").?, epoch).?;
    const parent_source = identity.Source.init(.hash, "parent app").?;
    const child_source = identity.Source.init(.hash, "child app").?;
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
    const app_id = identity.Identity.init(.app, identity.Source.init(.hash, "app").?, epoch).?;
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

test "apps exchange identity routed envelopes through relay boundary" {
    var source_memory: [256]u8 = undefined;
    var target_memory: [256]u8 = undefined;
    var relay_memory: [128]u8 = undefined;

    const keeper = clock.KeeperId{ .bytes = [_]u8{3} ++ [_]u8{0} ** 31 };
    const now = clock.Stamp{ .keeper = keeper, .tick = 3 };
    const user = identity.Identity.init(.user, identity.Source.init(.hash, "routing user").?, now).?;
    const device = identity.Identity.init(.device, identity.Source.init(.hash, "routing device").?, now).?;
    const source_id = identity.Identity.init(.app, identity.Source.init(.hash, "routing source app").?, now).?;
    const target_id = identity.Identity.init(.app, identity.Source.init(.hash, "routing target app").?, now).?;
    const relay_id = identity.Identity.init(.relay, identity.Source.init(.hash, "routing relay app").?, now).?;

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
