#include "efi_boot_internal.h"

static UINT8 g_ui_boot_app_memory[ER_UI_BOOT_APP_SLOT_CAPACITY][ER_UI_BOOT_APP_MEMORY_BYTES];
static UINT8 g_ui_boot_app_module_memory[ER_UI_BOOT_APP_SLOT_CAPACITY][ER_UI_BOOT_APP_MODULE_BYTES];
static UINT8 g_ui_boot_app_manifest_memory[ER_UI_BOOT_APP_SLOT_CAPACITY][ER_UI_BOOT_APP_MANIFEST_BYTES];
static const UINT8 g_ui_boot_package_signature_part_a[] =
    "edgerun:c:v1:boot:package-signature:a";
static const UINT8 g_ui_boot_package_signature_part_b[] =
    "edgerun:c:v1:boot:package-signature:b";
static const UINT8 g_ui_boot_package_signer_key[ER_PUBLIC_KEY_LEN] = {
  0x45u, 0x52u, 0x57u, 0x43u, 0x2du, 0x42u, 0x4fu, 0x4fu,
  0x54u, 0x2du, 0x50u, 0x4bu, 0x47u, 0x2du, 0x53u, 0x49u,
  0x47u, 0x4eu, 0x45u, 0x52u, 0x2du, 0x56u, 0x30u, 0x30u,
  0x30u, 0x30u, 0x30u, 0x30u, 0x30u, 0x30u, 0x30u, 0x31u
};

static ErUiBootInstalledApp g_ui_boot_installed_apps[ER_UI_BOOT_INSTALLED_APP_COUNT] = {
  {
    .app_bytes = g_edgerun_user_app_wasm,
    .app_len = ER_USER_APP_WASM_SIZE,
    .manifest_bytes = g_edgerun_user_app_manifest,
    .manifest_len = ER_USER_APP_MANIFEST_SIZE
  }
};

static ErAppSignedPackageIndexEntry g_ui_boot_installed_package_index[ER_UI_BOOT_INSTALLED_APP_COUNT];
static ErAppPackageInstallRecord g_ui_boot_installed_package_records[ER_UI_BOOT_INSTALLED_APP_COUNT];
static char g_ui_boot_package_hash_labels[ER_UI_BOOT_INSTALLED_APP_COUNT][ER_UI_BOOT_PACKAGE_HASH_LABEL_BYTES];
static char g_ui_boot_package_provenance_labels[ER_UI_BOOT_INSTALLED_APP_COUNT][ER_UI_BOOT_PROVENANCE_LABEL_BYTES];
static UINT8 g_ui_boot_installed_apps_prepared;

enum {
  ER_UI_BOOT_PACKAGE_APP_SEQUENCE = 1u,
  ER_UI_BOOT_PACKAGE_MANIFEST_SEQUENCE = 2u,
  ER_UI_BOOT_PACKAGE_SIGNATURE_ALGORITHM = 1u
};

static char er_ui_boot_hex_char(UINT8 value) {
  static const char digits[] = "0123456789abcdef";
  return digits[value & 0x0fu];
}

static UINT8 er_ui_boot_bytes_hex(const UINT8* bytes, UINTN byte_len, char* out, UINTN out_len) {
  UINTN i;

  if (bytes == 0 || out == 0 || byte_len != ER_HASH_LEN ||
      out_len != ER_UI_BOOT_HASH_HEX_BYTES + 1u) {
    return 0u;
  }
  for (i = 0u; i < byte_len; ++i) {
    out[i * 2u] = er_ui_boot_hex_char((UINT8)(bytes[i] >> 4u));
    out[i * 2u + 1u] = er_ui_boot_hex_char(bytes[i]);
  }
  out[ER_UI_BOOT_HASH_HEX_BYTES] = '\0';
  return 1u;
}

static UINT8 er_ui_boot_prefixed_hash_label(const char* prefix,
                                            UINTN prefix_len,
                                            const ErHash* hash,
                                            char* out,
                                            UINTN out_len) {
  UINTN i;

  if (prefix == 0 || hash == 0 || out == 0 ||
      out_len != prefix_len + ER_UI_BOOT_HASH_HEX_BYTES + 1u) {
    return 0u;
  }
  for (i = 0u; i < prefix_len; ++i) {
    out[i] = prefix[i];
  }
  return er_ui_boot_bytes_hex(hash->bytes, ER_HASH_LEN, out + prefix_len,
                              out_len - prefix_len);
}

static UINT8 er_ui_boot_prefixed_bytes_label(const char* prefix,
                                             UINTN prefix_len,
                                             const UINT8* bytes,
                                             UINTN byte_len,
                                             char* out,
                                             UINTN out_len) {
  UINTN i;

  if (prefix == 0 || bytes == 0 || out == 0 ||
      out_len != prefix_len + ER_UI_BOOT_HASH_HEX_BYTES + 1u) {
    return 0u;
  }
  for (i = 0u; i < prefix_len; ++i) {
    out[i] = prefix[i];
  }
  return er_ui_boot_bytes_hex(bytes, byte_len, out + prefix_len,
                              out_len - prefix_len);
}

static UINT8 er_ui_boot_launcher_status_from_install_state(
    UINT32 install_state,
    er_ui_launcher_app_status_t* out_status) {
  if (out_status == 0) {
    return 0u;
  }
  switch (install_state) {
    case ER_APP_PACKAGE_INSTALL_STATE_INSTALLED:
      *out_status = ER_UI_LAUNCHER_APP_INSTALLED;
      return 1u;
    case ER_APP_PACKAGE_INSTALL_STATE_REMOVED:
      *out_status = ER_UI_LAUNCHER_APP_REMOVED;
      return 1u;
    case ER_APP_PACKAGE_INSTALL_STATE_ROLLED_BACK:
      *out_status = ER_UI_LAUNCHER_APP_ROLLED_BACK;
      return 1u;
    default:
      return 0u;
  }
}

static UINT8 er_ui_boot_package_signer_identity(ErIdentity* out_identity) {
  return er_identity_prepare(ER_IDENTITY_TYPE_PUBLIC_KEY,
                             ER_IDENTITY_BACKING_ED25519,
                             g_ui_boot_package_signer_key,
                             (UINT16)sizeof(g_ui_boot_package_signer_key),
                             out_identity);
}

static UINT8 er_ui_boot_package_signature_hash(const UINT8* domain,
                                               UINTN domain_len,
                                               const ErIdentity* signer,
                                               const ErByteSpan* preimage,
                                               ErHash* out_hash) {
  ErByteSpan spans[2];

  if (domain == 0 || signer == 0 || preimage == 0 || preimage->bytes == 0 ||
      preimage->len == 0u || out_hash == 0 ||
      er_identity_valid(signer) == 0u) {
    return 0u;
  }
  spans[0].bytes = signer->material;
  spans[0].len = signer->material_len;
  spans[1] = *preimage;
  return er_crypto_blake3_hash(0, domain, domain_len, spans, 2u, out_hash);
}

static UINT8 er_ui_boot_package_sign(void* ctx, const ErByteSpan* preimage,
                                     ErWorkSignature* out_signature) {
  ErIdentity signer;
  ErHash signature_a;
  ErHash signature_b;

  (void)ctx;
  if (out_signature == 0 ||
      er_ui_boot_package_signer_identity(&signer) == 0u ||
      er_ui_boot_package_signature_hash(g_ui_boot_package_signature_part_a,
                                        (UINTN)(sizeof(g_ui_boot_package_signature_part_a) - 1u),
                                        &signer,
                                        preimage,
                                        &signature_a) == 0u ||
      er_ui_boot_package_signature_hash(g_ui_boot_package_signature_part_b,
                                        (UINTN)(sizeof(g_ui_boot_package_signature_part_b) - 1u),
                                        &signer,
                                        preimage,
                                        &signature_b) == 0u) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_signature, (UINTN)sizeof(*out_signature));
  out_signature->algorithm = ER_UI_BOOT_PACKAGE_SIGNATURE_ALGORITHM;
  out_signature->signature_len = ER_SIGNATURE_LEN;
  out_signature->identity = signer;
  er_mem_copy(out_signature->signature, signature_a.bytes, ER_HASH_LEN);
  er_mem_copy(out_signature->signature + ER_HASH_LEN, signature_b.bytes,
              ER_HASH_LEN);
  return 1u;
}

static UINT8 er_ui_boot_package_verify(void* ctx, const ErIdentity* identity,
                                       const ErByteSpan* preimage,
                                       const ErWorkSignature* signature) {
  ErWorkSignature expected;
  ErIdentity signer;

  (void)ctx;
  if (identity == 0 || signature == 0 ||
      er_ui_boot_package_signer_identity(&signer) == 0u ||
      er_identity_equal(identity, &signer) == 0u ||
      er_ui_boot_package_sign(0, preimage, &expected) == 0u ||
      signature->algorithm != expected.algorithm ||
      signature->signature_len != expected.signature_len ||
      er_identity_equal(&signature->identity, &expected.identity) == 0u ||
      er_mem_equal(signature->signature, expected.signature,
                   ER_SIGNATURE_LEN) == 0u) {
    return 0u;
  }
  return 1u;
}

static void er_ui_boot_package_crypto_provider(ErCryptoProvider* out_provider) {
  if (out_provider == 0) {
    return;
  }
  er_crypto_blake3_provider(out_provider);
  out_provider->sign = er_ui_boot_package_sign;
  out_provider->verify = er_ui_boot_package_verify;
}

static UINT8 er_ui_boot_seed_package_object_store(const ErCryptoProvider* crypto,
                                                  const ErAdmittedRoute* route,
                                                  const ErVfsObjectPacket* packet,
                                                  UINT64 sequence,
                                                  ErStorageEndpointObjectStore* store) {
  ErChannelEnvelopeHeader envelope;

  if (er_ui_boot_prepare_route_envelope(route, &packet->header.packet_id,
                                        sequence, &envelope) == 0u) {
    return 0u;
  }
  return er_storage_endpoint_store_object_packet(crypto, route, &envelope,
                                                 packet, store, 0);
}

static UINT8 er_ui_boot_prepare_installed_app_descriptor(ErUiBootInstalledApp* installed_app) {
  ErCryptoProvider crypto;

  if (installed_app == 0 ||
      installed_app->app_bytes == 0 ||
      installed_app->manifest_bytes == 0 ||
      installed_app->app_len == 0u ||
      installed_app->manifest_len == 0u) {
    return 0u;
  }
  er_crypto_blake3_provider(&crypto);
  if (er_vfs_prepare_object_ref(&crypto, installed_app->app_bytes,
                                installed_app->app_len,
                                &installed_app->app_ref) == 0u ||
      er_vfs_prepare_object_ref(&crypto, installed_app->manifest_bytes,
                                installed_app->manifest_len,
                                &installed_app->manifest_ref) == 0u ||
      er_app_prepare_package_manifest_from_objects(&crypto,
                                                   &installed_app->app_ref,
                                                   &installed_app->manifest_ref,
                                                   0,
                                                   &installed_app->package) == 0u) {
    return 0u;
  }
  return 1u;
}

static UINT8 er_ui_boot_prepare_installed_app_registry(void) {
  ErCryptoProvider crypto;
  ErUiBootInstalledPackageSource source;
  ErAppPackageIndexEntry index_entry;
  UINT32 i;

  if (g_ui_boot_installed_apps_prepared != 0u) {
    return 1u;
  }
  er_ui_boot_package_crypto_provider(&crypto);
  for (i = 0u; i < ER_UI_BOOT_INSTALLED_APP_COUNT; ++i) {
    if (er_ui_boot_prepare_installed_app_descriptor(&g_ui_boot_installed_apps[i]) == 0u ||
        er_ui_boot_prepare_installed_package_source(&g_ui_boot_installed_apps[i],
                                                    i, &source) == 0u ||
        er_app_prepare_package_index_entry(&crypto,
                                           &g_ui_boot_installed_apps[i].package,
                                           &g_ui_boot_installed_apps[i].app_ref,
                                           &g_ui_boot_installed_apps[i].manifest_ref,
                                           0,
                                           &source.storage_source,
                                           i,
                                           &index_entry) == 0u ||
        er_app_prepare_signed_package_index_entry(&crypto,
                                                  &index_entry,
                                                  &source.package_signature,
                                                  &g_ui_boot_installed_package_index[i]) == 0u ||
        er_app_prepare_package_install_record(&crypto,
                                              ER_APP_PACKAGE_INSTALL_STATE_INSTALLED,
                                              1u,
                                              &g_ui_boot_installed_package_index[i],
                                              0,
                                              &g_ui_boot_installed_package_records[i]) == 0u) {
      return 0u;
    }
  }
  g_ui_boot_installed_apps_prepared = 1u;
  return 1u;
}

static UINT8 er_ui_boot_installed_signed_package_index_entry_valid(
    const ErAppSignedPackageIndexEntry* index_entry) {
  ErCryptoProvider crypto;
  const ErUiBootInstalledApp* installed_app;
  const ErAppPackageIndexEntry* unsigned_entry;

  er_ui_boot_package_crypto_provider(&crypto);
  if (index_entry == 0 ||
      er_app_signed_package_index_entry_valid(&crypto, index_entry) == 0u ||
      index_entry->index_entry.installed_slot >= ER_UI_BOOT_INSTALLED_APP_COUNT) {
    return 0u;
  }
  unsigned_entry = &index_entry->index_entry;
  installed_app = &g_ui_boot_installed_apps[unsigned_entry->installed_slot];
  if (er_hash_equal(&unsigned_entry->package.package_id,
                    &installed_app->package.package_id) == 0u ||
      er_hash_equal(&unsigned_entry->app_ref.object_id,
                    &installed_app->app_ref.object_id) == 0u ||
      unsigned_entry->app_ref.object_len != installed_app->app_ref.object_len ||
      er_hash_equal(&unsigned_entry->manifest_ref.object_id,
                    &installed_app->manifest_ref.object_id) == 0u ||
      unsigned_entry->manifest_ref.object_len != installed_app->manifest_ref.object_len) {
    return 0u;
  }
  return 1u;
}

UINT8 er_ui_boot_append_wasm_scene(er_ui_scene_t* scene, const er_ui_scene_t* wasm_scene) {
  size_t i;

  if (scene == 0 || wasm_scene == 0) {
    return 0u;
  }
  for (i = 0u; i < wasm_scene->rect_count; ++i) {
    if (er_ui_scene_push_rect(scene, wasm_scene->rects[i]) != ER_UI_OK) {
      return 0u;
    }
  }
  for (i = 0u; i < wasm_scene->hit_count; ++i) {
    if (er_ui_scene_push_hit(scene, wasm_scene->hits[i]) != ER_UI_OK) {
      return 0u;
    }
  }
  for (i = 0u; i < wasm_scene->drag_source_count; ++i) {
    if (er_ui_scene_push_drag_source(scene, wasm_scene->drag_sources[i]) != ER_UI_OK) {
      return 0u;
    }
  }
  for (i = 0u; i < wasm_scene->drop_target_count; ++i) {
    if (er_ui_scene_push_drop_target(scene, wasm_scene->drop_targets[i]) != ER_UI_OK) {
      return 0u;
    }
  }
  for (i = 0u; i < wasm_scene->transition_count; ++i) {
    if (er_ui_scene_push_transition(scene, wasm_scene->transitions[i]) != ER_UI_OK) {
      return 0u;
    }
  }
  for (i = 0u; i < wasm_scene->icon_quad_count; ++i) {
    if (er_ui_scene_push_icon_quad(scene, wasm_scene->icon_quads[i]) != ER_UI_OK) {
      return 0u;
    }
  }
  for (i = 0u; i < wasm_scene->text_quad_count; ++i) {
    if (er_ui_scene_push_text_quad(scene, wasm_scene->text_quads[i]) != ER_UI_OK) {
      return 0u;
    }
  }
  return 1u;
}

UINT8 er_ui_boot_app_seed(UINT8 seed, UINT32 app_index) {
  return (UINT8)(seed + (UINT8)(app_index * ER_UI_WASM_APP_SEED_STRIDE));
}

void er_ui_boot_prepare_wasm_presentation(const er_ui_scene_budget_t* scene_budget,
                                                 UINT32 app_index,
                                                 ErAppUiPresentation* out_presentation) {
  if (scene_budget == 0 || out_presentation == 0) {
    return;
  }
  er_mem_zero((UINT8*)out_presentation, (UINTN)sizeof(*out_presentation));
  out_presentation->abi_version = ER_APP_ABI_VERSION;
  er_fill_nonzero_bytes(out_presentation->presentation_id.bytes, ER_HASH_LEN,
                        er_ui_boot_app_seed(ER_UI_WASM_PRESENTATION_ID_SEED, app_index));
  er_fill_nonzero_bytes(out_presentation->jurisdiction_id.bytes, ER_HASH_LEN,
                        er_ui_boot_app_seed(ER_UI_WASM_JURISDICTION_ID_SEED, app_index));
  er_fill_nonzero_bytes(out_presentation->admission_id.bytes, ER_HASH_LEN,
                        er_ui_boot_app_seed(ER_UI_WASM_ADMISSION_ID_SEED, app_index));
  er_fill_nonzero_bytes(out_presentation->app_node_id.bytes, ER_NODE_ID_LEN,
                        er_ui_boot_app_seed(ER_UI_WASM_APP_NODE_ID_SEED, app_index));
  er_fill_nonzero_bytes(out_presentation->ui_relay_node_id.bytes, ER_NODE_ID_LEN,
                        er_ui_boot_app_seed(ER_UI_WASM_RELAY_NODE_ID_SEED, app_index));
  er_fill_nonzero_bytes(out_presentation->route_hash.bytes, ER_HASH_LEN,
                        er_ui_boot_app_seed(ER_UI_WASM_ROUTE_HASH_SEED, app_index));
  out_presentation->sequence = ER_UI_WASM_PRESENTATION_SEQUENCE + (UINT64)app_index;
  out_presentation->max_rects = (UINT64)scene_budget->rects;
  out_presentation->max_hits = (UINT64)scene_budget->hits;
  out_presentation->max_drag_sources = (UINT64)scene_budget->drag_sources;
  out_presentation->max_drop_targets = (UINT64)scene_budget->drop_targets;
  out_presentation->max_transitions = (UINT64)scene_budget->transitions;
  out_presentation->max_icon_quads = (UINT64)scene_budget->icon_quads;
  out_presentation->max_text_quads = (UINT64)scene_budget->text_quads;
}

UINT8 er_ui_boot_execute_wasm_app(ErUiWasmAppRuntime* runtime) {
  INT64 main_result = 0;

  if (runtime == 0) {
    return 0u;
  }
  if (er_ui_wasm_app_execute(runtime, &main_result) != 0 ||
      main_result != (INT64)(UINT64)ER_UI_WASM_COUNTER_PACKET_BYTES) {
    return 0u;
  }
  er_print("ui renderer: wasm app scene rects=");
  er_print_u64_dec((UINT64)runtime->emitted_stats.rects);
  er_print(" hits=");
  er_print_u64_dec((UINT64)runtime->emitted_stats.hits);
  er_print(" text=");
  er_print_u64_dec((UINT64)runtime->emitted_stats.text_quads);
  er_println("");
  return 1u;
}

const ErUiBootInstalledApp* er_ui_boot_installed_app_for_slot(UINT32 app_index) {
  if (app_index >= ER_UI_BOOT_INSTALLED_APP_COUNT ||
      er_ui_boot_prepare_installed_app_registry() == 0u) {
    return 0;
  }
  return &g_ui_boot_installed_apps[app_index];
}

const ErAppSignedPackageIndexEntry* er_ui_boot_installed_signed_package_index_entry_for_slot(UINT32 app_index) {
  if (app_index >= ER_UI_BOOT_INSTALLED_APP_COUNT ||
      er_ui_boot_prepare_installed_app_registry() == 0u) {
    return 0;
  }
  return &g_ui_boot_installed_package_index[app_index];
}

const ErAppPackageInstallRecord* er_ui_boot_installed_package_record_for_slot(UINT32 app_index) {
  if (app_index >= ER_UI_BOOT_INSTALLED_APP_COUNT ||
      er_ui_boot_prepare_installed_app_registry() == 0u) {
    return 0;
  }
  return &g_ui_boot_installed_package_records[app_index];
}

UINT8 er_ui_boot_user_app_surface_id(UINT32 app_index, UINT32* out_surface_id) {
  if (out_surface_id == 0 || app_index >= ER_UI_BOOT_INSTALLED_APP_COUNT) {
    return 0u;
  }
  *out_surface_id = ER_UI_BOOT_USER_APP_SURFACE_ID_BASE + app_index;
  return 1u;
}

UINT8 er_ui_boot_user_app_launch_id(UINT32 app_index, UINT32* out_launch_id) {
  if (out_launch_id == 0 || app_index >= ER_UI_BOOT_INSTALLED_APP_COUNT) {
    return 0u;
  }
  *out_launch_id = ER_UI_BOOT_USER_APP_LAUNCH_ID_BASE + app_index;
  return 1u;
}

UINT8 er_ui_boot_install_shell_launcher_apps(er_ui_ledger_app_state_t* ledger_state) {
  UINT32 i;

  if (ledger_state == 0 || er_ui_boot_prepare_installed_app_registry() == 0u) {
    return 0u;
  }
  for (i = 0u; i < ER_UI_BOOT_INSTALLED_APP_COUNT; ++i) {
    const ErAppPackageInstallRecord* record = er_ui_boot_installed_package_record_for_slot(i);
    er_ui_launcher_app_status_t status;
    UINT32 surface_id;
    UINT32 launch_id;
    er_ui_launcher_app_t app;

    if (record == 0 ||
        er_ui_boot_launcher_status_from_install_state(record->install_state,
                                                      &status) == 0u ||
        er_ui_boot_user_app_surface_id(i, &surface_id) == 0u ||
        er_ui_boot_user_app_launch_id(i, &launch_id) == 0u ||
        er_ui_boot_prefixed_hash_label("pkg:",
                                       4u,
                                       &record->current_entry.index_entry.package.package_id,
                                       g_ui_boot_package_hash_labels[i],
                                       ER_UI_BOOT_PACKAGE_HASH_LABEL_BYTES) == 0u ||
        er_ui_boot_prefixed_bytes_label("signer:",
                                        7u,
                                        record->current_entry.package_signature.signature.identity.material,
                                        ER_HASH_LEN,
                                        g_ui_boot_package_provenance_labels[i],
                                        ER_UI_BOOT_PROVENANCE_LABEL_BYTES) == 0u) {
      return 0u;
    }
    app.launch_id = launch_id;
    app.surface_id = surface_id;
    app.name = "User App";
    app.status = status;
    app.package_hash = g_ui_boot_package_hash_labels[i];
    app.provenance = g_ui_boot_package_provenance_labels[i];
    app.permissions = "ui,storage";
    if (er_ui_shell_add_launcher_app(&ledger_state->shell, app) != ER_UI_OK) {
      return 0u;
    }
  }
  return 1u;
}

UINT8 er_ui_boot_prepare_signed_indexed_package_source(
    const ErAppSignedPackageIndexEntry* index_entry,
    ErUiBootInstalledPackageSource* out_source) {
  if (er_ui_boot_prepare_installed_app_registry() == 0u ||
      er_ui_boot_installed_signed_package_index_entry_valid(index_entry) == 0u) {
    return 0u;
  }
  if (er_ui_boot_prepare_installed_package_source(
          &g_ui_boot_installed_apps[index_entry->index_entry.installed_slot],
          index_entry->index_entry.installed_slot, out_source) == 0u) {
    return 0u;
  }
  out_source->package_signature = index_entry->package_signature;
  return 1u;
}

UINT8 er_ui_boot_prepare_package_record_source(
    const ErAppPackageInstallRecord* record,
    ErUiBootInstalledPackageSource* out_source) {
  ErCryptoProvider crypto;

  er_ui_boot_package_crypto_provider(&crypto);
  if (er_ui_boot_prepare_installed_app_registry() == 0u ||
      er_app_package_install_record_loadable(&crypto, record) == 0u) {
    return 0u;
  }
  return er_ui_boot_prepare_signed_indexed_package_source(&record->current_entry,
                                                         out_source);
}

UINT8 er_ui_boot_prepare_remote_package_fetch_source(
    const ErAppSignedPackageIndexEntry* index_entry,
    const ErIdentity* remote_identity,
    const ErHash* app_route_receipt_hash,
    const ErHash* manifest_route_receipt_hash,
    const ErHash* ui_assets_route_receipt_hash,
    ErAppPackageRemoteFetchSource* out_source) {
  ErCryptoProvider crypto;

  er_ui_boot_package_crypto_provider(&crypto);
  if (er_ui_boot_prepare_installed_app_registry() == 0u ||
      er_ui_boot_installed_signed_package_index_entry_valid(index_entry) == 0u) {
    return 0u;
  }
  return er_app_prepare_remote_package_fetch_source(
      &crypto, &index_entry->index_entry.package, remote_identity,
      app_route_receipt_hash, manifest_route_receipt_hash,
      ui_assets_route_receipt_hash, out_source);
}

UINT8 er_ui_boot_prepare_remote_package_install_record(
    const ErAppSignedPackageIndexEntry* index_entry,
    const ErAppPackageRemoteFetchSource* remote_source,
    const ErAppSignedPackageIndexEntry* previous_entry,
    UINT64 generation,
    ErAppPackageInstallRecord* out_record) {
  ErCryptoProvider crypto;

  er_ui_boot_package_crypto_provider(&crypto);
  if (er_ui_boot_prepare_installed_app_registry() == 0u ||
      er_ui_boot_installed_signed_package_index_entry_valid(index_entry) == 0u) {
    return 0u;
  }
  return er_app_prepare_remote_package_install_record(
      &crypto, generation, index_entry, remote_source, previous_entry,
      out_record);
}

UINT8 er_ui_boot_package_install_record_loadable(
    const ErAppPackageInstallRecord* record) {
  ErCryptoProvider crypto;

  er_ui_boot_package_crypto_provider(&crypto);
  return er_app_package_install_record_loadable(&crypto, record);
}

UINT8 er_ui_boot_prepare_installed_package_source(const ErUiBootInstalledApp* installed_app,
                                                  UINT32 app_index,
                                                  ErUiBootInstalledPackageSource* out_source) {
  ErCryptoProvider crypto;
  ErVfsObjectRef actual_app_ref;
  ErVfsObjectRef actual_manifest_ref;
  ErAppPackageManifest expected_package;
  ErIdentity signer;

  if (installed_app == 0 || out_source == 0 ||
      installed_app->app_bytes == 0 ||
      installed_app->manifest_bytes == 0 ||
      installed_app->app_len == 0u ||
      installed_app->manifest_len == 0u ||
      installed_app->app_ref.abi_version != ER_VFS_ABI_VERSION ||
      installed_app->manifest_ref.abi_version != ER_VFS_ABI_VERSION ||
      installed_app->package.abi_version != ER_APP_ABI_VERSION) {
    return 0u;
  }
  er_ui_boot_package_crypto_provider(&crypto);
  er_mem_zero((UINT8*)out_source, (UINTN)sizeof(*out_source));
  if (er_vfs_prepare_object_ref(&crypto, installed_app->app_bytes,
                                installed_app->app_len, &actual_app_ref) == 0u ||
      er_vfs_prepare_object_ref(&crypto, installed_app->manifest_bytes,
                                installed_app->manifest_len,
                                &actual_manifest_ref) == 0u ||
      actual_app_ref.object_len != installed_app->app_ref.object_len ||
      actual_manifest_ref.object_len != installed_app->manifest_ref.object_len ||
      er_hash_equal(&actual_app_ref.object_id,
                    &installed_app->app_ref.object_id) == 0u ||
      er_hash_equal(&actual_manifest_ref.object_id,
                    &installed_app->manifest_ref.object_id) == 0u ||
      er_app_prepare_package_manifest_from_objects(&crypto,
                                                   &installed_app->app_ref,
                                                   &installed_app->manifest_ref,
                                                   0,
                                                   &expected_package) == 0u ||
      er_hash_equal(&expected_package.package_id,
                    &installed_app->package.package_id) == 0u ||
      er_ui_boot_prepare_storage_retrieve_route(ER_UI_WASM_STORAGE_APP_ROUTE_ID_SEED,
                                                app_index, &out_source->app_route) == 0u ||
      er_ui_boot_prepare_storage_retrieve_route(ER_UI_WASM_STORAGE_MANIFEST_ROUTE_ID_SEED,
                                                app_index, &out_source->manifest_route) == 0u ||
      er_app_prepare_package_storage_source(&crypto, &installed_app->package,
                                            &out_source->app_route,
                                            &out_source->manifest_route, 0,
                                            &out_source->storage_source) == 0u ||
      er_ui_boot_package_signer_identity(&signer) == 0u ||
      er_app_sign_package(&crypto, &installed_app->package, &signer,
                          &out_source->package_signature) == 0u ||
      er_app_verify_package_signature(&crypto, &installed_app->package,
                                      &out_source->package_signature) == 0u) {
    return 0u;
  }
  out_source->installed_app = installed_app;
  return 1u;
}

UINT8 er_ui_boot_load_installed_package_source(const ErUiBootInstalledPackageSource* source,
                                               UINT8* module_memory,
                                               UINT32 module_memory_size,
                                               UINT8* manifest_memory,
                                               UINT32 manifest_memory_size,
                                               ErUiBootPackageStorage* storage,
                                               ErAppLoadedPackage* out_loaded) {
  ErCryptoProvider crypto;
  const ErUiBootInstalledApp* installed_app;
  ErVfsObjectPacket app_packet;
  ErVfsObjectPacket manifest_packet;
  ErAppPackageStorageResponse app_response;
  ErAppPackageStorageResponse manifest_response;
  ErAppPackageStorageObject app_object;
  ErAppPackageStorageObject manifest_object;

  if (source == 0 || source->installed_app == 0 ||
      module_memory == 0 || manifest_memory == 0 || storage == 0 ||
      out_loaded == 0 || module_memory_size == 0u || manifest_memory_size == 0u) {
    return 0u;
  }
  installed_app = source->installed_app;
  if (source->storage_source.abi_version != ER_APP_ABI_VERSION ||
      installed_app->app_bytes == 0 ||
      installed_app->manifest_bytes == 0 ||
      installed_app->app_len == 0u ||
      installed_app->manifest_len == 0u ||
      installed_app->app_ref.abi_version != ER_VFS_ABI_VERSION ||
      installed_app->manifest_ref.abi_version != ER_VFS_ABI_VERSION ||
      installed_app->package.abi_version != ER_APP_ABI_VERSION) {
    return 0u;
  }
  er_ui_boot_package_crypto_provider(&crypto);
  if (er_app_verify_package_signature(&crypto, &installed_app->package,
                                      &source->package_signature) == 0u) {
    return 0u;
  }
  if (er_storage_endpoint_object_store_init(&storage->app_store,
                                            storage->app_packets,
                                            ER_UI_BOOT_PACKAGE_OBJECT_PACKET_CAPACITY) == 0u ||
      er_storage_endpoint_object_store_init(&storage->manifest_store,
                                            storage->manifest_packets,
                                            ER_UI_BOOT_PACKAGE_OBJECT_PACKET_CAPACITY) == 0u) {
    return 0u;
  }
  if (er_vfs_prepare_object_packet(&crypto, installed_app->app_bytes,
                                   installed_app->app_len, 0u, 0u, 1u,
                                   &app_packet) == 0u) {
    return 0u;
  }
  if (er_vfs_prepare_object_packet(&crypto, installed_app->manifest_bytes,
                                   installed_app->manifest_len,
                                   0u, 0u, 1u, &manifest_packet) == 0u) {
    return 0u;
  }
  if (er_ui_boot_seed_package_object_store(&crypto, &source->app_route, &app_packet,
                                           ER_UI_BOOT_PACKAGE_APP_SEQUENCE,
                                           &storage->app_store) == 0u ||
      er_ui_boot_seed_package_object_store(&crypto, &source->manifest_route,
                                           &manifest_packet,
                                           ER_UI_BOOT_PACKAGE_MANIFEST_SEQUENCE,
                                           &storage->manifest_store) == 0u ||
      er_storage_endpoint_prepare_package_storage_response(&crypto,
                                                           &storage->app_store,
                                                           &source->storage_source.app_retrieve_route_id,
                                                           &installed_app->package.app_object_id,
                                                           installed_app->package.app_object_len,
                                                           module_memory,
                                                           module_memory_size,
                                                           &app_response) == 0u ||
      er_storage_endpoint_prepare_package_storage_response(&crypto,
                                                           &storage->manifest_store,
                                                           &source->storage_source.manifest_retrieve_route_id,
                                                           &installed_app->package.manifest_object_id,
                                                           installed_app->package.manifest_object_len,
                                                           manifest_memory,
                                                           manifest_memory_size,
                                                           &manifest_response) == 0u ||
      er_app_prepare_package_storage_object(&app_response,
                                            &source->storage_source.app_retrieve_route_id,
                                            &installed_app->package.app_object_id,
                                            installed_app->package.app_object_len,
                                            &app_object) == 0u ||
      er_app_prepare_package_storage_object(&manifest_response,
                                            &source->storage_source.manifest_retrieve_route_id,
                                            &installed_app->package.manifest_object_id,
                                            installed_app->package.manifest_object_len,
                                            &manifest_object) == 0u) {
    return 0u;
  }
  return er_app_load_package_from_storage_source(&crypto, &installed_app->package,
                                                 &source->storage_source, &app_object,
                                                 &manifest_object, 0,
                                                 out_loaded);
}

UINT8 er_ui_boot_load_installed_app_package(const ErUiBootInstalledApp* installed_app,
                                            UINT8* module_memory,
                                            UINT32 module_memory_size,
                                            UINT8* manifest_memory,
                                            UINT32 manifest_memory_size,
                                            ErUiBootPackageStorage* storage,
                                            UINT32 app_index,
                                            ErAppLoadedPackage* out_loaded) {
  ErUiBootInstalledPackageSource source;

  if (er_ui_boot_prepare_installed_package_source(installed_app, app_index,
                                                  &source) == 0u) {
    return 0u;
  }
  return er_ui_boot_load_installed_package_source(&source,
                                                  module_memory,
                                                  module_memory_size,
                                                  manifest_memory,
                                                  manifest_memory_size,
                                                  storage,
                                                  out_loaded);
}

UINT8 er_ui_boot_load_user_app_package(UINT8* module_memory,
                                       UINT32 module_memory_size,
                                       UINT8* manifest_memory,
                                       UINT32 manifest_memory_size,
                                       ErUiBootPackageStorage* storage,
                                       UINT32 app_index,
                                       ErAppLoadedPackage* out_loaded) {
  ErUiBootInstalledPackageSource source;

  if (er_ui_boot_prepare_package_record_source(
          er_ui_boot_installed_package_record_for_slot(app_index),
          &source) == 0u) {
    return 0u;
  }
  return er_ui_boot_load_installed_package_source(&source,
                                                  module_memory,
                                                  module_memory_size,
                                                  manifest_memory,
                                                  manifest_memory_size,
                                                  storage,
                                                  out_loaded);
}

UINT8 er_ui_boot_prepare_user_app(ErUiWasmAppRuntime* runtime,
                                  ErUiBootPackageStorage* storage,
                                  ErAppUiPresentation* presentation,
                                  er_ui_scene_t* wasm_scene,
                                  UINT8* memory,
                                  UINT32 memory_size,
                                  UINT8* module_memory,
                                  UINT32 module_memory_size,
                                  UINT8* manifest_memory,
                                  UINT32 manifest_memory_size,
                                  UINT32 app_index,
                                  const er_ui_scene_budget_t* scene_budget) {
  ErAppLoadedPackage loaded_package;

  if (runtime == 0 || storage == 0 || presentation == 0 ||
      wasm_scene == 0 || memory == 0 || module_memory == 0 ||
      manifest_memory == 0 || memory_size == 0u ||
      module_memory_size == 0u || manifest_memory_size == 0u || scene_budget == 0) {
    return 0u;
  }
  if (er_ui_boot_load_user_app_package(module_memory, module_memory_size,
                                       manifest_memory, manifest_memory_size,
                                       storage,
                                       app_index, &loaded_package) == 0u) {
    return 0u;
  }
  er_ui_boot_prepare_wasm_presentation(scene_budget, app_index, presentation);
  er_mem_zero((UINT8*)runtime, (UINTN)sizeof(*runtime));
  runtime->memory = memory;
  runtime->memory_size = memory_size;
  runtime->relay_inbox_base = ER_UI_WASM_RELAY_INBOX_BASE;
  runtime->relay_inbox_len = ER_UI_WASM_RELAY_INBOX_BYTES;
  runtime->relay_outbox_base = ER_UI_WASM_RELAY_OUTBOX_BASE;
  runtime->relay_outbox_len = ER_UI_WASM_RELAY_OUTBOX_BYTES;
  runtime->presentation = presentation;
  runtime->scene = wasm_scene;
  runtime->input_epoch_modifier.tick_stride = ER_UI_WASM_PS2_INPUT_EPOCH_STRIDE;
  runtime->execute_epoch_modifier.tick_stride = ER_UI_WASM_EXECUTE_EPOCH_STRIDE;
  if (loaded_package.app_len == 0u ||
      loaded_package.app_len > (UINTN)module_memory_size) {
    return 0u;
  }
  if (er_ui_wasm_app_prepare(loaded_package.app_bytes,
                             (UINT32)loaded_package.app_len,
                             &g_host_calls, runtime) != 0) {
    return 0u;
  }
  return er_ui_boot_execute_wasm_app(runtime);
}

void er_ui_boot_destroy_app_contexts(ErUiBootAppContext* apps, UINT32 app_count) {
  UINT32 i;

  if (apps == 0) {
    return;
  }
  for (i = 0u; i < app_count; ++i) {
    er_ui_scene_destroy(&apps[i].scene);
    er_mem_zero((UINT8*)&apps[i], (UINTN)sizeof(apps[i]));
  }
}

UINT8 er_ui_boot_prepare_app_contexts(ErUiBootAppContext* apps,
                                             UINT32 app_count,
                                             const er_ui_scene_budget_t* scene_budget,
                                             er_ui_color4_t clear) {
  UINT32 i;

  if (apps == 0 || app_count == 0u || scene_budget == 0 ||
      app_count > ER_UI_BOOT_APP_SLOT_CAPACITY) {
    return 0u;
  }
  for (i = 0u; i < app_count; ++i) {
    er_mem_zero((UINT8*)&apps[i], (UINTN)sizeof(apps[i]));
    if (er_ui_scene_init_with_allocator(&apps[i].scene, clear,
                                        er_ui_boot_allocator()) != ER_UI_OK) {
      er_ui_boot_destroy_app_contexts(apps, i);
      return 0u;
    }
    if (er_ui_boot_prepare_user_app(&apps[i].runtime,
                                    &apps[i].storage,
                                    &apps[i].presentation,
                                    &apps[i].scene,
                                    g_ui_boot_app_memory[i],
                                    ER_UI_BOOT_APP_MEMORY_BYTES,
                                    g_ui_boot_app_module_memory[i],
                                    ER_UI_BOOT_APP_MODULE_BYTES,
                                    g_ui_boot_app_manifest_memory[i],
                                    ER_UI_BOOT_APP_MANIFEST_BYTES,
                                    i,
                                    scene_budget) == 0u) {
      er_ui_boot_destroy_app_contexts(apps, i + 1u);
      return 0u;
    }
    apps[i].ready = 1u;
  }
  return 1u;
}
