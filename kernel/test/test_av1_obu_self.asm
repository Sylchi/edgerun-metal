; EdgeRun AV1 OBU self-hosted test runner — x86_64 assembly.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/av1_constants.inc"
%include "test/test_macros.inc"

extern er_av1_obu_type_valid
extern er_av1_leb128_decode
extern er_av1_leb128_encode
extern er_av1_obu_decode_header
extern er_av1_obu_encode_header
extern er_av1_obu_decode_unit
extern er_av1_obu_encode_prefix
extern er_av1_obu_encode_temporal_delimiter

SECTION .bss
passed: resq 1
failed: resq 1
desc:   resb AV1_OBU_DESC_SIZE
value:  resq 1
outbuf: resb 16

SECTION .data
seq_header:     db 0x0a
frame_ext:      db 0x36, 0x68
bad_forbidden:  db 0x8a
bad_reserved:   db 0x0b
bad_ext_resv:   db 0x36, 0x6f
bad_type_zero:  db 0x02
bad_type_nine:  db 0x4a
leb_zero:       db 0x00
leb_127:        db 0x7f
leb_128:        db 0x80, 0x01
leb_u32_max:    db 0xff, 0xff, 0xff, 0xff, 0x0f
leb_trunc:      db 0x80
leb_too_long:   db 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80
leb_over_u32:   db 0x80, 0x80, 0x80, 0x80, 0x10
obu_sized:      db 0x0a, 0x03, 0xaa, 0xbb, 0xcc
obu_unsized:    db 0x08, 0xaa, 0xbb
obu_ext_sized:  db 0x36, 0x68, 0x02, 0xaa, 0xbb
obu_trunc_size: db 0x0a, 0x80
obu_trunc_body: db 0x0a, 0x03, 0xaa

SECTION .text
global _start
_start:
    mov     edi, AV1_OBU_TYPE_SEQUENCE_HEADER
    call    er_av1_obu_type_valid
    cmp     eax, 1
    jne     .fail_type_valid
    test    edx, edx
    jnz     .fail_type_valid
    inc     qword [rel passed]
    jmp     .type_invalid
.fail_type_valid:
    inc     qword [rel failed]

.type_invalid:
    mov     edi, 9
    call    er_av1_obu_type_valid
    test    eax, eax
    jnz     .fail_type_invalid
    test    edx, edx
    jnz     .fail_type_invalid
    inc     qword [rel passed]
    jmp     .decode_base
.fail_type_invalid:
    inc     qword [rel failed]

.decode_base:
    mov     rdi, seq_header
    mov     esi, 1
    mov     rdx, desc
    call    er_av1_obu_decode_header
    cmp     eax, AV1_OBU_HEADER_BASE_LEN
    jne     .fail_decode_base
    test    edx, edx
    jnz     .fail_decode_base
    cmp     byte [rel desc + AV1_OBU_DESC_TYPE], AV1_OBU_TYPE_SEQUENCE_HEADER
    jne     .fail_decode_base
    cmp     byte [rel desc + AV1_OBU_DESC_HAS_SIZE], 1
    jne     .fail_decode_base
    cmp     byte [rel desc + AV1_OBU_DESC_EXTENSION], 0
    jne     .fail_decode_base
    inc     qword [rel passed]
    jmp     .decode_ext
.fail_decode_base:
    inc     qword [rel failed]

.decode_ext:
    mov     rdi, frame_ext
    mov     esi, 2
    mov     rdx, desc
    call    er_av1_obu_decode_header
    cmp     eax, AV1_OBU_HEADER_EXT_LEN
    jne     .fail_decode_ext
    test    edx, edx
    jnz     .fail_decode_ext
    cmp     byte [rel desc + AV1_OBU_DESC_TYPE], AV1_OBU_TYPE_FRAME
    jne     .fail_decode_ext
    cmp     byte [rel desc + AV1_OBU_DESC_HAS_SIZE], 1
    jne     .fail_decode_ext
    cmp     byte [rel desc + AV1_OBU_DESC_EXTENSION], 1
    jne     .fail_decode_ext
    cmp     byte [rel desc + AV1_OBU_DESC_TEMPORAL_ID], 3
    jne     .fail_decode_ext
    cmp     byte [rel desc + AV1_OBU_DESC_SPATIAL_ID], 1
    jne     .fail_decode_ext
    inc     qword [rel passed]
    jmp     .decode_no_data
.fail_decode_ext:
    inc     qword [rel failed]

.decode_no_data:
    mov     rdi, frame_ext
    mov     esi, 1
    mov     rdx, desc
    call    er_av1_obu_decode_header
    test    eax, eax
    jnz     .fail_no_data
    cmp     edx, ERROR_NO_DATA
    jne     .fail_no_data
    inc     qword [rel passed]
    jmp     .decode_corrupt
.fail_no_data:
    inc     qword [rel failed]

.decode_corrupt:
    mov     rdi, bad_forbidden
    mov     esi, 1
    mov     edx, ERROR_CORRUPT
    call    expect_header_error
    mov     rdi, bad_reserved
    mov     esi, 1
    mov     edx, ERROR_CORRUPT
    call    expect_header_error
    mov     rdi, bad_ext_resv
    mov     esi, 2
    mov     edx, ERROR_CORRUPT
    call    expect_header_error

.decode_unsupported:
    mov     rdi, bad_type_zero
    mov     esi, 1
    mov     edx, ERROR_UNSUPPORTED
    call    expect_header_error
    mov     rdi, bad_type_nine
    mov     esi, 1
    mov     edx, ERROR_UNSUPPORTED
    call    expect_header_error

.encode_base:
    mov     rdi, outbuf
    mov     esi, AV1_OBU_HEADER_EXT_LEN
    mov     edx, AV1_OBU_TYPE_SEQUENCE_HEADER
    mov     ecx, 1
    xor     r8d, r8d
    xor     r9d, r9d
    call    er_av1_obu_encode_header
    cmp     eax, AV1_OBU_HEADER_BASE_LEN
    jne     .fail_encode_base
    test    edx, edx
    jnz     .fail_encode_base
    cmp     byte [rel outbuf], 0x0a
    jne     .fail_encode_base
    inc     qword [rel passed]
    jmp     .encode_ext
.fail_encode_base:
    inc     qword [rel failed]

.encode_ext:
    mov     rdi, outbuf
    mov     esi, AV1_OBU_HEADER_EXT_LEN
    mov     edx, AV1_OBU_TYPE_FRAME
    mov     ecx, 1
    mov     r8d, 3
    mov     r9d, 1
    call    er_av1_obu_encode_header
    cmp     eax, AV1_OBU_HEADER_EXT_LEN
    jne     .fail_encode_ext
    test    edx, edx
    jnz     .fail_encode_ext
    cmp     byte [rel outbuf], 0x36
    jne     .fail_encode_ext
    cmp     byte [rel outbuf + 1], 0x68
    jne     .fail_encode_ext
    inc     qword [rel passed]
    jmp     .encode_no_space
.fail_encode_ext:
    inc     qword [rel failed]

.encode_no_space:
    mov     rdi, outbuf
    mov     esi, 1
    mov     edx, AV1_OBU_TYPE_FRAME
    mov     ecx, 1
    mov     r8d, 1
    mov     r9d, 0
    call    er_av1_obu_encode_header
    test    eax, eax
    jnz     .fail_encode_no_space
    cmp     edx, ERROR_NO_SPACE
    jne     .fail_encode_no_space
    inc     qword [rel passed]
    jmp     .encode_invalid_id
.fail_encode_no_space:
    inc     qword [rel failed]

.encode_invalid_id:
    mov     rdi, outbuf
    mov     esi, AV1_OBU_HEADER_EXT_LEN
    mov     edx, AV1_OBU_TYPE_FRAME
    mov     ecx, 1
    mov     r8d, 8
    xor     r9d, r9d
    call    er_av1_obu_encode_header
    test    eax, eax
    jnz     .fail_encode_invalid_id
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_encode_invalid_id
    inc     qword [rel passed]
    jmp     .leb_decode_zero
.fail_encode_invalid_id:
    inc     qword [rel failed]

.leb_decode_zero:
    mov     rdi, leb_zero
    mov     esi, 1
    mov     rdx, value
    call    er_av1_leb128_decode
    cmp     eax, 1
    jne     .fail_leb_decode_zero
    test    edx, edx
    jnz     .fail_leb_decode_zero
    cmp     qword [rel value], 0
    jne     .fail_leb_decode_zero
    inc     qword [rel passed]
    jmp     .leb_decode_127
.fail_leb_decode_zero:
    inc     qword [rel failed]

.leb_decode_127:
    mov     rdi, leb_127
    mov     esi, 1
    mov     rdx, value
    call    er_av1_leb128_decode
    cmp     eax, 1
    jne     .fail_leb_decode_127
    test    edx, edx
    jnz     .fail_leb_decode_127
    cmp     qword [rel value], 127
    jne     .fail_leb_decode_127
    inc     qword [rel passed]
    jmp     .leb_decode_128
.fail_leb_decode_127:
    inc     qword [rel failed]

.leb_decode_128:
    mov     rdi, leb_128
    mov     esi, 2
    mov     rdx, value
    call    er_av1_leb128_decode
    cmp     eax, 2
    jne     .fail_leb_decode_128
    test    edx, edx
    jnz     .fail_leb_decode_128
    cmp     qword [rel value], 128
    jne     .fail_leb_decode_128
    inc     qword [rel passed]
    jmp     .leb_decode_u32_max
.fail_leb_decode_128:
    inc     qword [rel failed]

.leb_decode_u32_max:
    mov     rdi, leb_u32_max
    mov     esi, 5
    mov     rdx, value
    call    er_av1_leb128_decode
    cmp     eax, 5
    jne     .fail_leb_decode_u32_max
    test    edx, edx
    jnz     .fail_leb_decode_u32_max
    mov     rax, AV1_LEB128_U32_MAX
    cmp     [rel value], rax
    jne     .fail_leb_decode_u32_max
    inc     qword [rel passed]
    jmp     .leb_decode_trunc
.fail_leb_decode_u32_max:
    inc     qword [rel failed]

.leb_decode_trunc:
    mov     rdi, leb_trunc
    mov     esi, 1
    mov     rdx, value
    call    er_av1_leb128_decode
    test    eax, eax
    jnz     .fail_leb_decode_trunc
    cmp     edx, ERROR_NO_DATA
    jne     .fail_leb_decode_trunc
    inc     qword [rel passed]
    jmp     .leb_decode_too_long
.fail_leb_decode_trunc:
    inc     qword [rel failed]

.leb_decode_too_long:
    mov     rdi, leb_too_long
    mov     esi, AV1_LEB128_MAX_BYTES
    mov     rdx, value
    call    er_av1_leb128_decode
    test    eax, eax
    jnz     .fail_leb_decode_too_long
    cmp     edx, ERROR_CORRUPT
    jne     .fail_leb_decode_too_long
    inc     qword [rel passed]
    jmp     .leb_decode_over_u32
.fail_leb_decode_too_long:
    inc     qword [rel failed]

.leb_decode_over_u32:
    mov     rdi, leb_over_u32
    mov     esi, 5
    mov     rdx, value
    call    er_av1_leb128_decode
    test    eax, eax
    jnz     .fail_leb_decode_over_u32
    cmp     edx, ERROR_CORRUPT
    jne     .fail_leb_decode_over_u32
    inc     qword [rel passed]
    jmp     .leb_encode_624485
.fail_leb_decode_over_u32:
    inc     qword [rel failed]

.leb_encode_624485:
    mov     rdi, outbuf
    mov     esi, AV1_LEB128_MAX_BYTES
    mov     edx, 624485
    call    er_av1_leb128_encode
    cmp     eax, 3
    jne     .fail_leb_encode_624485
    test    edx, edx
    jnz     .fail_leb_encode_624485
    cmp     byte [rel outbuf], 0xe5
    jne     .fail_leb_encode_624485
    cmp     byte [rel outbuf + 1], 0x8e
    jne     .fail_leb_encode_624485
    cmp     byte [rel outbuf + 2], 0x26
    jne     .fail_leb_encode_624485
    inc     qword [rel passed]
    jmp     .leb_encode_u32_max
.fail_leb_encode_624485:
    inc     qword [rel failed]

.leb_encode_u32_max:
    mov     rdi, outbuf
    mov     esi, AV1_LEB128_MAX_BYTES
    mov     edx, AV1_LEB128_U32_MAX
    call    er_av1_leb128_encode
    cmp     eax, 5
    jne     .fail_leb_encode_u32_max
    test    edx, edx
    jnz     .fail_leb_encode_u32_max
    cmp     byte [rel outbuf], 0xff
    jne     .fail_leb_encode_u32_max
    cmp     byte [rel outbuf + 1], 0xff
    jne     .fail_leb_encode_u32_max
    cmp     byte [rel outbuf + 2], 0xff
    jne     .fail_leb_encode_u32_max
    cmp     byte [rel outbuf + 3], 0xff
    jne     .fail_leb_encode_u32_max
    cmp     byte [rel outbuf + 4], 0x0f
    jne     .fail_leb_encode_u32_max
    inc     qword [rel passed]
    jmp     .leb_encode_no_space
.fail_leb_encode_u32_max:
    inc     qword [rel failed]

.leb_encode_no_space:
    mov     rdi, outbuf
    mov     esi, 0
    mov     edx, 1
    call    er_av1_leb128_encode
    test    eax, eax
    jnz     .fail_leb_encode_no_space
    cmp     edx, ERROR_NO_SPACE
    jne     .fail_leb_encode_no_space
    inc     qword [rel passed]
    jmp     .obu_decode_sized
.fail_leb_encode_no_space:
    inc     qword [rel failed]

.obu_decode_sized:
    mov     rdi, obu_sized
    mov     esi, 5
    mov     rdx, desc
    call    er_av1_obu_decode_unit
    cmp     eax, 5
    jne     .fail_obu_decode_sized
    test    edx, edx
    jnz     .fail_obu_decode_sized
    cmp     byte [rel desc + AV1_OBU_DESC_TYPE], AV1_OBU_TYPE_SEQUENCE_HEADER
    jne     .fail_obu_decode_sized
    cmp     byte [rel desc + AV1_OBU_DESC_HEADER_LEN], 1
    jne     .fail_obu_decode_sized
    cmp     byte [rel desc + AV1_OBU_DESC_SIZE_FIELD_LEN], 1
    jne     .fail_obu_decode_sized
    cmp     dword [rel desc + AV1_OBU_DESC_PAYLOAD_OFFSET], 2
    jne     .fail_obu_decode_sized
    cmp     dword [rel desc + AV1_OBU_DESC_PAYLOAD_LEN], 3
    jne     .fail_obu_decode_sized
    cmp     dword [rel desc + AV1_OBU_DESC_TOTAL_LEN], 5
    jne     .fail_obu_decode_sized
    inc     qword [rel passed]
    jmp     .obu_decode_unsized
.fail_obu_decode_sized:
    inc     qword [rel failed]

.obu_decode_unsized:
    mov     rdi, obu_unsized
    mov     esi, 3
    mov     rdx, desc
    call    er_av1_obu_decode_unit
    cmp     eax, 3
    jne     .fail_obu_decode_unsized
    test    edx, edx
    jnz     .fail_obu_decode_unsized
    cmp     byte [rel desc + AV1_OBU_DESC_HAS_SIZE], 0
    jne     .fail_obu_decode_unsized
    cmp     dword [rel desc + AV1_OBU_DESC_PAYLOAD_OFFSET], 1
    jne     .fail_obu_decode_unsized
    cmp     dword [rel desc + AV1_OBU_DESC_PAYLOAD_LEN], 2
    jne     .fail_obu_decode_unsized
    inc     qword [rel passed]
    jmp     .obu_decode_ext_sized
.fail_obu_decode_unsized:
    inc     qword [rel failed]

.obu_decode_ext_sized:
    mov     rdi, obu_ext_sized
    mov     esi, 5
    mov     rdx, desc
    call    er_av1_obu_decode_unit
    cmp     eax, 5
    jne     .fail_obu_decode_ext_sized
    test    edx, edx
    jnz     .fail_obu_decode_ext_sized
    cmp     byte [rel desc + AV1_OBU_DESC_TYPE], AV1_OBU_TYPE_FRAME
    jne     .fail_obu_decode_ext_sized
    cmp     byte [rel desc + AV1_OBU_DESC_HEADER_LEN], 2
    jne     .fail_obu_decode_ext_sized
    cmp     byte [rel desc + AV1_OBU_DESC_SIZE_FIELD_LEN], 1
    jne     .fail_obu_decode_ext_sized
    cmp     dword [rel desc + AV1_OBU_DESC_PAYLOAD_OFFSET], 3
    jne     .fail_obu_decode_ext_sized
    cmp     dword [rel desc + AV1_OBU_DESC_PAYLOAD_LEN], 2
    jne     .fail_obu_decode_ext_sized
    inc     qword [rel passed]
    jmp     .obu_decode_trunc_size
.fail_obu_decode_ext_sized:
    inc     qword [rel failed]

.obu_decode_trunc_size:
    mov     rdi, obu_trunc_size
    mov     esi, 2
    mov     rdx, desc
    call    er_av1_obu_decode_unit
    test    eax, eax
    jnz     .fail_obu_decode_trunc_size
    cmp     edx, ERROR_NO_DATA
    jne     .fail_obu_decode_trunc_size
    inc     qword [rel passed]
    jmp     .obu_decode_trunc_body
.fail_obu_decode_trunc_size:
    inc     qword [rel failed]

.obu_decode_trunc_body:
    mov     rdi, obu_trunc_body
    mov     esi, 3
    mov     rdx, desc
    call    er_av1_obu_decode_unit
    test    eax, eax
    jnz     .fail_obu_decode_trunc_body
    cmp     edx, ERROR_NO_DATA
    jne     .fail_obu_decode_trunc_body
    inc     qword [rel passed]
    jmp     .obu_encode_prefix_base
.fail_obu_decode_trunc_body:
    inc     qword [rel failed]

.obu_encode_prefix_base:
    mov     rdi, outbuf
    mov     esi, 16
    mov     edx, AV1_OBU_TYPE_SEQUENCE_HEADER
    mov     ecx, 3
    xor     r8d, r8d
    xor     r9d, r9d
    call    er_av1_obu_encode_prefix
    cmp     eax, 2
    jne     .fail_obu_encode_prefix_base
    test    edx, edx
    jnz     .fail_obu_encode_prefix_base
    cmp     byte [rel outbuf], 0x0a
    jne     .fail_obu_encode_prefix_base
    cmp     byte [rel outbuf + 1], 0x03
    jne     .fail_obu_encode_prefix_base
    inc     qword [rel passed]
    jmp     .obu_encode_prefix_ext
.fail_obu_encode_prefix_base:
    inc     qword [rel failed]

.obu_encode_prefix_ext:
    mov     rdi, outbuf
    mov     esi, 16
    mov     edx, AV1_OBU_TYPE_FRAME
    mov     ecx, 128
    mov     r8d, 3
    mov     r9d, 1
    call    er_av1_obu_encode_prefix
    cmp     eax, 4
    jne     .fail_obu_encode_prefix_ext
    test    edx, edx
    jnz     .fail_obu_encode_prefix_ext
    cmp     byte [rel outbuf], 0x36
    jne     .fail_obu_encode_prefix_ext
    cmp     byte [rel outbuf + 1], 0x68
    jne     .fail_obu_encode_prefix_ext
    cmp     byte [rel outbuf + 2], 0x80
    jne     .fail_obu_encode_prefix_ext
    cmp     byte [rel outbuf + 3], 0x01
    jne     .fail_obu_encode_prefix_ext
    inc     qword [rel passed]
    jmp     .obu_encode_prefix_no_space
.fail_obu_encode_prefix_ext:
    inc     qword [rel failed]

.obu_encode_prefix_no_space:
    mov     rdi, outbuf
    mov     esi, 1
    mov     edx, AV1_OBU_TYPE_SEQUENCE_HEADER
    mov     ecx, 3
    xor     r8d, r8d
    xor     r9d, r9d
    call    er_av1_obu_encode_prefix
    test    eax, eax
    jnz     .fail_obu_encode_prefix_no_space
	cmp     edx, ERROR_NO_SPACE
	jne     .fail_obu_encode_prefix_no_space
	inc     qword [rel passed]
	jmp     .obu_encode_temporal_delimiter
.fail_obu_encode_prefix_no_space:
	inc     qword [rel failed]

.obu_encode_temporal_delimiter:
	mov     rdi, outbuf
	mov     esi, 16
	call    er_av1_obu_encode_temporal_delimiter
	cmp     eax, 2
	jne     .fail_obu_encode_temporal_delimiter
	test    edx, edx
	jnz     .fail_obu_encode_temporal_delimiter
	cmp     byte [rel outbuf], 0x12
	jne     .fail_obu_encode_temporal_delimiter
	cmp     byte [rel outbuf + 1], 0x00
	jne     .fail_obu_encode_temporal_delimiter
	inc     qword [rel passed]
	jmp     .obu_encode_temporal_delimiter_no_space
.fail_obu_encode_temporal_delimiter:
	inc     qword [rel failed]

.obu_encode_temporal_delimiter_no_space:
	mov     rdi, outbuf
	mov     esi, 1
	call    er_av1_obu_encode_temporal_delimiter
	test    eax, eax
	jnz     .fail_obu_encode_temporal_delimiter_no_space
	cmp     edx, ERROR_NO_SPACE
	jne     .fail_obu_encode_temporal_delimiter_no_space
	inc     qword [rel passed]
	jmp     .done
.fail_obu_encode_temporal_delimiter_no_space:
	inc     qword [rel failed]

.done:
	xor     edi, edi
	cmp     qword [rel failed], 0
    sete    dil
    xor     dil, 1
    mov     eax, 60
    syscall

expect_header_error:
    mov     r8d, edx
    mov     rdx, desc
    call    er_av1_obu_decode_header
    test    eax, eax
    jnz     fail_header_error
    cmp     edx, r8d
    jne     fail_header_error
    inc     qword [rel passed]
    ret
fail_header_error:
    inc     qword [rel failed]
    ret
