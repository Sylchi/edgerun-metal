; EdgeRun VP9 self-hosted test runner — x86_64 assembly.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/media/vp9_constants.inc"
%include "test/test_macros.inc"

extern er_vp9_parse_frame_header
extern er_vp9_is_key_frame

TEST_BSS_PASSED_FAILED
header_desc: resb VP9_HEADER_DESC_SIZE

SECTION .data
key_frame_640x360:
    db 0x42
    db 0x49,0x83,0x42
    db 0x7f,0x02
    db 0x67,0x01
    db 0x7f,0x02
    db 0x67,0x01
inter_frame:
    db 0x62
show_existing_5:
    db 0xb2
bad_marker:
    db 0x40
bad_sync:
    db 0x42
    db 0x49,0x83,0x43
    db 0x7f,0x02
    db 0x67,0x01
    db 0x7f,0x02
    db 0x67,0x01
profile3_reserved:
    db 0x5e

SECTION .text
global _start
_start:
    mov     rdi, key_frame_640x360
    mov     esi, VP9_KEY_HEADER_SIZE + 2
    mov     rdx, header_desc
    call    er_vp9_parse_frame_header
    cmp     eax, VP9_KEY_HEADER_SIZE
    jne     .fail_key
    test    edx, edx
    jnz     .fail_key
    cmp     byte [rel header_desc + VP9_HEADER_DESC_MARKER], VP9_FRAME_MARKER
    jne     .fail_key
    cmp     byte [rel header_desc + VP9_HEADER_DESC_PROFILE], 0
    jne     .fail_key
    cmp     byte [rel header_desc + VP9_HEADER_DESC_SHOW_EXISTING], 0
    jne     .fail_key
    cmp     byte [rel header_desc + VP9_HEADER_DESC_FRAME_TYPE], VP9_FRAME_TYPE_KEY
    jne     .fail_key
    cmp     byte [rel header_desc + VP9_HEADER_DESC_SHOW_FRAME], 1
    jne     .fail_key
    cmp     byte [rel header_desc + VP9_HEADER_DESC_ERROR_RESILIENT], 0
    jne     .fail_key
    cmp     word [rel header_desc + VP9_HEADER_DESC_WIDTH], 640
    jne     .fail_key
    cmp     word [rel header_desc + VP9_HEADER_DESC_HEIGHT], 360
    jne     .fail_key
    cmp     word [rel header_desc + VP9_HEADER_DESC_RENDER_WIDTH], 640
    jne     .fail_key
    cmp     word [rel header_desc + VP9_HEADER_DESC_RENDER_HEIGHT], 360
    jne     .fail_key
    inc     qword [rel passed]
    jmp     .is_key
.fail_key:
    inc     qword [rel failed]

.is_key:
    mov     rdi, key_frame_640x360
    mov     esi, VP9_KEY_HEADER_SIZE
    call    er_vp9_is_key_frame
    cmp     eax, 1
    jne     .fail_is_key
    test    edx, edx
    jnz     .fail_is_key
    inc     qword [rel passed]
    jmp     .inter
.fail_is_key:
    inc     qword [rel failed]

.inter:
    mov     rdi, inter_frame
    mov     esi, 1
    mov     rdx, header_desc
    call    er_vp9_parse_frame_header
    cmp     eax, VP9_INTER_HEADER_SIZE
    jne     .fail_inter
    test    edx, edx
    jnz     .fail_inter
    cmp     byte [rel header_desc + VP9_HEADER_DESC_FRAME_TYPE], VP9_FRAME_TYPE_INTER
    jne     .fail_inter
    cmp     byte [rel header_desc + VP9_HEADER_DESC_SHOW_FRAME], 1
    jne     .fail_inter
    cmp     byte [rel header_desc + VP9_HEADER_DESC_ERROR_RESILIENT], 0
    jne     .fail_inter
    inc     qword [rel passed]
    jmp     .show_existing
.fail_inter:
    inc     qword [rel failed]

.show_existing:
    mov     rdi, show_existing_5
    mov     esi, 1
    mov     rdx, header_desc
    call    er_vp9_parse_frame_header
    cmp     eax, VP9_SHOW_EXISTING_HEADER_SIZE
    jne     .fail_show_existing
    test    edx, edx
    jnz     .fail_show_existing
    cmp     byte [rel header_desc + VP9_HEADER_DESC_SHOW_EXISTING], 1
    jne     .fail_show_existing
    cmp     byte [rel header_desc + VP9_HEADER_DESC_EXISTING_FRAME_IDX], 5
    jne     .fail_show_existing
    inc     qword [rel passed]
    jmp     .short_key
.fail_show_existing:
    inc     qword [rel failed]

.short_key:
    mov     rdi, key_frame_640x360
    mov     esi, VP9_KEY_HEADER_SIZE - 1
    mov     rdx, header_desc
    call    er_vp9_parse_frame_header
    test    eax, eax
    jnz     .fail_short_key
    cmp     edx, ERROR_NO_DATA
    jne     .fail_short_key
    inc     qword [rel passed]
    jmp     .bad_marker
.fail_short_key:
    inc     qword [rel failed]

.bad_marker:
    mov     rdi, bad_marker
    mov     esi, 1
    mov     rdx, header_desc
    call    er_vp9_parse_frame_header
    test    eax, eax
    jnz     .fail_bad_marker
    cmp     edx, ERROR_CORRUPT
    jne     .fail_bad_marker
    inc     qword [rel passed]
    jmp     .bad_sync
.fail_bad_marker:
    inc     qword [rel failed]

.bad_sync:
    mov     rdi, bad_sync
    mov     esi, VP9_KEY_HEADER_SIZE
    mov     rdx, header_desc
    call    er_vp9_parse_frame_header
    test    eax, eax
    jnz     .fail_bad_sync
    cmp     edx, ERROR_CORRUPT
    jne     .fail_bad_sync
    inc     qword [rel passed]
    jmp     .profile3_reserved
.fail_bad_sync:
    inc     qword [rel failed]

.profile3_reserved:
    mov     rdi, profile3_reserved
    mov     esi, 1
    mov     rdx, header_desc
    call    er_vp9_parse_frame_header
    test    eax, eax
    jnz     .fail_profile3_reserved
    cmp     edx, ERROR_UNSUPPORTED
    jne     .fail_profile3_reserved
    inc     qword [rel passed]
    jmp     .done
.fail_profile3_reserved:
    inc     qword [rel failed]

.done:
    mov     rax, [rel failed]
    test    rax, rax
    jz      .ok
    mov     edi, 1
    mov     eax, 60
    syscall
.ok:
    xor     edi, edi
    mov     eax, 60
    syscall
