; EdgeRun byte/utility functions — x86_64 assembly
; System V AMD64 ABI
; Freestanding — no libc, no external dependencies.

%include "x86_64/macros.inc"

SECTION .text

; ==================================================================
; er_bytes_nonzero(buf, len) → bool
; rdi=buf, esi=len
; Returns eax=1 if any byte != 0, 0 if all zero. rdx=0.
; ==================================================================
er_fn er_bytes_nonzero
    test    esi, esi
    jz      .all_zero
    xor     eax, eax
.loop:
    cmp     byte [rdi + rax], 0
    jnz     .found
    inc     eax
    cmp     eax, esi
    jb      .loop
.all_zero:
    xor     eax, eax
    er_ok
    er_ret
.found:
    mov     eax, 1
    er_ok
    er_ret

; ==================================================================
; er_bytes_eql(a, len_a, b, len_b) → bool
; rdi=a, esi=len_a, rdx=b, ecx=len_b
; Returns eax=1 if len_a==len_b and content matches, else 0. rdx=0.
; ==================================================================
er_fn er_bytes_eql
    cmp     esi, ecx
    jne     .not_eql
    test    esi, esi
    jz      .eql             ; both zero-length → equal
    push    rcx
    xor     ecx, ecx
.loop:
    mov     al, [rdi + rcx]
    cmp     al, [rdx + rcx]
    jne     .not_eql_pop
    inc     ecx
    cmp     ecx, esi
    jb      .loop
    pop     rcx
.eql:
    mov     eax, 1
    er_ok
    er_ret
.not_eql_pop:
    pop     rcx
.not_eql:
    xor     eax, eax
    er_ok
    er_ret

; ==================================================================
; er_bytes_order(a, len_a, b, len_b) → -1, 0, or 1
; rdi=a, esi=len_a, rdx=b, ecx=len_b
; Returns eax = -1 if a < b, 0 if a == b, 1 if a > b. rdx=0.
; Compares lexicographically; shorter prefix is less.
; ==================================================================
er_fn er_bytes_order
    push    rbx
    mov     ebx, esi
    cmp     ebx, ecx
    jbe     .min_set
    mov     ebx, ecx
.min_set:
    xor     eax, eax
    test    ebx, ebx
    jz      .check_len
.loop:
    mov     r9b, [rdi + rax]
    mov     r8b, [rdx + rax]
    cmp     r9b, r8b
    jb      .less
    ja      .greater
    inc     eax
    cmp     eax, ebx
    jb      .loop
.check_len:
    ; All common prefix bytes equal — compare lengths
    cmp     esi, ecx
    jb      .less
    ja      .greater
    xor     eax, eax
    pop     rbx
    er_ok
    er_ret
.less:
    mov     rax, -1
    pop     rbx
    er_ok
    er_ret
.greater:
    mov     eax, 1
    pop     rbx
    er_ok
    er_ret

; ==================================================================
; er_bytes_zero(buf, len)
; rdi=buf, esi=len
; Zero out memory. No return value.
; ==================================================================
er_fn er_bytes_zero
    test    esi, esi
    jz      .zero_done
    xor     eax, eax
.zero_loop:
    mov     [rdi + rax], byte 0
    inc     eax
    cmp     eax, esi
    jb      .zero_loop
.zero_done:
    er_ret

; ==================================================================
; er_store16(out, value) → bool
; rdi=out, esi=value (u16)
; Little-endian store. Always returns 1. rdx=0.
; ==================================================================
er_fn er_store16
    mov     [rdi], si
    mov     eax, 1
    er_ok
    er_ret

; ==================================================================
; er_store32(out, value) → bool
; rdi=out, esi=value (u32)
; Little-endian store. Always returns 1. rdx=0.
; ==================================================================
er_fn er_store32
    mov     [rdi], esi
    mov     eax, 1
    er_ok
    er_ret

; ==================================================================
; er_store64(out, value) → bool
; rdi=out, esi=value (u64)
; Little-endian store. Always returns 1. rdx=0.
; ==================================================================
er_fn er_store64
    mov     [rdi], rsi
    mov     eax, 1
    er_ok
    er_ret

; ==================================================================
; er_storebe16(out, value) → bool
; rdi=out, esi=value (u16)
; Big-endian store. Always returns 1. rdx=0.
; ==================================================================
er_fn er_storebe16
    mov     [rdi], si
    mov     al, [rdi]
    mov     bl, [rdi + 1]
    mov     [rdi], bl
    mov     [rdi + 1], al
    mov     eax, 1
    er_ok
    er_ret

; ==================================================================
; er_storebe32(out, value) → bool
; rdi=out, esi=value (u32)
; Big-endian store. Always returns 1. rdx=0.
; ==================================================================
er_fn er_storebe32
    bswap   esi
    mov     [rdi], esi
    mov     eax, 1
    er_ok
    er_ret

; ==================================================================
; er_storebe64(out, value) → bool
; rdi=out, rdx=value (u64)
; Big-endian store. Always returns 1. rdx=0.
; ==================================================================
er_fn er_storebe64
    mov     rax, rsi
    bswap   rax
    mov     [rdi], rax
    mov     eax, 1
    er_ok
    er_ret

; ==================================================================
; er_load16(in) → u16 (or 0 if len < 2)
; rdi=in, esi=len
; Little-endian load. Returns u16 value in eax. rdx=error code.
; ==================================================================
er_fn er_load16
    cmp     esi, 2
    jb      .load16_fail
    movzx   eax, word [rdi]
    er_ok
    er_ret
.load16_fail:
    xor     eax, eax
    er_err  1
    er_ret

; ==================================================================
; er_load32(in) → u32
; rdi=in, esi=len
; Little-endian load. rdx=0 on success, 1 on error.
; ==================================================================
er_fn er_load32
    cmp     esi, 4
    jb      .load32_fail
    mov     eax, [rdi]
    er_ok
    er_ret
.load32_fail:
    xor     eax, eax
    er_err  1
    er_ret

; ==================================================================
; er_load64(in) → u64
; rdi=in, esi=len
; Little-endian load. rdx=0 on success, 1 on error.
; ==================================================================
er_fn er_load64
    cmp     esi, 8
    jb      .load64_fail
    mov     rax, [rdi]
    er_ok
    er_ret
.load64_fail:
    xor     eax, eax
    er_err  1
    er_ret

; ==================================================================
; er_loadbe16(in) → u16
; rdi=in, esi=len
; Big-endian load. rdx=0 on success, 1 on error.
; ==================================================================
er_fn er_loadbe16
    cmp     esi, 2
    jb      .loadbe16_fail
    movzx   eax, word [rdi]
    xchg    al, ah
    er_ok
    er_ret
.loadbe16_fail:
    xor     eax, eax
    er_err  1
    er_ret

; ==================================================================
; er_loadbe32(in) → u32
; rdi=in, esi=len
; Big-endian load. rdx=0 on success, 1 on error.
; ==================================================================
er_fn er_loadbe32
    cmp     esi, 4
    jb      .loadbe32_fail
    mov     eax, [rdi]
    bswap   eax
    er_ok
    er_ret
.loadbe32_fail:
    xor     eax, eax
    er_err  1
    er_ret

; ==================================================================
; er_loadbe64(in) → u64
; rdi=in, esi=len
; Big-endian load. rdx=0 on success, 1 on error.
; ==================================================================
er_fn er_loadbe64
    cmp     esi, 8
    jb      .loadbe64_fail
    mov     rax, [rdi]
    bswap   rax
    er_ok
    er_ret
.loadbe64_fail:
    xor     eax, eax
    er_err  1
    er_ret

; ==================================================================
; er_bytes_copy(dst, dst_len, src, src_len) → bool
; rdi=dst, esi=dst_len, rdx=src, ecx=src_len
; Copies src_len bytes from src to dst. Returns eax=1 if dst_len >= src_len.
; Returns eax=0 (rdx=1) if src_len > dst_len. rdx=0 on success.
; ==================================================================
er_fn er_bytes_copy
    cmp     ecx, esi
    ja      .copy_fail
    test    ecx, ecx
    jz      .copy_ok
    xor     r8d, r8d
.copy_loop:
    mov     al, [rdx + r8]
    mov     [rdi + r8], al
    inc     r8d
    cmp     r8d, ecx
    jb      .copy_loop
.copy_ok:
    mov     eax, 1
    er_ok
    er_ret
.copy_fail:
    xor     eax, eax
    er_err  1
    er_ret

; ==================================================================
; er_starts_with(haystack, hay_len, needle, needle_len) → bool
; rdi=haystack, esi=hay_len, rdx=needle, ecx=needle_len
; Returns eax=1 if haystack starts with needle, else 0. rdx=0.
; ==================================================================
er_fn er_starts_with
    cmp     ecx, esi
    ja      .sw_false
    test    ecx, ecx
    jz      .sw_true         ; empty needle always matches
    push    rcx
    xor     eax, eax
.sw_loop:
    mov     r8b, [rdi + rax]
    cmp     r8b, [rdx + rax]
    jne     .sw_false_pop
    inc     eax
    cmp     eax, ecx
    jb      .sw_loop
    pop     rcx
.sw_true:
    mov     eax, 1
    er_ok
    er_ret
.sw_false_pop:
    pop     rcx
.sw_false:
    xor     eax, eax
    er_ok
    er_ret

; ==================================================================
; er_ends_with(haystack, hay_len, needle, needle_len) → bool
; rdi=haystack, esi=hay_len, rdx=needle, ecx=needle_len
; Returns eax=1 if haystack ends with needle, else 0. rdx=0.
; ==================================================================
er_fn er_ends_with
    cmp     ecx, esi
    ja      .ew_false
    test    ecx, ecx
    jz      .ew_true
    mov     eax, esi
    sub     eax, ecx         ; offset = hay_len - needle_len
    add     rdi, rax         ; haystack now points to the end-start
    push    rcx
    xor     ecx, ecx
.ew_loop:
    mov     al, [rdi + rcx]
    cmp     al, [rdx + rcx]
    jne     .ew_false_pop
    inc     ecx
    cmp     ecx, [rsp]
    jb      .ew_loop
    pop     rcx
.ew_true:
    mov     eax, 1
    er_ok
    er_ret
.ew_false_pop:
    pop     rcx
.ew_false:
    xor     eax, eax
    er_ok
    er_ret

; ==================================================================
; er_index_of(haystack, hay_len, needle, needle_len) → ssize_t
; rdi=haystack, esi=hay_len, rdx=needle, ecx=needle_len
; Returns index in eax on success, -1 if not found. rdx=0.
; ==================================================================
er_fn er_index_of
    cmp     ecx, esi
    ja      .io_not_found
    test    ecx, ecx
    jz      .io_found_0
    push    rbx
    push    r12
    push    r13
    push    r14

    mov     r12, rdi            ; haystack
    mov     r13d, esi           ; hay_len
    mov     r14, rdx            ; needle
    mov     ebx, ecx            ; needle_len
    mov     r8d, esi
    sub     r8d, ecx            ; end = hay_len - needle_len
    xor     r9d, r9d            ; i = 0

.io_outer:
    cmp     r9d, r8d
    ja      .io_not_found2
    lea     r10, [r12 + r9]     ; haystack + i
    xor     ecx, ecx            ; j = 0
.io_inner:
    mov     al, [r10 + rcx]
    cmp     al, [r14 + rcx]
    jne     .io_next
    inc     ecx
    cmp     ecx, ebx
    jb      .io_inner
    ; Found at r9d
    mov     eax, r9d
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ok
    er_ret
.io_next:
    inc     r9d
    jmp     .io_outer

.io_found_0:
    xor     eax, eax
    er_ok
    er_ret
.io_not_found2:
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
.io_not_found:
    mov     eax, -1
    er_ok
    er_ret

; ==================================================================
; er_stored64(value) → writes 8 bytes to out
; rdi=out, esi=value
; Stores u64 as 8 LE bytes. No return value.
; ==================================================================
er_fn er_stored64
    mov     [rdi], rsi
    er_ret
