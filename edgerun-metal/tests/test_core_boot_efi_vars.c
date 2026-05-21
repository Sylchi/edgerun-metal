typedef struct {
  UINT8 present;
  UINT8 corrupt_size;
  UINT8 corrupt_attributes;
  UINT8 set_called;
  UINT8 bytes[ER_BOOT_ADMISSION_RECORD_BYTES];
  UINTN bytes_len;
  UINT32 attributes;
} TestBootEfiVarStore;

static TestBootEfiVarStore* g_test_boot_efi_var_store;

static EFI_STATUS EFIAPI test_boot_efi_vars_get(CHAR16* VariableName,
                                                EFI_GUID* VendorGuid,
                                                UINT32* Attributes,
                                                UINTN* DataSize,
                                                void* Data) {
  (void)VariableName;
  (void)VendorGuid;

  if (g_test_boot_efi_var_store == 0 || DataSize == 0 || Data == 0) {
    return EFI_INVALID_PARAMETER;
  }
  if (g_test_boot_efi_var_store->present == 0u) {
    return EFI_NOT_FOUND;
  }
  if (*DataSize < g_test_boot_efi_var_store->bytes_len) {
    *DataSize = g_test_boot_efi_var_store->bytes_len;
    return EFI_BUFFER_TOO_SMALL;
  }

  er_mem_copy((UINT8*)Data,
              g_test_boot_efi_var_store->bytes,
              g_test_boot_efi_var_store->bytes_len);
  *DataSize = g_test_boot_efi_var_store->corrupt_size != 0u ?
      g_test_boot_efi_var_store->bytes_len - 1u :
      g_test_boot_efi_var_store->bytes_len;
  if (Attributes != 0) {
    *Attributes = g_test_boot_efi_var_store->corrupt_attributes != 0u ?
        EFI_VARIABLE_BOOTSERVICE_ACCESS :
        g_test_boot_efi_var_store->attributes;
  }
  return EFI_SUCCESS;
}

static EFI_STATUS EFIAPI test_boot_efi_vars_set(CHAR16* VariableName,
                                                EFI_GUID* VendorGuid,
                                                UINT32 Attributes,
                                                UINTN DataSize,
                                                void* Data) {
  (void)VariableName;
  (void)VendorGuid;

  if (g_test_boot_efi_var_store == 0 ||
      Data == 0 ||
      DataSize != ER_BOOT_ADMISSION_RECORD_BYTES) {
    return EFI_INVALID_PARAMETER;
  }

  er_mem_copy(g_test_boot_efi_var_store->bytes,
              (const UINT8*)Data,
              ER_BOOT_ADMISSION_RECORD_BYTES);
  g_test_boot_efi_var_store->present = 1u;
  g_test_boot_efi_var_store->set_called = 1u;
  g_test_boot_efi_var_store->bytes_len = ER_BOOT_ADMISSION_RECORD_BYTES;
  g_test_boot_efi_var_store->attributes = Attributes;
  return EFI_SUCCESS;
}

static void test_boot_efi_vars(void) {
  enum {
    BOOT_EFI_VARS_TEST_GENERATION = 3u
  };
  EFI_RUNTIME_SERVICES runtime_services;
  EFI_SYSTEM_TABLE system_table;
  TestBootEfiVarStore store;
  ErCryptoProvider crypto;
  ErBootAdmissionRecord record;
  ErBootAdmissionRecord read_record;

  er_mem_zero((UINT8*)&runtime_services, (UINTN)sizeof(runtime_services));
  er_mem_zero((UINT8*)&system_table, (UINTN)sizeof(system_table));
  er_mem_zero((UINT8*)&store, (UINTN)sizeof(store));
  er_crypto_blake3_provider(&crypto);
  runtime_services.GetVariable = test_boot_efi_vars_get;
  runtime_services.SetVariable = test_boot_efi_vars_set;
  system_table.RuntimeServices = &runtime_services;
  g_test_boot_efi_var_store = &store;

  check_cstr("boot efi var missing label",
             er_boot_efi_vars_admission_read_label(ER_BOOT_EFI_VAR_ADMISSION_MISSING),
             "missing");
  check_int64("boot efi var missing",
              er_boot_efi_vars_read_admission(&system_table, &crypto, &read_record),
              ER_BOOT_EFI_VAR_ADMISSION_MISSING);

  check_int64("boot efi var prepare",
              er_boot_admission_record_prepare(&crypto,
                                               BOOT_EFI_VARS_TEST_GENERATION,
                                               ER_BOOT_BOOTSTRAP_CHANNEL_NATIVE_ETH,
                                               0u,
                                               0u,
                                               &record),
              1);
  check_int64("boot efi var write",
              er_boot_efi_vars_write_admission(&system_table, &crypto, &record), 1);
  check_int64("boot efi var set called", store.set_called, 1);
  check_int64("boot efi var read",
              er_boot_efi_vars_read_admission(&system_table, &crypto, &read_record),
              ER_BOOT_EFI_VAR_ADMISSION_FOUND);
  check_int64("boot efi var read record valid",
              er_boot_admission_record_valid(&crypto, &read_record), 1);
  check_hash_equal("boot efi var read hash", &read_record.record_hash, &record.record_hash);

  store.bytes[0] ^= 1u;
  check_int64("boot efi var tamper invalid",
              er_boot_efi_vars_read_admission(&system_table, &crypto, &read_record),
              ER_BOOT_EFI_VAR_ADMISSION_INVALID);
  store.bytes[0] ^= 1u;
  store.corrupt_size = 1u;
  check_int64("boot efi var size invalid",
              er_boot_efi_vars_read_admission(&system_table, &crypto, &read_record),
              ER_BOOT_EFI_VAR_ADMISSION_INVALID);
  store.corrupt_size = 0u;
  store.corrupt_attributes = 1u;
  check_int64("boot efi var attributes invalid",
              er_boot_efi_vars_read_admission(&system_table, &crypto, &read_record),
              ER_BOOT_EFI_VAR_ADMISSION_INVALID);
  g_test_boot_efi_var_store = 0;
}
