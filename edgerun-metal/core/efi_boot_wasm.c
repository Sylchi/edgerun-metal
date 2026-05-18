#include "efi_boot_internal.h"

static UINT8 g_ui_boot_app_memory[ER_UI_BOOT_APP_COUNT][ER_UI_BOOT_APP_MEMORY_BYTES];
static UINT8 g_ui_boot_app_module_memory[ER_UI_BOOT_APP_COUNT][ER_UI_BOOT_APP_MODULE_BYTES];
static UINT8 g_ui_boot_app_manifest_memory[ER_UI_BOOT_APP_COUNT][ER_UI_BOOT_APP_MANIFEST_BYTES];

static const char g_ui_boot_counter_wasm_label[] = "apps/counter.wasm";
static const char g_ui_boot_counter_manifest_label[] = "apps/counter.manifest";
static const UINT8 g_ui_boot_counter_manifest[] = {
  'e', 'd', 'g', 'e', 'r', 'u', 'n', ':',
  'u', 'i', ':', 'c', 'o', 'u', 'n', 't',
  'e', 'r'
};

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

UINT8 er_ui_boot_execute_wasm_counter(ErUiWasmAppRuntime* runtime) {
  INT64 main_result = 0;

  if (runtime == 0) {
    return 0u;
  }
  if (er_ui_wasm_app_execute(runtime, &main_result) != 0 ||
      main_result != (INT64)(UINT64)ER_UI_WASM_COUNTER_PACKET_BYTES) {
    return 0u;
  }
  er_print("ui renderer: wasm scene rects=");
  er_print_u64_dec((UINT64)runtime->emitted_stats.rects);
  er_print(" hits=");
  er_print_u64_dec((UINT64)runtime->emitted_stats.hits);
  er_print(" text=");
  er_print_u64_dec((UINT64)runtime->emitted_stats.text_quads);
  er_println("");
  return 1u;
}

UINT8 er_ui_boot_load_wasm_counter_package(UINT8* module_memory,
                                                  UINT32 module_memory_size,
                                                  UINT8* manifest_memory,
                                                  UINT32 manifest_memory_size,
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
  ErAppPackageObjectLoad app_load;
  ErAppPackageObjectLoad manifest_load;

  if (module_memory == 0 || manifest_memory == 0 || out_loaded == 0 ||
      module_memory_size == 0u || manifest_memory_size == 0u) {
    return 0u;
  }
  er_crypto_blake3_provider(&crypto);
  if (er_vfs_prepare_object_label_ref(&crypto, g_ui_boot_counter_wasm_label,
                                      (UINTN)sizeof(g_ui_boot_counter_wasm_label) - 1u,
                                      g_edgerun_ui_counter_wasm,
                                      ER_UI_COUNTER_WASM_SIZE, &app_ref) == 0u) {
    return 0u;
  }
  if (er_vfs_prepare_object_label_ref(&crypto, g_ui_boot_counter_manifest_label,
                                      (UINTN)sizeof(g_ui_boot_counter_manifest_label) - 1u,
                                      g_ui_boot_counter_manifest,
                                      (UINTN)sizeof(g_ui_boot_counter_manifest),
                                      &manifest_ref) == 0u) {
    return 0u;
  }
  if (er_app_prepare_package_manifest(&crypto, &app_ref, &manifest_ref, 0,
                                      &package) == 0u) {
    return 0u;
  }
  if (er_vfs_prepare_object_packet(&crypto, g_edgerun_ui_counter_wasm,
                                   ER_UI_COUNTER_WASM_SIZE, 0u, 0u, 1u,
                                   &app_packet) == 0u) {
    return 0u;
  }
  if (er_vfs_prepare_object_packet(&crypto, g_ui_boot_counter_manifest,
                                   (UINTN)sizeof(g_ui_boot_counter_manifest),
                                   0u, 0u, 1u, &manifest_packet) == 0u) {
    return 0u;
  }
  app_load.packets = &app_packet;
  app_load.packet_count = 1u;
  app_load.bytes = module_memory;
  app_load.capacity = module_memory_size;
  manifest_load.packets = &manifest_packet;
  manifest_load.packet_count = 1u;
  manifest_load.bytes = manifest_memory;
  manifest_load.capacity = manifest_memory_size;
  if (er_ui_boot_prepare_storage_retrieve_route(ER_UI_WASM_STORAGE_APP_ROUTE_ID_SEED,
                                                app_index, &app_route) == 0u ||
      er_ui_boot_prepare_storage_retrieve_route(ER_UI_WASM_STORAGE_MANIFEST_ROUTE_ID_SEED,
                                                app_index, &manifest_route) == 0u ||
      er_app_prepare_package_storage_source(&crypto, &package, &app_route,
                                            &manifest_route, 0,
                                            &storage_source) == 0u) {
    return 0u;
  }
  er_mem_zero((UINT8*)&app_response, (UINTN)sizeof(app_response));
  app_response.abi_version = ER_APP_ABI_VERSION;
  app_response.retrieve_route_id = storage_source.app_retrieve_route_id;
  app_response.object_id = package.app_object_id;
  app_response.object_len = package.app_object_len;
  app_response.packets = app_load.packets;
  app_response.packet_count = app_load.packet_count;
  app_response.bytes = app_load.bytes;
  app_response.capacity = app_load.capacity;
  er_mem_zero((UINT8*)&manifest_response, (UINTN)sizeof(manifest_response));
  manifest_response.abi_version = ER_APP_ABI_VERSION;
  manifest_response.retrieve_route_id = storage_source.manifest_retrieve_route_id;
  manifest_response.object_id = package.manifest_object_id;
  manifest_response.object_len = package.manifest_object_len;
  manifest_response.packets = manifest_load.packets;
  manifest_response.packet_count = manifest_load.packet_count;
  manifest_response.bytes = manifest_load.bytes;
  manifest_response.capacity = manifest_load.capacity;
  if (er_app_prepare_package_storage_object(&app_response,
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

UINT8 er_ui_boot_prepare_wasm_counter(ErUiWasmAppRuntime* runtime,
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

  if (runtime == 0 || presentation == 0 || wasm_scene == 0 || memory == 0 ||
      module_memory == 0 || manifest_memory == 0 || memory_size == 0u ||
      module_memory_size == 0u || manifest_memory_size == 0u || scene_budget == 0) {
    return 0u;
  }
  if (er_ui_boot_load_wasm_counter_package(module_memory, module_memory_size,
                                           manifest_memory, manifest_memory_size,
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
  return er_ui_boot_execute_wasm_counter(runtime);
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
    if (er_ui_boot_prepare_wasm_counter(&apps[i].runtime,
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
