#ifndef ER_NETLOG_H
#define ER_NETLOG_H

/*
 * Purpose: provide an explicit firmware-managed UDP4 transmit path before
 * native NIC drivers own packet I/O.
 */

#include "er_types.h"

UINT8 er_netlog_init(EFI_SYSTEM_TABLE* st);
UINT8 er_netlog_write_bytes_wait(const UINT8* data, UINTN len, UINT32 poll_limit);
UINT8 er_netlog_ready(void);

#endif
