const std = @import("std");
const linux = std.os.linux;
const app_mod = @import("app.zig");
const BoundedArena = @import("arena.zig").BoundedArena;
const clock = @import("clock.zig");
const hardware_inventory_app = @import("hardware_inventory_app.zig");
const identity = @import("identity.zig");
const intent = @import("intent.zig");
const preimage = @import("preimage.zig");
const renderer_font_atlas = @import("renderer_font_atlas.zig");
const renderer_ir = @import("renderer_ir.zig");
const renderer_software = @import("renderer_software.zig");
const store = @import("store.zig");
const ui = @import("ui.zig");

const width = 320;
const height = 240;
const scene_build_iterations = 1_000;
const ir_pack_iterations = 1_000;
const ir_render_iterations = 100;
const max_rect_instances = 256;
const max_textured_vertices = 8192;
const max_image_vertices = 0;
const max_overlay_rect_instances = 64;
const max_overlay_textured_vertices = 2048;
const empty_alpha = [_]u8{255};
const IrStorage = renderer_ir.FixedBuffers(
    max_rect_instances,
    max_textured_vertices,
    max_textured_vertices,
    max_image_vertices,
    max_overlay_rect_instances,
    max_overlay_textured_vertices,
    max_overlay_textured_vertices,
);

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
    const admission = producer.admissionCapability(authorization) orelse return error.Unauthorized;
    try producer.admitAuthorization(authorization, admission);
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

    var ir_storage = IrStorage{};
    const ir_buffers = ir_storage.buffers();
    var font_atlas = renderer_font_atlas.Atlas.init();
    const sources = renderer_ir.Sources{
        .font = font_atlas.source(),
        .icon = renderer_font_atlas.nullIconSource(&font_atlas),
    };
    const ir_pack_start = nowNs();
    i = 0;
    while (i < ir_pack_iterations) : (i += 1) {
        try renderer_ir.packScene(ir_buffers, sources, scene.written());
    }
    const ir_pack_ns = nowNs() - ir_pack_start;

    var pixels: [width * height]ui.Color = undefined;
    const surface = try renderer_software.Surface.init(width, height, &pixels);
    const atlases = renderer_software.IrAtlases{
        .font = .{ .width = renderer_font_atlas.width, .height = renderer_font_atlas.height, .pixels = font_atlas.textureSlice() },
        .icon = .{ .width = 1, .height = 1, .alpha = &empty_alpha },
    };
    const ir_render_start = nowNs();
    i = 0;
    while (i < ir_render_iterations) : (i += 1) {
        surface.clear(.bg);
        _ = try surface.renderIrFrameWithAtlases(ir_buffers, atlases);
    }
    const ir_render_ns = nowNs() - ir_render_start;

    const checksum = commandChecksum(scene.written());
    const packed_checksum = irChecksum(ir_buffers);
    const rendered_checksum = pixelChecksum(&pixels);
    const final_state = try hardware_inventory_app.view(read_only.bytes);
    std.debug.print(
        \\ui bench
        \\  app ui: hardware inventory via read-only shared memory
        \\  shared bytes: {d}
        \\  scene commands: {d}
        \\  ir rect floats: {d}
        \\  ir text floats: {d}
        \\  ir icon floats: {d}
        \\  ir cached glyphs: {d}
        \\  final sequence: {d}
        \\  detected pci devices: {d}
        \\  shared update + scene build: {d} iterations in {d} ns ({d} ns/build)
        \\  ir pack: {d} iterations in {d} ns ({d} ns/pack)
        \\  ir software render: {d} iterations in {d} ns ({d} ns/render)
        \\  command checksum: 0x{x}
        \\  ir checksum: 0x{x}
        \\  pixel checksum: 0x{x}
        \\
    , .{
        read_only.bytes.len,
        scene.written().len,
        ir_storage.rect_len,
        ir_storage.text_vertex_len,
        ir_storage.icon_vertex_len,
        font_atlas.cachedGlyphCount(),
        final_state.sequence(),
        final_state.pciCount(),
        scene_build_iterations,
        scene_ns,
        scene_ns / scene_build_iterations,
        ir_pack_iterations,
        ir_pack_ns,
        ir_pack_ns / ir_pack_iterations,
        ir_render_iterations,
        ir_render_ns,
        ir_render_ns / ir_render_iterations,
        checksum,
        packed_checksum,
        rendered_checksum,
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
        .image_quad => |quad| sum = mix(sum, @truncate(quad.atlas_id)),
        .transition => |transition_value| sum = mix(sum, @truncate(transition_value.id)),
    };
    return sum;
}

fn irChecksum(buffers: renderer_ir.Buffers) u64 {
    var sum: u64 = 0xcbf29ce484222325;
    for (renderer_ir.drawBatches(buffers)) |batch| {
        sum = floatSliceChecksum(sum, renderer_ir.batchValues(batch));
    }
    return sum;
}

fn floatSliceChecksum(initial: u64, values: []const f32) u64 {
    var sum = initial;
    for (values) |value| {
        const bits: u32 = @bitCast(value);
        sum = mix(sum, @truncate(bits));
        sum = mix(sum, @truncate(bits >> 8));
        sum = mix(sum, @truncate(bits >> 16));
        sum = mix(sum, @truncate(bits >> 24));
    }
    return sum;
}

fn pixelChecksum(pixels: []const ui.Color) u64 {
    var sum: u64 = 0xcbf29ce484222325;
    for (pixels) |pixel| {
        sum = mix(sum, pixel.r);
        sum = mix(sum, pixel.g);
        sum = mix(sum, pixel.b);
        sum = mix(sum, pixel.a);
    }
    return sum;
}

fn mix(sum: u64, byte: u8) u64 {
    return (sum ^ byte) *% 0x100000001b3;
}
