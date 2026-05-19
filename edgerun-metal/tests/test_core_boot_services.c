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
  ErBootServicesReport report;
  EFI_RUNTIME_SERVICES runtime_services;
  EFI_SYSTEM_TABLE system_table;
  ErTpmNvLimits limits;
  ErPciDeviceSnapshot snapshot;
  ErBootOnboardingModel onboarding;

  er_boot_services_report_init(&report);
  check_uint64("boot services secure boot unknown",
               report.secure_boot_state, ER_BOOT_SECURE_BOOT_UNKNOWN);
  check_uint64("boot services selected invalid",
               report.selected_authority, ER_BOOT_AUTHORITY_PROFILE_CAPACITY);
  check_int64("boot services unknown halts",
              er_boot_services_decide_action(&report), ER_BOOT_SERVICES_ACTION_HALT);
  check_cstr("boot services halt label",
             er_boot_services_action_label(ER_BOOT_SERVICES_ACTION_HALT), "halt");
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
  check_int64("boot services invalid config halts",
              er_boot_services_decide_action(&report), ER_BOOT_SERVICES_ACTION_HALT);
}
