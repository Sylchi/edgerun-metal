; EdgeRun Chrome EC (Embedded Controller) driver — x86_64 assembly
; System V AMD64 ABI
; Freestanding — no libc, no external dependencies.
;
; Communicates with the Chrome OS Embedded Controller (cros_ec) found
; on Framework laptops and Chromebooks.
;
; The EC is accessed through the standard ACPI EC interface:
;   Port 0x66 — EC_SC (status/command)
;   Port 0x62 — EC_DATA (data register)
;
; Higher-level Chrome EC host commands use the LPC v3 packet protocol
; over the ACPI EC read/write interface.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"

; ACPI EC I/O ports
%define EC_SC        0x66    ; Status/command
%define EC_DATA      0x62    ; Data

; EC status register bits (read from 0x66)
%define EC_SC_OBF    0x01    ; Output buffer full (data ready to read)
%define EC_SC_IBF    0x02    ; Input buffer full (busy)
%define EC_SC_SCI    0x04    ; SCI event pending
%define EC_SC_SMI    0x08    ; SMI event pending
%define EC_SC_BURST  0x10    ; Burst mode
%define EC_SC_CMD    0x20    ; Last write was command (vs data)

; ACPI EC commands (write to 0x66)
%define EC_CMD_READ      0x80    ; Read EC memory at given offset
%define EC_CMD_WRITE     0x81    ; Write EC memory at given offset
%define EC_CMD_BURST_EN  0x82    ; Enable burst mode
%define EC_CMD_BURST_DIS 0x83    ; Disable burst mode
%define EC_CMD_QUERY     0x84    ; Query for pending event

; Chrome EC shared memory offsets (in EC address space)
%define EC_MEMMAP_HOST_CMD  0x0800  ; Host command packet buffer
%define EC_MEMMAP_OLD_HOST_CMD 0x0200 ; Legacy trigger
%define EC_MEMMAP_TEMP_SENSOR      0x00
%define EC_MEMMAP_FAN              0x10
%define EC_MEMMAP_SWITCHES         0x30
%define EC_MEMMAP_BATT_VOLT        0x40
%define EC_MEMMAP_BATT_RATE        0x44
%define EC_MEMMAP_BATT_CAP         0x48
%define EC_MEMMAP_BATT_FLAG        0x4c
%define EC_MEMMAP_BATT_DCAP        0x50
%define EC_MEMMAP_BATT_DVLT        0x54
%define EC_MEMMAP_BATT_LFCC        0x58
%define EC_MEMMAP_BATT_CCNT        0x5c
%define EC_TEMP_SENSOR_OFFSET      200
%define EC_TEMP_SENSOR_NOT_PRESENT 0xff
%define EC_FAN_SPEED_NOT_PRESENT   0xffff
%define EC_SWITCH_LID_OPEN         0x01

; EC_CMD_HOST_CMD protocol version
%define EC_HOST_CMD_VERSION  0x00

; Timeout for EC operations (spin count)
%define EC_TIMEOUT    1000000

; ─── HOSTED_TEST shadow buffer (unconditional) ────────────────────────
section .bss
global er_ec_shadow
er_ec_shadow: resb 4096        ; Simulated EC memory (offsets 0-4095)
global er_ec_cmd_log, er_ec_cmd_count
er_ec_cmd_log: resb 256        ; Command log
er_ec_cmd_count: resq 1
global er_ec_host_response_shadow
global er_ec_host_request_shadow
er_ec_host_request_shadow: resb 256
er_ec_host_response_shadow: resb 256

SECTION .text

; ==================================================================
; Low-level port I/O primitives
; =================================================================
%macro _ec_in_status 0
    mov     dx, EC_SC
    in      al, dx
%endmacro

%macro _ec_out_cmd 1
    mov     al, %1
    mov     dx, EC_SC
    out     dx, al
%endmacro

%macro _ec_in_data 0
    mov     dx, EC_DATA
    in      al, dx
%endmacro

%macro _ec_out_data 1
    mov     al, %1
    mov     dx, EC_DATA
    out     dx, al
%endmacro

; ==================================================================
; er_cros_ec_status — read EC status register
; uint8_t er_cros_ec_status(void)
; =================================================================
er_fn er_cros_ec_status
    %ifdef HOSTED_TEST
    mov     al, 0               ; Always idle in test mode
    er_ok
    er_ret
    %else
    _ec_in_status
    er_ok
    er_ret
    %endif

; ==================================================================
; er_cros_ec_wait_ibf — wait for input buffer empty
; void er_cros_ec_wait_ibf(void)
; Returns: rax = 0 on timeout, 1 on success
; =================================================================
er_fn er_cros_ec_wait_ibf
    %ifndef HOSTED_TEST
    push    rcx
    mov     ecx, EC_TIMEOUT
.loop:
    _ec_in_status
    test    al, EC_SC_IBF
    jz      .ready
    pause
    dec     ecx
    jnz     .loop
    pop     rcx
    xor     eax, eax            ; timeout
    er_err  ERROR_TIMEOUT
    er_ret
.ready:
    pop     rcx
    %endif
    er_ok
    er_ret

; ==================================================================
; er_cros_ec_wait_obf — wait for output buffer full
; void er_cros_ec_wait_obf(void)
; Returns: rax = 0 on timeout, 1 on success
; =================================================================
er_fn er_cros_ec_wait_obf
    %ifndef HOSTED_TEST
    push    rcx
    mov     ecx, EC_TIMEOUT
.loop:
    _ec_in_status
    test    al, EC_SC_OBF
    jnz     .ready
    pause
    dec     ecx
    jnz     .loop
    pop     rcx
    xor     eax, eax
    er_err  ERROR_TIMEOUT
    er_ret
.ready:
    pop     rcx
    %endif
    er_ok
    er_ret

; ==================================================================
; er_cros_ec_write_cmd — write command byte to EC status port
; void er_cros_ec_write_cmd(uint8_t cmd)
; Returns: rax = 1 on success, 0 on timeout
; =================================================================
er_fn er_cros_ec_write_cmd
    %ifdef HOSTED_TEST
    push    rsi
    push    rdi
    push    rcx
    mov     rsi, er_ec_cmd_log
    mov     rdi, [er_ec_cmd_count]
    add     rsi, rdi
    mov     byte [rsi], dil
    inc     rdi
    mov     [er_ec_cmd_count], rdi
    pop     rcx
    pop     rdi
    pop     rsi
    er_ok
    er_ret
    %else
    er_call er_cros_ec_wait_ibf, .fail
    _ec_out_cmd dil
    er_ok
    er_ret
.fail:
    er_ret
    %endif

; ==================================================================
; er_cros_ec_write_data — write byte to EC data port
; void er_cros_ec_write_data(uint8_t data)
; Returns: rax = 1 on success, 0 on timeout
; =================================================================
er_fn er_cros_ec_write_data
    %ifdef HOSTED_TEST
    push    rsi
    push    rdi
    push    rcx
    mov     rsi, er_ec_cmd_log
    mov     rdi, [er_ec_cmd_count]
    add     rsi, rdi
    mov     byte [rsi], sil
    inc     rdi
    mov     [er_ec_cmd_count], rdi
    pop     rcx
    pop     rdi
    pop     rsi
    er_ok
    er_ret
    %else
    er_call er_cros_ec_wait_ibf, .fail
    _ec_out_data sil
    er_ok
    er_ret
.fail:
    er_ret
    %endif

; ==================================================================
; er_cros_ec_read_data — read byte from EC data port
; uint8_t er_cros_ec_read_data(void)
; Returns: rax = data byte on success, rdx = 0; rax = 0, rdx = error on timeout
; =================================================================
er_fn er_cros_ec_read_data
    %ifdef HOSTED_TEST
    xor     eax, eax
    er_ok
    er_ret
    %else
    er_call er_cros_ec_wait_obf, .fail
    _ec_in_data
    movzx   eax, al
    er_ok
    er_ret
.fail:
    xor     eax, eax
    er_ret
    %endif

; ==================================================================
; er_cros_ec_ec_read — read a byte from EC memory at given offset
; uint8_t er_cros_ec_ec_read(uint16_t offset)
; Uses ACPI EC read command (0x80) to access EC address space.
; Returns: rax = byte value, 0 on error
; =================================================================
er_fn er_cros_ec_ec_read
    %ifdef HOSTED_TEST
    movzx   eax, di
    and     eax, 0xfff
    mov     al, [er_ec_shadow + rax]
    er_ok
    er_ret
    %else
    push    rcx
    mov     ecx, edi            ; save offset

    ; EC_CMD_READ to 0x66
    mov     dil, EC_CMD_READ
    er_call er_cros_ec_write_cmd, .err

    ; Write offset to 0x62
    mov     dil, cl
    er_call er_cros_ec_write_data, .err

    ; Read result from 0x62
    call    er_cros_ec_read_data
    ; rax = data; rdx = 0 on success, error code on failure

    pop     rcx
    er_ret

.err:
    xor     eax, eax
    pop     rcx
    er_ret                      ; rdx has error from inner call
    %endif

; ==================================================================
; er_cros_ec_ec_write — write a byte to EC memory at given offset
; void er_cros_ec_ec_write(uint16_t offset, uint8_t value)
; Returns: rax = 1 on success, 0 on error
; =================================================================
er_fn er_cros_ec_ec_write
    %ifdef HOSTED_TEST
    movzx   eax, di
    and     eax, 0xfff
    mov     byte [er_ec_shadow + rax], sil
    er_ok
    er_ret
    %else
    push    rcx
    push    rbx
    mov     ecx, edi            ; save offset
    mov     ebx, esi            ; save value

    ; EC_CMD_WRITE to 0x66
    mov     dil, EC_CMD_WRITE
    er_call er_cros_ec_write_cmd, .err

    ; Write offset to 0x62
    mov     dil, cl
    er_call er_cros_ec_write_data, .err

    ; Write value to 0x62
    mov     dil, bl
    er_call er_cros_ec_write_data, .err

    pop     rbx
    pop     rcx
    er_ok
    er_ret

.err:
    xor     eax, eax
    pop     rbx
    pop     rcx
    er_ret                      ; rdx has error from inner call
    %endif

; ==================================================================
; Host request/response struct field offsets
%define EC_HRQ_STRUCT_VERSION   0
%define EC_HRQ_CHECKSUM         1
%define EC_HRQ_COMMAND          2       ; 2 bytes (LE)
%define EC_HRQ_COMMAND_VERSION  4
%define EC_HRQ_RESERVED         5
%define EC_HRQ_DATA_LEN         6       ; 2 bytes (LE)
%define EC_HRQ_SIZE             8

%define EC_HRP_STRUCT_VERSION   0
%define EC_HRP_CHECKSUM         1
%define EC_HRP_RESULT           2       ; 2 bytes (LE)
%define EC_HRP_DATA_LEN         4       ; 2 bytes (LE)
%define EC_HRP_RESERVED         6       ; 2 bytes
%define EC_HRP_SIZE             8

; ==================================================================
; _ec_calc_checksum — sum of all bytes in buffer, negated
; uint8_t _ec_calc_checksum(const uint8_t* buf, uint16_t len)
; rdi = buffer, esi = length
; Returns: checksum byte (sum of all bytes, then negated)
; =================================================================
er_fn _ec_calc_checksum
    push    rcx
    push    rdx
    xor     eax, eax
    mov     ecx, esi
    test    ecx, ecx
    jz      .done
    xor     edx, edx
.loop:
    movzx   edx, byte [rdi]
    add     eax, edx
    inc     rdi
    dec     ecx
    jnz     .loop
.done:
    neg     al
    pop     rdx
    pop     rcx
    er_ok
    er_ret

; ==================================================================
; er_cros_ec_host_command — send a Chrome EC host command
; int32_t er_cros_ec_host_command(uint16_t command, uint8_t version,
;                                const void* req_data, uint16_t req_len,
;                                void* resp_data, uint16_t resp_max_len)
;
; rdi = command code (u16)
; esi = command version (u8, rest of reg ignored)
; rdx = request data pointer (can be 0 if req_len == 0)
; ecx = request data length
; r8  = response data buffer pointer
; r9  = response buffer max length
;
; Returns: rax = response data length on success, 0 on error
; =================================================================
er_fn er_cros_ec_host_command
    push    rbx
    push    rbp
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12d, edi            ; r12 = command
    mov     r13b, sil            ; r13 = version
    mov     r14, rdx             ; r14 = req_data pointer
    mov     r15d, ecx            ; r15 = req_len

    mov     rbx, r8              ; rbx = resp_data
    mov     ebp, r9d             ; rbp = resp_max_len

    ; Checksum starts with every request byte except the checksum field.
    mov     r11d, EC_HOST_CMD_VERSION
    mov     eax, r12d
    and     eax, 0xff
    add     r11d, eax
    mov     eax, r12d
    shr     eax, 8
    and     eax, 0xff
    add     r11d, eax
    movzx   eax, r13b
    add     r11d, eax
    mov     eax, r15d
    and     eax, 0xff
    add     r11d, eax
    mov     eax, r15d
    shr     eax, 8
    and     eax, 0xff
    add     r11d, eax

    ; Write struct_version = EC_HOST_CMD_VERSION
    mov     edi, EC_MEMMAP_HOST_CMD + EC_HRQ_STRUCT_VERSION
    mov     esi, EC_HOST_CMD_VERSION
    call    er_cros_ec_ec_write

    ; Write checksum placeholder (will calculate later)
    mov     edi, EC_MEMMAP_HOST_CMD + EC_HRQ_CHECKSUM
    xor     esi, esi
    call    er_cros_ec_ec_write

    ; Write command (16-bit LE)
    mov     edi, EC_MEMMAP_HOST_CMD + EC_HRQ_COMMAND
    mov     esi, r12d
    and     esi, 0xff
    call    er_cros_ec_ec_write
    mov     edi, EC_MEMMAP_HOST_CMD + EC_HRQ_COMMAND + 1
    mov     esi, r12d
    shr     esi, 8
    call    er_cros_ec_ec_write

    ; Write command_version
    mov     edi, EC_MEMMAP_HOST_CMD + EC_HRQ_COMMAND_VERSION
    movzx   esi, r13b
    call    er_cros_ec_ec_write

    ; Write reserved = 0
    mov     edi, EC_MEMMAP_HOST_CMD + EC_HRQ_RESERVED
    xor     esi, esi
    call    er_cros_ec_ec_write

    ; Write data_len (16-bit LE)
    mov     edi, EC_MEMMAP_HOST_CMD + EC_HRQ_DATA_LEN
    mov     esi, r15d
    and     esi, 0xff
    call    er_cros_ec_ec_write
    mov     edi, EC_MEMMAP_HOST_CMD + EC_HRQ_DATA_LEN + 1
    mov     esi, r15d
    shr     esi, 8
    call    er_cros_ec_ec_write

    ; ─── Write request data ──────────────────────────────────────
    test    r15d, r15d
    jz      .write_checksum

    mov     r13d, r15d           ; r13 = remaining bytes
    mov     r15d, EC_MEMMAP_HOST_CMD + EC_HRQ_SIZE  ; dest offset

.write_req_loop:
    test    r13d, r13d
    jz      .write_checksum

    mov     edi, r15d
    movzx   esi, byte [r14]
    add     r11d, esi
    call    er_cros_ec_ec_write

    inc     r14
    inc     r15d
    dec     r13d
    jmp     .write_req_loop

    ; ─── Finalize request checksum ───────────────────────────────
.write_checksum:
    mov     eax, r11d
    neg     al
    movzx   esi, al
    mov     edi, EC_MEMMAP_HOST_CMD + EC_HRQ_CHECKSUM
    call    er_cros_ec_ec_write

    ; ─── Trigger command ─────────────────────────────────────────
    ; Write EC_HOST_CMD_VERSION to EC_MEMMAP_OLD_HOST_CMD (0x0200)
.trigger:
    mov     edi, EC_MEMMAP_OLD_HOST_CMD
    mov     esi, EC_HOST_CMD_VERSION
    call    er_cros_ec_ec_write

    %ifdef HOSTED_TEST
    push    rcx
    xor     ecx, ecx
.copy_hosted_request:
    cmp     ecx, 256
    jae     .copy_hosted_request_done
    movzx   esi, byte [er_ec_shadow + EC_MEMMAP_HOST_CMD + rcx]
    mov     byte [er_ec_host_request_shadow + rcx], sil
    inc     ecx
    jmp     .copy_hosted_request
.copy_hosted_request_done:
    xor     ecx, ecx
.copy_hosted_response:
    cmp     ecx, 256
    jae     .copy_hosted_done
    movzx   esi, byte [er_ec_host_response_shadow + rcx]
    lea     edi, [EC_MEMMAP_HOST_CMD + rcx]
    call    er_cros_ec_ec_write
    inc     ecx
    jmp     .copy_hosted_response
.copy_hosted_done:
    pop     rcx
    %endif

    ; ─── Read response header ────────────────────────────────────
    ; After trigger, the EC processes and writes the response
    ; to EC_MEMMAP_HOST_CMD. On real hardware we'd need to poll
    ; for completion. For now, we just read back.

    ; Wait a bit for EC to process (in real implementation, poll OBF)
    push    rcx
    mov     ecx, 10000
.delay:
    pause
    dec     ecx
    jnz     .delay
    pop     rcx

    ; Read struct_version (should match)
    mov     edi, EC_MEMMAP_HOST_CMD + EC_HRP_STRUCT_VERSION
    call    er_cros_ec_ec_read
    ; Check if version matches (EC_HOST_CMD_VERSION)
    cmp     al, EC_HOST_CMD_VERSION
    jne     .err

    ; Read result (16-bit LE)
    mov     edi, EC_MEMMAP_HOST_CMD + EC_HRP_RESULT
    call    er_cros_ec_ec_read
    mov     r13b, al             ; save low byte
    mov     edi, EC_MEMMAP_HOST_CMD + EC_HRP_RESULT + 1
    call    er_cros_ec_ec_read
    shl     eax, 8
    or      al, r13b             ; result = combined

    ; Check success
    test    ax, ax
    jnz     .err

    ; Read response data_len (16-bit LE)
    mov     edi, EC_MEMMAP_HOST_CMD + EC_HRP_DATA_LEN
    call    er_cros_ec_ec_read
    mov     r13b, al
    mov     edi, EC_MEMMAP_HOST_CMD + EC_HRP_DATA_LEN + 1
    call    er_cros_ec_ec_read
    shl     eax, 8
    or      al, r13b
    mov     r14d, eax            ; r14 = response data length

    ; Cap at resp_max_len
    cmp     r14d, ebp
    jbe     .read_resp
    mov     r14d, ebp

    ; ─── Read response data ──────────────────────────────────────
.read_resp:
    mov     ebp, r14d
    test    r14d, r14d
    jz      .done

    mov     r13d, r14d           ; remaining
    mov     r15d, EC_MEMMAP_HOST_CMD + EC_HRP_SIZE  ; source offset
    mov     r14, rbx             ; destination pointer (resp_data)

.read_resp_loop:
    test    r13d, r13d
    jz      .done

    mov     edi, r15d
    call    er_cros_ec_ec_read
    mov     byte [r14], al

    inc     r14
    inc     r15d
    dec     r13d
    jmp     .read_resp_loop

.done:
    mov     eax, ebp
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
    er_ok
    er_ret

.err:
    xor     eax, eax
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
    er_ret                      ; edx has error from last ec_write/ec_read

; ==================================================================
; er_cros_ec_probe — check if Chrome EC is responding
; Returns: rax = 1 if EC present, 0 otherwise
;
; Uses EC_CMD_QUERY (0x84) to check for EC responsiveness
; =================================================================
er_fn er_cros_ec_probe
    %ifdef HOSTED_TEST
    mov     eax, 1
    er_ok
    er_ret
    %else
    push    rcx

    ; Send EC_CMD_QUERY to check communication
    mov     dil, EC_CMD_QUERY
    er_call er_cros_ec_write_cmd, .not_found

    ; Wait for and read response byte
    er_call er_cros_ec_read_data, .not_found
    mov     ecx, eax

    ; Also check status register for basic presence
    call    er_cros_ec_status
    test    al, 0xff
    jz      .not_found

    mov     eax, 1
    pop     rcx
    er_ok
    er_ret

.not_found:
    xor     eax, eax
    pop     rcx
    er_err  ERROR_NOT_PRESENT
    er_ret
    %endif

; ==================================================================
; er_cros_ec_read_battery — read battery status (simplified)
; Returns: rax = battery percentage (0-100), or 0xff on error
;
; Uses the same memmap parsing path as er_cros_ec_read_power_status.
; =================================================================
er_fn er_cros_ec_read_battery
    sub     rsp, 24
    lea     rsi, [rsp + 4]
    lea     rdi, [rsp]
    lea     rdx, [rsp + 8]
    lea     rcx, [rsp + 12]
    lea     r8, [rsp + 16]
    lea     r9, [rsp + 20]
    call    er_cros_ec_read_power_status
    test    eax, eax
    jnz     .rb_fail
    mov     eax, [rsp + 4]
    add     rsp, 24
    er_ok
    er_ret
.rb_fail:
    mov     eax, 0xff
    add     rsp, 24
    er_ret

; ==================================================================
; er_cros_ec_read_switches — read EC switch bitmap
; int er_cros_ec_read_switches(uint32_t* out_switches)
; =================================================================
er_fn er_cros_ec_read_switches
    test    rdi, rdi
    jz      .sw_bad_arg
    push    rbx
    mov     rbx, rdi
    mov     edi, EC_MEMMAP_SWITCHES
    call    er_cros_ec_ec_read
    movzx   eax, al
    mov     [rbx], eax
    pop     rbx
    xor     eax, eax
    er_ok
    er_ret
.sw_bad_arg:
    er_err  ERROR_BAD_ARGUMENT
    mov     eax, -1
    er_ret

; ==================================================================
; er_cros_ec_lid_open — read lid switch as boolean
; Returns: rax = 1 open, 0 closed
; =================================================================
er_fn er_cros_ec_lid_open
    mov     edi, EC_MEMMAP_SWITCHES
    call    er_cros_ec_ec_read
    movzx   eax, al
    and     eax, EC_SWITCH_LID_OPEN
    cmp     eax, 0
    setne   al
    movzx   eax, al
    er_ok
    er_ret

; ==================================================================
; er_cros_ec_read_battery_static — read battery design/health fields
; int er_cros_ec_read_battery_static(uint32_t* out_design_capacity,
;                                    uint32_t* out_design_voltage,
;                                    uint32_t* out_last_full_capacity,
;                                    uint32_t* out_cycle_count)
; =================================================================
er_fn er_cros_ec_read_battery_static
    test    rdi, rdi
    jz      .bs_bad_arg
    test    rsi, rsi
    jz      .bs_bad_arg
    test    rdx, rdx
    jz      .bs_bad_arg
    test    rcx, rcx
    jz      .bs_bad_arg
    push    rbx
    push    r12
    push    r13
    push    r14
    mov     rbx, rdi
    mov     r12, rsi
    mov     r13, rdx
    mov     r14, rcx
    mov     edi, EC_MEMMAP_BATT_DCAP
    call    _cros_ec_read_u32
    mov     [rbx], eax
    mov     edi, EC_MEMMAP_BATT_DVLT
    call    _cros_ec_read_u32
    mov     [r12], eax
    mov     edi, EC_MEMMAP_BATT_LFCC
    call    _cros_ec_read_u32
    mov     [r13], eax
    mov     edi, EC_MEMMAP_BATT_CCNT
    call    _cros_ec_read_u32
    mov     [r14], eax
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    xor     eax, eax
    er_ok
    er_ret
.bs_bad_arg:
    er_err  ERROR_BAD_ARGUMENT
    mov     eax, -1
    er_ret

; ==================================================================
; _cros_ec_read_u16 — read little-endian uint16 from EC memmap
; edi = low EC memmap offset. Returns eax=value.
; =================================================================
_cros_ec_read_u16:
    push    rbx
    push    r12
    mov     r12d, edi
    call    er_cros_ec_ec_read
    movzx   ebx, al
    lea     edi, [r12 + 1]
    call    er_cros_ec_ec_read
    movzx   eax, al
    shl     eax, 8
    or      eax, ebx
    pop     r12
    pop     rbx
    ret

; ==================================================================
; _cros_ec_read_u32 — read little-endian uint32 from EC memmap
; edi = low EC memmap offset. Returns eax=value.
; =================================================================
_cros_ec_read_u32:
    push    rbx
    push    r12
    mov     r12d, edi
    call    er_cros_ec_ec_read
    movzx   ebx, al
    lea     edi, [r12 + 1]
    call    er_cros_ec_ec_read
    movzx   eax, al
    shl     eax, 8
    or      ebx, eax
    lea     edi, [r12 + 2]
    call    er_cros_ec_ec_read
    movzx   eax, al
    shl     eax, 16
    or      ebx, eax
    lea     edi, [r12 + 3]
    call    er_cros_ec_ec_read
    movzx   eax, al
    shl     eax, 24
    or      eax, ebx
    pop     r12
    pop     rbx
    ret

; ==================================================================
; er_cros_ec_read_power_status — read Framework/Chrome EC power status
; int er_cros_ec_read_power_status(uint32_t* out_flags,
;                                  uint32_t* out_percent,
;                                  uint32_t* out_temp_c,
;                                  uint32_t* out_fan_rpm,
;                                  uint32_t* out_voltage_mv,
;                                  uint32_t* out_rate_mw)
; =================================================================
er_fn er_cros_ec_read_power_status
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    push    rbp

    mov     rbx, rdi
    mov     r12, rsi
    mov     r13, rdx
    mov     r14, rcx
    mov     r15, r8
    mov     rbp, r9
    test    rbx, rbx
    jz      .ps_bad_arg
    test    r12, r12
    jz      .ps_bad_arg
    test    r13, r13
    jz      .ps_bad_arg
    test    r14, r14
    jz      .ps_bad_arg
    test    r15, r15
    jz      .ps_bad_arg
    test    rbp, rbp
    jz      .ps_bad_arg

    mov     edi, EC_MEMMAP_BATT_FLAG
    call    er_cros_ec_ec_read
    movzx   eax, al
    mov     [rbx], eax

    mov     edi, EC_MEMMAP_TEMP_SENSOR
    call    er_cros_ec_ec_read
    movzx   eax, al
    cmp     eax, EC_TEMP_SENSOR_NOT_PRESENT
    je      .ps_temp_unknown
    cmp     eax, EC_TEMP_SENSOR_OFFSET
    jb      .ps_temp_unknown
    sub     eax, EC_TEMP_SENSOR_OFFSET
    jmp     .ps_store_temp
.ps_temp_unknown:
    mov     eax, 0xffffffff
.ps_store_temp:
    mov     [r13], eax

    mov     edi, EC_MEMMAP_FAN
    call    _cros_ec_read_u16
    cmp     eax, EC_FAN_SPEED_NOT_PRESENT
    jne     .ps_store_fan
    mov     eax, 0xffffffff
.ps_store_fan:
    mov     [r14], eax

    mov     edi, EC_MEMMAP_BATT_VOLT
    call    _cros_ec_read_u32
    mov     [r15], eax

    mov     edi, EC_MEMMAP_BATT_RATE
    call    _cros_ec_read_u32
    mov     [rbp], eax

    mov     edi, EC_MEMMAP_BATT_CAP
    call    _cros_ec_read_u32
    mov     ecx, eax
    mov     edi, EC_MEMMAP_BATT_LFCC
    call    _cros_ec_read_u32
    test    eax, eax
    jz      .ps_pct_unknown
    mov     ebx, eax
    mov     eax, ecx
    xor     edx, edx
    mov     ecx, 100
    mul     ecx
    div     ebx
    cmp     eax, 100
    jbe     .ps_store_pct
    mov     eax, 100
    jmp     .ps_store_pct
.ps_pct_unknown:
    mov     eax, 0xffffffff
.ps_store_pct:
    mov     [r12], eax

    xor     eax, eax
    er_ok
    jmp     .ps_out

.ps_bad_arg:
    er_err  ERROR_BAD_ARGUMENT
    mov     eax, -1
.ps_out:
    pop     rbp
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ret
