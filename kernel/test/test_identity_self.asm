; EdgeRun identity self-test — x86_64 assembly.

%include "x86_64/macros.inc"
%include "test/test_macros.inc"

SOURCE_ED25519_PUBLIC equ 2
SOURCE_HASH equ 1
SOURCE_P256_PUBLIC equ 3
SOURCE_DERIVED equ 7
SOURCE_DELEGATION equ 8
KIND_USER equ 1
KIND_APP equ 3
KIND_DELEGATED equ 9
IDENTITY_SOURCE_SIZE equ 112
IDENTITY_SIZE equ 216
ID_SIZE equ 32
STAMP_SIZE equ 64
IDENTITY_KIND_OFF equ 0
IDENTITY_ID_OFF equ 72
IDENTITY_SOURCE_OFF equ 104
SOURCE_KIND_OFF equ 0

extern er_identity_source_prepare
extern er_identity_source_id
extern er_identity_init
extern er_identity_valid
extern er_identity_eql
extern er_identity_instantiate
extern er_identity_derive_child
extern er_identity_instantiate_app

SECTION .data
public_key:
    db 7
    times 31 db 3
keeper:
    db 2
    times 31 db 0
epoch:
    db 2
    times 31 db 0
    dq 0, 0, 0, 0
manifest_hash:
    times 32 db 0x11
parent_hash:
    times 32 db 0x22
app_hash:
    times 32 db 0x33
scope_hash:
    times 32 db 0x44
p256_key:
    times 64 db 0x55
label_chat: db "chat"
material_manifest: db "manifest"

TEST_BSS_PASSED_FAILED
source: resb IDENTITY_SOURCE_SIZE
source2: resb IDENTITY_SOURCE_SIZE
parent_identity: resb IDENTITY_SIZE
identity_a: resb IDENTITY_SIZE
identity_b: resb IDENTITY_SIZE
child_identity: resb IDENTITY_SIZE
delegated_identity: resb IDENTITY_SIZE
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

    mov     edi, SOURCE_HASH
    lea     rsi, [rel manifest_hash]
    mov     edx, ID_SIZE
    lea     rcx, [rel source]
    call    er_identity_source_prepare
    ASSERT_RAX 1

    mov     edi, SOURCE_HASH
    lea     rsi, [rel manifest_hash]
    mov     edx, 5
    lea     rcx, [rel source2]
    call    er_identity_source_prepare
    ASSERT_RAX 0

    mov     edi, SOURCE_P256_PUBLIC
    lea     rsi, [rel p256_key]
    mov     edx, 64
    lea     rcx, [rel source2]
    call    er_identity_source_prepare
    ASSERT_RAX 1

    mov     edi, KIND_APP
    lea     rsi, [rel source]
    lea     rdx, [rel epoch]
    lea     rcx, [rel identity_a]
    call    er_identity_init
    ASSERT_RAX 1

    mov     edi, KIND_APP
    lea     rsi, [rel source]
    lea     rdx, [rel epoch]
    lea     rcx, [rel identity_b]
    call    er_identity_init
    ASSERT_RAX 1

    lea     rdi, [rel identity_a]
    lea     rsi, [rel identity_b]
    call    er_identity_eql
    ASSERT_RAX 1

    mov     edi, KIND_USER
    mov     esi, SOURCE_HASH
    lea     rdx, [rel parent_hash]
    mov     ecx, ID_SIZE
    lea     r8, [rel epoch]
    lea     r9, [rel parent_identity]
    call    er_identity_instantiate
    ASSERT_RAX 1

    lea     rdi, [rel parent_identity]
    call    er_identity_valid
    ASSERT_RAX 1

    lea     rax, [rel child_identity]
    push    rax
    mov     eax, 8
    push    rax
    lea     rdi, [rel parent_identity]
    mov     esi, KIND_APP
    lea     rdx, [rel epoch]
    lea     rcx, [rel label_chat]
    mov     r8d, 4
    lea     r9, [rel material_manifest]
    call    er_identity_derive_child
    add     rsp, 16
    ASSERT_RAX 1
    ASSERT_WORD [rel child_identity + IDENTITY_KIND_OFF], KIND_APP
    ASSERT_WORD [rel child_identity + IDENTITY_SOURCE_OFF + SOURCE_KIND_OFF], SOURCE_DERIVED
    lea     rdi, [rel child_identity]
    call    er_identity_valid
    ASSERT_RAX 1

    lea     rax, [rel delegated_identity]
    push    rax
    mov     eax, 3
    push    rax
    lea     rdi, [rel parent_identity]
    lea     rsi, [rel app_hash]
    mov     edx, ID_SIZE
    lea     rcx, [rel scope_hash]
    mov     r8d, ID_SIZE
    lea     r9, [rel epoch]
    call    er_identity_instantiate_app
    add     rsp, 16
    ASSERT_RAX 1
    ASSERT_WORD [rel delegated_identity + IDENTITY_KIND_OFF], KIND_DELEGATED
    ASSERT_WORD [rel delegated_identity + IDENTITY_SOURCE_OFF + SOURCE_KIND_OFF], SOURCE_DELEGATION
    lea     rdi, [rel delegated_identity]
    call    er_identity_valid
    ASSERT_RAX 1

    lea     rax, [rel delegated_identity]
    push    rax
    mov     eax, 3
    push    rax
    lea     rdi, [rel parent_identity]
    lea     rsi, [rel app_hash]
    mov     edx, ID_SIZE
    lea     rcx, [rel scope_hash]
    mov     r8d, 5
    lea     r9, [rel epoch]
    call    er_identity_instantiate_app
    add     rsp, 16
    ASSERT_RAX 0

    TEST_EXIT_FAILED
