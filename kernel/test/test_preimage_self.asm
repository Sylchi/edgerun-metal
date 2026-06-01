; EdgeRun preimage self-test — x86_64 assembly.

%include "x86_64/macros.inc"
%include "test/test_macros.inc"

extern er_preimage_hash
extern er_preimage_writer_init
extern er_preimage_writer_written
extern er_preimage_writer_id
extern er_preimage_writer_write_u16
extern er_preimage_writer_write_u64
extern er_preimage_writer_epoch
extern er_preimage_decode_epoch
extern er_stamp_order

WRITER_SIZE equ 24
STAMP_SIZE equ 64
HASH_SIZE equ 32
RAW_SIZE equ 106

SECTION .bss
TEST_BSS_PASSED_FAILED
writer: resb WRITER_SIZE
raw: resb RAW_SIZE
hash_out: resb HASH_SIZE
decoded_stamp: resb STAMP_SIZE

SECTION .data
id_value:
    db 3
    times 31 db 0

stamp1:
    db 1
    times 31 db 0
    dq 2
    dq 0
    dq 0
    dq 0

domain: db "edgerun:zig:v1:test"
DOMAIN_LEN equ $ - domain
value: db "preimage"
VALUE_LEN equ $ - value
expected_u16_4: db 4, 0

SECTION .text
global _start
_start:
    lea     rdi, [rel writer]
    lea     rsi, [rel raw]
    mov     edx, RAW_SIZE
    call    er_preimage_writer_init

    lea     rdi, [rel writer]
    lea     rsi, [rel id_value]
    call    er_preimage_writer_id
    ASSERT_RAX 1

    lea     rdi, [rel writer]
    mov     esi, 4
    call    er_preimage_writer_write_u16
    ASSERT_RAX 1

    lea     rdi, [rel writer]
    mov     esi, 5
    call    er_preimage_writer_write_u64
    ASSERT_RAX 1

    lea     rdi, [rel writer]
    lea     rsi, [rel stamp1]
    call    er_preimage_writer_epoch
    ASSERT_RAX 1

    lea     rdi, [rel writer]
    call    er_preimage_writer_written
    ASSERT_RAX RAW_SIZE

    ASSERT_MEM_EQ [rel id_value], [rel raw], 32
    ASSERT_MEM_EQ [rel expected_u16_4], [rel raw + 32], 2
    ASSERT_QWORD [rel raw + 34], 5

    lea     rdi, [rel raw + 42]
    mov     esi, STAMP_SIZE
    lea     rdx, [rel decoded_stamp]
    call    er_preimage_decode_epoch
    ASSERT_RAX 1

    lea     rdi, [rel stamp1]
    lea     rsi, [rel decoded_stamp]
    call    er_stamp_order
    ASSERT_RAX 0

    lea     rdi, [rel domain]
    mov     esi, DOMAIN_LEN
    lea     rdx, [rel value]
    mov     ecx, VALUE_LEN
    lea     r8, [rel hash_out]
    call    er_preimage_hash
    ASSERT_RAX 1

    cmp     qword [rel hash_out], 0
    jne     .hash_nonzero
    cmp     qword [rel hash_out + 8], 0
    jne     .hash_nonzero
    cmp     qword [rel hash_out + 16], 0
    jne     .hash_nonzero
    cmp     qword [rel hash_out + 24], 0
    jne     .hash_nonzero
    inc     qword [rel failed]
    jmp     .hash_done
.hash_nonzero:
    inc     qword [rel passed]
.hash_done:
    TEST_EXIT_FAILED
