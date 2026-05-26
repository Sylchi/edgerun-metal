const std = @import("std");
const builtin = @import("builtin");

const abi_version: u32 = 1;
const app_abi_version: u32 = 1;
const memory_alignment: usize = 16;
const memory_alignment_mask: usize = memory_alignment - 1;
const wasm_source_offset: u32 = 1024;
const wasm_page_bytes: u32 = 65_536;
const wasm_page_shift = 16;
const wasm_page_mask: u64 = wasm_page_bytes - 1;
const max_source_bytes: usize = 96 * 1024 * 1024;
const object_header_bytes: usize = 148;
const object_owner_bytes: usize = 36;
const object_envelope_bytes: usize = 76;
const object_child_bytes: usize = 84;
const object_kind_bytes: u16 = 1;
const vfs_label_ref_bytes: usize = 236;
const vfs_label_max: usize = 160;
const workspace_manifest_header_bytes: usize = 16;
const fnv_offset_basis: u32 = 0x811c9dc5;
const fnv_prime: u32 = 0x01000193;
const object_magic = "EROBJ001";
const workspace_source_marker = "ERVFSWS1";
const default_root_label = "src/ui_browser.zig";
const successor_base_function_count: u32 = 27;
const max_lowered_exports: usize = 64;
const max_lowered_consts: usize = 128;
const lowered_main_i32_signature = "pub export fn er_app_main() i32";
const legacy_main_i32_signature = "pub export fn main() i32";
const return_keyword = "return";
const export_fn_keyword = "export fn ";
const const_keyword = "const ";
const type_index_no_args_i32: u32 = 0;
const type_index_no_args_void: u32 = 1;
const type_index_i32_arg_i32: u32 = 2;
const state_slot_bytes: usize = 4;
const wasm_magic_word: i32 = 0x6d736100;
const error_code_ok: i32 = 0;
const error_code_bad_input: i32 = 2;

const CompileMode = enum {
    full_source,
    metadata_only,
};

const Status = enum(u32) {
    ok = 0,
    not_initialized = 1,
    invalid_memory = 2,
    unsupported = 3,
    source_too_large = 4,
    output_too_large = 5,
    corrupt_source_object = 6,
    missing_root_source = 7,
    invalid_zig_source = 8,
    compiler_memory_too_small = 9,
};

const CompilerState = struct {
    memory: []u8 = &.{},
    output: []const u8 = &.{},
    diagnostic: []const u8 = "compiler not initialized",
    initialized: bool = false,
    status: Status = .not_initialized,
};

var state: CompilerState = .{};
var memory_addr: usize = 0;
var output_addr: usize = 0;

export fn er_wasm_compiler_abi_version() u32 {
    return abi_version;
}

export fn er_wasm_compiler_init(memory_ptr: usize, memory_len: usize) u32 {
    if (memory_len == 0) {
        state = .{ .status = .invalid_memory, .diagnostic = "compiler memory slice is empty" };
        return @intFromEnum(Status.invalid_memory);
    }

    if (memory_ptr & memory_alignment_mask != 0) {
        state = .{ .status = .invalid_memory, .diagnostic = "compiler memory slice is not aligned" };
        return @intFromEnum(Status.invalid_memory);
    }

    state = .{
        .memory = (@as([*]u8, @ptrFromInt(memory_ptr)))[0..memory_len],
        .initialized = true,
        .status = .ok,
        .diagnostic = "",
    };
    memory_addr = memory_ptr;
    output_addr = 0;
    return @intFromEnum(Status.ok);
}

export fn er_wasm_compiler_status() u32 {
    return @intFromEnum(state.status);
}

export fn er_wasm_compiler_output_ptr() usize {
    return output_addr;
}

export fn er_wasm_compiler_output_len() usize {
    return state.output.len;
}

export fn er_wasm_compiler_diagnostic_ptr() usize {
    return @intFromPtr(state.diagnostic.ptr);
}

export fn er_wasm_compiler_diagnostic_len() usize {
    return state.diagnostic.len;
}

export fn er_wasm_compiler_compile_wasm(
    compiler_memory_ptr: usize,
    compiler_memory_len: usize,
    source_name_ptr: usize,
    source_name_len: usize,
    source_ptr: usize,
    source_len: usize,
) u32 {
    return compileWithMode(.full_source, compiler_memory_ptr, compiler_memory_len, source_name_ptr, source_name_len, source_ptr, source_len);
}

export fn er_wasm_compiler_compile_wasm_metadata(
    compiler_memory_ptr: usize,
    compiler_memory_len: usize,
    source_name_ptr: usize,
    source_name_len: usize,
    source_ptr: usize,
    source_len: usize,
) u32 {
    return compileWithMode(.metadata_only, compiler_memory_ptr, compiler_memory_len, source_name_ptr, source_name_len, source_ptr, source_len);
}

fn compileWithMode(
    mode: CompileMode,
    compiler_memory_ptr: usize,
    compiler_memory_len: usize,
    source_name_ptr: usize,
    source_name_len: usize,
    source_ptr: usize,
    source_len: usize,
) u32 {
    if (compiler_memory_len == 0 or compiler_memory_ptr & memory_alignment_mask != 0) return fail(.invalid_memory, "compiler memory slice is invalid");
    const compiler_memory = (@as([*]u8, @ptrFromInt(compiler_memory_ptr)))[0..compiler_memory_len];
    if (source_len == 0 or source_len > max_source_bytes) {
        state.status = .source_too_large;
        state.diagnostic = "source size is outside compiler bounds";
        state.output = &.{};
        output_addr = 0;
        return @intFromEnum(Status.source_too_large);
    }

    const source = (@as([*]const u8, @ptrFromInt(source_ptr)))[0..source_len];
    if (!validSourceObject(source)) {
        state.status = .corrupt_source_object;
        state.diagnostic = "compiler input is not a canonical EdgeRun object";
        state.output = &.{};
        output_addr = 0;
        return @intFromEnum(Status.corrupt_source_object);
    }
    const root_label = if (source_name_len == 0) default_root_label else (@as([*]const u8, @ptrFromInt(source_name_ptr)))[0..source_name_len];
    const workspace = workspaceFromSourceObject(source, root_label) catch |err| {
        state.status = switch (err) {
            error.MissingRootSource => .missing_root_source,
            else => .corrupt_source_object,
        };
        state.diagnostic = switch (err) {
            error.MissingRootSource => "VFS workspace does not contain requested root source label",
            error.NotWorkspace => "compiler input is not an EdgeRun VFS workspace object",
            else => "compiler input has a corrupt EdgeRun VFS workspace",
        };
        state.output = &.{};
        output_addr = 0;
        return @intFromEnum(state.status);
    };
    const compiler_output = analyzeWorkspaceGraph(compiler_memory, workspace) catch |err| {
        state.status = switch (err) {
            error.OutOfMemory => .compiler_memory_too_small,
            error.InvalidZig => .invalid_zig_source,
        };
        state.diagnostic = switch (err) {
            error.OutOfMemory => "compiler memory slice is too small for Zig lowering",
            error.InvalidZig => "VFS root source does not lower to valid Zig ZIR",
        };
        state.output = &.{};
        output_addr = 0;
        return @intFromEnum(state.status);
    };

    const result = emitAppWasm(compiler_memory, source, workspace, compiler_output, mode) catch |err| {
        state.status = .output_too_large;
        state.diagnostic = switch (err) {
            error.OutputTooLarge => "compiled wasm does not fit compiler output memory",
        };
        state.output = &.{};
        output_addr = 0;
        return @intFromEnum(Status.output_too_large);
    };

    state.memory = compiler_memory;
    state.output = compiler_memory[0..result];
    memory_addr = compiler_memory_ptr;
    output_addr = compiler_memory_ptr;
    state.status = .ok;
    state.diagnostic = "";
    return @intFromEnum(Status.ok);
}

fn fail(status: Status, diagnostic: []const u8) u32 {
    state.status = status;
    state.diagnostic = diagnostic;
    state.output = &.{};
    output_addr = 0;
    return @intFromEnum(status);
}

const Writer = struct {
    bytes: []u8,
    len: usize = 0,

    fn append(writer: *Writer, byte: u8) error{OutputTooLarge}!void {
        if (writer.len >= writer.bytes.len) return error.OutputTooLarge;
        writer.bytes[writer.len] = byte;
        writer.len += 1;
    }

    fn appendSlice(writer: *Writer, bytes: []const u8) error{OutputTooLarge}!void {
        if (bytes.len > writer.bytes.len - writer.len) return error.OutputTooLarge;
        @memcpy(writer.bytes[writer.len .. writer.len + bytes.len], bytes);
        writer.len += bytes.len;
    }

    fn appendU32Leb(writer: *Writer, value: u32) error{OutputTooLarge}!void {
        var remaining = value;
        while (true) {
            var byte: u8 = @truncate(remaining & 0x7f);
            remaining >>= 7;
            if (remaining != 0) byte |= 0x80;
            try writer.append(byte);
            if (remaining == 0) break;
        }
    }

    fn appendI32Leb(writer: *Writer, value: i32) error{OutputTooLarge}!void {
        var remaining = value;
        while (true) {
            const byte: u8 = @truncate(@as(u32, @bitCast(remaining)) & 0x7f);
            remaining >>= 7;
            const done = (remaining == 0 and (byte & 0x40) == 0) or (remaining == -1 and (byte & 0x40) != 0);
            try writer.append(if (done) byte else byte | 0x80);
            if (done) break;
        }
    }

    fn appendName(writer: *Writer, name: []const u8) error{OutputTooLarge}!void {
        try writer.appendU32Leb(@intCast(name.len));
        try writer.appendSlice(name);
    }
};

fn emitAppWasm(output: []u8, source: []const u8, workspace: WorkspaceInfo, compiler_output: CompilerOutputInfo, mode: CompileMode) error{OutputTooLarge}!usize {
    var writer = Writer{ .bytes = output };
    try writer.appendSlice(&.{ 0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00 });
    const embedded_source_len: usize = switch (mode) {
        .full_source => source.len,
        .metadata_only => 0,
    };
    const source_hash: u32 = switch (mode) {
        .full_source => sourceHash(source),
        .metadata_only => 0,
    };
    const root_hash = sourceHash(workspace.root_source);
    const lowered_main = lowerMainI32Literal(workspace.root_source);
    const lowered_data_base = alignForwardUsize(wasm_source_offset + embedded_source_len, memory_alignment);
    const lowered_exports = collectLoweredExports(workspace.root_source, lowered_data_base);
    const memory_bytes = if (lowered_exports.memory_end > wasm_source_offset + embedded_source_len) lowered_exports.memory_end else wasm_source_offset + embedded_source_len;
    try emitTypeSection(&writer);
    try emitFunctionSection(&writer, lowered_exports);
    try emitMemorySection(&writer, memoryPagesForBytes(memory_bytes));
    try emitExportSection(&writer, lowered_exports);
    try emitStartSection(&writer);
    try emitCodeSection(
        &writer,
        @intCast(source.len),
        @bitCast(source_hash),
        @intCast(workspace.file_count),
        @intCast(workspace.root_source.len),
        @bitCast(root_hash),
        @intCast(compiler_output.zir_instruction_count),
        @intCast(compiler_output.zir_extra_count),
        @intCast(compiler_output.zir_string_bytes),
        @intCast(compiler_output.compiler_memory_used),
        @intCast(compiler_output.analyzed_file_count),
        @intCast(compiler_output.import_edge_count),
        @intCast(compiler_output.unresolved_import_count),
        @intCast(compiler_output.truncated_import_count),
        @intCast(compiler_output.manifest_file_refs_scanned),
        @intCast(compiler_output.file_object_decodes),
        @intCast(compiler_output.file_lookup_count),
        @intCast(compiler_output.queued_import_count),
        @intCast(compiler_output.pruned_import_count),
        @intCast(compiler_output.parsed_source_bytes),
        @intCast(compiler_output.indexed_file_count),
        @intCast(embedded_source_len),
        @intCast(compiler_output.lowered_main_count),
        @intCast(compiler_output.lowered_export_count),
        lowered_main,
        lowered_exports,
    );
    if (mode == .full_source) try emitDataSection(&writer, source);
    return writer.len;
}

fn emitTypeSection(parent: *Writer) error{OutputTooLarge}!void {
    var payload_buffer: [24]u8 = undefined;
    var payload = Writer{ .bytes = &payload_buffer };
    try payload.appendU32Leb(3);
    try payload.append(0x60);
    try payload.appendU32Leb(0);
    try payload.appendU32Leb(1);
    try payload.append(0x7f);
    try payload.append(0x60);
    try payload.appendU32Leb(0);
    try payload.appendU32Leb(0);
    try payload.append(0x60);
    try payload.appendU32Leb(1);
    try payload.append(0x7f);
    try payload.appendU32Leb(1);
    try payload.append(0x7f);
    try emitSection(parent, 1, payload.bytes[0..payload.len]);
}

fn emitFunctionSection(parent: *Writer, lowered_exports: LoweredExports) error{OutputTooLarge}!void {
    var payload_buffer: [128]u8 = undefined;
    var payload = Writer{ .bytes = &payload_buffer };
    try payload.appendU32Leb(successor_base_function_count + lowered_exports.count);
    var index: u32 = 0;
    while (index < 5) : (index += 1) try payload.appendU32Leb(type_index_no_args_i32);
    try payload.appendU32Leb(type_index_no_args_void);
    index = 6;
    while (index < successor_base_function_count) : (index += 1) try payload.appendU32Leb(type_index_no_args_i32);
    for (lowered_exports.entries[0..@intCast(lowered_exports.count)]) |lowered| {
        try payload.appendU32Leb(switch (lowered.kind) {
            .return_i32, .state_load_i32 => type_index_no_args_i32,
            .release_artifact_commit, .source_workspace_commit => type_index_i32_arg_i32,
        });
    }
    try emitSection(parent, 3, payload.bytes[0..payload.len]);
}

fn emitMemorySection(parent: *Writer, min_pages: u32) error{OutputTooLarge}!void {
    var payload_buffer: [8]u8 = undefined;
    var payload = Writer{ .bytes = &payload_buffer };
    try payload.appendU32Leb(1);
    try payload.append(0);
    try payload.appendU32Leb(min_pages);
    try emitSection(parent, 5, payload.bytes[0..payload.len]);
}

fn emitExportSection(parent: *Writer, lowered_exports: LoweredExports) error{OutputTooLarge}!void {
    var payload_buffer: [8192]u8 = undefined;
    var payload = Writer{ .bytes = &payload_buffer };
    try payload.appendU32Leb(successor_base_function_count + lowered_exports.count);
    try emitExport(&payload, "memory", 2, 0);
    try emitExport(&payload, "er_app_abi_version", 0, 0);
    try emitExport(&payload, "er_app_source_ptr", 0, 1);
    try emitExport(&payload, "er_app_source_len", 0, 2);
    try emitExport(&payload, "er_app_source_hash", 0, 3);
    try emitExport(&payload, "er_app_main", 0, 4);
    try emitExport(&payload, "er_app_source_file_count", 0, 6);
    try emitExport(&payload, "er_app_root_source_len", 0, 7);
    try emitExport(&payload, "er_app_root_source_hash", 0, 8);
    try emitExport(&payload, "er_app_zir_instruction_count", 0, 9);
    try emitExport(&payload, "er_app_zir_extra_count", 0, 10);
    try emitExport(&payload, "er_app_zir_string_bytes", 0, 11);
    try emitExport(&payload, "er_app_compiler_memory_used", 0, 12);
    try emitExport(&payload, "er_app_analyzed_file_count", 0, 13);
    try emitExport(&payload, "er_app_import_edge_count", 0, 14);
    try emitExport(&payload, "er_app_unresolved_import_count", 0, 15);
    try emitExport(&payload, "er_app_truncated_import_count", 0, 16);
    try emitExport(&payload, "er_app_manifest_file_refs_scanned", 0, 17);
    try emitExport(&payload, "er_app_file_object_decodes", 0, 18);
    try emitExport(&payload, "er_app_file_lookup_count", 0, 19);
    try emitExport(&payload, "er_app_queued_import_count", 0, 20);
    try emitExport(&payload, "er_app_pruned_import_count", 0, 21);
    try emitExport(&payload, "er_app_parsed_source_bytes", 0, 22);
    try emitExport(&payload, "er_app_indexed_file_count", 0, 23);
    try emitExport(&payload, "er_app_embedded_source_len", 0, 24);
    try emitExport(&payload, "er_app_lowered_main_count", 0, 25);
    try emitExport(&payload, "er_app_lowered_export_count", 0, 26);
    for (lowered_exports.entries[0..@intCast(lowered_exports.count)], 0..) |lowered, index| {
        try emitExport(&payload, lowered.name, 0, successor_base_function_count + @as(u32, @intCast(index)));
    }
    try emitSection(parent, 7, payload.bytes[0..payload.len]);
}

fn emitCodeSection(
    parent: *Writer,
    source_len: i32,
    hash: i32,
    file_count: i32,
    root_len: i32,
    root_hash: i32,
    zir_instruction_count: i32,
    zir_extra_count: i32,
    zir_string_bytes: i32,
    compiler_memory_used: i32,
    analyzed_file_count: i32,
    import_edge_count: i32,
    unresolved_import_count: i32,
    truncated_import_count: i32,
    manifest_file_refs_scanned: i32,
    file_object_decodes: i32,
    file_lookup_count: i32,
    queued_import_count: i32,
    pruned_import_count: i32,
    parsed_source_bytes: i32,
    indexed_file_count: i32,
    embedded_source_len: i32,
    lowered_main_count: i32,
    lowered_export_count: i32,
    lowered_main: ?i32,
    lowered_exports: LoweredExports,
) error{OutputTooLarge}!void {
    var payload_buffer: [8192]u8 = undefined;
    var payload = Writer{ .bytes = &payload_buffer };
    try payload.appendU32Leb(successor_base_function_count + lowered_exports.count);
    try emitReturnI32Function(&payload, app_abi_version);
    try emitReturnI32Function(&payload, @intCast(wasm_source_offset));
    try emitReturnI32Function(&payload, source_len);
    try emitReturnI32Function(&payload, hash);
    try emitLoweredMainFunction(&payload, lowered_main);
    try emitNoopFunction(&payload);
    try emitReturnI32Function(&payload, file_count);
    try emitReturnI32Function(&payload, root_len);
    try emitReturnI32Function(&payload, root_hash);
    try emitReturnI32Function(&payload, zir_instruction_count);
    try emitReturnI32Function(&payload, zir_extra_count);
    try emitReturnI32Function(&payload, zir_string_bytes);
    try emitReturnI32Function(&payload, compiler_memory_used);
    try emitReturnI32Function(&payload, analyzed_file_count);
    try emitReturnI32Function(&payload, import_edge_count);
    try emitReturnI32Function(&payload, unresolved_import_count);
    try emitReturnI32Function(&payload, truncated_import_count);
    try emitReturnI32Function(&payload, manifest_file_refs_scanned);
    try emitReturnI32Function(&payload, file_object_decodes);
    try emitReturnI32Function(&payload, file_lookup_count);
    try emitReturnI32Function(&payload, queued_import_count);
    try emitReturnI32Function(&payload, pruned_import_count);
    try emitReturnI32Function(&payload, parsed_source_bytes);
    try emitReturnI32Function(&payload, indexed_file_count);
    try emitReturnI32Function(&payload, embedded_source_len);
    try emitReturnI32Function(&payload, lowered_main_count);
    try emitReturnI32Function(&payload, lowered_export_count);
    for (lowered_exports.entries[0..@intCast(lowered_exports.count)]) |lowered| {
        switch (lowered.kind) {
            .return_i32 => try emitReturnI32Function(&payload, lowered.value),
            .state_load_i32 => try emitStateLoadI32Function(&payload, lowered.value),
            .release_artifact_commit => try emitReleaseArtifactCommitFunction(&payload, lowered.value, lowered.limit, lowered.state_offset, lowered.error_offset),
            .source_workspace_commit => try emitSourceWorkspaceCommitFunction(&payload, lowered.limit, lowered.state_offset, lowered.ready_offset, lowered.error_offset),
        }
    }
    try emitSection(parent, 10, payload.bytes[0..payload.len]);
}

fn emitStartSection(parent: *Writer) error{OutputTooLarge}!void {
    var payload_buffer: [8]u8 = undefined;
    var payload = Writer{ .bytes = &payload_buffer };
    try payload.appendU32Leb(5);
    try emitSection(parent, 8, payload.bytes[0..payload.len]);
}

fn emitDataSection(parent: *Writer, source: []const u8) error{OutputTooLarge}!void {
    var header_buffer: [32]u8 = undefined;
    var header = Writer{ .bytes = &header_buffer };
    try header.appendU32Leb(1);
    try header.append(0);
    try header.append(0x41);
    try header.appendI32Leb(@intCast(wasm_source_offset));
    try header.append(0x0b);
    try header.appendU32Leb(@intCast(source.len));
    try parent.append(11);
    try parent.appendU32Leb(@intCast(header.len + source.len));
    try parent.appendSlice(header.bytes[0..header.len]);
    try parent.appendSlice(source);
}

fn emitSection(parent: *Writer, section_id: u8, payload: []const u8) error{OutputTooLarge}!void {
    try parent.append(section_id);
    try parent.appendU32Leb(@intCast(payload.len));
    try parent.appendSlice(payload);
}

fn emitExport(writer: *Writer, name: []const u8, kind: u8, index: u32) error{OutputTooLarge}!void {
    try writer.appendName(name);
    try writer.append(kind);
    try writer.appendU32Leb(index);
}

fn emitReturnI32Function(writer: *Writer, value: i32) error{OutputTooLarge}!void {
    var body_buffer: [16]u8 = undefined;
    var body = Writer{ .bytes = &body_buffer };
    try body.appendU32Leb(0);
    try body.append(0x41);
    try body.appendI32Leb(value);
    try body.append(0x0b);
    try writer.appendU32Leb(@intCast(body.len));
    try writer.appendSlice(body.bytes[0..body.len]);
}

fn emitStateLoadI32Function(writer: *Writer, state_offset: i32) error{OutputTooLarge}!void {
    var body_buffer: [24]u8 = undefined;
    var body = Writer{ .bytes = &body_buffer };
    try body.appendU32Leb(0);
    try emitI32Const(&body, state_offset);
    try body.append(0x28);
    try body.appendU32Leb(2);
    try body.appendU32Leb(0);
    try body.append(0x0b);
    try writer.appendU32Leb(@intCast(body.len));
    try writer.appendSlice(body.bytes[0..body.len]);
}

fn emitReleaseArtifactCommitFunction(writer: *Writer, ptr: i32, capacity: i32, len_offset: i32, error_offset: i32) error{OutputTooLarge}!void {
    var body_buffer: [128]u8 = undefined;
    var body = Writer{ .bytes = &body_buffer };
    try body.appendU32Leb(0);

    try emitLocalGet(&body, 0);
    try emitI32Const(&body, capacity);
    try body.append(0x4b);
    try emitBadInputIf(&body, error_offset);

    try emitLocalGet(&body, 0);
    try emitI32Const(&body, 4);
    try body.append(0x49);
    try emitBadInputIf(&body, error_offset);

    try emitI32Const(&body, ptr);
    try body.append(0x28);
    try body.appendU32Leb(2);
    try body.appendU32Leb(0);
    try emitI32Const(&body, wasm_magic_word);
    try body.append(0x47);
    try emitBadInputIf(&body, error_offset);

    try emitI32Const(&body, len_offset);
    try emitLocalGet(&body, 0);
    try emitI32Store(&body);
    try emitI32Const(&body, error_offset);
    try emitI32Const(&body, error_code_ok);
    try emitI32Store(&body);
    try emitI32Const(&body, error_code_ok);
    try body.append(0x0b);

    try writer.appendU32Leb(@intCast(body.len));
    try writer.appendSlice(body.bytes[0..body.len]);
}

fn emitSourceWorkspaceCommitFunction(writer: *Writer, capacity: i32, len_offset: i32, ready_offset: i32, error_offset: i32) error{OutputTooLarge}!void {
    var body_buffer: [96]u8 = undefined;
    var body = Writer{ .bytes = &body_buffer };
    try body.appendU32Leb(0);

    try emitLocalGet(&body, 0);
    try emitI32Const(&body, capacity);
    try body.append(0x4b);
    try emitBadInputIf(&body, error_offset);

    try emitI32Const(&body, len_offset);
    try emitLocalGet(&body, 0);
    try emitI32Store(&body);
    try emitI32Const(&body, ready_offset);
    try emitI32Const(&body, 1);
    try emitI32Store(&body);
    try emitI32Const(&body, error_offset);
    try emitI32Const(&body, error_code_ok);
    try emitI32Store(&body);
    try emitI32Const(&body, error_code_ok);
    try body.append(0x0b);

    try writer.appendU32Leb(@intCast(body.len));
    try writer.appendSlice(body.bytes[0..body.len]);
}

fn emitLocalGet(writer: *Writer, local_index: u32) error{OutputTooLarge}!void {
    try writer.append(0x20);
    try writer.appendU32Leb(local_index);
}

fn emitI32Const(writer: *Writer, value: i32) error{OutputTooLarge}!void {
    try writer.append(0x41);
    try writer.appendI32Leb(value);
}

fn emitI32Store(writer: *Writer) error{OutputTooLarge}!void {
    try writer.append(0x36);
    try writer.appendU32Leb(2);
    try writer.appendU32Leb(0);
}

fn emitBadInputIf(writer: *Writer, error_offset: i32) error{OutputTooLarge}!void {
    try writer.append(0x04);
    try writer.append(0x40);
    try emitI32Const(writer, error_offset);
    try emitI32Const(writer, error_code_bad_input);
    try emitI32Store(writer);
    try emitI32Const(writer, error_code_bad_input);
    try writer.append(0x0f);
    try writer.append(0x0b);
}

fn emitNoopFunction(writer: *Writer) error{OutputTooLarge}!void {
    var body_buffer: [8]u8 = undefined;
    var body = Writer{ .bytes = &body_buffer };
    try body.appendU32Leb(0);
    try body.append(0x0b);
    try writer.appendU32Leb(@intCast(body.len));
    try writer.appendSlice(body.bytes[0..body.len]);
}

fn emitLoweredMainFunction(writer: *Writer, lowered_main: ?i32) error{OutputTooLarge}!void {
    if (lowered_main) |value| {
        try emitReturnI32Function(writer, value);
        return;
    }
    var body_buffer: [8]u8 = undefined;
    var body = Writer{ .bytes = &body_buffer };
    try body.appendU32Leb(0);
    try body.append(0x00);
    try body.append(0x0b);
    try writer.appendU32Leb(@intCast(body.len));
    try writer.appendSlice(body.bytes[0..body.len]);
}

fn sourceHash(source: []const u8) u32 {
    var hash: u32 = fnv_offset_basis;
    for (source) |byte| {
        hash ^= byte;
        hash *%= fnv_prime;
    }
    return hash;
}

fn lowerMainI32Literal(source: []const u8) ?i32 {
    const signature_start = std.mem.indexOf(u8, source, lowered_main_i32_signature) orelse
        std.mem.indexOf(u8, source, legacy_main_i32_signature) orelse return null;
    const body_start_relative = std.mem.indexOfScalar(u8, source[signature_start..], '{') orelse return null;
    const body_start = signature_start + body_start_relative + 1;
    const body_end_relative = std.mem.indexOfScalar(u8, source[body_start..], '}') orelse return null;
    const body = source[body_start .. body_start + body_end_relative];
    const return_start_relative = std.mem.indexOf(u8, body, return_keyword) orelse return null;
    var index = return_start_relative + return_keyword.len;
    while (index < body.len and asciiWhitespace(body[index])) : (index += 1) {}
    const sign: i64 = if (index < body.len and body[index] == '-') sign: {
        index += 1;
        break :sign -1;
    } else 1;
    const digits_start = index;
    var value: i64 = 0;
    while (index < body.len and body[index] >= '0' and body[index] <= '9') : (index += 1) {
        value = value * 10 + @as(i64, body[index] - '0');
        if (value > @as(i64, std.math.maxInt(i32)) + 1) return null;
    }
    if (index == digits_start) return null;
    while (index < body.len and asciiWhitespace(body[index])) : (index += 1) {}
    if (index >= body.len or body[index] != ';') return null;
    const signed_value = value * sign;
    if (signed_value < std.math.minInt(i32) or signed_value > std.math.maxInt(i32)) return null;
    return @intCast(signed_value);
}

fn collectLoweredExports(source: []const u8, data_base: usize) LoweredExports {
    var context = collectLoweringContext(source, data_base);
    const stateful_release_artifact = sourceHasReleaseArtifactCommitPattern(source) and context.array_lengths.find("release_artifact") != null;
    const stateful_source_workspace = sourceHasSourceWorkspaceCommitPattern(source) and context.array_lengths.find("source_workspace") != null;
    const release_artifact_len_offset = if (stateful_release_artifact) reserveI32StateSlot(&context) else 0;
    const source_workspace_len_offset = if (stateful_source_workspace) reserveI32StateSlot(&context) else 0;
    const source_workspace_ready_offset = if (stateful_source_workspace) reserveI32StateSlot(&context) else 0;
    const last_error_offset = if (stateful_release_artifact or stateful_source_workspace) reserveI32StateSlot(&context) else 0;
    var lowered = LoweredExports{
        .memory_end = context.next_data_offset,
    };
    var index: usize = 0;
    while (std.mem.indexOf(u8, source[index..], export_fn_keyword)) |relative| {
        const fn_start = index + relative + export_fn_keyword.len;
        index = fn_start;
        const name_end = scanIdentifierEnd(source, fn_start) orelse continue;
        const name = source[fn_start..name_end];
        if (reservedExportName(name)) continue;
        const args_start = skipWhitespace(source, name_end);
        if (args_start >= source.len or source[args_start] != '(') continue;
        const args_end_relative = std.mem.indexOfScalar(u8, source[args_start..], ')') orelse continue;
        const args_end = args_start + args_end_relative;
        const args = source[args_start + 1 .. args_end];
        if (!lowerableExportArgs(args, name, stateful_release_artifact, stateful_source_workspace)) continue;
        const body_start_relative = std.mem.indexOfScalar(u8, source[args_end..], '{') orelse continue;
        const signature_tail = source[args_end + 1 .. args_end + body_start_relative];
        if (!integerReturnType(signature_tail)) continue;
        const body_start = args_end + body_start_relative + 1;
        const body_end_relative = std.mem.indexOfScalar(u8, source[body_start..], '}') orelse continue;
        const body = source[body_start .. body_start + body_end_relative];
        if (stateful_source_workspace and std.mem.eql(u8, name, "er_ui_source_workspace_ptr")) {
            const ptr = pointerForArray(&context, "source_workspace") orelse continue;
            lowered.append(name, ptr);
            continue;
        }
        if (stateful_source_workspace and std.mem.eql(u8, name, "er_ui_source_workspace_len")) {
            lowered.appendStateLoad(name, source_workspace_len_offset);
            continue;
        }
        if (stateful_source_workspace and std.mem.eql(u8, name, "er_ui_source_workspace_commit")) {
            const capacity = context.array_lengths.find("source_workspace") orelse continue;
            lowered.appendSourceWorkspaceCommit(name, capacity, source_workspace_len_offset, source_workspace_ready_offset, last_error_offset);
            continue;
        }
        if (stateful_release_artifact and std.mem.eql(u8, name, "er_ui_release_artifact_len")) {
            lowered.appendStateLoad(name, release_artifact_len_offset);
            continue;
        }
        if (stateful_release_artifact and std.mem.eql(u8, name, "er_ui_last_error")) {
            lowered.appendStateLoad(name, last_error_offset);
            continue;
        }
        if (stateful_release_artifact and std.mem.eql(u8, name, "er_ui_release_artifact_commit")) {
            const ptr = pointerForArray(&context, "release_artifact") orelse continue;
            const capacity = context.array_lengths.find("release_artifact") orelse continue;
            lowered.appendReleaseArtifactCommit(name, ptr, capacity, release_artifact_len_offset, last_error_offset);
            continue;
        }
        const value = parseReturnValue(body, &context) orelse continue;
        lowered.append(name, value);
    }
    lowered.memory_end = context.next_data_offset;
    return lowered;
}

fn lowerableExportArgs(args: []const u8, name: []const u8, stateful_release_artifact: bool, stateful_source_workspace: bool) bool {
    if (allWhitespace(args)) return true;
    const trimmed = trimAsciiWhitespace(args);
    if (stateful_release_artifact and std.mem.eql(u8, name, "er_ui_release_artifact_commit") and std.mem.eql(u8, trimmed, "artifact_len: usize")) return true;
    if (stateful_source_workspace and std.mem.eql(u8, name, "er_ui_source_workspace_commit") and std.mem.eql(u8, trimmed, "source_len: usize")) return true;
    return false;
}

fn reserveI32StateSlot(context: *LoweringContext) i32 {
    const offset: i32 = @intCast(context.next_data_offset);
    context.next_data_offset = alignForwardUsize(context.next_data_offset + state_slot_bytes, memory_alignment);
    return offset;
}

fn sourceHasReleaseArtifactCommitPattern(source: []const u8) bool {
    return std.mem.indexOf(u8, source, "export fn er_ui_release_artifact_commit(artifact_len: usize) u32") != null and
        std.mem.indexOf(u8, source, "if (artifact_len > release_artifact.len) return finishError(.bad_input);") != null and
        std.mem.indexOf(u8, source, "if (artifact_len < 4) return finishError(.bad_input);") != null and
        std.mem.indexOf(u8, source, "if (!std.mem.eql(u8, release_artifact[0..4], &.{ 0x00, 0x61, 0x73, 0x6d })) return finishError(.bad_input);") != null and
        std.mem.indexOf(u8, source, "release_artifact_len = artifact_len;") != null and
        std.mem.indexOf(u8, source, "last_error = .ok;") != null and
        std.mem.indexOf(u8, source, "return @intFromEnum(ErrorCode.ok);") != null;
}

fn sourceHasSourceWorkspaceCommitPattern(source: []const u8) bool {
    return std.mem.indexOf(u8, source, "export fn er_ui_source_workspace_commit(source_len: usize) u32") != null and
        std.mem.indexOf(u8, source, "if (source_len > source_workspace.len) return finishError(.bad_input);") != null and
        std.mem.indexOf(u8, source, "source_workspace_len = source_len;") != null and
        std.mem.indexOf(u8, source, "source_workspace_ready = true;") != null and
        std.mem.indexOf(u8, source, "last_error = .ok;") != null and
        std.mem.indexOf(u8, source, "return @intFromEnum(ErrorCode.ok);") != null;
}

fn collectLoweringContext(source: []const u8, data_base: usize) LoweringContext {
    var context = LoweringContext{
        .constants = .{},
        .array_lengths = .{},
        .pointer_values = .{},
        .zero_values = .{},
        .next_data_offset = data_base,
    };
    collectIntegerConsts(source, &context.constants);
    collectArrayLengths(source, &context);
    collectZeroValues(source, &context.zero_values);
    collectEnumInitialValues(source, &context.zero_values);
    return context;
}

fn collectIntegerConsts(source: []const u8, constants: *ConstIndex) void {
    var index: usize = 0;
    while (std.mem.indexOf(u8, source[index..], const_keyword)) |relative| {
        const name_start = skipWhitespace(source, index + relative + const_keyword.len);
        index = name_start;
        const name_end = scanIdentifierEnd(source, name_start) orelse continue;
        const name = source[name_start..name_end];
        const line_end = findLineEnd(source, name_end);
        const equals_relative = std.mem.indexOfScalar(u8, source[name_end..line_end], '=') orelse continue;
        const value_start = skipWhitespace(source, name_end + equals_relative + 1);
        const semicolon_relative = std.mem.indexOfScalar(u8, source[value_start..line_end], ';') orelse continue;
        const value_end = value_start + semicolon_relative;
        const value = parseI32Expression(source[value_start..value_end], constants) orelse continue;
        constants.append(name, value);
    }
}

fn collectArrayLengths(source: []const u8, context: *LoweringContext) void {
    collectArrayLengthsForKeyword(source, "var ", context);
    collectArrayLengthsForKeyword(source, const_keyword, context);
}

fn collectArrayLengthsForKeyword(source: []const u8, keyword: []const u8, context: *LoweringContext) void {
    var index: usize = 0;
    while (std.mem.indexOf(u8, source[index..], keyword)) |relative| {
        const name_start = skipWhitespace(source, index + relative + keyword.len);
        index = name_start;
        const name_end = scanIdentifierEnd(source, name_start) orelse continue;
        const name = source[name_start..name_end];
        const line_end = findLineEnd(source, name_end);
        const bracket_relative = std.mem.indexOf(u8, source[name_end..line_end], "[") orelse continue;
        const len_start = name_end + bracket_relative + 1;
        const bracket_end_relative = std.mem.indexOfScalar(u8, source[len_start..line_end], ']') orelse continue;
        const len_end = len_start + bracket_end_relative;
        const element_type_start = skipWhitespace(source, len_end + 1);
        if (element_type_start + "u8".len > line_end or !std.mem.eql(u8, source[element_type_start .. element_type_start + "u8".len], "u8")) continue;
        const value = parseI32Expression(source[len_start..len_end], &context.constants) orelse continue;
        context.array_lengths.append(name, value);
    }
}

fn collectZeroValues(source: []const u8, zero_values: *ConstIndex) void {
    var index: usize = 0;
    while (std.mem.indexOf(u8, source[index..], "var ")) |relative| {
        const name_start = skipWhitespace(source, index + relative + "var ".len);
        index = name_start;
        const name_end = scanIdentifierEnd(source, name_start) orelse continue;
        const name = source[name_start..name_end];
        const line_end = findLineEnd(source, name_end);
        const equals_relative = std.mem.indexOfScalar(u8, source[name_end..line_end], '=') orelse continue;
        const value_start = skipWhitespace(source, name_end + equals_relative + 1);
        if (value_start + 2 <= line_end and std.mem.eql(u8, source[value_start .. value_start + 2], "0;")) {
            zero_values.append(name, 0);
        }
    }
}

fn collectEnumInitialValues(source: []const u8, values: *ConstIndex) void {
    var index: usize = 0;
    while (std.mem.indexOf(u8, source[index..], "var ")) |relative| {
        const name_start = skipWhitespace(source, index + relative + "var ".len);
        index = name_start;
        const name_end = scanIdentifierEnd(source, name_start) orelse continue;
        const name = source[name_start..name_end];
        const line_end = findLineEnd(source, name_end);
        const colon_relative = std.mem.indexOfScalar(u8, source[name_end..line_end], ':') orelse continue;
        const type_start = skipWhitespace(source, name_end + colon_relative + 1);
        const type_end = scanIdentifierEnd(source, type_start) orelse continue;
        const enum_name = source[type_start..type_end];
        const equals_relative = std.mem.indexOfScalar(u8, source[type_end..line_end], '=') orelse continue;
        const value_start = skipWhitespace(source, type_end + equals_relative + 1);
        if (value_start >= line_end or source[value_start] != '.') continue;
        const field_start = value_start + 1;
        const field_end = scanIdentifierEnd(source, field_start) orelse continue;
        if (skipWhitespace(source, field_end) >= line_end or source[skipWhitespace(source, field_end)] != ';') continue;
        const value = findEnumFieldValue(source, enum_name, source[field_start..field_end]) orelse continue;
        values.append(name, value);
    }
}

fn findEnumFieldValue(source: []const u8, enum_name: []const u8, field_name: []const u8) ?i32 {
    var search_start: usize = 0;
    while (std.mem.indexOf(u8, source[search_start..], "const ")) |relative| {
        const name_start = skipWhitespace(source, search_start + relative + "const ".len);
        search_start = name_start;
        const name_end = scanIdentifierEnd(source, name_start) orelse continue;
        if (!std.mem.eql(u8, source[name_start..name_end], enum_name)) continue;
        const line_end = findLineEnd(source, name_end);
        if (std.mem.indexOf(u8, source[name_end..line_end], "enum") == null) continue;
        const body_start_relative = std.mem.indexOfScalar(u8, source[name_end..], '{') orelse return null;
        const body_start = name_end + body_start_relative + 1;
        const body_end_relative = std.mem.indexOfScalar(u8, source[body_start..], '}') orelse return null;
        return findEnumFieldValueInBody(source[body_start .. body_start + body_end_relative], field_name);
    }
    return null;
}

fn findEnumFieldValueInBody(body: []const u8, field_name: []const u8) ?i32 {
    var index: usize = 0;
    while (index < body.len) {
        index = skipWhitespaceAndCommas(body, index);
        const name_end = scanIdentifierEnd(body, index) orelse break;
        const name = body[index..name_end];
        index = skipWhitespace(body, name_end);
        if (index >= body.len or body[index] != '=') {
            index = name_end;
            continue;
        }
        const value_start = skipWhitespace(body, index + 1);
        const value_end = scanIntegerEnd(body, value_start) orelse continue;
        const value = parseI32Literal(body[value_start..value_end]) orelse continue;
        if (std.mem.eql(u8, name, field_name)) return value;
        index = value_end;
    }
    return null;
}

fn parseReturnValue(body: []const u8, context: *LoweringContext) ?i32 {
    const return_start_relative = std.mem.indexOf(u8, body, return_keyword) orelse return null;
    if (!allWhitespace(body[0..return_start_relative])) return null;
    var index = skipWhitespace(body, return_start_relative + return_keyword.len);
    if (std.mem.startsWith(u8, body[index..], "@intCast(")) {
        const value_start = index + "@intCast(".len;
        const value_end_relative = std.mem.indexOfScalar(u8, body[value_start..], ')') orelse return null;
        const value_end = value_start + value_end_relative;
        index = skipWhitespace(body, value_end + 1);
        if (index >= body.len or body[index] != ';') return null;
        return parseValueExpression(body[value_start..value_end], context);
    }
    if (std.mem.startsWith(u8, body[index..], "@intFromEnum(")) {
        const value_start = index + "@intFromEnum(".len;
        const value_end_relative = std.mem.indexOfScalar(u8, body[value_start..], ')') orelse return null;
        const value_end = value_start + value_end_relative;
        index = skipWhitespace(body, value_end + 1);
        if (index >= body.len or body[index] != ';') return null;
        return parseValueExpression(body[value_start..value_end], context);
    }
    if (std.mem.startsWith(u8, body[index..], "@intFromPtr(")) {
        const value_start = index + "@intFromPtr(".len;
        const value_end_relative = std.mem.indexOfScalar(u8, body[value_start..], ')') orelse return null;
        const value_end = value_start + value_end_relative;
        index = skipWhitespace(body, value_end + 1);
        if (index >= body.len or body[index] != ';') return null;
        return parsePointerExpression(body[value_start..value_end], context);
    }
    const value_end_relative = std.mem.indexOfScalar(u8, body[index..], ';') orelse return null;
    return parseValueExpression(body[index .. index + value_end_relative], context);
}

fn parseValueExpression(raw: []const u8, context: *const LoweringContext) ?i32 {
    const text = trimAsciiWhitespace(raw);
    if (text.len == 0) return null;
    if (parseI32Literal(text)) |value| return value;
    if (std.mem.endsWith(u8, text, ".len")) {
        return context.array_lengths.find(text[0 .. text.len - ".len".len]);
    }
    if (context.constants.find(text)) |value| return value;
    return context.zero_values.find(text);
}

fn parsePointerExpression(raw: []const u8, context: *LoweringContext) ?i32 {
    const text = trimAsciiWhitespace(raw);
    if (text.len == 0) return null;
    if (text[0] == '&') return pointerForArray(context, text[1..]);
    if (std.mem.endsWith(u8, text, "[0..].ptr")) {
        return pointerForArray(context, text[0 .. text.len - "[0..].ptr".len]);
    }
    return null;
}

fn pointerForArray(context: *LoweringContext, name: []const u8) ?i32 {
    if (context.pointer_values.find(name)) |value| return value;
    const len = context.array_lengths.find(name) orelse return null;
    if (context.next_data_offset > std.math.maxInt(i32)) return null;
    const offset: i32 = @intCast(context.next_data_offset);
    context.pointer_values.append(name, offset);
    context.next_data_offset = alignForwardUsize(context.next_data_offset + @as(usize, @intCast(len)), memory_alignment);
    return offset;
}

fn parseI32Expression(raw: []const u8, constants: *const ConstIndex) ?i32 {
    var sum: i64 = 0;
    var term_start: usize = 0;
    while (term_start < raw.len) {
        const plus_relative = std.mem.indexOfScalar(u8, raw[term_start..], '+');
        const term_end = if (plus_relative) |relative| term_start + relative else raw.len;
        const term = parseI32Product(raw[term_start..term_end], constants) orelse return null;
        sum += term;
        if (sum < std.math.minInt(i32) or sum > std.math.maxInt(i32)) return null;
        if (plus_relative == null) break;
        term_start = term_end + 1;
    }
    return @intCast(sum);
}

fn parseI32Product(raw: []const u8, constants: *const ConstIndex) ?i64 {
    var product: i64 = 1;
    var factor_start: usize = 0;
    var factor_count: usize = 0;
    while (factor_start < raw.len) {
        const multiply_relative = std.mem.indexOfScalar(u8, raw[factor_start..], '*');
        const factor_end = if (multiply_relative) |relative| factor_start + relative else raw.len;
        const factor = parseI32Factor(raw[factor_start..factor_end], constants) orelse return null;
        product *= factor;
        if (product < std.math.minInt(i32) or product > std.math.maxInt(i32)) return null;
        factor_count += 1;
        if (multiply_relative == null) break;
        factor_start = factor_end + 1;
    }
    if (factor_count == 0) return null;
    return product;
}

fn parseI32Factor(raw: []const u8, constants: *const ConstIndex) ?i64 {
    const text = trimAsciiWhitespace(raw);
    if (text.len == 0) return null;
    if (parseI32Literal(text)) |value| return value;
    if (constants.find(text)) |value| return value;
    return null;
}

fn parseI32Literal(text: []const u8) ?i32 {
    if (text.len == 0) return null;
    var index: usize = 0;
    const sign: i64 = if (text[index] == '-') sign: {
        index += 1;
        break :sign -1;
    } else 1;
    if (index >= text.len) return null;
    var value: i64 = 0;
    while (index < text.len) : (index += 1) {
        const byte = text[index];
        if (byte < '0' or byte > '9') return null;
        value = value * 10 + @as(i64, byte - '0');
        if (value > @as(i64, std.math.maxInt(i32)) + 1) return null;
    }
    const signed_value = value * sign;
    if (signed_value < std.math.minInt(i32) or signed_value > std.math.maxInt(i32)) return null;
    return @intCast(signed_value);
}

fn integerReturnType(signature_tail: []const u8) bool {
    return std.mem.indexOf(u8, signature_tail, "i32") != null or
        std.mem.indexOf(u8, signature_tail, "u32") != null or
        std.mem.indexOf(u8, signature_tail, "usize") != null;
}

fn reservedExportName(name: []const u8) bool {
    return std.mem.eql(u8, name, "er_app_main") or
        std.mem.startsWith(u8, name, "er_app_");
}

fn scanIdentifierEnd(source: []const u8, start: usize) ?usize {
    if (start >= source.len or !identifierStart(source[start])) return null;
    var index = start + 1;
    while (index < source.len and identifierContinue(source[index])) : (index += 1) {}
    return index;
}

fn scanIntegerEnd(source: []const u8, start: usize) ?usize {
    if (start >= source.len) return null;
    var index = start;
    if (source[index] == '-') index += 1;
    const digits_start = index;
    while (index < source.len and source[index] >= '0' and source[index] <= '9') : (index += 1) {}
    if (index == digits_start) return null;
    return index;
}

fn skipWhitespace(source: []const u8, start: usize) usize {
    var index = start;
    while (index < source.len and asciiWhitespace(source[index])) : (index += 1) {}
    return index;
}

fn skipWhitespaceAndCommas(source: []const u8, start: usize) usize {
    var index = start;
    while (index < source.len and (asciiWhitespace(source[index]) or source[index] == ',')) : (index += 1) {}
    return index;
}

fn trimAsciiWhitespace(source: []const u8) []const u8 {
    var start: usize = 0;
    while (start < source.len and asciiWhitespace(source[start])) : (start += 1) {}
    var end = source.len;
    while (end > start and asciiWhitespace(source[end - 1])) : (end -= 1) {}
    return source[start..end];
}

fn allWhitespace(source: []const u8) bool {
    for (source) |byte| {
        if (!asciiWhitespace(byte)) return false;
    }
    return true;
}

fn findLineEnd(source: []const u8, start: usize) usize {
    var index = start;
    while (index < source.len and source[index] != '\n' and source[index] != '\r') : (index += 1) {}
    return index;
}

fn identifierStart(byte: u8) bool {
    return (byte >= 'a' and byte <= 'z') or (byte >= 'A' and byte <= 'Z') or byte == '_';
}

fn identifierContinue(byte: u8) bool {
    return identifierStart(byte) or (byte >= '0' and byte <= '9');
}

fn asciiWhitespace(byte: u8) bool {
    return switch (byte) {
        ' ', '\n', '\r', '\t' => true,
        else => false,
    };
}

fn memoryPagesForBytes(byte_len: usize) u32 {
    const needed = @as(u64, @intCast(byte_len));
    return @intCast((needed + wasm_page_mask) >> wasm_page_shift);
}

fn alignForwardUsize(value: usize, alignment: usize) usize {
    const mask = alignment - 1;
    return (value + mask) & ~mask;
}

fn validSourceObject(source: []const u8) bool {
    return source.len >= object_magic.len and std.mem.eql(u8, source[0..object_magic.len], object_magic);
}

const CompilerInputError = error{
    Corrupt,
    NotWorkspace,
    MissingRootSource,
};

const ObjectView = struct {
    body: []const u8,
};

const LabelRef = struct {
    label: []const u8,
    object_len: usize,
};

const FileEntry = struct {
    label: Label,
    object: []const u8,
    queued: bool = false,
};

const WorkspaceInfo = struct {
    file_count: u32,
    root_source: []const u8,
    root_label: []const u8,
    manifest: []const u8,
};

const CompilerOutputInfo = struct {
    zir_instruction_count: u32,
    zir_extra_count: u32,
    zir_string_bytes: u32,
    compiler_memory_used: u32,
    analyzed_file_count: u32,
    import_edge_count: u32,
    unresolved_import_count: u32,
    truncated_import_count: u32,
    manifest_file_refs_scanned: u32,
    file_object_decodes: u32,
    file_lookup_count: u32,
    queued_import_count: u32,
    pruned_import_count: u32,
    parsed_source_bytes: u32,
    indexed_file_count: u32,
    lowered_main_count: u32,
    lowered_export_count: u32,
};

const ConstEntry = struct {
    name: []const u8,
    value: i32,
};

const ConstIndex = struct {
    entries: [max_lowered_consts]ConstEntry = undefined,
    count: usize = 0,

    fn append(index: *ConstIndex, name: []const u8, value: i32) void {
        if (index.count >= index.entries.len) return;
        index.entries[index.count] = .{ .name = name, .value = value };
        index.count += 1;
    }

    fn find(index: *const ConstIndex, name: []const u8) ?i32 {
        for (index.entries[0..index.count]) |entry| {
            if (std.mem.eql(u8, entry.name, name)) return entry.value;
        }
        return null;
    }
};

const LoweringContext = struct {
    constants: ConstIndex,
    array_lengths: ConstIndex,
    pointer_values: ConstIndex,
    zero_values: ConstIndex,
    next_data_offset: usize,
};

const LoweredFunctionKind = enum {
    return_i32,
    state_load_i32,
    release_artifact_commit,
    source_workspace_commit,
};

const LoweredExport = struct {
    name: []const u8,
    value: i32,
    limit: i32 = 0,
    state_offset: i32 = 0,
    ready_offset: i32 = 0,
    error_offset: i32 = 0,
    kind: LoweredFunctionKind = .return_i32,
};

const LoweredExports = struct {
    entries: [max_lowered_exports]LoweredExport = undefined,
    count: u32 = 0,
    memory_end: usize = 0,

    fn append(exports: *LoweredExports, name: []const u8, value: i32) void {
        exports.appendEntry(.{ .name = name, .value = value });
    }

    fn appendStateLoad(exports: *LoweredExports, name: []const u8, state_offset: i32) void {
        exports.appendEntry(.{ .name = name, .value = state_offset, .kind = .state_load_i32 });
    }

    fn appendReleaseArtifactCommit(exports: *LoweredExports, name: []const u8, ptr: i32, capacity: i32, len_offset: i32, error_offset: i32) void {
        exports.appendEntry(.{
            .name = name,
            .value = ptr,
            .limit = capacity,
            .state_offset = len_offset,
            .error_offset = error_offset,
            .kind = .release_artifact_commit,
        });
    }

    fn appendSourceWorkspaceCommit(exports: *LoweredExports, name: []const u8, capacity: i32, len_offset: i32, ready_offset: i32, error_offset: i32) void {
        exports.appendEntry(.{
            .name = name,
            .value = 0,
            .limit = capacity,
            .state_offset = len_offset,
            .ready_offset = ready_offset,
            .error_offset = error_offset,
            .kind = .source_workspace_commit,
        });
    }

    fn appendEntry(exports: *LoweredExports, lowered: LoweredExport) void {
        if (exports.count >= exports.entries.len) return;
        if (reservedExportName(lowered.name)) return;
        for (exports.entries[0..@intCast(exports.count)]) |entry| {
            if (std.mem.eql(u8, entry.name, lowered.name)) return;
        }
        exports.entries[@intCast(exports.count)] = lowered;
        exports.count += 1;
    }
};

const Label = struct {
    bytes: [vfs_label_max]u8 = [_]u8{0} ** vfs_label_max,
    len: u16 = 0,

    fn init(value: []const u8) Label {
        var label: Label = .{ .len = @intCast(value.len) };
        @memcpy(label.bytes[0..value.len], value);
        return label;
    }

    fn slice(label: *const Label) []const u8 {
        return label.bytes[0..label.len];
    }
};

fn workspaceFromSourceObject(source: []const u8, root_label: []const u8) CompilerInputError!WorkspaceInfo {
    const outer = try decodeObject(source);
    const manifest = outer.body;
    if (manifest.len < workspace_manifest_header_bytes or !std.mem.eql(u8, manifest[0..workspace_source_marker.len], workspace_source_marker)) return error.NotWorkspace;
    if ((load16(manifest[8..10]) orelse return error.Corrupt) != 1) return error.Corrupt;
    if ((load16(manifest[10..12]) orelse return error.Corrupt) != 0) return error.Corrupt;

    const file_count = load32(manifest[12..16]) orelse return error.Corrupt;
    if (file_count == 0) return error.Corrupt;

    var index: usize = workspace_manifest_header_bytes;
    var remaining = file_count;
    var root_source: ?[]const u8 = null;
    while (remaining > 0) : (remaining -= 1) {
        if (index > manifest.len or vfs_label_ref_bytes > manifest.len - index) return error.Corrupt;
        const label_ref = try decodeLabelRef(manifest[index..][0..vfs_label_ref_bytes]);
        index += vfs_label_ref_bytes;

        if (index > manifest.len or label_ref.object_len > manifest.len - index) return error.Corrupt;
        const file_object = manifest[index..][0..label_ref.object_len];
        index += label_ref.object_len;

        if (std.mem.eql(u8, label_ref.label, root_label)) {
            const file_view = try decodeObject(file_object);
            root_source = file_view.body;
        }
    }
    if (index != manifest.len) return error.Corrupt;
    return .{
        .file_count = file_count,
        .manifest = manifest,
        .root_label = root_label,
        .root_source = root_source orelse return error.MissingRootSource,
    };
}

fn analyzeZigRoot(scratch: []u8, source: []const u8) error{ InvalidZig, OutOfMemory }!CompilerOutputInfo {
    if (source.len + 1 > scratch.len) return error.OutOfMemory;
    var fixed = std.heap.FixedBufferAllocator.init(scratch);
    const allocator = fixed.allocator();
    const sentinel_source = try allocator.dupeZ(u8, source);
    var tree = try std.zig.Ast.parse(allocator, sentinel_source, .zig);
    defer tree.deinit(allocator);
    if (tree.errors.len != 0) return error.InvalidZig;
    var zir = try std.zig.AstGen.generate(allocator, tree);
    defer zir.deinit(allocator);
    if (zir.hasCompileErrors()) return error.InvalidZig;
    const compiler_memory_used = fixed.end_index;
    return .{
        .zir_instruction_count = @intCast(zir.instructions.len),
        .zir_extra_count = @intCast(zir.extra.len),
        .zir_string_bytes = @intCast(zir.string_bytes.len),
        .compiler_memory_used = @intCast(compiler_memory_used),
        .analyzed_file_count = 1,
        .import_edge_count = countZirImports(zir),
        .unresolved_import_count = 0,
        .truncated_import_count = 0,
        .manifest_file_refs_scanned = 0,
        .file_object_decodes = 0,
        .file_lookup_count = 0,
        .queued_import_count = 0,
        .pruned_import_count = 0,
        .parsed_source_bytes = @intCast(source.len),
        .indexed_file_count = 0,
        .lowered_main_count = 0,
        .lowered_export_count = collectLoweredExports(source, 0).count,
    };
}

fn analyzeWorkspaceGraph(scratch: []u8, workspace: WorkspaceInfo) error{ InvalidZig, OutOfMemory }!CompilerOutputInfo {
    var fixed = std.heap.FixedBufferAllocator.init(scratch);
    const allocator = fixed.allocator();
    var result = CompilerOutputInfo{
        .zir_instruction_count = 0,
        .zir_extra_count = 0,
        .zir_string_bytes = 0,
        .compiler_memory_used = 0,
        .analyzed_file_count = 0,
        .import_edge_count = 0,
        .unresolved_import_count = 0,
        .truncated_import_count = 0,
        .manifest_file_refs_scanned = 0,
        .file_object_decodes = 0,
        .file_lookup_count = 0,
        .queued_import_count = 0,
        .pruned_import_count = 0,
        .parsed_source_bytes = 0,
        .indexed_file_count = 0,
        .lowered_main_count = 0,
        .lowered_export_count = 0,
    };
    const files = buildWorkspaceIndex(allocator, workspace.manifest, workspace.file_count, &result) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.InvalidZig => return error.InvalidZig,
    };
    const root_index = findIndexedFileIndex(files, workspace.root_label) orelse return error.InvalidZig;

    const queue = try allocator.alloc(usize, workspace.file_count);
    var queue_len: usize = 1;
    var queue_index: usize = 0;
    queue[0] = root_index;
    files[root_index].queued = true;
    result.queued_import_count = 1;

    while (queue_index < queue_len) : (queue_index += 1) {
        const file_index = queue[queue_index];
        const label = files[file_index].label.slice();
        result.file_lookup_count += 1;
        const file_source = decodeIndexedFile(files[file_index]) orelse return error.InvalidZig;
        result.file_object_decodes += 1;
        result.parsed_source_bytes += @intCast(file_source.len);
        if (queue_index == 0) {
            const sentinel_source = try allocator.dupeZ(u8, file_source);
            var tree = try std.zig.Ast.parse(allocator, sentinel_source, .zig);
            defer tree.deinit(allocator);
            if (tree.errors.len != 0) return error.InvalidZig;
            var zir = try std.zig.AstGen.generate(allocator, tree);
            defer zir.deinit(allocator);
            if (zir.hasCompileErrors()) return error.InvalidZig;

            result.zir_instruction_count += @intCast(zir.instructions.len);
            result.zir_extra_count += @intCast(zir.extra.len);
            result.zir_string_bytes += @intCast(zir.string_bytes.len);
        }
        result.analyzed_file_count += 1;

        var imports = ImportScanner{ .source = file_source };
        while (imports.next()) |import_name| enqueueImport(files, queue, &queue_len, label, import_name, &result);
    }

    result.compiler_memory_used = @intCast(fixed.end_index);
    if (lowerMainI32Literal(workspace.root_source) != null) result.lowered_main_count = 1;
    result.lowered_export_count = collectLoweredExports(workspace.root_source, 0).count;
    return result;
}

fn enqueueImport(files: []FileEntry, queue: []usize, queue_len: *usize, importer_label: []const u8, import_name: []const u8, result: *CompilerOutputInfo) void {
    result.import_edge_count += 1;
    if (virtualImport(import_name)) return;
    var resolved: [vfs_label_max]u8 = undefined;
    const resolved_label = resolveImportLabel(importer_label, import_name, &resolved) orelse {
        result.unresolved_import_count += 1;
        return;
    };
    result.file_lookup_count += 1;
    const resolved_index = findIndexedFileIndex(files, resolved_label) orelse {
        if (prunedSourceImport(resolved_label)) {
            result.pruned_import_count += 1;
            return;
        }
        result.unresolved_import_count += 1;
        return;
    };
    if (files[resolved_index].queued) return;
    if (queue_len.* >= queue.len) {
        result.truncated_import_count += 1;
        return;
    }
    files[resolved_index].queued = true;
    queue[queue_len.*] = resolved_index;
    queue_len.* += 1;
    result.queued_import_count += 1;
}

fn buildWorkspaceIndex(allocator: std.mem.Allocator, manifest: []const u8, file_count: u32, result: *CompilerOutputInfo) error{ InvalidZig, OutOfMemory }![]FileEntry {
    const entries = try allocator.alloc(FileEntry, file_count);
    var index: usize = workspace_manifest_header_bytes;
    var file_index: usize = 0;
    while (file_index < entries.len) : (file_index += 1) {
        if (index > manifest.len or vfs_label_ref_bytes > manifest.len - index) return error.InvalidZig;
        const label_ref = decodeLabelRef(manifest[index..][0..vfs_label_ref_bytes]) catch return error.InvalidZig;
        result.manifest_file_refs_scanned += 1;
        index += vfs_label_ref_bytes;
        if (index > manifest.len or label_ref.object_len > manifest.len - index) return error.InvalidZig;
        const file_object = manifest[index..][0..label_ref.object_len];
        index += label_ref.object_len;
        entries[file_index] = .{
            .label = Label.init(label_ref.label),
            .object = file_object,
        };
        if (file_index != 0 and std.mem.order(u8, entries[file_index - 1].label.slice(), entries[file_index].label.slice()) != .lt) return error.InvalidZig;
    }
    if (index != manifest.len) return error.InvalidZig;
    result.indexed_file_count = @intCast(entries.len);
    return entries;
}

fn findIndexedFileIndex(files: []const FileEntry, label: []const u8) ?usize {
    var low: usize = 0;
    var high: usize = files.len;
    while (low < high) {
        const mid = low + (high - low) / 2;
        switch (std.mem.order(u8, files[mid].label.slice(), label)) {
            .eq => return mid,
            .lt => low = mid + 1,
            .gt => high = mid,
        }
    }
    return null;
}

fn decodeIndexedFile(file: FileEntry) ?[]const u8 {
    const view = decodeObject(file.object) catch return null;
    return view.body;
}

const ImportScanner = struct {
    source: []const u8,
    index: usize = 0,

    fn next(scanner: *ImportScanner) ?[]const u8 {
        while (std.mem.indexOf(u8, scanner.source[scanner.index..], "@import(\"")) |relative| {
            const start = scanner.index + relative + "@import(\"".len;
            scanner.index = start;
            var end = start;
            while (end < scanner.source.len and scanner.source[end] != '"') : (end += 1) {
                if (scanner.source[end] == '\\' or scanner.source[end] == '\n' or scanner.source[end] == '\r') break;
            }
            if (end >= scanner.source.len or scanner.source[end] != '"') continue;
            scanner.index = end + 1;
            return scanner.source[start..end];
        }
        scanner.index = scanner.source.len;
        return null;
    }
};

fn countZirImports(zir: std.zig.Zir) u32 {
    const imports_index = zir.extra[@intFromEnum(std.zig.Zir.ExtraIndex.imports)];
    if (imports_index == 0) return 0;
    return zir.extraData(std.zig.Zir.Inst.Imports, imports_index).data.imports_len;
}

fn findWorkspaceFile(manifest: []const u8, label: []const u8) ?[]const u8 {
    if (manifest.len < workspace_manifest_header_bytes) return null;
    const file_count = load32(manifest[12..16]) orelse return null;
    var index: usize = workspace_manifest_header_bytes;
    var remaining = file_count;
    while (remaining > 0) : (remaining -= 1) {
        if (index > manifest.len or vfs_label_ref_bytes > manifest.len - index) return null;
        const label_ref = decodeLabelRef(manifest[index..][0..vfs_label_ref_bytes]) catch return null;
        index += vfs_label_ref_bytes;
        if (index > manifest.len or label_ref.object_len > manifest.len - index) return null;
        const file_object = manifest[index..][0..label_ref.object_len];
        const file_view = decodeObject(file_object) catch return null;
        index += label_ref.object_len;
        if (std.mem.eql(u8, label_ref.label, label)) return file_view.body;
    }
    return null;
}

fn virtualImport(import_name: []const u8) bool {
    return switch (import_name.len) {
        "builtin".len => std.mem.eql(u8, import_name, "builtin"),
        "build_options".len => std.mem.eql(u8, import_name, "build_options"),
        "embedded_source_object".len => std.mem.eql(u8, import_name, "embedded_source_object") or
            std.mem.eql(u8, import_name, "embedded_wasm_compiler"),
        else => false,
    };
}

fn prunedSourceImport(resolved_label: []const u8) bool {
    if (std.mem.endsWith(u8, resolved_label, "_test.zig")) return true;
    switch (resolved_label.len) {
        "compiler/zig/lib/std/Build.zig".len => if (std.mem.eql(u8, resolved_label, "compiler/zig/lib/std/Build.zig")) return true,
        "compiler/zig/lib/std/c.zig".len => if (std.mem.eql(u8, resolved_label, "compiler/zig/lib/std/c.zig")) return true,
        "compiler/zig/lib/std/crypto.zig".len => if (std.mem.eql(u8, resolved_label, "compiler/zig/lib/std/crypto.zig")) return true,
        "compiler/zig/lib/std/http.zig".len => if (std.mem.eql(u8, resolved_label, "compiler/zig/lib/std/http.zig")) return true,
        "compiler/zig/lib/std/Io/Threaded.zig".len => if (std.mem.eql(u8, resolved_label, "compiler/zig/lib/std/Io/Threaded.zig")) return true,
        "compiler/zig/lib/std/Io/Uring.zig".len => if (std.mem.eql(u8, resolved_label, "compiler/zig/lib/std/Io/Uring.zig") or
            std.mem.eql(u8, resolved_label, "compiler/zig/lib/std/valgrind.zig")) return true,
        "compiler/zig/lib/std/os.zig".len => if (std.mem.eql(u8, resolved_label, "compiler/zig/lib/std/os.zig") or
            std.mem.eql(u8, resolved_label, "compiler/zig/lib/std/tz.zig")) return true,
        "compiler/zig/lib/std/tar.zig".len => if (std.mem.eql(u8, resolved_label, "compiler/zig/lib/std/tar.zig") or
            std.mem.eql(u8, resolved_label, "compiler/zig/lib/std/zip.zig")) return true,
        "compiler/zig/lib/std/testing.zig".len => if (std.mem.eql(u8, resolved_label, "compiler/zig/lib/std/testing.zig")) return true,
        else => {},
    }
    if (std.mem.startsWith(u8, resolved_label, "compiler/zig/lib/std/Build/")) return true;
    if (std.mem.startsWith(u8, resolved_label, "compiler/zig/lib/std/c/")) return true;
    if (std.mem.startsWith(u8, resolved_label, "compiler/zig/lib/std/crypto/")) return true;
    if (std.mem.startsWith(u8, resolved_label, "compiler/zig/lib/std/debug/")) return true;
    if (std.mem.startsWith(u8, resolved_label, "compiler/zig/lib/std/http/")) return true;
    if (std.mem.startsWith(u8, resolved_label, "compiler/zig/lib/std/os/")) return true;
    if (std.mem.startsWith(u8, resolved_label, "compiler/zig/lib/std/tar/")) return true;
    if (std.mem.startsWith(u8, resolved_label, "compiler/zig/lib/std/testing/")) return true;
    if (std.mem.startsWith(u8, resolved_label, "compiler/zig/lib/std/tz/")) return true;
    if (std.mem.startsWith(u8, resolved_label, "compiler/zig/lib/std/zig/llvm/")) return true;
    if (std.mem.startsWith(u8, resolved_label, "compiler/zig/lib/compiler/")) return true;
    if (std.mem.startsWith(u8, resolved_label, "compiler/zig/src/libs/")) return true;
    if (std.mem.startsWith(u8, resolved_label, "compiler/zig/src/Package/Fetch/")) return true;
    return false;
}

fn resolveImportLabel(importer_label: []const u8, import_name: []const u8, out: *[vfs_label_max]u8) ?[]const u8 {
    switch (import_name.len) {
        "std".len => if (std.mem.eql(u8, import_name, "std")) return copyResolved(out, "compiler/zig/lib/std/std.zig"),
        "root".len => if (std.mem.eql(u8, import_name, "root")) return copyResolved(out, importer_label),
        else => {},
    }
    if (import_name.len == 0 or import_name.len > vfs_label_max) return null;
    if (std.mem.startsWith(u8, import_name, "/")) return null;

    var raw: [vfs_label_max]u8 = undefined;
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

fn normalizeLabel(raw: []const u8, out: *[vfs_label_max]u8) ?[]const u8 {
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

fn copyResolved(out: *[vfs_label_max]u8, value: []const u8) ?[]const u8 {
    if (value.len > out.len) return null;
    @memcpy(out[0..value.len], value);
    return out[0..value.len];
}

fn decodeObject(canonical: []const u8) CompilerInputError!ObjectView {
    if (canonical.len < object_header_bytes or !std.mem.eql(u8, canonical[0..object_magic.len], object_magic)) return error.Corrupt;
    if ((load16(canonical[8..10]) orelse return error.Corrupt) != 1) return error.Corrupt;
    if ((load16(canonical[10..12]) orelse return error.Corrupt) != object_kind_bytes) return error.Corrupt;

    const owner_count = load16(canonical[24..26]) orelse return error.Corrupt;
    const envelope_count = load16(canonical[26..28]) orelse return error.Corrupt;
    const child_count = load32(canonical[28..32]) orelse return error.Corrupt;
    const body_len = load64(canonical[32..40]) orelse return error.Corrupt;
    const body_start = object_header_bytes +
        @as(usize, owner_count) * object_owner_bytes +
        @as(usize, envelope_count) * object_envelope_bytes +
        @as(usize, @intCast(child_count)) * object_child_bytes;
    const body_size: usize = @intCast(body_len);
    if (body_start > canonical.len or body_size > canonical.len - body_start) return error.Corrupt;
    if (body_start + body_size != canonical.len) return error.Corrupt;
    return .{ .body = canonical[body_start..][0..body_size] };
}

fn decodeLabelRef(raw: []const u8) CompilerInputError!LabelRef {
    if (raw.len < vfs_label_ref_bytes) return error.Corrupt;
    if ((load16(raw[0..2]) orelse return error.Corrupt) != 1) return error.Corrupt;
    const label_len = load16(raw[2..4]) orelse return error.Corrupt;
    if (label_len == 0 or label_len > vfs_label_max) return error.Corrupt;
    const label = raw[4..][0..label_len];
    if (!labelValid(label)) return error.Corrupt;
    for (raw[4 + label_len .. 4 + vfs_label_max]) |byte| {
        if (byte != 0) return error.Corrupt;
    }
    const object_len = load64(raw[196..204]) orelse return error.Corrupt;
    if (object_len == 0 or object_len > max_source_bytes) return error.Corrupt;
    return .{ .label = label, .object_len = @intCast(object_len) };
}

fn labelValid(label: []const u8) bool {
    if (label.len == 0 or label.len > vfs_label_max) return false;
    if (label[0] == '/' or label[label.len - 1] == '/') return false;
    var last_was_slash = false;
    var index: usize = 0;
    while (index < label.len) : (index += 1) {
        const c = label[index];
        if (c == 0 or c == '\\') return false;
        if (c == '/') {
            if (last_was_slash) return false;
            last_was_slash = true;
            continue;
        }
        if (c == '.') {
            const at_part_start = index == 0 or label[index - 1] == '/';
            const at_part_end = index + 1 == label.len or label[index + 1] == '/';
            const dotdot = index + 1 < label.len and label[index + 1] == '.' and
                (index + 2 == label.len or label[index + 2] == '/');
            if (at_part_start and (at_part_end or dotdot)) return false;
        }
        last_was_slash = false;
    }
    return true;
}

fn load16(in: []const u8) ?u16 {
    if (in.len < 2) return null;
    return @as(u16, in[0]) | (@as(u16, in[1]) << 8);
}

fn load32(in: []const u8) ?u32 {
    if (in.len < 4) return null;
    return @as(u32, in[0]) |
        (@as(u32, in[1]) << 8) |
        (@as(u32, in[2]) << 16) |
        (@as(u32, in[3]) << 24);
}

fn load64(in: []const u8) ?u64 {
    if (in.len < 8) return null;
    return @as(u64, load32(in[0..4]).?) |
        (@as(u64, load32(in[4..8]).?) << 32);
}

test "compiler ABI emits successor wasm for VFS workspace object" {
    state = .{};
    var memory: [65536]u8 align(memory_alignment) = undefined;
    try std.testing.expectEqual(@intFromEnum(Status.ok), er_wasm_compiler_init(@intFromPtr(&memory), memory.len));

    const root_source = "pub export fn main() void {}";
    var workspace_raw: [1024]u8 = undefined;
    const workspace_object = try buildTestWorkspace(&workspace_raw, default_root_label, root_source);
    try std.testing.expectEqual(
        @intFromEnum(Status.ok),
        er_wasm_compiler_compile_wasm(@intFromPtr(&memory), memory.len, @intFromPtr(default_root_label.ptr), default_root_label.len, @intFromPtr(workspace_object.ptr), workspace_object.len),
    );
    const output = (@as([*]const u8, @ptrFromInt(er_wasm_compiler_output_ptr())))[0..er_wasm_compiler_output_len()];
    try std.testing.expect(output.len > workspace_object.len);
    try std.testing.expectEqualSlices(u8, &.{ 0x00, 0x61, 0x73, 0x6d }, output[0..4]);
    try std.testing.expect(std.mem.indexOf(u8, output, workspace_object) != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "er_app_zir_instruction_count") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "er_app_embedded_source_len") != null);
    const full_output_len = output.len;

    try std.testing.expectEqual(
        @intFromEnum(Status.ok),
        er_wasm_compiler_compile_wasm_metadata(@intFromPtr(&memory), memory.len, @intFromPtr(default_root_label.ptr), default_root_label.len, @intFromPtr(workspace_object.ptr), workspace_object.len),
    );
    const metadata_output = (@as([*]const u8, @ptrFromInt(er_wasm_compiler_output_ptr())))[0..er_wasm_compiler_output_len()];
    try std.testing.expect(metadata_output.len < full_output_len);
    try std.testing.expectEqualSlices(u8, &.{ 0x00, 0x61, 0x73, 0x6d }, metadata_output[0..4]);
    try std.testing.expect(std.mem.indexOf(u8, metadata_output, workspace_object) == null);
    try std.testing.expect(std.mem.indexOf(u8, metadata_output, "er_app_embedded_source_len") != null);

    try std.testing.expectEqual(
        @intFromEnum(Status.missing_root_source),
        er_wasm_compiler_compile_wasm(@intFromPtr(&memory), memory.len, @intFromPtr("missing.zig".ptr), "missing.zig".len, @intFromPtr(workspace_object.ptr), workspace_object.len),
    );

    var bad_workspace_raw: [1024]u8 = undefined;
    const bad_workspace = try buildTestWorkspace(&bad_workspace_raw, default_root_label, "pub export fn broken( void");
    try std.testing.expectEqual(
        @intFromEnum(Status.invalid_zig_source),
        er_wasm_compiler_compile_wasm(@intFromPtr(&memory), memory.len, @intFromPtr(default_root_label.ptr), default_root_label.len, @intFromPtr(bad_workspace.ptr), bad_workspace.len),
    );

    var bad_astgen_workspace_raw: [1024]u8 = undefined;
    const bad_astgen_workspace = try buildTestWorkspace(
        &bad_astgen_workspace_raw,
        default_root_label,
        "pub const duplicate = 1; pub const duplicate = 2;",
    );
    try std.testing.expectEqual(
        @intFromEnum(Status.invalid_zig_source),
        er_wasm_compiler_compile_wasm(@intFromPtr(&memory), memory.len, @intFromPtr(default_root_label.ptr), default_root_label.len, @intFromPtr(bad_astgen_workspace.ptr), bad_astgen_workspace.len),
    );
}

test "compiler ABI rejects raw and non-workspace objects" {
    state = .{};
    try std.testing.expectEqual(@as(u32, abi_version), er_wasm_compiler_abi_version());
    try std.testing.expectEqual(@intFromEnum(Status.not_initialized), er_wasm_compiler_status());
    try std.testing.expectEqual(@intFromEnum(Status.invalid_memory), er_wasm_compiler_compile_wasm(0, 0, @intFromPtr("main.zig".ptr), "main.zig".len, @intFromPtr("pub fn main() void {}".ptr), "pub fn main() void {}".len));
    try std.testing.expect(er_wasm_compiler_diagnostic_len() > 0);
    try std.testing.expectEqual(@as(usize, 0), er_wasm_compiler_output_len());

    var memory: [4096]u8 align(memory_alignment) = undefined;
    try std.testing.expectEqual(@intFromEnum(Status.ok), er_wasm_compiler_init(@intFromPtr(&memory), memory.len));
    const source = "app title = edited";
    try std.testing.expectEqual(@intFromEnum(Status.corrupt_source_object), er_wasm_compiler_compile_wasm(@intFromPtr(&memory), memory.len, @intFromPtr("main.er".ptr), "main.er".len, @intFromPtr(source.ptr), source.len));
    var object_raw: [256]u8 = undefined;
    const source_object = try buildTestObject(&object_raw, "app title = edited");
    try std.testing.expectEqual(@intFromEnum(Status.corrupt_source_object), er_wasm_compiler_compile_wasm(@intFromPtr(&memory), memory.len, @intFromPtr("main.er".ptr), "main.er".len, @intFromPtr(source_object.ptr), source_object.len));
}

test "root main literal lowering is explicit and narrow" {
    try std.testing.expectEqual(@as(?i32, 7), lowerMainI32Literal("pub export fn er_app_main() i32 { return 7; }"));
    try std.testing.expectEqual(@as(?i32, -42), lowerMainI32Literal("pub export fn main() i32 { return -42; }"));
    try std.testing.expectEqual(@as(?i32, null), lowerMainI32Literal("pub export fn er_app_main() void {}"));
    try std.testing.expectEqual(@as(?i32, null), lowerMainI32Literal("pub export fn er_app_main() i32 { return value; }"));
}

test "simple zero arg integer exports lower to wasm functions" {
    const lowered = collectLoweredExports(
        \\const max_width: usize = 4096;
        \\const buffer_len: usize = 8 * 1024;
        \\const ErrorCode = enum(u32) { ok = 0, bad_input = 2 };
        \\var frame_width: usize = 0;
        \\var last_error: ErrorCode = .ok;
        \\var input_bytes: [buffer_len]u8 = undefined;
        \\export fn er_ui_max_width() u32 { return max_width; }
        \\export fn er_literal() i32 { return -3; }
        \\export fn er_zero() u32 { return @intCast(frame_width); }
        \\export fn er_len() usize { return input_bytes.len; }
        \\export fn er_ptr() usize { return @intFromPtr(&input_bytes); }
        \\export fn er_error() u32 { return @intFromEnum(last_error); }
        \\export fn er_effect() u32 { frame_width = 1; return @intCast(frame_width); }
        \\export fn er_dynamic() usize { return frame_width; }
    , 0);
    try std.testing.expectEqual(@as(u32, 7), lowered.count);
    try std.testing.expectEqualStrings("er_ui_max_width", lowered.entries[0].name);
    try std.testing.expectEqual(@as(i32, 4096), lowered.entries[0].value);
    try std.testing.expectEqualStrings("er_literal", lowered.entries[1].name);
    try std.testing.expectEqual(@as(i32, -3), lowered.entries[1].value);
    try std.testing.expectEqualStrings("er_zero", lowered.entries[2].name);
    try std.testing.expectEqual(@as(i32, 0), lowered.entries[2].value);
    try std.testing.expectEqualStrings("er_len", lowered.entries[3].name);
    try std.testing.expectEqual(@as(i32, 8192), lowered.entries[3].value);
    try std.testing.expectEqualStrings("er_ptr", lowered.entries[4].name);
    try std.testing.expectEqual(@as(i32, 0), lowered.entries[4].value);
    try std.testing.expectEqualStrings("er_error", lowered.entries[5].name);
    try std.testing.expectEqual(@as(i32, 0), lowered.entries[5].value);
    try std.testing.expectEqualStrings("er_dynamic", lowered.entries[6].name);
    try std.testing.expectEqual(@as(i32, 0), lowered.entries[6].value);
}

fn buildTestWorkspace(out: []u8, label: []const u8, root_source: []const u8) ![]const u8 {
    var file_raw: [512]u8 = undefined;
    const file_object = try buildTestObject(&file_raw, root_source);
    var manifest: [workspace_manifest_header_bytes + vfs_label_ref_bytes + file_raw.len]u8 = undefined;
    @memcpy(manifest[0..workspace_source_marker.len], workspace_source_marker);
    store16(manifest[8..10], 1);
    store16(manifest[10..12], 0);
    store32(manifest[12..16], 1);
    encodeTestLabelRef(manifest[workspace_manifest_header_bytes..][0..vfs_label_ref_bytes], label, file_object.len);
    const file_start = workspace_manifest_header_bytes + vfs_label_ref_bytes;
    @memcpy(manifest[file_start..][0..file_object.len], file_object);
    return buildTestObject(out, manifest[0 .. file_start + file_object.len]);
}

fn buildTestObject(out: []u8, body: []const u8) ![]const u8 {
    const len = object_header_bytes + body.len;
    if (out.len < len) return error.NoSpace;
    @memset(out[0..len], 0);
    @memcpy(out[0..object_magic.len], object_magic);
    store16(out[8..10], 1);
    store16(out[10..12], object_kind_bytes);
    store64(out[16..24], body.len);
    store64(out[32..40], body.len);
    @memcpy(out[object_header_bytes..][0..body.len], body);
    return out[0..len];
}

fn encodeTestLabelRef(out: []u8, label: []const u8, object_len: usize) void {
    @memset(out[0..vfs_label_ref_bytes], 0);
    store16(out[0..2], 1);
    store16(out[2..4], @intCast(label.len));
    @memcpy(out[4..][0..label.len], label);
    store64(out[196..204], object_len);
}

fn store16(out: []u8, value: u16) void {
    out[0] = @truncate(value);
    out[1] = @truncate(value >> 8);
}

fn store32(out: []u8, value: u32) void {
    out[0] = @truncate(value);
    out[1] = @truncate(value >> 8);
    out[2] = @truncate(value >> 16);
    out[3] = @truncate(value >> 24);
}

fn store64(out: []u8, value: u64) void {
    store32(out[0..4], @truncate(value));
    store32(out[4..8], @truncate(value >> 32));
}

comptime {
    if (builtin.cpu.arch == .wasm32) {
        std.debug.assert(@sizeOf(usize) == 4);
    }
}
