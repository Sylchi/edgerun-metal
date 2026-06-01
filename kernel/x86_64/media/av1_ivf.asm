; EdgeRun AV1 IVF container parser/encoder — x86_64 assembly.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/av1_constants.inc"

SECTION .text

; er_av1_ivf_is(buf, len) -> eax=1 if DKIF, else 0
; rdi=buf, esi=len
er_fn er_av1_ivf_is
    er_check_zero rdi, .no
    cmp     esi, 4
    jb      .no
    cmp     dword [rdi], AV1_IVF_SIGNATURE
    jne     .no
    mov     eax, 1
    er_ok
    er_ret
.no:
    xor     eax, eax
    er_ok
    er_ret

; er_av1_ivf_decode_header(buf, len, desc) -> eax=AV1_IVF_HEADER_SIZE, rdx=error
; desc: codec u32, width u16, height u16, timebase_den u32,
;       timebase_num u32, frame_count u32.
; rdi=buf, esi=len, rdx=desc
er_fn er_av1_ivf_decode_header
    er_check_zero rdi, .invalid_param
    er_check_zero rdx, .invalid_param
    cmp     esi, AV1_IVF_HEADER_SIZE
    jb      .no_data
    cmp     dword [rdi], AV1_IVF_SIGNATURE
    jne     .unsupported
    cmp     word [rdi + AV1_IVF_FILE_VERSION], 0
    jne     .unsupported
    cmp     word [rdi + AV1_IVF_FILE_HEADER_LEN], AV1_IVF_HEADER_SIZE
    jne     .corrupt
    cmp     dword [rdi + AV1_IVF_FILE_CODEC], AV1_IVF_CODEC_AV01
    jne     .unsupported
    movzx   eax, word [rdi + AV1_IVF_FILE_WIDTH]
    er_check_zero eax, .corrupt
    movzx   ecx, word [rdi + AV1_IVF_FILE_HEIGHT]
    er_check_zero ecx, .corrupt
    mov     [rdx + AV1_IVF_HDR_CODEC], dword AV1_IVF_CODEC_AV01
    mov     [rdx + AV1_IVF_HDR_WIDTH], ax
    mov     [rdx + AV1_IVF_HDR_HEIGHT], cx
    mov     eax, [rdi + AV1_IVF_FILE_TIMEBASE_DEN]
    mov     [rdx + AV1_IVF_HDR_TIMEBASE_DEN], eax
    mov     eax, [rdi + AV1_IVF_FILE_TIMEBASE_NUM]
    mov     [rdx + AV1_IVF_HDR_TIMEBASE_NUM], eax
    mov     eax, [rdi + AV1_IVF_FILE_FRAME_COUNT]
    mov     [rdx + AV1_IVF_HDR_FRAME_COUNT], eax
    mov     eax, AV1_IVF_HEADER_SIZE
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret
.no_data:
    xor     eax, eax
    er_err  ERROR_NO_DATA
    er_ret
.unsupported:
    xor     eax, eax
    er_err  ERROR_UNSUPPORTED
    er_ret
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
    er_ret

; er_av1_ivf_read_frame(buf, len, cursor, frame_desc) -> eax=next_cursor, rdx=error
; frame_desc: payload_offset u32, payload_len u32, timestamp u64.
; rdi=buf, esi=len, edx=cursor, rcx=frame_desc
er_fn er_av1_ivf_read_frame
    er_push rbx, r12, r13
    er_check_zero rdi, .invalid_param
    er_check_zero rcx, .invalid_param
    mov     r12, rdi
    mov     r13, rcx
    mov     ebx, edx
    cmp     ebx, esi
    ja      .corrupt
    mov     eax, esi
    sub     eax, ebx
    cmp     eax, AV1_IVF_FRAME_HEADER_SIZE
    jb      .no_data
    mov     eax, [r12 + rbx + AV1_IVF_FRAME_RECORD_LEN]
    mov     edx, ebx
    add     edx, AV1_IVF_FRAME_HEADER_SIZE
    jc      .corrupt
    mov     r8d, edx
    add     r8d, eax
    jc      .corrupt
    cmp     r8d, esi
    ja      .no_data
    mov     [r13 + AV1_IVF_FRAME_PAYLOAD_OFFSET], edx
    mov     [r13 + AV1_IVF_FRAME_PAYLOAD_LEN], eax
    mov     rcx, [r12 + rbx + AV1_IVF_FRAME_RECORD_TIMESTAMP]
    mov     [r13 + AV1_IVF_FRAME_TIMESTAMP], rcx
    mov     eax, r8d
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
    er_pop  rbx, r12, r13
    er_ret

; er_av1_ivf_count_frames(buf, len) -> eax=actual frame count, rdx=error
; Scans IVF frame records from the start of the payload to EOF.
; rdi=buf, esi=len
er_fn er_av1_ivf_count_frames
    er_push rbx, r12, r13, r14
    er_stack_alloc AV1_IVF_SCAN_STACK_SIZE
    er_check_zero rdi, .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     rdi, r12
    mov     esi, r13d
    lea     rdx, [rsp + AV1_IVF_SCAN_HDR]
    call    er_av1_ivf_decode_header
    er_check_nonzero edx, .done
    mov     ebx, AV1_IVF_HEADER_SIZE
    xor     r14d, r14d
.loop:
    cmp     ebx, r13d
    je      .ok
    ja      .corrupt
    mov     rdi, r12
    mov     esi, r13d
    mov     edx, ebx
    lea     rcx, [rsp + AV1_IVF_SCAN_FRAME]
    call    er_av1_ivf_read_frame
    er_check_nonzero edx, .done
    cmp     r14d, AV1_LEB128_U32_MAX
    je      .corrupt
    inc     r14d
    mov     ebx, eax
    jmp     .loop
.ok:
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
    er_stack_free AV1_IVF_SCAN_STACK_SIZE
    er_pop  rbx, r12, r13, r14
    er_ret

; er_av1_ivf_validate_frame_count(buf, len) -> eax=actual frame count, rdx=error
; Requires the declared IVF frame count to match the number of complete frames present.
; rdi=buf, esi=len
er_fn er_av1_ivf_validate_frame_count
    er_push rbx, r12, r13
    er_stack_alloc AV1_IVF_HDR_SIZE
    er_check_zero rdi, .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    call    er_av1_ivf_count_frames
    er_check_nonzero edx, .done
    mov     ebx, eax
    mov     rdi, r12
    mov     esi, r13d
    mov     rdx, rsp
    call    er_av1_ivf_decode_header
    er_check_nonzero edx, .done
    cmp     ebx, [rsp + AV1_IVF_HDR_FRAME_COUNT]
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
    er_stack_free AV1_IVF_HDR_SIZE
    er_pop  rbx, r12, r13
    er_ret

; er_av1_ivf_validate_timestamps(buf, len) -> eax=frame count, rdx=error
; Requires complete IVF frames with strictly increasing timestamps.
; rdi=buf, esi=len
er_fn er_av1_ivf_validate_timestamps
    er_push rbx, r12, r13, r14
    er_stack_alloc AV1_IVF_SCAN_STACK_SIZE
    er_check_zero rdi, .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     rdi, r12
    mov     esi, r13d
    lea     rdx, [rsp + AV1_IVF_SCAN_HDR]
    call    er_av1_ivf_decode_header
    er_check_nonzero edx, .done
    mov     ebx, AV1_IVF_HEADER_SIZE
    xor     r14d, r14d
    mov     qword [rsp + AV1_IVF_SCAN_PREV_TIMESTAMP], 0
.loop:
    cmp     ebx, r13d
    je      .ok
    ja      .corrupt
    mov     rdi, r12
    mov     esi, r13d
    mov     edx, ebx
    lea     rcx, [rsp + AV1_IVF_SCAN_FRAME]
    call    er_av1_ivf_read_frame
    er_check_nonzero edx, .done
    er_check_zero r14d, .first_frame
    mov     rcx, [rsp + AV1_IVF_SCAN_FRAME + AV1_IVF_FRAME_TIMESTAMP]
    cmp     rcx, [rsp + AV1_IVF_SCAN_PREV_TIMESTAMP]
    jbe     .corrupt
    jmp     .record
.first_frame:
    mov     rcx, [rsp + AV1_IVF_SCAN_FRAME + AV1_IVF_FRAME_TIMESTAMP]
.record:
    mov     [rsp + AV1_IVF_SCAN_PREV_TIMESTAMP], rcx
    cmp     r14d, AV1_LEB128_U32_MAX
    je      .corrupt
    inc     r14d
    mov     ebx, eax
    jmp     .loop
.ok:
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
    er_stack_free AV1_IVF_SCAN_STACK_SIZE
    er_pop  rbx, r12, r13, r14
    er_ret

; er_av1_ivf_seek_frame(buf, len, frame_index, frame_desc) -> eax=next_cursor, rdx=error
; Finds one declared IVF frame by zero-based index.
; rdi=buf, esi=len, edx=frame_index, rcx=frame_desc
er_fn er_av1_ivf_seek_frame
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc AV1_IVF_HDR_SIZE
    er_check_zero rdi, .invalid_param
    er_check_zero rcx, .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     r14d, edx
    mov     r15, rcx
    mov     rdi, r12
    mov     esi, r13d
    mov     rdx, rsp
    call    er_av1_ivf_decode_header
    er_check_nonzero edx, .done
    cmp     r14d, [rsp + AV1_IVF_HDR_FRAME_COUNT]
    jae     .not_found
    mov     ebx, AV1_IVF_HEADER_SIZE
.loop:
    mov     rdi, r12
    mov     esi, r13d
    mov     edx, ebx
    mov     rcx, r15
    call    er_av1_ivf_read_frame
    er_check_nonzero edx, .done
    er_check_zero r14d, .ok
    dec     r14d
    mov     ebx, eax
    jmp     .loop
.ok:
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done
.not_found:
    xor     eax, eax
    er_err  ERROR_NOT_FOUND
.done:
    er_stack_free AV1_IVF_HDR_SIZE
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_av1_ivf_encode_header(out, cap, desc) -> eax=AV1_IVF_HEADER_SIZE, rdx=error
; desc uses AV1_IVF_HDR_* fields. The codec is always AV01.
; rdi=out, esi=cap, rdx=desc
er_fn er_av1_ivf_encode_header
    er_check_zero rdi, .invalid_param
    er_check_zero rdx, .invalid_param
    cmp     esi, AV1_IVF_HEADER_SIZE
    jb      .no_space
    movzx   eax, word [rdx + AV1_IVF_HDR_WIDTH]
    er_check_zero eax, .corrupt
    movzx   ecx, word [rdx + AV1_IVF_HDR_HEIGHT]
    er_check_zero ecx, .corrupt
    mov     dword [rdi], AV1_IVF_SIGNATURE
    mov     word [rdi + AV1_IVF_FILE_VERSION], 0
    mov     word [rdi + AV1_IVF_FILE_HEADER_LEN], AV1_IVF_HEADER_SIZE
    mov     dword [rdi + AV1_IVF_FILE_CODEC], AV1_IVF_CODEC_AV01
    mov     [rdi + AV1_IVF_FILE_WIDTH], ax
    mov     [rdi + AV1_IVF_FILE_HEIGHT], cx
    mov     eax, [rdx + AV1_IVF_HDR_TIMEBASE_DEN]
    mov     [rdi + AV1_IVF_FILE_TIMEBASE_DEN], eax
    mov     eax, [rdx + AV1_IVF_HDR_TIMEBASE_NUM]
    mov     [rdi + AV1_IVF_FILE_TIMEBASE_NUM], eax
    mov     eax, [rdx + AV1_IVF_HDR_FRAME_COUNT]
    mov     [rdi + AV1_IVF_FILE_FRAME_COUNT], eax
    mov     dword [rdi + AV1_IVF_FILE_RESERVED], 0
    mov     eax, AV1_IVF_HEADER_SIZE
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret
.no_space:
    xor     eax, eax
    er_err  ERROR_NO_SPACE
    er_ret
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
    er_ret

; er_av1_ivf_write_frame(out, cap, payload, payload_len, timestamp)
; -> eax=bytes_written, rdx=error
; rdi=out, esi=cap, rdx=payload, ecx=payload_len, r8=timestamp
er_fn er_av1_ivf_write_frame
    er_push rbx, r12, r13, r14
    er_check_zero rdi, .invalid_param
    er_check_zero rdx, .invalid_param
    mov     eax, ecx
    add     eax, AV1_IVF_FRAME_HEADER_SIZE
    jc      .no_space
    cmp     eax, esi
    ja      .no_space
    mov     r12, rdi
    mov     r13, rdx
    mov     r14d, ecx
    mov     [r12 + AV1_IVF_FRAME_RECORD_LEN], ecx
    mov     [r12 + AV1_IVF_FRAME_RECORD_TIMESTAMP], r8
    lea     rdi, [r12 + AV1_IVF_FRAME_HEADER_SIZE]
    mov     rsi, r13
    mov     ecx, r14d
    call    copy_bytes
    mov     eax, r14d
    add     eax, AV1_IVF_FRAME_HEADER_SIZE
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
