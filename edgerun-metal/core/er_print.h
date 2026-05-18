#ifndef ER_PRINT_H
#define ER_PRINT_H

#include "er_types.h"

void er_print_set_system_table(EFI_SYSTEM_TABLE* st);
void er_print_set_firmware_console_enabled(UINT8 enabled);
void er_print(const char* s);
void er_println(const char* s);
void er_print_u64_dec(UINT64 value);
void er_print_u64_hex(UINT64 value);

#endif
