; EdgeRun AV1 MP4 self-hosted test runner — x86_64 assembly.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/mp4_constants.inc"
%include "test/test_macros.inc"

extern er_mp4_read_box
extern er_mp4_ftyp_has_brand
extern er_mp4_find_box
extern er_mp4_find_child_box
extern er_mp4_stsd_first_entry
extern er_mp4_sample_entry_find_child
extern er_mp4_av1c_decode
extern er_mp4_is_av1

TEST_BSS_PASSED_FAILED
box_desc:   resb MP4_BOX_DESC_SIZE
entry_desc: resb MP4_BOX_DESC_SIZE
av1c_desc:  resb MP4_AV1C_DESC_SIZE

SECTION .data
mp4_av1:
    db 0x00,0x00,0x00,0x20
    db 'f','t','y','p'
    db 'i','s','o','m'
    db 0x00,0x00,0x02,0x00
    db 'i','s','o','m'
    db 'a','v','0','1'
    db 'i','s','o','2'
    db 'm','p','4','1'
    db 0x00,0x00,0x00,0x10
    db 'm','d','a','t'
    times 8 db 0xaa
mp4_av1_len equ $ - mp4_av1

mp4_large:
    db 0x00,0x00,0x00,0x01
    db 'm','d','a','t'
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x18
    times 8 db 0xbb
mp4_large_len equ $ - mp4_large

mp4_to_eof:
    db 0x00,0x00,0x00,0x00
    db 'm','d','a','t'
    times 5 db 0xcc
mp4_to_eof_len equ $ - mp4_to_eof

mp4_trunc:
    db 0x00,0x00,0x00,0x20
    db 'f','t','y','p'
    db 'i','s','o','m'
mp4_trunc_len equ $ - mp4_trunc

mp4_no_av1:
    db 0x00,0x00,0x00,0x18
    db 'f','t','y','p'
    db 'i','s','o','m'
    db 0x00,0x00,0x02,0x00
    db 'i','s','o','m'
    db 'i','s','o','2'
mp4_no_av1_len equ $ - mp4_no_av1

mp4_parent:
    db 0x00,0x00,0x00,0x20
    db 'm','o','o','v'
    db 0x00,0x00,0x00,0x08
    db 'f','r','e','e'
    db 0x00,0x00,0x00,0x10
    db 'm','d','a','t'
    times 8 db 0xdd
mp4_parent_len equ $ - mp4_parent

mp4_sample:
    db 0x00,0x00,0x00,0x08
    db 'f','r','e','e'
    db 0x00,0x00,0x00,0x76
    db 's','t','s','d'
    db 0x00,0x00,0x00,0x00
    db 0x00,0x00,0x00,0x01
    db 0x00,0x00,0x00,0x66
    db 'a','v','0','1'
    times MP4_VISUAL_SAMPLE_ENTRY_CHILD_OFFSET db 0
    db 0x00,0x00,0x00,0x10
    db 'a','v','1','C'
    db 0x81,0x08,0x0c,0x00
    db 0x0a,0x0b,0x00,0x00
mp4_sample_len equ $ - mp4_sample

SECTION .text
global _start
_start:
    mov     rdi, mp4_av1
    mov     esi, mp4_av1_len
    xor     edx, edx
    mov     rcx, box_desc
    call    er_mp4_read_box
    cmp     eax, 32
    jne     .fail_read_ftyp
    test    edx, edx
    jnz     .fail_read_ftyp
    cmp     dword [rel box_desc + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_FTYP
    jne     .fail_read_ftyp
    cmp     dword [rel box_desc + MP4_BOX_DESC_HEADER_SIZE], MP4_BOX_HEADER_SIZE
    jne     .fail_read_ftyp
    cmp     dword [rel box_desc + MP4_BOX_DESC_PAYLOAD_OFFSET], 8
    jne     .fail_read_ftyp
    cmp     dword [rel box_desc + MP4_BOX_DESC_PAYLOAD_LEN], 24
    jne     .fail_read_ftyp
    cmp     dword [rel box_desc + MP4_BOX_DESC_NEXT_OFFSET], 32
    jne     .fail_read_ftyp
    inc     qword [rel passed]
    jmp     .read_mdat
.fail_read_ftyp:
    inc     qword [rel failed]

.read_mdat:
    mov     rdi, mp4_av1
    mov     esi, mp4_av1_len
    mov     edx, 32
    mov     rcx, box_desc
    call    er_mp4_read_box
    cmp     eax, 48
    jne     .fail_read_mdat
    test    edx, edx
    jnz     .fail_read_mdat
    cmp     dword [rel box_desc + MP4_BOX_DESC_PAYLOAD_OFFSET], 40
    jne     .fail_read_mdat
    cmp     dword [rel box_desc + MP4_BOX_DESC_PAYLOAD_LEN], 8
    jne     .fail_read_mdat
    inc     qword [rel passed]
    jmp     .av1_brand
.fail_read_mdat:
    inc     qword [rel failed]

.av1_brand:
    mov     rdi, mp4_av1
    mov     esi, mp4_av1_len
    xor     edx, edx
    mov     rcx, box_desc
    call    er_mp4_read_box
    mov     rdi, mp4_av1
    mov     esi, mp4_av1_len
    mov     rdx, box_desc
    mov     ecx, MP4_BRAND_AV01
    call    er_mp4_ftyp_has_brand
    cmp     eax, 1
    jne     .fail_av1_brand
    test    edx, edx
    jnz     .fail_av1_brand
    inc     qword [rel passed]
    jmp     .is_av1
.fail_av1_brand:
    inc     qword [rel failed]

.is_av1:
    mov     rdi, mp4_av1
    mov     esi, mp4_av1_len
    call    er_mp4_is_av1
    cmp     eax, 1
    jne     .fail_is_av1
    test    edx, edx
    jnz     .fail_is_av1
    inc     qword [rel passed]
    jmp     .no_av1
.fail_is_av1:
    inc     qword [rel failed]

.no_av1:
    mov     rdi, mp4_no_av1
    mov     esi, mp4_no_av1_len
    call    er_mp4_is_av1
    test    eax, eax
    jnz     .fail_no_av1
    test    edx, edx
    jnz     .fail_no_av1
    inc     qword [rel passed]
    jmp     .find_mdat
.fail_no_av1:
    inc     qword [rel failed]

.find_mdat:
    mov     rdi, mp4_av1
    mov     esi, mp4_av1_len
    xor     edx, edx
    mov     ecx, MP4_BOX_TYPE_MDAT
    mov     r8, box_desc
    call    er_mp4_find_box
    cmp     eax, 48
    jne     .fail_find_mdat
    test    edx, edx
    jnz     .fail_find_mdat
    cmp     dword [rel box_desc + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_MDAT
    jne     .fail_find_mdat
    cmp     dword [rel box_desc + MP4_BOX_DESC_PAYLOAD_OFFSET], 40
    jne     .fail_find_mdat
    cmp     dword [rel box_desc + MP4_BOX_DESC_PAYLOAD_LEN], 8
    jne     .fail_find_mdat
    inc     qword [rel passed]
    jmp     .find_missing
.fail_find_mdat:
    inc     qword [rel failed]

.find_missing:
    mov     rdi, mp4_av1
    mov     esi, mp4_av1_len
    xor     edx, edx
    mov     ecx, MP4_BOX_TYPE_MOOV
    mov     r8, box_desc
    call    er_mp4_find_box
    test    eax, eax
    jnz     .fail_find_missing
    cmp     edx, ERROR_NO_DATA
    jne     .fail_find_missing
    inc     qword [rel passed]
    jmp     .find_child
.fail_find_missing:
    inc     qword [rel failed]

.find_child:
    mov     rdi, mp4_parent
    mov     esi, mp4_parent_len
    xor     edx, edx
    mov     rcx, box_desc
    call    er_mp4_read_box
    test    edx, edx
    jnz     .fail_find_child
    mov     rdi, mp4_parent
    mov     esi, mp4_parent_len
    mov     rdx, box_desc
    mov     ecx, MP4_BOX_TYPE_MDAT
    mov     r8, entry_desc
    call    er_mp4_find_child_box
    cmp     eax, mp4_parent_len
    jne     .fail_find_child
    test    edx, edx
    jnz     .fail_find_child
    cmp     dword [rel entry_desc + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_MDAT
    jne     .fail_find_child
    cmp     dword [rel entry_desc + MP4_BOX_DESC_PAYLOAD_OFFSET], 24
    jne     .fail_find_child
    cmp     dword [rel entry_desc + MP4_BOX_DESC_PAYLOAD_LEN], 8
    jne     .fail_find_child
    inc     qword [rel passed]
    jmp     .child_stsd
.fail_find_child:
    inc     qword [rel failed]

.child_stsd:
    mov     rdi, mp4_sample
    mov     esi, mp4_sample_len
    mov     edx, 8
    mov     rcx, box_desc
    call    er_mp4_read_box
    test    edx, edx
    jnz     .fail_child_stsd
    mov     rdi, mp4_sample
    mov     esi, mp4_sample_len
    mov     rdx, box_desc
    mov     rcx, entry_desc
    call    er_mp4_stsd_first_entry
    cmp     eax, mp4_sample_len
    jne     .fail_child_stsd
    test    edx, edx
    jnz     .fail_child_stsd
    cmp     dword [rel entry_desc + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_AV01
    jne     .fail_child_stsd
    inc     qword [rel passed]
    jmp     .entry_av1c
.fail_child_stsd:
    inc     qword [rel failed]

.entry_av1c:
    mov     rdi, mp4_sample
    mov     esi, mp4_sample_len
    mov     rdx, entry_desc
    mov     ecx, MP4_BOX_TYPE_AV1C
    mov     r8, box_desc
    call    er_mp4_sample_entry_find_child
    cmp     eax, mp4_sample_len
    jne     .fail_entry_av1c
    test    edx, edx
    jnz     .fail_entry_av1c
    cmp     dword [rel box_desc + MP4_BOX_DESC_TYPE], MP4_BOX_TYPE_AV1C
    jne     .fail_entry_av1c
    cmp     dword [rel box_desc + MP4_BOX_DESC_PAYLOAD_LEN], 8
    jne     .fail_entry_av1c
    inc     qword [rel passed]
    jmp     .decode_av1c
.fail_entry_av1c:
    inc     qword [rel failed]

.decode_av1c:
    mov     rdi, mp4_sample
    mov     esi, mp4_sample_len
    mov     rdx, box_desc
    mov     rcx, av1c_desc
    call    er_mp4_av1c_decode
    cmp     eax, 4
    jne     .fail_decode_av1c
    test    edx, edx
    jnz     .fail_decode_av1c
    cmp     byte [rel av1c_desc + MP4_AV1C_DESC_PROFILE], 0
    jne     .fail_decode_av1c
    cmp     byte [rel av1c_desc + MP4_AV1C_DESC_LEVEL], 8
    jne     .fail_decode_av1c
    cmp     byte [rel av1c_desc + MP4_AV1C_DESC_SUBSAMPLING_X], 1
    jne     .fail_decode_av1c
    cmp     byte [rel av1c_desc + MP4_AV1C_DESC_SUBSAMPLING_Y], 1
    jne     .fail_decode_av1c
    cmp     dword [rel av1c_desc + MP4_AV1C_DESC_CONFIG_OBU_OFFSET], 122
    jne     .fail_decode_av1c
    cmp     dword [rel av1c_desc + MP4_AV1C_DESC_CONFIG_OBU_LEN], 4
    jne     .fail_decode_av1c
    inc     qword [rel passed]
    jmp     .large_box
.fail_decode_av1c:
    inc     qword [rel failed]

.large_box:
    mov     rdi, mp4_large
    mov     esi, mp4_large_len
    xor     edx, edx
    mov     rcx, box_desc
    call    er_mp4_read_box
    cmp     eax, 24
    jne     .fail_large_box
    test    edx, edx
    jnz     .fail_large_box
    cmp     dword [rel box_desc + MP4_BOX_DESC_HEADER_SIZE], MP4_BOX_LARGE_HEADER_SIZE
    jne     .fail_large_box
    cmp     dword [rel box_desc + MP4_BOX_DESC_PAYLOAD_LEN], 8
    jne     .fail_large_box
    inc     qword [rel passed]
    jmp     .to_eof
.fail_large_box:
    inc     qword [rel failed]

.to_eof:
    mov     rdi, mp4_to_eof
    mov     esi, mp4_to_eof_len
    xor     edx, edx
    mov     rcx, box_desc
    call    er_mp4_read_box
    cmp     eax, mp4_to_eof_len
    jne     .fail_to_eof
    test    edx, edx
    jnz     .fail_to_eof
    cmp     dword [rel box_desc + MP4_BOX_DESC_PAYLOAD_LEN], 5
    jne     .fail_to_eof
    inc     qword [rel passed]
    jmp     .truncated
.fail_to_eof:
    inc     qword [rel failed]

.truncated:
    mov     rdi, mp4_trunc
    mov     esi, mp4_trunc_len
    xor     edx, edx
    mov     rcx, box_desc
    call    er_mp4_read_box
    test    eax, eax
    jnz     .fail_truncated
    cmp     edx, ERROR_NO_DATA
    jne     .fail_truncated
    inc     qword [rel passed]
    jmp     .invalid
.fail_truncated:
    inc     qword [rel failed]

.invalid:
    xor     rdi, rdi
    mov     esi, mp4_av1_len
    call    er_mp4_is_av1
    test    eax, eax
    jnz     .fail_invalid
    cmp     edx, ERROR_INVALID_PARAM
    jne     .fail_invalid
    inc     qword [rel passed]
    jmp     .done
.fail_invalid:
    inc     qword [rel failed]

.done:
    cmp     qword [rel failed], 0
    je      .exit_ok
    mov     rdi, 1
    mov     rsi, failed
    mov     rdx, 8
    mov     rax, 1
    syscall
    mov     rax, 60
    mov     rdi, 1
    syscall
.exit_ok:
    mov     rax, 60
    xor     rdi, rdi
    syscall
