const std = @import("std");
const source_object = @import("embedded_source_object").bytes;
const wasm = @import("wasm/root.zig");
const wasm_compiler = @import("embedded_wasm_compiler").bytes;

const source_gap_bytes: usize = 64 * 1024;
const execution_tick_budget: u64 = 1_000_000_000;
const wasm_page_bytes: usize = 64 * 1024;

test "embedded compiler refuses workspace successor build until real Zig compiler is embedded" {
    const source_offset = alignForward(source_object.len + source_gap_bytes, 16);
    var memory: [source_object.len * 2 + source_gap_bytes + 1024 * 1024]u8 align(16) = undefined;
    @memset(&memory, 0);
    @memcpy(memory[source_offset .. source_offset + source_object.len], &source_object);

    var execution_ticks: u64 = execution_tick_budget;
    var runtime = wasm.Runtime.initWithMemoryPages(&memory, &execution_ticks, pagesForBytes(source_offset + source_object.len));
    const init_args = [_]wasm.Value{
        .{ .i32 = 0 },
        .{ .i32 = @intCast(source_offset) },
    };
    const init_result = try wasm.executeExportValueArgs(&runtime, &wasm_compiler, "er_wasm_compiler_init", &init_args);
    try std.testing.expectEqual(@as(i32, 0), try init_result.valueI32(0));

    const compile_args = [_]wasm.Value{
        .{ .i32 = @intCast(source_offset) },
        .{ .i32 = 0 },
        .{ .i32 = @intCast(source_offset) },
        .{ .i32 = @intCast(source_object.len) },
    };
    const compile_result = try wasm.executeExportValueArgs(&runtime, &wasm_compiler, "er_wasm_compiler_compile_wasm", &compile_args);
    try std.testing.expectEqual(@as(i32, 3), try compile_result.valueI32(0));

    const output_len_result = try wasm.executeExportValueArgs(&runtime, &wasm_compiler, "er_wasm_compiler_output_len", &.{});
    const output_len: usize = @intCast(try output_len_result.valueI32(0));
    try std.testing.expectEqual(@as(usize, 0), output_len);
}

fn alignForward(value: usize, alignment: usize) usize {
    const remainder = value % alignment;
    if (remainder == 0) return value;
    return value + (alignment - remainder);
}

fn pagesForBytes(value: usize) usize {
    return (value + wasm_page_bytes - 1) / wasm_page_bytes;
}
