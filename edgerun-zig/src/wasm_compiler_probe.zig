const std = @import("std");
const bytes = @import("bytes.zig");
const object = @import("object.zig");
const source_object = @import("embedded_source_object").bytes;
const vfs = @import("vfs.zig");
const wasm = @import("wasm/root.zig");
const wasm_compiler = @import("embedded_wasm_compiler").bytes;

const source_gap_bytes: usize = 64 * 1024;
const compiler_memory_offset: usize = 16 * 1024 * 1024;
const compiler_memory_extra_bytes: usize = 256 * 1024 * 1024;
const execution_tick_budget: u64 = 16_000_000_000;
const wasm_page_bytes: usize = 64 * 1024;
const default_root_label = "src/root.zig";
const workspace_magic = "ERVFSWS1";
const workspace_header_bytes: usize = 16;
const top_file_count: usize = 16;
const graph_max_files: usize = 1024;
const unresolved_sample_count: usize = 8;
const host_graph_only_arg = "--host-graph";

const FileStat = struct {
    label: [vfs.label_max]u8 = [_]u8{0} ** vfs.label_max,
    label_len: usize = 0,
    body_bytes: usize = 0,

    fn init(label: []const u8, body_bytes: usize) FileStat {
        var file: FileStat = .{ .label_len = label.len, .body_bytes = body_bytes };
        @memcpy(file.label[0..label.len], label);
        return file;
    }

    fn labelSlice(file: *const FileStat) []const u8 {
        return file.label[0..file.label_len];
    }
};

const VfsStats = struct {
    file_count: u32,
    manifest_bytes: usize,
    canonical_file_object_bytes: usize,
    source_body_bytes: usize,
    app_file_count: usize,
    app_source_body_bytes: usize,
    compiler_file_count: usize,
    compiler_source_body_bytes: usize,
    compiler_src_file_count: usize,
    compiler_src_body_bytes: usize,
    compiler_codegen_file_count: usize,
    compiler_codegen_body_bytes: usize,
    compiler_link_file_count: usize,
    compiler_link_body_bytes: usize,
    std_file_count: usize,
    std_source_body_bytes: usize,
    std_test_file_count: usize,
    std_test_body_bytes: usize,
    root_source_bytes: usize,
    top_files: [top_file_count]FileStat,
};

const Label = struct {
    bytes: [vfs.label_max]u8 = [_]u8{0} ** vfs.label_max,
    len: usize = 0,

    fn init(value: []const u8) Label {
        var label: Label = .{ .len = value.len };
        @memcpy(label.bytes[0..value.len], value);
        return label;
    }

    fn slice(label: *const Label) []const u8 {
        return label.bytes[0..label.len];
    }
};

const HostFileEntry = struct {
    label: Label,
    body: []const u8,
};

const UnresolvedImport = struct {
    importer: Label = .{},
    import_name: Label = .{},
    resolved: Label = .{},
};

const GraphStats = struct {
    analyzed_file_count: usize = 0,
    import_edge_count: usize = 0,
    unresolved_import_count: usize = 0,
    truncated_import_count: usize = 0,
    samples: [unresolved_sample_count]UnresolvedImport = [_]UnresolvedImport{.{}} ** unresolved_sample_count,

    fn recordUnresolved(stats: *GraphStats, importer: []const u8, import_name: []const u8, resolved: ?[]const u8) void {
        const index = stats.unresolved_import_count;
        stats.unresolved_import_count += 1;
        if (index >= stats.samples.len) return;
        stats.samples[index] = .{
            .importer = Label.init(importer),
            .import_name = Label.init(import_name),
            .resolved = if (resolved) |label| Label.init(label) else .{},
        };
    }
};

pub fn main(init: std.process.Init) !void {
    var args = std.process.Args.Iterator.init(init.minimal.args);
    defer args.deinit();

    _ = args.next();
    var host_graph_only = false;
    var root_label = args.next() orelse default_root_label;
    if (std.mem.eql(u8, root_label, host_graph_only_arg)) {
        host_graph_only = true;
        root_label = args.next() orelse default_root_label;
    }
    if (args.next() != null) return error.TooManyArguments;

    const source_bytes = source_object[0..];
    const compiler_memory_len = alignForward(source_bytes.len + compiler_memory_extra_bytes, 16);
    const source_offset = compiler_memory_offset + compiler_memory_len;
    const root_label_offset = source_offset + source_bytes.len;
    const requested_memory_len = root_label_offset + root_label.len + source_gap_bytes;
    const memory_pages = pagesForBytes(requested_memory_len);
    const memory_len = memory_pages * wasm_page_bytes;

    const vfs_stats = try inspectVfs(source_bytes, root_label);
    const graph_stats = try inspectImportGraph(source_bytes, root_label);
    if (host_graph_only) {
        printHostGraph(root_label, source_bytes, vfs_stats, graph_stats);
        return;
    }

    const allocator = std.heap.page_allocator;
    const memory = try allocator.alloc(u8, memory_len);
    defer allocator.free(memory);
    @memset(memory, 0);
    @memcpy(memory[source_offset..][0..source_bytes.len], source_bytes);
    @memcpy(memory[root_label_offset..][0..root_label.len], root_label);

    var execution_ticks: u64 = execution_tick_budget;
    var runtime = wasm.Runtime.initWithMemoryPages(memory, &execution_ticks, memory_pages);

    const init_start = nowNs();
    const init_result = try wasm.executeExportValueArgs(&runtime, &wasm_compiler, "er_wasm_compiler_init", &.{
        .{ .i32 = @intCast(compiler_memory_offset) },
        .{ .i32 = @intCast(compiler_memory_len) },
    });
    const init_end = nowNs();
    const init_status = try init_result.valueI32(0);

    const ticks_before_compile = execution_ticks;
    const compile_start = nowNs();
    const compile_result = try wasm.executeExportValueArgs(&runtime, &wasm_compiler, "er_wasm_compiler_compile_wasm", &.{
        .{ .i32 = @intCast(compiler_memory_offset) },
        .{ .i32 = @intCast(compiler_memory_len) },
        .{ .i32 = @intCast(root_label_offset) },
        .{ .i32 = @intCast(root_label.len) },
        .{ .i32 = @intCast(source_offset) },
        .{ .i32 = @intCast(source_bytes.len) },
    });
    const compile_end = nowNs();
    const compile_status = try compile_result.valueI32(0);
    const ticks_after_compile = execution_ticks;

    const reported_output_ptr: usize = @intCast(try (try wasm.executeExportValueArgs(&runtime, &wasm_compiler, "er_wasm_compiler_output_ptr", &.{})).valueI32(0));
    const output_len: usize = @intCast(try (try wasm.executeExportValueArgs(&runtime, &wasm_compiler, "er_wasm_compiler_output_len", &.{})).valueI32(0));
    const output_ptr = findSuccessorWasm(memory, output_len, reported_output_ptr) orelse return error.MissingSuccessorWasm;
    if (output_ptr != compiler_memory_offset) return error.WrongCompilerOutputAddress;
    const output = memory[output_ptr..][0..output_len];

    var successor_ticks: u64 = execution_tick_budget;
    const successor_memory = try allocator.alloc(u8, source_bytes.len + source_gap_bytes);
    defer allocator.free(successor_memory);
    @memset(successor_memory, 0);
    var successor = wasm.Runtime.init(successor_memory, &successor_ticks);
    const successor_start = nowNs();
    const app_source_ptr = try exportI32(&successor, output, "er_app_source_ptr");
    const app_source_len = try exportI32(&successor, output, "er_app_source_len");
    const app_source_hash = try exportI32(&successor, output, "er_app_source_hash");
    const app_file_count = try exportI32(&successor, output, "er_app_source_file_count");
    const app_root_source_len = try exportI32(&successor, output, "er_app_root_source_len");
    const app_root_source_hash = try exportI32(&successor, output, "er_app_root_source_hash");
    const zir_instruction_count = try exportI32(&successor, output, "er_app_zir_instruction_count");
    const zir_extra_count = try exportI32(&successor, output, "er_app_zir_extra_count");
    const zir_string_bytes = try exportI32(&successor, output, "er_app_zir_string_bytes");
    const compiler_memory_used = try exportI32(&successor, output, "er_app_compiler_memory_used");
    const analyzed_file_count = try exportI32(&successor, output, "er_app_analyzed_file_count");
    const import_edge_count = try exportI32(&successor, output, "er_app_import_edge_count");
    const unresolved_import_count = try exportI32(&successor, output, "er_app_unresolved_import_count");
    const truncated_import_count = try exportI32(&successor, output, "er_app_truncated_import_count");
    const successor_end = nowNs();

    std.debug.print("edgerun wasm compiler probe\n", .{});
    std.debug.print("root_label={s}\n", .{root_label});
    std.debug.print("input.compiler_wasm_bytes={d}\n", .{wasm_compiler.len});
    std.debug.print("input.source_object_bytes={d}\n", .{source_bytes.len});
    std.debug.print("input.source_hash=0x{x:0>8}\n", .{sourceHash(source_bytes)});
    std.debug.print("vfs.file_count={d}\n", .{vfs_stats.file_count});
    std.debug.print("vfs.manifest_bytes={d}\n", .{vfs_stats.manifest_bytes});
    std.debug.print("vfs.canonical_file_object_bytes={d}\n", .{vfs_stats.canonical_file_object_bytes});
    std.debug.print("vfs.source_body_bytes={d}\n", .{vfs_stats.source_body_bytes});
    std.debug.print("vfs.app_files={d} app_source_body_bytes={d}\n", .{ vfs_stats.app_file_count, vfs_stats.app_source_body_bytes });
    std.debug.print("vfs.compiler_files={d} compiler_source_body_bytes={d}\n", .{ vfs_stats.compiler_file_count, vfs_stats.compiler_source_body_bytes });
    std.debug.print("vfs.compiler_src_files={d} compiler_src_body_bytes={d}\n", .{ vfs_stats.compiler_src_file_count, vfs_stats.compiler_src_body_bytes });
    std.debug.print("vfs.compiler_codegen_files={d} compiler_codegen_body_bytes={d}\n", .{ vfs_stats.compiler_codegen_file_count, vfs_stats.compiler_codegen_body_bytes });
    std.debug.print("vfs.compiler_link_files={d} compiler_link_body_bytes={d}\n", .{ vfs_stats.compiler_link_file_count, vfs_stats.compiler_link_body_bytes });
    std.debug.print("vfs.std_files={d} std_source_body_bytes={d}\n", .{ vfs_stats.std_file_count, vfs_stats.std_source_body_bytes });
    std.debug.print("vfs.std_test_files={d} std_test_body_bytes={d}\n", .{ vfs_stats.std_test_file_count, vfs_stats.std_test_body_bytes });
    for (vfs_stats.top_files, 0..) |file, index| {
        if (file.body_bytes == 0) continue;
        std.debug.print("vfs.top_file.{d}.bytes={d} label={s}\n", .{ index + 1, file.body_bytes, file.labelSlice() });
    }
    std.debug.print("vfs.root_source_bytes={d}\n", .{vfs_stats.root_source_bytes});
    printHostGraphFields(graph_stats);
    std.debug.print("runtime.compiler_memory_offset={d}\n", .{compiler_memory_offset});
    std.debug.print("runtime.compiler_memory_len={d}\n", .{compiler_memory_len});
    std.debug.print("runtime.source_offset={d}\n", .{source_offset});
    std.debug.print("runtime.root_label_offset={d}\n", .{root_label_offset});
    std.debug.print("runtime.memory_len={d}\n", .{memory_len});
    std.debug.print("runtime.memory_pages={d}\n", .{memory_pages});
    std.debug.print("run.init_status={d} init_ms={d}\n", .{ init_status, elapsedMs(init_start, init_end) });
    std.debug.print("run.compile_status={d} compile_ms={d}\n", .{ compile_status, elapsedMs(compile_start, compile_end) });
    std.debug.print("run.ticks_compile={d}\n", .{ticks_before_compile - ticks_after_compile});
    std.debug.print("run.ticks_remaining={d}\n", .{ticks_after_compile});
    std.debug.print("output.reported_ptr={d}\n", .{reported_output_ptr});
    std.debug.print("output.actual_ptr={d}\n", .{output_ptr});
    std.debug.print("output.bytes={d}\n", .{output_len});
    std.debug.print("output.embedded_source_offset={?d}\n", .{std.mem.indexOf(u8, output, source_bytes)});
    std.debug.print("successor.export_source_ptr={d}\n", .{app_source_ptr});
    std.debug.print("successor.export_source_len={d}\n", .{app_source_len});
    std.debug.print("successor.export_source_hash=0x{x:0>8}\n", .{@as(u32, @bitCast(app_source_hash))});
    std.debug.print("successor.export_file_count={d}\n", .{app_file_count});
    std.debug.print("successor.export_root_source_len={d}\n", .{app_root_source_len});
    std.debug.print("successor.export_root_source_hash=0x{x:0>8}\n", .{@as(u32, @bitCast(app_root_source_hash))});
    std.debug.print("successor.zir_instruction_count={d}\n", .{zir_instruction_count});
    std.debug.print("successor.zir_extra_count={d}\n", .{zir_extra_count});
    std.debug.print("successor.zir_string_bytes={d}\n", .{zir_string_bytes});
    std.debug.print("successor.compiler_memory_used={d}\n", .{compiler_memory_used});
    std.debug.print("successor.analyzed_file_count={d}\n", .{analyzed_file_count});
    std.debug.print("successor.import_edge_count={d}\n", .{import_edge_count});
    std.debug.print("successor.unresolved_import_count={d}\n", .{unresolved_import_count});
    std.debug.print("successor.truncated_import_count={d}\n", .{truncated_import_count});
    std.debug.print("successor.read_exports_ms={d}\n", .{elapsedMs(successor_start, successor_end)});
    std.debug.print("successor.ticks_used={d}\n", .{execution_tick_budget - successor_ticks});
}

fn inspectVfs(source_bytes: []const u8, root_label: []const u8) !VfsStats {
    const view = try object.View.decode(source_bytes);
    if (!std.mem.startsWith(u8, view.body, workspace_magic)) return error.NotWorkspace;
    const file_count = bytes.load32(view.body[12..16]) orelse return error.Corrupt;
    var stats = VfsStats{
        .file_count = file_count,
        .manifest_bytes = view.body.len,
        .canonical_file_object_bytes = 0,
        .source_body_bytes = 0,
        .app_file_count = 0,
        .app_source_body_bytes = 0,
        .compiler_file_count = 0,
        .compiler_source_body_bytes = 0,
        .compiler_src_file_count = 0,
        .compiler_src_body_bytes = 0,
        .compiler_codegen_file_count = 0,
        .compiler_codegen_body_bytes = 0,
        .compiler_link_file_count = 0,
        .compiler_link_body_bytes = 0,
        .std_file_count = 0,
        .std_source_body_bytes = 0,
        .std_test_file_count = 0,
        .std_test_body_bytes = 0,
        .root_source_bytes = 0,
        .top_files = [_]FileStat{.{}} ** top_file_count,
    };
    var index: usize = workspace_header_bytes;
    var remaining = file_count;
    while (remaining > 0) : (remaining -= 1) {
        const label_ref = try vfs.decodeObjectLabelRef(view.body[index..][0..vfs.object_label_ref_bytes]);
        index += vfs.object_label_ref_bytes;
        const file_len: usize = @intCast(label_ref.object_len);
        const file_object = view.body[index..][0..file_len];
        index += file_len;
        const file_view = try object.View.decode(file_object);
        stats.canonical_file_object_bytes += file_len;
        stats.source_body_bytes += file_view.body.len;
        const label = label_ref.labelSlice();
        insertTopFile(&stats.top_files, FileStat.init(label, file_view.body.len));
        if (std.mem.startsWith(u8, label, "src/")) {
            stats.app_file_count += 1;
            stats.app_source_body_bytes += file_view.body.len;
        }
        if (std.mem.startsWith(u8, label, "compiler/zig/")) {
            stats.compiler_file_count += 1;
            stats.compiler_source_body_bytes += file_view.body.len;
        }
        if (std.mem.startsWith(u8, label, "compiler/zig/src/")) {
            stats.compiler_src_file_count += 1;
            stats.compiler_src_body_bytes += file_view.body.len;
        }
        if (std.mem.startsWith(u8, label, "compiler/zig/src/codegen/")) {
            stats.compiler_codegen_file_count += 1;
            stats.compiler_codegen_body_bytes += file_view.body.len;
        }
        if (std.mem.startsWith(u8, label, "compiler/zig/src/link/")) {
            stats.compiler_link_file_count += 1;
            stats.compiler_link_body_bytes += file_view.body.len;
        }
        if (std.mem.startsWith(u8, label, "compiler/zig/lib/std/")) {
            stats.std_file_count += 1;
            stats.std_source_body_bytes += file_view.body.len;
        }
        if (std.mem.startsWith(u8, label, "compiler/zig/lib/std/") and std.mem.endsWith(u8, label, "_test.zig")) {
            stats.std_test_file_count += 1;
            stats.std_test_body_bytes += file_view.body.len;
        }
        if (std.mem.eql(u8, label, root_label)) stats.root_source_bytes = file_view.body.len;
    }
    if (index != view.body.len) return error.Corrupt;
    if (stats.root_source_bytes == 0) return error.MissingRoot;
    return stats;
}

fn printHostGraph(root_label: []const u8, source_bytes: []const u8, vfs_stats: VfsStats, graph_stats: GraphStats) void {
    std.debug.print("edgerun wasm compiler host graph\n", .{});
    std.debug.print("root_label={s}\n", .{root_label});
    std.debug.print("input.source_object_bytes={d}\n", .{source_bytes.len});
    std.debug.print("input.source_hash=0x{x:0>8}\n", .{sourceHash(source_bytes)});
    std.debug.print("vfs.file_count={d}\n", .{vfs_stats.file_count});
    std.debug.print("vfs.source_body_bytes={d}\n", .{vfs_stats.source_body_bytes});
    std.debug.print("vfs.root_source_bytes={d}\n", .{vfs_stats.root_source_bytes});
    printHostGraphFields(graph_stats);
}

fn printHostGraphFields(graph_stats: GraphStats) void {
    std.debug.print("host_graph.analyzed_file_count={d}\n", .{graph_stats.analyzed_file_count});
    std.debug.print("host_graph.import_edge_count={d}\n", .{graph_stats.import_edge_count});
    std.debug.print("host_graph.unresolved_import_count={d}\n", .{graph_stats.unresolved_import_count});
    std.debug.print("host_graph.truncated_import_count={d}\n", .{graph_stats.truncated_import_count});
    for (graph_stats.samples, 0..) |sample, index| {
        if (sample.import_name.len == 0) continue;
        std.debug.print("host_graph.unresolved.{d}.importer={s} import={s} resolved={s}\n", .{
            index + 1,
            sample.importer.slice(),
            sample.import_name.slice(),
            sample.resolved.slice(),
        });
    }
}

fn inspectImportGraph(source_bytes: []const u8, root_label: []const u8) !GraphStats {
    const allocator = std.heap.page_allocator;
    const files = try allocator.alloc(HostFileEntry, graph_max_files);
    defer allocator.free(files);
    const file_count = try buildHostFileIndex(source_bytes, files);

    const queue = try allocator.alloc(Label, file_count);
    defer allocator.free(queue);
    var queue_len: usize = 1;
    var queue_index: usize = 0;
    queue[0] = Label.init(root_label);

    var stats: GraphStats = .{};
    while (queue_index < queue_len) : (queue_index += 1) {
        const importer = queue[queue_index].slice();
        const source = findHostFile(files[0..file_count], importer) orelse {
            stats.recordUnresolved(importer, importer, null);
            continue;
        };

        const sentinel_source = try allocator.dupeZ(u8, source);
        defer allocator.free(sentinel_source);
        var tree = try std.zig.Ast.parse(allocator, sentinel_source, .zig);
        defer tree.deinit(allocator);
        if (tree.errors.len != 0) return error.InvalidZig;
        var zir = try std.zig.AstGen.generate(allocator, tree);
        defer zir.deinit(allocator);
        if (zir.hasCompileErrors()) return error.InvalidZig;

        stats.analyzed_file_count += 1;
        const imports_index = zir.extra[@intFromEnum(std.zig.Zir.ExtraIndex.imports)];
        if (imports_index == 0) continue;
        const extra = zir.extraData(std.zig.Zir.Inst.Imports, imports_index);
        var extra_index = extra.end;
        var remaining = extra.data.imports_len;
        while (remaining > 0) : (remaining -= 1) {
            const item = zir.extraData(std.zig.Zir.Inst.Imports.Item, extra_index);
            extra_index = item.end;
            stats.import_edge_count += 1;
            const import_name = zir.nullTerminatedString(item.data.name);
            if (virtualImport(import_name)) continue;
            var resolved_buffer: [vfs.label_max]u8 = undefined;
            const resolved = resolveImportLabel(importer, import_name, &resolved_buffer) orelse {
                stats.recordUnresolved(importer, import_name, null);
                continue;
            };
            if (findHostFile(files[0..file_count], resolved) == null) {
                stats.recordUnresolved(importer, import_name, resolved);
                continue;
            }
            if (labelQueued(queue[0..queue_len], resolved)) continue;
            if (queue_len >= queue.len) {
                stats.truncated_import_count += 1;
                continue;
            }
            queue[queue_len] = Label.init(resolved);
            queue_len += 1;
        }
    }
    return stats;
}

fn buildHostFileIndex(source_bytes: []const u8, files: []HostFileEntry) !usize {
    const view = try object.View.decode(source_bytes);
    if (!std.mem.startsWith(u8, view.body, workspace_magic)) return error.NotWorkspace;
    const file_count = bytes.load32(view.body[12..16]) orelse return error.Corrupt;
    if (file_count > files.len) return error.OutOfMemory;
    var index: usize = workspace_header_bytes;
    var file_index: usize = 0;
    while (file_index < file_count) : (file_index += 1) {
        const label_ref = try vfs.decodeObjectLabelRef(view.body[index..][0..vfs.object_label_ref_bytes]);
        index += vfs.object_label_ref_bytes;
        const file_len: usize = @intCast(label_ref.object_len);
        const file_object = view.body[index..][0..file_len];
        index += file_len;
        const file_view = try object.View.decode(file_object);
        files[file_index] = .{
            .label = Label.init(label_ref.labelSlice()),
            .body = file_view.body,
        };
    }
    std.mem.sort(HostFileEntry, files[0..file_count], {}, hostFileLessThan);
    return file_count;
}

fn hostFileLessThan(_: void, left: HostFileEntry, right: HostFileEntry) bool {
    return std.mem.order(u8, left.label.slice(), right.label.slice()) == .lt;
}

fn findHostFile(files: []const HostFileEntry, label: []const u8) ?[]const u8 {
    var low: usize = 0;
    var high: usize = files.len;
    while (low < high) {
        const mid = low + (high - low) / 2;
        switch (std.mem.order(u8, files[mid].label.slice(), label)) {
            .eq => return files[mid].body,
            .lt => low = mid + 1,
            .gt => high = mid,
        }
    }
    return null;
}

fn virtualImport(import_name: []const u8) bool {
    return std.mem.eql(u8, import_name, "builtin") or
        std.mem.eql(u8, import_name, "build_options") or
        std.mem.eql(u8, import_name, "embedded_source_object") or
        std.mem.eql(u8, import_name, "embedded_wasm_compiler");
}

fn resolveImportLabel(importer_label: []const u8, import_name: []const u8, out: *[vfs.label_max]u8) ?[]const u8 {
    if (std.mem.eql(u8, import_name, "std")) return copyResolved(out, "compiler/zig/lib/std/std.zig");
    if (std.mem.eql(u8, import_name, "root")) return copyResolved(out, importer_label);
    if (import_name.len == 0 or import_name.len > vfs.label_max) return null;
    if (std.mem.startsWith(u8, import_name, "/")) return null;

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
        if (part.len == 0 or std.mem.eql(u8, part, ".")) {
            // skip
        } else if (std.mem.eql(u8, part, "..")) {
            if (len == 0) return null;
            len -= 1;
            while (len > 0 and out[len - 1] != '/') : (len -= 1) {}
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

fn labelQueued(queue: []const Label, label: []const u8) bool {
    for (queue) |queued| {
        if (std.mem.eql(u8, queued.slice(), label)) return true;
    }
    return false;
}

fn insertTopFile(top_files: *[top_file_count]FileStat, candidate: FileStat) void {
    for (top_files, 0..) |file, index| {
        if (candidate.body_bytes <= file.body_bytes) continue;
        var move_index = top_files.len - 1;
        while (move_index > index) : (move_index -= 1) {
            top_files[move_index] = top_files[move_index - 1];
        }
        top_files[index] = candidate;
        return;
    }
}

fn exportI32(runtime: *wasm.Runtime, module: []const u8, name: []const u8) !i32 {
    return try (try wasm.executeExportValueArgs(runtime, module, name, &.{})).valueI32(0);
}

fn findSuccessorWasm(memory: []u8, output_len: usize, reported_output_ptr: usize) ?usize {
    if (validSuccessorAt(memory, output_len, reported_output_ptr)) return reported_output_ptr;
    var index: usize = 0;
    while (std.mem.indexOf(u8, memory[index..], &.{ 0x00, 0x61, 0x73, 0x6d })) |relative| {
        const candidate = index + relative;
        if (validSuccessorAt(memory, output_len, candidate)) return candidate;
        index = candidate + 1;
    }
    return null;
}

fn validSuccessorAt(memory: []u8, output_len: usize, offset: usize) bool {
    if (offset > memory.len or output_len > memory.len - offset) return false;
    const candidate = memory[offset..][0..output_len];
    const scratch_len = output_len + source_gap_bytes;
    const scratch = std.heap.page_allocator.alloc(u8, scratch_len) catch return false;
    defer std.heap.page_allocator.free(scratch);
    @memset(scratch, 0);
    var ticks: u64 = 1024;
    var runtime = wasm.Runtime.init(scratch, &ticks);
    const result = wasm.executeExportValueArgs(&runtime, candidate, "er_app_abi_version", &.{}) catch return false;
    return (result.valueI32(0) catch return false) == 1;
}

fn alignForward(value: usize, alignment: usize) usize {
    const remainder = value % alignment;
    if (remainder == 0) return value;
    return value + (alignment - remainder);
}

fn pagesForBytes(value: usize) usize {
    return (value + wasm_page_bytes - 1) / wasm_page_bytes;
}

fn elapsedMs(start: i128, end: i128) i128 {
    return @divTrunc(end - start, std.time.ns_per_ms);
}

fn nowNs() i128 {
    var ts: std.os.linux.timespec = undefined;
    _ = std.os.linux.clock_gettime(.MONOTONIC, &ts);
    return @as(i128, ts.sec) * std.time.ns_per_s + ts.nsec;
}

fn sourceHash(source: []const u8) u32 {
    var hash: u32 = 0x811c9dc5;
    for (source) |byte| {
        hash ^= byte;
        hash *%= 0x01000193;
    }
    return hash;
}
