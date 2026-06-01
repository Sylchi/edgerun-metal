; EdgeRun string operations — included by runtime.asm

; ==================================================================
; er_strlen — get length of null-terminated string
; size_t er_strlen(const char* str)
; ==================================================================
er_fn er_strlen
    push    rcx
    xor     eax, eax

    er_check_zero rdi, .done

    mov     rcx, -1
    cld
    repne   scasb
    not     rcx
    dec     rcx
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
    mov     al, byte [rdi]
    mov     cl, byte [rsi]
    cmp     al, cl
    jne     .diff

    er_check_zero al, .equal

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
    mov     rax, rdi

.loop:
    mov     cl, byte [rsi]
    mov     byte [rdi], cl
    er_check_zero cl, .done
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
    mov     al, byte [rsi]
    er_check_zero al, .match

    mov     cl, byte [rdi]
    er_check_zero cl, .no_match

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
; er_strchr — find first occurrence of char in null-terminated string
; char* er_strchr(const char* str, int c)
; Returns: pointer to first occurrence, or NULL
; ==================================================================
er_fn er_strchr
    er_check_zero rdi, .strchr_null
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
    er_check_zero rdi, .strrchr_null
    mov     al, sil
    xor     rcx, rcx
    xor     edx, edx
.strrchr_loop:
    cmp     byte [rdi + rcx], al
    jne     .strrchr_next
    lea     rdx, [rdi + rcx]
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
    mov     r8, rdi
    er_check_zero rdx, .strncpy_done
    xor     r9d, r9d
.strncpy_copy:
    cmp     r9, rdx
    jae     .strncpy_done
    mov     al, byte [rsi + r9]
    mov     byte [rdi + r9], al
    er_check_zero al, .strncpy_pad
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
    mov     r8, rdi
    xor     r9d, r9d
.strncat_find_end:
    cmp     byte [rdi + r9], 0
    je      .strncat_copy
    inc     r9
    jmp     .strncat_find_end
.strncat_copy:
    xor     r10d, r10d
.strncat_loop:
    cmp     r10, rdx
    jae     .strncat_terminate
    mov     al, byte [rsi + r10]
    mov     byte [rdi + r9], al
    er_check_zero al, .strncat_done
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
    er_check_zero rdx, .strncmp_equal
    xor     r8d, r8d
.strncmp_loop:
    cmp     r8, rdx
    jae     .strncmp_equal
    mov     al, byte [rdi + r8]
    mov     cl, byte [rsi + r8]
    cmp     al, cl
    jne     .strncmp_diff
    er_check_zero al, .strncmp_equal
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
    er_check_zero al, .strcasecmp_equal
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
    er_check_zero rsi, .strstr_null
    er_check_zero rdi, .strstr_null
    cmp     byte [rsi], 0
    je      .strstr_haystack
.strstr_outer:
    mov     al, byte [rdi]
    er_check_zero al, .strstr_null
    mov     r8, rdi
    mov     r9, rsi
.strstr_inner:
    mov     al, byte [r9]
    er_check_zero al, .strstr_found
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
; er_strspn — get length of initial segment of str consisting of
;             characters from accept
; size_t er_strspn(const char* str, const char* accept)
; ==================================================================
er_fn er_strspn
    xor     r8d, r8d
.strspn_outer:
    movzx   eax, byte [rdi + r8]
    er_check_zero al, .strspn_done
    mov     rcx, rsi
.strspn_inner:
    movzx   edx, byte [rcx]
    er_check_zero dl, .strspn_done
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
    xor     r8d, r8d
.strcspn_outer:
    movzx   eax, byte [rdi + r8]
    er_check_zero al, .strcspn_done
    mov     rcx, rsi
.strcspn_inner:
    movzx   edx, byte [rcx]
    er_check_zero dl, .strcspn_found
    cmp     al, dl
    je      .strcspn_done
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
    er_check_zero al, .strpbrk_null
    mov     rcx, rsi
.strpbrk_inner:
    movzx   edx, byte [rcx]
    er_check_zero dl, .strpbrk_next
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
; er_strtok — tokenize string by delimiters (reentrant state)
; char* er_strtok(char* str, const char* delim)
; First call with non-NULL str initializes; subsequent calls with NULL
; ==================================================================

SECTION .bss
_strtok_save: resq 1

SECTION .text
er_fn er_strtok
    er_check_zero rdi, .strtok_continue
    mov     [rel _strtok_save], rdi
.strtok_continue:
    mov     rdi, [rel _strtok_save]
    er_check_zero rdi, .strtok_null
.strtok_skip:
    movzx   eax, byte [rdi]
    er_check_zero al, .strtok_null
    mov     rsi, rsi
    mov     rcx, rsi
.strtok_delim_check:
    movzx   edx, byte [rcx]
    er_check_zero dl, .strtok_token_start
    cmp     al, dl
    je      .strtok_skip_char
    inc     rcx
    jmp     .strtok_delim_check
.strtok_skip_char:
    inc     rdi
    jmp     .strtok_skip
.strtok_token_start:
    mov     r8, rdi
.strtok_find_end:
    movzx   eax, byte [rdi]
    er_check_zero al, .strtok_end
    mov     rcx, rsi
.strtok_end_check:
    movzx   edx, byte [rcx]
    er_check_zero dl, .strtok_next_char
    cmp     al, dl
    je      .strtok_terminate
    inc     rcx
    jmp     .strtok_end_check
.strtok_next_char:
    inc     rdi
    jmp     .strtok_find_end
.strtok_terminate:
    mov     byte [rdi], 0
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
