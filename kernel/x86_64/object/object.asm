; object.asm — EdgeRun Object serialization format
; Ported from edgerun-zig/src/object.zig
;
; All functions follow the two-register return convention:
;   eax = primary value, edx = 0 on success, error code on failure

%include "x86_64/macros.inc"
%include "x86_64/object/object_constants.inc"

OBJECT_STAMP_SIZE           equ 64
OBJECT_REQ_FIELD_COUNT      equ OBJECT_REQUIREMENTS_SIZE / 4

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
    er_push rbx, rbp
    mov     rbx, rdi
    xor     ebp, ebp
.loop:
    mov     edi, [rbx + rbp * 4]
    call    _requirement_max_for_index
    er_check_zero eax, .fail
    mov     edx, eax
    mov     esi, 1
    call    _validate_u32_range
    er_check_zero eax, .fail
    inc     ebp
    cmp     ebp, OBJECT_REQ_FIELD_COUNT
    jb      .loop
    er_pop  rbx, rbp
    mov     eax, 1
    er_ret
.fail:
    er_pop  rbx, rbp
    xor     eax, eax
    er_ret

; select requirement enum max by field index  ebp=index → eax=max, eax=0 invalid
_requirement_max_for_index:
    cmp     ebp, REQ_OF_DURABILITY / 4
    je      .durability
    cmp     ebp, REQ_OF_CONFIDENTIALITY / 4
    je      .confidentiality
    cmp     ebp, REQ_OF_PORTABILITY / 4
    je      .portability
    cmp     ebp, REQ_OF_INTEGRITY / 4
    je      .integrity
    cmp     ebp, REQ_OF_LIFETIME / 4
    je      .lifetime
    cmp     ebp, REQ_OF_VISIBILITY / 4
    je      .visibility
    cmp     ebp, REQ_OF_ACCESS / 4
    je      .access
    xor     eax, eax
    er_ret
.durability:
    mov     eax, OBJECT_DURABILITY_REPLICATED
    er_ret
.confidentiality:
    mov     eax, OBJECT_CONFIDENTIALITY_LAYERED
    er_ret
.portability:
    mov     eax, OBJECT_PORTABILITY_PUBLIC_PORTABLE
    er_ret
.integrity:
    mov     eax, OBJECT_INTEGRITY_SEALED
    er_ret
.lifetime:
    mov     eax, OBJECT_LIFETIME_PINNED
    er_ret
.visibility:
    mov     eax, OBJECT_VISIBILITY_PUBLIC
    er_ret
.access:
    mov     eax, OBJECT_ACCESS_HOT_MEMORY_ALLOWED
    er_ret

; validate Kind [1,2,4,8,16]  di=kind → eax=1
_validate_kind:
    cmp     di, OBJECT_KIND_BYTES
    je      .ok
    cmp     di, OBJECT_KIND_TREE
    je      .ok
    cmp     di, OBJECT_KIND_RECEIPT
    je      .ok
    cmp     di, OBJECT_KIND_CODE
    je      .ok
    cmp     di, OBJECT_KIND_ISA
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
    jb      .inv
    cmp     edi, OBJECT_ENVELOPE_KIND_USER
    ja      .inv
    xor     eax, eax
    cmp     esi, edi
    sete    al
    er_ret
.inv:
    xor     eax, eax
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
    call    _object_algorithm_is_encryption
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

; si=algorithm → eax=1 for supported encryption algorithms.
_object_algorithm_is_encryption:
    cmp     si, OBJECT_ALGORITHM_AES_GCM_256
    je      .ok
    cmp     si, OBJECT_ALGORITHM_XCHACHA20_POLY1305
    je      .ok
    xor     eax, eax
    er_ret
.ok:
    mov     eax, 1
    er_ret

; validate complete envelope policy against owner  rdi=envelope, rsi=owner → eax=1
_object_envelope_policy_matches:
    er_push rbx, r12
    mov     rbx, rdi
    mov     r12, rsi

    mov     edi, [rbx + ENVELOPE_STRUCT_KIND]
    call    _validate_envelope_kind
    er_check_zero eax, .fail

    mov     edi, [rbx + ENVELOPE_STRUCT_KIND]
    mov     esi, [r12 + OWNER_STRUCT_KIND]
    call    _envelope_owner_matches
    er_check_zero eax, .fail

    mov     edi, [rbx + ENVELOPE_STRUCT_KIND]
    mov     si, [rbx + ENVELOPE_STRUCT_ALGORITHM]
    call    _envelope_algorithm_matches
    er_check_zero eax, .fail

    mov     rdi, rbx
    call    _validate_envelope_key_metadata
    er_check_zero eax, .fail

    er_pop  rbx, r12
    mov     eax, 1
    er_ret
.fail:
    er_pop  rbx, r12
    xor     eax, eax
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
    lea     rdi, [rbx + HEADER_STRUCT_EPOCH]
    call    er_stamp_valid
    er_check_zero eax, .bad_arg

    ; Zero header buffer
    mov     rdi, r12
    mov     esi, OBJECT_HEADER_SIZE
    call    er_bytes_zero

    ; Magic
    mov     rax, OBJECT_MAGIC_QWORD
    mov     [r12], rax

    mov     rdi, r12
    mov     rsi, rbx
    call    _object_header_scalars_encode

    ; Epoch
    lea     rdi, [rbx + HEADER_STRUCT_EPOCH]
    lea     rsi, [r12 + HEADER_OF_EPOCH]
    mov     edx, OBJECT_STAMP_SIZE
    call    er_preimage_encode_epoch

    ; Requirements
    lea     rdi, [r12 + HEADER_OF_REQUIREMENTS]
    lea     rsi, [rbx + HEADER_STRUCT_REQUIREMENTS]
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

    ; Reserved bytes must be zero
    lea     rdi, [r12 + HEADER_OF_RESERVED]
    mov     esi, OBJECT_HEADER_RESERVED_SIZE
    call    er_bytes_nonzero
    er_check_nonzero eax, .corrupt

    mov     rdi, r12
    mov     rsi, rbx
    call    _object_header_scalars_decode
    er_check_zero eax, .corrupt

    ; Epoch
    lea     rdi, [r12 + HEADER_OF_EPOCH]
    mov     esi, OBJECT_STAMP_SIZE
    lea     rdx, [rbx + HEADER_STRUCT_EPOCH]
    call    er_preimage_decode_epoch
    er_check_zero eax, .corrupt

    ; Requirements
    lea     rdi, [r12 + HEADER_OF_REQUIREMENTS]
    lea     rsi, [rbx + HEADER_STRUCT_REQUIREMENTS]
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
    lea     rdi, [r12 + OWNER_OF_KIND]
    mov     esi, [rbx + OWNER_STRUCT_KIND]
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

    lea     rdi, [r12 + OWNER_OF_KIND]
    call    er_load32
    mov     [rbx + OWNER_STRUCT_KIND], eax
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

    mov     rdi, rbx
    mov     rsi, r13
    call    _object_envelope_policy_matches
    er_check_zero eax, .bad_arg

.write:
    lea     rdi, [r12 + ENVELOPE_OF_KIND]
    mov     esi, [rbx + ENVELOPE_STRUCT_KIND]
    call    er_store32

    lea     rdi, [r12 + ENVELOPE_OF_OWNER_INDEX]
    movzx   esi, word [rbx + ENVELOPE_STRUCT_OWNER_INDEX]
    call    er_store16

    lea     rdi, [r12 + ENVELOPE_OF_ALGORITHM]
    movzx   esi, word [rbx + ENVELOPE_STRUCT_ALGORITHM]
    call    er_store16

    lea     rdi, [r12 + ENVELOPE_OF_FLAGS]
    mov     esi, [rbx + ENVELOPE_STRUCT_FLAGS]
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

    lea     rdi, [r12 + ENVELOPE_OF_KIND]
    call    er_load32
    mov     [rbx + ENVELOPE_STRUCT_KIND], eax
    mov     edi, eax
    call    _validate_envelope_kind
    er_check_zero eax, .corrupt

    lea     rdi, [r12 + ENVELOPE_OF_OWNER_INDEX]
    call    er_load16
    mov     [rbx + ENVELOPE_STRUCT_OWNER_INDEX], ax

    lea     rdi, [r12 + ENVELOPE_OF_ALGORITHM]
    call    er_load16
    mov     [rbx + ENVELOPE_STRUCT_ALGORITHM], ax
    mov     di, ax
    call    _validate_algorithm
    er_check_zero eax, .corrupt

    lea     rdi, [r12 + ENVELOPE_OF_FLAGS]
    call    er_load32
    mov     [rbx + ENVELOPE_STRUCT_FLAGS], eax

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

    mov     rdi, rbx
    mov     rsi, r12
    call    _object_envelope_policy_matches
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

    movzx   edi, word [rbx + CHILD_STRUCT_KIND]
    call    _validate_kind
    er_check_zero eax, .bad_arg

    cmp     qword [rbx + CHILD_STRUCT_LOGICAL_LEN], 0
    je      .bad_arg

    lea     rdi, [rbx + CHILD_STRUCT_REQUIREMENTS_HASH]
    call    _object_id_nonzero
    er_check_zero eax, .bad_arg

    lea     rdi, [r12 + CHILD_OF_OBJECT_ID]
    lea     rsi, [rbx + CHILD_STRUCT_OBJECT_ID]
    call    _object_copy_id

    ; Logical_offset
    lea     rdi, [r12 + CHILD_OF_LOGICAL_OFFSET]
    mov     rsi, [rbx + CHILD_STRUCT_LOGICAL_OFFSET]
    call    er_store64

    ; Logical_len
    lea     rdi, [r12 + CHILD_OF_LOGICAL_LEN]
    mov     rsi, [rbx + CHILD_STRUCT_LOGICAL_LEN]
    call    er_store64

    ; Kind
    lea     rdi, [r12 + CHILD_OF_KIND]
    movzx   esi, word [rbx + CHILD_STRUCT_KIND]
    call    er_store16

    ; Pad = 0
    lea     rdi, [r12 + CHILD_OF_PAD]
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
    lea     rdi, [r12 + CHILD_OF_PAD]
    call    er_load16
    er_check_nonzero eax, .corrupt

    lea     rdi, [rbx + CHILD_STRUCT_OBJECT_ID]
    lea     rsi, [r12 + CHILD_OF_OBJECT_ID]
    call    _object_copy_id

    ; Logical_offset
    lea     rdi, [r12 + CHILD_OF_LOGICAL_OFFSET]
    call    er_load64
    mov     [rbx + CHILD_STRUCT_LOGICAL_OFFSET], rax
    cmp     rax, r13
    jne     .corrupt

    ; Logical_len
    lea     rdi, [r12 + CHILD_OF_LOGICAL_LEN]
    call    er_load64
    mov     [rbx + CHILD_STRUCT_LOGICAL_LEN], rax
    er_check_zero rax, .corrupt

    ; Kind
    lea     rdi, [r12 + CHILD_OF_KIND]
    call    er_load16
    mov     [rbx + CHILD_STRUCT_KIND], ax
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
    cmp     di, OBJECT_KIND_ISA
    je      .no_children
    cmp     di, OBJECT_KIND_CODE
    je      .compute
    jmp     .check_tree
.no_children:
    er_check_nonzero r8, .bad_arg
    jmp     .compute
.check_tree:
    er_check_nonzero rsi, .bad_arg

.compute:
    mov     rax, OBJECT_HEADER_SIZE
    mov     r10, rsi

    mov     rdi, rdx
    mov     esi, OBJECT_OWNER_SIZE
    call    _object_size_add_section
    er_check_nonzero edx, .no_space

    mov     rdi, rcx
    mov     esi, OBJECT_ENVELOPE_SIZE
    call    _object_size_add_section
    er_check_nonzero edx, .no_space

    mov     rdi, r8
    mov     esi, OBJECT_CHILD_SIZE
    call    _object_size_add_section
    er_check_nonzero edx, .no_space

    add     rax, r10
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

; rax=current size, rdi=count, esi=item_size → rax=new size, edx=0 or no-space
_object_size_add_section:
    push    rbx
    mov     rbx, rdi
    imul    rbx, rsi
    jo      .no_space
    add     rax, rbx
    jc      .no_space
    pop     rbx
    er_ok
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
; er_object_write_code_node
; int er_object_write_code_node(uint8_t* out, uint64_t out_len,
;                               const uint8_t req[28], const void* epoch,
;                               const uint8_t* body, uint64_t body_len)
; rdi=out, rsi=out_len, rdx=req, rcx=epoch, r8=body, r9=body_len
; Returns eax=written bytes, edx=0 on success.
; ==================================================================
er_fn er_object_write_code_node
    mov     r10d, OBJECT_KIND_CODE
    jmp     _object_write_plain_body_node

; ==================================================================
; er_object_write_receipt_node
; int er_object_write_receipt_node(uint8_t* out, uint64_t out_len,
;                                  const uint8_t req[28], const void* epoch,
;                                  const uint8_t* body, uint64_t body_len)
; rdi=out, rsi=out_len, rdx=req, rcx=epoch, r8=body, r9=body_len
; Returns eax=written bytes, edx=0 on success.
; ==================================================================
er_fn er_object_write_receipt_node
    mov     r10d, OBJECT_KIND_RECEIPT
    jmp     _object_write_plain_body_node

; ==================================================================
; er_object_write_isa_node
; int er_object_write_isa_node(uint8_t* out, uint64_t out_len,
;                              const uint8_t req[28], const void* epoch,
;                              const uint8_t* body, uint64_t body_len)
; rdi=out, rsi=out_len, rdx=req, rcx=epoch, r8=body, r9=body_len
; Returns eax=written bytes, edx=0 on success.
; ==================================================================
er_fn er_object_write_isa_node
    mov     r10d, OBJECT_KIND_ISA

; _object_write_plain_body_node: r10d=object kind, other args match wrapper ABI.
_object_write_plain_body_node:
    er_frame_push_regs rbx, r12, r13, r14, r15
    sub     rsp, 160

    mov     r12, rdi            ; out
    mov     r13, rsi            ; out_len
    mov     r14, rdx            ; req
    mov     r15, rcx            ; epoch
    mov     [rsp + 128], r8     ; body
    mov     [rsp + 136], r9     ; body_len
    mov     [rsp + 144], r10    ; kind

    cmp     r10d, OBJECT_KIND_CODE
    jne     .check_isa
    mov     rdi, [rsp + 128]
    mov     rsi, [rsp + 136]
    call    er_code_validate_body
    er_check_nonzero edx, .writer_fail
    jmp     .size_check

.check_isa:
    cmp     r10d, OBJECT_KIND_ISA
    jne     .size_check
    mov     rdi, [rsp + 128]
    mov     rsi, [rsp + 136]
    call    er_isa_validate_body
    er_check_nonzero edx, .writer_fail

.size_check:
    mov     edi, [rsp + 144]
    mov     rsi, [rsp + 136]
    xor     edx, edx
    xor     ecx, ecx
    xor     r8d, r8d
    lea     r9, [rsp + 152]
    call    er_object_canonical_size
    er_check_zero eax, .writer_fail
    mov     rax, [rsp + 152]
    cmp     r13, rax
    jb      .no_space

    mov     rdi, rsp
    mov     esi, [rsp + 144]
    mov     rdx, [rsp + 136]
    mov     rcx, [rsp + 136]
    xor     r8d, r8d
    mov     r9, r14
    mov     r10, r15
    xor     r11d, r11d
    xor     eax, eax
    call    _object_fill_header

    mov     rdi, r12
    mov     rsi, rsp
    xor     edx, edx
    xor     ecx, ecx
    xor     r8d, r8d
    xor     r9d, r9d
    call    _object_write_header_sections
    er_check_zero eax, .writer_fail
    mov     rbx, rax

    lea     rdi, [r12 + rbx]
    mov     rsi, [rsp + 136]
    mov     rdx, [rsp + 128]
    call    _object_memcpy
    mov     rax, [rsp + 152]
    er_ok
    jmp     .return
.no_space:
    xor     eax, eax
    mov     edx, OBJECT_ERR_NO_SPACE
    jmp     .return
.writer_fail:
    test    edx, edx
    jnz     .writer_return_fail
    mov     edx, OBJECT_ERR_BAD_ARGUMENT
.writer_return_fail:
    xor     eax, eax
.return:
    add     rsp, 160
    er_pop  rbx, r12, r13, r14, r15
    er_frame_pop
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
    jmp     .return
.no_space:
    xor     eax, eax
    mov     edx, OBJECT_ERR_NO_SPACE
    jmp     .return
.writer_fail:
    ; Preserve the callee's error code when possible.
    test    edx, edx
    jnz     .writer_return_fail
    mov     edx, OBJECT_ERR_BAD_ARGUMENT
.writer_return_fail:
    xor     eax, eax
.return:
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
    mov     rdi, [rbp + 16]
    mov     rsi, rbx
    call    _object_child_array_ptr
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
    mov     rdi, [rbp + 16]
    mov     rsi, r15
    call    _object_child_array_ptr
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
    jmp     .return
.bad_arg:
    xor     eax, eax
    mov     edx, OBJECT_ERR_BAD_ARGUMENT
    jmp     .return
.no_space:
    xor     eax, eax
    mov     edx, OBJECT_ERR_NO_SPACE
    jmp     .return
.writer_fail:
    test    edx, edx
    jnz     .writer_return_fail
    mov     edx, OBJECT_ERR_BAD_ARGUMENT
.writer_return_fail:
    xor     eax, eax
.return:
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
;   +OBJECT_VIEW_BODY_PTR: body_ptr (8)
;   +OBJECT_VIEW_BODY_LEN: body_len (8)
;   +OBJECT_VIEW_HEADER: header (HEADER_STRUCT_SIZE)
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
    lea     rsi, [r14 + OBJECT_VIEW_HEADER]
    call    er_object_header_decode
    er_check_zero eax, .corrupt_pop

    movzx   ebx, word [r14 + OBJECT_VIEW_HEADER + HEADER_STRUCT_OWNER_COUNT]
    movzx   r8d, word [r14 + OBJECT_VIEW_HEADER + HEADER_STRUCT_ENVELOPE_COUNT]
    mov     r10d, [r14 + OBJECT_VIEW_HEADER + HEADER_STRUCT_CHILD_COUNT]
    mov     r9,  [r14 + OBJECT_VIEW_HEADER + HEADER_STRUCT_BODY_LEN]
    movzx   r15d, word [r14 + OBJECT_VIEW_HEADER + HEADER_STRUCT_KIND]
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
    mov     rdx, [r14 + OBJECT_VIEW_HEADER + HEADER_STRUCT_LOGICAL_LEN]
    cmp     rdx, [rsp + 176]
    jne     .corrupt_pop

.set_body:
    mov     rax, [rsp + 184]
    sub     rax, [rsp + 176]
    add     rax, r12
    mov     [r14 + OBJECT_VIEW_BODY_PTR], rax
    mov     rdx, [rsp + 176]
    mov     [r14 + OBJECT_VIEW_BODY_LEN], rdx

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

    mov     rax, [rsp + CHILD_STRUCT_LOGICAL_LEN]
    add     r11, rax
    jc      .corrupt_pop

    inc     r15d
    cmp     r15d, r10d
    jb      .cl

    cmp     word [r14 + OBJECT_VIEW_HEADER + HEADER_STRUCT_KIND], OBJECT_KIND_TREE
    jne     .success
    mov     rdx, [r14 + OBJECT_VIEW_HEADER + HEADER_STRUCT_LOGICAL_LEN]
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

; Header scalar helpers. rdi=canonical header, rsi=decoded header.
_object_header_scalars_encode:
    er_push rbx, r12
    mov     r12, rdi
    mov     rbx, rsi

    lea     rdi, [r12 + HEADER_OF_VERSION]
    mov     esi, 1
    call    er_store16

    lea     rdi, [r12 + HEADER_OF_KIND]
    movzx   esi, word [rbx + HEADER_STRUCT_KIND]
    call    er_store16

    lea     rdi, [r12 + HEADER_OF_FLAGS]
    mov     esi, [rbx + HEADER_STRUCT_FLAGS]
    call    er_store32

    lea     rdi, [r12 + HEADER_OF_LOGICAL_LEN]
    mov     rsi, [rbx + HEADER_STRUCT_LOGICAL_LEN]
    call    er_store64

    lea     rdi, [r12 + HEADER_OF_OWNER_COUNT]
    movzx   esi, word [rbx + HEADER_STRUCT_OWNER_COUNT]
    call    er_store16

    lea     rdi, [r12 + HEADER_OF_ENVELOPE_COUNT]
    movzx   esi, word [rbx + HEADER_STRUCT_ENVELOPE_COUNT]
    call    er_store16

    lea     rdi, [r12 + HEADER_OF_CHILD_COUNT]
    mov     esi, [rbx + HEADER_STRUCT_CHILD_COUNT]
    call    er_store32

    lea     rdi, [r12 + HEADER_OF_BODY_LEN]
    mov     rsi, [rbx + HEADER_STRUCT_BODY_LEN]
    call    er_store64

    er_pop  rbx, r12
    mov     eax, 1
    er_ok
    er_ret

; Header scalar decode validates version and kind. rdi=canonical, rsi=decoded.
_object_header_scalars_decode:
    er_push rbx, r12
    mov     r12, rdi
    mov     rbx, rsi

    lea     rdi, [r12 + HEADER_OF_VERSION]
    call    er_load16
    cmp     eax, 1
    jne     .corrupt

    lea     rdi, [r12 + HEADER_OF_KIND]
    call    er_load16
    mov     [rbx + HEADER_STRUCT_KIND], ax
    mov     di, ax
    call    _validate_kind
    er_check_zero eax, .corrupt

    lea     rdi, [r12 + HEADER_OF_FLAGS]
    call    er_load32
    mov     [rbx + HEADER_STRUCT_FLAGS], eax

    lea     rdi, [r12 + HEADER_OF_LOGICAL_LEN]
    call    er_load64
    mov     [rbx + HEADER_STRUCT_LOGICAL_LEN], rax

    lea     rdi, [r12 + HEADER_OF_OWNER_COUNT]
    call    er_load16
    mov     [rbx + HEADER_STRUCT_OWNER_COUNT], ax

    lea     rdi, [r12 + HEADER_OF_ENVELOPE_COUNT]
    call    er_load16
    mov     [rbx + HEADER_STRUCT_ENVELOPE_COUNT], ax

    lea     rdi, [r12 + HEADER_OF_CHILD_COUNT]
    call    er_load32
    mov     [rbx + HEADER_STRUCT_CHILD_COUNT], eax

    lea     rdi, [r12 + HEADER_OF_BODY_LEN]
    call    er_load64
    mov     [rbx + HEADER_STRUCT_BODY_LEN], rax

    er_pop  rbx, r12
    mov     eax, 1
    er_ok
    er_ret
.corrupt:
    er_pop  rbx, r12
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

; Array element pointer helpers. Return rax=base + index * element_size.
; rdi=array_base, rsi=index.
_object_owner_array_ptr:
    mov     rax, rsi
    imul    rax, OBJECT_OWNER_SIZE
    add     rax, rdi
    ret

_object_envelope_array_ptr:
    mov     rax, rsi
    imul    rax, OBJECT_ENVELOPE_SIZE
    add     rax, rdi
    ret

_object_child_array_ptr:
    mov     rax, rsi
    imul    rax, OBJECT_CHILD_SIZE
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
    mov     esi, OBJECT_STAMP_SIZE
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
    mov     rdi, r13
    mov     rsi, rbp
    call    _object_owner_array_ptr
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
    mov     rdi, r15
    mov     rsi, rbp
    call    _object_envelope_array_ptr
    movzx   ecx, word [rax + ENVELOPE_STRUCT_OWNER_INDEX]
    cmp     rcx, r14
    jae     .bad_arg
    mov     rdi, r13
    mov     rsi, rcx
    call    _object_owner_array_ptr
    mov     rdx, rax
    mov     rdi, r15
    mov     rsi, rbp
    call    _object_envelope_array_ptr
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

; ==================================================================
; er_isa_validate_body
; Validate a canonical instruction-set body.
; rdi=body, rsi=body_len
; returns eax=definition_count, edx=0 on success or object error.
; ==================================================================
er_fn er_isa_validate_body
    er_push rbx, r12, r13, r14, r15
    mov     r12, rdi
    mov     r13, rsi

    er_check_zero r12, .bad_arg
    cmp     r13, ISA_BODY_HEADER_SIZE
    jb      .bad_arg
    mov     rax, [r12 + ISA_BODY_OF_MAGIC]
    mov     rdx, ISA_BODY_MAGIC_QWORD
    cmp     rax, rdx
    jne     .bad_arg
    cmp     word [r12 + ISA_BODY_OF_VERSION], ISA_BODY_VERSION
    jne     .bad_arg
    movzx   eax, word [r12 + ISA_BODY_OF_ISA]
    cmp     eax, ISA_ID_X86_64
    jb      .unsupported
    cmp     eax, ISA_ID_WASM
    ja      .unsupported

    mov     r14d, [r12 + ISA_BODY_OF_DEF_COUNT]
    test    r14d, r14d
    jz      .bad_arg
    mov     rax, r14
    imul    rax, ISA_DEF_SIZE
    jo      .bad_arg
    add     rax, ISA_BODY_HEADER_SIZE
    jc      .bad_arg
    cmp     rax, r13
    jne     .bad_arg

    xor     ebx, ebx
    xor     r15d, r15d
.def_loop:
    cmp     ebx, r14d
    jae     .success
    mov     r9, rbx
    imul    r9, ISA_DEF_SIZE
    lea     r9, [r12 + ISA_BODY_HEADER_SIZE + r9]
    mov     eax, [r9 + ISA_DEF_OF_INSTRUCTION_ID]
    test    eax, eax
    jz      .bad_arg
    cmp     eax, r15d
    jbe     .bad_arg
    mov     r15d, eax
    cmp     word [r9 + ISA_DEF_OF_MNEMONIC_ID], 0
    je      .bad_arg
    cmp     word [r9 + ISA_DEF_OF_OPERAND_SHAPE], 0
    je      .bad_arg
    cmp     word [r9 + ISA_DEF_OF_ENCODING_SHAPE], 0
    je      .bad_arg
    cmp     byte [r9 + ISA_DEF_OF_INPUT_COUNT], 8
    ja      .bad_arg
    cmp     byte [r9 + ISA_DEF_OF_OUTPUT_COUNT], 8
    ja      .bad_arg
    cmp     byte [r9 + ISA_DEF_OF_IMPLICIT_COUNT], 16
    ja      .bad_arg
    cmp     byte [r9 + ISA_DEF_OF_RESERVED], 0
    jne     .bad_arg
    inc     ebx
    jmp     .def_loop
.success:
    mov     eax, r14d
    er_ok
    jmp     .done_out
.bad_arg:
    xor     eax, eax
    mov     edx, OBJECT_ERR_BAD_ARGUMENT
    jmp     .done_out
.unsupported:
    xor     eax, eax
    mov     edx, OBJECT_ERR_UNSUPPORTED
.done_out:
    er_pop  rbx, r12, r13, r14, r15
    ret

; ==================================================================
; er_code_validate_body
; Validate a canonical CODE body.
; rdi=body, rsi=body_len
; returns eax=record_count, edx=0 on success or object error.
; ==================================================================
er_fn er_code_validate_body
    er_push rbx, r12, r13, r14
    mov     r12, rdi
    mov     r13, rsi

    er_check_zero r12, .bad_arg
    cmp     r13, CODE_BODY_HEADER_SIZE
    jb      .bad_arg
    mov     rax, [r12 + CODE_BODY_OF_MAGIC]
    mov     rdx, CODE_BODY_MAGIC_QWORD
    cmp     rax, rdx
    jne     .bad_arg
    cmp     word [r12 + CODE_BODY_OF_VERSION], CODE_BODY_VERSION
    jne     .bad_arg
    cmp     word [r12 + CODE_BODY_OF_ISA], CODE_ISA_X86_64
    jne     .unsupported

    mov     r14d, [r12 + CODE_BODY_OF_RECORD_COUNT]
    mov     rax, r14
    imul    rax, CODE_RECORD_SIZE
    jo      .bad_arg
    add     rax, CODE_BODY_HEADER_SIZE
    jc      .bad_arg
    cmp     rax, r13
    jne     .bad_arg

    xor     ebx, ebx
.record_loop:
    cmp     ebx, r14d
    jae     .success
    mov     r9, rbx
    imul    r9, CODE_RECORD_SIZE
    lea     r9, [r12 + CODE_BODY_HEADER_SIZE + r9]
    movzx   eax, word [r9 + CODE_RECORD_OF_KIND]
    cmp     eax, CODE_RECORD_KIND_EXPORT
    je      .next
    cmp     eax, CODE_RECORD_KIND_IMPORT
    je      .next
    cmp     eax, CODE_RECORD_KIND_INSTR
    jne     .unsupported
    movzx   eax, word [r9 + CODE_RECORD_OF_OPCODE]
    cmp     eax, CODE_OP_X86_MOV_EAX_IMM32
    je      .next
    cmp     eax, CODE_OP_X86_RET
    je      .next
    jmp     .unsupported
.next:
    inc     ebx
    jmp     .record_loop
.success:
    mov     eax, r14d
    er_ok
    jmp     .done_out
.bad_arg:
    xor     eax, eax
    mov     edx, OBJECT_ERR_BAD_ARGUMENT
    jmp     .done_out
.unsupported:
    xor     eax, eax
    mov     edx, OBJECT_ERR_UNSUPPORTED
.done_out:
    er_pop  rbx, r12, r13, r14
    ret

; ==================================================================
; er_code_materialize_flat
; Materialize a canonical CODE body into flat x86_64 bytes.
; rdi=body, rsi=body_len, rdx=out, rcx=out_len, r8=receipt[32]
; returns eax=bytes written, edx=0 on success or object error.
; ==================================================================
er_fn er_code_materialize_flat
    er_push rbx, rbp, r12, r13, r14, r15
    mov     r12, rdi        ; body
    mov     r13, rsi        ; body_len
    mov     r14, rdx        ; out
    mov     r15, rcx        ; out_len
    mov     rbx, r8         ; receipt

    er_check_zero r14, .bad_arg
    er_check_zero rbx, .bad_arg
    mov     rdi, r12
    mov     rsi, r13
    call    er_code_validate_body
    er_check_nonzero edx, .done_out
    mov     r10d, eax

    xor     ebp, ebp        ; record index
    xor     r11d, r11d      ; output offset
.record_loop:
    cmp     ebp, r10d
    jae     .success
    mov     r9, rbp
    imul    r9, CODE_RECORD_SIZE
    lea     r9, [r12 + CODE_BODY_HEADER_SIZE + r9]

    movzx   eax, word [r9 + CODE_RECORD_OF_KIND]
    cmp     eax, CODE_RECORD_KIND_EXPORT
    je      .metadata_record
    cmp     eax, CODE_RECORD_KIND_IMPORT
    je      .metadata_record
    cmp     eax, CODE_RECORD_KIND_INSTR
    jne     .unsupported
    movzx   eax, word [r9 + CODE_RECORD_OF_OPCODE]
    cmp     eax, CODE_OP_X86_MOV_EAX_IMM32
    je      .mov_eax_imm32
    cmp     eax, CODE_OP_X86_RET
    je      .ret_instr
    jmp     .unsupported

.mov_eax_imm32:
    mov     rax, r11
    add     rax, 5
    jc      .no_space
    cmp     rax, r15
    ja      .no_space
    mov     byte [r14 + r11], 0xb8
    mov     eax, [r9 + CODE_RECORD_OF_IMM64]
    mov     [r14 + r11 + 1], eax
    add     r11, 5
    inc     ebp
    jmp     .record_loop

.ret_instr:
    mov     rax, r11
    inc     rax
    jc      .no_space
    cmp     rax, r15
    ja      .no_space
    mov     byte [r14 + r11], 0xc3
    inc     r11
    inc     ebp
    jmp     .record_loop

.metadata_record:
    inc     ebp
    jmp     .record_loop

.success:
    mov     rax, CODE_RECEIPT_MAGIC_QWORD
    mov     [rbx + CODE_RECEIPT_OF_MAGIC], rax
    mov     [rbx + CODE_RECEIPT_OF_RECORD_COUNT], r10
    mov     [rbx + CODE_RECEIPT_OF_OUTPUT_LEN], r11
    mov     qword [rbx + CODE_RECEIPT_OF_ISA], CODE_ISA_X86_64
    mov     rax, r11
    er_ok
    jmp     .done_out
.bad_arg:
    xor     eax, eax
    mov     edx, OBJECT_ERR_BAD_ARGUMENT
    jmp     .done_out
.unsupported:
    xor     eax, eax
    mov     edx, OBJECT_ERR_UNSUPPORTED
    jmp     .done_out
.no_space:
    xor     eax, eax
    mov     edx, OBJECT_ERR_NO_SPACE
.done_out:
    er_pop  rbx, rbp, r12, r13, r14, r15
    ret
