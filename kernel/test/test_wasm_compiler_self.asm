; EdgeRun host-side WASM compiler self-test.
; Emits a deterministic WASM module and executes it through the interpreter.

%define HAVE_ER_WASM_RUNTIME_PTR
%include "x86_64/wasm/wasm_interpreter.asm"
%include "x86_64/wasm/wasm_compiler.asm"
%include "x86_64/wasm/wasm_test_data.asm"

LINUX_SYS_EXIT equ 60

SECTION .data
dummy_mem: times 256 db 0
export_name: db "f"
EXPORT_NAME_LEN equ 1

SECTION .bss
runtime: resb RUNTIME_SIZE
compiled_wasm: resb 128

global er_wasm_runtime_ptr
er_wasm_runtime_ptr: resq 1

SECTION .text
global _start
_start:
    lea     rdi, [rel compiled_wasm]
    mov     esi, 128
    mov     edx, 42
    lea     rcx, [rel export_name]
    mov     r8d, EXPORT_NAME_LEN
    call    er_wasmc_emit_i32_const_export
    test    rdx, rdx
    jnz     .fail

    mov     r12, rax
    mov     rdi, [rel wasm_return42_len]
    cmp     r12, rdi
    jne     .fail

    lea     rdi, [rel compiled_wasm]
    lea     rsi, [rel wasm_return42_start]
    mov     rdx, r12
    call    _bytes_equal
    test    rax, rax
    jz      .fail

    lea     rdi, [rel dummy_mem]
    mov     esi, 256
    xor     edx, edx
    call    er_fn_init

    lea     rdi, [rel runtime]
    lea     rsi, [rel compiled_wasm]
    mov     rdx, r12
    lea     rcx, [rel export_name]
    mov     r8d, EXPORT_NAME_LEN
    call    er_fn_run
    test    rdx, rdx
    jz      .fail
    cmp     rax, 42
    jne     .fail

    xor     edi, edi
    mov     eax, LINUX_SYS_EXIT
    syscall

.fail:
    mov     edi, 1
    mov     eax, LINUX_SYS_EXIT
    syscall

_bytes_equal:
    test    rdx, rdx
    jz      .equal
.loop:
    mov     al, [rdi]
    cmp     al, [rsi]
    jne     .not_equal
    inc     rdi
    inc     rsi
    dec     rdx
    jnz     .loop
.equal:
    mov     eax, 1
    ret
.not_equal:
    xor     eax, eax
    ret
