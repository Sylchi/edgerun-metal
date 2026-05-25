const std = @import("std");
const bytes = @import("bytes");
const object = @import("object");
const vfs = @import("vfs");

const output_file_permissions = std.Io.File.Permissions.default_file.setReadOnly(true);
const workspace_manifest_magic = "ERVFSWS1";
const workspace_manifest_version: u16 = 1;
const workspace_manifest_reserved: u16 = 0;
const workspace_manifest_header_bytes: usize = workspace_manifest_magic.len + 2 + 2 + 4;

const Mode = enum {
    file,
    workspace,
};

pub fn main(init: std.process.Init) !void {
    var args = std.process.Args.Iterator.init(init.minimal.args);
    defer args.deinit();

    _ = args.next();
    const mode_text = args.next() orelse return error.MissingMode;
    const mode = parseMode(mode_text) orelse return error.BadMode;
    const input_path = args.next() orelse return error.MissingInputPath;
    const output_path = args.next() orelse return error.MissingOutputPath;
    if (args.next() != null) return error.TooManyArguments;

    const bytes = switch (mode) {
        .file => try readFile(init.io, input_path),
        .workspace => try buildWorkspaceObject(init.io, input_path),
    };
    defer std.heap.page_allocator.free(bytes);
    try writeZigBytes(init.io, output_path, bytes);
}

fn parseMode(text: []const u8) ?Mode {
    if (std.mem.eql(u8, text, "file")) return .file;
    if (std.mem.eql(u8, text, "workspace")) return .workspace;
    return null;
}

fn readFile(io: std.Io, input_path: []const u8) ![]u8 {
    const cwd = std.Io.Dir.cwd();
    const input = try cwd.openFile(io, input_path, .{});
    defer input.close(io);
    const input_stat = try input.stat(io);
    const input_len: usize = @intCast(input_stat.size);
    var input_buffer: [4096]u8 = undefined;
    var reader = input.reader(io, &input_buffer);
    return try reader.interface.readAlloc(std.heap.page_allocator, input_len);
}

fn writeZigBytes(io: std.Io, output_path: []const u8, bytes: []const u8) !void {
    const cwd = std.Io.Dir.cwd();
    cwd.deleteFile(io, output_path) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };
    const output = try cwd.createFile(io, output_path, .{ .truncate = true });
    defer output.close(io);

    var buffer: [4096]u8 = undefined;
    var writer = output.writer(io, &buffer);
    try writer.interface.writeAll("pub const bytes = [_]u8{");
    for (bytes, 0..) |byte, index| {
        if (index % 16 == 0) try writer.interface.writeAll("\n    ");
        try writer.interface.print("0x{x:0>2}, ", .{byte});
    }
    try writer.interface.writeAll("\n};\n");
    try writer.interface.flush();
    try output.setPermissions(io, output_file_permissions);
}

fn buildWorkspaceObject(io: std.Io, root_path: []const u8) ![]u8 {
    const allocator = std.heap.page_allocator;
    var root = try std.Io.Dir.cwd().openDir(io, root_path, .{ .iterate = true });
    defer root.close(io);

    var paths: std.ArrayList([]u8) = .empty;
    defer {
        for (paths.items) |path| allocator.free(path);
        paths.deinit(allocator);
    }
    try collectSourcePaths(io, allocator, &root, "", &paths);
    std.mem.sort([]u8, paths.items, {}, pathLessThan);

    var manifest: std.ArrayList(u8) = .empty;
    defer manifest.deinit(allocator);
    try manifest.appendSlice(allocator, workspace_manifest_magic);
    try appendU16(&manifest, allocator, workspace_manifest_version);
    try appendU16(&manifest, allocator, workspace_manifest_reserved);
    try appendU32(&manifest, allocator, @intCast(paths.items.len));

    for (paths.items) |path| {
        const file_bytes = try readWorkspaceFile(io, allocator, &root, path);
        defer allocator.free(file_bytes);

        const file_raw = try allocator.alloc(u8, object.header_size + file_bytes.len);
        defer allocator.free(file_raw);
        const file_object = try (object.NodeWriter{ .out = file_raw }).bytesNode(sourceObjectRequirements(), sourceObjectEpoch(), file_bytes);
        const label_ref = try vfs.prepareObjectLabelRef(path, file_object);

        var label_ref_raw: [vfs.object_label_ref_bytes]u8 = undefined;
        try vfs.encodeObjectLabelRef(label_ref, &label_ref_raw);
        try manifest.appendSlice(allocator, &label_ref_raw);
        try manifest.appendSlice(allocator, file_object);
    }

    const raw = try allocator.alloc(u8, object.header_size + manifest.items.len);
    errdefer allocator.free(raw);
    const canonical = try (object.NodeWriter{ .out = raw }).bytesNode(sourceObjectRequirements(), sourceObjectEpoch(), manifest.items);
    return raw[0..canonical.len];
}

fn appendU16(out: *std.ArrayList(u8), allocator: std.mem.Allocator, value: u16) !void {
    var raw: [2]u8 = undefined;
    _ = bytes.store16(&raw, value);
    try out.appendSlice(allocator, &raw);
}

fn appendU32(out: *std.ArrayList(u8), allocator: std.mem.Allocator, value: u32) !void {
    var raw: [4]u8 = undefined;
    _ = bytes.store32(&raw, value);
    try out.appendSlice(allocator, &raw);
}

fn collectSourcePaths(io: std.Io, allocator: std.mem.Allocator, dir: *std.Io.Dir, prefix: []const u8, paths: *std.ArrayList([]u8)) !void {
    var iterator = dir.iterate();
    while (try iterator.next(io)) |entry| {
        const relative = try relativePath(allocator, prefix, entry.name);
        errdefer allocator.free(relative);
        switch (entry.kind) {
            .file => {
                if (sourceFileAllowed(relative)) {
                    try paths.append(allocator, relative);
                } else {
                    allocator.free(relative);
                }
            },
            .directory => {
                if (sourceDirectoryAllowed(relative)) {
                    var child = try dir.openDir(io, entry.name, .{ .iterate = true });
                    defer child.close(io);
                    try collectSourcePaths(io, allocator, &child, relative, paths);
                }
                allocator.free(relative);
            },
            else => allocator.free(relative),
        }
    }
}

fn relativePath(allocator: std.mem.Allocator, prefix: []const u8, name: []const u8) ![]u8 {
    if (prefix.len == 0) return try allocator.dupe(u8, name);
    return try std.fs.path.join(allocator, &.{ prefix, name });
}

fn sourceFileAllowed(path: []const u8) bool {
    if (std.mem.eql(u8, path, "build.zig")) return true;
    if (!std.mem.startsWith(u8, path, "src/")) return false;
    return std.mem.endsWith(u8, path, ".zig") or std.mem.endsWith(u8, path, ".md");
}

fn sourceDirectoryAllowed(path: []const u8) bool {
    if (std.mem.eql(u8, path, "src")) return true;
    if (!std.mem.startsWith(u8, path, "src/")) return false;
    return !std.mem.eql(u8, std.fs.path.basename(path), ".zig-cache");
}

fn readWorkspaceFile(io: std.Io, allocator: std.mem.Allocator, root: *std.Io.Dir, path: []const u8) ![]u8 {
    const file = try root.openFile(io, path, .{});
    defer file.close(io);
    const stat = try file.stat(io);
    const len: usize = @intCast(stat.size);
    var buffer: [4096]u8 = undefined;
    var reader = file.reader(io, &buffer);
    return try reader.interface.readAlloc(allocator, len);
}

fn pathLessThan(_: void, left: []const u8, right: []const u8) bool {
    return std.mem.order(u8, left, right) == .lt;
}

fn sourceObjectRequirements() object.Requirements {
    return .{
        .durability = .durable,
        .confidentiality = .public,
        .portability = .public_portable,
        .integrity = .hash_only,
        .lifetime = .retained,
        .visibility = .public,
        .access = .explicit_io,
    };
}

fn sourceObjectEpoch() @TypeOf(@as(object.Header, undefined).epoch) {
    return .{
        .keeper = .{ .bytes = [_]u8{
            0x65, 0x64, 0x67, 0x65, 0x72, 0x75, 0x6e, 0x3a,
            0x73, 0x6f, 0x75, 0x72, 0x63, 0x65, 0x3a, 0x6f,
            0x62, 0x6a, 0x65, 0x63, 0x74, 0x3a, 0x76, 0x31,
            0x3a, 0x62, 0x75, 0x69, 0x6c, 0x64, 0x00, 0x01,
        } },
    };
}

test "workspace manifest constants match encoded header width" {
    try std.testing.expectEqual(@as(usize, 16), workspace_manifest_header_bytes);
}
