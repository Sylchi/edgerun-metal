; ==================================================================
; EdgeRun WASM Compiler — Character classification and scanning
; Extracted from wasm_compiler.asm for maintainability
; All functions are global (used by wasm_compiler_source.asm)
; ==================================================================

%include "x86_64/macros.inc"
%include "x86_64/wasm/wasm_compiler.inc"

SECTION .text

; ------------------------------------------------------------------
; Determine if byte is an identifier start character
; al = byte, returns ZF set if true
; ------------------------------------------------------------------
global is_ident_start
is_ident_start:
    cmp     al, 'a'
    jb      .check_upper
    cmp     al, 'z'
    jbe     .yes
.check_upper:
    cmp     al, 'A'
    jb      .check_underscore
    cmp     al, 'Z'
    jbe     .yes
.check_underscore:
    cmp     al, '_'
    je      .yes
    xor     eax, eax
    inc     eax
    ret
.yes:
    cmp     al, al
    ret

; ------------------------------------------------------------------
; Determine if byte is an identifier continue character
; al = byte, returns ZF set if true
; ------------------------------------------------------------------
global is_ident_continue
is_ident_continue:
    call    is_ident_start
    jz      .yes
    cmp     al, '0'
    jb      .no
    cmp     al, '9'
    ja      .no
.yes:
    cmp     al, al
    ret
.no:
    ret

; ------------------------------------------------------------------
; Determine if byte is whitespace
; ------------------------------------------------------------------
global is_ascii_whitespace
is_ascii_whitespace:
    cmp     al, ' '
    je      .yes
    cmp     al, 0x09
    je      .yes
    cmp     al, 0x0a
    je      .yes
    cmp     al, 0x0d
    je      .yes
    xor     eax, eax
    or      eax, 1
    ret
.yes:
    cmp     al, al
    ret

; ------------------------------------------------------------------
; Determine if byte is a digit
; ------------------------------------------------------------------
global is_digit
is_digit:
    cmp     al, '0'
    jb      .no
    cmp     al, '9'
    ja      .no
.yes:
    cmp     al, al
    ret
.no:
    ret

; ------------------------------------------------------------------
; Determine if byte is a hex digit
; ------------------------------------------------------------------
global is_ascii_hex_digit
is_ascii_hex_digit:
    call    is_digit
    je      .yes
    cmp     al, 'a'
    jb      .no
    cmp     al, 'f'
    jbe     .yes
    cmp     al, 'A'
    jb      .no
    cmp     al, 'F'
    ja      .no
.yes:
    cmp     al, al
    ret
.no:
    ret

; ------------------------------------------------------------------
; Skip whitespace and line comments in source
; rdi = source ptr, rsi = source len, rdx = index
; Returns rdx = new index (carry set on end)
; ------------------------------------------------------------------
global skip_space
skip_space:
    er_frame_push
    push    rbx
.loop:
    cmp     rdx, rsi
    jae     .end
    movzx   eax, byte [rdi + rdx]
    call    is_ascii_whitespace
    jz      .skip_char
    cmp     al, '/'
    jne     .done
    cmp     rdx, rsi
    jae     .done
    movzx   ebx, byte [rdi + rdx + 1]
    cmp     bl, '/'
    jne     .done
    add     rdx, 2
.line_comment:
    cmp     rdx, rsi
    jae     .loop
    movzx   eax, byte [rdi + rdx]
    cmp     al, 0x0a
    je      .loop
    cmp     al, 0x0d
    je      .loop
    inc     rdx
    jmp     .line_comment
.skip_char:
    inc     rdx
    jmp     .loop
.done:
    clc
    pop     rbx
    pop     rbp
    ret
.end:
    stc
    pop     rbx
    pop     rbp
    ret

; ------------------------------------------------------------------
; Scan identifier end
; rdi = source ptr, rsi = source len, rdx = start index
; Returns rdx = end index (exclusive), carry if error
; ------------------------------------------------------------------
global scan_identifier_end
scan_identifier_end:
    cmp     rdx, rsi
    jae     .error
    movzx   eax, byte [rdi + rdx]
    call    is_ident_start
    jnz     .error
    inc     rdx
.loop:
    cmp     rdx, rsi
    jae     .done
    movzx   eax, byte [rdi + rdx]
    call    is_ident_continue
    jnz     .done
    inc     rdx
    jmp     .loop
.done:
    clc
    ret
.error:
    stc
    ret

; ------------------------------------------------------------------
; Scan balanced delimiter (matching parens/braces/brackets)
; rdi = source, rsi = source len, rdx = start index
; al = open char, ah = close char
; Returns rdx = index after matching close, carry if error
; ------------------------------------------------------------------
global scan_balanced
scan_balanced:
    er_frame_push
    push    rbx
    push    rcx
    cmp     rdx, rsi
    jae     .error
    movzx   ebx, byte [rdi + rdx]
    cmp     bl, al
    jne     .error
    mov     ecx, 1
    inc     rdx
.loop:
    cmp     rdx, rsi
    jae     .error
    movzx   ebx, byte [rdi + rdx]
    cmp     bl, al
    jne     .check_close
    inc     ecx
    inc     rdx
    jmp     .loop
.check_close:
    cmp     bl, ah
    jne     .next
    dec     ecx
    jz      .found
    inc     rdx
    jmp     .loop
.next:
    inc     rdx
    jmp     .loop
.found:
    inc     rdx
    clc
    pop     rcx
    pop     rbx
    pop     rbp
    ret
.error:
    stc
    pop     rcx
    pop     rbx
    pop     rbp
    ret

; ------------------------------------------------------------------
; Find top-level byte (not inside brackets)
; rdi = source, rsi = source len, rdx = start, cl = byte to find
; Returns rdx = position of byte, carry if not found
; ------------------------------------------------------------------
global find_top_level_byte
find_top_level_byte:
    er_frame_push
    push    rbx
    push    r12
    xor     r8d, r8d
    xor     r9d, r9d
    xor     r10d, r10d
    mov     r11b, cl
.loop:
    cmp     rdx, rsi
    jae     .not_found
    movzx   ebx, byte [rdi + rdx]
    cmp     bl, r11b
    jne     .check_paren
    test    r8d, r8d
    jnz     .skip
    test    r9d, r9d
    jnz     .skip
    test    r10d, r10d
    jnz     .skip
    clc
    pop     r12
    pop     rbx
    pop     rbp
    ret
.check_paren:
    cmp     bl, '('
    jne     .check_brace
    inc     r8d
    jmp     .next
.check_brace:
    cmp     bl, '{'
    jne     .check_bracket
    inc     r9d
    jmp     .next
.check_bracket:
    cmp     bl, '['
    jne     .check_close_paren
    inc     r10d
    jmp     .next
.check_close_paren:
    cmp     bl, ')'
    jne     .check_close_brace
    test    r8d, r8d
    jz      .not_found
    dec     r8d
    jmp     .next
.check_close_brace:
    cmp     bl, '}'
    jne     .check_close_bracket
    test    r9d, r9d
    jz      .not_found
    dec     r9d
    jmp     .next
.check_close_bracket:
    cmp     bl, ']'
    jne     .skip
    test    r10d, r10d
    jz      .not_found
    dec     r10d
.skip:
.next:
    inc     rdx
    jmp     .loop
.not_found:
    stc
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ------------------------------------------------------------------
; Find matching bracket: delegates to scan_balanced
; ------------------------------------------------------------------
global find_matching_bracket
find_matching_bracket:
    mov     al, '['
    mov     ah, ']'
    call    scan_balanced
    ret

; ------------------------------------------------------------------
; Find matching paren: delegates to scan_balanced
; ------------------------------------------------------------------
global find_matching_paren
find_matching_paren:
    mov     al, '('
    mov     ah, ')'
    call    scan_balanced
    ret

; ------------------------------------------------------------------
; Find matching brace: delegates to scan_balanced
; ------------------------------------------------------------------
global find_matching_brace
find_matching_brace:
    mov     al, '{'
    mov     ah, '}'
    call    scan_balanced
    ret

; ------------------------------------------------------------------
; Trim ASCII whitespace from ends of string
; rdi = ptr, rsi = len (in/out)
; Returns rdi = trimmed start, rsi = trimmed length
; ------------------------------------------------------------------
global trim_whitespace
trim_whitespace:
    er_frame_push
    push    rbx
    mov     rcx, rsi
    test    rcx, rcx
    jz      .done
.left_loop:
    movzx   eax, byte [rdi]
    call    is_ascii_whitespace
    jnz     .right_trim
    inc     rdi
    dec     rcx
    jnz     .left_loop
    jmp     .done
.right_trim:
    mov     rsi, rcx
    test    rsi, rsi
    jz      .done
.right_loop:
    movzx   eax, byte [rdi + rsi - 1]
    call    is_ascii_whitespace
    jnz     .done
    dec     rsi
    jnz     .right_loop
.done:
    pop     rbx
    pop     rbp
    ret

; ------------------------------------------------------------------
; Check if all characters in string are whitespace
; rdi = ptr, rsi = len, returns ZF set if all whitespace
; ------------------------------------------------------------------
global all_whitespace
all_whitespace:
    er_frame_push
    test    rsi, rsi
    jz      .yes
.loop:
    movzx   eax, byte [rdi]
    call    is_ascii_whitespace
    jnz     .no
    inc     rdi
    dec     rsi
    jnz     .loop
.yes:
    cmp     al, al
    pop     rbp
    ret
.no:
    xor     eax, eax
    inc     eax
    pop     rbp
    ret
