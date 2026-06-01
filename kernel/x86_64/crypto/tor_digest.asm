; EdgeRun Tor digest helpers — SHA-256 and HMAC-SHA256 via TPM
; Freestanding, no external dependencies beyond TPM primitives.
;
; Uses er_tpm_hash_sha256 for the underlying SHA-256.
; HMAC-SHA256 per RFC 2104: HMAC(K,m) = SHA256(K_opad || SHA256(K_ipad || m))

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/tpm/tpm_constants.inc"

extern er_tpm_hash_sha256
extern er_tpm_crb_transfer
extern er_tpm_parse_sha256_digest
extern er_memcpy
extern er_memset

SECTION .bss

; TPM command and response buffers
tor_digest_cmd: resb  512
tor_digest_rsp: resb  128
tor_digest_out: resb  32
tor_digest_work: resb 512

SECTION .text

; ==================================================================
; _tor_digest_tpm_sha256 — one-shot TPM SHA-256 wrapper
; rdi = data, rsi = data_len, rdx = out[32]
; Returns rax = 32 on success, 0 on error
;
; Builds command buffer, sends via CRB, parses response.
; ==================================================================
er_fn _tor_digest_tpm_sha256
    er_push rbx, r12, r13

    mov     r12, rdi        ; data
    mov     r13d, esi       ; data_len
    mov     rbx, rdx        ; out

    ; Build TPM Hash command
    mov     rdi, tor_digest_cmd
    mov     rsi, r12
    mov     edx, r13d
    mov     ecx, TPM_RH_NULL
    call    er_tpm_hash_sha256
    er_check_zero rax, .err

    ; Compute command size
    sub     rax, tor_digest_cmd
    mov     esi, eax        ; cmd_size

    ; Send via CRB and receive response
    mov     rdi, tor_digest_cmd
    mov     rdx, tor_digest_rsp
    mov     ecx, 128
    call    er_tpm_crb_transfer
    er_check_zero rax, .err

    ; Parse digest from response
    mov     edi, tor_digest_rsp
    mov     esi, eax        ; response length
    mov     rdx, rbx        ; output
    call    er_tpm_parse_sha256_digest
    er_check_zero rax, .err

    mov     eax, 32
    er_pop_ret rbx, r12, r13

.err:
    xor     eax, eax
    er_pop_ret rbx, r12, r13

; ==================================================================
; er_tor_sha256 — compute SHA-256 of data via TPM
; rdi = data, rsi = data_len, rdx = out[32]
; Returns rax = 32 on success, 0 on error
; ==================================================================
er_fn er_tor_sha256
    jmp     _tor_digest_tpm_sha256

; ==================================================================
; er_tor_hmac_sha256 — compute HMAC-SHA256 via TPM
; rdi = key, rsi = key_len, rdx = msg, rcx = msg_len, r8 = out[32]
; Returns rax = 32 on success, 0 on error
;
; If key_len > 64, key is compressed via SHA-256 first.
; ==================================================================
er_fn er_tor_hmac_sha256
    er_push rbx, r12, r13, r14, r15

    mov     r12, rdi        ; key
    mov     r13d, esi       ; key_len
    mov     r14, rdx        ; msg
    mov     r15d, ecx       ; msg_len
    mov     rbx, r8         ; out

    ; If key_len > 64, compress key first via SHA-256
    cmp     r13d, 64
    jbe     .key_ok

    ; Compress key to 32 bytes
    mov     rdi, r12
    mov     esi, r13d
    mov     rdx, tor_digest_out
    call    _tor_digest_tpm_sha256
    er_check_zero eax, .err

    mov     r12, tor_digest_out
    mov     r13d, 32

.key_ok:
    ; Build K_block: key padded with zeros to 64 bytes
    mov     rdi, tor_digest_work
    mov     rsi, r12
    mov     edx, r13d
    call    er_memcpy
    ; Zero-pad to 64 bytes
    mov     edi, r13d
    add     rdi, tor_digest_work
    xor     eax, eax
    mov     ecx, 64
    sub     ecx, r13d
    rep     stosb

    ; Compute K_ipad = K_block XOR 0x36 and build inner input
    mov     rdi, tor_digest_work
    mov     ecx, 64
.xor_ipad:
    xor     byte [rdi], 0x36
    inc     rdi
    dec     ecx
    jnz     .xor_ipad

    ; Append msg to K_ipad in work buffer (K_ipad starts at tor_digest_work)
    mov     edi, tor_digest_work
    add     edi, 64
    mov     rsi, r14
    mov     edx, r15d
    call    er_memcpy

    ; inner = SHA256(K_ipad || msg) — total = 64 + msg_len bytes
    mov     rdi, tor_digest_work
    lea     esi, [r15d + 64]
    mov     rdx, tor_digest_out
    call    _tor_digest_tpm_sha256
    er_check_zero eax, .err

    ; Rebuild K_block (key padded to 64 bytes)
    mov     rdi, tor_digest_work
    mov     rsi, r12
    mov     edx, r13d
    call    er_memcpy
    mov     edi, r13d
    add     rdi, tor_digest_work
    xor     eax, eax
    mov     ecx, 64
    sub     ecx, r13d
    rep     stosb

    ; Compute K_opad = K_block XOR 0x5c
    mov     rdi, tor_digest_work
    mov     ecx, 64
.xor_opad:
    xor     byte [rdi], 0x5c
    inc     rdi
    dec     ecx
    jnz     .xor_opad

    ; Append inner digest to K_opad
    mov     edi, tor_digest_work
    add     edi, 64
    mov     rsi, tor_digest_out
    mov     edx, 32
    call    er_memcpy

    ; outer = SHA256(K_opad || inner_digest) — total = 96 bytes
    mov     rdi, tor_digest_work
    mov     esi, 96
    mov     rdx, rbx
    call    _tor_digest_tpm_sha256
    er_check_zero eax, .err

    mov     eax, 32
    er_pop_ret rbx, r12, r13, r14, r15

.err:
    xor     eax, eax
    er_pop_ret rbx, r12, r13, r14, r15
