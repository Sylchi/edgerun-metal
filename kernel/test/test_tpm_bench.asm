; EdgeRun TPM SHA-256 benchmark — RDTSC cycle counter
; Measures cycles per call for TPM SHA-256 and HMAC-SHA256
; at various input sizes. Exits via syscall.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/tpm/tpm_constants.inc"
%include "test/test_macros.inc"

extern er_tpm_hash_sha256
extern er_tpm_crb_transfer
extern er_tpm_parse_sha256_digest
extern er_tor_hmac_sha256
extern er_serial_init
extern er_serial_puts
extern er_serial_puthex64
extern er_serial_crlf
extern er_memset

COM1_PORT equ 0x3F8
ITER      equ 100

SECTION .bss
cmd_buf:   resb 512
rsp_buf:   resb 128
out_buf:   resb 32
data_buf:  resb 2048
cycle_buf: resb 16
avg_buf:   resb 80

SECTION .text
global _start
_start:
    ; Init serial
    mov     rdi, COM1_PORT
    call    er_serial_init

    mov     rdi, COM1_PORT
    lea     rsi, [rel msg_banner]
    call    er_serial_puts
    call    er_serial_crlf

    ; Fill data buffer with pattern
    mov     edi, data_buf
    mov     esi, 0xAB
    mov     edx, 2048
    call    er_memset

    ; ── Benchmark: SHA-256 64 bytes ──
    mov     edi, 64
    call    bench_tpm_sha256

    ; ── Benchmark: SHA-256 256 bytes ──
    mov     edi, 256
    call    bench_tpm_sha256

    ; ── Benchmark: SHA-256 1024 bytes ──
    mov     edi, 1024
    call    bench_tpm_sha256

    ; ── Benchmark: HMAC-SHA256 64 bytes key, 64 bytes msg ──
    mov     edi, 64
    mov     esi, 64
    call    bench_tpm_hmac

    ; ── Benchmark: HMAC-SHA256 32 bytes key, 256 bytes msg ──
    mov     edi, 32
    mov     esi, 256
    call    bench_tpm_hmac

    ; ── Benchmark: HMAC-SHA256 32 bytes key, 1024 bytes msg ──
    mov     edi, 32
    mov     esi, 1024
    call    bench_tpm_hmac

    mov     rdi, COM1_PORT
    lea     rsi, [rel msg_done]
    call    er_serial_puts
    call    er_serial_crlf

    TEST_EXIT 0

; ──────────────────────────────────────────────────────────────────────
; bench_tpm_sha256(edi = data_len)
; ──────────────────────────────────────────────────────────────────────
bench_tpm_sha256:
    push    rbx
    push    r12
    push    r13

    mov     r12d, edi        ; data_len
    mov     r13d, ITER

    ; Warm up (1 iteration)
    mov     rdi, cmd_buf
    mov     rsi, data_buf
    mov     edx, r12d
    mov     ecx, TPM_RH_NULL
    call    er_tpm_hash_sha256
    test    rax, rax
    jz      .err

    sub     rax, cmd_buf
    mov     esi, eax
    mov     rdi, cmd_buf
    mov     rdx, rsp_buf
    mov     ecx, 128
    call    er_tpm_crb_transfer
    test    rax, rax
    jz      .err

    mov     edi, rsp_buf
    mov     esi, eax
    mov     rdx, out_buf
    call    er_tpm_parse_sha256_digest

    ; Benchmark loop
    rdtscp
    shl     rdx, 32
    or      rax, rdx
    mov     rbx, rax        ; start TSC

    xor     r8d, r8d
.loop:
    mov     rdi, cmd_buf
    mov     rsi, data_buf
    mov     edx, r12d
    mov     ecx, TPM_RH_NULL
    call    er_tpm_hash_sha256
    test    rax, rax
    jz      .err

    sub     rax, cmd_buf
    mov     esi, eax
    mov     rdi, cmd_buf
    mov     rdx, rsp_buf
    mov     ecx, 128
    call    er_tpm_crb_transfer
    test    rax, rax
    jz      .err

    mov     edi, rsp_buf
    mov     esi, eax
    mov     rdx, out_buf
    call    er_tpm_parse_sha256_digest

    inc     r8d
    cmp     r8d, r13d
    jb      .loop

    rdtscp
    shl     rdx, 32
    or      rax, rdx        ; end TSC

    sub     rax, rbx
    xor     edx, edx
    div     r13d            ; cycles per call

    ; Print result
    push    rax
    mov     rdi, COM1_PORT
    lea     rsi, [rel msg_sha256]
    call    er_serial_puts
    mov     edi, r12d
    call    dec_write
    mov     rdi, COM1_PORT
    lea     rsi, [rel msg_bytes]
    call    er_serial_puts
    pop     rax
    mov     rdi, COM1_PORT
    mov     rsi, rax
    call    er_serial_puthex64
    mov     rdi, COM1_PORT
    lea     rsi, [rel msg_cyc]
    call    er_serial_puts
    call    er_serial_crlf

    pop     r13
    pop     r12
    pop     rbx
    ret

.err:
    mov     rdi, COM1_PORT
    lea     rsi, [rel msg_err]
    call    er_serial_puts
    call    er_serial_crlf
    pop     r13
    pop     r12
    pop     rbx
    ret

; ──────────────────────────────────────────────────────────────────────
; bench_tpm_hmac(edi = key_len, esi = msg_len)
; ──────────────────────────────────────────────────────────────────────
bench_tpm_hmac:
    push    rbx
    push    r12
    push    r13
    push    r14

    mov     r12d, edi       ; key_len
    mov     r13d, esi       ; msg_len
    mov     r14d, ITER

    ; Warm up
    mov     rdi, data_buf
    mov     esi, r12d
    mov     rdx, data_buf
    add     rdx, 64         ; msg starts after key (avoid overlap)
    mov     ecx, r13d
    mov     r8, out_buf
    call    er_tor_hmac_sha256

    rdtscp
    shl     rdx, 32
    or      rax, rdx
    mov     rbx, rax

    xor     r8d, r8d
.loop:
    mov     rdi, data_buf
    mov     esi, r12d
    mov     rdx, data_buf
    add     rdx, 64
    mov     ecx, r13d
    mov     r8, out_buf
    call    er_tor_hmac_sha256
    inc     r8d
    cmp     r8d, r14d
    jb      .loop

    rdtscp
    shl     rdx, 32
    or      rax, rdx

    sub     rax, rbx
    xor     edx, edx
    div     r14d

    push    rax
    mov     rdi, COM1_PORT
    lea     rsi, [rel msg_hmac]
    call    er_serial_puts
    mov     edi, r12d
    call    dec_write
    mov     rdi, COM1_PORT
    lea     rsi, [rel msg_kbytes]
    call    er_serial_puts
    mov     edi, r13d
    call    dec_write
    mov     rdi, COM1_PORT
    lea     rsi, [rel msg_mbytes]
    call    er_serial_puts
    pop     rax
    mov     rdi, COM1_PORT
    mov     rsi, rax
    call    er_serial_puthex64
    mov     rdi, COM1_PORT
    lea     rsi, [rel msg_cyc]
    call    er_serial_puts
    call    er_serial_crlf

    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; ──────────────────────────────────────────────────────────────────────
; dec_write — write decimal edi to serial
; ──────────────────────────────────────────────────────────────────────
dec_write:
    push    rax
    push    rcx
    push    rdx
    push    rsi
    push    rdi

    mov     eax, edi
    mov     ecx, 10
    sub     rsp, 16
    lea     r8, [rsp + 15]
    mov     byte [r8], 0
    dec     r8
.next:
    xor     edx, edx
    div     ecx
    add     dl, '0'
    mov     [r8], dl
    dec     r8
    test    eax, eax
    jnz     .next
    inc     r8

    mov     rdi, COM1_PORT
    mov     rsi, r8
    call    er_serial_puts

    add     rsp, 16
    pop     rdi
    pop     rsi
    pop     rdx
    pop     rcx
    pop     rax
    ret

SECTION .rodata
msg_banner:  db "TPM SHA-256 Benchmark (", __XSTRING__(ITER), " iterations each)", 0
msg_sha256:  db "SHA-256 ", 0
msg_hmac:    db "HMAC-SHA256 ", 0
msg_bytes:   db " bytes: ", 0
msg_kbytes:  db "K/", 0
msg_mbytes:  db "M: ", 0
msg_cyc:     db " cyc/call", 0
msg_err:     db "TPM ERROR", 0
msg_done:    db "Benchmark complete.", 0
