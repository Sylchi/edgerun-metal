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
const default_root_label = "src/ui_browser.zig";
const successor_base_function_count: u32 = 27;
const max_lowered_exports: usize = 64;
const max_lowered_consts: usize = 128;
const max_edgerun_top_level_names: usize = max_lowered_exports + max_lowered_consts;
const max_edgerun_function_locals: usize = 32;
const max_edgerun_expr_code_bytes: usize = 64;
const max_lowered_data_bytes: usize = 512;
const max_edgerun_ui_nodes: usize = 8;
const erui_magic = "ERUI001\x00";
const erui_header_size: usize = 20;
const erui_record_size: usize = 16;
const erui_record_kind_text: u16 = 1;
const erui_record_kind_button: u16 = 2;
const erui_record_kind_input: u16 = 3;
const erui_record_kind_badge: u16 = 6;
const wasm_block_type_i32: u8 = 0x7f;
const wasm_opcode_if: u8 = 0x04;
const wasm_opcode_else: u8 = 0x05;
const wasm_opcode_end: u8 = 0x0b;
const wasm_opcode_i32_eq: u8 = 0x46;
const wasm_opcode_i32_lt_s: u8 = 0x48;
const wasm_opcode_i32_add: u8 = 0x6a;
const wasm_opcode_i32_mul: u8 = 0x6c;
const lowered_main_i32_signature = "pub export fn er_app_main() i32";
const legacy_main_i32_signature = "pub export fn main() i32";
const return_keyword = "return";
const export_fn_keyword = "export fn ";
const const_keyword = "const ";
const embedded_wasm_compiler_label = "embedded_wasm_compiler";
const type_index_no_args_i32: u32 = 0;
const type_index_no_args_void: u32 = 1;
const type_index_i32_arg_i32: u32 = 2;
const state_slot_bytes: usize = 4;
const linked_compiler_runtime_capacity: usize = 96 * 1024 * 1024;
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
    zig_compat,
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
    const source_mode = sourceModeForLabel(root_label);
    const compiler_output = analyzeWorkspaceGraph(compiler_memory, workspace, source_mode) catch |err| {
        state.status = switch (err) {
            error.OutOfMemory => .compiler_memory_too_small,
            error.InvalidZig => .invalid_zig_source,
        };
        state.diagnostic = switch (err) {
            error.OutOfMemory => "compiler memory slice is too small for Zig lowering",
            error.InvalidZig => switch (source_mode) {
                .zig_compat => "VFS root source does not lower to valid Zig ZIR",
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

fn sourceModeForLabel(label: []const u8) SourceMode {
    if (std.mem.endsWith(u8, label, ".er")) return .edgerun;
    return .zig_compat;
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
    const lowered_main = lowerMainForMode(source_mode, workspace.root_source);
    const embedded_compiler_wasm = findWorkspaceFile(workspace.manifest, embedded_wasm_compiler_label) orelse &.{};
    if (embedded_compiler_wasm.len != 0) {
        return try emitLinkedCompilerAppWasm(output, source, workspace, compiler_output, mode, source_mode, embedded_compiler_wasm, root_hash, lowered_main, source_hash);
    }
    const compiler_wasm_offset = alignForwardUsize(wasm_source_offset + embedded_source_len, memory_alignment);
    const compiler_wasm_end = compiler_wasm_offset + embedded_compiler_wasm.len;
    const lowered_data_base = alignForwardUsize(compiler_wasm_end, memory_alignment);
    const lowered_exports = collectLoweredExportsForMode(source_mode, workspace.root_source, lowered_data_base, @intCast(compiler_wasm_offset), @intCast(embedded_compiler_wasm.len));
    const source_end = wasm_source_offset + embedded_source_len;
    var memory_bytes = if (lowered_exports.memory_end > source_end) lowered_exports.memory_end else source_end;
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
    try emitDataSection(&writer, switch (mode) {
        .full_source => source,
        .metadata_only => &.{},
    }, embedded_compiler_wasm, @intCast(compiler_wasm_offset), lowered_exports.dataSlice(), @intCast(lowered_exports.data_offset));
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

const LinkedCompilerInfo = struct {
    function_count: u32,
    export_count: u32,
    code_count: u32,
    data_count: u32,
    memory_min_pages: u32,
    type_no_args_i32: u32,
    type_no_args_void: u32,
    type_i32_arg_i32: u32,
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
    lowered_main: ?i32,
    source_hash: u32,
) error{OutputTooLarge}!usize {
    const embedded_source_len: usize = switch (mode) {
        .full_source => source.len,
        .metadata_only => 0,
    };
    state.diagnostic = "linked parse compiler info";
    var compiler_info = parseLinkedCompilerInfo(compiler_wasm) orelse return error.OutputTooLarge;
    const compiler_reserved_bytes = pagesToBytesUsize(compiler_info.memory_min_pages) orelse return error.OutputTooLarge;
    const linked_source_offset = alignForwardUsize(compiler_reserved_bytes, memory_alignment);
    const source_end = linked_source_offset + embedded_source_len;
    const lowered_data_base = alignForwardUsize(source_end, memory_alignment);
    const lowered_exports = collectLoweredExportsForMode(source_mode, workspace.root_source, lowered_data_base, 0, 1);
    const memory_bytes = lowered_exports.memory_end;
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
                try emitSection(&writer, section.id, section.payload);
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
        .type_no_args_i32 = std.math.maxInt(u32),
        .type_no_args_void = std.math.maxInt(u32),
        .type_i32_arg_i32 = std.math.maxInt(u32),
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
    if (info.type_i32_arg_i32 == std.math.maxInt(u32)) return null;
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
    var index: u32 = 0;
    while (index < count) : (index += 1) {
        if ((try reader.readByte()) != 0x60) return error.OutputTooLarge;
        const param_count = try reader.readU32Leb();
        var params = [_]u8{0} ** 2;
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
    }
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
    var out_buffer: [2048]u8 = undefined;
    var out = Writer{ .bytes = &out_buffer };
    try out.appendU32Leb(info.function_count + successor_base_function_count + lowered_exports.count);
    try out.appendSlice(payload[reader.offset..]);
    var index: u32 = 0;
    while (index < successor_base_function_count) : (index += 1) try out.appendU32Leb(info.type_no_args_i32);
    for (lowered_exports.entries[0..@intCast(lowered_exports.count)]) |lowered| {
        try out.appendU32Leb(switch (lowered.kind) {
            .return_i32, .state_load_i32, .compile_workspace => info.type_no_args_i32,
            .release_artifact_commit, .source_workspace_commit => info.type_i32_arg_i32,
            .dynamic_i32_arg_i32 => info.type_i32_arg_i32,
        });
    }
    try emitSection(parent, 3, out.bytes[0..out.len]);
}

fn emitLinkedExportSection(parent: *Writer, payload: []const u8, base_function_count: u32, lowered_exports: LoweredExports) error{OutputTooLarge}!void {
    var reader = Reader{ .bytes = payload };
    const existing_count = try reader.readU32Leb();
    var out_buffer: [16384]u8 = undefined;
    var out = Writer{ .bytes = &out_buffer };
    try out.appendU32Leb(existing_count + successor_base_function_count - 1 + lowered_exports.count);
    try out.appendSlice(payload[reader.offset..]);
    try emitExport(&out, "er_app_abi_version", 0, base_function_count + 0);
    try emitExport(&out, "er_app_source_ptr", 0, base_function_count + 1);
    try emitExport(&out, "er_app_source_len", 0, base_function_count + 2);
    try emitExport(&out, "er_app_source_hash", 0, base_function_count + 3);
    try emitExport(&out, "er_app_main", 0, base_function_count + 4);
    try emitExport(&out, "er_app_source_file_count", 0, base_function_count + 6);
    try emitExport(&out, "er_app_root_source_len", 0, base_function_count + 7);
    try emitExport(&out, "er_app_root_source_hash", 0, base_function_count + 8);
    try emitExport(&out, "er_app_zir_instruction_count", 0, base_function_count + 9);
    try emitExport(&out, "er_app_zir_extra_count", 0, base_function_count + 10);
    try emitExport(&out, "er_app_zir_string_bytes", 0, base_function_count + 11);
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
        try emitExport(&out, lowered.name, 0, base_function_count + successor_base_function_count + @as(u32, @intCast(index)));
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
        zir_instruction_count,
        zir_extra_count,
        zir_string_bytes,
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
    try emitReturnI32Function(payload, zir_instruction_count);
    try emitReturnI32Function(payload, zir_extra_count);
    try emitReturnI32Function(payload, zir_string_bytes);
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
            .dynamic_i32_arg_i32 => try emitDynamicI32Function(payload, lowered.exprCode()),
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
            .dynamic_i32_arg_i32 => type_index_i32_arg_i32,
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
            .dynamic_i32_arg_i32 => try emitDynamicI32Function(&payload, lowered.exprCode()),
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

fn emitDynamicI32Function(writer: *Writer, expr_code: []const u8) error{OutputTooLarge}!void {
    var body_buffer: [max_edgerun_expr_code_bytes + 8]u8 = undefined;
    var body = Writer{ .bytes = &body_buffer };
    try body.appendU32Leb(0);
    try body.appendSlice(expr_code);
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

fn emitCompileWorkspaceFunction(writer: *Writer, lowered: LoweredExport, compiler_info: LinkedCompilerInfo) error{OutputTooLarge}!void {
    var body_buffer: [512]u8 = undefined;
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
    try emitI32Const(&body, 0);
    try emitI32Const(&body, 0);
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
    try writer.append(0x28);
    try writer.appendU32Leb(2);
    try writer.appendU32Leb(0);
}

fn emitLocalGet(writer: *Writer, local_index: u32) error{OutputTooLarge}!void {
    try writer.append(0x20);
    try writer.appendU32Leb(local_index);
}

fn emitCall(writer: *Writer, function_index: u32) error{OutputTooLarge}!void {
    try writer.append(0x10);
    try writer.appendU32Leb(function_index);
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
    try emitErrorIf(writer, error_offset, error_code_bad_input);
}

fn emitErrorIf(writer: *Writer, error_offset: i32, error_code: i32) error{OutputTooLarge}!void {
    try writer.append(0x04);
    try writer.append(0x40);
    try emitI32Const(writer, error_offset);
    try emitI32Const(writer, error_code);
    try emitI32Store(writer);
    try emitI32Const(writer, error_code);
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
    return parseI32ReturnBodyLiteral(source[body_start .. body_start + body_end_relative]);
}

fn lowerMainForMode(source_mode: SourceMode, source: []const u8) ?i32 {
    return switch (source_mode) {
        .zig_compat => lowerMainI32Literal(source),
        .edgerun => lowerEdgeRunMainI32Literal(source),
    };
}

fn lowerEdgeRunMainI32Literal(source: []const u8) ?i32 {
    const base_context = collectEdgeRunLoweringContext(source, 0);
    var index: usize = 0;
    while (true) {
        index = edgerun_source.skipSpace(source, index);
        if (index == source.len) return null;
        if (std.mem.startsWith(u8, source[index..], const_keyword)) {
            index = edgerun_source.parseConst(source, index) orelse return null;
            continue;
        }
        const parsed = edgerun_source.parseExport(source, index) orelse return null;
        index = parsed.next_index;
        if (!std.mem.eql(u8, parsed.name, "er_app_main")) continue;
        if (!allWhitespace(parsed.args)) return null;
        if (!std.mem.eql(u8, trimAsciiWhitespace(parsed.signature_tail), "i32")) return null;
        return compileEdgeRunReturnBody(parsed.body, &base_context);
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
            const value = parseI32Expression(decl.value, &context.constants) orelse return null;
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

    fn slice(expr: *const CompiledExpr) []const u8 {
        return expr.bytes[0..expr.len];
    }
};

const EdgeRunArg = struct {
    name: []const u8,
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

fn compileEdgeRunDynamicReturnBody(body: []const u8, base_context: *const LoweringContext, arg: EdgeRunArg) ?CompiledExpr {
    var locals = ExprIndex{};
    var index: usize = 0;
    while (true) {
        index = edgerun_source.skipSpace(body, index);
        if (index == body.len) return null;
        if (std.mem.startsWith(u8, body[index..], const_keyword)) {
            const decl = edgerun_source.parseConstDecl(body, index) orelse return null;
            if (!edgeRunIntegerType(decl.type_expr)) return null;
            if (std.mem.eql(u8, decl.name, arg.name)) return null;
            if (base_context.constants.find(decl.name) != null) return null;
            var code = CompiledExpr{};
            var writer = Writer{ .bytes = &code.bytes };
            compileEdgeRunExprCode(decl.value, base_context, arg, &locals, &writer) catch return null;
            code.len = @intCast(writer.len);
            if (!locals.appendUnique(decl.name, code)) return null;
            index = decl.next_index;
            continue;
        }
        if (!std.mem.startsWith(u8, body[index..], return_keyword)) return null;
        const parsed = compileEdgeRunReturnStatementCode(body, index, base_context, arg, &locals) orelse return null;
        index = edgerun_source.skipSpace(body, parsed.next_index);
        if (index != body.len) return null;
        return parsed.code;
    }
}

const ParsedReturnCode = struct {
    code: CompiledExpr,
    next_index: usize,
};

fn compileEdgeRunReturnStatementCode(body: []const u8, start: usize, context: *const LoweringContext, arg: EdgeRunArg, locals: *const ExprIndex) ?ParsedReturnCode {
    var index = start + return_keyword.len;
    if (index < body.len and identifierContinue(body[index])) return null;
    index = skipWhitespace(body, index);
    const value_start = index;
    const semicolon_relative = std.mem.indexOfScalar(u8, body[value_start..], ';') orelse return null;
    const value_end = value_start + semicolon_relative;
    var compiled = CompiledExpr{};
    var writer = Writer{ .bytes = &compiled.bytes };
    compileEdgeRunExprCode(body[value_start..value_end], context, arg, locals, &writer) catch return null;
    compiled.len = @intCast(writer.len);
    return .{
        .code = compiled,
        .next_index = value_end + 1,
    };
}

fn compileEdgeRunExprCode(raw: []const u8, context: *const LoweringContext, arg: EdgeRunArg, locals: *const ExprIndex, writer: *Writer) error{ OutputTooLarge, InvalidZig }!void {
    const text = trimAsciiWhitespace(raw);
    if (text.len == 0) return error.InvalidZig;
    if (std.mem.startsWith(u8, text, "@intCast(")) {
        const value = unwrapCallArgument(text, "@intCast(") orelse return error.InvalidZig;
        return compileEdgeRunExprCode(value, context, arg, locals, writer);
    }
    if (std.mem.startsWith(u8, text, "if (")) {
        return compileEdgeRunIfExprCode(text, context, arg, locals, writer);
    }
    if (splitTopLevelOperator(text, '+')) |split| {
        try compileEdgeRunExprCode(split.left, context, arg, locals, writer);
        try compileEdgeRunExprCode(split.right, context, arg, locals, writer);
        try writer.append(wasm_opcode_i32_add);
        return;
    }
    if (splitTopLevelOperator(text, '*')) |split| {
        try compileEdgeRunExprCode(split.left, context, arg, locals, writer);
        try compileEdgeRunExprCode(split.right, context, arg, locals, writer);
        try writer.append(wasm_opcode_i32_mul);
        return;
    }
    if (std.mem.eql(u8, text, arg.name)) {
        try emitLocalGet(writer, 0);
        return;
    }
    if (locals.find(text)) |code| {
        try writer.appendSlice(code.slice());
        return;
    }
    if (parseValueExpression(text, context)) |value| {
        try emitI32Const(writer, value);
        return;
    }
    return error.InvalidZig;
}

fn compileEdgeRunIfExprCode(text: []const u8, context: *const LoweringContext, arg: EdgeRunArg, locals: *const ExprIndex, writer: *Writer) error{ OutputTooLarge, InvalidZig }!void {
    const condition_end = findMatchingParen(text, "if ".len) orelse return error.InvalidZig;
    const condition = text["if (".len..condition_end];
    const after_condition = trimAsciiWhitespace(text[condition_end + 1 ..]);
    const else_index = findElseKeyword(after_condition) orelse return error.InvalidZig;
    const then_expr = after_condition[0..else_index];
    const else_expr = after_condition[else_index + "else".len ..];
    try compileEdgeRunConditionCode(condition, context, arg, locals, writer);
    try writer.append(wasm_opcode_if);
    try writer.append(wasm_block_type_i32);
    try compileEdgeRunExprCode(then_expr, context, arg, locals, writer);
    try writer.append(wasm_opcode_else);
    try compileEdgeRunExprCode(else_expr, context, arg, locals, writer);
    try writer.append(wasm_opcode_end);
}

fn compileEdgeRunConditionCode(raw: []const u8, context: *const LoweringContext, arg: EdgeRunArg, locals: *const ExprIndex, writer: *Writer) error{ OutputTooLarge, InvalidZig }!void {
    const text = trimAsciiWhitespace(raw);
    if (splitTopLevelToken(text, "==")) |split| {
        try compileEdgeRunExprCode(split.left, context, arg, locals, writer);
        try compileEdgeRunExprCode(split.right, context, arg, locals, writer);
        try writer.append(wasm_opcode_i32_eq);
        return;
    }
    if (splitTopLevelToken(text, "<")) |split| {
        try compileEdgeRunExprCode(split.left, context, arg, locals, writer);
        try compileEdgeRunExprCode(split.right, context, arg, locals, writer);
        try writer.append(wasm_opcode_i32_lt_s);
        return;
    }
    return error.InvalidZig;
}

const ExprSplit = struct {
    left: []const u8,
    right: []const u8,
};

fn splitTopLevelToken(text: []const u8, token: []const u8) ?ExprSplit {
    if (token.len == 0 or token.len > text.len) return null;
    var paren_depth: usize = 0;
    var index: usize = 0;
    while (index + token.len <= text.len) : (index += 1) {
        switch (text[index]) {
            '(' => paren_depth += 1,
            ')' => {
                if (paren_depth == 0) return null;
                paren_depth -= 1;
            },
            else => {},
        }
        if (paren_depth == 0 and std.mem.eql(u8, text[index..][0..token.len], token)) {
            return .{
                .left = text[0..index],
                .right = text[index + token.len ..],
            };
        }
    }
    return null;
}

fn splitTopLevelOperator(text: []const u8, operator: u8) ?ExprSplit {
    var index = text.len;
    var paren_depth: usize = 0;
    while (index > 0) {
        index -= 1;
        switch (text[index]) {
            ')' => paren_depth += 1,
            '(' => {
                if (paren_depth == 0) return null;
                paren_depth -= 1;
            },
            else => {},
        }
        if (paren_depth != 0) continue;
        if (text[index] != operator) continue;
        if (operator == '+' and index == 0) continue;
        if (operator == '*' and (index == 0 or index + 1 == text.len)) return null;
        return .{
            .left = text[0..index],
            .right = text[index + 1 ..],
        };
    }
    return null;
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

fn findElseKeyword(text: []const u8) ?usize {
    var paren_depth: usize = 0;
    var index: usize = 0;
    while (index + "else".len <= text.len) : (index += 1) {
        switch (text[index]) {
            '(' => paren_depth += 1,
            ')' => {
                if (paren_depth == 0) return null;
                paren_depth -= 1;
            },
            else => {},
        }
        if (paren_depth != 0) continue;
        if (!std.mem.eql(u8, text[index..][0.."else".len], "else")) continue;
        const before_ok = index == 0 or asciiWhitespace(text[index - 1]);
        const after_index = index + "else".len;
        const after_ok = after_index == text.len or asciiWhitespace(text[after_index]);
        if (before_ok and after_ok) return index;
    }
    return null;
}

fn parseEdgeRunI32Arg(args: []const u8) ?EdgeRunArg {
    const text = trimAsciiWhitespace(args);
    const colon_relative = std.mem.indexOfScalar(u8, text, ':') orelse return null;
    const name = trimAsciiWhitespace(text[0..colon_relative]);
    const type_name = trimAsciiWhitespace(text[colon_relative + 1 ..]);
    const name_end = scanIdentifierEnd(name, 0) orelse return null;
    if (name_end != name.len) return null;
    if (!std.mem.eql(u8, type_name, "i32")) return null;
    return .{ .name = name };
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
                .name = name,
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

fn collectLoweredExportsForMode(source_mode: SourceMode, source: []const u8, data_base: usize, compiler_wasm_offset: i32, compiler_wasm_len: i32) LoweredExports {
    return switch (source_mode) {
        .zig_compat => collectLoweredExports(source, data_base, compiler_wasm_offset, compiler_wasm_len),
        .edgerun => collectEdgeRunLoweredExports(source, data_base),
    };
}

fn collectEdgeRunLoweredExports(source: []const u8, data_base: usize) LoweredExports {
    var context = collectEdgeRunLoweringContext(source, data_base);
    var lowered = LoweredExports{
        .memory_end = context.next_data_offset,
    };
    var index: usize = 0;
    while (true) {
        index = edgerun_source.skipSpace(source, index);
        if (index == source.len) break;
        if (std.mem.startsWith(u8, source[index..], const_keyword)) {
            index = edgerun_source.parseConst(source, index) orelse break;
            continue;
        }
        const parsed = edgerun_source.parseExport(source, index) orelse break;
        index = parsed.next_index;
        if (reservedExportName(parsed.name)) continue;
        if (!integerReturnType(parsed.signature_tail)) continue;
        if (parseEdgeRunI32Arg(parsed.args)) |arg| {
            const compiled = compileEdgeRunDynamicReturnBody(parsed.body, &context, arg) orelse continue;
            lowered.appendDynamicI32Arg(parsed.name, compiled);
            continue;
        }
        if (!allWhitespace(parsed.args)) continue;
        const value = compileEdgeRunReturnBody(parsed.body, &context) orelse continue;
        lowered.append(parsed.name, value);
    }
    collectEdgeRunUiData(source, &lowered);
    lowered.memory_end = context.next_data_offset;
    if (lowered.data_len != 0) {
        lowered.data_offset = alignForwardUsize(lowered.memory_end, memory_alignment);
        lowered.memory_end = alignForwardUsize(lowered.data_offset + lowered.data_len, memory_alignment);
        lowered.appendGenerated("er_ui_root_ptr", @intCast(lowered.data_offset));
        lowered.appendGenerated("er_ui_root_len", @intCast(lowered.data_len));
    }
    return lowered;
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
        if (edgerun_source.parseExport(source, index)) |parsed| {
            index = parsed.next_index;
            continue;
        }
        return;
    }
    if (nodes.count != 0) lowered.data_len = buildUiBytes(&lowered.data, nodes, layout) orelse 0;
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
            }
            index = decl.next_index;
            continue;
        }
        if (edgerun_source.parseExport(source, index)) |parsed| {
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
    name: []const u8,
    value: i32,
    limit: i32 = 0,
    state_offset: i32 = 0,
    ready_offset: i32 = 0,
    error_offset: i32 = 0,
    source_ptr: i32 = 0,
    source_len_offset: i32 = 0,
    source_capacity: i32 = 0,
    release_ptr: i32 = 0,
    release_len_offset: i32 = 0,
    release_capacity: i32 = 0,
    expr_code: [max_edgerun_expr_code_bytes]u8 = [_]u8{0} ** max_edgerun_expr_code_bytes,
    expr_code_len: u8 = 0,
    kind: LoweredFunctionKind = .return_i32,

    fn exprCode(lowered: *const LoweredExport) []const u8 {
        return lowered.expr_code[0..lowered.expr_code_len];
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

    fn append(exports: *LoweredExports, name: []const u8, value: i32) void {
        exports.appendEntry(.{ .name = name, .value = value }, true);
    }

    fn appendDynamicI32Arg(exports: *LoweredExports, name: []const u8, code: CompiledExpr) void {
        var lowered = LoweredExport{
            .name = name,
            .value = 0,
            .kind = .dynamic_i32_arg_i32,
        };
        @memcpy(lowered.expr_code[0..code.len], code.bytes[0..code.len]);
        lowered.expr_code_len = code.len;
        exports.appendEntry(lowered, true);
    }

    fn appendStateLoad(exports: *LoweredExports, name: []const u8, state_offset: i32) void {
        exports.appendEntry(.{ .name = name, .value = state_offset, .kind = .state_load_i32 }, true);
    }

    fn appendReleaseArtifactCommit(exports: *LoweredExports, name: []const u8, ptr: i32, capacity: i32, len_offset: i32, error_offset: i32) void {
        exports.appendEntry(.{
            .name = name,
            .value = ptr,
            .limit = capacity,
            .state_offset = len_offset,
            .error_offset = error_offset,
            .kind = .release_artifact_commit,
        }, true);
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
        }, true);
    }

    fn appendCompileWorkspace(exports: *LoweredExports, lowered: LoweredExport) void {
        exports.appendEntry(lowered, true);
    }

    fn appendGenerated(exports: *LoweredExports, name: []const u8, value: i32) void {
        exports.appendEntry(.{ .name = name, .value = value }, false);
    }

    fn appendEntry(exports: *LoweredExports, lowered: LoweredExport, declared: bool) void {
        if (exports.count >= exports.entries.len) return;
        if (reservedExportName(lowered.name)) return;
        for (exports.entries[0..@intCast(exports.count)]) |entry| {
            if (std.mem.eql(u8, entry.name, lowered.name)) return;
        }
        exports.entries[@intCast(exports.count)] = lowered;
        exports.count += 1;
        if (declared) exports.declared_count += 1;
    }

    fn dataSlice(exports: *const LoweredExports) []const u8 {
        return exports.data[0..exports.data_len];
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
        .lowered_export_count = collectLoweredExports(source, 0, 0, 0).count,
    };
}

const EdgeRunRootAnalysis = struct {
    instruction_count: u32,
    extra_count: u32,
    string_bytes: u32,
};

fn analyzeEdgeRunRoot(source: []const u8) ?EdgeRunRootAnalysis {
    if (std.mem.indexOf(u8, source, "@import(") != null) return null;
    const parsed = edgerun_source.parse(source) orelse return null;
    if (!edgeRunTopLevelNamesUnique(source)) return null;

    const lowered_main_count: u32 = if (lowerEdgeRunMainI32Literal(source) == null) 0 else 1;
    const lowered_exports = collectEdgeRunLoweredExports(source, 0);
    if (lowered_main_count + lowered_exports.declared_count != parsed.export_count) return null;

    return .{
        .instruction_count = lowered_main_count + lowered_exports.count,
        .extra_count = parsed.declaration_count,
        .string_bytes = parsed.export_name_bytes,
    };
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
        if (edgerun_source.parseExport(source, index)) |parsed| {
            if (!names.appendUnique(parsed.name)) return false;
            index = parsed.next_index;
            continue;
        }
        return false;
    }
}

fn analyzeWorkspaceGraph(scratch: []u8, workspace: WorkspaceInfo, source_mode: SourceMode) error{ InvalidZig, OutOfMemory }!CompilerOutputInfo {
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
            switch (source_mode) {
                .zig_compat => {
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
                },
                .edgerun => {
                    const analysis = analyzeEdgeRunRoot(file_source) orelse return error.InvalidZig;
                    result.zir_instruction_count += analysis.instruction_count;
                    result.zir_extra_count += analysis.extra_count;
                    result.zir_string_bytes += analysis.string_bytes;
                },
            }
        }
        result.analyzed_file_count += 1;

        switch (source_mode) {
            .zig_compat => {
                var imports = ImportScanner{ .source = file_source };
                while (imports.next()) |import_name| enqueueImport(files, queue, &queue_len, label, import_name, &result);
            },
            .edgerun => {},
        }
    }

    result.compiler_memory_used = @intCast(fixed.end_index);
    if (lowerMainForMode(source_mode, workspace.root_source) != null) result.lowered_main_count = 1;
    result.lowered_export_count = collectLoweredExportsForMode(source_mode, workspace.root_source, 0, 0, if (findWorkspaceFile(workspace.manifest, embedded_wasm_compiler_label) == null) 0 else 1).count;
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
        @intFromEnum(Status.invalid_zig_source),
        er_wasm_compiler_compile_wasm(@intFromPtr(&memory), memory.len, @intFromPtr(root_label.ptr), root_label.len, @intFromPtr(workspace_object.ptr), workspace_object.len),
    );
    try std.testing.expect(er_wasm_compiler_diagnostic_len() > 0);
    try std.testing.expectEqual(@as(usize, 0), er_wasm_compiler_output_len());
    try std.testing.expect(analyzeEdgeRunRoot(root_source) == null);
}

test "edgerun source parser rejects unsupported top level declarations" {
    try std.testing.expect(analyzeEdgeRunRoot(
        \\var counter: i32 = 0;
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
    , 0, 0, 0);
    try std.testing.expectEqual(@as(u32, 1), lowered.count);
    try std.testing.expectEqualStrings("er_ui_max_width", lowered.entries[0].name);
    try std.testing.expectEqual(@as(i32, 4096), lowered.entries[0].value);
}

test "edgerun source function locals do not leak between exports" {
    const lowered = collectLoweredExportsForMode(.edgerun,
        \\const max_width: usize = 4096;
        \\export fn er_ui_define_hidden() u32 {
        \\    const hidden_width: usize = 8192;
        \\    return hidden_width;
        \\}
        \\export fn er_ui_use_hidden() u32 { return hidden_width; }
    , 0, 0, 0);
    try std.testing.expectEqual(@as(u32, 1), lowered.count);
    try std.testing.expectEqualStrings("er_ui_define_hidden", lowered.entries[0].name);
    try std.testing.expectEqual(@as(i32, 8192), lowered.entries[0].value);
}

test "edgerun source lowering collects top level const array lengths" {
    const lowered = collectLoweredExportsForMode(.edgerun,
        \\const max_width: usize = 4096;
        \\const source_workspace: [max_width]u8 = undefined;
        \\export fn er_ui_source_workspace_ptr() u32 { return @intFromPtr(&source_workspace); }
        \\export fn er_ui_source_workspace_capacity() u32 { return source_workspace.len; }
    , 256, 0, 0);
    try std.testing.expectEqual(@as(u32, 2), lowered.count);
    try std.testing.expectEqualStrings("er_ui_source_workspace_ptr", lowered.entries[0].name);
    try std.testing.expectEqual(@as(i32, 256), lowered.entries[0].value);
    try std.testing.expectEqualStrings("er_ui_source_workspace_capacity", lowered.entries[1].name);
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
    , 0, 0, 0);
    try std.testing.expectEqual(@as(u32, 1), lowered.count);
    try std.testing.expectEqualStrings("er_ui_local_width", lowered.entries[0].name);
    try std.testing.expectEqual(@as(i32, 4113), lowered.entries[0].value);
}

test "edgerun source compiles dynamic i32 argument expressions" {
    const lowered = collectLoweredExportsForMode(.edgerun,
        \\const bias: usize = 5;
        \\export fn er_scale(value: i32) i32 {
        \\    const tripled: i32 = value * 3;
        \\    const shifted: i32 = tripled + bias;
        \\    return shifted;
        \\}
    , 0, 0, 0);
    try std.testing.expectEqual(@as(u32, 1), lowered.count);
    try std.testing.expectEqualStrings("er_scale", lowered.entries[0].name);
    try std.testing.expectEqual(LoweredFunctionKind.dynamic_i32_arg_i32, lowered.entries[0].kind);
    try std.testing.expect(lowered.entries[0].expr_code_len > 0);
}

test "edgerun source compiles dynamic if else expressions" {
    const lowered = collectLoweredExportsForMode(.edgerun,
        \\export fn er_non_negative(value: i32) i32 {
        \\    return if (value < 0) 0 else value;
        \\}
    , 0, 0, 0);
    try std.testing.expectEqual(@as(u32, 1), lowered.count);
    try std.testing.expectEqualStrings("er_non_negative", lowered.entries[0].name);
    try std.testing.expectEqual(LoweredFunctionKind.dynamic_i32_arg_i32, lowered.entries[0].kind);
    try std.testing.expect(lowered.entries[0].expr_code_len > 0);
}

test "edgerun app main compiles local const return bodies" {
    try std.testing.expectEqual(@as(?i32, 19), lowerMainForMode(.edgerun,
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
    try std.testing.expectEqual(@as(?i32, 7), lowerMainForMode(.edgerun,
        \\const max_width: usize = 4096;
        \\pub export fn er_app_main() i32 { return 7; }
    ));
    try std.testing.expectEqual(@as(?i32, null), lowerMainForMode(.edgerun,
        \\const max_width: usize = 4096;
        \\export fn er_ui_outer() u32 {
        \\    pub export fn er_app_main() i32 { return 7; }
        \\    return max_width;
        \\}
    ));
    try std.testing.expectEqual(@as(?i32, null), lowerMainForMode(.edgerun,
        \\pub export fn main() i32 { return 7; }
    ));
    try std.testing.expectEqual(@as(?i32, null), lowerMainForMode(.edgerun,
        \\pub export fn er_app_main() i32 {
        \\    var value: i32 = 7;
        \\    return 7;
        \\}
    ));
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
