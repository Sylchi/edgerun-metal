const std = @import("std");
const font_builtin = @import("../font_builtin.zig");
const font_vector = @import("../font_vector.zig");
const ir = @import("ir.zig");
const raster = @import("vector_raster.zig");
const varfont = @import("../varfont.zig");

pub const width: usize = 2048;
pub const height: usize = 2048;
pub const bytes: usize = width * height;
pub const channels: usize = 1;
pub const glyph_capacity: usize = 4096;
pub const format: varfont.AtlasFormat = .alpha8;

const replacement = font_builtin.replacement_codepoint;
const pad: usize = 8;
const row_gap: usize = 8;
const default_scale: f32 = 2.0;
const prebake_px = [_]u8{ 11, 12, 14, 16, 18, 20, 24, 32, 48 };
const Cached = struct { ch: u21, px: u8, glyph: ir.Glyph };

pub const Atlas = struct {
    alpha: [bytes]u8,
    glyphs: [glyph_capacity]Cached,
    glyph_count: usize,
    atlas_x: usize,
    atlas_y: usize,
    atlas_row_h: usize,
    font: font_vector.Body,
    device_scale: f32,
    sealed: bool,

    pub fn init() Atlas {
        var self: Atlas = undefined;
        self.initUtf8();
        return self;
    }

    pub fn initWithFont(font: font_vector.Body) Atlas {
        var self: Atlas = undefined;
        self.initWithFontInPlace(font);
        return self;
    }

    pub fn initEmpty(self: *Atlas) void { self.initUtf8(); }
    pub fn initUtf8(self: *Atlas) void { self.initWithFontInPlace(font_builtin.compiled.body()); }

    pub fn initWithFontInPlace(self: *Atlas, font: font_vector.Body) void {
        self.font = font;
        self.device_scale = default_scale;
        self.clear();
        self.prebake() catch {};
    }

    pub fn clear(self: *Atlas) void {
        @memset(&self.alpha, 0);
        self.glyph_count = 0;
        self.atlas_x = pad;
        self.atlas_y = pad;
        self.atlas_row_h = 0;
        self.sealed = false;
    }

    pub fn source(self: *Atlas) ir.FontAtlas { return .{ .context = self, .metrics = metrics, .width = textWidth, .glyph = glyph }; }
    pub fn objectSource(self: *Atlas) ir.FontAtlas { return self.source(); }
    pub fn alphaSlice(self: *const Atlas) []const u8 { return &self.alpha; }
    pub fn cachedGlyphCount(self: *const Atlas) usize { return self.glyph_count; }
    pub fn deviceScale(self: *const Atlas) f32 { return self.device_scale; }

    pub fn setDeviceScale(self: *Atlas, scale: f32) void {
        if (@abs(self.device_scale - scale) <= 0.001) return;
        self.device_scale = scale;
        self.clear();
        self.prebake() catch {};
    }

    fn prebake(self: *Atlas) varfont.Error!void {
        for (prebake_px) |px| {
            for (self.font.glyphs) |record| {
                _ = try self.cacheGlyph(record.codepoint, px);
            }
        }
        self.sealed = true;
    }

    fn resolveGlyph(self: *Atlas, raw: u21, px: u8) ir.Error!?ir.Glyph {
        const cp = resolve(self.font, raw) orelse return null;
        for (self.glyphs[0..self.glyph_count]) |entry| if (entry.ch == cp and entry.px == px) return entry.glyph;
        if (self.sealed) return null;
        return self.cacheGlyph(cp, px) catch |err| switch (err) {
            error.GlyphBitmapBudgetExceeded, error.GlyphCacheFull => error.Budget,
            else => null,
        };
    }

    fn cacheGlyph(self: *Atlas, cp: u21, px: u8) varfont.Error!ir.Glyph {
        if (self.glyph_count >= self.glyphs.len) return error.GlyphCacheFull;
        const info = self.font.glyphForCodepoint(cp) orelse return error.UnsupportedGlyph;
        if (self.atlas_x + 256 >= width) {
            self.atlas_x = pad;
            self.atlas_y += self.atlas_row_h + row_gap;
            self.atlas_row_h = 0;
        }
        if (self.atlas_y + pad >= height) return error.GlyphBitmapBudgetExceeded;
        const scale = (@as(f32, @floatFromInt(px)) * self.device_scale) / @as(f32, @floatFromInt(self.font.metrics.units_per_em));
        const bitmap = if (info.commands.len == 0) raster.GlyphBitmap{ .width = 0, .height = 0, .left = 0, .top = 0 } else try raster.bakeAlpha(self.alpha[self.atlas_y * width + self.atlas_x ..], width, info.commands, scale, px);
        if (self.atlas_y + bitmap.height + pad >= height) return error.GlyphBitmapBudgetExceeded;
        const ax = self.atlas_x;
        const ay = self.atlas_y;
        self.atlas_row_h = @max(self.atlas_row_h, bitmap.height);
        self.atlas_x += bitmap.width + row_gap;
        const glyph_value = ir.Glyph{
            .u0 = if (bitmap.width == 0) 0 else (@as(f32, @floatFromInt(ax)) + 0.5) / @as(f32, @floatFromInt(width)),
            .v0 = if (bitmap.height == 0) 0 else (@as(f32, @floatFromInt(ay)) + 0.5) / @as(f32, @floatFromInt(height)),
            .u1 = if (bitmap.width == 0) 0 else (@as(f32, @floatFromInt(ax + bitmap.width)) - 0.5) / @as(f32, @floatFromInt(width)),
            .v1 = if (bitmap.height == 0) 0 else (@as(f32, @floatFromInt(ay + bitmap.height)) - 0.5) / @as(f32, @floatFromInt(height)),
            .w = self.s(@floatFromInt(bitmap.width)),
            .h = self.s(@floatFromInt(bitmap.height)),
            .left = self.s(@floatFromInt(bitmap.left)),
            .top = self.s(@floatFromInt(bitmap.top)),
            .advance = self.s(info.advance * scale),
        };
        self.glyphs[self.glyph_count] = .{ .ch = cp, .px = px, .glyph = glyph_value };
        self.glyph_count += 1;
        return glyph_value;
    }

    fn s(self: *const Atlas, v: f32) f32 { return v / self.device_scale; }
};

fn metrics(context: *anyopaque, px: u8) ir.TextMetrics {
    const atlas: *Atlas = @ptrCast(@alignCast(context));
    const scale = @as(f32, @floatFromInt(px)) / @as(f32, @floatFromInt(atlas.font.metrics.units_per_em));
    return .{ .ascender = atlas.font.metrics.ascender * scale, .descender = atlas.font.metrics.descender * scale };
}

fn textWidth(context: *anyopaque, value: []const u8, px: u8) f32 {
    const atlas: *Atlas = @ptrCast(@alignCast(context));
    const scale = @as(f32, @floatFromInt(px)) / @as(f32, @floatFromInt(atlas.font.metrics.units_per_em));
    var out: f32 = 0;
    var prev: ?u21 = null;
    var index: usize = 0;
    while (nextCodepoint(value, &index)) |raw| {
        const cp = resolve(atlas.font, raw) orelse continue;
        if (atlas.font.glyphForCodepoint(cp)) |info| {
            if (prev) |left| out += atlas.font.kern(left, cp) * scale;
            out += info.advance * scale;
            prev = cp;
        }
    }
    return out;
}

fn glyph(context: *anyopaque, ch: u21, px: u8) ir.Error!?ir.Glyph {
    const atlas: *Atlas = @ptrCast(@alignCast(context));
    return atlas.resolveGlyph(ch, px);
}

fn resolve(font: font_vector.Body, raw: u21) ?u21 {
    if (font.glyphForCodepoint(raw) != null) return raw;
    if (font.glyphForCodepoint(replacement) != null) return replacement;
    return null;
}

fn nextCodepoint(value: []const u8, index: *usize) ?u21 {
    if (index.* >= value.len) return null;
    const start = index.*;
    const len = std.unicode.utf8ByteSequenceLength(value[start]) catch { index.* = start + 1; return replacement; };
    const end = start + len;
    if (end > value.len) { index.* = value.len; return replacement; }
    const cp = std.unicode.utf8Decode(value[start..end]) catch { index.* = start + 1; return replacement; };
    index.* = end;
    return cp;
}
