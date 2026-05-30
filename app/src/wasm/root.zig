const byte_utils = @import("../bytes.zig");

const max_functions = 1024;
const max_imports = 16;
const max_types = 128;
const max_type_params = 128;
const max_type_results = 4;
const max_locals = 1024;
const max_stack = 32;
const max_call_depth = 256;
const max_control_depth = 256;
const max_globals = 16;
const max_table_entries = 32;
const max_data_segments = 8;
const max_decoded_ops = 512 * 1024;
const byte_load_bytes = 1;
const i32_load_bytes = 4;
const wasm_page_bytes = 65536;
const wasm_page_shift = 16;
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
const limits_min_only: u8 = 0;
const limits_min_max: u8 = 1;
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
const f32_sign_mask: u32 = 0x80000000;
const f32_magnitude_mask: u32 = 0x7fffffff;
const f64_sign_mask: u64 = 0x8000000000000000;
const f64_magnitude_mask: u64 = 0x7fffffffffffffff;

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
    i32_rotl = 0x77,
    i32_rotr = 0x78,
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
    i64_rotl = 0x89,
    i64_rotr = 0x8a,
    f32_abs = 0x8b,
    f32_neg = 0x8c,
    f32_ceil = 0x8d,
    f32_floor = 0x8e,
    f32_trunc = 0x8f,
    f32_nearest = 0x90,
    f32_sqrt = 0x91,
    f32_add = 0x92,
    f32_sub = 0x93,
    f32_mul = 0x94,
    f32_div = 0x95,
    f32_min = 0x96,
    f32_max = 0x97,
    f32_copysign = 0x98,
    f64_abs = 0x99,
    f64_neg = 0x9a,
    f64_ceil = 0x9b,
    f64_floor = 0x9c,
    f64_trunc = 0x9d,
    f64_nearest = 0x9e,
    f64_sqrt = 0x9f,
    f64_add = 0xa0,
    f64_sub = 0xa1,
    f64_mul = 0xa2,
    f64_div = 0xa3,
    f64_min = 0xa4,
    f64_max = 0xa5,
    f64_copysign = 0xa6,
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
    initial_memory_pages: ?usize = null,
    trace: ?*ExecutionTrace = null,

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

    pub fn initWithMemoryPages(memory: []u8, execution_ticks: *u64, initial_memory_pages: usize) Runtime {
        return .{
            .memory = memory,
            .execution_ticks = execution_ticks,
            .initial_memory_pages = initial_memory_pages,
        };
    }

    fn memoryLen(self: Runtime) usize {
        return self.memory.len;
    }

    fn consumeExecution(self: *Runtime, ticks: u64) bool {
        if (ticks == 0 or ticks > self.execution_ticks.*) return false;
        self.execution_ticks.* -= ticks;
        if (self.trace) |trace| trace.execution_ticks_consumed += ticks;
        return true;
    }
};

pub const ExecutionTrace = struct {
    execution_ticks_consumed: u64 = 0,
    instructions: u64 = 0,
    extended_instructions: u64 = 0,
    function_entries: u64 = 0,
    imported_calls: u64 = 0,
    direct_calls: u64 = 0,
    indirect_calls: u64 = 0,
    branch_instructions: u64 = 0,
    memory_loads: u64 = 0,
    memory_stores: u64 = 0,
    local_accesses: u64 = 0,
    constants: u64 = 0,
    max_call_depth: u64 = 0,
    opcode_counts: [256]u64 = [_]u64{0} ** 256,

    fn recordOpcode(self: *ExecutionTrace, opcode_byte: u8, opcode: Opcode) void {
        self.instructions += 1;
        self.opcode_counts[opcode_byte] += 1;
        switch (opcode) {
            .call => self.direct_calls += 1,
            .call_indirect => self.indirect_calls += 1,
            .br, .br_if, .br_table => self.branch_instructions += 1,
            .i32_load, .i64_load, .f32_load, .f64_load, .i32_load8_s, .i32_load8_u, .i32_load16_s, .i32_load16_u, .i64_load8_s, .i64_load8_u, .i64_load16_s, .i64_load16_u, .i64_load32_s, .i64_load32_u => self.memory_loads += 1,
            .i32_store, .i64_store, .f32_store, .f64_store, .i32_store8, .i32_store16, .i64_store8, .i64_store16, .i64_store32 => self.memory_stores += 1,
            .local_get, .local_set, .local_tee, .global_get, .global_set => self.local_accesses += 1,
            .i32_const, .i64_const, .f32_const, .f64_const => self.constants += 1,
            else => {},
        }
    }

    fn recordExtendedOpcode(self: *ExecutionTrace) void {
        self.instructions += 1;
        self.extended_instructions += 1;
        self.opcode_counts[wasm_extended_prefix] += 1;
    }

    fn enterFunction(self: *ExecutionTrace, depth: usize) void {
        self.function_entries += 1;
        const depth_value: u64 = @intCast(depth + 1);
        if (depth_value > self.max_call_depth) self.max_call_depth = depth_value;
    }
};

pub const MemoryGrowRequest = struct {
    previous_pages: usize,
    requested_pages: usize,
    previous_bytes: usize,
    requested_bytes: usize,

    pub fn valid(self: MemoryGrowRequest) bool {
        const expected_previous = pagesToBytes(self.previous_pages) orelse return false;
        const expected_requested = pagesToBytes(self.requested_pages) orelse return false;
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
    memory_max_pages: ?usize = null,
    table_min_entries: usize = 0,
    table_max_entries: ?usize = null,
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
        if (self.offset >= self.bytes.len) return error.Corrupt;
        const first = self.bytes[self.offset];
        if ((first & leb_continue_mask) == 0) {
            self.offset += 1;
            return first;
        }
        var result: u32 = 0;
        var count: usize = 0;
        while (count < leb32_max_bytes) : (count += 1) {
            const byte = try self.readByte();
            const shift: u5 = @intCast(count * leb_bits_per_byte);
            result |= @as(u32, byte & leb_payload_mask) << shift;
            if ((byte & leb_continue_mask) == 0) return result;
        }
        return error.Corrupt;
    }

    fn readI32Leb(self: *Reader) Error!i32 {
        if (self.offset >= self.bytes.len) return error.Corrupt;
        const first = self.bytes[self.offset];
        if ((first & leb_continue_mask) == 0) {
            self.offset += 1;
            var result: i32 = first & leb_payload_mask;
            if ((first & leb_sign_mask) != 0) result |= @as(i32, -1) << leb_bits_per_byte;
            return result;
        }
        var result: i32 = 0;
        var count: usize = 0;
        var byte: u8 = 0;
        while (count < leb32_max_bytes) : (count += 1) {
            byte = try self.readByte();
            const shift: u5 = @intCast(count * leb_bits_per_byte);
            result |= @as(i32, byte & leb_payload_mask) << shift;
            if ((byte & leb_continue_mask) == 0) {
                const signed_shift = (count + 1) * leb_bits_per_byte;
                if (signed_shift < 32 and (byte & leb_sign_mask) != 0) {
                    result |= @as(i32, -1) << @intCast(signed_shift);
                }
                return result;
            }
        }
        return error.Corrupt;
    }

    fn readI64Leb(self: *Reader) Error!i64 {
        if (self.offset >= self.bytes.len) return error.Corrupt;
        const first = self.bytes[self.offset];
        if ((first & leb_continue_mask) == 0) {
            self.offset += 1;
            var result: i64 = first & leb_payload_mask;
            if ((first & leb_sign_mask) != 0) result |= @as(i64, -1) << leb_bits_per_byte;
            return result;
        }
        var result: i64 = 0;
        var count: usize = 0;
        var byte: u8 = 0;
        while (count < leb64_max_bytes) : (count += 1) {
            byte = try self.readByte();
            const shift: u6 = @intCast(count * leb_bits_per_byte);
            result |= @as(i64, byte & leb_payload_mask) << shift;
            if ((byte & leb_continue_mask) == 0) {
                const signed_shift = (count + 1) * leb_bits_per_byte;
                if (signed_shift < 64 and (byte & leb_sign_mask) != 0) {
                    result |= @as(i64, -1) << @intCast(signed_shift);
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
    decoded_start: usize = 0,
    decoded_count: usize = 0,
};

const DecodedOp = struct {
    offset: u32 = 0,
    next_offset: u32 = 0,
    opcode_byte: u8 = 0,
    imm0: u32 = 0,
    imm1: u32 = 0,
};

const DecodedProgram = struct {
    ops: [max_decoded_ops]DecodedOp = undefined,
    count: usize = 0,

    fn reset(program: *DecodedProgram) void {
        program.count = 0;
    }

    fn append(program: *DecodedProgram, op: DecodedOp) Error!void {
        if (program.count >= program.ops.len) return error.Unsupported;
        program.ops[program.count] = op;
        program.count += 1;
    }
};

var decoded_program: DecodedProgram = .{};

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
    max_pages: ?usize = null,

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
    max_entries: ?usize = null,

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

const Limits = struct {
    min: usize,
    max: ?usize = null,
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
    rotl,
    rotr,
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
    min,
    max,
    copysign,
};

const FloatUnaryOp = enum {
    abs,
    neg,
    ceil,
    floor,
    trunc,
    nearest,
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
    table_max_entries: ?usize = null,
    has_table: bool = false,
    element_segments: [max_data_segments]ElementSegment = undefined,
    element_segment_count: usize = 0,
    data_segments: [max_data_segments]DataSegment = undefined,
    data_segment_count: usize = 0,
    declared_data_count: ?usize = null,
    imported_memory: ?ImportedMemory = null,
    imported_table: ?ImportedTable = null,
    memory_min_pages: usize = 0,
    memory_max_pages: ?usize = null,
    has_memory: bool = false,
    start_function_index: ?usize = null,

    fn parse(bytes: []const u8) Error!Module {
        var module: Module = undefined;
        try parseInto(&module, bytes);
        return module;
    }

    fn parseInto(module: *Module, bytes: []const u8) Error!void {
        module.* = .{};
        decoded_program.reset();
        var reader = Reader{ .bytes = bytes };
        if (!byte_utils.eql(try reader.readBytes(wasm_magic.len), &wasm_magic)) return error.Corrupt;
        if (!byte_utils.eql(try reader.readBytes(wasm_version.len), &wasm_version)) return error.Corrupt;

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
            const module_name = try reader.readBytes(module_len);
            const name_len = try reader.readU32Leb();
            const import_name = try reader.readBytes(name_len);
            const kind = externalKindFromByte(try reader.readByte()) orelse return error.Unsupported;
            switch (kind) {
                .function => {
                    if (self.import_count >= max_imports) return error.Unsupported;
                    const type_index = try reader.readU32Leb();
                    if (type_index >= self.type_count) return error.Corrupt;
                    const imported = &self.imports[self.import_count];
                    imported.* = .{
                        .module = module_name,
                        .name = import_name,
                        .type_index = type_index,
                    };
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
        const limits = try readLimits(reader);
        const imported = ImportedMemory{
            .module = module_name,
            .name = import_name,
            .min_pages = limits.min,
            .max_pages = limits.max,
        };
        self.imported_memory = imported;
        self.has_memory = true;
        self.memory_min_pages = limits.min;
        self.memory_max_pages = limits.max;
    }

    fn parseTableImport(self: *Module, reader: *Reader, module_name: []const u8, import_name: []const u8) Error!void {
        if (self.imported_table != null or self.has_table) return error.Unsupported;
        const ref_type = try reader.readByte();
        if (ref_type != wasm_funcref_type) return error.Unsupported;
        const limits = try readLimits(reader);
        if (limits.min > max_table_entries) return error.Unsupported;
        if (limits.max) |max| {
            if (max > max_table_entries) return error.Unsupported;
        }
        const imported = ImportedTable{
            .module = module_name,
            .name = import_name,
            .min_entries = limits.min,
            .max_entries = limits.max,
        };
        self.imported_table = imported;
        self.has_table = true;
        self.table_min_entries = limits.min;
        self.table_max_entries = limits.max;
    }

    fn parseTableSection(self: *Module, reader: *Reader) Error!void {
        const count = try reader.readU32Leb();
        if (count > 1) return error.Unsupported;
        if (count == 0) return;
        if (self.imported_table != null) return error.Corrupt;
        const ref_type = try reader.readByte();
        if (ref_type != wasm_funcref_type) return error.Unsupported;
        const limits = try readLimits(reader);
        if (limits.min > max_table_entries) return error.Unsupported;
        if (limits.max) |max| {
            if (max > max_table_entries) return error.Unsupported;
        }
        self.has_table = true;
        self.table_min_entries = limits.min;
        self.table_max_entries = limits.max;
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
        const imported = ImportedGlobal{
            .module = module_name,
            .name = import_name,
            .global_index = global_index,
        };
        self.imported_globals[self.imported_global_count] = imported;
        self.imported_global_count += 1;
        self.global_count += 1;
    }

    fn parseMemorySection(self: *Module, reader: *Reader) Error!void {
        const count = try reader.readU32Leb();
        if (count > 1) return error.Unsupported;
        if (count == 0) return;
        if (self.imported_memory != null) return error.Corrupt;
        const limits = try readLimits(reader);
        self.memory_min_pages = limits.min;
        self.memory_max_pages = limits.max;
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
                .name = name,
                .kind = kind,
                .index = index,
            };
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
            code.decoded_start = decoded_program.count;
            try decodeCodeBody(code.body, self.type_count);
            code.decoded_count = decoded_program.count - code.decoded_start;
        }
    }

    fn parseDataSection(self: *Module, reader: *Reader) Error!void {
        const count = try reader.readU32Leb();
        if (count > max_data_segments) return error.Unsupported;
        self.data_segment_count = count;
        for (self.data_segments[0..count]) |*segment| {
            const mode = try reader.readU32Leb();
            switch (mode) {
                0 => segment.* = try parseActiveDataSegment(reader),
                1 => segment.* = try parsePassiveDataSegment(reader),
                2 => {
                    try readMemoryIndex(reader);
                    segment.* = try parseActiveDataSegment(reader);
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
            self.table_entries[base + function_index] = try self.readElementFunctionRef(reader, payload);
        }
    }

    fn parsePassiveFunctionElements(self: *Module, reader: *Reader, segment_index: usize, payload: ElementPayload) Error!void {
        const function_count = try readElementFunctionCount(reader, payload);
        const segment = &self.element_segments[segment_index];
        segment.passive = true;
        segment.count = function_count;
        var function_index: usize = 0;
        while (function_index < function_count) : (function_index += 1) {
            segment.entries[function_index] = try self.readElementFunctionRef(reader, payload);
        }
    }

    fn skipPassiveFunctionElements(self: *Module, reader: *Reader, payload: ElementPayload) Error!void {
        const function_count = try readElementFunctionCount(reader, payload);
        var function_index: usize = 0;
        while (function_index < function_count) : (function_index += 1) {
            _ = try self.readElementFunctionRef(reader, payload);
        }
    }

    fn readElementFunctionRef(self: *const Module, reader: *Reader, payload: ElementPayload) Error!usize {
        const function_ref = switch (payload) {
            .function_index_vector, .element_kind => try reader.readU32Leb(),
            .ref_func_expression_vector => try readRefFuncExpression(reader),
        };
        if (function_ref >= self.totalFunctionCount()) return error.Corrupt;
        return function_ref;
    }

    fn findExport(self: *const Module, name: []const u8) Error!usize {
        for (self.exports[0..self.export_count]) |exp| {
            if (exp.kind == .function and exp.matches(name)) return exp.index;
        }
        return error.MissingExport;
    }

    fn totalFunctionCount(self: *const Module) usize {
        return self.import_count + self.function_count;
    }

    fn typeIndexForFunction(self: *const Module, function_index: usize) Error!usize {
        if (function_index < self.import_count) return self.imports[function_index].type_index;
        const defined_index = function_index - self.import_count;
        if (defined_index >= self.function_count) return error.Corrupt;
        return self.functions[defined_index].type_index;
    }

    fn codeIndexForFunction(self: *const Module, function_index: usize) Error!usize {
        if (function_index < self.import_count) return error.MissingImport;
        const defined_index = function_index - self.import_count;
        if (defined_index >= self.function_count) return error.Corrupt;
        return self.functions[defined_index].code_index;
    }

    fn requiredMemoryBytes(self: *const Module) Error!usize {
        return pagesToBytes(self.memory_min_pages) orelse error.Unsupported;
    }

    fn resolveImports(self: *Module, runtime: Runtime) Error!void {
        for (self.imports[0..self.import_count]) |imported| {
            _ = try findHostImport(runtime, imported, .function);
        }
        if (self.imported_memory) |imported| {
            try validateImportedMemory(imported, try findHostImport(runtime, imported, .memory));
        }
        if (self.imported_table) |imported| {
            try validateImportedTable(imported, try findHostImport(runtime, imported, .table));
        }
        for (self.imported_globals[0..self.imported_global_count]) |imported| {
            try self.resolveImportedGlobal(imported, try findHostImport(runtime, imported, .global));
        }
    }

    fn resolveImportedGlobal(self: *Module, imported: ImportedGlobal, host: HostImport) Error!void {
        const global = &self.globals[imported.global_index];
        if (global.value_type != host.global_value_type or global.mutable != host.global_mutable) return error.Corrupt;
        if (!valueMatchesType(host.global_value, global.value_type)) return error.Corrupt;
        global.value = host.global_value;
    }

    fn applyDataSegments(self: *const Module, runtime: *Runtime, memory_pages: usize) Error!void {
        const limit = pagesToBytes(memory_pages) orelse return error.Unsupported;
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
    module: *Module,
    memory_pages: usize,
    memory_limit: usize,

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
            if (self.stack_len >= max_stack) return error.StackOverflow;
            self.stack[self.stack_len] = .{ .i32 = value };
            self.stack_len += 1;
        }

        fn pushI64(self: *Frame, value: i64) Error!void {
            if (self.stack_len >= max_stack) return error.StackOverflow;
            self.stack[self.stack_len] = .{ .i64 = value };
            self.stack_len += 1;
        }

        fn popI32(self: *Frame) Error!i32 {
            if (self.stack_len == 0) return error.StackUnderflow;
            self.stack_len -= 1;
            return switch (self.stack[self.stack_len]) {
                .i32 => |value| value,
                else => error.Corrupt,
            };
        }

        fn popI64(self: *Frame) Error!i64 {
            if (self.stack_len == 0) return error.StackUnderflow;
            self.stack_len -= 1;
            return switch (self.stack[self.stack_len]) {
                .i64 => |value| value,
                else => error.Corrupt,
            };
        }

        fn popF32(self: *Frame) Error!f32 {
            if (self.stack_len == 0) return error.StackUnderflow;
            self.stack_len -= 1;
            return switch (self.stack[self.stack_len]) {
                .f32 => |value| value,
                else => error.Corrupt,
            };
        }

        fn popF64(self: *Frame) Error!f64 {
            if (self.stack_len == 0) return error.StackUnderflow;
            self.stack_len -= 1;
            return switch (self.stack[self.stack_len]) {
                .f64 => |value| value,
                else => error.Corrupt,
            };
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
        if (self.runtime.trace) |trace| trace.enterFunction(depth);
        if (function_index < self.module.import_count) return try self.runImportedFunction(function_index, args);
        if (function_index >= self.module.totalFunctionCount()) return error.Corrupt;
        const function_type = self.module.types[try self.module.typeIndexForFunction(function_index)];
        if (!function_type.supportedResult()) return error.Unsupported;
        const code = self.module.code[try self.module.codeIndexForFunction(function_index)];
        var frame = try Frame.init(function_type, code, args);
        const local_limit = function_type.param_count + code.local_count;
        var controls: [max_control_depth]ControlFrame = undefined;
        var control_len: usize = 0;

        const trace = self.runtime.trace;
        var reader = Reader{ .bytes = code.body };
        var decoded_index = code.decoded_start;
        const decoded_end = code.decoded_start + code.decoded_count;
        while (!reader.done()) {
            if (!self.runtime.consumeExecution(1)) return error.NoExecution;
            const decoded = try decodedOpForOffset(code, &decoded_index, decoded_end, reader.offset);
            const opcode_byte = try reader.readByte();
            if (decoded.opcode_byte != opcode_byte) return error.Corrupt;
            if (opcode_byte == wasm_extended_prefix) {
                if (trace) |execution_trace| execution_trace.recordExtendedOpcode();
                try self.executeExtendedOpcode(&frame, &reader);
                continue;
            }
            switch (opcode_byte) {
                @intFromEnum(Opcode.local_get) => {
                    if (trace) |execution_trace| execution_trace.recordOpcode(opcode_byte, .local_get);
                    reader.offset = decoded.next_offset;
                    const index = decoded.imm0;
                    if (index >= local_limit) return error.Corrupt;
                    if (try self.tryRunLocalGetSuperInstruction(&frame, &reader, &decoded_index, decoded_end, decoded, index, local_limit, trace)) continue;
                    if (frame.stack_len >= max_stack) return error.StackOverflow;
                    frame.stack[frame.stack_len] = frame.locals[index];
                    frame.stack_len += 1;
                    continue;
                },
                @intFromEnum(Opcode.local_set) => {
                    if (trace) |execution_trace| execution_trace.recordOpcode(opcode_byte, .local_set);
                    reader.offset = decoded.next_offset;
                    const index = decoded.imm0;
                    if (index >= local_limit) return error.Corrupt;
                    if (frame.stack_len == 0) return error.StackUnderflow;
                    frame.stack_len -= 1;
                    frame.locals[index] = frame.stack[frame.stack_len];
                    continue;
                },
                @intFromEnum(Opcode.local_tee) => {
                    if (trace) |execution_trace| execution_trace.recordOpcode(opcode_byte, .local_tee);
                    reader.offset = decoded.next_offset;
                    const index = decoded.imm0;
                    if (index >= local_limit or frame.stack_len == 0) return error.Corrupt;
                    frame.locals[index] = frame.stack[frame.stack_len - 1];
                    continue;
                },
                @intFromEnum(Opcode.i32_const) => {
                    if (trace) |execution_trace| execution_trace.recordOpcode(opcode_byte, .i32_const);
                    reader.offset = decoded.next_offset;
                    const value: i32 = @bitCast(decoded.imm0);
                    if (frame.stack_len >= max_stack) return error.StackOverflow;
                    frame.stack[frame.stack_len] = .{ .i32 = value };
                    frame.stack_len += 1;
                    continue;
                },
                @intFromEnum(Opcode.i32_add) => {
                    if (trace) |execution_trace| execution_trace.recordOpcode(opcode_byte, .i32_add);
                    if (frame.stack_len < 2) return error.StackUnderflow;
                    frame.stack_len -= 1;
                    const right = switch (frame.stack[frame.stack_len]) {
                        .i32 => |value| value,
                        else => return error.Corrupt,
                    };
                    const left_index = frame.stack_len - 1;
                    const left = switch (frame.stack[left_index]) {
                        .i32 => |value| value,
                        else => return error.Corrupt,
                    };
                    frame.stack[left_index] = .{ .i32 = left +% right };
                    continue;
                },
                @intFromEnum(Opcode.i32_xor) => {
                    if (trace) |execution_trace| execution_trace.recordOpcode(opcode_byte, .i32_xor);
                    if (frame.stack_len < 2) return error.StackUnderflow;
                    frame.stack_len -= 1;
                    const right = switch (frame.stack[frame.stack_len]) {
                        .i32 => |value| value,
                        else => return error.Corrupt,
                    };
                    const left_index = frame.stack_len - 1;
                    const left = switch (frame.stack[left_index]) {
                        .i32 => |value| value,
                        else => return error.Corrupt,
                    };
                    frame.stack[left_index] = .{ .i32 = left ^ right };
                    continue;
                },
                @intFromEnum(Opcode.br_if) => {
                    if (trace) |execution_trace| execution_trace.recordOpcode(opcode_byte, .br_if);
                    reader.offset = decoded.next_offset;
                    const branch_depth = decoded.imm0;
                    if (frame.stack_len == 0) return error.StackUnderflow;
                    frame.stack_len -= 1;
                    const condition = switch (frame.stack[frame.stack_len]) {
                        .i32 => |value| value,
                        else => return error.Corrupt,
                    };
                    if (condition != 0) try branchToControl(&reader, &controls, &control_len, branch_depth, self.module.type_count);
                    continue;
                },
                @intFromEnum(Opcode.i32_load) => {
                    if (trace) |execution_trace| execution_trace.recordOpcode(opcode_byte, .i32_load);
                    reader.offset = decoded.next_offset;
                    const offset = decoded.imm1;
                    const address = try popAddress(&frame, offset);
                    const range = try self.memoryRange(address, i32_load_bytes);
                    if (frame.stack_len >= max_stack) return error.StackOverflow;
                    frame.stack[frame.stack_len] = .{ .i32 = @bitCast(byte_utils.load32(range).?) };
                    frame.stack_len += 1;
                    continue;
                },
                @intFromEnum(Opcode.i32_load8_u) => {
                    if (trace) |execution_trace| execution_trace.recordOpcode(opcode_byte, .i32_load8_u);
                    reader.offset = decoded.next_offset;
                    const offset = decoded.imm1;
                    const address = try popAddress(&frame, offset);
                    const range = try self.memoryRange(address, byte_load_bytes);
                    if (frame.stack_len >= max_stack) return error.StackOverflow;
                    frame.stack[frame.stack_len] = .{ .i32 = range[0] };
                    frame.stack_len += 1;
                    continue;
                },
                @intFromEnum(Opcode.i32_store8) => {
                    if (trace) |execution_trace| execution_trace.recordOpcode(opcode_byte, .i32_store8);
                    reader.offset = decoded.next_offset;
                    const offset = decoded.imm1;
                    if (frame.stack_len < 2) return error.StackUnderflow;
                    frame.stack_len -= 1;
                    const value = switch (frame.stack[frame.stack_len]) {
                        .i32 => |stack_value| stack_value,
                        else => return error.Corrupt,
                    };
                    frame.stack_len -= 1;
                    const base: u32 = switch (frame.stack[frame.stack_len]) {
                        .i32 => |stack_value| @bitCast(stack_value),
                        else => return error.Corrupt,
                    };
                    const address = checkedAdd(@as(usize, base), offset) orelse return error.NoMemory;
                    const range = try self.memoryRange(address, byte_load_bytes);
                    range[0] = @truncate(@as(u32, @bitCast(value)));
                    continue;
                },
                else => {},
            }
            const opcode = opcodeFromByte(opcode_byte) orelse return error.Unsupported;
            if (trace) |execution_trace| execution_trace.recordOpcode(opcode_byte, opcode);
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
                    try readBlockType(&reader, self.module.type_count);
                    try pushControl(&controls, &control_len, .block, reader.offset);
                },
                .loop => {
                    try readBlockType(&reader, self.module.type_count);
                    try pushControl(&controls, &control_len, .loop, reader.offset);
                },
                .@"if" => {
                    try readBlockType(&reader, self.module.type_count);
                    const condition = try frame.popI32();
                    if (condition == 0) {
                        const skip_result = try skipUntakenIf(&reader, self.module.type_count);
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
                    try skipControlDepth(&reader, 0, self.module.type_count);
                    control_len -= 1;
                },
                .br => {
                    const branch_depth = try reader.readU32Leb();
                    try branchToControl(&reader, &controls, &control_len, branch_depth, self.module.type_count);
                },
                .br_if => {
                    const branch_depth = try reader.readU32Leb();
                    const condition = try frame.popI32();
                    if (condition != 0) try branchToControl(&reader, &controls, &control_len, branch_depth, self.module.type_count);
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
                    try branchToControl(&reader, &controls, &control_len, selected_target orelse default_target, self.module.type_count);
                },
                .i64_const => try frame.pushI64(try reader.readI64Leb()),
                .i32_const => try frame.pushI32(try reader.readI32Leb()),
                .f32_const => try frame.push(.{ .f32 = try reader.readF32() }),
                .f64_const => try frame.push(.{ .f64 = try reader.readF64() }),
                .i64_add => try pushIntegerBinary(i64, &frame, .add),
                .i64_sub => try pushIntegerBinary(i64, &frame, .sub),
                .i64_mul => try pushIntegerBinary(i64, &frame, .mul),
                .i64_div_s => try pushIntegerBinary(i64, &frame, .div_s),
                .i64_div_u => try pushIntegerBinary(i64, &frame, .div_u),
                .i64_rem_s => try pushIntegerBinary(i64, &frame, .rem_s),
                .i64_rem_u => try pushIntegerBinary(i64, &frame, .rem_u),
                .i64_and => try pushIntegerBinary(i64, &frame, .@"and"),
                .i64_or => try pushIntegerBinary(i64, &frame, .@"or"),
                .i64_xor => try pushIntegerBinary(i64, &frame, .xor),
                .i64_shl => try pushIntegerBinary(i64, &frame, .shl),
                .i64_shr_s => try pushIntegerBinary(i64, &frame, .shr_s),
                .i64_shr_u => try pushIntegerBinary(i64, &frame, .shr_u),
                .i64_rotl => try pushIntegerBinary(i64, &frame, .rotl),
                .i64_rotr => try pushIntegerBinary(i64, &frame, .rotr),
                .i64_clz => try pushIntegerUnary(i64, &frame, .clz),
                .i64_ctz => try pushIntegerUnary(i64, &frame, .ctz),
                .i64_popcnt => try pushIntegerUnary(i64, &frame, .popcnt),
                .i64_eqz => {
                    const value = try frame.popI64();
                    try frame.pushI32(if (value == 0) 1 else 0);
                },
                .i64_eq => try pushIntegerComparison(i64, &frame, .eq),
                .i64_ne => try pushIntegerComparison(i64, &frame, .ne),
                .i64_lt_s => try pushIntegerComparison(i64, &frame, .lt_s),
                .i64_lt_u => try pushIntegerComparison(i64, &frame, .lt_u),
                .i64_gt_s => try pushIntegerComparison(i64, &frame, .gt_s),
                .i64_gt_u => try pushIntegerComparison(i64, &frame, .gt_u),
                .i64_le_s => try pushIntegerComparison(i64, &frame, .le_s),
                .i64_le_u => try pushIntegerComparison(i64, &frame, .le_u),
                .i64_ge_s => try pushIntegerComparison(i64, &frame, .ge_s),
                .i64_ge_u => try pushIntegerComparison(i64, &frame, .ge_u),
                .f32_eq => try pushFloatComparison(f32, &frame, .eq),
                .f32_ne => try pushFloatComparison(f32, &frame, .ne),
                .f32_lt => try pushFloatComparison(f32, &frame, .lt),
                .f32_gt => try pushFloatComparison(f32, &frame, .gt),
                .f32_le => try pushFloatComparison(f32, &frame, .le),
                .f32_ge => try pushFloatComparison(f32, &frame, .ge),
                .f64_eq => try pushFloatComparison(f64, &frame, .eq),
                .f64_ne => try pushFloatComparison(f64, &frame, .ne),
                .f64_lt => try pushFloatComparison(f64, &frame, .lt),
                .f64_gt => try pushFloatComparison(f64, &frame, .gt),
                .f64_le => try pushFloatComparison(f64, &frame, .le),
                .f64_ge => try pushFloatComparison(f64, &frame, .ge),
                .i32_eqz => {
                    const value = try frame.popI32();
                    try frame.pushI32(if (value == 0) 1 else 0);
                },
                .i32_eq => try pushIntegerComparison(i32, &frame, .eq),
                .i32_ne => try pushIntegerComparison(i32, &frame, .ne),
                .i32_lt_s => try pushIntegerComparison(i32, &frame, .lt_s),
                .i32_lt_u => try pushIntegerComparison(i32, &frame, .lt_u),
                .i32_gt_s => try pushIntegerComparison(i32, &frame, .gt_s),
                .i32_gt_u => try pushIntegerComparison(i32, &frame, .gt_u),
                .i32_le_s => try pushIntegerComparison(i32, &frame, .le_s),
                .i32_le_u => try pushIntegerComparison(i32, &frame, .le_u),
                .i32_ge_s => try pushIntegerComparison(i32, &frame, .ge_s),
                .i32_ge_u => try pushIntegerComparison(i32, &frame, .ge_u),
                .i32_add => try pushIntegerBinary(i32, &frame, .add),
                .i32_sub => try pushIntegerBinary(i32, &frame, .sub),
                .i32_mul => try pushIntegerBinary(i32, &frame, .mul),
                .i32_div_s => try pushIntegerBinary(i32, &frame, .div_s),
                .i32_div_u => try pushIntegerBinary(i32, &frame, .div_u),
                .i32_rem_s => try pushIntegerBinary(i32, &frame, .rem_s),
                .i32_rem_u => try pushIntegerBinary(i32, &frame, .rem_u),
                .i32_and => try pushIntegerBinary(i32, &frame, .@"and"),
                .i32_or => try pushIntegerBinary(i32, &frame, .@"or"),
                .i32_xor => try pushIntegerBinary(i32, &frame, .xor),
                .i32_shl => try pushIntegerBinary(i32, &frame, .shl),
                .i32_shr_s => try pushIntegerBinary(i32, &frame, .shr_s),
                .i32_shr_u => try pushIntegerBinary(i32, &frame, .shr_u),
                .i32_rotl => try pushIntegerBinary(i32, &frame, .rotl),
                .i32_rotr => try pushIntegerBinary(i32, &frame, .rotr),
                .i32_clz => try pushIntegerUnary(i32, &frame, .clz),
                .i32_ctz => try pushIntegerUnary(i32, &frame, .ctz),
                .i32_popcnt => try pushIntegerUnary(i32, &frame, .popcnt),
                .f32_abs => try pushFloatUnary(f32, &frame, .abs),
                .f32_neg => try pushFloatUnary(f32, &frame, .neg),
                .f32_ceil => try pushFloatUnary(f32, &frame, .ceil),
                .f32_floor => try pushFloatUnary(f32, &frame, .floor),
                .f32_trunc => try pushFloatUnary(f32, &frame, .trunc),
                .f32_nearest => try pushFloatUnary(f32, &frame, .nearest),
                .f32_sqrt => try pushFloatUnary(f32, &frame, .sqrt),
                .f32_add => try pushFloatBinary(f32, &frame, .add),
                .f32_sub => try pushFloatBinary(f32, &frame, .sub),
                .f32_mul => try pushFloatBinary(f32, &frame, .mul),
                .f32_div => try pushFloatBinary(f32, &frame, .div),
                .f32_min => try pushFloatBinary(f32, &frame, .min),
                .f32_max => try pushFloatBinary(f32, &frame, .max),
                .f32_copysign => try pushFloatBinary(f32, &frame, .copysign),
                .f64_abs => try pushFloatUnary(f64, &frame, .abs),
                .f64_neg => try pushFloatUnary(f64, &frame, .neg),
                .f64_ceil => try pushFloatUnary(f64, &frame, .ceil),
                .f64_floor => try pushFloatUnary(f64, &frame, .floor),
                .f64_trunc => try pushFloatUnary(f64, &frame, .trunc),
                .f64_nearest => try pushFloatUnary(f64, &frame, .nearest),
                .f64_sqrt => try pushFloatUnary(f64, &frame, .sqrt),
                .f64_add => try pushFloatBinary(f64, &frame, .add),
                .f64_sub => try pushFloatBinary(f64, &frame, .sub),
                .f64_mul => try pushFloatBinary(f64, &frame, .mul),
                .f64_div => try pushFloatBinary(f64, &frame, .div),
                .f64_min => try pushFloatBinary(f64, &frame, .min),
                .f64_max => try pushFloatBinary(f64, &frame, .max),
                .f64_copysign => try pushFloatBinary(f64, &frame, .copysign),
                .i32_wrap_i64 => {
                    const value = try frame.popI64();
                    try frame.pushI32(@bitCast(@as(u32, @truncate(@as(u64, @bitCast(value))))));
                },
                .i32_trunc_f32_s => try frame.pushI32(try truncFloatToInt(f32, i32, try frame.popF32())),
                .i32_trunc_f32_u => try frame.pushI32(@bitCast(try truncFloatToInt(f32, u32, try frame.popF32()))),
                .i32_trunc_f64_s => try frame.pushI32(try truncFloatToInt(f64, i32, try frame.popF64())),
                .i32_trunc_f64_u => try frame.pushI32(@bitCast(try truncFloatToInt(f64, u32, try frame.popF64()))),
                .i64_extend_i32_s => {
                    const value = try frame.popI32();
                    try frame.pushI64(value);
                },
                .i64_extend_i32_u => {
                    const value: u32 = @bitCast(try frame.popI32());
                    try frame.pushI64(@intCast(value));
                },
                .i64_trunc_f32_s => try frame.pushI64(try truncFloatToInt(f32, i64, try frame.popF32())),
                .i64_trunc_f32_u => try frame.pushI64(@bitCast(try truncFloatToInt(f32, u64, try frame.popF32()))),
                .i64_trunc_f64_s => try frame.pushI64(try truncFloatToInt(f64, i64, try frame.popF64())),
                .i64_trunc_f64_u => try frame.pushI64(@bitCast(try truncFloatToInt(f64, u64, try frame.popF64()))),
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
            ext_i32_trunc_sat_f32_s => try frame.pushI32(saturatingTruncFloatToInt(f32, i32, try frame.popF32())),
            ext_i32_trunc_sat_f32_u => try frame.pushI32(@bitCast(saturatingTruncFloatToInt(f32, u32, try frame.popF32()))),
            ext_i32_trunc_sat_f64_s => try frame.pushI32(saturatingTruncFloatToInt(f64, i32, try frame.popF64())),
            ext_i32_trunc_sat_f64_u => try frame.pushI32(@bitCast(saturatingTruncFloatToInt(f64, u32, try frame.popF64()))),
            ext_i64_trunc_sat_f32_s => try frame.pushI64(saturatingTruncFloatToInt(f32, i64, try frame.popF32())),
            ext_i64_trunc_sat_f32_u => try frame.pushI64(@bitCast(saturatingTruncFloatToInt(f32, u64, try frame.popF32()))),
            ext_i64_trunc_sat_f64_s => try frame.pushI64(saturatingTruncFloatToInt(f64, i64, try frame.popF64())),
            ext_i64_trunc_sat_f64_u => try frame.pushI64(@bitCast(saturatingTruncFloatToInt(f64, u64, try frame.popF64()))),
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
        const table_entry = try popTableEntry(frame);
        if (table_entry >= self.module.table_min_entries) return error.Trap;
        const function_index = self.module.table_entries[table_entry] orelse return error.Trap;
        const expected_type = self.module.types[type_index];
        const actual_type = self.module.types[try self.module.typeIndexForFunction(function_index)];
        if (!actual_type.eql(expected_type)) return error.Trap;
        return try self.callFunctionFromFrame(frame, function_index, depth);
    }

    fn tableGet(self: *Executor, frame: *Frame, reader: *Reader) Error!void {
        try readTableIndex(reader);
        const table_entry = try popTableEntry(frame);
        if (table_entry >= self.module.table_min_entries) return error.Trap;
        try frame.push(.{ .funcref = self.module.table_entries[table_entry] });
    }

    fn tableSet(self: *Executor, frame: *Frame, reader: *Reader) Error!void {
        try readTableIndex(reader);
        const function_ref = try frame.popFuncref();
        const table_entry = try popTableEntry(frame);
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
        if (self.runtime.trace) |trace| trace.imported_calls += 1;
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

    fn tryRunLocalGetSuperInstruction(
        self: *Executor,
        frame: *Frame,
        reader: *Reader,
        decoded_index: *usize,
        decoded_end: usize,
        decoded: DecodedOp,
        local_index: u32,
        local_limit: usize,
        trace: ?*ExecutionTrace,
    ) Error!bool {
        const first = nextStraightDecoded(decoded_index.*, decoded_end, decoded.next_offset) orelse return false;
        switch (first.opcode_byte) {
            @intFromEnum(Opcode.i32_const) => {
                const second = nextStraightDecoded(decoded_index.* + 1, decoded_end, first.next_offset) orelse return false;
                if (second.opcode_byte != @intFromEnum(Opcode.i32_add)) return false;
                if (!self.runtime.consumeExecution(2)) return error.NoExecution;
                if (trace) |execution_trace| {
                    execution_trace.recordOpcode(first.opcode_byte, .i32_const);
                    execution_trace.recordOpcode(second.opcode_byte, .i32_add);
                }
                const left = try localI32(frame, local_index);
                const right: i32 = @bitCast(first.imm0);
                if (frame.stack_len >= max_stack) return error.StackOverflow;
                frame.stack[frame.stack_len] = .{ .i32 = left +% right };
                frame.stack_len += 1;
                reader.offset = second.next_offset;
                decoded_index.* += 2;
                return true;
            },
            @intFromEnum(Opcode.local_get) => {
                const second_index = first.imm0;
                if (second_index >= local_limit) return error.Corrupt;
                const second = nextStraightDecoded(decoded_index.* + 1, decoded_end, first.next_offset) orelse return false;
                const op: Opcode = switch (second.opcode_byte) {
                    @intFromEnum(Opcode.i32_add) => .i32_add,
                    @intFromEnum(Opcode.i32_xor) => .i32_xor,
                    else => return false,
                };
                if (!self.runtime.consumeExecution(2)) return error.NoExecution;
                if (trace) |execution_trace| {
                    execution_trace.recordOpcode(first.opcode_byte, .local_get);
                    execution_trace.recordOpcode(second.opcode_byte, op);
                }
                const left = try localI32(frame, local_index);
                const right = try localI32(frame, second_index);
                if (frame.stack_len >= max_stack) return error.StackOverflow;
                frame.stack[frame.stack_len] = .{ .i32 = switch (op) {
                    .i32_add => left +% right,
                    .i32_xor => left ^ right,
                    else => unreachable,
                } };
                frame.stack_len += 1;
                reader.offset = second.next_offset;
                decoded_index.* += 2;
                return true;
            },
            @intFromEnum(Opcode.i32_load), @intFromEnum(Opcode.i32_load8_u) => {
                const op: Opcode = if (first.opcode_byte == @intFromEnum(Opcode.i32_load)) .i32_load else .i32_load8_u;
                if (!self.runtime.consumeExecution(1)) return error.NoExecution;
                if (trace) |execution_trace| execution_trace.recordOpcode(first.opcode_byte, op);
                const base: u32 = @bitCast(try localI32(frame, local_index));
                const address = checkedAdd(@as(usize, base), first.imm1) orelse return error.NoMemory;
                const size: usize = switch (op) {
                    .i32_load => i32_load_bytes,
                    .i32_load8_u => byte_load_bytes,
                    else => unreachable,
                };
                const range = try self.memoryRange(address, size);
                if (frame.stack_len >= max_stack) return error.StackOverflow;
                const loaded: i32 = switch (op) {
                    .i32_load => @bitCast(byte_utils.load32(range).?),
                    .i32_load8_u => range[0],
                    else => unreachable,
                };
                frame.stack[frame.stack_len] = .{ .i32 = loaded };
                frame.stack_len += 1;
                reader.offset = first.next_offset;
                decoded_index.* += 1;
                return true;
            },
            else => return false,
        }
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
        const previous_bytes = self.memory_limit;
        const requested_pages = checkedAdd(previous_pages, @intCast(delta)) orelse {
            try frame.pushI32(-1);
            return;
        };
        if (self.module.memory_max_pages) |max_pages| {
            if (requested_pages > max_pages) {
                try frame.pushI32(-1);
                return;
            }
        }
        const requested_bytes = pagesToBytes(requested_pages) orelse {
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
        self.memory_limit = requested_bytes;
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
        if (self.module.table_max_entries) |max_entries| {
            if (requested_entries > max_entries) {
                try frame.pushI32(-1);
                return;
            }
        }
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
        const end = checkedAdd(address, size) orelse return error.NoMemory;
        if (end > self.memory_limit or end > self.runtime.memory.len) return error.NoMemory;
        return self.runtime.memory[address..end];
    }

    fn pushControl(controls: *[max_control_depth]ControlFrame, control_len: *usize, kind: ControlKind, start: usize) Error!void {
        if (control_len.* >= max_control_depth) return error.Unsupported;
        controls[control_len.*] = .{ .kind = kind, .start = start };
        control_len.* += 1;
    }

    fn branchToControl(reader: *Reader, controls: *[max_control_depth]ControlFrame, control_len: *usize, branch_depth: u32, type_count: usize) Error!void {
        if (branch_depth >= control_len.*) return error.Corrupt;
        const target_index = control_len.* - 1 - @as(usize, @intCast(branch_depth));
        const target = controls[target_index];
        switch (target.kind) {
            .loop => {
                reader.offset = target.start;
                control_len.* = target_index + 1;
            },
            .block, .if_then, .if_else => {
                try skipControlDepth(reader, branch_depth, type_count);
                control_len.* = target_index;
            },
        }
    }
};

fn decodedOpForOffset(code: Code, decoded_index: *usize, decoded_end: usize, offset: usize) Error!DecodedOp {
    if (decoded_index.* < decoded_end) {
        const op = decoded_program.ops[decoded_index.*];
        if (op.offset == offset) {
            decoded_index.* += 1;
            return op;
        }
    }
    var low = code.decoded_start;
    var high = decoded_end;
    while (low < high) {
        const mid = low + (high - low) / 2;
        const op = decoded_program.ops[mid];
        if (op.offset < offset) {
            low = mid + 1;
        } else if (op.offset > offset) {
            high = mid;
        } else {
            decoded_index.* = mid + 1;
            return op;
        }
    }
    return error.Corrupt;
}

fn nextStraightDecoded(index: usize, decoded_end: usize, expected_offset: u32) ?DecodedOp {
    if (index >= decoded_end) return null;
    const op = decoded_program.ops[index];
    if (op.offset != expected_offset) return null;
    return op;
}

fn localI32(frame: *const Executor.Frame, index: usize) Error!i32 {
    return switch (frame.locals[index]) {
        .i32 => |value| value,
        else => error.Corrupt,
    };
}

pub const ExecutionStorage = struct {
    module: Module = .{},
    executor: Executor = undefined,
    value_args: [max_type_params]Value = undefined,
    prepared: bool = false,
    start_ran: bool = false,
};

pub fn executeExportI64(runtime: *Runtime, wasm_bytes: []const u8, export_name: []const u8) Error!i64 {
    return executeExportI64Args(runtime, wasm_bytes, export_name, &.{});
}

pub fn executeExportI64Args(runtime: *Runtime, wasm_bytes: []const u8, export_name: []const u8, args: []const i64) Error!i64 {
    return (try executeExportValuesArgs(runtime, wasm_bytes, export_name, args)).onlyI64();
}

pub fn executeExportI64ArgsWithStorage(runtime: *Runtime, wasm_bytes: []const u8, export_name: []const u8, args: []const i64, storage: *ExecutionStorage) Error!i64 {
    return (try executeExportValuesArgsWithStorage(runtime, wasm_bytes, export_name, args, storage)).onlyI64();
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
    var storage = ExecutionStorage{};
    return executeExportValuesArgsWithStorage(runtime, wasm_bytes, export_name, args, &storage);
}

pub fn executeExportValuesArgsWithStorage(runtime: *Runtime, wasm_bytes: []const u8, export_name: []const u8, args: []const i64, storage: *ExecutionStorage) Error!ExecutionResult {
    if (export_name.len == 0) return error.BadArgument;
    if (args.len > max_type_params) return error.BadArgument;
    const executor = try executorForWithStorage(runtime, wasm_bytes, storage);
    const prepared_args = try integerArgsForExport(executor.module, export_name, args, &storage.value_args);
    try runStartOnce(storage, executor);
    return executor.runExport(export_name, prepared_args);
}

pub fn executeExportValueArgs(runtime: *Runtime, wasm_bytes: []const u8, export_name: []const u8, args: []const Value) Error!ExecutionResult {
    if (export_name.len == 0) return error.BadArgument;
    var storage = ExecutionStorage{};
    return executeExportValueArgsWithStorage(runtime, wasm_bytes, export_name, args, &storage);
}

pub fn executeExportValueArgsWithStorage(runtime: *Runtime, wasm_bytes: []const u8, export_name: []const u8, args: []const Value, storage: *ExecutionStorage) Error!ExecutionResult {
    if (export_name.len == 0) return error.BadArgument;
    const executor = try executorForWithStorage(runtime, wasm_bytes, storage);
    try runStartOnce(storage, executor);
    return executor.runExport(export_name, args);
}

fn executorForWithStorage(runtime: *Runtime, wasm_bytes: []const u8, storage: *ExecutionStorage) Error!*Executor {
    if (!storage.prepared) {
        try Module.parseInto(&storage.module, wasm_bytes);
        try storage.module.resolveImports(runtime.*);
        if (storage.module.global_count > 0 and storage.module.globals[0].mutable and storage.module.globals[0].value_type == .i32) {
            const sp_end = runtime.memoryLen();
            if (sp_end > 64 * 1024) {
                storage.module.globals[0].value.i32 = @intCast(sp_end - 64 * 1024);
            }
        }
    }
    const memory_pages = try initialMemoryPages(runtime.*, &storage.module);
    const required_memory = pagesToBytes(memory_pages) orelse return error.Unsupported;
    if (required_memory > runtime.memoryLen()) return error.NoMemory;
    if (!storage.prepared) {
        try storage.module.applyDataSegments(runtime, memory_pages);
        storage.prepared = true;
    }
    storage.executor = .{
        .runtime = runtime,
        .module = &storage.module,
        .memory_pages = memory_pages,
        .memory_limit = required_memory,
    };
    return &storage.executor;
}

fn runStartOnce(storage: *ExecutionStorage, executor: *Executor) Error!void {
    if (storage.start_ran) return;
    try executor.runStart();
    storage.start_ran = true;
}

fn initialMemoryPages(runtime: Runtime, module: *const Module) Error!usize {
    const pages = runtime.initial_memory_pages orelse return module.memory_min_pages;
    if (pages < module.memory_min_pages) return error.NoMemory;
    if (module.memory_max_pages) |max_pages| {
        if (pages > max_pages) return error.NoMemory;
    }
    return pages;
}

fn integerArgsForExport(module: *const Module, export_name: []const u8, args: []const i64, out: *[max_type_params]Value) Error![]const Value {
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
    return popNonNegativeUsize(frame, error.NoMemory);
}

fn popMemoryLength(frame: *Executor.Frame) Error!usize {
    return popNonNegativeUsize(frame, error.NoMemory);
}

fn popTableEntry(frame: *Executor.Frame) Error!usize {
    return popNonNegativeUsize(frame, error.Trap);
}

fn popNonNegativeUsize(frame: *Executor.Frame, negative_error: Error) Error!usize {
    const value = try frame.popI32();
    if (value < 0) return negative_error;
    return @intCast(value);
}

fn copyMemory(destination: []u8, source: []const u8) void {
    copyOverlapping(u8, destination, source);
}

fn copyTable(destination: []?usize, source: []const ?usize) void {
    copyOverlapping(?usize, destination, source);
}

fn copyOverlapping(comptime Item: type, destination: []Item, source: []const Item) void {
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

fn pagesToBytes(pages: usize) ?usize {
    if (pages > (maxUnsigned(usize) >> wasm_page_shift)) return null;
    return pages << wasm_page_shift;
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

fn readLimits(reader: *Reader) Error!Limits {
    const tag = try reader.readByte();
    return switch (tag) {
        limits_min_only => .{ .min = try reader.readU32Leb() },
        limits_min_max => limits: {
            const min = try reader.readU32Leb();
            const max = try reader.readU32Leb();
            if (max < min) return error.Corrupt;
            break :limits .{ .min = min, .max = max };
        },
        else => error.Unsupported,
    };
}

fn parseActiveDataSegment(reader: *Reader) Error!DataSegment {
    const offset = try readConstantI32Expression(reader);
    if (offset < 0) return error.NoMemory;
    const byte_count = try reader.readU32Leb();
    return .{
        .offset = @intCast(offset),
        .bytes = try reader.readBytes(byte_count),
        .active = true,
    };
}

fn parsePassiveDataSegment(reader: *Reader) Error!DataSegment {
    const byte_count = try reader.readU32Leb();
    return .{
        .bytes = try reader.readBytes(byte_count),
        .active = false,
    };
}

fn findHostImport(runtime: Runtime, imported: anytype, kind: HostImportKind) Error!HostImport {
    for (runtime.imports) |host| {
        if (host.kind != kind) continue;
        if (imported.matches(host)) return host;
    }
    return error.MissingImport;
}

fn validateImportedMemory(imported: ImportedMemory, host: HostImport) Error!void {
    if (host.memory_min_pages < imported.min_pages) return error.NoMemory;
    if (imported.max_pages) |imported_max| {
        const host_max = host.memory_max_pages orelse return error.Corrupt;
        if (host_max > imported_max) return error.Corrupt;
    }
}

fn validateImportedTable(imported: ImportedTable, host: HostImport) Error!void {
    if (host.table_min_entries < imported.min_entries) return error.NoMemory;
    if (imported.max_entries) |imported_max| {
        const host_max = host.table_max_entries orelse return error.Corrupt;
        if (host_max > imported_max) return error.Corrupt;
    }
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
    return opcode_table[value];
}

const opcode_table = buildOpcodeTable();

fn buildOpcodeTable() [256]?Opcode {
    @setEvalBranchQuota(4096);
    var table = [_]?Opcode{null} ** 256;
    for (@typeInfo(Opcode).@"enum".fields) |field| {
        table[@intCast(field.value)] = @enumFromInt(field.value);
    }
    return table;
}

fn parseEmptySection(reader: *Reader) Error!void {
    const count = try reader.readU32Leb();
    if (count != 0 or !reader.done()) return error.Unsupported;
}

fn readBlockType(reader: *Reader, type_count: usize) Error!void {
    const block_type = try reader.readByte();
    if (block_type == wasm_empty_block_type) return;
    if (valueTypeFromByte(block_type)) |value_type| {
        if (!supportedValue(value_type)) return error.Unsupported;
        return;
    }
    const type_index = try readBlockTypeIndex(reader, block_type);
    if (type_index >= type_count) return error.Corrupt;
}

fn readBlockTypeIndex(reader: *Reader, first_byte: u8) Error!usize {
    var result: u32 = first_byte & leb_payload_mask;
    if ((first_byte & leb_continue_mask) == 0) return result;
    var shift: u5 = leb_bits_per_byte;
    var count: usize = 1;
    while (count < leb32_max_bytes) : (count += 1) {
        const byte = try reader.readByte();
        result |= @as(u32, byte & leb_payload_mask) << shift;
        if ((byte & leb_continue_mask) == 0) return result;
        shift += leb_bits_per_byte;
    }
    return error.Corrupt;
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

fn skipUntakenIf(reader: *Reader, type_count: usize) Error!IfSkipResult {
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
                try readBlockType(reader, type_count);
                depth += 1;
            },
            .@"else" => {
                if (depth == 0) return .reached_else;
            },
            .end => {
                if (depth == 0) return .reached_end;
                depth -= 1;
            },
            else => try skipOpcodeImmediate(reader, opcode, type_count),
        }
    }
    return error.Corrupt;
}

fn skipControlDepth(reader: *Reader, branch_depth: u32, type_count: usize) Error!void {
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
                try readBlockType(reader, type_count);
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
            else => try skipOpcodeImmediate(reader, opcode, type_count),
        }
    }
    return error.Corrupt;
}

fn decodeCodeBody(body: []const u8, type_count: usize) Error!void {
    var reader = Reader{ .bytes = body };
    while (!reader.done()) {
        const offset = reader.offset;
        const opcode_byte = try reader.readByte();
        var decoded = DecodedOp{
            .offset = @intCast(offset),
            .opcode_byte = opcode_byte,
        };
        if (opcode_byte == wasm_extended_prefix) {
            try skipExtendedOpcodeImmediate(&reader);
            decoded.next_offset = @intCast(reader.offset);
            try decoded_program.append(decoded);
            continue;
        }
        const opcode = opcodeFromByte(opcode_byte) orelse return error.Unsupported;
        switch (opcode) {
            .block, .loop, .@"if" => try readBlockType(&reader, type_count),
            .br, .br_if, .call, .local_get, .local_set, .local_tee, .global_get, .global_set => {
                decoded.imm0 = try reader.readU32Leb();
            },
            .br_table => {
                const target_count = try reader.readU32Leb();
                var target_index: u32 = 0;
                while (target_index < target_count) : (target_index += 1) _ = try reader.readU32Leb();
                _ = try reader.readU32Leb();
            },
            .call_indirect => {
                decoded.imm0 = try reader.readU32Leb();
                decoded.imm1 = try reader.readU32Leb();
            },
            .select_typed => _ = try readSelectType(&reader),
            .table_get, .table_set => try readTableIndex(&reader),
            .memory_size, .memory_grow => try readMemoryIndex(&reader),
            .i32_load, .i64_load, .f32_load, .f64_load, .i32_load8_s, .i32_load8_u, .i32_load16_s, .i32_load16_u, .i64_load8_s, .i64_load8_u, .i64_load16_s, .i64_load16_u, .i64_load32_s, .i64_load32_u, .i32_store, .i64_store, .f32_store, .f64_store, .i32_store8, .i32_store16, .i64_store8, .i64_store16, .i64_store32 => {
                decoded.imm0 = try reader.readU32Leb();
                decoded.imm1 = try reader.readU32Leb();
            },
            .i32_const => decoded.imm0 = @bitCast(try reader.readI32Leb()),
            .i64_const => _ = try reader.readI64Leb(),
            .f32_const => _ = try reader.readF32(),
            .f64_const => _ = try reader.readF64(),
            .ref_null => _ = try reader.readByte(),
            .ref_func => decoded.imm0 = try reader.readU32Leb(),
            else => {},
        }
        decoded.next_offset = @intCast(reader.offset);
        try decoded_program.append(decoded);
    }
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

fn skipOpcodeImmediate(reader: *Reader, opcode: Opcode, type_count: usize) Error!void {
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
        .block, .loop, .@"if" => try readBlockType(reader, type_count),
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
        .i32_rotl,
        .i32_rotr,
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
        .i64_rotl,
        .i64_rotr,
        .i64_clz,
        .i64_ctz,
        .i64_popcnt,
        .f32_abs,
        .f32_neg,
        .f32_ceil,
        .f32_floor,
        .f32_trunc,
        .f32_nearest,
        .f32_sqrt,
        .f32_add,
        .f32_sub,
        .f32_mul,
        .f32_div,
        .f32_min,
        .f32_max,
        .f32_copysign,
        .f64_abs,
        .f64_neg,
        .f64_ceil,
        .f64_floor,
        .f64_trunc,
        .f64_nearest,
        .f64_sqrt,
        .f64_add,
        .f64_sub,
        .f64_mul,
        .f64_div,
        .f64_min,
        .f64_max,
        .f64_copysign,
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

fn pushIntegerBinary(comptime Int: type, frame: *Executor.Frame, op: BinaryOp) Error!void {
    const right = try popInteger(Int, frame);
    const left = try popInteger(Int, frame);
    try pushInteger(Int, frame, try applyIntegerBinary(Int, op, left, right));
}

fn pushFloatBinary(comptime Float: type, frame: *Executor.Frame, op: FloatBinaryOp) Error!void {
    const right = try popFloat(Float, frame);
    const left = try popFloat(Float, frame);
    try pushFloat(Float, frame, applyFloatBinary(Float, op, left, right));
}

fn pushIntegerUnary(comptime Int: type, frame: *Executor.Frame, op: UnaryOp) Error!void {
    try pushInteger(Int, frame, applyIntegerUnary(Int, op, try popInteger(Int, frame)));
}

fn pushFloatUnary(comptime Float: type, frame: *Executor.Frame, op: FloatUnaryOp) Error!void {
    try pushFloat(Float, frame, applyFloatUnary(Float, op, try popFloat(Float, frame)));
}

fn popInteger(comptime Int: type, frame: *Executor.Frame) Error!Int {
    return switch (Int) {
        i32 => try frame.popI32(),
        i64 => try frame.popI64(),
        else => @compileError("unsupported wasm integer type"),
    };
}

fn pushInteger(comptime Int: type, frame: *Executor.Frame, value: Int) Error!void {
    switch (Int) {
        i32 => try frame.pushI32(value),
        i64 => try frame.pushI64(value),
        else => @compileError("unsupported wasm integer type"),
    }
}

fn popFloat(comptime Float: type, frame: *Executor.Frame) Error!Float {
    return switch (Float) {
        f32 => try frame.popF32(),
        f64 => try frame.popF64(),
        else => @compileError("unsupported wasm float type"),
    };
}

fn pushFloat(comptime Float: type, frame: *Executor.Frame, value: Float) Error!void {
    switch (Float) {
        f32 => try frame.push(.{ .f32 = value }),
        f64 => try frame.push(.{ .f64 = value }),
        else => @compileError("unsupported wasm float type"),
    }
}

fn applyIntegerUnary(comptime Int: type, op: UnaryOp, value: Int) Int {
    const Unsigned = unsignedFor(Int);
    const unsigned = @as(Unsigned, @bitCast(value));
    const result = switch (op) {
        .clz => @clz(unsigned),
        .ctz => @ctz(unsigned),
        .popcnt => @popCount(unsigned),
    };
    return @intCast(result);
}

fn applyFloatUnary(comptime Float: type, op: FloatUnaryOp, value: Float) Float {
    return switch (op) {
        .abs => @abs(value),
        .neg => -value,
        .ceil => @ceil(value),
        .floor => @floor(value),
        .trunc => @trunc(value),
        .nearest => nearestFloat(Float, value),
        .sqrt => @sqrt(value),
    };
}

fn applyIntegerBinary(comptime Int: type, op: BinaryOp, left: Int, right: Int) Error!Int {
    const Unsigned = unsignedFor(Int);
    const Shift = shiftFor(Int);
    const bit_count = @bitSizeOf(Int);
    const shift_mask: Unsigned = bit_count - 1;
    const left_unsigned = @as(Unsigned, @bitCast(left));
    const right_unsigned = @as(Unsigned, @bitCast(right));
    const shift: Shift = @intCast(right_unsigned & shift_mask);
    return switch (op) {
        .add => left +% right,
        .sub => left -% right,
        .mul => left *% right,
        .div_s => signed: {
            if (right == 0 or (left == minSigned(Int) and right == -1)) return error.ArithmeticTrap;
            break :signed @divTrunc(left, right);
        },
        .div_u => unsigned: {
            if (right_unsigned == 0) return error.ArithmeticTrap;
            break :unsigned @bitCast(@divTrunc(left_unsigned, right_unsigned));
        },
        .rem_s => signed: {
            if (right == 0) return error.ArithmeticTrap;
            if (left == minSigned(Int) and right == -1) break :signed 0;
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
        .rotl => @bitCast(rotateLeftInt(Unsigned, Shift, left_unsigned, shift)),
        .rotr => @bitCast(rotateRightInt(Unsigned, Shift, left_unsigned, shift)),
    };
}

fn rotateLeftInt(comptime Unsigned: type, comptime Shift: type, value: Unsigned, shift: Shift) Unsigned {
    const bit_count: Unsigned = @bitSizeOf(Unsigned);
    const shift_mask: Unsigned = bit_count - 1;
    const reverse_shift: Shift = @intCast((bit_count - @as(Unsigned, shift)) & shift_mask);
    return (value << shift) | (value >> reverse_shift);
}

fn rotateRightInt(comptime Unsigned: type, comptime Shift: type, value: Unsigned, shift: Shift) Unsigned {
    const bit_count: Unsigned = @bitSizeOf(Unsigned);
    const shift_mask: Unsigned = bit_count - 1;
    const reverse_shift: Shift = @intCast((bit_count - @as(Unsigned, shift)) & shift_mask);
    return (value >> shift) | (value << reverse_shift);
}

fn applyFloatBinary(comptime Float: type, op: FloatBinaryOp, left: Float, right: Float) Float {
    return switch (op) {
        .add => left + right,
        .sub => left - right,
        .mul => left * right,
        .div => left / right,
        .min => if (Float == f32) minF32(left, right) else minF64(left, right),
        .max => if (Float == f32) maxF32(left, right) else maxF64(left, right),
        .copysign => if (Float == f32) copySignF32(left, right) else copySignF64(left, right),
    };
}

fn unsignedFor(comptime Int: type) type {
    return switch (Int) {
        i32 => u32,
        i64 => u64,
        else => @compileError("unsupported wasm integer type"),
    };
}

fn shiftFor(comptime Int: type) type {
    return switch (Int) {
        i32 => u5,
        i64 => u6,
        else => @compileError("unsupported wasm integer type"),
    };
}

fn minF32(left: f32, right: f32) f32 {
    if (isNan(left)) return left;
    if (isNan(right)) return right;
    if (left == 0 and right == 0) return @bitCast(@as(u32, @bitCast(left)) | @as(u32, @bitCast(right)));
    return if (left < right) left else right;
}

fn maxF32(left: f32, right: f32) f32 {
    if (isNan(left)) return left;
    if (isNan(right)) return right;
    if (left == 0 and right == 0) return @bitCast(@as(u32, @bitCast(left)) & @as(u32, @bitCast(right)));
    return if (left > right) left else right;
}

fn copySignF32(left: f32, right: f32) f32 {
    const magnitude = @as(u32, @bitCast(left)) & f32_magnitude_mask;
    const sign = @as(u32, @bitCast(right)) & f32_sign_mask;
    return @bitCast(magnitude | sign);
}

fn minF64(left: f64, right: f64) f64 {
    if (isNan(left)) return left;
    if (isNan(right)) return right;
    if (left == 0 and right == 0) return @bitCast(@as(u64, @bitCast(left)) | @as(u64, @bitCast(right)));
    return if (left < right) left else right;
}

fn maxF64(left: f64, right: f64) f64 {
    if (isNan(left)) return left;
    if (isNan(right)) return right;
    if (left == 0 and right == 0) return @bitCast(@as(u64, @bitCast(left)) & @as(u64, @bitCast(right)));
    return if (left > right) left else right;
}

fn copySignF64(left: f64, right: f64) f64 {
    const magnitude = @as(u64, @bitCast(left)) & f64_magnitude_mask;
    const sign = @as(u64, @bitCast(right)) & f64_sign_mask;
    return @bitCast(magnitude | sign);
}

fn nearestFloat(comptime Float: type, value: Float) Float {
    if (isNan(value)) return value;

    const lower = @floor(value);
    const upper = @ceil(value);
    const lower_distance = value - lower;
    const upper_distance = upper - value;
    if (lower_distance < upper_distance) return lower;
    if (upper_distance < lower_distance) return upper;
    return if (evenFloat(Float, lower)) lower else upper;
}

fn evenFloat(comptime Float: type, value: Float) bool {
    return @mod(@abs(value), @as(Float, 2.0)) == 0;
}

fn isNan(value: anytype) bool {
    return value != value;
}

fn pushIntegerComparison(comptime Int: type, frame: *Executor.Frame, comparison: Comparison) Error!void {
    const right = try popInteger(Int, frame);
    const left = try popInteger(Int, frame);
    try frame.pushI32(if (compareInteger(Int, comparison, left, right)) 1 else 0);
}

fn pushFloatComparison(comptime Float: type, frame: *Executor.Frame, comparison: FloatComparison) Error!void {
    const right = try popFloat(Float, frame);
    const left = try popFloat(Float, frame);
    try frame.pushI32(if (compareFloat(Float, comparison, left, right)) 1 else 0);
}

fn compareInteger(comptime Int: type, comparison: Comparison, left: Int, right: Int) bool {
    const Unsigned = unsignedFor(Int);
    const left_unsigned = @as(Unsigned, @bitCast(left));
    const right_unsigned = @as(Unsigned, @bitCast(right));
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

fn compareFloat(comptime Float: type, comparison: FloatComparison, left: Float, right: Float) bool {
    return switch (comparison) {
        .eq => left == right,
        .ne => left != right,
        .lt => left < right,
        .gt => left > right,
        .le => left <= right,
        .ge => left >= right,
    };
}

fn invalidTrunc(value: anytype, min: @TypeOf(value), max_exclusive: @TypeOf(value)) bool {
    return value != value or value < min or value >= max_exclusive;
}

fn truncFloatToInt(comptime Float: type, comptime Int: type, value: Float) Error!Int {
    if (invalidTrunc(value, truncMin(Float, Int), truncMaxExclusive(Float, Int))) return error.ArithmeticTrap;
    return @intFromFloat(value);
}

fn saturatingTruncFloatToInt(comptime Float: type, comptime Int: type, value: Float) Int {
    if (isNan(value)) return 0;
    switch (Int) {
        i32, i64 => {
            if (value <= truncMin(Float, Int)) return minSigned(Int);
            if (value >= truncMaxExclusive(Float, Int)) return maxSigned(Int);
        },
        u32, u64 => {
            if (value <= 0.0) return 0;
            if (value >= truncMaxExclusive(Float, Int)) return maxUnsigned(Int);
        },
        else => @compileError("unsupported wasm truncation target type"),
    }
    return @intFromFloat(value);
}

fn truncMin(comptime Float: type, comptime Int: type) Float {
    return switch (Int) {
        i32 => switch (Float) {
            f32 => i32_min_as_f32,
            f64 => i32_min_as_f64,
            else => @compileError("unsupported wasm truncation source type"),
        },
        i64 => switch (Float) {
            f32 => i64_min_as_f32,
            f64 => i64_min_as_f64,
            else => @compileError("unsupported wasm truncation source type"),
        },
        u32, u64 => 0.0,
        else => @compileError("unsupported wasm truncation target type"),
    };
}

fn truncMaxExclusive(comptime Float: type, comptime Int: type) Float {
    return switch (Float) {
        f32 => switch (Int) {
            i32 => i32_max_plus_one_as_f32,
            u32 => u32_max_plus_one_as_f32,
            i64 => i64_max_plus_one_as_f32,
            u64 => u64_max_plus_one_as_f32,
            else => @compileError("unsupported wasm truncation target type"),
        },
        f64 => switch (Int) {
            i32 => i32_max_plus_one_as_f64,
            u32 => u32_max_plus_one_as_f64,
            i64 => i64_max_plus_one_as_f64,
            u64 => u64_max_plus_one_as_f64,
            else => @compileError("unsupported wasm truncation target type"),
        },
        else => @compileError("unsupported wasm truncation source type"),
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
    if (reader.offset + 2 <= reader.bytes.len) {
        const alignment = reader.bytes[reader.offset];
        const offset = reader.bytes[reader.offset + 1];
        if (((alignment | offset) & leb_continue_mask) == 0) {
            reader.offset += 2;
            return offset;
        }
    }
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
    _ = @import("tests.zig");
}
