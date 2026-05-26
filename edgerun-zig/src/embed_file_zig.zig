const std = @import("std");
const object = @import("object.zig");
const vfs = @import("vfs.zig");

const output_file_permissions = std.Io.File.Permissions.default_file.setReadOnly(true);
const workspace_manifest_magic = "ERVFSWS1";
const workspace_manifest_version: u16 = 1;
const workspace_manifest_reserved: u16 = 0;
const workspace_manifest_header_bytes: usize = workspace_manifest_magic.len + 2 + 2 + 4;
const app_source_root = "src";
const compiler_root = "compiler";
const compiler_zig_root = "compiler/zig";
const compiler_zig_src_root = "compiler/zig/src";
const compiler_zig_src_codegen_root = "compiler/zig/src/codegen";
const compiler_zig_src_codegen_wasm_root = "compiler/zig/src/codegen/wasm";
const compiler_zig_src_link_root = "compiler/zig/src/link";
const compiler_zig_src_link_wasm_root = "compiler/zig/src/link/Wasm";
const compiler_zig_lib_root = "compiler/zig/lib";
const compiler_zig_std_root = "compiler/zig/lib/std";
const compiler_zig_std_crypto_root = "compiler/zig/lib/std/crypto";
const compiler_zig_std_io_root = "compiler/zig/lib/std/Io";
const compiler_zig_std_os_root = "compiler/zig/lib/std/os";
const compiler_zig_std_zig_llvm_root = "compiler/zig/lib/std/zig/llvm";
const compiler_zig_compiler_lib_root = "compiler/zig/lib/compiler";

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

    const embedded_bytes = switch (mode) {
        .file => try readFile(init.io, input_path),
        .workspace => try buildWorkspaceObject(init.io, input_path),
    };
    defer std.heap.page_allocator.free(embedded_bytes);
    try writeZigBytes(init.io, output_path, embedded_bytes);
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

fn relativePath(allocator: std.mem.Allocator, prefix: []const u8, name: []const u8) ![]u8 {
    if (prefix.len == 0) return try allocator.dupe(u8, name);
    return try std.fs.path.join(allocator, &.{ prefix, name });
}

fn sourceFileAllowed(path: []const u8) bool {
    if (std.mem.eql(u8, path, "build.zig")) return true;
    if (std.mem.eql(u8, path, "compiler/zig/build.zig")) return true;
    if (std.mem.eql(u8, path, "compiler/zig/build.zig.zon")) return true;
    if (std.mem.startsWith(u8, path, "src/")) return sourceExtensionAllowed(path);
    if (std.mem.startsWith(u8, path, "compiler/zig/src/")) return compilerSrcFileAllowed(path);
    if (std.mem.startsWith(u8, path, "compiler/zig/lib/std/")) return compilerStdFileAllowed(path);
    if (std.mem.startsWith(u8, path, "compiler/zig/lib/compiler/")) return compilerLibFileAllowed(path);
    if (std.mem.startsWith(u8, path, "compiler/zig/lib/") and std.mem.eql(u8, std.fs.path.dirname(path) orelse "", "compiler/zig/lib")) return compilerExtensionAllowed(path);
    return false;
}

fn sourceDirectoryAllowed(path: []const u8) bool {
    if (std.mem.eql(u8, path, app_source_root)) return true;
    if (std.mem.startsWith(u8, path, "src/")) return !std.mem.eql(u8, std.fs.path.basename(path), ".zig-cache");
    if (std.mem.eql(u8, path, compiler_root)) return true;
    if (std.mem.eql(u8, path, compiler_zig_root)) return true;
    if (std.mem.eql(u8, path, compiler_zig_src_root)) return true;
    if (std.mem.startsWith(u8, path, "compiler/zig/src/")) return compilerSrcDirectoryAllowed(path);
    if (std.mem.eql(u8, path, compiler_zig_lib_root)) return true;
    if (std.mem.eql(u8, path, compiler_zig_std_root)) return true;
    if (std.mem.startsWith(u8, path, "compiler/zig/lib/std/")) return compilerStdDirectoryAllowed(path);
    if (std.mem.eql(u8, path, compiler_zig_compiler_lib_root)) return true;
    if (std.mem.startsWith(u8, path, "compiler/zig/lib/compiler/")) return compilerLibDirectoryAllowed(path);
    return false;
}

fn sourceExtensionAllowed(path: []const u8) bool {
    return std.mem.endsWith(u8, path, ".zig") or std.mem.endsWith(u8, path, ".md");
}

fn compilerExtensionAllowed(path: []const u8) bool {
    return std.mem.endsWith(u8, path, ".zig") or
        std.mem.endsWith(u8, path, ".zon") or
        std.mem.endsWith(u8, path, ".h") or
        std.mem.endsWith(u8, path, ".c");
}

fn compilerSrcFileAllowed(path: []const u8) bool {
    if (!compilerExtensionAllowed(path)) return false;
    if (std.mem.startsWith(u8, path, "compiler/zig/src/codegen/")) return std.mem.startsWith(u8, path, "compiler/zig/src/codegen/wasm/");
    if (std.mem.startsWith(u8, path, "compiler/zig/src/link/")) return std.mem.eql(u8, path, "compiler/zig/src/link/Wasm.zig") or
        std.mem.startsWith(u8, path, "compiler/zig/src/link/Wasm/");
    return true;
}

fn compilerSrcDirectoryAllowed(path: []const u8) bool {
    if (std.mem.eql(u8, std.fs.path.basename(path), ".zig-cache")) return false;
    if (std.mem.eql(u8, path, compiler_zig_src_codegen_root)) return true;
    if (std.mem.startsWith(u8, path, "compiler/zig/src/codegen/")) return std.mem.eql(u8, path, compiler_zig_src_codegen_wasm_root) or
        std.mem.startsWith(u8, path, "compiler/zig/src/codegen/wasm/");
    if (std.mem.eql(u8, path, compiler_zig_src_link_root)) return true;
    if (std.mem.startsWith(u8, path, "compiler/zig/src/link/")) return std.mem.eql(u8, path, compiler_zig_src_link_wasm_root) or
        std.mem.startsWith(u8, path, "compiler/zig/src/link/Wasm/");
    return true;
}

fn compilerStdFileAllowed(path: []const u8) bool {
    if (std.mem.endsWith(u8, path, "_test.zig")) return false;
    if (std.mem.startsWith(u8, path, "compiler/zig/lib/std/crypto/")) return false;
    if (std.mem.eql(u8, path, "compiler/zig/lib/std/Io/Threaded.zig")) return false;
    if (std.mem.eql(u8, path, "compiler/zig/lib/std/Io/Uring.zig")) return false;
    if (std.mem.startsWith(u8, path, "compiler/zig/lib/std/os/")) return false;
    if (std.mem.startsWith(u8, path, "compiler/zig/lib/std/zig/llvm/")) return false;
    return compilerExtensionAllowed(path);
}

fn compilerStdDirectoryAllowed(path: []const u8) bool {
    if (std.mem.eql(u8, std.fs.path.basename(path), ".zig-cache")) return false;
    if (std.mem.eql(u8, path, compiler_zig_std_crypto_root) or std.mem.startsWith(u8, path, "compiler/zig/lib/std/crypto/")) return false;
    if (std.mem.eql(u8, path, compiler_zig_std_os_root) or std.mem.startsWith(u8, path, "compiler/zig/lib/std/os/")) return false;
    if (std.mem.eql(u8, path, compiler_zig_std_zig_llvm_root) or std.mem.startsWith(u8, path, "compiler/zig/lib/std/zig/llvm/")) return false;
    if (std.mem.eql(u8, path, compiler_zig_std_io_root)) return true;
    return true;
}

fn compilerLibFileAllowed(path: []const u8) bool {
    if (std.mem.startsWith(u8, path, "compiler/zig/lib/compiler/aro/")) return false;
    if (std.mem.startsWith(u8, path, "compiler/zig/lib/compiler/translate-c/")) return false;
    return compilerExtensionAllowed(path);
}

fn compilerLibDirectoryAllowed(path: []const u8) bool {
    if (std.mem.eql(u8, std.fs.path.basename(path), ".zig-cache")) return false;
    if (std.mem.eql(u8, path, "compiler/zig/lib/compiler/aro")) return false;
    if (std.mem.startsWith(u8, path, "compiler/zig/lib/compiler/aro/")) return false;
    if (std.mem.eql(u8, path, "compiler/zig/lib/compiler/translate-c")) return false;
    if (std.mem.startsWith(u8, path, "compiler/zig/lib/compiler/translate-c/")) return false;
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
