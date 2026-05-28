; EdgeRun freestanding memory and string runtime — x86_64 assembly
; System V AMD64 ABI: arg1=rdi, arg2=rsi, arg3=rdx, arg4=rcx, retval=rax
; All functions are freestanding — no libc, no external dependencies.

%include "x86_64/macros.inc"

SECTION .text

; ==================================================================
; er_memset — fill memory with a byte value
; void* er_memset(void* dst, int value, size_t num)
; Returns: dst
; ==================================================================
er_fn er_memset
    mov     r8, rdi             ; r8 = dst (save before clobbering)
    mov     rcx, rdx            ; rcx = count
    movzx   eax, sil            ; eax = value byte (zero-extended)

    cld
    rep     stosb               ; fill [rdi] with al, rcx times

    mov     rax, r8             ; return dst
    ret

; ==================================================================
; er_memcpy — copy memory buffer
; void* er_memcpy(void* dst, const void* src, size_t num)
; Returns: dst
; ==================================================================
er_fn er_memcpy
    ; Save return value (dst)
    mov     rax, rdi            ; retval = dst

    ; Use rep movsb for byte copy
    mov     rcx, rdx            ; rcx = num
    mov     rsi, rsi            ; rsi = src (already in rsi)
    mov     rdi, rax            ; rdi = dst
    cld
    rep     movsb

    ret

; ==================================================================
; er_memcmp — compare two memory buffers
; int er_memcmp(const void* ptr1, const void* ptr2, size_t num)
; Returns: 0 if equal, <0 if ptr1<ptr2, >0 if ptr1>ptr2
; ==================================================================
er_fn er_memcmp
    test    rdx, rdx
    jz      .equal

    mov     rcx, rdx
    cld
    repe    cmpsb

    movzx   eax, byte [rdi - 1]
    movzx   ecx, byte [rsi - 1]
    sub     eax, ecx
    ret

.equal:
    xor     eax, eax
    ret

; ==================================================================
; er_strlen — get length of null-terminated string
; size_t er_strlen(const char* str)
; ==================================================================
er_fn er_strlen
    push    rcx
    xor     eax, eax            ; length = 0

    ; Check for null pointer
    test    rdi, rdi
    jz      .done

    mov     rcx, -1             ; scan up to max
    cld
    repne   scasb               ; scan for null byte
    not     rcx                 ; rcx = -rcx - 1, but since we scanned -1 bytes...
    dec     rcx                 ; compensate for scasb incrementing past null
    mov     rax, rcx

.done:
    pop     rcx
    ret

; ==================================================================
; er_strcmp — compare two null-terminated strings
; int er_strcmp(const char* str1, const char* str2)
; Returns: 0 if equal, <0 if str1<str2, >0 if str1>str2
; ==================================================================
er_fn er_strcmp
    push    rcx

.loop:
    mov     al, byte [rdi]      ; load from str1
    mov     cl, byte [rsi]      ; load from str2
    cmp     al, cl
    jne     .diff               ; different byte found

    test    al, al              ; end of both strings?
    jz      .equal

    inc     rdi
    inc     rsi
    jmp     .loop

.diff:
    movzx   eax, al
    movzx   ecx, cl
    sub     eax, ecx
    pop     rcx
    ret

.equal:
    xor     eax, eax
    pop     rcx
    ret

; ==================================================================
; er_strcpy — copy null-terminated string
; char* er_strcpy(char* dst, const char* src)
; Returns: dst
; ==================================================================
er_fn er_strcpy
    push    rcx
    mov     rax, rdi            ; save dst as return value

.loop:
    mov     cl, byte [rsi]      ; load from src
    mov     byte [rdi], cl      ; store to dst
    test    cl, cl              ; null terminator?
    jz      .done
    inc     rdi
    inc     rsi
    jmp     .loop

.done:
    pop     rcx
    ret

; ==================================================================
; er_strcmp_prefix — check if str starts with prefix
; int er_strcmp_prefix(const char* str, const char* prefix)
; Returns: 0 if str starts with prefix, -1 if not
; ==================================================================
er_fn er_strcmp_prefix
    push    rcx

.loop:
    mov     al, byte [rsi]      ; load from prefix
    test    al, al              ; end of prefix?
    jz      .match

    mov     cl, byte [rdi]      ; load from str
    test    cl, cl              ; str ended before prefix?
    jz      .no_match

    cmp     al, cl
    jne     .no_match

    inc     rdi
    inc     rsi
    jmp     .loop

.match:
    xor     eax, eax
    pop     rcx
    ret

.no_match:
    or      eax, -1
    pop     rcx
    ret

; ==================================================================
; er_memmove — copy memory (handles overlapping buffers)
; void* er_memmove(void* dst, const void* src, size_t num)
; Returns: dst
; ==================================================================
er_fn er_memmove
    mov     rax, rdi            ; retval = dst

    ; If dst <= src, forward copy is safe
    cmp     rdi, rsi
    jbe     .forward

    ; If dst > src and dst < src+num, need backward copy
    lea     rcx, [rsi + rdx]    ; rcx = src + num
    cmp     rdi, rcx
    jae     .forward            ; dst >= src+num, no overlap

    ; Backward copy
    lea     rsi, [rsi + rdx - 1] ; src end
    lea     rdi, [rdi + rdx - 1] ; dst end
    mov     rcx, rdx
    std                         ; direction = backward
    rep     movsb
    cld                         ; restore forward direction
    ret

.forward:
    mov     rcx, rdx
    cld
    rep     movsb
    ret

; ==================================================================
; er_bss_zero — zero the BSS section
; void er_bss_zero(void* bss_start, void* bss_end)
; Called from _start before any C/asm code runs
; ==================================================================
er_fn er_bss_zero
    ; rdi = bss_start, rsi = bss_end
    mov     rcx, rsi
    sub     rcx, rdi            ; rcx = bss length
    jle     .done               ; nothing to zero

    xor     eax, eax
    cld
    ; Use 8-byte stores for speed
    mov     rdi, rdi
    shr     rcx, 3              ; rcx = count of qwords
    rep     stosq

.done:
    ret

; ==================================================================
; er_memchr — find first occurrence of byte in memory buffer
; void* er_memchr(const void* ptr, int value, size_t num)
; Returns: pointer to first occurrence, or NULL if not found
; ==================================================================
er_fn er_memchr
    test    rdx, rdx
    jz      .memchr_not_found
    mov     rcx, rdx
    mov     al, sil
    mov     rdi, rdi
    cld
    repne   scasb           ; scan for al in [rdi], rcx times
    jne     .memchr_not_found
    lea     rax, [rdi - 1]  ; scasb incremented past match
    er_ret
.memchr_not_found:
    xor     eax, eax
    er_ret

; ==================================================================
; er_memrchr — find last occurrence of byte in memory buffer (reverse)
; void* er_memrchr(const void* ptr, int value, size_t num)
; Returns: pointer to last occurrence, or NULL if not found
; ==================================================================
er_fn er_memrchr
    test    rdx, rdx
    jz      .memrchr_not_found
    mov     rcx, rdx
    lea     rdi, [rdi + rcx - 1]  ; start from last byte
    mov     al, sil
    std                         ; reverse direction
    repne   scasb               ; scan backward
    cld                         ; restore direction
    jne     .memrchr_not_found
    lea     rax, [rdi + 1]      ; scasb decremented past match
    er_ret
.memrchr_not_found:
    cld
    xor     eax, eax
    er_ret

; ==================================================================
; er_memset32 — fill memory with 32-bit value (4-byte aligned)
; void* er_memset32(void* dst, uint32_t value, size_t count)
; count is number of 32-bit elements, NOT bytes
; Returns: dst
; ==================================================================
er_fn er_memset32
    mov     r8, rdi             ; save dst
    mov     rcx, rdx            ; rcx = element count
    mov     eax, esi            ; eax = value
    cld
    rep     stosd               ; store eax, rcx times
    mov     rax, r8
    er_ret

; ==================================================================
; er_memset64 — fill memory with 64-bit value (8-byte aligned)
; void* er_memset64(void* dst, uint64_t value, size_t count)
; count is number of 64-bit elements, NOT bytes
; Returns: dst
; ==================================================================
er_fn er_memset64
    mov     r8, rdi             ; save dst
    mov     rcx, rdx            ; rcx = element count
    mov     rax, rsi            ; rax = value
    cld
    rep     stosq               ; store rax, rcx times
    mov     rax, r8
    er_ret

; ==================================================================
; er_strchr — find first occurrence of char in null-terminated string
; char* er_strchr(const char* str, int c)
; Returns: pointer to first occurrence, or NULL
; ==================================================================
er_fn er_strchr
    test    rdi, rdi
    jz      .strchr_null
    mov     al, sil
.strchr_loop:
    cmp     byte [rdi], al
    je      .strchr_found
    cmp     byte [rdi], 0
    je      .strchr_null
    inc     rdi
    jmp     .strchr_loop
.strchr_found:
    mov     rax, rdi
    er_ret
.strchr_null:
    xor     eax, eax
    er_ret

; ==================================================================
; er_strrchr — find last occurrence of char in null-terminated string
; char* er_strrchr(const char* str, int c)
; Returns: pointer to last occurrence, or NULL
; ==================================================================
er_fn er_strrchr
    test    rdi, rdi
    jz      .strrchr_null
    mov     al, sil
    xor     rcx, rcx
    xor     edx, edx            ; last_match = NULL
.strrchr_loop:
    cmp     byte [rdi + rcx], al
    jne     .strrchr_next
    lea     rdx, [rdi + rcx]    ; update last_match
.strrchr_next:
    cmp     byte [rdi + rcx], 0
    je      .strrchr_done
    inc     rcx
    jmp     .strrchr_loop
.strrchr_done:
    mov     rax, rdx
    er_ret
.strrchr_null:
    xor     eax, eax
    er_ret

; ==================================================================
; er_strncpy — bounded string copy (standard strncpy semantics)
; char* er_strncpy(char* dst, const char* src, size_t n)
; Copies at most n chars from src to dst. If src < n, null-pads remainder.
; If src >= n, dst is NOT null-terminated.
; Returns: dst
; ==================================================================
er_fn er_strncpy
    mov     r8, rdi             ; save dst
    test    rdx, rdx
    jz      .strncpy_done
    xor     r9d, r9d            ; index = 0
.strncpy_copy:
    cmp     r9, rdx
    jae     .strncpy_done
    mov     al, byte [rsi + r9]
    mov     byte [rdi + r9], al
    test    al, al
    jz      .strncpy_pad
    inc     r9
    jmp     .strncpy_copy
.strncpy_pad:
    cmp     r9, rdx
    jae     .strncpy_done
    mov     byte [rdi + r9], 0
    inc     r9
    jmp     .strncpy_pad
.strncpy_done:
    mov     rax, r8
    er_ret

; ==================================================================
; er_strncat — bounded string concatenation
; char* er_strncat(char* dst, const char* src, size_t n)
; Appends at most n chars from src to dst. Always null-terminates.
; Returns: dst
; ==================================================================
er_fn er_strncat
    mov     r8, rdi             ; save dst
    xor     r9d, r9d            ; offset within dst
    ; Find end of dst
.strncat_find_end:
    cmp     byte [rdi + r9], 0
    je      .strncat_copy
    inc     r9
    jmp     .strncat_find_end
.strncat_copy:
    xor     r10d, r10d          ; src index = 0
.strncat_loop:
    cmp     r10, rdx
    jae     .strncat_terminate
    mov     al, byte [rsi + r10]
    mov     byte [rdi + r9], al
    test    al, al
    jz      .strncat_done
    inc     r9
    inc     r10
    jmp     .strncat_loop
.strncat_terminate:
    mov     byte [rdi + r9], 0
.strncat_done:
    mov     rax, r8
    er_ret

; ==================================================================
; er_strncmp — bounded string compare
; int er_strncmp(const char* s1, const char* s2, size_t n)
; Compares at most n chars. Returns: 0 if equal, <0 if s1<s2, >0 if s1>s2
; ==================================================================
er_fn er_strncmp
    test    rdx, rdx
    jz      .strncmp_equal
    xor     r8d, r8d            ; index = 0
.strncmp_loop:
    cmp     r8, rdx
    jae     .strncmp_equal
    mov     al, byte [rdi + r8]
    mov     cl, byte [rsi + r8]
    cmp     al, cl
    jne     .strncmp_diff
    test    al, al
    jz      .strncmp_equal
    inc     r8
    jmp     .strncmp_loop
.strncmp_diff:
    movzx   eax, al
    movzx   ecx, cl
    sub     eax, ecx
    er_ret
.strncmp_equal:
    xor     eax, eax
    er_ret

; ==================================================================
; er_strcasecmp — case-insensitive string compare
; int er_strcasecmp(const char* s1, const char* s2)
; Both strings compared after folding each char to lowercase.
; Returns: 0 if equal, <0 if s1<s2, >0 if s1>s2
; ==================================================================
er_fn er_strcasecmp
.strcasecmp_loop:
    mov     al, byte [rdi]
    mov     cl, byte [rsi]
    ; Fold al to lowercase
    cmp     al, 'A'
    jb      .strcasecmp_check_cl
    cmp     al, 'Z'
    ja      .strcasecmp_check_cl
    add     al, 32
.strcasecmp_check_cl:
    cmp     cl, 'A'
    jb      .strcasecmp_after_fold
    cmp     cl, 'Z'
    ja      .strcasecmp_after_fold
    add     cl, 32
.strcasecmp_after_fold:
    cmp     al, cl
    jne     .strcasecmp_diff
    test    al, al
    jz      .strcasecmp_equal
    inc     rdi
    inc     rsi
    jmp     .strcasecmp_loop
.strcasecmp_diff:
    movzx   eax, al
    movzx   ecx, cl
    sub     eax, ecx
    er_ret
.strcasecmp_equal:
    xor     eax, eax
    er_ret

; ==================================================================
; er_strstr — find substring (naive scan)
; char* er_strstr(const char* haystack, const char* needle)
; Returns: pointer to start of first occurrence, or NULL
; ==================================================================
er_fn er_strstr
    test    rsi, rsi
    jz      .strstr_null
    test    rdi, rdi
    jz      .strstr_null
    ; If needle is empty, return haystack
    cmp     byte [rsi], 0
    je      .strstr_haystack
.strstr_outer:
    mov     al, byte [rdi]
    test    al, al
    jz      .strstr_null
    ; Try to match needle at current position
    mov     r8, rdi
    mov     r9, rsi
.strstr_inner:
    mov     al, byte [r9]
    test    al, al
    jz      .strstr_found         ; reached end of needle → match
    cmp     al, byte [r8]
    jne     .strstr_next
    inc     r8
    inc     r9
    jmp     .strstr_inner
.strstr_next:
    inc     rdi
    jmp     .strstr_outer
.strstr_found:
    mov     rax, rdi
    er_ret
.strstr_haystack:
    mov     rax, rdi
    er_ret
.strstr_null:
    xor     eax, eax
    er_ret

; ==================================================================
; er_strtou64 — parse decimal string to uint64
; uint64_t er_strtou64(const char* str, char** endptr)
; Skips whitespace. Handles optional +/-. Sets endptr if non-NULL.
; Returns parsed value, or 0 on parse failure.
; ==================================================================
er_fn er_strtou64
    push    rbx
    push    r12
    push    r13
    mov     r12, rdi            ; str
    mov     r13, rsi            ; endptr
    xor     r10d, r10d          ; sign = 0 (positive)
    xor     r9d, r9d            ; accumulator = 0
    xor     r11d, r11d          ; overflow flag
    ; Skip whitespace
.strtou64_skip:
    movzx   eax, byte [r12]
    cmp     al, ' '
    je      .strtou64_skip_inc
    cmp     al, 9
    je      .strtou64_skip_inc
    cmp     al, 10
    je      .strtou64_skip_inc
    cmp     al, 13
    je      .strtou64_skip_inc
    jmp     .strtou64_sign
.strtou64_skip_inc:
    inc     r12
    jmp     .strtou64_skip
.strtou64_sign:
    movzx   eax, byte [r12]
    cmp     al, '+'
    je      .strtou64_sign_plus
    cmp     al, '-'
    je      .strtou64_sign_minus
    jmp     .strtou64_parse
.strtou64_sign_plus:
    inc     r12
    jmp     .strtou64_parse
.strtou64_sign_minus:
    mov     r10b, 1             ; sign = 1 (negative)
    inc     r12
.strtou64_parse:
    movzx   eax, byte [r12]
    cmp     al, '0'
    jb      .strtou64_done
    cmp     al, '9'
    ja      .strtou64_done
    sub     al, '0'
    movzx   ecx, al             ; ecx = digit value
    test    r11, r11
    jnz     .strtou64_consume   ; already overflowed
    mov     rax, r9
    mov     rbx, 10
    mul     rbx                 ; rdx:rax = accum * 10
    test    rdx, rdx
    jnz     .strtou64_overflow
    add     rax, rcx
    jc      .strtou64_overflow
    mov     r9, rax
    inc     r12
    jmp     .strtou64_parse
.strtou64_overflow:
    mov     r11, 1
.strtou64_consume:
    inc     r12
    jmp     .strtou64_parse
.strtou64_done:
    test    r13, r13
    jz      .strtou64_ret
    mov     [r13], r12          ; *endptr = current str position
.strtou64_ret:
    test    r10, r10            ; negative sign?
    jz      .strtou64_return_accum
    neg     r9                  ; negate
.strtou64_return_accum:
    test    r11, r11
    jz      .strtou64_no_overflow
    mov     r9, -1              ; UINT64_MAX on overflow
.strtou64_no_overflow:
    mov     rax, r9
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; ==================================================================
; er_strtoi64 — parse decimal string to int64
; int64_t er_strtoi64(const char* str, char** endptr)
; Skips whitespace. Handles sign. Sets endptr if non-NULL.
; Returns parsed value, clamped to INT64_MIN/INT64_MAX on overflow.
; ==================================================================
er_fn er_strtoi64
    push    rbx
    push    r12
    push    r13
    mov     r12, rdi            ; str
    mov     r13, rsi            ; endptr
    xor     r10d, r10d          ; sign = 0 (positive)
    xor     r9d, r9d            ; accumulator = 0
    xor     r11d, r11d          ; overflow flag
    ; Skip whitespace
.strtoi64_skip:
    movzx   eax, byte [r12]
    cmp     al, ' '
    je      .strtoi64_skip_inc
    cmp     al, 9
    je      .strtoi64_skip_inc
    cmp     al, 10
    je      .strtoi64_skip_inc
    cmp     al, 13
    je      .strtoi64_skip_inc
    jmp     .strtoi64_sign
.strtoi64_skip_inc:
    inc     r12
    jmp     .strtoi64_skip
.strtoi64_sign:
    movzx   eax, byte [r12]
    cmp     al, '+'
    je      .strtoi64_sign_plus
    cmp     al, '-'
    je      .strtoi64_sign_minus
    jmp     .strtoi64_parse
.strtoi64_sign_plus:
    inc     r12
    jmp     .strtoi64_parse
.strtoi64_sign_minus:
    mov     r10b, 1
    inc     r12
.strtoi64_parse:
    movzx   eax, byte [r12]
    cmp     al, '0'
    jb      .strtoi64_done
    cmp     al, '9'
    ja      .strtoi64_done
    sub     al, '0'
    movzx   ecx, al
    test    r11, r11
    jnz     .strtoi64_consume
    mov     rax, r9
    mov     rbx, 10
    mul     rbx
    test    rdx, rdx
    jnz     .strtoi64_overflow
    add     rax, rcx
    jc      .strtoi64_overflow
    mov     r9, rax
    inc     r12
    jmp     .strtoi64_parse
.strtoi64_overflow:
    mov     r11, 1
.strtoi64_consume:
    inc     r12
    jmp     .strtoi64_parse
.strtoi64_done:
    test    r13, r13
    jz      .strtoi64_ret
    mov     [r13], r12
.strtoi64_ret:
    test    r11, r11
    jnz     .strtoi64_clamp
    test    r10, r10
    jz      .strtoi64_pos
    ; Check if accum > INT64_MAX (would overflow when negated)
    mov     rax, r9
    mov     rbx, 0x7fffffffffffffff
    cmp     rax, rbx
    ja      .strtoi64_neg_overflow
    neg     r9
    jmp     .strtoi64_pos
.strtoi64_neg_overflow:
    mov     r9, 0x8000000000000000  ; INT64_MIN
    jmp     .strtoi64_pos
.strtoi64_clamp:
    test    r10, r10
    jnz     .strtoi64_clamp_neg
    mov     r9, 0x7fffffffffffffff  ; INT64_MAX
    jmp     .strtoi64_pos
.strtoi64_clamp_neg:
    mov     r9, 0x8000000000000000  ; INT64_MIN
.strtoi64_pos:
    mov     rax, r9
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; ==================================================================
; er_strtou64_hex — parse hex string to uint64
; uint64_t er_strtou64_hex(const char* str, char** endptr)
; Skips optional "0x" or "0X" prefix. Sets endptr if non-NULL.
; ==================================================================
er_fn er_strtou64_hex
    push    rbx
    push    r12
    push    r13
    mov     r12, rdi
    mov     r13, rsi
    xor     r9d, r9d            ; accumulator = 0
    xor     r11d, r11d          ; overflow flag
    ; Skip leading whitespace
.strtou64_hex_skip:
    movzx   eax, byte [r12]
    cmp     al, ' '
    je      .strtou64_hex_skip_inc
    cmp     al, 9
    je      .strtou64_hex_skip_inc
    cmp     al, 10
    je      .strtou64_hex_skip_inc
    cmp     al, 13
    je      .strtou64_hex_skip_inc
    jmp     .strtou64_hex_prefix
.strtou64_hex_skip_inc:
    inc     r12
    jmp     .strtou64_hex_skip
.strtou64_hex_prefix:
    movzx   eax, byte [r12]
    cmp     al, '0'
    jne     .strtou64_hex_parse
    movzx   eax, byte [r12 + 1]
    cmp     al, 'x'
    je      .strtou64_hex_skip2
    cmp     al, 'X'
    jne     .strtou64_hex_parse
.strtou64_hex_skip2:
    add     r12, 2
.strtou64_hex_parse:
    movzx   eax, byte [r12]
    cmp     al, '0'
    jb      .strtou64_hex_done
    cmp     al, '9'
    ja      .strtou64_hex_alpha_upper
    sub     al, '0'
    jmp     .strtou64_hex_digit
.strtou64_hex_alpha_upper:
    cmp     al, 'A'
    jb      .strtou64_hex_done
    cmp     al, 'F'
    ja      .strtou64_hex_alpha_lower
    sub     al, 'A' - 10
    jmp     .strtou64_hex_digit
.strtou64_hex_alpha_lower:
    cmp     al, 'a'
    jb      .strtou64_hex_done
    cmp     al, 'f'
    ja      .strtou64_hex_done
    sub     al, 'a' - 10
.strtou64_hex_digit:
    movzx   ecx, al
    test    r11, r11
    jnz     .strtou64_hex_consume
    mov     rax, r9
    mov     rbx, 16
    mul     rbx
    test    rdx, rdx
    jnz     .strtou64_hex_overflow
    add     rax, rcx
    jc      .strtou64_hex_overflow
    mov     r9, rax
    inc     r12
    jmp     .strtou64_hex_parse
.strtou64_hex_overflow:
    mov     r11, 1
.strtou64_hex_consume:
    inc     r12
    jmp     .strtou64_hex_parse
.strtou64_hex_done:
    test    r13, r13
    jz      .strtou64_hex_ret
    mov     [r13], r12
.strtou64_hex_ret:
    test    r11, r11
    jz      .strtou64_hex_no_overflow
    mov     r9, -1
.strtou64_hex_no_overflow:
    mov     rax, r9
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; ==================================================================
; er_strspn — get length of initial segment of str consisting of
;             characters from accept
; size_t er_strspn(const char* str, const char* accept)
; ==================================================================
er_fn er_strspn
    xor     r8d, r8d            ; count = 0
.strspn_outer:
    movzx   eax, byte [rdi + r8]
    test    al, al
    jz      .strspn_done
    ; Check if current char is in accept
    mov     rcx, rsi
.strspn_inner:
    movzx   edx, byte [rcx]
    test    dl, dl
    jz      .strspn_done       ; reached end of accept → char not found
    cmp     al, dl
    je      .strspn_found
    inc     rcx
    jmp     .strspn_inner
.strspn_found:
    inc     r8
    jmp     .strspn_outer
.strspn_done:
    mov     rax, r8
    er_ret

; ==================================================================
; er_strcspn — get length of initial segment of str consisting of
;              characters NOT from reject
; size_t er_strcspn(const char* str, const char* reject)
; ==================================================================
er_fn er_strcspn
    xor     r8d, r8d            ; count = 0
.strcspn_outer:
    movzx   eax, byte [rdi + r8]
    test    al, al
    jz      .strcspn_done
    ; Check if current char is in reject
    mov     rcx, rsi
.strcspn_inner:
    movzx   edx, byte [rcx]
    test    dl, dl
    jz      .strcspn_found     ; end of reject → char not rejected
    cmp     al, dl
    je      .strcspn_done      ; char matches reject → stop
    inc     rcx
    jmp     .strcspn_inner
.strcspn_found:
    inc     r8
    jmp     .strcspn_outer
.strcspn_done:
    mov     rax, r8
    er_ret

; ==================================================================
; er_strpbrk — find first char in str that matches any char in accept
; char* er_strpbrk(const char* str, const char* accept)
; Returns: pointer to first matching char, or NULL
; ==================================================================
er_fn er_strpbrk
    xor     r8d, r8d
.strpbrk_outer:
    movzx   eax, byte [rdi + r8]
    test    al, al
    jz      .strpbrk_null
    mov     rcx, rsi
.strpbrk_inner:
    movzx   edx, byte [rcx]
    test    dl, dl
    jz      .strpbrk_next
    cmp     al, dl
    je      .strpbrk_found
    inc     rcx
    jmp     .strpbrk_inner
.strpbrk_next:
    inc     r8
    jmp     .strpbrk_outer
.strpbrk_found:
    lea     rax, [rdi + r8]
    er_ret
.strpbrk_null:
    xor     eax, eax
    er_ret

; ==================================================================
; er_memccpy — copy memory until stop_char found or limit reached
; void* er_memccpy(void* dst, const void* src, int stop_char, size_t n)
; Returns: pointer to byte AFTER stop_char in dst, or NULL if not found
; ==================================================================
er_fn er_memccpy
    mov     r8, rdi             ; save dst
    mov     r9, rsi             ; save src
    mov     al, dl              ; stop_char
.memccpy_loop:
    test    rcx, rcx
    jz      .memccpy_null
    mov     dl, byte [r9]
    mov     byte [r8], dl
    inc     r8
    inc     r9
    dec     rcx
    cmp     dl, al
    jne     .memccpy_loop
    lea     rax, [r8]
    er_ret
.memccpy_null:
    xor     eax, eax
    er_ret

; ==================================================================
; er_memicmp — case-insensitive memory compare
; int er_memicmp(const void* ptr1, const void* ptr2, size_t n)
; Folds A-Z to lowercase before comparing.
; Returns: 0 if equal, <0 if ptr1<ptr2, >0 if ptr1>ptr2
; ==================================================================
er_fn er_memicmp
    test    rdx, rdx
    jz      .memicmp_equal
    xor     r8d, r8d            ; index
.memicmp_loop:
    cmp     r8, rdx
    jae     .memicmp_equal
    mov     al, byte [rdi + r8]
    mov     cl, byte [rsi + r8]
    ; Fold al to lowercase
    cmp     al, 'A'
    jb      .memicmp_fold_cl
    cmp     al, 'Z'
    ja      .memicmp_fold_cl
    add     al, 32
.memicmp_fold_cl:
    cmp     cl, 'A'
    jb      .memicmp_compare
    cmp     cl, 'Z'
    ja      .memicmp_compare
    add     cl, 32
.memicmp_compare:
    cmp     al, cl
    jne     .memicmp_diff
    inc     r8
    jmp     .memicmp_loop
.memicmp_diff:
    movzx   eax, al
    movzx   ecx, cl
    sub     eax, ecx
    er_ret
.memicmp_equal:
    xor     eax, eax
    er_ret

; ==================================================================
; er_memswap — swap two equal-length memory buffers
; void er_memswap(void* ptr1, void* ptr2, size_t n)
; Swaps in 8-byte chunks, then byte-by-byte remainder.
; ==================================================================
er_fn er_memswap
    test    rdx, rdx
    jz      .memswap_done
    mov     rcx, rdx
    shr     rcx, 3              ; qword count
.memswap_8_loop:
    test    rcx, rcx
    jz      .memswap_remain
    mov     r8, [rdi]
    mov     r9, [rsi]
    mov     [rdi], r9
    mov     [rsi], r8
    add     rdi, 8
    add     rsi, 8
    dec     rcx
    jmp     .memswap_8_loop
.memswap_remain:
    mov     rcx, rdx
    and     rcx, 7              ; remaining bytes
.memswap_1_loop:
    test    rcx, rcx
    jz      .memswap_done
    mov     al, byte [rdi + rcx - 1]
    mov     r10b, byte [rsi + rcx - 1]
    mov     byte [rsi + rcx - 1], al
    mov     byte [rdi + rcx - 1], r10b
    dec     rcx
    jmp     .memswap_1_loop
.memswap_done:
    er_ret

; ==================================================================
; er_hex_encode — encode bytes to lowercase hex string
; void er_hex_encode(const void* data, size_t len, char* out)
; out must have space for len*2 characters (no null terminator added)
; ==================================================================
er_fn er_hex_encode
    test    rsi, rsi
    jz      .hexenc_done
    xor     r8d, r8d            ; index
.hexenc_loop:
    cmp     r8, rsi
    jae     .hexenc_done
    movzx   eax, byte [rdi + r8]
    mov     ecx, eax
    shr     al, 4               ; high nibble
    and     cl, 0x0f            ; low nibble
    ; Convert high nibble
    cmp     al, 10
    jb      .hexenc_hi_digit
    add     al, 'a' - 10
    jmp     .hexenc_store_hi
.hexenc_hi_digit:
    add     al, '0'
.hexenc_store_hi:
    mov     byte [rdx + r8*2], al
    ; Convert low nibble
    mov     al, cl
    cmp     al, 10
    jb      .hexenc_lo_digit
    add     al, 'a' - 10
    jmp     .hexenc_store_lo
.hexenc_lo_digit:
    add     al, '0'
.hexenc_store_lo:
    mov     byte [rdx + r8*2 + 1], al
    inc     r8
    jmp     .hexenc_loop
.hexenc_done:
    er_ret

; ==================================================================
; er_hex_decode — decode hex string to bytes
; size_t er_hex_decode(const char* hex, size_t len, void* out)
; Returns number of bytes written, or 0 on invalid hex or odd length.
; ==================================================================
er_fn er_hex_decode
    test    rsi, rsi
    jz      .hexdec_done_zero
    test    sil, 1              ; odd length → error
    jnz     .hexdec_done_zero
    xor     r8d, r8d            ; hex index
    xor     r9d, r9d            ; out index
.hexdec_loop:
    cmp     r8, rsi
    jae     .hexdec_done
    ; Parse high nibble
    movzx   eax, byte [rdi + r8]
    call    .hexdec_nibble
    jc      .hexdec_done_zero
    shl     al, 4
    mov     cl, al
    ; Parse low nibble
    movzx   eax, byte [rdi + r8 + 1]
    call    .hexdec_nibble
    jc      .hexdec_done_zero
    or      cl, al
    mov     byte [rdx + r9], cl
    add     r8, 2
    inc     r9
    jmp     .hexdec_loop
.hexdec_done:
    mov     rax, r9
    er_ret
.hexdec_done_zero:
    xor     eax, eax
    er_ret
; Helper: convert hex char to 4-bit value, CF=1 on invalid
.hexdec_nibble:
    cmp     al, '0'
    jb      .nibble_invalid
    cmp     al, '9'
    ja      .nibble_upper
    sub     al, '0'
    clc
    ret
.nibble_upper:
    cmp     al, 'A'
    jb      .nibble_invalid
    cmp     al, 'F'
    ja      .nibble_lower
    sub     al, 'A' - 10
    clc
    ret
.nibble_lower:
    cmp     al, 'a'
    jb      .nibble_invalid
    cmp     al, 'f'
    ja      .nibble_invalid
    sub     al, 'a' - 10
    clc
    ret
.nibble_invalid:
    stc
    ret

; ==================================================================
; er_utf8_encode — encode Unicode codepoint to UTF-8 bytes
; int er_utf8_encode(uint32_t codepoint, char* out)
; Returns number of bytes written (1-4), or 0 on invalid codepoint
; ==================================================================
er_fn er_utf8_encode
    cmp     edi, 0x7F
    jbe     .utf8enc_1byte
    cmp     edi, 0x7FF
    jbe     .utf8enc_2byte
    cmp     edi, 0xFFFF
    jbe     .utf8enc_3byte
    cmp     edi, 0x10FFFF
    ja      .utf8enc_invalid
    ; 4-byte: 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
    mov     eax, edi
    shr     eax, 18
    and     eax, 0x07
    or      eax, 0xF0
    mov     byte [rsi], al
    mov     eax, edi
    shr     eax, 12
    and     eax, 0x3F
    or      eax, 0x80
    mov     byte [rsi + 1], al
    mov     eax, edi
    shr     eax, 6
    and     eax, 0x3F
    or      eax, 0x80
    mov     byte [rsi + 2], al
    mov     eax, edi
    and     eax, 0x3F
    or      eax, 0x80
    mov     byte [rsi + 3], al
    mov     eax, 4
    er_ret
.utf8enc_3byte:
    ; 3-byte: 1110xxxx 10xxxxxx 10xxxxxx
    mov     eax, edi
    shr     eax, 12
    and     eax, 0x0F
    or      eax, 0xE0
    mov     byte [rsi], al
    mov     eax, edi
    shr     eax, 6
    and     eax, 0x3F
    or      eax, 0x80
    mov     byte [rsi + 1], al
    mov     eax, edi
    and     eax, 0x3F
    or      eax, 0x80
    mov     byte [rsi + 2], al
    mov     eax, 3
    er_ret
.utf8enc_2byte:
    ; 2-byte: 110xxxxx 10xxxxxx
    mov     eax, edi
    shr     eax, 6
    and     eax, 0x1F
    or      eax, 0xC0
    mov     byte [rsi], al
    mov     eax, edi
    and     eax, 0x3F
    or      eax, 0x80
    mov     byte [rsi + 1], al
    mov     eax, 2
    er_ret
.utf8enc_1byte:
    mov     byte [rsi], dil
    mov     eax, 1
    er_ret
.utf8enc_invalid:
    xor     eax, eax
    er_ret

; ==================================================================
; er_utf8_decode — decode single UTF-8 codepoint from bytes
; uint32_t er_utf8_decode(const char* str, size_t* len)
; Returns codepoint, sets *len to bytes consumed.
; Returns 0 and sets *len to 0 on invalid encoding.
; ==================================================================
er_fn er_utf8_decode
    movzx   eax, byte [rdi]
    test    al, al
    jz      .utf8dec_invalid
    ; Leading byte pattern determines sequence length
    test    al, 0x80
    jz      .utf8dec_1byte
    test    al, 0x20
    jz      .utf8dec_2byte
    test    al, 0x10
    jz      .utf8dec_3byte
    test    al, 0x08
    jnz     .utf8dec_invalid    ; 0b11111xxx is invalid
    ; 4-byte: 11110xxx
    mov     ecx, 4
    and     eax, 0x07
    jmp     .utf8dec_continue
.utf8dec_3byte:
    mov     ecx, 3
    and     eax, 0x0F
    jmp     .utf8dec_continue
.utf8dec_2byte:
    mov     ecx, 2
    and     eax, 0x1F
    jmp     .utf8dec_continue
.utf8dec_1byte:
    mov     ecx, 1
    and     eax, 0x7F
    jmp     .utf8dec_store_len
.utf8dec_continue:
    ; Process continuation bytes (10xxxxxx)
    mov     r8d, 1
.utf8dec_cont_loop:
    cmp     r8, rcx
    jae     .utf8dec_store_len
    movzx   edx, byte [rdi + r8]
    test    dl, 0x80
    jz      .utf8dec_invalid
    test    dl, 0x40
    jnz     .utf8dec_invalid    ; not a continuation byte
    shl     eax, 6
    and     edx, 0x3F
    or      eax, edx
    inc     r8
    jmp     .utf8dec_cont_loop
.utf8dec_store_len:
    test    rsi, rsi
    jz      .utf8dec_ret
    mov     [rsi], rcx          ; *len = bytes consumed
.utf8dec_ret:
    er_ret
.utf8dec_invalid:
    xor     eax, eax
    test    rsi, rsi
    jz      .utf8dec_ret
    mov     qword [rsi], 0
    er_ret

; ==================================================================
; er_strtok — tokenize string by delimiters (reentrant state)
; Standard strtok semantics with internal static state
; char* er_strtok(char* str, const char* delim)
; First call with non-NULL str initializes; subsequent calls with NULL
; ==================================================================

SECTION .bss
_strtok_save: resq 1

SECTION .text
er_fn er_strtok
    test    rdi, rdi
    jz      .strtok_continue
    mov     [rel _strtok_save], rdi
.strtok_continue:
    mov     rdi, [rel _strtok_save]
    test    rdi, rdi
    jz      .strtok_null        ; no saved state
    ; Skip leading delimiters
.strtok_skip:
    movzx   eax, byte [rdi]
    test    al, al
    jz      .strtok_null        ; end of string
    ; Check if current char is a delimiter
    mov     rsi, rsi            ; keep delim pointer (already in rsi from arg2)
    mov     rcx, rsi
.strtok_delim_check:
    movzx   edx, byte [rcx]
    test    dl, dl
    jz      .strtok_token_start ; not a delimiter
    cmp     al, dl
    je      .strtok_skip_char
    inc     rcx
    jmp     .strtok_delim_check
.strtok_skip_char:
    inc     rdi
    jmp     .strtok_skip
.strtok_token_start:
    mov     r8, rdi             ; save token start
.strtok_find_end:
    movzx   eax, byte [rdi]
    test    al, al
    jz      .strtok_end         ; end of string
    mov     rcx, rsi
.strtok_end_check:
    movzx   edx, byte [rcx]
    test    dl, dl
    jz      .strtok_next_char
    cmp     al, dl
    je      .strtok_terminate
    inc     rcx
    jmp     .strtok_end_check
.strtok_next_char:
    inc     rdi
    jmp     .strtok_find_end
.strtok_terminate:
    mov     byte [rdi], 0       ; null-terminate token
    inc     rdi
    mov     [rel _strtok_save], rdi
    mov     rax, r8
    er_ret
.strtok_end:
    mov     [rel _strtok_save], rdi
    mov     rax, r8
    er_ret
.strtok_null:
    xor     eax, eax
    er_ret

; ==================================================================
; er_digit_from_char — convert ASCII digit character to value (0-35)
; Internal helper used by strtou64_base and strtoi64_base
; Input: al = character, Output: al = digit value (0-35), CF=0
; On invalid: CF=1
; ==================================================================
er_digit_from_char:
    cmp     al, '0'
    jb      .dfc_invalid
    cmp     al, '9'
    ja      .dfc_upper
    sub     al, '0'
    clc
    ret
.dfc_upper:
    cmp     al, 'A'
    jb      .dfc_invalid
    cmp     al, 'Z'
    ja      .dfc_lower
    sub     al, 'A' - 10
    clc
    ret
.dfc_lower:
    cmp     al, 'a'
    jb      .dfc_invalid
    cmp     al, 'z'
    ja      .dfc_invalid
    sub     al, 'a' - 10
    clc
    ret
.dfc_invalid:
    stc
    ret

; ==================================================================
; er_strtou64_base — parse string to uint64 with configurable base (2-36)
; uint64_t er_strtou64_base(const char* str, char** endptr, int base)
; Skips whitespace, handles +/- sign. Returns 0 on parse failure.
; Overflow returns UINT64_MAX.
; ==================================================================
er_fn er_strtou64_base
    push    rbx
    push    r12
    push    r13
    mov     r12, rdi
    mov     r13, rsi
    mov     ebx, edx            ; base
    xor     r10d, r10d          ; sign
    xor     r9d, r9d            ; accum
    xor     r11d, r11d          ; overflow
    ; Validate base
    cmp     ebx, 2
    jl      .stoub_set_endptr
    cmp     ebx, 36
    jg      .stoub_set_endptr
    ; Skip whitespace
.stoub_skip:
    movzx   eax, byte [r12]
    cmp     al, ' '
    je      .stoub_skip_inc
    cmp     al, 9
    je      .stoub_skip_inc
    cmp     al, 10
    je      .stoub_skip_inc
    cmp     al, 13
    je      .stoub_skip_inc
    jmp     .stoub_sign
.stoub_skip_inc:
    inc     r12
    jmp     .stoub_skip
.stoub_sign:
    movzx   eax, byte [r12]
    cmp     al, '+'
    je      .stoub_sign_plus
    cmp     al, '-'
    jne     .stoub_parse
    mov     r10b, 1
    inc     r12
    jmp     .stoub_parse
.stoub_sign_plus:
    inc     r12
.stoub_parse:
    movzx   eax, byte [r12]
    call    er_digit_from_char
    jc      .stoub_done
    cmp     al, bl              ; digit >= base?
    jae     .stoub_done
    movzx   ecx, al
    test    r11, r11
    jnz     .stoub_consume
    ; Check overflow: accum > (UINT64_MAX - digit) / base
    mov     rax, -1
    sub     rax, rcx
    xor     edx, edx
    div     rbx
    cmp     r9, rax
    ja      .stoub_overflow
    mov     rax, r9
    mul     rbx
    add     rax, rcx
    mov     r9, rax
    inc     r12
    jmp     .stoub_parse
.stoub_overflow:
    mov     r11, 1
.stoub_consume:
    inc     r12
    jmp     .stoub_parse
.stoub_done:
    test    r13, r13
    jz      .stoub_ret
    mov     [r13], r12
.stoub_ret:
    test    r10, r10
    jz      .stoub_no_neg
    neg     r9
.stoub_no_neg:
    test    r11, r11
    jz      .stoub_no_of
    mov     r9, -1
.stoub_no_of:
    mov     rax, r9
    pop     r13
    pop     r12
    pop     rbx
    er_ret
.stoub_set_endptr:
    test    r13, r13
    jz      .stoub_ret_zero
    mov     [r13], r12
.stoub_ret_zero:
    xor     eax, eax
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; ==================================================================
; er_strtoi64_base — parse string to int64 with configurable base (2-36)
; int64_t er_strtoi64_base(const char* str, char** endptr, int base)
; Skips whitespace, handles sign. Returns INT64_MIN/MAX on overflow.
; ==================================================================
er_fn er_strtoi64_base
    push    rbx
    push    r12
    push    r13
    mov     r12, rdi
    mov     r13, rsi
    mov     ebx, edx
    xor     r10d, r10d          ; sign
    xor     r9d, r9d            ; accum
    xor     r11d, r11d          ; overflow
    cmp     ebx, 2
    jl      .stoib_set_endptr
    cmp     ebx, 36
    jg      .stoib_set_endptr
.stoib_skip:
    movzx   eax, byte [r12]
    cmp     al, ' '
    je      .stoib_skip_inc
    cmp     al, 9
    je      .stoib_skip_inc
    cmp     al, 10
    je      .stoib_skip_inc
    cmp     al, 13
    je      .stoib_skip_inc
    jmp     .stoib_sign
.stoib_skip_inc:
    inc     r12
    jmp     .stoib_skip
.stoib_sign:
    movzx   eax, byte [r12]
    cmp     al, '+'
    je      .stoib_sign_plus
    cmp     al, '-'
    jne     .stoib_parse
    mov     r10b, 1
    inc     r12
    jmp     .stoib_parse
.stoib_sign_plus:
    inc     r12
.stoib_parse:
    movzx   eax, byte [r12]
    call    er_digit_from_char
    jc      .stoib_done
    cmp     al, bl
    jae     .stoib_done
    movzx   ecx, al
    test    r11, r11
    jnz     .stoib_consume
    ; For signed, check overflow against INT64_MAX range
    ; accum > (INT64_MAX - digit) / base  → overflow for positive
    ; For negative, we allow up to INT64_MIN
    mov     rax, 0x7fffffffffffffff
    sub     rax, rcx
    xor     edx, edx
    div     rbx
    cmp     r9, rax
    ja      .stoib_overflow
    mov     rax, r9
    mul     rbx
    add     rax, rcx
    mov     r9, rax
    inc     r12
    jmp     .stoib_parse
.stoib_overflow:
    mov     r11, 1
.stoib_consume:
    inc     r12
    jmp     .stoib_parse
.stoib_done:
    test    r13, r13
    jz      .stoib_ret
    mov     [r13], r12
.stoib_ret:
    test    r11, r11
    jnz     .stoib_clamp
    test    r10, r10
    jz      .stoib_pos
    ; Check if accum > INT64_MAX (overflow for negative)
    mov     rax, r9
    mov     rbx, 0x7fffffffffffffff
    cmp     rax, rbx
    ja      .stoib_neg_overflow
    neg     r9
    jmp     .stoib_pos
.stoib_neg_overflow:
    mov     r9, 0x8000000000000000  ; INT64_MIN
    jmp     .stoib_pos
.stoib_clamp:
    test    r10, r10
    jnz     .stoib_clamp_neg
    mov     r9, 0x7fffffffffffffff
    jmp     .stoib_pos
.stoib_clamp_neg:
    mov     r9, 0x8000000000000000
.stoib_pos:
    mov     rax, r9
    pop     r13
    pop     r12
    pop     rbx
    er_ret
.stoib_set_endptr:
    test    r13, r13
    jz      .stoib_ret_zero
    mov     [r13], r12
.stoib_ret_zero:
    xor     eax, eax
    pop     r13
    pop     r12
    pop     rbx
    er_ret
