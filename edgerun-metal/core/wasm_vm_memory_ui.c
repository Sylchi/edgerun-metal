#include "wasm_vm_internal.h"

static int er_wasm_linear_window_valid(UINT32 address_base, UINT32 address_len,
                                       UINT32 window_base, UINT32 window_len) {
  UINT64 address_end;

  if (window_len == 0u) {
    return 0;
  }
  address_end = (UINT64)address_base + (UINT64)address_len;
  if ((UINT64)window_base < (UINT64)address_base || (UINT64)window_base > address_end) {
    return 0;
  }
  if (address_end - (UINT64)window_base < (UINT64)window_len) {
    return 0;
  }
  return 1;
}

static int er_wasm_linear_windows_overlap(UINT32 a_base, UINT32 a_len,
                                          UINT32 b_base, UINT32 b_len) {
  UINT64 a_end = (UINT64)a_base + (UINT64)a_len;
  UINT64 b_end = (UINT64)b_base + (UINT64)b_len;

  if (a_end <= (UINT64)b_base || b_end <= (UINT64)a_base) {
    return 0;
  }
  return 1;
}

int er_wasm_linear_memory_valid(const ErWasmLinearMemory* memory) {
  if (memory == 0 || memory->bytes == 0 ||
      memory->address_base != ER_WASM_LINEAR_MEMORY_BASE ||
      memory->address_len == 0u) {
    return 0;
  }
  if (er_wasm_linear_window_valid(memory->address_base, memory->address_len,
                                  memory->relay_inbox_base,
                                  memory->relay_inbox_len) == 0 ||
      er_wasm_linear_window_valid(memory->address_base, memory->address_len,
                                  memory->relay_outbox_base,
                                  memory->relay_outbox_len) == 0) {
    return 0;
  }
  if (er_wasm_linear_windows_overlap(memory->relay_inbox_base,
                                     memory->relay_inbox_len,
                                     memory->relay_outbox_base,
                                     memory->relay_outbox_len) != 0) {
    return 0;
  }
  return 1;
}

int er_wasm_prepare_linear_memory(UINT8* bytes, UINT32 address_len,
                                  UINT32 relay_inbox_base, UINT32 relay_inbox_len,
                                  UINT32 relay_outbox_base, UINT32 relay_outbox_len,
                                  ErWasmLinearMemory* out_memory) {
  if (bytes == 0 || address_len == 0u || out_memory == 0) {
    return -1;
  }
  if (er_wasm_linear_window_valid(ER_WASM_LINEAR_MEMORY_BASE, address_len,
                                  relay_inbox_base, relay_inbox_len) == 0 ||
      er_wasm_linear_window_valid(ER_WASM_LINEAR_MEMORY_BASE, address_len,
                                  relay_outbox_base, relay_outbox_len) == 0) {
    return -1;
  }
  if (er_wasm_linear_windows_overlap(relay_inbox_base, relay_inbox_len,
                                     relay_outbox_base, relay_outbox_len) != 0) {
    return -1;
  }
  er_mem_zero((UINT8*)out_memory, (UINTN)sizeof(*out_memory));
  out_memory->bytes = bytes;
  out_memory->address_base = ER_WASM_LINEAR_MEMORY_BASE;
  out_memory->address_len = address_len;
  out_memory->relay_inbox_base = relay_inbox_base;
  out_memory->relay_inbox_len = relay_inbox_len;
  out_memory->relay_outbox_base = relay_outbox_base;
  out_memory->relay_outbox_len = relay_outbox_len;
  return 0;
}

int er_wasm_linear_memory_public_region(const ErWasmLinearMemory* memory, UINT32 region_id,
                                        UINT32* out_base, UINT32* out_len) {
  UINT32 base = 0u;
  UINT32 len = 0u;

  if (memory == 0 || out_base == 0 || out_len == 0 ||
      er_wasm_linear_memory_valid(memory) == 0) {
    return -1;
  }

  switch (region_id) {
    case ER_WASM_PUBLIC_REGION_RELAY_INBOX:
      base = memory->relay_inbox_base;
      len = memory->relay_inbox_len;
      break;
    case ER_WASM_PUBLIC_REGION_RELAY_OUTBOX:
      base = memory->relay_outbox_base;
      len = memory->relay_outbox_len;
      break;
    default:
      return -1;
  }

  *out_base = base;
  *out_len = len;
  return 0;
}

int er_wasm_memory_range(ErWasmModule* module, UINT64 offset, UINT32 len, UINT8** out_bytes) {
  UINT64 address_end;

  if (module == 0 || out_bytes == 0 || module->linear_memory.bytes == 0 || len == 0u) {
    return -1;
  }
  address_end = (UINT64)module->linear_memory.address_base + (UINT64)module->linear_memory.address_len;
  if (offset < (UINT64)module->linear_memory.address_base ||
      offset > address_end || address_end - offset < (UINT64)len) {
    return -1;
  }
  *out_bytes = &module->linear_memory.bytes[(UINT32)(offset - module->linear_memory.address_base)];
  return 0;
}

int er_wasm_memory_window_range(ErWasmModule* module, UINT64 offset, UINT32 len,
                                       UINT32 window_base, UINT32 window_len,
                                       UINT8** out_bytes) {
  UINT64 window_end = (UINT64)window_base + (UINT64)window_len;

  if (module == 0 || out_bytes == 0 || len == 0u || window_len == 0u) {
    return -1;
  }
  if (offset < (UINT64)window_base || offset > window_end ||
      window_end - offset < (UINT64)len) {
    return -1;
  }
  return er_wasm_memory_range(module, offset, len, out_bytes);
}

UINT32 er_wasm_load_u32(const UINT8* src) {
  return (UINT32)src[ER_WASM_U32_BYTE0] |
         ((UINT32)src[ER_WASM_U32_BYTE1] << ER_WASM_U32_BYTE1_SHIFT) |
         ((UINT32)src[ER_WASM_U32_BYTE2] << ER_WASM_U32_BYTE2_SHIFT) |
         ((UINT32)src[ER_WASM_U32_BYTE3] << ER_WASM_U32_BYTE3_SHIFT);
}

float er_wasm_load_f32(const UINT8* src) {
  union {
    UINT32 bits;
    float value;
  } loaded;

  loaded.bits = er_wasm_load_u32(src);
  return loaded.value;
}

UINT64 er_wasm_load_u64(const UINT8* src) {
  return (UINT64)er_wasm_load_u32(src) |
         ((UINT64)er_wasm_load_u32(src + ER_WASM_U32_BYTES) << ER_WASM_U64_HIGH32_SHIFT);
}

UINT16 er_wasm_load_u16(const UINT8* src) {
  return (UINT16)src[ER_WASM_U32_BYTE0] |
         (UINT16)((UINT16)src[ER_WASM_U32_BYTE1] << ER_WASM_U32_BYTE1_SHIFT);
}

static int er_wasm_checked_add_u32(UINT32 left, UINT32 right, UINT32* out_value) {
  if (out_value == 0 || left > ER_WASM_U32_MASK - right) {
    return -1;
  }
  *out_value = left + right;
  return 0;
}

static int er_wasm_checked_mul_u32(UINT32 left, UINT32 right, UINT32* out_value) {
  if (out_value == 0 || (right != 0u && left > ER_WASM_U32_MASK / right)) {
    return -1;
  }
  *out_value = left * right;
  return 0;
}

static int er_wasm_add_record_span(UINT32 count, UINT32 record_len, UINT32* inout_len) {
  UINT32 bytes = 0;

  if (inout_len == 0 ||
      er_wasm_checked_mul_u32(count, record_len, &bytes) != 0 ||
      er_wasm_checked_add_u32(*inout_len, bytes, inout_len) != 0) {
    return -1;
  }
  return 0;
}

static int er_wasm_u32_in_range(UINT32 value, UINT32 min_value, UINT32 max_value) {
  if (value < min_value || value > max_value) {
    return -1;
  }
  return 0;
}

static int er_wasm_float_bits_finite(UINT32 bits) {
  if ((bits & ER_WASM_FLOAT_EXPONENT_MASK) == ER_WASM_FLOAT_EXPONENT_MASK) {
    return -1;
  }
  return 0;
}

static int er_wasm_validate_float_record(const UINT8* bytes, UINT32 len,
                                         UINT32 float_bytes_begin,
                                         UINT32 float_bytes_end) {
  UINT32 offset = float_bytes_begin;

  if (bytes == 0 || float_bytes_begin > float_bytes_end || float_bytes_end > len) {
    return -1;
  }
  while (offset < float_bytes_end) {
    if (float_bytes_end - offset < ER_WASM_UI_RECORD_FLOAT_BYTES ||
        er_wasm_float_bits_finite(er_wasm_load_u32(bytes + offset)) != 0) {
      return -1;
    }
    offset += ER_WASM_UI_RECORD_FLOAT_BYTES;
  }
  return 0;
}

static int er_wasm_validate_ui_rect_record(const UINT8* bytes) {
  if (bytes == 0 ||
      er_wasm_validate_float_record(bytes, ER_WASM_UI_RECT_RECORD_LEN, 0u,
                                    ER_WASM_UI_RECT_RECORD_MODE_OFFSET) != 0 ||
      er_wasm_u32_in_range(er_wasm_load_u32(bytes + ER_WASM_UI_RECT_RECORD_MODE_OFFSET),
                           ER_WASM_UI_RECT_MODE_MIN, ER_WASM_UI_RECT_MODE_MAX) != 0 ||
      er_wasm_validate_float_record(bytes, ER_WASM_UI_RECT_RECORD_LEN,
                                    ER_WASM_UI_RECT_RECORD_MODE_OFFSET +
                                      ER_WASM_U32_BYTES,
                                    ER_WASM_UI_RECT_RECORD_LEN) != 0) {
    return -1;
  }
  return 0;
}

static int er_wasm_validate_ui_hit_record(const UINT8* bytes) {
  if (bytes == 0 ||
      er_wasm_u32_in_range(er_wasm_load_u32(bytes + ER_WASM_UI_HIT_RECORD_KIND_OFFSET),
                           ER_WASM_UI_HIT_KIND_MIN, ER_WASM_UI_HIT_KIND_MAX) != 0 ||
      er_wasm_validate_float_record(bytes, ER_WASM_UI_HIT_RECORD_LEN,
                                    ER_WASM_UI_HIT_RECORD_FLOAT_OFFSET,
                                    ER_WASM_UI_HIT_RECORD_LEN) != 0) {
    return -1;
  }
  return 0;
}

static int er_wasm_validate_ui_drag_source_record(const UINT8* bytes) {
  if (bytes == 0 ||
      er_wasm_validate_float_record(bytes, ER_WASM_UI_DRAG_SOURCE_RECORD_LEN,
                                    ER_WASM_UI_DRAG_SOURCE_RECORD_FLOAT_OFFSET,
                                    ER_WASM_UI_DRAG_SOURCE_RECORD_LEN) != 0) {
    return -1;
  }
  return 0;
}

static int er_wasm_validate_ui_drop_target_record(const UINT8* bytes) {
  if (bytes == 0 ||
      er_wasm_validate_float_record(bytes, ER_WASM_UI_DROP_TARGET_RECORD_LEN,
                                    ER_WASM_UI_DROP_TARGET_RECORD_FLOAT_OFFSET,
                                    ER_WASM_UI_DROP_TARGET_RECORD_LEN) != 0) {
    return -1;
  }
  return 0;
}

static int er_wasm_validate_ui_transition_record(const UINT8* bytes) {
  if (bytes == 0 ||
      er_wasm_u32_in_range(er_wasm_load_u32(bytes + ER_WASM_UI_TRANSITION_RECORD_PROPERTY_OFFSET),
                           ER_WASM_UI_TRANSITION_PROPERTY_MIN,
                           ER_WASM_UI_TRANSITION_PROPERTY_MAX) != 0 ||
      er_wasm_validate_float_record(bytes, ER_WASM_UI_TRANSITION_RECORD_LEN,
                                    ER_WASM_UI_TRANSITION_RECORD_FLOAT_OFFSET,
                                    ER_WASM_UI_TRANSITION_RECORD_DURATION_OFFSET) != 0 ||
      er_wasm_u32_in_range(er_wasm_load_u32(bytes + ER_WASM_UI_TRANSITION_RECORD_EASING_OFFSET),
                           ER_WASM_UI_TRANSITION_EASING_MIN,
                           ER_WASM_UI_TRANSITION_EASING_MAX) != 0) {
    return -1;
  }
  return 0;
}

static int er_wasm_validate_ui_quad_record(const UINT8* bytes) {
  if (bytes == 0 ||
      er_wasm_validate_float_record(bytes, ER_WASM_UI_QUAD_RECORD_LEN, 0u,
                                    ER_WASM_UI_QUAD_RECORD_ATLAS_ID_OFFSET) != 0 ||
      er_wasm_validate_float_record(bytes, ER_WASM_UI_QUAD_RECORD_LEN,
                                    ER_WASM_UI_QUAD_RECORD_ATLAS_ID_OFFSET +
                                      ER_WASM_U32_BYTES,
                                    ER_WASM_UI_QUAD_RECORD_LEN) != 0) {
    return -1;
  }
  return 0;
}

static int er_wasm_validate_records(const UINT8* bytes, UINT32 count, UINT32 record_len,
                                    int (*validate_record)(const UINT8*)) {
  UINT32 index = 0;

  if (bytes == 0 || validate_record == 0) {
    return -1;
  }
  for (index = 0; index < count; index++) {
    if (validate_record(bytes + (index * record_len)) != 0) {
      return -1;
    }
  }
  return 0;
}

int er_wasm_ui_command_stats(const UINT8* bytes, UINT32 len,
                             er_ui_scene_stats_t* out_stats) {
  UINT64 command_count;
  UINT64 summed_count;
  UINT32 expected_len = ER_WASM_UI_COMMAND_LIST_HEADER_LEN;
  ErWasmUiCommandCounts counts;
  UINT32 offset = ER_WASM_UI_COMMAND_LIST_HEADER_LEN;

  if (bytes == 0 || out_stats == 0 || len < ER_WASM_UI_COMMAND_LIST_HEADER_LEN) {
    return -1;
  }
  if (er_wasm_load_u16(bytes + ER_WASM_UI_HEADER_ABI_OFFSET) !=
      ER_WASM_UI_COMMAND_ABI_VERSION) {
    return -1;
  }

  er_mem_zero((UINT8*)out_stats, (UINTN)sizeof(*out_stats));
  er_mem_zero((UINT8*)&counts, (UINTN)sizeof(counts));
  command_count = (UINT64)er_wasm_load_u32(bytes + ER_WASM_UI_HEADER_COMMAND_COUNT_OFFSET);
  counts.rects = er_wasm_load_u32(bytes + ER_WASM_UI_HEADER_RECT_COUNT_OFFSET);
  counts.hits = er_wasm_load_u32(bytes + ER_WASM_UI_HEADER_HIT_COUNT_OFFSET);
  counts.drag_sources = er_wasm_load_u32(bytes + ER_WASM_UI_HEADER_DRAG_SOURCE_COUNT_OFFSET);
  counts.drop_targets = er_wasm_load_u32(bytes + ER_WASM_UI_HEADER_DROP_TARGET_COUNT_OFFSET);
  counts.transitions = er_wasm_load_u32(bytes + ER_WASM_UI_HEADER_TRANSITION_COUNT_OFFSET);
  counts.icon_quads = er_wasm_load_u32(bytes + ER_WASM_UI_HEADER_ICON_QUAD_COUNT_OFFSET);
  counts.text_quads = er_wasm_load_u32(bytes + ER_WASM_UI_HEADER_TEXT_QUAD_COUNT_OFFSET);
  out_stats->rects = (size_t)counts.rects;
  out_stats->hits = (size_t)counts.hits;
  out_stats->drag_sources = (size_t)counts.drag_sources;
  out_stats->drop_targets = (size_t)counts.drop_targets;
  out_stats->transitions = (size_t)counts.transitions;
  out_stats->icon_quads = (size_t)counts.icon_quads;
  out_stats->text_quads = (size_t)counts.text_quads;

  summed_count = (UINT64)out_stats->rects + (UINT64)out_stats->hits +
                 (UINT64)out_stats->drag_sources + (UINT64)out_stats->drop_targets +
                 (UINT64)out_stats->transitions + (UINT64)out_stats->icon_quads +
                 (UINT64)out_stats->text_quads;
  if (command_count == 0u || command_count != summed_count) {
    return -1;
  }
  if (er_wasm_add_record_span(counts.rects, ER_WASM_UI_RECT_RECORD_LEN, &expected_len) != 0 ||
      er_wasm_add_record_span(counts.hits, ER_WASM_UI_HIT_RECORD_LEN, &expected_len) != 0 ||
      er_wasm_add_record_span(counts.drag_sources, ER_WASM_UI_DRAG_SOURCE_RECORD_LEN,
                              &expected_len) != 0 ||
      er_wasm_add_record_span(counts.drop_targets, ER_WASM_UI_DROP_TARGET_RECORD_LEN,
                              &expected_len) != 0 ||
      er_wasm_add_record_span(counts.transitions, ER_WASM_UI_TRANSITION_RECORD_LEN,
                              &expected_len) != 0 ||
      er_wasm_add_record_span(counts.icon_quads, ER_WASM_UI_QUAD_RECORD_LEN,
                              &expected_len) != 0 ||
      er_wasm_add_record_span(counts.text_quads, ER_WASM_UI_QUAD_RECORD_LEN,
                              &expected_len) != 0 ||
      len != expected_len) {
    return -1;
  }
  if (er_wasm_validate_records(bytes + offset, counts.rects, ER_WASM_UI_RECT_RECORD_LEN,
                               er_wasm_validate_ui_rect_record) != 0) {
    return -1;
  }
  offset += counts.rects * ER_WASM_UI_RECT_RECORD_LEN;
  if (er_wasm_validate_records(bytes + offset, counts.hits, ER_WASM_UI_HIT_RECORD_LEN,
                               er_wasm_validate_ui_hit_record) != 0) {
    return -1;
  }
  offset += counts.hits * ER_WASM_UI_HIT_RECORD_LEN;
  if (er_wasm_validate_records(bytes + offset, counts.drag_sources,
                               ER_WASM_UI_DRAG_SOURCE_RECORD_LEN,
                               er_wasm_validate_ui_drag_source_record) != 0) {
    return -1;
  }
  offset += counts.drag_sources * ER_WASM_UI_DRAG_SOURCE_RECORD_LEN;
  if (er_wasm_validate_records(bytes + offset, counts.drop_targets,
                               ER_WASM_UI_DROP_TARGET_RECORD_LEN,
                               er_wasm_validate_ui_drop_target_record) != 0) {
    return -1;
  }
  offset += counts.drop_targets * ER_WASM_UI_DROP_TARGET_RECORD_LEN;
  if (er_wasm_validate_records(bytes + offset, counts.transitions,
                               ER_WASM_UI_TRANSITION_RECORD_LEN,
                               er_wasm_validate_ui_transition_record) != 0) {
    return -1;
  }
  offset += counts.transitions * ER_WASM_UI_TRANSITION_RECORD_LEN;
  if (er_wasm_validate_records(bytes + offset, counts.icon_quads, ER_WASM_UI_QUAD_RECORD_LEN,
                               er_wasm_validate_ui_quad_record) != 0) {
    return -1;
  }
  offset += counts.icon_quads * ER_WASM_UI_QUAD_RECORD_LEN;
  if (er_wasm_validate_records(bytes + offset, counts.text_quads, ER_WASM_UI_QUAD_RECORD_LEN,
                               er_wasm_validate_ui_quad_record) != 0) {
    return -1;
  }
  return 0;
}

static er_ui_color4_t er_wasm_decode_ui_color(const UINT8* bytes) {
  return er_ui_color_rgba(er_wasm_load_f32(bytes + ER_WASM_UI_COLOR_RECORD_R_OFFSET),
                          er_wasm_load_f32(bytes + ER_WASM_UI_COLOR_RECORD_G_OFFSET),
                          er_wasm_load_f32(bytes + ER_WASM_UI_COLOR_RECORD_B_OFFSET),
                          er_wasm_load_f32(bytes + ER_WASM_UI_COLOR_RECORD_A_OFFSET));
}

static er_ui_rect_t er_wasm_decode_ui_rect(const UINT8* bytes) {
  er_ui_rect_t rect;

  rect.x = er_wasm_load_f32(bytes + ER_WASM_UI_RECT_RECORD_X_OFFSET);
  rect.y = er_wasm_load_f32(bytes + ER_WASM_UI_RECT_RECORD_Y_OFFSET);
  rect.w = er_wasm_load_f32(bytes + ER_WASM_UI_RECT_RECORD_W_OFFSET);
  rect.h = er_wasm_load_f32(bytes + ER_WASM_UI_RECT_RECORD_H_OFFSET);
  rect.radius = er_wasm_load_f32(bytes + ER_WASM_UI_RECT_RECORD_RADIUS_OFFSET);
  rect.color = er_wasm_decode_ui_color(bytes + ER_WASM_UI_RECT_RECORD_COLOR_OFFSET);
  rect.color2 = er_wasm_decode_ui_color(bytes + ER_WASM_UI_RECT_RECORD_COLOR2_OFFSET);
  rect.mode = (er_ui_rect_mode_t)er_wasm_load_u32(bytes + ER_WASM_UI_RECT_RECORD_MODE_OFFSET);
  rect.shadow = er_wasm_load_f32(bytes + ER_WASM_UI_RECT_RECORD_SHADOW_OFFSET);
  return rect;
}

static er_ui_hit_t er_wasm_decode_ui_hit(const UINT8* bytes) {
  return er_ui_hit((er_ui_hit_kind_t)er_wasm_load_u32(bytes + ER_WASM_UI_HIT_RECORD_KIND_OFFSET),
                   er_wasm_load_u32(bytes + ER_WASM_UI_HIT_RECORD_ID_OFFSET),
                   er_wasm_load_f32(bytes + ER_WASM_UI_HIT_RECORD_X_OFFSET),
                   er_wasm_load_f32(bytes + ER_WASM_UI_HIT_RECORD_Y_OFFSET),
                   er_wasm_load_f32(bytes + ER_WASM_UI_HIT_RECORD_W_OFFSET),
                   er_wasm_load_f32(bytes + ER_WASM_UI_HIT_RECORD_H_OFFSET));
}

static er_ui_drag_source_t er_wasm_decode_ui_drag_source(const UINT8* bytes) {
  return er_ui_drag_source(er_wasm_load_u32(bytes + ER_WASM_UI_DRAG_SOURCE_RECORD_SCOPE_ID_OFFSET),
                           er_wasm_load_u32(bytes + ER_WASM_UI_DRAG_SOURCE_RECORD_ITEM_ID_OFFSET),
                           (size_t)er_wasm_load_u32(bytes + ER_WASM_UI_DRAG_SOURCE_RECORD_INDEX_OFFSET),
                           er_wasm_load_f32(bytes + ER_WASM_UI_DRAG_SOURCE_RECORD_X_OFFSET),
                           er_wasm_load_f32(bytes + ER_WASM_UI_DRAG_SOURCE_RECORD_Y_OFFSET),
                           er_wasm_load_f32(bytes + ER_WASM_UI_DRAG_SOURCE_RECORD_W_OFFSET),
                           er_wasm_load_f32(bytes + ER_WASM_UI_DRAG_SOURCE_RECORD_H_OFFSET));
}

static er_ui_drop_target_t er_wasm_decode_ui_drop_target(const UINT8* bytes) {
  return er_ui_drop_target(er_wasm_load_u32(bytes + ER_WASM_UI_DROP_TARGET_RECORD_SCOPE_ID_OFFSET),
                           (size_t)er_wasm_load_u32(bytes + ER_WASM_UI_DROP_TARGET_RECORD_INDEX_OFFSET),
                           er_wasm_load_f32(bytes + ER_WASM_UI_DROP_TARGET_RECORD_X_OFFSET),
                           er_wasm_load_f32(bytes + ER_WASM_UI_DROP_TARGET_RECORD_Y_OFFSET),
                           er_wasm_load_f32(bytes + ER_WASM_UI_DROP_TARGET_RECORD_W_OFFSET),
                           er_wasm_load_f32(bytes + ER_WASM_UI_DROP_TARGET_RECORD_H_OFFSET));
}

static er_ui_transition_t er_wasm_decode_ui_transition(const UINT8* bytes) {
  return er_ui_transition(er_wasm_load_u32(bytes + ER_WASM_UI_TRANSITION_RECORD_ID_OFFSET),
                          (er_ui_transition_property_t)er_wasm_load_u32(bytes + ER_WASM_UI_TRANSITION_RECORD_PROPERTY_OFFSET),
                          er_wasm_load_f32(bytes + ER_WASM_UI_TRANSITION_RECORD_FROM_OFFSET),
                          er_wasm_load_f32(bytes + ER_WASM_UI_TRANSITION_RECORD_TO_OFFSET),
                          er_wasm_load_u32(bytes + ER_WASM_UI_TRANSITION_RECORD_DURATION_OFFSET),
                          er_wasm_load_u32(bytes + ER_WASM_UI_TRANSITION_RECORD_DELAY_OFFSET),
                          (er_ui_transition_easing_t)er_wasm_load_u32(bytes + ER_WASM_UI_TRANSITION_RECORD_EASING_OFFSET));
}

static er_ui_quad_t er_wasm_decode_ui_quad(const UINT8* bytes) {
  return er_ui_quad_atlas(er_wasm_load_f32(bytes + ER_WASM_UI_QUAD_RECORD_X_OFFSET),
                          er_wasm_load_f32(bytes + ER_WASM_UI_QUAD_RECORD_Y_OFFSET),
                          er_wasm_load_f32(bytes + ER_WASM_UI_QUAD_RECORD_W_OFFSET),
                          er_wasm_load_f32(bytes + ER_WASM_UI_QUAD_RECORD_H_OFFSET),
                          er_wasm_load_f32(bytes + ER_WASM_UI_QUAD_RECORD_U0_OFFSET),
                          er_wasm_load_f32(bytes + ER_WASM_UI_QUAD_RECORD_V0_OFFSET),
                          er_wasm_load_f32(bytes + ER_WASM_UI_QUAD_RECORD_U1_OFFSET),
                          er_wasm_load_f32(bytes + ER_WASM_UI_QUAD_RECORD_V1_OFFSET),
                          er_wasm_load_u32(bytes + ER_WASM_UI_QUAD_RECORD_ATLAS_ID_OFFSET),
                          er_wasm_decode_ui_color(bytes + ER_WASM_UI_QUAD_RECORD_COLOR_OFFSET));
}

static int er_wasm_push_decoded_ui_rect(const UINT8* bytes, er_ui_scene_t* scene) {
  return er_ui_scene_push_rect(scene, er_wasm_decode_ui_rect(bytes)) == ER_UI_OK ? 0 : -1;
}

static int er_wasm_push_decoded_ui_hit(const UINT8* bytes, er_ui_scene_t* scene) {
  return er_ui_scene_push_hit(scene, er_wasm_decode_ui_hit(bytes)) == ER_UI_OK ? 0 : -1;
}

static int er_wasm_push_decoded_ui_drag_source(const UINT8* bytes, er_ui_scene_t* scene) {
  return er_ui_scene_push_drag_source(scene, er_wasm_decode_ui_drag_source(bytes)) == ER_UI_OK ?
         0 : -1;
}

static int er_wasm_push_decoded_ui_drop_target(const UINT8* bytes, er_ui_scene_t* scene) {
  return er_ui_scene_push_drop_target(scene, er_wasm_decode_ui_drop_target(bytes)) == ER_UI_OK ?
         0 : -1;
}

static int er_wasm_push_decoded_ui_transition(const UINT8* bytes, er_ui_scene_t* scene) {
  return er_ui_scene_push_transition(scene, er_wasm_decode_ui_transition(bytes)) == ER_UI_OK ?
         0 : -1;
}

static int er_wasm_push_decoded_ui_icon_quad(const UINT8* bytes, er_ui_scene_t* scene) {
  return er_ui_scene_push_icon_quad(scene, er_wasm_decode_ui_quad(bytes)) == ER_UI_OK ? 0 : -1;
}

static int er_wasm_push_decoded_ui_text_quad(const UINT8* bytes, er_ui_scene_t* scene) {
  return er_ui_scene_push_text_quad(scene, er_wasm_decode_ui_quad(bytes)) == ER_UI_OK ? 0 : -1;
}

//@optimizer-ignore-function UI packet decoding must visit each admitted record exactly once
static int er_wasm_decode_ui_records(const UINT8* bytes, UINT32 count, UINT32 record_len,
                                     ErWasmUiDecodeRecord decode_record,
                                     er_ui_scene_t* scene) {
  UINT32 index = 0;

  if (bytes == 0 || decode_record == 0 || scene == 0) {
    return -1;
  }
  for (index = 0; index < count; index++) {
    if (decode_record(bytes + (index * record_len), scene) != 0) {
      return -1;
    }
  }
  return 0;
}

int er_wasm_ui_command_decode(const UINT8* bytes, UINT32 len, er_ui_scene_t* scene,
                              er_ui_scene_stats_t* out_stats) {
  er_ui_scene_stats_t stats;
  UINT32 offset = ER_WASM_UI_COMMAND_LIST_HEADER_LEN;
  ErWasmUiCommandCounts counts;

  if (scene == 0 || er_wasm_ui_command_stats(bytes, len, &stats) != 0) {
    return -1;
  }
  counts.rects = (UINT32)stats.rects;
  counts.hits = (UINT32)stats.hits;
  counts.drag_sources = (UINT32)stats.drag_sources;
  counts.drop_targets = (UINT32)stats.drop_targets;
  counts.transitions = (UINT32)stats.transitions;
  counts.icon_quads = (UINT32)stats.icon_quads;
  counts.text_quads = (UINT32)stats.text_quads;

  er_ui_scene_clear_commands(scene);
  if (er_wasm_decode_ui_records(bytes + offset, counts.rects, ER_WASM_UI_RECT_RECORD_LEN,
                                er_wasm_push_decoded_ui_rect, scene) != 0) {
    return -1;
  }
  offset += counts.rects * ER_WASM_UI_RECT_RECORD_LEN;
  if (er_wasm_decode_ui_records(bytes + offset, counts.hits, ER_WASM_UI_HIT_RECORD_LEN,
                                er_wasm_push_decoded_ui_hit, scene) != 0) {
    return -1;
  }
  offset += counts.hits * ER_WASM_UI_HIT_RECORD_LEN;
  if (er_wasm_decode_ui_records(bytes + offset, counts.drag_sources,
                                ER_WASM_UI_DRAG_SOURCE_RECORD_LEN,
                                er_wasm_push_decoded_ui_drag_source, scene) != 0) {
    return -1;
  }
  offset += counts.drag_sources * ER_WASM_UI_DRAG_SOURCE_RECORD_LEN;
  if (er_wasm_decode_ui_records(bytes + offset, counts.drop_targets,
                                ER_WASM_UI_DROP_TARGET_RECORD_LEN,
                                er_wasm_push_decoded_ui_drop_target, scene) != 0) {
    return -1;
  }
  offset += counts.drop_targets * ER_WASM_UI_DROP_TARGET_RECORD_LEN;
  if (er_wasm_decode_ui_records(bytes + offset, counts.transitions,
                                ER_WASM_UI_TRANSITION_RECORD_LEN,
                                er_wasm_push_decoded_ui_transition, scene) != 0) {
    return -1;
  }
  offset += counts.transitions * ER_WASM_UI_TRANSITION_RECORD_LEN;
  if (er_wasm_decode_ui_records(bytes + offset, counts.icon_quads, ER_WASM_UI_QUAD_RECORD_LEN,
                                er_wasm_push_decoded_ui_icon_quad, scene) != 0) {
    return -1;
  }
  offset += counts.icon_quads * ER_WASM_UI_QUAD_RECORD_LEN;
  if (er_wasm_decode_ui_records(bytes + offset, counts.text_quads, ER_WASM_UI_QUAD_RECORD_LEN,
                                er_wasm_push_decoded_ui_text_quad, scene) != 0) {
    return -1;
  }
  if (out_stats != 0) {
    *out_stats = stats;
  }
  return 0;
}

void er_wasm_store_u32(UINT8* dst, UINT32 value) {
  dst[ER_WASM_U32_BYTE0] = (UINT8)(value & ER_WASM_U8_MASK);
  dst[ER_WASM_U32_BYTE1] = (UINT8)((value >> ER_WASM_U32_BYTE1_SHIFT) & ER_WASM_U8_MASK);
  dst[ER_WASM_U32_BYTE2] = (UINT8)((value >> ER_WASM_U32_BYTE2_SHIFT) & ER_WASM_U8_MASK);
  dst[ER_WASM_U32_BYTE3] = (UINT8)((value >> ER_WASM_U32_BYTE3_SHIFT) & ER_WASM_U8_MASK);
}

void er_wasm_store_u64(UINT8* dst, UINT64 value) {
  er_wasm_store_u32(dst, (UINT32)(value & ER_WASM_U32_MASK));
  er_wasm_store_u32(dst + ER_WASM_U32_BYTES, (UINT32)(value >> ER_WASM_U64_HIGH32_SHIFT));
}
