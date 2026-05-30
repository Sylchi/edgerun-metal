; ==================================================================
; EdgeRun WASM Compiler — x86_64 assembly implementation
; Ported from edgerun-zig/compiler/zig/src/edgerun_wasm_compiler.zig
;
; C ABI (System V AMD64):
;   arg1=rdi, arg2=rsi, arg3=rdx, arg4=rcx, arg5=r8, arg6=r9
;   return=rax, error=rdx
;
; Split into:
;   wasm_compiler_helpers.asm — writer/read helpers, hashing, parsing
;   wasm_compiler_char.asm   — character classification and scanning
;   wasm_compiler_emit.asm   — WASM section emission + export strings
;   wasm_compiler.asm        — BSS, rodata, diagnostics, pipeline, API
; ==================================================================

%include "x86_64/macros.inc"
%include "x86_64/wasm/wasm_compiler.inc"

; Extern from source parser
extern source_parse
extern export_name_count, export_name_ptrs, export_name_lens
extern body_lens, body_buf_pos

; Extern from wasm_compiler_helpers.asm
extern writer_append_slice

; Extern from wasm_compiler_emit.asm
extern emit_types_section, emit_function_section, emit_memory_section
extern emit_base_exports, emit_start_section, emit_code_section

; ------------------------------------------------------------------
; BSS — global compiler state
; ------------------------------------------------------------------
SECTION .bss

compiler_memory_ptr:    resq    1
compiler_memory_len:    resq    1
compiler_output_ptr:    resq    1
compiler_output_len:    resq    1
compiler_status_val:    resd    1
compiler_diag_buf:      resb    128
compiler_diag_len:      resd    1
compiler_initialized:   resb    1
lowering_data_offset:   resd    1
lowering_data_end:      resd    1

; ------------------------------------------------------------------
; Read-only data
; ------------------------------------------------------------------
SECTION .rodata

; Diagnostic error strings
str_not_initialized:    db "compiler not initialized", 0
str_empty_memory:       db "compiler memory slice is empty", 0
str_unaligned_memory:   db "compiler memory slice is not aligned", 0
str_source_too_large:   db "source size is outside compiler bounds", 0
str_corrupt_object:     db "compiler input is not a canonical EdgeRun object", 0
str_unsupported_label:  db "source root label is not a supported EdgeRun compiler input", 0
str_missing_root:       db "wFSO: missing root source", 0
str_not_workspace:      db "compiler input is not an EdgeRun VFS workspace object", 0
str_corrupt_workspace:  db "compiler input has a corrupt EdgeRun VFS workspace", 0
str_memory_too_small:   db "compiler memory slice is too small for EdgeRun lowering", 0
str_invalid_source:     db "VFS root source is outside the supported EdgeRun source subset", 0
str_output_too_large:   db "compiled wasm does not fit compiler output memory", 0
str_linked_parse:       db "linked parse compiler info", 0
str_linked_info_fail:   db "linked compiler info", 0
str_linked_type:        db "linked type section", 0
str_linked_function:    db "linked function section", 0
str_linked_export:      db "linked export section", 0
str_linked_code:        db "linked code section", 0
str_linked_data:        db "linked data section", 0
str_linked_copy:        db "linked copied section", 0
str_enter_compile:      db "ZZZZ_enter_compileWithMode_ZZZZ", 0

; Default root source label
str_default_root:       db "src/main.er", 0

; WASM magic number + version (little-endian)
wasm_header_bytes:      db 0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00

; Keyword strings
kw_addrspace:   db "addrspace", 0
kw_align:       db "align", 0
kw_allowzero:   db "allowzero", 0
kw_and:         db "and", 0
kw_anyframe:    db "anyframe", 0
kw_anytype:     db "anytype", 0
kw_asm:         db "asm", 0
kw_break:       db "break", 0
kw_callconv:    db "callconv", 0
kw_catch:       db "catch", 0
kw_comptime:    db "comptime", 0
kw_const:       db "const", 0
kw_continue:    db "continue", 0
kw_defer:       db "defer", 0
kw_else:        db "else", 0
kw_enum:        db "enum", 0
kw_errdefer:    db "errdefer", 0
kw_error:       db "error", 0
kw_export:      db "export", 0
kw_extern:      db "extern", 0
kw_fn:          db "fn", 0
kw_for:         db "for", 0
kw_if:          db "if", 0
kw_inline:      db "inline", 0
kw_module:      db "module", 0
kw_noalias:     db "noalias", 0
kw_noinline:    db "noinline", 0
kw_nosuspend:   db "nosuspend", 0
kw_opaque:      db "opaque", 0
kw_or:          db "or", 0
kw_orelse:      db "orelse", 0
kw_packed:      db "packed", 0
kw_pub:         db "pub", 0
kw_resume:      db "resume", 0
kw_return:      db "return", 0
kw_linksection: db "linksection", 0
kw_struct:      db "struct", 0
kw_suspend:     db "suspend", 0
kw_switch:      db "switch", 0
kw_test:        db "test", 0
kw_threadlocal: db "threadlocal", 0
kw_try:         db "try", 0
kw_union:       db "union", 0
kw_unreachable: db "unreachable", 0
kw_var:         db "var", 0
kw_volatile:    db "volatile", 0
kw_while:       db "while", 0
kw_true:        db "true", 0
kw_false:       db "false", 0

; ==================================================================
; .text — all code
; ==================================================================
SECTION .text

; ==================================================================
; Helper: set diagnostic string (rdi = pointer to string in rodata)
; Clobbers: rax, rdi, rsi, rcx
; ==================================================================
diag_set:
    er_frame_push
    push    rdi

    mov     rdi, [rbp - 8]
    xor     eax, eax
    mov     rcx, -1
    repne   scasb
    not     rcx
    dec     rcx

    cmp     rcx, 127
    jbe     .copy
    mov     ecx, 127
.copy:
    mov     [compiler_diag_len], ecx
    mov     rsi, [rbp - 8]
    lea     rdi, [compiler_diag_buf]
    rep     movsb
    mov     byte [rdi], 0
    pop     rdi
    pop     rbp
    ret

; ==================================================================
; Helper: clear diagnostic
; ==================================================================
diag_clear:
    mov     dword [compiler_diag_len], 0
    mov     byte [compiler_diag_buf], 0
    ret

; ==================================================================
; C ABI exports
; ==================================================================

; u32 er_wasm_compiler_abi_version(void)
er_fn er_wasm_compiler_abi_version
    mov     eax, WASM_COMPILER_ABI_VERSION
    ret

; u32 er_wasm_compiler_init(memory_ptr=rdi, memory_len=rsi)
er_fn er_wasm_compiler_init
    er_frame_push

    test    rsi, rsi
    jnz     .check_align
    mov     dword [compiler_status_val], COMPILER_STATUS_INVALID_MEM
    lea     rdi, [str_empty_memory]
    call    diag_set
    mov     eax, COMPILER_STATUS_INVALID_MEM
    pop     rbp
    ret

.check_align:
    mov     rax, rdi
    and     eax, COMPILER_MEMORY_ALIGN_MASK
    jz      .init_ok
    mov     dword [compiler_status_val], COMPILER_STATUS_INVALID_MEM
    lea     rdi, [str_unaligned_memory]
    call    diag_set
    mov     eax, COMPILER_STATUS_INVALID_MEM
    pop     rbp
    ret

.init_ok:
    mov     [compiler_memory_ptr], rdi
    mov     [compiler_memory_len], rsi
    mov     qword [compiler_output_ptr], 0
    mov     qword [compiler_output_len], 0
    mov     byte [compiler_initialized], 1
    mov     dword [compiler_status_val], COMPILER_STATUS_OK
    call    diag_clear
    xor     eax, eax
    pop     rbp
    ret

; u32 er_wasm_compiler_status(void)
er_fn er_wasm_compiler_status
    mov     eax, [compiler_status_val]
    ret

; usize er_wasm_compiler_output_ptr(void)
er_fn er_wasm_compiler_output_ptr
    mov     rax, [compiler_output_ptr]
    ret

; usize er_wasm_compiler_output_len(void)
er_fn er_wasm_compiler_output_len
    mov     rax, [compiler_output_len]
    ret

; usize er_wasm_compiler_diagnostic_ptr(void)
er_fn er_wasm_compiler_diagnostic_ptr
    lea     rax, [compiler_diag_buf]
    ret

; usize er_wasm_compiler_diagnostic_len(void)
er_fn er_wasm_compiler_diagnostic_len
    mov     eax, [compiler_diag_len]
    ret

; ==================================================================
; Main compile pipeline
; ==================================================================

; u32 er_wasm_compiler_compile_wasm(
;     compiler_memory_ptr=rdi, compiler_memory_len=rsi,
;     source_name_ptr=rdx, source_name_len=rcx,
;     source_ptr=r8, source_len=r9)
er_fn er_wasm_compiler_compile_wasm
    er_frame_push
    push    r12                     ; compiler_memory_ptr
    push    r13                     ; compiler_memory_len
    push    r14                     ; source_name_ptr
    push    r15                     ; source_name_len
    sub     rsp, 32

    ; Validate arguments
    test    rsi, rsi
    jz      .invalid_memory
    mov     rax, rdi
    and     eax, COMPILER_MEMORY_ALIGN_MASK
    jnz     .invalid_memory

    test    r9, r9
    jz      .source_too_large
    cmp     r9, MAX_SOURCE_BYTES
    ja      .source_too_large

    mov     r12, rdi
    mov     r13, rsi
    mov     r14, rdx
    mov     r15, rcx

    ; Reset compiled body state
    mov     dword [body_buf_pos], 0

    ; Zero out body_lens
    push    rcx
    xor     ecx, ecx
.zbl_loop:
    cmp     ecx, MAX_PARSED_EXPORTS
    jae     .zbl_done
    mov     dword [body_lens + ecx*4], 0
    inc     ecx
    jmp     .zbl_loop
.zbl_done:
    pop     rcx

    ; Call source_parse(source_ptr=rdi, source_len=rsi)
    mov     rdi, r8
    mov     rsi, r9

    mov     dword [export_name_count], 0

    call    source_parse
    jc      .parse_failed

    mov     ecx, [export_name_count]

    cmp     r13, 1024
    jb      .mem_too_small

    ; Initialize output writer at start of compiler_memory
    sub     rsp, 40
    mov     [rsp], r12
    mov     [rsp + 8], r13
    mov     qword [rsp + 16], 0

    ; Write WASM header
    mov     rdi, rsp
    lea     rsi, [wasm_header_bytes]
    mov     edx, 8
    call    writer_append_slice
    jc      .output_overflow

    ; Emit type section
    mov     rdi, rsp
    call    emit_types_section
    test    eax, eax
    jnz     .cs_error

    ; Emit function section
    mov     rdi, rsp
    mov     ecx, [export_name_count]
    call    emit_function_section
    test    eax, eax
    jnz     .cs_error

    ; Emit memory section
    mov     rdi, rsp
    call    emit_memory_section
    test    eax, eax
    jnz     .cs_error

    ; Emit export section
    mov     rdi, rsp
    mov     ecx, [export_name_count]
    lea     r8, [export_name_ptrs]
    lea     r9, [export_name_lens]
    call    emit_base_exports
    test    eax, eax
    jnz     .cs_error

    ; Emit start section
    mov     rdi, rsp
    call    emit_start_section
    test    eax, eax
    jnz     .cs_error

    ; Emit code section
    mov     rdi, rsp
    mov     ecx, [export_name_count]
    mov     r8, [export_name_ptrs]
    mov     r9d, [export_name_count]
    call    emit_code_section
    test    eax, eax
    jnz     .cs_error

    ; Store output
    mov     rax, [rsp + 16]
    mov     [compiler_output_len], rax
    mov     [compiler_output_ptr], r12

    mov     dword [compiler_status_val], COMPILER_STATUS_OK
    call    diag_clear

    add     rsp, 40
    xor     eax, eax
    add     rsp, 32
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    ret

.parse_failed:
    mov     dword [compiler_status_val], COMPILER_STATUS_INVALID_SRC
    lea     rdi, [str_invalid_source]
    call    diag_set
    mov     eax, COMPILER_STATUS_INVALID_SRC
    add     rsp, 32
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    ret

.invalid_memory:
    mov     dword [compiler_status_val], COMPILER_STATUS_INVALID_MEM
    lea     rdi, [str_empty_memory]
    call    diag_set
    mov     eax, COMPILER_STATUS_INVALID_MEM
    add     rsp, 32
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    ret

.source_too_large:
    mov     dword [compiler_status_val], COMPILER_STATUS_SRC_TOO_LARGE
    lea     rdi, [str_source_too_large]
    call    diag_set
    mov     eax, COMPILER_STATUS_SRC_TOO_LARGE
    add     rsp, 32
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    ret

.mem_too_small:
    mov     dword [compiler_status_val], COMPILER_STATUS_MEM_TOO_SMALL
    lea     rdi, [str_memory_too_small]
    call    diag_set
    mov     eax, COMPILER_STATUS_MEM_TOO_SMALL
    add     rsp, 32
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    ret

.output_overflow:
.mem_overflow:
.cs_error:
    mov     dword [compiler_status_val], COMPILER_STATUS_UNSUPPORTED
    lea     rdi, [str_output_too_large]
    call    diag_set
    mov     dword [compiler_output_len], 0
    mov     qword [compiler_output_ptr], 0
    mov     eax, COMPILER_STATUS_UNSUPPORTED
    add     rsp, 40
    add     rsp, 32
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    ret

; u32 er_wasm_compiler_compile_wasm_metadata(
;     compiler_memory_ptr, compiler_memory_len,
;     source_name_ptr, source_name_len,
;     source_ptr, source_len)
er_fn er_wasm_compiler_compile_wasm_metadata
    jmp     er_wasm_compiler_compile_wasm
