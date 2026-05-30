; ==================================================================
; SECTION .text
; ==================================================================
SECTION .text

; ==================================================================
; Helper: er_wasm_read_leb_u32
; Reads a LEB128 unsigned 32-bit value from [rsi], returns in rax.
; Updates rsi to point past the value.
; Returns error in rdx (0 = ok, nonzero = error).
; ==================================================================
er_wasm_read_leb_u32:
    xor     eax, eax
    xor     ecx, ecx            ; shift count (in bits)
    xor     r8d, r8d            ; byte counter
.leb_loop:
    cmp     r8d, LEB32_MAX_BYTES
    jge     .leb_error
    movzx   r9d, byte [rsi]
    inc     rsi
    mov     r10d, r9d
    and     r10d, LEB_PAYLOAD_MASK
    shl     r10d, cl
    or      eax, r10d
    add     ecx, LEB_BITS_PER_BYTE
    inc     r8d
    test    r9d, LEB_CONTINUE_MASK
    jnz     .leb_loop
    er_ok            ; no error
    ret
.leb_error:
    er_err  ERROR_CORRUPT
    ret

; ==================================================================
; Helper: er_wasm_read_leb_i32
; Reads a LEB128 signed 32-bit value from [rsi], returns in rax.
; Updates rsi to point past the value.
; Returns error in rdx.
; ==================================================================
er_wasm_read_leb_i32:
    xor     eax, eax
    xor     ecx, ecx
    xor     r8d, r8d
    mov     r9b, 0              ; will store last byte
.leb_loop_s:
    cmp     r8d, LEB32_MAX_BYTES
    jge     .leb_error_s
    mov     r9b, byte [rsi]
    inc     rsi
    mov     r10d, r9d
    and     r10d, LEB_PAYLOAD_MASK
    shl     r10d, cl
    or      eax, r10d
    add     ecx, LEB_BITS_PER_BYTE
    inc     r8d
    test    r9b, LEB_CONTINUE_MASK
    jnz     .leb_loop_s
    ; sign extend if needed
    mov     ecx, r8d
    shl     ecx, 3              ; total bits read = bytes * 7
    cmp     ecx, 32
    jge     .done_s
    test    r9b, LEB_SIGN_MASK
    jz      .done_s
    mov     r10d, -1
    shl     r10d, cl            ; shift -1 left by bits_read
    or      eax, r10d
.done_s:
    er_ok
    ret
.leb_error_s:
    er_err  ERROR_CORRUPT
    ret

; ==================================================================
; Helper: er_wasm_read_leb_i64
; Reads a LEB128 signed 64-bit value from [rsi], returns in rax.
; Updates rsi to point past the value.
; Returns error in rdx.
; ==================================================================
er_wasm_read_leb_i64:
    xor     eax, eax
    xor     ecx, ecx
    xor     r8d, r8d
    mov     r9b, 0
.leb_loop_l:
    cmp     r8d, LEB64_MAX_BYTES
    jge     .leb_error_l
    mov     r9b, byte [rsi]
    inc     rsi
    mov     r10, r9
    and     r10, LEB_PAYLOAD_MASK
    shl     r10, cl
    or      rax, r10
    add     ecx, LEB_BITS_PER_BYTE
    inc     r8d
    test    r9b, LEB_CONTINUE_MASK
    jnz     .leb_loop_l
    mov     ecx, r8d
    shl     ecx, 3
    cmp     ecx, 64
    jge     .done_l
    test    r9b, LEB_SIGN_MASK
    jz      .done_l
    mov     r10, -1
    shl     r10, cl
    or      rax, r10
.done_l:
    er_ok
    ret
.leb_error_l:
    er_err  ERROR_CORRUPT
    ret

; ==================================================================
; Helper: er_wasm_read_value_type
; Reads a ValueType byte from [rsi], returns in al.
; Updates rsi. Returns error in rdx.
; ==================================================================
er_wasm_read_value_type:
    movzx   eax, byte [rsi]
    inc     rsi
    cmp     al, VALUE_TAG_I32
    je      .valid
    cmp     al, VALUE_TAG_I64
    je      .valid
    cmp     al, VALUE_TAG_F32
    je      .valid
    cmp     al, VALUE_TAG_F64
    je      .valid
    cmp     al, VALUE_TAG_FUNCREF
    je      .valid
    er_err  ERROR_UNSUPPORTED
    ret
.valid:
    er_ok
    ret

; ==================================================================
; Helper: er_wasm_read_limits
; Reads limits from [rsi], stores in [rcx] (Limits struct: min=0, max=8).
; Updates rsi.
; NOTE: er_wasm_read_leb_u32 clobbers rcx (shift counter).
;       Save rcx in rbx before calling it.
; ==================================================================
er_wasm_read_limits:
    push    rbx
    mov     rbx, rcx            ; preserve output pointer in callee-saved rbx
    movzx   eax, byte [rsi]
    inc     rsi
    cmp     al, LIMITS_MIN_ONLY
    je      .min_only
    cmp     al, LIMITS_MIN_MAX
    je      .min_max
    er_err  ERROR_UNSUPPORTED
    pop     rbx
    ret
.min_only:
    er_call er_wasm_read_leb_u32, .error
    mov     [rbx], rax          ; store min
    mov     qword [rbx + 8], 0  ; max = null (0)
    er_ok
    pop     rbx
    ret
.min_max:
    er_call er_wasm_read_leb_u32, .error
    mov     [rbx], rax          ; store min
    push    rax                 ; save min on stack for comparison
    er_call er_wasm_read_leb_u32, .error_pop
    pop     rcx                 ; restore min for comparison
    cmp     rax, rcx
    jb      .corrupt
    mov     [rbx + 8], rax      ; store max
    er_ok
    pop     rbx
    ret
.corrupt:
    er_err  ERROR_CORRUPT
    pop     rbx
    ret
.error_pop:
    add     rsp, 8              ; discard saved min
.error:
    pop     rbx
    ret

; ==================================================================
; Helper: er_wasm_read_constant_i32
; Reads i32.const + value + end expression from [rsi].
; Returns value in rax. Updates rsi.
; ==================================================================
er_wasm_read_constant_i32:
    movzx   eax, byte [rsi]
    inc     rsi
    cmp     al, 0x41            ; i32.const
    jne     .unsupported
    er_call er_wasm_read_leb_i32, .error
    push    rax                 ; save value
    movzx   eax, byte [rsi]
    inc     rsi
    cmp     al, 0x0b            ; end
    jne     .unsupported
    pop     rax
    er_ok
    ret
.unsupported:
    er_err  ERROR_UNSUPPORTED
.error:
    ret

; ==================================================================
; Helper: eql (string comparison)
; Compares two bytes at [rdi] (len in rsi) and [rdx] (len in rcx).
; Returns 1 in rax if equal, 0 otherwise.
; Clobbers: rdi, rsi, rcx, r8
; ==================================================================
er_wasm_eql:
    er_frame_push
    ; rdi = ptr1, rsi = len1, rdx = ptr2, rcx = len2
    cmp     rsi, rcx
    jne     .not_equal
    test    rsi, rsi
    jz      .equal
    mov     r8, rsi
    mov     rsi, rdx
    mov     rcx, r8
    cld
    repe    cmpsb
    jne     .not_equal
.equal:
    mov     eax, 1
    pop     rbp
    ret
.not_equal:
    xor     eax, eax
    pop     rbp
    ret

; ==================================================================
; Helper: find_host_import
; Searches runtime.imports for a matching import.
; rdi = import_ptr (ImportedFunction), rsi = import_size (for generic compare)
; rdx = expected kind (function/memory/table/global)
; Returns host import ptr in rax, or error in rdx
; ==================================================================
; TODO: implement

; ==================================================================
; Helper: checked_add
; Returns rdi + rsi in rax, CF set if overflow
; ==================================================================
er_wasm_checked_add:
    mov     rax, rdi
    add     rax, rsi
    ret

; ==================================================================
; Helper: pages_to_bytes
; rdi = pages, returns bytes in rax, rdx = 0 on success, error on overflow
; ==================================================================
er_wasm_pages_to_bytes:
    mov     rax, rdi
    shr     rax, 48             ; if pages > 2^48, overflow (since 2^48 >> 16 = 2^32)
    test    rax, rax
    jnz     .overflow
    mov     rax, rdi
    shl     rax, WASM_PAGE_SHIFT
    er_ok
    ret
.overflow:
    er_err  ERROR_UNSUPPORTED
    ret

; ==================================================================
; Module parser entry point
; er_wasm_parse_module(bytes_ptr=rdi, bytes_len=rsi)
; Returns: rdx = 0 on success, otherwise error code (per macros.inc convention)
; Destroys current module state, re-parses into global structures
; =================================================================+
er_wasm_parse_module:
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    sub     rsp, 64             ; local vars

    ; Reset module state
    mov     qword [type_count], 0
    mov     qword [import_count], 0
    mov     qword [function_count], 0
    mov     qword [code_count], 0
    mov     qword [export_count], 0
    mov     qword [global_count], 0
    mov     qword [imported_global_count], 0
    mov     qword [element_segment_count], 0
    mov     qword [data_segment_count], 0
    mov     qword [declared_data_count], 0
    mov     qword [table_min], 0
    mov     qword [table_max], 0
    mov     byte [table_has], 0
    mov     byte [imported_memory_present], 0
    mov     byte [imported_table_present], 0
    mov     qword [decoded_op_count], 0
    mov     qword [start_function_index], -1

    ; Check magic bytes
    cmp     rsi, 8
    jb      .corrupt
    ; Compare wasm magic
    mov     r8d, [rdi]
    cmp     r8d, 0x6d736100      ; little-endian "\x00asm"
    jne     .corrupt
    ; Compare wasm version (0x00000001 at offset 4)
    mov     r8d, [rdi + 4]
    cmp     r8d, 0x00000001
    jne     .corrupt

    ; Set up reader at offset 8
    lea     r12, [rdi + 8]      ; r12 = current read position
    lea     r13, [rdi + rsi]    ; r13 = end pointer
    xor     r14b, r14b          ; previous_section_order

.parse_loop:
    cmp     r12, r13
    jae     .parse_done

    ; Read section ID
    movzx   r15d, byte [r12]
    inc     r12

    ; Read section size (LEB128)
    mov     rsi, r12
    er_call er_wasm_read_leb_u32, .error
    mov     r11, rax            ; r11 = section_size

    ; Skip custom sections (id == 0)
    test    r15d, r15d
    jz      .skip_section

    ; Validate section order (section must have strictly increasing order)
    movzx   eax, byte [section_order + r15]
    cmp     al, r14b
    jbe     .corrupt
    mov     r14b, al

    ; Section payload bounds check
    mov     rax, r12
    add     rax, r11
    cmp     rax, r13
    ja      .corrupt

    ; Save rsi (payload start) and r11 (payload len), dispatch
    mov     [rsp], rsi          ; save payload start (past section-size LEB)
    mov     [rsp + 8], r11      ; save payload length
    mov     [rsp + 16], r13     ; save end pointer

    ; r12 = payload pointer for section parsing
    mov     r12, rsi
    mov     [debug_section_id], r15b  ; debug: mark section ID
    cmp     r15d, SECTION_TYPE
    je      .parse_type
    cmp     r15d, SECTION_IMPORT
    je      .parse_import
    cmp     r15d, SECTION_FUNCTION
    je     .parse_function
    cmp     r15d, SECTION_TABLE
    je      .parse_table
    cmp     r15d, SECTION_MEMORY
    je      .parse_memory
    cmp     r15d, SECTION_GLOBAL
    je      .parse_global
    cmp     r15d, SECTION_EXPORT
    je      .parse_export
    cmp     r15d, SECTION_START
    je      .parse_start
    cmp     r15d, SECTION_ELEMENT
    je      .parse_element
    cmp     r15d, SECTION_DATA_COUNT
    je      .parse_data_count
    cmp     r15d, SECTION_CODE
    je      .parse_code
    cmp     r15d, SECTION_DATA
    je      .parse_data
    jmp     .unsupported

.skip_section:
    add     r12, r11
    jmp     .parse_loop

.parse_type:
    er_call er_wasm_parse_type_section, .error
    ; advance past section
    mov     r12, [rsp]
    add     r12, [rsp + 8]
    mov     r13, [rsp + 16]
    jmp     .parse_loop

.parse_import:
    er_call er_wasm_parse_import_section, .error
    mov     r12, [rsp]
    add     r12, [rsp + 8]
    mov     r13, [rsp + 16]
    jmp     .parse_loop

.parse_function:
    er_call er_wasm_parse_function_section, .error
    mov     r12, [rsp]
    add     r12, [rsp + 8]
    mov     r13, [rsp + 16]
    jmp     .parse_loop

.parse_table:
    er_call er_wasm_parse_table_section, .error
    mov     r12, [rsp]
    add     r12, [rsp + 8]
    mov     r13, [rsp + 16]
    jmp     .parse_loop

.parse_memory:
    er_call er_wasm_parse_memory_section, .error
    mov     r12, [rsp]
    add     r12, [rsp + 8]
    mov     r13, [rsp + 16]
    jmp     .parse_loop

.parse_global:
    er_call er_wasm_parse_global_section, .error
    mov     r12, [rsp]
    add     r12, [rsp + 8]
    mov     r13, [rsp + 16]
    jmp     .parse_loop

.parse_export:
    er_call er_wasm_parse_export_section, .error
    mov     r12, [rsp]
    add     r12, [rsp + 8]
    mov     r13, [rsp + 16]
    jmp     .parse_loop

.parse_start:
    er_call er_wasm_parse_start_section, .error
    mov     r12, [rsp]
    add     r12, [rsp + 8]
    mov     r13, [rsp + 16]
    jmp     .parse_loop

.parse_element:
    er_call er_wasm_parse_element_section, .error
    mov     r12, [rsp]
    add     r12, [rsp + 8]
    mov     r13, [rsp + 16]
    jmp     .parse_loop

.parse_data_count:
    er_call er_wasm_parse_data_count_section, .error
    mov     r12, [rsp]
    add     r12, [rsp + 8]
    mov     r13, [rsp + 16]
    jmp     .parse_loop

.parse_code:
    er_call er_wasm_parse_code_section, .error
    mov     r12, [rsp]
    add     r12, [rsp + 8]
    mov     r13, [rsp + 16]
    jmp     .parse_loop

.parse_data:
    er_call er_wasm_parse_data_section, .error
    mov     r12, [rsp]
    add     r12, [rsp + 8]
    mov     r13, [rsp + 16]
    jmp     .parse_loop

.parse_done:
    ; Validate function_count == code_count
    mov     rax, [function_count]
    cmp     rax, [code_count]
    jne     .corrupt
    ; Validate declared_data_count matches data_segment_count if present
    mov     rax, [declared_data_count]
    test    rax, rax
    jz      .success
    cmp     rax, [data_segment_count]
    jne     .corrupt
.success:
    er_ok
    jmp     .done
.corrupt:
    er_err  ERROR_CORRUPT
    jmp     .done
.unsupported:
    er_err  ERROR_UNSUPPORTED
    jmp     .done
.error:
    ; rdx already has error from called function — pass through
.done:
    lea     rsp, [rbp - 40]
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; Type section parser
; Parses types from [r12] into types_buf
; =================================================================+
er_wasm_parse_type_section:
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14

    mov     rsi, r12
    er_call er_wasm_read_leb_u32, .error
    mov     r14, rax            ; r14 = count
    cmp     r14, MAX_TYPES
    ja      .unsupported
    mov     [type_count], r14

    ; Parse each FuncType
    xor     r13d, r13d          ; index
.type_loop:
    cmp     r13, r14
    jae     .done

    ; Read form byte (must be 0x60)
    movzx   eax, byte [rsi]
    inc     rsi
    cmp     al, 0x60
    jne     .unsupported

    ; Read param count
    er_call er_wasm_read_leb_u32, .error
    cmp     rax, MAX_TYPE_PARAMS
    ja      .unsupported
    
    ; Compute offset into types_buf
    mov     rbx, r13
    imul    rbx, FUNC_TYPE_SIZE
    lea     rbx, [types_buf + rbx]

    ; Store param count
    mov     [rbx + FUNC_TYPE_PARAM_COUNT_OFF], rax
    mov     rcx, rax            ; rcx = param count

    ; Read params
    xor     r8d, r8d
.param_loop:
    cmp     r8, rcx
    jae     .params_done
    er_call er_wasm_read_value_type, .error
    mov     [rbx + r8], al      ; store param type byte
    inc     r8
    jmp     .param_loop
.params_done:

    ; Read result count
    er_call er_wasm_read_leb_u32, .error
    cmp     rax, MAX_TYPE_RESULTS
    ja      .unsupported
    mov     [rbx + FUNC_TYPE_RESULT_COUNT_OFF], rax
    mov     rcx, rax            ; rcx = result count

    ; Read results
    xor     r8d, r8d
.result_loop:
    cmp     r8, rcx
    jae     .results_done
    er_call er_wasm_read_value_type, .error
    mov     [rbx + MAX_TYPE_PARAMS + r8], al  ; store result type after params
    inc     r8
    jmp     .result_loop
.results_done:

    inc     r13
    jmp     .type_loop

.done:
    mov     r12, rsi            ; save updated reader position
    er_ok
    jmp     .out
.unsupported:
    er_err  ERROR_UNSUPPORTED
    jmp     .out
.error:
    er_err  ERROR_CORRUPT
.out:
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; Import section parser
; =================================================================+
er_wasm_parse_import_section:
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     rsi, r12
    er_call er_wasm_read_leb_u32, .error
    mov     r14, rax            ; r14 = count
    cmp     r14, MAX_IMPORTS
    ja      .unsupported

    xor     r13d, r13d          ; import index
.import_loop:
    cmp     r13, r14
    jae     .done

    ; Read module name
    er_call er_wasm_read_leb_u32, .error
    mov     r15, rsi
    add     rsi, rax            ; skip name bytes (we don't store them for matching — names are in the caller's wasm bytes)

    ; Read import name
    er_call er_wasm_read_leb_u32, .error
    mov     r15, rsi
    add     rsi, rax

    ; Read external kind
    movzx   r15d, byte [rsi]
    inc     rsi

    cmp     r15d, EXTERNAL_FUNCTION
    je      .import_function
    cmp     r15d, EXTERNAL_MEMORY
    je      .import_memory
    cmp     r15d, EXTERNAL_GLOBAL
    je      .import_global
    cmp     r15d, EXTERNAL_TABLE
    je      .import_table
    jmp     .unsupported

.import_function:
    ; Store ImportedFunction
    push    r10
        mov     r10, r13
        imul    r10, IMPORTED_FUNC_SIZE
    mov     qword [imports_buf + r10], r15   ; module offset (simplified — just store pointer to wasm bytes)
        pop     r10
    ; For now, we store the name pointer relative to original bytes
    ; TODO: store properly
    mov     rdi, qword [rsp]    ; get saved payload start
    ; type_index
    er_call er_wasm_read_leb_u32, .error
    ; Verify type_index < type_count
    mov     rbx, rax
    cmp     rbx, [type_count]
    jae     .corrupt
    push    r10
        mov     r10, r13
        imul    r10, IMPORTED_FUNC_SIZE
    mov     [imports_buf + r10 + 32], rbx  ; type_index @ offset 32
        pop     r10
    jmp     .import_next

.import_memory:
    ; Store ImportedMemory
    mov     byte [imported_memory_present], 1
    lea     rcx, [rsp - 16]      ; temp Limits struct
    push    rsi
    call    er_wasm_read_limits
    pop     rsi
    test    edx, edx
    jnz     .error
    mov     rax, [rsp - 16]      ; min
    mov     rbx, [rsp - 8]       ; max
    mov     [imported_memory_min], rax
    mov     [imported_memory_max], rbx
    ; Update module memory limits
    mov     [memory_min_pages], rax  ; TODO: define this global
    mov     [memory_max_pages], rbx
    jmp     .import_next

.import_global:
    er_call er_wasm_read_value_type, .error
    movzx   r15d, byte [rsi - 1]  ; reread value type byte
    movzx   ebx, byte [rsi]
    inc     rsi
    cmp     bl, 1
    ja      .corrupt
    mov     rdi, [global_count]
    cmp     rdi, MAX_GLOBALS
    jae     .unsupported
    push    r10
        mov     r10, rdi
        imul    r10, GLOBAL_SIZE
    mov     [globals_buf + r10], r15b  ; value_type
        pop     r10
    ; Store ImportedGlobal
    push    r10
    mov     r10, r13
    imul    r10, IMPORTED_GLOBAL_SIZE
    mov     [imported_globals_buf + r10 + 16], rdi  ; global_index
    pop     r10
    inc     qword [global_count]
    inc     qword [imported_global_count]
    jmp     .import_next

.import_table:
    mov     byte [imported_table_present], 1
    movzx   eax, byte [rsi]
    inc     rsi
    cmp     al, WASM_FUNCREF_TYPE
    jne     .unsupported
    lea     rcx, [rsp - 16]
    er_call er_wasm_read_limits, .error
    mov     rax, [rsp - 16]      ; min
    mov     rbx, [rsp - 8]       ; max
    cmp     rax, MAX_TABLE_ENTRIES
    ja      .unsupported
    test    rbx, rbx
    jz      .table_ok
    cmp     rbx, MAX_TABLE_ENTRIES
    ja      .unsupported
.table_ok:
    mov     [imported_table_min], rax
    mov     [imported_table_max], rbx
    mov     byte [table_has], 1
    mov     [table_min], rax
    mov     [table_max], rbx
    jmp     .import_next

.import_next:
    inc     qword [import_count]
    inc     r13
    jmp     .import_loop

.done:
    mov     r12, rsi
    er_ok
    jmp     .out
.unsupported:
    er_err  ERROR_UNSUPPORTED
    jmp     .out
.corrupt:
    er_err  ERROR_CORRUPT
    jmp     .out
.error:
    mov     edx, edx
.out:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; Function section parser
; =================================================================+
er_wasm_parse_function_section:
    er_frame_push
    push    rbx
    push    r12

    mov     rsi, r12
    er_call er_wasm_read_leb_u32, .error
    mov     rbx, rax            ; rbx = count
    cmp     rbx, MAX_FUNCTIONS
    ja      .unsupported
    ; Check import_count + count <= MAX_FUNCTIONS
    mov     rax, [import_count]
    add     rax, rbx
    cmp     rax, MAX_FUNCTIONS
    ja      .unsupported
    mov     [function_count], rbx

    xor     r11d, r11d          ; index
.func_loop:
    cmp     r11, rbx
    jae     .done
    er_call er_wasm_read_leb_u32, .error
    ; Verify type_index < type_count
    cmp     rax, [type_count]
    jae     .corrupt
    ; Store Function { type_index, code_index = index }
    push    r10
    mov     r10, r11
    imul    r10, FUNCTION_SIZE
    mov     [functions_buf + r10], rax       ; type_index
    mov     [functions_buf + r10 + 8], r11   ; code_index
    pop     r10
    inc     r11
    jmp     .func_loop

.done:
    mov     r12, rsi
    er_ok
    jmp     .out
.corrupt:
    er_err  ERROR_CORRUPT
    jmp     .out
.unsupported:
    er_err  ERROR_UNSUPPORTED
    jmp     .out
.error:
    mov     edx, edx
.out:
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; Table section parser
; =================================================================+
er_wasm_parse_table_section:
    er_frame_push
    push    r12

    mov     rsi, r12
    er_call er_wasm_read_leb_u32, .error
    cmp     rax, 1
    ja      .unsupported
    test    rax, rax
    jz      .done               ; count == 0, nothing to parse

    cmp     byte [imported_table_present], 1
    je      .corrupt

    movzx   eax, byte [rsi]
    inc     rsi
    cmp     al, WASM_FUNCREF_TYPE
    jne     .unsupported

    lea     rcx, [rsp - 16]
    er_call er_wasm_read_limits, .error
    mov     rax, [rsp - 16]     ; min
    mov     rbx, [rsp - 8]      ; max
    cmp     rax, MAX_TABLE_ENTRIES
    ja      .unsupported
    test    rbx, rbx
    jz      .table_ok
    cmp     rbx, MAX_TABLE_ENTRIES
    ja      .unsupported
.table_ok:
    mov     byte [table_has], 1
    mov     [table_min], rax
    mov     [table_max], rbx

.done:
    mov     r12, rsi
    er_ok
    jmp     .out
.corrupt:
    er_err  ERROR_CORRUPT
    jmp     .out
.unsupported:
    er_err  ERROR_UNSUPPORTED
    jmp     .out
.error:
    mov     edx, edx
.out:
    pop     r12
    pop     rbp
    ret

; ==================================================================
; Memory section parser
; =================================================================+
er_wasm_parse_memory_section:
    er_frame_push

    mov     rsi, r12
    er_call er_wasm_read_leb_u32, .error
    cmp     rax, 1
    ja      .unsupported
    test    rax, rax
    jz      .done

    cmp     byte [imported_memory_present], 1
    je      .corrupt

    lea     rcx, [memory_min_pages]
    er_call er_wasm_read_limits, .error

.done:
    mov     r12, rsi
    er_ok
    jmp     .out
.corrupt:
    er_err  ERROR_CORRUPT
    jmp     .out
.unsupported:
    er_err  ERROR_UNSUPPORTED
    jmp     .out
.error:
    mov     edx, edx
.out:
    pop     rbp
    ret

; ==================================================================
; Export section parser
; =================================================================+
er_wasm_parse_export_section:
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     rsi, r12
    er_call er_wasm_read_leb_u32, .error
    mov     rbx, rax
    cmp     rbx, MAX_FUNCTIONS
    ja      .unsupported
    mov     [export_count], rbx

    xor     r14d, r14d
.export_loop:
    cmp     r14, rbx
    jae     .done

    ; Read name
    er_call er_wasm_read_leb_u32, .error
    mov     r13, rsi            ; save name start
    mov     r15, rax            ; save name length in r15
    add     rsi, rax            ; skip name

    ; Read kind
    movzx   r11d, byte [rsi]
    inc     rsi

    ; Read index
    er_call er_wasm_read_leb_u32, .error
    ; Store export
    push    r10
        mov     r10, r14
        imul    r10, EXPORT_SIZE
    mov     [exports_buf + r10], r13      ; name ptr
        pop     r10
    push    r10
        mov     r10, r14
        imul    r10, EXPORT_SIZE
    mov     [exports_buf + r10 + 8], r15   ; name length
        pop     r10
    push    r10
        mov     r10, r14
        imul    r10, EXPORT_SIZE
    mov     [exports_buf + r10 + 16], r11b ; kind
        pop     r10
    push    r10
        mov     r10, r14
        imul    r10, EXPORT_SIZE
    mov     [exports_buf + r10 + 24], rax  ; index
        pop     r10

    inc     r14
    jmp     .export_loop

.done:
    mov     r12, rsi
    er_ok
    jmp     .out
.unsupported:
    er_err  ERROR_UNSUPPORTED
    jmp     .out
.corrupt:
    er_err  ERROR_CORRUPT
    jmp     .out
.error:
    mov     edx, edx
.out:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; Start section parser
; =================================================================+
er_wasm_parse_start_section:
    er_frame_push

    mov     rsi, r12
    er_call er_wasm_read_leb_u32, .error
    mov     [start_function_index], rax
    mov     r12, rsi
    er_ok
    pop     rbp
    ret
.error:
    mov     edx, edx
    pop     rbp
    ret

; ==================================================================
; Data count section parser
; =================================================================+
er_wasm_parse_data_count_section:
    er_frame_push

    mov     rsi, r12
    er_call er_wasm_read_leb_u32, .error
    cmp     rax, MAX_DATA_SEGMENTS
    ja      .unsupported
    mov     [declared_data_count], rax
    mov     r12, rsi
    er_ok
    pop     rbp
    ret
.unsupported:
    er_err  ERROR_UNSUPPORTED
    pop     rbp
    ret
.error:
    mov     edx, edx
    pop     rbp
    ret

; ==================================================================
; Code section parser (most complex — also decodes ops)
; =================================================================+
er_wasm_parse_code_section:
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     rsi, r12
    er_call er_wasm_read_leb_u32, .error
    mov     rbx, rax            ; count
    cmp     rbx, [function_count]
    jne     .corrupt
    cmp     rbx, MAX_FUNCTIONS
    ja      .corrupt
    mov     [code_count], rbx

    xor     r14d, r14d          ; function index
.code_loop:
    cmp     r14, rbx
    jae     .done

    ; Read body size
    er_call er_wasm_read_leb_u32, .error
    mov     r15, rsi            ; r15 = body start
    add     r15, rax            ; r15 = body end (for bounds check)
    ; For now we use rsi as the reader into the body

    ; Read local group count
    er_call er_wasm_read_leb_u32, .error
    mov     r13, rax            ; local_group_count

    ; Store code entry: body_offset(8) + body_len(8) + local_count(8)
    push    r10
        mov     r10, r14
        imul    r10, CODE_SIZE
    mov     [code_buf + r10], rsi         ; body_offset (pointer into wasm bytes)
        pop     r10
    ; body_len = r15 - rsi (computed later after locals)
    push    r10
        mov     r10, r14
        imul    r10, CODE_SIZE
    mov     [code_buf + r10 + 16], r13    ; local_group_count (reuse field — will convert to local_count after processing)
        pop     r10

    ; Parse local groups
    xor     r11d, r11d          ; total local count
.local_group_loop:
    test    r13, r13
    jz      .locals_done
    dec     r13

    ; Read repeat count
    er_call er_wasm_read_leb_u32, .error
    mov     r12, rax            ; repeat count

    ; Read value type
    er_call er_wasm_read_value_type, .error
    mov     r9b, al             ; type byte

    ; Verify local_count + repeat <= MAX_LOCALS
    mov     rax, r11
    add     rax, r12
    cmp     rax, MAX_LOCALS
    ja      .unsupported

    ; Fill local_types
    mov     rdi, code_local_types
    imul    r10, r14, MAX_LOCALS
    add     rdi, r10
    xor     r10d, r10d
.repeat_loop:
    cmp     r10, r12
    jae     .repeat_done
    mov     [rdi + r11], r9b
    inc     r11
    inc     r10
    jmp     .repeat_loop
.repeat_done:
    jmp     .local_group_loop

.locals_done:
    ; Store local count
    push    r10
        mov     r10, r14
        imul    r10, CODE_SIZE
    mov     [code_buf + r10 + 16], r11    ; local_count
        pop     r10
    ; Store body end pointer - start = body length
    mov     rax, r15
    sub     rax, rsi
    push    r10
        mov     r10, r14
        imul    r10, CODE_SIZE
    mov     [code_buf + r10 + 8], rax     ; body_len
        pop     r10
    ; Store decoded_start = current decoded_op_count
    mov     rax, [decoded_op_count]
    push    r10
        mov     r10, r14
        imul    r10, CODE_SIZE
    mov     [code_buf + r10 + 24], rax    ; decoded_start
        pop     r10
    ; Decode the body
    push    r14
    push    r15
    mov     r12, rsi            ; body start for decoder
    ; We need the body bytes — already at rsi, length = r15 - rsi
    mov     rax, r15
    sub     rax, rsi
    mov     rdi, rsi            ; body ptr
    mov     rsi, rax            ; body len
    call    er_wasm_decode_body
    pop     r15
    pop     r14
    test    edx, edx
    jnz     .error
    ; Store decoded_count = decoded_op_count - decoded_start
    mov     rax, [decoded_op_count]
    push    r10
        mov     r10, r14
        imul    r10, CODE_SIZE
    sub     rax, [code_buf + r10 + 24]
        pop     r10
    push    r10
        mov     r10, r14
        imul    r10, CODE_SIZE
    mov     [code_buf + r10 + 32], rax  ; decoded_count
        pop     r10
    mov     rsi, r15
    inc     r14
    jmp     .code_loop

.done:
    mov     r12, rsi
    er_ok
    jmp     .out
.corrupt:
    er_err  ERROR_CORRUPT
    jmp     .out
.unsupported:
    er_err  ERROR_UNSUPPORTED
    jmp     .out
.error:
    mov     edx, edx
.out:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; Global section parser
; =================================================================+
er_wasm_parse_global_section:
    er_frame_push
    push    rbx
    push    r12
    push    r13

    mov     rsi, r12
    er_call er_wasm_read_leb_u32, .error
    mov     rbx, rax
    mov     rax, [global_count]
    add     rax, rbx
    cmp     rax, MAX_GLOBALS
    ja      .unsupported

    xor     r13d, r13d
.global_loop:
    cmp     r13, rbx
    jae     .done

    ; Read value type
    er_call er_wasm_read_value_type, .error
    push    rax                 ; save value_type

    ; Read mutability
    movzx   r11d, byte [rsi]
    inc     rsi
    cmp     r11b, 1
    ja      .corrupt

    ; Read constant expression
    pop     rdi                 ; value_type for read_constant
    er_call er_wasm_read_constant_value, .error

    ; Store global
    mov     rdi, [global_count]
    push    r10
        mov     r10, rdi
        imul    r10, GLOBAL_SIZE
    mov     [globals_buf + r10], al      ; value_type (from read_value_type — need to save properly)
        pop     r10
    push    r10
        mov     r10, rdi
        imul    r10, GLOBAL_SIZE
    mov     [globals_buf + r10 + 1], r11b ; mutable
        pop     r10
    ; value stored in rax
    push    r10
        mov     r10, rdi
        imul    r10, GLOBAL_SIZE
    mov     [globals_buf + r10 + 8], rax  ; value_data
        pop     r10
    inc     qword [global_count]
    inc     r13
    jmp     .global_loop

.done:
    mov     r12, rsi
    er_ok
    jmp     .out
.corrupt:
    er_err  ERROR_CORRUPT
    jmp     .out
.unsupported:
    er_err  ERROR_UNSUPPORTED
    jmp     .out
.error:
    mov     edx, edx
.out:
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; Helper: er_wasm_read_constant_value
; Reads a constant value expression from [rsi] for the given value_type (in rdi).
; Returns value in rax.
; =================================================================+
er_wasm_read_constant_value:
    er_frame_push
    push    rbx

    movzx   eax, byte [rsi]
    inc     rsi
    mov     rbx, rax            ; opcode

    cmp     dil, VALUE_TAG_I32
    je      .read_i32
    cmp     dil, VALUE_TAG_I64
    je      .read_i64
    cmp     dil, VALUE_TAG_F32
    je      .read_f32
    cmp     dil, VALUE_TAG_F64
    je      .read_f64
    cmp     dil, VALUE_TAG_FUNCREF
    je      .read_funcref
    jmp     .unsupported

.read_i32:
    cmp     bl, 0x41            ; i32.const
    jne     .unsupported
    er_call er_wasm_read_leb_i32, .error
    push    rax
    jmp     .check_end
.read_i64:
    cmp     bl, 0x42            ; i64.const
    jne     .unsupported
    er_call er_wasm_read_leb_i64, .error
    push    rax
    jmp     .check_end
.read_f32:
    cmp     bl, 0x43            ; f32.const
    jne     .unsupported
    mov     eax, [rsi]
    add     rsi, 4
    push    rax
    jmp     .check_end
.read_f64:
    cmp     bl, 0x44            ; f64.const
    jne     .unsupported
    mov     rax, [rsi]
    add     rsi, 8
    push    rax
    jmp     .check_end
.read_funcref:
    cmp     bl, 0xd0            ; ref.null
    je      .ref_null
    cmp     bl, 0xd2            ; ref.func
    je      .ref_func
    jmp     .unsupported
.ref_null:
    movzx   eax, byte [rsi]
    inc     rsi
    cmp     al, WASM_FUNCREF_TYPE
    jne     .unsupported
    push    0                   ; null = 0
    jmp     .check_end
.ref_func:
    er_call er_wasm_read_leb_u32, .error
    push    rax
    jmp     .check_end

.check_end:
    movzx   eax, byte [rsi]
    inc     rsi
    cmp     al, 0x0b            ; end
    jne     .unsupported
    pop     rax
    er_ok
    jmp     .done

.unsupported:
    er_err  ERROR_UNSUPPORTED
    pop     rbx
    pop     rbp
    ret
.error:
    mov     edx, edx
.done:
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; Element section parser (stub for now — full implementation)
; =================================================================+
er_wasm_parse_element_section:
    ; TODO: full element section parsing
    er_frame_push
    mov     rsi, r12
    er_call er_wasm_read_leb_u32, .error
    mov     r12, rsi            ; skip for now
    er_ok
    pop     rbp
    ret
.error:
    mov     edx, edx
    pop     rbp
    ret

; ==================================================================
; Data section parser
; =================================================================+
er_wasm_parse_data_section:
    er_frame_push
    push    r12

    mov     rsi, r12
    er_call er_wasm_read_leb_u32, .error
    mov     r12, rax
    cmp     r12, MAX_DATA_SEGMENTS
    ja      .unsupported
    mov     [data_segment_count], r12

    xor     r11d, r11d
.data_loop:
    cmp     r11, r12
    jae     .done

    ; Read mode
    er_call er_wasm_read_leb_u32, .error
    cmp     eax, 0
    je      .active_0
    cmp     eax, 1
    je      .passive
    cmp     eax, 2
    je      .active_2
    jmp     .unsupported

.active_0:
    ; mode 0: active, memory 0 implicit
    er_call er_wasm_read_constant_i32, .error
    push    rax                 ; offset
    er_call er_wasm_read_leb_u32, .error
    mov     rcx, rax            ; byte count
    pop     rdx                 ; offset
    ; Store DataSegment
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    mov     [data_segments + r10], rdx     ; offset
        pop     r10
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    mov     [data_segments + r10 + 8], rsi ; bytes ptr
        pop     r10
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    mov     [data_segments + r10 + 16], rcx ; bytes len
        pop     r10
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    mov     byte [data_segments + r10 + 24], 1  ; active
        pop     r10
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    mov     byte [data_segments + r10 + 25], 0  ; not dropped
        pop     r10
    add     rsi, rcx
    jmp     .next

.passive:
    er_call er_wasm_read_leb_u32, .error
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    mov     [data_segments + r10 + 8], rsi  ; bytes ptr
        pop     r10
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    mov     [data_segments + r10 + 16], rax ; bytes len
        pop     r10
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    mov     byte [data_segments + r10 + 24], 0  ; not active
        pop     r10
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    mov     byte [data_segments + r10 + 25], 0
        pop     r10
    add     rsi, rax
    jmp     .next

.active_2:
    ; mode 2: active with explicit memory index
    call    er_wasm_read_leb_u32  ; read and ignore memory index (must be 0)
    test    edx, edx
    jnz     .error
    test    eax, eax
    jnz     .unsupported
    er_call er_wasm_read_constant_i32, .error
    push    rax                 ; offset
    er_call er_wasm_read_leb_u32, .error
    mov     rcx, rax
    pop     rdx
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    mov     [data_segments + r10], rdx
        pop     r10
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    mov     [data_segments + r10 + 8], rsi
        pop     r10
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    mov     [data_segments + r10 + 16], rcx
        pop     r10
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    mov     byte [data_segments + r10 + 24], 1
        pop     r10
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    mov     byte [data_segments + r10 + 25], 0
        pop     r10
    add     rsi, rcx
    jmp     .next

.next:
    inc     r11
    jmp     .data_loop

.done:
    mov     r12, rsi
    er_ok
    jmp     .out
.unsupported:
    er_err  ERROR_UNSUPPORTED
    jmp     .out
.error:
    mov     edx, edx
.out:
    pop     r12
    pop     rbp
    ret

; ==================================================================
; Decoded op cache
; er_wasm_decode_body(bytes_ptr=rdi, bytes_len=rsi)
; Decodes opcodes from a function body, populates decoded_ops[]
; =================================================================+
er_wasm_decode_body:
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi            ; body start
    mov     r13, rdi
    add     r13, rsi            ; body end
    mov     rsi, rdi            ; rsi = bytecode reader (start at body ptr)
    mov     r14, [decoded_op_count]  ; start index

.decode_loop:
    cmp     rsi, r13
    jae     .done

    mov     r15d, [decoded_op_count]
    cmp     r15d, MAX_DECODED_OPS
    jae     .unsupported

    ; Calculate offset from body start
    mov     rax, rsi
    sub     rax, rdi
    mov     edx, eax            ; offset (low 32 bits)

    ; Read opcode byte
    movzx   r11d, byte [rsi]
    inc     rsi

    ; Store decoded op header
    mov     ebx, r15d
    imul    ebx, DECODED_OP_SIZE
    mov     [decoded_ops + rbx], edx      ; offset
    mov     [decoded_ops + rbx + 8], r11b ; opcode_byte

    ; Handle extended prefix
    cmp     r11b, WASM_EXTENDED_PREFIX
    je      .decode_extended

    ; Decode immediate fields based on opcode
    cmp     r11b, 0x02          ; block
    je      .decode_block_type
    cmp     r11b, 0x03          ; loop
    je      .decode_block_type
    cmp     r11b, 0x04          ; if
    je      .decode_block_type
    cmp     r11b, 0x0c          ; br
    je      .decode_leb
    cmp     r11b, 0x0d          ; br_if
    je      .decode_leb
    cmp     r11b, 0x10          ; call
    je      .decode_leb
    cmp     r11b, 0x20          ; local.get
    je      .decode_leb
    cmp     r11b, 0x21          ; local.set
    je      .decode_leb
    cmp     r11b, 0x22          ; local.tee
    je      .decode_leb
    cmp     r11b, 0x23          ; global.get
    je      .decode_leb
    cmp     r11b, 0x24          ; global.set
    je      .decode_leb
    cmp     r11b, 0x25          ; table.get
    je      .decode_table
    cmp     r11b, 0x26          ; table.set
    je      .decode_table
    cmp     r11b, 0x28          ; i32.load
    je      .decode_mem
    cmp     r11b, 0x29          ; i64.load
    je      .decode_mem
    cmp     r11b, 0x2a          ; f32.load
    je      .decode_mem
    cmp     r11b, 0x2b          ; f64.load
    je      .decode_mem
    cmp     r11b, 0x2c          ; i32.load8_s
    je      .decode_mem
    cmp     r11b, 0x2d          ; i32.load8_u
    je      .decode_mem
    cmp     r11b, 0x2e          ; i32.load16_s
    je      .decode_mem
    cmp     r11b, 0x2f          ; i32.load16_u
    je      .decode_mem
    cmp     r11b, 0x30          ; i64.load8_s
    je      .decode_mem
    cmp     r11b, 0x31          ; i64.load8_u
    je      .decode_mem
    cmp     r11b, 0x32          ; i64.load16_s
    je      .decode_mem
    cmp     r11b, 0x33          ; i64.load16_u
    je      .decode_mem
    cmp     r11b, 0x34          ; i64.load32_s
    je      .decode_mem
    cmp     r11b, 0x35          ; i64.load32_u
    je      .decode_mem
    cmp     r11b, 0x36          ; i32.store
    je      .decode_mem
    cmp     r11b, 0x37          ; i64.store
    je      .decode_mem
    cmp     r11b, 0x38          ; f32.store
    je      .decode_mem
    cmp     r11b, 0x39          ; f64.store
    je      .decode_mem
    cmp     r11b, 0x3a          ; i32.store8
    je      .decode_mem
    cmp     r11b, 0x3b          ; i32.store16
    je      .decode_mem
    cmp     r11b, 0x3c          ; i64.store8
    je      .decode_mem
    cmp     r11b, 0x3d          ; i64.store16
    je      .decode_mem
    cmp     r11b, 0x3e          ; i64.store32
    je      .decode_mem
    cmp     r11b, 0x3f          ; memory.size
    je      .decode_memidx
    cmp     r11b, 0x40          ; memory.grow
    je      .decode_memidx
    cmp     r11b, 0x41          ; i32.const
    je      .decode_i32_const
    cmp     r11b, 0x42          ; i64.const
    je      .decode_i64_const
    cmp     r11b, 0x43          ; f32.const
    je      .decode_f32_const
    cmp     r11b, 0x44          ; f64.const
    je      .decode_f64_const
    cmp     r11b, 0x11          ; call_indirect
    je      .decode_call_indirect
    cmp     r11b, 0x1c          ; select_typed
    je      .decode_select_typed
    cmp     r11b, 0xd0          ; ref.null
    je      .decode_ref_null
    cmp     r11b, 0xd2          ; ref.func
    je      .decode_leb
    cmp     r11b, 0x0e          ; br_table
    je      .decode_br_table

    ; Store next_offset for opcodes with no immediates
    mov     eax, esi
    sub     eax, edi            ; relative to body start
    mov     [decoded_ops + rbx + 4], eax  ; next_offset

    inc     dword [decoded_op_count]
    jmp     .decode_loop

    ; --- decode immediate handlers ---
.decode_leb:
    ; Read single LEB128 u32 into imm0
    er_call er_wasm_read_leb_u32, .error
    mov     [decoded_ops + rbx + 12], eax  ; imm0
    mov     eax, esi
    sub     eax, edi
    mov     [decoded_ops + rbx + 4], eax   ; next_offset
    inc     dword [decoded_op_count]
    jmp     .decode_loop

.decode_mem:
    ; Read alignment + offset (two LEB128 u32s)
    er_call er_wasm_read_leb_u32, .error
    mov     [decoded_ops + rbx + 12], eax  ; imm0 = alignment
    er_call er_wasm_read_leb_u32, .error
    mov     [decoded_ops + rbx + 16], eax  ; imm1 = offset
    mov     eax, esi
    sub     eax, edi
    mov     [decoded_ops + rbx + 4], eax   ; next_offset
    inc     dword [decoded_op_count]
    jmp     .decode_loop

.decode_memidx:
    ; Read memory index (must be 0)
    er_call er_wasm_read_leb_u32, .error
    test    eax, eax
    jnz     .unsupported
    mov     eax, esi
    sub     eax, edi
    mov     [decoded_ops + rbx + 4], eax
    inc     dword [decoded_op_count]
    jmp     .decode_loop

.decode_i32_const:
    er_call er_wasm_read_leb_i32, .error
    mov     [decoded_ops + rbx + 12], eax  ; imm0 = value (as bit pattern)
    mov     eax, esi
    sub     eax, edi
    mov     [decoded_ops + rbx + 4], eax
    inc     dword [decoded_op_count]
    jmp     .decode_loop

.decode_i64_const:
    er_call er_wasm_read_leb_i64, .error
    mov     eax, esi
    sub     eax, edi
    mov     [decoded_ops + rbx + 4], eax
    inc     dword [decoded_op_count]
    jmp     .decode_loop

.decode_f32_const:
    mov     eax, [rsi]
    add     rsi, 4
    mov     [decoded_ops + rbx + 12], eax  ; imm0 = f32 bits
    mov     eax, esi
    sub     eax, edi
    mov     [decoded_ops + rbx + 4], eax
    inc     dword [decoded_op_count]
    jmp     .decode_loop

.decode_f64_const:
    mov     eax, esi
    add     rsi, 8
    mov     eax, esi
    sub     eax, edi
    mov     [decoded_ops + rbx + 4], eax
    inc     dword [decoded_op_count]
    jmp     .decode_loop

.decode_block_type:
    ; Read block type (1 byte or LEB128 type index)
    movzx   eax, byte [rsi]
    inc     rsi
    cmp     al, WASM_EMPTY_BLOCK_TYPE
    je      .block_done
    ; Check if it's a value type
    cmp     al, VALUE_TAG_I32
    je      .block_done
    cmp     al, VALUE_TAG_I64
    je      .block_done
    cmp     al, VALUE_TAG_F32
    je      .block_done
    cmp     al, VALUE_TAG_F64
    je      .block_done
    cmp     al, VALUE_TAG_FUNCREF
    je      .block_done
    ; It's a type index (LEB128 starting with this byte)
    ; Continue reading as LEB128
    dec     rsi                 ; put back the byte
    er_call er_wasm_read_leb_u32, .error
.block_done:
    mov     eax, esi
    sub     eax, edi
    mov     [decoded_ops + rbx + 4], eax
    inc     dword [decoded_op_count]
    jmp     .decode_loop

.decode_call_indirect:
    er_call er_wasm_read_leb_u32, .error
    mov     [decoded_ops + rbx + 12], eax  ; imm0 = type_index
    er_call er_wasm_read_leb_u32, .error
    mov     [decoded_ops + rbx + 16], eax  ; imm1 = table_index
    mov     eax, esi
    sub     eax, edi
    mov     [decoded_ops + rbx + 4], eax
    inc     dword [decoded_op_count]
    jmp     .decode_loop

.decode_select_typed:
    call    er_wasm_read_leb_u32  ; type count
    test    edx, edx
    jnz     .error
    cmp     eax, 1
    jne     .unsupported
    er_call er_wasm_read_value_type, .error
    mov     eax, esi
    sub     eax, edi
    mov     [decoded_ops + rbx + 4], eax
    inc     dword [decoded_op_count]
    jmp     .decode_loop

.decode_table:
    call    er_wasm_read_leb_u32  ; table index
    test    edx, edx
    jnz     .error
    mov     [decoded_ops + rbx + 12], eax
    mov     eax, esi
    sub     eax, edi
    mov     [decoded_ops + rbx + 4], eax
    inc     dword [decoded_op_count]
    jmp     .decode_loop

.decode_ref_null:
    movzx   eax, byte [rsi]
    inc     rsi
    cmp     al, WASM_FUNCREF_TYPE
    jne     .unsupported
    mov     eax, esi
    sub     eax, edi
    mov     [decoded_ops + rbx + 4], eax
    inc     dword [decoded_op_count]
    jmp     .decode_loop

.decode_br_table:
    er_call er_wasm_read_leb_u32, .error
    mov     r11d, eax           ; target count
    xor     r10d, r10d
.br_table_loop:
    cmp     r10, r11
    jae     .br_table_done
    er_call er_wasm_read_leb_u32, .error
    inc     r10
    jmp     .br_table_loop
.br_table_done:
    call    er_wasm_read_leb_u32  ; default target
    test    edx, edx
    jnz     .error
    mov     eax, esi
    sub     eax, edi
    mov     [decoded_ops + rbx + 4], eax
    inc     dword [decoded_op_count]
    jmp     .decode_loop

.decode_extended:
    ; Read extended opcode
    er_call er_wasm_read_leb_u32, .error
    mov     [decoded_ops + rbx + 12], eax  ; imm0 = extended opcode
    ; Skip immediate fields based on extended opcode
    cmp     eax, EXT_MEMORY_INIT
    je      .ext_mem_init
    cmp     eax, EXT_DATA_DROP
    je      .ext_data_drop
    cmp     eax, EXT_MEMORY_COPY
    je      .ext_mem_copy
    cmp     eax, EXT_MEMORY_FILL
    je      .ext_mem_fill
    cmp     eax, EXT_TABLE_INIT
    je      .ext_table_init
    cmp     eax, EXT_ELEM_DROP
    je      .ext_elem_drop
    cmp     eax, EXT_TABLE_COPY
    je      .ext_table_copy
    cmp     eax, EXT_TABLE_GROW
    je      .ext_table_grow
    cmp     eax, EXT_TABLE_SIZE
    je      .ext_table_size
    cmp     eax, EXT_TABLE_FILL
    je      .ext_table_fill
    ; trunc_sat variants have no immediates
    jmp     .ext_done

.ext_mem_init:
    call    er_wasm_read_leb_u32  ; data segment index
    test    edx, edx
    jnz     .error
    call    er_wasm_read_leb_u32  ; memory index (must be 0)
    test    edx, edx
    jnz     .error
    jmp     .ext_done
.ext_data_drop:
    call    er_wasm_read_leb_u32  ; data segment index
    test    edx, edx
    jnz     .error
    jmp     .ext_done
.ext_mem_copy:
    call    er_wasm_read_leb_u32  ; memory index (dst)
    test    edx, edx
    jnz     .error
    call    er_wasm_read_leb_u32  ; memory index (src)
    test    edx, edx
    jnz     .error
    jmp     .ext_done
.ext_mem_fill:
    call    er_wasm_read_leb_u32  ; memory index
    test    edx, edx
    jnz     .error
    jmp     .ext_done
.ext_table_init:
    call    er_wasm_read_leb_u32  ; element segment index
    test    edx, edx
    jnz     .error
    call    er_wasm_read_leb_u32  ; table index
    test    edx, edx
    jnz     .error
    jmp     .ext_done
.ext_elem_drop:
    call    er_wasm_read_leb_u32  ; element segment index
    test    edx, edx
    jnz     .error
    jmp     .ext_done
.ext_table_copy:
    call    er_wasm_read_leb_u32  ; table index (dst)
    test    edx, edx
    jnz     .error
    call    er_wasm_read_leb_u32  ; table index (src)
    test    edx, edx
    jnz     .error
    jmp     .ext_done
.ext_table_grow:
    call    er_wasm_read_leb_u32  ; table index
    test    edx, edx
    jnz     .error
    jmp     .ext_done
.ext_table_size:
    call    er_wasm_read_leb_u32  ; table index
    test    edx, edx
    jnz     .error
    jmp     .ext_done
.ext_table_fill:
    call    er_wasm_read_leb_u32  ; table index
    test    edx, edx
    jnz     .error
    jmp     .ext_done
.ext_done:
    mov     eax, esi
    sub     eax, edi
    mov     [decoded_ops + rbx + 4], eax
    inc     dword [decoded_op_count]
    jmp     .decode_loop

.done:
    er_ok
    jmp     .out
.unsupported:
    er_err  ERROR_UNSUPPORTED
    mov     eax, edx
    jmp     .out
.error:
    mov     eax, edx
.out:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; Missing BSS variables referenced by parsers
; =================================================================+
SECTION .bss
debug_section_id:  resb 1
debug_check:       resq 4
memory_min_pages:  resq 1
memory_max_pages:  resq 1
has_memory:        resb 1
start_function_index: resq 1

SECTION .text

; ==================================================================
; Apply data segments — copy data segment bytes into runtime memory
; er_wasm_apply_data_segments(memory_ptr=rdi, memory_pages=rsi)
; =================================================================+
er_wasm_apply_data_segments:
    er_frame_push
    push    rbx
    push    r12
    push    r13

    mov     r12, rdi            ; memory_ptr
    ; Convert pages to bytes
    mov     rdi, rsi
    er_call er_wasm_pages_to_bytes, .error
    mov     r13, rax            ; memory limit in bytes

    xor     r11d, r11d          ; segment index
.seg_loop:
    cmp     r11, [data_segment_count]
    jae     .done

    ; Check if active
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    cmp     byte [data_segments + r10 + 24], 0  ; active flag
        pop     r10
    je      .next

    ; offset + bytes_len <= limit?
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    mov     rdx, [data_segments + r10]       ; offset
        pop     r10
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    mov     rcx, [data_segments + r10 + 16]  ; byte count
        pop     r10
    mov     rax, rdx
    add     rax, rcx
    jc      .nomemory
    cmp     rax, r13
    ja      .nomemory
    cmp     rax, [runtime_memory_len]
    ja      .nomemory

    ; Copy bytes: memcpy(memory + offset, segment_bytes, count)
    mov     rdi, r12
    add     rdi, rdx
    push    r10
        mov     r10, r11
        imul    r10, DATA_SEGMENT_SIZE
    mov     rsi, [data_segments + r10 + 8]  ; bytes ptr
        pop     r10
    mov     rdx, rcx
    call    er_memcpy

.next:
    inc     r11
    jmp     .seg_loop

.done:
    er_ok
    jmp     .out
.nomemory:
    er_err  ERROR_NO_MEMORY
    jmp     .out
.error:
    ; rdx already has error from called function — pass through
.out:
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; Find export by name
; er_wasm_find_export(name_ptr=rdi, name_len=rsi)
; Returns export index in rax, or error in rdx
; =================================================================+
er_wasm_find_export:
    er_frame_push
    push    rbx
    push    r12
    push    r13

    mov     r12, rdi            ; name ptr
    mov     r13, rsi            ; name len

    xor     r11d, r11d
.search_loop:
    cmp     r11, [export_count]
    jae     .not_found

    push    r11
    ; Compare export name
    push    r10
        mov     r10, r11
        imul    r10, EXPORT_SIZE
    mov     rdi, [exports_buf + r10]  ; name ptr
        pop     r10
    push    r10
        mov     r10, r11
        imul    r10, EXPORT_SIZE
    mov     rsi, [exports_buf + r10 + 8]  ; name len (need to save this)
        pop     r10
    ; TODO: proper name length storage
    ; For now, compare using the name in the exports buf
    mov     rdx, r12
    mov     rcx, r13
    call    er_wasm_eql
    pop     r11
    test    rax, rax
    jnz     .found

    inc     r11
    jmp     .search_loop

.found:
    mov     rax, r11
    er_ok
    jmp     .done
.not_found:
    er_err  ERROR_MISSING_EXPORT
    xor     eax, eax
.done:
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; Type index for function
; er_wasm_type_index_for_function(function_index=rdi)
; Returns type_index in rax, error in rdx
; =================================================================+
er_wasm_type_index_for_function:
    er_frame_push

    ; Check if imported function
    mov     rsi, [import_count]
    cmp     rdi, rsi
    jae     .defined

    ; Imported: return imports[function_index].type_index
    push    r10
        mov     r10, rdi
        imul    r10, IMPORTED_FUNC_SIZE
    mov     rax, [imports_buf + r10 + 32]  ; type_index
        pop     r10
    er_ok
    pop     rbp
    ret

.defined:
    ; Defined function
    sub     rdi, rsi            ; subtract import count
    cmp     rdi, [function_count]
    jae     .corrupt
    push    r10
    mov     r10, rdi
    imul    r10, FUNCTION_SIZE
    mov     rax, [functions_buf + r10]  ; type_index
    pop     r10
    er_ok
    pop     rbp
    ret

.corrupt:
    er_err  ERROR_CORRUPT
    xor     eax, eax
    pop     rbp
    ret

; ==================================================================
; Code index for function  
; er_wasm_code_index_for_function(function_index=rdi)
; Returns code_index in rax, error in rdx
; =================================================================+
er_wasm_code_index_for_function:
    er_frame_push

    mov     rsi, [import_count]
    cmp     rdi, rsi
    jb      .missing_import

    sub     rdi, rsi
    cmp     rdi, [function_count]
    jae     .corrupt

    push    r10
    mov     r10, rdi
    imul    r10, FUNCTION_SIZE
    mov     rax, [functions_buf + r10 + 8]  ; code_index
    pop     r10
    er_ok
    pop     rbp
    ret

.missing_import:
    er_err  ERROR_MISSING_IMPORT
    xor     eax, eax
    pop     rbp
    ret
.corrupt:
    er_err  ERROR_CORRUPT
    xor     eax, eax
    pop     rbp
    ret

; ==================================================================
; Frame (per-function-call state) operations
; The Frame is stored in a dedicated BSS area since only one call
; is active at a time (we don't need the full call depth — we use
; a call stack area for that)
; =================================================================+

; -- Frame state (current invocation)

; ==================================================================
; Pop value from frame stack
; Returns value in rax
; =================================================================+
