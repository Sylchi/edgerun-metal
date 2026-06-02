; EdgeRun shared media bit reader helpers — x86_64 assembly.

%include "x86_64/macros.inc"
%include "x86_64/wasm_defines.inc"

MEDIA_MSB_READER_BUFFER_OFF    equ 16
MEDIA_MSB_READER_BITS_LEFT_OFF equ 17
MEDIA_MSB_READER_MAX_BITS      equ 16

; er_media_msb_read_bit(state, next_byte_fn) -> eax=bit, rdx=error
er_fn er_media_msb_read_bit
    er_push rbx, r12
    er_check_zero rdi, .invalid_param
    er_check_zero rsi, .invalid_param
    mov     r12, rdi
    mov     rbx, rsi
    cmp     byte [r12 + MEDIA_MSB_READER_BITS_LEFT_OFF], 0
    jne     .have_bits
    call    rbx
    test    edx, edx
    jnz     .done
    mov     [r12 + MEDIA_MSB_READER_BUFFER_OFF], al
    mov     byte [r12 + MEDIA_MSB_READER_BITS_LEFT_OFF], 8
.have_bits:
    dec     byte [r12 + MEDIA_MSB_READER_BITS_LEFT_OFF]
    movzx   ecx, byte [r12 + MEDIA_MSB_READER_BITS_LEFT_OFF]
    movzx   eax, byte [r12 + MEDIA_MSB_READER_BUFFER_OFF]
    shr     eax, cl
    and     eax, 1
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
.done:
    er_pop  rbx, r12
    er_ret

; er_media_msb_read_bits(state, count, next_byte_fn) -> eax=value, rdx=error
er_fn er_media_msb_read_bits
    er_push rbx, r12, r13, r14
    er_check_zero rdi, .invalid_param
    er_check_zero rdx, .invalid_param
    cmp     esi, MEDIA_MSB_READER_MAX_BITS
    ja      .corrupt
    mov     r12, rdi
    mov     ebx, esi
    mov     r13, rdx
    xor     r14d, r14d
.loop:
    test    ebx, ebx
    jz      .ok
    mov     rdi, r12
    mov     rsi, r13
    call    er_media_msb_read_bit
    test    edx, edx
    jnz     .done
    shl     r14d, 1
    or      r14d, eax
    dec     ebx
    jmp     .loop
.ok:
    mov     eax, r14d
    er_ok
    jmp     .done
.invalid_param:
    xor     eax, eax
    er_err  ERROR_INVALID_PARAM
    jmp     .done
.corrupt:
    xor     eax, eax
    er_err  ERROR_CORRUPT
.done:
    er_pop  rbx, r12, r13, r14
    er_ret
