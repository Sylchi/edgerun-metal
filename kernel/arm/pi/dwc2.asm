@ Pi DWC2 USB OTG host driver — ARM1176JZF-S (BCM2835)
@
@ Programs the Synopsys DesignWare DWC2 (OTG_HS) controller in host
@ mode.  Provides USB 2.0 (HS) / 1.1 (FS/LS) host functionality
@ with control, bulk, and interrupt transfers.
@
@ Public API:
@   dwc2_init()               — reset + host mode + FIFO config
@   dwc2_port_detect(struct*) — wait for device, fill port speed
@   dwc2_control_xfer(struct*)r0=0 ok
@   dwc2_bulk_xfer(struct*)   r0=0 ok
@   dwc2_enumerate()          r0=0 ok, or device address (1-127)
@   dwc2_find_ethernet_config(config, len, out) r0=0 ok
@   dwc2_find_mass_storage_config(config, len, out) r0=0 ok
@   dwc2_msc_read10(dev, lba, buf) r0=0 ok

@ ---- DWC2 base address (BCM2835) ----
.equ DWC2_BASE,             0x20980000
.equ DWC2_SIZE,             0x00010000

@ ---- Core Global Registers (offset from DWC2_BASE) ----
.equ DWC_OTGCTL,            0x000
.equ DWC_GAHBCFG,           0x008
.equ DWC_GUSBCFG,           0x00c
.equ DWC_GRSTCTL,           0x010
.equ DWC_GINTSTS,           0x014
.equ DWC_GINTMSK,           0x018
.equ DWC_GRXSTSR,           0x01c
.equ DWC_GRXSTSP,           0x020
.equ DWC_GRXFSIZ,           0x024
.equ DWC_GNPTXFSIZ,         0x028
.equ DWC_GNPTXSTS,          0x02c
.equ DWC_GCCFG,             0x038
.equ DWC_CID,               0x040
.equ DWC_HPTXFSIZ,          0x100
.equ DWC_DPTXFSIZn,         0x104

@ ---- GUSBCFG bits ----
.equ GUSBCFG_TOCAL_SHIFT,   0
.equ GUSBCFG_PHYIF,         (1 << 6)
.equ GUSBCFG_ULPI_UTMI_SEL, (1 << 4)
.equ GUSBCFG_FS_INTF,       (1 << 5)
.equ GUSBCFG_TS_SHIFT,      10
.equ GUSBCFG_TS_MASK,       (3 << 10)
.equ GUSBCFG_SRPCAP,        (1 << 8)
.equ GUSBCFG_HNPCAP,        (1 << 9)
.equ GUSBCFG_TRDT_SHIFT,    10
.equ GUSBCFG_TRDT_MASK,     (0xf << 10)
.equ GUSBCFG_PHYSEL,        (1 << 7)

@ ---- GRSTCTL bits ----
.equ GRSTCTL_CSFTRST,       (1 << 0)
.equ GRSTCTL_AHBIDLE,       (1 << 31)
.equ GRSTCTL_TXFNUM_SHIFT,  6
.equ GRSTCTL_TXFFLSH,       (1 << 5)
.equ GRSTCTL_RXFFLSH,       (1 << 4)
.equ GRSTCTL_INTKNQFLSH,    (1 << 3)
.equ GRSTCTL_FRAME_CNTRST,  (1 << 2)
.equ GRSTCTL_PI_SCLK_STABLE,  (1 << 1)

@ ---- GAHBCFG bits ----
.equ GAHBCFG_GLBL_INTR_EN,  (1 << 0)
.equ GAHBCFG_HBSTLEN_SHIFT, 1
.equ GAHBCFG_HBSTLEN_MASK,  (7 << 1)
.equ GAHBCFG_DMA_EN,        (1 << 5)
.equ GAHBCFG_NPTXF_EMPTY_LVL, (1 << 7)
.equ GAHBCFG_PTXF_EMPTY_LVL,  (1 << 8)
.equ GAHBCFG_REM_MEM_SUPP,  (1 << 23)

@ ---- GINTSTS / GINTMSK bits ----
.equ GINT_OTG_INT,          (1 << 2)
.equ GINT_SOF,              (1 << 3)
.equ GINT_RXFLVL,           (1 << 4)
.equ GINT_NPTXF_EMPTY,      (1 << 5)
.equ GINT_GINNAKEFF,        (1 << 6)
.equ GINT_GOUTNAKEFF,       (1 << 7)
.equ GINT_ERLY_SUSP,        (1 << 10)
.equ GINT_USB_SUSPEND,      (1 << 11)
.equ GINT_USB_RESET,        (1 << 12)
.equ GINT_ENUMDONE,         (1 << 13)
.equ GINT_ISOCHRONOUS,      (1 << 14)
.equ GINT_EOP_FRAME,        (1 << 15)
.equ GINT_INTKN_BSS_EMPTY,  (1 << 16)
.equ GINT_I2C_INT,          (1 << 17)
.equ GINT_PTXF_EMPTY,       (1 << 18)
.equ GINT_HC_INT,           (1 << 25)
.equ GINT_PRT_INT,          (1 << 24)
.equ GINT_DISC_INT,         (1 << 28)
.equ GINT_CONID_STS_CHG,    (1 << 28) @ same bit, different name
.equ GINT_SESS_REQ_INT,     (1 << 29)
.equ GINT_WKUP_INT,         (1 << 31)

@ ---- OTGCTL bits ----
.equ OTGCTL_HNNF_REQ,       (1 << 9)
.equ OTGCTL_SRQ,            (1 << 11)
.equ OTGCTL_VBVALOEN,       (1 << 12)
.equ OTGCTL_VBVALOVAL,      (1 << 13)
.equ OTGCTL_BSVLD,          (1 << 19)
.equ OTGCTL_ASVLD,          (1 << 20)

@ ---- Host-mode Registers (offset from DWC2_BASE) ----
.equ DWC_HCFG,              0x400
.equ DWC_HFIR,              0x404
.equ DWC_HFNUM,             0x408
.equ DWC_HPTXSTS,           0x40c
.equ DWC_HAINT,             0x414
.equ DWC_HAINTMSK,          0x418
.equ DWC_HPRT,              0x440
.equ DWC_HPRT_CH,           0x444
.equ DWC_HCCHAR,            0x500  @ + n*0x20 per channel
.equ DWC_HCSPLT,            0x504  @ + n*0x20
.equ DWC_HCINT,             0x508  @ + n*0x20
.equ DWC_HCINTMSK,          0x50c  @ + n*0x20
.equ DWC_HCTSIZ,            0x510  @ + n*0x20
.equ DWC_HCDMA,             0x514  @ + n*0x20
.equ DWC_HCDMAB,            0x51c  @ + n*0x20
.equ DWC_HC_CHAN_SIZE,      0x20
.equ DWC_NUM_CHAN,          16

@ ---- HCFG bits ----
.equ HCFG_FSLSS,            (1 << 2)
.equ HCFG_FSLS_PHOST,       (1 << 3)

@ ---- HPRT bits ----
.equ HPRT_PRTENA,           (1 << 0)
.equ HPRT_PRTCONNSTS,       (1 << 1)
.equ HPRT_PRTCONNDET,       (1 << 2)
.equ HPRT_PRTENA_CHG,       (1 << 3)
.equ HPRT_PRTOVERRCUR_CHG,  (1 << 4)
.equ HPRT_PRT_EC_PS,        (1 << 5)
.equ HPRT_PRTRST,           (1 << 6)
.equ HPRT_PRTSLP,           (1 << 7)
.equ HPRT_PRTPWR,           (1 << 9)
.equ HPRR_PRT_SPD_SHIFT,    17
.equ HPRR_PRT_SPD_MASK,     (3 << 17)
.equ HPRT_SPD_HS,           (0 << 17)
.equ HPRT_SPD_FS,           (1 << 17)
.equ HPRT_SPD_LS,           (2 << 17)
.equ HPRT_TSTCTL_SHIFT,     11
.equ HPRT_TSTCTL_MASK,      (0xf << 11)

@ ---- HCCHAR bits ----
.equ HCCHAR_CHEN,           (1 << 31)
.equ HCCHAR_CHDIS,          (1 << 30)
.equ HCCHAR_ODDFRM,         (1 << 29)
.equ HCCHAR_DEVADDR_SHIFT,  22
.equ HCCHAR_DEVADDR_MASK,   (0x7f << 22)
.equ HCCHAR_MCNT_SHIFT,     26
.equ HCCHAR_MCNT_MASK,      (3 << 26)
.equ HCCHAR_EPDIR_IN,       (1 << 19)
.equ HCCHAR_EPDIR_OUT,      0
.equ HCCHAR_EPNUM_SHIFT,    15
.equ HCCHAR_EPNUM_MASK,     (0xf << 15)
.equ HCCHAR_EPTYPE_SHIFT,   18
.equ HCCHAR_EPTYPE_MASK,    (3 << 18)
.equ HCCHAR_LSPDDEV,        (1 << 17)
.equ HCCHAR_MPS_SHIFT,      0
.equ HCCHAR_MPS_MASK,       (0x7ff << 0)

@ ---- HCCHAR EP types ----
.equ EPTYPE_CTRL,           (0 << 18)
.equ EPTYPE_ISOC,           (1 << 18)
.equ EPTYPE_BULK,           (2 << 18)
.equ EPTYPE_INTR,           (3 << 18)

@ ---- HCTSIZ bits ----
.equ HCTSIZ_XFERSIZE_SHIFT, 0
.equ HCTSIZ_XFERSIZE_MASK,  (0x7ffff << 0)
.equ HCTSIZ_PKTCNT_SHIFT,   19
.equ HCTSIZ_PKTCNT_MASK,    (0x3ff << 19)
.equ HCTSIZ_DOPING,         (1 << 31)
.equ HCTSIZ_PID_SHIFT,      29
.equ HCTSIZ_PID_MASK,       (3 << 29)
.equ HCTSIZ_PID_DATA0,      (0 << 29)
.equ HCTSIZ_PID_DATA1,      (2 << 29)
.equ HCTSIZ_PID_SETUP,      (3 << 29)
.equ HCTSIZ_PID_MDATA,      (1 << 29)

@ ---- HCINT bits ----
.equ HCINT_XFER_COMPLETE,   (1 << 0)
.equ HCINT_CH_HALTED,       (1 << 1)
.equ HCINT_AHB_ERROR,       (1 << 2)
.equ HCINT_STALL,           (1 << 3)
.equ HCINT_NAK,             (1 << 4)
.equ HCINT_ACK,             (1 << 5)
.equ HCINT_NYET,            (1 << 6)
.equ HCINT_TRANSACTION_ERR, (1 << 7)
.equ HCINT_BBLERR,          (1 << 8)
.equ HCINT_FRAME_OVERRUN,   (1 << 9)
.equ HCINT_DATATGL_ERR,     (1 << 10)
.equ HCINT_BNA,             (1 << 11)
.equ HCINT_XFER_COMPLETE_MSK, (1 << 0)

@ ---- HCSPLT bits ----
.equ HCSPLT_SPLT_ENABLE,    (1 << 31)
.equ HCSPLT_HUBADDR_SHIFT,  25
.equ HCSPLT_HUBADDR_MASK,   (0x7f << 25)
.equ HCSPLT_XACTPOS_SHIFT,  24
.equ HCSPLT_XACTPOS_MASK,   (1 << 24)
.equ HCSPLT_EPNUM_SHIFT,    0
.equ HCSPLT_EPNUM_MASK,     (0xf << 0)

@ ---- USB standard request constants ----
.equ USB_DIR_IN,            (1 << 7)
.equ USB_DIR_OUT,           0
.equ USB_REQ_STANDARD,      (0 << 5)
.equ USB_REQ_CLASS,         (1 << 5)
.equ USB_REQ_VENDOR,        (2 << 5)
.equ USB_RECIP_DEVICE,      0
.equ USB_RECIP_INTERF,      1
.equ USB_RECIP_ENDP,        2
.equ USB_RECIP_OTHER,       3

.equ USB_REQ_GET_DESC,      0x06
.equ USB_REQ_SET_ADDR,      0x05
.equ USB_REQ_SET_CFG,       0x09
.equ USB_REQ_GET_CFG,       0x08
.equ USB_REQ_GET_STATUS,    0x00
.equ USB_REQ_SET_FEAT,      0x03
.equ USB_REQ_CLEAR_FEAT,    0x01

.equ USB_DESC_DEVICE,      1
.equ USB_DESC_CONFIG,      2
.equ USB_DESC_STRING,      3
.equ USB_DESC_INTERFACE,   4
.equ USB_DESC_ENDPOINT,    5

.equ USB_CLASS_COMM,       0x02
.equ USB_CLASS_MASS_STORAGE, 0x08
.equ USB_CLASS_CDC_DATA,   0x0a
.equ USB_CDC_SUBCLASS_ECM, 0x06
.equ USB_CDC_SUBCLASS_NCM, 0x0d
.equ USB_MSC_SUBCLASS_SCSI, 0x06
.equ USB_MSC_PROTOCOL_BULK_ONLY, 0x50
.equ USB_ENDPOINT_DIR_IN,  0x80
.equ USB_ENDPOINT_ATTR_TYPE_MASK, 0x03
.equ USB_ENDPOINT_ATTR_BULK, 0x02

@ ---- DWC2 core ID values ----
.equ DWC2_CORE_ID_310,      0x4f54230a
.equ DWC2_CORE_ID_310A,     0x4f54230b
.equ DWC2_CORE_ID_311,      0x4f54230c
.equ DWC2_CORE_ID_330,      0x4f54330a

@ ---- Usual FIFO sizes (in 32-bit words) ----
.equ FIFO_SIZE_256,         256
.equ FIFO_SIZE_128,         128
.equ FIFO_SIZE_64,          64
.equ FIFO_SIZE_16,          16

@ ---- USB device states ----
.equ USB_SPEED_HS,           0
.equ USB_SPEED_FS,           1
.equ USB_SPEED_LS,           2

@ ---- Transfer result codes ----
.equ USB_OK,                 0
.equ USB_TIMEOUT,            -1
.equ USB_STALL,              -2
.equ USB_NAK,                -3
.equ USB_ERROR,              -4

@ ---- Structure: dwc2_xfer_t (16 bytes) ----
@ Offset 0: Device address (byte)
@ Offset 1: Endpoint number (byte)
@ Offset 2: Endpoint type (byte: 0=ctrl, 2=bulk, 3=intr)
@ Offset 3: Direction (byte: 0=OUT, 0x80=IN)
@ Offset 4: Max packet size (u16)
@ Offset 6: Speed (byte: 0=HS, 1=FS, 2=LS)
@ Offset 8: Data buffer pointer (u32)
@ Offset 12: Total bytes (u32)
@ Offset 16: (returns actual bytes transferred)
.equ XFER_DEVADDR,           0
.equ XFER_EPNUM,             1
.equ XFER_EPTYPE,            2
.equ XFER_DIR,               3
.equ XFER_MPS,               4
.equ XFER_SPEED,             6
.equ XFER_BUF,               8
.equ XFER_LEN,               12
.equ XFER_ACTUAL,            16
.equ XFER_STRUCT_SIZE,       20

@ ---- Structure: dwc2_msc_dev_t (12 bytes) ----
@ Offset 0: Device address (byte)
@ Offset 1: Speed (byte)
@ Offset 2: Bulk IN endpoint address (byte)
@ Offset 3: Bulk OUT endpoint address (byte)
@ Offset 4: Bulk IN max packet size (u16)
@ Offset 6: Bulk OUT max packet size (u16)
@ Offset 8: BOT tag counter (u32)
.equ MSC_DEV_ADDR,            0
.equ MSC_DEV_SPEED,           1
.equ MSC_DEV_BULK_IN_EP,      2
.equ MSC_DEV_BULK_OUT_EP,     3
.equ MSC_DEV_BULK_IN_MPS,     4
.equ MSC_DEV_BULK_OUT_MPS,    6
.equ MSC_DEV_TAG,             8

@ ---- USB Mass Storage Bulk-Only Transport ----
.equ USB_MSC_CBW_SIGNATURE,   0x43425355
.equ USB_MSC_CSW_SIGNATURE,   0x53425355
.equ USB_MSC_CBW_LEN,         31
.equ USB_MSC_CSW_LEN,         13
.equ USB_MSC_CBW_TAG,         4
.equ USB_MSC_CBW_DATA_LEN,    8
.equ USB_MSC_CBW_FLAGS,       12
.equ USB_MSC_CBW_LUN,         13
.equ USB_MSC_CBW_CDB_LEN,     14
.equ USB_MSC_CBW_CDB,         15
.equ USB_MSC_CSW_TAG,         4
.equ USB_MSC_CSW_RESIDUE,     8
.equ USB_MSC_CSW_STATUS,      12
.equ USB_MSC_FLAG_IN,         0x80
.equ USB_MSC_SCSI_TEST_READY, 0x00
.equ USB_MSC_SCSI_INQUIRY,    0x12
.equ USB_MSC_SCSI_READ_CAP10, 0x25
.equ USB_MSC_SCSI_READ10,     0x28
.equ USB_MSC_BLOCK_SIZE,      512

@ ---- Structure: dwc2_control_xfer_t (28 bytes) ----
@ Offset 0: Device address (byte)
@ Offset 1: Request type (byte: bmRequestType)
@ Offset 2: Request (byte: bRequest)
@ Offset 3: Value low (byte: wValue low)
@ Offset 4: Value high (byte: wValue high)
@ Offset 5: Index low (byte: wIndex low)
@ Offset 6: Index high (byte: wIndex high)
@ Offset 8: Data pointer (u32) — 0 if no data stage
@ Offset 12: Data length (u32)
@ Offset 16: Max packet size (u16) — typically 8/16/32/64
@ Offset 18: Speed (byte)
@ Offset 20: (return) actual length
@ Offset 24: (return) status (0=ok, -1=timeout, -2=stall)
.equ CTRL_DEVADDR,           0
.equ CTRL_REQTYPE,           1
.equ CTRL_REQUEST,           2
.equ CTRL_VAL_LOW,           3
.equ CTRL_VAL_HIGH,          4
.equ CTRL_IDX_LOW,           5
.equ CTRL_IDX_HIGH,          6
.equ CTRL_DATA,              8
.equ CTRL_DATALEN,           12
.equ CTRL_MPS,               16
.equ CTRL_SPEED,             18
.equ CTRL_ACTUAL,            20
.equ CTRL_STATUS,            24
.equ CTRL_STRUCT_SIZE,       28

@ ---- Functions ----
.globl dwc2_init
.globl dwc2_port_detect
.globl dwc2_control_xfer
.globl dwc2_bulk_xfer
.globl dwc2_enumerate
.globl dwc2_find_ethernet_config
.globl dwc2_find_mass_storage_config
.globl dwc2_msc_scsi
.globl dwc2_msc_test_unit_ready
.globl dwc2_msc_inquiry
.globl dwc2_msc_read_capacity10
.globl dwc2_msc_read10
.weak dwc2_mmio_read
.weak dwc2_mmio_write
.weak dwc2_msc_bulk_xfer

@ ==========================================================
@ dwc2_find_ethernet_config
@ Arguments:
@   r0 = configuration descriptor buffer
@   r1 = buffer length
@   r2 = output: ctrl_if, data_if, bulk_in_ep, bulk_out_ep,
@                bulk_in_mps:u16, bulk_out_mps:u16
@ Returns: r0 = 0 on supported CDC ECM/NCM-style Ethernet config.
@ ==========================================================
dwc2_find_ethernet_config:
    push    {r4, r5, r6, r7, r8, r9, r10, r11, lr}
    cmp     r0, #0
    beq     .Leth_fail
    cmp     r1, #2
    blo     .Leth_fail
    cmp     r2, #0
    beq     .Leth_fail
    mov     r4, r0
    mov     r5, r1
    mov     r6, r2
    mov     r7, #0
    mov     r8, #0xff
    mov     r9, #0xff
    mov     r10, #0
    mov     r11, #0
    mov     r0, #0
    str     r0, [r6]
    str     r0, [r6, #4]

.Leth_next_desc:
    cmp     r5, #2
    blo     .Leth_done
    ldrb    r0, [r4]
    cmp     r0, #2
    blo     .Leth_fail
    cmp     r0, r5
    bhi     .Leth_fail
    ldrb    r1, [r4, #1]
    cmp     r1, #USB_DESC_INTERFACE
    beq     .Leth_interface
    cmp     r1, #USB_DESC_ENDPOINT
    beq     .Leth_endpoint
    b       .Leth_advance

.Leth_interface:
    cmp     r0, #9
    blo     .Leth_advance
    mov     r7, #0
    ldrb    r1, [r4, #5]
    cmp     r1, #USB_CLASS_COMM
    bne     1f
    ldrb    r2, [r4, #6]
    cmp     r2, #USB_CDC_SUBCLASS_ECM
    beq     2f
    cmp     r2, #USB_CDC_SUBCLASS_NCM
    bne     .Leth_advance
2:
    ldrb    r8, [r4, #2]
    strb    r8, [r6]
    b       .Leth_advance
1:
    cmp     r1, #USB_CLASS_CDC_DATA
    bne     .Leth_advance
    ldrb    r9, [r4, #2]
    strb    r9, [r6, #1]
    mov     r7, #1
    b       .Leth_advance

.Leth_endpoint:
    cmp     r7, #0
    beq     .Leth_advance
    cmp     r0, #7
    blo     .Leth_advance
    ldrb    r1, [r4, #3]
    and     r1, r1, #USB_ENDPOINT_ATTR_TYPE_MASK
    cmp     r1, #USB_ENDPOINT_ATTR_BULK
    bne     .Leth_advance
    ldrb    r1, [r4, #2]
    ldrb    r2, [r4, #4]
    ldrb    r3, [r4, #5]
    orr     r2, r2, r3, lsl #8
    tst     r1, #USB_ENDPOINT_DIR_IN
    beq     1f
    mov     r10, r1
    strb    r1, [r6, #2]
    strh    r2, [r6, #4]
    b       .Leth_advance
1:
    mov     r11, r1
    strb    r1, [r6, #3]
    strh    r2, [r6, #6]

.Leth_advance:
    add     r4, r4, r0
    sub     r5, r5, r0
    b       .Leth_next_desc

.Leth_done:
    cmp     r8, #0xff
    beq     .Leth_fail
    cmp     r9, #0xff
    beq     .Leth_fail
    cmp     r10, #0
    beq     .Leth_fail
    cmp     r11, #0
    beq     .Leth_fail
    mov     r0, #0
    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}

.Leth_fail:
    mov     r0, #1
    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}

@ ==========================================================
@ dwc2_find_mass_storage_config
@ Arguments:
@   r0 = configuration descriptor buffer
@   r1 = buffer length
@   r2 = output: interface, reserved, bulk_in_ep, bulk_out_ep,
@                bulk_in_mps:u16, bulk_out_mps:u16
@ Returns: r0 = 0 on supported SCSI/Bulk-Only mass storage config.
@ ==========================================================
dwc2_find_mass_storage_config:
    push    {r4, r5, r6, r7, r8, r9, r10, lr}
    cmp     r0, #0
    beq     .Lmsc_fail
    cmp     r1, #2
    blo     .Lmsc_fail
    cmp     r2, #0
    beq     .Lmsc_fail
    mov     r4, r0
    mov     r5, r1
    mov     r6, r2
    mov     r7, #0
    mov     r8, #0xff
    mov     r9, #0
    mov     r10, #0
    mov     r0, #0
    str     r0, [r6]
    str     r0, [r6, #4]

.Lmsc_next_desc:
    cmp     r5, #2
    blo     .Lmsc_done
    ldrb    r0, [r4]
    cmp     r0, #2
    blo     .Lmsc_fail
    cmp     r0, r5
    bhi     .Lmsc_fail
    ldrb    r1, [r4, #1]
    cmp     r1, #USB_DESC_INTERFACE
    beq     .Lmsc_interface
    cmp     r1, #USB_DESC_ENDPOINT
    beq     .Lmsc_endpoint
    b       .Lmsc_advance

.Lmsc_interface:
    cmp     r0, #9
    blo     .Lmsc_advance
    mov     r7, #0
    ldrb    r1, [r4, #5]
    cmp     r1, #USB_CLASS_MASS_STORAGE
    bne     .Lmsc_advance
    ldrb    r1, [r4, #6]
    cmp     r1, #USB_MSC_SUBCLASS_SCSI
    bne     .Lmsc_advance
    ldrb    r1, [r4, #7]
    cmp     r1, #USB_MSC_PROTOCOL_BULK_ONLY
    bne     .Lmsc_advance
    ldrb    r8, [r4, #2]
    strb    r8, [r6]
    mov     r7, #1
    b       .Lmsc_advance

.Lmsc_endpoint:
    cmp     r7, #0
    beq     .Lmsc_advance
    cmp     r0, #7
    blo     .Lmsc_advance
    ldrb    r1, [r4, #3]
    and     r1, r1, #USB_ENDPOINT_ATTR_TYPE_MASK
    cmp     r1, #USB_ENDPOINT_ATTR_BULK
    bne     .Lmsc_advance
    ldrb    r1, [r4, #2]
    ldrb    r2, [r4, #4]
    ldrb    r3, [r4, #5]
    orr     r2, r2, r3, lsl #8
    tst     r1, #USB_ENDPOINT_DIR_IN
    beq     1f
    mov     r9, r1
    strb    r1, [r6, #2]
    strh    r2, [r6, #4]
    b       .Lmsc_advance
1:
    mov     r10, r1
    strb    r1, [r6, #3]
    strh    r2, [r6, #6]

.Lmsc_advance:
    add     r4, r4, r0
    sub     r5, r5, r0
    b       .Lmsc_next_desc

.Lmsc_done:
    cmp     r8, #0xff
    beq     .Lmsc_fail
    cmp     r9, #0
    beq     .Lmsc_fail
    cmp     r10, #0
    beq     .Lmsc_fail
    mov     r0, #0
    pop     {r4, r5, r6, r7, r8, r9, r10, pc}

.Lmsc_fail:
    mov     r0, #1
    pop     {r4, r5, r6, r7, r8, r9, r10, pc}

@ ==========================================================
@ dwc2_msc_scsi
@ Arguments:
@   r0 = dwc2_msc_dev_t
@   r1 = CDB pointer
@   r2 = CDB length (1..16)
@   r3 = data buffer pointer, or 0 when data_len is 0
@ Stack:
@   [sp]   = data length
@   [sp+4] = CBW flags (0x80 for IN, 0 for OUT/no data)
@ Returns: r0 = 0 on valid BOT command/status sequence, 1 on failure.
@ ==========================================================
dwc2_msc_scsi:
    push    {r4, r5, r6, r7, r8, r9, r10, r11, lr}
    ldr     r8, [sp, #36]
    ldr     r9, [sp, #40]
    cmp     r0, #0
    beq     .Lmsc_scsi_fail_pushed
    cmp     r1, #0
    beq     .Lmsc_scsi_fail_pushed
    cmp     r2, #1
    blo     .Lmsc_scsi_fail_pushed
    cmp     r2, #16
    bhi     .Lmsc_scsi_fail_pushed
    cmp     r8, #0
    beq     1f
    cmp     r3, #0
    beq     .Lmsc_scsi_fail_pushed
1:
    mov     r4, r0
    mov     r5, r1
    mov     r6, r2
    mov     r7, r3
    sub     sp, sp, #72

    ldr     r10, [r4, #MSC_DEV_TAG]
    add     r11, r10, #1
    str     r11, [r4, #MSC_DEV_TAG]

    mov     r0, #0
    str     r0, [sp]
    str     r0, [sp, #4]
    str     r0, [sp, #8]
    str     r0, [sp, #12]
    str     r0, [sp, #16]
    str     r0, [sp, #20]
    str     r0, [sp, #24]
    str     r0, [sp, #28]

    ldr     r0, =USB_MSC_CBW_SIGNATURE
    str     r0, [sp]
    str     r10, [sp, #USB_MSC_CBW_TAG]
    str     r8, [sp, #USB_MSC_CBW_DATA_LEN]
    strb    r9, [sp, #USB_MSC_CBW_FLAGS]
    mov     r0, #0
    strb    r0, [sp, #USB_MSC_CBW_LUN]
    strb    r6, [sp, #USB_MSC_CBW_CDB_LEN]

    mov     r0, #0
2:
    cmp     r0, r6
    bhs     3f
    ldrb    r1, [r5, r0]
    add     r2, sp, #USB_MSC_CBW_CDB
    strb    r1, [r2, r0]
    add     r0, r0, #1
    b       2b

3:
    add     r0, sp, #48
    mov     r1, sp
    mov     r2, #USB_MSC_CBW_LEN
    ldrb    r3, [r4, #MSC_DEV_BULK_OUT_EP]
    ldrh    r11, [r4, #MSC_DEV_BULK_OUT_MPS]
    mov     r12, #0
    bl      _dwc2_msc_bulk_phase
    cmp     r0, #0
    bne     .Lmsc_scsi_fail_alloc

    cmp     r8, #0
    beq     4f
    tst     r9, #USB_MSC_FLAG_IN
    beq     5f
    add     r0, sp, #48
    mov     r1, r7
    mov     r2, r8
    ldrb    r3, [r4, #MSC_DEV_BULK_IN_EP]
    ldrh    r11, [r4, #MSC_DEV_BULK_IN_MPS]
    mov     r12, #USB_ENDPOINT_DIR_IN
    bl      _dwc2_msc_bulk_phase
    cmp     r0, #0
    bne     .Lmsc_scsi_fail_alloc
    b       4f
5:
    add     r0, sp, #48
    mov     r1, r7
    mov     r2, r8
    ldrb    r3, [r4, #MSC_DEV_BULK_OUT_EP]
    ldrh    r11, [r4, #MSC_DEV_BULK_OUT_MPS]
    mov     r12, #0
    bl      _dwc2_msc_bulk_phase
    cmp     r0, #0
    bne     .Lmsc_scsi_fail_alloc

4:
    add     r0, sp, #48
    add     r1, sp, #32
    mov     r2, #USB_MSC_CSW_LEN
    ldrb    r3, [r4, #MSC_DEV_BULK_IN_EP]
    ldrh    r11, [r4, #MSC_DEV_BULK_IN_MPS]
    mov     r12, #USB_ENDPOINT_DIR_IN
    bl      _dwc2_msc_bulk_phase
    cmp     r0, #0
    bne     .Lmsc_scsi_fail_alloc

    ldr     r0, [sp, #32]
    ldr     r1, =USB_MSC_CSW_SIGNATURE
    cmp     r0, r1
    bne     .Lmsc_scsi_fail_alloc
    ldr     r0, [sp, #(32 + USB_MSC_CSW_TAG)]
    cmp     r0, r10
    bne     .Lmsc_scsi_fail_alloc
    ldr     r0, [sp, #(32 + USB_MSC_CSW_RESIDUE)]
    cmp     r0, #0
    bne     .Lmsc_scsi_fail_alloc
    ldrb    r0, [sp, #(32 + USB_MSC_CSW_STATUS)]
    cmp     r0, #0
    bne     .Lmsc_scsi_fail_alloc

    mov     r0, #0
    add     sp, sp, #72
    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}

.Lmsc_scsi_fail_alloc:
    mov     r0, #1
    add     sp, sp, #72
    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}

.Lmsc_scsi_fail_pushed:
    mov     r0, #1
    pop     {r4, r5, r6, r7, r8, r9, r10, r11, pc}

@ r0=xfer struct, r1=buffer, r2=len, r3=endpoint address,
@ r4=dwc2_msc_dev_t, r11=mps, r12=direction.
_dwc2_msc_bulk_phase:
    push    {r5, lr}
    mov     r5, r0
    mov     r0, #0
    str     r0, [r5, #XFER_ACTUAL]
    str     r2, [r5, #XFER_LEN]
    str     r1, [r5, #XFER_BUF]
    and     r3, r3, #0x0f
    strb    r3, [r5, #XFER_EPNUM]
    mov     r0, #2
    strb    r0, [r5, #XFER_EPTYPE]
    strb    r12, [r5, #XFER_DIR]
    strh    r11, [r5, #XFER_MPS]
    ldrb    r0, [r4, #MSC_DEV_ADDR]
    strb    r0, [r5, #XFER_DEVADDR]
    ldrb    r0, [r4, #MSC_DEV_SPEED]
    strb    r0, [r5, #XFER_SPEED]
    mov     r0, r5
    bl      dwc2_msc_bulk_xfer
    cmp     r0, #USB_OK
    moveq   r0, #0
    movne   r0, #1
    pop     {r5, pc}

@ ==========================================================
@ dwc2_msc_test_unit_ready(dev)
@ Returns: r0 = 0 when CSW status is good.
@ ==========================================================
dwc2_msc_test_unit_ready:
    push    {lr}
    sub     sp, sp, #16
    mov     r1, #0
    str     r1, [sp]
    str     r1, [sp, #4]
    str     r1, [sp, #8]
    str     r1, [sp, #12]
    mov     r1, #USB_MSC_SCSI_TEST_READY
    strb    r1, [sp]
    mov     r1, sp
    mov     r2, #6
    mov     r3, #0
    mov     r12, #0
    push    {r12}
    push    {r12}
    bl      dwc2_msc_scsi
    add     sp, sp, #8
    add     sp, sp, #16
    pop     {pc}

@ ==========================================================
@ dwc2_msc_inquiry(dev, out, len)
@ Returns: r0 = 0 when INQUIRY data and CSW are received.
@ ==========================================================
dwc2_msc_inquiry:
    push    {r4, r5, lr}
    cmp     r1, #0
    beq     .Lmsc_inquiry_fail
    cmp     r2, #1
    blo     .Lmsc_inquiry_fail
    cmp     r2, #255
    bhi     .Lmsc_inquiry_fail
    mov     r4, r1
    mov     r5, r2
    sub     sp, sp, #16
    mov     r1, #0
    str     r1, [sp]
    str     r1, [sp, #4]
    str     r1, [sp, #8]
    str     r1, [sp, #12]
    mov     r1, #USB_MSC_SCSI_INQUIRY
    strb    r1, [sp]
    strb    r5, [sp, #4]
    mov     r1, sp
    mov     r2, #6
    mov     r3, r4
    mov     r12, #USB_MSC_FLAG_IN
    push    {r12}
    push    {r5}
    bl      dwc2_msc_scsi
    add     sp, sp, #8
    add     sp, sp, #16
    pop     {r4, r5, pc}
.Lmsc_inquiry_fail:
    mov     r0, #1
    pop     {r4, r5, pc}

@ ==========================================================
@ dwc2_msc_read_capacity10(dev, out8)
@ Returns: r0 = 0 when READ CAPACITY(10) data and CSW are received.
@ ==========================================================
dwc2_msc_read_capacity10:
    push    {r4, lr}
    cmp     r1, #0
    beq     .Lmsc_cap_fail
    mov     r4, r1
    sub     sp, sp, #16
    mov     r1, #0
    str     r1, [sp]
    str     r1, [sp, #4]
    str     r1, [sp, #8]
    str     r1, [sp, #12]
    mov     r1, #USB_MSC_SCSI_READ_CAP10
    strb    r1, [sp]
    mov     r1, sp
    mov     r2, #10
    mov     r3, r4
    mov     r12, #USB_MSC_FLAG_IN
    push    {r12}
    mov     r12, #8
    push    {r12}
    bl      dwc2_msc_scsi
    add     sp, sp, #8
    add     sp, sp, #16
    pop     {r4, pc}
.Lmsc_cap_fail:
    mov     r0, #1
    pop     {r4, pc}

@ ==========================================================
@ dwc2_msc_read10(dev, lba, buf512)
@ Returns: r0 = 0 when one 512-byte block and CSW are received.
@ ==========================================================
dwc2_msc_read10:
    push    {r4, r5, lr}
    cmp     r2, #0
    beq     .Lmsc_read10_fail
    mov     r4, r2
    mov     r5, r1
    sub     sp, sp, #16
    mov     r1, #0
    str     r1, [sp]
    str     r1, [sp, #4]
    str     r1, [sp, #8]
    str     r1, [sp, #12]
    mov     r1, #USB_MSC_SCSI_READ10
    strb    r1, [sp]
    mov     r1, r5, lsr #24
    strb    r1, [sp, #2]
    mov     r1, r5, lsr #16
    strb    r1, [sp, #3]
    mov     r1, r5, lsr #8
    strb    r1, [sp, #4]
    strb    r5, [sp, #5]
    mov     r1, #1
    strb    r1, [sp, #8]
    mov     r1, sp
    mov     r2, #10
    mov     r3, r4
    mov     r12, #USB_MSC_FLAG_IN
    push    {r12}
    ldr     r12, =USB_MSC_BLOCK_SIZE
    push    {r12}
    bl      dwc2_msc_scsi
    add     sp, sp, #8
    add     sp, sp, #16
    pop     {r4, r5, pc}
.Lmsc_read10_fail:
    mov     r0, #1
    pop     {r4, r5, pc}

@ ==========================================================
@ dwc2_init — Reset core, set host mode, configure FIFOs
@ Arguments: none
@ Returns: r0 = 0 on success, 1 on failure
@ Clobbers: r0-r3
@ ==========================================================
dwc2_init:
    push    {r4, r5, lr}

    @ 1. Read core ID to verify controller presence
    mov     r0, #DWC_CID
    bl      dwc2_mmio_read
    ldr     r1, =DWC2_CORE_ID_310
    cmp     r0, r1
    beq     .Linit_ok_cid
    ldr     r1, =DWC2_CORE_ID_310A
    cmp     r0, r1
    beq     .Linit_ok_cid
    ldr     r1, =DWC2_CORE_ID_311
    cmp     r0, r1
    beq     .Linit_ok_cid
    ldr     r1, =DWC2_CORE_ID_330
    cmp     r0, r1
    beq     .Linit_ok_cid
    @ Unknown core ID — fail
    mov     r0, #1
    pop     {r4, r5, pc}
.Linit_ok_cid:

    @ 2. Wait for AHB idle
    mov     r5, #0x100000
1:  mov     r0, #DWC_GRSTCTL
    bl      dwc2_mmio_read
    tst     r0, #GRSTCTL_AHBIDLE
    bne     2f
    subs    r5, r5, #1
    bne     1b
    mov     r0, #1
    pop     {r4, r5, pc}
2:
    @ 3. Soft reset
    ldr     r0, =GRSTCTL_CSFTRST
    mov     r1, r0
    mov     r0, #DWC_GRSTCTL
    bl      dwc2_mmio_write
    mov     r5, #0x100000
1:  mov     r0, #DWC_GRSTCTL
    bl      dwc2_mmio_read
    tst     r0, #GRSTCTL_CSFTRST
    beq     2f
    subs    r5, r5, #1
    bne     1b
    mov     r0, #1
    pop     {r4, r5, pc}
2:

    @ 4. Disable global interrupt
    mov     r0, #DWC_GAHBCFG
    bl      dwc2_mmio_read
    bic     r0, r0, #GAHBCFG_GLBL_INTR_EN
    mov     r1, r0
    mov     r0, #DWC_GAHBCFG
    bl      dwc2_mmio_write

    @ 5. Set GUSBCFG: select UTMI+ interface, FS PHY
    @ On BCM2835, the PHY interface is UTMI+ (not ULPI).
    @ TRDT = 0x5 (5+1 = 6 PHY clocks turnaround, typical for UTMI+)
    mov     r0, #DWC_GUSBCFG
    bl      dwc2_mmio_read
    bic     r0, r0, #GUSBCFG_TRDT_MASK
    bic     r0, r0, #GUSBCFG_PHYIF
    bic     r0, r0, #GUSBCFG_FS_INTF
    bic     r0, r0, #GUSBCFG_ULPI_UTMI_SEL
    orr     r0, r0, #(5 << GUSBCFG_TRDT_SHIFT)
    mov     r1, r0
    mov     r0, #DWC_GUSBCFG
    bl      dwc2_mmio_write

    @ 6. Force host mode (clear HNPCAP and SRPCAP, but on BCM2835
    @ the USB controller is in host mode only — no OTG support)
    mov     r0, #DWC_GUSBCFG
    bl      dwc2_mmio_read
    bic     r0, r0, #GUSBCFG_HNPCAP
    bic     r0, r0, #GUSBCFG_SRPCAP
    mov     r1, r0
    mov     r0, #DWC_GUSBCFG
    bl      dwc2_mmio_write

    @ 7. Wait for host mode to take effect (DWC_OTGCTL.HNNF_REQ = 0)
    mov     r5, #0x100000
1:  mov     r0, #DWC_OTGCTL
    bl      dwc2_mmio_read
    tst     r0, #OTGCTL_HNNF_REQ
    beq     2f
    subs    r5, r5, #1
    bne     1b
    mov     r0, #1
    pop     {r4, r5, pc}
2:

    @ 8. Configure host: full-speed host, enable port power
    ldr     r0, =DWC_HCFG
    bl      dwc2_mmio_read
    bic     r0, r0, #HCFG_FSLSS   @ not FS/LS split
    bic     r0, r0, #HCFG_FSLS_PHOST @ not FS/LS only
    mov     r1, r0
    ldr     r0, =DWC_HCFG
    bl      dwc2_mmio_write

    @ 9. Set frame interval for FS (60000 = 1ms at 60MHz)
    ldr     r0, =60000
    mov     r1, r0
    ldr     r0, =DWC_HFIR
    bl      dwc2_mmio_write

    @ 10. Configure FIFO sizes
    @ Rx FIFO: 128 words
    ldr     r0, =FIFO_SIZE_128
    mov     r1, r0
    mov     r0, #DWC_GRXFSIZ
    bl      dwc2_mmio_write

    @ Non-periodic Tx FIFO: 128 words (offset after Rx FIFO)
    ldr     r0, =FIFO_SIZE_128
    ldr     r1, =FIFO_SIZE_128
    lsl     r1, r1, #16
    orr     r0, r0, r1
    mov     r1, r0
    mov     r0, #DWC_GNPTXFSIZ
    bl      dwc2_mmio_write

    @ Periodic Tx FIFO: 128 words (offset after Rx FIFO + NP Tx FIFO)
    ldr     r0, =FIFO_SIZE_128
    ldr     r1, =(FIFO_SIZE_128 + FIFO_SIZE_128)
    lsl     r1, r1, #16
    orr     r0, r0, r1
    mov     r1, r0
    ldr     r0, =DWC_HPTXFSIZ
    bl      dwc2_mmio_write

    @ 11. Enable host channel interrupt and port interrupt
    ldr     r0, =(GINT_HC_INT | GINT_PRT_INT | GINT_DISC_INT)
    mov     r1, r0
    mov     r0, #DWC_GINTMSK
    bl      dwc2_mmio_write

    @ 12. Enable global interrupt in AHB config
    mov     r0, #DWC_GAHBCFG
    bl      dwc2_mmio_read
    orr     r0, r0, #GAHBCFG_GLBL_INTR_EN
    mov     r1, r0
    mov     r0, #DWC_GAHBCFG
    bl      dwc2_mmio_write

    mov     r0, #0
    pop     {r4, r5, pc}

@ ==========================================================
@ dwc2_port_detect — Wait for device connection and enable port
@ Arguments: r0 = pointer to speed byte (filled by function)
@ Returns: r0 = 0 on success
@ ==========================================================
dwc2_port_detect:
    push    {r4, r5, r6, lr}
    mov     r6, r0
    cmp     r6, #0
    beq     .Lport_fail

    @ 1. Power on the port
    ldr     r0, =DWC_HPRT
    bl      dwc2_mmio_read
    orr     r0, r0, #HPRT_PRTPWR
    mov     r1, r0
    ldr     r0, =DWC_HPRT
    bl      dwc2_mmio_write

    @ 2. Wait up to 5 seconds for connection
    ldr     r5, =50000000
1:  ldr     r0, =DWC_HPRT
    bl      dwc2_mmio_read
    tst     r0, #HPRT_PRTCONNDET
    bne     2f
    subs    r5, r5, #1
    bne     1b
    b       .Lport_fail
2:
    @ 3. Clear connection detect bit by writing it
    mov     r1, r0
    ldr     r0, =DWC_HPRT
    bl      dwc2_mmio_write

    @ 4. Wait for port enable
    ldr     r5, =5000000
1:  ldr     r0, =DWC_HPRT
    bl      dwc2_mmio_read
    tst     r0, #HPRT_PRTENA
    bne     2f
    subs    r5, r5, #1
    bne     1b
    @ Port didn't enable — try reset
    b       3f
2:
    @ 5. Read port speed and store
    ldr     r0, =DWC_HPRT
    bl      dwc2_mmio_read
    and     r0, r0, #HPRR_PRT_SPD_MASK
    lsr     r0, r0, #HPRR_PRT_SPD_SHIFT
    strb    r0, [r6]
    mov     r0, #0
    pop     {r4, r5, r6, pc}

    @ 4b. Reset the port
3:  ldr     r0, =DWC_HPRT
    bl      dwc2_mmio_read
    orr     r0, r0, #HPRT_PRTRST
    mov     r1, r0
    ldr     r0, =DWC_HPRT
    bl      dwc2_mmio_write
    ldr     r5, =50000
1:  subs    r5, r5, #1
    bne     1b
    ldr     r0, =DWC_HPRT
    bl      dwc2_mmio_read
    bic     r0, r0, #HPRT_PRTRST
    mov     r1, r0
    ldr     r0, =DWC_HPRT
    bl      dwc2_mmio_write

    @ Wait for port enable after reset
    ldr     r5, =5000000
1:  ldr     r0, =DWC_HPRT
    bl      dwc2_mmio_read
    tst     r0, #HPRT_PRTENA
    bne     2b     @ jump to speed-read above
    subs    r5, r5, #1
    bne     1b

.Lport_fail:
    mov     r0, #1
    pop     {r4, r5, r6, pc}

@ ==========================================================
@ _dwc2_channel_wait — Poll for channel interrupt
@ Arguments: r0 = channel index (0-15)
@ Returns: r0 = channel interrupt status, or 0 on timeout
@ Clobbers: r0-r2
@ ==========================================================
_dwc2_channel_wait:
    push    {lr}
    mov     r2, r0, lsl #5      @ channel * 0x20
    ldr     r1, =(DWC2_BASE + DWC_HCINT)
    add     r2, r1, r2          @ HCINT register address

    ldr     r1, =0x100000        @ timeout counter
1:  ldr     r0, [r2]
    tst     r0, #HCINT_XFER_COMPLETE
    bne     2f
    tst     r0, #HCINT_CH_HALTED
    bne     2f
    subs    r1, r1, #1
    bne     1b
    mov     r0, #0
    pop     {pc}
2:
    str     r0, [r2]
    pop     {pc}

@ ==========================================================
@ _dwc2_chan_setup — Program and start a host channel
@ Arguments:
@   r0 = channel index
@   r1 = device address
@   r2 = endpoint number @ direction (bit 7 = IN)
@   r3 = endpoint type (0/2/3)
@ Stack: [sp] = max packet size
@ Stack: [sp+4] = speed
@ Stack: [sp+8] = total bytes (u32)
@ Stack: [sp+12] = pid (0=DATA0, 2=DATA1, 3=SETUP)
@ Returns: r0 = 0 ok, 1 fail
@ Uses r12 as channel register base (DWC2_BASE + DWC_HCCHAR + chan*0x20)
@ ==========================================================
_dwc2_chan_setup:
    push    {r4, r5, r6, r7, lr}
    ldr     r4, =DWC2_BASE
    mov     r5, r0              @ channel index
    mov     r6, r5, lsl #5     @ offset = n * 0x20
    ldr     r7, =(DWC2_BASE + DWC_HCCHAR)
    add     r12, r7, r6         @ chan_reg_base = DWC2_BASE + 0x500 + n*0x20

    @ Read parameters from stack
    ldr     r8, [sp, #20]       @ max packet size
    ldrb    r9, [sp, #24]       @ speed
    ldr     r10, [sp, #28]      @ total bytes
    ldr     r11, [sp, #32]      @ pid

    @ 1. Disable channel first (if already active)
    ldr     r7, [r12]           @ HCCHAR register
    orr     r7, r7, #HCCHAR_CHDIS
    str     r7, [r12]
    ldr     r14, =1000
1:  ldr     r7, [r12]
    tst     r7, #HCCHAR_CHEN
    beq     2f
    subs    r14, r14, #1
    bne     1b
2:
    @ 2. Build HCCHAR value
    mov     r7, #0

    @ Device address
    lsl     r1, r1, #HCCHAR_DEVADDR_SHIFT
    ldr     r14, =HCCHAR_DEVADDR_MASK
    and     r1, r1, r14
    orr     r7, r7, r1

    @ Endpoint number (bits 14:15) + direction (bit 19)
    and     r2, r2, #0x8f      @ keep ep number (0-15) + direction (bit 7)
    lsl     r14, r2, #15       @ epnum to bits 18:15
    ldr     r1, =HCCHAR_EPNUM_MASK
    and     r14, r14, r1
    orr     r7, r7, r14
    lsl     r14, r2, #12       @ direction bit 7 to bit 19
    ldr     r1, =HCCHAR_EPDIR_IN
    and     r14, r14, r1
    orr     r7, r7, r14

    @ Endpoint type
    lsl     r3, r3, #HCCHAR_EPTYPE_SHIFT
    ldr     r1, =HCCHAR_EPTYPE_MASK
    and     r3, r3, r1
    orr     r7, r7, r3

    @ Speed: set LS bit if speed == LS
    cmp     r9, #USB_SPEED_LS
    moveq   r14, #HCCHAR_LSPDDEV
    orreq   r7, r7, r14

    @ Max packet size
    ldr     r1, =HCCHAR_MPS_MASK
    and     r8, r8, r1
    orr     r7, r7, r8

    @ Write HCCHAR
    str     r7, [r12]

    @ 3. Set HCTSIZ: transfer size, packet count, pid
    mov     r14, r10           @ total bytes
    ldr     r1, =HCTSIZ_XFERSIZE_MASK
    and     r14, r14, r1
    mov     r1, #1
    orr     r14, r14, r1, lsl #HCTSIZ_PKTCNT_SHIFT
    lsl     r11, r11, #HCTSIZ_PID_SHIFT
    ldr     r1, =HCTSIZ_PID_MASK
    and     r11, r11, r1
    orr     r14, r14, r11
    str     r14, [r12, #0x10]   @ HCTSIZ = chan_base + 0x10

    @ 4. Enable channel
    ldr     r7, [r12]
    orr     r7, r7, #HCCHAR_CHEN
    orr     r7, r7, #HCCHAR_CHDIS
    bic     r7, r7, #HCCHAR_CHDIS
    str     r7, [r12]

    @ 5. Wait for completion
    mov     r0, r5
    bl      _dwc2_channel_wait
    cmp     r0, #0
    beq     3f

    @ 6. Check for errors
    tst     r0, #HCINT_STALL
    bne     4f
    tst     r0, #HCINT_NAK
    bne     5f
    tst     r0, #HCINT_TRANSACTION_ERR
    bne     6f
    tst     r0, #HCINT_AHB_ERROR
    bne     6f

    mov     r0, #USB_OK
    pop     {r4, r5, r6, r7, pc}

3:  mov     r0, #USB_TIMEOUT
    pop     {r4, r5, r6, r7, pc}
4:  mov     r0, #USB_STALL
    pop     {r4, r5, r6, r7, pc}
5:  mov     r0, #USB_NAK
    pop     {r4, r5, r6, r7, pc}
6:  mov     r0, #USB_ERROR
    pop     {r4, r5, r6, r7, pc}

@ ==========================================================
@ _dwc2_write_txfifo — Write data to non-periodic Tx FIFO
@ Arguments: r0 = buffer pointer, r1 = word count
@ Uses DFIFO data port at offset 0x1000 (host non-periodic Tx)
@ Clobbers: r0-r2, r12
@ ==========================================================
_dwc2_write_txfifo:
    ldr     r2, =DWC2_BASE
    add     r2, r2, #0x1000
    cmp     r1, #0
    bxle    lr
1:  ldr     r12, [r0], #4
    str     r12, [r2]
    subs    r1, r1, #1
    bne     1b
    bx      lr

@ ==========================================================
@ _dwc2_read_rxfifo — Read data from Rx FIFO
@ Arguments: r0 = buffer pointer, r1 = word count
@ Uses DFIFO data port at offset 0x1000 (shared Rx FIFO)
@ Clobbers: r0-r2, r12
@ ==========================================================
_dwc2_read_rxfifo:
    ldr     r2, =DWC2_BASE
    add     r2, r2, #0x1000
    cmp     r1, #0
    bxle    lr
1:  ldr     r12, [r2]
    str     r12, [r0], #4
    subs    r1, r1, #1
    bne     1b
    bx      lr

@ ==========================================================
@ dwc2_control_xfer — Execute a USB control transfer
@ Arguments: r0 = pointer to ctrl_xfer struct
@ Returns: r0 = 0 ok, -1 timeout, -2 stall, -4 error
@ ==========================================================
dwc2_control_xfer:
    push    {r4, r5, r6, r7, r8, r9, r10, lr}
    mov     r4, r0
    ldr     r5, =DWC2_BASE

    @ Read parameters
    ldrb    r6, [r4, #CTRL_DEVADDR]
    ldrb    r7, [r4, #CTRL_REQTYPE]
    ldrb    r8, [r4, #CTRL_REQUEST]
    ldrb    r9, [r4, #CTRL_VAL_LOW]
    ldrb    r10, [r4, #CTRL_VAL_HIGH]
    ldrb    r11, [r4, #CTRL_IDX_LOW]
    ldrb    r12, [r4, #CTRL_IDX_HIGH]
    ldr     r14, [r4, #CTRL_DATA]
    ldr     r3, [r4, #CTRL_DATALEN]
    ldrh    r2, [r4, #CTRL_MPS]
    ldrb    r1, [r4, #CTRL_SPEED]

    push    {r1, r2, r3, r14}   @ save speed, mps, datalen, data ptr

    @ ---- SETUP stage ----
    @ Build setup packet (8 bytes) on stack
    sub     sp, sp, #8
    strb    r7, [sp, #0]        @ bmRequestType
    strb    r8, [sp, #1]        @ bRequest
    strb    r9, [sp, #2]        @ wValue low
    strb    r10, [sp, #3]       @ wValue high
    strb    r11, [sp, #4]       @ wIndex low
    strb    r12, [sp, #5]       @ wIndex high
    ldr     r12, [sp, #16]      @ datalen from push above
    strb    r12, [sp, #6]       @ wLength low
    lsr     r12, r12, #8
    strb    r12, [sp, #7]       @ wLength high

    @ Write setup packet to Tx FIFO (2 words)
    mov     r0, sp
    mov     r1, #2
    bl      _dwc2_write_txfifo

    @ Program channel 0 for SETUP packet
    @ r0=chan, r1=devaddr, r2=epnum|dir, r3=type
    @ Stack: mps, speed, total_bytes, pid
    mov     r0, #0              @ channel 0
    mov     r1, r6              @ device address
    mov     r2, #0              @ ep 0, OUT
    mov     r3, #EPTYPE_CTRL    @ control
    mov     r12, #8             @ total bytes = 8 (setup packet)
    mov     r11, #HCTSIZ_PID_SETUP  @ PID = SETUP
    ldr     r10, [sp, #20]      @ speed from earlier push
    ldr     r9, [sp, #16]       @ mps from earlier push
    push    {r9, r10, r11, r12}
    bl      _dwc2_chan_setup
    add     sp, sp, #16         @ pop setup args
    add     sp, sp, #8          @ pop setup packet
    cmp     r0, #USB_OK
    bne     .Lctrl_fail

    @ ---- Data stage (if present) ----
    ldr     r3, [r4, #CTRL_DATALEN]
    cmp     r3, #0
    beq     .Lctrl_status_in

    ldrb    r14, [r4, #CTRL_REQTYPE]
    tst     r14, #USB_DIR_IN
    bne     .Lctrl_data_in

    @ Data OUT: write data to Tx FIFO, then channel
    ldr     r0, [r4, #CTRL_DATA]
    ldr     r1, [r4, #CTRL_DATALEN]
    add     r1, r1, #3
    lsr     r1, r1, #2          @ word count (rounded up)
    bl      _dwc2_write_txfifo

    mov     r0, #0              @ channel 0
    mov     r1, r6              @ devaddr
    mov     r2, #0              @ ep 0, OUT
    mov     r3, #EPTYPE_CTRL
    ldr     r12, [r4, #CTRL_DATALEN]
    mov     r11, #HCTSIZ_PID_DATA1  @ DATA1
    ldr     r10, [r4, #CTRL_SPEED]
    ldr     r9, [r4, #CTRL_MPS]
    push    {r9, r10, r11, r12}
    bl      _dwc2_chan_setup
    add     sp, sp, #16
    cmp     r0, #USB_OK
    bne     .Lctrl_fail
    b       .Lctrl_status_in

.Lctrl_data_in:
    @ Data IN: set up channel for receive
    mov     r0, #0              @ channel 0
    mov     r1, r6              @ devaddr
    mov     r2, #USB_DIR_IN     @ ep 0, IN
    mov     r3, #EPTYPE_CTRL
    ldr     r12, [r4, #CTRL_DATALEN]
    mov     r11, #HCTSIZ_PID_DATA1  @ DATA1
    ldr     r10, [r4, #CTRL_SPEED]
    ldr     r9, [r4, #CTRL_MPS]
    push    {r9, r10, r11, r12}
    bl      _dwc2_chan_setup
    add     sp, sp, #16
    cmp     r0, #USB_OK
    bne     .Lctrl_fail

    @ Read received data from Rx FIFO
    ldr     r0, [r4, #CTRL_DATA]
    ldr     r1, [r4, #CTRL_DATALEN]
    add     r1, r1, #3
    lsr     r1, r1, #2
    bl      _dwc2_read_rxfifo

    @ ---- STATUS stage ----
.Lctrl_status_in:
    @ Status IN: device sends 0-byte packet to ack
    mov     r0, #0              @ channel 0
    mov     r1, r6              @ devaddr
    mov     r2, #USB_DIR_IN     @ ep 0, IN
    mov     r3, #EPTYPE_CTRL
    mov     r11, #HCTSIZ_PID_DATA1  @ DATA1
    mov     r12, #0             @ 0 bytes
    ldr     r10, [r4, #CTRL_SPEED]
    ldr     r9, [r4, #CTRL_MPS]
    push    {r9, r10, r11, r12}
    bl      _dwc2_chan_setup
    add     sp, sp, #16
    cmp     r0, #USB_OK
    bne     .Lctrl_fail

    mov     r0, #USB_OK
    str     r0, [r4, #CTRL_STATUS]
    pop     {r4, r5, r6, r7, r8, r9, r10, pc}

.Lctrl_fail:
    str     r0, [r4, #CTRL_STATUS]
    pop     {r4, r5, r6, r7, r8, r9, r10, pc}

@ ==========================================================
@ dwc2_bulk_xfer — Execute a USB bulk transfer
@ Arguments: r0 = pointer to xfer struct
@ Returns: r0 = 0 ok, -1 timeout, -2 stall, -3 nak, -4 error
@ ==========================================================
dwc2_bulk_xfer:
    push    {r4, r5, lr}
    mov     r4, r0

    ldrb    r1, [r4, #XFER_DEVADDR]
    ldrb    r2, [r4, #XFER_EPNUM]
    ldrb    r3, [r4, #XFER_DIR]
    orr     r2, r2, r3          @ combine epnum + direction
    ldrb    r3, [r4, #XFER_EPTYPE]
    ldrh    r9, [r4, #XFER_MPS]
    ldrb    r10, [r4, #XFER_SPEED]
    ldr     r12, [r4, #XFER_LEN]
    ldr     r14, [r4, #XFER_BUF]

    @ Choose channel 1 for bulk (leave channel 0 for control)
    mov     r0, #1

    @ PID: use DATA0 for first transfer (simplified — no toggle tracking)
    mov     r11, #HCTSIZ_PID_DATA0

    @ For OUT, write data to Tx FIFO first
    ldrb    r5, [r4, #XFER_DIR]
    tst     r5, #USB_DIR_IN
    bne     .Lbulk_in

    @ Bulk OUT: write data to non-periodic Tx FIFO
    mov     r0, r14
    mov     r1, r12
    add     r1, r1, #3
    lsr     r1, r1, #2
    bl      _dwc2_write_txfifo

    mov     r0, #1              @ channel 1
    @ r1-r3 already set
    push    {r9, r10, r11, r12}
    bl      _dwc2_chan_setup
    add     sp, sp, #16
    cmp     r0, #USB_OK
    bne     .Lbulk_fail
    b       .Lbulk_done

.Lbulk_in:
    mov     r0, #1              @ channel 1
    push    {r9, r10, r11, r12}
    bl      _dwc2_chan_setup
    add     sp, sp, #16
    cmp     r0, #USB_OK
    bne     .Lbulk_fail

    @ Read data from Rx FIFO
    mov     r0, r14
    ldr     r1, [r4, #XFER_LEN]
    add     r1, r1, #3
    lsr     r1, r1, #2
    bl      _dwc2_read_rxfifo

.Lbulk_done:
    mov     r0, #USB_OK
    str     r0, [r4, #XFER_ACTUAL]
    pop     {r4, r5, pc}

.Lbulk_fail:
    str     r0, [r4, #XFER_ACTUAL]
    pop     {r4, r5, pc}

@ ==========================================================
@ dwc2_enumerate — Full USB device enumeration
@ Arguments: none
@ Returns: r0 = device address (1-127) on success, 0 on failure
@
@ Performs:
@   1. Get Device Descriptor (first 8 bytes)
@   2. Set Address (address 1)
@   3. Get Device Descriptor (full, 18 bytes)
@   4. Get Configuration Descriptor
@   5. Set Configuration (config 1)
@ ==========================================================
dwc2_enumerate:
    push    {r4, r5, r6, r7, r8, lr}
    sub     sp, sp, #72          @ space for descriptors

    @ ---- Step 1: Get first 8 bytes of device descriptor ----
    mov     r0, sp
    @ ctrl_xfer struct on stack
    mov     r7, sp

    @ Build ctrl struct
    mov     r1, #0              @ device address = 0
    strb    r1, [r7, #CTRL_DEVADDR]
    mov     r1, #(USB_DIR_IN | USB_REQ_STANDARD | USB_RECIP_DEVICE)
    strb    r1, [r7, #CTRL_REQTYPE]
    mov     r1, #USB_REQ_GET_DESC
    strb    r1, [r7, #CTRL_REQUEST]
    mov     r1, #USB_DESC_DEVICE
    strb    r1, [r7, #CTRL_VAL_LOW]     @ descriptor type
    mov     r1, #0
    strb    r1, [r7, #CTRL_VAL_HIGH]    @ descriptor index
    strb    r1, [r7, #CTRL_IDX_LOW]
    strb    r1, [r7, #CTRL_IDX_HIGH]
    add     r1, r7, #28
    str     r1, [r7, #CTRL_DATA]        @ buffer at sp+28
    mov     r1, #8
    str     r1, [r7, #CTRL_DATALEN]
    mov     r1, #64
    strh    r1, [r7, #CTRL_MPS]         @ assume 64 for HS
    ldr     r1, =USB_SPEED_HS
    strb    r1, [r7, #CTRL_SPEED]

    mov     r0, r7
    bl      dwc2_control_xfer
    cmp     r0, #USB_OK
    bne     .Lenum_fail

    @ Read max packet size from descriptor byte 7 (bMaxPacketSize0)
    add     r0, r7, #28
    ldrb    r5, [r0, #7]         @ bMaxPacketSize0
    cmp     r5, #0
    movne   r5, r5               @ keep if valid
    moveq   r5, #64              @ default to 64

    @ ---- Step 2: Set address to 1 ----
    mov     r1, #0
    strb    r1, [r7, #CTRL_DEVADDR]     @ still address 0
    mov     r1, #(USB_DIR_OUT | USB_REQ_STANDARD | USB_RECIP_DEVICE)
    strb    r1, [r7, #CTRL_REQTYPE]
    mov     r1, #USB_REQ_SET_ADDR
    strb    r1, [r7, #CTRL_REQUEST]
    mov     r1, #1
    strb    r1, [r7, #CTRL_VAL_LOW]     @ address = 1
    mov     r1, #0
    strb    r1, [r7, #CTRL_VAL_HIGH]
    strb    r1, [r7, #CTRL_IDX_LOW]
    strb    r1, [r7, #CTRL_IDX_HIGH]
    mov     r1, #0
    str     r1, [r7, #CTRL_DATA]        @ no data
    str     r1, [r7, #CTRL_DATALEN]
    @ Use correct MPS from descriptor
    strh    r5, [r7, #CTRL_MPS]

    mov     r0, r7
    bl      dwc2_control_xfer
    cmp     r0, #USB_OK
    bne     .Lenum_fail

    mov     r6, #1                       @ device address = 1

    @ ---- Step 3: Get full device descriptor (18 bytes) ----
    mov     r1, #1
    strb    r1, [r7, #CTRL_DEVADDR]      @ new address
    mov     r1, #(USB_DIR_IN | USB_REQ_STANDARD | USB_RECIP_DEVICE)
    strb    r1, [r7, #CTRL_REQTYPE]
    mov     r1, #USB_REQ_GET_DESC
    strb    r1, [r7, #CTRL_REQUEST]
    mov     r1, #USB_DESC_DEVICE
    strb    r1, [r7, #CTRL_VAL_LOW]
    mov     r1, #0
    strb    r1, [r7, #CTRL_VAL_HIGH]
    strb    r1, [r7, #CTRL_IDX_LOW]
    strb    r1, [r7, #CTRL_IDX_HIGH]
    add     r1, r7, #28
    str     r1, [r7, #CTRL_DATA]
    mov     r1, #18
    str     r1, [r7, #CTRL_DATALEN]
    strh    r5, [r7, #CTRL_MPS]

    mov     r0, r7
    bl      dwc2_control_xfer
    cmp     r0, #USB_OK
    bne     .Lenum_fail

    @ ---- Step 4: Get configuration descriptor ----
    @ We just get the first config (9-byte header, then full)
    mov     r1, #1
    strb    r1, [r7, #CTRL_DEVADDR]
    mov     r1, #(USB_DIR_IN | USB_REQ_STANDARD | USB_RECIP_DEVICE)
    strb    r1, [r7, #CTRL_REQTYPE]
    mov     r1, #USB_REQ_GET_DESC
    strb    r1, [r7, #CTRL_REQUEST]
    mov     r1, #USB_DESC_CONFIG
    strb    r1, [r7, #CTRL_VAL_LOW]
    mov     r1, #0
    strb    r1, [r7, #CTRL_VAL_HIGH]
    strb    r1, [r7, #CTRL_IDX_LOW]
    strb    r1, [r7, #CTRL_IDX_HIGH]
    add     r1, r7, #28
    str     r1, [r7, #CTRL_DATA]
    mov     r1, #64
    str     r1, [r7, #CTRL_DATALEN]
    strh    r5, [r7, #CTRL_MPS]

    mov     r0, r7
    bl      dwc2_control_xfer
    cmp     r0, #USB_OK
    bne     .Lenum_fail

    @ ---- Step 5: Set configuration 1 ----
    mov     r1, #1
    strb    r1, [r7, #CTRL_DEVADDR]
    mov     r1, #(USB_DIR_OUT | USB_REQ_STANDARD | USB_RECIP_DEVICE)
    strb    r1, [r7, #CTRL_REQTYPE]
    mov     r1, #USB_REQ_SET_CFG
    strb    r1, [r7, #CTRL_REQUEST]
    mov     r1, #1
    strb    r1, [r7, #CTRL_VAL_LOW]     @ configuration 1
    mov     r1, #0
    strb    r1, [r7, #CTRL_VAL_HIGH]
    strb    r1, [r7, #CTRL_IDX_LOW]
    strb    r1, [r7, #CTRL_IDX_HIGH]
    mov     r1, #0
    str     r1, [r7, #CTRL_DATA]
    str     r1, [r7, #CTRL_DATALEN]
    strh    r5, [r7, #CTRL_MPS]

    mov     r0, r7
    bl      dwc2_control_xfer
    cmp     r0, #USB_OK
    bne     .Lenum_fail

    @ Success! Return device address
    mov     r0, r6
    add     sp, sp, #72
    pop     {r4, r5, r6, r7, r8, pc}

.Lenum_fail:
    mov     r0, #0
    add     sp, sp, #72
    pop     {r4, r5, r6, r7, r8, pc}

@ ---- default MMIO hooks ----
dwc2_mmio_read:
    ldr     r1, =DWC2_BASE
    ldr     r0, [r1, r0]
    bx      lr

dwc2_mmio_write:
    ldr     r2, =DWC2_BASE
    str     r1, [r2, r0]
    bx      lr

dwc2_msc_bulk_xfer:
    b       dwc2_bulk_xfer
