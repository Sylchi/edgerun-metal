const std = @import("std");
const source_object = @import("embedded_source_object").bytes;
const wasm = @import("wasm/root.zig");
const wasm_compiler = @import("embedded_wasm_compiler").bytes;

const source_gap_bytes: usize = 64 * 1024;
const compiler_memory_offset: usize = 16 * 1024 * 1024;
const compiler_memory_extra_bytes: usize = 256 * 1024 * 1024;
const execution_tick_budget: u64 = 16_000_000_000;
const wasm_page_bytes: usize = 64 * 1024;
const runner_root_label = "src/root.zig";

test "embedded compiler emits workspace successor wasm with source object embedded" {
    const source_bytes = source_object[0..];
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
    try std.testing.expect((try file_count_result.valueI32(0)) > 0);
    const root_len_result = try wasm.executeExportValueArgs(&successor, output, "er_app_root_source_len", &.{});
    try std.testing.expect((try root_len_result.valueI32(0)) > 0);
    const root_hash_result = try wasm.executeExportValueArgs(&successor, output, "er_app_root_source_hash", &.{});
    try std.testing.expect((try root_hash_result.valueI32(0)) != 0);
    const zir_instruction_count_result = try wasm.executeExportValueArgs(&successor, output, "er_app_zir_instruction_count", &.{});
    try std.testing.expect((try zir_instruction_count_result.valueI32(0)) > 0);
    const zir_extra_count_result = try wasm.executeExportValueArgs(&successor, output, "er_app_zir_extra_count", &.{});
    try std.testing.expect((try zir_extra_count_result.valueI32(0)) > 0);
    const zir_string_bytes_result = try wasm.executeExportValueArgs(&successor, output, "er_app_zir_string_bytes", &.{});
    try std.testing.expect((try zir_string_bytes_result.valueI32(0)) > 0);
    const analyzed_file_count_result = try wasm.executeExportValueArgs(&successor, output, "er_app_analyzed_file_count", &.{});
    try std.testing.expect((try analyzed_file_count_result.valueI32(0)) > 1);
    const import_edge_count_result = try wasm.executeExportValueArgs(&successor, output, "er_app_import_edge_count", &.{});
    try std.testing.expect((try import_edge_count_result.valueI32(0)) > 0);
    const unresolved_import_count_result = try wasm.executeExportValueArgs(&successor, output, "er_app_unresolved_import_count", &.{});
    try std.testing.expect((try unresolved_import_count_result.valueI32(0)) >= 0);
    const truncated_import_count_result = try wasm.executeExportValueArgs(&successor, output, "er_app_truncated_import_count", &.{});
    try std.testing.expect((try truncated_import_count_result.valueI32(0)) >= 0);
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
