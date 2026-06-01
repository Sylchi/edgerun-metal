; EdgeRun render_ir self-hosted test — x86_64 assembly
; Exits via syscall: 0 = pass, 1 = fail.

%include "x86_64/macros.inc"
%include "test/test_macros.inc"

extern er_render_ir_channel
extern er_render_ir_pack_channel
extern er_render_ir_push_rect
extern er_render_ir_push_textured_vertex
extern er_render_ir_push_icon
extern er_render_ir_rect_at
extern er_render_ir_textured_vertex_at
extern er_render_ir_icon_at
extern er_render_ir_rect_count
extern er_render_ir_textured_vertex_count
extern er_render_ir_icon_count
extern er_render_ir_validate_buffers
extern er_render_ir_push_rect_ex
extern er_render_ir_push_textured_vertex_ex
extern er_render_ir_push_icon_ex
extern er_render_ir_push_textured_quad

%define RS  15
%define VS  8
%define IS  9

SECTION .rodata
align 16
float_one:  dd 0x3f800000

rect_data1:
    dd 0x41200000, 0x41a00000, 0x42c80000, 0x42700000
    dd 0x40800000, 0x00000000
    dd 0x3f800000, 0x00000000, 0x00000000, 0x3f000000
    dd 0x00000000, 0x3f800000, 0x00000000, 0x3f800000
    dd 0x00000000

rect_data2:
    dd 0x40a00000, 0x40a00000, 0x42480000, 0x42480000
    dd 0x00000000, 0x40000000
    dd 0x00000000, 0x00000000, 0x3f800000, 0x3f800000
    dd 0x3f800000, 0x3f800000, 0x00000000, 0x3f800000
    dd 0x40000000

vertex_data1:
    dd 0x41800000, 0x42000000, 0x3e800000, 0x3f400000
    dd 0x3f000000, 0x3f000000, 0x3f000000, 0x3f800000

icon_data1:
    dd 0x41f00000, 0x42200000, 0x41c00000, 0x41c00000
    dd 0x3f800000, 0x00000000, 0x00000000, 0x3f800000
    dd 0x42280000

lens_ok:    dq RS*4, VS, IS, 0, 0, 0, 0, 0, 0
caps_ok:    dq RS*4, VS, IS, 1, 1, 1, 1, 1, 1
lens_bad:   dq 999, 0, 0, 0, 0, 0, 0, 0, 0
caps_bad:   dq RS*4, 0, 0, 0, 0, 0, 0, 0, 0

ex_bounds:
    dd 0x41200000, 0x41A00000, 0x42C80000, 0x42700000  ; (10, 20, 100, 60)

rect_ex_expected:
    dd 0x41200000, 0x41A00000, 0x42C80000, 0x42700000  ; bounds
    dd 0x40800000, 0x00000000                            ; radius=4, shadow=0
    dd 0x3F800000, 0x3F800000, 0x3F800000, 0x3F800000  ; r=g=b=a=1.0
    dd 0x00000000, 0x00000000, 0x00000000, 0x00000000  ; r2=g2=b2=a2=0
    dd 0x00000000                                        ; mode=0

ex_vtx_expected:
    dd 0x41800000, 0x42000000  ; x=16, y=32
    dd 0x3E800000, 0x3F400000  ; u=0.25, v=0.75
    dd 0x3F800000, 0x3F800000, 0x3F800000, 0x3F800000  ; r=g=b=a=1.0

ex_icon_bounds:
    dd 0x41F00000, 0x42200000, 0x41C00000, 0x41C00000  ; (30, 40, 24, 24)

ex_icon_expected:
    dd 0x41F00000, 0x42200000, 0x41C00000, 0x41C00000  ; bounds
    dd 0x3F800000, 0x3F800000, 0x3F800000, 0x3F800000  ; r=g=b=a=1.0
    dd 0x42280000                                        ; icon_id=42.0

rad_4_0:  dq 0x40800000
shad_0:   dq 0x00000000
mode_0:   dq 0x00000000

tq_bounds:
    dd 0x00000000, 0x00000000, 0x40800000, 0x40800000  ; (0, 0, 4, 4)
tq_clip:
    dd 0x3F800000, 0x3F800000, 0x40000000, 0x40000000  ; (1, 1, 2, 2)

tq_expected_1:
    dd 0x3F800000, 0x3F800000  ; x=1, y=1
    dd 0x3E800000, 0x3E800000  ; u=0.25, v=0.25
    dd 0x3F800000, 0x3F800000, 0x3F800000, 0x3F800000  ; rgba=white

tq_expected_2:
    dd 0x40400000, 0x3F800000  ; x=3, y=1
    dd 0x3F400000, 0x3E800000  ; u=0.75, v=0.25
    dd 0x3F800000, 0x3F800000, 0x3F800000, 0x3F800000

tq_expected_3:
    dd 0x40400000, 0x40400000  ; x=3, y=3
    dd 0x3F400000, 0x3F400000  ; u=0.75, v=0.75
    dd 0x3F800000, 0x3F800000, 0x3F800000, 0x3F800000

tq_expected_6:
    dd 0x3F800000, 0x40400000  ; x=1, y=3
    dd 0x3E800000, 0x3F400000  ; u=0.25, v=0.75
    dd 0x3F800000, 0x3F800000, 0x3F800000, 0x3F800000

tq_clip_miss:
    dd 0x41200000, 0x41200000, 0x40800000, 0x40800000  ; (10, 10, 4, 4) — no overlap

TEST_BSS_TOTAL_PASSED
rect_buf:   resd RS*4
vtx_buf:    resd VS*4
icon_buf:   resd IS*4
tq_buf:     resd 48           ; 6 vertices * 8 floats
rect_out:   resd RS
vtx_out:    resd VS
icon_out:   resd IS
tq_out:     resd 8            ; single vertex read-back

SECTION .data
rect_len:   dq 0
vtx_len:    dq 0
icon_len:   dq 0

SECTION .text
global _start
_start:
    ; ===== 1. er_render_ir_channel =====
    mov     edi, 0
    call    er_render_ir_channel
    movd    eax, xmm0
    xor     edx, edx
    TEST

    mov     edi, 255
    call    er_render_ir_channel
    movd    eax, xmm0
    mov     edx, [rel float_one]
    TEST

    ; ===== 2. er_render_ir_pack_channel =====
    pxor    xmm0, xmm0
    call    er_render_ir_pack_channel
    xor     edx, edx
    TEST

    movss   xmm0, [rel float_one]
    call    er_render_ir_pack_channel
    mov     edx, 255
    TEST

    ; ===== 3. rect push + read-back =====
    lea     rdi, [rel rect_buf]
    lea     rsi, [rel rect_len]
    mov     rdx, RS*4
    lea     rcx, [rel rect_data1]
    call    er_render_ir_push_rect
    xor     edx, edx
    TEST

    ; verify len == RS
    mov     rax, [rel rect_len]
    mov     rdx, RS
    TESTQ

    ; read back
    lea     rdi, [rel rect_buf]
    xor     esi, esi
    lea     rdx, [rel rect_out]
    call    er_render_ir_rect_at
    xor     edx, edx
    TEST

    ; compare output
    lea     rdi, [rel rect_out]
    lea     rsi, [rel rect_data1]
    mov     ecx, RS*4
    TEST_MEM

    ; push rect2
    lea     rdi, [rel rect_buf]
    lea     rsi, [rel rect_len]
    mov     rdx, RS*4
    lea     rcx, [rel rect_data2]
    call    er_render_ir_push_rect
    xor     edx, edx
    TEST

    ; read back index 1
    lea     rdi, [rel rect_buf]
    mov     esi, 1
    lea     rdx, [rel rect_out]
    call    er_render_ir_rect_at
    xor     edx, edx
    TEST

    lea     rdi, [rel rect_out]
    lea     rsi, [rel rect_data2]
    mov     ecx, RS*4
    TEST_MEM

    ; push 2 more rects
    lea     rdi, [rel rect_buf]
    lea     rsi, [rel rect_len]
    mov     rdx, RS*4
    lea     rcx, [rel rect_data1]
    call    er_render_ir_push_rect
    xor     edx, edx
    TEST
    lea     rcx, [rel rect_data1]
    mov     rdx, RS*4
    call    er_render_ir_push_rect
    xor     edx, edx
    TEST

    ; budget exceeded
    lea     rcx, [rel rect_data1]
    mov     rdx, RS*4
    call    er_render_ir_push_rect
    mov     edx, -1
    TEST

    ; final len
    mov     rax, [rel rect_len]
    mov     rdx, RS*4
    TESTQ

    ; verify index 0 not corrupted
    lea     rdi, [rel rect_buf]
    xor     esi, esi
    lea     rdx, [rel rect_out]
    call    er_render_ir_rect_at
    lea     rdi, [rel rect_out]
    lea     rsi, [rel rect_data1]
    mov     ecx, RS*4
    TEST_MEM

    ; ===== 4. vertex push + read-back =====
    lea     rdi, [rel vtx_buf]
    lea     rsi, [rel vtx_len]
    mov     rdx, VS*4
    lea     rcx, [rel vertex_data1]
    call    er_render_ir_push_textured_vertex
    xor     edx, edx
    TEST

    mov     rax, [rel vtx_len]
    mov     rdx, VS
    TESTQ

    lea     rdi, [rel vtx_buf]
    xor     esi, esi
    lea     rdx, [rel vtx_out]
    call    er_render_ir_textured_vertex_at
    xor     edx, edx
    TEST

    lea     rdi, [rel vtx_out]
    lea     rsi, [rel vertex_data1]
    mov     ecx, VS*4
    TEST_MEM

    ; ===== 5. icon push + read-back =====
    lea     rdi, [rel icon_buf]
    lea     rsi, [rel icon_len]
    mov     rdx, IS*4
    lea     rcx, [rel icon_data1]
    call    er_render_ir_push_icon
    xor     edx, edx
    TEST

    mov     rax, [rel icon_len]
    mov     rdx, IS
    TESTQ

    lea     rdi, [rel icon_buf]
    xor     esi, esi
    lea     rdx, [rel icon_out]
    call    er_render_ir_icon_at
    xor     edx, edx
    TEST

    lea     rdi, [rel icon_out]
    lea     rsi, [rel icon_data1]
    mov     ecx, IS*4
    TEST_MEM

    ; ===== 6. count helpers =====
    mov     rdi, [rel rect_len]
    call    er_render_ir_rect_count
    mov     rdx, 4
    TESTQ

    mov     edi, 7
    call    er_render_ir_rect_count
    mov     rdx, -2
    TESTQ

    mov     rdi, [rel vtx_len]
    call    er_render_ir_textured_vertex_count
    mov     rdx, 1
    TESTQ

    mov     rdi, [rel icon_len]
    call    er_render_ir_icon_count
    mov     rdx, 1
    TESTQ

    ; ===== 7. validate_buffers =====
    lea     rdi, [rel lens_ok]
    lea     rsi, [rel caps_ok]
    call    er_render_ir_validate_buffers
    xor     edx, edx
    TEST

    lea     rdi, [rel lens_bad]
    lea     rsi, [rel caps_bad]
    call    er_render_ir_validate_buffers
    mov     edx, -2
    TEST

    ; ===== 8. er_render_ir_push_rect_ex =====
    mov     qword [rel rect_len], 0

    lea     rdi, [rel rect_buf]
    lea     rsi, [rel rect_len]
    mov     rdx, RS*4
    lea     rcx, [rel ex_bounds]
    mov     r8d, 0xFFFFFFFF
    xor     r9d, r9d
    push    qword [rel mode_0]
    push    qword [rel shad_0]
    push    qword [rel rad_4_0]
    call    er_render_ir_push_rect_ex
    add     rsp, 24
    xor     edx, edx
    TEST

    mov     rax, [rel rect_len]
    mov     rdx, RS
    TESTQ

    lea     rdi, [rel rect_buf]
    xor     esi, esi
    lea     rdx, [rel rect_out]
    call    er_render_ir_rect_at
    xor     edx, edx
    TEST

    lea     rdi, [rel rect_out]
    lea     rsi, [rel rect_ex_expected]
    mov     ecx, RS*4
    TEST_MEM

    ; ===== 9. er_render_ir_push_textured_vertex_ex =====
    mov     qword [rel vtx_len], 0

    lea     rdi, [rel vtx_buf]
    lea     rsi, [rel vtx_len]
    mov     rdx, VS*4
    mov     ecx, 0xFFFFFFFF
    mov     eax, 0x41800000
    movd    xmm0, eax
    mov     eax, 0x42000000
    movd    xmm1, eax
    mov     eax, 0x3E800000
    movd    xmm2, eax
    mov     eax, 0x3F400000
    movd    xmm3, eax
    call    er_render_ir_push_textured_vertex_ex
    xor     edx, edx
    TEST

    mov     rax, [rel vtx_len]
    mov     rdx, VS
    TESTQ

    lea     rdi, [rel vtx_buf]
    xor     esi, esi
    lea     rdx, [rel vtx_out]
    call    er_render_ir_textured_vertex_at
    xor     edx, edx
    TEST

    lea     rdi, [rel vtx_out]
    lea     rsi, [rel ex_vtx_expected]
    mov     ecx, VS*4
    TEST_MEM

    ; ===== 10. er_render_ir_push_icon_ex =====
    mov     qword [rel icon_len], 0

    lea     rdi, [rel icon_buf]
    lea     rsi, [rel icon_len]
    mov     rdx, IS*4
    lea     rcx, [rel ex_icon_bounds]
    mov     r8d, 0xFFFFFFFF
    mov     r9d, 42
    call    er_render_ir_push_icon_ex
    xor     edx, edx
    TEST

    mov     rax, [rel icon_len]
    mov     rdx, IS
    TESTQ

    lea     rdi, [rel icon_buf]
    xor     esi, esi
    lea     rdx, [rel icon_out]
    call    er_render_ir_icon_at
    xor     edx, edx
    TEST

    lea     rdi, [rel icon_out]
    lea     rsi, [rel ex_icon_expected]
    mov     ecx, IS*4
    TEST_MEM

    ; ===== 11. er_render_ir_push_textured_quad =====
    mov     qword [rel vtx_len], 0

    ; Normal case: bounds=(0,0,4,4), clip=(1,1,2,2) → intersection=(1,1,2,2)
    lea     rdi, [rel tq_buf]
    lea     rsi, [rel vtx_len]
    mov     rdx, 48
    lea     rcx, [rel tq_clip]
    lea     r8,  [rel tq_bounds]
    pxor    xmm0, xmm0            ; tex_u0 = 0
    pxor    xmm1, xmm1            ; tex_v0 = 0
    mov     eax, 0x3F800000
    movd    xmm2, eax             ; tex_u1 = 1.0
    movd    xmm3, eax             ; tex_v1 = 1.0
    mov     r9d, 0xFFFFFFFF       ; color = white
    call    er_render_ir_push_textured_quad
    xor     edx, edx
    TEST                           ; return 0

    ; len == 48 (6 * 8)
    mov     rax, [rel vtx_len]
    mov     rdx, 48
    TESTQ                          ; len correct

    ; Verify vertex 1
    lea     rdi, [rel tq_buf]
    xor     esi, esi
    lea     rdx, [rel tq_out]
    call    er_render_ir_textured_vertex_at
    xor     edx, edx
    TEST
    lea     rdi, [rel tq_out]
    lea     rsi, [rel tq_expected_1]
    mov     ecx, VS*4
    TEST_MEM

    ; Verify vertex 2 (index 1)
    lea     rdi, [rel tq_buf]
    mov     esi, 1
    lea     rdx, [rel tq_out]
    call    er_render_ir_textured_vertex_at
    xor     edx, edx
    TEST
    lea     rdi, [rel tq_out]
    lea     rsi, [rel tq_expected_2]
    mov     ecx, VS*4
    TEST_MEM

    ; Verify vertex 3 (index 2)
    lea     rdi, [rel tq_buf]
    mov     esi, 2
    lea     rdx, [rel tq_out]
    call    er_render_ir_textured_vertex_at
    xor     edx, edx
    TEST
    lea     rdi, [rel tq_out]
    lea     rsi, [rel tq_expected_3]
    mov     ecx, VS*4
    TEST_MEM

    ; Verify vertex 6 (index 5 — last)
    lea     rdi, [rel tq_buf]
    mov     esi, 5
    lea     rdx, [rel tq_out]
    call    er_render_ir_textured_vertex_at
    xor     edx, edx
    TEST
    lea     rdi, [rel tq_out]
    lea     rsi, [rel tq_expected_6]
    mov     ecx, VS*4
    TEST_MEM

    ; ===== 12. No intersection (clip far away) =====
    lea     rdi, [rel tq_buf]
    lea     rsi, [rel vtx_len]
    mov     rdx, 48
    lea     rcx, [rel tq_clip_miss]
    lea     r8,  [rel tq_bounds]
    pxor    xmm0, xmm0
    pxor    xmm1, xmm1
    mov     eax, 0x3F800000
    movd    xmm2, eax
    movd    xmm3, eax
    mov     r9d, 0xFFFFFFFF
    call    er_render_ir_push_textured_quad
    xor     edx, edx
    TEST                           ; return 0 (nothing to draw)

    ; len unchanged (still 48)
    mov     rax, [rel vtx_len]
    mov     rdx, 48
    TESTQ

    ; ===== 13. Budget exceeded =====
    ; len=48, capacity=48 → no room for 48 more
    lea     rdi, [rel tq_buf]
    lea     rsi, [rel vtx_len]
    mov     rdx, 48                ; capacity = 48, same as current len
    lea     rcx, [rel tq_clip]
    lea     r8,  [rel tq_bounds]
    pxor    xmm0, xmm0
    pxor    xmm1, xmm1
    mov     eax, 0x3F800000
    movd    xmm2, eax
    movd    xmm3, eax
    mov     r9d, 0xFFFFFFFF
    call    er_render_ir_push_textured_quad
    mov     edx, -1
    TEST                           ; return -1

    ; len unchanged
    mov     rax, [rel vtx_len]
    mov     rdx, 48
    TESTQ

    ; ===== done =====
    TEST_EXIT_PASSED_TOTAL
