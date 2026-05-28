const std = @import("std");
const font_builtin = @import("../font_builtin.zig");
const font_vector = @import("../font_vector.zig");
const ir = @import("ir.zig");
const raster = @import("vector_raster.zig");
const varfont = @import("../varfont.zig");

pub const width: usize = 8192;
pub const height: usize = 8192;
pub const bytes: usize = width * height;
pub const channels: usize = 1;
pub const glyph_capacity: usize = 196608;
pub const format: varfont.AtlasFormat = .alpha8;

const pad: usize = 8;
const row_gap: usize = 8;
const default_scale: f32 = 2.0;
const first_px: u8 = ir.font_first_px;
const last_px: u8 = ir.font_last_px;
const weights = [_]font_builtin.Weight{ .regular, .semibold, .bold };
const Cached = struct { weight: font_builtin.Weight, ch: u21, px: u8, glyph: ir.Glyph };

pub const Atlas = struct {
    alpha: [bytes]u8,
    glyphs: [glyph_capacity]Cached,
    glyph_count: usize,
    atlas_x: usize,
    atlas_y: usize,
    atlas_row_h: usize,
    font: font_vector.Body,
    builtin: bool,
    device_scale: f32,
    revision: u32,

    pub fn init() Atlas {
        var atlas: Atlas = undefined;
        atlas.initUtf8();
        return atlas;
    }

    pub fn initWithFont(font: font_vector.Body) Atlas {
        var atlas: Atlas = undefined;
        atlas.initWithFontInPlace(font);
        return atlas;
    }

    pub fn initEmpty(self: *Atlas) void { self.initUtf8(); }

    pub fn initUtf8(self: *Atlas) void {
        self.font = font_builtin.body(.regular);
        self.builtin = true;
        self.device_scale = default_scale;
        self.revision = 0;
        self.clearWithoutRevision();
        self.prebuildDeterministicCache() catch @panic("font atlas cache build failed");
        self.bumpRevision();
    }

    pub fn initWithFontInPlace(self: *Atlas, font: font_vector.Body) void {
        self.font = font;
        self.builtin = false;
        self.device_scale = default_scale;
        self.revision = 0;
        self.clearWithoutRevision();
        self.prebuildDeterministicCache() catch @panic("font atlas cache build failed");
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

    pub fn source(self: *Atlas) ir.FontAtlas { return .{ .context = self, .metrics = metrics, .width = textWidth, .glyph = glyph }; }
    pub fn objectSource(self: *Atlas) ir.FontAtlas { return self.source(); }
    pub fn alphaSlice(self: *const Atlas) []const u8 { return &self.alpha; }
    pub fn cachedGlyphCount(self: *const Atlas) usize { return self.glyph_count; }
    pub fn deviceScale(self: *const Atlas) f32 { return self.device_scale; }
    pub fn cacheRevision(self: *const Atlas) u32 { return self.revision; }

    pub fn setDeviceScale(self: *Atlas, scale: f32) void {
        if (@abs(self.device_scale - scale) <= 0.001) return;
        self.device_scale = scale;
        self.clearWithoutRevision();
        self.prebuildDeterministicCache() catch @panic("font atlas cache rebuild failed");
        self.bumpRevision();
    }

    pub fn prepareText(self: *Atlas, value: []const u8, px: u8, weight: font_builtin.Weight) ir.Error!void {
        var index: usize = 0;
        while (nextCodepoint(value, &index)) |cp| {
            if (self.body(weight).glyphForCodepoint(cp) == null) continue;
            if (self.lookupGlyph(weight, cp, px) == null) return error.Budget;
        }
    }

    fn prebuildDeterministicCache(self: *Atlas) varfont.Error!void {
        if (self.builtin) {
            for (weights) |weight| {
                const font = self.body(weight);
                var px: u8 = first_px;
                while (px <= last_px) : (px += 1) {
                    for (font.glyphs) |record| _ = try self.cacheGlyph(weight, record.codepoint, px);
                    if (px == last_px) break;
                }
            }
        } else {
            var px: u8 = first_px;
            while (px <= last_px) : (px += 1) {
                for (self.font.glyphs) |record| _ = try self.cacheGlyph(.regular, record.codepoint, px);
                if (px == last_px) break;
            }
        }
    }

    fn body(self: *const Atlas, weight: font_builtin.Weight) font_vector.Body {
        if (!self.builtin) return self.font;
        return font_builtin.body(weight);
    }

    fn weightForPx(_: *const Atlas, px: u8) font_builtin.Weight {
        if (px >= 24) return .bold;
        if (px >= 16) return .semibold;
        return .regular;
    }

    fn resolveGlyph(self: *Atlas, raw: u21, px: u8) ir.Error!?ir.Glyph {
        const weight = self.weightForPx(px);
        const font = self.body(weight);
        if (font.glyphForCodepoint(raw) == null) return null;
        return self.lookupGlyph(weight, raw, px);
    }

    fn lookupGlyph(self: *const Atlas, weight: font_builtin.Weight, cp: u21, px: u8) ?ir.Glyph {
        for (self.glyphs[0..self.glyph_count]) |entry| {
            if (entry.weight == weight and entry.ch == cp and entry.px == px) return entry.glyph;
        }
        return null;
    }

    fn cacheGlyph(self: *Atlas, weight: font_builtin.Weight, cp: u21, px: u8) varfont.Error!ir.Glyph {
        if (self.glyph_count >= self.glyphs.len) return error.GlyphCacheFull;
        const font = self.body(weight);
        const info = font.glyphForCodepoint(cp) orelse return error.UnsupportedGlyph;
        if (self.atlas_x + 256 >= width) {
            self.atlas_x = pad;
            self.atlas_y += self.atlas_row_h + row_gap;
            self.atlas_row_h = 0;
        }
        if (self.atlas_y + pad >= height) return error.GlyphBitmapBudgetExceeded;
        const scale = (@as(f32, @floatFromInt(px)) * self.device_scale) / @as(f32, @floatFromInt(font.metrics.units_per_em));
        const bitmap = if (info.commands.len == 0) raster.GlyphBitmap{ .width = 0, .height = 0, .left = 0, .top = 0 } else try raster.bakeAlpha(self.alpha[self.atlas_y * width + self.atlas_x ..], width, info.commands, scale, px);
        if (self.atlas_y + bitmap.height + pad >= height) return error.GlyphBitmapBudgetExceeded;
        const ax = self.atlas_x;
        const ay = self.atlas_y;
        self.atlas_row_h = @max(self.atlas_row_h, bitmap.height);
        self.atlas_x += bitmap.width + row_gap;
        const out = ir.Glyph{
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
        self.glyphs[self.glyph_count] = .{ .weight = weight, .ch = cp, .px = px, .glyph = out };
        self.glyph_count += 1;
        return out;
    }

    fn bumpRevision(self: *Atlas) void {
        self.revision +%= 1;
        if (self.revision == 0) self.revision = 1;
    }

    fn s(self: *const Atlas, value: f32) f32 { return value / self.device_scale; }
};

fn metrics(context: *anyopaque, px: u8) ir.TextMetrics {
    const atlas: *Atlas = @ptrCast(@alignCast(context));
    const font = atlas.body(atlas.weightForPx(px));
    const scale = @as(f32, @floatFromInt(px)) / @as(f32, @floatFromInt(font.metrics.units_per_em));
    return .{ .ascender = font.metrics.ascender * scale, .descender = font.metrics.descender * scale };
}

fn textWidth(context: *anyopaque, value: []const u8, px: u8) f32 {
    const atlas: *Atlas = @ptrCast(@alignCast(context));
    const font = atlas.body(atlas.weightForPx(px));
    const scale = @as(f32, @floatFromInt(px)) / @as(f32, @floatFromInt(font.metrics.units_per_em));
    var out: f32 = 0;
    var prev: ?u21 = null;
    var index: usize = 0;
    while (nextCodepoint(value, &index)) |cp| {
        if (font.glyphForCodepoint(cp)) |info| {
            if (prev) |left| out += font.kern(left, cp) * scale;
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

fn nextCodepoint(value: []const u8, index: *usize) ?u21 {
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
