@ EdgeRun Pi Zero W DWC2 USB host initialization emulator test.

.syntax unified
.cpu arm1176jzf-s
.arm

.equ DWC_GAHBCFG,           0x008
.equ DWC_GUSBCFG,           0x00c
.equ DWC_GRSTCTL,           0x010
.equ DWC_GINTMSK,           0x018
.equ DWC_GRXFSIZ,           0x024
.equ DWC_GNPTXFSIZ,         0x028
.equ DWC_CID,               0x040
.equ DWC_HPTXFSIZ,          0x100
.equ DWC_HCFG,              0x400
.equ DWC_HFIR,              0x404
.equ DWC_HPRT,              0x440

.equ DWC2_CORE_ID_310A,     0x4f54230b
.equ GRSTCTL_CSFTRST,       (1 << 0)
.equ GRSTCTL_AHBIDLE,       (1 << 31)
.equ GAHBCFG_GLBL_INTR_EN,  (1 << 0)
.equ GUSBCFG_PHYIF,         (1 << 6)
.equ GUSBCFG_ULPI_UTMI_SEL, (1 << 4)
.equ GUSBCFG_FS_INTF,       (1 << 5)
.equ GUSBCFG_SRPCAP,        (1 << 8)
.equ GUSBCFG_HNPCAP,        (1 << 9)
.equ GUSBCFG_TRDT_SHIFT,    10
.equ GUSBCFG_TRDT_MASK,     (0xf << 10)
.equ HCFG_FSLSS,            (1 << 2)
.equ HCFG_FSLS_PHOST,       (1 << 3)
.equ HPRT_PRTENA,           (1 << 0)
.equ HPRT_PRTCONNDET,       (1 << 2)
.equ HPRT_PRTRST,           (1 << 6)
.equ HPRT_PRTPWR,           (1 << 9)
.equ HPRT_SPD_FS,           (1 << 17)
.equ HPRR_PRT_SPD_SHIFT,    17
.equ HPRR_PRT_SPD_MASK,     (3 << 17)
.equ GINT_HC_INT,           (1 << 25)
.equ GINT_PRT_INT,          (1 << 24)
.equ GINT_DISC_INT,         (1 << 28)
.equ FIFO_SIZE_128,         128
.equ TRACE_LIMIT,           32
.equ ETH_CTRL_IF,           0
.equ ETH_DATA_IF,           1
.equ ETH_BULK_IN_EP,        0x81
.equ ETH_BULK_OUT_EP,       0x02
.equ ETH_BULK_MPS,          64
.equ MSC_IF,                2
.equ MSC_BULK_IN_EP,        0x84
.equ MSC_BULK_OUT_EP,       0x05
.equ MSC_BULK_MPS,          64
.equ MSC_DEV_ADDR_VALUE,    7
.equ MSC_DEV_SPEED_VALUE,   1
.equ MSC_TEST_LBA_BYTE0,    0x01
.equ MSC_TEST_LBA_BYTE1,    0x23
.equ MSC_TEST_LBA_BYTE2,    0x45
.equ MSC_TEST_LBA_BYTE3,    0x67
.equ XFER_DEVADDR,          0
.equ XFER_EPNUM,            1
.equ XFER_EPTYPE,           2
.equ XFER_DIR,              3
.equ XFER_MPS,              4
.equ XFER_SPEED,            6
.equ XFER_BUF,              8
.equ XFER_LEN,              12
.equ MSC_DEV_ADDR,          0
.equ MSC_DEV_SPEED,         1
.equ MSC_DEV_BULK_IN_EP,    2
.equ MSC_DEV_BULK_OUT_EP,   3
.equ MSC_DEV_BULK_IN_MPS,   4
.equ MSC_DEV_BULK_OUT_MPS,  6
.equ MSC_DEV_TAG,           8
.equ USB_DIR_IN,            0x80
.equ USB_MSC_CBW_SIGNATURE, 0x43425355
.equ USB_MSC_CSW_SIGNATURE, 0x53425355
.equ USB_MSC_CBW_LEN,       31
.equ USB_MSC_CSW_LEN,       13
.equ USB_MSC_BLOCK_SIZE,    512
.equ USB_MSC_SCSI_READ10,   0x28
.equ USB_MSC_SCSI_TEST_READY, 0x00
.equ USB_MSC_SCSI_INQUIRY,  0x12
.equ USB_MSC_SCSI_READ_CAP10, 0x25
.equ MSC_TEST_TAG,          0x11223344
.equ MSC_READ_MARKER,       0xa5c35a3c

.extern dwc2_init
.extern dwc2_port_detect
.extern dwc2_find_ethernet_config
.extern dwc2_find_mass_storage_config
.extern dwc2_msc_test_unit_ready
.extern dwc2_msc_inquiry
.extern dwc2_msc_read_capacity10
.extern dwc2_msc_read10

.section .text.startup,"ax",%progbits
.globl _start
_start:
    ldr     sp, =stack_top

    bl      test_dwc2_init_programs_core
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_dwc2_init_rejects_bad_core
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_dwc2_init_ahb_idle_timeout
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_dwc2_init_reset_timeout
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_dwc2_port_detect_reports_speed
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_dwc2_port_detect_resets_to_enable
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_dwc2_port_detect_reset_timeout
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_dwc2_port_detect_rejects_null
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_dwc2_find_ethernet_ecm
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_dwc2_find_ethernet_ncm
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_dwc2_rejects_incomplete_ethernet
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_dwc2_find_mass_storage
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_dwc2_rejects_incomplete_mass_storage
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_dwc2_rejects_bad_mass_storage_protocol
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_dwc2_msc_read10_bot
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_dwc2_msc_test_unit_ready_bot
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_dwc2_msc_inquiry_bot
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_dwc2_msc_read_capacity_bot
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    bl      test_dwc2_msc_read10_rejects_bad_csw
    cmp     r0, #0
    movne   r4, r0
    bne     .Lfail_code

    mov     r0, #0
    b       semihost_exit

.Lfail_code:
    mov     r0, r4
    b       semihost_exit

test_dwc2_init_programs_core:
    push    {lr}
    bl      reset_usb_emulator
    ldr     r1, =core_id
    ldr     r0, =DWC2_CORE_ID_310A
    str     r0, [r1]
    bl      dwc2_init
    cmp     r0, #0
    movne   r0, #11
    popne   {pc}
    bl      check_usb_init_registers
    pop     {pc}

test_dwc2_init_rejects_bad_core:
    push    {lr}
    bl      reset_usb_emulator
    ldr     r1, =core_id
    ldr     r0, =0x12345678
    str     r0, [r1]
    bl      dwc2_init
    cmp     r0, #1
    movne   r0, #31
    popne   {pc}
    ldr     r1, =write_count
    ldr     r0, [r1]
    cmp     r0, #0
    movne   r0, #32
    popne   {pc}
    mov     r0, #0
    pop     {pc}

test_dwc2_init_ahb_idle_timeout:
    push    {lr}
    bl      reset_usb_emulator
    ldr     r1, =core_id
    ldr     r0, =DWC2_CORE_ID_310A
    str     r0, [r1]
    ldr     r1, =ahb_idle_enabled
    mov     r0, #0
    str     r0, [r1]
    bl      dwc2_init
    cmp     r0, #1
    movne   r0, #33
    popne   {pc}
    ldr     r1, =write_count
    ldr     r0, [r1]
    cmp     r0, #0
    movne   r0, #34
    popne   {pc}
    mov     r0, #0
    pop     {pc}

test_dwc2_init_reset_timeout:
    push    {lr}
    bl      reset_usb_emulator
    ldr     r1, =core_id
    ldr     r0, =DWC2_CORE_ID_310A
    str     r0, [r1]
    ldr     r1, =reset_clears
    mov     r0, #0
    str     r0, [r1]
    bl      dwc2_init
    cmp     r0, #1
    movne   r0, #35
    popne   {pc}
    ldr     r1, =write_count
    ldr     r0, [r1]
    cmp     r0, #1
    movne   r0, #36
    popne   {pc}
    mov     r0, #0
    pop     {pc}

test_dwc2_port_detect_reports_speed:
    push    {lr}
    bl      reset_usb_emulator
    ldr     r1, =hprt_value
    ldr     r0, =(HPRT_PRTCONNDET | HPRT_PRTENA | HPRT_SPD_FS)
    str     r0, [r1]
    ldr     r0, =speed_out
    bl      dwc2_port_detect
    cmp     r0, #0
    movne   r0, #41
    popne   {pc}
    ldr     r1, =speed_out
    ldrb    r0, [r1]
    cmp     r0, #1
    movne   r0, #42
    popne   {pc}
    ldr     r1, =hprt_value
    ldr     r0, [r1]
    tst     r0, #HPRT_PRTPWR
    moveq   r0, #43
    popeq   {pc}
    ldr     r1, =hprt_write_count
    ldr     r0, [r1]
    cmp     r0, #2
    movne   r0, #44
    popne   {pc}
    mov     r0, #0
    pop     {pc}

test_dwc2_port_detect_resets_to_enable:
    push    {lr}
    bl      reset_usb_emulator
    ldr     r1, =hprt_value
    ldr     r0, =(HPRT_PRTCONNDET | HPRT_SPD_FS)
    str     r0, [r1]
    ldr     r1, =hprt_reset_enables
    mov     r0, #1
    str     r0, [r1]
    ldr     r0, =speed_out
    bl      dwc2_port_detect
    cmp     r0, #0
    movne   r0, #47
    popne   {pc}
    ldr     r1, =speed_out
    ldrb    r0, [r1]
    cmp     r0, #1
    movne   r0, #48
    popne   {pc}
    ldr     r1, =hprt_reset_seen
    ldr     r0, [r1]
    cmp     r0, #1
    movne   r0, #49
    popne   {pc}
    ldr     r1, =hprt_value
    ldr     r0, [r1]
    tst     r0, #HPRT_PRTENA
    moveq   r0, #50
    popeq   {pc}
    tst     r0, #HPRT_PRTRST
    movne   r0, #51
    popne   {pc}
    mov     r0, #0
    pop     {pc}

test_dwc2_port_detect_reset_timeout:
    push    {lr}
    bl      reset_usb_emulator
    ldr     r1, =hprt_value
    ldr     r0, =(HPRT_PRTCONNDET | HPRT_SPD_FS)
    str     r0, [r1]
    ldr     r0, =speed_out
    bl      dwc2_port_detect
    cmp     r0, #1
    movne   r0, #52
    popne   {pc}
    ldr     r1, =hprt_reset_seen
    ldr     r0, [r1]
    cmp     r0, #1
    movne   r0, #53
    popne   {pc}
    ldr     r1, =speed_out
    ldrb    r0, [r1]
    cmp     r0, #0
    movne   r0, #54
    popne   {pc}
    mov     r0, #0
    pop     {pc}

test_dwc2_port_detect_rejects_null:
    push    {lr}
    bl      reset_usb_emulator
    mov     r0, #0
    bl      dwc2_port_detect
    cmp     r0, #1
    movne   r0, #45
    popne   {pc}
    ldr     r1, =write_count
    ldr     r0, [r1]
    cmp     r0, #0
    movne   r0, #46
    popne   {pc}
    mov     r0, #0
    pop     {pc}

test_dwc2_find_ethernet_ecm:
    push    {lr}
    ldr     r0, =ecm_config_desc
    mov     r1, #ecm_config_desc_len
    ldr     r2, =eth_out
    bl      dwc2_find_ethernet_config
    cmp     r0, #0
    movne   r0, #61
    popne   {pc}
    bl      check_eth_out
    cmp     r0, #0
    moveq   r0, #0
    movne   r0, #62
    pop     {pc}

test_dwc2_find_ethernet_ncm:
    push    {lr}
    ldr     r0, =ncm_config_desc
    mov     r1, #ncm_config_desc_len
    ldr     r2, =eth_out
    bl      dwc2_find_ethernet_config
    cmp     r0, #0
    movne   r0, #63
    popne   {pc}
    bl      check_eth_out
    cmp     r0, #0
    moveq   r0, #0
    movne   r0, #64
    pop     {pc}

test_dwc2_rejects_incomplete_ethernet:
    push    {lr}
    ldr     r0, =incomplete_config_desc
    mov     r1, #incomplete_config_desc_len
    ldr     r2, =eth_out
    bl      dwc2_find_ethernet_config
    cmp     r0, #1
    movne   r0, #65
    popne   {pc}
    mov     r0, #0
    pop     {pc}

test_dwc2_find_mass_storage:
    push    {lr}
    ldr     r0, =msc_config_desc
    mov     r1, #msc_config_desc_len
    ldr     r2, =msc_out
    bl      dwc2_find_mass_storage_config
    cmp     r0, #0
    movne   r0, #66
    popne   {pc}
    bl      check_msc_out
    cmp     r0, #0
    moveq   r0, #0
    movne   r0, #67
    pop     {pc}

test_dwc2_rejects_incomplete_mass_storage:
    push    {lr}
    ldr     r0, =incomplete_msc_config_desc
    mov     r1, #incomplete_msc_config_desc_len
    ldr     r2, =msc_out
    bl      dwc2_find_mass_storage_config
    cmp     r0, #1
    movne   r0, #68
    popne   {pc}
    mov     r0, #0
    pop     {pc}

test_dwc2_rejects_bad_mass_storage_protocol:
    push    {lr}
    ldr     r0, =bad_msc_protocol_desc
    mov     r1, #bad_msc_protocol_desc_len
    ldr     r2, =msc_out
    bl      dwc2_find_mass_storage_config
    cmp     r0, #1
    movne   r0, #69
    popne   {pc}
    mov     r0, #0
    pop     {pc}

test_dwc2_msc_read10_bot:
    push    {lr}
    bl      reset_msc_bulk_emulator
    ldr     r0, =msc_read_block
    bl      set_msc_read10_expectation
    ldr     r0, =msc_dev
    ldr     r1, =0x01234567
    ldr     r2, =msc_read_block
    bl      dwc2_msc_read10
    cmp     r0, #0
    movne   r0, #70
    popne   {pc}
    ldr     r1, =msc_bulk_phase
    ldr     r0, [r1]
    cmp     r0, #3
    movne   r0, #71
    popne   {pc}
    ldr     r1, =msc_dev
    ldr     r0, [r1, #MSC_DEV_TAG]
    ldr     r2, =(MSC_TEST_TAG + 1)
    cmp     r0, r2
    movne   r0, #72
    popne   {pc}
    ldr     r1, =msc_read_block
    ldr     r0, [r1]
    ldr     r2, =MSC_READ_MARKER
    cmp     r0, r2
    movne   r0, #73
    popne   {pc}
    mov     r0, #0
    pop     {pc}

test_dwc2_msc_test_unit_ready_bot:
    push    {lr}
    bl      reset_msc_bulk_emulator
    mov     r0, #USB_MSC_SCSI_TEST_READY
    mov     r1, #6
    mov     r2, #0
    mov     r3, #0
    bl      set_msc_expectation
    ldr     r0, =msc_dev
    bl      dwc2_msc_test_unit_ready
    cmp     r0, #0
    movne   r0, #76
    popne   {pc}
    ldr     r1, =msc_bulk_phase
    ldr     r0, [r1]
    cmp     r0, #2
    movne   r0, #77
    popne   {pc}
    mov     r0, #0
    pop     {pc}

test_dwc2_msc_inquiry_bot:
    push    {lr}
    bl      reset_msc_bulk_emulator
    ldr     r3, =msc_inquiry_buf
    mov     r0, #USB_MSC_SCSI_INQUIRY
    mov     r1, #6
    mov     r2, #36
    bl      set_msc_expectation
    ldr     r0, =msc_dev
    ldr     r1, =msc_inquiry_buf
    mov     r2, #36
    bl      dwc2_msc_inquiry
    cmp     r0, #0
    movne   r0, #78
    popne   {pc}
    ldr     r1, =msc_inquiry_buf
    ldr     r0, [r1]
    ldr     r2, =MSC_READ_MARKER
    cmp     r0, r2
    movne   r0, #79
    popne   {pc}
    mov     r0, #0
    pop     {pc}

test_dwc2_msc_read_capacity_bot:
    push    {lr}
    bl      reset_msc_bulk_emulator
    ldr     r3, =msc_capacity_buf
    mov     r0, #USB_MSC_SCSI_READ_CAP10
    mov     r1, #10
    mov     r2, #8
    bl      set_msc_expectation
    ldr     r0, =msc_dev
    ldr     r1, =msc_capacity_buf
    bl      dwc2_msc_read_capacity10
    cmp     r0, #0
    movne   r0, #80
    popne   {pc}
    ldr     r1, =msc_capacity_buf
    ldr     r0, [r1]
    ldr     r2, =MSC_READ_MARKER
    cmp     r0, r2
    movne   r0, #81
    popne   {pc}
    mov     r0, #0
    pop     {pc}

test_dwc2_msc_read10_rejects_bad_csw:
    push    {lr}
    bl      reset_msc_bulk_emulator
    ldr     r0, =msc_read_block
    bl      set_msc_read10_expectation
    ldr     r1, =msc_bulk_bad_csw
    mov     r0, #1
    str     r0, [r1]
    ldr     r0, =msc_dev
    ldr     r1, =0x01234567
    ldr     r2, =msc_read_block
    bl      dwc2_msc_read10
    cmp     r0, #1
    movne   r0, #74
    popne   {pc}
    ldr     r1, =msc_bulk_phase
    ldr     r0, [r1]
    cmp     r0, #3
    movne   r0, #75
    popne   {pc}
    mov     r0, #0
    pop     {pc}

set_msc_read10_expectation:
    push    {lr}
    mov     r3, r0
    mov     r0, #USB_MSC_SCSI_READ10
    mov     r1, #10
    ldr     r2, =USB_MSC_BLOCK_SIZE
    bl      set_msc_expectation
    pop     {pc}

set_msc_expectation:
    ldr     r12, =msc_expected_opcode
    str     r0, [r12]
    ldr     r12, =msc_expected_cdb_len
    str     r1, [r12]
    ldr     r12, =msc_expected_data_len
    str     r2, [r12]
    ldr     r12, =msc_expected_data_buf
    str     r3, [r12]
    bx      lr

check_eth_out:
    push    {lr}
    ldr     r1, =eth_out
    ldrb    r0, [r1]
    cmp     r0, #ETH_CTRL_IF
    movne   r0, #1
    popne   {pc}
    ldrb    r0, [r1, #1]
    cmp     r0, #ETH_DATA_IF
    movne   r0, #1
    popne   {pc}
    ldrb    r0, [r1, #2]
    cmp     r0, #ETH_BULK_IN_EP
    movne   r0, #1
    popne   {pc}
    ldrb    r0, [r1, #3]
    cmp     r0, #ETH_BULK_OUT_EP
    movne   r0, #1
    popne   {pc}
    ldrh    r0, [r1, #4]
    cmp     r0, #ETH_BULK_MPS
    movne   r0, #1
    popne   {pc}
    ldrh    r0, [r1, #6]
    cmp     r0, #ETH_BULK_MPS
    movne   r0, #1
    popne   {pc}
    mov     r0, #0
    pop     {pc}

check_msc_out:
    push    {lr}
    ldr     r1, =msc_out
    ldrb    r0, [r1]
    cmp     r0, #MSC_IF
    movne   r0, #1
    popne   {pc}
    ldrb    r0, [r1, #2]
    cmp     r0, #MSC_BULK_IN_EP
    movne   r0, #1
    popne   {pc}
    ldrb    r0, [r1, #3]
    cmp     r0, #MSC_BULK_OUT_EP
    movne   r0, #1
    popne   {pc}
    ldrh    r0, [r1, #4]
    cmp     r0, #MSC_BULK_MPS
    movne   r0, #1
    popne   {pc}
    ldrh    r0, [r1, #6]
    cmp     r0, #MSC_BULK_MPS
    movne   r0, #1
    popne   {pc}
    mov     r0, #0
    pop     {pc}

check_usb_init_registers:
    push    {lr}
    ldr     r1, =grxfsiz_value
    ldr     r0, [r1]
    cmp     r0, #FIFO_SIZE_128
    movne   r0, #12
    popne   {pc}
    ldr     r1, =gnptxfsiz_value
    ldr     r0, [r1]
    ldr     r2, =(FIFO_SIZE_128 | (FIFO_SIZE_128 << 16))
    cmp     r0, r2
    movne   r0, #13
    popne   {pc}
    ldr     r1, =hptxfsiz_value
    ldr     r0, [r1]
    ldr     r2, =(FIFO_SIZE_128 | ((FIFO_SIZE_128 + FIFO_SIZE_128) << 16))
    cmp     r0, r2
    movne   r0, #14
    popne   {pc}
    ldr     r1, =hfir_value
    ldr     r0, [r1]
    ldr     r2, =60000
    cmp     r0, r2
    movne   r0, #16
    popne   {pc}
    ldr     r1, =gintmsk_value
    ldr     r0, [r1]
    ldr     r2, =(GINT_HC_INT | GINT_PRT_INT | GINT_DISC_INT)
    cmp     r0, r2
    movne   r0, #17
    popne   {pc}
    ldr     r1, =gahbcfg_value
    ldr     r0, [r1]
    tst     r0, #GAHBCFG_GLBL_INTR_EN
    moveq   r0, #18
    popeq   {pc}
    ldr     r1, =gusbcfg_value
    ldr     r0, [r1]
    tst     r0, #GUSBCFG_PHYIF
    movne   r0, #19
    popne   {pc}
    tst     r0, #GUSBCFG_ULPI_UTMI_SEL
    movne   r0, #20
    popne   {pc}
    tst     r0, #GUSBCFG_FS_INTF
    movne   r0, #21
    popne   {pc}
    tst     r0, #GUSBCFG_SRPCAP
    movne   r0, #22
    popne   {pc}
    tst     r0, #GUSBCFG_HNPCAP
    movne   r0, #23
    popne   {pc}
    and     r0, r0, #GUSBCFG_TRDT_MASK
    ldr     r2, =(5 << GUSBCFG_TRDT_SHIFT)
    cmp     r0, r2
    movne   r0, #24
    popne   {pc}
    ldr     r1, =hcfg_value
    ldr     r0, [r1]
    tst     r0, #HCFG_FSLSS
    movne   r0, #25
    popne   {pc}
    tst     r0, #HCFG_FSLS_PHOST
    movne   r0, #26
    popne   {pc}
    mov     r0, #0
    pop     {pc}

reset_usb_emulator:
    push    {lr}
    mov     r0, #0
    ldr     r1, =write_count
    str     r0, [r1]
    ldr     r1, =reset_pending
    str     r0, [r1]
    ldr     r1, =ahb_idle_enabled
    mov     r0, #1
    str     r0, [r1]
    ldr     r1, =reset_clears
    str     r0, [r1]
    mov     r0, #0
    ldr     r1, =gahbcfg_value
    str     r0, [r1]
    ldr     r1, =gusbcfg_value
    ldr     r0, =(GUSBCFG_PHYIF | GUSBCFG_ULPI_UTMI_SEL | GUSBCFG_FS_INTF | GUSBCFG_SRPCAP | GUSBCFG_HNPCAP)
    str     r0, [r1]
    ldr     r1, =hcfg_value
    mov     r0, #(HCFG_FSLSS | HCFG_FSLS_PHOST)
    str     r0, [r1]
    mov     r0, #0
    ldr     r1, =hfir_value
    str     r0, [r1]
    ldr     r1, =grxfsiz_value
    str     r0, [r1]
    ldr     r1, =gnptxfsiz_value
    str     r0, [r1]
    ldr     r1, =hptxfsiz_value
    str     r0, [r1]
    ldr     r1, =gintmsk_value
    str     r0, [r1]
    ldr     r1, =hprt_value
    str     r0, [r1]
    ldr     r1, =hprt_write_count
    str     r0, [r1]
    ldr     r1, =hprt_reset_enables
    str     r0, [r1]
    ldr     r1, =hprt_reset_seen
    str     r0, [r1]
    ldr     r1, =speed_out
    str     r0, [r1]
    pop     {pc}

reset_msc_bulk_emulator:
    push    {lr}
    mov     r0, #0
    ldr     r1, =msc_bulk_phase
    str     r0, [r1]
    ldr     r1, =msc_bulk_bad_csw
    str     r0, [r1]
    ldr     r1, =msc_captured_tag
    str     r0, [r1]
    ldr     r1, =msc_expected_opcode
    str     r0, [r1]
    ldr     r1, =msc_expected_cdb_len
    str     r0, [r1]
    ldr     r1, =msc_expected_data_len
    str     r0, [r1]
    ldr     r1, =msc_expected_data_buf
    str     r0, [r1]
    ldr     r1, =msc_read_block
    str     r0, [r1]
    ldr     r1, =msc_dev
    mov     r0, #MSC_DEV_ADDR_VALUE
    strb    r0, [r1, #MSC_DEV_ADDR]
    mov     r0, #MSC_DEV_SPEED_VALUE
    strb    r0, [r1, #MSC_DEV_SPEED]
    mov     r0, #MSC_BULK_IN_EP
    strb    r0, [r1, #MSC_DEV_BULK_IN_EP]
    mov     r0, #MSC_BULK_OUT_EP
    strb    r0, [r1, #MSC_DEV_BULK_OUT_EP]
    mov     r0, #MSC_BULK_MPS
    strh    r0, [r1, #MSC_DEV_BULK_IN_MPS]
    strh    r0, [r1, #MSC_DEV_BULK_OUT_MPS]
    ldr     r0, =MSC_TEST_TAG
    str     r0, [r1, #MSC_DEV_TAG]
    pop     {pc}

.globl dwc2_mmio_read
dwc2_mmio_read:
    cmp     r0, #DWC_CID
    bne     1f
    ldr     r1, =core_id
    ldr     r0, [r1]
    bx      lr
1:
    cmp     r0, #DWC_GRSTCTL
    bne     2f
    ldr     r1, =ahb_idle_enabled
    ldr     r2, [r1]
    cmp     r2, #0
    moveq   r0, #0
    bxeq    lr
    ldr     r1, =reset_pending
    ldr     r2, [r1]
    cmp     r2, #0
    beq     7f
    ldr     r3, =reset_clears
    ldr     r0, [r3]
    cmp     r0, #0
    ldreq   r0, =(GRSTCTL_AHBIDLE | GRSTCTL_CSFTRST)
    bxeq    lr
    movne   r2, #0
    strne   r2, [r1]
7:
    mov     r0, #GRSTCTL_AHBIDLE
    bx      lr
2:
    cmp     r0, #DWC_GAHBCFG
    bne     3f
    ldr     r1, =gahbcfg_value
    ldr     r0, [r1]
    bx      lr
3:
    cmp     r0, #DWC_GUSBCFG
    bne     4f
    ldr     r1, =gusbcfg_value
    ldr     r0, [r1]
    bx      lr
4:
    ldr     r3, =DWC_HCFG
    cmp     r0, r3
    bne     5f
    ldr     r1, =hcfg_value
    ldr     r0, [r1]
    bx      lr
5:
    ldr     r3, =DWC_HPRT
    cmp     r0, r3
    bne     6f
    ldr     r1, =hprt_value
    ldr     r0, [r1]
    bx      lr
6:
    mov     r0, #0
    bx      lr

.globl dwc2_mmio_write
dwc2_mmio_write:
    ldr     r2, =write_count
    ldr     r3, [r2]
    add     r3, r3, #1
    str     r3, [r2]
    cmp     r0, #DWC_GRSTCTL
    bne     1f
    ldr     r2, =reset_pending
    str     r1, [r2]
    bx      lr
1:
    cmp     r0, #DWC_GAHBCFG
    ldreq   r2, =gahbcfg_value
    streq   r1, [r2]
    bxeq    lr
    cmp     r0, #DWC_GUSBCFG
    ldreq   r2, =gusbcfg_value
    streq   r1, [r2]
    bxeq    lr
    cmp     r0, #DWC_HCFG
    ldreq   r2, =hcfg_value
    streq   r1, [r2]
    bxeq    lr
    ldr     r3, =DWC_HFIR
    cmp     r0, r3
    ldreq   r2, =hfir_value
    streq   r1, [r2]
    bxeq    lr
    cmp     r0, #DWC_GRXFSIZ
    ldreq   r2, =grxfsiz_value
    streq   r1, [r2]
    bxeq    lr
    cmp     r0, #DWC_GNPTXFSIZ
    ldreq   r2, =gnptxfsiz_value
    streq   r1, [r2]
    bxeq    lr
    ldr     r3, =DWC_HPTXFSIZ
    cmp     r0, r3
    ldreq   r2, =hptxfsiz_value
    streq   r1, [r2]
    bxeq    lr
    cmp     r0, #DWC_GINTMSK
    ldreq   r2, =gintmsk_value
    streq   r1, [r2]
    bxeq    lr
    ldr     r3, =DWC_HPRT
    cmp     r0, r3
    bne     2f
    tst     r1, #HPRT_PRTRST
    beq     3f
    ldr     r2, =hprt_reset_seen
    mov     r3, #1
    str     r3, [r2]
3:
    tst     r1, #HPRT_PRTRST
    bne     4f
    ldr     r2, =hprt_reset_enables
    ldr     r3, [r2]
    cmp     r3, #0
    beq     4f
    ldr     r2, =hprt_reset_seen
    ldr     r3, [r2]
    cmp     r3, #0
    beq     4f
    orr     r1, r1, #HPRT_PRTENA
    bic     r1, r1, #HPRT_PRTRST
4:
    ldr     r2, =hprt_value
    str     r1, [r2]
    ldr     r2, =hprt_write_count
    ldr     r3, [r2]
    add     r3, r3, #1
    str     r3, [r2]
    bx      lr
2:
    bx      lr

.globl dwc2_msc_bulk_xfer
dwc2_msc_bulk_xfer:
    push    {r4, r5, r6, r7, lr}
    mov     r4, r0
    ldr     r5, =msc_bulk_phase
    ldr     r6, [r5]
    cmp     r6, #0
    beq     .Lmsc_bulk_cbw
    cmp     r6, #1
    beq     .Lmsc_bulk_data
    cmp     r6, #2
    beq     .Lmsc_bulk_csw
    mov     r0, #1
    pop     {r4, r5, r6, r7, pc}

.Lmsc_bulk_cbw:
    ldrb    r0, [r4, #XFER_DEVADDR]
    cmp     r0, #MSC_DEV_ADDR_VALUE
    movne   r0, #1
    popne   {r4, r5, r6, r7, pc}
    ldrb    r0, [r4, #XFER_EPNUM]
    cmp     r0, #MSC_BULK_OUT_EP
    movne   r0, #1
    popne   {r4, r5, r6, r7, pc}
    ldrb    r0, [r4, #XFER_DIR]
    cmp     r0, #0
    movne   r0, #1
    popne   {r4, r5, r6, r7, pc}
    ldr     r0, [r4, #XFER_LEN]
    cmp     r0, #USB_MSC_CBW_LEN
    movne   r0, #1
    popne   {r4, r5, r6, r7, pc}
    ldr     r7, [r4, #XFER_BUF]
    ldr     r0, [r7]
    ldr     r1, =USB_MSC_CBW_SIGNATURE
    cmp     r0, r1
    movne   r0, #1
    popne   {r4, r5, r6, r7, pc}
    ldr     r0, [r7, #4]
    ldr     r1, =MSC_TEST_TAG
    cmp     r0, r1
    movne   r0, #1
    popne   {r4, r5, r6, r7, pc}
    ldr     r1, =msc_captured_tag
    str     r0, [r1]
    ldr     r0, [r7, #8]
    ldr     r1, =msc_expected_data_len
    ldr     r1, [r1]
    cmp     r0, r1
    movne   r0, #1
    popne   {r4, r5, r6, r7, pc}
    ldrb    r0, [r7, #12]
    ldr     r1, =msc_expected_data_len
    ldr     r1, [r1]
    cmp     r1, #0
    moveq   r1, #0
    movne   r1, #USB_DIR_IN
    cmp     r0, r1
    movne   r0, #1
    popne   {r4, r5, r6, r7, pc}
    ldrb    r0, [r7, #14]
    ldr     r1, =msc_expected_cdb_len
    ldr     r1, [r1]
    cmp     r0, r1
    movne   r0, #1
    popne   {r4, r5, r6, r7, pc}
    ldrb    r0, [r7, #15]
    ldr     r1, =msc_expected_opcode
    ldr     r1, [r1]
    cmp     r0, r1
    movne   r0, #1
    popne   {r4, r5, r6, r7, pc}
    cmp     r0, #USB_MSC_SCSI_READ10
    bne     .Lmsc_bulk_cbw_done
    ldrb    r0, [r7, #17]
    cmp     r0, #MSC_TEST_LBA_BYTE0
    movne   r0, #1
    popne   {r4, r5, r6, r7, pc}
    ldrb    r0, [r7, #18]
    cmp     r0, #MSC_TEST_LBA_BYTE1
    movne   r0, #1
    popne   {r4, r5, r6, r7, pc}
    ldrb    r0, [r7, #19]
    cmp     r0, #MSC_TEST_LBA_BYTE2
    movne   r0, #1
    popne   {r4, r5, r6, r7, pc}
    ldrb    r0, [r7, #20]
    cmp     r0, #MSC_TEST_LBA_BYTE3
    movne   r0, #1
    popne   {r4, r5, r6, r7, pc}
    ldrb    r0, [r7, #23]
    cmp     r0, #1
    movne   r0, #1
    popne   {r4, r5, r6, r7, pc}
.Lmsc_bulk_cbw_done:
    mov     r0, #1
    str     r0, [r5]
    mov     r0, #0
    pop     {r4, r5, r6, r7, pc}

.Lmsc_bulk_data:
    ldr     r0, =msc_expected_data_len
    ldr     r1, [r0]
    cmp     r1, #0
    beq     .Lmsc_bulk_csw
    ldrb    r0, [r4, #XFER_EPNUM]
    and     r0, r0, #0x0f
    cmp     r0, #4
    movne   r0, #1
    popne   {r4, r5, r6, r7, pc}
    ldrb    r0, [r4, #XFER_DIR]
    cmp     r0, #USB_DIR_IN
    movne   r0, #1
    popne   {r4, r5, r6, r7, pc}
    ldr     r0, [r4, #XFER_LEN]
    ldr     r1, =msc_expected_data_len
    ldr     r1, [r1]
    cmp     r0, r1
    movne   r0, #1
    popne   {r4, r5, r6, r7, pc}
    ldr     r7, [r4, #XFER_BUF]
    ldr     r1, =msc_expected_data_buf
    ldr     r1, [r1]
    cmp     r7, r1
    movne   r0, #1
    popne   {r4, r5, r6, r7, pc}
    ldr     r0, =MSC_READ_MARKER
    str     r0, [r7]
    mov     r0, #2
    str     r0, [r5]
    mov     r0, #0
    pop     {r4, r5, r6, r7, pc}

.Lmsc_bulk_csw:
    ldrb    r0, [r4, #XFER_EPNUM]
    and     r0, r0, #0x0f
    cmp     r0, #4
    movne   r0, #1
    popne   {r4, r5, r6, r7, pc}
    ldrb    r0, [r4, #XFER_DIR]
    cmp     r0, #USB_DIR_IN
    movne   r0, #1
    popne   {r4, r5, r6, r7, pc}
    ldr     r0, [r4, #XFER_LEN]
    cmp     r0, #USB_MSC_CSW_LEN
    movne   r0, #1
    popne   {r4, r5, r6, r7, pc}
    ldr     r7, [r4, #XFER_BUF]
    ldr     r0, =USB_MSC_CSW_SIGNATURE
    str     r0, [r7]
    ldr     r1, =msc_captured_tag
    ldr     r0, [r1]
    str     r0, [r7, #4]
    mov     r0, #0
    str     r0, [r7, #8]
    ldr     r1, =msc_bulk_bad_csw
    ldr     r0, [r1]
    strb    r0, [r7, #12]
    add     r0, r6, #1
    str     r0, [r5]
    mov     r0, #0
    pop     {r4, r5, r6, r7, pc}

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
ecm_config_desc:
    .byte   9, 2, ecm_config_desc_len, 0, 2, 1, 0, 0x80, 50
    .byte   9, 4, ETH_CTRL_IF, 0, 1, 0x02, 0x06, 0x00, 0
    .byte   5, 0x24, 0x00, 0x10, 0x01
    .byte   7, 5, 0x83, 0x03, 8, 0, 16
    .byte   9, 4, ETH_DATA_IF, 0, 2, 0x0a, 0x00, 0x00, 0
    .byte   7, 5, ETH_BULK_IN_EP, 0x02, ETH_BULK_MPS, 0, 0
    .byte   7, 5, ETH_BULK_OUT_EP, 0x02, ETH_BULK_MPS, 0, 0
ecm_config_desc_end:
.equ ecm_config_desc_len, ecm_config_desc_end - ecm_config_desc
ncm_config_desc:
    .byte   9, 2, ncm_config_desc_len, 0, 2, 1, 0, 0x80, 50
    .byte   9, 4, ETH_CTRL_IF, 0, 1, 0x02, 0x0d, 0x00, 0
    .byte   5, 0x24, 0x00, 0x10, 0x01
    .byte   7, 5, 0x83, 0x03, 8, 0, 16
    .byte   9, 4, ETH_DATA_IF, 0, 2, 0x0a, 0x00, 0x00, 0
    .byte   7, 5, ETH_BULK_IN_EP, 0x02, ETH_BULK_MPS, 0, 0
    .byte   7, 5, ETH_BULK_OUT_EP, 0x02, ETH_BULK_MPS, 0, 0
ncm_config_desc_end:
.equ ncm_config_desc_len, ncm_config_desc_end - ncm_config_desc
incomplete_config_desc:
    .byte   9, 2, incomplete_config_desc_len, 0, 2, 1, 0, 0x80, 50
    .byte   9, 4, ETH_CTRL_IF, 0, 1, 0x02, 0x06, 0x00, 0
    .byte   7, 5, 0x83, 0x03, 8, 0, 16
    .byte   9, 4, ETH_DATA_IF, 0, 1, 0x0a, 0x00, 0x00, 0
    .byte   7, 5, ETH_BULK_IN_EP, 0x02, ETH_BULK_MPS, 0, 0
incomplete_config_desc_end:
.equ incomplete_config_desc_len, incomplete_config_desc_end - incomplete_config_desc
msc_config_desc:
    .byte   9, 2, msc_config_desc_len, 0, 1, 1, 0, 0x80, 50
    .byte   9, 4, MSC_IF, 0, 2, 0x08, 0x06, 0x50, 0
    .byte   7, 5, MSC_BULK_IN_EP, 0x02, MSC_BULK_MPS, 0, 0
    .byte   7, 5, MSC_BULK_OUT_EP, 0x02, MSC_BULK_MPS, 0, 0
msc_config_desc_end:
.equ msc_config_desc_len, msc_config_desc_end - msc_config_desc
incomplete_msc_config_desc:
    .byte   9, 2, incomplete_msc_config_desc_len, 0, 1, 1, 0, 0x80, 50
    .byte   9, 4, MSC_IF, 0, 1, 0x08, 0x06, 0x50, 0
    .byte   7, 5, MSC_BULK_IN_EP, 0x02, MSC_BULK_MPS, 0, 0
incomplete_msc_config_desc_end:
.equ incomplete_msc_config_desc_len, incomplete_msc_config_desc_end - incomplete_msc_config_desc
bad_msc_protocol_desc:
    .byte   9, 2, bad_msc_protocol_desc_len, 0, 1, 1, 0, 0x80, 50
    .byte   9, 4, MSC_IF, 0, 2, 0x08, 0x06, 0x62, 0
    .byte   7, 5, MSC_BULK_IN_EP, 0x02, MSC_BULK_MPS, 0, 0
    .byte   7, 5, MSC_BULK_OUT_EP, 0x02, MSC_BULK_MPS, 0, 0
bad_msc_protocol_desc_end:
.equ bad_msc_protocol_desc_len, bad_msc_protocol_desc_end - bad_msc_protocol_desc
.align 4

.section .bss
.align 4
core_id:
    .space  4
write_count:
    .space  4
reset_pending:
    .space  4
ahb_idle_enabled:
    .space  4
reset_clears:
    .space  4
gahbcfg_value:
    .space  4
gusbcfg_value:
    .space  4
hcfg_value:
    .space  4
hfir_value:
    .space  4
grxfsiz_value:
    .space  4
gnptxfsiz_value:
    .space  4
hptxfsiz_value:
    .space  4
gintmsk_value:
    .space  4
hprt_value:
    .space  4
hprt_write_count:
    .space  4
hprt_reset_enables:
    .space  4
hprt_reset_seen:
    .space  4
speed_out:
    .space  4
eth_out:
    .space  8
msc_out:
    .space  8
msc_dev:
    .space  12
msc_bulk_phase:
    .space  4
msc_bulk_bad_csw:
    .space  4
msc_captured_tag:
    .space  4
msc_expected_opcode:
    .space  4
msc_expected_cdb_len:
    .space  4
msc_expected_data_len:
    .space  4
msc_expected_data_buf:
    .space  4
msc_read_block:
    .space  512
msc_inquiry_buf:
    .space  36
msc_capacity_buf:
    .space  8
stack_bottom:
    .space  4096
stack_top:
