pub const float_max: f32 = 3.4028234663852886e38;
pub const pi: f32 = 3.14159265358979323846;
pub const half_pi: f32 = pi * 0.5;
pub const quarter_pi: f32 = pi * 0.25;
pub const three_quarter_pi: f32 = pi * 0.75;
pub const tau: f32 = pi * 2.0;
pub const atan2_epsilon: f32 = 1.0e-10;
pub const atan2_cubic: f32 = 0.1963;
pub const atan2_linear: f32 = -0.9817;
pub const inv_sqrt_magic: u32 = 0x5f37_59df;

const sqrt_seed_bias: u32 = 0x1fc0_0000;
const unit_u8_max: f32 = 255.0;
const rounding_half: f32 = 0.5;
const smoothstep_a: f32 = 3.0;
const smoothstep_b: f32 = 2.0;
const smootherstep_a: f32 = 6.0;
const smootherstep_b: f32 = 15.0;
const smootherstep_c: f32 = 10.0;
const inv_sqrt_refine: f32 = 1.5;

pub fn absF(value: f32) f32 {
    return if (value < 0.0) -value else value;
}

pub fn minF(a: f32, b: f32) f32 {
    return if (a < b) a else b;
}

pub fn maxF(a: f32, b: f32) f32 {
    return if (a > b) a else b;
}

pub fn clampF(value: f32, min_value: f32, max_value: f32) f32 {
    if (value < min_value) return min_value;
    if (value > max_value) return max_value;
    return value;
}

pub fn clamp01F(value: f32) f32 {
    return clampF(value, 0.0, 1.0);
}

pub fn minSize(a: usize, b: usize) usize {
    return if (a < b) a else b;
}

pub fn maxSize(a: usize, b: usize) usize {
    return if (a > b) a else b;
}

pub fn clampSize(value: usize, min_value: usize, max_value: usize) usize {
    if (value < min_value) return min_value;
    if (value > max_value) return max_value;
    return value;
}

pub fn minU64(a: u64, b: u64) u64 {
    return if (a < b) a else b;
}

pub fn maxU64(a: u64, b: u64) u64 {
    return if (a > b) a else b;
}

pub fn clampU64(value: u64, min_value: u64, max_value: u64) u64 {
    if (value < min_value) return min_value;
    if (value > max_value) return max_value;
    return value;
}

pub fn isPowerOfTwoU64(value: u64) bool {
    return value != 0 and (value & (value - 1)) == 0;
}

pub fn alignDownU64(value: u64, alignment: u64) u64 {
    if (!isPowerOfTwoU64(alignment)) return value;
    return value & ~(alignment - 1);
}

pub fn alignUpU64(value: u64, alignment: u64) u64 {
    if (!isPowerOfTwoU64(alignment)) return value;
    const mask = alignment - 1;
    if (value > maxIntU64() - mask) return maxIntU64() & ~mask;
    return (value + mask) & ~mask;
}

pub fn nextPowerOfTwoU64(input: u64) u64 {
    if (input <= 1) return 1;
    var value = input - 1;
    value |= value >> 1;
    value |= value >> 2;
    value |= value >> 4;
    value |= value >> 8;
    value |= value >> 16;
    value |= value >> 32;
    if (value == maxIntU64()) return maxIntU64();
    return value + 1;
}

pub fn lerpF(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t;
}

pub fn lerpClampedF(a: f32, b: f32, t: f32) f32 {
    return lerpF(a, b, clamp01F(t));
}

pub fn smoothstepF(edge0: f32, edge1: f32, value: f32) f32 {
    if (edge0 == edge1) return if (value < edge0) 0.0 else 1.0;
    const t = clamp01F((value - edge0) / (edge1 - edge0));
    return t * t * (smoothstep_a - smoothstep_b * t);
}

pub fn smootherstepF(edge0: f32, edge1: f32, value: f32) f32 {
    if (edge0 == edge1) return if (value < edge0) 0.0 else 1.0;
    const t = clamp01F((value - edge0) / (edge1 - edge0));
    return t * t * t * (t * (t * smootherstep_a - smootherstep_b) + smootherstep_c);
}

pub fn u8FromUnitF(value: f32) u8 {
    const scaled = clamp01F(value) * unit_u8_max + rounding_half;
    if (scaled <= 0.0) return 0;
    if (scaled >= unit_u8_max) return 255;
    return @intFromFloat(scaled);
}

pub fn dot2F(ax: f32, ay: f32, bx: f32, by: f32) f32 {
    return ax * bx + ay * by;
}

pub fn lengthSq2F(x: f32, y: f32) f32 {
    return dot2F(x, y, x, y);
}

pub fn distanceSq2F(ax: f32, ay: f32, bx: f32, by: f32) f32 {
    const dx = ax - bx;
    const dy = ay - by;
    return lengthSq2F(dx, dy);
}

pub fn isFiniteF(value: f32) bool {
    return value == value and value <= float_max and value >= -float_max;
}

pub fn floorF(value: f32) f32 {
    var truncated: i32 = @intFromFloat(value);
    if (@as(f32, @floatFromInt(truncated)) > value) truncated -= 1;
    return @floatFromInt(truncated);
}

pub fn ceilF(value: f32) f32 {
    var truncated: i32 = @intFromFloat(value);
    if (@as(f32, @floatFromInt(truncated)) < value) truncated += 1;
    return @floatFromInt(truncated);
}

pub fn floorI64(value: f32) i64 {
    var truncated: i64 = @intFromFloat(value);
    if (value < 0.0 and @as(f32, @floatFromInt(truncated)) != value) truncated -= 1;
    return truncated;
}

pub fn ceilI64(value: f32) i64 {
    var truncated: i64 = @intFromFloat(value);
    if (value > 0.0 and @as(f32, @floatFromInt(truncated)) != value) truncated += 1;
    return truncated;
}

pub fn lrintF(value: f32) isize {
    return @intFromFloat(if (value >= 0.0) value + rounding_half else value - rounding_half);
}

pub fn sqrtF(value: f32) f32 {
    if (value <= 0.0) return 0.0;
    var bits: u32 = @bitCast(value);
    bits = (bits >> 1) + sqrt_seed_bias;
    var estimate: f32 = @bitCast(bits);
    estimate = rounding_half * (estimate + value / estimate);
    estimate = rounding_half * (estimate + value / estimate);
    return estimate;
}

pub fn length2F(x: f32, y: f32) f32 {
    return sqrtF(lengthSq2F(x, y));
}

pub fn distance2F(ax: f32, ay: f32, bx: f32, by: f32) f32 {
    return sqrtF(distanceSq2F(ax, ay, bx, by));
}

pub fn rsqrtF(value: f32) f32 {
    if (value <= 0.0) return 0.0;
    const half = value * rounding_half;
    var bits: u32 = @bitCast(value);
    bits = inv_sqrt_magic - (bits >> 1);
    var estimate: f32 = @bitCast(bits);
    estimate = estimate * (inv_sqrt_refine - half * estimate * estimate);
    estimate = estimate * (inv_sqrt_refine - half * estimate * estimate);
    return estimate;
}

pub fn atan2F(y: f32, x: f32) f32 {
    if (y == 0.0) return if (x > 0.0) 0.0 else pi;
    if (x == 0.0) {
        if (y > 0.0) return half_pi;
        if (y < 0.0) return -half_pi;
        return 0.0;
    }

    const abs_y = absF(y) + atan2_epsilon;
    var angle: f32 = undefined;
    var ratio: f32 = undefined;
    if (x < 0.0) {
        ratio = (x + abs_y) / (abs_y - x);
        angle = three_quarter_pi;
    } else {
        ratio = (x - abs_y) / (x + abs_y);
        angle = quarter_pi;
    }
    angle += (atan2_cubic * ratio * ratio + atan2_linear) * ratio;
    return if (y < 0.0) -angle else angle;
}

fn maxIntU64() u64 {
    return ~@as(u64, 0);
}

test "scalar clamp align and power helpers match C helper semantics" {
    try expectEqual(@as(f32, 3.0), absF(-3.0));
    try expectEqual(@as(f32, 1.0), minF(1.0, 2.0));
    try expectEqual(@as(f32, 2.0), maxF(1.0, 2.0));
    try expectEqual(@as(f32, 1.0), clamp01F(4.0));
    try expectEqual(@as(usize, 4), clampSize(9, 1, 4));
    try expectEqual(@as(u64, 8), alignDownU64(15, 8));
    try expectEqual(@as(u64, 16), alignUpU64(15, 8));
    try expectEqual(maxIntU64() & ~@as(u64, 7), alignUpU64(maxIntU64() - 1, 8));
    try expectEqual(@as(u64, 16), nextPowerOfTwoU64(9));
    try expectEqual(maxIntU64(), nextPowerOfTwoU64(maxIntU64()));
    try expect(isPowerOfTwoU64(1024));
    try expect(!isPowerOfTwoU64(0));
}

test "float interpolation and geometry helpers match deterministic C formulas" {
    try expectEqual(@as(f32, 5.0), lerpF(0.0, 10.0, 0.5));
    try expectEqual(@as(f32, 10.0), lerpClampedF(0.0, 10.0, 2.0));
    try expectEqual(@as(f32, 0.5), smoothstepF(0.0, 1.0, 0.5));
    try expectEqual(@as(f32, 0.5), smootherstepF(0.0, 1.0, 0.5));
    try expectEqual(@as(u8, 0), u8FromUnitF(-1.0));
    try expectEqual(@as(u8, 128), u8FromUnitF(0.5));
    try expectEqual(@as(u8, 255), u8FromUnitF(2.0));
    try expectEqual(@as(f32, 11.0), dot2F(1.0, 2.0, 3.0, 4.0));
    try expectEqual(@as(f32, 25.0), lengthSq2F(3.0, 4.0));
    try expectEqual(@as(f32, 25.0), distanceSq2F(0.0, 0.0, 3.0, 4.0));
    const nan: f32 = @bitCast(@as(u32, 0x7fc0_0000));
    try expect(isFiniteF(1.0));
    try expect(!isFiniteF(nan));
}

test "rounding and approximate transcendental helpers stay in expected bands" {
    try expectEqual(@as(f32, -2.0), floorF(-1.25));
    try expectEqual(@as(f32, -1.0), ceilF(-1.25));
    try expectEqual(@as(i64, -2), floorI64(-1.25));
    try expectEqual(@as(i64, -1), ceilI64(-1.25));
    try expectEqual(@as(isize, 2), lrintF(1.6));
    try expectEqual(@as(isize, -2), lrintF(-1.6));
    try expectApproxEqAbs(@as(f32, 5.0), sqrtF(25.0), 0.01);
    try expectApproxEqAbs(@as(f32, 5.0), length2F(3.0, 4.0), 0.01);
    try expectApproxEqAbs(@as(f32, 5.0), distance2F(0.0, 0.0, 3.0, 4.0), 0.01);
    try expectApproxEqAbs(@as(f32, 0.2), rsqrtF(25.0), 0.01);
    try expectApproxEqAbs(quarter_pi, atan2F(1.0, 1.0), 0.01);
    try expectApproxEqAbs(-half_pi, atan2F(-1.0, 0.0), 0.01);
}

fn expect(condition: bool) !void {
    if (!condition) return error.TestExpectedTrue;
}

fn expectEqual(expected: anytype, actual: @TypeOf(expected)) !void {
    if (actual != expected) return error.TestExpectedEqual;
}

fn expectApproxEqAbs(expected: f32, actual: f32, tolerance: f32) !void {
    if (absF(actual - expected) > tolerance) return error.TestExpectedApproxEqual;
}
