const std = @import("std");
const renderer_ir = @import("renderer_ir.zig");
const varfont = @import("varfont.zig");

pub const width: usize = 1024;
pub const height: usize = 1024;
pub const bytes: usize = width * height;
pub const channels: usize = 3;
pub const texture_bytes: usize = bytes * channels;
pub const glyph_capacity: usize = 1280;
pub const format: varfont.AtlasFormat = .msdf_rgb;

const padding: usize = 4;
const row_gap: usize = 4;
const bitmap_bytes: usize = 2 * 1024 * 1024;
const font_weight: f32 = 560.0;
const device_scale: f32 = 1.0;

const CachedGlyph = struct {
    ch: u8,
    px: u8,
    glyph: renderer_ir.Glyph,
};

pub const Atlas = struct {
    texture: [texture_bytes]u8 = [_]u8{0} ** texture_bytes,
    bitmap: [bitmap_bytes]u8 = undefined,
    glyphs: [glyph_capacity]CachedGlyph = undefined,
    glyph_count: usize = 0,
    atlas_x: usize = padding,
    atlas_y: usize = padding,
    atlas_row_h: usize = 0,

    pub fn init() Atlas {
        return .{};
    }

    pub fn source(self: *Atlas) renderer_ir.FontAtlas {
        return .{
            .context = self,
            .metrics = metrics,
            .width = textWidth,
            .glyph = glyph,
        };
    }

    pub fn textureSlice(self: *const Atlas) []const u8 {
        return &self.texture;
    }

    pub fn cachedGlyphCount(self: *const Atlas) usize {
        return self.glyph_count;
    }

    fn resolveGlyph(self: *Atlas, ch: u8, px: u8) renderer_ir.Error!?renderer_ir.Glyph {
        if (self.findGlyph(ch, px)) |found| return found;
        return self.cacheGlyph(ch, px) catch |err| switch (err) {
            error.GlyphBitmapBudgetExceeded, error.GlyphCacheFull => error.Budget,
            error.InvalidFont,
            error.MissingTable,
            error.UnsupportedCmap,
            error.UnsupportedGlyph,
            error.GlyphPointBudgetExceeded,
            error.GlyphEdgeBudgetExceeded,
            => null,
        };
    }

    fn findGlyph(self: *const Atlas, ch: u8, px: u8) ?renderer_ir.Glyph {
        for (self.glyphs[0..self.glyph_count]) |entry| {
            if (entry.ch == ch and entry.px == px) return entry.glyph;
        }
        return null;
    }

    fn cacheGlyph(self: *Atlas, ch: u8, px: u8) varfont.Error!renderer_ir.Glyph {
        if (self.glyph_count >= self.glyphs.len) return error.GlyphCacheFull;
        const face = try varfont.Face.geist();
        var cache = varfont.Cache.initFormat(face, &self.bitmap, format);
        _ = cache.setAxis("wght", font_weight);
        const glyph_id = face.glyphId(ch);
        const cached = try cache.bakeGlyph(glyph_id, @as(f32, @floatFromInt(px)) * device_scale);
        const view = cache.bitmapView(cached);
        const glyph_width: usize = view.width;
        const glyph_height: usize = view.height;
        var atlas_x = self.atlas_x;
        var atlas_y = self.atlas_y;
        var atlas_u0: f32 = 0.0;
        var atlas_v0: f32 = 0.0;
        var atlas_u1: f32 = 0.0;
        var atlas_v1: f32 = 0.0;

        if (glyph_width > 0 and glyph_height > 0) {
            if (self.atlas_x + glyph_width + padding >= width) {
                self.atlas_x = padding;
                self.atlas_y += self.atlas_row_h + row_gap;
                self.atlas_row_h = 0;
            }
            if (self.atlas_y + glyph_height + padding >= height) return error.GlyphBitmapBudgetExceeded;
            atlas_x = self.atlas_x;
            atlas_y = self.atlas_y;
            self.copyGlyphBitmap(atlas_x, atlas_y, glyph_width, glyph_height, view.pixels);
            self.atlas_row_h = @max(self.atlas_row_h, glyph_height);
            self.atlas_x += glyph_width + row_gap;
            atlas_u0 = (@as(f32, @floatFromInt(atlas_x)) + 0.5) / @as(f32, @floatFromInt(width));
            atlas_v0 = (@as(f32, @floatFromInt(atlas_y)) + 0.5) / @as(f32, @floatFromInt(height));
            atlas_u1 = (@as(f32, @floatFromInt(atlas_x + glyph_width)) - 0.5) / @as(f32, @floatFromInt(width));
            atlas_v1 = (@as(f32, @floatFromInt(atlas_y + glyph_height)) - 0.5) / @as(f32, @floatFromInt(height));
        }

        const packed_glyph = renderer_ir.Glyph{
            .u0 = atlas_u0,
            .v0 = atlas_v0,
            .u1 = atlas_u1,
            .v1 = atlas_v1,
            .w = @floatFromInt(glyph_width),
            .h = @floatFromInt(glyph_height),
            .left = @floatFromInt(cached.left),
            .top = @floatFromInt(cached.top),
            .advance = cached.advance,
        };
        self.glyphs[self.glyph_count] = .{ .ch = ch, .px = px, .glyph = packed_glyph };
        self.glyph_count += 1;
        return packed_glyph;
    }

    fn copyGlyphBitmap(self: *Atlas, x: usize, y: usize, w: usize, h: usize, source_pixels: []const u8) void {
        var row: usize = 0;
        while (row < h) : (row += 1) {
            const dst = ((y + row) * width + x) * channels;
            const src = row * w * channels;
            @memcpy(self.texture[dst .. dst + w * channels], source_pixels[src .. src + w * channels]);
        }
    }
};

pub fn nullIconSource(context: *anyopaque) renderer_ir.IconAtlas {
    return .{
        .context = context,
        .rect = nullIconRect,
    };
}

fn metrics(_: *anyopaque, px: u8) renderer_ir.TextMetrics {
    const face = varfont.Face.geist() catch unreachable;
    const value = face.metrics(@floatFromInt(px));
    return .{ .ascender = value.ascender, .descender = value.descender };
}

fn textWidth(_: *anyopaque, value: []const u8, px: u8) f32 {
    const face = varfont.Face.geist() catch return 0.0;
    const px_size: f32 = @floatFromInt(px);
    var out: f32 = 0.0;
    var previous: u16 = 0;
    for (value) |byte| {
        if (byte < renderer_ir.font_first_char or byte > renderer_ir.font_last_char) continue;
        const glyph_id = face.glyphId(byte);
        if (previous != 0) out += face.kern(previous, glyph_id, px_size);
        out += face.advance(glyph_id, px_size);
        previous = glyph_id;
    }
    return out;
}

fn glyph(context: *anyopaque, ch: u8, px: u8) renderer_ir.Error!?renderer_ir.Glyph {
    const atlas: *Atlas = @ptrCast(@alignCast(context));
    return atlas.resolveGlyph(ch, px);
}

fn nullIconRect(_: *anyopaque, _: u32) ?renderer_ir.AtlasRect {
    return null;
}

test "font atlas supplies renderer ir text vertices" {
    var atlas = Atlas.init();
    var storage = renderer_ir.FixedBuffers(1, renderer_ir.textured_quad_vertex_count, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    const sources = renderer_ir.Sources{
        .font = atlas.source(),
        .icon = nullIconSource(&atlas),
    };
    try renderer_ir.pushText(buffers, sources.font, .base, .{ .x = 0, .y = 0, .w = 64, .h = 18 }, "A", .text, .start);
    try std.testing.expectEqual(@as(usize, renderer_ir.textured_quad_vertex_count * renderer_ir.text_vertex_float_stride), storage.text_vertex_len);
    try std.testing.expect(atlas.cachedGlyphCount() > 0);
}

test "font atlas caches ascii glyphs across common sizes" {
    var atlas = Atlas.init();
    const source = atlas.source();
    const px_sizes = [_]u8{ 11, 16, 24, 32 };

    for (px_sizes) |px| {
        var ch: usize = renderer_ir.font_first_char;
        while (ch <= renderer_ir.font_last_char) : (ch += 1) {
            _ = try source.glyph(source.context, @intCast(ch), px);
        }
    }

    try std.testing.expect(atlas.cachedGlyphCount() > 256);
}
