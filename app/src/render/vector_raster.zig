const std = @import("std");
const math = @import("../math.zig");
const font_vector = @import("font.zig");

pub const Error = error{
    InvalidFont,
    GlyphEdgeBudgetExceeded,
    GlyphBitmapBudgetExceeded,
};

const max_edges: usize = 2048;

pub const Point = struct { x: f32, y: f32 };
const Edge = struct { a: Point, b: Point };
const Hit = struct { x: f32, direction: i8 };
const Bounds = struct { x_min: f32, y_min: f32, x_max: f32, y_max: f32 };

pub const GlyphBitmap = struct {
    width: usize,
    height: usize,
    left: i16,
    top: i16,
};

const quadratic_steps: usize = 10;
const raster_samples: usize = 8;
const padding_pixels: i16 = 1;
const sharpen_max_px: u8 = 16;
const sharpen_midpoint: f32 = 128.0;
const sharpen_contrast: f32 = 1.14;
const sharpen_lift: f32 = 6.0;

pub fn bakeAlpha(
    atlas_alpha: []u8,
    atlas_stride: usize,
    glyph_commands: []const font_vector.Command,
    scale: f32,
    px: u8,
) Error!GlyphBitmap {
    var edges: [max_edges]Edge = undefined;
    const edge_count = try flatten(glyph_commands, scale, &edges);
    const b = edgeBounds(edges[0..edge_count]) orelse return .{ .width = 0, .height = 0, .left = 0, .top = 0 };
    const left = @as(i16, @intFromFloat(@floor(b.x_min))) - padding_pixels;
    const right = @as(i16, @intFromFloat(@ceil(b.x_max))) + padding_pixels;
    const top = @as(i16, @intFromFloat(@floor(b.y_min))) - padding_pixels;
    const bottom = @as(i16, @intFromFloat(@ceil(b.y_max))) + padding_pixels;
    if (right <= left or bottom <= top) return .{ .width = 0, .height = 0, .left = 0, .top = 0 };

    const w: usize = @intCast(right - left);
    const h: usize = @intCast(bottom - top);
    fillAlpha(atlas_alpha, atlas_stride, w, h, left, top, edges[0..edge_count]);
    if (px <= sharpen_max_px) sharpenAlpha(atlas_alpha, atlas_stride, w, h);
    return .{ .width = w, .height = h, .left = left, .top = top };
}

fn flatten(commands: []const font_vector.Command, scale: f32, edges: *[max_edges]Edge) Error!usize {
    var n: usize = 0;
    var current = Point{ .x = 0, .y = 0 };
    var contour_start = current;
    var has_current = false;
    for (commands) |command| switch (command) {
        .move_to => |p| {
            current = transform(p, scale);
            contour_start = current;
            has_current = true;
        },
        .line_to => |p| {
            if (!has_current) return error.InvalidFont;
            const next = transform(p, scale);
            n = try appendEdge(edges, n, current, next);
            current = next;
        },
        .quad_to => |q| {
            if (!has_current) return error.InvalidFont;
            const c = transform(q.control, scale);
            const e = transform(q.end, scale);
            n = try appendQuadratic(edges, n, current, c, e);
            current = e;
        },
        .close => {
            if (!has_current) return error.InvalidFont;
            n = try appendEdge(edges, n, current, contour_start);
            has_current = false;
        },
    };
    if (has_current) n = try appendEdge(edges, n, current, contour_start);
    return n;
}

fn transform(p: font_vector.Point, scale: f32) Point {
    return .{ .x = p.x * scale, .y = -p.y * scale };
}

fn appendQuadratic(edges: *[max_edges]Edge, start_count: usize, p0: Point, p1: Point, p2: Point) Error!usize {
    var count = start_count;
    var prev = p0;
    var step: usize = 1;
    while (step <= quadratic_steps) : (step += 1) {
        const t = @as(f32, @floatFromInt(step)) / @as(f32, @floatFromInt(quadratic_steps));
        const mt = 1.0 - t;
        const next = Point{
            .x = mt * mt * p0.x + 2.0 * mt * t * p1.x + t * t * p2.x,
            .y = mt * mt * p0.y + 2.0 * mt * t * p1.y + t * t * p2.y,
        };
        count = try appendEdge(edges, count, prev, next);
        prev = next;
    }
    return count;
}

fn appendEdge(edges: *[max_edges]Edge, count: usize, a: Point, b: Point) Error!usize {
    if (count >= max_edges) return error.GlyphEdgeBudgetExceeded;
    if (a.x == b.x and a.y == b.y) return count;
    edges[count] = .{ .a = a, .b = b };
    return count + 1;
}

fn edgeBounds(edges: []const Edge) ?Bounds {
    if (edges.len == 0) return null;
    var b = Bounds{ .x_min = edges[0].a.x, .y_min = edges[0].a.y, .x_max = edges[0].a.x, .y_max = edges[0].a.y };
    for (edges) |e| {
        include(&b, e.a);
        include(&b, e.b);
    }
    return b;
}

fn include(b: *Bounds, p: Point) void {
    b.x_min = @min(b.x_min, p.x);
    b.y_min = @min(b.y_min, p.y);
    b.x_max = @max(b.x_max, p.x);
    b.y_max = @max(b.y_max, p.y);
}

fn fillAlpha(alpha: []u8, stride: usize, w: usize, h: usize, left_i: i16, top_i: i16, edges: []const Edge) void {
    const sample_count = raster_samples * raster_samples;
    const right_f = @as(f32, @floatFromInt(left_i)) + @as(f32, @floatFromInt(w));
    var hits: [max_edges]Hit = undefined;
    var y: usize = 0;
    while (y < h) : (y += 1) {
        const row = alpha[y * stride .. y * stride + w];
        @memset(row, 0);
        var sy: usize = 0;
        while (sy < raster_samples) : (sy += 1) {
            const sample_y = @as(f32, @floatFromInt(top_i)) + @as(f32, @floatFromInt(y)) + sampleOffset(sy);
            const hit_count = sortedHits(sample_y, edges, &hits);
            var winding: i32 = 0;
            var i: usize = 0;
            while (i < hit_count) : (i += 1) {
                winding += hits[i].direction;
                if (winding != 0 and i + 1 < hit_count) fillSpan(row, left_i, right_f, hits[i].x, hits[i + 1].x);
            }
        }
        var x: usize = 0;
        while (x < w) : (x += 1) row[x] = @intCast((@as(u16, row[x]) * 255) / sample_count);
    }
}

fn sortedHits(y: f32, edges: []const Edge, hits: *[max_edges]Hit) usize {
    var count: usize = 0;
    for (edges) |e| {
        if (e.a.y <= y) {
            if (e.b.y > y) insertHit(hits, &count, .{ .x = xAtY(e, y), .direction = 1 });
        } else if (e.b.y <= y) {
            insertHit(hits, &count, .{ .x = xAtY(e, y), .direction = -1 });
        }
    }
    return count;
}

fn xAtY(e: Edge, y: f32) f32 {
    return e.a.x + ((y - e.a.y) * (e.b.x - e.a.x)) / (e.b.y - e.a.y);
}

fn insertHit(hits: *[max_edges]Hit, count: *usize, hit: Hit) void {
    var i = count.*;
    while (i > 0 and hits[i - 1].x > hit.x) : (i -= 1) hits[i] = hits[i - 1];
    hits[i] = hit;
    count.* += 1;
}

fn fillSpan(row: []u8, left_i: i16, right_limit: f32, span_a: f32, span_b: f32) void {
    const left = @max(span_a, @as(f32, @floatFromInt(left_i)));
    const right = @min(span_b, right_limit);
    if (right <= left) return;
    const origin = @as(f32, @floatFromInt(left_i));
    var x: usize = @intFromFloat(@max(@floor(left - origin), 0.0));
    const end: usize = @min(row.len, @as(usize, @intFromFloat(@ceil(right - origin))));
    while (x < end) : (x += 1) {
        var sx: usize = 0;
        while (sx < raster_samples) : (sx += 1) {
            const sample_x = origin + @as(f32, @floatFromInt(x)) + sampleOffset(sx);
            if (sample_x >= left and sample_x < right) row[x] += 1;
        }
    }
}

fn sampleOffset(i: usize) f32 {
    return (@as(f32, @floatFromInt(i)) + 0.5) / @as(f32, @floatFromInt(raster_samples));
}

fn sharpenAlpha(alpha: []u8, stride: usize, w: usize, h: usize) void {
    var y: usize = 0;
    while (y < h) : (y += 1) {
        const row = alpha[y * stride .. y * stride + w];
        for (row) |*sample| sample.* = sharpen(sample.*);
    }
}

fn sharpen(sample: u8) u8 {
    if (sample == 0 or sample == 255) return sample;
    const value = sharpen_midpoint + (@as(f32, @floatFromInt(sample)) - sharpen_midpoint) * sharpen_contrast + sharpen_lift;
    return @intFromFloat(@round(math.clampF(value, 0.0, 255.0)));
}
