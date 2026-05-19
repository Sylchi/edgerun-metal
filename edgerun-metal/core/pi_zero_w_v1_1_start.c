#include "er_pi_zero_w_v1_1_uart.h"
#include "er_types.h"

/*
 * Purpose: provide the first owned ARMv6 payload for Raspberry Pi Zero W v1.1.
 * Intention: make BCM2835 board bring-up visibly testable over serial without
 * pretending it can use the AArch64 EFI payload used by Pi Zero 2 W.
 */

#define ER_PI_ZERO_W_V1_1_BOOT_MAGIC 0x45525a57u
#define ER_PI_ZERO_W_V1_1_STACK_TOP_ASM "0x8000"

volatile UINT32 g_er_pi_zero_w_v1_1_boot_magic =
    ER_PI_ZERO_W_V1_1_BOOT_MAGIC;

static volatile UINT32* er_pi_zero_w_v1_1_reg(UINT32 base, UINT32 offset) {
  return (volatile UINT32*)(UINTN)(base + offset);
}

static UINT32 er_pi_zero_w_v1_1_read(UINT32 base, UINT32 offset) {
  return *er_pi_zero_w_v1_1_reg(base, offset);
}

static void er_pi_zero_w_v1_1_write(UINT32 base, UINT32 offset, UINT32 value) {
  *er_pi_zero_w_v1_1_reg(base, offset) = value;
}

static void er_pi_zero_w_v1_1_barrier(void) {
  __asm__ volatile("" ::: "memory");
}

static void er_pi_zero_w_v1_1_delay(UINT32 ticks) {
  volatile UINT32 i;

  for (i = 0u; i < ticks; ++i) {
    __asm__ volatile("nop" ::: "memory");
  }
}

static void er_pi_zero_w_v1_1_uart_gpio_init(void) {
  UINT32 fsel1;

  fsel1 = er_pi_zero_w_v1_1_read(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                                 ER_PI_GPIO_GPFSEL1);
  fsel1 = er_pi_gpio_fsel_alt(fsel1,
                              ER_PI_GPIO_PIN_UART_TX,
                              ER_PI_GPIO_ALT5);
  fsel1 = er_pi_gpio_fsel_alt(fsel1,
                              ER_PI_GPIO_PIN_UART_RX,
                              ER_PI_GPIO_ALT5);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                          ER_PI_GPIO_GPFSEL1,
                          fsel1);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                          ER_PI_GPIO_GPPUD,
                          ER_PI_GPIO_PULL_DISABLE);
  er_pi_zero_w_v1_1_delay(ER_PI_ZERO_W_V1_1_UART_GPIO_DELAY_TICKS);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                          ER_PI_GPIO_GPPUDCLK0,
                          ER_PI_GPIO_PULL_CLOCK_UART);
  er_pi_zero_w_v1_1_delay(ER_PI_ZERO_W_V1_1_UART_GPIO_DELAY_TICKS);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_GPIO_BASE,
                          ER_PI_GPIO_GPPUDCLK0,
                          ER_PI_GPIO_PULL_DISABLE);
}

static void er_pi_zero_w_v1_1_uart_init(void) {
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_AUX_BASE,
                          ER_PI_AUX_ENABLES,
                          ER_PI_AUX_ENABLE_MINI_UART);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_AUX_BASE,
                          ER_PI_AUX_MU_CNTL,
                          ER_PI_AUX_MU_DISABLE);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_AUX_BASE,
                          ER_PI_AUX_MU_IER,
                          ER_PI_AUX_MU_DISABLE_INTERRUPTS);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_AUX_BASE,
                          ER_PI_AUX_MU_LCR,
                          ER_PI_AUX_MU_EIGHT_BIT_MODE);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_AUX_BASE,
                          ER_PI_AUX_MU_MCR,
                          ER_PI_AUX_MU_RTS_HIGH);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_AUX_BASE,
                          ER_PI_AUX_MU_IIR,
                          ER_PI_AUX_MU_CLEAR_FIFOS);
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_AUX_BASE,
                          ER_PI_AUX_MU_BAUD,
                          ER_PI_AUX_MU_BAUD_115200_CORE_250MHZ);
  er_pi_zero_w_v1_1_uart_gpio_init();
  er_pi_zero_w_v1_1_barrier();
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_AUX_BASE,
                          ER_PI_AUX_MU_CNTL,
                          ER_PI_AUX_MU_ENABLE_TX_RX);
}

static void er_pi_zero_w_v1_1_uart_putc(char ch) {
  while ((er_pi_zero_w_v1_1_read(ER_PI_ZERO_W_V1_1_AUX_BASE,
                                 ER_PI_AUX_MU_LSR) &
          ER_PI_AUX_MU_LSR_TX_EMPTY) == 0u) {
  }
  er_pi_zero_w_v1_1_write(ER_PI_ZERO_W_V1_1_AUX_BASE,
                          ER_PI_AUX_MU_IO,
                          (UINT32)(UINT8)ch);
}

static void er_pi_zero_w_v1_1_uart_puts(const char* text) {
  UINT32 i = 0u;

  while (text[i] != 0) {
    if (text[i] == '\n') {
      er_pi_zero_w_v1_1_uart_putc('\r');
    }
    er_pi_zero_w_v1_1_uart_putc(text[i]);
    i += 1u;
  }
}

static void er_pi_zero_w_v1_1_uart_put_hex32(UINT32 value) {
  UINT32 i;
  UINT32 shift;

  er_pi_zero_w_v1_1_uart_puts("0x");
  for (i = 0u; i < ER_PI_SERIAL_HEX_DIGITS_U32; ++i) {
    shift = (ER_PI_SERIAL_HEX_DIGITS_U32 - 1u - i) *
            ER_PI_SERIAL_HEX_NIBBLE_BITS;
    er_pi_zero_w_v1_1_uart_putc(
        er_pi_serial_hex_digit(value >> shift));
  }
}

static void er_pi_zero_w_v1_1_uart_put_key_hex32(const char* key,
                                                 UINT32 value) {
  er_pi_zero_w_v1_1_uart_puts(key);
  er_pi_zero_w_v1_1_uart_put_hex32(value);
  er_pi_zero_w_v1_1_uart_puts("\n");
}

void er_pi_zero_w_v1_1_main(void) {
  UINT32 heartbeat = 0u;

  er_pi_zero_w_v1_1_uart_init();
  er_pi_zero_w_v1_1_uart_puts("EdgeRun Pi Zero W v1.1 ARMv6 boot\n");
  er_pi_zero_w_v1_1_uart_puts("board=pi-zero-w-v1_1 radio=cyw43438\n");
  er_pi_zero_w_v1_1_uart_put_key_hex32(
      "peripheral_base=", ER_PI_ZERO_W_V1_1_UART_PERIPHERAL_BASE);
  er_pi_zero_w_v1_1_uart_put_key_hex32(
      "gpio_base=", ER_PI_ZERO_W_V1_1_GPIO_BASE);
  er_pi_zero_w_v1_1_uart_put_key_hex32(
      "aux_base=", ER_PI_ZERO_W_V1_1_AUX_BASE);
  er_pi_zero_w_v1_1_uart_put_key_hex32(
      "boot_magic=", ER_PI_ZERO_W_V1_1_BOOT_MAGIC);

  for (;;) {
    g_er_pi_zero_w_v1_1_boot_magic = ER_PI_ZERO_W_V1_1_BOOT_MAGIC;
    er_pi_zero_w_v1_1_uart_puts("alive=");
    er_pi_zero_w_v1_1_uart_put_hex32(heartbeat);
    er_pi_zero_w_v1_1_uart_puts("\n");
    heartbeat += 1u;
    er_pi_zero_w_v1_1_delay(
        ER_PI_ZERO_W_V1_1_UART_HEARTBEAT_DELAY_TICKS);
  }
}

void _start(void) __attribute__((naked));
void _start(void) {
  __asm__ volatile(
      "ldr sp, =" ER_PI_ZERO_W_V1_1_STACK_TOP_ASM "\n"
      "bl er_pi_zero_w_v1_1_main\n"
      "1: b 1b\n"
      ::: "memory");
}
