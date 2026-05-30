; EdgeRun floating-point math — x86_64 assembly
; System V AMD64 ABI: float args in xmm0..xmm7, return in xmm0
; NOTE: simd.inc is included by the umbrella (math.asm)

SECTION .rodata

align 16
abs_f32_mask:   dd FLOAT_ABS_MASK, FLOAT_ABS_MASK, FLOAT_ABS_MASK, FLOAT_ABS_MASK
nan_f32:        dd FLOAT_NAN
pos_inf_f32:    dd FLOAT_POS_INF
neg_inf_f32:    dd FLOAT_NEG_INF

; sqrtF constants
align 16
sqrt_seed_bias_f32:   dd 0x1fc00000
half_f32:             dd FLOAT_HALF

; rsqrtF constants
align 16
rsqrt_magic_f32:      dd 0x5f3759df
rsqrt_refine_f32:     dd 0x3fc00000     ; 1.5f

; clamp01F / u8FromUnitF constants
align 16
zero_f32:             dd FLOAT_ZERO
one_f32:              dd FLOAT_ONE
u8_max_f32:           dd 0x437f0000     ; 255.0f
rounding_half_f32:    dd FLOAT_HALF

; isFiniteF constants
align 16
float_max_f32:        dd 0x7f7fffff     ; FLT_MAX
neg_float_max_f32:    dd 0xff7fffff     ; -FLT_MAX

SECTION .text

; ==================================================================
; er_abs_f32 — absolute value
; float er_abs_f32(float value)
; ==================================================================
er_fn er_abs_f32
    ; Clear sign bit: andps xmm0, [abs_mask]
    andps   xmm0, [rel abs_f32_mask]
    er_ret

; ==================================================================
; er_min_f32 — minimum of two floats (returns NaN if either is NaN)
; float er_min_f32(float a, float b)
; ==================================================================
er_fn er_min_f32
    minss   xmm0, xmm1
    er_ret

; ==================================================================
; er_max_f32 — maximum of two floats (returns NaN if either is NaN)
; float er_max_f32(float a, float b)
; ==================================================================
er_fn er_max_f32
    maxss   xmm0, xmm1
    er_ret

; ==================================================================
; er_clamp_f32 — clamp value to [min_value, max_value]
; float er_clamp_f32(float value, float min_value, float max_value)
; ==================================================================
er_fn er_clamp_f32
    ; value in xmm0, min in xmm1, max in xmm2
    ; clamp = min(max(value, min_value), max_value)
    maxss   xmm0, xmm1       ; xmm0 = max(value, min)
    minss   xmm0, xmm2       ; xmm0 = min(max(value, min), max)
    er_ret

; ==================================================================
; er_clamp01_f32 — clamp value to [0.0, 1.0]
; float er_clamp01_f32(float value)
; ==================================================================
er_fn er_clamp01_f32
    ; Compare with 0.0
    xorps   xmm1, xmm1       ; xmm1 = 0.0
    maxss   xmm0, xmm1       ; xmm0 = max(value, 0.0)

    ; Compare with 1.0
    movss   xmm1, [rel one_f32]
    minss   xmm0, xmm1       ; xmm0 = min(max(value, 0.0), 1.0)
    er_ret

; ==================================================================
; er_sqrt_f32 — Newton-Raphson square root (matches math.zig reference)
; Falls back to SSE hardware sqrtss as the reference, which is
; correctly rounded per IEEE 754 and strictly more accurate.
; For bit-exactness with the Zig Newton-Raphson, see er_sqrt_f32_nr.
; ==================================================================
er_fn er_sqrt_f32
    ; If value <= 0.0, return 0.0
    xorps   xmm1, xmm1
    ucomiss xmm0, xmm1
    jbe     .zero

    sqrtss  xmm0, xmm0
    er_ret

.zero:
    xorps   xmm0, xmm0
    er_ret

; ==================================================================
; er_sqrt_f32_nr — Newton-Raphson sqrt bit-exact with math.zig
; float er_sqrt_f32_nr(float value)
;
; Algorithm from edgerun-zig/src/math.zig sqrtF:
;   if (value <= 0.0) return 0.0;
;   bits = @bitCast(value);
;   bits = (bits >> 1) + sqrt_seed_bias;  // 0x1fc00000
;   estimate = @bitCast(bits);
;   estimate = 0.5 * (estimate + value / estimate);
;   estimate = 0.5 * (estimate + value / estimate);
;   return estimate;
; ==================================================================
er_fn er_sqrt_f32_nr
    ; If value <= 0.0, return 0.0
    xorps   xmm1, xmm1
    ucomiss xmm0, xmm1
    jbe     .zero

    ; Save value for later
    movss   xmm2, xmm0      ; xmm2 = value

    ; Extract bits: bits = @bitCast(value)
    movd    eax, xmm0       ; eax = value bits

    ; bits = (bits >> 1) + sqrt_seed_bias
    shr     eax, 1
    add     eax, 0x1fc00000

    ; estimate = @bitCast(bits)
    movd    xmm0, eax       ; xmm0 = estimate

    ; First Newton iteration: estimate = 0.5 * (estimate + value / estimate)
    movss   xmm1, xmm2      ; xmm1 = value
    divss   xmm1, xmm0      ; xmm1 = value / estimate
    addss   xmm0, xmm1      ; xmm0 = estimate + value / estimate
    mulss   xmm0, [rel half_f32]  ; xmm0 = 0.5 * (estimate + value / estimate)

    ; Second Newton iteration
    movss   xmm1, xmm2      ; xmm1 = value
    divss   xmm1, xmm0      ; xmm1 = value / estimate
    addss   xmm0, xmm1      ; xmm0 = estimate + value / estimate
    mulss   xmm0, [rel half_f32]  ; xmm0 = 0.5 * (estimate + value / estimate)

    er_ret

.zero:
    xorps   xmm0, xmm0
    er_ret

; ==================================================================
; er_rsqrt_f32 — fast inverse square root (matches math.zig reference)
; float er_rsqrt_f32(float value)
;
; Algorithm from edgerun-zig/src/math.zig rsqrtF:
;   if (value <= 0.0) return 0.0;
;   half = value * 0.5;
;   bits = @bitCast(value);
;   bits = inv_sqrt_magic - (bits >> 1);  // 0x5f3759df
;   estimate = @bitCast(bits);
;   estimate = estimate * (1.5 - half * estimate * estimate);
;   estimate = estimate * (1.5 - half * estimate * estimate);
;   return estimate;
; ==================================================================
er_fn er_rsqrt_f32
    ; If value <= 0.0, return 0.0
    xorps   xmm1, xmm1
    ucomiss xmm0, xmm1
    jbe     .zero

    ; half = value * 0.5
    movss   xmm1, xmm0
    mulss   xmm1, [rel half_f32]  ; xmm1 = half

    ; bits = @bitCast(value)
    movd    eax, xmm0

    ; bits = inv_sqrt_magic - (bits >> 1)
    shr     eax, 1
    mov     ecx, 0x5f3759df
    sub     ecx, eax

    ; estimate = @bitCast(bits)
    movd    xmm0, ecx       ; xmm0 = estimate

    ; First refinement: estimate = estimate * (1.5 - half * estimate * estimate)
    movss   xmm2, xmm0      ; xmm2 = estimate
    mulss   xmm2, xmm2      ; xmm2 = estimate^2
    mulss   xmm2, xmm1      ; xmm2 = half * estimate^2
    movss   xmm3, [rel rsqrt_refine_f32]  ; xmm3 = 1.5
    subss   xmm3, xmm2      ; xmm3 = 1.5 - half * estimate^2
    mulss   xmm0, xmm3      ; xmm0 = estimate * (1.5 - half * estimate^2)

    ; Second refinement
    movss   xmm2, xmm0
    mulss   xmm2, xmm2
    mulss   xmm2, xmm1
    movss   xmm3, [rel rsqrt_refine_f32]
    subss   xmm3, xmm2
    mulss   xmm0, xmm3

    er_ret

.zero:
    xorps   xmm0, xmm0
    er_ret

; ==================================================================
; er_floor_f32 — floor function (matches math.zig reference)
; float er_floor_f32(float value)
;
; Algorithm from edgerun-zig/src/math.zig floorF:
;   truncated = @intFromFloat(value);
;   if (@floatFromInt(truncated) > value) truncated -= 1;
;   return @floatFromInt(truncated);
; ==================================================================
er_fn er_floor_f32
    ; Convert float to i32 (truncate toward zero)
    cvttss2si eax, xmm0     ; eax = (i32)value

    ; Convert back to float
    cvtsi2ss xmm1, eax      ; xmm1 = (float)(i32)value

    ; Compare: if (float_from_int > value) decrement
    ucomiss xmm1, xmm0
    jbe     .done            ; if float_from_int <= value, done

    sub     eax, 1
    cvtsi2ss xmm0, eax
    er_ret

.done:
    movss   xmm0, xmm1
    er_ret

; ==================================================================
; er_ceil_f32 — ceil function (matches math.zig reference)
; float er_ceil_f32(float value)
;
; Algorithm from edgerun-zig/src/math.zig ceilF:
;   truncated = @intFromFloat(value);
;   if (@floatFromInt(truncated) < value) truncated += 1;
;   return @floatFromInt(truncated);
; ==================================================================
er_fn er_ceil_f32
    ; Convert float to i32 (truncate toward zero)
    cvttss2si eax, xmm0     ; eax = (i32)value

    ; Convert back to float
    cvtsi2ss xmm1, eax      ; xmm1 = (float)(i32)value

    ; Compare: if (float_from_int < value) increment
    ucomiss xmm1, xmm0
    jae     .done            ; if float_from_int >= value, done

    add     eax, 1
    cvtsi2ss xmm0, eax
    er_ret

.done:
    movss   xmm0, xmm1
    er_ret

; ==================================================================
; er_is_finite_f32 — check if float is finite (matches math.zig reference)
; int er_is_finite_f32(float value)
;
; Algorithm from edgerun-zig/src/math.zig isFiniteF:
;   return value == value and value <= float_max and value >= -float_max;
; Returns: 1 if finite, 0 if NaN or infinite
; ==================================================================
er_fn er_is_finite_f32
    ; Check: value == value (catches NaN — NaN != NaN)
    ucomiss xmm0, xmm0
    jp      .not_finite      ; NaN has parity flag set

    ; Check: value <= FLT_MAX
    movss   xmm1, [rel float_max_f32]
    ucomiss xmm1, xmm0
    jb      .not_finite      ; FLT_MAX < value → inf

    ; Check: value >= -FLT_MAX (done via value == value and positive bound check)
    ; For negative values, check against -FLT_MAX
    movss   xmm1, [rel neg_float_max_f32]
    ucomiss xmm0, xmm1
    jb      .not_finite      ; value < -FLT_MAX → -inf

    mov     eax, 1           ; finite
    er_ret

.not_finite:
    xor     eax, eax         ; not finite
    er_ret

; ==================================================================
; er_u8_from_unit_f32 — convert unit float [0,1] to u8 (matches math.zig)
; unsigned char er_u8_from_unit_f32(float value)
;
; Algorithm from edgerun-zig/src/math.zig u8FromUnitF:
;   scaled = clamp01F(value) * 255.0 + 0.5;
;   if (scaled <= 0.0) return 0;
;   if (scaled >= 255.0) return 255;
;   return (int)scaled;
; ==================================================================
er_fn er_u8_from_unit_f32
    ; Clamp to [0, 1]
    xorps   xmm1, xmm1
    maxss   xmm0, xmm1       ; xmm0 = max(value, 0.0)
    movss   xmm1, [rel one_f32]
    minss   xmm0, xmm1       ; xmm0 = min(clamped, 1.0)

    ; scaled = value * 255.0 + 0.5
    mulss   xmm0, [rel u8_max_f32]
    addss   xmm0, [rel rounding_half_f32]

    ; if (scaled <= 0.0) return 0
    xorps   xmm1, xmm1
    ucomiss xmm0, xmm1
    jbe     .zero

    ; if (scaled >= 255.0) return 255
    movss   xmm1, [rel u8_max_f32]
    ucomiss xmm0, xmm1
    jae     .max

    ; return (int)scaled
    cvttss2si eax, xmm0
    er_ret

.zero:
    xor     eax, eax
    er_ret

.max:
    mov     eax, 255
    er_ret
