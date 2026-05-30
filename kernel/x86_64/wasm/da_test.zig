// da_test.zig — Minimal WASM app that registers a surface with the DA
// Compile: zig build-exe -target wasm32-freestanding -fno-entry --export=f -O ReleaseSmall da_test.zig

const RegisterParams = extern struct {
    layer: i32,
    flags: i32,
    rect_data: i32,
    rect_count: i32,
};

extern "er" fn da_surface_register(params: i32) i32;

// rect_data embedded as f32 array — will be placed in WASM data segment
const rect_data: [15]f32 align(4) = .{
    100.0, 100.0, 200.0, 150.0,
    0.0, 0.0,
    0.2, 0.5, 0.8, 1.0,
    0.0, 0.0, 0.0, 0.0,
    0.0,
};

export fn f() i32 {
    const reg = RegisterParams{
        .layer = 0,
        .flags = 1,
        .rect_data = @as(i32, @intCast(@intFromPtr(&rect_data))),
        .rect_count = 1,
    };
    return da_surface_register(@as(i32, @intCast(@intFromPtr(&reg))));
}
