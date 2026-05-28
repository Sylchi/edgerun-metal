; EdgeRun I2C HID protocol driver — x86_64 assembly
; System V AMD64 ABI
; Freestanding — no libc, no external dependencies.
;
; Implements the I2C HID protocol specification for HID devices
; connected over I2C (touchpads, keyboards, etc.).
;
; The I2C HID protocol uses 16-bit register addresses and a standard
; combined write-then-read I2C transfer to access registers.

%include "x86_64/macros.inc"
%include "x86_64/wasm_constants.inc"

extern er_dw_i2c_xfer

; I2C HID register addresses
%define I2C_HID_REG_DESC        0x01

; HID descriptor field offsets (in bytes from descriptor base)
%define HID_DESC_LENGTH         0
%define HID_DESC_BCD_VERSION    2
%define HID_DESC_REPDESC_LEN    4
%define HID_DESC_REPDESC_REG    6
%define HID_DESC_INPUT_REG      8
%define HID_DESC_MAX_INPUT_LEN  10
%define HID_DESC_OUTPUT_REG     12
%define HID_DESC_MAX_OUTPUT_LEN 14
%define HID_DESC_CMD_REG        16
%define HID_DESC_DATA_REG       18
%define HID_DESC_VID            20
%define HID_DESC_PID            22
%define HID_DESC_VERSION        24
%define HID_DESC_RESERVED       26

%define HID_DESC_SIZE           30

; I2C HID commands
%define HID_CMD_RESET           0x01
%define HID_CMD_SET_POWER       0x02

; Power states
%define HID_POWER_ON            0x01
%define HID_POWER_OFF           0x00

%define HID_DESC_EXPECTED_LEN   30

; ─── HOSTED_TEST shadow ──────────────────────────────────────────
%ifdef HOSTED_TEST
section .bss
global er_i2c_hid_desc
er_i2c_hid_desc: resb HID_DESC_SIZE
global er_i2c_hid_probed
er_i2c_hid_probed: resq 1
%endif

SECTION .text

; ==================================================================
; _i2c_hid_read_desc — read HID descriptor via I2C combined transfer
; int _i2c_hid_read_desc(uint64_t mmio_base, uint8_t i2c_addr,
;                        uint8_t* buf)
; ==================================================================
er_fn _i2c_hid_read_desc
    push    r12
    push    r13
    push    r14
    mov     r12, rdi
    mov     r13b, sil
    mov     r14, rdx

%ifndef HOSTED_TEST
    sub     rsp, 8
    mov     word [rsp], I2C_HID_REG_DESC

    mov     rdi, r12
    movzx   esi, r13b
    lea     rdx, [rsp]
    mov     ecx, 2
    mov     r8, r14
    mov     r9d, HID_DESC_SIZE
    call    er_dw_i2c_xfer
    test    edx, edx
    jnz     .fail_read

    add     rsp, 8
%endif
    xor     eax, eax
    pop     r14
    pop     r13
    pop     r12
    er_ok
    er_ret

.fail_read:
    add     rsp, 8
    xor     eax, eax
    pop     r14
    pop     r13
    pop     r12
    er_ret                      ; rdx has error from er_dw_i2c_xfer

; ==================================================================
; _i2c_hid_write_cmd — write 16-bit command to command register
; int _i2c_hid_write_cmd(uint64_t mmio_base, uint8_t i2c_addr,
;                        uint16_t cmd_reg, uint16_t cmd_val)
; ==================================================================
er_fn _i2c_hid_write_cmd
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12, rdi
    mov     r13b, sil
    mov     r14d, edx
    mov     r15d, ecx

%ifndef HOSTED_TEST
    sub     rsp, 4
    mov     word [rsp], r14w
    mov     word [rsp + 2], r15w

    mov     rdi, r12
    movzx   esi, r13b
    lea     rdx, [rsp]
    mov     ecx, 4
    xor     r8, r8
    xor     r9d, r9d
    call    er_dw_i2c_xfer
    test    edx, edx
    jnz     .fail_cmd

    add     rsp, 4
%endif
    xor     eax, eax
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    er_ok
    er_ret

.fail_cmd:
    add     rsp, 4
    xor     eax, eax
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    er_ret                      ; rdx has error from er_dw_i2c_xfer

; ==================================================================
; _i2c_hid_read_reg16 — read 16-bit value from a register
; uint32_t _i2c_hid_read_reg16(uint64_t mmio_base, uint8_t i2c_addr,
;                              uint16_t reg)
; Returns: eax = 16-bit value, or -1 on failure
; ==================================================================
er_fn _i2c_hid_read_reg16
    push    r12
    push    r13
    push    r14
    mov     r12, rdi
    mov     r13b, sil
    mov     r14d, edx

%ifndef HOSTED_TEST
    sub     rsp, 6
    mov     word [rsp], r14w

    mov     rdi, r12
    movzx   esi, r13b
    lea     rdx, [rsp]
    mov     ecx, 2
    lea     r8, [rsp + 4]
    mov     r9d, 2
    call    er_dw_i2c_xfer
    test    edx, edx
    jnz     .fail_reg16

    movzx   eax, word [rsp + 4]
    add     rsp, 6
    pop     r14
    pop     r13
    pop     r12
    er_ok
    er_ret

.fail_reg16:
    add     rsp, 6
%endif
    xor     eax, eax
    pop     r14
    pop     r13
    pop     r12
    er_ret                      ; rdx has error from er_dw_i2c_xfer

; ==================================================================
; er_i2c_hid_probe — probe and reset an I2C HID device
; int er_i2c_hid_probe(uint64_t mmio_base, uint8_t i2c_addr,
;                      uint16_t* out_vid, uint16_t* out_pid)
; Returns: eax = 0 on success (device found), -1 on failure
; ==================================================================
er_fn er_i2c_hid_probe
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12, rdi
    mov     r13b, sil
    mov     r14, rdx
    mov     r15, rcx

    sub     rsp, HID_DESC_SIZE

%ifndef HOSTED_TEST
    mov     rdi, r12
    movzx   esi, r13b
    lea     rdx, [rsp]
    call    _i2c_hid_read_desc
    test    edx, edx
    jnz     .fail_probe

    movzx   eax, word [rsp + HID_DESC_LENGTH]
    cmp     eax, HID_DESC_EXPECTED_LEN
    jne     .fail_probe

    movzx   eax, word [rsp + HID_DESC_VID]
    mov     word [r14], ax
    movzx   eax, word [rsp + HID_DESC_PID]
    mov     word [r15], ax

    movzx   edx, word [rsp + HID_DESC_CMD_REG]

    xor     ecx, ecx
    mov     rdi, r12
    movzx   esi, r13b
    call    _i2c_hid_write_cmd
    test    edx, edx
    jnz     .fail_probe

    mov     ecx, HID_CMD_RESET
    mov     rdi, r12
    movzx   esi, r13b
    call    _i2c_hid_write_cmd
    test    edx, edx
    jnz     .fail_probe

    ; Wait ~10ms
    mov     ecx, 20000000
.reset_wait:
    pause
    dec     ecx
    jnz     .reset_wait

    xor     ecx, ecx
    mov     rdi, r12
    movzx   esi, r13b
    call    _i2c_hid_write_cmd
    test    edx, edx
    jnz     .fail_probe
%endif

    add     rsp, HID_DESC_SIZE
    xor     eax, eax
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    er_ok
    er_ret

.fail_probe:
    add     rsp, HID_DESC_SIZE
    xor     eax, eax
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    er_err  ERROR_IO
    er_ret

; ==================================================================
; er_i2c_hid_set_power — set device power state
; int er_i2c_hid_set_power(uint64_t mmio_base, uint8_t i2c_addr,
;                          uint16_t cmd_reg, uint16_t data_reg,
;                          uint8_t on)
; ==================================================================
er_fn er_i2c_hid_set_power
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12, rdi
    mov     r13b, sil
    mov     r14d, edx
    mov     r15d, ecx
    mov     r8d, r8d

%ifndef HOSTED_TEST
    sub     rsp, 6

    ; Step 1: Write 0x0000 to cmd_reg
    mov     word [rsp], r14w
    mov     word [rsp + 2], 0
    mov     rdi, r12
    movzx   esi, r13b
    lea     rdx, [rsp]
    mov     ecx, 4
    xor     r8, r8
    xor     r9d, r9d
    call    er_dw_i2c_xfer
    test    edx, edx
    jnz     .fail_power

    ; Step 2: Write power state to data_reg
    movzx   eax, r8b
    and     eax, 1
    mov     word [rsp], r15w
    mov     word [rsp + 2], ax
    mov     rdi, r12
    movzx   esi, r13b
    lea     rdx, [rsp]
    mov     ecx, 4
    xor     r8, r8
    xor     r9d, r9d
    call    er_dw_i2c_xfer
    test    edx, edx
    jnz     .fail_power

    ; Step 3: Write SET_POWER to cmd_reg
    mov     word [rsp], r14w
    mov     word [rsp + 2], HID_CMD_SET_POWER
    mov     rdi, r12
    movzx   esi, r13b
    lea     rdx, [rsp]
    mov     ecx, 4
    xor     r8, r8
    xor     r9d, r9d
    call    er_dw_i2c_xfer
    test    edx, edx
    jnz     .fail_power

    ; Step 4: Clear cmd_reg
    mov     word [rsp], r14w
    mov     word [rsp + 2], 0
    mov     rdi, r12
    movzx   esi, r13b
    lea     rdx, [rsp]
    mov     ecx, 4
    xor     r8, r8
    xor     r9d, r9d
    call    er_dw_i2c_xfer
    test    edx, edx
    jnz     .fail_power

    add     rsp, 6
%endif

    xor     eax, eax
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    er_ok
    er_ret

.fail_power:
    add     rsp, 6
    xor     eax, eax
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    er_ret                      ; rdx has error from er_dw_i2c_xfer

; ==================================================================
; er_i2c_hid_read_input — read an input report
; int er_i2c_hid_read_input(uint64_t mmio_base, uint8_t i2c_addr,
;                           uint16_t input_reg, uint16_t max_len,
;                           uint8_t* buf)
; Returns: eax = bytes read, or -1 on failure
; ==================================================================
er_fn er_i2c_hid_read_input
    push    r12
    push    r13
    push    r14
    push    r15
    mov     r12, rdi
    mov     r13b, sil
    mov     r14d, edx
    mov     r15d, ecx
    ; r8 = buf

%ifndef HOSTED_TEST
    sub     rsp, 4
    mov     word [rsp], r14w

    mov     rdi, r12
    movzx   esi, r13b
    lea     rdx, [rsp]
    mov     ecx, 2
    ; r8 already has buf pointer (arg5)
    mov     r9d, r15d
    call    er_dw_i2c_xfer
    test    edx, edx
    jnz     .fail_input

    movzx   eax, word [r8]
    add     rsp, 4
    cmp     eax, r15d
    jbe     .out
    mov     eax, r15d
.out:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    er_ok
    er_ret
%endif

    xor     eax, eax
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    er_ok
    er_ret

.fail_input:
    add     rsp, 4
    xor     eax, eax
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    er_ret                      ; rdx has error from er_dw_i2c_xfer
