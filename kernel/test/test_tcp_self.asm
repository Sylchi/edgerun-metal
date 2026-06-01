; EdgeRun TCP checksum self-hosted test.

%include "x86_64/macros.inc"
%include "x86_64/net/net_constants.inc"
%include "test/test_macros.inc"

extern _tcp_compute_checksum

TEST_BSS_PASSED_FAILED

SECTION .data
conn:
    times TCP_CONN_SIZE db 0

tcp_test_segment:
    db 0x30, 0x39, 0x00, 0x50
    db 0x11, 0x22, 0x33, 0x44
    db 0x55, 0x66, 0x77, 0x88
    db 0x50, 0x18, 0x40, 0x00
    db 0x00, 0x00, 0x00, 0x00
    db "test"
tcp_test_segment_len equ $ - tcp_test_segment

SECTION .text
global _start
_start:
    ; 192.168.1.10 and 192.168.1.20 stored as network-order bytes.
    mov     dword [rel conn + TCP_CONN_SRC_IP], 0x0a01a8c0
    mov     dword [rel conn + TCP_CONN_DST_IP], 0x1401a8c0

    lea     rdi, [rel conn]
    lea     rsi, [rel tcp_test_segment]
    mov     edx, tcp_test_segment_len
    call    _tcp_compute_checksum

    ASSERT_EQ byte [rel tcp_test_segment + TCP_CHECKSUM], 0xc2
    ASSERT_EQ byte [rel tcp_test_segment + TCP_CHECKSUM + 1], 0xa1

    TEST_EXIT_FAILED
