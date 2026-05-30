er_fn er_fn_pop
    er_frame_push

    mov     rax, [frame_stack_len]
    test    rax, rax
    jz      .underflow

    dec     rax
    mov     [frame_stack_len], rax

    ; Load value data (16 bytes per entry)
    shl     rax, 4
    mov     rax, [frame_stack + rax]      ; value data
    pop     rbp
    ret

.underflow:
    er_err  ERROR_STACK_UNDERFLOW
    mov     rax, -1
    pop     rbp
    ret

; ==================================================================
; Push value to frame stack
; rdi = value data
; =================================================================+
er_fn er_fn_push
    er_frame_push

    mov     rax, [frame_stack_len]
    cmp     rax, MAX_STACK
    jae     .overflow

    shl     rax, 4
    mov     [frame_stack + rax], rdi      ; value data

    inc     qword [frame_stack_len]
    xor     eax, eax
    pop     rbp
    ret

.overflow:
    er_err  ERROR_STACK_OVERFLOW
    mov     rax, -1
    pop     rbp
    ret

; ==================================================================
; Executor entry point
; er_fn_run(runtime_ptr=rdi, wasm_bytes_ptr=rsi, wasm_bytes_len=rdx, export_name_ptr=rcx, export_name_len=r8)
; =================================================================+
; ==================================================================
; Frame save/restore helpers
; =================================================================+

; Save current frame state onto exec_frame_save area
; Clobbers: rax, rcx
; Returns: carry set if save area overflow
er_fn exec_save_frame_state
    er_frame_push

    mov     rax, [exec_frame_save_ptr]
    mov     rcx, [exec_local_count]

    ; Check space: local_count*8 + stack_len*8 + control_len*16 + 40 <= FRAME_SAVE_SIZE - save_ptr
    push    rcx
    imul    rcx, 8
    add     rax, rcx
    pop     rcx
    mov     rcx, [exec_stack_len]
    shl     rcx, 3
    add     rax, rcx
    mov     rcx, [exec_control_len]
    imul    rcx, CONTROL_FRAME_SIZE
    add     rax, rcx
    add     rax, 40
    cmp     rax, FRAME_SAVE_SIZE
    ja      .overflow

    ; Push locals: exec_locals[0..local_count] onto save area
    mov     rcx, [exec_local_count]
    test    rcx, rcx
    jz      .save_stack
    mov     rax, exec_locals
    mov     rdx, [exec_frame_save_ptr]
.save_locals_loop:
    mov     r8, [rax]
    mov     [exec_frame_save + rdx], r8
    add     rax, 8
    add     rdx, 8
    dec     rcx
    jnz     .save_locals_loop
    mov     [exec_frame_save_ptr], rdx

.save_stack:
    ; Push stack entries
    mov     rcx, [exec_stack_len]
    test    rcx, rcx
    jz      .save_control
    mov     rax, exec_stack
    mov     rdx, [exec_frame_save_ptr]
.save_stack_loop:
    mov     r8, [rax]
    mov     [exec_frame_save + rdx], r8
    add     rax, 8
    add     rdx, 8
    dec     rcx
    jnz     .save_stack_loop
    mov     [exec_frame_save_ptr], rdx

.save_control:
    ; Push control frames
    mov     rcx, [exec_control_len]
    test    rcx, rcx
    jz      .save_meta
    mov     rax, exec_control
    mov     rdx, [exec_frame_save_ptr]
.save_control_loop:
    mov     r8, [rax]
    mov     r9, [rax + 8]
    mov     [exec_frame_save + rdx], r8
    mov     [exec_frame_save + rdx + 8], r9
    add     rax, CONTROL_FRAME_SIZE
    add     rdx, CONTROL_FRAME_SIZE
    dec     rcx
    jnz     .save_control_loop
    mov     [exec_frame_save_ptr], rdx

.save_meta:
    ; Push metadata: local_count, stack_len, control_len, dec_idx, dec_end
    mov     rdx, [exec_frame_save_ptr]
    mov     rax, [exec_local_count]
    mov     [exec_frame_save + rdx], rax
    mov     rax, [exec_stack_len]
    mov     [exec_frame_save + rdx + 8], rax
    mov     rax, [exec_control_len]
    mov     [exec_frame_save + rdx + 16], rax
    mov     rax, [exec_decoded_index]
    mov     [exec_frame_save + rdx + 24], rax
    mov     rax, [exec_decoded_end]
    mov     [exec_frame_save + rdx + 32], rax
    add     qword [exec_frame_save_ptr], 40
    clc
    pop     rbp
    ret

.overflow:
    er_err  ERROR_NO_MEMORY
    stc
    pop     rbp
    ret

; Restore frame state from exec_frame_save area
; Clobbers: rax, rcx
er_fn exec_restore_frame_state
    er_frame_push

    ; First read metadata at the end
    mov     rax, [exec_frame_save_ptr]
    sub     rax, 40
    mov     rcx, [exec_frame_save + rax]
    mov     [exec_local_count], rcx
    mov     rcx, [exec_frame_save + rax + 8]
    mov     [exec_stack_len], rcx
    mov     rcx, [exec_frame_save + rax + 16]
    mov     [exec_control_len], rcx
    mov     rcx, [exec_frame_save + rax + 24]
    mov     [exec_decoded_index], rcx
    mov     rcx, [exec_frame_save + rax + 32]
    mov     [exec_decoded_end], rcx
    mov     [exec_frame_save_ptr], rax

    ; Pop control frames
    mov     rcx, [exec_control_len]
    test    rcx, rcx
    jz      .rest_stack
    mov     rdx, [exec_frame_save_ptr]
.rest_control_loop:
    sub     rdx, CONTROL_FRAME_SIZE
    mov     r8, [exec_frame_save + rdx]
    mov     r9, [exec_frame_save + rdx + 8]
    mov     rax, exec_control
    add     rax, rcx
    sub     rax, CONTROL_FRAME_SIZE
    mov     [rax], r8
    mov     [rax + 8], r9
    dec     rcx
    jnz     .rest_control_loop
    mov     [exec_frame_save_ptr], rdx

.rest_stack:
    ; Pop stack entries
    mov     rcx, [exec_stack_len]
    test    rcx, rcx
    jz      .rest_locals
    mov     rdx, [exec_frame_save_ptr]
.rest_stack_loop:
    sub     rdx, 8
    mov     r8, [exec_frame_save + rdx]
    mov     rax, exec_stack
    add     rax, rcx
    sub     rax, 8
    mov     [rax], r8
    dec     rcx
    jnz     .rest_stack_loop
    mov     [exec_frame_save_ptr], rdx

.rest_locals:
    ; Pop locals
    mov     rcx, [exec_local_count]
    test    rcx, rcx
    jz      .done_rest
    mov     rdx, [exec_frame_save_ptr]
.rest_locals_loop:
    sub     rdx, 8
    mov     r8, [exec_frame_save + rdx]
    mov     rax, exec_locals
    add     rax, rcx
    sub     rax, 8
    mov     [rax], r8
    dec     rcx
    jnz     .rest_locals_loop
    mov     [exec_frame_save_ptr], rdx

.done_rest:
    er_ok
    pop     rbp
    ret

; ==================================================================
; Stack operations
; =================================================================+

; Pop a value from exec_stack into rax
; Returns carry set on underflow
er_fn exec_stack_pop
    er_frame_push
    mov     rax, [exec_stack_len]
    test    rax, rax
    jz      .underflow
    dec     rax
    mov     [exec_stack_len], rax
    mov     rax, [exec_stack + rax * 8]
    clc
    pop     rbp
    ret
.underflow:
    er_err  ERROR_STACK_UNDERFLOW
    stc
    pop     rbp
    ret

; Push rax onto exec_stack
; Returns carry set on overflow
er_fn exec_stack_push
    er_frame_push
    mov     rcx, [exec_stack_len]
    cmp     rcx, MAX_STACK
    jae     .overflow
    mov     [exec_stack + rcx * 8], rax
    inc     qword [exec_stack_len]
    clc
    pop     rbp
    ret
.overflow:
    er_err  ERROR_STACK_OVERFLOW
    stc
    pop     rbp
    ret

; Peek at stack top (no pop)
; Returns value in rax
er_fn exec_stack_peek
    mov     rax, [exec_stack_len]
    test    rax, rax
    jz      .underflow
    mov     rax, [exec_stack + rax * 8 - 8]
    clc
    ret
.underflow:
    stc
    ret

; Duplicate stack top
er_fn exec_stack_dup
    er_frame_push
    call    exec_stack_peek
    jc      .done
    call    exec_stack_push
.done:
    pop     rbp
    ret

; ==================================================================
; Error handler
; Sets error code and returns from enclosing function
; Expects error code in rdx
; =================================================================+
er_fn exec_error
    pop     rbp         ; pop return address of the caller
    pop     rbp         ; restore parent frame
    ret

; ==================================================================
; Read current reader byte without advancing
; =================================================================+
er_fn reader_peek_byte
    mov     rax, [exec_reader_offset]
    cmp     rax, [exec_code_body_len]
    jae     .done
    mov     rsi, [exec_code_body_ptr]
    mov     al, [rsi + rax]
    er_ok
    clc
    ret
.done:
    stc
    ret

; Advance reader by amount in rdi
er_fn reader_advance
    mov     rax, [exec_reader_offset]
    add     rax, rdi
    mov     [exec_reader_offset], rax
    ret

; Read a byte from reader and advance
; Returns byte in al, carry set if past end
er_fn reader_read_byte
    er_frame_push
    call    reader_peek_byte
    jc      .done
    inc     qword [exec_reader_offset]
    clc
.done:
    pop     rbp
    ret

; ==================================================================
; Set up frame for a function
; rdi = function_index
; rsi = args pointer (array of int64)
; rdx = args count
; =================================================================+
er_fn er_fn_exec
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi        ; function_index
    mov     r13, rsi        ; args ptr
    mov     r14, rdx        ; args count

    ; Check call depth
    mov     rax, [exec_call_depth]
    cmp     rax, MAX_CALL_DEPTH
    jae     .depth_error

    ; Save current frame if we have locals
    cmp     qword [exec_local_count], 0
    je      .no_save
    call    exec_save_frame_state
    jc      .depth_error
.no_save:
    inc     qword [exec_call_depth]

    ; Check if imported function
    mov     rax, r12
    cmp     rax, [import_count]
    jb      .imported_func

    ; Defined function
    sub     r12, [import_count]    ; defined_index
    mov     rdi, r12
    call    er_wasm_code_index_for_function
    test    rdx, rdx
    jnz     .error

    mov     r15, rax               ; code_index

    ; Get code info
    ; Code struct: body_offset(8) + body_len(8) + local_count(8) + decoded_start(8) + decoded_count(8)
    push    r10
    mov     r10, r15
    imul    r10, CODE_SIZE
    mov     rax, [code_buf + r10]      ; body_offset (from code body start)
    mov     [exec_code_body_ptr], rax
    mov     rax, [code_buf + r10 + 8]  ; body_len
    mov     [exec_code_body_len], rax
    mov     rax, [code_buf + r10 + 16] ; local_count
    mov     rbx, rax                   ; local_count
    mov     rax, [code_buf + r10 + 24] ; decoded_start
    mov     [exec_decoded_index], rax
    mov     rax, [code_buf + r10 + 32] ; decoded_count
    mov     [exec_decoded_end], rax
    pop     r10

    ; Get function type
    mov     rdi, r12
    add     rdi, [import_count]
    call    er_wasm_type_index_for_function
    test    rdx, rdx
    jnz     .error
    ; Store type info for result handling
    mov     [exec_type_index], rax

    ; param_count + result_count from FuncType
    push    r10
    mov     r10, rax
    imul    r10, FUNC_TYPE_SIZE
    mov     rax, [types_buf + r10 + FUNC_TYPE_PARAM_COUNT_OFF]  ; param_count
    mov     rcx, rax
    mov     rax, [types_buf + r10 + FUNC_TYPE_RESULT_COUNT_OFF] ; result_count
    mov     [exec_result_count], rax
    pop     r10

    ; Local count = param_count + code local_count
    ; The code local_count is the number of zero-initialized locals after params
    ; rbx already has local_count from code struct
    mov     rax, rcx     ; param_count
    add     rax, rbx     ; + code local_count
    mov     [exec_local_count], rax
    cmp     rax, MAX_LOCALS
    ja      .unsupported_error

    ; Initialize locals from args
    xor     r15d, r15d
.init_locals_loop:
    cmp     r15, rcx     ; param_count
    jae     .init_zero
    ; Copy arg
    mov     rax, [r13 + r15 * 8]
    mov     [exec_locals + r15 * 8], rax
    inc     r15
    jmp     .init_locals_loop
.init_zero:
    ; Zero remaining locals
    cmp     r15, [exec_local_count]
    jae     .init_done
    mov     qword [exec_locals + r15 * 8], 0
    inc     r15
    jmp     .init_zero
.init_done:
    ; Clear value stack and control stack
    mov     qword [exec_stack_len], 0
    mov     qword [exec_control_len], 0
    mov     qword [exec_reader_offset], 0

    ; Enter dispatch loop
    call    exec_dispatch_loop

    ; Restore error state
    mov     r15, rax      ; save return value
    mov     r14, rdx      ; save error code

    ; Decrement call depth
    dec     qword [exec_call_depth]

    ; Restore previous frame
    call    exec_restore_frame_state

    mov     rax, r15
    mov     rdx, r14
    jmp     .done

.imported_func:
    ; Imported function - call through host import dispatch
    call    er_wasm_call_imported
    jmp     .done

.depth_error:
    er_err  ERROR_UNSUPPORTED
    jmp     .done
.unsupported_error:
    er_err  ERROR_UNSUPPORTED
    jmp     .done
.error:
    ; rdx already set
.done:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; Imported function dispatch
; rdi = function_index (absolute, < import_count)
; =================================================================+
er_wasm_call_imported:
    er_frame_push
    ; For now, return Unsupported
    er_err  ERROR_UNSUPPORTED
    pop     rbp
    ret

; ==================================================================
; Main instruction dispatch loop
; =================================================================+
exec_dispatch_loop:
    er_frame_push

    ; One-time opcode table population
    cmp     byte [rel opcode_table_populated], 0
    jne     .dispatch_next
    inc     byte [rel opcode_table_populated]

    ; Default all 256 entries to unsupported_error
    lea     rax, [rel .unsupported_error]
    mov     ecx, 256
    lea     rdx, [rel opcode_table]
.fill_table:
    mov     [rdx + rcx * 8 - 8], rax
    dec     ecx
    jnz     .fill_table

    ; Set handler for each implemented opcode
    %macro _init_op 2
        lea     rax, [rel .%2]
        mov     [rel opcode_table + %1 * 8], rax
    %endm

    _init_op 0x00, op_unreachable
    _init_op 0x01, op_nop
    _init_op 0x02, op_block
    _init_op 0x03, op_loop
    _init_op 0x04, op_if
    _init_op 0x05, op_else
    _init_op 0x0b, op_end
    _init_op 0x0c, op_br
    _init_op 0x0d, op_br_if
    _init_op 0x0e, op_br_table
    _init_op 0x0f, op_return
    _init_op 0x10, op_call
    _init_op 0x11, op_call_indirect
    _init_op 0x1a, op_drop
    _init_op 0x1b, op_select
    _init_op 0x1c, op_select_typed
    _init_op 0x20, op_local_get
    _init_op 0x21, op_local_set
    _init_op 0x22, op_local_tee
    _init_op 0x23, op_global_get
    _init_op 0x24, op_global_set
    _init_op 0x25, op_table_get
    _init_op 0x26, op_table_set
    _init_op 0x28, op_i32_load
    _init_op 0x29, op_i64_load
    _init_op 0x2a, op_f32_load
    _init_op 0x2b, op_f64_load
    _init_op 0x2c, op_i32_load8_s
    _init_op 0x2d, op_i32_load8_u
    _init_op 0x2e, op_i32_load16_s
    _init_op 0x2f, op_i32_load16_u
    _init_op 0x30, op_i64_load8_s
    _init_op 0x31, op_i64_load8_u
    _init_op 0x32, op_i64_load16_s
    _init_op 0x33, op_i64_load16_u
    _init_op 0x34, op_i64_load32_s
    _init_op 0x35, op_i64_load32_u
    _init_op 0x36, op_i32_store
    _init_op 0x37, op_i64_store
    _init_op 0x38, op_f32_store
    _init_op 0x39, op_f64_store
    _init_op 0x3a, op_i32_store8
    _init_op 0x3b, op_i32_store16
    _init_op 0x3c, op_i64_store8
    _init_op 0x3d, op_i64_store16
    _init_op 0x3e, op_i64_store32
    _init_op 0x3f, op_memory_size
    _init_op 0x40, op_memory_grow
    _init_op 0x41, op_i32_const
    _init_op 0x42, op_i64_const
    _init_op 0x43, op_f32_const
    _init_op 0x44, op_f64_const
    _init_op 0x45, op_i32_eqz
    _init_op 0x46, op_i32_eq
    _init_op 0x47, op_i32_ne
    _init_op 0x48, op_i32_lt_s
    _init_op 0x49, op_i32_lt_u
    _init_op 0x4a, op_i32_gt_s
    _init_op 0x4b, op_i32_gt_u
    _init_op 0x4c, op_i32_le_s
    _init_op 0x4d, op_i32_le_u
    _init_op 0x4e, op_i32_ge_s
    _init_op 0x4f, op_i32_ge_u
    _init_op 0x50, op_i64_eqz
    _init_op 0x51, op_i64_eq
    _init_op 0x52, op_i64_ne
    _init_op 0x53, op_i64_lt_s
    _init_op 0x54, op_i64_lt_u
    _init_op 0x55, op_i64_gt_s
    _init_op 0x56, op_i64_gt_u
    _init_op 0x57, op_i64_le_s
    _init_op 0x58, op_i64_le_u
    _init_op 0x59, op_i64_ge_s
    _init_op 0x5a, op_i64_ge_u
    _init_op 0x5b, op_f32_eq
    _init_op 0x5c, op_f32_ne
    _init_op 0x5d, op_f32_lt
    _init_op 0x5e, op_f32_gt
    _init_op 0x5f, op_f32_le
    _init_op 0x60, op_f32_ge
    _init_op 0x61, op_f64_eq
    _init_op 0x62, op_f64_ne
    _init_op 0x63, op_f64_lt
    _init_op 0x64, op_f64_gt
    _init_op 0x65, op_f64_le
    _init_op 0x66, op_f64_ge
    _init_op 0x67, op_i32_clz
    _init_op 0x68, op_i32_ctz
    _init_op 0x69, op_i32_popcnt
    _init_op 0x6a, op_i32_add
    _init_op 0x6b, op_i32_sub
    _init_op 0x6c, op_i32_mul
    _init_op 0x6d, op_i32_div_s
    _init_op 0x6e, op_i32_div_u
    _init_op 0x6f, op_i32_rem_s
    _init_op 0x70, op_i32_rem_u
    _init_op 0x71, op_i32_and
    _init_op 0x72, op_i32_or
    _init_op 0x73, op_i32_xor
    _init_op 0x74, op_i32_shl
    _init_op 0x75, op_i32_shr_s
    _init_op 0x76, op_i32_shr_u
    _init_op 0x77, op_i32_rotl
    _init_op 0x78, op_i32_rotr
    _init_op 0x79, op_i64_clz
    _init_op 0x7a, op_i64_ctz
    _init_op 0x7b, op_i64_popcnt
    _init_op 0x7c, op_i64_add
    _init_op 0x7d, op_i64_sub
    _init_op 0x7e, op_i64_mul
    _init_op 0x7f, op_i64_div_s
    _init_op 0x80, op_i64_div_u
    _init_op 0x81, op_i64_rem_s
    _init_op 0x82, op_i64_rem_u
    _init_op 0x83, op_i64_and
    _init_op 0x84, op_i64_or
    _init_op 0x85, op_i64_xor
    _init_op 0x86, op_i64_shl
    _init_op 0x87, op_i64_shr_s
    _init_op 0x88, op_i64_shr_u
    _init_op 0x89, op_i64_rotl
    _init_op 0x8a, op_i64_rotr
    _init_op 0x8b, op_f32_abs
    _init_op 0x8c, op_f32_neg
    _init_op 0x8d, op_f32_ceil
    _init_op 0x8e, op_f32_floor
    _init_op 0x8f, op_f32_trunc
    _init_op 0x90, op_f32_nearest
    _init_op 0x91, op_f32_sqrt
    _init_op 0x92, op_f32_add
    _init_op 0x93, op_f32_sub
    _init_op 0x94, op_f32_mul
    _init_op 0x95, op_f32_div
    _init_op 0x96, op_f32_min
    _init_op 0x97, op_f32_max
    _init_op 0x98, op_f32_copysign
    _init_op 0x99, op_f64_abs
    _init_op 0x9a, op_f64_neg
    _init_op 0x9b, op_f64_ceil
    _init_op 0x9c, op_f64_floor
    _init_op 0x9d, op_f64_trunc
    _init_op 0x9e, op_f64_nearest
    _init_op 0x9f, op_f64_sqrt
    _init_op 0xa0, op_f64_add
    _init_op 0xa1, op_f64_sub
    _init_op 0xa2, op_f64_mul
    _init_op 0xa3, op_f64_div
    _init_op 0xa4, op_f64_min
    _init_op 0xa5, op_f64_max
    _init_op 0xa6, op_f64_copysign
    _init_op 0xa7, op_i32_wrap_i64
    _init_op 0xa8, op_i32_trunc_f32_s
    _init_op 0xa9, op_i32_trunc_f32_u
    _init_op 0xaa, op_i32_trunc_f64_s
    _init_op 0xab, op_i32_trunc_f64_u
    _init_op 0xac, op_i64_extend_i32_s
    _init_op 0xad, op_i64_extend_i32_u
    _init_op 0xae, op_i64_trunc_f32_s
    _init_op 0xaf, op_i64_trunc_f32_u
    _init_op 0xb0, op_i64_trunc_f64_s
    _init_op 0xb1, op_i64_trunc_f64_u
    _init_op 0xb2, op_f32_convert_i32_s
    _init_op 0xb3, op_f32_convert_i32_u
    _init_op 0xb4, op_f32_convert_i64_s
    _init_op 0xb5, op_f32_convert_i64_u
    _init_op 0xb6, op_f32_demote_f64
    _init_op 0xb7, op_f64_convert_i32_s
    _init_op 0xb8, op_f64_convert_i32_u
    _init_op 0xb9, op_f64_convert_i64_s
    _init_op 0xba, op_f64_convert_i64_u
    _init_op 0xbb, op_f64_promote_f32
    _init_op 0xbc, op_i32_reinterpret_f32
    _init_op 0xbd, op_i64_reinterpret_f64
    _init_op 0xbe, op_f32_reinterpret_i32
    _init_op 0xbf, op_f64_reinterpret_i64
    _init_op 0xc0, op_i32_extend8_s
    _init_op 0xc1, op_i32_extend16_s
    _init_op 0xc2, op_i64_extend8_s
    _init_op 0xc3, op_i64_extend16_s
    _init_op 0xc4, op_i64_extend32_s
    _init_op 0xd0, op_ref_null
    _init_op 0xd1, op_ref_is_null
    _init_op 0xd2, op_ref_func

.dispatch_next:
    ; Check reader done: reader_offset >= body_len
    mov     rax, [exec_reader_offset]
    cmp     rax, [exec_code_body_len]
    jae     .done

    ; Read opcode byte directly
    call    reader_read_byte
    jc      .corrupt_error

    movzx   ebx, al          ; opcode byte in bl

    ; Check for extended prefix (0xfc)
    cmp     bl, WASM_EXTENDED_PREFIX
    je      .extended_opcode

    ; Dispatch through opcode table (O(1), was O(n) ladder)
    jmp     [rel opcode_table + rbx * 8]

; ==================================================================
; Hot opcode handlers
; =================================================================+

.op_i32_const:
    ; Read i32 const value via LEB128
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_i32
    test    rdx, rdx
    jnz     .corrupt_error
    ; Update reader offset (LEB consumed bytes in rsi - body_ptr)
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_const:
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_i64
    test    rdx, rdx
    jnz     .corrupt_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_local_get:
    ; Read local index (LEB128)
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .corrupt_error
    ; Update reader
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    ; Check bounds
    cmp     rax, [exec_local_count]
    jae     .corrupt_error
    ; Read local
    mov     rax, [exec_locals + rax * 8]
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_local_set:
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .corrupt_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    cmp     rax, [exec_local_count]
    jae     .corrupt_error
    push    rax        ; save index
    call    exec_stack_pop
    jc      .underflow_error
    pop     rcx
    mov     [exec_locals + rcx * 8], rax
    jmp     .dispatch_next

.op_local_tee:
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .corrupt_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    cmp     rax, [exec_local_count]
    jae     .corrupt_error
    push    rax
    call    exec_stack_peek
    jc      .underflow_error
    pop     rcx
    mov     [exec_locals + rcx * 8], rax
    jmp     .dispatch_next

.op_global_get:
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .corrupt_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    cmp     rax, [global_count]
    jae     .corrupt_error
    push    r10
    mov     r10, rax
    imul    r10, GLOBAL_SIZE
    mov     rax, [globals_buf + r10 + 8]  ; value_data
    pop     r10
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_global_set:
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .corrupt_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    cmp     rax, [global_count]
    jae     .corrupt_error
    push    rax
    call    exec_stack_pop
    jc      .underflow_error
    pop     rcx
    push    r10
    mov     r10, rcx
    imul    r10, GLOBAL_SIZE
    mov     [globals_buf + r10 + 8], rax  ; value_data
    pop     r10
    jmp     .dispatch_next

.op_drop:
    call    exec_stack_pop
    jc      .underflow_error
    jmp     .dispatch_next

.op_select:
    call    exec_stack_pop  ; condition
    jc      .underflow_error
    mov     rcx, rax
    call    exec_stack_pop  ; false_val
    jc      .underflow_error
    mov     rdx, rax
    call    exec_stack_pop  ; true_val
    jc      .underflow_error
    test    ecx, ecx
    cmovz   rax, rdx
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_select_typed:
    ; Skip type immediates (read_byte for type count, then read_value_type)
    call    reader_read_byte   ; type_count (must be 1)
    jc      .corrupt_error
    cmp     al, 1
    jne     .unsupported_error
    call    reader_read_byte   ; value type byte
    jc      .corrupt_error
    ; Same as select
    call    exec_stack_pop  ; condition
    jc      .underflow_error
    mov     rcx, rax
    call    exec_stack_pop  ; false_val
    jc      .underflow_error
    mov     rdx, rax
    call    exec_stack_pop  ; true_val
    jc      .underflow_error
    test    ecx, ecx
    cmovz   rax, rdx
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_nop:
    jmp     .dispatch_next

.op_unreachable:
    er_err  ERROR_TRAP
    jmp     .error_return

.op_end:
    ; End of block/function
    mov     rax, [exec_control_len]
    test    rax, rax
    jz      .function_return
    ; Pop control frame
    dec     rax
    mov     [exec_control_len], rax
    jmp     .dispatch_next

.op_return:
    jmp     .function_return

.op_block:
    ; Read block type byte (skip it for now)
    call    reader_read_byte
    jc      .corrupt_error
    ; Push control frame: kind=BLOCK, start=reader_offset
    push    qword [exec_reader_offset]  ; start offset
    push    CONTROL_BLOCK
    call    exec_control_push
    jmp     .dispatch_next

.op_loop:
    call    reader_read_byte
    jc      .corrupt_error
    push    qword [exec_reader_offset]
    push    CONTROL_LOOP
    call    exec_control_push
    jmp     .dispatch_next

.op_if:
    call    reader_read_byte
    jc      .corrupt_error
    call    exec_stack_pop   ; condition
    jc      .underflow_error
    test    eax, eax
    jnz     .if_taken
    ; Skip to else or end
    ; Need to balance block/loop/if/else/end
    ; Simplified: scan forward counting nested blocks
    xor     r15d, r15d       ; depth
.skip_if_loop:
    call    reader_read_byte
    jc      .corrupt_error
    movzx   ebx, al
    cmp     bl, 0x02         ; block
    je      .skip_if_block
    cmp     bl, 0x03         ; loop
    je      .skip_if_block
    cmp     bl, 0x04         ; if
    je      .skip_if_block
    cmp     bl, 0x05         ; else
    je      .skip_if_else
    cmp     bl, 0x0b         ; end
    je      .skip_if_end
    ; Regular opcode - skip immediates
    call    .skip_opcode_immediates
    jmp     .skip_if_loop
.skip_if_block:
    inc     r15d
    call    reader_read_byte    ; skip block type
    jc      .corrupt_error
    jmp     .skip_if_loop
.skip_if_else:
    test    r15d, r15d
    jz      .if_else_found
    dec     r15d
    jmp     .skip_if_loop
.skip_if_end:
    test    r15d, r15d
    jz      .if_end_found
    dec     r15d
    jmp     .skip_if_loop
.if_else_found:
    push    qword [exec_reader_offset]
    push    CONTROL_IF_ELSE
    call    exec_control_push
    jmp     .dispatch_next
.if_end_found:
    ; No else branch - just continue (if body was empty)
    push    qword [exec_reader_offset]
    push    CONTROL_IF_THEN
    call    exec_control_push
    ; At end, so drop through to done
    jmp     .function_return
.if_taken:
    push    qword [exec_reader_offset]
    push    CONTROL_IF_THEN
    call    exec_control_push
    jmp     .dispatch_next

.op_else:
    ; Check control stack top is if_then
    mov     rax, [exec_control_len]
    test    rax, rax
    jz      .corrupt_error
    ; Pop control, push if_else (already at else body)
    dec     rax
    mov     [exec_control_len], rax
    push    qword [exec_reader_offset]
    push    CONTROL_IF_ELSE
    call    exec_control_push
    jmp     .dispatch_next

.op_br:
    ; Read branch depth
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .corrupt_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    ; Branch to control
    mov     rdi, rax        ; depth
    call    exec_branch_to_control
    test    rdx, rdx
    jnz     .corrupt_error
    jmp     .dispatch_next

.op_br_if:
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .corrupt_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    push    rax             ; save depth
    call    exec_stack_pop  ; condition
    jc      .underflow_error
    pop     rcx
    test    eax, eax
    jz      .dispatch_next
    mov     rdi, rcx
    call    exec_branch_to_control
    test    rdx, rdx
    jnz     .corrupt_error
    jmp     .dispatch_next

.op_call:
    ; Read function index
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .corrupt_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    ; Execute function
    mov     rdi, rax        ; function_index
    ; Pass current stack as args - simplified: pass args_ptr=0, args_count=0
    ; For proper argument passing, need to pop from stack
    xor     rsi, rsi        ; no explicit args for now
    xor     rdx, rdx
    call    er_fn_exec
    test    rdx, rdx
    jnz     .error_return
    jmp     .dispatch_next

.op_call_indirect:
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32    ; type_index
    test    rdx, rdx
    jnz     .corrupt_error
    push    rax
    call    reader_read_byte        ; table_index (LEB, but table index is small)
    jc      .corrupt_error
    pop     r15                     ; type_index -> r15
    ; Pop function index from stack
    call    exec_stack_pop
    jc      .underflow_error
    mov     rdi, rax                ; function_index
    xor     rsi, rsi
    xor     rdx, rdx
    call    er_fn_exec
    test    rdx, rdx
    jnz     .error_return
    jmp     .dispatch_next

.op_br_table:
    ; Read target count
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .corrupt_error
    mov     r15d, eax       ; target_count
    call    exec_stack_pop
    jc      .underflow_error
    mov     r14d, eax       ; selector
    xor     r13d, r13d      ; target_index
.br_table_loop:
    cmp     r13d, r15d
    jae     .br_table_default
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .corrupt_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    cmp     r13d, r14d
    je      .br_table_branch   ; found matching target
    inc     r13d
    jmp     .br_table_loop
.br_table_default:
    ; Read default target
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .corrupt_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
.br_table_branch:
    mov     rdi, rax        ; branch depth
    call    exec_branch_to_control
    test    rdx, rdx
    jnz     .corrupt_error
    jmp     .dispatch_next

; ==================================================================
; Control frame push/pop/branch
; =================================================================+

; Push control frame: expects values on stack (kind=8 bytes, start=8 bytes)
; Used as: push kind; push start; call exec_control_push

; ==================================================================
; Integer i32 binary ops
; =================================================================+
.op_i32_add:
    _wasm_binop e, add

.op_i32_sub:
    _wasm_binop e, sub

.op_i32_mul:
    _wasm_binop e, imul

.op_i32_div_s:
    call    exec_stack_pop
    jc      .underflow_error
    mov     ecx, eax
    call    exec_stack_pop
    jc      .underflow_error
    test    ecx, ecx
    jz      .arithmetic_trap
    cmp     eax, 0x80000000
    jne     .div_s_ok
    cmp     ecx, -1
    jne     .div_s_ok
    ; Overflow: INT_MIN / -1
    er_err  ERROR_ARITHMETIC_TRAP
    jmp     .error_return
.div_s_ok:
    cdq
    idiv    ecx
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_div_u:
    call    exec_stack_pop
    jc      .underflow_error
    mov     ecx, eax
    call    exec_stack_pop
    jc      .underflow_error
    test    ecx, ecx
    jz      .arithmetic_trap
    er_ok
    div     ecx
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_rem_s:
    call    exec_stack_pop
    jc      .underflow_error
    mov     ecx, eax
    call    exec_stack_pop
    jc      .underflow_error
    test    ecx, ecx
    jz      .arithmetic_trap
    mov     r8d, eax        ; save dividend
    cdq
    idiv    ecx
    mov     eax, edx        ; remainder
    ; If dividend was INT_MIN and divisor was -1, remainder = 0
    cmp     r8d, 0x80000000
    jne     .rem_s_done
    cmp     ecx, -1
    jne     .rem_s_done
    xor     eax, eax
.rem_s_done:
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_rem_u:
    call    exec_stack_pop
    jc      .underflow_error
    mov     ecx, eax
    call    exec_stack_pop
    jc      .underflow_error
    test    ecx, ecx
    jz      .arithmetic_trap
    er_ok
    div     ecx
    mov     eax, edx
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_and:
    _wasm_binop e, and

.op_i32_or:
    _wasm_binop e, or

.op_i32_xor:
    _wasm_binop e, xor

.op_i32_shl:
    _wasm_shiftop e, shl

.op_i32_shr_s:
    _wasm_shiftop e, sar

.op_i32_shr_u:
    _wasm_shiftop e, shr

.op_i32_rotl:
    _wasm_shiftop e, rol

.op_i32_rotr:
    _wasm_shiftop e, ror

.op_i32_clz:
    call    exec_stack_pop
    jc      .underflow_error
    ; Count leading zeros (eax -> eax)
    bsr     ecx, eax
    jnz     .clz_found
    mov     eax, 32
    jmp     .clz_done
.clz_found:
    mov     eax, 31
    sub     eax, ecx
.clz_done:
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_ctz:
    call    exec_stack_pop
    jc      .underflow_error
    bsf     ecx, eax
    jnz     .ctz_found
    mov     eax, 32
    jmp     .ctz_done
.ctz_found:
    mov     eax, ecx
.ctz_done:
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_popcnt:
    _wasm_unop e, popcnt

; ==================================================================
; Integer i32 comparison ops
; =================================================================+
.op_i32_eqz:
    _wasm_eqz e

.op_i32_eq:
    _wasm_cmpop e, sete

.op_i32_ne:
    _wasm_cmpop e, setne

.op_i32_lt_s:
    _wasm_cmpop e, setl

.op_i32_lt_u:
    _wasm_cmpop e, setb

.op_i32_gt_s:
    _wasm_cmpop e, setg

.op_i32_gt_u:
    _wasm_cmpop e, seta

.op_i32_le_s:
    _wasm_cmpop e, setle

.op_i32_le_u:
    _wasm_cmpop e, setbe

.op_i32_ge_s:
    _wasm_cmpop e, setge

.op_i32_ge_u:
    _wasm_cmpop e, setae

; ==================================================================
; Integer i64 binary ops
; =================================================================+
.op_i64_add:
    _wasm_binop r, add

.op_i64_sub:
    _wasm_binop r, sub

.op_i64_mul:
    _wasm_binop r, imul

.op_i64_div_s:
    call    exec_stack_pop
    jc      .underflow_error
    mov     rcx, rax
    call    exec_stack_pop
    jc      .underflow_error
    test    rcx, rcx
    jz      .arithmetic_trap
    mov     rdx, rax
    mov     rax, 0x8000000000000000
    cmp     rdx, rax
    jne     .div_s64_ok
    cmp     rcx, -1
    jne     .div_s64_ok
    ; Overflow: INT64_MIN / -1
    er_err  ERROR_ARITHMETIC_TRAP
    jmp     .error_return
.div_s64_ok:
    mov     rax, rdx
    cqo
    idiv    rcx
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_div_u:
    call    exec_stack_pop
    jc      .underflow_error
    mov     rcx, rax
    call    exec_stack_pop
    jc      .underflow_error
    test    rcx, rcx
    jz      .arithmetic_trap
    xor     rdx, rdx
    div     rcx
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_rem_s:
    call    exec_stack_pop
    jc      .underflow_error
    mov     rcx, rax
    call    exec_stack_pop
    jc      .underflow_error
    test    rcx, rcx
    jz      .arithmetic_trap
    mov     r8, rax
    cqo
    idiv    rcx
    mov     rax, rdx
    mov     rdx, 0x8000000000000000
    cmp     r8, rdx
    jne     .rem_s64_done
    cmp     rcx, -1
    jne     .rem_s64_done
    xor     eax, eax
.rem_s64_done:
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_rem_u:
    call    exec_stack_pop
    jc      .underflow_error
    mov     rcx, rax
    call    exec_stack_pop
    jc      .underflow_error
    test    rcx, rcx
    jz      .arithmetic_trap
    xor     rdx, rdx
    div     rcx
    mov     rax, rdx
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_and:
    _wasm_binop r, and

.op_i64_or:
    _wasm_binop r, or

.op_i64_xor:
    _wasm_binop r, xor

.op_i64_shl:
    _wasm_shiftop r, shl

.op_i64_shr_s:
    _wasm_shiftop r, sar

.op_i64_shr_u:
    _wasm_shiftop r, shr

.op_i64_rotl:
    _wasm_shiftop r, rol

.op_i64_rotr:
    _wasm_shiftop r, ror

.op_i64_clz:
    call    exec_stack_pop
    jc      .underflow_error
    bsr     rcx, rax
    jnz     .clz64_found
    mov     eax, 64
    jmp     .clz64_done
.clz64_found:
    mov     eax, 63
    sub     eax, ecx
.clz64_done:
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_ctz:
    call    exec_stack_pop
    jc      .underflow_error
    bsf     rcx, rax
    jnz     .ctz64_found
    mov     eax, 64
    jmp     .ctz64_done
.ctz64_found:
    mov     eax, ecx
.ctz64_done:
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_popcnt:
    _wasm_unop r, popcnt

; ==================================================================
; Integer i64 comparison ops
; =================================================================+
.op_i64_eqz:
    _wasm_eqz r

.op_i64_eq:
    _wasm_cmpop r, sete

.op_i64_ne:
    _wasm_cmpop r, setne

.op_i64_lt_s:
    _wasm_cmpop r, setl

.op_i64_lt_u:
    _wasm_cmpop r, setb

.op_i64_gt_s:
    _wasm_cmpop r, setg

.op_i64_gt_u:
    _wasm_cmpop r, seta

.op_i64_le_s:
    _wasm_cmpop r, setle

.op_i64_le_u:
    _wasm_cmpop r, setbe

.op_i64_ge_s:
    _wasm_cmpop r, setge

.op_i64_ge_u:
    _wasm_cmpop r, setae

; ==================================================================
; Conversion ops
; =================================================================+
.op_i32_wrap_i64:
    call    exec_stack_pop
    jc      .underflow_error
    ; Just take low 32 bits (already in rax, truncate upper bits)
    mov     eax, eax
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_extend_i32_s:
    call    exec_stack_pop
    jc      .underflow_error
    movsxd  rax, eax
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_extend_i32_u:
    call    exec_stack_pop
    jc      .underflow_error
    ; Zero extend (rax already has i32 in low bits, high bits 0 from 32-bit ops)
    mov     eax, eax    ; zero extend
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_extend8_s:
    call    exec_stack_pop
    jc      .underflow_error
    movsx   eax, al
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_extend16_s:
    call    exec_stack_pop
    jc      .underflow_error
    movsx   eax, ax
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_extend8_s:
    call    exec_stack_pop
    jc      .underflow_error
    movsx   rax, al
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_extend16_s:
    call    exec_stack_pop
    jc      .underflow_error
    movsx   rax, ax
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_extend32_s:
    call    exec_stack_pop
    jc      .underflow_error
    movsxd  rax, eax
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

; ==================================================================
; Reinterpret ops
; =================================================================+
.op_i32_reinterpret_f32:
    ; f32 bits are already on stack as 64-bit value
    ; Just take low 32 bits
    call    exec_stack_peek
    ; Value is already in rax, just keep as is
    ; (but tagged as i32, which we don't track)
    jmp     .dispatch_next

.op_f32_reinterpret_i32:
    ; i32 bits are already on stack
    jmp     .dispatch_next

.op_i64_reinterpret_f64:
    jmp     .dispatch_next

.op_f64_reinterpret_i64:
    jmp     .dispatch_next

; ==================================================================
; Reference ops
; =================================================================+
.op_ref_null:
    mov     eax, -1
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_ref_is_null:
    ; Pop reference value
    call    exec_stack_pop
    jc      .underflow_error
    cmp     eax, -1
    sete    al
    movzx   eax, al
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_ref_func:
    ; Read function index
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .corrupt_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    mov     rdi, rax
    ; Verify function index < totalFunctionCount
    mov     rax, [import_count]
    add     rax, [function_count]
    cmp     rdi, rax
    jae     .corrupt_error
    ; Push function index as funcref
    mov     rax, rdi
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

; ==================================================================
; Memory ops
; =================================================================+


.op_i32_load:
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 4          ; size
    call    exec_memory_check_range
    jc      .error_return
    mov     eax, [rax]      ; load 32 bits
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_load8_s:
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 1
    call    exec_memory_check_range
    jc      .error_return
    movsx   eax, byte [rax]
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_load8_u:
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 1
    call    exec_memory_check_range
    jc      .error_return
    movzx   eax, byte [rax]
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_load16_s:
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 2
    call    exec_memory_check_range
    jc      .error_return
    movsx   eax, word [rax]
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_load16_u:
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 2
    call    exec_memory_check_range
    jc      .error_return
    movzx   eax, word [rax]
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i32_store:
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 4
    call    exec_memory_check_range
    jc      .error_return
    push    rax
    call    exec_stack_pop
    jc      .underflow_error
    pop     rcx
    mov     [rcx], eax
    jmp     .dispatch_next

.op_i32_store8:
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 1
    call    exec_memory_check_range
    jc      .error_return
    push    rax
    call    exec_stack_pop
    jc      .underflow_error
    pop     rcx
    mov     [rcx], al
    jmp     .dispatch_next

.op_i32_store16:
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 2
    call    exec_memory_check_range
    jc      .error_return
    push    rax
    call    exec_stack_pop
    jc      .underflow_error
    pop     rcx
    mov     [rcx], ax
    jmp     .dispatch_next

.op_i64_load:
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 8
    call    exec_memory_check_range
    jc      .error_return
    mov     rax, [rax]
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_load8_s:
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 1
    call    exec_memory_check_range
    jc      .error_return
    movsx   rax, byte [rax]
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_load8_u:
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 1
    call    exec_memory_check_range
    jc      .error_return
    movzx   rax, byte [rax]
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_load16_s:
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 2
    call    exec_memory_check_range
    jc      .error_return
    movsx   rax, word [rax]
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_load16_u:
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 2
    call    exec_memory_check_range
    jc      .error_return
    movzx   rax, word [rax]
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_load32_s:
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 4
    call    exec_memory_check_range
    jc      .error_return
    movsxd  rax, dword [rax]
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_load32_u:
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 4
    call    exec_memory_check_range
    jc      .error_return
    mov     eax, [rax]
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_i64_store:
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 8
    call    exec_memory_check_range
    jc      .error_return
    push    rax
    call    exec_stack_pop
    jc      .underflow_error
    pop     rcx
    mov     [rcx], rax
    jmp     .dispatch_next

.op_i64_store8:
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 1
    call    exec_memory_check_range
    jc      .error_return
    push    rax
    call    exec_stack_pop
    jc      .underflow_error
    pop     rcx
    mov     [rcx], al
    jmp     .dispatch_next

.op_i64_store16:
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 2
    call    exec_memory_check_range
    jc      .error_return
    push    rax
    call    exec_stack_pop
    jc      .underflow_error
    pop     rcx
    mov     [rcx], ax
    jmp     .dispatch_next

.op_i64_store32:
    call    exec_memory_prepare
    jc      .error_return
    mov     ecx, 4
    call    exec_memory_check_range
    jc      .error_return
    push    rax
    call    exec_stack_pop
    jc      .underflow_error
    pop     rcx
    mov     [rcx], eax
    jmp     .dispatch_next

.op_memory_size:
    mov     rax, [executor_memory_pages]
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_memory_grow:
    call    exec_stack_pop
    jc      .underflow_error
    mov     r15, rax         ; requested pages
    ; Current pages
    mov     rax, [executor_memory_pages]
    mov     r14, rax         ; previous pages
    ; Check if grow function exists
    mov     rdi, [runtime_memory_grow_fn]
    test    rdi, rdi
    jz      .memory_grow_no_authority
    mov     rsi, [runtime_memory_grow_ctx]
    ; Call memory grow function: fn(context, old_pages, new_pages)
    ; ABI: rdi=context, rsi=old_pages, rdx=new_pages
    mov     rdx, r15
    call    rdi
    test    rax, rax
    jz      .memory_grow_failed
    ; Update memory pages and limit
    mov     [executor_memory_pages], r15
    ; Current pages pushed as result
    mov     rax, r14
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next
.memory_grow_no_authority:
    er_err  ERROR_MEMORY_GROWTH
    jmp     .error_return
.memory_grow_failed:
    ; Push -1 on failure (WASM spec)
    mov     eax, -1
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

; ==================================================================
; Table ops
; =================================================================+
.op_table_get:
    call    reader_read_byte   ; table index (skip, only table 0 supported)
    jc      .corrupt_error
    call    exec_stack_pop
    jc      .underflow_error
    cmp     rax, [table_min]
    jae     .corrupt_error
    mov     rax, [table_entries + rax * 8]
    call    exec_stack_push
    jc      .overflow_error
    jmp     .dispatch_next

.op_table_set:
    call    reader_read_byte
    jc      .corrupt_error
    call    exec_stack_pop   ; value
    jc      .underflow_error
    push    rax
    call    exec_stack_pop   ; index
    jc      .underflow_error
    pop     rcx
    cmp     rax, [table_min]
    jae     .corrupt_error
    mov     [table_entries + rax * 8], rcx
    jmp     .dispatch_next

; ==================================================================
; Float ops (stubs for now - return Unsupported)
; =================================================================+
.op_f32_load:
.op_f64_load:
.op_f32_store:
.op_f64_store:
.op_f32_const:
.op_f64_const:
.op_f32_eq:
.op_f32_ne:
.op_f32_lt:
.op_f32_gt:
.op_f32_le:
.op_f32_ge:
.op_f64_eq:
.op_f64_ne:
.op_f64_lt:
.op_f64_gt:
.op_f64_le:
.op_f64_ge:
.op_f32_abs:
.op_f32_neg:
.op_f32_ceil:
.op_f32_floor:
.op_f32_trunc:
.op_f32_nearest:
.op_f32_sqrt:
.op_f32_add:
.op_f32_sub:
.op_f32_mul:
.op_f32_div:
.op_f32_min:
.op_f32_max:
.op_f32_copysign:
.op_f64_abs:
.op_f64_neg:
.op_f64_ceil:
.op_f64_floor:
.op_f64_trunc:
.op_f64_nearest:
.op_f64_sqrt:
.op_f64_add:
.op_f64_sub:
.op_f64_mul:
.op_f64_div:
.op_f64_min:
.op_f64_max:
.op_f64_copysign:
.op_i32_trunc_f32_s:
.op_i32_trunc_f32_u:
.op_i32_trunc_f64_s:
.op_i32_trunc_f64_u:
.op_i64_trunc_f32_s:
.op_i64_trunc_f32_u:
.op_i64_trunc_f64_s:
.op_i64_trunc_f64_u:
.op_f32_convert_i32_s:
.op_f32_convert_i32_u:
.op_f32_convert_i64_s:
.op_f32_convert_i64_u:
.op_f32_demote_f64:
.op_f64_convert_i32_s:
.op_f64_convert_i32_u:
.op_f64_convert_i64_s:
.op_f64_convert_i64_u:
.op_f64_promote_f32:
    er_err  ERROR_UNSUPPORTED
    jmp     .error_return

; ==================================================================
; Extended opcodes (0xfc prefix)
; =================================================================+
.extended_opcode:
    ; Read extended opcode
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .corrupt_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi

    cmp     eax, EXT_I32_TRUNC_SAT_F32_S
    je      .ext_i32_trunc_sat_f32_s
    cmp     eax, EXT_I32_TRUNC_SAT_F32_U
    je      .ext_i32_trunc_sat_f32_u
    cmp     eax, EXT_I32_TRUNC_SAT_F64_S
    je      .ext_i32_trunc_sat_f64_s
    cmp     eax, EXT_I32_TRUNC_SAT_F64_U
    je      .ext_i32_trunc_sat_f64_u
    cmp     eax, EXT_I64_TRUNC_SAT_F32_S
    je      .ext_i64_trunc_sat_f32_s
    cmp     eax, EXT_I64_TRUNC_SAT_F32_U
    je      .ext_i64_trunc_sat_f32_u
    cmp     eax, EXT_I64_TRUNC_SAT_F64_S
    je      .ext_i64_trunc_sat_f64_s
    cmp     eax, EXT_I64_TRUNC_SAT_F64_U
    je      .ext_i64_trunc_sat_f64_u
    cmp     eax, EXT_MEMORY_INIT
    je      .ext_memory_init
    cmp     eax, EXT_DATA_DROP
    je      .ext_data_drop
    cmp     eax, EXT_MEMORY_COPY
    je      .ext_memory_copy
    cmp     eax, EXT_MEMORY_FILL
    je      .ext_memory_fill

    ; All other extended opcodes (table ops) - unsupported for now
    er_err  ERROR_UNSUPPORTED
    jmp     .error_return

.ext_memory_init:
    ; Read segment index, then memory index
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .corrupt_error
    push    rax             ; segment index
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    call    reader_read_byte ; memory index (0)
    jc      .corrupt_error
    pop     r15             ; segment index
    ; Pop dest, src, count from stack
    call    exec_stack_pop  ; n
    jc      .underflow_error
    mov     r14, rax
    call    exec_stack_pop  ; s
    jc      .underflow_error
    mov     r13, rax
    call    exec_stack_pop  ; d
    jc      .underflow_error
    mov     r12, rax
    ; TODO: implement actual memory.init
    ; For now, just skip
    jmp     .dispatch_next

.ext_data_drop:
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .corrupt_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    ; Mark data segment as dropped (set active=0)
    ; data_segment layout: offset(8) + byte_offset(8) + byte_len(8) + active(1) + dropped(1)
    ; For now, just skip
    jmp     .dispatch_next

.ext_memory_copy:
    ; Read dest memory index, then src memory index
    call    reader_read_byte
    jc      .corrupt_error
    call    reader_read_byte
    jc      .corrupt_error
    ; Pop n, s, d
    call    exec_stack_pop  ; n
    jc      .underflow_error
    mov     r14, rax
    call    exec_stack_pop  ; s
    jc      .underflow_error
    mov     r13, rax
    call    exec_stack_pop  ; d
    jc      .underflow_error
    mov     r12, rax
    ; TODO: implement actual memory.copy
    jmp     .dispatch_next

.ext_memory_fill:
    call    reader_read_byte
    jc      .corrupt_error
    ; Pop n, val, d
    call    exec_stack_pop  ; n
    jc      .underflow_error
    mov     r14, rax
    call    exec_stack_pop  ; val
    jc      .underflow_error
    mov     r13, rax
    call    exec_stack_pop  ; d
    jc      .underflow_error
    mov     r12, rax
    ; TODO: implement actual memory.fill
    jmp     .dispatch_next

; ==================================================================
; Opcode immediate skipping helper
; =================================================================+
.skip_opcode_immediates:
    ; ebx = opcode byte
    movzx   ebx, bl
    ; Most opcodes have no immediates
    ; Check opcodes that DO have immediates
    cmp     bl, 0x02         ; block
    je      .skip_block_type
    cmp     bl, 0x03         ; loop
    je      .skip_block_type
    cmp     bl, 0x04         ; if
    je      .skip_block_type
    cmp     bl, 0x0c         ; br
    je      .skip_leb
    cmp     bl, 0x0d         ; br_if
    je      .skip_leb
    cmp     bl, 0x10         ; call
    je      .skip_leb
    cmp     bl, 0x11         ; call_indirect
    je      .skip_call_indirect
    cmp     bl, 0x20         ; local.get
    je      .skip_leb
    cmp     bl, 0x21         ; local.set
    je      .skip_leb
    cmp     bl, 0x22         ; local.tee
    je      .skip_leb
    cmp     bl, 0x23         ; global.get
    je      .skip_leb
    cmp     bl, 0x24         ; global.set
    je      .skip_leb
    cmp     bl, 0x41         ; i32.const
    je      .skip_leb_i32
    cmp     bl, 0x42         ; i64.const
    je      .skip_leb_i64
    cmp     bl, 0x0e         ; br_table
    je      .skip_br_table
    cmp     bl, 0x28         ; i32.load etc.
    ret
    cmp     bl, 0x3f         ; below memory_size
    jb      .skip_load_store
    cmp     bl, 0x40         ; memory_grow
    je      .skip_leb
    cmp     bl, 0x1c         ; select_typed
    je      .skip_select_typed
    cmp     bl, 0xd0         ; ref.null
    je      .skip_byte
    cmp     bl, 0xd2         ; ref.func
    je      .skip_leb
    ; For most opcodes, no immediates to skip
    ret

.skip_leb:
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .skip_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    ret

.skip_leb_i32:
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_i32
    test    rdx, rdx
    jnz     .skip_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    ret

.skip_leb_i64:
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_i64
    test    rdx, rdx
    jnz     .skip_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    ret

.skip_block_type:
    call    reader_read_byte
    jc      .skip_error
    ret

.skip_byte:
    call    reader_read_byte
    jc      .skip_error
    ret

.skip_call_indirect:
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32    ; type_index
    test    rdx, rdx
    jnz     .skip_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    call    reader_read_byte        ; table_index
    ret

.skip_load_store:
    ; Two LEBs: alignment then offset
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .skip_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .skip_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    ret

.skip_br_table:
    ; Read target count, then targets, then default
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .skip_error
    mov     r15d, eax      ; target count
.skip_br_table_loop:
    test    r15d, r15d
    jz      .skip_br_table_default
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .skip_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    dec     r15d
    jmp     .skip_br_table_loop
.skip_br_table_default:
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .skip_error
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    ret

.skip_select_typed:
    call    reader_read_byte  ; type count (should be 1)
    ret

.skip_error:
    ; On skip error, just return (will be caught later)
    ret

; ==================================================================
; Function return handling
; =================================================================+
.function_return:
    ; Collect results from stack based on result count
    mov     rcx, [exec_result_count]
    test    rcx, rcx
    jz      .return_done
    mov     r15, rcx
    ; Pop results in reverse order
.return_collect:
    cmp     r15, 0
    je      .return_done
    dec     r15
    call    exec_stack_pop
    jc      .underflow_error
    mov     [exec_result_values + r15 * 8], rax
    jmp     .return_collect
.return_done:
    ; If this is the outermost call (stack_len was 0 before call), exit loop
    ; Otherwise, the result will be pushed back by caller
    er_ok
    pop     rbp
    ret

; ==================================================================
; Error exit points
; =================================================================+
.corrupt_error:
    er_err  ERROR_CORRUPT
    jmp     .error_return
.underflow_error:
    er_err  ERROR_STACK_UNDERFLOW
    jmp     .error_return
.overflow_error:
    er_err  ERROR_STACK_OVERFLOW
    jmp     .error_return
.unsupported_error:
    er_err  ERROR_UNSUPPORTED
    jmp     .error_return
.arithmetic_trap:
    er_err  ERROR_ARITHMETIC_TRAP
    jmp     .error_return

; ==================================================================
; Outer dispatch loop exit (error)
; =================================================================+
.done:
    er_ok
    pop     rbp
    ret

.error_return:
    ; rdx set by caller
    mov     rax, -1
    pop     rbp
    ret
er_fn exec_control_push
    pop     rax     ; return address
    pop     rcx     ; start
    pop     rdx     ; kind
    push    rax     ; restore return address
    mov     rax, [exec_control_len]
    cmp     rax, MAX_CONTROL_DEPTH
    jae     .overflow
    push    r10
    mov     r10, rax
    imul    r10, CONTROL_FRAME_SIZE
    mov     [exec_control + r10], rdx      ; kind
    mov     [exec_control + r10 + 8], rcx  ; start
    pop     r10
    inc     qword [exec_control_len]
    ret
.overflow:
    er_err  ERROR_UNSUPPORTED
    ; Skip the pushed values
    ret

; Branch to control at given depth
; rdi = branch_depth from current position (0 = innermost)
er_fn exec_branch_to_control
    er_frame_push
    ; target_index = control_len - 1 - branch_depth
    mov     rax, [exec_control_len]
    test    rax, rax
    jz      .error
    sub     rax, 1
    sub     rax, rdi
    jc      .error
    ; Get control frame at target_index
    push    r10
    mov     r10, rax
    imul    r10, CONTROL_FRAME_SIZE
    mov     rcx, [exec_control + r10]        ; kind
    mov     rdx, [exec_control + r10 + 8]   ; start
    pop     r10
    ; Set control length = target_index + 1 (for loop) or target_index (for block)
    mov     r8, rax         ; target_index
    cmp     rcx, CONTROL_LOOP
    je      .branch_loop
    ; block/if_then/if_else
.branch_block:
    mov     [exec_control_len], r8
    mov     [exec_reader_offset], rdx
    jmp     .branch_done
.branch_loop:
    add     r8, 1
    mov     [exec_control_len], r8
    mov     [exec_reader_offset], rdx
.branch_done:
    er_ok
    pop     rbp
    ret
.error:
    er_err  ERROR_CORRUPT
    pop     rbp
    ret
; Helper: read alignment and offset immediates, compute address
; Returns address in rax
er_fn exec_memory_prepare
    ; Read alignment (LEB, skip it)
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .corrupt_mem
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    ; Read offset (LEB)
    mov     rsi, [exec_code_body_ptr]
    add     rsi, [exec_reader_offset]
    call    er_wasm_read_leb_u32
    test    rdx, rdx
    jnz     .corrupt_mem
    push    rsi
    sub     rsi, [exec_code_body_ptr]
    mov     [exec_reader_offset], rsi
    pop     rsi
    mov     r15d, eax      ; offset
    ; Pop base address from stack
    call    exec_stack_pop
    jc      .underflow_mem
    mov     ecx, eax        ; base (lower 32 bits)
    ; Compute final address = base + offset
    mov     eax, ecx
    add     eax, r15d       ; add offset
    jc      .no_memory      ; overflow
    clc
    ret
.corrupt_mem:
    er_err  ERROR_CORRUPT
    stc
    ret
.underflow_mem:
    er_err  ERROR_STACK_UNDERFLOW
    stc
    ret
.no_memory:
    er_err  ERROR_NO_MEMORY
    stc
    ret

; Check memory range: address in eax, size in ecx
; Returns pointer in rax, carry on error
er_fn exec_memory_check_range
    er_frame_push
    ; Check address + size <= memory_len
    mov     rdx, [runtime_memory_len]
    mov     r8d, eax
    add     r8d, ecx
    jc      .out_of_range
    cmp     r8d, edx
    ja      .out_of_range
    ; Also check address + size <= memory_limit
    mov     rdx, [executor_memory_limit]
    cmp     r8d, edx
    ja      .out_of_range
    ; Valid: return pointer in rax
    add     rax, [runtime_memory_ptr]
    clc
    pop     rbp
    ret
.out_of_range:
    er_err  ERROR_NO_MEMORY
    stc
    pop     rbp
    ret

