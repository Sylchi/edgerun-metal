const std = @import("std");
const bytes = @import("../bytes.zig");
const object = @import("../object.zig");
const state = @import("state.zig");
const wasm_interpreter = state.wasm_interpreter;

pub fn compileWorkspaceInsideWasm() state.ErrorCode {
    ensureSourceWorkspace();
    setCompileProgress(.loading_workspace);
    if (state.source_workspace_len == 0 or state.source_workspace_len > state.source_workspace.len) return finishCompileError(.bad_input);

    const source_offset = alignForward(state.compiler_memory_offset_bytes + state.compiler_work_memory_bytes + state.compiler_source_gap_bytes, 16);
    if (source_offset > state.compiler_runtime_memory.len) return finishCompileError(.bad_input);
    if (state.source_workspace_len > state.compiler_runtime_memory.len - source_offset) return finishCompileError(.bad_input);

    @memset(&state.compiler_runtime_memory, 0);
    @memcpy(state.compiler_runtime_memory[source_offset .. source_offset + state.source_workspace_len], state.source_workspace[0..state.source_workspace_len]);

    setCompileProgress(.init_compiler);
    var execution_ticks: u64 = state.compiler_execution_tick_budget;
    const compiler_wasm = @import("embedded_wasm_compiler").bytes;
    var runtime = wasm_interpreter.Runtime.initWithMemoryPages(&state.compiler_runtime_memory, &execution_ticks, pagesForBytes(source_offset + state.source_workspace_len));
    var trace: wasm_interpreter.ExecutionTrace = .{};
    runtime.trace = &trace;
    const compiler_memory_ptr: i32 = @intCast(state.compiler_memory_offset_bytes);
    const compiler_memory_len: i32 = @intCast(state.compiler_work_memory_bytes);
    const source_ptr: i32 = @intCast(source_offset);
    const source_len: i32 = @intCast(state.source_workspace_len);
    const source_name_offset = source_offset + state.source_workspace_len;
    if (source_name_offset > state.compiler_runtime_memory.len) return finishCompileError(.bad_input);
    if (state.source_editor_label.len > state.compiler_runtime_memory.len - source_name_offset) return finishCompileError(.bad_input);
    @memcpy(state.compiler_runtime_memory[source_name_offset..][0..state.source_editor_label.len], state.source_editor_label);
    const init_args = [_]wasm_interpreter.Value{
        .{ .i32 = compiler_memory_ptr },
        .{ .i32 = compiler_memory_len },
    };
    const init_result = wasm_interpreter.executeExportValueArgs(&runtime, &compiler_wasm, "er_wasm_compiler_init", &init_args) catch return finishCompileError(.render_failed);
    state.last_compiler_status = @intCast(init_result.valueI32(0) catch return finishCompileError(.render_failed));
    if (state.last_compiler_status != 0) {
        recordCompilerDiagnostic(&runtime);
        return finishCompileError(.bad_input);
    }

    setCompileProgress(.compiling);
    const compile_args = [_]wasm_interpreter.Value{
        .{ .i32 = compiler_memory_ptr },
        .{ .i32 = compiler_memory_len },
        .{ .i32 = @intCast(source_name_offset) },
        .{ .i32 = @intCast(state.source_editor_label.len) },
        .{ .i32 = source_ptr },
        .{ .i32 = source_len },
    };
    const compile_result = wasm_interpreter.executeExportValueArgs(&runtime, &compiler_wasm, "er_wasm_compiler_compile_wasm", &compile_args) catch return finishCompileError(.render_failed);
    state.last_compiler_status = @intCast(compile_result.valueI32(0) catch return finishCompileError(.render_failed));
    if (state.last_compiler_status != 0) {
        recordCompilerDiagnostic(&runtime);
        state.last_compile_instructions = trace.instructions;
        state.last_compile_function_entries = trace.function_entries;
        state.last_compile_memory_loads = trace.memory_loads;
        return finishCompileError(.bad_input);
    }

    setCompileProgress(.collecting_artifact);
    const output_len_result = wasm_interpreter.executeExportValueArgs(&runtime, &compiler_wasm, "er_wasm_compiler_output_len", &.{}) catch return finishCompileError(.render_failed);
    const output_ptr_result = wasm_interpreter.executeExportValueArgs(&runtime, &compiler_wasm, "er_wasm_compiler_output_ptr", &.{}) catch return finishCompileError(.render_failed);
    const output_ptr: usize = @intCast(output_ptr_result.valueI32(0) catch return finishCompileError(.render_failed));
    const output_len: usize = @intCast(output_len_result.valueI32(0) catch return finishCompileError(.render_failed));
    if (output_len < 4 or output_len > state.release_artifact.len) return finishCompileError(.bad_input);
    if (output_ptr > state.compiler_runtime_memory.len or output_len > state.compiler_runtime_memory.len - output_ptr) return finishCompileError(.bad_input);
    if (!bytes.eql(state.compiler_runtime_memory[output_ptr..][0..4], &.{ 0x00, 0x61, 0x73, 0x6d })) return finishCompileError(.bad_input);

    @memcpy(state.release_artifact[0..output_len], state.compiler_runtime_memory[output_ptr .. output_ptr + output_len]);
    state.release_artifact_len = output_len;
    state.last_compile_instructions = trace.instructions;
    state.last_compile_function_entries = trace.function_entries;
    state.last_compile_memory_loads = trace.memory_loads;
    setCompileProgress(.complete);
    setSourceCompileSummary() catch {};
    state.last_compiler_status = 0;
    state.last_compiler_diagnostic_len = 0;
    state.last_error = .ok;
    return .ok;
}

pub fn setCompileProgress(phase: state.CompilePhase) void {
    state.last_compile_phase = phase;
    state.last_compile_progress_permille = switch (phase) {
        .idle => 0,
        .loading_workspace => 80,
        .init_compiler => 180,
        .compiling => 520,
        .collecting_artifact => 880,
        .complete => 1000,
        .failed => state.last_compile_progress_permille,
    };
    setSourceCompileSummary() catch {};
}

pub fn finishCompileError(code: state.ErrorCode) state.ErrorCode {
    state.last_compile_phase = .failed;
    if (state.last_compile_progress_permille == 0) state.last_compile_progress_permille = 1;
    setSourceCompileSummary() catch {};
    return finishErrorCode(code);
}

pub fn setSourceCompileSummary() !void {
    const rendered = try std.fmt.bufPrint(&state.source_compile_summary, "workspace {d} bytes | file {d} bytes | release {d} bytes | {d} instructions | {d} calls | {d} loads", .{
        state.source_workspace_len,
        state.source_editor_len,
        state.release_artifact_len,
        state.last_compile_instructions,
        state.last_compile_function_entries,
        state.last_compile_memory_loads,
    });
    state.source_compile_summary_len = rendered.len;
}

pub fn recordCompilerDiagnostic(runtime: *wasm_interpreter.Runtime) void {
    const compiler_wasm = @import("embedded_wasm_compiler").bytes;
    const ptr_result = wasm_interpreter.executeExportValueArgs(runtime, &compiler_wasm, "er_wasm_compiler_diagnostic_ptr", &.{}) catch {
        state.last_compiler_diagnostic_len = 0;
        return;
    };
    const len_result = wasm_interpreter.executeExportValueArgs(runtime, &compiler_wasm, "er_wasm_compiler_diagnostic_len", &.{}) catch {
        state.last_compiler_diagnostic_len = 0;
        return;
    };
    const ptr: usize = @intCast(ptr_result.valueI32(0) catch {
        state.last_compiler_diagnostic_len = 0;
        return;
    });
    const len: usize = @intCast(len_result.valueI32(0) catch {
        state.last_compiler_diagnostic_len = 0;
        return;
    });
    if (ptr > runtime.memory.len) {
        state.last_compiler_diagnostic_len = 0;
        return;
    }
    const bounded_len = @min(len, @min(state.last_compiler_diagnostic.len, runtime.memory.len - ptr));
    if (bounded_len > 0) @memcpy(state.last_compiler_diagnostic[0..bounded_len], runtime.memory[ptr..][0..bounded_len]);
    state.last_compiler_diagnostic_len = bounded_len;
}

pub fn finishErrorCode(code: state.ErrorCode) state.ErrorCode {
    state.last_error = code;
    return code;
}

pub fn alignForward(value: usize, alignment: usize) usize {
    const remainder = value % alignment;
    if (remainder == 0) return value;
    return value + (alignment - remainder);
}

pub fn pagesForBytes(value: usize) usize {
    return (value + state.wasm_page_bytes - 1) / state.wasm_page_bytes;
}

fn ensureSourceWorkspace() void {
    if (!state.source_workspace_ready) {
        const source_object = @import("embedded_source_object").bytes;
        state.source_workspace_len = @min(source_object.len, state.source_workspace.len);
        @memcpy(state.source_workspace[0..state.source_workspace_len], source_object[0..state.source_workspace_len]);
        state.source_workspace_ready = true;
    }
}

pub fn sourceCompileSummaryText() []const u8 {
    if (state.source_compile_summary_len == 0) {
        setSourceCompileSummary() catch return "";
    }
    return state.source_compile_summary[0..state.source_compile_summary_len];
}

pub fn compilePhaseText(phase: state.CompilePhase) []const u8 {
    return switch (phase) {
        .idle => "idle",
        .loading_workspace => "loading workspace into compiler memory",
        .init_compiler => "initializing embedded Zig-to-wasm compiler",
        .compiling => "compiling app workspace",
        .collecting_artifact => "collecting release wasm artifact",
        .complete => "compile complete",
        .failed => "compile failed",
    };
}
