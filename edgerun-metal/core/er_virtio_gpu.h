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
#define ER_VIRTIO_GPU_CMD_GET_DISPLAY_INFO 0x0100u
#define ER_VIRTIO_GPU_CMD_RESOURCE_CREATE_2D 0x0101u
#define ER_VIRTIO_GPU_CMD_SET_SCANOUT 0x0103u
#define ER_VIRTIO_GPU_CMD_RESOURCE_FLUSH 0x0104u
#define ER_VIRTIO_GPU_CMD_TRANSFER_TO_HOST_2D 0x0105u
#define ER_VIRTIO_GPU_CMD_RESOURCE_ATTACH_BACKING 0x0106u
#define ER_VIRTIO_GPU_RESP_OK_NODATA 0x1100u
#define ER_VIRTIO_GPU_RESP_OK_DISPLAY_INFO 0x1101u
#define ER_VIRTIO_GPU_MAX_SCANOUTS 16u
#define ER_VIRTIO_GPU_FORMAT_B8G8R8X8_UNORM 2u
#define ER_VIRTIO_GPU_FRAMEBUFFER_BYTES_PER_PIXEL 4u

typedef struct {
  UINT32 events_read;
  UINT32 num_scanouts;
  UINT32 num_capsets;
} ErVirtioGpuConfig;

typedef struct {
  UINT32 type;
  UINT32 flags;
  UINT64 fence_id;
  UINT32 ctx_id;
  UINT8 ring_idx;
  UINT8 padding[3];
} ErVirtioGpuControlHeader;

typedef struct {
  UINT32 x;
  UINT32 y;
  UINT32 width;
  UINT32 height;
} ErVirtioGpuRect;

typedef struct {
  ErVirtioGpuRect rect;
  UINT32 enabled;
  UINT32 flags;
} ErVirtioGpuDisplayOne;

typedef struct {
  ErVirtioGpuControlHeader header;
  ErVirtioGpuDisplayOne scanouts[ER_VIRTIO_GPU_MAX_SCANOUTS];
} ErVirtioGpuDisplayInfo;

typedef struct {
  UINT32 control_submitted;
  UINT32 control_completed;
  UINT32 control_invalid;
  UINT32 control_busy;
} ErVirtioGpuStats;

typedef struct {
  ErVirtioMmioTransport transport;
  UINT64 features;
  UINT64 host_features;
  UINT16 control_queue_size;
  UINT16 cursor_queue_size;
  UINT16 control_last_used_idx;
  UINT8 control_pending;
  UINT8 initialized;
  ErVirtioGpuConfig config;
  ErVirtioGpuStats stats;
} ErVirtioGpu;

typedef struct {
  UINT32 resource_id;
  UINT32 scanout_id;
  UINT32 format;
  UINT32 width;
  UINT32 height;
  UINT32 stride_pixels;
  UINT32 byte_len;
  UINT32* pixels;
  UINT8 initialized;
} ErVirtioGpuFramebuffer;

UINT8 er_virtio_gpu_init_mmio(UINT64 base, UINT64 len, ErVirtioGpu* out_gpu);
UINT8 er_virtio_gpu_init_pci(UINT32 bus, UINT32 dev, UINT32 func, ErVirtioGpu* out_gpu);
UINT8 er_virtio_gpu_init_first_pci(ErVirtioGpu* out_gpu);
UINT8 er_virtio_gpu_submit_control(ErVirtioGpu* gpu, const UINT8* request, UINT32 request_len,
                                   UINT8* response, UINT32 response_len);
UINT8 er_virtio_gpu_poll_control(ErVirtioGpu* gpu, UINT32* out_response_len);
UINT8 er_virtio_gpu_poll_ok_nodata(ErVirtioGpu* gpu);
UINT8 er_virtio_gpu_submit_get_display_info(ErVirtioGpu* gpu);
UINT8 er_virtio_gpu_poll_display_info(ErVirtioGpu* gpu, ErVirtioGpuDisplayInfo* out_info);
UINT8 er_virtio_gpu_submit_resource_create_2d(ErVirtioGpu* gpu, UINT32 resource_id,
                                             UINT32 format, UINT32 width, UINT32 height);
UINT8 er_virtio_gpu_submit_resource_attach_backing(ErVirtioGpu* gpu, UINT32 resource_id,
                                                  UINT64 addr, UINT32 len);
UINT8 er_virtio_gpu_submit_set_scanout(ErVirtioGpu* gpu, UINT32 scanout_id, UINT32 resource_id,
                                       UINT32 width, UINT32 height);
UINT8 er_virtio_gpu_submit_transfer_to_host_2d(ErVirtioGpu* gpu, UINT32 resource_id,
                                              UINT32 width, UINT32 height);
UINT8 er_virtio_gpu_submit_transfer_to_host_2d_rect(ErVirtioGpu* gpu, UINT32 resource_id,
                                                    UINT32 x, UINT32 y,
                                                    UINT32 width, UINT32 height,
                                                    UINT64 offset);
UINT8 er_virtio_gpu_submit_resource_flush(ErVirtioGpu* gpu, UINT32 resource_id,
                                          UINT32 width, UINT32 height);
UINT8 er_virtio_gpu_submit_resource_flush_rect(ErVirtioGpu* gpu, UINT32 resource_id,
                                               UINT32 x, UINT32 y,
                                               UINT32 width, UINT32 height);
ErVirtioGpuStats er_virtio_gpu_stats(ErVirtioGpu* gpu);
UINT8 er_virtio_gpu_framebuffer_init(ErVirtioGpuFramebuffer* framebuffer, UINT32 resource_id,
                                     UINT32 scanout_id, UINT32 format, UINT32 width,
                                     UINT32 height, UINT32 stride_pixels, UINT32* pixels,
                                     UINT32 pixel_capacity);
void er_virtio_gpu_framebuffer_clear(ErVirtioGpuFramebuffer* framebuffer, UINT32 color);
void er_virtio_gpu_framebuffer_fill_halves(ErVirtioGpuFramebuffer* framebuffer,
                                           UINT32 top_color, UINT32 bottom_color);
UINT8 er_virtio_gpu_submit_framebuffer_create(ErVirtioGpu* gpu,
                                             const ErVirtioGpuFramebuffer* framebuffer);
UINT8 er_virtio_gpu_submit_framebuffer_attach(ErVirtioGpu* gpu,
                                             const ErVirtioGpuFramebuffer* framebuffer);
UINT8 er_virtio_gpu_submit_framebuffer_set_scanout(ErVirtioGpu* gpu,
                                                  const ErVirtioGpuFramebuffer* framebuffer);
UINT8 er_virtio_gpu_submit_framebuffer_transfer(ErVirtioGpu* gpu,
                                               const ErVirtioGpuFramebuffer* framebuffer);
UINT8 er_virtio_gpu_submit_framebuffer_flush(ErVirtioGpu* gpu,
                                            const ErVirtioGpuFramebuffer* framebuffer);
UINT8 er_virtio_gpu_submit_framebuffer_transfer_rect(ErVirtioGpu* gpu,
                                                     const ErVirtioGpuFramebuffer* framebuffer,
                                                     UINT32 x, UINT32 y,
                                                     UINT32 width, UINT32 height);
UINT8 er_virtio_gpu_submit_framebuffer_flush_rect(ErVirtioGpu* gpu,
                                                  const ErVirtioGpuFramebuffer* framebuffer,
                                                  UINT32 x, UINT32 y,
                                                  UINT32 width, UINT32 height);

#if defined(ER_ENABLE_TEST_HOOKS)
ErVirtioQueueDesc* er_virtio_gpu_test_control_desc(void);
ErVirtioQueueAvail* er_virtio_gpu_test_control_avail(void);
ErVirtioQueueUsed* er_virtio_gpu_test_control_used(void);
ErVirtioQueueDesc* er_virtio_gpu_test_cursor_desc(void);
ErVirtioQueueAvail* er_virtio_gpu_test_cursor_avail(void);
ErVirtioQueueUsed* er_virtio_gpu_test_cursor_used(void);
UINT8* er_virtio_gpu_test_control_request(void);
UINT8* er_virtio_gpu_test_control_response(void);
#endif

#endif
