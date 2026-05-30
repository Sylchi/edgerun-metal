; ==================================================================
; EdgeRun WASM Compiler — Writer/read helpers, hashing, parsing
; Extracted from wasm_compiler.asm for maintainability
; ==================================================================

%include "x86_64/macros.inc"
%include "x86_64/wasm/wasm_compiler.inc"

SECTION .text

; ------------------------------------------------------------------
; Append single byte to writer buffer
; rdi = writer struct ptr {bytes_ptr, max_len, cur_len (as qword)}
; sil = byte to append
; Returns: carry set on overflow
; ------------------------------------------------------------------
global writer_append_byte
writer_append_byte:
    mov     rax, [rdi + 16]     ; cur_len
    cmp     rax, [rdi + 8]      ; max_len
    jae     .overflow
    mov     r8, [rdi]           ; bytes ptr
    mov     [r8 + rax], sil
    inc     qword [rdi + 16]
    clc
    ret
.overflow:
    stc
    ret

; ------------------------------------------------------------------
; Append slice to writer buffer
; rdi = writer struct ptr, rsi = source ptr, rdx = source len
; ------------------------------------------------------------------
global writer_append_slice
writer_append_slice:
    mov     rax, [rdi + 16]     ; cur_len
    mov     r8, [rdi + 8]       ; max_len
    sub     r8, rax             ; remaining
    cmp     rdx, r8
    ja      .overflow
    mov     rcx, [rdi]          ; dst = bytes + cur_len
    add     rcx, rax
    push    rsi
    push    rdx
    push    rdi
    mov     rdi, rcx
    mov     rcx, rdx
    rep     movsb
    pop     rdi
    pop     rdx
    pop     rsi
    add     qword [rdi + 16], rdx
    clc
    ret
.overflow:
    stc
    ret

; ------------------------------------------------------------------
; Encode u32 LEB128
; rdi = writer struct ptr, eax = value
; ------------------------------------------------------------------
global writer_append_u32_leb
writer_append_u32_leb:
    er_frame_push
    push    rbx
    mov     ebx, eax
.leb_loop:
    mov     sil, bl
    and     sil, LEB_PAYLOAD_MASK
    shr     ebx, 7
    test    ebx, ebx
    jz      .last_byte
    or      sil, LEB_CONTINUE_MASK
    call    writer_append_byte
    jc      .error
    jmp     .leb_loop
.last_byte:
    call    writer_append_byte
    jc      .error
    xor     eax, eax
    pop     rbx
    pop     rbp
    ret
.error:
    or      eax, -1
    pop     rbx
    pop     rbp
    ret

; ------------------------------------------------------------------
; Encode i32 LEB128 (signed)
; rdi = writer struct ptr, eax = value
; ------------------------------------------------------------------
global writer_append_i32_leb
writer_append_i32_leb:
    er_frame_push
    push    rbx
    movsxd  rbx, eax
.sleb_loop:
    mov     sil, bl
    and     sil, LEB_PAYLOAD_MASK
    mov     rcx, rbx
    sar     rbx, 7
    test    rbx, rbx
    jnz     .not_done
    test    sil, LEB_SIGN_MASK
    jz      .last
.not_done:
    cmp     rbx, -1
    jne     .more
    test    sil, LEB_SIGN_MASK
    jnz     .last
.more:
    or      sil, LEB_CONTINUE_MASK
    call    writer_append_byte
    jc      .error
    jmp     .sleb_loop
.last:
    call    writer_append_byte
    jc      .error
    xor     eax, eax
    pop     rbx
    pop     rbp
    ret
.error:
    or      eax, -1
    pop     rbx
    pop     rbp
    ret

; ------------------------------------------------------------------
; Name writer: LEB(len) + bytes
; rdi = writer struct ptr, rsi = name ptr, edx = name len
; ------------------------------------------------------------------
global writer_append_name
writer_append_name:
    er_frame_push
    push    rsi
    push    rdx
    mov     eax, edx
    call    writer_append_u32_leb
    test    eax, eax
    jnz     .error
    pop     rdx
    pop     rsi
    call    writer_append_slice
    jc      .error2
    xor     eax, eax
    pop     rbp
    ret
.error:
    pop     rdx
    pop     rsi
.error2:
    or      eax, -1
    pop     rbp
    ret

; ------------------------------------------------------------------
; Read u32 LEB128 from [rsi], return in eax, advance rsi
; Returns carry set on error
; ------------------------------------------------------------------
global read_u32_leb
read_u32_leb:
    xor     eax, eax
    xor     ecx, ecx
    xor     r8d, r8d
.r_loop:
    cmp     r8d, LEB32_MAX_BYTES
    jae     .r_error
    movzx   r9d, byte [rsi]
    inc     rsi
    mov     r10d, r9d
    and     r10d, LEB_PAYLOAD_MASK
    shl     r10d, cl
    or      eax, r10d
    add     ecx, LEB_BITS_PER_BYTE
    inc     r8d
    test    r9d, LEB_CONTINUE_MASK
    jnz     .r_loop
    clc
    ret
.r_error:
    stc
    ret

; ------------------------------------------------------------------
; Read one byte from [rsi], return in al, advance rsi
; ------------------------------------------------------------------
global read_byte
read_byte:
    movzx   eax, byte [rsi]
    inc     rsi
    ret

; ------------------------------------------------------------------
; FNV-1a hash
; rdi = data ptr, rsi = length
; Returns eax = hash
; ------------------------------------------------------------------
global fnv1a_hash
fnv1a_hash:
    mov     eax, FNV_OFFSET_BASIS
    test    rsi, rsi
    jz      .done
.hash_loop:
    movzx   ecx, byte [rdi]
    xor     eax, ecx
    imul    eax, FNV_PRIME
    inc     rdi
    dec     rsi
    jnz     .hash_loop
.done:
    ret

; ------------------------------------------------------------------
; Integer parsing from decimal string
; rdi = string ptr, rsi = length
; Returns eax = value, carry set on error
; ------------------------------------------------------------------
global parse_decimal_i32
parse_decimal_i32:
    er_frame_push
    push    rbx
    xor     eax, eax
    mov     ebx, 1
    mov     rcx, rsi
    test    rcx, rcx
    jz      .error
    movzx   edx, byte [rdi]
    cmp     dl, '-'
    jne     .digit_loop
    mov     ebx, -1
    inc     rdi
    dec     rcx
    jz      .error
.digit_loop:
    movzx   edx, byte [rdi]
    sub     dl, '0'
    cmp     dl, 9
    ja      .error
    imul    eax, 10
    jo      .error
    add     eax, edx
    jo      .error
    inc     rdi
    dec     rcx
    jnz     .digit_loop
    imul    eax, ebx
    clc
    pop     rbx
    pop     rbp
    ret
.error:
    stc
    pop     rbx
    pop     rbp
    ret
