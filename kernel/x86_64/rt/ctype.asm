; EdgeRun freestanding ctype character classification — x86_64 assembly
; System V AMD64 ABI: arg1=edi (int c), retval=eax
; All functions return 1 for true, 0 for false (or converted char for tolower/toupper)

%include "x86_64/macros.inc"

SECTION .text

; ==================================================================
; er_isdigit — check if character is a decimal digit (0-9)
; int er_isdigit(int c)
; ==================================================================
er_fn er_isdigit
    cmp     dil, '0'
    jb      .digit_false
    cmp     dil, '9'
    ja      .digit_false
    mov     eax, 1
    er_ret
.digit_false:
    xor     eax, eax
    er_ret

; ==================================================================
; er_isalpha — check if character is a letter (A-Z, a-z)
; int er_isalpha(int c)
; ==================================================================
er_fn er_isalpha
    cmp     dil, 'A'
    jb      .alpha_lower
    cmp     dil, 'Z'
    ja      .alpha_lower
    mov     eax, 1
    er_ret
.alpha_lower:
    cmp     dil, 'a'
    jb      .alpha_false
    cmp     dil, 'z'
    ja      .alpha_false
    mov     eax, 1
    er_ret
.alpha_false:
    xor     eax, eax
    er_ret

; ==================================================================
; er_isalnum — check if character is alphanumeric (A-Z, a-z, 0-9)
; int er_isalnum(int c)
; ==================================================================
er_fn er_isalnum
    cmp     dil, '0'
    jb      .alnum_alpha
    cmp     dil, '9'
    ja      .alnum_alpha
    mov     eax, 1
    er_ret
.alnum_alpha:
    cmp     dil, 'A'
    jb      .alnum_false
    cmp     dil, 'Z'
    ja      .alnum_lower
    mov     eax, 1
    er_ret
.alnum_lower:
    cmp     dil, 'a'
    jb      .alnum_false
    cmp     dil, 'z'
    ja      .alnum_false
    mov     eax, 1
    er_ret
.alnum_false:
    xor     eax, eax
    er_ret

; ==================================================================
; er_isspace — check if character is whitespace
; Spaces: ' ', \t, \n, \r, \f, \v
; int er_isspace(int c)
; ==================================================================
er_fn er_isspace
    cmp     dil, ' '
    jb      .space_range
    cmp     dil, ' '
    ja      .space_range
    mov     eax, 1
    er_ret
.space_range:
    cmp     dil, 9
    jb      .space_false
    cmp     dil, 13
    ja      .space_false
    mov     eax, 1
    er_ret
.space_false:
    xor     eax, eax
    er_ret

; ==================================================================
; er_isxdigit — check if character is hex digit (0-9, A-F, a-f)
; int er_isxdigit(int c)
; ==================================================================
er_fn er_isxdigit
    cmp     dil, '0'
    jb      .xdigit_false
    cmp     dil, '9'
    ja      .xdigit_upper
    mov     eax, 1
    er_ret
.xdigit_upper:
    cmp     dil, 'A'
    jb      .xdigit_false
    cmp     dil, 'F'
    ja      .xdigit_lower
    mov     eax, 1
    er_ret
.xdigit_lower:
    cmp     dil, 'a'
    jb      .xdigit_false
    cmp     dil, 'f'
    ja      .xdigit_false
    mov     eax, 1
    er_ret
.xdigit_false:
    xor     eax, eax
    er_ret

; ==================================================================
; er_islower — check if character is lowercase letter (a-z)
; int er_islower(int c)
; ==================================================================
er_fn er_islower
    cmp     dil, 'a'
    jb      .lower_false
    cmp     dil, 'z'
    ja      .lower_false
    mov     eax, 1
    er_ret
.lower_false:
    xor     eax, eax
    er_ret

; ==================================================================
; er_isupper — check if character is uppercase letter (A-Z)
; int er_isupper(int c)
; ==================================================================
er_fn er_isupper
    cmp     dil, 'A'
    jb      .upper_false
    cmp     dil, 'Z'
    ja      .upper_false
    mov     eax, 1
    er_ret
.upper_false:
    xor     eax, eax
    er_ret

; ==================================================================
; er_tolower — convert uppercase letter to lowercase
; Returns lowercase equivalent, or c unchanged if not uppercase.
; int er_tolower(int c)
; ==================================================================
er_fn er_tolower
    mov     eax, edi
    cmp     dil, 'A'
    jb      .tolower_done
    cmp     dil, 'Z'
    ja      .tolower_done
    add     eax, 32
.tolower_done:
    er_ret

; ==================================================================
; er_toupper — convert lowercase letter to uppercase
; Returns uppercase equivalent, or c unchanged if not lowercase.
; int er_toupper(int c)
; ==================================================================
er_fn er_toupper
    mov     eax, edi
    cmp     dil, 'a'
    jb      .toupper_done
    cmp     dil, 'z'
    ja      .toupper_done
    sub     eax, 32
.toupper_done:
    er_ret
