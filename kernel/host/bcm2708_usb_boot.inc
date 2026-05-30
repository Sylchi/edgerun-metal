; BCM2708 USB boot protocol — host-side constants and helpers.
; Ported from edgerun-zig/src/bcm2708_usb_boot.zig
; Target: x86_64 Linux userspace assembly
;
; The BCM2708 boot ROM exposes a vendor-specific USB interface (class 0xff, subclass 0, protocol 0)
; at endpoint 0x01 out / 0x82 in (bulk, 64-byte packets).  Communication proceeds in two phases:
;
;   Phase 1 (first-stage boot):
;     1. USB control vendor-out write (bRequest=0) with payload length in wValue/wIndex
;     2. One or more USB bulk OUT transfers containing the 24-byte header + bootcode image
;     3. USB control vendor-in read to get the 4-byte return code
;
;   Phase 2 (file server):
;     The second-stage bootloader re-enumerates with serial_index=1 instead of 0/3.
;     It sends file requests via control vendor-in reads, and the host responds with
;     file sizes (control vendor-out with length) or file data (control vendor-out + bulk).

; ---- protocol constants ----
%define BCM_ABI_VERSION              1
%define BCM_VENDOR_ID                0x0a5c
%define BCM_PRODUCT_ID_FIRST         0x2763  ; MSD / first-stage boot
%define BCM_PRODUCT_ID_SECOND        0x2764  ; file server (not always used)
%define BCM_INTERFACE_CLASS_VENDOR   0xff
%define BCM_INTERFACE_SUBCLASS       0
%define BCM_INTERFACE_PROTOCOL       0
%define BCM_ENDPOINT_OUT             0x01
%define BCM_ENDPOINT_IN              0x82
%define BCM_ENDPOINT_ATTR_BULK       0x02
%define BCM_PACKET_BYTES             64
%define BCM_MAX_BULK_BYTES           16384
%define BCM_SIGNATURE_BYTES          20
%define BCM_SECOND_STAGE_HEADER_BYTES 24
%define BCM_CONTROL_VENDOR_OUT       0x40
%define BCM_CONTROL_VENDOR_IN        0xc0
%define BCM_CONTROL_REQUEST          0
%define BCM_RETURN_CODE_BYTES        4

; File server protocol
%define BCM_FILE_CMD_GET_SIZE        0
%define BCM_FILE_CMD_READ            1
%define BCM_FILE_CMD_DONE            2
%define BCM_FILE_NAME_BYTES          256
%define BCM_FILE_MESSAGE_BYTES       260  ; 4 + 256

; ---- helpers (x86_64 Linux userspace) ----
; Linux usbfs ioctl numbers
%define USBDEVFS_CONTROL             0xc0185500
%define USBDEVFS_BULK                0xc0185502
%define USBDEVFS_CLAIM_INTERFACE     0x8004550f
%define USBDEVFS_RELEASE_INTERFACE   0x80045510

; Syscall numbers (x86_64 Linux)
%define SYS_openat                   257
%define SYS_read                     0
%define SYS_write                    1
%define SYS_close                    3
%define SYS_ioctl                    16
%define SYS_nanosleep                35
%define SYS_mmap                     9
%define SYS_munmap                   11
%define SYS_exit_group               231
%define SYS_open                     2

; AT_FDCWD for openat
%define AT_FDCWD                     -100

; mmap flags
%define PROT_READ                    1
%define MAP_PRIVATE                  2

; ---- structs (layouts) ----
; struct usbdevfs_ctrltransfer {
;     u8   request_type;     // +0
;     u8   request;           // +1
;     u16  value;             // +2
;     u16  index;             // +4
;     u16  length;            // +6
;     u32  timeout;           // +8
;     void *data;             // +12  (on 64-bit: +16 on the wire, but Linux packs
;                                     this as 8+4=12 then a pointer... actually:
;                                     request_type(1) + request(1) + value(2) + index(2)
;                                     + length(2) + timeout(4) + padding(0) + data(8) = 20)
; };
; Linux kernel actually packs it as: 1+1+2+2+2+4+8 = 20 bytes
%define USBCTRL_REQUEST_TYPE        0
%define USBCTRL_REQUEST             1
%define USBCTRL_VALUE               2
%define USBCTRL_INDEX               4
%define USBCTRL_LENGTH              6
%define USBCTRL_TIMEOUT             8
%define USBCTRL_DATA                12
%define USBCTRL_SIZE                20

; struct usbdevfs_bulktransfer {
;     unsigned int endpoint;   // +0
;     unsigned int len;        // +4
;     unsigned int timeout;    // +8
;     void *data;              // +12
; };
%define USBBULK_ENDPOINT            0
%define USBBULK_LEN                 4
%define USBBULK_TIMEOUT             8
%define USBBULK_DATA                12
%define USBBULK_SIZE                20

; ---- macros ----
; Build a file request message at a given buffer
; Args: buf_reg (rdi), cmd_reg (esi), name_reg (rsi for string ptr)
; Uses: rax, rcx, rdx, r8, r9, r10, r11
; Returns: nothing
%macro bcm_build_file_request 0
    ; command (4 bytes little-endian at [buf])
    mov     [rdi], esi
    ; copy name string to buf+4 (null-terminated, up to 255 bytes)
    lea     r9, [rdi + 4]
    xor     r10d, r10d
.%%copy_name:
    cmp     r10b, 255
    jae     .%%done_name
    mov     al, [rsi + r10]
    test    al, al
    jz      .%%done_name
    mov     [r9 + r10], al
    inc     r10
    jmp     .%%copy_name
.%%done_name:
    ; ensure null terminator
    mov     byte [r9 + r10], 0
%endmacro

; Build a second-stage header
; Args: bootcode_size (esi), buffer (rdi), optional signature (rdx or 0)
; Uses: rax, rcx, r10, r11
%macro bcm_build_second_stage_header 0
    ; bytes 0-3: bootcode size (LE32)
    mov     [rdi], esi
    ; bytes 4-23: signature (20 bytes, zero if rdx is NULL)
    test    rdx, rdx
    jnz     .%%with_sig
    xor     eax, eax
    mov     [rdi + 4], eax
    mov     [rdi + 8], eax
    mov     [rdi + 12], eax
    mov     [rdi + 16], eax
    mov     [rdi + 20], eax
    jmp     .%%done
.%%with_sig:
    ; copy 20 bytes from [rdx] to [rdi+4]
    lea     r10, [rdi + 4]
    mov     r11, rdx
    mov     ecx, 20
    rep movsb
.%%done:
%endmacro

; Decode a file request from a 260-byte message buffer
; Args: buf (rdi)
; Returns: eax = command, [buf+4..] = name (null-terminated)
; No error checking — caller validates.
%macro bcm_decode_file_request 0
    mov     eax, [rdi]          ; command (LE32)
%endmacro
