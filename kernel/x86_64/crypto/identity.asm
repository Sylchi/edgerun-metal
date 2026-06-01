; EdgeRun identity module — x86_64 assembly
; System V AMD64 ABI
; Freestanding — no libc, no external dependencies.

%include "x86_64/macros.inc"

extern er_blake3_hash_bytes
extern er_bytes_nonzero
extern er_bytes_eql
extern er_bytes_copy
extern er_store16
extern er_store32
extern er_keeper_id_valid
extern er_keeper_id_eql
extern er_stamp_valid
extern er_stamp_order

%define ID_SIZE                32
%define HASH_SIZE              32
%define MATERIAL_MAX           96
%define ED25519_PUBLIC_SIZE    32
%define P256_PUBLIC_SIZE       64
%define DELEGATION_MATERIAL_SIZE 96
%define EPOCH_SIZE             64
%define ID_DOMAIN_LEN          26
%define CHILD_DOMAIN_LEN       29
%define APP_SCOPE_DOMAIN_LEN   33

; ── SourceKind enum values (u16) ──
%define SOURCE_HASH                     1
%define SOURCE_ED25519_PUBLIC           2
%define SOURCE_P256_PUBLIC              3
%define SOURCE_TPM_P256_PUBLIC          4
%define SOURCE_OBJECT_ID                5
%define SOURCE_ENDPOINT                 6
%define SOURCE_DERIVED                  7
%define SOURCE_DELEGATION               8
%define SOURCE_ANDROID_KEYSTONE_P256    9

; ── Kind enum values (u16) ──
%define KIND_USER       1
%define KIND_DEVICE     2
%define KIND_APP        3
%define KIND_STORAGE    4
%define KIND_RELAY      5
%define KIND_RESOURCE   6
%define KIND_OBJECT     7
%define KIND_EPHEMERAL  8
%define KIND_DELEGATED  9

; ── InstantiationOperation enum values (u32) ──
%define OP_VERIFY            1
%define OP_SIGN              2
%define OP_VERIFY_AND_SIGN   3

; ── ID struct ──
struc er_identity_id
    .bytes: resb ID_SIZE
endstruc

; ── Source struct (112 bytes) ──
struc er_identity_source
    .kind:      resw 1      ; 0: SourceKind
    .pad0:      resb 6      ; 2: pad for material alignment
    .material:  resb MATERIAL_MAX  ; 8: material buffer
    .len:       resq 1      ; 104: material length
endstruc

; ── Identity struct (216 bytes) ──
struc er_identity
    .kind:    resw 1        ; 0: Kind
    .pad1:    resb 6        ; 2: pad for epoch alignment
    .epoch:   resb EPOCH_SIZE  ; 8: clock Stamp
    .id:      resb ID_SIZE  ; 72: computed Id
    .source:  resb er_identity_source_size  ; 104: Source
endstruc

SECTION .text

; ==================================================================
; Internal helper: check if material length is valid for source kind
; er_identity_material_len_valid(kind, len) → bool
; rdi=kind (u16), esi=len (u32)
; Returns eax=1 if len is valid for this source kind.
; ==================================================================
er_identity_material_len_valid:
    cmp     edi, SOURCE_HASH
    je      .len_hash
    cmp     edi, SOURCE_OBJECT_ID
    je      .len_hash
    cmp     edi, SOURCE_DERIVED
    je      .len_hash
    cmp     edi, SOURCE_ED25519_PUBLIC
    je      .len_ed25519
    cmp     edi, SOURCE_P256_PUBLIC
    je      .len_p256
    cmp     edi, SOURCE_TPM_P256_PUBLIC
    je      .len_p256
    cmp     edi, SOURCE_ANDROID_KEYSTONE_P256
    je      .len_p256
    cmp     edi, SOURCE_ENDPOINT
    je      .len_endpoint
    cmp     edi, SOURCE_DELEGATION
    je      .len_delegation
    jmp     .len_invalid

.len_hash:
    cmp     esi, HASH_SIZE
    je      .len_ok
    jmp     .len_invalid
.len_ed25519:
    cmp     esi, ED25519_PUBLIC_SIZE
    je      .len_ok
    jmp     .len_invalid
.len_p256:
    cmp     esi, P256_PUBLIC_SIZE
    je      .len_ok
    jmp     .len_invalid
.len_endpoint:
    er_check_zero esi, .len_invalid
    cmp     esi, MATERIAL_MAX
    ja      .len_invalid
    jmp     .len_ok
.len_delegation:
    cmp     esi, DELEGATION_MATERIAL_SIZE
    je      .len_ok
.len_invalid:
    xor     eax, eax
    er_ret
.len_ok:
    mov     eax, 1
    er_ret

; ==================================================================
; er_identity_kind_valid(kind) → bool
; rdi=kind (u16). Returns eax=1 if kind is in 1..9.
; ==================================================================
er_fn er_identity_kind_valid
    movzx   eax, di
    er_check_zero eax, .kv_fail
    cmp     eax, 9
    ja      .kv_fail
    mov     eax, 1
    er_ret
.kv_fail:
    xor     eax, eax
    er_ret

; ==================================================================
; er_identity_source_prepare — create a source from kind + material
; int er_identity_source_prepare(uint16_t kind,
;     const uint8_t* material, uint32_t material_len, void* out_source)
; rdi=kind (u16), esi=kind (lower ignored for u16)
; Wait — ABI: rdi=kind, rsi=material_ptr, rdx=material_len, rcx=out_source
; Actually for System V: rdi, rsi, rdx, rcx
;
; kind (u16) in di, material_ptr in rsi, material_len in rdx (u32), out_source in rcx
; But rcx is also used for 4th arg. Let me use: rdi=kind, rsi=material, edx=len, rcx=out
; ==================================================================
er_fn er_identity_source_prepare
    er_push rbx, r12, r13, r14

    mov     r12d, edi           ; kind (u16)
    mov     r13, rsi            ; material ptr
    mov     r14d, edx           ; material_len
    mov     rbx, rcx            ; out_source

    ; Check material_len valid for kind
    mov     edi, r12d
    mov     esi, r14d
    call    er_identity_material_len_valid
    er_check_zero eax, .sp_fail

    ; Check material nonzero
    mov     rdi, r13
    mov     esi, r14d
    call    er_bytes_nonzero
    er_check_zero eax, .sp_fail

    ; Fill source.kind
    mov     [rbx + er_identity_source.kind], r12w

    ; Copy material
    lea     rdi, [rbx + er_identity_source.material]
    mov     esi, MATERIAL_MAX   ; dst_len
    mov     rdx, r13            ; src
    mov     ecx, r14d           ; src_len
    call    er_bytes_copy

    ; Set source.len
    mov     [rbx + er_identity_source.len], r14

    er_pop  rbx, r12, r13, r14
    er_ok
    mov     eax, 1
    er_ret
.sp_fail:
    xor     eax, eax
    er_pop  rbx, r12, r13, r14
    er_ret

; ==================================================================
; er_identity_source_prepare_delegation — create delegation source
; int er_identity_source_prepare_delegation(const uint8_t parent_id[32],
;     const uint8_t delegate_id[32], const uint8_t scope_hash[32],
;     void* out_source)
; rdi=parent_id, rsi=delegate_id, rdx=scope_hash, rcx=out_source
; ==================================================================
er_fn er_identity_source_prepare_delegation
    er_push rbx, r12, r13, r14, r15

    mov     r12, rdi            ; parent_id
    mov     r13, rsi            ; delegate_id
    mov     r14, rdx            ; scope_hash
    mov     r15, rcx            ; out_source

    ; Validate parent, delegate, scope_hash all nonzero
    mov     rdi, r12
    mov     esi, ID_SIZE
    call    er_bytes_nonzero
    er_check_zero eax, .spd_fail

    mov     rdi, r13
    mov     esi, ID_SIZE
    call    er_bytes_nonzero
    er_check_zero eax, .spd_fail

    mov     rdi, r14
    mov     esi, HASH_SIZE
    call    er_bytes_nonzero
    er_check_zero eax, .spd_fail

    ; Fill source.kind = DELEGATION
    mov     word [r15 + er_identity_source.kind], SOURCE_DELEGATION

    ; Copy parent_id to material[0..32]
    lea     rdi, [r15 + er_identity_source.material]
    mov     esi, DELEGATION_MATERIAL_SIZE
    mov     rdx, r12
    mov     ecx, ID_SIZE
    call    er_bytes_copy

    ; Copy delegate_id to material[32..64]
    lea     rdi, [r15 + er_identity_source.material + 32]
    mov     esi, DELEGATION_MATERIAL_SIZE - 32
    mov     rdx, r13
    mov     ecx, ID_SIZE
    call    er_bytes_copy

    ; Copy scope_hash to material[64..96]
    lea     rdi, [r15 + er_identity_source.material + 64]
    mov     esi, DELEGATION_MATERIAL_SIZE - 64
    mov     rdx, r14
    mov     ecx, HASH_SIZE
    call    er_bytes_copy

    ; Set source.len = 96
    mov     qword [r15 + er_identity_source.len], DELEGATION_MATERIAL_SIZE

    er_pop  rbx, r12, r13, r14, r15
    er_ok
    mov     eax, 1
    er_ret
.spd_fail:
    xor     eax, eax
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; ==================================================================
; er_identity_source_valid(source) → bool
; rdi=source
; ==================================================================
er_fn er_identity_source_valid
    push    r12
    mov     r12, rdi

    movzx   edi, word [r12 + er_identity_source.kind]
    mov     esi, [r12 + er_identity_source.len]
    call    er_identity_material_len_valid
    er_check_zero eax, .sv_fail

    lea     rdi, [r12 + er_identity_source.material]
    mov     esi, [r12 + er_identity_source.len]
    call    er_bytes_nonzero
    test    eax, eax
    pop     r12
    er_ret          ; returns eax from er_bytes_nonzero
.sv_fail:
    xor     eax, eax
    pop     r12
    er_ret

; ==================================================================
; er_identity_source_id — compute Id from source via BLAKE3
; int er_identity_source_id(const void* source, uint8_t out_id[32])
; rdi=source, rsi=out_id
; Computes: blake3("edgerun:zig:v1:identity-id" (26 bytes) ++ header(4) ++ material)
; ==================================================================
er_fn er_identity_source_id
    er_push rbx, r12, r13

    mov     r12, rdi            ; source
    mov     r13, rsi            ; out_id

    cmp     word [r12 + er_identity_source.kind], SOURCE_ED25519_PUBLIC
    je      .si_ed25519_public

    ; Total prefix: domain(26) + header(4) = 30
    ; Total input: 30 + source.len
    mov     eax, [r12 + er_identity_source.len]
    add     eax, 30
    cmp     eax, 4096           ; sanity check (matches PREIMAGE_BUFFER_SIZE)
    ja      .si_fail

    sub     rsp, 4096

    ; Copy domain string
    mov     rdi, rsp
    mov     esi, ID_DOMAIN_LEN
    lea     rdx, [rel .id_domain]
    call    _id_memcpy

    ; Build and copy header (4 bytes: kind LE[2] + len LE[2])
    movzx   eax, word [r12 + er_identity_source.kind]
    mov     [rsp + ID_DOMAIN_LEN], ax
    mov     eax, [r12 + er_identity_source.len]
    mov     [rsp + ID_DOMAIN_LEN + 2], ax     ; only low 16 bits of len

    ; Save total_len = ID_DOMAIN_LEN + 4 + material_len
    mov     ebx, eax           ; eax had material_len from the load above
    add     ebx, ID_DOMAIN_LEN + 4

    ; Copy material
    mov     rdi, rsp
    add     rdi, ID_DOMAIN_LEN + 4
    mov     esi, [r12 + er_identity_source.len]
    lea     rdx, [r12 + er_identity_source.material]
    call    _id_memcpy

    ; Hash
    mov     rdi, rsp
    mov     esi, ebx            ; total_len = 33 + material_len
    mov     rdx, r13
    call    er_blake3_hash_bytes

    add     rsp, 4096

    er_pop  rbx, r12, r13
    er_ok
    mov     eax, 1
    er_ret
.si_ed25519_public:
    mov     rdi, r13
    mov     esi, ID_SIZE
    lea     rdx, [r12 + er_identity_source.material]
    mov     ecx, ID_SIZE
    call    er_bytes_copy
    er_pop  rbx, r12, r13
    er_ok
    mov     eax, 1
    er_ret
.si_fail:
    xor     eax, eax
    er_pop  rbx, r12, r13
    er_ret

.id_domain: db "edgerun:zig:v1:identity-id"

; ==================================================================
; er_identity_init — create an Identity
; int er_identity_init(uint16_t kind, const void* source,
;                      const void* epoch, void* out_identity)
; rdi=kind, rsi=source, rdx=epoch, rcx=out_identity
; ==================================================================
er_fn er_identity_init
    er_push rbx, r12, r13, r14, r15

    mov     r12w, di            ; kind
    mov     r13, rsi            ; source
    mov     r14, rdx            ; epoch
    mov     r15, rcx            ; out_identity

    ; Validate kind
    movzx   edi, r12w
    call    er_identity_kind_valid
    er_check_zero eax, .ii_fail

    ; Validate source
    mov     rdi, r13
    call    er_identity_source_valid
    er_check_zero eax, .ii_fail

    ; Validate epoch
    mov     rdi, r14
    call    er_stamp_valid
    er_check_zero eax, .ii_fail

    ; Compute source.id
    mov     rdi, r13
    lea     rsi, [r15 + er_identity.id]
    call    er_identity_source_id
    er_check_zero eax, .ii_fail

    ; Fill identity.kind
    mov     [r15 + er_identity.kind], r12w

    ; Copy epoch
    lea     rdi, [r15 + er_identity.epoch]
    mov     esi, EPOCH_SIZE
    mov     rdx, r14
    call    _id_memcpy

    ; Copy source
    lea     rdi, [r15 + er_identity.source]
    mov     esi, er_identity_source_size
    mov     rdx, r13
    call    _id_memcpy

    er_pop  rbx, r12, r13, r14, r15
    er_ok
    mov     eax, 1
    er_ret
.ii_fail:
    xor     eax, eax
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; ==================================================================
; er_identity_valid(const void* identity) → bool
; rdi=identity
; ==================================================================
er_fn er_identity_valid
    er_push rbx, r12

    mov     r12, rdi

    ; epoch.valid()
    lea     rdi, [r12 + er_identity.epoch]
    call    er_stamp_valid
    er_check_zero eax, .iv_fail

    ; kind.valid()
    movzx   edi, word [r12 + er_identity.kind]
    call    er_identity_kind_valid
    er_check_zero eax, .iv_fail

    ; id.valid()
    lea     rdi, [r12 + er_identity.id]
    call    er_keeper_id_valid
    er_check_zero eax, .iv_fail

    ; source.valid()
    lea     rdi, [r12 + er_identity.source]
    call    er_identity_source_valid
    er_check_zero eax, .iv_fail

    ; id.eql(source.id())
    ; Compute source.id() on stack, compare
    sub     rsp, 32
    lea     rdi, [r12 + er_identity.source]
    mov     rsi, rsp
    call    er_identity_source_id
    er_check_zero eax, .iv_pop_fail

    lea     rdi, [r12 + er_identity.id]
    mov     esi, ID_SIZE
    mov     rdx, rsp
    mov     ecx, ID_SIZE
    call    er_bytes_eql
    add     rsp, 32
    er_check_zero eax, .iv_fail

    er_pop  rbx, r12
    er_ok
    mov     eax, 1
    er_ret
.iv_pop_fail:
    add     rsp, 32
.iv_fail:
    xor     eax, eax
    er_pop  rbx, r12
    er_ret

; ==================================================================
; er_identity_eql(const void* a, const void* b) → bool
; rdi=a, rsi=b
; ==================================================================
er_fn er_identity_eql
    er_push rbx, r12, r13

    mov     r12, rdi
    mov     r13, rsi

    ; Both must be valid first
    mov     rdi, r12
    call    er_identity_valid
    er_check_zero eax, .ie_false
    mov     rdi, r13
    call    er_identity_valid
    er_check_zero eax, .ie_false

    ; kind comparison
    movzx   eax, word [r12 + er_identity.kind]
    movzx   ebx, word [r13 + er_identity.kind]
    cmp     eax, ebx
    jne     .ie_false

    ; epoch order
    lea     rdi, [r12 + er_identity.epoch]
    lea     rsi, [r13 + er_identity.epoch]
    call    er_stamp_order
    er_check_nonzero eax, .ie_false

    ; source kind comparison
    movzx   eax, word [r12 + er_identity.source + er_identity_source.kind]
    movzx   ebx, word [r13 + er_identity.source + er_identity_source.kind]
    cmp     eax, ebx
    jne     .ie_false

    ; source len comparison
    mov     rax, [r12 + er_identity.source + er_identity_source.len]
    mov     rbx, [r13 + er_identity.source + er_identity_source.len]
    cmp     rax, rbx
    jne     .ie_false

    ; id eql
    lea     rdi, [r12 + er_identity.id]
    mov     esi, ID_SIZE
    lea     rdx, [r13 + er_identity.id]
    mov     ecx, ID_SIZE
    call    er_bytes_eql
    er_check_zero eax, .ie_false

    ; source active bytes eql
    lea     rdi, [r12 + er_identity.source + er_identity_source.material]
    mov     esi, [r12 + er_identity.source + er_identity_source.len]
    lea     rdx, [r13 + er_identity.source + er_identity_source.material]
    mov     ecx, [r13 + er_identity.source + er_identity_source.len]
    call    er_bytes_eql
    er_check_zero eax, .ie_false

    er_pop  rbx, r12, r13
    er_ok
    mov     eax, 1
    er_ret
.ie_false:
    xor     eax, eax
    er_pop  rbx, r12, r13
    er_ret

; ==================================================================
; er_identity_instantiate — create a non-derived/non-delegated Identity
; int er_identity_instantiate(uint16_t kind, uint16_t source_kind,
;     const uint8_t* material, uint32_t material_len,
;     const void* epoch, void* out_identity)
; rdi=kind, rsi=source_kind, rdx=material, rcx=material_len, r8=epoch, r9=out
; ==================================================================
er_fn er_identity_instantiate
    er_push rbx, r12, r13, r14, r15
    push    r8

    mov     r12d, edi           ; kind
    mov     r13d, esi           ; source_kind
    mov     r14, rdx            ; material
    mov     r15d, ecx           ; material_len
    mov     rbx, r9             ; out_identity

    cmp     r13d, SOURCE_DELEGATION
    je      .inst_fail
    cmp     r13d, SOURCE_DERIVED
    je      .inst_fail

    sub     rsp, er_identity_source_size
    mov     edi, r13d
    mov     rsi, r14
    mov     edx, r15d
    mov     rcx, rsp
    call    er_identity_source_prepare
    er_check_zero eax, .inst_pop_fail

    mov     edi, r12d
    mov     rsi, rsp
    mov     rdx, [rsp + er_identity_source_size]
    mov     rcx, rbx
    call    er_identity_init
    add     rsp, er_identity_source_size
    pop     r8
    er_pop  rbx, r12, r13, r14, r15
    er_ret
.inst_pop_fail:
    add     rsp, er_identity_source_size
.inst_fail:
    xor     eax, eax
    pop     r8
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; ==================================================================
; er_identity_derive_child — derive a child identity from a valid parent.
; int er_identity_derive_child(const void* parent, uint16_t child_kind,
;     const void* epoch, const uint8_t* label, uint32_t label_len,
;     const uint8_t* material, uint32_t material_len, void* out_identity)
; rdi=parent, rsi=child_kind, rdx=epoch, rcx=label, r8=label_len, r9=material
; stack: [rbp+16]=material_len, [rbp+24]=out_identity
; ==================================================================
er_fn er_identity_derive_child
    er_frame_push_regs rbx, r12, r13, r14, r15
    push    r9

    mov     r12, rdi            ; parent
    mov     r13d, esi           ; child_kind
    mov     r14, rdx            ; epoch
    mov     r15, rcx            ; label
    mov     ebx, r8d            ; label_len

    mov     rdi, r12
    call    er_identity_valid
    er_check_zero eax, .dc_fail

    mov     rdi, r14
    call    er_stamp_valid
    er_check_zero eax, .dc_fail

    mov     rdi, r15
    mov     esi, ebx
    call    er_bytes_nonzero
    er_check_zero eax, .dc_fail

    mov     rdi, [rbp - 48]
    mov     esi, [rbp + 16]
    call    er_bytes_nonzero
    er_check_zero eax, .dc_fail

    mov     eax, CHILD_DOMAIN_LEN + ID_SIZE + 2
    add     eax, ebx
    add     eax, [rbp + 16]
    cmp     eax, 4096
    ja      .dc_fail

    sub     rsp, 4096 + HASH_SIZE + er_identity_source_size
    mov     r10, rsp                            ; input buffer
    lea     r11, [rsp + 4096]                   ; child material hash
    lea     rdx, [rsp + 4096 + HASH_SIZE]       ; derived source

    mov     rdi, r10
    mov     esi, CHILD_DOMAIN_LEN
    lea     rdx, [rel .child_domain]
    call    _id_memcpy

    lea     rdi, [r10 + CHILD_DOMAIN_LEN]
    mov     esi, ID_SIZE
    lea     rdx, [r12 + er_identity.id]
    call    _id_memcpy

    mov     [r10 + CHILD_DOMAIN_LEN + ID_SIZE], r13w

    lea     rdi, [r10 + CHILD_DOMAIN_LEN + ID_SIZE + 2]
    mov     esi, ebx
    mov     rdx, r15
    call    _id_memcpy

    lea     rdi, [r10 + CHILD_DOMAIN_LEN + ID_SIZE + 2]
    add     rdi, rbx
    mov     esi, [rbp + 16]
    mov     rdx, [rbp - 48]
    call    _id_memcpy

    mov     eax, CHILD_DOMAIN_LEN + ID_SIZE + 2
    add     eax, ebx
    add     eax, [rbp + 16]
    mov     rdi, rsp
    mov     esi, eax
    lea     rdx, [rsp + 4096]
    call    er_blake3_hash_bytes
    er_check_zero eax, .dc_pop_fail

    mov     edi, SOURCE_DERIVED
    lea     rsi, [rsp + 4096]
    mov     edx, HASH_SIZE
    lea     rcx, [rsp + 4096 + HASH_SIZE]
    call    er_identity_source_prepare
    er_check_zero eax, .dc_pop_fail

    mov     edi, r13d
    lea     rsi, [rsp + 4096 + HASH_SIZE]
    mov     rdx, r14
    mov     rcx, [rbp + 24]
    call    er_identity_init
    add     rsp, 4096 + HASH_SIZE + er_identity_source_size
    pop     r9
    er_pop  rbx, r12, r13, r14, r15
    er_frame_pop
    er_ret
.dc_pop_fail:
    add     rsp, 4096 + HASH_SIZE + er_identity_source_size
.dc_fail:
    xor     eax, eax
    pop     r9
    er_pop  rbx, r12, r13, r14, r15
    er_frame_pop
    er_ret

.child_domain: db "edgerun:zig:v1:identity-child"

; ==================================================================
; er_identity_instantiate_app — derive delegated app identity.
; int er_identity_instantiate_app(const void* parent,
;     const uint8_t* app_material, uint32_t app_material_len,
;     const uint8_t* scope_hash, uint32_t scope_hash_len,
;     const void* epoch, uint32_t operation, void* out_identity)
; rdi=parent, rsi=app_material, rdx=app_material_len, rcx=scope_hash,
; r8=scope_hash_len, r9=epoch, stack: [rbp+16]=operation, [rbp+24]=out
; ==================================================================
er_fn er_identity_instantiate_app
    er_frame_push_regs rbx, r12, r13, r14, r15
    push    r9

    mov     r12, rdi            ; parent
    mov     r13, rsi            ; app_material
    mov     r14d, edx           ; app_material_len
    mov     r15, rcx            ; scope_hash
    mov     ebx, r8d            ; scope_hash_len

    mov     rdi, r12
    call    er_identity_valid
    er_check_zero eax, .ia_fail

    cmp     ebx, HASH_SIZE
    jne     .ia_fail
    mov     rdi, r15
    mov     esi, HASH_SIZE
    call    er_bytes_nonzero
    er_check_zero eax, .ia_fail

    mov     rdi, [rbp - 48]
    call    er_stamp_valid
    er_check_zero eax, .ia_fail

    sub     rsp, er_identity_source_size + er_identity_size + 4096 + HASH_SIZE + er_identity_source_size
    mov     edi, SOURCE_HASH
    mov     rsi, r13
    mov     edx, r14d
    mov     rcx, rsp
    call    er_identity_source_prepare
    er_check_zero eax, .ia_pop_fail

    mov     edi, KIND_APP
    mov     rsi, rsp
    mov     rdx, [rbp - 48]
    lea     rcx, [rsp + er_identity_source_size]
    call    er_identity_init
    er_check_zero eax, .ia_pop_fail

    lea     r10, [rsp + er_identity_source_size + er_identity_size]

    mov     rdi, r10
    mov     esi, APP_SCOPE_DOMAIN_LEN
    lea     rdx, [rel .app_scope_domain]
    call    _id_memcpy

    mov     eax, [rbp + 16]
    mov     [r10 + APP_SCOPE_DOMAIN_LEN], eax

    lea     rdi, [r10 + APP_SCOPE_DOMAIN_LEN + 4]
    mov     esi, HASH_SIZE
    mov     rdx, r15
    call    _id_memcpy

    mov     rdi, r10
    mov     esi, APP_SCOPE_DOMAIN_LEN + 4 + HASH_SIZE
    lea     rdx, [rsp + er_identity_source_size + er_identity_size + 4096]
    call    er_blake3_hash_bytes
    er_check_zero eax, .ia_pop_fail

    lea     rcx, [rsp + er_identity_source_size + er_identity_size + 4096 + HASH_SIZE]
    lea     rsi, [rsp + er_identity_source_size + er_identity.id]
    lea     rdi, [r12 + er_identity.id]
    lea     rdx, [rsp + er_identity_source_size + er_identity_size + 4096]
    call    er_identity_source_prepare_delegation
    er_check_zero eax, .ia_pop_fail

    mov     edi, KIND_DELEGATED
    lea     rsi, [rsp + er_identity_source_size + er_identity_size + 4096 + HASH_SIZE]
    mov     rdx, [rbp - 48]
    mov     rcx, [rbp + 24]
    call    er_identity_init
    add     rsp, er_identity_source_size + er_identity_size + 4096 + HASH_SIZE + er_identity_source_size
    pop     r9
    er_pop  rbx, r12, r13, r14, r15
    er_frame_pop
    er_ret
.ia_pop_fail:
    add     rsp, er_identity_source_size + er_identity_size + 4096 + HASH_SIZE + er_identity_source_size
.ia_fail:
    xor     eax, eax
    pop     r9
    er_pop  rbx, r12, r13, r14, r15
    er_frame_pop
    er_ret

.app_scope_domain: db "edgerun:zig:v1:identity-app-scope"

; ==================================================================
; Internal helper: _id_memcpy(rdi=dst, esi=len, rdx=src)
_id_memcpy:
    er_check_zero esi, .mdone
    xor     ecx, ecx
.mloop:
    mov     al, [rdx + rcx]
    mov     [rdi + rcx], al
    inc     ecx
    cmp     ecx, esi
    jb      .mloop
.mdone:
    ret

; vim: set ft=nasm:
