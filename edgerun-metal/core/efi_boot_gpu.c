#include "efi_boot_internal.h"

static UINT32 g_virtio_gpu_framebuffer[ER_GPU_PROFILE_FRAMEBUFFER_WIDTH_MAX *
                                       ER_GPU_PROFILE_FRAMEBUFFER_HEIGHT_MAX];

UINT8 er_virtio_gpu_wait_ok(ErVirtioGpu* gpu) {
  UINT32 poll_count;

  for (poll_count = 0u; poll_count < ER_GPU_PROFILE_POLL_LIMIT; ++poll_count) {
    if (er_virtio_gpu_poll_ok_nodata(gpu) != 0u) {
      return 1u;
    }
  }
  return 0u;
}

UINT8 er_virtio_gpu_wait_display_info(ErVirtioGpu* gpu,
                                             ErVirtioGpuDisplayInfo* out_info) {
  UINT32 poll_count;

  if (out_info == 0) {
    return 0u;
  }
  for (poll_count = 0u; poll_count < ER_GPU_PROFILE_POLL_LIMIT; ++poll_count) {
    if (er_virtio_gpu_poll_display_info(gpu, out_info) != 0u) {
      return 1u;
    }
  }
  return 0u;
}

UINT8 er_ui_boot_gpu_present(ErUiBootRenderContext* render) {
  const ErUiSurfacePixelRect* rect;
  UINT32 i;
  UINT32 width;
  UINT32 height;

  if (render == 0 || render->gpu == 0 || render->framebuffer == 0) {
    return 0u;
  }
  if (render->last_dirty_tiles.count == 0u) {
    return 1u;
  }
  if (er_ui_boot_dirty_present_rects(render) == 0u) {
    return 0u;
  }
  if (render->last_present_rect_count == 1u &&
      render->present_rects[0].x0 == 0u &&
      render->present_rects[0].y0 == 0u &&
      render->present_rects[0].x1 == render->framebuffer->width &&
      render->present_rects[0].y1 == render->framebuffer->height) {
    if (er_virtio_gpu_submit_framebuffer_transfer(render->gpu, render->framebuffer) == 0u ||
        er_virtio_gpu_wait_ok(render->gpu) == 0u ||
        er_virtio_gpu_submit_framebuffer_flush(render->gpu, render->framebuffer) == 0u ||
        er_virtio_gpu_wait_ok(render->gpu) == 0u) {
      return 0u;
    }
    return 1u;
  }
  for (i = 0u; i < render->last_present_rect_count; ++i) {
    rect = &render->present_rects[i];
    width = rect->x1 - rect->x0;
    height = rect->y1 - rect->y0;
    if (er_virtio_gpu_submit_framebuffer_transfer_rect(render->gpu,
                                                       render->framebuffer,
                                                       rect->x0,
                                                       rect->y0,
                                                       width,
                                                       height) == 0u ||
        er_virtio_gpu_wait_ok(render->gpu) == 0u ||
        er_virtio_gpu_submit_framebuffer_flush_rect(render->gpu,
                                                   render->framebuffer,
                                                   rect->x0,
                                                   rect->y0,
                                                   width,
                                                   height) == 0u ||
        er_virtio_gpu_wait_ok(render->gpu) == 0u) {
      return 0u;
    }
  }
  return 1u;
}

UINT8 er_ui_boot_gpu_prepare_scanout(ErVirtioGpu* gpu,
                                            ErVirtioGpuFramebuffer* framebuffer,
                                            ErUiSurface* surface,
                                            ErUiSurfaceMode* out_mode) {
  if (gpu == 0 || framebuffer == 0 || surface == 0 || out_mode == 0) {
    return 0u;
  }
  if (er_virtio_gpu_framebuffer_init(framebuffer, ER_UI_BOOT_GPU_RESOURCE_ID,
                                     ER_UI_BOOT_GPU_SCANOUT_ID,
                                     ER_VIRTIO_GPU_FORMAT_B8G8R8X8_UNORM,
                                     ER_GPU_PROFILE_FRAMEBUFFER_WIDTH,
                                     ER_GPU_PROFILE_FRAMEBUFFER_HEIGHT,
                                     ER_GPU_PROFILE_FRAMEBUFFER_WIDTH,
                                     g_virtio_gpu_framebuffer,
                                     ER_GPU_PROFILE_FRAMEBUFFER_WIDTH_MAX *
                                         ER_GPU_PROFILE_FRAMEBUFFER_HEIGHT_MAX) == 0u) {
    return 0u;
  }
  if (er_virtio_gpu_submit_framebuffer_create(gpu, framebuffer) == 0u ||
      er_virtio_gpu_wait_ok(gpu) == 0u ||
      er_virtio_gpu_submit_framebuffer_attach(gpu, framebuffer) == 0u ||
      er_virtio_gpu_wait_ok(gpu) == 0u ||
      er_virtio_gpu_submit_framebuffer_set_scanout(gpu, framebuffer) == 0u ||
      er_virtio_gpu_wait_ok(gpu) == 0u) {
    return 0u;
  }
  surface->pixels = framebuffer->pixels;
  surface->width = framebuffer->width;
  surface->height = framebuffer->height;
  surface->stride = framebuffer->stride_pixels;
  surface->pixel_format = ER_UI_SURFACE_PIXEL_BGRX;
  out_mode->width = framebuffer->width;
  out_mode->height = framebuffer->height;
  out_mode->stride = framebuffer->stride_pixels;
  out_mode->refresh_hz = 1u;
  out_mode->pixel_format = ER_UI_SURFACE_PIXEL_BGRX;
  return (UINT8)(er_ui_surface_valid(surface) != 0u &&
                 er_ui_surface_mode_valid(out_mode) != 0u);
}
