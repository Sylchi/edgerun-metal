const std = @import("std");
const mem = std.mem;
const heap = std.heap;
const svg_parser = @import("../src/svg_path_parser.zig");
const icon_vector = @import("../src/icon_vector.zig");

pub fn main(init: std.process.Init) !void {
    const alloc = heap.page_allocator;
    const io = init.io;
    const cwd = std.Io.Dir.cwd();

    const icon_dir = try cwd.openDir(io, "src/icons/tabler", .{ .iterate = true });
    defer icon_dir.close(io);

    var icon_list = std.ArrayList(IconData).init(alloc);
    var walker = try icon_dir.walk(alloc);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file) continue;
        if (!mem.endsWith(u8, entry.basename, ".svg")) continue;

        const raw = try icon_dir.readFileAlloc(io, entry.path, alloc);
        const svg_text = mem.trim(u8, raw, " \t\r\n");
        const meta = parseMetadata(svg_text);
        const name = entry.basename[0 .. entry.basename.len - 4];

        var ir = std.ArrayList(f32).init(alloc);

        // Emit stroke defaults from <svg> element
        const sw_str = extractSvgAttribute(svg_text, "stroke-width") orelse "2";
        const sw = try std.fmt.parseFloat(f32, sw_str);
        const cap_str = extractSvgAttribute(svg_text, "stroke-linecap") orelse "round";
        const join_str = extractSvgAttribute(svg_text, "stroke-linejoin") orelse "round";
        const cap: u8 = if (mem.eql(u8, cap_str, "butt")) 0 else if (mem.eql(u8, cap_str, "square")) 2 else 1;
        const join: u8 = if (mem.eql(u8, join_str, "bevel")) 2 else if (mem.eql(u8, join_str, "miter")) 0 else 1;

        try ir.appendSlice(&.{ icon_vector.op_stroke_width, sw / 24.0, icon_vector.op_stroke_cap, @floatFromInt(cap), icon_vector.op_stroke_join, @floatFromInt(join) });

        // Parse each <path d="..."> element
        var search = svg_text;
        while (extractPathDAttribute(search)) |d| {
            const path_start = mem.indexOf(u8, search, "<path") orelse break;
            search = search[path_start + 5..];

            var pi = svg_parser.PathIterator.init(d);
            while (try pi.next()) |op| {
                try appendOp(&ir, op);
            }
        }

        try icon_list.append(.{
            .name = try alloc.dupe(u8, name),
            .tags = try alloc.dupe(u8, meta.tags),
            .category = try alloc.dupe(u8, meta.category),
            .ir = try ir.toOwnedSlice(),
        });
    }

    const icons = try icon_list.toOwnedSlice();
    mem.sortUnstable(IconData, icons, {}, lessThanByName);

    const out_dir = try cwd.makeOpenDir(io, ".build", .{});
    defer out_dir.close(io);

    try emitAssetPack(out_dir, io, alloc, icons);

    var total_ir: usize = 0;
    for (icons) |ic| total_ir += ic.ir.len;
    std.debug.print("gen_icon_objects: {d} icons, {d} f32 values ({d} bytes)\n", .{ icons.len, total_ir, total_ir * @sizeOf(f32) });
}

fn appendOp(ir: *std.ArrayList(f32), op: icon_vector.Op) !void {
    switch (op) {
        .move_to => |p| try ir.appendSlice(&.{ icon_vector.op_move_to, p.x, p.y }),
        .line_to => |p| try ir.appendSlice(&.{ icon_vector.op_line_to, p.x, p.y }),
        .quad_to => |q| try ir.appendSlice(&.{ icon_vector.op_quad_to, q.control.x, q.control.y, q.end.x, q.end.y }),
        .cubic_to => |c| try ir.appendSlice(&.{ icon_vector.op_cubic_to, c.control0.x, c.control0.y, c.control1.x, c.control1.y, c.end.x, c.end.y }),
        .arc_to => |a| try ir.appendSlice(&.{ icon_vector.op_arc_to, a.rx, a.ry, a.x_axis_rotation, if (a.large_arc) 1.0 else 0.0, if (a.sweep) 1.0 else 0.0, a.end.x, a.end.y }),
        .close_path => try ir.append(icon_vector.op_close_path),
        .circle => |c| try ir.appendSlice(&.{ icon_vector.op_circle, c.cx, c.cy, c.radius }),
        .ellipse => |e| {
            try ir.appendSlice(&.{ icon_vector.op_ellipse, e.cx, e.cy, e.rx, e.ry });
            try ir.append(if (e.full) 1.0 else 0.0);
        },
        .round_rect => |r| try ir.appendSlice(&.{ icon_vector.op_round_rect, r.x, r.y, r.w, r.h, r.radius }),
        .filled_circle => |c| try ir.appendSlice(&.{ icon_vector.op_filled_circle, c.cx, c.cy, c.radius }),
        .filled_ellipse => |e| {
            try ir.appendSlice(&.{ icon_vector.op_filled_ellipse, e.cx, e.cy, e.rx, e.ry });
            try ir.append(if (e.full) 1.0 else 0.0);
        },
        .filled_round_rect => |r| try ir.appendSlice(&.{ icon_vector.op_filled_round_rect, r.x, r.y, r.w, r.h, r.radius }),
        .polyline => |pts| {
            try ir.append(icon_vector.op_polyline);
            try ir.append(@as(f32, @floatFromInt(pts.len / 2)));
            try ir.appendSlice(pts);
        },
        .begin_fill_path => try ir.append(icon_vector.op_begin_fill_path),
        .begin_evenodd_fill_path => try ir.append(icon_vector.op_begin_evenodd_fill_path),
        .end_fill_path => try ir.append(icon_vector.op_end_fill_path),
        .paint_rgba => |p| try ir.appendSlice(&.{ icon_vector.op_paint_rgba, @floatFromInt(p.r), @floatFromInt(p.g), @floatFromInt(p.b), @floatFromInt(p.a) }),
        .paint_current_color => try ir.append(icon_vector.op_paint_current_color),
        .paint_current_color_alpha => |a| try ir.appendSlice(&.{ icon_vector.op_paint_current_color_alpha, @floatFromInt(a) }),
        .paint_linear_gradient => |g| {
            try ir.append(icon_vector.op_paint_linear_gradient);
            try ir.append(@floatFromInt(@intFromEnum(g.coordinate_space)));
            try ir.append(@floatFromInt(@intFromEnum(g.spread)));
            try ir.appendSlice(&.{ g.x1, g.y1, g.x2, g.y2 });
            try ir.append(@as(f32, @floatFromInt(g.stop_count)));
            var i: usize = 0;
            while (i < g.stop_count) : (i += 1) {
                try ir.appendSlice(&.{ g.stops[i].offset, @floatFromInt(g.stops[i].color.r), @floatFromInt(g.stops[i].color.g), @floatFromInt(g.stops[i].color.b), @floatFromInt(g.stops[i].color.a) });
            }
        },
        .paint_radial_gradient => |g| {
            try ir.append(icon_vector.op_paint_radial_gradient);
            try ir.append(@floatFromInt(@intFromEnum(g.coordinate_space)));
            try ir.append(@floatFromInt(@intFromEnum(g.spread)));
            try ir.appendSlice(&.{ g.cx, g.cy, g.radius, g.fx, g.fy, g.focal_radius });
            try ir.append(@as(f32, @floatFromInt(g.stop_count)));
            var i: usize = 0;
            while (i < g.stop_count) : (i += 1) {
                try ir.appendSlice(&.{ g.stops[i].offset, @floatFromInt(g.stops[i].color.r), @floatFromInt(g.stops[i].color.g), @floatFromInt(g.stops[i].color.b), @floatFromInt(g.stops[i].color.a) });
            }
        },
        .stroke_width => |w| try ir.appendSlice(&.{ icon_vector.op_stroke_width, w }),
        .stroke_cap => |c| try ir.appendSlice(&.{ icon_vector.op_stroke_cap, @floatFromInt(@intFromEnum(c)) }),
        .stroke_join => |j| try ir.appendSlice(&.{ icon_vector.op_stroke_join, @floatFromInt(@intFromEnum(j)) }),
        .stroke_miter_limit => |ml| try ir.appendSlice(&.{ icon_vector.op_stroke_miter_limit, ml }),
        .begin_clip_path => try ir.append(icon_vector.op_begin_clip_path),
        .end_clip_path => try ir.append(icon_vector.op_end_clip_path),
        .clear_clip_path => try ir.append(icon_vector.op_clear_clip_path),
    }
}

const Metadata = struct { tags: []const u8, category: []const u8 };

fn parseMetadata(svg: []const u8) Metadata {
    var tags: []const u8 = "";
    var category: []const u8 = "";
    var lines = mem.splitScalar(u8, svg, '\n');
    while (lines.next()) |line| {
        const t = mem.trim(u8, line, " \t\r");
        if (mem.indexOf(u8, t, "tags:")) |idx| tags = mem.trim(u8, t[idx + 5 ..], " :\t\r[]");
        if (mem.indexOf(u8, t, "category:")) |idx| category = mem.trim(u8, t[idx + 9 ..], " :\t\r");
    }
    return .{ .tags = tags, .category = category };
}

fn extractSvgAttribute(svg: []const u8, attr: []const u8) ?[]const u8 {
    var buf: [64]u8 = undefined;
    @memcpy(buf[0..attr.len], attr);
    buf[attr.len] = '=';
    buf[attr.len + 1] = '"';
    const prefix = buf[0 .. attr.len + 2];
    const idx = mem.indexOf(u8, svg, prefix) orelse return null;
    const start = idx + prefix.len;
    const end = mem.indexOfScalar(u8, svg[start..], '"') orelse return null;
    return svg[start..start + end];
}

fn extractPathDAttribute(svg: []const u8) ?[]const u8 {
    const prefix = "d=\"";
    const idx = mem.indexOf(u8, svg, prefix) orelse return null;
    const start = idx + prefix.len;
    const end = mem.indexOfScalar(u8, svg[start..], '"') orelse return null;
    return svg[start..start + end];
}

fn lessThanByName(a: IconData, b: IconData) bool {
    return mem.lessThan(u8, a.name, b.name);
}

const IconData = struct {
    name: []const u8,
    tags: []const u8,
    category: []const u8,
    ir: []const f32,
};

fn emitAssetPack(dir: std.Io.Dir, io: std.Io, _: mem.Allocator, icons: []const IconData) !void {
    var buf: [4096]u8 = undefined;

    // Write index Zig file
    {
        dir.deleteFile(io, "icon_asset_pack_index.zig") catch {};
        var f = try dir.createFile(io, "icon_asset_pack_index.zig", .{ .truncate = true });
        defer f.close(io);
        var w = f.writer(io, &buf);
        const W = @TypeOf(w.interface);

        try w.interface.writeAll(
            \\const std = @import("std");
            \\const mem = std.mem;
            \\
            \\pub const icon_count: u32 = 
        );
        try W.writeInt(w.stream, @as(u64, icons.len), .little);
        try w.interface.writeAll(
            \\;
            \\
            \\pub const Entry = struct {
            \\    name: []const u8,
            \\    tags: []const u8,
            \\    category: []const u8,
            \\    ir_offset: u32,
            \\    ir_len: u32,
            \\};
            \\
            \\pub const entries = [_]Entry{
            \\
        );

        var offset: u32 = 0;
        for (icons) |ic| {
            const data_len = @as(u32, @intCast(ic.ir.len * @sizeOf(f32)));
            try w.interface.print("    .{{ .name = \"{s}\", .tags = \"{s}\", .category = \"{s}\", .ir_offset = {d}, .ir_len = {d} }},\n", .{ ic.name, ic.tags, ic.category, offset, data_len });
            offset += data_len;
        }

        try w.interface.writeAll(
            \\};
            \\
        );
    }

    // Write IR binary data
    {
        dir.deleteFile(io, "icon_asset_pack_ir.bin") catch {};
        var f = try dir.createFile(io, "icon_asset_pack_ir.bin", .{ .truncate = true });
        defer f.close(io);
        for (icons) |ic| {
            try f.write(io, mem.sliceAsBytes(ic.ir));
        }
    }
}
