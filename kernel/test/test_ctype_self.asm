; EdgeRun ctype self-hosted test runner — x86_64 assembly
; No libc, no external dependencies. Exits via syscall.
; Returns 0 if all tests pass, 1 on any failure.

%include "x86_64/macros.inc"

extern er_isdigit, er_isalpha, er_isalnum, er_isspace
extern er_isxdigit, er_islower, er_isupper, er_tolower, er_toupper

; Increment 'passed' if condition is true; always increment 'total'
%macro TEST_CTYPE 3
    mov     edi, %2
    call    %1
    cmp     eax, %3
    jne     %%fail
    inc     qword [rel passed]
%%fail:
    inc     qword [rel total]
%endmacro

SECTION .bss
total:  resq 1
passed: resq 1

SECTION .text
global _start
_start:
    ; er_isdigit
    TEST_CTYPE er_isdigit, '0', 1
    TEST_CTYPE er_isdigit, '5', 1
    TEST_CTYPE er_isdigit, '9', 1
    TEST_CTYPE er_isdigit, 'A', 0
    TEST_CTYPE er_isdigit, ' ', 0
    TEST_CTYPE er_isdigit, 0,   0

    ; er_isalpha
    TEST_CTYPE er_isalpha, 'A', 1
    TEST_CTYPE er_isalpha, 'Z', 1
    TEST_CTYPE er_isalpha, 'a', 1
    TEST_CTYPE er_isalpha, 'z', 1
    TEST_CTYPE er_isalpha, '0', 0
    TEST_CTYPE er_isalpha, '[', 0

    ; er_isalnum
    TEST_CTYPE er_isalnum, 'A', 1
    TEST_CTYPE er_isalnum, 'z', 1
    TEST_CTYPE er_isalnum, '0', 1
    TEST_CTYPE er_isalnum, '9', 1
    TEST_CTYPE er_isalnum, ' ', 0
    TEST_CTYPE er_isalnum, '@', 0

    ; er_isspace
    TEST_CTYPE er_isspace, ' ',  1
    TEST_CTYPE er_isspace, 9,    1       ; \t
    TEST_CTYPE er_isspace, 10,   1       ; \n
    TEST_CTYPE er_isspace, 13,   1       ; \r
    TEST_CTYPE er_isspace, 'A',  0
    TEST_CTYPE er_isspace, '0',  0

    ; er_isxdigit
    TEST_CTYPE er_isxdigit, '0', 1
    TEST_CTYPE er_isxdigit, '9', 1
    TEST_CTYPE er_isxdigit, 'A', 1
    TEST_CTYPE er_isxdigit, 'F', 1
    TEST_CTYPE er_isxdigit, 'a', 1
    TEST_CTYPE er_isxdigit, 'f', 1
    TEST_CTYPE er_isxdigit, 'G', 0
    TEST_CTYPE er_isxdigit, ' ', 0

    ; er_islower
    TEST_CTYPE er_islower, 'a', 1
    TEST_CTYPE er_islower, 'z', 1
    TEST_CTYPE er_islower, 'A', 0
    TEST_CTYPE er_islower, '0', 0

    ; er_isupper
    TEST_CTYPE er_isupper, 'A', 1
    TEST_CTYPE er_isupper, 'Z', 1
    TEST_CTYPE er_isupper, 'a', 0
    TEST_CTYPE er_isupper, '0', 0

    ; er_tolower
    TEST_CTYPE er_tolower, 'A', 'a'
    TEST_CTYPE er_tolower, 'Z', 'z'
    TEST_CTYPE er_tolower, 'a', 'a'
    TEST_CTYPE er_tolower, '0', '0'
    TEST_CTYPE er_tolower, '[', '['

    ; er_toupper
    TEST_CTYPE er_toupper, 'a', 'A'
    TEST_CTYPE er_toupper, 'z', 'Z'
    TEST_CTYPE er_toupper, 'A', 'A'
    TEST_CTYPE er_toupper, '0', '0'
    TEST_CTYPE er_toupper, '{', '{'

    ; Return 0 if passed == total, 1 otherwise
    mov     rax, [rel passed]
    mov     rdx, [rel total]
    cmp     rax, rdx
    setne   dil                 ; edi = 1 if failure, 0 if all passed

    mov     eax, 60             ; sys_exit
    syscall
