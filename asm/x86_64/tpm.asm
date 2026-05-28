; EdgeRun TPM2 wire protocol — command/response buffer building and parsing
;
; All multi-byte integers in TPM2 are big-endian.
; Functions follow System V AMD64 ABI.
;
; HOSTED_TEST mode: command buffer writes are captured to a static buffer
; for test verification (same pattern as serial.asm).

%include "x86_64/macros.inc"
%include "x86_64/tpm_constants.inc"

; ─── TPM2 protocol constants (local-only) ──────────────────────────
%define TPM_CRB_MAX_BUFFER_SIZE 4096

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
    push    rax
    call    _tpm_capture_tx
    pop     rax
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
    mov     esi, TPM_ST_NO_SESSIONS
    mov     edx, TPM_CMD_GET_RANDOM_LEN
    mov     ecx, TPM_CC_GET_RANDOM
    call    er_tpm_header_build
    test    rax, rax
    jz      .err

    ; Store bytes requested at offset 10 (big-endian)
    pop     rcx        ; esi value = bytes_req
    mov     byte [rax + 11], cl    ; LSB
    shr     ecx, 8
    mov     byte [rax + 10], cl    ; MSB

%ifdef HOSTED_TEST
    pop     rdi
    push    rax
    call    _tpm_capture_tx
    pop     rax
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

%ifdef HOSTED_TEST
    pop     rdi             ; pop buf off stack before data-field pops
%endif
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
    push    rax
    call    _tpm_capture_tx   ; rdi already = buf from earlier pop
    pop     rax
%endif
    ret

.err_pop3:
%ifdef HOSTED_TEST
    add     rsp, 32     ; pop rdi, rsi, rdx, rcx
%else
    add     rsp, 24     ; pop rsi, rdx, rcx
%endif
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

    mov     rdi, er_tpm_tx_buffer
    push    rcx
    mov     rsi, [er_tpm_tx_count]
    add     rdi, rsi
    pop     rcx

    mov     rsi, [rsp]          ; rsi = saved rdi = cmd_buf pointer

    rep     movsb

    sub     rdi, er_tpm_tx_buffer
    mov     [er_tpm_tx_count], rdi
    pop     rdi
    pop     rcx
    pop     rsi
    ret
%endif
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
    mov     word [rdi + 12], 0x0000
    mov     byte [rdi + 14], 0x00
    mov     word [rdi + 15], 0x0000
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
%ifdef HOSTED_TEST
    push    rdi
%endif
    mov     esi, TPM_ST_NO_SESSIONS
    mov     edx, TPM_CMD_SHUTDOWN_LEN
    mov     ecx, TPM_CC_SHUTDOWN
    call    er_tpm_header_build
    test    rax, rax
    jz      .err_pop2
    mov     ecx, r12d
    mov     byte [rax + 10], ch
    mov     byte [rax + 11], cl
%ifdef HOSTED_TEST
    mov     rdi, rax
    push    rax
    call    _tpm_capture_tx
    pop     rax
    pop     rdi
%endif
    pop     r12
    ret
.err_pop2:
%ifdef HOSTED_TEST
    add     rsp, 8
%endif
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
%ifdef HOSTED_TEST
    push    rdi
%endif
    mov     esi, TPM_ST_NO_SESSIONS
    mov     edx, TPM_CMD_FLUSH_CONTEXT_LEN
    mov     ecx, TPM_CC_FLUSH_CONTEXT
    call    er_tpm_header_build
    test    rax, rax
    jz      .err_pop2
    mov     ecx, r12d
    bswap   ecx
    mov     [rax + 10], ecx
%ifdef HOSTED_TEST
    mov     rdi, rax
    push    rax
    call    _tpm_capture_tx
    pop     rax
    pop     rdi
%endif
    pop     r12
    ret
.err_pop2:
%ifdef HOSTED_TEST
    add     rsp, 8
%endif
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
%ifdef HOSTED_TEST
    push    rdi
%endif
    mov     esi, TPM_ST_NO_SESSIONS
    mov     edx, TPM_CMD_READ_PUBLIC_LEN
    mov     ecx, TPM_CC_READ_PUBLIC
    call    er_tpm_header_build
    test    rax, rax
    jz      .err_pop2
    mov     ecx, r12d
    bswap   ecx
    mov     [rax + 10], ecx
%ifdef HOSTED_TEST
    mov     rdi, rax
    push    rax
    call    _tpm_capture_tx
    pop     rax
    pop     rdi
%endif
    pop     r12
    ret
.err_pop2:
%ifdef HOSTED_TEST
    add     rsp, 8
%endif
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
    mov     r12d, ecx
    mov     rbx, rsi
    mov     r13d, edx
%ifdef HOSTED_TEST
    push    rdi
%endif
    lea     edx, [r13 + TPM_CMD_HASH_FIXED_LEN]
    mov     esi, TPM_ST_NO_SESSIONS
    mov     ecx, TPM_CC_HASH
    call    er_tpm_header_build
    test    rax, rax
    jz      .err_pop3
    mov     rdi, rax
    add     rdi, TPM_HEADER_LEN
    mov     rsi, rbx
    mov     edx, r13d
    call    _tpm_write_tpm2b
    ; hash_alg = TPM_ALG_SHA256
    mov     word [rax], 0x000B
    ; hierarchy (4 BE)
    mov     ecx, r12d
    bswap   ecx
    mov     [rax + 2], ecx
%ifdef HOSTED_TEST
    push    rax
    mov     rdi, [rsp + 8]   ; rdi = buffer start from entry push
    call    _tpm_capture_tx
    pop     rax
    mov     rax, [rsp]       ; restore buffer start for return
    add     rsp, 8
%endif
    pop     r13
    pop     r12
    pop     rbx
    ret
.err_pop3:
%ifdef HOSTED_TEST
    add     rsp, 8
%endif
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
%ifdef HOSTED_TEST
    push    rdi
%endif
    mov     esi, TPM_ST_NO_SESSIONS
    mov     edx, TPM_CMD_HASH_SEQUENCE_START_LEN
    mov     ecx, TPM_CC_HASH_SEQUENCE_START
    call    er_tpm_header_build
    test    rax, rax
    jz      .err
    ; hash_alg = TPM_ALG_SHA256 at offset 10 (2 BE)
    mov     word [rax + 10], 0x000B
    ; hierarchy = TPM_RH_NULL at offset 12 (4 BE)
    mov     dword [rax + 12], 0x07000040
%ifdef HOSTED_TEST
    mov     rdi, rax
    push    rax
    call    _tpm_capture_tx
    pop     rax
    add     rsp, 8
%endif
    ret
.err:
%ifdef HOSTED_TEST
    add     rsp, 8
%endif
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
%ifdef HOSTED_TEST
    push    rdi
%endif
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
%ifdef HOSTED_TEST
    push    rax
    mov     rdi, [rsp + 8]   ; rdi = buffer start from entry push
    call    _tpm_capture_tx
    pop     rax
    mov     rax, [rsp]
    add     rsp, 8
%endif
    pop     r13
    pop     r12
    pop     rbx
    ret
.err_pop3:
%ifdef HOSTED_TEST
    add     rsp, 8
%endif
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
%ifdef HOSTED_TEST
    push    rdi
%endif
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
%ifdef HOSTED_TEST
    push    rax
    mov     rdi, [rsp + 8]   ; rdi = buffer start from entry push
    call    _tpm_capture_tx
    pop     rax
    mov     rax, [rsp]
    add     rsp, 8
%endif
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret
.err_pop4:
%ifdef HOSTED_TEST
    add     rsp, 8
%endif
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
%ifdef HOSTED_TEST
    push    rdi
%endif
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
    mov     word [rax], 0x000B
%ifdef HOSTED_TEST
    push    rax
    mov     rdi, [rsp + 8]   ; rdi = buffer start from entry push
    call    _tpm_capture_tx
    pop     rax
    mov     rax, [rsp]
    add     rsp, 8
%endif
    pop     r13
    pop     r12
    pop     rbx
    ret
.err_pop3:
%ifdef HOSTED_TEST
    add     rsp, 8
%endif
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
%ifdef HOSTED_TEST
    push    rdi
%endif
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
    mov     word [rax], 0x0018
    mov     word [rax + 2], 0x000B
    ; TPMT_TK_HASHCHECK: st_hashcheck + rh_null + digest_len=0
    mov     byte [rax + 4], 0x80
    mov     byte [rax + 5], 0x24
    mov     byte [rax + 6], 0x40
    mov     byte [rax + 7], 0x00
    mov     byte [rax + 8], 0x00
    mov     byte [rax + 9], 0x07
    mov     word [rax + 10], 0x0000
%ifdef HOSTED_TEST
    push    rax
    mov     rdi, [rsp + 8]   ; rdi = buffer start from entry push
    call    _tpm_capture_tx
    pop     rax
    mov     rax, [rsp]
    add     rsp, 8
%endif
    pop     r12
    pop     rbx
    ret
.err_pop2:
%ifdef HOSTED_TEST
    add     rsp, 8
%endif
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
%ifdef HOSTED_TEST
    push    rdi
%endif
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
    mov     word [rax], 0x0018
    mov     word [rax + 2], 0x000B
    add     rax, 4
    mov     rsi, r13
    mov     edx, TPM_P256_POINT_BYTES
    mov     rdi, rax
    call    _tpm_write_tpm2b
    mov     rsi, r14
    mov     edx, TPM_P256_POINT_BYTES
    call    _tpm_write_tpm2b
%ifdef HOSTED_TEST
    push    rax
    mov     rdi, [rsp + 8]   ; rdi = buffer start from entry push
    call    _tpm_capture_tx
    pop     rax
    mov     rax, [rsp]
    add     rsp, 8
%endif
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret
.err_pop4:
%ifdef HOSTED_TEST
    add     rsp, 8
%endif
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
%ifdef HOSTED_TEST
    push    rdi
%endif
    mov     esi, TPM_ST_SESSIONS
    mov     edx, TPM_CMD_CREATE_PRIMARY_LEN
    mov     ecx, TPM_CC_CREATE_PRIMARY
    call    er_tpm_header_build
    test    rax, rax
    jz      .err_pop2

    mov     rdi, rax
    ; [10-13] rh_owner (4 BE)
    mov     dword [rdi + 10], 0x01004000
    ; [14-17] auth_area_len = 9 (4 BE)
    mov     dword [rdi + 14], 0x09000000
    ; [18-21] rs_pw (4 BE)
    mov     dword [rdi + 18], 0x09000040
    ; [22-23] nonce = 0 (2 BE)
    mov     word [rdi + 22], 0x0000
    ; [24]   session attrs = 0
    mov     byte [rdi + 24], 0x00
    ; [25-26] hmac = 0 (2 BE)
    mov     word [rdi + 25], 0x0000
    ; [27-28] empty_sensitive_create_len = 4 (2 BE)
    mov     word [rdi + 27], 0x0004
    ; [29-30] sensitive type = 0 (2 BE)
    mov     word [rdi + 29], 0x0000
    ; [31-32] authValue TPM2B = empty (2 BE)
    mov     word [rdi + 31], 0x0000
    ; [33-34] TPM2B_PUBLIC len = 24 (2 BE)
    mov     word [rdi + 33], 0x0018

    ; TPMT_PUBLIC (24 bytes at [35-58]):
    mov     word [rdi + 35], 0x0023     ; type = TPM_ALG_ECC
    mov     word [rdi + 37], 0x000B     ; nameAlg = TPM_ALG_SHA256

    ; [39-42] objectAttributes (4 BE)
    mov     eax, TPM_OA_FIXED_TPM
    or      eax, TPM_OA_FIXED_PARENT
    or      eax, TPM_OA_SENSITIVE_DATA_ORIGIN
    or      eax, TPM_OA_USER_WITH_AUTH
    or      eax, TPM_OA_NODA
    or      eax, ebx
    bswap   eax
    mov     [rdi + 39], eax

    mov     word [rdi + 43], 0x0000     ; authPolicy TPM2B = empty
    mov     word [rdi + 45], 0x0010     ; symmetric = TPM_ALG_NULL
    ; [47-48] scheme alg
    mov     eax, r12d
    xchg    al, ah
    mov     [rdi + 47], ax
    mov     word [rdi + 49], 0x000B     ; scheme hash = SHA256
    mov     word [rdi + 51], 0x0003     ; curve = NIST_P256
    mov     word [rdi + 53], 0x0010     ; kdf = TPM_ALG_NULL
    mov     word [rdi + 55], 0x0000     ; unique_x len = 0
    mov     word [rdi + 57], 0x0000     ; unique_y len = 0
    mov     word [rdi + 59], 0x0000     ; outsideInfo len = 0
    mov     dword [rdi + 61], 0x00000000 ; creationPCR count = 0

%ifdef HOSTED_TEST
    push    rax
    mov     rdi, [rsp + 8]   ; rdi = buffer start from entry push
    call    _tpm_capture_tx
    pop     rax
    mov     rax, [rsp]
    add     rsp, 8
%endif
    pop     r12
    pop     rbx
    ret
.err_pop2:
%ifdef HOSTED_TEST
    add     rsp, 8
%endif
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
%ifdef HOSTED_TEST
    push    rdi
%endif
    mov     esi, TPM_ST_NO_SESSIONS
    mov     edx, TPM_CMD_LOAD_EXT_P256_LEN
    mov     ecx, TPM_CC_LOAD_EXTERNAL
    call    er_tpm_header_build
    test    rax, rax
    jz      .err_pop1

    mov     rdi, rax
    ; [10-11] TPM2B_SENSITIVE outer len = 0
    mov     word [rdi + 10], 0x0000
    ; [12-13] TPM2B_PUBLIC area_len = 88
    mov     word [rdi + 12], 0x0058

    ; TPMT_PUBLIC starting at [14]:
    mov     word [rdi + 14], 0x0023     ; type = ECC
    mov     word [rdi + 16], 0x000B     ; nameAlg = SHA256
    mov     dword [rdi + 18], 0x52040000 ; objectAttributes
    mov     word [rdi + 22], 0x0000     ; authPolicy = empty
    mov     word [rdi + 24], 0x0010     ; symmetric = NULL
    mov     word [rdi + 26], 0x0018     ; scheme = ECDSA
    mov     word [rdi + 28], 0x000B     ; scheme hash = SHA256
    mov     word [rdi + 30], 0x0003     ; curve = NIST_P256
    mov     word [rdi + 32], 0x0010     ; kdf = NULL
    mov     word [rdi + 34], 0x0020     ; unique_x len = 32
    ; [36-67] copy X (32 bytes)
    push    rdi
    add     rdi, 36
    mov     rsi, rbx
    mov     ecx, TPM_P256_POINT_BYTES
    rep     movsb
    pop     rdi
    mov     word [rdi + 68], 0x0020     ; unique_y len = 32
    ; [70-101] copy Y from key+32
    push    rdi
    add     rdi, 70
    lea     rsi, [rbx + TPM_P256_POINT_BYTES]
    mov     ecx, TPM_P256_POINT_BYTES
    rep     movsb
    pop     rdi
    ; [102-105] hierarchy = TPM_RH_NULL
    mov     dword [rdi + 102], 0x07000040

%ifdef HOSTED_TEST
    mov     rdi, rax
    push    rax
    call    _tpm_capture_tx
    pop     rax
    add     rsp, 8
%endif
    pop     rbx
    ret
.err_pop1:
%ifdef HOSTED_TEST
    add     rsp, 8
%endif
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
%ifdef HOSTED_TEST
    push    rdi
%endif
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
    mov     word [rax], 0x0044
    ; [2-3] x_len = 32 (0x0020)
    mov     word [rax + 2], 0x0020
    ; [4-35] copy X (32 bytes from rbx)
    push    rax
    lea     rdi, [rax + 4]
    mov     rsi, rbx
    mov     ecx, TPM_P256_POINT_BYTES
    rep     movsb
    pop     rax
    ; [36-37] y_len = 32 (0x0020)
    mov     word [rax + 36], 0x0020
    ; [38-69] copy Y (32 bytes from rbx+32)
    push    rax
    lea     rdi, [rax + 38]
    lea     rsi, [rbx + TPM_P256_POINT_BYTES]
    mov     ecx, TPM_P256_POINT_BYTES
    rep     movsb
    pop     rax

%ifdef HOSTED_TEST
    push    rax
    mov     rdi, [rsp + 8]   ; rdi = buffer start from entry push
    call    _tpm_capture_tx
    pop     rax
    mov     rax, [rsp]
    add     rsp, 8
%endif
    pop     r12
    pop     rbx
    ret
.err_pop2:
%ifdef HOSTED_TEST
    add     rsp, 8
%endif
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
%ifdef HOSTED_TEST
    push    rdi
%endif
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
    ; symmetric alg = TPM_ALG_AES (2 BE)
    mov     word [rax], 0x0006
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

%ifdef HOSTED_TEST
    push    rax
    mov     rdi, [rsp + 8]   ; rdi = buffer start from entry push
    call    _tpm_capture_tx
    pop     rax
    mov     rax, [rsp]
    add     rsp, 8
%endif
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret
.err_pop5:
%ifdef HOSTED_TEST
    add     rsp, 8
%endif
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
    mov     esi, esi          ; keep original length

.check_param_sd:
    pop     rdi
    pop     rsi
    pop     rdx

    ; cursor starts at TPM_HEADER_LEN
    mov     ecx, TPM_HEADER_LEN
    ; Read TPM2B at cursor
    cmp     esi, ecx
    jb      .err
    add     ecx, 2
    cmp     esi, ecx
    jb      .err
    movzx   eax, word [rdi + TPM_HEADER_LEN]
    cmp     eax, TPM_SHA256_DIGEST_LEN
    jne     .err
    ; Copy digest
    mov     ecx, TPM_SHA256_DIGEST_LEN
    mov     rsi, rdi
    add     rsi, TPM_HEADER_LEN + 2
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
    ; TODO: full implementation
    xor     eax, eax
    ret
