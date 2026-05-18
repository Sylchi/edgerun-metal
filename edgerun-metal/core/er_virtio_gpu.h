#ifndef ER_VIRTIO_GPU_H
#define ER_VIRTIO_GPU_H

/*
 * Purpose: expose the native VirtIO GPU queue owner for post-boot display control.
 * Intention: make the framebuffer path a device jurisdiction instead of a firmware service.
 */

#include "er_types.h"
#include "er_virtio.h"

#define ER_VIRTIO_GPU_CONTROL_QUEUE 0u
#define ER_VIRTIO_GPU_CURSOR_QUEUE 1u

typedef struct {
  UINT32 events_read;
  UINT32 num_scanouts;
  UINT32 num_capsets;
} ErVirtioGpuConfig;

typedef struct {
  ErVirtioMmioTransport transport;
  UINT64 features;
  UINT64 host_features;
  UINT16 control_queue_size;
  UINT16 cursor_queue_size;
  UINT8 initialized;
  ErVirtioGpuConfig config;
} ErVirtioGpu;

UINT8 er_virtio_gpu_init_mmio(UINT64 base, UINT64 len, ErVirtioGpu* out_gpu);
UINT8 er_virtio_gpu_init_pci(UINT32 bus, UINT32 dev, UINT32 func, ErVirtioGpu* out_gpu);
UINT8 er_virtio_gpu_init_first_pci(ErVirtioGpu* out_gpu);

#if defined(ER_ENABLE_TEST_HOOKS)
ErVirtioQueueDesc* er_virtio_gpu_test_control_desc(void);
ErVirtioQueueAvail* er_virtio_gpu_test_control_avail(void);
ErVirtioQueueUsed* er_virtio_gpu_test_control_used(void);
ErVirtioQueueDesc* er_virtio_gpu_test_cursor_desc(void);
ErVirtioQueueAvail* er_virtio_gpu_test_cursor_avail(void);
ErVirtioQueueUsed* er_virtio_gpu_test_cursor_used(void);
#endif

#endif
