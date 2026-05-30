; EdgeRun TPM2 wire protocol — command/response buffer building and parsing
;
; All multi-byte integers in TPM2 are big-endian.
; Functions follow System V AMD64 ABI.
;
; HOSTED_TEST mode: command buffer writes are captured to a static buffer
; for test verification (same pattern as serial.asm).

%include "x86_64/macros.inc"
%include "x86_64/tpm/tpm_constants.inc"

; ─── TPM2 protocol constants (local-only) ──────────────────────────
%define TPM_CRB_MAX_BUFFER_SIZE 4096

; ─── HOSTED_TEST capture buffer ───────────────────────────────────────

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
    mov     eax, esi
    xchg    al, ah
    mov     [rdi], ax

    ; Store command size (32-bit big-endian)
    mov     eax, edx
    bswap   eax
    mov     [rdi + 2], eax

    ; Store command code (32-bit big-endian)
    pop     rdx
    pop     rax
    bswap   eax
    mov     [rdi + 6], eax

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

    mov     esi, TPM_ST_NO_SESSIONS
    mov     edx, TPM_CMD_STARTUP_LEN
    mov     ecx, TPM_CC_STARTUP
    call    er_tpm_header_build
    test    rax, rax
    jz      .err

    ; Startup type = TPM_SU_CLEAR at offset 10
    mov     byte [rax + 10], 0x00
    mov     byte [rax + 11], 0x00

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

    mov     r8d, esi            ; save bytes_req
    mov     esi, TPM_ST_NO_SESSIONS
    mov     edx, TPM_CMD_GET_RANDOM_LEN
    mov     ecx, TPM_CC_GET_RANDOM
    call    er_tpm_header_build
    test    rax, rax
    jz      .err

    ; Store bytes requested at offset 10 (big-endian)
    mov     byte [rax + 11], r8b    ; LSB at offset 11
    shr     r8d, 8
    mov     byte [rax + 10], r8b    ; MSB at offset 10

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

    mov     esi, TPM_ST_NO_SESSIONS
    mov     edx, TPM_CMD_GET_CAP_LEN
    mov     ecx, TPM_CC_GET_CAPABILITY
    call    er_tpm_header_build
    test    rax, rax
    jz      .err_pop3

    ; Offset 10: capability
    pop     rcx
    bswap   ecx
    mov     [rax + 10], ecx

    ; Offset 14: property
    pop     rcx
    bswap   ecx
    mov     [rax + 14], ecx

    ; Offset 18: property_count
    pop     rcx
    bswap   ecx
    mov     [rax + 18], ecx

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
    mov     edx, esi
    sub     edx, 12
    cmp     eax, edx
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

    push    rdx
    push    rsi
    push    rdi

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

    push    rdx
    push    rcx
    mov     rdi, rsi
    call    _tpm_get_be16
    pop     rcx
    pop     rdi
    cmp     ax, di
    je      .found

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
    add     rsp, 24
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
    push    rsi
    push    rdi

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
    pop     rcx
    pop     rdi
    cmp     ax, di
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
    add     rsp, 24
.err_pop3:
    add     rsp, 24
.err:
    xor     eax, eax
    ret

; ─── HOSTED_TEST capture helper ───────────────────────────────────────
; ==================================================================
; Internal: write big-endian u32 at [rdi], return rdi+4
; rdi = ptr, esi = value → rax = rdi+4
; =================================================================
er_fn _tpm_put_be32_adv
    mov     eax, esi
    bswap   eax
    mov     [rdi], eax
    lea     rax, [rdi + 4]
    ret

; ==================================================================
; Internal: write big-endian u16 at [rdi], return rdi+2
; rdi = ptr, esi = value → rax = rdi+2
; =================================================================
er_fn _tpm_put_be16_adv
    mov     eax, esi
    xchg    al, ah
    mov     [rdi], ax
    lea     rax, [rdi + 2]
    ret

; ==================================================================
; Internal: write handle + password auth area (17 bytes)
; rdi = buf, esi = handle → rax = buf+17
; =================================================================
er_fn _tpm_write_auth_handle
    mov     eax, esi
    bswap   eax
    mov     [rdi], eax
    mov     dword [rdi + 4], 0x09000000
    mov     dword [rdi + 8], 0x09000040
    mov word [rdi + 12], 0x0000
    mov     byte [rdi + 14], 0x00
    mov word [rdi + 15], 0x0000
    lea     rax, [rdi + 17]
    ret

; ==================================================================
; Internal: write TPM2B (u16 len BE + data)
; rdi = buf, rsi = data, edx = data_len → rax = buf+2+data
; =================================================================
er_fn _tpm_write_tpm2b
    mov     eax, edx
    xchg    al, ah
    mov     [rdi], ax
    add     rdi, 2
    mov     rcx, rdx
    rep     movsb
    mov     rax, rdi
    ret

; ==================================================================
; er_tpm_shutdown — TPM2 Shutdown(sType)
; rdi = buf, esi = shutdown_type → rax = buf, 0 on error
; =================================================================
er_fn er_tpm_shutdown
    test    rdi, rdi
    jz      .err
    push    r12
    mov     r12d, esi            ; r12 = shutdown_type
    mov     esi, TPM_ST_NO_SESSIONS
    mov     edx, TPM_CMD_SHUTDOWN_LEN
    mov     ecx, TPM_CC_SHUTDOWN
    call    er_tpm_header_build
    test    rax, rax
    jz      .err_pop2
    mov     ecx, r12d
    mov     byte [rax + 10], ch
    mov     byte [rax + 11], cl
    pop     r12
    ret
.err_pop2:
    pop     r12
.err:
    xor     eax, eax
    ret

; ==================================================================
; er_tpm_flush_context — TPM2 FlushContext(handle)
; rdi = buf, esi = handle → rax = buf, 0 on error
; =================================================================
er_fn er_tpm_flush_context
    test    rdi, rdi
    jz      .err
    test    esi, esi
    jz      .err
    push    r12
    mov     r12d, esi
    mov     esi, TPM_ST_NO_SESSIONS
    mov     edx, TPM_CMD_FLUSH_CONTEXT_LEN
    mov     ecx, TPM_CC_FLUSH_CONTEXT
    call    er_tpm_header_build
    test    rax, rax
    jz      .err_pop2
    mov     ecx, r12d
    bswap   ecx
    mov     [rax + 10], ecx
    pop     r12
    ret
.err_pop2:
    pop     r12
.err:
    xor     eax, eax
    ret

; ==================================================================
; er_tpm_read_public — TPM2 ReadPublic(handle)
; rdi = buf, esi = handle → rax = buf, 0 on error
; =================================================================
er_fn er_tpm_read_public
    test    rdi, rdi
    jz      .err
    test    esi, esi
    jz      .err
    push    r12
    mov     r12d, esi
    mov     esi, TPM_ST_NO_SESSIONS
    mov     edx, TPM_CMD_READ_PUBLIC_LEN
    mov     ecx, TPM_CC_READ_PUBLIC
    call    er_tpm_header_build
    test    rax, rax
    jz      .err_pop2
    mov     ecx, r12d
    bswap   ecx
    mov     [rax + 10], ecx
    pop     r12
    ret
.err_pop2:
    pop     r12
.err:
    xor     eax, eax
    ret

; ==================================================================
; er_tpm_hash_sha256 — TPM2 Hash(data, hierarchy) SHA-256
; rdi = buf, rsi = data, edx = data_len, ecx = hierarchy → rax = buf, 0
; =================================================================
er_fn er_tpm_hash_sha256
    test    rdi, rdi
    jz      .err
    test    edx, edx
    jz      .err
    push    rbx
    push    r12
    push    r13
    mov     r12d, ecx            ; hierarchy
    mov     rbx, rsi             ; data ptr
    mov     r13d, edx            ; data len
    ; Command size = header(10) + TPM2B(2+data) + hashAlg(2) + hierarchy(4)
    lea     edx, [r13 + TPM_CMD_HASH_FIXED_LEN]
    mov     esi, TPM_ST_NO_SESSIONS
    mov     ecx, TPM_CC_HASH
    call    er_tpm_header_build
    test    rax, rax
    jz      .err_pop3
    ; [10..]: TPM2B data at offset 10 (no handle area — hierarchy is parameter 3 at end)
    lea     rdi, [rax + 10]
    mov     rsi, rbx
    mov     edx, r13d
    call    _tpm_write_tpm2b
    ; rax = position after TPM2B = 10 + 2 + data_len
    ; hash_alg = TPM_ALG_SHA256 (byte-swapped for BE wire format)
    mov     word [rax], 0x0B00
    ; hierarchy = TPMI_RH_HIERARCHY as parameter 3 (after hashAlg)
    mov     ecx, r12d
    bswap   ecx
    mov     [rax + 2], ecx
    pop     r13
    pop     r12
    pop     rbx
    ret
.err_pop3:
    pop     r13
    pop     r12
    pop     rbx
.err:
    xor     eax, eax
    ret

; ==================================================================
; er_tpm_hash_sequence_start — TPM2 HashSequenceStart SHA-256
; rdi = buf → rax = buf, 0 on error
; =================================================================
er_fn er_tpm_hash_sequence_start
    test    rdi, rdi
    jz      .err
    mov     esi, TPM_ST_NO_SESSIONS
    mov     edx, TPM_CMD_HASH_SEQUENCE_START_LEN
    mov     ecx, TPM_CC_HASH_SEQUENCE_START
    call    er_tpm_header_build
    test    rax, rax
    jz      .err
    ; authHandle = TPM_RH_NULL at offset 10 (4 BE)
    mov     dword [rax + 10], 0x07000040
    ; hash_alg = TPM_ALG_SHA256 at offset 14 (2 BE, byte-swapped)
    mov     word [rax + 14], 0x0B00
    ; hierarchy = TPM_RH_NULL at offset 16 (4 BE)
    mov     dword [rax + 16], 0x07000040
    ret
.err:
    xor     eax, eax
    ret

; ==================================================================
; er_tpm_sequence_update — TPM2 SequenceUpdate(handle, data)
; rdi = buf, esi = handle, rdx = data, ecx = data_len → rax = buf, 0
; =================================================================
er_fn er_tpm_sequence_update
    test    rdi, rdi
    jz      .err
    test    esi, esi
    jz      .err
    test    ecx, ecx
    jz      .err
    push    rbx
    push    r12
    push    r13
    mov     r12d, esi
    mov     rbx, rdx
    mov     r13d, ecx
    lea     edx, [r13 + TPM_CMD_SEQ_UPDATE_FIXED_LEN]
    mov     esi, TPM_ST_SESSIONS
    mov     ecx, TPM_CC_SEQUENCE_UPDATE
    call    er_tpm_header_build
    test    rax, rax
    jz      .err_pop3
    mov     rdi, rax
    add     rdi, TPM_HEADER_LEN
    mov     esi, r12d
    call    _tpm_write_auth_handle
    mov     rsi, rbx
    mov     edx, r13d
    call    _tpm_write_tpm2b
    pop     r13
    pop     r12
    pop     rbx
    ret
.err_pop3:
    pop     r13
    pop     r12
    pop     rbx
.err:
    xor     eax, eax
    ret

; ==================================================================
; er_tpm_sequence_complete — TPM2 SequenceComplete(handle, data, hierarchy)
; rdi = buf, esi = handle, rdx = data, ecx = data_len, r8d = hierarchy
; → rax = buf, 0
; =================================================================
er_fn er_tpm_sequence_complete
    test    rdi, rdi
    jz      .err
    test    esi, esi
    jz      .err
    push    rbx
    push    r12
    push    r13
    push    r14
    mov     r12d, esi
    mov     rbx, rdx
    mov     r13d, ecx
    mov     r14d, r8d
    lea     edx, [r13 + TPM_CMD_SEQ_COMPLETE_FIXED_LEN]
    mov     esi, TPM_ST_SESSIONS
    mov     ecx, TPM_CC_SEQUENCE_COMPLETE
    call    er_tpm_header_build
    test    rax, rax
    jz      .err_pop4
    mov     rdi, rax
    add     rdi, TPM_HEADER_LEN
    mov     esi, r12d
    call    _tpm_write_auth_handle
    mov     rsi, rbx
    mov     edx, r13d
    call    _tpm_write_tpm2b
    ; hierarchy (4 BE)
    mov     ecx, r14d
    bswap   ecx
    mov     [rax], ecx
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret
.err_pop4:
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
.err:
    xor     eax, eax
    ret

; ==================================================================
; er_tpm_hmac_sha256 — TPM2 HMAC(key_handle, data) SHA-256
; rdi = buf, esi = handle, rdx = data, ecx = data_len → rax = buf, 0
; =================================================================
er_fn er_tpm_hmac_sha256
    test    rdi, rdi
    jz      .err
    test    esi, esi
    jz      .err
    test    ecx, ecx
    jz      .err
    push    rbx
    push    r12
    push    r13
    mov     r12d, esi
    mov     rbx, rdx
    mov     r13d, ecx
    lea     edx, [r13 + TPM_CMD_HMAC_FIXED_LEN]
    mov     esi, TPM_ST_SESSIONS
    mov     ecx, TPM_CC_HMAC
    call    er_tpm_header_build
    test    rax, rax
    jz      .err_pop3
    mov     rdi, rax
    add     rdi, TPM_HEADER_LEN
    mov     esi, r12d
    call    _tpm_write_auth_handle
    mov     rsi, rbx
    mov     edx, r13d
    call    _tpm_write_tpm2b
    mov word [rax], 0x0B00
    pop     r13
    pop     r12
    pop     rbx
    ret
.err_pop3:
    pop     r13
    pop     r12
    pop     rbx
.err:
    xor     eax, eax
    ret

; ==================================================================
; er_tpm_sign_p256_sha256 — TPM2 Sign(key, digest[32]) ECDSA P-256
; rdi = buf, esi = handle, rdx = digest → rax = buf, 0
; =================================================================
er_fn er_tpm_sign_p256_sha256
    test    rdi, rdi
    jz      .err
    test    esi, esi
    jz      .err
    test    rdx, rdx
    jz      .err
    push    rbx
    push    r12
    mov     r12d, esi
    mov     rbx, rdx
    mov     esi, TPM_ST_SESSIONS
    mov     edx, TPM_CMD_SIGN_LEN
    mov     ecx, TPM_CC_SIGN
    call    er_tpm_header_build
    test    rax, rax
    jz      .err_pop2
    mov     rdi, rax
    add     rdi, TPM_HEADER_LEN
    mov     esi, r12d
    call    _tpm_write_auth_handle
    mov     edx, TPM_SHA256_DIGEST_LEN
    mov     rsi, rbx
    call    _tpm_write_tpm2b
    ; TPMT_SIG_SCHEME: alg_ecdsa + alg_sha256
    mov word [rax], 0x1800
    mov word [rax + 2], 0x0B00
    ; TPMT_TK_HASHCHECK: st_hashcheck + rh_null + digest_len=0
    mov     byte [rax + 4], 0x80
    mov     byte [rax + 5], 0x24
    mov     byte [rax + 6], 0x40
    mov     byte [rax + 7], 0x00
    mov     byte [rax + 8], 0x00
    mov     byte [rax + 9], 0x07
    mov word [rax + 10], 0x0000
    pop     r12
    pop     rbx
    ret
.err_pop2:
    pop     r12
    pop     rbx
.err:
    xor     eax, eax
    ret

; ==================================================================
; er_tpm_verify_p256_sha256 — TPM2 VerifySignature(key, digest, sig_r, sig_s)
; rdi = buf, esi = handle, rdx = digest, rcx = sig_r, r8 = sig_s
; → rax = buf, 0
; =================================================================
er_fn er_tpm_verify_p256_sha256
    test    rdi, rdi
    jz      .err
    test    esi, esi
    jz      .err
    test    rdx, rdx
    jz      .err
    test    rcx, rcx
    jz      .err
    test    r8, r8
    jz      .err
    push    rbx
    push    r12
    push    r13
    push    r14
    mov     r12d, esi
    mov     rbx, rdx
    mov     r13, rcx
    mov     r14, r8
    mov     esi, TPM_ST_NO_SESSIONS
    mov     edx, TPM_CMD_VERIFY_SHA256_LEN
    mov     ecx, TPM_CC_VERIFY_SIGNATURE
    call    er_tpm_header_build
    test    rax, rax
    jz      .err_pop4
    mov     rdi, rax
    add     rdi, TPM_HEADER_LEN
    mov     esi, r12d
    call    _tpm_put_be32_adv
    mov     rsi, rbx
    mov     edx, TPM_SHA256_DIGEST_LEN
    call    _tpm_write_tpm2b
    mov word [rax], 0x1800
    mov word [rax + 2], 0x0B00
    add     rax, 4
    mov     rsi, r13
    mov     edx, TPM_P256_POINT_BYTES
    mov     rdi, rax
    call    _tpm_write_tpm2b
    mov     rsi, r14
    mov     edx, TPM_P256_POINT_BYTES
    call    _tpm_write_tpm2b
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret
.err_pop4:
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
.err:
    xor     eax, eax
    ret

; ==================================================================
; er_tpm_create_primary_p256 — TPM2 CreatePrimary P-256
; rdi = buf, esi = scheme, edx = crypto_attrs → rax = buf, 0
; =================================================================
er_fn er_tpm_create_primary_p256
    test    rdi, rdi
    jz      .err
    push    rbx
    push    r12
    mov     r12d, esi
    mov     ebx, edx
    ; Use TPM_ST_NO_SESSIONS matching tpm2-tools
    mov     esi, TPM_ST_NO_SESSIONS
    mov     edx, TPM_CMD_CREATE_PRIMARY_LEN
    mov     ecx, TPM_CC_CREATE_PRIMARY
    call    er_tpm_header_build
    test    rax, rax
    jz      .err_pop2

    mov     rdi, rax
    ; [10-13] primaryHandle = TPM_RH_ENDORSEMENT (4 BE)
    mov     dword [rdi + 10], 0x01000040

    ; ── TPM2B_SENSITIVE_CREATE: empty (size=0, no data) ────────────
    ; tpm2-tools uses inSensitive.size=0, no sensitiveType/authValue.
    mov word [rdi + 14], 0x0000     ; inSensitive.size = 0

    ; ── inPublic starts at [16] ──────────────────────────────────────
    ; Determine whether scheme is NULL (-> 22B public) or not (-> 24B)
    lea     eax, [r12 - TPM_ALG_NULL]
    test    eax, eax
    jnz     .scheme_not_null_cp

    ; ── NULL scheme: inPublic = 22 bytes ──────────────────────────
    ; TPMS_ECC_PARMS layout: symmetric, scheme, curveID, kdf
    mov word [rdi + 33], 0x1600     ; public.size = 22 (BE)
    mov word [rdi + 35], 0x2300     ; type = TPM_ALG_ECC
    mov word [rdi + 37], 0x0B00     ; nameAlg = TPM_ALG_SHA256
    mov     eax, TPM_OA_FIXED_TPM
    or      eax, TPM_OA_FIXED_PARENT
    or      eax, TPM_OA_SENSITIVE_DATA_ORIGIN
    or      eax, TPM_OA_USER_WITH_AUTH
    or      eax, ebx
    bswap   eax
    mov     [rdi + 39], eax          ; objectAttributes
    mov word [rdi + 43], 0x0000     ; authPolicy.size = 0
    mov word [rdi + 45], 0x1000     ; symmetric = TPM_ALG_NULL
    mov word [rdi + 47], 0x1000     ; scheme = TPM_ALG_NULL (2B for NULL)
    mov word [rdi + 49], 0x0300     ; curveID = TPM_ECC_NIST_P256
    mov word [rdi + 51], 0x1000     ; kdf = TPM_ALG_NULL
    mov word [rdi + 53], 0x0000     ; unique.x.size = 0
    mov word [rdi + 55], 0x0000     ; unique.y.size = 0
    ; total params = 8, public = 22 bytes: [35-56]
    mov word [rdi + 57], 0x0000      ; outsideInfo.size = 0
    mov     dword [rdi + 59], 0x00000000 ; creationPCR.count = 0
    ; Fix header size to 63 (NULL scheme)
    mov     dword [rdi + 2], 0x3f000000
    jmp     .done_cp

.scheme_not_null_cp:
    ; ── Non-NULL scheme (ECDSA/ECDH): inPublic = 24 bytes ────────
    ; TPMS_ECC_PARMS: symmetric(2), scheme(4), curveID(2), kdf(2) = 10
    mov word [rdi + 33], 0x1800     ; public.size = 24 (BE)
    mov word [rdi + 35], 0x2300     ; type = TPM_ALG_ECC
    mov word [rdi + 37], 0x0B00     ; nameAlg = TPM_ALG_SHA256
    mov     eax, TPM_OA_FIXED_TPM
    or      eax, TPM_OA_FIXED_PARENT
    or      eax, TPM_OA_SENSITIVE_DATA_ORIGIN
    or      eax, TPM_OA_USER_WITH_AUTH
    or      eax, ebx
    bswap   eax
    mov     [rdi + 39], eax          ; objectAttributes
    mov word [rdi + 43], 0x0000     ; authPolicy.size = 0
    mov word [rdi + 45], 0x1000     ; symmetric = TPM_ALG_NULL
    mov     eax, r12d
    xchg    al, ah
    mov     [rdi + 47], ax           ; scheme algorithm (ECDSA/ECDH)
    mov word [rdi + 49], 0x0B00     ; scheme.hash = SHA256
    mov word [rdi + 51], 0x0300     ; curveID = TPM_ECC_NIST_P256
    mov word [rdi + 53], 0x1000     ; kdf = TPM_ALG_NULL
    mov word [rdi + 55], 0x0000     ; unique.x.size = 0
    mov word [rdi + 57], 0x0000     ; unique.y.size = 0
    ; total params = 10, public = 24 bytes: [35-58]
    mov word [rdi + 59], 0x0000      ; outsideInfo.size = 0
    mov     dword [rdi + 61], 0x00000000 ; creationPCR.count = 0
    ; Fix header size to 65 (ECDSA scheme)
    mov     dword [rdi + 2], 0x41000000
.done_cp:
    pop     r12
    pop     rbx
    ret
.err_pop2:
    pop     r12
    pop     rbx
.err:
    xor     eax, eax
    ret

; ==================================================================
; er_tpm_create_primary_p256_signing — CreatePrimary ECDSA signing
; rdi = buf → rax = buf, 0
; =================================================================
er_fn er_tpm_create_primary_p256_signing
    mov     esi, TPM_ALG_ECDSA
    mov     edx, TPM_OA_SIGN_ENCRYPT
    jmp     er_tpm_create_primary_p256

; ==================================================================
; er_tpm_create_primary_p256_ecdh — CreatePrimary ECDH
; rdi = buf → rax = buf, 0
; =================================================================
er_fn er_tpm_create_primary_p256_ecdh
    mov     esi, TPM_ALG_ECDH
    mov     edx, TPM_OA_DECRYPT
    jmp     er_tpm_create_primary_p256

; ==================================================================
; er_tpm_load_external_p256_verify — LoadExternal P-256 verify key
; rdi = buf, rsi = public_key[64] (X[32] + Y[32]) → rax = buf, 0
; =================================================================
er_fn er_tpm_load_external_p256_verify
    test    rdi, rdi
    jz      .err
    test    rsi, rsi
    jz      .err
    push    rbx
    mov     rbx, rsi
    mov     esi, TPM_ST_NO_SESSIONS
    mov     edx, TPM_CMD_LOAD_EXT_P256_LEN
    mov     ecx, TPM_CC_LOAD_EXTERNAL
    call    er_tpm_header_build
    test    rax, rax
    jz      .err_pop1

    mov     rdi, rax
    ; [10-11] TPM2B_SENSITIVE outer len = 0
    mov word [rdi + 10], 0x0000
    ; [12-13] TPM2B_PUBLIC area_len = 88
    mov word [rdi + 12], 0x5800

    ; TPMT_PUBLIC starting at [14]:
    mov word [rdi + 14], 0x2300     ; type = ECC
    mov word [rdi + 16], 0x0B00     ; nameAlg = SHA256
    mov     dword [rdi + 18], 0x52040000 ; objectAttributes
    mov word [rdi + 22], 0x0000     ; authPolicy = empty
    mov word [rdi + 24], 0x1000     ; symmetric = NULL
    mov word [rdi + 26], 0x1800     ; scheme = ECDSA
    mov word [rdi + 28], 0x0B00     ; scheme hash = SHA256
    mov word [rdi + 30], 0x0300     ; curve = NIST_P256
    mov word [rdi + 32], 0x1000     ; kdf = NULL
    mov word [rdi + 34], 0x2000     ; unique_x len = 32
    ; [36-67] copy X (32 bytes)
    push    rdi
    add     rdi, 36
    mov     rsi, rbx
    mov     ecx, TPM_P256_POINT_BYTES
    rep     movsb
    pop     rdi
    mov word [rdi + 68], 0x2000     ; unique_y len = 32
    ; [70-101] copy Y from key+32
    push    rdi
    add     rdi, 70
    lea     rsi, [rbx + TPM_P256_POINT_BYTES]
    mov     ecx, TPM_P256_POINT_BYTES
    rep     movsb
    pop     rdi
    ; [102-105] hierarchy = TPM_RH_NULL
    mov     dword [rdi + 102], 0x07000040

    pop     rbx
    ret
.err_pop1:
    pop     rbx
.err:
    xor     eax, eax
    ret

; ==================================================================
; er_tpm_ecdh_zgen_p256 — TPM2 ECDH ZGen(handle, peer_point[64])
; rdi = buf, esi = handle, rdx = peer_point → rax = buf, 0
; =================================================================
er_fn er_tpm_ecdh_zgen_p256
    test    rdi, rdi
    jz      .err
    test    esi, esi
    jz      .err
    test    rdx, rdx
    jz      .err
    push    rbx
    push    r12
    mov     r12d, esi
    mov     rbx, rdx
    mov     esi, TPM_ST_SESSIONS
    mov     edx, TPM_CMD_ECDH_ZGEN_LEN
    mov     ecx, TPM_CC_ECDH_ZGEN
    call    er_tpm_header_build
    test    rax, rax
    jz      .err_pop2

    mov     rdi, rax
    add     rdi, TPM_HEADER_LEN
    mov     esi, r12d
    call    _tpm_write_auth_handle
    ; rax = buf+27. Write TPM2B_ECC_POINT:
    ; [0-1] outer_len = 68 (0x0044)
    mov word [rax], 0x4400
    ; [2-3] x_len = 32 (0x0020)
    mov word [rax + 2], 0x2000
    ; [4-35] copy X (32 bytes from rbx)
    push    rax
    lea     rdi, [rax + 4]
    mov     rsi, rbx
    mov     ecx, TPM_P256_POINT_BYTES
    rep     movsb
    pop     rax
    ; [36-37] y_len = 32 (0x0020)
    mov word [rax + 36], 0x2000
    ; [38-69] copy Y (32 bytes from rbx+32)
    push    rax
    lea     rdi, [rax + 38]
    lea     rsi, [rbx + TPM_P256_POINT_BYTES]
    mov     ecx, TPM_P256_POINT_BYTES
    rep     movsb
    pop     rax

    pop     r12
    pop     rbx
    ret
.err_pop2:
    pop     r12
    pop     rbx
.err:
    xor     eax, eax
    ret

; ==================================================================
; er_tpm_encrypt_decrypt2 — TPM2 EncryptDecrypt2
; rdi = buf, esi = handle, rdx = input, ecx = input_len,
; r8 = iv[16], r9d = mode, [rsp+8] = decrypt_flag
; → rax = buf, 0
; =================================================================
er_fn er_tpm_encrypt_decrypt2
    test    rdi, rdi
    jz      .err
    test    esi, esi
    jz      .err
    test    rdx, rdx
    jz      .err
    test    ecx, ecx
    jz      .err
    test    r8, r8
    jz      .err

    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12d, esi
    mov     rbx, rdx
    mov     r13d, ecx
    mov     r14, r8
    mov     r15d, r9d

    ; total = TPM_CMD_ENC_DEC2_FIXED_LEN + 16 + input_len
    lea     edx, [r13 + 16 + TPM_CMD_ENC_DEC2_FIXED_LEN]
    mov     esi, TPM_ST_SESSIONS
    mov     ecx, TPM_CC_ENCRYPT_DECRYPT2
    call    er_tpm_header_build
    test    rax, rax
    jz      .err_pop5

    mov     rdi, rax
    add     rdi, TPM_HEADER_LEN
    mov     esi, r12d
    call    _tpm_write_auth_handle
    ; rax = cursor after auth handle
    ; decrypt flag (1 byte): always encrypt=0 for now
    mov     byte [rax], 0x00
    inc     rax
    ; mode (2 BE)
    mov     ecx, r15d
    xchg    cl, ch
    mov     [rax], cx
    add     rax, 2
    ; IV TPM2B (16 bytes)
    mov     rsi, r14
    mov     edx, 16
    mov     rdi, rax
    call    _tpm_write_tpm2b
    ; input TPM2B (variable)
    mov     rsi, rbx
    mov     edx, r13d
    call    _tpm_write_tpm2b

    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret
.err_pop5:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
.err:
    xor     eax, eax
    ret

; ==================================================================
; Response parsers
; =================================================================

; ==================================================================
; er_tpm_parse_handle — parse handle from response
; rdi = response, esi = length → rax = handle, 0 on error
; =================================================================
er_fn er_tpm_parse_handle
    push    rsi
    push    rdi
    call    er_tpm_response_success
    test    eax, eax
    jz      .err_pop2
    pop     rdi
    pop     rsi
    cmp     esi, TPM_HEADER_LEN + 4
    jb      .err
    add     rdi, TPM_HEADER_LEN
    call    _tpm_get_be32
    test    eax, eax
    jz      .err
    ret
.err_pop2:
    add     rsp, 16
.err:
    xor     eax, eax
    ret

; ==================================================================
; er_tpm_parse_sha256_digest — parse SHA-256 digest from response
; rdi = response, esi = length, rdx = output[32] → rax = 32, 0
; =================================================================
er_fn er_tpm_parse_sha256_digest
    push    rdx
    push    rsi
    push    rdi
    call    er_tpm_response_success
    test    eax, eax
    jz      .err_pop3
    pop     rdi
    pop     rsi
    pop     rdx

    cmp     esi, TPM_HEADER_LEN + 4
    jb      .err

    ; Read parameter size if sessions tag
    push    rdx
    push    rsi
    push    rdi

    movzx   eax, word [rdi]
    cmp     eax, TPM_ST_SESSIONS
    jne     .no_param_sz_sd
    add     rdi, TPM_HEADER_LEN
    call    _tpm_get_be32
    ; Parameter size is at offset 10 after sessions header
    ; Use it to bound the parameter window
    mov     ecx, eax          ; ecx = param_size
    ; parameter_end = 14 + param_size (header 10 + param_size 4)
    lea     esi, [ecx + 14]
    jmp     .check_param_sd
.no_param_sz_sd:
    ; For no-sessions responses with handle, TPM2B starts at offset 14
    pop     rdi
    pop     rsi
    pop     rdx
    jmp     .skip_handle_sd

.check_param_sd:
    pop     rdi
    pop     rsi
    pop     rdx
    ; For sessions, param_size at offset 10, TPM2B at offset 14

.skip_handle_sd:
    ; Read TPM2B at offset 14
    mov     ecx, TPM_HEADER_LEN + 4
    cmp     esi, ecx
    jb      .err
    add     ecx, 2
    cmp     esi, ecx
    jb      .err
    movzx   eax, word [rdi + TPM_HEADER_LEN + 4]
    xchg    al, ah
    cmp     eax, TPM_SHA256_DIGEST_LEN
    jne     .err
    ; Copy digest
    mov     ecx, TPM_SHA256_DIGEST_LEN
    mov     rsi, rdi
    add     rsi, TPM_HEADER_LEN + 4 + 2
    mov     rdi, rdx
    rep     movsb
    mov     eax, TPM_SHA256_DIGEST_LEN
    ret
.err_pop3:
    add     rsp, 24
.err:
    xor     eax, eax
    ret

; ==================================================================
; er_tpm_parse_p256_public — parse P-256 public key from CreatePrimary
; rdi = response, esi = length, rdx = x_out[32], rcx = y_out[32]
; → rax = 64 on success, 0 on error (TODO)
; =================================================================
er_fn er_tpm_parse_p256_public
    test    rdi, rdi
    jz      .err
    test    rdx, rdx
    jz      .err
    test    rcx, rcx
    jz      .err

    push    rbx
    push    r12
    push    r13
    push    r14
    mov     r12, rdx            ; x_out
    mov     r13, rcx            ; y_out

    push    rsi
    push    rdi
    call    er_tpm_response_success
    test    eax, eax
    jz      .err_pop6

    pop     rdi                 ; rdi = response
    pop     rsi                 ; rsi = length

    ; Determine handle offset from tag
    movzx   eax, word [rdi]
    cmp     eax, TPM_ST_SESSIONS
    je      .has_param_size
    ; TPM_ST_NO_SESSIONS: handle at +10
    mov     ebx, 10
    jmp     .got_handle_ofs
.has_param_size:
    ; TPM_ST_SESSIONS: parameterSize at +10, handle at +14
    mov     ebx, 14
.got_handle_ofs:
    lea     ecx, [rbx + 4]
    cmp     esi, ecx
    jb      .err_pop4

    ; Skip past header + handle
    lea     r14, [rdi + rbx + 4]

    ; Read TPM2B_PUBLIC size
    movzx   eax, word [r14]
    xchg    al, ah
    add     r14, 2

    ; Type: must be TPM_ALG_ECC (0x0023)
    movzx   eax, word [r14]
    xchg    al, ah
    cmp     eax, TPM_ALG_ECC
    jne     .err_pop4
    add     r14, 2

    ; Skip nameAlg (2), objectAttributes (4)
    add     r14, 6

    ; Skip authPolicy TPM2B
    movzx   eax, word [r14]
    xchg    al, ah
    lea     r14, [r14 + rax + 2]

    ; Skip ECC params: symmetric(2), scheme(4), curveID(2), kdf(2)
    add     r14, 10

    ; unique: x TPM2B
    movzx   eax, word [r14]
    xchg    al, ah
    cmp     eax, 32
    jne     .err_pop4
    add     r14, 2
    mov     ecx, 32
    mov     rsi, r14
    mov     rdi, r12
    rep     movsb
    mov     r14, rsi

    ; unique: y TPM2B
    movzx   eax, word [r14]
    xchg    al, ah
    cmp     eax, 32
    jne     .err_pop4
    add     r14, 2
    mov     ecx, 32
    mov     rsi, r14
    mov     rdi, r13
    rep     movsb

    mov     eax, 64
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

.err_pop6:
    add     rsp, 48
    xor     eax, eax
    ret
.err_pop4:
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
.err:
    xor     eax, eax
    ret
