; ==================================================================
; EdgeRun WASM Compiler — x86_64 assembly implementation
; Ported from edgerun-zig/compiler/zig/src/edgerun_wasm_compiler.zig
;
; C ABI (System V AMD64):
;   arg1=rdi, arg2=rsi, arg3=rdx, arg4=rcx, arg5=r8, arg6=r9
;   return=rax, error=rdx
; ==================================================================

%include "x86_64/macros.inc"
%include "x86_64/wasm_compiler.inc"

; Extern from source parser
extern source_parse
extern export_name_count, export_name_ptrs, export_name_lens
extern return_values

; ------------------------------------------------------------------
; BSS — global compiler state
; ------------------------------------------------------------------
SECTION .bss

; Memory buffer for compiler workspace
compiler_memory_ptr:    resq    1
compiler_memory_len:    resq    1
compiler_output_ptr:    resq    1
compiler_output_len:    resq    1
compiler_status_val:    resd    1
compiler_initialized:   resb    1
                        resb    3   ; padding

; Diagnostic message buffer (embedded in BSS, max 128 bytes)
compiler_diag_buf:      resb    128
compiler_diag_len:      resd    1

; Lowering context (persistent across compile calls)
lowering_data_offset:   resd    1
lowering_data_end:      resd    1

; ------------------------------------------------------------------
; .rodata — string constants
; ------------------------------------------------------------------
SECTION .rodata

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

; Default root label
str_default_root:       db "src/main.er", 0

; Wasm magic
wasm_header_bytes:      db 0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00

; String "memory" for export
str_memory_export:      db "memory", 0

; Export name strings (27 successor base function exports)
str_er_app_abi_version:         db "er_app_abi_version", 0
str_er_app_source_ptr:          db "er_app_source_ptr", 0
str_er_app_source_len:          db "er_app_source_len", 0
str_er_app_source_hash:         db "er_app_source_hash", 0
str_er_app_main:                db "er_app_main", 0
str_er_app_source_file_count:   db "er_app_source_file_count", 0
str_er_app_root_source_len:     db "er_app_root_source_len", 0
str_er_app_root_source_hash:    db "er_app_root_source_hash", 0
str_er_app_edgerun_inst_count:  db "er_app_edgerun_instruction_count", 0
str_er_app_edgerun_decl_count:  db "er_app_edgerun_declaration_count", 0
str_er_app_edgerun_export_bytes:db "er_app_edgerun_export_name_bytes", 0
str_er_app_compiler_mem_used:   db "er_app_compiler_memory_used", 0
str_er_app_analyzed_file_count: db "er_app_analyzed_file_count", 0
str_er_app_import_edge_count:   db "er_app_import_edge_count", 0
str_er_app_unresolved_import:   db "er_app_unresolved_import_count", 0
str_er_app_truncated_import:    db "er_app_truncated_import_count", 0
str_er_app_manifest_scanned:    db "er_app_manifest_file_refs_scanned", 0
str_er_app_file_object_decodes: db "er_app_file_object_decodes", 0
str_er_app_file_lookup_count:   db "er_app_file_lookup_count", 0
str_er_app_queued_import_count: db "er_app_queued_import_count", 0
str_er_app_pruned_import_count: db "er_app_pruned_import_count", 0
str_er_app_parsed_source_bytes: db "er_app_parsed_source_bytes", 0
str_er_app_indexed_file_count:  db "er_app_indexed_file_count", 0
str_er_app_embedded_src_len:    db "er_app_embedded_source_len", 0
str_er_app_lowered_main_count:  db "er_app_lowered_main_count", 0
str_er_app_lowered_export_count:db "er_app_lowered_export_count", 0

; Keyword match table entries: db "keyword", 0
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
    push    rbp
    mov     rbp, rsp
    push    rdi                     ; save string pointer

    ; Compute string length (strlen in rodata)
    mov     rdi, [rbp - 8]          ; restore string pointer
    xor     eax, eax
    mov     rcx, -1
    repne   scasb
    not     rcx
    dec     rcx                     ; rcx = length (excluding null)

    ; Check if it fits in diag buffer
    cmp     rcx, 127
    jbe     .copy
    mov     ecx, 127
.copy:
    mov     [compiler_diag_len], ecx
    mov     rsi, [rbp - 8]          ; src = string pointer
    lea     rdi, [compiler_diag_buf] ; dst
    rep     movsb
    mov     byte [rdi], 0           ; null terminate
    pop     rdi
    pop     rbp
    ret

; ==================================================================
; Helper: clear output
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
    push    rbp
    mov     rbp, rsp

    ; Check memory_len == 0
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
; Writer helper — write bytes to a buffer
; Arguments:
;   rdi = buffer pointer
;   rsi = buffer length (max)
;   rdx = current length (in/out)
; Returns: rax = error (0=ok, -1=overflow)
; ==================================================================

; Append single byte to writer buffer
; rdi = writer struct ptr {bytes_ptr, max_len, cur_len (as qword)}
; sil = byte to append
; Returns: carry set on overflow
writer_append_byte:
    mov     rax, [rdi + 16]     ; cur_len
    cmp     rax, [rdi + 8]      ; max_len
    jae     .overflow
    mov     rcx, [rdi]          ; bytes ptr
    mov     [rcx + rax], sil
    inc     qword [rdi + 16]
    clc
    ret
.overflow:
    stc
    ret

; Append slice to writer buffer
; rdi = writer struct ptr
; rsi = source ptr
; rdx = source len
writer_append_slice:
    mov     rax, [rdi + 16]     ; cur_len
    mov     r8, [rdi + 8]       ; max_len
    sub     r8, rax             ; remaining
    cmp     rdx, r8
    ja      .overflow
    mov     rcx, [rdi]          ; dst = bytes + cur_len
    add     rcx, rax
    push    rsi                 ; save src
    push    rdx                 ; save len
    push    rdi                 ; save writer
    mov     rdi, rcx            ; rdi = dst
    mov     rcx, rdx            ; rcx = count (rep movsb uses rcx)
    rep     movsb               ; memcpy(rdi=dst, rsi=src, rcx=count)
    pop     rdi                 ; restore writer
    pop     rdx                 ; restore len
    pop     rsi                 ; restore src
    add     qword [rdi + 16], rdx
    clc
    ret
.overflow:
    stc
    ret

; ==================================================================
; LEB128 utilities
; ==================================================================

; Encode u32 LEB128
; rdi = writer struct ptr
; eax = value
writer_append_u32_leb:
    push    rbp
    mov     rbp, rsp
    push    rbx
    mov     ebx, eax            ; remaining value
.leb_loop:
    mov     sil, bl
    and     sil, LEB_PAYLOAD_MASK
    shr     ebx, 7
    test    ebx, ebx
    jz      .last_byte
    or      sil, LEB_CONTINUE_MASK
    call    writer_append_byte
    jc      .error
    jmp     .leb_loop
.last_byte:
    call    writer_append_byte
    jc      .error
    xor     eax, eax
    pop     rbx
    pop     rbp
    ret
.error:
    or      eax, -1
    pop     rbx
    pop     rbp
    ret

; Encode i32 LEB128 (signed)
; rdi = writer struct ptr
; eax = value (sign-extended to rbx)
writer_append_i32_leb:
    push    rbp
    mov     rbp, rsp
    push    rbx
    movsxd  rbx, eax            ; sign extend to 64-bit for arithmetic
.sleb_loop:
    mov     sil, bl
    and     sil, LEB_PAYLOAD_MASK
    mov     rcx, rbx
    sar     rbx, 7
    ; check if done: (remaining == 0 && (byte & 0x40) == 0) || (remaining == -1 && (byte & 0x40) != 0)
    test    rbx, rbx
    jnz     .not_done
    test    sil, LEB_SIGN_MASK
    jz      .last
.not_done:
    cmp     rbx, -1
    jne     .more
    test    sil, LEB_SIGN_MASK
    jnz     .last
.more:
    or      sil, LEB_CONTINUE_MASK
    call    writer_append_byte
    jc      .error
    jmp     .sleb_loop
.last:
    call    writer_append_byte
    jc      .error
    xor     eax, eax
    pop     rbx
    pop     rbp
    ret
.error:
    or      eax, -1
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; Name writer: LEB(len) + bytes
; rdi = writer struct ptr
; rsi = name ptr
; edx = name len
writer_append_name:
    push    rbp
    mov     rbp, rsp
    push    rsi
    push    rdx
    mov     eax, edx
    call    writer_append_u32_leb
    test    eax, eax
    jnz     .error
    pop     rdx
    pop     rsi
    call    writer_append_slice
    jc      .error2
    xor     eax, eax
    pop     rbp
    ret
.error:
    pop     rdx
    pop     rsi
.error2:
    or      eax, -1
    pop     rbp
    ret

; ==================================================================
; Read helpers (for parsing linked compiler WASM)
; ==================================================================

; Read u32 LEB128 from [rsi], return in eax, advance rsi
; Returns carry set on error
read_u32_leb:
    xor     eax, eax
    xor     ecx, ecx            ; shift
    xor     r8d, r8d            ; count
.r_loop:
    cmp     r8d, LEB32_MAX_BYTES
    jae     .r_error
    movzx   r9d, byte [rsi]
    inc     rsi
    mov     r10d, r9d
    and     r10d, LEB_PAYLOAD_MASK
    shl     r10d, cl
    or      eax, r10d
    add     ecx, LEB_BITS_PER_BYTE
    inc     r8d
    test    r9d, LEB_CONTINUE_MASK
    jnz     .r_loop
    clc
    ret
.r_error:
    stc
    ret

; Read one byte from [rsi], return in al, advance rsi
read_byte:
    movzx   eax, byte [rsi]
    inc     rsi
    ret

; ==================================================================
; FNV-1a hash
; rdi = data ptr, rsi = length
; Returns eax = hash
; ==================================================================
fnv1a_hash:
    mov     eax, FNV_OFFSET_BASIS
    test    rsi, rsi
    jz      .done
.hash_loop:
    movzx   ecx, byte [rdi]
    xor     eax, ecx
    imul    eax, FNV_PRIME
    inc     rdi
    dec     rsi
    jnz     .hash_loop
.done:
    ret

; ==================================================================
; Integer parsing from decimal string
; rdi = string ptr, rsi = length
; Returns eax = value, carry set on error
; ==================================================================
parse_decimal_i32:
    push    rbp
    mov     rbp, rsp
    push    rbx
    xor     eax, eax
    mov     ebx, 1              ; sign
    mov     rcx, rsi
    test    rcx, rcx
    jz      .error
    ; Check for leading minus
    movzx   edx, byte [rdi]
    cmp     dl, '-'
    jne     .digit_loop
    mov     ebx, -1
    inc     rdi
    dec     rcx
    jz      .error
.digit_loop:
    movzx   edx, byte [rdi]
    sub     dl, '0'
    cmp     dl, 9
    ja      .error
    imul    eax, 10
    jo      .error
    add     eax, edx
    jo      .error
    inc     rdi
    dec     rcx
    jnz     .digit_loop
    imul    eax, ebx
    clc
    pop     rbx
    pop     rbp
    ret
.error:
    stc
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; Source tokenizer (port of edgerun_source.zig)
; ==================================================================

; Determine if byte is an identifier start character
; al = byte, returns ZF set if true
global is_ident_start
is_ident_start:
    cmp     al, 'a'
    jb      .check_upper
    cmp     al, 'z'
    jbe     .yes
.check_upper:
    cmp     al, 'A'
    jb      .check_underscore
    cmp     al, 'Z'
    jbe     .yes
.check_underscore:
    cmp     al, '_'
    je      .yes
    xor     eax, eax
    inc     eax
    ret
.yes:
    cmp     al, al              ; ZF set
    ret

; Determine if byte is an identifier continue character
; al = byte, returns ZF set if true
global is_ident_continue
is_ident_continue:
    call    is_ident_start
    jz      .yes
    cmp     al, '0'
    jb      .no
    cmp     al, '9'
    ja      .no
.yes:
    cmp     al, al
    ret
.no:
    ret

; Determine if byte is whitespace
global is_ascii_whitespace
is_ascii_whitespace:
    cmp     al, ' '
    je      .yes
    cmp     al, 0x09            ; tab
    je      .yes
    cmp     al, 0x0a            ; newline
    je      .yes
    cmp     al, 0x0d            ; carriage return
    je      .yes
    xor     eax, eax
    or      eax, 1
    ret
.yes:
    cmp     al, al
    ret

; Determine if byte is a digit
global is_digit
is_digit:
    cmp     al, '0'
    jb      .no
    cmp     al, '9'
    ja      .no
.yes:
    cmp     al, al
    ret
.no:
    ret

; Determine if byte is a hex digit
global is_ascii_hex_digit
is_ascii_hex_digit:
    call    is_digit
    je      .yes
    cmp     al, 'a'
    jb      .no
    cmp     al, 'f'
    jbe     .yes
    cmp     al, 'A'
    jb      .no
    cmp     al, 'F'
    ja      .no
.yes:
    cmp     al, al
    ret
.no:
    ret

; ==================================================================
; Skip whitespace and line comments in source
; rdi = source ptr, rsi = source len, rdx = index
; Returns rdx = new index (carry set on end)
global skip_space
skip_space:
    push    rbp
    mov     rbp, rsp
    push    rbx
.loop:
    cmp     rdx, rsi
    jae     .end
    movzx   eax, byte [rdi + rdx]
    call    is_ascii_whitespace
    jz      .skip_char
    ; Check for line comment //
    cmp     al, '/'
    jne     .done
    cmp     rdx, rsi
    jae     .done
    movzx   ebx, byte [rdi + rdx + 1]
    cmp     bl, '/'
    jne     .done
    ; Skip line comment
    add     rdx, 2
.line_comment:
    cmp     rdx, rsi
    jae     .loop
    movzx   eax, byte [rdi + rdx]
    cmp     al, 0x0a
    je      .loop
    cmp     al, 0x0d
    je      .loop
    inc     rdx
    jmp     .line_comment
.skip_char:
    inc     rdx
    jmp     .loop
.done:
    clc
    pop     rbx
    pop     rbp
    ret
.end:
    stc
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; Scan identifier end
; rdi = source ptr, rsi = source len, rdx = start index
; Returns rdx = end index (exclusive), carry if error
global scan_identifier_end
scan_identifier_end:
    cmp     rdx, rsi
    jae     .error
    movzx   eax, byte [rdi + rdx]
    call    is_ident_start
    jnz     .error
    inc     rdx
.loop:
    cmp     rdx, rsi
    jae     .done
    movzx   eax, byte [rdi + rdx]
    call    is_ident_continue
    jnz     .done
    inc     rdx
    jmp     .loop
.done:
    clc
    ret
.error:
    stc
    ret

; ==================================================================
; Scan balanced delimiter (matching parens/braces/brackets)
; rdi = source, rsi = source len, rdx = start index
; al = open char, ah = close char
; Returns rdx = index after matching close, carry if error
global scan_balanced
scan_balanced:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    rcx
    cmp     rdx, rsi
    jae     .error
    movzx   ebx, byte [rdi + rdx]
    cmp     bl, al
    jne     .error
    mov     ecx, 1              ; depth
    inc     rdx
.loop:
    cmp     rdx, rsi
    jae     .error
    movzx   ebx, byte [rdi + rdx]
    cmp     bl, al
    jne     .check_close
    inc     ecx
    inc     rdx
    jmp     .loop
.check_close:
    cmp     bl, ah
    jne     .next
    dec     ecx
    jz      .found
    inc     rdx
    jmp     .loop
.next:
    inc     rdx
    jmp     .loop
.found:
    inc     rdx
    clc
    pop     rcx
    pop     rbx
    pop     rbp
    ret
.error:
    stc
    pop     rcx
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; Find top-level byte (not inside brackets)
; rdi = source, rsi = source len, rdx = start, cl = byte to find
; Returns rdx = position of byte, carry if not found
; ==================================================================
find_top_level_byte:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    xor     r8d, r8d            ; paren_depth
    xor     r9d, r9d            ; brace_depth
    xor     r10d, r10d          ; bracket_depth
    mov     r11b, cl            ; byte to find
.loop:
    cmp     rdx, rsi
    jae     .not_found
    movzx   ebx, byte [rdi + rdx]
    cmp     bl, r11b
    jne     .check_paren
    test    r8d, r8d
    jnz     .skip
    test    r9d, r9d
    jnz     .skip
    test    r10d, r10d
    jnz     .skip
    ; Found at top level
    clc
    pop     r12
    pop     rbx
    pop     rbp
    ret
.check_paren:
    cmp     bl, '('
    jne     .check_brace
    inc     r8d
    jmp     .next
.check_brace:
    cmp     bl, '{'
    jne     .check_bracket
    inc     r9d
    jmp     .next
.check_bracket:
    cmp     bl, '['
    jne     .check_close_paren
    inc     r10d
    jmp     .next
.check_close_paren:
    cmp     bl, ')'
    jne     .check_close_brace
    test    r8d, r8d
    jz      .not_found
    dec     r8d
    jmp     .next
.check_close_brace:
    cmp     bl, '}'
    jne     .check_close_bracket
    test    r9d, r9d
    jz      .not_found
    dec     r9d
    jmp     .next
.check_close_bracket:
    cmp     bl, ']'
    jne     .skip
    test    r10d, r10d
    jz      .not_found
    dec     r10d
.skip:
.next:
    inc     rdx
    jmp     .loop
.not_found:
    stc
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; Find matching bracket (for array indexing)
; rdi = source, rsi = source len, rdx = start (at '[')
; Returns rdx = index after ']', carry if error
; ==================================================================
find_matching_bracket:
    mov     al, '['
    mov     ah, ']'
    call    scan_balanced
    ret

; ==================================================================
; Find matching paren (for while/if conditions)
; rdi = source, rsi = source len, rdx = start (at '(')
; Returns rdx = index after ')'
; ==================================================================
find_matching_paren:
    mov     al, '('
    mov     ah, ')'
    call    scan_balanced
    ret

; ==================================================================
; Find matching brace (for blocks)
; rdi = source, rsi = source len, rdx = start (at '{')
; Returns rdx = index after '}'
; ==================================================================
find_matching_brace:
    mov     al, '{'
    mov     ah, '}'
    call    scan_balanced
    ret

; ==================================================================
; Trim ASCII whitespace from ends of string
; rdi = ptr, rsi = len (in/out as rsi)
; Returns rdi = trimmed start, rsi = trimmed length
; ==================================================================
trim_whitespace:
    push    rbp
    mov     rbp, rsp
    push    rbx
    ; Trim left
    mov     rcx, rsi
    test    rcx, rcx
    jz      .done
.left_loop:
    movzx   eax, byte [rdi]
    call    is_ascii_whitespace
    jnz     .right_trim
    inc     rdi
    dec     rcx
    jnz     .left_loop
    jmp     .done
.right_trim:
    mov     rsi, rcx
    test    rsi, rsi
    jz      .done
.right_loop:
    movzx   eax, byte [rdi + rsi - 1]
    call    is_ascii_whitespace
    jnz     .done
    dec     rsi
    jnz     .right_loop
.done:
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; Check if all characters in string are whitespace
; rdi = ptr, rsi = len, returns ZF set if all whitespace
; ==================================================================
all_whitespace:
    push    rbp
    mov     rbp, rsp
    test    rsi, rsi
    jz      .yes
.loop:
    movzx   eax, byte [rdi]
    call    is_ascii_whitespace
    jnz     .no
    inc     rdi
    dec     rsi
    jnz     .loop
.yes:
    cmp     al, al
    pop     rbp
    ret
.no:
    xor     eax, eax
    inc     eax
    pop     rbp
    ret

; ==================================================================
; Emit WASM section header
; rdi = writer struct ptr, al = section_id
; Need payload_len in r8d
; Clobbers: rax, rcx, rdx, rsi, rdi, r8
; ==================================================================

; Emit a section with given id and payload
; rdi = parent writer
; al = section_id
; rsi = payload ptr, rdx = payload len
emit_section:
    push    rbp
    mov     rbp, rsp
    sub     rsp, 16              ; dedicated slots: [rbp-16]=payload_ptr, [rbp-8]=payload_len
    mov     [rbp - 16], rsi      ; save payload ptr
    mov     [rbp - 8], rdx       ; save payload len
    mov     sil, al              ; section_id
    call    writer_append_byte
    jc      .error
    ; Write payload length as LEB128
    mov     eax, [rbp - 8]       ; payload len
    push    rdi                  ; save writer
    call    writer_append_u32_leb
    ; eax = return value from writer_append_u32_leb (0 = success)
    pop     rdi                  ; restore writer
    test    eax, eax
    jnz     .error
    ; Write payload bytes
    mov     rsi, [rbp - 16]      ; payload ptr
    mov     rdx, [rbp - 8]       ; payload len
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

; ==================================================================
; Emit export entry
; rdi = writer, rsi = name ptr, ecx = name_len, dl = kind, r8d = index
; ==================================================================
emit_export_entry:
    push    rbp
    mov     rbp, rsp
    push    rcx
    push    rdx
    push    r8
    ; Write name
    mov     edx, ecx
    call    writer_append_name
    test    eax, eax
    jnz     .error
    ; Write kind
    pop     r8
    pop     rdx
    push    rdx
    mov     sil, dl
    call    writer_append_byte
    jc      .error
    ; Write index
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

; ==================================================================
; Emit a WASM function body for "return i32_const(value)"
; rdi = writer struct ptr, eax = value
; Returns eax = 0 ok, -1 error
; ==================================================================
emit_return_i32_function:
    push    rbp
    mov     rbp, rsp
    push    rbx
    push    r12
    push    r13
    mov     r12, rdi            ; save writer
    mov     r13d, eax           ; save value
    sub     rsp, 40             ; header(24) + body(8) + padding(8)

    ; Stack-based writer for building body
    ; Layout at [rsp]: bytes_ptr(8), max_len(8), cur_len(8) = 24 bytes
    lea     rax, [rsp + 24]     ; body data starts after writer header
    mov     [rsp], rax          ; bytes_ptr
    mov     qword [rsp + 8], 8  ; max_len (i32.const + leb + end = ~5 bytes)
    mov     qword [rsp + 16], 0 ; cur_len

    ; body: local_count = 0 (ULEB128)
    mov     rdi, rsp
    xor     eax, eax
    call    writer_append_u32_leb
    test    eax, eax
    jnz     .error

    ; i32.const opcode
    mov     rdi, rsp
    mov     sil, WASM_I32_CONST
    call    writer_append_byte
    jc      .error

    ; i32.const value (LEB128 signed)
    mov     rdi, rsp
    mov     eax, r13d
    call    writer_append_i32_leb
    test    eax, eax
    jnz     .error

    ; end opcode
    mov     rdi, rsp
    mov     sil, WASM_OPCODE_END
    call    writer_append_byte
    jc      .error

    ; Now body is built at [rsp+24] with length in [rsp+16]
    ; Write to parent: func_len + body_bytes
    mov     rdi, r12            ; parent writer
    mov     eax, [rsp + 16]     ; body length
    call    writer_append_u32_leb
    test    eax, eax
    jnz     .error

    ; Copy body bytes
    mov     rdi, r12
    lea     rsi, [rsp + 24]
    mov     rdx, [rsp + 16]
    call    writer_append_slice
    jc      .error

    xor     eax, eax
    add     rsp, 40
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

.error:
    or      eax, -1
    add     rsp, 40
    pop     r13
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ==================================================================
; Section emission helpers
; Each takes the main writer in rdi, builds payload on stack,
; and calls emit_section to write section header + payload
; ==================================================================

; ---------------------------------------------------------------
; emit_types_section(rdi=main_writer)
; Writes section 1 with 5 base types:
;   0: ()->i32, 1: ()->(), 2: (i32)->i32,
;   3: (i32,i32)->i32, 4: (i32,i32,i32)->i32
; ---------------------------------------------------------------
emit_types_section:
    push    rbp
    mov     rbp, rsp
    push    rbx                    ; save main writer
    push    r12
    mov     r12, rdi               ; main writer
    sub     rsp, 128

    ; Init stack writer at [rsp]
    lea     rax, [rsp + 24]
    mov     [rsp], rax
    mov     qword [rsp + 8], 100
    mov     qword [rsp + 16], 0

    ; type count = 5
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

    ; Emit section 1 (type)
    mov     rdi, r12               ; main writer
    mov     al, 1                  ; type section id
    lea     rsi, [rsp + 24]        ; payload ptr
    mov     rdx, [rsp + 16]        ; payload len
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
; Section 3: function section with 27 + user_count funcs
; ------------------------------------------------------------------
emit_function_section:
    push    rbp
    mov     rbp, rsp
    push    r12
    push    r13
    mov     r12, rdi               ; main writer
    mov     r13d, ecx              ; user export count
    sub     rsp, 64

    lea     rax, [rsp + 24]
    mov     [rsp], rax
    mov     qword [rsp + 8], 40
    mov     qword [rsp + 16], 0

    ; func count = 27 + user_count
    mov     rdi, rsp
    lea     eax, [r13 + SUCCESSOR_BASE_FUNCTION_COUNT]
    call    writer_append_u32_leb
    test    eax, eax
    jnz     .fs_error

    ; Functions 0-4: type index 0 (()->i32)
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

    ; Function 5: type index 1 (()->void)
    mov     rdi, rsp
    mov     eax, 1
    call    writer_append_u32_leb
    test    eax, eax
    jnz     .fs_error

    ; Functions 6-26: type index 0 (()->i32)
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

    ; User exports: type index 0 (()->i32) for now
    mov     rdi, rsp
    xor     ecx, ecx
.fs_loop_user:
    xor     eax, eax
    call    writer_append_u32_leb
    test    eax, eax
    jnz     .fs_error
    inc     ecx
    cmp     ecx, r13d
    jb      .fs_loop_user

    mov     rdi, r12
    mov     al, 3                  ; function section id
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
emit_memory_section:
    push    rbp
    mov     rbp, rsp
    push    r12
    mov     r12, rdi
    sub     rsp, 32

    lea     rax, [rsp + 24]
    mov     [rsp], rax
    mov     qword [rsp + 8], 16
    mov     qword [rsp + 16], 0

    ; mem count = 1
    mov     rdi, rsp
    mov     eax, 1
    call    writer_append_u32_leb
    test    eax, eax
    jnz     .ms_error

    ; limits: flags=1 (max present), initial=1, max=1
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
    mov     al, 5                  ; memory section id
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

; ==================================================================
; Emit export entry helper (alias for emit_export_entry above)
; ==================================================================

; ------------------------------------------------------------------
; emit_base_exports(rdi=main_writer)
; Emit 1 memory export + 27 base function exports (28 total)
; ------------------------------------------------------------------
emit_base_exports:
    push    rbp
    mov     rbp, rsp
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12, rdi               ; main writer
    mov     r13d, ecx              ; user export count
    mov     r14, r8                ; export_name_ptrs base
    mov     r15, r9                ; export_name_lens base
    ; Temp writer: 24-byte header + 1024-byte buffer
    sub     rsp, 24 + 1024

    lea     rax, [rsp + 24]
    mov     [rsp], rax
    mov     qword [rsp + 8], 1024
    mov     qword [rsp + 16], 0

    ; export count = 28 + user_count
    mov     rdi, rsp
    lea     eax, [r13 + 28]
    call    writer_append_u32_leb
    test    eax, eax
    jnz     .be_error

    ; Memory export: name="memory", kind=2, index=0
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

    ; 27 function exports (kind=0, index 0-26)
    ; Using table of {name_ptr, name_len, index} tuples
    lea     r10, [export_table]    ; r10 not clobbered by writer functions
    xor     ebx, ebx               ; rbx preserved by writer_append_u32_leb push/pop
.be_loop:
    mov     rdi, rsp
    mov     rsi, [r10]             ; name ptr
    mov     edx, [r10 + 8]         ; name len
    call    writer_append_name
    test    eax, eax
    jnz     .be_error
    mov     rdi, rsp
    mov     sil, 0                 ; function kind
    call    writer_append_byte
    jc      .be_error
    mov     rdi, rsp
    mov     eax, [r10 + 12]        ; index
    call    writer_append_u32_leb
    test    eax, eax
    jnz     .be_error
    add     r10, 16                ; next table entry
    inc     ebx
    cmp     ebx, 27
    jb      .be_loop

    ; User function exports (kind=0, index = 27 + i)
    xor     ebx, ebx
.be_user_loop:
    cmp     ebx, r13d
    jae     .be_done_exports
    mov     rdi, rsp
    mov     rsi, [r14 + rbx*8]     ; export name ptr
    mov     edx, [r15 + rbx*4]     ; export name len
    call    writer_append_name
    test    eax, eax
    jnz     .be_error
    mov     rdi, rsp
    mov     sil, 0                 ; function kind
    call    writer_append_byte
    jc      .be_error
    mov     rdi, rsp
    lea     eax, [rbx + 27]        ; function index = 27 + i
    call    writer_append_u32_leb
    test    eax, eax
    jnz     .be_error
    inc     ebx
    jmp     .be_user_loop

.be_done_exports:
    ; Emit export section
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

; Export table: 27 entries of {name_ptr(8), name_len(4), index(4)}
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
    exp_entry str_er_app_lowered_main_count, 28, 26  ; reuse

SECTION .text

; ------------------------------------------------------------------
; emit_start_section(rdi=main_writer)
; Section 8: start = function index 5
; ------------------------------------------------------------------
emit_start_section:
    push    rbp
    mov     rbp, rsp
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
; Section 10: code section with 27 noop bodies + user bodies
; User bodies return i32_const(val) from source
; ------------------------------------------------------------------
emit_code_section:
    push    rbp
    mov     rbp, rsp
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12, rdi               ; main writer
    mov     r13d, ecx              ; user count
    mov     r14, r8                ; export name ptrs
    mov     r15, r9                ; export name lens
    ; Temp writer: 24-byte header + 1024-byte buffer
    sub     rsp, 24 + 1024

    lea     rax, [rsp + 24]
    mov     [rsp], rax
    mov     qword [rsp + 8], 1024
    mov     qword [rsp + 16], 0

    ; code count = 27 + user_count
    mov     rdi, rsp
    lea     eax, [r13 + SUCCESSOR_BASE_FUNCTION_COUNT]
    call    writer_append_u32_leb
    test    eax, eax
    jnz     .cs_error

    ; 27 base function bodies: each is {0x00, 0x0b} = local_count=0, end
    mov     rdi, rsp
    xor     ecx, ecx
.cs_noop_loop:
    ; body size = 2 bytes
    mov     eax, 2
    call    writer_append_u32_leb
    test    eax, eax
    jnz     .cs_error
    mov     rdi, rsp
    mov     sil, 0x00              ; local count = 0
    call    writer_append_byte
    jc      .cs_error
    mov     rdi, rsp
    mov     sil, WASM_OPCODE_END
    call    writer_append_byte
    jc      .cs_error
    inc     ecx
    cmp     ecx, SUCCESSOR_BASE_FUNCTION_COUNT
    jb      .cs_noop_loop

    ; N user function bodies: return i32_const(val)
    xor     r14d, r14d
.cs_user_loop:
    ; Sub-writer at [rsp + 800] for building one body
    lea     rax, [rsp + 824]
    mov     [rsp + 800], rax
    mov     qword [rsp + 808], 224
    mov     qword [rsp + 816], 0

    lea     rdi, [rsp + 800]
    mov     sil, 0x00              ; local count = 0
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

    ; body size
    mov     rdi, rsp
    mov     eax, [rsp + 816]
    call    writer_append_u32_leb
    test    eax, eax
    jnz     .cs_error

    ; body content
    mov     rdi, rsp
    lea     rsi, [rsp + 824]
    mov     edx, [rsp + 816]
    call    writer_append_slice
    jc      .cs_error

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

; ==================================================================
; Main compile pipeline
; ==================================================================

; u32 er_wasm_compiler_compile_wasm(
;     compiler_memory_ptr=rdi, compiler_memory_len=rsi,
;     source_name_ptr=rdx, source_name_len=rcx,
;     source_ptr=r8, source_len=r9)
er_fn er_wasm_compiler_compile_wasm
    push    rbp
    mov     rbp, rsp
    push    r12                     ; compiler_memory_ptr
    push    r13                     ; compiler_memory_len
    push    r14                     ; source_name_ptr
    push    r15                     ; source_name_len
    sub     rsp, 32                 ; local vars

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

    ; Call source_parse(source_ptr=rdi, source_len=rsi)
    mov     rdi, r8                 ; source_ptr
    mov     rsi, r9                 ; source_len

    ; Reset export name count
    mov     dword [export_name_count], 0

    call    source_parse
    jc      .parse_failed            ; carry set on failure

    mov     ecx, [export_name_count]

    ; Check if we have enough memory for output
    ; We need: ~100 bytes overhead + 27 sections * ~20 bytes + N * ~50 bytes
    ; Good enough check: if runtime < 1024, fail
    cmp     r13, 1024
    jb      .mem_too_small

    ; Initialize output writer at the start of compiler_memory
    ; Writer struct on stack: bytes_ptr(8), max_len(8), cur_len(8)
    sub     rsp, 40
    mov     [rsp], r12              ; bytes_ptr = compiler_memory_ptr
    mov     [rsp + 8], r13          ; max_len = compiler_memory_len
    mov     qword [rsp + 16], 0     ; cur_len = 0

    ; Write WASM header (8 bytes: magic + version)
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

    ; Emit export section (base exports + user function exports)
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
    mov     r9d, [export_name_count] ; reuse
    call    emit_code_section
    test    eax, eax
    jnz     .cs_error

    ; Store output
    mov     rax, [rsp + 16]         ; output length
    mov     [compiler_output_len], rax
    mov     [compiler_output_ptr], r12

    ; Set status
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
    ; General compile failure
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
    ; For now, same as compile_wasm (TODO: metadata-only mode)
    jmp     er_wasm_compiler_compile_wasm
