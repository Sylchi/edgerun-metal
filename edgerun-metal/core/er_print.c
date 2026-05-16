#include "er_print.h"

#define ER_COM1_PORT 0x03f8u

static EFI_SYSTEM_TABLE* g_st;
static UINT8 g_serial_ready;

static inline void er_io_out8(UINT16 port, UINT8 value) {
  __asm__ __volatile__("outb %0, %1" : : "a"(value), "Nd"(port));
}

static inline UINT8 er_io_in8(UINT16 port) {
  UINT8 value = 0;
  __asm__ __volatile__("inb %1, %0" : "=a"(value) : "Nd"(port));
  return value;
}

static void er_serial_init(void) {
  if (g_serial_ready != 0) {
    return;
  }

  er_io_out8((UINT16)(ER_COM1_PORT + 1u), 0x00u); /* disable interrupts */
  er_io_out8((UINT16)(ER_COM1_PORT + 3u), 0x80u); /* enable DLAB */
  er_io_out8((UINT16)(ER_COM1_PORT + 0u), 0x03u); /* divisor low: 38400 baud */
  er_io_out8((UINT16)(ER_COM1_PORT + 1u), 0x00u); /* divisor high */
  er_io_out8((UINT16)(ER_COM1_PORT + 3u), 0x03u); /* 8n1 */
  er_io_out8((UINT16)(ER_COM1_PORT + 2u), 0xc7u); /* fifo on, clear, 14-byte threshold */
  er_io_out8((UINT16)(ER_COM1_PORT + 4u), 0x0bu); /* irq enabled, rts/dsr set */

  g_serial_ready = 1;
}

static void er_serial_putc(char c) {
  UINT32 spins = 0;

  er_serial_init();
  while ((er_io_in8((UINT16)(ER_COM1_PORT + 5u)) & 0x20u) == 0u && spins < 1000000u) {
    ++spins;
  }
  er_io_out8((UINT16)ER_COM1_PORT, (UINT8)c);
}

static void er_serial_write(const char* s) {
  UINTN i;

  if (s == 0) {
    return;
  }

  for (i = 0; s[i] != 0; ++i) {
    er_serial_putc(s[i]);
  }
}

void er_print_set_system_table(EFI_SYSTEM_TABLE* st) {
  g_st = st;
  er_serial_init();
}

void er_print(const char* s) {
  CHAR16 out[256];
  UINTN i;
  UINTN j = 0;

  if (s == 0) {
    return;
  }

  er_serial_write(s);

  if (g_st == 0 || g_st->ConOut == 0 || g_st->ConOut->OutputString == 0) {
    return;
  }

  for (i = 0; s[i] != 0 && j < (sizeof(out) / sizeof(CHAR16)) - 1; ++i) {
    out[j++] = (CHAR16)(UINT16)(UINT8)s[i];
  }
  out[j] = 0;
  g_st->ConOut->OutputString(g_st->ConOut, out);
}

void er_println(const char* s) {
  if (s == 0) {
    s = "";
  }

  er_print(s);
  er_print("\r\n");
}

void er_print_u64_hex(UINT64 value) {
  char buf[24];
  const char hex_digits[16] = "0123456789abcdef";
  int i = 0;
  UINTN n;

  buf[i++] = '0';
  buf[i++] = 'x';

  for (n = 16; n > 0; --n) {
    UINT8 nibble = (UINT8)((value >> ((n - 1) * 4)) & 0xf);
    buf[i++] = hex_digits[nibble];
  }

  buf[i] = 0;
  er_print(buf);
}

void er_print_u64_dec(UINT64 value) {
  char buf[24];
  int i = 0;
  UINT64 tmp = value;

  if (tmp == 0) {
    er_print("0");
    return;
  }

  while (tmp > 0 && i < (int)(sizeof(buf) - 1)) {
    buf[i++] = (char)('0' + (tmp % 10));
    tmp /= 10;
  }

  for (int left = 0, right = i - 1; left < right; ++left, --right) {
    char t = buf[left];
    buf[left] = buf[right];
    buf[right] = t;
  }

  buf[i] = 0;
  er_print(buf);
}