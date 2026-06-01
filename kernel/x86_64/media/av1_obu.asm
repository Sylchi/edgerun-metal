; EdgeRun AV1 OBU header codec — x86_64 assembly.
; Covers deterministic AV1 Open Bitstream Unit header encode/decode.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/av1_constants.inc"

%macro av1_route_first_payload 3
    cmp     eax, %1
    jne     %%skip
    cmp     dword [r14 + %2], 0
    jne     %%skip
    mov     ecx, [rsp + AV1_OBU_DESC_PAYLOAD_OFFSET]
    add     ecx, ebx
    mov     [r14 + %2], ecx
    mov     ecx, [rsp + AV1_OBU_DESC_PAYLOAD_LEN]
    mov     [r14 + %3], ecx
%%skip:
%endmacro

SECTION .text

; er_av1_obu_type_valid(type) -> eax=1 valid, eax=0 invalid
; rdi=type
er_fn er_av1_obu_type_valid
    cmp     edi, AV1_OBU_TYPE_MAX
    ja      .invalid
    mov     eax, AV1_OBU_VALID_TYPE_MASK
    bt      eax, edi
    setc    al
    movzx   eax, al
    er_ok
    er_ret
.invalid:
    xor     eax, eax
    er_ok
    er_ret

; er_av1_metadata_type_valid(type) -> eax=1 valid, eax=0 invalid
; rdi=type
er_fn er_av1_metadata_type_valid
    cmp     edi, AV1_METADATA_TYPE_MAX
    ja      .invalid
    mov     eax, AV1_METADATA_VALID_TYPE_MASK
    bt      eax, edi
    setc    al
    movzx   eax, al
    er_ok
    er_ret
.invalid:
    xor     eax, eax
    er_ok
    er_ret

; er_av1_leb128_decode(buf, len, value_out) -> eax=bytes_read, rdx=error
; rdi=buf, esi=len, rdx=value_out(qword)
er_fn er_av1_leb128_decode
    er_push rbx, r12, r13, r14
    er_check_zero rdi, .invalid_param
    er_check_zero rdx, .invalid_param
    er_check_zero esi, .no_data
    mov     r12, rdi
    mov     r13, rdx
    xor     r14, r14
    xor     r10d, r10d
    xor     r11d, r11d
.loop:
    cmp     r10d, esi
    jae     .no_data
    cmp     r10d, AV1_LEB128_MAX_BYTES
    jae     .corrupt
    movzx   ebx, byte [r12 + r10]
    mov     r8d, ebx
    and     r8d, AV1_LEB128_PAYLOAD_MASK
    mov     r9, r8
    mov     ecx, r11d
    shl     r9, cl
    or      r14, r9
    test    ebx, AV1_LEB128_CONTINUE_MASK
    jz      .finish
    inc     r10d
    add     r11d, AV1_LEB128_BITS_PER_BYTE
    cmp     r10d, AV1_LEB128_MAX_BYTES
    jb      .loop
    jmp     .corrupt
.finish:
    mov     rax, AV1_LEB128_U32_MAX
    cmp     r14, rax
    ja      .corrupt
    mov     [r13], r14
    lea     eax, [r10 + 1]
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
    jmp     .done
.done:
    er_pop  rbx, r12, r13, r14
    er_ret

; er_av1_leb128_encode(out, cap, value) -> eax=bytes_written, rdx=error
; rdi=out, esi=cap, rdx=value(u32)
er_fn er_av1_leb128_encode
    er_push rbx, r12
    er_check_zero rdi, .invalid_param
    mov     rax, AV1_LEB128_U32_MAX
    cmp     rdx, rax
    ja      .invalid_param
    mov     r12, rdi
    mov     rbx, rdx
    xor     ecx, ecx
.loop:
    cmp     ecx, esi
    jae     .no_space
    mov     eax, ebx
    and     eax, AV1_LEB128_PAYLOAD_MASK
    shr     rbx, AV1_LEB128_BITS_PER_BYTE
    er_check_zero rbx, .last
    or      eax, AV1_LEB128_CONTINUE_MASK
.last:
    mov     [r12 + rcx], al
    inc     ecx
    er_check_nonzero rbx, .loop
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
    er_pop  rbx, r12
    er_ret

; er_av1_obu_decode_header(buf, len, desc) -> eax=header_len, rdx=error
; rdi=buf, esi=len, rdx=desc
er_fn er_av1_obu_decode_header
    er_push rbx, r12, r13
    er_check_zero rdi, .invalid_param
    er_check_zero rdx, .invalid_param
    er_check_zero esi, .no_data
    mov     r12, rdx
    mov     r13, rdi
    movzx   ebx, byte [r13]
    test    ebx, AV1_OBU_HEADER_FORBIDDEN_MASK
    jnz     .corrupt
    test    ebx, AV1_OBU_HEADER_RESERVED_MASK
    jnz     .corrupt

    mov     eax, ebx
    and     eax, AV1_OBU_HEADER_TYPE_MASK
    shr     eax, AV1_OBU_HEADER_TYPE_SHIFT
    mov     edi, eax
    call    er_av1_obu_type_valid
    er_check_zero eax, .unsupported
    mov     eax, edi
    mov     [r12 + AV1_OBU_DESC_TYPE], al

    xor     eax, eax
    test    ebx, AV1_OBU_HEADER_HAS_SIZE_MASK
    setnz   al
    mov     [r12 + AV1_OBU_DESC_HAS_SIZE], al

    xor     eax, eax
    test    ebx, AV1_OBU_HEADER_EXTENSION_MASK
    setnz   al
    mov     [r12 + AV1_OBU_DESC_EXTENSION], al
    mov     byte [r12 + AV1_OBU_DESC_TEMPORAL_ID], 0
    mov     byte [r12 + AV1_OBU_DESC_SPATIAL_ID], 0
    er_check_nonzero eax, .decode_extension

    mov     byte [r12 + AV1_OBU_DESC_HEADER_LEN], AV1_OBU_HEADER_BASE_LEN
    mov     byte [r12 + AV1_OBU_DESC_SIZE_FIELD_LEN], 0
    mov     eax, AV1_OBU_HEADER_BASE_LEN
    jmp     .ok

.decode_extension:
    cmp     esi, AV1_OBU_HEADER_EXT_LEN
    jb      .no_data
    movzx   ebx, byte [r13 + 1]
    test    ebx, AV1_OBU_EXTENSION_RESERVED_MASK
    jnz     .corrupt
    mov     eax, ebx
    and     eax, AV1_OBU_EXTENSION_TEMPORAL_MASK
    shr     eax, AV1_OBU_EXTENSION_TEMPORAL_SHIFT
    mov     [r12 + AV1_OBU_DESC_TEMPORAL_ID], al
    mov     eax, ebx
    and     eax, AV1_OBU_EXTENSION_SPATIAL_MASK
    shr     eax, AV1_OBU_EXTENSION_SPATIAL_SHIFT
    mov     [r12 + AV1_OBU_DESC_SPATIAL_ID], al
    mov     byte [r12 + AV1_OBU_DESC_HEADER_LEN], AV1_OBU_HEADER_EXT_LEN
    mov     byte [r12 + AV1_OBU_DESC_SIZE_FIELD_LEN], 0
    mov     eax, AV1_OBU_HEADER_EXT_LEN
    jmp     .ok

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
    jmp     .done
.unsupported:
    xor     eax, eax
    er_err  ERROR_UNSUPPORTED
    jmp     .done
.ok:
    er_ok
.done:
    er_pop  rbx, r12, r13
    er_ret

; er_av1_obu_decode_unit(buf, len, desc) -> eax=total_len, rdx=error
; rdi=buf, esi=len, rdx=desc. Records payload offset and length in desc.
er_fn er_av1_obu_decode_unit
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc 16
    er_check_zero rdi, .invalid_param
    er_check_zero rdx, .invalid_param
    mov     r12, rdi
    mov     r13, rdx
    mov     r14d, esi
    call    er_av1_obu_decode_header
    er_check_nonzero edx, .done
    mov     ebx, eax
    cmp     byte [r13 + AV1_OBU_DESC_HAS_SIZE], 0
    jne     .with_size

    mov     [r13 + AV1_OBU_DESC_PAYLOAD_OFFSET], ebx
    mov     eax, r14d
    sub     eax, ebx
    mov     [r13 + AV1_OBU_DESC_PAYLOAD_LEN], eax
    mov     [r13 + AV1_OBU_DESC_TOTAL_LEN], r14d
    mov     eax, r14d
    er_ok
    jmp     .done

.with_size:
    cmp     r14d, ebx
    jbe     .no_data
    lea     rdi, [r12 + rbx]
    mov     esi, r14d
    sub     esi, ebx
    mov     rdx, rsp
    call    er_av1_leb128_decode
    er_check_nonzero edx, .done
    mov     r15d, eax
    mov     byte [r13 + AV1_OBU_DESC_SIZE_FIELD_LEN], al
    mov     rax, [rsp]
    mov     rcx, rbx
    add     rcx, r15
    add     rcx, rax
    mov     rdx, r14
    cmp     rcx, rdx
    ja      .no_data
    mov     eax, ebx
    add     eax, r15d
    mov     [r13 + AV1_OBU_DESC_PAYLOAD_OFFSET], eax
    mov     eax, [rsp]
    mov     [r13 + AV1_OBU_DESC_PAYLOAD_LEN], eax
    mov     [r13 + AV1_OBU_DESC_TOTAL_LEN], ecx
    mov     eax, ecx
    er_ok
    jmp     .done

.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done
.no_data:
    xor     eax, eax
    er_err  ERROR_NO_DATA
.done:
    er_stack_free 16
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_obu_scan_units(buf, len, stats) -> eax=unit count, rdx=error
; Walks consecutive complete AV1 OBUs and fills dword counts by OBU type.
; rdi=buf, esi=len, rdx=stats
er_fn er_av1_obu_scan_units
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc 32
    er_check_zero rdi, .invalid_param
    er_check_zero rdx, .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     r15, rdx
    mov     rdi, r15
    xor     eax, eax
    mov     ecx, AV1_OBU_STATS_SIZE / 8
    cld
    rep     stosq
    xor     ebx, ebx
    xor     r14d, r14d
.loop:
    cmp     ebx, r13d
    je      .ok
    ja      .corrupt
    lea     rdi, [r12 + rbx]
    mov     esi, r13d
    sub     esi, ebx
    mov     rdx, rsp
    call    er_av1_obu_decode_unit
    er_check_nonzero edx, .done
    er_check_zero eax, .corrupt
    add     ebx, eax
    jc      .corrupt
    movzx   eax, byte [rsp + AV1_OBU_DESC_TYPE]
    inc     dword [r15 + AV1_OBU_STATS_TYPE_COUNTS + rax * 4]
    cmp     r14d, AV1_LEB128_U32_MAX
    je      .corrupt
    inc     r14d
    jmp     .loop
.ok:
    mov     [r15 + AV1_OBU_STATS_TOTAL], r14d
    mov     eax, r14d
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
    er_stack_free 32
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_obu_route_sample(buf, len, route) -> eax=unit count, rdx=error
; Fills the stats prefix and first sequence/frame/tile payload offsets relative to buf.
; rdi=buf, esi=len, rdx=route
er_fn er_av1_obu_route_sample
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc 32
    er_check_zero rdi, .invalid_param
    er_check_zero rdx, .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     r14, rdx
    mov     rdi, r14
    xor     eax, eax
    mov     ecx, AV1_OBU_ROUTE_SIZE / 8
    cld
    rep     stosq
    mov     rdi, r12
    mov     esi, r13d
    mov     rdx, r14
    call    er_av1_obu_scan_units
    er_check_nonzero edx, .done
    mov     r15d, eax
    xor     ebx, ebx
.loop:
    cmp     ebx, r13d
    je      .ok
    ja      .corrupt
    lea     rdi, [r12 + rbx]
    mov     esi, r13d
    sub     esi, ebx
    mov     rdx, rsp
    call    er_av1_obu_decode_unit
    er_check_nonzero edx, .done
    er_check_zero eax, .corrupt
    movzx   eax, byte [rsp + AV1_OBU_DESC_TYPE]
    av1_route_first_payload AV1_OBU_TYPE_SEQUENCE_HEADER, AV1_OBU_ROUTE_SEQUENCE_OFFSET, AV1_OBU_ROUTE_SEQUENCE_LEN
    av1_route_first_payload AV1_OBU_TYPE_FRAME_HEADER, AV1_OBU_ROUTE_FRAME_HEADER_OFFSET, AV1_OBU_ROUTE_FRAME_HEADER_LEN
    av1_route_first_payload AV1_OBU_TYPE_TILE_GROUP, AV1_OBU_ROUTE_TILE_GROUP_OFFSET, AV1_OBU_ROUTE_TILE_GROUP_LEN
    av1_route_first_payload AV1_OBU_TYPE_FRAME, AV1_OBU_ROUTE_FRAME_OFFSET, AV1_OBU_ROUTE_FRAME_LEN
    add     ebx, [rsp + AV1_OBU_DESC_TOTAL_LEN]
    jc      .corrupt
    jmp     .loop
.ok:
    mov     eax, r15d
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
    er_stack_free 32
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_obu_count_units(buf, len) -> eax=unit count, rdx=error
; Walks a buffer of consecutive AV1 OBUs and requires every byte to belong to a complete unit.
; rdi=buf, esi=len
er_fn er_av1_obu_count_units
    er_stack_alloc AV1_OBU_STATS_SIZE
    mov     rdx, rsp
    call    er_av1_obu_scan_units
    er_stack_free AV1_OBU_STATS_SIZE
    er_ret

; er_av1_metadata_decode(payload, len, desc)
; Decodes metadata_type and records metadata body offset/length relative to payload.
; rdi=payload, esi=len, rdx=desc. Returns eax=bytes_consumed, rdx=error.
er_fn er_av1_metadata_decode
    er_push rbx, r12, r13, r14
    er_stack_alloc 8
    er_check_zero rdi, .invalid_param
    er_check_zero rdx, .invalid_param
    er_check_zero esi, .no_data
    mov     r12, rdi
    mov     r13d, esi
    mov     r14, rdx
    mov     rdx, rsp
    call    er_av1_leb128_decode
    er_check_nonzero edx, .done
    mov     ebx, eax
    mov     rax, [rsp]
    cmp     rax, AV1_METADATA_TYPE_MAX
    ja      .unsupported
    mov     edi, eax
    call    er_av1_metadata_type_valid
    er_check_zero eax, .unsupported
    mov     eax, [rsp]
    mov     [r14 + AV1_METADATA_DESC_TYPE], eax
    mov     [r14 + AV1_METADATA_DESC_PAYLOAD_OFFSET], ebx
    mov     eax, r13d
    sub     eax, ebx
    mov     [r14 + AV1_METADATA_DESC_PAYLOAD_LEN], eax
    mov     ecx, [r14 + AV1_METADATA_DESC_TYPE]
    cmp     ecx, AV1_METADATA_TYPE_HDR_CLL
    je      .check_hdr_cll
    cmp     ecx, AV1_METADATA_TYPE_HDR_MDCV
    je      .check_hdr_mdcv
    mov     eax, r13d
    er_ok
    jmp     .done
.check_hdr_cll:
    cmp     eax, AV1_METADATA_HDR_CLL_LEN
    jne     .corrupt
    mov     eax, r13d
    er_ok
    jmp     .done
.check_hdr_mdcv:
    cmp     eax, AV1_METADATA_HDR_MDCV_LEN
    jne     .corrupt
    mov     eax, r13d
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
.unsupported:
    xor     eax, eax
    er_err  ERROR_UNSUPPORTED
    jmp     .done
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.done:
    er_stack_free 8
    er_pop  rbx, r12, r13, r14
    er_ret

; er_av1_padding_decode(payload, len)
; Validates a padding payload. All padding bytes must be zero.
; rdi=payload, esi=len. Returns eax=bytes_consumed, rdx=error.
er_fn er_av1_padding_decode
    er_check_zero esi, .ok
    er_check_zero rdi, .invalid_param
    xor     ecx, ecx
.loop:
    cmp     byte [rdi + rcx], AV1_PADDING_BYTE
    jne     .corrupt
    inc     ecx
    cmp     ecx, esi
    jb      .loop
.ok:
    mov     eax, esi
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

; er_av1_obu_encode_prefix(out, cap, type, payload_len, temporal_id, spatial_id)
; -> eax=prefix_len, rdx=error. Always writes obu_has_size_field=1.
; rdi=out, esi=cap, edx=type, ecx=payload_len, r8d=temporal_id, r9d=spatial_id
er_fn er_av1_obu_encode_prefix
    er_push rbx, r12, r13, r14
    er_check_zero rdi, .invalid_param
    mov     r12, rdi
    mov     r13d, ecx
    mov     r14d, esi
    mov     ecx, 1
    call    er_av1_obu_encode_header
    er_check_nonzero edx, .done
    mov     ebx, eax
    lea     rdi, [r12 + rbx]
    mov     esi, r14d
    sub     esi, ebx
    mov     edx, r13d
    call    er_av1_leb128_encode
    er_check_nonzero edx, .done
    add     eax, ebx
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done:
	er_pop  rbx, r12, r13, r14
	er_ret

; er_av1_obu_encode_temporal_delimiter(out, cap)
; -> eax=bytes_written, rdx=error. Emits a zero-payload sized temporal delimiter OBU.
; rdi=out, esi=cap
er_fn er_av1_obu_encode_temporal_delimiter
	mov     edx, AV1_OBU_TYPE_TEMPORAL_DELIMITER
	xor     ecx, ecx
	xor     r8d, r8d
	xor     r9d, r9d
	call    er_av1_obu_encode_prefix
	er_ret

; er_av1_obu_encode_padding(out, cap, padding_len)
; -> eax=bytes_written, rdx=error. Emits a sized PADDING OBU with zero bytes.
; rdi=out, esi=cap, edx=padding_len
er_fn er_av1_obu_encode_padding
    er_push rbx, r12, r13
    er_check_zero rdi, .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     ebx, edx
    mov     edx, AV1_OBU_TYPE_PADDING
    mov     ecx, ebx
    xor     r8d, r8d
    xor     r9d, r9d
    call    er_av1_obu_encode_prefix
    er_check_nonzero edx, .done
    mov     r11d, eax
    add     eax, ebx
    jc      .no_space
    cmp     eax, r13d
    ja      .no_space
    lea     rdi, [r12 + r11]
    mov     ecx, ebx
    call    zero_bytes
    mov     eax, r11d
    add     eax, ebx
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

; er_av1_obu_encode_metadata(out, cap, metadata_type, payload, payload_len)
; -> eax=bytes_written, rdx=error. Emits a sized METADATA OBU.
; rdi=out, esi=cap, edx=metadata_type, rcx=payload, r8d=payload_len
er_fn er_av1_obu_encode_metadata
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc 16
    er_check_zero rdi, .invalid_param
    er_check_zero r8d, .payload_checked
    er_check_zero rcx, .invalid_param
.payload_checked:
    mov     r12, rdi
    mov     r13d, esi
    mov     r14, rcx
    mov     r15d, r8d
    mov     [rsp + 8], edx
    mov     edi, edx
    call    er_av1_metadata_type_valid
    er_check_zero eax, .unsupported
    mov     edx, [rsp + 8]
    cmp     edx, AV1_METADATA_TYPE_HDR_CLL
    je      .check_hdr_cll
    cmp     edx, AV1_METADATA_TYPE_HDR_MDCV
    je      .check_hdr_mdcv
    jmp     .encode_type
.check_hdr_cll:
    cmp     r15d, AV1_METADATA_HDR_CLL_LEN
    jne     .corrupt
    jmp     .encode_type
.check_hdr_mdcv:
    cmp     r15d, AV1_METADATA_HDR_MDCV_LEN
    jne     .corrupt
.encode_type:
    mov     rdi, rsp
    mov     esi, 8
    mov     edx, [rsp + 8]
    call    er_av1_leb128_encode
    er_check_nonzero edx, .done
    mov     ebx, eax
    mov     ecx, ebx
    add     ecx, r15d
    jc      .no_space
    mov     rdi, r12
    mov     esi, r13d
    mov     edx, AV1_OBU_TYPE_METADATA
    xor     r8d, r8d
    xor     r9d, r9d
    call    er_av1_obu_encode_prefix
    er_check_nonzero edx, .done
    mov     r11d, eax
    mov     eax, r11d
    add     eax, ebx
    jc      .no_space
    add     eax, r15d
    jc      .no_space
    cmp     eax, r13d
    ja      .no_space
    mov     ecx, ebx
    mov     rsi, rsp
    lea     rdi, [r12 + r11]
    call    copy_bytes
    lea     rdi, [r12 + r11]
    add     rdi, rbx
    mov     rsi, r14
    mov     ecx, r15d
    call    copy_bytes
    mov     eax, r11d
    add     eax, ebx
    add     eax, r15d
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
    er_stack_free 16
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_obu_encode_header(out, cap, type, has_size, temporal_id, spatial_id)
; -> eax=header_len, rdx=error
; rdi=out, esi=cap, edx=type, ecx=has_size, r8d=temporal_id, r9d=spatial_id
er_fn er_av1_obu_encode_header
    er_push rbx, r12, r13
    er_check_zero rdi, .invalid_param
    mov     r12, rdi
    mov     r13d, edx
    mov     edi, edx
    call    er_av1_obu_type_valid
    er_check_zero eax, .unsupported
    cmp     r8d, AV1_ID_MAX
    ja      .invalid_param
    cmp     r9d, AV1_ID_MAX
    ja      .invalid_param

    xor     ebx, ebx
    test    r8d, r8d
    setnz   bl
    test    r9d, r9d
    setnz   al
    or      bl, al
    movzx   ebx, bl
    lea     eax, [rbx + AV1_OBU_HEADER_BASE_LEN]
    cmp     esi, eax
    jb      .no_space

    mov     eax, r13d
    shl     eax, AV1_OBU_HEADER_TYPE_SHIFT
    er_check_zero ebx, .size_flag
    or      eax, AV1_OBU_HEADER_EXTENSION_MASK
.size_flag:
    er_check_zero ecx, .store_base
    or      eax, AV1_OBU_HEADER_HAS_SIZE_MASK
.store_base:
    mov     [r12], al
    er_check_zero ebx, .base_done
    mov     eax, r8d
    shl     eax, AV1_OBU_EXTENSION_TEMPORAL_SHIFT
    mov     edx, r9d
    shl     edx, AV1_OBU_EXTENSION_SPATIAL_SHIFT
    or      eax, edx
    mov     [r12 + 1], al
    mov     eax, AV1_OBU_HEADER_EXT_LEN
    jmp     .ok
.base_done:
    mov     eax, AV1_OBU_HEADER_BASE_LEN
    jmp     .ok

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
.ok:
    er_ok
.done:
    er_pop  rbx, r12, r13
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

zero_bytes:
    er_check_zero ecx, .done
.loop:
    mov     byte [rdi], AV1_PADDING_BYTE
    inc     rdi
    dec     ecx
    jnz     .loop
.done:
    ret
