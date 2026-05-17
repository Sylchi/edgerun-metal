#ifndef ERWIRE_H
#define ERWIRE_H

/*
 * Purpose: define EdgeRun's compact binary wire packets for firmware-to-host data.
 * Intention: move structured bytes efficiently without JSON, libc, or raw pointers.
 */

#include "er_types.h"
#include "er_work.h"
#include "er_vfs.h"
#include "er_app.h"
#include "er_native_eth.h"

#define ERWIRE_MAGIC 0x31575245u
#define ERWIRE_VERSION 1u
#define ERWIRE_HEADER_SIZE 32u
#define ERWIRE_KIND_LOG_TEXT 1u
#define ERWIRE_KIND_BLOB_CHUNK 2u
#define ERWIRE_KIND_PCI_DEVICE 16u
#define ERWIRE_KIND_BUS_OP32_REQUEST 20u
#define ERWIRE_KIND_BUS_OP32_RESPONSE 21u
#define ERWIRE_KIND_ACPI_TABLE 22u
#define ERWIRE_KIND_BUS_IO_REQUEST 23u
#define ERWIRE_KIND_BUS_IO_RESPONSE 24u
#define ERWIRE_KIND_WORK_REQUEST 32u
#define ERWIRE_KIND_WORK_ADMISSION 33u
#define ERWIRE_KIND_CHANNEL_ENVELOPE 34u
#define ERWIRE_KIND_CAPABILITY_ENVELOPE 35u
#define ERWIRE_KIND_RELAY_TRANSIT_HOP 36u
#define ERWIRE_KIND_APP_IDENTITY 40u
#define ERWIRE_KIND_APP_IPC_ROUTE 41u
#define ERWIRE_KIND_VFS_OBJECT_PACKET 48u
#define ERWIRE_KIND_VFS_OBJECT_LABEL_REF 49u
#define ERWIRE_KIND_VFS_OBJECT_TRANSFORM 50u
#define ERWIRE_FLAG_FIRST 0x0001u
#define ERWIRE_FLAG_LAST 0x0002u
#define ERWIRE_MAX_PAYLOAD 1024u

typedef struct {
  UINT32 Magic;
  UINT16 Version;
  UINT16 HeaderSize;
  UINT32 StreamId;
  UINT32 Seq;
  UINT16 Kind;
  UINT16 Flags;
  UINT32 PayloadLen;
  UINT32 PayloadCrc;
  UINT32 Reserved;
} ErwirePacketHeader;

void erwire_init(UINT32 stream_id);
UINT8 erwire_set_native_eth_sink(ErNativeEth* native_eth);
void erwire_clear_native_eth_sink(void);
void erwire_send(UINT16 kind, UINT16 flags, const UINT8* payload, UINT32 payload_len);
void erwire_send_text(const char* s);
void erwire_send_blob_chunk(const ErHash* object_id, UINT32 offset, UINT32 total_size, const UINT8* data,
                            UINT32 len, UINT8 is_last);
void erwire_send_pci_device(UINT32 bus, UINT32 dev, UINT32 func, UINT32 target_kind, UINT32 id,
                            UINT32 command_status, UINT32 class_revision, UINT32 header_cacheline,
                            const UINT32* bars);

#endif
