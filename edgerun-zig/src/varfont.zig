const std = @import("std");
const math = @import("math.zig");
const bytes_mod = @import("bytes.zig");
const ui = @import("ui.zig");

const geist_bytes = @embedFile("assets/Geist[wght].ttf");

pub const Error = error{
    InvalidFont,
    MissingTable,
    UnsupportedCmap,
    UnsupportedGlyph,
    GlyphPointBudgetExceeded,
    GlyphEdgeBudgetExceeded,
    GlyphCacheFull,
    GlyphBitmapBudgetExceeded,
};

pub const max_tables = 96;
pub const max_axes = 16;
pub const max_avar_segments = 96;
pub const max_kern_pairs = 1024;
pub const max_points = 768;
pub const max_contours = 128;
pub const max_contour_points = max_points * 2 + 2;
pub const max_edges = 2048;
pub const max_curves = 1024;
pub const max_cached_glyphs = 1024;
pub const vertices_per_glyph = 6;
pub const default_px_size: f32 = 18.0;
const glyph_padding = 1;
const raster_samples_small: usize = 8;
const raster_samples_medium: usize = 8;
const raster_samples_large: usize = 8;
const raster_small_px_limit: f32 = 14.0;
const raster_medium_px_limit: f32 = 28.0;
const msdf_channels = 3;
const msdf_supersample = 8;
const msdf_spread: f32 = 2.0;
const msdf_mid_alpha: f32 = 128.0;
const msdf_edge_scale: f32 = 255.0;
const msdf_pi: f32 = 3.14159265359;
const msdf_two_pi: f32 = 6.28318530718;
const msdf_channel_scale: f32 = 3.0;
const msdf_channel_half_bin: f32 = 0.5 / msdf_channel_scale;
const msdf_missing_channel_epsilon: f32 = 0.000001;
const segment_tolerance: f32 = 0.0000001;
const curve_linear_tolerance: f32 = 0.000000000001;
const curve_newton_epsilon: f32 = 0.00001;
const curve_crossing_epsilon: f32 = 0.0000001;
const curve_distance_samples = 16;
const curve_newton_steps = 8;
const boundary_probe_offset: f32 = 0.25;
const tessellation_soft_limit = 12;
const tessellation_hard_limit = 16;
const quadratic_tolerance_sq: f32 = 0.01;
const flattened_curve_edge_flag: u8 = 0x80;
const vertex_color_one: f32 = 1.0;

const scalar_ttf: u32 = 0x0001_0000;
const scalar_otto: u32 = 0x4f54_544f;
const tag_head = tag("head");
const tag_hhea = tag("hhea");
const tag_hmtx = tag("hmtx");
const tag_maxp = tag("maxp");
const tag_loca = tag("loca");
const tag_glyf = tag("glyf");
const tag_cmap = tag("cmap");
const tag_fvar = tag("fvar");
const tag_gvar = tag("gvar");
const tag_avar = tag("avar");
const tag_kern = tag("kern");

const flag_on_curve: u8 = 0x01;
const flag_x_short: u8 = 0x02;
const flag_y_short: u8 = 0x04;
const flag_repeat: u8 = 0x08;
const flag_x_same_or_positive: u8 = 0x10;
const flag_y_same_or_positive: u8 = 0x20;
const comp_arg_words: u16 = 0x0001;
const comp_args_xy: u16 = 0x0002;
const comp_have_scale: u16 = 0x0008;
const comp_more: u16 = 0x0020;
const comp_have_xy_scale: u16 = 0x0040;
const comp_have_2x2: u16 = 0x0080;
const max_composite_depth = 8;
const tuple_count_mask: u16 = 0x0fff;
const tuple_shared_points: u16 = 0x8000;
const tuple_embedded_peak: u16 = 0x8000;
const tuple_intermediate: u16 = 0x4000;
const tuple_private_points: u16 = 0x2000;
const gvar_offset_format_32: u16 = 0x0001;
const kern_coverage_format_mask: u16 = 0x00ff;
const kern_format_0: u16 = 0;
const kern_pair_bytes: usize = 6;
const kern_subtable_header_bytes: usize = 8;
const kern_format_0_header_bytes: usize = 14;
const avar_header_bytes: usize = 8;
const avar_axis_offset_bytes: usize = 2;
const avar_segment_count_bytes: usize = 2;
const avar_segment_value_bytes: usize = 2;
const avar_segment_pair_bytes: usize = avar_segment_value_bytes * 2;
const sfnt_version_1: u32 = 0x0001_0000;

pub const Axis = struct {
    tag: [4]u8,
    min: f32,
    default: f32,
    max: f32,
};

pub const Metrics = struct {
    units_per_em: u16,
    px_size: f32,
    ascender: f32,
    descender: f32,
    line_gap: f32,
    line_height: f32,
    y_min: f32,
    y_max: f32,
};

const Table = struct {
    id: u32,
    offset: usize,
    len: usize,
};

pub const Point = struct {
    x: f32,
    y: f32,
    on_curve: bool,
};

const Edge = struct {
    a: Point,
    b: Point,
};

const Curve = struct {
    p0: Point,
    p1: Point,
    p2: Point,
};

const MsdfEdgeKind = enum {
    line,
    quadratic,
};

const MsdfEdge = struct {
    kind: MsdfEdgeKind,
    p0: Point,
    p1: Point,
    p2: Point,
};

pub const AtlasFormat = enum {
    alpha8,
    sdf8,
    msdf_rgb,

    fn channels(self: AtlasFormat) usize {
        return switch (self) {
            .alpha8 => 1,
            .sdf8 => 1,
            .msdf_rgb => msdf_channels,
        };
    }
};

pub const OutlineCounts = struct {
    points: usize,
    contours: usize,
};

const RasterOutline = struct {
    edge_count: usize,
    curve_count: usize,
};

const PointSet = struct {
    all: bool,
    points: [max_points + 4]u16 = undefined,
    count: usize = 0,
    consumed: usize = 0,
};

const Bounds = struct {
    x_min: f32,
    x_max: f32,
    y_min: f32,
    y_max: f32,
};

const KernPair = struct {
    left: u16,
    right: u16,
    adjust: i16,
};

const AvarAxis = struct {
    offset: usize,
    count: usize,
};

pub const ShapedGlyph = struct {
    glyph_id: u16,
    codepoint: u21,
    advance: f32,
    x_offset: f32 = 0.0,
    y_offset: f32 = 0.0,
    cluster: usize,
};

pub const Vertex = struct {
    x: f32,
    y: f32,
    u: f32,
    v: f32,
    r: f32,
    g: f32,
    b: f32,
    a: f32,
    atlas_id: u32,
};

pub const VertexAtlasRange = struct {
    atlas_id: u32,
    start_vertex: usize,
    vertex_count: usize,
};

pub const GlyphBitmapView = struct {
    pixels: []const u8,
    width: u16,
    height: u16,
    format: AtlasFormat,
    bytes_per_pixel: usize,
};

pub const CachedGlyph = struct {
    glyph_id: u16,
    px_key: u16,
    format: AtlasFormat,
    width: u16,
    height: u16,
    left: i16,
    top: i16,
    advance: f32,
    bitmap_offset: usize,
    variation_key: u32,
};

pub const Cache = struct {
    face: Face,
    format: AtlasFormat = .alpha8,
    axis_values: [max_axes]f32 = [_]f32{0.0} ** max_axes,
    glyphs: [max_cached_glyphs]CachedGlyph = undefined,
    glyph_count: usize = 0,
    bitmap: []u8,
    bitmap_len: usize = 0,

    pub fn init(face: Face, bitmap: []u8) Cache {
        return .{ .face = face, .bitmap = bitmap };
    }

    pub fn initFormat(face: Face, bitmap: []u8, format: AtlasFormat) Cache {
        return .{ .face = face, .format = format, .bitmap = bitmap };
    }

    pub fn setAxis(self: *Cache, axis_tag: *const [4:0]u8, value: f32) bool {
        for (self.face.axes[0..self.face.axis_count], 0..) |axis, index| {
            if (bytes_mod.eql(&axis.tag, axis_tag[0..4])) {
                self.axis_values[index] = self.face.mapAxisValue(index, value);
                self.clear();
                return true;
            }
        }
        return false;
    }

    pub fn clear(self: *Cache) void {
        self.glyph_count = 0;
        self.bitmap_len = 0;
    }

    pub fn bakeGlyph(self: *Cache, glyph_id: u16, px_size: f32) Error!CachedGlyph {
        return self.glyph(glyph_id, px_size);
    }

    pub fn bitmapView(self: Cache, glyph_value: CachedGlyph) GlyphBitmapView {
        const byte_len = @as(usize, glyph_value.width) * @as(usize, glyph_value.height) * glyph_value.format.channels();
        return .{
            .pixels = self.bitmap[glyph_value.bitmap_offset .. glyph_value.bitmap_offset + byte_len],
            .width = glyph_value.width,
            .height = glyph_value.height,
            .format = glyph_value.format,
            .bytes_per_pixel = glyph_value.format.channels(),
        };
    }

    pub fn drawText(self: *Cache, surface: anytype, bounds: ui.Rect, text: []const u8, color: ui.Color, px_size: f32) Error!void {
        const m = self.face.metrics(px_size);
        var x = bounds.x;
        const baseline = bounds.y + m.ascender;
        var previous_glyph: u16 = 0;
        for (text) |byte| {
            if (byte >= 0x80) return error.UnsupportedGlyph;
            const glyph_id = self.face.glyphId(@intCast(byte));
            if (previous_glyph != 0) x += self.face.kern(previous_glyph, glyph_id, px_size);
            const cached = self.glyph(glyph_id, px_size) catch |err| switch (err) {
                error.UnsupportedGlyph => {
                    x += self.face.advance(glyph_id, px_size);
                    previous_glyph = glyph_id;
                    continue;
                },
                else => return err,
            };
            if (byte != ' ') self.blit(surface, cached, x, baseline, color, bounds);
            x += cached.advance;
            previous_glyph = glyph_id;
            if (x > bounds.x + bounds.w) break;
        }
    }

    pub fn buildVertexBatch(self: *Cache, shaped: []const ShapedGlyph, origin_x: f32, origin_y: f32, px_size: f32, out: []Vertex) Error![]Vertex {
        if (shaped.len > out.len / vertices_per_glyph) return error.GlyphPointBudgetExceeded;
        var pen_x = origin_x;
        var vertex_count: usize = 0;
        for (shaped) |glyph_value| {
            const baked = try self.glyph(glyph_value.glyph_id, px_size);
            if (baked.width != 0 and baked.height != 0) {
                appendGlyphQuad(
                    out,
                    &vertex_count,
                    pen_x + glyph_value.x_offset + @as(f32, @floatFromInt(baked.left)),
                    origin_y + glyph_value.y_offset - @as(f32, @floatFromInt(baked.top)),
                    baked,
                );
            }
            pen_x += glyph_value.advance;
        }
        return out[0..vertex_count];
    }

    pub fn buildVertexBatchesByAtlas(self: *Cache, shaped: []const ShapedGlyph, origin_x: f32, origin_y: f32, px_size: f32, out_vertices: []Vertex, out_ranges: []VertexAtlasRange) Error!struct { vertices: []Vertex, ranges: []VertexAtlasRange } {
        const vertices = try self.buildVertexBatch(shaped, origin_x, origin_y, px_size, out_vertices);
        if (vertices.len == 0) return .{ .vertices = vertices, .ranges = out_ranges[0..0] };
        if (out_ranges.len == 0) return error.GlyphCacheFull;
        out_ranges[0] = .{ .atlas_id = 0, .start_vertex = 0, .vertex_count = vertices.len };
        return .{ .vertices = vertices, .ranges = out_ranges[0..1] };
    }

    fn glyph(self: *Cache, glyph_id: u16, px_size: f32) Error!CachedGlyph {
        const key = pxKey(px_size);
        const variation_key = self.variationKey();
        for (self.glyphs[0..self.glyph_count]) |glyph_value| {
            if (glyph_value.glyph_id == glyph_id and glyph_value.px_key == key and glyph_value.variation_key == variation_key and glyph_value.format == self.format) return glyph_value;
        }
        if (self.glyph_count >= max_cached_glyphs) return error.GlyphCacheFull;
        const next = try self.face.bakeGlyph(glyph_id, px_size, self.axis_values, variation_key, self.format, self.bitmap, &self.bitmap_len);
        self.glyphs[self.glyph_count] = next;
        self.glyph_count += 1;
        return next;
    }

    fn variationKey(self: Cache) u32 {
        var hash: u32 = 2166136261;
        for (self.axis_values[0..self.face.axis_count]) |value| {
            const quantized: i16 = @intFromFloat(@round(value * 16384.0));
            const bits: u16 = @bitCast(quantized);
            hash ^= bits;
            hash *%= 16777619;
        }
        return hash;
    }

    fn blit(self: Cache, surface: anytype, glyph_value: CachedGlyph, x: f32, baseline: f32, color: ui.Color, clip: ui.Rect) void {
        const dst_x = @as(i32, @intFromFloat(@round(x))) + glyph_value.left;
        const dst_y = @as(i32, @intFromFloat(@round(baseline))) + glyph_value.top;
        var gy: usize = 0;
        while (gy < glyph_value.height) : (gy += 1) {
            const sy_i32 = dst_y + @as(i32, @intCast(gy));
            if (sy_i32 < 0) continue;
            const sy: usize = @intCast(sy_i32);
            if (sy >= surface.height) continue;
            const sy_f: f32 = @floatFromInt(sy);
            if (sy_f < clip.y or sy_f >= clip.y + clip.h) continue;
            var gx: usize = 0;
            while (gx < glyph_value.width) : (gx += 1) {
                const sx_i32 = dst_x + @as(i32, @intCast(gx));
                if (sx_i32 < 0) continue;
                const sx: usize = @intCast(sx_i32);
                if (sx >= surface.width) continue;
                const sx_f: f32 = @floatFromInt(sx);
                if (sx_f < clip.x or sx_f >= clip.x + clip.w) continue;
                const alpha = self.glyphAlpha(glyph_value, gx, gy);
                if (alpha != 0) surface.blendPixel(sx, sy, color, alpha);
            }
        }
    }

    fn glyphAlpha(self: Cache, glyph_value: CachedGlyph, x: usize, y: usize) u8 {
        const pixel_offset = glyph_value.bitmap_offset + (y * glyph_value.width + x) * glyph_value.format.channels();
        return switch (glyph_value.format) {
            .alpha8 => self.bitmap[pixel_offset],
            .sdf8 => msdfCoverageAlpha(self.bitmap[pixel_offset]),
            .msdf_rgb => msdfCoverageAlpha(self.bitmap[pixel_offset + 2]),
        };
    }
};

pub const Face = struct {
    data: []const u8,
    tables: [max_tables]Table = undefined,
    table_count: usize = 0,
    units_per_em: u16 = 0,
    ascender: i16 = 0,
    descender: i16 = 0,
    line_gap: i16 = 0,
    y_min: i16 = 0,
    y_max: i16 = 0,
    num_h_metrics: u16 = 0,
    num_glyphs: u16 = 0,
    index_to_loc_format: i16 = 0,
    cmap_offset: usize = 0,
    cmap_len: usize = 0,
    cmap_format: u16 = 0,
    hmtx_offset: usize = 0,
    loca_offset: usize = 0,
    glyf_offset: usize = 0,
    gvar_offset: usize = 0,
    gvar_len: usize = 0,
    gvar_axis_count: usize = 0,
    gvar_shared_tuple_count: usize = 0,
    gvar_shared_tuple_offset: usize = 0,
    gvar_glyph_count: usize = 0,
    gvar_glyph_data_offset: usize = 0,
    gvar_offsets_32: bool = false,
    axes: [max_axes]Axis = undefined,
    axis_count: usize = 0,
    avar_axes: [max_axes]AvarAxis = [_]AvarAxis{.{ .offset = 0, .count = 0 }} ** max_axes,
    avar_from: [max_avar_segments]f32 = undefined,
    avar_to: [max_avar_segments]f32 = undefined,
    avar_segment_count: usize = 0,
    kern_pairs: [max_kern_pairs]KernPair = undefined,
    kern_pair_count: usize = 0,

    pub fn init(data: []const u8) Error!Face {
        var face = Face{ .data = data };
        try face.parseDirectory();
        try face.parseRequiredTables();
        face.parseAxes();
        try face.parseAvar();
        try face.parseKern();
        return face;
    }

    pub fn geist() Error!Face {
        return init(geist_bytes);
    }

    pub fn metrics(self: Face, px_size: f32) Metrics {
        const scale = px_size / @as(f32, @floatFromInt(self.units_per_em));
        return .{
            .units_per_em = self.units_per_em,
            .px_size = px_size,
            .ascender = @as(f32, @floatFromInt(self.ascender)) * scale,
            .descender = @as(f32, @floatFromInt(self.descender)) * scale,
            .line_gap = @as(f32, @floatFromInt(self.line_gap)) * scale,
            .line_height = @as(f32, @floatFromInt(self.ascender - self.descender + self.line_gap)) * scale,
            .y_min = @as(f32, @floatFromInt(self.y_min)) * scale,
            .y_max = @as(f32, @floatFromInt(self.y_max)) * scale,
        };
    }

    pub fn glyphId(self: Face, codepoint: u21) u16 {
        return switch (self.cmap_format) {
            4 => self.glyphIdFormat4(codepoint),
            12 => self.glyphIdFormat12(codepoint),
            else => 0,
        };
    }

    pub fn advance(self: Face, glyph_id: u16, px_size: f32) f32 {
        if (self.units_per_em == 0 or self.num_h_metrics == 0) return 0.0;
        const scale = px_size / @as(f32, @floatFromInt(self.units_per_em));
        const metric_index: usize = if (glyph_id < self.num_h_metrics) glyph_id else self.num_h_metrics - 1;
        const offset = self.hmtx_offset + metric_index * 4;
        return @as(f32, @floatFromInt(readU16(self.data, offset))) * scale;
    }

    pub fn kern(self: Face, left: u16, right: u16, px_size: f32) f32 {
        if (self.units_per_em == 0) return 0.0;
        for (self.kern_pairs[0..self.kern_pair_count]) |pair| {
            if (pair.left == left and pair.right == right) {
                const scale = px_size / @as(f32, @floatFromInt(self.units_per_em));
                return @as(f32, @floatFromInt(pair.adjust)) * scale;
            }
        }
        return 0.0;
    }

    pub fn mapAxisValue(self: Face, axis_index: usize, value: f32) f32 {
        if (axis_index >= self.axis_count) return 0.0;
        return self.applyAvarMapping(axis_index, normalizeAxis(self.axes[axis_index], value));
    }

    pub fn shapeAscii(self: Face, text: []const u8, px_size: f32, out: []ShapedGlyph) Error![]ShapedGlyph {
        if (out.len < text.len) return error.GlyphPointBudgetExceeded;
        for (text, 0..) |byte, i| {
            if (byte >= 0x80) return error.UnsupportedGlyph;
            const cp: u21 = @intCast(byte);
            const glyph_id = self.glyphId(cp);
            const kern_adjust = if (i > 0) self.kern(out[i - 1].glyph_id, glyph_id, px_size) else 0.0;
            out[i] = .{ .glyph_id = glyph_id, .codepoint = cp, .advance = self.advance(glyph_id, px_size) + kern_adjust, .x_offset = kern_adjust, .cluster = i };
        }
        return out[0..text.len];
    }

    pub fn fixedAxisValues(self: Face, comptime axis_tag: *const [4:0]u8, value: f32) [max_axes]f32 {
        var values = [_]f32{0.0} ** max_axes;
        for (self.axes[0..self.axis_count], 0..) |axis, index| {
            if (bytes_mod.eql(&axis.tag, axis_tag[0..4])) {
                values[index] = self.mapAxisValue(index, value);
                return values;
            }
        }
        return values;
    }

    pub fn outline(
        self: Face,
        glyph_id: u16,
        axis_values: [max_axes]f32,
        points: *[max_points]Point,
        contour_ends: *[max_contours]u16,
    ) Error!OutlineCounts {
        const counts = try self.loadGlyphOutline(glyph_id, points, contour_ends, 0);
        try self.applyGvar(glyph_id, points[0..counts.points], contour_ends[0..counts.contours], axis_values);
        return counts;
    }

    fn parseDirectory(self: *Face) Error!void {
        if (self.data.len < 12) return error.InvalidFont;
        const scalar = readU32(self.data, 0);
        if (scalar != scalar_ttf and scalar != scalar_otto) return error.InvalidFont;
        const count = readU16(self.data, 4);
        if (count > max_tables or self.data.len < 12 + @as(usize, count) * 16) return error.InvalidFont;
        self.table_count = count;
        var i: usize = 0;
        while (i < count) : (i += 1) {
            const rec = 12 + i * 16;
            self.tables[i] = .{
                .id = readU32(self.data, rec),
                .offset = readU32(self.data, rec + 8),
                .len = readU32(self.data, rec + 12),
            };
            if (self.tables[i].offset + self.tables[i].len > self.data.len) return error.InvalidFont;
        }
    }

    fn applyAvarMapping(self: Face, axis_index: usize, value: f32) f32 {
        if (axis_index >= max_axes or self.avar_segment_count == 0) return value;
        const axis = self.avar_axes[axis_index];
        if (axis.count == 0) return value;
        if (axis.count == 1) return self.avar_to[axis.offset];
        const first = axis.offset;
        const last = axis.offset + axis.count - 1;
        if (value <= self.avar_from[first]) return self.avar_to[first];
        if (value >= self.avar_from[last]) return self.avar_to[last];
        var segment: usize = 0;
        while (segment + 1 < axis.count) : (segment += 1) {
            const current = axis.offset + segment;
            const next = current + 1;
            const from0 = self.avar_from[current];
            const from1 = self.avar_from[next];
            if (value < from0 or value > from1) continue;
            const to0 = self.avar_to[current];
            const to1 = self.avar_to[next];
            if (from0 == from1) return to1;
            return to0 + (value - from0) * (to1 - to0) / (from1 - from0);
        }
        return value;
    }

    fn parseRequiredTables(self: *Face) Error!void {
        const head = self.table(tag_head) orelse return error.MissingTable;
        const hhea = self.table(tag_hhea) orelse return error.MissingTable;
        const maxp = self.table(tag_maxp) orelse return error.MissingTable;
        const hmtx = self.table(tag_hmtx) orelse return error.MissingTable;
        const loca = self.table(tag_loca) orelse return error.MissingTable;
        const glyf = self.table(tag_glyf) orelse return error.MissingTable;
        const cmap = self.table(tag_cmap) orelse return error.MissingTable;
        if (head.len < 54 or hhea.len < 36 or maxp.len < 6) return error.InvalidFont;

        self.units_per_em = readU16(self.data, head.offset + 18);
        self.index_to_loc_format = readI16(self.data, head.offset + 50);
        self.y_min = readI16(self.data, head.offset + 38);
        self.y_max = readI16(self.data, head.offset + 42);
        self.ascender = readI16(self.data, hhea.offset + 4);
        self.descender = readI16(self.data, hhea.offset + 6);
        self.line_gap = readI16(self.data, hhea.offset + 8);
        self.num_h_metrics = readU16(self.data, hhea.offset + 34);
        self.num_glyphs = readU16(self.data, maxp.offset + 4);
        self.hmtx_offset = hmtx.offset;
        self.loca_offset = loca.offset;
        self.glyf_offset = glyf.offset;
        try self.parseCmap(cmap);
        self.parseGvar();
    }

    fn parseAxes(self: *Face) void {
        const fvar = self.table(tag_fvar) orelse return;
        if (fvar.len < 16) return;
        const axes_offset = @as(usize, readU16(self.data, fvar.offset + 4));
        const axis_count = @as(usize, readU16(self.data, fvar.offset + 8));
        const axis_size = @as(usize, readU16(self.data, fvar.offset + 10));
        if (axis_size < 20) return;
        self.axis_count = @min(axis_count, max_axes);
        var i: usize = 0;
        while (i < self.axis_count) : (i += 1) {
            const off = fvar.offset + axes_offset + i * axis_size;
            if (off + 20 > fvar.offset + fvar.len) {
                self.axis_count = i;
                return;
            }
            self.axes[i] = .{
                .tag = self.data[off..][0..4].*,
                .min = fixed16_16(readU32(self.data, off + 4)),
                .default = fixed16_16(readU32(self.data, off + 8)),
                .max = fixed16_16(readU32(self.data, off + 12)),
            };
        }
    }

    fn parseAvar(self: *Face) Error!void {
        const avar = self.table(tag_avar) orelse return;
        if (avar.len < avar_header_bytes) return error.InvalidFont;
        if (readU32(self.data, avar.offset) != sfnt_version_1) return error.InvalidFont;
        const axis_count = @as(usize, readU16(self.data, avar.offset + 6));
        if (axis_count > max_axes or (self.axis_count != 0 and axis_count != self.axis_count)) return error.InvalidFont;
        if (avar_header_bytes + axis_count * avar_axis_offset_bytes > avar.len) return error.InvalidFont;

        var total_segments: usize = 0;
        var axis: usize = 0;
        while (axis < axis_count) : (axis += 1) {
            const map_offset = readU16(self.data, avar.offset + avar_header_bytes + axis * avar_axis_offset_bytes);
            if (map_offset == 0) continue;
            if (@as(usize, map_offset) + avar_segment_count_bytes > avar.len) return error.InvalidFont;
            const segment_count = @as(usize, readU16(self.data, avar.offset + map_offset));
            if (@as(usize, map_offset) + avar_segment_count_bytes + segment_count * avar_segment_pair_bytes > avar.len) return error.InvalidFont;
            if (total_segments + segment_count > max_avar_segments) return error.GlyphPointBudgetExceeded;
            self.avar_axes[axis] = .{ .offset = total_segments, .count = segment_count };
            const from_base = avar.offset + map_offset + avar_segment_count_bytes;
            const to_base = from_base + segment_count * avar_segment_value_bytes;
            var segment: usize = 0;
            while (segment < segment_count) : (segment += 1) {
                self.avar_from[total_segments + segment] = f2dot14(readU16(self.data, from_base + segment * avar_segment_value_bytes));
                self.avar_to[total_segments + segment] = f2dot14(readU16(self.data, to_base + segment * avar_segment_value_bytes));
            }
            total_segments += segment_count;
        }
        self.avar_segment_count = total_segments;
    }

    fn parseKern(self: *Face) Error!void {
        const kern_table = self.table(tag_kern) orelse return;
        if (kern_table.len < 4) return error.InvalidFont;
        const subtable_count = readU16(self.data, kern_table.offset + 2);
        var subtable = kern_table.offset + 4;
        const table_end = kern_table.offset + kern_table.len;
        var i: usize = 0;
        while (i < subtable_count) : (i += 1) {
            if (subtable + kern_subtable_header_bytes > table_end) return error.InvalidFont;
            const subtable_version = readU16(self.data, subtable);
            const subtable_len = @as(usize, readU16(self.data, subtable + 2));
            const coverage = readU16(self.data, subtable + 4);
            if (subtable_len < kern_subtable_header_bytes or subtable + subtable_len > table_end) return error.InvalidFont;
            if (subtable_version == 0 and (coverage & kern_coverage_format_mask) == kern_format_0 and subtable_len >= kern_format_0_header_bytes) {
                const pair_count = @as(usize, readU16(self.data, subtable + 8));
                const pair_base = subtable + 14;
                if (pair_base + pair_count * kern_pair_bytes > subtable + subtable_len) return error.InvalidFont;
                if (self.kern_pair_count + pair_count > max_kern_pairs) return error.GlyphPointBudgetExceeded;
                var pair_index: usize = 0;
                while (pair_index < pair_count) : (pair_index += 1) {
                    const pair_offset = pair_base + pair_index * kern_pair_bytes;
                    self.kern_pairs[self.kern_pair_count + pair_index] = .{
                        .left = readU16(self.data, pair_offset),
                        .right = readU16(self.data, pair_offset + 2),
                        .adjust = readI16(self.data, pair_offset + 4),
                    };
                }
                self.kern_pair_count += pair_count;
            }
            subtable += subtable_len;
        }
    }

    fn parseGvar(self: *Face) void {
        const gvar = self.table(tag_gvar) orelse return;
        if (gvar.len < 20) return;
        if (readU16(self.data, gvar.offset) != 1 or readU16(self.data, gvar.offset + 2) != 0) return;
        const axis_count = readU16(self.data, gvar.offset + 4);
        const shared_tuple_count = readU16(self.data, gvar.offset + 6);
        const shared_tuple_offset = readU32(self.data, gvar.offset + 8);
        const glyph_count = readU16(self.data, gvar.offset + 12);
        const flags = readU16(self.data, gvar.offset + 14);
        const glyph_data_offset = readU32(self.data, gvar.offset + 16);
        if (axis_count > max_axes or glyph_count != self.num_glyphs) return;
        if (shared_tuple_offset > gvar.len or glyph_data_offset > gvar.len) return;
        self.gvar_offset = gvar.offset;
        self.gvar_len = gvar.len;
        self.gvar_axis_count = axis_count;
        self.gvar_shared_tuple_count = shared_tuple_count;
        self.gvar_shared_tuple_offset = gvar.offset + shared_tuple_offset;
        self.gvar_glyph_count = glyph_count;
        self.gvar_glyph_data_offset = gvar.offset + glyph_data_offset;
        self.gvar_offsets_32 = (flags & gvar_offset_format_32) != 0;
    }

    fn parseCmap(self: *Face, cmap: Table) Error!void {
        if (cmap.len < 4 or readU16(self.data, cmap.offset) != 0) return error.InvalidFont;
        const records = readU16(self.data, cmap.offset + 2);
        if (cmap.len < 4 + @as(usize, records) * 8) return error.InvalidFont;
        var selected: usize = 0;
        var selected_format: u16 = 0;
        var i: usize = 0;
        while (i < records) : (i += 1) {
            const rec = cmap.offset + 4 + i * 8;
            const platform = readU16(self.data, rec);
            const encoding = readU16(self.data, rec + 2);
            const sub_offset = @as(usize, readU32(self.data, rec + 4));
            if (sub_offset >= cmap.len) continue;
            const sub = cmap.offset + sub_offset;
            if (sub + 2 > cmap.offset + cmap.len) continue;
            const format = readU16(self.data, sub);
            const preferred = (platform == 3 and (encoding == 10 or encoding == 1)) or platform == 0;
            if (preferred and (format == 12 or (format == 4 and selected_format != 12))) {
                selected = sub;
                selected_format = format;
            }
        }
        if (selected == 0) return error.UnsupportedCmap;
        self.cmap_offset = selected;
        self.cmap_format = selected_format;
        self.cmap_len = if (selected_format == 12) readU32(self.data, selected + 4) else readU16(self.data, selected + 2);
        if (self.cmap_len == 0 or selected + self.cmap_len > cmap.offset + cmap.len) return error.InvalidFont;
    }

    fn table(self: Face, id: u32) ?Table {
        for (self.tables[0..self.table_count]) |entry| {
            if (entry.id == id) return entry;
        }
        return null;
    }

    fn glyphIdFormat4(self: Face, codepoint: u21) u16 {
        if (codepoint > 0xffff) return 0;
        const sub = self.cmap_offset;
        const seg_count = readU16(self.data, sub + 6) / 2;
        const end_codes = sub + 14;
        const start_codes = end_codes + @as(usize, seg_count) * 2 + 2;
        const id_deltas = start_codes + @as(usize, seg_count) * 2;
        const id_range_offsets = id_deltas + @as(usize, seg_count) * 2;
        var i: usize = 0;
        while (i < seg_count) : (i += 1) {
            const end_code = readU16(self.data, end_codes + i * 2);
            const start_code = readU16(self.data, start_codes + i * 2);
            if (codepoint < start_code or codepoint > end_code) continue;
            const delta = readI16(self.data, id_deltas + i * 2);
            const range_offset = readU16(self.data, id_range_offsets + i * 2);
            if (range_offset == 0) {
                const sum: i32 = @as(i32, @intCast(codepoint)) + delta;
                return @truncate(@as(u32, @bitCast(sum)));
            }
            const glyph_addr = id_range_offsets + i * 2 + range_offset + (@as(usize, codepoint - start_code) * 2);
            if (glyph_addr + 2 > sub + self.cmap_len) return 0;
            const raw = readU16(self.data, glyph_addr);
            if (raw == 0) return 0;
            const sum: i32 = @as(i32, raw) + delta;
            return @truncate(@as(u32, @bitCast(sum)));
        }
        return 0;
    }

    fn glyphIdFormat12(self: Face, codepoint: u21) u16 {
        const groups = readU32(self.data, self.cmap_offset + 12);
        var i: usize = 0;
        while (i < groups) : (i += 1) {
            const group = self.cmap_offset + 16 + i * 12;
            const start = readU32(self.data, group);
            const end = readU32(self.data, group + 4);
            if (codepoint < start or codepoint > end) continue;
            return @truncate(readU32(self.data, group + 8) + codepoint - start);
        }
        return 0;
    }

    fn glyphSlice(self: Face, glyph_id: u16) ?[]const u8 {
        if (glyph_id >= self.num_glyphs) return null;
        const start = self.glyphOffset(glyph_id);
        const end = self.glyphOffset(glyph_id + 1);
        if (end <= start) return self.data[self.glyf_offset + start .. self.glyf_offset + start];
        if (self.glyf_offset + end > self.data.len) return null;
        return self.data[self.glyf_offset + start .. self.glyf_offset + end];
    }

    fn glyphOffset(self: Face, glyph_id: u16) usize {
        if (self.index_to_loc_format == 0) return @as(usize, readU16(self.data, self.loca_offset + @as(usize, glyph_id) * 2)) * 2;
        return readU32(self.data, self.loca_offset + @as(usize, glyph_id) * 4);
    }

    fn bakeGlyph(self: Face, glyph_id: u16, px_size: f32, axis_values: [max_axes]f32, variation_key: u32, format: AtlasFormat, bitmap: []u8, bitmap_len: *usize) Error!CachedGlyph {
        const glyph = self.glyphSlice(glyph_id) orelse return error.InvalidFont;
        const advance_value = self.advance(glyph_id, px_size);
        const start = bitmap_len.*;
        if (glyph.len == 0) {
            return emptyGlyph(glyph_id, px_size, advance_value, start, variation_key, format);
        }
        if (glyph.len < 10) return error.InvalidFont;
        var points: [max_points]Point = undefined;
        var contour_ends: [max_contours]u16 = undefined;
        const outline_counts = try self.loadGlyphOutline(glyph_id, &points, &contour_ends, 0);
        if (outline_counts.contours == 0 or outline_counts.points == 0) {
            return emptyGlyph(glyph_id, px_size, advance_value, start, variation_key, format);
        }
        try self.applyGvar(glyph_id, points[0..outline_counts.points], contour_ends[0..outline_counts.contours], axis_values);
        var edges: [max_edges]Edge = undefined;
        var curves: [max_curves]Curve = undefined;
        var edge_colors: [max_edges]u8 = undefined;
        var curve_colors: [max_curves]u8 = undefined;
        const scale = px_size / @as(f32, @floatFromInt(self.units_per_em));
        const raster = switch (format) {
            .alpha8 => RasterOutline{
                .edge_count = try flattenContours(points[0..outline_counts.points], contour_ends[0..outline_counts.contours], &edges, 0.0, 0.0, scale),
                .curve_count = 0,
            },
            .sdf8 => try buildMsdfOutline(points[0..outline_counts.points], contour_ends[0..outline_counts.contours], scale, &edges, &edge_colors, &curves, &curve_colors),
            .msdf_rgb => try buildMsdfOutline(points[0..outline_counts.points], contour_ends[0..outline_counts.contours], scale, &edges, &edge_colors, &curves, &curve_colors),
        };
        if (raster.edge_count == 0 and raster.curve_count == 0) return emptyGlyph(glyph_id, px_size, advance_value, start, variation_key, format);

        const design_bounds = pointBounds(points[0..outline_counts.points]);
        const left = @as(i16, @intFromFloat(@floor(design_bounds.x_min * scale))) - glyph_padding;
        const right = @as(i16, @intFromFloat(@ceil(design_bounds.x_max * scale))) + glyph_padding;
        const top = @as(i16, @intFromFloat(@floor(-design_bounds.y_max * scale))) - glyph_padding;
        const bottom = @as(i16, @intFromFloat(@ceil(-design_bounds.y_min * scale))) + glyph_padding;
        if (right <= left or bottom <= top) {
            return .{ .glyph_id = glyph_id, .px_key = pxKey(px_size), .format = format, .width = 0, .height = 0, .left = left, .top = top, .advance = advance_value, .bitmap_offset = start, .variation_key = variation_key };
        }
        const width: u16 = @intCast(right - left);
        const height: u16 = @intCast(bottom - top);
        const byte_count = @as(usize, width) * @as(usize, height) * format.channels();
        if (start + byte_count > bitmap.len) return error.GlyphBitmapBudgetExceeded;
        bitmap_len.* += byte_count;

        switch (format) {
            .alpha8 => bakeAlphaBitmap(bitmap[start .. start + byte_count], width, height, left, top, edges[0..raster.edge_count], rasterSamples(px_size)),
            .sdf8 => bakeSdfBitmap(
                bitmap[start .. start + byte_count],
                width,
                height,
                left,
                top,
                edges[0..raster.edge_count],
                edge_colors[0..raster.edge_count],
                curves[0..raster.curve_count],
            ),
            .msdf_rgb => bakeMsdfBitmap(
                bitmap[start .. start + byte_count],
                width,
                height,
                left,
                top,
                edges[0..raster.edge_count],
                edge_colors[0..raster.edge_count],
                curves[0..raster.curve_count],
                curve_colors[0..raster.curve_count],
            ),
        }
        return .{ .glyph_id = glyph_id, .px_key = pxKey(px_size), .format = format, .width = width, .height = height, .left = left, .top = top, .advance = advance_value, .bitmap_offset = start, .variation_key = variation_key };
    }

    fn applyGvar(self: Face, glyph_id: u16, points: []Point, contour_ends: []const u16, axis_values: [max_axes]f32) Error!void {
        if (self.gvar_axis_count == 0 or self.gvar_glyph_count == 0 or glyph_id >= self.gvar_glyph_count) return;
        const range = self.gvarRange(glyph_id) orelse return;
        if (range.end <= range.start or range.start + 4 > self.gvar_offset + self.gvar_len) return;
        const tuple_count_raw = readU16(self.data, range.start);
        const tuple_count = tuple_count_raw & tuple_count_mask;
        const data_offset = @as(usize, readU16(self.data, range.start + 2));
        const serialized_start = range.start + data_offset;
        if (serialized_start > range.end) return error.InvalidFont;
        var tuple_data = serialized_start;
        var shared_set: ?PointSet = null;
        if ((tuple_count_raw & tuple_shared_points) != 0) {
            shared_set = try decodePointSet(self.data, tuple_data, range.end, points.len + 4);
            tuple_data += shared_set.?.consumed;
        }
        var header = range.start + 4;
        var tuple_index_i: usize = 0;
        while (tuple_index_i < tuple_count) : (tuple_index_i += 1) {
            if (header + 4 > range.end) return error.InvalidFont;
            const tuple_data_size = @as(usize, readU16(self.data, header));
            const tuple_index = readU16(self.data, header + 2);
            header += 4;
            var peak: [max_axes]f32 = [_]f32{0.0} ** max_axes;
            var start_curve: [max_axes]f32 = [_]f32{0.0} ** max_axes;
            var end_curve: [max_axes]f32 = [_]f32{0.0} ** max_axes;
            if ((tuple_index & tuple_embedded_peak) != 0) {
                for (0..self.gvar_axis_count) |axis| {
                    if (header + 2 > range.end) return error.InvalidFont;
                    peak[axis] = f2dot14(readU16(self.data, header));
                    header += 2;
                }
            } else {
                const shared_index = tuple_index & tuple_count_mask;
                if (shared_index >= self.gvar_shared_tuple_count) return error.InvalidFont;
                for (0..self.gvar_axis_count) |axis| {
                    peak[axis] = f2dot14(readU16(self.data, self.gvar_shared_tuple_offset + (@as(usize, shared_index) * self.gvar_axis_count + axis) * 2));
                }
            }
            if ((tuple_index & tuple_intermediate) != 0) {
                for (0..self.gvar_axis_count) |axis| {
                    if (header + 4 > range.end) return error.InvalidFont;
                    start_curve[axis] = f2dot14(readU16(self.data, header));
                    end_curve[axis] = f2dot14(readU16(self.data, header + 2));
                    header += 4;
                }
            } else {
                for (0..self.gvar_axis_count) |axis| {
                    if (peak[axis] > 0) {
                        start_curve[axis] = 0;
                        end_curve[axis] = peak[axis];
                    } else if (peak[axis] < 0) {
                        start_curve[axis] = peak[axis];
                        end_curve[axis] = 0;
                    }
                }
            }
            if (tuple_data + tuple_data_size > range.end) return error.InvalidFont;
            const scalar = tupleScalar(axis_values, self.gvar_axis_count, start_curve, peak, end_curve);
            if (scalar != 0) try self.applyGvarTuple(points, contour_ends, tuple_data, tuple_data + tuple_data_size, (tuple_index & tuple_private_points) != 0, shared_set, scalar);
            tuple_data += tuple_data_size;
        }
    }

    fn applyGvarTuple(self: Face, points: []Point, contour_ends: []const u16, tuple_start: usize, tuple_end: usize, private_points: bool, shared_set: ?PointSet, scalar: f32) Error!void {
        var cursor = tuple_start;
        const total_points = points.len + 4;
        var set = PointSet{ .all = true, .count = total_points, .consumed = 0 };
        if (private_points) {
            set = try decodePointSet(self.data, cursor, tuple_end, total_points);
            cursor += set.consumed;
        } else if (shared_set) |shared| {
            set = shared;
        }
        const apply_count = if (set.all) total_points else set.count;
        var raw_dx: [max_points + 4]i16 = undefined;
        var raw_dy: [max_points + 4]i16 = undefined;
        const used_x = try decodeDeltas(self.data, cursor, tuple_end, raw_dx[0..apply_count]);
        cursor += used_x;
        _ = try decodeDeltas(self.data, cursor, tuple_end, raw_dy[0..apply_count]);
        var dx: [max_points + 4]f32 = [_]f32{0.0} ** (max_points + 4);
        var dy: [max_points + 4]f32 = [_]f32{0.0} ** (max_points + 4);
        var touched: [max_points + 4]bool = [_]bool{false} ** (max_points + 4);
        for (0..apply_count) |i| {
            const point_index = if (set.all) i else set.points[i];
            if (point_index >= total_points) continue;
            dx[point_index] = @floatFromInt(raw_dx[i]);
            dy[point_index] = @floatFromInt(raw_dy[i]);
            touched[point_index] = true;
        }
        if (!set.all) interpolateUntouched(points, contour_ends, &dx, &dy, &touched);
        for (points, 0..) |*point, i| {
            point.x += dx[i] * scalar;
            point.y += dy[i] * scalar;
        }
    }

    fn gvarRange(self: Face, glyph_id: u16) ?struct { start: usize, end: usize } {
        const offset_table = self.gvar_offset + 20;
        const start_rel: usize = if (self.gvar_offsets_32) readU32(self.data, offset_table + @as(usize, glyph_id) * 4) else @as(usize, readU16(self.data, offset_table + @as(usize, glyph_id) * 2)) * 2;
        const end_rel: usize = if (self.gvar_offsets_32) readU32(self.data, offset_table + (@as(usize, glyph_id) + 1) * 4) else @as(usize, readU16(self.data, offset_table + (@as(usize, glyph_id) + 1) * 2)) * 2;
        if (end_rel < start_rel) return null;
        const start = self.gvar_glyph_data_offset + start_rel;
        const end = self.gvar_glyph_data_offset + end_rel;
        if (end > self.gvar_offset + self.gvar_len) return null;
        return .{ .start = start, .end = end };
    }

    fn loadGlyphOutline(self: Face, glyph_id: u16, points: *[max_points]Point, contour_ends: *[max_contours]u16, depth: usize) Error!OutlineCounts {
        if (depth > max_composite_depth) return error.UnsupportedGlyph;
        const glyph = self.glyphSlice(glyph_id) orelse return error.InvalidFont;
        if (glyph.len == 0) return .{ .points = 0, .contours = 0 };
        if (glyph.len < 10) return error.InvalidFont;
        const contours = readI16(glyph, 0);
        if (contours >= 0) {
            const point_count = try parseSimpleGlyph(glyph, @intCast(contours), points, contour_ends);
            return .{ .points = point_count, .contours = @intCast(contours) };
        }
        return self.loadCompoappGlyph(glyph, points, contour_ends, depth);
    }

    fn loadCompoappGlyph(self: Face, glyph: []const u8, points: *[max_points]Point, contour_ends: *[max_contours]u16, depth: usize) Error!OutlineCounts {
        var cursor: usize = 10;
        var out_points: usize = 0;
        var out_contours: usize = 0;
        while (true) {
            if (cursor + 4 > glyph.len) return error.InvalidFont;
            const flags = readU16(glyph, cursor);
            const component_glyph = readU16(glyph, cursor + 2);
            cursor += 4;

            if ((flags & comp_args_xy) == 0) return error.UnsupportedGlyph;
            var dx: f32 = 0.0;
            var dy: f32 = 0.0;
            if ((flags & comp_arg_words) != 0) {
                if (cursor + 4 > glyph.len) return error.InvalidFont;
                dx = @floatFromInt(readI16(glyph, cursor));
                dy = @floatFromInt(readI16(glyph, cursor + 2));
                cursor += 4;
            } else {
                if (cursor + 2 > glyph.len) return error.InvalidFont;
                dx = @floatFromInt(@as(i8, @bitCast(glyph[cursor])));
                dy = @floatFromInt(@as(i8, @bitCast(glyph[cursor + 1])));
                cursor += 2;
            }

            var xx: f32 = 1.0;
            var xy: f32 = 0.0;
            var yx: f32 = 0.0;
            var yy: f32 = 1.0;
            if ((flags & comp_have_scale) != 0) {
                if (cursor + 2 > glyph.len) return error.InvalidFont;
                const s = f2dot14(readU16(glyph, cursor));
                cursor += 2;
                xx = s;
                yy = s;
            } else if ((flags & comp_have_xy_scale) != 0) {
                if (cursor + 4 > glyph.len) return error.InvalidFont;
                xx = f2dot14(readU16(glyph, cursor));
                yy = f2dot14(readU16(glyph, cursor + 2));
                cursor += 4;
            } else if ((flags & comp_have_2x2) != 0) {
                if (cursor + 8 > glyph.len) return error.InvalidFont;
                xx = f2dot14(readU16(glyph, cursor));
                yx = f2dot14(readU16(glyph, cursor + 2));
                xy = f2dot14(readU16(glyph, cursor + 4));
                yy = f2dot14(readU16(glyph, cursor + 6));
                cursor += 8;
            }

            var component_points: [max_points]Point = undefined;
            var component_contours: [max_contours]u16 = undefined;
            const component = try self.loadGlyphOutline(component_glyph, &component_points, &component_contours, depth + 1);
            if (out_points + component.points > max_points or out_contours + component.contours > contour_ends.len) return error.GlyphPointBudgetExceeded;

            var i: usize = 0;
            while (i < component.points) : (i += 1) {
                const p = component_points[i];
                points[out_points + i] = .{
                    .x = p.x * xx + p.y * xy + dx,
                    .y = p.x * yx + p.y * yy + dy,
                    .on_curve = p.on_curve,
                };
            }
            i = 0;
            while (i < component.contours) : (i += 1) {
                contour_ends[out_contours + i] = @intCast(@as(usize, component_contours[i]) + out_points);
            }
            out_points += component.points;
            out_contours += component.contours;

            if ((flags & comp_more) == 0) break;
        }
        return .{ .points = out_points, .contours = out_contours };
    }
};

fn parseSimpleGlyph(glyph: []const u8, contour_count: usize, points: *[max_points]Point, contour_ends: *[max_contours]u16) Error!usize {
    if (contour_count > contour_ends.len) return error.GlyphPointBudgetExceeded;
    var cursor: usize = 10;
    var i: usize = 0;
    while (i < contour_count) : (i += 1) {
        if (cursor + 2 > glyph.len) return error.InvalidFont;
        contour_ends[i] = readU16(glyph, cursor);
        cursor += 2;
    }
    if (contour_count == 0) return 0;
    const point_count = @as(usize, contour_ends[contour_count - 1]) + 1;
    if (point_count > max_points) return error.GlyphPointBudgetExceeded;
    if (cursor + 2 > glyph.len) return error.InvalidFont;
    const instruction_len = readU16(glyph, cursor);
    cursor += 2 + instruction_len;
    if (cursor > glyph.len) return error.InvalidFont;

    var flags: [max_points]u8 = undefined;
    i = 0;
    while (i < point_count) {
        if (cursor >= glyph.len) return error.InvalidFont;
        const f = glyph[cursor];
        cursor += 1;
        var repeat: usize = 1;
        if ((f & flag_repeat) != 0) {
            if (cursor >= glyph.len) return error.InvalidFont;
            repeat = @as(usize, glyph[cursor]) + 1;
            cursor += 1;
        }
        var r: usize = 0;
        while (r < repeat and i < point_count) : ({
            r += 1;
            i += 1;
        }) flags[i] = f;
    }

    var x: i16 = 0;
    i = 0;
    while (i < point_count) : (i += 1) {
        const f = flags[i];
        if ((f & flag_x_short) != 0) {
            if (cursor >= glyph.len) return error.InvalidFont;
            const raw: i16 = glyph[cursor];
            cursor += 1;
            x += if ((f & flag_x_same_or_positive) != 0) raw else -raw;
        } else if ((f & flag_x_same_or_positive) == 0) {
            if (cursor + 2 > glyph.len) return error.InvalidFont;
            x += readI16(glyph, cursor);
            cursor += 2;
        }
        points[i].x = @floatFromInt(x);
        points[i].on_curve = (f & flag_on_curve) != 0;
    }
    var y: i16 = 0;
    i = 0;
    while (i < point_count) : (i += 1) {
        const f = flags[i];
        if ((f & flag_y_short) != 0) {
            if (cursor >= glyph.len) return error.InvalidFont;
            const raw: i16 = glyph[cursor];
            cursor += 1;
            y += if ((f & flag_y_same_or_positive) != 0) raw else -raw;
        } else if ((f & flag_y_same_or_positive) == 0) {
            if (cursor + 2 > glyph.len) return error.InvalidFont;
            y += readI16(glyph, cursor);
            cursor += 2;
        }
        points[i].y = @floatFromInt(y);
    }
    return point_count;
}

fn flattenContours(points: []const Point, contour_ends: []const u16, edges: *[max_edges]Edge, x: f32, baseline: f32, scale: f32) Error!usize {
    var edge_count: usize = 0;
    var start: usize = 0;
    for (contour_ends) |end_u16| {
        const end = @as(usize, end_u16);
        if (end >= points.len or end < start) return error.InvalidFont;
        edge_count = try flattenContour(points[start .. end + 1], edges, edge_count, x, baseline, scale);
        start = end + 1;
    }
    return edge_count;
}

fn flattenContour(raw: []const Point, edges: *[max_edges]Edge, edge_count_start: usize, x: f32, baseline: f32, scale: f32) Error!usize {
    if (raw.len == 0) return edge_count_start;
    var edge_count = edge_count_start;
    var current = if (raw[0].on_curve) raw[0] else if (raw[raw.len - 1].on_curve) raw[raw.len - 1] else midpoint(raw[raw.len - 1], raw[0]);
    var i: usize = if (raw[0].on_curve) 1 else 0;
    while (i < raw.len) {
        const p = raw[i];
        if (p.on_curve) {
            edge_count = try appendEdge(edges, edge_count, transform(current, x, baseline, scale), transform(p, x, baseline, scale));
            current = p;
            i += 1;
        } else {
            const next = raw[(i + 1) % raw.len];
            const end = if (next.on_curve) next else midpoint(p, next);
            edge_count = try appendQuadratic(edges, edge_count, transform(current, x, baseline, scale), transform(p, x, baseline, scale), transform(end, x, baseline, scale));
            current = end;
            i += if (next.on_curve) 2 else 1;
        }
    }
    if (raw[0].on_curve) {
        edge_count = try appendEdge(edges, edge_count, transform(current, x, baseline, scale), transform(raw[0], x, baseline, scale));
    }
    return edge_count;
}

fn buildMsdfOutline(points: []const Point, contour_ends: []const u16, scale: f32, edges: *[max_edges]Edge, edge_colors: *[max_edges]u8, curves: *[max_curves]Curve, curve_colors: *[max_curves]u8) Error!RasterOutline {
    var edge_count: usize = 0;
    var curve_count: usize = 0;
    var start: usize = 0;
    for (contour_ends) |end_u16| {
        const end = @as(usize, end_u16);
        if (end >= points.len or end < start) return error.InvalidFont;
        var contour: [max_contour_points]Point = undefined;
        const contour_count = try collectContourPoints(points[start .. end + 1], scale, &contour);
        const counts = try emitMsdfContour(contour[0..contour_count], edges, edge_colors, edge_count, curves, curve_colors, curve_count);
        edge_count = counts.edge_count;
        curve_count = counts.curve_count;
        start = end + 1;
    }
    return .{ .edge_count = edge_count, .curve_count = curve_count };
}

fn collectContourPoints(raw: []const Point, scale: f32, out: *[max_contour_points]Point) Error!usize {
    if (raw.len == 0) return error.InvalidFont;
    var count: usize = 0;
    if (!raw[0].on_curve) {
        try appendPoint(out, &count, transform(midpoint(raw[raw.len - 1], raw[0]), 0.0, 0.0, scale));
    }
    for (raw, 0..) |point, i| {
        try appendPoint(out, &count, transform(point, 0.0, 0.0, scale));
        const next = raw[(i + 1) % raw.len];
        if (!point.on_curve and !next.on_curve) {
            try appendPoint(out, &count, transform(midpoint(point, next), 0.0, 0.0, scale));
        }
    }
    try appendPoint(out, &count, out[0]);
    return count;
}

fn appendPoint(out: *[max_contour_points]Point, count: *usize, point: Point) Error!void {
    if (count.* >= out.len) return error.GlyphPointBudgetExceeded;
    out[count.*] = point;
    count.* += 1;
}

fn emitMsdfContour(contour: []const Point, edges: *[max_edges]Edge, edge_colors: *[max_edges]u8, edge_count_start: usize, curves: *[max_curves]Curve, curve_colors: *[max_curves]u8, curve_count_start: usize) Error!RasterOutline {
    if (contour.len < 2) return .{ .edge_count = edge_count_start, .curve_count = curve_count_start };
    var msdf_edges: [max_contour_points]MsdfEdge = undefined;
    var msdf_colors: [max_contour_points]u8 = undefined;
    var msdf_count: usize = 0;
    var i: usize = 0;
    while (i + 1 < contour.len) {
        const p0 = contour[i];
        const p1 = contour[i + 1];
        if (!p0.on_curve) return error.InvalidFont;
        if (p1.on_curve) {
            if (msdf_count >= msdf_edges.len) return error.GlyphEdgeBudgetExceeded;
            msdf_edges[msdf_count] = .{ .kind = .line, .p0 = p0, .p1 = p1, .p2 = p1 };
            msdf_count += 1;
            i += 1;
        } else {
            if (i + 2 >= contour.len or !contour[i + 2].on_curve) return error.InvalidFont;
            if (msdf_count >= msdf_edges.len) return error.GlyphEdgeBudgetExceeded;
            msdf_edges[msdf_count] = .{ .kind = .quadratic, .p0 = p0, .p1 = p1, .p2 = contour[i + 2] };
            msdf_count += 1;
            i += 2;
        }
    }
    colorMsdfEdges(msdf_edges[0..msdf_count], msdf_colors[0..msdf_count]);

    var edge_count = edge_count_start;
    var curve_count = curve_count_start;
    for (msdf_edges[0..msdf_count], msdf_colors[0..msdf_count]) |edge, color| {
        switch (edge.kind) {
            .line => {
                edge_count = try appendColoredEdge(edges, edge_colors, edge_count, edge.p0, edge.p1, color);
            },
            .quadratic => {
                if (curve_count >= max_curves) return error.GlyphEdgeBudgetExceeded;
                curves[curve_count] = .{ .p0 = edge.p0, .p1 = edge.p1, .p2 = edge.p2 };
                curve_colors[curve_count] = color;
                curve_count += 1;
                edge_count = try appendQuadraticColoredEdges(edges, edge_colors, edge_count, edge.p0, edge.p1, edge.p2, color, 0);
            },
        }
    }
    return .{ .edge_count = edge_count, .curve_count = curve_count };
}

fn appendColoredEdge(edges: *[max_edges]Edge, edge_colors: *[max_edges]u8, edge_count: usize, a: Point, b: Point, color: u8) Error!usize {
    if (a.x == b.x and a.y == b.y) return edge_count;
    if (edge_count >= max_edges) return error.GlyphEdgeBudgetExceeded;
    edges[edge_count] = .{ .a = a, .b = b };
    edge_colors[edge_count] = color;
    return edge_count + 1;
}

fn appendQuadraticColoredEdges(edges: *[max_edges]Edge, edge_colors: *[max_edges]u8, edge_count_start: usize, p0: Point, p1: Point, p2: Point, color: u8, depth: usize) Error!usize {
    if (depth > tessellation_soft_limit and depth > tessellation_hard_limit) return edge_count_start;
    const mid = Point{ .x = (p0.x + 2.0 * p1.x + p2.x) * 0.25, .y = (p0.y + 2.0 * p1.y + p2.y) * 0.25, .on_curve = true };
    const dist_sq = square(p1.x - mid.x) + square(p1.y - mid.y);
    if (dist_sq <= quadratic_tolerance_sq) {
        return appendColoredEdge(edges, edge_colors, edge_count_start, p0, p2, color | flattened_curve_edge_flag);
    }
    const q0 = midpoint(p0, p1);
    const q1 = midpoint(p1, p2);
    const r = midpoint(q0, q1);
    const first = try appendQuadraticColoredEdges(edges, edge_colors, edge_count_start, p0, q0, r, color, depth + 1);
    return appendQuadraticColoredEdges(edges, edge_colors, first, r, q1, p2, color, depth + 1);
}

fn appendQuadratic(edges: *[max_edges]Edge, edge_count_start: usize, p0: Point, p1: Point, p2: Point) Error!usize {
    var edge_count = edge_count_start;
    var previous = p0;
    var step: usize = 1;
    while (step <= 10) : (step += 1) {
        const t = @as(f32, @floatFromInt(step)) / 10.0;
        const mt = 1.0 - t;
        const next = Point{ .x = mt * mt * p0.x + 2.0 * mt * t * p1.x + t * t * p2.x, .y = mt * mt * p0.y + 2.0 * mt * t * p1.y + t * t * p2.y, .on_curve = true };
        edge_count = try appendEdge(edges, edge_count, previous, next);
        previous = next;
    }
    return edge_count;
}

fn appendEdge(edges: *[max_edges]Edge, edge_count: usize, a: Point, b: Point) Error!usize {
    if (edge_count >= max_edges) return error.GlyphEdgeBudgetExceeded;
    if (a.x == b.x and a.y == b.y) return edge_count;
    edges[edge_count] = .{ .a = a, .b = b };
    return edge_count + 1;
}

fn insideNonZero(x: f32, y: f32, edges: []const Edge) bool {
    var winding: i32 = 0;
    for (edges) |edge| {
        const ay = edge.a.y;
        const by = edge.b.y;
        if (ay <= y) {
            if (by > y and isLeft(edge, x, y) > 0.0) winding += 1;
        } else if (by <= y and isLeft(edge, x, y) < 0.0) {
            winding -= 1;
        }
    }
    return winding != 0;
}

fn isLeft(edge: Edge, x: f32, y: f32) f32 {
    return (edge.b.x - edge.a.x) * (y - edge.a.y) - (x - edge.a.x) * (edge.b.y - edge.a.y);
}

fn bakeAlphaBitmap(bitmap: []u8, width: u16, height: u16, left: i16, top: i16, edges: []const Edge, samples: usize) void {
    const sample_count = samples * samples;
    var py: usize = 0;
    while (py < height) : (py += 1) {
        var px: usize = 0;
        while (px < width) : (px += 1) {
            var covered: u16 = 0;
            var sy: usize = 0;
            while (sy < samples) : (sy += 1) {
                var sx: usize = 0;
                while (sx < samples) : (sx += 1) {
                    const sample_x = @as(f32, @floatFromInt(left)) + @as(f32, @floatFromInt(px)) + sampleOffset(sx, samples);
                    const sample_y = @as(f32, @floatFromInt(top)) + @as(f32, @floatFromInt(py)) + sampleOffset(sy, samples);
                    if (insideNonZero(sample_x, sample_y, edges)) covered += 1;
                }
            }
            bitmap[py * width + px] = @intCast((covered * 255) / sample_count);
        }
    }
}

fn bakeMsdfBitmap(bitmap: []u8, width: u16, height: u16, left: i16, top: i16, edges: []const Edge, edge_colors: []const u8, curves: []const Curve, curve_colors: []const u8) void {
    const inv_samples = 1.0 / @as(f32, @floatFromInt(msdf_supersample * msdf_supersample));
    var py: usize = 0;
    while (py < height) : (py += 1) {
        var px: usize = 0;
        while (px < width) : (px += 1) {
            var total = [_]f32{ 0.0, 0.0, 0.0 };
            var sy: usize = 0;
            while (sy < msdf_supersample) : (sy += 1) {
                var sx: usize = 0;
                while (sx < msdf_supersample) : (sx += 1) {
                    const sample_x = @as(f32, @floatFromInt(left)) + @as(f32, @floatFromInt(px)) + sampleOffset(sx, msdf_supersample);
                    const sample_y = @as(f32, @floatFromInt(top)) + @as(f32, @floatFromInt(py)) + sampleOffset(sy, msdf_supersample);
                    const distances = msdfSignedDistances(sample_x, sample_y, edges, edge_colors, curves, curve_colors);
                    const true_distance = signedDistanceToOutline(sample_x, sample_y, edges, edge_colors, curves);
                    total[0] += distances[0];
                    total[1] += distances[1];
                    total[2] += true_distance;
                }
            }
            const offset = (py * width + px) * msdf_channels;
            bitmap[offset] = alphaFromSignedDistance(total[0] * inv_samples);
            bitmap[offset + 1] = alphaFromSignedDistance(total[1] * inv_samples);
            bitmap[offset + 2] = alphaFromSignedDistance(total[2] * inv_samples);
        }
    }
}

fn bakeSdfBitmap(bitmap: []u8, width: u16, height: u16, left: i16, top: i16, edges: []const Edge, edge_colors: []const u8, curves: []const Curve) void {
    const inv_samples = 1.0 / @as(f32, @floatFromInt(msdf_supersample * msdf_supersample));
    var boundary_edges: [max_edges]bool = undefined;
    var boundary_curves: [max_curves]bool = undefined;
    computeBoundaryFlags(edges, edge_colors, curves, &boundary_edges, &boundary_curves);
    var py: usize = 0;
    while (py < height) : (py += 1) {
        var px: usize = 0;
        while (px < width) : (px += 1) {
            var total: f32 = 0.0;
            var sy: usize = 0;
            while (sy < msdf_supersample) : (sy += 1) {
                var sx: usize = 0;
                while (sx < msdf_supersample) : (sx += 1) {
                    const sample_x = @as(f32, @floatFromInt(left)) + @as(f32, @floatFromInt(px)) + sampleOffset(sx, msdf_supersample);
                    const sample_y = @as(f32, @floatFromInt(top)) + @as(f32, @floatFromInt(py)) + sampleOffset(sy, msdf_supersample);
                    total += signedDistanceToBoundary(sample_x, sample_y, edges, edge_colors, curves, boundary_edges[0..edges.len], boundary_curves[0..curves.len]);
                }
            }
            bitmap[py * width + px] = alphaFromSignedDistance(total * inv_samples);
        }
    }
}

fn msdfSignedDistances(px: f32, py: f32, edges: []const Edge, edge_colors: []const u8, curves: []const Curve, curve_colors: []const u8) [msdf_channels]f32 {
    var nearest_channel_sq = [_]f32{ math.float_max, math.float_max, math.float_max };
    var present = [_]bool{ false, false, false };
    var nearest_sq = math.float_max;

    for (edges, 0..) |edge, i| {
        const d_sq = segmentDistanceSq(px, py, edge);
        nearest_sq = @min(nearest_sq, d_sq);
        const mask = edge_colors[i] & ~flattened_curve_edge_flag;
        for (0..msdf_channels) |color| {
            if ((mask & channelBit(color)) != 0 and d_sq < nearest_channel_sq[color]) {
                nearest_channel_sq[color] = d_sq;
                present[color] = true;
            }
        }
    }
    for (curves, 0..) |curve, i| {
        const d_sq = quadraticDistanceSq(px, py, curve);
        nearest_sq = @min(nearest_sq, d_sq);
        const mask = curve_colors[i];
        for (0..msdf_channels) |color| {
            if ((mask & channelBit(color)) != 0 and d_sq < nearest_channel_sq[color]) {
                nearest_channel_sq[color] = d_sq;
                present[color] = true;
            }
        }
    }

    var nearest = @sqrt(nearest_sq);
    if (!math.isFiniteF(nearest)) nearest = segment_tolerance;
    var distances = [_]f32{ nearest, nearest, nearest };
    var any_present = false;
    for (0..msdf_channels) |color| {
        if (present[color]) {
            distances[color] = @sqrt(nearest_channel_sq[color]);
            any_present = true;
        }
    }
    if (!any_present) return .{ -nearest, -nearest, -nearest };
    for (0..msdf_channels) |color| {
        if (!present[color]) distances[color] = resolveMissingChannelDistance(present, distances, color);
    }
    const sign: f32 = if (insideWithCurves(px, py, edges, edge_colors, curves)) 1.0 else -1.0;
    return .{ sign * distances[0], sign * distances[1], sign * distances[2] };
}

fn signedDistanceToOutline(px: f32, py: f32, edges: []const Edge, edge_colors: []const u8, curves: []const Curve) f32 {
    var nearest_sq = math.float_max;
    for (edges) |edge| nearest_sq = @min(nearest_sq, segmentDistanceSq(px, py, edge));
    for (curves) |curve| nearest_sq = @min(nearest_sq, quadraticDistanceSq(px, py, curve));
    var nearest = @sqrt(nearest_sq);
    if (!math.isFiniteF(nearest)) nearest = segment_tolerance;
    const sign: f32 = if (insideWithCurves(px, py, edges, edge_colors, curves)) 1.0 else -1.0;
    return sign * nearest;
}

fn signedDistanceToBoundary(px: f32, py: f32, edges: []const Edge, edge_colors: []const u8, curves: []const Curve, boundary_edges: []const bool, boundary_curves: []const bool) f32 {
    var nearest_sq = math.float_max;
    for (edges, 0..) |edge, index| {
        if (boundary_edges[index]) {
            nearest_sq = @min(nearest_sq, segmentDistanceSq(px, py, edge));
        }
    }
    for (curves, 0..) |curve, index| {
        if (boundary_curves[index]) {
            nearest_sq = @min(nearest_sq, quadraticDistanceSq(px, py, curve));
        }
    }
    if (nearest_sq == math.float_max) {
        for (edges, 0..) |edge, index| {
            if ((edge_colors[index] & flattened_curve_edge_flag) == 0) nearest_sq = @min(nearest_sq, segmentDistanceSq(px, py, edge));
        }
        for (curves) |curve| nearest_sq = @min(nearest_sq, quadraticDistanceSq(px, py, curve));
    }
    var nearest = @sqrt(nearest_sq);
    if (!math.isFiniteF(nearest)) nearest = segment_tolerance;
    const sign: f32 = if (insideWithCurves(px, py, edges, edge_colors, curves)) 1.0 else -1.0;
    return sign * nearest;
}

fn computeBoundaryFlags(edges: []const Edge, edge_colors: []const u8, curves: []const Curve, boundary_edges: *[max_edges]bool, boundary_curves: *[max_curves]bool) void {
    for (edges, 0..) |edge, index| {
        boundary_edges[index] = (edge_colors[index] & flattened_curve_edge_flag) == 0 and segmentSeparatesFill(edge, edges, edge_colors, curves);
    }
    for (curves, 0..) |curve, index| {
        boundary_curves[index] = curveSeparatesFill(curve, edges, edge_colors, curves);
    }
}

fn segmentSeparatesFill(edge: Edge, edges: []const Edge, edge_colors: []const u8, curves: []const Curve) bool {
    return normalSamplesDiffer(
        (edge.a.x + edge.b.x) * 0.5,
        (edge.a.y + edge.b.y) * 0.5,
        edge.b.x - edge.a.x,
        edge.b.y - edge.a.y,
        edges,
        edge_colors,
        curves,
    );
}

fn curveSeparatesFill(curve: Curve, edges: []const Edge, edge_colors: []const u8, curves: []const Curve) bool {
    const mid_x = quadraticPointX(curve, 0.5);
    const mid_y = quadraticPointY(curve, 0.5);
    return normalSamplesDiffer(
        mid_x,
        mid_y,
        curve.p2.x - curve.p0.x,
        curve.p2.y - curve.p0.y,
        edges,
        edge_colors,
        curves,
    );
}

fn normalSamplesDiffer(x: f32, y: f32, dx: f32, dy: f32, edges: []const Edge, edge_colors: []const u8, curves: []const Curve) bool {
    const length_sq = dx * dx + dy * dy;
    if (length_sq <= segment_tolerance) return true;
    const inv_len = 1.0 / @sqrt(length_sq);
    const nx = -dy * inv_len * boundary_probe_offset;
    const ny = dx * inv_len * boundary_probe_offset;
    const inside_a = insideWithCurves(x + nx, y + ny, edges, edge_colors, curves);
    const inside_b = insideWithCurves(x - nx, y - ny, edges, edge_colors, curves);
    return inside_a != inside_b;
}

fn resolveMissingChannelDistance(present: [msdf_channels]bool, distances: [msdf_channels]f32, color: usize) f32 {
    const next = (color + 1) % msdf_channels;
    const prev = (color + msdf_channels - 1) % msdf_channels;
    if (present[next] and present[prev]) {
        const separation = @abs(distances[next] - distances[prev]);
        if (separation <= msdf_missing_channel_epsilon) return 0.5 * (distances[next] + distances[prev]);
        return @min(distances[next], distances[prev]);
    }
    if (present[next]) return distances[next];
    return if (present[prev]) distances[prev] else distances[color];
}

fn insideWithCurves(px: f32, py: f32, edges: []const Edge, edge_colors: []const u8, curves: []const Curve) bool {
    var winding: i32 = 0;
    for (edges, 0..) |edge, index| {
        if ((edge_colors[index] & flattened_curve_edge_flag) == 0) {
            winding += segmentCrossingSign(px, py, edge);
        }
    }
    for (curves) |curve| winding += quadraticCrossingSign(px, py, curve);
    return winding != 0;
}

fn segmentCrossingSign(x: f32, y: f32, edge: Edge) i32 {
    const y1 = edge.a.y;
    const y2 = edge.b.y;
    if (!((y1 <= y and y2 > y) or (y2 <= y and y1 > y))) return 0;
    const dy = y2 - y1;
    if (@abs(dy) <= segment_tolerance) return 0;
    const x_int = (edge.b.x - edge.a.x) * (y - y1) / dy + edge.a.x;
    if (x >= x_int) return 0;
    return if (y2 > y1) 1 else -1;
}

fn quadraticCrossingSign(x: f32, y: f32, curve: Curve) i32 {
    const y0 = curve.p0.y;
    const y1 = curve.p1.y;
    const y2 = curve.p2.y;
    if (!((y0 <= y and y2 > y) or (y2 <= y and y0 > y))) return 0;
    const a = y0 - 2.0 * y1 + y2;
    const b = 2.0 * (y1 - y0);
    const c = y0 - y;
    const disc = b * b - 4.0 * a * c;
    if (disc < 0.0) return 0;

    const sqrt_disc = @sqrt(disc);
    var candidates: [2]f32 = undefined;
    var count: usize = 0;
    if (@abs(a) > segment_tolerance) {
        const inv_2a = 0.5 / a;
        const t0 = (-b - sqrt_disc) * inv_2a;
        const t1 = (-b + sqrt_disc) * inv_2a;
        if (t0 > curve_crossing_epsilon and t0 < 1.0 - curve_crossing_epsilon) {
            candidates[count] = t0;
            count += 1;
        }
        if (t1 > curve_crossing_epsilon and t1 < 1.0 - curve_crossing_epsilon and (count == 0 or @abs(t1 - candidates[0]) > curve_crossing_epsilon)) {
            candidates[count] = t1;
            count += 1;
        }
    } else if (@abs(b) > segment_tolerance) {
        const t = -c / b;
        if (t > curve_crossing_epsilon and t < 1.0 - curve_crossing_epsilon) {
            candidates[count] = t;
            count += 1;
        }
    }
    var winding: i32 = 0;
    for (candidates[0..count]) |t| {
        const x_int = quadraticPointX(curve, t);
        if (x >= x_int) continue;
        const omt = 1.0 - t;
        const dy_dt = 2.0 * (omt * (y1 - y0) + t * (y2 - y1));
        if (@abs(dy_dt) <= segment_tolerance) continue;
        winding += if (dy_dt > 0.0) 1 else -1;
    }
    return winding;
}

fn segmentDistanceSq(px: f32, py: f32, edge: Edge) f32 {
    const vx = edge.b.x - edge.a.x;
    const vy = edge.b.y - edge.a.y;
    const wx = px - edge.a.x;
    const wy = py - edge.a.y;
    const len_sq = vx * vx + vy * vy;
    const t = if (len_sq <= segment_tolerance) 0.0 else math.clampF((wx * vx + wy * vy) / len_sq, 0.0, 1.0);
    const proj_x = edge.a.x + t * vx;
    const proj_y = edge.a.y + t * vy;
    return square(px - proj_x) + square(py - proj_y);
}

fn quadraticDistanceSq(px: f32, py: f32, curve: Curve) f32 {
    const ax = curve.p0.x - 2.0 * curve.p1.x + curve.p2.x;
    const ay = curve.p0.y - 2.0 * curve.p1.y + curve.p2.y;
    const bx = 2.0 * (curve.p1.x - curve.p0.x);
    const by = 2.0 * (curve.p1.y - curve.p0.y);
    const cx = curve.p0.x - px;
    const cy = curve.p0.y - py;
    const accel = ax * ax + ay * ay;
    if (accel <= curve_linear_tolerance) return segmentDistanceSq(px, py, .{ .a = curve.p0, .b = curve.p2 });

    const c0 = cx * bx + cy * by;
    const c1 = 2.0 * (cx * ax + cy * ay) + bx * bx + by * by;
    const c2 = 2.0 * (bx * ax + by * ay);
    const c3 = 2.0 * accel;

    var best = quadraticPointDistanceSq(px, py, curve, 0.0);
    best = @min(best, quadraticPointDistanceSq(px, py, curve, 1.0));
    var sample: usize = 0;
    while (sample <= curve_distance_samples) : (sample += 1) {
        var t = @as(f32, @floatFromInt(sample)) / @as(f32, @floatFromInt(curve_distance_samples));
        var step: usize = 0;
        while (step < curve_newton_steps) : (step += 1) {
            const derivative = ((3.0 * c3 * t + 2.0 * c2) * t + c1) * t + c0;
            const slope = (3.0 * c3 * t + 2.0 * c2) * t + c1;
            if (@abs(slope) <= segment_tolerance) break;
            const next_t = math.clampF(t - derivative / slope, 0.0, 1.0);
            if (@abs(next_t - t) <= curve_newton_epsilon) {
                t = next_t;
                break;
            }
            t = next_t;
        }
        best = @min(best, quadraticPointDistanceSq(px, py, curve, t));
    }
    return best;
}

fn quadraticPointX(curve: Curve, t: f32) f32 {
    const omt = 1.0 - t;
    return omt * omt * curve.p0.x + 2.0 * omt * t * curve.p1.x + t * t * curve.p2.x;
}

fn quadraticPointY(curve: Curve, t: f32) f32 {
    const omt = 1.0 - t;
    return omt * omt * curve.p0.y + 2.0 * omt * t * curve.p1.y + t * t * curve.p2.y;
}

fn quadraticPointDistanceSq(px: f32, py: f32, curve: Curve, t: f32) f32 {
    return square(px - quadraticPointX(curve, t)) + square(py - quadraticPointY(curve, t));
}

fn alphaFromSignedDistance(distance: f32) u8 {
    const value = msdf_mid_alpha + (distance * msdf_edge_scale) / msdf_spread;
    return @intFromFloat(@round(math.clampF(value, 0.0, 255.0)));
}

fn msdfCoverageAlpha(encoded: u8) u8 {
    const signed_distance = (@as(f32, @floatFromInt(encoded)) - msdf_mid_alpha) * msdf_spread / msdf_edge_scale;
    const coverage = math.clampF(signed_distance + 0.5, 0.0, 1.0);
    return @intFromFloat(@round(coverage * 255.0));
}

fn sampleOffset(index: usize, samples: usize) f32 {
    return (@as(f32, @floatFromInt(index)) + 0.5) / @as(f32, @floatFromInt(samples));
}

fn rasterSamples(px_size: f32) usize {
    if (px_size <= raster_small_px_limit) return raster_samples_small;
    if (px_size <= raster_medium_px_limit) return raster_samples_medium;
    return raster_samples_large;
}

fn colorMsdfEdges(edges: []const MsdfEdge, out_colors: []u8) void {
    if (edges.len == 0) return;
    if (edges.len == 1) {
        out_colors[0] = msdfColorMask(preferredMsdfEdgeColor(edges[0], 0));
        return;
    }
    var preferred: [max_contour_points]u8 = undefined;
    for (edges, 0..) |edge, i| preferred[i] = preferredMsdfEdgeColor(edge, i);

    var best_cost: u32 = ~@as(u32, 0);
    var best_first: u8 = 0;
    var best_last: u8 = 0;
    var first: u8 = 0;
    while (first < msdf_channels) : (first += 1) {
        var dp_prev = [_]u32{~@as(u32, 0)} ** msdf_channels;
        var dp_next = [_]u32{~@as(u32, 0)} ** msdf_channels;
        dp_prev[first] = msdfColorCost(first, preferred[0]);
        var edge_index: usize = 1;
        while (edge_index < edges.len) : (edge_index += 1) {
            @memset(&dp_next, ~@as(u32, 0));
            var prev: u8 = 0;
            while (prev < msdf_channels) : (prev += 1) {
                if (dp_prev[prev] == ~@as(u32, 0)) continue;
                var color: u8 = 0;
                while (color < msdf_channels) : (color += 1) {
                    if (color == prev) continue;
                    const cost = dp_prev[prev] + msdfColorCost(color, preferred[edge_index]);
                    if (cost < dp_next[color]) dp_next[color] = cost;
                }
            }
            dp_prev = dp_next;
        }
        var last: u8 = 0;
        while (last < msdf_channels) : (last += 1) {
            if (last == first) continue;
            const candidate = dp_prev[last];
            if (candidate < best_cost or (candidate == best_cost and (first < best_first or (first == best_first and last < best_last)))) {
                best_cost = candidate;
                best_first = first;
                best_last = last;
            }
        }
    }

    var parent: [max_contour_points][msdf_channels]u8 = undefined;
    for (0..edges.len) |edge_index| {
        for (0..msdf_channels) |color| parent[edge_index][color] = 0;
    }
    var dp_prev = [_]u32{~@as(u32, 0)} ** msdf_channels;
    var dp_next = [_]u32{~@as(u32, 0)} ** msdf_channels;
    dp_prev[best_first] = msdfColorCost(best_first, preferred[0]);
    var edge_index: usize = 1;
    while (edge_index < edges.len) : (edge_index += 1) {
        @memset(&dp_next, ~@as(u32, 0));
        var prev: u8 = 0;
        while (prev < msdf_channels) : (prev += 1) {
            if (dp_prev[prev] == ~@as(u32, 0)) continue;
            var color: u8 = 0;
            while (color < msdf_channels) : (color += 1) {
                if (color == prev) continue;
                const cost = dp_prev[prev] + msdfColorCost(color, preferred[edge_index]);
                if (cost < dp_next[color]) {
                    dp_next[color] = cost;
                    parent[edge_index][color] = prev;
                }
            }
        }
        dp_prev = dp_next;
    }
    out_colors[edges.len - 1] = msdfColorMask(best_last);
    var backtrack = edges.len - 1;
    var current_color = best_last;
    while (backtrack > 0) : (backtrack -= 1) {
        current_color = parent[backtrack][current_color];
        out_colors[backtrack - 1] = msdfColorMask(current_color);
    }
}

fn channelBit(color: usize) u8 {
    return @as(u8, 1) << @intCast(color);
}

fn msdfColorMask(color: u8) u8 {
    return switch (color) {
        0 => channelBit(1) | channelBit(2),
        1 => channelBit(0) | channelBit(2),
        else => channelBit(0) | channelBit(1),
    };
}

fn preferredMsdfEdgeColor(edge: MsdfEdge, edge_index: usize) u8 {
    const end = switch (edge.kind) {
        .line => edge.p1,
        .quadratic => edge.p2,
    };
    return msdfEdgeColor(end.x - edge.p0.x, end.y - edge.p0.y, edge_index);
}

fn msdfEdgeColor(dx: f32, dy: f32, edge_index: usize) u8 {
    if (@abs(dx) <= segment_tolerance and @abs(dy) <= segment_tolerance) return @intCast(edge_index % msdf_channels);
    var angle = math.atan2F(dy, dx) + msdf_pi;
    if (angle < 0.0) angle = 0.0;
    if (angle >= msdf_two_pi) angle = msdf_two_pi;
    var biased = angle / msdf_two_pi + msdf_channel_half_bin;
    if (biased >= 1.0) biased -= 1.0;
    const color: u8 = @intFromFloat(@floor(biased * msdf_channel_scale));
    return if (color >= msdf_channels) msdf_channels - 1 else color;
}

fn msdfColorCost(color: u8, preferred: u8) u32 {
    return if (color == preferred) 0 else 1;
}

fn transform(p: Point, x: f32, baseline: f32, scale: f32) Point {
    return .{ .x = x + p.x * scale, .y = baseline - p.y * scale, .on_curve = true };
}

fn midpoint(a: Point, b: Point) Point {
    return .{ .x = (a.x + b.x) * 0.5, .y = (a.y + b.y) * 0.5, .on_curve = true };
}

fn normalizeAxis(axis: Axis, value: f32) f32 {
    const clamped = @min(@max(value, axis.min), axis.max);
    const normalized = if (clamped >= axis.default)
        if (axis.max != axis.default) (clamped - axis.default) / (axis.max - axis.default) else 0.0
    else if (axis.default != axis.min) -((axis.default - clamped) / (axis.default - axis.min)) else 0.0;
    return @min(@max(normalized, -1.0), 1.0);
}

fn tupleScalar(axis_values: [max_axes]f32, axis_count: usize, start_curve: [max_axes]f32, peak: [max_axes]f32, end_curve: [max_axes]f32) f32 {
    var scalar: f32 = 1.0;
    for (0..axis_count) |axis| {
        const start = start_curve[axis];
        const peak_value = peak[axis];
        const end = end_curve[axis];
        const value = axis_values[axis];
        if (!(start <= peak_value and peak_value <= end)) return 0.0;
        const axis_scalar: f32 = if (value < start or value > end)
            0.0
        else if (peak_value == start or peak_value == end)
            if (value == peak_value) 1.0 else 0.0
        else if (value < peak_value)
            (value - start) / (peak_value - start)
        else if (value > peak_value)
            (end - value) / (end - peak_value)
        else
            1.0;
        scalar *= axis_scalar;
        if (scalar == 0.0) return 0.0;
    }
    return scalar;
}

fn decodePointSet(data: []const u8, start: usize, end: usize, all_points_hint: usize) Error!PointSet {
    if (start >= end) return error.InvalidFont;
    var cursor = start;
    const first = data[cursor];
    cursor += 1;
    if (first == 0) return .{ .all = true, .count = all_points_hint, .consumed = cursor - start };
    var count: usize = first;
    if ((first & 0x80) != 0) {
        if (cursor >= end) return error.InvalidFont;
        count = (@as(usize, first & 0x7f) << 8) | data[cursor];
        cursor += 1;
    }
    if (count > max_points + 4) return error.GlyphPointBudgetExceeded;
    var out = PointSet{ .all = false, .count = count };
    var parsed: usize = 0;
    var last: u16 = 0;
    while (parsed < count) {
        if (cursor >= end) return error.InvalidFont;
        const control = data[cursor];
        cursor += 1;
        const run_count = @as(usize, control & 0x7f) + 1;
        const words = (control & 0x80) != 0;
        var i: usize = 0;
        while (i < run_count and parsed < count) : (i += 1) {
            const delta: u16 = if (words) blk: {
                if (cursor + 2 > end) return error.InvalidFont;
                const value = readU16(data, cursor);
                cursor += 2;
                break :blk value;
            } else blk: {
                if (cursor >= end) return error.InvalidFont;
                const value: u16 = data[cursor];
                cursor += 1;
                break :blk value;
            };
            last +%= delta;
            out.points[parsed] = last;
            parsed += 1;
        }
    }
    out.consumed = cursor - start;
    return out;
}

fn decodeDeltas(data: []const u8, start: usize, end: usize, out: []i16) Error!usize {
    var cursor = start;
    var produced: usize = 0;
    while (produced < out.len) {
        if (cursor >= end) return error.InvalidFont;
        const control = data[cursor];
        cursor += 1;
        const run_count = @as(usize, control & 0x3f) + 1;
        if ((control & 0x80) != 0) {
            var i: usize = 0;
            while (i < run_count and produced < out.len) : (i += 1) {
                out[produced] = 0;
                produced += 1;
            }
        } else if ((control & 0x40) != 0) {
            var i: usize = 0;
            while (i < run_count and produced < out.len) : (i += 1) {
                if (cursor + 2 > end) return error.InvalidFont;
                out[produced] = readI16(data, cursor);
                cursor += 2;
                produced += 1;
            }
        } else {
            var i: usize = 0;
            while (i < run_count and produced < out.len) : (i += 1) {
                if (cursor >= end) return error.InvalidFont;
                out[produced] = @as(i8, @bitCast(data[cursor]));
                cursor += 1;
                produced += 1;
            }
        }
    }
    return cursor - start;
}

fn interpolateUntouched(points: []const Point, contour_ends: []const u16, dx: *[max_points + 4]f32, dy: *[max_points + 4]f32, touched: *[max_points + 4]bool) void {
    var start: usize = 0;
    for (contour_ends) |end_u16| {
        const end = @as(usize, end_u16);
        interpolateContourAxis(points, dx, touched, start, end, true);
        interpolateContourAxis(points, dy, touched, start, end, false);
        start = end + 1;
    }
}

fn interpolateContourAxis(points: []const Point, deltas: *[max_points + 4]f32, touched: *[max_points + 4]bool, start: usize, end: usize, x_axis: bool) void {
    var first = end + 1;
    var count: usize = 0;
    var i = start;
    while (i <= end) : (i += 1) {
        if (touched[i]) {
            if (first > end) first = i;
            count += 1;
        }
    }
    if (count == 0) return;
    if (count == 1) {
        i = start;
        while (i <= end) : (i += 1) {
            if (!touched[i]) deltas[i] = deltas[first];
        }
        return;
    }
    var left = first;
    while (true) {
        var right = nextContourIndex(left, start, end);
        while (right != left and !touched[right]) right = nextContourIndex(right, start, end);
        var fill = nextContourIndex(left, start, end);
        while (fill != right) : (fill = nextContourIndex(fill, start, end)) {
            const coord = if (x_axis) points[fill].x else points[fill].y;
            const coord_l = if (x_axis) points[left].x else points[left].y;
            const coord_r = if (x_axis) points[right].x else points[right].y;
            deltas[fill] = interpolateDelta(coord, coord_l, coord_r, deltas[left], deltas[right]);
        }
        left = right;
        if (left == first) break;
    }
}

fn nextContourIndex(index: usize, start: usize, end: usize) usize {
    return if (index >= end) start else index + 1;
}

fn interpolateDelta(coord: f32, coord_a: f32, coord_b: f32, delta_a: f32, delta_b: f32) f32 {
    if (coord_a == coord_b) return delta_a;
    var min_coord = coord_a;
    var max_coord = coord_b;
    var min_delta = delta_a;
    var max_delta = delta_b;
    if (coord_a > coord_b) {
        min_coord = coord_b;
        max_coord = coord_a;
        min_delta = delta_b;
        max_delta = delta_a;
    }
    if (coord <= min_coord) return min_delta;
    if (coord >= max_coord) return max_delta;
    return min_delta + (max_delta - min_delta) * ((coord - min_coord) / (max_coord - min_coord));
}

fn appendGlyphQuad(vertices: []Vertex, cursor: *usize, x0: f32, y0: f32, glyph_value: CachedGlyph) void {
    const x1 = x0 + @as(f32, @floatFromInt(glyph_value.width));
    const y1 = y0 + @as(f32, @floatFromInt(glyph_value.height));
    const v0 = vertex(x0, y0, 0.0, 0.0);
    const v1 = vertex(x1, y0, 1.0, 0.0);
    const v2 = vertex(x1, y1, 1.0, 1.0);
    const v3 = vertex(x0, y1, 0.0, 1.0);
    vertices[cursor.*] = v0;
    vertices[cursor.* + 1] = v1;
    vertices[cursor.* + 2] = v2;
    vertices[cursor.* + 3] = v0;
    vertices[cursor.* + 4] = v2;
    vertices[cursor.* + 5] = v3;
    cursor.* += vertices_per_glyph;
}

fn vertex(x: f32, y: f32, u: f32, v: f32) Vertex {
    return .{
        .x = x,
        .y = y,
        .u = u,
        .v = v,
        .r = vertex_color_one,
        .g = vertex_color_one,
        .b = vertex_color_one,
        .a = vertex_color_one,
        .atlas_id = 0,
    };
}

fn pointBounds(points: []const Point) Bounds {
    var bounds = Bounds{ .x_min = points[0].x, .x_max = points[0].x, .y_min = points[0].y, .y_max = points[0].y };
    for (points[1..]) |point| {
        bounds.x_min = @min(bounds.x_min, point.x);
        bounds.x_max = @max(bounds.x_max, point.x);
        bounds.y_min = @min(bounds.y_min, point.y);
        bounds.y_max = @max(bounds.y_max, point.y);
    }
    return bounds;
}

fn emptyGlyph(glyph_id: u16, px_size: f32, advance_value: f32, bitmap_offset: usize, variation_key: u32, format: AtlasFormat) CachedGlyph {
    return .{ .glyph_id = glyph_id, .px_key = pxKey(px_size), .format = format, .width = 0, .height = 0, .left = 0, .top = 0, .advance = advance_value, .bitmap_offset = bitmap_offset, .variation_key = variation_key };
}

fn median3(a: u8, b: u8, c: u8) u8 {
    return @max(@min(a, b), @min(@max(a, b), c));
}

fn square(value: f32) f32 {
    return value * value;
}

pub fn readU16(data: []const u8, offset: usize) u16 {
    return (@as(u16, data[offset]) << 8) | data[offset + 1];
}

fn readI16(data: []const u8, offset: usize) i16 {
    return @bitCast(readU16(data, offset));
}

pub fn readU32(data: []const u8, offset: usize) u32 {
    return (@as(u32, data[offset]) << 24) | (@as(u32, data[offset + 1]) << 16) | (@as(u32, data[offset + 2]) << 8) | data[offset + 3];
}

fn tag(value: *const [4:0]u8) u32 {
    return (@as(u32, value[0]) << 24) | (@as(u32, value[1]) << 16) | (@as(u32, value[2]) << 8) | value[3];
}

fn fixed16_16(value: u32) f32 {
    return @as(f32, @floatFromInt(@as(i32, @bitCast(value)))) / 65536.0;
}

fn f2dot14(value: u16) f32 {
    return @as(f32, @floatFromInt(@as(i16, @bitCast(value)))) / 16384.0;
}

fn pxKey(px_size: f32) u16 {
    return @intFromFloat(@round(px_size * 16.0));
}

test "alpha rasterizer uses size dependent coverage samples" {
    try std.testing.expectEqual(@as(usize, raster_samples_small), rasterSamples(12.0));
    try std.testing.expectEqual(@as(usize, raster_samples_medium), rasterSamples(20.0));
    try std.testing.expectEqual(@as(usize, raster_samples_large), rasterSamples(32.0));
}

test "geist variable font parses metrics axes and glyph ids" {
    const face = try Face.geist();
    try std.testing.expect(face.units_per_em > 0);
    try std.testing.expect(face.axis_count > 0);
    try std.testing.expectEqualStrings("wght", &face.axes[0].tag);
    try std.testing.expect(face.glyphId('e') != 0);
    const metrics = face.metrics(default_px_size);
    try std.testing.expect(metrics.ascender > 0);
    try std.testing.expect(metrics.line_height > 0);
    try std.testing.expect(metrics.y_min < metrics.y_max);
}

test "geist variable font rasterizes real glyph outlines" {
    const face = try Face.geist();
    var pixels: [96 * 32]ui.Color = undefined;
    var surface = TestSurface{ .width = 96, .height = 32, .pixels = &pixels };
    var bitmap: [64 * 1024]u8 = undefined;
    var cache = Cache.init(face, &bitmap);
    @memset(surface.pixels, ui.Color.clear);
    try cache.drawText(&surface, ui.Rect.init(0, 0, 96, 32), "edgerun", ui.Color.text, 20);
    var painted: usize = 0;
    for (pixels) |pixel| {
        if (pixel.a != 0) painted += 1;
    }
    try std.testing.expect(painted > 80);
    const bitmap_len = cache.bitmap_len;
    try cache.drawText(&surface, ui.Rect.init(0, 0, 96, 32), "edgerun", ui.Color.text, 20);
    try std.testing.expectEqual(bitmap_len, cache.bitmap_len);
}

test "geist weight axis changes rasterized glyph output" {
    const face = try Face.geist();
    var light_pixels: [96 * 36]ui.Color = undefined;
    var bold_pixels: [96 * 36]ui.Color = undefined;
    var light_surface = TestSurface{ .width = 96, .height = 36, .pixels = &light_pixels };
    var bold_surface = TestSurface{ .width = 96, .height = 36, .pixels = &bold_pixels };
    @memset(light_surface.pixels, ui.Color.clear);
    @memset(bold_surface.pixels, ui.Color.clear);

    var light_bitmap: [64 * 1024]u8 = undefined;
    var bold_bitmap: [64 * 1024]u8 = undefined;
    var light = Cache.init(face, &light_bitmap);
    var bold = Cache.init(face, &bold_bitmap);
    try std.testing.expect(light.setAxis("wght", 100.0));
    try std.testing.expect(bold.setAxis("wght", 900.0));

    try light.drawText(&light_surface, ui.Rect.init(0, 0, 96, 36), "edgerun", ui.Color.text, 24);
    try bold.drawText(&bold_surface, ui.Rect.init(0, 0, 96, 36), "edgerun", ui.Color.text, 24);

    const light_sum = pixelAlphaSum(&light_pixels);
    const bold_sum = pixelAlphaSum(&bold_pixels);
    try std.testing.expect(bold_sum > light_sum);
    try std.testing.expect(!std.mem.eql(ui.Color, &light_pixels, &bold_pixels));
}

test "shape and vertex batch mirror C varfont geometry contract" {
    const face = try Face.geist();
    var shaped_storage: [16]ShapedGlyph = undefined;
    const shaped = try face.shapeAscii("Hello", default_px_size, &shaped_storage);
    try std.testing.expectEqual(@as(usize, 5), shaped.len);
    for (shaped, 0..) |glyph_value, index| {
        try std.testing.expectEqual(index, glyph_value.cluster);
        try std.testing.expect(glyph_value.glyph_id != 0);
        try std.testing.expect(glyph_value.advance > 0.0);
    }

    var bitmap: [64 * 1024]u8 = undefined;
    var cache = Cache.init(face, &bitmap);
    var vertices: [16 * vertices_per_glyph]Vertex = undefined;
    const written = try cache.buildVertexBatch(shaped, 10.0, 10.0, default_px_size, &vertices);
    try std.testing.expect(written.len > 0);
    try std.testing.expectEqual(@as(usize, 0), written.len % vertices_per_glyph);
    for (written) |value| {
        try std.testing.expectEqual(@as(u32, 0), value.atlas_id);
        try std.testing.expect(value.a == vertex_color_one);
    }

    var ranges: [1]VertexAtlasRange = undefined;
    const grouped = try cache.buildVertexBatchesByAtlas(shaped, 10.0, 10.0, default_px_size, &vertices, &ranges);
    try std.testing.expectEqual(written.len, grouped.vertices.len);
    try std.testing.expectEqual(@as(usize, 1), grouped.ranges.len);
    try std.testing.expectEqual(written.len, grouped.ranges[0].vertex_count);
}

test "msdf rasterization emits rgb distance channels" {
    const face = try Face.geist();
    var bitmap: [128 * 1024]u8 = undefined;
    var cache = Cache.initFormat(face, &bitmap, .msdf_rgb);
    const glyph_id = face.glyphId('A');
    try std.testing.expect(glyph_id != 0);
    const glyph_value = try cache.bakeGlyph(glyph_id, 42.0);
    try std.testing.expectEqual(AtlasFormat.msdf_rgb, glyph_value.format);
    try std.testing.expect(glyph_value.width > 0);
    try std.testing.expect(glyph_value.height > 0);
    try std.testing.expectEqual(@as(usize, glyph_value.width) * @as(usize, glyph_value.height) * msdf_channels, cache.bitmap_len);

    const view = cache.bitmapView(glyph_value);
    try std.testing.expectEqual(@as(usize, msdf_channels), view.bytes_per_pixel);
    try std.testing.expectEqual(AtlasFormat.msdf_rgb, view.format);
    try std.testing.expect(msdfHasChannelVariation(view.pixels));
    try std.testing.expect(msdfHasDistanceRamp(view.pixels));
}

test "sdf rasterization emits single channel distance field" {
    const face = try Face.geist();
    var bitmap: [128 * 1024]u8 = undefined;
    var cache = Cache.initFormat(face, &bitmap, .sdf8);
    const glyph_id = face.glyphId('A');
    try std.testing.expect(glyph_id != 0);
    const glyph_value = try cache.bakeGlyph(glyph_id, 42.0);
    try std.testing.expectEqual(AtlasFormat.sdf8, glyph_value.format);
    try std.testing.expect(glyph_value.width > 0);
    try std.testing.expect(glyph_value.height > 0);
    try std.testing.expectEqual(@as(usize, glyph_value.width) * @as(usize, glyph_value.height), cache.bitmap_len);

    const view = cache.bitmapView(glyph_value);
    try std.testing.expectEqual(@as(usize, 1), view.bytes_per_pixel);
    try std.testing.expectEqual(AtlasFormat.sdf8, view.format);
    try std.testing.expect(sdfHasDistanceRamp(view.pixels));
}

test "sdf cache is distinct from alpha cache and drawable" {
    const face = try Face.geist();
    var pixels: [96 * 36]ui.Color = undefined;
    var surface = TestSurface{ .width = 96, .height = 36, .pixels = &pixels };
    var bitmap: [128 * 1024]u8 = undefined;
    var cache = Cache.initFormat(face, &bitmap, .sdf8);
    @memset(surface.pixels, ui.Color.clear);
    try cache.drawText(&surface, ui.Rect.init(0, 0, 96, 36), "sdf", ui.Color.text, 24);
    try std.testing.expect(pixelAlphaSum(&pixels) > 0);

    const sdf_len = cache.bitmap_len;
    cache.format = .alpha8;
    try cache.drawText(&surface, ui.Rect.init(0, 0, 96, 36), "sdf", ui.Color.text, 24);
    try std.testing.expect(cache.bitmap_len > sdf_len);
}

test "msdf cache is distinct from alpha cache and drawable" {
    const face = try Face.geist();
    var pixels: [96 * 36]ui.Color = undefined;
    var surface = TestSurface{ .width = 96, .height = 36, .pixels = &pixels };
    var bitmap: [128 * 1024]u8 = undefined;
    var cache = Cache.initFormat(face, &bitmap, .msdf_rgb);
    @memset(surface.pixels, ui.Color.clear);
    try cache.drawText(&surface, ui.Rect.init(0, 0, 96, 36), "msdf", ui.Color.text, 24);
    try std.testing.expect(pixelAlphaSum(&pixels) > 0);

    const msdf_len = cache.bitmap_len;
    cache.format = .alpha8;
    try cache.drawText(&surface, ui.Rect.init(0, 0, 96, 36), "msdf", ui.Color.text, 24);
    try std.testing.expect(cache.bitmap_len > msdf_len);
}

test "msdf encoded distance reconstructs crisp coverage alpha" {
    try std.testing.expectEqual(@as(u8, 0), msdfCoverageAlpha(0));
    try std.testing.expectEqual(@as(u8, 128), msdfCoverageAlpha(128));
    try std.testing.expectEqual(@as(u8, 255), msdfCoverageAlpha(255));
    try std.testing.expect(msdfCoverageAlpha(96) < 128);
    try std.testing.expect(msdfCoverageAlpha(160) > 128);
}

test "axis mapping and kern use ported fixed tables" {
    const empty = [_]u8{};
    var face = Face{
        .data = &empty,
        .units_per_em = 1000,
        .axis_count = 1,
        .avar_segment_count = 3,
        .kern_pair_count = 1,
    };
    face.axes[0] = .{ .tag = "wght".*, .min = 100.0, .default = 400.0, .max = 900.0 };
    face.avar_axes[0] = .{ .offset = 0, .count = 3 };
    face.avar_from[0] = -1.0;
    face.avar_to[0] = -1.0;
    face.avar_from[1] = 0.0;
    face.avar_to[1] = 0.0;
    face.avar_from[2] = 1.0;
    face.avar_to[2] = 0.5;
    face.kern_pairs[0] = .{ .left = 2, .right = 3, .adjust = -50 };

    try std.testing.expectEqual(@as(f32, 0.25), face.mapAxisValue(0, 650.0));
    try std.testing.expectEqual(@as(f32, -1.0), face.mapAxisValue(0, 0.0));
    try std.testing.expectEqual(@as(f32, -1.0), face.kern(2, 3, 20.0));
    try std.testing.expectEqual(@as(f32, 0.0), face.kern(3, 2, 20.0));
}

fn pixelAlphaSum(pixels: []const ui.Color) usize {
    var sum: usize = 0;
    for (pixels) |pixel| sum += pixel.a;
    return sum;
}

fn msdfHasChannelVariation(bytes: []const u8) bool {
    var i: usize = 0;
    while (i + 2 < bytes.len) : (i += msdf_channels) {
        if (bytes[i] != bytes[i + 1] or bytes[i] != bytes[i + 2]) return true;
    }
    return false;
}

fn msdfHasDistanceRamp(bytes: []const u8) bool {
    return sdfHasDistanceRamp(bytes);
}

fn sdfHasDistanceRamp(bytes: []const u8) bool {
    var low = false;
    var mid = false;
    var high = false;
    for (bytes) |value| {
        if (value <= 16) low = true;
        if (value >= 32 and value <= 224) mid = true;
        if (value >= 240) high = true;
    }
    return low and mid and high;
}

const TestSurface = struct {
    width: usize,
    height: usize,
    pixels: []ui.Color,

    pub fn blendPixel(self: *TestSurface, x: usize, y: usize, color: ui.Color, alpha: u8) void {
        _ = alpha;
        self.pixels[y * self.width + x] = color;
    }
};
