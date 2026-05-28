const std = @import("std");
const bytes = @import("bytes.zig");
const object = @import("object.zig");
const source_object = @import("embedded_source_object").bytes;
const vfs = @import("vfs.zig");
const wasm = @import("wasm/root.zig");
const wasm_compiler = @import("embedded_wasm_compiler").bytes;

const source_gap_bytes: usize = 64 * 1024;
const successor_validation_memory_bytes: usize = 256 * 1024 * 1024;
const compiler_memory_offset: usize = 16 * 1024 * 1024;
const compiler_memory_extra_bytes: usize = 256 * 1024 * 1024;
const execution_tick_budget: u64 = 16_000_000_000;
const wasm_page_bytes: usize = 64 * 1024;
const default_root_label = "src/root.zig";
const workspace_magic = "ERVFSWS1";
const workspace_header_bytes: usize = 16;
const top_file_count: usize = 16;
const unresolved_sample_count: usize = 8;
const host_graph_only_arg = "--host-graph";
const synthetic_arg = "--synthetic";
const metadata_only_arg = "--metadata-only";
const synthetic_root_label = "src/synthetic_000000.zig";
const workspace_manifest_version: u16 = 1;
const workspace_manifest_reserved: u16 = 0;
const wasm_magic = [_]u8{ 0x00, 0x61, 0x73, 0x6d };

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
    var metadata_only = false;
    var synthetic_file_count: ?usize = null;
    var root_label = args.next() orelse default_root_label;
    if (bytes.eql(root_label, host_graph_only_arg)) {
        host_graph_only = true;
        root_label = args.next() orelse default_root_label;
    }
    if (bytes.eql(root_label, metadata_only_arg)) {
        metadata_only = true;
        root_label = args.next() orelse default_root_label;
    }
    if (bytes.eql(root_label, synthetic_arg)) {
        const count_text = args.next() orelse return error.MissingSyntheticFileCount;
        synthetic_file_count = try std.fmt.parseInt(usize, count_text, 10);
        root_label = synthetic_root_label;
    }
    if (bytes.eql(root_label, metadata_only_arg)) {
        metadata_only = true;
        root_label = args.next() orelse default_root_label;
    }
    if (bytes.eql(root_label, synthetic_arg)) {
        const count_text = args.next() orelse return error.MissingSyntheticFileCount;
        synthetic_file_count = try std.fmt.parseInt(usize, count_text, 10);
        root_label = synthetic_root_label;
    }
    if (args.next() != null) return error.TooManyArguments;

    const allocator = std.heap.page_allocator;
    var synthetic_source: ?[]u8 = null;
    defer if (synthetic_source) |bytes_to_free| allocator.free(bytes_to_free);
    if (synthetic_file_count) |file_count| synthetic_source = try buildSyntheticWorkspace(allocator, file_count);
    const source_bytes = synthetic_source orelse source_object[0..];
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

    const memory = try allocator.alloc(u8, memory_len);
    defer allocator.free(memory);
    @memset(memory, 0);
    @memcpy(memory[source_offset..][0..source_bytes.len], source_bytes);
    @memcpy(memory[root_label_offset..][0..root_label.len], root_label);

    var execution_ticks: u64 = execution_tick_budget;
    var runtime = wasm.Runtime.initWithMemoryPages(memory, &execution_ticks, memory_pages);
    var compile_trace: wasm.ExecutionTrace = .{};
    runtime.trace = &compile_trace;

    const init_start = nowNs();
    const init_result = try wasm.executeExportValueArgs(&runtime, &wasm_compiler, "er_wasm_compiler_init", &.{
        .{ .i32 = @intCast(compiler_memory_offset) },
        .{ .i32 = @intCast(compiler_memory_len) },
    });
    const init_end = nowNs();
    const init_status = try init_result.valueI32(0);

    const ticks_before_compile = execution_ticks;
    const compile_start = nowNs();
    const compile_export = if (metadata_only) "er_wasm_compiler_compile_wasm_metadata" else "er_wasm_compiler_compile_wasm";
    const compile_result = try wasm.executeExportValueArgs(&runtime, &wasm_compiler, compile_export, &.{
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
    if (compile_status != 0 or output_len == 0) {
        std.debug.print("run.compile_status={d} output.ptr={d} output.len={d}\n", .{ compile_status, reported_output_ptr, output_len });
        const diagnostic_ptr: usize = @intCast(try (try wasm.executeExportValueArgs(&runtime, &wasm_compiler, "er_wasm_compiler_diagnostic_ptr", &.{})).valueI32(0));
        const diagnostic_len: usize = @intCast(try (try wasm.executeExportValueArgs(&runtime, &wasm_compiler, "er_wasm_compiler_diagnostic_len", &.{})).valueI32(0));
        if (diagnostic_ptr <= memory.len and diagnostic_len <= memory.len - diagnostic_ptr) {
            std.debug.print("run.diagnostic={s}\n", .{memory[diagnostic_ptr..][0..diagnostic_len]});
        }
        return error.CompilerDidNotEmitOutput;
    }
    const output_ptr = findSuccessorWasm(memory, output_len, reported_output_ptr) orelse {
        std.debug.print("output.missing_successor reported_ptr={d} len={d}", .{ reported_output_ptr, output_len });
        if (reported_output_ptr <= memory.len and output_len >= wasm_magic.len and output_len <= memory.len - reported_output_ptr) {
            std.debug.print(" first4={x:0>2} {x:0>2} {x:0>2} {x:0>2}", .{
                memory[reported_output_ptr],
                memory[reported_output_ptr + 1],
                memory[reported_output_ptr + 2],
                memory[reported_output_ptr + 3],
            });
            diagnoseSuccessorCandidate(memory, output_len, reported_output_ptr);
        }
        std.debug.print("\n", .{});
        return error.MissingSuccessorWasm;
    };
    if (output_ptr != compiler_memory_offset) return error.WrongCompilerOutputAddress;
    const output = memory[output_ptr..][0..output_len];
    try dumpBuildArtifact(init.io, ".build/edgerun-linked-successor.wasm", output);

    var successor_ticks: u64 = execution_tick_budget;
    const successor_memory_len = if (source_bytes.len + source_gap_bytes > successor_validation_memory_bytes)
        source_bytes.len + source_gap_bytes
    else
        successor_validation_memory_bytes;
    const successor_memory = try allocator.alloc(u8, successor_memory_len);
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
    const manifest_file_refs_scanned = try exportI32(&successor, output, "er_app_manifest_file_refs_scanned");
    const file_object_decodes = try exportI32(&successor, output, "er_app_file_object_decodes");
    const file_lookup_count = try exportI32(&successor, output, "er_app_file_lookup_count");
    const queued_import_count = try exportI32(&successor, output, "er_app_queued_import_count");
    const pruned_import_count = try exportI32(&successor, output, "er_app_pruned_import_count");
    const parsed_source_bytes = try exportI32(&successor, output, "er_app_parsed_source_bytes");
    const indexed_file_count = try exportI32(&successor, output, "er_app_indexed_file_count");
    const embedded_source_len = try exportI32(&successor, output, "er_app_embedded_source_len");
    const lowered_main_count = try exportI32(&successor, output, "er_app_lowered_main_count");
    const lowered_export_count = try exportI32(&successor, output, "er_app_lowered_export_count");
    const lowered_main_result: ?i32 = if (lowered_main_count != 0)
        try (try wasm.executeExportValueArgs(&successor, output, "er_app_main", &.{})).valueI32(0)
    else
        null;
    const lowered_ui_max_width = try exportI32Optional(&successor, output, "er_ui_max_width");
    const lowered_ui_max_height = try exportI32Optional(&successor, output, "er_ui_max_height");
    const lowered_ui_width = try exportI32Optional(&successor, output, "er_ui_width");
    const lowered_ui_height = try exportI32Optional(&successor, output, "er_ui_height");
    const lowered_input_ptr = try exportI32Optional(&successor, output, "er_ui_input_ptr");
    const lowered_input_capacity = try exportI32Optional(&successor, output, "er_ui_input_capacity");
    const lowered_source_workspace_ptr = try exportI32Optional(&successor, output, "er_ui_source_workspace_ptr");
    const lowered_source_workspace_capacity = try exportI32Optional(&successor, output, "er_ui_source_workspace_capacity");
    const lowered_compiler_wasm_ptr = try exportI32Optional(&successor, output, "er_ui_compiler_wasm_ptr");
    const lowered_compiler_wasm_len = try exportI32Optional(&successor, output, "er_ui_compiler_wasm_len");
    const lowered_compiler_wasm_magic_ok = compilerMagicOk(successor_memory, lowered_compiler_wasm_ptr, lowered_compiler_wasm_len);
    const lowered_release_artifact_ptr = try exportI32Optional(&successor, output, "er_ui_release_artifact_ptr");
    const lowered_release_artifact_capacity = try exportI32Optional(&successor, output, "er_ui_release_artifact_capacity");
    const lowered_last_error = try exportI32Optional(&successor, output, "er_ui_last_error");
    var source_commit_ok: ?i32 = null;
    var source_len_after_commit: ?i32 = null;
    var source_commit_oversized: ?i32 = null;
    var source_len_after_oversized: ?i32 = null;
    var source_commit_full: ?i32 = null;
    var source_len_after_full: ?i32 = null;
    var self_compile_status: ?i32 = null;
    var self_compile_release_len: ?i32 = null;
    var self_compile_inner_status: ?i32 = null;
    var self_compile_diagnostic_ptr: ?i32 = null;
    var self_compile_diagnostic_len: ?i32 = null;
    var self_compile_release_magic_ok = false;
    var self_compile_release_hash: ?u32 = null;
    if (lowered_source_workspace_ptr) |source_ptr_i32| {
        if (source_ptr_i32 >= 0) {
            if (lowered_source_workspace_capacity) |capacity_i32| {
                const source_ptr: usize = @intCast(source_ptr_i32);
                const sample = "probe successor source";
                if (source_ptr + sample.len <= successor_memory.len) {
                    @memcpy(successor_memory[source_ptr..][0..sample.len], sample);
                    source_commit_ok = try exportI32ArgOptional(&successor, output, "er_ui_source_workspace_commit", @intCast(sample.len));
                    source_len_after_commit = try exportI32Optional(&successor, output, "er_ui_source_workspace_len");
                    if (capacity_i32 < ~@as(i32, 0) >> 1) {
                        source_commit_oversized = try exportI32ArgOptional(&successor, output, "er_ui_source_workspace_commit", capacity_i32 + 1);
                        source_len_after_oversized = try exportI32Optional(&successor, output, "er_ui_source_workspace_len");
                    }
                }
                if (source_bytes.len <= @as(usize, @intCast(capacity_i32)) and source_ptr + source_bytes.len <= successor_memory.len) {
                    @memcpy(successor_memory[source_ptr..][0..source_bytes.len], source_bytes);
                    source_commit_full = try exportI32ArgOptional(&successor, output, "er_ui_source_workspace_commit", @intCast(source_bytes.len));
                    source_len_after_full = try exportI32Optional(&successor, output, "er_ui_source_workspace_len");
                    self_compile_status = try exportI32Optional(&successor, output, "er_ui_compile_workspace_wasm");
                    self_compile_release_len = try exportI32Optional(&successor, output, "er_ui_release_artifact_len");
                    if (self_compile_status != null and self_compile_status.? != 0) {
                        self_compile_inner_status = try exportI32Optional(&successor, output, "er_wasm_compiler_status");
                        self_compile_diagnostic_ptr = try exportI32Optional(&successor, output, "er_wasm_compiler_diagnostic_ptr");
                        self_compile_diagnostic_len = try exportI32Optional(&successor, output, "er_wasm_compiler_diagnostic_len");
                    }
                }
            }
        }
    }
    var release_commit_short: ?i32 = null;
    var release_last_error_after_short: ?i32 = null;
    var release_commit_ok: ?i32 = null;
    var release_len_after_commit: ?i32 = null;
    var release_last_error_after_commit: ?i32 = null;
    if (lowered_release_artifact_ptr) |artifact_ptr_i32| {
        if (artifact_ptr_i32 >= 0 and lowered_release_artifact_capacity != null) {
            const artifact_ptr: usize = @intCast(artifact_ptr_i32);
            if (artifact_ptr + wasm_magic.len <= successor_memory.len) {
                release_commit_short = try exportI32ArgOptional(&successor, output, "er_ui_release_artifact_commit", 3);
                release_last_error_after_short = try exportI32Optional(&successor, output, "er_ui_last_error");
                @memcpy(successor_memory[artifact_ptr..][0..wasm_magic.len], &wasm_magic);
                release_commit_ok = try exportI32ArgOptional(&successor, output, "er_ui_release_artifact_commit", @intCast(wasm_magic.len));
                release_len_after_commit = try exportI32Optional(&successor, output, "er_ui_release_artifact_len");
                release_last_error_after_commit = try exportI32Optional(&successor, output, "er_ui_last_error");
            }
        }
    }
    if (lowered_release_artifact_ptr) |artifact_ptr_i32| {
        if (artifact_ptr_i32 >= 0) {
            if (self_compile_release_len) |release_len_i32| {
                if (release_len_i32 >= @as(i32, @intCast(wasm_magic.len))) {
                    const artifact_ptr: usize = @intCast(artifact_ptr_i32);
                    const release_len: usize = @intCast(release_len_i32);
                    if (artifact_ptr <= successor_memory.len and release_len <= successor_memory.len - artifact_ptr) {
                        const release = successor_memory[artifact_ptr..][0..release_len];
                        self_compile_release_magic_ok = bytes.eql(release[0..wasm_magic.len], &wasm_magic);
                        self_compile_release_hash = sourceHash(release);
                    }
                }
            }
        }
    }
    const successor_end = nowNs();

    std.debug.print("edgerun wasm compiler probe\n", .{});
    std.debug.print("root_label={s}\n", .{root_label});
    std.debug.print("mode.metadata_only={}\n", .{metadata_only});
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
    printRuntimeTrace("run.trace", compile_trace);
    std.debug.print("output.reported_ptr={d}\n", .{reported_output_ptr});
    std.debug.print("output.actual_ptr={d}\n", .{output_ptr});
    std.debug.print("output.bytes={d}\n", .{output_len});
    std.debug.print("output.hash=0x{x:0>8}\n", .{sourceHash(output)});
    std.debug.print("output.embedded_source_offset={?d}\n", .{bytes.indexOf(output, source_bytes)});
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
    std.debug.print("successor.manifest_file_refs_scanned={d}\n", .{manifest_file_refs_scanned});
    std.debug.print("successor.file_object_decodes={d}\n", .{file_object_decodes});
    std.debug.print("successor.file_lookup_count={d}\n", .{file_lookup_count});
    std.debug.print("successor.queued_import_count={d}\n", .{queued_import_count});
    std.debug.print("successor.pruned_import_count={d}\n", .{pruned_import_count});
    std.debug.print("successor.parsed_source_bytes={d}\n", .{parsed_source_bytes});
    std.debug.print("successor.indexed_file_count={d}\n", .{indexed_file_count});
    std.debug.print("successor.embedded_source_len={d}\n", .{embedded_source_len});
    std.debug.print("successor.lowered_main_count={d}\n", .{lowered_main_count});
    std.debug.print("successor.lowered_export_count={d}\n", .{lowered_export_count});
    std.debug.print("successor.lowered_main_result={?d}\n", .{lowered_main_result});
    std.debug.print("successor.lowered.er_ui_max_width={?d}\n", .{lowered_ui_max_width});
    std.debug.print("successor.lowered.er_ui_max_height={?d}\n", .{lowered_ui_max_height});
    std.debug.print("successor.lowered.er_ui_width={?d}\n", .{lowered_ui_width});
    std.debug.print("successor.lowered.er_ui_height={?d}\n", .{lowered_ui_height});
    std.debug.print("successor.lowered.er_ui_input_ptr={?d}\n", .{lowered_input_ptr});
    std.debug.print("successor.lowered.er_ui_input_capacity={?d}\n", .{lowered_input_capacity});
    std.debug.print("successor.lowered.er_ui_source_workspace_ptr={?d}\n", .{lowered_source_workspace_ptr});
    std.debug.print("successor.lowered.er_ui_source_workspace_capacity={?d}\n", .{lowered_source_workspace_capacity});
    std.debug.print("successor.lowered.er_ui_compiler_wasm_ptr={?d}\n", .{lowered_compiler_wasm_ptr});
    std.debug.print("successor.lowered.er_ui_compiler_wasm_len={?d}\n", .{lowered_compiler_wasm_len});
    std.debug.print("successor.lowered.er_ui_compiler_wasm_magic_ok={}\n", .{lowered_compiler_wasm_magic_ok});
    std.debug.print("successor.lowered.er_ui_release_artifact_ptr={?d}\n", .{lowered_release_artifact_ptr});
    std.debug.print("successor.lowered.er_ui_release_artifact_capacity={?d}\n", .{lowered_release_artifact_capacity});
    std.debug.print("successor.lowered.er_ui_last_error={?d}\n", .{lowered_last_error});
    std.debug.print("successor.source_commit.ok={?d}\n", .{source_commit_ok});
    std.debug.print("successor.source_commit.len_after_ok={?d}\n", .{source_len_after_commit});
    std.debug.print("successor.source_commit.oversized={?d}\n", .{source_commit_oversized});
    std.debug.print("successor.source_commit.len_after_oversized={?d}\n", .{source_len_after_oversized});
    std.debug.print("successor.source_commit.full={?d}\n", .{source_commit_full});
    std.debug.print("successor.source_commit.len_after_full={?d}\n", .{source_len_after_full});
    std.debug.print("successor.self_compile.status={?d}\n", .{self_compile_status});
    std.debug.print("successor.self_compile.release_len={?d}\n", .{self_compile_release_len});
    std.debug.print("successor.self_compile.inner_status={?d}\n", .{self_compile_inner_status});
    if (self_compile_inner_status != null) {
        printOptionalMemoryString(
            "successor.self_compile.diagnostic",
            successor_memory,
            self_compile_diagnostic_ptr,
            self_compile_diagnostic_len,
        );
    }
    std.debug.print("successor.self_compile.release_magic_ok={}\n", .{self_compile_release_magic_ok});
    std.debug.print("successor.self_compile.release_hash={?x:0>8}\n", .{self_compile_release_hash});
    std.debug.print("successor.self_compile.same_hash={}\n", .{if (self_compile_release_hash) |hash| hash == sourceHash(output) else false});
    std.debug.print("successor.release_commit.short={?d}\n", .{release_commit_short});
    std.debug.print("successor.release_commit.last_error_after_short={?d}\n", .{release_last_error_after_short});
    std.debug.print("successor.release_commit.ok={?d}\n", .{release_commit_ok});
    std.debug.print("successor.release_commit.len_after_ok={?d}\n", .{release_len_after_commit});
    std.debug.print("successor.release_commit.last_error_after_ok={?d}\n", .{release_last_error_after_commit});
    std.debug.print("successor.read_exports_ms={d}\n", .{elapsedMs(successor_start, successor_end)});
    std.debug.print("successor.ticks_used={d}\n", .{execution_tick_budget - successor_ticks});
}

fn printRuntimeTrace(prefix: []const u8, trace: wasm.ExecutionTrace) void {
    std.debug.print("{s}.instructions={d}\n", .{ prefix, trace.instructions });
    std.debug.print("{s}.extended_instructions={d}\n", .{ prefix, trace.extended_instructions });
    std.debug.print("{s}.function_entries={d}\n", .{ prefix, trace.function_entries });
    std.debug.print("{s}.imported_calls={d}\n", .{ prefix, trace.imported_calls });
    std.debug.print("{s}.direct_calls={d}\n", .{ prefix, trace.direct_calls });
    std.debug.print("{s}.indirect_calls={d}\n", .{ prefix, trace.indirect_calls });
    std.debug.print("{s}.branch_instructions={d}\n", .{ prefix, trace.branch_instructions });
    std.debug.print("{s}.memory_loads={d}\n", .{ prefix, trace.memory_loads });
    std.debug.print("{s}.memory_stores={d}\n", .{ prefix, trace.memory_stores });
    std.debug.print("{s}.local_accesses={d}\n", .{ prefix, trace.local_accesses });
    std.debug.print("{s}.constants={d}\n", .{ prefix, trace.constants });
    std.debug.print("{s}.max_call_depth={d}\n", .{ prefix, trace.max_call_depth });
    std.debug.print("{s}.ticks_consumed={d}\n", .{ prefix, trace.execution_ticks_consumed });
    printTopOpcodes(prefix, trace);
}

fn dumpBuildArtifact(io: std.Io, path: []const u8, bytes_value: []const u8) !void {
    const file = try std.Io.Dir.cwd().createFile(io, path, .{ .truncate = true });
    defer file.close(io);
    try file.writeStreamingAll(io, bytes_value);
}

fn printOptionalMemoryString(prefix: []const u8, memory: []const u8, maybe_ptr: ?i32, maybe_len: ?i32) void {
    const ptr_i32 = maybe_ptr orelse {
        std.debug.print("{s}=null\n", .{prefix});
        return;
    };
    const len_i32 = maybe_len orelse {
        std.debug.print("{s}=null\n", .{prefix});
        return;
    };
    if (ptr_i32 < 0 or len_i32 < 0) {
        std.debug.print("{s}=invalid\n", .{prefix});
        return;
    }
    const ptr: usize = @intCast(ptr_i32);
    const len: usize = @intCast(len_i32);
    if (ptr > memory.len or len > memory.len - ptr) {
        std.debug.print("{s}=out_of_bounds\n", .{prefix});
        return;
    }
    std.debug.print("{s}={s}\n", .{ prefix, memory[ptr..][0..len] });
}

fn printTopOpcodes(prefix: []const u8, trace: wasm.ExecutionTrace) void {
    var used = [_]bool{false} ** 256;
    var rank: usize = 0;
    while (rank < 8) : (rank += 1) {
        var best_opcode: usize = 0;
        var best_count: u64 = 0;
        for (trace.opcode_counts, 0..) |count, opcode| {
            if (used[opcode] or count <= best_count) continue;
            best_opcode = opcode;
            best_count = count;
        }
        if (best_count == 0) return;
        used[best_opcode] = true;
        std.debug.print("{s}.opcode_top.{d}.opcode=0x{x:0>2} count={d}\n", .{ prefix, rank + 1, best_opcode, best_count });
    }
}

fn buildSyntheticWorkspace(allocator: std.mem.Allocator, file_count: usize) ![]u8 {
    if (file_count == 0) return error.BadSyntheticFileCount;
    var manifest: std.ArrayList(u8) = .empty;
    defer manifest.deinit(allocator);
    try manifest.appendSlice(allocator, workspace_magic);
    try appendU16(&manifest, allocator, workspace_manifest_version);
    try appendU16(&manifest, allocator, workspace_manifest_reserved);
    try appendU32(&manifest, allocator, @intCast(file_count));

    var index: usize = 0;
    while (index < file_count) : (index += 1) {
        var label_buffer: [vfs.label_max]u8 = undefined;
        const label = try std.fmt.bufPrint(&label_buffer, "src/synthetic_{d:0>6}.zig", .{index});

        var source_buffer: [128]u8 = undefined;
        const source = if (index == 0)
            "pub export fn er_synthetic() i32 { return 7; }"
        else
            try std.fmt.bufPrint(&source_buffer, "pub const synthetic_value_{d}: u32 = {d};", .{ index, index });

        const file_raw = try allocator.alloc(u8, object.header_size + source.len);
        defer allocator.free(file_raw);
        const file_object = try (object.NodeWriter{ .out = file_raw }).bytesNode(sourceObjectRequirements(), sourceObjectEpoch(), source);
        const label_ref = try vfs.prepareObjectLabelRef(label, file_object);
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
            0x73, 0x79, 0x6e, 0x74, 0x68, 0x65, 0x74, 0x69,
            0x63, 0x3a, 0x73, 0x6f, 0x75, 0x72, 0x63, 0x65,
            0x3a, 0x74, 0x65, 0x73, 0x74, 0x00, 0x00, 0x01,
        } },
    };
}

fn inspectVfs(source_bytes: []const u8, root_label: []const u8) !VfsStats {
    const view = try object.View.decode(source_bytes);
    if (!bytes.startsWith(view.body, workspace_magic)) return error.NotWorkspace;
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
        if (bytes.startsWith(label, "src/")) {
            stats.app_file_count += 1;
            stats.app_source_body_bytes += file_view.body.len;
        }
        if (bytes.startsWith(label, "compiler/zig/")) {
            stats.compiler_file_count += 1;
            stats.compiler_source_body_bytes += file_view.body.len;
        }
        if (bytes.startsWith(label, "compiler/zig/src/")) {
            stats.compiler_src_file_count += 1;
            stats.compiler_src_body_bytes += file_view.body.len;
        }
        if (bytes.startsWith(label, "compiler/zig/src/codegen/")) {
            stats.compiler_codegen_file_count += 1;
            stats.compiler_codegen_body_bytes += file_view.body.len;
        }
        if (bytes.startsWith(label, "compiler/zig/src/link/")) {
            stats.compiler_link_file_count += 1;
            stats.compiler_link_body_bytes += file_view.body.len;
        }
        if (bytes.startsWith(label, "compiler/zig/lib/std/")) {
            stats.std_file_count += 1;
            stats.std_source_body_bytes += file_view.body.len;
        }
        if (bytes.startsWith(label, "compiler/zig/lib/std/") and bytes.endsWith(label, "_test.zig")) {
            stats.std_test_file_count += 1;
            stats.std_test_body_bytes += file_view.body.len;
        }
        if (bytes.eql(label, root_label)) stats.root_source_bytes = file_view.body.len;
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
    const manifest_file_count = try workspaceFileCount(source_bytes);
    const files = try allocator.alloc(HostFileEntry, manifest_file_count);
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
                if (prunedSourceImport(resolved)) continue;
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

fn workspaceFileCount(source_bytes: []const u8) !usize {
    const view = try object.View.decode(source_bytes);
    if (!bytes.startsWith(view.body, workspace_magic)) return error.NotWorkspace;
    const file_count = bytes.load32(view.body[12..16]) orelse return error.Corrupt;
    return @intCast(file_count);
}

fn buildHostFileIndex(source_bytes: []const u8, files: []HostFileEntry) !usize {
    const view = try object.View.decode(source_bytes);
    if (!bytes.startsWith(view.body, workspace_magic)) return error.NotWorkspace;
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
    return bytes.order(left.label.slice(), right.label.slice()) == -1;
}

fn findHostFile(files: []const HostFileEntry, label: []const u8) ?[]const u8 {
    var low: usize = 0;
    var high: usize = files.len;
    while (low < high) {
        const mid = low + (high - low) / 2;
        switch (bytes.order(files[mid].label.slice(), label)) {
            0 => return files[mid].body,
            -1 => low = mid + 1,
            1 => high = mid,
            -2 => unreachable,
        }
    }
    return null;
}

fn virtualImport(import_name: []const u8) bool {
    return bytes.eql(import_name, "builtin") or
        bytes.eql(import_name, "build_options") or
        bytes.eql(import_name, "embedded_source_object") or
        bytes.eql(import_name, "embedded_wasm_compiler");
}

fn prunedSourceImport(resolved_label: []const u8) bool {
    if (bytes.endsWith(resolved_label, "_test.zig")) return true;
    if (bytes.eql(resolved_label, "compiler/zig/lib/std/Build.zig")) return true;
    if (bytes.eql(resolved_label, "compiler/zig/lib/std/c.zig")) return true;
    if (bytes.eql(resolved_label, "compiler/zig/lib/std/crypto.zig")) return true;
    if (bytes.eql(resolved_label, "compiler/zig/lib/std/http.zig")) return true;
    if (bytes.eql(resolved_label, "compiler/zig/lib/std/Io/Threaded.zig")) return true;
    if (bytes.eql(resolved_label, "compiler/zig/lib/std/Io/Uring.zig")) return true;
    if (bytes.eql(resolved_label, "compiler/zig/lib/std/os.zig")) return true;
    if (bytes.eql(resolved_label, "compiler/zig/lib/std/tar.zig")) return true;
    if (bytes.eql(resolved_label, "compiler/zig/lib/std/testing.zig")) return true;
    if (bytes.eql(resolved_label, "compiler/zig/lib/std/tz.zig")) return true;
    if (bytes.eql(resolved_label, "compiler/zig/lib/std/valgrind.zig")) return true;
    if (bytes.eql(resolved_label, "compiler/zig/lib/std/zip.zig")) return true;
    if (bytes.startsWith(resolved_label, "compiler/zig/lib/std/Build/")) return true;
    if (bytes.startsWith(resolved_label, "compiler/zig/lib/std/c/")) return true;
    if (bytes.startsWith(resolved_label, "compiler/zig/lib/std/crypto/")) return true;
    if (bytes.startsWith(resolved_label, "compiler/zig/lib/std/debug/")) return true;
    if (bytes.startsWith(resolved_label, "compiler/zig/lib/std/http/")) return true;
    if (bytes.startsWith(resolved_label, "compiler/zig/lib/std/os/")) return true;
    if (bytes.startsWith(resolved_label, "compiler/zig/lib/std/tar/")) return true;
    if (bytes.startsWith(resolved_label, "compiler/zig/lib/std/testing/")) return true;
    if (bytes.startsWith(resolved_label, "compiler/zig/lib/std/tz/")) return true;
    if (bytes.startsWith(resolved_label, "compiler/zig/lib/std/zig/llvm/")) return true;
    if (bytes.startsWith(resolved_label, "compiler/zig/lib/compiler/")) return true;
    if (bytes.startsWith(resolved_label, "compiler/zig/src/libs/")) return true;
    if (bytes.startsWith(resolved_label, "compiler/zig/src/Package/Fetch/")) return true;
    return false;
}

fn resolveImportLabel(importer_label: []const u8, import_name: []const u8, out: *[vfs.label_max]u8) ?[]const u8 {
    if (bytes.eql(import_name, "std")) return copyResolved(out, "compiler/zig/lib/std/std.zig");
    if (bytes.eql(import_name, "root")) return copyResolved(out, importer_label);
    if (import_name.len == 0 or import_name.len > vfs.label_max) return null;
    if (bytes.startsWith(import_name, "/")) return null;

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
        if (part.len == 0 or bytes.eql(part, ".")) {
            // skip
        } else if (bytes.eql(part, "..")) {
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

fn labelQueued(queue: []const Label, label: []const u8) bool {
    for (queue) |queued| {
        if (bytes.eql(queued.slice(), label)) return true;
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

fn exportI32Optional(runtime: *wasm.Runtime, module: []const u8, name: []const u8) !?i32 {
    const result = wasm.executeExportValueArgs(runtime, module, name, &.{}) catch |err| switch (err) {
        error.MissingExport => return null,
        else => return err,
    };
    return try result.valueI32(0);
}

fn exportI32ArgOptional(runtime: *wasm.Runtime, module: []const u8, name: []const u8, arg: i32) !?i32 {
    const result = wasm.executeExportValueArgs(runtime, module, name, &.{.{ .i32 = arg }}) catch |err| switch (err) {
        error.MissingExport => return null,
        else => return err,
    };
    return try result.valueI32(0);
}

fn compilerMagicOk(memory: []const u8, maybe_ptr: ?i32, maybe_len: ?i32) bool {
    const ptr_i32 = maybe_ptr orelse return false;
    const len_i32 = maybe_len orelse return false;
    if (ptr_i32 < 0 or len_i32 < @as(i32, @intCast(wasm_magic.len))) return false;
    const ptr: usize = @intCast(ptr_i32);
    const len: usize = @intCast(len_i32);
    if (ptr > memory.len or len > memory.len - ptr) return false;
    return bytes.eql(memory[ptr..][0..wasm_magic.len], &wasm_magic);
}

fn findSuccessorWasm(memory: []u8, output_len: usize, reported_output_ptr: usize) ?usize {
    if (validSuccessorAt(memory, output_len, reported_output_ptr)) return reported_output_ptr;
    var index: usize = 0;
    while (bytes.indexOf(memory[index..], &.{ 0x00, 0x61, 0x73, 0x6d })) |relative| {
        const candidate = index + relative;
        if (validSuccessorAt(memory, output_len, candidate)) return candidate;
        index = candidate + 1;
    }
    return null;
}

fn diagnoseSuccessorCandidate(memory: []u8, output_len: usize, offset: usize) void {
    if (offset > memory.len or output_len > memory.len - offset) {
        std.debug.print(" validation=out_of_bounds", .{});
        return;
    }
    const candidate = memory[offset..][0..output_len];
    const scratch_len = if (output_len + source_gap_bytes > successor_validation_memory_bytes)
        output_len + source_gap_bytes
    else
        successor_validation_memory_bytes;
    const scratch = std.heap.page_allocator.alloc(u8, scratch_len) catch {
        std.debug.print(" validation=alloc_failed", .{});
        return;
    };
    defer std.heap.page_allocator.free(scratch);
    @memset(scratch, 0);
    var ticks: u64 = 1024;
    var runtime = wasm.Runtime.init(scratch, &ticks);
    const result = wasm.executeExportValueArgs(&runtime, candidate, "er_app_abi_version", &.{}) catch |err| {
        std.debug.print(" validation_error={s}", .{@errorName(err)});
        return;
    };
    const abi = result.valueI32(0) catch |err| {
        std.debug.print(" abi_error={s}", .{@errorName(err)});
        return;
    };
    std.debug.print(" abi={d}", .{abi});
}

fn validSuccessorAt(memory: []u8, output_len: usize, offset: usize) bool {
    if (offset > memory.len or output_len > memory.len - offset) return false;
    const candidate = memory[offset..][0..output_len];
    const scratch_len = if (output_len + source_gap_bytes > successor_validation_memory_bytes)
        output_len + source_gap_bytes
    else
        successor_validation_memory_bytes;
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
