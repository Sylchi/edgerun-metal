; EdgeRun integer arithmetic — x86_64 assembly
; System V AMD64 ABI: arg1=rdi, arg2=rsi, arg3=rdx, arg4=rcx

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
    er_check_zero eax, .clz32_zero
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
    er_check_zero rax, .clz64_zero
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
    er_check_zero eax, .ctz32_zero
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
    er_check_zero rax, .ctz64_zero
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
    er_check_zero esi, .div_u32_zero
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
    er_check_zero esi, .mod_u32_zero
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
    er_check_zero rsi, .div_u64_zero
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
    er_check_zero rsi, .mod_u64_zero
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
    er_check_zero esi, .dm32_zero
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
    er_check_zero rsi, .dm64_zero
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
    er_check_zero esi, .dm32s_zero
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
