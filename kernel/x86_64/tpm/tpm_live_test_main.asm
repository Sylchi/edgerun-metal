; EdgeRun TPM2 live hardware test kernel
; Boots on bare metal, runs every TPM2 command against real CRB TPM,
; prints per-test result ("ok"/"FAIL") over serial, then PASS/FAIL summary.
;
; Build as a kernel image: replaces kernel_main.asm at link time.

%include "x86_64/macros.inc"
%include "x86_64/tpm/tpm_constants.inc"

extern er_serial_init
extern er_serial_puts
extern er_serial_putchar
extern er_serial_puthex32
extern er_serial_putdec32
extern er_halt

extern er_tpm_crb_present
extern er_tpm_crb_transfer
extern er_tpm_startup
extern er_tpm_shutdown
extern er_tpm_get_random
extern er_tpm_get_capability
extern er_tpm_hash_sha256
extern er_tpm_create_primary_p256_signing
extern er_tpm_create_primary_p256_ecdh
extern er_tpm_read_public
extern er_tpm_sign_p256_sha256
extern er_tpm_verify_p256_sha256
extern er_tpm_load_external_p256_verify
extern er_tpm_ecdh_zgen_p256
extern er_tpm_encrypt_decrypt2
extern er_tpm_hmac_sha256
extern er_tpm_flush_context
extern er_tpm_response_success
extern er_tpm_response_code
extern er_tpm_has_algorithm
extern er_tpm_parse_handle
extern er_tpm_parse_sha256_digest
extern er_tpm_parse_p256_public
extern _tpm_get_be32

%define COM1_PORT      0x3f8
%define BAUD_115200    1

SECTION .bss
cmd_buf:  resb 1024
rsp_buf:  resb 1024
hash_out: resb 32
x_out:    resb 32
y_out:    resb 32
iv_buf:   resb 16
sig_r:    resb 32
sig_s:    resb 32
point_buf: resb 64
pub_key:  resb 64
test_ctr: resb 4
pass_ctr: resb 4

SECTION .data
str_banner:  db "EdgeRun TPM2 Live Hardware Test", 0
str_crb:     db "  CRB present: ", 0
str_ok:      db "ok", 0
str_fail:    db "FAIL", 0
str_skip:    db "skip", 0
str_startup: db "  Startup(SU_CLEAR): ", 0
str_getcaps: db "  GetCapability(ALGS): ", 0
str_sha256:  db "  Has SHA256: ", 0
str_ecc:     db "  Has ECC: ", 0
str_random:  db "  GetRandom(32): ", 0
str_hash:    db "  Hash(SHA256): ", 0
str_crtprim: db "  CreatePrimary(P-256 signing): ", 0
str_readpub: db "  ReadPublic: ", 0
str_sign:    db "  Sign(P-256 SHA256): ", 0
str_verify:  db "  VerifySignature: ", 0
str_ladext:  db "  LoadExternal(P-256 verify): ", 0
str_ecdh:    db "  ECDH ZGen: ", 0
str_encdec:  db "  EncryptDecrypt2(AES-128-CFB): ", 0
str_hmac:    db "  HMAC(SHA-256): ", 0
str_flush:   db "  FlushContext: ", 0
str_shut:    db "  Shutdown(SU_CLEAR): ", 0
str_pass:    db "PASS: ", 0
str_fail_all:db "FAIL: ", 0
str_space:   db " ", 0
str_slash:   db "/", 0
str_crlf:    db 13, 10, 0
str_hex:     db "  Random bytes: ", 0

hash_test_data: db "EdgeRun TPM live test"
; SHA-256("EdgeRun TPM live test") — 21 bytes, no null sentinel
; Pre-computed: echo -n "EdgeRun TPM live test" | openssl dgst -sha256
known_hash:  db 0x44, 0xde, 0x2d, 0x9a, 0x00, 0x66, 0x93, 0x3c
             db 0xff, 0xa0, 0x27, 0x83, 0x96, 0xd2, 0x09, 0x79
             db 0x1f, 0x70, 0xed, 0x93, 0x7a, 0x2b, 0x8a, 0x67
              db 0x26, 0x96, 0x3c, 0x30, 0x9f, 0x76, 0x12, 0xc5

; TPM2_Hash command: SHA256 of 21-byte data with TPM_RH_NULL
; The hierarchy handle is PARAMETER 3 (after data + hashAlg), NOT a handle area entry
; Layout: Tag(2) + Size(4) + CC(4) + TPM2B_size(2) + data(21) + hashAlg(2) + hierarchy(4)
hash_cmd_bytes:
db 0x80, 0x01              ; TPM_ST_NO_SESSIONS (BE)
db 0x00, 0x00, 0x00, 0x27  ; size = 39 (BE)
db 0x00, 0x00, 0x01, 0x7D  ; TPM_CC_HASH (BE)
db 0x00, 0x15               ; TPM2B buffer size = 21 (BE)
db "EdgeRun TPM live test"  ; 21 bytes of data
db 0x00, 0x0B               ; TPM_ALG_SHA256 = 0x000B (BE)
db 0x40, 0x00, 0x00, 0x07  ; TPM_RH_NULL (BE) — as parameter 3

SECTION .text

; ─── Test result helpers ───────────────────────────────────────────

; Print test prefix string
; rsi = string
%macro PRINT_STR 0
    mov     rdi, COM1_PORT
    call    er_serial_puts
%endmacro

; Print "ok" and increment counters
%macro TEST_PASS 0
    push    rsi
    mov     rdi, COM1_PORT
    mov     rsi, str_ok
    call    er_serial_puts
    call    .crlf
    add     dword [rel test_ctr], 1
    add     dword [rel pass_ctr], 1
    pop     rsi
%endmacro

; Print "FAIL" and increment counter
%macro TEST_FAIL 0
    push    rsi
    mov     rdi, COM1_PORT
    mov     rsi, str_fail
    call    er_serial_puts
    call    .crlf
    add     dword [rel test_ctr], 1
    pop     rsi
%endmacro

; Print "skip" and increment counter
%macro TEST_SKIP 0
    push    rsi
    mov     rdi, COM1_PORT
    mov     rsi, str_skip
    call    er_serial_puts
    call    .crlf
    add     dword [rel test_ctr], 1
    pop     rsi
%endmacro

; ─── CRB send-and-check macro ──────────────────────────────────────
; Runs er_tpm_crb_transfer, checks response success
; Clobbers rax, rdi, rsi, rdx, rcx
; Sets ZF = 1 on success, 0 on failure
%macro CRB_SEND_CHECK 0
    mov     rdx, rsp_buf
    mov     ecx, 1024
    call    er_tpm_crb_transfer
    er_check_zero rax, %%fail
    mov     rdi, rsp_buf
    mov     esi, eax
    call    er_tpm_response_success
    er_check_zero eax, %%fail
    jmp     %%done
%%fail:
%%done:
%endmacro

; ==================================================================
; er_kernel_main — entry point called by entry.asm
; =================================================================
er_fn er_kernel_main
    er_push rbx, r12, r13, r14, r15

    mov     dword [rel test_ctr], 0
    mov     dword [rel pass_ctr], 0

    ; Init serial
    mov     rdi, COM1_PORT
    mov     rsi, BAUD_115200
    call    er_serial_init

    mov     rdi, COM1_PORT
    mov     rsi, str_banner
    call    er_serial_puts
    call    .crlf
    call    .crlf

    ; ═══════════════════════════════════════════════════════════════
    ; 1. CRB present
    ; ═══════════════════════════════════════════════════════════════
    mov     rsi, str_crb
    PRINT_STR
    ; Debug: test MMIO reads like kernel_main does
    mov     rdi, COM1_PORT
    mov     sil, 'I'
    call    er_serial_putchar
    mov     edi, 0xFEC00000
    mov     eax, [rdi]
    push    rax
    mov     rdi, COM1_PORT
    mov     esi, eax
    call    er_serial_puthex32
    mov     rdi, COM1_PORT
    mov     sil, ' '
    call    er_serial_putchar
    pop     rax
    mov     edi, 0xFED40030
    mov     eax, [rdi]
    push    rax
    mov     rdi, COM1_PORT
    mov     esi, eax
    call    er_serial_puthex32
    mov     rdi, COM1_PORT
    mov     sil, ' '
    call    er_serial_putchar
    pop     rax
    call    er_tpm_crb_present
    er_check_nonzero eax, .tpm_found
    TEST_FAIL
    jmp     .done
.tpm_found:
    TEST_PASS

    ; ═══════════════════════════════════════════════════════════════
    ; 2. GetRandom(32) — tests CRB command/response cycle
    ; ═══════════════════════════════════════════════════════════════
    mov     rsi, str_random
    PRINT_STR
    mov     rdi, cmd_buf
    mov     esi, 32
    call    er_tpm_get_random
    er_check_zero rax, .fail_random
    mov     esi, TPM_CMD_GET_RANDOM_LEN
    mov     rdx, rsp_buf
    mov     ecx, 512
    call    er_tpm_crb_transfer
    er_check_zero rax, .fail_random
    mov     r12d, eax
    mov     rdi, rsp_buf
    mov     esi, eax
    call    er_tpm_response_success
    er_check_zero eax, .fail_random
    TEST_PASS
    ; Dump first 8 random bytes as hex
    mov     rdi, COM1_PORT
    mov     rsi, str_hex
    call    er_serial_puts
    mov     r12, 8
.dump_rand:
    movzx   esi, byte [rsp_buf + TPM_RANDOM_OFFSET + r12 - 1]
    mov     rdi, COM1_PORT
    call    er_serial_puthex32
    dec     r12
    jnz     .dump_rand
    call    .crlf
    jmp     .test_getcaps

.fail_random:
    TEST_FAIL
    jmp     .done

    ; ═══════════════════════════════════════════════════════════════
    ; 3. GetCapability(ALGS)
    ; ═══════════════════════════════════════════════════════════════
.test_getcaps:
    mov     rsi, str_getcaps
    PRINT_STR
    mov     rdi, cmd_buf
    mov     esi, TPM_CAP_ALGS
    xor     edx, edx
    mov     ecx, 64
    call    er_tpm_get_capability
    er_check_zero rax, .fail_getcaps
    mov     esi, TPM_CMD_GET_CAP_LEN
    CRB_SEND_CHECK
    jz      .fail_getcaps
    ; Read response size from header at [rsp_buf+2] for algorithm checks
    mov     r12d, [rsp_buf + 2]
    bswap   r12d
    ; Check for SHA256 in response
    mov     rdi, rsp_buf
    mov     esi, r12d
    mov     edx, TPM_ALG_SHA256
    call    er_tpm_has_algorithm
    ; Don't fail on missing algorithm — just report
    ; Check for ECC in response (same response buffer, same size)
    mov     rdi, rsp_buf
    mov     esi, r12d
    mov     edx, TPM_ALG_ECC
    call    er_tpm_has_algorithm
    TEST_PASS
    jmp     .test_algs_sha256

.fail_getcaps:
    TEST_FAIL
    jmp     .test_algs_sha256

    ; ═══════════════════════════════════════════════════════════════
    ; 3a. Check specific algorithm: SHA256
    ; ═══════════════════════════════════════════════════════════════
.test_algs_sha256:
    mov     rsi, str_sha256
    PRINT_STR
    mov     rdi, rsp_buf
    mov     esi, r12d               ; response size from GetCapability
    mov     edx, TPM_ALG_SHA256
    call    er_tpm_has_algorithm
    er_check_zero al, .no_sha256
    TEST_PASS
    jmp     .test_algs_ecc
.no_sha256:
    TEST_FAIL

    ; ═══════════════════════════════════════════════════════════════
    ; 3b. Check specific algorithm: ECC
    ; ═══════════════════════════════════════════════════════════════
.test_algs_ecc:
    mov     rsi, str_ecc
    PRINT_STR
    mov     rdi, rsp_buf
    mov     esi, r12d               ; response size from GetCapability
    mov     edx, TPM_ALG_ECC
    call    er_tpm_has_algorithm
    er_check_zero al, .no_ecc
    TEST_PASS
    jmp     .test_hash
.no_ecc:
    TEST_FAIL

    ; ═══════════════════════════════════════════════════════════════
    ; Try Startup(SU_CLEAR) — the CRB device may not auto-init
    ; ═══════════════════════════════════════════════════════════════
.test_startup:
    mov     rdi, cmd_buf
    mov     esi, TPM_SU_CLEAR
    call    er_tpm_startup
    er_check_zero rax, .test_hash
    mov     esi, TPM_CMD_STARTUP_LEN
    mov     rdx, rsp_buf
    mov     ecx, 512
    call    er_tpm_crb_transfer
    ; Ignore result — just try

    ; ═══════════════════════════════════════════════════════════════
    ; 4. Hash SHA-256
    ; ═══════════════════════════════════════════════════════════════
.test_hash:
    mov     rsi, str_hash
    PRINT_STR
    ; Build Hash command using pre-defined byte array (no function calls)
    mov     edi, cmd_buf
    mov     esi, hash_cmd_bytes
    mov     ecx, 39
    rep     movsb                  ; copy hardcoded command
    ; Send it
    mov     rdi, cmd_buf
    mov     esi, 39
    mov     rdx, rsp_buf
    mov     ecx, 1024
    call    er_tpm_crb_transfer
    er_check_zero rax, .fail_hash
    ; Check response code
    mov     rdi, rsp_buf
    mov     esi, eax
    call    er_tpm_response_success
    er_check_zero eax, .dump_hash_rc
    ; Extract digest from response
    ; NO_SESSIONS response: Tag(2) + Size(4) + RC(4) + TPM2B_size(2) + digest(32)
    movzx   eax, word [rsp_buf]  ; tag
    cmp     eax, TPM_ST_SESSIONS
    je      .hash_sessions
    movzx   eax, word [rsp_buf + 10]  ; TPM2B size
    xchg    al, ah
    cmp     eax, 32
    jne     .dump_hash_size
    mov     rdi, hash_out
    lea     rsi, [rsp_buf + 12]
    mov     ecx, 32
    rep     movsb
    jmp     .hash_digest_ok
.hash_sessions:
    movzx   eax, word [rsp_buf + 14]  ; TPM2B size
    xchg    al, ah
    cmp     eax, 32
    jne     .dump_hash_size
    mov     rdi, hash_out
    lea     rsi, [rsp_buf + 16]
    mov     ecx, 32
    rep     movsb
.hash_digest_ok:
    mov     r12, 32
    xor     r13d, r13d
.compare_hash:
    movzx   eax, byte [hash_out + r13]
    movzx   ebx, byte [known_hash + r13]
    cmp     eax, ebx
    jne     .fail_hash_mismatch
    inc     r13
    dec     r12
    jnz     .compare_hash
    TEST_PASS
    jmp     .test_create_primary

.dump_hash_rc:
    push    rsi
    mov     rdi, COM1_PORT
    mov     rsi, str_fail
    call    er_serial_puts
    ; Dump first 10 bytes of response header
    mov     r12, 10
    xor     r13d, r13d
.dump_rsp_hash_hdr:
    movzx   esi, byte [rsp_buf + r13]
    mov     rdi, COM1_PORT
    call    er_serial_puthex32
    mov     rdi, COM1_PORT
    mov     sil, ' '
    call    er_serial_putchar
    inc     r13
    dec     r12
    jnz     .dump_rsp_hash_hdr
    call    .crlf
    pop     rsi
    jmp     .test_create_primary

.dump_hash_size:
    push    rsi
    mov     rdi, COM1_PORT
    mov     rsi, str_fail
    call    er_serial_puts
    lea     rdi, [rsp_buf + 6]
    call    _tpm_get_be32
    mov     rdi, COM1_PORT
    mov     esi, eax
    call    er_serial_puthex32
    mov     rdi, COM1_PORT
    mov     rsi, str_space
    call    er_serial_puts
    movzx   eax, word [rsp_buf + 10]
    xchg    al, ah
    mov     rdi, COM1_PORT
    mov     esi, eax
    call    er_serial_puthex32
    call    .crlf
    pop     rsi
    jmp     .test_create_primary

.fail_hash_mismatch:
    ; Print byte index where mismatch first occurs
    push    rsi
    mov     rdi, COM1_PORT
    mov     rsi, str_fail
    call    er_serial_puts
    mov     rdi, COM1_PORT
    mov     esi, r13d
    call    er_serial_putdec32
    call    .crlf
    pop     rsi
    jmp     .test_create_primary

.fail_hash:
    TEST_FAIL

    ; ═══════════════════════════════════════════════════════════════
    ; 6. CreatePrimary(P-256 signing)
    ; ═══════════════════════════════════════════════════════════════
.test_create_primary:
    mov     rsi, str_crtprim
    PRINT_STR
    mov     rdi, cmd_buf
    call    er_tpm_create_primary_p256_signing
    er_check_zero rax, .fail_crtprim
    ; dbg1
    mov     rdi, COM1_PORT
    mov     sil, '1'
    call    er_serial_putchar
    mov     esi, TPM_CMD_CREATE_PRIMARY_LEN
    CRB_SEND_CHECK
    jz      .fail_crtprim
    ; dbg2
    mov     rdi, COM1_PORT
    mov     sil, '2'
    call    er_serial_putchar
    ; Read response size from header, then parse handle
    mov     r14d, [rsp_buf + 2]
    bswap   r14d
    mov     rdi, rsp_buf
    mov     esi, r14d
    call    er_tpm_parse_handle
    er_check_zero eax, .fail_crtprim
    ; dbg3
    mov     rdi, COM1_PORT
    mov     sil, '3'
    call    er_serial_putchar
    mov     r12d, eax           ; r12 = key handle
    ; Parse public key
    mov     rdi, rsp_buf
    mov     esi, r14d
    mov     rdx, x_out
    mov     rcx, y_out
    call    er_tpm_parse_p256_public
    cmp     eax, 64
    jne     .dump_crtprim
    ; Copy x+y to pub_key for LoadExternal
    mov     rdi, pub_key
    mov     rsi, x_out
    mov     ecx, 32
    rep     movsb
    mov     rdi, pub_key + 32
    mov     rsi, y_out
    mov     ecx, 32
    rep     movsb
    TEST_PASS
    jmp     .test_readpub

.dump_crtprim:
    push    rsi
    mov     rdi, COM1_PORT
    mov     rsi, str_fail
    call    er_serial_puts
    ; Dump response code
    lea     rdi, [rsp_buf + 6]
    call    _tpm_get_be32
    mov     rdi, COM1_PORT
    mov     esi, eax
    call    er_serial_puthex32
    mov     rdi, COM1_PORT
    mov     sil, ' '
    call    er_serial_putchar
    ; Dump response size
    mov     rdi, COM1_PORT
    mov     esi, r14d
    call    er_serial_putdec32
    mov     rdi, COM1_PORT
    mov     sil, ' '
    call    er_serial_putchar
    ; Dump first 32 bytes hex
    mov     r12, 32
    xor     r13d, r13d
.dump_crtprim_bytes:
    movzx   esi, byte [rsp_buf + r13]
    mov     rdi, COM1_PORT
    call    er_serial_puthex32
    inc     r13
    dec     r12
    jnz     .dump_crtprim_bytes
    call    .crlf
    pop     rsi

.fail_crtprim:
    push    rsi
    ; Print RC
    mov     rdi, COM1_PORT
    mov     rsi, str_fail
    call    er_serial_puts
    ; Dump first 20 bytes of response
    mov     r12, 20
    xor     r13d, r13d
.dump_crtprim_hdr:
    movzx   esi, byte [rsp_buf + r13]
    mov     rdi, COM1_PORT
    call    er_serial_puthex32
    inc     r13
    dec     r12
    jnz     .dump_crtprim_hdr
    call    .crlf
    pop     rsi
    xor     r12d, r12d
    TEST_FAIL
    jmp     .test_readpub

    ; ═══════════════════════════════════════════════════════════════
    ; 7. ReadPublic (of the primary key)
    ; ═══════════════════════════════════════════════════════════════
.test_readpub:
    mov     rsi, str_readpub
    PRINT_STR
    er_check_zero r12d, .skip_readpub
    mov     rdi, cmd_buf
    mov     esi, r12d
    call    er_tpm_read_public
    er_check_zero rax, .fail_readpub
    mov     esi, TPM_CMD_READ_PUBLIC_LEN
    CRB_SEND_CHECK
    jz      .fail_readpub
    TEST_PASS
    jmp     .test_sign
.skip_readpub:
    TEST_SKIP
    jmp     .test_sign
.fail_readpub:
    TEST_FAIL

    ; ═══════════════════════════════════════════════════════════════
    ; 8. Sign(P-256 SHA256) with primary key
    ; ═══════════════════════════════════════════════════════════════
.test_sign:
    mov     rsi, str_sign
    PRINT_STR
    er_check_zero r12d, .skip_sign
    mov     rdi, cmd_buf
    mov     esi, r12d
    mov     rdx, hash_out
    call    er_tpm_sign_p256_sha256
    er_check_zero rax, .fail_sign
    mov     esi, TPM_CMD_SIGN_LEN
    CRB_SEND_CHECK
    jz      .fail_sign
    TEST_PASS
    jmp     .test_verify
.skip_sign:
    TEST_SKIP
    jmp     .test_verify
.fail_sign:
    TEST_FAIL

    ; ═══════════════════════════════════════════════════════════════
    ; 9. VerifySignature
    ; ═══════════════════════════════════════════════════════════════
.test_verify:
    mov     rsi, str_verify
    PRINT_STR
    er_check_zero r12d, .skip_verify
    mov     rdi, cmd_buf
    mov     esi, r12d
    mov     rdx, hash_out
    mov     rcx, sig_r
    mov     r8, sig_s
    call    er_tpm_verify_p256_sha256
    er_check_zero rax, .fail_verify
    mov     esi, TPM_CMD_VERIFY_SHA256_LEN
    CRB_SEND_CHECK
    jz      .fail_verify
    TEST_PASS
    jmp     .test_loadext
.skip_verify:
    TEST_SKIP
    jmp     .test_loadext
.fail_verify:
    TEST_FAIL

    ; ═══════════════════════════════════════════════════════════════
    ; 10. LoadExternal(P-256 verify key)
    ; ═══════════════════════════════════════════════════════════════
.test_loadext:
    mov     rsi, str_ladext
    PRINT_STR
    mov     rdi, cmd_buf
    mov     rsi, pub_key
    call    er_tpm_load_external_p256_verify
    er_check_zero rax, .fail_loadext
    mov     esi, TPM_CMD_LOAD_EXT_P256_LEN
    CRB_SEND_CHECK
    jz      .fail_loadext
    ; Read response size from header, then parse handle
    mov     r14d, [rsp_buf + 2]
    bswap   r14d
    mov     rdi, rsp_buf
    mov     esi, r14d
    call    er_tpm_parse_handle
    er_check_zero eax, .fail_loadext
    mov     r13d, eax           ; r13 = ext key handle
    TEST_PASS
    jmp     .test_ecdh

.fail_loadext:
    xor     r13d, r13d
    TEST_FAIL

    ; ═══════════════════════════════════════════════════════════════
    ; 11. ECDH ZGen
    ; ═══════════════════════════════════════════════════════════════
.test_ecdh:
    mov     rsi, str_ecdh
    PRINT_STR
    er_check_zero r12d, .skip_ecdh
    ; Build peer point from the public key
    mov     rdi, point_buf
    mov     rsi, x_out
    mov     ecx, 32
    rep     movsb
    mov     rsi, y_out
    mov     ecx, 32
    rep     movsb
    mov     rdi, cmd_buf
    mov     esi, r12d
    mov     rdx, point_buf
    call    er_tpm_ecdh_zgen_p256
    er_check_zero rax, .fail_ecdh
    mov     esi, TPM_CMD_ECDH_ZGEN_LEN
    CRB_SEND_CHECK
    jz      .fail_ecdh
    TEST_PASS
    jmp     .test_encdec
.skip_ecdh:
    TEST_SKIP
    jmp     .test_encdec
.fail_ecdh:
    TEST_FAIL

    ; ═══════════════════════════════════════════════════════════════
    ; 12. EncryptDecrypt2(AES-128-CFB)
    ; ═══════════════════════════════════════════════════════════════
.test_encdec:
    mov     rsi, str_encdec
    PRINT_STR
    er_check_zero r12d, .skip_encdec
    ; IV = zeros
    push    rdi
    mov     rdi, iv_buf
    xor     eax, eax
    mov     ecx, 16
    rep     stosb
    pop     rdi
    mov     rdi, cmd_buf
    mov     esi, r12d
    mov     rdx, hash_test_data
    mov     ecx, 21
    mov     r8, iv_buf
    mov     r9d, TPM_ALG_CFB
    call    er_tpm_encrypt_decrypt2
    er_check_zero rax, .fail_encdec
    mov     edx, 21
    add     edx, TPM_CMD_ENC_DEC2_FIXED_LEN
    add     edx, 16
    mov     esi, edx
    CRB_SEND_CHECK
    jz      .fail_encdec
    TEST_PASS
    jmp     .test_hmac
.skip_encdec:
    TEST_SKIP
    jmp     .test_hmac
.fail_encdec:
    TEST_FAIL

    ; ═══════════════════════════════════════════════════════════════
    ; 13. HMAC(SHA-256)
    ; ═══════════════════════════════════════════════════════════════
.test_hmac:
    mov     rsi, str_hmac
    PRINT_STR
    er_check_zero r12d, .skip_hmac
    mov     rdi, cmd_buf
    mov     esi, r12d
    mov     rdx, hash_test_data
    mov     ecx, 21
    call    er_tpm_hmac_sha256
    er_check_zero rax, .fail_hmac
    mov     esi, TPM_CMD_HMAC_FIXED_LEN + 21
    CRB_SEND_CHECK
    jz      .fail_hmac
    TEST_PASS
    jmp     .test_flush
.skip_hmac:
    TEST_SKIP
    jmp     .test_flush
.fail_hmac:
    TEST_FAIL

    ; ═══════════════════════════════════════════════════════════════
    ; 14. FlushContext (primary handle)
    ; ═══════════════════════════════════════════════════════════════
.test_flush:
    mov     rsi, str_flush
    PRINT_STR
    er_check_zero r12d, .skip_flush
    mov     rdi, cmd_buf
    mov     esi, r12d
    call    er_tpm_flush_context
    er_check_zero rax, .fail_flush
    mov     esi, TPM_CMD_FLUSH_CONTEXT_LEN
    CRB_SEND_CHECK
    jz      .fail_flush
    TEST_PASS
    jmp     .test_flush2
.skip_flush:
    TEST_SKIP
    jmp     .test_flush2
.fail_flush:
    TEST_FAIL

.test_flush2:
    er_check_zero r13d, .skip_flush2
    mov     rdi, cmd_buf
    mov     esi, r13d
    call    er_tpm_flush_context
    er_check_zero rax, .fail_flush2
    mov     esi, TPM_CMD_FLUSH_CONTEXT_LEN
    CRB_SEND_CHECK
    jz      .fail_flush2
    jmp     .skip_flush2
.fail_flush2:
    TEST_FAIL
.skip_flush2:

    ; ═══════════════════════════════════════════════════════════════
    ; 15. Shutdown(SU_CLEAR)
    ; ═══════════════════════════════════════════════════════════════
.test_shutdown:
    mov     rsi, str_shut
    PRINT_STR
    mov     rdi, cmd_buf
    xor     esi, esi
    call    er_tpm_shutdown
    er_check_zero rax, .fail_shutdown
    mov     esi, TPM_CMD_SHUTDOWN_LEN
    CRB_SEND_CHECK
    jz      .fail_shutdown
    TEST_PASS
    jmp     .done

.fail_shutdown:
    TEST_FAIL

    ; ═══════════════════════════════════════════════════════════════
    ; Summary
    ; ═══════════════════════════════════════════════════════════════
.done:
    call    .crlf
    mov     edx, dword [rel pass_ctr]
    mov     ecx, dword [rel test_ctr]
    cmp     edx, ecx
    je      .all_pass
    mov     rdi, COM1_PORT
    mov     rsi, str_fail_all
    call    er_serial_puts
    jmp     .print_count
.all_pass:
    mov     rdi, COM1_PORT
    mov     rsi, str_pass
    call    er_serial_puts
.print_count:
    mov     rdi, COM1_PORT
    mov     esi, dword [rel pass_ctr]
    call    er_serial_putdec32
    mov     rdi, COM1_PORT
    mov     rsi, str_slash
    call    er_serial_puts
    mov     rdi, COM1_PORT
    mov     esi, dword [rel test_ctr]
    call    er_serial_putdec32
    call    .crlf

    call    er_halt
    er_pop_ret rbx, r12, r13, r14, r15

; ─── Internal helpers ──────────────────────────────────────────────
.crlf:
    push    rsi
    mov     rdi, COM1_PORT
    mov     rsi, str_crlf
    call    er_serial_puts
    pop     rsi
    ret
