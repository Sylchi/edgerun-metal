const std = @import("std");
const font_vector = @import("../font_vector.zig");
const renderer_ir = @import("ir.zig");
const varfont = @import("../varfont.zig");

pub const width: usize = 2048;
pub const height: usize = 2048;
pub const bytes: usize = width * height;
pub const channels: usize = 1;
pub const glyph_capacity: usize = 1280;
pub const format: varfont.AtlasFormat = .alpha8;
pub const ascii_codepoint_count: usize = renderer_ir.font_last_char - renderer_ir.font_first_char + 1;
pub const ascii_kern_capacity: usize = ascii_codepoint_count * ascii_codepoint_count;
pub const ascii_command_capacity: usize = ascii_codepoint_count * font_vector.max_commands;
pub const AsciiFontStorage = FontObjectStorage(ascii_codepoint_count, ascii_kern_capacity, ascii_command_capacity);
pub const geist_ascii_command_count: usize = 1835;
pub const geist_ascii_font: CompiledFont(ascii_codepoint_count, 0, geist_ascii_command_count) = compileGeistAsciiComptime();

const padding: usize = 8;
const row_gap: usize = 8;
const bitmap_bytes: usize = 2 * 1024 * 1024;
const font_weight: f32 = 560.0;
const device_scale: f32 = 2.0;
const raster_samples: usize = 8;
const quadratic_steps: usize = 10;
const padding_pixels: i16 = 1;

const CachedGlyph = struct {
    ch: u8,
    px: u8,
    glyph: renderer_ir.Glyph,
};

pub fn FontObjectStorage(comptime compiled_glyph_capacity: usize, comptime kern_capacity: usize, comptime command_capacity: usize) type {
    return struct {
        glyphs: [compiled_glyph_capacity]font_vector.GlyphRecord = undefined,
        kerns: [kern_capacity]font_vector.KernRecord = undefined,
        commands: [command_capacity]font_vector.Command = undefined,
        body: ?font_vector.Body = null,

        const Self = @This();

        pub fn compileGeist(self: *Self, codepoints: []const u21) font_vector.CompileError!font_vector.Body {
            const fixed = try font_vector.FixedFace.geistDefault();
            const compiled = try font_vector.compileCodepoints(fixed, codepoints, &self.glyphs, &self.kerns, &self.commands);
            self.body = compiled;
            return compiled;
        }

        pub fn atlas(self: *Self) ?Atlas {
            const body = self.body orelse return null;
            return Atlas.initWithFont(body);
        }
    };
}

pub fn compileGeistAscii(storage: *AsciiFontStorage) font_vector.CompileError!font_vector.Body {
    var codepoints_raw: [ascii_codepoint_count]u21 = undefined;
    return try storage.compileGeist(asciiCodepoints(&codepoints_raw));
}

fn compileGeistAsciiComptime() CompiledFont(ascii_codepoint_count, 0, geist_ascii_command_count) {
    @setEvalBranchQuota(500_000);
    var storage: AsciiFontStorage = .{};
    const compiled = compileGeistAscii(&storage) catch @compileError("failed to compile Geist ASCII font object");
    if (compiled.glyphs.len != ascii_codepoint_count) @compileError("unexpected Geist ASCII glyph count");
    if (compiled.kerns.len != 0) @compileError("unexpected Geist ASCII kern count");
    if (compiled.commands.len != geist_ascii_command_count) @compileError("unexpected Geist ASCII command count");

    var owned = CompiledFont(ascii_codepoint_count, 0, geist_ascii_command_count){
        .metrics = compiled.metrics,
        .glyphs = undefined,
        .kerns = .{},
        .commands = undefined,
    };
    @memcpy(&owned.glyphs, compiled.glyphs);
    @memcpy(&owned.commands, compiled.commands);
    return owned;
}

pub fn CompiledFont(comptime glyph_count: usize, comptime kern_count: usize, comptime command_count: usize) type {
    return struct {
        metrics: font_vector.Metrics,
        glyphs: [glyph_count]font_vector.GlyphRecord,
        kerns: [kern_count]font_vector.KernRecord,
        commands: [command_count]font_vector.Command,

        const Self = @This();

        pub fn body(self: *const Self) font_vector.Body {
            return .{
                .metrics = self.metrics,
                .glyphs = &self.glyphs,
                .kerns = &self.kerns,
                .commands = &self.commands,
            };
        }
    };
}

pub fn asciiCodepoints(out: *[ascii_codepoint_count]u21) []const u21 {
    var index: usize = 0;
    var codepoint: u21 = renderer_ir.font_first_char;
    while (codepoint <= renderer_ir.font_last_char) : (codepoint += 1) {
        out[index] = codepoint;
        index += 1;
    }
    return out[0..index];
}

pub const Atlas = struct {
    alpha: [bytes]u8,
    bitmap: [bitmap_bytes]u8,
    glyphs: [glyph_capacity]CachedGlyph,
    glyph_count: usize,
    atlas_x: usize,
    atlas_y: usize,
    atlas_row_h: usize,
    font: ?font_vector.Body,

    pub fn init() Atlas {
        var atlas: Atlas = undefined;
        atlas.font = null;
        atlas.clear();
        return atlas;
    }

    pub fn initWithFont(font: font_vector.Body) Atlas {
        var atlas: Atlas = undefined;
        atlas.font = font;
        atlas.clear();
        return atlas;
    }

    pub fn clear(self: *Atlas) void {
        @memset(&self.alpha, 0);
        self.glyph_count = 0;
        self.atlas_x = padding;
        self.atlas_y = padding;
        self.atlas_row_h = 0;
    }

    pub fn source(self: *Atlas) renderer_ir.FontAtlas {
        return .{
            .context = self,
            .metrics = metrics,
            .width = textWidth,
            .glyph = glyph,
        };
    }

    pub fn objectSource(self: *Atlas) renderer_ir.FontAtlas {
        return .{
            .context = self,
            .metrics = objectMetrics,
            .width = objectTextWidthCallback,
            .glyph = objectGlyph,
        };
    }

    pub fn alphaSlice(self: *const Atlas) []const u8 {
        return &self.alpha;
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
        if (self.font) |font| return try self.cacheObjectGlyph(font, ch, px);

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
            .w = scaledFontValue(@floatFromInt(glyph_width)),
            .h = scaledFontValue(@floatFromInt(glyph_height)),
            .left = scaledFontValue(@floatFromInt(cached.left)),
            .top = scaledFontValue(@floatFromInt(cached.top)),
            .advance = scaledFontValue(cached.advance),
        };
        self.glyphs[self.glyph_count] = .{ .ch = ch, .px = px, .glyph = packed_glyph };
        self.glyph_count += 1;
        return packed_glyph;
    }

    fn cacheObjectGlyph(self: *Atlas, font: font_vector.Body, ch: u8, px: u8) varfont.Error!renderer_ir.Glyph {
        const glyph_info = font.glyphForCodepoint(ch) orelse return error.UnsupportedGlyph;
        const scale = (@as(f32, @floatFromInt(px)) * device_scale) / @as(f32, @floatFromInt(font.metrics.units_per_em));
        const advance = glyph_info.advance * scale;
        var glyph_width: usize = 0;
        var glyph_height: usize = 0;
        var glyph_left: i16 = 0;
        var glyph_top: i16 = 0;
        var atlas_x = self.atlas_x;
        var atlas_y = self.atlas_y;
        var atlas_u0: f32 = 0.0;
        var atlas_v0: f32 = 0.0;
        var atlas_u1: f32 = 0.0;
        var atlas_v1: f32 = 0.0;

        if (glyph_info.commands.len > 0) {
            var edges: [varfont.max_edges]Edge = undefined;
            const edge_count = try flattenCommands(glyph_info.commands, scale, &edges);
            const bounds = edgeBounds(edges[0..edge_count]) orelse return error.InvalidFont;
            const left = @as(i16, @intFromFloat(@floor(bounds.x_min))) - padding_pixels;
            const right = @as(i16, @intFromFloat(@ceil(bounds.x_max))) + padding_pixels;
            const top = @as(i16, @intFromFloat(@floor(bounds.y_min))) - padding_pixels;
            const bottom = @as(i16, @intFromFloat(@ceil(bounds.y_max))) + padding_pixels;
            if (right > left and bottom > top) {
                glyph_left = left;
                glyph_top = top;
                glyph_width = @intCast(right - left);
                glyph_height = @intCast(bottom - top);
                if (self.atlas_x + glyph_width + padding >= width) {
                    self.atlas_x = padding;
                    self.atlas_y += self.atlas_row_h + row_gap;
                    self.atlas_row_h = 0;
                }
                if (self.atlas_y + glyph_height + padding >= height) return error.GlyphBitmapBudgetExceeded;
                atlas_x = self.atlas_x;
                atlas_y = self.atlas_y;
                bakeAlphaBitmap(self.alpha[atlas_y * width + atlas_x ..], glyph_width, glyph_height, glyph_left, glyph_top, edges[0..edge_count]);
                self.atlas_row_h = @max(self.atlas_row_h, glyph_height);
                self.atlas_x += glyph_width + row_gap;
                atlas_u0 = (@as(f32, @floatFromInt(atlas_x)) + 0.5) / @as(f32, @floatFromInt(width));
                atlas_v0 = (@as(f32, @floatFromInt(atlas_y)) + 0.5) / @as(f32, @floatFromInt(height));
                atlas_u1 = (@as(f32, @floatFromInt(atlas_x + glyph_width)) - 0.5) / @as(f32, @floatFromInt(width));
                atlas_v1 = (@as(f32, @floatFromInt(atlas_y + glyph_height)) - 0.5) / @as(f32, @floatFromInt(height));
            }
        }

        const packed_glyph = renderer_ir.Glyph{
            .u0 = atlas_u0,
            .v0 = atlas_v0,
            .u1 = atlas_u1,
            .v1 = atlas_v1,
            .w = scaledFontValue(@floatFromInt(glyph_width)),
            .h = scaledFontValue(@floatFromInt(glyph_height)),
            .left = scaledFontValue(@floatFromInt(glyph_left)),
            .top = scaledFontValue(@floatFromInt(glyph_top)),
            .advance = scaledFontValue(advance),
        };
        self.glyphs[self.glyph_count] = .{ .ch = ch, .px = px, .glyph = packed_glyph };
        self.glyph_count += 1;
        return packed_glyph;
    }

    fn copyGlyphBitmap(self: *Atlas, x: usize, y: usize, w: usize, h: usize, source_pixels: []const u8) void {
        var row: usize = 0;
        while (row < h) : (row += 1) {
            const dst = (y + row) * width + x;
            const src = row * w;
            @memcpy(self.alpha[dst .. dst + w], source_pixels[src .. src + w]);
        }
    }
};

fn metrics(context: *anyopaque, px: u8) renderer_ir.TextMetrics {
    const atlas: *Atlas = @ptrCast(@alignCast(context));
    if (atlas.font) |font| {
        const scale = @as(f32, @floatFromInt(px)) / @as(f32, @floatFromInt(font.metrics.units_per_em));
        return .{
            .ascender = font.metrics.ascender * scale,
            .descender = font.metrics.descender * scale,
        };
    }

    const face = varfont.Face.geist() catch unreachable;
    const value = face.metrics(@floatFromInt(px));
    return .{ .ascender = value.ascender, .descender = value.descender };
}

fn objectMetrics(context: *anyopaque, px: u8) renderer_ir.TextMetrics {
    const atlas: *Atlas = @ptrCast(@alignCast(context));
    const font = atlas.font orelse return .{ .ascender = 0, .descender = 0 };
    const scale = @as(f32, @floatFromInt(px)) / @as(f32, @floatFromInt(font.metrics.units_per_em));
    return .{
        .ascender = font.metrics.ascender * scale,
        .descender = font.metrics.descender * scale,
    };
}

fn textWidth(context: *anyopaque, value: []const u8, px: u8) f32 {
    const atlas: *Atlas = @ptrCast(@alignCast(context));
    if (atlas.font) |font| return objectTextWidth(font, value, px);

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

fn objectTextWidthCallback(context: *anyopaque, value: []const u8, px: u8) f32 {
    const atlas: *Atlas = @ptrCast(@alignCast(context));
    const font = atlas.font orelse return 0;
    return objectTextWidth(font, value, px);
}

fn objectTextWidth(font: font_vector.Body, value: []const u8, px: u8) f32 {
    const scale = @as(f32, @floatFromInt(px)) / @as(f32, @floatFromInt(font.metrics.units_per_em));
    var out: f32 = 0;
    var previous: ?u21 = null;
    for (value) |byte| {
        if (byte < renderer_ir.font_first_char or byte > renderer_ir.font_last_char) continue;
        const codepoint: u21 = @intCast(byte);
        if (previous) |left| out += font.kern(left, codepoint) * scale;
        if (font.glyphForCodepoint(codepoint)) |info| {
            out += info.advance * scale;
            previous = codepoint;
        }
    }
    return out;
}

fn scaledFontValue(value: f32) f32 {
    return value / device_scale;
}

fn glyph(context: *anyopaque, ch: u8, px: u8) renderer_ir.Error!?renderer_ir.Glyph {
    const atlas: *Atlas = @ptrCast(@alignCast(context));
    return atlas.resolveGlyph(ch, px);
}

fn objectGlyph(context: *anyopaque, ch: u8, px: u8) renderer_ir.Error!?renderer_ir.Glyph {
    const atlas: *Atlas = @ptrCast(@alignCast(context));
    if (atlas.font == null) return null;
    return atlas.resolveGlyph(ch, px);
}

const Point = struct {
    x: f32,
    y: f32,
};

const Edge = struct {
    a: Point,
    b: Point,
};

const Intersection = struct {
    x: f32,
    direction: i8,
};

const Bounds = struct {
    x_min: f32,
    y_min: f32,
    x_max: f32,
    y_max: f32,
};

fn flattenCommands(commands: []const font_vector.Command, scale: f32, edges: *[varfont.max_edges]Edge) varfont.Error!usize {
    var edge_count: usize = 0;
    var current = Point{ .x = 0, .y = 0 };
    var contour_start = current;
    var has_current = false;

    for (commands) |command| switch (command) {
        .move_to => |point| {
            current = transformPoint(point, scale);
            contour_start = current;
            has_current = true;
        },
        .line_to => |point| {
            if (!has_current) return error.InvalidFont;
            const next = transformPoint(point, scale);
            edge_count = try appendEdge(edges, edge_count, current, next);
            current = next;
        },
        .quad_to => |quad| {
            if (!has_current) return error.InvalidFont;
            const control = transformPoint(quad.control, scale);
            const end = transformPoint(quad.end, scale);
            edge_count = try appendQuadratic(edges, edge_count, current, control, end);
            current = end;
        },
        .close => {
            if (!has_current) return error.InvalidFont;
            edge_count = try appendEdge(edges, edge_count, current, contour_start);
            has_current = false;
        },
    };

    if (has_current) edge_count = try appendEdge(edges, edge_count, current, contour_start);
    return edge_count;
}

fn transformPoint(point: font_vector.Point, scale: f32) Point {
    return .{ .x = point.x * scale, .y = -point.y * scale };
}

fn appendQuadratic(edges: *[varfont.max_edges]Edge, edge_count_start: usize, p0: Point, p1: Point, p2: Point) varfont.Error!usize {
    var edge_count = edge_count_start;
    var previous = p0;
    var step: usize = 1;
    while (step <= quadratic_steps) : (step += 1) {
        const t = @as(f32, @floatFromInt(step)) / @as(f32, @floatFromInt(quadratic_steps));
        const mt = 1.0 - t;
        const next = Point{
            .x = mt * mt * p0.x + 2.0 * mt * t * p1.x + t * t * p2.x,
            .y = mt * mt * p0.y + 2.0 * mt * t * p1.y + t * t * p2.y,
        };
        edge_count = try appendEdge(edges, edge_count, previous, next);
        previous = next;
    }
    return edge_count;
}

fn appendEdge(edges: *[varfont.max_edges]Edge, edge_count: usize, a: Point, b: Point) varfont.Error!usize {
    if (edge_count >= varfont.max_edges) return error.GlyphEdgeBudgetExceeded;
    if (a.x == b.x and a.y == b.y) return edge_count;
    edges[edge_count] = .{ .a = a, .b = b };
    return edge_count + 1;
}

fn edgeBounds(edges: []const Edge) ?Bounds {
    if (edges.len == 0) return null;
    var bounds = Bounds{
        .x_min = edges[0].a.x,
        .y_min = edges[0].a.y,
        .x_max = edges[0].a.x,
        .y_max = edges[0].a.y,
    };
    for (edges) |edge| {
        includePoint(&bounds, edge.a);
        includePoint(&bounds, edge.b);
    }
    return bounds;
}

fn includePoint(bounds: *Bounds, point: Point) void {
    bounds.x_min = @min(bounds.x_min, point.x);
    bounds.y_min = @min(bounds.y_min, point.y);
    bounds.x_max = @max(bounds.x_max, point.x);
    bounds.y_max = @max(bounds.y_max, point.y);
}

fn bakeAlphaBitmap(atlas_alpha: []u8, glyph_width: usize, glyph_height: usize, glyph_left: i16, glyph_top: i16, edges: []const Edge) void {
    const sample_count = raster_samples * raster_samples;
    const glyph_right = @as(f32, @floatFromInt(glyph_left)) + @as(f32, @floatFromInt(glyph_width));
    var intersections: [varfont.max_edges]Intersection = undefined;

    var py: usize = 0;
    while (py < glyph_height) : (py += 1) {
        const row = atlas_alpha[py * width .. py * width + glyph_width];
        @memset(row, 0);

        var sy: usize = 0;
        while (sy < raster_samples) : (sy += 1) {
            const sample_y = @as(f32, @floatFromInt(glyph_top)) + @as(f32, @floatFromInt(py)) + sampleOffset(sy);
            const intersection_count = sortedIntersections(sample_y, edges, &intersections);
            var winding: i32 = 0;
            var intersection_index: usize = 0;
            while (intersection_index < intersection_count) : (intersection_index += 1) {
                winding += intersections[intersection_index].direction;
                if (winding != 0 and intersection_index + 1 < intersection_count) {
                    fillSpanSamples(
                        row,
                        glyph_left,
                        glyph_right,
                        intersections[intersection_index].x,
                        intersections[intersection_index + 1].x,
                    );
                }
            }
        }

        var px: usize = 0;
        while (px < glyph_width) : (px += 1) {
            row[px] = @intCast((@as(u16, row[px]) * 255) / sample_count);
        }
    }
}

fn sampleOffset(index: usize) f32 {
    return (@as(f32, @floatFromInt(index)) + 0.5) / @as(f32, @floatFromInt(raster_samples));
}

fn sortedIntersections(y: f32, edges: []const Edge, intersections: *[varfont.max_edges]Intersection) usize {
    var count: usize = 0;
    for (edges) |edge| {
        const ay = edge.a.y;
        const by = edge.b.y;
        if (ay <= y) {
            if (by > y) {
                insertIntersection(intersections, &count, .{
                    .x = edgeXAtY(edge, y),
                    .direction = 1,
                });
            }
        } else if (by <= y) {
            insertIntersection(intersections, &count, .{
                .x = edgeXAtY(edge, y),
                .direction = -1,
            });
        }
    }
    return count;
}

fn edgeXAtY(edge: Edge, y: f32) f32 {
    return edge.a.x + ((y - edge.a.y) * (edge.b.x - edge.a.x)) / (edge.b.y - edge.a.y);
}

fn insertIntersection(intersections: *[varfont.max_edges]Intersection, count: *usize, value: Intersection) void {
    var index = count.*;
    while (index > 0 and intersections[index - 1].x > value.x) : (index -= 1) {
        intersections[index] = intersections[index - 1];
    }
    intersections[index] = value;
    count.* += 1;
}

fn fillSpanSamples(row: []u8, glyph_left: i16, glyph_right: f32, span_a: f32, span_b: f32) void {
    const left = @max(span_a, @as(f32, @floatFromInt(glyph_left)));
    const right = @min(span_b, glyph_right);
    if (right <= left) return;

    const local_left = left - @as(f32, @floatFromInt(glyph_left));
    const local_right = right - @as(f32, @floatFromInt(glyph_left));
    var px: usize = @intFromFloat(@max(@floor(local_left), 0.0));
    const px_end: usize = @min(row.len, @as(usize, @intFromFloat(@ceil(local_right))));
    while (px < px_end) : (px += 1) {
        var sx: usize = 0;
        while (sx < raster_samples) : (sx += 1) {
            const sample_x = @as(f32, @floatFromInt(glyph_left)) + @as(f32, @floatFromInt(px)) + sampleOffset(sx);
            if (sample_x >= left and sample_x < right) row[px] += 1;
        }
    }
}

test "font atlas supplies renderer ir text vertices" {
    var atlas = Atlas.init();
    var storage = renderer_ir.FixedBuffers(1, renderer_ir.textured_quad_vertex_count, 0, 0, 0, 0, 0){};
    const buffers = storage.buffers();
    const sources = renderer_ir.Sources{
        .font = atlas.source(),
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

test "font atlas renders text from canonical font object body" {
    const commands = [_]font_vector.Command{
        .{ .move_to = .{ .x = 0, .y = 0 } },
        .{ .line_to = .{ .x = 1000, .y = 0 } },
        .{ .line_to = .{ .x = 1000, .y = 1000 } },
        .{ .line_to = .{ .x = 0, .y = 1000 } },
        .close,
    };
    const glyphs = [_]font_vector.GlyphRecord{
        .{ .codepoint = 'A', .glyph_id = 1, .command_offset = 0, .command_count = commands.len, .advance = 1000 },
        .{ .codepoint = 'V', .glyph_id = 2, .command_offset = 0, .command_count = commands.len, .advance = 1000 },
    };
    const kerns = [_]font_vector.KernRecord{
        .{ .left_codepoint = 'A', .right_codepoint = 'V', .advance_adjust = -100 },
    };
    const font = font_vector.Body{
        .metrics = .{ .units_per_em = 1000, .ascender = 800, .descender = -200, .line_gap = 0, .y_min = -200, .y_max = 1000 },
        .glyphs = &glyphs,
        .kerns = &kerns,
        .commands = &commands,
    };

    var atlas = Atlas.initWithFont(font);
    const source = atlas.source();
    try std.testing.expectApproxEqAbs(@as(f32, 30.4), source.width(source.context, "AV", 16), 0.001);

    var storage = renderer_ir.FixedBuffers(1, renderer_ir.textured_quad_vertex_count, 0, 0, 0, 0, 0){};
    try renderer_ir.pushText(storage.buffers(), source, .base, .{ .x = 0, .y = 0, .w = 64, .h = 18 }, "A", .text, .start);

    try std.testing.expectEqual(@as(usize, 1), atlas.cachedGlyphCount());
    try std.testing.expect(atlasHasCoverage(atlas.alphaSlice()));
}

test "font atlas storage compiles a codepoint set into object font renderer input" {
    var codepoints_raw: [ascii_codepoint_count]u21 = undefined;
    const codepoints = asciiCodepoints(&codepoints_raw);
    var storage = FontObjectStorage(ascii_codepoint_count, 16, font_vector.max_commands * 2){};
    _ = try storage.compileGeist(codepoints[0..2]);
    var atlas = storage.atlas().?;
    const source = atlas.source();

    var buffers_storage = renderer_ir.FixedBuffers(1, renderer_ir.textured_quad_vertex_count, 0, 0, 0, 0, 0){};
    try renderer_ir.pushText(buffers_storage.buffers(), source, .base, .{ .x = 0, .y = 0, .w = 64, .h = 18 }, " !", .text, .start);

    try std.testing.expect(atlas.cachedGlyphCount() > 0);
    try std.testing.expect(atlasHasCoverage(atlas.alphaSlice()));
}

fn atlasHasCoverage(alpha: []const u8) bool {
    for (alpha) |pixel| {
        if (pixel != 0) return true;
    }
    return false;
}
