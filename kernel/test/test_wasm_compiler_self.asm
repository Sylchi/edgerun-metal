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
source_return42: db "export f = 42;"
SOURCE_RETURN42_LEN equ 14
source_named: db "  export answer_1 = 123;  "
SOURCE_NAMED_LEN equ 26
source_add: db "export sum = 40 + 2;"
SOURCE_ADD_LEN equ 20
source_bad: db "export = 1;"
SOURCE_BAD_LEN equ 11
source_negative_bad: db "export f = -7;"
SOURCE_NEGATIVE_BAD_LEN equ 13
answer_name: db "answer_1"
ANSWER_NAME_LEN equ 8
sum_name: db "sum"
SUM_NAME_LEN equ 3

SECTION .bss
runtime: resb RUNTIME_SIZE
compiled_wasm: resb 128
compiled_wasm_b: resb 128

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

    lea     rdi, [rel compiled_wasm]
    mov     esi, 128
    lea     rdx, [rel source_return42]
    mov     ecx, SOURCE_RETURN42_LEN
    call    er_wasmc_compile_source
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

    lea     rdi, [rel compiled_wasm_b]
    mov     esi, 128
    lea     rdx, [rel source_named]
    mov     ecx, SOURCE_NAMED_LEN
    call    er_wasmc_compile_source
    test    rdx, rdx
    jnz     .fail

    mov     r12, rax
    lea     rdi, [rel runtime]
    lea     rsi, [rel compiled_wasm_b]
    mov     rdx, r12
    lea     rcx, [rel answer_name]
    mov     r8d, ANSWER_NAME_LEN
    call    er_fn_run
    test    rdx, rdx
    jz      .fail
    cmp     eax, 123
    jne     .fail

    lea     rdi, [rel compiled_wasm_b]
    mov     esi, 128
    lea     rdx, [rel source_add]
    mov     ecx, SOURCE_ADD_LEN
    call    er_wasmc_compile_source
    test    rdx, rdx
    jnz     .fail

    mov     r12, rax
    lea     rdi, [rel runtime]
    lea     rsi, [rel compiled_wasm_b]
    mov     rdx, r12
    lea     rcx, [rel sum_name]
    mov     r8d, SUM_NAME_LEN
    call    er_fn_run
    test    rdx, rdx
    jz      .fail
    cmp     eax, 42
    jne     .fail

    lea     rdi, [rel compiled_wasm_b]
    mov     esi, 128
    lea     rdx, [rel source_bad]
    mov     ecx, SOURCE_BAD_LEN
    call    er_wasmc_compile_source
    cmp     rdx, ERROR_PARSE
    jne     .fail

    lea     rdi, [rel compiled_wasm_b]
    mov     esi, 128
    lea     rdx, [rel source_negative_bad]
    mov     ecx, SOURCE_NEGATIVE_BAD_LEN
    call    er_wasmc_compile_source
    cmp     rdx, ERROR_PARSE
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
