const std = @import("std");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const args = try std.process.argsAllocator(allocator);
    if (args.len < 4) {
        std.debug.print("usage: {s} <svg-dir> <output-icon-zig> <output-embed-zig>\n", .{args[0]});
        std.process.exit(1);
    }

    const svg_dir_path = args[1];
    const icon_zig_path = args[2];
    const embed_zig_path = args[3];

    var dir = try std.fs.openIterableDirAbsolute(svg_dir_path, .{});
    defer dir.close();

    var entries = std.ArrayList([]const u8).init(allocator);

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind != .file) continue;
        const name = entry.name;
        if (!std.mem.endsWith(u8, name, ".svg")) continue;
        try entries.append(try allocator.dupe(u8, name[0 .. name.len - 4]));
    }

    std.mem.sort([]const u8, entries.items, {}, struct {
        fn lessThan(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.lessThan);

    const count = entries.items.len;

    // Generate icon.zig
    {
        const file = try std.fs.createFileAbsolute(icon_zig_path, .{});
        defer file.close();
        const w = file.writer();

        try w.writeAll(
            \\const std = @import("std");
            \\
            \\// zig fmt: off
            \\pub const Icon = enum(u16) {
            \\
        );

        for (entries.items, 0..) |name, i| {
            const comma = if (i < count - 1) "," else "";
            try w.print("    {s}{s}\n", .{ try zigVariant(allocator, name), comma });
        }

        try w.writeAll(
            \\};
            \\// zig fmt: on
            \\
            \\pub const Provider = enum {
            \\    lucide,
            \\    tabler,
            \\};
            \\
            \\pub fn tablerName(value: Icon) []const u8 {
            \\    return switch (value) {
            \\
        );
        for (entries.items) |name| {
            try w.print("        .{s} => \"{s}\",\n", .{ try zigVariant(allocator, name), name });
        }
        try w.writeAll(
            \\    };
            \\}
            \\
            \\pub fn label(value: Icon) []const u8 {
            \\    return tablerName(value);
            \\}
            \\
            \\pub fn id(value: Icon) u32 {
            \\    return @as(u32, @intFromEnum(value)) + 1;
            \\}
            \\
            \\pub fn fromId(icon_id: u32) ?Icon {
            \\    if (icon_id == 0 or icon_id > @typeInfo(Icon).@"enum".fields.len) return null;
            \\    return @enumFromInt(icon_id - 1);
            \\}
            \\
            \\pub fn providerName(value: Icon, provider: Provider) []const u8 {
            \\    _ = provider;
            \\    return tablerName(value);
            \\}
            \\
            \\test "icon ids are stable and one based" {
            \\    const count = @typeInfo(Icon).@"enum".fields.len;
            \\    try std.testing.expectEqual(@as(u32, 1), id(@enumFromInt(0)));
            \\    try std.testing.expectEqual(@as(u32, @intCast(count)), id(@enumFromInt(count - 1)));
            \\    try std.testing.expect(id(@enumFromInt(0)) > 0);
            \\    try std.testing.expect(fromId(0) == null);
            \\    try std.testing.expect(fromId(@as(u32, @intCast(count + 1))) == null);
            \\}
            \\
            \\test "every icon has a label" {
            \\    inline for (std.meta.fields(Icon)) |field| {
            \\        const value: Icon = @enumFromInt(field.value);
            \\        try std.testing.expect(label(value).len > 0);
            \\    }
            \\}
            \\
        );
    }

    // Generate embed file
    {
        const file = try std.fs.createFileAbsolute(embed_zig_path, .{});
        defer file.close();
        const w = file.writer();

        try w.writeAll(
            \\const icon = @import("icon.zig");
            \\
            \\pub fn source(value: icon.Icon) []const u8 {
            \\    return switch (value) {
            \\
        );

        for (entries.items) |name| {
            try w.print("        .{s} => @embedFile(\"icons/tabler/{s}.svg\"),\n", .{ try zigVariant(allocator, name), name });
        }

        try w.writeAll(
            \\    };
            \\}
            \\
        );
    }
}

fn zigVariant(allocator: std.mem.Allocator, name: []const u8) ![]const u8 {
    var result = std.ArrayList(u8).init(allocator);
    var i: usize = 0;

    if (name.len > 0 and name[0] >= '0' and name[0] <= '9') {
        try result.append('_');
    }

    while (i < name.len) : (i += 1) {
        const c = name[i];
        switch (c) {
            '-' => try result.append('_'),
            '0'...'9', 'a'...'z', 'A'...'Z', '_' => try result.append(c),
            else => try result.append('_'),
        }
    }

    return result.items;
}
