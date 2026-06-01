; ESP32 serial boot protocol — host-side constants and helpers.
; Target: x86_64 Linux userspace assembly
;
; The ESP32 ROM bootloader communicates over UART at 115200 baud (auto-detected).
; The protocol uses SLIP framing with 0xC0 delimiters.
;
; Boot flow:
;   1. Reset device into download mode (GPIO0 low, EN pulse via RTS/DTR)
;   2. Send SYNC frames until valid response received
;   3. (Optional) Upload stub loader via MEM_BEGIN/DATA/END
;   4. Download code via MEM_BEGIN/MEM_DATA/MEM_END (RAM) or
;      FLASH_BEGIN/FLASH_DATA/FLASH_END (SPI flash)
;   5. Execute via MEM_END with execute_flag=1 + entry point

; ---- SLIP framing ----
%define SLIP_END                 0xC0
%define SLIP_ESC                 0xDB
%define SLIP_ESC_END            0xDC    ; escaped 0xC0
%define SLIP_ESC_ESC            0xDD    ; escaped 0xDB

; ---- Packet header layout ----
; Command/response packet (8-byte header + variable data):
;   [0]   direction   (0x00 = request, 0x01 = response)
;   [1]   command     (command identifier)
;   [2-3] size        (length of data field, little-endian)
;   [4-7] checksum    (xor checksum, little-endian, 0 for most commands)
;   [8..] data        (variable length)
%define PKT_DIRECTION           0
%define PKT_COMMAND             1
%define PKT_SIZE                2
%define PKT_CHECKSUM            4
%define PKT_DATA                8
%define PKT_HEADER_BYTES        8

; Direction values
%define DIR_REQUEST             0x00
%define DIR_RESPONSE            0x01

; ---- ROM bootloader commands ----
%define CMD_FLASH_BEGIN         0x02
%define CMD_FLASH_DATA          0x03
%define CMD_FLASH_END           0x04
%define CMD_MEM_BEGIN           0x05
%define CMD_MEM_END             0x06
%define CMD_MEM_DATA            0x07
%define CMD_SYNC                0x08
%define CMD_WRITE_REG           0x09
%define CMD_READ_REG            0x0A
%define CMD_SPI_SET_PARAMS      0x0B
%define CMD_SPI_ATTACH          0x0D
%define CMD_CHANGE_BAUDRATE     0x0F
%define CMD_FLASH_DEFL_BEGIN    0x10
%define CMD_FLASH_DEFL_DATA     0x11
%define CMD_FLASH_DEFL_END      0x12
%define CMD_SPI_FLASH_MD5       0x13

; Stub-only commands (ROM returns error)
%define CMD_ERASE_FLASH         0xD0
%define CMD_ERASE_REGION        0xD1
%define CMD_READ_FLASH          0xD2
%define CMD_RUN_USER_CODE       0xD3

; ---- SYNC data ----
; SYNC payload: 4 bytes header + 32 bytes of 0x55
%define SYNC_HEADER_BYTES       4
%define SYNC_PATTERN_BYTES      32
%define SYNC_TOTAL_BYTES        36      ; 4 + 32
%define SYNC_MAGIC_BYTE1        0x07
%define SYNC_MAGIC_BYTE2        0x07
%define SYNC_MAGIC_BYTE3        0x12
%define SYNC_MAGIC_BYTE4        0x20
%define SYNC_FILL_BYTE          0x55

; Number of sync attempts before giving up
%define SYNC_RETRIES            200

; ---- MEM_BEGIN parameters (for RAM download) ----
; Data payload: 4 x 32-bit words
;   [0] total_size       ; total bytes to download
;   [1] num_packets      ; number of data packets
;   [2] packet_size      ; max bytes per data packet
;   [3] memory_offset    ; destination address in RAM
%define MEM_BEGIN_TOTAL_SIZE    0
%define MEM_BEGIN_NUM_PACKETS   4
%define MEM_BEGIN_PACKET_SIZE   8
%define MEM_BEGIN_MEM_OFFSET    12
%define MEM_BEGIN_DATA_BYTES    16

; ---- MEM_DATA parameters ----
; Data payload: 4 x 32-bit words + raw data
;   [0] data_size        ; bytes of data in this packet
;   [1] sequence_num     ; 0-based sequence number
;   [2-3] reserved       ; zero
;   [16..] data          ; raw data to write
%define MEM_DATA_SIZE            0
%define MEM_DATA_SEQUENCE        4
%define MEM_DATA_HEADER_BYTES    16

; ---- MEM_END parameters ----
; Data payload: 2 x 32-bit words
;   [0] execute_flag     ; 0 = stay in loader, 1 = execute
;   [1] entry_point      ; address to jump to
%define MEM_END_EXECUTE_FLAG    0
%define MEM_END_ENTRY_POINT     4
%define MEM_END_DATA_BYTES      8

; ---- FLASH_BEGIN parameters ----
; Data payload: 4 x 32-bit words
;   [0] total_size       ; total bytes to write
;   [1] num_packets      ; number of data packets
;   [2] packet_size      ; max bytes per data packet
;   [3] flash_offset     ; SPI flash destination offset
%define FLASH_BEGIN_TOTAL_SIZE  0
%define FLASH_BEGIN_NUM_PACKETS 4
%define FLASH_BEGIN_PACKET_SIZE 8
%define FLASH_BEGIN_OFFSET      12
%define FLASH_BEGIN_DATA_BYTES  16

; ---- FLASH_DATA parameters ----
; Data payload: 4 x 32-bit words + raw data
;   [0] data_size        ; bytes of data in this packet
;   [1] sequence_num     ; 0-based sequence number
;   [2-3] reserved       ; zero
;   [16..] data          ; raw bytes to write
%define FLASH_DATA_SIZE         0
%define FLASH_DATA_SEQUENCE     4
%define FLASH_DATA_HEADER_BYTES 16

; ---- FLASH_END parameters ----
; Data payload: 1 x 32-bit word
;   [0] reboot_flag      ; 0 = reboot after write, 1 = stay in loader
%define FLASH_END_REBOOT_FLAG   0
%define FLASH_END_DATA_BYTES    4

; ---- Default values ----
%define ESP_DEFAULT_BAUD        115200
%define ESP_MEM_PACKET_SIZE     16384   ; 16KB per packet (fits in IRAM)
%define ESP_FLASH_PACKET_SIZE   1024    ; ROM flash block size
%define ESP_DEFAULT_FLASH_OFF   0x00010000
%define ESP32S3_IRAM_ENTRY      0x40374000
%define ESP_SYNC_TIMEOUT_MS     100
%define ESP_RESPONSE_TIMEOUT_MS 3000

; ---- Response status ----
; Response data ends with 2 status bytes (stub) or 4 (ROM):
;   [N-2] status         ; 0 = success, 1 = failure
;   [N-1] error          ; error code (if status == 1)
%define RESP_STATUS_OFFSET_LSB  -2
%define RESP_ERROR_OFFSET_LSB   -1

; Status values
%define STATUS_SUCCESS          0
%define STATUS_FAILURE          1

; ---- ROM loader error codes ----
%define ERR_UNDEFINED           0x00
%define ERR_INVALID_PARAM       0x01
%define ERR_MALLOC_FAILED       0x02
%define ERR_SEND_FAILED         0x03
%define ERR_RECV_FAILED         0x04
%define ERR_INVALID_FORMAT      0x05
%define ERR_RUN_RESULT          0x06
%define ERR_CHECKSUM            0x07
%define ERR_FLASH_WRITE         0x08
%define ERR_FLASH_READ          0x09
%define ERR_FLASH_READ_LEN      0x0A
%define ERR_DEFLATE             0x0B
%define ERR_DEFLATE_ADLER32     0x0C
%define ERR_DEFLATE_PARAM       0x0D
%define ERR_INVALID_RAM_SIZE    0x0E
%define ERR_INVALID_RAM_ADDR    0x0F

; ---- Checksum ----
; XOR-based checksum used for MEM_DATA and FLASH_DATA.
; Algorithm: start with seed 0xEF, XOR each data byte.
%define CHECKSUM_SEED           0xEF

; Compute XOR checksum of a buffer
; Args: rdi = buffer, esi = length
; Returns: al = checksum byte
; Clobbers: rcx, rdx, rsi, rdi
%macro checksum_compute 0
    xor     eax, eax
    mov     al, CHECKSUM_SEED
    test    esi, esi
    jz      .%%done
    xor     ecx, ecx
.%%loop:
    mov     dl, [rdi + rcx]
    xor     al, dl
    inc     ecx
    cmp     ecx, esi
    jb      .%%loop
.%%done:
%endmacro

; ---- Linux serial port ioctl numbers ----
; termios2 ioctls (use these instead of termios for speed_t)
%define TCGETS2                 0x802C542A
%define TCSETS2                 0x402C542B

; termios2 struct layout (44 bytes, Linux x86_64)
; struct termios2 {
;     tcflag_t c_iflag;    // +0  (4 bytes)
;     tcflag_t c_oflag;    // +4  (4 bytes)
;     tcflag_t c_cflag;    // +8  (4 bytes)
;     tcflag_t c_lflag;    // +12 (4 bytes)
;     cc_t     c_line;     // +16 (1 byte)
;     cc_t     c_cc[19];   // +17 (19 bytes)
;     speed_t  c_ispeed;   // +36 (4 bytes)
;     speed_t  c_ospeed;   // +40 (4 bytes)
; };
%define TERMIO2_IFLAG           0
%define TERMIO2_OFLAG           4
%define TERMIO2_CFLAG           8
%define TERMIO2_LFLAG           12
%define TERMIO2_LINE            16
%define TERMIO2_CC              17
%define TERMIO2_ISPEED          36
%define TERMIO2_OSPEED          40
%define TERMIO2_SIZE            44

; c_cflag bitmasks
%define C_CSIZE                 0x00000030
%define   CS5                   0x00000000
%define   CS6                   0x00000010
%define   CS7                   0x00000020
%define   CS8                   0x00000030
%define CSTOPB                  0x00000040
%define CREAD                   0x00000080
%define PARENB                  0x00000100
%define PARODD                  0x00000200
%define HUPCL                   0x00000400
%define CLOCAL                  0x00000800

; c_iflag bitmasks
%define IGNBRK                  0x00000001
%define BRKINT                  0x00000002
%define IGNPAR                  0x00000004
%define PARMRK                  0x00000008
%define INPCK                   0x00000010
%define ISTRIP                  0x00000020
%define INLCR                   0x00000040
%define IGNCR                   0x00000080
%define ICRNL                   0x00000100

; c_lflag bitmasks
%define ISIG                    0x00000001
%define ICANON                  0x00000002
%define ECHO                    0x00000008
%define ECHOE                   0x00000010
%define ECHOK                   0x00000020
%define ECHONL                  0x00000040

; c_cc indices
%define VMIN                    4
%define VTIME                   5

; Baud rate constants for termios2 (matching Linux kernel asm/termbits.h)
%define B0                      0
%define B9600                   13
%define B19200                  14
%define B38400                  15
%define B57600                  16
%define B115200                 17
%define B230400                 18
%define B460800                 19
%define B921600                 20

; ---- RTS/DTR control ----
; Serial port ioctls for modem control
%define TIOCMGET                0x5415
%define TIOCMSET                0x5418
%define TIOCM_DTR               0x002
%define TIOCM_RTS               0x004

; Serial port open flags
%define O_RDWR                  0x0002
%define O_NOCTTY                0x0080
%define O_NDELAY                0x0800

; ---- Syscall numbers (x86_64 Linux) ----
%define SYS_read                0
%define SYS_write               1
%define SYS_open                2
%define SYS_close               3
%define SYS_ioctl               16
%define SYS_nanosleep           35
%define SYS_openat              257

; ---- Helper: SLIP-encode a buffer into another buffer ----
; Args: src (rdi), src_len (esi), dst (rdx)
; Returns: rax = encoded length
; Clobbers: rcx, r8, r9
; Encodes [src] of [src_len] bytes into [dst] with SLIP escaping.
; Caller must ensure dst has enough space (approx src_len * 2 + 2).
%macro slip_encode 0
    xor     eax, eax
    mov     byte [rdx], SLIP_END          ; leading END
    inc     eax
    inc     rdx
    xor     ecx, ecx
.%%loop:
    cmp     ecx, esi
    jae     .%%done
    mov     r8b, [rdi + rcx]
    cmp     r8b, SLIP_END
    je      .%%esc_end
    cmp     r8b, SLIP_ESC
    je      .%%esc_esc
    mov     [rdx], r8b
    inc     eax
    inc     rdx
    inc     ecx
    jmp     .%%loop
.%%esc_end:
    mov     byte [rdx], SLIP_ESC
    mov     byte [rdx + 1], SLIP_ESC_END
    add     eax, 2
    add     rdx, 2
    inc     ecx
    jmp     .%%loop
.%%esc_esc:
    mov     byte [rdx], SLIP_ESC
    mov     byte [rdx + 1], SLIP_ESC_ESC
    add     eax, 2
    add     rdx, 2
    inc     ecx
    jmp     .%%loop
.%%done:
    mov     byte [rdx], SLIP_END          ; trailing END
    inc     eax
%endmacro

; ---- Helper: SLIP-decode a buffer (in-place) ----
; Args: buf (rdi), len (esi)
; Returns: eax = decoded length, carry = 0 on success, 1 on error
; Decodes a SLIP packet at [rdi] of [esi] bytes in-place.
; Strips leading/trailing 0xC0 and unescapes.
; On success, rax = decoded payload length, decoded data at [rdi].
%macro slip_decode 0
    xor     eax, eax
    xor     ecx, ecx
    xor     r8d, r8d
    ; Skip leading END bytes
.%%skip_lead:
    cmp     ecx, esi
    jae     .%%error
    cmp     byte [rdi + rcx], SLIP_END
    jne     .%%decode_body
    inc     ecx
    jmp     .%%skip_lead
.%%decode_body:
    cmp     ecx, esi
    jae     .%%done
    mov     r9b, [rdi + rcx]
    cmp     r9b, SLIP_END
    je      .%%done                     ; trailing END found
    cmp     r9b, SLIP_ESC
    jne     .%%copy
    ; Escape sequence: read next byte
    inc     ecx
    cmp     ecx, esi
    jae     .%%error
    mov     r9b, [rdi + rcx]
    cmp     r9b, SLIP_ESC_END
    je      .%%copy_end
    cmp     r9b, SLIP_ESC_ESC
    je      .%%copy_esc
    jmp     .%%error
.%%copy_end:
    mov     r9b, SLIP_END
    jmp     .%%copy
.%%copy_esc:
    mov     r9b, SLIP_ESC
.%%copy:
    mov     [rdi + r8], r9b
    inc     r8
    inc     ecx
    jmp     .%%decode_body
.%%done:
    mov     eax, r8d
    clc
    jmp     .%%out
.%%error:
    stc
.%%out:
%endmacro

; ---- Helper: build MEM_BEGIN payload ----
; Args: buf (rdi), total_size (esi), num_packets (edx), packet_size (ecx), mem_offset (r8d)
; Uses: eax
%macro build_mem_begin 0
    mov     [rdi + MEM_BEGIN_TOTAL_SIZE], esi
    mov     [rdi + MEM_BEGIN_NUM_PACKETS], edx
    mov     [rdi + MEM_BEGIN_PACKET_SIZE], ecx
    mov     [rdi + MEM_BEGIN_MEM_OFFSET], r8d
%endmacro

; ---- Helper: build MEM_END payload ----
; Args: buf (rdi), execute_flag (esi), entry_point (edx)
%macro build_mem_end 0
    mov     [rdi + MEM_END_EXECUTE_FLAG], esi
    mov     [rdi + MEM_END_ENTRY_POINT], edx
%endmacro
