const std = @import("std");
const varfont = @import("varfont.zig");
const font_vector = @import("font_vector.zig");
const object = @import("object.zig");
const clock = @import("clock.zig");

const geist_bytes = @embedFile("assets/Geist[wght].ttf");

pub fn main(init: std.process.Init) !void {
    const allocator = std.heap.page_allocator;
    const io = init.io;
    const face = try varfont.Face.init(geist_bytes);

    const cps = try collectCodepoints(allocator, &face);
    defer allocator.free(cps);

    const req = object.Requirements{
        .durability = .durable,
        .confidentiality = .public,
        .portability = .public_portable,
        .integrity = .hash_only,
        .lifetime = .retained,
        .visibility = .public,
        .access = .explicit_io,
    };
    const epoch = blk: {
        var k: clock.KeeperId = undefined;
        const stamp = "edgerun:font:builtin:v1\x00\x00\x00\x00\x00\x00\x00\x00\x00";
        @memcpy(k.bytes[0..stamp.len], stamp);
        break :blk clock.Stamp{ .keeper = k };
    };

    const weights = [_]struct { name: []const u8, wght: f32 }{
        .{ .name = "regular", .wght = 400.0 },
        .{ .name = "semibold", .wght = 600.0 },
        .{ .name = "bold", .wght = 700.0 },
    };

    const cwd = std.Io.Dir.cwd();

    inline for (weights) |w| {
        const ff = font_vector.FixedFace{
            .face = face,
            .axis_values = face.fixedAxisValues("wght", w.wght),
        };

        const counts = try font_vector.countCodepoints(ff, cps);

        const glyphs = try allocator.alloc(font_vector.GlyphRecord, counts.glyphs);
        defer allocator.free(glyphs);
        const kerns = try allocator.alloc(font_vector.KernRecord, counts.kerns);
        defer allocator.free(kerns);
        const commands = try allocator.alloc(font_vector.Command, counts.commands);
        defer allocator.free(commands);

        const body = try font_vector.compileCodepoints(ff, cps, glyphs, kerns, commands);

        const body_size = font_vector.serializedLen(counts.glyphs, counts.kerns, counts.commands).?;
        const body_buf = try allocator.alloc(u8, body_size);
        defer allocator.free(body_buf);
        const encoded_body = font_vector.encodeBody(body_buf, body).?;

        const obj_size = try object.canonicalSize(.bytes, encoded_body.len, 0, 0, 0);
        const obj_buf = try allocator.alloc(u8, obj_size);
        defer allocator.free(obj_buf);
        const canonical = try (object.NodeWriter{ .out = obj_buf }).bytesNode(req, epoch, encoded_body);

        const path = try std.fmt.allocPrint(allocator, "src/assets/font_{s}.obj", .{w.name});
        defer allocator.free(path);
        {
            var file_buf: [4096]u8 = undefined;
            cwd.deleteFile(io, path) catch {};
            var file = try cwd.createFile(io, path, .{ .truncate = true });
            defer file.close(io);
            var writer = file.writer(io, &file_buf);
            try writer.interface.writeAll(canonical);
            try writer.interface.flush();
        }

        std.debug.print("{s}: {d} glyphs, {d} kerns, {d} commands, {d} bytes\n", .{ w.name, counts.glyphs, counts.kerns, counts.commands, canonical.len });
    }

    std.debug.print("Generated {d} font objects with {d} codepoints\n", .{ weights.len, cps.len });
}

fn collectCodepoints(allocator: std.mem.Allocator, face: *const varfont.Face) ![]u21 {
    const count = countCoveredCodepoints(face);
    const cps = try allocator.alloc(u21, count);
    var index: usize = 0;
    switch (face.cmap_format) {
        4 => fillFormat4(face, cps, &index),
        12 => fillFormat12(face, cps, &index),
        else => return error.UnsupportedCmap,
    }
    if (index != count) return error.Inconsistent;
    return cps;
}

fn countCoveredCodepoints(face: *const varfont.Face) usize {
    return switch (face.cmap_format) {
        4 => countFormat4(face),
        12 => countFormat12(face),
        else => @panic("unsupported cmap format"),
    };
}

fn countFormat4(face: *const varfont.Face) usize {
    var count: usize = 0;
    const sub: usize = face.cmap_offset;
    const seg_count = varfont.readU16(face.data, sub + 6) / 2;
    const end_codes = sub + 14;
    const start_codes = end_codes + seg_count * 2 + 2;
    var i: usize = 0;
    while (i < seg_count) : (i += 1) {
        const start = varfont.readU16(face.data, start_codes + i * 2);
        const end = varfont.readU16(face.data, end_codes + i * 2);
        var raw: usize = start;
        while (raw <= end and raw <= std.math.maxInt(u21)) : (raw += 1) {
            const cp: u21 = @intCast(raw);
            if (isSurrogate(cp)) continue;
            if (face.glyphId(cp) == 0) continue;
            count += 1;
        }
    }
    return count;
}

fn fillFormat4(face: *const varfont.Face, out: []u21, index: *usize) void {
    const sub: usize = face.cmap_offset;
    const seg_count = varfont.readU16(face.data, sub + 6) / 2;
    const end_codes = sub + 14;
    const start_codes = end_codes + seg_count * 2 + 2;
    var i: usize = 0;
    while (i < seg_count) : (i += 1) {
        const start = varfont.readU16(face.data, start_codes + i * 2);
        const end = varfont.readU16(face.data, end_codes + i * 2);
        var raw: usize = start;
        while (raw <= end and raw <= std.math.maxInt(u21)) : (raw += 1) {
            const cp: u21 = @intCast(raw);
            if (isSurrogate(cp)) continue;
            if (face.glyphId(cp) == 0) continue;
            out[index.*] = cp;
            index.* += 1;
        }
    }
}

fn countFormat12(face: *const varfont.Face) usize {
    const group_count = varfont.readU32(face.data, face.cmap_offset + 12);
    var count: usize = 0;
    var gi: usize = 0;
    while (gi < group_count) : (gi += 1) {
        const group = face.cmap_offset + 16 + gi * 12;
        const start = varfont.readU32(face.data, group);
        const end = varfont.readU32(face.data, group + 4);
        var raw: usize = start;
        while (raw <= end and raw <= std.math.maxInt(u21)) : (raw += 1) {
            const cp: u21 = @intCast(raw);
            if (isSurrogate(cp)) continue;
            if (face.glyphId(cp) == 0) continue;
            count += 1;
        }
    }
    return count;
}

fn fillFormat12(face: *const varfont.Face, out: []u21, index: *usize) void {
    const group_count = varfont.readU32(face.data, face.cmap_offset + 12);
    var gi: usize = 0;
    while (gi < group_count) : (gi += 1) {
        const group = face.cmap_offset + 16 + gi * 12;
        const start = varfont.readU32(face.data, group);
        const end = varfont.readU32(face.data, group + 4);
        var raw: usize = start;
        while (raw <= end and raw <= std.math.maxInt(u21)) : (raw += 1) {
            const cp: u21 = @intCast(raw);
            if (isSurrogate(cp)) continue;
            if (face.glyphId(cp) == 0) continue;
            out[index.*] = cp;
            index.* += 1;
        }
    }
}

fn isSurrogate(cp: u21) bool {
    return cp >= 0xd800 and cp <= 0xdfff;
}
