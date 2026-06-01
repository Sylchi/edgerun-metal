; EdgeRun identity self-test — x86_64 assembly.

%include "x86_64/macros.inc"
%include "test/test_macros.inc"

SOURCE_ED25519_PUBLIC equ 2
IDENTITY_SOURCE_SIZE equ 112
ID_SIZE equ 32

extern er_identity_source_prepare
extern er_identity_source_id

SECTION .data
public_key:
    db 7
    times 31 db 3

TEST_BSS_PASSED_FAILED
source: resb IDENTITY_SOURCE_SIZE
out_id: resb ID_SIZE

SECTION .text
global _start
_start:
    mov     edi, SOURCE_ED25519_PUBLIC
    lea     rsi, [rel public_key]
    mov     edx, ID_SIZE
    lea     rcx, [rel source]
    call    er_identity_source_prepare
    ASSERT_RDX 0

    lea     rdi, [rel source]
    lea     rsi, [rel out_id]
    call    er_identity_source_id
    ASSERT_RDX 0
    ASSERT_MEM_EQ [rel public_key], [rel out_id], ID_SIZE

    TEST_EXIT_FAILED
