; EdgeRun EFI boot variable manager — x86_64 Linux userspace assembly.
;
; Writes EFI global variables directly through efivarfs. File contents use the
; Linux efivarfs ABI: 4 bytes of variable attributes followed by EFI data.

%define SYS_write       1
%define SYS_read        0
%define SYS_open        2
%define SYS_close       3
%define SYS_unlink      87
%define SYS_exit        60

%define O_RDONLY        0
%define O_WRONLY        1
%define O_CREAT         64
%define O_TRUNC         512
%define EFIVAR_MODE     0644o

%define EFI_VAR_ATTR    7
%define EFI_VAR_AUTH_ATTR 39
%define LOAD_ACTIVE     1
%define IO_BUF_SIZE     65536
%define AUTH_PAYLOAD_MAX (IO_BUF_SIZE - 4)

%define OP_NONE         0
%define OP_SET_NEXT     1
%define OP_SET_ORDER    2
%define OP_CREATE_FILE  3
%define OP_PREPEND_ORDER 4
%define OP_READ_FILE    5
%define OP_DELETE_FILE  6
%define OP_READ_SECURE  7
%define OP_WRITE_AUTH   8
%define OP_CAPSULE      9

section .data
efivar_prefix: db "/sys/firmware/efi/efivars/", 0
global_guid:   db "-8be4df61-93ca-11d2-aa0d-00e098032b8c", 0
image_security_guid: db "-d719b2cb-3d3a-4596-a3bc-dad00e67656f", 0
capsule_loader_path: db "/dev/efi_capsule_loader", 0
name_boot:     db "Boot", 0
name_bootnext: db "BootNext", 0
name_bootorder: db "BootOrder", 0
name_secureboot: db "SecureBoot", 0
name_setupmode: db "SetupMode", 0
name_pk:       db "PK", 0
name_kek:      db "KEK", 0
name_db:       db "db", 0
name_dbx:      db "dbx", 0

str_help:        db "--help", 0
str_dry_run:     db "--dry-run", 0
str_set_next:    db "--set-next", 0
str_set_order:   db "--set-order", 0
str_prepend_order: db "--prepend-order", 0
str_create_file: db "--create-file", 0
str_read_file:   db "--read-file", 0
str_delete_file: db "--delete-file", 0
str_read_secure: db "--read-secure", 0
str_write_auth:  db "--write-auth", 0
str_capsule:     db "--capsule", 0

msg_usage:
    db "usage:", 10
    db "  er_efiboot --dry-run --create-file #### LABEL LOADER", 10
    db "  er_efiboot --create-file #### LABEL LOADER", 10
    db "  er_efiboot --set-next ####", 10
    db "  er_efiboot --set-order ####[,####...]", 10
    db "  er_efiboot --prepend-order ####", 10
    db "  er_efiboot --read-file ####", 10
    db "  er_efiboot --delete-file ####", 10
    db "  er_efiboot --read-secure SecureBoot|SetupMode|PK|KEK|db|dbx", 10
    db "  er_efiboot --write-auth PK|KEK|db|dbx FILE.auth", 10
    db "  er_efiboot --capsule FIRMWARE.cap", 10
    db 0
msg_written: db "wrote ", 0
msg_read:    db "read ", 0
msg_deleted: db "deleted ", 0
msg_staged:  db "staged ", 0
msg_dry:     db "dry-run ", 0
msg_bytes:   db " bytes", 10, 0
msg_bad:     db "error: invalid arguments", 10, 0
msg_write:   db "error: efivar operation failed", 10, 0
hex_digits:  db "0123456789ABCDEF"

section .bss
opt_op:        resd 1
opt_dry:       resb 1
opt_bootnum:   resw 1
opt_order:     resq 1
opt_label:     resq 1
opt_loader:    resq 1
opt_var:       resq 1
opt_file:      resq 1

path_buf:      resb 256
data_buf:      resb IO_BUF_SIZE
read_buf:      resb IO_BUF_SIZE
hex_buf:       resb 16
stack_bottom:  resb 65536
stack_top:

section .text
global _start

_start:
    mov     r14, [rsp]
    lea     r15, [rsp + 8]
    mov     rsp, stack_top
    mov     dword [opt_op], OP_NONE
    mov     byte [opt_dry], 0
    mov     qword [opt_order], 0
    mov     qword [opt_label], 0
    mov     qword [opt_loader], 0
    mov     qword [opt_var], 0
    mov     qword [opt_file], 0

    cmp     r14, 1
    je      .usage_ok
    mov     rdi, r14
    mov     rsi, r15
    call    parse_args
    test    eax, eax
    jnz     .bad

    mov     eax, [opt_op]
    cmp     eax, OP_SET_NEXT
    je      .set_next
    cmp     eax, OP_SET_ORDER
    je      .set_order
    cmp     eax, OP_CREATE_FILE
    je      .create_file
    cmp     eax, OP_PREPEND_ORDER
    je      .prepend_order
    cmp     eax, OP_READ_FILE
    je      .read_file
    cmp     eax, OP_DELETE_FILE
    je      .delete_file
    cmp     eax, OP_READ_SECURE
    je      .read_secure
    cmp     eax, OP_WRITE_AUTH
    je      .write_auth
    cmp     eax, OP_CAPSULE
    je      .capsule
    jmp     .bad

.set_next:
    lea     rdi, [name_bootnext]
    call    build_global_path
    mov     dword [data_buf], EFI_VAR_ATTR
    movzx   eax, word [opt_bootnum]
    mov     [data_buf + 4], ax
    mov     esi, 6
    jmp     .write

.set_order:
    lea     rdi, [name_bootorder]
    call    build_global_path
    mov     dword [data_buf], EFI_VAR_ATTR
    mov     rdi, [opt_order]
    lea     rsi, [data_buf + 4]
    call    parse_order
    test    edx, edx
    jnz     .bad
    lea     esi, [eax + 4]
    jmp     .write

.create_file:
    lea     rdi, [name_boot]
    movzx   esi, word [opt_bootnum]
    call    build_boot_path
    call    build_file_load_option
    test    edx, edx
    jnz     .bad
    mov     esi, eax
    jmp     .write

.prepend_order:
    lea     rdi, [name_bootorder]
    call    build_global_path
    mov     dword [data_buf], EFI_VAR_ATTR
    movzx   eax, word [opt_bootnum]
    mov     [data_buf + 4], ax
    mov     ecx, 6
    cmp     byte [opt_dry], 1
    je      .prepend_done
    lea     rdi, [path_buf]
    lea     rsi, [read_buf]
    mov     edx, 4096
    call    read_var
    test    eax, eax
    js      .prepend_done
    cmp     eax, 6
    jb      .prepend_done
    mov     r8d, eax
    mov     r9d, 4
.prepend_loop:
    lea     eax, [r9d + 2]
    cmp     eax, r8d
    ja      .prepend_done
    movzx   eax, word [read_buf + r9]
    cmp     ax, [opt_bootnum]
    je      .prepend_next
    mov     [data_buf + rcx], ax
    add     ecx, 2
.prepend_next:
    add     r9d, 2
    jmp     .prepend_loop
.prepend_done:
    mov     esi, ecx
    jmp     .write

.read_file:
    lea     rdi, [name_boot]
    movzx   esi, word [opt_bootnum]
    call    build_boot_path
    cmp     byte [opt_dry], 1
    je      .dry_read
    lea     rdi, [path_buf]
    lea     rsi, [read_buf]
    mov     edx, 4096
    call    read_var
    test    eax, eax
    js      .write_fail
    mov     r12d, eax
    lea     rdi, [msg_read]
    call    print_str
    lea     rdi, [path_buf]
    call    print_str
    mov     edi, r12d
    call    print_size_tail
    xor     edi, edi
    jmp     sys_exit
.dry_read:
    mov     esi, 0
    jmp     .dry

.delete_file:
    lea     rdi, [name_boot]
    movzx   esi, word [opt_bootnum]
    call    build_boot_path
    cmp     byte [opt_dry], 1
    je      .dry_delete
    lea     rdi, [path_buf]
    call    unlink_var
    test    eax, eax
    jnz     .write_fail
    lea     rdi, [msg_deleted]
    call    print_str
    lea     rdi, [path_buf]
    call    print_str
    mov     edi, 0
    call    print_size_tail
    xor     edi, edi
    jmp     sys_exit
.dry_delete:
    mov     esi, 0
    jmp     .dry

.read_secure:
    mov     rdi, [opt_var]
    call    build_secure_path
    test    edx, edx
    jnz     .bad
    cmp     byte [opt_dry], 1
    je      .dry_read
    lea     rdi, [path_buf]
    lea     rsi, [read_buf]
    mov     edx, IO_BUF_SIZE
    call    read_var
    test    eax, eax
    js      .write_fail
    mov     r12d, eax
    lea     rdi, [msg_read]
    call    print_str
    lea     rdi, [path_buf]
    call    print_str
    mov     edi, r12d
    call    print_size_tail
    xor     edi, edi
    jmp     sys_exit

.write_auth:
    mov     rdi, [opt_var]
    call    build_auth_path
    test    edx, edx
    jnz     .bad
    mov     rdi, [opt_file]
    lea     rsi, [data_buf + 4]
    mov     edx, AUTH_PAYLOAD_MAX
    call    read_input_file
    test    eax, eax
    js      .write_fail
    mov     dword [data_buf], EFI_VAR_AUTH_ATTR
    lea     esi, [eax + 4]
    jmp     .write

.capsule:
    lea     rdi, [capsule_loader_path]
    call    copy_path_literal
    cmp     byte [opt_dry], 1
    je      .dry_read
    mov     rdi, [opt_file]
    call    stage_capsule
    test    eax, eax
    js      .write_fail
    mov     r12d, eax
    lea     rdi, [msg_staged]
    call    print_str
    lea     rdi, [path_buf]
    call    print_str
    mov     edi, r12d
    call    print_size_tail
    xor     edi, edi
    jmp     sys_exit

.write:
    mov     r12d, esi
    cmp     byte [opt_dry], 1
    je      .dry
    lea     rdi, [path_buf]
    lea     rdx, [data_buf]
    call    write_var
    test    eax, eax
    jnz     .write_fail
    lea     rdi, [msg_written]
    call    print_str
    lea     rdi, [path_buf]
    call    print_str
    mov     edi, r12d
    call    print_size_tail
    xor     edi, edi
    jmp     sys_exit

.dry:
    lea     rdi, [msg_dry]
    call    print_str
    lea     rdi, [path_buf]
    call    print_str
    mov     edi, r12d
    call    print_size_tail
    xor     edi, edi
    jmp     sys_exit

.usage_ok:
    lea     rdi, [msg_usage]
    call    print_str
    xor     edi, edi
    jmp     sys_exit
.bad:
    lea     rdi, [msg_bad]
    call    print_str
    mov     edi, 1
    jmp     sys_exit
.write_fail:
    lea     rdi, [msg_write]
    call    print_str
    mov     edi, 1
    jmp     sys_exit

; parse_args(argc=rdi, argv=rsi) -> eax=0/-1
parse_args:
    push    rbx
    push    r12
    push    r13
    mov     r12d, edi
    mov     r13, rsi
    mov     ebx, 1
.loop:
    cmp     ebx, r12d
    jae     .done
    mov     rdi, [r13 + rbx * 8]
    inc     ebx
    lea     rsi, [str_help]
    call    str_eq
    test    eax, eax
    jnz     .help
    mov     rdi, [r13 + (rbx - 1) * 8]
    lea     rsi, [str_dry_run]
    call    str_eq
    test    eax, eax
    jz      .ck_set_next
    mov     byte [opt_dry], 1
    jmp     .loop
.ck_set_next:
    mov     rdi, [r13 + (rbx - 1) * 8]
    lea     rsi, [str_set_next]
    call    str_eq
    test    eax, eax
    jz      .ck_set_order
    cmp     dword [opt_op], OP_NONE
    jne     .bad
    cmp     ebx, r12d
    jae     .bad
    mov     rdi, [r13 + rbx * 8]
    inc     ebx
    call    parse_hex4
    test    edx, edx
    jnz     .bad
    mov     [opt_bootnum], ax
    mov     dword [opt_op], OP_SET_NEXT
    jmp     .loop
.ck_set_order:
    mov     rdi, [r13 + (rbx - 1) * 8]
    lea     rsi, [str_set_order]
    call    str_eq
    test    eax, eax
    jz      .ck_prepend_order
    cmp     dword [opt_op], OP_NONE
    jne     .bad
    cmp     ebx, r12d
    jae     .bad
    mov     rax, [r13 + rbx * 8]
    inc     ebx
    mov     [opt_order], rax
    mov     dword [opt_op], OP_SET_ORDER
    jmp     .loop
.ck_prepend_order:
    mov     rdi, [r13 + (rbx - 1) * 8]
    lea     rsi, [str_prepend_order]
    call    str_eq
    test    eax, eax
    jz      .ck_create_file
    cmp     dword [opt_op], OP_NONE
    jne     .bad
    cmp     ebx, r12d
    jae     .bad
    mov     rdi, [r13 + rbx * 8]
    inc     ebx
    call    parse_hex4
    test    edx, edx
    jnz     .bad
    mov     [opt_bootnum], ax
    mov     dword [opt_op], OP_PREPEND_ORDER
    jmp     .loop
.ck_create_file:
    mov     rdi, [r13 + (rbx - 1) * 8]
    lea     rsi, [str_create_file]
    call    str_eq
    test    eax, eax
    jz      .ck_read_file
    cmp     dword [opt_op], OP_NONE
    jne     .bad
    mov     eax, r12d
    sub     eax, ebx
    cmp     eax, 3
    jb      .bad
    mov     rdi, [r13 + rbx * 8]
    inc     ebx
    call    parse_hex4
    test    edx, edx
    jnz     .bad
    mov     [opt_bootnum], ax
    mov     rax, [r13 + rbx * 8]
    inc     ebx
    mov     [opt_label], rax
    mov     rax, [r13 + rbx * 8]
    inc     ebx
    mov     [opt_loader], rax
    mov     dword [opt_op], OP_CREATE_FILE
    jmp     .loop
.ck_read_file:
    mov     rdi, [r13 + (rbx - 1) * 8]
    lea     rsi, [str_read_file]
    call    str_eq
    test    eax, eax
    jz      .ck_delete_file
    cmp     dword [opt_op], OP_NONE
    jne     .bad
    cmp     ebx, r12d
    jae     .bad
    mov     rdi, [r13 + rbx * 8]
    inc     ebx
    call    parse_hex4
    test    edx, edx
    jnz     .bad
    mov     [opt_bootnum], ax
    mov     dword [opt_op], OP_READ_FILE
    jmp     .loop
.ck_delete_file:
    mov     rdi, [r13 + (rbx - 1) * 8]
    lea     rsi, [str_delete_file]
    call    str_eq
    test    eax, eax
    jz      .ck_read_secure
    cmp     dword [opt_op], OP_NONE
    jne     .bad
    cmp     ebx, r12d
    jae     .bad
    mov     rdi, [r13 + rbx * 8]
    inc     ebx
    call    parse_hex4
    test    edx, edx
    jnz     .bad
    mov     [opt_bootnum], ax
    mov     dword [opt_op], OP_DELETE_FILE
    jmp     .loop
.ck_read_secure:
    mov     rdi, [r13 + (rbx - 1) * 8]
    lea     rsi, [str_read_secure]
    call    str_eq
    test    eax, eax
    jz      .ck_write_auth
    cmp     dword [opt_op], OP_NONE
    jne     .bad
    cmp     ebx, r12d
    jae     .bad
    mov     rax, [r13 + rbx * 8]
    inc     ebx
    mov     [opt_var], rax
    mov     dword [opt_op], OP_READ_SECURE
    jmp     .loop
.ck_write_auth:
    mov     rdi, [r13 + (rbx - 1) * 8]
    lea     rsi, [str_write_auth]
    call    str_eq
    test    eax, eax
    jz      .ck_capsule
    cmp     dword [opt_op], OP_NONE
    jne     .bad
    mov     eax, r12d
    sub     eax, ebx
    cmp     eax, 2
    jb      .bad
    mov     rax, [r13 + rbx * 8]
    inc     ebx
    mov     [opt_var], rax
    mov     rax, [r13 + rbx * 8]
    inc     ebx
    mov     [opt_file], rax
    mov     dword [opt_op], OP_WRITE_AUTH
    jmp     .loop
.ck_capsule:
    mov     rdi, [r13 + (rbx - 1) * 8]
    lea     rsi, [str_capsule]
    call    str_eq
    test    eax, eax
    jz      .bad
    cmp     dword [opt_op], OP_NONE
    jne     .bad
    cmp     ebx, r12d
    jae     .bad
    mov     rax, [r13 + rbx * 8]
    inc     ebx
    mov     [opt_file], rax
    mov     dword [opt_op], OP_CAPSULE
    jmp     .loop
.help:
    lea     rdi, [msg_usage]
    call    print_str
    mov     edi, 0
    jmp     sys_exit
.done:
    xor     eax, eax
    jmp     .out
.bad:
    mov     eax, -1
.out:
    pop     r13
    pop     r12
    pop     rbx
    ret

build_global_path:
    lea     rsi, [global_guid]
    call    build_named_guid_path
    ret

copy_path_literal:
    mov     rsi, rdi
    lea     rdi, [path_buf]
    call    copy_cstr
    ret

; rdi=name_boot, esi=bootnum
build_boot_path:
    push    rsi
    lea     rdi, [path_buf]
    lea     rsi, [efivar_prefix]
    call    copy_cstr
    mov     rsi, rdi
    lea     rsi, [name_boot]
    call    append_cstr
    pop     rsi
    call    append_hex4
    lea     rsi, [global_guid]
    call    append_cstr
    ret

; build_secure_path(var=rdi) -> edx=0/-1
build_secure_path:
    push    rbx
    mov     rbx, rdi
    lea     rsi, [name_secureboot]
    call    str_eq
    test    eax, eax
    jnz     .global
    mov     rdi, rbx
    lea     rsi, [name_setupmode]
    call    str_eq
    test    eax, eax
    jnz     .global
    mov     rdi, rbx
    lea     rsi, [name_pk]
    call    str_eq
    test    eax, eax
    jnz     .global
    mov     rdi, rbx
    lea     rsi, [name_kek]
    call    str_eq
    test    eax, eax
    jnz     .global
    mov     rdi, rbx
    lea     rsi, [name_db]
    call    str_eq
    test    eax, eax
    jnz     .image
    mov     rdi, rbx
    lea     rsi, [name_dbx]
    call    str_eq
    test    eax, eax
    jnz     .image
    mov     edx, 1
    jmp     .out
.global:
    mov     rdi, rbx
    lea     rsi, [global_guid]
    call    build_named_guid_path
    xor     edx, edx
    jmp     .out
.image:
    mov     rdi, rbx
    lea     rsi, [image_security_guid]
    call    build_named_guid_path
    xor     edx, edx
.out:
    pop     rbx
    ret

; build_auth_path(var=rdi) -> edx=0/-1
build_auth_path:
    push    rbx
    mov     rbx, rdi
    lea     rsi, [name_pk]
    call    str_eq
    test    eax, eax
    jnz     .global
    mov     rdi, rbx
    lea     rsi, [name_kek]
    call    str_eq
    test    eax, eax
    jnz     .global
    mov     rdi, rbx
    lea     rsi, [name_db]
    call    str_eq
    test    eax, eax
    jnz     .image
    mov     rdi, rbx
    lea     rsi, [name_dbx]
    call    str_eq
    test    eax, eax
    jnz     .image
    mov     edx, 1
    jmp     .out
.global:
    mov     rdi, rbx
    lea     rsi, [global_guid]
    call    build_named_guid_path
    xor     edx, edx
    jmp     .out
.image:
    mov     rdi, rbx
    lea     rsi, [image_security_guid]
    call    build_named_guid_path
    xor     edx, edx
.out:
    pop     rbx
    ret

; build_named_guid_path(name=rdi, guid=rsi)
build_named_guid_path:
    push    rsi
    push    rdi
    lea     rdi, [path_buf]
    lea     rsi, [efivar_prefix]
    call    copy_cstr
    pop     rsi
    call    append_cstr
    pop     rsi
    call    append_cstr
    ret

; build_file_load_option() -> eax=len, edx=0/-1
build_file_load_option:
    push    rbx
    push    r12
    push    r13
    mov     dword [data_buf], EFI_VAR_ATTR
    mov     dword [data_buf + 4], LOAD_ACTIVE
    mov     word [data_buf + 8], 0
    mov     r12d, 10
    mov     r13, [opt_label]
.label_loop:
    movzx   eax, byte [r13]
    inc     r13
    mov     [data_buf + r12], al
    mov     byte [data_buf + r12 + 1], 0
    add     r12d, 2
    test    al, al
    jnz     .label_loop
    mov     ebx, r12d
    mov     byte [data_buf + r12], 4
    mov     byte [data_buf + r12 + 1], 4
    add     r12d, 4
    mov     r13, [opt_loader]
.path_loop:
    movzx   eax, byte [r13]
    inc     r13
    mov     [data_buf + r12], al
    mov     byte [data_buf + r12 + 1], 0
    add     r12d, 2
    test    al, al
    jnz     .path_loop
    mov     eax, r12d
    sub     eax, ebx
    mov     [data_buf + rbx + 2], ax
    mov     word [data_buf + r12], 0xff7f
    mov     word [data_buf + r12 + 2], 4
    add     r12d, 4
    mov     eax, r12d
    sub     eax, ebx
    mov     [data_buf + 8], ax
    mov     eax, r12d
    xor     edx, edx
    pop     r13
    pop     r12
    pop     rbx
    ret

; write_var(path=rdi, len=esi, data=rdx) -> eax=0/-1
write_var:
    push    rbx
    push    r12
    push    r13
    mov     r12d, esi
    mov     r13, rdx
    mov     eax, SYS_open
    mov     esi, O_WRONLY | O_CREAT | O_TRUNC
    mov     edx, EFIVAR_MODE
    syscall
    test    eax, eax
    js      .fail
    mov     ebx, eax
    mov     eax, SYS_write
    mov     edi, ebx
    mov     rsi, r13
    mov     edx, r12d
    syscall
    cmp     eax, r12d
    jne     .close_fail
    mov     eax, SYS_close
    mov     edi, ebx
    syscall
    xor     eax, eax
    jmp     .out
.close_fail:
    mov     eax, SYS_close
    mov     edi, ebx
    syscall
.fail:
    mov     eax, -1
.out:
    pop     r13
    pop     r12
    pop     rbx
    ret

; read_var(path=rdi, out=rsi, cap=edx) -> eax=bytes or -1
read_var:
    push    rbx
    push    r12
    push    r13
    mov     r12, rsi
    mov     r13d, edx
    mov     eax, SYS_open
    mov     esi, O_RDONLY
    xor     edx, edx
    syscall
    test    eax, eax
    js      .fail
    mov     ebx, eax
    mov     eax, SYS_read
    mov     edi, ebx
    mov     rsi, r12
    mov     edx, r13d
    syscall
    mov     r12d, eax
    mov     eax, SYS_close
    mov     edi, ebx
    syscall
    mov     eax, r12d
    jmp     .out
.fail:
    mov     eax, -1
.out:
    pop     r13
    pop     r12
    pop     rbx
    ret

; read_input_file(path=rdi, out=rsi, cap=edx) -> eax=bytes or -1
read_input_file:
    push    rbx
    push    r12
    push    r13
    push    r14
    mov     r13, rsi
    mov     r14d, edx
    xor     r12d, r12d
    mov     eax, SYS_open
    mov     esi, O_RDONLY
    xor     edx, edx
    syscall
    test    eax, eax
    js      .fail
    mov     ebx, eax
.loop:
    cmp     r12d, r14d
    jae     .check_full
    mov     eax, SYS_read
    mov     edi, ebx
    lea     rsi, [r13 + r12]
    mov     edx, r14d
    sub     edx, r12d
    syscall
    test    eax, eax
    js      .close_fail
    jz      .done
    add     r12d, eax
    jmp     .loop
.check_full:
    mov     eax, SYS_read
    mov     edi, ebx
    lea     rsi, [hex_buf]
    mov     edx, 1
    syscall
    test    eax, eax
    js      .close_fail
    jnz     .close_fail
    jmp     .done
.done:
    mov     eax, SYS_close
    mov     edi, ebx
    syscall
    mov     eax, r12d
    jmp     .out
.close_fail:
    mov     eax, SYS_close
    mov     edi, ebx
    syscall
.fail:
    mov     eax, -1
.out:
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; stage_capsule(path=rdi) -> eax=bytes or -1
stage_capsule:
    push    rbx
    push    r12
    push    r13
    push    r14
    mov     eax, SYS_open
    mov     esi, O_RDONLY
    xor     edx, edx
    syscall
    test    eax, eax
    js      .fail
    mov     ebx, eax
    lea     rdi, [capsule_loader_path]
    mov     eax, SYS_open
    mov     esi, O_WRONLY
    xor     edx, edx
    syscall
    test    eax, eax
    js      .close_in_fail
    mov     r12d, eax
    xor     r13d, r13d
.loop:
    mov     eax, SYS_read
    mov     edi, ebx
    lea     rsi, [read_buf]
    mov     edx, IO_BUF_SIZE
    syscall
    test    eax, eax
    js      .close_both_fail
    jz      .done
    mov     r14d, eax
    mov     edi, r12d
    lea     rsi, [read_buf]
    mov     edx, r14d
    call    write_all_fd
    test    eax, eax
    js      .close_both_fail
    add     r13d, r14d
    jmp     .loop
.done:
    mov     eax, SYS_close
    mov     edi, r12d
    syscall
    mov     eax, SYS_close
    mov     edi, ebx
    syscall
    mov     eax, r13d
    jmp     .out
.close_both_fail:
    mov     eax, SYS_close
    mov     edi, r12d
    syscall
.close_in_fail:
    mov     eax, SYS_close
    mov     edi, ebx
    syscall
.fail:
    mov     eax, -1
.out:
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; write_all_fd(fd=edi, buf=rsi, len=edx) -> eax=0/-1
write_all_fd:
    push    rbx
    push    r12
    push    r13
    mov     ebx, edi
    mov     r12, rsi
    mov     r13d, edx
.loop:
    test    r13d, r13d
    jz      .ok
    mov     eax, SYS_write
    mov     edi, ebx
    mov     rsi, r12
    mov     edx, r13d
    syscall
    test    eax, eax
    jle     .fail
    add     r12, rax
    sub     r13d, eax
    jmp     .loop
.ok:
    xor     eax, eax
    jmp     .out
.fail:
    mov     eax, -1
.out:
    pop     r13
    pop     r12
    pop     rbx
    ret

unlink_var:
    mov     eax, SYS_unlink
    syscall
    test    eax, eax
    js      .fail
    xor     eax, eax
    ret
.fail:
    mov     eax, -1
    ret

; parse_order(str=rdi, out=rsi) -> eax=bytes, edx=0/-1
parse_order:
    push    rbx
    push    r12
    mov     rbx, rdi
    mov     r12, rsi
    xor     ecx, ecx
.next:
    mov     rdi, rbx
    call    parse_hex4_term
    test    edx, edx
    jnz     .bad
    mov     [r12 + rcx], ax
    add     ecx, 2
    mov     rbx, rdi
    cmp     byte [rbx], ','
    jne     .end_check
    inc     rbx
    jmp     .next
.end_check:
    cmp     byte [rbx], 0
    jne     .bad
    mov     eax, ecx
    xor     edx, edx
    jmp     .out
.bad:
    xor     eax, eax
    mov     edx, 1
.out:
    pop     r12
    pop     rbx
    ret

parse_hex4:
    call    parse_hex4_term
    test    edx, edx
    jnz     .ret
    cmp     byte [rdi], 0
    je      .ret
    mov     edx, 1
.ret:
    ret

; parse_hex4_term(str=rdi) -> ax=value, rdi=end, edx=0/-1
parse_hex4_term:
    xor     eax, eax
    xor     ecx, ecx
    cmp     byte [rdi], '0'
    jne     .loop
    cmp     byte [rdi + 1], 'x'
    je      .skip_prefix
    cmp     byte [rdi + 1], 'X'
    jne     .loop
.skip_prefix:
    add     rdi, 2
.loop:
    movzx   edx, byte [rdi]
    call    hex_value
    cmp     edx, 16
    jae     .done
    cmp     ecx, 4
    jae     .bad
    shl     eax, 4
    or      eax, edx
    inc     ecx
    inc     rdi
    jmp     .loop
.done:
    test    ecx, ecx
    jz      .bad
    xor     edx, edx
    ret
.bad:
    mov     edx, 1
    ret

hex_value:
    cmp     dl, '0'
    jb      .bad
    cmp     dl, '9'
    jbe     .digit
    cmp     dl, 'A'
    jb      .lower
    cmp     dl, 'F'
    jbe     .upper
.lower:
    cmp     dl, 'a'
    jb      .bad
    cmp     dl, 'f'
    ja      .bad
    sub     dl, 'a' - 10
    ret
.upper:
    sub     dl, 'A' - 10
    ret
.digit:
    sub     dl, '0'
    ret
.bad:
    mov     edx, 16
    ret

copy_cstr:
    mov     rdx, rdi
.loop:
    lodsb
    stosb
    test    al, al
    jnz     .loop
    lea     rdi, [rdi - 1]
    ret

append_cstr:
    jmp     copy_cstr

append_hex4:
    push    rbx
    mov     ebx, esi
    mov     ecx, 12
.loop:
    mov     eax, ebx
    shr     eax, cl
    and     eax, 15
    movzx   eax, byte [hex_digits + rax]
    stosb
    sub     ecx, 4
    jns     .loop
    mov     byte [rdi], 0
    pop     rbx
    ret

str_eq:
.loop:
    mov     al, [rdi]
    cmp     al, [rsi]
    jne     .no
    test    al, al
    jz      .yes
    inc     rdi
    inc     rsi
    jmp     .loop
.yes:
    mov     eax, 1
    ret
.no:
    xor     eax, eax
    ret

print_size_tail:
    push    rdi
    call    print_dec
    lea     rdi, [msg_bytes]
    call    print_str
    pop     rdi
    ret

print_dec:
    push    rbx
    push    r12
    lea     r12, [hex_buf + 15]
    mov     byte [r12], 0
    mov     eax, edi
    mov     ebx, 10
    test    eax, eax
    jnz     .loop
    dec     r12
    mov     byte [r12], '0'
    jmp     .write
.loop:
    xor     edx, edx
    div     ebx
    add     dl, '0'
    dec     r12
    mov     [r12], dl
    test    eax, eax
    jnz     .loop
.write:
    mov     rdi, r12
    call    print_str
    pop     r12
    pop     rbx
    ret

print_str:
    push    rdi
    call    strlen
    mov     edx, eax
    pop     rsi
    mov     eax, SYS_write
    mov     edi, 1
    syscall
    ret

strlen:
    xor     eax, eax
.loop:
    cmp     byte [rdi + rax], 0
    je      .done
    inc     eax
    jmp     .loop
.done:
    ret

sys_exit:
    mov     eax, SYS_exit
    syscall
