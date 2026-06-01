; EdgeRun AV1 reduced-still stream decoder/encoder — x86_64 assembly.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/av1_constants.inc"

extern er_av1_obu_decode_unit
extern er_av1_obu_encode_prefix
extern er_av1_obu_encode_temporal_delimiter
extern er_av1_sequence_decode_reduced_still
extern er_av1_sequence_encode_reduced_still
extern er_av1_frame_decode_reduced_still
extern er_av1_frame_encode_reduced_still
extern er_av1_tile_group_decode_single
extern er_av1_tile_group_encode_single
extern er_av1_ivf_is
extern er_av1_ivf_decode_header
extern er_av1_ivf_read_frame
extern er_av1_ivf_validate_frame_count
extern er_av1_ivf_validate_timestamps
extern er_av1_ivf_seek_frame
extern er_av1_ivf_encode_header
extern er_av1_ivf_write_frame
extern er_av1_tile_raw420_size
extern er_av1_tile_raw420_validate
extern er_av1_tile_raw420_encode
extern er_av1_tile_raw420_decode

SECTION .text

; er_av1_reduced_still_decode(stream, len, desc) -> eax=bytes_consumed, rdx=error
; desc includes sequence desc, frame desc, tile offset/len relative to stream.
; rdi=stream, esi=len, rdx=desc
er_fn er_av1_reduced_still_decode
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc AV1_OBU_DESC_SIZE + AV1_TILE_GROUP_SIZE
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     r14, rdx
    xor     ebx, ebx
    mov     byte [r14 + AV1_REDUCED_SEEN_SEQUENCE], 0
    mov     byte [r14 + AV1_REDUCED_SEEN_FRAME], 0
    mov     dword [r14 + AV1_REDUCED_TILE_OFFSET], 0
    mov     dword [r14 + AV1_REDUCED_TILE_LEN], 0
.loop:
    cmp     ebx, r13d
    jae     .finish
    lea     rdi, [r12 + rbx]
    mov     esi, r13d
    sub     esi, ebx
    mov     rdx, rsp
    call    er_av1_obu_decode_unit
    test    edx, edx
    jnz     .done
    mov     r15d, eax
    movzx   eax, byte [rsp + AV1_OBU_DESC_TYPE]
    cmp     eax, AV1_OBU_TYPE_TEMPORAL_DELIMITER
    je      .next
    cmp     eax, AV1_OBU_TYPE_SEQUENCE_HEADER
    je      .sequence
    cmp     eax, AV1_OBU_TYPE_FRAME
    je      .frame
    cmp     eax, AV1_OBU_TYPE_FRAME_HEADER
    je      .frame
    cmp     eax, AV1_OBU_TYPE_TILE_GROUP
    je      .tile_group
    cmp     eax, AV1_OBU_TYPE_PADDING
    je      .next
    jmp     .unsupported

.sequence:
    mov     eax, [rsp + AV1_OBU_DESC_PAYLOAD_OFFSET]
    lea     rdi, [r12 + rbx]
    add     rdi, rax
    mov     esi, [rsp + AV1_OBU_DESC_PAYLOAD_LEN]
    lea     rdx, [r14 + AV1_REDUCED_SEQ]
    call    er_av1_sequence_decode_reduced_still
    test    edx, edx
    jnz     .done
    mov     byte [r14 + AV1_REDUCED_SEEN_SEQUENCE], 1
    jmp     .next

.frame:
    cmp     byte [r14 + AV1_REDUCED_SEEN_SEQUENCE], 1
    jne     .corrupt
    mov     eax, [rsp + AV1_OBU_DESC_PAYLOAD_OFFSET]
    lea     rdi, [r12 + rbx]
    add     rdi, rax
    mov     esi, [rsp + AV1_OBU_DESC_PAYLOAD_LEN]
    lea     rdx, [r14 + AV1_REDUCED_SEQ]
    lea     rcx, [r14 + AV1_REDUCED_FRAME]
    call    er_av1_frame_decode_reduced_still
    test    edx, edx
    jnz     .done
    mov     byte [r14 + AV1_REDUCED_SEEN_FRAME], 1
    mov     ecx, [rsp + AV1_OBU_DESC_PAYLOAD_OFFSET]
    add     ecx, [r14 + AV1_REDUCED_FRAME + AV1_FRAME_TILE_OFFSET]
    add     ecx, ebx
    mov     [r14 + AV1_REDUCED_TILE_OFFSET], ecx
    mov     ecx, [r14 + AV1_REDUCED_FRAME + AV1_FRAME_TILE_LEN]
    mov     [r14 + AV1_REDUCED_TILE_LEN], ecx
    jmp     .next

.tile_group:
    cmp     byte [r14 + AV1_REDUCED_SEEN_FRAME], 1
    jne     .corrupt
    mov     eax, [rsp + AV1_OBU_DESC_PAYLOAD_OFFSET]
    lea     rdi, [r12 + rbx]
    add     rdi, rax
    mov     esi, [rsp + AV1_OBU_DESC_PAYLOAD_LEN]
    lea     rdx, [rsp + AV1_OBU_DESC_SIZE]
    call    er_av1_tile_group_decode_single
    test    edx, edx
    jnz     .done
    mov     ecx, [rsp + AV1_OBU_DESC_PAYLOAD_OFFSET]
    add     ecx, ebx
    add     ecx, [rsp + AV1_OBU_DESC_SIZE + AV1_TILE_GROUP_DATA_OFFSET]
    mov     [r14 + AV1_REDUCED_TILE_OFFSET], ecx
    mov     ecx, [rsp + AV1_OBU_DESC_SIZE + AV1_TILE_GROUP_DATA_LEN]
    mov     [r14 + AV1_REDUCED_TILE_LEN], ecx

.next:
    add     ebx, r15d
    jmp     .loop

.finish:
    cmp     byte [r14 + AV1_REDUCED_SEEN_SEQUENCE], 1
    jne     .corrupt
    cmp     byte [r14 + AV1_REDUCED_SEEN_FRAME], 1
    jne     .corrupt
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
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.done:
    er_stack_free AV1_OBU_DESC_SIZE + AV1_TILE_GROUP_SIZE
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_reduced_still_decode_auto(stream, len, desc)
; Accepts a raw low-overhead OBU stream or an IVF-wrapped first AV1 frame.
; Returns bytes consumed relative to the original stream, and keeps tile offsets
; relative to the original stream.
; rdi=stream, esi=len, rdx=desc
er_fn er_av1_reduced_still_decode_auto
    er_push rbx, r12, r13, r14
    er_stack_alloc AV1_IVF_HDR_SIZE + AV1_IVF_FRAME_SIZE
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     r14, rdx
    call    er_av1_ivf_is
    test    edx, edx
    jnz     .done
    cmp     eax, 1
    je      .ivf
    mov     rdi, r12
    mov     esi, r13d
    mov     rdx, r14
    call    er_av1_reduced_still_decode
    jmp     .done
.ivf:
    mov     rdi, r12
    mov     esi, r13d
    mov     rdx, rsp
    call    er_av1_ivf_decode_header
    test    edx, edx
    jnz     .done
    mov     rdi, r12
    mov     esi, r13d
    call    er_av1_ivf_validate_frame_count
    test    edx, edx
    jnz     .done
    mov     rdi, r12
    mov     esi, r13d
    call    er_av1_ivf_validate_timestamps
    test    edx, edx
    jnz     .done
    mov     rdi, r12
    mov     esi, r13d
    mov     edx, AV1_IVF_HEADER_SIZE
    lea     rcx, [rsp + AV1_IVF_HDR_SIZE]
    call    er_av1_ivf_read_frame
    test    edx, edx
    jnz     .done
    mov     ebx, eax
    mov     eax, [rsp + AV1_IVF_HDR_SIZE + AV1_IVF_FRAME_PAYLOAD_OFFSET]
    lea     rdi, [r12 + rax]
    mov     esi, [rsp + AV1_IVF_HDR_SIZE + AV1_IVF_FRAME_PAYLOAD_LEN]
    mov     rdx, r14
    call    er_av1_reduced_still_decode
    test    edx, edx
    jnz     .done
    movzx   ecx, word [rsp + AV1_IVF_HDR_WIDTH]
    cmp     [r14 + AV1_REDUCED_FRAME + AV1_FRAME_WIDTH], ecx
    jne     .corrupt
    movzx   ecx, word [rsp + AV1_IVF_HDR_HEIGHT]
    cmp     [r14 + AV1_REDUCED_FRAME + AV1_FRAME_HEIGHT], ecx
    jne     .corrupt
    mov     ecx, [rsp + AV1_IVF_HDR_SIZE + AV1_IVF_FRAME_PAYLOAD_OFFSET]
    add     [r14 + AV1_REDUCED_TILE_OFFSET], ecx
    mov     eax, ebx
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
    er_stack_free AV1_IVF_HDR_SIZE + AV1_IVF_FRAME_SIZE
    er_pop  rbx, r12, r13, r14
    er_ret

; er_av1_reduced_still_decode_ivf_frame(stream, len, frame_index, desc)
; Decodes one indexed frame from an IVF-wrapped reduced-still AV1 stream.
; Returns eax=next IVF cursor after the selected frame. Tile offsets remain
; relative to the original IVF buffer.
; rdi=stream, esi=len, edx=frame_index, rcx=desc
er_fn er_av1_reduced_still_decode_ivf_frame
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc AV1_REDUCED_IVF_FRAME_STACK_SIZE
    test    rdi, rdi
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     r14d, edx
    mov     r15, rcx
    mov     rdi, r12
    mov     esi, r13d
    call    er_av1_ivf_validate_frame_count
    test    edx, edx
    jnz     .done
    mov     rdi, r12
    mov     esi, r13d
    call    er_av1_ivf_validate_timestamps
    test    edx, edx
    jnz     .done
    mov     rdi, r12
    mov     esi, r13d
    lea     rdx, [rsp + AV1_REDUCED_IVF_FRAME_HDR]
    call    er_av1_ivf_decode_header
    test    edx, edx
    jnz     .done
    mov     rdi, r12
    mov     esi, r13d
    mov     edx, r14d
    lea     rcx, [rsp + AV1_REDUCED_IVF_FRAME_DESC]
    call    er_av1_ivf_seek_frame
    test    edx, edx
    jnz     .done
    mov     ebx, eax
    mov     eax, [rsp + AV1_REDUCED_IVF_FRAME_DESC + AV1_IVF_FRAME_PAYLOAD_OFFSET]
    lea     rdi, [r12 + rax]
    mov     esi, [rsp + AV1_REDUCED_IVF_FRAME_DESC + AV1_IVF_FRAME_PAYLOAD_LEN]
    mov     rdx, r15
    call    er_av1_reduced_still_decode
    test    edx, edx
    jnz     .done
    movzx   ecx, word [rsp + AV1_REDUCED_IVF_FRAME_HDR + AV1_IVF_HDR_WIDTH]
    cmp     [r15 + AV1_REDUCED_FRAME + AV1_FRAME_WIDTH], ecx
    jne     .corrupt
    movzx   ecx, word [rsp + AV1_REDUCED_IVF_FRAME_HDR + AV1_IVF_HDR_HEIGHT]
    cmp     [r15 + AV1_REDUCED_FRAME + AV1_FRAME_HEIGHT], ecx
    jne     .corrupt
    mov     ecx, [rsp + AV1_REDUCED_IVF_FRAME_DESC + AV1_IVF_FRAME_PAYLOAD_OFFSET]
    add     [r15 + AV1_REDUCED_TILE_OFFSET], ecx
    mov     eax, ebx
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
    er_stack_free AV1_REDUCED_IVF_FRAME_STACK_SIZE
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_reduced_still_decode_ivf_frame_raw420(stream, len, frame_index, image_desc, reduced_desc)
; Decodes one indexed IVF frame directly into caller-provided raw 8-bit 4:2:0 planes.
; rdi=stream, esi=len, edx=frame_index, rcx=image_desc, r8=reduced_desc.
; Returns eax=next IVF cursor after the selected frame.
er_fn er_av1_reduced_still_decode_ivf_frame_raw420
    er_push rbx, r12, r13, r14, r15
    test    rdi, rdi
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    test    r8, r8
    jz      .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     ebx, edx
    mov     r14, rcx
    mov     r15, r8
    mov     rdi, r12
    mov     esi, r13d
    mov     edx, ebx
    mov     rcx, r15
    call    er_av1_reduced_still_decode_ivf_frame
    test    edx, edx
    jnz     .done
    mov     ebx, eax
    mov     eax, [r15 + AV1_REDUCED_FRAME + AV1_FRAME_WIDTH]
    cmp     [r14 + AV1_IMAGE_WIDTH], eax
    jne     .corrupt
    mov     eax, [r15 + AV1_REDUCED_FRAME + AV1_FRAME_HEIGHT]
    cmp     [r14 + AV1_IMAGE_HEIGHT], eax
    jne     .corrupt
    mov     rdi, r14
    call    er_av1_tile_raw420_validate
    test    edx, edx
    jnz     .done
    cmp     eax, [r15 + AV1_REDUCED_TILE_LEN]
    jne     .corrupt
    mov     eax, [r15 + AV1_REDUCED_TILE_OFFSET]
    lea     rdi, [r12 + rax]
    mov     esi, [r15 + AV1_REDUCED_TILE_LEN]
    mov     rdx, r14
    call    er_av1_tile_raw420_decode
    test    edx, edx
    jnz     .done
    mov     eax, ebx
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

; er_av1_reduced_still_encode(out, cap, width, height, tile_ptr, tile_len)
; rdi=out, esi=cap, edx=width, ecx=height, r8=tile_ptr, r9d=tile_len
; Returns eax=bytes_written, rdx=error.
er_fn er_av1_reduced_still_encode
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc AV1_REDUCED_ENC_STACK_SIZE
    test    rdi, rdi
    jz      .invalid_param
    test    r8, r8
    jz      .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     r14, r8
    mov     r15d, r9d
    xor     ebx, ebx

    lea     rdi, [rsp + AV1_REDUCED_ENC_PAYLOAD]
    mov     esi, 16
    call    er_av1_sequence_encode_reduced_still
    test    edx, edx
    jnz     .done
    mov     [rsp + AV1_REDUCED_ENC_SEQ_LEN], eax

    lea     rdi, [r12 + rbx]
    mov     esi, r13d
    sub     esi, ebx
    mov     edx, AV1_OBU_TYPE_SEQUENCE_HEADER
    mov     ecx, [rsp + AV1_REDUCED_ENC_SEQ_LEN]
    xor     r8d, r8d
    xor     r9d, r9d
    call    er_av1_obu_encode_prefix
    test    edx, edx
    jnz     .done
    add     ebx, eax
    mov     eax, ebx
    add     eax, [rsp + AV1_REDUCED_ENC_SEQ_LEN]
    jc      .no_space
    cmp     eax, r13d
    ja      .no_space
    mov     ecx, [rsp + AV1_REDUCED_ENC_SEQ_LEN]
    lea     rsi, [rsp + AV1_REDUCED_ENC_PAYLOAD]
    lea     rdi, [r12 + rbx]
    call    copy_bytes
    add     ebx, [rsp + AV1_REDUCED_ENC_SEQ_LEN]

    lea     rdi, [rsp + AV1_REDUCED_ENC_PAYLOAD]
    mov     esi, [rsp + AV1_REDUCED_ENC_SEQ_LEN]
    lea     rdx, [rsp + AV1_REDUCED_ENC_SEQ_DESC]
    call    er_av1_sequence_decode_reduced_still
    test    edx, edx
    jnz     .done

    lea     rdi, [rsp + AV1_REDUCED_ENC_PAYLOAD]
    mov     esi, 16
    lea     rdx, [rsp + AV1_REDUCED_ENC_SEQ_DESC]
    mov     ecx, [rsp + AV1_REDUCED_ENC_SEQ_DESC + AV1_SEQ_MAX_WIDTH]
    mov     r8d, [rsp + AV1_REDUCED_ENC_SEQ_DESC + AV1_SEQ_MAX_HEIGHT]
    call    er_av1_frame_encode_reduced_still
    test    edx, edx
    jnz     .done
    mov     [rsp + AV1_REDUCED_ENC_FRAME_LEN], eax

    lea     rdi, [r12 + rbx]
    mov     esi, r13d
    sub     esi, ebx
    mov     edx, AV1_OBU_TYPE_FRAME
    mov     ecx, [rsp + AV1_REDUCED_ENC_FRAME_LEN]
    add     ecx, r15d
    xor     r8d, r8d
    xor     r9d, r9d
    call    er_av1_obu_encode_prefix
    test    edx, edx
    jnz     .done
    add     ebx, eax
    mov     eax, ebx
    add     eax, [rsp + AV1_REDUCED_ENC_FRAME_LEN]
    jc      .no_space
    add     eax, r15d
    jc      .no_space
    cmp     eax, r13d
    ja      .no_space
    mov     ecx, [rsp + AV1_REDUCED_ENC_FRAME_LEN]
    lea     rsi, [rsp + AV1_REDUCED_ENC_PAYLOAD]
    lea     rdi, [r12 + rbx]
    call    copy_bytes
    add     ebx, [rsp + AV1_REDUCED_ENC_FRAME_LEN]
    lea     rdi, [r12 + rbx]
    mov     esi, r13d
    sub     esi, ebx
    mov     rdx, r14
    mov     ecx, r15d
    call    er_av1_tile_group_encode_single
    test    edx, edx
    jnz     .done
    add     ebx, eax
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
.done:
    er_stack_free AV1_REDUCED_ENC_STACK_SIZE
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_reduced_still_encode_split(out, cap, width, height, tile_ptr, tile_len)
; Emits sequence header, frame header, then tile group OBUs.
; rdi=out, esi=cap, edx=width, ecx=height, r8=tile_ptr, r9d=tile_len
; Returns eax=bytes_written, rdx=error.
er_fn er_av1_reduced_still_encode_split
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc AV1_REDUCED_ENC_STACK_SIZE
    test    rdi, rdi
    jz      .invalid_param
    test    r8, r8
    jz      .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     r14, r8
    mov     r15d, r9d
    xor     ebx, ebx

    lea     rdi, [rsp + AV1_REDUCED_ENC_PAYLOAD]
    mov     esi, 16
    call    er_av1_sequence_encode_reduced_still
    test    edx, edx
    jnz     .done
    mov     [rsp + AV1_REDUCED_ENC_SEQ_LEN], eax

    lea     rdi, [r12 + rbx]
    mov     esi, r13d
    sub     esi, ebx
    mov     edx, AV1_OBU_TYPE_SEQUENCE_HEADER
    mov     ecx, [rsp + AV1_REDUCED_ENC_SEQ_LEN]
    xor     r8d, r8d
    xor     r9d, r9d
    call    er_av1_obu_encode_prefix
    test    edx, edx
    jnz     .done
    add     ebx, eax
    mov     eax, ebx
    add     eax, [rsp + AV1_REDUCED_ENC_SEQ_LEN]
    jc      .no_space
    cmp     eax, r13d
    ja      .no_space
    mov     ecx, [rsp + AV1_REDUCED_ENC_SEQ_LEN]
    lea     rsi, [rsp + AV1_REDUCED_ENC_PAYLOAD]
    lea     rdi, [r12 + rbx]
    call    copy_bytes
    add     ebx, [rsp + AV1_REDUCED_ENC_SEQ_LEN]

    lea     rdi, [rsp + AV1_REDUCED_ENC_PAYLOAD]
    mov     esi, [rsp + AV1_REDUCED_ENC_SEQ_LEN]
    lea     rdx, [rsp + AV1_REDUCED_ENC_SEQ_DESC]
    call    er_av1_sequence_decode_reduced_still
    test    edx, edx
    jnz     .done

    lea     rdi, [rsp + AV1_REDUCED_ENC_PAYLOAD]
    mov     esi, 16
    lea     rdx, [rsp + AV1_REDUCED_ENC_SEQ_DESC]
    mov     ecx, [rsp + AV1_REDUCED_ENC_SEQ_DESC + AV1_SEQ_MAX_WIDTH]
    mov     r8d, [rsp + AV1_REDUCED_ENC_SEQ_DESC + AV1_SEQ_MAX_HEIGHT]
    call    er_av1_frame_encode_reduced_still
    test    edx, edx
    jnz     .done
    mov     [rsp + AV1_REDUCED_ENC_FRAME_LEN], eax

    lea     rdi, [r12 + rbx]
    mov     esi, r13d
    sub     esi, ebx
    mov     edx, AV1_OBU_TYPE_FRAME_HEADER
    mov     ecx, [rsp + AV1_REDUCED_ENC_FRAME_LEN]
    xor     r8d, r8d
    xor     r9d, r9d
    call    er_av1_obu_encode_prefix
    test    edx, edx
    jnz     .done
    add     ebx, eax
    mov     eax, ebx
    add     eax, [rsp + AV1_REDUCED_ENC_FRAME_LEN]
    jc      .no_space
    cmp     eax, r13d
    ja      .no_space
    mov     ecx, [rsp + AV1_REDUCED_ENC_FRAME_LEN]
    lea     rsi, [rsp + AV1_REDUCED_ENC_PAYLOAD]
    lea     rdi, [r12 + rbx]
    call    copy_bytes
    add     ebx, [rsp + AV1_REDUCED_ENC_FRAME_LEN]

    lea     rdi, [r12 + rbx]
    mov     esi, r13d
    sub     esi, ebx
    mov     edx, AV1_OBU_TYPE_TILE_GROUP
    mov     ecx, r15d
    xor     r8d, r8d
    xor     r9d, r9d
    call    er_av1_obu_encode_prefix
    test    edx, edx
    jnz     .done
    add     ebx, eax
    lea     rdi, [r12 + rbx]
    mov     esi, r13d
    sub     esi, ebx
    mov     rdx, r14
    mov     ecx, r15d
    call    er_av1_tile_group_encode_single
    test    edx, edx
    jnz     .done
    add     ebx, eax
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
.done:
    er_stack_free AV1_REDUCED_ENC_STACK_SIZE
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_reduced_still_encode_ivf(out, cap, width, height, tile_ptr, tile_len)
; Emits a complete single-frame IVF file whose payload is split reduced-still AV1.
; rdi=out, esi=cap, edx=width, ecx=height, r8=tile_ptr, r9d=tile_len
; Returns eax=bytes_written, rdx=error.
er_fn er_av1_reduced_still_encode_ivf
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc AV1_REDUCED_IVF_STACK_SIZE
    test    rdi, rdi
    jz      .invalid_param
    test    r8, r8
    jz      .invalid_param
    test    edx, edx
    jz      .invalid_param
    test    ecx, ecx
    jz      .invalid_param
    cmp     edx, AV1_IVF_DIMENSION_MAX
    ja      .corrupt
    cmp     ecx, AV1_IVF_DIMENSION_MAX
    ja      .corrupt
    mov     r12, rdi
    mov     r13d, esi
    mov     [rsp + AV1_REDUCED_IVF_WIDTH], edx
    mov     [rsp + AV1_REDUCED_IVF_HEIGHT], ecx
    mov     r14, r8
    mov     r15d, r9d
    cmp     r13d, AV1_IVF_HEADER_SIZE + AV1_IVF_FRAME_HEADER_SIZE
    jb      .no_space

    mov     dword [rsp + AV1_REDUCED_IVF_DESC + AV1_IVF_HDR_CODEC], AV1_IVF_CODEC_AV01
    mov     eax, [rsp + AV1_REDUCED_IVF_WIDTH]
    mov     [rsp + AV1_REDUCED_IVF_DESC + AV1_IVF_HDR_WIDTH], ax
    mov     eax, [rsp + AV1_REDUCED_IVF_HEIGHT]
    mov     [rsp + AV1_REDUCED_IVF_DESC + AV1_IVF_HDR_HEIGHT], ax
    mov     dword [rsp + AV1_REDUCED_IVF_DESC + AV1_IVF_HDR_TIMEBASE_DEN], AV1_IVF_DEFAULT_TIMEBASE_DEN
    mov     dword [rsp + AV1_REDUCED_IVF_DESC + AV1_IVF_HDR_TIMEBASE_NUM], AV1_IVF_DEFAULT_TIMEBASE_NUM
    mov     dword [rsp + AV1_REDUCED_IVF_DESC + AV1_IVF_HDR_FRAME_COUNT], AV1_IVF_SINGLE_FRAME_COUNT

    mov     rdi, r12
    mov     esi, r13d
    lea     rdx, [rsp + AV1_REDUCED_IVF_DESC]
    call    er_av1_ivf_encode_header
    test    edx, edx
    jnz     .done

    lea     rdi, [r12 + AV1_IVF_HEADER_SIZE + AV1_IVF_FRAME_HEADER_SIZE]
    mov     esi, r13d
    sub     esi, AV1_IVF_HEADER_SIZE + AV1_IVF_FRAME_HEADER_SIZE
    mov     edx, [rsp + AV1_REDUCED_IVF_WIDTH]
    mov     ecx, [rsp + AV1_REDUCED_IVF_HEIGHT]
    mov     r8, r14
    mov     r9d, r15d
    call    er_av1_reduced_still_encode_split
    test    edx, edx
    jnz     .done
    mov     [rsp + AV1_REDUCED_IVF_PAYLOAD_LEN], eax

    lea     rdi, [r12 + AV1_IVF_HEADER_SIZE]
    mov     esi, r13d
    sub     esi, AV1_IVF_HEADER_SIZE
    lea     rdx, [r12 + AV1_IVF_HEADER_SIZE + AV1_IVF_FRAME_HEADER_SIZE]
    mov     ecx, [rsp + AV1_REDUCED_IVF_PAYLOAD_LEN]
    mov     r8d, AV1_IVF_FIRST_TIMESTAMP
    call    er_av1_ivf_write_frame
    test    edx, edx
    jnz     .done
    add     eax, AV1_IVF_HEADER_SIZE
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
    er_stack_free AV1_REDUCED_IVF_STACK_SIZE
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_reduced_still_encode_ivf_raw420(out, cap, image_desc)
; Emits a complete single-frame IVF file from caller-provided raw 8-bit 4:2:0 planes.
; rdi=out, esi=cap, rdx=image_desc. Returns eax=bytes_written, rdx=error.
er_fn er_av1_reduced_still_encode_raw420
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc AV1_REDUCED_RAW_STACK_SIZE
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     r14, rdx
    mov     [rsp + AV1_REDUCED_RAW_IMAGE_PTR], rdx
    cmp     dword [r14 + AV1_IMAGE_WIDTH], 0
    je      .invalid_param
    cmp     dword [r14 + AV1_IMAGE_HEIGHT], 0
    je      .invalid_param
    cmp     qword [r14 + AV1_IMAGE_Y_PTR], 0
    je      .invalid_param
    cmp     qword [r14 + AV1_IMAGE_U_PTR], 0
    je      .invalid_param
    cmp     qword [r14 + AV1_IMAGE_V_PTR], 0
    je      .invalid_param

    mov     rdi, r14
    call    er_av1_tile_raw420_validate
    test    edx, edx
    jnz     .done
    mov     [rsp + AV1_REDUCED_RAW_TILE_LEN], eax
    xor     r15d, r15d

    lea     rdi, [rsp + AV1_REDUCED_RAW_PAYLOAD]
    mov     esi, 16
    mov     r14, [rsp + AV1_REDUCED_RAW_IMAGE_PTR]
    mov     edx, [r14 + AV1_IMAGE_WIDTH]
    mov     ecx, [r14 + AV1_IMAGE_HEIGHT]
    call    er_av1_sequence_encode_reduced_still
    test    edx, edx
    jnz     .done
    mov     [rsp + AV1_REDUCED_RAW_SEQ_LEN], eax
    lea     rdi, [r12 + r15]
    mov     esi, r13d
    sub     esi, r15d
    mov     edx, AV1_OBU_TYPE_SEQUENCE_HEADER
    mov     ecx, [rsp + AV1_REDUCED_RAW_SEQ_LEN]
    xor     r8d, r8d
    xor     r9d, r9d
    call    er_av1_obu_encode_prefix
    test    edx, edx
    jnz     .done
    add     r15d, eax
    mov     eax, r15d
    add     eax, [rsp + AV1_REDUCED_RAW_SEQ_LEN]
    jc      .no_space
    cmp     eax, r13d
    ja      .no_space
    mov     ecx, [rsp + AV1_REDUCED_RAW_SEQ_LEN]
    lea     rsi, [rsp + AV1_REDUCED_RAW_PAYLOAD]
    lea     rdi, [r12 + r15]
    call    copy_bytes
    add     r15d, [rsp + AV1_REDUCED_RAW_SEQ_LEN]

    lea     rdi, [rsp + AV1_REDUCED_RAW_PAYLOAD]
    mov     esi, [rsp + AV1_REDUCED_RAW_SEQ_LEN]
    lea     rdx, [rsp + AV1_REDUCED_RAW_SEQ_DESC]
    call    er_av1_sequence_decode_reduced_still
    test    edx, edx
    jnz     .done
    lea     rdi, [rsp + AV1_REDUCED_RAW_PAYLOAD]
    mov     esi, 16
    lea     rdx, [rsp + AV1_REDUCED_RAW_SEQ_DESC]
    mov     r14, [rsp + AV1_REDUCED_RAW_IMAGE_PTR]
    mov     ecx, [r14 + AV1_IMAGE_WIDTH]
    mov     r8d, [r14 + AV1_IMAGE_HEIGHT]
    call    er_av1_frame_encode_reduced_still
    test    edx, edx
    jnz     .done
    mov     [rsp + AV1_REDUCED_RAW_FRAME_LEN], eax

    lea     rdi, [r12 + r15]
    mov     esi, r13d
    sub     esi, r15d
    mov     edx, AV1_OBU_TYPE_FRAME_HEADER
    mov     ecx, [rsp + AV1_REDUCED_RAW_FRAME_LEN]
    xor     r8d, r8d
    xor     r9d, r9d
    call    er_av1_obu_encode_prefix
    test    edx, edx
    jnz     .done
    add     r15d, eax
    mov     eax, r15d
    add     eax, [rsp + AV1_REDUCED_RAW_FRAME_LEN]
    jc      .no_space
    cmp     eax, r13d
    ja      .no_space
    mov     ecx, [rsp + AV1_REDUCED_RAW_FRAME_LEN]
    lea     rsi, [rsp + AV1_REDUCED_RAW_PAYLOAD]
    lea     rdi, [r12 + r15]
    call    copy_bytes
    add     r15d, [rsp + AV1_REDUCED_RAW_FRAME_LEN]

    lea     rdi, [r12 + r15]
    mov     esi, r13d
    sub     esi, r15d
    mov     edx, AV1_OBU_TYPE_TILE_GROUP
    mov     ecx, [rsp + AV1_REDUCED_RAW_TILE_LEN]
    xor     r8d, r8d
    xor     r9d, r9d
    call    er_av1_obu_encode_prefix
    test    edx, edx
    jnz     .done
    add     r15d, eax
    lea     rdi, [r12 + r15]
    mov     esi, r13d
    sub     esi, r15d
    mov     rdx, [rsp + AV1_REDUCED_RAW_IMAGE_PTR]
    call    er_av1_tile_raw420_encode
    test    edx, edx
    jnz     .done
    add     r15d, eax
    mov     eax, r15d
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
	er_stack_free AV1_REDUCED_RAW_STACK_SIZE
	er_pop  rbx, r12, r13, r14, r15
	er_ret

; er_av1_reduced_still_encode_raw420_delimited(out, cap, image_desc)
; Emits a temporal delimiter followed by a reduced-still raw420 OBU stream.
; rdi=out, esi=cap, rdx=image_desc. Returns eax=bytes_written, rdx=error.
er_fn er_av1_reduced_still_encode_raw420_delimited
	er_push rbx, r12, r13, r14
	test    rdi, rdi
	jz      .invalid_param
	test    rdx, rdx
	jz      .invalid_param
	mov     r12, rdi
	mov     r13d, esi
	mov     r14, rdx
	mov     rdi, r14
	call    er_av1_tile_raw420_validate
	test    edx, edx
	jnz     .done
	mov     rdi, r12
	mov     esi, r13d
	call    er_av1_obu_encode_temporal_delimiter
	test    edx, edx
	jnz     .done
	mov     ebx, eax
	lea     rdi, [r12 + rbx]
	mov     esi, r13d
	sub     esi, ebx
	mov     rdx, r14
	call    er_av1_reduced_still_encode_raw420
	test    edx, edx
	jnz     .done
	add     eax, ebx
	er_ok
	jmp     .done
.invalid_param:
	xor     eax, eax
	er_err  ERROR_INVALID_PARAM
.done:
	er_pop  rbx, r12, r13, r14
	er_ret

; er_av1_reduced_still_encode_ivf_raw420(out, cap, image_desc)
; Emits a complete single-frame IVF file from caller-provided raw 8-bit 4:2:0 planes.
; rdi=out, esi=cap, rdx=image_desc. Returns eax=bytes_written, rdx=error.
er_fn er_av1_reduced_still_encode_ivf_raw420
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc AV1_REDUCED_RAW_STACK_SIZE
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     r14, rdx
    mov     [rsp + AV1_REDUCED_RAW_IMAGE_PTR], rdx
    cmp     dword [r14 + AV1_IMAGE_WIDTH], 0
    je      .invalid_param
    cmp     dword [r14 + AV1_IMAGE_HEIGHT], 0
    je      .invalid_param
    cmp     qword [r14 + AV1_IMAGE_Y_PTR], 0
    je      .invalid_param
    cmp     qword [r14 + AV1_IMAGE_U_PTR], 0
    je      .invalid_param
    cmp     qword [r14 + AV1_IMAGE_V_PTR], 0
    je      .invalid_param
    mov     r14, [rsp + AV1_REDUCED_RAW_IMAGE_PTR]
    mov     eax, [r14 + AV1_IMAGE_WIDTH]
    cmp     eax, AV1_IVF_DIMENSION_MAX
    ja      .corrupt
    mov     eax, [r14 + AV1_IMAGE_HEIGHT]
    cmp     eax, AV1_IVF_DIMENSION_MAX
    ja      .corrupt
    cmp     r13d, AV1_IVF_HEADER_SIZE + AV1_IVF_FRAME_HEADER_SIZE
    jb      .no_space

    mov     r14, [rsp + AV1_REDUCED_RAW_IMAGE_PTR]
    mov     rdi, r14
    call    er_av1_tile_raw420_validate
    test    edx, edx
    jnz     .done
    mov     [rsp + AV1_REDUCED_RAW_TILE_LEN], eax

    mov     dword [rsp + AV1_REDUCED_RAW_IVF_DESC + AV1_IVF_HDR_CODEC], AV1_IVF_CODEC_AV01
    mov     r14, [rsp + AV1_REDUCED_RAW_IMAGE_PTR]
    mov     eax, [r14 + AV1_IMAGE_WIDTH]
    mov     [rsp + AV1_REDUCED_RAW_IVF_DESC + AV1_IVF_HDR_WIDTH], ax
    mov     eax, [r14 + AV1_IMAGE_HEIGHT]
    mov     [rsp + AV1_REDUCED_RAW_IVF_DESC + AV1_IVF_HDR_HEIGHT], ax
    mov     dword [rsp + AV1_REDUCED_RAW_IVF_DESC + AV1_IVF_HDR_TIMEBASE_DEN], AV1_IVF_DEFAULT_TIMEBASE_DEN
    mov     dword [rsp + AV1_REDUCED_RAW_IVF_DESC + AV1_IVF_HDR_TIMEBASE_NUM], AV1_IVF_DEFAULT_TIMEBASE_NUM
    mov     dword [rsp + AV1_REDUCED_RAW_IVF_DESC + AV1_IVF_HDR_FRAME_COUNT], AV1_IVF_SINGLE_FRAME_COUNT
    mov     rdi, r12
    mov     esi, r13d
    lea     rdx, [rsp + AV1_REDUCED_RAW_IVF_DESC]
    call    er_av1_ivf_encode_header
    test    edx, edx
    jnz     .done
    mov     r15d, AV1_IVF_HEADER_SIZE + AV1_IVF_FRAME_HEADER_SIZE

    lea     rdi, [rsp + AV1_REDUCED_RAW_PAYLOAD]
    mov     esi, 16
    mov     r14, [rsp + AV1_REDUCED_RAW_IMAGE_PTR]
    mov     edx, [r14 + AV1_IMAGE_WIDTH]
    mov     ecx, [r14 + AV1_IMAGE_HEIGHT]
    call    er_av1_sequence_encode_reduced_still
    test    edx, edx
    jnz     .done
    mov     [rsp + AV1_REDUCED_RAW_SEQ_LEN], eax
    lea     rdi, [r12 + r15]
    mov     esi, r13d
    sub     esi, r15d
    mov     edx, AV1_OBU_TYPE_SEQUENCE_HEADER
    mov     ecx, [rsp + AV1_REDUCED_RAW_SEQ_LEN]
    xor     r8d, r8d
    xor     r9d, r9d
    call    er_av1_obu_encode_prefix
    test    edx, edx
    jnz     .done
    add     r15d, eax
    mov     eax, r15d
    add     eax, [rsp + AV1_REDUCED_RAW_SEQ_LEN]
    jc      .no_space
    cmp     eax, r13d
    ja      .no_space
    mov     ecx, [rsp + AV1_REDUCED_RAW_SEQ_LEN]
    lea     rsi, [rsp + AV1_REDUCED_RAW_PAYLOAD]
    lea     rdi, [r12 + r15]
    call    copy_bytes
    add     r15d, [rsp + AV1_REDUCED_RAW_SEQ_LEN]

    lea     rdi, [rsp + AV1_REDUCED_RAW_PAYLOAD]
    mov     esi, [rsp + AV1_REDUCED_RAW_SEQ_LEN]
    lea     rdx, [rsp + AV1_REDUCED_RAW_SEQ_DESC]
    call    er_av1_sequence_decode_reduced_still
    test    edx, edx
    jnz     .done
    lea     rdi, [rsp + AV1_REDUCED_RAW_PAYLOAD]
    mov     esi, 16
    lea     rdx, [rsp + AV1_REDUCED_RAW_SEQ_DESC]
    mov     r14, [rsp + AV1_REDUCED_RAW_IMAGE_PTR]
    mov     ecx, [r14 + AV1_IMAGE_WIDTH]
    mov     r8d, [r14 + AV1_IMAGE_HEIGHT]
    call    er_av1_frame_encode_reduced_still
    test    edx, edx
    jnz     .done
    mov     [rsp + AV1_REDUCED_RAW_FRAME_LEN], eax

    lea     rdi, [r12 + r15]
    mov     esi, r13d
    sub     esi, r15d
    mov     edx, AV1_OBU_TYPE_FRAME_HEADER
    mov     ecx, [rsp + AV1_REDUCED_RAW_FRAME_LEN]
    xor     r8d, r8d
    xor     r9d, r9d
    call    er_av1_obu_encode_prefix
    test    edx, edx
    jnz     .done
    add     r15d, eax
    mov     eax, r15d
    add     eax, [rsp + AV1_REDUCED_RAW_FRAME_LEN]
    jc      .no_space
    cmp     eax, r13d
    ja      .no_space
    mov     ecx, [rsp + AV1_REDUCED_RAW_FRAME_LEN]
    lea     rsi, [rsp + AV1_REDUCED_RAW_PAYLOAD]
    lea     rdi, [r12 + r15]
    call    copy_bytes
    add     r15d, [rsp + AV1_REDUCED_RAW_FRAME_LEN]

    lea     rdi, [r12 + r15]
    mov     esi, r13d
    sub     esi, r15d
    mov     edx, AV1_OBU_TYPE_TILE_GROUP
    mov     ecx, [rsp + AV1_REDUCED_RAW_TILE_LEN]
    xor     r8d, r8d
    xor     r9d, r9d
    call    er_av1_obu_encode_prefix
    test    edx, edx
    jnz     .done
    add     r15d, eax
    lea     rdi, [r12 + r15]
    mov     esi, r13d
    sub     esi, r15d
    mov     rdx, [rsp + AV1_REDUCED_RAW_IMAGE_PTR]
    call    er_av1_tile_raw420_encode
    test    edx, edx
    jnz     .done
    add     r15d, eax

    lea     rdi, [r12 + AV1_IVF_HEADER_SIZE]
    mov     esi, r13d
    sub     esi, AV1_IVF_HEADER_SIZE
    lea     rdx, [r12 + AV1_IVF_HEADER_SIZE + AV1_IVF_FRAME_HEADER_SIZE]
    mov     ecx, r15d
    sub     ecx, AV1_IVF_HEADER_SIZE + AV1_IVF_FRAME_HEADER_SIZE
    mov     r8d, AV1_IVF_FIRST_TIMESTAMP
    call    er_av1_ivf_write_frame
    test    edx, edx
    jnz     .done
    add     eax, AV1_IVF_HEADER_SIZE
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
    er_stack_free AV1_REDUCED_RAW_STACK_SIZE
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_reduced_still_begin_ivf_raw420(out, cap, width, height, timebase_den, timebase_num)
; Initializes an empty IVF stream for reduced-still raw420 AV1 frames.
; rdi=out, esi=cap, edx=width, ecx=height, r8d=timebase_den, r9d=timebase_num.
; Returns eax=cursor for the first frame append.
er_fn er_av1_reduced_still_begin_ivf_raw420
    er_push rbx, r12
    er_stack_alloc AV1_REDUCED_APPEND_STACK_SIZE
    test    rdi, rdi
    jz      .invalid_param
    test    edx, edx
    jz      .invalid_param
    test    ecx, ecx
    jz      .invalid_param
    test    r8d, r8d
    jz      .invalid_param
    test    r9d, r9d
    jz      .invalid_param
    cmp     edx, AV1_IVF_DIMENSION_MAX
    ja      .corrupt
    cmp     ecx, AV1_IVF_DIMENSION_MAX
    ja      .corrupt
    mov     r12, rdi
    mov     ebx, esi
    mov     dword [rsp + AV1_REDUCED_APPEND_IVF_DESC + AV1_IVF_HDR_CODEC], AV1_IVF_CODEC_AV01
    mov     [rsp + AV1_REDUCED_APPEND_IVF_DESC + AV1_IVF_HDR_WIDTH], dx
    mov     [rsp + AV1_REDUCED_APPEND_IVF_DESC + AV1_IVF_HDR_HEIGHT], cx
    mov     [rsp + AV1_REDUCED_APPEND_IVF_DESC + AV1_IVF_HDR_TIMEBASE_DEN], r8d
    mov     [rsp + AV1_REDUCED_APPEND_IVF_DESC + AV1_IVF_HDR_TIMEBASE_NUM], r9d
    mov     dword [rsp + AV1_REDUCED_APPEND_IVF_DESC + AV1_IVF_HDR_FRAME_COUNT], 0
    mov     rdi, r12
    mov     esi, ebx
    lea     rdx, [rsp + AV1_REDUCED_APPEND_IVF_DESC]
    call    er_av1_ivf_encode_header
    test    edx, edx
    jnz     .done
    mov     eax, AV1_IVF_HEADER_SIZE
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
    er_stack_free AV1_REDUCED_APPEND_STACK_SIZE
    er_pop  rbx, r12
    er_ret

; er_av1_reduced_still_append_ivf_raw420(buf, cap, cursor, image_desc, timestamp)
; Appends one reduced-still raw420 AV1 frame to an existing IVF buffer.
; rdi=buf, esi=cap, edx=cursor, rcx=image_desc, r8=timestamp.
; Returns eax=next_cursor and updates the IVF frame count on success.
er_fn er_av1_reduced_still_append_ivf_raw420
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc AV1_REDUCED_APPEND_STACK_SIZE
    test    rdi, rdi
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     ebx, edx
    mov     r14, rcx
    mov     r15, r8
    cmp     ebx, AV1_IVF_HEADER_SIZE
    jb      .corrupt
    cmp     ebx, r13d
    ja      .corrupt
    mov     rdi, r12
    mov     esi, r13d
    lea     rdx, [rsp + AV1_REDUCED_APPEND_IVF_DESC]
    call    er_av1_ivf_decode_header
    test    edx, edx
    jnz     .done
    mov     rdi, r12
    mov     esi, ebx
    call    er_av1_ivf_validate_frame_count
    test    edx, edx
    jnz     .done
    mov     rdi, r12
    mov     esi, ebx
    call    er_av1_ivf_validate_timestamps
    test    edx, edx
    jnz     .done
    cmp     dword [rsp + AV1_REDUCED_APPEND_IVF_DESC + AV1_IVF_HDR_FRAME_COUNT], 0
    je      .check_dimensions
    mov     rdi, r12
    mov     esi, ebx
    mov     edx, [rsp + AV1_REDUCED_APPEND_IVF_DESC + AV1_IVF_HDR_FRAME_COUNT]
    dec     edx
    lea     rcx, [rsp + AV1_REDUCED_APPEND_FRAME_DESC]
    call    er_av1_ivf_seek_frame
    test    edx, edx
    jnz     .done
    cmp     r15, [rsp + AV1_REDUCED_APPEND_FRAME_DESC + AV1_IVF_FRAME_TIMESTAMP]
    jbe     .corrupt
.check_dimensions:
    movzx   eax, word [rsp + AV1_REDUCED_APPEND_IVF_DESC + AV1_IVF_HDR_WIDTH]
    cmp     [r14 + AV1_IMAGE_WIDTH], eax
    jne     .corrupt
    movzx   eax, word [rsp + AV1_REDUCED_APPEND_IVF_DESC + AV1_IVF_HDR_HEIGHT]
    cmp     [r14 + AV1_IMAGE_HEIGHT], eax
    jne     .corrupt
    mov     rdi, r14
    call    er_av1_tile_raw420_validate
    test    edx, edx
    jnz     .done
    mov     eax, r13d
    sub     eax, ebx
    cmp     eax, AV1_IVF_FRAME_HEADER_SIZE
    jb      .no_space
    lea     rdi, [r12 + rbx + AV1_IVF_FRAME_HEADER_SIZE]
    mov     esi, r13d
    sub     esi, ebx
    sub     esi, AV1_IVF_FRAME_HEADER_SIZE
    mov     rdx, r14
    call    er_av1_reduced_still_encode_raw420
    test    edx, edx
    jnz     .done
    mov     ecx, eax
    lea     rdi, [r12 + rbx]
    mov     esi, r13d
    sub     esi, ebx
    lea     rdx, [r12 + rbx + AV1_IVF_FRAME_HEADER_SIZE]
    mov     r8, r15
    call    er_av1_ivf_write_frame
    test    edx, edx
    jnz     .done
    add     eax, ebx
    jc      .corrupt
    mov     ecx, [r12 + AV1_IVF_FILE_FRAME_COUNT]
    cmp     ecx, AV1_LEB128_U32_MAX
    je      .corrupt
    inc     ecx
    mov     [r12 + AV1_IVF_FILE_FRAME_COUNT], ecx
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
    er_stack_free AV1_REDUCED_APPEND_STACK_SIZE
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_reduced_still_validate_raw420(stream, len, reduced_desc)
; Validates raw or IVF-wrapped reduced-still AV1 carries exactly one raw420 tile payload.
; rdi=stream, esi=len, rdx=reduced_desc. Returns eax=bytes_consumed.
er_fn er_av1_reduced_still_validate_raw420
    er_push rbx, r12
    test    rdx, rdx
    jz      .invalid_param
    mov     r12, rdx
    call    er_av1_reduced_still_decode_auto
    test    edx, edx
    jnz     .done
    mov     ebx, eax
    mov     edi, [r12 + AV1_REDUCED_FRAME + AV1_FRAME_WIDTH]
    mov     esi, [r12 + AV1_REDUCED_FRAME + AV1_FRAME_HEIGHT]
    call    er_av1_tile_raw420_size
    test    edx, edx
    jnz     .done
    cmp     eax, [r12 + AV1_REDUCED_TILE_LEN]
    jne     .corrupt
    mov     eax, ebx
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
    er_pop  rbx, r12
    er_ret

; er_av1_reduced_still_validate_ivf_frame_raw420(stream, len, frame_index, reduced_desc)
; Validates one indexed IVF reduced-still AV1 frame carries exactly one raw420 tile payload.
; rdi=stream, esi=len, edx=frame_index, rcx=reduced_desc. Returns eax=next IVF cursor.
er_fn er_av1_reduced_still_validate_ivf_frame_raw420
    er_push rbx, r12
    test    rcx, rcx
    jz      .invalid_param
    mov     r12, rcx
    call    er_av1_reduced_still_decode_ivf_frame
    test    edx, edx
    jnz     .done
    mov     ebx, eax
    mov     edi, [r12 + AV1_REDUCED_FRAME + AV1_FRAME_WIDTH]
    mov     esi, [r12 + AV1_REDUCED_FRAME + AV1_FRAME_HEIGHT]
    call    er_av1_tile_raw420_size
    test    edx, edx
    jnz     .done
    cmp     eax, [r12 + AV1_REDUCED_TILE_LEN]
    jne     .corrupt
    mov     eax, ebx
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
    er_pop  rbx, r12
    er_ret

; er_av1_reduced_still_decode_raw420(stream, len, image_desc, reduced_desc)
; Decodes raw 8-bit 4:2:0 tile payload from raw or IVF-wrapped reduced-still AV1.
; rdi=stream, esi=len, rdx=image_desc, rcx=reduced_desc. Returns eax=bytes_consumed.
er_fn er_av1_reduced_still_decode_raw420
    er_push rbx, r12, r13, r14
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    mov     r12, rdi
    mov     r13, rdx
    mov     r14, rcx
    mov     rdx, r14
    call    er_av1_reduced_still_decode_auto
    test    edx, edx
    jnz     .done
    mov     ebx, eax
    mov     eax, [r14 + AV1_REDUCED_FRAME + AV1_FRAME_WIDTH]
    cmp     [r13 + AV1_IMAGE_WIDTH], eax
    jne     .corrupt
    mov     eax, [r14 + AV1_REDUCED_FRAME + AV1_FRAME_HEIGHT]
    cmp     [r13 + AV1_IMAGE_HEIGHT], eax
    jne     .corrupt
    mov     rdi, r13
    call    er_av1_tile_raw420_validate
    test    edx, edx
    jnz     .done
    cmp     eax, [r14 + AV1_REDUCED_TILE_LEN]
    jne     .corrupt
    mov     eax, [r14 + AV1_REDUCED_TILE_OFFSET]
    lea     rdi, [r12 + rax]
    mov     esi, [r14 + AV1_REDUCED_TILE_LEN]
    mov     rdx, r13
    call    er_av1_tile_raw420_decode
    test    edx, edx
    jnz     .done
    mov     eax, ebx
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
    er_pop  rbx, r12, r13, r14
    er_ret

copy_bytes:
    test    ecx, ecx
    jz      .done
.loop:
    mov     al, [rsi]
    mov     [rdi], al
    inc     rsi
    inc     rdi
    dec     ecx
    jnz     .loop
.done:
    ret
