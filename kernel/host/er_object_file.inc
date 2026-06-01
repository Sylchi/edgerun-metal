; Shared EROBJ001 bytes-object file helpers for Linux host ASM tools.
; Requires caller-provided constants: SYS_open, SYS_read, O_RDONLY,
; OBJECT_HEADER_SIZE, OBJECT_BUF_SIZE, OBJECT_VERSION, OBJECT_KIND_BYTES.
; Requires caller-provided BSS symbol: object_buf.

; read_object(path) -> rax=bytes read or negative syscall error
read_object:
    mov     rsi, O_RDONLY
    xor     edx, edx
    mov     eax, SYS_open
    syscall
    test    rax, rax
    js      .ret
    mov     rdi, rax
    lea     rsi, [rel object_buf]
    mov     edx, OBJECT_BUF_SIZE
    mov     eax, SYS_read
    syscall
.ret:
    ret

; validate_object(total_len) -> eax=1 valid, 0 invalid
validate_object:
    cmp     rdi, OBJECT_HEADER_SIZE
    jb      .invalid
    mov     rax, [rel object_buf]
    mov     rcx, 0x3130304a424f5245     ; EROBJ001
    cmp     rax, rcx
    jne     .invalid
    cmp     word [rel object_buf + 8], OBJECT_VERSION
    jne     .invalid
    cmp     word [rel object_buf + 10], OBJECT_KIND_BYTES
    jne     .invalid
    cmp     dword [rel object_buf + 12], 0
    jne     .invalid
    cmp     word [rel object_buf + 24], 0
    jne     .invalid
    cmp     word [rel object_buf + 26], 0
    jne     .invalid
    cmp     dword [rel object_buf + 28], 0
    jne     .invalid
    mov     rax, [rel object_buf + 16]
    cmp     rax, [rel object_buf + 32]
    jne     .invalid
    mov     rax, rdi
    sub     rax, OBJECT_HEADER_SIZE
    cmp     rax, [rel object_buf + 32]
    jne     .invalid
    lea     rsi, [rel object_buf + 132]
    mov     ecx, 16
.reserved_loop:
    cmp     byte [rsi], 0
    jne     .invalid
    inc     rsi
    loop    .reserved_loop
    mov     eax, 1
    ret
.invalid:
    xor     eax, eax
    ret
