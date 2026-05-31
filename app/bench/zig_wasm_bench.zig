export fn er_bench(seed: u32) u32 {
    var x = seed;
    inline for (0..512) |round| {
        x = x *% 1664525 +% 1013904223 +% @as(u32, @intCast(round));
        x ^= x >> 13;
    }
    return x;
}
