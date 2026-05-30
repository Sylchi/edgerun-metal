; ==================================================================
; EdgeRun WASM Compiler — WASM section emission
; Extracted from wasm_compiler.asm for maintainability
; ==================================================================

%include "x86_64/macros.inc"
%include "x86_64/wasm/wasm_compiler.inc"

; Externs from wasm_compiler_helpers.asm
extern writer_append_byte
extern writer_append_slice
extern writer_append_u32_leb
extern writer_append_i32_leb
extern writer_append_name

; Externs from wasm_compiler_source.asm
extern return_values
extern body_offsets, body_lens, body_param_counts, body_buf

; ------------------------------------------------------------------
; Export name strings (for export_table)
; Must be in the same file as export_table for label resolution
; ------------------------------------------------------------------
SECTION .rodata
global str_memory_export
str_memory_export:      db "memory", 0

global str_er_app_abi_version
str_er_app_abi_version:         db "er_app_abi_version", 0
global str_er_app_source_ptr
str_er_app_source_ptr:          db "er_app_source_ptr", 0
global str_er_app_source_len
str_er_app_source_len:          db "er_app_source_len", 0
global str_er_app_source_hash
str_er_app_source_hash:         db "er_app_source_hash", 0
global str_er_app_main
str_er_app_main:                db "er_app_main", 0
global str_er_app_source_file_count
str_er_app_source_file_count:   db "er_app_source_file_count", 0
global str_er_app_root_source_len
str_er_app_root_source_len:     db "er_app_root_source_len", 0
global str_er_app_root_source_hash
str_er_app_root_source_hash:    db "er_app_root_source_hash", 0
global str_er_app_edgerun_inst_count
str_er_app_edgerun_inst_count:  db "er_app_edgerun_instruction_count", 0
global str_er_app_edgerun_decl_count
str_er_app_edgerun_decl_count:  db "er_app_edgerun_declaration_count", 0
global str_er_app_edgerun_export_bytes
str_er_app_edgerun_export_bytes:db "er_app_edgerun_export_name_bytes", 0
global str_er_app_compiler_mem_used
str_er_app_compiler_mem_used:   db "er_app_compiler_memory_used", 0
global str_er_app_analyzed_file_count
str_er_app_analyzed_file_count: db "er_app_analyzed_file_count", 0
global str_er_app_import_edge_count
str_er_app_import_edge_count:   db "er_app_import_edge_count", 0
global str_er_app_unresolved_import
str_er_app_unresolved_import:   db "er_app_unresolved_import_count", 0
global str_er_app_truncated_import
str_er_app_truncated_import:    db "er_app_truncated_import_count", 0
global str_er_app_manifest_scanned
str_er_app_manifest_scanned:    db "er_app_manifest_file_refs_scanned", 0
global str_er_app_file_object_decodes
str_er_app_file_object_decodes: db "er_app_file_object_decodes", 0
global str_er_app_file_lookup_count
str_er_app_file_lookup_count:   db "er_app_file_lookup_count", 0
global str_er_app_queued_import_count
str_er_app_queued_import_count: db "er_app_queued_import_count", 0
global str_er_app_pruned_import_count
str_er_app_pruned_import_count: db "er_app_pruned_import_count", 0
global str_er_app_parsed_source_bytes
str_er_app_parsed_source_bytes: db "er_app_parsed_source_bytes", 0
global str_er_app_indexed_file_count
str_er_app_indexed_file_count:  db "er_app_indexed_file_count", 0
global str_er_app_embedded_src_len
str_er_app_embedded_src_len:    db "er_app_embedded_source_len", 0
global str_er_app_lowered_main_count
str_er_app_lowered_main_count:  db "er_app_lowered_main_count", 0
global str_er_app_lowered_export_count
str_er_app_lowered_export_count:db "er_app_lowered_export_count", 0

; ==================================================================
; .text — WASM section emission code
; ==================================================================
SECTION .text

; ==================================================================
; Emit WASM section header
; ==================================================================

; Emit a section with given id and payload
; rdi = parent writer
; al = section_id
; rsi = payload ptr, rdx = payload len
global emit_section
emit_section:
    er_frame_push
    sub     rsp, 16
    mov     [rbp - 16], rsi
    mov     [rbp - 8], rdx
    mov     sil, al
    call    writer_append_byte
    jc      .error
    mov     eax, [rbp - 8]
    push    rdi
    call    writer_append_u32_leb
    pop     rdi
    test    eax, eax
    jnz     .error
    mov     rsi, [rbp - 16]
    mov     rdx, [rbp - 8]
    call    writer_append_slice
    jc      .error
    xor     eax, eax
    clc
    add     rsp, 16
    pop     rbp
    ret
.error:
    or      eax, -1
    stc
    add     rsp, 16
    pop     rbp
    ret

; ------------------------------------------------------------------
; Emit export entry
; rdi = writer, rsi = name ptr, ecx = name_len, dl = kind, r8d = index
; ------------------------------------------------------------------
global emit_export_entry
emit_export_entry:
    er_frame_push
    push    rcx
    push    rdx
    push    r8
    mov     edx, ecx
    call    writer_append_name
    test    eax, eax
    jnz     .error
    pop     r8
    pop     rdx
    push    rdx
    mov     sil, dl
    call    writer_append_byte
    jc      .error
    mov     eax, r8d
    call    writer_append_u32_leb
    test    eax, eax
    jnz     .error
    xor     eax, eax
    pop     rcx
    pop     rbp
    ret
.error:
    or      eax, -1
    pop     rcx
    pop     rbp
    ret

; ------------------------------------------------------------------
; Emit a WASM function body for "return i32_const(value)"
; rdi = writer struct ptr, eax = value
; Returns eax = 0 ok, -1 error
; ------------------------------------------------------------------
global emit_return_i32_function
emit_return_i32_function:
    er_frame_push
    push    rbx
    mov     ebx, eax
    ; body size LEB(len of 0x00 0x41 <value_leb> 0x0b)
    push    rdi
    mov     rdi, rsp
    sub     rsp, 32
    lea     rax, [rsp + 24]
    mov     [rsp], rax
    mov     qword [rsp + 8], 16
    mov     qword [rsp + 16], 0
    mov     rdi, rsp
    mov     sil, 0x00
    call    writer_append_byte
    jc      .error_save
    mov     rdi, rsp
    mov     sil, WASM_I32_CONST
    call    writer_append_byte
    jc      .error_save
    mov     rdi, rsp
    mov     eax, ebx
    call    writer_append_i32_leb
    test    eax, eax
    jnz     .error_save
    mov     rdi, rsp
    mov     sil, WASM_OPCODE_END
    call    writer_append_byte
    jc      .error_save
    ; Write body size + body to actual writer
    mov     rdi, [rbp - 8]
    mov     esi, [rsp + 16]
    call    writer_append_u32_leb
    test    eax, eax
    jnz     .error_save
    mov     rdi, [rbp - 8]
    lea     rsi, [rsp + 24]
    mov     edx, [rsp + 16]
    call    writer_append_slice
    jc      .error_save
    add     rsp, 32
    pop     rdi
    xor     eax, eax
    pop     rbx
    pop     rbp
    ret
.error_save:
    add     rsp, 32
    pop     rdi
    or      eax, -1
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; Section 1: Type section
; 5 function types: ()->i32, ()->(), (i32)->i32, (i32,i32)->i32, (i32,i32,i32)->i32
; ==================================================================
global emit_types_section
emit_types_section:
    er_frame_push
    push    rbx
    push    r12
    mov     r12, rdi
    sub     rsp, 128

    lea     rax, [rsp + 24]
    mov     [rsp], rax
    mov     qword [rsp + 8], 100
    mov     qword [rsp + 16], 0

    mov     rdi, rsp
    mov     eax, 5
    call    writer_append_u32_leb
    test    eax, eax
    jnz     .ts_error

    ; Type 0: ()->i32
    mov     rdi, rsp
    mov     sil, 0x60
    call    writer_append_byte; jc .ts_error
    jc      .ts_error
    mov     rdi, rsp
    xor     eax, eax
    call    writer_append_u32_leb; jnz .ts_error
    jnz     .ts_error
    mov     rdi, rsp
    mov     eax, 1
    call    writer_append_u32_leb; jnz .ts_error
    jnz     .ts_error
    mov     rdi, rsp
    mov     sil, 0x7f
    call    writer_append_byte; jc .ts_error
    jc      .ts_error

    ; Type 1: ()->()
    mov     rdi, rsp
    mov     sil, 0x60
    call    writer_append_byte; jc .ts_error
    jc      .ts_error
    mov     rdi, rsp
    xor     eax, eax
    call    writer_append_u32_leb; jnz .ts_error
    jnz     .ts_error
    mov     rdi, rsp
    xor     eax, eax
    call    writer_append_u32_leb; jnz .ts_error
    jnz     .ts_error

    ; Type 2: (i32)->i32
    mov     rdi, rsp
    mov     sil, 0x60
    call    writer_append_byte; jc .ts_error
    jc      .ts_error
    mov     rdi, rsp
    mov     eax, 1
    call    writer_append_u32_leb; jnz .ts_error
    jnz     .ts_error
    mov     rdi, rsp
    mov     sil, 0x7f
    call    writer_append_byte; jc .ts_error
    jc      .ts_error
    mov     rdi, rsp
    mov     eax, 1
    call    writer_append_u32_leb; jnz .ts_error
    jnz     .ts_error
    mov     rdi, rsp
    mov     sil, 0x7f
    call    writer_append_byte; jc .ts_error
    jc      .ts_error

    ; Type 3: (i32,i32)->i32
    mov     rdi, rsp
    mov     sil, 0x60
    call    writer_append_byte; jc .ts_error
    jc      .ts_error
    mov     rdi, rsp
    mov     eax, 2
    call    writer_append_u32_leb; jnz .ts_error
    jnz     .ts_error
    mov     rdi, rsp
    mov     sil, 0x7f
    call    writer_append_byte; jc .ts_error
    jc      .ts_error
    mov     rdi, rsp
    mov     sil, 0x7f
    call    writer_append_byte; jc .ts_error
    jc      .ts_error
    mov     rdi, rsp
    mov     eax, 1
    call    writer_append_u32_leb; jnz .ts_error
    jnz     .ts_error
    mov     rdi, rsp
    mov     sil, 0x7f
    call    writer_append_byte; jc .ts_error
    jc      .ts_error

    ; Type 4: (i32,i32,i32)->i32
    mov     rdi, rsp
    mov     sil, 0x60
    call    writer_append_byte; jc .ts_error
    jc      .ts_error
    mov     rdi, rsp
    mov     eax, 3
    call    writer_append_u32_leb; jnz .ts_error
    jnz     .ts_error
    mov     rdi, rsp
    mov     sil, 0x7f
    call    writer_append_byte; jc .ts_error
    jc      .ts_error
    mov     rdi, rsp
    mov     sil, 0x7f
    call    writer_append_byte; jc .ts_error
    jc      .ts_error
    mov     rdi, rsp
    mov     sil, 0x7f
    call    writer_append_byte; jc .ts_error
    jc      .ts_error
    mov     rdi, rsp
    mov     eax, 1
    call    writer_append_u32_leb; jnz .ts_error
    jnz     .ts_error
    mov     rdi, rsp
    mov     sil, 0x7f
    call    writer_append_byte; jc .ts_error
    jc      .ts_error

    mov     rdi, r12
    mov     al, 1
    lea     rsi, [rsp + 24]
    mov     rdx, [rsp + 16]
    call    emit_section
    jc      .ts_error

    xor     eax, eax
    add     rsp, 128
    pop     r12
    pop     rbx
    pop     rbp
    ret
.ts_error:
    or      eax, -1
    add     rsp, 128
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ------------------------------------------------------------------
; emit_function_section(rdi=main_writer, ecx=user_count)
; Section 3: 27 base + N user function type indices
; ------------------------------------------------------------------
global emit_function_section
emit_function_section:
    er_frame_push
    push    r12
    push    r13
    mov     r12, rdi
    mov     r13d, ecx
    sub     rsp, 64

    lea     rax, [rsp + 24]
    mov     [rsp], rax
    mov     qword [rsp + 8], 40
    mov     qword [rsp + 16], 0

    mov     rdi, rsp
    lea     eax, [r13 + SUCCESSOR_BASE_FUNCTION_COUNT]
    call    writer_append_u32_leb
    test    eax, eax
    jnz     .fs_error

    mov     rdi, rsp
    xor     ecx, ecx
.fs_loop_0_4:
    xor     eax, eax
    call    writer_append_u32_leb
    test    eax, eax
    jnz     .fs_error
    inc     ecx
    cmp     ecx, 5
    jb      .fs_loop_0_4

    mov     rdi, rsp
    mov     eax, 1
    call    writer_append_u32_leb
    test    eax, eax
    jnz     .fs_error

    mov     rdi, rsp
    mov     ecx, 6
.fs_loop_6_26:
    xor     eax, eax
    call    writer_append_u32_leb
    test    eax, eax
    jnz     .fs_error
    inc     ecx
    cmp     ecx, SUCCESSOR_BASE_FUNCTION_COUNT
    jb      .fs_loop_6_26

    mov     rdi, rsp
    xor     ecx, ecx
.fs_loop_user:
    mov     eax, [body_param_counts + ecx*4]
    test    eax, eax
    jz      .fs_user_no_params
    add     eax, 1
    jmp     .fs_user_emit_type
.fs_user_no_params:
    xor     eax, eax
.fs_user_emit_type:
    call    writer_append_u32_leb
    test    eax, eax
    jnz     .fs_error
    inc     ecx
    cmp     ecx, r13d
    jb      .fs_loop_user

    mov     rdi, r12
    mov     al, 3
    lea     rsi, [rsp + 24]
    mov     rdx, [rsp + 16]
    call    emit_section
    jc      .fs_error

    xor     eax, eax
    add     rsp, 64
    pop     r13
    pop     r12
    pop     rbp
    ret
.fs_error:
    or      eax, -1
    add     rsp, 64
    pop     r13
    pop     r12
    pop     rbp
    ret

; ------------------------------------------------------------------
; emit_memory_section(rdi=main_writer)
; Section 5: 1 linear memory with max=1 page
; ------------------------------------------------------------------
global emit_memory_section
emit_memory_section:
    er_frame_push
    push    r12
    mov     r12, rdi
    sub     rsp, 32

    lea     rax, [rsp + 24]
    mov     [rsp], rax
    mov     qword [rsp + 8], 16
    mov     qword [rsp + 16], 0

    mov     rdi, rsp
    mov     eax, 1
    call    writer_append_u32_leb
    test    eax, eax
    jnz     .ms_error

    mov     rdi, rsp
    mov     sil, 1
    call    writer_append_byte
    jc      .ms_error
    mov     rdi, rsp
    mov     eax, 1
    call    writer_append_u32_leb
    test    eax, eax
    jnz     .ms_error
    mov     rdi, rsp
    mov     eax, 1
    call    writer_append_u32_leb
    test    eax, eax
    jnz     .ms_error

    mov     rdi, r12
    mov     al, 5
    lea     rsi, [rsp + 24]
    mov     rdx, [rsp + 16]
    call    emit_section
    jc      .ms_error

    xor     eax, eax
    add     rsp, 32
    pop     r12
    pop     rbp
    ret
.ms_error:
    or      eax, -1
    add     rsp, 32
    pop     r12
    pop     rbp
    ret

; ------------------------------------------------------------------
; emit_base_exports(rdi=main_writer, ecx=user_count,
;                   r8=export_name_ptrs, r9=export_name_lens)
; Section 7: memory export + 27 base exports + user exports
; ------------------------------------------------------------------
global emit_base_exports
emit_base_exports:
    er_frame_push
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12, rdi
    mov     r13d, ecx
    mov     r14, r8
    mov     r15, r9
    sub     rsp, 24 + 1024

    lea     rax, [rsp + 24]
    mov     [rsp], rax
    mov     qword [rsp + 8], 1024
    mov     qword [rsp + 16], 0

    mov     rdi, rsp
    lea     eax, [r13 + 28]
    call    writer_append_u32_leb
    test    eax, eax
    jnz     .be_error

    mov     rdi, rsp
    lea     rsi, [str_memory_export]
    mov     edx, 6
    call    writer_append_name
    test    eax, eax
    jnz     .be_error
    mov     rdi, rsp
    mov     sil, 2
    call    writer_append_byte
    jc      .be_error
    mov     rdi, rsp
    xor     eax, eax
    call    writer_append_u32_leb
    test    eax, eax
    jnz     .be_error

    lea     r10, [export_table]
    xor     ebx, ebx
.be_loop:
    mov     rdi, rsp
    mov     rsi, [r10]
    mov     edx, [r10 + 8]
    call    writer_append_name
    test    eax, eax
    jnz     .be_error
    mov     rdi, rsp
    mov     sil, 0
    call    writer_append_byte
    jc      .be_error
    mov     rdi, rsp
    mov     eax, [r10 + 12]
    call    writer_append_u32_leb
    test    eax, eax
    jnz     .be_error
    add     r10, 16
    inc     ebx
    cmp     ebx, 27
    jb      .be_loop

    xor     ebx, ebx
.be_user_loop:
    cmp     ebx, r13d
    jae     .be_done_exports
    mov     rdi, rsp
    mov     rsi, [r14 + rbx*8]
    mov     edx, [r15 + rbx*4]
    call    writer_append_name
    test    eax, eax
    jnz     .be_error
    mov     rdi, rsp
    mov     sil, 0
    call    writer_append_byte
    jc      .be_error
    mov     rdi, rsp
    lea     eax, [rbx + 27]
    call    writer_append_u32_leb
    test    eax, eax
    jnz     .be_error
    inc     ebx
    jmp     .be_user_loop

.be_done_exports:
    mov     rdi, r12
    mov     al, 7
    lea     rsi, [rsp + 24]
    mov     rdx, [rsp + 16]
    call    emit_section
    jc      .be_error

    xor     eax, eax
    add     rsp, 1048
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    ret
.be_error:
    or      eax, -1
    add     rsp, 1048
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    ret

; ------------------------------------------------------------------
; Export table: 27 entries of {name_ptr(8), name_len(4), index(4)}
; ------------------------------------------------------------------
SECTION .rodata
align 8
export_table:
%macro exp_entry 3
    dq %1
    dd %2, %3
%endmacro
    exp_entry str_er_app_abi_version, 18, 0
    exp_entry str_er_app_source_ptr, 17, 1
    exp_entry str_er_app_source_len, 17, 2
    exp_entry str_er_app_source_hash, 18, 3
    exp_entry str_er_app_main, 11, 4
    exp_entry str_er_app_source_file_count, 24, 5
    exp_entry str_er_app_root_source_len, 22, 6
    exp_entry str_er_app_root_source_hash, 23, 7
    exp_entry str_er_app_edgerun_inst_count, 31, 8
    exp_entry str_er_app_edgerun_decl_count, 32, 9
    exp_entry str_er_app_edgerun_export_bytes, 31, 10
    exp_entry str_er_app_compiler_mem_used, 25, 11
    exp_entry str_er_app_analyzed_file_count, 27, 12
    exp_entry str_er_app_import_edge_count, 26, 13
    exp_entry str_er_app_unresolved_import, 28, 14
    exp_entry str_er_app_truncated_import, 27, 15
    exp_entry str_er_app_manifest_scanned, 29, 16
    exp_entry str_er_app_file_object_decodes, 29, 17
    exp_entry str_er_app_file_lookup_count, 25, 18
    exp_entry str_er_app_queued_import_count, 27, 19
    exp_entry str_er_app_pruned_import_count, 27, 20
    exp_entry str_er_app_parsed_source_bytes, 28, 21
    exp_entry str_er_app_indexed_file_count, 28, 22
    exp_entry str_er_app_embedded_src_len, 25, 23
    exp_entry str_er_app_lowered_main_count, 28, 24
    exp_entry str_er_app_lowered_export_count, 30, 25
    exp_entry str_er_app_lowered_export_count, 30, 26

; ==================================================================
; Section 8: Start section
; ==================================================================
SECTION .text

; ------------------------------------------------------------------
; emit_start_section(rdi=main_writer)
; Section 8: start = function index 5
; ------------------------------------------------------------------
global emit_start_section
emit_start_section:
    er_frame_push
    push    r12
    mov     r12, rdi
    sub     rsp, 64

    lea     rax, [rsp + 24]
    mov     [rsp], rax
    mov     qword [rsp + 8], 16
    mov     qword [rsp + 16], 0

    mov     rdi, rsp
    mov     eax, 5
    call    writer_append_u32_leb
    test    eax, eax
    jnz     .ss_error

    mov     rdi, r12
    mov     al, 8
    lea     rsi, [rsp + 24]
    mov     rdx, [rsp + 16]
    call    emit_section
    jc      .ss_error

    xor     eax, eax
    add     rsp, 64
    pop     r12
    pop     rbp
    ret
.ss_error:
    or      eax, -1
    add     rsp, 64
    pop     r12
    pop     rbp
    ret

; ------------------------------------------------------------------
; emit_code_section(rdi=main_writer, ecx=user_count,
;                   r8=export_name_ptrs, r9=export_name_lens)
; Section 10: 27 noop bodies + user bodies
; ------------------------------------------------------------------
global emit_code_section
emit_code_section:
    er_frame_push
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12, rdi
    mov     r13d, ecx
    mov     r14, r8
    mov     r15, r9
    sub     rsp, 24 + 1024

    lea     rax, [rsp + 24]
    mov     [rsp], rax
    mov     qword [rsp + 8], 1024
    mov     qword [rsp + 16], 0

    mov     rdi, rsp
    lea     eax, [r13 + SUCCESSOR_BASE_FUNCTION_COUNT]
    call    writer_append_u32_leb
    test    eax, eax
    jnz     .cs_error

    mov     rdi, rsp
    xor     ecx, ecx
.cs_noop_loop:
    mov     eax, 2
    call    writer_append_u32_leb
    test    eax, eax
    jnz     .cs_error
    mov     rdi, rsp
    mov     sil, 0x00
    call    writer_append_byte
    jc      .cs_error
    mov     rdi, rsp
    mov     sil, WASM_OPCODE_END
    call    writer_append_byte
    jc      .cs_error
    inc     ecx
    cmp     ecx, SUCCESSOR_BASE_FUNCTION_COUNT
    jb      .cs_noop_loop

    xor     r14d, r14d
.cs_user_loop:
    mov     eax, [body_lens + r14*4]
    test    eax, eax
    jz      .cs_user_fallback

    mov     rdi, rsp
    mov     eax, [body_lens + r14*4]
    call    writer_append_u32_leb
    test    eax, eax
    jnz     .cs_error

    mov     rdi, rsp
    mov     eax, [body_offsets + r14*4]
    lea     rsi, [body_buf + rax]
    mov     edx, [body_lens + r14*4]
    call    writer_append_slice
    jc      .cs_error
    jmp     .cs_user_next

.cs_user_fallback:
    lea     rax, [rsp + 824]
    mov     [rsp + 800], rax
    mov     qword [rsp + 808], 224
    mov     qword [rsp + 816], 0

    lea     rdi, [rsp + 800]
    mov     sil, 0x00
    call    writer_append_byte
    jc      .cs_error
    lea     rdi, [rsp + 800]
    mov     sil, WASM_I32_CONST
    call    writer_append_byte
    jc      .cs_error
    lea     rdi, [rsp + 800]
    mov     eax, [return_values + r14*4]
    call    writer_append_i32_leb
    test    eax, eax
    jnz     .cs_error
    lea     rdi, [rsp + 800]
    mov     sil, WASM_OPCODE_END
    call    writer_append_byte
    jc      .cs_error

    mov     rdi, rsp
    mov     eax, [rsp + 816]
    call    writer_append_u32_leb
    test    eax, eax
    jnz     .cs_error

    mov     rdi, rsp
    lea     rsi, [rsp + 824]
    mov     edx, [rsp + 816]
    call    writer_append_slice
    jc      .cs_error

.cs_user_next:
    inc     r14d
    cmp     r14d, r13d
    jb      .cs_user_loop

    mov     rdi, r12
    mov     al, 10
    lea     rsi, [rsp + 24]
    mov     rdx, [rsp + 16]
    call    emit_section
    jc      .cs_error

    xor     eax, eax
    add     rsp, 1048
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    ret
.cs_error:
    or      eax, -1
    add     rsp, 1048
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    ret
