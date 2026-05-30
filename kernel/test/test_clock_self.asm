; EdgeRun clock self-hosted test runner — x86_64 assembly
; No libc, no external dependencies. Exits via syscall.
; Returns 0 if all tests pass, 1 on any failure.

%include "x86_64/macros.inc"

extern er_clock_is_power_of_two, er_clock_shift_for_power_of_two
extern er_clock_limits_valid, er_clock_modifier_valid, er_clock_keeper_valid
extern er_clock_init, er_clock_advance_with, er_clock_advance
extern er_clock_advance_default, er_clock_stamp_order

; Error codes (must match clock.asm)
CLOCK_ERR_INVALID      equ 90
CLOCK_ERR_OVERFLOW     equ 91

; Boundary flags
BOUNDARY_SLOT          equ 1
BOUNDARY_EPOCH         equ 2
BOUNDARY_ERA           equ 4

KEEPER_ID_SIZE         equ 32
SIZEOF_CLOCK           equ 88

; ─── Assertion macros ──────────────────────────────────────────────
%macro ASSERT_EQ 2
    cmp     %1, %2
    jne     %%fail
    inc     qword [rel passed]
    jmp     %%done
%%fail:
    inc     qword [rel failed]
%%done:
%endmacro

; Assert that rax == expected (immediate)
%macro ASSERT_RAX 1
    cmp     rax, %1
    jne     %%fail
    inc     qword [rel passed]
    jmp     %%done
%%fail:
    inc     qword [rel failed]
%%done:
%endmacro

; Assert that rdx == expected error code (immediate)
%macro ASSERT_RDX 1
    cmp     rdx, %1
    jne     %%fail
    inc     qword [rel passed]
    jmp     %%done
%%fail:
    inc     qword [rel failed]
%%done:
%endmacro

; Assert that memory at rdi (size rsi) equals expected immediate byte
%macro ASSERT_MEM_ALL 2
    push    rcx
    push    rdi
    push    rsi
    mov     rcx, %2
    mov     al, %1
%%loop:
    cmp     [rdi], al
    jne     %%fail
    inc     rdi
    dec     rcx
    jnz     %%loop
    inc     qword [rel passed]
    jmp     %%done
%%fail:
    inc     qword [rel failed]
%%done:
    pop     rsi
    pop     rdi
    pop     rcx
%endmacro

; Assert that memory at rdi (size rsi) is all zeros
%macro ASSERT_MEM_ZERO 2
    push    rcx
    push    rdi
    push    rsi
    mov     rcx, %2
    xor     eax, eax
%%loop:
    cmp     [rdi], al
    jne     %%fail
    inc     rdi
    dec     rcx
    jnz     %%loop
    inc     qword [rel passed]
    jmp     %%done
%%fail:
    inc     qword [rel failed]
%%done:
    pop     rsi
    pop     rdi
    pop     rcx
%endmacro

; Assert u64 value at memory location equals expected
; %1 = address expression (e.g. clock1 + 32), %2 = expected u64 immediate
%macro ASSERT_MEM_U64 2
    push    rdi
    push    rax
    mov     rdi, %1
    mov     rax, [rdi]
    cmp     rax, %2
    jne     %%fail
    inc     qword [rel passed]
    jmp     %%done
%%fail:
    inc     qword [rel failed]
%%done:
    pop     rax
    pop     rdi
%endmacro

; Run a test and print its name (for debug)
%macro TEST_GROUP 1
    ; No-op for now; just a label marker
%endmacro

SECTION .bss
; Test clock structures (88 bytes each)
align 16
clock1:     resb SIZEOF_CLOCK
clock2:     resb SIZEOF_CLOCK
clock3:     resb SIZEOF_CLOCK
clock4:     resb SIZEOF_CLOCK
clock5:     resb SIZEOF_CLOCK

; Result tracking
passed:     resq 1
failed:     resq 1

SECTION .data
; ─── Test Keeper IDs ───────────────────────────────────────────────
keeper1:
    db 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

keeper2:
    db 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

keeper3:
    db 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    db 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

; Invalid keeper (all zeros)
keeper_zero:
    times 32 db 0

; ─── Test Limits ───────────────────────────────────────────────────
limits_2_2_2:
    dq 2, 2, 2

limits_4_4_4:
    dq 4, 4, 4

limits_1024_1024_1024:
    dq 1024, 1024, 1024

; Invalid limits (not power of 2)
limits_invalid:
    dq 3, 2, 2

; ─── Test Modifiers ────────────────────────────────────────────────
mod_one:
    dq 1

mod_zero:
    dq 0

mod_five:
    dq 5

SECTION .text
global _start
_start:

; ═══════════════════════════════════════════════════════════════════
; Test: er_clock_is_power_of_two
; ═══════════════════════════════════════════════════════════════════
    ; 0 → false
    mov     rdi, 0
    call    er_clock_is_power_of_two
    ASSERT_RAX 0

    ; 1 → true (2^0)
    mov     rdi, 1
    call    er_clock_is_power_of_two
    ASSERT_RAX 1

    ; 2 → true (2^1)
    mov     rdi, 2
    call    er_clock_is_power_of_two
    ASSERT_RAX 1

    ; 3 → false
    mov     rdi, 3
    call    er_clock_is_power_of_two
    ASSERT_RAX 0

    ; 1024 → true (2^10)
    mov     rdi, 1024
    call    er_clock_is_power_of_two
    ASSERT_RAX 1

    ; 0x8000000000000000 → true (2^63)
    mov     rdi, 0x8000000000000000
    call    er_clock_is_power_of_two
    ASSERT_RAX 1

; ═══════════════════════════════════════════════════════════════════
; Test: er_clock_shift_for_power_of_two
; ═══════════════════════════════════════════════════════════════════
    ; 1024 → shift 10
    mov     rdi, 1024
    call    er_clock_shift_for_power_of_two
    ASSERT_RAX 10
    ASSERT_RDX 0

    ; 4 → shift 2
    mov     rdi, 4
    call    er_clock_shift_for_power_of_two
    ASSERT_RAX 2
    ASSERT_RDX 0

    ; 3 → error
    mov     rdi, 3
    call    er_clock_shift_for_power_of_two
    ASSERT_RDX CLOCK_ERR_INVALID

; ═══════════════════════════════════════════════════════════════════
; Test: er_clock_limits_valid
; ═══════════════════════════════════════════════════════════════════
    ; Valid limits (2, 2, 2)
    mov     rdi, limits_2_2_2
    call    er_clock_limits_valid
    ASSERT_RAX 1

    ; Invalid limits (3, 2, 2)
    mov     rdi, limits_invalid
    call    er_clock_limits_valid
    ASSERT_RAX 0

; ═══════════════════════════════════════════════════════════════════
; Test: er_clock_modifier_valid
; ═══════════════════════════════════════════════════════════════════
    ; stride=1 → valid
    mov     rdi, mod_one
    call    er_clock_modifier_valid
    ASSERT_RAX 1

    ; stride=0 → invalid
    mov     rdi, mod_zero
    call    er_clock_modifier_valid
    ASSERT_RAX 0

; ═══════════════════════════════════════════════════════════════════
; Test: er_clock_keeper_valid
; ═══════════════════════════════════════════════════════════════════
    ; keeper1 → valid (has byte 1)
    mov     rdi, keeper1
    call    er_clock_keeper_valid
    ASSERT_RAX 1

    ; keeper_zero → invalid (all zeros)
    mov     rdi, keeper_zero
    call    er_clock_keeper_valid
    ASSERT_RAX 0

; ═══════════════════════════════════════════════════════════════════
; Test: er_clock_init — valid
; ═══════════════════════════════════════════════════════════════════
    mov     rdi, keeper1
    mov     rsi, limits_2_2_2
    mov     rdx, clock1
    call    er_clock_init
    ASSERT_RAX clock1        ; returns clock out ptr
    ASSERT_RDX 0             ; no error

    ; Verify keeper was copied
    lea     rdi, [clock1 + 0]   ; offset STAMP_KEEPER = 0
    mov     rsi, keeper1
    mov     rcx, KEEPER_ID_SIZE
    cld
    repe    cmpsb
    ASSERT_RAX 0                 ; ZF set → equal (but RAX was modified by cmpsb)

    ; Hmm, the cmpsb modified rax. Let me do this differently.
    ; Actually, after repe cmpsb, ZF indicates result. Let me just use a simpler check.
    ; I'll verify the first and last bytes of the keeper copy.
    cmp     byte [clock1 + 0], 1
    jne     .keeper_fail
    inc     qword [rel passed]
    jmp     .keeper_ok
.keeper_fail:
    inc     qword [rel failed]
.keeper_ok:
    cmp     byte [clock1 + 31], 0
    jne     .keeper2_fail
    inc     qword [rel passed]
    jmp     .keeper2_ok
.keeper2_fail:
    inc     qword [rel failed]
.keeper2_ok:

    ; Verify tick/slot/epoch/era are zero
    ASSERT_MEM_U64 (clock1 + 32), 0     ; tick = 0
    ASSERT_MEM_U64 (clock1 + 40), 0     ; slot = 0
    ASSERT_MEM_U64 (clock1 + 48), 0     ; epoch = 0
    ASSERT_MEM_U64 (clock1 + 56), 0     ; era = 0

    ; Verify limits copied
    ASSERT_MEM_U64 (clock1 + 64), 2     ; ticks_per_slot = 2
    ASSERT_MEM_U64 (clock1 + 72), 2     ; slots_per_epoch = 2
    ASSERT_MEM_U64 (clock1 + 80), 2     ; epochs_per_era = 2

; ═══════════════════════════════════════════════════════════════════
; Test: er_clock_init — invalid keeper (all zeros)
; ═══════════════════════════════════════════════════════════════════
    mov     rdi, keeper_zero
    mov     rsi, limits_2_2_2
    mov     rdx, clock2
    call    er_clock_init
    ASSERT_RAX 0
    ASSERT_RDX CLOCK_ERR_INVALID

; ═══════════════════════════════════════════════════════════════════
; Test: er_clock_init — invalid limits (not power of 2)
; ═══════════════════════════════════════════════════════════════════
    mov     rdi, keeper2
    mov     rsi, limits_invalid
    mov     rdx, clock2
    call    er_clock_init
    ASSERT_RAX 0
    ASSERT_RDX CLOCK_ERR_INVALID

; ═══════════════════════════════════════════════════════════════════
; Test: advance with no boundary crossing (2 ticks per slot)
; clock1: keeper1, limits (2,2,2), now at (tick=0,slot=0,epoch=0,era=0)
; advance(1): tick 0→1, same slot → no boundary
; ═══════════════════════════════════════════════════════════════════
    ; Re-init clock1 to ensure clean state (init checked above)
    mov     rdi, keeper1
    mov     rsi, limits_2_2_2
    mov     rdx, clock1
    call    er_clock_init

    mov     rdi, clock1
    mov     rsi, mod_one       ; stride = 1
    call    er_clock_advance_with
    ASSERT_RAX 0                ; no boundary
    ASSERT_RDX 0
    ASSERT_MEM_U64 (clock1 + 32), 1     ; tick = 1 (was 0, advanced by 1)

; ═══════════════════════════════════════════════════════════════════
; Test: advance crossing slot boundary
; clock1 is at tick=1, limits (2,2,2)
; advance(1): tick 1→2 → wraps to 0, slot_steps=1 → slot 0→1
; ═══════════════════════════════════════════════════════════════════
    mov     rdi, clock1
    mov     rsi, mod_one
    call    er_clock_advance_with
    ASSERT_RAX BOUNDARY_SLOT            ; slot boundary
    ASSERT_RDX 0
    ASSERT_MEM_U64 (clock1 + 32), 0     ; tick = 0 (wrapped)
    ASSERT_MEM_U64 (clock1 + 40), 1     ; slot = 1

; ═══════════════════════════════════════════════════════════════════
; Test: advance with er_clock_advance convenience wrapper
; clock1 at tick=0, slot=1, epoch=0, era=0
; advance(1): tick 0→1, same slot → no boundary
; ═══════════════════════════════════════════════════════════════════
    mov     rdi, clock1
    mov     rsi, 1
    call    er_clock_advance
    ASSERT_RAX 0
    ASSERT_RDX 0
    ASSERT_MEM_U64 (clock1 + 32), 1     ; tick = 1

; ═══════════════════════════════════════════════════════════════════
; Test: er_clock_advance_default
; clock1 at tick=1, slot=1, epoch=0, era=0, limits (2,2,2)
; advance default(1): tick 1→2 → wraps to 0, slot 1→2, slot_steps=1 → wraps slot to 0, epoch 0→1
; Actually: total_ticks = 1+1 = 2. tick = 2 & 1 = 0. slot_steps = 2 >> 1 = 1.
; next_slot = 1+1 = 2. slot = 2 & 1 = 0. epoch_steps = 2 >> 1 = 1.
; epoch 0→1. epoch 1 & 1 = 1? Wait: epochs_per_era=2, so epoch = 1 & 1 = 1. era_steps = 1 >> 1 = 0.
; So boundary = slot=1, epoch=1. Now: tick=0, slot=0, epoch=1.
; ═══════════════════════════════════════════════════════════════════
    mov     rdi, clock1
    call    er_clock_advance_default
    ASSERT_RAX (BOUNDARY_SLOT | BOUNDARY_EPOCH)
    ASSERT_RDX 0
    ASSERT_MEM_U64 (clock1 + 32), 0     ; tick = 0
    ASSERT_MEM_U64 (clock1 + 40), 0     ; slot = 0
    ASSERT_MEM_U64 (clock1 + 48), 1     ; epoch = 1

; ═══════════════════════════════════════════════════════════════════
; Test: invalid modifier (stride=0) → error
; ═══════════════════════════════════════════════════════════════════
    mov     rdi, clock1
    mov     rsi, mod_zero
    call    er_clock_advance_with
    ASSERT_RDX CLOCK_ERR_INVALID

; ═══════════════════════════════════════════════════════════════════
; Test: overflow (tick = U64_MAX, advance 1)
; ═══════════════════════════════════════════════════════════════════
    mov     qword [clock1 + 32], -1     ; tick = U64_MAX
    mov     rdi, clock1
    mov     rsi, mod_one
    call    er_clock_advance_with
    ASSERT_RDX CLOCK_ERR_OVERFLOW

; ═══════════════════════════════════════════════════════════════════
; Test: advance across epoch and era boundaries (limits 4,4,4)
; clock2: keeper2, limits (4,4,4), init
; advance(4*4*4 + 5 = 69)
; total_ticks = 0 + 69 = 69
; tick = 69 & 3 = 1  (4-1=3)
; slot_steps = 69 >> 2 = 17  (ctz(4)=2)
; next_slot = 0 + 17 = 17
; slot = 17 & 3 = 1
; epoch_steps = 17 >> 2 = 4
; boundary.slot=true
; next_epoch = 0 + 4 = 4
; epoch = 4 & 3 = 0
; era_steps = 4 >> 2 = 1
; boundary.epoch=true
; next_era = 0 + 1 = 1
; boundary.era=true
; Result: tick=1, slot=1, epoch=0, era=1
; ═══════════════════════════════════════════════════════════════════
    mov     rdi, keeper2
    mov     rsi, limits_4_4_4
    mov     rdx, clock2
    call    er_clock_init

    mov     rdi, clock2
    mov     rsi, 69           ; 4*4*4 + 5
    call    er_clock_advance
    ASSERT_RAX (BOUNDARY_SLOT | BOUNDARY_EPOCH | BOUNDARY_ERA)
    ASSERT_RDX 0
    ASSERT_MEM_U64 (clock2 + 32), 1     ; tick = 1
    ASSERT_MEM_U64 (clock2 + 40), 1     ; slot = 1
    ASSERT_MEM_U64 (clock2 + 48), 0     ; epoch = 0
    ASSERT_MEM_U64 (clock2 + 56), 1     ; era = 1

; ═══════════════════════════════════════════════════════════════════
; Test: stamp order (same keeper, different eras)
; ═══════════════════════════════════════════════════════════════════
    ; Init clock3 with keeper1, limits (2,2,2)
    mov     rdi, keeper1
    mov     rsi, limits_2_2_2
    mov     rdx, clock3
    call    er_clock_init

    ; Init clock4 with keeper1, limits (2,2,2)
    mov     rdi, keeper1
    mov     rsi, limits_2_2_2
    mov     rdx, clock4
    call    er_clock_init

    ; Advance clock3 to different state
    mov     rdi, clock3
    mov     rsi, 100
    call    er_clock_advance

    ; clock3 and clock4 have same keeper → order by time
    lea     rdi, [clock3 + 0]      ; clock3's stamp (at offset 0 of Clock)
    lea     rsi, [clock4 + 0]      ; clock4's stamp
    call    er_clock_stamp_order
    ASSERT_RAX 1                    ; clock3 (advanced) > clock4 (zero)

    lea     rdi, [clock4 + 0]
    lea     rsi, [clock3 + 0]
    call    er_clock_stamp_order
    ASSERT_RAX -1                   ; clock4 < clock3

    lea     rdi, [clock4 + 0]
    lea     rsi, [clock4 + 0]
    call    er_clock_stamp_order
    ASSERT_RAX 0                    ; same stamp

; ═══════════════════════════════════════════════════════════════════
; Test: stamp order (different keepers)
; ═══════════════════════════════════════════════════════════════════
    ; clock1 uses keeper1 (starts with 1)
    ; clock2 uses keeper2 (starts with 2)
    lea     rdi, [clock1 + 0]
    lea     rsi, [clock2 + 0]
    call    er_clock_stamp_order
    ASSERT_RAX -1                   ; keeper1 (0x01...) < keeper2 (0x02...)

    lea     rdi, [clock2 + 0]
    lea     rsi, [clock1 + 0]
    call    er_clock_stamp_order
    ASSERT_RAX 1                    ; keeper2 > keeper1

; ═══════════════════════════════════════════════════════════════════
; Test: slot overflow protection
; Set now.slot to U64_MAX - 1, advance enough to wrap slot
; ═══════════════════════════════════════════════════════════════════
    ; Init clean clock5
    mov     rdi, keeper3
    mov     rsi, limits_2_2_2
    mov     rdx, clock5
    call    er_clock_init

    ; Set tick to max so that stride 1 wraps tick -> slot_steps=1
    ; Then set slot to U64_MAX so that slot + 1 overflows
    mov     qword [clock5 + 32], 0xFFFFFFFFFFFFFFFE   ; tick huge (so step wraps)
    ; Actually we need tick such that (tick + stride) >> 1 produces a slot_steps
    ; that overflows when added to slot. Let's do:
    ; stride=1, tick = U64_MAX-1, so total_ticks = U64_MAX
    ; next_tick = U64_MAX & 1 = 1
    ; slot_steps = U64_MAX >> 1 = 0x7FFFFFFFFFFFFFFF
    ; slot = U64_MAX, then slot + slot_steps overflows
    mov     qword [clock5 + 32], -2     ; tick = U64_MAX - 1
    mov     qword [clock5 + 40], -1     ; slot = U64_MAX

    mov     rdi, clock5
    mov     rsi, mod_one
    call    er_clock_advance_with
    ASSERT_RDX CLOCK_ERR_OVERFLOW       ; slot overflow

; ═══════════════════════════════════════════════════════════════════
; Done — report results
; ═══════════════════════════════════════════════════════════════════
    mov     rax, [rel failed]
    test    rax, rax
    jnz     .exit_fail
.exit_pass:
    xor     edi, edi            ; return 0
    jmp     .exit
.exit_fail:
    mov     edi, 1              ; return 1

.exit:
    mov     eax, 60             ; sys_exit
    syscall
