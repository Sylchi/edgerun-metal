; EdgeRun TCP checksum self-hosted test.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"
%include "x86_64/net/net_constants.inc"
%include "test/test_macros.inc"

extern _tcp_compute_checksum
extern er_tcp_init
extern er_tcp_connect
extern er_tcp_get_state
extern er_tcp_handle
extern er_tcp_send
extern er_tcp_recv
extern er_tcp_close
extern er_tcp_poll
extern tcp_stub_last_dst_ip
extern tcp_stub_last_proto
extern tcp_stub_last_len
extern tcp_stub_last_packet
extern tcp_stub_send_count

TEST_BSS_PASSED_FAILED
ip_packet: resb 96
recv_buf: resb 16
recv_len: resd 1
conn_id: resd 1

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

    call    er_tcp_init
    ASSERT_RDX 0

    mov     edi, 0x0200000a
    mov     esi, 443
    xor     edx, edx
    xor     ecx, ecx
    call    er_tcp_connect
    ASSERT_RDX 0
    ASSERT_EQ eax, 0
    mov     [rel conn_id], eax
    ASSERT_EQ dword [rel tcp_stub_last_dst_ip], 0x0200000a
    ASSERT_EQ dword [rel tcp_stub_last_proto], IP_PROTO_TCP
    ASSERT_EQ dword [rel tcp_stub_last_len], 24
    ASSERT_EQ byte [rel tcp_stub_last_packet + TCP_FLAGS], TCP_SYN
    ASSERT_EQ byte [rel tcp_stub_last_packet + TCP_DATA_OFF], 0x60
    ASSERT_EQ word [rel tcp_stub_last_packet + TCP_SRC_PORT], 0x00c0
    ASSERT_EQ word [rel tcp_stub_last_packet + TCP_DST_PORT], 0xbb01
    ASSERT_EQ dword [rel tcp_stub_send_count], 1

    call    er_tcp_poll
    ASSERT_RDX 0
    ASSERT_EQ byte [rel tcp_stub_last_packet + TCP_FLAGS], TCP_SYN
    ASSERT_EQ dword [rel tcp_stub_send_count], 2

    call    build_syn_ack
    lea     rdi, [rel ip_packet]
    mov     esi, IP_HDR_LEN + TCP_HDR_LEN
    call    er_tcp_handle
    ASSERT_RDX 0
    mov     edi, [rel conn_id]
    call    er_tcp_get_state
    ASSERT_EQ eax, TCP_ESTABLISHED
    ASSERT_EQ byte [rel tcp_stub_last_packet + TCP_FLAGS], TCP_ACK
    ASSERT_EQ dword [rel tcp_stub_last_len], TCP_HDR_LEN
    ASSERT_EQ dword [rel tcp_stub_last_packet + TCP_ACK_NUM], 0x45332211

    call    build_bad_seq_packet
    lea     rdi, [rel ip_packet]
    mov     esi, IP_HDR_LEN + TCP_HDR_LEN + 3
    call    er_tcp_handle
    ASSERT_RDX 0
    mov     dword [rel recv_len], 16
    mov     edi, [rel conn_id]
    lea     rsi, [rel recv_buf]
    lea     rdx, [rel recv_len]
    call    er_tcp_recv
    ASSERT_RDX 0
    ASSERT_EQ dword [rel recv_len], 0
    ASSERT_EQ dword [rel tcp_stub_last_packet + TCP_ACK_NUM], 0x45332211

    call    build_data_packet
    lea     rdi, [rel ip_packet]
    mov     esi, IP_HDR_LEN + TCP_HDR_LEN + 3
    call    er_tcp_handle
    ASSERT_RDX 0
    ASSERT_EQ byte [rel tcp_stub_last_packet + TCP_FLAGS], TCP_ACK
    ASSERT_EQ dword [rel tcp_stub_last_packet + TCP_ACK_NUM], 0x48332211

    mov     dword [rel recv_len], 16
    mov     edi, [rel conn_id]
    lea     rsi, [rel recv_buf]
    lea     rdx, [rel recv_len]
    call    er_tcp_recv
    ASSERT_RDX 0
    ASSERT_EQ dword [rel recv_len], 3
    ASSERT_EQ byte [rel recv_buf], 'a'
    ASSERT_EQ byte [rel recv_buf + 1], 'b'
    ASSERT_EQ byte [rel recv_buf + 2], 'c'
    ASSERT_EQ dword [rel tcp_stub_last_packet + TCP_ACK_NUM], 0x48332211

    mov     edi, [rel conn_id]
    lea     rsi, [rel send_payload]
    mov     edx, send_payload_len
    call    er_tcp_send
    ASSERT_RDX 0
    ASSERT_EQ byte [rel tcp_stub_last_packet + TCP_FLAGS], TCP_PSH | TCP_ACK
    ASSERT_EQ dword [rel tcp_stub_last_packet + TCP_SEQ_NUM], 0x05030201
    ASSERT_EQ dword [rel tcp_stub_last_packet + TCP_ACK_NUM], 0x48332211
    ASSERT_EQ byte [rel tcp_stub_last_packet + TCP_HDR_LEN], 'x'
    ASSERT_EQ byte [rel tcp_stub_last_packet + TCP_HDR_LEN + 1], 'y'

    mov     edi, [rel conn_id]
    xor     rsi, rsi
    mov     edx, 1
    call    er_tcp_send
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_INVALID_PARAM

    mov     dword [rel recv_len], 1
    mov     edi, [rel conn_id]
    xor     rsi, rsi
    lea     rdx, [rel recv_len]
    call    er_tcp_recv
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_INVALID_PARAM

    mov     edi, [rel conn_id]
    lea     rsi, [rel recv_buf]
    xor     edx, edx
    call    er_tcp_recv
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_INVALID_PARAM

    mov     edi, [rel conn_id]
    lea     rsi, [rel send_payload_2]
    mov     edx, send_payload_2_len
    call    er_tcp_send
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_BUSY

    call    er_tcp_poll
    ASSERT_RDX 0
    ASSERT_EQ byte [rel tcp_stub_last_packet + TCP_FLAGS], TCP_PSH | TCP_ACK
    ASSERT_EQ dword [rel tcp_stub_last_packet + TCP_SEQ_NUM], 0x05030201
    ASSERT_EQ byte [rel tcp_stub_last_packet + TCP_HDR_LEN], 'x'
    ASSERT_EQ byte [rel tcp_stub_last_packet + TCP_HDR_LEN + 1], 'y'

    mov     edi, [rel conn_id]
    call    er_tcp_close
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_BUSY

    call    build_ack_high_packet
    lea     rdi, [rel ip_packet]
    mov     esi, IP_HDR_LEN + TCP_HDR_LEN
    call    er_tcp_handle
    ASSERT_RDX 0

    mov     edi, [rel conn_id]
    lea     rsi, [rel send_payload_2]
    mov     edx, send_payload_2_len
    call    er_tcp_send
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_BUSY

    call    build_ack_xy_packet
    lea     rdi, [rel ip_packet]
    mov     esi, IP_HDR_LEN + TCP_HDR_LEN
    call    er_tcp_handle
    ASSERT_RDX 0

    mov     edi, [rel conn_id]
    lea     rsi, [rel send_payload_2]
    mov     edx, send_payload_2_len
    call    er_tcp_send
    ASSERT_RDX 0
    ASSERT_EQ byte [rel tcp_stub_last_packet + TCP_FLAGS], TCP_PSH | TCP_ACK
    ASSERT_EQ dword [rel tcp_stub_last_packet + TCP_SEQ_NUM], 0x07030201
    ASSERT_EQ byte [rel tcp_stub_last_packet + TCP_HDR_LEN], 'z'
    ASSERT_EQ byte [rel tcp_stub_last_packet + TCP_HDR_LEN + 1], 'z'

    call    build_ack_zz_packet
    lea     rdi, [rel ip_packet]
    mov     esi, IP_HDR_LEN + TCP_HDR_LEN
    call    er_tcp_handle
    ASSERT_RDX 0

    mov     edi, [rel conn_id]
    lea     rsi, [rel big_payload]
    mov     edx, big_payload_len
    call    er_tcp_send
    ASSERT_RDX 0
    ASSERT_EQ byte [rel tcp_stub_last_packet + TCP_FLAGS], TCP_PSH | TCP_ACK
    ASSERT_EQ dword [rel tcp_stub_last_packet + TCP_SEQ_NUM], 0xbd080201
    ASSERT_EQ dword [rel tcp_stub_last_len], TCP_HDR_LEN + 1
    ASSERT_EQ byte [rel tcp_stub_last_packet + TCP_HDR_LEN], 'q'

    call    build_ack_big_partial_packet
    lea     rdi, [rel ip_packet]
    mov     esi, IP_HDR_LEN + TCP_HDR_LEN
    call    er_tcp_handle
    ASSERT_RDX 0

    call    er_tcp_poll
    ASSERT_RDX 0
    ASSERT_EQ byte [rel tcp_stub_last_packet + TCP_FLAGS], TCP_PSH | TCP_ACK
    ASSERT_EQ dword [rel tcp_stub_last_packet + TCP_SEQ_NUM], 0xbd080201
    ASSERT_EQ dword [rel tcp_stub_last_len], TCP_HDR_LEN + 1

    call    build_ack_big_packet
    lea     rdi, [rel ip_packet]
    mov     esi, IP_HDR_LEN + TCP_HDR_LEN
    call    er_tcp_handle
    ASSERT_RDX 0

    mov     edi, [rel conn_id]
    lea     rsi, [rel oversize_payload]
    mov     edx, oversize_payload_len
    call    er_tcp_send
    ASSERT_EQ eax, -1
    ASSERT_RDX ERROR_INVALID_PARAM

    mov     edi, [rel conn_id]
    call    er_tcp_close
    ASSERT_RDX 0
    ASSERT_EQ byte [rel tcp_stub_last_packet + TCP_FLAGS], TCP_FIN | TCP_ACK
    ASSERT_EQ dword [rel tcp_stub_last_packet + TCP_SEQ_NUM], 0xbe080201

    call    er_tcp_poll
    ASSERT_RDX 0
    ASSERT_EQ byte [rel tcp_stub_last_packet + TCP_FLAGS], TCP_FIN | TCP_ACK
    ASSERT_EQ dword [rel tcp_stub_last_packet + TCP_SEQ_NUM], 0xbe080201

    call    build_ack_fin_packet
    lea     rdi, [rel ip_packet]
    mov     esi, IP_HDR_LEN + TCP_HDR_LEN
    call    er_tcp_handle
    ASSERT_RDX 0
    mov     edi, [rel conn_id]
    call    er_tcp_get_state
    ASSERT_EQ eax, TCP_FIN_WAIT_2

    TEST_EXIT_FAILED

send_payload: db "xy"
send_payload_len equ $ - send_payload
send_payload_2: db "zz"
send_payload_2_len equ $ - send_payload_2
big_payload: times TCP_DEFAULT_MSS + 1 db 'q'
big_payload_len equ $ - big_payload
oversize_payload: times TCP_CONN_TX_CAP + 1 db 'r'
oversize_payload_len equ $ - oversize_payload

build_ip_tcp_common:
    mov     byte [rel ip_packet + IP_VER_IHL], IP_DEFAULT_VER_IHL
    mov     byte [rel ip_packet + IP_PROTOCOL], IP_PROTO_TCP
    mov     word [rel ip_packet + IP_TOTAL_LEN], 0
    mov     dword [rel ip_packet + IP_SRC], 0x0200000a
    mov     dword [rel ip_packet + IP_DST], 0x0100000a
    mov     word [rel ip_packet + IP_HDR_LEN + TCP_SRC_PORT], 0xbb01
    mov     word [rel ip_packet + IP_HDR_LEN + TCP_DST_PORT], 0x00c0
    mov     byte [rel ip_packet + IP_HDR_LEN + TCP_DATA_OFF], TCP_DEFAULT_DATA_OFF
    mov     word [rel ip_packet + IP_HDR_LEN + TCP_WINDOW], 0xffff
    mov     word [rel ip_packet + IP_HDR_LEN + TCP_CHECKSUM], 0
    mov     word [rel ip_packet + IP_HDR_LEN + TCP_URGENT], 0
    ret

build_syn_ack:
    call    build_ip_tcp_common
    mov     word [rel ip_packet + IP_TOTAL_LEN], 0x2800
    mov     dword [rel ip_packet + IP_HDR_LEN + TCP_SEQ_NUM], 0x44332211
    mov     dword [rel ip_packet + IP_HDR_LEN + TCP_ACK_NUM], 0x05030201
    mov     byte [rel ip_packet + IP_HDR_LEN + TCP_FLAGS], TCP_SYN | TCP_ACK
    lea     rdi, [rel conn]
    mov     dword [rel conn + TCP_CONN_SRC_IP], 0x0100000a
    mov     dword [rel conn + TCP_CONN_DST_IP], 0x0200000a
    lea     rsi, [rel ip_packet + IP_HDR_LEN]
    mov     edx, TCP_HDR_LEN
    call    _tcp_compute_checksum
    ret

build_data_packet:
    call    build_ip_tcp_common
    mov     word [rel ip_packet + IP_TOTAL_LEN], 0x2b00
    mov     dword [rel ip_packet + IP_HDR_LEN + TCP_SEQ_NUM], 0x45332211
    mov     dword [rel ip_packet + IP_HDR_LEN + TCP_ACK_NUM], 0x05030201
    mov     byte [rel ip_packet + IP_HDR_LEN + TCP_FLAGS], TCP_PSH | TCP_ACK
    mov     byte [rel ip_packet + IP_HDR_LEN + TCP_HDR_LEN], 'a'
    mov     byte [rel ip_packet + IP_HDR_LEN + TCP_HDR_LEN + 1], 'b'
    mov     byte [rel ip_packet + IP_HDR_LEN + TCP_HDR_LEN + 2], 'c'
    lea     rdi, [rel conn]
    mov     dword [rel conn + TCP_CONN_SRC_IP], 0x0100000a
    mov     dword [rel conn + TCP_CONN_DST_IP], 0x0200000a
    lea     rsi, [rel ip_packet + IP_HDR_LEN]
    mov     edx, TCP_HDR_LEN + 3
    call    _tcp_compute_checksum
    ret

build_bad_seq_packet:
    call    build_data_packet
    mov     word [rel ip_packet + IP_HDR_LEN + TCP_CHECKSUM], 0
    mov     dword [rel ip_packet + IP_HDR_LEN + TCP_SEQ_NUM], 0x46332211
    lea     rdi, [rel conn]
    mov     dword [rel conn + TCP_CONN_SRC_IP], 0x0100000a
    mov     dword [rel conn + TCP_CONN_DST_IP], 0x0200000a
    lea     rsi, [rel ip_packet + IP_HDR_LEN]
    mov     edx, TCP_HDR_LEN + 3
    call    _tcp_compute_checksum
    ret

build_ack_common:
    call    build_ip_tcp_common
    mov     word [rel ip_packet + IP_TOTAL_LEN], 0x2800
    mov     dword [rel ip_packet + IP_HDR_LEN + TCP_SEQ_NUM], 0x48332211
    mov     byte [rel ip_packet + IP_HDR_LEN + TCP_FLAGS], TCP_ACK
    ret

build_ack_xy_packet:
    call    build_ack_common
    mov     dword [rel ip_packet + IP_HDR_LEN + TCP_ACK_NUM], 0x07030201
    lea     rdi, [rel conn]
    mov     dword [rel conn + TCP_CONN_SRC_IP], 0x0100000a
    mov     dword [rel conn + TCP_CONN_DST_IP], 0x0200000a
    lea     rsi, [rel ip_packet + IP_HDR_LEN]
    mov     edx, TCP_HDR_LEN
    call    _tcp_compute_checksum
    ret

build_ack_zz_packet:
    call    build_ack_common
    mov     dword [rel ip_packet + IP_HDR_LEN + TCP_ACK_NUM], 0x09030201
    lea     rdi, [rel conn]
    mov     dword [rel conn + TCP_CONN_SRC_IP], 0x0100000a
    mov     dword [rel conn + TCP_CONN_DST_IP], 0x0200000a
    lea     rsi, [rel ip_packet + IP_HDR_LEN]
    mov     edx, TCP_HDR_LEN
    call    _tcp_compute_checksum
    ret

build_ack_big_packet:
    call    build_ack_common
    mov     dword [rel ip_packet + IP_HDR_LEN + TCP_ACK_NUM], 0xbe080201
    lea     rdi, [rel conn]
    mov     dword [rel conn + TCP_CONN_SRC_IP], 0x0100000a
    mov     dword [rel conn + TCP_CONN_DST_IP], 0x0200000a
    lea     rsi, [rel ip_packet + IP_HDR_LEN]
    mov     edx, TCP_HDR_LEN
    call    _tcp_compute_checksum
    ret

build_ack_big_partial_packet:
    call    build_ack_common
    mov     dword [rel ip_packet + IP_HDR_LEN + TCP_ACK_NUM], 0xbd080201
    lea     rdi, [rel conn]
    mov     dword [rel conn + TCP_CONN_SRC_IP], 0x0100000a
    mov     dword [rel conn + TCP_CONN_DST_IP], 0x0200000a
    lea     rsi, [rel ip_packet + IP_HDR_LEN]
    mov     edx, TCP_HDR_LEN
    call    _tcp_compute_checksum
    ret

build_ack_high_packet:
    call    build_ack_common
    mov     dword [rel ip_packet + IP_HDR_LEN + TCP_ACK_NUM], 0xff030201
    lea     rdi, [rel conn]
    mov     dword [rel conn + TCP_CONN_SRC_IP], 0x0100000a
    mov     dword [rel conn + TCP_CONN_DST_IP], 0x0200000a
    lea     rsi, [rel ip_packet + IP_HDR_LEN]
    mov     edx, TCP_HDR_LEN
    call    _tcp_compute_checksum
    ret

build_ack_fin_packet:
    call    build_ack_common
    mov     dword [rel ip_packet + IP_HDR_LEN + TCP_ACK_NUM], 0xbf080201
    lea     rdi, [rel conn]
    mov     dword [rel conn + TCP_CONN_SRC_IP], 0x0100000a
    mov     dword [rel conn + TCP_CONN_DST_IP], 0x0200000a
    lea     rsi, [rel ip_packet + IP_HDR_LEN]
    mov     edx, TCP_HDR_LEN
    call    _tcp_compute_checksum
    ret
