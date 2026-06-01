; EdgeRun AV1 tile-group parser/encoder — x86_64 assembly.
; This handles the conforming single-tile reduced-still path.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/av1_constants.inc"

extern er_av1_bits_read_init
extern er_av1_bits_read
extern er_av1_bits_write_init
extern er_av1_bits_write
extern er_av1_bits_bytes_written
extern er_av1_symbol_init
extern er_av1_symbol_exit

%macro tile_write_bits 2
    mov     rdi, rsp
    mov     esi, %1
    mov     edx, %2
    call    er_av1_bits_write
    er_check_nonzero edx, .done
%endmacro

SECTION .text

; er_av1_tile_group_decode_uniform(payload, len, tile_info_desc, tile_entries, entry_cap)
; Decodes uniform multi-tile payload sizes into tile_entries.
; rdi=payload, esi=len, rdx=tile_info_desc, rcx=entries, r8d=entry_cap.
; Each entry receives qword offset and dword length. Returns eax=bytes consumed.
er_fn er_av1_tile_group_decode_uniform
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc 8
    er_check_zero rdi, .invalid_param
    er_check_zero rdx, .invalid_param
    er_check_zero rcx, .invalid_param
    cmp     byte [rdx + AV1_TILE_INFO_UNIFORM], 1
    jne     .unsupported
    mov     r12, rdi
    mov     r13, rcx
    mov     r14d, esi
    mov     r15d, [rdx + AV1_TILE_INFO_COUNT]
    er_check_zero r15d, .invalid_param
    cmp     r15d, r8d
    ja      .invalid_param
    movzx   r11d, byte [rdx + AV1_TILE_INFO_TILE_SIZE_BYTES]
    cmp     r11d, AV1_TILE_SIZE_BYTES_MIN
    jb      .invalid_param
    cmp     r11d, AV1_TILE_SIZE_BYTES_MAX
    ja      .invalid_param
    mov     eax, [rdx + AV1_TILE_INFO_COLS]
    er_check_zero eax, .invalid_param
    mov     [rsp], eax
    xor     ebx, ebx
    xor     r10d, r10d
.loop:
    cmp     r10d, r15d
    jae     .ok
    imul    eax, r10d, AV1_TILE_ENTRY_SIZE
    lea     r9, [r13 + rax]
    mov     eax, r15d
    dec     eax
    cmp     r10d, eax
    je      .last_tile
    mov     eax, ebx
    add     eax, r11d
    jc      .corrupt
    cmp     eax, r14d
    ja      .no_data
    xor     eax, eax
    xor     ecx, ecx
    lea     r8, [r12 + rbx]
.read_size:
    cmp     ecx, r11d
    jae     .size_done
    movzx   edx, byte [r8 + rcx]
    push    rcx
    shl     ecx, 3
    shl     edx, cl
    pop     rcx
    or      eax, edx
    inc     ecx
    jmp     .read_size
.size_done:
    add     ebx, r11d
    cmp     eax, AV1_LEB128_U32_MAX
    je      .corrupt
    inc     eax
    mov     edx, ebx
    add     edx, eax
    jc      .corrupt
    cmp     edx, r14d
    ja      .no_data
    mov     [r9 + AV1_TILE_ENTRY_OFFSET], rbx
    mov     [r9 + AV1_TILE_ENTRY_LEN], eax
    mov     ebx, edx
    mov     eax, r10d
    xor     edx, edx
    div     dword [rsp]
    mov     [r9 + AV1_TILE_ENTRY_ROW], eax
    mov     [r9 + AV1_TILE_ENTRY_COL], edx
    inc     r10d
    jmp     .loop
.last_tile:
    mov     eax, r14d
    sub     eax, ebx
    mov     [r9 + AV1_TILE_ENTRY_OFFSET], rbx
    mov     [r9 + AV1_TILE_ENTRY_LEN], eax
    mov     eax, r10d
    xor     edx, edx
    div     dword [rsp]
    mov     [r9 + AV1_TILE_ENTRY_ROW], eax
    mov     [r9 + AV1_TILE_ENTRY_COL], edx
    mov     ebx, r14d
    inc     r10d
    jmp     .loop
.ok:
    mov     eax, ebx
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done
.unsupported:
    xor     eax, eax
    er_err  ERROR_UNSUPPORTED
    jmp     .done
.no_data:
    xor     eax, eax
    er_err  ERROR_NO_DATA
    jmp     .done
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.done:
    er_stack_free 8
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_tile_group_encode_uniform(out, cap, tile_info_desc, tile_entries, entry_count)
; Encodes uniform multi-tile payload sizes from entries.
; Entries use qword source pointer and dword length. Returns eax=bytes written.
er_fn er_av1_tile_group_encode_uniform
    er_push rbx, r12, r13, r14, r15
    er_check_zero rdi, .invalid_param
    er_check_zero rdx, .invalid_param
    er_check_zero rcx, .invalid_param
    cmp     byte [rdx + AV1_TILE_INFO_UNIFORM], 1
    jne     .unsupported
    mov     r12, rdi
    mov     r13, rcx
    mov     r14d, esi
    mov     r15d, r8d
    er_check_zero r15d, .invalid_param
    cmp     r15d, [rdx + AV1_TILE_INFO_COUNT]
    jne     .invalid_param
    movzx   r11d, byte [rdx + AV1_TILE_INFO_TILE_SIZE_BYTES]
    cmp     r11d, AV1_TILE_SIZE_BYTES_MIN
    jb      .invalid_param
    cmp     r11d, AV1_TILE_SIZE_BYTES_MAX
    ja      .invalid_param
    xor     ebx, ebx
    xor     r10d, r10d
.loop:
    cmp     r10d, r15d
    jae     .ok
    imul    eax, r10d, AV1_TILE_ENTRY_SIZE
    lea     r9, [r13 + rax]
    mov     rsi, [r9 + AV1_TILE_ENTRY_PTR]
    er_check_zero rsi, .invalid_param
    mov     ecx, [r9 + AV1_TILE_ENTRY_LEN]
    mov     r8d, ecx
    mov     eax, r15d
    dec     eax
    cmp     r10d, eax
    je      .copy_tile
    er_check_zero ecx, .invalid_param
    mov     eax, ebx
    add     eax, r11d
    jc      .corrupt
    cmp     eax, r14d
    ja      .no_space
    mov     eax, ecx
    dec     eax
    xor     edx, edx
    lea     rdi, [r12 + rbx]
.write_size:
    cmp     edx, r11d
    jae     .after_size
    mov     byte [rdi + rdx], al
    shr     eax, 8
    inc     edx
    jmp     .write_size
.after_size:
    er_check_nonzero eax, .corrupt
    add     ebx, r11d
.copy_tile:
    mov     eax, ebx
    add     eax, ecx
    jc      .corrupt
    cmp     eax, r14d
    ja      .no_space
    lea     rdi, [r12 + rbx]
    call    copy_bytes
    add     ebx, r8d
    inc     r10d
    jmp     .loop
.ok:
    mov     eax, ebx
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done
.unsupported:
    xor     eax, eax
    er_err  ERROR_UNSUPPORTED
    jmp     .done
.no_space:
    xor     eax, eax
    er_err  ERROR_NO_SPACE
    jmp     .done
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.done:
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_tile_group_decode(payload, len, tile_info_desc, tile_group_desc, tile_entries, entry_cap)
; Decodes tile_start/tile_end header fields plus uniform tile payload sizes.
; rdi=payload, esi=len, rdx=tile_info_desc, rcx=tile_group_desc, r8=entries, r9d=entry_cap.
; Entry offsets are relative to the tile-group OBU payload.
er_fn er_av1_tile_group_decode
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc AV1_BITS_SIZE + 8
    er_check_zero rdi, .invalid_param
    er_check_zero rdx, .invalid_param
    er_check_zero rcx, .invalid_param
    er_check_zero r8, .invalid_param
    cmp     byte [rdx + AV1_TILE_INFO_UNIFORM], 1
    jne     .unsupported
    mov     r12, rdi
    mov     ebx, esi
    mov     r13, rdx
    mov     r14, rcx
    mov     r15, r8
    mov     [rsp + AV1_BITS_SIZE], r9d
    mov     eax, [r13 + AV1_TILE_INFO_COUNT]
    er_check_zero eax, .invalid_param
    mov     dword [r14 + AV1_TILE_GROUP_START], 0
    dec     eax
    mov     [r14 + AV1_TILE_GROUP_END], eax
    mov     dword [r14 + AV1_TILE_GROUP_DATA_OFFSET], 0
    mov     [r14 + AV1_TILE_GROUP_DATA_LEN], ebx
    cmp     dword [r13 + AV1_TILE_INFO_COUNT], 1
    je      .range_ready

    mov     rdx, rbx
    mov     rsi, r12
    mov     rdi, rsp
    call    er_av1_bits_read_init
    er_check_nonzero edx, .done
    mov     rdi, rsp
    mov     esi, 1
    call    er_av1_bits_read
    er_check_nonzero edx, .done
    er_check_zero eax, .byte_align
    movzx   esi, byte [r13 + AV1_TILE_INFO_COLS_LOG2]
    add     sil, [r13 + AV1_TILE_INFO_ROWS_LOG2]
    er_check_zero esi, .corrupt
    mov     rdi, rsp
    call    er_av1_bits_read
    er_check_nonzero edx, .done
    cmp     eax, [r13 + AV1_TILE_INFO_COUNT]
    jae     .corrupt
    mov     [r14 + AV1_TILE_GROUP_START], eax
    movzx   esi, byte [r13 + AV1_TILE_INFO_COLS_LOG2]
    add     sil, [r13 + AV1_TILE_INFO_ROWS_LOG2]
    mov     rdi, rsp
    call    er_av1_bits_read
    er_check_nonzero edx, .done
    cmp     eax, [r13 + AV1_TILE_INFO_COUNT]
    jae     .corrupt
    cmp     eax, [r14 + AV1_TILE_GROUP_START]
    jb      .corrupt
    mov     [r14 + AV1_TILE_GROUP_END], eax
.byte_align:
    mov     ecx, [rsp + AV1_BITS_POS]
    neg     ecx
    and     ecx, 7
    er_check_zero ecx, .header_done
    mov     rdi, rsp
    mov     esi, ecx
    call    er_av1_bits_read
    er_check_nonzero edx, .done
    er_check_nonzero eax, .corrupt
.header_done:
    mov     eax, [rsp + AV1_BITS_POS]
    shr     eax, 3
    cmp     eax, ebx
    ja      .no_data
    mov     [r14 + AV1_TILE_GROUP_DATA_OFFSET], eax
    mov     edx, ebx
    sub     edx, eax
    mov     [r14 + AV1_TILE_GROUP_DATA_LEN], edx

.range_ready:
    mov     r11d, [r14 + AV1_TILE_GROUP_END]
    sub     r11d, [r14 + AV1_TILE_GROUP_START]
    jc      .corrupt
    inc     r11d
    cmp     r11d, [rsp + AV1_BITS_SIZE]
    ja      .invalid_param
    movzx   r10d, byte [r13 + AV1_TILE_INFO_TILE_SIZE_BYTES]
    cmp     r10d, AV1_TILE_SIZE_BYTES_MIN
    jb      .invalid_param
    cmp     r10d, AV1_TILE_SIZE_BYTES_MAX
    ja      .invalid_param
    cmp     dword [r13 + AV1_TILE_INFO_COLS], 0
    je      .invalid_param
    mov     r8d, [r14 + AV1_TILE_GROUP_DATA_OFFSET]
    mov     esi, [r14 + AV1_TILE_GROUP_DATA_LEN]
    xor     ecx, ecx
    xor     r9d, r9d
.tile_loop:
    cmp     r9d, r11d
    jae     .ok
    imul    eax, r9d, AV1_TILE_ENTRY_SIZE
    lea     rdi, [r15 + rax]
    mov     eax, r11d
    dec     eax
    cmp     r9d, eax
    je      .last_tile
    mov     eax, ecx
    add     eax, r10d
    jc      .corrupt
    cmp     eax, esi
    ja      .no_data
    mov     eax, [r14 + AV1_TILE_GROUP_DATA_OFFSET]
    add     eax, ecx
    lea     r8, [r12 + rax]
    xor     eax, eax
    xor     edx, edx
.read_size:
    cmp     edx, r10d
    jae     .size_done
    movzx   ebx, byte [r8 + rdx]
    push    rcx
    mov     ecx, edx
    shl     ecx, 3
    shl     ebx, cl
    pop     rcx
    or      eax, ebx
    inc     edx
    jmp     .read_size
.size_done:
    add     ecx, r10d
    cmp     eax, AV1_LEB128_U32_MAX
    je      .corrupt
    inc     eax
    mov     edx, ecx
    add     edx, eax
    jc      .corrupt
    cmp     edx, esi
    ja      .no_data
    mov     ebx, [r14 + AV1_TILE_GROUP_DATA_OFFSET]
    add     ebx, ecx
    mov     [rdi + AV1_TILE_ENTRY_OFFSET], ebx
    mov     [rdi + AV1_TILE_ENTRY_LEN], eax
    mov     ecx, edx
    mov     eax, [r14 + AV1_TILE_GROUP_START]
    add     eax, r9d
    xor     edx, edx
    div     dword [r13 + AV1_TILE_INFO_COLS]
    mov     [rdi + AV1_TILE_ENTRY_ROW], eax
    mov     [rdi + AV1_TILE_ENTRY_COL], edx
    inc     r9d
    jmp     .tile_loop
.last_tile:
    mov     eax, esi
    sub     eax, ecx
    mov     ebx, [r14 + AV1_TILE_GROUP_DATA_OFFSET]
    add     ebx, ecx
    mov     [rdi + AV1_TILE_ENTRY_OFFSET], ebx
    mov     [rdi + AV1_TILE_ENTRY_LEN], eax
    mov     eax, [r14 + AV1_TILE_GROUP_START]
    add     eax, r9d
    xor     edx, edx
    div     dword [r13 + AV1_TILE_INFO_COLS]
    mov     [rdi + AV1_TILE_ENTRY_ROW], eax
    mov     [rdi + AV1_TILE_ENTRY_COL], edx
    mov     ecx, esi
    inc     r9d
    jmp     .tile_loop
.ok:
    mov     eax, [r14 + AV1_TILE_GROUP_DATA_OFFSET]
    add     eax, ecx
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done
.unsupported:
    xor     eax, eax
    er_err  ERROR_UNSUPPORTED
    jmp     .done
.no_data:
    xor     eax, eax
    er_err  ERROR_NO_DATA
    jmp     .done
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.done:
    er_stack_free AV1_BITS_SIZE + 8
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_tile_group_encode(out, cap, tile_info_desc, tile_group_desc, tile_entries, entry_count)
; Encodes tile-group header fields plus uniform tile payload sizes.
; rdi=out, esi=cap, rdx=tile_info_desc, rcx=tile_group_desc, r8=entries, r9d=entry_count.
er_fn er_av1_tile_group_encode
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc AV1_BITS_SIZE + 8
    er_check_zero rdi, .invalid_param
    er_check_zero rdx, .invalid_param
    er_check_zero rcx, .invalid_param
    er_check_zero r8, .invalid_param
    cmp     byte [rdx + AV1_TILE_INFO_UNIFORM], 1
    jne     .unsupported
    mov     r12, rdi
    mov     ebx, esi
    mov     r13, rdx
    mov     r14, rcx
    mov     r15, r8
    mov     [rsp + AV1_BITS_SIZE], r9d
    mov     eax, [r13 + AV1_TILE_INFO_COUNT]
    er_check_zero eax, .invalid_param
    mov     r11d, [r14 + AV1_TILE_GROUP_END]
    sub     r11d, [r14 + AV1_TILE_GROUP_START]
    jc      .corrupt
    inc     r11d
    cmp     r11d, r9d
    jne     .invalid_param
    mov     eax, [r14 + AV1_TILE_GROUP_END]
    cmp     eax, [r13 + AV1_TILE_INFO_COUNT]
    jae     .corrupt
    movzx   r10d, byte [r13 + AV1_TILE_INFO_TILE_SIZE_BYTES]
    cmp     r10d, AV1_TILE_SIZE_BYTES_MIN
    jb      .invalid_param
    cmp     r10d, AV1_TILE_SIZE_BYTES_MAX
    ja      .invalid_param
    xor     r8d, r8d
    cmp     dword [r13 + AV1_TILE_INFO_COUNT], 1
    je      .payload

    mov     edx, ebx
    mov     rsi, r12
    mov     rdi, rsp
    call    er_av1_bits_write_init
    er_check_nonzero edx, .done
    mov     eax, [r13 + AV1_TILE_INFO_COUNT]
    dec     eax
    cmp     dword [r14 + AV1_TILE_GROUP_START], 0
    jne     .write_range
    cmp     [r14 + AV1_TILE_GROUP_END], eax
    jne     .write_range
    mov     rdi, rsp
    xor     esi, esi
    mov     edx, 1
    call    er_av1_bits_write
    er_check_nonzero edx, .done
    jmp     .pad_header
.write_range:
    mov     rdi, rsp
    mov     esi, 1
    mov     edx, 1
    call    er_av1_bits_write
    er_check_nonzero edx, .done
    movzx   edx, byte [r13 + AV1_TILE_INFO_COLS_LOG2]
    add     dl, [r13 + AV1_TILE_INFO_ROWS_LOG2]
    er_check_zero edx, .corrupt
    mov     esi, [r14 + AV1_TILE_GROUP_START]
    mov     rdi, rsp
    call    er_av1_bits_write
    er_check_nonzero edx, .done
    movzx   edx, byte [r13 + AV1_TILE_INFO_COLS_LOG2]
    add     dl, [r13 + AV1_TILE_INFO_ROWS_LOG2]
    mov     esi, [r14 + AV1_TILE_GROUP_END]
    mov     rdi, rsp
    call    er_av1_bits_write
    er_check_nonzero edx, .done
.pad_header:
    mov     edx, [rsp + AV1_BITS_POS]
    neg     edx
    and     edx, 7
    er_check_zero edx, .header_written
    mov     rdi, rsp
    xor     esi, esi
    call    er_av1_bits_write
    er_check_nonzero edx, .done
.header_written:
    mov     rdi, rsp
    call    er_av1_bits_bytes_written
    er_check_nonzero edx, .done
    mov     r8d, eax
    mov     [r14 + AV1_TILE_GROUP_DATA_OFFSET], eax
.payload:
    xor     ecx, ecx
    xor     r9d, r9d
.payload_loop:
    cmp     r9d, [rsp + AV1_BITS_SIZE]
    jae     .payload_ok
    imul    eax, r9d, AV1_TILE_ENTRY_SIZE
    lea     rdi, [r15 + rax]
    mov     rsi, [rdi + AV1_TILE_ENTRY_PTR]
    er_check_zero rsi, .invalid_param
    mov     eax, [rdi + AV1_TILE_ENTRY_LEN]
    mov     r11d, eax
    mov     edx, [rsp + AV1_BITS_SIZE]
    dec     edx
    cmp     r9d, edx
    je      .copy_tile
    er_check_zero eax, .invalid_param
    mov     edx, r8d
    add     edx, ecx
    jc      .corrupt
    add     edx, r10d
    jc      .corrupt
    cmp     edx, ebx
    ja      .no_space
    mov     eax, r11d
    dec     eax
    xor     edx, edx
    lea     rdi, [r12 + r8]
    add     rdi, rcx
.write_size:
    cmp     edx, r10d
    jae     .after_size
    mov     byte [rdi + rdx], al
    shr     eax, 8
    inc     edx
    jmp     .write_size
.after_size:
    er_check_nonzero eax, .corrupt
    add     ecx, r10d
.copy_tile:
    mov     eax, r8d
    add     eax, ecx
    jc      .corrupt
    add     eax, r11d
    jc      .corrupt
    cmp     eax, ebx
    ja      .no_space
    lea     rdi, [r12 + r8]
    add     rdi, rcx
    mov     [rsp + AV1_BITS_SIZE + 4], ecx
    mov     ecx, r11d
    call    copy_bytes
    mov     ecx, [rsp + AV1_BITS_SIZE + 4]
    add     ecx, r11d
    inc     r9d
    jmp     .payload_loop
.payload_ok:
    mov     [r14 + AV1_TILE_GROUP_DATA_LEN], ecx
    mov     eax, r8d
    add     eax, ecx
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done
.unsupported:
    xor     eax, eax
    er_err  ERROR_UNSUPPORTED
    jmp     .done
.no_space:
    xor     eax, eax
    er_err  ERROR_NO_SPACE
    jmp     .done
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.done:
    er_stack_free AV1_BITS_SIZE + 8
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_tile_info_encode(out, cap, tile_info_desc)
; Encodes the supported uniform tile-info subset:
; uniform flag, cols_log2, rows_log2, context_update_tile_id, tile_size_bytes.
; rdi=out, esi=cap, rdx=tile_info_desc. Returns eax=bytes, rdx=error.
er_fn er_av1_tile_info_encode
    er_push rbx, r12
    er_stack_alloc AV1_BITS_SIZE
    er_check_zero rdi, .invalid_param
    er_check_zero rdx, .invalid_param
    mov     r12, rdx
    cmp     byte [r12 + AV1_TILE_INFO_UNIFORM], 1
    jne     .unsupported
    cmp     byte [r12 + AV1_TILE_INFO_COLS_LOG2], AV1_TILE_LOG2_MAX
    ja      .invalid_param
    cmp     byte [r12 + AV1_TILE_INFO_ROWS_LOG2], AV1_TILE_LOG2_MAX
    ja      .invalid_param
    cmp     byte [r12 + AV1_TILE_INFO_TILE_SIZE_BYTES], AV1_TILE_SIZE_BYTES_MIN
    jb      .invalid_param
    cmp     byte [r12 + AV1_TILE_INFO_TILE_SIZE_BYTES], AV1_TILE_SIZE_BYTES_MAX
    ja      .invalid_param
    mov     rdx, rsi
    mov     rsi, rdi
    mov     rdi, rsp
    call    er_av1_bits_write_init
    er_check_nonzero edx, .done
    tile_write_bits 1, 1
    movzx   esi, byte [r12 + AV1_TILE_INFO_COLS_LOG2]
    mov     rdi, rsp
    mov     edx, AV1_TILE_LOG2_BITS
    call    er_av1_bits_write
    er_check_nonzero edx, .done
    movzx   esi, byte [r12 + AV1_TILE_INFO_ROWS_LOG2]
    mov     rdi, rsp
    mov     edx, AV1_TILE_LOG2_BITS
    call    er_av1_bits_write
    er_check_nonzero edx, .done
    movzx   ebx, byte [r12 + AV1_TILE_INFO_COLS_LOG2]
    add     bl, [r12 + AV1_TILE_INFO_ROWS_LOG2]
    er_check_zero ebx, .tile_size_bytes
    mov     esi, [r12 + AV1_TILE_INFO_CONTEXT_UPDATE_ID]
    mov     edx, ebx
    mov     rdi, rsp
    call    er_av1_bits_write
    er_check_nonzero edx, .done
.tile_size_bytes:
    movzx   esi, byte [r12 + AV1_TILE_INFO_TILE_SIZE_BYTES]
    dec     esi
    mov     rdi, rsp
    mov     edx, AV1_TILE_SIZE_BYTES_BITS
    call    er_av1_bits_write
    er_check_nonzero edx, .done
    mov     rdi, rsp
    call    er_av1_bits_bytes_written
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done
.unsupported:
    xor     eax, eax
    er_err  ERROR_UNSUPPORTED
.done:
    er_stack_free AV1_BITS_SIZE
    er_pop  rbx, r12
    er_ret

; er_av1_tile_info_decode(payload, len, tile_info_desc)
; Decodes the supported uniform tile-info subset.
; rdi=payload, esi=len, rdx=tile_info_desc. Returns eax=bytes_consumed, rdx=error.
er_fn er_av1_tile_info_decode
    er_push rbx, r12
    er_stack_alloc AV1_BITS_SIZE
    er_check_zero rdx, .invalid_param
    mov     r12, rdx
    mov     rdx, rsi
    mov     rsi, rdi
    mov     rdi, rsp
    call    er_av1_bits_read_init
    er_check_nonzero edx, .done
    mov     rdi, rsp
    mov     esi, 1
    call    er_av1_bits_read
    er_check_nonzero edx, .done
    cmp     eax, 1
    jne     .unsupported
    mov     [r12 + AV1_TILE_INFO_UNIFORM], al
    mov     rdi, rsp
    mov     esi, AV1_TILE_LOG2_BITS
    call    er_av1_bits_read
    er_check_nonzero edx, .done
    cmp     eax, AV1_TILE_LOG2_MAX
    ja      .corrupt
    mov     [r12 + AV1_TILE_INFO_COLS_LOG2], al
    mov     ebx, 1
    mov     ecx, eax
    shl     ebx, cl
    mov     [r12 + AV1_TILE_INFO_COLS], ebx
    mov     rdi, rsp
    mov     esi, AV1_TILE_LOG2_BITS
    call    er_av1_bits_read
    er_check_nonzero edx, .done
    cmp     eax, AV1_TILE_LOG2_MAX
    ja      .corrupt
    mov     [r12 + AV1_TILE_INFO_ROWS_LOG2], al
    mov     ecx, eax
    mov     eax, 1
    shl     eax, cl
    mov     [r12 + AV1_TILE_INFO_ROWS], eax
    imul    eax, [r12 + AV1_TILE_INFO_COLS]
    mov     [r12 + AV1_TILE_INFO_COUNT], eax
    movzx   ebx, byte [r12 + AV1_TILE_INFO_COLS_LOG2]
    add     bl, [r12 + AV1_TILE_INFO_ROWS_LOG2]
    er_check_zero ebx, .read_tile_size
    mov     rdi, rsp
    mov     esi, ebx
    call    er_av1_bits_read
    er_check_nonzero edx, .done
    mov     [r12 + AV1_TILE_INFO_CONTEXT_UPDATE_ID], eax
    jmp     .read_tile_size
.read_tile_size:
    mov     rdi, rsp
    mov     esi, AV1_TILE_SIZE_BYTES_BITS
    call    er_av1_bits_read
    er_check_nonzero edx, .done
    inc     eax
    mov     [r12 + AV1_TILE_INFO_TILE_SIZE_BYTES], al
    mov     eax, [rsp + AV1_BITS_POS]
    add     eax, 7
    shr     eax, 3
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done
.unsupported:
    xor     eax, eax
    er_err  ERROR_UNSUPPORTED
    jmp     .done
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.done:
    er_stack_free AV1_BITS_SIZE
    er_pop  rbx, r12
    er_ret

; er_av1_tile_entries_validate_entropy(payload, len, tile_entries, entry_count)
; Validates each tile entry as an entropy-coded tile payload with OBU trailing bits.
; rdi=tile-group payload base, esi=payload len, rdx=entries, ecx=entry_count.
er_fn er_av1_tile_entries_validate_entropy
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc AV1_SYMBOL_SIZE
    er_check_zero rdi, .invalid_param
    er_check_zero rdx, .invalid_param
    er_check_zero ecx, .invalid_param
    mov     r12, rdi
    mov     r13, rdx
    mov     r14d, esi
    mov     r15d, ecx
    xor     ebx, ebx
.loop:
    cmp     ebx, r15d
    jae     .ok
    imul    eax, ebx, AV1_TILE_ENTRY_SIZE
    lea     r11, [r13 + rax]
    mov     r8, [r11 + AV1_TILE_ENTRY_OFFSET]
    mov     r9d, [r11 + AV1_TILE_ENTRY_LEN]
    er_check_zero r9d, .invalid_param
    mov     eax, r14d
    cmp     r8, rax
    ja      .no_data
    mov     rax, r8
    add     rax, r9
    jc      .corrupt
    mov     edx, r14d
    cmp     rax, rdx
    ja      .no_data
    lea     rsi, [r12 + r8]
    mov     edx, r9d
    mov     rdi, rsp
    call    er_av1_symbol_init
    er_check_nonzero edx, .done
    mov     rdi, rsp
    call    er_av1_symbol_exit
    er_check_nonzero edx, .done
    inc     ebx
    jmp     .loop
.ok:
    mov     eax, r15d
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done
.no_data:
    xor     eax, eax
    er_err  ERROR_NO_DATA
    jmp     .done
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.done:
    er_stack_free AV1_SYMBOL_SIZE
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_tile_group_decode_entropy(payload, len, tile_info_desc, tile_group_desc, tile_entries, entry_cap)
; Decodes a tile group and validates every decoded tile payload with the entropy decoder lifecycle.
; rdi=payload, esi=len, rdx=tile_info_desc, rcx=tile_group_desc, r8=entries, r9d=entry_cap.
er_fn er_av1_tile_group_decode_entropy
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc 8
    er_check_zero rdi, .invalid_param
    er_check_zero rdx, .invalid_param
    er_check_zero rcx, .invalid_param
    er_check_zero r8, .invalid_param
    mov     r12, rdi
    mov     ebx, esi
    mov     r13, rcx
    mov     r14, r8
    mov     r15d, r9d
    mov     [rsp], rdx
    call    er_av1_tile_group_decode
    er_check_nonzero edx, .done
    mov     r9d, [r13 + AV1_TILE_GROUP_END]
    sub     r9d, [r13 + AV1_TILE_GROUP_START]
    jc      .corrupt
    inc     r9d
    cmp     r9d, r15d
    ja      .invalid_param
    mov     rdi, r12
    mov     esi, ebx
    mov     rdx, r14
    mov     ecx, r9d
    call    er_av1_tile_entries_validate_entropy
    er_check_nonzero edx, .done
    mov     eax, [r13 + AV1_TILE_GROUP_DATA_OFFSET]
    add     eax, [r13 + AV1_TILE_GROUP_DATA_LEN]
    jc      .corrupt
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.done:
    er_stack_free 8
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_tile_group_decode_single(payload, len, desc) -> eax=bytes_consumed, rdx=error
; rdi=payload, esi=len, rdx=desc. For NumTiles=1, tile data is the whole payload.
er_fn er_av1_tile_group_decode_single
    er_check_zero rdi, .invalid_param
    er_check_zero rdx, .invalid_param
    mov     dword [rdx + AV1_TILE_GROUP_START], 0
    mov     dword [rdx + AV1_TILE_GROUP_END], 0
    mov     dword [rdx + AV1_TILE_GROUP_DATA_OFFSET], 0
    mov     [rdx + AV1_TILE_GROUP_DATA_LEN], esi
    mov     eax, esi
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret

; er_av1_tile_group_encode_single(out, cap, tile_ptr, tile_len) -> eax=bytes, rdx=error
; rdi=out, esi=cap, rdx=tile_ptr, ecx=tile_len.
er_fn er_av1_tile_group_encode_single
    er_push rbx, r12, r13
    er_check_zero rdi, .invalid_param
    er_check_zero rdx, .invalid_param
    cmp     ecx, esi
    ja      .no_space
    mov     r12, rdi
    mov     r13, rdx
    mov     ebx, ecx
    er_check_zero ebx, .ok
.loop:
    mov     al, [r13]
    mov     [r12], al
    inc     r13
    inc     r12
    dec     ebx
    jnz     .loop
.ok:
    mov     eax, ecx
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done
.no_space:
    xor     eax, eax
    er_err  ERROR_NO_SPACE
.done:
    er_pop  rbx, r12, r13
    er_ret

; er_av1_tile_raw420_size(width, height) -> eax=Y+U+V bytes, rdx=error
; edi=width, esi=height. 8-bit 4:2:0 planes, chroma dimensions are ceil / 2.
er_fn er_av1_tile_raw420_size
    er_check_zero edi, .invalid_param
    er_check_zero esi, .invalid_param
    mov     eax, edi
    mul     esi
    er_check_nonzero edx, .corrupt
    mov     r8d, eax
    mov     eax, edi
    cmp     eax, AV1_LEB128_U32_MAX
    je      .corrupt
    inc     eax
    shr     eax, 1
    mov     ecx, esi
    cmp     ecx, AV1_LEB128_U32_MAX
    je      .corrupt
    inc     ecx
    shr     ecx, 1
    mul     ecx
    er_check_nonzero edx, .corrupt
    mov     ecx, eax
    add     eax, ecx
    jc      .corrupt
    add     eax, r8d
    jc      .corrupt
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
    er_ret

; er_av1_tile_raw420_fill_desc(desc, width, height, y, u, v)
; rdi=desc, esi=width, edx=height, rcx=y, r8=u, r9=v. Returns eax=total bytes.
er_fn er_av1_tile_raw420_fill_desc
    er_push rbx, r12, r13, r14, r15
    er_check_zero rdi, .invalid_param
    er_check_zero rcx, .invalid_param
    er_check_zero r8, .invalid_param
    er_check_zero r9, .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     r14d, edx
    mov     r15, rcx
    mov     rbx, r8
    mov     [r12 + AV1_IMAGE_V_PTR], r9
    mov     edi, r13d
    mov     esi, r14d
    call    er_av1_tile_raw420_size
    er_check_nonzero edx, .done
    mov     r10d, eax
    mov     eax, r13d
    mul     r14d
    er_check_nonzero edx, .corrupt
    mov     [r12 + AV1_IMAGE_Y_LEN], eax
    mov     ecx, r10d
    sub     ecx, eax
    shr     ecx, 1
    mov     [r12 + AV1_IMAGE_U_LEN], ecx
    mov     [r12 + AV1_IMAGE_V_LEN], ecx
    mov     [r12 + AV1_IMAGE_WIDTH], r13d
    mov     [r12 + AV1_IMAGE_HEIGHT], r14d
    mov     [r12 + AV1_IMAGE_Y_PTR], r15
    mov     [r12 + AV1_IMAGE_U_PTR], rbx
    mov     eax, r10d
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.done:
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_tile_raw420_validate(image_desc) -> eax=total bytes, rdx=error
; Verifies pointers and that Y/U/V lengths match 8-bit 4:2:0 dimensions.
er_fn er_av1_tile_raw420_validate
    er_push rbx, r12, r13
    er_check_zero rdi, .invalid_param
    mov     r12, rdi
    cmp     dword [r12 + AV1_IMAGE_WIDTH], 0
    je      .invalid_param
    cmp     dword [r12 + AV1_IMAGE_HEIGHT], 0
    je      .invalid_param
    cmp     qword [r12 + AV1_IMAGE_Y_PTR], 0
    je      .invalid_param
    cmp     qword [r12 + AV1_IMAGE_U_PTR], 0
    je      .invalid_param
    cmp     qword [r12 + AV1_IMAGE_V_PTR], 0
    je      .invalid_param
    mov     edi, [r12 + AV1_IMAGE_WIDTH]
    mov     esi, [r12 + AV1_IMAGE_HEIGHT]
    call    er_av1_tile_raw420_size
    er_check_nonzero edx, .done
    mov     r13d, eax
    mov     eax, [r12 + AV1_IMAGE_WIDTH]
    mul     dword [r12 + AV1_IMAGE_HEIGHT]
    er_check_nonzero edx, .corrupt
    cmp     [r12 + AV1_IMAGE_Y_LEN], eax
    jne     .corrupt
    mov     ebx, r13d
    sub     ebx, eax
    jc      .corrupt
    shr     ebx, 1
    cmp     [r12 + AV1_IMAGE_U_LEN], ebx
    jne     .corrupt
    cmp     [r12 + AV1_IMAGE_V_LEN], ebx
    jne     .corrupt
    mov     eax, r13d
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.done:
    er_pop  rbx, r12, r13
    er_ret

; er_av1_tile_raw420_encode(out, cap, image_desc) -> eax=bytes, rdx=error
; Copies Y, U, V planes from image_desc into a contiguous tile payload.
er_fn er_av1_tile_raw420_encode
    er_push rbx, r12, r13, r14
    er_check_zero rdi, .invalid_param
    er_check_zero rdx, .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     r14, rdx
    mov     rdi, r14
    call    er_av1_tile_raw420_validate
    er_check_nonzero edx, .done
    cmp     eax, r13d
    ja      .no_space
    mov     ebx, eax
    mov     rdi, r12
    mov     rsi, [r14 + AV1_IMAGE_Y_PTR]
    mov     ecx, [r14 + AV1_IMAGE_Y_LEN]
    call    copy_bytes
    mov     ecx, [r14 + AV1_IMAGE_Y_LEN]
    add     r12, rcx
    mov     rdi, r12
    mov     rsi, [r14 + AV1_IMAGE_U_PTR]
    mov     ecx, [r14 + AV1_IMAGE_U_LEN]
    call    copy_bytes
    mov     ecx, [r14 + AV1_IMAGE_U_LEN]
    add     r12, rcx
    mov     rdi, r12
    mov     rsi, [r14 + AV1_IMAGE_V_PTR]
    mov     ecx, [r14 + AV1_IMAGE_V_LEN]
    call    copy_bytes
    mov     eax, ebx
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done
.no_space:
    xor     eax, eax
    er_err  ERROR_NO_SPACE
    jmp     .done
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.done:
    er_pop  rbx, r12, r13, r14
    er_ret

; er_av1_tile_raw420_decode(payload, len, image_desc) -> eax=bytes, rdx=error
; Copies a contiguous raw 4:2:0 tile payload into Y, U, V planes in image_desc.
er_fn er_av1_tile_raw420_decode
    er_push rbx, r12, r13, r14
    er_check_zero rdi, .invalid_param
    er_check_zero rdx, .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     r14, rdx
    mov     rdi, r14
    call    er_av1_tile_raw420_validate
    er_check_nonzero edx, .done
    cmp     eax, r13d
    ja      .no_data
    mov     ebx, eax
    mov     rdi, [r14 + AV1_IMAGE_Y_PTR]
    mov     rsi, r12
    mov     ecx, [r14 + AV1_IMAGE_Y_LEN]
    call    copy_bytes
    mov     ecx, [r14 + AV1_IMAGE_Y_LEN]
    add     r12, rcx
    mov     rdi, [r14 + AV1_IMAGE_U_PTR]
    mov     rsi, r12
    mov     ecx, [r14 + AV1_IMAGE_U_LEN]
    call    copy_bytes
    mov     ecx, [r14 + AV1_IMAGE_U_LEN]
    add     r12, rcx
    mov     rdi, [r14 + AV1_IMAGE_V_PTR]
    mov     rsi, r12
    mov     ecx, [r14 + AV1_IMAGE_V_LEN]
    call    copy_bytes
    mov     eax, ebx
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done
.no_data:
    xor     eax, eax
    er_err  ERROR_NO_DATA
    jmp     .done
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.done:
    er_pop  rbx, r12, r13, r14
    er_ret

copy_bytes:
    er_check_zero ecx, .done
.loop:
    mov     al, [rsi]
    mov     [rdi], al
    inc     rsi
    inc     rdi
    dec     ecx
    jnz     .loop
.done:
    ret
