; EdgeRun ctype bare-metal unit test main.
; Runs as er_kernel_main inside the flat kernel payload and exits QEMU through
; the debug-exit port with a deterministic pass/fail code.

%include "x86_64/macros.inc"

%define DEBUG_EXIT_PORT 0xf4
%define DEBUG_EXIT_PASS 0
%define DEBUG_EXIT_FAIL 1

extern er_isdigit
extern er_isalpha
extern er_isalnum
extern er_isspace
extern er_isxdigit
extern er_islower
extern er_isupper
extern er_tolower
extern er_toupper

SECTION .bss
ctype_failures: resq 1

SECTION .text

%macro CTYPE_EXPECT 3
    mov     edi, %2
    call    %1
    cmp     eax, %3
    je      %%done
    inc     qword [rel ctype_failures]
%%done:
%endmacro

er_fn er_kernel_main
    CTYPE_EXPECT er_isdigit, '0', 1
    CTYPE_EXPECT er_isdigit, '5', 1
    CTYPE_EXPECT er_isdigit, '9', 1
    CTYPE_EXPECT er_isdigit, 'A', 0
    CTYPE_EXPECT er_isdigit, ' ', 0
    CTYPE_EXPECT er_isdigit, 0, 0

    CTYPE_EXPECT er_isalpha, 'A', 1
    CTYPE_EXPECT er_isalpha, 'Z', 1
    CTYPE_EXPECT er_isalpha, 'a', 1
    CTYPE_EXPECT er_isalpha, 'z', 1
    CTYPE_EXPECT er_isalpha, '0', 0
    CTYPE_EXPECT er_isalpha, '[', 0

    CTYPE_EXPECT er_isalnum, 'A', 1
    CTYPE_EXPECT er_isalnum, 'z', 1
    CTYPE_EXPECT er_isalnum, '0', 1
    CTYPE_EXPECT er_isalnum, '9', 1
    CTYPE_EXPECT er_isalnum, ' ', 0
    CTYPE_EXPECT er_isalnum, '@', 0

    CTYPE_EXPECT er_isspace, ' ', 1
    CTYPE_EXPECT er_isspace, 9, 1
    CTYPE_EXPECT er_isspace, 10, 1
    CTYPE_EXPECT er_isspace, 13, 1
    CTYPE_EXPECT er_isspace, 'A', 0
    CTYPE_EXPECT er_isspace, '0', 0

    CTYPE_EXPECT er_isxdigit, '0', 1
    CTYPE_EXPECT er_isxdigit, '9', 1
    CTYPE_EXPECT er_isxdigit, 'A', 1
    CTYPE_EXPECT er_isxdigit, 'F', 1
    CTYPE_EXPECT er_isxdigit, 'a', 1
    CTYPE_EXPECT er_isxdigit, 'f', 1
    CTYPE_EXPECT er_isxdigit, 'G', 0
    CTYPE_EXPECT er_isxdigit, ' ', 0

    CTYPE_EXPECT er_islower, 'a', 1
    CTYPE_EXPECT er_islower, 'z', 1
    CTYPE_EXPECT er_islower, 'A', 0
    CTYPE_EXPECT er_islower, '0', 0

    CTYPE_EXPECT er_isupper, 'A', 1
    CTYPE_EXPECT er_isupper, 'Z', 1
    CTYPE_EXPECT er_isupper, 'a', 0
    CTYPE_EXPECT er_isupper, '0', 0

    CTYPE_EXPECT er_tolower, 'A', 'a'
    CTYPE_EXPECT er_tolower, 'Z', 'z'
    CTYPE_EXPECT er_tolower, 'a', 'a'
    CTYPE_EXPECT er_tolower, '0', '0'
    CTYPE_EXPECT er_tolower, '[', '['

    CTYPE_EXPECT er_toupper, 'a', 'A'
    CTYPE_EXPECT er_toupper, 'z', 'Z'
    CTYPE_EXPECT er_toupper, 'A', 'A'
    CTYPE_EXPECT er_toupper, '0', '0'
    CTYPE_EXPECT er_toupper, '{', '{'

    cmp     qword [rel ctype_failures], 0
    jne     .fail
    mov     eax, DEBUG_EXIT_PASS
    jmp     .exit
.fail:
    mov     eax, DEBUG_EXIT_FAIL
.exit:
    mov     dx, DEBUG_EXIT_PORT
    out     dx, eax
.halt:
    cli
    hlt
    jmp     .halt
