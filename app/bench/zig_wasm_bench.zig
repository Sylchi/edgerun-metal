export fn er_bench(seed: u32) u32 {
    var x = seed;
    inline for (0..256) |round| {
        const n: u32 = @intCast(round);
        const left: u5 = @intCast((round % 11) + 3);
        const right: u5 = @intCast(32 - @as(u32, left));
        const mix: u32 = 0x9e3779b9 +% (n *% 0x45d9f3b);

        x +%= mix;
        x ^= x >> @intCast((round % 13) + 5);
        x *%= 1664525 +% (n | 1);
        x = (x << left) | (x >> right);
        x -%= (x & 0x7f4a7c15) | (mix >> 7);
        x ^= (x << 3) +% (x >> 11);
    }
    return x;
}
