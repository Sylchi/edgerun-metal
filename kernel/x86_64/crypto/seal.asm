; EdgeRun seal policy helpers — x86_64 assembly.

%include "x86_64/macros.inc"

extern er_bytes_nonzero
extern er_bytes_zero
extern er_bytes_copy
extern er_store16
extern er_store32
extern er_preimage_hash

SEAL_ID_SIZE equ 32
SEAL_ENCODED_SIZE equ 116
SEAL_DOMAIN_LEN equ 28

SEAL_SCOPE_PUBLIC equ 1
SEAL_SCOPE_INTEGRITY_ONLY equ 2
SEAL_SCOPE_MACHINE_APP equ 3
SEAL_SCOPE_MACHINE_APP_USER equ 4
SEAL_SCOPE_SYNC_TRANSFER equ 5

SEAL_ALG_NONE equ 0
SEAL_ALG_BLAKE3 equ 1
SEAL_ALG_TPM_SEALED_AES256 equ 2
SEAL_ALG_RECIPIENT_SEALED_AES256 equ 3

struc er_seal_policy
    .scope:     resw 1
    .algorithm: resw 1
    .flags:     resd 1
    .device:    resb SEAL_ID_SIZE
    .app:       resb SEAL_ID_SIZE
    .user:      resb SEAL_ID_SIZE
    .has_device: resb 1
    .has_app:    resb 1
    .has_user:   resb 1
    .pad:        resb 5
endstruc

SECTION .text

er_fn er_seal_policy_public
    mov     rax, rdi
    mov     esi, er_seal_policy_size
    call    er_bytes_zero
    mov     word [rax + er_seal_policy.scope], SEAL_SCOPE_PUBLIC
    mov     word [rax + er_seal_policy.algorithm], SEAL_ALG_NONE
    mov     eax, 1
    er_ret

er_fn er_seal_policy_integrity_only
    mov     rax, rdi
    mov     esi, er_seal_policy_size
    call    er_bytes_zero
    mov     word [rax + er_seal_policy.scope], SEAL_SCOPE_INTEGRITY_ONLY
    mov     word [rax + er_seal_policy.algorithm], SEAL_ALG_BLAKE3
    mov     eax, 1
    er_ret

; int er_seal_policy_machine_app_user_ids(device_id, app_id, user_id, out_policy)
; rdi=device, rsi=app, rdx=user, rcx=out_policy
er_fn er_seal_policy_machine_app_user_ids
    er_push rbx, r12, r13, r14
    mov     r12, rdi
    mov     r13, rsi
    mov     r14, rdx
    mov     rbx, rcx

    mov     rdi, rbx
    mov     esi, er_seal_policy_size
    call    er_bytes_zero

    mov     word [rbx + er_seal_policy.scope], SEAL_SCOPE_MACHINE_APP_USER
    mov     word [rbx + er_seal_policy.algorithm], SEAL_ALG_TPM_SEALED_AES256
    mov     byte [rbx + er_seal_policy.has_device], 1
    mov     byte [rbx + er_seal_policy.has_app], 1
    mov     byte [rbx + er_seal_policy.has_user], 1

    lea     rdi, [rbx + er_seal_policy.device]
    mov     esi, SEAL_ID_SIZE
    mov     rdx, r12
    mov     ecx, SEAL_ID_SIZE
    call    er_bytes_copy
    lea     rdi, [rbx + er_seal_policy.app]
    mov     esi, SEAL_ID_SIZE
    mov     rdx, r13
    mov     ecx, SEAL_ID_SIZE
    call    er_bytes_copy
    lea     rdi, [rbx + er_seal_policy.user]
    mov     esi, SEAL_ID_SIZE
    mov     rdx, r14
    mov     ecx, SEAL_ID_SIZE
    call    er_bytes_copy

    er_pop  rbx, r12, r13, r14
    mov     eax, 1
    er_ret

; int er_seal_policy_valid(policy)
; rdi=policy
er_fn er_seal_policy_valid
    er_push rbx
    mov     rbx, rdi
    movzx   eax, word [rbx + er_seal_policy.scope]
    cmp     eax, SEAL_SCOPE_PUBLIC
    je      .valid_public
    cmp     eax, SEAL_SCOPE_INTEGRITY_ONLY
    je      .valid_integrity
    cmp     eax, SEAL_SCOPE_MACHINE_APP
    je      .valid_machine_app
    cmp     eax, SEAL_SCOPE_MACHINE_APP_USER
    je      .valid_machine_app_user
    cmp     eax, SEAL_SCOPE_SYNC_TRANSFER
    je      .valid_sync_transfer
    jmp     .invalid

.valid_public:
    cmp     word [rbx + er_seal_policy.algorithm], SEAL_ALG_NONE
    jne     .invalid
    cmp     byte [rbx + er_seal_policy.has_device], 0
    jne     .invalid
    cmp     byte [rbx + er_seal_policy.has_app], 0
    jne     .invalid
    cmp     byte [rbx + er_seal_policy.has_user], 0
    jne     .invalid
    jmp     .valid
.valid_integrity:
    cmp     word [rbx + er_seal_policy.algorithm], SEAL_ALG_BLAKE3
    jne     .invalid
    cmp     byte [rbx + er_seal_policy.has_device], 0
    jne     .invalid
    cmp     byte [rbx + er_seal_policy.has_app], 0
    jne     .invalid
    cmp     byte [rbx + er_seal_policy.has_user], 0
    jne     .invalid
    jmp     .valid
.valid_machine_app:
    cmp     word [rbx + er_seal_policy.algorithm], SEAL_ALG_TPM_SEALED_AES256
    jne     .invalid
    cmp     byte [rbx + er_seal_policy.has_device], 1
    jne     .invalid
    cmp     byte [rbx + er_seal_policy.has_app], 1
    jne     .invalid
    cmp     byte [rbx + er_seal_policy.has_user], 0
    jne     .invalid
    lea     rdi, [rbx + er_seal_policy.device]
    call    er_seal_id_valid
    test    eax, eax
    jz      .invalid
    lea     rdi, [rbx + er_seal_policy.app]
    call    er_seal_id_valid
    test    eax, eax
    jz      .invalid
    jmp     .valid
.valid_machine_app_user:
    cmp     word [rbx + er_seal_policy.algorithm], SEAL_ALG_TPM_SEALED_AES256
    jne     .invalid
    jmp     .valid_three_ids
.valid_sync_transfer:
    cmp     word [rbx + er_seal_policy.algorithm], SEAL_ALG_RECIPIENT_SEALED_AES256
    jne     .invalid
.valid_three_ids:
    cmp     byte [rbx + er_seal_policy.has_device], 1
    jne     .invalid
    cmp     byte [rbx + er_seal_policy.has_app], 1
    jne     .invalid
    cmp     byte [rbx + er_seal_policy.has_user], 1
    jne     .invalid
    lea     rdi, [rbx + er_seal_policy.device]
    call    er_seal_id_valid
    test    eax, eax
    jz      .invalid
    lea     rdi, [rbx + er_seal_policy.app]
    call    er_seal_id_valid
    test    eax, eax
    jz      .invalid
    lea     rdi, [rbx + er_seal_policy.user]
    call    er_seal_id_valid
    test    eax, eax
    jz      .invalid
.valid:
    er_pop  rbx
    mov     eax, 1
    er_ret
.invalid:
    er_pop  rbx
    xor     eax, eax
    er_ret

er_seal_id_valid:
    mov     esi, SEAL_ID_SIZE
    jmp     er_bytes_nonzero

; int er_seal_policy_encode(policy, out, out_len)
; rdi=policy, rsi=out, rdx=out_len
er_fn er_seal_policy_encode
    er_push rbx, r12
    cmp     rdx, SEAL_ENCODED_SIZE
    jb      .encode_fail
    mov     rbx, rdi
    mov     r12, rsi
    call    er_seal_policy_valid
    test    eax, eax
    jz      .encode_fail

    mov     rdi, r12
    mov     esi, SEAL_ENCODED_SIZE
    call    er_bytes_zero
    movzx   esi, word [rbx + er_seal_policy.scope]
    mov     rdi, r12
    call    er_store16
    movzx   esi, word [rbx + er_seal_policy.algorithm]
    lea     rdi, [r12 + 2]
    call    er_store16
    mov     esi, [rbx + er_seal_policy.flags]
    lea     rdi, [r12 + 4]
    call    er_store32
    lea     rdi, [r12 + 8]
    mov     esi, SEAL_ID_SIZE
    lea     rdx, [rbx + er_seal_policy.device]
    mov     ecx, SEAL_ID_SIZE
    call    er_bytes_copy
    lea     rdi, [r12 + 40]
    mov     esi, SEAL_ID_SIZE
    lea     rdx, [rbx + er_seal_policy.app]
    mov     ecx, SEAL_ID_SIZE
    call    er_bytes_copy
    lea     rdi, [r12 + 72]
    mov     esi, SEAL_ID_SIZE
    lea     rdx, [rbx + er_seal_policy.user]
    mov     ecx, SEAL_ID_SIZE
    call    er_bytes_copy
    er_pop  rbx, r12
    mov     eax, 1
    er_ret
.encode_fail:
    er_pop  rbx, r12
    xor     eax, eax
    er_ret

; int er_seal_policy_id(policy, out_hash)
; rdi=policy, rsi=out_hash
er_fn er_seal_policy_id
    er_push rbx, r12
    mov     rbx, rdi
    mov     r12, rsi
    sub     rsp, SEAL_ENCODED_SIZE
    mov     rdi, rbx
    mov     rsi, rsp
    mov     edx, SEAL_ENCODED_SIZE
    call    er_seal_policy_encode
    test    eax, eax
    jz      .id_fail
    lea     rdi, [rel .domain]
    mov     esi, SEAL_DOMAIN_LEN
    mov     rdx, rsp
    mov     ecx, SEAL_ENCODED_SIZE
    mov     r8, r12
    call    er_preimage_hash
    add     rsp, SEAL_ENCODED_SIZE
    er_pop  rbx, r12
    er_ret
.id_fail:
    add     rsp, SEAL_ENCODED_SIZE
    er_pop  rbx, r12
    xor     eax, eax
    er_ret

.domain: db "edgerun:zig:v1:seal-policy"
