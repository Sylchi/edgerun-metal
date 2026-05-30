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

