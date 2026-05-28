const std = @import("std");
const builtin = @import("builtin");
const edgerun_source = @import("edgerun_source.zig");

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
const default_root_label = "src/main.er";
const successor_base_function_count: u32 = 27;
const max_lowered_exports: usize = 64;
const max_lowered_consts: usize = 128;
const max_edgerun_top_level_names: usize = max_lowered_exports + max_lowered_consts;
const max_edgerun_function_locals: usize = 32;
const max_edgerun_expr_code_bytes: usize = 256;
const max_workspace_import_edges: usize = 16;
const max_lowered_data_bytes: usize = 512;
const max_edgerun_ui_nodes: usize = 8;
const erui_magic = "ERUI001\x00";
const erui_header_size: usize = 20;
const erui_record_size: usize = 16;
const erui_record_kind_text: u16 = 1;
const erui_record_kind_button: u16 = 2;
const erui_record_kind_input: u16 = 3;
const erui_record_kind_badge: u16 = 6;
const wasm_block_type_empty: u8 = 0x40;
const wasm_opcode_block: u8 = 0x02;
const wasm_opcode_loop: u8 = 0x03;
const wasm_block_type_i32: u8 = 0x7f;
const wasm_opcode_if: u8 = 0x04;
const wasm_opcode_else: u8 = 0x05;
const wasm_opcode_end: u8 = 0x0b;
const wasm_opcode_br: u8 = 0x0c;
const wasm_opcode_br_if: u8 = 0x0d;
const wasm_opcode_return: u8 = 0x0f;
const wasm_opcode_call: u8 = 0x10;
const wasm_opcode_local_get: u8 = 0x20;
const wasm_opcode_local_set: u8 = 0x21;
const wasm_opcode_i32_load: u8 = 0x28;
const wasm_opcode_i32_load8_u: u8 = 0x2d;
const wasm_opcode_i32_store: u8 = 0x36;
const wasm_opcode_i32_store8: u8 = 0x3a;
const wasm_opcode_i32_eqz: u8 = 0x45;
const wasm_opcode_i32_eq: u8 = 0x46;
const wasm_opcode_i32_ne: u8 = 0x47;
const wasm_opcode_i32_lt_s: u8 = 0x48;
const wasm_opcode_i32_gt_s: u8 = 0x4a;
const wasm_opcode_i32_le_s: u8 = 0x4c;
const wasm_opcode_i32_ge_s: u8 = 0x4e;
const wasm_opcode_i32_add: u8 = 0x6a;
const wasm_opcode_i32_sub: u8 = 0x6b;
const wasm_opcode_i32_mul: u8 = 0x6c;
const wasm_opcode_i32_div_s: u8 = 0x6d;
const wasm_opcode_i32_rem_s: u8 = 0x6f;
const lowered_main_i32_signature = "pub export fn er_app_main() i32";
const legacy_main_i32_signature = "pub export fn main() i32";
const return_keyword = "return";
const export_fn_keyword = "export fn ";
const const_keyword = "const ";
const var_keyword = "var ";
const embedded_wasm_compiler_label = "embedded_wasm_compiler";
const type_index_no_args_i32: u32 = 0;
const type_index_no_args_void: u32 = 1;
const type_index_i32_arg_i32: u32 = 2;
const type_index_i32_i32_arg_i32: u32 = 3;
const type_index_i32_i32_i32_arg_i32: u32 = 4;
const state_slot_bytes: usize = 4;
const linked_compiler_runtime_capacity: usize = 96 * 1024 * 1024;
const linked_type_section_buffer_bytes: usize = 64 * 1024;
const linked_function_section_buffer_bytes: usize = 64 * 1024;
const linked_export_section_buffer_bytes: usize = 64 * 1024;
const compile_workspace_body_buffer_bytes: usize = 2048;
const wasm_magic_word: i32 = 0x6d736100;
const error_code_ok: i32 = 0;
const error_code_bad_input: i32 = 2;
const error_code_compile_source_empty: i32 = 20;
const error_code_compile_source_too_large: i32 = 21;
const error_code_compile_init_failed: i32 = 22;
const error_code_compile_failed: i32 = 23;
const error_code_compile_output_short: i32 = 24;
const error_code_compile_output_too_large: i32 = 25;
const error_code_compile_output_bad_magic: i32 = 26;

const CompileMode = enum {
    full_source,
    metadata_only,
};

const SourceMode = enum {
    edgerun,
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
    invalid_source = 8,
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
    state.diagnostic = "";
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
    const source_mode = sourceModeForLabel(root_label) orelse {
        state.status = .unsupported;
        state.diagnostic = "source root label is not a supported EdgeRun compiler input";
        state.output = &.{};
        output_addr = 0;
        return @intFromEnum(Status.unsupported);
    };
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
    const compiler_output = analyzeWorkspaceGraph(compiler_memory, workspace, source_mode) catch |err| {
        state.status = switch (err) {
            error.OutOfMemory => .compiler_memory_too_small,
            error.InvalidSource => .invalid_source,
        };
        state.diagnostic = switch (err) {
            error.OutOfMemory => "compiler memory slice is too small for EdgeRun lowering",
            error.InvalidSource => switch (source_mode) {
                .edgerun => "VFS root source is outside the supported EdgeRun source subset",
            },
        };
        state.output = &.{};
        output_addr = 0;
        return @intFromEnum(state.status);
    };

    const result = emitAppWasm(compiler_memory, source, workspace, compiler_output, mode, source_mode) catch |err| {
        state.status = .output_too_large;
        if (state.diagnostic.len == 0) {
            state.diagnostic = switch (err) {
                error.OutputTooLarge => "compiled wasm does not fit compiler output memory",
            };
        }
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

fn sourceModeForLabel(label: []const u8) ?SourceMode {
    if (std.mem.endsWith(u8, label, ".er")) return .edgerun;
    return null;
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

const Reader = struct {
    bytes: []const u8,
    offset: usize = 0,

    fn done(reader: Reader) bool {
        return reader.offset == reader.bytes.len;
    }

    fn readByte(reader: *Reader) error{OutputTooLarge}!u8 {
        if (reader.offset >= reader.bytes.len) return error.OutputTooLarge;
        const byte = reader.bytes[reader.offset];
        reader.offset += 1;
        return byte;
    }

    fn readBytes(reader: *Reader, len: usize) error{OutputTooLarge}![]const u8 {
        if (len > reader.bytes.len - reader.offset) return error.OutputTooLarge;
        const start = reader.offset;
        reader.offset += len;
        return reader.bytes[start..reader.offset];
    }

    fn readU32Leb(reader: *Reader) error{OutputTooLarge}!u32 {
        var result: u32 = 0;
        var shift: u5 = 0;
        var count: usize = 0;
        while (count < 5) : (count += 1) {
            const byte = try reader.readByte();
            result |= @as(u32, byte & 0x7f) << shift;
            if ((byte & 0x80) == 0) return result;
            shift += 7;
        }
        return error.OutputTooLarge;
    }
};

fn emitAppWasm(output: []u8, source: []const u8, workspace: WorkspaceInfo, compiler_output: CompilerOutputInfo, mode: CompileMode, source_mode: SourceMode) error{OutputTooLarge}!usize {
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
    const embedded_compiler_wasm = findWorkspaceFile(workspace.manifest, embedded_wasm_compiler_label) orelse &.{};
    if (embedded_compiler_wasm.len != 0) {
        return try emitLinkedCompilerAppWasm(output, source, workspace, compiler_output, mode, source_mode, embedded_compiler_wasm, root_hash, source_hash);
    }
    const compiler_wasm_offset = alignForwardUsize(wasm_source_offset + embedded_source_len, memory_alignment);
    const compiler_wasm_end = compiler_wasm_offset + embedded_compiler_wasm.len;
    const lowered_data_base = alignForwardUsize(compiler_wasm_end, memory_alignment);
    const lowered_exports = collectWorkspaceLoweredExportsForMode(source_mode, workspace, lowered_data_base, @intCast(compiler_wasm_offset), @intCast(embedded_compiler_wasm.len), successor_base_function_count);
    const lowered_main = lowerMainForMode(source_mode, workspace.root_source, lowered_data_base, &lowered_exports, successor_base_function_count);
    const source_end = wasm_source_offset + embedded_source_len;
    var memory_bytes = if (lowered_exports.memory_end > source_end) lowered_exports.memory_end else source_end;
    if (lowered_main.memory_end > memory_bytes) memory_bytes = lowered_main.memory_end;
    if (compiler_wasm_end > memory_bytes) memory_bytes = compiler_wasm_end;
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
        @intCast(compiler_output.edgerun_instruction_count),
        @intCast(compiler_output.edgerun_declaration_count),
        @intCast(compiler_output.edgerun_export_name_bytes),
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
        lowered_main.countI32(),
        @intCast(compiler_output.lowered_export_count),
        lowered_main,
        lowered_exports,
    );
    try emitDataSection(&writer, switch (mode) {
        .full_source => source,
        .metadata_only => &.{},
    }, embedded_compiler_wasm, @intCast(compiler_wasm_offset), lowered_exports.dataSlice(), @intCast(lowered_exports.data_offset));
    return writer.len;
}

fn emitTypeSection(parent: *Writer) error{OutputTooLarge}!void {
    var payload_buffer: [40]u8 = undefined;
    var payload = Writer{ .bytes = &payload_buffer };
    try payload.appendU32Leb(5);
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
    try payload.append(0x60);
    try payload.appendU32Leb(2);
    try payload.append(0x7f);
    try payload.append(0x7f);
    try payload.appendU32Leb(1);
    try payload.append(0x7f);
    try payload.append(0x60);
    try payload.appendU32Leb(3);
    try payload.append(0x7f);
    try payload.append(0x7f);
    try payload.append(0x7f);
    try payload.appendU32Leb(1);
    try payload.append(0x7f);
    try emitSection(parent, 1, payload.bytes[0..payload.len]);
}

const LinkedCompilerInfo = struct {
    function_count: u32,
    export_count: u32,
    code_count: u32,
    data_count: u32,
    memory_min_pages: u32,
    type_count: u32,
    type_no_args_i32: u32,
    type_no_args_void: u32,
    type_i32_arg_i32: u32,
    type_i32_i32_arg_i32: u32,
    type_i32_i32_i32_arg_i32: u32,
    init_function_index: u32,
    compile_function_index: u32,
    output_len_function_index: u32,
};

const RawSection = struct {
    id: u8,
    payload: []const u8,
};

fn emitLinkedCompilerAppWasm(
    output: []u8,
    source: []const u8,
    workspace: WorkspaceInfo,
    compiler_output: CompilerOutputInfo,
    mode: CompileMode,
    source_mode: SourceMode,
    compiler_wasm: []const u8,
    root_hash: u32,
    source_hash: u32,
) error{OutputTooLarge}!usize {
    const embedded_source_len: usize = switch (mode) {
        .full_source => source.len,
        .metadata_only => 0,
    };
    state.diagnostic = "linked parse compiler info";
    var compiler_info = parseLinkedCompilerInfo(compiler_wasm) orelse {
        state.diagnostic = "linked compiler info";
        return error.OutputTooLarge;
    };
    const compiler_reserved_bytes = pagesToBytesUsize(compiler_info.memory_min_pages) orelse return error.OutputTooLarge;
    const linked_source_offset = alignForwardUsize(compiler_reserved_bytes, memory_alignment);
    const source_end = linked_source_offset + embedded_source_len;
    const lowered_data_base = alignForwardUsize(source_end, memory_alignment);
    const lowered_exports = collectWorkspaceLoweredExportsForMode(source_mode, workspace, lowered_data_base, 0, 1, compiler_info.function_count + successor_base_function_count);
    const lowered_main = lowerMainForMode(source_mode, workspace.root_source, lowered_data_base, &lowered_exports, compiler_info.function_count + successor_base_function_count);
    var memory_bytes = lowered_exports.memory_end;
    if (lowered_main.memory_end > memory_bytes) memory_bytes = lowered_main.memory_end;
    var writer = Writer{ .bytes = output };
    try writer.appendSlice(&.{ 0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00 });

    var reader = Reader{ .bytes = compiler_wasm[8..] };
    while (!reader.done()) {
        const section_id = try reader.readByte();
        const section_size = try reader.readU32Leb();
        const section = RawSection{ .id = section_id, .payload = try reader.readBytes(section_size) };
        if (section.id == 0) continue;
        switch (section.id) {
            1 => {
                state.diagnostic = "linked type section";
                try emitLinkedTypeSection(&writer, section.payload, &compiler_info);
            },
            3 => {
                state.diagnostic = "linked function section";
                try emitLinkedFunctionSection(&writer, section.payload, compiler_info, lowered_exports);
            },
            5 => {
                state.diagnostic = "linked memory section";
                try emitMemorySection(&writer, memoryPagesForBytes(memory_bytes));
            },
            7 => {
                state.diagnostic = "linked export section";
                try emitLinkedExportSection(&writer, section.payload, compiler_info.function_count, lowered_exports);
            },
            10 => {
                state.diagnostic = "linked code section";
                try emitLinkedCodeSection(
                    &writer,
                    section.payload,
                    @intCast(source.len),
                    @intCast(linked_source_offset),
                    @bitCast(source_hash),
                    @intCast(workspace.file_count),
                    @intCast(workspace.root_source.len),
                    @bitCast(root_hash),
                    @intCast(compiler_output.edgerun_instruction_count),
                    @intCast(compiler_output.edgerun_declaration_count),
                    @intCast(compiler_output.edgerun_export_name_bytes),
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
                    lowered_main.countI32(),
                    @intCast(compiler_output.lowered_export_count),
                    lowered_main,
                    lowered_exports,
                    compiler_info,
                );
            },
            11 => {
                state.diagnostic = "linked data section";
                try emitLinkedDataSection(&writer, section.payload, switch (mode) {
                    .full_source => source,
                    .metadata_only => &.{},
                }, @intCast(linked_source_offset), lowered_exports.dataSlice(), @intCast(lowered_exports.data_offset));
            },
            else => {
                state.diagnostic = "linked copied section";
                try emitSection(&writer, section.id, section.payload);
            },
        }
    }
    _ = &compiler_info;
    return writer.len;
}

fn parseLinkedCompilerInfo(wasm: []const u8) ?LinkedCompilerInfo {
    if (wasm.len < 8 or !std.mem.eql(u8, wasm[0..4], &.{ 0x00, 0x61, 0x73, 0x6d })) return null;
    var info = LinkedCompilerInfo{
        .function_count = 0,
        .export_count = 0,
        .code_count = 0,
        .data_count = 0,
        .memory_min_pages = 0,
        .type_count = 0,
        .type_no_args_i32 = std.math.maxInt(u32),
        .type_no_args_void = std.math.maxInt(u32),
        .type_i32_arg_i32 = std.math.maxInt(u32),
        .type_i32_i32_arg_i32 = std.math.maxInt(u32),
        .type_i32_i32_i32_arg_i32 = std.math.maxInt(u32),
        .init_function_index = std.math.maxInt(u32),
        .compile_function_index = std.math.maxInt(u32),
        .output_len_function_index = std.math.maxInt(u32),
    };
    var reader = Reader{ .bytes = wasm[8..] };
    while (!reader.done()) {
        const id = reader.readByte() catch return null;
        const size = reader.readU32Leb() catch return null;
        const payload = reader.readBytes(size) catch return null;
        switch (id) {
            1 => parseLinkedTypeInfo(payload, &info) catch return null,
            3 => info.function_count = parseCount(payload) orelse return null,
            5 => info.memory_min_pages = parseMemoryMinPages(payload) orelse return null,
            7 => parseLinkedExportInfo(payload, &info) catch return null,
            10 => info.code_count = parseCount(payload) orelse return null,
            11 => info.data_count = parseCount(payload) orelse return null,
            else => {},
        }
    }
    if (info.function_count == 0 or info.function_count != info.code_count) return null;
    if (info.memory_min_pages == 0) return null;
    if (info.type_no_args_i32 == std.math.maxInt(u32)) return null;
    if (info.type_count == 0) return null;
    if (info.init_function_index == std.math.maxInt(u32)) return null;
    if (info.compile_function_index == std.math.maxInt(u32)) return null;
    if (info.output_len_function_index == std.math.maxInt(u32)) return null;
    return info;
}

fn parseCount(payload: []const u8) ?u32 {
    var reader = Reader{ .bytes = payload };
    return reader.readU32Leb() catch null;
}

fn parseMemoryMinPages(payload: []const u8) ?u32 {
    var reader = Reader{ .bytes = payload };
    const count = reader.readU32Leb() catch return null;
    if (count != 1) return null;
    const flags = reader.readByte() catch return null;
    const min = reader.readU32Leb() catch return null;
    if (flags == 1) _ = reader.readU32Leb() catch return null;
    if (flags > 1 or !reader.done()) return null;
    return min;
}

fn parseLinkedTypeInfo(payload: []const u8, info: *LinkedCompilerInfo) error{OutputTooLarge}!void {
    var reader = Reader{ .bytes = payload };
    const count = try reader.readU32Leb();
    info.type_count = count;
    var index: u32 = 0;
    while (index < count) : (index += 1) {
        if ((try reader.readByte()) != 0x60) return error.OutputTooLarge;
        const param_count = try reader.readU32Leb();
        var params = [_]u8{0} ** 3;
        var param_index: u32 = 0;
        while (param_index < param_count) : (param_index += 1) {
            const value_type = try reader.readByte();
            if (param_index < params.len) params[param_index] = value_type;
        }
        const result_count = try reader.readU32Leb();
        var results = [_]u8{0} ** 1;
        var result_index: u32 = 0;
        while (result_index < result_count) : (result_index += 1) {
            const value_type = try reader.readByte();
            if (result_index < results.len) results[result_index] = value_type;
        }
        if (param_count == 0 and result_count == 1 and results[0] == 0x7f) info.type_no_args_i32 = index;
        if (param_count == 0 and result_count == 0) info.type_no_args_void = index;
        if (param_count == 1 and params[0] == 0x7f and result_count == 1 and results[0] == 0x7f) info.type_i32_arg_i32 = index;
        if (param_count == 2 and params[0] == 0x7f and params[1] == 0x7f and result_count == 1 and results[0] == 0x7f) info.type_i32_i32_arg_i32 = index;
        if (param_count == 3 and params[0] == 0x7f and params[1] == 0x7f and params[2] == 0x7f and result_count == 1 and results[0] == 0x7f) info.type_i32_i32_i32_arg_i32 = index;
    }
}

fn emitLinkedTypeSection(parent: *Writer, payload: []const u8, info: *LinkedCompilerInfo) error{OutputTooLarge}!void {
    var reader = Reader{ .bytes = payload };
    const existing_count = try reader.readU32Leb();
    var out_buffer: [linked_type_section_buffer_bytes]u8 = undefined;
    var out = Writer{ .bytes = &out_buffer };
    const add_one_arg_type = info.type_i32_arg_i32 == std.math.maxInt(u32);
    const add_two_arg_type = info.type_i32_i32_arg_i32 == std.math.maxInt(u32);
    const add_three_arg_type = info.type_i32_i32_i32_arg_i32 == std.math.maxInt(u32);
    try out.appendU32Leb(existing_count + (if (add_one_arg_type) @as(u32, 1) else 0) + (if (add_two_arg_type) @as(u32, 1) else 0) + (if (add_three_arg_type) @as(u32, 1) else 0));
    try out.appendSlice(payload[reader.offset..]);
    if (add_one_arg_type) {
        info.type_i32_arg_i32 = existing_count;
        try out.append(0x60);
        try out.appendU32Leb(1);
        try out.append(0x7f);
        try out.appendU32Leb(1);
        try out.append(0x7f);
    }
    if (add_two_arg_type) {
        info.type_i32_i32_arg_i32 = existing_count + if (add_one_arg_type) @as(u32, 1) else 0;
        try out.append(0x60);
        try out.appendU32Leb(2);
        try out.append(0x7f);
        try out.append(0x7f);
        try out.appendU32Leb(1);
        try out.append(0x7f);
    }
    if (add_three_arg_type) {
        info.type_i32_i32_i32_arg_i32 = existing_count + (if (add_one_arg_type) @as(u32, 1) else 0) + (if (add_two_arg_type) @as(u32, 1) else 0);
        try out.append(0x60);
        try out.appendU32Leb(3);
        try out.append(0x7f);
        try out.append(0x7f);
        try out.append(0x7f);
        try out.appendU32Leb(1);
        try out.append(0x7f);
    }
    info.type_count = existing_count + (if (add_one_arg_type) @as(u32, 1) else 0) + (if (add_two_arg_type) @as(u32, 1) else 0) + (if (add_three_arg_type) @as(u32, 1) else 0);
    try emitSection(parent, 1, out.bytes[0..out.len]);
}

fn parseLinkedExportInfo(payload: []const u8, info: *LinkedCompilerInfo) error{OutputTooLarge}!void {
    var reader = Reader{ .bytes = payload };
    const count = try reader.readU32Leb();
    info.export_count = count;
    var index: u32 = 0;
    while (index < count) : (index += 1) {
        const name_len = try reader.readU32Leb();
        const name = try reader.readBytes(name_len);
        const kind = try reader.readByte();
        const exported_index = try reader.readU32Leb();
        if (kind != 0) continue;
        if (std.mem.eql(u8, name, "er_wasm_compiler_init")) info.init_function_index = exported_index;
        if (std.mem.eql(u8, name, "er_wasm_compiler_compile_wasm")) info.compile_function_index = exported_index;
        if (std.mem.eql(u8, name, "er_wasm_compiler_output_len")) info.output_len_function_index = exported_index;
    }
}

fn emitLinkedFunctionSection(parent: *Writer, payload: []const u8, info: LinkedCompilerInfo, lowered_exports: LoweredExports) error{OutputTooLarge}!void {
    var reader = Reader{ .bytes = payload };
    _ = try reader.readU32Leb();
    var out_buffer: [linked_function_section_buffer_bytes]u8 = undefined;
    var out = Writer{ .bytes = &out_buffer };
    try out.appendU32Leb(info.function_count + successor_base_function_count + lowered_exports.count);
    try out.appendSlice(payload[reader.offset..]);
    var index: u32 = 0;
    while (index < successor_base_function_count) : (index += 1) try out.appendU32Leb(info.type_no_args_i32);
    for (lowered_exports.entries[0..@intCast(lowered_exports.count)]) |lowered| {
        try out.appendU32Leb(switch (lowered.kind) {
            .return_i32, .state_load_i32, .compile_workspace => info.type_no_args_i32,
            .release_artifact_commit, .source_workspace_commit => info.type_i32_arg_i32,
            .dynamic_i32_arg_i32 => linkedDynamicI32TypeIndex(info, lowered.arg_count),
        });
    }
    try emitSection(parent, 3, out.bytes[0..out.len]);
}

fn linkedDynamicI32TypeIndex(info: LinkedCompilerInfo, arg_count: u8) u32 {
    return switch (arg_count) {
        0 => info.type_no_args_i32,
        1 => info.type_i32_arg_i32,
        2 => info.type_i32_i32_arg_i32,
        3 => info.type_i32_i32_i32_arg_i32,
        else => info.type_i32_arg_i32,
    };
}

fn emitLinkedExportSection(parent: *Writer, payload: []const u8, base_function_count: u32, lowered_exports: LoweredExports) error{OutputTooLarge}!void {
    var reader = Reader{ .bytes = payload };
    const existing_count = try reader.readU32Leb();
    var out_buffer: [linked_export_section_buffer_bytes]u8 = undefined;
    var out = Writer{ .bytes = &out_buffer };
    try out.appendU32Leb(existing_count + successor_base_function_count - 1 + lowered_exports.exportedCount());
    try out.appendSlice(payload[reader.offset..]);
    try emitExport(&out, "er_app_abi_version", 0, base_function_count + 0);
    try emitExport(&out, "er_app_source_ptr", 0, base_function_count + 1);
    try emitExport(&out, "er_app_source_len", 0, base_function_count + 2);
    try emitExport(&out, "er_app_source_hash", 0, base_function_count + 3);
    try emitExport(&out, "er_app_main", 0, base_function_count + 4);
    try emitExport(&out, "er_app_source_file_count", 0, base_function_count + 6);
    try emitExport(&out, "er_app_root_source_len", 0, base_function_count + 7);
    try emitExport(&out, "er_app_root_source_hash", 0, base_function_count + 8);
    try emitExport(&out, "er_app_edgerun_instruction_count", 0, base_function_count + 9);
    try emitExport(&out, "er_app_edgerun_declaration_count", 0, base_function_count + 10);
    try emitExport(&out, "er_app_edgerun_export_name_bytes", 0, base_function_count + 11);
    try emitExport(&out, "er_app_compiler_memory_used", 0, base_function_count + 12);
    try emitExport(&out, "er_app_analyzed_file_count", 0, base_function_count + 13);
    try emitExport(&out, "er_app_import_edge_count", 0, base_function_count + 14);
    try emitExport(&out, "er_app_unresolved_import_count", 0, base_function_count + 15);
    try emitExport(&out, "er_app_truncated_import_count", 0, base_function_count + 16);
    try emitExport(&out, "er_app_manifest_file_refs_scanned", 0, base_function_count + 17);
    try emitExport(&out, "er_app_file_object_decodes", 0, base_function_count + 18);
    try emitExport(&out, "er_app_file_lookup_count", 0, base_function_count + 19);
    try emitExport(&out, "er_app_queued_import_count", 0, base_function_count + 20);
    try emitExport(&out, "er_app_pruned_import_count", 0, base_function_count + 21);
    try emitExport(&out, "er_app_parsed_source_bytes", 0, base_function_count + 22);
    try emitExport(&out, "er_app_indexed_file_count", 0, base_function_count + 23);
    try emitExport(&out, "er_app_embedded_source_len", 0, base_function_count + 24);
    try emitExport(&out, "er_app_lowered_main_count", 0, base_function_count + 25);
    try emitExport(&out, "er_app_lowered_export_count", 0, base_function_count + 26);
    for (lowered_exports.entries[0..@intCast(lowered_exports.count)], 0..) |lowered, index| {
        if (!lowered.exported) continue;
        try emitExport(&out, lowered.nameSlice(), 0, base_function_count + successor_base_function_count + @as(u32, @intCast(index)));
    }
    try emitSection(parent, 7, out.bytes[0..out.len]);
}

fn emitLinkedCodeSection(
    parent: *Writer,
    payload: []const u8,
    source_len: i32,
    source_offset: i32,
    hash: i32,
    file_count: i32,
    root_len: i32,
    root_hash: i32,
    edgerun_instruction_count: i32,
    edgerun_declaration_count: i32,
    edgerun_export_name_bytes: i32,
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
    lowered_main: LoweredMain,
    lowered_exports: LoweredExports,
    compiler_info: LinkedCompilerInfo,
) error{OutputTooLarge}!void {
    var reader = Reader{ .bytes = payload };
    const existing_count = try reader.readU32Leb();
    var out = Writer{ .bytes = parent.bytes[parent.len..] };
    try out.append(10);
    const size_offset = out.len;
    try out.appendSlice(&.{ 0, 0, 0, 0, 0 });
    const payload_start = out.len;
    try out.appendU32Leb(existing_count + successor_base_function_count + lowered_exports.count);
    try out.appendSlice(payload[reader.offset..]);
    try emitAppCodeBodies(
        &out,
        source_len,
        source_offset,
        hash,
        file_count,
        root_len,
        root_hash,
        edgerun_instruction_count,
        edgerun_declaration_count,
        edgerun_export_name_bytes,
        compiler_memory_used,
        analyzed_file_count,
        import_edge_count,
        unresolved_import_count,
        truncated_import_count,
        manifest_file_refs_scanned,
        file_object_decodes,
        file_lookup_count,
        queued_import_count,
        pruned_import_count,
        parsed_source_bytes,
        indexed_file_count,
        embedded_source_len,
        lowered_main_count,
        lowered_export_count,
        lowered_main,
        lowered_exports,
        compiler_info,
    );
    const payload_len = out.len - payload_start;
    parent.len += try finishReservedSizeSection(&out, size_offset, payload_start, payload_len);
}

fn emitAppCodeBodies(
    payload: *Writer,
    source_len: i32,
    source_offset: i32,
    hash: i32,
    file_count: i32,
    root_len: i32,
    root_hash: i32,
    edgerun_instruction_count: i32,
    edgerun_declaration_count: i32,
    edgerun_export_name_bytes: i32,
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
    lowered_main: LoweredMain,
    lowered_exports: LoweredExports,
    compiler_info: ?LinkedCompilerInfo,
) error{OutputTooLarge}!void {
    try emitReturnI32Function(payload, app_abi_version);
    try emitReturnI32Function(payload, source_offset);
    try emitReturnI32Function(payload, source_len);
    try emitReturnI32Function(payload, hash);
    try emitLoweredMainFunction(payload, lowered_main);
    if (compiler_info != null) {
        try emitReturnI32Function(payload, 0);
    } else {
        try emitNoopFunction(payload);
    }
    try emitReturnI32Function(payload, file_count);
    try emitReturnI32Function(payload, root_len);
    try emitReturnI32Function(payload, root_hash);
    try emitReturnI32Function(payload, edgerun_instruction_count);
    try emitReturnI32Function(payload, edgerun_declaration_count);
    try emitReturnI32Function(payload, edgerun_export_name_bytes);
    try emitReturnI32Function(payload, compiler_memory_used);
    try emitReturnI32Function(payload, analyzed_file_count);
    try emitReturnI32Function(payload, import_edge_count);
    try emitReturnI32Function(payload, unresolved_import_count);
    try emitReturnI32Function(payload, truncated_import_count);
    try emitReturnI32Function(payload, manifest_file_refs_scanned);
    try emitReturnI32Function(payload, file_object_decodes);
    try emitReturnI32Function(payload, file_lookup_count);
    try emitReturnI32Function(payload, queued_import_count);
    try emitReturnI32Function(payload, pruned_import_count);
    try emitReturnI32Function(payload, parsed_source_bytes);
    try emitReturnI32Function(payload, indexed_file_count);
    try emitReturnI32Function(payload, embedded_source_len);
    try emitReturnI32Function(payload, lowered_main_count);
    try emitReturnI32Function(payload, lowered_export_count);
    for (lowered_exports.entries[0..@intCast(lowered_exports.count)]) |lowered| {
        switch (lowered.kind) {
            .return_i32 => try emitReturnI32Function(payload, lowered.value),
            .dynamic_i32_arg_i32 => try emitDynamicI32Function(payload, .{
                .bytes = lowered.expr_code,
                .len = lowered.expr_code_len,
                .local_count = lowered.local_count,
            }),
            .state_load_i32 => try emitStateLoadI32Function(payload, lowered.value),
            .release_artifact_commit => try emitReleaseArtifactCommitFunction(payload, lowered.value, lowered.limit, lowered.state_offset, lowered.error_offset),
            .source_workspace_commit => try emitSourceWorkspaceCommitFunction(payload, lowered.limit, lowered.state_offset, lowered.ready_offset, lowered.error_offset),
            .compile_workspace => try emitCompileWorkspaceFunction(payload, lowered, compiler_info orelse return error.OutputTooLarge),
        }
    }
}

fn emitLinkedDataSection(parent: *Writer, payload: []const u8, source: []const u8, source_offset: i32, lowered_data: []const u8, lowered_data_offset: i32) error{OutputTooLarge}!void {
    if (source.len == 0 and lowered_data.len == 0) {
        try emitSection(parent, 11, payload);
        return;
    }
    var reader = Reader{ .bytes = payload };
    const existing_count = try reader.readU32Leb();
    var out = Writer{ .bytes = parent.bytes[parent.len..] };
    try out.append(11);
    const size_offset = out.len;
    try out.appendSlice(&.{ 0, 0, 0, 0, 0 });
    const payload_start = out.len;
    const added_count: u32 = (if (source.len == 0) @as(u32, 0) else 1) + (if (lowered_data.len == 0) @as(u32, 0) else 1);
    try out.appendU32Leb(existing_count + added_count);
    try out.appendSlice(payload[reader.offset..]);
    if (source.len != 0) {
        try appendDataSegmentHeader(&out, source_offset, @intCast(source.len));
        try out.appendSlice(source);
    }
    if (lowered_data.len != 0) {
        try appendDataSegmentHeader(&out, lowered_data_offset, @intCast(lowered_data.len));
        try out.appendSlice(lowered_data);
    }
    const payload_len = out.len - payload_start;
    parent.len += try finishReservedSizeSection(&out, size_offset, payload_start, payload_len);
}

fn finishReservedSizeSection(writer: *Writer, size_offset: usize, payload_start: usize, payload_len: usize) error{OutputTooLarge}!usize {
    var size_buffer: [8]u8 = undefined;
    var size_writer = Writer{ .bytes = &size_buffer };
    try size_writer.appendU32Leb(@intCast(payload_len));
    const reserved = payload_start - size_offset;
    if (size_writer.len > reserved) return error.OutputTooLarge;
    const removed = reserved - size_writer.len;
    @memcpy(writer.bytes[size_offset..][0..size_writer.len], size_buffer[0..size_writer.len]);
    if (removed != 0) {
        const src_start = payload_start;
        const src_end = writer.len;
        std.mem.copyForwards(u8, writer.bytes[size_offset + size_writer.len ..], writer.bytes[src_start..src_end]);
    }
    return writer.len - removed;
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
            .return_i32, .state_load_i32, .compile_workspace => type_index_no_args_i32,
            .release_artifact_commit, .source_workspace_commit => type_index_i32_arg_i32,
            .dynamic_i32_arg_i32 => dynamicI32TypeIndex(lowered.arg_count),
        });
    }
    try emitSection(parent, 3, payload.bytes[0..payload.len]);
}

fn dynamicI32TypeIndex(arg_count: u8) u32 {
    return switch (arg_count) {
        0 => type_index_no_args_i32,
        1 => type_index_i32_arg_i32,
        2 => type_index_i32_i32_arg_i32,
        3 => type_index_i32_i32_i32_arg_i32,
        else => type_index_i32_arg_i32,
    };
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
    try payload.appendU32Leb(successor_base_function_count + lowered_exports.exportedCount());
    try emitExport(&payload, "memory", 2, 0);
    try emitExport(&payload, "er_app_abi_version", 0, 0);
    try emitExport(&payload, "er_app_source_ptr", 0, 1);
    try emitExport(&payload, "er_app_source_len", 0, 2);
    try emitExport(&payload, "er_app_source_hash", 0, 3);
    try emitExport(&payload, "er_app_main", 0, 4);
    try emitExport(&payload, "er_app_source_file_count", 0, 6);
    try emitExport(&payload, "er_app_root_source_len", 0, 7);
    try emitExport(&payload, "er_app_root_source_hash", 0, 8);
    try emitExport(&payload, "er_app_edgerun_instruction_count", 0, 9);
    try emitExport(&payload, "er_app_edgerun_declaration_count", 0, 10);
    try emitExport(&payload, "er_app_edgerun_export_name_bytes", 0, 11);
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
        if (!lowered.exported) continue;
        try emitExport(&payload, lowered.nameSlice(), 0, successor_base_function_count + @as(u32, @intCast(index)));
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
    edgerun_instruction_count: i32,
    edgerun_declaration_count: i32,
    edgerun_export_name_bytes: i32,
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
    lowered_main: LoweredMain,
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
    try emitReturnI32Function(&payload, edgerun_instruction_count);
    try emitReturnI32Function(&payload, edgerun_declaration_count);
    try emitReturnI32Function(&payload, edgerun_export_name_bytes);
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
            .dynamic_i32_arg_i32 => try emitDynamicI32Function(&payload, .{
                .bytes = lowered.expr_code,
                .len = lowered.expr_code_len,
                .local_count = lowered.local_count,
            }),
            .state_load_i32 => try emitStateLoadI32Function(&payload, lowered.value),
            .release_artifact_commit => try emitReleaseArtifactCommitFunction(&payload, lowered.value, lowered.limit, lowered.state_offset, lowered.error_offset),
            .source_workspace_commit => try emitSourceWorkspaceCommitFunction(&payload, lowered.limit, lowered.state_offset, lowered.ready_offset, lowered.error_offset),
            .compile_workspace => return error.OutputTooLarge,
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

fn emitDataSection(parent: *Writer, source: []const u8, compiler_wasm: []const u8, compiler_wasm_offset: i32, lowered_data: []const u8, lowered_data_offset: i32) error{OutputTooLarge}!void {
    const segment_count: u32 = (if (source.len == 0) @as(u32, 0) else 1) + (if (compiler_wasm.len == 0) @as(u32, 0) else 1) + (if (lowered_data.len == 0) @as(u32, 0) else 1);
    if (segment_count == 0) return;
    var count_buffer: [8]u8 = undefined;
    var count = Writer{ .bytes = &count_buffer };
    try count.appendU32Leb(segment_count);
    var source_header_buffer: [32]u8 = undefined;
    var source_header = Writer{ .bytes = &source_header_buffer };
    if (source.len != 0) try appendDataSegmentHeader(&source_header, @intCast(wasm_source_offset), @intCast(source.len));
    var compiler_header_buffer: [32]u8 = undefined;
    var compiler_header = Writer{ .bytes = &compiler_header_buffer };
    if (compiler_wasm.len != 0) try appendDataSegmentHeader(&compiler_header, compiler_wasm_offset, @intCast(compiler_wasm.len));
    var lowered_header_buffer: [32]u8 = undefined;
    var lowered_header = Writer{ .bytes = &lowered_header_buffer };
    if (lowered_data.len != 0) try appendDataSegmentHeader(&lowered_header, lowered_data_offset, @intCast(lowered_data.len));

    try parent.append(11);
    try parent.appendU32Leb(@intCast(count.len + source_header.len + source.len + compiler_header.len + compiler_wasm.len + lowered_header.len + lowered_data.len));
    try parent.appendSlice(count.bytes[0..count.len]);
    if (source.len != 0) {
        try parent.appendSlice(source_header.bytes[0..source_header.len]);
        try parent.appendSlice(source);
    }
    if (compiler_wasm.len != 0) {
        try parent.appendSlice(compiler_header.bytes[0..compiler_header.len]);
        try parent.appendSlice(compiler_wasm);
    }
    if (lowered_data.len != 0) {
        try parent.appendSlice(lowered_header.bytes[0..lowered_header.len]);
        try parent.appendSlice(lowered_data);
    }
}

fn appendDataSegmentHeader(writer: *Writer, offset: i32, len: u32) error{OutputTooLarge}!void {
    try writer.append(0);
    try writer.append(0x41);
    try writer.appendI32Leb(offset);
    try writer.append(0x0b);
    try writer.appendU32Leb(len);
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

fn emitDynamicI32Function(writer: *Writer, compiled: CompiledExpr) error{OutputTooLarge}!void {
    var body_buffer: [max_edgerun_expr_code_bytes + 16]u8 = undefined;
    var body = Writer{ .bytes = &body_buffer };
    if (compiled.local_count == 0) {
        try body.appendU32Leb(0);
    } else {
        try body.appendU32Leb(1);
        try body.appendU32Leb(compiled.local_count);
        try body.append(wasm_block_type_i32);
    }
    try body.appendSlice(compiled.slice());
    try body.append(wasm_opcode_end);
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

fn emitCompileWorkspaceFunction(writer: *Writer, lowered: LoweredExport, compiler_info: LinkedCompilerInfo) error{OutputTooLarge}!void {
    var body_buffer: [compile_workspace_body_buffer_bytes]u8 = undefined;
    var body = Writer{ .bytes = &body_buffer };
    try body.appendU32Leb(1);
    try body.appendU32Leb(1);
    try body.append(0x7f);

    try emitStateLoadI32(&body, lowered.source_len_offset);
    try body.append(0x45);
    try emitErrorIf(&body, lowered.error_offset, error_code_compile_source_empty);

    try emitStateLoadI32(&body, lowered.source_len_offset);
    try emitI32Const(&body, lowered.source_capacity);
    try body.append(0x4b);
    try emitErrorIf(&body, lowered.error_offset, error_code_compile_source_too_large);

    try emitI32Const(&body, lowered.value);
    try emitI32Const(&body, lowered.limit);
    try emitCall(&body, compiler_info.init_function_index);
    try emitErrorIf(&body, lowered.error_offset, error_code_compile_init_failed);

    try emitI32Const(&body, lowered.value);
    try emitI32Const(&body, lowered.limit);
    try emitI32Const(&body, lowered.source_name_ptr);
    try emitI32Const(&body, lowered.source_name_len);
    try emitI32Const(&body, lowered.source_ptr);
    try emitStateLoadI32(&body, lowered.source_len_offset);
    try emitCall(&body, compiler_info.compile_function_index);
    try emitErrorIf(&body, lowered.error_offset, error_code_compile_failed);

    try emitCall(&body, compiler_info.output_len_function_index);
    try body.append(0x21);
    try body.appendU32Leb(0);

    try emitLocalGet(&body, 0);
    try emitI32Const(&body, 4);
    try body.append(0x49);
    try emitErrorIf(&body, lowered.error_offset, error_code_compile_output_short);

    try emitLocalGet(&body, 0);
    try emitI32Const(&body, lowered.release_capacity);
    try body.append(0x4b);
    try emitErrorIf(&body, lowered.error_offset, error_code_compile_output_too_large);

    try emitI32Const(&body, lowered.value);
    try body.append(0x28);
    try body.appendU32Leb(2);
    try body.appendU32Leb(0);
    try emitI32Const(&body, wasm_magic_word);
    try body.append(0x47);
    try emitErrorIf(&body, lowered.error_offset, error_code_compile_output_bad_magic);

    try emitI32Const(&body, lowered.release_ptr);
    try emitI32Const(&body, lowered.value);
    try emitLocalGet(&body, 0);
    try body.append(0xfc);
    try body.appendU32Leb(10);
    try body.appendU32Leb(0);
    try body.appendU32Leb(0);

    try emitI32Const(&body, lowered.release_len_offset);
    try emitLocalGet(&body, 0);
    try emitI32Store(&body);
    try emitI32Const(&body, lowered.error_offset);
    try emitI32Const(&body, error_code_ok);
    try emitI32Store(&body);
    try emitI32Const(&body, error_code_ok);
    try body.append(0x0b);

    try writer.appendU32Leb(@intCast(body.len));
    try writer.appendSlice(body.bytes[0..body.len]);
}

fn emitStateLoadI32(writer: *Writer, state_offset: i32) error{OutputTooLarge}!void {
    try emitI32Const(writer, state_offset);
    try writer.append(wasm_opcode_i32_load);
    try writer.appendU32Leb(2);
    try writer.appendU32Leb(0);
}

fn emitLocalGet(writer: *Writer, local_index: u32) error{OutputTooLarge}!void {
    try writer.append(wasm_opcode_local_get);
    try writer.appendU32Leb(local_index);
}

fn emitLocalSet(writer: *Writer, local_index: u32) error{OutputTooLarge}!void {
    try writer.append(wasm_opcode_local_set);
    try writer.appendU32Leb(local_index);
}

fn emitCall(writer: *Writer, function_index: u32) error{OutputTooLarge}!void {
    try writer.append(wasm_opcode_call);
    try writer.appendU32Leb(function_index);
}

fn emitI32Const(writer: *Writer, value: i32) error{OutputTooLarge}!void {
    try writer.append(0x41);
    try writer.appendI32Leb(value);
}

fn emitI32Store(writer: *Writer) error{OutputTooLarge}!void {
    try writer.append(wasm_opcode_i32_store);
    try writer.appendU32Leb(2);
    try writer.appendU32Leb(0);
}

fn emitI32Load8U(writer: *Writer) error{OutputTooLarge}!void {
    try writer.append(wasm_opcode_i32_load8_u);
    try writer.appendU32Leb(0);
    try writer.appendU32Leb(0);
}

fn emitI32Store8(writer: *Writer) error{OutputTooLarge}!void {
    try writer.append(wasm_opcode_i32_store8);
    try writer.appendU32Leb(0);
    try writer.appendU32Leb(0);
}

fn emitBadInputIf(writer: *Writer, error_offset: i32) error{OutputTooLarge}!void {
    try emitErrorIf(writer, error_offset, error_code_bad_input);
}

fn emitErrorIf(writer: *Writer, error_offset: i32, error_code: i32) error{OutputTooLarge}!void {
    try writer.append(0x04);
    try writer.append(0x40);
    try emitI32Const(writer, error_offset);
    try emitI32Const(writer, error_code);
    try emitI32Store(writer);
    try emitI32Const(writer, error_code);
    try writer.append(wasm_opcode_return);
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

fn emitLoweredMainFunction(writer: *Writer, lowered_main: LoweredMain) error{OutputTooLarge}!void {
    if (lowered_main.found) {
        if (lowered_main.dynamic) {
            try emitDynamicI32Function(writer, lowered_main.code);
        } else {
            try emitReturnI32Function(writer, lowered_main.value);
        }
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
    return parseI32ReturnBodyLiteral(source[body_start .. body_start + body_end_relative]);
}

fn lowerMainForMode(source_mode: SourceMode, source: []const u8, data_base: usize, calls: *const LoweredExports, function_index_base: u32) LoweredMain {
    return switch (source_mode) {
        .edgerun => lowerEdgeRunMain(source, data_base, calls, function_index_base),
    };
}

fn lowerEdgeRunMainI32Literal(source: []const u8) ?i32 {
    var empty = LoweredExports{};
    return lowerEdgeRunMain(source, 0, &empty, successor_base_function_count).staticValue();
}

fn lowerEdgeRunMain(source: []const u8, data_base: usize, calls: *const LoweredExports, function_index_base: u32) LoweredMain {
    var base_context = collectEdgeRunLoweringContext(source, data_base);
    var index: usize = 0;
    while (true) {
        index = edgerun_source.skipSpace(source, index);
        if (index == source.len) return .{ .memory_end = base_context.next_data_offset };
        if (std.mem.startsWith(u8, source[index..], const_keyword)) {
            index = edgerun_source.parseConst(source, index) orelse return .{ .memory_end = base_context.next_data_offset };
            continue;
        }
        if (std.mem.startsWith(u8, source[index..], var_keyword)) {
            const decl = parseEdgeRunVarDecl(source, index) orelse return .{ .memory_end = base_context.next_data_offset };
            index = decl.next_index;
            continue;
        }
        const parsed = edgerun_source.parseFunction(source, index) orelse return .{ .memory_end = base_context.next_data_offset };
        index = parsed.next_index;
        if (!parsed.exported or !std.mem.eql(u8, parsed.name, "er_app_main")) continue;
        if (!allWhitespace(parsed.args)) return .{ .memory_end = base_context.next_data_offset };
        if (!std.mem.eql(u8, trimAsciiWhitespace(parsed.signature_tail), "i32")) return .{ .memory_end = base_context.next_data_offset };
        if (edgeRunBodyNeedsDynamic(parsed.body)) {
            const code = compileEdgeRunDynamicReturnBody(parsed.body, &base_context, .{}, calls, function_index_base) orelse return .{ .memory_end = base_context.next_data_offset };
            return .{ .found = true, .dynamic = true, .code = code, .memory_end = base_context.next_data_offset };
        }
        const value = compileEdgeRunReturnBody(parsed.body, &base_context) orelse return .{ .memory_end = base_context.next_data_offset };
        return .{ .found = true, .value = value, .memory_end = base_context.next_data_offset };
    }
}

fn parseI32ReturnBodyLiteral(body: []const u8) ?i32 {
    const return_start_relative = std.mem.indexOf(u8, body, return_keyword) orelse return null;
    if (!allWhitespace(body[0..return_start_relative])) return null;
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

fn compileEdgeRunReturnBody(body: []const u8, base_context: *const LoweringContext) ?i32 {
    var context = base_context.*;
    var local_count: usize = 0;
    var index: usize = 0;
    while (true) {
        index = edgerun_source.skipSpace(body, index);
        if (index == body.len) return null;
        if (std.mem.startsWith(u8, body[index..], const_keyword)) {
            if (local_count >= max_edgerun_function_locals) return null;
            const decl = edgerun_source.parseConstDecl(body, index) orelse return null;
            if (context.constants.find(decl.name) != null) return null;
            const value = parseValueExpression(decl.value, &context) orelse return null;
            context.constants.append(decl.name, value);
            local_count += 1;
            index = decl.next_index;
            continue;
        }
        if (!std.mem.startsWith(u8, body[index..], return_keyword)) return null;
        const parsed = parseEdgeRunReturnStatement(body, index, &context) orelse return null;
        const end = edgerun_source.skipSpace(body, parsed.next_index);
        if (end != body.len) return null;
        return parsed.value;
    }
}

const ParsedReturnValue = struct {
    value: i32,
    next_index: usize,
};

const CompiledExpr = struct {
    bytes: [max_edgerun_expr_code_bytes]u8 = [_]u8{0} ** max_edgerun_expr_code_bytes,
    len: u8 = 0,
    local_count: u8 = 0,

    fn slice(expr: *const CompiledExpr) []const u8 {
        return expr.bytes[0..expr.len];
    }
};

const LoweredMain = struct {
    found: bool = false,
    dynamic: bool = false,
    value: i32 = 0,
    code: CompiledExpr = .{},
    memory_end: usize = 0,

    fn countI32(main: LoweredMain) i32 {
        return if (main.found) 1 else 0;
    }

    fn staticValue(main: LoweredMain) ?i32 {
        if (!main.found or main.dynamic) return null;
        return main.value;
    }
};

const EdgeRunArgs = struct {
    names: [3][]const u8 = .{ "", "", "" },
    count: u8 = 0,

    fn find(args: *const EdgeRunArgs, name: []const u8) ?u32 {
        for (args.names[0..args.count], 0..) |arg_name, index| {
            if (std.mem.eql(u8, arg_name, name)) return @intCast(index);
        }
        return null;
    }
};

const ExprBinding = struct {
    name: []const u8,
    code: CompiledExpr,
};

const ExprIndex = struct {
    entries: [max_edgerun_function_locals]ExprBinding = undefined,
    count: usize = 0,

    fn appendUnique(index: *ExprIndex, name: []const u8, code: CompiledExpr) bool {
        if (index.find(name) != null) return false;
        if (index.count >= index.entries.len) return false;
        index.entries[index.count] = .{ .name = name, .code = code };
        index.count += 1;
        return true;
    }

    fn find(index: *const ExprIndex, name: []const u8) ?*const CompiledExpr {
        for (index.entries[0..index.count]) |*entry| {
            if (std.mem.eql(u8, entry.name, name)) return &entry.code;
        }
        return null;
    }
};

const LocalVar = struct {
    name: []const u8,
    local_index: u32,
};

const LocalVarIndex = struct {
    entries: [max_edgerun_function_locals]LocalVar = undefined,
    count: usize = 0,

    fn appendUnique(index: *LocalVarIndex, name: []const u8, local_index: u32) bool {
        if (index.find(name) != null) return false;
        if (index.count >= index.entries.len) return false;
        index.entries[index.count] = .{ .name = name, .local_index = local_index };
        index.count += 1;
        return true;
    }

    fn find(index: *const LocalVarIndex, name: []const u8) ?u32 {
        for (index.entries[0..index.count]) |entry| {
            if (std.mem.eql(u8, entry.name, name)) return entry.local_index;
        }
        return null;
    }
};

fn compileEdgeRunDynamicReturnBody(body: []const u8, base_context: *LoweringContext, args: EdgeRunArgs, calls: *const LoweredExports, function_index_base: u32) ?CompiledExpr {
    var locals = ExprIndex{};
    var vars = LocalVarIndex{};
    var local_count: u8 = 0;
    var prefix = CompiledExpr{};
    var prefix_writer = Writer{ .bytes = &prefix.bytes };
    var index: usize = 0;
    while (true) {
        index = edgerun_source.skipSpace(body, index);
        if (index == body.len) return null;
        if (std.mem.startsWith(u8, body[index..], const_keyword)) {
            const decl = edgerun_source.parseConstDecl(body, index) orelse return null;
            if (!edgeRunIntegerType(decl.type_expr)) return null;
            if (args.find(decl.name) != null) return null;
            if (base_context.constants.find(decl.name) != null) return null;
            var code = CompiledExpr{};
            var writer = Writer{ .bytes = &code.bytes };
            compileEdgeRunExprCode(decl.value, base_context, args, &locals, &vars, calls, function_index_base, &writer) catch return null;
            code.len = @intCast(writer.len);
            if (!locals.appendUnique(decl.name, code)) return null;
            index = decl.next_index;
            continue;
        }
        if (std.mem.startsWith(u8, body[index..], var_keyword)) {
            const decl = parseEdgeRunVarDecl(body, index) orelse return null;
            if (!std.mem.eql(u8, trimAsciiWhitespace(decl.type_expr), "i32")) return null;
            if (args.find(decl.name) != null) return null;
            if (base_context.constants.find(decl.name) != null) return null;
            if (base_context.state_offsets.find(decl.name) != null) return null;
            if (locals.find(decl.name) != null) return null;
            if (vars.find(decl.name) != null) return null;
            if (@as(usize, local_count) >= max_edgerun_function_locals) return null;
            compileEdgeRunExprCode(decl.value, base_context, args, &locals, &vars, calls, function_index_base, &prefix_writer) catch return null;
            const local_index = @as(u32, args.count) + @as(u32, local_count);
            if (!vars.appendUnique(decl.name, local_index)) return null;
            emitLocalSet(&prefix_writer, local_index) catch return null;
            local_count += 1;
            index = decl.next_index;
            continue;
        }
        if (parseEdgeRunIndexAssignment(body, index)) |assignment| {
            compileEdgeRunIndexAssignmentCode(assignment, base_context, args, &locals, &vars, calls, function_index_base, &prefix_writer) catch return null;
            index = assignment.next_index;
            continue;
        }
        if (parseEdgeRunAssignment(body, index)) |assignment| {
            compileEdgeRunAssignmentCode(assignment, base_context, args, &locals, &vars, calls, function_index_base, &prefix_writer) catch return null;
            index = assignment.next_index;
            continue;
        }
        if (std.mem.startsWith(u8, body[index..], "while (")) {
            index = compileEdgeRunWhileStatementCode(body, index, base_context, args, &locals, &vars, calls, function_index_base, &prefix_writer) orelse return null;
            continue;
        }
        if (std.mem.startsWith(u8, body[index..], "if (")) {
            if (compileEdgeRunIfGuardReturnCode(body, index, base_context, args, &locals, &vars, calls, function_index_base, &prefix_writer)) |next_index| {
                index = next_index;
                continue;
            }
        }
        const parsed = if (std.mem.startsWith(u8, body[index..], "if ("))
            compileEdgeRunIfReturnStatementCode(body, index, base_context, args, &locals, &vars, calls, function_index_base) orelse return null
        else if (std.mem.startsWith(u8, body[index..], return_keyword))
            compileEdgeRunReturnStatementCode(body, index, base_context, args, &locals, &vars, calls, function_index_base) orelse return null
        else
            return null;
        index = edgerun_source.skipSpace(body, parsed.next_index);
        if (index != body.len) return null;
        var compiled = CompiledExpr{ .local_count = local_count };
        var writer = Writer{ .bytes = &compiled.bytes };
        writer.appendSlice(prefix.bytes[0..prefix_writer.len]) catch return null;
        writer.appendSlice(parsed.code.slice()) catch return null;
        compiled.len = @intCast(writer.len);
        return compiled;
    }
}

const ParsedReturnCode = struct {
    code: CompiledExpr,
    next_index: usize,
};

const ParsedLocalVarDecl = struct {
    name: []const u8,
    type_expr: []const u8,
    value: []const u8,
    next_index: usize,
};

const ParsedAssignment = struct {
    name: []const u8,
    value: []const u8,
    next_index: usize,
};

const ParsedIndexAssignment = struct {
    name: []const u8,
    index_expr: []const u8,
    value: []const u8,
    next_index: usize,
};

fn parseEdgeRunVarDecl(body: []const u8, start: usize) ?ParsedLocalVarDecl {
    if (!std.mem.startsWith(u8, body[start..], var_keyword)) return null;
    const name_start = skipWhitespace(body, start + var_keyword.len);
    const name_end = scanIdentifierEnd(body, name_start) orelse return null;
    const index = skipWhitespace(body, name_end);
    if (index >= body.len or body[index] != ':') return null;
    const type_start = skipWhitespace(body, index + 1);
    const equals_index = findTopLevelByte(body, type_start, '=') orelse return null;
    const type_expr = trimAsciiWhitespace(body[type_start..equals_index]);
    const value_start = skipWhitespace(body, equals_index + 1);
    const value_end = findTopLevelByte(body, value_start, ';') orelse return null;
    const value = trimAsciiWhitespace(body[value_start..value_end]);
    if (type_expr.len == 0 or value.len == 0) return null;
    return .{
        .name = body[name_start..name_end],
        .type_expr = type_expr,
        .value = value,
        .next_index = value_end + 1,
    };
}

fn parseEdgeRunAssignment(body: []const u8, start: usize) ?ParsedAssignment {
    const name_end = scanIdentifierEnd(body, start) orelse return null;
    const index = skipWhitespace(body, name_end);
    if (index >= body.len or body[index] != '=') return null;
    if (index + 1 < body.len and body[index + 1] == '=') return null;
    const value_start = skipWhitespace(body, index + 1);
    const value_end = findTopLevelByte(body, value_start, ';') orelse return null;
    const value = trimAsciiWhitespace(body[value_start..value_end]);
    if (value.len == 0) return null;
    return .{
        .name = body[start..name_end],
        .value = value,
        .next_index = value_end + 1,
    };
}

fn parseEdgeRunIndexAssignment(body: []const u8, start: usize) ?ParsedIndexAssignment {
    const name_end = scanIdentifierEnd(body, start) orelse return null;
    const name = body[start..name_end];
    var index = skipWhitespace(body, name_end);
    if (index >= body.len or body[index] != '[') return null;
    const index_end = findMatchingBracket(body, index) orelse return null;
    const index_expr = trimAsciiWhitespace(body[index + 1 .. index_end]);
    index = skipWhitespace(body, index_end + 1);
    if (index >= body.len or body[index] != '=') return null;
    if (index + 1 < body.len and body[index + 1] == '=') return null;
    const value_start = skipWhitespace(body, index + 1);
    const value_end = findTopLevelByte(body, value_start, ';') orelse return null;
    const value = trimAsciiWhitespace(body[value_start..value_end]);
    if (index_expr.len == 0 or value.len == 0) return null;
    return .{
        .name = name,
        .index_expr = index_expr,
        .value = value,
        .next_index = value_end + 1,
    };
}

fn compileEdgeRunAssignmentCode(assignment: ParsedAssignment, context: *LoweringContext, args: EdgeRunArgs, locals: *const ExprIndex, vars: *const LocalVarIndex, calls: *const LoweredExports, function_index_base: u32, writer: *Writer) error{ OutputTooLarge, InvalidSource }!void {
    if (vars.find(assignment.name)) |local_index| {
        try compileEdgeRunExprCode(assignment.value, context, args, locals, vars, calls, function_index_base, writer);
        try emitLocalSet(writer, local_index);
        return;
    }
    if (context.state_offsets.find(assignment.name)) |state_offset| {
        try emitI32Const(writer, state_offset);
        try compileEdgeRunExprCode(assignment.value, context, args, locals, vars, calls, function_index_base, writer);
        try emitI32Store(writer);
        return;
    }
    return error.InvalidSource;
}

fn compileEdgeRunIndexAssignmentCode(assignment: ParsedIndexAssignment, context: *LoweringContext, args: EdgeRunArgs, locals: *const ExprIndex, vars: *const LocalVarIndex, calls: *const LoweredExports, function_index_base: u32, writer: *Writer) error{ OutputTooLarge, InvalidSource }!void {
    const base = pointerForArray(context, assignment.name) orelse return error.InvalidSource;
    try emitI32Const(writer, base);
    try compileEdgeRunExprCode(assignment.index_expr, context, args, locals, vars, calls, function_index_base, writer);
    try writer.append(wasm_opcode_i32_add);
    try compileEdgeRunExprCode(assignment.value, context, args, locals, vars, calls, function_index_base, writer);
    try emitI32Store8(writer);
}

fn compileEdgeRunWhileStatementCode(body: []const u8, start: usize, context: *LoweringContext, args: EdgeRunArgs, locals: *const ExprIndex, vars: *const LocalVarIndex, calls: *const LoweredExports, function_index_base: u32, writer: *Writer) ?usize {
    const condition_end = findMatchingParen(body, start + "while ".len) orelse return null;
    const condition = body[start + "while (".len .. condition_end];
    const index = skipWhitespace(body, condition_end + 1);
    if (index >= body.len or body[index] != '{') return null;
    const body_end = findMatchingBrace(body, index) orelse return null;
    const loop_body = body[index + 1 .. body_end];

    writer.append(wasm_opcode_block) catch return null;
    writer.append(wasm_block_type_empty) catch return null;
    writer.append(wasm_opcode_loop) catch return null;
    writer.append(wasm_block_type_empty) catch return null;
    compileEdgeRunConditionCode(condition, context, args, locals, vars, calls, function_index_base, writer) catch return null;
    writer.append(wasm_opcode_i32_eqz) catch return null;
    writer.append(wasm_opcode_br_if) catch return null;
    writer.appendU32Leb(1) catch return null;
    compileEdgeRunLoopBodyCode(loop_body, context, args, locals, vars, calls, function_index_base, writer) catch return null;
    writer.append(wasm_opcode_br) catch return null;
    writer.appendU32Leb(0) catch return null;
    writer.append(wasm_opcode_end) catch return null;
    writer.append(wasm_opcode_end) catch return null;
    return body_end + 1;
}

fn compileEdgeRunLoopBodyCode(body: []const u8, context: *LoweringContext, args: EdgeRunArgs, locals: *const ExprIndex, vars: *const LocalVarIndex, calls: *const LoweredExports, function_index_base: u32, writer: *Writer) error{ OutputTooLarge, InvalidSource }!void {
    var index: usize = 0;
    while (true) {
        index = edgerun_source.skipSpace(body, index);
        if (index == body.len) return;
        if (parseEdgeRunIndexAssignment(body, index)) |assignment| {
            try compileEdgeRunIndexAssignmentCode(assignment, context, args, locals, vars, calls, function_index_base, writer);
            index = assignment.next_index;
            continue;
        }
        if (parseEdgeRunAssignment(body, index)) |assignment| {
            try compileEdgeRunAssignmentCode(assignment, context, args, locals, vars, calls, function_index_base, writer);
            index = assignment.next_index;
            continue;
        }
        if (std.mem.startsWith(u8, body[index..], "while (")) {
            index = compileEdgeRunWhileStatementCode(body, index, context, args, locals, vars, calls, function_index_base, writer) orelse return error.InvalidSource;
            continue;
        }
        if (std.mem.startsWith(u8, body[index..], "if (")) {
            index = compileEdgeRunIfGuardReturnCode(body, index, context, args, locals, vars, calls, function_index_base, writer) orelse return error.InvalidSource;
            continue;
        }
        return error.InvalidSource;
    }
}

fn compileEdgeRunIfGuardReturnCode(body: []const u8, start: usize, context: *LoweringContext, args: EdgeRunArgs, locals: *const ExprIndex, vars: *const LocalVarIndex, calls: *const LoweredExports, function_index_base: u32, writer: *Writer) ?usize {
    const condition_end = findMatchingParen(body, start + "if ".len) orelse return null;
    const condition = body[start + "if (".len .. condition_end];
    var index = skipWhitespace(body, condition_end + 1);
    if (index >= body.len or body[index] != '{') return null;
    const then_end = findMatchingBrace(body, index) orelse return null;
    const return_code = compileEdgeRunReturnBlockCode(body[index + 1 .. then_end], context, args, locals, vars, calls, function_index_base) orelse return null;
    index = skipWhitespace(body, then_end + 1);
    if (std.mem.startsWith(u8, body[index..], "else")) return null;
    compileEdgeRunConditionCode(condition, context, args, locals, vars, calls, function_index_base, writer) catch return null;
    writer.append(wasm_opcode_if) catch return null;
    writer.append(wasm_block_type_empty) catch return null;
    writer.appendSlice(return_code.code.slice()) catch return null;
    writer.append(wasm_opcode_return) catch return null;
    writer.append(wasm_opcode_end) catch return null;
    return then_end + 1;
}

fn compileEdgeRunIfReturnStatementCode(body: []const u8, start: usize, context: *LoweringContext, args: EdgeRunArgs, locals: *const ExprIndex, vars: *const LocalVarIndex, calls: *const LoweredExports, function_index_base: u32) ?ParsedReturnCode {
    const condition_end = findMatchingParen(body, start + "if ".len) orelse return null;
    const condition = body[start + "if (".len .. condition_end];
    var index = skipWhitespace(body, condition_end + 1);
    if (index >= body.len or body[index] != '{') return null;
    const then_end = findMatchingBrace(body, index) orelse return null;
    const then_code = compileEdgeRunReturnBlockCode(body[index + 1 .. then_end], context, args, locals, vars, calls, function_index_base) orelse return null;
    index = skipWhitespace(body, then_end + 1);
    if (!std.mem.startsWith(u8, body[index..], "else")) return null;
    const after_else = index + "else".len;
    if (after_else < body.len and identifierContinue(body[after_else])) return null;
    index = skipWhitespace(body, after_else);
    if (index >= body.len or body[index] != '{') return null;
    const else_end = findMatchingBrace(body, index) orelse return null;
    const else_code = compileEdgeRunReturnBlockCode(body[index + 1 .. else_end], context, args, locals, vars, calls, function_index_base) orelse return null;

    var compiled = CompiledExpr{};
    var writer = Writer{ .bytes = &compiled.bytes };
    compileEdgeRunConditionCode(condition, context, args, locals, vars, calls, function_index_base, &writer) catch return null;
    writer.append(wasm_opcode_if) catch return null;
    writer.append(wasm_block_type_i32) catch return null;
    writer.appendSlice(then_code.code.slice()) catch return null;
    writer.append(wasm_opcode_else) catch return null;
    writer.appendSlice(else_code.code.slice()) catch return null;
    writer.append(wasm_opcode_end) catch return null;
    compiled.len = @intCast(writer.len);
    return .{
        .code = compiled,
        .next_index = else_end + 1,
    };
}

fn compileEdgeRunReturnBlockCode(block: []const u8, context: *LoweringContext, args: EdgeRunArgs, locals: *const ExprIndex, vars: *const LocalVarIndex, calls: *const LoweredExports, function_index_base: u32) ?ParsedReturnCode {
    var index = edgerun_source.skipSpace(block, 0);
    if (!std.mem.startsWith(u8, block[index..], return_keyword)) return null;
    const parsed = compileEdgeRunReturnStatementCode(block, index, context, args, locals, vars, calls, function_index_base) orelse return null;
    index = edgerun_source.skipSpace(block, parsed.next_index);
    if (index != block.len) return null;
    return parsed;
}

fn compileEdgeRunReturnStatementCode(body: []const u8, start: usize, context: *LoweringContext, args: EdgeRunArgs, locals: *const ExprIndex, vars: *const LocalVarIndex, calls: *const LoweredExports, function_index_base: u32) ?ParsedReturnCode {
    var index = start + return_keyword.len;
    if (index < body.len and identifierContinue(body[index])) return null;
    index = skipWhitespace(body, index);
    const value_start = index;
    const semicolon_relative = std.mem.indexOfScalar(u8, body[value_start..], ';') orelse return null;
    const value_end = value_start + semicolon_relative;
    var compiled = CompiledExpr{};
    var writer = Writer{ .bytes = &compiled.bytes };
    compileEdgeRunExprCode(body[value_start..value_end], context, args, locals, vars, calls, function_index_base, &writer) catch return null;
    compiled.len = @intCast(writer.len);
    return .{
        .code = compiled,
        .next_index = value_end + 1,
    };
}

fn compileEdgeRunExprCode(raw: []const u8, context: *LoweringContext, args: EdgeRunArgs, locals: *const ExprIndex, vars: *const LocalVarIndex, calls: *const LoweredExports, function_index_base: u32, writer: *Writer) error{ OutputTooLarge, InvalidSource }!void {
    var tok = edgerun_source.tokenize(raw);
    return compileEdgeRunExprTokens(&tok, context, args, locals, vars, calls, function_index_base, writer);
}

fn compileEdgeRunExprTokens(tok: *edgerun_source.Tokenizer, context: *LoweringContext, args: EdgeRunArgs, locals: *const ExprIndex, vars: *const LocalVarIndex, calls: *const LoweredExports, function_index_base: u32, writer: *Writer) error{ OutputTooLarge, InvalidSource }!void {
    try parseExprComparison(tok, context, args, locals, vars, calls, function_index_base, writer);
    const token = tok.next();
    if (token != .eof) return error.InvalidSource;
}

fn parseExprComparison(tok: *edgerun_source.Tokenizer, context: *LoweringContext, args: EdgeRunArgs, locals: *const ExprIndex, vars: *const LocalVarIndex, calls: *const LoweredExports, function_index_base: u32, writer: *Writer) error{ OutputTooLarge, InvalidSource }!void {
    try parseExprAddSub(tok, context, args, locals, vars, calls, function_index_base, writer);
    const op_token = tok.peek();
    const op: u8 = switch (op_token) {
        .eq_eq => wasm_opcode_i32_eq,
        .not_eq => wasm_opcode_i32_ne,
        .lt => wasm_opcode_i32_lt_s,
        .gt => wasm_opcode_i32_gt_s,
        .lt_eq => wasm_opcode_i32_le_s,
        .gt_eq => wasm_opcode_i32_ge_s,
        else => return,
    };
    _ = tok.next();
    try parseExprAddSub(tok, context, args, locals, vars, calls, function_index_base, writer);
    try writer.append(op);
}

fn parseExprAddSub(tok: *edgerun_source.Tokenizer, context: *LoweringContext, args: EdgeRunArgs, locals: *const ExprIndex, vars: *const LocalVarIndex, calls: *const LoweredExports, function_index_base: u32, writer: *Writer) error{ OutputTooLarge, InvalidSource }!void {
    try parseExprMulDiv(tok, context, args, locals, vars, calls, function_index_base, writer);
    while (true) {
        const op = tok.peek();
        const opcode: u8 = switch (op) {
            .plus => wasm_opcode_i32_add,
            .minus => wasm_opcode_i32_sub,
            else => return,
        };
        _ = tok.next();
        try parseExprMulDiv(tok, context, args, locals, vars, calls, function_index_base, writer);
        try writer.append(opcode);
    }
}

fn parseExprMulDiv(tok: *edgerun_source.Tokenizer, context: *LoweringContext, args: EdgeRunArgs, locals: *const ExprIndex, vars: *const LocalVarIndex, calls: *const LoweredExports, function_index_base: u32, writer: *Writer) error{ OutputTooLarge, InvalidSource }!void {
    try parseExprPrimary(tok, context, args, locals, vars, calls, function_index_base, writer);
    while (true) {
        const op = tok.peek();
        const opcode: u8 = switch (op) {
            .star => wasm_opcode_i32_mul,
            .slash => wasm_opcode_i32_div_s,
            .percent => wasm_opcode_i32_rem_s,
            else => return,
        };
        _ = tok.next();
        try parseExprPrimary(tok, context, args, locals, vars, calls, function_index_base, writer);
        try writer.append(opcode);
    }
}

fn parseExprPrimary(tok: *edgerun_source.Tokenizer, context: *LoweringContext, args: EdgeRunArgs, locals: *const ExprIndex, vars: *const LocalVarIndex, calls: *const LoweredExports, function_index_base: u32, writer: *Writer) error{ OutputTooLarge, InvalidSource }!void {
    const token = tok.next();
    switch (token) {
        .keyword_true => try emitI32Const(writer, 1),
        .keyword_false => try emitI32Const(writer, 0),
        .minus => {
            try emitI32Const(writer, 0);
            try parseExprPrimary(tok, context, args, locals, vars, calls, function_index_base, writer);
            try writer.append(wasm_opcode_i32_sub);
        },
        .integer_literal => |literal| {
            const value = parseIntLiteral(literal) orelse return error.InvalidSource;
            try emitI32Const(writer, value);
        },
        .builtin_int_cast => {
            if (tok.next() != .lparen) return error.InvalidSource;
            try parseExprComparison(tok, context, args, locals, vars, calls, function_index_base, writer);
            if (tok.next() != .rparen) return error.InvalidSource;
        },
        .builtin_int_from_enum => {
            if (tok.next() != .lparen) return error.InvalidSource;
            const arg_text = try collectTokenArgText(tok);
            const parsed = parseValueExpression(arg_text, context) orelse return error.InvalidSource;
            try emitI32Const(writer, parsed);
        },
        .builtin_int_from_ptr => {
            if (tok.next() != .lparen) return error.InvalidSource;
            const arg_text = try collectTokenArgText(tok);
            const parsed = parsePointerExpression(arg_text, context) orelse return error.InvalidSource;
            try emitI32Const(writer, parsed);
        },
        .keyword_if => {
            if (tok.next() != .lparen) return error.InvalidSource;
            try parseExprComparison(tok, context, args, locals, vars, calls, function_index_base, writer);
            if (tok.next() != .rparen) return error.InvalidSource;
            try writer.append(wasm_opcode_if);
            try writer.append(wasm_block_type_i32);
            try parseExprComparison(tok, context, args, locals, vars, calls, function_index_base, writer);
            if (tok.next() != .keyword_else) return error.InvalidSource;
            try writer.append(wasm_opcode_else);
            try parseExprComparison(tok, context, args, locals, vars, calls, function_index_base, writer);
            try writer.append(wasm_opcode_end);
        },
        .builtin_import => {
            if (tok.next() != .lparen) return error.InvalidSource;
            if (tok.next() != .string_literal) return error.InvalidSource;
            if (tok.next() != .rparen) return error.InvalidSource;
        },
        .identifier => |name| {
            if (tok.peek() == .dot) {
                _ = tok.next();
                const suffix = tok.next();
                if (suffix == .identifier) {
                    if (std.mem.eql(u8, suffix.identifier, "len")) {
                        if (context.array_lengths.find(name)) |value| {
                            try emitI32Const(writer, value);
                            return;
                        }
                        return error.InvalidSource;
                    }
                    if (tok.peek() == .lparen) {
                        const qualified_name_len = name.len + 1 + suffix.identifier.len;
                        if (qualified_name_len > vfs_label_max) return error.InvalidSource;
                        var qualified_buf: [vfs_label_max]u8 = undefined;
                        @memcpy(qualified_buf[0..name.len], name);
                        qualified_buf[name.len] = '.';
                        @memcpy(qualified_buf[name.len + 1 .. qualified_name_len], suffix.identifier);
                        const qualified_name = qualified_buf[0..qualified_name_len];
                        _ = tok.next();
                        var parsed_args: [3][]const u8 = .{ "", "", "" };
                        var arg_count: u8 = 0;
                        if (tok.peek() != .rparen) {
                            while (true) {
                                if (arg_count >= parsed_args.len) return error.InvalidSource;
                                const arg_start = tok.index;
                                try skipBalancedExpr(tok);
                                parsed_args[arg_count] = tok.source[arg_start..tok.index];
                                arg_count += 1;
                                const sep = tok.next();
                                if (sep == .rparen) break;
                                if (sep != .comma) return error.InvalidSource;
                            }
                        } else {
                            _ = tok.next();
                        }
                        const target = calls.findCall(qualified_name, arg_count, function_index_base) orelse return error.InvalidSource;
                        var arg_index: u8 = 0;
                        while (arg_index < arg_count) : (arg_index += 1) {
                            try compileEdgeRunExprCode(parsed_args[arg_index], context, args, locals, vars, calls, function_index_base, writer);
                        }
                        try emitCall(writer, target);
                        return;
                    }
                }
                return error.InvalidSource;
            }
            if (tok.peek() == .lbracket) {
                _ = tok.next();
                const base = pointerForArray(context, name) orelse return error.InvalidSource;
                try emitI32Const(writer, base);
                try parseExprAddSub(tok, context, args, locals, vars, calls, function_index_base, writer);
                if (tok.next() != .rbracket) return error.InvalidSource;
                try writer.append(wasm_opcode_i32_add);
                try emitI32Load8U(writer);
            } else if (tok.peek() == .lparen) {
                _ = tok.next();
                var parsed_args: [3][]const u8 = .{ "", "", "" };
                var arg_count: u8 = 0;
                if (tok.peek() != .rparen) {
                    while (true) {
                        if (arg_count >= parsed_args.len) return error.InvalidSource;
                        const arg_start = tok.index;
                        try skipBalancedExpr(tok);
                        parsed_args[arg_count] = tok.source[arg_start..tok.index];
                        arg_count += 1;
                        const sep = tok.next();
                        if (sep == .rparen) break;
                        if (sep != .comma) return error.InvalidSource;
                    }
                } else {
                    _ = tok.next();
                }
                const target = calls.findCall(name, arg_count, function_index_base) orelse return error.InvalidSource;
                var arg_index: u8 = 0;
                while (arg_index < arg_count) : (arg_index += 1) {
                    try compileEdgeRunExprCode(parsed_args[arg_index], context, args, locals, vars, calls, function_index_base, writer);
                }
                try emitCall(writer, target);
            } else if (args.find(name)) |arg_index| {
                try emitLocalGet(writer, arg_index);
            } else if (vars.find(name)) |local_index| {
                try emitLocalGet(writer, local_index);
            } else if (locals.find(name)) |code| {
                try writer.appendSlice(code.slice());
            } else if (context.state_offsets.find(name)) |state_offset| {
                try emitStateLoadI32(writer, state_offset);
            } else if (parseValueExpression(name, context)) |value| {
                try emitI32Const(writer, value);
            } else {
                return error.InvalidSource;
            }
        },
        .string_literal => {
            const text = tok.source[tok.index - 1 .. tok.index];
            if (parseValueExpression(text, context)) |value| {
                try emitI32Const(writer, value);
                return;
            }
            return error.InvalidSource;
        },
        .lparen => {
            try parseExprComparison(tok, context, args, locals, vars, calls, function_index_base, writer);
            if (tok.next() != .rparen) return error.InvalidSource;
        },
        else => return error.InvalidSource,
    }
}

fn skipBalancedExpr(tok: *edgerun_source.Tokenizer) error{ OutputTooLarge, InvalidSource }!void {
    var depth: usize = 0;
    while (true) {
        const t = tok.peek();
        switch (t) {
            .eof => return error.InvalidSource,
            .lparen, .lbrace, .lbracket => {
                _ = tok.next();
                depth += 1;
            },
            .rparen, .rbrace, .rbracket, .comma => {
                if (depth == 0) return;
                _ = tok.next();
                depth -= 1;
            },
            else => {
                _ = tok.next();
            },
        }
    }
}

fn collectTokenArgText(tok: *edgerun_source.Tokenizer) error{ OutputTooLarge, InvalidSource }![]const u8 {
    const start = tok.index;
    var depth: usize = 1;
    while (true) {
        if (tok.index >= tok.source.len) return error.InvalidSource;
        const byte = tok.source[tok.index];
        tok.index += 1;
        switch (byte) {
            '(' => depth += 1,
            ')' => {
                depth -= 1;
                if (depth == 0) return tok.source[start .. tok.index - 1];
            },
            else => {},
        }
    }
}

fn parseIntLiteral(literal: []const u8) ?i32 {
    return std.fmt.parseInt(i32, literal, 10) catch null;
}

fn compileEdgeRunConditionCode(raw: []const u8, context: *LoweringContext, args: EdgeRunArgs, locals: *const ExprIndex, vars: *const LocalVarIndex, calls: *const LoweredExports, function_index_base: u32, writer: *Writer) error{ OutputTooLarge, InvalidSource }!void {
    var tok = edgerun_source.tokenize(raw);
    try parseExprComparison(&tok, context, args, locals, vars, calls, function_index_base, writer);
    if (tok.next() != .eof) return error.InvalidSource;
}

const ExprSplit = struct {
    left: []const u8,
    right: []const u8,
};

const ExprOperatorSplit = struct {
    left: []const u8,
    right: []const u8,
    operator: u8,
};

fn splitTopLevelToken(text: []const u8, token: []const u8) ?ExprSplit {
    if (token.len == 0 or token.len > text.len) return null;
    var paren_depth: usize = 0;
    var bracket_depth: usize = 0;
    var index: usize = 0;
    while (index + token.len <= text.len) : (index += 1) {
        switch (text[index]) {
            '(' => paren_depth += 1,
            ')' => {
                if (paren_depth == 0) return null;
                paren_depth -= 1;
            },
            '[' => bracket_depth += 1,
            ']' => {
                if (bracket_depth == 0) return null;
                bracket_depth -= 1;
            },
            else => {},
        }
        if (paren_depth == 0 and bracket_depth == 0 and std.mem.eql(u8, text[index..][0..token.len], token)) {
            return .{
                .left = text[0..index],
                .right = text[index + token.len ..],
            };
        }
    }
    return null;
}

fn findTopLevelByte(text: []const u8, start: usize, target: u8) ?usize {
    var paren_depth: usize = 0;
    var bracket_depth: usize = 0;
    var index = start;
    while (index < text.len) : (index += 1) {
        switch (text[index]) {
            '(' => paren_depth += 1,
            ')' => {
                if (paren_depth == 0) return null;
                paren_depth -= 1;
            },
            '[' => bracket_depth += 1,
            ']' => {
                if (bracket_depth == 0) return null;
                bracket_depth -= 1;
            },
            else => {},
        }
        if (paren_depth == 0 and bracket_depth == 0 and text[index] == target) return index;
    }
    return null;
}

fn splitTopLevelOperator(text: []const u8, operator: u8) ?ExprSplit {
    const split = splitTopLevelOperators(text, &.{operator}) orelse return null;
    return .{
        .left = split.left,
        .right = split.right,
    };
}

fn splitTopLevelOperators(text: []const u8, operators: []const u8) ?ExprOperatorSplit {
    var index = text.len;
    var paren_depth: usize = 0;
    var bracket_depth: usize = 0;
    while (index > 0) {
        index -= 1;
        switch (text[index]) {
            ')' => paren_depth += 1,
            '(' => {
                if (paren_depth == 0) return null;
                paren_depth -= 1;
            },
            ']' => bracket_depth += 1,
            '[' => {
                if (bracket_depth == 0) return null;
                bracket_depth -= 1;
            },
            else => {},
        }
        if (paren_depth != 0 or bracket_depth != 0) continue;
        if (!operatorCandidate(text[index], operators)) continue;
        if (!binaryOperatorAt(text, index)) continue;
        return .{
            .left = text[0..index],
            .right = text[index + 1 ..],
            .operator = text[index],
        };
    }
    return null;
}

fn operatorCandidate(byte: u8, operators: []const u8) bool {
    for (operators) |operator| {
        if (byte == operator) return true;
    }
    return false;
}

fn binaryOperatorAt(text: []const u8, index: usize) bool {
    if (index == 0 or index + 1 >= text.len) return false;
    var before = index;
    while (before > 0 and asciiWhitespace(text[before - 1])) : (before -= 1) {}
    if (before == 0) return false;
    return switch (text[before - 1]) {
        '+', '-', '*', '/', '%', '(', ',', '<', '>', '=' => false,
        else => true,
    };
}

fn findMatchingParen(text: []const u8, open_index: usize) ?usize {
    if (open_index >= text.len or text[open_index] != '(') return null;
    var depth: usize = 1;
    var index = open_index + 1;
    while (index < text.len) : (index += 1) {
        switch (text[index]) {
            '(' => depth += 1,
            ')' => {
                depth -= 1;
                if (depth == 0) return index;
            },
            else => {},
        }
    }
    return null;
}

fn findMatchingBrace(text: []const u8, open_index: usize) ?usize {
    if (open_index >= text.len or text[open_index] != '{') return null;
    var depth: usize = 1;
    var index = open_index + 1;
    while (index < text.len) : (index += 1) {
        switch (text[index]) {
            '{' => depth += 1,
            '}' => {
                depth -= 1;
                if (depth == 0) return index;
            },
            else => {},
        }
    }
    return null;
}

fn findMatchingBracket(text: []const u8, open_index: usize) ?usize {
    if (open_index >= text.len or text[open_index] != '[') return null;
    var depth: usize = 1;
    var index = open_index + 1;
    while (index < text.len) : (index += 1) {
        switch (text[index]) {
            '[' => depth += 1,
            ']' => {
                depth -= 1;
                if (depth == 0) return index;
            },
            else => {},
        }
    }
    return null;
}

fn parseEdgeRunWasm32Args(args: []const u8) ?EdgeRunArgs {
    const text = trimAsciiWhitespace(args);
    if (text.len == 0) return null;
    var result = EdgeRunArgs{};
    var remaining = text;
    while (true) {
        if (splitTopLevelToken(remaining, ",")) |split| {
            if (!appendEdgeRunWasm32Arg(&result, split.left)) return null;
            remaining = split.right;
            continue;
        }
        if (!appendEdgeRunWasm32Arg(&result, remaining)) return null;
        break;
    }
    return result;
}

fn appendEdgeRunWasm32Arg(args: *EdgeRunArgs, raw: []const u8) bool {
    if (args.count >= args.names.len) return false;
    const text = trimAsciiWhitespace(raw);
    const colon_relative = std.mem.indexOfScalar(u8, text, ':') orelse return false;
    const name = trimAsciiWhitespace(text[0..colon_relative]);
    const type_name = trimAsciiWhitespace(text[colon_relative + 1 ..]);
    const name_end = scanIdentifierEnd(name, 0) orelse return false;
    if (name_end != name.len) return false;
    if (!edgeRunWasm32ArgType(type_name)) return false;
    if (args.find(name) != null) return false;
    args.names[args.count] = name;
    args.count += 1;
    return true;
}

fn edgeRunWasm32ArgType(type_name: []const u8) bool {
    return std.mem.eql(u8, type_name, "i32") or
        std.mem.eql(u8, type_name, "u32") or
        std.mem.eql(u8, type_name, "usize");
}

fn edgeRunIntegerType(type_expr: []const u8) bool {
    const text = trimAsciiWhitespace(type_expr);
    return std.mem.eql(u8, text, "i32") or
        std.mem.eql(u8, text, "u32") or
        std.mem.eql(u8, text, "usize");
}

fn parseEdgeRunReturnStatement(body: []const u8, start: usize, context: *LoweringContext) ?ParsedReturnValue {
    var index = start + return_keyword.len;
    if (index < body.len and identifierContinue(body[index])) return null;
    index = skipWhitespace(body, index);
    const value_start = index;
    const semicolon_relative = std.mem.indexOfScalar(u8, body[value_start..], ';') orelse return null;
    const value_end = value_start + semicolon_relative;
    const value = parseReturnExpressionValue(body[value_start..value_end], context) orelse return null;
    return .{
        .value = value,
        .next_index = value_end + 1,
    };
}

fn parseReturnExpressionValue(raw: []const u8, context: *LoweringContext) ?i32 {
    const text = trimAsciiWhitespace(raw);
    if (text.len == 0) return null;
    if (std.mem.startsWith(u8, text, "@intCast(")) {
        const value = unwrapCallArgument(text, "@intCast(") orelse return null;
        return parseValueExpression(value, context);
    }
    if (std.mem.startsWith(u8, text, "@intFromEnum(")) {
        const value = unwrapCallArgument(text, "@intFromEnum(") orelse return null;
        return parseValueExpression(value, context);
    }
    if (std.mem.startsWith(u8, text, "@intFromPtr(")) {
        const value = unwrapCallArgument(text, "@intFromPtr(") orelse return null;
        return parsePointerExpression(value, context);
    }
    return parseValueExpression(text, context);
}

fn unwrapCallArgument(text: []const u8, prefix: []const u8) ?[]const u8 {
    if (!std.mem.startsWith(u8, text, prefix)) return null;
    if (text.len <= prefix.len or text[text.len - 1] != ')') return null;
    return text[prefix.len .. text.len - 1];
}

fn collectLoweredExports(source: []const u8, data_base: usize, compiler_wasm_offset: i32, compiler_wasm_len: i32) LoweredExports {
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
        if (compiler_wasm_len > 0 and compiler_wasm_offset > 0 and std.mem.eql(u8, name, "er_ui_compiler_wasm_ptr")) {
            lowered.append(name, compiler_wasm_offset);
            continue;
        }
        if (compiler_wasm_len > 0 and compiler_wasm_offset > 0 and std.mem.eql(u8, name, "er_ui_compiler_wasm_len")) {
            lowered.append(name, compiler_wasm_len);
            continue;
        }
        if (compiler_wasm_len > 0 and stateful_source_workspace and stateful_release_artifact and std.mem.eql(u8, name, "er_ui_compile_workspace_wasm")) {
            const source_ptr = pointerForArray(&context, "source_workspace") orelse continue;
            const source_capacity = context.array_lengths.find("source_workspace") orelse continue;
            const release_ptr = pointerForArray(&context, "release_artifact") orelse continue;
            const release_capacity = context.array_lengths.find("release_artifact") orelse continue;
            const compiler_runtime_offset_usize = alignForwardUsize(context.next_data_offset, memory_alignment);
            const compiler_runtime_offset: i32 = @intCast(compiler_runtime_offset_usize);
            context.next_data_offset = compiler_runtime_offset_usize + linked_compiler_runtime_capacity;
            lowered.appendCompileWorkspace(.{
                .name = Label.init(name),
                .value = compiler_runtime_offset,
                .limit = @intCast(linked_compiler_runtime_capacity),
                .source_ptr = source_ptr,
                .source_len_offset = source_workspace_len_offset,
                .source_capacity = source_capacity,
                .release_ptr = release_ptr,
                .release_len_offset = release_artifact_len_offset,
                .release_capacity = release_capacity,
                .error_offset = last_error_offset,
                .kind = .compile_workspace,
            });
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

fn collectLoweredExportsForMode(source_mode: SourceMode, source: []const u8, data_base: usize, compiler_wasm_offset: i32, compiler_wasm_len: i32, function_index_base: u32) LoweredExports {
    return switch (source_mode) {
        .edgerun => collectEdgeRunLoweredExports(source, data_base, compiler_wasm_offset, compiler_wasm_len, function_index_base),
    };
}

fn collectWorkspaceLoweredExportsForMode(source_mode: SourceMode, workspace: WorkspaceInfo, data_base: usize, compiler_wasm_offset: i32, compiler_wasm_len: i32, function_index_base: u32) LoweredExports {
    return switch (source_mode) {
        .edgerun => collectEdgeRunWorkspaceLoweredExports(workspace, data_base, compiler_wasm_offset, compiler_wasm_len, function_index_base),
    };
}

fn collectEdgeRunLoweredExports(source: []const u8, data_base: usize, compiler_wasm_offset: i32, compiler_wasm_len: i32, function_index_base: u32) LoweredExports {
    return collectEdgeRunLoweredExportsWithPrelude(source, default_root_label, data_base, compiler_wasm_offset, compiler_wasm_len, function_index_base, .{ .memory_end = data_base });
}

fn collectEdgeRunWorkspaceLoweredExports(workspace: WorkspaceInfo, data_base: usize, compiler_wasm_offset: i32, compiler_wasm_len: i32, function_index_base: u32) LoweredExports {
    var stack = ImportStack{};
    return collectEdgeRunModuleLoweredExports(workspace, workspace.root_label, workspace.root_source, data_base, compiler_wasm_offset, compiler_wasm_len, function_index_base, &stack);
}

fn collectEdgeRunModuleLoweredExports(
    workspace: WorkspaceInfo,
    label: []const u8,
    source: []const u8,
    data_base: usize,
    compiler_wasm_offset: i32,
    compiler_wasm_len: i32,
    function_index_base: u32,
    stack: *ImportStack,
) LoweredExports {
    if (!stack.push(label)) return invalidEdgeRunLowered(data_base);
    defer stack.pop();
    const imports = scanEdgeRunImports(source) orelse return invalidEdgeRunLowered(data_base);
    var lowered = LoweredExports{ .memory_end = data_base };
    for (imports.labels[0..imports.label_count], 0..) |*import_label, import_index| {
        const imported_source = findWorkspaceFile(workspace.manifest, import_label.slice()) orelse continue;
        const imported = collectEdgeRunModuleLoweredExports(workspace, import_label.slice(), imported_source, lowered.memory_end, 0, 0, function_index_base + lowered.count, stack);
        if (imported.count == 0 and imported.declared_count != 0) return invalidEdgeRunLowered(lowered.memory_end);
        appendImportedModuleExports(&lowered, imports.aliases[import_index].slice(), imported) orelse return invalidEdgeRunLowered(lowered.memory_end);
        lowered.memory_end = imported.memory_end;
    }
    return collectEdgeRunLoweredExportsWithPrelude(source, label, lowered.memory_end, compiler_wasm_offset, compiler_wasm_len, function_index_base, lowered);
}

fn collectEdgeRunLoweredExportsWithPrelude(source: []const u8, root_label: []const u8, data_base: usize, compiler_wasm_offset: i32, compiler_wasm_len: i32, function_index_base: u32, prelude: LoweredExports) LoweredExports {
    var context = collectEdgeRunLoweringContext(source, data_base);
    const stateful_release_artifact = sourceHasReleaseArtifactCommitPattern(source) and context.array_lengths.find("release_artifact") != null;
    const stateful_source_workspace = sourceHasSourceWorkspaceCommitPattern(source) and context.array_lengths.find("source_workspace") != null;
    const release_artifact_len_offset = if (stateful_release_artifact) reserveI32StateSlot(&context) else 0;
    const source_workspace_len_offset = if (stateful_source_workspace) reserveI32StateSlot(&context) else 0;
    const source_workspace_ready_offset = if (stateful_source_workspace) reserveI32StateSlot(&context) else 0;
    const last_error_offset = if (stateful_release_artifact or stateful_source_workspace) reserveI32StateSlot(&context) else 0;
    var lowered = prelude;
    lowered.memory_end = context.next_data_offset;
    var decls = EdgeRunFunctionDecls{};
    var index: usize = 0;
    while (true) {
        index = edgerun_source.skipSpace(source, index);
        if (index == source.len) break;
        if (std.mem.startsWith(u8, source[index..], const_keyword)) {
            index = edgerun_source.parseConst(source, index) orelse break;
            continue;
        }
        if (std.mem.startsWith(u8, source[index..], var_keyword)) {
            const decl = parseEdgeRunVarDecl(source, index) orelse break;
            index = decl.next_index;
            continue;
        }
        const parsed = edgerun_source.parseFunction(source, index) orelse break;
        index = parsed.next_index;
        if (reservedExportName(parsed.name)) continue;
        if (!integerReturnType(parsed.signature_tail)) continue;
        if (stateful_source_workspace and std.mem.eql(u8, parsed.name, "er_ui_source_workspace_ptr")) {
            const ptr = pointerForArray(&context, "source_workspace") orelse return invalidEdgeRunLowered(context.next_data_offset);
            lowered.append(parsed.name, ptr);
            continue;
        }
        if (stateful_source_workspace and std.mem.eql(u8, parsed.name, "er_ui_source_workspace_len")) {
            lowered.appendStateLoad(parsed.name, source_workspace_len_offset);
            continue;
        }
        if (stateful_source_workspace and std.mem.eql(u8, parsed.name, "er_ui_source_workspace_commit")) {
            const capacity = context.array_lengths.find("source_workspace") orelse return invalidEdgeRunLowered(context.next_data_offset);
            lowered.appendSourceWorkspaceCommit(parsed.name, capacity, source_workspace_len_offset, source_workspace_ready_offset, last_error_offset);
            continue;
        }
        if (compiler_wasm_len > 0 and compiler_wasm_offset > 0 and std.mem.eql(u8, parsed.name, "er_ui_compiler_wasm_ptr")) {
            lowered.append(parsed.name, compiler_wasm_offset);
            continue;
        }
        if (compiler_wasm_len > 0 and compiler_wasm_offset > 0 and std.mem.eql(u8, parsed.name, "er_ui_compiler_wasm_len")) {
            lowered.append(parsed.name, compiler_wasm_len);
            continue;
        }
        if (compiler_wasm_len > 0 and stateful_source_workspace and stateful_release_artifact and std.mem.eql(u8, parsed.name, "er_ui_compile_workspace_wasm")) {
            const source_ptr = pointerForArray(&context, "source_workspace") orelse return invalidEdgeRunLowered(context.next_data_offset);
            const source_capacity = context.array_lengths.find("source_workspace") orelse return invalidEdgeRunLowered(context.next_data_offset);
            const release_ptr = pointerForArray(&context, "release_artifact") orelse return invalidEdgeRunLowered(context.next_data_offset);
            const release_capacity = context.array_lengths.find("release_artifact") orelse return invalidEdgeRunLowered(context.next_data_offset);
            const source_name_offset = lowered.appendDataBytes(root_label) orelse return invalidEdgeRunLowered(context.next_data_offset);
            const compiler_runtime_offset_usize = alignForwardUsize(context.next_data_offset, memory_alignment);
            const compiler_runtime_offset: i32 = @intCast(compiler_runtime_offset_usize);
            context.next_data_offset = compiler_runtime_offset_usize + linked_compiler_runtime_capacity;
            lowered.appendCompileWorkspace(.{
                .name = Label.init(parsed.name),
                .value = compiler_runtime_offset,
                .limit = @intCast(linked_compiler_runtime_capacity),
                .source_ptr = source_ptr,
                .source_len_offset = source_workspace_len_offset,
                .source_capacity = source_capacity,
                .source_name_ptr = @intCast(source_name_offset),
                .source_name_len = @intCast(root_label.len),
                .release_ptr = release_ptr,
                .release_len_offset = release_artifact_len_offset,
                .release_capacity = release_capacity,
                .error_offset = last_error_offset,
                .kind = .compile_workspace,
            });
            continue;
        }
        if (stateful_release_artifact and std.mem.eql(u8, parsed.name, "er_ui_release_artifact_len")) {
            lowered.appendStateLoad(parsed.name, release_artifact_len_offset);
            continue;
        }
        if (stateful_release_artifact and std.mem.eql(u8, parsed.name, "er_ui_last_error")) {
            lowered.appendStateLoad(parsed.name, last_error_offset);
            continue;
        }
        if (stateful_release_artifact and std.mem.eql(u8, parsed.name, "er_ui_release_artifact_commit")) {
            const ptr = pointerForArray(&context, "release_artifact") orelse return invalidEdgeRunLowered(context.next_data_offset);
            const capacity = context.array_lengths.find("release_artifact") orelse return invalidEdgeRunLowered(context.next_data_offset);
            lowered.appendReleaseArtifactCommit(parsed.name, ptr, capacity, release_artifact_len_offset, last_error_offset);
            continue;
        }
        if (parseEdgeRunWasm32Args(parsed.args)) |args| {
            if (parsed.exported) {
                lowered.appendDynamicI32Arg(parsed.name, .{}, args.count);
            } else {
                lowered.appendInternalDynamicI32Arg(parsed.name, .{}, args.count);
            }
            if (!decls.append(.{ .parsed = parsed, .args = args, .dynamic = true })) return invalidEdgeRunLowered(context.next_data_offset);
            continue;
        }
        if (!allWhitespace(parsed.args)) continue;
        if (edgeRunBodyNeedsDynamic(parsed.body)) {
            if (parsed.exported) {
                lowered.appendDynamicI32Arg(parsed.name, .{}, 0);
            } else {
                lowered.appendInternalDynamicI32Arg(parsed.name, .{}, 0);
            }
            if (!decls.append(.{ .parsed = parsed, .args = .{}, .dynamic = true })) return invalidEdgeRunLowered(context.next_data_offset);
            continue;
        }
        if (parsed.exported) {
            lowered.append(parsed.name, 0);
        } else {
            lowered.appendInternal(parsed.name, 0);
        }
        if (!decls.append(.{ .parsed = parsed, .args = .{}, .dynamic = false })) return invalidEdgeRunLowered(context.next_data_offset);
    }
    for (decls.items[0..decls.count]) |decl| {
        const entry_index = lowered.findEntryIndex(decl.parsed.name) orelse return invalidEdgeRunLowered(context.next_data_offset);
        if (decl.dynamic) {
            const compiled = compileEdgeRunDynamicReturnBody(decl.parsed.body, &context, decl.args, &lowered, function_index_base) orelse return invalidEdgeRunLowered(context.next_data_offset);
            lowered.fillDynamic(entry_index, compiled) orelse return invalidEdgeRunLowered(context.next_data_offset);
        } else {
            lowered.entries[entry_index].value = compileEdgeRunReturnBody(decl.parsed.body, &context) orelse return invalidEdgeRunLowered(context.next_data_offset);
        }
    }
    collectEdgeRunUiData(source, &lowered);
    lowered.memory_end = context.next_data_offset;
    lowered.finalizeData();
    return lowered;
}

fn edgeRunBodyNeedsDynamic(body: []const u8) bool {
    return std.mem.indexOf(u8, body, var_keyword) != null or
        std.mem.indexOf(u8, body, "while (") != null or
        std.mem.indexOfScalar(u8, body, '[') != null or
        (std.mem.indexOfScalar(u8, body, '.') != null and std.mem.indexOfScalar(u8, body, '(') != null);
}

const EdgeRunFunctionDecl = struct {
    parsed: edgerun_source.ParsedExport,
    args: EdgeRunArgs,
    dynamic: bool,
};

const EdgeRunFunctionDecls = struct {
    items: [max_lowered_exports]EdgeRunFunctionDecl = undefined,
    count: usize = 0,

    fn append(decls: *EdgeRunFunctionDecls, decl: EdgeRunFunctionDecl) bool {
        if (decls.count >= decls.items.len) return false;
        decls.items[decls.count] = decl;
        decls.count += 1;
        return true;
    }
};

fn invalidEdgeRunLowered(memory_end: usize) LoweredExports {
    return .{ .memory_end = memory_end };
}

fn collectEdgeRunUiData(source: []const u8, lowered: *LoweredExports) void {
    var nodes = UiNodeList{};
    var layout = UiLayout{};
    var index: usize = 0;
    while (true) {
        index = edgerun_source.skipSpace(source, index);
        if (index == source.len) break;
        if (std.mem.startsWith(u8, source[index..], const_keyword)) {
            const decl = edgerun_source.parseConstDecl(source, index) orelse return;
            const type_expr = trimAsciiWhitespace(decl.type_expr);
            if (std.mem.eql(u8, type_expr, "text")) {
                const value = parseEdgeRunStringLiteral(decl.value) orelse return;
                if (!nodes.append(.{ .kind = .text, .value = value })) return;
            } else if (std.mem.eql(u8, type_expr, "button")) {
                const value = parseEdgeRunStringLiteral(decl.value) orelse return;
                if (!nodes.append(.{ .kind = .button, .value = value })) return;
            } else if (std.mem.eql(u8, type_expr, "input")) {
                const value = parseEdgeRunStringLiteral(decl.value) orelse return;
                if (!nodes.append(.{ .kind = .input, .value = value })) return;
            } else if (std.mem.eql(u8, type_expr, "badge")) {
                const value = parseEdgeRunStringLiteral(decl.value) orelse return;
                if (!nodes.append(.{ .kind = .badge, .value = value })) return;
            } else if (std.mem.eql(u8, type_expr, "stack")) {
                layout = parseEdgeRunStackLayout(decl.value) orelse return;
            }
            index = decl.next_index;
            continue;
        }
        if (std.mem.startsWith(u8, source[index..], var_keyword)) {
            const decl = parseEdgeRunVarDecl(source, index) orelse return;
            index = decl.next_index;
            continue;
        }
        if (edgerun_source.parseFunction(source, index)) |parsed| {
            index = parsed.next_index;
            continue;
        }
        return;
    }
    if (nodes.count != 0) {
        var ui_data: [max_lowered_data_bytes]u8 = undefined;
        const ui_len = buildUiBytes(&ui_data, nodes, layout) orelse return;
        const ui_offset = lowered.appendDataBytes(ui_data[0..ui_len]) orelse return;
        lowered.ui_root_data_offset = ui_offset;
        lowered.ui_root_len = ui_len;
    }
}

const UiNodeKind = enum {
    text,
    button,
    input,
    badge,
};

const UiNodeDecl = struct {
    kind: UiNodeKind,
    value: []const u8,
};

const UiNodeList = struct {
    nodes: [max_edgerun_ui_nodes]UiNodeDecl = undefined,
    count: usize = 0,

    fn append(list: *UiNodeList, node: UiNodeDecl) bool {
        if (list.count >= list.nodes.len) return false;
        list.nodes[list.count] = node;
        list.count += 1;
        return true;
    }
};

const UiLayout = struct {
    axis: u16 = 0,
    gap: u16 = 0,
    padding: u16 = 0,
};

fn parseEdgeRunStackLayout(raw: []const u8) ?UiLayout {
    const text = trimAsciiWhitespace(raw);
    if (std.mem.startsWith(u8, text, "column(")) return parseEdgeRunStackLayoutArgs(text, "column(".len, 0);
    if (std.mem.startsWith(u8, text, "row(")) return parseEdgeRunStackLayoutArgs(text, "row(".len, 1);
    return null;
}

fn parseEdgeRunStackLayoutArgs(text: []const u8, args_start: usize, axis: u16) ?UiLayout {
    if (text.len <= args_start or text[text.len - 1] != ')') return null;
    const args = text[args_start .. text.len - 1];
    const comma = std.mem.indexOfScalar(u8, args, ',') orelse return null;
    if (std.mem.indexOfScalar(u8, args[comma + 1 ..], ',') != null) return null;
    const gap = parseU16Expression(args[0..comma]) orelse return null;
    const padding = parseU16Expression(args[comma + 1 ..]) orelse return null;
    return .{ .axis = axis, .gap = gap, .padding = padding };
}

fn parseU16Expression(raw: []const u8) ?u16 {
    const empty = ConstIndex{};
    const value = parseI32Expression(raw, &empty) orelse return null;
    if (value < 0 or value > std.math.maxInt(u16)) return null;
    return @intCast(value);
}

fn parseEdgeRunStringLiteral(raw: []const u8) ?[]const u8 {
    const text = trimAsciiWhitespace(raw);
    if (text.len < 2 or text[0] != '"' or text[text.len - 1] != '"') return null;
    const body = text[1 .. text.len - 1];
    if (std.mem.indexOfScalar(u8, body, '"') != null) return null;
    if (std.mem.indexOfScalar(u8, body, '\\') != null) return null;
    return body;
}

fn buildUiBytes(out: []u8, list: UiNodeList, layout: UiLayout) ?u16 {
    if (list.count == 0 or list.count > std.math.maxInt(u16)) return null;
    var string_bytes: usize = 0;
    for (list.nodes[0..list.count]) |node| string_bytes += node.value.len;
    const records_len = erui_record_size * list.count;
    const len = erui_header_size + records_len + string_bytes;
    if (len > out.len or len > std.math.maxInt(u16)) return null;
    @memset(out[0..len], 0);
    @memcpy(out[0..erui_magic.len], erui_magic);
    store16(out[8..10], 1);
    store16(out[10..12], layout.axis);
    store16(out[12..14], layout.gap);
    store16(out[14..16], layout.padding);
    store16(out[16..18], @intCast(list.count));
    store16(out[18..20], @intCast(list.count));
    var string_cursor: usize = erui_header_size + records_len;
    for (list.nodes[0..list.count], 0..) |node, index| {
        const string_offset = string_cursor - erui_header_size - records_len;
        if (string_offset > std.math.maxInt(u16) or node.value.len > std.math.maxInt(u16)) return null;
        @memcpy(out[string_cursor..][0..node.value.len], node.value);
        const record = out[erui_header_size + index * erui_record_size ..][0..erui_record_size];
        store16(record[0..2], switch (node.kind) {
            .text => erui_record_kind_text,
            .button => erui_record_kind_button,
            .input => erui_record_kind_input,
            .badge => erui_record_kind_badge,
        });
        store32(record[4..8], @intCast(index + 1));
        store16(record[8..10], @intCast(string_offset));
        store16(record[10..12], @intCast(node.value.len));
        string_cursor += node.value.len;
    }
    return @intCast(len);
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
        .state_offsets = .{},
        .zero_values = .{},
        .next_data_offset = data_base,
    };
    collectIntegerConsts(source, &context.constants);
    collectArrayLengths(source, &context);
    collectZeroValues(source, &context.zero_values);
    collectEnumInitialValues(source, &context.zero_values);
    return context;
}

fn collectEdgeRunLoweringContext(source: []const u8, data_base: usize) LoweringContext {
    var context = LoweringContext{
        .constants = .{},
        .array_lengths = .{},
        .pointer_values = .{},
        .state_offsets = .{},
        .zero_values = .{},
        .next_data_offset = data_base,
    };
    var index: usize = 0;
    while (true) {
        index = edgerun_source.skipSpace(source, index);
        if (index == source.len) break;
        if (std.mem.startsWith(u8, source[index..], const_keyword)) {
            const decl = edgerun_source.parseConstDecl(source, index) orelse break;
            if (parseI32Expression(decl.value, &context.constants)) |value| {
                context.constants.append(decl.name, value);
            }
            if (parseEdgeRunArrayLength(decl.type_expr, &context.constants)) |len| {
                context.array_lengths.append(decl.name, len);
                _ = pointerForArray(&context, decl.name) orelse break;
            }
            index = decl.next_index;
            continue;
        }
        if (std.mem.startsWith(u8, source[index..], var_keyword)) {
            const decl = parseEdgeRunVarDecl(source, index) orelse break;
            if (edgeRunIntegerType(decl.type_expr)) {
                const value = parseI32Expression(decl.value, &context.constants) orelse break;
                if (value != 0) break;
                const offset = reserveI32StateSlot(&context);
                context.state_offsets.append(decl.name, offset);
                context.zero_values.append(decl.name, 0);
            }
            index = decl.next_index;
            continue;
        }
        if (edgerun_source.parseFunction(source, index)) |parsed| {
            index = parsed.next_index;
            continue;
        }
        break;
    }
    return context;
}

fn parseEdgeRunArrayLength(type_expr: []const u8, constants: *const ConstIndex) ?i32 {
    if (type_expr.len == 0 or type_expr[0] != '[') return null;
    const bracket_end_relative = std.mem.indexOfScalar(u8, type_expr, ']') orelse return null;
    const len = parseI32Expression(type_expr[1..bracket_end_relative], constants) orelse return null;
    const element_start = skipWhitespace(type_expr, bracket_end_relative + 1);
    if (element_start + "u8".len != type_expr.len) return null;
    if (!std.mem.eql(u8, type_expr[element_start..], "u8")) return null;
    return len;
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
    if (splitTopLevelOperators(text, &.{ '+', '-' })) |split| {
        const left = parseValueExpression(split.left, context) orelse return null;
        const right = parseValueExpression(split.right, context) orelse return null;
        return checkedI32Binary(left, right, split.operator);
    }
    if (splitTopLevelOperators(text, &.{ '*', '/', '%' })) |split| {
        const left = parseValueExpression(split.left, context) orelse return null;
        const right = parseValueExpression(split.right, context) orelse return null;
        return checkedI32Binary(left, right, split.operator);
    }
    if (parseI32Literal(text)) |value| return value;
    if (std.mem.endsWith(u8, text, ".len")) {
        return context.array_lengths.find(text[0 .. text.len - ".len".len]);
    }
    if (context.constants.find(text)) |value| return value;
    return context.zero_values.find(text);
}

fn checkedI32Binary(left: i32, right: i32, operator: u8) ?i32 {
    const result: i64 = switch (operator) {
        '+' => @as(i64, left) + @as(i64, right),
        '-' => @as(i64, left) - @as(i64, right),
        '*' => @as(i64, left) * @as(i64, right),
        '/' => if (right == 0) return null else @divTrunc(@as(i64, left), @as(i64, right)),
        '%' => if (right == 0) return null else @rem(@as(i64, left), @as(i64, right)),
        else => return null,
    };
    if (result < std.math.minInt(i32) or result > std.math.maxInt(i32)) return null;
    return @intCast(result);
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

fn pagesToBytesUsize(page_count: u32) ?usize {
    const byte_count = @as(u64, page_count) * wasm_page_bytes;
    if (byte_count > std.math.maxInt(usize)) return null;
    return @intCast(byte_count);
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

const WorkspaceInfo = struct {
    file_count: u32,
    root_source: []const u8,
    root_label: []const u8,
    manifest: []const u8,
};

const CompilerOutputInfo = struct {
    edgerun_instruction_count: u32,
    edgerun_declaration_count: u32,
    edgerun_export_name_bytes: u32,
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

fn emptyCompilerOutputInfo() CompilerOutputInfo {
    return .{
        .edgerun_instruction_count = 0,
        .edgerun_declaration_count = 0,
        .edgerun_export_name_bytes = 0,
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
}

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

const NameIndex = struct {
    entries: [max_edgerun_top_level_names][]const u8 = undefined,
    count: usize = 0,

    fn appendUnique(index: *NameIndex, name: []const u8) bool {
        for (index.entries[0..index.count]) |entry| {
            if (std.mem.eql(u8, entry, name)) return false;
        }
        if (index.count >= index.entries.len) return false;
        index.entries[index.count] = name;
        index.count += 1;
        return true;
    }
};

const LoweringContext = struct {
    constants: ConstIndex,
    array_lengths: ConstIndex,
    pointer_values: ConstIndex,
    state_offsets: ConstIndex,
    zero_values: ConstIndex,
    next_data_offset: usize,
};

const LoweredFunctionKind = enum {
    return_i32,
    dynamic_i32_arg_i32,
    state_load_i32,
    release_artifact_commit,
    source_workspace_commit,
    compile_workspace,
};

const LoweredExport = struct {
    name: Label,
    value: i32,
    limit: i32 = 0,
    state_offset: i32 = 0,
    ready_offset: i32 = 0,
    error_offset: i32 = 0,
    source_ptr: i32 = 0,
    source_len_offset: i32 = 0,
    source_capacity: i32 = 0,
    source_name_ptr: i32 = 0,
    source_name_len: i32 = 0,
    release_ptr: i32 = 0,
    release_len_offset: i32 = 0,
    release_capacity: i32 = 0,
    expr_code: [max_edgerun_expr_code_bytes]u8 = [_]u8{0} ** max_edgerun_expr_code_bytes,
    expr_code_len: u8 = 0,
    local_count: u8 = 0,
    arg_count: u8 = 0,
    kind: LoweredFunctionKind = .return_i32,
    exported: bool = true,

    fn nameSlice(lowered: *const LoweredExport) []const u8 {
        return lowered.name.slice();
    }

    fn exprCode(lowered: *const LoweredExport) []const u8 {
        return lowered.expr_code[0..lowered.expr_code_len];
    }

    fn compiledExpr(lowered: *const LoweredExport) CompiledExpr {
        var result = CompiledExpr{ .len = lowered.expr_code_len, .local_count = lowered.local_count };
        @memcpy(result.bytes[0..lowered.expr_code_len], lowered.expr_code[0..lowered.expr_code_len]);
        return result;
    }
};

const LoweredExports = struct {
    entries: [max_lowered_exports]LoweredExport = undefined,
    count: u32 = 0,
    declared_count: u32 = 0,
    memory_end: usize = 0,
    data_offset: usize = 0,
    data: [max_lowered_data_bytes]u8 = [_]u8{0} ** max_lowered_data_bytes,
    data_len: u16 = 0,
    ui_root_data_offset: u16 = 0,
    ui_root_len: u16 = 0,

    fn append(exports: *LoweredExports, name: []const u8, value: i32) void {
        exports.appendFunction(name, value, true);
    }

    fn appendDynamicI32Arg(exports: *LoweredExports, name: []const u8, code: CompiledExpr, arg_count: u8) void {
        exports.appendDynamicI32ArgFunction(name, code, arg_count, true);
    }

    fn appendInternal(exports: *LoweredExports, name: []const u8, value: i32) void {
        exports.appendFunction(name, value, false);
    }

    fn appendInternalDynamicI32Arg(exports: *LoweredExports, name: []const u8, code: CompiledExpr, arg_count: u8) void {
        exports.appendDynamicI32ArgFunction(name, code, arg_count, false);
    }

    fn appendFunction(exports: *LoweredExports, name: []const u8, value: i32, exported: bool) void {
        const label = Label.initBounded(name) orelse return;
        exports.appendEntry(.{ .name = label, .value = value, .exported = exported }, exported);
    }

    fn appendDynamicI32ArgFunction(exports: *LoweredExports, name: []const u8, code: CompiledExpr, arg_count: u8, exported: bool) void {
        const label = Label.initBounded(name) orelse return;
        var lowered = LoweredExport{
            .name = label,
            .value = 0,
            .kind = .dynamic_i32_arg_i32,
            .arg_count = arg_count,
            .exported = exported,
        };
        @memcpy(lowered.expr_code[0..code.len], code.bytes[0..code.len]);
        lowered.expr_code_len = code.len;
        lowered.local_count = code.local_count;
        exports.appendEntry(lowered, exported);
    }

    fn appendStateLoad(exports: *LoweredExports, name: []const u8, state_offset: i32) void {
        const label = Label.initBounded(name) orelse return;
        exports.appendEntry(.{ .name = label, .value = state_offset, .kind = .state_load_i32 }, true);
    }

    fn appendReleaseArtifactCommit(exports: *LoweredExports, name: []const u8, ptr: i32, capacity: i32, len_offset: i32, error_offset: i32) void {
        const label = Label.initBounded(name) orelse return;
        exports.appendEntry(.{
            .name = label,
            .value = ptr,
            .limit = capacity,
            .state_offset = len_offset,
            .error_offset = error_offset,
            .kind = .release_artifact_commit,
        }, true);
    }

    fn appendSourceWorkspaceCommit(exports: *LoweredExports, name: []const u8, capacity: i32, len_offset: i32, ready_offset: i32, error_offset: i32) void {
        const label = Label.initBounded(name) orelse return;
        exports.appendEntry(.{
            .name = label,
            .value = 0,
            .limit = capacity,
            .state_offset = len_offset,
            .ready_offset = ready_offset,
            .error_offset = error_offset,
            .kind = .source_workspace_commit,
        }, true);
    }

    fn appendCompileWorkspace(exports: *LoweredExports, lowered: LoweredExport) void {
        exports.appendEntry(lowered, true);
    }

    fn appendGenerated(exports: *LoweredExports, name: []const u8, value: i32) void {
        const label = Label.initBounded(name) orelse return;
        exports.appendEntry(.{ .name = label, .value = value }, false);
    }

    fn appendImported(exports: *LoweredExports, alias: []const u8, entry: LoweredExport) bool {
        const qualified = qualifiedImportName(alias, entry.nameSlice()) orelse return false;
        var lowered = entry;
        lowered.name = qualified;
        lowered.exported = false;
        exports.appendEntry(lowered, false);
        return true;
    }

    fn appendEntry(exports: *LoweredExports, lowered: LoweredExport, declared: bool) void {
        if (exports.count >= exports.entries.len) return;
        if (reservedExportName(lowered.nameSlice())) return;
        for (exports.entries[0..@intCast(exports.count)]) |entry| {
            if (std.mem.eql(u8, entry.nameSlice(), lowered.nameSlice())) return;
        }
        exports.entries[@intCast(exports.count)] = lowered;
        exports.count += 1;
        if (declared) exports.declared_count += 1;
    }

    fn dataSlice(exports: *const LoweredExports) []const u8 {
        return exports.data[0..exports.data_len];
    }

    fn appendDataBytes(exports: *LoweredExports, bytes: []const u8) ?u16 {
        if (bytes.len > std.math.maxInt(u16)) return null;
        const start = exports.data_len;
        if (bytes.len > exports.data.len - start) return null;
        @memcpy(exports.data[start..][0..bytes.len], bytes);
        exports.data_len += @intCast(bytes.len);
        return start;
    }

    fn finalizeData(exports: *LoweredExports) void {
        if (exports.data_len == 0) return;
        exports.data_offset = alignForwardUsize(exports.memory_end, memory_alignment);
        exports.memory_end = alignForwardUsize(exports.data_offset + exports.data_len, memory_alignment);
        for (exports.entries[0..@intCast(exports.count)]) |*entry| {
            if (entry.kind == .compile_workspace and entry.source_name_len != 0) {
                entry.source_name_ptr += @intCast(exports.data_offset);
            }
        }
        if (exports.ui_root_len != 0) {
            exports.appendGenerated("er_ui_root_ptr", @intCast(exports.data_offset + exports.ui_root_data_offset));
            exports.appendGenerated("er_ui_root_len", @intCast(exports.ui_root_len));
        }
    }

    fn fillDynamic(exports: *LoweredExports, index: usize, code: CompiledExpr) ?void {
        if (index >= exports.count) return null;
        if (exports.entries[index].kind != .dynamic_i32_arg_i32) return null;
        @memcpy(exports.entries[index].expr_code[0..code.len], code.bytes[0..code.len]);
        exports.entries[index].expr_code_len = code.len;
        exports.entries[index].local_count = code.local_count;
    }

    fn findEntryIndex(exports: *const LoweredExports, name: []const u8) ?usize {
        for (exports.entries[0..@intCast(exports.count)], 0..) |entry, index| {
            if (std.mem.eql(u8, entry.nameSlice(), name)) return index;
        }
        return null;
    }

    fn exportedCount(exports: *const LoweredExports) u32 {
        var result: u32 = 0;
        for (exports.entries[0..@intCast(exports.count)]) |entry| {
            if (entry.exported) result += 1;
        }
        return result;
    }

    fn findCall(exports: *const LoweredExports, name: []const u8, arg_count: u8, function_index_base: u32) ?u32 {
        for (exports.entries[0..@intCast(exports.count)], 0..) |entry, index| {
            if (!std.mem.eql(u8, entry.nameSlice(), name)) continue;
            return switch (entry.kind) {
                .return_i32, .state_load_i32 => if (arg_count == 0) function_index_base + @as(u32, @intCast(index)) else null,
                .dynamic_i32_arg_i32 => if (arg_count == entry.arg_count) function_index_base + @as(u32, @intCast(index)) else null,
                .release_artifact_commit, .source_workspace_commit, .compile_workspace => null,
            };
        }
        return null;
    }
};

const Label = struct {
    bytes: [vfs_label_max]u8 = [_]u8{0} ** vfs_label_max,
    len: u16 = 0,

    fn initBounded(value: []const u8) ?Label {
        if (value.len > vfs_label_max) return null;
        return init(value);
    }

    fn init(value: []const u8) Label {
        var label: Label = .{ .len = @intCast(value.len) };
        @memcpy(label.bytes[0..value.len], value);
        return label;
    }

    fn slice(label: *const Label) []const u8 {
        return label.bytes[0..label.len];
    }
};

const ImportStack = struct {
    labels: [max_workspace_import_edges]Label = [_]Label{.{}} ** max_workspace_import_edges,
    count: usize = 0,

    fn push(stack: *ImportStack, label: []const u8) bool {
        if (stack.contains(label)) return false;
        if (stack.count >= stack.labels.len) return false;
        stack.labels[stack.count] = Label.init(label);
        stack.count += 1;
        return true;
    }

    fn pop(stack: *ImportStack) void {
        if (stack.count == 0) return;
        stack.count -= 1;
    }

    fn contains(stack: *const ImportStack, label: []const u8) bool {
        for (stack.labels[0..stack.count]) |*entry| {
            if (std.mem.eql(u8, entry.slice(), label)) return true;
        }
        return false;
    }
};

fn appendImportedModuleExports(target: *LoweredExports, alias: []const u8, imported: LoweredExports) ?void {
    for (imported.entries[0..@intCast(imported.count)]) |entry| {
        if (!target.appendImported(alias, entry)) return null;
    }
}

fn qualifiedImportName(alias: []const u8, name: []const u8) ?Label {
    if (alias.len == 0 or name.len == 0) return null;
    if (alias.len + 1 + name.len > vfs_label_max) return null;
    var label = Label{ .len = @intCast(alias.len + 1 + name.len) };
    @memcpy(label.bytes[0..alias.len], alias);
    label.bytes[alias.len] = '.';
    @memcpy(label.bytes[alias.len + 1 ..][0..name.len], name);
    return label;
}

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

fn analyzeEdgeRunWorkspaceGraph(workspace: WorkspaceInfo) error{InvalidSource}!CompilerOutputInfo {
    var result = emptyCompilerOutputInfo();
    if (workspace.manifest.len < workspace_manifest_header_bytes) return error.InvalidSource;
    const file_count = load32(workspace.manifest[12..16]) orelse return error.InvalidSource;
    if (file_count != workspace.file_count) return error.InvalidSource;

    var index: usize = workspace_manifest_header_bytes;
    var remaining = file_count;
    var root_source: ?[]const u8 = null;
    while (remaining > 0) : (remaining -= 1) {
        if (index > workspace.manifest.len or vfs_label_ref_bytes > workspace.manifest.len - index) return error.InvalidSource;
        const label_ref = decodeLabelRef(workspace.manifest[index..][0..vfs_label_ref_bytes]) catch return error.InvalidSource;
        result.manifest_file_refs_scanned += 1;
        index += vfs_label_ref_bytes;

        if (index > workspace.manifest.len or label_ref.object_len > workspace.manifest.len - index) return error.InvalidSource;
        const file_object = workspace.manifest[index..][0..label_ref.object_len];
        index += label_ref.object_len;
        if (!std.mem.eql(u8, label_ref.label, workspace.root_label)) continue;

        const file_view = decodeObject(file_object) catch return error.InvalidSource;
        result.file_object_decodes += 1;
        root_source = file_view.body;
    }
    if (index != workspace.manifest.len) return error.InvalidSource;
    const source = root_source orelse return error.InvalidSource;
    const root_stats = parseEdgeRunRootStats(source) orelse return error.InvalidSource;
    const lowered_exports = collectWorkspaceLoweredExportsForMode(.edgerun, workspace, 0, 0, if (workspaceHasFileLabel(workspace.manifest, embedded_wasm_compiler_label)) 1 else 0, successor_base_function_count);
    const imports = scanEdgeRunImports(source) orelse return error.InvalidSource;
    const lowered_main_count: u32 = if (lowerMainForMode(.edgerun, source, 0, &lowered_exports, successor_base_function_count).found) 1 else 0;
    if (lowered_main_count + lowered_exports.declared_count != root_stats.export_count) return error.InvalidSource;

    result.edgerun_instruction_count = lowered_main_count + lowered_exports.count;
    result.edgerun_declaration_count = root_stats.declaration_count;
    result.edgerun_export_name_bytes = root_stats.export_name_bytes;
    result.analyzed_file_count = 1;
    result.file_lookup_count = 1;
    result.parsed_source_bytes = @intCast(source.len);
    result.indexed_file_count = file_count;
    result.import_edge_count = imports.edge_count;
    result.truncated_import_count = imports.truncated_count;
    result.lowered_main_count = lowered_main_count;
    result.lowered_export_count = lowered_exports.exportedCount();
    var stack = ImportStack{};
    try analyzeEdgeRunImportsRecursive(workspace, workspace.root_label, source, &result, &stack, 0);
    if (result.unresolved_import_count != 0 or result.truncated_import_count != 0) return error.InvalidSource;
    return result;
}

fn analyzeWorkspaceGraph(scratch: []u8, workspace: WorkspaceInfo, source_mode: SourceMode) error{ InvalidSource, OutOfMemory }!CompilerOutputInfo {
    _ = scratch;
    return switch (source_mode) {
        .edgerun => analyzeEdgeRunWorkspaceGraph(workspace),
    };
}

const EdgeRunRootAnalysis = struct {
    instruction_count: u32,
    extra_count: u32,
    string_bytes: u32,
};

const EdgeRunImportScan = struct {
    edge_count: u32 = 0,
    truncated_count: u32 = 0,
    labels: [max_workspace_import_edges]Label = [_]Label{.{}} ** max_workspace_import_edges,
    aliases: [max_workspace_import_edges]Label = [_]Label{.{}} ** max_workspace_import_edges,
    label_count: usize = 0,
};

fn analyzeEdgeRunImportsRecursive(workspace: WorkspaceInfo, label: []const u8, source: []const u8, result: *CompilerOutputInfo, stack: *ImportStack, depth: usize) error{InvalidSource}!void {
    if (depth >= max_workspace_import_edges) {
        result.truncated_import_count += 1;
        return;
    }
    if (!stack.push(label)) return error.InvalidSource;
    defer stack.pop();
    const imports = scanEdgeRunImports(source) orelse return error.InvalidSource;
    if (depth != 0) {
        result.import_edge_count += imports.edge_count;
        result.truncated_import_count += imports.truncated_count;
    }
    for (imports.labels[0..imports.label_count]) |*import_label| {
        result.file_lookup_count += 1;
        const imported_source = findWorkspaceFile(workspace.manifest, import_label.slice()) orelse {
            result.unresolved_import_count += 1;
            continue;
        };
        const imported_stats = parseEdgeRunRootStats(imported_source) orelse return error.InvalidSource;
        result.queued_import_count += 1;
        result.analyzed_file_count += 1;
        result.file_object_decodes += 1;
        result.parsed_source_bytes += @intCast(imported_source.len);
        result.edgerun_declaration_count += imported_stats.declaration_count;
        result.edgerun_export_name_bytes += imported_stats.export_name_bytes;
        try analyzeEdgeRunImportsRecursive(workspace, import_label.slice(), imported_source, result, stack, depth + 1);
    }
}

fn analyzeEdgeRunRoot(source: []const u8) ?EdgeRunRootAnalysis {
    const parsed = parseEdgeRunRootStats(source) orelse return null;

    const lowered_exports = collectEdgeRunLoweredExports(source, 0, 0, 0, successor_base_function_count);
    const lowered_main_count: u32 = if (lowerEdgeRunMain(source, 0, &lowered_exports, successor_base_function_count).found) 1 else 0;
    if (lowered_main_count + lowered_exports.declared_count != parsed.export_count) return null;

    return .{
        .instruction_count = lowered_main_count + lowered_exports.count,
        .extra_count = parsed.declaration_count,
        .string_bytes = parsed.export_name_bytes,
    };
}

fn parseEdgeRunRootStats(source: []const u8) ?edgerun_source.Stats {
    _ = scanEdgeRunImports(source) orelse return null;
    const parsed = edgerun_source.parse(source) orelse return null;
    if (!edgeRunTopLevelNamesUnique(source)) return null;
    return parsed;
}

fn scanEdgeRunImports(source: []const u8) ?EdgeRunImportScan {
    var scan = EdgeRunImportScan{};
    var import_occurrences: u32 = 0;
    var search_index: usize = 0;
    while (std.mem.indexOf(u8, source[search_index..], "@import(")) |relative| {
        import_occurrences += 1;
        search_index += relative + "@import(".len;
    }

    var index: usize = 0;
    while (true) {
        index = edgerun_source.skipSpace(source, index);
        if (index == source.len) break;
        if (std.mem.startsWith(u8, source[index..], const_keyword)) {
            const decl = edgerun_source.parseConstDecl(source, index) orelse return null;
            if (parseEdgeRunImportLabel(decl)) |label| {
                scan.edge_count += 1;
                if (scan.label_count < scan.labels.len) {
                    scan.labels[scan.label_count] = Label.init(label);
                    scan.aliases[scan.label_count] = Label.init(decl.name);
                    scan.label_count += 1;
                } else {
                    scan.truncated_count += 1;
                }
            }
            index = decl.next_index;
            continue;
        }
        if (std.mem.startsWith(u8, source[index..], var_keyword)) {
            index = edgerun_source.parseVar(source, index) orelse return null;
            continue;
        }
        if (edgerun_source.parseFunction(source, index)) |parsed| {
            index = parsed.next_index;
            continue;
        }
        return null;
    }
    if (scan.edge_count != import_occurrences) return null;
    return scan;
}

fn parseEdgeRunImportLabel(decl: edgerun_source.ParsedConst) ?[]const u8 {
    if (!std.mem.eql(u8, trimAsciiWhitespace(decl.type_expr), "module")) return null;
    const raw = unwrapCallArgument(trimAsciiWhitespace(decl.value), "@import(") orelse return null;
    const label = parseImportString(raw) orelse return null;
    if (!std.mem.endsWith(u8, label, ".er")) return null;
    if (!labelValid(label)) return null;
    return label;
}

fn parseImportString(raw: []const u8) ?[]const u8 {
    const text = trimAsciiWhitespace(raw);
    if (text.len < 2 or text[0] != '"' or text[text.len - 1] != '"') return null;
    const label = text[1 .. text.len - 1];
    if (label.len == 0) return null;
    if (std.mem.indexOfScalar(u8, label, '"') != null) return null;
    if (std.mem.indexOfScalar(u8, label, '\\') != null) return null;
    return label;
}

fn edgeRunTopLevelNamesUnique(source: []const u8) bool {
    var names = NameIndex{};
    var index: usize = 0;
    while (true) {
        index = edgerun_source.skipSpace(source, index);
        if (index == source.len) return true;
        if (std.mem.startsWith(u8, source[index..], const_keyword)) {
            const decl = edgerun_source.parseConstDecl(source, index) orelse return false;
            if (!names.appendUnique(decl.name)) return false;
            index = decl.next_index;
            continue;
        }
        if (std.mem.startsWith(u8, source[index..], var_keyword)) {
            const decl = parseEdgeRunVarDecl(source, index) orelse return false;
            if (!names.appendUnique(decl.name)) return false;
            index = decl.next_index;
            continue;
        }
        if (edgerun_source.parseFunction(source, index)) |parsed| {
            if (!names.appendUnique(parsed.name)) return false;
            index = parsed.next_index;
            continue;
        }
        return false;
    }
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

fn workspaceHasFileLabel(manifest: []const u8, label: []const u8) bool {
    if (manifest.len < workspace_manifest_header_bytes) return false;
    const file_count = load32(manifest[12..16]) orelse return false;
    var index: usize = workspace_manifest_header_bytes;
    var remaining = file_count;
    while (remaining > 0) : (remaining -= 1) {
        if (index > manifest.len or vfs_label_ref_bytes > manifest.len - index) return false;
        const label_ref = decodeLabelRef(manifest[index..][0..vfs_label_ref_bytes]) catch return false;
        index += vfs_label_ref_bytes;
        if (index > manifest.len or label_ref.object_len > manifest.len - index) return false;
        index += label_ref.object_len;
        if (std.mem.eql(u8, label_ref.label, label)) return true;
    }
    if (index != manifest.len) return false;
    return false;
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

    const root_source =
        \\const max_width: usize = 4096;
        \\pub export fn er_app_main() i32 { return 7; }
        \\export fn er_width() u32 { return max_width; }
    ;
    var workspace_raw: [2048]u8 = undefined;
    const workspace_object = try buildTestWorkspace(&workspace_raw, default_root_label, root_source);
    try std.testing.expectEqual(
        @intFromEnum(Status.ok),
        er_wasm_compiler_compile_wasm(@intFromPtr(&memory), memory.len, 0, 0, @intFromPtr(workspace_object.ptr), workspace_object.len),
    );
    const output = (@as([*]const u8, @ptrFromInt(er_wasm_compiler_output_ptr())))[0..er_wasm_compiler_output_len()];
    try std.testing.expect(output.len > workspace_object.len);
    try std.testing.expectEqualSlices(u8, &.{ 0x00, 0x61, 0x73, 0x6d }, output[0..4]);
    try std.testing.expect(std.mem.indexOf(u8, output, workspace_object) != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "er_app_edgerun_instruction_count") != null);
    try std.testing.expect(std.mem.indexOf(u8, output, "er_app_embedded_source_len") != null);
    const full_output_len = output.len;

    try std.testing.expectEqual(
        @intFromEnum(Status.ok),
        er_wasm_compiler_compile_wasm_metadata(@intFromPtr(&memory), memory.len, 0, 0, @intFromPtr(workspace_object.ptr), workspace_object.len),
    );
    const metadata_output = (@as([*]const u8, @ptrFromInt(er_wasm_compiler_output_ptr())))[0..er_wasm_compiler_output_len()];
    try std.testing.expect(metadata_output.len < full_output_len);
    try std.testing.expectEqualSlices(u8, &.{ 0x00, 0x61, 0x73, 0x6d }, metadata_output[0..4]);
    try std.testing.expect(std.mem.indexOf(u8, metadata_output, workspace_object) == null);
    try std.testing.expect(std.mem.indexOf(u8, metadata_output, "er_app_embedded_source_len") != null);

    try std.testing.expectEqual(
        @intFromEnum(Status.missing_root_source),
        er_wasm_compiler_compile_wasm(@intFromPtr(&memory), memory.len, @intFromPtr("missing.er".ptr), "missing.er".len, @intFromPtr(workspace_object.ptr), workspace_object.len),
    );

    var bad_workspace_raw: [1024]u8 = undefined;
    const bad_workspace = try buildTestWorkspace(&bad_workspace_raw, default_root_label, "const max_width = 4096;");
    try std.testing.expectEqual(
        @intFromEnum(Status.invalid_source),
        er_wasm_compiler_compile_wasm(@intFromPtr(&memory), memory.len, 0, 0, @intFromPtr(bad_workspace.ptr), bad_workspace.len),
    );
}

test "compiler ABI rejects implicit Zig source labels" {
    state = .{};
    var memory: [65536]u8 align(memory_alignment) = undefined;
    try std.testing.expectEqual(@intFromEnum(Status.ok), er_wasm_compiler_init(@intFromPtr(&memory), memory.len));

    const root_label = "src/legacy.zig";
    const root_source = "pub export fn main() void {}";
    var workspace_raw: [1024]u8 = undefined;
    const workspace_object = try buildTestWorkspace(&workspace_raw, root_label, root_source);
    try std.testing.expectEqual(
        @intFromEnum(Status.unsupported),
        er_wasm_compiler_compile_wasm(@intFromPtr(&memory), memory.len, @intFromPtr(root_label.ptr), root_label.len, @intFromPtr(workspace_object.ptr), workspace_object.len),
    );
    try std.testing.expect(er_wasm_compiler_diagnostic_len() > 0);
    try std.testing.expectEqual(@as(usize, 0), er_wasm_compiler_output_len());
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

test "edgerun source roots compile without Zig imports" {
    state = .{};
    var memory: [65536]u8 align(memory_alignment) = undefined;
    try std.testing.expectEqual(@intFromEnum(Status.ok), er_wasm_compiler_init(@intFromPtr(&memory), memory.len));

    const root_label = "src/main.er";
    const root_source =
        \\const max_width: usize = 4096;
        \\pub export fn er_app_main() i32 { return 7; }
        \\export fn er_ui_max_width() u32 { return max_width; }
    ;
    var workspace_raw: [2048]u8 = undefined;
    const workspace_object = try buildTestWorkspace(&workspace_raw, root_label, root_source);

    try std.testing.expectEqual(
        @intFromEnum(Status.ok),
        er_wasm_compiler_compile_wasm(@intFromPtr(&memory), memory.len, @intFromPtr(root_label.ptr), root_label.len, @intFromPtr(workspace_object.ptr), workspace_object.len),
    );
    const output = (@as([*]const u8, @ptrFromInt(er_wasm_compiler_output_ptr())))[0..er_wasm_compiler_output_len()];
    try std.testing.expect(output.len > workspace_object.len);
    try std.testing.expectEqualSlices(u8, &.{ 0x00, 0x61, 0x73, 0x6d }, output[0..4]);
    try std.testing.expect(std.mem.indexOf(u8, output, "er_ui_max_width") != null);

    const analysis = analyzeEdgeRunRoot(root_source).?;
    try std.testing.expectEqual(@as(u32, 2), analysis.instruction_count);
    try std.testing.expectEqual(@as(u32, 3), analysis.extra_count);
    try std.testing.expect(analysis.string_bytes > 0);
}

test "edgerun source roots reject Zig toolchain imports instead of falling back" {
    state = .{};
    var memory: [65536]u8 align(memory_alignment) = undefined;
    try std.testing.expectEqual(@intFromEnum(Status.ok), er_wasm_compiler_init(@intFromPtr(&memory), memory.len));

    const root_label = "src/main.er";
    const root_source =
        \\const std = @import("std");
        \\pub export fn er_app_main() i32 { return 7; }
    ;
    var workspace_raw: [2048]u8 = undefined;
    const workspace_object = try buildTestWorkspace(&workspace_raw, root_label, root_source);

    try std.testing.expectEqual(
        @intFromEnum(Status.invalid_source),
        er_wasm_compiler_compile_wasm(@intFromPtr(&memory), memory.len, @intFromPtr(root_label.ptr), root_label.len, @intFromPtr(workspace_object.ptr), workspace_object.len),
    );
    try std.testing.expect(er_wasm_compiler_diagnostic_len() > 0);
    try std.testing.expectEqual(@as(usize, 0), er_wasm_compiler_output_len());
    try std.testing.expect(analyzeEdgeRunRoot(root_source) == null);
}

test "edgerun workspace analysis does not use Zig AST scratch or imports" {
    const root_label = "src/main.er";
    const root_source =
        \\const max_width: usize = 4096;
        \\pub export fn er_app_main() i32 { return 7; }
        \\export fn er_width() u32 { return max_width; }
    ;
    var workspace_raw: [2048]u8 = undefined;
    const workspace_object = try buildTestWorkspace(&workspace_raw, root_label, root_source);
    const workspace = try workspaceFromSourceObject(workspace_object, root_label);
    const analysis = try analyzeWorkspaceGraph(&.{}, workspace, .edgerun);

    try std.testing.expectEqual(@as(u32, 1), analysis.analyzed_file_count);
    try std.testing.expectEqual(@as(u32, 0), analysis.compiler_memory_used);
    try std.testing.expectEqual(@as(u32, 0), analysis.import_edge_count);
    try std.testing.expectEqual(@as(u32, 0), analysis.queued_import_count);
    try std.testing.expectEqual(@as(u32, 1), analysis.lowered_main_count);
    try std.testing.expectEqual(@as(u32, 1), analysis.lowered_export_count);
}

test "edgerun workspace analysis resolves typed source imports" {
    const root_label = "src/main.er";
    const helper_label = "src/helper.er";
    const math_label = "src/math.er";
    const math_source =
        \\export fn er_math_marker() i32 { return 40; }
    ;
    const helper_source =
        \\const math: module = @import("src/math.er");
        \\export fn er_helper_marker() i32 { return math.er_math_marker() + 1; }
    ;
    const root_source =
        \\const helper: module = @import("src/helper.er");
        \\pub export fn er_app_main() i32 { return 7; }
        \\export fn er_width() u32 { return 9; }
        \\export fn er_imported_marker() i32 { return helper.er_helper_marker() + 1; }
    ;
    var workspace_raw: [8192]u8 = undefined;
    const workspace_object = try buildTestWorkspaceWithTwoExtras(&workspace_raw, root_label, root_source, helper_label, helper_source, math_label, math_source);
    const workspace = try workspaceFromSourceObject(workspace_object, root_label);
    const analysis = try analyzeWorkspaceGraph(&.{}, workspace, .edgerun);

    try std.testing.expectEqual(@as(u32, 3), analysis.indexed_file_count);
    try std.testing.expectEqual(@as(u32, 3), analysis.analyzed_file_count);
    try std.testing.expectEqual(@as(u32, 2), analysis.import_edge_count);
    try std.testing.expectEqual(@as(u32, 2), analysis.queued_import_count);
    try std.testing.expectEqual(@as(u32, 0), analysis.unresolved_import_count);
    try std.testing.expectEqual(@as(u32, 0), analysis.truncated_import_count);
    try std.testing.expectEqual(@as(u32, 3), analysis.file_lookup_count);
    try std.testing.expectEqual(@as(u32, 2), analysis.lowered_export_count);
    try std.testing.expectEqual(@as(u32, 1), analysis.lowered_main_count);
    try std.testing.expect(analysis.edgerun_declaration_count >= 7);
}

test "compiler rejects unresolved typed source imports" {
    state = .{};
    var memory: [65536]u8 align(memory_alignment) = undefined;
    try std.testing.expectEqual(@intFromEnum(Status.ok), er_wasm_compiler_init(@intFromPtr(&memory), memory.len));

    const root_label = "src/main.er";
    const helper_label = "src/other.er";
    const root_source =
        \\const helper: module = @import("src/missing.er");
        \\pub export fn er_app_main() i32 { return 7; }
    ;
    var workspace_raw: [4096]u8 = undefined;
    const workspace_object = try buildTestWorkspaceWithExtra(&workspace_raw, root_label, root_source, helper_label, "export fn er_other() i32 { return 1; }");
    const workspace = try workspaceFromSourceObject(workspace_object, root_label);

    try std.testing.expectError(error.InvalidSource, analyzeWorkspaceGraph(&.{}, workspace, .edgerun));
    try std.testing.expectEqual(
        @intFromEnum(Status.invalid_source),
        er_wasm_compiler_compile_wasm(@intFromPtr(&memory), memory.len, @intFromPtr(root_label.ptr), root_label.len, @intFromPtr(workspace_object.ptr), workspace_object.len),
    );
    try std.testing.expect(er_wasm_compiler_diagnostic_len() > 0);
    try std.testing.expectEqual(@as(usize, 0), er_wasm_compiler_output_len());
}

test "edgerun workspace analysis rejects cyclic typed source imports" {
    const root_label = "src/main.er";
    const helper_label = "src/helper.er";
    const root_source =
        \\const helper: module = @import("src/helper.er");
        \\pub export fn er_app_main() i32 { return helper.er_helper_marker(); }
    ;
    const helper_source =
        \\const main: module = @import("src/main.er");
        \\export fn er_helper_marker() i32 { return main.er_app_main(); }
    ;
    var workspace_raw: [4096]u8 = undefined;
    const workspace_object = try buildTestWorkspaceWithExtra(&workspace_raw, root_label, root_source, helper_label, helper_source);
    const workspace = try workspaceFromSourceObject(workspace_object, root_label);

    try std.testing.expectError(error.InvalidSource, analyzeWorkspaceGraph(&.{}, workspace, .edgerun));
}

test "edgerun workspace analysis does not decode embedded compiler payload" {
    const root_label = "src/main.er";
    const root_source =
        \\pub export fn er_app_main() i32 { return 7; }
        \\export fn er_compile_hook() u32 { return 9; }
    ;
    const embedded_payload = "not wasm, and not EdgeRun source";
    var workspace_raw: [4096]u8 = undefined;
    const workspace_object = try buildTestWorkspaceWithExtra(&workspace_raw, root_label, root_source, embedded_wasm_compiler_label, embedded_payload);
    const workspace = try workspaceFromSourceObject(workspace_object, root_label);
    const analysis = try analyzeWorkspaceGraph(&.{}, workspace, .edgerun);

    try std.testing.expectEqual(@as(u32, 2), analysis.manifest_file_refs_scanned);
    try std.testing.expectEqual(@as(u32, 1), analysis.file_object_decodes);
    try std.testing.expectEqual(@as(u32, 2), analysis.indexed_file_count);
    try std.testing.expectEqual(@as(u32, 1), analysis.lowered_main_count);
    try std.testing.expectEqual(@as(u32, 1), analysis.lowered_export_count);
}

test "edgerun source parser rejects unsupported top level declarations" {
    try std.testing.expect(analyzeEdgeRunRoot(
        \\var counter = 0;
        \\pub export fn er_app_main() i32 { return 7; }
    ) == null);
    try std.testing.expect(analyzeEdgeRunRoot(
        \\const max_width = 4096;
        \\pub export fn er_app_main() i32 { return 7; }
    ) == null);
    try std.testing.expect(analyzeEdgeRunRoot(
        \\pub fn helper() i32 { return 7; }
        \\pub export fn er_app_main() i32 { return 7; }
    ) == null);
    try std.testing.expect(analyzeEdgeRunRoot(
        \\// comments are fine at top level
        \\const max_width: usize = 4096;
        \\export fn er_ui_max_width() u32 { return max_width; }
    ) != null);
}

test "edgerun source rejects duplicate top level names" {
    try std.testing.expect(analyzeEdgeRunRoot(
        \\const max_width: usize = 4096;
        \\const max_width: usize = 8192;
        \\export fn er_ui_max_width() u32 { return max_width; }
    ) == null);
    try std.testing.expect(analyzeEdgeRunRoot(
        \\const max_width: usize = 4096;
        \\export fn er_ui_max_width() u32 { return max_width; }
        \\export fn er_ui_max_width() u32 { return 7; }
    ) == null);
    try std.testing.expect(analyzeEdgeRunRoot(
        \\const er_ui_max_width: usize = 4096;
        \\export fn er_ui_max_width() u32 { return er_ui_max_width; }
    ) == null);
}

test "edgerun source lowering only collects parsed top level exports" {
    const source =
        \\const max_width: usize = 4096;
        \\export fn er_ui_outer() u32 {
        \\    export fn er_ui_nested() u32 { return max_width; }
        \\    return max_width;
        \\}
    ;
    try std.testing.expect(analyzeEdgeRunRoot(source) == null);

    const lowered = collectLoweredExportsForMode(.edgerun,
        \\const max_width: usize = 4096;
        \\export fn er_ui_max_width() u32 { return max_width; }
    , 0, 0, 0, successor_base_function_count);
    try std.testing.expectEqual(@as(u32, 1), lowered.count);
    try std.testing.expectEqualStrings("er_ui_max_width", lowered.entries[0].nameSlice());
    try std.testing.expectEqual(@as(i32, 4096), lowered.entries[0].value);
}

test "edgerun source rejects leaked function locals between exports" {
    const lowered = collectLoweredExportsForMode(.edgerun,
        \\const max_width: usize = 4096;
        \\export fn er_ui_define_hidden() u32 {
        \\    const hidden_width: usize = 8192;
        \\    return hidden_width;
        \\}
        \\export fn er_ui_use_hidden() u32 { return hidden_width; }
    , 0, 0, 0, successor_base_function_count);
    try std.testing.expectEqual(@as(u32, 0), lowered.count);
}

test "edgerun source lowering collects top level const array lengths" {
    const lowered = collectLoweredExportsForMode(.edgerun,
        \\const max_width: usize = 4096;
        \\const source_workspace: [max_width]u8 = undefined;
        \\export fn er_ui_source_workspace_ptr() u32 { return @intFromPtr(&source_workspace); }
        \\export fn er_ui_source_workspace_capacity() u32 { return source_workspace.len; }
    , 256, 0, 0, successor_base_function_count);
    try std.testing.expectEqual(@as(u32, 2), lowered.count);
    try std.testing.expectEqualStrings("er_ui_source_workspace_ptr", lowered.entries[0].nameSlice());
    try std.testing.expectEqual(@as(i32, 256), lowered.entries[0].value);
    try std.testing.expectEqualStrings("er_ui_source_workspace_capacity", lowered.entries[1].nameSlice());
    try std.testing.expectEqual(@as(i32, 4096), lowered.entries[1].value);
}

test "edgerun source compiles local const return bodies" {
    const lowered = collectLoweredExportsForMode(.edgerun,
        \\const base_width: usize = 2048;
        \\export fn er_ui_local_width() u32 {
        \\    const doubled: usize = base_width * 2;
        \\    const padded: usize = doubled + 17;
        \\    return padded;
        \\}
    , 0, 0, 0, successor_base_function_count);
    try std.testing.expectEqual(@as(u32, 1), lowered.count);
    try std.testing.expectEqualStrings("er_ui_local_width", lowered.entries[0].nameSlice());
    try std.testing.expectEqual(@as(i32, 4113), lowered.entries[0].value);
}

test "edgerun source compiles static array length arithmetic returns" {
    const lowered = collectLoweredExportsForMode(.edgerun,
        \\const source_workspace: [16]u8 = undefined;
        \\const release_artifact: [32]u8 = undefined;
        \\export fn er_total_capacity() usize {
        \\    const doubled: usize = source_workspace.len * 2;
        \\    return doubled + release_artifact.len - 4;
        \\}
    , 128, 0, 0, successor_base_function_count);
    try std.testing.expectEqual(@as(u32, 1), lowered.count);
    try std.testing.expectEqualStrings("er_total_capacity", lowered.entries[0].nameSlice());
    try std.testing.expectEqual(@as(i32, 60), lowered.entries[0].value);
}

test "edgerun source compiles dynamic i32 argument expressions" {
    const lowered = collectLoweredExportsForMode(.edgerun,
        \\const bias: usize = 5;
        \\export fn er_scale(value: i32) i32 {
        \\    const tripled: i32 = value * 3;
        \\    const shifted: i32 = tripled + bias;
        \\    return shifted;
        \\}
    , 0, 0, 0, successor_base_function_count);
    try std.testing.expectEqual(@as(u32, 1), lowered.count);
    try std.testing.expectEqualStrings("er_scale", lowered.entries[0].nameSlice());
    try std.testing.expectEqual(LoweredFunctionKind.dynamic_i32_arg_i32, lowered.entries[0].kind);
    try std.testing.expect(lowered.entries[0].expr_code_len > 0);
}

test "edgerun source compiles dynamic if else expressions" {
    const lowered = collectLoweredExportsForMode(.edgerun,
        \\export fn er_non_negative(value: i32) i32 {
        \\    return if (value < 0) 0 else value;
        \\}
    , 0, 0, 0, successor_base_function_count);
    try std.testing.expectEqual(@as(u32, 1), lowered.count);
    try std.testing.expectEqualStrings("er_non_negative", lowered.entries[0].nameSlice());
    try std.testing.expectEqual(LoweredFunctionKind.dynamic_i32_arg_i32, lowered.entries[0].kind);
    try std.testing.expect(lowered.entries[0].expr_code_len > 0);
}

test "edgerun source compiles block if else returns" {
    const lowered = collectLoweredExportsForMode(.edgerun,
        \\export fn er_max(left: i32, right: i32) i32 {
        \\    if (left < right) {
        \\        return right;
        \\    } else {
        \\        return left;
        \\    }
        \\}
    , 0, 0, 0, successor_base_function_count);
    try std.testing.expectEqual(@as(u32, 1), lowered.count);
    try std.testing.expectEqualStrings("er_max", lowered.entries[0].nameSlice());
    try std.testing.expectEqual(@as(u8, 2), lowered.entries[0].arg_count);
    try std.testing.expectEqual(LoweredFunctionKind.dynamic_i32_arg_i32, lowered.entries[0].kind);
    try std.testing.expect(std.mem.indexOfScalar(u8, lowered.entries[0].exprCode(), wasm_opcode_if) != null);
}

test "edgerun source compiles subtraction and comparison operators" {
    const lowered = collectLoweredExportsForMode(.edgerun,
        \\export fn er_delta(left: i32, right: i32) i32 {
        \\    return left - right;
        \\}
        \\export fn er_ge(left: i32, right: i32) i32 {
        \\    if (left >= right) {
        \\        return 1;
        \\    } else {
        \\        return 0;
        \\    }
        \\}
        \\export fn er_ne(left: i32, right: i32) i32 {
        \\    if (left != right) {
        \\        return left - right;
        \\    } else {
        \\        return 0;
        \\    }
        \\}
    , 0, 0, 0, successor_base_function_count);
    try std.testing.expectEqual(@as(u32, 3), lowered.count);
    try std.testing.expect(std.mem.indexOfScalar(u8, lowered.entries[0].exprCode(), wasm_opcode_i32_sub) != null);
    try std.testing.expect(std.mem.indexOfScalar(u8, lowered.entries[1].exprCode(), wasm_opcode_i32_ge_s) != null);
    try std.testing.expect(std.mem.indexOfScalar(u8, lowered.entries[2].exprCode(), wasm_opcode_i32_ne) != null);
}

test "edgerun source compiles division remainder and mixed precedence" {
    const lowered = collectLoweredExportsForMode(.edgerun,
        \\export fn er_chunk_score(total: i32, chunk: i32) i32 {
        \\    return total / chunk + total % chunk + total - chunk - 1;
        \\}
    , 0, 0, 0, successor_base_function_count);
    try std.testing.expectEqual(@as(u32, 1), lowered.count);
    try std.testing.expectEqualStrings("er_chunk_score", lowered.entries[0].nameSlice());
    try std.testing.expectEqual(LoweredFunctionKind.dynamic_i32_arg_i32, lowered.entries[0].kind);
    try std.testing.expectEqual(@as(u8, 2), lowered.entries[0].arg_count);
    try std.testing.expect(std.mem.indexOfScalar(u8, lowered.entries[0].exprCode(), wasm_opcode_i32_div_s) != null);
    try std.testing.expect(std.mem.indexOfScalar(u8, lowered.entries[0].exprCode(), wasm_opcode_i32_rem_s) != null);
}

test "edgerun source compiles mutable i32 locals" {
    const lowered = collectLoweredExportsForMode(.edgerun,
        \\export fn er_accumulate(start: i32, step: i32) i32 {
        \\    var total: i32 = start;
        \\    total = total + step;
        \\    total = total + step;
        \\    return total;
        \\}
    , 0, 0, 0, successor_base_function_count);
    try std.testing.expectEqual(@as(u32, 1), lowered.count);
    try std.testing.expectEqualStrings("er_accumulate", lowered.entries[0].nameSlice());
    try std.testing.expectEqual(LoweredFunctionKind.dynamic_i32_arg_i32, lowered.entries[0].kind);
    try std.testing.expectEqual(@as(u8, 2), lowered.entries[0].arg_count);
    try std.testing.expectEqual(@as(u8, 1), lowered.entries[0].local_count);
    try std.testing.expect(std.mem.indexOfScalar(u8, lowered.entries[0].exprCode(), wasm_opcode_local_set) != null);
    try std.testing.expect(std.mem.indexOfScalar(u8, lowered.entries[0].exprCode(), wasm_opcode_local_get) != null);
}

test "edgerun source compiles while loops over mutable i32 locals" {
    const lowered = collectLoweredExportsForMode(.edgerun,
        \\export fn er_sum_to(limit: i32) i32 {
        \\    var total: i32 = 0;
        \\    var index: i32 = 0;
        \\    while (index < limit) {
        \\        total = total + index;
        \\        index = index + 1;
        \\    }
        \\    return total;
        \\}
    , 0, 0, 0, successor_base_function_count);
    try std.testing.expectEqual(@as(u32, 1), lowered.count);
    try std.testing.expectEqualStrings("er_sum_to", lowered.entries[0].nameSlice());
    try std.testing.expectEqual(LoweredFunctionKind.dynamic_i32_arg_i32, lowered.entries[0].kind);
    try std.testing.expectEqual(@as(u8, 1), lowered.entries[0].arg_count);
    try std.testing.expectEqual(@as(u8, 2), lowered.entries[0].local_count);
    try std.testing.expect(std.mem.indexOfScalar(u8, lowered.entries[0].exprCode(), wasm_opcode_loop) != null);
    try std.testing.expect(std.mem.indexOfScalar(u8, lowered.entries[0].exprCode(), wasm_opcode_br_if) != null);
}

test "edgerun source compiles byte array stores and loads" {
    const lowered = collectLoweredExportsForMode(.edgerun,
        \\const scratch: [16]u8 = undefined;
        \\export fn er_fill_byte(seed: i32) i32 {
        \\    var index: i32 = 0;
        \\    while (index < 4) {
        \\        scratch[index] = seed + index;
        \\        index = index + 1;
        \\    }
        \\    return scratch[3];
        \\}
    , 128, 0, 0, successor_base_function_count);
    try std.testing.expectEqual(@as(u32, 1), lowered.count);
    try std.testing.expectEqualStrings("er_fill_byte", lowered.entries[0].nameSlice());
    try std.testing.expectEqual(LoweredFunctionKind.dynamic_i32_arg_i32, lowered.entries[0].kind);
    try std.testing.expectEqual(@as(u8, 1), lowered.entries[0].arg_count);
    try std.testing.expectEqual(@as(u8, 1), lowered.entries[0].local_count);
    try std.testing.expect(lowered.memory_end > 128);
    try std.testing.expect(std.mem.indexOfScalar(u8, lowered.entries[0].exprCode(), wasm_opcode_i32_store8) != null);
    try std.testing.expect(std.mem.indexOfScalar(u8, lowered.entries[0].exprCode(), wasm_opcode_i32_load8_u) != null);
}

test "edgerun source compiles dynamic no argument bodies" {
    const lowered = collectLoweredExportsForMode(.edgerun,
        \\const scratch: [16]u8 = undefined;
        \\export fn er_init_scratch() i32 {
        \\    var index: i32 = 0;
        \\    while (index < 3) {
        \\        scratch[index] = 7 + index;
        \\        index = index + 1;
        \\    }
        \\    return scratch[2];
        \\}
    , 128, 0, 0, successor_base_function_count);
    try std.testing.expectEqual(@as(u32, 1), lowered.count);
    try std.testing.expectEqualStrings("er_init_scratch", lowered.entries[0].nameSlice());
    try std.testing.expectEqual(LoweredFunctionKind.dynamic_i32_arg_i32, lowered.entries[0].kind);
    try std.testing.expectEqual(@as(u8, 0), lowered.entries[0].arg_count);
    try std.testing.expectEqual(@as(u8, 1), lowered.entries[0].local_count);
    try std.testing.expect(std.mem.indexOfScalar(u8, lowered.entries[0].exprCode(), wasm_opcode_i32_store8) != null);
    try std.testing.expect(std.mem.indexOfScalar(u8, lowered.entries[0].exprCode(), wasm_opcode_i32_load8_u) != null);
}

test "edgerun source compiles early return guard statements" {
    const lowered = collectLoweredExportsForMode(.edgerun,
        \\const scratch: [16]u8 = undefined;
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
    , 128, 0, 0, successor_base_function_count);
    try std.testing.expectEqual(@as(u32, 1), lowered.count);
    try std.testing.expectEqualStrings("er_guarded_fill", lowered.entries[0].nameSlice());
    try std.testing.expectEqual(LoweredFunctionKind.dynamic_i32_arg_i32, lowered.entries[0].kind);
    try std.testing.expectEqual(@as(u8, 1), lowered.entries[0].arg_count);
    try std.testing.expectEqual(@as(u8, 1), lowered.entries[0].local_count);
    try std.testing.expect(std.mem.indexOfScalar(u8, lowered.entries[0].exprCode(), wasm_opcode_return) != null);
    try std.testing.expect(std.mem.indexOfScalar(u8, lowered.entries[0].exprCode(), wasm_opcode_i32_store8) != null);
    try std.testing.expect(std.mem.indexOfScalar(u8, lowered.entries[0].exprCode(), wasm_opcode_i32_load8_u) != null);
}

test "edgerun source compiles wasm32 usize and u32 arguments" {
    const lowered = collectLoweredExportsForMode(.edgerun,
        \\const scratch: [16]u8 = undefined;
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
    , 128, 0, 0, successor_base_function_count);
    try std.testing.expectEqual(@as(u32, 1), lowered.count);
    try std.testing.expectEqualStrings("er_copy_prefix", lowered.entries[0].nameSlice());
    try std.testing.expectEqual(LoweredFunctionKind.dynamic_i32_arg_i32, lowered.entries[0].kind);
    try std.testing.expectEqual(@as(u8, 2), lowered.entries[0].arg_count);
    try std.testing.expectEqual(@as(u8, 1), lowered.entries[0].local_count);
    try std.testing.expect(std.mem.indexOfScalar(u8, lowered.entries[0].exprCode(), wasm_opcode_return) != null);
    try std.testing.expect(std.mem.indexOfScalar(u8, lowered.entries[0].exprCode(), wasm_opcode_i32_store8) != null);
    try std.testing.expect(std.mem.indexOfScalar(u8, lowered.entries[0].exprCode(), wasm_opcode_i32_load8_u) != null);
}

test "edgerun source compiles three wasm32 arguments and calls" {
    const lowered = collectLoweredExportsForMode(.edgerun,
        \\fn er_weighted(left: i32, middle: u32, right: usize) i32 {
        \\    return left + middle * right;
        \\}
        \\export fn er_three_arg_mix(left: i32, middle: u32, right: usize) i32 {
        \\    return er_weighted(left, middle, right) - right;
        \\}
    , 128, 0, 0, successor_base_function_count);
    try std.testing.expectEqual(@as(u32, 2), lowered.count);
    try std.testing.expectEqualStrings("er_weighted", lowered.entries[0].nameSlice());
    try std.testing.expectEqual(LoweredFunctionKind.dynamic_i32_arg_i32, lowered.entries[0].kind);
    try std.testing.expectEqual(@as(u8, 3), lowered.entries[0].arg_count);
    try std.testing.expect(!lowered.entries[0].exported);
    try std.testing.expectEqualStrings("er_three_arg_mix", lowered.entries[1].nameSlice());
    try std.testing.expectEqual(LoweredFunctionKind.dynamic_i32_arg_i32, lowered.entries[1].kind);
    try std.testing.expectEqual(@as(u8, 3), lowered.entries[1].arg_count);
    try std.testing.expect(lowered.entries[1].exported);
    try std.testing.expect(std.mem.indexOfScalar(u8, lowered.entries[1].exprCode(), wasm_opcode_call) != null);
}

test "edgerun source compiles top level scalar state stores and loads" {
    const lowered = collectLoweredExportsForMode(.edgerun,
        \\var committed_len: usize = 0;
        \\export fn er_state_roundtrip(value: usize) i32 {
        \\    committed_len = value;
        \\    return committed_len;
        \\}
        \\export fn er_state_add(delta: u32) i32 {
        \\    committed_len = committed_len + delta;
        \\    return committed_len;
        \\}
    , 128, 0, 0, successor_base_function_count);
    try std.testing.expectEqual(@as(u32, 2), lowered.count);
    try std.testing.expectEqualStrings("er_state_roundtrip", lowered.entries[0].nameSlice());
    try std.testing.expectEqual(LoweredFunctionKind.dynamic_i32_arg_i32, lowered.entries[0].kind);
    try std.testing.expectEqual(@as(u8, 1), lowered.entries[0].arg_count);
    try std.testing.expect(std.mem.indexOfScalar(u8, lowered.entries[0].exprCode(), wasm_opcode_i32_load) != null);
    try std.testing.expect(std.mem.indexOfScalar(u8, lowered.entries[0].exprCode(), wasm_opcode_i32_store) != null);
    try std.testing.expectEqualStrings("er_state_add", lowered.entries[1].nameSlice());
    try std.testing.expectEqual(LoweredFunctionKind.dynamic_i32_arg_i32, lowered.entries[1].kind);
    try std.testing.expect(std.mem.indexOfScalar(u8, lowered.entries[1].exprCode(), wasm_opcode_i32_load) != null);
    try std.testing.expect(std.mem.indexOfScalar(u8, lowered.entries[1].exprCode(), wasm_opcode_i32_store) != null);
}

test "edgerun source compiles calls to private dynamic functions" {
    const lowered = collectLoweredExportsForMode(.edgerun,
        \\export fn er_scale(value: i32) i32 {
        \\    const doubled: i32 = er_double(value);
        \\    return er_add(doubled, 5);
        \\}
        \\export fn er_mix(left: i32, right: i32) i32 {
        \\    return er_add(left, right) * 2;
        \\}
        \\fn er_double(value: i32) i32 {
        \\    return value * 2;
        \\}
        \\fn er_add(left: i32, right: i32) i32 {
        \\    return left + right;
        \\}
    , 0, 0, 0, successor_base_function_count);
    try std.testing.expectEqual(@as(u32, 4), lowered.count);
    try std.testing.expectEqual(@as(u32, 2), lowered.exportedCount());
    try std.testing.expectEqualStrings("er_scale", lowered.entries[0].nameSlice());
    try std.testing.expect(lowered.entries[0].exported);
    try std.testing.expectEqualStrings("er_mix", lowered.entries[1].nameSlice());
    try std.testing.expectEqual(@as(u8, 2), lowered.entries[1].arg_count);
    try std.testing.expect(lowered.entries[1].exported);
    try std.testing.expectEqualStrings("er_double", lowered.entries[2].nameSlice());
    try std.testing.expect(!lowered.entries[2].exported);
    try std.testing.expectEqualStrings("er_add", lowered.entries[3].nameSlice());
    try std.testing.expectEqual(@as(u8, 2), lowered.entries[3].arg_count);
    try std.testing.expect(!lowered.entries[3].exported);
    try std.testing.expectEqual(LoweredFunctionKind.dynamic_i32_arg_i32, lowered.entries[0].kind);
    try std.testing.expect(std.mem.indexOfScalar(u8, lowered.entries[0].exprCode(), wasm_opcode_call) != null);
}

test "edgerun imported lowered names survive export table copies" {
    const imported = collectLoweredExportsForMode(.edgerun,
        \\export fn er_helper_marker() i32 {
        \\    return 41;
        \\}
    , 0, 0, 0, successor_base_function_count);
    try std.testing.expectEqual(@as(u32, 1), imported.count);

    var table = LoweredExports{};
    try std.testing.expect(table.appendImported("helper", imported.entries[0]));
    try std.testing.expectEqualStrings("helper.er_helper_marker", table.entries[0].nameSlice());

    const copied = table;
    table.entries[0].name.bytes[0] = 'x';
    try std.testing.expectEqualStrings("helper.er_helper_marker", copied.entries[0].nameSlice());
    try std.testing.expectEqualStrings("xelper.er_helper_marker", table.entries[0].nameSlice());
}

test "edgerun app main compiles local const return bodies" {
    try std.testing.expectEqual(@as(?i32, 19), lowerEdgeRunMainI32Literal(
        \\const seed: usize = 7;
        \\pub export fn er_app_main() i32 {
        \\    const doubled: usize = seed * 2;
        \\    const result: usize = doubled + 5;
        \\    return result;
        \\}
    ));
}

test "root main literal lowering is explicit and narrow" {
    try std.testing.expectEqual(@as(?i32, 7), lowerMainI32Literal("pub export fn er_app_main() i32 { return 7; }"));
    try std.testing.expectEqual(@as(?i32, -42), lowerMainI32Literal("pub export fn main() i32 { return -42; }"));
    try std.testing.expectEqual(@as(?i32, null), lowerMainI32Literal("pub export fn er_app_main() void {}"));
    try std.testing.expectEqual(@as(?i32, null), lowerMainI32Literal("pub export fn er_app_main() i32 { return value; }"));
}

test "edgerun root main lowering only uses parsed top level exports" {
    try std.testing.expectEqual(@as(?i32, 7), lowerEdgeRunMainI32Literal(
        \\const max_width: usize = 4096;
        \\pub export fn er_app_main() i32 { return 7; }
    ));
    try std.testing.expectEqual(@as(?i32, null), lowerEdgeRunMainI32Literal(
        \\const max_width: usize = 4096;
        \\export fn er_ui_outer() u32 {
        \\    pub export fn er_app_main() i32 { return 7; }
        \\    return max_width;
        \\}
    ));
    try std.testing.expectEqual(@as(?i32, null), lowerEdgeRunMainI32Literal(
        \\pub export fn main() i32 { return 7; }
    ));
    var empty_exports = LoweredExports{};
    const dynamic_main = lowerEdgeRunMain(
        \\const scratch: [16]u8 = undefined;
        \\pub export fn er_app_main() i32 {
        \\    var index: i32 = 0;
        \\    while (index < 2) {
        \\        scratch[index] = 3 + index;
        \\        index = index + 1;
        \\    }
        \\    return scratch[1];
        \\}
    , 128, &empty_exports, successor_base_function_count);
    try std.testing.expect(dynamic_main.found);
    try std.testing.expect(dynamic_main.dynamic);
    try std.testing.expect(std.mem.indexOfScalar(u8, dynamic_main.code.slice(), wasm_opcode_i32_store8) != null);
    try std.testing.expect(std.mem.indexOfScalar(u8, dynamic_main.code.slice(), wasm_opcode_i32_load8_u) != null);
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
    , 0, 0, 0);
    try std.testing.expectEqual(@as(u32, 7), lowered.count);
    try std.testing.expectEqualStrings("er_ui_max_width", lowered.entries[0].nameSlice());
    try std.testing.expectEqual(@as(i32, 4096), lowered.entries[0].value);
    try std.testing.expectEqualStrings("er_literal", lowered.entries[1].nameSlice());
    try std.testing.expectEqual(@as(i32, -3), lowered.entries[1].value);
    try std.testing.expectEqualStrings("er_zero", lowered.entries[2].nameSlice());
    try std.testing.expectEqual(@as(i32, 0), lowered.entries[2].value);
    try std.testing.expectEqualStrings("er_len", lowered.entries[3].nameSlice());
    try std.testing.expectEqual(@as(i32, 8192), lowered.entries[3].value);
    try std.testing.expectEqualStrings("er_ptr", lowered.entries[4].nameSlice());
    try std.testing.expectEqual(@as(i32, 0), lowered.entries[4].value);
    try std.testing.expectEqualStrings("er_error", lowered.entries[5].nameSlice());
    try std.testing.expectEqual(@as(i32, 0), lowered.entries[5].value);
    try std.testing.expectEqualStrings("er_dynamic", lowered.entries[6].nameSlice());
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

fn buildTestWorkspaceWithExtra(out: []u8, root_label: []const u8, root_source: []const u8, extra_label: []const u8, extra_source: []const u8) ![]const u8 {
    var root_raw: [512]u8 = undefined;
    const root_object = try buildTestObject(&root_raw, root_source);
    var extra_raw: [512]u8 = undefined;
    const extra_object = try buildTestObject(&extra_raw, extra_source);
    var manifest: [workspace_manifest_header_bytes + vfs_label_ref_bytes * 2 + root_raw.len + extra_raw.len]u8 = undefined;
    @memcpy(manifest[0..workspace_source_marker.len], workspace_source_marker);
    store16(manifest[8..10], 1);
    store16(manifest[10..12], 0);
    store32(manifest[12..16], 2);
    var index: usize = workspace_manifest_header_bytes;
    encodeTestLabelRef(manifest[index..][0..vfs_label_ref_bytes], extra_label, extra_object.len);
    index += vfs_label_ref_bytes;
    @memcpy(manifest[index..][0..extra_object.len], extra_object);
    index += extra_object.len;
    encodeTestLabelRef(manifest[index..][0..vfs_label_ref_bytes], root_label, root_object.len);
    index += vfs_label_ref_bytes;
    @memcpy(manifest[index..][0..root_object.len], root_object);
    index += root_object.len;
    return buildTestObject(out, manifest[0..index]);
}

fn buildTestWorkspaceWithTwoExtras(
    out: []u8,
    root_label: []const u8,
    root_source: []const u8,
    first_label: []const u8,
    first_source: []const u8,
    second_label: []const u8,
    second_source: []const u8,
) ![]const u8 {
    var root_raw: [512]u8 = undefined;
    const root_object = try buildTestObject(&root_raw, root_source);
    var first_raw: [512]u8 = undefined;
    const first_object = try buildTestObject(&first_raw, first_source);
    var second_raw: [512]u8 = undefined;
    const second_object = try buildTestObject(&second_raw, second_source);
    var manifest: [workspace_manifest_header_bytes + vfs_label_ref_bytes * 3 + root_raw.len + first_raw.len + second_raw.len]u8 = undefined;
    @memcpy(manifest[0..workspace_source_marker.len], workspace_source_marker);
    store16(manifest[8..10], 1);
    store16(manifest[10..12], 0);
    store32(manifest[12..16], 3);
    var index: usize = workspace_manifest_header_bytes;
    encodeTestLabelRef(manifest[index..][0..vfs_label_ref_bytes], second_label, second_object.len);
    index += vfs_label_ref_bytes;
    @memcpy(manifest[index..][0..second_object.len], second_object);
    index += second_object.len;
    encodeTestLabelRef(manifest[index..][0..vfs_label_ref_bytes], first_label, first_object.len);
    index += vfs_label_ref_bytes;
    @memcpy(manifest[index..][0..first_object.len], first_object);
    index += first_object.len;
    encodeTestLabelRef(manifest[index..][0..vfs_label_ref_bytes], root_label, root_object.len);
    index += vfs_label_ref_bytes;
    @memcpy(manifest[index..][0..root_object.len], root_object);
    index += root_object.len;
    return buildTestObject(out, manifest[0..index]);
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
