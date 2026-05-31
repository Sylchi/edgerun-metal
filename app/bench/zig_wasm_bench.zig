export fn er_bench(seed: u32) u32 {
    return seed *% 1664525 +% 1013904223;
}
