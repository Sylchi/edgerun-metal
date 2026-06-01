; EdgeRun VP9 uncompressed frame header helpers — x86_64 assembly.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/vp9_constants.inc"

SECTION .text

; er_vp9_parse_frame_header(buf, len, desc) -> eax=header bytes consumed, rdx=error
; Parses VP9 profile, show-existing-frame, and profile-0 key/inter frame header prefix.
; rdi=buf, esi=len, rdx=desc
er_fn er_vp9_parse_frame_header
    er_push rbx, r12
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    test    esi, esi
    jz      .no_data
    mov     r12, rdx
    movzx   ebx, byte [rdi]
    mov     eax, ebx
    and     eax, VP9_FRAME_MARKER_MASK
    cmp     eax, VP9_FRAME_MARKER
    jne     .corrupt
    mov     [r12 + VP9_HEADER_DESC_MARKER], al
    xor     ecx, ecx
    test    ebx, VP9_PROFILE_LOW_MASK
    setnz   cl
    xor     eax, eax
    test    ebx, VP9_PROFILE_HIGH_MASK
    setnz   al
    shl     eax, 1
    or      eax, ecx
    mov     [r12 + VP9_HEADER_DESC_PROFILE], al
    cmp     eax, VP9_PROFILE_MAX
    ja      .unsupported
    cmp     eax, VP9_PROFILE_MAX
    jne     .profile_ok
    test    ebx, VP9_PROFILE_RESERVED_MASK
    jnz     .unsupported
.profile_ok:
    xor     eax, eax
    test    ebx, VP9_SHOW_EXISTING_MASK
    setnz   al
    mov     [r12 + VP9_HEADER_DESC_SHOW_EXISTING], al
    test    eax, eax
    jnz     .show_existing
    mov     byte [r12 + VP9_HEADER_DESC_EXISTING_FRAME_IDX], 0
    mov     eax, ebx
    and     eax, VP9_FRAME_TYPE_MASK
    shr     eax, VP9_FRAME_TYPE_SHIFT
    mov     [r12 + VP9_HEADER_DESC_FRAME_TYPE], al
    xor     eax, eax
    test    ebx, VP9_SHOW_FRAME_MASK
    setnz   al
    mov     [r12 + VP9_HEADER_DESC_SHOW_FRAME], al
    xor     eax, eax
    test    ebx, VP9_ERROR_RESILIENT_MASK
    setnz   al
    mov     [r12 + VP9_HEADER_DESC_ERROR_RESILIENT], al
    cmp     byte [r12 + VP9_HEADER_DESC_FRAME_TYPE], VP9_FRAME_TYPE_KEY
    je      .key_frame
    cmp     byte [r12 + VP9_HEADER_DESC_FRAME_TYPE], VP9_FRAME_TYPE_INTER
    jne     .corrupt
    mov     word [r12 + VP9_HEADER_DESC_WIDTH], 0
    mov     word [r12 + VP9_HEADER_DESC_HEIGHT], 0
    mov     word [r12 + VP9_HEADER_DESC_RENDER_WIDTH], 0
    mov     word [r12 + VP9_HEADER_DESC_RENDER_HEIGHT], 0
    mov     eax, VP9_INTER_HEADER_SIZE
    er_ok
    jmp     .done
.show_existing:
    mov     eax, ebx
    and     eax, VP9_SHOW_EXISTING_FRAME_INDEX_MASK
    shr     eax, VP9_SHOW_EXISTING_FRAME_INDEX_SHIFT
    mov     [r12 + VP9_HEADER_DESC_EXISTING_FRAME_IDX], al
    mov     byte [r12 + VP9_HEADER_DESC_FRAME_TYPE], VP9_FRAME_TYPE_INTER
    mov     byte [r12 + VP9_HEADER_DESC_SHOW_FRAME], 1
    mov     byte [r12 + VP9_HEADER_DESC_ERROR_RESILIENT], 0
    mov     word [r12 + VP9_HEADER_DESC_WIDTH], 0
    mov     word [r12 + VP9_HEADER_DESC_HEIGHT], 0
    mov     word [r12 + VP9_HEADER_DESC_RENDER_WIDTH], 0
    mov     word [r12 + VP9_HEADER_DESC_RENDER_HEIGHT], 0
    mov     eax, VP9_SHOW_EXISTING_HEADER_SIZE
    er_ok
    jmp     .done
.key_frame:
    cmp     esi, VP9_KEY_HEADER_SIZE
    jb      .no_data
    cmp     byte [rdi + VP9_SYNC_CODE_OFFSET], VP9_SYNC_CODE_0
    jne     .corrupt
    cmp     byte [rdi + VP9_SYNC_CODE_OFFSET + 1], VP9_SYNC_CODE_1
    jne     .corrupt
    cmp     byte [rdi + VP9_SYNC_CODE_OFFSET + 2], VP9_SYNC_CODE_2
    jne     .corrupt
    movzx   eax, word [rdi + VP9_FRAME_WIDTH_OFFSET]
    inc     eax
    test    eax, eax
    jz      .corrupt
    mov     [r12 + VP9_HEADER_DESC_WIDTH], ax
    movzx   eax, word [rdi + VP9_FRAME_HEIGHT_OFFSET]
    inc     eax
    test    eax, eax
    jz      .corrupt
    mov     [r12 + VP9_HEADER_DESC_HEIGHT], ax
    movzx   eax, word [rdi + VP9_RENDER_WIDTH_OFFSET]
    inc     eax
    test    eax, eax
    jz      .corrupt
    mov     [r12 + VP9_HEADER_DESC_RENDER_WIDTH], ax
    movzx   eax, word [rdi + VP9_RENDER_HEIGHT_OFFSET]
    inc     eax
    test    eax, eax
    jz      .corrupt
    mov     [r12 + VP9_HEADER_DESC_RENDER_HEIGHT], ax
    mov     eax, VP9_KEY_HEADER_SIZE
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
    er_pop  rbx, r12
    er_ret

; er_vp9_is_key_frame(buf, len) -> eax=1 key frame, eax=0 otherwise, rdx=error
; rdi=buf, esi=len
er_fn er_vp9_is_key_frame
    er_stack_alloc VP9_HEADER_DESC_SIZE
    mov     rdx, rsp
    call    er_vp9_parse_frame_header
    test    edx, edx
    jnz     .done
    cmp     byte [rsp + VP9_HEADER_DESC_SHOW_EXISTING], 0
    jne     .not_key
    cmp     byte [rsp + VP9_HEADER_DESC_FRAME_TYPE], VP9_FRAME_TYPE_KEY
    sete    al
    movzx   eax, al
    jmp     .ok
.not_key:
    xor     eax, eax
.ok:
    er_ok
.done:
    er_stack_free VP9_HEADER_DESC_SIZE
    er_ret
