; EdgeRun TPM2 wire protocol — command/response buffer building and parsing
;
; All multi-byte integers in TPM2 are big-endian.
; Functions follow System V AMD64 ABI.
;
; HOSTED_TEST mode: command buffer writes are captured to a static buffer
; for test verification (same pattern as serial.asm).

%include "x86_64/macros.inc"

; ─── TPM2 protocol constants ──────────────────────────────────────────

; Tags
%define TPM_ST_NO_SESSIONS      0x8001
%define TPM_ST_SESSIONS          0x8002

; Response codes
%define TPM_RC_SUCCESS          0x00000000

; Command codes
%define TPM_CC_STARTUP          0x00000144
%define TPM_CC_GET_RANDOM       0x0000017b
%define TPM_CC_GET_CAPABILITY   0x0000017a
%define TPM_CC_SHUTDOWN         0x00000145

; Startup types
%define TPM_SU_CLEAR            0x0000
%define TPM_SU_STATE            0x0001

; Capability types
%define TPM_CAP_ALGS            0x00000000
%define TPM_CAP_COMMANDS        0x00000002
%define TPM_CAP_TPM_PROPERTIES  0x00000006

; Algorithm IDs
%define TPM_ALG_SHA256          0x000b
%define TPM_ALG_HMAC            0x0005
%define TPM_ALG_KEYEDHASH       0x0008
%define TPM_ALG_ECC             0x0023
%define TPM_ALG_ECDH            0x0019
%define TPM_ALG_ECDSA           0x0018
%define TPM_ALG_AES             0x0006
%define TPM_ALG_SYMCIPHER       0x0025
%define TPM_ALG_NULL            0x0010

; ECC curves
%define TPM_ECC_NIST_P256       0x0003

; Handle values
%define TPM_RH_OWNER            0x40000001
%define TPM_RH_NULL             0x40000007
%define TPM_RH_ENDORSEMENT      0x4000000b

; Object attributes
%define TPM_OA_FIXED_TPM        0x00000002
%define TPM_OA_FIXED_PARENT     0x00000010
%define TPM_OA_SENSITIVE_DATA_ORIGIN 0x00000020
%define TPM_OA_USER_WITH_AUTH   0x00000040
%define TPM_OA_NODA             0x00000400
%define TPM_OA_SIGN_ENCRYPT     0x00040000
%define TPM_OA_DECRYPT          0x00020000

; Protocol sizes
%define TPM_HEADER_LEN          10
%define TPM_SHA256_DIGEST_LEN   32
%define TPM_P256_PUBLIC_KEY_LEN 64
%define TPM_CRB_MAX_BUFFER_SIZE 4096

; Command size constants
%define TPM_CMD_STARTUP_LEN     12
%define TPM_CMD_GET_RANDOM_LEN  12
%define TPM_CMD_GET_CAP_LEN     22
%define TPM_CMD_SHUTDOWN_LEN    12

; ─── HOSTED_TEST capture buffer ───────────────────────────────────────
%ifdef HOSTED_TEST
section .bss
global er_tpm_tx_buffer, er_tpm_tx_count, er_tpm_rx_buffer, er_tpm_rx_size
er_tpm_tx_buffer: resb 4096
er_tpm_tx_count:  resq 1
er_tpm_rx_buffer: resb 4096
er_tpm_rx_size:   resq 1
%endif

; ==================================================================
; Helper: store big-endian u16 at address in rdi
; void _tpm_put_be16(void* addr, uint16_t value)
; =================================================================
er_fn _tpm_put_be16
    mov     [rdi + 0], sil      ; high byte
    shr     esi, 8
    mov     [rdi + 1], sil      ; low byte
    ret

; ==================================================================
; Helper: store big-endian u32 at address in rdi
; void _tpm_put_be32(void* addr, uint32_t value)
; =================================================================
er_fn _tpm_put_be32
    mov     [rdi + 0], sil      ; byte 3 (MSB)
    shr     esi, 8
    mov     [rdi + 1], sil      ; byte 2
    shr     esi, 8
    mov     [rdi + 2], sil      ; byte 1
    shr     esi, 8
    mov     [rdi + 3], sil      ; byte 0 (LSB)
    ret

; ==================================================================
; Helper: load big-endian u16 from address in rdi
; uint16_t _tpm_get_be16(const void* addr)
; =================================================================
er_fn _tpm_get_be16
    movzx   eax, byte [rdi]
    shl     eax, 8
    movzx   ecx, byte [rdi + 1]
    or      eax, ecx
    ret

; ==================================================================
; Helper: load big-endian u32 from address in rdi
; uint32_t _tpm_get_be32(const void* addr)
; =================================================================
er_fn _tpm_get_be32
    movzx   eax, byte [rdi]
    shl     eax, 8
    movzx   ecx, byte [rdi + 1]
    or      eax, ecx
    shl     eax, 8
    movzx   ecx, byte [rdi + 2]
    or      eax, ecx
    shl     eax, 8
    movzx   ecx, byte [rdi + 3]
    or      eax, ecx
    ret

; ==================================================================
; Build TPM2 command header: tag, size, commandCode
; rdi = output buffer (must be >= size bytes)
; esi = tag (u16, big-endian)
; edx = total command size (u32)
; ecx = command code (u32)
; Returns: rax = buffer pointer (same as rdi), or 0 on error
; =================================================================
er_fn er_tpm_header_build
    ; Validate size >= header and buffer is non-null
    test    rdi, rdi
    jz      .err
    cmp     edx, TPM_HEADER_LEN
    jb      .err

    push    rdi
    push    rcx
    push    rdx

    ; Store tag (16-bit big-endian)
    mov     byte [rdi + 0], sil
    shr     esi, 8
    mov     byte [rdi + 1], sil

    ; Store command size (32-bit big-endian)
    mov     eax, edx
    mov     byte [rdi + 2], al
    shr     eax, 8
    mov     byte [rdi + 3], al
    shr     eax, 8
    mov     byte [rdi + 4], al
    shr     eax, 8
    mov     byte [rdi + 5], al

    ; Store command code (32-bit big-endian)
    pop     rdx
    pop     rax
    mov     byte [rdi + 6], al
    shr     eax, 8
    mov     byte [rdi + 7], al
    shr     eax, 8
    mov     byte [rdi + 8], al
    shr     eax, 8
    mov     byte [rdi + 9], al

    pop     rax             ; return original buffer pointer
    ret

.err:
    xor     eax, eax
    ret

; ==================================================================
; Build TPM2 Startup(SU_CLEAR) command
; rdi = output buffer (must be >= 12 bytes)
; Returns: rax = buffer pointer, or 0 on error
; =================================================================
er_fn er_tpm_startup
    test    rdi, rdi
    jz      .err

%ifdef HOSTED_TEST
    push    rdi
%endif
    mov     esi, TPM_ST_NO_SESSIONS
    mov     edx, TPM_CMD_STARTUP_LEN
    mov     ecx, TPM_CC_STARTUP
    call    er_tpm_header_build
    test    rax, rax
    jz      .err

    ; Startup type = TPM_SU_CLEAR at offset 10
    mov     byte [rax + 10], 0x00
    mov     byte [rax + 11], 0x00

%ifdef HOSTED_TEST
    pop     rdi
    call    _tpm_capture_tx
%endif
    ret

.err:
    xor     eax, eax
    ret

; ==================================================================
; Build TPM2 GetRandom(n) command
; rdi = output buffer
; esi = number of bytes requested (u16)
; Returns: rax = buffer pointer, or 0 on error
; =================================================================
er_fn er_tpm_get_random
    test    rdi, rdi
    jz      .err
    test    esi, esi
    jz      .err

%ifdef HOSTED_TEST
    push    rdi
    push    rsi
%endif
    mov     edx, TPM_CMD_GET_RANDOM_LEN
    mov     ecx, TPM_CC_GET_RANDOM
    call    er_tpm_header_build
    test    rax, rax
    jz      .err

    ; Store bytes requested at offset 10
    pop     rcx        ; esi value
    mov     byte [rax + 10], cl
    shr     ecx, 8
    mov     byte [rax + 11], cl

%ifdef HOSTED_TEST
    pop     rdi
    call    _tpm_capture_tx
%endif
    ret

.err:
    xor     eax, eax
    ret

; ==================================================================
; Build TPM2 GetCapability(capability, property, property_count) command
; rdi = output buffer
; esi = capability (u32)
; edx = property (u32)
; ecx = property_count (u32)
; Returns: rax = buffer pointer, or 0 on error
; =================================================================
er_fn er_tpm_get_capability
    test    rdi, rdi
    jz      .err
    test    ecx, ecx
    jz      .err

    push    rcx
    push    rdx
    push    rsi
%ifdef HOSTED_TEST
    push    rdi
%endif

    mov     esi, TPM_ST_NO_SESSIONS
    mov     edx, TPM_CMD_GET_CAP_LEN
    mov     ecx, TPM_CC_GET_CAPABILITY
    call    er_tpm_header_build
    test    rax, rax
    jz      .err_pop3

    ; Offset 10: capability
    pop     rcx
    mov     byte [rax + 10], cl
    shr     ecx, 8
    mov     byte [rax + 11], cl
    shr     ecx, 8
    mov     byte [rax + 12], cl
    shr     ecx, 8
    mov     byte [rax + 13], cl

    ; Offset 14: property
    pop     rcx
    mov     byte [rax + 14], cl
    shr     ecx, 8
    mov     byte [rax + 15], cl
    shr     ecx, 8
    mov     byte [rax + 16], cl
    shr     ecx, 8
    mov     byte [rax + 17], cl

    ; Offset 18: property_count
    pop     rcx
    mov     byte [rax + 18], cl
    shr     ecx, 8
    mov     byte [rax + 19], cl
    shr     ecx, 8
    mov     byte [rax + 20], cl
    shr     ecx, 8
    mov     byte [rax + 21], cl

%ifdef HOSTED_TEST
    pop     rdi
    push    rax
    call    _tpm_capture_tx
    pop     rax
%endif
    ret

.err_pop3:
    add     rsp, 24     ; pop rsi, rdx, rcx
.err:
    xor     eax, eax
    ret

; ==================================================================
; Parse response code from TPM2 response buffer
; rdi = response buffer
; esi = response length
; Returns: rax = response code (0 = success), or 0xFFFFFFFC on error
; =================================================================
er_fn er_tpm_response_code
    cmp     esi, TPM_HEADER_LEN
    jb      .err

    ; Verify claimed size matches actual
    mov     eax, esi
    push    rax
    push    rdi
    add     rdi, 2
    call    _tpm_get_be32
    pop     rdi
    pop     rcx
    cmp     eax, ecx
    jne     .err

    ; Read response code at offset 6
    add     rdi, 6
    call    _tpm_get_be32
    ret

.err:
    mov     eax, 0xFFFFFFFC
    ret

; ==================================================================
; Check if TPM2 response is success
; rdi = response buffer
; esi = response length
; Returns: rax = 1 if success, 0 otherwise
; =================================================================
er_fn er_tpm_response_success
    call    er_tpm_response_code
    cmp     eax, TPM_RC_SUCCESS
    sete    al
    movzx   eax, al
    ret

; ==================================================================
; Parse random bytes from GetRandom response
; rdi = response buffer
; esi = response length
; rdx = output buffer for random bytes
; ecx = output buffer size
; Returns: rax = number of bytes written, or 0 on error
; =================================================================
er_fn er_tpm_parse_get_random
    ; Validate response success
    push    rcx
    push    rdx
    push    rsi
    push    rdi
    call    er_tpm_response_success
    test    eax, eax
    jz      .err_pop4

    pop     rdi
    pop     rsi
    pop     rdx
    pop     rcx

    ; Check minimum response size
    cmp     esi, 12
    jb      .err

    ; Read random length at offset 10
    push    rdi
    push    rcx
    push    rdx
    add     rdi, 10
    call    _tpm_get_be16
    pop     rdi        ; rdx = output buffer
    pop     rcx        ; ecx = output buffer size

    ; Validate length fits both response and output
    cmp     eax, esi - 12
    ja      .err_now2
    cmp     eax, ecx
    ja      .err_now2

    ; Copy random bytes (offset 12) to output buffer
    mov     ecx, eax        ; ecx = count
    pop     rsi             ; rsi = response buffer
    add     rsi, 12         ; rsi = source
    push    rcx             ; save count for return
    rep     movsb

    pop     rax             ; return count
    ret

.err_now2:
    add     rsp, 8
.err_pop4:
    add     rsp, 32
.err:
    xor     eax, eax
    ret

; ==================================================================
; Parse algorithm capability response — check for specific algorithm
; rdi = response buffer
; esi = response length
; edx = algorithm ID to check (u16)
; Returns: rax = 1 if algorithm found, 0 otherwise
; =================================================================
er_fn er_tpm_has_algorithm
    push    rdx
    push    rsi
    push    rdi
    call    er_tpm_response_success
    test    eax, eax
    jz      .err_pop3

    pop     rdi
    pop     rsi
    pop     rdx

    ; Response layout:
    ;   [0-9] = header (10 bytes)
    ;   [10] = 1 byte parameter start (0x00 for no sessions)
    ;   [11-14] = capability (4 bytes, must match TPM_CAP_ALGS)
    ;   [15-18] = count (4 bytes)
    ;   [19..] = algorithm entries (6 bytes each: 2 alg_id + 4 reserved)

    cmp     esi, 19
    jb      .err

    push    rdx             ; save algorithm to find
    push    rdi
    push    rsi

    ; Verify capability field = TPM_CAP_ALGS
    add     rdi, 11
    call    _tpm_get_be32
    cmp     eax, TPM_CAP_ALGS
    jne     .err_pop4

    ; Read count
    add     rdi, 4          ; past capability (was at 11, now at 15)
    call    _tpm_get_be32
    mov     ecx, eax        ; ecx = number of entries

    ; Entry offset = 19 (header 10 + parameter 1 + capability 4 + count 4)
    pop     rsi             ; rsi = response pointer
    add     rsi, 19         ; rsi = first algorithm entry
    pop     rdi             ; restore response pointer (pop pop sequence)
    pop     rdx             ; rdx = algorithm to find

.loop:
    test    ecx, ecx
    jz      .not_found

    ; Read algorithm ID from entry
    push    rdx
    push    rcx
    mov     rdi, rsi
    call    _tpm_get_be16
    mov     dx, ax
    pop     rcx
    pop     rdi             ; rdi = algorithm to find
    cmp     dx, di
    je      .found

    ; Next entry (6 bytes each)
    add     rsi, 6
    dec     ecx
    jmp     .loop

.found:
    mov     eax, 1
    ret

.not_found:
    xor     eax, eax
    ret

.err_pop4:
    add     rsp, 32
    jmp     .err
.err_pop3:
    add     rsp, 24
.err:
    xor     eax, eax
    ret

; ==================================================================
; Parse command capability response — check for specific command
; rdi = response buffer
; esi = response length
; edx = command code to check (u32)
; Returns: rax = 1 if command found, 0 otherwise
; =================================================================
er_fn er_tpm_has_command
    push    rdx
    push    rsi
    push    rdi
    call    er_tpm_response_success
    test    eax, eax
    jz      .err_pop3

    pop     rdi
    pop     rsi
    pop     rdx

    cmp     esi, 19
    jb      .err

    push    rdx
    push    rdi
    push    rsi

    ; Verify capability = TPM_CAP_COMMANDS
    add     rdi, 11
    call    _tpm_get_be32
    cmp     eax, TPM_CAP_COMMANDS
    jne     .err_pop4

    ; Read count
    add     rdi, 4
    call    _tpm_get_be32
    mov     ecx, eax

    pop     rsi
    add     rsi, 19
    pop     rdi
    pop     rdx

.loop:
    test    ecx, ecx
    jz      .not_found

    push    rdx
    push    rcx
    mov     rdi, rsi
    call    _tpm_get_be32
    and     eax, 0x0000FFFF    ; low 16 bits = command index
    mov     ecx, eax
    pop     rdi
    pop     rsi
    cmp     rcx, rsi
    je      .found

    add     rsi, 4
    dec     ecx
    jmp     .loop

.found:
    mov     eax, 1
    ret

.not_found:
    xor     eax, eax
    ret

.err_pop4:
    add     rsp, 32
.err_pop3:
    add     rsp, 24
.err:
    xor     eax, eax
    ret

; ─── HOSTED_TEST capture helper ───────────────────────────────────────
%ifdef HOSTED_TEST
_tpm_capture_tx:
    ; Capture command buffer for test verification.
    ; rdi = command buffer pointer (uses er_tpm_tx_count as size).
    ; The size was encoded at offset 2-5.
    push    rsi
    push    rcx
    push    rdi

    ; Read command size from header offset 2
    add     rdi, 2
    call    _tpm_get_be32
    mov     ecx, eax            ; ecx = command size
    pop     rsi                 ; rsi = source (original command pointer)

    push    rcx
    mov     rdi, er_tpm_tx_buffer
    mov     rsi, [er_tpm_tx_count]
    add     rdi, rsi
    pop     rcx

    rep     movsb

    mov     [er_tpm_tx_count], rdi
    sub     [er_tpm_tx_count], rsi
    pop     rcx
    pop     rsi
    ret
%endif
