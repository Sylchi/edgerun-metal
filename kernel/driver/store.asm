; store.asm — EdgeRun Persistent WAL Store over NVMe/SDHCI blocks
; System V AMD64 ABI, freestanding, no libc.
;
; Implements an append-log WAL over a block device, with in-memory
; blob and key indexes. Record format matches Zig PersistentStore.
;
; Functions:
;   er_store_init(state, state_bytes, dev_bar0) — init/replay store
;   er_store_sync(state)                        — flush superblock
;   er_store_put_blob(state, data, data_len)    — store blob by hash
;   er_store_get_blob(state, hash, out)         — read blob
;   er_store_index_put(state, idx, key, key_len, hash) — index key→hash
;   er_store_index_get(state, idx, key, key_len)        — get hash by key
;   er_store_blob_info(state, hash)             — get blob info

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"

extern er_nvme_read_blocks
extern er_nvme_write_blocks
extern er_preimage_raw_hash
extern er_store32
extern er_store64
extern er_load32
extern er_load64
extern er_bytes_copy
extern er_bytes_eql
extern er_bytes_zero

; ==================================================================
; Constants (matching Zig PersistentStore)
; ==================================================================
%define STORE_MAGIC         0x45525331       ; "ERSTORE\0" — wait no, "ERS1" 
%define STORE_SUPER_MAGIC   "ERSTORE"

STORE_MAGIC_STR        db "ERSTORE", 0
STORE_MAGIC_STR_LEN    equ 7

%define SUPERBLOCK_SIZE     68
%define RECORD_HEADER_SIZE  188
%define HASH_SIZE           32
%define MAX_KEY             64
%define INDEX_PAYLOAD_PREFIX_SIZE 28
%define INDEX_PAYLOAD_MIN_SIZE    (INDEX_PAYLOAD_PREFIX_SIZE + 1 + HASH_SIZE)
%define INDEX_PAYLOAD_MAX_SIZE    (INDEX_PAYLOAD_PREFIX_SIZE + MAX_KEY + HASH_SIZE)

; Superblock offsets
SUPER_MAGIC_OFF      equ 0   ; 8 bytes "ERSTORE\0\0"
SUPER_VERSION_OFF    equ 8   ; u32
SUPER_HDR_SIZE_OFF   equ 12  ; u32
SUPER_LOG_START_OFF  equ 16  ; u64
SUPER_LOG_END_OFF    equ 24  ; u64
SUPER_ROOT_HASH_OFF  equ 32  ; 32 bytes
SUPER_CRC_OFF        equ 64  ; u32

; Record header offsets
HDR_MAGIC_OFF        equ 0   ; u32
HDR_VERSION_OFF      equ 4   ; u16
HDR_TYPE_OFF         equ 6   ; u16
HDR_SEQ_OFF          equ 8   ; u64
HDR_PAYLOAD_LEN_OFF  equ 16  ; u64
HDR_PAYLOAD_HASH_OFF equ 24  ; 32 bytes
HDR_PREV_HASH_OFF    equ 56  ; 32 bytes
HDR_EPOCH_OFF        equ 88  ; 64 bytes
HDR_STORAGE_ID_OFF   equ 152 ; 32 bytes
HDR_CRC_OFF          equ 184 ; u32

; Record types
REC_BLOB             equ 1
REC_INDEX_PUT        equ 2
REC_BLOB_TYPE        equ 4
REC_OBJECT_INDEX_PUT equ 7

; Blob type constants
CONTENT_TYPE_RAW     equ 0
CONTENT_TYPE_OBJECT  equ 1

; Block device constants
BLOCK_BYTES          equ 512

; Scratch buffer for block I/O (4K-aligned, safe range above kernel)
%define STORE_SCRATCH    0x306000

; ==================================================================
; StoreState struct (at start of state buffer)
; ==================================================================
%define ST_DEV_BAR0      0  ; u64 — NVMe BAR0
%define ST_LOG_START     8  ; u64 — first record offset
%define ST_LOG_END       16 ; u64 — next write position
%define ST_NEXT_SEQ      24 ; u64 — next record seq number
%define ST_LAST_HASH     32 ; u8[32] — hash of last record header
%define ST_DIRTY         64 ; u8 — 1 if superblock needs update
%define ST_BLOB_COUNT    72 ; u64 — number of used blob slots
%define ST_KEY_COUNT     80 ; u64 — number of used key slots
%define ST_RESERVED      88 ; u8[24] — growth room
%define ST_STRUCT_SIZE   112

; Blob slot (8 bytes aligned)
%define BL_USED          0 ; u8
%define BL_HASH          1 ; u8[32]
%define BL_CONTENT_TYPE  33 ; u32
%define BL_OFFSET        40 ; u64
%define BL_SIZE          48 ; u64
%define BL_SLOT_SIZE     56

; Key slot
%define KL_USED          0  ; u8
%define KL_INDEX_ID      4  ; u32
%define KL_KEY           8  ; u8[64]
%define KL_KEY_LEN       72 ; u64
%define KL_HASH          80 ; u8[32]
%define KL_VALUE_KIND    112 ; u32
%define KL_CONTENT_TYPE  116 ; u32
%define KL_VALUE_SIZE    120 ; u64
%define KL_SLOT_SIZE     128

SECTION .bss
store_replay_header_hash: resb HASH_SIZE
store_replay_payload:     resb INDEX_PAYLOAD_MAX_SIZE
store_block_scratch:      resb BLOCK_BYTES

SECTION .text

; ==================================================================
; _store_crc32_super — compute CRC32 for superblock
; rdi = superblock ptr (SUPERBLOCK_SIZE bytes)
; Returns eax = CRC32
; ==================================================================
_store_crc32_super:
    push    rbx
    push    rcx
    push    rdx
    xor     eax, eax
    mov     ecx, SUPERBLOCK_SIZE - 4   ; CRC field is last 4 bytes
    xor     ebx, ebx
.crc_loop:
    movzx   edx, byte [rdi + rbx]
    crc32   eax, dl
    inc     ebx
    cmp     ebx, ecx
    jb      .crc_loop
    pop     rdx
    pop     rcx
    pop     rbx
    ret

; ==================================================================
; _store_crc32_record — compute CRC32 for record header
; rdi = record ptr (RECORD_HEADER_SIZE bytes)
; Returns eax = CRC32
; ==================================================================
_store_crc32_record:
    push    rcx
    push    rdx
    push    rbx
    xor     eax, eax
    mov     ecx, RECORD_HEADER_SIZE - 4
    xor     ebx, ebx
.rcrc_loop:
    movzx   edx, byte [rdi + rbx]
    crc32   eax, dl
    inc     ebx
    cmp     ebx, ecx
    jb      .rcrc_loop
    pop     rbx
    pop     rdx
    pop     rcx
    ret

; ==================================================================
; _store_blk_write — write data to block device at byte offset
; rdi = dev_bar0, rsi = byte_offset, rdx = data, ecx = count
; Destroys r8, r9, r10, r11
; Returns: eax = 0 on success, -1 on failure
; ==================================================================
_store_blk_write:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi            ; bar0
    mov     r13, rsi            ; byte offset
    mov     r14, rdx            ; data
    mov     r15, rcx            ; count (bytes)

    ; Compute start block and intra-block offset
    mov     rax, r13
    xor     edx, edx
    mov     rbx, BLOCK_BYTES
    div     rbx                 ; rax = block LBA, rdx = intra-block offset
    mov     r8, rax             ; current LBA
    mov     r9d, edx            ; intra-block offset
    mov     r10, r14            ; data cursor
    mov     r11, r15            ; remaining bytes

.wr_loop:
    test    r11, r11
    jz      .wr_done

    ; Calculate how many bytes fit in this block
    mov     eax, BLOCK_BYTES
    sub     eax, r9d            ; remaining in block
    cmp     eax, r11d
    jbe     .wr_full_block
    mov     eax, r11d           ; last partial block

.wr_full_block:
    ; If writing full block at start, write directly
    mov     ecx, eax            ; bytes to write
    test    r9d, r9d
    jnz     .wr_read_modify
    cmp     ecx, BLOCK_BYTES
    je      .wr_write_full

.wr_read_modify:
    ; Partial block — read existing block, patch, write
    push    r8
    push    r9
    push    r10
    push    r11
    push    rcx

    mov     rdi, r12
    mov     rsi, r8
    lea     rdx, [rel store_block_scratch]
    mov     ecx, 1
    call    er_nvme_read_blocks
    test    eax, eax
    jnz     .wr_fail_restore

    pop     rcx
    pop     r11
    pop     r10
    pop     r9
    pop     r8

    ; Copy patch into scratch buffer at intra-block offset
    push    r8
    push    r9
    push    r10
    push    r11
    push    rcx
    lea     rdi, [rel store_block_scratch]
    add     edi, r9d
    mov     esi, ecx
    mov     rdx, r10
    mov     ecx, esi
    call    er_bytes_copy
    pop     rcx
    pop     r11
    pop     r10
    pop     r9
    pop     r8
    jmp     .wr_do_write

.wr_write_full:
    push    r8
    push    r9
    push    r10
    push    r11
    push    rcx
    lea     rdi, [rel store_block_scratch]
    mov     esi, ecx
    mov     rdx, r10
    mov     ecx, esi
    call    er_bytes_copy
    pop     rcx
    pop     r11
    pop     r10
    pop     r9
    pop     r8

.wr_do_write:
    push    r8
    push    r9
    push    r10
    push    r11
    push    rcx
    mov     rdi, r12
    mov     rsi, r8
    lea     rdx, [rel store_block_scratch]
    mov     ecx, 1
    call    er_nvme_write_blocks
    test    eax, eax
    jnz     .wr_fail_restore

    pop     rcx               ; bytes written
    pop     r11
    pop     r10
    pop     r9
    pop     r8                ; LBA
    sub     r11, rcx          ; subtract bytes written
    add     r10, rcx          ; advance data cursor
    inc     r8                ; next LBA
    xor     r9d, r9d          ; from block start next time
    jmp     .wr_loop

.wr_done:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    xor     eax, eax
    er_ok
    ret

.wr_fail_restore:
    pop     rcx
    pop     r11
    pop     r10
    pop     r9
    pop     r8
.wr_fail:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_err  ERROR_IO
    ret

; ==================================================================
; _store_blk_read — read data from block device at byte offset
; rdi = dev_bar0, rsi = byte_offset, rdx = buf, ecx = count
; Returns: eax = 0 on success, -1 on failure
; ==================================================================
_store_blk_read:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi            ; bar0
    mov     r13, rsi            ; byte offset
    mov     r14, rdx            ; buf
    mov     r15, rcx            ; count

    mov     rax, r13
    xor     edx, edx
    mov     rbx, BLOCK_BYTES
    div     rbx
    mov     r8, rax             ; current LBA
    mov     r9d, edx            ; intra-block offset
    mov     r10, r14            ; buf cursor
    mov     r11, r15            ; remaining

.rd_loop:
    test    r11, r11
    jz      .rd_done

    mov     eax, BLOCK_BYTES
    sub     eax, r9d
    cmp     eax, r11d
    jbe     .rd_full
    mov     eax, r11d

.rd_full:
    ; Read block into scratch
    push    r8
    push    r9
    push    r10
    push    r11
    push    rax

    mov     rdi, r12
    mov     rsi, r8
    lea     rdx, [rel store_block_scratch]
    mov     ecx, 1
    call    er_nvme_read_blocks
    test    eax, eax
    jnz     .rd_fail_pop

    pop     rcx               ; bytes to copy
    pop     r11
    pop     r10
    pop     r9
    pop     r8

    ; Copy from scratch buffer + offset to output
    push    r8
    push    r9
    push    r10
    push    r11
    push    rcx
    mov     rdi, r10
    mov     esi, ecx
    lea     rdx, [rel store_block_scratch]
    add     edx, r9d
    call    er_bytes_copy

    pop     rcx
    pop     r11
    pop     r10
    pop     r9
    pop     r8
    sub     r11, rcx
    add     r10, rcx
    inc     r8
    xor     r9d, r9d
    jmp     .rd_loop

.rd_done:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    xor     eax, eax
    er_ok
    ret

.rd_fail_pop:
    pop     rax
    pop     r11
    pop     r10
    pop     r9
    pop     r8
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_err  ERROR_IO
    ret

; ==================================================================
; er_store_init — initialize or open a persistent store
; int er_store_init(void* state, uint64_t state_bytes, uint64_t dev_bar0)
;
; state buffer MUST be large enough for StoreState + blob_slots + key_slots.
; Layout: [StoreState][blob slabs][key slabs]
; Returns: eax = 0 on success, -1 on failure
; ==================================================================
er_fn er_store_init
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi            ; state
    mov     r13, rsi            ; state_bytes
    mov     r14, rdx            ; dev_bar0

    ; Validate state buffer is large enough
    cmp     r13, ST_STRUCT_SIZE + BL_SLOT_SIZE + KL_SLOT_SIZE
    jb      .init_bad

    ; Clear entire state buffer
    push    rcx
    push    rdi
    mov     rdi, r12
    mov     esi, r13d
    call    er_bytes_zero
    pop     rdi
    pop     rcx

    ; Store dev_bar0
    mov     [r12 + ST_DEV_BAR0], r14

    ; Set log_start to first block (or superblock_size for byte_log)
    mov     qword [r12 + ST_LOG_START], BLOCK_BYTES
    mov     qword [r12 + ST_LOG_END], BLOCK_BYTES
    mov     qword [r12 + ST_NEXT_SEQ], 1

    ; Try to read superblock at offset 0
    mov     rdi, r14
    xor     esi, esi
    mov     rdx, STORE_SCRATCH
    mov     ecx, SUPERBLOCK_SIZE
    call    _store_blk_read
    test    eax, eax
    jnz     .init_fresh      ; can't read → first use

    ; Check superblock magic
    mov     rdi, STORE_SCRATCH
    mov     esi, STORE_MAGIC_STR_LEN
    lea     rdx, [rel STORE_MAGIC_STR]
    mov     ecx, STORE_MAGIC_STR_LEN
    push    r12
    call    er_bytes_eql
    pop     r12
    test    eax, eax
    jz      .init_fresh      ; bad magic → first use

    ; Read log_start / log_end from superblock
    mov     rdi, STORE_SCRATCH + SUPER_LOG_START_OFF
    mov     esi, 8
    call    er_load64
    mov     [r12 + ST_LOG_START], rax
    mov     [r12 + ST_LOG_END], rax

    mov     rdi, STORE_SCRATCH + SUPER_LOG_END_OFF
    mov     esi, 8
    call    er_load64
    mov     [r12 + ST_LOG_END], rax

    ; Replay log to rebuild in-memory index
    mov     rdi, r12
    call    _store_replay
    test    eax, eax
    jnz     .init_fail

    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    xor     eax, eax
    er_ok
    ret

.init_fresh:
    ; Fresh store — write superblock
    mov     rdi, r12
    call    _store_write_superblock
    test    eax, eax
    jnz     .init_fail

    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    xor     eax, eax
    er_ok
    ret

.init_bad:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_err  ERROR_UNSUPPORTED
    ret

.init_fail:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_err  ERROR_IO
    ret

; ==================================================================
; _store_write_superblock — flush store state to superblock
; rdi = state
; Returns: eax = 0 on success, -1 on failure
; Uses STORE_SCRATCH as scratch.
; ==================================================================
_store_write_superblock:
    push    rbx
    push    r12

    mov     r12, rdi

    ; Build superblock in scratch buffer
    mov     rdi, STORE_SCRATCH
    mov     esi, SUPERBLOCK_SIZE
    call    er_bytes_zero

    ; Magic: "ERSTORE"
    mov     byte [STORE_SCRATCH + 0], 'E'
    mov     byte [STORE_SCRATCH + 1], 'R'
    mov     byte [STORE_SCRATCH + 2], 'S'
    mov     byte [STORE_SCRATCH + 3], 'T'
    mov     byte [STORE_SCRATCH + 4], 'O'
    mov     byte [STORE_SCRATCH + 5], 'R'
    mov     byte [STORE_SCRATCH + 6], 'E'
    mov     byte [STORE_SCRATCH + 7], 0

    ; Version = 1
    mov     dword [STORE_SCRATCH + SUPER_VERSION_OFF], 1

    ; Header size = SUPERBLOCK_SIZE
    mov     dword [STORE_SCRATCH + SUPER_HDR_SIZE_OFF], SUPERBLOCK_SIZE

    ; Log start
    mov     rax, [r12 + ST_LOG_START]
    mov     qword [STORE_SCRATCH + SUPER_LOG_START_OFF], rax

    ; Log end
    mov     rax, [r12 + ST_LOG_END]
    mov     qword [STORE_SCRATCH + SUPER_LOG_END_OFF], rax

    ; Root hash (last record hash)
    mov     rdi, STORE_SCRATCH + SUPER_ROOT_HASH_OFF
    mov     esi, HASH_SIZE
    lea     rdx, [r12 + ST_LAST_HASH]
    mov     ecx, HASH_SIZE
    call    er_bytes_copy

    ; CRC32 of bytes 0..SUPER_CRC_OFF-1
    lea     rdi, [rel STORE_SCRATCH]
    call    _store_crc32_super
    mov     dword [STORE_SCRATCH + SUPER_CRC_OFF], eax

    ; Write to block 0 (single block)
    mov     rdi, [r12 + ST_DEV_BAR0]
    xor     esi, esi
    mov     rdx, STORE_SCRATCH
    mov     ecx, 1
    call    er_nvme_write_blocks
    test    eax, eax
    jnz     .sb_fail

    ; Clear dirty flag
    mov     byte [r12 + ST_DIRTY], 0

    pop     r12
    pop     rbx
    xor     eax, eax
    er_ok
    ret

.sb_fail:
    pop     r12
    pop     rbx
    er_err  ERROR_IO
    ret

; ==================================================================
; er_store_sync — write superblock if dirty
; int er_store_sync(void* state)
; ==================================================================
er_fn er_store_sync
    push    rbx
    push    r12

    mov     r12, rdi
    cmp     byte [r12 + ST_DIRTY], 0
    jz      .sync_clean

    mov     rdi, r12
    call    _store_write_superblock
    test    eax, eax
    jnz     .sync_fail

.sync_clean:
    pop     r12
    pop     rbx
    xor     eax, eax
    er_ok
    ret

.sync_fail:
    pop     r12
    pop     rbx
    er_err  ERROR_IO
    ret

; ==================================================================
; _store_find_blob — find blob slot by hash
; rdi = state, rsi = hash ptr
; Returns: eax = slot index, or -1 if not found
; ==================================================================
_store_find_blob:
    push    rbx
    push    r12
    push    r13

    mov     r12, rdi
    mov     r13, rsi

    ; Compute blob slot area: after StoreState
    lea     rbx, [r12 + ST_STRUCT_SIZE]  ; first blob slot

    ; Count blob slots: state_bytes - ST_STRUCT_SIZE
    mov     rdx, [r12 + ST_STRUCT_SIZE - 8]  ; this won't work...
    
    ; Actually the state_bytes was only passed to init. We need to know
    ; the capacity. Let's recalculate from blob_count.

    ; Scan through all possible blob slots up to a reasonable limit
    ; We look for used slots and stop when we hit unused + no more slots
    xor     r8d, r8d            ; slot index
.fb_loop:
    cmp     byte [rbx + BL_USED], 0
    jz      .fb_check_end

    ; Compare hash
    lea     rdi, [rbx + BL_HASH]
    mov     esi, HASH_SIZE
    mov     rdx, r13
    mov     ecx, HASH_SIZE
    push    r8
    push    rbx
    call    er_bytes_eql
    pop     rbx
    pop     r8
    test    eax, eax
    jz      .fb_next

    mov     eax, r8d
    pop     r13
    pop     r12
    pop     rbx
    ret

.fb_next:
    inc     r8d
    add     rbx, BL_SLOT_SIZE
    jmp     .fb_loop

.fb_check_end:
    ; Check if this is within blob_count (used slots)
    mov     rax, [r12 + ST_BLOB_COUNT]
    cmp     r8d, eax
    jb      .fb_loop            ; still within used range, keep scanning
    ; Not found
    mov     eax, -1
    pop     r13
    pop     r12
    pop     rbx
    ret

; ==================================================================
; _store_next_blob_slot — find next free blob slot
; rdi = state
; Returns: eax = slot index, or -1 if full
; Destroys: rbx = slot ptr or 0
; ==================================================================
_store_next_blob_slot:
    push    r12

    mov     r12, rdi
    lea     rbx, [r12 + ST_STRUCT_SIZE]
    xor     r8d, r8d
.nb_loop:
    cmp     byte [rbx + BL_USED], 0
    jz      .nb_found
    inc     r8d
    add     rbx, BL_SLOT_SIZE
    ; Bound check: 256 slots max
    cmp     r8d, 256
    jb      .nb_loop
    mov     eax, -1
    pop     r12
    ret

.nb_found:
    mov     eax, r8d
    pop     r12
    ret

; ==================================================================
; _store_append_record — append a record to the WAL
; rdi = state, esi = type (u16), rdx = payload, ecx = payload_len
; Returns: eax = payload offset on success, -1 on failure
; ==================================================================
_store_append_record:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi            ; state
    mov     r13w, si            ; type
    mov     r14, rdx            ; payload
    mov     r15d, ecx           ; payload_len
    mov     rbx, r14            ; payload write pointer

    ; Preserve payloads that are built in STORE_SCRATCH before the header
    ; overwrites that buffer.
    cmp     r14, STORE_SCRATCH
    jne     .ar_payload_ready
    mov     rdi, STORE_SCRATCH + RECORD_HEADER_SIZE
    mov     esi, r15d
    mov     rdx, r14
    mov     ecx, r15d
    call    er_bytes_copy
    mov     rbx, STORE_SCRATCH + RECORD_HEADER_SIZE

.ar_payload_ready:

    ; Build record header at STORE_SCRATCH
    mov     rdi, STORE_SCRATCH
    mov     esi, RECORD_HEADER_SIZE
    call    er_bytes_zero

    ; Magic
    mov     dword [STORE_SCRATCH + HDR_MAGIC_OFF], STORE_MAGIC

    ; Version = 2
    mov     word [STORE_SCRATCH + HDR_VERSION_OFF], 2

    ; Type
    mov     word [STORE_SCRATCH + HDR_TYPE_OFF], r13w

    ; Sequence
    mov     rax, [r12 + ST_NEXT_SEQ]
    mov     qword [STORE_SCRATCH + HDR_SEQ_OFF], rax

    ; Payload length
    mov     qword [STORE_SCRATCH + HDR_PAYLOAD_LEN_OFF], r15

    ; Payload hash
    mov     rdi, rbx
    mov     esi, r15d
    mov     rdx, STORE_SCRATCH + HDR_PAYLOAD_HASH_OFF
    call    er_preimage_raw_hash

    ; Previous record hash
    mov     rdi, STORE_SCRATCH + HDR_PREV_HASH_OFF
    mov     esi, HASH_SIZE
    lea     rdx, [r12 + ST_LAST_HASH]
    mov     ecx, HASH_SIZE
    call    er_bytes_copy

    ; CRC32 of header (bytes before CRC)
    mov     rdi, STORE_SCRATCH
    call    _store_crc32_record
    mov     dword [STORE_SCRATCH + HDR_CRC_OFF], eax

    ; Write header to disk
    mov     rdi, [r12 + ST_DEV_BAR0]
    mov     rsi, [r12 + ST_LOG_END]
    mov     rdx, STORE_SCRATCH
    mov     ecx, RECORD_HEADER_SIZE
    call    _store_blk_write
    test    eax, eax
    jnz     .ar_fail

    ; Compute payload offset
    mov     rax, [r12 + ST_LOG_END]
    add     rax, RECORD_HEADER_SIZE
    mov     r8, rax             ; payload offset

    ; Write payload to disk
    mov     rdi, [r12 + ST_DEV_BAR0]
    mov     rsi, r8
    mov     rdx, rbx
    mov     ecx, r15d
    call    _store_blk_write
    test    eax, eax
    jnz     .ar_fail

    ; Compute header hash for chain
    mov     rdi, STORE_SCRATCH
    mov     esi, RECORD_HEADER_SIZE
    lea     rdx, [r12 + ST_LAST_HASH]
    call    er_preimage_raw_hash

    ; Update state
    mov     rax, [r12 + ST_LOG_END]
    add     rax, RECORD_HEADER_SIZE
    add     rax, r15
    mov     [r12 + ST_LOG_END], rax

    mov     rax, [r12 + ST_NEXT_SEQ]
    inc     rax
    mov     [r12 + ST_NEXT_SEQ], rax

    mov     byte [r12 + ST_DIRTY], 1

    ; Return payload offset
    mov     rax, r8
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ok
    ret

.ar_fail:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_err  ERROR_IO
    ret

; ==================================================================
; _store_replay — replay log records to rebuild in-memory index
; rdi = state
; Returns: eax = 0 on success, -1 on failure
; ==================================================================
_store_replay:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    push    rbp

    mov     r12, rdi
    mov     r13, [r12 + ST_LOG_START]   ; read cursor
    mov     r14, [r12 + ST_LOG_END]     ; end boundary

.replay_loop:
    ; Check if we can read a header
    mov     rax, r13
    add     rax, RECORD_HEADER_SIZE
    cmp     rax, r14
    ja      .replay_done

    ; Read header
    mov     rdi, [r12 + ST_DEV_BAR0]
    mov     rsi, r13
    mov     rdx, STORE_SCRATCH
    mov     ecx, RECORD_HEADER_SIZE
    call    _store_blk_read
    test    eax, eax
    jnz     .replay_fail

    ; Validate magic
    mov     eax, [STORE_SCRATCH + HDR_MAGIC_OFF]
    cmp     eax, STORE_MAGIC
    jne     .replay_corrupt

    ; Validate CRC
    mov     rdi, STORE_SCRATCH
    call    _store_crc32_record
    mov     edx, [STORE_SCRATCH + HDR_CRC_OFF]
    cmp     eax, edx
    jne     .replay_corrupt

    ; Get payload length
    mov     rax, [STORE_SCRATCH + HDR_PAYLOAD_LEN_OFF]
    mov     r15, rax             ; payload_len

    ; Payload offset
    mov     rax, r13
    add     rax, RECORD_HEADER_SIZE
    mov     r8, rax

    ; Validate payload fits
    mov     rax, r8
    add     rax, r15
    cmp     rax, r14
    ja      .replay_corrupt     ; payload extends past log_end

    push    r8
    push    r15
    mov     rdi, STORE_SCRATCH
    mov     esi, RECORD_HEADER_SIZE
    lea     rdx, [rel store_replay_header_hash]
    call    er_preimage_raw_hash
    pop     r15
    pop     r8

    ; Apply record based on type
    movzx   eax, word [STORE_SCRATCH + HDR_TYPE_OFF]
    cmp     eax, REC_BLOB
    je      .replay_blob
    cmp     eax, REC_INDEX_PUT
    je      .replay_index
    cmp     eax, REC_BLOB_TYPE
    je      .replay_blob_type
    cmp     eax, REC_OBJECT_INDEX_PUT
    je      .replay_index
    jmp     .replay_skip         ; unknown type, skip

.replay_blob:
    ; Insert blob slot
    mov     rdi, r12
    call    _store_next_blob_slot
    cmp     eax, -1
    je      .replay_corrupt

    lea     rbx, [r12 + ST_STRUCT_SIZE]
    mov     ecx, BL_SLOT_SIZE
    mul     ecx
    add     rbx, rax            ; slot ptr

    mov     byte [rbx + BL_USED], 1
    mov     ecx, CONTENT_TYPE_RAW
    mov     dword [rbx + BL_CONTENT_TYPE], ecx

    ; Copy hash
    lea     rdi, [rbx + BL_HASH]
    mov     esi, HASH_SIZE
    mov     rdx, STORE_SCRATCH + HDR_PAYLOAD_HASH_OFF
    mov     ecx, HASH_SIZE
    call    er_bytes_copy

    mov     qword [rbx + BL_OFFSET], r8
    mov     qword [rbx + BL_SIZE], r15

    mov     rax, [r12 + ST_BLOB_COUNT]
    inc     rax
    mov     [r12 + ST_BLOB_COUNT], rax
    jmp     .replay_next

.replay_blob_type:
    ; Read content_type from payload
    ; Payload: content_type (4 bytes) + hash (32 bytes)
    cmp     r15, 36
    jb      .replay_skip

    mov     rdi, [r12 + ST_DEV_BAR0]
    mov     rsi, r8
    lea     rdx, [rel store_replay_payload]
    mov     ecx, 36
    call    _store_blk_read
    test    eax, eax
    jnz     .replay_fail

    lea     rdi, [rel store_replay_payload]
    mov     esi, 4
    call    er_load32
    mov     r9d, eax            ; content_type

    ; Update blob slot's content_type
    mov     rdi, r12
    lea     rsi, [rel store_replay_payload + 4]
    call    _store_find_blob
    cmp     eax, -1
    je      .replay_skip        ; blob not found, skip

    lea     rbx, [r12 + ST_STRUCT_SIZE]
    mov     ecx, BL_SLOT_SIZE
    mul     ecx
    add     rbx, rax
    mov     dword [rbx + BL_CONTENT_TYPE], r9d
    jmp     .replay_next

.replay_index:
    ; Payload: index_id(4) + value_kind(4) + content_type(4) + value_size(8) + key_len(8) + key(<=64) + hash(32)
    ; Fixed prefix before key: index_id(4) + value_kind(4) + content_type(4) + value_size(8) + key_len(8) = 28 bytes
    cmp     r15, INDEX_PAYLOAD_MIN_SIZE
    jb      .replay_skip
    cmp     r15, INDEX_PAYLOAD_MAX_SIZE
    ja      .replay_skip

    mov     rdi, [r12 + ST_DEV_BAR0]
    mov     rsi, r8
    lea     rdx, [rel store_replay_payload]
    mov     ecx, r15d
    call    _store_blk_read
    test    eax, eax
    jnz     .replay_fail

    ; Read key_len at offset 20
    lea     rdi, [rel store_replay_payload + 20]
    mov     esi, 8
    call    er_load64
    mov     r9, rax             ; key_len
    test    r9, r9
    jz      .replay_skip
    cmp     r9, MAX_KEY
    ja      .replay_skip

    mov     rax, INDEX_PAYLOAD_PREFIX_SIZE
    add     rax, r9
    add     rax, HASH_SIZE
    cmp     r15, rax
    jb      .replay_skip

    lea     rdi, [rel store_replay_payload]
    mov     esi, 4
    call    er_load32
    mov     r10d, eax           ; index_id

    mov     rax, [rel store_replay_payload + 20]

    mov     rdi, r12
    mov     esi, r10d
    lea     rdx, [rel store_replay_payload + INDEX_PAYLOAD_PREFIX_SIZE]
    mov     ecx, eax
    call    _store_find_key
    cmp     eax, -1
    jne     .replay_index_existing

    lea     rbx, [r12 + ST_STRUCT_SIZE]
    mov     rax, [r12 + ST_BLOB_COUNT]
    mov     ecx, BL_SLOT_SIZE
    mul     ecx
    add     rbx, rax

    xor     r8d, r8d
.replay_index_find_free:
    cmp     byte [rbx + KL_USED], 0
    jz      .replay_index_new
    inc     r8d
    add     rbx, KL_SLOT_SIZE
    cmp     r8d, 256
    jb      .replay_index_find_free
    jmp     .replay_corrupt

.replay_index_new:
    mov     byte [rbx + KL_USED], 1
    mov     rax, [r12 + ST_KEY_COUNT]
    inc     rax
    mov     [r12 + ST_KEY_COUNT], rax
    jmp     .replay_index_fill

.replay_index_existing:
    lea     rbx, [r12 + ST_STRUCT_SIZE]
    push    rax
    mov     rax, [r12 + ST_BLOB_COUNT]
    mov     ecx, BL_SLOT_SIZE
    mul     ecx
    pop     rcx
    add     rbx, rax
    mov     eax, ecx
    mov     ecx, KL_SLOT_SIZE
    mul     ecx
    add     rbx, rax

.replay_index_fill:
    mov     eax, [rel store_replay_payload]
    mov     [rbx + KL_INDEX_ID], eax
    mov     rax, [rel store_replay_payload + 20]
    mov     [rbx + KL_KEY_LEN], rax

    lea     rdi, [rbx + KL_KEY]
    mov     esi, MAX_KEY
    call    er_bytes_zero

    mov     rax, [rel store_replay_payload + 20]
    lea     rdi, [rbx + KL_KEY]
    mov     esi, MAX_KEY
    lea     rdx, [rel store_replay_payload + INDEX_PAYLOAD_PREFIX_SIZE]
    mov     ecx, eax
    call    er_bytes_copy

    mov     rax, [rel store_replay_payload + 20]
    lea     rdi, [rbx + KL_HASH]
    mov     esi, HASH_SIZE
    lea     rdx, [rel store_replay_payload + INDEX_PAYLOAD_PREFIX_SIZE]
    add     rdx, rax
    mov     ecx, HASH_SIZE
    call    er_bytes_copy

    mov     eax, [rel store_replay_payload + 4]
    mov     [rbx + KL_VALUE_KIND], eax
    mov     eax, [rel store_replay_payload + 8]
    mov     [rbx + KL_CONTENT_TYPE], eax
    mov     rax, [rel store_replay_payload + 12]
    mov     [rbx + KL_VALUE_SIZE], rax
    jmp     .replay_next

.replay_next:
    ; Update last_record_hash
    lea     rdi, [r12 + ST_LAST_HASH]
    mov     esi, HASH_SIZE
    lea     rdx, [rel store_replay_header_hash]
    mov     ecx, HASH_SIZE
    call    er_bytes_copy

    ; Advance cursor
    mov     rax, r13
    add     rax, RECORD_HEADER_SIZE
    add     rax, r15
    mov     r13, rax

    mov     rax, [r12 + ST_NEXT_SEQ]
    inc     rax
    mov     [r12 + ST_NEXT_SEQ], rax
    jmp     .replay_loop

.replay_skip:
    ; Advance cursor without applying
    mov     rax, r13
    add     rax, RECORD_HEADER_SIZE
    add     rax, r15
    mov     r13, rax
    jmp     .replay_loop

.replay_done:
    pop     rbp
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    xor     eax, eax
    er_ok
    ret

.replay_corrupt:
    ; Stop replay at corrupt record
    ; Update log_end to current cursor position
    mov     [r12 + ST_LOG_END], r13
    mov     byte [r12 + ST_DIRTY], 1
    jmp     .replay_done

.replay_fail:
    pop     rbp
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_err  ERROR_IO
    ret

; ==================================================================
; er_store_put_blob — store a blob by content hash
; int er_store_put_blob(void* state, const void* data, uint32_t data_len)
;
; Returns: eax = 0 on success, hash written to blob's slot.
;          rdx = 0 on success, error code on failure.
; ==================================================================
er_fn er_store_put_blob
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi            ; state
    mov     r13, rsi            ; data
    mov     r14d, edx           ; data_len

    ; Validate
    test    r14d, r14d
    jz      .put_bad

    ; Hash the data
    mov     rdi, r13
    mov     esi, r14d
    mov     rdx, STORE_SCRATCH + RECORD_HEADER_SIZE
    call    er_preimage_raw_hash

    ; Check if already stored
    mov     rsi, STORE_SCRATCH + RECORD_HEADER_SIZE
    mov     rdi, r12
    call    _store_find_blob
    cmp     eax, -1
    jne     .put_dup            ; already exists

    ; Find free blob slot
    mov     rdi, r12
    call    _store_next_blob_slot
    cmp     eax, -1
    je      .put_full

    mov     r15d, eax           ; slot index

    ; Append blob record
    mov     rdi, r12
    mov     esi, REC_BLOB
    mov     rdx, r13
    mov     ecx, r14d
    call    _store_append_record
    cmp     eax, -1
    je      .put_io

    ; Fill blob slot
    push    rax                 ; payload offset
    lea     rbx, [r12 + ST_STRUCT_SIZE]
    mov     eax, r15d
    mov     ecx, BL_SLOT_SIZE
    mul     ecx
    add     rbx, rax
    pop     r15                 ; payload offset

    mov     byte [rbx + BL_USED], 1
    mov     dword [rbx + BL_CONTENT_TYPE], CONTENT_TYPE_RAW

    ; Copy hash
    lea     rdi, [rbx + BL_HASH]
    mov     esi, HASH_SIZE
    mov     rdx, STORE_SCRATCH + HDR_PAYLOAD_HASH_OFF
    mov     ecx, HASH_SIZE
    call    er_bytes_copy

    mov     qword [rbx + BL_OFFSET], r15
    mov     qword [rbx + BL_SIZE], r14

    mov     rax, [r12 + ST_BLOB_COUNT]
    inc     rax
    mov     [r12 + ST_BLOB_COUNT], rax

    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    xor     eax, eax
    er_ok
    ret

.put_dup:
    ; Already stored — success
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    xor     eax, eax
    er_ok
    ret

.put_full:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_err  ERROR_NO_SPACE
    ret

.put_bad:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_err  ERROR_UNSUPPORTED
    ret

.put_io:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_err  ERROR_IO
    ret

; ==================================================================
; er_store_get_blob — retrieve blob data by hash
; int er_store_get_blob(void* state, const uint8_t hash[32],
;                       void* out_buf, uint32_t* out_len)
;
; out_len: caller sets max buf size, function writes actual size.
; Returns: eax = 0 on success, -1 on failure
; ==================================================================
er_fn er_store_get_blob
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi            ; state
    mov     r13, rsi            ; hash
    mov     r14, rdx            ; out_buf
    mov     r15, rcx            ; out_len ptr

    mov     rdi, r12
    mov     rsi, r13
    call    _store_find_blob
    cmp     eax, -1
    je      .get_notfound

    ; Compute slot ptr
    lea     rbx, [r12 + ST_STRUCT_SIZE]
    mov     ecx, BL_SLOT_SIZE
    mul     ecx
    add     rbx, rax

    ; Check buffer capacity
    mov     rax, qword [r15]    ; buffer size
    mov     r8, [rbx + BL_SIZE]
    cmp     rax, r8
    jb      .get_small

    ; Read blob data
    mov     rdi, [r12 + ST_DEV_BAR0]
    mov     rsi, [rbx + BL_OFFSET]
    mov     rdx, r14
    mov     ecx, r8d
    call    _store_blk_read
    test    eax, eax
    jnz     .get_io

    ; Write actual size
    mov     qword [r15], r8

    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    xor     eax, eax
    er_ok
    ret

.get_notfound:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_err  ERROR_NOT_FOUND
    ret

.get_small:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_err  ERROR_NO_SPACE
    ret

.get_io:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_err  ERROR_IO
    ret

; ==================================================================
; er_store_blob_info — get blob info by hash
; int er_store_blob_info(void* state, const uint8_t hash[32],
;                         uint64_t* out_offset, uint64_t* out_size,
;                         uint32_t* out_content_type)
;
; Returns: eax = 1 if found, 0 if not found
; ==================================================================
er_fn er_store_blob_info
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi            ; state
    mov     r13, rsi            ; hash
    mov     r14, rdx            ; out_offset
    mov     r15, rcx            ; out_size
    ; stack: out_content_type

    mov     rdi, r12
    mov     rsi, r13
    call    _store_find_blob
    cmp     eax, -1
    je      .info_notfound

    lea     rbx, [r12 + ST_STRUCT_SIZE]
    mov     ecx, BL_SLOT_SIZE
    mul     ecx
    add     rbx, rax

    test    r14, r14
    jz      .info_skip_offset
    mov     rax, [rbx + BL_OFFSET]
    mov     [r14], rax
.info_skip_offset:

    test    r15, r15
    jz      .info_skip_size
    mov     rax, [rbx + BL_SIZE]
    mov     [r15], rax
.info_skip_size:

    mov     rdi, [rsp]          ; out_content_type from stack
    test    rdi, rdi
    jz      .info_skip_ct
    mov     eax, [rbx + BL_CONTENT_TYPE]
    mov     [rdi], eax
.info_skip_ct:

    mov     eax, 1
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    xor     eax, eax
    er_ok
    ret

.info_notfound:
    xor     eax, eax
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_err  ERROR_NOT_FOUND
    ret

; ==================================================================
; _store_find_key — find key slot by (index_id, key)
; rdi = state, esi = index_id, rdx = key, ecx = key_len
; Returns: eax = slot index, or -1 if not found
; ==================================================================
_store_find_key:
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi
    mov     r13d, esi
    mov     r14, rdx
    mov     r15d, ecx

    ; Compute key slot area: after StoreState + all blob slots
    lea     rbx, [r12 + ST_STRUCT_SIZE]
    ; Skip blob slots
    mov     rax, [r12 + ST_BLOB_COUNT]
    mov     ecx, BL_SLOT_SIZE
    mul     ecx
    add     rbx, rax

    xor     r8d, r8d
.fk_loop:
    cmp     byte [rbx + KL_USED], 0
    jz      .fk_check_end

    ; Compare index_id
    mov     eax, [rbx + KL_INDEX_ID]
    cmp     eax, r13d
    jne     .fk_next

    ; Compare key_len
    mov     rax, [rbx + KL_KEY_LEN]
    cmp     eax, r15d
    jne     .fk_next

    ; Compare key bytes
    lea     rdi, [rbx + KL_KEY]
    mov     esi, r15d
    mov     rdx, r14
    mov     ecx, r15d
    push    r8
    push    rbx
    call    er_bytes_eql
    pop     rbx
    pop     r8
    test    eax, eax
    jnz     .fk_found

.fk_next:
    inc     r8d
    add     rbx, KL_SLOT_SIZE
    jmp     .fk_loop

.fk_check_end:
    mov     rax, [r12 + ST_KEY_COUNT]
    cmp     r8d, eax
    jb      .fk_loop

    mov     eax, -1
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

.fk_found:
    mov     eax, r8d
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; ==================================================================
; er_store_index_put — index a key → hash mapping
; int er_store_index_put(void* state, uint32_t index_id,
;                         const void* key, uint32_t key_len,
;                         const uint8_t hash[32])
; ==================================================================
er_fn er_store_index_put
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    push    rbp

    mov     r12, rdi            ; state
    mov     r13d, esi           ; index_id
    mov     r14, rdx            ; key
    mov     r15d, ecx           ; key_len
    mov     rbp, r8             ; hash

    ; Validate
    test    r15d, r15d
    jz      .ip_bad
    cmp     r15d, MAX_KEY
    ja      .ip_bad

    ; Check if key already exists
    mov     rdi, r12
    mov     esi, r13d
    mov     rdx, r14
    mov     ecx, r15d
    call    _store_find_key
    cmp     eax, -1
    jne     .ip_update_slot     ; update existing

    ; Find free key slot
    mov     rdi, r12
    lea     rbx, [r12 + ST_STRUCT_SIZE]
    ; Skip blob slots
    mov     rax, [r12 + ST_BLOB_COUNT]
    mov     ecx, BL_SLOT_SIZE
    mul     ecx
    add     rbx, rax

    xor     r8d, r8d
.ip_find_loop:
    cmp     byte [rbx + KL_USED], 0
    jz      .ip_found_slot
    inc     r8d
    add     rbx, KL_SLOT_SIZE
    cmp     r8d, 256
    jb      .ip_find_loop

    ; Full
    pop     rbp
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_err  ERROR_NO_SPACE
    ret

.ip_found_slot:
    ; Fill key slot
    mov     byte [rbx + KL_USED], 1
    mov     dword [rbx + KL_INDEX_ID], r13d
    mov     qword [rbx + KL_KEY_LEN], r15

    ; Copy key
    lea     rdi, [rbx + KL_KEY]
    mov     esi, r15d
    mov     rdx, r14
    mov     ecx, r15d
    call    er_bytes_copy

    ; Copy hash
    lea     rdi, [rbx + KL_HASH]
    mov     esi, HASH_SIZE
    mov     rdx, rbp
    mov     ecx, HASH_SIZE
    call    er_bytes_copy

    mov     dword [rbx + KL_VALUE_KIND], 1     ; value_blob
    mov     dword [rbx + KL_CONTENT_TYPE], CONTENT_TYPE_RAW
    mov     qword [rbx + KL_VALUE_SIZE], 0

    mov     rax, [r12 + ST_KEY_COUNT]
    inc     rax
    mov     [r12 + ST_KEY_COUNT], rax
    jmp     .ip_append_record

.ip_update_slot:
    lea     rbx, [r12 + ST_STRUCT_SIZE]
    push    rax
    mov     rax, [r12 + ST_BLOB_COUNT]
    mov     ecx, BL_SLOT_SIZE
    mul     ecx
    pop     rcx
    add     rbx, rax
    mov     eax, ecx
    mov     ecx, KL_SLOT_SIZE
    mul     ecx
    add     rbx, rax

    lea     rdi, [rbx + KL_HASH]
    mov     esi, HASH_SIZE
    mov     rdx, rbp
    mov     ecx, HASH_SIZE
    call    er_bytes_copy

    mov     dword [rbx + KL_VALUE_KIND], 1
    mov     dword [rbx + KL_CONTENT_TYPE], CONTENT_TYPE_RAW
    mov     qword [rbx + KL_VALUE_SIZE], 0

.ip_append_record:
    ; Append index record (read blob info for value_size)
    ; Build payload: index_id(4) + value_kind(4) + content_type(4) + value_size(8) + key_len(8) + key + hash(32)
    ; = 28 + key_len + 32 bytes total
    mov     edi, INDEX_PAYLOAD_PREFIX_SIZE
    add     edi, r15d
    add     edi, HASH_SIZE
    mov     r9d, edi            ; payload_size
    cmp     r9d, INDEX_PAYLOAD_MAX_SIZE
    ja      .ip_bad             ; payload too large

    ; Build payload at STORE_SCRATCH
    mov     dword [STORE_SCRATCH], r13d          ; index_id
    mov     dword [STORE_SCRATCH + 4], 1          ; value_kind = blob
    mov     dword [STORE_SCRATCH + 8], CONTENT_TYPE_RAW
    mov     qword [STORE_SCRATCH + 12], 0         ; value_size (unknown from here)
    mov     qword [STORE_SCRATCH + 20], r15       ; key_len
    ; Copy key at offset 28
    mov     rdi, STORE_SCRATCH + INDEX_PAYLOAD_PREFIX_SIZE
    mov     esi, r15d
    mov     rdx, r14
    mov     ecx, r15d
    call    er_bytes_copy
    ; Copy hash at offset 28 + key_len
    mov     rdi, STORE_SCRATCH + INDEX_PAYLOAD_PREFIX_SIZE
    add     edi, r15d
    mov     esi, HASH_SIZE
    mov     rdx, rbp
    mov     ecx, HASH_SIZE
    call    er_bytes_copy

    ; Append record
    mov     ecx, INDEX_PAYLOAD_PREFIX_SIZE
    add     ecx, r15d
    add     ecx, HASH_SIZE
    mov     rdi, r12
    mov     esi, REC_INDEX_PUT
    mov     rdx, STORE_SCRATCH
    call    _store_append_record
    cmp     eax, -1
    je      .ip_io

    pop     rbp
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    xor     eax, eax
    er_ok
    ret

.ip_bad:
    pop     rbp
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_err  ERROR_UNSUPPORTED
    ret

.ip_io:
    pop     rbp
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_err  ERROR_IO
    ret

; ==================================================================
; er_store_index_get — get hash by (index_id, key)
; int er_store_index_get(void* state, uint32_t index_id,
;                         const void* key, uint32_t key_len,
;                         uint8_t out_hash[32])
; Returns: eax = 1 if found, 0 if not found
; ==================================================================
er_fn er_store_index_get
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    push    rbp

    mov     r12, rdi            ; state
    mov     r13d, esi           ; index_id
    mov     r14, rdx            ; key
    mov     r15d, ecx           ; key_len
    mov     rbp, r8             ; out_hash

    mov     rdi, r12
    mov     esi, r13d
    mov     rdx, r14
    mov     ecx, r15d
    call    _store_find_key
    cmp     eax, -1
    je      .ig_notfound

    lea     rbx, [r12 + ST_STRUCT_SIZE]
    ; Skip blob slots
    push    rax
    mov     rax, [r12 + ST_BLOB_COUNT]
    mov     ecx, BL_SLOT_SIZE
    mul     ecx
    pop     rcx                ; slot index
    add     rbx, rax
    mov     eax, ecx
    mov     ecx, KL_SLOT_SIZE
    mul     ecx
    add     rbx, rax

    ; Copy hash to output
    test    rbp, rbp
    jz      .ig_skip_hash
    mov     rdi, rbp
    mov     esi, HASH_SIZE
    lea     rdx, [rbx + KL_HASH]
    mov     ecx, HASH_SIZE
    call    er_bytes_copy
.ig_skip_hash:

    mov     eax, 1
    pop     rbp
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ok
    ret

.ig_notfound:
    xor     eax, eax
    pop     rbp
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_err  ERROR_NOT_FOUND
    ret
