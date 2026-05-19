#include "er_ui_wasm_app.h"
#include "er_crypto_blake3.h"
#include "er_mem.h"

#define ER_UI_WASM_U32_BYTE0 0u
#define ER_UI_WASM_U32_BYTE1 1u
#define ER_UI_WASM_U32_BYTE2 2u
#define ER_UI_WASM_U32_BYTE3 3u
#define ER_UI_WASM_U32_BYTE1_SHIFT 8u
#define ER_UI_WASM_U32_BYTE2_SHIFT 16u
#define ER_UI_WASM_U32_BYTE3_SHIFT 24u
#define ER_UI_WASM_U64_HIGH_OFFSET 4u
#define ER_UI_WASM_U64_HIGH_SHIFT 32u
#define ER_UI_WASM_U8_MASK 0xffu
#define ER_UI_WASM_U32_MASK 0xffffffffu

static void er_ui_wasm_app_store_u32(UINT8* dst, UINT32 value) {
  dst[ER_UI_WASM_U32_BYTE0] = (UINT8)(value & ER_UI_WASM_U8_MASK);
  dst[ER_UI_WASM_U32_BYTE1] =
    (UINT8)((value >> ER_UI_WASM_U32_BYTE1_SHIFT) & ER_UI_WASM_U8_MASK);
  dst[ER_UI_WASM_U32_BYTE2] =
    (UINT8)((value >> ER_UI_WASM_U32_BYTE2_SHIFT) & ER_UI_WASM_U8_MASK);
  dst[ER_UI_WASM_U32_BYTE3] =
    (UINT8)((value >> ER_UI_WASM_U32_BYTE3_SHIFT) & ER_UI_WASM_U8_MASK);
}

static void er_ui_wasm_app_store_u64(UINT8* dst, UINT64 value) {
  er_ui_wasm_app_store_u32(dst, (UINT32)(value & ER_UI_WASM_U32_MASK));
  er_ui_wasm_app_store_u32(dst + ER_UI_WASM_U64_HIGH_OFFSET,
                           (UINT32)(value >> ER_UI_WASM_U64_HIGH_SHIFT));
}

static UINT32 er_ui_wasm_app_modifier_bits(er_ui_key_modifiers_t modifiers) {
  UINT32 bits = 0u;

  if (modifiers.shift) {
    bits |= ER_UI_WASM_INPUT_MODIFIER_SHIFT;
  }
  if (modifiers.ctrl) {
    bits |= ER_UI_WASM_INPUT_MODIFIER_CTRL;
  }
  if (modifiers.alt) {
    bits |= ER_UI_WASM_INPUT_MODIFIER_ALT;
  }
  if (modifiers.meta) {
    bits |= ER_UI_WASM_INPUT_MODIFIER_META;
  }
  return bits;
}

static int er_ui_wasm_app_memory_window(const ErUiWasmAppRuntime* runtime, UINT32 base,
                                        UINT32 len, UINT8** out_bytes) {
  UINT64 end;

  if (runtime == 0 || runtime->memory == 0 || out_bytes == 0 || len == 0u) {
    return -1;
  }
  end = (UINT64)base + (UINT64)len;
  if (end > (UINT64)runtime->memory_size) {
    return -1;
  }
  *out_bytes = runtime->memory + base;
  return 0;
}

static UINT32 er_ui_wasm_app_next_input_sequence(UINT32 current) {
  if (current == ER_UI_WASM_INPUT_SEQUENCE_MAX) {
    return 1u;
  }
  return current + 1u;
}

static ErEpochClockModifier er_ui_wasm_app_effective_modifier(ErEpochClockModifier modifier) {
  if (modifier.tick_stride == 0u) {
    return er_epoch_clock_default_modifier();
  }
  return modifier;
}

static UINT8 er_ui_wasm_app_stats_equal(er_ui_scene_stats_t left,
                                        er_ui_scene_stats_t right) {
  return (UINT8)(left.rects == right.rects &&
                 left.hits == right.hits &&
                 left.drag_sources == right.drag_sources &&
                 left.drop_targets == right.drop_targets &&
                 left.transitions == right.transitions &&
                 left.icon_quads == right.icon_quads &&
                 left.text_quads == right.text_quads);
}

UINT8 er_ui_wasm_app_prepare_render_route(const ErAppUiPresentation* presentation,
                                          ErAdmittedRoute* out_route) {
  if (presentation == 0 || out_route == 0 ||
      presentation->abi_version != ER_APP_ABI_VERSION) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_route, (UINTN)sizeof(*out_route));
  out_route->abi_version = ER_WORK_ABI_VERSION;
  out_route->role = ER_NODE_ROLE_CAPABILITY;
  out_route->route_id = presentation->route_hash;
  out_route->request_hash = presentation->presentation_id;
  out_route->admission_hash = presentation->admission_id;
  out_route->source_node_id = presentation->app_node_id;
  out_route->target_node_id = presentation->ui_relay_node_id;
  out_route->relay_node_id = presentation->ui_relay_node_id;
  out_route->channel_id = presentation->presentation_id;
  out_route->relay_count = 1u;
  out_route->department = ER_DEPARTMENT_CAPABILITY;
  out_route->work_type = ER_WORK_TYPE_CAPABILITY_INVOKE;
  out_route->admission_route_commitment = presentation->route_hash;
  out_route->target_route_commitment = presentation->route_hash;
  out_route->policy_hash = presentation->jurisdiction_id;
  out_route->admitted_budget = presentation->max_rects + presentation->max_hits +
                               presentation->max_drag_sources +
                               presentation->max_drop_targets +
                               presentation->max_transitions +
                               presentation->max_icon_quads +
                               presentation->max_text_quads;
  out_route->valid_until_ms = presentation->sequence;
  out_route->relay_path[0] = presentation->ui_relay_node_id;
  return (UINT8)(out_route->admitted_budget != 0u);
}

static UINT8 er_ui_wasm_app_prepare_render_envelope(const ErAppUiPresentation* presentation,
                                                    const ErHash* scene_hash,
                                                    ErChannelEnvelopeHeader* out_envelope) {
  if (presentation == 0 || scene_hash == 0 || out_envelope == 0) {
    return 0u;
  }
  er_mem_zero((UINT8*)out_envelope, (UINTN)sizeof(*out_envelope));
  out_envelope->abi_version = ER_WORK_ABI_VERSION;
  out_envelope->packet_kind = ER_WORK_TYPE_CAPABILITY_INVOKE;
  out_envelope->channel_id = presentation->presentation_id;
  out_envelope->from = presentation->app_node_id;
  out_envelope->to = presentation->ui_relay_node_id;
  out_envelope->route_hash = presentation->route_hash;
  out_envelope->packet_hash = *scene_hash;
  out_envelope->sequence = presentation->sequence;
  out_envelope->previous_message_hash = presentation->jurisdiction_id;
  return 1u;
}

static UINT8 er_ui_wasm_app_decode_render_endpoint(ErUiWasmAppRuntime* runtime,
                                                   const UINT8* bytes,
                                                   UINT32 len,
                                                   const er_ui_scene_stats_t* stats) {
  ErCryptoProvider crypto;
  ErHash scene_hash;
  ErAdmittedRoute route;
  ErChannelEnvelopeHeader envelope;
  ErCapabilityEnvelopeHeader capability;

  if (runtime == 0 || runtime->presentation == 0 || runtime->scene == 0 ||
      bytes == 0 || len == 0u || stats == 0) {
    return 0u;
  }
  er_crypto_blake3_provider(&crypto);
  if (er_render_endpoint_scene_payload_hash(&crypto, bytes, len,
                                            &scene_hash) == 0u ||
      er_ui_wasm_app_prepare_render_route(runtime->presentation,
                                          &route) == 0u ||
      er_ui_wasm_app_prepare_render_envelope(runtime->presentation,
                                             &scene_hash, &envelope) == 0u ||
      er_work_prepare_capability_envelope_header(ER_CAPABILITY_PACKET_INVOKE,
                                                 ER_WORK_TYPE_CAPABILITY_INVOKE,
                                                 ER_CAPABILITY_CONTENT_RENDER,
                                                 ER_CAPABILITY_RISK_NONE,
                                                 &runtime->presentation->jurisdiction_id,
                                                 &runtime->presentation->presentation_id,
                                                 &runtime->presentation->admission_id,
                                                 &runtime->presentation->app_node_id,
                                                 &runtime->presentation->ui_relay_node_id,
                                                 runtime->presentation->sequence,
                                                 runtime->settlement_clock.now.tick + 1u,
                                                 &scene_hash, len,
                                                 &capability) == 0u ||
      er_render_endpoint_capture(&crypto, &route, &envelope, &capability,
                                 &runtime->last_render_capture) == 0u ||
      er_render_endpoint_decode_scene_payload(&crypto, &runtime->last_render_capture,
                                              bytes, len, runtime->scene,
                                              &runtime->last_render_scene) == 0u ||
      er_ui_wasm_app_stats_equal(runtime->last_render_scene.scene_stats,
                                 *stats) == 0u) {
    return 0u;
  }
  runtime->emitted_stats = runtime->last_render_scene.scene_stats;
  return 1u;
}

static int er_ui_wasm_app_prepare_input_window(ErUiWasmAppRuntime* runtime,
                                               UINT32 len, UINT8** out_inbox) {
  if (runtime == 0 || len == 0u || runtime->prepared == 0u ||
      len > runtime->relay_inbox_len ||
      er_ui_wasm_app_memory_window(runtime, runtime->relay_inbox_base,
                                   runtime->relay_inbox_len, out_inbox) != 0) {
    return -1;
  }
  return 0;
}

static void er_ui_wasm_app_stamp_epoch_input(UINT8* bytes,
                                             ErEpochStamp epoch) {
  er_ui_wasm_app_store_u64(bytes + ER_UI_WASM_INPUT_EPOCH_TICK_OFFSET, epoch.tick);
  er_ui_wasm_app_store_u64(bytes + ER_UI_WASM_INPUT_EPOCH_SLOT_OFFSET, epoch.slot);
  er_ui_wasm_app_store_u64(bytes + ER_UI_WASM_INPUT_EPOCH_EPOCH_OFFSET, epoch.epoch);
  er_ui_wasm_app_store_u64(bytes + ER_UI_WASM_INPUT_EPOCH_ERA_OFFSET, epoch.era);
}

static int er_ui_wasm_app_commit_prepared_input(ErUiWasmAppRuntime* runtime,
                                                UINT8* inbox, const UINT8* bytes,
                                                UINT32 len, UINT32 sequence,
                                                ErEpochStamp epoch) {
  if (runtime == 0 || inbox == 0 || bytes == 0 || len == 0u) {
    return -1;
  }
  er_mem_zero(inbox, (UINTN)runtime->relay_inbox_len);
  er_mem_copy(inbox, bytes, (UINTN)len);
  runtime->last_input_epoch = epoch;
  runtime->input_len = len;
  runtime->input_sequence = sequence;
  return 0;
}

static int er_ui_wasm_app_commit_input(ErUiWasmAppRuntime* runtime,
                                       const UINT8* bytes, UINT32 len,
                                       UINT32 sequence) {
  UINT8* inbox = 0;
  ErEpochStamp epoch;

  if (bytes == 0) {
    return -1;
  }
  if (er_ui_wasm_app_prepare_input_window(runtime, len, &inbox) != 0) {
    return -1;
  }
  if (er_epoch_clock_advance_with_modifier(&runtime->settlement_clock,
                                           &runtime->input_epoch_modifier, 0) == 0u) {
    return -1;
  }
  epoch = runtime->settlement_clock.now;
  return er_ui_wasm_app_commit_prepared_input(runtime, inbox, bytes, len, sequence,
                                             epoch);
}

static INT64 er_ui_wasm_app_emit_host(void* user, const UINT8* bytes, UINT32 len,
                                      const er_ui_scene_stats_t* stats) {
  ErUiWasmAppRuntime* runtime = (ErUiWasmAppRuntime*)user;

  if (bytes == 0 || stats == 0 || runtime == 0 || runtime->scene == 0) {
    return -1;
  }
  if (er_ui_wasm_app_decode_render_endpoint(runtime, bytes, len, stats) == 0u) {
    return -1;
  }
  runtime->emitted = 1u;
  return (INT64)(UINT64)len;
}

int er_ui_wasm_app_prepare(const UINT8* module_data, UINT32 module_size,
                           const ErWasmHostCalls* host_template,
                           ErUiWasmAppRuntime* runtime) {
  ErWasmHostCalls host;
  ErWasmLinearMemory linear_memory;
  ErEpochClockLimits clock_limits;

  if (module_data == 0 || module_size == 0u || host_template == 0 ||
      runtime == 0 || runtime->memory == 0 || runtime->memory_size == 0u ||
      runtime->presentation == 0 || runtime->scene == 0 ||
      runtime->prepared != 0u) {
    return -1;
  }
  er_mem_zero(runtime->memory, (UINTN)runtime->memory_size);
  er_mem_zero((UINT8*)&runtime->emitted_stats, (UINTN)sizeof(runtime->emitted_stats));
  er_mem_zero((UINT8*)&runtime->last_input_epoch, (UINTN)sizeof(runtime->last_input_epoch));
  er_mem_zero((UINT8*)&runtime->last_execute_epoch, (UINTN)sizeof(runtime->last_execute_epoch));
  er_mem_zero((UINT8*)&runtime->last_render_capture, (UINTN)sizeof(runtime->last_render_capture));
  er_mem_zero((UINT8*)&runtime->last_render_scene, (UINTN)sizeof(runtime->last_render_scene));
  clock_limits = er_epoch_clock_default_limits();
  if (er_epoch_clock_init(&clock_limits, &runtime->settlement_clock) == 0u) {
    return -1;
  }
  runtime->input_epoch_modifier =
    er_ui_wasm_app_effective_modifier(runtime->input_epoch_modifier);
  runtime->execute_epoch_modifier =
    er_ui_wasm_app_effective_modifier(runtime->execute_epoch_modifier);
  runtime->input_len = 0u;
  runtime->input_sequence = 0u;
  runtime->emitted = 0u;
  if (er_wasm_prepare_linear_memory(runtime->memory, runtime->memory_size,
                                    runtime->relay_inbox_base,
                                    runtime->relay_inbox_len,
                                    runtime->relay_outbox_base,
                                    runtime->relay_outbox_len,
                                    &linear_memory) != 0) {
    return -1;
  }

  host = *host_template;
  host.linear_memory = linear_memory;
  host.memory = runtime->memory;
  host.memory_size = runtime->memory_size;
  host.ui_emit = er_ui_wasm_app_emit_host;
  host.ui_emit_user = runtime;
  host.ui_presentation = runtime->presentation;

  if (er_wasm_init(&runtime->module, module_data, module_size, &host) != 0 ||
      er_wasm_validate_contract(&runtime->module, ER_WASM_MODULE_CONTRACT_UI_APP) != 0 ||
      er_wasm_find_main(&runtime->module, &runtime->main_index) != 0) {
    return -1;
  }
  runtime->prepared = 1u;
  return 0;
}

int er_ui_wasm_app_deliver_input(ErUiWasmAppRuntime* runtime, const UINT8* bytes,
                                 UINT32 len) {
  UINT32 sequence;

  if (runtime == 0) {
    return -1;
  }
  sequence = er_ui_wasm_app_next_input_sequence(runtime->input_sequence);
  return er_ui_wasm_app_commit_input(runtime, bytes, len, sequence);
}

int er_ui_wasm_app_deliver_key_input(ErUiWasmAppRuntime* runtime, er_ui_key_t key,
                                     er_ui_key_modifiers_t modifiers) {
  UINT8 packet[ER_UI_WASM_INPUT_PACKET_LEN];
  UINT8* inbox = 0;
  UINT32 sequence;
  ErEpochStamp epoch;

  if (runtime == 0 || key.kind > ER_UI_KEY_OTHER) {
    return -1;
  }
  if (er_ui_wasm_app_prepare_input_window(runtime, (UINT32)sizeof(packet), &inbox) != 0) {
    return -1;
  }
  sequence = er_ui_wasm_app_next_input_sequence(runtime->input_sequence);
  if (er_epoch_clock_advance_with_modifier(&runtime->settlement_clock,
                                           &runtime->input_epoch_modifier, 0) == 0u) {
    return -1;
  }
  epoch = runtime->settlement_clock.now;
  er_mem_zero(packet, (UINTN)sizeof(packet));
  er_ui_wasm_app_store_u32(packet + ER_UI_WASM_INPUT_ABI_OFFSET,
                           ER_UI_WASM_INPUT_ABI_VERSION);
  er_ui_wasm_app_store_u32(packet + ER_UI_WASM_INPUT_KIND_OFFSET,
                           (UINT32)ER_UI_WASM_INPUT_KIND_KEY);
  er_ui_wasm_app_store_u32(packet + ER_UI_WASM_INPUT_KEY_KIND_OFFSET,
                           (UINT32)key.kind);
  er_ui_wasm_app_store_u32(packet + ER_UI_WASM_INPUT_KEY_CODEPOINT_OFFSET,
                           key.codepoint);
  er_ui_wasm_app_store_u32(packet + ER_UI_WASM_INPUT_MODIFIERS_OFFSET,
                           er_ui_wasm_app_modifier_bits(modifiers));
  er_ui_wasm_app_store_u32(packet + ER_UI_WASM_INPUT_SEQUENCE_OFFSET, sequence);
  er_ui_wasm_app_stamp_epoch_input(packet, epoch);
  return er_ui_wasm_app_commit_prepared_input(runtime, inbox, packet,
                                             (UINT32)sizeof(packet), sequence,
                                             epoch);
}

int er_ui_wasm_app_execute(ErUiWasmAppRuntime* runtime, INT64* out_result) {
  INT64 result = 0;

  if (runtime == 0 || out_result == 0 || runtime->prepared == 0u ||
      runtime->scene == 0) {
    return -1;
  }
  er_ui_scene_clear_commands(runtime->scene);
  er_mem_zero((UINT8*)&runtime->emitted_stats, (UINTN)sizeof(runtime->emitted_stats));
  er_mem_zero((UINT8*)&runtime->last_render_capture, (UINTN)sizeof(runtime->last_render_capture));
  er_mem_zero((UINT8*)&runtime->last_render_scene, (UINTN)sizeof(runtime->last_render_scene));
  runtime->emitted = 0u;
  if (er_wasm_execute_i64(&runtime->module, runtime->main_index, &result) != 0 ||
      runtime->emitted == 0u) {
    return -1;
  }
  if (er_epoch_clock_advance_with_modifier(&runtime->settlement_clock,
                                           &runtime->execute_epoch_modifier, 0) == 0u) {
    return -1;
  }
  runtime->last_execute_epoch = runtime->settlement_clock.now;
  *out_result = result;
  return 0;
}

int er_ui_wasm_app_run(const UINT8* module_data, UINT32 module_size,
                       const ErWasmHostCalls* host_template,
                       ErUiWasmAppRuntime* runtime, INT64* out_result) {
  if (er_ui_wasm_app_prepare(module_data, module_size, host_template, runtime) != 0) {
    return -1;
  }
  return er_ui_wasm_app_execute(runtime, out_result);
}
