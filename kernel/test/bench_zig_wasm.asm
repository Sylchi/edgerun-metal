; Benchmark the same Zig function compiled as native x86_64 and wasm32.
;
; build.sh produces:
;   .build/kernel/zig_wasm_bench_native.o
;   .build/kernel/zig_wasm_bench.wasm

%define HAVE_ER_WASM_RUNTIME_PTR
%include "x86_64/wasm/wasm_interpreter.asm"

%ifndef ZIG_WASM_BENCH_PATH
%define ZIG_WASM_BENCH_PATH ".build/kernel/zig_wasm_bench.wasm"
%endif

extern er_bench

LINUX_SYS_EXIT     equ 60
LINUX_SYS_MPROTECT equ 10
LINUX_PROT_READ    equ 1
LINUX_PROT_WRITE   equ 2
LINUX_PROT_EXEC    equ 4
LINUX_PAGE_SIZE    equ 4096
LINUX_PAGE_MASK    equ -LINUX_PAGE_SIZE

ITERS_NATIVE equ 5000000
ITERS_INTERP equ 100000
ITERS_JIT    equ 1000000

SECTION .rodata
zig_wasm_start:
    incbin ZIG_WASM_BENCH_PATH
zig_wasm_end:
zig_wasm_len: dq zig_wasm_end - zig_wasm_start

bench_export_name: db "er_bench"
BENCH_EXPORT_NAME_LEN equ 8

str_title:  db "zig native x86 vs wasm interpreter vs wasm jit", 10, 0
str_native: db "native_x86_cycles: ", 0
str_interp: db "wasm_interp_cycles: ", 0
str_jit:    db "wasm_jit_cycles:    ", 0
str_fail:   db "FAIL", 10, 0
str_done:   db "done", 10, 0

SECTION .bss
runtime: resb RUNTIME_SIZE
dummy_mem: resb 1048576
args: resq 1
func_idx: resq 1
fail_stage: resq 1

global er_wasm_runtime_ptr
er_wasm_runtime_ptr: resq 1

SECTION .text
global _start
_start:
    mov     qword [rel fail_stage], 1
    lea     rdi, [rel str_title]
    call    puts

    mov     qword [rel fail_stage], 2
    call    make_jit_cache_executable

    mov     qword [rel fail_stage], 3
    lea     rax, [rel dummy_mem]
    mov     [rel runtime + RUNTIME_MEMORY_PTR_OFF], rax
    mov     qword [rel runtime + RUNTIME_MEMORY_LEN_OFF], 1048576
    mov     qword [rel runtime + RUNTIME_TICKS_PTR_OFF], 0
    mov     qword [rel runtime + RUNTIME_MEM_GROW_FN_OFF], 0
    mov     qword [rel runtime + RUNTIME_MEM_GROW_CTX_OFF], 0
    mov     qword [rel runtime + RUNTIME_TABLE_GROW_FN_OFF], 0
    mov     qword [rel runtime + RUNTIME_TABLE_GROW_CTX_OFF], 0
    mov     qword [rel runtime + RUNTIME_INITIAL_PAGES_OFF], 16
    mov     byte  [rel runtime + RUNTIME_HAS_PAGES_OFF], 1
    mov     qword [rel runtime + RUNTIME_IMPORTS_PTR_OFF], 0
    mov     qword [rel runtime + RUNTIME_IMPORTS_LEN_OFF], 0

    lea     rdi, [rel runtime]
    lea     rsi, [rel zig_wasm_start]
    mov     rdx, [rel zig_wasm_len]
    call    er_fn_load
    test    rdx, rdx
    jnz     fail_error

    mov     qword [rel fail_stage], 4
    lea     rdi, [rel bench_export_name]
    mov     esi, BENCH_EXPORT_NAME_LEN
    call    _er_wasm_resolve_export_function_index
    test    rdx, rdx
    jnz     fail
    mov     [rel func_idx], rax

    mov     dword [rel args], 12345
    mov     qword [rel fail_stage], 5
    mov     edi, 12345
    call    er_bench
    mov     r12d, eax

    mov     rdi, [rel func_idx]
    mov     qword [rel fail_stage], 6
    lea     rsi, [rel args]
    mov     edx, 1
    call    er_fn_exec
    test    rdx, rdx
    jnz     fail
    cmp     eax, r12d
    jne     fail

    mov     rdi, [rel func_idx]
    mov     qword [rel fail_stage], 7
    lea     rsi, [rel args]
    mov     edx, 1
    call    er_wasm_jit_exec
    test    rdx, rdx
    jnz     fail_error
    cmp     eax, r12d
    jne     fail

    call    bench_native
    lea     rdi, [rel str_native]
    call    puts
    mov     rdi, rax
    call    puthex64
    call    newline

    call    bench_interp
    lea     rdi, [rel str_interp]
    call    puts
    mov     rdi, rax
    call    puthex64
    call    newline

    call    bench_jit
    lea     rdi, [rel str_jit]
    call    puts
    mov     rdi, rax
    call    puthex64
    call    newline

    lea     rdi, [rel str_done]
    call    puts
    xor     edi, edi
    mov     eax, LINUX_SYS_EXIT
    syscall

fail:
    lea     rdi, [rel str_fail]
    call    puts
    mov     edi, [rel fail_stage]
    test    edi, edi
    jnz     .exit
    mov     edi, 1
.exit:
    mov     eax, LINUX_SYS_EXIT
    syscall

fail_error:
    mov     r12, rdx
    lea     rdi, [rel str_fail]
    call    puts
    mov     edi, r12d
    mov     eax, LINUX_SYS_EXIT
    syscall

make_jit_cache_executable:
    lea     rdi, [rel jit_code_cache]
    and     rdi, LINUX_PAGE_MASK
    lea     rsi, [rel jit_code_cache + JIT_CACHE_SIZE + LINUX_PAGE_SIZE - 1]
    and     rsi, LINUX_PAGE_MASK
    sub     rsi, rdi
    mov     edx, LINUX_PROT_READ | LINUX_PROT_WRITE | LINUX_PROT_EXEC
    mov     eax, LINUX_SYS_MPROTECT
    syscall
    test    rax, rax
    jnz     fail
    ret

bench_native:
    rdtscp
    shl     rdx, 32
    or      rax, rdx
    mov     r14, rax
    mov     r13d, ITERS_NATIVE
.loop:
    mov     edi, 12345
    call    er_bench
    dec     r13d
    jnz     .loop
    rdtscp
    shl     rdx, 32
    or      rax, rdx
    sub     rax, r14
    xor     edx, edx
    mov     r13d, ITERS_NATIVE
    div     r13
    ret

bench_interp:
    rdtscp
    shl     rdx, 32
    or      rax, rdx
    mov     r14, rax
    mov     r13d, ITERS_INTERP
.loop:
    mov     rdi, [rel func_idx]
    lea     rsi, [rel args]
    mov     edx, 1
    call    er_fn_exec
    test    rdx, rdx
    jnz     fail
    dec     r13d
    jnz     .loop
    rdtscp
    shl     rdx, 32
    or      rax, rdx
    sub     rax, r14
    xor     edx, edx
    mov     r13d, ITERS_INTERP
    div     r13
    ret

bench_jit:
    rdtscp
    shl     rdx, 32
    or      rax, rdx
    mov     r14, rax
    mov     r13d, ITERS_JIT
.loop:
    mov     rdi, [rel func_idx]
    lea     rsi, [rel args]
    mov     edx, 1
    call    er_wasm_jit_exec
    test    rdx, rdx
    jnz     fail
    dec     r13d
    jnz     .loop
    rdtscp
    shl     rdx, 32
    or      rax, rdx
    sub     rax, r14
    xor     edx, edx
    mov     r13d, ITERS_JIT
    div     r13
    ret

putchar:
    sub     rsp, 16
    mov     [rsp], dil
    mov     eax, 1
    mov     edi, 1
    lea     rsi, [rsp]
    mov     edx, 1
    syscall
    add     rsp, 16
    ret

puts:
    push    rbx
    mov     rbx, rdi
    xor     rsi, rsi
.count:
    cmp     byte [rbx + rsi], 0
    je      .write
    inc     rsi
    jmp     .count
.write:
    mov     rdi, 1
    mov     rdx, rsi
    mov     rsi, rbx
    mov     eax, 1
    syscall
    pop     rbx
    ret

newline:
    mov     edi, 10
    call    putchar
    ret

puthex64:
    push    rbx
    push    r12
    mov     r12, rdi
    sub     rsp, 24
    lea     rbx, [rsp + 21]
    mov     byte [rbx], 0
    mov     rdi, r12
    mov     ecx, 16
.hex_loop:
    dec     rbx
    mov     eax, edi
    and     eax, 0x0f
    cmp     al, 10
    jb      .hex_digit
    add     al, 'a' - 10 - '0'
.hex_digit:
    add     al, '0'
    mov     [rbx], al
    shr     rdi, 4
    dec     ecx
    jnz     .hex_loop
    dec     rbx
    mov     byte [rbx], 'x'
    dec     rbx
    mov     byte [rbx], '0'
    mov     rdi, rbx
    call    puts
    add     rsp, 24
    pop     r12
    pop     rbx
    ret
