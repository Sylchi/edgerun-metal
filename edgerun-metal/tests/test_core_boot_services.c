static void test_boot_services_boundary(void) {
  ErBootServicesReport report;
  ErTpmNvLimits limits;
  ErPciDeviceSnapshot snapshot;

  er_boot_services_report_init(&report);
  check_uint64("boot services secure boot unknown",
               report.secure_boot_state, ER_BOOT_SECURE_BOOT_UNKNOWN);
  check_uint64("boot services selected invalid",
               report.selected_authority, ER_BOOT_AUTHORITY_PROFILE_CAPACITY);
  check_int64("boot services unknown halts",
              er_boot_services_decide_action(&report), ER_BOOT_SERVICES_ACTION_HALT);
  check_cstr("boot services halt label",
             er_boot_services_action_label(ER_BOOT_SERVICES_ACTION_HALT), "halt");

  report.secure_boot_state = ER_BOOT_SECURE_BOOT_VERIFIED;
  er_mem_zero((UINT8*)&limits, (UINTN)sizeof(limits));
  limits.has_nv_index_max = 1u;
  limits.has_nv_buffer_max = 1u;
  limits.nv_index_max = 1600u;
  limits.nv_buffer_max = 1024u;
  check_int64("boot services set tpm limits",
              er_boot_services_set_tpm_limits(&report, &limits), 1);
  check_uint64("boot services tpm present", report.tpm_present, 1u);
  check_uint64("boot services nv index max", report.tpm_nv_limits.nv_index_max, 1600u);
  check_int64("boot services no authority configures",
              er_boot_services_decide_action(&report),
              ER_BOOT_SERVICES_ACTION_CONFIGURE_AUTHORITY);
  check_cstr("boot services configure label",
             er_boot_services_action_label(ER_BOOT_SERVICES_ACTION_CONFIGURE_AUTHORITY),
             "configure-authority");

  check_int64("boot services add authority",
              er_boot_services_add_authority(&report, 0x81000010u, 1u,
                                             ER_BOOT_CONFIG_PRESENT),
              1);
  check_int64("boot services one authority enters runtime",
              er_boot_services_decide_action(&report),
              ER_BOOT_SERVICES_ACTION_ENTER_RUNTIME);
  check_cstr("boot services runtime label",
             er_boot_services_action_label(ER_BOOT_SERVICES_ACTION_ENTER_RUNTIME),
             "enter-runtime");

  check_int64("boot services add second authority",
              er_boot_services_add_authority(&report, 0x81000011u, 2u,
                                             ER_BOOT_CONFIG_PRESENT),
              1);
  check_int64("boot services multiple authority selects",
              er_boot_services_decide_action(&report),
              ER_BOOT_SERVICES_ACTION_SELECT_AUTHORITY);
  check_cstr("boot services select label",
             er_boot_services_action_label(ER_BOOT_SERVICES_ACTION_SELECT_AUTHORITY),
             "select-authority");
  check_int64("boot services select second",
              er_boot_services_select_authority(&report, 1u), 1);
  check_int64("boot services selected enters runtime",
              er_boot_services_decide_action(&report),
              ER_BOOT_SERVICES_ACTION_ENTER_RUNTIME);

  er_mem_zero((UINT8*)&snapshot, (UINTN)sizeof(snapshot));
  snapshot.present = 1u;
  snapshot.bus = 0u;
  snapshot.dev = 2u;
  snapshot.func = 0u;
  snapshot.id = 0x10001af4u;
  snapshot.class_revision = 0x02000000u;
  check_int64("boot services add pci device",
              er_boot_services_add_pci_device(&report, &snapshot), 1);
  check_uint64("boot services device count", report.device_count, 1u);
  check_uint64("boot services device vendor", report.devices[0].vendor_id, 0x1af4u);
  check_uint64("boot services device kind",
               report.devices[0].kind, ER_PCI_TARGET_KIND_ETHERNET);

  report.config_state = ER_BOOT_CONFIG_INVALID;
  check_int64("boot services invalid config halts",
              er_boot_services_decide_action(&report), ER_BOOT_SERVICES_ACTION_HALT);
}
