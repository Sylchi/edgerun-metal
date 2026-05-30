; EdgeRun network protocol constants — x86_64 assembly
; Included by arp.asm, ipv4.asm, tcp.asm, net.asm
;
; Protocol header offsets, flag bits, well-known port numbers,
; and structure layouts for the TCP/IP stack.

; ==================================================================
; Ethernet header (14 bytes)
; ==================================================================
ETHER_DST      equ 0     ; 6 bytes — destination MAC
ETHER_SRC      equ 6     ; 6 bytes — source MAC
ETHER_TYPE     equ 12    ; 2 bytes — EtherType
ETHER_HDR_LEN  equ 14

; EtherType values (network byte order)
ETHERTYPE_IPV4 equ 0x0008  ; 0x0800 stored as little-endian word
ETHERTYPE_ARP  equ 0x0608  ; 0x0806 stored as little-endian word
ETHERTYPE_IPV6 equ 0xDD86  ; 0x86DD stored as little-endian word

; ==================================================================
; ARP packet (28 bytes, after Ethernet header)
; ==================================================================
ARP_HTYPE      equ 0     ; 2 bytes — hardware type (1 = Ethernet)
ARP_PTYPE      equ 2     ; 2 bytes — protocol type (0x0800 = IPv4)
ARP_HLEN       equ 4     ; 1 byte  — hardware address length (6)
ARP_PLEN       equ 5     ; 1 byte  — protocol address length (4)
ARP_OPER       equ 6     ; 2 bytes — operation (1=request, 2=reply)
ARP_SHA        equ 8     ; 6 bytes — sender hardware address
ARP_SPA        equ 14    ; 4 bytes — sender protocol address
ARP_THA        equ 18    ; 6 bytes — target hardware address
ARP_TPA        equ 24    ; 4 bytes — target protocol address
ARP_PKT_LEN    equ 28

ARP_OP_REQUEST equ 0x0100  ; 1 in network byte order (big-endian in LE word)
ARP_OP_REPLY   equ 0x0200  ; 2 in network byte order

; ==================================================================
; IPv4 header (20 bytes minimum)
; ==================================================================
IP_VER_IHL     equ 0     ; 1 byte  — version (top 4) + header length (bottom 4, in dwords)
IP_DSCP_ECN    equ 1     ; 1 byte  — differentiated services + ECN
IP_TOTAL_LEN   equ 2     ; 2 bytes — total length (header + payload)
IP_ID          equ 4     ; 2 bytes — identification
IP_FLAGS_FRAG  equ 6     ; 2 bytes — flags (top 3 bits) + fragment offset
IP_TTL         equ 8     ; 1 byte  — time to live
IP_PROTOCOL    equ 9     ; 1 byte  — protocol (6=TCP, 17=UDP)
IP_CHECKSUM    equ 10    ; 2 bytes — header checksum
IP_SRC         equ 12    ; 4 bytes — source IP address
IP_DST         equ 16    ; 4 bytes — destination IP address
IP_HDR_LEN     equ 20

; Default IP header values
IP_DEFAULT_VER_IHL equ 0x45  ; IPv4, 5 dword header (20 bytes)
IP_DEFAULT_TTL     equ 64

; IP protocols
IP_PROTO_TCP   equ 6
IP_PROTO_UDP   equ 17
IP_PROTO_ICMP  equ 1

; ==================================================================
; TCP header (20 bytes minimum)
; ==================================================================
TCP_SRC_PORT   equ 0     ; 2 bytes
TCP_DST_PORT   equ 2     ; 2 bytes
TCP_SEQ_NUM    equ 4     ; 4 bytes
TCP_ACK_NUM    equ 8     ; 4 bytes
TCP_DATA_OFF   equ 12    ; 1 byte  — data offset (top 4 bits, in dwords)
TCP_FLAGS      equ 13    ; 1 byte  — control flags
TCP_WINDOW     equ 14    ; 2 bytes — receive window
TCP_CHECKSUM   equ 16    ; 2 bytes — checksum (pseudo-header + segment)
TCP_URGENT     equ 18    ; 2 bytes — urgent pointer
TCP_HDR_LEN    equ 20

; TCP header length value for 20-byte header
TCP_DEFAULT_DATA_OFF equ 0x50  ; 5 dwords = 20 bytes

; TCP flags
TCP_FIN   equ 0x01
TCP_SYN   equ 0x02
TCP_RST   equ 0x04
TCP_PSH   equ 0x08
TCP_ACK   equ 0x10
TCP_URG   equ 0x20
TCP_ECE   equ 0x40
TCP_CWR   equ 0x80

; ==================================================================
; TCP connection states
; ==================================================================
TCP_CLOSED      equ 0
TCP_SYN_SENT    equ 1
TCP_SYN_RCVD    equ 2
TCP_ESTABLISHED equ 3
TCP_FIN_WAIT_1  equ 4
TCP_FIN_WAIT_2  equ 5
TCP_TIME_WAIT   equ 6
TCP_CLOSE_WAIT  equ 7
TCP_LAST_ACK    equ 8

; ==================================================================
; TCP connection table — connection structure offsets
; Each entry: TCP_CONN_SIZE bytes
; ==================================================================
TCP_CONN_STATE     equ 0   ; u32 state
TCP_CONN_SRC_IP    equ 4   ; u32 local IP
TCP_CONN_DST_IP    equ 8   ; u32 remote IP
TCP_CONN_SRC_PORT  equ 12  ; u16 local port
TCP_CONN_DST_PORT  equ 14  ; u16 remote port
TCP_CONN_ISS       equ 16  ; u32 initial send sequence number
TCP_CONN_IRS       equ 20  ; u32 initial receive sequence number
TCP_CONN_SND_NXT   equ 24  ; u32 next sequence number to send
TCP_CONN_RCV_NXT   equ 28  ; u32 next sequence number expected
TCP_CONN_SND_WND   equ 32  ; u16 send window
TCP_CONN_RCV_WND   equ 34  ; u16 receive window
TCP_CONN_MSS       equ 36  ; u16 max segment size
TCP_CONN_RX_LEN    equ 38  ; u32 bytes in rx buffer
TCP_CONN_TX_LEN    equ 42  ; u32 bytes in tx buffer
TCP_CONN_RX_BUF    equ 46  ; 1460 bytes receive buffer
TCP_CONN_TX_BUF    equ 1506 ; 1460 bytes transmit buffer
TCP_CONN_SIZE      equ 2966

; Max concurrent TCP connections
TCP_MAX_CONNS      equ 4

; ==================================================================
; ARP cache — entry offsets
; ==================================================================
ARP_ENTRY_IP    equ 0   ; u32 IP address
ARP_ENTRY_MAC   equ 4   ; 6 bytes MAC address
ARP_ENTRY_VALID equ 10  ; u8 valid flag
ARP_ENTRY_SIZE  equ 11

ARP_CACHE_SIZE  equ 16  ; entries

; ==================================================================
; Default ports and constants
; ==================================================================
EPHEMERAL_PORT_START equ 49152

; Ethernet MTU (max payload)
ETHERNET_MTU   equ 1500
ETHERNET_MIN   equ 60   ; minimum frame size (padded)

; TCP MSS (MTU - IP header - TCP header)
TCP_DEFAULT_MSS equ 1460  ; 1500 - 20 - 20

; Network error codes (extending wasm_defines.inc)
ERROR_NET_UNREACHABLE equ 30
ERROR_NET_RESET       equ 31
ERROR_NET_TIMEDOUT    equ 32
ERROR_TCP_CLOSED      equ 33
ERROR_NET_NOROUTE     equ 34
ERROR_ARP_PENDING     equ 35

; ==================================================================
; HTTP client error codes
; ==================================================================
ERROR_HTTP_PARSE     equ 40
ERROR_HTTP_TIMEOUT   equ 41
ERROR_HTTP_CLOSED    equ 42
ERROR_HTTP_NORESP    equ 43

; ==================================================================
; TCP pseudo-header for checksum calculation
; Layout (12 bytes):
;   src_ip    u32
;   dst_ip    u32
;   zero      u8
;   protocol  u8
;   tcp_len   u16
; ==================================================================
TCP_PSEUDO_SIZE equ 12    ; total size of pseudo-header
TCP_PSEUDO_SRC  equ 0     ; 4 bytes
TCP_PSEUDO_DST  equ 4     ; 4 bytes
TCP_PSEUDO_ZERO equ 8     ; 1 byte
TCP_PSEUDO_PROT equ 9     ; 1 byte
TCP_PSEUDO_LEN  equ 10    ; 2 bytes — length field offset within pseudo-hdr

; ==================================================================
; NIC driver abstraction — function pointer table offsets
; ==================================================================
NIC_TRANSMIT equ 0   ; qword — er_net_transmit_fn(frame_ptr, len) -> rax=0 ok, rdx=error
NIC_RECEIVE  equ 8   ; qword — er_net_receive_fn(buf_ptr, len_ptr) -> rax=0 ok, rdx=error
NIC_MAC      equ 16  ; 6 bytes
NIC_SIZE     equ 22

; ==================================================================
; IP config block (BSS) offsets
; ==================================================================
IP_CFG_ADDR    equ 0   ; u32 local IP
IP_CFG_NETMASK equ 4   ; u32 netmask
IP_CFG_GATEWAY equ 8   ; u32 gateway IP
IP_CFG_MAC     equ 12  ; 6 bytes MAC
IP_CFG_DHCP    equ 18  ; u8 dhcp flag
IP_CFG_SIZE    equ 19
