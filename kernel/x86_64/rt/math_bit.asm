; EdgeRun bit-level operations — x86_64 assembly
; System V AMD64 ABI: arg1=rdi, arg2=rsi, arg3=rdx, arg4=rcx

; ==================================================================
; er_is_power_of_two_u64 — check if value is a power of two
; Returns 1 if value != 0 and (value & (value - 1)) == 0
; int er_is_power_of_two_u64(uint64_t value)
; ==================================================================
er_fn er_is_power_of_two_u64
    mov     rax, rdi
    er_check_zero rax, .not_pow2
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
    er_check_zero rcx, .align_down_done
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
    er_check_zero rcx, .align_up_done
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
    er_check_zero rsi, .div_ceil_zero
    er_check_zero rdi, .div_ceil_zero
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
    er_check_zero rdi, .log2_zero
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
    er_check_zero rdi, .pow2_zero
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
    er_check_zero esi, .div_ceil32_zero
    er_check_zero edi, .div_ceil32_zero
    mov     eax, edi
    dec     eax
    xor     edx, edx
    div     esi
    inc     eax
    er_ret
.div_ceil32_zero:
    xor     eax, eax
    er_ret
