; EdgeRun persistent store replay self-hosted test.
; Covers blob hash staging, live index updates, and log replay rebuilding
; in-memory blob/key indexes from persisted records.

%include "test/test_macros.inc"

STORE_SCRATCH        equ 0x306000
SCRATCH_MAP_BYTES    equ 8192
STATE_BYTES          equ 65536
DISK_BYTES           equ 65536
BLOCK_BYTES          equ 512
ST_STRUCT_SIZE       equ 112
BL_HASH              equ 1
BL_SLOT_SIZE         equ 56
SYS_MMAP             equ 9
SYS_EXIT             equ 60
PROT_READ_WRITE      equ 3
MAP_PRIVATE_FIXED_ANON equ 0x32

extern er_store_init
extern er_store_sync
extern er_store_put_blob
extern er_store_get_blob
extern er_store_index_put
extern er_store_index_get
extern er_memset

TEST_DATA_TOTAL_PASSED_FAILED

SECTION .bss
fake_disk:      resb DISK_BYTES
state_a:        resb STATE_BYTES
state_b:        resb STATE_BYTES
state_c:        resb STATE_BYTES
hash_one:       resb 32
hash_two:       resb 32
out_hash:       resb 32
out_blob:       resb 64
out_len:        resq 1

SECTION .text
global _start
_start:
    call    map_store_scratch
    call    clear_test_memory

    lea     rdi, [rel state_a]
    mov     esi, STATE_BYTES
    xor     edx, edx
    call    er_store_init
    ASSERT_EQ eax, 0
    ASSERT_EQ edx, 0

    lea     rdi, [rel state_a]
    lea     rsi, [rel blob_one]
    mov     edx, blob_one_len
    call    er_store_put_blob
    ASSERT_EQ eax, 0
    ASSERT_EQ edx, 0

    lea     rdi, [rel hash_one]
    mov     esi, 32
    lea     rdx, [rel state_a + ST_STRUCT_SIZE + BL_HASH]
    mov     ecx, 32
    call    copy_bytes

    lea     rdi, [rel state_a]
    lea     rsi, [rel blob_two]
    mov     edx, blob_two_len
    call    er_store_put_blob
    ASSERT_EQ eax, 0
    ASSERT_EQ edx, 0

    lea     rdi, [rel hash_two]
    mov     esi, 32
    lea     rdx, [rel state_a + ST_STRUCT_SIZE + BL_SLOT_SIZE + BL_HASH]
    mov     ecx, 32
    call    copy_bytes

    ; A second blob must not corrupt the first slot's hash.
    ASSERT_MEM_EQ [rel state_a + ST_STRUCT_SIZE + BL_HASH], [rel hash_one], 32

    lea     rdi, [rel state_a]
    mov     esi, 7
    lea     rdx, [rel key_alpha]
    mov     ecx, key_alpha_len
    lea     r8, [rel hash_one]
    call    er_store_index_put
    ASSERT_EQ eax, 0
    ASSERT_EQ edx, 0

    lea     rdi, [rel state_a]
    mov     esi, 7
    lea     rdx, [rel key_alpha]
    mov     ecx, key_alpha_len
    lea     r8, [rel hash_two]
    call    er_store_index_put
    ASSERT_EQ eax, 0
    ASSERT_EQ edx, 0

    ; Updating an existing key must update the live slot immediately.
    lea     rdi, [rel state_a]
    mov     esi, 7
    lea     rdx, [rel key_alpha]
    mov     ecx, key_alpha_len
    lea     r8, [rel out_hash]
    call    er_store_index_get
    ASSERT_EQ eax, 1
    ASSERT_EQ edx, 0
    ASSERT_MEM_EQ [rel out_hash], [rel hash_two], 32

    lea     rdi, [rel state_a]
    call    er_store_sync
    ASSERT_EQ eax, 0
    ASSERT_EQ edx, 0

    ; Reopen from fake disk: replay must rebuild blob and key indexes.
    lea     rdi, [rel state_b]
    mov     esi, STATE_BYTES
    xor     edx, edx
    call    er_store_init
    ASSERT_EQ eax, 0
    ASSERT_EQ edx, 0

    lea     rdi, [rel state_b]
    mov     esi, 7
    lea     rdx, [rel key_alpha]
    mov     ecx, key_alpha_len
    lea     r8, [rel out_hash]
    call    er_store_index_get
    ASSERT_EQ eax, 1
    ASSERT_EQ edx, 0
    ASSERT_MEM_EQ [rel out_hash], [rel hash_two], 32

    mov     qword [rel out_len], 64
    lea     rdi, [rel state_b]
    lea     rsi, [rel hash_two]
    lea     rdx, [rel out_blob]
    lea     rcx, [rel out_len]
    call    er_store_get_blob
    ASSERT_EQ eax, 0
    ASSERT_EQ edx, 0
    ASSERT_QWORD [rel out_len], blob_two_len
    ASSERT_MEM_EQ [rel out_blob], [rel blob_two], blob_two_len

    ; Reopen a second time to catch replay state carried in globals.
    lea     rdi, [rel state_c]
    mov     esi, STATE_BYTES
    xor     edx, edx
    call    er_store_init
    ASSERT_EQ eax, 0
    ASSERT_EQ edx, 0

    lea     rdi, [rel state_c]
    mov     esi, 7
    lea     rdx, [rel key_alpha]
    mov     ecx, key_alpha_len
    lea     r8, [rel out_hash]
    call    er_store_index_get
    ASSERT_EQ eax, 1
    ASSERT_EQ edx, 0
    ASSERT_MEM_EQ [rel out_hash], [rel hash_two], 32

    TEST_EXIT_FAILED

map_store_scratch:
    mov     eax, SYS_MMAP
    mov     edi, STORE_SCRATCH
    mov     esi, SCRATCH_MAP_BYTES
    mov     edx, PROT_READ_WRITE
    mov     r10d, MAP_PRIVATE_FIXED_ANON
    mov     r8, -1
    xor     r9d, r9d
    syscall
    cmp     rax, STORE_SCRATCH
    je      .mapped
    mov     edi, 90
    mov     eax, SYS_EXIT
    syscall
.mapped:
    ret

clear_test_memory:
    lea     rdi, [rel fake_disk]
    xor     esi, esi
    mov     edx, DISK_BYTES
    call    er_memset
    lea     rdi, [rel state_a]
    xor     esi, esi
    mov     edx, STATE_BYTES
    call    er_memset
    lea     rdi, [rel state_b]
    xor     esi, esi
    mov     edx, STATE_BYTES
    call    er_memset
    lea     rdi, [rel state_c]
    xor     esi, esi
    mov     edx, STATE_BYTES
    call    er_memset
    ret

copy_bytes:
    cmp     esi, ecx
    jb      .too_large
    mov     rsi, rdx
    mov     edx, ecx
    call    er_memcpy
    ret
.too_large:
    mov     edi, 91
    mov     eax, SYS_EXIT
    syscall

global er_nvme_read_blocks
er_nvme_read_blocks:
    push    rsi
    mov     rdi, rdx
    lea     rsi, [rel fake_disk]
    pop     rax
    shl     rax, 9
    add     rsi, rax
    mov     eax, ecx
    shl     eax, 9
    mov     ecx, eax
    cld
    rep     movsb
    xor     eax, eax
    ret

global er_nvme_write_blocks
er_nvme_write_blocks:
    push    rsi
    mov     rsi, rdx
    lea     rdi, [rel fake_disk]
    pop     rax
    shl     rax, 9
    add     rdi, rax
    mov     eax, ecx
    shl     eax, 9
    mov     ecx, eax
    cld
    rep     movsb
    xor     eax, eax
    ret

global er_preimage_raw_hash
er_preimage_raw_hash:
    push    rbx
    push    r12
    push    r13
    mov     r12, rdi
    mov     ebx, esi
    mov     r13, rdx
    mov     rdi, rdx
    xor     esi, esi
    mov     edx, 32
    call    er_memset
    mov     rdi, r13
    mov     [rdi], ebx
    lea     rdi, [rdi + 4]
    mov     rsi, r12
    mov     ecx, ebx
    cmp     ecx, 28
    jbe     .hash_copy
    mov     ecx, 28
.hash_copy:
    test    ecx, ecx
    jz      .hash_done
    cld
    rep     movsb
.hash_done:
    pop     r13
    pop     r12
    pop     rbx
    xor     eax, eax
    ret

extern er_memcpy

SECTION .rodata
blob_one:       db "first persistent blob"
blob_one_len    equ $ - blob_one
blob_two:       db "second persisted blob payload"
blob_two_len    equ $ - blob_two
key_alpha:      db "alpha"
key_alpha_len   equ $ - key_alpha
