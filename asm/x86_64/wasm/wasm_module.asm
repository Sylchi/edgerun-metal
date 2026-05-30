; EdgeRun WASM Module Manager — x86_64 assembly
; Module registry + pipeline runner for sequential module execution.
; Modules share linear memory; data flows through return values and memory.
; System V AMD64 ABI: rax=value, rdx=0=ok or error.

%include "x86_64/macros.inc"
%include "x86_64/wasm/wasm_constants.inc"   ; includes wasm_defines.inc

extern er_fn_run
extern er_fn_init
extern er_wasm_parse_module
extern er_wasm_find_export
extern er_wasm_apply_data_segments
extern er_memcpy

; Module descriptor: { name_ptr(8), name_len(8), wasm_ptr(8), wasm_len(8) }
MODULE_DESC_SIZE equ 32

SECTION .bss
module_descs:       resb MAX_MODULES * MODULE_DESC_SIZE
module_desc_count:  resq 1

SECTION .text

; ============================================================
; module_load(rdi=name_ptr, rsi=name_len, rdx=wasm_ptr, rcx=wasm_len)
; Register a module descriptor.  Returns module_id in rax.
; ============================================================
global module_load
module_load:
    er_frame_push
    push    rbx
    push    r12

    mov     r12, [module_desc_count]
    cmp     r12, MAX_MODULES
    jae     .full

    mov     rbx, r12
    imul    rbx, MODULE_DESC_SIZE
    mov     [module_descs + rbx],      rdi   ; name_ptr
    mov     [module_descs + rbx + 8],  rsi   ; name_len
    mov     [module_descs + rbx + 16], rdx   ; wasm_ptr
    mov     [module_descs + rbx + 24], rcx   ; wasm_len

    inc     qword [module_desc_count]
    mov     rax, r12
    er_ok

    pop     r12
    pop     rbx
    pop     rbp
    ret

.full:
    er_err  ERROR_NO_MEMORY
    pop     r12
    pop     rbx
    pop     rbp
    ret

; ============================================================
; module_run_export(rdi=module_id, rsi=runtime, rdx=name, rcx=name_len)
; Parse + execute a module's export.  Returns rax=result, rdx=error.
; ============================================================
global module_run_export
module_run_export:
    er_frame_push
    push    r12                         ; module_id
    push    r13                         ; runtime_ptr
    push    r14                         ; export_name
    push    r15                         ; export_name_len

    mov     r12, rdi
    mov     r13, rsi
    mov     r14, rdx
    mov     r15, rcx

    cmp     r12, [module_desc_count]
    jae     .bad

    ; Load module wasm bytes from descriptor table
    mov     rbx, r12
    imul    rbx, MODULE_DESC_SIZE
    mov     rsi, [module_descs + rbx + 16]   ; wasm_ptr
    mov     rdx, [module_descs + rbx + 24]   ; wasm_len

    ; er_fn_run(rdi=runtime, rsi=wasm, rdx=len, rcx=name, r8=name_len)
    mov     rdi, r13
    mov     rcx, r14
    mov     r8,  r15
    call    er_fn_run

    ; rax = result, rdx = error
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    ret

.bad:
    er_err  ERROR_BAD_ARGUMENT
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    ret

; ============================================================
; module_find_by_name(rdi=name_ptr, rsi=name_len)
; Linear scan.  Returns module_id in rax (+ edx=0) or error.
; ============================================================
global module_find_by_name
module_find_by_name:
    er_frame_push
    push    r12
    push    r13

    mov     r12, rdi                    ; target name ptr
    mov     r13, rsi                    ; target name len
    xor     r11d, r11d                  ; index

.loop:
    cmp     r11, [module_desc_count]
    jae     .nf

    mov     rbx, r11
    imul    rbx, MODULE_DESC_SIZE
    mov     rdi, [module_descs + rbx]       ; candidate name ptr
    mov     rsi, [module_descs + rbx + 8]   ; candidate name len

    cmp     rsi, r13
    jne     .next

    ; Length matches — compare bytes
    xor     ecx, ecx
.cmp_loop:
    cmp     ecx, r13d
    jae     .found
    movzx   eax, byte [r12 + rcx]
    movzx   edx, byte [rdi + rcx]
    cmp     al,  dl
    jne     .next
    inc     ecx
    jmp     .cmp_loop

.found:
    mov     rax, r11
    er_ok
    pop     r13
    pop     r12
    pop     rbp
    ret

.next:
    inc     r11
    jmp     .loop

.nf:
    er_err  ERROR_MISSING_IMPORT
    xor     eax, eax
    pop     r13
    pop     r12
    pop     rbp
    ret

; ============================================================
; module_count()
; Returns number of registered modules in rax.
; ============================================================
global module_count
module_count:
    mov     rax, [module_desc_count]
    er_ok
    ret
