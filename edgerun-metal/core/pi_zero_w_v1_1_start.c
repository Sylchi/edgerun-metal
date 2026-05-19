#include "er_types.h"

/*
 * Purpose: provide the first owned ARMv6 payload for Raspberry Pi Zero W v1.1.
 * Intention: make the BCM2835 boot path buildable without pretending it can use
 * the AArch64 EFI payload used by Pi Zero 2 W.
 */

#define ER_PI_ZERO_W_V1_1_BOOT_MAGIC 0x45525a57u

volatile UINT32 g_er_pi_zero_w_v1_1_boot_magic =
    ER_PI_ZERO_W_V1_1_BOOT_MAGIC;

void _start(void) {
  for (;;) {
    g_er_pi_zero_w_v1_1_boot_magic = ER_PI_ZERO_W_V1_1_BOOT_MAGIC;
  }
}
