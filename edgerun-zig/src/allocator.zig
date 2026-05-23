const std = @import("std");
const app = @import("app.zig");
const clock = @import("clock.zig");
const identity = @import("identity.zig");
const intent = @import("intent.zig");
const object = @import("object.zig");
const preimage = @import("preimage.zig");

pub const Allocator = struct {
    id: identity.Identity,

    pub fn init(id: identity.Identity) ?Allocator {
        if (id.kind != .app or !id.id.valid()) return null;
        return .{ .id = id };
    }

    pub fn spawnChild(self: Allocator, parent: *app.App, child_id: identity.Identity, epoch: clock.Stamp, authorization: intent.Receipt, manifest_canonical: []const u8) app.SpawnError!app.App.Spawned {
        return parent.spawnManifest(self.id, child_id, epoch, authorization, manifest_canonical);
    }
};

test "allocator app is the authorized actor for spawn transitions" {
    const BoundedArena = @import("arena.zig").BoundedArena;
    const store = @import("store.zig");

    var memory_bytes: [64]u8 = undefined;
    var storage_bytes: [128]u8 = undefined;
    var slots: [4]store.Blob = undefined;
    var manifest_raw: [object.header_size + object.owner_size + app.App.manifest_body_size]u8 = undefined;

    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const user = identity.Identity.init(.user, identity.Source.prepare(.hash, &preimage.rawHash("user")).?, epoch).?;
    const device = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("device")).?, epoch).?;
    const allocator_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("allocator")).?, epoch).?;
    const parent_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("parent")).?, epoch).?;
    const child_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("child")).?, epoch).?;
    const allocator = Allocator.init(allocator_id).?;
    var parent = app.App.initAllocated(
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
    const authorization = intent.admit(user, device, allocator_id, child_id, .spawn_app, .delegates_resources, epoch, intent.requestId("spawn via allocator").?).?;
    const manifest = app.App.Manifest{
        .code_hash = preimage.hash("edgerun:zig:v1:test-code", "allocator child"),
        .allocation = .{
            .memory_bytes = 8,
            .storage_bytes = 16,
            .storage_slots = 1,
        },
    };
    const manifest_canonical = try app.App.writeManifestObject(child_id, manifest, epoch, &manifest_raw);

    const spawned = try allocator.spawnChild(&parent, child_id, epoch, authorization, manifest_canonical);
    try std.testing.expect(spawned.receipt.valid());
    try std.testing.expectEqual(@as(usize, 56), parent.memory.remaining());
}
