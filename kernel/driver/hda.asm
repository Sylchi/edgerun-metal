; EdgeRun High Definition Audio controller probe — x86_64 assembly
; System V AMD64 ABI
; Freestanding — no libc, no external dependencies.

%include "x86_64/macros.inc"
%include "driver/pci_constants.inc"
%include "x86_64/wasm_defines.inc"

extern er_pci_read32
extern er_pci_write32
extern er_mmio_read32
extern er_mmio_write32
extern er_mmio_read16
extern er_mmio_write16
extern er_mmio_read8
extern er_mmio_write8

%define HDA_CLASS       0x04
%define HDA_SUBCLASS    0x03
%define HDA_PROGIF      0x00

%define HDA_REG_GCAP    0x00
%define HDA_REG_GCTL    0x08
%define HDA_REG_STATESTS_DWORD 0x0C
%define HDA_REG_ICOI    0x60
%define HDA_REG_ICII    0x64
%define HDA_REG_ICIS    0x68
%define HDA_REG_SD_BASE 0x80
%define HDA_GCTL_CRST   1
%define HDA_ICIS_ICB    1
%define HDA_ICIS_IRV    2
%define HDA_VERB_GET_PARAMETER 0xF00
%define HDA_VERB_SET_POWER_STATE 0x705
%define HDA_VERB_SET_CHANNEL_STREAM_ID 0x706
%define HDA_VERB_SET_PIN_WIDGET_CONTROL 0x707
%define HDA_VERB_SET_EAPD_BTL 0x70C
%define HDA_VERB_SET_CONVERTER_FORMAT 0x200
%define HDA_VERB_SET_AMP_GAIN_MUTE 0x300
%define HDA_PARAM_VENDOR_ID    0x00
%define HDA_PARAM_SUB_NODE_COUNT 0x04
%define HDA_FORMAT_PCM_48K_16_STEREO 0x0011
%define HDA_STREAM_TAG 1
%define HDA_SD_BYTES 0x20
%define HDA_SD_CTL_RUN 0x00000002
%define HDA_SD_CTL_SRST 0x00000001
%define HDA_SD_CTL_STREAM_TAG_SHIFT 20
%define HDA_SD_STS_CLEAR 0x1C
%define HDA_SD_LPIB 0x04
%define HDA_SD_CBL 0x08
%define HDA_SD_LVI 0x0C
%define HDA_SD_FMT 0x12
%define HDA_SD_BDPL 0x18
%define HDA_SD_BDPU 0x1C
%define HDA_TONE_BYTES 4096
%define HDA_TONE_PHASE_BIT 16

SECTION .bss
align 128
hda_bdl:          resb 16
align 128
hda_tone_buffer:  resb HDA_TONE_BYTES
hda_verb_sink:    resd 1
hda_last_sd_base: resd 1
hda_last_start_stage: resd 1

SECTION .text

; ==================================================================
; er_hda_probe_init — locate and minimally reset an HDA-compatible PCI fn
; int er_hda_probe_init(uint8_t bus, uint8_t dev, uint8_t func,
;                       uint32_t* out_bar0, uint32_t* out_gcap,
;                       uint32_t* out_statests)
; Returns eax=0 when the controller MMIO responds and reset bit sticks.
; ==================================================================
er_fn er_hda_probe_init
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    push    rbp

    mov     r12d, edi           ; bus
    mov     r13d, esi           ; dev
    mov     r14d, edx           ; func
    mov     r15, rcx            ; out_bar0
    mov     rbx, r8             ; out_gcap
    mov     rbp, r9             ; out_statests
    test    r15, r15
    jz      .bad_arg
    test    rbx, rbx
    jz      .bad_arg
    test    rbp, rbp
    jz      .bad_arg

    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    xor     ecx, ecx
    call    er_pci_read32
    cmp     eax, 0xFFFFFFFF
    je      .absent

    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    mov     ecx, 0x08
    call    er_pci_read32
    shr     eax, 8
    movzx   edx, al
    movzx   ecx, ah
    shr     eax, 16
    cmp     al, HDA_CLASS
    jne     .absent
    cmp     cl, HDA_SUBCLASS
    jne     .absent
    cmp     dl, HDA_PROGIF
    jne     .absent

    ; Enable memory decoding and bus mastering before MMIO access.
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    mov     ecx, PCI_COMMAND
    call    er_pci_read32
    or      eax, PCI_CMD_MEM_SPACE | PCI_CMD_BUS_MASTER
    mov     r8d, eax
    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    mov     ecx, PCI_COMMAND
    call    er_pci_write32

    mov     rdi, r12
    mov     rsi, r13
    mov     rdx, r14
    mov     ecx, PCI_BAR0
    call    er_pci_read32
    and     eax, ~0x0F
    test    eax, eax
    jz      .absent
    mov     [r15], eax

    mov     edi, [r15]
    add     edi, HDA_REG_GCAP
    call    er_mmio_read32
    movzx   eax, ax
    test    eax, eax
    jz      .absent
    mov     [rbx], eax

    ; Bring controller out of reset and wait for CRST to read back as 1.
    mov     edi, [r15]
    add     edi, HDA_REG_GCTL
    mov     esi, HDA_GCTL_CRST
    call    er_mmio_write32
    mov     ecx, 200000
.wait_crst:
    mov     edi, [r15]
    add     edi, HDA_REG_GCTL
    call    er_mmio_read32
    test    eax, HDA_GCTL_CRST
    jnz     .crst_ready
    dec     ecx
    jnz     .wait_crst
    jmp     .timeout
.crst_ready:
    mov     edi, [r15]
    add     edi, HDA_REG_STATESTS_DWORD
    call    er_mmio_read32
    shr     eax, 16
    and     eax, 0x7FFF
    mov     [rbp], eax
    xor     eax, eax
    er_ok
    jmp     .out

.bad_arg:
    er_err  ERROR_BAD_ARGUMENT
    mov     eax, -1
    jmp     .out
.absent:
    er_err  ERROR_NOT_PRESENT
    mov     eax, -1
    jmp     .out
.timeout:
    er_err  ERROR_TIMEOUT
    mov     eax, -1
.out:
    pop     rbp
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; _hda_first_codec — return first codec address present in STATESTS.
; edi=statests. Returns eax=codec address or -1.
_hda_first_codec:
    xor     eax, eax
.fc_loop:
    cmp     eax, 15
    jae     .fc_absent
    mov     edx, edi
    mov     ecx, eax
    shr     edx, cl
    test    edx, 1
    jnz     .fc_found
    inc     eax
    jmp     .fc_loop
.fc_found:
    ret
.fc_absent:
    mov     eax, -1
    ret

; ==================================================================
; er_hda_codec_get_parameter — immediate GET_PARAMETER codec verb
; int er_hda_codec_get_parameter(uint32_t bar0, uint32_t statests,
;                                uint32_t node_id, uint32_t parameter_id,
;                                uint32_t* out_value)
; Uses the first present codec address from STATESTS.
; ==================================================================
er_fn er_hda_codec_get_parameter
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12d, edi           ; bar0
    mov     r13d, esi           ; statests
    mov     r14d, edx           ; node id
    mov     r15d, ecx           ; parameter id
    mov     rbx, r8             ; out_value
    test    r12d, r12d
    jz      .cp_bad_arg
    test    r13d, r13d
    jz      .cp_absent
    test    rbx, rbx
    jz      .cp_bad_arg
    cmp     r14d, 0xFF
    ja      .cp_bad_arg
    cmp     r15d, 0xFF
    ja      .cp_bad_arg

    mov     edi, r13d
    call    _hda_first_codec
    cmp     eax, -1
    je      .cp_absent

    ; Command: codec address, node id, GET_PARAMETER, parameter id.
    shl     eax, 28
    mov     edx, r14d
    shl     edx, 20
    or      eax, edx
    mov     ecx, HDA_VERB_GET_PARAMETER
    shl     ecx, 8
    or      eax, ecx
    or      eax, r15d
    mov     r13d, eax

    mov     ecx, 200000
.cp_wait_idle:
    mov     edi, r12d
    add     edi, HDA_REG_ICIS
    call    er_mmio_read32
    test    eax, HDA_ICIS_ICB
    jz      .cp_idle
    dec     ecx
    jnz     .cp_wait_idle
    jmp     .cp_timeout
.cp_idle:
    mov     edi, r12d
    add     edi, HDA_REG_ICOI
    mov     esi, r13d
    call    er_mmio_write32

    mov     edi, r12d
    add     edi, HDA_REG_ICIS
    mov     esi, HDA_ICIS_ICB
    call    er_mmio_write32

    mov     ecx, 200000
.cp_wait_done:
    mov     edi, r12d
    add     edi, HDA_REG_ICIS
    call    er_mmio_read32
    test    eax, HDA_ICIS_ICB
    jnz     .cp_spin
    test    eax, HDA_ICIS_IRV
    jnz     .cp_have_response
.cp_spin:
    dec     ecx
    jnz     .cp_wait_done
    jmp     .cp_timeout
.cp_have_response:
    mov     edi, r12d
    add     edi, HDA_REG_ICII
    call    er_mmio_read32
    mov     [rbx], eax
    mov     edi, r12d
    add     edi, HDA_REG_ICIS
    mov     esi, HDA_ICIS_IRV
    call    er_mmio_write32
    xor     eax, eax
    er_ok
    jmp     .cp_out

.cp_bad_arg:
    er_err  ERROR_BAD_ARGUMENT
    mov     eax, -1
    jmp     .cp_out
.cp_absent:
    er_err  ERROR_NOT_PRESENT
    mov     eax, -1
    jmp     .cp_out
.cp_timeout:
    er_err  ERROR_TIMEOUT
    mov     eax, -1
.cp_out:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; ==================================================================
; er_hda_codec_send_verb — immediate arbitrary codec verb
; int er_hda_codec_send_verb(uint32_t bar0, uint32_t statests,
;                            uint32_t node_id, uint32_t verb,
;                            uint32_t payload, uint32_t* out_response)
; Uses the first present codec address from STATESTS.
; ==================================================================
er_fn er_hda_codec_send_verb
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15
    push    rbp

    mov     r12d, edi           ; bar0
    mov     r13d, esi           ; statests
    mov     r14d, edx           ; node id
    mov     r15d, ecx           ; verb
    mov     ebp, r8d            ; payload
    mov     rbx, r9             ; out_response
    test    r12d, r12d
    jz      .sv_bad_arg
    test    r13d, r13d
    jz      .sv_absent
    cmp     r14d, 0xFF
    ja      .sv_bad_arg
    cmp     r15d, 0xFFF
    ja      .sv_bad_arg
    cmp     ebp, 0xFF
    ja      .sv_bad_arg

    mov     edi, r13d
    call    _hda_first_codec
    cmp     eax, -1
    je      .sv_absent

    shl     eax, 28
    mov     edx, r14d
    shl     edx, 20
    or      eax, edx
    mov     ecx, r15d
    shl     ecx, 8
    or      eax, ecx
    or      eax, ebp
    mov     r13d, eax

    mov     ecx, 200000
.sv_wait_idle:
    mov     edi, r12d
    add     edi, HDA_REG_ICIS
    call    er_mmio_read32
    test    eax, HDA_ICIS_ICB
    jz      .sv_idle
    dec     ecx
    jnz     .sv_wait_idle
    jmp     .sv_timeout
.sv_idle:
    mov     edi, r12d
    add     edi, HDA_REG_ICOI
    mov     esi, r13d
    call    er_mmio_write32
    mov     edi, r12d
    add     edi, HDA_REG_ICIS
    mov     esi, HDA_ICIS_ICB
    call    er_mmio_write32

    mov     ecx, 200000
.sv_wait_done:
    mov     edi, r12d
    add     edi, HDA_REG_ICIS
    call    er_mmio_read32
    test    eax, HDA_ICIS_ICB
    jnz     .sv_spin
    test    eax, HDA_ICIS_IRV
    jnz     .sv_have_response
.sv_spin:
    dec     ecx
    jnz     .sv_wait_done
    jmp     .sv_timeout
.sv_have_response:
    mov     edi, r12d
    add     edi, HDA_REG_ICII
    call    er_mmio_read32
    test    rbx, rbx
    jz      .sv_clear
    mov     [rbx], eax
.sv_clear:
    mov     edi, r12d
    add     edi, HDA_REG_ICIS
    mov     esi, HDA_ICIS_IRV
    call    er_mmio_write32
    xor     eax, eax
    er_ok
    jmp     .sv_out

.sv_bad_arg:
    er_err  ERROR_BAD_ARGUMENT
    mov     eax, -1
    jmp     .sv_out
.sv_absent:
    er_err  ERROR_NOT_PRESENT
    mov     eax, -1
    jmp     .sv_out
.sv_timeout:
    er_err  ERROR_TIMEOUT
    mov     eax, -1
.sv_out:
    pop     rbp
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; ==================================================================
; er_hda_codec_vendor_id — read root Vendor ID parameter
; int er_hda_codec_vendor_id(uint32_t bar0, uint32_t statests,
;                            uint32_t* out_vendor_id)
; ==================================================================
er_fn er_hda_codec_vendor_id
    mov     r8, rdx
    xor     edx, edx
    mov     ecx, HDA_PARAM_VENDOR_ID
    jmp     er_hda_codec_get_parameter

; ==================================================================
; er_hda_codec_root_nodes — read root Subordinate Node Count parameter
; int er_hda_codec_root_nodes(uint32_t bar0, uint32_t statests,
;                             uint32_t* out_node_count)
; ==================================================================
er_fn er_hda_codec_root_nodes
    mov     r8, rdx
    xor     edx, edx
    mov     ecx, HDA_PARAM_SUB_NODE_COUNT
    jmp     er_hda_codec_get_parameter

; ==================================================================
; er_hda_alc295_prepare_speaker — minimal ALC295 speaker route
; int er_hda_alc295_prepare_speaker(uint32_t bar0, uint32_t statests)
; Route: DAC 0x02 -> speaker pin 0x14, D0 power, EAPD on, pin OUT.
; ==================================================================
er_fn er_hda_alc295_prepare_speaker
    push    r12
    push    r13
    mov     r12d, edi
    mov     r13d, esi

    ; AFG, DAC, and speaker pin to D0.
    mov     edi, r12d
    mov     esi, r13d
    mov     edx, 0x01
    mov     ecx, HDA_VERB_SET_POWER_STATE
    xor     r8d, r8d
    lea     r9, [rel hda_verb_sink]
    call    er_hda_codec_send_verb
    test    eax, eax
    jnz     .ps_out
    mov     edi, r12d
    mov     esi, r13d
    mov     edx, 0x02
    mov     ecx, HDA_VERB_SET_POWER_STATE
    xor     r8d, r8d
    lea     r9, [rel hda_verb_sink]
    call    er_hda_codec_send_verb
    test    eax, eax
    jnz     .ps_out
    mov     edi, r12d
    mov     esi, r13d
    mov     edx, 0x14
    mov     ecx, HDA_VERB_SET_POWER_STATE
    xor     r8d, r8d
    lea     r9, [rel hda_verb_sink]
    call    er_hda_codec_send_verb
    test    eax, eax
    jnz     .ps_out

    ; DAC 0x02 uses stream tag 1/channel 0 and 48 kHz 16-bit stereo.
    mov     edi, r12d
    mov     esi, r13d
    mov     edx, 0x02
    mov     ecx, HDA_VERB_SET_CHANNEL_STREAM_ID
    mov     r8d, (HDA_STREAM_TAG << 4)
    lea     r9, [rel hda_verb_sink]
    call    er_hda_codec_send_verb
    test    eax, eax
    jnz     .ps_out
    mov     edi, r12d
    mov     esi, r13d
    mov     edx, 0x02
    mov     ecx, HDA_VERB_SET_CONVERTER_FORMAT
    mov     r8d, HDA_FORMAT_PCM_48K_16_STEREO
    lea     r9, [rel hda_verb_sink]
    call    er_hda_codec_send_verb
    test    eax, eax
    jnz     .ps_out

    ; Unmute DAC output and speaker pin output, then enable EAPD and OUT.
    mov     edi, r12d
    mov     esi, r13d
    mov     edx, 0x02
    mov     ecx, HDA_VERB_SET_AMP_GAIN_MUTE
    mov     r8d, 0xB0
    lea     r9, [rel hda_verb_sink]
    call    er_hda_codec_send_verb
    test    eax, eax
    jnz     .ps_out
    mov     edi, r12d
    mov     esi, r13d
    mov     edx, 0x14
    mov     ecx, HDA_VERB_SET_AMP_GAIN_MUTE
    mov     r8d, 0xB0
    lea     r9, [rel hda_verb_sink]
    call    er_hda_codec_send_verb
    test    eax, eax
    jnz     .ps_out
    mov     edi, r12d
    mov     esi, r13d
    mov     edx, 0x14
    mov     ecx, HDA_VERB_SET_EAPD_BTL
    mov     r8d, 0x02
    lea     r9, [rel hda_verb_sink]
    call    er_hda_codec_send_verb
    test    eax, eax
    jnz     .ps_out
    mov     edi, r12d
    mov     esi, r13d
    mov     edx, 0x14
    mov     ecx, HDA_VERB_SET_PIN_WIDGET_CONTROL
    mov     r8d, 0x40
    lea     r9, [rel hda_verb_sink]
    call    er_hda_codec_send_verb
.ps_out:
    pop     r13
    pop     r12
    ret

; ==================================================================
; er_hda_start_square_wave — start one output stream on static tone buffer
; int er_hda_start_square_wave(uint32_t bar0, uint32_t gcap)
; ==================================================================
er_fn er_hda_start_square_wave
    push    rbx
    push    r12
    push    r13
    push    r14

    mov     r12d, edi
    mov     r13d, esi
    mov     dword [rel hda_last_start_stage], 0
    test    r12d, r12d
    jz      .sq_bad_arg

    ; Fill 48 kHz stereo 16-bit square-wave samples.
    lea     rdi, [rel hda_tone_buffer]
    mov     ecx, HDA_TONE_BYTES / 4
    xor     ebx, ebx
.sq_fill:
    mov     eax, ebx
    test    eax, HDA_TONE_PHASE_BIT
    jz      .sq_pos
    mov     eax, 0xD000D000
    jmp     .sq_store
.sq_pos:
    mov     eax, 0x30003000
.sq_store:
    mov     [rdi], eax
    add     rdi, 4
    inc     ebx
    dec     ecx
    jnz     .sq_fill

    lea     rax, [rel hda_tone_buffer]
    mov     [rel hda_bdl + 0], rax
    mov     dword [rel hda_bdl + 8], HDA_TONE_BYTES
    mov     dword [rel hda_bdl + 12], 1

    ; First output stream descriptor is after input streams.
    mov     eax, r13d
    shr     eax, 8
    and     eax, 0x0F
    imul    eax, HDA_SD_BYTES
    add     eax, HDA_REG_SD_BASE
    add     eax, r12d
    mov     r14d, eax
    mov     [rel hda_last_sd_base], eax

    ; Reset stream descriptor.
    mov     edi, r14d
    mov     esi, HDA_SD_CTL_SRST
    call    er_mmio_write8
    mov     ecx, 200000
.sq_wait_srst:
    mov     edi, r14d
    call    er_mmio_read8
    test    eax, HDA_SD_CTL_SRST
    jnz     .sq_srst_set
    dec     ecx
    jnz     .sq_wait_srst
    mov     dword [rel hda_last_start_stage], 2
    jmp     .sq_timeout
.sq_srst_set:
    mov     edi, r14d
    xor     esi, esi
    call    er_mmio_write8
    mov     ecx, 200000
.sq_wait_clear:
    mov     edi, r14d
    call    er_mmio_read8
    test    eax, HDA_SD_CTL_SRST
    jz      .sq_ready
    dec     ecx
    jnz     .sq_wait_clear
    mov     dword [rel hda_last_start_stage], 3
    jmp     .sq_timeout
.sq_ready:
    mov     edi, r14d
    add     edi, 0x03
    mov     esi, HDA_SD_STS_CLEAR
    call    er_mmio_write8
    mov     edi, r14d
    add     edi, HDA_SD_CBL
    mov     esi, HDA_TONE_BYTES
    call    er_mmio_write32
    mov     edi, r14d
    add     edi, HDA_SD_LVI
    xor     esi, esi
    call    er_mmio_write16
    mov     edi, r14d
    add     edi, HDA_SD_FMT
    mov     esi, HDA_FORMAT_PCM_48K_16_STEREO
    call    er_mmio_write16
    lea     rax, [rel hda_bdl]
    mov     edi, r14d
    add     edi, HDA_SD_BDPL
    mov     esi, eax
    call    er_mmio_write32
    lea     rax, [rel hda_bdl]
    shr     rax, 32
    mov     edi, r14d
    add     edi, HDA_SD_BDPU
    mov     esi, eax
    call    er_mmio_write32
    mov     edi, r14d
    mov     esi, HDA_SD_CTL_RUN
    call    er_mmio_write8
    mov     edi, r14d
    add     edi, 0x02
    mov     esi, HDA_STREAM_TAG << 4
    call    er_mmio_write8
    mov     edi, r14d
    call    er_mmio_read32
    test    eax, HDA_SD_CTL_RUN
    jnz     .sq_run_ok
    mov     dword [rel hda_last_start_stage], 4
    jmp     .sq_timeout
.sq_run_ok:
    mov     edi, r14d
    add     edi, HDA_SD_CBL
    call    er_mmio_read32
    cmp     eax, HDA_TONE_BYTES
    je      .sq_success
    mov     dword [rel hda_last_start_stage], 5
    jmp     .sq_timeout
.sq_success:
    xor     eax, eax
    er_ok
    jmp     .sq_out
.sq_bad_arg:
    mov     dword [rel hda_last_start_stage], 1
    er_err  ERROR_BAD_ARGUMENT
    mov     eax, -1
    jmp     .sq_out
.sq_timeout:
    er_err  ERROR_TIMEOUT
    mov     eax, -1
.sq_out:
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret

; ==================================================================
; er_hda_get_start_stage — read last square-wave start stage
; uint32_t er_hda_get_start_stage(void)
; 0=success/not-run, 1=bad-arg, 2=reset-assert timeout,
; 3=reset-clear timeout, 4=RUN did not stick, 5=CBL mismatch.
; ==================================================================
er_fn er_hda_get_start_stage
    mov     eax, [rel hda_last_start_stage]
    er_ok
    ret

; ==================================================================
; er_hda_get_stream_debug — read first output stream descriptor state
; int er_hda_get_stream_debug(uint32_t bar0, uint32_t gcap,
;                             uint32_t* out_ctl, uint32_t* out_sts,
;                             uint32_t* out_lpib, uint32_t* out_cbl)
; ==================================================================
er_fn er_hda_get_stream_debug
    push    rbx
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12d, edi           ; bar0
    mov     r13d, esi           ; gcap
    mov     rbx, rdx            ; out_ctl
    mov     r14, rcx            ; out_sts
    mov     r15, r8             ; out_lpib
    test    r12d, r12d
    jz      .sd_bad_arg
    test    rbx, rbx
    jz      .sd_bad_arg
    test    r14, r14
    jz      .sd_bad_arg
    test    r15, r15
    jz      .sd_bad_arg
    test    r9, r9
    jz      .sd_bad_arg

    mov     eax, r13d
    shr     eax, 8
    and     eax, 0x0F
    imul    eax, HDA_SD_BYTES
    add     eax, HDA_REG_SD_BASE
    add     eax, r12d
    mov     r13d, eax

    mov     edi, r13d
    call    er_mmio_read32
    mov     [rbx], eax
    mov     edi, r13d
    add     edi, 0x03
    call    er_mmio_read8
    mov     [r14], eax
    mov     edi, r13d
    add     edi, HDA_SD_LPIB
    call    er_mmio_read32
    mov     [r15], eax
    mov     edi, r13d
    add     edi, HDA_SD_CBL
    call    er_mmio_read32
    mov     [r9], eax
    xor     eax, eax
    er_ok
    jmp     .sd_out
.sd_bad_arg:
    er_err  ERROR_BAD_ARGUMENT
    mov     eax, -1
.sd_out:
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbx
    ret
