; ==================================================================
; wasm_jit.asm — JIT orchestrator: compilation driver + trampoline
;
; Public API:
;   er_wasm_jit_init()       — one-time init (populates jit_globals,
;                               fills template dispatch table)
;   er_wasm_jit_compile(rdi=func_idx)  — compile function to native code
;                               returns rax=code_ptr, rdx=0 on success
;   er_wasm_jit_exec(rdi=func_idx, rsi=args, rdx=args_count)
;                              — execute compiled function
;                               returns rax=result, rdx=error
; =================================================================+

; ==================================================================
; BSS — JIT state
; =================================================================+
SECTION .bss
align 16

; JitGlobals struct — pointed to by r15 at JIT runtime
jit_globals:
    istruc JitGlobals
        at JitGlobals.locals,           resq 1
        at JitGlobals.mem_ptr,          resq 1
        at JitGlobals.mem_len,          resq 1
        at JitGlobals.mem_limit,        resq 1
        at JitGlobals.types_buf,        resq 1
        at JitGlobals.code_buf,         resq 1
        at JitGlobals.imports_buf,      resq 1
        at JitGlobals.import_count,     resq 1
        at JitGlobals.globals_buf,      resq 1
        at JitGlobals.global_count,     resq 1
        at JitGlobals.result_values,    resq 1
        at JitGlobals.result_count_ptr, resq 1
        at JitGlobals.table_entries,    resq 1
        at JitGlobals.table_min,        resq 1
        at JitGlobals.local_count_ptr,  resq 1
        at JitGlobals.functions_buf,    resq 1
        at JitGlobals.function_count,   resq 1
        at JitGlobals.mem_grow_hook,    resq 1
        at JitGlobals.mem_grow_ctx,     resq 1
        at JitGlobals.memory_pages,     resq 1
    iend

; Code cache — emitted x86_64 code lands here
jit_code_cache: resb JIT_CACHE_SIZE

; JIT table — maps function_index → compiled code pointer (0 = not compiled)
jit_table:      resq MAX_FUNCTIONS

; Compile-time state (one at a time, ~4KB)
jit_state:
    .code_ptr:       resq 1   ; current write position in code cache
    .cache_base:     resq 1   ; base of current function's cache slot
    .cache_end:      resq 1   ; end of current function's cache slot
    .func_idx:       resq 1   ; function being compiled
    .result_count:   resq 1   ; number of return values (0 or 1)
    .stack_depth:    resq 1   ; current WASM stack depth
    .max_stack:      resq 1   ; max WASM stack depth seen
    .reg_map:        resb 8   ; which WASM slot each reg holds (-1 = free)
    .slot_reg:       resb 8   ; which reg holds each WASM slot
    .label_depth:    resq 1   ; current label nesting depth
    .label_offsets:  resq 256 ; code address for each label
    .label_kinds:    resb 256 ; kind of each label
    .label_if_jz:    resq 256 ; for IF labels: jz displacement address to patch at else/end
    .fixup_count:    resq 1   ; number of pending fixups
    .fixup_label:    resq 256 ; label depth for each fixup
    .fixup_offset:   resq 256 ; code address where displacement field needs patching
    .return_emitted: resq 1   ; flag: epilogue already emitted inline

; Template dispatch table (256 entries, filled at init)
jit_template_table: resq 256

; Init flag
jit_initialized:    resb 1

; ==================================================================
; Init — one-time setup of JIT globals and template table
; =================================================================+
SECTION .text

er_wasm_jit_init:
    er_frame_push

    ; --- populate JitGlobals with runtime BSS addresses ---
    lea     rax, [rel exec_locals]
    mov     [rel jit_globals + JitGlobals.locals], rax

    lea     rax, [rel runtime_memory_ptr]
    mov     [rel jit_globals + JitGlobals.mem_ptr], rax

    mov     rax, [rel runtime_memory_len]
    mov     [rel jit_globals + JitGlobals.mem_len], rax

    mov     rax, [rel executor_memory_limit]
    mov     [rel jit_globals + JitGlobals.mem_limit], rax

    lea     rax, [rel types_buf]
    mov     [rel jit_globals + JitGlobals.types_buf], rax

    lea     rax, [rel code_buf]
    mov     [rel jit_globals + JitGlobals.code_buf], rax

    lea     rax, [rel imports_buf]
    mov     [rel jit_globals + JitGlobals.imports_buf], rax

    mov     rax, [rel import_count]
    mov     [rel jit_globals + JitGlobals.import_count], rax

    lea     rax, [rel globals_buf]
    mov     [rel jit_globals + JitGlobals.globals_buf], rax

    mov     rax, [rel global_count]
    mov     [rel jit_globals + JitGlobals.global_count], rax

    lea     rax, [rel exec_result_values]
    mov     [rel jit_globals + JitGlobals.result_values], rax

    lea     rax, [rel exec_result_count]
    mov     [rel jit_globals + JitGlobals.result_count_ptr], rax

    lea     rax, [rel table_entries]
    mov     [rel jit_globals + JitGlobals.table_entries], rax

    mov     rax, [rel table_min]
    mov     [rel jit_globals + JitGlobals.table_min], rax

    lea     rax, [rel exec_local_count]
    mov     [rel jit_globals + JitGlobals.local_count_ptr], rax

    lea     rax, [rel functions_buf]
    mov     [rel jit_globals + JitGlobals.functions_buf], rax

    mov     rax, [rel function_count]
    mov     [rel jit_globals + JitGlobals.function_count], rax

    mov     rax, [rel runtime_memory_grow_fn]
    mov     [rel jit_globals + JitGlobals.mem_grow_hook], rax

    mov     rax, [rel runtime_memory_grow_ctx]
    mov     [rel jit_globals + JitGlobals.mem_grow_ctx], rax

    mov     rax, [rel executor_memory_pages]
    mov     [rel jit_globals + JitGlobals.memory_pages], rax

    ; --- fill template dispatch table ---
    ; Default all entries to jit_template_fallback (compile refusal path).
    lea     rax, [rel jit_template_fallback]
    mov     ecx, 256
    lea     rdx, [rel jit_template_table]
.tmpl_fill:
    mov     [rdx + rcx * 8 - 8], rax
    dec     ecx
    jnz     .tmpl_fill

    %macro _jit_init_op 2
        lea     rax, [rel %2]
        mov     [rel jit_template_table + %1 * 8], rax
    %endm

    _jit_init_op 0x00, jit_template_unreachable
    _jit_init_op 0x01, jit_template_nop
    _jit_init_op 0x10, jit_template_call
    _jit_init_op 0x11, jit_template_call_indirect
    _jit_init_op 0x1A, jit_template_drop
    ; Parametric
    _jit_init_op 0x1B, jit_template_select
    _jit_init_op 0x1C, jit_template_select   ; select_typed = select (identical runtime behavior)
    _jit_init_op 0x20, jit_template_local_get
    _jit_init_op 0x21, jit_template_local_set
    _jit_init_op 0x22, jit_template_local_tee
    _jit_init_op 0x23, jit_template_global_get
    _jit_init_op 0x24, jit_template_global_set
    _jit_init_op 0x25, jit_template_table_get
    _jit_init_op 0x26, jit_template_table_set
    _jit_init_op 0x41, jit_template_i32_const
    _jit_init_op 0x42, jit_template_i64_const
    _jit_init_op 0x45, jit_template_i32_eqz
    _jit_init_op 0x46, jit_template_i32_eq
    _jit_init_op 0x47, jit_template_i32_ne
    _jit_init_op 0x48, jit_template_i32_lt_s
    _jit_init_op 0x49, jit_template_i32_lt_u
    _jit_init_op 0x4A, jit_template_i32_gt_s
    _jit_init_op 0x4B, jit_template_i32_gt_u
    _jit_init_op 0x4C, jit_template_i32_le_s
    _jit_init_op 0x4D, jit_template_i32_le_u
    _jit_init_op 0x4E, jit_template_i32_ge_s
    _jit_init_op 0x4F, jit_template_i32_ge_u
    _jit_init_op 0x67, jit_template_i32_clz
    _jit_init_op 0x68, jit_template_i32_ctz
    _jit_init_op 0x69, jit_template_i32_popcnt
    _jit_init_op 0x6A, jit_template_i32_add
    _jit_init_op 0x6B, jit_template_i32_sub
    _jit_init_op 0x6C, jit_template_i32_mul
    _jit_init_op 0x6D, jit_template_i32_div_s
    _jit_init_op 0x6E, jit_template_i32_div_u
    _jit_init_op 0x6F, jit_template_i32_rem_s
    _jit_init_op 0x70, jit_template_i32_rem_u
    _jit_init_op 0x71, jit_template_i32_and
    _jit_init_op 0x72, jit_template_i32_or
    _jit_init_op 0x73, jit_template_i32_xor
    _jit_init_op 0x74, jit_template_i32_shl
    _jit_init_op 0x75, jit_template_i32_shr_s
    _jit_init_op 0x76, jit_template_i32_shr_u
    _jit_init_op 0x77, jit_template_i32_rotl
    _jit_init_op 0x78, jit_template_i32_rotr
    _jit_init_op 0xA7, jit_template_i32_wrap_i64
    _jit_init_op 0xAC, jit_template_i64_extend_i32_s
    _jit_init_op 0xAD, jit_template_i64_extend_i32_u
    ; Sign extensions
    _jit_init_op 0xC0, jit_template_i32_extend8_s
    _jit_init_op 0xC1, jit_template_i32_extend16_s
    _jit_init_op 0xC2, jit_template_i64_extend8_s
    _jit_init_op 0xC3, jit_template_i64_extend16_s
    _jit_init_op 0xC4, jit_template_i64_extend32_s
    ; Memory ops
    _jit_init_op 0x28, jit_template_i32_load
    _jit_init_op 0x29, jit_template_i64_load
    ; Narrow loads
    _jit_init_op 0x2C, jit_template_i32_load8_s
    _jit_init_op 0x2D, jit_template_i32_load8_u
    _jit_init_op 0x2E, jit_template_i32_load16_s
    _jit_init_op 0x2F, jit_template_i32_load16_u
    _jit_init_op 0x30, jit_template_i64_load8_s
    _jit_init_op 0x31, jit_template_i32_load8_u   ; i64.load8_u = i32.load8_u
    _jit_init_op 0x32, jit_template_i64_load16_s
    _jit_init_op 0x33, jit_template_i32_load16_u   ; i64.load16_u = i32.load16_u
    _jit_init_op 0x34, jit_template_i64_load32_s
    _jit_init_op 0x35, jit_template_i32_load       ; i64.load32_u = i32.load
    _jit_init_op 0x36, jit_template_i32_store
    _jit_init_op 0x37, jit_template_i64_store
    ; Narrow stores
    _jit_init_op 0x3A, jit_template_i32_store8
    _jit_init_op 0x3B, jit_template_i32_store16
    _jit_init_op 0x3C, jit_template_i32_store8     ; i64.store8 = i32.store8
    _jit_init_op 0x3D, jit_template_i32_store16    ; i64.store16 = i32.store16
    _jit_init_op 0x3E, jit_template_i32_store      ; i64.store32 = i32.store
    ; Memory management
    _jit_init_op 0x3F, jit_template_memory_size
    _jit_init_op 0x40, jit_template_memory_grow
    ; i64 comparisons
    _jit_init_op 0x50, jit_template_i64_eqz
    _jit_init_op 0x51, jit_template_i64_eq
    _jit_init_op 0x52, jit_template_i64_ne
    _jit_init_op 0x53, jit_template_i64_lt_s
    _jit_init_op 0x54, jit_template_i64_lt_u
    _jit_init_op 0x55, jit_template_i64_gt_s
    _jit_init_op 0x56, jit_template_i64_gt_u
    _jit_init_op 0x57, jit_template_i64_le_s
    _jit_init_op 0x58, jit_template_i64_le_u
    _jit_init_op 0x59, jit_template_i64_ge_s
    _jit_init_op 0x5A, jit_template_i64_ge_u
    ; i64 unary
    _jit_init_op 0x79, jit_template_i64_clz
    _jit_init_op 0x7A, jit_template_i64_ctz
    _jit_init_op 0x7B, jit_template_i64_popcnt
    ; i64 binary arithmetic
    _jit_init_op 0x7C, jit_template_i64_add
    _jit_init_op 0x7D, jit_template_i64_sub
    _jit_init_op 0x7E, jit_template_i64_mul
    _jit_init_op 0x7F, jit_template_i64_div_s
    _jit_init_op 0x80, jit_template_i64_div_u
    _jit_init_op 0x81, jit_template_i64_rem_s
    _jit_init_op 0x82, jit_template_i64_rem_u
    _jit_init_op 0x83, jit_template_i64_and
    _jit_init_op 0x84, jit_template_i64_or
    _jit_init_op 0x85, jit_template_i64_xor
    _jit_init_op 0x86, jit_template_i64_shl
    _jit_init_op 0x87, jit_template_i64_shr_s
    _jit_init_op 0x88, jit_template_i64_shr_u
    _jit_init_op 0x89, jit_template_i64_rotl
    _jit_init_op 0x8A, jit_template_i64_rotr
    ; Float comparisons (f32: 0x5B-0x60, f64: 0x61-0x66)
    _jit_init_op 0x5B, jit_template_f32_eq
    _jit_init_op 0x5C, jit_template_f32_ne
    _jit_init_op 0x5D, jit_template_f32_lt
    _jit_init_op 0x5E, jit_template_f32_gt
    _jit_init_op 0x5F, jit_template_f32_le
    _jit_init_op 0x60, jit_template_f32_ge
    _jit_init_op 0x61, jit_template_f64_eq
    _jit_init_op 0x62, jit_template_f64_ne
    _jit_init_op 0x63, jit_template_f64_lt
    _jit_init_op 0x64, jit_template_f64_gt
    _jit_init_op 0x65, jit_template_f64_le
    _jit_init_op 0x66, jit_template_f64_ge
    ; Float constants
    _jit_init_op 0x43, jit_template_f32_const
    _jit_init_op 0x44, jit_template_f64_const
    ; Float unary
    _jit_init_op 0x8B, jit_template_f32_abs
    _jit_init_op 0x8C, jit_template_f32_neg
    _jit_init_op 0x99, jit_template_f64_abs
    _jit_init_op 0x9A, jit_template_f64_neg
    _jit_init_op 0x91, jit_template_f32_sqrt
    _jit_init_op 0x9F, jit_template_f64_sqrt
    ; Float rounding (SSE4.1)
    _jit_init_op 0x8D, jit_template_f32_ceil
    _jit_init_op 0x8E, jit_template_f32_floor
    _jit_init_op 0x8F, jit_template_f32_trunc
    _jit_init_op 0x90, jit_template_f32_nearest
    _jit_init_op 0x9B, jit_template_f64_ceil
    _jit_init_op 0x9C, jit_template_f64_floor
    _jit_init_op 0x9D, jit_template_f64_trunc
    _jit_init_op 0x9E, jit_template_f64_nearest
    ; Float binary (f32: add/sub/mul/div)
    _jit_init_op 0x92, jit_template_f32_add
    _jit_init_op 0x93, jit_template_f32_sub
    _jit_init_op 0x94, jit_template_f32_mul
    _jit_init_op 0x95, jit_template_f32_div
    ; Float binary (f32/f64: min/max/copysign)
    _jit_init_op 0x96, jit_template_f32_min
    _jit_init_op 0x97, jit_template_f32_max
    _jit_init_op 0x98, jit_template_f32_copysign
    ; Float binary (f64: add/sub/mul/div)
    _jit_init_op 0xA0, jit_template_f64_add
    _jit_init_op 0xA1, jit_template_f64_sub
    _jit_init_op 0xA2, jit_template_f64_mul
    _jit_init_op 0xA3, jit_template_f64_div
    _jit_init_op 0xA4, jit_template_f64_min
    _jit_init_op 0xA5, jit_template_f64_max
    _jit_init_op 0xA6, jit_template_f64_copysign
    ; Float load/store — reuse integer templates (same semantics)
    _jit_init_op 0x2A, jit_template_i32_load   ; f32.load
    _jit_init_op 0x2B, jit_template_i64_load   ; f64.load
    _jit_init_op 0x38, jit_template_i32_store  ; f32.store
    _jit_init_op 0x39, jit_template_i64_store  ; f64.store
    ; Float conversions
    _jit_init_op 0xB2, jit_template_f32_convert_i32_s
    _jit_init_op 0xB3, jit_template_f32_convert_i32_u
    _jit_init_op 0xB4, jit_template_f32_convert_i64_s
    _jit_init_op 0xB5, jit_template_f32_convert_i64_u
    _jit_init_op 0xB6, jit_template_f32_demote_f64
    _jit_init_op 0xB7, jit_template_f64_convert_i32_s
    _jit_init_op 0xB8, jit_template_f64_convert_i32_u
    _jit_init_op 0xB9, jit_template_f64_convert_i64_s
    _jit_init_op 0xBA, jit_template_f64_convert_i64_u
    _jit_init_op 0xBB, jit_template_f64_promote_f32
    ; Reinterpret ops — no-op on x86_64 (bits are the same)
    _jit_init_op 0xBC, jit_template_i32_reinterpret_f32
    _jit_init_op 0xBD, jit_template_i64_reinterpret_f64
    _jit_init_op 0xBE, jit_template_f32_reinterpret_i32
    _jit_init_op 0xBF, jit_template_f64_reinterpret_i64
    ; Reference types
    _jit_init_op 0xD0, jit_template_ref_null
    _jit_init_op 0xD1, jit_template_ref_is_null
    _jit_init_op 0xD2, jit_template_ref_func

    mov     byte [rel jit_initialized], 1
    er_ok
    pop     rbp
    ret

; ==================================================================
; Compile a WASM function to native x86_64 code
; rdi = function_index (absolute)
; Returns: rax = code_ptr (0 = not compiled), rdx = error
; =================================================================+
er_wasm_jit_compile:
    er_frame_push
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi            ; function_index

    ; Ensure init
    cmp     byte [rel jit_initialized], 0
    jne     .init_done
    call    er_wasm_jit_init
.init_done:

    ; --- allocate code cache slot ---
    ; Simple: scan for first unused 64KB slot, or use func_idx mod MAX_COMPILED
    ; For Phase 1: use slot = func_idx & 3 (max 4 compiled functions)
    mov     rax, r12
    and     eax, 3
    mov     ecx, JIT_SLOT_SIZE
    mul     ecx
    lea     r15, [rel jit_code_cache]
    add     r15, rax             ; r15 = cache_base
    lea     r14, [r15 + JIT_SLOT_SIZE]  ; r14 = cache_end

    ; Set up jit_state
    mov     [rel jit_state.code_ptr], r15
    mov     [rel jit_state.cache_base], r15
    mov     [rel jit_state.cache_end], r14
    mov     [rel jit_state.func_idx], r12
    mov     qword [rel jit_state.stack_depth], 0
    mov     qword [rel jit_state.max_stack], 0
    mov     qword [rel jit_state.label_depth], 0
    mov     qword [rel jit_state.fixup_count], 0
    mov     qword [rel jit_state.return_emitted], 0

    ; --- emit function prologue ---
    ; push rbp; mov rbp, rsp
    mov     al, 0x55            ; push rbp
    call    jit_emit_byte
    mov     al, 0x48            ; REX.W
    call    jit_emit_byte
    mov     al, 0x89            ; mov rbp, rsp
    call    jit_emit_byte
    mov     al, 0xE5            ; ModRM: mod=11, reg=4(rbp), rm=4(rsp)
    call    jit_emit_modrm

    ; --- get function type to know result count ---
    mov     rdi, r12
    call    er_wasm_type_index_for_function
    test    rdx, rdx
    jnz     .type_error
    mov     r10, rax
    imul    r10, FUNC_TYPE_SIZE
    mov     rax, [rel types_buf + r10 + FUNC_TYPE_RESULT_COUNT_OFF]
    mov     [rel jit_state.result_count], rax

    ; --- get decoded ops range ---
    mov     r10, r12
    imul    r10, CODE_SIZE
    mov     r13, [rel code_buf + r10 + 24]  ; decoded_start
    mov     rax, [rel code_buf + r10 + 32]  ; decoded_count
    add     rax, r13
    mov     r14, rax                         ; end index (exclusive)

    ; --- compile loop: iterate decoded ops ---
.compile_loop:
    cmp     r13, r14
    jae     .compile_done

    ; Calculate DecodedOp address
    mov     rdi, r13
    imul    rdi, DECODED_OP_SIZE
    lea     rdi, [rel decoded_ops + rdi]

    movzx   ebx, byte [rdi + 8]            ; opcode_byte

    ; --- Control flow ops handled directly by orchestrator ---
    cmp     bl, 0x02
    je      .handle_block
    cmp     bl, 0x03
    je      .handle_loop
    cmp     bl, 0x04
    je      .handle_if
    cmp     bl, 0x05
    je      .handle_else
    cmp     bl, 0x0B
    je      .handle_end
    cmp     bl, 0x0C
    je      .handle_br
    cmp     bl, 0x0D
    je      .handle_br_if
    cmp     bl, 0x0F
    je      .handle_return

    ; --- All other ops: use template table ---
    lea     rax, [rel jit_template_table]
    mov     rax, [rax + rbx * 8]
    lea     rcx, [rel jit_template_fallback]
    cmp     rax, rcx
    je      .fallback

    push    r13
    push    r14
    call    rax
    pop     r14
    pop     r13

    test    rdx, rdx
    jnz     .compile_error

    inc     r13
    jmp     .compile_loop

; ------------------------------------------------------------------
; Control flow handlers
; ------------------------------------------------------------------
.handle_block:
    ; Push label: BLOCK kind — no code emitted
    mov     rdx, [rel jit_state.label_depth]
    mov     byte [rel jit_state.label_kinds + rdx], JIT_LABEL_BLOCK
    mov     qword [rel jit_state.label_offsets + rdx * 8], 0
    mov     qword [rel jit_state.label_if_jz + rdx * 8], 0
    inc     qword [rel jit_state.label_depth]
    inc     r13
    jmp     .compile_loop

.handle_loop:
    ; Push label: LOOP kind — record current code_ptr as loop start
    mov     rdx, [rel jit_state.label_depth]
    mov     byte [rel jit_state.label_kinds + rdx], JIT_LABEL_LOOP
    mov     rax, [rel jit_state.code_ptr]
    mov     [rel jit_state.label_offsets + rdx * 8], rax
    mov     qword [rel jit_state.label_if_jz + rdx * 8], 0
    inc     qword [rel jit_state.label_depth]
    inc     r13
    jmp     .compile_loop

.handle_if:
    ; Pop condition, emit test + jz with placeholder
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_test32
    mov     al, 0x0F
    call    jit_emit_byte
    mov     al, 0x84          ; jz rel32
    call    jit_emit_byte
    mov     eax, 0
    call    jit_emit_dword    ; placeholder displacement
    ; Record jz displacement address
    mov     rdx, [rel jit_state.label_depth]
    mov     rax, [rel jit_state.code_ptr]
    sub     rax, 4
    mov     [rel jit_state.label_if_jz + rdx * 8], rax
    ; Push label: IF kind
    mov     byte [rel jit_state.label_kinds + rdx], JIT_LABEL_IF
    mov     qword [rel jit_state.label_offsets + rdx * 8], 0
    inc     qword [rel jit_state.label_depth]
    inc     r13
    jmp     .compile_loop

.handle_else:
    ; At else: patch the if's jz to jump here, then emit jmp to end
    mov     rdx, [rel jit_state.label_depth]
    dec     rdx               ; depth of the if label
    ; Patch jz if non-zero
    mov     rcx, [rel jit_state.label_if_jz + rdx * 8]
    test    rcx, rcx
    jz      .else_skip_jz
    mov     rax, [rel jit_state.code_ptr]
    sub     rax, rcx
    sub     rax, 4
    mov     [rcx], eax
    mov     qword [rel jit_state.label_if_jz + rdx * 8], 0
.else_skip_jz:
    ; Emit jmp to end (placeholder), record as normal fixup
    mov     al, 0xE9
    call    jit_emit_byte
    mov     eax, 0
    call    jit_emit_dword
    ; Record fixup at this label depth
    mov     rdi, [rel jit_state.fixup_count]
    mov     rax, [rel jit_state.code_ptr]
    sub     rax, 4
    mov     [rel jit_state.fixup_label + rdi * 8], rdx
    mov     [rel jit_state.fixup_offset + rdi * 8], rax
    inc     qword [rel jit_state.fixup_count]
    inc     r13
    jmp     .compile_loop

.handle_end:
    mov     rdx, [rel jit_state.label_depth]
    test    rdx, rdx
    jz      .end_done        ; function-level end — no label handling needed
    dec     qword [rel jit_state.label_depth]
    dec     rdx
    ; Check label kind
    cmp     byte [rel jit_state.label_kinds + rdx], JIT_LABEL_LOOP
    je      .end_loop
    ; For BLOCK/IF: patch all normal fixups for this depth
    call    jit_patch_fixups_for_label
    ; For IF (no else): patch the if jz if still pending
    cmp     byte [rel jit_state.label_kinds + rdx], JIT_LABEL_IF
    jne     .end_done
    mov     rcx, [rel jit_state.label_if_jz + rdx * 8]
    test    rcx, rcx
    jz      .end_done
    mov     rax, [rel jit_state.code_ptr]
    sub     rax, rcx
    sub     rax, 4
    mov     [rcx], eax
    mov     qword [rel jit_state.label_if_jz + rdx * 8], 0
    jmp     .end_done
.end_loop:
    ; For LOOP: emit jmp back to loop start
    mov     rax, [rel jit_state.code_ptr]
    mov     rcx, [rel jit_state.label_offsets + rdx * 8]
    sub     rcx, rax
    sub     rcx, 5
    mov     eax, ecx
    call    jit_emit_jmp_rel32
.end_done:
    inc     r13
    jmp     .compile_loop

.handle_br:
    ; imm0 = WASM label depth (0 = innermost)
    mov     eax, [rdi + 12]
    mov     rdx, [rel jit_state.label_depth]
    dec     rdx
    sub     rdx, rax            ; target label index
    cmp     byte [rel jit_state.label_kinds + rdx], JIT_LABEL_LOOP
    je      .br_loop
    ; Forward branch (BLOCK/IF): emit jmp with placeholder, record fixup
    push    rdx
    mov     al, 0xE9
    call    jit_emit_byte
    mov     eax, 0
    call    jit_emit_dword
    pop     rdx
    ; Record fixup at target label depth
    mov     rdi, [rel jit_state.fixup_count]
    mov     rax, [rel jit_state.code_ptr]
    sub     rax, 4
    mov     [rel jit_state.fixup_label + rdi * 8], rdx
    mov     [rel jit_state.fixup_offset + rdi * 8], rax
    inc     qword [rel jit_state.fixup_count]
    jmp     .br_done
.br_loop:
    ; Backward branch (LOOP): compute displacement directly
    push    rdx
    mov     al, 0xE9
    call    jit_emit_byte
    pop     rdx
    mov     rax, [rel jit_state.code_ptr]
    mov     rcx, [rel jit_state.label_offsets + rdx * 8]
    sub     rcx, rax
    sub     rcx, 4
    mov     eax, ecx
    call    jit_emit_dword
.br_done:
    inc     r13
    jmp     .compile_loop

.handle_br_if:
    ; Pop condition, test, conditional jmp
    xor     ecx, ecx
    call    jit_emit_pop_reg
    call    jit_emit_test32
    ; Get target label
    mov     eax, [rdi + 12]
    mov     rdx, [rel jit_state.label_depth]
    dec     rdx
    sub     rdx, rax
    cmp     byte [rel jit_state.label_kinds + rdx], JIT_LABEL_LOOP
    je      .br_if_loop
    ; Forward: jne with placeholder, record fixup
    push    rdx
    mov     al, 0x0F
    call    jit_emit_byte
    mov     al, 0x85          ; jne rel32
    call    jit_emit_byte
    mov     eax, 0
    call    jit_emit_dword
    pop     rdx
    ; Record fixup at target label depth
    mov     rdi, [rel jit_state.fixup_count]
    mov     rax, [rel jit_state.code_ptr]
    sub     rax, 4
    mov     [rel jit_state.fixup_label + rdi * 8], rdx
    mov     [rel jit_state.fixup_offset + rdi * 8], rax
    inc     qword [rel jit_state.fixup_count]
    jmp     .br_if_done
.br_if_loop:
    ; Backward: jne with computed displacement
    push    rdx
    mov     al, 0x0F
    call    jit_emit_byte
    mov     al, 0x85
    call    jit_emit_byte
    pop     rdx
    mov     rax, [rel jit_state.code_ptr]
    mov     rcx, [rel jit_state.label_offsets + rdx * 8]
    sub     rcx, rax
    sub     rcx, 4
    mov     eax, ecx
    call    jit_emit_dword
.br_if_done:
    inc     r13
    jmp     .compile_loop

.handle_return:
    ; Emit epilogue inline: pop result, pop rbp, ret, then ud2
    mov     rax, [rel jit_state.result_count]
    cmp     rax, 1
    jne     .ret_zero
    xor     ecx, ecx
    call    jit_emit_pop_reg
    jmp     .ret_common
.ret_zero:
    call    jit_emit_xor_eax_eax
.ret_common:
    mov     al, 0x5D
    call    jit_emit_byte       ; pop rbp
    call    jit_emit_ret
    ; ud2 — unreachable after return
    mov     al, 0x0F
    call    jit_emit_byte
    mov     al, 0x0B
    call    jit_emit_byte
    mov     qword [rel jit_state.return_emitted], 1
    inc     r13
    jmp     .compile_loop

.compile_done:
    ; --- emit function epilogue ---
    mov     rax, [rel jit_state.result_count]
    cmp     rax, 1
    jne     .epi_zero

    ; 1 return value: pop rax before cleanup
    xor     ecx, ecx            ; rax
    call    jit_emit_pop_reg
    jmp     .epi_common

.epi_zero:
    ; 0 return values: xor eax, eax
    call    jit_emit_xor_eax_eax

.epi_common:
    ; pop rbp
    mov     al, 0x5D
    call    jit_emit_byte
    ; ret
    call    jit_emit_ret

    ; --- store code pointer in jit_table ---
    mov     rax, [rel jit_state.cache_base]
    mov     r10, r12
    mov     [rel jit_table + r10 * 8], rax

    ; Return success
    mov     rax, [rel jit_state.cache_base]
    er_ok
    jmp     .out

.fallback:
    ; Opcode not JIT-supported — don't compile
    xor     eax, eax            ; code_ptr = 0
    er_err  ERROR_NOT_IMPLEMENTED
    jmp     .out

.type_error:
    xor     eax, eax
    ; rdx already has error
    jmp     .out

.compile_error:
    xor     eax, eax
    ; rdx already has error
    jmp     .out

.out:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    ret

; ==================================================================
; Execute a JIT-compiled WASM function
; rdi = function_index (absolute)
; rsi = args pointer
; rdx = args count
; Returns: rax = result value, rdx = error code
; =================================================================+
er_wasm_jit_exec:
    er_frame_push
    push    r15
    push    rbx
    push    r12
    push    r13
    push    r14

    mov     r12, rdi            ; function_index
    mov     r13, rsi            ; args ptr
    mov     r14, rdx            ; args count

    ; Ensure init
    cmp     byte [rel jit_initialized], 0
    jne     .exec_comp_check
    call    er_wasm_jit_init
.exec_comp_check:

    ; Check if compiled
    mov     rax, [rel jit_table + r12 * 8]
    test    rax, rax
    jnz     .exec_compiled

    ; Not compiled — try to compile
    mov     rdi, r12
    call    er_wasm_jit_compile
    test    rdx, rdx
    jnz     .exec_error         ; compilation failed — call interpreter instead

.exec_compiled:
    mov     rbx, rax            ; code_ptr

    ; Save current frame if we have locals
    cmp     qword [rel exec_local_count], 0
    je      .exec_no_save
    call    exec_save_frame_state
    jc      .exec_error
.exec_no_save:

    ; Set up locals from args (same as interpreter)
    ; Get function type for param_count
    mov     rdi, r12
    call    er_wasm_type_index_for_function
    test    rdx, rdx
    jnz     .exec_error

    mov     r10, rax
    imul    r10, FUNC_TYPE_SIZE
    mov     rax, [rel types_buf + r10 + FUNC_TYPE_PARAM_COUNT_OFF]
    mov     rcx, rax            ; param_count
    mov     rax, [rel types_buf + r10 + FUNC_TYPE_RESULT_COUNT_OFF]
    mov     [rel exec_result_count], rax

    ; Get local_count from code struct
    mov     r10, r12
    imul    r10, CODE_SIZE
    mov     rax, [rel code_buf + r10 + 16]  ; local_count
    mov     rdx, rax            ; code local_count

    ; Total locals = param_count + code local_count
    mov     rax, rcx
    add     rax, rdx
    mov     [rel exec_local_count], rax
    cmp     rax, MAX_LOCALS
    ja      .unsupported_error

    ; Initialize locals from args
    xor     r15d, r15d
.exec_init_locals:
    cmp     r15, rcx            ; param_count
    jae     .exec_init_zero
    mov     rax, [r13 + r15 * 8]
    mov     [rel exec_locals + r15 * 8], rax
    inc     r15
    jmp     .exec_init_locals
.exec_init_zero:
    cmp     r15, [rel exec_local_count]
    jae     .exec_init_done
    mov     qword [rel exec_locals + r15 * 8], 0
    inc     r15
    jmp     .exec_init_zero
.exec_init_done:

    ; Clear value stack and control stack
    mov     qword [rel exec_stack_len], 0
    mov     qword [rel exec_control_len], 0
    mov     qword [rel exec_reader_offset], 0

    ; Set r15 to jit_globals for JIT'd code
    lea     r15, [rel jit_globals]

    ; Call compiled code
    call    rbx

    ; Result is in rax, rdx is error
    mov     r15, rax             ; save return value
    mov     r14, rdx             ; save error code

    ; Restore previous frame
    call    exec_restore_frame_state

    mov     rax, r15
    mov     rdx, r14
    jmp     .exec_done

.exec_error:
    ; rdx already set
    jmp     .exec_done

.unsupported_error:
    er_err  ERROR_UNSUPPORTED

.exec_done:
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     r15
    pop     rbp
    ret

; ==================================================================
; Helper: patch all normal fixups for a given label depth
; rdx = label depth to patch
; Patches displacement and removes fixups from the list.
; =================================================================+
er_fn jit_patch_fixups_for_label
    mov     rcx, [rel jit_state.fixup_count]
    test    rcx, rcx
    jz      .pff_done
.pff_loop:
    dec     rcx
    cmp     [rel jit_state.fixup_label + rcx * 8], rdx
    jne     .pff_next
    ; Patch this fixup: displacement = code_ptr - (fixup_offset + 4)
    mov     rax, [rel jit_state.code_ptr]
    mov     rdi, [rel jit_state.fixup_offset + rcx * 8]
    sub     rax, rdi
    sub     rax, 4
    mov     [rdi], eax
    ; Remove fixup by swapping with last entry
    mov     rsi, [rel jit_state.fixup_count]
    dec     rsi
    mov     rdi, [rel jit_state.fixup_label + rsi * 8]
    mov     [rel jit_state.fixup_label + rcx * 8], rdi
    mov     rdi, [rel jit_state.fixup_offset + rsi * 8]
    mov     [rel jit_state.fixup_offset + rcx * 8], rdi
    dec     qword [rel jit_state.fixup_count]
.pff_next:
    test    rcx, rcx
    jnz     .pff_loop
.pff_done:
    ret
