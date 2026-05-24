const byte_utils = @import("bytes.zig");

const max_functions = 16;
const max_imports = 16;
const max_types = 16;
const max_type_params = 5;
const max_type_results = 4;
const max_locals = 16;
const max_stack = 32;
const max_call_depth = 8;
const max_control_depth = 16;
const max_globals = 16;
const max_table_entries = 32;
const max_data_segments = 8;
const wasm_page_bytes = 65536;
const leb32_max_bytes = 5;
const leb64_max_bytes = 10;
const leb_payload_mask = 0x7f;
const leb_continue_mask = 0x80;
const leb_sign_mask = 0x40;
const leb_bits_per_byte = 7;
const wasm_empty_block_type = 0x40;
const wasm_funcref_type = 0x70;
const wasm_ref_func_opcode = 0xd2;
const wasm_extended_prefix = 0xfc;
const ext_i32_trunc_sat_f32_s: u32 = 0;
const ext_i32_trunc_sat_f32_u: u32 = 1;
const ext_i32_trunc_sat_f64_s: u32 = 2;
const ext_i32_trunc_sat_f64_u: u32 = 3;
const ext_i64_trunc_sat_f32_s: u32 = 4;
const ext_i64_trunc_sat_f32_u: u32 = 5;
const ext_i64_trunc_sat_f64_s: u32 = 6;
const ext_i64_trunc_sat_f64_u: u32 = 7;
const ext_memory_init: u32 = 8;
const ext_data_drop: u32 = 9;
const ext_memory_copy: u32 = 10;
const ext_memory_fill: u32 = 11;
const ext_table_init: u32 = 12;
const ext_elem_drop: u32 = 13;
const ext_table_copy: u32 = 14;
const ext_table_grow: u32 = 15;
const ext_table_size: u32 = 16;
const ext_table_fill: u32 = 17;
const i32_min_as_f32: f32 = -2147483648.0;
const i32_max_plus_one_as_f32: f32 = 2147483648.0;
const u32_max_plus_one_as_f32: f32 = 4294967296.0;
const i32_min_as_f64: f64 = -2147483648.0;
const i32_max_plus_one_as_f64: f64 = 2147483648.0;
const u32_max_plus_one_as_f64: f64 = 4294967296.0;
const i64_min_as_f32: f32 = -9223372036854775808.0;
const i64_max_plus_one_as_f32: f32 = 9223372036854775808.0;
const u64_max_plus_one_as_f32: f32 = 18446744073709551616.0;
const i64_min_as_f64: f64 = -9223372036854775808.0;
const i64_max_plus_one_as_f64: f64 = 9223372036854775808.0;
const u64_max_plus_one_as_f64: f64 = 18446744073709551616.0;

const wasm_magic = [_]u8{ 0x00, 0x61, 0x73, 0x6d };
const wasm_version = [_]u8{ 0x01, 0x00, 0x00, 0x00 };

const Section = enum(u8) {
    type = 1,
    import = 2,
    function = 3,
    table = 4,
    memory = 5,
    global = 6,
    @"export" = 7,
    start = 8,
    element = 9,
    code = 10,
    data = 11,
    data_count = 12,
};

const ExternalKind = enum(u8) {
    function = 0,
    table = 1,
    memory = 2,
    global = 3,
};

pub const ValueType = enum(u8) {
    i32 = 0x7f,
    i64 = 0x7e,
    f32 = 0x7d,
    f64 = 0x7c,
    funcref = wasm_funcref_type,
};

pub const Value = union(ValueType) {
    i32: i32,
    i64: i64,
    f32: f32,
    f64: f64,
    funcref: ?usize,

    fn zero(value_type: ValueType) Error!Value {
        return switch (value_type) {
            .i32 => .{ .i32 = 0 },
            .i64 => .{ .i64 = 0 },
            .f32 => .{ .f32 = 0 },
            .f64 => .{ .f64 = 0 },
            .funcref => .{ .funcref = null },
        };
    }

    fn fromI64Arg(value_type: ValueType, value: i64) Error!Value {
        return switch (value_type) {
            .i32 => .{ .i32 = @truncate(value) },
            .i64 => .{ .i64 = value },
            .f32, .f64, .funcref => error.Unsupported,
        };
    }

    pub fn asI32(self: Value) Error!i32 {
        return switch (self) {
            .i32 => |value| value,
            else => error.Corrupt,
        };
    }

    pub fn asI64(self: Value) Error!i64 {
        return switch (self) {
            .i64 => |value| value,
            else => error.Corrupt,
        };
    }

    pub fn asF32(self: Value) Error!f32 {
        return switch (self) {
            .f32 => |value| value,
            else => error.Corrupt,
        };
    }

    pub fn asF64(self: Value) Error!f64 {
        return switch (self) {
            .f64 => |value| value,
            else => error.Corrupt,
        };
    }

    pub fn asFuncref(self: Value) Error!?usize {
        return switch (self) {
            .funcref => |value| value,
            else => error.Corrupt,
        };
    }

    pub fn asIntegerI64(self: Value) Error!i64 {
        return switch (self) {
            .i32 => |value| value,
            .i64 => |value| value,
            .f32, .f64, .funcref => error.Unsupported,
        };
    }
};

pub const ExecutionResult = struct {
    values: [max_type_results]Value = undefined,
    count: usize = 0,

    fn empty() ExecutionResult {
        return .{};
    }

    fn single(value: Value) ExecutionResult {
        var result = ExecutionResult{ .count = 1 };
        result.values[0] = value;
        return result;
    }

    pub fn optionalI64(self: ExecutionResult) Error!?i64 {
        if (self.count == 0) return null;
        return try self.onlyI64();
    }

    pub fn onlyI64(self: ExecutionResult) Error!i64 {
        if (self.count != 1) return error.Corrupt;
        return self.values[0].asIntegerI64();
    }

    pub fn valueI32(self: ExecutionResult, index: usize) Error!i32 {
        if (index >= self.count) return error.Corrupt;
        return self.values[index].asI32();
    }

    pub fn valueI64(self: ExecutionResult, index: usize) Error!i64 {
        if (index >= self.count) return error.Corrupt;
        return self.values[index].asI64();
    }

    pub fn valueF32(self: ExecutionResult, index: usize) Error!f32 {
        if (index >= self.count) return error.Corrupt;
        return self.values[index].asF32();
    }

    pub fn valueF64(self: ExecutionResult, index: usize) Error!f64 {
        if (index >= self.count) return error.Corrupt;
        return self.values[index].asF64();
    }
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
    br_table = 0x0e,
    @"return" = 0x0f,
    call = 0x10,
    call_indirect = 0x11,
    drop = 0x1a,
    select = 0x1b,
    select_typed = 0x1c,
    local_get = 0x20,
    local_set = 0x21,
    local_tee = 0x22,
    global_get = 0x23,
    global_set = 0x24,
    table_get = 0x25,
    table_set = 0x26,
    i32_load = 0x28,
    i64_load = 0x29,
    f32_load = 0x2a,
    f64_load = 0x2b,
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
    f32_store = 0x38,
    f64_store = 0x39,
    i32_store8 = 0x3a,
    i32_store16 = 0x3b,
    i64_store8 = 0x3c,
    i64_store16 = 0x3d,
    i64_store32 = 0x3e,
    memory_size = 0x3f,
    memory_grow = 0x40,
    i32_const = 0x41,
    i64_const = 0x42,
    f32_const = 0x43,
    f64_const = 0x44,
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
    f32_eq = 0x5b,
    f32_ne = 0x5c,
    f32_lt = 0x5d,
    f32_gt = 0x5e,
    f32_le = 0x5f,
    f32_ge = 0x60,
    f64_eq = 0x61,
    f64_ne = 0x62,
    f64_lt = 0x63,
    f64_gt = 0x64,
    f64_le = 0x65,
    f64_ge = 0x66,
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
    f32_abs = 0x8b,
    f32_neg = 0x8c,
    f32_sqrt = 0x91,
    f32_add = 0x92,
    f32_sub = 0x93,
    f32_mul = 0x94,
    f32_div = 0x95,
    f64_abs = 0x99,
    f64_neg = 0x9a,
    f64_sqrt = 0x9f,
    f64_add = 0xa0,
    f64_sub = 0xa1,
    f64_mul = 0xa2,
    f64_div = 0xa3,
    i32_wrap_i64 = 0xa7,
    i32_trunc_f32_s = 0xa8,
    i32_trunc_f32_u = 0xa9,
    i32_trunc_f64_s = 0xaa,
    i32_trunc_f64_u = 0xab,
    i64_extend_i32_s = 0xac,
    i64_extend_i32_u = 0xad,
    i64_trunc_f32_s = 0xae,
    i64_trunc_f32_u = 0xaf,
    i64_trunc_f64_s = 0xb0,
    i64_trunc_f64_u = 0xb1,
    f32_convert_i32_s = 0xb2,
    f32_convert_i32_u = 0xb3,
    f32_convert_i64_s = 0xb4,
    f32_convert_i64_u = 0xb5,
    f32_demote_f64 = 0xb6,
    f64_convert_i32_s = 0xb7,
    f64_convert_i32_u = 0xb8,
    f64_convert_i64_s = 0xb9,
    f64_convert_i64_u = 0xba,
    f64_promote_f32 = 0xbb,
    i32_reinterpret_f32 = 0xbc,
    i64_reinterpret_f64 = 0xbd,
    f32_reinterpret_i32 = 0xbe,
    f64_reinterpret_i64 = 0xbf,
    i32_extend8_s = 0xc0,
    i32_extend16_s = 0xc1,
    i64_extend8_s = 0xc2,
    i64_extend16_s = 0xc3,
    i64_extend32_s = 0xc4,
    ref_null = 0xd0,
    ref_is_null = 0xd1,
    ref_func = wasm_ref_func_opcode,
};

pub const Error = error{
    BadArgument,
    Corrupt,
    Unsupported,
    NoMemory,
    MemoryGrowthRequiresAuthority,
    TableGrowthRequiresAuthority,
    NoExecution,
    MissingExport,
    MissingImport,
    StackOverflow,
    StackUnderflow,
    Trap,
    ArithmeticTrap,
};

pub const Runtime = struct {
    memory: []u8,
    execution_ticks: *u64,
    imports: []const HostImport = &.{},
    memory_grow_authority: ?MemoryGrowAuthority = null,
    table_grow_authority: ?TableGrowAuthority = null,

    pub fn init(memory: []u8, execution_ticks: *u64) Runtime {
        return initWithImports(memory, execution_ticks, &.{});
    }

    pub fn initWithImports(memory: []u8, execution_ticks: *u64, imports: []const HostImport) Runtime {
        return .{
            .memory = memory,
            .execution_ticks = execution_ticks,
            .imports = imports,
        };
    }

    fn memoryLen(self: Runtime) usize {
        return self.memory.len;
    }

    fn consumeExecution(self: Runtime, ticks: u64) bool {
        if (ticks == 0 or ticks > self.execution_ticks.*) return false;
        self.execution_ticks.* -= ticks;
        return true;
    }
};

pub const MemoryGrowRequest = struct {
    previous_pages: usize,
    requested_pages: usize,
    previous_bytes: usize,
    requested_bytes: usize,

    pub fn valid(self: MemoryGrowRequest) bool {
        const expected_previous = checkedMul(self.previous_pages, wasm_page_bytes) orelse return false;
        const expected_requested = checkedMul(self.requested_pages, wasm_page_bytes) orelse return false;
        return self.requested_pages >= self.previous_pages and
            self.requested_bytes >= self.previous_bytes and
            self.previous_bytes == expected_previous and
            self.requested_bytes == expected_requested;
    }
};

pub const MemoryGrowAuthority = struct {
    context: ?*anyopaque = null,
    request: *const fn (context: ?*anyopaque, runtime: *Runtime, grow: MemoryGrowRequest) Error!bool,
};

pub const TableGrowRequest = struct {
    previous_entries: usize,
    requested_entries: usize,
    delta_entries: usize,

    pub fn valid(self: TableGrowRequest) bool {
        return self.requested_entries >= self.previous_entries and
            self.delta_entries == self.requested_entries - self.previous_entries;
    }
};

pub const TableGrowAuthority = struct {
    context: ?*anyopaque = null,
    request: *const fn (context: ?*anyopaque, runtime: *Runtime, grow: TableGrowRequest) Error!bool,
};

pub const HostImport = struct {
    module: []const u8,
    name: []const u8,
    kind: HostImportKind = .function,
    context: ?*anyopaque = null,
    call: ?*const fn (context: ?*anyopaque, args: []const Value) Error!ExecutionResult = null,
    memory_min_pages: usize = 0,
    table_min_entries: usize = 0,
    global_value_type: ValueType = .i64,
    global_mutable: bool = false,
    global_value: Value = .{ .i64 = 0 },
};

pub const HostImportKind = enum {
    function,
    memory,
    table,
    global,
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

    fn readF32(self: *Reader) Error!f32 {
        const bytes = try self.readBytes(4);
        return @bitCast(byte_utils.load32(bytes).?);
    }

    fn readF64(self: *Reader) Error!f64 {
        const bytes = try self.readBytes(8);
        return @bitCast(byte_utils.load64(bytes).?);
    }
};

const FuncType = struct {
    params: [max_type_params]ValueType = undefined,
    results: [max_type_results]ValueType = undefined,
    param_count: usize = 0,
    result_count: usize = 0,

    fn noParamsNoResult(self: FuncType) bool {
        return self.param_count == 0 and self.result_count == 0;
    }

    fn supportedWithArgs(self: FuncType, args: []const Value) bool {
        if (self.param_count != args.len or !self.supportedResult()) return false;
        for (args, 0..) |arg, index| {
            if (!valueMatchesType(arg, self.params[index])) return false;
        }
        return true;
    }

    fn supportedParams(self: FuncType) bool {
        for (self.params[0..self.param_count]) |param| {
            if (!supportedValue(param)) return false;
        }
        return true;
    }

    fn supportedResult(self: FuncType) bool {
        if (!self.supportedParams()) return false;
        for (self.results[0..self.result_count]) |result| {
            if (!supportedValue(result)) return false;
        }
        return true;
    }

    fn eql(self: FuncType, other: FuncType) bool {
        if (self.param_count != other.param_count or self.result_count != other.result_count) return false;
        var index: usize = 0;
        while (index < self.param_count) : (index += 1) {
            if (self.params[index] != other.params[index]) return false;
        }
        index = 0;
        while (index < self.result_count) : (index += 1) {
            if (self.results[index] != other.results[index]) return false;
        }
        return true;
    }
};

fn supportedValue(value_type: ValueType) bool {
    return switch (value_type) {
        .i32, .i64, .f32, .f64, .funcref => true,
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

const ImportedFunction = struct {
    module: []const u8 = &.{},
    name: []const u8 = &.{},
    type_index: usize = 0,

    fn matches(self: ImportedFunction, host: HostImport) bool {
        return byte_utils.eql(self.module, host.module) and byte_utils.eql(self.name, host.name);
    }
};

const ImportedMemory = struct {
    module: []const u8 = &.{},
    name: []const u8 = &.{},
    min_pages: usize = 0,

    fn matches(self: ImportedMemory, host: HostImport) bool {
        return host.kind == .memory and
            byte_utils.eql(self.module, host.module) and
            byte_utils.eql(self.name, host.name);
    }
};

const ImportedTable = struct {
    module: []const u8 = &.{},
    name: []const u8 = &.{},
    min_entries: usize = 0,

    fn matches(self: ImportedTable, host: HostImport) bool {
        return host.kind == .table and
            byte_utils.eql(self.module, host.module) and
            byte_utils.eql(self.name, host.name);
    }
};

const ImportedGlobal = struct {
    module: []const u8 = &.{},
    name: []const u8 = &.{},
    global_index: usize = 0,

    fn matches(self: ImportedGlobal, host: HostImport) bool {
        return host.kind == .global and
            byte_utils.eql(self.module, host.module) and
            byte_utils.eql(self.name, host.name);
    }
};

const Export = struct {
    name: []const u8 = &.{},
    kind: ExternalKind = .function,
    index: usize = 0,

    fn matches(self: Export, name: []const u8) bool {
        return byte_utils.eql(self.name, name);
    }
};

const DataSegment = struct {
    offset: usize = 0,
    bytes: []const u8 = &.{},
    active: bool = false,
    dropped: bool = false,
};

const ElementSegment = struct {
    entries: [max_table_entries]usize = undefined,
    count: usize = 0,
    passive: bool = false,
    dropped: bool = false,
};

const Global = struct {
    value_type: ValueType = .i64,
    mutable: bool = false,
    value: Value = .{ .i64 = 0 },
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

const FloatBinaryOp = enum {
    add,
    sub,
    mul,
    div,
};

const FloatUnaryOp = enum {
    abs,
    neg,
    sqrt,
};

const FloatComparison = enum {
    eq,
    ne,
    lt,
    gt,
    le,
    ge,
};

const MemoryLoad = enum {
    i32,
    i64,
    f32,
    f64,
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
    f32,
    f64,
    i32_8,
    i32_16,
    i64_8,
    i64_16,
    i64_32,
};

const Module = struct {
    types: [max_types]FuncType = undefined,
    type_count: usize = 0,
    imports: [max_imports]ImportedFunction = undefined,
    import_count: usize = 0,
    imported_globals: [max_globals]ImportedGlobal = undefined,
    imported_global_count: usize = 0,
    functions: [max_functions]Function = undefined,
    function_count: usize = 0,
    code: [max_functions]Code = undefined,
    code_count: usize = 0,
    exports: [max_functions]Export = undefined,
    export_count: usize = 0,
    globals: [max_globals]Global = undefined,
    global_count: usize = 0,
    table_entries: [max_table_entries]?usize = [_]?usize{null} ** max_table_entries,
    table_min_entries: usize = 0,
    has_table: bool = false,
    element_segments: [max_data_segments]ElementSegment = undefined,
    element_segment_count: usize = 0,
    data_segments: [max_data_segments]DataSegment = undefined,
    data_segment_count: usize = 0,
    declared_data_count: ?usize = null,
    imported_memory: ?ImportedMemory = null,
    imported_table: ?ImportedTable = null,
    memory_min_pages: usize = 0,
    has_memory: bool = false,
    start_function_index: ?usize = null,

    fn parse(bytes: []const u8) Error!Module {
        var reader = Reader{ .bytes = bytes };
        if (!byte_utils.eql(try reader.readBytes(wasm_magic.len), &wasm_magic)) return error.Corrupt;
        if (!byte_utils.eql(try reader.readBytes(wasm_version.len), &wasm_version)) return error.Corrupt;

        var module = Module{};
        var previous_section_order: u8 = 0;
        while (!reader.done()) {
            const section_id_raw = try reader.readByte();
            const section_size = try reader.readU32Leb();
            const payload = try reader.readBytes(section_size);
            if (section_id_raw == 0) continue;
            const section = sectionFromByte(section_id_raw) orelse return error.Unsupported;
            const current_section_order = sectionOrder(section);
            if (current_section_order <= previous_section_order) return error.Corrupt;
            previous_section_order = current_section_order;
            var section_reader = Reader{ .bytes = payload };
            switch (section) {
                .type => try module.parseTypeSection(&section_reader),
                .import => try module.parseImportSection(&section_reader),
                .function => try module.parseFunctionSection(&section_reader),
                .table => try module.parseTableSection(&section_reader),
                .memory => try module.parseMemorySection(&section_reader),
                .global => try module.parseGlobalSection(&section_reader),
                .@"export" => try module.parseExportSection(&section_reader),
                .start => try module.parseStartSection(&section_reader),
                .element => try module.parseElementSection(&section_reader),
                .data_count => try module.parseDataCountSection(&section_reader),
                .code => try module.parseCodeSection(&section_reader),
                .data => try module.parseDataSection(&section_reader),
            }
            if (!section_reader.done()) return error.Corrupt;
        }
        if (module.function_count != module.code_count) return error.Corrupt;
        if (module.declared_data_count) |declared| {
            if (declared != module.data_segment_count) return error.Corrupt;
        }
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
            if (result_count > max_type_results) return error.Unsupported;
            func_type.result_count = result_count;
            for (func_type.results[0..result_count]) |*result| {
                result.* = try readValueType(reader);
            }
        }
    }

    fn parseFunctionSection(self: *Module, reader: *Reader) Error!void {
        const count = try reader.readU32Leb();
        if (count > max_functions) return error.Unsupported;
        if (self.import_count + count > max_functions) return error.Unsupported;
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

    fn parseImportSection(self: *Module, reader: *Reader) Error!void {
        const count = try reader.readU32Leb();
        if (count > max_imports) return error.Unsupported;
        var import_index: usize = 0;
        while (import_index < count) : (import_index += 1) {
            const module_len = try reader.readU32Leb();
            if (module_len == 0 or module_len > max_import_name) return error.Unsupported;
            const module_name = try reader.readBytes(module_len);
            const name_len = try reader.readU32Leb();
            if (name_len == 0 or name_len > max_import_name) return error.Unsupported;
            const import_name = try reader.readBytes(name_len);
            const kind = externalKindFromByte(try reader.readByte()) orelse return error.Unsupported;
            switch (kind) {
                .function => {
                    if (self.import_count >= max_imports) return error.Unsupported;
                    const type_index = try reader.readU32Leb();
                    if (type_index >= self.type_count) return error.Corrupt;
                    const imported = &self.imports[self.import_count];
                    imported.* = .{
                        .module_len = module_len,
                        .name_len = name_len,
                        .type_index = type_index,
                    };
                    @memcpy(imported.module[0..module_len], module_name);
                    @memcpy(imported.name[0..name_len], import_name);
                    self.import_count += 1;
                },
                .memory => try self.parseMemoryImport(reader, module_name, import_name),
                .global => try self.parseGlobalImport(reader, module_name, import_name),
                .table => try self.parseTableImport(reader, module_name, import_name),
            }
        }
    }

    fn parseMemoryImport(self: *Module, reader: *Reader, module_name: []const u8, import_name: []const u8) Error!void {
        if (self.imported_memory != null or self.has_memory) return error.Unsupported;
        const min_pages = try readMemoryMinimumPages(reader);
        var imported = ImportedMemory{
            .module_len = module_name.len,
            .name_len = import_name.len,
            .min_pages = min_pages,
        };
        @memcpy(imported.module[0..module_name.len], module_name);
        @memcpy(imported.name[0..import_name.len], import_name);
        self.imported_memory = imported;
        self.has_memory = true;
        self.memory_min_pages = min_pages;
    }

    fn parseTableImport(self: *Module, reader: *Reader, module_name: []const u8, import_name: []const u8) Error!void {
        if (self.imported_table != null or self.has_table) return error.Unsupported;
        const ref_type = try reader.readByte();
        if (ref_type != wasm_funcref_type) return error.Unsupported;
        const min_entries = try readTableMinimumEntries(reader);
        if (min_entries > max_table_entries) return error.Unsupported;
        var imported = ImportedTable{
            .module_len = module_name.len,
            .name_len = import_name.len,
            .min_entries = min_entries,
        };
        @memcpy(imported.module[0..module_name.len], module_name);
        @memcpy(imported.name[0..import_name.len], import_name);
        self.imported_table = imported;
        self.has_table = true;
        self.table_min_entries = min_entries;
    }

    fn parseTableSection(self: *Module, reader: *Reader) Error!void {
        const count = try reader.readU32Leb();
        if (count > 1) return error.Unsupported;
        if (count == 0) return;
        if (self.imported_table != null) return error.Corrupt;
        const ref_type = try reader.readByte();
        if (ref_type != wasm_funcref_type) return error.Unsupported;
        const min_entries = try readTableMinimumEntries(reader);
        if (min_entries > max_table_entries) return error.Unsupported;
        self.has_table = true;
        self.table_min_entries = min_entries;
    }

    fn parseGlobalImport(self: *Module, reader: *Reader, module_name: []const u8, import_name: []const u8) Error!void {
        if (self.global_count >= max_globals or self.imported_global_count >= max_globals) return error.Unsupported;
        const value_type = try readValueType(reader);
        if (!supportedValue(value_type)) return error.Unsupported;
        const mutability = try reader.readByte();
        if (mutability > 1) return error.Corrupt;
        const global_index = self.global_count;
        self.globals[global_index] = .{
            .value_type = value_type,
            .mutable = mutability == 1,
        };
        var imported = ImportedGlobal{
            .module_len = module_name.len,
            .name_len = import_name.len,
            .global_index = global_index,
        };
        @memcpy(imported.module[0..module_name.len], module_name);
        @memcpy(imported.name[0..import_name.len], import_name);
        self.imported_globals[self.imported_global_count] = imported;
        self.imported_global_count += 1;
        self.global_count += 1;
    }

    fn parseMemorySection(self: *Module, reader: *Reader) Error!void {
        const count = try reader.readU32Leb();
        if (count > 1) return error.Unsupported;
        if (count == 0) return;
        if (self.imported_memory != null) return error.Corrupt;
        self.memory_min_pages = try readMemoryMinimumPages(reader);
        self.has_memory = true;
    }

    fn parseGlobalSection(self: *Module, reader: *Reader) Error!void {
        const count = try reader.readU32Leb();
        if (self.global_count + count > max_globals) return error.Unsupported;
        const base = self.global_count;
        self.global_count += count;
        for (self.globals[base..self.global_count]) |*global| {
            const value_type = try readValueType(reader);
            if (!supportedValue(value_type)) return error.Unsupported;
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
                .function => if (index >= self.totalFunctionCount()) return error.Corrupt,
                .memory => if (index != 0 or !self.has_memory) return error.Corrupt,
                .table => if (index != 0 or !self.has_table) return error.Corrupt,
                .global => if (index >= self.global_count) return error.Corrupt,
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
        const function_type = self.types[try self.typeIndexForFunction(index)];
        if (!function_type.noParamsNoResult()) return error.Unsupported;
        self.start_function_index = index;
    }

    fn parseCodeSection(self: *Module, reader: *Reader) Error!void {
        const count = try reader.readU32Leb();
        if (count != self.function_count or count > max_functions) return error.Corrupt;
        self.code_count = count;
        for (self.code[0..count]) |*code| {
            const body_size = try reader.readU32Leb();
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
            switch (mode) {
                0 => {
                    const offset = try readConstantI32Expression(reader);
                    if (offset < 0) return error.NoMemory;
                    const byte_count = try reader.readU32Leb();
                    segment.* = .{
                        .offset = @intCast(offset),
                        .bytes = try reader.readBytes(byte_count),
                        .active = true,
                    };
                },
                1 => {
                    const byte_count = try reader.readU32Leb();
                    segment.* = .{
                        .bytes = try reader.readBytes(byte_count),
                        .active = false,
                    };
                },
                2 => {
                    const memory_index = try reader.readU32Leb();
                    if (memory_index != 0) return error.Unsupported;
                    const offset = try readConstantI32Expression(reader);
                    if (offset < 0) return error.NoMemory;
                    const byte_count = try reader.readU32Leb();
                    segment.* = .{
                        .offset = @intCast(offset),
                        .bytes = try reader.readBytes(byte_count),
                        .active = true,
                    };
                },
                else => return error.Unsupported,
            }
        }
    }

    fn parseDataCountSection(self: *Module, reader: *Reader) Error!void {
        const count = try reader.readU32Leb();
        if (count > max_data_segments) return error.Unsupported;
        self.declared_data_count = count;
    }

    fn parseElementSection(self: *Module, reader: *Reader) Error!void {
        const count = try reader.readU32Leb();
        if (count > max_data_segments) return error.Unsupported;
        self.element_segment_count = count;
        for (self.element_segments[0..count]) |*segment| {
            segment.* = .{};
        }
        var segment_index: usize = 0;
        while (segment_index < count) : (segment_index += 1) {
            const mode = try reader.readU32Leb();
            switch (mode) {
                0 => try self.parseActiveFunctionElements(reader, 0, .function_index_vector),
                1 => try self.parsePassiveFunctionElements(reader, segment_index, .element_kind),
                2 => {
                    const table_index = try reader.readU32Leb();
                    try self.parseActiveFunctionElements(reader, table_index, .element_kind);
                },
                3 => try self.skipPassiveFunctionElements(reader, .element_kind),
                4 => try self.parseActiveFunctionElements(reader, 0, .ref_func_expression_vector),
                5 => try self.parsePassiveFunctionElements(reader, segment_index, .ref_func_expression_vector),
                6 => {
                    const table_index = try reader.readU32Leb();
                    try self.parseActiveFunctionElements(reader, table_index, .ref_func_expression_vector);
                },
                7 => try self.skipPassiveFunctionElements(reader, .ref_func_expression_vector),
                else => return error.Unsupported,
            }
        }
    }

    const ElementPayload = enum {
        function_index_vector,
        element_kind,
        ref_func_expression_vector,
    };

    fn parseActiveFunctionElements(self: *Module, reader: *Reader, table_index: u32, payload: ElementPayload) Error!void {
        if (table_index != 0 or self.table_min_entries == 0) return error.Corrupt;
        const offset = try readConstantI32Expression(reader);
        if (offset < 0) return error.Corrupt;
        const base: usize = @intCast(offset);
        const function_count = try readElementFunctionCount(reader, payload);
        const end = checkedAdd(base, function_count) orelse return error.Corrupt;
        if (end > self.table_min_entries or end > max_table_entries) return error.Corrupt;
        var function_index: usize = 0;
        while (function_index < function_count) : (function_index += 1) {
            const function_ref = switch (payload) {
                .function_index_vector, .element_kind => try reader.readU32Leb(),
                .ref_func_expression_vector => try readRefFuncExpression(reader),
            };
            if (function_ref >= self.totalFunctionCount()) return error.Corrupt;
            self.table_entries[base + function_index] = function_ref;
        }
    }

    fn parsePassiveFunctionElements(self: *Module, reader: *Reader, segment_index: usize, payload: ElementPayload) Error!void {
        const function_count = try readElementFunctionCount(reader, payload);
        const segment = &self.element_segments[segment_index];
        segment.passive = true;
        segment.count = function_count;
        var function_index: usize = 0;
        while (function_index < function_count) : (function_index += 1) {
            const function_ref = switch (payload) {
                .function_index_vector,
                .element_kind,
                => try reader.readU32Leb(),
                .ref_func_expression_vector => try readRefFuncExpression(reader),
            };
            if (function_ref >= self.totalFunctionCount()) return error.Corrupt;
            segment.entries[function_index] = function_ref;
        }
    }

    fn skipPassiveFunctionElements(self: *Module, reader: *Reader, payload: ElementPayload) Error!void {
        const function_count = try readElementFunctionCount(reader, payload);
        var function_index: usize = 0;
        while (function_index < function_count) : (function_index += 1) {
            const function_ref = switch (payload) {
                .function_index_vector, .element_kind => try reader.readU32Leb(),
                .ref_func_expression_vector => try readRefFuncExpression(reader),
            };
            if (function_ref >= self.totalFunctionCount()) return error.Corrupt;
        }
    }

    fn findExport(self: Module, name: []const u8) Error!usize {
        for (self.exports[0..self.export_count]) |exp| {
            if (exp.kind == .function and exp.matches(name)) return exp.index;
        }
        return error.MissingExport;
    }

    fn totalFunctionCount(self: Module) usize {
        return self.import_count + self.function_count;
    }

    fn typeIndexForFunction(self: Module, function_index: usize) Error!usize {
        if (function_index < self.import_count) return self.imports[function_index].type_index;
        const defined_index = function_index - self.import_count;
        if (defined_index >= self.function_count) return error.Corrupt;
        return self.functions[defined_index].type_index;
    }

    fn codeIndexForFunction(self: Module, function_index: usize) Error!usize {
        if (function_index < self.import_count) return error.MissingImport;
        const defined_index = function_index - self.import_count;
        if (defined_index >= self.function_count) return error.Corrupt;
        return self.functions[defined_index].code_index;
    }

    fn requiredMemoryBytes(self: Module) Error!usize {
        return checkedMul(self.memory_min_pages, wasm_page_bytes) orelse error.Unsupported;
    }

    fn resolveImports(self: *Module, runtime: Runtime) Error!void {
        for (self.imports[0..self.import_count]) |imported| {
            for (runtime.imports) |host| {
                if (host.kind == .function and imported.matches(host)) break;
            } else return error.MissingImport;
        }
        if (self.imported_memory) |imported| {
            for (runtime.imports) |host| {
                if (!imported.matches(host)) continue;
                try validateImportedMemory(imported, host);
                return;
            }
            return error.MissingImport;
        }
        if (self.imported_table) |imported| {
            for (runtime.imports) |host| {
                if (!imported.matches(host)) continue;
                try validateImportedTable(imported, host);
                return;
            }
            return error.MissingImport;
        }
        for (self.imported_globals[0..self.imported_global_count]) |imported| {
            for (runtime.imports) |host| {
                if (!imported.matches(host)) continue;
                try self.resolveImportedGlobal(imported, host);
                break;
            } else return error.MissingImport;
        }
    }

    fn resolveImportedGlobal(self: *Module, imported: ImportedGlobal, host: HostImport) Error!void {
        const global = &self.globals[imported.global_index];
        if (global.value_type != host.global_value_type or global.mutable != host.global_mutable) return error.Corrupt;
        if (!valueMatchesType(host.global_value, global.value_type)) return error.Corrupt;
        global.value = host.global_value;
    }

    fn applyDataSegments(self: Module, runtime: *Runtime) Error!void {
        const limit = try self.requiredMemoryBytes();
        for (self.data_segments[0..self.data_segment_count]) |segment| {
            if (!segment.active) continue;
            const end = checkedAdd(segment.offset, segment.bytes.len) orelse return error.NoMemory;
            if (end > limit or end > runtime.memory.len) return error.NoMemory;
            @memcpy(runtime.memory[segment.offset..end], segment.bytes);
        }
    }
};

const Executor = struct {
    runtime: *Runtime,
    module: Module,
    memory_pages: usize,

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
        locals: [max_locals]Value = undefined,
        stack: [max_stack]Value = undefined,
        stack_len: usize = 0,

        fn init(function_type: FuncType, code: Code, args: []const Value) Error!Frame {
            if (args.len != function_type.param_count) return error.Corrupt;
            if (function_type.param_count + code.local_count > max_locals) return error.Unsupported;
            var frame = Frame{};
            for (args, 0..) |arg, index| {
                if (!valueMatchesType(arg, function_type.params[index])) return error.Corrupt;
                frame.locals[index] = arg;
            }
            var local_index: usize = 0;
            while (local_index < code.local_count) : (local_index += 1) {
                frame.locals[function_type.param_count + local_index] = try Value.zero(code.local_types[local_index]);
            }
            return frame;
        }

        fn push(self: *Frame, value: Value) Error!void {
            if (self.stack_len >= max_stack) return error.StackOverflow;
            self.stack[self.stack_len] = value;
            self.stack_len += 1;
        }

        fn pop(self: *Frame) Error!Value {
            if (self.stack_len == 0) return error.StackUnderflow;
            self.stack_len -= 1;
            return self.stack[self.stack_len];
        }

        fn pushI32(self: *Frame, value: i32) Error!void {
            try self.push(.{ .i32 = value });
        }

        fn pushI64(self: *Frame, value: i64) Error!void {
            try self.push(.{ .i64 = value });
        }

        fn popI32(self: *Frame) Error!i32 {
            return (try self.pop()).asI32();
        }

        fn popI64(self: *Frame) Error!i64 {
            return (try self.pop()).asI64();
        }

        fn popF32(self: *Frame) Error!f32 {
            return (try self.pop()).asF32();
        }

        fn popF64(self: *Frame) Error!f64 {
            return (try self.pop()).asF64();
        }

        fn popFuncref(self: *Frame) Error!?usize {
            return (try self.pop()).asFuncref();
        }
    };

    fn runExport(self: *Executor, name: []const u8, args: []const Value) Error!ExecutionResult {
        const function_index = try self.module.findExport(name);
        const function_type = self.module.types[try self.module.typeIndexForFunction(function_index)];
        if (!function_type.supportedWithArgs(args)) return error.Unsupported;
        return try self.runFunction(function_index, 0, args);
    }

    fn runStart(self: *Executor) Error!void {
        if (self.module.start_function_index) |function_index| {
            const result = try self.runFunction(function_index, 0, &.{});
            if (result.count != 0) return error.Corrupt;
        }
    }

    fn runFunction(self: *Executor, function_index: usize, depth: usize, args: []const Value) Error!ExecutionResult {
        if (depth >= max_call_depth) return error.Unsupported;
        if (function_index < self.module.import_count) return try self.runImportedFunction(function_index, args);
        if (function_index >= self.module.totalFunctionCount()) return error.Corrupt;
        const function_type = self.module.types[try self.module.typeIndexForFunction(function_index)];
        if (!function_type.supportedResult()) return error.Unsupported;
        const code = self.module.code[try self.module.codeIndexForFunction(function_index)];
        var frame = try Frame.init(function_type, code, args);
        const local_limit = function_type.param_count + code.local_count;
        var controls: [max_control_depth]ControlFrame = undefined;
        var control_len: usize = 0;

        var reader = Reader{ .bytes = code.body };
        while (!reader.done()) {
            if (!self.runtime.consumeExecution(1)) return error.NoExecution;
            const opcode_byte = try reader.readByte();
            if (opcode_byte == wasm_extended_prefix) {
                try self.executeExtendedOpcode(&frame, &reader);
                continue;
            }
            const opcode = opcodeFromByte(opcode_byte) orelse return error.Unsupported;
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
                    try readBlockType(&reader);
                    try pushControl(&controls, &control_len, .block, reader.offset);
                },
                .loop => {
                    try readBlockType(&reader);
                    try pushControl(&controls, &control_len, .loop, reader.offset);
                },
                .@"if" => {
                    try readBlockType(&reader);
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
                .br_table => {
                    const target_count = try reader.readU32Leb();
                    const selector = @as(u32, @bitCast(try frame.popI32()));
                    var selected_target: ?u32 = null;
                    var target_index: u32 = 0;
                    while (target_index < target_count) : (target_index += 1) {
                        const target = try reader.readU32Leb();
                        if (target_index == selector) selected_target = target;
                    }
                    const default_target = try reader.readU32Leb();
                    try branchToControl(&reader, &controls, &control_len, selected_target orelse default_target);
                },
                .i64_const => try frame.pushI64(try reader.readI64Leb()),
                .i32_const => try frame.pushI32(try reader.readI32Leb()),
                .f32_const => try frame.push(.{ .f32 = try reader.readF32() }),
                .f64_const => try frame.push(.{ .f64 = try reader.readF64() }),
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
                    const value = try frame.popI64();
                    try frame.pushI32(if (value == 0) 1 else 0);
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
                .f32_eq => try pushF32Comparison(&frame, .eq),
                .f32_ne => try pushF32Comparison(&frame, .ne),
                .f32_lt => try pushF32Comparison(&frame, .lt),
                .f32_gt => try pushF32Comparison(&frame, .gt),
                .f32_le => try pushF32Comparison(&frame, .le),
                .f32_ge => try pushF32Comparison(&frame, .ge),
                .f64_eq => try pushF64Comparison(&frame, .eq),
                .f64_ne => try pushF64Comparison(&frame, .ne),
                .f64_lt => try pushF64Comparison(&frame, .lt),
                .f64_gt => try pushF64Comparison(&frame, .gt),
                .f64_le => try pushF64Comparison(&frame, .le),
                .f64_ge => try pushF64Comparison(&frame, .ge),
                .i32_eqz => {
                    const value = try frame.popI32();
                    try frame.pushI32(if (value == 0) 1 else 0);
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
                .f32_abs => try pushF32Unary(&frame, .abs),
                .f32_neg => try pushF32Unary(&frame, .neg),
                .f32_sqrt => try pushF32Unary(&frame, .sqrt),
                .f32_add => try pushF32Binary(&frame, .add),
                .f32_sub => try pushF32Binary(&frame, .sub),
                .f32_mul => try pushF32Binary(&frame, .mul),
                .f32_div => try pushF32Binary(&frame, .div),
                .f64_abs => try pushF64Unary(&frame, .abs),
                .f64_neg => try pushF64Unary(&frame, .neg),
                .f64_sqrt => try pushF64Unary(&frame, .sqrt),
                .f64_add => try pushF64Binary(&frame, .add),
                .f64_sub => try pushF64Binary(&frame, .sub),
                .f64_mul => try pushF64Binary(&frame, .mul),
                .f64_div => try pushF64Binary(&frame, .div),
                .i32_wrap_i64 => {
                    const value = try frame.popI64();
                    try frame.pushI32(@bitCast(@as(u32, @truncate(@as(u64, @bitCast(value))))));
                },
                .i32_trunc_f32_s => try frame.pushI32(try truncF32ToI32(try frame.popF32())),
                .i32_trunc_f32_u => try frame.pushI32(@bitCast(try truncF32ToU32(try frame.popF32()))),
                .i32_trunc_f64_s => try frame.pushI32(try truncF64ToI32(try frame.popF64())),
                .i32_trunc_f64_u => try frame.pushI32(@bitCast(try truncF64ToU32(try frame.popF64()))),
                .i64_extend_i32_s => {
                    const value = try frame.popI32();
                    try frame.pushI64(value);
                },
                .i64_extend_i32_u => {
                    const value: u32 = @bitCast(try frame.popI32());
                    try frame.pushI64(@intCast(value));
                },
                .i64_trunc_f32_s => try frame.pushI64(try truncF32ToI64(try frame.popF32())),
                .i64_trunc_f32_u => try frame.pushI64(@bitCast(try truncF32ToU64(try frame.popF32()))),
                .i64_trunc_f64_s => try frame.pushI64(try truncF64ToI64(try frame.popF64())),
                .i64_trunc_f64_u => try frame.pushI64(@bitCast(try truncF64ToU64(try frame.popF64()))),
                .f32_convert_i32_s => try frame.push(.{ .f32 = @floatFromInt(try frame.popI32()) }),
                .f32_convert_i32_u => try frame.push(.{ .f32 = @floatFromInt(@as(u32, @bitCast(try frame.popI32()))) }),
                .f32_convert_i64_s => try frame.push(.{ .f32 = @floatFromInt(try frame.popI64()) }),
                .f32_convert_i64_u => try frame.push(.{ .f32 = @floatFromInt(@as(u64, @bitCast(try frame.popI64()))) }),
                .f32_demote_f64 => try frame.push(.{ .f32 = @floatCast(try frame.popF64()) }),
                .f64_convert_i32_s => try frame.push(.{ .f64 = @floatFromInt(try frame.popI32()) }),
                .f64_convert_i32_u => try frame.push(.{ .f64 = @floatFromInt(@as(u32, @bitCast(try frame.popI32()))) }),
                .f64_convert_i64_s => try frame.push(.{ .f64 = @floatFromInt(try frame.popI64()) }),
                .f64_convert_i64_u => try frame.push(.{ .f64 = @floatFromInt(@as(u64, @bitCast(try frame.popI64()))) }),
                .f64_promote_f32 => try frame.push(.{ .f64 = @floatCast(try frame.popF32()) }),
                .i32_reinterpret_f32 => try frame.pushI32(@bitCast(try frame.popF32())),
                .i64_reinterpret_f64 => try frame.pushI64(@bitCast(try frame.popF64())),
                .f32_reinterpret_i32 => try frame.push(.{ .f32 = @bitCast(try frame.popI32()) }),
                .f64_reinterpret_i64 => try frame.push(.{ .f64 = @bitCast(try frame.popI64()) }),
                .i32_extend8_s => {
                    const value: i8 = @truncate(try frame.popI32());
                    try frame.pushI32(value);
                },
                .i32_extend16_s => {
                    const value: i16 = @truncate(try frame.popI32());
                    try frame.pushI32(value);
                },
                .i64_extend8_s => {
                    const value: i8 = @truncate(try frame.popI64());
                    try frame.pushI64(value);
                },
                .i64_extend16_s => {
                    const value: i16 = @truncate(try frame.popI64());
                    try frame.pushI64(value);
                },
                .i64_extend32_s => {
                    const value: i32 = @truncate(try frame.popI64());
                    try frame.pushI64(value);
                },
                .ref_null => {
                    const ref_type = try reader.readByte();
                    if (ref_type != wasm_funcref_type) return error.Unsupported;
                    try frame.push(.{ .funcref = null });
                },
                .ref_is_null => try frame.pushI32(if ((try frame.popFuncref()) == null) 1 else 0),
                .ref_func => {
                    const function_ref = try reader.readU32Leb();
                    if (function_ref >= self.module.totalFunctionCount()) return error.Corrupt;
                    try frame.push(.{ .funcref = function_ref });
                },
                .drop => _ = try frame.pop(),
                .select => {
                    const condition = try frame.popI32();
                    const false_value = try frame.pop();
                    const true_value = try frame.pop();
                    try frame.push(if (condition != 0) true_value else false_value);
                },
                .select_typed => {
                    const value_type = try readSelectType(&reader);
                    const condition = try frame.popI32();
                    const false_value = try popTypedValue(&frame, value_type);
                    const true_value = try popTypedValue(&frame, value_type);
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
                    global.value = try popTypedValue(&frame, global.value_type);
                },
                .table_get => try self.tableGet(&frame, &reader),
                .table_set => try self.tableSet(&frame, &reader),
                .i32_load => try self.loadMemory(&frame, &reader, .i32),
                .i64_load => try self.loadMemory(&frame, &reader, .i64),
                .f32_load => try self.loadMemory(&frame, &reader, .f32),
                .f64_load => try self.loadMemory(&frame, &reader, .f64),
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
                .f32_store => try self.storeMemory(&frame, &reader, .f32),
                .f64_store => try self.storeMemory(&frame, &reader, .f64),
                .i32_store8 => try self.storeMemory(&frame, &reader, .i32_8),
                .i32_store16 => try self.storeMemory(&frame, &reader, .i32_16),
                .i64_store8 => try self.storeMemory(&frame, &reader, .i64_8),
                .i64_store16 => try self.storeMemory(&frame, &reader, .i64_16),
                .i64_store32 => try self.storeMemory(&frame, &reader, .i64_32),
                .memory_size => try self.memorySize(&frame, &reader),
                .memory_grow => try self.memoryGrow(&frame, &reader),
                .call => {
                    const callee = try reader.readU32Leb();
                    const callee_type = self.module.types[try self.module.typeIndexForFunction(callee)];
                    const result = try self.callFunctionFromFrame(&frame, callee, depth);
                    try pushFunctionResult(&frame, callee_type, result);
                },
                .call_indirect => {
                    const type_index = try reader.readU32Leb();
                    if (type_index >= self.module.type_count) return error.Corrupt;
                    const table_index = try reader.readU32Leb();
                    const result = try self.callIndirectFromFrame(&frame, type_index, table_index, depth);
                    try pushFunctionResult(&frame, self.module.types[type_index], result);
                },
            }
        }
        return error.Corrupt;
    }

    fn executeExtendedOpcode(self: *Executor, frame: *Frame, reader: *Reader) Error!void {
        const opcode = try reader.readU32Leb();
        switch (opcode) {
            ext_i32_trunc_sat_f32_s => try frame.pushI32(saturatingTruncF32ToI32(try frame.popF32())),
            ext_i32_trunc_sat_f32_u => try frame.pushI32(@bitCast(saturatingTruncF32ToU32(try frame.popF32()))),
            ext_i32_trunc_sat_f64_s => try frame.pushI32(saturatingTruncF64ToI32(try frame.popF64())),
            ext_i32_trunc_sat_f64_u => try frame.pushI32(@bitCast(saturatingTruncF64ToU32(try frame.popF64()))),
            ext_i64_trunc_sat_f32_s => try frame.pushI64(saturatingTruncF32ToI64(try frame.popF32())),
            ext_i64_trunc_sat_f32_u => try frame.pushI64(@bitCast(saturatingTruncF32ToU64(try frame.popF32()))),
            ext_i64_trunc_sat_f64_s => try frame.pushI64(saturatingTruncF64ToI64(try frame.popF64())),
            ext_i64_trunc_sat_f64_u => try frame.pushI64(@bitCast(saturatingTruncF64ToU64(try frame.popF64()))),
            ext_memory_init => try self.memoryInit(frame, reader),
            ext_data_drop => try self.dataDrop(reader),
            ext_memory_copy => try self.memoryCopy(frame, reader),
            ext_memory_fill => try self.memoryFill(frame, reader),
            ext_table_init => try self.tableInit(frame, reader),
            ext_elem_drop => try self.elemDrop(reader),
            ext_table_copy => try self.tableCopy(frame, reader),
            ext_table_grow => try self.tableGrow(frame, reader),
            ext_table_size => try self.tableSize(frame, reader),
            ext_table_fill => try self.tableFill(frame, reader),
            else => return error.Unsupported,
        }
    }

    fn callIndirectFromFrame(self: *Executor, frame: *Frame, type_index: usize, table_index: u32, depth: usize) Error!ExecutionResult {
        if (table_index != 0) return error.Unsupported;
        const table_offset = try frame.popI32();
        if (table_offset < 0) return error.Trap;
        const table_entry: usize = @intCast(table_offset);
        if (table_entry >= self.module.table_min_entries) return error.Trap;
        const function_index = self.module.table_entries[table_entry] orelse return error.Trap;
        const expected_type = self.module.types[type_index];
        const actual_type = self.module.types[try self.module.typeIndexForFunction(function_index)];
        if (!actual_type.eql(expected_type)) return error.Trap;
        return try self.callFunctionFromFrame(frame, function_index, depth);
    }

    fn tableGet(self: *Executor, frame: *Frame, reader: *Reader) Error!void {
        try readTableIndex(reader);
        const table_offset = try frame.popI32();
        if (table_offset < 0) return error.Trap;
        const table_entry: usize = @intCast(table_offset);
        if (table_entry >= self.module.table_min_entries) return error.Trap;
        try frame.push(.{ .funcref = self.module.table_entries[table_entry] });
    }

    fn tableSet(self: *Executor, frame: *Frame, reader: *Reader) Error!void {
        try readTableIndex(reader);
        const function_ref = try frame.popFuncref();
        const table_offset = try frame.popI32();
        if (table_offset < 0) return error.Trap;
        const table_entry: usize = @intCast(table_offset);
        if (table_entry >= self.module.table_min_entries) return error.Trap;
        if (function_ref) |index| {
            if (index >= self.module.totalFunctionCount()) return error.Corrupt;
        }
        self.module.table_entries[table_entry] = function_ref;
    }

    fn callFunctionFromFrame(self: *Executor, frame: *Frame, function_index: usize, depth: usize) Error!ExecutionResult {
        if (function_index >= self.module.totalFunctionCount()) return error.Corrupt;
        const function_type = self.module.types[try self.module.typeIndexForFunction(function_index)];
        if (!function_type.supportedResult()) return error.Unsupported;
        var args: [max_type_params]Value = undefined;
        var remaining = function_type.param_count;
        while (remaining > 0) {
            remaining -= 1;
            args[remaining] = try popTypedValue(frame, function_type.params[remaining]);
        }
        return try self.runFunction(function_index, depth + 1, args[0..function_type.param_count]);
    }

    fn runImportedFunction(self: *Executor, function_index: usize, args: []const Value) Error!ExecutionResult {
        const imported = self.module.imports[function_index];
        const function_type = self.module.types[imported.type_index];
        if (!function_type.supportedWithArgs(args)) return error.Unsupported;
        for (self.runtime.imports) |host| {
            if (host.kind != .function) continue;
            if (!imported.matches(host)) continue;
            const call = host.call orelse return error.Corrupt;
            const result = try call(host.context, args);
            if (!resultMatchesType(result, function_type)) return error.Corrupt;
            return result;
        }
        return error.MissingImport;
    }

    fn loadMemory(self: *Executor, frame: *Frame, reader: *Reader, kind: MemoryLoad) Error!void {
        const offset = try readMemoryImmediate(reader);
        const address = try popAddress(frame, offset);
        const size = memoryLoadSize(kind);
        const range = try self.memoryRange(address, size);
        switch (kind) {
            .i32 => try frame.pushI32(@bitCast(byte_utils.load32(range).?)),
            .i64 => try frame.pushI64(@bitCast(byte_utils.load64(range).?)),
            .f32 => try frame.push(.{ .f32 = @bitCast(byte_utils.load32(range).?) }),
            .f64 => try frame.push(.{ .f64 = @bitCast(byte_utils.load64(range).?) }),
            .i32_8_s => try frame.pushI32(@as(i8, @bitCast(range[0]))),
            .i32_8_u => try frame.pushI32(range[0]),
            .i32_16_s => try frame.pushI32(@as(i16, @bitCast(byte_utils.load16(range).?))),
            .i32_16_u => try frame.pushI32(@intCast(byte_utils.load16(range).?)),
            .i64_8_s => try frame.pushI64(@as(i8, @bitCast(range[0]))),
            .i64_8_u => try frame.pushI64(range[0]),
            .i64_16_s => try frame.pushI64(@as(i16, @bitCast(byte_utils.load16(range).?))),
            .i64_16_u => try frame.pushI64(byte_utils.load16(range).?),
            .i64_32_s => try frame.pushI64(@as(i32, @bitCast(byte_utils.load32(range).?))),
            .i64_32_u => try frame.pushI64(byte_utils.load32(range).?),
        }
    }

    fn storeMemory(self: *Executor, frame: *Frame, reader: *Reader, kind: MemoryStore) Error!void {
        const offset = try readMemoryImmediate(reader);
        const value = switch (kind) {
            .i32, .i32_8, .i32_16 => @as(u64, @bitCast(@as(i64, try frame.popI32()))),
            .i64, .i64_8, .i64_16, .i64_32 => @as(u64, @bitCast(try frame.popI64())),
            .f32 => @as(u64, @intCast(@as(u32, @bitCast(try frame.popF32())))),
            .f64 => @as(u64, @bitCast(try frame.popF64())),
        };
        const address = try popAddress(frame, offset);
        const size = memoryStoreSize(kind);
        const range = try self.memoryRange(address, size);
        const stored = switch (kind) {
            .i32 => byte_utils.store32(range, @truncate(value)),
            .i64 => byte_utils.store64(range, value),
            .f32 => byte_utils.store32(range, @truncate(value)),
            .f64 => byte_utils.store64(range, value),
            .i32_8, .i64_8 => store8(range, @truncate(value)),
            .i32_16, .i64_16 => byte_utils.store16(range, @truncate(value)),
            .i64_32 => byte_utils.store32(range, @truncate(value)),
        };
        if (!stored) return error.Corrupt;
    }

    fn memorySize(self: *Executor, frame: *Frame, reader: *Reader) Error!void {
        try readMemoryIndex(reader);
        try frame.pushI32(@intCast(self.memory_pages));
    }

    fn memoryGrow(self: *Executor, frame: *Frame, reader: *Reader) Error!void {
        try readMemoryIndex(reader);
        const delta = try frame.popI32();
        if (delta < 0) return error.Corrupt;
        const previous_pages = self.memory_pages;
        const previous_bytes = checkedMul(previous_pages, wasm_page_bytes) orelse return error.Unsupported;
        const requested_pages = checkedAdd(previous_pages, @intCast(delta)) orelse {
            try frame.pushI32(-1);
            return;
        };
        const requested_bytes = checkedMul(requested_pages, wasm_page_bytes) orelse {
            try frame.pushI32(-1);
            return;
        };
        if (requested_bytes > self.runtime.memoryLen()) {
            const request = MemoryGrowRequest{
                .previous_pages = previous_pages,
                .requested_pages = requested_pages,
                .previous_bytes = previous_bytes,
                .requested_bytes = requested_bytes,
            };
            if (!request.valid()) return error.Corrupt;
            const authority = self.runtime.memory_grow_authority orelse return error.MemoryGrowthRequiresAuthority;
            const granted = try authority.request(authority.context, self.runtime, request);
            if (!granted) {
                try frame.pushI32(-1);
                return;
            }
            if (requested_bytes > self.runtime.memoryLen()) return error.NoMemory;
        }
        self.memory_pages = requested_pages;
        try frame.pushI32(@intCast(previous_pages));
    }

    fn memoryCopy(self: *Executor, frame: *Frame, reader: *Reader) Error!void {
        try readMemoryIndex(reader);
        try readMemoryIndex(reader);
        const length = try popMemoryLength(frame);
        const source = try popMemoryBase(frame);
        const destination = try popMemoryBase(frame);
        const source_range = try self.memoryRange(source, length);
        const destination_range = try self.memoryRange(destination, length);
        copyMemory(destination_range, source_range);
    }

    fn memoryInit(self: *Executor, frame: *Frame, reader: *Reader) Error!void {
        const data_index = try reader.readU32Leb();
        try readMemoryIndex(reader);
        if (data_index >= self.module.data_segment_count) return error.Corrupt;
        const segment = self.module.data_segments[data_index];
        if (segment.active or segment.dropped) return error.Trap;
        const length = try popMemoryLength(frame);
        const source = try popMemoryBase(frame);
        const destination = try popMemoryBase(frame);
        const source_end = checkedAdd(source, length) orelse return error.Trap;
        if (source_end > segment.bytes.len) return error.Trap;
        const destination_range = try self.memoryRange(destination, length);
        copyMemory(destination_range, segment.bytes[source..source_end]);
    }

    fn dataDrop(self: *Executor, reader: *Reader) Error!void {
        const data_index = try reader.readU32Leb();
        if (data_index >= self.module.data_segment_count) return error.Corrupt;
        self.module.data_segments[data_index].dropped = true;
    }

    fn tableInit(self: *Executor, frame: *Frame, reader: *Reader) Error!void {
        const element_index = try reader.readU32Leb();
        try readTableIndex(reader);
        if (element_index >= self.module.element_segment_count) return error.Corrupt;
        const segment = self.module.element_segments[element_index];
        if (!segment.passive or segment.dropped) return error.Trap;
        const length = try popMemoryLength(frame);
        const source = try popMemoryBase(frame);
        const destination = try popMemoryBase(frame);
        const source_end = checkedAdd(source, length) orelse return error.Trap;
        if (source_end > segment.count) return error.Trap;
        const destination_end = checkedAdd(destination, length) orelse return error.Trap;
        if (destination_end > self.module.table_min_entries or destination_end > max_table_entries) return error.Trap;
        var index: usize = 0;
        while (index < length) : (index += 1) {
            self.module.table_entries[destination + index] = segment.entries[source + index];
        }
    }

    fn elemDrop(self: *Executor, reader: *Reader) Error!void {
        const element_index = try reader.readU32Leb();
        if (element_index >= self.module.element_segment_count) return error.Corrupt;
        self.module.element_segments[element_index].dropped = true;
    }

    fn tableCopy(self: *Executor, frame: *Frame, reader: *Reader) Error!void {
        try readTableIndex(reader);
        try readTableIndex(reader);
        const length = try popMemoryLength(frame);
        const source = try popMemoryBase(frame);
        const destination = try popMemoryBase(frame);
        const source_end = checkedAdd(source, length) orelse return error.Trap;
        const destination_end = checkedAdd(destination, length) orelse return error.Trap;
        if (source_end > self.module.table_min_entries or destination_end > self.module.table_min_entries) return error.Trap;
        copyTable(self.module.table_entries[destination..destination_end], self.module.table_entries[source..source_end]);
    }

    fn tableSize(self: *Executor, frame: *Frame, reader: *Reader) Error!void {
        try readTableIndex(reader);
        try frame.pushI32(@intCast(self.module.table_min_entries));
    }

    fn tableGrow(self: *Executor, frame: *Frame, reader: *Reader) Error!void {
        try readTableIndex(reader);
        const delta = try frame.popI32();
        if (delta < 0) return error.Corrupt;
        const function_ref = try frame.popFuncref();
        if (function_ref) |index| {
            if (index >= self.module.totalFunctionCount()) return error.Corrupt;
        }
        const previous_entries = self.module.table_min_entries;
        const delta_entries: usize = @intCast(delta);
        const requested_entries = checkedAdd(previous_entries, delta_entries) orelse {
            try frame.pushI32(-1);
            return;
        };
        if (requested_entries > max_table_entries) {
            try frame.pushI32(-1);
            return;
        }
        if (delta_entries > 0) {
            const request = TableGrowRequest{
                .previous_entries = previous_entries,
                .requested_entries = requested_entries,
                .delta_entries = delta_entries,
            };
            if (!request.valid()) return error.Corrupt;
            const authority = self.runtime.table_grow_authority orelse return error.TableGrowthRequiresAuthority;
            const granted = try authority.request(authority.context, self.runtime, request);
            if (!granted) {
                try frame.pushI32(-1);
                return;
            }
        }
        var index: usize = previous_entries;
        while (index < requested_entries) : (index += 1) {
            self.module.table_entries[index] = function_ref;
        }
        self.module.table_min_entries = requested_entries;
        try frame.pushI32(@intCast(previous_entries));
    }

    fn tableFill(self: *Executor, frame: *Frame, reader: *Reader) Error!void {
        try readTableIndex(reader);
        const length = try popMemoryLength(frame);
        const function_ref = try frame.popFuncref();
        const destination = try popMemoryBase(frame);
        const destination_end = checkedAdd(destination, length) orelse return error.Trap;
        if (destination_end > self.module.table_min_entries or destination_end > max_table_entries) return error.Trap;
        if (function_ref) |index| {
            if (index >= self.module.totalFunctionCount()) return error.Corrupt;
        }
        var index: usize = destination;
        while (index < destination_end) : (index += 1) {
            self.module.table_entries[index] = function_ref;
        }
    }

    fn memoryFill(self: *Executor, frame: *Frame, reader: *Reader) Error!void {
        try readMemoryIndex(reader);
        const length = try popMemoryLength(frame);
        const value: u8 = @truncate(@as(u32, @bitCast(try frame.popI32())));
        const destination = try popMemoryBase(frame);
        const destination_range = try self.memoryRange(destination, length);
        @memset(destination_range, value);
    }

    fn popAddress(frame: *Frame, offset: u32) Error!usize {
        const base: u32 = @bitCast(try frame.popI32());
        return checkedAdd(@as(usize, base), offset) orelse error.NoMemory;
    }

    fn memoryRange(self: *Executor, address: usize, size: usize) Error![]u8 {
        const limit = checkedMul(self.memory_pages, wasm_page_bytes) orelse return error.Unsupported;
        const end = checkedAdd(address, size) orelse return error.NoMemory;
        if (end > limit or end > self.runtime.memory.len) return error.NoMemory;
        return self.runtime.memory[address..end];
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

pub fn executeExportI64(runtime: *Runtime, wasm_bytes: []const u8, export_name: []const u8) Error!i64 {
    return executeExportI64Args(runtime, wasm_bytes, export_name, &.{});
}

pub fn executeExportI64Args(runtime: *Runtime, wasm_bytes: []const u8, export_name: []const u8, args: []const i64) Error!i64 {
    return (try executeExportValuesArgs(runtime, wasm_bytes, export_name, args)).onlyI64();
}

pub fn executeExport(runtime: *Runtime, wasm_bytes: []const u8, export_name: []const u8) Error!?i64 {
    return (try executeExportValuesArgs(runtime, wasm_bytes, export_name, &.{})).optionalI64();
}

pub fn executeExportArgs(runtime: *Runtime, wasm_bytes: []const u8, export_name: []const u8, args: []const i64) Error!?i64 {
    return (try executeExportValuesArgs(runtime, wasm_bytes, export_name, args)).optionalI64();
}

pub fn executeExportValues(runtime: *Runtime, wasm_bytes: []const u8, export_name: []const u8) Error!ExecutionResult {
    return executeExportValueArgs(runtime, wasm_bytes, export_name, &.{});
}

pub fn executeExportValuesArgs(runtime: *Runtime, wasm_bytes: []const u8, export_name: []const u8, args: []const i64) Error!ExecutionResult {
    if (export_name.len == 0) return error.BadArgument;
    if (args.len > max_type_params) return error.BadArgument;
    var executor = try executorFor(runtime, wasm_bytes);
    var value_args: [max_type_params]Value = undefined;
    const prepared_args = try integerArgsForExport(executor.module, export_name, args, &value_args);
    try executor.runStart();
    return executor.runExport(export_name, prepared_args);
}

pub fn executeExportValueArgs(runtime: *Runtime, wasm_bytes: []const u8, export_name: []const u8, args: []const Value) Error!ExecutionResult {
    if (export_name.len == 0) return error.BadArgument;
    var executor = try executorFor(runtime, wasm_bytes);
    try executor.runStart();
    return executor.runExport(export_name, args);
}

fn executorFor(runtime: *Runtime, wasm_bytes: []const u8) Error!Executor {
    var module = try Module.parse(wasm_bytes);
    try module.resolveImports(runtime.*);
    const required_memory = try module.requiredMemoryBytes();
    if (required_memory > runtime.memoryLen()) return error.NoMemory;
    try module.applyDataSegments(runtime);
    return Executor{
        .runtime = runtime,
        .module = module,
        .memory_pages = module.memory_min_pages,
    };
}

fn integerArgsForExport(module: Module, export_name: []const u8, args: []const i64, out: *[max_type_params]Value) Error![]const Value {
    if (export_name.len == 0) return error.BadArgument;
    const function_index = try module.findExport(export_name);
    const function_type = module.types[try module.typeIndexForFunction(function_index)];
    if (args.len != function_type.param_count) return error.Unsupported;
    for (args, 0..) |arg, index| {
        out[index] = try Value.fromI64Arg(function_type.params[index], arg);
    }
    return out[0..args.len];
}

fn popMemoryBase(frame: *Executor.Frame) Error!usize {
    const value = try frame.popI32();
    if (value < 0) return error.NoMemory;
    return @intCast(value);
}

fn popMemoryLength(frame: *Executor.Frame) Error!usize {
    const value = try frame.popI32();
    if (value < 0) return error.NoMemory;
    return @intCast(value);
}

fn copyMemory(destination: []u8, source: []const u8) void {
    if (destination.len != source.len) unreachable;
    if (destination.len == 0) return;
    if (@intFromPtr(destination.ptr) <= @intFromPtr(source.ptr)) {
        var index: usize = 0;
        while (index < destination.len) : (index += 1) {
            destination[index] = source[index];
        }
    } else {
        var index = destination.len;
        while (index > 0) {
            index -= 1;
            destination[index] = source[index];
        }
    }
}

fn copyTable(destination: []?usize, source: []const ?usize) void {
    if (destination.len != source.len) unreachable;
    if (destination.len == 0) return;
    if (@intFromPtr(destination.ptr) <= @intFromPtr(source.ptr)) {
        var index: usize = 0;
        while (index < destination.len) : (index += 1) {
            destination[index] = source[index];
        }
    } else {
        var index = destination.len;
        while (index > 0) {
            index -= 1;
            destination[index] = source[index];
        }
    }
}

fn checkedAdd(left: usize, right: usize) ?usize {
    const result = @addWithOverflow(left, right);
    if (result[1] != 0) return null;
    return result[0];
}

fn checkedMul(left: usize, right: usize) ?usize {
    const result = @mulWithOverflow(left, right);
    if (result[1] != 0) return null;
    return result[0];
}

fn minSigned(comptime Int: type) Int {
    return @as(Int, -1) << (@typeInfo(Int).int.bits - 1);
}

fn maxSigned(comptime Int: type) Int {
    return ~minSigned(Int);
}

fn maxUnsigned(comptime Int: type) Int {
    return ~@as(Int, 0);
}

fn readValueType(reader: *Reader) Error!ValueType {
    return valueTypeFromByte(try reader.readByte()) orelse error.Unsupported;
}

fn readMemoryMinimumPages(reader: *Reader) Error!usize {
    const limits = try reader.readByte();
    if (limits != 0 and limits != 1) return error.Unsupported;
    const min = try reader.readU32Leb();
    if (limits == 1) {
        _ = try reader.readU32Leb();
    }
    return min;
}

fn readTableMinimumEntries(reader: *Reader) Error!usize {
    const limits = try reader.readByte();
    if (limits != 0 and limits != 1) return error.Unsupported;
    const min = try reader.readU32Leb();
    if (limits == 1) {
        const encoded_max = try reader.readU32Leb();
        if (encoded_max < min) return error.Corrupt;
    }
    return min;
}

fn validateImportedMemory(imported: ImportedMemory, host: HostImport) Error!void {
    if (host.memory_min_pages < imported.min_pages) return error.NoMemory;
}

fn validateImportedTable(imported: ImportedTable, host: HostImport) Error!void {
    if (host.table_min_entries < imported.min_entries) return error.NoMemory;
}

fn sectionFromByte(value: u8) ?Section {
    return switch (value) {
        @intFromEnum(Section.type) => .type,
        @intFromEnum(Section.import) => .import,
        @intFromEnum(Section.function) => .function,
        @intFromEnum(Section.table) => .table,
        @intFromEnum(Section.memory) => .memory,
        @intFromEnum(Section.global) => .global,
        @intFromEnum(Section.@"export") => .@"export",
        @intFromEnum(Section.start) => .start,
        @intFromEnum(Section.element) => .element,
        @intFromEnum(Section.code) => .code,
        @intFromEnum(Section.data) => .data,
        @intFromEnum(Section.data_count) => .data_count,
        else => null,
    };
}

fn sectionOrder(section: Section) u8 {
    return switch (section) {
        .type => 1,
        .import => 2,
        .function => 3,
        .table => 4,
        .memory => 5,
        .global => 6,
        .@"export" => 7,
        .start => 8,
        .element => 9,
        .data_count => 10,
        .code => 11,
        .data => 12,
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
        @intFromEnum(ValueType.funcref) => .funcref,
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
        @intFromEnum(Opcode.br_table) => .br_table,
        @intFromEnum(Opcode.@"return") => .@"return",
        @intFromEnum(Opcode.call) => .call,
        @intFromEnum(Opcode.call_indirect) => .call_indirect,
        @intFromEnum(Opcode.drop) => .drop,
        @intFromEnum(Opcode.select) => .select,
        @intFromEnum(Opcode.select_typed) => .select_typed,
        @intFromEnum(Opcode.local_get) => .local_get,
        @intFromEnum(Opcode.local_set) => .local_set,
        @intFromEnum(Opcode.local_tee) => .local_tee,
        @intFromEnum(Opcode.global_get) => .global_get,
        @intFromEnum(Opcode.global_set) => .global_set,
        @intFromEnum(Opcode.table_get) => .table_get,
        @intFromEnum(Opcode.table_set) => .table_set,
        @intFromEnum(Opcode.i32_load) => .i32_load,
        @intFromEnum(Opcode.i64_load) => .i64_load,
        @intFromEnum(Opcode.f32_load) => .f32_load,
        @intFromEnum(Opcode.f64_load) => .f64_load,
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
        @intFromEnum(Opcode.f32_store) => .f32_store,
        @intFromEnum(Opcode.f64_store) => .f64_store,
        @intFromEnum(Opcode.i32_store8) => .i32_store8,
        @intFromEnum(Opcode.i32_store16) => .i32_store16,
        @intFromEnum(Opcode.i64_store8) => .i64_store8,
        @intFromEnum(Opcode.i64_store16) => .i64_store16,
        @intFromEnum(Opcode.i64_store32) => .i64_store32,
        @intFromEnum(Opcode.memory_size) => .memory_size,
        @intFromEnum(Opcode.memory_grow) => .memory_grow,
        @intFromEnum(Opcode.i32_const) => .i32_const,
        @intFromEnum(Opcode.i64_const) => .i64_const,
        @intFromEnum(Opcode.f32_const) => .f32_const,
        @intFromEnum(Opcode.f64_const) => .f64_const,
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
        @intFromEnum(Opcode.f32_eq) => .f32_eq,
        @intFromEnum(Opcode.f32_ne) => .f32_ne,
        @intFromEnum(Opcode.f32_lt) => .f32_lt,
        @intFromEnum(Opcode.f32_gt) => .f32_gt,
        @intFromEnum(Opcode.f32_le) => .f32_le,
        @intFromEnum(Opcode.f32_ge) => .f32_ge,
        @intFromEnum(Opcode.f64_eq) => .f64_eq,
        @intFromEnum(Opcode.f64_ne) => .f64_ne,
        @intFromEnum(Opcode.f64_lt) => .f64_lt,
        @intFromEnum(Opcode.f64_gt) => .f64_gt,
        @intFromEnum(Opcode.f64_le) => .f64_le,
        @intFromEnum(Opcode.f64_ge) => .f64_ge,
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
        @intFromEnum(Opcode.f32_abs) => .f32_abs,
        @intFromEnum(Opcode.f32_neg) => .f32_neg,
        @intFromEnum(Opcode.f32_sqrt) => .f32_sqrt,
        @intFromEnum(Opcode.f32_add) => .f32_add,
        @intFromEnum(Opcode.f32_sub) => .f32_sub,
        @intFromEnum(Opcode.f32_mul) => .f32_mul,
        @intFromEnum(Opcode.f32_div) => .f32_div,
        @intFromEnum(Opcode.f64_abs) => .f64_abs,
        @intFromEnum(Opcode.f64_neg) => .f64_neg,
        @intFromEnum(Opcode.f64_sqrt) => .f64_sqrt,
        @intFromEnum(Opcode.f64_add) => .f64_add,
        @intFromEnum(Opcode.f64_sub) => .f64_sub,
        @intFromEnum(Opcode.f64_mul) => .f64_mul,
        @intFromEnum(Opcode.f64_div) => .f64_div,
        @intFromEnum(Opcode.i32_wrap_i64) => .i32_wrap_i64,
        @intFromEnum(Opcode.i32_trunc_f32_s) => .i32_trunc_f32_s,
        @intFromEnum(Opcode.i32_trunc_f32_u) => .i32_trunc_f32_u,
        @intFromEnum(Opcode.i32_trunc_f64_s) => .i32_trunc_f64_s,
        @intFromEnum(Opcode.i32_trunc_f64_u) => .i32_trunc_f64_u,
        @intFromEnum(Opcode.i64_extend_i32_s) => .i64_extend_i32_s,
        @intFromEnum(Opcode.i64_extend_i32_u) => .i64_extend_i32_u,
        @intFromEnum(Opcode.i64_trunc_f32_s) => .i64_trunc_f32_s,
        @intFromEnum(Opcode.i64_trunc_f32_u) => .i64_trunc_f32_u,
        @intFromEnum(Opcode.i64_trunc_f64_s) => .i64_trunc_f64_s,
        @intFromEnum(Opcode.i64_trunc_f64_u) => .i64_trunc_f64_u,
        @intFromEnum(Opcode.f32_convert_i32_s) => .f32_convert_i32_s,
        @intFromEnum(Opcode.f32_convert_i32_u) => .f32_convert_i32_u,
        @intFromEnum(Opcode.f32_convert_i64_s) => .f32_convert_i64_s,
        @intFromEnum(Opcode.f32_convert_i64_u) => .f32_convert_i64_u,
        @intFromEnum(Opcode.f32_demote_f64) => .f32_demote_f64,
        @intFromEnum(Opcode.f64_convert_i32_s) => .f64_convert_i32_s,
        @intFromEnum(Opcode.f64_convert_i32_u) => .f64_convert_i32_u,
        @intFromEnum(Opcode.f64_convert_i64_s) => .f64_convert_i64_s,
        @intFromEnum(Opcode.f64_convert_i64_u) => .f64_convert_i64_u,
        @intFromEnum(Opcode.f64_promote_f32) => .f64_promote_f32,
        @intFromEnum(Opcode.i32_reinterpret_f32) => .i32_reinterpret_f32,
        @intFromEnum(Opcode.i64_reinterpret_f64) => .i64_reinterpret_f64,
        @intFromEnum(Opcode.f32_reinterpret_i32) => .f32_reinterpret_i32,
        @intFromEnum(Opcode.f64_reinterpret_i64) => .f64_reinterpret_i64,
        @intFromEnum(Opcode.i32_extend8_s) => .i32_extend8_s,
        @intFromEnum(Opcode.i32_extend16_s) => .i32_extend16_s,
        @intFromEnum(Opcode.i64_extend8_s) => .i64_extend8_s,
        @intFromEnum(Opcode.i64_extend16_s) => .i64_extend16_s,
        @intFromEnum(Opcode.i64_extend32_s) => .i64_extend32_s,
        @intFromEnum(Opcode.ref_null) => .ref_null,
        @intFromEnum(Opcode.ref_is_null) => .ref_is_null,
        @intFromEnum(Opcode.ref_func) => .ref_func,
        else => null,
    };
}

fn parseEmptySection(reader: *Reader) Error!void {
    const count = try reader.readU32Leb();
    if (count != 0 or !reader.done()) return error.Unsupported;
}

fn readBlockType(reader: *Reader) Error!void {
    const block_type = try reader.readByte();
    if (block_type == wasm_empty_block_type) return;
    const value_type = valueTypeFromByte(block_type) orelse return error.Unsupported;
    if (!supportedValue(value_type)) return error.Unsupported;
}

fn readSelectType(reader: *Reader) Error!ValueType {
    const type_count = try reader.readU32Leb();
    if (type_count != 1) return error.Unsupported;
    return readValueType(reader);
}

fn readElementFunctionCount(reader: *Reader, payload: Module.ElementPayload) Error!usize {
    switch (payload) {
        .function_index_vector => {},
        .element_kind => {
            const element_kind = try reader.readByte();
            if (element_kind != 0) return error.Unsupported;
        },
        .ref_func_expression_vector => {
            const ref_type = try reader.readByte();
            if (ref_type != wasm_funcref_type) return error.Unsupported;
        },
    }
    const function_count = try reader.readU32Leb();
    if (function_count > max_table_entries) return error.Unsupported;
    return function_count;
}

fn readRefFuncExpression(reader: *Reader) Error!usize {
    const opcode = try reader.readByte();
    if (opcode != wasm_ref_func_opcode) return error.Unsupported;
    const function_ref = try reader.readU32Leb();
    const end = opcodeFromByte(try reader.readByte()) orelse return error.Unsupported;
    if (end != .end) return error.Unsupported;
    return function_ref;
}

const IfSkipResult = enum {
    reached_else,
    reached_end,
};

fn skipUntakenIf(reader: *Reader) Error!IfSkipResult {
    var depth: usize = 0;
    while (!reader.done()) {
        const opcode_byte = try reader.readByte();
        if (opcode_byte == wasm_extended_prefix) {
            try skipExtendedOpcodeImmediate(reader);
            continue;
        }
        const opcode = opcodeFromByte(opcode_byte) orelse return error.Unsupported;
        switch (opcode) {
            .block, .loop, .@"if" => {
                try readBlockType(reader);
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
        const opcode_byte = try reader.readByte();
        if (opcode_byte == wasm_extended_prefix) {
            try skipExtendedOpcodeImmediate(reader);
            continue;
        }
        const opcode = opcodeFromByte(opcode_byte) orelse return error.Unsupported;
        switch (opcode) {
            .block, .loop, .@"if" => {
                try readBlockType(reader);
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

fn skipExtendedOpcodeImmediate(reader: *Reader) Error!void {
    const opcode = try reader.readU32Leb();
    switch (opcode) {
        ext_i32_trunc_sat_f32_s,
        ext_i32_trunc_sat_f32_u,
        ext_i32_trunc_sat_f64_s,
        ext_i32_trunc_sat_f64_u,
        ext_i64_trunc_sat_f32_s,
        ext_i64_trunc_sat_f32_u,
        ext_i64_trunc_sat_f64_s,
        ext_i64_trunc_sat_f64_u,
        => {},
        ext_memory_init => {
            _ = try reader.readU32Leb();
            try readMemoryIndex(reader);
        },
        ext_data_drop => _ = try reader.readU32Leb(),
        ext_memory_copy => {
            try readMemoryIndex(reader);
            try readMemoryIndex(reader);
        },
        ext_memory_fill => try readMemoryIndex(reader),
        ext_table_init => {
            _ = try reader.readU32Leb();
            try readTableIndex(reader);
        },
        ext_elem_drop => _ = try reader.readU32Leb(),
        ext_table_copy => {
            try readTableIndex(reader);
            try readTableIndex(reader);
        },
        ext_table_grow => try readTableIndex(reader),
        ext_table_size => try readTableIndex(reader),
        ext_table_fill => try readTableIndex(reader),
        else => return error.Unsupported,
    }
}

fn skipOpcodeImmediate(reader: *Reader, opcode: Opcode) Error!void {
    switch (opcode) {
        .i32_const => _ = try reader.readI32Leb(),
        .i64_const => _ = try reader.readI64Leb(),
        .f32_const => _ = try reader.readF32(),
        .f64_const => _ = try reader.readF64(),
        .local_get,
        .local_set,
        .local_tee,
        .global_get,
        .global_set,
        .call,
        .br,
        .br_if,
        .memory_size,
        .memory_grow,
        => _ = try reader.readU32Leb(),
        .br_table => {
            const target_count = try reader.readU32Leb();
            var target_index: u32 = 0;
            while (target_index < target_count) : (target_index += 1) {
                _ = try reader.readU32Leb();
            }
            _ = try reader.readU32Leb();
        },
        .select_typed => _ = try readSelectType(reader),
        .call_indirect => {
            _ = try reader.readU32Leb();
            _ = try reader.readU32Leb();
        },
        .table_get, .table_set => try readTableIndex(reader),
        .ref_null => {
            const ref_type = try reader.readByte();
            if (ref_type != wasm_funcref_type) return error.Unsupported;
        },
        .ref_func => _ = try reader.readU32Leb(),
        .i32_load,
        .i64_load,
        .f32_load,
        .f64_load,
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
        .f32_store,
        .f64_store,
        .i32_store8,
        .i32_store16,
        .i64_store8,
        .i64_store16,
        .i64_store32,
        => {
            _ = try reader.readU32Leb();
            _ = try reader.readU32Leb();
        },
        .block, .loop, .@"if" => try readBlockType(reader),
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
        .f32_eq,
        .f32_ne,
        .f32_lt,
        .f32_gt,
        .f32_le,
        .f32_ge,
        .f64_eq,
        .f64_ne,
        .f64_lt,
        .f64_gt,
        .f64_le,
        .f64_ge,
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
        .f32_abs,
        .f32_neg,
        .f32_sqrt,
        .f32_add,
        .f32_sub,
        .f32_mul,
        .f32_div,
        .f64_abs,
        .f64_neg,
        .f64_sqrt,
        .f64_add,
        .f64_sub,
        .f64_mul,
        .f64_div,
        .i32_wrap_i64,
        .i32_trunc_f32_s,
        .i32_trunc_f32_u,
        .i32_trunc_f64_s,
        .i32_trunc_f64_u,
        .i64_extend_i32_s,
        .i64_extend_i32_u,
        .i64_trunc_f32_s,
        .i64_trunc_f32_u,
        .i64_trunc_f64_s,
        .i64_trunc_f64_u,
        .f32_convert_i32_s,
        .f32_convert_i32_u,
        .f32_convert_i64_s,
        .f32_convert_i64_u,
        .f32_demote_f64,
        .f64_convert_i32_s,
        .f64_convert_i32_u,
        .f64_convert_i64_s,
        .f64_convert_i64_u,
        .f64_promote_f32,
        .i32_reinterpret_f32,
        .i64_reinterpret_f64,
        .f32_reinterpret_i32,
        .f64_reinterpret_i64,
        .i32_extend8_s,
        .i32_extend16_s,
        .i64_extend8_s,
        .i64_extend16_s,
        .i64_extend32_s,
        .ref_is_null,
        => {},
    }
}

fn finishFunctionResult(function_type: FuncType, frame: *Executor.Frame) Error!ExecutionResult {
    var result = ExecutionResult{ .count = function_type.result_count };
    var remaining = function_type.result_count;
    while (remaining > 0) {
        remaining -= 1;
        result.values[remaining] = try popTypedValue(frame, function_type.results[remaining]);
    }
    if (frame.stack_len != 0) return error.Corrupt;
    return result;
}

fn pushFunctionResult(frame: *Executor.Frame, function_type: FuncType, result: ExecutionResult) Error!void {
    if (result.count != function_type.result_count) return error.Corrupt;
    for (result.values[0..result.count], 0..) |value, index| {
        if (!valueMatchesType(value, function_type.results[index])) return error.Corrupt;
        try frame.push(value);
    }
}

fn popTypedValue(frame: *Executor.Frame, value_type: ValueType) Error!Value {
    return switch (value_type) {
        .i32 => .{ .i32 = try frame.popI32() },
        .i64 => .{ .i64 = try frame.popI64() },
        .f32 => .{ .f32 = try frame.popF32() },
        .f64 => .{ .f64 = try frame.popF64() },
        .funcref => .{ .funcref = try frame.popFuncref() },
    };
}

fn valueMatchesType(value: Value, value_type: ValueType) bool {
    return switch (value) {
        .i32 => value_type == .i32,
        .i64 => value_type == .i64,
        .f32 => value_type == .f32,
        .f64 => value_type == .f64,
        .funcref => value_type == .funcref,
    };
}

fn resultMatchesType(result: ExecutionResult, function_type: FuncType) bool {
    if (result.count != function_type.result_count) return false;
    for (result.values[0..result.count], 0..) |value, index| {
        if (!valueMatchesType(value, function_type.results[index])) return false;
    }
    return true;
}

fn pushI32Binary(frame: *Executor.Frame, op: BinaryOp) Error!void {
    const right = try frame.popI32();
    const left = try frame.popI32();
    try frame.pushI32(try applyI32Binary(op, left, right));
}

fn pushI64Binary(frame: *Executor.Frame, op: BinaryOp) Error!void {
    const right = try frame.popI64();
    const left = try frame.popI64();
    try frame.pushI64(try applyI64Binary(op, left, right));
}

fn pushF32Binary(frame: *Executor.Frame, op: FloatBinaryOp) Error!void {
    const right = try frame.popF32();
    const left = try frame.popF32();
    try frame.push(.{ .f32 = applyF32Binary(op, left, right) });
}

fn pushF64Binary(frame: *Executor.Frame, op: FloatBinaryOp) Error!void {
    const right = try frame.popF64();
    const left = try frame.popF64();
    try frame.push(.{ .f64 = applyF64Binary(op, left, right) });
}

fn pushI32Unary(frame: *Executor.Frame, op: UnaryOp) Error!void {
    const value = try frame.popI32();
    try frame.pushI32(applyI32Unary(op, value));
}

fn pushI64Unary(frame: *Executor.Frame, op: UnaryOp) Error!void {
    const value = try frame.popI64();
    try frame.pushI64(applyI64Unary(op, value));
}

fn pushF32Unary(frame: *Executor.Frame, op: FloatUnaryOp) Error!void {
    const value = try frame.popF32();
    try frame.push(.{ .f32 = applyF32Unary(op, value) });
}

fn pushF64Unary(frame: *Executor.Frame, op: FloatUnaryOp) Error!void {
    const value = try frame.popF64();
    try frame.push(.{ .f64 = applyF64Unary(op, value) });
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

fn applyF32Unary(op: FloatUnaryOp, value: f32) f32 {
    return switch (op) {
        .abs => @abs(value),
        .neg => -value,
        .sqrt => @sqrt(value),
    };
}

fn applyF64Unary(op: FloatUnaryOp, value: f64) f64 {
    return switch (op) {
        .abs => @abs(value),
        .neg => -value,
        .sqrt => @sqrt(value),
    };
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
            if (right == 0 or (left == minSigned(i32) and right == -1)) return error.ArithmeticTrap;
            break :signed @divTrunc(left, right);
        },
        .div_u => unsigned: {
            if (right_unsigned == 0) return error.ArithmeticTrap;
            break :unsigned @bitCast(@divTrunc(left_unsigned, right_unsigned));
        },
        .rem_s => signed: {
            if (right == 0) return error.ArithmeticTrap;
            if (left == minSigned(i32) and right == -1) break :signed 0;
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
            if (right == 0 or (left == minSigned(i64) and right == -1)) return error.ArithmeticTrap;
            break :signed @divTrunc(left, right);
        },
        .div_u => unsigned: {
            if (right_unsigned == 0) return error.ArithmeticTrap;
            break :unsigned @bitCast(@divTrunc(left_unsigned, right_unsigned));
        },
        .rem_s => signed: {
            if (right == 0) return error.ArithmeticTrap;
            if (left == minSigned(i64) and right == -1) break :signed 0;
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

fn applyF32Binary(op: FloatBinaryOp, left: f32, right: f32) f32 {
    return switch (op) {
        .add => left + right,
        .sub => left - right,
        .mul => left * right,
        .div => left / right,
    };
}

fn applyF64Binary(op: FloatBinaryOp, left: f64, right: f64) f64 {
    return switch (op) {
        .add => left + right,
        .sub => left - right,
        .mul => left * right,
        .div => left / right,
    };
}

fn pushI32Comparison(frame: *Executor.Frame, comparison: Comparison) Error!void {
    const right = try frame.popI32();
    const left = try frame.popI32();
    try frame.pushI32(if (compareI32(comparison, left, right)) 1 else 0);
}

fn pushI64Comparison(frame: *Executor.Frame, comparison: Comparison) Error!void {
    const right = try frame.popI64();
    const left = try frame.popI64();
    try frame.pushI32(if (compareI64(comparison, left, right)) 1 else 0);
}

fn pushF32Comparison(frame: *Executor.Frame, comparison: FloatComparison) Error!void {
    const right = try frame.popF32();
    const left = try frame.popF32();
    try frame.pushI32(if (compareF32(comparison, left, right)) 1 else 0);
}

fn pushF64Comparison(frame: *Executor.Frame, comparison: FloatComparison) Error!void {
    const right = try frame.popF64();
    const left = try frame.popF64();
    try frame.pushI32(if (compareF64(comparison, left, right)) 1 else 0);
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

fn compareF32(comparison: FloatComparison, left: f32, right: f32) bool {
    return switch (comparison) {
        .eq => left == right,
        .ne => left != right,
        .lt => left < right,
        .gt => left > right,
        .le => left <= right,
        .ge => left >= right,
    };
}

fn compareF64(comparison: FloatComparison, left: f64, right: f64) bool {
    return switch (comparison) {
        .eq => left == right,
        .ne => left != right,
        .lt => left < right,
        .gt => left > right,
        .le => left <= right,
        .ge => left >= right,
    };
}

fn invalidTruncF32(value: f32, min: f32, max_exclusive: f32) bool {
    return value != value or value < min or value >= max_exclusive;
}

fn invalidTruncF64(value: f64, min: f64, max_exclusive: f64) bool {
    return value != value or value < min or value >= max_exclusive;
}

fn truncF32ToI32(value: f32) Error!i32 {
    if (invalidTruncF32(value, i32_min_as_f32, i32_max_plus_one_as_f32)) return error.ArithmeticTrap;
    return @intFromFloat(value);
}

fn truncF32ToU32(value: f32) Error!u32 {
    if (invalidTruncF32(value, 0.0, u32_max_plus_one_as_f32)) return error.ArithmeticTrap;
    return @intFromFloat(value);
}

fn truncF64ToI32(value: f64) Error!i32 {
    if (invalidTruncF64(value, i32_min_as_f64, i32_max_plus_one_as_f64)) return error.ArithmeticTrap;
    return @intFromFloat(value);
}

fn truncF64ToU32(value: f64) Error!u32 {
    if (invalidTruncF64(value, 0.0, u32_max_plus_one_as_f64)) return error.ArithmeticTrap;
    return @intFromFloat(value);
}

fn truncF32ToI64(value: f32) Error!i64 {
    if (invalidTruncF32(value, i64_min_as_f32, i64_max_plus_one_as_f32)) return error.ArithmeticTrap;
    return @intFromFloat(value);
}

fn truncF32ToU64(value: f32) Error!u64 {
    if (invalidTruncF32(value, 0.0, u64_max_plus_one_as_f32)) return error.ArithmeticTrap;
    return @intFromFloat(value);
}

fn truncF64ToI64(value: f64) Error!i64 {
    if (invalidTruncF64(value, i64_min_as_f64, i64_max_plus_one_as_f64)) return error.ArithmeticTrap;
    return @intFromFloat(value);
}

fn truncF64ToU64(value: f64) Error!u64 {
    if (invalidTruncF64(value, 0.0, u64_max_plus_one_as_f64)) return error.ArithmeticTrap;
    return @intFromFloat(value);
}

fn saturatingTruncF32ToI32(value: f32) i32 {
    if (value != value) return 0;
    if (value <= i32_min_as_f32) return minSigned(i32);
    if (value >= i32_max_plus_one_as_f32) return maxSigned(i32);
    return @intFromFloat(value);
}

fn saturatingTruncF32ToU32(value: f32) u32 {
    if (value != value or value <= 0.0) return 0;
    if (value >= u32_max_plus_one_as_f32) return maxUnsigned(u32);
    return @intFromFloat(value);
}

fn saturatingTruncF64ToI32(value: f64) i32 {
    if (value != value) return 0;
    if (value <= i32_min_as_f64) return minSigned(i32);
    if (value >= i32_max_plus_one_as_f64) return maxSigned(i32);
    return @intFromFloat(value);
}

fn saturatingTruncF64ToU32(value: f64) u32 {
    if (value != value or value <= 0.0) return 0;
    if (value >= u32_max_plus_one_as_f64) return maxUnsigned(u32);
    return @intFromFloat(value);
}

fn saturatingTruncF32ToI64(value: f32) i64 {
    if (value != value) return 0;
    if (value <= i64_min_as_f32) return minSigned(i64);
    if (value >= i64_max_plus_one_as_f32) return maxSigned(i64);
    return @intFromFloat(value);
}

fn saturatingTruncF32ToU64(value: f32) u64 {
    if (value != value or value <= 0.0) return 0;
    if (value >= u64_max_plus_one_as_f32) return maxUnsigned(u64);
    return @intFromFloat(value);
}

fn saturatingTruncF64ToI64(value: f64) i64 {
    if (value != value) return 0;
    if (value <= i64_min_as_f64) return minSigned(i64);
    if (value >= i64_max_plus_one_as_f64) return maxSigned(i64);
    return @intFromFloat(value);
}

fn saturatingTruncF64ToU64(value: f64) u64 {
    if (value != value or value <= 0.0) return 0;
    if (value >= u64_max_plus_one_as_f64) return maxUnsigned(u64);
    return @intFromFloat(value);
}

fn readConstantI32Expression(reader: *Reader) Error!i32 {
    const opcode = opcodeFromByte(try reader.readByte()) orelse return error.Unsupported;
    if (opcode != .i32_const) return error.Unsupported;
    const value = try reader.readI32Leb();
    const end = opcodeFromByte(try reader.readByte()) orelse return error.Unsupported;
    if (end != .end) return error.Unsupported;
    return value;
}

fn readConstantValueExpression(reader: *Reader, value_type: ValueType) Error!Value {
    const opcode = opcodeFromByte(try reader.readByte()) orelse return error.Unsupported;
    const value = switch (value_type) {
        .i32 => value: {
            if (opcode != .i32_const) return error.Unsupported;
            break :value Value{ .i32 = try reader.readI32Leb() };
        },
        .i64 => value: {
            if (opcode != .i64_const) return error.Unsupported;
            break :value Value{ .i64 = try reader.readI64Leb() };
        },
        .f32 => value: {
            if (opcode != .f32_const) return error.Unsupported;
            break :value Value{ .f32 = try reader.readF32() };
        },
        .f64 => value: {
            if (opcode != .f64_const) return error.Unsupported;
            break :value Value{ .f64 = try reader.readF64() };
        },
        .funcref => value: {
            switch (opcode) {
                .ref_null => {
                    const ref_type = try reader.readByte();
                    if (ref_type != wasm_funcref_type) return error.Unsupported;
                    break :value Value{ .funcref = null };
                },
                .ref_func => break :value Value{ .funcref = try reader.readU32Leb() },
                else => return error.Unsupported,
            }
        },
    };
    const end = opcodeFromByte(try reader.readByte()) orelse return error.Unsupported;
    if (end != .end) return error.Unsupported;
    return value;
}

fn readMemoryImmediate(reader: *Reader) Error!u32 {
    _ = try reader.readU32Leb();
    return try reader.readU32Leb();
}

fn readMemoryIndex(reader: *Reader) Error!void {
    const memory_index = try reader.readU32Leb();
    if (memory_index != 0) return error.Unsupported;
}

fn readTableIndex(reader: *Reader) Error!void {
    const table_index = try reader.readU32Leb();
    if (table_index != 0) return error.Unsupported;
}

fn memoryLoadSize(kind: MemoryLoad) usize {
    return switch (kind) {
        .i32 => @sizeOf(u32),
        .i64 => @sizeOf(u64),
        .f32 => @sizeOf(f32),
        .f64 => @sizeOf(f64),
        .i32_8_s, .i32_8_u, .i64_8_s, .i64_8_u => @sizeOf(u8),
        .i32_16_s, .i32_16_u, .i64_16_s, .i64_16_u => @sizeOf(u16),
        .i64_32_s, .i64_32_u => @sizeOf(u32),
    };
}

fn memoryStoreSize(kind: MemoryStore) usize {
    return switch (kind) {
        .i32 => @sizeOf(u32),
        .i64 => @sizeOf(u64),
        .f32 => @sizeOf(f32),
        .f64 => @sizeOf(f64),
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
