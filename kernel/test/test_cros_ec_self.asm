; EdgeRun Chrome EC self-hosted test runner — x86_64 assembly
; Tests EC memmap parsing through the HOSTED_TEST shadow memory.

%include "x86_64/macros.inc"
%include "test/test_macros.inc"

extern er_ec_shadow
extern er_cros_ec_read_power_status
extern er_cros_ec_read_battery
extern er_cros_ec_read_switches
extern er_cros_ec_lid_open
extern er_cros_ec_read_battery_static

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
%define EC_SWITCH_LID_OPEN         0x01

SECTION .bss
passed: resq 1
failed: resq 1
flags_out: resd 1
pct_out: resd 1
temp_out: resd 1
fan_out: resd 1
mv_out: resd 1
rate_out: resd 1
switches_out: resd 1
design_cap_out: resd 1
design_mv_out: resd 1
last_full_cap_out: resd 1
cycle_count_out: resd 1

SECTION .rodata
pass_msg: db "PASS cros_ec", 10, 0
fail_msg: db "FAIL cros_ec", 10, 0

SECTION .text
global _start
_start:
    ; Battery flag: AC present, battery present, charging.
    mov     byte [rel er_ec_shadow + EC_MEMMAP_BATT_FLAG], 0x0b
    mov     byte [rel er_ec_shadow + EC_MEMMAP_SWITCHES], EC_SWITCH_LID_OPEN

    ; Temperature stores Celsius + 200.
    mov     byte [rel er_ec_shadow + EC_MEMMAP_TEMP_SENSOR], EC_TEMP_SENSOR_OFFSET + 37

    ; Fan RPM = 2400.
    mov     word [rel er_ec_shadow + EC_MEMMAP_FAN], 2400

    ; Voltage mV = 7600, rate mW = 12000.
    mov     dword [rel er_ec_shadow + EC_MEMMAP_BATT_VOLT], 7600
    mov     dword [rel er_ec_shadow + EC_MEMMAP_BATT_RATE], 12000

    ; Remaining 40 / last full 80 => 50%.
    mov     dword [rel er_ec_shadow + EC_MEMMAP_BATT_CAP], 40
    mov     dword [rel er_ec_shadow + EC_MEMMAP_BATT_LFCC], 80
    mov     dword [rel er_ec_shadow + EC_MEMMAP_BATT_DCAP], 100
    mov     dword [rel er_ec_shadow + EC_MEMMAP_BATT_DVLT], 7700
    mov     dword [rel er_ec_shadow + EC_MEMMAP_BATT_CCNT], 17

    lea     rdi, [rel flags_out]
    lea     rsi, [rel pct_out]
    lea     rdx, [rel temp_out]
    lea     rcx, [rel fan_out]
    lea     r8, [rel mv_out]
    lea     r9, [rel rate_out]
    call    er_cros_ec_read_power_status
    ASSERT_EQ eax, 0

    mov     eax, [rel flags_out]
    ASSERT_EQ eax, 0x0b
    mov     eax, [rel pct_out]
    ASSERT_EQ eax, 50
    mov     eax, [rel temp_out]
    ASSERT_EQ eax, 37
    mov     eax, [rel fan_out]
    ASSERT_EQ eax, 2400
    mov     eax, [rel mv_out]
    ASSERT_EQ eax, 7600
    mov     eax, [rel rate_out]
    ASSERT_EQ eax, 12000

    call    er_cros_ec_read_battery
    ASSERT_EQ eax, 50

    lea     rdi, [rel switches_out]
    call    er_cros_ec_read_switches
    ASSERT_EQ eax, 0
    mov     eax, [rel switches_out]
    ASSERT_EQ eax, EC_SWITCH_LID_OPEN

    call    er_cros_ec_lid_open
    ASSERT_EQ eax, 1
    mov     byte [rel er_ec_shadow + EC_MEMMAP_SWITCHES], 0
    call    er_cros_ec_lid_open
    ASSERT_EQ eax, 0

    lea     rdi, [rel design_cap_out]
    lea     rsi, [rel design_mv_out]
    lea     rdx, [rel last_full_cap_out]
    lea     rcx, [rel cycle_count_out]
    call    er_cros_ec_read_battery_static
    ASSERT_EQ eax, 0
    mov     eax, [rel design_cap_out]
    ASSERT_EQ eax, 100
    mov     eax, [rel design_mv_out]
    ASSERT_EQ eax, 7700
    mov     eax, [rel last_full_cap_out]
    ASSERT_EQ eax, 80
    mov     eax, [rel cycle_count_out]
    ASSERT_EQ eax, 17

    mov     rdi, 1
    mov     rax, [rel failed]
    test    rax, rax
    jnz     .fail
    lea     rsi, [rel pass_msg]
    mov     rdx, 13
    mov     rax, 1
    syscall
    xor     edi, edi
    mov     rax, 60
    syscall
.fail:
    lea     rsi, [rel fail_msg]
    mov     rdx, 13
    mov     rax, 1
    syscall
    mov     edi, 1
    mov     rax, 60
    syscall
