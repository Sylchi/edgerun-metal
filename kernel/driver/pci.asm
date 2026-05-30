; EdgeRun PCI configuration space access driver — x86_64 assembly
; System V AMD64 ABI
; Freestanding — no libc, no external dependencies.
;
; Accesses PCI configuration space via the legacy I/O port mechanism
; (CONFIG_ADDRESS at 0xCF8, CONFIG_DATA at 0xCFC).

%include "x86_64/macros.inc"
%include "driver/pci_constants.inc"

%define PCI_ADDR_PORT   0xCF8
%define PCI_DATA_PORT   0xCFC

; NVMe class code
%define NVME_CLASS      0x01
%define NVME_SUBCLASS   0x08
%define NVME_PROGIF     0x02

SECTION .text

; ==================================================================
; er_pci_read32 — read 32-bit from PCI config space
; uint32_t er_pci_read32(uint8_t bus, uint8_t dev, uint8_t func,
;                        uint16_t offset)
;
; Registers: rdi=bus, rsi=dev, rdx=func, rcx=offset
; Returns:   eax = dword value from config space
; ==================================================================
er_fn er_pci_read32
    push    rbx
    mov     eax, 0x80000000
    mov     al, cl
    and     al, 0xFC
    mov     ebx, edx
    and     ebx, 0x07
    shl     ebx, 8
    or      eax, ebx
    mov     ebx, esi
    and     ebx, 0x1F
    shl     ebx, 11
    or      eax, ebx
    mov     ebx, edi
    shl     ebx, 16
    or      eax, ebx

    mov     dx, PCI_ADDR_PORT
    out     dx, eax
    mov     dx, PCI_DATA_PORT
    in      eax, dx
    pop     rbx
    er_ok
    ret

; ==================================================================
; er_pci_write32 — write 32-bit to PCI config space
; void er_pci_write32(uint8_t bus, uint8_t dev, uint8_t func,
;                     uint16_t offset, uint32_t val)
;
; Registers: rdi=bus, rsi=dev, rdx=func, rcx=offset, r8=val
; ==================================================================
er_fn er_pci_write32
    push    r8
    push    rbx

    mov     eax, 0x80000000
    mov     al, cl
    and     al, 0xFC
    mov     ebx, edx
    and     ebx, 0x07
    shl     ebx, 8
    or      eax, ebx
    mov     ebx, esi
    and     ebx, 0x1F
    shl     ebx, 11
    or      eax, ebx
    mov     ebx, edi
    shl     ebx, 16
    or      eax, ebx

    mov     dx, PCI_ADDR_PORT
    out     dx, eax
    mov     eax, r8d
    mov     dx, PCI_DATA_PORT
    out     dx, eax

    pop     rbx
    pop     r8
    er_ok
    ret

; ==================================================================
; er_pci_find_class — find first PCI device matching class/subclass/prog-if
; int er_pci_find_class(uint8_t class, uint8_t subclass,
;                       uint8_t prog_if, uint8_t* out_bus,
;                       uint8_t* out_dev, uint8_t* out_func)
;
; Args: rdi=class, rsi=subclass, rdx=prog_if, rcx=out_bus,
;       r8=out_dev, r9=out_func
;
; Scans all 256 PCI buses (0-255) for a matching class/subclass/prog-if.
; Non-existent buses/devices return 0xFFFFFFFF via the standard
; 0xCF8/0xCFC config mechanism and are skipped.
; Returns: eax = 1 if found, 0 if not found
; ==================================================================
er_fn er_pci_find_class
    push    rbx
    push    rbp
    push    r12
    push    r13
    push    r14
    push    r15
    push    r8              ; save out_dev pointer
    push    r9              ; save out_func pointer

    mov     r12d, edi       ; class
    mov     r13d, esi       ; subclass
    mov     r14d, edx       ; prog_if
    mov     r15, rcx        ; out_bus

    xor     ebx, ebx        ; bus = 0
.bus_loop:
    xor     r8d, r8d        ; dev = 0
.dev_loop:
    xor     r10d, r10d      ; func = 0
.func_loop:
    push    r8
    push    r10

    mov     rdi, rbx        ; bus
    mov     rsi, r8         ; dev
    mov     rdx, r10        ; func
    xor     ecx, ecx        ; offset 0 (VID/DID)
    call    er_pci_read32

    pop     r10
    pop     r8

    cmp     eax, 0xFFFFFFFF
    je      .next_func

    push    r8
    push    r10

    mov     rdi, rbx
    mov     rsi, r8
    mov     rdx, r10
    mov     ecx, 0x08       ; class code offset
    call    er_pci_read32

    pop     r10
    pop     r8

    ; eax = CC:SS:PP:RR (class:subclass:prog-if:revision)
    shr     eax, 8          ; eax = 0x00CCSSPP
    movzx   edx, al         ; edx = PP (prog-if)
    movzx   ecx, ah         ; ecx = SS (subclass)
    shr     eax, 16         ; al = CC (class)

    cmp     al, r12b
    jne     .next_func
    cmp     cl, r13b
    jne     .next_func
    cmp     dl, r14b
    jne     .next_func

    ; Found — store results
    mov     byte [r15], bl
    mov     rax, [rsp + 8]  ; out_dev pointer
    mov     byte [rax], r8b
    mov     rax, [rsp]      ; out_func pointer
    mov     byte [rax], r10b

    mov     eax, 1
    er_ok
    jmp     .out

.next_func:
    inc     r10
    cmp     r10b, 8
    jb      .func_loop
    inc     r8
    cmp     r8b, 32
    jb      .dev_loop
    inc     ebx
    cmp     ebx, 256        ; scan all 256 buses
    jb      .bus_loop

    xor     eax, eax
    er_ok
.out:
    pop     r9
    pop     r8
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
    ret

; ==================================================================
; er_pci_find_device — find first PCI device matching vendor/device id
; int er_pci_find_device(uint16_t vendor, uint16_t device, uint8_t* out_bus,
;                        uint8_t* out_dev, uint8_t* out_func)
;
; Args: rdi=vendor, rsi=device, rdx=out_bus, rcx=out_dev, r8=out_func
; Returns: eax = 1 if found, 0 if not found
; ==================================================================
er_fn er_pci_find_device
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    movzx   r12d, di            ; vendor
    movzx   r13d, si            ; device
    shl     r13d, 16
    or      r13d, r12d          ; target DID:VID in config dword 0
    mov     r14, rdx            ; out_bus
    mov     r15, rcx            ; out_dev

    xor     ebx, ebx            ; bus
.dev_bus_loop:
    xor     r9d, r9d            ; dev
.dev_dev_loop:
    xor     r10d, r10d          ; func
.dev_func_loop:
    mov     rdi, rbx
    mov     rsi, r9
    mov     rdx, r10
    xor     ecx, ecx            ; offset 0 (VID/DID)
    call    er_pci_read32
    cmp     eax, r13d
    jne     .dev_next_func

    mov     byte [r14], bl
    mov     byte [r15], r9b
    mov     byte [r8], r10b
    mov     eax, 1
    er_ok
    jmp     .dev_out

.dev_next_func:
    inc     r10d
    cmp     r10d, 8
    jb      .dev_func_loop
    inc     r9d
    cmp     r9d, 32
    jb      .dev_dev_loop
    inc     ebx
    cmp     ebx, 256
    jb      .dev_bus_loop

    xor     eax, eax
    er_ok
.dev_out:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; ==================================================================
; er_pci_find_nvme — find NVMe controller on bus 0
; int er_pci_find_nvme(uint8_t* out_bus, uint8_t* out_dev,
;                      uint8_t* out_func)
;
; Args: rdi=out_bus, rsi=out_dev, rdx=out_func
; Returns: eax = 1 if found, 0 if not found
; ==================================================================
er_fn er_pci_find_nvme
    mov     rcx, rdi        ; out_bus → 4th arg
    mov     r8, rsi         ; out_dev → 5th arg
    mov     r9, rdx         ; out_func → 6th arg
    mov     edi, NVME_CLASS
    mov     esi, NVME_SUBCLASS
    mov     edx, NVME_PROGIF
    jmp     er_pci_find_class
