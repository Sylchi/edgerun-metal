const std = @import("std");
const linux = std.os.linux;
const app_mod = @import("app.zig");
const BoundedArena = @import("arena.zig").BoundedArena;
const clock = @import("clock.zig");
const hardware_inventory_app = @import("hardware_inventory_app.zig");
const identity = @import("identity.zig");
const intent = @import("intent.zig");
const preimage = @import("preimage.zig");
const renderer_software = @import("renderer_software.zig");
const ui = @import("ui.zig");
const varfont = @import("varfont.zig");

const width = 320;
const height = 240;
const scene_build_iterations = 200;
const warm_frames = 5;

pub fn main() !void {
    var producer_memory: [4096]u8 = undefined;
    var ui_memory: [2048]u8 = undefined;
    const keeper = clock.KeeperId{ .bytes = [_]u8{9} ++ [_]u8{0} ** 31 };
    const epoch = clock.Stamp{ .keeper = keeper };
    const user_id = identity.Identity.init(.user, identity.Source.prepare(.hash, &preimage.rawHash("bench user")).?, epoch).?;
    const device_id = identity.Identity.init(.device, identity.Source.prepare(.hash, &preimage.rawHash("bench device")).?, epoch).?;
    const producer_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("hardware inventory producer")).?, epoch).?;
    const ui_id = identity.Identity.init(.app, identity.Source.prepare(.hash, &preimage.rawHash("hardware inventory ui")).?, epoch).?;
    var producer = app_mod.App.initFromHostSlice(producer_id, BoundedArena.init(.{ .base = &producer_memory }), 512, 8).?;
    _ = app_mod.App.initFromHostSlice(ui_id, BoundedArena.init(.{ .base = &ui_memory }), 256, 4).?;
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
    std.debug.print("bench setup done\n", .{});

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
    std.debug.print("scene loop done\n", .{});

    var pixels: [width * height]ui.Color = undefined;
    const surface = try renderer_software.Surface.init(width, height, &pixels);
    const font = try varfont.Face.geist();
    var glyph_bitmap: [256 * 1024]u8 = undefined;
    var font_cache = varfont.Cache.init(font, &glyph_bitmap);
    std.debug.print("surface setup done\n", .{});

    const cold_start = nowNs();
    surface.clear(.bg);
    try surface.rasterize(scene.written(), &font_cache);
    const cold_ns = nowNs() - cold_start;
    std.debug.print("cold frame done\n", .{});

    const warm_start = nowNs();
    i = 0;
    while (i < warm_frames) : (i += 1) {
        surface.clear(.bg);
        try surface.rasterize(scene.written(), &font_cache);
    }
    const warm_ns = nowNs() - warm_start;

    const checksum = pixelChecksum(surface.pixels);
    const final_state = try hardware_inventory_app.view(read_only.bytes);
    std.debug.print(
        \\ui bench
        \\  app ui: hardware inventory via read-only shared memory
        \\  shared bytes: {d}
        \\  scene commands: {d}
        \\  final sequence: {d}
        \\  detected pci devices: {d}
        \\  cached glyphs: {d}
        \\  glyph bitmap bytes: {d}
        \\  shared update + scene build: {d} iterations in {d:.3} ms ({d:.3} us/build)
        \\  cold frame: {d:.3} ms
        \\  warm frames: {d} in {d:.3} ms ({d:.3} us/frame, {d:.1} fps)
        \\  checksum: 0x{x}
        \\
    , .{
        read_only.bytes.len,
        scene.written().len,
        final_state.sequence(),
        final_state.pciCount(),
        font_cache.glyph_count,
        font_cache.bitmap_len,
        scene_build_iterations,
        nsToMs(scene_ns),
        nsToUs(scene_ns) / @as(f64, @floatFromInt(scene_build_iterations)),
        nsToMs(cold_ns),
        warm_frames,
        nsToMs(warm_ns),
        nsToUs(warm_ns) / @as(f64, @floatFromInt(warm_frames)),
        @as(f64, @floatFromInt(warm_frames)) / (nsToMs(warm_ns) / 1000.0),
        checksum,
    });
}

fn nsToMs(ns: u64) f64 {
    return @as(f64, @floatFromInt(ns)) / 1_000_000.0;
}

fn nowNs() u64 {
    var ts: linux.timespec = undefined;
    _ = linux.clock_gettime(.MONOTONIC, &ts);
    return @as(u64, @intCast(ts.sec)) * std.time.ns_per_s + @as(u64, @intCast(ts.nsec));
}

fn nsToUs(ns: u64) f64 {
    return @as(f64, @floatFromInt(ns)) / 1_000.0;
}

fn pixelChecksum(pixels: []const ui.Color) u64 {
    var sum: u64 = 0xcbf29ce484222325;
    for (pixels) |pixel| {
        sum ^= pixel.r;
        sum *%= 0x100000001b3;
        sum ^= pixel.g;
        sum *%= 0x100000001b3;
        sum ^= pixel.b;
        sum *%= 0x100000001b3;
        sum ^= pixel.a;
        sum *%= 0x100000001b3;
    }
    return sum;
}
