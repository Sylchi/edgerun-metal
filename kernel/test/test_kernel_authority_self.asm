; EdgeRun kernel authority content self-test — x86_64 assembly.

%include "x86_64/macros.inc"
%include "test/test_macros.inc"

extern er_kernel_authority_encode_add_allocation
extern er_kernel_authority_add_verified_allocation

ERROR_BAD_ARGUMENT equ 1
ERROR_NO_SPACE equ 4
ERROR_VERIFY_FAILED equ 5
DIGEST_SIZE equ 32

SECTION .bss
TEST_BSS_PASSED_FAILED
canonical: resb 64
digest: resb DIGEST_SIZE
allocator_len: resq 1

SECTION .data
alloc_id: db "alloc-a"
ALLOC_ID_LEN equ $ - alloc_id
owner_id: db "root-user"
OWNER_ID_LEN equ $ - owner_id
expected:
    db 1, 1
    dq ALLOC_ID_LEN
    db "alloc-a"
    dq OWNER_ID_LEN
    db "root-user"
    dq 128
EXPECTED_LEN equ $ - expected

SECTION .text
global _start
_start:
    mov     rax, 64
    push    rax
    lea     rdi, [rel alloc_id]
    mov     esi, ALLOC_ID_LEN
    lea     rdx, [rel owner_id]
    mov     ecx, OWNER_ID_LEN
    mov     r8d, 128
    lea     r9, [rel canonical]
    call    er_kernel_authority_encode_add_allocation
    add     rsp, 8
    ASSERT_RAX EXPECTED_LEN
    ASSERT_RDX 0
    ASSERT_MEM_EQ [rel expected], [rel canonical], EXPECTED_LEN

    mov     rax, EXPECTED_LEN - 1
    push    rax
    lea     rdi, [rel alloc_id]
    mov     esi, ALLOC_ID_LEN
    lea     rdx, [rel owner_id]
    mov     ecx, OWNER_ID_LEN
    mov     r8d, 128
    lea     r9, [rel canonical]
    call    er_kernel_authority_encode_add_allocation
    add     rsp, 8
    ASSERT_RAX 0
    ASSERT_RDX ERROR_NO_SPACE

    mov     rax, 64
    push    rax
    lea     rdi, [rel alloc_id]
    mov     esi, ALLOC_ID_LEN
    lea     rdx, [rel owner_id]
    mov     ecx, OWNER_ID_LEN
    xor     r8d, r8d
    lea     r9, [rel canonical]
    call    er_kernel_authority_encode_add_allocation
    add     rsp, 8
    ASSERT_RAX 0
    ASSERT_RDX ERROR_BAD_ARGUMENT

    mov     qword [rel allocator_len], 0
    mov     edi, 1
    lea     rsi, [rel allocator_len]
    mov     edx, 1
    lea     rcx, [rel digest]
    call    er_kernel_authority_add_verified_allocation
    ASSERT_RAX 1
    ASSERT_RDX 0
    ASSERT_QWORD [rel allocator_len], 1
    lea     rdi, [rel digest]
    ASSERT_MEM_ALL 0x33, DIGEST_SIZE

    mov     qword [rel allocator_len], 0
    xor     edi, edi
    lea     rsi, [rel allocator_len]
    mov     edx, 1
    lea     rcx, [rel digest]
    call    er_kernel_authority_add_verified_allocation
    ASSERT_RAX 0
    ASSERT_RDX ERROR_VERIFY_FAILED
    ASSERT_QWORD [rel allocator_len], 0

    TEST_EXIT_FAILED
