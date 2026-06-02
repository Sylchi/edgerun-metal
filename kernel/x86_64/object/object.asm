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
    cmp     di, OBJECT_KIND_BYTES
    je      .ok
    cmp     di, OBJECT_KIND_TREE
    je      .ok
    cmp     di, OBJECT_KIND_RECEIPT
    je      .ok
    xor     eax, eax
    er_ret
.ok: mov    eax, 1
    er_ret

; validate section counts  rdx=owners, rcx=envelopes, r8=children → eax=1
_validate_section_counts:
    cmp     rdx, OBJECT_MAX_OWNERS
    ja      .inv
    cmp     rcx, OBJECT_MAX_ENVELOPES
    ja      .inv
    cmp     r8, OBJECT_MAX_CHILDREN
    ja      .inv
    mov     eax, 1
    er_ret
.inv: xor    eax, eax
    er_ret

; validate OwnerKind [1..4]  edi=kind → eax=1
_validate_owner_kind:
    cmp     edi, OBJECT_OWNER_KIND_DEVICE
    jb      .inv
    cmp     edi, OBJECT_OWNER_KIND_USER
    ja      .inv
    mov     eax, 1
    er_ret
.inv: xor    eax, eax
    er_ret

; validate EnvelopeKind [0..5]  edi=kind → eax=1
_validate_envelope_kind:
    cmp     edi, OBJECT_ENVELOPE_KIND_SIGNATURE
    ja      .inv
    mov     eax, 1
    er_ret
.inv: xor    eax, eax
    er_ret

; validate Algorithm [0..5]  di=algo → eax=1
_validate_algorithm:
    cmp     di, OBJECT_ALGORITHM_ECDSA_P256_SHA256
    ja      .inv
    mov     eax, 1
    er_ret
.inv: xor    eax, eax
    er_ret

; envelope owner match  edi=env_kind, esi=owner_kind → eax=1
_envelope_owner_matches:
    cmp     edi, OBJECT_ENVELOPE_KIND_NONE
    je      .ok
    cmp     edi, OBJECT_ENVELOPE_KIND_SIGNATURE
    je      .ok
    cmp     edi, OBJECT_ENVELOPE_KIND_DEVICE
    je      .check_device
    cmp     edi, OBJECT_ENVELOPE_KIND_STORAGE
    je      .check_storage
    cmp     edi, OBJECT_ENVELOPE_KIND_APP
    je      .check_app
    cmp     edi, OBJECT_ENVELOPE_KIND_USER
    je      .check_user
    xor     eax, eax
    er_ret
.check_device:
    xor     eax, eax
    cmp     esi, OBJECT_OWNER_KIND_DEVICE
    sete    al
    er_ret
.check_storage:
    xor     eax, eax
    cmp     esi, OBJECT_OWNER_KIND_STORAGE
    sete    al
    er_ret
.check_app:
    xor     eax, eax
    cmp     esi, OBJECT_OWNER_KIND_APP
    sete    al
    er_ret
.check_user:
    xor     eax, eax
    cmp     esi, OBJECT_OWNER_KIND_USER
    sete    al
    er_ret
.ok:
    mov     eax, 1
    er_ret

; envelope algorithm match  edi=env_kind, si=algo → eax=1
_envelope_algorithm_matches:
    cmp     edi, OBJECT_ENVELOPE_KIND_NONE
    je      .check_none
    cmp     edi, OBJECT_ENVELOPE_KIND_SIGNATURE
    je      .check_ed25519
    cmp     si, OBJECT_ALGORITHM_AES_GCM_256
    je      .ok
    cmp     si, OBJECT_ALGORITHM_XCHACHA20_POLY1305
    je      .ok
    xor     eax, eax
    er_ret
.check_none:
    xor     eax, eax
    cmp     si, OBJECT_ALGORITHM_NONE
    sete    al
    er_ret
.check_ed25519:
    xor     eax, eax
    cmp     si, OBJECT_ALGORITHM_ED25519
    sete    al
    er_ret
.ok:
    mov     eax, 1
    er_ret

; validate envelope key_id/metadata_hash zero policy  rdi=envelope → eax=1
_validate_envelope_key_metadata:
    push    rbx
    mov     rbx, rdi
    cmp     dword [rbx + ENVELOPE_STRUCT_KIND], OBJECT_ENVELOPE_KIND_NONE
    jne     .check_nonzero
    lea     rdi, [rbx + ENVELOPE_STRUCT_KEY_ID]
    call    _object_id_nonzero
    test    eax, eax
    jnz     .inv
    lea     rdi, [rbx + ENVELOPE_STRUCT_METADATA_HASH]
    call    _object_id_nonzero
    test    eax, eax
    jnz     .inv
    jmp     .ok
.check_nonzero:
    lea     rdi, [rbx + ENVELOPE_STRUCT_KEY_ID]
    call    _object_id_nonzero
    test    eax, eax
    jz      .inv
    lea     rdi, [rbx + ENVELOPE_STRUCT_METADATA_HASH]
    call    _object_id_nonzero
    test    eax, eax
    jz      .inv
.ok:
    pop     rbx
    mov     eax, 1
    er_ret
.inv:
    pop     rbx
    xor     eax, eax
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

    xor     ecx, ecx
.loop:
    lea     rdi, [r12 + rcx * 4]
    mov     esi, [rbx + rcx * 4]
    er_push rcx
    call    er_store32
    er_pop  rcx
    inc     ecx
    cmp     ecx, OBJECT_REQUIREMENTS_SIZE / 4
    jb      .loop

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

    xor     ecx, ecx
.loop:
    lea     rdi, [r12 + rcx * 4]
    er_push rcx
    call    er_load32
    er_pop  rcx
    mov     [rbx + rcx * 4], eax
    inc     ecx
    cmp     ecx, OBJECT_REQUIREMENTS_SIZE / 4
    jb      .loop

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
    lea     rdi, [rbx + OWNER_STRUCT_NODE_ID]
    call    _object_id_nonzero
    er_check_zero eax, .bad_arg

    ; Kind
    lea     rdi, [r12 + 0]
    mov     esi, [rbx + 0]
    call    er_store32

    lea     rdi, [r12 + OWNER_OF_NODE_ID]
    lea     rsi, [rbx + OWNER_STRUCT_NODE_ID]
    call    _object_copy_id

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

    lea     rdi, [rbx + OWNER_STRUCT_NODE_ID]
    lea     rsi, [r12 + OWNER_OF_NODE_ID]
    call    _object_copy_id

    lea     rdi, [rbx + OWNER_STRUCT_NODE_ID]
    call    _object_id_nonzero
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

    mov     rdi, rbx
    call    _validate_envelope_key_metadata
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

    lea     rdi, [r12 + ENVELOPE_OF_KEY_ID]
    lea     rsi, [rbx + ENVELOPE_STRUCT_KEY_ID]
    call    _object_copy_id

    lea     rdi, [r12 + ENVELOPE_OF_METADATA_HASH]
    lea     rsi, [rbx + ENVELOPE_STRUCT_METADATA_HASH]
    call    _object_copy_id

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

    lea     rdi, [rbx + ENVELOPE_STRUCT_KEY_ID]
    lea     rsi, [r12 + ENVELOPE_OF_KEY_ID]
    call    _object_copy_id

    lea     rdi, [rbx + ENVELOPE_STRUCT_METADATA_HASH]
    lea     rsi, [r12 + ENVELOPE_OF_METADATA_HASH]
    call    _object_copy_id

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

    mov     rdi, rbx
    call    _validate_envelope_key_metadata
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
    lea     rdi, [rbx + CHILD_STRUCT_OBJECT_ID]
    call    _object_id_nonzero
    er_check_zero eax, .bad_arg

    movzx   edi, word [rbx + 48]
    call    _validate_kind
    er_check_zero eax, .bad_arg

    cmp     qword [rbx + 40], 0  ; logical_len
    je      .bad_arg

    lea     rdi, [rbx + CHILD_STRUCT_REQUIREMENTS_HASH]
    call    _object_id_nonzero
    er_check_zero eax, .bad_arg

    lea     rdi, [r12 + CHILD_OF_OBJECT_ID]
    lea     rsi, [rbx + CHILD_STRUCT_OBJECT_ID]
    call    _object_copy_id

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

    lea     rdi, [r12 + CHILD_OF_REQUIREMENTS_HASH]
    lea     rsi, [rbx + CHILD_STRUCT_REQUIREMENTS_HASH]
    call    _object_copy_id

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

    lea     rdi, [rbx + CHILD_STRUCT_OBJECT_ID]
    lea     rsi, [r12 + CHILD_OF_OBJECT_ID]
    call    _object_copy_id

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

    lea     rdi, [rbx + CHILD_STRUCT_REQUIREMENTS_HASH]
    lea     rsi, [r12 + CHILD_OF_REQUIREMENTS_HASH]
    call    _object_copy_id

    ; Validate nonzeros
    lea     rdi, [rbx + CHILD_STRUCT_OBJECT_ID]
    call    _object_id_nonzero
    er_check_zero eax, .corrupt

    lea     rdi, [rbx + CHILD_STRUCT_REQUIREMENTS_HASH]
    call    _object_id_nonzero
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
; rdi=kind, rsi=body_len, rdx=owners, rcx=envelopes,
; r8=children, r9=out_size
; ==================================================================
er_fn er_object_canonical_size
    push    rbx

    mov     di, di
    call    _validate_kind
    er_check_zero eax, .bad_arg

    call    _validate_section_counts
    er_check_zero eax, .bad_arg

    cmp     di, OBJECT_KIND_BYTES
    je      .no_children
    cmp     di, OBJECT_KIND_RECEIPT
    je      .no_children
    jmp     .check_tree
.no_children:
    er_check_nonzero r8, .bad_arg
    jmp     .compute
.check_tree:
    er_check_nonzero rsi, .bad_arg

.compute:
    mov     rax, OBJECT_HEADER_SIZE

    mov     rbx, rdx
    imul    rbx, OBJECT_OWNER_SIZE
    jo      .no_space
    add     rax, rbx
    jc      .no_space

    mov     rbx, rcx
    imul    rbx, OBJECT_ENVELOPE_SIZE
    jo      .no_space
    add     rax, rbx
    jc      .no_space

    mov     rbx, r8
    imul    rbx, OBJECT_CHILD_SIZE
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
; er_object_write_bytes_node
; int er_object_write_bytes_node(uint8_t* out, uint64_t out_len,
;                                const uint8_t req[28], const void* epoch,
;                                const uint8_t* body, uint64_t body_len)
; rdi=out, rsi=out_len, rdx=req, rcx=epoch, r8=body, r9=body_len
; Returns eax=written bytes, edx=0 on success.
; ==================================================================
er_fn er_object_write_bytes_node
    xor     eax, eax
    push    rax                 ; envelope_count
    push    rax                 ; envelopes
    push    r9                  ; body_len
    push    r8                  ; body
    xor     r8d, r8d            ; owners
    xor     r9d, r9d            ; owner_count
    call    er_object_write_bytes_node_owned
    add     rsp, 32
    er_ret

; ==================================================================
; er_object_write_bytes_node_owned
; int er_object_write_bytes_node_owned(uint8_t* out, uint64_t out_len,
;     const uint8_t req[28], const void* epoch,
;     const uint8_t* owners, uint64_t owner_count,
;     const uint8_t* envelopes, uint64_t envelope_count,
;     const uint8_t* body, uint64_t body_len)
; rdi=out, rsi=out_len, rdx=req, rcx=epoch, r8=owners, r9=owner_count
; stack: [rbp+16]=body, [rbp+24]=body_len, [rbp+32]=envelopes, [rbp+40]=envelope_count
; ==================================================================
er_fn er_object_write_bytes_node_owned
    er_frame_push_regs rbx, r12, r13, r14, r15
    sub     rsp, 160

    mov     r12, rdi            ; out
    mov     r13, rsi            ; out_len
    mov     r14, rdx            ; req
    mov     r15, rcx            ; epoch
    mov     [rsp + 128], r8     ; owners
    mov     [rsp + 136], r9     ; owner_count

    mov     edi, OBJECT_KIND_BYTES
    mov     rsi, [rbp + 24]
    mov     rdx, [rsp + 136]
    mov     rcx, [rbp + 40]
    xor     r8d, r8d
    lea     r9, [rsp + 152]
    call    er_object_canonical_size
    er_check_zero eax, .writer_fail
    mov     rax, [rsp + 152]
    cmp     r13, rax
    jb      .no_space

    mov     rdi, rsp
    mov     esi, OBJECT_KIND_BYTES
    mov     rdx, [rbp + 24]
    mov     rcx, [rbp + 24]
    xor     r8d, r8d
    mov     r9, r14
    mov     r10, r15
    mov     r11, [rsp + 136]
    mov     rax, [rbp + 40]
    call    _object_fill_header

    mov     rdi, r12
    mov     rsi, rsp
    mov     rdx, [rsp + 128]
    mov     rcx, [rsp + 136]
    mov     r8, [rbp + 32]
    mov     r9, [rbp + 40]
    call    _object_write_header_sections
    er_check_zero eax, .writer_fail
    mov     rbx, rax

.body_copy:
    lea     rdi, [r12 + rbx]
    mov     rsi, [rbp + 24]
    mov     rdx, [rbp + 16]
    call    _object_memcpy
    mov     rax, [rsp + 152]
    er_ok
    add     rsp, 160
    er_pop  rbx, r12, r13, r14, r15
    er_frame_pop
    er_ret
.bad_arg:
    xor     eax, eax
    mov     edx, OBJECT_ERR_BAD_ARGUMENT
    add     rsp, 160
    er_pop  rbx, r12, r13, r14, r15
    er_frame_pop
    er_ret
.no_space:
    xor     eax, eax
    mov     edx, OBJECT_ERR_NO_SPACE
    add     rsp, 160
    er_pop  rbx, r12, r13, r14, r15
    er_frame_pop
    er_ret
.writer_fail:
    ; Preserve the callee's error code when possible.
    test    edx, edx
    jnz     .writer_return_fail
    mov     edx, OBJECT_ERR_BAD_ARGUMENT
.writer_return_fail:
    xor     eax, eax
    add     rsp, 160
    er_pop  rbx, r12, r13, r14, r15
    er_frame_pop
    er_ret

; ==================================================================
; er_object_write_tree_node
; int er_object_write_tree_node(uint8_t* out, uint64_t out_len,
;                               const uint8_t req[28], const void* epoch,
;                               const uint8_t* children, uint64_t child_count)
; rdi=out, rsi=out_len, rdx=req, rcx=epoch, r8=children, r9=child_count
; Returns eax=written bytes, edx=0 on success.
; ==================================================================
er_fn er_object_write_tree_node
    xor     eax, eax
    push    rax                 ; envelope_count
    push    rax                 ; envelopes
    push    r9                  ; child_count
    push    r8                  ; children
    xor     r8d, r8d            ; owners
    xor     r9d, r9d            ; owner_count
    call    er_object_write_tree_node_owned
    add     rsp, 32
    er_ret

; ==================================================================
; er_object_write_tree_node_owned
; int er_object_write_tree_node_owned(uint8_t* out, uint64_t out_len,
;     const uint8_t req[28], const void* epoch,
;     const uint8_t* owners, uint64_t owner_count,
;     const uint8_t* envelopes, uint64_t envelope_count,
;     const uint8_t* children, uint64_t child_count)
; rdi=out, rsi=out_len, rdx=req, rcx=epoch, r8=owners, r9=owner_count
; stack: [rbp+16]=children, [rbp+24]=child_count, [rbp+32]=envelopes, [rbp+40]=envelope_count
; ==================================================================
er_fn er_object_write_tree_node_owned
    er_frame_push_regs rbx, r12, r13, r14, r15
    sub     rsp, 176

    mov     r12, rdi            ; out
    mov     r13, rsi            ; out_len
    mov     r14, rdx            ; req
    mov     r15, rcx            ; epoch
    mov     [rsp + 128], r8     ; owners
    mov     [rsp + 136], r9     ; owner_count

    mov     rdx, [rsp + 136]
    mov     rcx, [rbp + 40]
    mov     r8, [rbp + 24]
    call    _validate_section_counts
    er_check_zero eax, .bad_arg

    ; Validate child offsets and accumulate logical length.
    xor     rbx, rbx            ; index
    mov     qword [rsp + 144], 0 ; logical_len
.validate_child_loop:
    cmp     rbx, [rbp + 24]
    jae     .children_valid
    mov     rax, rbx
    imul    rax, OBJECT_CHILD_SIZE
    add     rax, [rbp + 16]
    mov     rcx, [rsp + 144]
    cmp     [rax + CHILD_STRUCT_LOGICAL_OFFSET], rcx
    jne     .bad_arg
    cmp     qword [rax + CHILD_STRUCT_LOGICAL_LEN], 0
    je      .bad_arg
    add     rcx, [rax + CHILD_STRUCT_LOGICAL_LEN]
    jc      .no_space
    mov     [rsp + 144], rcx
    inc     rbx
    jmp     .validate_child_loop

.children_valid:
    mov     edi, OBJECT_KIND_TREE
    xor     esi, esi
    mov     rdx, [rsp + 136]
    mov     rcx, [rbp + 40]
    mov     r8, [rbp + 24]
    lea     r9, [rsp + 160]
    call    er_object_canonical_size
    er_check_zero eax, .writer_fail
    mov     rax, [rsp + 160]
    cmp     r13, rax
    jb      .no_space

    mov     rdi, rsp
    mov     esi, OBJECT_KIND_TREE
    mov     rdx, [rsp + 144]
    xor     ecx, ecx
    mov     r8d, [rbp + 24]
    mov     r9, r14
    mov     r10, r15
    mov     r11, [rsp + 136]
    mov     rax, [rbp + 40]
    call    _object_fill_header

    mov     rdi, r12
    mov     rsi, rsp
    mov     rdx, [rsp + 128]
    mov     rcx, [rsp + 136]
    mov     r8, [rbp + 32]
    mov     r9, [rbp + 40]
    call    _object_write_header_sections
    er_check_zero eax, .writer_fail
    mov     rbx, rax

.child_copy_loop_start:
    xor     r15d, r15d
.child_copy_loop:
    cmp     r15, [rbp + 24]
    jae     .success
    mov     rax, r15
    imul    rax, OBJECT_CHILD_SIZE
    add     rax, [rbp + 16]
    lea     rdi, [r12 + rbx]
    mov     rsi, rax
    call    er_object_child_encode
    er_check_zero eax, .writer_fail
    add     rbx, OBJECT_CHILD_SIZE
    inc     r15
    jmp     .child_copy_loop

.success:
    mov     rax, [rsp + 160]
    er_ok
    add     rsp, 176
    er_pop  rbx, r12, r13, r14, r15
    er_frame_pop
    er_ret
.bad_arg:
    xor     eax, eax
    mov     edx, OBJECT_ERR_BAD_ARGUMENT
    add     rsp, 176
    er_pop  rbx, r12, r13, r14, r15
    er_frame_pop
    er_ret
.no_space:
    xor     eax, eax
    mov     edx, OBJECT_ERR_NO_SPACE
    add     rsp, 176
    er_pop  rbx, r12, r13, r14, r15
    er_frame_pop
    er_ret
.writer_fail:
    test    edx, edx
    jnz     .writer_return_fail
    mov     edx, OBJECT_ERR_BAD_ARGUMENT
.writer_return_fail:
    xor     eax, eax
    add     rsp, 176
    er_pop  rbx, r12, r13, r14, r15
    er_frame_pop
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

    cmp     r13d, OBJECT_HEADER_SIZE
    jb      .corrupt

    sub     rsp, 192

    mov     rdi, r12
    lea     rsi, [r14 + 16]
    call    er_object_header_decode
    er_check_zero eax, .corrupt_pop

    movzx   ebx, word [r14 + 16 + 16]
    movzx   r8d, word [r14 + 16 + 18]
    mov     r10d, [r14 + 16 + 20]
    mov     r9,  [r14 + 16 + 24]
    movzx   r15d, word [r14 + 16]
    mov     [rsp + 160], ebx
    mov     [rsp + 164], r8d
    mov     [rsp + 168], r10d
    mov     [rsp + 172], r15d
    mov     [rsp + 176], r9

    mov     edi, r15d
    mov     rsi, r9
    mov     edx, ebx
    mov     ecx, r8d
    mov     r8d, r10d
    lea     r9, [rsp + 184]
    call    er_object_canonical_size
    er_check_zero eax, .corrupt_pop

    mov     rax, [rsp + 184]
    cmp     eax, r13d
    jne     .corrupt_pop

    cmp     r15w, OBJECT_KIND_TREE
    je      .set_body
    mov     rdx, [r14 + 16 + 8]
    cmp     rdx, [rsp + 176]
    jne     .corrupt_pop

.set_body:
    mov     rax, [rsp + 184]
    sub     rax, [rsp + 176]
    add     rax, r12
    mov     [r14], rax
    mov     rdx, [rsp + 176]
    mov     [r14 + 8], rdx

    mov     ebx, [rsp + 160]
    er_check_zero ebx, .check_env
    xor     r15d, r15d
.ol:
    mov     rdi, r12
    mov     rsi, r15
    call    _object_owner_ptr
    mov     rdi, rax
    mov     rsi, rsp
    er_push rbx, r8, r9, r10, r11, r12, r13, r14, r15
    call    er_object_owner_decode
    er_pop  rbx, r8, r9, r10, r11, r12, r13, r14, r15
    er_check_zero eax, .corrupt_pop
    inc     r15d
    cmp     r15d, ebx
    jb      .ol

.check_env:
    mov     r8d, [rsp + 164]
    er_check_zero r8d, .check_child
    xor     r15d, r15d
.el:
    mov     rdi, r12
    mov     esi, ebx
    mov     rdx, r15
    call    _object_envelope_ptr
    mov     rdi, rax
    mov     rsi, rsp
    er_push rbx, r8, r9, r10, r11, r12, r13, r14, r15
    call    er_object_envelope_decode
    er_pop  rbx, r8, r9, r10, r11, r12, r13, r14, r15
    er_check_zero eax, .corrupt_pop

    movzx   eax, word [rsp + 4]
    cmp     eax, ebx
    jae     .corrupt_pop

    mov     rdi, r12
    mov     rsi, rax
    call    _object_owner_ptr
    er_push rbx, r8, r9, r10, r11, r12, r13, r14, r15
    mov     rdi, rax
    lea     rsi, [rsp + 96 + 72]
    call    er_object_owner_decode
    er_pop  rbx, r8, r9, r10, r11, r12, r13, r14, r15
    er_check_zero eax, .corrupt_pop

    er_push rbx, r8, r9, r10, r11, r12, r13, r14, r15
    lea     rdi, [rsp + 72]
    lea     rsi, [rsp + 96 + 72]
    call    er_object_envelope_validate
    er_pop  rbx, r8, r9, r10, r11, r12, r13, r14, r15
    er_check_zero eax, .corrupt_pop

    inc     r15d
    cmp     r15d, r8d
    jb      .el

.check_child:
    mov     r10d, [rsp + 168]
    er_check_zero r10d, .success
    xor     r15d, r15d
    xor     r11d, r11d
.cl:
    mov     rdi, r12
    mov     esi, ebx
    mov     rdx, r8
    mov     rcx, r15
    call    _object_child_ptr

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

    cmp     word [r14 + 16], OBJECT_KIND_TREE
    jne     .success
    mov     rdx, [r14 + 16 + 8]
    cmp     r11, rdx
    jne     .corrupt_pop

.success:
    add     rsp, 192
    er_pop  rbx, r12, r13, r14, r15
    mov     eax, 1
    er_ok
    er_ret
.corrupt_pop:
    add     rsp, 192
.corrupt:
    er_pop  rbx, r12, r13, r14, r15
    xor     eax, eax
    mov     edx, OBJECT_ERR_CORRUPT
    er_ret

; Section pointer helpers. All return rax=record pointer.
; rdi=canonical_base, rsi=owner_index.
_object_owner_ptr:
    mov     rax, rsi
    imul    rax, OBJECT_OWNER_SIZE
    add     rax, OBJECT_HEADER_SIZE
    add     rax, rdi
    ret

; rdi=canonical_base, rsi=owner_count, rdx=envelope_index.
_object_envelope_ptr:
    mov     rax, rsi
    imul    rax, OBJECT_OWNER_SIZE
    add     rax, OBJECT_HEADER_SIZE
    imul    rdx, OBJECT_ENVELOPE_SIZE
    add     rax, rdx
    add     rax, rdi
    ret

; rdi=canonical_base, rsi=owner_count, rdx=envelope_count, rcx=child_index.
_object_child_ptr:
    mov     rax, rsi
    imul    rax, OBJECT_OWNER_SIZE
    add     rax, OBJECT_HEADER_SIZE
    imul    rdx, OBJECT_ENVELOPE_SIZE
    add     rax, rdx
    imul    rcx, OBJECT_CHILD_SIZE
    add     rax, rcx
    add     rax, rdi
    ret

; Internal header filler: rdi=header, esi=kind, rdx=logical_len,
; rcx=body_len, r8d=child_count, r9=requirements, r10=epoch,
; r11=owner_count, rax=envelope_count.
_object_fill_header:
    er_push rbx, r12, r13
    mov     r12, rdi
    mov     r13, r9
    mov     rbx, r10

    mov     [r12 + HEADER_STRUCT_KIND], si
    mov     dword [r12 + HEADER_STRUCT_FLAGS], 0
    mov     [r12 + HEADER_STRUCT_LOGICAL_LEN], rdx
    mov     [r12 + HEADER_STRUCT_OWNER_COUNT], r11w
    mov     [r12 + HEADER_STRUCT_ENVELOPE_COUNT], ax
    mov     [r12 + HEADER_STRUCT_CHILD_COUNT], r8d
    mov     [r12 + HEADER_STRUCT_BODY_LEN], rcx

    lea     rdi, [r12 + HEADER_STRUCT_EPOCH]
    mov     esi, 64
    mov     rdx, rbx
    call    _object_memcpy
    lea     rdi, [r12 + HEADER_STRUCT_REQUIREMENTS]
    mov     esi, OBJECT_REQUIREMENTS_SIZE
    mov     rdx, r13
    call    _object_memcpy

    er_pop  rbx, r12, r13
    ret

; Internal writer prefix: encode header, then emit owner/envelope sections.
; rdi=out_base, rsi=header, rdx=owners, rcx=owner_count,
; r8=envelopes, r9=envelope_count. Returns rax=payload_offset, edx=0.
_object_write_header_sections:
    er_push rbx, r12, r13, r14, r15
    push    r9
    mov     r12, rdi            ; out_base
    mov     r13, rdx            ; owners
    mov     r14, rcx            ; owner_count
    mov     r15, r8             ; envelopes

    call    er_object_header_encode
    er_check_zero eax, .fail

    mov     rdi, r12
    mov     esi, OBJECT_HEADER_SIZE
    mov     rdx, r13
    mov     rcx, r14
    mov     r8, r15
    mov     r9, [rsp]
    call    _object_write_owners_envelopes
    er_check_zero eax, .fail

    er_ok
    pop     r9
    er_pop  rbx, r12, r13, r14, r15
    ret
.fail:
    test    edx, edx
    jnz     .return_fail
    mov     edx, OBJECT_ERR_BAD_ARGUMENT
.return_fail:
    xor     eax, eax
    pop     r9
    er_pop  rbx, r12, r13, r14, r15
    ret

; Internal section writer: emit owners then envelopes.
; rdi=out_base, rsi=offset, rdx=owners, rcx=owner_count,
; r8=envelopes, r9=envelope_count. Returns rax=new_offset, edx=0.
_object_write_owners_envelopes:
    er_push rbx, rbp, r12, r13, r14, r15
    push    r9
    mov     r12, rdi            ; out_base
    mov     rbx, rsi            ; current offset
    mov     r13, rdx            ; owners
    mov     r14, rcx            ; owner_count
    mov     r15, r8             ; envelopes

    xor     ebp, ebp
.owner_loop:
    cmp     rbp, r14
    jae     .envelope_loop_start
    mov     rax, rbp
    imul    rax, OBJECT_OWNER_SIZE
    add     rax, r13
    lea     rdi, [r12 + rbx]
    mov     rsi, rax
    call    er_object_owner_encode
    er_check_zero eax, .fail
    add     rbx, OBJECT_OWNER_SIZE
    inc     rbp
    jmp     .owner_loop

.envelope_loop_start:
    xor     ebp, ebp
.envelope_loop:
    cmp     rbp, [rsp]
    jae     .success
    mov     rax, rbp
    imul    rax, OBJECT_ENVELOPE_SIZE
    add     rax, r15
    movzx   ecx, word [rax + ENVELOPE_STRUCT_OWNER_INDEX]
    cmp     rcx, r14
    jae     .bad_arg
    mov     rdx, rcx
    imul    rdx, OBJECT_OWNER_SIZE
    add     rdx, r13
    lea     rdi, [r12 + rbx]
    mov     rsi, rax
    call    er_object_envelope_encode
    er_check_zero eax, .fail
    add     rbx, OBJECT_ENVELOPE_SIZE
    inc     rbp
    jmp     .envelope_loop

.success:
    mov     rax, rbx
    er_ok
    pop     r9
    er_pop  rbx, rbp, r12, r13, r14, r15
    ret
.bad_arg:
    mov     edx, OBJECT_ERR_BAD_ARGUMENT
.fail:
    test    edx, edx
    jnz     .return_fail
    mov     edx, OBJECT_ERR_BAD_ARGUMENT
.return_fail:
    xor     eax, eax
    pop     r9
    er_pop  rbx, rbp, r12, r13, r14, r15
    ret

; Internal fixed-ID helpers.
; _object_copy_id: rdi=dst, rsi=src.
_object_copy_id:
    mov     rdx, rsi
    mov     esi, OBJECT_ID_SIZE
    call    _object_memcpy
    ret

; _object_id_nonzero: rdi=id → eax=1 when any byte is nonzero.
_object_id_nonzero:
    mov     esi, OBJECT_ID_SIZE
    call    er_bytes_nonzero
    ret

; Internal memcpy helper: rdi=dst, rsi=len, rdx=src.
_object_memcpy:
    test    rsi, rsi
    jz      .done
    xor     ecx, ecx
.loop:
    mov     al, [rdx + rcx]
    mov     [rdi + rcx], al
    inc     rcx
    cmp     rcx, rsi
    jb      .loop
.done:
    ret
