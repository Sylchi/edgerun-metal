; EdgeRun object bytes wrapper - x86_64 Linux userspace assembly.
;
; Usage: er_obj_wrap INPUT OUTPUT.erobj

SYS_read       equ 0
SYS_write      equ 1
SYS_open       equ 2
SYS_close      equ 3
SYS_exit_group equ 231

STDERR_FD equ 2
O_RDONLY  equ 0
O_WRONLY_CREAT_TRUNC equ 577
FILE_MODE_0644 equ 0644o

OBJECT_HEADER_SIZE equ 148
OBJECT_BUF_SIZE    equ 1048576
OBJECT_KIND_BYTES  equ 1
OBJECT_VERSION     equ 1

section .bss
object_buf: resb OBJECT_BUF_SIZE
overflow_byte: resb 1
stack_bottom: resb 65536
stack_top:

section .text
global _start

_start:
    mov     r12, [rsp]
    lea     r13, [rsp + 8]
    mov     rsp, stack_top
    cmp     r12, 3
    jne     .usage
    mov     rdi, [r13 + 8]
    call    read_input_body
    test    rax, rax
    js      .io_fail
    mov     r14, rax
    call    write_header
    mov     rdi, [r13 + 16]
    mov     rsi, r14
    call    write_output_object
    test    eax, eax
    jnz     .io_fail
    xor     edi, edi
    jmp     exit_now
.usage:
    lea     rdi, [rel msg_usage]
    call    print_cstr_stderr
    mov     edi, 2
    jmp     exit_now
.io_fail:
    lea     rdi, [rel msg_io_fail]
    call    print_cstr_stderr
    mov     edi, 1
    jmp     exit_now

read_input_body:
    mov     rsi, O_RDONLY
    xor     edx, edx
    mov     eax, SYS_open
    syscall
    test    rax, rax
    js      .ret
    mov     r12, rax
    mov     rdi, r12
    lea     rsi, [rel object_buf + OBJECT_HEADER_SIZE]
    mov     edx, OBJECT_BUF_SIZE - OBJECT_HEADER_SIZE
    mov     eax, SYS_read
    syscall
    mov     r13, rax
    cmp     r13, OBJECT_BUF_SIZE - OBJECT_HEADER_SIZE
    jne     .close_done
    mov     rdi, r12
    lea     rsi, [rel overflow_byte]
    mov     edx, 1
    mov     eax, SYS_read
    syscall
    test    rax, rax
    jg      .too_large
.close_done:
    mov     rdi, r12
    mov     eax, SYS_close
    syscall
    mov     rax, r13
.ret:
    ret
.too_large:
    mov     rdi, r12
    mov     eax, SYS_close
    syscall
    mov     rax, -1
    ret

write_header:
    mov     rax, 0x3130304a424f5245
    mov     [rel object_buf], rax
    mov     word [rel object_buf + 8], OBJECT_VERSION
    mov     word [rel object_buf + 10], OBJECT_KIND_BYTES
    mov     dword [rel object_buf + 12], 0
    mov     [rel object_buf + 16], r14
    mov     word [rel object_buf + 24], 0
    mov     word [rel object_buf + 26], 0
    mov     dword [rel object_buf + 28], 0
    mov     [rel object_buf + 32], r14
    mov     qword [rel object_buf + 40], 0
    mov     qword [rel object_buf + 48], 0
    mov     qword [rel object_buf + 56], 0
    mov     qword [rel object_buf + 64], 0
    mov     qword [rel object_buf + 72], 0
    mov     qword [rel object_buf + 80], 0
    mov     qword [rel object_buf + 88], 0
    mov     qword [rel object_buf + 96], 0
    mov     qword [rel object_buf + 104], 0
    mov     qword [rel object_buf + 112], 0
    mov     qword [rel object_buf + 120], 0
    mov     qword [rel object_buf + 128], 0
    mov     qword [rel object_buf + 136], 0
    ret

write_output_object:
    mov     r12, rsi
    mov     esi, O_WRONLY_CREAT_TRUNC
    mov     edx, FILE_MODE_0644
    mov     eax, SYS_open
    syscall
    test    rax, rax
    js      .fail
    mov     r13, rax
    mov     rdi, r13
    lea     rsi, [rel object_buf]
    lea     rdx, [r12 + OBJECT_HEADER_SIZE]
    mov     eax, SYS_write
    syscall
    lea     rdx, [r12 + OBJECT_HEADER_SIZE]
    cmp     rax, rdx
    jne     .fail
    mov     rdi, r13
    mov     eax, SYS_close
    syscall
    test    rax, rax
    js      .fail
    xor     eax, eax
    ret
.fail:
    mov     eax, 1
    ret

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
msg_usage: db "usage: er_obj_wrap INPUT OUTPUT.erobj", 10, 0
msg_io_fail: db "error: object wrap I/O failed", 10, 0
