#ifndef ER_GFX_CONSOLE_H
#define ER_GFX_CONSOLE_H

/*
 * Purpose: mirror early boot text into the UEFI framebuffer at TV-readable size.
 * Intention: keep real-hardware diagnostics visible without depending on firmware font scaling.
 */

#include "er_types.h"

void er_gfx_console_init(EFI_SYSTEM_TABLE* st);
void er_gfx_console_write(const char* s);

#endif
