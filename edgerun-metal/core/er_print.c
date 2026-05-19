#include "er_print.h"
#include "er_gfx_console.h"
#include "erwire.h"

#define ER_COM1_PORT 0x03f8u
#define ER_SERIAL_INTERRUPT_ENABLE_OFFSET 1u
#define ER_SERIAL_FIFO_CONTROL_OFFSET 2u
#define ER_SERIAL_LINE_CONTROL_OFFSET 3u
#define ER_SERIAL_MODEM_CONTROL_OFFSET 4u
#define ER_SERIAL_LINE_STATUS_OFFSET 5u
#define ER_SERIAL_INTERRUPTS_DISABLED 0x00u
#define ER_SERIAL_DLAB_ENABLE 0x80u
#define ER_SERIAL_DIVISOR_LOW_38400 0x03u
#define ER_SERIAL_DIVISOR_HIGH_38400 0x00u
#define ER_SERIAL_LINE_8N1 0x03u
#define ER_SERIAL_FIFO_ENABLE_CLEAR_14B 0xc7u
#define ER_SERIAL_MODEM_IRQ_RTS_DSR 0x0bu
#define ER_SERIAL_TX_READY_MASK 0x20u
#define ER_SERIAL_TX_WAIT_SPINS 1000000u
#define ER_PRINT_FW_BUFFER_CHARS 256u
#define ER_PRINT_HEX_BUF_CHARS 24u
#define ER_PRINT_HEX_DIGITS 16u
#define ER_PRINT_HEX_BITS_PER_DIGIT 4u
#define ER_PRINT_HEX_DIGIT_MASK 0xfu
#define ER_PRINT_DEC_BUF_CHARS 24u
#define ER_PRINT_DEC_BASE 10u

#if defined(ER_TARGET_X86_64) || defined(__x86_64__) || defined(_M_X64)
#define ER_PRINT_SERIAL_PORT_SUPPORTED 1u
#else
#define ER_PRINT_SERIAL_PORT_SUPPORTED 0u
#endif

static EFI_SYSTEM_TABLE* g_st;
static UINT8 g_serial_ready;
static UINT8 g_firmware_console_enabled = 1u;
static UINT8 g_serial_direct_enabled = 1u;

#ifdef ER_ENABLE_TEST_HOOKS
static UINT64 g_test_serial_byte_count;
#endif

static inline void er_io_out8(UINT16 port, UINT8 value) {
#if ER_PRINT_SERIAL_PORT_SUPPORTED
  __asm__ __volatile__("outb %0, %1" : : "a"(value), "Nd"(port));
#else
  (void)port;
  (void)value;
#endif
}

static void er_serial_init(void) {
  if (ER_PRINT_SERIAL_PORT_SUPPORTED == 0u) {
    return;
  }
  if (g_serial_ready != 0) {
    return;
  }

  er_io_out8((UINT16)(ER_COM1_PORT + ER_SERIAL_INTERRUPT_ENABLE_OFFSET), ER_SERIAL_INTERRUPTS_DISABLED);
  er_io_out8((UINT16)(ER_COM1_PORT + ER_SERIAL_LINE_CONTROL_OFFSET), ER_SERIAL_DLAB_ENABLE);
  er_io_out8((UINT16)ER_COM1_PORT, ER_SERIAL_DIVISOR_LOW_38400);
  er_io_out8((UINT16)(ER_COM1_PORT + ER_SERIAL_INTERRUPT_ENABLE_OFFSET), ER_SERIAL_DIVISOR_HIGH_38400);
  er_io_out8((UINT16)(ER_COM1_PORT + ER_SERIAL_LINE_CONTROL_OFFSET), ER_SERIAL_LINE_8N1);
  er_io_out8((UINT16)(ER_COM1_PORT + ER_SERIAL_FIFO_CONTROL_OFFSET), ER_SERIAL_FIFO_ENABLE_CLEAR_14B);
  er_io_out8((UINT16)(ER_COM1_PORT + ER_SERIAL_MODEM_CONTROL_OFFSET), ER_SERIAL_MODEM_IRQ_RTS_DSR);

  g_serial_ready = 1;
}

#ifndef ER_ENABLE_TEST_HOOKS
static inline UINT8 er_io_in8(UINT16 port) {
  UINT8 value = 0;
#if ER_PRINT_SERIAL_PORT_SUPPORTED
  __asm__ __volatile__("inb %1, %0" : "=a"(value) : "Nd"(port));
#else
  (void)port;
#endif
  return value;
}
#endif

static void er_serial_putc(char c) {
#ifndef ER_ENABLE_TEST_HOOKS
  UINT32 spins = 0;
#endif

#ifdef ER_ENABLE_TEST_HOOKS
  (void)c;
  ++g_test_serial_byte_count;
  return;
#else
  if (ER_PRINT_SERIAL_PORT_SUPPORTED == 0u) {
    return;
  }
  er_serial_init();
  while ((er_io_in8((UINT16)(ER_COM1_PORT + ER_SERIAL_LINE_STATUS_OFFSET)) & ER_SERIAL_TX_READY_MASK) == 0u &&
         spins < ER_SERIAL_TX_WAIT_SPINS) {
    ++spins;
  }
  er_io_out8((UINT16)ER_COM1_PORT, (UINT8)c);
#endif
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
  g_firmware_console_enabled = 1u;
  g_serial_direct_enabled = 0u;
  er_serial_init();
  er_gfx_console_init(st);
  erwire_init(1u);
  erwire_send_text("erwire: init ok");
}

void er_print_set_firmware_console_enabled(UINT8 enabled) {
  g_firmware_console_enabled = (UINT8)(enabled != 0u);
  g_serial_direct_enabled = (UINT8)(enabled == 0u);
}

void er_print_set_serial_mirror_enabled(UINT8 enabled) {
  g_serial_direct_enabled = (UINT8)(enabled != 0u);
}

#ifdef ER_ENABLE_TEST_HOOKS
void er_print_test_reset(EFI_SYSTEM_TABLE* st) {
  g_st = st;
  g_serial_ready = 1u;
  g_firmware_console_enabled = 1u;
  g_serial_direct_enabled = 0u;
  g_test_serial_byte_count = 0u;
}

UINT64 er_print_test_serial_byte_count(void) {
  return g_test_serial_byte_count;
}
#endif

void er_print(const char* s) {
  CHAR16 out[ER_PRINT_FW_BUFFER_CHARS];
  UINTN i;
  UINTN j = 0;

  if (s == 0) {
    return;
  }

  if (g_serial_direct_enabled != 0u ||
      g_st == 0 ||
      g_st->ConOut == 0 ||
      g_st->ConOut->OutputString == 0) {
    er_serial_write(s);
  }
  er_gfx_console_write(s);

  if (g_firmware_console_enabled == 0u || g_st == 0 || g_st->ConOut == 0 || g_st->ConOut->OutputString == 0) {
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
  char buf[ER_PRINT_HEX_BUF_CHARS];
  const char hex_digits[] = "0123456789abcdef";
  int i = 0;
  UINTN n;

  buf[i++] = '0';
  buf[i++] = 'x';

  for (n = ER_PRINT_HEX_DIGITS; n > 0; --n) {
    UINT8 nibble = (UINT8)((value >> ((n - 1u) * ER_PRINT_HEX_BITS_PER_DIGIT)) & ER_PRINT_HEX_DIGIT_MASK);
    buf[i++] = hex_digits[nibble];
  }

  buf[i] = 0;
  er_print(buf);
}

//@optimizer-ignore-function decimal logging must emit each digit from the integer value without libc formatting
void er_print_u64_dec(UINT64 value) {
  char buf[ER_PRINT_DEC_BUF_CHARS];
  int i = 0;
  UINT64 tmp = value;

  if (tmp == 0) {
    er_print("0");
    return;
  }

  while (tmp > 0 && i < (int)(sizeof(buf) - 1)) {
    buf[i++] = (char)('0' + (tmp % ER_PRINT_DEC_BASE));
    tmp /= ER_PRINT_DEC_BASE;
  }

  for (int left = 0, right = i - 1; left < right; ++left, --right) {
    char t = buf[left];
    buf[left] = buf[right];
    buf[right] = t;
  }

  buf[i] = 0;
  er_print(buf);
}
