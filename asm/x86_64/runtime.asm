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
