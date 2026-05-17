#ifndef ER_RELAY_DISPATCH_H
#define ER_RELAY_DISPATCH_H

/*
 * Purpose: consume relay intents and classify concrete endpoint dispatch.
 * Intention: keep route choice separate from endpoint movement or device adapters.
 */

#include "er_work.h"

typedef enum {
  ER_RELAY_DISPATCH_NONE = 0,
  ER_RELAY_DISPATCH_STORAGE_CAPTURE = 1,
  ER_RELAY_DISPATCH_RENDER_CAPTURE = 2,
  ER_RELAY_DISPATCH_UNSUPPORTED_ENDPOINT = 3,
  ER_RELAY_DISPATCH_MALFORMED_ENDPOINT = 4
} ErRelayDispatchStatus;

typedef struct {
  ErRelayDispatchStatus status;
  UINT32 virtio_device_type;
  UINT16 virtio_queue;
  UINT64 sequence;
  UINTN packet_len;
  ErHash packet_hash;
} ErRelayDispatchRecord;

UINT8 er_relay_dispatch_intent(const ErRelayForwardIntent* intent,
                               const UINT8* packet, UINTN packet_len,
                               ErRelayDispatchRecord* out_record);

#endif
