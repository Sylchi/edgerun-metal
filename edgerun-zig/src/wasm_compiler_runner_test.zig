const std = @import("std");
const object = @import("object.zig");
const ui = @import("ui.zig");
const ui_codec = @import("ui_codec.zig");
const vfs = @import("vfs.zig");
const wasm = @import("wasm/root.zig");
const wasm_compiler = @import("embedded_wasm_compiler").bytes;

const source_gap_bytes: usize = 256 * 1024;
const compiler_memory_offset: usize = 16 * 1024 * 1024;
const compiler_memory_extra_bytes: usize = 384 * 1024 * 1024;
const self_host_compiler_memory_extra_bytes: usize = 768 * 1024 * 1024;
const execution_tick_budget: u64 = 16_000_000_000;
const wasm_page_bytes: usize = 64 * 1024;
const self_host_buffer_len: usize = 16 * 1024 * 1024;
const self_host_successor_memory_len: usize = 160 * 1024 * 1024;
const workspace_manifest_magic = "ERVFSWS1";
const workspace_manifest_version: u16 = 1;
const workspace_manifest_reserved: u16 = 0;
const runner_root_label = "src/smoke.er";
const edgerun_runner_root_label = "src/smoke.er";
const runner_root_source =
    \\const max_width: usize = 4096;
    \\const buffer_len: usize = 8 * 1024;
    \\const ErrorCode: enum(u32) = enum(u32) { ok = 0, bad_input = 2 };
    \\var frame_width: usize = 0;
    \\var last_error: u32 = 0;
    \\const input_bytes: [buffer_len]u8 = undefined;
    \\const source_workspace: [buffer_len]u8 = undefined;
    \\var source_workspace_len: usize = 0;
    \\var source_workspace_ready: usize = 0;
    \\const release_artifact: [buffer_len]u8 = undefined;
    \\var release_artifact_len: usize = 0;
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
;
const edgerun_runner_root_source =
    \\const max_width: usize = 4096;
    \\const root_layout: stack = row(6, 10);
    \\const title_view: text = "Compiled without Zig";
    \\const search_view: input = "Search objects";
    \\const status_view: badge = "Ready";
    \\const action_view: button = "Run app";
    \\const scratch: [16]u8 = undefined;
    \\var committed_len: usize = 0;
    \\pub export fn er_app_main() i32 {
    \\    var index: i32 = 0;
    \\    while (index < 3) {
    \\        scratch[index] = 5 + index;
    \\        index = index + 1;
    \\    }
    \\    return scratch[2];
    \\}
    \\export fn er_smoke_const() usize {
    \\    const doubled: usize = max_width * 2;
    \\    const padded: usize = doubled + 17;
    \\    return padded;
    \\}
    \\export fn er_scale(value: i32) i32 {
    \\    const doubled: i32 = er_double(value);
    \\    const shifted: i32 = er_add(doubled, 5);
    \\    return shifted;
    \\}
    \\export fn er_mix(left: i32, right: i32) i32 {
    \\    return er_add(left, right) * 2;
    \\}
    \\export fn er_non_negative(value: i32) i32 {
    \\    if (value < 0) {
    \\        return 0;
    \\    } else {
    \\        return value;
    \\    }
    \\}
    \\export fn er_max(left: i32, right: i32) i32 {
    \\    if (left < right) {
    \\        return right;
    \\    } else {
    \\        return left;
    \\    }
    \\}
    \\fn er_double(value: i32) i32 {
    \\    return value * 2;
    \\}
    \\fn er_add(left: i32, right: i32) i32 {
    \\    return left + right;
    \\}
    \\fn er_weighted(left: i32, middle: u32, right: usize) i32 {
    \\    return left + middle * right;
    \\}
    \\export fn er_delta(left: i32, right: i32) i32 {
    \\    return left - right;
    \\}
    \\export fn er_compare_code(left: i32, right: i32) i32 {
    \\    if (left >= right) {
    \\        return 100;
    \\    } else {
    \\        return 7;
    \\    }
    \\}
    \\export fn er_not_same(left: i32, right: i32) i32 {
    \\    if (left != right) {
    \\        return left - right;
    \\    } else {
    \\        return 0;
    \\    }
    \\}
    \\export fn er_chunk_score(total: i32, chunk: i32) i32 {
    \\    return total / chunk + total % chunk + total - chunk - 1;
    \\}
    \\export fn er_accumulate(start: i32, step: i32) i32 {
    \\    var total: i32 = start;
    \\    total = total + step;
    \\    total = total + step;
    \\    return total;
    \\}
    \\export fn er_sum_to(limit: i32) i32 {
    \\    var total: i32 = 0;
    \\    var index: i32 = 0;
    \\    while (index < limit) {
    \\        total = total + index;
    \\        index = index + 1;
    \\    }
    \\    return total;
    \\}
    \\export fn er_fill_byte(seed: i32) i32 {
    \\    var index: i32 = 0;
    \\    while (index < 4) {
    \\        scratch[index] = seed + index;
    \\        index = index + 1;
    \\    }
    \\    return scratch[3];
    \\}
    \\export fn er_init_scratch() i32 {
    \\    var index: i32 = 0;
    \\    while (index < 3) {
    \\        scratch[index] = 7 + index;
    \\        index = index + 1;
    \\    }
    \\    return scratch[2];
    \\}
    \\export fn er_guarded_fill(limit: i32) i32 {
    \\    if (limit > 4) {
    \\        return -1;
    \\    }
    \\    var index: i32 = 0;
    \\    while (index < limit) {
    \\        scratch[index] = 20 + index;
    \\        index = index + 1;
    \\    }
    \\    return scratch[0] + scratch[limit - 1];
    \\}
    \\export fn er_copy_prefix(limit: usize, seed: u32) i32 {
    \\    if (limit > scratch.len) {
    \\        return -1;
    \\    }
    \\    var index: i32 = 0;
    \\    while (index < limit) {
    \\        scratch[index] = seed + index;
    \\        index = index + 1;
    \\    }
    \\    return scratch[limit - 1];
    \\}
    \\export fn er_three_arg_mix(left: i32, middle: u32, right: usize) i32 {
    \\    return er_weighted(left, middle, right) - right;
    \\}
    \\export fn er_state_roundtrip(value: usize) i32 {
    \\    committed_len = value;
    \\    return committed_len;
    \\}
    \\export fn er_state_add(delta: u32) i32 {
    \\    committed_len = committed_len + delta;
    \\    return committed_len;
    \\}
;
const self_host_runner_root_label = "src/er/self_host/main.er";
const self_host_runner_helper_label = "src/er/self_host/helper.er";
const self_host_runner_math_label = "src/er/self_host/math.er";
const self_host_runner_root_source = @embedFile("er/self_host/main.er");
const self_host_runner_helper_source = @embedFile("er/self_host/helper.er");
const self_host_runner_math_source = @embedFile("er/self_host/math.er");

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
    var compiler_storage = wasm.ExecutionStorage{};
    const init_result = try wasm.executeExportValueArgsWithStorage(&runtime, &wasm_compiler, "er_wasm_compiler_init", &.{
        .{ .i32 = @intCast(compiler_memory_offset) },
        .{ .i32 = @intCast(compiler_memory_len) },
    }, &compiler_storage);
    try std.testing.expectEqual(@as(i32, 0), try init_result.valueI32(0));

    const status_result = try wasm.executeExportValueArgsWithStorage(&runtime, &wasm_compiler, "er_wasm_compiler_status", &.{}, &compiler_storage);
    const diag_len_result = try wasm.executeExportValueArgsWithStorage(&runtime, &wasm_compiler, "er_wasm_compiler_diagnostic_len", &.{}, &compiler_storage);
    std.debug.print("\n  after init: status={d} diag_len={d}", .{ try status_result.valueI32(0), try diag_len_result.valueI32(0) });

    const compile_result = try wasm.executeExportValueArgsWithStorage(&runtime, &wasm_compiler, "er_wasm_compiler_compile_wasm", &.{
        .{ .i32 = @intCast(compiler_memory_offset) },
        .{ .i32 = @intCast(compiler_memory_len) },
        .{ .i32 = @intCast(root_label_offset) },
        .{ .i32 = @intCast(runner_root_label.len) },
        .{ .i32 = @intCast(source_offset) },
        .{ .i32 = @intCast(source_bytes.len) },
    }, &compiler_storage);
    try std.testing.expectEqual(@as(i32, 0), try compile_result.valueI32(0));

    const output_len: usize = @intCast(try (try wasm.executeExportValueArgsWithStorage(&runtime, &wasm_compiler, "er_wasm_compiler_output_len", &.{}, &compiler_storage)).valueI32(0));
    try std.testing.expect(output_len > source_bytes.len);

    const output_ptr: usize = @intCast(try (try wasm.executeExportValueArgsWithStorage(&runtime, &wasm_compiler, "er_wasm_compiler_output_ptr", &.{}, &compiler_storage)).valueI32(0));
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
    const edgerun_instruction_count_result = try wasm.executeExportValueArgs(&successor, output, "er_app_edgerun_instruction_count", &.{});
    try std.testing.expect((try edgerun_instruction_count_result.valueI32(0)) > 0);
    const edgerun_declaration_count_result = try wasm.executeExportValueArgs(&successor, output, "er_app_edgerun_declaration_count", &.{});
    try std.testing.expect((try edgerun_declaration_count_result.valueI32(0)) > 0);
    const edgerun_export_name_bytes_result = try wasm.executeExportValueArgs(&successor, output, "er_app_edgerun_export_name_bytes", &.{});
    try std.testing.expect((try edgerun_export_name_bytes_result.valueI32(0)) > 0);
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

test "compiled app compiles its own workspace and reproduces wasm hash" {
    const allocator = std.testing.allocator;
    var source_bytes_allocation: []u8 = &.{};
    const source_bytes = try buildTestWorkspaceWithEmbeddedCompiler(
        allocator,
        self_host_runner_root_label,
        self_host_runner_root_source,
        self_host_runner_helper_label,
        self_host_runner_helper_source,
        self_host_runner_math_label,
        self_host_runner_math_source,
        &source_bytes_allocation,
    );
    defer allocator.free(source_bytes_allocation);
    try std.testing.expect(source_bytes.len < self_host_buffer_len);

    const direct_output = try compileWorkspaceWithEmbeddedCompiler(allocator, source_bytes, self_host_runner_root_label);
    defer allocator.free(direct_output);
    try verifySelfHostAppBehavior(allocator, direct_output);

    const self_output = try compileWorkspaceInsideApp(allocator, direct_output, source_bytes);
    defer allocator.free(self_output);
    try expectSameWasmOutput(direct_output, self_output);
    try verifySelfHostAppBehavior(allocator, self_output);

    const second_self_output = try compileWorkspaceInsideApp(allocator, self_output, source_bytes);
    defer allocator.free(second_self_output);
    try expectSameWasmOutput(direct_output, second_self_output);
    try verifySelfHostAppBehavior(allocator, second_self_output);
}

test "embedded compiler compiles edgerun source root through interpreter" {
    var file_raw: [4096]u8 = undefined;
    var workspace_raw: [8192]u8 = undefined;
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
    var compiler_storage = wasm.ExecutionStorage{};
    const init_result = try wasm.executeExportValueArgsWithStorage(&runtime, &wasm_compiler, "er_wasm_compiler_init", &.{
        .{ .i32 = @intCast(compiler_memory_offset) },
        .{ .i32 = @intCast(compiler_memory_len) },
    }, &compiler_storage);
    try std.testing.expectEqual(@as(i32, 0), try init_result.valueI32(0));

    const compile_result = try wasm.executeExportValueArgsWithStorage(&runtime, &wasm_compiler, "er_wasm_compiler_compile_wasm", &.{
        .{ .i32 = @intCast(compiler_memory_offset) },
        .{ .i32 = @intCast(compiler_memory_len) },
        .{ .i32 = @intCast(root_label_offset) },
        .{ .i32 = @intCast(edgerun_runner_root_label.len) },
        .{ .i32 = @intCast(source_offset) },
        .{ .i32 = @intCast(source_bytes.len) },
    }, &compiler_storage);
    const compile_status = try compile_result.valueI32(0);
    std.debug.print("\n  test3 compile_status={d} output_len=?", .{compile_status});
    try std.testing.expectEqual(@as(i32, 0), compile_status);

    const output_len: usize = @intCast(try (try wasm.executeExportValueArgsWithStorage(&runtime, &wasm_compiler, "er_wasm_compiler_output_len", &.{}, &compiler_storage)).valueI32(0));
    std.debug.print(" output_len={d} source_bytes.len={d}\n", .{output_len, source_bytes.len});
    try std.testing.expect(output_len > source_bytes.len);
    const output_ptr: usize = @intCast(try (try wasm.executeExportValueArgsWithStorage(&runtime, &wasm_compiler, "er_wasm_compiler_output_ptr", &.{}, &compiler_storage)).valueI32(0));
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
    try std.testing.expectEqual(@as(i32, 20), try lowered_export_count_result.valueI32(0));
    const main_result = try wasm.executeExportValueArgs(&successor, output, "er_app_main", &.{});
    try std.testing.expectEqual(@as(i32, 7), try main_result.valueI32(0));
    const const_result = try wasm.executeExportValueArgs(&successor, output, "er_smoke_const", &.{});
    try std.testing.expectEqual(@as(i32, 8209), try const_result.valueI32(0));
    const scale_five_result = try wasm.executeExportValueArgs(&successor, output, "er_scale", &.{.{ .i32 = 5 }});
    try std.testing.expectEqual(@as(i32, 15), try scale_five_result.valueI32(0));
    const scale_neg_result = try wasm.executeExportValueArgs(&successor, output, "er_scale", &.{.{ .i32 = -4 }});
    try std.testing.expectEqual(@as(i32, -3), try scale_neg_result.valueI32(0));
    const mix_result = try wasm.executeExportValueArgs(&successor, output, "er_mix", &.{ .{ .i32 = 8 }, .{ .i32 = 3 } });
    try std.testing.expectEqual(@as(i32, 22), try mix_result.valueI32(0));
    const non_negative_positive_result = try wasm.executeExportValueArgs(&successor, output, "er_non_negative", &.{.{ .i32 = 7 }});
    try std.testing.expectEqual(@as(i32, 7), try non_negative_positive_result.valueI32(0));
    const non_negative_negative_result = try wasm.executeExportValueArgs(&successor, output, "er_non_negative", &.{.{ .i32 = -9 }});
    try std.testing.expectEqual(@as(i32, 0), try non_negative_negative_result.valueI32(0));
    const max_left_result = try wasm.executeExportValueArgs(&successor, output, "er_max", &.{ .{ .i32 = 12 }, .{ .i32 = 4 } });
    try std.testing.expectEqual(@as(i32, 12), try max_left_result.valueI32(0));
    const max_right_result = try wasm.executeExportValueArgs(&successor, output, "er_max", &.{ .{ .i32 = -3 }, .{ .i32 = 8 } });
    try std.testing.expectEqual(@as(i32, 8), try max_right_result.valueI32(0));
    const delta_result = try wasm.executeExportValueArgs(&successor, output, "er_delta", &.{ .{ .i32 = 8 }, .{ .i32 = 13 } });
    try std.testing.expectEqual(@as(i32, -5), try delta_result.valueI32(0));
    const compare_high_result = try wasm.executeExportValueArgs(&successor, output, "er_compare_code", &.{ .{ .i32 = 9 }, .{ .i32 = 9 } });
    try std.testing.expectEqual(@as(i32, 100), try compare_high_result.valueI32(0));
    const compare_low_result = try wasm.executeExportValueArgs(&successor, output, "er_compare_code", &.{ .{ .i32 = 2 }, .{ .i32 = 9 } });
    try std.testing.expectEqual(@as(i32, 7), try compare_low_result.valueI32(0));
    const not_same_result = try wasm.executeExportValueArgs(&successor, output, "er_not_same", &.{ .{ .i32 = 2 }, .{ .i32 = 9 } });
    try std.testing.expectEqual(@as(i32, -7), try not_same_result.valueI32(0));
    const same_result = try wasm.executeExportValueArgs(&successor, output, "er_not_same", &.{ .{ .i32 = 9 }, .{ .i32 = 9 } });
    try std.testing.expectEqual(@as(i32, 0), try same_result.valueI32(0));
    const chunk_score_result = try wasm.executeExportValueArgs(&successor, output, "er_chunk_score", &.{ .{ .i32 = 23 }, .{ .i32 = 5 } });
    try std.testing.expectEqual(@as(i32, 24), try chunk_score_result.valueI32(0));
    const accumulate_result = try wasm.executeExportValueArgs(&successor, output, "er_accumulate", &.{ .{ .i32 = 3 }, .{ .i32 = 4 } });
    try std.testing.expectEqual(@as(i32, 11), try accumulate_result.valueI32(0));
    const sum_to_result = try wasm.executeExportValueArgs(&successor, output, "er_sum_to", &.{.{ .i32 = 6 }});
    try std.testing.expectEqual(@as(i32, 15), try sum_to_result.valueI32(0));
    const fill_byte_result = try wasm.executeExportValueArgs(&successor, output, "er_fill_byte", &.{.{ .i32 = 40 }});
    try std.testing.expectEqual(@as(i32, 43), try fill_byte_result.valueI32(0));
    const init_scratch_result = try wasm.executeExportValueArgs(&successor, output, "er_init_scratch", &.{});
    try std.testing.expectEqual(@as(i32, 9), try init_scratch_result.valueI32(0));
    const guarded_fill_ok_result = try wasm.executeExportValueArgs(&successor, output, "er_guarded_fill", &.{.{ .i32 = 4 }});
    try std.testing.expectEqual(@as(i32, 43), try guarded_fill_ok_result.valueI32(0));
    const guarded_fill_bad_result = try wasm.executeExportValueArgs(&successor, output, "er_guarded_fill", &.{.{ .i32 = 5 }});
    try std.testing.expectEqual(@as(i32, -1), try guarded_fill_bad_result.valueI32(0));
    const copy_prefix_result = try wasm.executeExportValueArgs(&successor, output, "er_copy_prefix", &.{ .{ .i32 = 5 }, .{ .i32 = 30 } });
    try std.testing.expectEqual(@as(i32, 34), try copy_prefix_result.valueI32(0));
    const copy_prefix_bad_result = try wasm.executeExportValueArgs(&successor, output, "er_copy_prefix", &.{ .{ .i32 = 17 }, .{ .i32 = 30 } });
    try std.testing.expectEqual(@as(i32, -1), try copy_prefix_bad_result.valueI32(0));
    const three_arg_mix_result = try wasm.executeExportValueArgs(&successor, output, "er_three_arg_mix", &.{ .{ .i32 = 2 }, .{ .i32 = 5 }, .{ .i32 = 4 } });
    try std.testing.expectEqual(@as(i32, 18), try three_arg_mix_result.valueI32(0));
    const state_roundtrip_result = try wasm.executeExportValueArgs(&successor, output, "er_state_roundtrip", &.{.{ .i32 = 77 }});
    try std.testing.expectEqual(@as(i32, 77), try state_roundtrip_result.valueI32(0));
    const state_add_result = try wasm.executeExportValueArgs(&successor, output, "er_state_add", &.{.{ .i32 = 5 }});
    try std.testing.expectEqual(@as(i32, 82), try state_add_result.valueI32(0));
    const ui_ptr: usize = @intCast(try (try wasm.executeExportValueArgs(&successor, output, "er_ui_root_ptr", &.{})).valueI32(0));
    const ui_len: usize = @intCast(try (try wasm.executeExportValueArgs(&successor, output, "er_ui_root_len", &.{})).valueI32(0));
    try std.testing.expect(ui_len > ui_codec.header_size);
    var nodes: [4]ui.Node = undefined;
    const root = try ui_codec.decodeBytes(successor_memory[ui_ptr..][0..ui_len], &nodes);
    try std.testing.expectEqual(ui.Axis.row, root.stack.axis);
    try std.testing.expectEqual(@as(f32, 6), root.stack.gap);
    try std.testing.expectEqual(@as(f32, 10), root.stack.padding);
    try std.testing.expectEqual(@as(usize, 4), root.stack.children.len);
    try std.testing.expectEqualStrings("Compiled without Zig", root.stack.children[0].text.value);
    try std.testing.expectEqualStrings("Search objects", root.stack.children[1].input.placeholder);
    try std.testing.expectEqual(@as(u32, 2), root.stack.children[1].input.id);
    try std.testing.expectEqualStrings("Ready", root.stack.children[2].badge.label);
    try std.testing.expectEqualStrings("Run app", root.stack.children[3].button.label);
}

fn compileWorkspaceWithEmbeddedCompiler(allocator: std.mem.Allocator, source_bytes: []const u8, root_label: []const u8) ![]u8 {
    const compiler_memory_len = alignForward(source_bytes.len + self_host_compiler_memory_extra_bytes, 16);
    const source_offset = compiler_memory_offset + compiler_memory_len;
    const requested_memory_len = source_offset + source_bytes.len + root_label.len + source_gap_bytes;
    const memory_pages = pagesForBytes(requested_memory_len);
    const memory_len = memory_pages * wasm_page_bytes;
    const memory = try allocator.alloc(u8, memory_len);
    defer allocator.free(memory);
    @memset(memory, 0);
    @memcpy(memory[source_offset..][0..source_bytes.len], source_bytes);
    const root_label_offset = source_offset + source_bytes.len;
    @memcpy(memory[root_label_offset..][0..root_label.len], root_label);

    var execution_ticks: u64 = execution_tick_budget;
    var runtime = wasm.Runtime.initWithMemoryPages(memory, &execution_ticks, memory_pages);
    var compiler_storage = wasm.ExecutionStorage{};
    const init_result = try wasm.executeExportValueArgsWithStorage(&runtime, &wasm_compiler, "er_wasm_compiler_init", &.{
        .{ .i32 = @intCast(compiler_memory_offset) },
        .{ .i32 = @intCast(compiler_memory_len) },
    }, &compiler_storage);
    try std.testing.expectEqual(@as(i32, 0), try init_result.valueI32(0));

    const compile_result = try wasm.executeExportValueArgsWithStorage(&runtime, &wasm_compiler, "er_wasm_compiler_compile_wasm", &.{
        .{ .i32 = @intCast(compiler_memory_offset) },
        .{ .i32 = @intCast(compiler_memory_len) },
        .{ .i32 = @intCast(root_label_offset) },
        .{ .i32 = @intCast(root_label.len) },
        .{ .i32 = @intCast(source_offset) },
        .{ .i32 = @intCast(source_bytes.len) },
    }, &compiler_storage);
    const compile_status = try compile_result.valueI32(0);
    const cwEC_diag_len = try (try wasm.executeExportValueArgsWithStorage(&runtime, &wasm_compiler, "er_wasm_compiler_diagnostic_len", &.{}, &compiler_storage)).valueI32(0);
    const cwEC_diag_ptr = try (try wasm.executeExportValueArgsWithStorage(&runtime, &wasm_compiler, "er_wasm_compiler_diagnostic_ptr", &.{}, &compiler_storage)).valueI32(0);
    const cwEC_diag_slice = memory[@as(usize, @intCast(cwEC_diag_ptr))..][0..@as(usize, @intCast(cwEC_diag_len))];
    std.debug.print("\n  cwEC compile_status={d} diagnostic=\"{s}\"", .{ compile_status, cwEC_diag_slice });
    try std.testing.expectEqual(@as(i32, 0), compile_status);

    const output_len: usize = @intCast(try (try wasm.executeExportValueArgsWithStorage(&runtime, &wasm_compiler, "er_wasm_compiler_output_len", &.{}, &compiler_storage)).valueI32(0));
    const output_ptr: usize = @intCast(try (try wasm.executeExportValueArgsWithStorage(&runtime, &wasm_compiler, "er_wasm_compiler_output_ptr", &.{}, &compiler_storage)).valueI32(0));
    const output = memory[output_ptr..][0..output_len];
    std.debug.print(" output_len={d}\n", .{output_len});
    try expectWasmMagic(output);
    try std.testing.expect(output_len < self_host_buffer_len);

    const copied = try allocator.alloc(u8, output_len);
    @memcpy(copied, output);
    return copied;
}

fn compileWorkspaceInsideApp(allocator: std.mem.Allocator, app_wasm: []const u8, source_bytes: []const u8) ![]u8 {
    const memory = try allocator.alloc(u8, self_host_successor_memory_len);
    defer allocator.free(memory);
    @memset(memory, 0);
    var execution_ticks: u64 = execution_tick_budget;
    var runtime = wasm.Runtime.init(memory, &execution_ticks);

    const source_workspace_ptr: usize = @intCast(try (try wasm.executeExportValueArgs(&runtime, app_wasm, "er_ui_source_workspace_ptr", &.{})).valueI32(0));
    const source_workspace_capacity: usize = @intCast(try (try wasm.executeExportValueArgs(&runtime, app_wasm, "er_ui_source_workspace_capacity", &.{})).valueI32(0));
    try std.testing.expectEqual(@as(usize, self_host_buffer_len), source_workspace_capacity);
    try std.testing.expect(source_bytes.len <= source_workspace_capacity);
    try std.testing.expect(source_workspace_ptr + source_bytes.len <= memory.len);
    @memcpy(memory[source_workspace_ptr..][0..source_bytes.len], source_bytes);

    const source_commit_result = try wasm.executeExportValueArgs(&runtime, app_wasm, "er_ui_source_workspace_commit", &.{.{ .i32 = @intCast(source_bytes.len) }});
    try std.testing.expectEqual(@as(i32, 0), try source_commit_result.valueI32(0));

    const compile_result = try wasm.executeExportValueArgs(&runtime, app_wasm, "er_ui_compile_workspace_wasm", &.{});
    try std.testing.expectEqual(@as(i32, 0), try compile_result.valueI32(0));

    const artifact_len: usize = @intCast(try (try wasm.executeExportValueArgs(&runtime, app_wasm, "er_ui_release_artifact_len", &.{})).valueI32(0));
    const artifact_ptr: usize = @intCast(try (try wasm.executeExportValueArgs(&runtime, app_wasm, "er_ui_release_artifact_ptr", &.{})).valueI32(0));
    try std.testing.expect(artifact_ptr + artifact_len <= memory.len);
    const artifact = memory[artifact_ptr..][0..artifact_len];
    try expectWasmMagic(artifact);

    const copied = try allocator.alloc(u8, artifact_len);
    @memcpy(copied, artifact);
    return copied;
}

fn verifySelfHostAppBehavior(allocator: std.mem.Allocator, app_wasm: []const u8) !void {
    const memory = try allocator.alloc(u8, self_host_successor_memory_len);
    defer allocator.free(memory);
    @memset(memory, 0);
    var execution_ticks: u64 = execution_tick_budget;
    var runtime = wasm.Runtime.init(memory, &execution_ticks);

    const main_result = try wasm.executeExportValueArgs(&runtime, app_wasm, "er_app_main", &.{});
    try std.testing.expectEqual(@as(i32, 7), try main_result.valueI32(0));
    const score_result = try wasm.executeExportValueArgs(&runtime, app_wasm, "er_self_host_score", &.{.{ .i32 = 5 }});
    try std.testing.expectEqual(@as(i32, 23), try score_result.valueI32(0));
    const guard_negative_result = try wasm.executeExportValueArgs(&runtime, app_wasm, "er_self_host_guard", &.{.{ .i32 = -3 }});
    try std.testing.expectEqual(@as(i32, 0), try guard_negative_result.valueI32(0));
    const guard_positive_result = try wasm.executeExportValueArgs(&runtime, app_wasm, "er_self_host_guard", &.{.{ .i32 = 12 }});
    try std.testing.expectEqual(@as(i32, 17), try guard_positive_result.valueI32(0));
    const imported_marker_result = try wasm.executeExportValueArgs(&runtime, app_wasm, "er_self_host_imported_marker", &.{});
    try std.testing.expectEqual(@as(i32, 42), try imported_marker_result.valueI32(0));
    const capacity_result = try wasm.executeExportValueArgs(&runtime, app_wasm, "er_self_host_capacity_echo", &.{});
    try std.testing.expectEqual(@as(i32, @intCast(self_host_buffer_len * 2)), try capacity_result.valueI32(0));
    const import_edge_count_result = try wasm.executeExportValueArgs(&runtime, app_wasm, "er_app_import_edge_count", &.{});
    try std.testing.expectEqual(@as(i32, 2), try import_edge_count_result.valueI32(0));
    const analyzed_file_count_result = try wasm.executeExportValueArgs(&runtime, app_wasm, "er_app_analyzed_file_count", &.{});
    try std.testing.expectEqual(@as(i32, 3), try analyzed_file_count_result.valueI32(0));
    const queued_import_count_result = try wasm.executeExportValueArgs(&runtime, app_wasm, "er_app_queued_import_count", &.{});
    try std.testing.expectEqual(@as(i32, 2), try queued_import_count_result.valueI32(0));
    const unresolved_import_count_result = try wasm.executeExportValueArgs(&runtime, app_wasm, "er_app_unresolved_import_count", &.{});
    try std.testing.expectEqual(@as(i32, 0), try unresolved_import_count_result.valueI32(0));
}

fn expectSameWasmOutput(expected: []const u8, actual: []const u8) !void {
    try expectWasmMagic(expected);
    try expectWasmMagic(actual);
    try std.testing.expectEqual(expected.len, actual.len);
    try std.testing.expectEqual(sourceHash(expected), sourceHash(actual));
    try std.testing.expectEqualSlices(u8, expected, actual);
}

fn expectWasmMagic(bytes: []const u8) !void {
    try std.testing.expect(bytes.len >= 4);
    try std.testing.expectEqualSlices(u8, &.{ 0x00, 0x61, 0x73, 0x6d }, bytes[0..4]);
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

fn buildTestWorkspaceWithEmbeddedCompiler(
    allocator: std.mem.Allocator,
    root_label: []const u8,
    root_source: []const u8,
    helper_label: []const u8,
    helper_source: []const u8,
    math_label: []const u8,
    math_source: []const u8,
    out_allocation: *[]u8,
) ![]u8 {
    const root_file_raw = try allocator.alloc(u8, root_source.len + 1024);
    defer allocator.free(root_file_raw);
    const root_file_object = try (object.NodeWriter{ .out = root_file_raw }).bytesNode(sourceObjectRequirements(), sourceObjectEpoch(), root_source);
    const root_ref = try vfs.prepareObjectLabelRef(root_label, root_file_object);

    const helper_file_raw = try allocator.alloc(u8, helper_source.len + 1024);
    defer allocator.free(helper_file_raw);
    const helper_file_object = try (object.NodeWriter{ .out = helper_file_raw }).bytesNode(sourceObjectRequirements(), sourceObjectEpoch(), helper_source);
    const helper_ref = try vfs.prepareObjectLabelRef(helper_label, helper_file_object);

    const math_file_raw = try allocator.alloc(u8, math_source.len + 1024);
    defer allocator.free(math_file_raw);
    const math_file_object = try (object.NodeWriter{ .out = math_file_raw }).bytesNode(sourceObjectRequirements(), sourceObjectEpoch(), math_source);
    const math_ref = try vfs.prepareObjectLabelRef(math_label, math_file_object);

    const compiler_file_raw = try allocator.alloc(u8, wasm_compiler.len + 1024);
    defer allocator.free(compiler_file_raw);
    const compiler_file_object = try (object.NodeWriter{ .out = compiler_file_raw }).bytesNode(sourceObjectRequirements(), sourceObjectEpoch(), &wasm_compiler);
    const compiler_ref = try vfs.prepareObjectLabelRef("embedded_wasm_compiler", compiler_file_object);

    const manifest_len = workspace_manifest_magic.len +
        2 + 2 + 4 +
        vfs.object_label_ref_bytes * 4 +
        root_file_object.len +
        helper_file_object.len +
        math_file_object.len +
        compiler_file_object.len;
    var manifest = try allocator.alloc(u8, manifest_len);
    defer allocator.free(manifest);

    var index: usize = 0;
    @memcpy(manifest[index..][0..workspace_manifest_magic.len], workspace_manifest_magic);
    index += workspace_manifest_magic.len;
    std.mem.writeInt(u16, manifest[index..][0..2], workspace_manifest_version, .little);
    index += 2;
    std.mem.writeInt(u16, manifest[index..][0..2], workspace_manifest_reserved, .little);
    index += 2;
    std.mem.writeInt(u32, manifest[index..][0..4], 4, .little);
    index += 4;
    try vfs.encodeObjectLabelRef(root_ref, manifest[index..][0..vfs.object_label_ref_bytes]);
    index += vfs.object_label_ref_bytes;
    @memcpy(manifest[index..][0..root_file_object.len], root_file_object);
    index += root_file_object.len;
    try vfs.encodeObjectLabelRef(helper_ref, manifest[index..][0..vfs.object_label_ref_bytes]);
    index += vfs.object_label_ref_bytes;
    @memcpy(manifest[index..][0..helper_file_object.len], helper_file_object);
    index += helper_file_object.len;
    try vfs.encodeObjectLabelRef(math_ref, manifest[index..][0..vfs.object_label_ref_bytes]);
    index += vfs.object_label_ref_bytes;
    @memcpy(manifest[index..][0..math_file_object.len], math_file_object);
    index += math_file_object.len;
    try vfs.encodeObjectLabelRef(compiler_ref, manifest[index..][0..vfs.object_label_ref_bytes]);
    index += vfs.object_label_ref_bytes;
    @memcpy(manifest[index..][0..compiler_file_object.len], compiler_file_object);
    index += compiler_file_object.len;
    try std.testing.expectEqual(manifest_len, index);

    const workspace_raw = try allocator.alloc(u8, manifest_len + 1024);
    errdefer allocator.free(workspace_raw);
    const workspace = try (object.NodeWriter{ .out = workspace_raw }).bytesNode(sourceObjectRequirements(), sourceObjectEpoch(), manifest);
    out_allocation.* = workspace_raw;
    return workspace;
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
