const std = @import("std");
const font_builtin = @import("font.zig");
const font_vector = @import("font.zig");
const raster = @import("vector_raster.zig");
const varfont = @import("varfont.zig");

pub const width: usize = font_builtin.atlas_width;
pub const height: usize = font_builtin.atlas_height;
pub const bytes: usize = width * height;
pub const channels: usize = 1;
pub const format: varfont.AtlasFormat = .alpha8;

pub const Error = error{
    Budget,
    InvalidBuffer,
};

pub const Glyph = struct {
    u0: f32,
    v0: f32,
    u1: f32,
    v1: f32,
    w: f32,
    h: f32,
    left: f32,
    top: f32,
    advance: f32,
};

pub const TextMetrics = struct {
    ascender: f32,
    descender: f32,
};

pub const FontAtlas = struct {
    context: *anyopaque,
    metrics: *const fn (context: *anyopaque, px: u8) TextMetrics,
    width: *const fn (context: *anyopaque, value: []const u8, px: u8) f32,
    glyph: *const fn (context: *anyopaque, ch: u21, px: u8) Error!?Glyph,
};

pub const font_first_px: u8 = 12;
pub const font_last_px: u8 = 60;

const weight_count = @typeInfo(font_builtin.Weight).@"enum".fields.len;
const px_range = font_last_px - font_first_px + 1;
const glyph_capacity: usize = font_builtin.codepoint_count * weight_count * px_range;

const pad: usize = 8;
const row_gap: usize = 8;
const default_scale: f32 = 2.0;
const Cached = struct { weight: font_builtin.Weight, ch: u21, px: u8, glyph: Glyph };

pub const Atlas = struct {
    width: usize,
    height: usize,
    alpha: [bytes]u8,
    glyphs: [glyph_capacity]Cached,
    glyph_count: usize,
    atlas_x: usize,
    atlas_y: usize,
    atlas_row_h: usize,
    font: font_vector.Body,
    builtin: bool,
    device_scale: f32,
    active_weight: font_builtin.Weight,
    revision: u32,

    pub fn initUtf8(self: *Atlas) void {
        self.font = font_builtin.body(.regular);
        self.builtin = true;
        self.width = width;
        self.height = height;
        self.device_scale = default_scale;
        self.active_weight = .regular;
        self.revision = 0;
        self.clearWithoutRevision();
        self.bumpRevision();
    }

    pub fn initWithFontInPlace(self: *Atlas, font: font_vector.Body) void {
        self.font = font;
        self.builtin = false;
        self.width = width;
        self.height = height;
        self.device_scale = default_scale;
        self.active_weight = .regular;
        self.revision = 0;
        self.clearWithoutRevision();
        self.bumpRevision();
    }

    pub fn clear(self: *Atlas) void {
        self.clearWithoutRevision();
        self.bumpRevision();
    }

    fn clearWithoutRevision(self: *Atlas) void {
        @memset(&self.alpha, 0);
        self.glyph_count = 0;
        self.atlas_x = pad;
        self.atlas_y = pad;
        self.atlas_row_h = 0;
    }

    pub fn source(self: *Atlas) FontAtlas {
        return .{ .context = self, .metrics = metrics, .width = textWidth, .glyph = glyph };
    }
    pub fn objectSource(self: *Atlas) FontAtlas {
        return self.source();
    }
    pub fn alphaSlice(self: *const Atlas) []const u8 {
        return &self.alpha;
    }
    pub fn cachedGlyphCount(self: *const Atlas) usize {
        return self.glyph_count;
    }
    pub fn deviceScale(self: *const Atlas) f32 {
        return self.device_scale;
    }
    pub fn cacheRevision(self: *const Atlas) u32 {
        return self.revision;
    }

    pub fn setTextWeight(self: *Atlas, weight: font_builtin.Weight) void {
        self.active_weight = weight;
    }

    pub fn setDeviceScale(self: *Atlas, scale: f32) void {
        if (@abs(self.device_scale - scale) <= 0.001) return;
        self.device_scale = scale;
        self.clear();
    }

    pub fn prepareText(self: *Atlas, value: []const u8, px: u8, weight: font_builtin.Weight) Error!void {
        var index: usize = 0;
        while (try nextCodepointStrict(value, &index)) |cp| {
            if (self.body(weight).glyphForCodepoint(cp) == null) return error.InvalidBuffer;
            _ = self.ensureGlyph(weight, cp, px) catch |err| switch (err) {
                error.GlyphBitmapBudgetExceeded, error.GlyphCacheFull => return error.Budget,
                else => return error.InvalidBuffer,
            };
        }
    }

    fn body(self: *const Atlas, weight: font_builtin.Weight) font_vector.Body {
        if (!self.builtin) return self.font;
        return font_builtin.body(weight);
    }

    fn resolveGlyph(self: *Atlas, raw: u21, px: u8) Error!?Glyph {
        const weight = self.active_weight;
        const font = self.body(weight);
        if (font.glyphForCodepoint(raw) == null) return null;
        return self.lookupGlyph(weight, raw, px);
    }

    fn lookupGlyph(self: *const Atlas, weight: font_builtin.Weight, cp: u21, px: u8) ?Glyph {
        for (self.glyphs[0..self.glyph_count]) |entry| {
            if (entry.weight == weight and entry.ch == cp and entry.px == px) return entry.glyph;
        }
        return null;
    }

    fn ensureGlyph(self: *Atlas, weight: font_builtin.Weight, cp: u21, px: u8) varfont.Error!Glyph {
        if (self.lookupGlyph(weight, cp, px)) |found| return found;
        return self.cacheGlyph(weight, cp, px);
    }

    fn cacheGlyph(self: *Atlas, weight: font_builtin.Weight, cp: u21, px: u8) varfont.Error!Glyph {
        if (self.glyph_count >= self.glyphs.len) return error.GlyphCacheFull;
        const font = self.body(weight);
        const info = font.glyphForCodepoint(cp) orelse return error.UnsupportedGlyph;
        if (self.atlas_x + 256 >= self.width) {
            self.atlas_x = pad;
            self.atlas_y += self.atlas_row_h + row_gap;
            self.atlas_row_h = 0;
        }
        if (self.atlas_y + pad >= self.height) return error.GlyphBitmapBudgetExceeded;
        const scale = (@as(f32, @floatFromInt(px)) * self.device_scale) / @as(f32, @floatFromInt(font.metrics.units_per_em));
        const bitmap = if (info.commands.len == 0) raster.GlyphBitmap{ .width = 0, .height = 0, .left = 0, .top = 0 } else try raster.bakeAlpha(self.alpha[self.atlas_y * self.width + self.atlas_x ..], self.width, info.commands, scale, px);
        if (self.atlas_y + bitmap.height + pad >= self.height) return error.GlyphBitmapBudgetExceeded;
        const ax = self.atlas_x;
        const ay = self.atlas_y;
        self.atlas_row_h = @max(self.atlas_row_h, bitmap.height);
        self.atlas_x += bitmap.width + row_gap;
        const out = Glyph{
            .u0 = if (bitmap.width == 0) 0 else (@as(f32, @floatFromInt(ax)) + 0.5) / @as(f32, @floatFromInt(self.width)),
            .v0 = if (bitmap.height == 0) 0 else (@as(f32, @floatFromInt(ay)) + 0.5) / @as(f32, @floatFromInt(self.height)),
            .u1 = if (bitmap.width == 0) 0 else (@as(f32, @floatFromInt(ax + bitmap.width)) - 0.5) / @as(f32, @floatFromInt(self.width)),
            .v1 = if (bitmap.height == 0) 0 else (@as(f32, @floatFromInt(ay + bitmap.height)) - 0.5) / @as(f32, @floatFromInt(self.height)),
            .w = self.s(@floatFromInt(bitmap.width)),
            .h = self.s(@floatFromInt(bitmap.height)),
            .left = self.s(@floatFromInt(bitmap.left)),
            .top = self.s(@floatFromInt(bitmap.top)),
            .advance = self.s(info.advance * scale),
        };
        self.glyphs[self.glyph_count] = .{ .weight = weight, .ch = cp, .px = px, .glyph = out };
        self.glyph_count += 1;
        self.bumpRevision();
        return out;
    }

    fn bumpRevision(self: *Atlas) void {
        self.revision +%= 1;
        if (self.revision == 0) self.revision = 1;
    }

    fn s(self: *const Atlas, value: f32) f32 {
        return value / self.device_scale;
    }
};

fn metrics(context: *anyopaque, px: u8) TextMetrics {
    const atlas: *Atlas = @ptrCast(@alignCast(context));
    const font = atlas.body(atlas.active_weight);
    const scale = @as(f32, @floatFromInt(px)) / @as(f32, @floatFromInt(font.metrics.units_per_em));
    return .{ .ascender = font.metrics.ascender * scale, .descender = font.metrics.descender * scale };
}

fn textWidth(context: *anyopaque, value: []const u8, px: u8) f32 {
    const atlas: *Atlas = @ptrCast(@alignCast(context));
    const font = atlas.body(atlas.active_weight);
    const scale = @as(f32, @floatFromInt(px)) / @as(f32, @floatFromInt(font.metrics.units_per_em));
    var out: f32 = 0;
    var prev: ?u21 = null;
    var index: usize = 0;
    while (nextCodepointLenient(value, &index)) |cp| {
        if (font.glyphForCodepoint(cp)) |info| {
            if (prev) |left| out += font.kern(left, cp) * scale;
            out += info.advance * scale;
            prev = cp;
        }
    }
    return out;
}

fn glyph(context: *anyopaque, ch: u21, px: u8) Error!?Glyph {
    const atlas: *Atlas = @ptrCast(@alignCast(context));
    return atlas.resolveGlyph(ch, px);
}

fn nextCodepointStrict(value: []const u8, index: *usize) Error!?u21 {
    if (index.* >= value.len) return null;
    const start = index.*;
    const len = std.unicode.utf8ByteSequenceLength(value[start]) catch return error.InvalidBuffer;
    const end = start + len;
    if (end > value.len) return error.InvalidBuffer;
    const cp = std.unicode.utf8Decode(value[start..end]) catch return error.InvalidBuffer;
    index.* = end;
    return cp;
}

fn nextCodepointLenient(value: []const u8, index: *usize) ?u21 {
    if (index.* >= value.len) return null;
    const start = index.*;
    const len = std.unicode.utf8ByteSequenceLength(value[start]) catch {
        index.* = start + 1;
        return null;
    };
    const end = start + len;
    if (end > value.len) {
        index.* = value.len;
        return null;
    }
    const cp = std.unicode.utf8Decode(value[start..end]) catch {
        index.* = start + 1;
        return null;
    };
    index.* = end;
    return cp;
}

test "font atlas starts as an empty runtime cache" {
    var atlas: Atlas = undefined;
    atlas.initUtf8();
    try std.testing.expectEqual(@as(usize, 0), atlas.cachedGlyphCount());
    try std.testing.expect(atlas.cacheRevision() != 0);
}

test "prepareText mutates cache and lookup does not" {
    var atlas: Atlas = undefined;
    atlas.initUtf8();
    try atlas.prepareText("A", 18, .regular);
    const glyphs_after_prepare = atlas.cachedGlyphCount();
    const revision_after_prepare = atlas.cacheRevision();
    try std.testing.expect(glyphs_after_prepare > 0);
    atlas.setTextWeight(.regular);
    const source = atlas.source();
    const maybe_glyph = try source.glyph(source.context, 'A', 18);
    try std.testing.expect(maybe_glyph != null);
    try std.testing.expectEqual(glyphs_after_prepare, atlas.cachedGlyphCount());
    try std.testing.expectEqual(revision_after_prepare, atlas.cacheRevision());
}

test "prepareText rejects invalid utf8 without replacement fallback" {
    var atlas: Atlas = undefined;
    atlas.initUtf8();
    const invalid = [_]u8{0xff};
    try std.testing.expectError(error.InvalidBuffer, atlas.prepareText(&invalid, 18, .regular));
    try std.testing.expectEqual(@as(usize, 0), atlas.cachedGlyphCount());
}

test "prepareText rejects missing font coverage instead of substituting" {
    var atlas: Atlas = undefined;
    atlas.initUtf8();
    const max_scalar = "\xF4\x8F\xBF\xBF";
    if (font_builtin.body(.regular).glyphForCodepoint(0x10ffff) == null) {
        try std.testing.expectError(error.InvalidBuffer, atlas.prepareText(max_scalar, 18, .regular));
    }
}
