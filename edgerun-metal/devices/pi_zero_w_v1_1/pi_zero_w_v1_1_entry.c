#include "er_types.h"

/*
 * Purpose: provide the first bytes of the raw Pi Zero W v1.1 kernel image.
 * Intention: Raspberry Pi firmware jumps to offset zero in kernel.img, so the
 * stack setup and C payload branch must live before every other text symbol.
 */

#define ER_PI_ZERO_W_V1_1_STACK_TOP_ASM "0x8000"

void er_pi_zero_w_v1_1_main(void);

void _start(void) __attribute__((naked));
void _start(void) {
  __asm__ volatile(
      "mov sp, #" ER_PI_ZERO_W_V1_1_STACK_TOP_ASM "\n"
      "bl er_pi_zero_w_v1_1_main\n"
      "1: b 1b\n"
      ::: "memory");
}
