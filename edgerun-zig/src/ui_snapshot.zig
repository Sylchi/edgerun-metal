const std = @import("std");
const renderer_software = @import("renderer_software.zig");
const ui = @import("ui.zig");
const varfont = @import("varfont.zig");

pub fn main(init: std.process.Init) !void {
    try renderSnapshot(init, ".build/edgerun-zig/ui.ppm", .alpha8);
    try renderSnapshot(init, ".build/edgerun-zig/ui-msdf.ppm", .msdf_rgb);
}

fn renderSnapshot(init: std.process.Init, out_path: []const u8, font_format: varfont.AtlasFormat) !void {
    const allocator = std.heap.page_allocator;
    const width = 2560;
    const height = 1440;
    const supersample = 2;
    const render_width = width * supersample;
    const render_height = height * supersample;

    var nodes: [5]ui.Node = undefined;
    const root = sampleRoot(&nodes);

    var commands: [64]ui.Command = undefined;
    var scene = ui.Scene.init(&commands);
    try ui.render(&scene, root, .{ .x = 0, .y = 0, .w = width, .h = height }, .{});

    const render_pixels = try allocator.alloc(ui.Color, render_width * render_height);
    defer allocator.free(render_pixels);
    const pixels = try allocator.alloc(ui.Color, width * height);
    defer allocator.free(pixels);
    const surface = try renderer_software.Surface.init(render_width, render_height, render_pixels);
    const font = try varfont.Face.geist();
    const glyph_bitmap = try allocator.alloc(u8, 8 * 1024 * 1024);
    defer allocator.free(glyph_bitmap);
    var font_cache = varfont.Cache.initFormat(font, glyph_bitmap, font_format);
    surface.clear(.bg);
    try surface.rasterizeScaled(scene.written(), &font_cache, @floatFromInt(supersample));
    try drawTypographySpecimen(surface, &font_cache, supersample);
    downsample2x(pixels, render_pixels, width, height);

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
    children[0] = .{ .text = .{ .value = "edgerun ui msdf snapshot", .color = .accent } };
    children[1] = .{ .input = .{ .id = 10, .placeholder = "search canonical objects, identities, storage records" } };
    children[2] = .{ .row_item = .{ .id = 20, .title = "object graph renderer", .detail = "" } };
    children[3] = .{ .slot = .{ .id = 7, .child = &children[4] } };
    children[4] = .{ .button = .{ .id = 30, .label = "Render MSDF" } };
    return .{ .stack = .{ .axis = .column, .gap = 18, .padding = 48, .children = children[0..4] } };
}

fn drawTypographySpecimen(surface: renderer_software.Surface, cache: *varfont.Cache, comptime scale: comptime_int) varfont.Error!void {
    const s: f32 = @floatFromInt(scale);
    const x = 108.0 * s;
    var y: f32 = 560.0 * s;
    try cache.drawText(surface, ui.Rect.init(x, y, 2200.0 * s, 120.0 * s), "Geist variable font - MSDF sizes and weights", ui.Color.text, 72.0 * s);
    y += 150.0 * s;

    try drawSpecimenRow(surface, cache, x, y, 32.0 * s, 250.0, "small 250", "edgerun", s);
    y += 84.0 * s;
    try drawSpecimenRow(surface, cache, x, y, 40.0 * s, 400.0, "body 400", "edgerun", s);
    y += 104.0 * s;
    try drawSpecimenRow(surface, cache, x, y, 56.0 * s, 550.0, "title 550", "edgerun", s);
    y += 136.0 * s;
    try drawSpecimenRow(surface, cache, x, y, 80.0 * s, 700.0, "display 700", "edgerun", s);
    y += 178.0 * s;
    try drawSpecimenRow(surface, cache, x, y, 112.0 * s, 850.0, "poster 850", "MSDF", s);
}

fn drawSpecimenRow(surface: renderer_software.Surface, cache: *varfont.Cache, x: f32, y: f32, px_size: f32, weight: f32, label: []const u8, specimen: []const u8, scale: f32) varfont.Error!void {
    _ = cache.setAxis("wght", 400.0);
    try cache.drawText(surface, ui.Rect.init(x, y + 4.0 * scale, 360.0 * scale, 48.0 * scale), label, ui.Color.muted, 32.0 * scale);
    _ = cache.setAxis("wght", weight);
    try cache.drawText(surface, ui.Rect.init(x + 440.0 * scale, y, 1800.0 * scale, px_size + 36.0 * scale), specimen, ui.Color.text, px_size);
}

fn downsample2x(dst: []ui.Color, src: []const ui.Color, width: usize, height: usize) void {
    const src_width = width * 2;
    var y: usize = 0;
    while (y < height) : (y += 1) {
        var x: usize = 0;
        while (x < width) : (x += 1) {
            const src_index = (y * 2) * src_width + x * 2;
            const a = src[src_index];
            const b = src[src_index + 1];
            const c = src[src_index + src_width];
            const d = src[src_index + src_width + 1];
            dst[y * width + x] = .{
                .r = avg4(a.r, b.r, c.r, d.r),
                .g = avg4(a.g, b.g, c.g, d.g),
                .b = avg4(a.b, b.b, c.b, d.b),
                .a = avg4(a.a, b.a, c.a, d.a),
            };
        }
    }
}

fn avg4(a: u8, b: u8, c: u8, d: u8) u8 {
    return @intCast((@as(u16, a) + b + c + d + 2) / 4);
}
