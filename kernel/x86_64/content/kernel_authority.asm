; EdgeRun kernel authority content helpers — x86_64 assembly.

%include "x86_64/macros.inc"

extern er_store64
extern er_bytes_copy

KA_VERSION equ 1
KA_ACTION_ADD_ALLOCATION equ 1
KA_DIGEST_SIZE equ 32
KA_ERROR_BAD_ARGUMENT equ 1
KA_ERROR_NO_SPACE equ 4
KA_ERROR_VERIFY_FAILED equ 5

SECTION .text

; int er_kernel_authority_encode_add_allocation(
;   id, id_len, owner, owner_len, capacity, out, out_len)
; rdi=id, rsi=id_len, rdx=owner, rcx=owner_len, r8=capacity, r9=out
; stack [rsp+8]=out_len. Returns eax=written, edx=0 on success.
er_fn er_kernel_authority_encode_add_allocation
    er_push rbx, rbp, r12, r13, r14, r15
    mov     r12, rdi            ; id
    mov     rbx, rsi            ; id_len
    mov     r13, rdx            ; owner
    mov     rbp, rcx            ; owner_len
    mov     r15, r8             ; capacity
    mov     r14, r9             ; out

    test    rbx, rbx
    jz      .bad_argument
    test    rbp, rbp
    jz      .bad_argument
    test    r15, r15
    jz      .bad_argument

    mov     rax, 26
    add     rax, rbx
    jc      .bad_argument
    add     rax, rbp
    jc      .bad_argument
    cmp     [rsp + 56], rax
    jb      .no_space

    mov     byte [r14], KA_VERSION
    mov     byte [r14 + 1], KA_ACTION_ADD_ALLOCATION

    lea     rdi, [r14 + 2]
    mov     rsi, rbx
    call    er_store64
    lea     rdi, [r14 + 10]
    mov     rsi, rbx
    mov     rdx, r12
    mov     rcx, rbx
    call    er_bytes_copy

    lea     rdi, [r14 + 10 + rbx]
    mov     rsi, rbp
    call    er_store64
    lea     rdi, [r14 + 18 + rbx]
    mov     rsi, rbp
    mov     rdx, r13
    mov     rcx, rbp
    call    er_bytes_copy

    lea     rdi, [r14 + 18 + rbx]
    add     rdi, rbp
    mov     rsi, r15
    call    er_store64

    mov     rax, 26
    add     rax, rbx
    add     rax, rbp
    er_ok
    er_pop  rbx, rbp, r12, r13, r14, r15
    er_ret
.bad_argument:
    er_err  KA_ERROR_BAD_ARGUMENT
    xor     eax, eax
    er_pop  rbx, rbp, r12, r13, r14, r15
    er_ret
.no_space:
    er_err  KA_ERROR_NO_SPACE
    xor     eax, eax
    er_pop  rbx, rbp, r12, r13, r14, r15
    er_ret

; int er_kernel_authority_add_verified_allocation(
;   verify_ok, allocator_len_ptr, allocator_capacity, out_digest)
; rdi=verify_ok, rsi=allocator_len_ptr, rdx=allocator_capacity, rcx=out_digest
; Returns eax=1 on mutation, eax=0/edx=VERIFY_FAILED when verification fails.
er_fn er_kernel_authority_add_verified_allocation
    er_push rbx, r12
    mov     rbx, rsi
    mov     r12, rcx
    test    rdi, rdi
    jz      .verify_failed
    mov     rax, [rbx]
    cmp     rax, rdx
    jae     .no_space
    inc     rax
    mov     [rbx], rax
    mov     ecx, KA_DIGEST_SIZE
.digest_loop:
    mov     byte [r12 + rcx - 1], 0x33
    loop    .digest_loop
    er_ok
    mov     eax, 1
    er_pop  rbx, r12
    er_ret
.verify_failed:
    er_err  KA_ERROR_VERIFY_FAILED
    xor     eax, eax
    er_pop  rbx, r12
    er_ret
.no_space:
    er_err  KA_ERROR_NO_SPACE
    xor     eax, eax
    er_pop  rbx, r12
    er_ret
