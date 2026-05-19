#include "er_driver_event.h"

#include "er_mem.h"

UINT8 er_driver_event_kind_valid(UINT16 event_kind) {
  switch (event_kind) {
    case ER_DRIVER_EVENT_KIND_IRQ:
    case ER_DRIVER_EVENT_KIND_QUEUE_USED:
    case ER_DRIVER_EVENT_KIND_DEVICE:
      return 1u;
    case ER_DRIVER_EVENT_KIND_NONE:
    default:
      return 0u;
  }
}

UINT8 er_driver_event_queue_init(ErDriverEventQueue* queue, ErDriverEvent* events, UINT32 capacity) {
  if (queue == 0 || events == 0 || capacity == 0u) {
    return 0u;
  }

  er_mem_zero((UINT8*)queue, (UINTN)sizeof(*queue));
  er_mem_zero((UINT8*)events, (UINTN)sizeof(*events) * capacity);
  queue->events = events;
  queue->capacity = capacity;
  queue->next_sequence = ER_DRIVER_EVENT_FIRST_SEQUENCE;
  return 1u;
}

UINT8 er_driver_event_queue_empty(const ErDriverEventQueue* queue) {
  if (queue == 0 || queue->events == 0 || queue->capacity == 0u) {
    return 0u;
  }
  return queue->count == 0u;
}

UINT8 er_driver_event_queue_full(const ErDriverEventQueue* queue) {
  if (queue == 0 || queue->events == 0 || queue->capacity == 0u) {
    return 0u;
  }
  return queue->count == queue->capacity;
}

UINT8 er_driver_event_push(ErDriverEventQueue* queue, UINT16 event_kind, UINT32 source_id,
                           UINT64 arg0, UINT64 arg1, ErDriverEvent* out_event) {
  UINT32 tail;
  ErDriverEvent event;

  if (queue == 0 || queue->events == 0 || queue->capacity == 0u) {
    return 0u;
  }
  if (er_driver_event_kind_valid(event_kind) == 0u) {
    return 0u;
  }
  if (queue->count >= queue->capacity) {
    return 0u;
  }
  if (queue->next_sequence == ER_DRIVER_EVENT_SEQUENCE_MAX) {
    return 0u;
  }

  tail = queue->head + queue->count;
  if (tail >= queue->capacity) {
    tail -= queue->capacity;
  }

  event.abi_version = ER_DRIVER_EVENT_ABI_VERSION;
  event.event_kind = event_kind;
  event.source_id = source_id;
  event.sequence = queue->next_sequence;
  event.arg0 = arg0;
  event.arg1 = arg1;

  queue->events[tail] = event;
  queue->count += 1u;
  queue->next_sequence += 1u;

  if (out_event != 0) {
    *out_event = event;
  }
  return 1u;
}

UINT8 er_driver_event_pop(ErDriverEventQueue* queue, ErDriverEvent* out_event) {
  if (queue == 0 || queue->events == 0 || queue->capacity == 0u || out_event == 0) {
    return 0u;
  }
  if (queue->count == 0u) {
    return 0u;
  }

  *out_event = queue->events[queue->head];
  er_mem_zero((UINT8*)&queue->events[queue->head], (UINTN)sizeof(queue->events[queue->head]));
  queue->head += 1u;
  if (queue->head == queue->capacity) {
    queue->head = 0u;
  }
  queue->count -= 1u;
  return 1u;
}
