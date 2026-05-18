#ifndef WASM_VM_INTERNAL_H
#define WASM_VM_INTERNAL_H
#include "wasm_vm.h"
#include "er_mem.h"
#include "er_relay_packet.h"

/*
 * Purpose: run small admitted WASM driver/app modules inside the metal executor.
 * Intention: keep driver code outside the executor while exposing only explicit hostcalls.
 */

typedef struct {
  const UINT8* data;
  UINT32 size;
  UINT32 ofs;
} ErReader;

typedef struct {
  UINT8 form;
  UINT8 param_count;
  UINT8 result_count;
  UINT8 result_type;
} ErFuncType;

typedef struct {
  const char* module;
  UINT8 module_len;
  const char* field;
  UINT8 field_len;
  UINT8 kind;
} ErHostImport;

typedef struct {
  UINT8 kind;
  UINT32 start_pc;
  UINT32 end_pc;
  UINT32 stack_depth;
} ErControlFrame;

typedef struct {
  UINT32 rects;
  UINT32 hits;
  UINT32 drag_sources;
  UINT32 drop_targets;
  UINT32 transitions;
  UINT32 icon_quads;
  UINT32 text_quads;
} ErWasmUiCommandCounts;

typedef int (*ErWasmUiDecodeRecord)(const UINT8* bytes, er_ui_scene_t* scene);

#define ER_WASM_IMPORT_MODULE_LOG "edgerun.log"
#define ER_WASM_IMPORT_MODULE_PCI "edgerun.pci"
#define ER_WASM_IMPORT_MODULE_MMIO "edgerun.mmio"
#define ER_WASM_IMPORT_MODULE_BUS "edgerun.bus"
#define ER_WASM_IMPORT_MODULE_RELAY "edgerun.relay"
#define ER_WASM_IMPORT_MODULE_MEMORY "edgerun.memory"
#define ER_WASM_IMPORT_MODULE_UI "edgerun.ui"
#define ER_WASM_IMPORT_FIELD_U64 "u64"
#define ER_WASM_IMPORT_FIELD_HEX "hex"
#define ER_WASM_IMPORT_FIELD_READ32 "read32"
#define ER_WASM_IMPORT_FIELD_WRITE32 "write32"
#define ER_WASM_IMPORT_FIELD_MAP "map"
#define ER_WASM_IMPORT_FIELD_EXEC "exec"
#define ER_WASM_IMPORT_FIELD_SEND "send"
#define ER_WASM_IMPORT_FIELD_RECV "recv"
#define ER_WASM_IMPORT_FIELD_EMIT "emit"
#define ER_WASM_IMPORT_FIELD_REGION_BASE "region_base"
#define ER_WASM_IMPORT_FIELD_REGION_LEN "region_len"
#define ER_WASM_STRING_LEN(value) ((UINT8)(sizeof(value) - 1u))
#define ER_WASM_LEB32_MAX_BYTES 5u
#define ER_WASM_LEB64_MAX_BYTES 10u
#define ER_WASM_LEB_PAYLOAD_MASK 0x7fu
#define ER_WASM_LEB_CONTINUE_MASK 0x80u
#define ER_WASM_LEB_SIGN_MASK 0x40u
#define ER_WASM_LEB_BITS_PER_BYTE 7u
#define ER_WASM_U8_MASK 0xffu
#define ER_WASM_U8_BYTES 1u
#define ER_WASM_U16_BYTES 2u
#define ER_WASM_UI_HEADER_ABI_OFFSET 0u
#define ER_WASM_UI_HEADER_COMMAND_COUNT_OFFSET 4u
#define ER_WASM_UI_HEADER_RECT_COUNT_OFFSET 8u
#define ER_WASM_UI_HEADER_HIT_COUNT_OFFSET 12u
#define ER_WASM_UI_HEADER_DRAG_SOURCE_COUNT_OFFSET 16u
#define ER_WASM_UI_HEADER_DROP_TARGET_COUNT_OFFSET 20u
#define ER_WASM_UI_HEADER_TRANSITION_COUNT_OFFSET 24u
#define ER_WASM_UI_HEADER_ICON_QUAD_COUNT_OFFSET 28u
#define ER_WASM_UI_HEADER_TEXT_QUAD_COUNT_OFFSET 32u
#define ER_WASM_FLOAT_EXPONENT_MASK 0x7f800000u
#define ER_WASM_UI_RECT_MODE_MIN 0u
#define ER_WASM_UI_RECT_MODE_MAX 3u
#define ER_WASM_UI_HIT_KIND_MIN 0u
#define ER_WASM_UI_HIT_KIND_MAX 24u
#define ER_WASM_UI_TRANSITION_PROPERTY_MIN 0u
#define ER_WASM_UI_TRANSITION_PROPERTY_MAX 2u
#define ER_WASM_UI_TRANSITION_EASING_MIN 0u
#define ER_WASM_UI_TRANSITION_EASING_MAX 3u
#define ER_WASM_UI_RECT_RECORD_MODE_OFFSET 52u
#define ER_WASM_UI_HIT_RECORD_KIND_OFFSET 0u
#define ER_WASM_UI_HIT_RECORD_FLOAT_OFFSET 8u
#define ER_WASM_UI_DRAG_SOURCE_RECORD_FLOAT_OFFSET 12u
#define ER_WASM_UI_DROP_TARGET_RECORD_FLOAT_OFFSET 8u
#define ER_WASM_UI_TRANSITION_RECORD_PROPERTY_OFFSET 4u
#define ER_WASM_UI_TRANSITION_RECORD_FLOAT_OFFSET 8u
#define ER_WASM_UI_TRANSITION_RECORD_DURATION_OFFSET 16u
#define ER_WASM_UI_TRANSITION_RECORD_EASING_OFFSET 24u
#define ER_WASM_UI_QUAD_RECORD_ATLAS_ID_OFFSET 32u
#define ER_WASM_UI_COLOR_RECORD_R_OFFSET 0u
#define ER_WASM_UI_COLOR_RECORD_G_OFFSET 4u
#define ER_WASM_UI_COLOR_RECORD_B_OFFSET 8u
#define ER_WASM_UI_COLOR_RECORD_A_OFFSET 12u
#define ER_WASM_UI_RECT_RECORD_X_OFFSET 0u
#define ER_WASM_UI_RECT_RECORD_Y_OFFSET 4u
#define ER_WASM_UI_RECT_RECORD_W_OFFSET 8u
#define ER_WASM_UI_RECT_RECORD_H_OFFSET 12u
#define ER_WASM_UI_RECT_RECORD_RADIUS_OFFSET 16u
#define ER_WASM_UI_RECT_RECORD_COLOR_OFFSET 20u
#define ER_WASM_UI_RECT_RECORD_COLOR2_OFFSET 36u
#define ER_WASM_UI_RECT_RECORD_SHADOW_OFFSET 56u
#define ER_WASM_UI_HIT_RECORD_ID_OFFSET 4u
#define ER_WASM_UI_HIT_RECORD_X_OFFSET 8u
#define ER_WASM_UI_HIT_RECORD_Y_OFFSET 12u
#define ER_WASM_UI_HIT_RECORD_W_OFFSET 16u
#define ER_WASM_UI_HIT_RECORD_H_OFFSET 20u
#define ER_WASM_UI_DRAG_SOURCE_RECORD_SCOPE_ID_OFFSET 0u
#define ER_WASM_UI_DRAG_SOURCE_RECORD_ITEM_ID_OFFSET 4u
#define ER_WASM_UI_DRAG_SOURCE_RECORD_INDEX_OFFSET 8u
#define ER_WASM_UI_DRAG_SOURCE_RECORD_X_OFFSET 12u
#define ER_WASM_UI_DRAG_SOURCE_RECORD_Y_OFFSET 16u
#define ER_WASM_UI_DRAG_SOURCE_RECORD_W_OFFSET 20u
#define ER_WASM_UI_DRAG_SOURCE_RECORD_H_OFFSET 24u
#define ER_WASM_UI_DROP_TARGET_RECORD_SCOPE_ID_OFFSET 0u
#define ER_WASM_UI_DROP_TARGET_RECORD_INDEX_OFFSET 4u
#define ER_WASM_UI_DROP_TARGET_RECORD_X_OFFSET 8u
#define ER_WASM_UI_DROP_TARGET_RECORD_Y_OFFSET 12u
#define ER_WASM_UI_DROP_TARGET_RECORD_W_OFFSET 16u
#define ER_WASM_UI_DROP_TARGET_RECORD_H_OFFSET 20u
#define ER_WASM_UI_TRANSITION_RECORD_ID_OFFSET 0u
#define ER_WASM_UI_TRANSITION_RECORD_FROM_OFFSET 8u
#define ER_WASM_UI_TRANSITION_RECORD_TO_OFFSET 12u
#define ER_WASM_UI_TRANSITION_RECORD_DELAY_OFFSET 20u
#define ER_WASM_UI_QUAD_RECORD_X_OFFSET 0u
#define ER_WASM_UI_QUAD_RECORD_Y_OFFSET 4u
#define ER_WASM_UI_QUAD_RECORD_W_OFFSET 8u
#define ER_WASM_UI_QUAD_RECORD_H_OFFSET 12u
#define ER_WASM_UI_QUAD_RECORD_U0_OFFSET 16u
#define ER_WASM_UI_QUAD_RECORD_V0_OFFSET 20u
#define ER_WASM_UI_QUAD_RECORD_U1_OFFSET 24u
#define ER_WASM_UI_QUAD_RECORD_V1_OFFSET 28u
#define ER_WASM_UI_QUAD_RECORD_COLOR_OFFSET 36u
#define ER_WASM_UI_RECORD_FLOAT_BYTES 4u
#define ER_WASM_U32_BYTE0 0u
#define ER_WASM_U32_BYTE1 1u
#define ER_WASM_U32_BYTE2 2u
#define ER_WASM_U32_BYTE3 3u
#define ER_WASM_U32_BYTE1_SHIFT 8u
#define ER_WASM_U32_BYTE2_SHIFT 16u
#define ER_WASM_U32_BYTE3_SHIFT 24u
#define ER_WASM_U32_BYTES 4u
#define ER_WASM_U64_BYTES 8u
#define ER_WASM_U32_MASK 0xffffffffu
#define ER_WASM_U64_HIGH32_SHIFT 32u
#define ER_WASM_MAGIC_BYTES 8u
#define ER_WASM_HEADER_BYTE0 0u
#define ER_WASM_HEADER_BYTE1 1u
#define ER_WASM_HEADER_BYTE2 2u
#define ER_WASM_HEADER_BYTE3 3u
#define ER_WASM_HEADER_BYTE4 4u
#define ER_WASM_HEADER_BYTE5 5u
#define ER_WASM_HEADER_BYTE6 6u
#define ER_WASM_HEADER_BYTE7 7u
#define ER_WASM_MAGIC_0 0x00u
#define ER_WASM_MAGIC_1 0x61u
#define ER_WASM_MAGIC_2 0x73u
#define ER_WASM_MAGIC_3 0x6du
#define ER_WASM_VERSION_0 0x01u
#define ER_WASM_VERSION_1 0x00u
#define ER_WASM_VERSION_2 0x00u
#define ER_WASM_VERSION_3 0x00u
#define ER_WASM_SECTION_TYPE 1u
#define ER_WASM_SECTION_IMPORT 2u
#define ER_WASM_SECTION_FUNCTION 3u
#define ER_WASM_SECTION_MEMORY 5u
#define ER_WASM_SECTION_EXPORT 7u
#define ER_WASM_SECTION_CODE 10u
#define ER_WASM_SECTION_DATA 11u
#define ER_WASM_TYPE_FORM_FUNC 0x60u
#define ER_WASM_VALTYPE_I64 0x7eu
#define ER_WASM_VALTYPE_I32 0x7fu
#define ER_WASM_VALTYPE_F32 0x7du
#define ER_WASM_VALTYPE_F64 0x7cu
#define ER_WASM_EXTERNAL_KIND_FUNC 0x00u
#define ER_WASM_MEMORY_LIMIT_HAS_MAX 1u
#define ER_WASM_MEMORY_PAGE_BYTES 65536ull
#define ER_WASM_MAX_TYPE_PARAMS 5u
#define ER_WASM_MAX_TYPE_RESULTS 1u
#define ER_WASM_MAX_LOCALS 16u
#define ER_WASM_MAX_DATA_SEGMENTS 16u
#define ER_WASM_MAX_CONTROL_DEPTH 16u
#define ER_WASM_STACK_MAX 32u
#define ER_WASM_MEMORY_INDEX_ZERO 0u
#define ER_WASM_PCI_READ32_PARAM_COUNT 4u
#define ER_WASM_PCI_WRITE32_PARAM_COUNT 5u
#define ER_WASM_MAIN_NAME_LEN 4u
#define ER_WASM_MAIN_NAME_BYTE0 'm'
#define ER_WASM_MAIN_NAME_BYTE1 'a'
#define ER_WASM_MAIN_NAME_BYTE2 'i'
#define ER_WASM_MAIN_NAME_BYTE3 'n'
#define ER_WASM_OP_BLOCK 0x02u
#define ER_WASM_OP_LOOP 0x03u
#define ER_WASM_OP_IF 0x04u
#define ER_WASM_OP_ELSE 0x05u
#define ER_WASM_OP_END 0x0bu
#define ER_WASM_OP_BR 0x0cu
#define ER_WASM_OP_BR_IF 0x0du
#define ER_WASM_OP_CALL 0x10u
#define ER_WASM_OP_DROP 0x1au
#define ER_WASM_OP_LOCAL_GET 0x20u
#define ER_WASM_OP_LOCAL_SET 0x21u
#define ER_WASM_OP_LOCAL_TEE 0x22u
#define ER_WASM_OP_I32_LOAD 0x28u
#define ER_WASM_OP_I64_LOAD 0x29u
#define ER_WASM_OP_I32_LOAD8_U 0x2du
#define ER_WASM_OP_I32_LOAD16_U 0x2fu
#define ER_WASM_OP_I32_STORE 0x36u
#define ER_WASM_OP_I64_STORE 0x37u
#define ER_WASM_OP_I32_STORE8 0x3au
#define ER_WASM_OP_I32_STORE16 0x3bu
#define ER_WASM_OP_MEMORY_MAX 0x3eu
#define ER_WASM_OP_MEMORY_SIZE 0x3fu
#define ER_WASM_OP_MEMORY_GROW 0x40u
#define ER_WASM_OP_I32_CONST 0x41u
#define ER_WASM_OP_I64_CONST 0x42u
#define ER_WASM_OP_I32_EQZ 0x45u
#define ER_WASM_OP_I64_EQ 0x51u
#define ER_WASM_OP_I64_NE 0x52u
#define ER_WASM_OP_I64_LT_U 0x54u
#define ER_WASM_OP_I64_ADD 0x7cu
#define ER_WASM_OP_I64_AND 0x83u
#define ER_WASM_OP_I32_WRAP_I64 0xa7u

enum {
  ER_IMPORT_KIND_NONE = 0,
  ER_IMPORT_KIND_LOG_U64 = 1,
  ER_IMPORT_KIND_LOG_HEX = 2,
  ER_IMPORT_KIND_PCI_READ32 = 3,
  ER_IMPORT_KIND_PCI_WRITE32 = 4,
  ER_IMPORT_KIND_MMIO_MAP = 5,
  ER_IMPORT_KIND_MMIO_READ32 = 6,
  ER_IMPORT_KIND_BUS_EXEC = 7,
  ER_IMPORT_KIND_RELAY_SEND = 8,
  ER_IMPORT_KIND_RELAY_RECV = 9,
  ER_IMPORT_KIND_MEMORY_REGION_BASE = 10,
  ER_IMPORT_KIND_MEMORY_REGION_LEN = 11,
  ER_IMPORT_KIND_UI_EMIT = 12
};

enum {
  ER_CONTROL_KIND_BLOCK = 1,
  ER_CONTROL_KIND_LOOP = 2,
  ER_CONTROL_KIND_IF = 3
};

int er_reader_init(ErReader* r, const UINT8* data, UINT32 size);
int er_reader_more(const ErReader* r);
int er_reader_read_u8(ErReader* r, UINT8* out);
int er_reader_read_u32_leb(ErReader* r, UINT32* out);
int er_reader_read_i64_leb(ErReader* r, INT64* out);
int er_skip_u32_leb(const UINT8* data, UINT32 size, UINT32* ofs);
int er_skip_i64_leb(const UINT8* data, UINT32 size, UINT32* ofs);
int er_reader_skip(ErReader* r, UINT32 count);
int er_read_string(ErReader* r, const UINT8** out_string, UINT32* out_len);
int er_scan_matching_end(const UINT8* data, UINT32 size, UINT32 start_pc,
                         UINT32* out_end_pc, UINT32* out_else_pc);
int er_wasm_linear_memory_valid(const ErWasmLinearMemory* memory);
int er_wasm_memory_range(ErWasmModule* module, UINT64 offset, UINT32 len, UINT8** out_bytes);
int er_wasm_memory_window_range(ErWasmModule* module, UINT64 offset, UINT32 len,
                                UINT32 window_base, UINT32 window_len,
                                UINT8** out_bytes);
UINT32 er_wasm_load_u32(const UINT8* src);
float er_wasm_load_f32(const UINT8* src);
UINT64 er_wasm_load_u64(const UINT8* src);
UINT16 er_wasm_load_u16(const UINT8* src);
void er_wasm_store_u32(UINT8* dst, UINT32 value);
void er_wasm_store_u64(UINT8* dst, UINT64 value);

#endif
