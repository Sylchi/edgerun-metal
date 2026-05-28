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
%include "x86_64/wasm_constants.inc"

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

; EC_CMD_HOST_CMD protocol version
%define EC_HOST_CMD_VERSION  0x00

; Timeout for EC operations (spin count)
%define EC_TIMEOUT    1000000

; ─── HOSTED_TEST shadow buffer ────────────────────────────────────────
%ifdef HOSTED_TEST
section .bss
global er_ec_shadow
er_ec_shadow: resb 4096        ; Simulated EC memory (offsets 0-4095)
global er_ec_cmd_log, er_ec_cmd_count
er_ec_cmd_log: resb 256        ; Command log
er_ec_cmd_count: resq 1
%endif

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
    call    er_cros_ec_wait_ibf
    test    edx, edx
    jnz     .fail
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
    call    er_cros_ec_wait_ibf
    test    edx, edx
    jnz     .fail
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
    call    er_cros_ec_wait_obf
    test    edx, edx
    jnz     .fail
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
    call    er_cros_ec_write_cmd
    test    edx, edx
    jnz     .err

    ; Write offset to 0x62
    mov     dil, cl
    call    er_cros_ec_write_data
    test    edx, edx
    jnz     .err

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
    call    er_cros_ec_write_cmd
    test    edx, edx
    jnz     .err

    ; Write offset to 0x62
    mov     dil, cl
    call    er_cros_ec_write_data
    test    edx, edx
    jnz     .err

    ; Write value to 0x62
    mov     dil, bl
    call    er_cros_ec_write_data
    test    edx, edx
    jnz     .err

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
; Chrome EC LPC v3 host command packet protocol
;
; The host command buffer lives at EC memory offset EC_MEMMAP_HOST_CMD
; (0x0800). To issue a command:
;
;   1. Write struct ec_host_request (8 bytes) to the buffer
;   2. Write any request data after the header
;   3. Trigger command execution
;   4. Read struct ec_host_response from the buffer
;   5. Read response data after the header
;
; Packed struct layouts:
;
;   struct ec_host_request {
;       uint8_t  struct_version;    // = EC_HOST_CMD_VERSION (3)
;       uint8_t  checksum;          // sum of all bytes = 0
;       uint16_t command;           // EC command code (LE)
;       uint8_t  command_version;   // version of the command
;       uint8_t  reserved;          // = 0
;       uint16_t data_len;          // bytes of data after header (LE)
;   };  // total: 8 bytes
;
;   struct ec_host_response {
;       uint8_t  struct_version;    // = EC_HOST_CMD_VERSION
;       uint8_t  checksum;
;       uint16_t result;            // EC_RES_SUCCESS = 0 (LE)
;       uint16_t data_len;          // bytes of data after header (LE)
;       uint16_t reserved;          // = 0
;   };  // total: 8 bytes
;
; The trigger mechanism writes a command to EC_MEMMAP_OLD_HOST_CMD
; (0x0200), which the EC firmware interprets as "run the command
; in the command buffer".
;
; Actual trigger value is EC_HOST_CMD_VERSION (byte 0 of the request
; struct), written to offset 0x0200.
;
; After triggering, the EC writes the response struct to the same
; buffer (0x0800), then sets the status register to indicate readiness.
;
; =================================================================

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
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi             ; r12 = command
    mov     r13b, sil            ; r13 = version
    mov     r14, rdx             ; r14 = req_data pointer
    mov     r15d, ecx            ; r15 = req_len

    ; Stack: [frame] [rsp+8 after 5 pushes] = r8, [rsp+16] = r9
    ; Actually, r8 and r9 are already in register args after the 6th.
    ; But we only have 6 args max via registers in SysV ABI.
    ; Extra args go on the stack. Let me re-think.

    ; Wait, we have 6 args: rdi, rsi, rdx, rcx, r8, r9. That works.
    ; r8 = resp_data, r9 = resp_max_len

    mov     rbx, r8              ; rbx = resp_data
    mov     r12d, r9d            ; r12 = resp_max_len (reuse r12)

    ; ─── Build request header ────────────────────────────────────
    ; Buffer is at EC_MEMMAP_HOST_CMD (0x800)
    ; We'll write the header + request data to EC memory, then trigger,
    ; then read back the response.

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
    jz      .trigger

    mov     r13d, r15d           ; r13 = remaining bytes
    mov     r14, r14             ; source pointer
    mov     r15d, EC_MEMMAP_HOST_CMD + EC_HRQ_SIZE  ; dest offset

.write_req_loop:
    test    r13d, r13d
    jz      .trigger

    mov     edi, r15d
    movzx   esi, byte [r14]
    call    er_cros_ec_ec_write

    inc     r14
    inc     r15d
    dec     r13d
    jmp     .write_req_loop

    ; ─── Trigger command ─────────────────────────────────────────
    ; Write EC_HOST_CMD_VERSION to EC_MEMMAP_OLD_HOST_CMD (0x0200)
.trigger:
    mov     edi, EC_MEMMAP_OLD_HOST_CMD
    mov     esi, EC_HOST_CMD_VERSION
    call    er_cros_ec_ec_write

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
    ; For now, just proceed

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
    cmp     r14d, r12d
    jbe     .read_resp
    mov     r14d, r12d

    ; ─── Read response data ──────────────────────────────────────
.read_resp:
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
    mov     eax, r14d
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ok
    er_ret

.err:
    xor     eax, eax
    pop     r15
    pop     r14
    pop     r13
    pop     r12
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
    call    er_cros_ec_write_cmd
    test    edx, edx
    jnz     .not_found

    ; Wait for and read response byte
    call    er_cros_ec_read_data
    test    edx, edx
    jnz     .not_found
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
; Uses EC_CMD_BATTERY_STATUS or reads from EC shared memory.
; The Chrome EC maps battery info into its shared memory region
; at offset EC_MEMMAP_BATTERY (typically 0x0100+).
;
; For simplicity, reads the battery percentage directly from
; EC firmware's shared memory at offsets:
;   EC_MEMMAP_BATT_PCT = 0x0105
; =================================================================
er_fn er_cros_ec_read_battery
    push    r12
    %ifndef HOSTED_TEST
    ; Read battery percentage from EC shared memory
    mov     edi, 0x0105
    call    er_cros_ec_ec_read
    test    edx, edx
    jnz     .fail
    mov     r12b, al

    ; Validate range
    cmp     r12b, 100
    jbe     .valid
    ; Could be 0xff = "charging" or similar
    cmp     r12b, 0xff
    je      .charging
    xor     r12d, r12d
.charging:
.valid:
    movzx   eax, r12b
    pop     r12
    er_ok
    er_ret
.fail:
    mov     eax, 0xff
    pop     r12
    er_ret                      ; rdx has error from er_cros_ec_ec_read
    %else
    mov     eax, 50             ; simulated 50%
    pop     r12
    er_ok
    er_ret
    %endif
