#include "er_virtio_gpu.h"
#include "er_mem.h"

/*
 * Purpose: initialize VirtIO GPU queues without using firmware graphics services.
 * Intention: give the device controller an explicit display relay endpoint before rendering policy exists.
 */

#define ER_VIRTIO_GPU_CONFIG_EVENTS_READ_OFFSET 0u
#define ER_VIRTIO_GPU_CONFIG_NUM_SCANOUTS_OFFSET 8u
#define ER_VIRTIO_GPU_CONFIG_NUM_CAPSETS_OFFSET 12u

#if defined(_MSC_VER)
#define ER_VIRTIO_GPU_ALIGN16 __declspec(align(16))
#else
#define ER_VIRTIO_GPU_ALIGN16 __attribute__((aligned(16)))
#endif

typedef struct ER_VIRTIO_GPU_ALIGN16 {
  ErVirtioQueueDesc items[ER_VIRTIO_QUEUE_SIZE];
} ErVirtioGpuDescTable;

static ErVirtioGpuDescTable g_control_desc;
static ErVirtioQueueAvail g_control_avail;
static ErVirtioQueueUsed g_control_used;
static ErVirtioGpuDescTable g_cursor_desc;
static ErVirtioQueueAvail g_cursor_avail;
static ErVirtioQueueUsed g_cursor_used;

static void er_virtio_gpu_reset_storage(void) {
  er_virtio_queue_clear(g_control_desc.items, &g_control_avail, &g_control_used);
  er_virtio_queue_clear(g_cursor_desc.items, &g_cursor_avail, &g_cursor_used);
}

static UINT8 er_virtio_gpu_configure_queue(const ErVirtioMmioTransport* transport, UINT16 queue,
                                           ErVirtioQueueDesc* desc, ErVirtioQueueAvail* avail,
                                           ErVirtioQueueUsed* used, UINT16* out_queue_size) {
  return er_virtio_mmio_configure_split_queue(transport, queue, ER_VIRTIO_QUEUE_SIZE,
                                             ER_VIRTIO_QUEUE_SIZE, (UINT64)(UINTN)desc,
                                             (UINT64)(UINTN)avail, (UINT64)(UINTN)used,
                                             out_queue_size);
}

static UINT8 er_virtio_gpu_read_config(ErVirtioGpu* gpu) {
  if (gpu == 0) {
    return 0;
  }
  return (UINT8)(er_virtio_config_read32(&gpu->transport,
                                         ER_VIRTIO_GPU_CONFIG_EVENTS_READ_OFFSET,
                                         &gpu->config.events_read) != 0u &&
                 er_virtio_config_read32(&gpu->transport,
                                         ER_VIRTIO_GPU_CONFIG_NUM_SCANOUTS_OFFSET,
                                         &gpu->config.num_scanouts) != 0u &&
                 er_virtio_config_read32(&gpu->transport,
                                         ER_VIRTIO_GPU_CONFIG_NUM_CAPSETS_OFFSET,
                                         &gpu->config.num_capsets) != 0u);
}

static UINT8 er_virtio_gpu_init_transport(const ErVirtioMmioTransport* transport, ErVirtioGpu* out_gpu) {
  ErVirtioFeatureSet features;
  UINT16 control_queue_size = 0;
  UINT16 cursor_queue_size = 0;
  UINT8 status = 0;

  if (out_gpu == 0) {
    return 0;
  }
  er_mem_zero((UINT8*)out_gpu, (UINTN)sizeof(*out_gpu));
  er_virtio_gpu_reset_storage();
  if (transport == 0 || transport->device_type != ER_VIRTIO_DEVICE_TYPE_GPU) {
    return 0;
  }
  out_gpu->transport = *transport;
  if (er_virtio_mmio_negotiate_features(&out_gpu->transport, ER_VIRTIO_F_VERSION_1,
                                        &features) == 0u) {
    er_mem_zero((UINT8*)out_gpu, (UINTN)sizeof(*out_gpu));
    return 0;
  }
  out_gpu->host_features = features.host;
  out_gpu->features = features.driver;
  if (er_virtio_gpu_read_config(out_gpu) == 0u ||
      er_virtio_gpu_configure_queue(&out_gpu->transport, ER_VIRTIO_GPU_CONTROL_QUEUE,
                                    g_control_desc.items, &g_control_avail, &g_control_used,
                                    &control_queue_size) == 0u ||
      er_virtio_gpu_configure_queue(&out_gpu->transport, ER_VIRTIO_GPU_CURSOR_QUEUE,
                                    g_cursor_desc.items, &g_cursor_avail, &g_cursor_used,
                                    &cursor_queue_size) == 0u) {
    (void)er_virtio_mmio_write_status(&out_gpu->transport, ER_VIRTIO_STATUS_FAILED);
    return 0;
  }
  out_gpu->control_queue_size = control_queue_size;
  out_gpu->cursor_queue_size = cursor_queue_size;
  if (er_virtio_mmio_read_status(&out_gpu->transport, &status) == 0u ||
      er_virtio_mmio_write_status(&out_gpu->transport,
                                  (UINT8)(status | ER_VIRTIO_STATUS_DRIVER_OK)) == 0u) {
    return 0;
  }
  out_gpu->initialized = 1u;
  return 1;
}

UINT8 er_virtio_gpu_init_mmio(UINT64 base, UINT64 len, ErVirtioGpu* out_gpu) {
  ErVirtioMmioTransport transport;

  if (er_virtio_mmio_transport_init(base, len, ER_VIRTIO_DEVICE_TYPE_GPU, &transport) == 0u) {
    if (out_gpu != 0) {
      er_mem_zero((UINT8*)out_gpu, (UINTN)sizeof(*out_gpu));
    }
    return 0;
  }
  return er_virtio_gpu_init_transport(&transport, out_gpu);
}

UINT8 er_virtio_gpu_init_pci(UINT32 bus, UINT32 dev, UINT32 func, ErVirtioGpu* out_gpu) {
  ErVirtioMmioTransport transport;

  if (er_virtio_pci_transport_init(bus, dev, func, ER_VIRTIO_DEVICE_TYPE_GPU, &transport) == 0u) {
    if (out_gpu != 0) {
      er_mem_zero((UINT8*)out_gpu, (UINTN)sizeof(*out_gpu));
    }
    return 0;
  }
  return er_virtio_gpu_init_transport(&transport, out_gpu);
}

UINT8 er_virtio_gpu_init_first_pci(ErVirtioGpu* out_gpu) {
  ErVirtioMmioTransport transport;

  if (er_virtio_pci_find_transport(ER_VIRTIO_DEVICE_TYPE_GPU, &transport) == 0u) {
    if (out_gpu != 0) {
      er_mem_zero((UINT8*)out_gpu, (UINTN)sizeof(*out_gpu));
    }
    return 0;
  }
  return er_virtio_gpu_init_transport(&transport, out_gpu);
}

#if defined(ER_ENABLE_TEST_HOOKS)
ErVirtioQueueDesc* er_virtio_gpu_test_control_desc(void) {
  return g_control_desc.items;
}

ErVirtioQueueAvail* er_virtio_gpu_test_control_avail(void) {
  return &g_control_avail;
}

ErVirtioQueueUsed* er_virtio_gpu_test_control_used(void) {
  return &g_control_used;
}

ErVirtioQueueDesc* er_virtio_gpu_test_cursor_desc(void) {
  return g_cursor_desc.items;
}

ErVirtioQueueAvail* er_virtio_gpu_test_cursor_avail(void) {
  return &g_cursor_avail;
}

ErVirtioQueueUsed* er_virtio_gpu_test_cursor_used(void) {
  return &g_cursor_used;
}
#endif
