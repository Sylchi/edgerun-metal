; object.asm — EdgeRun Object serialization format
; Ported from edgerun-zig/src/object.zig
;
; All functions follow the two-register return convention:
;   eax = primary value, edx = 0 on success, error code on failure

%include "x86_64/macros.inc"
%include "x86_64/object/object_constants.inc"

extern er_store16
extern er_store32
extern er_store64
extern er_load16
extern er_load32
extern er_load64
extern er_bytes_nonzero
extern er_bytes_zero
extern er_preimage_raw_hash
extern er_preimage_encode_epoch
extern er_preimage_decode_epoch
extern er_stamp_valid

; ==================================================================
; Internal helpers
; ==================================================================

; validate u32 in [min, max]  edi=value, esi=min, edx=max → eax=1
_validate_u32_range:
    cmp     edi, esi
    jb      .inv
    cmp     edi, edx
    ja      .inv
    mov     eax, 1
    er_ret
.inv: xor    eax, eax
    er_ret

; validate u16 in [min, max]  di=value, si=min, dx=max → eax=1
_validate_u16_range:
    cmp     di, si
    jb      .inv
    cmp     di, dx
    ja      .inv
    mov     eax, 1
    er_ret
.inv: xor    eax, eax
    er_ret

; validate all 7 requirement enum values  rdi=req_ptr → eax=1
_validate_requirements:
    push    rbx
    mov     rbx, rdi
    mov     edi, [rbx + 0]   ; durability
    mov     esi, 1
    mov     edx, 3
    call    _validate_u32_range
    er_check_zero eax, .fail
    mov     edi, [rbx + 4]   ; confidentiality
    mov     esi, 1
    mov     edx, 7
    call    _validate_u32_range
    er_check_zero eax, .fail
    mov     edi, [rbx + 8]   ; portability
    mov     esi, 1
    mov     edx, 4
    call    _validate_u32_range
    er_check_zero eax, .fail
    mov     edi, [rbx + 12]  ; integrity
    mov     esi, 1
    mov     edx, 3
    call    _validate_u32_range
    er_check_zero eax, .fail
    mov     edi, [rbx + 16]  ; lifetime
    mov     esi, 1
    mov     edx, 5
    call    _validate_u32_range
    er_check_zero eax, .fail
    mov     edi, [rbx + 20]  ; visibility
    mov     esi, 1
    mov     edx, 4
    call    _validate_u32_range
    er_check_zero eax, .fail
    mov     edi, [rbx + 24]  ; access
    mov     esi, 1
    mov     edx, 2
    call    _validate_u32_range
    er_check_zero eax, .fail
    pop     rbx
    mov     eax, 1
    er_ret
.fail: pop     rbx
    xor     eax, eax
    er_ret

; validate Kind [1,2,4]  di=kind → eax=1
_validate_kind:
    cmp     di, 1
    je      .ok
    cmp     di, 2
    je      .ok
    cmp     di, 4
    je      .ok
    xor     eax, eax
    er_ret
.ok: mov    eax, 1
    er_ret

; validate OwnerKind [1..4]  edi=kind → eax=1
_validate_owner_kind:
    cmp     edi, 1
    jb      .inv
    cmp     edi, 4
    ja      .inv
    mov     eax, 1
    er_ret
.inv: xor    eax, eax
    er_ret

; validate EnvelopeKind [0..5]  edi=kind → eax=1
_validate_envelope_kind:
    cmp     edi, 5
    ja      .inv
    mov     eax, 1
    er_ret
.inv: xor    eax, eax
    er_ret

; validate Algorithm [0..5]  di=algo → eax=1
_validate_algorithm:
    cmp     di, 5
    ja      .inv
    mov     eax, 1
    er_ret
.inv: xor    eax, eax
    er_ret

; envelope owner match  edi=env_kind, esi=owner_kind → eax=1
_envelope_owner_matches:
    cmp     edi, 0          ; NONE
    je      .ok
    cmp     edi, 5          ; SIGNATURE
    je      .ok
    cmp     edi, 1          ; DEVICE
    je      .check_device
    cmp     edi, 2          ; STORAGE
    je      .check_storage
    cmp     edi, 3          ; APP
    je      .check_app
    cmp     edi, 4          ; USER
    je      .check_user
    xor     eax, eax
    er_ret
.check_device:
    cmp     esi, 1
    sete    al
    er_ret
.check_storage:
    cmp     esi, 2
    sete    al
    er_ret
.check_app:
    cmp     esi, 3
    sete    al
    er_ret
.check_user:
    cmp     esi, 4
    sete    al
    er_ret
.ok:
    mov     eax, 1
    er_ret

; envelope algorithm match  edi=env_kind, si=algo → eax=1
_envelope_algorithm_matches:
    cmp     edi, 0          ; NONE → algo must be 0
    je      .check_none
    cmp     edi, 5          ; SIGNATURE → algo must be 4 (ed25519)
    je      .check_ed25519
    cmp     si, 1           ; AES_GCM_256
    je      .ok
    cmp     si, 2           ; XCHACHA20_POLY1305
    je      .ok
    xor     eax, eax
    er_ret
.check_none:
    cmp     si, 0
    sete    al
    er_ret
.check_ed25519:
    cmp     si, 4
    sete    al
    er_ret
.ok:
    mov     eax, 1
    er_ret

; ==================================================================
; er_object_requirements_encode
; bool er_object_requirements_encode(uint8_t out[28],
;                                    const uint8_t req[28])
; rdi=out, rsi=req
; Writes 7 u32 values in canonical order.
; ==================================================================
er_fn er_object_requirements_encode
    er_push rbx, r12
    mov     r12, rdi          ; out
    mov     rbx, rsi          ; req

    lea     rdi, [r12 + 0]
    mov     esi, [rbx + 0]
    call    er_store32
    lea     rdi, [r12 + 4]
    mov     esi, [rbx + 4]
    call    er_store32
    lea     rdi, [r12 + 8]
    mov     esi, [rbx + 8]
    call    er_store32
    lea     rdi, [r12 + 12]
    mov     esi, [rbx + 12]
    call    er_store32
    lea     rdi, [r12 + 16]
    mov     esi, [rbx + 16]
    call    er_store32
    lea     rdi, [r12 + 20]
    mov     esi, [rbx + 20]
    call    er_store32
    lea     rdi, [r12 + 24]
    mov     esi, [rbx + 24]
    call    er_store32

    er_pop  rbx, r12
    mov     eax, 1
    er_ok
    er_ret

; ==================================================================
; er_object_requirements_decode
; int er_object_requirements_decode(const uint8_t in[28],
;                                   uint8_t req[28])
; rdi=in, rsi=req
; ==================================================================
er_fn er_object_requirements_decode
    er_push rbx, r12
    mov     r12, rdi
    mov     rbx, rsi

    lea     rdi, [r12 + 0]
    call    er_load32
    mov     [rbx + 0], eax
    lea     rdi, [r12 + 4]
    call    er_load32
    mov     [rbx + 4], eax
    lea     rdi, [r12 + 8]
    call    er_load32
    mov     [rbx + 8], eax
    lea     rdi, [r12 + 12]
    call    er_load32
    mov     [rbx + 12], eax
    lea     rdi, [r12 + 16]
    call    er_load32
    mov     [rbx + 16], eax
    lea     rdi, [r12 + 20]
    call    er_load32
    mov     [rbx + 20], eax
    lea     rdi, [r12 + 24]
    call    er_load32
    mov     [rbx + 24], eax

    mov     rdi, rbx
    call    _validate_requirements
    er_check_zero eax, .corrupt

    er_pop  rbx, r12
    mov     eax, 1
    er_ok
    er_ret
.corrupt:
    er_pop  rbx, r12
    xor     eax, eax
    mov     edx, OBJECT_ERR_CORRUPT
    er_ret

; ==================================================================
; er_object_requirements_hash
; void er_object_requirements_hash(const uint8_t req[28],
;                                  uint8_t out[32])
; rdi=req, rsi=out
; ==================================================================
er_fn er_object_requirements_hash
    er_push rbx, r12
    mov     rbx, rdi
    mov     r12, rsi

    sub     rsp, 32
    mov     rdi, rsp
    mov     rsi, rbx
    call    er_object_requirements_encode

    mov     rdi, rsp
    mov     esi, 28
    mov     rdx, r12
    call    er_preimage_raw_hash

    add     rsp, 32
    er_pop  rbx, r12
    er_ok
    er_ret

; ==================================================================
; er_object_header_encode
; int er_object_header_encode(uint8_t out[148],
;                             const uint8_t header[124])
; rdi=out, rsi=header
; ==================================================================
er_fn er_object_header_encode
    er_push rbx, r12, r13
    mov     r12, rdi
    mov     rbx, rsi

    ; Validate epoch
    lea     rdi, [rbx + 32]       ; epoch stamp in header struct
    call    er_stamp_valid
    er_check_zero eax, .bad_arg

    ; Zero header buffer
    mov     rdi, r12
    mov     esi, 148
    call    er_bytes_zero
    ; Actually er_bytes_zero takes (rdi=buf, esi=len) — no rdx/rcx
    ; Let me re-read: it's `test esi, esi` then loop.
    ; But my call set rdx and rcx which it ignores. That's fine.

    ; Magic
    mov     rax, OBJECT_MAGIC_QWORD
    mov     [r12], rax



    ; Version = 1
    lea     rdi, [r12 + 8]
    mov     esi, 1
    call    er_store16

    ; Kind (u16)
    lea     rdi, [r12 + 10]
    movzx   esi, word [rbx + 0]    ; HEADER_STRUCT offset 0 = kind
    call    er_store16

    ; Flags (u32)
    lea     rdi, [r12 + 12]
    mov     esi, [rbx + 4]         ; offset 4 = flags
    call    er_store32

    ; Logical_len (u64)
    lea     rdi, [r12 + 16]
    mov     rsi, [rbx + 8]         ; offset 8 = logical_len
    call    er_store64

    ; Owner_count (u16)
    lea     rdi, [r12 + 24]
    movzx   esi, word [rbx + 16]   ; offset 16 = owner_count
    call    er_store16

    ; Envelope_count (u16)
    lea     rdi, [r12 + 26]
    movzx   esi, word [rbx + 18]   ; offset 18 = envelope_count
    call    er_store16

    ; Child_count (u32)
    lea     rdi, [r12 + 28]
    mov     esi, [rbx + 20]        ; offset 20 = child_count
    call    er_store32

    ; Body_len (u64)
    lea     rdi, [r12 + 32]
    mov     rsi, [rbx + 24]        ; offset 24 = body_len
    call    er_store64

    ; Epoch (stamp at header_struct+32 → binary at out+40)
    lea     rdi, [rbx + 32]        ; stamp
    lea     rsi, [r12 + 40]        ; out
    mov     edx, 64                ; out_len
    call    er_preimage_encode_epoch

    ; Requirements (struct at header_struct+96 → binary at out+104)
    lea     rdi, [r12 + 104]
    lea     rsi, [rbx + 96]
    call    er_object_requirements_encode

    er_pop  rbx, r12, r13
    mov     eax, 1
    er_ok
    er_ret
.bad_arg:
    er_pop  rbx, r12, r13
    xor     eax, eax
    mov     edx, OBJECT_ERR_BAD_ARGUMENT
    er_ret

; ==================================================================
; er_object_header_decode
; int er_object_header_decode(const uint8_t in[148],
;                             uint8_t header[124])
; rdi=in, rsi=header
; ==================================================================
er_fn er_object_header_decode
    er_push rbx, r12
    mov     r12, rdi
    mov     rbx, rsi

    ; Magic
    mov     rax, [r12]
    mov     rcx, OBJECT_MAGIC_QWORD
    cmp     rax, rcx
    jne     .corrupt

    ; Version
    lea     rdi, [r12 + 8]
    call    er_load16
    cmp     eax, 1
    jne     .corrupt

    ; Reserved bytes must be zero
    lea     rdi, [r12 + 132]
    mov     esi, 16
    call    er_bytes_nonzero
    er_check_nonzero eax, .corrupt

    ; Kind
    lea     rdi, [r12 + 10]
    call    er_load16
    mov     [rbx + 0], ax
    mov     di, ax
    call    _validate_kind
    er_check_zero eax, .corrupt

    ; Flags
    lea     rdi, [r12 + 12]
    call    er_load32
    mov     [rbx + 4], eax

    ; Logical_len
    lea     rdi, [r12 + 16]
    call    er_load64
    mov     [rbx + 8], rax

    ; Owner_count
    lea     rdi, [r12 + 24]
    call    er_load16
    mov     [rbx + 16], ax

    ; Envelope_count
    lea     rdi, [r12 + 26]
    call    er_load16
    mov     [rbx + 18], ax

    ; Child_count
    lea     rdi, [r12 + 28]
    call    er_load32
    mov     [rbx + 20], eax

    ; Body_len
    lea     rdi, [r12 + 32]
    call    er_load64
    mov     [rbx + 24], rax

    ; Epoch
    lea     rdi, [r12 + 40]
    mov     esi, 64
    lea     rdx, [rbx + 32]       ; stamp at header_struct+32
    call    er_preimage_decode_epoch
    er_check_zero eax, .corrupt

    ; Requirements
    lea     rdi, [r12 + 104]
    lea     rsi, [rbx + 96]       ; requirements at header_struct+96
    call    er_object_requirements_decode
    er_check_zero eax, .corrupt

    er_pop  rbx, r12
    mov     eax, 1
    er_ok
    er_ret
.corrupt:
    er_pop  rbx, r12
    xor     eax, eax
    mov     edx, OBJECT_ERR_CORRUPT
    er_ret

; ==================================================================
; er_object_header_id
; void er_object_header_id(const uint8_t* canonical, uint32_t len,
;                          uint8_t out[32])
; rdi=canonical, esi=len, rdx=out
; ==================================================================
er_fn er_object_header_id
    call    er_preimage_raw_hash
    er_ok
    er_ret

; ==================================================================
; er_object_owner_encode
; int er_object_owner_encode(uint8_t out[36],
;                            const uint8_t owner[36])
; rdi=out, rsi=owner
; ==================================================================
er_fn er_object_owner_encode
    er_push rbx, r12
    mov     r12, rdi
    mov     rbx, rsi

    ; Validate node_id nonzero
    lea     rdi, [rbx + 4]
    mov     esi, 32
    call    er_bytes_nonzero
    er_check_zero eax, .bad_arg

    ; Kind
    lea     rdi, [r12 + 0]
    mov     esi, [rbx + 0]
    call    er_store32

    ; Node_id: copy 32 bytes inline
    lea     rdi, [r12 + 4]
    lea     rsi, [rbx + 4]
    mov     ecx, 32
    xor     r8d, r8d
.copy_loop:
    mov     al, [rsi + r8]
    mov     [rdi + r8], al
    inc     r8d
    cmp     r8d, ecx
    jb      .copy_loop

    er_pop  rbx, r12
    mov     eax, 1
    er_ok
    er_ret
.bad_arg:
    er_pop  rbx, r12
    xor     eax, eax
    mov     edx, OBJECT_ERR_BAD_ARGUMENT
    er_ret

; ==================================================================
; er_object_owner_decode
; int er_object_owner_decode(const uint8_t in[36],
;                            uint8_t owner[36])
; rdi=in, rsi=owner
; ==================================================================
er_fn er_object_owner_decode
    er_push rbx, r12
    mov     r12, rdi
    mov     rbx, rsi

    lea     rdi, [r12 + 0]
    call    er_load32
    mov     [rbx + 0], eax
    mov     edi, eax
    call    _validate_owner_kind
    er_check_zero eax, .corrupt

    ; Copy node_id 32 bytes
    lea     rdi, [rbx + 4]
    lea     rsi, [r12 + 4]
    mov     ecx, 32
    xor     r8d, r8d
.copy_loop:
    mov     al, [rsi + r8]
    mov     [rdi + r8], al
    inc     r8d
    cmp     r8d, ecx
    jb      .copy_loop

    lea     rdi, [rbx + 4]
    mov     esi, 32
    call    er_bytes_nonzero
    er_check_zero eax, .corrupt

    er_pop  rbx, r12
    mov     eax, 1
    er_ok
    er_ret
.corrupt:
    er_pop  rbx, r12
    xor     eax, eax
    mov     edx, OBJECT_ERR_CORRUPT
    er_ret

; ==================================================================
; er_object_envelope_encode
; int er_object_envelope_encode(uint8_t out[76],
;                               const uint8_t envelope[76],
;                               const uint8_t owner[36])
; rdi=out, rsi=envelope, rdx=owner
; ==================================================================
er_fn er_object_envelope_encode
    er_push rbx, r12, r13
    mov     r12, rdi
    mov     rbx, rsi
    mov     r13, rdx

    mov     edi, [rbx + 0]
    call    _validate_envelope_kind
    er_check_zero eax, .bad_arg

    mov     edi, [rbx + 0]
    mov     esi, [r13 + 0]
    call    _envelope_owner_matches
    er_check_zero eax, .bad_arg

    mov     edi, [rbx + 0]
    mov     si, [rbx + 6]       ; algorithm field (u16 at offset 6)
    call    _envelope_algorithm_matches
    er_check_zero eax, .bad_arg

    ; For NONE kind: key_id and metadata_hash must be zero
    cmp     dword [rbx + 0], OBJECT_ENVELOPE_KIND_NONE
    jne     .check_nonzero
    lea     rdi, [rbx + 12]
    mov     esi, 32
    call    er_bytes_nonzero
    er_check_nonzero eax, .bad_arg
    lea     rdi, [rbx + 44]
    mov     esi, 32
    call    er_bytes_nonzero
    er_check_nonzero eax, .bad_arg
    jmp     .write

.check_nonzero:
    lea     rdi, [rbx + 12]
    mov     esi, 32
    call    er_bytes_nonzero
    er_check_zero eax, .bad_arg
    lea     rdi, [rbx + 44]
    mov     esi, 32
    call    er_bytes_nonzero
    er_check_zero eax, .bad_arg

.write:
    lea     rdi, [r12 + 0]
    mov     esi, [rbx + 0]
    call    er_store32

    lea     rdi, [r12 + 4]
    movzx   esi, word [rbx + 4]
    call    er_store16

    lea     rdi, [r12 + 6]
    movzx   esi, word [rbx + 6]
    call    er_store16

    lea     rdi, [r12 + 8]
    mov     esi, [rbx + 8]
    call    er_store32

    ; key_id 32 bytes
    lea     rdi, [r12 + 12]
    lea     rsi, [rbx + 12]
    mov     ecx, 32
    xor     r8d, r8d
.kloop:
    mov     al, [rsi + r8]
    mov     [rdi + r8], al
    inc     r8d
    cmp     r8d, ecx
    jb      .kloop

    ; metadata_hash 32 bytes
    lea     rdi, [r12 + 44]
    lea     rsi, [rbx + 44]
    mov     ecx, 32
    xor     r8d, r8d
.mloop:
    mov     al, [rsi + r8]
    mov     [rdi + r8], al
    inc     r8d
    cmp     r8d, ecx
    jb      .mloop

    er_pop  rbx, r12, r13
    mov     eax, 1
    er_ok
    er_ret
.bad_arg:
    er_pop  rbx, r12, r13
    xor     eax, eax
    mov     edx, OBJECT_ERR_BAD_ARGUMENT
    er_ret

; ==================================================================
; er_object_envelope_decode
; int er_object_envelope_decode(const uint8_t in[76],
;                               uint8_t envelope[76])
; rdi=in, rsi=envelope
; ==================================================================
er_fn er_object_envelope_decode
    er_push rbx, r12
    mov     r12, rdi
    mov     rbx, rsi

    lea     rdi, [r12 + 0]
    call    er_load32
    mov     [rbx + 0], eax
    mov     edi, eax
    call    _validate_envelope_kind
    er_check_zero eax, .corrupt

    lea     rdi, [r12 + 4]
    call    er_load16
    mov     [rbx + 4], ax

    lea     rdi, [r12 + 6]
    call    er_load16
    mov     [rbx + 6], ax
    mov     di, ax
    call    _validate_algorithm
    er_check_zero eax, .corrupt

    lea     rdi, [r12 + 8]
    call    er_load32
    mov     [rbx + 8], eax

    ; key_id
    lea     rdi, [rbx + 12]
    lea     rsi, [r12 + 12]
    mov     ecx, 32
    xor     r8d, r8d
.kloop:
    mov     al, [rsi + r8]
    mov     [rdi + r8], al
    inc     r8d
    cmp     r8d, ecx
    jb      .kloop

    ; metadata_hash
    lea     rdi, [rbx + 44]
    lea     rsi, [r12 + 44]
    mov     ecx, 32
    xor     r8d, r8d
.mloop:
    mov     al, [rsi + r8]
    mov     [rdi + r8], al
    inc     r8d
    cmp     r8d, ecx
    jb      .mloop

    er_pop  rbx, r12
    mov     eax, 1
    er_ok
    er_ret
.corrupt:
    er_pop  rbx, r12
    xor     eax, eax
    mov     edx, OBJECT_ERR_CORRUPT
    er_ret

; ==================================================================
; er_object_envelope_validate
; int er_object_envelope_validate(const uint8_t envelope[76],
;                                 const uint8_t owner[36])
; rdi=envelope, rsi=owner
; ==================================================================
er_fn er_object_envelope_validate
    er_push rbx, r12
    mov     rbx, rdi
    mov     r12, rsi

    mov     edi, [rbx + 0]
    mov     esi, [r12 + 0]
    call    _envelope_owner_matches
    er_check_zero eax, .corrupt

    mov     edi, [rbx + 0]
    mov     si, [rbx + 6]
    call    _envelope_algorithm_matches
    er_check_zero eax, .corrupt

    cmp     dword [rbx + 0], OBJECT_ENVELOPE_KIND_NONE
    jne     .check_nonzero
    lea     rdi, [rbx + 12]
    mov     esi, 32
    call    er_bytes_nonzero
    er_check_nonzero eax, .corrupt
    lea     rdi, [rbx + 44]
    mov     esi, 32
    call    er_bytes_nonzero
    er_check_nonzero eax, .corrupt
    jmp     .ok

.check_nonzero:
    lea     rdi, [rbx + 12]
    mov     esi, 32
    call    er_bytes_nonzero
    er_check_zero eax, .corrupt
    lea     rdi, [rbx + 44]
    mov     esi, 32
    call    er_bytes_nonzero
    er_check_zero eax, .corrupt

.ok:
    er_pop  rbx, r12
    mov     eax, 1
    er_ok
    er_ret
.corrupt:
    er_pop  rbx, r12
    xor     eax, eax
    mov     edx, OBJECT_ERR_CORRUPT
    er_ret

; ==================================================================
; er_object_child_encode
; int er_object_child_encode(uint8_t out[84],
;                            const uint8_t child[84])
; rdi=out, rsi=child
; ==================================================================
er_fn er_object_child_encode
    er_push rbx, r12
    mov     r12, rdi
    mov     rbx, rsi

    ; Validate
    lea     rdi, [rbx + 0]       ; object_id
    mov     esi, 32
    call    er_bytes_nonzero
    er_check_zero eax, .bad_arg

    movzx   edi, word [rbx + 48]
    call    _validate_kind
    er_check_zero eax, .bad_arg

    cmp     qword [rbx + 40], 0  ; logical_len
    je      .bad_arg

    lea     rdi, [rbx + 52]
    mov     esi, 32
    call    er_bytes_nonzero
    er_check_zero eax, .bad_arg

    ; Object_id 32 bytes
    lea     rdi, [r12 + 0]
    lea     rsi, [rbx + 0]
    mov     ecx, 32
    xor     r8d, r8d
.oid_loop:
    mov     al, [rsi + r8]
    mov     [rdi + r8], al
    inc     r8d
    cmp     r8d, ecx
    jb      .oid_loop

    ; Logical_offset
    lea     rdi, [r12 + 32]
    mov     rsi, [rbx + 32]
    call    er_store64

    ; Logical_len
    lea     rdi, [r12 + 40]
    mov     rsi, [rbx + 40]
    call    er_store64

    ; Kind
    lea     rdi, [r12 + 48]
    movzx   esi, word [rbx + 48]
    call    er_store16

    ; Pad = 0
    lea     rdi, [r12 + 50]
    xor     esi, esi
    call    er_store16

    ; Requirements_hash 32 bytes
    lea     rdi, [r12 + 52]
    lea     rsi, [rbx + 52]
    mov     ecx, 32
    xor     r8d, r8d
.rh_loop:
    mov     al, [rsi + r8]
    mov     [rdi + r8], al
    inc     r8d
    cmp     r8d, ecx
    jb      .rh_loop

    er_pop  rbx, r12
    mov     eax, 1
    er_ok
    er_ret
.bad_arg:
    er_pop  rbx, r12
    xor     eax, eax
    mov     edx, OBJECT_ERR_BAD_ARGUMENT
    er_ret

; ==================================================================
; er_object_child_decode
; int er_object_child_decode(const uint8_t in[84],
;                            uint64_t expected_offset,
;                            uint8_t child[84])
; rdi=in, rsi=expected_offset, rdx=child
; ==================================================================
er_fn er_object_child_decode
    er_push rbx, r12, r13
    mov     r12, rdi
    mov     r13, rsi
    mov     rbx, rdx

    ; Pad must be zero
    lea     rdi, [r12 + 50]
    call    er_load16
    er_check_nonzero eax, .corrupt

    ; Object_id 32 bytes
    lea     rdi, [rbx + 0]
    lea     rsi, [r12 + 0]
    mov     ecx, 32
    xor     r8d, r8d
.oid_loop:
    mov     al, [rsi + r8]
    mov     [rdi + r8], al
    inc     r8d
    cmp     r8d, ecx
    jb      .oid_loop

    ; Logical_offset
    lea     rdi, [r12 + 32]
    call    er_load64
    mov     [rbx + 32], rax
    cmp     rax, r13
    jne     .corrupt

    ; Logical_len
    lea     rdi, [r12 + 40]
    call    er_load64
    mov     [rbx + 40], rax
    er_check_zero rax, .corrupt

    ; Kind
    lea     rdi, [r12 + 48]
    call    er_load16
    mov     [rbx + 48], ax
    mov     di, ax
    call    _validate_kind
    er_check_zero eax, .corrupt

    ; Requirements_hash 32 bytes
    lea     rdi, [rbx + 52]
    lea     rsi, [r12 + 52]
    mov     ecx, 32
    xor     r8d, r8d
.rh_loop:
    mov     al, [rsi + r8]
    mov     [rdi + r8], al
    inc     r8d
    cmp     r8d, ecx
    jb      .rh_loop

    ; Validate nonzeros
    lea     rdi, [rbx + 0]
    mov     esi, 32
    call    er_bytes_nonzero
    er_check_zero eax, .corrupt

    lea     rdi, [rbx + 52]
    mov     esi, 32
    call    er_bytes_nonzero
    er_check_zero eax, .corrupt

    er_pop  rbx, r12, r13
    mov     eax, 1
    er_ok
    er_ret
.corrupt:
    er_pop  rbx, r12, r13
    xor     eax, eax
    mov     edx, OBJECT_ERR_CORRUPT
    er_ret

; ==================================================================
; er_object_canonical_size
; int er_object_canonical_size(uint32_t kind, uint64_t body_len,
;                              uint16_t owners, uint16_t envelopes,
;                              uint32_t children, uint64_t* out_size)
; rdi=kind, rsi=body_len, edx=owners, ecx=envelopes,
; r8d=children, r9=out_size
; ==================================================================
er_fn er_object_canonical_size
    push    rbx

    mov     di, di
    call    _validate_kind
    er_check_zero eax, .bad_arg

    cmp     dx, 16            ; OBJECT_MAX_OWNERS
    ja      .bad_arg
    cmp     cx, 16            ; OBJECT_MAX_ENVELOPES
    ja      .bad_arg
    cmp     r8d, 65536        ; OBJECT_MAX_CHILDREN
    ja      .bad_arg

    ; bytes/receipt: children must be 0
    cmp     edi, 1
    je      .no_children
    cmp     edi, 4
    je      .no_children
    jmp     .check_tree
.no_children:
    er_check_nonzero r8d, .bad_arg
    jmp     .compute
.check_tree:
    er_check_nonzero rsi, .bad_arg

.compute:
    mov     rax, 148          ; OBJECT_HEADER_SIZE

    movzx   rbx, dx
    imul    rbx, 36           ; OBJECT_OWNER_SIZE
    jo      .no_space
    add     rax, rbx
    jc      .no_space

    movzx   rbx, cx
    imul    rbx, 76           ; OBJECT_ENVELOPE_SIZE
    jo      .no_space
    add     rax, rbx
    jc      .no_space

    imul    rbx, r8, 84       ; OBJECT_CHILD_SIZE
    jo      .no_space
    add     rax, rbx
    jc      .no_space

    add     rax, rsi
    jc      .no_space

    mov     [r9], rax
    pop     rbx
    mov     eax, 1
    er_ok
    er_ret
.bad_arg:
    pop     rbx
    xor     eax, eax
    mov     edx, OBJECT_ERR_BAD_ARGUMENT
    er_ret
.no_space:
    pop     rbx
    xor     eax, eax
    mov     edx, OBJECT_ERR_NO_SPACE
    er_ret

; ==================================================================
; er_object_view_decode
; int er_object_view_decode(const uint8_t* canonical, uint32_t len,
;                           uint8_t* view)
; rdi=canonical, esi=len, rdx=view (ObjectView)
;
; ObjectView (144 bytes):
;   +0: body_ptr (8)
;   +8: body_len (8)
;  +16: header (124 = HEADER_STRUCT_SIZE)
; ==================================================================
er_fn er_object_view_decode
    er_push rbx, r12, r13, r14, r15

    mov     r12, rdi
    mov     r13d, esi
    mov     r14, rdx

    cmp     r13d, 148
    jb      .corrupt

    sub     rsp, 96

    mov     rdi, r12
    lea     rsi, [r14 + 16]
    call    er_object_header_decode
    er_check_zero eax, .corrupt_pop

    movzx   ebx, word [r14 + 16 + 16]
    movzx   r8d, word [r14 + 16 + 18]
    mov     r10d, [r14 + 16 + 20]
    mov     r9,  [r14 + 16 + 24]
    movzx   r15d, word [r14 + 16]

    mov     edi, r15d
    mov     rsi, r9
    mov     edx, ebx
    mov     ecx, r8d
    mov     r8d, r10d
    lea     r9, [rsp + 80]
    call    er_object_canonical_size
    er_check_zero eax, .corrupt_pop

    mov     rax, [rsp + 80]
    cmp     eax, r13d
    jne     .corrupt_pop

    cmp     r15w, 2
    je      .set_body
    mov     rdx, [r14 + 16 + 8]
    cmp     rdx, r9
    jne     .corrupt_pop

.set_body:
    mov     rax, [rsp + 80]
    sub     rax, r9
    add     rax, r12
    mov     [r14], rax
    mov     [r14 + 8], r9

    er_check_zero ebx, .check_env
    xor     r15d, r15d
.ol:
    mov     ecx, r15d
    imul    ecx, 36
    add     ecx, 148
    add     rcx, r12
    mov     rdi, rcx
    mov     rsi, rsp
    er_push rbx, r8, r9, r10, r11, r12, r13, r14, r15
    call    er_object_owner_decode
    er_pop  rbx, r8, r9, r10, r11, r12, r13, r14, r15
    er_check_zero eax, .corrupt_pop
    inc     r15d
    cmp     r15d, ebx
    jb      .ol

.check_env:
    er_check_zero r8d, .check_child
    xor     r15d, r15d
.el:
    mov     eax, 148
    mov     ecx, ebx
    imul    ecx, 36
    add     eax, ecx
    mov     ecx, r15d
    imul    ecx, 76
    add     eax, ecx
    add     rax, r12
    mov     rdi, rax
    mov     rsi, rsp
    er_push rbx, r8, r9, r10, r11, r12, r13, r14, r15
    call    er_object_envelope_decode
    er_pop  rbx, r8, r9, r10, r11, r12, r13, r14, r15
    er_check_zero eax, .corrupt_pop

    movzx   eax, word [rsp + 4]
    cmp     eax, ebx
    jae     .corrupt_pop

    ; Decode owner at index into second temp spot (rsp+84)
    mov     ecx, eax
    imul    ecx, 36
    add     ecx, 148
    add     rcx, r12
    er_push rbx, r8, r9, r10, r11, r12, r13, r14, r15
    mov     rdi, rcx
    lea     rsi, [rsp + 96 + 72]
    call    er_object_owner_decode
    er_pop  rbx, r8, r9, r10, r11, r12, r13, r14, r15
    er_check_zero eax, .corrupt_pop

    er_push rbx, r8, r9, r10, r11, r12, r13, r14, r15
    mov     rdi, rsp
    lea     rsi, [rsp + 96 + 72]
    call    er_object_envelope_validate
    er_pop  rbx, r8, r9, r10, r11, r12, r13, r14, r15
    er_check_zero eax, .corrupt_pop

    inc     r15d
    cmp     r15d, r8d
    jb      .el

.check_child:
    er_check_zero r10d, .success
    xor     r15d, r15d
    xor     r11d, r11d
.cl:
    mov     eax, 148
    mov     ecx, ebx
    imul    ecx, 36
    add     eax, ecx
    mov     ecx, r8d
    imul    ecx, 76
    add     eax, ecx
    mov     ecx, r15d
    imul    ecx, 84
    add     eax, ecx
    add     rax, r12

    mov     rdi, rax
    mov     esi, r11d
    mov     rdx, rsp
    er_push rbx, r8, r9, r10, r11, r12, r13, r14, r15
    call    er_object_child_decode
    er_pop  rbx, r8, r9, r10, r11, r12, r13, r14, r15
    er_check_zero eax, .corrupt_pop

    mov     rax, [rsp + 40]
    add     r11, rax
    jc      .corrupt_pop

    inc     r15d
    cmp     r15d, r10d
    jb      .cl

    cmp     word [r14 + 16], 2
    jne     .success
    mov     rdx, [r14 + 16 + 8]
    cmp     r11, rdx
    jne     .corrupt_pop

.success:
    add     rsp, 96
    er_pop  rbx, r12, r13, r14, r15
    mov     eax, 1
    er_ok
    er_ret
.corrupt_pop:
    add     rsp, 96
.corrupt:
    er_pop  rbx, r12, r13, r14, r15
    xor     eax, eax
    mov     edx, OBJECT_ERR_CORRUPT
    er_ret
