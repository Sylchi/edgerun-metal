const std = @import("std");
const bytes_mod = @import("bytes.zig");
const object = @import("object.zig");
const vfs = @import("vfs.zig");

const output_file_permissions = std.Io.File.Permissions.default_file.setReadOnly(true);
const workspace_manifest_magic = "ERVFSWS1";
const workspace_manifest_version: u16 = 1;
const workspace_manifest_reserved: u16 = 0;
const workspace_manifest_header_bytes: usize = workspace_manifest_magic.len + 2 + 2 + 4;
const app_source_root = "src";
const embed_file_call = "@embedFile(\"";
const app_workspace_roots = [_][]const u8{
    "src/er/self_host/main.er",
    "src/app_runtime.zig",
    "src/media/root.zig",
    "src/media/image.zig",
    "src/media/video.zig",
    "src/media/audio.zig",
};

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
    var output_path = args.next() orelse return error.MissingOutputPath;
    if (args.next() != null) return error.TooManyArguments;

    const embedded_bytes = switch (mode) {
        .file => try readFile(init.io, input_path),
        .workspace => try buildWorkspaceObject(init.io, input_path),
    };
    defer std.heap.page_allocator.free(embedded_bytes);
    try writeZigBytes(init.io, output_path, embedded_bytes);
}

fn parseMode(text: []const u8) ?Mode {
    if (bytes_mod.eql(text, "file")) return .file;
    if (bytes_mod.eql(text, "workspace")) return .workspace;
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

fn writeZigBytes(io: std.Io, output_path: []const u8, embedded_bytes: []const u8) !void {
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
    for (embedded_bytes, 0..) |byte, index| {
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
    // TODO: pruneSourcePathsToAppClosure segfaults on the Zig compiler std lib
    // ZIR parsing (optimizer bug or stack corruption). Skip until the self-host
    // compiler replaces the Zig toolchain path entirely.
    //try pruneSourcePathsToAppClosure(io, allocator, &root, &paths);

    var manifest: std.ArrayList(u8) = .empty;
    defer manifest.deinit(allocator);
    try manifest.appendSlice(allocator, workspace_manifest_magic);
    try appendU16(&manifest, allocator, workspace_manifest_version);
    try appendU16(&manifest, allocator, workspace_manifest_reserved);
    try appendU32(&manifest, allocator, @intCast(paths.items.len));

    for (paths.items) |path| {
        const file_bytes = try readWorkspaceFile(io, allocator, &root, path);
        defer allocator.free(file_bytes);

        try appendWorkspaceFile(allocator, &manifest, path, file_bytes);
    }

    const raw = try allocator.alloc(u8, object.header_size + manifest.items.len);
    errdefer allocator.free(raw);
    const canonical = try (object.NodeWriter{ .out = raw }).bytesNode(sourceObjectRequirements(), sourceObjectEpoch(), manifest.items);
    return raw[0..canonical.len];
}

fn appendWorkspaceFile(allocator: std.mem.Allocator, manifest: *std.ArrayList(u8), label: []const u8, file_bytes: []const u8) !void {
    const file_raw = try allocator.alloc(u8, object.header_size + file_bytes.len);
    defer allocator.free(file_raw);
    const file_object = try (object.NodeWriter{ .out = file_raw }).bytesNode(sourceObjectRequirements(), sourceObjectEpoch(), file_bytes);
    const label_ref = try vfs.prepareObjectLabelRef(label, file_object);

    var label_ref_raw: [vfs.object_label_ref_bytes]u8 = undefined;
    try vfs.encodeObjectLabelRef(label_ref, &label_ref_raw);
    try manifest.appendSlice(allocator, &label_ref_raw);
    try manifest.appendSlice(allocator, file_object);
}

fn appendU16(out: *std.ArrayList(u8), allocator: std.mem.Allocator, value: u16) !void {
    var raw: [2]u8 = undefined;
    std.mem.writeInt(u16, &raw, value, .little);
    try out.appendSlice(allocator, &raw);
}

fn appendU32(out: *std.ArrayList(u8), allocator: std.mem.Allocator, value: u32) !void {
    var raw: [4]u8 = undefined;
    std.mem.writeInt(u32, &raw, value, .little);
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

fn pruneSourcePathsToAppClosure(io: std.Io, allocator: std.mem.Allocator, root: *std.Io.Dir, paths: *std.ArrayList([]u8)) !void {
    var reachable: std.StringHashMap(void) = .init(allocator);
    defer reachable.deinit();
    var queue: std.ArrayList([]u8) = .empty;
    defer {
        for (queue.items) |label| allocator.free(label);
        queue.deinit(allocator);
    }

    for (app_workspace_roots) |root_label| {
        if (findSourcePath(paths.items, root_label) == null) return error.MissingAppWorkspaceRoot;
        try enqueueReachable(allocator, &reachable, &queue, root_label);
    }

    var queue_index: usize = 0;
    while (queue_index < queue.items.len) : (queue_index += 1) {
        const importer = queue.items[queue_index];
        const source = try readWorkspaceFile(io, allocator, root, importer);
        defer allocator.free(source);
        if (bytes_mod.endsWith(importer, ".zig")) {
            try enqueueImportedSourcePaths(allocator, paths.items, importer, source, &reachable, &queue);
            try enqueueEmbeddedSourcePaths(allocator, paths.items, importer, source, &reachable, &queue);
        } else if (bytes_mod.endsWith(importer, ".er")) {
            try enqueueEdgeRunImportedSourcePaths(allocator, paths.items, importer, source, &reachable, &queue);
        }
    }

    var write_index: usize = 0;
    for (paths.items) |path| {
        if (reachable.contains(path)) {
            paths.items[write_index] = path;
            write_index += 1;
        } else {
            allocator.free(path);
        }
    }
    paths.shrinkRetainingCapacity(write_index);
}

fn enqueueEdgeRunImportedSourcePaths(
    allocator: std.mem.Allocator,
    paths: []const []u8,
    importer: []const u8,
    source: []const u8,
    reachable: *std.StringHashMap(void),
    queue: *std.ArrayList([]u8),
) !void {
    const import_call = "@import(\"";
    var index: usize = 0;
    while (std.mem.indexOfPos(u8, source, index, import_call)) |call_index| {
        const name_start = call_index + import_call.len;
        const name_end = std.mem.indexOfScalarPos(u8, source, name_start, '"') orelse return error.BadWorkspaceImport;
        const import_name = source[name_start..name_end];
        var resolved_buffer: [vfs.label_max]u8 = undefined;
        const resolved = resolveEdgeRunImportLabel(importer, import_name, &resolved_buffer) orelse return error.BadWorkspaceImport;
        if (!bytes_mod.endsWith(resolved, ".er")) return error.BadWorkspaceImport;
        if (findSourcePath(paths, resolved) == null) return error.MissingWorkspaceImport;
        try enqueueReachable(allocator, reachable, queue, resolved);
        index = name_end + 1;
    }
}

fn resolveEdgeRunImportLabel(importer_label: []const u8, import_name: []const u8, out: *[vfs.label_max]u8) ?[]const u8 {
    if (bytes_mod.startsWith(import_name, "src/")) return normalizeLabel(import_name, out);
    return resolveImportLabel(importer_label, import_name, out);
}

fn enqueueImportedSourcePaths(
    allocator: std.mem.Allocator,
    paths: []const []u8,
    importer: []const u8,
    source: []const u8,
    reachable: *std.StringHashMap(void),
    queue: *std.ArrayList([]u8),
) !void {
    const sentinel_source = try allocator.dupeZ(u8, source);
    defer allocator.free(sentinel_source);
    var tree = try std.zig.Ast.parse(allocator, sentinel_source, .zig);
    defer tree.deinit(allocator);
    if (tree.errors.len != 0) return error.InvalidWorkspaceZigSource;
    var zir = try std.zig.AstGen.generate(allocator, tree);
    defer zir.deinit(allocator);
    if (zir.hasCompileErrors()) return error.InvalidWorkspaceZigSource;

    const imports_index = zir.extra[@intFromEnum(std.zig.Zir.ExtraIndex.imports)];
    if (imports_index == 0) return;
    const extra = zir.extraData(std.zig.Zir.Inst.Imports, imports_index);
    var extra_index = extra.end;
    var remaining = extra.data.imports_len;
    while (remaining > 0) : (remaining -= 1) {
        const item = zir.extraData(std.zig.Zir.Inst.Imports.Item, extra_index);
        extra_index = item.end;
        const import_name = zir.nullTerminatedString(item.data.name);
        if (virtualImport(import_name)) continue;
        var resolved_buffer: [vfs.label_max]u8 = undefined;
        const resolved = resolveImportLabel(importer, import_name, &resolved_buffer) orelse return error.BadWorkspaceImport;
        if (findSourcePath(paths, resolved) == null) {
            if (sourceFileAllowed(resolved)) return error.MissingWorkspaceImport;
            continue;
        }
        try enqueueReachable(allocator, reachable, queue, resolved);
    }
}

fn enqueueEmbeddedSourcePaths(
    allocator: std.mem.Allocator,
    paths: []const []u8,
    importer: []const u8,
    source: []const u8,
    reachable: *std.StringHashMap(void),
    queue: *std.ArrayList([]u8),
) !void {
    var index: usize = 0;
    while (std.mem.indexOfPos(u8, source, index, embed_file_call)) |call_index| {
        const name_start = call_index + embed_file_call.len;
        const name_end = std.mem.indexOfScalarPos(u8, source, name_start, '"') orelse return error.BadWorkspaceEmbedFile;
        const embed_name = source[name_start..name_end];
        var resolved_buffer: [vfs.label_max]u8 = undefined;
        const resolved = resolveImportLabel(importer, embed_name, &resolved_buffer) orelse return error.BadWorkspaceEmbedFile;
        if (findSourcePath(paths, resolved) != null) {
            try enqueueReachable(allocator, reachable, queue, resolved);
        } else if (sourceFileAllowed(resolved)) {
            return error.MissingWorkspaceEmbedFile;
        }
        index = name_end + 1;
    }
}

fn enqueueReachable(
    allocator: std.mem.Allocator,
    reachable: *std.StringHashMap(void),
    queue: *std.ArrayList([]u8),
    label: []const u8,
) !void {
    if (reachable.contains(label)) return;
    const owned = try allocator.dupe(u8, label);
    errdefer allocator.free(owned);
    try reachable.put(owned, {});
    try queue.append(allocator, owned);
}

fn findSourcePath(paths: []const []u8, label: []const u8) ?[]u8 {
    var low: usize = 0;
    var high: usize = paths.len;
    while (low < high) {
        const mid = low + (high - low) / 2;
        switch (bytes_mod.order(paths[mid], label)) {
            0 => return paths[mid],
            -1 => low = mid + 1,
            1 => high = mid,
            -2 => unreachable,
        }
    }
    return null;
}

fn virtualImport(import_name: []const u8) bool {
    return bytes_mod.eql(import_name, "builtin") or
        bytes_mod.eql(import_name, "build_options") or
        bytes_mod.eql(import_name, "embedded_source_object") or
        bytes_mod.eql(import_name, "embedded_wasm_compiler");
}

fn resolveImportLabel(importer_label: []const u8, import_name: []const u8, out: *[vfs.label_max]u8) ?[]const u8 {
    if (bytes_mod.eql(import_name, "std")) return null;
    if (bytes_mod.eql(import_name, "root")) return copyResolved(out, importer_label);
    if (import_name.len == 0 or import_name.len > vfs.label_max) return null;
    if (bytes_mod.startsWith(import_name, "/")) return null;

    var raw: [vfs.label_max]u8 = undefined;
    var raw_len: usize = 0;
    if (std.mem.lastIndexOfScalar(u8, importer_label, '/')) |slash| {
        const prefix = importer_label[0 .. slash + 1];
        if (prefix.len > raw.len) return null;
        @memcpy(raw[0..prefix.len], prefix);
        raw_len = prefix.len;
    }
    if (import_name.len > raw.len - raw_len) return null;
    @memcpy(raw[raw_len .. raw_len + import_name.len], import_name);
    raw_len += import_name.len;
    return normalizeLabel(raw[0..raw_len], out);
}

fn normalizeLabel(raw: []const u8, out: *[vfs.label_max]u8) ?[]const u8 {
    var len: usize = 0;
    var index: usize = 0;
    while (index <= raw.len) {
        const start = index;
        while (index < raw.len and raw[index] != '/') : (index += 1) {}
        const part = raw[start..index];
        if (part.len == 0 or bytes_mod.eql(part, ".")) {
            // Skip empty and current-directory path segments.
        } else if (bytes_mod.eql(part, "..")) {
            if (len == 0) return null;
            len -= 1;
            while (len > 0 and out[len - 1] != '/') : (len -= 1) {}
            if (len > 0 and out[len - 1] == '/') len -= 1;
        } else {
            if (len != 0) {
                if (len >= out.len) return null;
                out[len] = '/';
                len += 1;
            }
            if (part.len > out.len - len) return null;
            @memcpy(out[len .. len + part.len], part);
            len += part.len;
        }
        if (index == raw.len) break;
        index += 1;
    }
    if (len == 0) return null;
    return out[0..len];
}

fn copyResolved(out: *[vfs.label_max]u8, value: []const u8) ?[]const u8 {
    if (value.len > out.len) return null;
    @memcpy(out[0..value.len], value);
    return out[0..value.len];
}

fn relativePath(allocator: std.mem.Allocator, prefix: []const u8, name: []const u8) ![]u8 {
    if (prefix.len == 0) return try allocator.dupe(u8, name);
    return try std.fs.path.join(allocator, &.{ prefix, name });
}

fn sourceFileAllowed(path: []const u8) bool {
    if (bytes_mod.eql(path, "build.zig")) return true;
    if (bytes_mod.startsWith(path, "src/")) return appSourceFileAllowed(path);
    return false;
}

fn sourceDirectoryAllowed(path: []const u8) bool {
    if (bytes_mod.eql(path, app_source_root)) return true;
    if (bytes_mod.startsWith(path, "src/")) return !bytes_mod.eql(std.fs.path.basename(path), ".zig-cache");
    return false;
}

fn sourceExtensionAllowed(path: []const u8) bool {
    return bytes_mod.endsWith(path, ".zig") or bytes_mod.endsWith(path, ".er") or bytes_mod.endsWith(path, ".md");
}

fn appSourceFileAllowed(path: []const u8) bool {
    if (!sourceExtensionAllowed(path)) return false;
    if (bytes_mod.endsWith(path, "_test.zig")) return false;
    if (bytes_mod.endsWith(path, "_tests.zig")) return false;
    if (bytes_mod.endsWith(path, "/tests.zig")) return false;
    if (bytes_mod.endsWith(path, "/test.zig")) return false;

    if (bytes_mod.startsWith(path, "src/pi_")) return false;
    if (bytes_mod.startsWith(path, "src/pi_zero_")) return false;
    if (bytes_mod.startsWith(path, "src/render/backends/gles")) return false;
    if (bytes_mod.startsWith(path, "src/render/backends/gpu")) return false;

    return true;
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
    return bytes_mod.order(left, right) == -1;
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

test "workspace source filter keeps EdgeRun app roots" {
    try std.testing.expect(sourceFileAllowed("src/er/self_host/main.er"));
    try std.testing.expect(sourceFileAllowed("src/app_runtime.zig"));
    try std.testing.expect(sourceFileAllowed("src/blog/one.md"));
    try std.testing.expect(sourceFileAllowed("src/media/video.zig"));
    try std.testing.expect(sourceFileAllowed("src/media/video_webm.zig"));
}

test "workspace source closure follows EdgeRun typed imports" {
    const allocator = std.testing.allocator;
    var paths = [_][]u8{
        try allocator.dupe(u8, "src/er/self_host/helper.er"),
        try allocator.dupe(u8, "src/er/self_host/math.er"),
    };
    defer {
        for (paths) |path| allocator.free(path);
    }
    var reachable: std.StringHashMap(void) = .init(allocator);
    defer reachable.deinit();
    var queue: std.ArrayList([]u8) = .empty;
    defer {
        for (queue.items) |label| allocator.free(label);
        queue.deinit(allocator);
    }

    try enqueueEdgeRunImportedSourcePaths(
        allocator,
        &paths,
        "src/er/self_host/main.er",
        "const helper: module = @import(\"src/er/self_host/helper.er\");",
        &reachable,
        &queue,
    );
    try std.testing.expect(reachable.contains("src/er/self_host/helper.er"));
    try std.testing.expectEqual(@as(usize, 1), queue.items.len);
    try std.testing.expectEqualStrings("src/er/self_host/helper.er", queue.items[0]);
}

test "workspace source closure accepts absolute EdgeRun labels" {
    var out: [vfs.label_max]u8 = undefined;
    const resolved = resolveEdgeRunImportLabel(
        "src/er/self_host/main.er",
        "src/er/self_host/helper.er",
        &out,
    ).?;
    try std.testing.expectEqualStrings("src/er/self_host/helper.er", resolved);
}

test "workspace source filter removes app host tools and tests" {
    try std.testing.expect(!sourceFileAllowed("src/wasm/tests.zig"));
    try std.testing.expect(!sourceFileAllowed("src/media/video_tests.zig"));
    try std.testing.expect(!sourceFileAllowed("src/ui_core_test.zig"));
    try std.testing.expect(!sourceFileAllowed("src/wasm_compiler_probe.zig"));
    try std.testing.expect(!sourceFileAllowed("src/wasm_compiler_runner_test.zig"));
    try std.testing.expect(!sourceFileAllowed("src/wayland_window_host.zig"));
    try std.testing.expect(!sourceFileAllowed("src/wayland_egl_host.zig"));
    try std.testing.expect(!sourceFileAllowed("src/render/native_present.zig"));
    try std.testing.expect(!sourceFileAllowed("src/pi_zero_w_v1_1.zig"));
}
