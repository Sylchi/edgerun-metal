static void test_pi_zero2w_bringup_boundary(void) {
  ErPiZero2wMmio mmio;
  ErMmioInfo info;
  ErPiMailboxTwoValueMessage message;
  ErBootServicesReport report;

  er_mmio_reset();
  check_uint64("pi zero peripheral mailbox phys",
               er_pi_zero2w_peripheral_phys(ER_PI_ZERO2W_MAILBOX_OFFSET),
               ER_PI_ZERO2W_PERIPHERAL_BASE + ER_PI_ZERO2W_MAILBOX_OFFSET);
  check_int64("pi zero mmio map", er_pi_zero2w_mmio_map(&mmio), 1);
  check_uint64("pi zero mmio mapped", mmio.mapped, 1u);
  check_int64("pi zero mailbox info",
              er_mmio_get_info(mmio.mailbox_handle, &info), 1);
  check_uint64("pi zero mailbox phys", info.phys,
               ER_PI_ZERO2W_PERIPHERAL_BASE + ER_PI_ZERO2W_MAILBOX_OFFSET);
  check_uint64("pi zero mailbox len", info.len, ER_PI_ZERO2W_MAILBOX_BYTES);
  check_int64("pi zero gpio info", er_mmio_get_info(mmio.gpio_handle, &info), 1);
  check_uint64("pi zero gpio phys", info.phys,
               ER_PI_ZERO2W_PERIPHERAL_BASE + ER_PI_ZERO2W_GPIO_OFFSET);

  check_int64("pi mailbox reject end tag",
              er_pi_mailbox_two_value_request(ER_PI_MAILBOX_TAG_LAST,
                                              0u,
                                              0u,
                                              &message),
              0);
  check_int64("pi mailbox get clock",
              er_pi_mailbox_two_value_request(ER_PI_MAILBOX_TAG_GET_CLOCK_RATE,
                                              ER_PI_CLOCK_ID_EMMC,
                                              0u,
                                              &message),
              1);
  check_uint64("pi mailbox message bytes", message.size_bytes,
               8u * sizeof(UINT32));
  check_uint64("pi mailbox request", message.request_code,
               ER_PI_MAILBOX_REQUEST_CODE);
  check_uint64("pi mailbox tag", message.tag_id,
               ER_PI_MAILBOX_TAG_GET_CLOCK_RATE);
  check_uint64("pi mailbox value bytes", message.value_buffer_bytes, 8u);
  check_uint64("pi mailbox value0", message.value0, ER_PI_CLOCK_ID_EMMC);
  check_uint64("pi mailbox end", message.end_tag, ER_PI_MAILBOX_TAG_LAST);

  er_boot_services_report_init(&report);
  er_mmio_reset();
  check_int64("pi zero boot report",
              er_pi_zero2w_apply_boot_report(&report), 1);
  check_uint64("pi zero report wifi kind",
               report.runtime_capabilities.wifi_kind,
               ER_BOOT_WIFI_KIND_CYW43439_SDIO);
  check_uint64("pi zero report wifi not ready",
               report.runtime_capabilities.wifi_ready, 0u);
  check_uint64("pi zero report bluetooth kind",
               report.runtime_capabilities.bluetooth_kind,
               ER_BOOT_BLUETOOTH_KIND_CYW43439_HCI_UART);
  check_uint64("pi zero report bluetooth not ready",
               report.runtime_capabilities.bluetooth_ready, 0u);
  check_uint64("pi zero report storage kind",
               report.runtime_capabilities.local_storage_kind,
               ER_BOOT_LOCAL_STORAGE_KIND_SD_CARD);
  check_uint64("pi zero report update blocked",
               report.runtime_capabilities.update_blocked_reason,
               ER_BOOT_UPDATE_BLOCKED_NO_WIFI);
}
