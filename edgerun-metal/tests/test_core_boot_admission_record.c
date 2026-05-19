static void test_boot_admission_record(void) {
  enum {
    BOOT_ADMISSION_TEST_GENERATION = 7u,
    BOOT_ADMISSION_TEST_VENDOR_ID = 0x1af4u,
    BOOT_ADMISSION_TEST_DEVICE_ID = 0x1000u
  };
  ErCryptoProvider crypto;
  ErBootAdmissionRecord local_record;
  ErBootAdmissionRecord external_record;
  ErBootAdmissionRecord ephemeral_record;
  ErBootAdmissionRecord decoded_record;
  ErIdentity admission_identity;
  UINT8 encoded[ER_BOOT_ADMISSION_RECORD_BYTES];
  UINT8 public_key[ER_P256_PUBLIC_KEY_LEN];

  er_crypto_blake3_provider(&crypto);
  test_fill_bytes(public_key, (UINTN)sizeof(public_key), 0x51u);

  check_int64("boot admission native eth valid",
              er_boot_admission_channel_valid(ER_BOOT_BOOTSTRAP_CHANNEL_NATIVE_ETH), 1);
  check_int64("boot admission reject invalid channel",
              er_boot_admission_channel_valid(0xffu), 0);
  check_cstr("boot admission local label",
             er_boot_admission_mode_label(ER_BOOT_ADMISSION_MODE_LOCAL), "local");
  check_cstr("boot admission wifi label",
             er_boot_bootstrap_channel_label(ER_BOOT_BOOTSTRAP_CHANNEL_WIFI_OPEN_EDGERUN),
             "wifi-open-edgerun");

  check_int64("boot admission prepare local",
              er_boot_admission_record_prepare_local(&crypto,
                                                     BOOT_ADMISSION_TEST_GENERATION,
                                                     ER_BOOT_BOOTSTRAP_CHANNEL_NATIVE_ETH,
                                                     BOOT_ADMISSION_TEST_VENDOR_ID,
                                                     BOOT_ADMISSION_TEST_DEVICE_ID,
                                                     &local_record),
              1);
  check_int64("boot admission local valid",
              er_boot_admission_record_valid(&crypto, &local_record), 1);
  check_uint64("boot admission local mode",
               local_record.admission_mode, ER_BOOT_ADMISSION_MODE_LOCAL);
  check_uint64("boot admission local channel",
               local_record.bootstrap_channel_kind, ER_BOOT_BOOTSTRAP_CHANNEL_NATIVE_ETH);
  check_uint64("boot admission local vendor",
               local_record.bootstrap_pci_vendor_id, BOOT_ADMISSION_TEST_VENDOR_ID);
  check_int64("boot admission local hash", er_hash_nonzero(&local_record.record_hash), 1);

  check_int64("boot admission encode",
              er_boot_admission_record_encode(&local_record, encoded), 1);
  check_uint64("boot admission encoded magic", encoded[0], 'E');
  check_uint64("boot admission encoded size",
               ((UINT64)encoded[6] << 8u) | encoded[7], ER_BOOT_ADMISSION_RECORD_BYTES);
  check_int64("boot admission decode",
              er_boot_admission_record_decode(encoded, &decoded_record), 1);
  check_int64("boot admission decoded valid",
              er_boot_admission_record_valid(&crypto, &decoded_record), 1);
  check_hash_equal("boot admission decoded hash",
                   &decoded_record.record_hash, &local_record.record_hash);

  decoded_record.bootstrap_channel_kind = ER_BOOT_BOOTSTRAP_CHANNEL_WIFI_OPEN_EDGERUN;
  check_int64("boot admission tamper rejected",
              er_boot_admission_record_valid(&crypto, &decoded_record), 0);

  check_int64("boot admission identity prepare",
              er_identity_prepare(ER_IDENTITY_TYPE_PUBLIC_KEY,
                                  ER_IDENTITY_BACKING_P256,
                                  public_key,
                                  (UINT16)sizeof(public_key),
                                  &admission_identity),
              1);
  check_int64("boot admission prepare external",
              er_boot_admission_record_prepare_external(&crypto,
                                                        BOOT_ADMISSION_TEST_GENERATION,
                                                        ER_BOOT_BOOTSTRAP_CHANNEL_WIFI_OPEN_EDGERUN,
                                                        0u,
                                                        0u,
                                                        &admission_identity,
                                                        &external_record),
              1);
  check_int64("boot admission external valid",
              er_boot_admission_record_valid(&crypto, &external_record), 1);
  check_uint64("boot admission external mode",
               external_record.admission_mode, ER_BOOT_ADMISSION_MODE_EXTERNAL);
  check_int64("boot admission external identity",
              er_identity_equal(&external_record.admission_identity, &admission_identity), 1);
  check_int64("boot admission reject null external identity",
              er_boot_admission_record_prepare_external(&crypto,
                                                        BOOT_ADMISSION_TEST_GENERATION,
                                                        ER_BOOT_BOOTSTRAP_CHANNEL_WIFI_OPEN_EDGERUN,
                                                        0u,
                                                        0u,
                                                        0,
                                                        &external_record),
              0);
  check_int64("boot admission prepare ephemeral authority",
              er_boot_admission_record_prepare_ephemeral_authority(&crypto,
                                                                   BOOT_ADMISSION_TEST_GENERATION,
                                                                   ER_BOOT_BOOTSTRAP_CHANNEL_NATIVE_ETH,
                                                                   BOOT_ADMISSION_TEST_VENDOR_ID,
                                                                   BOOT_ADMISSION_TEST_DEVICE_ID,
                                                                   4u,
                                                                   &ephemeral_record),
              1);
  check_int64("boot admission ephemeral valid",
              er_boot_admission_record_valid(&crypto, &ephemeral_record), 1);
  check_uint64("boot admission ephemeral mode",
               ephemeral_record.admission_mode, ER_BOOT_ADMISSION_MODE_EXTERNAL);
  check_uint64("boot admission ephemeral identity",
               ephemeral_record.admission_identity.identity_type, ER_IDENTITY_TYPE_HASH);
  check_uint64("boot admission ephemeral backing",
               ephemeral_record.admission_identity.backing_type, ER_IDENTITY_BACKING_EPHEMERAL_HASH);
}
