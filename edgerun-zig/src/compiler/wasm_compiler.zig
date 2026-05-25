const std = @import("std");
const builtin = @import("builtin");

const abi_version: u32 = 1;
const app_abi_version: u32 = 1;
const memory_alignment: usize = 16;
const wasm_source_offset: u32 = 1024;
const wasm_page_bytes: u32 = 65_536;
const max_source_bytes: usize = 8 * 1024 * 1024;
const fnv_offset_basis: u32 = 0x811c9dc5;
const fnv_prime: u32 = 0x01000193;
const object_magic = "EROBJ001";
const workspace_source_marker = "ERVFSWS1";

const Status = enum(u32) {
    ok = 0,
    not_initialized = 1,
    invalid_memory = 2,
    unsupported = 3,
    source_too_large = 4,
    output_too_large = 5,
    corrupt_source_object = 6,
};

const CompilerState = struct {
    memory: []u8 = &.{},
    output: []const u8 = &.{},
    diagnostic: []const u8 = "compiler not initialized",
    initialized: bool = false,
    status: Status = .not_initialized,
};

var state: CompilerState = .{};

export fn er_wasm_compiler_abi_version() u32 {
    return abi_version;
}

export fn er_wasm_compiler_init(memory_ptr: [*]u8, memory_len: usize) u32 {
    if (memory_len == 0) {
        state = .{ .status = .invalid_memory, .diagnostic = "compiler memory slice is empty" };
        return @intFromEnum(Status.invalid_memory);
    }

    const addr = @intFromPtr(memory_ptr);
    if (addr % memory_alignment != 0) {
        state = .{ .status = .invalid_memory, .diagnostic = "compiler memory slice is not aligned" };
        return @intFromEnum(Status.invalid_memory);
    }

    state = .{
        .memory = memory_ptr[0..memory_len],
        .initialized = true,
        .status = .ok,
        .diagnostic = "",
    };
    return @intFromEnum(Status.ok);
}

export fn er_wasm_compiler_status() u32 {
    return @intFromEnum(state.status);
}

export fn er_wasm_compiler_output_ptr() usize {
    return @intFromPtr(state.output.ptr);
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
    source_name_ptr: [*]const u8,
    source_name_len: usize,
    source_ptr: [*]const u8,
    source_len: usize,
) u32 {
    _ = source_name_ptr;
    _ = source_name_len;

    if (!state.initialized) {
        state.status = .not_initialized;
        state.diagnostic = "compiler not initialized";
        state.output = &.{};
        return @intFromEnum(Status.not_initialized);
    }
    if (source_len == 0 or source_len > max_source_bytes) {
        state.status = .source_too_large;
        state.diagnostic = "source size is outside compiler bounds";
        state.output = &.{};
        return @intFromEnum(Status.source_too_large);
    }

    const source = source_ptr[0..source_len];
    if (!validSourceObject(source)) {
        state.status = .corrupt_source_object;
        state.diagnostic = "compiler input is not a canonical EdgeRun object";
        state.output = &.{};
        return @intFromEnum(Status.corrupt_source_object);
    }
    if (isWorkspaceSourceObject(source)) {
        state.status = .unsupported;
        state.diagnostic = "VFS workspace successor compile requires the real Zig-to-wasm compiler ABI";
        state.output = &.{};
        return @intFromEnum(Status.unsupported);
    }

    const result = emitAppWasm(state.memory, source) catch |err| {
        state.status = .output_too_large;
        state.diagnostic = switch (err) {
            error.OutputTooLarge => "compiled wasm does not fit compiler output memory",
        };
        state.output = &.{};
        return @intFromEnum(Status.output_too_large);
    };

    state.output = state.memory[0..result];
    state.status = .ok;
    state.diagnostic = "";
    return @intFromEnum(Status.ok);
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

fn emitAppWasm(output: []u8, source: []const u8) error{OutputTooLarge}!usize {
    var writer = Writer{ .bytes = output };
    try writer.appendSlice(&.{ 0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00 });
    const source_hash = sourceHash(source);
    try emitTypeSection(&writer);
    try emitFunctionSection(&writer);
    try emitMemorySection(&writer, memoryPagesForSource(source.len));
    try emitExportSection(&writer);
    try emitStartSection(&writer);
    try emitCodeSection(&writer, @intCast(source.len), @bitCast(source_hash));
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
    var payload_buffer: [16]u8 = undefined;
    var payload = Writer{ .bytes = &payload_buffer };
    try payload.appendU32Leb(6);
    try payload.appendU32Leb(0);
    try payload.appendU32Leb(0);
    try payload.appendU32Leb(0);
    try payload.appendU32Leb(0);
    try payload.appendU32Leb(0);
    try payload.appendU32Leb(1);
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
    var payload_buffer: [256]u8 = undefined;
    var payload = Writer{ .bytes = &payload_buffer };
    try payload.appendU32Leb(6);
    try emitExport(&payload, "memory", 2, 0);
    try emitExport(&payload, "er_app_abi_version", 0, 0);
    try emitExport(&payload, "er_app_source_ptr", 0, 1);
    try emitExport(&payload, "er_app_source_len", 0, 2);
    try emitExport(&payload, "er_app_source_hash", 0, 3);
    try emitExport(&payload, "er_app_main", 0, 4);
    try emitSection(parent, 7, payload.bytes[0..payload.len]);
}

fn emitCodeSection(parent: *Writer, source_len: i32, hash: i32) error{OutputTooLarge}!void {
    var payload_buffer: [128]u8 = undefined;
    var payload = Writer{ .bytes = &payload_buffer };
    try payload.appendU32Leb(6);
    try emitReturnI32Function(&payload, app_abi_version);
    try emitReturnI32Function(&payload, @intCast(wasm_source_offset));
    try emitReturnI32Function(&payload, source_len);
    try emitReturnI32Function(&payload, hash);
    try emitReturnI32Function(&payload, hash);
    try emitNoopFunction(&payload);
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

fn isWorkspaceSourceObject(source: []const u8) bool {
    return std.mem.indexOf(u8, source, workspace_source_marker) != null;
}

test "compiler ABI rejects workspace source until real Zig compiler is embedded" {
    state = .{};
    var memory: [4096]u8 align(memory_alignment) = undefined;
    try std.testing.expectEqual(@intFromEnum(Status.ok), er_wasm_compiler_init(&memory, memory.len));

    const workspace_object =
        "EROBJ001" ++
        " canonical header bytes " ++
        workspace_source_marker ++
        "\x01\x00\x00\x00\x01\x00\x00\x00";
    try std.testing.expectEqual(
        @intFromEnum(Status.unsupported),
        er_wasm_compiler_compile_wasm("workspace.erobj".ptr, "workspace.erobj".len, workspace_object.ptr, workspace_object.len),
    );
    const diagnostic = (@as([*]const u8, @ptrFromInt(er_wasm_compiler_diagnostic_ptr())))[0..er_wasm_compiler_diagnostic_len()];
    try std.testing.expect(std.mem.indexOf(u8, diagnostic, "real Zig-to-wasm compiler ABI") != null);
    try std.testing.expectEqual(@as(usize, 0), er_wasm_compiler_output_len());
}

test "artifact packer emits launchable wasm for non-workspace canonical object" {
    state = .{};
    try std.testing.expectEqual(@as(u32, abi_version), er_wasm_compiler_abi_version());
    try std.testing.expectEqual(@intFromEnum(Status.not_initialized), er_wasm_compiler_status());
    try std.testing.expectEqual(@intFromEnum(Status.not_initialized), er_wasm_compiler_compile_wasm("main.zig".ptr, "main.zig".len, "pub fn main() void {}".ptr, "pub fn main() void {}".len));
    try std.testing.expect(er_wasm_compiler_diagnostic_len() > 0);
    try std.testing.expectEqual(@as(usize, 0), er_wasm_compiler_output_len());

    var memory: [4096]u8 align(memory_alignment) = undefined;
    try std.testing.expectEqual(@intFromEnum(Status.ok), er_wasm_compiler_init(&memory, memory.len));
    const source = "app title = edited";
    try std.testing.expectEqual(@intFromEnum(Status.corrupt_source_object), er_wasm_compiler_compile_wasm("main.er".ptr, "main.er".len, source.ptr, source.len));
    const source_object = "EROBJ001 app title = edited";
    try std.testing.expectEqual(@intFromEnum(Status.ok), er_wasm_compiler_compile_wasm("main.er".ptr, "main.er".len, source_object.ptr, source_object.len));
    const output = (@as([*]const u8, @ptrFromInt(er_wasm_compiler_output_ptr())))[0..er_wasm_compiler_output_len()];
    try std.testing.expect(output.len > source_object.len);
    try std.testing.expectEqualSlices(u8, &.{ 0x00, 0x61, 0x73, 0x6d }, output[0..4]);
    try std.testing.expect(std.mem.indexOf(u8, output, source_object) != null);
}

comptime {
    if (builtin.cpu.arch == .wasm32) {
        std.debug.assert(@sizeOf(usize) == 4);
    }
}
