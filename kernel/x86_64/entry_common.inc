; EdgeRun shared entry-point utility functions — x86_64 assembly
; Included by both entry.asm (multiboot) and efi_entry.asm (UEFI).

; ==================================================================
; er_halt — stop execution
; void er_halt(void)
; ==================================================================
er_fn er_halt
    cli
.loop:
    hlt
    jmp     .loop

; ==================================================================
; er_cpu_id — get CPU identification
; uint64_t er_cpu_id(void)
; ==================================================================
er_fn er_cpu_id
    push    rbx
    xor     eax, eax
    cpuid
    pop     rbx
    ret

; ==================================================================
; er_rdtsc — read timestamp counter
; uint64_t er_rdtsc(void)
; ==================================================================
er_fn er_rdtsc
    rdtsc
    shl     rdx, 32
    or      rax, rdx
    ret

; ==================================================================
; er_mmio_read32 — read 32-bit from MMIO address
; uint32_t er_mmio_read32(uint64_t addr)
; ==================================================================
er_fn er_mmio_read32
    mov     eax, [rdi]
    ret

; ==================================================================
; er_mmio_write32 — write 32-bit to MMIO address
; void er_mmio_write32(uint64_t addr, uint32_t value)
; ==================================================================
er_fn er_mmio_write32
    mov     [rdi], esi
    ret

; ==================================================================
; er_port_in8 — read 8-bit from I/O port
; uint8_t er_port_in8(uint16_t port)
; ==================================================================
er_fn er_port_in8
    mov     dx, di
    in      al, dx
    ret

; ==================================================================
; er_port_out8 — write 8-bit to I/O port
; void er_port_out8(uint16_t port, uint8_t value)
; ==================================================================
er_fn er_port_out8
    mov     dx, di
    mov     al, sil
    out     dx, al
    ret

; ==================================================================
; er_spin_delay — busy-wait loop
; void er_spin_delay(uint32_t iterations)
; ==================================================================
er_fn er_spin_delay
.loop:
    pause
    dec     esi
    jnz     .loop
    ret
