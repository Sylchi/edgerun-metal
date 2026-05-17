#ifndef ER_NETLOG_H
#define ER_NETLOG_H

/*
 * Purpose: mirror early UEFI diagnostics over firmware-managed UDP4 when available.
 * Intention: keep boot output capturable without ExitBootServices or a NIC driver.
 */

#include "er_types.h"

void er_netlog_init(EFI_SYSTEM_TABLE* st);
void er_netlog_write(const char* s);
void er_netlog_write_text(const char* s);
void er_netlog_flush_text(void);
void er_netlog_write_bytes(const UINT8* data, UINTN len);
UINT8 er_netlog_write_bytes_wait(const UINT8* data, UINTN len, UINT32 poll_limit);
UINT8 er_netlog_ready(void);

#endif
