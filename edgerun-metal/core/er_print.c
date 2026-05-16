#include "er_print.h"

static EFI_SYSTEM_TABLE* g_st;

void er_print_set_system_table(EFI_SYSTEM_TABLE* st) {
  g_st = st;
}

void er_print(const char* s) {
  if (g_st == 0 || g_st->ConOut == 0 || g_st->ConOut->OutputString == 0 || s == 0) {
    return;
  }

  CHAR16 out[256];
  UINTN i;
  UINTN j = 0;

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
