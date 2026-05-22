const std = @import("std");
const app = @import("app.zig");
const clock = @import("clock.zig");
const identity = @import("identity.zig");
const intent = @import("intent.zig");

pub const Allocator = struct {
    id: identity.Identity,

    pub fn init(id: identity.Identity) ?Allocator {
        if (id.kind != .app or !id.id.valid()) return null;
        return .{ .id = id };
    }

    pub fn spawnChild(self: Allocator, parent: *app.App, child_id: identity.Identity, epoch: clock.Stamp, authorization: intent.Receipt, memory_bytes: usize, storage_bytes: usize, storage_slots: usize) app.SpawnError!app.App.Spawned {
        return parent.spawn(self.id, child_id, epoch, authorization, memory_bytes, storage_bytes, storage_slots);
    }
};

test "allocator app is the authorized actor for spawn transitions" {
    const BoundedArena = @import("arena.zig").BoundedArena;
    const store = @import("store.zig");

    var memory_bytes: [64]u8 = undefined;
    var storage_bytes: [128]u8 = undefined;
    var slots: [4]store.Blob = undefined;

    const keeper = clock.KeeperId{ .bytes = [_]u8{1} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const user = identity.Identity.init(.user, identity.Source.init(.hash, "user").?, epoch).?;
    const device = identity.Identity.init(.device, identity.Source.init(.hash, "device").?, epoch).?;
    const allocator_id = identity.Identity.init(.app, identity.Source.init(.hash, "allocator").?, epoch).?;
    const parent_id = identity.Identity.init(.app, identity.Source.init(.hash, "parent").?, epoch).?;
    const child_id = identity.Identity.init(.app, identity.Source.init(.hash, "child").?, epoch).?;
    const allocator = Allocator.init(allocator_id).?;
    var parent = app.App.init(
        parent_id,
        BoundedArena.init(.{ .base = &memory_bytes }),
        store.Store.init(.{ .base = &storage_bytes }, &slots),
    );
    const authorization = intent.admit(user, device, allocator_id, child_id, .spawn_app, .delegates_resources, epoch, intent.requestId("spawn via allocator").?).?;

    const spawned = try allocator.spawnChild(&parent, child_id, epoch, authorization, 8, 16, 1);
    try std.testing.expect(spawned.receipt.valid());
    try std.testing.expectEqual(@as(usize, 56), parent.memory.remaining());
}
