; EdgeRun MP4/ISOBMFF box parser — x86_64 assembly.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/mp4_constants.inc"

extern er_av1_obu_route_sample
extern er_av1_obu_scan_units

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

%macro mp4_load_be16 2
    movzx   eax, byte [%1]
    shl     eax, 8
    movzx   r10d, byte [%1 + 1]
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

; er_mp4_sample_tables_find(buf, len, stbl_desc, out_tables) -> eax=MP4_SAMPLE_TABLES_SIZE, rdx=error
; Finds the required sample-location boxes inside stbl: stsz, stco-or-co64, and stsc.
; rdi=buf, esi=len, rdx=stbl_desc, rcx=out_tables
er_fn er_mp4_sample_tables_find
    er_push rbx, r12, r13, r14
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    cmp     dword [rdx + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_STBL
    jne     .unsupported
    mov     r12, rdi
    mov     r13d, esi
    mov     r14, rdx
    mov     rbx, rcx
    mov     rdi, r12
    mov     esi, r13d
    mov     rdx, r14
    mov     ecx, MP4_BOX_TYPE_STSZ
    lea     r8, [rbx + MP4_SAMPLE_TABLES_STSZ_DESC]
    call    er_mp4_find_child_box
    test    edx, edx
    jnz     .done
    mov     rdi, r12
    mov     esi, r13d
    mov     rdx, r14
    mov     ecx, MP4_BOX_TYPE_STCO
    lea     r8, [rbx + MP4_SAMPLE_TABLES_STCO_DESC]
    call    er_mp4_find_child_box
    test    edx, edx
    jz      .find_stsc
    cmp     edx, ERROR_NO_DATA
    jne     .done
    mov     rdi, r12
    mov     esi, r13d
    mov     rdx, r14
    mov     ecx, MP4_BOX_TYPE_CO64
    lea     r8, [rbx + MP4_SAMPLE_TABLES_STCO_DESC]
    call    er_mp4_find_child_box
    test    edx, edx
    jnz     .done
.find_stsc:
    mov     rdi, r12
    mov     esi, r13d
    mov     rdx, r14
    mov     ecx, MP4_BOX_TYPE_STSC
    lea     r8, [rbx + MP4_SAMPLE_TABLES_STSC_DESC]
    call    er_mp4_find_child_box
    test    edx, edx
    jnz     .done
    mov     eax, MP4_SAMPLE_TABLES_SIZE
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done
.unsupported:
    xor     eax, eax
    er_err  ERROR_UNSUPPORTED
.done:
    er_pop  rbx, r12, r13, r14
    er_ret

; er_mp4_video_stbl_find(buf, len, moov_desc, out_stbl_desc) -> eax=stbl next offset, rdx=error
; Finds the first video track by mdia/hdlr handler type, then returns its minf/stbl descriptor.
; rdi=buf, esi=len, rdx=moov_desc, rcx=out_stbl_desc
er_fn er_mp4_video_stbl_find
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc MP4_VIDEO_STBL_STACK_SIZE
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    cmp     dword [rdx + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_MOOV
    jne     .unsupported
    mov     r12, rdi
    mov     r13d, esi
    mov     r14, rdx
    mov     r15, rcx
    mov     ebx, [r14 + MP4_BOX_DESC_PAYLOAD_OFFSET]
    mov     eax, [r14 + MP4_BOX_DESC_PAYLOAD_LEN]
    cmp     ebx, r13d
    ja      .corrupt
    mov     ecx, r13d
    sub     ecx, ebx
    cmp     eax, ecx
    ja      .corrupt
    add     eax, ebx
    jc      .corrupt
    cmp     eax, r13d
    ja      .corrupt
    mov     [rsp + MP4_VIDEO_STBL_CURSOR], ebx
    mov     [rsp + MP4_VIDEO_STBL_END], eax
.trak_loop:
    mov     ebx, [rsp + MP4_VIDEO_STBL_CURSOR]
    cmp     ebx, [rsp + MP4_VIDEO_STBL_END]
    jae     .no_data
    mov     rdi, r12
    mov     esi, [rsp + MP4_VIDEO_STBL_END]
    mov     edx, ebx
    mov     ecx, MP4_BOX_TYPE_TRAK
    lea     r8, [rsp + MP4_VIDEO_STBL_TRAK_DESC]
    call    er_mp4_find_box
    test    edx, edx
    jnz     .done
    cmp     eax, ebx
    jbe     .corrupt
    mov     [rsp + MP4_VIDEO_STBL_CURSOR], eax
    mov     rdi, r12
    mov     esi, r13d
    lea     rdx, [rsp + MP4_VIDEO_STBL_TRAK_DESC]
    mov     ecx, MP4_BOX_TYPE_MDIA
    lea     r8, [rsp + MP4_VIDEO_STBL_MDIA_DESC]
    call    er_mp4_find_child_box
    test    edx, edx
    jnz     .done
    mov     rdi, r12
    mov     esi, r13d
    lea     rdx, [rsp + MP4_VIDEO_STBL_MDIA_DESC]
    mov     ecx, MP4_BOX_TYPE_HDLR
    lea     r8, [rsp + MP4_VIDEO_STBL_HDLR_DESC]
    call    er_mp4_find_child_box
    test    edx, edx
    jnz     .done
    mov     rdi, r12
    mov     esi, r13d
    lea     rdx, [rsp + MP4_VIDEO_STBL_HDLR_DESC]
    call    er_mp4_hdlr_is_video
    test    edx, edx
    jnz     .done
    test    eax, eax
    jz      .trak_loop
    mov     rdi, r12
    mov     esi, r13d
    lea     rdx, [rsp + MP4_VIDEO_STBL_MDIA_DESC]
    mov     ecx, MP4_BOX_TYPE_MINF
    lea     r8, [rsp + MP4_VIDEO_STBL_MINF_DESC]
    call    er_mp4_find_child_box
    test    edx, edx
    jnz     .done
    mov     rdi, r12
    mov     esi, r13d
    lea     rdx, [rsp + MP4_VIDEO_STBL_MINF_DESC]
    mov     ecx, MP4_BOX_TYPE_STBL
    mov     r8, r15
    call    er_mp4_find_child_box
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
    er_stack_free MP4_VIDEO_STBL_STACK_SIZE
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_mp4_video_sample_tables_find(buf, len, moov_desc, out_tables) -> eax=MP4_SAMPLE_TABLES_SIZE, rdx=error
; Finds the first video track's stbl and fills the sample-location table bundle.
; rdi=buf, esi=len, rdx=moov_desc, rcx=out_tables
er_fn er_mp4_video_sample_tables_find
    er_push rbx, r12, r13, r14
    er_stack_alloc MP4_BOX_DESC_SIZE
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     r14, rcx
    mov     rdi, r12
    mov     esi, r13d
    mov     rcx, rsp
    call    er_mp4_video_stbl_find
    test    edx, edx
    jnz     .done
    mov     rdi, r12
    mov     esi, r13d
    mov     rdx, rsp
    mov     rcx, r14
    call    er_mp4_sample_tables_find
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done:
    er_stack_free MP4_BOX_DESC_SIZE
    er_pop  rbx, r12, r13, r14
    er_ret

; er_mp4_file_video_sample_tables_find(buf, len, out_tables) -> eax=MP4_SAMPLE_TABLES_SIZE, rdx=error
; Finds top-level moov, then fills the first video track sample-location table bundle.
; rdi=buf, esi=len, rdx=out_tables
er_fn er_mp4_file_video_sample_tables_find
    er_push rbx, r12, r13
    er_stack_alloc MP4_BOX_DESC_SIZE
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     rbx, rdx
    xor     edx, edx
    mov     ecx, MP4_BOX_TYPE_MOOV
    mov     r8, rsp
    call    er_mp4_find_box
    test    edx, edx
    jnz     .done
    mov     rdi, r12
    mov     esi, r13d
    mov     rdx, rsp
    mov     rcx, rbx
    call    er_mp4_video_sample_tables_find
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done:
    er_stack_free MP4_BOX_DESC_SIZE
    er_pop  rbx, r12, r13
    er_ret

; er_mp4_file_video_sample_locate(buf, len, sample_index, out_desc) -> eax=payload_offset, rdx=error
; Finds the first video track's sample tables from the file, then locates sample_index.
; rdi=buf, esi=len, edx=sample_index, rcx=out_desc
er_fn er_mp4_file_video_sample_locate
    er_push rbx, r12, r13, r14
    er_stack_alloc MP4_SAMPLE_TABLES_SIZE
    test    rdi, rdi
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     ebx, edx
    mov     r14, rcx
    mov     rdx, rsp
    call    er_mp4_file_video_sample_tables_find
    test    edx, edx
    jnz     .done
    mov     rdi, r12
    mov     esi, r13d
    mov     rdx, rsp
    mov     ecx, ebx
    mov     r8, r14
    call    er_mp4_sample_locate
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done:
    er_stack_free MP4_SAMPLE_TABLES_SIZE
    er_pop  rbx, r12, r13, r14
    er_ret

; er_mp4_file_video_sample_payload(buf, len, sample_index, out_desc) -> eax=payload_offset, rdx=error
; Finds and validates the first video track sample payload inside top-level mdat.
; rdi=buf, esi=len, edx=sample_index, rcx=out_desc
er_fn er_mp4_file_video_sample_payload
    er_push rbx, r12, r13, r14
    er_stack_alloc MP4_FILE_SAMPLE_PAYLOAD_STACK_SIZE
    test    rdi, rdi
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     ebx, edx
    mov     r14, rcx
    xor     edx, edx
    mov     ecx, MP4_BOX_TYPE_MDAT
    lea     r8, [rsp + MP4_FILE_SAMPLE_PAYLOAD_MDAT_DESC]
    call    er_mp4_find_box
    test    edx, edx
    jnz     .done
    mov     rdi, r12
    mov     esi, r13d
    mov     edx, ebx
    lea     rcx, [rsp + MP4_FILE_SAMPLE_PAYLOAD_SAMPLE_DESC]
    call    er_mp4_file_video_sample_locate
    test    edx, edx
    jnz     .done
    mov     rdi, r12
    mov     esi, r13d
    lea     rdx, [rsp + MP4_FILE_SAMPLE_PAYLOAD_MDAT_DESC]
    lea     rcx, [rsp + MP4_FILE_SAMPLE_PAYLOAD_SAMPLE_DESC]
    mov     r8, r14
    call    er_mp4_sample_payload
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done:
    er_stack_free MP4_FILE_SAMPLE_PAYLOAD_STACK_SIZE
    er_pop  rbx, r12, r13, r14
    er_ret

; er_mp4_file_video_sample_obu_scan(buf, len, sample_index, out_stats) -> eax=unit count, rdx=error
; Validates a file video sample payload, then scans complete AV1 OBUs inside that payload.
; rdi=buf, esi=len, edx=sample_index, rcx=out_stats
er_fn er_mp4_file_video_sample_obu_scan
    er_push rbx, r12, r13, r14
    er_stack_alloc MP4_SAMPLE_DESC_SIZE
    test    rdi, rdi
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     ebx, edx
    mov     r14, rcx
    mov     edx, ebx
    mov     rcx, rsp
    call    er_mp4_file_video_sample_payload
    test    edx, edx
    jnz     .done
    mov     eax, [rsp + MP4_SAMPLE_DESC_PAYLOAD_OFFSET]
    lea     rdi, [r12 + rax]
    mov     esi, [rsp + MP4_SAMPLE_DESC_PAYLOAD_LEN]
    mov     rdx, r14
    call    er_av1_obu_scan_units
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done:
    er_stack_free MP4_SAMPLE_DESC_SIZE
    er_pop  rbx, r12, r13, r14
    er_ret

; er_mp4_file_video_sample_obu_route(buf, len, sample_index, out_route) -> eax=unit count, rdx=error
; Validates a file video sample payload, then routes first AV1 OBU payload offsets relative to that sample.
; rdi=buf, esi=len, edx=sample_index, rcx=out_route
er_fn er_mp4_file_video_sample_obu_route
    er_push rbx, r12, r13, r14
    er_stack_alloc MP4_SAMPLE_DESC_SIZE
    test    rdi, rdi
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     ebx, edx
    mov     r14, rcx
    mov     edx, ebx
    mov     rcx, rsp
    call    er_mp4_file_video_sample_payload
    test    edx, edx
    jnz     .done
    mov     eax, [rsp + MP4_SAMPLE_DESC_PAYLOAD_OFFSET]
    lea     rdi, [r12 + rax]
    mov     esi, [rsp + MP4_SAMPLE_DESC_PAYLOAD_LEN]
    mov     rdx, r14
    call    er_av1_obu_route_sample
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done:
    er_stack_free MP4_SAMPLE_DESC_SIZE
    er_pop  rbx, r12, r13, r14
    er_ret

; er_mp4_visual_sample_entry_decode(buf, len, entry_desc, out_desc) -> eax=width, rdx=error
; Decodes the fixed VisualSampleEntry header: data_reference_index, width, height.
; rdi=buf, esi=len, rdx=entry_desc, rcx=out_desc
er_fn er_mp4_visual_sample_entry_decode
    er_push rbx, r12
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    test    rcx, rcx
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
    lea     r8, [rdi + rbx + MP4_VISUAL_SAMPLE_ENTRY_DATA_REF]
    mp4_load_be16 r8, eax
    test    eax, eax
    jz      .corrupt
    mov     [rcx + MP4_VISUAL_SAMPLE_ENTRY_DESC_DATA_REF], eax
    lea     r8, [rdi + rbx + MP4_VISUAL_SAMPLE_ENTRY_WIDTH]
    mp4_load_be16 r8, eax
    test    eax, eax
    jz      .corrupt
    mov     [rcx + MP4_VISUAL_SAMPLE_ENTRY_DESC_WIDTH], eax
    lea     r8, [rdi + rbx + MP4_VISUAL_SAMPLE_ENTRY_HEIGHT]
    mp4_load_be16 r8, eax
    test    eax, eax
    jz      .corrupt
    mov     [rcx + MP4_VISUAL_SAMPLE_ENTRY_DESC_HEIGHT], eax
    mov     eax, [rcx + MP4_VISUAL_SAMPLE_ENTRY_DESC_WIDTH]
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

; er_mp4_mdhd_decode(buf, len, mdhd_desc, out_desc) -> eax=timescale, rdx=error
; Decodes MediaHeaderBox timescale and duration. Version-1 duration must fit u32.
; rdi=buf, esi=len, rdx=mdhd_desc, rcx=out_desc
er_fn er_mp4_mdhd_decode
    er_push rbx, r12
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    cmp     dword [rdx + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_MDHD
    jne     .unsupported
    mov     ebx, [rdx + MP4_BOX_DESC_PAYLOAD_OFFSET]
    mov     r12d, [rdx + MP4_BOX_DESC_PAYLOAD_LEN]
    cmp     ebx, esi
    ja      .corrupt
    mov     eax, esi
    sub     eax, ebx
    cmp     r12d, eax
    ja      .corrupt
    cmp     r12d, MP4_FULLBOX_HEADER_SIZE
    jb      .corrupt
    movzx   eax, byte [rdi + rbx + MP4_FULLBOX_VERSION]
    test    eax, eax
    jz      .v0
    cmp     eax, 1
    je      .v1
    jmp     .unsupported
.v0:
    cmp     r12d, MP4_MDHD_V0_MIN_PAYLOAD
    jb      .corrupt
    lea     r8, [rdi + rbx + MP4_MDHD_V0_TIMESCALE]
    mp4_load_be32 r8, eax
    test    eax, eax
    jz      .corrupt
    mov     [rcx + MP4_MDHD_DESC_TIMESCALE], eax
    lea     r8, [rdi + rbx + MP4_MDHD_V0_DURATION]
    mp4_load_be32 r8, eax
    mov     [rcx + MP4_MDHD_DESC_DURATION], eax
    mov     eax, [rcx + MP4_MDHD_DESC_TIMESCALE]
    er_ok
    jmp     .done
.v1:
    cmp     r12d, MP4_MDHD_V1_MIN_PAYLOAD
    jb      .corrupt
    lea     r8, [rdi + rbx + MP4_MDHD_V1_TIMESCALE]
    mp4_load_be32 r8, eax
    test    eax, eax
    jz      .corrupt
    mov     [rcx + MP4_MDHD_DESC_TIMESCALE], eax
    lea     r8, [rdi + rbx + MP4_MDHD_V1_DURATION_HI]
    mp4_load_be32 r8, eax
    test    eax, eax
    jnz     .unsupported
    lea     r8, [rdi + rbx + MP4_MDHD_V1_DURATION_LO]
    mp4_load_be32 r8, eax
    mov     [rcx + MP4_MDHD_DESC_DURATION], eax
    mov     eax, [rcx + MP4_MDHD_DESC_TIMESCALE]
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

; er_mp4_tkhd_decode(buf, len, tkhd_desc, out_desc) -> eax=width, rdx=error
; Decodes TrackHeaderBox duration and integer display width/height from 16.16 fixed values.
; rdi=buf, esi=len, rdx=tkhd_desc, rcx=out_desc
er_fn er_mp4_tkhd_decode
    er_push rbx, r12
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    cmp     dword [rdx + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_TKHD
    jne     .unsupported
    mov     ebx, [rdx + MP4_BOX_DESC_PAYLOAD_OFFSET]
    mov     r12d, [rdx + MP4_BOX_DESC_PAYLOAD_LEN]
    cmp     ebx, esi
    ja      .corrupt
    mov     eax, esi
    sub     eax, ebx
    cmp     r12d, eax
    ja      .corrupt
    cmp     r12d, MP4_FULLBOX_HEADER_SIZE
    jb      .corrupt
    movzx   eax, byte [rdi + rbx + MP4_FULLBOX_VERSION]
    test    eax, eax
    jz      .v0
    cmp     eax, 1
    je      .v1
    jmp     .unsupported
.v0:
    cmp     r12d, MP4_TKHD_V0_MIN_PAYLOAD
    jb      .corrupt
    lea     r8, [rdi + rbx + MP4_TKHD_V0_DURATION]
    mp4_load_be32 r8, eax
    mov     [rcx + MP4_TKHD_DESC_DURATION], eax
    lea     r8, [rdi + rbx + MP4_TKHD_V0_WIDTH]
    call    mp4_decode_fixed_16
    mov     [rcx + MP4_TKHD_DESC_WIDTH], eax
    lea     r8, [rdi + rbx + MP4_TKHD_V0_HEIGHT]
    call    mp4_decode_fixed_16
    mov     [rcx + MP4_TKHD_DESC_HEIGHT], eax
    mov     eax, [rcx + MP4_TKHD_DESC_WIDTH]
    er_ok
    jmp     .done
.v1:
    cmp     r12d, MP4_TKHD_V1_MIN_PAYLOAD
    jb      .corrupt
    lea     r8, [rdi + rbx + MP4_TKHD_V1_DURATION_HI]
    mp4_load_be32 r8, eax
    test    eax, eax
    jnz     .unsupported
    lea     r8, [rdi + rbx + MP4_TKHD_V1_DURATION_LO]
    mp4_load_be32 r8, eax
    mov     [rcx + MP4_TKHD_DESC_DURATION], eax
    lea     r8, [rdi + rbx + MP4_TKHD_V1_WIDTH]
    call    mp4_decode_fixed_16
    mov     [rcx + MP4_TKHD_DESC_WIDTH], eax
    lea     r8, [rdi + rbx + MP4_TKHD_V1_HEIGHT]
    call    mp4_decode_fixed_16
    mov     [rcx + MP4_TKHD_DESC_HEIGHT], eax
    mov     eax, [rcx + MP4_TKHD_DESC_WIDTH]
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

; er_mp4_hdlr_decode(buf, len, hdlr_desc, out_desc) -> eax=handler_type, rdx=error
; Decodes HandlerBox handler_type.
; rdi=buf, esi=len, rdx=hdlr_desc, rcx=out_desc
er_fn er_mp4_hdlr_decode
    er_push rbx, r12
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    cmp     dword [rdx + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_HDLR
    jne     .unsupported
    mov     ebx, [rdx + MP4_BOX_DESC_PAYLOAD_OFFSET]
    mov     r12d, [rdx + MP4_BOX_DESC_PAYLOAD_LEN]
    cmp     ebx, esi
    ja      .corrupt
    mov     eax, esi
    sub     eax, ebx
    cmp     r12d, eax
    ja      .corrupt
    cmp     r12d, MP4_HDLR_MIN_PAYLOAD
    jb      .corrupt
    movzx   eax, byte [rdi + rbx + MP4_FULLBOX_VERSION]
    test    eax, eax
    jnz     .unsupported
    mov     eax, [rdi + rbx + MP4_HDLR_HANDLER_TYPE]
    mov     [rcx + MP4_HDLR_DESC_HANDLER_TYPE], eax
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

; er_mp4_hdlr_is_video(buf, len, hdlr_desc) -> eax=1 if handler_type is vide, else 0.
; rdi=buf, esi=len, rdx=hdlr_desc
er_fn er_mp4_hdlr_is_video
    er_stack_alloc MP4_HDLR_DESC_SIZE
    mov     rcx, rsp
    call    er_mp4_hdlr_decode
    test    edx, edx
    jnz     .done
    cmp     eax, MP4_HANDLER_TYPE_VIDE
    sete    al
    movzx   eax, al
    er_ok
.done:
    er_stack_free MP4_HDLR_DESC_SIZE
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

; er_mp4_stts_entry(buf, len, stts_desc, entry_index, out_desc) -> eax=entry_count, rdx=error
; entry_index is zero-based. out_desc receives sample_count and sample_delta.
; rdi=buf, esi=len, rdx=stts_desc, ecx=entry_index, r8=out_desc
er_fn er_mp4_stts_entry
    er_push rbx, r12, r13, r14
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    test    r8, r8
    jz      .invalid_param
    cmp     dword [rdx + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_STTS
    jne     .unsupported
    mov     ebx, [rdx + MP4_BOX_DESC_PAYLOAD_OFFSET]
    mov     r12d, [rdx + MP4_BOX_DESC_PAYLOAD_LEN]
    cmp     ebx, esi
    ja      .corrupt
    mov     eax, esi
    sub     eax, ebx
    cmp     r12d, eax
    ja      .corrupt
    cmp     r12d, MP4_STTS_FIRST_ENTRY_OFFSET
    jb      .corrupt
    lea     r13, [rdi + rbx + MP4_STTS_ENTRY_COUNT_OFFSET]
    mp4_load_be32 r13, r14d
    cmp     ecx, r14d
    jae     .no_data
    mov     eax, ecx
    imul    eax, MP4_STTS_ENTRY_SIZE
    add     eax, MP4_STTS_FIRST_ENTRY_OFFSET
    jc      .corrupt
    add     eax, MP4_STTS_ENTRY_SIZE
    jc      .corrupt
    cmp     eax, r12d
    ja      .corrupt
    mov     eax, ecx
    imul    eax, MP4_STTS_ENTRY_SIZE
    lea     r13, [rdi + rbx + MP4_STTS_FIRST_ENTRY_OFFSET]
    add     r13, rax
    mp4_load_be32 r13 + MP4_STTS_ENTRY_SAMPLE_COUNT, eax
    mov     [r8 + MP4_STTS_DESC_SAMPLE_COUNT], eax
    mp4_load_be32 r13 + MP4_STTS_ENTRY_SAMPLE_DELTA, eax
    mov     [r8 + MP4_STTS_DESC_SAMPLE_DELTA], eax
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

; er_mp4_stts_sample_time(buf, len, stts_desc, sample_index, out_desc) -> eax=dts, rdx=error
; sample_index is zero-based. out_desc receives decode timestamp and duration in track ticks.
; rdi=buf, esi=len, rdx=stts_desc, ecx=sample_index, r8=out_desc
er_fn er_mp4_stts_sample_time
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc MP4_STTS_SAMPLE_TIME_STACK_SIZE
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    test    r8, r8
    jz      .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     r14, rdx
    mov     ebx, ecx
    mov     r15, r8
    mov     rdi, r12
    mov     esi, r13d
    mov     rdx, r14
    xor     ecx, ecx
    lea     r8, [rsp + MP4_STTS_SAMPLE_TIME_CUR_DESC]
    call    er_mp4_stts_entry
    test    edx, edx
    jnz     .done
    test    eax, eax
    jz      .corrupt
    mov     [rsp + MP4_STTS_SAMPLE_TIME_ENTRY_COUNT], eax
    mov     dword [rsp + MP4_STTS_SAMPLE_TIME_ENTRY_INDEX], 0
    mov     dword [rsp + MP4_STTS_SAMPLE_TIME_SAMPLE_CURSOR], 0
    mov     dword [rsp + MP4_STTS_SAMPLE_TIME_DTS], 0
.loop:
    mov     eax, [rsp + MP4_STTS_SAMPLE_TIME_CUR_DESC + MP4_STTS_DESC_SAMPLE_COUNT]
    test    eax, eax
    jz      .corrupt
    mov     edx, [rsp + MP4_STTS_SAMPLE_TIME_SAMPLE_CURSOR]
    add     edx, eax
    jc      .corrupt
    cmp     ebx, edx
    jb      .found
    mov     ecx, [rsp + MP4_STTS_SAMPLE_TIME_CUR_DESC + MP4_STTS_DESC_SAMPLE_DELTA]
    imul    eax, ecx
    jc      .corrupt
    add     [rsp + MP4_STTS_SAMPLE_TIME_DTS], eax
    jc      .corrupt
    mov     [rsp + MP4_STTS_SAMPLE_TIME_SAMPLE_CURSOR], edx
    mov     eax, [rsp + MP4_STTS_SAMPLE_TIME_ENTRY_INDEX]
    inc     eax
    cmp     eax, [rsp + MP4_STTS_SAMPLE_TIME_ENTRY_COUNT]
    jae     .no_data
    mov     [rsp + MP4_STTS_SAMPLE_TIME_ENTRY_INDEX], eax
    mov     rdi, r12
    mov     esi, r13d
    mov     rdx, r14
    mov     ecx, eax
    lea     r8, [rsp + MP4_STTS_SAMPLE_TIME_CUR_DESC]
    call    er_mp4_stts_entry
    test    edx, edx
    jnz     .done
    jmp     .loop
.found:
    mov     eax, ebx
    sub     eax, [rsp + MP4_STTS_SAMPLE_TIME_SAMPLE_CURSOR]
    mov     ecx, [rsp + MP4_STTS_SAMPLE_TIME_CUR_DESC + MP4_STTS_DESC_SAMPLE_DELTA]
    imul    eax, ecx
    jc      .corrupt
    add     eax, [rsp + MP4_STTS_SAMPLE_TIME_DTS]
    jc      .corrupt
    mov     [r15 + MP4_SAMPLE_TIME_DTS], eax
    mov     ecx, [rsp + MP4_STTS_SAMPLE_TIME_CUR_DESC + MP4_STTS_DESC_SAMPLE_DELTA]
    mov     [r15 + MP4_SAMPLE_TIME_DURATION], ecx
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
    er_stack_free MP4_STTS_SAMPLE_TIME_STACK_SIZE
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_mp4_ctts_entry(buf, len, ctts_desc, entry_index, out_desc) -> eax=entry_count, rdx=error
; entry_index is zero-based. out_desc receives sample_count and signed/unsigned sample_offset bits.
; rdi=buf, esi=len, rdx=ctts_desc, ecx=entry_index, r8=out_desc
er_fn er_mp4_ctts_entry
    er_push rbx, r12, r13, r14
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    test    r8, r8
    jz      .invalid_param
    cmp     dword [rdx + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_CTTS
    jne     .unsupported
    mov     ebx, [rdx + MP4_BOX_DESC_PAYLOAD_OFFSET]
    mov     r12d, [rdx + MP4_BOX_DESC_PAYLOAD_LEN]
    cmp     ebx, esi
    ja      .corrupt
    mov     eax, esi
    sub     eax, ebx
    cmp     r12d, eax
    ja      .corrupt
    cmp     r12d, MP4_CTTS_FIRST_ENTRY_OFFSET
    jb      .corrupt
    movzx   eax, byte [rdi + rbx + MP4_FULLBOX_VERSION]
    cmp     eax, 1
    ja      .unsupported
    lea     r13, [rdi + rbx + MP4_CTTS_ENTRY_COUNT_OFFSET]
    mp4_load_be32 r13, r14d
    cmp     ecx, r14d
    jae     .no_data
    mov     eax, ecx
    imul    eax, MP4_CTTS_ENTRY_SIZE
    add     eax, MP4_CTTS_FIRST_ENTRY_OFFSET
    jc      .corrupt
    add     eax, MP4_CTTS_ENTRY_SIZE
    jc      .corrupt
    cmp     eax, r12d
    ja      .corrupt
    mov     eax, ecx
    imul    eax, MP4_CTTS_ENTRY_SIZE
    lea     r13, [rdi + rbx + MP4_CTTS_FIRST_ENTRY_OFFSET]
    add     r13, rax
    mp4_load_be32 r13 + MP4_CTTS_ENTRY_SAMPLE_COUNT, eax
    mov     [r8 + MP4_CTTS_DESC_SAMPLE_COUNT], eax
    mp4_load_be32 r13 + MP4_CTTS_ENTRY_SAMPLE_OFFSET, eax
    mov     [r8 + MP4_CTTS_DESC_SAMPLE_OFFSET], eax
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

; er_mp4_ctts_sample_offset(buf, len, ctts_desc, sample_index, out_desc) -> eax=offset, rdx=error
; sample_index is zero-based. Version-1 offsets are returned as signed 32-bit values.
; rdi=buf, esi=len, rdx=ctts_desc, ecx=sample_index, r8=out_desc
er_fn er_mp4_ctts_sample_offset
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc MP4_CTTS_SAMPLE_OFFSET_STACK_SIZE
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    test    r8, r8
    jz      .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     r14, rdx
    mov     ebx, ecx
    mov     r15, r8
    mov     rdi, r12
    mov     esi, r13d
    mov     rdx, r14
    xor     ecx, ecx
    lea     r8, [rsp + MP4_CTTS_SAMPLE_OFFSET_CUR_DESC]
    call    er_mp4_ctts_entry
    test    edx, edx
    jnz     .done
    test    eax, eax
    jz      .corrupt
    mov     [rsp + MP4_CTTS_SAMPLE_OFFSET_ENTRY_COUNT], eax
    mov     dword [rsp + MP4_CTTS_SAMPLE_OFFSET_ENTRY_INDEX], 0
    mov     dword [rsp + MP4_CTTS_SAMPLE_OFFSET_SAMPLE_CURSOR], 0
.loop:
    mov     eax, [rsp + MP4_CTTS_SAMPLE_OFFSET_CUR_DESC + MP4_CTTS_DESC_SAMPLE_COUNT]
    test    eax, eax
    jz      .corrupt
    mov     edx, [rsp + MP4_CTTS_SAMPLE_OFFSET_SAMPLE_CURSOR]
    add     edx, eax
    jc      .corrupt
    cmp     ebx, edx
    jb      .found
    mov     [rsp + MP4_CTTS_SAMPLE_OFFSET_SAMPLE_CURSOR], edx
    mov     eax, [rsp + MP4_CTTS_SAMPLE_OFFSET_ENTRY_INDEX]
    inc     eax
    cmp     eax, [rsp + MP4_CTTS_SAMPLE_OFFSET_ENTRY_COUNT]
    jae     .no_data
    mov     [rsp + MP4_CTTS_SAMPLE_OFFSET_ENTRY_INDEX], eax
    mov     rdi, r12
    mov     esi, r13d
    mov     rdx, r14
    mov     ecx, eax
    lea     r8, [rsp + MP4_CTTS_SAMPLE_OFFSET_CUR_DESC]
    call    er_mp4_ctts_entry
    test    edx, edx
    jnz     .done
    jmp     .loop
.found:
    mov     eax, [rsp + MP4_CTTS_SAMPLE_OFFSET_CUR_DESC + MP4_CTTS_DESC_SAMPLE_COUNT]
    mov     [r15 + MP4_CTTS_DESC_SAMPLE_COUNT], eax
    mov     eax, [rsp + MP4_CTTS_SAMPLE_OFFSET_CUR_DESC + MP4_CTTS_DESC_SAMPLE_OFFSET]
    mov     [r15 + MP4_CTTS_DESC_SAMPLE_OFFSET], eax
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
    er_stack_free MP4_CTTS_SAMPLE_OFFSET_STACK_SIZE
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_mp4_stss_sync_count(buf, len, stss_desc) -> eax=count, rdx=error
; rdi=buf, esi=len, rdx=stss_desc
er_fn er_mp4_stss_sync_count
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    cmp     dword [rdx + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_STSS
    jne     .unsupported
    mov     r8d, [rdx + MP4_BOX_DESC_PAYLOAD_OFFSET]
    mov     r9d, [rdx + MP4_BOX_DESC_PAYLOAD_LEN]
    cmp     r8d, esi
    ja      .corrupt
    mov     eax, esi
    sub     eax, r8d
    cmp     r9d, eax
    ja      .corrupt
    cmp     r9d, MP4_STSS_FIRST_ENTRY_OFFSET
    jb      .corrupt
    lea     r8, [rdi + r8 + MP4_STSS_ENTRY_COUNT_OFFSET]
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

; er_mp4_stss_is_sync_sample(buf, len, stss_desc, sample_index) -> eax=1 if sync, else 0.
; sample_index is zero-based. stss entries are one-based sample numbers.
; rdi=buf, esi=len, rdx=stss_desc, ecx=sample_index
er_fn er_mp4_stss_is_sync_sample
    er_push rbx, r12, r13, r14, r15
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    cmp     dword [rdx + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_STSS
    jne     .unsupported
    mov     ebx, [rdx + MP4_BOX_DESC_PAYLOAD_OFFSET]
    mov     r12d, [rdx + MP4_BOX_DESC_PAYLOAD_LEN]
    cmp     ebx, esi
    ja      .corrupt
    mov     eax, esi
    sub     eax, ebx
    cmp     r12d, eax
    ja      .corrupt
    cmp     r12d, MP4_STSS_FIRST_ENTRY_OFFSET
    jb      .corrupt
    lea     r13, [rdi + rbx + MP4_STSS_ENTRY_COUNT_OFFSET]
    mp4_load_be32 r13, r14d
    mov     eax, r14d
    imul    eax, MP4_STSS_ENTRY_SIZE
    add     eax, MP4_STSS_FIRST_ENTRY_OFFSET
    jc      .corrupt
    cmp     eax, r12d
    ja      .corrupt
    cmp     ecx, 0xffffffff
    je      .corrupt
    lea     r15d, [ecx + 1]
    xor     ecx, ecx
    lea     r13, [rdi + rbx + MP4_STSS_FIRST_ENTRY_OFFSET]
.loop:
    cmp     ecx, r14d
    jae     .no
    mp4_load_be32 r13, eax
    test    eax, eax
    jz      .corrupt
    cmp     eax, r15d
    je      .yes
    ja      .no
    add     r13, MP4_STSS_ENTRY_SIZE
    inc     ecx
    jmp     .loop
.yes:
    mov     eax, 1
    er_ok
    jmp     .done
.no:
    xor     eax, eax
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
    er_pop  rbx, r12, r13, r14, r15
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
    lea     r13, [rdi + rbx + MP4_STSZ_FIRST_ENTRY_OFFSET]
    add     r13, rax
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
    lea     r13, [rdi + rbx + MP4_STCO_FIRST_ENTRY_OFFSET]
    add     r13, rax
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

; er_mp4_stco_chunk_count(buf, len, stco_desc) -> eax=count, rdx=error
; rdi=buf, esi=len, rdx=stco_desc
er_fn er_mp4_stco_chunk_count
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    cmp     dword [rdx + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_STCO
    jne     .unsupported
    mov     r8d, [rdx + MP4_BOX_DESC_PAYLOAD_OFFSET]
    mov     r9d, [rdx + MP4_BOX_DESC_PAYLOAD_LEN]
    cmp     r8d, esi
    ja      .corrupt
    mov     eax, esi
    sub     eax, r8d
    cmp     r9d, eax
    ja      .corrupt
    cmp     r9d, MP4_STCO_FIRST_ENTRY_OFFSET
    jb      .corrupt
    lea     r8, [rdi + r8 + MP4_STCO_ENTRY_COUNT_OFFSET]
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

; er_mp4_co64_chunk_offset(buf, len, co64_desc, chunk_index) -> eax=offset, rdx=error
; chunk_index is zero-based. The current sample-address path accepts only 32-bit offsets.
; rdi=buf, esi=len, rdx=co64_desc, ecx=chunk_index
er_fn er_mp4_co64_chunk_offset
    er_push rbx, r12, r13
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    cmp     dword [rdx + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_CO64
    jne     .unsupported
    mov     ebx, [rdx + MP4_BOX_DESC_PAYLOAD_OFFSET]
    mov     r12d, [rdx + MP4_BOX_DESC_PAYLOAD_LEN]
    cmp     ebx, esi
    ja      .corrupt
    mov     eax, esi
    sub     eax, ebx
    cmp     r12d, eax
    ja      .corrupt
    cmp     r12d, MP4_CO64_FIRST_ENTRY_OFFSET
    jb      .corrupt
    lea     r13, [rdi + rbx + MP4_CO64_ENTRY_COUNT_OFFSET]
    mp4_load_be32 r13, eax
    cmp     ecx, eax
    jae     .no_data
    mov     eax, ecx
    imul    eax, MP4_CO64_ENTRY_SIZE
    add     eax, MP4_CO64_FIRST_ENTRY_OFFSET
    jc      .corrupt
    add     eax, MP4_CO64_ENTRY_SIZE
    jc      .corrupt
    cmp     eax, r12d
    ja      .corrupt
    mov     eax, ecx
    imul    eax, MP4_CO64_ENTRY_SIZE
    lea     r13, [rdi + rbx + MP4_CO64_FIRST_ENTRY_OFFSET]
    add     r13, rax
    mp4_load_be32 r13, eax
    test    eax, eax
    jnz     .unsupported
    mp4_load_be32 r13 + 4, eax
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

; er_mp4_co64_chunk_count(buf, len, co64_desc) -> eax=count, rdx=error
; rdi=buf, esi=len, rdx=co64_desc
er_fn er_mp4_co64_chunk_count
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    cmp     dword [rdx + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_CO64
    jne     .unsupported
    mov     r8d, [rdx + MP4_BOX_DESC_PAYLOAD_OFFSET]
    mov     r9d, [rdx + MP4_BOX_DESC_PAYLOAD_LEN]
    cmp     r8d, esi
    ja      .corrupt
    mov     eax, esi
    sub     eax, r8d
    cmp     r9d, eax
    ja      .corrupt
    cmp     r9d, MP4_CO64_FIRST_ENTRY_OFFSET
    jb      .corrupt
    lea     r8, [rdi + r8 + MP4_CO64_ENTRY_COUNT_OFFSET]
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
    lea     r13, [rdi + rbx + MP4_STSC_FIRST_ENTRY_OFFSET]
    add     r13, rax
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

; er_mp4_sample_locate(buf, len, tables_desc, sample_index, out_desc) -> eax=payload_offset, rdx=error
; tables_desc contains stsz, stco-or-co64, and stsc box descriptors. sample_index is zero-based.
; rdi=buf, esi=len, rdx=tables_desc, ecx=sample_index, r8=out_desc
er_fn er_mp4_sample_locate
    er_push rbx, r12, r13, r14, r15
    er_stack_alloc MP4_SAMPLE_LOC_STACK_SIZE
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    test    r8, r8
    jz      .invalid_param
    mov     r12, rdi
    mov     r13d, esi
    mov     r14, rdx
    mov     ebx, ecx
    mov     r15, r8
    mov     rdi, r12
    mov     esi, r13d
    lea     rdx, [r14 + MP4_SAMPLE_TABLES_STSZ_DESC]
    call    er_mp4_stsz_sample_count
    test    edx, edx
    jnz     .done
    cmp     ebx, eax
    jae     .no_data
    mov     rdi, r12
    mov     esi, r13d
    lea     rdx, [r14 + MP4_SAMPLE_TABLES_STCO_DESC]
    cmp     dword [rdx + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_STCO
    je      .chunk_count_stco
    cmp     dword [rdx + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_CO64
    je      .chunk_count_co64
    jmp     .unsupported
.chunk_count_stco:
    call    er_mp4_stco_chunk_count
    jmp     .chunk_count_done
.chunk_count_co64:
    call    er_mp4_co64_chunk_count
.chunk_count_done:
    test    edx, edx
    jnz     .done
    test    eax, eax
    jz      .corrupt
    mov     [rsp + MP4_SAMPLE_LOC_CHUNK_COUNT], eax
    mov     rdi, r12
    mov     esi, r13d
    lea     rdx, [r14 + MP4_SAMPLE_TABLES_STSC_DESC]
    xor     ecx, ecx
    lea     r8, [rsp + MP4_SAMPLE_LOC_CUR_STSC]
    call    er_mp4_stsc_entry
    test    edx, edx
    jnz     .done
    test    eax, eax
    jz      .corrupt
    mov     [rsp + MP4_SAMPLE_LOC_ENTRY_COUNT], eax
    mov     dword [rsp + MP4_SAMPLE_LOC_ENTRY_INDEX], 0
    mov     dword [rsp + MP4_SAMPLE_LOC_SAMPLE_CURSOR], 0
.entry_loop:
    mov     eax, [rsp + MP4_SAMPLE_LOC_CUR_STSC + MP4_STSC_DESC_FIRST_CHUNK]
    test    eax, eax
    jz      .corrupt
    mov     ecx, [rsp + MP4_SAMPLE_LOC_CUR_STSC + MP4_STSC_DESC_SAMPLES_PER_CHUNK]
    test    ecx, ecx
    jz      .corrupt
    mov     edx, [rsp + MP4_SAMPLE_LOC_ENTRY_INDEX]
    inc     edx
    cmp     edx, [rsp + MP4_SAMPLE_LOC_ENTRY_COUNT]
    jae     .last_entry
    mov     rdi, r12
    mov     esi, r13d
    lea     rdx, [r14 + MP4_SAMPLE_TABLES_STSC_DESC]
    mov     ecx, [rsp + MP4_SAMPLE_LOC_ENTRY_INDEX]
    inc     ecx
    lea     r8, [rsp + MP4_SAMPLE_LOC_NEXT_STSC]
    call    er_mp4_stsc_entry
    test    edx, edx
    jnz     .done
    mov     eax, [rsp + MP4_SAMPLE_LOC_NEXT_STSC + MP4_STSC_DESC_FIRST_CHUNK]
    cmp     eax, [rsp + MP4_SAMPLE_LOC_CUR_STSC + MP4_STSC_DESC_FIRST_CHUNK]
    jbe     .corrupt
    mov     [rsp + MP4_SAMPLE_LOC_NEXT_FIRST_CHUNK], eax
    jmp     .chunk_loop_start
.last_entry:
    mov     eax, [rsp + MP4_SAMPLE_LOC_CHUNK_COUNT]
    inc     eax
    mov     [rsp + MP4_SAMPLE_LOC_NEXT_FIRST_CHUNK], eax
.chunk_loop_start:
    mov     eax, [rsp + MP4_SAMPLE_LOC_CUR_STSC + MP4_STSC_DESC_FIRST_CHUNK]
    cmp     eax, [rsp + MP4_SAMPLE_LOC_CHUNK_COUNT]
    ja      .corrupt
    mov     [rsp + MP4_SAMPLE_LOC_CHUNK_INDEX], eax
.chunk_loop:
    mov     eax, [rsp + MP4_SAMPLE_LOC_CHUNK_INDEX]
    cmp     eax, [rsp + MP4_SAMPLE_LOC_NEXT_FIRST_CHUNK]
    jae     .advance_entry
    cmp     eax, [rsp + MP4_SAMPLE_LOC_CHUNK_COUNT]
    ja      .corrupt
    mov     eax, [rsp + MP4_SAMPLE_LOC_SAMPLE_CURSOR]
    add     eax, [rsp + MP4_SAMPLE_LOC_CUR_STSC + MP4_STSC_DESC_SAMPLES_PER_CHUNK]
    jc      .corrupt
    cmp     ebx, eax
    jb      .found_chunk
    mov     [rsp + MP4_SAMPLE_LOC_SAMPLE_CURSOR], eax
    inc     dword [rsp + MP4_SAMPLE_LOC_CHUNK_INDEX]
    jmp     .chunk_loop
.advance_entry:
    mov     eax, [rsp + MP4_SAMPLE_LOC_ENTRY_INDEX]
    inc     eax
    cmp     eax, [rsp + MP4_SAMPLE_LOC_ENTRY_COUNT]
    jae     .no_data
    mov     [rsp + MP4_SAMPLE_LOC_ENTRY_INDEX], eax
    mov     eax, [rsp + MP4_SAMPLE_LOC_NEXT_STSC + MP4_STSC_DESC_FIRST_CHUNK]
    mov     [rsp + MP4_SAMPLE_LOC_CUR_STSC + MP4_STSC_DESC_FIRST_CHUNK], eax
    mov     eax, [rsp + MP4_SAMPLE_LOC_NEXT_STSC + MP4_STSC_DESC_SAMPLES_PER_CHUNK]
    mov     [rsp + MP4_SAMPLE_LOC_CUR_STSC + MP4_STSC_DESC_SAMPLES_PER_CHUNK], eax
    mov     eax, [rsp + MP4_SAMPLE_LOC_NEXT_STSC + MP4_STSC_DESC_SAMPLE_DESC_INDEX]
    mov     [rsp + MP4_SAMPLE_LOC_CUR_STSC + MP4_STSC_DESC_SAMPLE_DESC_INDEX], eax
    jmp     .entry_loop
.found_chunk:
    mov     eax, [rsp + MP4_SAMPLE_LOC_CHUNK_INDEX]
    dec     eax
    mov     ecx, eax
    mov     rdi, r12
    mov     esi, r13d
    lea     rdx, [r14 + MP4_SAMPLE_TABLES_STCO_DESC]
    cmp     dword [rdx + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_STCO
    je      .chunk_offset_stco
    cmp     dword [rdx + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_CO64
    je      .chunk_offset_co64
    jmp     .unsupported
.chunk_offset_stco:
    call    er_mp4_stco_chunk_offset
    jmp     .chunk_offset_done
.chunk_offset_co64:
    call    er_mp4_co64_chunk_offset
.chunk_offset_done:
    test    edx, edx
    jnz     .done
    mov     [rsp + MP4_SAMPLE_LOC_OFFSET_IN_CHUNK], eax
    mov     ecx, [rsp + MP4_SAMPLE_LOC_SAMPLE_CURSOR]
.sum_loop:
    cmp     ecx, ebx
    jae     .current_size
    mov     rdi, r12
    mov     esi, r13d
    lea     rdx, [r14 + MP4_SAMPLE_TABLES_STSZ_DESC]
    call    er_mp4_stsz_sample_size
    test    edx, edx
    jnz     .done
    add     [rsp + MP4_SAMPLE_LOC_OFFSET_IN_CHUNK], eax
    jc      .corrupt
    inc     ecx
    jmp     .sum_loop
.current_size:
    mov     rdi, r12
    mov     esi, r13d
    lea     rdx, [r14 + MP4_SAMPLE_TABLES_STSZ_DESC]
    mov     ecx, ebx
    call    er_mp4_stsz_sample_size
    test    edx, edx
    jnz     .done
    mov     [r15 + MP4_SAMPLE_DESC_PAYLOAD_LEN], eax
    mov     eax, [rsp + MP4_SAMPLE_LOC_OFFSET_IN_CHUNK]
    mov     [r15 + MP4_SAMPLE_DESC_PAYLOAD_OFFSET], eax
    mov     ecx, [rsp + MP4_SAMPLE_LOC_CHUNK_INDEX]
    dec     ecx
    mov     [r15 + MP4_SAMPLE_DESC_CHUNK_INDEX], ecx
    mov     ecx, ebx
    sub     ecx, [rsp + MP4_SAMPLE_LOC_SAMPLE_CURSOR]
    mov     [r15 + MP4_SAMPLE_DESC_INDEX_IN_CHUNK], ecx
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
    er_stack_free MP4_SAMPLE_LOC_STACK_SIZE
    er_pop  rbx, r12, r13, r14, r15
    er_ret

; er_mp4_sample_payload(buf, len, mdat_desc, sample_desc, out_desc) -> eax=payload_offset, rdx=error
; Validates that an already located sample lies inside both the file buffer and mdat payload.
; rdi=buf, esi=len, rdx=mdat_desc, rcx=sample_desc, r8=out_desc
er_fn er_mp4_sample_payload
    test    rdi, rdi
    jz      .invalid_param
    test    rdx, rdx
    jz      .invalid_param
    test    rcx, rcx
    jz      .invalid_param
    test    r8, r8
    jz      .invalid_param
    cmp     dword [rdx + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_MDAT
    jne     .unsupported
    mov     eax, [rdx + MP4_BOX_DESC_PAYLOAD_OFFSET]
    cmp     eax, esi
    ja      .corrupt
    mov     r9d, esi
    sub     r9d, eax
    mov     r10d, [rdx + MP4_BOX_DESC_PAYLOAD_LEN]
    cmp     r10d, r9d
    ja      .corrupt
    add     r10d, eax
    jc      .corrupt
    mov     r9d, [rcx + MP4_SAMPLE_DESC_PAYLOAD_OFFSET]
    cmp     r9d, eax
    jb      .corrupt
    mov     eax, [rcx + MP4_SAMPLE_DESC_PAYLOAD_LEN]
    mov     r11d, r9d
    add     r11d, eax
    jc      .corrupt
    cmp     r11d, r10d
    ja      .no_data
    cmp     r11d, esi
    ja      .no_data
    mov     [r8 + MP4_SAMPLE_DESC_PAYLOAD_OFFSET], r9d
    mov     [r8 + MP4_SAMPLE_DESC_PAYLOAD_LEN], eax
    mov     eax, [rcx + MP4_SAMPLE_DESC_CHUNK_INDEX]
    mov     [r8 + MP4_SAMPLE_DESC_CHUNK_INDEX], eax
    mov     eax, [rcx + MP4_SAMPLE_DESC_INDEX_IN_CHUNK]
    mov     [r8 + MP4_SAMPLE_DESC_INDEX_IN_CHUNK], eax
    mov     eax, r9d
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
.no_data:
    xor     eax, eax
    er_err  ERROR_NO_DATA
    er_ret
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
    er_ret

mp4_decode_fixed_16:
    mp4_load_be32 r8, eax
    shr     eax, MP4_TKHD_FIXED_16_SHIFT
    ret

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
