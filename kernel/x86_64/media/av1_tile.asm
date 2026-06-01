; EdgeRun AV1 tile-group parser/encoder — x86_64 assembly.
; This handles the conforming single-tile reduced-still path.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/av1_constants.inc"

SECTION .text

; er_av1_tile_group_decode_single(payload, len, desc) -> eax=bytes_consumed, rdx=error
; rdi=payload, esi=len, rdx=desc. For NumTiles=1, tile data is the whole payload.
er_fn er_av1_tile_group_decode_single
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
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
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    cmp     ecx, esi
    ja      .no_space
    mov     r12, rdi
    mov     r13, rdx
    mov     ebx, ecx
    test    ebx, ebx
    jz      .ok
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
    test    edi, edi
    jz      .invalid_param
    test    esi, esi
    jz      .invalid_param
    mov     eax, edi
    mul     esi
    test    edx, edx
    jnz     .corrupt
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
    test    edx, edx
    jnz     .corrupt
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
    test    rdi, rdi
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    test    r8, r8
    jz      .invalid_param
    test    r9, r9
    jz      .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     r14d, edx
    mov     r15, rcx
    mov     rbx, r8
    mov     [r12 + AV1_IMAGE_V_PTR], r9
    mov     edi, r13d
    mov     esi, r14d
    call    er_av1_tile_raw420_size
    test    edx, edx
    jnz     .done
    mov     r10d, eax
    mov     eax, r13d
    mul     r14d
    test    edx, edx
    jnz     .corrupt
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
    test    rdi, rdi
    jz      .invalid_param
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
    test    edx, edx
    jnz     .done
    mov     r13d, eax
    mov     eax, [r12 + AV1_IMAGE_WIDTH]
    mul     dword [r12 + AV1_IMAGE_HEIGHT]
    test    edx, edx
    jnz     .corrupt
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
