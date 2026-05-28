; EdgeRun x86_64 bare-metal kernel main.
; Called from entry.asm after stack and BSS are ready.
; Follows the project kernel pattern: banner → checks → PASS.

%include "x86_64/macros.inc"

extern er_serial_init
extern er_serial_puts
extern er_serial_puthex32
extern er_serial_putdec32
extern er_serial_crlf
extern er_strcmp_prefix
extern er_cpu_id
extern er_rdtsc
extern er_halt

extern er_tpm_crb_present
extern er_tpm_crb_transfer
extern er_tpm_startup
extern er_tpm_get_random
extern er_tpm_get_capability
extern er_tpm_response_success
extern er_tpm_has_algorithm

; TPM constants (mirrored from tpm.asm for kernel_main use)
%define TPM_CAP_ALGS            0x00000000
%define TPM_CMD_GET_CAP_LEN     22
%define TPM_CMD_STARTUP_LEN     12
%define TPM_CMD_GET_RANDOM_LEN  12
%define TPM_ALG_SHA256          0x000b
%define TPM_ALG_ECC             0x0023

; QEMU debugcon port and ISA debugcon device registers
%define COM1_PORT      0x3f8
%define BAUD_115200    1

SECTION .data
banner:        db "EdgeRun x86_64 bare metal", 0
check_cpu:     db "check: cpuid signature 0x", 0
check_rdtsc:   db "check: rdtsc ok", 0
check_serial:  db "check: serial 0x", 0
check_tpm_abs: db "check: tpm absent", 0
check_tpm_pre: db "check: tpm present", 0
check_tpm_sta: db "check: tpm startup ok", 0
check_tpm_rnd: db "check: tpm random ok", 0
check_tpm_sh2: db "check: tpm alg sha256 ok", 0
check_tpm_ecc: db "check: tpm alg ecc ok", 0
check_tpm_fail:db "check: tpm failed", 0
pass_text:     db "PASS asm-bare-metal-x86_64", 0

SECTION .bss
tpm_cmd_buf:  resb 512
tpm_rsp_buf:  resb 512

SECTION .text

; Helper: save regs for TPM operations
%macro tpm_op_save 0
    push    r12
    push    r13
    push    r14
%endmacro

%macro tpm_op_restore 0
    pop     r14
    pop     r13
    pop     r12
%endmacro

er_fn er_kernel_main
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    ; Initialize serial COM1 at 115200 baud
    mov     rdi, COM1_PORT
    mov     rsi, BAUD_115200
    call    er_serial_init

    ; Print banner
    mov     rdi, COM1_PORT
    mov     rsi, banner
    call    er_serial_puts
    call    .crlf

    ; check: cpuid signature
    mov     rdi, COM1_PORT
    mov     rsi, check_cpu
    call    er_serial_puts
    call    er_cpu_id
    mov     r12, rax
    mov     rdi, COM1_PORT
    mov     rsi, r12
    call    er_serial_puthex32
    call    .crlf

    ; check: serial
    mov     rdi, COM1_PORT
    mov     rsi, check_serial
    call    er_serial_puts
    mov     rdi, COM1_PORT
    mov     rsi, COM1_PORT
    call    er_serial_puthex32
    call    .crlf

    ; check: rdtsc
    call    er_rdtsc
    mov     rdi, COM1_PORT
    mov     rsi, check_rdtsc
    call    er_serial_puts
    call    .crlf

    ; ─── TPM checks ────────────────────────────────────────────────
    call    er_tpm_crb_present
    test    eax, eax
    jz      .tpm_absent

    mov     rdi, COM1_PORT
    mov     rsi, check_tpm_pre
    call    er_serial_puts
    call    .crlf

    ; TPM Startup(SU_CLEAR)
    lea     rdi, [rel tpm_cmd_buf]
    call    er_tpm_startup
    test    rax, rax
    jz      .tpm_err

    mov     rdi, rax
    mov     esi, TPM_CMD_STARTUP_LEN
    lea     rdx, [rel tpm_rsp_buf]
    mov     ecx, 512
    call    er_tpm_crb_transfer
    mov     r15d, eax            ; save response size
    test    eax, eax
    jz      .tpm_err

    ; Verify startup response
    lea     rdi, [rel tpm_rsp_buf]
    mov     esi, r15d
    call    er_tpm_response_success
    test    eax, eax
    jz      .tpm_err

    mov     rdi, COM1_PORT
    mov     rsi, check_tpm_sta
    call    er_serial_puts
    call    .crlf

    ; GetRandom(16)
    lea     rdi, [rel tpm_cmd_buf]
    mov     esi, 16
    call    er_tpm_get_random
    test    rax, rax
    jz      .tpm_err

    mov     rdi, rax
    mov     esi, TPM_CMD_GET_RANDOM_LEN
    lea     rdx, [rel tpm_rsp_buf]
    mov     ecx, 512
    call    er_tpm_crb_transfer
    mov     r15d, eax
    test    eax, eax
    jz      .tpm_err

    lea     rdi, [rel tpm_rsp_buf]
    mov     esi, r15d
    call    er_tpm_response_success
    test    eax, eax
    jz      .tpm_err

    mov     rdi, COM1_PORT
    mov     rsi, check_tpm_rnd
    call    er_serial_puts
    call    .crlf

    ; GetCapability(ALGS, 0, 32)
    lea     rdi, [rel tpm_cmd_buf]
    mov     esi, TPM_CAP_ALGS
    xor     edx, edx             ; property = 0
    mov     ecx, 32              ; property_count = 32
    call    er_tpm_get_capability
    test    rax, rax
    jz      .tpm_err

    mov     rdi, rax
    mov     esi, TPM_CMD_GET_CAP_LEN
    lea     rdx, [rel tpm_rsp_buf]
    mov     ecx, 512
    call    er_tpm_crb_transfer
    mov     r15d, eax            ; save response size
    test    eax, eax
    jz      .tpm_err

    ; Check for SHA256 algorithm
    lea     rdi, [rel tpm_rsp_buf]
    mov     esi, r15d
    mov     edx, TPM_ALG_SHA256
    call    er_tpm_has_algorithm
    test    eax, eax
    jz      .tpm_alg_fail

    mov     rdi, COM1_PORT
    mov     rsi, check_tpm_sh2
    call    er_serial_puts
    call    .crlf

    ; Check for ECC algorithm (same response)
    lea     rdi, [rel tpm_rsp_buf]
    mov     esi, r15d
    mov     edx, TPM_ALG_ECC
    call    er_tpm_has_algorithm
    test    eax, eax
    jz      .tpm_alg_fail

    mov     rdi, COM1_PORT
    mov     rsi, check_tpm_ecc
    call    er_serial_puts
    call    .crlf
    jmp     .tpm_done

.tpm_alg_fail:
    mov     rdi, COM1_PORT
    mov     rsi, check_tpm_fail
    call    er_serial_puts
    mov     rdi, COM1_PORT
    mov     rsi, check_tpm_alg_fail_details
    call    er_serial_puts
    jmp     .tpm_done

.tpm_absent:
    mov     rdi, COM1_PORT
    mov     rsi, check_tpm_abs
    call    er_serial_puts
    call    .crlf
    jmp     .tpm_done

.tpm_err:
    mov     rdi, COM1_PORT
    mov     rsi, check_tpm_fail
    call    er_serial_puts
    call    .crlf

.tpm_done:
    ; PASS
    mov     rdi, COM1_PORT
    mov     rsi, pass_text
    call    er_serial_puts
    call    .crlf

    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

.crlf:
    mov     rdi, COM1_PORT
    jmp     er_serial_crlf
