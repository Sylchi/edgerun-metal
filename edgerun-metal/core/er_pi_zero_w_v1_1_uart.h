#ifndef ER_PI_ZERO_W_V1_1_UART_H
#define ER_PI_ZERO_W_V1_1_UART_H

/*
 * Purpose: define the Raspberry Pi Zero W v1.1 early mini UART boundary.
 * Intention: make the first ARMv6 hardware proof visible over serial without
 * pulling in firmware, libc, or host assumptions.
 */

#include "er_types.h"

#define ER_PI_ZERO_W_V1_1_GPIO_BASE 0x20200000u
#define ER_PI_ZERO_W_V1_1_AUX_BASE 0x20215000u

#define ER_PI_GPIO_GPFSEL1 0x00000004u
#define ER_PI_GPIO_GPPUD 0x00000094u
#define ER_PI_GPIO_GPPUDCLK0 0x00000098u

#define ER_PI_AUX_ENABLES 0x00000004u
#define ER_PI_AUX_MU_IO 0x00000040u
#define ER_PI_AUX_MU_IER 0x00000044u
#define ER_PI_AUX_MU_IIR 0x00000048u
#define ER_PI_AUX_MU_LCR 0x0000004cu
#define ER_PI_AUX_MU_MCR 0x00000050u
#define ER_PI_AUX_MU_LSR 0x00000054u
#define ER_PI_AUX_MU_CNTL 0x00000060u
#define ER_PI_AUX_MU_BAUD 0x00000068u

#define ER_PI_GPIO_PIN_UART_TX 14u
#define ER_PI_GPIO_PIN_UART_RX 15u
#define ER_PI_GPIO_ALT5 2u
#define ER_PI_GPIO_FSEL_BITS_PER_PIN 3u
#define ER_PI_GPIO_FSEL_PIN_MOD 10u
#define ER_PI_GPIO_FSEL_MASK 7u

#define ER_PI_GPIO_PULL_DISABLE 0u
#define ER_PI_GPIO_PULL_CLOCK_UART ((1u << ER_PI_GPIO_PIN_UART_TX) | \
                                    (1u << ER_PI_GPIO_PIN_UART_RX))

#define ER_PI_AUX_ENABLE_MINI_UART 1u
#define ER_PI_AUX_MU_DISABLE 0u
#define ER_PI_AUX_MU_ENABLE_TX_RX 3u
#define ER_PI_AUX_MU_DISABLE_INTERRUPTS 0u
#define ER_PI_AUX_MU_CLEAR_FIFOS 0xc6u
#define ER_PI_AUX_MU_EIGHT_BIT_MODE 3u
#define ER_PI_AUX_MU_RTS_HIGH 0u
#define ER_PI_AUX_MU_LSR_TX_EMPTY 0x20u
#define ER_PI_AUX_MU_BAUD_115200_CORE_250MHZ 270u

#define ER_PI_ZERO_W_V1_1_UART_GPIO_DELAY_TICKS 150u

static inline UINT32 er_pi_gpio_fsel_shift(UINT32 pin) {
  return (pin % ER_PI_GPIO_FSEL_PIN_MOD) * ER_PI_GPIO_FSEL_BITS_PER_PIN;
}

static inline UINT32 er_pi_gpio_fsel_alt(UINT32 current,
                                         UINT32 pin,
                                         UINT32 alt_function) {
  UINT32 shift = er_pi_gpio_fsel_shift(pin);
  UINT32 mask = ER_PI_GPIO_FSEL_MASK << shift;

  return (current & ~mask) |
         ((alt_function & ER_PI_GPIO_FSEL_MASK) << shift);
}

#endif
