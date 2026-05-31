export fn er_bench(seed: u32) u32 {
    var x = seed;
    x = x *% 1664525 +% 1013904223;
    x ^= x >> 16;
    x = x *% 2246822519;
    x ^= x >> 13;
    x = x *% 3266489917;
    x ^= x >> 16;
    return x;
}
