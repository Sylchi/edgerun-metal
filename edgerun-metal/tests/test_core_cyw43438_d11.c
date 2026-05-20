#include "test_core_internal.h"

static void test_cyw43438_d11_registers(void) {
  check_uint64("cyw43438 d11 maccontrol offset",
               ER_CYW43438_D11_MACCONTROL,
               0x120u);
  check_uint64("cyw43438 d11 xmtfifocmd offset",
               ER_CYW43438_D11_XMTFIFOCMD,
               0x540u);
  check_uint64("cyw43438 d11 template write pointer offset",
               ER_CYW43438_D11_TPLATEWRPTR,
               0x130u);
  check_uint64("cyw43438 d11 template write data offset",
               ER_CYW43438_D11_TPLATEWRDATA,
               ER_CYW43438_D11_TPLATEWRPTR + (UINT32)sizeof(UINT32));
  check_uint64("cyw43438 d11 frame tx status offset",
               ER_CYW43438_D11_FRMTXSTATUS,
               0x170u);
  check_uint64("cyw43438 d11 frame tx status2 offset",
               ER_CYW43438_D11_FRMTXSTATUS2,
               ER_CYW43438_D11_FRMTXSTATUS + (UINT32)sizeof(UINT32));
  check_uint64("cyw43438 d11 xmtfifordy offset",
               ER_CYW43438_D11_XMTFIFORDY,
               ER_CYW43438_D11_XMTFIFOCMD + 6u);
  check_uint64("cyw43438 d11 txe status offset",
               ER_CYW43438_D11_TXE_STATUS,
               0x50eu);
  check_uint64("cyw43438 d11 tx fifo frame counter offset",
               ER_CYW43438_D11_XMTFIFO_FRAME_CNT,
               0x522u);
  check_uint64("cyw43438 d11 tx fifo byte counter offset",
               ER_CYW43438_D11_XMTFIFO_BYTE_CNT,
               ER_CYW43438_D11_XMTFIFO_FRAME_CNT + (UINT32)sizeof(UINT16));
  check_uint64("cyw43438 d11 tx fifo write pointer offset",
               ER_CYW43438_D11_XMTFIFO_WR_PTR,
               0x52au);
  check_uint64("cyw43438 d11 fifo64 stride",
               ER_CYW43438_D11_FIFO64_STRIDE,
               0x40u);
  check_uint64("cyw43438 d11 bcmc fifo",
               ER_CYW43438_D11_TX_BCMC_FIFO,
               4u);
  check_uint64("cyw43438 d11 maccontrol probe",
               ER_CYW43438_D11_MACCONTROL_PROBE,
               ER_CYW43438_D11_MCTL_WAKE |
                   ER_CYW43438_D11_MCTL_IHR_EN |
                   ER_CYW43438_D11_MCTL_SHM_EN);
  check_uint64("cyw43438 d11 maccontrol tx attempt",
               ER_CYW43438_D11_MACCONTROL_TX_ATTEMPT,
               ER_CYW43438_D11_MACCONTROL_PROBE |
                   ER_CYW43438_D11_MCTL_EN_MAC);
  check_uint64("cyw43438 d11 tx fifo select",
               ER_CYW43438_D11_TX_BCMC_FIFO_SELECT,
               ER_CYW43438_D11_TX_BCMC_FIFO <<
                   ER_CYW43438_D11_TXFIFOCMD_FIFOSEL_SHIFT);
  check_uint64("cyw43438 d11 tx fifo reset",
               ER_CYW43438_D11_TX_BCMC_FIFO_RESET,
               ER_CYW43438_D11_TXFIFOCMD_RESET |
                   ER_CYW43438_D11_TX_BCMC_FIFO_SELECT);
  check_uint64("cyw43438 d11 tx fifo select mask covers bcmc",
               ER_CYW43438_D11_TX_BCMC_FIFO_SELECT &
                   ER_CYW43438_D11_TXFIFOCMD_FIFOSEL_MASK,
               ER_CYW43438_D11_TX_BCMC_FIFO_SELECT);
  check_uint64("cyw43438 d11 bcmc pio tx control",
               ER_CYW43438_D11_TX_BCMC_PIO_TX_CONTROL,
               ER_CYW43438_D11_FIFO64_BASE +
                   (ER_CYW43438_D11_TX_BCMC_FIFO *
                    ER_CYW43438_D11_FIFO64_STRIDE) +
                   ER_CYW43438_D11_FIFO64_PIO_TX_OFFSET);
  check_uint64("cyw43438 d11 bcmc pio tx data",
               ER_CYW43438_D11_TX_BCMC_PIO_TX_DATA,
               ER_CYW43438_D11_TX_BCMC_PIO_TX_CONTROL +
                   (UINT32)sizeof(UINT32));
}
