const std = @import("std");
const mem = std.mem;
const svg_parser = @import("svg_path_parser.zig");
const icon_vector = @import("icon_vector.zig");

pub fn main(init: std.process.Init) !void {
    const alloc = std.heap.page_allocator;
    const io = init.io;
    const cwd = std.Io.Dir.cwd();

    const icon_dir = try cwd.openDir(io, "src/icons/tabler", .{ .iterate = true });
    defer icon_dir.close(io);

    var icon_list: std.ArrayList(IconData) = .empty;
    var walker = try icon_dir.walk(alloc);
    defer walker.deinit();

    while (try walker.next(io)) |entry| {
        if (entry.kind != .file) continue;
        if (!mem.endsWith(u8, entry.basename, ".svg")) continue;

        const raw = try icon_dir.readFileAlloc(io, entry.path, alloc, .limited(65536));
        const svg_text = mem.trim(u8, raw, " \t\r\n");
        const meta = parseMetadata(svg_text);
        const name = entry.basename[0 .. entry.basename.len - 4];

        var ir: std.ArrayList(f32) = .empty;
        defer ir.deinit(alloc);

        try ir.append(alloc, icon_vector.op_stroke_width);
        try ir.append(alloc, 2.0 / 24.0);
        try ir.append(alloc, icon_vector.op_stroke_cap);
        try ir.append(alloc, 1.0);
        try ir.append(alloc, icon_vector.op_stroke_join);
        try ir.append(alloc, 1.0);

        var search = svg_text;
        while (true) {
            const path_tag = mem.indexOf(u8, search, "<path") orelse break;
            search = search[path_tag + 5 ..];
            const d_attr = extractDAttribute(search) orelse continue;
            var pi = svg_parser.PathIterator.init(d_attr);
            while (try pi.next()) |op| {
                try appendOp(alloc, &ir, op);
            }
        }

        try icon_list.append(alloc, .{
            .name = try alloc.dupe(u8, name),
            .tags = try alloc.dupe(u8, meta.tags),
            .category = try alloc.dupe(u8, meta.category),
            .ir = try ir.toOwnedSlice(alloc),
        });
    }

    const icons = try icon_list.toOwnedSlice(alloc);
    mem.sortUnstable(IconData, icons, {}, lessThanByName);

    try cwd.createDirPath(io, "src/gen");
    const out_dir = try cwd.openDir(io, "src/gen", .{});
    defer out_dir.close(io);

    try emitAssetPack(out_dir, io, alloc, icons);

    var total_ir: usize = 0;
    for (icons) |ic| total_ir += ic.ir.len;
    std.debug.print("gen_icon_objects: {d} icons, {d} f32 values ({d} bytes)\n", .{ icons.len, total_ir, total_ir * @sizeOf(f32) });
}

fn extractDAttribute(svg: []const u8) ?[]const u8 {
    const prefix = "d=\"";
    const idx = mem.indexOf(u8, svg, prefix) orelse return null;
    const start = idx + prefix.len;
    const end = mem.indexOfScalar(u8, svg[start..], '"') orelse return null;
    return svg[start..start + end];
}

fn appendOp(alloc: mem.Allocator, ir: *std.ArrayList(f32), op: icon_vector.Op) !void {
    switch (op) {
        .move_to => |p| try ir.appendSlice(alloc, &.{ icon_vector.op_move_to, p.x, p.y }),
        .line_to => |p| try ir.appendSlice(alloc, &.{ icon_vector.op_line_to, p.x, p.y }),
        .quad_to => |q| try ir.appendSlice(alloc, &.{ icon_vector.op_quad_to, q.control.x, q.control.y, q.end.x, q.end.y }),
        .cubic_to => |c| try ir.appendSlice(alloc, &.{ icon_vector.op_cubic_to, c.control0.x, c.control0.y, c.control1.x, c.control1.y, c.end.x, c.end.y }),
        .arc_to => |a| try ir.appendSlice(alloc, &.{ icon_vector.op_arc_to, a.rx, a.ry, a.x_axis_rotation, if (a.large_arc) 1.0 else 0.0, if (a.sweep) 1.0 else 0.0, a.end.x, a.end.y }),
        .close_path => try ir.append(alloc, icon_vector.op_close_path),
        .circle => |c| try ir.appendSlice(alloc, &.{ icon_vector.op_circle, c.cx, c.cy, c.radius }),
        .ellipse => |e| {
            try ir.appendSlice(alloc, &.{ icon_vector.op_ellipse, e.cx, e.cy, e.rx, e.ry });
            try ir.append(alloc, if (e.full) 1.0 else 0.0);
        },
        .round_rect => |r| try ir.appendSlice(alloc, &.{ icon_vector.op_round_rect, r.x, r.y, r.w, r.h, r.radius }),
        .filled_circle => |c| try ir.appendSlice(alloc, &.{ icon_vector.op_filled_circle, c.cx, c.cy, c.radius }),
        .filled_ellipse => |e| {
            try ir.appendSlice(alloc, &.{ icon_vector.op_filled_ellipse, e.cx, e.cy, e.rx, e.ry });
            try ir.append(alloc, if (e.full) 1.0 else 0.0);
        },
        .filled_round_rect => |r| try ir.appendSlice(alloc, &.{ icon_vector.op_filled_round_rect, r.x, r.y, r.w, r.h, r.radius }),
        .polyline => |pts| {
            try ir.append(alloc, icon_vector.op_polyline);
            try ir.append(alloc, @as(f32, @floatFromInt(pts.len / 2)));
            try ir.appendSlice(alloc, pts);
        },
        .begin_fill_path => try ir.append(alloc, icon_vector.op_begin_fill_path),
        .begin_evenodd_fill_path => try ir.append(alloc, icon_vector.op_begin_evenodd_fill_path),
        .end_fill_path => try ir.append(alloc, icon_vector.op_end_fill_path),
        .paint_rgba => |p| try ir.appendSlice(alloc, &.{ icon_vector.op_paint_rgba, @floatFromInt(p.r), @floatFromInt(p.g), @floatFromInt(p.b), @floatFromInt(p.a) }),
        .paint_current_color => try ir.append(alloc, icon_vector.op_paint_current_color),
        .paint_current_color_alpha => |a| try ir.appendSlice(alloc, &.{ icon_vector.op_paint_current_color_alpha, @floatFromInt(a) }),
        .paint_linear_gradient => |g| {
            try ir.append(alloc, icon_vector.op_paint_linear_gradient);
            try ir.append(alloc, @floatFromInt(@intFromEnum(g.coordinate_space)));
            try ir.append(alloc, @floatFromInt(@intFromEnum(g.spread)));
            try ir.appendSlice(alloc, &.{ g.x1, g.y1, g.x2, g.y2 });
            try ir.append(alloc, @as(f32, @floatFromInt(g.stop_count)));
            var i: usize = 0;
            while (i < g.stop_count) : (i += 1) {
                try ir.appendSlice(alloc, &.{ g.stops[i].offset, @floatFromInt(g.stops[i].color.r), @floatFromInt(g.stops[i].color.g), @floatFromInt(g.stops[i].color.b), @floatFromInt(g.stops[i].color.a) });
            }
        },
        .paint_radial_gradient => |g| {
            try ir.append(alloc, icon_vector.op_paint_radial_gradient);
            try ir.append(alloc, @floatFromInt(@intFromEnum(g.coordinate_space)));
            try ir.append(alloc, @floatFromInt(@intFromEnum(g.spread)));
            try ir.appendSlice(alloc, &.{ g.cx, g.cy, g.radius, g.fx, g.fy, g.focal_radius });
            try ir.append(alloc, @as(f32, @floatFromInt(g.stop_count)));
            var i: usize = 0;
            while (i < g.stop_count) : (i += 1) {
                try ir.appendSlice(alloc, &.{ g.stops[i].offset, @floatFromInt(g.stops[i].color.r), @floatFromInt(g.stops[i].color.g), @floatFromInt(g.stops[i].color.b), @floatFromInt(g.stops[i].color.a) });
            }
        },
        .stroke_width => |w| try ir.appendSlice(alloc, &.{ icon_vector.op_stroke_width, w }),
        .stroke_cap => |c| try ir.appendSlice(alloc, &.{ icon_vector.op_stroke_cap, @floatFromInt(@intFromEnum(c)) }),
        .stroke_join => |j| try ir.appendSlice(alloc, &.{ icon_vector.op_stroke_join, @floatFromInt(@intFromEnum(j)) }),
        .stroke_miter_limit => |ml| try ir.appendSlice(alloc, &.{ icon_vector.op_stroke_miter_limit, ml }),
        .begin_clip_path => try ir.append(alloc, icon_vector.op_begin_clip_path),
        .end_clip_path => try ir.append(alloc, icon_vector.op_end_clip_path),
        .clear_clip_path => try ir.append(alloc, icon_vector.op_clear_clip_path),
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

fn lessThanByName(_: void, a: IconData, b: IconData) bool {
    return mem.lessThan(u8, a.name, b.name);
}

const IconData = struct {
    name: []const u8,
    tags: []const u8,
    category: []const u8,
    ir: []const f32,
};

fn emitAssetPack(dir: std.Io.Dir, io: std.Io, _: mem.Allocator, icons: []const IconData) !void {
    {
        dir.deleteFile(io, "icon_asset_pack_index.bin") catch {};
        var f = try dir.createFile(io, "icon_asset_pack_index.bin", .{ .truncate = true });
        defer f.close(io);
        var w = f.writer(io, &.{});

        const magic: u32 = 0x4E435849; // "IXCN" in little-endian file bytes
        try w.interface.writeInt(u32, magic, .little);
        try w.interface.writeInt(u32, @as(u32, @intCast(icons.len)), .little);

        var ir_offset: u32 = 0;
        for (icons) |ic| {
            const ir_len = @as(u32, @intCast(ic.ir.len * @sizeOf(f32)));
            try w.interface.writeInt(u32, ir_offset, .little);
            try w.interface.writeInt(u32, ir_len, .little);
            ir_offset += ir_len;
        }
        try w.interface.flush();
    }

    {
        dir.deleteFile(io, "icon_asset_pack_ir.bin") catch {};
        var f = try dir.createFile(io, "icon_asset_pack_ir.bin", .{ .truncate = true });
        defer f.close(io);
        var w = f.writer(io, &.{});

        for (icons) |ic| {
            const bytes = mem.sliceAsBytes(ic.ir);
            try w.interface.writeAll(bytes);
        }
        try w.interface.flush();
    }
}
