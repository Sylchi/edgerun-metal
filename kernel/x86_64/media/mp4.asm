; EdgeRun MP4/ISOBMFF box parser — x86_64 assembly.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/mp4_constants.inc"

%macro mp4_load_be32 2
    movzx   eax, byte [%1]
    shl     eax, 24
    movzx   r10d, byte [%1 + 1]
    shl     r10d, 16
    or      eax, r10d
    movzx   r10d, byte [%1 + 2]
    shl     r10d, 8
    or      eax, r10d
    movzx   r10d, byte [%1 + 3]
    or      eax, r10d
    mov     %2, eax
%endmacro

; er_mp4_read_box(buf, len, cursor, desc) -> eax=next_offset, rdx=error
; desc: type u32, header_size u32, payload_offset u32, payload_len u32, next_offset u32.
; rdi=buf, esi=len, edx=cursor, rcx=desc
er_fn er_mp4_read_box
    er_push rbx, r12
    test    rdi, rdi
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    mov     ebx, edx
    cmp     ebx, esi
    ja      .corrupt
    mov     eax, esi
    sub     eax, ebx
    cmp     eax, MP4_BOX_HEADER_SIZE
    jb      .no_data
    lea     r12, [rdi + rbx]
    mp4_load_be32 r12, edx
    mov     eax, [r12 + MP4_BOX_TYPE_OFFSET]
    mov     [rcx + MP4_BOX_DESC_TYPE], eax
    cmp     edx, MP4_BOX_SIZE_FIELD_TO_EOF
    je      .size_to_eof
    cmp     edx, MP4_BOX_SIZE_FIELD_LARGE
    je      .large_size
    cmp     edx, MP4_BOX_HEADER_SIZE
    jb      .corrupt
    mov     eax, ebx
    add     eax, edx
    jc      .corrupt
    cmp     eax, esi
    ja      .no_data
    mov     dword [rcx + MP4_BOX_DESC_HEADER_SIZE], MP4_BOX_HEADER_SIZE
    lea     r8d, [ebx + MP4_BOX_HEADER_SIZE]
    mov     [rcx + MP4_BOX_DESC_PAYLOAD_OFFSET], r8d
    mov     r9d, edx
    sub     r9d, MP4_BOX_HEADER_SIZE
    mov     [rcx + MP4_BOX_DESC_PAYLOAD_LEN], r9d
    mov     [rcx + MP4_BOX_DESC_NEXT_OFFSET], eax
    er_ok
    jmp     .done
.size_to_eof:
    mov     eax, esi
    sub     eax, ebx
    cmp     eax, MP4_BOX_HEADER_SIZE
    jb      .corrupt
    mov     dword [rcx + MP4_BOX_DESC_HEADER_SIZE], MP4_BOX_HEADER_SIZE
    lea     edx, [ebx + MP4_BOX_HEADER_SIZE]
    mov     [rcx + MP4_BOX_DESC_PAYLOAD_OFFSET], edx
    sub     eax, MP4_BOX_HEADER_SIZE
    mov     [rcx + MP4_BOX_DESC_PAYLOAD_LEN], eax
    mov     [rcx + MP4_BOX_DESC_NEXT_OFFSET], esi
    mov     eax, esi
    er_ok
    jmp     .done
.large_size:
    mov     eax, esi
    sub     eax, ebx
    cmp     eax, MP4_BOX_LARGE_HEADER_SIZE
    jb      .no_data
    cmp     dword [r12 + MP4_BOX_LARGE_SIZE_OFFSET], 0
    jne     .unsupported
    mp4_load_be32 r12 + MP4_BOX_LARGE_SIZE_OFFSET + 4, edx
    cmp     edx, MP4_BOX_LARGE_HEADER_SIZE
    jb      .corrupt
    mov     eax, ebx
    add     eax, edx
    jc      .corrupt
    cmp     eax, esi
    ja      .no_data
    mov     dword [rcx + MP4_BOX_DESC_HEADER_SIZE], MP4_BOX_LARGE_HEADER_SIZE
    lea     r8d, [ebx + MP4_BOX_LARGE_HEADER_SIZE]
    mov     [rcx + MP4_BOX_DESC_PAYLOAD_OFFSET], r8d
    mov     r9d, edx
    sub     r9d, MP4_BOX_LARGE_HEADER_SIZE
    mov     [rcx + MP4_BOX_DESC_PAYLOAD_LEN], r9d
    mov     [rcx + MP4_BOX_DESC_NEXT_OFFSET], eax
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

; er_mp4_ftyp_has_brand(buf, len, box_desc, brand) -> eax=1 if present, else 0.
; rdi=buf, esi=len, rdx=box_desc, ecx=brand
er_fn er_mp4_ftyp_has_brand
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    cmp     dword [rdx + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_FTYP
    jne     .unsupported
    mov     r8d, [rdx + MP4_BOX_DESC_PAYLOAD_OFFSET]
    mov     r9d, [rdx + MP4_BOX_DESC_PAYLOAD_LEN]
    cmp     r8d, esi
    ja      .corrupt
    mov     eax, esi
    sub     eax, r8d
    cmp     r9d, eax
    ja      .corrupt
    cmp     r9d, MP4_FTYP_PAYLOAD_MIN
    jb      .corrupt
    mov     eax, [rdi + r8 + MP4_FTYP_MAJOR_BRAND]
    cmp     eax, ecx
    je      .yes
    lea     r8d, [r8d + MP4_FTYP_COMPATIBLE_BRANDS]
    sub     r9d, MP4_FTYP_COMPATIBLE_BRANDS
    test    r9d, MP4_BRAND_SIZE - 1
    jnz     .corrupt
.loop:
    test    r9d, r9d
    jz      .no
    mov     eax, [rdi + r8]
    cmp     eax, ecx
    je      .yes
    add     r8d, MP4_BRAND_SIZE
    sub     r9d, MP4_BRAND_SIZE
    jmp     .loop
.yes:
    mov     eax, 1
    er_ok
    er_ret
.no:
    xor     eax, eax
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret
.unsupported:
    xor     eax, eax
    er_err  ERROR_UNSUPPORTED
    er_ret
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
    er_ret

; er_mp4_find_box(buf, len, cursor, type, desc) -> eax=next_offset, rdx=error
; Scans sibling boxes from cursor until a box with the requested fourcc is found.
; rdi=buf, esi=len, edx=cursor, ecx=type, r8=desc
er_fn er_mp4_find_box
    er_push rbx, r12, r13, r14, r15
    test    rdi, rdi
    jz      .invalid_param
    test    r8, r8
    jz      .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     ebx, edx
    mov     r14d, ecx
    mov     r15, r8
.loop:
    cmp     ebx, r13d
    je      .no_data
    ja      .corrupt
    mov     rdi, r12
    mov     esi, r13d
    mov     edx, ebx
    mov     rcx, r15
    call    er_mp4_read_box
    test    edx, edx
    jnz     .done
    cmp     dword [r15 + MP4_BOX_DESC_TYPE], r14d
    je      .ok
    cmp     eax, ebx
    jbe     .corrupt
    mov     ebx, eax
    jmp     .loop
.ok:
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
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_mp4_find_child_box(buf, len, parent_desc, type, child_desc) -> eax=next_offset, rdx=error
; Scans direct children inside a parent box payload.
; rdi=buf, esi=len, rdx=parent_desc, ecx=type, r8=child_desc
er_fn er_mp4_find_child_box
    test    rdx, rdx
    jz      .invalid_param
    mov     r9d, [rdx + MP4_BOX_DESC_PAYLOAD_OFFSET]
    mov     r10d, [rdx + MP4_BOX_DESC_PAYLOAD_LEN]
    cmp     r9d, esi
    ja      .corrupt
    mov     eax, esi
    sub     eax, r9d
    cmp     r10d, eax
    ja      .corrupt
    add     r10d, r9d
    jc      .corrupt
    cmp     r10d, esi
    ja      .corrupt
    mov     edx, r9d
    mov     esi, r10d
    call    er_mp4_find_box
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
    er_ret

; er_mp4_stsd_first_entry(buf, len, stsd_desc, entry_desc) -> eax=entry next offset, rdx=error
; Parses a SampleDescriptionBox fullbox header and returns its first sample entry.
; rdi=buf, esi=len, rdx=stsd_desc, rcx=entry_desc
er_fn er_mp4_stsd_first_entry
    er_push rbx, r12, r13
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    cmp     dword [rdx + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_STSD
    jne     .unsupported
    mov     ebx, [rdx + MP4_BOX_DESC_PAYLOAD_OFFSET]
    mov     r12d, [rdx + MP4_BOX_DESC_PAYLOAD_LEN]
    cmp     ebx, esi
    ja      .corrupt
    mov     eax, esi
    sub     eax, ebx
    cmp     r12d, eax
    ja      .corrupt
    cmp     r12d, MP4_STSD_FIRST_ENTRY_OFFSET
    jb      .corrupt
    lea     r13, [rdi + rbx + MP4_STSD_ENTRY_COUNT_OFFSET]
    mp4_load_be32 r13, eax
    test    eax, eax
    jz      .corrupt
    lea     edx, [ebx + MP4_STSD_FIRST_ENTRY_OFFSET]
    mov     r13d, ebx
    add     r13d, r12d
    jc      .corrupt
    mov     esi, r13d
    call    er_mp4_read_box
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
    er_pop  rbx, r12, r13
    er_ret

; er_mp4_sample_entry_find_child(buf, len, entry_desc, type, child_desc) -> eax=next_offset, rdx=error
; Scans child boxes inside an AV1 visual sample entry after its fixed 78-byte header.
; rdi=buf, esi=len, rdx=entry_desc, ecx=type, r8=child_desc
er_fn er_mp4_sample_entry_find_child
    er_push rbx, r12
    test    rdx, rdx
    jz      .invalid_param
    cmp     dword [rdx + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_AV01
    jne     .unsupported
    mov     ebx, [rdx + MP4_BOX_DESC_PAYLOAD_OFFSET]
    mov     r12d, [rdx + MP4_BOX_DESC_PAYLOAD_LEN]
    cmp     ebx, esi
    ja      .corrupt
    mov     eax, esi
    sub     eax, ebx
    cmp     r12d, eax
    ja      .corrupt
    cmp     r12d, MP4_VISUAL_SAMPLE_ENTRY_CHILD_OFFSET
    jb      .corrupt
    add     ebx, MP4_VISUAL_SAMPLE_ENTRY_CHILD_OFFSET
    sub     r12d, MP4_VISUAL_SAMPLE_ENTRY_CHILD_OFFSET
    add     r12d, ebx
    jc      .corrupt
    cmp     r12d, esi
    ja      .corrupt
    mov     edx, ebx
    mov     esi, r12d
    call    er_mp4_find_box
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
    er_pop  rbx, r12
    er_ret

; er_mp4_av1c_decode(buf, len, av1c_desc, out_desc) -> eax=config OBU len, rdx=error
; rdi=buf, esi=len, rdx=av1c_desc, rcx=out_desc
er_fn er_mp4_av1c_decode
    er_push rbx, r12
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    cmp     dword [rdx + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_AV1C
    jne     .unsupported
    mov     ebx, [rdx + MP4_BOX_DESC_PAYLOAD_OFFSET]
    mov     r12d, [rdx + MP4_BOX_DESC_PAYLOAD_LEN]
    cmp     ebx, esi
    ja      .corrupt
    mov     eax, esi
    sub     eax, ebx
    cmp     r12d, eax
    ja      .corrupt
    cmp     r12d, MP4_AV1C_PAYLOAD_MIN
    jb      .corrupt
    movzx   eax, byte [rdi + rbx]
    test    al, MP4_AV1C_MARKER_MASK
    jz      .corrupt
    and     eax, MP4_AV1C_VERSION_MASK
    cmp     eax, MP4_AV1C_VERSION
    jne     .unsupported
    movzx   eax, byte [rdi + rbx + 1]
    mov     edx, eax
    and     edx, MP4_AV1C_PROFILE_MASK
    shr     edx, MP4_AV1C_PROFILE_SHIFT
    mov     [rcx + MP4_AV1C_DESC_PROFILE], dl
    and     eax, MP4_AV1C_LEVEL_MASK
    mov     [rcx + MP4_AV1C_DESC_LEVEL], al
    movzx   eax, byte [rdi + rbx + 2]
    mov     edx, eax
    and     edx, MP4_AV1C_TIER_MASK
    shr     edx, MP4_AV1C_TIER_SHIFT
    mov     [rcx + MP4_AV1C_DESC_TIER], dl
    mov     edx, eax
    and     edx, MP4_AV1C_HIGH_BITDEPTH_MASK
    shr     edx, MP4_AV1C_HIGH_BITDEPTH_SHIFT
    mov     [rcx + MP4_AV1C_DESC_HIGH_BITDEPTH], dl
    mov     edx, eax
    and     edx, MP4_AV1C_TWELVE_BIT_MASK
    shr     edx, MP4_AV1C_TWELVE_BIT_SHIFT
    mov     [rcx + MP4_AV1C_DESC_TWELVE_BIT], dl
    mov     edx, eax
    and     edx, MP4_AV1C_MONOCHROME_MASK
    shr     edx, MP4_AV1C_MONOCHROME_SHIFT
    mov     [rcx + MP4_AV1C_DESC_MONOCHROME], dl
    mov     edx, eax
    and     edx, MP4_AV1C_SUBSAMPLING_X_MASK
    shr     edx, MP4_AV1C_SUBSAMPLING_X_SHIFT
    mov     [rcx + MP4_AV1C_DESC_SUBSAMPLING_X], dl
    mov     edx, eax
    and     edx, MP4_AV1C_SUBSAMPLING_Y_MASK
    shr     edx, MP4_AV1C_SUBSAMPLING_Y_SHIFT
    mov     [rcx + MP4_AV1C_DESC_SUBSAMPLING_Y], dl
    and     eax, MP4_AV1C_CHROMA_POSITION_MASK
    mov     [rcx + MP4_AV1C_DESC_CHROMA_POSITION], al
    movzx   eax, byte [rdi + rbx + 3]
    mov     edx, eax
    and     edx, MP4_AV1C_IPD_PRESENT_MASK
    shr     edx, MP4_AV1C_IPD_PRESENT_SHIFT
    mov     [rcx + MP4_AV1C_DESC_IPD_PRESENT], dl
    and     eax, MP4_AV1C_IPD_MINUS_ONE_MASK
    mov     [rcx + MP4_AV1C_DESC_IPD_MINUS_ONE], al
    lea     eax, [ebx + MP4_AV1C_PAYLOAD_MIN]
    mov     [rcx + MP4_AV1C_DESC_CONFIG_OBU_OFFSET], eax
    mov     eax, r12d
    sub     eax, MP4_AV1C_PAYLOAD_MIN
    mov     [rcx + MP4_AV1C_DESC_CONFIG_OBU_LEN], eax
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
    er_pop  rbx, r12
    er_ret

; er_mp4_stsz_sample_count(buf, len, stsz_desc) -> eax=count, rdx=error
; rdi=buf, esi=len, rdx=stsz_desc
er_fn er_mp4_stsz_sample_count
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    cmp     dword [rdx + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_STSZ
    jne     .unsupported
    mov     r8d, [rdx + MP4_BOX_DESC_PAYLOAD_OFFSET]
    mov     r9d, [rdx + MP4_BOX_DESC_PAYLOAD_LEN]
    cmp     r8d, esi
    ja      .corrupt
    mov     eax, esi
    sub     eax, r8d
    cmp     r9d, eax
    ja      .corrupt
    cmp     r9d, MP4_STSZ_FIRST_ENTRY_OFFSET
    jb      .corrupt
    lea     r8, [rdi + r8 + MP4_STSZ_SAMPLE_COUNT_OFFSET]
    mp4_load_be32 r8, eax
    er_ok
    er_ret
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    er_ret
.unsupported:
    xor     eax, eax
    er_err  ERROR_UNSUPPORTED
    er_ret
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
    er_ret

; er_mp4_stsz_sample_size(buf, len, stsz_desc, sample_index) -> eax=size, rdx=error
; sample_index is zero-based. Constant-size stsz tables return the fixed sample size.
; rdi=buf, esi=len, rdx=stsz_desc, ecx=sample_index
er_fn er_mp4_stsz_sample_size
    er_push rbx, r12, r13
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    cmp     dword [rdx + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_STSZ
    jne     .unsupported
    mov     ebx, [rdx + MP4_BOX_DESC_PAYLOAD_OFFSET]
    mov     r12d, [rdx + MP4_BOX_DESC_PAYLOAD_LEN]
    cmp     ebx, esi
    ja      .corrupt
    mov     eax, esi
    sub     eax, ebx
    cmp     r12d, eax
    ja      .corrupt
    cmp     r12d, MP4_STSZ_FIRST_ENTRY_OFFSET
    jb      .corrupt
    lea     r13, [rdi + rbx + MP4_STSZ_SAMPLE_COUNT_OFFSET]
    mp4_load_be32 r13, eax
    cmp     ecx, eax
    jae     .no_data
    lea     r13, [rdi + rbx + MP4_STSZ_SAMPLE_SIZE_OFFSET]
    mp4_load_be32 r13, eax
    test    eax, eax
    jnz     .ok
    mov     eax, ecx
    imul    eax, MP4_STSZ_ENTRY_SIZE
    add     eax, MP4_STSZ_FIRST_ENTRY_OFFSET
    jc      .corrupt
    add     eax, MP4_STSZ_ENTRY_SIZE
    jc      .corrupt
    cmp     eax, r12d
    ja      .corrupt
    mov     eax, ecx
    imul    eax, MP4_STSZ_ENTRY_SIZE
    lea     r13, [rdi + rbx + MP4_STSZ_FIRST_ENTRY_OFFSET + rax]
    mp4_load_be32 r13, eax
.ok:
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
    er_pop  rbx, r12, r13
    er_ret

; er_mp4_stco_chunk_offset(buf, len, stco_desc, chunk_index) -> eax=offset, rdx=error
; chunk_index is zero-based and reads 32-bit chunk offsets.
; rdi=buf, esi=len, rdx=stco_desc, ecx=chunk_index
er_fn er_mp4_stco_chunk_offset
    er_push rbx, r12, r13
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    cmp     dword [rdx + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_STCO
    jne     .unsupported
    mov     ebx, [rdx + MP4_BOX_DESC_PAYLOAD_OFFSET]
    mov     r12d, [rdx + MP4_BOX_DESC_PAYLOAD_LEN]
    cmp     ebx, esi
    ja      .corrupt
    mov     eax, esi
    sub     eax, ebx
    cmp     r12d, eax
    ja      .corrupt
    cmp     r12d, MP4_STCO_FIRST_ENTRY_OFFSET
    jb      .corrupt
    lea     r13, [rdi + rbx + MP4_STCO_ENTRY_COUNT_OFFSET]
    mp4_load_be32 r13, eax
    cmp     ecx, eax
    jae     .no_data
    mov     eax, ecx
    imul    eax, MP4_STCO_ENTRY_SIZE
    add     eax, MP4_STCO_FIRST_ENTRY_OFFSET
    jc      .corrupt
    add     eax, MP4_STCO_ENTRY_SIZE
    jc      .corrupt
    cmp     eax, r12d
    ja      .corrupt
    mov     eax, ecx
    imul    eax, MP4_STCO_ENTRY_SIZE
    lea     r13, [rdi + rbx + MP4_STCO_FIRST_ENTRY_OFFSET + rax]
    mp4_load_be32 r13, eax
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
    er_pop  rbx, r12, r13
    er_ret

; er_mp4_stsc_entry(buf, len, stsc_desc, entry_index, out_desc) -> eax=entry_count, rdx=error
; entry_index is zero-based. out_desc receives first_chunk, samples_per_chunk, sample_desc_index.
; rdi=buf, esi=len, rdx=stsc_desc, ecx=entry_index, r8=out_desc
er_fn er_mp4_stsc_entry
    er_push rbx, r12, r13, r14
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    test    r8, r8
    jz      .invalid_param
    cmp     dword [rdx + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_STSC
    jne     .unsupported
    mov     ebx, [rdx + MP4_BOX_DESC_PAYLOAD_OFFSET]
    mov     r12d, [rdx + MP4_BOX_DESC_PAYLOAD_LEN]
    cmp     ebx, esi
    ja      .corrupt
    mov     eax, esi
    sub     eax, ebx
    cmp     r12d, eax
    ja      .corrupt
    cmp     r12d, MP4_STSC_FIRST_ENTRY_OFFSET
    jb      .corrupt
    lea     r13, [rdi + rbx + MP4_STSC_ENTRY_COUNT_OFFSET]
    mp4_load_be32 r13, r14d
    cmp     ecx, r14d
    jae     .no_data
    mov     eax, ecx
    imul    eax, MP4_STSC_ENTRY_SIZE
    add     eax, MP4_STSC_FIRST_ENTRY_OFFSET
    jc      .corrupt
    add     eax, MP4_STSC_ENTRY_SIZE
    jc      .corrupt
    cmp     eax, r12d
    ja      .corrupt
    mov     eax, ecx
    imul    eax, MP4_STSC_ENTRY_SIZE
    lea     r13, [rdi + rbx + MP4_STSC_FIRST_ENTRY_OFFSET + rax]
    mp4_load_be32 r13 + MP4_STSC_ENTRY_FIRST_CHUNK, eax
    mov     [r8 + MP4_STSC_DESC_FIRST_CHUNK], eax
    mp4_load_be32 r13 + MP4_STSC_ENTRY_SAMPLES_PER_CHUNK, eax
    mov     [r8 + MP4_STSC_DESC_SAMPLES_PER_CHUNK], eax
    mp4_load_be32 r13 + MP4_STSC_ENTRY_SAMPLE_DESC_INDEX, eax
    mov     [r8 + MP4_STSC_DESC_SAMPLE_DESC_INDEX], eax
    mov     eax, r14d
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
    er_pop  rbx, r12, r13, r14
    er_ret

; er_mp4_is_av1(buf, len) -> eax=1 if the file starts with ftyp carrying av01.
; rdi=buf, esi=len
er_fn er_mp4_is_av1
    er_push rbx, r12
    er_stack_alloc MP4_BOX_DESC_SIZE
    test    rdi, rdi
    jz      .invalid_param
    mov     rbx, rdi
    mov     r12d, esi
    xor     edx, edx
    mov     rcx, rsp
    call    er_mp4_read_box
    test    edx, edx
    jnz     .done
    mov     rdi, rbx
    mov     esi, r12d
    mov     rdx, rsp
    mov     ecx, MP4_BRAND_AV01
    call    er_mp4_ftyp_has_brand
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done:
    er_stack_free MP4_BOX_DESC_SIZE
    er_pop  rbx, r12
    er_ret
