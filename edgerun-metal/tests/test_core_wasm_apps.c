#include "test_core_internal.h"

static void test_ui_wasm_app_runner(void) {
  static UINT8 memory[65536];
  static const UINT8 input_packet[] = {'k', 'e', 'y', '1'};
  ErWasmHostCalls host = {0};
  ErUiWasmAppRuntime runtime;
  ErAppUiPresentation presentation;
  er_ui_scene_t scene;
  er_ui_key_t key;
  er_ui_key_t invalid_key;
  er_ui_key_modifiers_t modifiers;
  INT64 result = 0;

  test_prepare_wasm_ui_presentation(&presentation);

  check_int64("ui wasm app scene init",
              er_ui_scene_init_with_allocator(&scene, er_ui_color_rgb_u8(0u, 0u, 0u),
                                              test_ui_allocator()),
              ER_UI_OK);
  er_mem_zero((UINT8*)&runtime, (UINTN)sizeof(runtime));
  runtime.memory = memory;
  runtime.memory_size = (UINT32)sizeof(memory);
  runtime.relay_inbox_base = 0u;
  runtime.relay_inbox_len = 1024u;
  runtime.relay_outbox_base = 1024u;
  runtime.relay_outbox_len = 2048u;
  runtime.presentation = &presentation;
  runtime.scene = &scene;
  runtime.input_epoch_modifier.tick_stride = 2u;
  runtime.execute_epoch_modifier.tick_stride = 4u;
  runtime.input_len = ER_UI_WASM_INPUT_PACKET_LEN;
  runtime.input_sequence = ER_UI_WASM_INPUT_SEQUENCE_MAX;
  check_int64("ui wasm app prepare",
              er_ui_wasm_app_prepare(g_edgerun_ui_counter_wasm, ER_UI_COUNTER_WASM_SIZE,
                                     &host, &runtime),
              0);
  check_uint64("ui wasm app prepared input len", runtime.input_len, 0u);
  check_uint64("ui wasm app prepared input sequence", runtime.input_sequence, 0u);
  check_uint64("ui wasm app prepared clock tick", runtime.settlement_clock.now.tick, 0u);
  check_uint64("ui wasm app input epoch stride", runtime.input_epoch_modifier.tick_stride, 2u);
  check_uint64("ui wasm app execute epoch stride", runtime.execute_epoch_modifier.tick_stride, 4u);
  check_int64("ui wasm app deliver input",
              er_ui_wasm_app_deliver_input(&runtime, input_packet,
                                           (UINT32)sizeof(input_packet)),
              0);
  check_uint64("ui wasm app inbox byte0", memory[0], (UINT8)'k');
  check_uint64("ui wasm app inbox byte3", memory[3], (UINT8)'1');
  check_uint64("ui wasm app inbox zeroed", memory[4], 0u);
  check_uint64("ui wasm app input len", runtime.input_len, sizeof(input_packet));
  check_uint64("ui wasm app input sequence", runtime.input_sequence, 1u);
  check_uint64("ui wasm app input epoch tick", runtime.last_input_epoch.tick, 2u);
  check_int64("ui wasm app reject oversized input",
              er_ui_wasm_app_deliver_input(&runtime, input_packet,
                                           runtime.relay_inbox_len + 1u),
              -1);
  check_uint64("ui wasm app rejected input sequence", runtime.input_sequence, 1u);
  check_uint64("ui wasm app rejected input epoch tick", runtime.last_input_epoch.tick, 2u);
  key.kind = ER_UI_KEY_OTHER;
  key.codepoint = (UINT32)'A';
  modifiers = er_ui_key_modifiers(true, true, false, false);
  check_int64("ui wasm app deliver key input",
              er_ui_wasm_app_deliver_key_input(&runtime, key, modifiers), 0);
  check_uint64("ui wasm app key input abi", memory[ER_UI_WASM_INPUT_ABI_OFFSET],
               ER_UI_WASM_INPUT_ABI_VERSION);
  check_uint64("ui wasm app key input kind", memory[ER_UI_WASM_INPUT_KIND_OFFSET],
               ER_UI_WASM_INPUT_KIND_KEY);
  check_uint64("ui wasm app key input key", memory[ER_UI_WASM_INPUT_KEY_KIND_OFFSET],
               ER_UI_KEY_OTHER);
  check_uint64("ui wasm app key input codepoint", memory[ER_UI_WASM_INPUT_KEY_CODEPOINT_OFFSET],
               (UINT8)'A');
  check_uint64("ui wasm app key input modifiers", memory[ER_UI_WASM_INPUT_MODIFIERS_OFFSET],
               ER_UI_WASM_INPUT_MODIFIER_SHIFT | ER_UI_WASM_INPUT_MODIFIER_CTRL);
  check_uint64("ui wasm app key input len", runtime.input_len, ER_UI_WASM_INPUT_PACKET_LEN);
  check_uint64("ui wasm app key input sequence field",
               memory[ER_UI_WASM_INPUT_SEQUENCE_OFFSET], 2u);
  check_uint64("ui wasm app key input sequence", runtime.input_sequence, 2u);
  check_uint64("ui wasm app key input epoch field",
               memory[ER_UI_WASM_INPUT_EPOCH_TICK_OFFSET], 4u);
  check_uint64("ui wasm app key input epoch high byte",
               memory[ER_UI_WASM_INPUT_EPOCH_TICK_OFFSET + 4u], 0u);
  check_uint64("ui wasm app key input slot field",
               memory[ER_UI_WASM_INPUT_EPOCH_SLOT_OFFSET], 0u);
  check_uint64("ui wasm app key input era field",
               memory[ER_UI_WASM_INPUT_EPOCH_ERA_OFFSET], 0u);
  check_uint64("ui wasm app key input epoch tick", runtime.last_input_epoch.tick, 4u);
  invalid_key.kind = (er_ui_key_kind_t)(ER_UI_KEY_OTHER + 1u);
  invalid_key.codepoint = 0u;
  check_int64("ui wasm app reject invalid key input",
              er_ui_wasm_app_deliver_key_input(&runtime, invalid_key, modifiers), -1);
  check_uint64("ui wasm app invalid key sequence", runtime.input_sequence, 2u);
  runtime.input_sequence = ER_UI_WASM_INPUT_SEQUENCE_MAX;
  check_int64("ui wasm app deliver wrapped key input",
              er_ui_wasm_app_deliver_key_input(&runtime, key, modifiers), 0);
  check_uint64("ui wasm app wrapped key input sequence field",
               memory[ER_UI_WASM_INPUT_SEQUENCE_OFFSET], 1u);
  check_uint64("ui wasm app wrapped key input sequence", runtime.input_sequence, 1u);
  check_uint64("ui wasm app wrapped key input epoch field",
               memory[ER_UI_WASM_INPUT_EPOCH_TICK_OFFSET], 6u);
  check_uint64("ui wasm app wrapped input epoch tick", runtime.last_input_epoch.tick, 6u);
  check_int64("ui wasm app execute", er_ui_wasm_app_execute(&runtime, &result),
              0);
  check_uint64("ui wasm app result", (UINT64)result,
               ER_WASM_UI_COMMAND_LIST_HEADER_LEN +
                 ER_WASM_UI_RECT_RECORD_LEN +
                 ER_WASM_UI_HIT_RECORD_LEN +
                 ER_WASM_UI_QUAD_RECORD_LEN);
  check_uint64("ui wasm app emitted", runtime.emitted, 1u);
  check_int64("ui wasm app render capture abi",
              runtime.last_render_capture.abi_version,
              ER_RENDER_ENDPOINT_ABI_VERSION);
  check_int64("ui wasm app render scene abi",
              runtime.last_render_scene.abi_version,
              ER_RENDER_ENDPOINT_ABI_VERSION);
  check_hash_equal("ui wasm app render route",
                   &runtime.last_render_capture.route_id,
                   &presentation.route_hash);
  check_hash_equal("ui wasm app render capture scene hash",
                   &runtime.last_render_scene.scene_hash,
                   &runtime.last_render_capture.scene_hash);
  check_uint64("ui wasm app render scene rects",
               runtime.last_render_scene.scene_stats.rects, 1u);
  check_uint64("ui wasm app render scene hits",
               runtime.last_render_scene.scene_stats.hits, 1u);
  check_uint64("ui wasm app render scene text",
               runtime.last_render_scene.scene_stats.text_quads, 1u);
  check_uint64("ui wasm app execute epoch tick", runtime.last_execute_epoch.tick, 10u);
  check_uint64("ui wasm app rects", scene.rect_count, 1u);
  check_uint64("ui wasm app hits", scene.hit_count, 1u);
  check_uint64("ui wasm app text", scene.text_quad_count, 1u);
  check_int64("ui wasm app hit kind", scene.hits[0].kind, ER_UI_HIT_BUTTON);
  check_uint64("ui wasm app hit id from input sequence", scene.hits[0].id, 1u);
  memory[4096] = 0x5au;
  check_int64("ui wasm app execute again", er_ui_wasm_app_execute(&runtime, &result),
              0);
  check_uint64("ui wasm app persistent memory", memory[4096], 0x5au);
  check_uint64("ui wasm app emitted again", runtime.emitted, 1u);
  check_uint64("ui wasm app execute again epoch tick", runtime.last_execute_epoch.tick, 14u);
  check_uint64("ui wasm app rects after rerun", scene.rect_count, 1u);
  check_uint64("ui wasm app hits after rerun", scene.hit_count, 1u);
  check_uint64("ui wasm app text after rerun", scene.text_quad_count, 1u);
  check_int64("ui wasm app reject second prepare",
              er_ui_wasm_app_prepare(g_edgerun_ui_counter_wasm, ER_UI_COUNTER_WASM_SIZE,
                                     &host, &runtime),
              -1);
  er_ui_scene_destroy(&scene);
}

static void test_ui_wasm_app_multiple_runtimes(void) {
  static UINT8 memory_a[65536];
  static UINT8 memory_b[65536];
  ErWasmHostCalls host = {0};
  ErUiWasmAppRuntime runtime_a;
  ErUiWasmAppRuntime runtime_b;
  ErAppUiPresentation presentation_a;
  ErAppUiPresentation presentation_b;
  er_ui_scene_t scene_a;
  er_ui_scene_t scene_b;
  er_ui_key_t key;
  er_ui_key_modifiers_t modifiers;
  INT64 result_a = 0;
  INT64 result_b = 0;

  test_prepare_wasm_ui_presentation(&presentation_a);
  test_prepare_wasm_ui_presentation(&presentation_b);
  check_int64("ui wasm multi scene a init",
              er_ui_scene_init_with_allocator(&scene_a, er_ui_color_rgb_u8(0u, 0u, 0u),
                                              test_ui_allocator()),
              ER_UI_OK);
  check_int64("ui wasm multi scene b init",
              er_ui_scene_init_with_allocator(&scene_b, er_ui_color_rgb_u8(0u, 0u, 0u),
                                              test_ui_allocator()),
              ER_UI_OK);

  er_mem_zero(memory_a, (UINTN)sizeof(memory_a));
  er_mem_zero(memory_b, (UINTN)sizeof(memory_b));
  er_mem_zero((UINT8*)&runtime_a, (UINTN)sizeof(runtime_a));
  er_mem_zero((UINT8*)&runtime_b, (UINTN)sizeof(runtime_b));
  runtime_a.memory = memory_a;
  runtime_a.memory_size = (UINT32)sizeof(memory_a);
  runtime_a.relay_inbox_base = 0u;
  runtime_a.relay_inbox_len = 1024u;
  runtime_a.relay_outbox_base = 1024u;
  runtime_a.relay_outbox_len = 2048u;
  runtime_a.presentation = &presentation_a;
  runtime_a.scene = &scene_a;
  runtime_b.memory = memory_b;
  runtime_b.memory_size = (UINT32)sizeof(memory_b);
  runtime_b.relay_inbox_base = 0u;
  runtime_b.relay_inbox_len = 1024u;
  runtime_b.relay_outbox_base = 1024u;
  runtime_b.relay_outbox_len = 2048u;
  runtime_b.presentation = &presentation_b;
  runtime_b.scene = &scene_b;

  check_int64("ui wasm multi prepare a",
              er_ui_wasm_app_prepare(g_edgerun_ui_counter_wasm, ER_UI_COUNTER_WASM_SIZE,
                                     &host, &runtime_a),
              0);
  check_int64("ui wasm multi prepare b",
              er_ui_wasm_app_prepare(g_edgerun_ui_counter_wasm, ER_UI_COUNTER_WASM_SIZE,
                                     &host, &runtime_b),
              0);

  key.kind = ER_UI_KEY_OTHER;
  key.codepoint = (UINT32)'Z';
  modifiers = er_ui_key_modifiers(false, false, false, false);
  check_int64("ui wasm multi input a",
              er_ui_wasm_app_deliver_key_input(&runtime_a, key, modifiers), 0);
  check_int64("ui wasm multi input b1",
              er_ui_wasm_app_deliver_key_input(&runtime_b, key, modifiers), 0);
  check_int64("ui wasm multi input b2",
              er_ui_wasm_app_deliver_key_input(&runtime_b, key, modifiers), 0);

  check_int64("ui wasm multi execute a",
              er_ui_wasm_app_execute(&runtime_a, &result_a), 0);
  check_int64("ui wasm multi execute b",
              er_ui_wasm_app_execute(&runtime_b, &result_b), 0);
  check_uint64("ui wasm multi result a", (UINT64)result_a,
               ER_WASM_UI_COMMAND_LIST_HEADER_LEN +
                 ER_WASM_UI_RECT_RECORD_LEN +
                 ER_WASM_UI_HIT_RECORD_LEN +
                 ER_WASM_UI_QUAD_RECORD_LEN);
  check_uint64("ui wasm multi result b", (UINT64)result_b,
               ER_WASM_UI_COMMAND_LIST_HEADER_LEN +
                 ER_WASM_UI_RECT_RECORD_LEN +
                 ER_WASM_UI_HIT_RECORD_LEN +
                 ER_WASM_UI_QUAD_RECORD_LEN);
  check_uint64("ui wasm multi scene a rects", scene_a.rect_count, 1u);
  check_uint64("ui wasm multi scene b rects", scene_b.rect_count, 1u);
  check_uint64("ui wasm multi scene a hit id", scene_a.hits[0].id, 1u);
  check_uint64("ui wasm multi scene b hit id", scene_b.hits[0].id, 2u);
  check_uint64("ui wasm multi memory a sequence",
               memory_a[ER_UI_WASM_INPUT_SEQUENCE_OFFSET], 1u);
  check_uint64("ui wasm multi memory b sequence",
               memory_b[ER_UI_WASM_INPUT_SEQUENCE_OFFSET], 2u);
  check_uint64("ui wasm multi emitted a", runtime_a.emitted, 1u);
  check_uint64("ui wasm multi emitted b", runtime_b.emitted, 1u);
  check_hash_equal("ui wasm multi render route a",
                   &runtime_a.last_render_capture.route_id,
                   &presentation_a.route_hash);
  check_hash_equal("ui wasm multi render route b",
                   &runtime_b.last_render_capture.route_id,
                   &presentation_b.route_hash);
  check_uint64("ui wasm multi render scene a hits",
               runtime_a.last_render_scene.scene_stats.hits, 1u);
  check_uint64("ui wasm multi render scene b hits",
               runtime_b.last_render_scene.scene_stats.hits, 1u);

  er_ui_scene_destroy(&scene_b);
  er_ui_scene_destroy(&scene_a);
}

static void test_ui_boot_apply_input_routes_to_active_wasm_app(void) {
  enum {
    UI_BOOT_INPUT_APP_COUNT = 2u,
    UI_BOOT_INPUT_ACTIVE_APP = 1u,
    UI_BOOT_INPUT_INBOX_BYTES = 1024u,
    UI_BOOT_INPUT_OUTBOX_BASE = 1024u,
    UI_BOOT_INPUT_OUTBOX_BYTES = 2048u,
    UI_BOOT_INPUT_MEMORY_BYTES = 65536u,
    UI_BOOT_INPUT_CHAR = 'R'
  };
  static UINT8 memory_a[UI_BOOT_INPUT_MEMORY_BYTES];
  static UINT8 memory_b[UI_BOOT_INPUT_MEMORY_BYTES];
  ErWasmHostCalls host = {0};
  ErUiBootAppContext apps[UI_BOOT_INPUT_APP_COUNT];
  ErUiBootRenderContext render;
  ErAppUiPresentation presentation_a;
  ErAppUiPresentation presentation_b;
  er_ui_ledger_app_state_t ledger_state;
  er_ui_runtime_state_t runtime;
  er_ui_scene_t scene;
  ErPs2KeyboardAction input;
  UINT8 redraw = 0u;

  test_prepare_wasm_ui_presentation(&presentation_a);
  test_prepare_wasm_ui_presentation(&presentation_b);
  er_mem_zero(memory_a, (UINTN)sizeof(memory_a));
  er_mem_zero(memory_b, (UINTN)sizeof(memory_b));
  er_mem_zero((UINT8*)apps, (UINTN)sizeof(apps));
  er_mem_zero((UINT8*)&render, (UINTN)sizeof(render));
  er_mem_zero((UINT8*)&input, (UINTN)sizeof(input));

  check_int64("ui boot input ledger init",
              er_ui_ledger_app_state_init(&ledger_state, test_ui_allocator()),
              ER_UI_OK);
  check_int64("ui boot input runtime init",
              er_ui_runtime_state_init_with_allocator(&runtime, test_ui_allocator()),
              ER_UI_OK);
  check_int64("ui boot input scene init",
              er_ui_scene_init_with_allocator(&scene, er_ui_color_rgb_u8(0u, 0u, 0u),
                                              test_ui_allocator()),
              ER_UI_OK);

  apps[0].ready = 1u;
  apps[0].runtime.memory = memory_a;
  apps[0].runtime.memory_size = (UINT32)sizeof(memory_a);
  apps[0].runtime.relay_inbox_base = 0u;
  apps[0].runtime.relay_inbox_len = UI_BOOT_INPUT_INBOX_BYTES;
  apps[0].runtime.relay_outbox_base = UI_BOOT_INPUT_OUTBOX_BASE;
  apps[0].runtime.relay_outbox_len = UI_BOOT_INPUT_OUTBOX_BYTES;
  apps[0].runtime.presentation = &presentation_a;
  apps[0].runtime.scene = &apps[0].scene;
  check_int64("ui boot input app a scene init",
              er_ui_scene_init_with_allocator(&apps[0].scene,
                                              er_ui_color_rgb_u8(0u, 0u, 0u),
                                              test_ui_allocator()),
              ER_UI_OK);
  check_int64("ui boot input app a prepare",
              er_ui_wasm_app_prepare(g_edgerun_ui_counter_wasm,
                                     ER_UI_COUNTER_WASM_SIZE,
                                     &host,
                                     &apps[0].runtime),
              0);

  apps[1].ready = 1u;
  apps[1].runtime.memory = memory_b;
  apps[1].runtime.memory_size = (UINT32)sizeof(memory_b);
  apps[1].runtime.relay_inbox_base = 0u;
  apps[1].runtime.relay_inbox_len = UI_BOOT_INPUT_INBOX_BYTES;
  apps[1].runtime.relay_outbox_base = UI_BOOT_INPUT_OUTBOX_BASE;
  apps[1].runtime.relay_outbox_len = UI_BOOT_INPUT_OUTBOX_BYTES;
  apps[1].runtime.presentation = &presentation_b;
  apps[1].runtime.scene = &apps[1].scene;
  check_int64("ui boot input app b scene init",
              er_ui_scene_init_with_allocator(&apps[1].scene,
                                              er_ui_color_rgb_u8(0u, 0u, 0u),
                                              test_ui_allocator()),
              ER_UI_OK);
  check_int64("ui boot input app b prepare",
              er_ui_wasm_app_prepare(g_edgerun_ui_counter_wasm,
                                     ER_UI_COUNTER_WASM_SIZE,
                                     &host,
                                     &apps[1].runtime),
              0);

  render.apps = apps;
  render.app_count = UI_BOOT_INPUT_APP_COUNT;
  render.active_app = UI_BOOT_INPUT_ACTIVE_APP;
  render.scene = &scene;

  input.kind = ER_PS2_KEYBOARD_ACTION_UI_KEY;
  input.key.kind = ER_UI_KEY_OTHER;
  input.key.codepoint = UI_BOOT_INPUT_CHAR;
  input.modifiers = er_ui_key_modifiers(false, true, false, false);

  check_int64("ui boot input apply",
              er_ui_boot_apply_input(&ledger_state, &runtime, &scene, &render,
                                     input, &redraw),
              1);
  check_uint64("ui boot input redraw", redraw, 1u);
  check_uint64("ui boot input inactive sequence",
               apps[0].runtime.input_sequence, 0u);
  check_uint64("ui boot input active sequence",
               apps[1].runtime.input_sequence, 1u);
  check_uint64("ui boot input inactive emitted",
               apps[0].runtime.emitted, 0u);
  check_uint64("ui boot input active emitted",
               apps[1].runtime.emitted, 1u);
  check_uint64("ui boot input inactive memory kind",
               memory_a[ER_UI_WASM_INPUT_KIND_OFFSET], 0u);
  check_uint64("ui boot input active abi",
               memory_b[ER_UI_WASM_INPUT_ABI_OFFSET],
               ER_UI_WASM_INPUT_ABI_VERSION);
  check_uint64("ui boot input active kind",
               memory_b[ER_UI_WASM_INPUT_KIND_OFFSET],
               ER_UI_WASM_INPUT_KIND_KEY);
  check_uint64("ui boot input active key",
               memory_b[ER_UI_WASM_INPUT_KEY_KIND_OFFSET],
               ER_UI_KEY_OTHER);
  check_uint64("ui boot input active codepoint",
               memory_b[ER_UI_WASM_INPUT_KEY_CODEPOINT_OFFSET],
               UI_BOOT_INPUT_CHAR);
  check_uint64("ui boot input active modifiers",
               memory_b[ER_UI_WASM_INPUT_MODIFIERS_OFFSET],
               ER_UI_WASM_INPUT_MODIFIER_CTRL);

  er_ui_scene_destroy(&apps[1].scene);
  er_ui_scene_destroy(&apps[0].scene);
  er_ui_scene_destroy(&scene);
  er_ui_runtime_state_destroy(&runtime);
  er_ui_ledger_app_state_destroy(&ledger_state);
}

static void test_ui_boot_package_loads_from_endpoint_storage(void) {
  enum {
    UI_BOOT_PACKAGE_TEST_APP_INDEX = 0u
  };
  UINT8 module_memory[ER_UI_BOOT_APP_MODULE_BYTES];
  UINT8 manifest_memory[ER_UI_BOOT_APP_MANIFEST_BYTES];
  ErUiBootPackageStorage storage;
  ErAppLoadedPackage loaded;
  const ErUiBootInstalledApp* installed_app;
  ErUiBootInstalledApp tampered_app;
  ErUiBootInstalledPackageSource source;
  ErUiBootInstalledPackageSource tampered_source;
  const ErAppSignedPackageIndexEntry* signed_index_entry;
  ErAppSignedPackageIndexEntry tampered_signed_index_entry;

  er_mem_zero(module_memory, (UINTN)sizeof(module_memory));
  er_mem_zero(manifest_memory, (UINTN)sizeof(manifest_memory));
  er_mem_zero((UINT8*)&storage, (UINTN)sizeof(storage));
  er_mem_zero((UINT8*)&loaded, (UINTN)sizeof(loaded));

  installed_app = er_ui_boot_installed_app_for_slot(UI_BOOT_PACKAGE_TEST_APP_INDEX);
  signed_index_entry = er_ui_boot_installed_signed_package_index_entry_for_slot(UI_BOOT_PACKAGE_TEST_APP_INDEX);
  check_int64("ui boot installed app present", installed_app != 0, 1);
  check_int64("ui boot installed signed package index present",
              signed_index_entry != 0, 1);
  check_int64("ui boot installed app rejects invalid slot",
              er_ui_boot_installed_app_for_slot(ER_UI_BOOT_INSTALLED_APP_COUNT) == 0, 1);
  check_int64("ui boot installed signed package index rejects invalid slot",
              er_ui_boot_installed_signed_package_index_entry_for_slot(ER_UI_BOOT_INSTALLED_APP_COUNT) == 0, 1);
  check_uint64("ui boot installed app len", installed_app->app_len,
               ER_USER_APP_WASM_SIZE);
  check_uint64("ui boot installed manifest len", installed_app->manifest_len,
               ER_USER_APP_MANIFEST_SIZE);
  check_int64("ui boot installed app ref abi",
              installed_app->app_ref.abi_version, ER_VFS_ABI_VERSION);
  check_int64("ui boot installed manifest ref abi",
              installed_app->manifest_ref.abi_version, ER_VFS_ABI_VERSION);
  check_int64("ui boot installed package abi",
              installed_app->package.abi_version, ER_APP_ABI_VERSION);
  check_uint64("ui boot installed package app len",
               installed_app->package.app_object_len, ER_USER_APP_WASM_SIZE);
  check_uint64("ui boot installed package manifest len",
               installed_app->package.manifest_object_len,
               ER_USER_APP_MANIFEST_SIZE);
  check_int64("ui boot installed signed index abi",
              signed_index_entry->abi_version, ER_APP_ABI_VERSION);
  check_int64("ui boot installed signed index kind",
              signed_index_entry->app_kind, ER_APP_KIND_USER);
  check_hash_equal("ui boot installed signed index package signature",
                   &signed_index_entry->package_signature.package_id,
                   &installed_app->package.package_id);
  check_uint64("ui boot installed index slot",
               signed_index_entry->index_entry.installed_slot,
               UI_BOOT_PACKAGE_TEST_APP_INDEX);
  check_hash_equal("ui boot installed index package",
                   &signed_index_entry->index_entry.package.package_id,
                   &installed_app->package.package_id);
  check_hash_equal("ui boot installed index app",
                   &signed_index_entry->index_entry.app_ref.object_id,
                   &installed_app->app_ref.object_id);
  check_hash_equal("ui boot installed index manifest",
                   &signed_index_entry->index_entry.manifest_ref.object_id,
                   &installed_app->manifest_ref.object_id);
  check_uint64("ui boot installed app byte", installed_app->app_bytes[0],
               g_edgerun_user_app_wasm[0]);
  check_uint64("ui boot installed manifest byte", installed_app->manifest_bytes[0],
               g_edgerun_user_app_manifest[0]);
  check_int64("ui boot installed package rejects missing descriptor",
              er_ui_boot_load_installed_app_package(0,
                                                    module_memory,
                                                    (UINT32)sizeof(module_memory),
                                                    manifest_memory,
                                                    (UINT32)sizeof(manifest_memory),
                                                    &storage,
                                                    UI_BOOT_PACKAGE_TEST_APP_INDEX,
                                                    &loaded),
              0);
  check_int64("ui boot installed source prepare",
              er_ui_boot_prepare_installed_package_source(installed_app,
                                                          UI_BOOT_PACKAGE_TEST_APP_INDEX,
                                                          &source),
              1);
  check_hash_equal("ui boot installed source package",
                   &source.storage_source.package_id,
                   &installed_app->package.package_id);
  check_int64("ui boot installed source rejects missing app",
              er_ui_boot_prepare_installed_package_source(0,
                                                          UI_BOOT_PACKAGE_TEST_APP_INDEX,
                                                          &source),
              0);
  check_int64("ui boot signed indexed source prepare",
              er_ui_boot_prepare_signed_indexed_package_source(signed_index_entry,
                                                               &source),
              1);
  tampered_signed_index_entry = *signed_index_entry;
  tampered_signed_index_entry.index_entry.package.package_id.bytes[0] ^= 1u;
  check_int64("ui boot signed indexed source rejects package mismatch",
              er_ui_boot_prepare_signed_indexed_package_source(
                  &tampered_signed_index_entry,
                  &source),
              0);
  tampered_signed_index_entry = *signed_index_entry;
  tampered_signed_index_entry.package_signature.signature.signature[0] ^= 1u;
  check_int64("ui boot signed indexed source rejects signature mismatch",
              er_ui_boot_prepare_signed_indexed_package_source(
                  &tampered_signed_index_entry,
                  &source),
              0);
  er_mem_zero((UINT8*)&storage, (UINTN)sizeof(storage));
  er_mem_zero((UINT8*)&loaded, (UINTN)sizeof(loaded));
  check_int64("ui boot package loads content source",
              er_ui_boot_load_installed_package_source(&source,
                                                       module_memory,
                                                       (UINT32)sizeof(module_memory),
                                                       manifest_memory,
                                                       (UINT32)sizeof(manifest_memory),
                                                       &storage,
                                                       &loaded),
              1);
  tampered_source = source;
  tampered_source.storage_source.source_id.bytes[0] ^= 1u;
  er_mem_zero((UINT8*)&storage, (UINTN)sizeof(storage));
  er_mem_zero((UINT8*)&loaded, (UINTN)sizeof(loaded));
  check_int64("ui boot package rejects source mismatch",
              er_ui_boot_load_installed_package_source(&tampered_source,
                                                       module_memory,
                                                       (UINT32)sizeof(module_memory),
                                                       manifest_memory,
                                                       (UINT32)sizeof(manifest_memory),
                                                       &storage,
                                                       &loaded),
              0);
  tampered_source = source;
  tampered_source.package_signature.package_id.bytes[0] ^= 1u;
  er_mem_zero((UINT8*)&storage, (UINTN)sizeof(storage));
  er_mem_zero((UINT8*)&loaded, (UINTN)sizeof(loaded));
  check_int64("ui boot package rejects source signature mismatch",
              er_ui_boot_load_installed_package_source(&tampered_source,
                                                       module_memory,
                                                       (UINT32)sizeof(module_memory),
                                                       manifest_memory,
                                                       (UINT32)sizeof(manifest_memory),
                                                       &storage,
                                                       &loaded),
              0);
  tampered_app = *installed_app;
  tampered_app.app_ref.object_id.bytes[0] ^= 1u;
  er_mem_zero((UINT8*)&storage, (UINTN)sizeof(storage));
  er_mem_zero((UINT8*)&loaded, (UINTN)sizeof(loaded));
  check_int64("ui boot package rejects app ref mismatch",
              er_ui_boot_load_installed_app_package(&tampered_app,
                                                    module_memory,
                                                    (UINT32)sizeof(module_memory),
                                                    manifest_memory,
                                                    (UINT32)sizeof(manifest_memory),
                                                    &storage,
                                                    UI_BOOT_PACKAGE_TEST_APP_INDEX,
                                                    &loaded),
              0);
  tampered_app = *installed_app;
  tampered_app.package.package_id.bytes[0] ^= 1u;
  er_mem_zero((UINT8*)&storage, (UINTN)sizeof(storage));
  er_mem_zero((UINT8*)&loaded, (UINTN)sizeof(loaded));
  check_int64("ui boot package rejects package mismatch",
              er_ui_boot_load_installed_app_package(&tampered_app,
                                                    module_memory,
                                                    (UINT32)sizeof(module_memory),
                                                    manifest_memory,
                                                    (UINT32)sizeof(manifest_memory),
                                                    &storage,
                                                    UI_BOOT_PACKAGE_TEST_APP_INDEX,
                                                    &loaded),
              0);
  er_mem_zero((UINT8*)&storage, (UINTN)sizeof(storage));
  er_mem_zero((UINT8*)&loaded, (UINTN)sizeof(loaded));

  check_int64("ui boot package endpoint load",
              er_ui_boot_load_user_app_package(module_memory,
                                               (UINT32)sizeof(module_memory),
                                               manifest_memory,
                                               (UINT32)sizeof(manifest_memory),
                                               &storage,
                                               UI_BOOT_PACKAGE_TEST_APP_INDEX,
                                               &loaded),
              1);
  check_uint64("ui boot package app store complete",
               storage.app_store.complete, 1u);
  check_uint64("ui boot package manifest store complete",
               storage.manifest_store.complete, 1u);
  check_uint64("ui boot package app store packets",
               storage.app_store.accepted_packet_count,
               ER_UI_BOOT_PACKAGE_OBJECT_PACKET_CAPACITY);
  check_uint64("ui boot package manifest store packets",
               storage.manifest_store.accepted_packet_count,
               ER_UI_BOOT_PACKAGE_OBJECT_PACKET_CAPACITY);
  check_uint64("ui boot package loaded app len", loaded.app_len,
               ER_USER_APP_WASM_SIZE);
  check_uint64("ui boot package loaded manifest len", loaded.manifest_len,
               ER_USER_APP_MANIFEST_SIZE);
  check_uint64("ui boot package app byte", loaded.app_bytes[0],
               g_edgerun_user_app_wasm[0]);
  check_uint64("ui boot package manifest byte", loaded.manifest_bytes[0],
               g_edgerun_user_app_manifest[0]);
}
