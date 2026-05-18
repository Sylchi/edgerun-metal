#include "er_virtio_gpu.h"
#include "er_mem.h"

/*
 * Purpose: initialize VirtIO GPU queues without using firmware graphics services.
 * Intention: give the device controller an explicit display relay endpoint before rendering policy exists.
 */

#define ER_VIRTIO_GPU_CONFIG_EVENTS_READ_OFFSET 0u
#define ER_VIRTIO_GPU_CONFIG_NUM_SCANOUTS_OFFSET 8u
#define ER_VIRTIO_GPU_CONFIG_NUM_CAPSETS_OFFSET 12u
#define ER_VIRTIO_GPU_CONTROL_REQUEST_DESC 0u
#define ER_VIRTIO_GPU_CONTROL_RESPONSE_DESC 1u
#define ER_VIRTIO_GPU_CONTROL_DESC_COUNT 2u
#define ER_VIRTIO_GPU_CONTROL_REQUEST_SIZE 256u
#define ER_VIRTIO_GPU_CONTROL_RESPONSE_SIZE 512u
#define ER_VIRTIO_GPU_U32_MAX 0xffffffffu

#if defined(_MSC_VER)
#define ER_VIRTIO_GPU_ALIGN16 __declspec(align(16))
#else
#define ER_VIRTIO_GPU_ALIGN16 __attribute__((aligned(16)))
#endif

typedef struct ER_VIRTIO_GPU_ALIGN16 {
  ErVirtioQueueDesc items[ER_VIRTIO_QUEUE_SIZE];
} ErVirtioGpuDescTable;

typedef struct {
  ErVirtioGpuControlHeader header;
  UINT32 resource_id;
  UINT32 format;
  UINT32 width;
  UINT32 height;
} ErVirtioGpuResourceCreate2d;

typedef struct {
  UINT64 addr;
  UINT32 length;
  UINT32 padding;
} ErVirtioGpuMemEntry;

typedef struct {
  ErVirtioGpuControlHeader header;
  UINT32 resource_id;
  UINT32 nr_entries;
  ErVirtioGpuMemEntry entry;
} ErVirtioGpuResourceAttachBackingOne;

typedef struct {
  ErVirtioGpuControlHeader header;
  ErVirtioGpuRect rect;
  UINT32 scanout_id;
  UINT32 resource_id;
} ErVirtioGpuSetScanout;

typedef struct {
  ErVirtioGpuControlHeader header;
  ErVirtioGpuRect rect;
  UINT64 offset;
  UINT32 resource_id;
  UINT32 padding;
} ErVirtioGpuTransferToHost2d;

typedef struct {
  ErVirtioGpuControlHeader header;
  ErVirtioGpuRect rect;
  UINT32 resource_id;
  UINT32 padding;
} ErVirtioGpuResourceFlush;

static ErVirtioGpuDescTable g_control_desc;
static ErVirtioQueueAvail g_control_avail;
static ErVirtioQueueUsed g_control_used;
static ErVirtioGpuDescTable g_cursor_desc;
static ErVirtioQueueAvail g_cursor_avail;
static ErVirtioQueueUsed g_cursor_used;
static UINT8 g_control_request[ER_VIRTIO_GPU_CONTROL_REQUEST_SIZE];
static UINT8 g_control_response[ER_VIRTIO_GPU_CONTROL_RESPONSE_SIZE];

static void er_virtio_gpu_reset_storage(void) {
  er_virtio_queue_clear(g_control_desc.items, &g_control_avail, &g_control_used);
  er_virtio_queue_clear(g_cursor_desc.items, &g_cursor_avail, &g_cursor_used);
  er_mem_zero(g_control_request, (UINTN)sizeof(g_control_request));
  er_mem_zero(g_control_response, (UINTN)sizeof(g_control_response));
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

static ErVirtioGpuControlHeader er_virtio_gpu_control_header(UINT32 type) {
  ErVirtioGpuControlHeader header;

  er_mem_zero((UINT8*)&header, (UINTN)sizeof(header));
  header.type = type;
  return header;
}

static ErVirtioGpuRect er_virtio_gpu_rect(UINT32 width, UINT32 height) {
  ErVirtioGpuRect rect;

  er_mem_zero((UINT8*)&rect, (UINTN)sizeof(rect));
  rect.width = width;
  rect.height = height;
  return rect;
}

static UINT8 er_virtio_gpu_submit_request(ErVirtioGpu* gpu, const UINT8* request, UINT32 request_len) {
  er_mem_zero(g_control_request, (UINTN)sizeof(g_control_request));
  er_mem_zero(g_control_response, (UINTN)sizeof(g_control_response));
  if (request == 0 || request_len == 0u || request_len > (UINT32)sizeof(g_control_request)) {
    return 0;
  }
  er_mem_copy(g_control_request, request, (UINTN)request_len);
  return er_virtio_gpu_submit_control(gpu, g_control_request, request_len,
                                      g_control_response, (UINT32)sizeof(g_control_response));
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
  out_gpu->control_last_used_idx = 0u;
  out_gpu->control_pending = 0u;
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

UINT8 er_virtio_gpu_submit_control(ErVirtioGpu* gpu, const UINT8* request, UINT32 request_len,
                                   UINT8* response, UINT32 response_len) {
  if (gpu == 0 || gpu->initialized == 0u || request == 0 || request_len == 0u ||
      response == 0 || response_len == 0u ||
      gpu->control_queue_size < ER_VIRTIO_GPU_CONTROL_DESC_COUNT) {
    return 0;
  }
  if (gpu->control_pending != 0u) {
    ++gpu->stats.control_busy;
    return 0;
  }
  g_control_desc.items[ER_VIRTIO_GPU_CONTROL_REQUEST_DESC].addr = (UINT64)(UINTN)request;
  g_control_desc.items[ER_VIRTIO_GPU_CONTROL_REQUEST_DESC].len = request_len;
  g_control_desc.items[ER_VIRTIO_GPU_CONTROL_REQUEST_DESC].flags = ER_VIRTIO_DESC_F_NEXT;
  g_control_desc.items[ER_VIRTIO_GPU_CONTROL_REQUEST_DESC].next = ER_VIRTIO_GPU_CONTROL_RESPONSE_DESC;
  g_control_desc.items[ER_VIRTIO_GPU_CONTROL_RESPONSE_DESC].addr = (UINT64)(UINTN)response;
  g_control_desc.items[ER_VIRTIO_GPU_CONTROL_RESPONSE_DESC].len = response_len;
  g_control_desc.items[ER_VIRTIO_GPU_CONTROL_RESPONSE_DESC].flags = ER_VIRTIO_DESC_F_WRITE;
  g_control_desc.items[ER_VIRTIO_GPU_CONTROL_RESPONSE_DESC].next = 0u;
  if (er_virtio_queue_post_descriptor(&g_control_avail, gpu->control_queue_size,
                                      ER_VIRTIO_GPU_CONTROL_REQUEST_DESC) == 0u ||
      er_virtio_mmio_notify_queue(&gpu->transport, ER_VIRTIO_GPU_CONTROL_QUEUE) == 0u) {
    er_virtio_queue_clear(g_control_desc.items, 0, 0);
    return 0;
  }
  gpu->control_pending = 1u;
  ++gpu->stats.control_submitted;
  return 1;
}

UINT8 er_virtio_gpu_poll_control(ErVirtioGpu* gpu, UINT32* out_response_len) {
  ErVirtioQueueUsedElem elem;

  if (gpu == 0 || gpu->initialized == 0u || out_response_len == 0) {
    return 0;
  }
  *out_response_len = 0u;
  if (er_virtio_queue_take_next_used(&g_control_used, gpu->control_queue_size,
                                     &gpu->control_last_used_idx, &elem) == 0u) {
    return 0;
  }
  gpu->control_pending = 0u;
  if (elem.id != ER_VIRTIO_GPU_CONTROL_REQUEST_DESC) {
    ++gpu->stats.control_invalid;
    return 0;
  }
  *out_response_len = elem.len;
  ++gpu->stats.control_completed;
  return 1;
}

UINT8 er_virtio_gpu_submit_get_display_info(ErVirtioGpu* gpu) {
  ErVirtioGpuControlHeader header;

  header = er_virtio_gpu_control_header(ER_VIRTIO_GPU_CMD_GET_DISPLAY_INFO);
  return er_virtio_gpu_submit_request(gpu, (const UINT8*)&header, (UINT32)sizeof(header));
}

UINT8 er_virtio_gpu_poll_ok_nodata(ErVirtioGpu* gpu) {
  UINT32 response_len = 0;
  ErVirtioGpuControlHeader header;

  er_mem_zero((UINT8*)&header, (UINTN)sizeof(header));
  if (er_virtio_gpu_poll_control(gpu, &response_len) == 0u ||
      response_len < (UINT32)sizeof(header)) {
    return 0;
  }
  er_mem_copy((UINT8*)&header, g_control_response, (UINTN)sizeof(header));
  return (UINT8)(header.type == ER_VIRTIO_GPU_RESP_OK_NODATA);
}

UINT8 er_virtio_gpu_poll_display_info(ErVirtioGpu* gpu, ErVirtioGpuDisplayInfo* out_info) {
  UINT32 response_len = 0;
  ErVirtioGpuControlHeader header;

  er_mem_zero((UINT8*)&header, (UINTN)sizeof(header));
  if (out_info == 0 ||
      er_virtio_gpu_poll_control(gpu, &response_len) == 0u ||
      response_len < (UINT32)sizeof(ErVirtioGpuControlHeader)) {
    return 0;
  }
  er_mem_copy((UINT8*)&header, g_control_response, (UINTN)sizeof(header));
  if (header.type != ER_VIRTIO_GPU_RESP_OK_DISPLAY_INFO) {
    return 0;
  }
  er_mem_copy((UINT8*)out_info, g_control_response, (UINTN)sizeof(*out_info));
  return 1;
}

UINT8 er_virtio_gpu_submit_resource_create_2d(ErVirtioGpu* gpu, UINT32 resource_id,
                                             UINT32 format, UINT32 width, UINT32 height) {
  ErVirtioGpuResourceCreate2d request;

  if (resource_id == 0u || width == 0u || height == 0u) {
    return 0;
  }
  er_mem_zero((UINT8*)&request, (UINTN)sizeof(request));
  request.header = er_virtio_gpu_control_header(ER_VIRTIO_GPU_CMD_RESOURCE_CREATE_2D);
  request.resource_id = resource_id;
  request.format = format;
  request.width = width;
  request.height = height;
  return er_virtio_gpu_submit_request(gpu, (const UINT8*)&request, (UINT32)sizeof(request));
}

UINT8 er_virtio_gpu_submit_resource_attach_backing(ErVirtioGpu* gpu, UINT32 resource_id,
                                                  UINT64 addr, UINT32 len) {
  ErVirtioGpuResourceAttachBackingOne request;

  if (resource_id == 0u || addr == 0u || len == 0u) {
    return 0;
  }
  er_mem_zero((UINT8*)&request, (UINTN)sizeof(request));
  request.header = er_virtio_gpu_control_header(ER_VIRTIO_GPU_CMD_RESOURCE_ATTACH_BACKING);
  request.resource_id = resource_id;
  request.nr_entries = 1u;
  request.entry.addr = addr;
  request.entry.length = len;
  return er_virtio_gpu_submit_request(gpu, (const UINT8*)&request, (UINT32)sizeof(request));
}

UINT8 er_virtio_gpu_submit_set_scanout(ErVirtioGpu* gpu, UINT32 scanout_id, UINT32 resource_id,
                                       UINT32 width, UINT32 height) {
  ErVirtioGpuSetScanout request;

  if (resource_id == 0u || width == 0u || height == 0u) {
    return 0;
  }
  er_mem_zero((UINT8*)&request, (UINTN)sizeof(request));
  request.header = er_virtio_gpu_control_header(ER_VIRTIO_GPU_CMD_SET_SCANOUT);
  request.rect = er_virtio_gpu_rect(width, height);
  request.scanout_id = scanout_id;
  request.resource_id = resource_id;
  return er_virtio_gpu_submit_request(gpu, (const UINT8*)&request, (UINT32)sizeof(request));
}

UINT8 er_virtio_gpu_submit_transfer_to_host_2d(ErVirtioGpu* gpu, UINT32 resource_id,
                                              UINT32 width, UINT32 height) {
  ErVirtioGpuTransferToHost2d request;

  if (resource_id == 0u || width == 0u || height == 0u) {
    return 0;
  }
  er_mem_zero((UINT8*)&request, (UINTN)sizeof(request));
  request.header = er_virtio_gpu_control_header(ER_VIRTIO_GPU_CMD_TRANSFER_TO_HOST_2D);
  request.rect = er_virtio_gpu_rect(width, height);
  request.offset = 0u;
  request.resource_id = resource_id;
  return er_virtio_gpu_submit_request(gpu, (const UINT8*)&request, (UINT32)sizeof(request));
}

UINT8 er_virtio_gpu_submit_resource_flush(ErVirtioGpu* gpu, UINT32 resource_id,
                                          UINT32 width, UINT32 height) {
  ErVirtioGpuResourceFlush request;

  if (resource_id == 0u || width == 0u || height == 0u) {
    return 0;
  }
  er_mem_zero((UINT8*)&request, (UINTN)sizeof(request));
  request.header = er_virtio_gpu_control_header(ER_VIRTIO_GPU_CMD_RESOURCE_FLUSH);
  request.rect = er_virtio_gpu_rect(width, height);
  request.resource_id = resource_id;
  return er_virtio_gpu_submit_request(gpu, (const UINT8*)&request, (UINT32)sizeof(request));
}

ErVirtioGpuStats er_virtio_gpu_stats(ErVirtioGpu* gpu) {
  ErVirtioGpuStats stats;

  er_mem_zero((UINT8*)&stats, (UINTN)sizeof(stats));
  if (gpu != 0) {
    stats = gpu->stats;
  }
  return stats;
}

static UINT8 er_virtio_gpu_framebuffer_ready(const ErVirtioGpuFramebuffer* framebuffer) {
  return (UINT8)(framebuffer != 0 && framebuffer->initialized != 0u &&
                 framebuffer->resource_id != 0u && framebuffer->width != 0u &&
                 framebuffer->height != 0u && framebuffer->stride_pixels >= framebuffer->width &&
                 framebuffer->pixels != 0 && framebuffer->byte_len != 0u);
}

UINT8 er_virtio_gpu_framebuffer_init(ErVirtioGpuFramebuffer* framebuffer, UINT32 resource_id,
                                     UINT32 scanout_id, UINT32 format, UINT32 width,
                                     UINT32 height, UINT32 stride_pixels, UINT32* pixels,
                                     UINT32 pixel_capacity) {
  UINT32 required_pixels;
  UINT32 byte_len;

  if (framebuffer == 0) {
    return 0;
  }
  er_mem_zero((UINT8*)framebuffer, (UINTN)sizeof(*framebuffer));
  if (resource_id == 0u || width == 0u || height == 0u ||
      stride_pixels < width || pixels == 0 ||
      height > ER_VIRTIO_GPU_U32_MAX / stride_pixels) {
    return 0;
  }
  required_pixels = stride_pixels * height;
  if (required_pixels == 0u || pixel_capacity < required_pixels ||
      required_pixels > ER_VIRTIO_GPU_U32_MAX / ER_VIRTIO_GPU_FRAMEBUFFER_BYTES_PER_PIXEL) {
    return 0;
  }
  byte_len = required_pixels * ER_VIRTIO_GPU_FRAMEBUFFER_BYTES_PER_PIXEL;
  framebuffer->resource_id = resource_id;
  framebuffer->scanout_id = scanout_id;
  framebuffer->format = format;
  framebuffer->width = width;
  framebuffer->height = height;
  framebuffer->stride_pixels = stride_pixels;
  framebuffer->byte_len = byte_len;
  framebuffer->pixels = pixels;
  framebuffer->initialized = 1u;
  return 1;
}

void er_virtio_gpu_framebuffer_clear(ErVirtioGpuFramebuffer* framebuffer, UINT32 color) {
  UINT32 x;
  UINT32 y;

  if (er_virtio_gpu_framebuffer_ready(framebuffer) == 0u) {
    return;
  }
  for (y = 0u; y < framebuffer->height; ++y) {
    for (x = 0u; x < framebuffer->width; ++x) {
      framebuffer->pixels[(UINTN)y * framebuffer->stride_pixels + x] = color;
    }
  }
}

void er_virtio_gpu_framebuffer_fill_halves(ErVirtioGpuFramebuffer* framebuffer,
                                           UINT32 top_color, UINT32 bottom_color) {
  UINT32 x;
  UINT32 y;
  UINT32 half_height;

  if (er_virtio_gpu_framebuffer_ready(framebuffer) == 0u) {
    return;
  }
  half_height = framebuffer->height / 2u;
  for (y = 0u; y < framebuffer->height; ++y) {
    for (x = 0u; x < framebuffer->width; ++x) {
      framebuffer->pixels[(UINTN)y * framebuffer->stride_pixels + x] =
          (y < half_height) ? top_color : bottom_color;
    }
  }
}

UINT8 er_virtio_gpu_submit_framebuffer_create(ErVirtioGpu* gpu,
                                             const ErVirtioGpuFramebuffer* framebuffer) {
  if (er_virtio_gpu_framebuffer_ready(framebuffer) == 0u) {
    return 0;
  }
  return er_virtio_gpu_submit_resource_create_2d(gpu, framebuffer->resource_id,
                                                framebuffer->format,
                                                framebuffer->width, framebuffer->height);
}

UINT8 er_virtio_gpu_submit_framebuffer_attach(ErVirtioGpu* gpu,
                                             const ErVirtioGpuFramebuffer* framebuffer) {
  if (er_virtio_gpu_framebuffer_ready(framebuffer) == 0u) {
    return 0;
  }
  return er_virtio_gpu_submit_resource_attach_backing(
      gpu, framebuffer->resource_id, (UINT64)(UINTN)framebuffer->pixels, framebuffer->byte_len);
}

UINT8 er_virtio_gpu_submit_framebuffer_set_scanout(ErVirtioGpu* gpu,
                                                  const ErVirtioGpuFramebuffer* framebuffer) {
  if (er_virtio_gpu_framebuffer_ready(framebuffer) == 0u) {
    return 0;
  }
  return er_virtio_gpu_submit_set_scanout(gpu, framebuffer->scanout_id,
                                         framebuffer->resource_id,
                                         framebuffer->width, framebuffer->height);
}

UINT8 er_virtio_gpu_submit_framebuffer_transfer(ErVirtioGpu* gpu,
                                               const ErVirtioGpuFramebuffer* framebuffer) {
  if (er_virtio_gpu_framebuffer_ready(framebuffer) == 0u) {
    return 0;
  }
  return er_virtio_gpu_submit_transfer_to_host_2d(gpu, framebuffer->resource_id,
                                                 framebuffer->width, framebuffer->height);
}

UINT8 er_virtio_gpu_submit_framebuffer_flush(ErVirtioGpu* gpu,
                                            const ErVirtioGpuFramebuffer* framebuffer) {
  if (er_virtio_gpu_framebuffer_ready(framebuffer) == 0u) {
    return 0;
  }
  return er_virtio_gpu_submit_resource_flush(gpu, framebuffer->resource_id,
                                            framebuffer->width, framebuffer->height);
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

UINT8* er_virtio_gpu_test_control_request(void) {
  return g_control_request;
}

UINT8* er_virtio_gpu_test_control_response(void) {
  return g_control_response;
}
#endif
