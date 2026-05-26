const std = @import("std");
const object = @import("object.zig");
const vfs = @import("vfs.zig");
const wasm = @import("wasm/root.zig");
const wasm_compiler = @import("embedded_wasm_compiler").bytes;

const source_gap_bytes: usize = 64 * 1024;
const compiler_memory_offset: usize = 16 * 1024 * 1024;
const compiler_memory_extra_bytes: usize = 256 * 1024 * 1024;
const execution_tick_budget: u64 = 16_000_000_000;
const wasm_page_bytes: usize = 64 * 1024;
const workspace_manifest_magic = "ERVFSWS1";
const workspace_manifest_version: u16 = 1;
const workspace_manifest_reserved: u16 = 0;
const runner_root_label = "src/smoke.zig";
const edgerun_runner_root_label = "src/smoke.er";
const runner_root_source =
    \\const max_width: usize = 4096;
    \\const buffer_len: usize = 8 * 1024;
    \\const ErrorCode = enum(u32) { ok = 0, bad_input = 2 };
    \\const std = struct {
    \\    const mem = struct {
    \\        fn eql(comptime T: type, left: []const T, right: []const T) bool {
    \\            _ = left;
    \\            _ = right;
    \\            return true;
    \\        }
    \\    };
    \\};
    \\var frame_width: usize = 0;
    \\var last_error: ErrorCode = .ok;
    \\var input_bytes: [buffer_len]u8 = undefined;
    \\var source_workspace: [buffer_len]u8 = undefined;
    \\var source_workspace_len: usize = 0;
    \\var source_workspace_ready = false;
    \\var release_artifact: [buffer_len]u8 = undefined;
    \\var release_artifact_len: usize = 0;
    \\fn finishError(code: ErrorCode) u32 {
    \\    last_error = code;
    \\    return @intFromEnum(code);
    \\}
    \\pub export fn er_app_main() i32 { return 7; }
    \\export fn er_smoke_literal() u32 { return 11; }
    \\export fn er_smoke_const() usize { return max_width; }
    \\export fn er_smoke_zero() u32 { return @intCast(frame_width); }
    \\export fn er_smoke_len() usize { return input_bytes.len; }
    \\export fn er_smoke_ptr() usize { return @intFromPtr(&input_bytes); }
    \\export fn er_smoke_error() u32 { return @intFromEnum(last_error); }
    \\export fn er_ui_last_error() u32 { return @intFromEnum(last_error); }
    \\export fn er_ui_source_workspace_ptr() usize { ensureSourceWorkspace(); return @intFromPtr(&source_workspace); }
    \\export fn er_ui_source_workspace_len() usize { ensureSourceWorkspace(); return source_workspace_len; }
    \\export fn er_ui_source_workspace_capacity() usize { return source_workspace.len; }
    \\export fn er_ui_source_workspace_commit(source_len: usize) u32 {
    \\    if (source_len > source_workspace.len) return finishError(.bad_input);
    \\    source_workspace_len = source_len;
    \\    source_workspace_ready = true;
    \\    last_error = .ok;
    \\    return @intFromEnum(ErrorCode.ok);
    \\}
    \\export fn er_ui_release_artifact_ptr() usize { return @intFromPtr(&release_artifact); }
    \\export fn er_ui_release_artifact_len() usize { return release_artifact_len; }
    \\export fn er_ui_release_artifact_capacity() usize { return release_artifact.len; }
    \\export fn er_ui_release_artifact_commit(artifact_len: usize) u32 {
    \\    if (artifact_len > release_artifact.len) return finishError(.bad_input);
    \\    if (artifact_len < 4) return finishError(.bad_input);
    \\    if (!std.mem.eql(u8, release_artifact[0..4], &.{ 0x00, 0x61, 0x73, 0x6d })) return finishError(.bad_input);
    \\    release_artifact_len = artifact_len;
    \\    last_error = .ok;
    \\    return @intFromEnum(ErrorCode.ok);
    \\}
    \\fn ensureSourceWorkspace() void {}
;
const edgerun_runner_root_source =
    \\const max_width: usize = 4096;
    \\pub export fn er_app_main() i32 { return 9; }
    \\export fn er_smoke_const() usize { return max_width; }
;

test "embedded compiler emits workspace successor wasm with source object embedded" {
    var file_raw: [4096]u8 = undefined;
    var workspace_raw: [8192]u8 = undefined;
    const source_bytes = try buildTestWorkspace(&workspace_raw, &file_raw, runner_root_label, runner_root_source);
    const compiler_memory_len = alignForward(source_bytes.len + compiler_memory_extra_bytes, 16);
    const source_offset = compiler_memory_offset + compiler_memory_len;
    const requested_memory_len = source_offset + source_bytes.len + source_gap_bytes;
    const memory_pages = pagesForBytes(requested_memory_len);
    const memory_len = memory_pages * wasm_page_bytes;
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, memory_len);
    defer allocator.free(memory);
    @memset(memory, 0);
    @memcpy(memory[source_offset .. source_offset + source_bytes.len], source_bytes);
    const root_label_offset = source_offset + source_bytes.len;
    @memcpy(memory[root_label_offset..][0..runner_root_label.len], runner_root_label);

    var execution_ticks: u64 = execution_tick_budget;
    var runtime = wasm.Runtime.initWithMemoryPages(memory, &execution_ticks, memory_pages);
    const init_args = [_]wasm.Value{
        .{ .i32 = @intCast(compiler_memory_offset) },
        .{ .i32 = @intCast(compiler_memory_len) },
    };
    const init_result = try wasm.executeExportValueArgs(&runtime, &wasm_compiler, "er_wasm_compiler_init", &init_args);
    try std.testing.expectEqual(@as(i32, 0), try init_result.valueI32(0));

    const compile_args = [_]wasm.Value{
        .{ .i32 = @intCast(compiler_memory_offset) },
        .{ .i32 = @intCast(compiler_memory_len) },
        .{ .i32 = @intCast(root_label_offset) },
        .{ .i32 = @intCast(runner_root_label.len) },
        .{ .i32 = @intCast(source_offset) },
        .{ .i32 = @intCast(source_bytes.len) },
    };
    const compile_result = try wasm.executeExportValueArgs(&runtime, &wasm_compiler, "er_wasm_compiler_compile_wasm", &compile_args);
    try std.testing.expectEqual(@as(i32, 0), try compile_result.valueI32(0));

    const output_len_result = try wasm.executeExportValueArgs(&runtime, &wasm_compiler, "er_wasm_compiler_output_len", &.{});
    const output_len: usize = @intCast(try output_len_result.valueI32(0));
    try std.testing.expect(output_len > source_bytes.len);

    const output_ptr_result = try wasm.executeExportValueArgs(&runtime, &wasm_compiler, "er_wasm_compiler_output_ptr", &.{});
    const output_ptr: usize = @intCast(try output_ptr_result.valueI32(0));
    try std.testing.expectEqual(@as(usize, compiler_memory_offset), output_ptr);
    const output = memory[output_ptr..][0..output_len];
    try std.testing.expectEqualSlices(u8, &.{ 0x00, 0x61, 0x73, 0x6d }, output[0..4]);

    const successor_memory = try allocator.alloc(u8, source_bytes.len + source_gap_bytes);
    defer allocator.free(successor_memory);
    @memset(successor_memory, 0);
    var successor_ticks: u64 = execution_tick_budget;
    var successor = wasm.Runtime.init(successor_memory, &successor_ticks);
    const source_len_result = try wasm.executeExportValueArgs(&successor, output, "er_app_source_len", &.{});
    try std.testing.expectEqual(@as(i32, @intCast(source_bytes.len)), try source_len_result.valueI32(0));
    const source_hash_result = try wasm.executeExportValueArgs(&successor, output, "er_app_source_hash", &.{});
    try std.testing.expectEqual(@as(i32, @bitCast(sourceHash(source_bytes))), try source_hash_result.valueI32(0));
    const file_count_result = try wasm.executeExportValueArgs(&successor, output, "er_app_source_file_count", &.{});
    try std.testing.expectEqual(@as(i32, 1), try file_count_result.valueI32(0));
    const root_len_result = try wasm.executeExportValueArgs(&successor, output, "er_app_root_source_len", &.{});
    try std.testing.expectEqual(@as(i32, runner_root_source.len), try root_len_result.valueI32(0));
    const root_hash_result = try wasm.executeExportValueArgs(&successor, output, "er_app_root_source_hash", &.{});
    try std.testing.expect((try root_hash_result.valueI32(0)) != 0);
    const zir_instruction_count_result = try wasm.executeExportValueArgs(&successor, output, "er_app_zir_instruction_count", &.{});
    try std.testing.expect((try zir_instruction_count_result.valueI32(0)) > 0);
    const zir_extra_count_result = try wasm.executeExportValueArgs(&successor, output, "er_app_zir_extra_count", &.{});
    try std.testing.expect((try zir_extra_count_result.valueI32(0)) > 0);
    const zir_string_bytes_result = try wasm.executeExportValueArgs(&successor, output, "er_app_zir_string_bytes", &.{});
    try std.testing.expect((try zir_string_bytes_result.valueI32(0)) > 0);
    const analyzed_file_count_result = try wasm.executeExportValueArgs(&successor, output, "er_app_analyzed_file_count", &.{});
    try std.testing.expectEqual(@as(i32, 1), try analyzed_file_count_result.valueI32(0));
    const import_edge_count_result = try wasm.executeExportValueArgs(&successor, output, "er_app_import_edge_count", &.{});
    try std.testing.expectEqual(@as(i32, 0), try import_edge_count_result.valueI32(0));
    const unresolved_import_count_result = try wasm.executeExportValueArgs(&successor, output, "er_app_unresolved_import_count", &.{});
    try std.testing.expectEqual(@as(i32, 0), try unresolved_import_count_result.valueI32(0));
    const truncated_import_count_result = try wasm.executeExportValueArgs(&successor, output, "er_app_truncated_import_count", &.{});
    try std.testing.expectEqual(@as(i32, 0), try truncated_import_count_result.valueI32(0));
    const lowered_main_count_result = try wasm.executeExportValueArgs(&successor, output, "er_app_lowered_main_count", &.{});
    try std.testing.expectEqual(@as(i32, 1), try lowered_main_count_result.valueI32(0));
    const lowered_export_count_result = try wasm.executeExportValueArgs(&successor, output, "er_app_lowered_export_count", &.{});
    try std.testing.expectEqual(@as(i32, 15), try lowered_export_count_result.valueI32(0));
    const main_result = try wasm.executeExportValueArgs(&successor, output, "er_app_main", &.{});
    try std.testing.expectEqual(@as(i32, 7), try main_result.valueI32(0));
    const literal_result = try wasm.executeExportValueArgs(&successor, output, "er_smoke_literal", &.{});
    try std.testing.expectEqual(@as(i32, 11), try literal_result.valueI32(0));
    const const_result = try wasm.executeExportValueArgs(&successor, output, "er_smoke_const", &.{});
    try std.testing.expectEqual(@as(i32, 4096), try const_result.valueI32(0));
    const zero_result = try wasm.executeExportValueArgs(&successor, output, "er_smoke_zero", &.{});
    try std.testing.expectEqual(@as(i32, 0), try zero_result.valueI32(0));
    const len_result = try wasm.executeExportValueArgs(&successor, output, "er_smoke_len", &.{});
    try std.testing.expectEqual(@as(i32, 8192), try len_result.valueI32(0));
    const ptr_result = try wasm.executeExportValueArgs(&successor, output, "er_smoke_ptr", &.{});
    const ptr: usize = @intCast(try ptr_result.valueI32(0));
    try std.testing.expect(ptr >= 1024);
    try std.testing.expect(ptr + 8192 <= successor_memory.len);
    const error_result = try wasm.executeExportValueArgs(&successor, output, "er_smoke_error", &.{});
    try std.testing.expectEqual(@as(i32, 0), try error_result.valueI32(0));
    const source_workspace_ptr_result = try wasm.executeExportValueArgs(&successor, output, "er_ui_source_workspace_ptr", &.{});
    const source_workspace_ptr: usize = @intCast(try source_workspace_ptr_result.valueI32(0));
    const source_workspace_capacity_result = try wasm.executeExportValueArgs(&successor, output, "er_ui_source_workspace_capacity", &.{});
    const source_workspace_capacity: usize = @intCast(try source_workspace_capacity_result.valueI32(0));
    try std.testing.expectEqual(@as(usize, 8192), source_workspace_capacity);
    try std.testing.expect(source_workspace_ptr >= 1024);
    try std.testing.expect(source_workspace_ptr + source_workspace_capacity <= successor_memory.len);
    const source_workspace_len_before_result = try wasm.executeExportValueArgs(&successor, output, "er_ui_source_workspace_len", &.{});
    try std.testing.expectEqual(@as(i32, 0), try source_workspace_len_before_result.valueI32(0));
    @memcpy(successor_memory[source_workspace_ptr..][0.."next source".len], "next source");
    const source_commit_result = try wasm.executeExportValueArgs(&successor, output, "er_ui_source_workspace_commit", &.{.{ .i32 = "next source".len }});
    try std.testing.expectEqual(@as(i32, 0), try source_commit_result.valueI32(0));
    const source_workspace_len_after_result = try wasm.executeExportValueArgs(&successor, output, "er_ui_source_workspace_len", &.{});
    try std.testing.expectEqual(@as(i32, "next source".len), try source_workspace_len_after_result.valueI32(0));
    const source_oversized_commit_result = try wasm.executeExportValueArgs(&successor, output, "er_ui_source_workspace_commit", &.{.{ .i32 = @intCast(source_workspace_capacity + 1) }});
    try std.testing.expectEqual(@as(i32, 2), try source_oversized_commit_result.valueI32(0));
    const source_workspace_len_after_oversized_result = try wasm.executeExportValueArgs(&successor, output, "er_ui_source_workspace_len", &.{});
    try std.testing.expectEqual(@as(i32, "next source".len), try source_workspace_len_after_oversized_result.valueI32(0));
    const artifact_ptr_result = try wasm.executeExportValueArgs(&successor, output, "er_ui_release_artifact_ptr", &.{});
    const artifact_ptr: usize = @intCast(try artifact_ptr_result.valueI32(0));
    const artifact_capacity_result = try wasm.executeExportValueArgs(&successor, output, "er_ui_release_artifact_capacity", &.{});
    const artifact_capacity: usize = @intCast(try artifact_capacity_result.valueI32(0));
    try std.testing.expectEqual(@as(usize, 8192), artifact_capacity);
    try std.testing.expect(artifact_ptr >= 1024);
    try std.testing.expect(artifact_ptr + artifact_capacity <= successor_memory.len);
    const artifact_len_before_result = try wasm.executeExportValueArgs(&successor, output, "er_ui_release_artifact_len", &.{});
    try std.testing.expectEqual(@as(i32, 0), try artifact_len_before_result.valueI32(0));
    const short_commit_result = try wasm.executeExportValueArgs(&successor, output, "er_ui_release_artifact_commit", &.{.{ .i32 = 3 }});
    try std.testing.expectEqual(@as(i32, 2), try short_commit_result.valueI32(0));
    const last_error_after_short_result = try wasm.executeExportValueArgs(&successor, output, "er_ui_last_error", &.{});
    try std.testing.expectEqual(@as(i32, 2), try last_error_after_short_result.valueI32(0));
    const wasm_magic = [_]u8{ 0x00, 0x61, 0x73, 0x6d };
    @memcpy(successor_memory[artifact_ptr..][0..wasm_magic.len], &wasm_magic);
    const commit_result = try wasm.executeExportValueArgs(&successor, output, "er_ui_release_artifact_commit", &.{.{ .i32 = 4 }});
    try std.testing.expectEqual(@as(i32, 0), try commit_result.valueI32(0));
    const artifact_len_after_result = try wasm.executeExportValueArgs(&successor, output, "er_ui_release_artifact_len", &.{});
    try std.testing.expectEqual(@as(i32, 4), try artifact_len_after_result.valueI32(0));
    const last_error_after_commit_result = try wasm.executeExportValueArgs(&successor, output, "er_ui_last_error", &.{});
    try std.testing.expectEqual(@as(i32, 0), try last_error_after_commit_result.valueI32(0));
    const oversized_commit_result = try wasm.executeExportValueArgs(&successor, output, "er_ui_release_artifact_commit", &.{.{ .i32 = @intCast(artifact_capacity + 1) }});
    try std.testing.expectEqual(@as(i32, 2), try oversized_commit_result.valueI32(0));
    const artifact_len_after_oversized_result = try wasm.executeExportValueArgs(&successor, output, "er_ui_release_artifact_len", &.{});
    try std.testing.expectEqual(@as(i32, 4), try artifact_len_after_oversized_result.valueI32(0));
}

test "embedded compiler compiles edgerun source root through interpreter" {
    var file_raw: [2048]u8 = undefined;
    var workspace_raw: [4096]u8 = undefined;
    const source_bytes = try buildTestWorkspace(&workspace_raw, &file_raw, edgerun_runner_root_label, edgerun_runner_root_source);
    const compiler_memory_len = alignForward(source_bytes.len + compiler_memory_extra_bytes, 16);
    const source_offset = compiler_memory_offset + compiler_memory_len;
    const requested_memory_len = source_offset + source_bytes.len + edgerun_runner_root_label.len + source_gap_bytes;
    const memory_pages = pagesForBytes(requested_memory_len);
    const memory_len = memory_pages * wasm_page_bytes;
    const allocator = std.testing.allocator;
    const memory = try allocator.alloc(u8, memory_len);
    defer allocator.free(memory);
    @memset(memory, 0);
    @memcpy(memory[source_offset .. source_offset + source_bytes.len], source_bytes);
    const root_label_offset = source_offset + source_bytes.len;
    @memcpy(memory[root_label_offset..][0..edgerun_runner_root_label.len], edgerun_runner_root_label);

    var execution_ticks: u64 = execution_tick_budget;
    var runtime = wasm.Runtime.initWithMemoryPages(memory, &execution_ticks, memory_pages);
    const init_result = try wasm.executeExportValueArgs(&runtime, &wasm_compiler, "er_wasm_compiler_init", &.{
        .{ .i32 = @intCast(compiler_memory_offset) },
        .{ .i32 = @intCast(compiler_memory_len) },
    });
    try std.testing.expectEqual(@as(i32, 0), try init_result.valueI32(0));

    const compile_result = try wasm.executeExportValueArgs(&runtime, &wasm_compiler, "er_wasm_compiler_compile_wasm", &.{
        .{ .i32 = @intCast(compiler_memory_offset) },
        .{ .i32 = @intCast(compiler_memory_len) },
        .{ .i32 = @intCast(root_label_offset) },
        .{ .i32 = @intCast(edgerun_runner_root_label.len) },
        .{ .i32 = @intCast(source_offset) },
        .{ .i32 = @intCast(source_bytes.len) },
    });
    try std.testing.expectEqual(@as(i32, 0), try compile_result.valueI32(0));

    const output_len: usize = @intCast(try (try wasm.executeExportValueArgs(&runtime, &wasm_compiler, "er_wasm_compiler_output_len", &.{})).valueI32(0));
    try std.testing.expect(output_len > source_bytes.len);
    const output_ptr: usize = @intCast(try (try wasm.executeExportValueArgs(&runtime, &wasm_compiler, "er_wasm_compiler_output_ptr", &.{})).valueI32(0));
    try std.testing.expectEqual(@as(usize, compiler_memory_offset), output_ptr);
    const output = memory[output_ptr..][0..output_len];
    try std.testing.expectEqualSlices(u8, &.{ 0x00, 0x61, 0x73, 0x6d }, output[0..4]);

    const successor_memory = try allocator.alloc(u8, source_bytes.len + source_gap_bytes);
    defer allocator.free(successor_memory);
    @memset(successor_memory, 0);
    var successor_ticks: u64 = execution_tick_budget;
    var successor = wasm.Runtime.init(successor_memory, &successor_ticks);

    const source_len_result = try wasm.executeExportValueArgs(&successor, output, "er_app_source_len", &.{});
    try std.testing.expectEqual(@as(i32, @intCast(source_bytes.len)), try source_len_result.valueI32(0));
    const analyzed_file_count_result = try wasm.executeExportValueArgs(&successor, output, "er_app_analyzed_file_count", &.{});
    try std.testing.expectEqual(@as(i32, 1), try analyzed_file_count_result.valueI32(0));
    const lowered_main_count_result = try wasm.executeExportValueArgs(&successor, output, "er_app_lowered_main_count", &.{});
    try std.testing.expectEqual(@as(i32, 1), try lowered_main_count_result.valueI32(0));
    const lowered_export_count_result = try wasm.executeExportValueArgs(&successor, output, "er_app_lowered_export_count", &.{});
    try std.testing.expectEqual(@as(i32, 1), try lowered_export_count_result.valueI32(0));
    const main_result = try wasm.executeExportValueArgs(&successor, output, "er_app_main", &.{});
    try std.testing.expectEqual(@as(i32, 9), try main_result.valueI32(0));
    const const_result = try wasm.executeExportValueArgs(&successor, output, "er_smoke_const", &.{});
    try std.testing.expectEqual(@as(i32, 4096), try const_result.valueI32(0));
}

fn buildTestWorkspace(workspace_raw: []u8, file_raw: []u8, label: []const u8, source: []const u8) ![]u8 {
    const file_object = try (object.NodeWriter{ .out = file_raw }).bytesNode(sourceObjectRequirements(), sourceObjectEpoch(), source);
    const label_ref = try vfs.prepareObjectLabelRef(label, file_object);

    var manifest: [4096]u8 = undefined;
    var manifest_len: usize = 0;
    @memcpy(manifest[manifest_len..][0..workspace_manifest_magic.len], workspace_manifest_magic);
    manifest_len += workspace_manifest_magic.len;
    std.mem.writeInt(u16, manifest[manifest_len..][0..2], workspace_manifest_version, .little);
    manifest_len += 2;
    std.mem.writeInt(u16, manifest[manifest_len..][0..2], workspace_manifest_reserved, .little);
    manifest_len += 2;
    std.mem.writeInt(u32, manifest[manifest_len..][0..4], 1, .little);
    manifest_len += 4;
    try vfs.encodeObjectLabelRef(label_ref, manifest[manifest_len..][0..vfs.object_label_ref_bytes]);
    manifest_len += vfs.object_label_ref_bytes;
    @memcpy(manifest[manifest_len..][0..file_object.len], file_object);
    manifest_len += file_object.len;

    return try (object.NodeWriter{ .out = workspace_raw }).bytesNode(sourceObjectRequirements(), sourceObjectEpoch(), manifest[0..manifest_len]);
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
            0x3a, 0x74, 0x65, 0x73, 0x74, 0x00, 0x00, 0x01,
        } },
    };
}

fn alignForward(value: usize, alignment: usize) usize {
    const remainder = value % alignment;
    if (remainder == 0) return value;
    return value + (alignment - remainder);
}

fn pagesForBytes(value: usize) usize {
    return (value + wasm_page_bytes - 1) / wasm_page_bytes;
}

fn sourceHash(source: []const u8) u32 {
    var hash: u32 = 0x811c9dc5;
    for (source) |byte| {
        hash ^= byte;
        hash *%= 0x01000193;
    }
    return hash;
}
