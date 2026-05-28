; EdgeRun CMOS/RTC NVRAM driver — x86_64 assembly
; System V AMD64 ABI
; Freestanding — no libc, no external dependencies.
;
; Standard PC CMOS at I/O ports 0x70 (index) / 0x71 (data).
; 128 bytes NVRAM (some reserved for RTC). RTC time/date registers.
; Bit 7 of the index register disables NMI when set.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"

; CMOS/RTC register addresses
%define CMOS_RTC_SEC        0x00
%define CMOS_RTC_SEC_ALRM   0x01
%define CMOS_RTC_MIN        0x02
%define CMOS_RTC_MIN_ALRM   0x03
%define CMOS_RTC_HOUR       0x04
%define CMOS_RTC_HOUR_ALRM  0x05
%define CMOS_RTC_DAY_WEEK   0x06
%define CMOS_RTC_DAY_MONTH  0x07
%define CMOS_RTC_MONTH      0x08
%define CMOS_RTC_YEAR       0x09
%define CMOS_RTC_STATUS_A   0x0a
%define CMOS_RTC_STATUS_B   0x0b
%define CMOS_RTC_STATUS_C   0x0c
%define CMOS_RTC_STATUS_D   0x0d
%define CMOS_RTC_DIAG       0x0e
%define CMOS_RTC_SHUTDOWN   0x0f
%define CMOS_FLOPPY_DRIVE   0x10
%define CMOS_DISK1_TYPE     0x12
%define CMOS_DISK2_TYPE     0x15
%define CMOS_INSTALLED      0x14
%define CMOS_LOW_MEM        0x15
%define CMOS_HIGH_MEM_LOW   0x16
%define CMOS_HIGH_MEM_HIGH  0x17
%define CMOS_EQUIPMENT      0x14
%define CMOS_BASIC_MEM_LOW  0x15
%define CMOS_BASIC_MEM_HIGH 0x16
%define CMOS_EXT_MEM_LOW    0x17
%define CMOS_EXT_MEM_HIGH   0x18
%define CMOS_CENTURY        0x32

; Status register A bits
%define CMOS_UIP            0x80    ; Update In Progress

; Status register B bits
%define CMOS_24HR           0x02    ; 24-hour mode
%define CMOS_BINARY         0x04    ; Binary (not BCD) mode

; Index control — bit 7 disables NMI
%define CMOS_NMI_DISABLE    0x80
%define CMOS_NMI_ENABLE     0x00

; NVRAM user storage range
%define CMOS_NVRAM_START    0x10
%define CMOS_NVRAM_END      0x7f

; HOSTED_TEST shadow buffer (unconditional — small, harmless for kernel)
section .bss
global er_cmos_shadow
er_cmos_shadow: resb 256       ; Simulated CMOS NVRAM (256 bytes)

SECTION .text

; ==================================================================
; CMOS port I/O primitives
; =================================================================
%macro _cmos_out_index 1
    mov     al, %1
    mov     dx, 0x70
    out     dx, al
%endmacro

%macro _cmos_in_data 0
    mov     dx, 0x71
    in      al, dx
%endmacro

%macro _cmos_out_data 1
    mov     al, %1
    mov     dx, 0x71
    out     dx, al
%endmacro

; ==================================================================
; er_cmos_read — read byte from CMOS NVRAM
; uint8_t er_cmos_read(uint8_t index)
; index = register address (0-127), bit 7 disables NMI
; Returns: value read
; =================================================================
er_fn er_cmos_read
    %ifdef HOSTED_TEST
    movzx   eax, dil
    and     eax, 0x7f
    mov     al, [er_cmos_shadow + rax]
    er_ok
    er_ret
    %else
    _cmos_out_index dil
    _cmos_in_data
    er_ok
    er_ret
    %endif

; ==================================================================
; er_cmos_write — write byte to CMOS NVRAM
; void er_cmos_write(uint8_t index, uint8_t value)
; =================================================================
er_fn er_cmos_write
    %ifdef HOSTED_TEST
    movzx   eax, dil
    and     eax, 0x7f
    mov     byte [er_cmos_shadow + rax], sil
    %else
    _cmos_out_index dil
    _cmos_out_data sil
    %endif
    er_ok
    er_ret

; ==================================================================
; er_cmos_read_rtc — read one RTC time register
; uint8_t er_cmos_read_rtc(uint8_t reg)
; reg = RTC register (0x00-0x09)
; Returns: value in BCD (unless STATUS_B has BINARY set)
; Waits for UIP to clear before reading.
; =================================================================
er_fn er_cmos_read_rtc
    push    rcx
    %ifndef HOSTED_TEST
    ; Wait for UIP to clear (indicates RTC update complete)
.wait_uip:
    _cmos_out_index CMOS_RTC_STATUS_A
    _cmos_in_data
    test    al, CMOS_UIP
    jnz     .wait_uip
    %endif

    ; Read requested register
    mov     al, dil
    %ifdef HOSTED_TEST
    and     al, 0x7f
    movzx   eax, al
    mov     al, [er_cmos_shadow + rax]
    %else
    _cmos_out_index al
    _cmos_in_data
    %endif
    pop     rcx
    er_ok
    er_ret

; ==================================================================
; er_cmos_bcd_to_bin — convert BCD byte to binary
; uint8_t er_cmos_bcd_to_bin(uint8_t bcd)
; =================================================================
er_fn er_cmos_bcd_to_bin
    movzx   eax, dil
    mov     ecx, eax
    shr     ecx, 4
    and     eax, 0x0f
    imul    ecx, 10
    add     eax, ecx
    er_ok
    er_ret

; ==================================================================
; er_cmos_read_time — read RTC time fields
; void er_cmos_read_time(uint16_t* hours, uint16_t* minutes, uint16_t* seconds)
; rdi = &hours, rsi = &minutes, rdx = &seconds
; Returns values in binary (converted from BCD if needed)
; =================================================================
er_fn er_cmos_read_time
    push    r8
    push    r9
    push    r10
    push    r12
    push    r13
    push    r14

    mov     r12, rdi            ; &hours
    mov     r13, rsi            ; &minutes
    mov     r14, rdx            ; &seconds

    ; Read RTC registers (BCD by default)
    mov     dil, CMOS_RTC_HOUR
    call    er_cmos_read_rtc
    mov     r8b, al
    mov     dil, CMOS_RTC_MIN
    call    er_cmos_read_rtc
    mov     r9b, al
    mov     dil, CMOS_RTC_SEC
    call    er_cmos_read_rtc
    mov     r10b, al

    ; Check if binary mode
    mov     dil, CMOS_RTC_STATUS_B
    call    er_cmos_read
    test    al, CMOS_BINARY
    jnz     .store

    ; Convert BCD to binary
    movzx   edi, r8b
    call    er_cmos_bcd_to_bin
    mov     r8b, al
    movzx   edi, r9b
    call    er_cmos_bcd_to_bin
    mov     r9b, al
    movzx   edi, r10b
    call    er_cmos_bcd_to_bin
    mov     r10b, al

.store:
    movzx   eax, r8b
    mov     [r12], ax
    movzx   eax, r9b
    mov     [r13], ax
    movzx   eax, r10b
    mov     [r14], ax

    pop     r14
    pop     r13
    pop     r12
    pop     r10
    pop     r9
    pop     r8
    er_ok
    er_ret

; ==================================================================
; er_cmos_read_date — read RTC date fields
; void er_cmos_read_date(uint16_t* year, uint16_t* month, uint16_t* day)
; rdi = &year, rsi = &month, rdx = &day
; =================================================================
er_fn er_cmos_read_date
    push    r8
    push    r9
    push    r10
    push    r12
    push    r13
    push    r14

    mov     r12, rdi            ; &year
    mov     r13, rsi            ; &month
    mov     r14, rdx            ; &day

    mov     dil, CMOS_RTC_YEAR
    call    er_cmos_read_rtc
    mov     r8b, al
    mov     dil, CMOS_RTC_MONTH
    call    er_cmos_read_rtc
    mov     r9b, al
    mov     dil, CMOS_RTC_DAY_MONTH
    call    er_cmos_read_rtc
    mov     r10b, al

    ; Check if binary mode
    mov     dil, CMOS_RTC_STATUS_B
    call    er_cmos_read
    test    al, CMOS_BINARY
    jnz     .store

    movzx   edi, r8b
    call    er_cmos_bcd_to_bin
    mov     r8b, al
    movzx   edi, r9b
    call    er_cmos_bcd_to_bin
    mov     r9b, al
    movzx   edi, r10b
    call    er_cmos_bcd_to_bin
    mov     r10b, al

.store:
    ; Add century (2000 for this millennium)
    movzx   eax, r8b
    add     eax, 2000
    mov     [r12], ax
    movzx   eax, r9b
    mov     [r13], ax
    movzx   eax, r10b
    mov     [r14], ax

    pop     r14
    pop     r13
    pop     r12
    pop     r10
    pop     r9
    pop     r8
    er_ok
    er_ret
