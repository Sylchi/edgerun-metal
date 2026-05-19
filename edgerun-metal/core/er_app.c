#include "er_app.h"
#include "er_identity.h"
#include "er_mem.h"

/*
 * Purpose: derive app and IPC identities from runtime hashes.
 * Intention: make app routing content-addressed and admission-bound; locality grants no authority.
 */

static const UINT8 g_app_node_domain[] = "edgerun:c:v1:app:node-id";
static const UINT8 g_app_route_domain[] = "edgerun:c:v1:app:ipc-route";
static const UINT8 g_app_session_domain[] = "edgerun:c:v1:app:ipc-session";
static const UINT8 g_app_budget_domain[] = "edgerun:c:v1:app:budget";
static const UINT8 g_app_schedule_domain[] = "edgerun:c:v1:app:schedule-slot";
static const UINT8 g_app_launch_allocation_domain[] = "edgerun:c:v1:app:launch-allocation";
static const UINT8 g_app_execution_jurisdiction_domain[] = "edgerun:c:v1:app:execution-jurisdiction";
static const UINT8 g_app_ui_presentation_domain[] = "edgerun:c:v1:app:ui-presentation";
static const UINT8 g_app_package_domain[] = "edgerun:c:v1:app:package";
static const UINT8 g_app_package_signature_domain[] = "edgerun:c:v1:app:package-signature";
static const UINT8 g_app_package_storage_source_domain[] = "edgerun:c:v1:app:package-storage-source";

enum {
  ER_APP_BYTE_BITS = 8u,
  ER_APP_BYTE_MASK = 0xffu,
  ER_APP_U16_FIELD_BYTES = 2u,
  ER_APP_U64_FIELD_BYTES = 8u,
  ER_APP_BUDGET_U64_FIELD_COUNT = 6u,
  ER_APP_BUDGET_FIELD_BYTES = ER_APP_U16_FIELD_BYTES + (ER_APP_U64_FIELD_BYTES * ER_APP_BUDGET_U64_FIELD_COUNT),
  ER_APP_PACKAGE_U64_FIELD_COUNT = 3u,
  ER_APP_PACKAGE_FIELD_BYTES =
      ER_APP_U16_FIELD_BYTES + (ER_APP_U64_FIELD_BYTES * ER_APP_PACKAGE_U64_FIELD_COUNT),
  ER_APP_PACKAGE_SPAN_COUNT = 4u,
  ER_APP_PACKAGE_FIELDS_SPAN = 0u,
  ER_APP_PACKAGE_APP_OBJECT_SPAN = 1u,
  ER_APP_PACKAGE_MANIFEST_OBJECT_SPAN = 2u,
  ER_APP_PACKAGE_UI_ASSETS_OBJECT_SPAN = 3u,
  ER_APP_PACKAGE_STORAGE_SPAN_COUNT = 4u,
  ER_APP_PACKAGE_STORAGE_PACKAGE_SPAN = 0u,
  ER_APP_PACKAGE_STORAGE_APP_ROUTE_SPAN = 1u,
  ER_APP_PACKAGE_STORAGE_MANIFEST_ROUTE_SPAN = 2u,
  ER_APP_PACKAGE_STORAGE_UI_ASSETS_ROUTE_SPAN = 3u,
  ER_APP_IDENTITY_HASH_SPAN_COUNT = 4u,
  ER_APP_IDENTITY_APP_OBJECT_SPAN = 0u,
  ER_APP_IDENTITY_MANIFEST_SPAN = 1u,
  ER_APP_IDENTITY_ADMISSION_SPAN = 2u,
  ER_APP_IDENTITY_NONCE_SPAN = 3u,
  ER_APP_IDENTITY_BUDGET_SPAN_COUNT = 4u,
  ER_APP_IDENTITY_BUDGET_NODE_SPAN = 0u,
  ER_APP_IDENTITY_BUDGET_ADMISSION_SPAN = 1u,
  ER_APP_IDENTITY_BUDGET_ID_SPAN = 2u,
  ER_APP_IDENTITY_BUDGET_FIELDS_SPAN = 3u,
  ER_APP_BUDGET_HASH_SPAN_COUNT = 4u,
  ER_APP_BUDGET_HASH_APP_OBJECT_SPAN = 0u,
  ER_APP_BUDGET_HASH_MANIFEST_SPAN = 1u,
  ER_APP_BUDGET_HASH_ADMISSION_SPAN = 2u,
  ER_APP_BUDGET_HASH_FIELDS_SPAN = 3u,
  ER_APP_ROUTE_BINDING_SPAN_COUNT = 5u,
  ER_APP_ROUTE_SOURCE_SPAN = 0u,
  ER_APP_ROUTE_TARGET_SPAN = 1u,
  ER_APP_ROUTE_CAPABILITY_SPAN = 2u,
  ER_APP_ROUTE_HASH_SPAN = 3u,
  ER_APP_ROUTE_SEQUENCE_SPAN = 4u,
  ER_APP_SESSION_SPAN_COUNT = 3u,
  ER_APP_SESSION_ADMISSION_SPAN = 0u,
  ER_APP_SESSION_ROUTE_SPAN = 1u,
  ER_APP_SESSION_NONCE_SPAN = 2u,
  ER_APP_EXECUTION_SPAN_COUNT = 5u,
  ER_APP_EXECUTION_PARENT_RELAY_SPAN = 0u,
  ER_APP_EXECUTION_APP_NODE_SPAN = 1u,
  ER_APP_EXECUTION_ADMISSION_SPAN = 2u,
  ER_APP_EXECUTION_BUDGET_SPAN = 3u,
  ER_APP_EXECUTION_FIELDS_SPAN = 4u,
  ER_APP_PACKED_FIELD0_OFFSET = 0u,
  ER_APP_PACKED_FIELD1_OFFSET = 8u,
  ER_APP_PACKED_FIELD2_OFFSET = 16u,
  ER_APP_PACKED_FIELD3_OFFSET = 24u,
  ER_APP_PACKED_U64_FIELD_COUNT = 4u,
  ER_APP_PACKED_U64_FIELDS_BYTES = ER_APP_U64_FIELD_BYTES * ER_APP_PACKED_U64_FIELD_COUNT,
  ER_APP_EXECUTION_U64_FIELD_COUNT = 6u,
  ER_APP_EXECUTION_U64_FIELDS_BYTES = ER_APP_U64_FIELD_BYTES * ER_APP_EXECUTION_U64_FIELD_COUNT,
  ER_APP_EXECUTION_ALLOCATION_OFFSET = 0u,
  ER_APP_EXECUTION_ADDRESS_BASE_OFFSET = 32u,
  ER_APP_EXECUTION_ADDRESS_LEN_OFFSET = 40u,
  ER_APP_EXECUTION_INBOX_BASE_OFFSET = 48u,
  ER_APP_EXECUTION_INBOX_LEN_OFFSET = 56u,
  ER_APP_EXECUTION_OUTBOX_BASE_OFFSET = 64u,
  ER_APP_EXECUTION_OUTBOX_LEN_OFFSET = 72u,
  ER_APP_UI_PRESENTATION_SPAN_COUNT = 5u,
  ER_APP_UI_PRESENTATION_JURISDICTION_SPAN = 0u,
  ER_APP_UI_PRESENTATION_APP_SPAN = 1u,
  ER_APP_UI_PRESENTATION_RELAY_SPAN = 2u,
  ER_APP_UI_PRESENTATION_ROUTE_SPAN = 3u,
  ER_APP_UI_PRESENTATION_FIELDS_SPAN = 4u,
  ER_APP_UI_PRESENTATION_U64_FIELD_COUNT = 8u,
  ER_APP_UI_PRESENTATION_U64_FIELDS_BYTES =
      ER_APP_U64_FIELD_BYTES * ER_APP_UI_PRESENTATION_U64_FIELD_COUNT,
  ER_APP_PACKAGE_SIGNATURE_PREIMAGE_BYTES =
      (UINTN)(sizeof(g_app_package_signature_domain) - 1u) + ER_HASH_LEN
};

static void er_app_put_be(UINT8* dst, UINT64 value, UINTN byte_count) {
  UINTN i;

  for (i = 0u; i < byte_count; ++i) {
    UINTN shift = (byte_count - 1u - i) * ER_APP_BYTE_BITS;
    dst[i] = (UINT8)((value >> shift) & ER_APP_BYTE_MASK);
  }
}

static void er_app_put_be16(UINT8* dst, UINT16 value) {
  er_app_put_be(dst, value, ER_APP_U16_FIELD_BYTES);
}

static void er_app_put_be64(UINT8* dst, UINT64 value) {
  er_app_put_be(dst, value, ER_APP_U64_FIELD_BYTES);
}

static void er_app_put_budget_field(UINT8** cursor, UINT64 value) {
  er_app_put_be64(*cursor, value);
  *cursor += ER_APP_U64_FIELD_BYTES;
}

static UINT8 er_app_add_overflows(UINT64 current, UINT64 amount) {
  return (UINT64)(current + amount) < current ? 1u : 0u;
}

static UINT8 er_app_label_ref_valid(const ErVfsObjectLabelRef* object_ref) {
  return (UINT8)(object_ref != 0 &&
                 object_ref->abi_version == ER_VFS_ABI_VERSION &&
                 object_ref->object_len != 0u &&
                 er_vfs_label_valid(object_ref->label, object_ref->label_len) != 0u &&
                 er_hash_nonzero(&object_ref->object_id) != 0u);
}

static UINT8 er_app_object_ref_valid(const ErVfsObjectRef* object_ref) {
  return (UINT8)(object_ref != 0 &&
                 object_ref->abi_version == ER_VFS_ABI_VERSION &&
                 object_ref->reserved == 0u &&
                 object_ref->object_len != 0u &&
                 er_hash_nonzero(&object_ref->object_id) != 0u);
}

static UINT8 er_app_empty_object_ref_valid(const ErVfsObjectRef* object_ref) {
  return (UINT8)(object_ref != 0 &&
                 object_ref->abi_version == 0u &&
                 object_ref->reserved == 0u &&
                 object_ref->object_len == 0u &&
                 er_hash_nonzero(&object_ref->object_id) == 0u);
}

static UINT8 er_app_object_ref_matches(const ErVfsObjectRef* object_ref,
                                       const ErHash* object_id,
                                       UINT64 object_len) {
  return (UINT8)(er_app_object_ref_valid(object_ref) != 0u &&
                 er_hash_equal(&object_ref->object_id, object_id) != 0u &&
                 object_ref->object_len == object_len);
}

static UINT8 er_app_scene_budget_nonzero(er_ui_scene_budget_t budget) {
  return (UINT8)(budget.rects != 0u ||
                 budget.hits != 0u ||
                 budget.drag_sources != 0u ||
                 budget.drop_targets != 0u ||
                 budget.transitions != 0u ||
                 budget.icon_quads != 0u ||
                 budget.text_quads != 0u);
}

static UINT8 er_app_package_hash(const ErCryptoProvider* crypto,
                                 const ErHash* app_object_id,
                                 UINT64 app_object_len,
                                 const ErHash* manifest_object_id,
                                 UINT64 manifest_object_len,
                                 const ErHash* ui_assets_object_id,
                                 UINT64 ui_assets_object_len,
                                 ErHash* out_package_id) {
  UINT8 fields[ER_APP_PACKAGE_FIELD_BYTES];
  UINT8* cursor = fields;
  ErByteSpan spans[ER_APP_PACKAGE_SPAN_COUNT];

  if (crypto == 0 || app_object_id == 0 || manifest_object_id == 0 ||
      ui_assets_object_id == 0 || out_package_id == 0) {
    return 0;
  }
  er_app_put_be16(cursor, ER_APP_KIND_USER);
  cursor += ER_APP_U16_FIELD_BYTES;
  er_app_put_budget_field(&cursor, app_object_len);
  er_app_put_budget_field(&cursor, manifest_object_len);
  er_app_put_budget_field(&cursor, ui_assets_object_len);

  spans[ER_APP_PACKAGE_FIELDS_SPAN].bytes = fields;
  spans[ER_APP_PACKAGE_FIELDS_SPAN].len = (UINTN)sizeof(fields);
  spans[ER_APP_PACKAGE_APP_OBJECT_SPAN].bytes = app_object_id->bytes;
  spans[ER_APP_PACKAGE_APP_OBJECT_SPAN].len = ER_HASH_LEN;
  spans[ER_APP_PACKAGE_MANIFEST_OBJECT_SPAN].bytes = manifest_object_id->bytes;
  spans[ER_APP_PACKAGE_MANIFEST_OBJECT_SPAN].len = ER_HASH_LEN;
  spans[ER_APP_PACKAGE_UI_ASSETS_OBJECT_SPAN].bytes = ui_assets_object_id->bytes;
  spans[ER_APP_PACKAGE_UI_ASSETS_OBJECT_SPAN].len = ER_HASH_LEN;
  return er_crypto_hash(crypto, g_app_package_domain,
                        (UINTN)(sizeof(g_app_package_domain) - 1u),
                        spans, ER_APP_PACKAGE_SPAN_COUNT, out_package_id);
}

static UINT8 er_app_package_manifest_valid(const ErCryptoProvider* crypto,
                                           const ErAppPackageManifest* package) {
  ErHash expected_package_id;

  if (package == 0 || package->abi_version != ER_APP_ABI_VERSION ||
      package->app_kind != ER_APP_KIND_USER ||
      er_hash_nonzero(&package->package_id) == 0u ||
      er_hash_nonzero(&package->app_object_id) == 0u ||
      er_hash_nonzero(&package->manifest_object_id) == 0u ||
      package->app_object_len == 0u ||
      package->manifest_object_len == 0u) {
    return 0;
  }
  if (package->ui_assets_object_len == 0u) {
    if (er_hash_nonzero(&package->ui_assets_object_id) != 0u) {
      return 0;
    }
  } else if (er_hash_nonzero(&package->ui_assets_object_id) == 0u) {
    return 0;
  }
  if (er_app_package_hash(crypto, &package->app_object_id,
                          package->app_object_len,
                          &package->manifest_object_id,
                          package->manifest_object_len,
                          &package->ui_assets_object_id,
                          package->ui_assets_object_len,
                          &expected_package_id) == 0u) {
    return 0;
  }
  return er_hash_equal(&expected_package_id, &package->package_id);
}

static UINT8 er_app_prepare_package_signature_preimage(
    const ErCryptoProvider* crypto,
    const ErAppPackageManifest* package,
    UINT8 out_preimage[ER_APP_PACKAGE_SIGNATURE_PREIMAGE_BYTES],
    ErByteSpan* out_span) {
  UINTN domain_len = (UINTN)(sizeof(g_app_package_signature_domain) - 1u);

  if (out_preimage == 0 || out_span == 0 ||
      er_app_package_manifest_valid(crypto, package) == 0u) {
    return 0u;
  }
  er_mem_copy(out_preimage, g_app_package_signature_domain, domain_len);
  er_mem_copy(out_preimage + domain_len, package->package_id.bytes,
              ER_HASH_LEN);
  out_span->bytes = out_preimage;
  out_span->len = ER_APP_PACKAGE_SIGNATURE_PREIMAGE_BYTES;
  return 1u;
}

static UINT8 er_app_load_package_object(const ErCryptoProvider* crypto,
                                        const ErAppPackageObjectLoad* load,
                                        const ErHash* expected_object_id,
                                        UINT64 expected_object_len,
                                        UINTN* out_len) {
  ErHash loaded_object_id;

  if (load == 0 || expected_object_id == 0 || out_len == 0 ||
      expected_object_len == 0u) {
    return 0;
  }
  if (er_vfs_assemble_object_packets(crypto, load->packets, load->packet_count,
                                     load->bytes, load->capacity, out_len,
                                     &loaded_object_id) == 0u ||
      *out_len != (UINTN)expected_object_len ||
      er_hash_equal(&loaded_object_id, expected_object_id) == 0u) {
    return 0;
  }
  return 1;
}

static UINT8 er_app_storage_retrieve_route_valid(const ErAdmittedRoute* route) {
  return (UINT8)(route != 0 &&
                 route->abi_version == ER_WORK_ABI_VERSION &&
                 route->role == ER_NODE_ROLE_STORAGE &&
                 route->department == ER_DEPARTMENT_STORAGE &&
                 route->work_type == ER_WORK_TYPE_OBJECT_RETRIEVE &&
                 route->admitted_budget != 0u &&
                 er_hash_nonzero(&route->route_id) != 0u &&
                 er_hash_nonzero(&route->request_hash) != 0u &&
                 er_hash_nonzero(&route->admission_hash) != 0u &&
                 er_node_id_nonzero(&route->source_node_id) != 0u &&
                 er_node_id_nonzero(&route->target_node_id) != 0u &&
                 er_node_id_nonzero(&route->relay_node_id) != 0u);
}

static UINT8 er_app_package_storage_source_id(const ErCryptoProvider* crypto,
                                              const ErHash* package_id,
                                              const ErHash* app_route_id,
                                              const ErHash* manifest_route_id,
                                              const ErHash* ui_assets_route_id,
                                              ErHash* out_source_id) {
  ErByteSpan spans[ER_APP_PACKAGE_STORAGE_SPAN_COUNT];

  if (crypto == 0 || package_id == 0 || app_route_id == 0 ||
      manifest_route_id == 0 || ui_assets_route_id == 0 ||
      out_source_id == 0) {
    return 0;
  }
  spans[ER_APP_PACKAGE_STORAGE_PACKAGE_SPAN].bytes = package_id->bytes;
  spans[ER_APP_PACKAGE_STORAGE_PACKAGE_SPAN].len = ER_HASH_LEN;
  spans[ER_APP_PACKAGE_STORAGE_APP_ROUTE_SPAN].bytes = app_route_id->bytes;
  spans[ER_APP_PACKAGE_STORAGE_APP_ROUTE_SPAN].len = ER_HASH_LEN;
  spans[ER_APP_PACKAGE_STORAGE_MANIFEST_ROUTE_SPAN].bytes =
      manifest_route_id->bytes;
  spans[ER_APP_PACKAGE_STORAGE_MANIFEST_ROUTE_SPAN].len = ER_HASH_LEN;
  spans[ER_APP_PACKAGE_STORAGE_UI_ASSETS_ROUTE_SPAN].bytes =
      ui_assets_route_id->bytes;
  spans[ER_APP_PACKAGE_STORAGE_UI_ASSETS_ROUTE_SPAN].len = ER_HASH_LEN;
  return er_crypto_hash(crypto, g_app_package_storage_source_domain,
                        (UINTN)(sizeof(g_app_package_storage_source_domain) - 1u),
                        spans, ER_APP_PACKAGE_STORAGE_SPAN_COUNT,
                        out_source_id);
}

static UINT8 er_app_package_storage_source_valid(const ErCryptoProvider* crypto,
                                                 const ErAppPackageManifest* package,
                                                 const ErAppPackageStorageSource* source) {
  ErHash expected_source_id;

  if (source == 0 ||
      source->abi_version != ER_APP_ABI_VERSION ||
      source->app_kind != ER_APP_KIND_USER ||
      er_app_package_manifest_valid(crypto, package) == 0u ||
      er_hash_equal(&source->package_id, &package->package_id) == 0u ||
      er_hash_nonzero(&source->app_retrieve_route_id) == 0u ||
      er_hash_nonzero(&source->manifest_retrieve_route_id) == 0u) {
    return 0;
  }
  if (package->ui_assets_object_len == 0u) {
    if (er_hash_nonzero(&source->ui_assets_retrieve_route_id) != 0u) {
      return 0;
    }
  } else if (er_hash_nonzero(&source->ui_assets_retrieve_route_id) == 0u) {
    return 0;
  }
  if (er_app_package_storage_source_id(crypto, &source->package_id,
                                       &source->app_retrieve_route_id,
                                       &source->manifest_retrieve_route_id,
                                       &source->ui_assets_retrieve_route_id,
                                       &expected_source_id) == 0u) {
    return 0;
  }
  return er_hash_equal(&source->source_id, &expected_source_id);
}

UINT8 er_app_package_index_entry_valid(const ErCryptoProvider* crypto,
                                       const ErAppPackageIndexEntry* entry) {
  if (entry == 0 ||
      entry->abi_version != ER_APP_ABI_VERSION ||
      entry->app_kind != ER_APP_KIND_USER ||
      er_app_package_manifest_valid(crypto, &entry->package) == 0u ||
      er_app_object_ref_matches(&entry->app_ref,
                                &entry->package.app_object_id,
                                entry->package.app_object_len) == 0u ||
      er_app_object_ref_matches(&entry->manifest_ref,
                                &entry->package.manifest_object_id,
                                entry->package.manifest_object_len) == 0u ||
      er_app_package_storage_source_valid(crypto, &entry->package,
                                          &entry->storage_source) == 0u) {
    return 0u;
  }
  if (entry->package.ui_assets_object_len == 0u) {
    return er_app_empty_object_ref_valid(&entry->ui_assets_ref);
  }
  return er_app_object_ref_matches(&entry->ui_assets_ref,
                                   &entry->package.ui_assets_object_id,
                                   entry->package.ui_assets_object_len);
}

UINT8 er_app_prepare_package_index_entry(const ErCryptoProvider* crypto,
                                         const ErAppPackageManifest* package,
                                         const ErVfsObjectRef* app_ref,
                                         const ErVfsObjectRef* manifest_ref,
                                         const ErVfsObjectRef* ui_assets_ref,
                                         const ErAppPackageStorageSource* storage_source,
                                         UINT32 installed_slot,
                                         ErAppPackageIndexEntry* out_entry) {
  if (out_entry == 0) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_entry, (UINTN)sizeof(*out_entry));
  out_entry->abi_version = ER_APP_ABI_VERSION;
  out_entry->app_kind = ER_APP_KIND_USER;
  out_entry->installed_slot = installed_slot;
  if (package != 0) {
    out_entry->package = *package;
  }
  if (app_ref != 0) {
    out_entry->app_ref = *app_ref;
  }
  if (manifest_ref != 0) {
    out_entry->manifest_ref = *manifest_ref;
  }
  if (ui_assets_ref != 0) {
    out_entry->ui_assets_ref = *ui_assets_ref;
  }
  if (storage_source != 0) {
    out_entry->storage_source = *storage_source;
  }
  return er_app_package_index_entry_valid(crypto, out_entry);
}

UINT8 er_app_prepare_package_manifest(const ErCryptoProvider* crypto,
                                      const ErVfsObjectLabelRef* app_object,
                                      const ErVfsObjectLabelRef* manifest_object,
                                      const ErVfsObjectLabelRef* ui_assets_object,
                                      ErAppPackageManifest* out_package) {
  ErVfsObjectRef app_ref;
  ErVfsObjectRef manifest_ref;
  ErVfsObjectRef ui_assets_ref;
  const ErVfsObjectRef* ui_assets_ref_ptr = 0;

  if (er_app_label_ref_valid(app_object) == 0u ||
      er_app_label_ref_valid(manifest_object) == 0u) {
    return 0;
  }
  if (er_vfs_prepare_object_ref_from_object(&app_object->object_id,
                                            app_object->object_len,
                                            &app_ref) == 0u ||
      er_vfs_prepare_object_ref_from_object(&manifest_object->object_id,
                                            manifest_object->object_len,
                                            &manifest_ref) == 0u) {
    return 0;
  }
  if (ui_assets_object != 0) {
    if (er_app_label_ref_valid(ui_assets_object) == 0u ||
        er_vfs_prepare_object_ref_from_object(&ui_assets_object->object_id,
                                              ui_assets_object->object_len,
                                              &ui_assets_ref) == 0u) {
      return 0;
    }
    ui_assets_ref_ptr = &ui_assets_ref;
  }
  return er_app_prepare_package_manifest_from_objects(crypto, &app_ref,
                                                      &manifest_ref,
                                                      ui_assets_ref_ptr,
                                                      out_package);
}

UINT8 er_app_prepare_package_manifest_from_objects(const ErCryptoProvider* crypto,
                                                   const ErVfsObjectRef* app_object,
                                                   const ErVfsObjectRef* manifest_object,
                                                   const ErVfsObjectRef* ui_assets_object,
                                                   ErAppPackageManifest* out_package) {
  ErHash zero_hash;
  const ErHash* ui_assets_object_id = &zero_hash;
  UINT64 ui_assets_object_len = 0u;

  if (crypto == 0 || out_package == 0 ||
      er_app_object_ref_valid(app_object) == 0u ||
      er_app_object_ref_valid(manifest_object) == 0u) {
    return 0;
  }
  if (ui_assets_object != 0) {
    if (er_app_object_ref_valid(ui_assets_object) == 0u) {
      return 0;
    }
    ui_assets_object_id = &ui_assets_object->object_id;
    ui_assets_object_len = ui_assets_object->object_len;
  }

  er_mem_zero((UINT8*)&zero_hash, (UINTN)sizeof(zero_hash));
  er_mem_zero((UINT8*)out_package, (UINTN)sizeof(*out_package));
  out_package->abi_version = ER_APP_ABI_VERSION;
  out_package->app_kind = ER_APP_KIND_USER;
  out_package->app_object_id = app_object->object_id;
  out_package->app_object_len = app_object->object_len;
  out_package->manifest_object_id = manifest_object->object_id;
  out_package->manifest_object_len = manifest_object->object_len;
  out_package->ui_assets_object_id = *ui_assets_object_id;
  out_package->ui_assets_object_len = ui_assets_object_len;

  return er_app_package_hash(crypto, &out_package->app_object_id,
                             out_package->app_object_len,
                             &out_package->manifest_object_id,
                             out_package->manifest_object_len,
                             &out_package->ui_assets_object_id,
                             out_package->ui_assets_object_len,
                             &out_package->package_id);
}

UINT8 er_app_sign_package(const ErCryptoProvider* crypto,
                          const ErAppPackageManifest* package,
                          const ErIdentity* signer,
                          ErAppPackageSignature* out_signature) {
  UINT8 preimage[ER_APP_PACKAGE_SIGNATURE_PREIMAGE_BYTES];
  ErByteSpan preimage_span;
  ErWorkSignature work_signature;

  if (out_signature == 0 || er_identity_valid(signer) == 0u ||
      er_app_prepare_package_signature_preimage(crypto, package, preimage,
                                               &preimage_span) == 0u ||
      er_crypto_sign(crypto, &preimage_span, &work_signature) == 0u ||
      er_identity_equal(&work_signature.identity, signer) == 0u ||
      work_signature.signature_len != ER_SIGNATURE_LEN) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_signature, (UINTN)sizeof(*out_signature));
  out_signature->abi_version = ER_APP_ABI_VERSION;
  out_signature->app_kind = ER_APP_KIND_USER;
  out_signature->package_id = package->package_id;
  out_signature->signer = *signer;
  out_signature->signature = work_signature;
  return 1u;
}

UINT8 er_app_verify_package_signature(const ErCryptoProvider* crypto,
                                      const ErAppPackageManifest* package,
                                      const ErAppPackageSignature* signature) {
  UINT8 preimage[ER_APP_PACKAGE_SIGNATURE_PREIMAGE_BYTES];
  ErByteSpan preimage_span;

  if (signature == 0 ||
      signature->abi_version != ER_APP_ABI_VERSION ||
      signature->app_kind != ER_APP_KIND_USER ||
      er_identity_valid(&signature->signer) == 0u ||
      er_hash_equal(&signature->package_id, &package->package_id) == 0u ||
      er_identity_equal(&signature->signer,
                        &signature->signature.identity) == 0u ||
      signature->signature.signature_len != ER_SIGNATURE_LEN ||
      er_app_prepare_package_signature_preimage(crypto, package, preimage,
                                               &preimage_span) == 0u) {
    return 0u;
  }
  return er_crypto_verify(crypto, &signature->signer, &preimage_span,
                          &signature->signature);
}

UINT8 er_app_load_package_objects(const ErCryptoProvider* crypto,
                                  const ErAppPackageManifest* package,
                                  const ErAppPackageObjectLoad* app_object,
                                  const ErAppPackageObjectLoad* manifest_object,
                                  const ErAppPackageObjectLoad* ui_assets_object,
                                  ErAppLoadedPackage* out_loaded) {
  UINTN app_len = 0u;
  UINTN manifest_len = 0u;
  UINTN ui_assets_len = 0u;

  if (crypto == 0 || out_loaded == 0 ||
      er_app_package_manifest_valid(crypto, package) == 0u) {
    return 0;
  }
  if (er_app_load_package_object(crypto, app_object, &package->app_object_id,
                                 package->app_object_len, &app_len) == 0u ||
      er_app_load_package_object(crypto, manifest_object,
                                 &package->manifest_object_id,
                                 package->manifest_object_len,
                                 &manifest_len) == 0u) {
    return 0;
  }
  if (package->ui_assets_object_len != 0u) {
    if (er_app_load_package_object(crypto, ui_assets_object,
                                   &package->ui_assets_object_id,
                                   package->ui_assets_object_len,
                                   &ui_assets_len) == 0u) {
      return 0;
    }
  } else if (ui_assets_object != 0) {
    return 0;
  }

  er_mem_zero((UINT8*)out_loaded, (UINTN)sizeof(*out_loaded));
  out_loaded->abi_version = ER_APP_ABI_VERSION;
  out_loaded->app_kind = ER_APP_KIND_USER;
  out_loaded->package_id = package->package_id;
  out_loaded->app_bytes = app_object->bytes;
  out_loaded->app_len = app_len;
  out_loaded->manifest_bytes = manifest_object->bytes;
  out_loaded->manifest_len = manifest_len;
  if (ui_assets_object != 0) {
    out_loaded->ui_assets_bytes = ui_assets_object->bytes;
    out_loaded->ui_assets_len = ui_assets_len;
  }
  return 1;
}

UINT8 er_app_prepare_package_storage_source(const ErCryptoProvider* crypto,
                                            const ErAppPackageManifest* package,
                                            const ErAdmittedRoute* app_route,
                                            const ErAdmittedRoute* manifest_route,
                                            const ErAdmittedRoute* ui_assets_route,
                                            ErAppPackageStorageSource* out_source) {
  ErHash zero_route_id;
  const ErHash* ui_assets_route_id = &zero_route_id;

  if (crypto == 0 || out_source == 0 ||
      er_app_package_manifest_valid(crypto, package) == 0u ||
      er_app_storage_retrieve_route_valid(app_route) == 0u ||
      er_app_storage_retrieve_route_valid(manifest_route) == 0u) {
    return 0;
  }
  er_mem_zero((UINT8*)&zero_route_id, (UINTN)sizeof(zero_route_id));
  if (package->ui_assets_object_len != 0u) {
    if (er_app_storage_retrieve_route_valid(ui_assets_route) == 0u) {
      return 0;
    }
    ui_assets_route_id = &ui_assets_route->route_id;
  } else if (ui_assets_route != 0) {
    return 0;
  }

  er_mem_zero((UINT8*)out_source, (UINTN)sizeof(*out_source));
  out_source->abi_version = ER_APP_ABI_VERSION;
  out_source->app_kind = ER_APP_KIND_USER;
  out_source->package_id = package->package_id;
  out_source->app_retrieve_route_id = app_route->route_id;
  out_source->manifest_retrieve_route_id = manifest_route->route_id;
  out_source->ui_assets_retrieve_route_id = *ui_assets_route_id;

  return er_app_package_storage_source_id(crypto, &out_source->package_id,
                                          &out_source->app_retrieve_route_id,
                                          &out_source->manifest_retrieve_route_id,
                                          &out_source->ui_assets_retrieve_route_id,
                                          &out_source->source_id);
}

UINT8 er_app_prepare_package_storage_object(const ErAppPackageStorageResponse* response,
                                            const ErHash* expected_route_id,
                                            const ErHash* expected_object_id,
                                            UINT64 expected_object_len,
                                            ErAppPackageStorageObject* out_object) {
  if (response == 0 || expected_route_id == 0 || expected_object_id == 0 ||
      out_object == 0 ||
      response->abi_version != ER_APP_ABI_VERSION ||
      response->object_len == 0u ||
      response->packet_count == 0u ||
      response->packets == 0 ||
      response->bytes == 0 ||
      response->capacity < response->object_len ||
      er_hash_equal(&response->retrieve_route_id, expected_route_id) == 0u ||
      er_hash_equal(&response->object_id, expected_object_id) == 0u ||
      response->object_len != expected_object_len) {
    return 0;
  }
  er_mem_zero((UINT8*)out_object, (UINTN)sizeof(*out_object));
  out_object->retrieve_route_id = response->retrieve_route_id;
  out_object->object.packets = response->packets;
  out_object->object.packet_count = response->packet_count;
  out_object->object.bytes = response->bytes;
  out_object->object.capacity = response->capacity;
  return 1;
}

UINT8 er_app_load_package_from_storage_source(const ErCryptoProvider* crypto,
                                              const ErAppPackageManifest* package,
                                              const ErAppPackageStorageSource* source,
                                              const ErAppPackageStorageObject* app_object,
                                              const ErAppPackageStorageObject* manifest_object,
                                              const ErAppPackageStorageObject* ui_assets_object,
                                              ErAppLoadedPackage* out_loaded) {
  const ErAppPackageObjectLoad* ui_assets_load = 0;

  if (app_object == 0 || manifest_object == 0 ||
      er_app_package_storage_source_valid(crypto, package, source) == 0u ||
      er_hash_equal(&app_object->retrieve_route_id,
                        &source->app_retrieve_route_id) == 0u ||
      er_hash_equal(&manifest_object->retrieve_route_id,
                        &source->manifest_retrieve_route_id) == 0u) {
    return 0;
  }
  if (package->ui_assets_object_len != 0u) {
    if (ui_assets_object == 0 ||
        er_hash_equal(&ui_assets_object->retrieve_route_id,
                          &source->ui_assets_retrieve_route_id) == 0u) {
      return 0;
    }
    ui_assets_load = &ui_assets_object->object;
  } else if (ui_assets_object != 0) {
    return 0;
  }
  return er_app_load_package_objects(crypto, package, &app_object->object,
                                     &manifest_object->object, ui_assets_load,
                                     out_loaded);
}

UINT8 er_app_derive_identity_from_package(const ErCryptoProvider* crypto,
                                          const ErAppPackageManifest* package,
                                          const ErHash* admission_id,
                                          const UINT8* instance_nonce,
                                          UINTN instance_nonce_len,
                                          ErAppIdentity* out_identity) {
  if (er_app_package_manifest_valid(crypto, package) == 0u) {
    return 0;
  }
  return er_app_derive_identity(crypto, &package->app_object_id,
                                &package->manifest_object_id,
                                admission_id, instance_nonce,
                                instance_nonce_len, out_identity);
}

static UINT8 er_app_scene_count_fits(UINT64 actual, UINT64 limit) {
  return (UINT8)(actual <= limit);
}

static void er_app_prepare_identity_budget_spans(const ErAppIdentity* identity, const ErAppBudget* budget,
                                                 const UINT8* fields, UINTN fields_len, ErByteSpan* spans) {
  spans[ER_APP_IDENTITY_BUDGET_NODE_SPAN].bytes = identity->app_node_id.bytes;
  spans[ER_APP_IDENTITY_BUDGET_NODE_SPAN].len = ER_NODE_ID_LEN;
  spans[ER_APP_IDENTITY_BUDGET_ADMISSION_SPAN].bytes = identity->admission_id.bytes;
  spans[ER_APP_IDENTITY_BUDGET_ADMISSION_SPAN].len = ER_HASH_LEN;
  spans[ER_APP_IDENTITY_BUDGET_ID_SPAN].bytes = budget->budget_id.bytes;
  spans[ER_APP_IDENTITY_BUDGET_ID_SPAN].len = ER_HASH_LEN;
  spans[ER_APP_IDENTITY_BUDGET_FIELDS_SPAN].bytes = fields;
  spans[ER_APP_IDENTITY_BUDGET_FIELDS_SPAN].len = fields_len;
}

UINT8 er_app_derive_identity(const ErCryptoProvider* crypto, const ErHash* app_object_id,
                             const ErHash* manifest_hash, const ErHash* admission_id,
                             const UINT8* instance_nonce, UINTN instance_nonce_len,
                             ErAppIdentity* out_identity) {
  ErHash app_node_hash;
  ErByteSpan spans[ER_APP_IDENTITY_HASH_SPAN_COUNT];

  if (crypto == 0 || app_object_id == 0 || manifest_hash == 0 || admission_id == 0 || out_identity == 0) {
    return 0;
  }
  if (instance_nonce_len != ER_APP_INSTANCE_NONCE_LEN || instance_nonce == 0) {
    return 0;
  }

  spans[ER_APP_IDENTITY_APP_OBJECT_SPAN].bytes = app_object_id->bytes;
  spans[ER_APP_IDENTITY_APP_OBJECT_SPAN].len = ER_HASH_LEN;
  spans[ER_APP_IDENTITY_MANIFEST_SPAN].bytes = manifest_hash->bytes;
  spans[ER_APP_IDENTITY_MANIFEST_SPAN].len = ER_HASH_LEN;
  spans[ER_APP_IDENTITY_ADMISSION_SPAN].bytes = admission_id->bytes;
  spans[ER_APP_IDENTITY_ADMISSION_SPAN].len = ER_HASH_LEN;
  spans[ER_APP_IDENTITY_NONCE_SPAN].bytes = instance_nonce;
  spans[ER_APP_IDENTITY_NONCE_SPAN].len = instance_nonce_len;
  if (er_crypto_hash(crypto, g_app_node_domain, (UINTN)(sizeof(g_app_node_domain) - 1u),
                     spans, ER_APP_IDENTITY_HASH_SPAN_COUNT, &app_node_hash) == 0u) {
    return 0;
  }

  er_mem_zero((UINT8*)out_identity, (UINTN)sizeof(*out_identity));
  out_identity->abi_version = ER_APP_ABI_VERSION;
  out_identity->app_object_id = *app_object_id;
  out_identity->manifest_hash = *manifest_hash;
  out_identity->admission_id = *admission_id;
  er_mem_copy(out_identity->instance_nonce, instance_nonce, ER_APP_INSTANCE_NONCE_LEN);
  er_mem_copy(out_identity->app_node_id.bytes, app_node_hash.bytes, ER_NODE_ID_LEN);
  return 1;
}

UINT8 er_app_prepare_ipc_route_binding(const ErCryptoProvider* crypto, const ErAppIdentity* source_app,
                                       const ErNodeId* target_node_id, const ErHash* capability_id,
                                       const ErHash* route_hash, UINT64 sequence_base,
                                       UINT32 capability_risk_flags, ErAppIpcRouteBinding* out_binding) {
  UINT8 sequence_be[ER_APP_U64_FIELD_BYTES];
  ErByteSpan route_spans[ER_APP_ROUTE_BINDING_SPAN_COUNT];
  ErByteSpan session_spans[ER_APP_SESSION_SPAN_COUNT];

  if (crypto == 0 || source_app == 0 || target_node_id == 0 || capability_id == 0 ||
      route_hash == 0 || out_binding == 0) {
    return 0;
  }
  if (source_app->abi_version != ER_APP_ABI_VERSION) {
    return 0;
  }
  if (capability_risk_flags != ER_CAPABILITY_RISK_NONE) {
    return 0;
  }

  er_mem_zero((UINT8*)out_binding, (UINTN)sizeof(*out_binding));
  out_binding->abi_version = ER_APP_ABI_VERSION;
  out_binding->seal_policy = ER_APP_SEAL_POLICY_REQUIRED;
  out_binding->admission_id = source_app->admission_id;
  out_binding->source_app_node_id = source_app->app_node_id;
  out_binding->target_node_id = *target_node_id;
  out_binding->capability_id = *capability_id;
  out_binding->route_hash = *route_hash;
  out_binding->sequence_base = sequence_base;
  out_binding->capability_risk_flags = capability_risk_flags;

  er_app_put_be64(sequence_be, sequence_base);
  route_spans[ER_APP_ROUTE_SOURCE_SPAN].bytes = source_app->app_node_id.bytes;
  route_spans[ER_APP_ROUTE_SOURCE_SPAN].len = ER_NODE_ID_LEN;
  route_spans[ER_APP_ROUTE_TARGET_SPAN].bytes = target_node_id->bytes;
  route_spans[ER_APP_ROUTE_TARGET_SPAN].len = ER_NODE_ID_LEN;
  route_spans[ER_APP_ROUTE_CAPABILITY_SPAN].bytes = capability_id->bytes;
  route_spans[ER_APP_ROUTE_CAPABILITY_SPAN].len = ER_HASH_LEN;
  route_spans[ER_APP_ROUTE_HASH_SPAN].bytes = route_hash->bytes;
  route_spans[ER_APP_ROUTE_HASH_SPAN].len = ER_HASH_LEN;
  route_spans[ER_APP_ROUTE_SEQUENCE_SPAN].bytes = sequence_be;
  route_spans[ER_APP_ROUTE_SEQUENCE_SPAN].len = (UINTN)sizeof(sequence_be);
  if (er_crypto_hash(crypto, g_app_route_domain, (UINTN)(sizeof(g_app_route_domain) - 1u),
                     route_spans, ER_APP_ROUTE_BINDING_SPAN_COUNT, &out_binding->route_binding_id) == 0u) {
    return 0;
  }

  session_spans[ER_APP_SESSION_ADMISSION_SPAN].bytes = source_app->admission_id.bytes;
  session_spans[ER_APP_SESSION_ADMISSION_SPAN].len = ER_HASH_LEN;
  session_spans[ER_APP_SESSION_ROUTE_SPAN].bytes = out_binding->route_binding_id.bytes;
  session_spans[ER_APP_SESSION_ROUTE_SPAN].len = ER_HASH_LEN;
  session_spans[ER_APP_SESSION_NONCE_SPAN].bytes = source_app->instance_nonce;
  session_spans[ER_APP_SESSION_NONCE_SPAN].len = ER_APP_INSTANCE_NONCE_LEN;
  return er_crypto_hash(crypto, g_app_session_domain, (UINTN)(sizeof(g_app_session_domain) - 1u),
                        session_spans, ER_APP_SESSION_SPAN_COUNT, &out_binding->session_id);
}

UINT8 er_app_prepare_budget(const ErCryptoProvider* crypto, const ErAppIdentity* identity,
                            UINT16 app_kind, UINT64 max_cpu_steps, UINT64 max_memory_bytes,
                            UINT64 max_packet_bytes, UINT64 max_storage_bytes,
                            UINT64 max_ipc_sends, UINT64 max_ipc_recvs,
                            ErAppBudget* out_budget) {
  UINT8 fields[ER_APP_BUDGET_FIELD_BYTES];
  UINT8* field_cursor = fields;
  ErByteSpan spans[ER_APP_IDENTITY_BUDGET_SPAN_COUNT];

  if (crypto == 0 || identity == 0 || out_budget == 0 || identity->abi_version != ER_APP_ABI_VERSION) {
    return 0;
  }
  if (app_kind != ER_APP_KIND_USER) {
    return 0;
  }
  if (max_cpu_steps == 0u || max_memory_bytes == 0u) {
    return 0;
  }

  er_mem_zero((UINT8*)out_budget, (UINTN)sizeof(*out_budget));
  out_budget->abi_version = ER_APP_ABI_VERSION;
  out_budget->app_kind = app_kind;
  out_budget->admission_id = identity->admission_id;
  out_budget->app_object_id = identity->app_object_id;
  out_budget->max_cpu_steps = max_cpu_steps;
  out_budget->max_memory_bytes = max_memory_bytes;
  out_budget->max_packet_bytes = max_packet_bytes;
  out_budget->max_storage_bytes = max_storage_bytes;
  out_budget->max_ipc_sends = max_ipc_sends;
  out_budget->max_ipc_recvs = max_ipc_recvs;

  er_app_put_be16(field_cursor, app_kind);
  field_cursor += ER_APP_U16_FIELD_BYTES;
  er_app_put_budget_field(&field_cursor, max_cpu_steps);
  er_app_put_budget_field(&field_cursor, max_memory_bytes);
  er_app_put_budget_field(&field_cursor, max_packet_bytes);
  er_app_put_budget_field(&field_cursor, max_storage_bytes);
  er_app_put_budget_field(&field_cursor, max_ipc_sends);
  er_app_put_budget_field(&field_cursor, max_ipc_recvs);

  spans[ER_APP_BUDGET_HASH_APP_OBJECT_SPAN].bytes = identity->app_object_id.bytes;
  spans[ER_APP_BUDGET_HASH_APP_OBJECT_SPAN].len = ER_HASH_LEN;
  spans[ER_APP_BUDGET_HASH_MANIFEST_SPAN].bytes = identity->manifest_hash.bytes;
  spans[ER_APP_BUDGET_HASH_MANIFEST_SPAN].len = ER_HASH_LEN;
  spans[ER_APP_BUDGET_HASH_ADMISSION_SPAN].bytes = identity->admission_id.bytes;
  spans[ER_APP_BUDGET_HASH_ADMISSION_SPAN].len = ER_HASH_LEN;
  spans[ER_APP_BUDGET_HASH_FIELDS_SPAN].bytes = fields;
  spans[ER_APP_BUDGET_HASH_FIELDS_SPAN].len = (UINTN)sizeof(fields);
  return er_crypto_hash(crypto, g_app_budget_domain, (UINTN)(sizeof(g_app_budget_domain) - 1u),
                        spans, ER_APP_BUDGET_HASH_SPAN_COUNT, &out_budget->budget_id);
}

UINT8 er_app_usage_init(const ErAppIdentity* identity, const ErAppBudget* budget, ErAppUsage* out_usage) {
  if (identity == 0 || budget == 0 || out_usage == 0 ||
      identity->abi_version != ER_APP_ABI_VERSION || budget->abi_version != ER_APP_ABI_VERSION) {
    return 0;
  }
  if (budget->app_kind != ER_APP_KIND_USER) {
    return 0;
  }

  er_mem_zero((UINT8*)out_usage, (UINTN)sizeof(*out_usage));
  out_usage->abi_version = ER_APP_ABI_VERSION;
  out_usage->budget_id = budget->budget_id;
  out_usage->app_node_id = identity->app_node_id;
  return 1;
}

UINT8 er_app_usage_charge(ErAppUsage* usage, const ErAppBudget* budget, UINT32 resource_kind, UINT64 amount) {
  UINT64* current = 0;
  UINT64 limit = 0;

  if (usage == 0 || budget == 0 || usage->abi_version != ER_APP_ABI_VERSION ||
      budget->abi_version != ER_APP_ABI_VERSION || amount == 0u) {
    return 0;
  }

  switch (resource_kind) {
    case ER_APP_BUDGET_CPU_STEP:
      current = &usage->cpu_steps;
      limit = budget->max_cpu_steps;
      break;
    case ER_APP_BUDGET_MEMORY_BYTE:
      current = &usage->memory_bytes;
      limit = budget->max_memory_bytes;
      break;
    case ER_APP_BUDGET_PACKET_BYTE:
      current = &usage->packet_bytes;
      limit = budget->max_packet_bytes;
      break;
    case ER_APP_BUDGET_STORAGE_BYTE:
      current = &usage->storage_bytes;
      limit = budget->max_storage_bytes;
      break;
    case ER_APP_BUDGET_IPC_SEND:
      current = &usage->ipc_sends;
      limit = budget->max_ipc_sends;
      break;
    case ER_APP_BUDGET_IPC_RECV:
      current = &usage->ipc_recvs;
      limit = budget->max_ipc_recvs;
      break;
    default:
      return 0;
  }

  if (limit == 0u || er_app_add_overflows(*current, amount) != 0u || *current + amount > limit) {
    return 0;
  }
  *current += amount;
  return 1;
}

UINT8 er_app_prepare_schedule_slot(const ErCryptoProvider* crypto, const ErAppIdentity* identity,
                                   const ErAppBudget* budget, UINT64 deterministic_tick,
                                   UINT64 sequence, ErAppScheduleSlot* out_slot) {
  UINT8 fields[ER_APP_PACKED_U64_FIELDS_BYTES];
  ErByteSpan spans[ER_APP_IDENTITY_BUDGET_SPAN_COUNT];

  if (crypto == 0 || identity == 0 || budget == 0 || out_slot == 0 ||
      identity->abi_version != ER_APP_ABI_VERSION || budget->abi_version != ER_APP_ABI_VERSION) {
    return 0;
  }
  if (budget->app_kind != ER_APP_KIND_USER || budget->max_cpu_steps == 0u || budget->max_memory_bytes == 0u) {
    return 0;
  }

  er_mem_zero((UINT8*)out_slot, (UINTN)sizeof(*out_slot));
  out_slot->abi_version = ER_APP_ABI_VERSION;
  out_slot->admission_id = identity->admission_id;
  out_slot->app_node_id = identity->app_node_id;
  out_slot->deterministic_tick = deterministic_tick;
  out_slot->sequence = sequence;
  out_slot->cpu_step_quanta = budget->max_cpu_steps;
  out_slot->memory_byte_limit = budget->max_memory_bytes;

  er_app_put_be64(&fields[ER_APP_PACKED_FIELD0_OFFSET], deterministic_tick);
  er_app_put_be64(&fields[ER_APP_PACKED_FIELD1_OFFSET], sequence);
  er_app_put_be64(&fields[ER_APP_PACKED_FIELD2_OFFSET], out_slot->cpu_step_quanta);
  er_app_put_be64(&fields[ER_APP_PACKED_FIELD3_OFFSET], out_slot->memory_byte_limit);
  er_app_prepare_identity_budget_spans(identity, budget, fields, (UINTN)sizeof(fields), spans);
  return er_crypto_hash(crypto, g_app_schedule_domain, (UINTN)(sizeof(g_app_schedule_domain) - 1u),
                        spans, ER_APP_IDENTITY_BUDGET_SPAN_COUNT, &out_slot->slot_id);
}

UINT8 er_app_prepare_launch_allocation(const ErCryptoProvider* crypto, const ErAppIdentity* identity,
                                       const ErAppBudget* budget, UINT64 executor_memory_base,
                                       UINT64 executor_memory_len, ErAppLaunchAllocation* out_allocation) {
  UINT8 fields[ER_APP_PACKED_U64_FIELDS_BYTES];
  ErByteSpan spans[ER_APP_IDENTITY_BUDGET_SPAN_COUNT];

  if (crypto == 0 || identity == 0 || budget == 0 || out_allocation == 0 ||
      identity->abi_version != ER_APP_ABI_VERSION || budget->abi_version != ER_APP_ABI_VERSION) {
    return 0;
  }
  if (budget->app_kind != ER_APP_KIND_USER || budget->max_memory_bytes == 0u ||
      executor_memory_base == 0u || executor_memory_len != budget->max_memory_bytes) {
    return 0;
  }

  er_mem_zero((UINT8*)out_allocation, (UINTN)sizeof(*out_allocation));
  out_allocation->abi_version = ER_APP_ABI_VERSION;
  out_allocation->admission_id = identity->admission_id;
  out_allocation->budget_id = budget->budget_id;
  out_allocation->app_node_id = identity->app_node_id;
  out_allocation->executor_memory_base = executor_memory_base;
  out_allocation->executor_memory_len = executor_memory_len;
  out_allocation->app_address_base = ER_APP_ADDRESS_BASE;
  out_allocation->app_address_len = budget->max_memory_bytes;

  er_app_put_be64(&fields[ER_APP_PACKED_FIELD0_OFFSET], executor_memory_base);
  er_app_put_be64(&fields[ER_APP_PACKED_FIELD1_OFFSET], executor_memory_len);
  er_app_put_be64(&fields[ER_APP_PACKED_FIELD2_OFFSET], out_allocation->app_address_base);
  er_app_put_be64(&fields[ER_APP_PACKED_FIELD3_OFFSET], out_allocation->app_address_len);
  er_app_prepare_identity_budget_spans(identity, budget, fields, (UINTN)sizeof(fields), spans);
  return er_crypto_hash(crypto, g_app_launch_allocation_domain,
                        (UINTN)(sizeof(g_app_launch_allocation_domain) - 1u),
                        spans, ER_APP_IDENTITY_BUDGET_SPAN_COUNT, &out_allocation->allocation_id);
}

UINT8 er_app_prepare_execution_jurisdiction(const ErCryptoProvider* crypto,
                                            const ErAppIdentity* identity,
                                            const ErAppBudget* budget,
                                            const ErAppLaunchAllocation* allocation,
                                            const ErNodeId* parent_relay_node_id,
                                            UINT64 public_inbox_base,
                                            UINT64 public_inbox_len,
                                            UINT64 public_outbox_base,
                                            UINT64 public_outbox_len,
                                            ErAppExecutionJurisdiction* out_jurisdiction) {
  UINT8 fields[ER_HASH_LEN + ER_APP_EXECUTION_U64_FIELDS_BYTES];
  ErByteSpan spans[ER_APP_EXECUTION_SPAN_COUNT];
  UINT64 app_address_end;
  UINT64 inbox_end;
  UINT64 outbox_end;

  if (crypto == 0 || identity == 0 || budget == 0 || allocation == 0 ||
      parent_relay_node_id == 0 || out_jurisdiction == 0 ||
      identity->abi_version != ER_APP_ABI_VERSION ||
      budget->abi_version != ER_APP_ABI_VERSION ||
      allocation->abi_version != ER_APP_ABI_VERSION ||
      budget->app_kind != ER_APP_KIND_USER ||
      er_node_id_nonzero(parent_relay_node_id) == 0u) {
    return 0;
  }
  if (er_hash_equal(&identity->admission_id, &budget->admission_id) == 0u ||
      er_hash_equal(&identity->admission_id, &allocation->admission_id) == 0u ||
      er_hash_equal(&budget->budget_id, &allocation->budget_id) == 0u ||
      er_node_id_equal(&identity->app_node_id, &allocation->app_node_id) == 0u) {
    return 0;
  }
  if (allocation->app_address_base != ER_APP_ADDRESS_BASE ||
      allocation->app_address_len != budget->max_memory_bytes ||
      allocation->executor_memory_len != budget->max_memory_bytes ||
      allocation->app_address_len == 0u ||
      public_inbox_len == 0u || public_outbox_len == 0u) {
    return 0;
  }
  app_address_end = allocation->app_address_base + allocation->app_address_len;
  inbox_end = public_inbox_base + public_inbox_len;
  outbox_end = public_outbox_base + public_outbox_len;
  if (app_address_end < allocation->app_address_base ||
      inbox_end < public_inbox_base ||
      outbox_end < public_outbox_base ||
      public_inbox_base < allocation->app_address_base ||
      public_outbox_base < allocation->app_address_base ||
      inbox_end > app_address_end ||
      outbox_end > app_address_end ||
      (public_inbox_base < outbox_end && public_outbox_base < inbox_end)) {
    return 0;
  }

  er_mem_copy(&fields[ER_APP_EXECUTION_ALLOCATION_OFFSET], allocation->allocation_id.bytes, ER_HASH_LEN);
  er_app_put_be64(&fields[ER_APP_EXECUTION_ADDRESS_BASE_OFFSET], allocation->app_address_base);
  er_app_put_be64(&fields[ER_APP_EXECUTION_ADDRESS_LEN_OFFSET], allocation->app_address_len);
  er_app_put_be64(&fields[ER_APP_EXECUTION_INBOX_BASE_OFFSET], public_inbox_base);
  er_app_put_be64(&fields[ER_APP_EXECUTION_INBOX_LEN_OFFSET], public_inbox_len);
  er_app_put_be64(&fields[ER_APP_EXECUTION_OUTBOX_BASE_OFFSET], public_outbox_base);
  er_app_put_be64(&fields[ER_APP_EXECUTION_OUTBOX_LEN_OFFSET], public_outbox_len);

  spans[ER_APP_EXECUTION_PARENT_RELAY_SPAN].bytes = parent_relay_node_id->bytes;
  spans[ER_APP_EXECUTION_PARENT_RELAY_SPAN].len = ER_NODE_ID_LEN;
  spans[ER_APP_EXECUTION_APP_NODE_SPAN].bytes = identity->app_node_id.bytes;
  spans[ER_APP_EXECUTION_APP_NODE_SPAN].len = ER_NODE_ID_LEN;
  spans[ER_APP_EXECUTION_ADMISSION_SPAN].bytes = identity->admission_id.bytes;
  spans[ER_APP_EXECUTION_ADMISSION_SPAN].len = ER_HASH_LEN;
  spans[ER_APP_EXECUTION_BUDGET_SPAN].bytes = budget->budget_id.bytes;
  spans[ER_APP_EXECUTION_BUDGET_SPAN].len = ER_HASH_LEN;
  spans[ER_APP_EXECUTION_FIELDS_SPAN].bytes = fields;
  spans[ER_APP_EXECUTION_FIELDS_SPAN].len = (UINTN)sizeof(fields);

  er_mem_zero((UINT8*)out_jurisdiction, (UINTN)sizeof(*out_jurisdiction));
  out_jurisdiction->abi_version = ER_APP_ABI_VERSION;
  out_jurisdiction->admission_id = identity->admission_id;
  out_jurisdiction->budget_id = budget->budget_id;
  out_jurisdiction->allocation_id = allocation->allocation_id;
  out_jurisdiction->parent_relay_node_id = *parent_relay_node_id;
  out_jurisdiction->app_node_id = identity->app_node_id;
  out_jurisdiction->app_address_base = allocation->app_address_base;
  out_jurisdiction->app_address_len = allocation->app_address_len;
  out_jurisdiction->public_inbox_base = public_inbox_base;
  out_jurisdiction->public_inbox_len = public_inbox_len;
  out_jurisdiction->public_outbox_base = public_outbox_base;
  out_jurisdiction->public_outbox_len = public_outbox_len;

  return er_crypto_hash(crypto, g_app_execution_jurisdiction_domain,
                        (UINTN)(sizeof(g_app_execution_jurisdiction_domain) - 1u),
                        spans, ER_APP_EXECUTION_SPAN_COUNT, &out_jurisdiction->jurisdiction_id);
}

UINT8 er_app_prepare_ui_presentation(const ErCryptoProvider* crypto,
                                     const ErAppExecutionJurisdiction* jurisdiction,
                                     const ErNodeId* ui_relay_node_id,
                                     const ErHash* route_hash,
                                     er_ui_scene_budget_t scene_budget,
                                     UINT64 sequence,
                                     ErAppUiPresentation* out_presentation) {
  UINT8 fields[ER_APP_UI_PRESENTATION_U64_FIELDS_BYTES];
  UINT8* cursor = fields;
  ErByteSpan spans[ER_APP_UI_PRESENTATION_SPAN_COUNT];

  if (crypto == 0 || jurisdiction == 0 || ui_relay_node_id == 0 ||
      route_hash == 0 || out_presentation == 0 ||
      jurisdiction->abi_version != ER_APP_ABI_VERSION ||
      er_node_id_nonzero(&jurisdiction->app_node_id) == 0u ||
      er_hash_nonzero(&jurisdiction->jurisdiction_id) == 0u ||
      er_hash_nonzero(&jurisdiction->admission_id) == 0u ||
      er_node_id_nonzero(ui_relay_node_id) == 0u ||
      er_hash_nonzero(route_hash) == 0u ||
      er_app_scene_budget_nonzero(scene_budget) == 0u ||
      sequence == 0u) {
    return 0;
  }

  er_app_put_budget_field(&cursor, sequence);
  er_app_put_budget_field(&cursor, (UINT64)scene_budget.rects);
  er_app_put_budget_field(&cursor, (UINT64)scene_budget.hits);
  er_app_put_budget_field(&cursor, (UINT64)scene_budget.drag_sources);
  er_app_put_budget_field(&cursor, (UINT64)scene_budget.drop_targets);
  er_app_put_budget_field(&cursor, (UINT64)scene_budget.transitions);
  er_app_put_budget_field(&cursor, (UINT64)scene_budget.icon_quads);
  er_app_put_budget_field(&cursor, (UINT64)scene_budget.text_quads);

  spans[ER_APP_UI_PRESENTATION_JURISDICTION_SPAN].bytes =
      jurisdiction->jurisdiction_id.bytes;
  spans[ER_APP_UI_PRESENTATION_JURISDICTION_SPAN].len = ER_HASH_LEN;
  spans[ER_APP_UI_PRESENTATION_APP_SPAN].bytes = jurisdiction->app_node_id.bytes;
  spans[ER_APP_UI_PRESENTATION_APP_SPAN].len = ER_NODE_ID_LEN;
  spans[ER_APP_UI_PRESENTATION_RELAY_SPAN].bytes = ui_relay_node_id->bytes;
  spans[ER_APP_UI_PRESENTATION_RELAY_SPAN].len = ER_NODE_ID_LEN;
  spans[ER_APP_UI_PRESENTATION_ROUTE_SPAN].bytes = route_hash->bytes;
  spans[ER_APP_UI_PRESENTATION_ROUTE_SPAN].len = ER_HASH_LEN;
  spans[ER_APP_UI_PRESENTATION_FIELDS_SPAN].bytes = fields;
  spans[ER_APP_UI_PRESENTATION_FIELDS_SPAN].len = (UINTN)sizeof(fields);

  er_mem_zero((UINT8*)out_presentation, (UINTN)sizeof(*out_presentation));
  out_presentation->abi_version = ER_APP_ABI_VERSION;
  out_presentation->jurisdiction_id = jurisdiction->jurisdiction_id;
  out_presentation->admission_id = jurisdiction->admission_id;
  out_presentation->app_node_id = jurisdiction->app_node_id;
  out_presentation->ui_relay_node_id = *ui_relay_node_id;
  out_presentation->route_hash = *route_hash;
  out_presentation->sequence = sequence;
  out_presentation->max_rects = (UINT64)scene_budget.rects;
  out_presentation->max_hits = (UINT64)scene_budget.hits;
  out_presentation->max_drag_sources = (UINT64)scene_budget.drag_sources;
  out_presentation->max_drop_targets = (UINT64)scene_budget.drop_targets;
  out_presentation->max_transitions = (UINT64)scene_budget.transitions;
  out_presentation->max_icon_quads = (UINT64)scene_budget.icon_quads;
  out_presentation->max_text_quads = (UINT64)scene_budget.text_quads;

  return er_crypto_hash(crypto, g_app_ui_presentation_domain,
                        (UINTN)(sizeof(g_app_ui_presentation_domain) - 1u),
                        spans, ER_APP_UI_PRESENTATION_SPAN_COUNT,
                        &out_presentation->presentation_id);
}

UINT8 er_app_ui_scene_fits_presentation(er_ui_scene_stats_t stats,
                                        const ErAppUiPresentation* presentation) {
  if (presentation == 0 ||
      presentation->abi_version != ER_APP_ABI_VERSION ||
      er_node_id_nonzero(&presentation->app_node_id) == 0u ||
      er_node_id_nonzero(&presentation->ui_relay_node_id) == 0u ||
      er_hash_nonzero(&presentation->jurisdiction_id) == 0u ||
      er_hash_nonzero(&presentation->admission_id) == 0u ||
      er_hash_nonzero(&presentation->presentation_id) == 0u ||
      er_hash_nonzero(&presentation->route_hash) == 0u ||
      presentation->sequence == 0u) {
    return 0;
  }
  return (UINT8)(er_app_scene_count_fits((UINT64)stats.rects, presentation->max_rects) != 0u &&
                 er_app_scene_count_fits((UINT64)stats.hits, presentation->max_hits) != 0u &&
                 er_app_scene_count_fits((UINT64)stats.drag_sources,
                                         presentation->max_drag_sources) != 0u &&
                 er_app_scene_count_fits((UINT64)stats.drop_targets,
                                         presentation->max_drop_targets) != 0u &&
                 er_app_scene_count_fits((UINT64)stats.transitions,
                                         presentation->max_transitions) != 0u &&
                 er_app_scene_count_fits((UINT64)stats.icon_quads,
                                         presentation->max_icon_quads) != 0u &&
                 er_app_scene_count_fits((UINT64)stats.text_quads,
                                         presentation->max_text_quads) != 0u);
}
