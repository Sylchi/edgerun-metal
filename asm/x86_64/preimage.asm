; EdgeRun preimage (domain-separated BLAKE3 hashing) — x86_64 assembly
; System V AMD64 ABI
; Freestanding — no libc, no external dependencies.

%include "x86_64/macros.inc"

extern er_blake3_hash_bytes
extern er_bytes_zero
extern er_store64
extern er_stamp_valid
extern er_keeper_id_valid

%define PREIMAGE_HASH_SIZE     32
%define PREIMAGE_BUFFER_SIZE   4096
%define KEEPER_ID_SIZE         32
%define EPOCH_SIZE             64

; Preimage builder state structure offsets (4112 bytes)
struc er_preimage_state
    .buffer:    resb PREIMAGE_BUFFER_SIZE
    .pos:       resd 1          ; current write position
    .domain_len: resd 1         ; length of domain prefix
    .pad:       resq 1          ; align to 16
endstruc

; Preimage writer state structure offsets (24 bytes)
struc er_preimage_writer
    .buf:       resq 1          ; pointer to buffer
    .len:       resq 1          ; buffer capacity
    .pos:       resq 1          ; current write position
endstruc

SECTION .text

; ==================================================================
; er_preimage_hash — one-shot domain-separated BLAKE3 hash
; int er_preimage_hash(const void* domain, uint32_t domain_len,
;                      const void* value, uint32_t value_len,
;                      uint8_t out[32])
;
; rdi=domain, esi=domain_len, rdx=value, ecx=value_len, r8=out
; Returns eax=1 on success, 0 on error (overflow).
; ==================================================================
er_fn er_preimage_hash
    push    r12
    push    r13
    push    r14
    push    r15
    push    rbx

    mov     r12, rdi            ; domain
    mov     r13d, esi           ; domain_len
    mov     r14, rdx            ; value
    mov     r15d, ecx           ; value_len
    mov     rbx, r8             ; out

    mov     eax, r13d
    add     eax, r15d
    jc      .overflow
    cmp     eax, PREIMAGE_BUFFER_SIZE
    ja      .overflow
    mov     r8d, eax            ; total_len

    sub     rsp, PREIMAGE_BUFFER_SIZE
    mov     rdi, rsp
    mov     esi, r13d
    mov     rdx, r12
    call    er_preimage_memcpy
    mov     rdi, rsp
    add     rdi, r13
    mov     esi, r15d
    mov     rdx, r14
    call    er_preimage_memcpy

    mov     rdi, rsp
    mov     esi, r8d
    mov     rdx, rbx
    call    er_blake3_hash_bytes

    add     rsp, PREIMAGE_BUFFER_SIZE
    pop     rbx
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    er_ok
    mov     eax, 1
    er_ret

.overflow:
    xor     eax, eax
    pop     rbx
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    er_ok
    er_ret

; ==================================================================
; er_preimage_raw_hash — one-shot BLAKE3 hash without domain
; int er_preimage_raw_hash(const void* value, uint32_t value_len,
;                          uint8_t out[32])
;
; rdi=value, esi=value_len, rdx=out
; Returns eax=1 on success, 0 on error.
; ==================================================================
er_fn er_preimage_raw_hash
    call    er_blake3_hash_bytes
    mov     eax, 1
    er_ret

; ==================================================================
; er_preimage_builder_init — initialize a preimage builder
; void er_preimage_builder_init(void* state, const void* domain,
;                               uint32_t domain_len)
; rdi=state (er_preimage_state), rsi=domain, edx=domain_len
; ==================================================================
er_fn er_preimage_builder_init
    push    rbx
    push    r12
    push    r13

    mov     r12, rdi            ; state
    mov     r13, rsi            ; domain
    mov     ebx, edx            ; domain_len

    mov     [r12 + er_preimage_state.pos], ebx
    mov     [r12 + er_preimage_state.domain_len], ebx

    ; Copy domain into state.buffer
    lea     rdi, [r12 + er_preimage_state.buffer]
    mov     esi, ebx
    mov     rdx, r13
    call    er_preimage_memcpy

    pop     r13
    pop     r12
    pop     rbx
    er_ret

; ==================================================================
; er_preimage_builder_update — append data to builder
; int er_preimage_builder_update(void* state, const void* data,
;                                uint32_t data_len)
; rdi=state, rsi=data, edx=data_len
; Returns eax=1 on success, 0 if buffer would overflow.
; ==================================================================
er_fn er_preimage_builder_update
    push    rbx
    push    r12
    push    r13

    mov     r12, rdi            ; state
    mov     r13, rsi            ; data
    mov     ebx, edx            ; data_len

    mov     eax, [r12 + er_preimage_state.pos]
    add     eax, ebx
    jc      .update_overflow
    cmp     eax, PREIMAGE_BUFFER_SIZE
    ja      .update_overflow

    ; Copy data into buffer at current pos
    mov     edi, [r12 + er_preimage_state.pos]
    lea     rdi, [r12 + rdi + er_preimage_state.buffer]
    mov     esi, ebx
    mov     rdx, r13
    call    er_preimage_memcpy

    ; Update pos
    add     [r12 + er_preimage_state.pos], ebx

    pop     r13
    pop     r12
    pop     rbx
    er_ok
    mov     eax, 1
    er_ret

.update_overflow:
    xor     eax, eax
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; ==================================================================
; er_preimage_builder_final — finalize and produce hash
; int er_preimage_builder_final(void* state, uint8_t out[32])
; rdi=state, rsi=out
; Returns eax=1.
; ==================================================================
er_fn er_preimage_builder_final
    push    rbx
    push    r12

    mov     r12, rdi            ; state
    mov     rbx, rsi            ; out

    lea     rdi, [r12 + er_preimage_state.buffer]
    mov     esi, [r12 + er_preimage_state.pos]
    mov     rdx, rbx
    call    er_blake3_hash_bytes

    pop     r12
    pop     rbx
    er_ok
    mov     eax, 1
    er_ret

; ==================================================================
; er_preimage_builder_id — append an identity Id (32 bytes) to builder
; void er_preimage_builder_id(void* state, const uint8_t id[32])
; rdi=state, rsi=id
; ==================================================================
er_fn er_preimage_builder_id
    mov     edx, 32
    jmp     er_preimage_builder_update_tail

; ==================================================================
; er_preimage_builder_hash — append a Hash (32 bytes) to builder
; void er_preimage_builder_hash(void* state, const uint8_t hash[32])
; rdi=state, rsi=hash
; ==================================================================
er_fn er_preimage_builder_hash
    mov     edx, 32
    ; fall through to er_preimage_builder_update_tail

; Tail call helper for builder methods: rdi=state, rsi=data, edx=len
; Returns eax=1 on success, 0 on overflow.
global er_preimage_builder_update_tail
er_preimage_builder_update_tail:
    jmp     er_preimage_builder_update

; ==================================================================
; er_preimage_builder_write_u64 — append a u64 in LE to builder
; void er_preimage_builder_write_u64(void* state, uint64_t value)
; rdi=state, rsi=value
; ==================================================================
er_fn er_preimage_builder_write_u64
    push    r12
    sub     rsp, 8
    mov     [rsp], rsi
    mov     r12, rdi            ; save state
    mov     rsi, rsp
    mov     edx, 8
    mov     rdi, r12
    call    er_preimage_builder_update
    add     rsp, 8
    pop     r12
    er_ret

; ==================================================================
; er_preimage_encode_epoch — serialize stamp to 64 bytes
; int er_preimage_encode_epoch(const void* stamp, uint8_t out[64], uint32_t out_len)
; rdi=stamp, rsi=out, edx=out_len
; Returns eax=1 on success, 0 on failure. rdx=0 on success.
; ==================================================================
er_fn er_preimage_encode_epoch
    push    rbx
    push    r12
    push    r13

    mov     r12, rdi            ; stamp
    mov     r13, rsi            ; out
    mov     ebx, edx            ; out_len

    cmp     ebx, EPOCH_SIZE
    jb      .ee_fail

    call    er_stamp_valid
    test    eax, eax
    jz      .ee_fail

    ; Copy keeper (32 bytes) — from stamp to out
    mov     rdi, r13            ; dst = out
    mov     esi, KEEPER_ID_SIZE
    mov     rdx, r12            ; src = stamp
    call    er_preimage_memcpy

    ; Store tick
    mov     rdi, r13
    add     rdi, 32
    mov     rsi, [r12 + 32]
    call    er_store64

    ; Store slot
    mov     rdi, r13
    add     rdi, 40
    mov     rsi, [r12 + 40]
    call    er_store64

    ; Store epoch
    mov     rdi, r13
    add     rdi, 48
    mov     rsi, [r12 + 48]
    call    er_store64

    ; Store era
    mov     rdi, r13
    add     rdi, 56
    mov     rsi, [r12 + 56]
    call    er_store64

    pop     r13
    pop     r12
    pop     rbx
    er_ok
    mov     eax, 1
    er_ret
.ee_fail:
    pop     r13
    pop     r12
    pop     rbx
    xor     eax, eax
    er_ret

; ==================================================================
; er_preimage_decode_epoch — deserialize stamp from 64 bytes
; int er_preimage_decode_epoch(const uint8_t in[64], uint32_t in_len, void* stamp)
; rdi=in, esi=in_len, rdx=stamp
; Returns eax=1 on success, 0 if in too short or stamp invalid. rdx=0.
; ==================================================================
er_fn er_preimage_decode_epoch
    push    rbx
    push    r12
    push    r13

    mov     r12, rdi            ; in
    mov     ebx, esi            ; in_len
    mov     r13, rdx            ; stamp

    cmp     ebx, EPOCH_SIZE
    jb      .de_fail

    ; Copy keeper (32 bytes)
    mov     rdi, r13
    mov     esi, KEEPER_ID_SIZE
    mov     rdx, r12
    call    er_preimage_memcpy

    ; Load tick
    mov     rdi, r12
    add     rdi, 32
    mov     esi, 8
    call    er_load64_from
    mov     [r13 + 32], rax

    ; Load slot
    mov     rdi, r12
    add     rdi, 40
    mov     esi, 8
    call    er_load64_from
    mov     [r13 + 40], rax

    ; Load epoch
    mov     rdi, r12
    add     rdi, 48
    mov     esi, 8
    call    er_load64_from
    mov     [r13 + 48], rax

    ; Load era
    mov     rdi, r12
    add     rdi, 56
    mov     esi, 8
    call    er_load64_from
    mov     [r13 + 56], rax

    ; Validate stamp
    mov     rdi, r13
    call    er_stamp_valid
    test    eax, eax
    jz      .de_fail

    pop     r13
    pop     r12
    pop     rbx
    er_ok
    mov     eax, 1
    er_ret
.de_fail:
    xor     eax, eax
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; Internal helper: load 8 bytes from memory (rdi=src, esi=len) → rax
; Used by decode_epoch since er_load64 takes (rdi=in, esi=len)
er_load64_from:
    mov     rax, [rdi]
    ret

; ==================================================================
; er_preimage_writer_init — initialize a writer
; void er_preimage_writer_init(void* writer, uint8_t* buf, uint64_t len)
; rdi=writer, rsi=buf, rdx=len
; ==================================================================
er_fn er_preimage_writer_init
    push    rbx
    push    r12
    push    r13

    mov     r12, rdi            ; writer
    mov     r13, rsi            ; buf
    mov     rbx, rdx            ; len

    mov     [r12 + er_preimage_writer.buf], r13
    mov     [r12 + er_preimage_writer.len], rbx
    mov     qword [r12 + er_preimage_writer.pos], 0

    ; Zero the buffer
    mov     rdi, r13
    mov     esi, ebx
    call    er_bytes_zero

    pop     r13
    pop     r12
    pop     rbx
    er_ret

; ==================================================================
; er_preimage_writer_written — return number of bytes written
; uint64_t er_preimage_writer_written(const void* writer)
; rdi=writer
; Returns written count in rax. rdx=0.
; ==================================================================
er_fn er_preimage_writer_written
    mov     rax, [rdi + er_preimage_writer.pos]
    er_ok
    er_ret

; ==================================================================
; er_preimage_writer_reserve — check if len bytes available
; int er_preimage_writer_reserve(void* writer, uint64_t len)
; rdi=writer, rsi=len
; Returns eax=1 if pos + len <= buf.len, else 0.
; ==================================================================
er_fn er_preimage_writer_reserve
    mov     rax, [rdi + er_preimage_writer.pos]
    add     rax, rsi
    jc      .wr_fail
    cmp     rax, [rdi + er_preimage_writer.len]
    ja      .wr_fail
    mov     eax, 1
    er_ok
    er_ret
.wr_fail:
    xor     eax, eax
    er_ret

; ==================================================================
; er_preimage_writer_raw — append raw bytes to writer
; int er_preimage_writer_raw(void* writer, const uint8_t* data, uint64_t len)
; rdi=writer, rsi=data, rdx=len
; Returns eax=1 on success, 0 if not enough space.
; ==================================================================
er_fn er_preimage_writer_raw
    push    rbx
    push    r12
    push    r13
    push    r14

    mov     r12, rdi            ; writer
    mov     r13, rsi            ; data
    mov     r14, rdx            ; len

    ; Check reserve
    mov     rsi, r14
    call    er_preimage_writer_reserve
    test    eax, eax
    jz      .wr_raw_fail

    ; Copy data to buf[pos..pos+len]
    mov     rdi, [r12 + er_preimage_writer.buf]
    add     rdi, [r12 + er_preimage_writer.pos]
    mov     esi, r14d           ; len (32-bit for memcpy)
    mov     rdx, r13
    call    er_preimage_memcpy

    ; Advance pos
    add     [r12 + er_preimage_writer.pos], r14

    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ok
    mov     eax, 1
    er_ret
.wr_raw_fail:
    xor     eax, eax
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; ==================================================================
; er_preimage_writer_write_u16 — append u16 in LE
; int er_preimage_writer_write_u16(void* writer, uint16_t value)
; rdi=writer, esi=value
; ==================================================================
er_fn er_preimage_writer_write_u16
    sub     rsp, 2
    mov     [rsp], si
    mov     rsi, rsp
    mov     rdx, 2
    call    er_preimage_writer_raw
    add     rsp, 2
    er_ret

; ==================================================================
; er_preimage_writer_write_u32 — append u32 in LE
; int er_preimage_writer_write_u32(void* writer, uint32_t value)
; rdi=writer, esi=value
; ==================================================================
er_fn er_preimage_writer_write_u32
    sub     rsp, 4
    mov     [rsp], esi
    mov     rsi, rsp
    mov     rdx, 4
    call    er_preimage_writer_raw
    add     rsp, 4
    er_ret

; ==================================================================
; er_preimage_writer_write_u64 — append u64 in LE
; int er_preimage_writer_write_u64(void* writer, uint64_t value)
; rdi=writer, rsi=value
; ==================================================================
er_fn er_preimage_writer_write_u64
    sub     rsp, 8
    mov     [rsp], rsi
    mov     rsi, rsp
    mov     rdx, 8
    call    er_preimage_writer_raw
    add     rsp, 8
    er_ret

; ==================================================================
; er_preimage_writer_id — append a 32-byte identity Id
; int er_preimage_writer_id(void* writer, const uint8_t id[32])
; rdi=writer, rsi=id
; ==================================================================
er_fn er_preimage_writer_id
    mov     rdx, 32
    jmp     er_preimage_writer_raw

; ==================================================================
; er_preimage_writer_hash — append a 32-byte Hash
; int er_preimage_writer_hash(void* writer, const uint8_t hash[32])
; rdi=writer, rsi=hash
; ==================================================================
er_fn er_preimage_writer_hash
    mov     rdx, 32
    jmp     er_preimage_writer_raw

; ==================================================================
; er_preimage_writer_epoch — append an encoded epoch (64 bytes)
; int er_preimage_writer_epoch(void* writer, const void* stamp)
; rdi=writer, rsi=stamp
; ==================================================================
er_fn er_preimage_writer_epoch
    push    rbx
    push    r12
    push    r13

    mov     r12, rdi            ; writer
    mov     r13, rsi            ; stamp

    call    er_stamp_valid
    test    eax, eax
    jz      .we_fail

    ; Check reserve(64)
    mov     rdi, r12
    mov     rsi, EPOCH_SIZE
    call    er_preimage_writer_reserve
    test    eax, eax
    jz      .we_fail

    ; Encode epoch into buf[pos..pos+64]
    mov     rdi, r13            ; stamp
    mov     rsi, [r12 + er_preimage_writer.buf]
    add     rsi, [r12 + er_preimage_writer.pos]
    mov     edx, EPOCH_SIZE
    call    er_preimage_encode_epoch
    test    eax, eax
    jz      .we_fail

    ; Advance pos
    add     qword [r12 + er_preimage_writer.pos], EPOCH_SIZE

    pop     r13
    pop     r12
    pop     rbx
    er_ok
    mov     eax, 1
    er_ret
.we_fail:
    xor     eax, eax
    pop     r13
    pop     r12
    pop     rbx
    er_ret

; ==================================================================
; Internal helper: er_preimage_memcpy(rdi=dst, esi=len, rdx=src)
; Preserves all callee-saved registers. Clobbers rax, rcx.
; ==================================================================
global er_preimage_memcpy
er_preimage_memcpy:
    test    esi, esi
    jz      .mdone
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
