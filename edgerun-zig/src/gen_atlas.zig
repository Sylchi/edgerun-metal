const std = @import("std");
const font_builtin = @import("font_builtin.zig");
const font_vector = @import("font_vector.zig");
const raster = @import("render/vector_raster.zig");

const atlas_w: usize = 1024;
const atlas_h: usize = 1024;

const GlyphRecord = extern struct {
    codepoint: u32,
    atlas_x: u16,
    atlas_y: u16,
    w: u16,
    h: u16,
    left: i16,
    top: i16,
    advance: u16,  // 4.12 fixed-point
};

pub fn main(init: std.process.Init) !void {
    const allocator = std.heap.page_allocator;
    const io = init.io;

    const body = font_builtin.body(.regular);

    var atlas = try allocator.alloc(u8, atlas_w * atlas_h);
    defer allocator.free(atlas);
    @memset(atlas, 0);

    const pad: usize = 8;
    const row_gap: usize = 8;
    const px: u8 = 16;
    const scale = @as(f32, @floatFromInt(px)) / @as(f32, @floatFromInt(body.metrics.units_per_em));

    var ax: usize = pad;
    var ay: usize = pad;
    var row_h: usize = 0;

    var records = try allocator.alloc(GlyphRecord, 95);
    defer allocator.free(records);
    var record_count: usize = 0;

    for (32..127) |cp| {
        const info = body.glyphForCodepoint(@intCast(cp)) orelse {
            records[record_count] = .{
                .codepoint = @intCast(cp),
                .atlas_x = 0,
                .atlas_y = 0,
                .w = 0,
                .h = 0,
                .left = 0,
                .top = 0,
                .advance = 0,
            };
            record_count += 1;
            continue;
        };

        if (ax + 256 >= atlas_w) {
            ax = pad;
            ay += row_h + row_gap;
            row_h = 0;
        }
        if (ay + pad >= atlas_h) {
            std.debug.print("atlas full at codepoint {d}\n", .{cp});
            break;
        }

        const bitmap = try raster.bakeAlpha(atlas[ay * atlas_w + ax ..], atlas_w, info.commands, scale, px);
        if (ay + bitmap.height + pad >= atlas_h) {
            std.debug.print("atlas height exceeded at codepoint {d}\n", .{cp});
            break;
        }

        row_h = @max(row_h, bitmap.height);

        const advance_px = info.advance * scale;
        const advance_fp = @as(u16, @intFromFloat(@round(advance_px * 16.0)));

        records[record_count] = .{
            .codepoint = @intCast(cp),
            .atlas_x = @intCast(ax),
            .atlas_y = @intCast(ay),
            .w = @intCast(bitmap.width),
            .h = @intCast(bitmap.height),
            .left = bitmap.left,
            .top = bitmap.top,
            .advance = advance_fp,
        };
        record_count += 1;

        ax += bitmap.width + row_gap;
    }

    std.debug.print("Rasterized {d}/{d} glyphs\n", .{ record_count, 95 });

    const cwd = std.Io.Dir.cwd();

    // Write atlas binary
    {
        var buf: [4096]u8 = undefined;
        const path = "/home/ken/edgerun-c/asm/x86_64/font_atlas.bin";
        cwd.deleteFile(io, path) catch {};
        var file = try cwd.createFile(io, path, .{ .truncate = true });
        defer file.close(io);
        var writer = file.writer(io, &buf);
        try writer.interface.writeAll(atlas[0 .. atlas_w * atlas_h]);
        try writer.interface.flush();
        std.debug.print("Wrote font_atlas.bin ({d} bytes)\n", .{atlas_w * atlas_h});
    }

    // Write glyph table binary
    {
        var buf: [4096]u8 = undefined;
        const path = "/home/ken/edgerun-c/asm/x86_64/font_glyph_table.bin";
        cwd.deleteFile(io, path) catch {};
        var file = try cwd.createFile(io, path, .{ .truncate = true });
        defer file.close(io);
        var writer = file.writer(io, &buf);
        const glyph_ptr = @as([*]const u8, @ptrCast(records.ptr));
        const glyph_bytes = glyph_ptr[0 .. record_count * @sizeOf(GlyphRecord)];
        try writer.interface.writeAll(glyph_bytes);
        try writer.interface.flush();
        std.debug.print("Wrote font_glyph_table.bin ({d} bytes)\n", .{glyph_bytes.len});
    }
}
