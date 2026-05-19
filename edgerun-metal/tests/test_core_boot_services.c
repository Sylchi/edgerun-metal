static UINT8 g_test_secure_boot_value = 1u;

static EFI_STATUS EFIAPI test_boot_services_get_variable(CHAR16* VariableName,
                                                         EFI_GUID* VendorGuid,
                                                         UINT32* Attributes,
                                                         UINTN* DataSize,
                                                         void* Data) {
  (void)VariableName;
  (void)VendorGuid;
  (void)Attributes;

  if (DataSize == 0 || Data == 0 || *DataSize < 1u) {
    return EFI_INVALID_PARAMETER;
  }
  *(UINT8*)Data = g_test_secure_boot_value;
  *DataSize = 1u;
  return EFI_SUCCESS;
}

static void test_boot_services_boundary(void) {
  enum {
    BOOT_SERVICES_TEST_ADMISSION_GENERATION = 1u
  };
  ErBootServicesReport report;
  ErBootServicesReport variant_report;
  EFI_RUNTIME_SERVICES runtime_services;
  EFI_SYSTEM_TABLE system_table;
  ErTpmNvLimits limits;
  ErPciDeviceSnapshot snapshot;
  ErBootOnboardingModel onboarding;
  ErCryptoProvider crypto;
  ErBootAdmissionRecord admission_record;

  er_boot_services_report_init(&report);
  check_uint64("boot services secure boot unknown",
               report.secure_boot_state, ER_BOOT_SECURE_BOOT_UNKNOWN);
  check_uint64("boot services selected invalid",
               report.selected_authority, ER_BOOT_AUTHORITY_PROFILE_CAPACITY);
  check_uint64("boot services runtime cap abi",
               report.runtime_capabilities.abi_version,
               ER_BOOT_RUNTIME_CAPABILITY_ABI_VERSION);
  check_uint64("boot services update blocked without wifi",
               report.runtime_capabilities.update_blocked_reason,
               ER_BOOT_UPDATE_BLOCKED_NO_WIFI);
  check_int64("boot services reject impossible wifi",
              er_boot_services_set_wifi_runtime(&report,
                                                ER_BOOT_WIFI_KIND_NONE,
                                                1u,
                                                0u),
              0);
  check_int64("boot services set wifi",
              er_boot_services_set_wifi_runtime(&report,
                                                ER_BOOT_WIFI_KIND_CYW43439_SDIO,
                                                1u,
                                                6u),
              1);
  er_boot_services_report_init(&variant_report);
  check_int64("boot services set cyw43438 wifi",
              er_boot_services_set_wifi_runtime(&variant_report,
                                                ER_BOOT_WIFI_KIND_CYW43438_SDIO,
                                                0u,
                                                6u),
              1);
  check_uint64("boot services update blocked without storage",
               report.runtime_capabilities.update_blocked_reason,
               ER_BOOT_UPDATE_BLOCKED_NO_WRITABLE_STORAGE);
  check_int64("boot services reject impossible bluetooth",
              er_boot_services_set_bluetooth_runtime(&report,
                                                     ER_BOOT_BLUETOOTH_KIND_NONE,
                                                     1u),
              0);
  check_int64("boot services set bluetooth",
              er_boot_services_set_bluetooth_runtime(
                  &report,
                  ER_BOOT_BLUETOOTH_KIND_CYW43439_HCI_UART,
                  1u),
              1);
  check_int64("boot services set cyw43438 bluetooth",
              er_boot_services_set_bluetooth_runtime(
                  &variant_report,
                  ER_BOOT_BLUETOOTH_KIND_CYW43438_HCI_UART,
                  0u),
              1);
  check_uint64("boot services bluetooth ready",
               report.runtime_capabilities.bluetooth_ready, 1u);
  check_int64("boot services reject empty storage",
              er_boot_services_set_local_storage(&report,
                                                 ER_BOOT_LOCAL_STORAGE_KIND_SD_CARD,
                                                 1u,
                                                 0u,
                                                 1024u),
              0);
  check_int64("boot services set storage",
              er_boot_services_set_local_storage(&report,
                                                 ER_BOOT_LOCAL_STORAGE_KIND_SD_CARD,
                                                 1u,
                                                 512u,
                                                 1024u),
              1);
  check_uint64("boot services update blocked without artifact store",
               report.runtime_capabilities.update_blocked_reason,
               ER_BOOT_UPDATE_BLOCKED_NO_ARTIFACT_STORE);
  check_int64("boot services reject zero artifact capacity",
              er_boot_services_set_update_artifact_store(&report, 1u, 0u),
              0);
  check_int64("boot services set artifact store",
              er_boot_services_set_update_artifact_store(&report,
                                                         1u,
                                                         512u * 1024u),
              1);
  check_uint64("boot services update ready",
               report.runtime_capabilities.update_ready, 1u);
  check_uint64("boot services update ready reason",
               report.runtime_capabilities.update_blocked_reason,
               ER_BOOT_UPDATE_READY);
  check_int64("boot services unknown blocked",
              er_boot_services_decide_action(&report), ER_BOOT_SERVICES_ACTION_BLOCKED);
  check_cstr("boot services blocked label",
             er_boot_services_action_label(ER_BOOT_SERVICES_ACTION_BLOCKED), "blocked");
  check_int64("boot services runtime denied",
              er_boot_services_runtime_entry_allowed(&report), 0);
  er_boot_services_onboarding_model(&report, &onboarding);
  check_uint64("boot services unknown onboarding fatal",
               onboarding.state, ER_BOOT_ONBOARDING_STATE_FATAL);
  check_cstr("boot services onboarding fatal label",
             er_boot_services_onboarding_state_label(onboarding.state), "fatal");
  check_int64("boot services reject empty label",
              er_boot_services_authority_label_valid("", 0u), 0);
  check_int64("boot services accept profile label",
              er_boot_services_authority_label_valid("personal", 8u), 1);

  er_mem_zero((UINT8*)&runtime_services, (UINTN)sizeof(runtime_services));
  er_mem_zero((UINT8*)&system_table, (UINTN)sizeof(system_table));
  runtime_services.GetVariable = test_boot_services_get_variable;
  system_table.RuntimeServices = &runtime_services;
  g_test_secure_boot_value = 1u;
  check_int64("boot services probe secure boot",
              er_boot_services_probe_secure_boot(&system_table, &report), 1);
  check_uint64("boot services secure boot verified",
               report.secure_boot_state, ER_BOOT_SECURE_BOOT_VERIFIED);
  check_int64("boot services probe missing tpm",
              er_boot_services_probe_tpm(&system_table, &report), 0);

  g_test_secure_boot_value = 0u;
  check_int64("boot services probe secure boot disabled",
              er_boot_services_probe_secure_boot(&system_table, &report), 1);
  check_uint64("boot services secure boot disabled",
               report.secure_boot_state, ER_BOOT_SECURE_BOOT_DISABLED);

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
  er_boot_services_onboarding_model(&report, &onboarding);
  check_uint64("boot services onboarding create first",
               onboarding.state, ER_BOOT_ONBOARDING_STATE_CREATE_FIRST_PROFILE);
  check_uint64("boot services onboarding no choices", onboarding.choice_count, 0u);
  check_cstr("boot services onboarding create label",
             er_boot_services_onboarding_state_label(onboarding.state),
             "create-first-profile");

  check_int64("boot services reject unnamed authority",
              er_boot_services_add_authority_profile(&report, 0x81000010u, 1u,
                                                     ER_BOOT_CONFIG_PRESENT,
                                                     "", 0u),
              0);
  check_int64("boot services add personal authority",
              er_boot_services_add_authority_profile(&report, 0x81000010u, 1u,
                                                     ER_BOOT_CONFIG_PRESENT,
                                                     "personal", 8u),
              1);
  check_int64("boot services one authority enters runtime",
              er_boot_services_decide_action(&report),
              ER_BOOT_SERVICES_ACTION_ENTER_RUNTIME);
  check_cstr("boot services runtime label",
             er_boot_services_action_label(ER_BOOT_SERVICES_ACTION_ENTER_RUNTIME),
             "enter-runtime");
  er_boot_services_onboarding_model(&report, &onboarding);
  check_uint64("boot services onboarding ready",
               onboarding.state, ER_BOOT_ONBOARDING_STATE_READY);
  check_uint64("boot services onboarding one choice", onboarding.choice_count, 1u);
  check_cstr("boot services onboarding personal label",
             onboarding.choices[0].label, "personal");

  check_int64("boot services add second authority",
              er_boot_services_add_authority_profile(&report, 0x81000011u, 2u,
                                                     ER_BOOT_CONFIG_PRESENT,
                                                     "lab", 3u),
              1);
  check_int64("boot services multiple authority selects",
              er_boot_services_decide_action(&report),
              ER_BOOT_SERVICES_ACTION_SELECT_AUTHORITY);
  check_cstr("boot services select label",
             er_boot_services_action_label(ER_BOOT_SERVICES_ACTION_SELECT_AUTHORITY),
             "select-authority");
  er_boot_services_onboarding_model(&report, &onboarding);
  check_uint64("boot services onboarding select",
               onboarding.state, ER_BOOT_ONBOARDING_STATE_SELECT_PROFILE);
  check_uint64("boot services onboarding two choices", onboarding.choice_count, 2u);
  check_cstr("boot services onboarding lab label",
             onboarding.choices[1].label, "lab");
  check_int64("boot services select second",
              er_boot_services_select_authority(&report, 1u), 1);
  check_int64("boot services selected enters runtime",
              er_boot_services_decide_action(&report),
              ER_BOOT_SERVICES_ACTION_ENTER_RUNTIME);
  check_int64("boot services runtime allowed",
              er_boot_services_runtime_entry_allowed(&report), 1);
  er_boot_services_onboarding_model(&report, &onboarding);
  check_uint64("boot services onboarding selected", onboarding.selected_authority, 1u);

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
  check_int64("boot services invalid config blocked",
              er_boot_services_decide_action(&report), ER_BOOT_SERVICES_ACTION_BLOCKED);

  er_crypto_blake3_provider(&crypto);
  er_boot_services_report_init(&report);
  report.secure_boot_state = ER_BOOT_SECURE_BOOT_VERIFIED;
  check_int64("boot services set tpm limits for admission",
              er_boot_services_set_tpm_limits(&report, &limits), 1);
  check_int64("boot services prepare local admission",
              er_boot_admission_record_prepare_local(&crypto,
                                                     BOOT_SERVICES_TEST_ADMISSION_GENERATION,
                                                     ER_BOOT_BOOTSTRAP_CHANNEL_NATIVE_ETH,
                                                     0u,
                                                     0u,
                                                     &admission_record),
              1);
  check_int64("boot services set boot admission",
              er_boot_services_set_boot_admission(&report, &crypto, &admission_record), 1);
  check_int64("boot services local admission not ephemeral",
              er_boot_services_report_has_ephemeral_admission(&report), 0);
  check_int64("boot services admission enters runtime",
              er_boot_services_decide_action(&report),
              ER_BOOT_SERVICES_ACTION_ENTER_RUNTIME);
  check_int64("boot services admission runtime allowed",
              er_boot_services_runtime_entry_allowed(&report), 1);

  er_boot_services_report_init(&report);
  check_int64("boot services prepare ephemeral admission",
              er_boot_admission_record_prepare_ephemeral_authority(&crypto,
                                                                   BOOT_SERVICES_TEST_ADMISSION_GENERATION,
                                                                   ER_BOOT_BOOTSTRAP_CHANNEL_NATIVE_ETH,
                                                                   0u,
                                                                   0u,
                                                                   4u,
                                                                   &admission_record),
              1);
  check_int64("boot services set ephemeral admission",
              er_boot_services_set_boot_admission(&report, &crypto, &admission_record), 1);
  check_int64("boot services detects ephemeral admission",
              er_boot_services_report_has_ephemeral_admission(&report), 1);
  check_int64("boot services default build still blocks ephemeral without secure boot",
              er_boot_services_decide_action(&report), ER_BOOT_SERVICES_ACTION_BLOCKED);
}
