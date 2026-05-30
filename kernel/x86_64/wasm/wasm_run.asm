; ==================================================================
; er_fn_run: Top-level entry point
; rdi = runtime_ptr (pointer to RuntimeConfig struct)
; rsi = wasm_bytes_ptr
; rdx = wasm_bytes_len
; rcx = export_name_ptr
; r8  = export_name_len
; Returns: rax = result value, rdx = error code
; =================================================================+
er_fn er_fn_run
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    push    r8              ; save export_name_len

    mov     r12, rdi        ; runtime_ptr
    mov     r13, rsi        ; wasm_bytes
    mov     r14, rdx        ; wasm_len
    mov     r15, rcx        ; export_name

    ; Initialize runtime context
    mov     rdi, [r12 + RUNTIME_MEMORY_PTR_OFF]
    mov     rsi, [r12 + RUNTIME_MEMORY_LEN_OFF]
    mov     rdx, [r12 + RUNTIME_TICKS_PTR_OFF]
    call    er_fn_init

    ; Store grow function pointers if present
    mov     rax, [r12 + RUNTIME_MEM_GROW_FN_OFF]
    mov     [runtime_memory_grow_fn], rax
    mov     rax, [r12 + RUNTIME_MEM_GROW_CTX_OFF]
    mov     [runtime_memory_grow_ctx], rax
    mov     rax, [r12 + RUNTIME_TABLE_GROW_FN_OFF]
    mov     [runtime_table_grow_fn], rax
    mov     rax, [r12 + RUNTIME_TABLE_GROW_CTX_OFF]
    mov     [runtime_table_grow_ctx], rax
    mov     rax, [r12 + RUNTIME_INITIAL_PAGES_OFF]
    mov     [runtime_initial_pages], rax
    movzx   eax, byte [r12 + RUNTIME_HAS_PAGES_OFF]
    mov     [runtime_has_initial_pages], al

    ; Store host imports table
    mov     rax, [r12 + RUNTIME_IMPORTS_PTR_OFF]
    mov     [runtime_imports_ptr], rax
    mov     rax, [r12 + RUNTIME_IMPORTS_LEN_OFF]
    mov     [runtime_imports_len], rax

    ; Reset parser state
    mov     byte [exec_storage_module_valid], 0
    mov     byte [exec_storage_start_ran], 0
    mov     qword [exec_frame_save_ptr], 0
    mov     qword [exec_call_depth], 0
    ; Clear JIT table — per-module entries become stale on re-run
    cld
    lea     rdi, [rel jit_table]
    xor     eax, eax
    mov     ecx, MAX_FUNCTIONS
    rep stosq

    ; Parse module
    mov     rdi, r13
    mov     rsi, r14
    call    er_wasm_parse_module
    test    rdx, rdx
    jnz     .error

    ; Resolve imports against host-provided table
    call    er_wasm_resolve_imports
    test    rdx, rdx
    jnz     .error

    mov     byte [exec_storage_module_valid], 1

    ; Determine initial memory pages
    cmp     byte [runtime_has_initial_pages], 0
    je      .use_module_memory_pages
    mov     rax, [runtime_initial_pages]
    jmp     .set_memory_pages
.use_module_memory_pages:
    mov     rax, [memory_min_pages]
.set_memory_pages:
    mov     [executor_memory_pages], rax
    ; Calculate memory limit: pages * 65536
    shl     rax, WASM_PAGE_SHIFT
    mov     [executor_memory_limit], rax

    ; Run start function if present
    cmp     byte [exec_storage_start_ran], 0
    jne     .skip_start

    cmp     qword [start_function_index], -1
    je      .no_start

    mov     rdi, [start_function_index]
    xor     rsi, rsi
    xor     rdx, rdx
    call    er_fn_exec
    test    rdx, rdx
    jnz     .error
    ; Check that start function returned no results
    cmp     qword [exec_result_count], 0
    jne     .corrupt_error_label

.no_start:
    mov     byte [exec_storage_start_ran], 1

.skip_start:
    ; Find the export
    mov     rdi, r15
    mov     rsi, [rbp - 48]
    call    er_wasm_find_export
    test    rdx, rdx
    jnz     .error

    ; er_wasm_find_export returns the export entry index.
    ; We must look up the actual function index from the export entry.
    mov     r15, rax        ; export_index
    push    r10
    mov     r10, r15
    imul    r10, EXPORT_SIZE
    movzx   eax, byte [exports_buf + r10 + 16]  ; kind
    cmp     al, 0x00        ; function kind
    jne     .error          ; not a function export
    mov     r15, [exports_buf + r10 + 24]   ; function index
    pop     r10

    ; Apply data segments
    mov     rdi, [runtime_memory_ptr]
    mov     rsi, [executor_memory_pages]
    call    er_wasm_apply_data_segments

    ; Execute exported function
    mov     rdi, r15
    xor     rsi, rsi        ; no args for now
    xor     rdx, rdx
    call    er_fn_exec
    test    rdx, rdx
    jnz     .error

    ; Return result
    mov     rax, [exec_result_values]
    mov     rdx, [exec_result_count]
    jmp     .done

.corrupt_error_label:
    er_err  ERROR_CORRUPT
.error:
    mov     rax, -1
.done:
    pop     r8              ; restore export_name_len
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; Initialize the runtime context
; er_fn_init(memory_ptr=rdi, memory_len=rsi, ticks_ptr=rdx)
; =================================================================+
er_fn er_fn_init
    er_frame_push

    mov     [runtime_memory_ptr], rdi
    mov     [runtime_memory_len], rsi
    mov     [runtime_ticks_ptr], rdx
    mov     qword [runtime_imports_ptr], 0
    mov     qword [runtime_imports_len], 0
    mov     byte [runtime_has_initial_pages], 0

    xor     eax, eax
    pop     rbp
    ret

; ==================================================================
; Resolve all imports against host-provided import table
; For each import in imports_buf, scans runtime_imports for a match
; by module name and function name.
; Sets resolved_func_index (offset 48) to the host import index.
; Returns: rdx = 0 on success, ERROR_MISSING_IMPORT on failure
; =================================================================+
er_wasm_resolve_imports:
    er_frame_push
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    xor     r12d, r12d
    mov     r13, [import_count]
    mov     r14, [runtime_imports_len]

    test    r13, r13
    jz      .done_ok

    cmp     qword [runtime_imports_ptr], 0
    je      .not_found_all

    test    r14, r14
    jz      .not_found_all

.loop:
    cmp     r12, r13
    jae     .done_ok

    mov     rbx, r12
    imul    rbx, IMPORTED_FUNC_SIZE

    xor     r15d, r15d
.scan:
    cmp     r15, r14
    jae     .not_found

    ; Compare module name
    ; er_wasm_eql(rdi=ptr1, rsi=len1, rdx=ptr2, rcx=len2)
    mov     rax, r15
    imul    rax, HOST_IMPORT_SIZE
    add     rax, [runtime_imports_ptr]
    mov     rdi, [rax + HOST_IMPORT_MODULE_PTR_OFF]
    mov     rsi, [rax + HOST_IMPORT_MODULE_LEN_OFF]
    mov     rdx, [imports_buf + rbx + IMPORT_MODULE_NAME_PTR_OFF]
    mov     rcx, [imports_buf + rbx + IMPORT_MODULE_NAME_LEN_OFF]
    call    er_wasm_eql
    test    eax, eax
    jz      .scan_next

    ; Module name matches — compare function name
    mov     rax, r15
    imul    rax, HOST_IMPORT_SIZE
    add     rax, [runtime_imports_ptr]
    mov     rdi, [rax + HOST_IMPORT_NAME_PTR_OFF]
    mov     rsi, [rax + HOST_IMPORT_NAME_LEN_OFF]
    mov     rdx, [imports_buf + rbx + IMPORT_FUNC_NAME_PTR_OFF]
    mov     rcx, [imports_buf + rbx + IMPORT_FUNC_NAME_LEN_OFF]
    call    er_wasm_eql
    test    eax, eax
    jz      .scan_next

    ; Both names match — store resolved index
    mov     [imports_buf + rbx + IMPORT_RESOLVED_FUNC_IDX_OFF], r15
    inc     r12
    jmp     .loop

.scan_next:
    inc     r15
    jmp     .scan

.not_found:
.not_found_all:
    er_err  ERROR_MISSING_IMPORT
    jmp     .done

.done_ok:
    xor     edx, edx
.done:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret
