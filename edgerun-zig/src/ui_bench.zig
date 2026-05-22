const std = @import("std");
const linux = std.os.linux;
const app_mod = @import("app.zig");
const BoundedArena = @import("arena.zig").BoundedArena;
const clock = @import("clock.zig");
const hardware_inventory_app = @import("hardware_inventory_app.zig");
const identity = @import("identity.zig");
const intent = @import("intent.zig");
const preimage = @import("preimage.zig");
const store = @import("store.zig");
const ui = @import("ui.zig");

const width = 320;
const height = 240;
const scene_build_iterations = 1_000;

pub fn main() !void {
    var producer_memory: [4096]u8 = undefined;
    var ui_memory: [2048]u8 = undefined;
    var producer_storage_bytes: [512]u8 = undefined;
    var producer_storage_slots: [8]store.Blob = undefined;
    var ui_storage_bytes: [256]u8 = undefined;
    var ui_storage_slots: [4]store.Blob = undefined;
    const keeper = clock.KeeperId{ .bytes = [_]u8{9} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const user_id = identity.Identity.init(.user, identity.Source.prepare(.hash, &preimage.rawHash("bench user")).?, epoch).?;
    const device_id = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("bench device")).?, epoch).?;
    const producer_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("hardware inventory producer")).?, epoch).?;
    const ui_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("hardware inventory ui")).?, epoch).?;
    var producer = app_mod.App.init(
        producer_id,
        BoundedArena.init(.{ .base = &producer_memory }),
        store.Store.init(.{ .base = &producer_storage_bytes }, &producer_storage_slots),
    );
    _ = app_mod.App.init(
        ui_id,
        BoundedArena.init(.{ .base = &ui_memory }),
        store.Store.init(.{ .base = &ui_storage_bytes }, &ui_storage_slots),
    );
    const shared = try producer.reserveSharedMemory(hardware_inventory_app.state_size, "hardware-inventory-ui", epoch);
    var inventory = hardware_inventory_app.sampleInventory(1);
    _ = try hardware_inventory_app.writeState(shared.bytes, inventory, 0);
    const authorization = intent.admit(
        user_id,
        device_id,
        producer_id,
        ui_id,
        .grant_resource,
        .exports_data,
        epoch,
        intent.requestId("benchmark hardware inventory ui sharing").?,
    ).?;
    const read_only = try producer.shareMemoryReadOnly(ui_id.id, shared, epoch, authorization);

    var nodes: [hardware_inventory_app.node_count]ui.Node = undefined;
    var commands: [64]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);

    const scene_start = nowNs();
    var i: usize = 0;
    while (i < scene_build_iterations) : (i += 1) {
        inventory.pci.device_count = (i % 8) + 1;
        _ = try hardware_inventory_app.writeState(shared.bytes, inventory, @intCast(i + 1));
        const state_view = try hardware_inventory_app.view(read_only.bytes);
        const root = state_view.rootNode(&nodes) orelse return error.NodeBudgetExceeded;
        scene.clear();
        try ui.render(&scene, root, .{ .x = 0, .y = 0, .w = width, .h = height }, .{});
    }
    const scene_ns = nowNs() - scene_start;

    const checksum = commandChecksum(scene.written());
    const final_state = try hardware_inventory_app.view(read_only.bytes);
    std.debug.print(
        \\ui bench
        \\  app ui: hardware inventory via read-only shared memory
        \\  shared bytes: {d}
        \\  scene commands: {d}
        \\  final sequence: {d}
        \\  detected pci devices: {d}
        \\  shared update + scene build: {d} iterations in {d} ns ({d} ns/build)
        \\  checksum: 0x{x}
        \\
    , .{
        read_only.bytes.len,
        scene.written().len,
        final_state.sequence(),
        final_state.pciCount(),
        scene_build_iterations,
        scene_ns,
        scene_ns / scene_build_iterations,
        checksum,
    });
}

fn nowNs() u64 {
    var ts: linux.timespec = undefined;
    _ = linux.clock_gettime(.MONOTONIC, &ts);
    return @as(u64, @intCast(ts.sec)) * std.time.ns_per_s + @as(u64, @intCast(ts.nsec));
}

fn commandChecksum(commands: []const ui.Command) u64 {
    var sum: u64 = 0xcbf29ce484222325;
    for (commands) |command| switch (command) {
        .rect => |rect| {
            sum = mix(sum, rect.color.r);
            sum = mix(sum, rect.color.g);
            sum = mix(sum, rect.color.b);
            sum = mix(sum, rect.color.a);
        },
        .border => |border| {
            sum = mix(sum, border.color.r);
            sum = mix(sum, border.color.g);
            sum = mix(sum, border.color.b);
            sum = mix(sum, border.color.a);
        },
        .text => |text| {
            for (text.value) |byte| sum = mix(sum, byte);
        },
        .hit => |hit| sum = mix(sum, @truncate(hit.id)),
        .drag_source => |source| sum = mix(sum, @truncate(source.item_id)),
        .drop_target => |target| sum = mix(sum, @truncate(target.index)),
        .icon_quad => |quad| sum = mix(sum, @truncate(quad.atlas_id)),
        .text_quad => |quad| sum = mix(sum, @truncate(quad.atlas_id)),
        .transition => |transition_value| sum = mix(sum, @truncate(transition_value.id)),
    };
    return sum;
}

fn mix(sum: u64, byte: u8) u64 {
    return (sum ^ byte) *% 0x100000001b3;
}
