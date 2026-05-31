const state = @import("state.zig");

const missing_compiler_message = "compiler unavailable: app-side Zig WASM interpreter removed; use canonical host-side WASM compiler/runtime";

pub fn compileWorkspaceInsideWasm() u32 {
    state.last_compiler_status = @intFromEnum(state.ErrorCode.render_failed);
    state.last_compile_phase = .failed;
    state.last_compile_progress_permille = 0;
    state.last_compile_instructions = 0;
    state.last_compile_function_entries = 0;
    state.last_compile_memory_loads = 0;
    state.release_artifact_len = 0;
    setDiagnostic(missing_compiler_message);
    setSourceCompileSummary() catch {};
    return @intFromEnum(state.ErrorCode.render_failed);
}

pub fn setSourceCompileSummary() !void {
    const message = if (state.last_compile_phase == .failed)
        missing_compiler_message
    else
        "source workspace updated; compile path is host-side";
    const len = @min(message.len, state.source_compile_summary.len);
    @memcpy(state.source_compile_summary[0..len], message[0..len]);
    state.source_compile_summary_len = len;
}

fn setDiagnostic(message: []const u8) void {
    const len = @min(message.len, state.last_compiler_diagnostic.len);
    @memcpy(state.last_compiler_diagnostic[0..len], message[0..len]);
    state.last_compiler_diagnostic_len = len;
}
