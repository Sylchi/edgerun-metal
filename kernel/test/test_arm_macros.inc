@ Shared ARM semihosted test helpers.

.macro TEST_ARM_CALL fn
    bl      \fn
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code
.endm

.macro TEST_ARM_CALL_CODE fn, code
    bl      \fn
    cmp     r0, #0
    movne   r4, #\code
    bne     .Lfail_code
.endm

.macro TEST_ARM_EXPECT_ZERO
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code
.endm

.macro TEST_ARM_EXPECT_ZERO_CODE code
    cmp     r0, #0
    movne   r4, #\code
    bne     .Lfail_code
.endm

.macro TEST_ARM_EXPECT_EQ_CODE value, code
    cmp     r0, #\value
    movne   r4, #\code
    bne     .Lfail_code
.endm

.macro TEST_ARM_EXIT_OK
    mov     r0, #0
    b       semihost_exit
.endm

.macro TEST_ARM_EXIT_FAIL
.Lfail_code:
    mov     r0, r4
    b       semihost_exit
.endm
