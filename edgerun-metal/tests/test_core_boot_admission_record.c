static void test_boot_admission_record(void) {
  enum {
    BOOT_ADMISSION_TEST_GENERATION = 7u,
    BOOT_ADMISSION_TEST_VENDOR_ID = 0x1af4u,
    BOOT_ADMISSION_TEST_DEVICE_ID = 0x1000u
  };
  ErCryptoProvider crypto;
  ErBootAdmissionRecord record;
  ErBootAdmissionRecord decoded_record;
  UINT8 encoded[ER_BOOT_ADMISSION_RECORD_BYTES];

  er_crypto_blake3_provider(&crypto);

  check_int64("boot admission native eth valid",
              er_boot_admission_channel_valid(ER_BOOT_BOOTSTRAP_CHANNEL_NATIVE_ETH), 1);
  check_int64("boot admission reject invalid channel",
              er_boot_admission_channel_valid(0xffu), 0);
  check_cstr("boot admission local label",
             er_boot_admission_mode_label(ER_BOOT_ADMISSION_MODE_LOCAL), "local");
  check_cstr("boot admission wifi label",
             er_boot_bootstrap_channel_label(ER_BOOT_BOOTSTRAP_CHANNEL_WIFI_OPEN_EDGERUN),
             "wifi-open-edgerun");

  check_int64("boot admission prepare",
              er_boot_admission_record_prepare(&crypto,
                                               BOOT_ADMISSION_TEST_GENERATION,
                                               ER_BOOT_BOOTSTRAP_CHANNEL_NATIVE_ETH,
                                               BOOT_ADMISSION_TEST_VENDOR_ID,
                                               BOOT_ADMISSION_TEST_DEVICE_ID,
                                               &record),
              1);
  check_int64("boot admission valid",
              er_boot_admission_record_valid(&crypto, &record), 1);
  check_uint64("boot admission mode",
               record.admission_mode, ER_BOOT_ADMISSION_MODE_LOCAL);
  check_uint64("boot admission channel",
               record.bootstrap_channel_kind, ER_BOOT_BOOTSTRAP_CHANNEL_NATIVE_ETH);
  check_uint64("boot admission vendor",
               record.bootstrap_pci_vendor_id, BOOT_ADMISSION_TEST_VENDOR_ID);
  check_int64("boot admission hash", er_hash_nonzero(&record.record_hash), 1);

  check_int64("boot admission encode",
              er_boot_admission_record_encode(&record, encoded), 1);
  check_uint64("boot admission encoded magic", encoded[0], 'E');
  check_uint64("boot admission encoded size",
               ((UINT64)encoded[6] << 8u) | encoded[7], ER_BOOT_ADMISSION_RECORD_BYTES);
  check_int64("boot admission decode",
              er_boot_admission_record_decode(encoded, &decoded_record), 1);
  check_int64("boot admission decoded valid",
              er_boot_admission_record_valid(&crypto, &decoded_record), 1);
  check_hash_equal("boot admission decoded hash",
                   &decoded_record.record_hash, &record.record_hash);

  decoded_record.bootstrap_channel_kind = ER_BOOT_BOOTSTRAP_CHANNEL_WIFI_OPEN_EDGERUN;
  check_int64("boot admission tamper rejected",
              er_boot_admission_record_valid(&crypto, &decoded_record), 0);
}
