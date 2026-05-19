#include "er_pi_zero2w.h"

/*
 * Purpose: build the first executable Pi Zero 2 W board bring-up boundary.
 * Intention: no guessed packet path; expose the exact MMIO/radio/storage state
 * that must become ready before remote update traffic is admitted.
 */

enum {
  ER_PI_MAILBOX_TWO_VALUE_BUFFER_BYTES = 8u,
  ER_PI_MAILBOX_MESSAGE_WORDS = 8u,
  ER_PI_ZERO2W_STORAGE_BLOCK_BYTES = 512u
};

UINT64 er_pi_zero2w_peripheral_phys(UINT64 offset) {
  return ER_PI_ZERO2W_PERIPHERAL_BASE + offset;
}

static INT64 er_pi_zero2w_map_child(UINT64 offset, UINT64 len) {
  return er_mmio_map((INT64)er_pi_zero2w_peripheral_phys(offset), (INT64)len);
}

UINT8 er_pi_zero2w_mmio_map(ErPiZero2wMmio* out_mmio) {
  if (out_mmio == 0) {
    return 0u;
  }

  out_mmio->mapped = 0u;
  out_mmio->peripheral_handle =
      er_mmio_map((INT64)ER_PI_ZERO2W_PERIPHERAL_BASE,
                  (INT64)ER_PI_ZERO2W_PERIPHERAL_BYTES);
  out_mmio->mailbox_handle =
      er_pi_zero2w_map_child(ER_PI_ZERO2W_MAILBOX_OFFSET,
                             ER_PI_ZERO2W_MAILBOX_BYTES);
  out_mmio->gpio_handle =
      er_pi_zero2w_map_child(ER_PI_ZERO2W_GPIO_OFFSET,
                             ER_PI_ZERO2W_GPIO_BYTES);
  out_mmio->sdhost_handle =
      er_pi_zero2w_map_child(ER_PI_ZERO2W_SDHOST_OFFSET,
                             ER_PI_ZERO2W_SDHOST_BYTES);
  out_mmio->emmc_handle =
      er_pi_zero2w_map_child(ER_PI_ZERO2W_EMMC_OFFSET,
                             ER_PI_ZERO2W_EMMC_BYTES);
  out_mmio->aux_handle =
      er_pi_zero2w_map_child(ER_PI_ZERO2W_AUX_OFFSET,
                             ER_PI_ZERO2W_AUX_BYTES);

  if (out_mmio->peripheral_handle <= 0 ||
      out_mmio->mailbox_handle <= 0 ||
      out_mmio->gpio_handle <= 0 ||
      out_mmio->sdhost_handle <= 0 ||
      out_mmio->emmc_handle <= 0 ||
      out_mmio->aux_handle <= 0) {
    return 0u;
  }

  out_mmio->mapped = 1u;
  return 1u;
}

UINT8 er_pi_mailbox_two_value_request(UINT32 tag_id,
                                      UINT32 value0,
                                      UINT32 value1,
                                      ErPiMailboxTwoValueMessage* out_message) {
  if (out_message == 0 ||
      tag_id == ER_PI_MAILBOX_TAG_LAST) {
    return 0u;
  }

  out_message->size_bytes =
      (UINT32)(ER_PI_MAILBOX_MESSAGE_WORDS * sizeof(UINT32));
  out_message->request_code = ER_PI_MAILBOX_REQUEST_CODE;
  out_message->tag_id = tag_id;
  out_message->value_buffer_bytes = ER_PI_MAILBOX_TWO_VALUE_BUFFER_BYTES;
  out_message->request_value_bytes = 0u;
  out_message->value0 = value0;
  out_message->value1 = value1;
  out_message->end_tag = ER_PI_MAILBOX_TAG_LAST;
  return 1u;
}

UINT8 er_pi_zero2w_apply_boot_report(ErBootServicesReport* report) {
  ErPiZero2wMmio mmio;

  if (report == 0) {
    return 0u;
  }

  if (er_pi_zero2w_mmio_map(&mmio) == 0u) {
    return 0u;
  }

  if (er_boot_services_set_wifi_runtime(report,
                                        ER_BOOT_WIFI_KIND_CYW43439_SDIO,
                                        0u,
                                        ER_PI_ZERO2W_WIFI_DEFAULT_CHANNEL) == 0u ||
      er_boot_services_set_bluetooth_runtime(
          report,
          ER_BOOT_BLUETOOTH_KIND_CYW43439_HCI_UART,
          0u) == 0u ||
      er_boot_services_set_local_storage(
          report,
          ER_BOOT_LOCAL_STORAGE_KIND_SD_CARD,
          0u,
          ER_PI_ZERO2W_STORAGE_BLOCK_BYTES,
          ER_PI_ZERO2W_STORAGE_BLOCK_BYTES) == 0u ||
      er_boot_services_set_update_artifact_store(report, 0u, 0u) == 0u) {
    return 0u;
  }

  return 1u;
}
