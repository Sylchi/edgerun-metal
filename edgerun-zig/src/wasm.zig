const std = @import("std");
const app_mod = @import("app.zig");
const byte_utils = @import("bytes.zig");

const App = app_mod.App;

const max_functions = 16;
const max_types = 16;
const max_type_params = 5;
const max_locals = 16;
const max_stack = 32;
const max_call_depth = 8;
const max_control_depth = 16;
const max_globals = 16;
const max_code_bytes = 512;
const max_data_segments = 8;
const max_data_bytes = 256;
const max_export_name = 32;
const wasm_page_bytes = 65536;
const leb32_max_bytes = 5;
const leb64_max_bytes = 10;
const leb_payload_mask = 0x7f;
const leb_continue_mask = 0x80;
const leb_sign_mask = 0x40;
const leb_bits_per_byte = 7;
const wasm_empty_block_type = 0x40;

const wasm_magic = [_]u8{ 0x00, 0x61, 0x73, 0x6d };
const wasm_version = [_]u8{ 0x01, 0x00, 0x00, 0x00 };

const Section = enum(u8) {
    type = 1,
    import = 2,
    function = 3,
    memory = 5,
    global = 6,
    @"export" = 7,
    start = 8,
    code = 10,
    data = 11,
};

const ExternalKind = enum(u8) {
    function = 0,
    table = 1,
    memory = 2,
    global = 3,
};

const ValueType = enum(u8) {
    i32 = 0x7f,
    i64 = 0x7e,
    f32 = 0x7d,
    f64 = 0x7c,
};

const Opcode = enum(u8) {
    @"unreachable" = 0x00,
    nop = 0x01,
    block = 0x02,
    loop = 0x03,
    @"if" = 0x04,
    @"else" = 0x05,
    end = 0x0b,
    br = 0x0c,
    br_if = 0x0d,
    @"return" = 0x0f,
    call = 0x10,
    drop = 0x1a,
    select = 0x1b,
    local_get = 0x20,
    local_set = 0x21,
    local_tee = 0x22,
    global_get = 0x23,
    global_set = 0x24,
    i32_load = 0x28,
    i64_load = 0x29,
    i32_load8_s = 0x2c,
    i32_load8_u = 0x2d,
    i32_load16_s = 0x2e,
    i32_load16_u = 0x2f,
    i64_load8_s = 0x30,
    i64_load8_u = 0x31,
    i64_load16_s = 0x32,
    i64_load16_u = 0x33,
    i64_load32_s = 0x34,
    i64_load32_u = 0x35,
    i32_store = 0x36,
    i64_store = 0x37,
    i32_store8 = 0x3a,
    i32_store16 = 0x3b,
    i64_store8 = 0x3c,
    i64_store16 = 0x3d,
    i64_store32 = 0x3e,
    i32_const = 0x41,
    i64_const = 0x42,
    i32_eqz = 0x45,
    i32_eq = 0x46,
    i32_ne = 0x47,
    i32_lt_s = 0x48,
    i32_lt_u = 0x49,
    i32_gt_s = 0x4a,
    i32_gt_u = 0x4b,
    i32_le_s = 0x4c,
    i32_le_u = 0x4d,
    i32_ge_s = 0x4e,
    i32_ge_u = 0x4f,
    i64_eqz = 0x50,
    i64_eq = 0x51,
    i64_ne = 0x52,
    i64_lt_s = 0x53,
    i64_lt_u = 0x54,
    i64_gt_s = 0x55,
    i64_gt_u = 0x56,
    i64_le_s = 0x57,
    i64_le_u = 0x58,
    i64_ge_s = 0x59,
    i64_ge_u = 0x5a,
    i32_clz = 0x67,
    i32_ctz = 0x68,
    i32_popcnt = 0x69,
    i32_add = 0x6a,
    i32_sub = 0x6b,
    i32_mul = 0x6c,
    i32_div_s = 0x6d,
    i32_div_u = 0x6e,
    i32_rem_s = 0x6f,
    i32_rem_u = 0x70,
    i32_and = 0x71,
    i32_or = 0x72,
    i32_xor = 0x73,
    i32_shl = 0x74,
    i32_shr_s = 0x75,
    i32_shr_u = 0x76,
    i64_clz = 0x79,
    i64_ctz = 0x7a,
    i64_popcnt = 0x7b,
    i64_add = 0x7c,
    i64_sub = 0x7d,
    i64_mul = 0x7e,
    i64_div_s = 0x7f,
    i64_div_u = 0x80,
    i64_rem_s = 0x81,
    i64_rem_u = 0x82,
    i64_and = 0x83,
    i64_or = 0x84,
    i64_xor = 0x85,
    i64_shl = 0x86,
    i64_shr_s = 0x87,
    i64_shr_u = 0x88,
    i32_wrap_i64 = 0xa7,
    i64_extend_i32_s = 0xac,
    i64_extend_i32_u = 0xad,
    i32_extend8_s = 0xc0,
    i32_extend16_s = 0xc1,
    i64_extend8_s = 0xc2,
    i64_extend16_s = 0xc3,
    i64_extend32_s = 0xc4,
};

pub const Error = error{
    BadArgument,
    Corrupt,
    Unsupported,
    NoMemory,
    NoExecution,
    MissingExport,
    StackOverflow,
    StackUnderflow,
    Trap,
    ArithmeticTrap,
};

const Reader = struct {
    bytes: []const u8,
    offset: usize = 0,

    fn remaining(self: Reader) usize {
        return self.bytes.len - self.offset;
    }

    fn done(self: Reader) bool {
        return self.offset == self.bytes.len;
    }

    fn readByte(self: *Reader) Error!u8 {
        if (self.offset >= self.bytes.len) return error.Corrupt;
        const value = self.bytes[self.offset];
        self.offset += 1;
        return value;
    }

    fn readBytes(self: *Reader, len: usize) Error![]const u8 {
        if (len > self.remaining()) return error.Corrupt;
        const start = self.offset;
        self.offset += len;
        return self.bytes[start..self.offset];
    }

    fn readU32Leb(self: *Reader) Error!u32 {
        var result: u32 = 0;
        var shift: u5 = 0;
        var count: usize = 0;
        while (count < leb32_max_bytes) : (count += 1) {
            const byte = try self.readByte();
            result |= @as(u32, byte & leb_payload_mask) << shift;
            if ((byte & leb_continue_mask) == 0) return result;
            shift += leb_bits_per_byte;
        }
        return error.Corrupt;
    }

    fn readI32Leb(self: *Reader) Error!i32 {
        var result: i32 = 0;
        var shift: u5 = 0;
        var count: usize = 0;
        var byte: u8 = 0;
        while (count < leb32_max_bytes) : (count += 1) {
            byte = try self.readByte();
            result |= @as(i32, byte & leb_payload_mask) << shift;
            shift += leb_bits_per_byte;
            if ((byte & leb_continue_mask) == 0) {
                if (shift < 32 and (byte & leb_sign_mask) != 0) {
                    result |= @as(i32, -1) << shift;
                }
                return result;
            }
        }
        return error.Corrupt;
    }

    fn readI64Leb(self: *Reader) Error!i64 {
        var result: i64 = 0;
        var shift: u6 = 0;
        var count: usize = 0;
        var byte: u8 = 0;
        while (count < leb64_max_bytes) : (count += 1) {
            byte = try self.readByte();
            result |= @as(i64, byte & leb_payload_mask) << shift;
            shift += leb_bits_per_byte;
            if ((byte & leb_continue_mask) == 0) {
                if (shift < 64 and (byte & leb_sign_mask) != 0) {
                    result |= @as(i64, -1) << shift;
                }
                return result;
            }
        }
        return error.Corrupt;
    }
};

const FuncType = struct {
    params: [max_type_params]ValueType = undefined,
    param_count: usize = 0,
    result_count: usize = 0,
    result_type: ?ValueType = null,

    fn noParamsI64Result(self: FuncType) bool {
        return self.param_count == 0 and self.result_count == 1 and self.result_type == .i64;
    }

    fn noParamsNoResult(self: FuncType) bool {
        return self.param_count == 0 and self.result_count == 0 and self.result_type == null;
    }

    fn supportedParams(self: FuncType) bool {
        for (self.params[0..self.param_count]) |param| {
            if (!supportedInteger(param)) return false;
        }
        return true;
    }

    fn supportedResult(self: FuncType) bool {
        if (!self.supportedParams()) return false;
        if (self.result_count == 0 and self.result_type == null) return true;
        return self.result_count == 1 and self.result_type == .i64;
    }
};

fn supportedInteger(value_type: ValueType) bool {
    return switch (value_type) {
        .i32, .i64 => true,
        .f32, .f64 => false,
    };
}

const Code = struct {
    body: []const u8 = &.{},
    local_count: usize = 0,
    local_types: [max_locals]ValueType = undefined,
};

const Function = struct {
    type_index: usize = 0,
    code_index: usize = 0,
};

const Export = struct {
    name: [max_export_name]u8 = undefined,
    name_len: usize = 0,
    kind: ExternalKind = .function,
    index: usize = 0,

    fn matches(self: Export, name: []const u8) bool {
        return self.name_len == name.len and std.mem.eql(u8, self.name[0..self.name_len], name);
    }
};

const DataSegment = struct {
    offset: usize = 0,
    bytes: []const u8 = &.{},
};

const Global = struct {
    value_type: ValueType = .i64,
    mutable: bool = false,
    value: i64 = 0,
};

const Comparison = enum {
    eq,
    ne,
    lt_s,
    lt_u,
    gt_s,
    gt_u,
    le_s,
    le_u,
    ge_s,
    ge_u,
};

const BinaryOp = enum {
    add,
    sub,
    mul,
    div_s,
    div_u,
    rem_s,
    rem_u,
    @"and",
    @"or",
    xor,
    shl,
    shr_s,
    shr_u,
};

const UnaryOp = enum {
    clz,
    ctz,
    popcnt,
};

const MemoryLoad = enum {
    i32,
    i64,
    i32_8_s,
    i32_8_u,
    i32_16_s,
    i32_16_u,
    i64_8_s,
    i64_8_u,
    i64_16_s,
    i64_16_u,
    i64_32_s,
    i64_32_u,
};

const MemoryStore = enum {
    i32,
    i64,
    i32_8,
    i32_16,
    i64_8,
    i64_16,
    i64_32,
};

const Module = struct {
    types: [max_types]FuncType = undefined,
    type_count: usize = 0,
    functions: [max_functions]Function = undefined,
    function_count: usize = 0,
    code: [max_functions]Code = undefined,
    code_count: usize = 0,
    exports: [max_functions]Export = undefined,
    export_count: usize = 0,
    globals: [max_globals]Global = undefined,
    global_count: usize = 0,
    data_segments: [max_data_segments]DataSegment = undefined,
    data_segment_count: usize = 0,
    memory_min_pages: usize = 0,
    start_function_index: ?usize = null,

    fn parse(bytes: []const u8) Error!Module {
        var reader = Reader{ .bytes = bytes };
        if (!std.mem.eql(u8, try reader.readBytes(wasm_magic.len), &wasm_magic)) return error.Corrupt;
        if (!std.mem.eql(u8, try reader.readBytes(wasm_version.len), &wasm_version)) return error.Corrupt;

        var module = Module{};
        var previous_section: u8 = 0;
        while (!reader.done()) {
            const section_id_raw = try reader.readByte();
            const section_size = try reader.readU32Leb();
            const payload = try reader.readBytes(section_size);
            if (section_id_raw == 0) continue;
            if (section_id_raw <= previous_section) return error.Corrupt;
            previous_section = section_id_raw;
            const section = sectionFromByte(section_id_raw) orelse return error.Unsupported;
            var section_reader = Reader{ .bytes = payload };
            switch (section) {
                .type => try module.parseTypeSection(&section_reader),
                .import => try parseEmptySection(&section_reader),
                .function => try module.parseFunctionSection(&section_reader),
                .memory => try module.parseMemorySection(&section_reader),
                .global => try module.parseGlobalSection(&section_reader),
                .@"export" => try module.parseExportSection(&section_reader),
                .start => try module.parseStartSection(&section_reader),
                .code => try module.parseCodeSection(&section_reader),
                .data => try module.parseDataSection(&section_reader),
            }
            if (!section_reader.done()) return error.Corrupt;
        }
        if (module.function_count != module.code_count) return error.Corrupt;
        return module;
    }

    fn parseTypeSection(self: *Module, reader: *Reader) Error!void {
        const count = try reader.readU32Leb();
        if (count > max_types) return error.Unsupported;
        self.type_count = count;
        for (self.types[0..count]) |*func_type| {
            const form = try reader.readByte();
            if (form != 0x60) return error.Unsupported;
            const param_count = try reader.readU32Leb();
            if (param_count > max_type_params) return error.Unsupported;
            func_type.* = .{ .param_count = param_count };
            for (func_type.params[0..param_count]) |*param| {
                param.* = try readValueType(reader);
            }
            const result_count = try reader.readU32Leb();
            if (result_count > 1) return error.Unsupported;
            func_type.result_count = result_count;
            if (result_count == 1) {
                func_type.result_type = try readValueType(reader);
            }
        }
    }

    fn parseFunctionSection(self: *Module, reader: *Reader) Error!void {
        const count = try reader.readU32Leb();
        if (count > max_functions) return error.Unsupported;
        self.function_count = count;
        for (self.functions[0..count], 0..) |*function, index| {
            const type_index = try reader.readU32Leb();
            if (type_index >= self.type_count) return error.Corrupt;
            function.* = .{
                .type_index = type_index,
                .code_index = index,
            };
        }
    }

    fn parseMemorySection(self: *Module, reader: *Reader) Error!void {
        const count = try reader.readU32Leb();
        if (count > 1) return error.Unsupported;
        if (count == 0) return;
        const limits = try reader.readByte();
        if (limits != 0 and limits != 1) return error.Unsupported;
        self.memory_min_pages = try reader.readU32Leb();
        if (limits == 1) {
            const max_pages = try reader.readU32Leb();
            if (max_pages < self.memory_min_pages) return error.Corrupt;
        }
    }

    fn parseGlobalSection(self: *Module, reader: *Reader) Error!void {
        const count = try reader.readU32Leb();
        if (count > max_globals) return error.Unsupported;
        self.global_count = count;
        for (self.globals[0..count]) |*global| {
            const value_type = try readValueType(reader);
            if (!supportedInteger(value_type)) return error.Unsupported;
            const mutability = try reader.readByte();
            if (mutability > 1) return error.Corrupt;
            global.* = .{
                .value_type = value_type,
                .mutable = mutability == 1,
                .value = try readConstantValueExpression(reader, value_type),
            };
        }
    }

    fn parseExportSection(self: *Module, reader: *Reader) Error!void {
        const count = try reader.readU32Leb();
        if (count > max_functions) return error.Unsupported;
        self.export_count = count;
        for (self.exports[0..count]) |*exp| {
            const name_len = try reader.readU32Leb();
            if (name_len == 0 or name_len > max_export_name) return error.Unsupported;
            const name = try reader.readBytes(name_len);
            const kind = externalKindFromByte(try reader.readByte()) orelse return error.Unsupported;
            const index = try reader.readU32Leb();
            switch (kind) {
                .function => if (index >= self.function_count) return error.Corrupt,
                .table, .memory, .global => return error.Unsupported,
            }
            exp.* = .{
                .name_len = name_len,
                .kind = kind,
                .index = index,
            };
            @memcpy(exp.name[0..name_len], name);
        }
    }

    fn parseStartSection(self: *Module, reader: *Reader) Error!void {
        const index = try reader.readU32Leb();
        if (index >= self.function_count) return error.Corrupt;
        const function = self.functions[index];
        const function_type = self.types[function.type_index];
        if (!function_type.noParamsNoResult()) return error.Unsupported;
        self.start_function_index = index;
    }

    fn parseCodeSection(self: *Module, reader: *Reader) Error!void {
        const count = try reader.readU32Leb();
        if (count != self.function_count or count > max_functions) return error.Corrupt;
        self.code_count = count;
        for (self.code[0..count]) |*code| {
            const body_size = try reader.readU32Leb();
            if (body_size > max_code_bytes) return error.Unsupported;
            var body_reader = Reader{ .bytes = try reader.readBytes(body_size) };
            const local_group_count = try body_reader.readU32Leb();
            code.* = .{};
            var local_count: usize = 0;
            var group_index: usize = 0;
            while (group_index < local_group_count) : (group_index += 1) {
                const repeated = try body_reader.readU32Leb();
                const value_type = try readValueType(&body_reader);
                if (local_count + repeated > max_locals) return error.Unsupported;
                var repeated_index: usize = 0;
                while (repeated_index < repeated) : (repeated_index += 1) {
                    code.local_types[local_count] = value_type;
                    local_count += 1;
                }
            }
            code.local_count = local_count;
            code.body = body_reader.bytes[body_reader.offset..];
        }
    }

    fn parseDataSection(self: *Module, reader: *Reader) Error!void {
        const count = try reader.readU32Leb();
        if (count > max_data_segments) return error.Unsupported;
        self.data_segment_count = count;
        for (self.data_segments[0..count]) |*segment| {
            const mode = try reader.readU32Leb();
            const offset = switch (mode) {
                0 => try readConstantI32Expression(reader),
                1 => return error.Unsupported,
                2 => active: {
                    const memory_index = try reader.readU32Leb();
                    if (memory_index != 0) return error.Unsupported;
                    break :active try readConstantI32Expression(reader);
                },
                else => return error.Unsupported,
            };
            if (offset < 0) return error.NoMemory;
            const byte_count = try reader.readU32Leb();
            if (byte_count > max_data_bytes) return error.Unsupported;
            segment.* = .{
                .offset = @intCast(offset),
                .bytes = try reader.readBytes(byte_count),
            };
        }
    }

    fn findExport(self: Module, name: []const u8) Error!usize {
        for (self.exports[0..self.export_count]) |exp| {
            if (exp.kind == .function and exp.matches(name)) return exp.index;
        }
        return error.MissingExport;
    }

    fn requiredMemoryBytes(self: Module) Error!usize {
        return std.math.mul(usize, self.memory_min_pages, wasm_page_bytes) catch error.Unsupported;
    }

    fn applyDataSegments(self: Module, app: *App) Error!void {
        const limit = try self.requiredMemoryBytes();
        const memory = app.state.memory.owned.base;
        for (self.data_segments[0..self.data_segment_count]) |segment| {
            const end = std.math.add(usize, segment.offset, segment.bytes.len) catch return error.NoMemory;
            if (end > limit or end > memory.len) return error.NoMemory;
            @memcpy(memory[segment.offset..end], segment.bytes);
        }
    }
};

const Executor = struct {
    app: *App,
    module: Module,

    const ControlKind = enum {
        block,
        loop,
        if_then,
        if_else,
    };

    const ControlFrame = struct {
        kind: ControlKind,
        start: usize,
    };

    const Frame = struct {
        locals: [max_locals]i64 = undefined,
        stack: [max_stack]i64 = undefined,
        stack_len: usize = 0,

        fn init(function_type: FuncType, code: Code, args: []const i64) Error!Frame {
            if (args.len != function_type.param_count) return error.Corrupt;
            if (function_type.param_count + code.local_count > max_locals) return error.Unsupported;
            var frame = Frame{};
            @memset(frame.locals[0..], 0);
            for (args, 0..) |arg, index| {
                frame.locals[index] = arg;
            }
            return frame;
        }

        fn push(self: *Frame, value: i64) Error!void {
            if (self.stack_len >= max_stack) return error.StackOverflow;
            self.stack[self.stack_len] = value;
            self.stack_len += 1;
        }

        fn pop(self: *Frame) Error!i64 {
            if (self.stack_len == 0) return error.StackUnderflow;
            self.stack_len -= 1;
            return self.stack[self.stack_len];
        }

        fn pushI32(self: *Frame, value: i32) Error!void {
            try self.push(value);
        }

        fn popI32(self: *Frame) Error!i32 {
            return @truncate(try self.pop());
        }
    };

    fn runExport(self: *Executor, name: []const u8) Error!i64 {
        const function_index = try self.module.findExport(name);
        const function = self.module.functions[function_index];
        const function_type = self.module.types[function.type_index];
        if (!function_type.noParamsI64Result()) return error.Unsupported;
        return (try self.runFunction(function_index, 0, &.{})) orelse error.Corrupt;
    }

    fn runStart(self: *Executor) Error!void {
        if (self.module.start_function_index) |function_index| {
            const result = try self.runFunction(function_index, 0, &.{});
            if (result != null) return error.Corrupt;
        }
    }

    fn runFunction(self: *Executor, function_index: usize, depth: usize, args: []const i64) Error!?i64 {
        if (depth >= max_call_depth) return error.Unsupported;
        if (function_index >= self.module.function_count) return error.Corrupt;
        const function = self.module.functions[function_index];
        const function_type = self.module.types[function.type_index];
        if (!function_type.supportedResult()) return error.Unsupported;
        const code = self.module.code[function.code_index];
        var frame = try Frame.init(function_type, code, args);
        const local_limit = function_type.param_count + code.local_count;
        var controls: [max_control_depth]ControlFrame = undefined;
        var control_len: usize = 0;

        var reader = Reader{ .bytes = code.body };
        while (!reader.done()) {
            if (!self.app.consumeExecution(1)) return error.NoExecution;
            const opcode = opcodeFromByte(try reader.readByte()) orelse return error.Unsupported;
            switch (opcode) {
                .@"unreachable" => return error.Trap,
                .nop => {},
                .end => {
                    if (control_len != 0) {
                        control_len -= 1;
                        continue;
                    }
                    if (!reader.done()) return error.Corrupt;
                    return try finishFunctionResult(function_type, &frame);
                },
                .@"return" => return try finishFunctionResult(function_type, &frame),
                .block => {
                    try readEmptyBlockType(&reader);
                    try pushControl(&controls, &control_len, .block, reader.offset);
                },
                .loop => {
                    try readEmptyBlockType(&reader);
                    try pushControl(&controls, &control_len, .loop, reader.offset);
                },
                .@"if" => {
                    try readEmptyBlockType(&reader);
                    const condition = try frame.popI32();
                    if (condition == 0) {
                        const skip_result = try skipUntakenIf(&reader);
                        switch (skip_result) {
                            .reached_else => try pushControl(&controls, &control_len, .if_else, reader.offset),
                            .reached_end => {},
                        }
                    } else {
                        try pushControl(&controls, &control_len, .if_then, reader.offset);
                    }
                },
                .@"else" => {
                    if (control_len == 0 or controls[control_len - 1].kind != .if_then) return error.Corrupt;
                    try skipControlDepth(&reader, 0);
                    control_len -= 1;
                },
                .br => {
                    const branch_depth = try reader.readU32Leb();
                    try branchToControl(&reader, &controls, &control_len, branch_depth);
                },
                .br_if => {
                    const branch_depth = try reader.readU32Leb();
                    const condition = try frame.popI32();
                    if (condition != 0) try branchToControl(&reader, &controls, &control_len, branch_depth);
                },
                .i64_const => try frame.push(try reader.readI64Leb()),
                .i32_const => try frame.push(@as(i64, try reader.readI32Leb())),
                .i64_add => try pushI64Binary(&frame, .add),
                .i64_sub => try pushI64Binary(&frame, .sub),
                .i64_mul => try pushI64Binary(&frame, .mul),
                .i64_div_s => try pushI64Binary(&frame, .div_s),
                .i64_div_u => try pushI64Binary(&frame, .div_u),
                .i64_rem_s => try pushI64Binary(&frame, .rem_s),
                .i64_rem_u => try pushI64Binary(&frame, .rem_u),
                .i64_and => try pushI64Binary(&frame, .@"and"),
                .i64_or => try pushI64Binary(&frame, .@"or"),
                .i64_xor => try pushI64Binary(&frame, .xor),
                .i64_shl => try pushI64Binary(&frame, .shl),
                .i64_shr_s => try pushI64Binary(&frame, .shr_s),
                .i64_shr_u => try pushI64Binary(&frame, .shr_u),
                .i64_clz => try pushI64Unary(&frame, .clz),
                .i64_ctz => try pushI64Unary(&frame, .ctz),
                .i64_popcnt => try pushI64Unary(&frame, .popcnt),
                .i64_eqz => {
                    const value = try frame.pop();
                    try frame.push(if (value == 0) 1 else 0);
                },
                .i64_eq => try pushI64Comparison(&frame, .eq),
                .i64_ne => try pushI64Comparison(&frame, .ne),
                .i64_lt_s => try pushI64Comparison(&frame, .lt_s),
                .i64_lt_u => try pushI64Comparison(&frame, .lt_u),
                .i64_gt_s => try pushI64Comparison(&frame, .gt_s),
                .i64_gt_u => try pushI64Comparison(&frame, .gt_u),
                .i64_le_s => try pushI64Comparison(&frame, .le_s),
                .i64_le_u => try pushI64Comparison(&frame, .le_u),
                .i64_ge_s => try pushI64Comparison(&frame, .ge_s),
                .i64_ge_u => try pushI64Comparison(&frame, .ge_u),
                .i32_eqz => {
                    const value = try frame.pop();
                    try frame.push(if (@as(u32, @truncate(@as(u64, @bitCast(value)))) == 0) 1 else 0);
                },
                .i32_eq => try pushI32Comparison(&frame, .eq),
                .i32_ne => try pushI32Comparison(&frame, .ne),
                .i32_lt_s => try pushI32Comparison(&frame, .lt_s),
                .i32_lt_u => try pushI32Comparison(&frame, .lt_u),
                .i32_gt_s => try pushI32Comparison(&frame, .gt_s),
                .i32_gt_u => try pushI32Comparison(&frame, .gt_u),
                .i32_le_s => try pushI32Comparison(&frame, .le_s),
                .i32_le_u => try pushI32Comparison(&frame, .le_u),
                .i32_ge_s => try pushI32Comparison(&frame, .ge_s),
                .i32_ge_u => try pushI32Comparison(&frame, .ge_u),
                .i32_add => try pushI32Binary(&frame, .add),
                .i32_sub => try pushI32Binary(&frame, .sub),
                .i32_mul => try pushI32Binary(&frame, .mul),
                .i32_div_s => try pushI32Binary(&frame, .div_s),
                .i32_div_u => try pushI32Binary(&frame, .div_u),
                .i32_rem_s => try pushI32Binary(&frame, .rem_s),
                .i32_rem_u => try pushI32Binary(&frame, .rem_u),
                .i32_and => try pushI32Binary(&frame, .@"and"),
                .i32_or => try pushI32Binary(&frame, .@"or"),
                .i32_xor => try pushI32Binary(&frame, .xor),
                .i32_shl => try pushI32Binary(&frame, .shl),
                .i32_shr_s => try pushI32Binary(&frame, .shr_s),
                .i32_shr_u => try pushI32Binary(&frame, .shr_u),
                .i32_clz => try pushI32Unary(&frame, .clz),
                .i32_ctz => try pushI32Unary(&frame, .ctz),
                .i32_popcnt => try pushI32Unary(&frame, .popcnt),
                .i32_wrap_i64 => {
                    const value = try frame.pop();
                    try frame.push(@as(i64, @as(u32, @truncate(@as(u64, @bitCast(value))))));
                },
                .i64_extend_i32_s => {
                    const value: i32 = @truncate(try frame.pop());
                    try frame.push(value);
                },
                .i64_extend_i32_u => {
                    const value: u32 = @bitCast(@as(i32, @truncate(try frame.pop())));
                    try frame.push(@intCast(value));
                },
                .i32_extend8_s => {
                    const value: i8 = @truncate(try frame.pop());
                    try frame.push(value);
                },
                .i32_extend16_s => {
                    const value: i16 = @truncate(try frame.pop());
                    try frame.push(value);
                },
                .i64_extend8_s => {
                    const value: i8 = @truncate(try frame.pop());
                    try frame.push(value);
                },
                .i64_extend16_s => {
                    const value: i16 = @truncate(try frame.pop());
                    try frame.push(value);
                },
                .i64_extend32_s => {
                    const value: i32 = @truncate(try frame.pop());
                    try frame.push(value);
                },
                .drop => _ = try frame.pop(),
                .select => {
                    const condition = try frame.popI32();
                    const false_value = try frame.pop();
                    const true_value = try frame.pop();
                    try frame.push(if (condition != 0) true_value else false_value);
                },
                .local_get => {
                    const index = try reader.readU32Leb();
                    if (index >= local_limit) return error.Corrupt;
                    try frame.push(frame.locals[index]);
                },
                .local_set => {
                    const index = try reader.readU32Leb();
                    if (index >= local_limit) return error.Corrupt;
                    frame.locals[index] = try frame.pop();
                },
                .local_tee => {
                    const index = try reader.readU32Leb();
                    if (index >= local_limit or frame.stack_len == 0) return error.Corrupt;
                    frame.locals[index] = frame.stack[frame.stack_len - 1];
                },
                .global_get => {
                    const index = try reader.readU32Leb();
                    if (index >= self.module.global_count) return error.Corrupt;
                    try frame.push(self.module.globals[index].value);
                },
                .global_set => {
                    const index = try reader.readU32Leb();
                    if (index >= self.module.global_count) return error.Corrupt;
                    const global = &self.module.globals[index];
                    if (!global.mutable) return error.Unsupported;
                    global.value = switch (global.value_type) {
                        .i32 => try frame.popI32(),
                        .i64 => try frame.pop(),
                        .f32, .f64 => return error.Unsupported,
                    };
                },
                .i32_load => try self.loadMemory(&frame, &reader, .i32),
                .i64_load => try self.loadMemory(&frame, &reader, .i64),
                .i32_load8_s => try self.loadMemory(&frame, &reader, .i32_8_s),
                .i32_load8_u => try self.loadMemory(&frame, &reader, .i32_8_u),
                .i32_load16_s => try self.loadMemory(&frame, &reader, .i32_16_s),
                .i32_load16_u => try self.loadMemory(&frame, &reader, .i32_16_u),
                .i64_load8_s => try self.loadMemory(&frame, &reader, .i64_8_s),
                .i64_load8_u => try self.loadMemory(&frame, &reader, .i64_8_u),
                .i64_load16_s => try self.loadMemory(&frame, &reader, .i64_16_s),
                .i64_load16_u => try self.loadMemory(&frame, &reader, .i64_16_u),
                .i64_load32_s => try self.loadMemory(&frame, &reader, .i64_32_s),
                .i64_load32_u => try self.loadMemory(&frame, &reader, .i64_32_u),
                .i32_store => try self.storeMemory(&frame, &reader, .i32),
                .i64_store => try self.storeMemory(&frame, &reader, .i64),
                .i32_store8 => try self.storeMemory(&frame, &reader, .i32_8),
                .i32_store16 => try self.storeMemory(&frame, &reader, .i32_16),
                .i64_store8 => try self.storeMemory(&frame, &reader, .i64_8),
                .i64_store16 => try self.storeMemory(&frame, &reader, .i64_16),
                .i64_store32 => try self.storeMemory(&frame, &reader, .i64_32),
                .call => {
                    const callee = try reader.readU32Leb();
                    const result = try self.callFunctionFromFrame(&frame, callee, depth);
                    if (result) |value| try frame.push(value);
                },
            }
        }
        return error.Corrupt;
    }

    fn callFunctionFromFrame(self: *Executor, frame: *Frame, function_index: usize, depth: usize) Error!?i64 {
        if (function_index >= self.module.function_count) return error.Corrupt;
        const function = self.module.functions[function_index];
        const function_type = self.module.types[function.type_index];
        if (!function_type.supportedResult()) return error.Unsupported;
        var args: [max_type_params]i64 = undefined;
        var remaining = function_type.param_count;
        while (remaining > 0) {
            remaining -= 1;
            args[remaining] = try frame.pop();
        }
        return try self.runFunction(function_index, depth + 1, args[0..function_type.param_count]);
    }

    fn loadMemory(self: *Executor, frame: *Frame, reader: *Reader, kind: MemoryLoad) Error!void {
        const offset = try readMemoryImmediate(reader);
        const address = try popAddress(frame, offset);
        const size = memoryLoadSize(kind);
        const range = try self.memoryRange(address, size);
        switch (kind) {
            .i32 => try frame.push(@as(i64, byte_utils.load32(range).?)),
            .i64 => try frame.push(@as(i64, @bitCast(byte_utils.load64(range).?))),
            .i32_8_s, .i64_8_s => try frame.push(@as(i8, @bitCast(range[0]))),
            .i32_8_u, .i64_8_u => try frame.push(range[0]),
            .i32_16_s, .i64_16_s => try frame.push(@as(i16, @bitCast(byte_utils.load16(range).?))),
            .i32_16_u, .i64_16_u => try frame.push(byte_utils.load16(range).?),
            .i64_32_s => try frame.push(@as(i32, @bitCast(byte_utils.load32(range).?))),
            .i64_32_u => try frame.push(byte_utils.load32(range).?),
        }
    }

    fn storeMemory(self: *Executor, frame: *Frame, reader: *Reader, kind: MemoryStore) Error!void {
        const offset = try readMemoryImmediate(reader);
        const value = try frame.pop();
        const address = try popAddress(frame, offset);
        const size = memoryStoreSize(kind);
        const range = try self.memoryRange(address, size);
        const stored = switch (kind) {
            .i32 => byte_utils.store32(range, @truncate(@as(u64, @bitCast(value)))),
            .i64 => byte_utils.store64(range, @as(u64, @bitCast(value))),
            .i32_8, .i64_8 => store8(range, @truncate(@as(u64, @bitCast(value)))),
            .i32_16, .i64_16 => byte_utils.store16(range, @truncate(@as(u64, @bitCast(value)))),
            .i64_32 => byte_utils.store32(range, @truncate(@as(u64, @bitCast(value)))),
        };
        if (!stored) return error.Corrupt;
    }

    fn popAddress(frame: *Frame, offset: u32) Error!usize {
        const base = try frame.pop();
        if (base < 0) return error.NoMemory;
        return std.math.add(usize, @as(usize, @intCast(base)), offset) catch error.NoMemory;
    }

    fn memoryRange(self: *Executor, address: usize, size: usize) Error![]u8 {
        const limit = try self.module.requiredMemoryBytes();
        const memory = self.app.state.memory.owned.base;
        const end = std.math.add(usize, address, size) catch return error.NoMemory;
        if (end > limit or end > memory.len) return error.NoMemory;
        return memory[address..end];
    }

    fn pushControl(controls: *[max_control_depth]ControlFrame, control_len: *usize, kind: ControlKind, start: usize) Error!void {
        if (control_len.* >= max_control_depth) return error.Unsupported;
        controls[control_len.*] = .{ .kind = kind, .start = start };
        control_len.* += 1;
    }

    fn branchToControl(reader: *Reader, controls: *[max_control_depth]ControlFrame, control_len: *usize, branch_depth: u32) Error!void {
        if (branch_depth >= control_len.*) return error.Corrupt;
        const target_index = control_len.* - 1 - @as(usize, @intCast(branch_depth));
        const target = controls[target_index];
        switch (target.kind) {
            .loop => {
                reader.offset = target.start;
                control_len.* = target_index + 1;
            },
            .block, .if_then, .if_else => {
                try skipControlDepth(reader, branch_depth);
                control_len.* = target_index;
            },
        }
    }
};

pub fn executeExportI64(app: *App, wasm_bytes: []const u8, export_name: []const u8) Error!i64 {
    if (export_name.len == 0) return error.BadArgument;
    const module = try Module.parse(wasm_bytes);
    const required_memory = try module.requiredMemoryBytes();
    if (required_memory > app.state.memory.owned.len()) return error.NoMemory;
    try module.applyDataSegments(app);
    var executor = Executor{
        .app = app,
        .module = module,
    };
    try executor.runStart();
    return executor.runExport(export_name);
}

fn readValueType(reader: *Reader) Error!ValueType {
    return valueTypeFromByte(try reader.readByte()) orelse error.Unsupported;
}

fn sectionFromByte(value: u8) ?Section {
    return switch (value) {
        @intFromEnum(Section.type) => .type,
        @intFromEnum(Section.import) => .import,
        @intFromEnum(Section.function) => .function,
        @intFromEnum(Section.memory) => .memory,
        @intFromEnum(Section.global) => .global,
        @intFromEnum(Section.@"export") => .@"export",
        @intFromEnum(Section.start) => .start,
        @intFromEnum(Section.code) => .code,
        @intFromEnum(Section.data) => .data,
        else => null,
    };
}

fn externalKindFromByte(value: u8) ?ExternalKind {
    return switch (value) {
        @intFromEnum(ExternalKind.function) => .function,
        @intFromEnum(ExternalKind.table) => .table,
        @intFromEnum(ExternalKind.memory) => .memory,
        @intFromEnum(ExternalKind.global) => .global,
        else => null,
    };
}

fn valueTypeFromByte(value: u8) ?ValueType {
    return switch (value) {
        @intFromEnum(ValueType.i32) => .i32,
        @intFromEnum(ValueType.i64) => .i64,
        @intFromEnum(ValueType.f32) => .f32,
        @intFromEnum(ValueType.f64) => .f64,
        else => null,
    };
}

fn opcodeFromByte(value: u8) ?Opcode {
    return switch (value) {
        @intFromEnum(Opcode.@"unreachable") => .@"unreachable",
        @intFromEnum(Opcode.nop) => .nop,
        @intFromEnum(Opcode.block) => .block,
        @intFromEnum(Opcode.loop) => .loop,
        @intFromEnum(Opcode.@"if") => .@"if",
        @intFromEnum(Opcode.@"else") => .@"else",
        @intFromEnum(Opcode.end) => .end,
        @intFromEnum(Opcode.br) => .br,
        @intFromEnum(Opcode.br_if) => .br_if,
        @intFromEnum(Opcode.@"return") => .@"return",
        @intFromEnum(Opcode.call) => .call,
        @intFromEnum(Opcode.drop) => .drop,
        @intFromEnum(Opcode.select) => .select,
        @intFromEnum(Opcode.local_get) => .local_get,
        @intFromEnum(Opcode.local_set) => .local_set,
        @intFromEnum(Opcode.local_tee) => .local_tee,
        @intFromEnum(Opcode.global_get) => .global_get,
        @intFromEnum(Opcode.global_set) => .global_set,
        @intFromEnum(Opcode.i32_load) => .i32_load,
        @intFromEnum(Opcode.i64_load) => .i64_load,
        @intFromEnum(Opcode.i32_load8_s) => .i32_load8_s,
        @intFromEnum(Opcode.i32_load8_u) => .i32_load8_u,
        @intFromEnum(Opcode.i32_load16_s) => .i32_load16_s,
        @intFromEnum(Opcode.i32_load16_u) => .i32_load16_u,
        @intFromEnum(Opcode.i64_load8_s) => .i64_load8_s,
        @intFromEnum(Opcode.i64_load8_u) => .i64_load8_u,
        @intFromEnum(Opcode.i64_load16_s) => .i64_load16_s,
        @intFromEnum(Opcode.i64_load16_u) => .i64_load16_u,
        @intFromEnum(Opcode.i64_load32_s) => .i64_load32_s,
        @intFromEnum(Opcode.i64_load32_u) => .i64_load32_u,
        @intFromEnum(Opcode.i32_store) => .i32_store,
        @intFromEnum(Opcode.i64_store) => .i64_store,
        @intFromEnum(Opcode.i32_store8) => .i32_store8,
        @intFromEnum(Opcode.i32_store16) => .i32_store16,
        @intFromEnum(Opcode.i64_store8) => .i64_store8,
        @intFromEnum(Opcode.i64_store16) => .i64_store16,
        @intFromEnum(Opcode.i64_store32) => .i64_store32,
        @intFromEnum(Opcode.i32_const) => .i32_const,
        @intFromEnum(Opcode.i64_const) => .i64_const,
        @intFromEnum(Opcode.i32_eqz) => .i32_eqz,
        @intFromEnum(Opcode.i32_eq) => .i32_eq,
        @intFromEnum(Opcode.i32_ne) => .i32_ne,
        @intFromEnum(Opcode.i32_lt_s) => .i32_lt_s,
        @intFromEnum(Opcode.i32_lt_u) => .i32_lt_u,
        @intFromEnum(Opcode.i32_gt_s) => .i32_gt_s,
        @intFromEnum(Opcode.i32_gt_u) => .i32_gt_u,
        @intFromEnum(Opcode.i32_le_s) => .i32_le_s,
        @intFromEnum(Opcode.i32_le_u) => .i32_le_u,
        @intFromEnum(Opcode.i32_ge_s) => .i32_ge_s,
        @intFromEnum(Opcode.i32_ge_u) => .i32_ge_u,
        @intFromEnum(Opcode.i64_eqz) => .i64_eqz,
        @intFromEnum(Opcode.i64_eq) => .i64_eq,
        @intFromEnum(Opcode.i64_ne) => .i64_ne,
        @intFromEnum(Opcode.i64_lt_s) => .i64_lt_s,
        @intFromEnum(Opcode.i64_lt_u) => .i64_lt_u,
        @intFromEnum(Opcode.i64_gt_s) => .i64_gt_s,
        @intFromEnum(Opcode.i64_gt_u) => .i64_gt_u,
        @intFromEnum(Opcode.i64_le_s) => .i64_le_s,
        @intFromEnum(Opcode.i64_le_u) => .i64_le_u,
        @intFromEnum(Opcode.i64_ge_s) => .i64_ge_s,
        @intFromEnum(Opcode.i64_ge_u) => .i64_ge_u,
        @intFromEnum(Opcode.i32_clz) => .i32_clz,
        @intFromEnum(Opcode.i32_ctz) => .i32_ctz,
        @intFromEnum(Opcode.i32_popcnt) => .i32_popcnt,
        @intFromEnum(Opcode.i32_add) => .i32_add,
        @intFromEnum(Opcode.i32_sub) => .i32_sub,
        @intFromEnum(Opcode.i32_mul) => .i32_mul,
        @intFromEnum(Opcode.i32_div_s) => .i32_div_s,
        @intFromEnum(Opcode.i32_div_u) => .i32_div_u,
        @intFromEnum(Opcode.i32_rem_s) => .i32_rem_s,
        @intFromEnum(Opcode.i32_rem_u) => .i32_rem_u,
        @intFromEnum(Opcode.i32_and) => .i32_and,
        @intFromEnum(Opcode.i32_or) => .i32_or,
        @intFromEnum(Opcode.i32_xor) => .i32_xor,
        @intFromEnum(Opcode.i32_shl) => .i32_shl,
        @intFromEnum(Opcode.i32_shr_s) => .i32_shr_s,
        @intFromEnum(Opcode.i32_shr_u) => .i32_shr_u,
        @intFromEnum(Opcode.i64_clz) => .i64_clz,
        @intFromEnum(Opcode.i64_ctz) => .i64_ctz,
        @intFromEnum(Opcode.i64_popcnt) => .i64_popcnt,
        @intFromEnum(Opcode.i64_add) => .i64_add,
        @intFromEnum(Opcode.i64_sub) => .i64_sub,
        @intFromEnum(Opcode.i64_mul) => .i64_mul,
        @intFromEnum(Opcode.i64_div_s) => .i64_div_s,
        @intFromEnum(Opcode.i64_div_u) => .i64_div_u,
        @intFromEnum(Opcode.i64_rem_s) => .i64_rem_s,
        @intFromEnum(Opcode.i64_rem_u) => .i64_rem_u,
        @intFromEnum(Opcode.i64_and) => .i64_and,
        @intFromEnum(Opcode.i64_or) => .i64_or,
        @intFromEnum(Opcode.i64_xor) => .i64_xor,
        @intFromEnum(Opcode.i64_shl) => .i64_shl,
        @intFromEnum(Opcode.i64_shr_s) => .i64_shr_s,
        @intFromEnum(Opcode.i64_shr_u) => .i64_shr_u,
        @intFromEnum(Opcode.i32_wrap_i64) => .i32_wrap_i64,
        @intFromEnum(Opcode.i64_extend_i32_s) => .i64_extend_i32_s,
        @intFromEnum(Opcode.i64_extend_i32_u) => .i64_extend_i32_u,
        @intFromEnum(Opcode.i32_extend8_s) => .i32_extend8_s,
        @intFromEnum(Opcode.i32_extend16_s) => .i32_extend16_s,
        @intFromEnum(Opcode.i64_extend8_s) => .i64_extend8_s,
        @intFromEnum(Opcode.i64_extend16_s) => .i64_extend16_s,
        @intFromEnum(Opcode.i64_extend32_s) => .i64_extend32_s,
        else => null,
    };
}

fn parseEmptySection(reader: *Reader) Error!void {
    const count = try reader.readU32Leb();
    if (count != 0 or !reader.done()) return error.Unsupported;
}

fn readEmptyBlockType(reader: *Reader) Error!void {
    const block_type = try reader.readByte();
    if (block_type != wasm_empty_block_type) return error.Unsupported;
}

const IfSkipResult = enum {
    reached_else,
    reached_end,
};

fn skipUntakenIf(reader: *Reader) Error!IfSkipResult {
    var depth: usize = 0;
    while (!reader.done()) {
        const opcode = opcodeFromByte(try reader.readByte()) orelse return error.Unsupported;
        switch (opcode) {
            .block, .loop, .@"if" => {
                try readEmptyBlockType(reader);
                depth += 1;
            },
            .@"else" => {
                if (depth == 0) return .reached_else;
            },
            .end => {
                if (depth == 0) return .reached_end;
                depth -= 1;
            },
            else => try skipOpcodeImmediate(reader, opcode),
        }
    }
    return error.Corrupt;
}

fn skipControlDepth(reader: *Reader, branch_depth: u32) Error!void {
    var depth: usize = 0;
    var remaining_targets: usize = branch_depth;
    while (!reader.done()) {
        const opcode = opcodeFromByte(try reader.readByte()) orelse return error.Unsupported;
        switch (opcode) {
            .block, .loop, .@"if" => {
                try readEmptyBlockType(reader);
                depth += 1;
            },
            .end => {
                if (depth == 0) {
                    if (remaining_targets == 0) return;
                    remaining_targets -= 1;
                    continue;
                }
                depth -= 1;
            },
            else => try skipOpcodeImmediate(reader, opcode),
        }
    }
    return error.Corrupt;
}

fn skipOpcodeImmediate(reader: *Reader, opcode: Opcode) Error!void {
    switch (opcode) {
        .i32_const => _ = try reader.readI32Leb(),
        .i64_const => _ = try reader.readI64Leb(),
        .local_get,
        .local_set,
        .local_tee,
        .global_get,
        .global_set,
        .call,
        .br,
        .br_if,
        => _ = try reader.readU32Leb(),
        .i32_load,
        .i64_load,
        .i32_load8_s,
        .i32_load8_u,
        .i32_load16_s,
        .i32_load16_u,
        .i64_load8_s,
        .i64_load8_u,
        .i64_load16_s,
        .i64_load16_u,
        .i64_load32_s,
        .i64_load32_u,
        .i32_store,
        .i64_store,
        .i32_store8,
        .i32_store16,
        .i64_store8,
        .i64_store16,
        .i64_store32,
        => {
            _ = try reader.readU32Leb();
            _ = try reader.readU32Leb();
        },
        .block, .loop, .@"if" => try readEmptyBlockType(reader),
        .@"unreachable",
        .nop,
        .end,
        .@"else",
        .@"return",
        .drop,
        .select,
        .i32_eqz,
        .i32_eq,
        .i32_ne,
        .i32_lt_s,
        .i32_lt_u,
        .i32_gt_s,
        .i32_gt_u,
        .i32_le_s,
        .i32_le_u,
        .i32_ge_s,
        .i32_ge_u,
        .i64_eqz,
        .i64_eq,
        .i64_ne,
        .i64_lt_s,
        .i64_lt_u,
        .i64_gt_s,
        .i64_gt_u,
        .i64_le_s,
        .i64_le_u,
        .i64_ge_s,
        .i64_ge_u,
        .i32_add,
        .i32_sub,
        .i32_mul,
        .i32_div_s,
        .i32_div_u,
        .i32_rem_s,
        .i32_rem_u,
        .i32_and,
        .i32_or,
        .i32_xor,
        .i32_shl,
        .i32_shr_s,
        .i32_shr_u,
        .i32_clz,
        .i32_ctz,
        .i32_popcnt,
        .i64_add,
        .i64_sub,
        .i64_mul,
        .i64_div_s,
        .i64_div_u,
        .i64_rem_s,
        .i64_rem_u,
        .i64_and,
        .i64_or,
        .i64_xor,
        .i64_shl,
        .i64_shr_s,
        .i64_shr_u,
        .i64_clz,
        .i64_ctz,
        .i64_popcnt,
        .i32_wrap_i64,
        .i64_extend_i32_s,
        .i64_extend_i32_u,
        .i32_extend8_s,
        .i32_extend16_s,
        .i64_extend8_s,
        .i64_extend16_s,
        .i64_extend32_s,
        => {},
    }
}

fn finishFunctionResult(function_type: FuncType, frame: *Executor.Frame) Error!?i64 {
    if (function_type.result_count == 0) {
        if (frame.stack_len != 0) return error.Corrupt;
        return null;
    }
    return try frame.pop();
}

fn pushI32Binary(frame: *Executor.Frame, op: BinaryOp) Error!void {
    const right = try frame.popI32();
    const left = try frame.popI32();
    try frame.pushI32(try applyI32Binary(op, left, right));
}

fn pushI64Binary(frame: *Executor.Frame, op: BinaryOp) Error!void {
    const right = try frame.pop();
    const left = try frame.pop();
    try frame.push(try applyI64Binary(op, left, right));
}

fn pushI32Unary(frame: *Executor.Frame, op: UnaryOp) Error!void {
    const value = try frame.popI32();
    try frame.pushI32(applyI32Unary(op, value));
}

fn pushI64Unary(frame: *Executor.Frame, op: UnaryOp) Error!void {
    const value = try frame.pop();
    try frame.push(applyI64Unary(op, value));
}

fn applyI32Unary(op: UnaryOp, value: i32) i32 {
    const unsigned = @as(u32, @bitCast(value));
    const result = switch (op) {
        .clz => @clz(unsigned),
        .ctz => @ctz(unsigned),
        .popcnt => @popCount(unsigned),
    };
    return @intCast(result);
}

fn applyI64Unary(op: UnaryOp, value: i64) i64 {
    const unsigned = @as(u64, @bitCast(value));
    const result = switch (op) {
        .clz => @clz(unsigned),
        .ctz => @ctz(unsigned),
        .popcnt => @popCount(unsigned),
    };
    return @intCast(result);
}

fn applyI32Binary(op: BinaryOp, left: i32, right: i32) Error!i32 {
    const left_unsigned = @as(u32, @bitCast(left));
    const right_unsigned = @as(u32, @bitCast(right));
    const shift: u5 = @intCast(@as(u32, @bitCast(right)) & 31);
    return switch (op) {
        .add => left +% right,
        .sub => left -% right,
        .mul => left *% right,
        .div_s => signed: {
            if (right == 0 or (left == std.math.minInt(i32) and right == -1)) return error.ArithmeticTrap;
            break :signed @divTrunc(left, right);
        },
        .div_u => unsigned: {
            if (right_unsigned == 0) return error.ArithmeticTrap;
            break :unsigned @bitCast(@divTrunc(left_unsigned, right_unsigned));
        },
        .rem_s => signed: {
            if (right == 0) return error.ArithmeticTrap;
            if (left == std.math.minInt(i32) and right == -1) break :signed 0;
            break :signed @rem(left, right);
        },
        .rem_u => unsigned: {
            if (right_unsigned == 0) return error.ArithmeticTrap;
            break :unsigned @bitCast(@rem(left_unsigned, right_unsigned));
        },
        .@"and" => left & right,
        .@"or" => left | right,
        .xor => left ^ right,
        .shl => @bitCast(left_unsigned << shift),
        .shr_s => left >> shift,
        .shr_u => @bitCast(left_unsigned >> shift),
    };
}

fn applyI64Binary(op: BinaryOp, left: i64, right: i64) Error!i64 {
    const left_unsigned = @as(u64, @bitCast(left));
    const right_unsigned = @as(u64, @bitCast(right));
    const shift: u6 = @intCast(@as(u64, @bitCast(right)) & 63);
    return switch (op) {
        .add => left +% right,
        .sub => left -% right,
        .mul => left *% right,
        .div_s => signed: {
            if (right == 0 or (left == std.math.minInt(i64) and right == -1)) return error.ArithmeticTrap;
            break :signed @divTrunc(left, right);
        },
        .div_u => unsigned: {
            if (right_unsigned == 0) return error.ArithmeticTrap;
            break :unsigned @bitCast(@divTrunc(left_unsigned, right_unsigned));
        },
        .rem_s => signed: {
            if (right == 0) return error.ArithmeticTrap;
            if (left == std.math.minInt(i64) and right == -1) break :signed 0;
            break :signed @rem(left, right);
        },
        .rem_u => unsigned: {
            if (right_unsigned == 0) return error.ArithmeticTrap;
            break :unsigned @bitCast(@rem(left_unsigned, right_unsigned));
        },
        .@"and" => left & right,
        .@"or" => left | right,
        .xor => left ^ right,
        .shl => @bitCast(left_unsigned << shift),
        .shr_s => left >> shift,
        .shr_u => @bitCast(left_unsigned >> shift),
    };
}

fn pushI32Comparison(frame: *Executor.Frame, comparison: Comparison) Error!void {
    const right = try frame.popI32();
    const left = try frame.popI32();
    try frame.push(if (compareI32(comparison, left, right)) 1 else 0);
}

fn pushI64Comparison(frame: *Executor.Frame, comparison: Comparison) Error!void {
    const right = try frame.pop();
    const left = try frame.pop();
    try frame.push(if (compareI64(comparison, left, right)) 1 else 0);
}

fn compareI32(comparison: Comparison, left: i32, right: i32) bool {
    const left_unsigned = @as(u32, @bitCast(left));
    const right_unsigned = @as(u32, @bitCast(right));
    return switch (comparison) {
        .eq => left == right,
        .ne => left != right,
        .lt_s => left < right,
        .lt_u => left_unsigned < right_unsigned,
        .gt_s => left > right,
        .gt_u => left_unsigned > right_unsigned,
        .le_s => left <= right,
        .le_u => left_unsigned <= right_unsigned,
        .ge_s => left >= right,
        .ge_u => left_unsigned >= right_unsigned,
    };
}

fn compareI64(comparison: Comparison, left: i64, right: i64) bool {
    const left_unsigned = @as(u64, @bitCast(left));
    const right_unsigned = @as(u64, @bitCast(right));
    return switch (comparison) {
        .eq => left == right,
        .ne => left != right,
        .lt_s => left < right,
        .lt_u => left_unsigned < right_unsigned,
        .gt_s => left > right,
        .gt_u => left_unsigned > right_unsigned,
        .le_s => left <= right,
        .le_u => left_unsigned <= right_unsigned,
        .ge_s => left >= right,
        .ge_u => left_unsigned >= right_unsigned,
    };
}

fn readConstantI32Expression(reader: *Reader) Error!i32 {
    const opcode = opcodeFromByte(try reader.readByte()) orelse return error.Unsupported;
    if (opcode != .i32_const) return error.Unsupported;
    const value = try reader.readI32Leb();
    const end = opcodeFromByte(try reader.readByte()) orelse return error.Unsupported;
    if (end != .end) return error.Unsupported;
    return value;
}

fn readConstantValueExpression(reader: *Reader, value_type: ValueType) Error!i64 {
    const opcode = opcodeFromByte(try reader.readByte()) orelse return error.Unsupported;
    const value = switch (value_type) {
        .i32 => value: {
            if (opcode != .i32_const) return error.Unsupported;
            break :value @as(i64, try reader.readI32Leb());
        },
        .i64 => value: {
            if (opcode != .i64_const) return error.Unsupported;
            break :value try reader.readI64Leb();
        },
        .f32, .f64 => return error.Unsupported,
    };
    const end = opcodeFromByte(try reader.readByte()) orelse return error.Unsupported;
    if (end != .end) return error.Unsupported;
    return value;
}

fn readMemoryImmediate(reader: *Reader) Error!u32 {
    _ = try reader.readU32Leb();
    return try reader.readU32Leb();
}

fn memoryLoadSize(kind: MemoryLoad) usize {
    return switch (kind) {
        .i32 => @sizeOf(u32),
        .i64 => @sizeOf(u64),
        .i32_8_s, .i32_8_u, .i64_8_s, .i64_8_u => @sizeOf(u8),
        .i32_16_s, .i32_16_u, .i64_16_s, .i64_16_u => @sizeOf(u16),
        .i64_32_s, .i64_32_u => @sizeOf(u32),
    };
}

fn memoryStoreSize(kind: MemoryStore) usize {
    return switch (kind) {
        .i32 => @sizeOf(u32),
        .i64 => @sizeOf(u64),
        .i32_8, .i64_8 => @sizeOf(u8),
        .i32_16, .i64_16 => @sizeOf(u16),
        .i64_32 => @sizeOf(u32),
    };
}

fn store8(out: []u8, value: u8) bool {
    if (out.len < @sizeOf(u8)) return false;
    out[0] = value;
    return true;
}

test {
    _ = @import("wasm_tests.zig");
}
