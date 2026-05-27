const std = @import("std");
const renderer_font_atlas = @import("render/font_atlas.zig");
const renderer_ir = @import("render/ir.zig");
const renderer_pipeline = @import("render/pipeline.zig");
const renderer_software = @import("render/software.zig");
const component_union = @import("ui/components/Component.zig");
const node_renderer = @import("ui/components/NodeRenderer.zig");
const ui = @import("ui.zig");

const width: usize = 2560;
const height: usize = 1440;
const max_commands: usize = 64;
const max_rects: usize = 256;
const max_text_vertices: usize = 8192;
const max_icon_vertices: usize = 64;
const empty_texture_vertices: usize = 0;
const core_snapshot_width: usize = 360;
const core_snapshot_height: usize = 180;
const fnv64_offset_basis: u64 = 0xcbf29ce484222325;
const fnv64_prime: u64 = 0x100000001b3;
const SnapshotIrStorage = renderer_ir.FixedBuffers(
    max_rects,
    max_text_vertices,
    max_icon_vertices,
    empty_texture_vertices,
    empty_texture_vertices,
    empty_texture_vertices,
    empty_texture_vertices,
    max_icon_vertices * 256,
    empty_texture_vertices,
);

pub fn main(init: std.process.Init) !void {
    try renderSnapshot(init, ".build/edgerun-zig/ui.ppm");
}

fn renderSnapshot(init: std.process.Init, out_path: []const u8) !void {
    const allocator = std.heap.page_allocator;
    var nodes: [5]ui.Node = undefined;
    const root = sampleRoot(&nodes);

    var commands: [max_commands]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try node_renderer.renderNode(component_union.Component, &scene, .{ .x = 0, .y = 0, .w = width, .h = height }, root, .{});

    const pixels = try allocator.alloc(ui.Color, width * height);
    defer allocator.free(pixels);

    var ir_storage = SnapshotIrStorage{};
    const buffers = ir_storage.buffers();

    var font_atlas: renderer_font_atlas.Atlas = undefined;
    font_atlas.initUtf8();
    try renderer_pipeline.packScene(buffers, &font_atlas, .object, scene.written());

    const surface = try renderer_software.Framebuffer.init(width, height, pixels);
    surface.clear(.bg);
    const receipt = try surface.renderIr(buffers, renderer_pipeline.softwareResources(&font_atlas, null));
    if (!receipt.valid()) return error.InvalidSoftwareReceipt;

    const io = init.io;
    try std.Io.Dir.cwd().createDirPath(io, ".build/edgerun-zig");
    const file = try std.Io.Dir.cwd().createFile(io, out_path, .{ .truncate = true });
    defer file.close(io);

    var header: [64]u8 = undefined;
    const header_bytes = try std.fmt.bufPrint(&header, "P6\n{} {}\n255\n", .{ width, height });
    try file.writeStreamingAll(io, header_bytes);

    for (pixels) |pixel| {
        try file.writeStreamingAll(io, &.{ pixel.r, pixel.g, pixel.b });
    }
}

fn sampleRoot(children: []ui.Node) ui.Node {
    std.debug.assert(children.len >= 5);
    children[0] = .{ .text = .{ .value = "edgerun ui snapshot", .color = .accent } };
    children[1] = .{ .input = .{ .id = 10, .placeholder = "search canonical objects, identities, storage records" } };
    children[2] = .{ .row_item = .{ .id = 20, .title = "object graph renderer", .detail = "" } };
    children[3] = .{ .slot = .{ .id = 7, .child = &children[4] } };
    children[4] = .{ .button = .{ .id = 30, .label = "Render" } };
    return .{ .stack = .{ .axis = .column, .gap = 18, .padding = 48, .children = children[0..4] } };
}

test "snapshot packs and rasterizes through renderer ir" {
    var nodes: [5]ui.Node = undefined;
    const root = sampleRoot(&nodes);
    var commands: [max_commands]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try node_renderer.renderNode(component_union.Component, &scene, .{ .x = 0, .y = 0, .w = 320, .h = 240 }, root, .{});

    var ir_storage = SnapshotIrStorage{};
    const buffers = ir_storage.buffers();

    var font_atlas: renderer_font_atlas.Atlas = undefined;
    font_atlas.initUtf8();
    try renderer_pipeline.packScene(buffers, &font_atlas, .object, scene.written());
    try std.testing.expect(ir_storage.rect_len > 0);
    try std.testing.expect(ir_storage.text_vertex_len > 0);

    var pixels: [320 * 240]ui.Color = undefined;
    const surface = try renderer_software.Framebuffer.init(320, 240, &pixels);
    surface.clear(.bg);
    const receipt = try surface.renderIr(buffers, renderer_pipeline.softwareResources(&font_atlas, null));
    try std.testing.expect(receipt.valid());

    var painted: usize = 0;
    for (pixels) |pixel| {
        if (pixel.a != 0 and !std.meta.eql(pixel, ui.Color.bg)) painted += 1;
    }
    try std.testing.expect(painted > 0);
}

const ComponentSnapshotCase = struct {
    name: []const u8,
    component: component_union.Component,
    digest: u64,
};

const component_snapshot_cases = [_]ComponentSnapshotCase{
    .{ .name = "button", .component = .{ .button = .{ .id = 10, .label = "Continue", .variant = .primary } }, .digest = 0x121823fe318104ab },
    .{ .name = "input", .component = .{ .input = .{ .id = 11, .placeholder = "Email address" } }, .digest = 0xc3eddf8410f2126b },
    .{ .name = "field", .component = .{ .field = .{ .id = 12, .label = "Email", .placeholder = "m@example.com" } }, .digest = 0x8c1ece84270f2978 },
    .{ .name = "card", .component = .{ .card = .{ .title = "Receipt", .detail = "Canonical object stored", .variant = .elevated } }, .digest = 0xd543ba0ebc303cdf },
    .{ .name = "toast", .component = .{ .toast = .{ .id = 13, .title = "Saved", .detail = "Notification queued" } }, .digest = 0xb914b903dcb9ff69 },
    .{ .name = "tabs", .component = .{ .tabs = .{ .id = 14, .first = "Account", .second = "Security", .active = 1 } }, .digest = 0x528e1f57bdec604a },
    .{ .name = "table", .component = .{ .table = .{ .id = 15, .name = "Sarah Chen", .role = "Engineer" } }, .digest = 0x9901aa8edb119e9a },
    .{ .name = "dialog", .component = .{ .dialog = .{ .id = 16, .title = "Edit profile", .detail = "Modal content" } }, .digest = 0x066f76f8e0d235a1 },
};

test "core component visual snapshots match deterministic software raster" {
    for (component_snapshot_cases) |case| {
        const digest = try componentSnapshotDigest(case.component);
        try std.testing.expectEqual(case.digest, digest);
    }
}

fn componentSnapshotDigest(component: component_union.Component) !u64 {
    var commands: [max_commands]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try component.render(&scene, ui.Rect.init(0, 0, @floatFromInt(core_snapshot_width), @floatFromInt(core_snapshot_height)), .{});

    var ir_storage = SnapshotIrStorage{};
    const buffers = ir_storage.buffers();
    var font_atlas: renderer_font_atlas.Atlas = undefined;
    font_atlas.initUtf8();
    try renderer_pipeline.packScene(buffers, &font_atlas, .object, scene.written());

    var pixels: [core_snapshot_width * core_snapshot_height]ui.Color = undefined;
    const surface = try renderer_software.Framebuffer.init(core_snapshot_width, core_snapshot_height, &pixels);
    surface.clear(.bg);
    const receipt = try surface.renderIr(buffers, renderer_pipeline.softwareResources(&font_atlas, null));
    if (!receipt.valid()) return error.InvalidSoftwareReceipt;

    return pixelDigest(&pixels);
}

fn pixelDigest(pixels: []const ui.Color) u64 {
    var out: u64 = fnv64_offset_basis;
    for (pixels) |pixel| {
        out = fnv64Byte(out, pixel.r);
        out = fnv64Byte(out, pixel.g);
        out = fnv64Byte(out, pixel.b);
        out = fnv64Byte(out, pixel.a);
    }
    return out;
}

fn fnv64Byte(hash: u64, value: u8) u64 {
    return (hash ^ value) *% fnv64_prime;
}
