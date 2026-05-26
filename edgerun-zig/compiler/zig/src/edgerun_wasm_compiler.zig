const std = @import("std");
const builtin = @import("builtin");

const abi_version: u32 = 1;
const app_abi_version: u32 = 1;
const memory_alignment: usize = 16;
const wasm_source_offset: u32 = 1024;
const wasm_page_bytes: u32 = 65_536;
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

    if (memory_ptr % memory_alignment != 0) {
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
    if (compiler_memory_len == 0 or compiler_memory_ptr % memory_alignment != 0) return fail(.invalid_memory, "compiler memory slice is invalid");
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

    const result = emitAppWasm(compiler_memory, source, workspace, compiler_output) catch |err| {
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

fn emitAppWasm(output: []u8, source: []const u8, workspace: WorkspaceInfo, compiler_output: CompilerOutputInfo) error{OutputTooLarge}!usize {
    var writer = Writer{ .bytes = output };
    try writer.appendSlice(&.{ 0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00 });
    const source_hash = sourceHash(source);
    const root_hash = sourceHash(workspace.root_source);
    try emitTypeSection(&writer);
    try emitFunctionSection(&writer);
    try emitMemorySection(&writer, memoryPagesForSource(source.len));
    try emitExportSection(&writer);
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
    );
    try emitDataSection(&writer, source);
    return writer.len;
}

fn emitTypeSection(parent: *Writer) error{OutputTooLarge}!void {
    var payload_buffer: [16]u8 = undefined;
    var payload = Writer{ .bytes = &payload_buffer };
    try payload.appendU32Leb(2);
    try payload.append(0x60);
    try payload.appendU32Leb(0);
    try payload.appendU32Leb(1);
    try payload.append(0x7f);
    try payload.append(0x60);
    try payload.appendU32Leb(0);
    try payload.appendU32Leb(0);
    try emitSection(parent, 1, payload.bytes[0..payload.len]);
}

fn emitFunctionSection(parent: *Writer) error{OutputTooLarge}!void {
    var payload_buffer: [24]u8 = undefined;
    var payload = Writer{ .bytes = &payload_buffer };
    try payload.appendU32Leb(17);
    try payload.appendU32Leb(0);
    try payload.appendU32Leb(0);
    try payload.appendU32Leb(0);
    try payload.appendU32Leb(0);
    try payload.appendU32Leb(0);
    try payload.appendU32Leb(1);
    try payload.appendU32Leb(0);
    try payload.appendU32Leb(0);
    try payload.appendU32Leb(0);
    try payload.appendU32Leb(0);
    try payload.appendU32Leb(0);
    try payload.appendU32Leb(0);
    try payload.appendU32Leb(0);
    try payload.appendU32Leb(0);
    try payload.appendU32Leb(0);
    try payload.appendU32Leb(0);
    try payload.appendU32Leb(0);
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

fn emitExportSection(parent: *Writer) error{OutputTooLarge}!void {
    var payload_buffer: [512]u8 = undefined;
    var payload = Writer{ .bytes = &payload_buffer };
    try payload.appendU32Leb(17);
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
) error{OutputTooLarge}!void {
    var payload_buffer: [240]u8 = undefined;
    var payload = Writer{ .bytes = &payload_buffer };
    try payload.appendU32Leb(17);
    try emitReturnI32Function(&payload, app_abi_version);
    try emitReturnI32Function(&payload, @intCast(wasm_source_offset));
    try emitReturnI32Function(&payload, source_len);
    try emitReturnI32Function(&payload, hash);
    try emitReturnI32Function(&payload, hash);
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

fn emitNoopFunction(writer: *Writer) error{OutputTooLarge}!void {
    var body_buffer: [8]u8 = undefined;
    var body = Writer{ .bytes = &body_buffer };
    try body.appendU32Leb(0);
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

fn memoryPagesForSource(source_len: usize) u32 {
    const needed = @as(u64, wasm_source_offset) + @as(u64, @intCast(source_len));
    return @intCast((needed + wasm_page_bytes - 1) / wasm_page_bytes);
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
    body: []const u8,
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
        const file_view = try decodeObject(file_object);
        index += label_ref.object_len;

        if (std.mem.eql(u8, label_ref.label, root_label)) root_source = file_view.body;
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
    };
}

fn analyzeWorkspaceGraph(scratch: []u8, workspace: WorkspaceInfo) error{ InvalidZig, OutOfMemory }!CompilerOutputInfo {
    var fixed = std.heap.FixedBufferAllocator.init(scratch);
    const allocator = fixed.allocator();
    const files = buildWorkspaceIndex(allocator, workspace.manifest, workspace.file_count) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        error.InvalidZig => return error.InvalidZig,
    };

    const queue = try allocator.alloc(Label, workspace.file_count);
    var queue_len: usize = 1;
    var queue_index: usize = 0;
    queue[0] = Label.init(workspace.root_label);

    var result = CompilerOutputInfo{
        .zir_instruction_count = 0,
        .zir_extra_count = 0,
        .zir_string_bytes = 0,
        .compiler_memory_used = 0,
        .analyzed_file_count = 0,
        .import_edge_count = 0,
        .unresolved_import_count = 0,
        .truncated_import_count = 0,
    };

    while (queue_index < queue_len) : (queue_index += 1) {
        const label = queue[queue_index].slice();
        const file_source = findIndexedFile(files, label) orelse {
            result.unresolved_import_count += 1;
            continue;
        };
        const sentinel_source = try allocator.dupeZ(u8, file_source);
        var tree = try std.zig.Ast.parse(allocator, sentinel_source, .zig);
        defer tree.deinit(allocator);
        if (tree.errors.len != 0) return error.InvalidZig;
        var zir = try std.zig.AstGen.generate(allocator, tree);
        defer zir.deinit(allocator);
        if (zir.hasCompileErrors()) return error.InvalidZig;

        result.analyzed_file_count += 1;
        result.zir_instruction_count += @intCast(zir.instructions.len);
        result.zir_extra_count += @intCast(zir.extra.len);
        result.zir_string_bytes += @intCast(zir.string_bytes.len);

        const imports_index = zir.extra[@intFromEnum(std.zig.Zir.ExtraIndex.imports)];
        if (imports_index == 0) continue;
        const extra = zir.extraData(std.zig.Zir.Inst.Imports, imports_index);
        var extra_index = extra.end;
        var remaining = extra.data.imports_len;
        while (remaining > 0) : (remaining -= 1) {
            const item = zir.extraData(std.zig.Zir.Inst.Imports.Item, extra_index);
            extra_index = item.end;
            result.import_edge_count += 1;
            const import_name = zir.nullTerminatedString(item.data.name);
            if (virtualImport(import_name)) continue;
            var resolved: [vfs_label_max]u8 = undefined;
            const resolved_label = resolveImportLabel(label, import_name, &resolved) orelse {
                result.unresolved_import_count += 1;
                continue;
            };
            if (findIndexedFile(files, resolved_label) == null) {
                result.unresolved_import_count += 1;
                continue;
            }
            if (labelQueued(queue[0..queue_len], resolved_label)) continue;
            if (queue_len >= queue.len) {
                result.truncated_import_count += 1;
                continue;
            }
            queue[queue_len] = Label.init(resolved_label);
            queue_len += 1;
        }
    }

    result.compiler_memory_used = @intCast(fixed.end_index);
    return result;
}

fn buildWorkspaceIndex(allocator: std.mem.Allocator, manifest: []const u8, file_count: u32) error{ InvalidZig, OutOfMemory }![]FileEntry {
    const entries = try allocator.alloc(FileEntry, file_count);
    var index: usize = workspace_manifest_header_bytes;
    var file_index: usize = 0;
    while (file_index < entries.len) : (file_index += 1) {
        if (index > manifest.len or vfs_label_ref_bytes > manifest.len - index) return error.InvalidZig;
        const label_ref = decodeLabelRef(manifest[index..][0..vfs_label_ref_bytes]) catch return error.InvalidZig;
        index += vfs_label_ref_bytes;
        if (index > manifest.len or label_ref.object_len > manifest.len - index) return error.InvalidZig;
        const file_object = manifest[index..][0..label_ref.object_len];
        const file_view = decodeObject(file_object) catch return error.InvalidZig;
        index += label_ref.object_len;
        entries[file_index] = .{
            .label = Label.init(label_ref.label),
            .body = file_view.body,
        };
    }
    if (index != manifest.len) return error.InvalidZig;
    std.mem.sort(FileEntry, entries, {}, fileEntryLessThan);
    return entries;
}

fn fileEntryLessThan(_: void, left: FileEntry, right: FileEntry) bool {
    return std.mem.order(u8, left.label.slice(), right.label.slice()) == .lt;
}

fn findIndexedFile(files: []const FileEntry, label: []const u8) ?[]const u8 {
    var low: usize = 0;
    var high: usize = files.len;
    while (low < high) {
        const mid = low + (high - low) / 2;
        switch (std.mem.order(u8, files[mid].label.slice(), label)) {
            .eq => return files[mid].body,
            .lt => low = mid + 1,
            .gt => high = mid,
        }
    }
    return null;
}

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
    return std.mem.eql(u8, import_name, "builtin") or
        std.mem.eql(u8, import_name, "build_options") or
        std.mem.eql(u8, import_name, "embedded_source_object") or
        std.mem.eql(u8, import_name, "embedded_wasm_compiler");
}

fn resolveImportLabel(importer_label: []const u8, import_name: []const u8, out: *[vfs_label_max]u8) ?[]const u8 {
    if (std.mem.eql(u8, import_name, "std")) return copyResolved(out, "compiler/zig/lib/std/std.zig");
    if (std.mem.eql(u8, import_name, "root")) return copyResolved(out, importer_label);
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

fn labelQueued(queue: []const Label, label: []const u8) bool {
    for (queue) |queued| {
        if (std.mem.eql(u8, queued.slice(), label)) return true;
    }
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
