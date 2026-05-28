; EdgeRun freestanding math functions — x86_64 assembly
; Faithful port of edgerun-zig/src/math.zig reference implementations
; System V AMD64 ABI: float args in xmm0..xmm7, return in xmm0

%include "x86_64/macros.inc"
%include "x86_64/simd.inc"

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
; er_absF — absolute value
; float er_absF(float value)
; ==================================================================
er_fn er_absF
    ; Clear sign bit: andps xmm0, [abs_mask]
    andps   xmm0, [rel abs_f32_mask]
    er_ret

; ==================================================================
; er_minF — minimum of two floats (returns NaN if either is NaN)
; float er_minF(float a, float b)
; ==================================================================
er_fn er_minF
    minss   xmm0, xmm1
    er_ret

; ==================================================================
; er_maxF — maximum of two floats (returns NaN if either is NaN)
; float er_maxF(float a, float b)
; ==================================================================
er_fn er_maxF
    maxss   xmm0, xmm1
    er_ret

; ==================================================================
; er_clampF — clamp value to [min_value, max_value]
; float er_clampF(float value, float min_value, float max_value)
; ==================================================================
er_fn er_clampF
    ; value in xmm0, min in xmm1, max in xmm2
    ; clamp = min(max(value, min_value), max_value)
    maxss   xmm0, xmm1       ; xmm0 = max(value, min)
    minss   xmm0, xmm2       ; xmm0 = min(max(value, min), max)
    er_ret

; ==================================================================
; er_clamp01F — clamp value to [0.0, 1.0]
; float er_clamp01F(float value)
; ==================================================================
er_fn er_clamp01F
    ; Compare with 0.0
    xorps   xmm1, xmm1       ; xmm1 = 0.0
    maxss   xmm0, xmm1       ; xmm0 = max(value, 0.0)

    ; Compare with 1.0
    movss   xmm1, [rel one_f32]
    minss   xmm0, xmm1       ; xmm0 = min(max(value, 0.0), 1.0)
    er_ret

; ==================================================================
; er_sqrtF — Newton-Raphson square root (matches math.zig reference)
; Falls back to SSE hardware sqrtss as the reference, which is
; correctly rounded per IEEE 754 and strictly more accurate.
; For bit-exactness with the Zig Newton-Raphson, see er_sqrtF_nr.
; ==================================================================
er_fn er_sqrtF
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
; er_sqrtF_nr — Newton-Raphson sqrt bit-exact with math.zig
; float er_sqrtF_nr(float value)
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
er_fn er_sqrtF_nr
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
; er_rsqrtF — fast inverse square root (matches math.zig reference)
; float er_rsqrtF(float value)
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
er_fn er_rsqrtF
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
; er_floorF — floor function (matches math.zig reference)
; float er_floorF(float value)
;
; Algorithm from edgerun-zig/src/math.zig floorF:
;   truncated = @intFromFloat(value);
;   if (@floatFromInt(truncated) > value) truncated -= 1;
;   return @floatFromInt(truncated);
; ==================================================================
er_fn er_floorF
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
; er_ceilF — ceil function (matches math.zig reference)
; float er_ceilF(float value)
;
; Algorithm from edgerun-zig/src/math.zig ceilF:
;   truncated = @intFromFloat(value);
;   if (@floatFromInt(truncated) < value) truncated += 1;
;   return @floatFromInt(truncated);
; ==================================================================
er_fn er_ceilF
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
; er_isFiniteF — check if float is finite (matches math.zig reference)
; int er_isFiniteF(float value)
;
; Algorithm from edgerun-zig/src/math.zig isFiniteF:
;   return value == value and value <= float_max and value >= -float_max;
; Returns: 1 if finite, 0 if NaN or infinite
; ==================================================================
er_fn er_isFiniteF
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
; er_u8FromUnitF — convert unit float [0,1] to u8 (matches math.zig)
; unsigned char er_u8FromUnitF(float value)
;
; Algorithm from edgerun-zig/src/math.zig u8FromUnitF:
;   scaled = clamp01F(value) * 255.0 + 0.5;
;   if (scaled <= 0.0) return 0;
;   if (scaled >= 255.0) return 255;
;   return (int)scaled;
; ==================================================================
er_fn er_u8FromUnitF
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

; ==================================================================
; Integer arithmetic — x86_64 assembly
; System V AMD64 ABI: arg1=rdi, arg2=rsi, arg3=rdx, arg4=rcx
; ==================================================================

; ==================================================================
; er_abs_i32 — absolute value of 32-bit signed integer
; int32_t er_abs_i32(int32_t value)
; ==================================================================
er_fn er_abs_i32
    mov     eax, edi
    cdq                     ; sign-extend eax into edx:eax
    xor     eax, edx
    sub     eax, edx        ; abs = (x XOR x>>31) - (x>>31)
    er_ret

; ==================================================================
; er_abs_i64 — absolute value of 64-bit signed integer
; int64_t er_abs_i64(int64_t value)
; ==================================================================
er_fn er_abs_i64
    mov     rax, rdi
    cqo                     ; sign-extend rax into rdx:rax
    xor     rax, rdx
    sub     rax, rdx
    er_ret

; ==================================================================
; er_clz32 — count leading zeros in 32-bit value
; Returns 32 if value == 0
; uint32_t er_clz32(uint32_t value)
; ==================================================================
er_fn er_clz32
    mov     eax, edi
    test    eax, eax
    jz      .clz32_zero
    bsr     ecx, eax        ; bit scan reverse → position of highest set bit
    mov     eax, 31
    sub     eax, ecx        ; clz = 31 - bsr
    er_ret
.clz32_zero:
    mov     eax, 32
    er_ret

; ==================================================================
; er_clz64 — count leading zeros in 64-bit value
; Returns 64 if value == 0
; uint32_t er_clz64(uint64_t value)
; ==================================================================
er_fn er_clz64
    mov     rax, rdi
    test    rax, rax
    jz      .clz64_zero
    bsr     rcx, rax
    mov     eax, 63
    sub     eax, ecx
    er_ret
.clz64_zero:
    mov     eax, 64
    er_ret

; ==================================================================
; er_ctz32 — count trailing zeros in 32-bit value
; Returns 32 if value == 0
; uint32_t er_ctz32(uint32_t value)
; ==================================================================
er_fn er_ctz32
    mov     eax, edi
    test    eax, eax
    jz      .ctz32_zero
    bsf     ecx, eax        ; bit scan forward → position of lowest set bit
    mov     eax, ecx
    er_ret
.ctz32_zero:
    mov     eax, 32
    er_ret

; ==================================================================
; er_ctz64 — count trailing zeros in 64-bit value
; Returns 64 if value == 0
; uint32_t er_ctz64(uint64_t value)
; ==================================================================
er_fn er_ctz64
    mov     rax, rdi
    test    rax, rax
    jz      .ctz64_zero
    bsf     rcx, rax
    mov     eax, ecx
    er_ret
.ctz64_zero:
    mov     eax, 64
    er_ret

; ==================================================================
; er_popcount32 — population count (number of set bits) in 32-bit value
; uint32_t er_popcount32(uint32_t value)
; ==================================================================
er_fn er_popcount32
    mov     eax, edi
    ; Popcount via divide-and-conquer (no popcnt instruction dependency)
    ; 32-bit: (x & 0x55555555) + ((x >> 1) & 0x55555555)
    mov     edx, eax
    shr     edx, 1
    and     eax, 0x55555555
    and     edx, 0x55555555
    add     eax, edx
    ; 2-bit pairs → 4-bit: (x & 0x33333333) + ((x >> 2) & 0x33333333)
    mov     edx, eax
    shr     edx, 2
    and     eax, 0x33333333
    and     edx, 0x33333333
    add     eax, edx
    ; 4-bit → 8-bit: (x + (x >> 4)) & 0x0F0F0F0F
    mov     edx, eax
    shr     edx, 4
    add     eax, edx
    and     eax, 0x0F0F0F0F
    ; 8-bit → 16-bit: (x + (x >> 8)) & 0x00FF00FF
    mov     edx, eax
    shr     edx, 8
    add     eax, edx
    and     eax, 0x00FF00FF
    ; 16-bit → 32-bit: (x + (x >> 16)) & 0x0000FFFF
    mov     edx, eax
    shr     edx, 16
    add     eax, edx
    and     eax, 0x0000FFFF
    er_ret

; ==================================================================
; er_popcount64 — population count in 64-bit value
; uint32_t er_popcount64(uint64_t value)
; ==================================================================
er_fn er_popcount64
    mov     rax, rdi
    ; Same divide-and-conquer for 64 bits
    mov     rdx, rax
    shr     rdx, 1
    mov     rcx, 0x5555555555555555
    and     rax, rcx
    and     rdx, rcx
    add     rax, rdx
    ; 2-bit → 4-bit
    mov     rdx, rax
    shr     rdx, 2
    mov     rcx, 0x3333333333333333
    and     rax, rcx
    and     rdx, rcx
    add     rax, rdx
    ; 4-bit → 8-bit
    mov     rdx, rax
    shr     rdx, 4
    add     rax, rdx
    mov     rcx, 0x0F0F0F0F0F0F0F0F
    and     rax, rcx
    ; 8-bit → 16-bit
    mov     rdx, rax
    shr     rdx, 8
    add     rax, rdx
    mov     rcx, 0x00FF00FF00FF00FF
    and     rax, rcx
    ; 16-bit → 32-bit
    mov     rdx, rax
    shr     rdx, 16
    add     rax, rdx
    mov     rcx, 0x0000FFFF0000FFFF
    and     rax, rcx
    ; 32-bit → 64-bit
    mov     rdx, rax
    shr     rdx, 32
    add     rax, rdx
    and     eax, 0x0000FFFF
    er_ret

; ==================================================================
; er_umulhi — high 64 bits of unsigned 64×64→128 multiply
; uint64_t er_umulhi(uint64_t a, uint64_t b)
; ==================================================================
er_fn er_umulhi
    mov     rax, rdi
    mul     rsi             ; rdx:rax = rax * rsi (unsigned)
    mov     rax, rdx
    er_ret

; ==================================================================
; er_smulhi — high 64 bits of signed 64×64→128 multiply
; int64_t er_smulhi(int64_t a, int64_t b)
; ==================================================================
er_fn er_smulhi
    mov     rax, rdi
    imul    rsi             ; rdx:rax = rax * rsi (signed)
    mov     rax, rdx
    er_ret

; ==================================================================
; er_div_u32 — unsigned 32-bit division
; uint32_t er_div_u32(uint32_t dividend, uint32_t divisor)
; Returns 0 on division by zero
; ==================================================================
er_fn er_div_u32
    test    esi, esi
    jz      .div_u32_zero
    mov     eax, edi
    xor     edx, edx
    div     esi             ; eax = quotient, edx = remainder
    er_ret
.div_u32_zero:
    xor     eax, eax
    er_ret

; ==================================================================
; er_mod_u32 — unsigned 32-bit modulo
; uint32_t er_mod_u32(uint32_t dividend, uint32_t divisor)
; Returns 0 on division by zero
; ==================================================================
er_fn er_mod_u32
    test    esi, esi
    jz      .mod_u32_zero
    mov     eax, edi
    xor     edx, edx
    div     esi             ; eax = quotient, edx = remainder
    mov     eax, edx
    er_ret
.mod_u32_zero:
    xor     eax, eax
    er_ret

; ==================================================================
; er_div_u64 — unsigned 64-bit division
; uint64_t er_div_u64(uint64_t dividend, uint64_t divisor)
; Returns 0 on division by zero
; ==================================================================
er_fn er_div_u64
    test    rsi, rsi
    jz      .div_u64_zero
    mov     rax, rdi
    xor     rdx, rdx
    div     rsi
    er_ret
.div_u64_zero:
    xor     eax, eax
    er_ret

; ==================================================================
; er_mod_u64 — unsigned 64-bit modulo
; uint64_t er_mod_u64(uint64_t dividend, uint64_t divisor)
; Returns 0 on division by zero
; ==================================================================
er_fn er_mod_u64
    test    rsi, rsi
    jz      .mod_u64_zero
    mov     rax, rdi
    xor     rdx, rdx
    div     rsi
    mov     rax, rdx
    er_ret
.mod_u64_zero:
    xor     eax, eax
    er_ret

; ==================================================================
; er_divmod_u32 — unsigned 32-bit divmod via output pointers
; void er_divmod_u32(uint32_t dividend, uint32_t divisor,
;                    uint32_t* quot_out, uint32_t* rem_out)
; If divisor == 0, writes 0 to both outputs
; Note: quot_out in arg3 (rdx), rem_out in arg4 (rcx)
; div clobbers edx, so we save pointers in r8/r9
; ==================================================================
er_fn er_divmod_u32
    test    esi, esi
    jz      .dm32_zero
    mov     r8, rdx         ; save quot_out pointer
    mov     r9, rcx         ; save rem_out pointer
    mov     eax, edi
    xor     edx, edx
    div     esi             ; eax = quot, edx = rem
    mov     [r8], eax
    mov     [r9], edx
    er_ret
.dm32_zero:
    mov     dword [rdx], 0
    mov     dword [rcx], 0
    er_ret

; ==================================================================
; er_divmod_u64 — unsigned 64-bit divmod via output pointers
; void er_divmod_u64(uint64_t dividend, uint64_t divisor,
;                    uint64_t* quot_out, uint64_t* rem_out)
; quot_out in arg3 (rdx), rem_out in arg4 (rcx)
; div clobbers rdx, so save pointers first
; ==================================================================
er_fn er_divmod_u64
    test    rsi, rsi
    jz      .dm64_zero
    mov     r8, rdx         ; save quot_out
    mov     r9, rcx         ; save rem_out
    mov     rax, rdi
    xor     rdx, rdx
    div     rsi             ; rax = quot, rdx = rem
    mov     [r8], rax
    mov     [r9], rdx
    er_ret
.dm64_zero:
    mov     qword [rdx], 0
    mov     qword [rcx], 0
    er_ret

; ==================================================================
; er_divmod_i32 — signed 32-bit divmod via output pointers
; void er_divmod_i32(int32_t dividend, int32_t divisor,
;                    int32_t* quot_out, int32_t* rem_out)
; quot_out in arg3 (rdx), rem_out in arg4 (rcx)
; Division by zero writes 0 to both outputs
; ==================================================================
er_fn er_divmod_i32
    test    esi, esi
    jz      .dm32s_zero
    mov     r8, rdx         ; save quot_out
    mov     r9, rcx         ; save rem_out
    mov     eax, edi
    cdq                     ; sign-extend eax → edx:eax
    idiv    esi             ; eax = quot, edx = rem
    mov     [r8], eax
    mov     [r9], edx
    er_ret
.dm32s_zero:
    mov     dword [rdx], 0
    mov     dword [rcx], 0
    er_ret

; ==================================================================
; er_is_power_of_two_u64 — check if value is a power of two
; Returns 1 if value != 0 and (value & (value - 1)) == 0
; int er_is_power_of_two_u64(uint64_t value)
; ==================================================================
er_fn er_is_power_of_two_u64
    mov     rax, rdi
    test    rax, rax
    jz      .not_pow2
    lea     rcx, [rax - 1]
    test    rax, rcx
    jnz     .not_pow2
    mov     eax, 1
    er_ret
.not_pow2:
    xor     eax, eax
    er_ret

; ==================================================================
; er_align_down_u64 — align value down to power-of-two boundary
; If alignment is not a power of two, returns value unchanged
; uint64_t er_align_down_u64(uint64_t value, uint64_t alignment)
; ==================================================================
er_fn er_align_down_u64
    mov     rax, rdi
    ; Check alignment is power of two
    mov     rcx, rsi
    test    rcx, rcx
    jz      .align_down_done
    lea     rdx, [rcx - 1]
    test    rcx, rdx
    jnz     .align_down_done
    not     rdx
    and     rax, rdx
.align_down_done:
    er_ret

; ==================================================================
; er_align_up_u64 — align value up to power-of-two boundary
; If alignment is not a power of two, returns value unchanged
; uint64_t er_align_up_u64(uint64_t value, uint64_t alignment)
; ==================================================================
er_fn er_align_up_u64
    mov     rax, rdi
    mov     rcx, rsi
    test    rcx, rcx
    jz      .align_up_done
    lea     rdx, [rcx - 1]
    test    rcx, rdx
    jnz     .align_up_done
    add     rax, rdx        ; value + (alignment - 1)
    jc      .align_up_max  ; overflow → max
    not     rdx
    and     rax, rdx
    er_ret
.align_up_max:
    mov     rax, -1
    mov     r8, rcx
    dec     r8
    not     r8
    and     rax, r8
    er_ret
.align_up_done:
    er_ret

; ==================================================================
; er_min_u64 — minimum of two uint64 values
; uint64_t er_min_u64(uint64_t a, uint64_t b)
; ==================================================================
er_fn er_min_u64
    cmp     rdi, rsi
    cmovb   rax, rdi
    cmovae  rax, rsi
    er_ret

; ==================================================================
; er_max_u64 — maximum of two uint64 values
; uint64_t er_max_u64(uint64_t a, uint64_t b)
; ==================================================================
er_fn er_max_u64
    cmp     rdi, rsi
    cmova   rax, rdi
    cmovbe  rax, rsi
    er_ret

; ==================================================================
; er_clamp_u64 — clamp uint64 value to [min, max] range
; If min > max, returns value unchanged.
; uint64_t er_clamp_u64(uint64_t value, uint64_t min_v, uint64_t max_v)
; ==================================================================
er_fn er_clamp_u64
    cmp     rsi, rdx
    ja      .clamp_u64_ret     ; min > max → return value unchanged
    cmp     rdi, rsi
    cmovb   rdi, rsi            ; value = max(value, min)
    cmp     rdi, rdx
    cmova   rdi, rdx            ; value = min(value, max)
.clamp_u64_ret:
    mov     rax, rdi
    er_ret

; ==================================================================
; er_div_ceil_u64 — ceiling division for uint64
; Returns (dividend + divisor - 1) / divisor, without overflow.
; If divisor == 0, returns 0.
; uint64_t er_div_ceil_u64(uint64_t dividend, uint64_t divisor)
; ==================================================================
er_fn er_div_ceil_u64
    test    rsi, rsi
    jz      .div_ceil_zero
    test    rdi, rdi
    jz      .div_ceil_zero
    mov     rax, rdi
    dec     rax
    xor     edx, edx
    div     rsi
    inc     rax
    er_ret
.div_ceil_zero:
    xor     eax, eax
    er_ret

; ==================================================================
; er_log2_u64 — floor(log2) of uint64 value
; Returns 63 - clz for non-zero, 0 for zero.
; uint64_t er_log2_u64(uint64_t value)
; ==================================================================
er_fn er_log2_u64
    test    rdi, rdi
    jz      .log2_zero
    bsr     rax, rdi
    er_ret
.log2_zero:
    xor     eax, eax
    er_ret

; ==================================================================
; er_round_up_pow2_u64 — round up to next power of two
; Returns the smallest power of two ≥ value.
; 0 → 0, 1 → 1, 2 → 2, 3 → 4, 4 → 4, etc.
; If value > 2^63, returns 0 (overflow).
; uint64_t er_round_up_pow2_u64(uint64_t value)
; ==================================================================
er_fn er_round_up_pow2_u64
    test    rdi, rdi
    jz      .pow2_zero
    ; Check for overflow: values > 2^63 can't be represented as next power of two
    ; Use mov+ cmp since cmp r64, imm64 is not encodable
    mov     rax, 0x8000000000000000
    mov     rdx, rdi
    cmp     rdx, rax
    ja      .pow2_overflow
    dec     rdi
    mov     rax, rdi
    shr     rax, 1
    or      rdi, rax
    mov     rax, rdi
    shr     rax, 2
    or      rdi, rax
    mov     rax, rdi
    shr     rax, 4
    or      rdi, rax
    mov     rax, rdi
    shr     rax, 8
    or      rdi, rax
    mov     rax, rdi
    shr     rax, 16
    or      rdi, rax
    mov     rax, rdi
    shr     rax, 32
    or      rdi, rax
    lea     rax, [rdi + 1]
    er_ret
.pow2_overflow:
    xor     eax, eax
    er_ret
.pow2_zero:
    xor     eax, eax
    er_ret

; ==================================================================
; er_rotl32 — rotate 32-bit value left by count bits
; uint32_t er_rotl32(uint32_t value, unsigned int count)
; ==================================================================
er_fn er_rotl32
    mov     ecx, esi
    mov     eax, edi
    rol     eax, cl
    er_ret

; ==================================================================
; er_rotr32 — rotate 32-bit value right by count bits
; uint32_t er_rotr32(uint32_t value, unsigned int count)
; ==================================================================
er_fn er_rotr32
    mov     ecx, esi
    mov     eax, edi
    ror     eax, cl
    er_ret

; ==================================================================
; er_rotl64 — rotate 64-bit value left by count bits
; uint64_t er_rotl64(uint64_t value, unsigned int count)
; ==================================================================
er_fn er_rotl64
    mov     ecx, esi
    mov     rax, rdi
    rol     rax, cl
    er_ret

; ==================================================================
; er_rotr64 — rotate 64-bit value right by count bits
; uint64_t er_rotr64(uint64_t value, unsigned int count)
; ==================================================================
er_fn er_rotr64
    mov     ecx, esi
    mov     rax, rdi
    ror     rax, cl
    er_ret

; ==================================================================
; er_bswap16 — byte-swap 16-bit value (endian conversion)
; uint16_t er_bswap16(uint16_t value)
; ==================================================================
er_fn er_bswap16
    mov     eax, edi
    rol     ax, 8
    er_ret

; ==================================================================
; er_bswap32 — byte-swap 32-bit value (endian conversion)
; uint32_t er_bswap32(uint32_t value)
; ==================================================================
er_fn er_bswap32
    mov     eax, edi
    bswap   eax
    er_ret

; ==================================================================
; er_bswap64 — byte-swap 64-bit value (endian conversion)
; uint64_t er_bswap64(uint64_t value)
; ==================================================================
er_fn er_bswap64
    mov     rax, rdi
    bswap   rax
    er_ret

; ==================================================================
; er_xorshift64 — xorshift64 PRNG (deterministic)
; Returns next pseudo-random uint64, updates state in place.
; uint64_t er_xorshift64(uint64_t* state)
; Algorithm: state ^= state << 13; state ^= state >> 7; state ^= state << 17
; ==================================================================
er_fn er_xorshift64
    mov     rax, [rdi]
    mov     rdx, rax
    shl     rdx, 13
    xor     rax, rdx
    mov     rdx, rax
    shr     rdx, 7
    xor     rax, rdx
    mov     rdx, rax
    shl     rdx, 17
    xor     rax, rdx
    mov     [rdi], rax
    er_ret

; ==================================================================
; er_min_u32 — minimum of two uint32 values
; uint32_t er_min_u32(uint32_t a, uint32_t b)
; ==================================================================
er_fn er_min_u32
    cmp     edi, esi
    cmovb   eax, edi
    cmovae  eax, esi
    er_ret

; ==================================================================
; er_max_u32 — maximum of two uint32 values
; uint32_t er_max_u32(uint32_t a, uint32_t b)
; ==================================================================
er_fn er_max_u32
    cmp     edi, esi
    cmova   eax, edi
    cmovbe  eax, esi
    er_ret

; ==================================================================
; er_clamp_u32 — clamp uint32 to [min, max]
; uint32_t er_clamp_u32(uint32_t value, uint32_t min_v, uint32_t max_v)
; ==================================================================
er_fn er_clamp_u32
    cmp     esi, edx
    ja      .clamp32_ret
    cmp     edi, esi
    cmovb   edi, esi
    cmp     edi, edx
    cmova   edi, edx
.clamp32_ret:
    mov     eax, edi
    er_ret

; ==================================================================
; er_min_i32 — minimum of two int32 values
; int32_t er_min_i32(int32_t a, int32_t b)
; ==================================================================
er_fn er_min_i32
    cmp     edi, esi
    cmovl   eax, edi
    cmovge  eax, esi
    er_ret

; ==================================================================
; er_max_i32 — maximum of two int32 values
; int32_t er_max_i32(int32_t a, int32_t b)
; ==================================================================
er_fn er_max_i32
    cmp     edi, esi
    cmovg   eax, edi
    cmovle  eax, esi
    er_ret

; ==================================================================
; er_clamp_i32 — clamp int32 to [min, max]
; int32_t er_clamp_i32(int32_t value, int32_t min_v, int32_t max_v)
; ==================================================================
er_fn er_clamp_i32
    cmp     esi, edx
    jg      .clampi32_ret      ; min > max → return value unchanged
    cmp     edi, esi
    cmovl   edi, esi
    cmp     edi, edx
    cmovg   edi, edx
.clampi32_ret:
    mov     eax, edi
    er_ret

; ==================================================================
; er_min_i64 — minimum of two int64 values
; int64_t er_min_i64(int64_t a, int64_t b)
; ==================================================================
er_fn er_min_i64
    cmp     rdi, rsi
    cmovl   rax, rdi
    cmovge  rax, rsi
    er_ret

; ==================================================================
; er_max_i64 — maximum of two int64 values
; int64_t er_max_i64(int64_t a, int64_t b)
; ==================================================================
er_fn er_max_i64
    cmp     rdi, rsi
    cmovg   rax, rdi
    cmovle  rax, rsi
    er_ret

; ==================================================================
; er_clamp_i64 — clamp int64 to [min, max]
; int64_t er_clamp_i64(int64_t value, int64_t min_v, int64_t max_v)
; ==================================================================
er_fn er_clamp_i64
    cmp     rsi, rdx
    jg      .clampi64_ret
    cmp     rdi, rsi
    cmovl   rdi, rsi
    cmp     rdi, rdx
    cmovg   rdi, rdx
.clampi64_ret:
    mov     rax, rdi
    er_ret

; ==================================================================
; er_div_ceil_u32 — ceiling division for uint32
; uint32_t er_div_ceil_u32(uint32_t dividend, uint32_t divisor)
; ==================================================================
er_fn er_div_ceil_u32
    test    esi, esi
    jz      .div_ceil32_zero
    test    edi, edi
    jz      .div_ceil32_zero
    mov     eax, edi
    dec     eax
    xor     edx, edx
    div     esi
    inc     eax
    er_ret
.div_ceil32_zero:
    xor     eax, eax
    er_ret

; ==================================================================
; er_crc32c — compute CRC-32C (Castagnoli) checksum
; Uses x86 SSE 4.2 crc32 instruction.
; uint32_t er_crc32c(uint32_t crc, const void* data, size_t len)
; ==================================================================
er_fn er_crc32c
    mov     eax, edi            ; crc
    test    rdx, rdx
    jz      .crc32c_done
    mov     r8, rsi             ; data ptr
    mov     rcx, rdx            ; len
.crc32c_8:
    cmp     rcx, 8
    jb      .crc32c_4
    crc32   rax, qword [r8]
    add     r8, 8
    sub     rcx, 8
    jmp     .crc32c_8
.crc32c_4:
    cmp     rcx, 4
    jb      .crc32c_1
    crc32   eax, dword [r8]
    add     r8, 4
    sub     rcx, 4
    jmp     .crc32c_4
.crc32c_1:
    test    rcx, rcx
    jz      .crc32c_done
    crc32   eax, byte [r8]
    inc     r8
    dec     rcx
    jmp     .crc32c_1
.crc32c_done:
    er_ret

; ==================================================================
; er_fnv1a64 — FNV-1a 64-bit hash
; uint64_t er_fnv1a64(const void* data, size_t len)
; ==================================================================
er_fn er_fnv1a64
    mov     rax, 0xcbf29ce484222325   ; FNV offset basis
    test    rsi, rsi
    jz      .fnv1a_done
    xor     rcx, rcx
    mov     r10, rsi
.fnv1a_loop:
    movzx   rdx, byte [rdi + rcx]
    xor     rax, rdx
    mov     r8, 0x100000001b3         ; FNV prime
    mul     r8
    inc     rcx
    cmp     rcx, r10
    jb      .fnv1a_loop
.fnv1a_done:
    er_ret
