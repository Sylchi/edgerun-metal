; EdgeRun object body extractor - x86_64 Linux userspace assembly.
;
; Usage:
;   er_obj_body FILE.erobj
;
; Validates the canonical EROBJ001 bytes-object header used for build graph
; objects, then writes the object body to stdout.

SYS_read       equ 0
SYS_write      equ 1
SYS_open       equ 2
SYS_exit_group equ 231

STDOUT_FD equ 1
STDERR_FD equ 2
O_RDONLY  equ 0

OBJECT_HEADER_SIZE equ 148
OBJECT_BUF_SIZE    equ 1048576
OBJECT_KIND_BYTES  equ 1
OBJECT_VERSION     equ 1

section .bss
object_buf: resb OBJECT_BUF_SIZE
stack_bottom: resb 65536
stack_top:

section .text
global _start

_start:
    mov     r12, [rsp]
    lea     r13, [rsp + 8]
    mov     rsp, stack_top
    cmp     r12, 2
    jne     .usage

    mov     rdi, [r13 + 8]
    call    read_object
    test    rax, rax
    js      .bad_object
    mov     r14, rax

    mov     rdi, r14
    call    validate_object
    test    eax, eax
    jz      .bad_object

    mov     eax, [rel object_buf + 32]
    mov     edx, [rel object_buf + 36]
    test    edx, edx
    jnz     .bad_object
    mov     rdx, rax
    lea     rsi, [rel object_buf + OBJECT_HEADER_SIZE]
    mov     edi, STDOUT_FD
    mov     eax, SYS_write
    syscall
    cmp     rax, rdx
    jne     .write_fail
    xor     edi, edi
    jmp     exit_now

.usage:
    lea     rdi, [rel msg_usage]
    call    print_cstr_stderr
    mov     edi, 2
    jmp     exit_now

.bad_object:
    lea     rdi, [rel msg_bad_object]
    call    print_cstr_stderr
    mov     edi, 1
    jmp     exit_now

.write_fail:
    lea     rdi, [rel msg_write_fail]
    call    print_cstr_stderr
    mov     edi, 1
    jmp     exit_now

%include "host/er_object_file.inc"

print_cstr_stderr:
    push    rdi
    call    cstr_len
    mov     rdx, rax
    pop     rsi
    mov     edi, STDERR_FD
    mov     eax, SYS_write
    syscall
    ret

cstr_len:
    xor     eax, eax
.loop:
    cmp     byte [rdi + rax], 0
    je      .done
    inc     rax
    jmp     .loop
.done:
    ret

exit_now:
    mov     eax, SYS_exit_group
    syscall

section .rodata
msg_usage: db "usage: er_obj_body FILE.erobj", 10, 0
msg_bad_object: db "error: invalid EROBJ001 bytes object", 10, 0
msg_write_fail: db "error: object body write failed", 10, 0
