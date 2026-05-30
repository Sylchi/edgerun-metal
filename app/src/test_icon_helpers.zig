const std = @import("std");
const mem = std.mem;
const svg_parser = @import("svg_path_parser.zig");
const icon_vector = @import("ui/icon_vector.zig");

const GradSpec = union(enum) {
    linear: struct {
        space: icon_vector.GradientCoordinateSpace,
        spread: icon_vector.GradientSpreadMethod,
        x1: f32,
        y1: f32,
        x2: f32,
        y2: f32,
        stops: []const StopSpec,
    },
    radial: struct {
        space: icon_vector.GradientCoordinateSpace,
        spread: icon_vector.GradientSpreadMethod,
        cx: f32,
        cy: f32,
        radius: f32,
        fx: f32,
        fy: f32,
        focal_radius: f32,
        stops: []const StopSpec,
    },
};
const StopSpec = struct { offset: f32, color: icon_vector.Paint };

const PaintSpec = union(enum) {
    rgba: icon_vector.Paint,
    current_color: void,
    url: struct { ref: []const u8, fallback: ?icon_vector.Paint },
};
const FillRule = enum { nonzero, evenodd };
const StrokeCap = icon_vector.StrokeCap;
const StrokeJoin = icon_vector.StrokeJoin;

const SvgAttrs = struct {
    viewBox: svg_parser.ViewBox = .{ .width = 24, .height = 24 },
    fill: ?PaintSpec = PaintSpec{ .rgba = .{ .r = 0, .g = 0, .b = 0, .a = 255 } },
    stroke: ?PaintSpec = null,
    stroke_width: f32 = 2.0,
    stroke_linecap: StrokeCap = .round,
    stroke_linejoin: StrokeJoin = .round,
    fill_rule: FillRule = .nonzero,
    color: ?PaintSpec = null,
    fill_opacity: f32 = 1.0,
    stroke_opacity: f32 = 1.0,
};

pub fn svgToIr(alloc: mem.Allocator, svg: []const u8) ![]const f32 {
    var ir: std.ArrayList(f32) = .empty;
    errdefer ir.deinit(alloc);

    const default_attrs = extractSvgAttrs(alloc, svg);
    const viewbox = default_attrs.viewBox;
    const grads = extractGradients(alloc, svg, viewbox);
    defer for (&grads) |*g| {
        const spec = g.* orelse continue;
        switch (spec) {
            .linear => |s| alloc.free(s.stops),
            .radial => |s| alloc.free(s.stops),
        }
    };

    var search = svg;
    while (true) {
        const elem_start = findTagStart(search) orelse break;
        search = search[elem_start..];
        const elem_end = findTagEnd(search) orelse break;
        const tag_content = search[0 .. elem_end + 1];
        search = search[elem_end + 1 ..];
        const tag_name = extractTagName(tag_content) orelse continue;
        if (mem.eql(u8, tag_name, "svg")) continue;
        if (mem.eql(u8, tag_name, "defs") or
            mem.eql(u8, tag_name, "linearGradient") or
            mem.eql(u8, tag_name, "radialGradient") or
            mem.eql(u8, tag_name, "stop") or
            mem.eql(u8, tag_name, "clipPath")) continue;

        var attrs = extractAttributes(alloc, tag_content);
        defer attrs.deinit(alloc);

        const fill_spec = if (attrs.getRaw("fill")) |f| parsePaintSpec(f) else default_attrs.fill;
        const stroke_spec = if (attrs.getRaw("stroke")) |s| parsePaintSpec(s) else default_attrs.stroke;
        const stroke_width = parseF32Attr(attrs.getRaw("stroke-width"), default_attrs.stroke_width);
        const stroke_cap = parseStrokeCap(attrs.getRaw("stroke-linecap")) orelse default_attrs.stroke_linecap;
        const stroke_join = parseStrokeJoin(attrs.getRaw("stroke-linejoin")) orelse default_attrs.stroke_linejoin;
        const fill_rule = parseFillRule(attrs.getRaw("fill-rule")) orelse default_attrs.fill_rule;
        const fill_opacity = parseF32Attr(attrs.getRaw("fill-opacity"), default_attrs.fill_opacity);
        const stroke_opacity = parseF32Attr(attrs.getRaw("stroke-opacity"), default_attrs.stroke_opacity);
        const clip_path = attrs.getRaw("clip-path");
        const svg_color = default_attrs.color;

        const have_fill = fill_spec != null;
        const have_stroke = stroke_spec != null;

        if (have_fill and fill_opacity <= 0.0) {
            // fill invisible, even if specified
        }

        if (clip_path) |cp| {
            if (parseUrlRef(cp)) |ref| {
                try appendClipPathForRef(alloc, &ir, svg, ref, viewbox);
            }
        }

        if (mem.eql(u8, tag_name, "path")) {
            const d = attrs.getRaw("d") orelse continue;
            const fv = fill_opacity > 0.0;
            const sv = stroke_opacity > 0.0;
            if (have_fill and fv) {
                try appendPaint(&ir, alloc, fill_spec.?, svg_color, fill_opacity, grads);
                try appendBeginFill(&ir, alloc, fill_rule);
                try appendPathData(&ir, alloc, d, viewbox);
                try ir.append(alloc, icon_vector.op_end_fill_path);
            }
            if (have_stroke and sv) {
                if (!fv or !have_fill) {
                    try ir.appendSlice(alloc, &.{ icon_vector.op_stroke_width, stroke_width / viewbox.width });
                    try ir.appendSlice(alloc, &.{ icon_vector.op_stroke_cap, @floatFromInt(@intFromEnum(stroke_cap)) });
                    try ir.appendSlice(alloc, &.{ icon_vector.op_stroke_join, @floatFromInt(@intFromEnum(stroke_join)) });
                    try ir.appendSlice(alloc, &.{ icon_vector.op_stroke_miter_limit, 4.0 });
                }
                try appendPaint(&ir, alloc, stroke_spec.?, svg_color, stroke_opacity, grads);
                try appendPathData(&ir, alloc, d, viewbox);
                try ir.append(alloc, icon_vector.op_begin_fill_path);
                try ir.append(alloc, icon_vector.op_end_fill_path);
            }
        } else if (mem.eql(u8, tag_name, "circle")) {
            var cx = parseF32Attr(attrs.getRaw("cx"), 0.0);
            var cy = parseF32Attr(attrs.getRaw("cy"), 0.0);
            const r = parseF32Attr(attrs.getRaw("r"), 0.0);
            if (attrs.getRaw("transform")) |tx| {
                applyTranslate(tx, &cx, &cy);
            }
            const ncx = cx / viewbox.width;
            const ncy = cy / viewbox.height;
            const nr = r / viewbox.width;
            const fv = fill_opacity > 0.0;
            const sv = stroke_opacity > 0.0;
            if (have_fill and fv) {
                try appendPaint(&ir, alloc, fill_spec.?, svg_color, fill_opacity, grads);
                try ir.appendSlice(alloc, &.{ icon_vector.op_filled_circle, ncx, ncy, nr });
            }
            if (have_stroke and sv) {
                try ir.appendSlice(alloc, &.{ icon_vector.op_stroke_width, stroke_width / viewbox.width });
                try ir.appendSlice(alloc, &.{ icon_vector.op_stroke_cap, @floatFromInt(@intFromEnum(stroke_cap)) });
                try ir.appendSlice(alloc, &.{ icon_vector.op_stroke_join, @floatFromInt(@intFromEnum(stroke_join)) });
                try ir.appendSlice(alloc, &.{ icon_vector.op_stroke_miter_limit, 4.0 });
                try appendPaint(&ir, alloc, stroke_spec.?, svg_color, stroke_opacity, grads);
                try ir.appendSlice(alloc, &.{ icon_vector.op_circle, ncx, ncy, nr });
            }
        } else if (mem.eql(u8, tag_name, "rect")) {
            const x = parseF32Attr(attrs.getRaw("x"), 0.0) / viewbox.width;
            const y = parseF32Attr(attrs.getRaw("y"), 0.0) / viewbox.height;
            const w = parseF32Attr(attrs.getRaw("width"), 0.0) / viewbox.width;
            const h = parseF32Attr(attrs.getRaw("height"), 0.0) / viewbox.height;
            const rx = parseF32Attr(attrs.getRaw("rx"), 0.0) / viewbox.width;
            const fv = fill_opacity > 0.0;
            const sv = stroke_opacity > 0.0;
            if (have_fill and fv) {
                try appendPaint(&ir, alloc, fill_spec.?, svg_color, fill_opacity, grads);
                try ir.appendSlice(alloc, &.{ icon_vector.op_filled_round_rect, x, y, w, h, rx });
            }
            if (have_stroke and sv) {
                try ir.appendSlice(alloc, &.{ icon_vector.op_stroke_width, stroke_width / viewbox.width });
                try ir.appendSlice(alloc, &.{ icon_vector.op_stroke_cap, @floatFromInt(@intFromEnum(stroke_cap)) });
                try ir.appendSlice(alloc, &.{ icon_vector.op_stroke_join, @floatFromInt(@intFromEnum(stroke_join)) });
                try ir.appendSlice(alloc, &.{ icon_vector.op_stroke_miter_limit, 4.0 });
                try appendPaint(&ir, alloc, stroke_spec.?, svg_color, stroke_opacity, grads);
                try ir.appendSlice(alloc, &.{ icon_vector.op_round_rect, x, y, w, h, rx });
            }
        } else if (mem.eql(u8, tag_name, "polyline")) {
            const points_raw = attrs.getRaw("points") orelse continue;
            var pl_points: std.ArrayList(f32) = .empty;
            defer pl_points.deinit(alloc);
            try parsePolylinePoints(&pl_points, alloc, points_raw, viewbox);
            const fv = fill_opacity > 0.0;
            const sv = stroke_opacity > 0.0;
            if (have_fill and fv) {
                try appendPaint(&ir, alloc, fill_spec.?, svg_color, fill_opacity, grads);
                try appendBeginFill(&ir, alloc, fill_rule);
                try appendPolylineFillPath(&ir, alloc, pl_points.items);
                try ir.append(alloc, icon_vector.op_end_fill_path);
            }
            if (have_stroke and sv) {
                try ir.appendSlice(alloc, &.{ icon_vector.op_stroke_width, stroke_width / viewbox.width });
                try ir.appendSlice(alloc, &.{ icon_vector.op_stroke_cap, @floatFromInt(@intFromEnum(stroke_cap)) });
                try ir.appendSlice(alloc, &.{ icon_vector.op_stroke_join, @floatFromInt(@intFromEnum(stroke_join)) });
                try ir.appendSlice(alloc, &.{ icon_vector.op_stroke_miter_limit, 4.0 });
                try appendPaint(&ir, alloc, stroke_spec.?, svg_color, stroke_opacity, grads);
                try ir.appendSlice(alloc, pl_points.items);
            }
        }
    }

    return ir.toOwnedSlice(alloc);
}

fn applyTranslate(tx: []const u8, cx: *f32, cy: *f32) void {
    const t = mem.trim(u8, tx, " \"'");
    if (!mem.startsWith(u8, t, "translate(")) return;
    const paren = mem.indexOfScalar(u8, t, '(') orelse return;
    const close = mem.indexOfScalar(u8, t, ')') orelse return;
    var parts = mem.splitSequence(u8, t[paren + 1 .. close], " ");
    const dx = parseF32(parts.next() orelse return) orelse return;
    const dy_raw = parts.next();
    const dy = if (dy_raw) |d| parseF32(d) orelse 0.0 else 0.0;
    cx.* += dx;
    cy.* += dy;
}

fn extractGradients(alloc: mem.Allocator, svg: []const u8, viewbox: svg_parser.ViewBox) [4]?GradSpec {
    var result: [4]?GradSpec = .{ null, null, null, null };
    var defs_start: ?usize = null;
    const svg_idx: usize = 0;
    while (true) {
        const next_defs = mem.indexOf(u8, svg[svg_idx..], "<defs>") orelse break;
        defs_start = svg_idx + next_defs;
        break;
    }
    const defs_region = if (defs_start) |ds| blk: {
        const after_defs = svg[ds + 6 ..];
        const defs_end = mem.indexOf(u8, after_defs, "</defs>") orelse return result;
        break :blk after_defs[0..defs_end];
    } else return result;

    var grad_idx: usize = 0;
    var search = defs_region;
    while (grad_idx < 4) {
        const lg_start = mem.indexOf(u8, search, "<linearGradient") orelse
            mem.indexOf(u8, search, "<radialGradient") orelse break;
        const is_radial = mem.startsWith(u8, search[lg_start..], "<radial");
        const lg_end = mem.indexOf(u8, search[lg_start..], ">") orelse break;
        const tag = search[lg_start .. lg_start + lg_end + 1];
        search = search[lg_start + lg_end + 1 ..];

        var attrs = extractAttributes(alloc, tag);
        defer attrs.deinit(alloc);

        _ = attrs.getRaw("id") orelse continue;
        const href = attrs.getRaw("href");

        const grad_text = if (is_radial) blk: {
            const close_tag = mem.indexOf(u8, search, "</radialGradient>") orelse continue;
            const text = search[0..close_tag];
            search = search[close_tag + 17 ..];
            break :blk text;
        } else blk: {
            const close_tag = mem.indexOf(u8, search, "</linearGradient>") orelse continue;
            const text = search[0..close_tag];
            search = search[close_tag + 17 ..];
            break :blk text;
        };

        var stops_buf: [8]StopSpec = undefined;
        var stop_count: usize = 0;
        var stop_search = grad_text;
        while (stop_count < 8) {
            const stop_start = mem.indexOf(u8, stop_search, "<stop") orelse break;
            const stop_end = mem.indexOf(u8, stop_search[stop_start..], ">") orelse break;
            const stop_tag = stop_search[stop_start .. stop_start + stop_end + 1];
            stop_search = stop_search[stop_start + stop_end + 1 ..];
            var stop_attrs = extractAttributes(alloc, stop_tag);
            defer stop_attrs.deinit(alloc);
            const offset = parseF32Attr(stop_attrs.getRaw("offset"), 0.0);
            const stop_color_str = stop_attrs.getRaw("stop-color") orelse "black";
            const stop_color = if (parsePaintSpec(stop_color_str)) |ps| switch (ps) {
                .rgba => |c| c,
                else => icon_vector.Paint{ .r = 0, .g = 0, .b = 0, .a = 255 },
            } else icon_vector.Paint{ .r = 0, .g = 0, .b = 0, .a = 255 };
            stops_buf[stop_count] = .{ .offset = offset, .color = stop_color };
            stop_count += 1;
        }

        if (stop_count < 2) continue;

        const stops = alloc.alloc(StopSpec, stop_count) catch continue;
        @memcpy(stops, stops_buf[0..stop_count]);

        if (is_radial) {
            const space = parseGradSpace(attrs.getRaw("gradientUnits"));
            const spread = parseSpread(attrs.getRaw("spreadMethod"));
            var cx = parseF32Attr(attrs.getRaw("cx"), 0.5);
            var cy = parseF32Attr(attrs.getRaw("cy"), 0.5);
            var radius = parseF32Attr(attrs.getRaw("r"), 0.5);
            var fx = parseF32Attr(attrs.getRaw("fx"), 0.5);
            var fy = parseF32Attr(attrs.getRaw("fy"), 0.5);
            var focal_radius = parseF32Attr(attrs.getRaw("fr"), 0.0);
            if (space == .user_space) {
                cx /= viewbox.width;
                cy /= viewbox.height;
                radius /= viewbox.width;
                fx /= viewbox.width;
                fy /= viewbox.height;
                focal_radius /= viewbox.width;
            }
            result[grad_idx] = GradSpec{ .radial = .{
                .space = space,
                .spread = spread,
                .cx = cx, .cy = cy, .radius = radius,
                .fx = fx, .fy = fy, .focal_radius = focal_radius,
                .stops = stops,
            } };
        } else {
            const space = parseGradSpace(attrs.getRaw("gradientUnits"));
            const spread = parseSpread(attrs.getRaw("spreadMethod"));
            var x1 = parseF32Attr(attrs.getRaw("x1"), 0.0);
            var y1 = parseF32Attr(attrs.getRaw("y1"), 0.0);
            var x2 = parseF32Attr(attrs.getRaw("x2"), 1.0);
            var y2 = parseF32Attr(attrs.getRaw("y2"), 0.0);
            if (space == .user_space) {
                x1 /= viewbox.width;
                y1 /= viewbox.height;
                x2 /= viewbox.width;
                y2 /= viewbox.height;
            }
            if (href) |h| {
                const h_trim = mem.trim(u8, h, " \"'");
                if (mem.startsWith(u8, h_trim, "#")) {
                    for (&result) |*existing| {
                        if (existing.*) |e| {
                            _ = e;
                        }
                    }
                }
            }
            result[grad_idx] = GradSpec{ .linear = .{
                .space = space,
                .spread = spread,
                .x1 = x1, .y1 = y1, .x2 = x2, .y2 = y2,
                .stops = stops,
            } };
        }
        grad_idx += 1;
    }
    return result;
}

fn findGradById(grads: [4]?GradSpec, id: []const u8) ?GradSpec {
    _ = id;
    for (grads) |g| {
        if (g) |spec| return spec;
    }
    return null;
}

fn parseGradSpace(raw: ?[]const u8) icon_vector.GradientCoordinateSpace {
    const s = raw orelse return .object_bounding_box;
    const t = mem.trim(u8, s, " \"'");
    if (mem.eql(u8, t, "userSpaceOnUse")) return .user_space;
    return .object_bounding_box;
}

fn parseSpread(raw: ?[]const u8) icon_vector.GradientSpreadMethod {
    const s = raw orelse return .pad;
    const t = mem.trim(u8, s, " \"'");
    if (mem.eql(u8, t, "reflect")) return .reflect;
    if (mem.eql(u8, t, "repeat")) return .repeat;
    return .pad;
}

fn extractSvgAttrs(alloc: mem.Allocator, svg: []const u8) SvgAttrs {
    var result = SvgAttrs{};
    const svg_tag_start = mem.indexOf(u8, svg, "<svg") orelse return result;
    const svg_tag_end = findTagEnd(svg[svg_tag_start..]) orelse return result;
    const tag = svg[svg_tag_start .. svg_tag_start + svg_tag_end + 1];

    var attrs = extractAttributes(alloc, tag);
    defer attrs.deinit(alloc);
    if (attrs.getRaw("viewBox")) |vb| {
        result.viewBox = parseViewBox(vb) orelse result.viewBox;
    }
    if (attrs.getRaw("fill")) |f| {
        if (mem.eql(u8, mem.trim(u8, f, " \"'"), "none")) {
            result.fill = null;
        } else {
            result.fill = parsePaintSpec(f);
        }
    }
    if (attrs.getRaw("stroke")) |s| {
        result.stroke = parsePaintSpec(s);
    }
    if (attrs.getRaw("stroke-width")) |sw| {
        result.stroke_width = parseF32(sw) orelse result.stroke_width;
    }
    if (attrs.getRaw("stroke-linecap")) |lc| {
        result.stroke_linecap = parseStrokeCap(lc) orelse result.stroke_linecap;
    }
    if (attrs.getRaw("stroke-linejoin")) |lj| {
        result.stroke_linejoin = parseStrokeJoin(lj) orelse result.stroke_linejoin;
    }
    if (attrs.getRaw("fill-rule")) |fr| {
        result.fill_rule = parseFillRule(fr) orelse result.fill_rule;
    }
    if (attrs.getRaw("color")) |c| {
        result.color = parsePaintSpec(c);
    }
    if (attrs.getRaw("fill-opacity")) |fo| {
        result.fill_opacity = parseF32(fo) orelse result.fill_opacity;
    }
    if (attrs.getRaw("stroke-opacity")) |so| {
        result.stroke_opacity = parseF32(so) orelse result.stroke_opacity;
    }
    return result;
}

fn parsePaintSpec(value: []const u8) ?PaintSpec {
    const t = mem.trim(u8, value, " \"'");
    if (mem.eql(u8, t, "none")) return null;
    if (mem.eql(u8, t, "currentColor")) {
        return PaintSpec{ .current_color = {} };
    }
    if (mem.startsWith(u8, t, "url(")) {
        const end = mem.indexOfScalar(u8, t[4..], ')') orelse return null;
        const ref = t[4 .. 4 + end];
        const after = mem.trim(u8, t[4 + end + 1 ..], " ");
        const fallback: ?icon_vector.Paint = if (after.len > 0) blk: {
            if (parsePaintSpec(after)) |ps| {
                if (ps == .rgba) break :blk ps.rgba;
            }
            break :blk null;
        } else null;
        return PaintSpec{ .url = .{ .ref = ref, .fallback = fallback } };
    }
    if (t.len > 0 and t[0] == '#') {
        return PaintSpec{ .rgba = parseHexColor(t) orelse return null };
    }
    if (mem.startsWith(u8, t, "rgba(")) {
        return PaintSpec{ .rgba = parseRgbaColor(t) orelse return null };
    }
    if (mem.eql(u8, t, "red")) return PaintSpec{ .rgba = .{ .r = 255, .g = 0, .b = 0, .a = 255 } };
    if (mem.eql(u8, t, "green")) return PaintSpec{ .rgba = .{ .r = 0, .g = 128, .b = 0, .a = 255 } };
    if (mem.eql(u8, t, "blue")) return PaintSpec{ .rgba = .{ .r = 0, .g = 0, .b = 255, .a = 255 } };
    if (mem.eql(u8, t, "black")) return PaintSpec{ .rgba = .{ .r = 0, .g = 0, .b = 0, .a = 255 } };
    if (mem.eql(u8, t, "white")) return PaintSpec{ .rgba = .{ .r = 255, .g = 255, .b = 255, .a = 255 } };
    return null;
}

fn parseHexColor(value: []const u8) ?icon_vector.Paint {
    const t = if (value.len > 0 and value[0] == '#') value[1..] else value;
    if (t.len == 3) {
        return .{
            .r = tryHex2(t[0..1]) * 17,
            .g = tryHex2(t[1..2]) * 17,
            .b = tryHex2(t[2..3]) * 17,
            .a = 255,
        };
    }
    if (t.len == 6) {
        return .{ .r = tryHex2(t[0..2]), .g = tryHex2(t[2..4]), .b = tryHex2(t[4..6]), .a = 255 };
    }
    if (t.len == 8) {
        return .{ .r = tryHex2(t[0..2]), .g = tryHex2(t[2..4]), .b = tryHex2(t[4..6]), .a = tryHex2(t[6..8]) };
    }
    return null;
}

fn tryHex2(s: []const u8) u8 {
    var result: u8 = 0;
    for (s) |c| {
        result <<= 4;
        result |= switch (c) {
            '0'...'9' => c - '0',
            'a'...'f' => c - 'a' + 10,
            'A'...'F' => c - 'A' + 10,
            else => 0,
        };
    }
    return result;
}

fn parseRgbaColor(value: []const u8) ?icon_vector.Paint {
    const paren = mem.indexOfScalar(u8, value, '(') orelse return null;
    const close = mem.lastIndexOfScalar(u8, value, ')') orelse return null;
    var parts = mem.splitSequence(u8, value[paren + 1 .. close], ",");
    const r = parseF32(parts.next() orelse return null) orelse return null;
    const g = parseF32(parts.next() orelse return null) orelse return null;
    const b = parseF32(parts.next() orelse return null) orelse return null;
    const a_raw = parts.next() orelse "1.0";
    const a = parseF32(a_raw) orelse 1.0;
    return .{
        .r = clampByte(@intFromFloat(r)),
        .g = clampByte(@intFromFloat(g)),
        .b = clampByte(@intFromFloat(b)),
        .a = clampByte(@intFromFloat(a * 255.0)),
    };
}

fn clampByte(v: i32) u8 {
    return @intCast(@max(0, @min(255, v)));
}

fn appendPaint(ir: *std.ArrayList(f32), alloc: mem.Allocator, spec: PaintSpec, svg_color: ?PaintSpec, opacity: f32, grads: [4]?GradSpec) !void {
    switch (spec) {
        .rgba => |c| {
            const a = if (opacity < 1.0)
                @as(u8, @intFromFloat(@round(@as(f32, @floatFromInt(c.a)) * opacity)))
            else
                c.a;
            try ir.appendSlice(alloc, &.{ icon_vector.op_paint_rgba, @floatFromInt(c.r), @floatFromInt(c.g), @floatFromInt(c.b), @floatFromInt(a) });
        },
        .current_color => {
            const base = svg_color orelse {
                if (opacity < 1.0) {
                    const a: u8 = @intFromFloat(@round(opacity * 255.0));
                    try ir.appendSlice(alloc, &.{ icon_vector.op_paint_current_color_alpha, @floatFromInt(a) });
                } else {
                    try ir.append(alloc, icon_vector.op_paint_current_color);
                }
                return;
            };
            const c = switch (base) {
                .rgba => |v| v,
                else => return,
            };
            const a = if (opacity < 1.0)
                @as(u8, @intFromFloat(@round(@as(f32, @floatFromInt(c.a)) * opacity)))
            else
                c.a;
            try ir.appendSlice(alloc, &.{ icon_vector.op_paint_rgba, @floatFromInt(c.r), @floatFromInt(c.g), @floatFromInt(c.b), @floatFromInt(a) });
        },
        .url => |info| {
            if (findGradById(grads, info.ref)) |gs| {
                try appendGradOp(ir, alloc, gs, svg_color, opacity);
            } else if (info.fallback) |c| {
                try ir.appendSlice(alloc, &.{ icon_vector.op_paint_rgba, @floatFromInt(c.r), @floatFromInt(c.g), @floatFromInt(c.b), @floatFromInt(c.a) });
            } else {
                try ir.append(alloc, icon_vector.op_paint_current_color);
            }
        },
    }
}

fn appendGradOp(ir: *std.ArrayList(f32), alloc: mem.Allocator, gs: GradSpec, svg_color: ?PaintSpec, opacity: f32) !void {
    _ = svg_color;
    switch (gs) {
        .linear => |l| {
            try ir.append(alloc, icon_vector.op_paint_linear_gradient);
            try ir.append(alloc, @floatFromInt(@intFromEnum(l.space)));
            try ir.append(alloc, @floatFromInt(@intFromEnum(l.spread)));
            try ir.appendSlice(alloc, &.{ l.x1, l.y1, l.x2, l.y2 });
            const sc = @as(f32, @floatFromInt(l.stops.len));
            try ir.append(alloc, sc);
            for (l.stops) |s| {
                const a = if (opacity < 1.0)
                    @as(u8, @intFromFloat(@round(@as(f32, @floatFromInt(s.color.a)) * opacity)))
                else
                    s.color.a;
                try ir.appendSlice(alloc, &.{ s.offset, @floatFromInt(s.color.r), @floatFromInt(s.color.g), @floatFromInt(s.color.b), @floatFromInt(a) });
            }
        },
        .radial => |r| {
            try ir.append(alloc, icon_vector.op_paint_radial_gradient);
            try ir.append(alloc, @floatFromInt(@intFromEnum(r.space)));
            try ir.append(alloc, @floatFromInt(@intFromEnum(r.spread)));
            try ir.appendSlice(alloc, &.{ r.cx, r.cy, r.radius, r.fx, r.fy, r.focal_radius });
            const sc = @as(f32, @floatFromInt(r.stops.len));
            try ir.append(alloc, sc);
            for (r.stops) |s| {
                const a = if (opacity < 1.0)
                    clampByte(@intFromFloat(@as(f32, @floatFromInt(s.color.a)) * opacity))
                else
                    s.color.a;
                try ir.appendSlice(alloc, &.{ s.offset, @floatFromInt(s.color.r), @floatFromInt(s.color.g), @floatFromInt(s.color.b), @floatFromInt(a) });
            }
        },
    }
}

fn appendBeginFill(ir: *std.ArrayList(f32), alloc: mem.Allocator, rule: FillRule) !void {
    try ir.append(alloc, switch (rule) {
        .nonzero => icon_vector.op_begin_fill_path,
        .evenodd => icon_vector.op_begin_evenodd_fill_path,
    });
}

fn appendPathData(ir: *std.ArrayList(f32), alloc: mem.Allocator, d: []const u8, viewbox: svg_parser.ViewBox) !void {
    var pi = svg_parser.PathIterator.init(d);
    pi.view_box = viewbox;
    while (try pi.next()) |op| {
        switch (op) {
            .move_to => |p| try ir.appendSlice(alloc, &.{ icon_vector.op_move_to, p.x, p.y }),
            .line_to => |p| try ir.appendSlice(alloc, &.{ icon_vector.op_line_to, p.x, p.y }),
            .quad_to => |q| try ir.appendSlice(alloc, &.{ icon_vector.op_quad_to, q.control.x, q.control.y, q.end.x, q.end.y }),
            .cubic_to => |c| try ir.appendSlice(alloc, &.{ icon_vector.op_cubic_to, c.control0.x, c.control0.y, c.control1.x, c.control1.y, c.end.x, c.end.y }),
            .arc_to => |a| try ir.appendSlice(alloc, &.{ icon_vector.op_arc_to, a.rx, a.ry, a.x_axis_rotation, if (a.large_arc) 1.0 else 0.0, if (a.sweep) 1.0 else 0.0, a.end.x, a.end.y }),
            .close_path => try ir.append(alloc, icon_vector.op_close_path),
            else => {},
        }
    }
}

fn parsePolylinePoints(ir: *std.ArrayList(f32), alloc: mem.Allocator, points: []const u8, viewbox: svg_parser.ViewBox) !void {
    var values: std.ArrayList(f32) = .empty;
    defer values.deinit(alloc);
    var idx: usize = 0;
    while (idx < points.len) {
        svg_parser.skipSvgNumberSeparators(points, &idx) catch break;
        if (idx >= points.len) break;
        const x = try svg_parser.parseSvgNumber(points, &idx);
        svg_parser.skipSvgNumberSeparators(points, &idx) catch break;
        if (idx >= points.len) break;
        const y = try svg_parser.parseSvgNumber(points, &idx);
        try values.append(alloc, (x - viewbox.min_x) / viewbox.width);
        try values.append(alloc, (y - viewbox.min_y) / viewbox.height);
    }
    if (values.items.len >= 4) {
        try ir.append(alloc, icon_vector.op_polyline);
        try ir.append(alloc, @as(f32, @floatFromInt(values.items.len / 2)));
        try ir.appendSlice(alloc, values.items);
    }
}

fn appendPolylineFillPath(ir: *std.ArrayList(f32), alloc: mem.Allocator, items: []const f32) !void {
    if (items.len < 4) return;
    _ = items[0];
    const point_count = @as(usize, @intFromFloat(items[1]));
    if (point_count < 2) return;
    const pts = items[2..];
    if (pts.len < 2 * point_count) return;
    try ir.append(alloc, icon_vector.op_move_to);
    try ir.append(alloc, pts[0]);
    try ir.append(alloc, pts[1]);
    var i: usize = 1;
    while (i < point_count) : (i += 1) {
        try ir.append(alloc, icon_vector.op_line_to);
        try ir.append(alloc, pts[2 * i]);
        try ir.append(alloc, pts[2 * i + 1]);
    }
    try ir.append(alloc, icon_vector.op_close_path);
}

fn parseViewBox(value: []const u8) ?svg_parser.ViewBox {
    var idx: usize = 0;
    const min_x = svg_parser.parseSvgNumber(value, &idx) catch return null;
    svg_parser.skipSvgNumberSeparators(value, &idx) catch return null;
    const min_y = svg_parser.parseSvgNumber(value, &idx) catch return null;
    svg_parser.skipSvgNumberSeparators(value, &idx) catch return null;
    const w = svg_parser.parseSvgNumber(value, &idx) catch return null;
    svg_parser.skipSvgNumberSeparators(value, &idx) catch return null;
    const h = svg_parser.parseSvgNumber(value, &idx) catch return null;
    return svg_parser.ViewBox{ .min_x = min_x, .min_y = min_y, .width = w, .height = h };
}

fn parseF32Attr(raw: ?[]const u8, default: f32) f32 {
    return parseF32(raw orelse return default) orelse default;
}

fn parseF32(s: []const u8) ?f32 {
    const had_pct = mem.indexOfScalar(u8, s, '%') != null;
    const t = mem.trim(u8, s, " \"'%");
    if (t.len == 0) return null;
    const v = std.fmt.parseFloat(f32, t) catch return null;
    return if (had_pct) v / 100.0 else v;
}

fn parseStrokeCap(raw: ?[]const u8) ?StrokeCap {
    const s = raw orelse return null;
    const t = mem.trim(u8, s, " \"'");
    if (mem.eql(u8, t, "round")) return .round;
    if (mem.eql(u8, t, "butt")) return .butt;
    if (mem.eql(u8, t, "square")) return .square;
    return null;
}

fn parseStrokeJoin(raw: ?[]const u8) ?StrokeJoin {
    const s = raw orelse return null;
    const t = mem.trim(u8, s, " \"'");
    if (mem.eql(u8, t, "round")) return .round;
    if (mem.eql(u8, t, "miter")) return .miter;
    if (mem.eql(u8, t, "bevel")) return .bevel;
    return null;
}

fn parseFillRule(raw: ?[]const u8) ?FillRule {
    const s = raw orelse return null;
    const t = mem.trim(u8, s, " \"'");
    if (mem.eql(u8, t, "nonzero")) return .nonzero;
    if (mem.eql(u8, t, "evenodd")) return .evenodd;
    return null;
}

fn parseUrlRef(value: []const u8) ?[]const u8 {
    const t = mem.trim(u8, value, " \"'");
    const prefix = "url(#";
    if (!mem.startsWith(u8, t, prefix)) return null;
    const end = mem.indexOfScalar(u8, t[prefix.len..], ')') orelse return null;
    return t[prefix.len .. prefix.len + end];
}

fn findTagStart(svg: []const u8) ?usize {
    return mem.indexOf(u8, svg, "<");
}

fn findTagEnd(svg: []const u8) ?usize {
    return mem.indexOf(u8, svg, ">");
}

fn extractTagName(tag: []const u8) ?[]const u8 {
    const start: usize = if (tag.len > 0 and tag[0] == '<') 1 else 0;
    if (tag.len <= start) return null;
    if (tag[start] == '/') return null;
    if (tag[start] == '?') return null;
    var end = start;
    while (end < tag.len and !isSpace(tag[end]) and tag[end] != '>' and tag[end] != '/') end += 1;
    return tag[start..end];
}

fn isSpace(c: u8) bool {
    return switch (c) { ' ', '\t', '\n', '\r' => true, else => false };
}

const AttrMap = struct {
    pairs: std.ArrayListUnmanaged(AttrPair) = .empty,

    fn getRaw(self: AttrMap, name: []const u8) ?[]const u8 {
        for (self.pairs.items) |p| {
            if (mem.eql(u8, name, p.name)) return p.value;
        }
        return null;
    }

    fn deinit(self: *AttrMap, alloc: mem.Allocator) void {
        self.pairs.deinit(alloc);
    }
};

const AttrPair = struct { name: []const u8, value: []const u8 };

fn extractAttributes(alloc: mem.Allocator, tag: []const u8) AttrMap {
    var result = AttrMap{};
    var i: usize = 1;
    while (i < tag.len) {
        while (i < tag.len and isSpace(tag[i])) i += 1;
        if (i >= tag.len) break;
        if (tag[i] == '>' or tag[i] == '/') break;
        const name_start = i;
        while (i < tag.len and tag[i] != '=' and !isSpace(tag[i]) and tag[i] != '>' and tag[i] != '/') i += 1;
        if (i >= tag.len or tag[i] != '=') continue;
        const name = tag[name_start..i];
        i += 1;
        while (i < tag.len and isSpace(tag[i])) i += 1;
        if (i >= tag.len) break;
        const quote = tag[i];
        if (quote != '"' and quote != '\'') continue;
        i += 1;
        const val_start = i;
        while (i < tag.len and tag[i] != quote) i += 1;
        const value = tag[val_start..i];
        if (i < tag.len) i += 1;
        result.pairs.append(alloc, .{ .name = name, .value = value }) catch {};
    }
    return result;
}

fn appendClipPathForRef(alloc: mem.Allocator, ir: *std.ArrayList(f32), svg: []const u8, ref: []const u8, viewbox: svg_parser.ViewBox) !void {
    const clip_start = mem.indexOf(u8, svg, "<clipPath") orelse return;
    const clip_end = mem.indexOf(u8, svg[clip_start..], "</clipPath>") orelse return;
    const clip_content = svg[clip_start .. clip_start + clip_end + 12];

    const id_start = mem.indexOf(u8, clip_content, "id=\"") orelse return;
    const id_val_start = id_start + 4;
    const id_end = mem.indexOfScalar(u8, clip_content[id_val_start..], '"') orelse return;
    const clip_id = clip_content[id_val_start .. id_val_start + id_end];
    if (!mem.eql(u8, clip_id, ref)) return;

    try ir.append(alloc, icon_vector.op_begin_clip_path);
    try ir.appendSlice(alloc, &.{ icon_vector.op_paint_rgba, 255, 255, 255, 255 });
    try ir.append(alloc, icon_vector.op_begin_fill_path);
    var search = clip_content;
    while (true) {
        const path_tag_start = mem.indexOf(u8, search, "<path") orelse break;
        const path_tag_end = mem.indexOf(u8, search[path_tag_start..], ">") orelse break;
        const path_tag = search[path_tag_start .. path_tag_start + path_tag_end + 1];
        search = search[path_tag_start + path_tag_end + 1 ..];
        var pattrs = extractAttributes(alloc, path_tag);
        defer pattrs.deinit(alloc);
        const d = pattrs.getRaw("d") orelse continue;
        try appendPathData(ir, alloc, d, viewbox);
    }
    try ir.append(alloc, icon_vector.op_end_fill_path);
    try ir.append(alloc, icon_vector.op_end_clip_path);
}
