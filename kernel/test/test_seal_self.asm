; EdgeRun seal policy self-test — x86_64 assembly.

%include "x86_64/macros.inc"
%include "test/test_macros.inc"

extern er_seal_policy_public
extern er_seal_policy_integrity_only
extern er_seal_policy_machine_app_user_ids
extern er_seal_policy_valid
extern er_seal_policy_encode
extern er_seal_policy_id

SEAL_POLICY_SIZE equ 112
SEAL_ENCODED_SIZE equ 116
HASH_SIZE equ 32
SCOPE_MACHINE_APP_USER equ 4
ALG_TPM_SEALED_AES256 equ 2
SCOPE_PUBLIC equ 1
ALG_NONE equ 0
SCOPE_INTEGRITY_ONLY equ 2
ALG_BLAKE3 equ 1

SECTION .bss
TEST_BSS_PASSED_FAILED
policy: resb SEAL_POLICY_SIZE
encoded: resb SEAL_ENCODED_SIZE
hash_out: resb HASH_SIZE

SECTION .data
device_id:
    db 1
    times 31 db 0
app_id:
    db 2
    times 31 db 0
user_id:
    db 3
    times 31 db 0

SECTION .text
global _start
_start:
    lea     rdi, [rel device_id]
    lea     rsi, [rel app_id]
    lea     rdx, [rel user_id]
    lea     rcx, [rel policy]
    call    er_seal_policy_machine_app_user_ids
    ASSERT_RAX 1

    lea     rdi, [rel policy]
    call    er_seal_policy_valid
    ASSERT_RAX 1

    lea     rdi, [rel policy]
    lea     rsi, [rel encoded]
    mov     edx, SEAL_ENCODED_SIZE
    call    er_seal_policy_encode
    ASSERT_RAX 1
    ASSERT_WORD [rel encoded], SCOPE_MACHINE_APP_USER
    ASSERT_WORD [rel encoded + 2], ALG_TPM_SEALED_AES256
    ASSERT_MEM_EQ [rel device_id], [rel encoded + 8], HASH_SIZE
    ASSERT_MEM_EQ [rel app_id], [rel encoded + 40], HASH_SIZE
    ASSERT_MEM_EQ [rel user_id], [rel encoded + 72], HASH_SIZE

    lea     rdi, [rel policy]
    lea     rsi, [rel hash_out]
    call    er_seal_policy_id
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

    lea     rdi, [rel policy]
    call    er_seal_policy_public
    ASSERT_RAX 1
    lea     rdi, [rel policy]
    call    er_seal_policy_valid
    ASSERT_RAX 1
    lea     rdi, [rel policy]
    lea     rsi, [rel encoded]
    mov     edx, SEAL_ENCODED_SIZE
    call    er_seal_policy_encode
    ASSERT_RAX 1
    ASSERT_WORD [rel encoded], SCOPE_PUBLIC
    ASSERT_WORD [rel encoded + 2], ALG_NONE

    lea     rdi, [rel policy]
    call    er_seal_policy_integrity_only
    ASSERT_RAX 1
    lea     rdi, [rel policy]
    call    er_seal_policy_valid
    ASSERT_RAX 1
    lea     rdi, [rel policy]
    lea     rsi, [rel encoded]
    mov     edx, SEAL_ENCODED_SIZE
    call    er_seal_policy_encode
    ASSERT_RAX 1
    ASSERT_WORD [rel encoded], SCOPE_INTEGRITY_ONLY
    ASSERT_WORD [rel encoded + 2], ALG_BLAKE3

    TEST_EXIT_FAILED
