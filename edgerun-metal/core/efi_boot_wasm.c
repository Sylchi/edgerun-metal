#include "efi_boot_internal.h"
#include "wasm_vm_internal.h"

static UINT8 g_ui_boot_app_memory[ER_UI_BOOT_APP_COUNT][ER_UI_BOOT_APP_MEMORY_BYTES];
static UINT8 g_ui_boot_app_module_memory[ER_UI_BOOT_APP_COUNT][ER_UI_BOOT_APP_MODULE_BYTES];
static UINT8 g_ui_boot_app_manifest_memory[ER_UI_BOOT_APP_COUNT][ER_UI_BOOT_APP_MANIFEST_BYTES];

static const char g_ui_boot_user_app_wasm_label[] = "apps/user-app.wasm";
static const char g_ui_boot_user_app_manifest_label[] = "apps/user-app.manifest";

enum {
  ER_UI_BOOT_PACKAGE_APP_SEQUENCE = 1u,
  ER_UI_BOOT_PACKAGE_MANIFEST_SEQUENCE = 2u,
  ER_UI_BOOT_APP_UI_COMMAND_COUNT = 3u,
  ER_UI_BOOT_APP_UI_RECT_COUNT = 1u,
  ER_UI_BOOT_APP_UI_HIT_COUNT = 1u,
  ER_UI_BOOT_APP_UI_TEXT_COUNT = 1u,
  ER_UI_BOOT_APP_RECT_X = 0x41200000u,
  ER_UI_BOOT_APP_RECT_Y = 0x41a00000u,
  ER_UI_BOOT_APP_RECT_W = 0x42f00000u,
  ER_UI_BOOT_APP_RECT_H = 0x42480000u,
  ER_UI_BOOT_APP_RECT_RADIUS = 0x41000000u,
  ER_UI_BOOT_APP_RECT_COLOR_R = 0x3e800000u,
  ER_UI_BOOT_APP_RECT_COLOR_G = 0x3f000000u,
  ER_UI_BOOT_APP_RECT_COLOR_B = 0x3f400000u,
  ER_UI_BOOT_APP_RECT_COLOR_A = 0x3f800000u,
  ER_UI_BOOT_APP_HIT_ID = 7u,
  ER_UI_BOOT_APP_TEXT_X = 0x41300000u,
  ER_UI_BOOT_APP_TEXT_Y = 0x41b00000u,
  ER_UI_BOOT_APP_TEXT_W = 0x41800000u,
  ER_UI_BOOT_APP_TEXT_H = 0x41800000u,
  ER_UI_BOOT_APP_TEXT_U1 = 0x3f800000u,
  ER_UI_BOOT_APP_TEXT_V1 = 0x3f800000u,
  ER_UI_BOOT_APP_TEXT_ATLAS_ID = 2u,
  ER_UI_BOOT_APP_TEXT_COLOR_R = 0x3f800000u,
  ER_UI_BOOT_APP_TEXT_COLOR_G = 0x3f800000u,
  ER_UI_BOOT_APP_TEXT_COLOR_B = 0x3f800000u,
  ER_UI_BOOT_APP_TEXT_COLOR_A = 0x3f800000u
};

static void er_ui_boot_store_u16(UINT8* dst, UINT16 value) {
  dst[ER_WASM_U32_BYTE0] = (UINT8)(value & ER_WASM_U8_MASK);
  dst[ER_WASM_U32_BYTE1] = (UINT8)((UINT32)value >> ER_WASM_U32_BYTE1_SHIFT);
}

static void er_ui_boot_store_u32(UINT8* dst, UINT32 value) {
  dst[ER_WASM_U32_BYTE0] = (UINT8)(value & ER_WASM_U8_MASK);
  dst[ER_WASM_U32_BYTE1] = (UINT8)((value >> ER_WASM_U32_BYTE1_SHIFT) &
                                   ER_WASM_U8_MASK);
  dst[ER_WASM_U32_BYTE2] = (UINT8)((value >> ER_WASM_U32_BYTE2_SHIFT) &
                                   ER_WASM_U8_MASK);
  dst[ER_WASM_U32_BYTE3] = (UINT8)((value >> ER_WASM_U32_BYTE3_SHIFT) &
                                   ER_WASM_U8_MASK);
}

static void er_ui_boot_seed_user_app_header(UINT8* packet) {
  er_ui_boot_store_u16(packet + ER_WASM_UI_HEADER_ABI_OFFSET,
                       (UINT16)ER_WASM_UI_COMMAND_ABI_VERSION);
  er_ui_boot_store_u32(packet + ER_WASM_UI_HEADER_COMMAND_COUNT_OFFSET,
                       ER_UI_BOOT_APP_UI_COMMAND_COUNT);
  er_ui_boot_store_u32(packet + ER_WASM_UI_HEADER_RECT_COUNT_OFFSET,
                       ER_UI_BOOT_APP_UI_RECT_COUNT);
  er_ui_boot_store_u32(packet + ER_WASM_UI_HEADER_HIT_COUNT_OFFSET,
                       ER_UI_BOOT_APP_UI_HIT_COUNT);
  er_ui_boot_store_u32(packet + ER_WASM_UI_HEADER_DRAG_SOURCE_COUNT_OFFSET, 0u);
  er_ui_boot_store_u32(packet + ER_WASM_UI_HEADER_DROP_TARGET_COUNT_OFFSET, 0u);
  er_ui_boot_store_u32(packet + ER_WASM_UI_HEADER_TRANSITION_COUNT_OFFSET, 0u);
  er_ui_boot_store_u32(packet + ER_WASM_UI_HEADER_ICON_QUAD_COUNT_OFFSET, 0u);
  er_ui_boot_store_u32(packet + ER_WASM_UI_HEADER_TEXT_QUAD_COUNT_OFFSET,
                       ER_UI_BOOT_APP_UI_TEXT_COUNT);
}

static void er_ui_boot_seed_user_app_rect(UINT8* rect) {
  er_ui_boot_store_u32(rect + ER_WASM_UI_RECT_RECORD_X_OFFSET,
                       ER_UI_BOOT_APP_RECT_X);
  er_ui_boot_store_u32(rect + ER_WASM_UI_RECT_RECORD_Y_OFFSET,
                       ER_UI_BOOT_APP_RECT_Y);
  er_ui_boot_store_u32(rect + ER_WASM_UI_RECT_RECORD_W_OFFSET,
                       ER_UI_BOOT_APP_RECT_W);
  er_ui_boot_store_u32(rect + ER_WASM_UI_RECT_RECORD_H_OFFSET,
                       ER_UI_BOOT_APP_RECT_H);
  er_ui_boot_store_u32(rect + ER_WASM_UI_RECT_RECORD_RADIUS_OFFSET,
                       ER_UI_BOOT_APP_RECT_RADIUS);
  er_ui_boot_store_u32(rect + ER_WASM_UI_RECT_RECORD_COLOR_OFFSET +
                       ER_WASM_UI_COLOR_RECORD_R_OFFSET,
                       ER_UI_BOOT_APP_RECT_COLOR_R);
  er_ui_boot_store_u32(rect + ER_WASM_UI_RECT_RECORD_COLOR_OFFSET +
                       ER_WASM_UI_COLOR_RECORD_G_OFFSET,
                       ER_UI_BOOT_APP_RECT_COLOR_G);
  er_ui_boot_store_u32(rect + ER_WASM_UI_RECT_RECORD_COLOR_OFFSET +
                       ER_WASM_UI_COLOR_RECORD_B_OFFSET,
                       ER_UI_BOOT_APP_RECT_COLOR_B);
  er_ui_boot_store_u32(rect + ER_WASM_UI_RECT_RECORD_COLOR_OFFSET +
                       ER_WASM_UI_COLOR_RECORD_A_OFFSET,
                       ER_UI_BOOT_APP_RECT_COLOR_A);
  er_ui_boot_store_u32(rect + ER_WASM_UI_RECT_RECORD_COLOR2_OFFSET +
                       ER_WASM_UI_COLOR_RECORD_R_OFFSET,
                       ER_UI_BOOT_APP_RECT_COLOR_R);
  er_ui_boot_store_u32(rect + ER_WASM_UI_RECT_RECORD_COLOR2_OFFSET +
                       ER_WASM_UI_COLOR_RECORD_G_OFFSET,
                       ER_UI_BOOT_APP_RECT_COLOR_G);
  er_ui_boot_store_u32(rect + ER_WASM_UI_RECT_RECORD_COLOR2_OFFSET +
                       ER_WASM_UI_COLOR_RECORD_B_OFFSET,
                       ER_UI_BOOT_APP_RECT_COLOR_B);
  er_ui_boot_store_u32(rect + ER_WASM_UI_RECT_RECORD_COLOR2_OFFSET +
                       ER_WASM_UI_COLOR_RECORD_A_OFFSET,
                       ER_UI_BOOT_APP_RECT_COLOR_A);
  er_ui_boot_store_u32(rect + ER_WASM_UI_RECT_RECORD_MODE_OFFSET,
                       (UINT32)ER_UI_RECT_FILL);
  er_ui_boot_store_u32(rect + ER_WASM_UI_RECT_RECORD_SHADOW_OFFSET, 0u);
}

static void er_ui_boot_seed_user_app_hit(UINT8* hit) {
  er_ui_boot_store_u32(hit + ER_WASM_UI_HIT_RECORD_KIND_OFFSET,
                       (UINT32)ER_UI_HIT_BUTTON);
  er_ui_boot_store_u32(hit + ER_WASM_UI_HIT_RECORD_ID_OFFSET,
                       ER_UI_BOOT_APP_HIT_ID);
  er_ui_boot_store_u32(hit + ER_WASM_UI_HIT_RECORD_X_OFFSET,
                       ER_UI_BOOT_APP_RECT_X);
  er_ui_boot_store_u32(hit + ER_WASM_UI_HIT_RECORD_Y_OFFSET,
                       ER_UI_BOOT_APP_RECT_Y);
  er_ui_boot_store_u32(hit + ER_WASM_UI_HIT_RECORD_W_OFFSET,
                       ER_UI_BOOT_APP_RECT_W);
  er_ui_boot_store_u32(hit + ER_WASM_UI_HIT_RECORD_H_OFFSET,
                       ER_UI_BOOT_APP_RECT_H);
}

static void er_ui_boot_seed_user_app_text(UINT8* text) {
  er_ui_boot_store_u32(text + ER_WASM_UI_QUAD_RECORD_X_OFFSET,
                       ER_UI_BOOT_APP_TEXT_X);
  er_ui_boot_store_u32(text + ER_WASM_UI_QUAD_RECORD_Y_OFFSET,
                       ER_UI_BOOT_APP_TEXT_Y);
  er_ui_boot_store_u32(text + ER_WASM_UI_QUAD_RECORD_W_OFFSET,
                       ER_UI_BOOT_APP_TEXT_W);
  er_ui_boot_store_u32(text + ER_WASM_UI_QUAD_RECORD_H_OFFSET,
                       ER_UI_BOOT_APP_TEXT_H);
  er_ui_boot_store_u32(text + ER_WASM_UI_QUAD_RECORD_U0_OFFSET, 0u);
  er_ui_boot_store_u32(text + ER_WASM_UI_QUAD_RECORD_V0_OFFSET, 0u);
  er_ui_boot_store_u32(text + ER_WASM_UI_QUAD_RECORD_U1_OFFSET,
                       ER_UI_BOOT_APP_TEXT_U1);
  er_ui_boot_store_u32(text + ER_WASM_UI_QUAD_RECORD_V1_OFFSET,
                       ER_UI_BOOT_APP_TEXT_V1);
  er_ui_boot_store_u32(text + ER_WASM_UI_QUAD_RECORD_ATLAS_ID_OFFSET,
                       ER_UI_BOOT_APP_TEXT_ATLAS_ID);
  er_ui_boot_store_u32(text + ER_WASM_UI_QUAD_RECORD_COLOR_OFFSET +
                       ER_WASM_UI_COLOR_RECORD_R_OFFSET,
                       ER_UI_BOOT_APP_TEXT_COLOR_R);
  er_ui_boot_store_u32(text + ER_WASM_UI_QUAD_RECORD_COLOR_OFFSET +
                       ER_WASM_UI_COLOR_RECORD_G_OFFSET,
                       ER_UI_BOOT_APP_TEXT_COLOR_G);
  er_ui_boot_store_u32(text + ER_WASM_UI_QUAD_RECORD_COLOR_OFFSET +
                       ER_WASM_UI_COLOR_RECORD_B_OFFSET,
                       ER_UI_BOOT_APP_TEXT_COLOR_B);
  er_ui_boot_store_u32(text + ER_WASM_UI_QUAD_RECORD_COLOR_OFFSET +
                       ER_WASM_UI_COLOR_RECORD_A_OFFSET,
                       ER_UI_BOOT_APP_TEXT_COLOR_A);
}

static UINT8 er_ui_boot_seed_user_app_ui_packet(ErUiWasmAppRuntime* runtime) {
  UINT8* packet;
  UINT8* rect;
  UINT8* hit;
  UINT8* text;

  if (runtime == 0 || runtime->memory == 0 ||
      runtime->relay_outbox_base > runtime->memory_size ||
      ER_UI_WASM_COUNTER_PACKET_BYTES >
        runtime->memory_size - runtime->relay_outbox_base) {
    return 0u;
  }
  packet = runtime->memory + runtime->relay_outbox_base;
  rect = packet + ER_WASM_UI_COMMAND_LIST_HEADER_LEN;
  hit = rect + ER_WASM_UI_RECT_RECORD_LEN;
  text = hit + ER_WASM_UI_HIT_RECORD_LEN;

  er_mem_zero(packet, ER_UI_WASM_COUNTER_PACKET_BYTES);
  er_ui_boot_seed_user_app_header(packet);
  er_ui_boot_seed_user_app_rect(rect);
  er_ui_boot_seed_user_app_hit(hit);
  er_ui_boot_seed_user_app_text(text);
  return 1u;
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
  if (er_ui_boot_seed_user_app_ui_packet(runtime) == 0u ||
      er_ui_wasm_app_execute(runtime, &main_result) != 0 ||
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

UINT8 er_ui_boot_load_user_app_package(UINT8* module_memory,
                                       UINT32 module_memory_size,
                                       UINT8* manifest_memory,
                                       UINT32 manifest_memory_size,
                                       ErUiBootPackageStorage* storage,
                                       UINT32 app_index,
                                       ErAppLoadedPackage* out_loaded) {
  ErCryptoProvider crypto;
  ErVfsObjectLabelRef app_ref;
  ErVfsObjectLabelRef manifest_ref;
  ErAppPackageManifest package;
  ErVfsObjectPacket app_packet;
  ErVfsObjectPacket manifest_packet;
  ErAdmittedRoute app_route;
  ErAdmittedRoute manifest_route;
  ErAppPackageStorageSource storage_source;
  ErAppPackageStorageResponse app_response;
  ErAppPackageStorageResponse manifest_response;
  ErAppPackageStorageObject app_object;
  ErAppPackageStorageObject manifest_object;

  if (module_memory == 0 || manifest_memory == 0 || storage == 0 ||
      out_loaded == 0 ||
      module_memory_size == 0u || manifest_memory_size == 0u) {
    return 0u;
  }
  er_crypto_blake3_provider(&crypto);
  if (er_storage_endpoint_object_store_init(&storage->app_store,
                                            storage->app_packets,
                                            ER_UI_BOOT_PACKAGE_OBJECT_PACKET_CAPACITY) == 0u ||
      er_storage_endpoint_object_store_init(&storage->manifest_store,
                                            storage->manifest_packets,
                                            ER_UI_BOOT_PACKAGE_OBJECT_PACKET_CAPACITY) == 0u) {
    return 0u;
  }
  if (er_vfs_prepare_object_label_ref(&crypto, g_ui_boot_user_app_wasm_label,
                                      (UINTN)sizeof(g_ui_boot_user_app_wasm_label) - 1u,
                                      g_edgerun_user_app_wasm,
                                      ER_USER_APP_WASM_SIZE, &app_ref) == 0u) {
    return 0u;
  }
  if (er_vfs_prepare_object_label_ref(&crypto, g_ui_boot_user_app_manifest_label,
                                      (UINTN)sizeof(g_ui_boot_user_app_manifest_label) - 1u,
                                      g_edgerun_user_app_manifest,
                                      ER_USER_APP_MANIFEST_SIZE,
                                      &manifest_ref) == 0u) {
    return 0u;
  }
  if (er_app_prepare_package_manifest(&crypto, &app_ref, &manifest_ref, 0,
                                      &package) == 0u) {
    return 0u;
  }
  if (er_vfs_prepare_object_packet(&crypto, g_edgerun_user_app_wasm,
                                   ER_USER_APP_WASM_SIZE, 0u, 0u, 1u,
                                   &app_packet) == 0u) {
    return 0u;
  }
  if (er_vfs_prepare_object_packet(&crypto, g_edgerun_user_app_manifest,
                                   ER_USER_APP_MANIFEST_SIZE,
                                   0u, 0u, 1u, &manifest_packet) == 0u) {
    return 0u;
  }
  if (er_ui_boot_prepare_storage_retrieve_route(ER_UI_WASM_STORAGE_APP_ROUTE_ID_SEED,
                                                app_index, &app_route) == 0u ||
      er_ui_boot_prepare_storage_retrieve_route(ER_UI_WASM_STORAGE_MANIFEST_ROUTE_ID_SEED,
                                                app_index, &manifest_route) == 0u ||
      er_app_prepare_package_storage_source(&crypto, &package, &app_route,
                                            &manifest_route, 0,
                                            &storage_source) == 0u) {
    return 0u;
  }
  if (er_ui_boot_seed_package_object_store(&crypto, &app_route, &app_packet,
                                           ER_UI_BOOT_PACKAGE_APP_SEQUENCE,
                                           &storage->app_store) == 0u ||
      er_ui_boot_seed_package_object_store(&crypto, &manifest_route,
                                           &manifest_packet,
                                           ER_UI_BOOT_PACKAGE_MANIFEST_SEQUENCE,
                                           &storage->manifest_store) == 0u ||
      er_storage_endpoint_prepare_package_storage_response(&crypto,
                                                           &storage->app_store,
                                                           &storage_source.app_retrieve_route_id,
                                                           &package.app_object_id,
                                                           package.app_object_len,
                                                           module_memory,
                                                           module_memory_size,
                                                           &app_response) == 0u ||
      er_storage_endpoint_prepare_package_storage_response(&crypto,
                                                           &storage->manifest_store,
                                                           &storage_source.manifest_retrieve_route_id,
                                                           &package.manifest_object_id,
                                                           package.manifest_object_len,
                                                           manifest_memory,
                                                           manifest_memory_size,
                                                           &manifest_response) == 0u ||
      er_app_prepare_package_storage_object(&app_response,
                                            &storage_source.app_retrieve_route_id,
                                            &package.app_object_id,
                                            package.app_object_len,
                                            &app_object) == 0u ||
      er_app_prepare_package_storage_object(&manifest_response,
                                            &storage_source.manifest_retrieve_route_id,
                                            &package.manifest_object_id,
                                            package.manifest_object_len,
                                            &manifest_object) == 0u) {
    return 0u;
  }
  return er_app_load_package_from_storage_source(&crypto, &package,
                                                 &storage_source, &app_object,
                                                 &manifest_object, 0,
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
      app_count > ER_UI_BOOT_APP_COUNT) {
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
