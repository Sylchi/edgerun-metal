; EdgeRun self-hosted test assertion macros
;
; Usage:
;   %include "test/test_macros.inc"
;   SECTION .bss
;   total:  resq 1
;   passed: resq 1
;   failed: resq 1
;
; Tests increment qword [rel passed] on success,
; and always increment qword [rel total] (or [rel failed]).

; ------------------------------------------------------------------
; Basic comparison macros (eax/edx, rax/rdx)
; Expects: qword [rel passed] and qword [rel total] in .bss
; ------------------------------------------------------------------

; Pass if eax == edx (32-bit)
%macro TEST 0
    cmp     eax, edx
    jne     %%fail
    inc     qword [rel passed]
%%fail:
    inc     qword [rel total]
%endmacro

; Pass if rax == rdx (64-bit)
%macro TESTQ 0
    cmp     rax, rdx
    jne     %%fail
    inc     qword [rel passed]
%%fail:
    inc     qword [rel total]
%endmacro

; Pass if [rdi] == [rsi] for ecx bytes
; Clobbers rdi, rsi, ecx, eax
%macro TEST_MEM 0
    cld
    repe    cmpsb
    jne     %%fail
    inc     qword [rel passed]
%%fail:
    inc     qword [rel total]
%endmacro

; ------------------------------------------------------------------
; Assert macros (reg, reg comparison)
; Expects: qword [rel passed] and qword [rel failed] in .bss
; ------------------------------------------------------------------

; Assert %1 == %2 (any same-size registers)
%macro ASSERT_EQ 2
    cmp     %1, %2
    jne     %%fail
    inc     qword [rel passed]
    jmp     %%done
%%fail:
    inc     qword [rel failed]
%%done:
%endmacro

; Assert rax == immediate
%macro ASSERT_RAX 1
    cmp     rax, %1
    jne     %%fail
    inc     qword [rel passed]
    jmp     %%done
%%fail:
    inc     qword [rel failed]
%%done:
%endmacro

; Assert rdx == immediate
%macro ASSERT_RDX 1
    cmp     rdx, %1
    jne     %%fail
    inc     qword [rel passed]
    jmp     %%done
%%fail:
    inc     qword [rel failed]
%%done:
%endmacro

; Assert all bytes at [rdi] equal byte %1 for %2 bytes
; Clobbers rcx, rdi, al
%macro ASSERT_MEM_ALL 2
    push    rcx
    push    rdi
    push    rsi
    mov     rcx, %2
    mov     al, %1
%%loop:
    cmp     [rdi], al
    jne     %%fail
    inc     rdi
    dec     rcx
    jnz     %%loop
    inc     qword [rel passed]
    jmp     %%done
%%fail:
    inc     qword [rel failed]
%%done:
    pop     rsi
    pop     rdi
    pop     rcx
%endmacro

; Assert all %2 bytes at [rdi] are zero
; Clobbers rcx, rdi, eax
%macro ASSERT_MEM_ZERO 2
    push    rcx
    push    rdi
    push    rsi
    mov     rcx, %2
    xor     eax, eax
%%loop:
    cmp     [rdi], al
    jne     %%fail
    inc     rdi
    dec     rcx
    jnz     %%loop
    inc     qword [rel passed]
    jmp     %%done
%%fail:
    inc     qword [rel failed]
%%done:
    pop     rsi
    pop     rdi
    pop     rcx
%endmacro

; Assert u64 at [rdi] == %1; clobbers rax, rdi
%macro ASSERT_MEM_U64 1
    mov     rax, [rdi]
    cmp     rax, %1
    jne     %%fail
    inc     qword [rel passed]
    jmp     %%done
%%fail:
    inc     qword [rel failed]
%%done:
%endmacro
