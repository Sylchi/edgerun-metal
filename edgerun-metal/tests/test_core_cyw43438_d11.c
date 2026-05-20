#include "test_core_internal.h"

static void test_cyw43438_d11_registers(void) {
  check_uint64("cyw43438 d11 maccontrol offset",
               ER_CYW43438_D11_MACCONTROL,
               0x120u);
  check_uint64("cyw43438 d11 xmtfifocmd offset",
               ER_CYW43438_D11_XMTFIFOCMD,
               0x540u);
  check_uint64("cyw43438 d11 xmtfifordy offset",
               ER_CYW43438_D11_XMTFIFORDY,
               ER_CYW43438_D11_XMTFIFOCMD + 6u);
  check_uint64("cyw43438 d11 bcmc fifo",
               ER_CYW43438_D11_TX_BCMC_FIFO,
               4u);
  check_uint64("cyw43438 d11 maccontrol probe",
               ER_CYW43438_D11_MACCONTROL_PROBE,
               ER_CYW43438_D11_MCTL_WAKE |
                   ER_CYW43438_D11_MCTL_IHR_EN |
                   ER_CYW43438_D11_MCTL_SHM_EN);
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
}
