#ifndef ER_DRIVER_EVENT_H
#define ER_DRIVER_EVENT_H

/*
 * Purpose: define the bounded event records delivered to Wasm drivers.
 * Intention: make interrupt and device wakeup delivery deterministic before a
 * driver receives access to hardware state.
 */

#include "er_driver_abi.h"
#include "er_types.h"

#define ER_DRIVER_EVENT_ABI_VERSION ER_DRIVER_ABI_VERSION

#define ER_DRIVER_EVENT_KIND_NONE ER_DRIVER_ABI_EVENT_KIND_NONE
#define ER_DRIVER_EVENT_KIND_IRQ ER_DRIVER_ABI_EVENT_KIND_IRQ
#define ER_DRIVER_EVENT_KIND_QUEUE_USED ER_DRIVER_ABI_EVENT_KIND_QUEUE_USED
#define ER_DRIVER_EVENT_KIND_DEVICE ER_DRIVER_ABI_EVENT_KIND_DEVICE

#define ER_DRIVER_EVENT_FIRST_SEQUENCE 1ull
#define ER_DRIVER_EVENT_SEQUENCE_MAX (~(UINT64)0u)

typedef struct {
  UINT16 abi_version;
  UINT16 event_kind;
  UINT32 source_id;
  UINT64 sequence;
  UINT64 arg0;
  UINT64 arg1;
} ErDriverEvent;

typedef struct {
  ErDriverEvent* events;
  UINT32 capacity;
  UINT32 head;
  UINT32 count;
  UINT64 next_sequence;
} ErDriverEventQueue;

UINT8 er_driver_event_kind_valid(UINT16 event_kind);
UINT8 er_driver_event_queue_init(ErDriverEventQueue* queue, ErDriverEvent* events, UINT32 capacity);
UINT8 er_driver_event_queue_empty(const ErDriverEventQueue* queue);
UINT8 er_driver_event_queue_full(const ErDriverEventQueue* queue);
UINT8 er_driver_event_push(ErDriverEventQueue* queue, UINT16 event_kind, UINT32 source_id,
                           UINT64 arg0, UINT64 arg1, ErDriverEvent* out_event);
UINT8 er_driver_event_pop(ErDriverEventQueue* queue, ErDriverEvent* out_event);

#endif
