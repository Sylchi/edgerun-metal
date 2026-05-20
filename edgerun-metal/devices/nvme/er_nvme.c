#include "er_nvme.h"
#include "er_mem.h"

enum {
  ER_NVME_CAP_DSTRD_SHIFT = 32u,
  ER_NVME_CAP_DSTRD_MASK = 0x0fu,
  ER_NVME_CAP_MPSMIN_SHIFT = 48u,
  ER_NVME_CAP_MPSMIN_MASK = 0x0fu,
  ER_NVME_DOORBELL_BASE_BYTES = 4u,
  ER_NVME_PAGE_BASE_SHIFT = 12u,
  ER_NVME_MIN_MMIO_BYTES = 0x1000u,
  ER_NVME_ADMIN_COMMAND_BYTES = 64u,
  ER_NVME_COMPLETION_BYTES = 16u,
  ER_NVME_MAX_PAGE_SHIFT = 24u
};

UINT8 er_nvme_pci_snapshot_supported(const ErPciDeviceSnapshot* snapshot,
                                     ErPciBarSelection* out_bar) {
  ErPciBarSelection selected;

  if (out_bar != 0) {
    er_mem_zero((UINT8*)out_bar, (UINTN)sizeof(*out_bar));
  }
  if (snapshot == 0 ||
      snapshot->present == 0u ||
      er_pci_classify_target(snapshot->id, snapshot->class_revision) !=
          ER_PCI_TARGET_KIND_NVME) {
    return 0u;
  }
  selected = er_pci_select_first_mmio_bar(snapshot->bars);
  if (selected.found == 0u || er_pci_bar_is_mmio(&selected.info) == 0u) {
    return 0u;
  }
  if (out_bar != 0) {
    *out_bar = selected;
  }
  return 1u;
}

UINT32 er_nvme_doorbell_stride_from_cap(UINT64 cap) {
  UINT32 dstrd = (UINT32)((cap >> ER_NVME_CAP_DSTRD_SHIFT) &
                          ER_NVME_CAP_DSTRD_MASK);
  return ER_NVME_DOORBELL_BASE_BYTES << dstrd;
}

UINT32 er_nvme_page_bytes_from_cap(UINT64 cap) {
  UINT32 mpsmin = (UINT32)((cap >> ER_NVME_CAP_MPSMIN_SHIFT) &
                           ER_NVME_CAP_MPSMIN_MASK);
  UINT32 shift = ER_NVME_PAGE_BASE_SHIFT + mpsmin;

  if (shift > ER_NVME_MAX_PAGE_SHIFT) {
    return 0u;
  }
  return 1u << shift;
}

UINT8 er_nvme_queue_memory_valid(const ErNvmeQueueMemory* memory) {
  if (memory == 0 ||
      memory->admin_sq == 0 ||
      memory->admin_cq == 0 ||
      memory->io_sq == 0 ||
      memory->io_cq == 0 ||
      memory->admin_sq_bytes < ER_NVME_ADMIN_QUEUE_DEPTH * ER_NVME_ADMIN_COMMAND_BYTES ||
      memory->admin_cq_bytes < ER_NVME_ADMIN_QUEUE_DEPTH * ER_NVME_COMPLETION_BYTES ||
      memory->io_sq_bytes < ER_NVME_IO_QUEUE_DEPTH * ER_NVME_ADMIN_COMMAND_BYTES ||
      memory->io_cq_bytes < ER_NVME_IO_QUEUE_DEPTH * ER_NVME_COMPLETION_BYTES) {
    return 0u;
  }
  return 1u;
}

UINT8 er_nvme_prepare_controller(UINT64 mmio_base,
                                 UINT64 mmio_len,
                                 UINT64 cap,
                                 UINT32 version,
                                 const ErNvmeQueueMemory* memory,
                                 ErNvmeController* out_controller) {
  UINT32 page_bytes;
  UINT32 doorbell_stride;

  if (out_controller == 0) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_controller, (UINTN)sizeof(*out_controller));
  page_bytes = er_nvme_page_bytes_from_cap(cap);
  doorbell_stride = er_nvme_doorbell_stride_from_cap(cap);
  if (mmio_base == 0u ||
      mmio_len < ER_NVME_MIN_MMIO_BYTES ||
      page_bytes == 0u ||
      doorbell_stride == 0u ||
      er_nvme_queue_memory_valid(memory) == 0u) {
    return 0u;
  }
  out_controller->mmio_base = mmio_base;
  out_controller->mmio_len = mmio_len;
  out_controller->cap = cap;
  out_controller->version = version;
  out_controller->doorbell_stride_bytes = doorbell_stride;
  out_controller->page_bytes = page_bytes;
  out_controller->max_transfer_bytes = page_bytes;
  out_controller->initialized = 1u;
  return 1u;
}
