; EdgeRun WASM JIT cycle benchmark — RDTSC
; Measures cycles per call for:
;   1. Native x86_64 reference function
;   2. JIT-compiled WASM function (direct call)
;   3. JIT-compiled WASM function (via er_fn_exec trampoline)
;
; Build: yasm -f elf64 -I kernel -o bench_wasm_jit.o bench_wasm_jit.asm
; Link:  ld -T kernel/test/test_jit.ld -nostdlib -static -o bench_wasm_jit \
;          bench_wasm_jit.o .build/kernel/runtime.o
; Run:   ./bench_wasm_jit

%include "x86_64/wasm/wasm_interpreter.asm"

ITERS_NATIVE  equ 10000000
ITERS_JIT     equ 5000000
ITERS_TRAMP   equ 100000

SECTION .data
align 16

; Dummy linear memory
dummy_mem: times 256 db 0

; WASM bytecode for func 0: block i32.const 42 end → result = 42
body0:        db 0x02, 0x7F, 0x41, 0x2A, 0x0B
BODY0_LEN     equ 5

SECTION .bss
; decoder scratch
dec_scratch: resq 1

SECTION .text
global _start
_start:

    ; ── common runtime setup ──
    lea     rax, [rel dummy_mem]
    mov     [rel runtime_memory_ptr], rax
    mov     qword [rel runtime_memory_len], 256
    mov     qword [rel executor_memory_limit], 256

    mov     qword [rel import_count], 0
    mov     qword [rel function_count], 1

    ; Type 0: 0 params, 1 result
    mov     qword [rel types_buf + FUNC_TYPE_PARAM_COUNT_OFF], 0
    mov     qword [rel types_buf + FUNC_TYPE_RESULT_COUNT_OFF], 1

    ; Functions: func 0 → type 0, code 0
    mov     qword [rel functions_buf], 0
    mov     qword [rel functions_buf + 8], 0

    ; Code 0: body0, 5 bytes, 0 locals, decoded range [0,3)
    lea     rax, [rel body0]
    mov     [rel code_buf], rax
    mov     qword [rel code_buf + 8], BODY0_LEN
    mov     qword [rel code_buf + 16], 0
    mov     qword [rel code_buf + 24], 0
    mov     qword [rel code_buf + 32], 3
    ; code_buf + 40 to +63 unused (CODE_SIZE=64)

    ; Decoded ops: 3 entries, each 32 bytes
    ; Slot 0: block(0x02), imm0=0x7F
    mov     dword [rel decoded_ops + 0],  0
    mov     dword [rel decoded_ops + 4],  2
    mov     byte  [rel decoded_ops + 8],  0x02
    mov     dword [rel decoded_ops + 12], 0x7F
    ; Slot 1: i32.const(0x41), imm0=42
    mov     dword [rel decoded_ops + 32], 2
    mov     dword [rel decoded_ops + 36], 4
    mov     byte  [rel decoded_ops + 40], 0x41
    mov     dword [rel decoded_ops + 44], 42
    ; Slot 2: end(0x0B)
    mov     dword [rel decoded_ops + 64], 4
    mov     dword [rel decoded_ops + 68], 5
    mov     byte  [rel decoded_ops + 72], 0x0B

    mov     qword [rel decoded_op_count], 3

    ; ── init JIT ──
    call    er_wasm_jit_init

    ; ── compile func 0 ──
    xor     edi, edi
    call    er_wasm_jit_compile
    test    rdx, rdx
    jnz     .fail

    mov     r12, [rel jit_table]          ; JIT code pointer
    lea     r13, [rel jit_globals]        ; r15 anchor

    ; ── sanity: JIT result must be 42 ──
    lea     r15, [rel jit_globals]
    call    r12
    cmp     rax, 42
    jne     .fail

    ; ══════════════════════════════════════════════════════════════
    ; 1. Native reference
    ; ══════════════════════════════════════════════════════════════
    ; warm up
    call    .native_ref

    rdtscp
    shl     rdx, 32
    or      rax, rdx
    mov     r14, rax                       ; start

    mov     r13d, ITERS_NATIVE
.loop_native:
    call    .native_ref
    dec     r13d
    jnz     .loop_native

    rdtscp
    shl     rdx, 32
    or      rax, rdx
    sub     rax, r14                       ; total
    xor     edx, edx
    mov     r13d, ITERS_NATIVE
    div     r13                            ; cycles/call

    mov     rbx, rax                       ; save

    lea     rdi, [rel str_native]
    call    puts
    mov     rdi, rbx
    call    puthex64
    call    newline

    ; ══════════════════════════════════════════════════════════════
    ; 2. JIT compiled (direct native call)
    ; ══════════════════════════════════════════════════════════════
    ; warm up
    lea     r15, [rel jit_globals]
    call    r12

    rdtscp
    shl     rdx, 32
    or      rax, rdx
    mov     r14, rax

    mov     r13d, ITERS_JIT
.loop_jit:
    lea     r15, [rel jit_globals]
    call    r12
    dec     r13d
    jnz     .loop_jit

    rdtscp
    shl     rdx, 32
    or      rax, rdx
    sub     rax, r14
    xor     edx, edx
    mov     r13d, ITERS_JIT
    div     r13

    mov     rbx, rax

    lea     rdi, [rel str_jit]
    call    puts
    mov     rdi, rbx
    call    puthex64
    call    newline

    ; ══════════════════════════════════════════════════════════════
    ; 3. JIT via er_fn_exec trampoline
    ; ══════════════════════════════════════════════════════════════
    ; warm up
    xor     edi, edi
    xor     esi, esi
    xor     edx, edx
    call    er_fn_exec

    rdtscp
    shl     rdx, 32
    or      rax, rdx
    mov     r14, rax

    mov     r13d, ITERS_TRAMP
.loop_tramp:
    xor     edi, edi
    xor     esi, esi
    xor     edx, edx
    call    er_fn_exec
    dec     r13d
    jnz     .loop_tramp

    rdtscp
    shl     rdx, 32
    or      rax, rdx
    sub     rax, r14
    xor     edx, edx
    mov     r13d, ITERS_TRAMP
    div     r13

    mov     rbx, rax

    lea     rdi, [rel str_tramp]
    call    puts
    mov     rdi, rbx
    call    puthex64
    call    newline

    ; ── done ──
    lea     rdi, [rel str_done]
    call    puts
    xor     edi, edi
    mov     eax, 60
    syscall

.fail:
    lea     rdi, [rel str_fail]
    call    puts
    mov     edi, 1
    mov     eax, 60
    syscall

; ── native reference: same body as JIT produces ──
.native_ref:
    push    rbp
    mov     rbp, rsp
    push    42
    pop     rax
    pop     rbp
    ret

; ══════════════════════════════════════════════════════════════
; I/O helpers  (Linux syscall based)
; ══════════════════════════════════════════════════════════════

; putchar(rdi=char)
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

; puts(rdi=string)
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

; newline
newline:
    mov     edi, 0x0A
    call    putchar
    ret

; puthex64(rdi=value) — prints "0x" + 16 hex digits
puthex64:
    push    rbx
    push    r12
    mov     r12, rdi                 ; save value
    sub     rsp, 24                  ; buf[0..23]

    ; Build "0xXXXXXXXXXXXXXXXX\0" at buf+2
    lea     rbx, [rsp + 21]          ; end of hex digit area
    mov     byte [rbx], 0            ; null terminator

    mov     rdi, r12
    mov     ecx, 16
.hex_loop:
    dec     rbx
    mov     eax, edi
    and     eax, 0xF
    cmp     al, 10
    jb      .hex_digit
    add     al, 'a' - 10 - '0'
.hex_digit:
    add     al, '0'
    mov     [rbx], al
    shr     rdi, 4
    dec     ecx
    jnz     .hex_loop

    ; rbx now points to first hex digit; prepend "0x"
    dec     rbx
    mov     byte [rbx], 'x'
    dec     rbx
    mov     byte [rbx], '0'

    ; Print "0x" + 16 hex digits
    mov     rdi, rbx
    call    puts

    add     rsp, 24
    pop     r12
    pop     rbx
    ret

SECTION .rodata
str_native: db "native: ", 0
str_jit:    db "jit:    ", 0
str_tramp:  db "tramp:  ", 0
str_done:   db "done", 10, 0
str_fail:   db "FAIL", 10, 0
