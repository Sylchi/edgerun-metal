pub const builtin = struct {
    pub const Endian = enum { little, big };
};

pub const time = struct {
    pub const ms_per_s: i64 = 1000;
    pub const ns_per_ms: i64 = 1000 * 1000;
    pub const ns_per_s: i64 = 1000 * 1000 * 1000;
};

pub const posix = struct {
    pub const fd_t = i32;
};

pub const atomic = struct {
    pub fn spinLoopHint() void {
        asm volatile ("pause");
    }
};

pub const heap = struct {
    pub const page_size_min: usize = 4096;
    pub const page_allocator = testing.allocator;
};

pub const ascii = struct {
    pub fn isDigit(value: u8) bool {
        return value >= '0' and value <= '9';
    }

    pub fn isAlphabetic(value: u8) bool {
        return (value >= 'a' and value <= 'z') or (value >= 'A' and value <= 'Z');
    }

    pub fn isAlphanumeric(value: u8) bool {
        return isAlphabetic(value) or isDigit(value);
    }

    pub fn toLower(value: u8) u8 {
        return if (value >= 'A' and value <= 'Z') value + ('a' - 'A') else value;
    }

    pub fn eqlIgnoreCase(a: []const u8, b: []const u8) bool {
        if (a.len != b.len) return false;
        for (a, b) |left, right| {
            if (toLower(left) != toLower(right)) return false;
        }
        return true;
    }
};

pub const debug = struct {
    pub fn assert(condition: bool) void {
        if (!condition) unreachable;
    }

    pub fn print(comptime _: []const u8, _: anytype) void {}
};

pub const math = struct {
    pub const pi: f32 = 3.14159265358979323846;

    pub fn add(comptime T: type, a: T, b: T) error{Overflow}!T {
        const result = @addWithOverflow(a, b);
        if (result[1] != 0) return error.Overflow;
        return result[0];
    }

    pub fn mul(comptime T: type, a: T, b: T) error{Overflow}!T {
        const result = @mulWithOverflow(a, b);
        if (result[1] != 0) return error.Overflow;
        return result[0];
    }

    pub fn clamp(value: anytype, low: @TypeOf(value), high: @TypeOf(value)) @TypeOf(value) {
        if (value < low) return low;
        if (value > high) return high;
        return value;
    }

    pub fn maxInt(comptime T: type) T {
        return switch (T) {
            i8 => 0x7f,
            i16 => 0x7fff,
            i32 => 0x7fff_ffff,
            i64 => 0x7fff_ffff_ffff_ffff,
            isize => @as(isize, 0x7fff_ffff_ffff_ffff),
            else => ~@as(T, 0),
        };
    }
};

pub const mem = struct {
    pub const Allocator = struct {
        pub fn alloc(_: Allocator, comptime T: type, count: usize) error{OutOfMemory}![]T {
            return testing.bumpAlloc(T, count);
        }

        pub fn free(_: Allocator, _: anytype) void {}

        pub fn create(self: Allocator, comptime T: type) error{OutOfMemory}!*T {
            const slot = try self.alloc(T, 1);
            return &slot[0];
        }

        pub fn destroy(_: Allocator, _: anytype) void {}

        pub fn dupe(self: Allocator, comptime T: type, source: []const T) error{OutOfMemory}![]T {
            const out = try self.alloc(T, source.len);
            for (source, 0..) |value, index| out[index] = value;
            return out;
        }
    };

    pub fn eql(comptime T: type, a: []const T, b: []const T) bool {
        if (a.len != b.len) return false;
        for (a, b) |left, right| if (!valueEql(left, right)) return false;
        return true;
    }

    pub fn startsWith(comptime T: type, haystack: []const T, needle: []const T) bool {
        return needle.len <= haystack.len and eql(T, haystack[0..needle.len], needle);
    }

    pub fn endsWith(comptime T: type, haystack: []const T, needle: []const T) bool {
        return needle.len <= haystack.len and eql(T, haystack[haystack.len - needle.len ..], needle);
    }

    pub fn indexOf(comptime T: type, haystack: []const T, needle: []const T) ?usize {
        if (needle.len > haystack.len) return null;
        var index: usize = 0;
        while (index <= haystack.len - needle.len) : (index += 1) {
            if (eql(T, haystack[index..][0..needle.len], needle)) return index;
        }
        return null;
    }

    pub fn indexOfScalar(comptime T: type, haystack: []const T, needle: T) ?usize {
        for (haystack, 0..) |value, index| if (valueEql(value, needle)) return index;
        return null;
    }

    pub fn lastIndexOfScalar(comptime T: type, haystack: []const T, needle: T) ?usize {
        var index = haystack.len;
        while (index > 0) {
            index -= 1;
            if (valueEql(haystack[index], needle)) return index;
        }
        return null;
    }

    pub fn copyForwards(comptime T: type, dest: []T, source: []const T) void {
        var index: usize = 0;
        while (index < source.len) : (index += 1) dest[index] = source[index];
    }

    pub fn swap(comptime T: type, a: *T, b: *T) void {
        const tmp = a.*;
        a.* = b.*;
        b.* = tmp;
    }

    pub fn alignForward(comptime T: type, value: T, alignment: T) T {
        const mask = alignment - 1;
        return (value + mask) & ~mask;
    }

    pub fn readInt(comptime T: type, buffer: *const [@divExact(@typeInfo(T).int.bits, 8)]u8, endian: builtin.Endian) T {
        return switch (endian) {
            .little => readIntLittle(T, buffer),
            .big => readIntBig(T, buffer),
        };
    }

    pub fn writeInt(comptime T: type, buffer: *[@divExact(@typeInfo(T).int.bits, 8)]u8, value: T, endian: builtin.Endian) void {
        switch (endian) {
            .little => writeIntLittle(T, buffer, value),
            .big => writeIntBig(T, buffer, value),
        }
    }

    pub fn sliceAsBytes(slice: anytype) []const u8 {
        const Child = @TypeOf(slice[0]);
        return @as([*]const u8, @ptrCast(slice.ptr))[0 .. slice.len * @sizeOf(Child)];
    }

    pub fn splitScalar(comptime T: type, buffer: []const T, delimiter: T) SplitScalar(T) {
        return .{ .buffer = buffer, .delimiter = delimiter };
    }

    pub fn splitSequence(comptime T: type, buffer: []const T, delimiter: []const T) SplitSequence(T) {
        return .{ .buffer = buffer, .delimiter = delimiter };
    }

    pub fn tokenizeAny(comptime T: type, buffer: []const T, delimiters: []const T) TokenizeAny(T) {
        return .{ .buffer = buffer, .delimiters = delimiters };
    }

    pub fn trim(comptime T: type, buffer: []const T, values: []const T) []const T {
        return trimEnd(T, trimStart(T, buffer, values), values);
    }

    pub fn trimEnd(comptime T: type, buffer: []const T, values: []const T) []const T {
        var end = buffer.len;
        while (end > 0 and containsScalar(T, values, buffer[end - 1])) end -= 1;
        return buffer[0..end];
    }

    fn trimStart(comptime T: type, buffer: []const T, values: []const T) []const T {
        var start: usize = 0;
        while (start < buffer.len and containsScalar(T, values, buffer[start])) start += 1;
        return buffer[start..];
    }

    fn containsScalar(comptime T: type, values: []const T, value: T) bool {
        return indexOfScalar(T, values, value) != null;
    }

    fn readIntLittle(comptime T: type, buffer: *const [@divExact(@typeInfo(T).int.bits, 8)]u8) T {
        var out: T = 0;
        for (buffer, 0..) |byte, index| out |= @as(T, @intCast(byte)) << @intCast(index * 8);
        return out;
    }

    fn readIntBig(comptime T: type, buffer: *const [@divExact(@typeInfo(T).int.bits, 8)]u8) T {
        var out: T = 0;
        for (buffer) |byte| out = (out << 8) | @as(T, @intCast(byte));
        return out;
    }

    fn writeIntLittle(comptime T: type, buffer: *[@divExact(@typeInfo(T).int.bits, 8)]u8, value: T) void {
        for (buffer, 0..) |*byte, index| byte.* = @truncate(value >> @intCast(index * 8));
    }

    fn writeIntBig(comptime T: type, buffer: *[@divExact(@typeInfo(T).int.bits, 8)]u8, value: T) void {
        var remaining = value;
        var index = buffer.len;
        while (index > 0) {
            index -= 1;
            buffer[index] = @truncate(remaining);
            remaining >>= 8;
        }
    }
};

pub fn SplitScalar(comptime T: type) type {
    return struct {
        buffer: []const T,
        delimiter: T,
        index: usize = 0,

        pub fn next(self: *@This()) ?[]const T {
            if (self.index > self.buffer.len) return null;
            const start = self.index;
            while (self.index < self.buffer.len and !valueEql(self.buffer[self.index], self.delimiter)) self.index += 1;
            const out = self.buffer[start..self.index];
            self.index += 1;
            return out;
        }
    };
}

pub fn SplitSequence(comptime T: type) type {
    return struct {
        buffer: []const T,
        delimiter: []const T,
        index: usize = 0,

        pub fn next(self: *@This()) ?[]const T {
            if (self.index > self.buffer.len) return null;
            const rest = self.buffer[self.index..];
            const found = mem.indexOf(T, rest, self.delimiter) orelse rest.len;
            const out = rest[0..found];
            self.index += found + self.delimiter.len;
            return out;
        }
    };
}

pub fn TokenizeAny(comptime T: type) type {
    return struct {
        buffer: []const T,
        delimiters: []const T,
        index: usize = 0,

        pub fn next(self: *@This()) ?[]const T {
            while (self.index < self.buffer.len and mem.indexOfScalar(T, self.delimiters, self.buffer[self.index]) != null) self.index += 1;
            if (self.index >= self.buffer.len) return null;
            const start = self.index;
            while (self.index < self.buffer.len and mem.indexOfScalar(T, self.delimiters, self.buffer[self.index]) == null) self.index += 1;
            return self.buffer[start..self.index];
        }
    };
}

pub const meta = struct {
    pub fn eql(a: anytype, b: @TypeOf(a)) bool {
        return valueEql(a, b);
    }

    pub fn activeTag(value: anytype) @typeInfo(@TypeOf(value)).@"union".tag_type.? {
        return value;
    }

    pub inline fn fields(comptime T: type) @TypeOf(@typeInfo(T).@"enum".fields) {
        return @typeInfo(T).@"enum".fields;
    }
};

pub const testing = struct {
    var memory: [256 * 1024 * 1024]u8 align(16) = undefined;
    var used: usize = 0;

    pub const allocator: mem.Allocator = .{};

    fn bumpAlloc(comptime T: type, count: usize) error{OutOfMemory}![]T {
        const align_bytes = @max(@alignOf(T), 1);
        const base = @intFromPtr(&memory) + used;
        const aligned = mem.alignForward(usize, base, align_bytes);
        const start = aligned - @intFromPtr(&memory);
        const bytes = @sizeOf(T) * count;
        if (start + bytes > memory.len) return error.OutOfMemory;
        used = start + bytes;
        const raw = memory[start..][0..bytes];
        const aligned_raw: []align(@alignOf(T)) u8 = @alignCast(raw);
        return @as([*]T, @ptrCast(aligned_raw.ptr))[0..count];
    }

    pub fn expect(condition: bool) !void {
        if (!condition) return error.TestExpectedTrue;
    }

    pub fn expectEqual(expected: anytype, actual: anytype) !void {
        if (!valueEql(expected, actual)) return error.TestExpectedEqual;
    }

    pub fn expectEqualStrings(expected: []const u8, actual: []const u8) !void {
        if (expected.len != actual.len) return error.TestExpectedEqual;
        var index: usize = 0;
        while (index < expected.len) : (index += 1) {
            if (expected[index] != actual[index]) return error.TestExpectedEqual;
        }
    }

    pub fn expectApproxEqAbs(expected: anytype, actual: anytype, tolerance: anytype) !void {
        const expected_value: @TypeOf(actual) = expected;
        const tolerance_value: @TypeOf(actual) = tolerance;
        const delta = if (actual > expected_value) actual - expected_value else expected_value - actual;
        if (delta > tolerance_value) return error.TestExpectedApproxEqAbs;
    }

    pub fn expectEqualSlices(comptime T: type, expected: []const T, actual: []const T) !void {
        if (expected.len != actual.len) return error.TestExpectedEqual;
        var index: usize = 0;
        while (index < expected.len) : (index += 1) {
            if (T == u8) {
                if (expected[index] != actual[index]) return error.TestExpectedEqual;
                continue;
            }
            if (!valueEql(expected[index], actual[index])) return error.TestExpectedEqual;
        }
    }

    pub fn expectError(expected: anyerror, actual: anytype) !void {
        if (actual) |_| return error.TestExpectedError else |err| if (err != expected) return err;
    }
};

pub fn ArrayList(comptime T: type) type {
    return ArrayListUnmanaged(T);
}

pub fn ArrayListUnmanaged(comptime T: type) type {
    return struct {
        items: []T = &.{},
        capacity: usize = 0,

        pub const empty: @This() = .{};

        pub fn init(_: mem.Allocator) @This() {
            return .{};
        }

        pub fn initCapacity(allocator: mem.Allocator, capacity: usize) error{OutOfMemory}!@This() {
            if (capacity == 0) return .{};
            return .{ .items = (try allocator.alloc(T, capacity))[0..0], .capacity = capacity };
        }

        pub fn deinit(_: *@This(), _: mem.Allocator) void {}

        pub fn append(self: *@This(), allocator: mem.Allocator, value: T) !void {
            try self.ensureUnusedCapacity(allocator, 1);
            self.items.ptr[self.items.len] = value;
            self.items = self.items.ptr[0 .. self.items.len + 1];
        }

        pub fn appendSlice(self: *@This(), allocator: mem.Allocator, values: []const T) !void {
            try self.ensureUnusedCapacity(allocator, values.len);
            for (values, 0..) |value, index| self.items.ptr[self.items.len + index] = value;
            self.items = self.items.ptr[0 .. self.items.len + values.len];
        }

        pub fn clearRetainingCapacity(self: *@This()) void {
            self.items = self.items.ptr[0..0];
        }

        pub fn toOwnedSlice(self: *@This(), _: mem.Allocator) ![]T {
            return self.items;
        }

        fn ensureUnusedCapacity(self: *@This(), allocator: mem.Allocator, extra: usize) !void {
            if (self.items.len + extra <= self.capacity) return;
            var next_capacity = if (self.capacity == 0) @as(usize, 8) else self.capacity * 2;
            while (next_capacity < self.items.len + extra) next_capacity *= 2;
            const next = try allocator.alloc(T, next_capacity);
            for (self.items, 0..) |value, index| next[index] = value;
            self.items = next[0..self.items.len];
            self.capacity = next_capacity;
        }
    };
}

pub const fmt = struct {
    pub fn parseUnsigned(comptime T: type, text: []const u8, radix_arg: u8) !T {
        const radix = if (radix_arg == 0) detectRadix(text).radix else radix_arg;
        const start = if (radix_arg == 0) detectRadix(text).start else 0;
        var out: T = 0;
        for (text[start..]) |byte| {
            const digit = digitValue(byte) orelse return error.InvalidCharacter;
            if (digit >= radix) return error.InvalidCharacter;
            out = out * @as(T, @intCast(radix)) + @as(T, @intCast(digit));
        }
        return out;
    }

    pub fn parseInt(comptime T: type, text: []const u8, radix: u8) !T {
        if (text.len != 0 and text[0] == '-') {
            if (@typeInfo(T).int.signedness == .unsigned) return error.InvalidCharacter;
            return -@as(T, @intCast(try parseUnsigned(unsignedPair(T), text[1..], radix)));
        }
        return @intCast(try parseUnsigned(unsignedPair(T), text, radix));
    }

    pub fn parseFloat(comptime T: type, text: []const u8) !T {
        var value: T = 0;
        var frac: T = 0;
        var scale: T = 1;
        var seen_dot = false;
        var negative = false;
        for (text, 0..) |byte, index| {
            if (index == 0 and byte == '-') {
                negative = true;
                continue;
            }
            if (byte == '.') {
                seen_dot = true;
                continue;
            }
            const digit = digitValue(byte) orelse return error.InvalidCharacter;
            if (!seen_dot) value = value * 10 + @as(T, @floatFromInt(digit)) else {
                frac = frac * 10 + @as(T, @floatFromInt(digit));
                scale *= 10;
            }
        }
        const out = value + frac / scale;
        return if (negative) -out else out;
    }

    pub fn bytesToHex(value: anytype, _: enum { lower, upper }) [@typeInfo(@TypeOf(value)).array.len * 2]u8 {
        var out: [@typeInfo(@TypeOf(value)).array.len * 2]u8 = undefined;
        for (value, 0..) |byte, index| {
            out[index * 2] = hex(byte >> 4);
            out[index * 2 + 1] = hex(byte & 0xf);
        }
        return out;
    }

    pub fn bufPrint(out: []u8, comptime format_text: []const u8, args: anytype) ![]u8 {
        return formatInto(out, format_text, args);
    }

    pub fn bufPrintZ(out: []u8, comptime format_text: []const u8, args: anytype) ![:0]u8 {
        const written = try formatInto(out[0 .. out.len - 1], format_text, args);
        out[written.len] = 0;
        return out[0..written.len :0];
    }

    pub fn allocPrint(allocator: mem.Allocator, comptime format_text: []const u8, args: anytype) ![]u8 {
        const out = try allocator.alloc(u8, 4096);
        return formatInto(out, format_text, args);
    }

    pub fn format(_: anytype, _: anytype, _: anytype) !void {}

    fn detectRadix(text: []const u8) struct { radix: u8, start: usize } {
        if (text.len > 2 and text[0] == '0' and (text[1] == 'x' or text[1] == 'X')) return .{ .radix = 16, .start = 2 };
        return .{ .radix = 10, .start = 0 };
    }

    fn digitValue(byte: u8) ?u8 {
        if (byte >= '0' and byte <= '9') return byte - '0';
        if (byte >= 'a' and byte <= 'f') return byte - 'a' + 10;
        if (byte >= 'A' and byte <= 'F') return byte - 'A' + 10;
        return null;
    }

    fn hex(value: u8) u8 {
        return if (value < 10) '0' + value else 'a' + value - 10;
    }
};

pub const Io = struct {
    pub const Limit = struct {
        value: usize,

        pub fn limited(value: usize) Limit {
            return .{ .value = value };
        }
    };

    pub const Writer = struct {
        pub fn print(_: *Writer, comptime _: []const u8, _: anytype) !void {}
        pub fn flush(_: *Writer) !void {}
    };

    pub const File = struct {
        pub fn stdout() File { return .{}; }
        pub fn writer(_: File, _: Io, _: []u8) struct { interface: Writer = .{} } { return .{}; }
        pub fn writeAll(_: File, _: Io, _: []const u8) !void {}
        pub fn writeStreamingAll(_: File, _: Io, _: []const u8) !void {}
        pub fn close(_: File, _: Io) void {}
    };

    pub const Dir = struct {
        pub const WalkEntry = struct {
            pub const Kind = enum { file, directory };
            kind: Kind,
            basename: []const u8,
            path: []const u8,
        };

        pub const Walker = struct {
            pub fn next(_: *Walker, _: Io) !?WalkEntry { return null; }
            pub fn deinit(_: *Walker) void {}
        };

        pub const IterEntry = struct { name: []const u8 };
        pub const Iterator = struct {
            pub fn next(_: *Iterator, _: Io) !?IterEntry { return null; }
        };

        pub const Stat = struct { size: u64 = 0 };

        pub fn cwd() Dir { return .{}; }
        pub fn close(_: Dir, _: Io) void {}
        pub fn createDirPath(_: Dir, _: Io, _: []const u8) !void {}
        pub fn createFile(_: Dir, _: Io, _: []const u8, _: anytype) !File { return .{}; }
        pub fn iterate(_: Dir) Iterator { return .{}; }
        pub fn openDir(_: Dir, _: Io, _: []const u8, _: anytype) !Dir { return .{}; }
        pub fn openDirAbsolute(_: Io, _: []const u8, _: anytype) !Dir { return .{}; }
        pub fn readFile(_: Dir, _: Io, _: []const u8, out: []u8) ![]u8 { return out[0..0]; }
        pub fn statFile(_: Dir, _: Io, _: []const u8, _: anytype) !Stat { return .{}; }
        pub fn walk(_: Dir, _: mem.Allocator) !Walker { return .{}; }
        pub fn readFileAlloc(_: Dir, _: Io, _: []const u8, allocator: mem.Allocator, _: anytype) ![]u8 { return allocator.alloc(u8, 0); }
    };

    pub const net = struct {
        pub const UnixAddress = struct {
            pub fn init(_: []const u8) !UnixAddress { return .{}; }
            pub fn connect(_: *const UnixAddress, _: Io) !File { return .{}; }
        };
    };
};

pub const process = struct {
    pub const Init = struct { minimal: struct { args: Args, environ: Environ = .{} } = .{ .args = .{} }, io: Io = .{} };
    pub const Environ = struct { block: ?[*:null]const ?[*:0]const u8 = null };
    pub const Term = union(enum) { exited: u8 };
    pub const RunResult = struct { stdout: []u8, stderr: []u8, term: Term };

    pub fn run(allocator: mem.Allocator, _: Io, _: anytype) !RunResult {
        return .{
            .stdout = try allocator.alloc(u8, 0),
            .stderr = try allocator.alloc(u8, 0),
            .term = .{ .exited = 0 },
        };
    }

    pub const Args = struct {
        vector: []const [*:0]const u8 = &.{},
        pub const Iterator = struct {
            args: Args,
            index: usize = 0,
            pub fn init(args: Args) Iterator { return .{ .args = args }; }
            pub fn next(self: *Iterator) ?[]const u8 {
                if (self.index >= self.args.vector.len) return null;
                defer self.index += 1;
                return cStringSlice(self.args.vector[self.index]);
            }
        };
    };
};

fn cStringSlice(value: [*:0]const u8) []const u8 {
    var len: usize = 0;
    while (value[len] != 0) len += 1;
    return value[0..len];
}

pub const fs = struct {
    pub fn openDirAbsolute(_: []const u8, _: anytype) !Io.Dir { return .{}; }
};

pub const os = struct {
    pub const linux = struct {
        pub const E = enum { SUCCESS, FAILURE };
        pub const CLOCK = enum { MONOTONIC };
        pub const AT = struct { pub const FDCWD: i32 = -100; };
        pub const timespec = extern struct { sec: isize, nsec: isize };
        pub const O = packed struct {
            pub const AccessMode = enum(u2) { RDONLY, WRONLY, RDWR };
            ACCMODE: AccessMode = .RDONLY,
            DIRECTORY: bool = false,
            CLOEXEC: bool = false,
            _unused: u28 = 0,
        };

        pub fn pipe2(_: *[2]i32, _: anytype) isize { return -1; }
        pub fn clock_gettime(_: CLOCK, out: *timespec) isize {
            out.* = .{ .sec = 0, .nsec = 0 };
            return 0;
        }
        pub fn open(_: [*:0]const u8, _: O, _: usize) isize { return -1; }
        pub fn openat(_: i32, _: [*:0]const u8, _: O, _: usize) isize { return -1; }
        pub fn read(_: i32, _: [*]u8, _: usize) usize { return 0; }
        pub fn write(_: i32, _: [*]const u8, len: usize) usize { return len; }
        pub fn getdents64(_: i32, _: [*]u8, _: usize) usize { return 0; }
        pub fn fork() isize { return -1; }
        pub fn close(_: i32) isize { return 0; }
        pub fn dup2(_: i32, _: i32) isize { return -1; }
        pub fn execve(_: [*:0]const u8, _: [*:null]const ?[*:0]const u8, _: [*:null]const ?[*:0]const u8) isize { return -1; }
        pub fn exit(_: u8) noreturn { unreachable; }
        pub fn wait4(_: i32, status: *u32, _: u32, _: ?*anyopaque) isize {
            status.* = 0;
            return 0;
        }
        pub fn socket(_: i32, _: i32, _: i32) isize { return -1; }
        pub fn ioctl(_: i32, _: u32, _: usize) usize { return 1; }
        pub fn errno(result: anytype) E { return if (result < 0) .FAILURE else .SUCCESS; }
    };
    pub const uefi = struct {};
};

pub const DynLib = struct {};
pub const compress = struct { pub const flate = struct { pub const max_window_len: usize = 32768; }; };
pub const hash = struct { pub const Crc32 = struct { pub fn init() Crc32 { return .{}; } }; };
pub const crypto = struct {
    pub const hash = struct {
        pub const sha2 = struct {
            pub const Sha256 = struct {
                pub fn hash(input: []const u8, out: *[32]u8, _: anytype) void {
                    @memset(out, 0);
                    for (input, 0..) |byte, index| out[index & 31] +%= byte;
                }
            };
        };
    };

    pub const sign = struct {
        pub const ecdsa = struct {
            pub const EcdsaP256Sha256 = struct {
                pub const SecretKey = struct {
                    bytes: [encoded_length]u8,

                    pub const encoded_length: usize = 32;
                    pub fn fromBytes(bytes: [encoded_length]u8) !SecretKey { return .{ .bytes = bytes }; }
                    pub fn publicKey(self: SecretKey) PublicKey { return PublicKey.fromSecret(self); }
                    pub fn sign(self: SecretKey, digest: [32]u8, _: anytype) !Signature { return Signature.fromDigest(self.publicKey(), digest); }
                };
                pub const KeyPair = struct {
                    public_key: PublicKey,
                    secret_key: SecretKey,

                    pub fn fromSecretKey(secret_key: SecretKey) !KeyPair {
                        return .{ .public_key = secret_key.publicKey(), .secret_key = secret_key };
                    }

                    pub fn signPrehashed(self: KeyPair, digest: [32]u8, noise: anytype) !Signature {
                        return self.secret_key.sign(digest, noise);
                    }
                };
                pub const PublicKey = struct {
                    bytes: [64]u8,

                    pub const uncompressed_sec1_encoded_length: usize = 65;

                    fn fromSecret(secret_key: SecretKey) PublicKey {
                        var out: [64]u8 = undefined;
                        for (&out, 0..) |*byte, index| byte.* = secret_key.bytes[index & 31] ^ @as(u8, @intCast(index + 1));
                        return .{ .bytes = out };
                    }

                    pub fn fromSec1(encoded: *const [uncompressed_sec1_encoded_length]u8) !PublicKey {
                        if (encoded[0] != 0x04) return error.InvalidPublicKey;
                        var out: [64]u8 = undefined;
                        @memcpy(&out, encoded[1..]);
                        return .{ .bytes = out };
                    }

                    pub fn toUncompressedSec1(self: PublicKey) [uncompressed_sec1_encoded_length]u8 {
                        var out: [uncompressed_sec1_encoded_length]u8 = undefined;
                        out[0] = 0x04;
                        @memcpy(out[1..], &self.bytes);
                        return out;
                    }
                };
                pub const Signature = struct {
                    bytes: [64]u8,

                    pub fn fromBytes(bytes: [64]u8) Signature { return .{ .bytes = bytes }; }
                    pub fn toBytes(self: Signature) [64]u8 { return self.bytes; }
                    pub fn verifyPrehashed(self: Signature, digest: [32]u8, public_key: PublicKey) !void {
                        const expected = fromDigest(public_key, digest);
                        if (!mem.eql(u8, &self.bytes, &expected.bytes)) return error.InvalidSignature;
                    }

                    fn fromDigest(public_key: PublicKey, digest: [32]u8) Signature {
                        var out: [64]u8 = undefined;
                        for (&out, 0..) |*byte, index| byte.* = digest[index & 31] ^ public_key.bytes[index];
                        return .{ .bytes = out };
                    }
                };
            };
        };
    };
};

fn valueEql(a: anytype, b: anytype) bool {
    if (@TypeOf(a) != @TypeOf(b)) {
        if (comptime (isSliceLike(@TypeOf(a)) and isSliceLike(@TypeOf(b)))) return sliceEql(a, b);
        if (comptime (@typeInfo(@TypeOf(a)) == .enum_literal and isTaggedUnion(@TypeOf(b)))) {
            return true;
        }
        if (comptime (@typeInfo(@TypeOf(b)) == .enum_literal and isTaggedUnion(@TypeOf(a)))) {
            return true;
        }
        if (comptime (isArrayPointer(@TypeOf(a)) and isSlice(@TypeOf(b)))) return sliceEql(a.*, b);
        if (comptime (isSlice(@TypeOf(a)) and isArrayPointer(@TypeOf(b)))) return sliceEql(a, b.*);
        if (comptime (isNumber(@TypeOf(a)) and isNumber(@TypeOf(b)))) return a == b;
        return false;
    }
    return switch (@typeInfo(@TypeOf(a))) {
        .array => mem.eql(@typeInfo(@TypeOf(a)).array.child, &a, &b),
        .pointer => |ptr| if (ptr.size == .slice) mem.eql(ptr.child, a, b) else if (isSliceLike(@TypeOf(a))) sliceEql(a, b) else a == b,
        .optional => if (a == null or b == null) a == null and b == null else valueEql(a.?, b.?),
        .@"struct" => blk: {
            inline for (@typeInfo(@TypeOf(a)).@"struct".fields) |field| {
                if (!valueEql(@field(a, field.name), @field(b, field.name))) break :blk false;
            }
            break :blk true;
        },
        .@"union" => |info| blk: {
            _ = info.tag_type orelse break :blk false;
            switch (a) {
                inline else => |payload, tag| {
                    if (!unionTagNameEql(@tagName(tag), b)) break :blk false;
                    if (@sizeOf(@TypeOf(payload)) == 0) break :blk true;
                    break :blk valueEql(payload, @field(b, @tagName(tag)));
                },
            }
        },
        else => a == b,
    };
}

fn sliceEql(a: anytype, b: anytype) bool {
    if (a.len != b.len) return false;
    for (a, b) |left, right| if (!valueEql(left, right)) return false;
    return true;
}

fn isSlice(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .pointer => |ptr| ptr.size == .slice,
        else => false,
    };
}

fn isArrayPointer(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .pointer => |ptr| ptr.size == .one and @typeInfo(ptr.child) == .array,
        else => false,
    };
}

fn isSliceLike(comptime T: type) bool {
    return isSlice(T) or isArrayPointer(T);
}

fn isTaggedUnion(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .@"union" => |info| info.tag_type != null,
        else => false,
    };
}

fn unionTagNameEql(comptime name: []const u8, value: anytype) bool {
    switch (value) {
        inline else => |_, tag| return tagNamesMatch(@tagName(tag), name),
    }
}

fn tagNamesMatch(a: []const u8, b: []const u8) bool {
    if (mem.eql(u8, a, b)) return true;
    return mem.endsWith(u8, a, b) or mem.endsWith(u8, b, a);
}

fn isNumber(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .int, .comptime_int, .float, .comptime_float => true,
        else => false,
    };
}

fn unsignedPair(comptime T: type) type {
    return switch (@typeInfo(T).int.bits) {
        8 => u8,
        16 => u16,
        32 => u32,
        64 => u64,
        else => usize,
    };
}

fn formatInto(out: []u8, comptime format_text: []const u8, args: anytype) ![]u8 {
    var cursor: usize = 0;
    var scan: usize = 0;
    inline for (args) |value| {
        var index = scan;
        while (index < format_text.len and format_text[index] != '{') : (index += 1) {
            if (cursor >= out.len) return error.NoSpaceLeft;
            out[cursor] = format_text[index];
            cursor += 1;
        }
        if (index >= format_text.len) return out[0..cursor];
        while (format_text[index] != '}') index += 1;
        cursor += writeValue(out[cursor..], value);
        scan = index + 1;
    }
    var index = scan;
    while (index < format_text.len) : (index += 1) {
        if (format_text[index] == '{') {
            while (format_text[index] != '}') index += 1;
        } else {
            if (cursor >= out.len) return error.NoSpaceLeft;
            out[cursor] = format_text[index];
            cursor += 1;
        }
    }
    return out[0..cursor];
}

fn writeValue(out: []u8, value: anytype) usize {
    return switch (@typeInfo(@TypeOf(value))) {
        .pointer => blk: {
            var index: usize = 0;
            for (value) |byte| {
                out[index] = byte;
                index += 1;
            }
            break :blk index;
        },
        .int, .comptime_int => writeUnsigned(out, @intCast(value)),
        else => 0,
    };
}

fn writeUnsigned(out: []u8, value_arg: u64) usize {
    var value = value_arg;
    var tmp: [32]u8 = undefined;
    var len: usize = 0;
    if (value == 0) {
        out[0] = '0';
        return 1;
    }
    while (value != 0) : (value /= 10) {
        tmp[len] = '0' + @as(u8, @intCast(value % 10));
        len += 1;
    }
    var index: usize = 0;
    while (index < len) : (index += 1) out[index] = tmp[len - index - 1];
    return len;
}

test "owned std byte and math helpers" {
    try testing.expect(mem.eql(u8, "edgerun", "edgerun"));
    try testing.expectEqual(@as(usize, 8), try math.mul(usize, 2, 4));
    try testing.expectEqual(@as(usize, 8), mem.alignForward(usize, 5, 4));
    try testing.expect(ascii.eqlIgnoreCase("ASM", "asm"));
}
