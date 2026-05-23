const std = @import("std");
const BoundedArena = @import("arena.zig").BoundedArena;
const app_mod = @import("app.zig");
const clock = @import("clock.zig");
const identity = @import("identity.zig");
const intent = @import("intent.zig");
const object = @import("object.zig");
const preimage = @import("preimage.zig");
const store = @import("store.zig");

const App = app_mod.App;
const hash_size = preimage.hash_size;
const signature_bytes = hash_size;
const draft_bytes = object.header_size + 512;
const signed_receipt_bytes = object.header_size + object.signature_fixed_body_size + signature_bytes;

const TestIds = struct {
    user: identity.Identity,
    device: identity.Identity,
    parent: identity.Identity,
    child: identity.Identity,
    grandchild: identity.Identity,
    sibling: identity.Identity,
    reader: identity.Identity,
};

fn ids(epoch: clock.Stamp) TestIds {
    return .{
        .user = identity.Identity.init(.user, identity.Source.prepare(.hash, &preimage.rawHash("cheating user")).?, epoch).?,
        .device = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("cheating device")).?, epoch).?,
        .parent = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("cheating parent")).?, epoch).?,
        .child = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("cheating child")).?, epoch).?,
        .grandchild = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("cheating grandchild")).?, epoch).?,
        .sibling = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("cheating sibling")).?, epoch).?,
        .reader = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("cheating reader")).?, epoch).?,
    };
}

fn testHash(material: []const u8) preimage.Hash {
    return preimage.hash("edgerun:zig:v1:cheating-app-test", material);
}

fn allocation(memory_bytes: usize, storage_bytes: usize, storage_slots: usize, execution_ticks: u64) App.DeclaredAllocation {
    return .{
        .memory_bytes = memory_bytes,
        .storage_bytes = storage_bytes,
        .storage_slots = storage_slots,
        .execution_ticks = execution_ticks,
    };
}

fn spawnAuthorization(test_ids: TestIds, actor: identity.Identity, child: identity.Identity, epoch: clock.Stamp, label: []const u8) intent.Receipt {
    return intent.admit(
        test_ids.user,
        test_ids.device,
        actor,
        child,
        .spawn_app,
        .delegates_resources,
        epoch,
        intent.requestId(label).?,
    ).?;
}

fn admittedSpawnAuthorization(app: *App, test_ids: TestIds, actor: identity.Identity, child: identity.Identity, epoch: clock.Stamp, label: []const u8) intent.Receipt {
    const authorization = spawnAuthorization(test_ids, actor, child, epoch, label);
    app.admitAuthorization(authorization, app.admissionCapability(authorization) orelse unreachable) catch unreachable;
    return authorization;
}

fn signingCapability(test_ids: TestIds, epoch: clock.Stamp) App.SigningCapability {
    const signing = intent.admit(
        test_ids.user,
        test_ids.device,
        test_ids.parent,
        test_ids.parent,
        .sign_data,
        .attests_state,
        epoch,
        intent.requestId("cheating parent signs work").?,
    ).?;
    return .{
        .signer = test_ids.parent,
        .authorization = signing,
    };
}

fn admittedSigningCapability(app: *App, test_ids: TestIds, epoch: clock.Stamp) App.SigningCapability {
    const capability = signingCapability(test_ids, epoch);
    app.admitAuthorization(capability.authorization, app.admissionCapability(capability.authorization) orelse unreachable) catch unreachable;
    return capability;
}

fn manifestFor(owner: identity.Identity, alloc: App.DeclaredAllocation, flags: u32, epoch: clock.Stamp, out: []u8) object.Error![]u8 {
    return App.writeManifestObject(owner, .{
        .code_hash = testHash("cheating app code"),
        .allocation = alloc,
        .flags = flags,
    }, epoch, out);
}

test "cheating app cannot write outside memory allocation" {
    const child_memory_bytes = 4096;
    const child_storage_bytes = 128;
    const child_storage_slots = 2;

    var memory: [child_memory_bytes]u8 = undefined;
    var storage_bytes: [child_storage_bytes]u8 = undefined;
    var slots: [child_storage_slots]store.Blob = undefined;

    const epoch = clock.Stamp{ .keeper = .{ .bytes = [_]u8{31} ++ [_]u8{0} ** 31 } };
    const test_ids = ids(epoch);
    var cheating = App.initAllocated(
        test_ids.child,
        BoundedArena.init(.{ .base = &memory }),
        store.Store.init(.{ .base = &storage_bytes }, &slots),
        allocation(child_memory_bytes, child_storage_bytes, child_storage_slots, 1),
    ).?;

    _ = try cheating.reserveSharedMemory(child_memory_bytes, "fill child allocation", epoch);
    try std.testing.expectError(error.NoMemory, cheating.reserveSharedMemory(1, "write byte 4096", epoch));
}

test "cheating app cannot steal parent allocation id" {
    const parent_memory_bytes = 256;
    const parent_storage_bytes = 256;
    const parent_storage_slots = 4;
    const child_memory_bytes = 64;
    const child_storage_bytes = 128;
    const child_storage_slots = 2;

    var memory: [parent_memory_bytes]u8 = undefined;
    var storage_bytes: [parent_storage_bytes]u8 = undefined;
    var slots: [parent_storage_slots]store.Blob = undefined;
    var manifest_raw: [object.header_size + object.owner_size + App.manifest_body_size]u8 = undefined;

    const epoch = clock.Stamp{ .keeper = .{ .bytes = [_]u8{32} ++ [_]u8{0} ** 31 } };
    const test_ids = ids(epoch);
    const parent_allocation = allocation(parent_memory_bytes, parent_storage_bytes, parent_storage_slots, 1);
    var parent = App.initAllocated(
        test_ids.parent,
        BoundedArena.init(.{ .base = &memory }),
        store.Store.init(.{ .base = &storage_bytes }, &slots),
        parent_allocation,
    ).?;
    const child_allocation = allocation(child_memory_bytes, child_storage_bytes, child_storage_slots, 1);
    const child_manifest = try manifestFor(test_ids.child, child_allocation, 0, epoch, &manifest_raw);
    const spawned = try parent.spawnManifest(
        test_ids.parent,
        test_ids.child,
        epoch,
        admittedSpawnAuthorization(&parent, test_ids, test_ids.parent, test_ids.child, epoch, "cheating child spawn"),
        child_manifest,
    );
    var cheating = spawned.app;
    const owned_slice = try cheating.reserveSharedMemory(1, "owned child byte", epoch);
    const forged_slice = App.SharedMemory{
        .owner = cheating.id.id,
        .id = parent_allocation.id().?,
        .offset = owned_slice.offset,
        .bytes = owned_slice.bytes,
        .epoch = epoch,
    };
    const share = intent.admit(
        test_ids.user,
        test_ids.device,
        test_ids.child,
        test_ids.reader,
        .grant_resource,
        .exports_data,
        epoch,
        intent.requestId("cheating forged allocation share").?,
    ).?;

    try std.testing.expectError(error.Corrupt, cheating.shareMemoryReadOnly(test_ids.reader.id, forged_slice, epoch, share));
}

test "cheating app cannot read sibling storage" {
    const memory_bytes = 512;
    const storage_bytes_len = 512;
    const storage_slots = 4;

    var child_memory: [memory_bytes]u8 = undefined;
    var child_storage_bytes: [storage_bytes_len]u8 = undefined;
    var child_slots: [storage_slots]store.Blob = undefined;
    var sibling_memory: [memory_bytes]u8 = undefined;
    var sibling_storage_bytes: [storage_bytes_len]u8 = undefined;
    var sibling_slots: [storage_slots]store.Blob = undefined;
    var sibling_object_raw: [object.header_size + object.owner_size + object.envelope_size + 14]u8 = undefined;

    const epoch = clock.Stamp{ .keeper = .{ .bytes = [_]u8{33} ++ [_]u8{0} ** 31 } };
    const test_ids = ids(epoch);
    var cheating = App.initAllocated(
        test_ids.child,
        BoundedArena.init(.{ .base = &child_memory }),
        store.Store.init(.{ .base = &child_storage_bytes }, &child_slots),
        allocation(memory_bytes, storage_bytes_len, storage_slots, 1),
    ).?;
    var sibling = App.initAllocated(
        test_ids.sibling,
        BoundedArena.init(.{ .base = &sibling_memory }),
        store.Store.init(.{ .base = &sibling_storage_bytes }, &sibling_slots),
        allocation(memory_bytes, storage_bytes_len, storage_slots, 1),
    ).?;
    const req = app_mod.sealedAppRequirements();
    const owner = object.Owner{ .kind = .app, .node_id = sibling.id.id.bytes };
    const envelope = app_mod.sealedEnvelopeForApp(test_ids.device, test_ids.sibling, test_ids.user, req, "sibling storage key").?;
    const canonical = try (object.NodeWriter{ .out = &sibling_object_raw }).bytesNodeOwned(req, epoch, &.{owner}, &.{envelope}, "sibling secret");
    const sibling_object = sibling.putSealedObject(test_ids.device, test_ids.user, canonical).?;

    try std.testing.expect(cheating.storedObject(sibling_object) == null);
}

test "cheating app cannot spawn with authorization for different actor" {
    const parent_memory_bytes = 256;
    const parent_storage_bytes = 256;
    const parent_storage_slots = 4;
    const child_memory_bytes = 64;
    const child_storage_bytes = 128;
    const child_storage_slots = 2;

    var memory: [parent_memory_bytes]u8 = undefined;
    var storage_bytes: [parent_storage_bytes]u8 = undefined;
    var slots: [parent_storage_slots]store.Blob = undefined;
    var manifest_raw: [object.header_size + object.owner_size + App.manifest_body_size]u8 = undefined;

    const epoch = clock.Stamp{ .keeper = .{ .bytes = [_]u8{36} ++ [_]u8{0} ** 31 } };
    const test_ids = ids(epoch);
    var parent = App.initAllocated(
        test_ids.parent,
        BoundedArena.init(.{ .base = &memory }),
        store.Store.init(.{ .base = &storage_bytes }, &slots),
        allocation(parent_memory_bytes, parent_storage_bytes, parent_storage_slots, 1),
    ).?;
    const child_allocation = allocation(child_memory_bytes, child_storage_bytes, child_storage_slots, 1);
    const child_manifest = try manifestFor(test_ids.child, child_allocation, 0, epoch, &manifest_raw);

    try std.testing.expectError(error.Unauthorized, parent.spawnManifest(
        test_ids.parent,
        test_ids.child,
        epoch,
        spawnAuthorization(test_ids, test_ids.reader, test_ids.child, epoch, "cheating forged allocator spawn"),
        child_manifest,
    ));
}

test "cheating app cannot spawn from manifest owned by sibling" {
    const parent_memory_bytes = 256;
    const parent_storage_bytes = 256;
    const parent_storage_slots = 4;
    const child_memory_bytes = 64;
    const child_storage_bytes = 128;
    const child_storage_slots = 2;

    var memory: [parent_memory_bytes]u8 = undefined;
    var storage_bytes: [parent_storage_bytes]u8 = undefined;
    var slots: [parent_storage_slots]store.Blob = undefined;
    var manifest_raw: [object.header_size + object.owner_size + App.manifest_body_size]u8 = undefined;

    const epoch = clock.Stamp{ .keeper = .{ .bytes = [_]u8{37} ++ [_]u8{0} ** 31 } };
    const test_ids = ids(epoch);
    var parent = App.initAllocated(
        test_ids.parent,
        BoundedArena.init(.{ .base = &memory }),
        store.Store.init(.{ .base = &storage_bytes }, &slots),
        allocation(parent_memory_bytes, parent_storage_bytes, parent_storage_slots, 1),
    ).?;
    const child_allocation = allocation(child_memory_bytes, child_storage_bytes, child_storage_slots, 1);
    const sibling_owned_manifest = try manifestFor(test_ids.sibling, child_allocation, 0, epoch, &manifest_raw);

    try std.testing.expectError(error.BadAllocation, parent.spawnManifest(
        test_ids.parent,
        test_ids.child,
        epoch,
        spawnAuthorization(test_ids, test_ids.parent, test_ids.child, epoch, "cheating sibling manifest spawn"),
        sibling_owned_manifest,
    ));
}

test "cheating app cannot spawn with unadmitted authorization" {
    const parent_memory_bytes = 256;
    const parent_storage_bytes = 256;
    const parent_storage_slots = 4;
    const child_memory_bytes = 64;
    const child_storage_bytes = 128;
    const child_storage_slots = 2;

    var memory: [parent_memory_bytes]u8 = undefined;
    var storage_bytes: [parent_storage_bytes]u8 = undefined;
    var slots: [parent_storage_slots]store.Blob = undefined;
    var manifest_raw: [object.header_size + object.owner_size + App.manifest_body_size]u8 = undefined;

    const epoch = clock.Stamp{ .keeper = .{ .bytes = [_]u8{39} ++ [_]u8{0} ** 31 } };
    const test_ids = ids(epoch);
    var parent = App.initAllocated(
        test_ids.parent,
        BoundedArena.init(.{ .base = &memory }),
        store.Store.init(.{ .base = &storage_bytes }, &slots),
        allocation(parent_memory_bytes, parent_storage_bytes, parent_storage_slots, 1),
    ).?;
    const child_allocation = allocation(child_memory_bytes, child_storage_bytes, child_storage_slots, 1);
    const child_manifest = try manifestFor(test_ids.child, child_allocation, 0, epoch, &manifest_raw);
    const authorization = spawnAuthorization(test_ids, test_ids.parent, test_ids.child, epoch, "cheating unadmitted spawn");

    try std.testing.expectError(error.Unauthorized, parent.spawnManifest(
        test_ids.parent,
        test_ids.child,
        epoch,
        authorization,
        child_manifest,
    ));
}

test "cheating app cannot admit parent authorization with child capability" {
    const parent_memory_bytes = 256;
    const parent_storage_bytes = 256;
    const parent_storage_slots = 4;
    const child_memory_bytes = 64;
    const child_storage_bytes = 128;
    const child_storage_slots = 2;

    var parent_memory: [parent_memory_bytes]u8 = undefined;
    var parent_storage: [parent_storage_bytes]u8 = undefined;
    var parent_slots: [parent_storage_slots]store.Blob = undefined;
    var child_memory: [child_memory_bytes]u8 = undefined;
    var child_storage: [child_storage_bytes]u8 = undefined;
    var child_slots: [child_storage_slots]store.Blob = undefined;

    const epoch = clock.Stamp{ .keeper = .{ .bytes = [_]u8{41} ++ [_]u8{0} ** 31 } };
    const test_ids = ids(epoch);
    var parent = App.initAllocated(
        test_ids.parent,
        BoundedArena.init(.{ .base = &parent_memory }),
        store.Store.init(.{ .base = &parent_storage }, &parent_slots),
        allocation(parent_memory_bytes, parent_storage_bytes, parent_storage_slots, 1),
    ).?;
    const child = App.initAllocated(
        test_ids.child,
        BoundedArena.init(.{ .base = &child_memory }),
        store.Store.init(.{ .base = &child_storage }, &child_slots),
        allocation(child_memory_bytes, child_storage_bytes, child_storage_slots, 1),
    ).?;
    const authorization = spawnAuthorization(test_ids, test_ids.parent, test_ids.child, epoch, "cheating wrong admission capability");
    const child_capability = child.admissionCapability(authorization).?;

    try std.testing.expectError(error.BadArgument, parent.admitAuthorization(authorization, child_capability));
}

test "cheating app cannot double report work" {
    const parent_memory_bytes = 256;
    const parent_storage_bytes = 1024;
    const parent_storage_slots = 4;
    const child_memory_bytes = 64;
    const child_storage_bytes = 512;
    const child_storage_slots = 2;
    const epoch = clock.Stamp{ .keeper = .{ .bytes = [_]u8{34} ++ [_]u8{0} ** 31 }, .tick = 10 };
    const end = clock.Stamp{ .keeper = epoch.keeper, .tick = 20 };

    var memory: [parent_memory_bytes]u8 = undefined;
    var storage_bytes: [parent_storage_bytes]u8 = undefined;
    var slots: [parent_storage_slots]store.Blob = undefined;
    var manifest_raw: [object.header_size + object.owner_size + App.manifest_body_size]u8 = undefined;
    var draft_raw: [draft_bytes]u8 = undefined;
    var signed_raw: [signed_receipt_bytes]u8 = undefined;

    const test_ids = ids(epoch);
    var parent = App.initAllocated(
        test_ids.parent,
        BoundedArena.init(.{ .base = &memory }),
        store.Store.init(.{ .base = &storage_bytes }, &slots),
        allocation(parent_memory_bytes, parent_storage_bytes, parent_storage_slots, 1),
    ).?;
    const child_allocation = allocation(child_memory_bytes, child_storage_bytes, child_storage_slots, 1);
    const child_manifest = try manifestFor(test_ids.child, child_allocation, 0, epoch, &manifest_raw);
    const manifest_id = object.Header.id(child_manifest);
    const spawned = try parent.spawnManifest(
        test_ids.parent,
        test_ids.child,
        epoch,
        admittedSpawnAuthorization(&parent, test_ids, test_ids.parent, test_ids.child, epoch, "cheating work child spawn"),
        child_manifest,
    );
    const work = spawned.app.completeWork(parent.id.id, testHash("work input"), testHash("work output"), testHash("cheating app code"), manifest_id, epoch, end, child_allocation, spawned.receipt).?;
    const draft = try work.writeObject(end, &draft_raw);
    const context = App.WorkReceiptDraftContext{
        .child = test_ids.child,
        .input = testHash("work input"),
        .output = testHash("work output"),
        .app_hash = testHash("cheating app code"),
        .manifest = manifest_id,
        .clock_start = epoch,
        .clock_end = end,
        .allocation = child_allocation,
        .execution_used = work.execution_used,
        .spawn_receipt = spawned.receipt,
    };

    const capability = admittedSigningCapability(&parent, test_ids, end);
    _ = try parent.signWorkReceiptDraft(draft, context, end, capability, &signed_raw);
    try std.testing.expectError(error.Corrupt, parent.signWorkReceiptDraft(draft, context, end, capability, &signed_raw));
}

test "cheating app cannot sign work with unadmitted signing capability" {
    const parent_memory_bytes = 256;
    const parent_storage_bytes = 1024;
    const parent_storage_slots = 4;
    const child_memory_bytes = 64;
    const child_storage_bytes = 512;
    const child_storage_slots = 2;
    const epoch = clock.Stamp{ .keeper = .{ .bytes = [_]u8{40} ++ [_]u8{0} ** 31 }, .tick = 10 };
    const end = clock.Stamp{ .keeper = epoch.keeper, .tick = 20 };

    var memory: [parent_memory_bytes]u8 = undefined;
    var storage_bytes: [parent_storage_bytes]u8 = undefined;
    var slots: [parent_storage_slots]store.Blob = undefined;
    var manifest_raw: [object.header_size + object.owner_size + App.manifest_body_size]u8 = undefined;
    var draft_raw: [draft_bytes]u8 = undefined;
    var signed_raw: [signed_receipt_bytes]u8 = undefined;

    const test_ids = ids(epoch);
    var parent = App.initAllocated(
        test_ids.parent,
        BoundedArena.init(.{ .base = &memory }),
        store.Store.init(.{ .base = &storage_bytes }, &slots),
        allocation(parent_memory_bytes, parent_storage_bytes, parent_storage_slots, 1),
    ).?;
    const child_allocation = allocation(child_memory_bytes, child_storage_bytes, child_storage_slots, 1);
    const child_manifest = try manifestFor(test_ids.child, child_allocation, 0, epoch, &manifest_raw);
    const manifest_id = object.Header.id(child_manifest);
    const spawned = try parent.spawnManifest(
        test_ids.parent,
        test_ids.child,
        epoch,
        admittedSpawnAuthorization(&parent, test_ids, test_ids.parent, test_ids.child, epoch, "cheating unadmitted signing child spawn"),
        child_manifest,
    );
    const work = spawned.app.completeWork(parent.id.id, testHash("unadmitted signing input"), testHash("unadmitted signing output"), testHash("cheating app code"), manifest_id, epoch, end, child_allocation, spawned.receipt).?;
    const draft = try work.writeObject(end, &draft_raw);
    const context = App.WorkReceiptDraftContext{
        .child = test_ids.child,
        .input = testHash("unadmitted signing input"),
        .output = testHash("unadmitted signing output"),
        .app_hash = testHash("cheating app code"),
        .manifest = manifest_id,
        .clock_start = epoch,
        .clock_end = end,
        .allocation = child_allocation,
        .execution_used = work.execution_used,
        .spawn_receipt = spawned.receipt,
    };

    try std.testing.expectError(error.Unauthorized, parent.signWorkReceiptDraft(draft, context, end, signingCapability(test_ids, end), &signed_raw));
}

test "cheating app cannot report work for app hash not spawned" {
    const parent_memory_bytes = 256;
    const parent_storage_bytes = 1024;
    const parent_storage_slots = 4;
    const child_memory_bytes = 64;
    const child_storage_bytes = 512;
    const child_storage_slots = 2;
    const epoch = clock.Stamp{ .keeper = .{ .bytes = [_]u8{38} ++ [_]u8{0} ** 31 }, .tick = 10 };
    const end = clock.Stamp{ .keeper = epoch.keeper, .tick = 20 };

    var memory: [parent_memory_bytes]u8 = undefined;
    var storage_bytes: [parent_storage_bytes]u8 = undefined;
    var slots: [parent_storage_slots]store.Blob = undefined;
    var manifest_raw: [object.header_size + object.owner_size + App.manifest_body_size]u8 = undefined;
    var draft_raw: [draft_bytes]u8 = undefined;
    var signed_raw: [signed_receipt_bytes]u8 = undefined;

    const test_ids = ids(epoch);
    var parent = App.initAllocated(
        test_ids.parent,
        BoundedArena.init(.{ .base = &memory }),
        store.Store.init(.{ .base = &storage_bytes }, &slots),
        allocation(parent_memory_bytes, parent_storage_bytes, parent_storage_slots, 1),
    ).?;
    const child_allocation = allocation(child_memory_bytes, child_storage_bytes, child_storage_slots, 1);
    const child_manifest = try manifestFor(test_ids.child, child_allocation, 0, epoch, &manifest_raw);
    const manifest_id = object.Header.id(child_manifest);
    const spawned = try parent.spawnManifest(
        test_ids.parent,
        test_ids.child,
        epoch,
        admittedSpawnAuthorization(&parent, test_ids, test_ids.parent, test_ids.child, epoch, "cheating wrong app hash spawn"),
        child_manifest,
    );
    const wrong_app_hash = testHash("cheating different app code");
    const work = spawned.app.completeWork(parent.id.id, testHash("wrong app hash input"), testHash("wrong app hash output"), wrong_app_hash, manifest_id, epoch, end, child_allocation, spawned.receipt).?;
    const draft = try work.writeObject(end, &draft_raw);
    const context = App.WorkReceiptDraftContext{
        .child = test_ids.child,
        .input = testHash("wrong app hash input"),
        .output = testHash("wrong app hash output"),
        .app_hash = wrong_app_hash,
        .manifest = manifest_id,
        .clock_start = epoch,
        .clock_end = end,
        .allocation = child_allocation,
        .execution_used = work.execution_used,
        .spawn_receipt = spawned.receipt,
    };

    try std.testing.expectError(error.Unauthorized, parent.signWorkReceiptDraft(draft, context, end, signingCapability(test_ids, end), &signed_raw));
    try std.testing.expectError(error.Corrupt, parent.signWorkReceiptDraft(draft, context, end, admittedSigningCapability(&parent, test_ids, end), &signed_raw));
}

test "cheating app cannot reclaim parent resources while grandchild is alive" {
    const parent_memory_bytes = 256;
    const parent_storage_bytes = 1024;
    const parent_storage_slots = 4;
    const child_memory_bytes = 128;
    const child_storage_bytes = 512;
    const child_storage_slots = 2;
    const grandchild_memory_bytes = 32;
    const grandchild_storage_bytes = 128;
    const grandchild_storage_slots = 1;

    var memory: [parent_memory_bytes]u8 = undefined;
    var storage_bytes: [parent_storage_bytes]u8 = undefined;
    var slots: [parent_storage_slots]store.Blob = undefined;
    var child_manifest_raw: [object.header_size + object.owner_size + App.manifest_body_size]u8 = undefined;
    var grandchild_manifest_raw: [object.header_size + object.owner_size + App.manifest_body_size]u8 = undefined;

    const epoch = clock.Stamp{ .keeper = .{ .bytes = [_]u8{35} ++ [_]u8{0} ** 31 } };
    const test_ids = ids(epoch);
    var parent = App.initAllocated(
        test_ids.parent,
        BoundedArena.init(.{ .base = &memory }),
        store.Store.init(.{ .base = &storage_bytes }, &slots),
        allocation(parent_memory_bytes, parent_storage_bytes, parent_storage_slots, 2),
    ).?;
    const child_allocation = allocation(child_memory_bytes, child_storage_bytes, child_storage_slots, 2);
    const child_manifest = try manifestFor(test_ids.child, child_allocation, App.manifest_flag_child_spawn, epoch, &child_manifest_raw);
    const spawned_child = try parent.spawnManifest(
        test_ids.parent,
        test_ids.child,
        epoch,
        admittedSpawnAuthorization(&parent, test_ids, test_ids.parent, test_ids.child, epoch, "cheating tree child spawn"),
        child_manifest,
    );
    var child = spawned_child.app;
    const grandchild_allocation = allocation(grandchild_memory_bytes, grandchild_storage_bytes, grandchild_storage_slots, 1);
    const grandchild_manifest = try manifestFor(test_ids.grandchild, grandchild_allocation, 0, epoch, &grandchild_manifest_raw);
    _ = try child.spawnManifest(
        test_ids.child,
        test_ids.grandchild,
        epoch,
        admittedSpawnAuthorization(&child, test_ids, test_ids.child, test_ids.grandchild, epoch, "cheating tree grandchild spawn"),
        grandchild_manifest,
    );

    try std.testing.expectError(error.Corrupt, parent.reclaimChild(&child, spawned_child.receipt, epoch));
}
