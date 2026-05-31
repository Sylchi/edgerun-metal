@ EdgeRun Pi Zero W EMMC SD block emulator test.

.syntax unified
.cpu arm1176jzf-s
.arm

.equ EMMC_BLKSIZECNT, 0x04
.equ EMMC_ARG1,       0x08
.equ EMMC_CMDTM,      0x0c
.equ EMMC_DATA,       0x20
.equ EMMC_INTERRUPT,  0x30
.equ EMMC_SCRATCH,    0x100

.equ CMD17_VAL,       (17 << 24) | (2 << 16) | (1 << 19) | (1 << 20) | (1 << 21) | (1 << 1) | (1 << 4)
.equ CMD24_VAL,       (24 << 24) | (2 << 16) | (1 << 19) | (1 << 20) | (1 << 21) | (1 << 1)
.equ INT_CMD_DONE,    (1 << 0)
.equ INT_DATA_DONE,   (1 << 1)
.equ INT_WRITE_READY, (1 << 4)
.equ INT_READ_READY,  (1 << 5)
.equ INT_ERROR,       (1 << 15)
.equ BLOCK_WORDS,     128
.equ BLOCK_BYTES,     512
.equ BLOCK_COUNT_ONE, 1
.equ BLKSIZECNT_SINGLE, BLOCK_BYTES | (BLOCK_COUNT_ONE << 16)
.equ SDHC_LBA,        7
.equ SDSC_LBA,        3
.equ SDHC_FLAG,       1
.equ SDSC_FLAG,       0
.equ OP_NONE,         0
.equ OP_READ,         1
.equ OP_WRITE,        2
.equ PHASE_IDLE,      0
.equ PHASE_CMD,       1
.equ PHASE_READY,     2
.equ PHASE_DATA,      3
.equ READ_BASE,       0x50000000
.equ WRITE_BASE,      0x60000000

.extern emmc_read_block
.extern emmc_write_block

.section .text.startup,"ax",%progbits
.globl _start
_start:
    ldr     sp, =stack_top

    bl      test_sdhc_read_block
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_sdsc_read_uses_byte_address
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_sdhc_write_block
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_read_null_buffer_rejected
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_write_null_buffer_rejected
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_read_misaligned_buffer_rejected
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_write_misaligned_buffer_rejected
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_read_command_error_rejected
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_write_command_error_rejected
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_read_ready_error_rejected
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_write_ready_error_rejected
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_read_data_done_error_rejected
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_write_data_done_error_rejected
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    mov     r0, #0
    b       semihost_exit

.Lfail_code:
    mov     r0, r4
    b       semihost_exit

test_sdhc_read_block:
    push    {lr}
    mov     r0, #SDHC_FLAG
    bl      reset_sd_emulator
    mov     r0, #SDHC_LBA
    ldr     r1, =read_buffer
    bl      emmc_read_block
    cmp     r0, #0
    movne   r0, #11
    popne   {pc}
    bl      check_read_command_sdhc
    cmp     r0, #0
    popne   {pc}
    bl      check_read_buffer
    pop     {pc}

test_sdsc_read_uses_byte_address:
    push    {lr}
    mov     r0, #SDSC_FLAG
    bl      reset_sd_emulator
    mov     r0, #SDSC_LBA
    ldr     r1, =read_buffer
    bl      emmc_read_block
    cmp     r0, #0
    movne   r0, #21
    popne   {pc}
    ldr     r1, =last_arg1
    ldr     r0, [r1]
    ldr     r2, =(SDSC_LBA << 9)
    cmp     r0, r2
    movne   r0, #22
    popne   {pc}
    mov     r0, #0
    pop     {pc}

test_sdhc_write_block:
    push    {lr}
    mov     r0, #SDHC_FLAG
    bl      reset_sd_emulator
    bl      fill_write_source
    mov     r0, #SDHC_LBA
    ldr     r1, =write_source
    bl      emmc_write_block
    cmp     r0, #0
    movne   r0, #31
    popne   {pc}
    bl      check_write_command
    cmp     r0, #0
    popne   {pc}
    bl      check_write_capture
    pop     {pc}

test_read_null_buffer_rejected:
    push    {lr}
    mov     r0, #SDHC_FLAG
    bl      reset_sd_emulator
    mov     r0, #SDHC_LBA
    mov     r1, #0
    bl      emmc_read_block
    cmp     r0, #1
    movne   r0, #41
    popne   {pc}
    bl      check_no_command_issued
    cmp     r0, #0
    moveq   r0, #0
    movne   r0, #42
    pop     {pc}

test_write_null_buffer_rejected:
    push    {lr}
    mov     r0, #SDHC_FLAG
    bl      reset_sd_emulator
    mov     r0, #SDHC_LBA
    mov     r1, #0
    bl      emmc_write_block
    cmp     r0, #1
    movne   r0, #43
    popne   {pc}
    bl      check_no_command_issued
    cmp     r0, #0
    moveq   r0, #0
    movne   r0, #44
    pop     {pc}

test_read_misaligned_buffer_rejected:
    push    {lr}
    mov     r0, #SDHC_FLAG
    bl      reset_sd_emulator
    mov     r0, #SDHC_LBA
    ldr     r1, =read_buffer
    add     r1, r1, #1
    bl      emmc_read_block
    cmp     r0, #1
    movne   r0, #45
    popne   {pc}
    bl      check_no_command_issued
    cmp     r0, #0
    moveq   r0, #0
    movne   r0, #46
    pop     {pc}

test_write_misaligned_buffer_rejected:
    push    {lr}
    mov     r0, #SDHC_FLAG
    bl      reset_sd_emulator
    mov     r0, #SDHC_LBA
    ldr     r1, =write_source
    add     r1, r1, #1
    bl      emmc_write_block
    cmp     r0, #1
    movne   r0, #47
    popne   {pc}
    bl      check_no_command_issued
    cmp     r0, #0
    moveq   r0, #0
    movne   r0, #48
    pop     {pc}

test_read_command_error_rejected:
    push    {lr}
    mov     r0, #SDHC_FLAG
    bl      reset_sd_emulator
    ldr     r1, =error_phase
    mov     r0, #PHASE_CMD
    str     r0, [r1]
    mov     r0, #SDHC_LBA
    ldr     r1, =read_buffer
    bl      emmc_read_block
    cmp     r0, #1
    movne   r0, #51
    popne   {pc}
    bl      check_no_fifo_transfer
    cmp     r0, #0
    moveq   r0, #0
    movne   r0, #52
    pop     {pc}

test_write_command_error_rejected:
    push    {lr}
    mov     r0, #SDHC_FLAG
    bl      reset_sd_emulator
    bl      fill_write_source
    ldr     r1, =error_phase
    mov     r0, #PHASE_CMD
    str     r0, [r1]
    mov     r0, #SDHC_LBA
    ldr     r1, =write_source
    bl      emmc_write_block
    cmp     r0, #1
    movne   r0, #59
    popne   {pc}
    bl      check_no_fifo_transfer
    cmp     r0, #0
    moveq   r0, #0
    movne   r0, #60
    pop     {pc}

test_read_ready_error_rejected:
    push    {lr}
    mov     r0, #SDHC_FLAG
    bl      reset_sd_emulator
    ldr     r1, =error_phase
    mov     r0, #PHASE_READY
    str     r0, [r1]
    mov     r0, #SDHC_LBA
    ldr     r1, =read_buffer
    bl      emmc_read_block
    cmp     r0, #1
    movne   r0, #61
    popne   {pc}
    bl      check_no_fifo_transfer
    cmp     r0, #0
    moveq   r0, #0
    movne   r0, #62
    pop     {pc}

test_write_ready_error_rejected:
    push    {lr}
    mov     r0, #SDHC_FLAG
    bl      reset_sd_emulator
    bl      fill_write_source
    ldr     r1, =error_phase
    mov     r0, #PHASE_READY
    str     r0, [r1]
    mov     r0, #SDHC_LBA
    ldr     r1, =write_source
    bl      emmc_write_block
    cmp     r0, #1
    movne   r0, #53
    popne   {pc}
    bl      check_no_fifo_transfer
    cmp     r0, #0
    moveq   r0, #0
    movne   r0, #54
    pop     {pc}

test_read_data_done_error_rejected:
    push    {lr}
    mov     r0, #SDHC_FLAG
    bl      reset_sd_emulator
    ldr     r1, =error_phase
    mov     r0, #PHASE_DATA
    str     r0, [r1]
    mov     r0, #SDHC_LBA
    ldr     r1, =read_buffer
    bl      emmc_read_block
    cmp     r0, #1
    movne   r0, #55
    popne   {pc}
    bl      check_read_fifo_full_transfer
    cmp     r0, #0
    moveq   r0, #0
    movne   r0, #56
    pop     {pc}

test_write_data_done_error_rejected:
    push    {lr}
    mov     r0, #SDHC_FLAG
    bl      reset_sd_emulator
    bl      fill_write_source
    ldr     r1, =error_phase
    mov     r0, #PHASE_DATA
    str     r0, [r1]
    mov     r0, #SDHC_LBA
    ldr     r1, =write_source
    bl      emmc_write_block
    cmp     r0, #1
    movne   r0, #57
    popne   {pc}
    bl      check_write_fifo_full_transfer
    cmp     r0, #0
    moveq   r0, #0
    movne   r0, #58
    pop     {pc}

check_read_command_sdhc:
    push    {lr}
    ldr     r1, =last_arg1
    ldr     r0, [r1]
    cmp     r0, #SDHC_LBA
    movne   r0, #12
    popne   {pc}
    ldr     r1, =last_blksizecnt
    ldr     r0, [r1]
    ldr     r2, =BLKSIZECNT_SINGLE
    cmp     r0, r2
    movne   r0, #13
    popne   {pc}
    ldr     r1, =last_cmdtm
    ldr     r0, [r1]
    ldr     r2, =CMD17_VAL
    cmp     r0, r2
    movne   r0, #14
    popne   {pc}
    ldr     r1, =data_read_count
    ldr     r0, [r1]
    cmp     r0, #BLOCK_WORDS
    movne   r0, #15
    popne   {pc}
    mov     r0, #0
    pop     {pc}

check_read_buffer:
    push    {r4, lr}
    ldr     r4, =read_buffer
    ldr     r0, [r4]
    ldr     r1, =READ_BASE
    cmp     r0, r1
    movne   r0, #16
    popne   {r4, pc}
    ldr     r0, [r4, #4]
    add     r1, r1, #1
    cmp     r0, r1
    movne   r0, #17
    popne   {r4, pc}
    ldr     r0, [r4, #508]
    ldr     r1, =(READ_BASE + 127)
    cmp     r0, r1
    movne   r0, #18
    popne   {r4, pc}
    mov     r0, #0
    pop     {r4, pc}

check_write_command:
    push    {lr}
    ldr     r1, =last_arg1
    ldr     r0, [r1]
    cmp     r0, #SDHC_LBA
    movne   r0, #32
    popne   {pc}
    ldr     r1, =last_blksizecnt
    ldr     r0, [r1]
    ldr     r2, =BLKSIZECNT_SINGLE
    cmp     r0, r2
    movne   r0, #33
    popne   {pc}
    ldr     r1, =last_cmdtm
    ldr     r0, [r1]
    ldr     r2, =CMD24_VAL
    cmp     r0, r2
    movne   r0, #34
    popne   {pc}
    ldr     r1, =data_write_count
    ldr     r0, [r1]
    cmp     r0, #BLOCK_WORDS
    movne   r0, #35
    popne   {pc}
    mov     r0, #0
    pop     {pc}

check_write_capture:
    push    {r4, lr}
    ldr     r4, =write_capture
    ldr     r0, [r4]
    ldr     r1, =WRITE_BASE
    cmp     r0, r1
    movne   r0, #36
    popne   {r4, pc}
    ldr     r0, [r4, #4]
    add     r1, r1, #1
    cmp     r0, r1
    movne   r0, #37
    popne   {r4, pc}
    ldr     r0, [r4, #508]
    ldr     r1, =(WRITE_BASE + 127)
    cmp     r0, r1
    movne   r0, #38
    popne   {r4, pc}
    mov     r0, #0
    pop     {r4, pc}

check_no_command_issued:
    push    {lr}
    ldr     r1, =last_arg1
    ldr     r0, [r1]
    cmp     r0, #0
    movne   r0, #1
    popne   {pc}
    ldr     r1, =last_blksizecnt
    ldr     r0, [r1]
    cmp     r0, #0
    movne   r0, #1
    popne   {pc}
    ldr     r1, =last_cmdtm
    ldr     r0, [r1]
    cmp     r0, #0
    movne   r0, #1
    popne   {pc}
    mov     r0, #0
    pop     {pc}

check_no_fifo_transfer:
    push    {lr}
    ldr     r1, =data_read_count
    ldr     r0, [r1]
    cmp     r0, #0
    movne   r0, #1
    popne   {pc}
    ldr     r1, =data_write_count
    ldr     r0, [r1]
    cmp     r0, #0
    movne   r0, #1
    popne   {pc}
    mov     r0, #0
    pop     {pc}

check_read_fifo_full_transfer:
    push    {lr}
    ldr     r1, =data_read_count
    ldr     r0, [r1]
    cmp     r0, #BLOCK_WORDS
    movne   r0, #1
    popne   {pc}
    ldr     r1, =data_write_count
    ldr     r0, [r1]
    cmp     r0, #0
    movne   r0, #1
    popne   {pc}
    mov     r0, #0
    pop     {pc}

check_write_fifo_full_transfer:
    push    {lr}
    ldr     r1, =data_read_count
    ldr     r0, [r1]
    cmp     r0, #0
    movne   r0, #1
    popne   {pc}
    ldr     r1, =data_write_count
    ldr     r0, [r1]
    cmp     r0, #BLOCK_WORDS
    movne   r0, #1
    popne   {pc}
    mov     r0, #0
    pop     {pc}

fill_write_source:
    push    {r4, lr}
    ldr     r1, =write_source
    ldr     r2, =WRITE_BASE
    mov     r3, #BLOCK_WORDS
1:
    str     r2, [r1], #4
    add     r2, r2, #1
    subs    r3, r3, #1
    bne     1b
    pop     {r4, pc}

reset_sd_emulator:
    push    {lr}
    ldr     r1, =sdhc_flag
    str     r0, [r1]
    mov     r0, #0
    ldr     r1, =last_arg1
    str     r0, [r1]
    ldr     r1, =last_blksizecnt
    str     r0, [r1]
    ldr     r1, =last_cmdtm
    str     r0, [r1]
    ldr     r1, =active_op
    str     r0, [r1]
    ldr     r1, =active_phase
    str     r0, [r1]
    ldr     r1, =data_read_count
    str     r0, [r1]
    ldr     r1, =data_write_count
    str     r0, [r1]
    ldr     r1, =error_phase
    str     r0, [r1]
    pop     {pc}

.globl emmc_mmio_read
emmc_mmio_read:
    cmp     r0, #EMMC_SCRATCH
    bne     1f
    ldr     r1, =sdhc_flag
    ldr     r0, [r1]
    bx      lr
1:
    cmp     r0, #EMMC_INTERRUPT
    bne     2f
    ldr     r1, =active_phase
    ldr     r2, [r1]
    ldr     r1, =error_phase
    ldr     r3, [r1]
    cmp     r2, r3
    moveq   r0, #INT_ERROR
    bxeq    lr
    cmp     r2, #PHASE_CMD
    moveq   r0, #INT_CMD_DONE
    bxeq    lr
    cmp     r2, #PHASE_READY
    bne     3f
    ldr     r1, =active_op
    ldr     r2, [r1]
    cmp     r2, #OP_READ
    moveq   r0, #INT_READ_READY
    movne   r0, #INT_WRITE_READY
    bx      lr
3:
    cmp     r2, #PHASE_DATA
    moveq   r0, #INT_DATA_DONE
    movne   r0, #0
    bx      lr
2:
    cmp     r0, #EMMC_DATA
    moveq   r0, #0
    bne     4f
    ldr     r1, =data_read_count
    ldr     r2, [r1]
    add     r3, r2, #1
    str     r3, [r1]
    ldr     r0, =READ_BASE
    add     r0, r0, r2
    bx      lr
4:
    mov     r0, #0
    bx      lr

.globl emmc_mmio_write
emmc_mmio_write:
    cmp     r0, #EMMC_ARG1
    ldreq   r2, =last_arg1
    streq   r1, [r2]
    bxeq    lr
    cmp     r0, #EMMC_BLKSIZECNT
    ldreq   r2, =last_blksizecnt
    streq   r1, [r2]
    bxeq    lr
    cmp     r0, #EMMC_CMDTM
    beq     write_cmdtm
    cmp     r0, #EMMC_INTERRUPT
    beq     write_interrupt
    cmp     r0, #EMMC_DATA
    beq     write_data
    bx      lr

write_cmdtm:
    ldr     r2, =last_cmdtm
    str     r1, [r2]
    ldr     r2, =active_phase
    mov     r3, #PHASE_CMD
    str     r3, [r2]
    ldr     r2, =active_op
    ldr     r3, =CMD17_VAL
    cmp     r1, r3
    moveq   r3, #OP_READ
    streq   r3, [r2]
    ldr     r3, =CMD24_VAL
    cmp     r1, r3
    moveq   r3, #OP_WRITE
    streq   r3, [r2]
    bx      lr

write_interrupt:
    ldr     r2, =active_phase
    ldr     r3, [r2]
    cmp     r3, #PHASE_CMD
    moveq   r3, #PHASE_READY
    streq   r3, [r2]
    bxeq    lr
    cmp     r3, #PHASE_READY
    moveq   r3, #PHASE_DATA
    streq   r3, [r2]
    bxeq    lr
    mov     r3, #PHASE_IDLE
    str     r3, [r2]
    bx      lr

write_data:
    ldr     r2, =data_write_count
    ldr     r3, [r2]
    add     r12, r3, #1
    str     r12, [r2]
    ldr     r2, =write_capture
    str     r1, [r2, r3, lsl #2]
    bx      lr

semihost_exit:
    ldr     r1, =exit_block
    str     r0, [r1, #4]
    mov     r0, #0x20
    svc     #0x123456
1:  b       1b

.section .data
.align 4
exit_block:
    .word   0x20026
    .word   0

.section .bss
.align 4
sdhc_flag:
    .space  4
last_arg1:
    .space  4
last_blksizecnt:
    .space  4
last_cmdtm:
    .space  4
active_op:
    .space  4
active_phase:
    .space  4
data_read_count:
    .space  4
data_write_count:
    .space  4
error_phase:
    .space  4
read_buffer:
    .space  BLOCK_BYTES
write_source:
    .space  BLOCK_BYTES
write_capture:
    .space  BLOCK_BYTES
stack_bottom:
    .space  4096
stack_top:
