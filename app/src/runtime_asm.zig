// EdgeRun freestanding memory and string runtime — x86_64 assembly
// System V AMD64 ABI extern declarations.
// Functions are freestanding — no libc, no external dependencies.

// -----------------------------------------------------------------
// Memory operations
// -----------------------------------------------------------------

pub extern fn er_memset(dst: ?*anyopaque, value: i32, num: usize) callconv(.C) ?*anyopaque;
pub extern fn er_memcpy(dst: ?*anyopaque, src: ?*const anyopaque, num: usize) callconv(.C) ?*anyopaque;
pub extern fn er_memcmp(ptr1: ?*const anyopaque, ptr2: ?*const anyopaque, num: usize) callconv(.C) i32;
pub extern fn er_memmove(dst: ?*anyopaque, src: ?*const anyopaque, num: usize) callconv(.C) ?*anyopaque;
pub extern fn er_memchr(ptr: ?*const anyopaque, value: i32, num: usize) callconv(.C) ?*anyopaque;
pub extern fn er_memrchr(ptr: ?*const anyopaque, value: i32, num: usize) callconv(.C) ?*anyopaque;
pub extern fn er_memccpy(dst: ?*anyopaque, src: ?*const anyopaque, stop_char: i32, n: usize) callconv(.C) ?*anyopaque;
pub extern fn er_memicmp(ptr1: ?*const anyopaque, ptr2: ?*const anyopaque, n: usize) callconv(.C) i32;
pub extern fn er_memswap(ptr1: ?*anyopaque, ptr2: ?*anyopaque, n: usize) callconv(.C) void;
pub extern fn er_memset32(dst: ?*anyopaque, value: u32, count: usize) callconv(.C) ?*anyopaque;
pub extern fn er_memset64(dst: ?*anyopaque, value: u64, count: usize) callconv(.C) ?*anyopaque;

// -----------------------------------------------------------------
// String operations
// -----------------------------------------------------------------

pub extern fn er_strlen(str: [*c]const u8) callconv(.C) usize;
pub extern fn er_strcmp(str1: [*c]const u8, str2: [*c]const u8) callconv(.C) i32;
pub extern fn er_strcpy(dst: [*c]u8, src: [*c]const u8) callconv(.C) [*c]u8;
pub extern fn er_strcmp_prefix(str: [*c]const u8, prefix: [*c]const u8) callconv(.C) i32;
pub extern fn er_strchr(str: [*c]const u8, c: i32) callconv(.C) ?[*c]const u8;
pub extern fn er_strrchr(str: [*c]const u8, c: i32) callconv(.C) ?[*c]const u8;
pub extern fn er_strncpy(dst: [*c]u8, src: [*c]const u8, n: usize) callconv(.C) [*c]u8;
pub extern fn er_strncat(dst: [*c]u8, src: [*c]const u8, n: usize) callconv(.C) [*c]u8;
pub extern fn er_strncmp(s1: [*c]const u8, s2: [*c]const u8, n: usize) callconv(.C) i32;
pub extern fn er_strcasecmp(s1: [*c]const u8, s2: [*c]const u8) callconv(.C) i32;
pub extern fn er_strstr(haystack: [*c]const u8, needle: [*c]const u8) callconv(.C) ?[*c]const u8;
pub extern fn er_strspn(str: [*c]const u8, accept: [*c]const u8) callconv(.C) usize;
pub extern fn er_strcspn(str: [*c]const u8, reject: [*c]const u8) callconv(.C) usize;
pub extern fn er_strpbrk(str: [*c]const u8, accept: [*c]const u8) callconv(.C) ?[*c]const u8;
pub extern fn er_strtok(str: ?[*c]u8, delim: [*c]const u8) callconv(.C) ?[*c]u8;

// -----------------------------------------------------------------
// String → number parsing
// -----------------------------------------------------------------

pub extern fn er_strtou64(str: [*c]const u8, endptr: ?*?*u8) callconv(.C) u64;
pub extern fn er_strtoi64(str: [*c]const u8, endptr: ?*?*u8) callconv(.C) i64;
pub extern fn er_strtou64_hex(str: [*c]const u8, endptr: ?*?*u8) callconv(.C) u64;
pub extern fn er_strtou64_base(str: [*c]const u8, endptr: ?*?*u8, base: i32) callconv(.C) u64;
pub extern fn er_strtoi64_base(str: [*c]const u8, endptr: ?*?*u8, base: i32) callconv(.C) i64;

// -----------------------------------------------------------------
// Encoding / decoding
// -----------------------------------------------------------------

pub extern fn er_hex_encode(data: ?*const anyopaque, len: usize, out: [*c]u8) callconv(.C) void;
pub extern fn er_hex_decode(hex_str: [*c]const u8, len: usize, out: ?*anyopaque) callconv(.C) usize;
pub extern fn er_utf8_encode(codepoint: u32, out: [*c]u8) callconv(.C) i32;
pub extern fn er_utf8_decode(str: [*c]const u8, len: ?*usize) callconv(.C) u32;

// -----------------------------------------------------------------
// Bootstrap
// -----------------------------------------------------------------

pub extern fn er_bss_zero(bss_start: ?*anyopaque, bss_end: ?*anyopaque) callconv(.C) void;
