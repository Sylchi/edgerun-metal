; EdgeRun clock (KeeperId, Stamp, Clock) — x86_64 assembly
; System V AMD64 ABI
; Freestanding — no libc, no external dependencies.

%include "x86_64/macros.inc"

extern er_bytes_nonzero
extern er_bytes_eql
extern er_bytes_order

%define KEEPER_ID_SIZE     32

struc er_stamp
    .keeper:    resb KEEPER_ID_SIZE
    .tick:      resq 1
    .slot:      resq 1
    .epoch:     resq 1
    .era:       resq 1
endstruc

struc er_limits
    .ticks_per_slot:   resq 1
    .slots_per_epoch:  resq 1
    .epochs_per_era:   resq 1
endstruc

struc er_clock
    .now:       resb er_stamp_size
    .limits:    resb er_limits_size
endstruc

%define BOUNDARY_SLOT  1
%define BOUNDARY_EPOCH 2
%define BOUNDARY_ERA   4

SECTION .text

; ==================================================================
; er_keeper_id_valid(keeper) → bool
er_fn er_keeper_id_valid
    mov     esi, KEEPER_ID_SIZE
    jmp     er_bytes_nonzero

; ==================================================================
; er_keeper_id_eql(a, b) → bool
er_fn er_keeper_id_eql
    mov     ecx, KEEPER_ID_SIZE
    mov     rdx, rsi
    mov     esi, KEEPER_ID_SIZE
    jmp     er_bytes_eql

; ==================================================================
; er_stamp_valid(stamp) → bool
er_fn er_stamp_valid
    jmp     er_keeper_id_valid

; ==================================================================
; er_stamp_same_keeper(a, b) → bool
er_fn er_stamp_same_keeper
    jmp     er_keeper_id_eql

; ==================================================================
; er_stamp_order(a, b) → -1, 0, or 1
er_fn er_stamp_order
    push    rbx
    push    r12
    push    r13
    mov     r12, rdi
    mov     r13, rsi

    lea     rdi, [r12 + er_stamp.keeper]
    mov     esi, KEEPER_ID_SIZE
    lea     rdx, [r13 + er_stamp.keeper]
    mov     ecx, KEEPER_ID_SIZE
    call    er_bytes_order
    test    eax, eax
    jnz     .ord_done

    mov     rax, [r12 + er_stamp.era]
    mov     rdx, [r13 + er_stamp.era]
    cmp     rax, rdx
    jb      .ord_less
    ja      .ord_greater
    mov     rax, [r12 + er_stamp.epoch]
    mov     rdx, [r13 + er_stamp.epoch]
    cmp     rax, rdx
    jb      .ord_less
    ja      .ord_greater
    mov     rax, [r12 + er_stamp.slot]
    mov     rdx, [r13 + er_stamp.slot]
    cmp     rax, rdx
    jb      .ord_less
    ja      .ord_greater
    mov     rax, [r12 + er_stamp.tick]
    mov     rdx, [r13 + er_stamp.tick]
    cmp     rax, rdx
    jb      .ord_less
    ja      .ord_greater
    xor     eax, eax
    pop     r13
    pop     r12
    pop     rbx
    er_ok
    er_ret
.ord_less:
    mov     rax, -1
    pop     r13
    pop     r12
    pop     rbx
    er_ok
    er_ret
.ord_greater:
    mov     eax, 1
    pop     r13
    pop     r12
    pop     rbx
    er_ok
    er_ret
.ord_done:
    pop     r13
    pop     r12
    pop     rbx
    er_ok
    er_ret

; ==================================================================
; Shared: er_is_power_of_two(rdi=value) → eax=1 if power of 2
; ==================================================================
er_fn er_is_power_of_two
    test    rdi, rdi
    jz      .np2
    mov     rax, rdi
    dec     rax
    test    rdi, rax
    jnz     .np2
    mov     eax, 1
    er_ret
.np2:
    xor     eax, eax
    er_ret

; ==================================================================
; er_limits_valid(limits) → bool
er_fn er_limits_valid
    push    r12
    mov     r12, rdi
    mov     rdi, [r12 + er_limits.ticks_per_slot]
    call    er_is_power_of_two
    test    eax, eax
    jz      .lim_invalid
    mov     rdi, [r12 + er_limits.slots_per_epoch]
    call    er_is_power_of_two
    test    eax, eax
    jz      .lim_invalid
    mov     rdi, [r12 + er_limits.epochs_per_era]
    call    er_is_power_of_two
    test    eax, eax
    jz      .lim_invalid
    mov     eax, 1
    pop     r12
    er_ok
    er_ret
.lim_invalid:
    xor     eax, eax
    pop     r12
    er_ok
    er_ret

; ==================================================================
; er_shift_for_power_of_two(value) → shift or -1
er_fn er_shift_for_power_of_two
    call    er_is_power_of_two
    test    eax, eax
    jz      .nps
    bsf     rax, rdi
    er_ok
    er_ret
.nps:
    mov     eax, -1
    er_ok
    er_ret

; ==================================================================
; er_clock_init(keeper, limits, out_clock) → bool
er_fn er_clock_init
    push    rbx
    push    r12
    push    r13
    mov     r12, rdi
    mov     r13, rsi
    mov     rbx, rdx

    mov     rdi, r12
    call    er_keeper_id_valid
    test    eax, eax
    jz      .init_fail
    mov     rdi, r13
    call    er_limits_valid
    test    eax, eax
    jz      .init_fail

    lea     rdi, [rbx + er_clock.now + er_stamp.keeper]
    mov     rsi, r12
    mov     ecx, KEEPER_ID_SIZE
    shr     ecx, 3
    rep movsq
    mov     qword [rbx + er_clock.now + er_stamp.tick], 0
    mov     qword [rbx + er_clock.now + er_stamp.slot], 0
    mov     qword [rbx + er_clock.now + er_stamp.epoch], 0
    mov     qword [rbx + er_clock.now + er_stamp.era], 0
    mov     rax, [r13 + er_limits.ticks_per_slot]
    mov     [rbx + er_clock.limits + er_limits.ticks_per_slot], rax
    mov     rax, [r13 + er_limits.slots_per_epoch]
    mov     [rbx + er_clock.limits + er_limits.slots_per_epoch], rax
    mov     rax, [r13 + er_limits.epochs_per_era]
    mov     [rbx + er_clock.limits + er_limits.epochs_per_era], rax

    mov     eax, 1
    pop     r13
    pop     r12
    pop     rbx
    er_ok
    er_ret
.init_fail:
    xor     eax, eax
    pop     r13
    pop     r12
    pop     rbx
    er_ok
    er_ret

; ==================================================================
; er_clock_advance_with(clock, modifier_tick_stride) → boundary flags
; rdi=clock, esi=modifier_tick_stride
; Returns eax = BOUNDARY flags, 0 on error (rdx=1).
; ==================================================================
er_fn er_clock_advance_with
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi
    mov     r13, rsi            ; stride

    lea     rdi, [r12 + er_clock.limits]
    call    er_limits_valid
    test    eax, eax
    jz      .fail
    test    r13, r13
    jz      .fail

    ; ── TICK level ──────────────────────────────────────────────
    mov     rax, [r12 + er_clock.now + er_stamp.tick]
    add     rax, r13
    jc      .fail
    mov     r14, rax            ; total_ticks

    mov     r15, [r12 + er_clock.limits + er_limits.ticks_per_slot]
    mov     rdi, r15
    call    er_shift_for_power_of_two
    mov     ecx, eax
    mov     rax, r14
    shr     rax, cl
    mov     r8, rax             ; r8 = slot_steps

    mov     rax, r15
    dec     rax
    and     r14, rax
    mov     [r12 + er_clock.now + er_stamp.tick], r14

    test    r8, r8
    jz      .done_no_boundary

    ; ── SLOT level ──────────────────────────────────────────────
    mov     rax, [r12 + er_clock.now + er_stamp.slot]
    add     rax, r8
    jc      .fail
    mov     r14, rax            ; total_slots

    mov     r15, [r12 + er_clock.limits + er_limits.slots_per_epoch]
    mov     rdi, r15
    call    er_shift_for_power_of_two
    mov     ecx, eax
    mov     rax, r14
    shr     rax, cl
    mov     r9, rax             ; r9 = epoch_steps

    mov     rax, r15
    dec     rax
    and     r14, rax
    mov     [r12 + er_clock.now + er_stamp.slot], r14

    mov     ebx, BOUNDARY_SLOT
    test    r9, r9
    jz      .done

    ; ── EPOCH level ─────────────────────────────────────────────
    mov     rax, [r12 + er_clock.now + er_stamp.epoch]
    add     rax, r9
    jc      .fail
    mov     r14, rax            ; total_epochs

    mov     r15, [r12 + er_clock.limits + er_limits.epochs_per_era]
    mov     rdi, r15
    call    er_shift_for_power_of_two
    mov     ecx, eax
    mov     rax, r14
    shr     rax, cl
    mov     r10, rax            ; r10 = era_steps

    mov     rax, r15
    dec     rax
    and     r14, rax
    mov     [r12 + er_clock.now + er_stamp.epoch], r14

    or      ebx, BOUNDARY_EPOCH
    test    r10, r10
    jz      .done

    ; ── ERA level ───────────────────────────────────────────────
    add     qword [r12 + er_clock.now + er_stamp.era], r10
    jc      .fail

    or      ebx, BOUNDARY_ERA
    mov     eax, ebx
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ok
    er_ret

.done:
    mov     eax, ebx
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ok
    er_ret

.done_no_boundary:
    xor     eax, eax
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_ok
    er_ret

.fail:
    xor     eax, eax
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    er_err  1
    er_ret
