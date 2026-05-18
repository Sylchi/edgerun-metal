#include "test_core_internal.h"

static void test_vfs_object_packets(void) {
  static const UINT8 object_bytes[] = {'a', 'b', 'c', 'd', 'e', 'f'};
  ErCryptoProvider crypto;
  ErVfsObjectPacket packet;
  ErVfsObjectPacket packets[2];
  ErVfsObjectPacket tampered_packets[2];
  ErVfsObjectLabelRef ref;
  ErVfsObjectLabelRef ref_from_object;
  ErVfsObjectTransformRef transform;
  UINT8 large_object[1500];
  UINT8 assembled[1500];
  ErHash assembled_object_id;
  UINTN assembled_len = 0u;
  UINTN i;

  crypto.ctx = (void*)(UINTN)5u;
  crypto.hash = test_hash;
  crypto.seal = 0;
  crypto.open = 0;
  crypto.sign = 0;
  crypto.verify = 0;

  check_int64("vfs label valid", er_vfs_label_valid("app/data.bin", 12), 1);
  check_int64("vfs label reject empty", er_vfs_label_valid("", 0), 0);
  check_int64("vfs label reject absolute", er_vfs_label_valid("/app/data.bin", 13), 0);
  check_int64("vfs label reject parent", er_vfs_label_valid("app/../data.bin", 15), 0);
  check_int64("vfs label reject backslash", er_vfs_label_valid("app\\data.bin", 12), 0);

  check_int64("vfs object packet", er_vfs_prepare_object_packet(&crypto, object_bytes, sizeof(object_bytes), 2, 1, 3, &packet), 1);
  check_int64("vfs packet abi", packet.header.abi_version, ER_VFS_ABI_VERSION);
  check_int64("vfs packet index", packet.header.packet_index, 1);
  check_int64("vfs packet count", packet.header.packet_count, 3);
  check_uint64("vfs packet object len", packet.header.object_len, sizeof(object_bytes));
  check_uint64("vfs packet offset", packet.header.offset, 2);
  check_uint64("vfs packet bytes len", packet.header.bytes_len, 4);
  check_int64("vfs packet byte0", packet.bytes[0], 'c');
  check_int64("vfs packet byte3", packet.bytes[3], 'f');

  for (i = 0u; i < sizeof(large_object); ++i) {
    large_object[i] = (UINT8)(i & 0xffu);
  }
  check_int64("vfs object packet 0",
              er_vfs_prepare_object_packet(&crypto, large_object,
                                           sizeof(large_object), 0u, 0u, 2u,
                                           &packets[0]),
              1);
  check_int64("vfs object packet 1",
              er_vfs_prepare_object_packet(&crypto, large_object,
                                           sizeof(large_object),
                                           ER_VFS_OBJECT_PACKET_BYTES, 1u, 2u,
                                           &packets[1]),
              1);
  check_int64("vfs assemble object",
              er_vfs_assemble_object_packets(&crypto, packets, 2u, assembled,
                                             sizeof(assembled), &assembled_len,
                                             &assembled_object_id),
              1);
  check_uint64("vfs assemble len", assembled_len, sizeof(large_object));
  check_hash_equal("vfs assemble object id", &assembled_object_id,
                   &packets[0].header.object_id);
  check_int64("vfs assemble first byte", assembled[0], large_object[0]);
  check_int64("vfs assemble split byte",
              assembled[ER_VFS_OBJECT_PACKET_BYTES],
              large_object[ER_VFS_OBJECT_PACKET_BYTES]);
  check_int64("vfs assemble last byte",
              assembled[sizeof(large_object) - 1u],
              large_object[sizeof(large_object) - 1u]);
  tampered_packets[0] = packets[0];
  tampered_packets[1] = packets[1];
  tampered_packets[1].bytes[0] ^= 1u;
  check_int64("vfs assemble reject payload tamper",
              er_vfs_assemble_object_packets(&crypto, tampered_packets, 2u,
                                             assembled, sizeof(assembled),
                                             &assembled_len,
                                             &assembled_object_id),
              0);
  tampered_packets[0] = packets[1];
  tampered_packets[1] = packets[0];
  check_int64("vfs assemble reject packet order",
              er_vfs_assemble_object_packets(&crypto, tampered_packets, 2u,
                                             assembled, sizeof(assembled),
                                             &assembled_len,
                                             &assembled_object_id),
              0);
  check_int64("vfs assemble reject short buffer",
              er_vfs_assemble_object_packets(&crypto, packets, 2u, assembled,
                                             sizeof(assembled) - 1u,
                                             &assembled_len,
                                             &assembled_object_id),
              0);

  check_int64("vfs label ref", er_vfs_prepare_object_label_ref(&crypto, "app/data.bin", 12, object_bytes, sizeof(object_bytes), &ref), 1);
  check_int64("vfs label ref abi", ref.abi_version, ER_VFS_ABI_VERSION);
  check_int64("vfs label ref label len", ref.label_len, 12);
  check_uint64("vfs label ref object len", ref.object_len, sizeof(object_bytes));
  check_int64("vfs label ref from object",
              er_vfs_prepare_object_label_ref_from_object(&crypto, "app/alias.bin", 13, &ref.object_id,
                                                          ref.object_len, &ref_from_object),
              1);
  check_int64("vfs label ref from object abi", ref_from_object.abi_version, ER_VFS_ABI_VERSION);
  check_uint64("vfs label ref from object len", ref_from_object.object_len, sizeof(object_bytes));
  check_hash_equal("vfs label ref from object id", &ref_from_object.object_id, &ref.object_id);

  check_int64("vfs transform reject unsealed",
              er_vfs_prepare_transform_ref(&crypto, &ref.object_id, ref.object_len, &packet.header.payload_hash,
                                           packet.header.bytes_len, ER_VFS_COMPRESSION_NONE, ER_VFS_SEAL_NONE,
                                           &transform),
              0);
  check_int64("vfs transform sealed",
              er_vfs_prepare_transform_ref(&crypto, &ref.object_id, ref.object_len, &packet.header.payload_hash,
                                           packet.header.bytes_len, ER_VFS_COMPRESSION_NONE, ER_VFS_SEAL_AES256_GCM,
                                           &transform),
              1);
  check_int64("vfs transform abi", transform.abi_version, ER_VFS_ABI_VERSION);
  check_int64("vfs transform seal", transform.seal_kind, ER_VFS_SEAL_AES256_GCM);
}

static void test_app_identity_routes(void) {
  ErCryptoProvider crypto;
  static const UINT8 app_bytes[] = {'w', 'a', 's', 'm', '-', 'u', 'i'};
  static const UINT8 manifest_bytes[] = {'m', 'a', 'n', 'i', 'f', 'e', 's', 't'};
  static const UINT8 ui_assets_bytes[] = {'a', 's', 's', 'e', 't', 's'};
  ErVfsObjectLabelRef app_ref;
  ErVfsObjectLabelRef app_alias_ref;
  ErVfsObjectLabelRef app_bad_label_ref;
  ErVfsObjectLabelRef manifest_ref;
  ErVfsObjectLabelRef manifest_alias_ref;
  ErVfsObjectLabelRef ui_assets_ref;
  ErVfsObjectPacket app_packet;
  ErVfsObjectPacket manifest_packet;
  ErVfsObjectPacket ui_assets_packet;
  ErVfsObjectPacket tampered_manifest_packet;
  ErAppPackageObjectLoad app_load;
  ErAppPackageObjectLoad manifest_load;
  ErAppPackageObjectLoad ui_assets_load;
  ErAppPackageManifest package;
  ErAppPackageManifest package_alias;
  ErAppPackageManifest package_without_assets;
  ErAppPackageManifest package_bad_id;
  ErAppLoadedPackage loaded_package;
  ErAppPackageStorageSource storage_source;
  ErAppPackageStorageSource storage_source_again;
  ErAppPackageStorageSource package_without_assets_source;
  ErAppPackageStorageSource bad_storage_source;
  ErAppPackageStorageResponse app_storage_response;
  ErAppPackageStorageResponse manifest_storage_response;
  ErAppPackageStorageResponse ui_assets_storage_response;
  ErAppPackageStorageResponse bad_storage_response;
  ErAppPackageStorageObject app_storage_object;
  ErAppPackageStorageObject manifest_storage_object;
  ErAppPackageStorageObject ui_assets_storage_object;
  ErAppPackageStorageObject bad_storage_object;
  ErAdmittedRoute app_retrieve_route;
  ErAdmittedRoute manifest_retrieve_route;
  ErAdmittedRoute ui_assets_retrieve_route;
  ErAdmittedRoute bad_retrieve_route;
  ErHash app_object_id;
  ErHash manifest_hash;
  ErHash admission_id;
  ErHash capability_id;
  ErHash route_hash;
  ErNodeId target_node_id;
  ErNodeId parent_relay_node_id;
  ErNodeId ui_relay_node_id;
  ErAppIdentity identity;
  ErAppIpcRouteBinding binding;
  ErAppBudget budget;
  ErAppUsage usage;
  ErAppScheduleSlot slot;
  ErAppLaunchAllocation allocation;
  ErAppExecutionJurisdiction jurisdiction;
  ErAppUiPresentation presentation;
  er_ui_scene_budget_t scene_budget;
  er_ui_scene_stats_t scene_stats;
  UINT8 loaded_app_bytes[sizeof(app_bytes)];
  UINT8 loaded_manifest_bytes[sizeof(manifest_bytes)];
  UINT8 loaded_ui_assets_bytes[sizeof(ui_assets_bytes)];
  UINT8 nonce[ER_APP_INSTANCE_NONCE_LEN];
  UINTN i;

  crypto.ctx = (void*)(UINTN)9u;
  crypto.hash = test_hash;
  crypto.seal = 0;
  crypto.open = 0;
  crypto.sign = 0;
  crypto.verify = 0;

  check_int64("app package app ref",
              er_vfs_prepare_object_label_ref(&crypto, "apps/counter.wasm", 17,
                                              app_bytes, sizeof(app_bytes), &app_ref),
              1);
  check_int64("app package app alias ref",
              er_vfs_prepare_object_label_ref(&crypto, "drafts/main.wasm", 16,
                                              app_bytes, sizeof(app_bytes), &app_alias_ref),
              1);
  check_int64("app package manifest ref",
              er_vfs_prepare_object_label_ref(&crypto, "apps/counter.manifest", 21,
                                              manifest_bytes, sizeof(manifest_bytes), &manifest_ref),
              1);
  check_int64("app package manifest alias ref",
              er_vfs_prepare_object_label_ref(&crypto, "drafts/app.manifest", 19,
                                              manifest_bytes, sizeof(manifest_bytes),
                                              &manifest_alias_ref),
              1);
  check_int64("app package assets ref",
              er_vfs_prepare_object_label_ref(&crypto, "apps/counter.assets", 19,
                                              ui_assets_bytes, sizeof(ui_assets_bytes),
                                              &ui_assets_ref),
              1);
  check_int64("app package prepare",
              er_app_prepare_package_manifest(&crypto, &app_ref, &manifest_ref,
                                              &ui_assets_ref, &package),
              1);
  check_int64("app package abi", package.abi_version, ER_APP_ABI_VERSION);
  check_int64("app package kind", package.app_kind, ER_APP_KIND_USER);
  check_hash_equal("app package app object", &package.app_object_id,
                   &app_ref.object_id);
  check_hash_equal("app package manifest object", &package.manifest_object_id,
                   &manifest_ref.object_id);
  check_uint64("app package app len", package.app_object_len, sizeof(app_bytes));
  check_uint64("app package manifest len", package.manifest_object_len,
               sizeof(manifest_bytes));
  check_uint64("app package assets len", package.ui_assets_object_len,
               sizeof(ui_assets_bytes));
  check_int64("app package alias prepare",
              er_app_prepare_package_manifest(&crypto, &app_alias_ref,
                                              &manifest_alias_ref,
                                              &ui_assets_ref, &package_alias),
              1);
  check_hash_equal("app package labels ignored", &package_alias.package_id,
                   &package.package_id);
  check_int64("app package without assets",
              er_app_prepare_package_manifest(&crypto, &app_ref, &manifest_ref,
                                              0, &package_without_assets),
              1);
  check_hash_not_equal("app package assets affect id",
                       &package_without_assets.package_id, &package.package_id);
  check_int64("app package reject missing manifest",
              er_app_prepare_package_manifest(&crypto, &app_ref, 0,
                                              &ui_assets_ref, &package_alias),
              0);
  app_bad_label_ref = app_ref;
  app_bad_label_ref.label[0] = '/';
  check_int64("app package reject invalid label ref",
              er_app_prepare_package_manifest(&crypto, &app_bad_label_ref,
                                              &manifest_ref, &ui_assets_ref,
                                              &package_alias),
              0);
  check_int64("app package app packet",
              er_vfs_prepare_object_packet(&crypto, app_bytes, sizeof(app_bytes),
                                           0u, 0u, 1u, &app_packet),
              1);
  check_int64("app package manifest packet",
              er_vfs_prepare_object_packet(&crypto, manifest_bytes,
                                           sizeof(manifest_bytes), 0u, 0u, 1u,
                                           &manifest_packet),
              1);
  check_int64("app package assets packet",
              er_vfs_prepare_object_packet(&crypto, ui_assets_bytes,
                                           sizeof(ui_assets_bytes), 0u, 0u, 1u,
                                           &ui_assets_packet),
              1);
  app_load.packets = &app_packet;
  app_load.packet_count = 1u;
  app_load.bytes = loaded_app_bytes;
  app_load.capacity = sizeof(loaded_app_bytes);
  manifest_load.packets = &manifest_packet;
  manifest_load.packet_count = 1u;
  manifest_load.bytes = loaded_manifest_bytes;
  manifest_load.capacity = sizeof(loaded_manifest_bytes);
  ui_assets_load.packets = &ui_assets_packet;
  ui_assets_load.packet_count = 1u;
  ui_assets_load.bytes = loaded_ui_assets_bytes;
  ui_assets_load.capacity = sizeof(loaded_ui_assets_bytes);
  check_int64("app package load",
              er_app_load_package_objects(&crypto, &package, &app_load,
                                          &manifest_load, &ui_assets_load,
                                          &loaded_package),
              1);
  check_int64("app package load abi", loaded_package.abi_version,
              ER_APP_ABI_VERSION);
  check_hash_equal("app package load package id", &loaded_package.package_id,
                   &package.package_id);
  check_uint64("app package load app len", loaded_package.app_len,
               sizeof(app_bytes));
  check_uint64("app package load manifest len", loaded_package.manifest_len,
               sizeof(manifest_bytes));
  check_uint64("app package load assets len", loaded_package.ui_assets_len,
               sizeof(ui_assets_bytes));
  check_int64("app package load app byte", loaded_package.app_bytes[0],
              app_bytes[0]);
  check_int64("app package load manifest byte",
              loaded_package.manifest_bytes[0], manifest_bytes[0]);
  check_int64("app package load assets byte",
              loaded_package.ui_assets_bytes[0], ui_assets_bytes[0]);
  check_int64("app package load without assets",
              er_app_load_package_objects(&crypto, &package_without_assets,
                                          &app_load, &manifest_load, 0,
                                          &loaded_package),
              1);
  check_uint64("app package load no assets len",
               loaded_package.ui_assets_len, 0u);
  check_int64("app package load reject extra assets",
              er_app_load_package_objects(&crypto, &package_without_assets,
                                          &app_load, &manifest_load,
                                          &ui_assets_load, &loaded_package),
              0);
  package_bad_id = package;
  package_bad_id.package_id.bytes[0] ^= 1u;
  check_int64("app package load reject package id",
              er_app_load_package_objects(&crypto, &package_bad_id, &app_load,
                                          &manifest_load, &ui_assets_load,
                                          &loaded_package),
              0);
  tampered_manifest_packet = manifest_packet;
  tampered_manifest_packet.bytes[0] ^= 1u;
  manifest_load.packets = &tampered_manifest_packet;
  check_int64("app package load reject manifest bytes",
              er_app_load_package_objects(&crypto, &package, &app_load,
                                          &manifest_load, &ui_assets_load,
                                          &loaded_package),
              0);
  manifest_load.packets = &manifest_packet;

  er_mem_zero((UINT8*)&app_retrieve_route, (UINTN)sizeof(app_retrieve_route));
  app_retrieve_route.abi_version = ER_WORK_ABI_VERSION;
  app_retrieve_route.role = ER_NODE_ROLE_STORAGE;
  app_retrieve_route.department = ER_DEPARTMENT_STORAGE;
  app_retrieve_route.work_type = ER_WORK_TYPE_OBJECT_RETRIEVE;
  app_retrieve_route.admitted_budget = 32u;
  test_fill_bytes(app_retrieve_route.route_id.bytes, ER_HASH_LEN, 0x11u);
  test_fill_bytes(app_retrieve_route.request_hash.bytes, ER_HASH_LEN, 0x12u);
  test_fill_bytes(app_retrieve_route.admission_hash.bytes, ER_HASH_LEN, 0x13u);
  test_fill_bytes(app_retrieve_route.source_node_id.bytes, ER_NODE_ID_LEN, 0x14u);
  test_fill_bytes(app_retrieve_route.target_node_id.bytes, ER_NODE_ID_LEN, 0x15u);
  test_fill_bytes(app_retrieve_route.relay_node_id.bytes, ER_NODE_ID_LEN, 0x16u);
  manifest_retrieve_route = app_retrieve_route;
  test_fill_bytes(manifest_retrieve_route.route_id.bytes, ER_HASH_LEN, 0x21u);
  test_fill_bytes(manifest_retrieve_route.request_hash.bytes, ER_HASH_LEN, 0x22u);
  ui_assets_retrieve_route = app_retrieve_route;
  test_fill_bytes(ui_assets_retrieve_route.route_id.bytes, ER_HASH_LEN, 0x31u);
  test_fill_bytes(ui_assets_retrieve_route.request_hash.bytes, ER_HASH_LEN, 0x32u);
  check_int64("app package storage source",
              er_app_prepare_package_storage_source(&crypto, &package,
                                                    &app_retrieve_route,
                                                    &manifest_retrieve_route,
                                                    &ui_assets_retrieve_route,
                                                    &storage_source),
              1);
  check_int64("app package storage source abi", storage_source.abi_version,
              ER_APP_ABI_VERSION);
  check_hash_equal("app package storage source package",
                   &storage_source.package_id, &package.package_id);
  check_hash_equal("app package storage app route",
                   &storage_source.app_retrieve_route_id,
                   &app_retrieve_route.route_id);
  check_hash_equal("app package storage manifest route",
                   &storage_source.manifest_retrieve_route_id,
                   &manifest_retrieve_route.route_id);
  check_hash_equal("app package storage assets route",
                   &storage_source.ui_assets_retrieve_route_id,
                   &ui_assets_retrieve_route.route_id);
  check_int64("app package storage source deterministic",
              er_app_prepare_package_storage_source(&crypto, &package,
                                                    &app_retrieve_route,
                                                    &manifest_retrieve_route,
                                                    &ui_assets_retrieve_route,
                                                    &storage_source_again),
              1);
  check_hash_equal("app package storage source id deterministic",
                   &storage_source_again.source_id, &storage_source.source_id);
  er_mem_zero((UINT8*)&app_storage_response,
              (UINTN)sizeof(app_storage_response));
  app_storage_response.abi_version = ER_APP_ABI_VERSION;
  app_storage_response.retrieve_route_id = storage_source.app_retrieve_route_id;
  app_storage_response.object_id = package.app_object_id;
  app_storage_response.object_len = package.app_object_len;
  app_storage_response.packets = app_load.packets;
  app_storage_response.packet_count = app_load.packet_count;
  app_storage_response.bytes = app_load.bytes;
  app_storage_response.capacity = app_load.capacity;
  er_mem_zero((UINT8*)&manifest_storage_response,
              (UINTN)sizeof(manifest_storage_response));
  manifest_storage_response.abi_version = ER_APP_ABI_VERSION;
  manifest_storage_response.retrieve_route_id =
      storage_source.manifest_retrieve_route_id;
  manifest_storage_response.object_id = package.manifest_object_id;
  manifest_storage_response.object_len = package.manifest_object_len;
  manifest_storage_response.packets = manifest_load.packets;
  manifest_storage_response.packet_count = manifest_load.packet_count;
  manifest_storage_response.bytes = manifest_load.bytes;
  manifest_storage_response.capacity = manifest_load.capacity;
  er_mem_zero((UINT8*)&ui_assets_storage_response,
              (UINTN)sizeof(ui_assets_storage_response));
  ui_assets_storage_response.abi_version = ER_APP_ABI_VERSION;
  ui_assets_storage_response.retrieve_route_id =
      storage_source.ui_assets_retrieve_route_id;
  ui_assets_storage_response.object_id = package.ui_assets_object_id;
  ui_assets_storage_response.object_len = package.ui_assets_object_len;
  ui_assets_storage_response.packets = ui_assets_load.packets;
  ui_assets_storage_response.packet_count = ui_assets_load.packet_count;
  ui_assets_storage_response.bytes = ui_assets_load.bytes;
  ui_assets_storage_response.capacity = ui_assets_load.capacity;
  check_int64("app package storage object app",
              er_app_prepare_package_storage_object(&app_storage_response,
                                                    &storage_source.app_retrieve_route_id,
                                                    &package.app_object_id,
                                                    package.app_object_len,
                                                    &app_storage_object),
              1);
  check_hash_equal("app package storage object route",
                   &app_storage_object.retrieve_route_id,
                   &storage_source.app_retrieve_route_id);
  check_int64("app package storage object manifest",
              er_app_prepare_package_storage_object(&manifest_storage_response,
                                                    &storage_source.manifest_retrieve_route_id,
                                                    &package.manifest_object_id,
                                                    package.manifest_object_len,
                                                    &manifest_storage_object),
              1);
  check_int64("app package storage object assets",
              er_app_prepare_package_storage_object(&ui_assets_storage_response,
                                                    &storage_source.ui_assets_retrieve_route_id,
                                                    &package.ui_assets_object_id,
                                                    package.ui_assets_object_len,
                                                    &ui_assets_storage_object),
              1);
  bad_storage_response = app_storage_response;
  bad_storage_response.retrieve_route_id =
      storage_source.manifest_retrieve_route_id;
  check_int64("app package storage object reject route",
              er_app_prepare_package_storage_object(&bad_storage_response,
                                                    &storage_source.app_retrieve_route_id,
                                                    &package.app_object_id,
                                                    package.app_object_len,
                                                    &bad_storage_object),
              0);
  bad_storage_response = app_storage_response;
  bad_storage_response.object_id = package.manifest_object_id;
  check_int64("app package storage object reject id",
              er_app_prepare_package_storage_object(&bad_storage_response,
                                                    &storage_source.app_retrieve_route_id,
                                                    &package.app_object_id,
                                                    package.app_object_len,
                                                    &bad_storage_object),
              0);
  bad_storage_response = app_storage_response;
  --bad_storage_response.object_len;
  check_int64("app package storage object reject len",
              er_app_prepare_package_storage_object(&bad_storage_response,
                                                    &storage_source.app_retrieve_route_id,
                                                    &package.app_object_id,
                                                    package.app_object_len,
                                                    &bad_storage_object),
              0);
  bad_storage_response = app_storage_response;
  bad_storage_response.capacity = bad_storage_response.object_len - 1u;
  check_int64("app package storage object reject capacity",
              er_app_prepare_package_storage_object(&bad_storage_response,
                                                    &storage_source.app_retrieve_route_id,
                                                    &package.app_object_id,
                                                    package.app_object_len,
                                                    &bad_storage_object),
              0);
  check_int64("app package storage load",
              er_app_load_package_from_storage_source(&crypto, &package,
                                                      &storage_source,
                                                      &app_storage_object,
                                                      &manifest_storage_object,
                                                      &ui_assets_storage_object,
                                                      &loaded_package),
              1);
  check_hash_equal("app package storage load package",
                   &loaded_package.package_id, &package.package_id);
  check_uint64("app package storage load app len", loaded_package.app_len,
               sizeof(app_bytes));
  bad_storage_object = app_storage_object;
  bad_storage_object.retrieve_route_id = manifest_storage_object.retrieve_route_id;
  check_int64("app package storage load reject route mismatch",
              er_app_load_package_from_storage_source(&crypto, &package,
                                                      &storage_source,
                                                      &bad_storage_object,
                                                      &manifest_storage_object,
                                                      &ui_assets_storage_object,
                                                      &loaded_package),
              0);
  bad_storage_source = storage_source;
  bad_storage_source.source_id.bytes[0] ^= 1u;
  check_int64("app package storage load reject source id",
              er_app_load_package_from_storage_source(&crypto, &package,
                                                      &bad_storage_source,
                                                      &app_storage_object,
                                                      &manifest_storage_object,
                                                      &ui_assets_storage_object,
                                                      &loaded_package),
              0);
  check_int64("app package storage source without assets",
              er_app_prepare_package_storage_source(&crypto,
                                                    &package_without_assets,
                                                    &app_retrieve_route,
                                                    &manifest_retrieve_route,
                                                    0,
                                                    &package_without_assets_source),
              1);
  check_hash_not_equal("app package storage source assets affect id",
                       &package_without_assets_source.source_id,
                       &storage_source.source_id);
  app_storage_response.retrieve_route_id =
      package_without_assets_source.app_retrieve_route_id;
  manifest_storage_response.retrieve_route_id =
      package_without_assets_source.manifest_retrieve_route_id;
  check_int64("app package storage object app without assets",
              er_app_prepare_package_storage_object(&app_storage_response,
                                                    &package_without_assets_source.app_retrieve_route_id,
                                                    &package_without_assets.app_object_id,
                                                    package_without_assets.app_object_len,
                                                    &app_storage_object),
              1);
  check_int64("app package storage object manifest without assets",
              er_app_prepare_package_storage_object(&manifest_storage_response,
                                                    &package_without_assets_source.manifest_retrieve_route_id,
                                                    &package_without_assets.manifest_object_id,
                                                    package_without_assets.manifest_object_len,
                                                    &manifest_storage_object),
              1);
  check_int64("app package storage load without assets",
              er_app_load_package_from_storage_source(&crypto,
                                                      &package_without_assets,
                                                      &package_without_assets_source,
                                                      &app_storage_object,
                                                      &manifest_storage_object,
                                                      0,
                                                      &loaded_package),
              1);
  check_uint64("app package storage load no assets len",
               loaded_package.ui_assets_len, 0u);
  check_int64("app package storage load reject extra assets",
              er_app_load_package_from_storage_source(&crypto,
                                                      &package_without_assets,
                                                      &package_without_assets_source,
                                                      &app_storage_object,
                                                      &manifest_storage_object,
                                                      &ui_assets_storage_object,
                                                      &loaded_package),
              0);
  check_int64("app package storage reject extra assets route",
              er_app_prepare_package_storage_source(&crypto,
                                                    &package_without_assets,
                                                    &app_retrieve_route,
                                                    &manifest_retrieve_route,
                                                    &ui_assets_retrieve_route,
                                                    &storage_source_again),
              0);
  bad_retrieve_route = app_retrieve_route;
  bad_retrieve_route.work_type = ER_WORK_TYPE_OBJECT_STORE;
  check_int64("app package storage reject store route",
              er_app_prepare_package_storage_source(&crypto, &package,
                                                    &bad_retrieve_route,
                                                    &manifest_retrieve_route,
                                                    &ui_assets_retrieve_route,
                                                    &storage_source_again),
              0);
  bad_retrieve_route = app_retrieve_route;
  bad_retrieve_route.department = ER_DEPARTMENT_RETRIEVAL;
  check_int64("app package storage reject wrong department",
              er_app_prepare_package_storage_source(&crypto, &package,
                                                    &bad_retrieve_route,
                                                    &manifest_retrieve_route,
                                                    &ui_assets_retrieve_route,
                                                    &storage_source_again),
              0);

  for (i = 0; i < ER_HASH_LEN; ++i) {
    app_object_id.bytes[i] = (UINT8)(0x10u + i);
    manifest_hash.bytes[i] = (UINT8)(0x30u + i);
    admission_id.bytes[i] = (UINT8)(0x50u + i);
    capability_id.bytes[i] = (UINT8)(0x70u + i);
    route_hash.bytes[i] = (UINT8)(0x90u + i);
    target_node_id.bytes[i] = (UINT8)(0xb0u + i);
    parent_relay_node_id.bytes[i] = (UINT8)(0xc0u + i);
    ui_relay_node_id.bytes[i] = (UINT8)(0xe0u + i);
    nonce[i] = (UINT8)(0xd0u + i);
  }

  check_int64("app identity reject short nonce",
              er_app_derive_identity(&crypto, &app_object_id, &manifest_hash, &admission_id,
                                     nonce, ER_APP_INSTANCE_NONCE_LEN - 1u, &identity),
              0);
  check_int64("app identity derive",
              er_app_derive_identity(&crypto, &app_object_id, &manifest_hash, &admission_id,
                                     nonce, ER_APP_INSTANCE_NONCE_LEN, &identity),
              1);
  check_int64("app identity abi", identity.abi_version, ER_APP_ABI_VERSION);
  check_int64("app identity nonce", identity.instance_nonce[0], 0xd0);
  check_int64("app identity from package",
              er_app_derive_identity_from_package(&crypto, &package, &admission_id,
                                                  nonce, ER_APP_INSTANCE_NONCE_LEN,
                                                  &identity),
              1);
  check_hash_equal("app identity package object", &identity.app_object_id,
                   &package.app_object_id);
  check_hash_equal("app identity package manifest", &identity.manifest_hash,
                   &package.manifest_object_id);

  check_int64("app ipc route",
              er_app_prepare_ipc_route_binding(&crypto, &identity, &target_node_id, &capability_id,
                                               &route_hash, 42u, ER_CAPABILITY_RISK_NONE, &binding),
              1);
  check_int64("app ipc abi", binding.abi_version, ER_APP_ABI_VERSION);
  check_int64("app ipc sealed", binding.seal_policy, ER_APP_SEAL_POLICY_REQUIRED);
  check_uint64("app ipc sequence", binding.sequence_base, 42u);
  check_uint64("app ipc risk", binding.capability_risk_flags, ER_CAPABILITY_RISK_NONE);

  check_int64("app ipc reject risky cap",
              er_app_prepare_ipc_route_binding(&crypto, &identity, &target_node_id, &capability_id,
                                               &route_hash, 42u, ER_CAPABILITY_RISK_RAW_DEVICE, &binding),
              0);

  identity.abi_version = 0;
  check_int64("app ipc reject abi",
              er_app_prepare_ipc_route_binding(&crypto, &identity, &target_node_id, &capability_id,
                                               &route_hash, 42u, ER_CAPABILITY_RISK_NONE, &binding),
              0);

  identity.abi_version = ER_APP_ABI_VERSION;
  check_int64("app budget reject opaque system",
              er_app_prepare_budget(&crypto, &identity, 99u, 1000u, 4096u, 1024u, 2048u, 4u, 4u, &budget),
              0);
  check_int64("app budget reject zero memory",
              er_app_prepare_budget(&crypto, &identity, ER_APP_KIND_USER, 1000u, 0u, 1024u, 2048u, 4u, 4u, &budget),
              0);
  check_int64("app budget prepare",
              er_app_prepare_budget(&crypto, &identity, ER_APP_KIND_USER, 1000u, 4096u, 1024u, 2048u, 4u, 4u, &budget),
              1);
  check_int64("app budget kind", budget.app_kind, ER_APP_KIND_USER);
  check_uint64("app budget cpu", budget.max_cpu_steps, 1000u);
  check_uint64("app budget memory", budget.max_memory_bytes, 4096u);

  check_int64("app usage init", er_app_usage_init(&identity, &budget, &usage), 1);
  check_int64("app usage cpu charge", er_app_usage_charge(&usage, &budget, ER_APP_BUDGET_CPU_STEP, 400u), 1);
  check_uint64("app usage cpu charged", usage.cpu_steps, 400u);
  check_int64("app usage cpu over budget", er_app_usage_charge(&usage, &budget, ER_APP_BUDGET_CPU_STEP, 601u), 0);
  check_uint64("app usage cpu unchanged", usage.cpu_steps, 400u);
  check_int64("app usage memory charge", er_app_usage_charge(&usage, &budget, ER_APP_BUDGET_MEMORY_BYTE, 4096u), 1);
  check_int64("app usage memory over budget", er_app_usage_charge(&usage, &budget, ER_APP_BUDGET_MEMORY_BYTE, 1u), 0);
  check_int64("app usage unknown resource", er_app_usage_charge(&usage, &budget, 0xffffffffu, 1u), 0);

  check_int64("app schedule slot",
              er_app_prepare_schedule_slot(&crypto, &identity, &budget, 7u, 11u, &slot),
              1);
  check_int64("app schedule abi", slot.abi_version, ER_APP_ABI_VERSION);
  check_uint64("app schedule tick", slot.deterministic_tick, 7u);
  check_uint64("app schedule sequence", slot.sequence, 11u);
  check_uint64("app schedule cpu quanta", slot.cpu_step_quanta, 1000u);
  check_uint64("app schedule memory limit", slot.memory_byte_limit, 4096u);

  check_int64("app launch reject short backing",
              er_app_prepare_launch_allocation(&crypto, &identity, &budget, 0x100000u, 4095u, &allocation),
              0);
  check_int64("app launch reject null backing",
              er_app_prepare_launch_allocation(&crypto, &identity, &budget, 0u, 4096u, &allocation),
              0);
  check_int64("app launch allocation",
              er_app_prepare_launch_allocation(&crypto, &identity, &budget, 0x100000u, 4096u, &allocation),
              1);
  check_int64("app launch abi", allocation.abi_version, ER_APP_ABI_VERSION);
  check_uint64("app launch executor base", allocation.executor_memory_base, 0x100000u);
  check_uint64("app launch executor len", allocation.executor_memory_len, 4096u);
  check_uint64("app launch address base", allocation.app_address_base, ER_APP_ADDRESS_BASE);
  check_uint64("app launch address len", allocation.app_address_len, 4096u);

  check_int64("app execution jurisdiction",
              er_app_prepare_execution_jurisdiction(&crypto, &identity, &budget, &allocation,
                                                    &parent_relay_node_id, 0u, 1024u,
                                                    1024u, 1024u, &jurisdiction),
              1);
  check_int64("app execution abi", jurisdiction.abi_version, ER_APP_ABI_VERSION);
  check_node_id_equal("app execution parent relay", &jurisdiction.parent_relay_node_id,
                      &parent_relay_node_id);
  check_node_id_equal("app execution app node", &jurisdiction.app_node_id,
                      &identity.app_node_id);
  check_uint64("app execution address len", jurisdiction.app_address_len, 4096u);
  check_uint64("app execution inbox base", jurisdiction.public_inbox_base, 0u);
  check_uint64("app execution inbox len", jurisdiction.public_inbox_len, 1024u);
  check_uint64("app execution outbox base", jurisdiction.public_outbox_base, 1024u);
  check_uint64("app execution outbox len", jurisdiction.public_outbox_len, 1024u);
  check_int64("app execution reject overlap",
              er_app_prepare_execution_jurisdiction(&crypto, &identity, &budget, &allocation,
                                                    &parent_relay_node_id, 0u, 2048u,
                                                    1024u, 1024u, &jurisdiction),
              0);
  check_int64("app execution reject outbox outside",
              er_app_prepare_execution_jurisdiction(&crypto, &identity, &budget, &allocation,
                                                    &parent_relay_node_id, 0u, 1024u,
                                                    4096u, 1u, &jurisdiction),
              0);

  scene_budget.rects = 2u;
  scene_budget.hits = 1u;
  scene_budget.drag_sources = 0u;
  scene_budget.drop_targets = 0u;
  scene_budget.transitions = 1u;
  scene_budget.icon_quads = 1u;
  scene_budget.text_quads = 3u;
  check_int64("app ui presentation prepare",
              er_app_prepare_ui_presentation(&crypto, &jurisdiction, &ui_relay_node_id,
                                             &route_hash, scene_budget, 12u, &presentation),
              1);
  check_int64("app ui presentation abi", presentation.abi_version, ER_APP_ABI_VERSION);
  check_node_id_equal("app ui presentation app", &presentation.app_node_id,
                      &identity.app_node_id);
  check_node_id_equal("app ui presentation relay", &presentation.ui_relay_node_id,
                      &ui_relay_node_id);
  check_uint64("app ui presentation text budget", presentation.max_text_quads, 3u);
  scene_stats.rects = 2u;
  scene_stats.hits = 1u;
  scene_stats.drag_sources = 0u;
  scene_stats.drop_targets = 0u;
  scene_stats.transitions = 1u;
  scene_stats.clips = 100u;
  scene_stats.icon_quads = 1u;
  scene_stats.text_quads = 3u;
  check_int64("app ui scene fits presentation",
              er_app_ui_scene_fits_presentation(scene_stats, &presentation), 1);
  scene_stats.text_quads = 4u;
  check_int64("app ui scene rejects over text budget",
              er_app_ui_scene_fits_presentation(scene_stats, &presentation), 0);
  scene_stats.text_quads = 3u;
  scene_stats.rects = 3u;
  check_int64("app ui scene rejects over rect budget",
              er_app_ui_scene_fits_presentation(scene_stats, &presentation), 0);
  scene_budget.rects = 0u;
  scene_budget.hits = 0u;
  scene_budget.drag_sources = 0u;
  scene_budget.drop_targets = 0u;
  scene_budget.transitions = 0u;
  scene_budget.icon_quads = 0u;
  scene_budget.text_quads = 0u;
  check_int64("app ui presentation reject zero budget",
              er_app_prepare_ui_presentation(&crypto, &jurisdiction, &ui_relay_node_id,
                                             &route_hash, scene_budget, 12u, &presentation),
              0);

  er_mem_zero(parent_relay_node_id.bytes, ER_NODE_ID_LEN);
  check_int64("app execution reject zero parent",
              er_app_prepare_execution_jurisdiction(&crypto, &identity, &budget, &allocation,
                                                    &parent_relay_node_id, 0u, 1024u,
                                                    1024u, 1024u, &jurisdiction),
              0);
}
