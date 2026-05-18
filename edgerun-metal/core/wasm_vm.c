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

static const ErHostImport ER_HOST_IMPORTS[] = {
  {ER_WASM_IMPORT_MODULE_LOG, ER_WASM_STRING_LEN(ER_WASM_IMPORT_MODULE_LOG),
   ER_WASM_IMPORT_FIELD_U64, ER_WASM_STRING_LEN(ER_WASM_IMPORT_FIELD_U64), ER_IMPORT_KIND_LOG_U64},
  {ER_WASM_IMPORT_MODULE_LOG, ER_WASM_STRING_LEN(ER_WASM_IMPORT_MODULE_LOG),
   ER_WASM_IMPORT_FIELD_HEX, ER_WASM_STRING_LEN(ER_WASM_IMPORT_FIELD_HEX), ER_IMPORT_KIND_LOG_HEX},
  {ER_WASM_IMPORT_MODULE_PCI, ER_WASM_STRING_LEN(ER_WASM_IMPORT_MODULE_PCI),
   ER_WASM_IMPORT_FIELD_READ32, ER_WASM_STRING_LEN(ER_WASM_IMPORT_FIELD_READ32), ER_IMPORT_KIND_PCI_READ32},
  {ER_WASM_IMPORT_MODULE_PCI, ER_WASM_STRING_LEN(ER_WASM_IMPORT_MODULE_PCI),
   ER_WASM_IMPORT_FIELD_WRITE32, ER_WASM_STRING_LEN(ER_WASM_IMPORT_FIELD_WRITE32), ER_IMPORT_KIND_PCI_WRITE32},
  {ER_WASM_IMPORT_MODULE_MMIO, ER_WASM_STRING_LEN(ER_WASM_IMPORT_MODULE_MMIO),
   ER_WASM_IMPORT_FIELD_MAP, ER_WASM_STRING_LEN(ER_WASM_IMPORT_FIELD_MAP), ER_IMPORT_KIND_MMIO_MAP},
  {ER_WASM_IMPORT_MODULE_MMIO, ER_WASM_STRING_LEN(ER_WASM_IMPORT_MODULE_MMIO),
   ER_WASM_IMPORT_FIELD_READ32, ER_WASM_STRING_LEN(ER_WASM_IMPORT_FIELD_READ32), ER_IMPORT_KIND_MMIO_READ32},
  {ER_WASM_IMPORT_MODULE_BUS, ER_WASM_STRING_LEN(ER_WASM_IMPORT_MODULE_BUS),
   ER_WASM_IMPORT_FIELD_EXEC, ER_WASM_STRING_LEN(ER_WASM_IMPORT_FIELD_EXEC), ER_IMPORT_KIND_BUS_EXEC},
  {ER_WASM_IMPORT_MODULE_RELAY, ER_WASM_STRING_LEN(ER_WASM_IMPORT_MODULE_RELAY),
   ER_WASM_IMPORT_FIELD_SEND, ER_WASM_STRING_LEN(ER_WASM_IMPORT_FIELD_SEND), ER_IMPORT_KIND_RELAY_SEND},
  {ER_WASM_IMPORT_MODULE_RELAY, ER_WASM_STRING_LEN(ER_WASM_IMPORT_MODULE_RELAY),
   ER_WASM_IMPORT_FIELD_RECV, ER_WASM_STRING_LEN(ER_WASM_IMPORT_FIELD_RECV), ER_IMPORT_KIND_RELAY_RECV},
  {ER_WASM_IMPORT_MODULE_MEMORY, ER_WASM_STRING_LEN(ER_WASM_IMPORT_MODULE_MEMORY),
   ER_WASM_IMPORT_FIELD_REGION_BASE, ER_WASM_STRING_LEN(ER_WASM_IMPORT_FIELD_REGION_BASE),
   ER_IMPORT_KIND_MEMORY_REGION_BASE},
  {ER_WASM_IMPORT_MODULE_MEMORY, ER_WASM_STRING_LEN(ER_WASM_IMPORT_MODULE_MEMORY),
   ER_WASM_IMPORT_FIELD_REGION_LEN, ER_WASM_STRING_LEN(ER_WASM_IMPORT_FIELD_REGION_LEN),
   ER_IMPORT_KIND_MEMORY_REGION_LEN},
  {ER_WASM_IMPORT_MODULE_UI, ER_WASM_STRING_LEN(ER_WASM_IMPORT_MODULE_UI),
   ER_WASM_IMPORT_FIELD_EMIT, ER_WASM_STRING_LEN(ER_WASM_IMPORT_FIELD_EMIT),
   ER_IMPORT_KIND_UI_EMIT}
};
static const UINT32 ER_HOST_IMPORT_COUNT = (UINT32)(sizeof(ER_HOST_IMPORTS) / sizeof(ER_HOST_IMPORTS[0]));

static UINT8 er_match_name(const UINT8* actual_name, UINT32 actual_len, const char* expected_name, UINT32 expected_len) {
  UINT32 i = 0;

  if (actual_name == 0 || expected_name == 0) {
    return 0;
  }
  if (actual_len != expected_len) {
    return 0;
  }

  for (i = 0; i < actual_len; ++i) {
    if (actual_name[i] != (UINT8)expected_name[i]) {
      return 0;
    }
  }

  return 1;
}

static UINT8 er_find_host_import(const UINT8* module_name, UINT32 module_len,
                                 const UINT8* field_name, UINT32 field_len) {
  const ErHostImport* import = ER_HOST_IMPORTS;
  const ErHostImport* end = ER_HOST_IMPORTS + ER_HOST_IMPORT_COUNT;

  while (import < end) {
    if (er_match_name(module_name, module_len, import->module, import->module_len) &&
        er_match_name(field_name, field_len, import->field, import->field_len)) {
      return import->kind;
    }
    ++import;
  }
  return ER_IMPORT_KIND_NONE;
}

static void er_clear_module(ErWasmModule* module) {
  if (module == 0) {
    return;
  }

  module->num_types = 0;
  module->num_imports = 0;
  module->num_funcs = 0;
  module->num_exports = 0;
  module->memory_min_pages = 0;
  module->memory_size = 0;
  module->memory = 0;
  er_mem_zero((UINT8*)&module->linear_memory, (UINTN)sizeof(module->linear_memory));
  module->function_has_main = 0;
  module->main_index = 0;

  for (UINT32 i = 0; i < ER_WASM_MAX_FUNCTIONS; ++i) {
    module->function_type_indices[i] = 0;
    module->function_is_import[i] = 0;
    module->function_import_kind[i] = ER_IMPORT_KIND_NONE;
    module->type_params_0[i] = 0;
    module->type_result_count[i] = 0;
    module->type_result_type[i] = 0;
    module->code[i].body = 0;
    module->code[i].size = 0;
    module->code[i].local_count = 0;
  }

  module->host.log_u64 = 0;
  module->host.log_hex = 0;
  module->host.pci_read32 = 0;
  module->host.pci_write32 = 0;
  module->host.mmio_map = 0;
  module->host.mmio_read32 = 0;
  module->host.bus_exec = 0;
  module->host.relay_send = 0;
  module->host.relay_recv = 0;
  module->host.ui_emit = 0;
  module->host.memory = 0;
  module->host.memory_size = 0;
  er_mem_zero((UINT8*)&module->host.linear_memory, (UINTN)sizeof(module->host.linear_memory));
  module->host.app_usage = 0;
  module->host.app_budget = 0;
  module->host.ui_presentation = 0;
}

static int er_reader_init(ErReader* r, const UINT8* data, UINT32 size) {
  if (r == 0) {
    return -1;
  }

  r->data = data;
  r->size = size;
  r->ofs = 0;
  return 0;
}

static int er_reader_more(const ErReader* r) {
  if (r == 0) {
    return 0;
  }
  return (r->ofs < r->size);
}

static int er_reader_read_u8(ErReader* r, UINT8* out) {
  if (r == 0 || out == 0) {
    return -1;
  }
  if (!er_reader_more(r)) {
    return -1;
  }

  *out = r->data[r->ofs];
  ++r->ofs;
  return 0;
}

static int er_reader_read_u32_leb(ErReader* r, UINT32* out) {
  UINT32 result = 0;
  UINT32 shift = 0;
  UINT8 byte = 0;
  UINT32 count = 0;

  if (r == 0 || out == 0) {
    return -1;
  }

  do {
    if (count++ >= ER_WASM_LEB32_MAX_BYTES || r->ofs >= r->size) {
      return -1;
    }
    byte = r->data[r->ofs++];
    result |= (UINT32)(byte & ER_WASM_LEB_PAYLOAD_MASK) << shift;
    shift += ER_WASM_LEB_BITS_PER_BYTE;
  } while (byte & ER_WASM_LEB_CONTINUE_MASK);

  *out = result;
  return 0;
}

static int er_reader_read_i64_leb(ErReader* r, INT64* out) {
  UINT8 byte = 0;
  INT64 result = 0;
  INT32 shift = 0;
  UINT8 count = 0;

  if (r == 0 || out == 0) {
    return -1;
  }

  do {
    if (count++ >= ER_WASM_LEB64_MAX_BYTES || r->ofs >= r->size) {
      return -1;
    }
    byte = r->data[r->ofs++];
    result |= (INT64)(byte & ER_WASM_LEB_PAYLOAD_MASK) << shift;
    shift += ER_WASM_LEB_BITS_PER_BYTE;
  } while (byte & ER_WASM_LEB_CONTINUE_MASK);

  if ((shift < 64) && (byte & ER_WASM_LEB_SIGN_MASK)) {
    result |= (INT64)(~((UINT64)0) << shift);
  }

  *out = result;
  return 0;
}

static int er_skip_leb_bytes(const UINT8* data, UINT32 size, UINT32* ofs, UINT32 max_bytes) {
  UINT8 byte = 0;
  UINT32 count = 0;

  if (data == 0 || ofs == 0 || max_bytes == 0u) {
    return -1;
  }

  while (*ofs < size) {
    byte = data[*ofs];
    ++(*ofs);
    if ((byte & ER_WASM_LEB_CONTINUE_MASK) == 0u) {
      return 0;
    }

    if (++count >= max_bytes) {
      return -1;
    }
  }

  return -1;
}

static int er_skip_u32_leb(const UINT8* data, UINT32 size, UINT32* ofs) {
  return er_skip_leb_bytes(data, size, ofs, ER_WASM_LEB32_MAX_BYTES);
}

static int er_skip_i64_leb(const UINT8* data, UINT32 size, UINT32* ofs) {
  return er_skip_leb_bytes(data, size, ofs, ER_WASM_LEB64_MAX_BYTES);
}

static int er_reader_skip(ErReader* r, UINT32 count) {
  if (r == 0 || count > r->size - r->ofs) {
    return -1;
  }
  r->ofs += count;
  return 0;
}

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

static int er_wasm_linear_memory_valid(const ErWasmLinearMemory* memory) {
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

static int er_wasm_memory_range(ErWasmModule* module, UINT64 offset, UINT32 len, UINT8** out_bytes) {
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

static int er_wasm_memory_window_range(ErWasmModule* module, UINT64 offset, UINT32 len,
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

static UINT32 er_wasm_load_u32(const UINT8* src) {
  return (UINT32)src[ER_WASM_U32_BYTE0] |
         ((UINT32)src[ER_WASM_U32_BYTE1] << ER_WASM_U32_BYTE1_SHIFT) |
         ((UINT32)src[ER_WASM_U32_BYTE2] << ER_WASM_U32_BYTE2_SHIFT) |
         ((UINT32)src[ER_WASM_U32_BYTE3] << ER_WASM_U32_BYTE3_SHIFT);
}

static UINT64 er_wasm_load_u64(const UINT8* src) {
  return (UINT64)er_wasm_load_u32(src) |
         ((UINT64)er_wasm_load_u32(src + ER_WASM_U32_BYTES) << ER_WASM_U64_HIGH32_SHIFT);
}

static UINT16 er_wasm_load_u16(const UINT8* src) {
  return (UINT16)src[ER_WASM_U32_BYTE0] |
         (UINT16)((UINT16)src[ER_WASM_U32_BYTE1] << ER_WASM_U32_BYTE1_SHIFT);
}

static int er_wasm_ui_command_stats(const UINT8* bytes, UINT32 len,
                                    er_ui_scene_stats_t* out_stats) {
  UINT64 command_count;
  UINT64 summed_count;

  if (bytes == 0 || out_stats == 0 || len != ER_WASM_UI_COMMAND_LIST_HEADER_LEN) {
    return -1;
  }
  if (er_wasm_load_u16(bytes + ER_WASM_UI_HEADER_ABI_OFFSET) !=
      ER_WASM_UI_COMMAND_ABI_VERSION) {
    return -1;
  }

  er_mem_zero((UINT8*)out_stats, (UINTN)sizeof(*out_stats));
  command_count = (UINT64)er_wasm_load_u32(bytes + ER_WASM_UI_HEADER_COMMAND_COUNT_OFFSET);
  out_stats->rects = (size_t)er_wasm_load_u32(bytes + ER_WASM_UI_HEADER_RECT_COUNT_OFFSET);
  out_stats->hits = (size_t)er_wasm_load_u32(bytes + ER_WASM_UI_HEADER_HIT_COUNT_OFFSET);
  out_stats->drag_sources =
      (size_t)er_wasm_load_u32(bytes + ER_WASM_UI_HEADER_DRAG_SOURCE_COUNT_OFFSET);
  out_stats->drop_targets =
      (size_t)er_wasm_load_u32(bytes + ER_WASM_UI_HEADER_DROP_TARGET_COUNT_OFFSET);
  out_stats->transitions =
      (size_t)er_wasm_load_u32(bytes + ER_WASM_UI_HEADER_TRANSITION_COUNT_OFFSET);
  out_stats->icon_quads =
      (size_t)er_wasm_load_u32(bytes + ER_WASM_UI_HEADER_ICON_QUAD_COUNT_OFFSET);
  out_stats->text_quads =
      (size_t)er_wasm_load_u32(bytes + ER_WASM_UI_HEADER_TEXT_QUAD_COUNT_OFFSET);

  summed_count = (UINT64)out_stats->rects + (UINT64)out_stats->hits +
                 (UINT64)out_stats->drag_sources + (UINT64)out_stats->drop_targets +
                 (UINT64)out_stats->transitions + (UINT64)out_stats->icon_quads +
                 (UINT64)out_stats->text_quads;
  if (command_count == 0u || command_count != summed_count) {
    return -1;
  }
  return 0;
}

static void er_wasm_store_u32(UINT8* dst, UINT32 value) {
  dst[ER_WASM_U32_BYTE0] = (UINT8)(value & ER_WASM_U8_MASK);
  dst[ER_WASM_U32_BYTE1] = (UINT8)((value >> ER_WASM_U32_BYTE1_SHIFT) & ER_WASM_U8_MASK);
  dst[ER_WASM_U32_BYTE2] = (UINT8)((value >> ER_WASM_U32_BYTE2_SHIFT) & ER_WASM_U8_MASK);
  dst[ER_WASM_U32_BYTE3] = (UINT8)((value >> ER_WASM_U32_BYTE3_SHIFT) & ER_WASM_U8_MASK);
}

static void er_wasm_store_u64(UINT8* dst, UINT64 value) {
  er_wasm_store_u32(dst, (UINT32)(value & ER_WASM_U32_MASK));
  er_wasm_store_u32(dst + ER_WASM_U32_BYTES, (UINT32)(value >> ER_WASM_U64_HIGH32_SHIFT));
}

static int er_read_string(ErReader* r, const UINT8** out_string, UINT32* out_len) {
  UINT32 len = 0;

  if (r == 0 || out_string == 0 || out_len == 0) {
    return -1;
  }

  if (er_reader_read_u32_leb(r, &len) != 0) {
    return -1;
  }

  if (r->ofs + len > r->size) {
    return -1;
  }

  *out_string = &r->data[r->ofs];
  *out_len = len;
  r->ofs += len;
  return 0;
}

static int er_scan_matching_end(const UINT8* data, UINT32 size, UINT32 start_pc, UINT32* out_end_pc, UINT32* out_else_pc) {
  UINT32 pc = start_pc;
  UINT32 depth = 1;

  if (data == 0 || out_end_pc == 0) {
    return -1;
  }

  if (start_pc >= size) {
    return -1;
  }

  if (out_else_pc != 0) {
    *out_else_pc = 0;
  }

  while (pc < size) {
    UINT8 op = data[pc++];

    if (op == ER_WASM_OP_BLOCK || op == ER_WASM_OP_LOOP || op == ER_WASM_OP_IF) {
      if (pc >= size) {
        return -1;
      }
      pc += 1; /* block type */
      ++depth;
      continue;
    }

    if (op == ER_WASM_OP_ELSE) {
      if (depth == 1 && out_else_pc != 0 && *out_else_pc == 0) {
        *out_else_pc = pc;
      }
      continue;
    }

    if (op == ER_WASM_OP_END) {
      if (depth == 0) {
        return -1;
      }
      if (depth == 1) {
        *out_end_pc = pc;
        return 0;
      }
      --depth;
      continue;
    }

    if (op == ER_WASM_OP_CALL || op == ER_WASM_OP_BR || op == ER_WASM_OP_BR_IF ||
        op == ER_WASM_OP_LOCAL_GET || op == ER_WASM_OP_LOCAL_SET || op == ER_WASM_OP_LOCAL_TEE) {
      if (er_skip_u32_leb(data, size, &pc) != 0) {
        return -1;
      }
      continue;
    }

    if (op == ER_WASM_OP_I32_CONST) {
      if (er_skip_u32_leb(data, size, &pc) != 0) {
        return -1;
      }
      continue;
    }

    if (op == ER_WASM_OP_I64_CONST) {
      if (er_skip_i64_leb(data, size, &pc) != 0) {
        return -1;
      }
      continue;
    }

    if (op >= ER_WASM_OP_I32_LOAD && op <= ER_WASM_OP_MEMORY_MAX) {
      if (er_skip_u32_leb(data, size, &pc) != 0 || er_skip_u32_leb(data, size, &pc) != 0) {
        return -1;
      }
      continue;
    }

    if (op == ER_WASM_OP_MEMORY_SIZE || op == ER_WASM_OP_MEMORY_GROW) {
      if (er_skip_u32_leb(data, size, &pc) != 0) {
        return -1;
      }
      continue;
    }
  }

  return -1;
}

//@optimizer-ignore-function Wasm module initialization must parse each declared section and type entry
int er_wasm_init(ErWasmModule* module, const UINT8* data, UINT32 size, const ErWasmHostCalls* host) {
  ErReader r;
  ErFuncType temp_type[ER_WASM_MAX_FUNCTIONS];
  ErFuncType func_types[ER_WASM_MAX_FUNCTIONS];
  UINT8 i;

  if (module == 0) {
    return -1;
  }

  er_clear_module(module);

  if (host != 0) {
    module->host.log_u64 = host->log_u64;
    module->host.log_hex = host->log_hex;
    module->host.pci_read32 = host->pci_read32;
    module->host.pci_write32 = host->pci_write32;
    module->host.mmio_map = host->mmio_map;
    module->host.mmio_read32 = host->mmio_read32;
    module->host.bus_exec = host->bus_exec;
    module->host.relay_send = host->relay_send;
    module->host.relay_recv = host->relay_recv;
    module->host.ui_emit = host->ui_emit;
    module->host.memory = host->memory;
    module->host.memory_size = host->memory_size;
    module->host.linear_memory = host->linear_memory;
    module->host.app_usage = host->app_usage;
    module->host.app_budget = host->app_budget;
    module->host.ui_presentation = host->ui_presentation;
    if (host->linear_memory.bytes != 0) {
      if (er_wasm_linear_memory_valid(&host->linear_memory) == 0) {
        return -1;
      }
      module->linear_memory = host->linear_memory;
      module->memory = host->linear_memory.bytes;
      module->memory_size = host->linear_memory.address_len;
    } else if (host->memory != 0 && host->memory_size != 0u) {
      if (er_wasm_prepare_linear_memory(host->memory, host->memory_size,
                                        ER_WASM_LINEAR_MEMORY_BASE, host->memory_size,
                                        ER_WASM_LINEAR_MEMORY_BASE, host->memory_size,
                                        &module->linear_memory) != 0) {
        return -1;
      }
      module->host.linear_memory = module->linear_memory;
      module->memory = host->memory;
      module->memory_size = host->memory_size;
    }
  }

  if (er_reader_init(&r, data, size) != 0) {
    return -1;
  }

  if (size < ER_WASM_MAGIC_BYTES) {
    return -1;
  }

  if (data[ER_WASM_HEADER_BYTE0] != ER_WASM_MAGIC_0 ||
      data[ER_WASM_HEADER_BYTE1] != ER_WASM_MAGIC_1 ||
      data[ER_WASM_HEADER_BYTE2] != ER_WASM_MAGIC_2 ||
      data[ER_WASM_HEADER_BYTE3] != ER_WASM_MAGIC_3) {
    return -1;
  }

  if (data[ER_WASM_HEADER_BYTE4] != ER_WASM_VERSION_0 ||
      data[ER_WASM_HEADER_BYTE5] != ER_WASM_VERSION_1 ||
      data[ER_WASM_HEADER_BYTE6] != ER_WASM_VERSION_2 ||
      data[ER_WASM_HEADER_BYTE7] != ER_WASM_VERSION_3) {
    return -1;
  }

  r.ofs = ER_WASM_MAGIC_BYTES;

  while (r.ofs < r.size) {
    UINT8 section_id = 0;
    UINT32 section_len = 0;
    UINT32 section_end = 0;

    if (er_reader_read_u8(&r, &section_id) != 0) {
      return -1;
    }
    if (er_reader_read_u32_leb(&r, &section_len) != 0) {
      return -1;
    }

    if (section_len > r.size - r.ofs) {
      return -1;
    }

    section_end = r.ofs + section_len;

    if (section_id == ER_WASM_SECTION_TYPE) {
      UINT32 type_count = 0;
      if (er_reader_read_u32_leb(&r, &type_count) != 0) {
        return -1;
      }
      if (type_count > ER_WASM_MAX_FUNCTIONS) {
        return -1;
      }

      for (i = 0; i < (UINT8)type_count; ++i) {
        UINT8 form;
        UINT32 param_count;
        UINT32 result_count;

        if (er_reader_read_u8(&r, &form) != 0) {
          return -1;
        }
        if (form != ER_WASM_TYPE_FORM_FUNC) {
          return -1;
        }

        if (er_reader_read_u32_leb(&r, &param_count) != 0) {
          return -1;
        }

        if (param_count > ER_WASM_MAX_TYPE_PARAMS) {
          return -1;
        }

        for (UINT32 p = 0; p < param_count; ++p) {
          UINT8 skip;
          if (er_reader_read_u8(&r, &skip) != 0) {
            return -1;
          }
          if (skip != ER_WASM_VALTYPE_I64 && skip != ER_WASM_VALTYPE_I32 &&
              skip != ER_WASM_VALTYPE_F32 && skip != ER_WASM_VALTYPE_F64) {
            return -1;
          }
        }

        if (er_reader_read_u32_leb(&r, &result_count) != 0) {
          return -1;
        }
        if (result_count > ER_WASM_MAX_TYPE_RESULTS) {
          return -1;
        }

        temp_type[i].form = form;
        temp_type[i].param_count = (UINT8)param_count;
        temp_type[i].result_count = (UINT8)result_count;
        temp_type[i].result_type = 0;

        if (result_count == 1) {
          if (er_reader_read_u8(&r, &temp_type[i].result_type) != 0) {
            return -1;
          }
        }
      }

      for (i = 0; i < (UINT8)type_count; ++i) {
        func_types[i] = temp_type[i];
      }
      module->num_types = type_count;
    } else if (section_id == ER_WASM_SECTION_IMPORT) {
      UINT32 import_count = 0;
      if (er_reader_read_u32_leb(&r, &import_count) != 0) {
        return -1;
      }
      if (import_count > ER_WASM_MAX_FUNCTIONS) {
        return -1;
      }

      for (UINT32 import_i = 0; import_i < import_count; ++import_i) {
        UINT8 import_kind = ER_IMPORT_KIND_NONE;
        UINT8 kind = 0;
        UINT32 type_index = 0;
        UINT32 function_index = 0;
        const UINT8* module_name = 0;
        UINT32 module_len = 0;
        const UINT8* field_name = 0;
        UINT32 field_len = 0;

        if (module->num_funcs >= ER_WASM_MAX_FUNCTIONS) {
          return -1;
        }

        if (er_read_string(&r, &module_name, &module_len) != 0) {
          return -1;
        }
        if (er_read_string(&r, &field_name, &field_len) != 0) {
          return -1;
        }

        import_kind = er_find_host_import(module_name, module_len, field_name, field_len);

        if (er_reader_read_u8(&r, &kind) != 0) {
          return -1;
        }
        if (kind != ER_WASM_EXTERNAL_KIND_FUNC) {
          return -1;
        }
        if (er_reader_read_u32_leb(&r, &type_index) != 0 || type_index >= module->num_types) {
          return -1;
        }

        function_index = module->num_funcs;
        module->function_type_indices[function_index] = type_index;
        module->function_is_import[function_index] = 1;
        module->function_import_kind[function_index] = import_kind;
        module->num_funcs += 1;
        module->num_imports += 1;
      }
    } else if (section_id == ER_WASM_SECTION_FUNCTION) {
      UINT32 func_count = 0;
      if (er_reader_read_u32_leb(&r, &func_count) != 0) {
        return -1;
      }
      if (func_count > ER_WASM_MAX_FUNCTIONS ||
          module->num_funcs + func_count > ER_WASM_MAX_FUNCTIONS) {
        return -1;
      }

      for (UINT32 func_i = 0; func_i < func_count; ++func_i) {
        UINT32 type_index = 0;
        if (er_reader_read_u32_leb(&r, &type_index) != 0 || type_index >= module->num_types) {
          return -1;
        }
        module->function_type_indices[module->num_funcs] = type_index;
        module->function_is_import[module->num_funcs] = 0;
        module->function_import_kind[module->num_funcs] = ER_IMPORT_KIND_NONE;
        module->num_funcs += 1;
      }
    } else if (section_id == ER_WASM_SECTION_MEMORY) {
      UINT32 memory_count = 0;
      UINT8 flags = 0;
      UINT32 min_pages = 0;
      UINT32 max_pages = 0;

      if (er_reader_read_u32_leb(&r, &memory_count) != 0 || memory_count > 1u) {
        return -1;
      }
      if (memory_count == 1u) {
        if (er_reader_read_u8(&r, &flags) != 0 ||
            (flags & (UINT8)~ER_WASM_MEMORY_LIMIT_HAS_MAX) != 0u) {
          return -1;
        }
        if (er_reader_read_u32_leb(&r, &min_pages) != 0) {
          return -1;
        }
        if ((flags & ER_WASM_MEMORY_LIMIT_HAS_MAX) != 0u &&
            er_reader_read_u32_leb(&r, &max_pages) != 0) {
          return -1;
        }
        if (min_pages > 0u) {
          UINT64 required_bytes = (UINT64)min_pages * ER_WASM_MEMORY_PAGE_BYTES;
          if (module->memory == 0 || required_bytes > (UINT64)module->memory_size) {
            return -1;
          }
          er_mem_zero(module->memory, (UINTN)required_bytes);
        }
        module->memory_min_pages = min_pages;
      }
    } else if (section_id == ER_WASM_SECTION_EXPORT) {
      UINT32 export_count = 0;
      if (er_reader_read_u32_leb(&r, &export_count) != 0) {
        return -1;
      }
      if (export_count > ER_WASM_MAX_FUNCTIONS) {
        return -1;
      }

      module->num_exports = export_count;

      for (i = 0; i < (UINT8)export_count; ++i) {
        UINT32 name_len = 0;
        UINT8 is_main = 0;
        UINT8 kind = 0;
        UINT32 index = 0;

        if (er_reader_read_u32_leb(&r, &name_len) != 0) {
          return -1;
        }

        if (name_len == ER_WASM_MAIN_NAME_LEN &&
            r.ofs + ER_WASM_MAIN_NAME_LEN <= r.size &&
            r.data[r.ofs] == ER_WASM_MAIN_NAME_BYTE0 &&
            r.data[r.ofs + ER_WASM_U32_BYTE1] == ER_WASM_MAIN_NAME_BYTE1 &&
            r.data[r.ofs + ER_WASM_U32_BYTE2] == ER_WASM_MAIN_NAME_BYTE2 &&
            r.data[r.ofs + ER_WASM_U32_BYTE3] == ER_WASM_MAIN_NAME_BYTE3) {
          r.ofs += ER_WASM_MAIN_NAME_LEN;
          is_main = 1;
        } else {
          r.ofs += name_len;
        }

        if (er_reader_read_u8(&r, &kind) != 0) {
          return -1;
        }
        if (er_reader_read_u32_leb(&r, &index) != 0) {
          return -1;
        }

        if (is_main) {
          if (kind != ER_WASM_EXTERNAL_KIND_FUNC) {
            return -1;
          }
          module->function_has_main = 1;
          module->main_index = index;
        }
      }
    } else if (section_id == ER_WASM_SECTION_CODE) {
      UINT32 body_count = 0;
      if (er_reader_read_u32_leb(&r, &body_count) != 0) {
        return -1;
      }

      if (body_count > ER_WASM_MAX_FUNCTIONS ||
          body_count > module->num_funcs - module->num_imports) {
        return -1;
      }

      for (i = 0; i < (UINT8)body_count; ++i) {
        UINT32 body_size = 0;
        UINT32 body_start = 0;
        UINT32 body_end = 0;
        UINT32 local_count = 0;
        UINT32 local_total = 0;

        if (er_reader_read_u32_leb(&r, &body_size) != 0) {
          return -1;
        }

        if (r.ofs + body_size > r.size) {
          return -1;
        }

        body_start = r.ofs;
        body_end = body_start + body_size;

        if (er_reader_read_u32_leb(&r, &local_count) != 0) {
          return -1;
        }

        for (UINT32 l = 0; l < local_count; ++l) {
          UINT32 local_repeat = 0;
          UINT8 local_type = 0;
          if (er_reader_read_u32_leb(&r, &local_repeat) != 0) {
            return -1;
          }
          if (er_reader_read_u8(&r, &local_type) != 0) {
            return -1;
          }
          if (local_type != ER_WASM_VALTYPE_I64) {
            return -1;
          }
          local_total += local_repeat;
          if (local_total > ER_WASM_MAX_LOCALS) {
            return -1;
          }
        }

        module->code[module->num_imports + i].body = &r.data[r.ofs];
        if (r.ofs > body_end) {
          return -1;
        }
        module->code[module->num_imports + i].size = body_end - r.ofs;
        module->code[module->num_imports + i].local_count = (UINT8)local_total;
        r.ofs = body_end;
      }
    } else if (section_id == ER_WASM_SECTION_DATA) {
      UINT32 segment_count = 0;

      if (er_reader_read_u32_leb(&r, &segment_count) != 0 ||
          segment_count > ER_WASM_MAX_DATA_SEGMENTS) {
        return -1;
      }
      for (UINT32 segment_i = 0; segment_i < segment_count; ++segment_i) {
        UINT32 flags = 0;
        UINT8 op = 0;
        UINT32 offset = 0;
        UINT32 len = 0;
        UINT8* dst = 0;

        if (er_reader_read_u32_leb(&r, &flags) != 0 || flags != 0u) {
          return -1;
        }
        if (er_reader_read_u8(&r, &op) != 0 || op != ER_WASM_OP_I32_CONST) {
          return -1;
        }
        if (er_reader_read_u32_leb(&r, &offset) != 0) {
          return -1;
        }
        if (er_reader_read_u8(&r, &op) != 0 || op != ER_WASM_OP_END) {
          return -1;
        }
        if (er_reader_read_u32_leb(&r, &len) != 0) {
          return -1;
        }
        if (len > r.size - r.ofs || er_wasm_memory_range(module, offset, len, &dst) != 0) {
          return -1;
        }
        for (UINT32 byte_i = 0; byte_i < len; ++byte_i) {
          dst[byte_i] = r.data[r.ofs + byte_i];
        }
        r.ofs += len;
      }
    } else {
      if (er_reader_skip(&r, section_len) != 0) {
        return -1;
      }
    }

    if (r.ofs != section_end) {
      r.ofs = section_end;
    }
  }

  for (i = 0; i < module->num_types; ++i) {
    if (i < ER_WASM_MAX_FUNCTIONS) {
      module->type_params_0[i] = func_types[i].param_count;
      module->type_result_count[i] = func_types[i].result_count;
      module->type_result_type[i] = func_types[i].result_type;
    }
  }

  return 0;
}

int er_wasm_find_main(ErWasmModule* module, UINT32* main_index) {
  if (module == 0 || main_index == 0) {
    return -1;
  }

  if (!module->function_has_main) {
    return -1;
  }

  *main_index = module->main_index;
  return 0;
}

//@optimizer-ignore-function Wasm interpreter must dispatch bytecode, invoke host calls, and scan structured control blocks
int er_wasm_execute_i64(ErWasmModule* module, UINT32 function_index, INT64* result) {
  if (module == 0 || result == 0) {
    return -1;
  }

  if (function_index >= module->num_funcs) {
    return -1;
  }
  if (module->function_is_import[function_index]) {
    return -1;
  }

  {
    UINT32 type_index = module->function_type_indices[function_index];
    const ErWasmCode* c = 0;
    UINT8 param_count = 0;
    UINT8 local_limit = 0;
    UINT8 local_total = 0;
    INT64 stack[ER_WASM_STACK_MAX];
    UINT32 stack_size = 0;
    INT64 locals[ER_WASM_STACK_MAX];

    if (type_index >= module->num_types) {
      return -1;
    }
    if (module->type_params_0[type_index] != 0) {
      return -1;
    }
    if (module->type_result_count[type_index] != 1) {
      return -1;
    }
    if (module->type_result_type[type_index] != ER_WASM_VALTYPE_I64) {
      return -1;
    }

    c = &module->code[function_index];
    if (c->body == 0 || c->size == 0) {
      return -1;
    }

    param_count = module->type_params_0[type_index];
    local_total = c->local_count;
    if (param_count + local_total > ER_WASM_STACK_MAX) {
      return -1;
    }

    local_limit = param_count + local_total;
    for (UINT8 l = 0; l < local_limit; ++l) {
      locals[l] = 0;
    }

    ErReader code;
    ErControlFrame control[ER_WASM_MAX_CONTROL_DEPTH];
    UINT32 control_depth = 0;

    er_reader_init(&code, c->body, c->size);

    while (er_reader_more(&code)) {
      UINT8 op = 0;
      UINT32 i32value = 0;
      UINT32 target = 0;
      UINT32 matching_end = 0;
      UINT32 matching_else = 0;

      if (er_reader_read_u8(&code, &op) != 0) {
        return -1;
      }

      if (op == ER_WASM_OP_I64_CONST) {
        INT64 value = 0;
        if (stack_size >= ER_WASM_STACK_MAX) {
          return -1;
        }
        if (er_reader_read_i64_leb(&code, &value) != 0) {
          return -1;
        }
        stack[stack_size++] = value;
      } else if (op == ER_WASM_OP_I32_CONST) {
        UINT32 value = 0;
        INT64 signed_value = 0;
        if (stack_size >= ER_WASM_STACK_MAX) {
          return -1;
        }
        if (er_reader_read_u32_leb(&code, &value) != 0) {
          return -1;
        }
        signed_value = (INT64)(UINT64)value;
        stack[stack_size++] = signed_value;
      } else if (op == ER_WASM_OP_LOCAL_GET) {
        UINT32 index = 0;
        if (er_reader_read_u32_leb(&code, &index) != 0) {
          return -1;
        }
        if (index >= local_limit) {
          return -1;
        }
        if (stack_size >= ER_WASM_STACK_MAX) {
          return -1;
        }
        stack[stack_size++] = locals[index];
      } else if (op == ER_WASM_OP_LOCAL_SET) {
        UINT32 index = 0;
        if (er_reader_read_u32_leb(&code, &index) != 0) {
          return -1;
        }
        if (index >= local_limit) {
          return -1;
        }
        if (stack_size == 0) {
          return -1;
        }
        locals[index] = stack[--stack_size];
      } else if (op == ER_WASM_OP_LOCAL_TEE) {
        UINT32 index = 0;
        if (er_reader_read_u32_leb(&code, &index) != 0) {
          return -1;
        }
        if (index >= local_limit) {
          return -1;
        }
        if (stack_size == 0) {
          return -1;
        }
        locals[index] = stack[stack_size - 1];
      } else if (op == ER_WASM_OP_I32_LOAD || op == ER_WASM_OP_I64_LOAD ||
                 op == ER_WASM_OP_I32_LOAD8_U || op == ER_WASM_OP_I32_LOAD16_U) {
        UINT32 align = 0;
        UINT32 offset = 0;
        UINT64 address = 0;
        UINT32 width = 0;
        UINT8* bytes = 0;

        if (er_reader_read_u32_leb(&code, &align) != 0 || er_reader_read_u32_leb(&code, &offset) != 0) {
          return -1;
        }
        (void)align;
        if (stack_size < 1) {
          return -1;
        }
        address = (UINT64)stack[--stack_size] + (UINT64)offset;
        if (op == ER_WASM_OP_I32_LOAD8_U) {
          width = ER_WASM_U8_BYTES;
        } else if (op == ER_WASM_OP_I32_LOAD16_U) {
          width = ER_WASM_U16_BYTES;
        } else if (op == ER_WASM_OP_I32_LOAD) {
          width = ER_WASM_U32_BYTES;
        } else {
          width = ER_WASM_U64_BYTES;
        }
        if (er_wasm_memory_range(module, address, width, &bytes) != 0 ||
            stack_size >= ER_WASM_STACK_MAX) {
          return -1;
        }
        if (width == ER_WASM_U8_BYTES) {
          stack[stack_size++] = (INT64)bytes[0];
        } else if (width == ER_WASM_U16_BYTES) {
          stack[stack_size++] = (INT64)((UINT32)bytes[0] | ((UINT32)bytes[1] << 8));
        } else if (width == ER_WASM_U32_BYTES) {
          stack[stack_size++] = (INT64)(UINT64)er_wasm_load_u32(bytes);
        } else {
          stack[stack_size++] = (INT64)er_wasm_load_u64(bytes);
        }
      } else if (op == ER_WASM_OP_I32_STORE || op == ER_WASM_OP_I64_STORE ||
                 op == ER_WASM_OP_I32_STORE8 || op == ER_WASM_OP_I32_STORE16) {
        UINT32 align = 0;
        UINT32 offset = 0;
        UINT64 address = 0;
        INT64 value = 0;
        UINT32 width = 0;
        UINT8* bytes = 0;

        if (er_reader_read_u32_leb(&code, &align) != 0 || er_reader_read_u32_leb(&code, &offset) != 0) {
          return -1;
        }
        (void)align;
        if (stack_size < 2) {
          return -1;
        }
        value = stack[--stack_size];
        address = (UINT64)stack[--stack_size] + (UINT64)offset;
        if (op == ER_WASM_OP_I32_STORE8) {
          width = ER_WASM_U8_BYTES;
        } else if (op == ER_WASM_OP_I32_STORE16) {
          width = ER_WASM_U16_BYTES;
        } else if (op == ER_WASM_OP_I32_STORE) {
          width = ER_WASM_U32_BYTES;
        } else {
          width = ER_WASM_U64_BYTES;
        }
        if (er_wasm_memory_range(module, address, width, &bytes) != 0) {
          return -1;
        }
        if (width == ER_WASM_U8_BYTES) {
          bytes[0] = (UINT8)value;
        } else if (width == ER_WASM_U16_BYTES) {
          bytes[ER_WASM_U32_BYTE0] = (UINT8)((UINT64)value & ER_WASM_U8_MASK);
          bytes[ER_WASM_U32_BYTE1] =
            (UINT8)(((UINT64)value >> ER_WASM_U32_BYTE1_SHIFT) & ER_WASM_U8_MASK);
        } else if (width == ER_WASM_U32_BYTES) {
          er_wasm_store_u32(bytes, (UINT32)value);
        } else {
          er_wasm_store_u64(bytes, (UINT64)value);
        }
      } else if (op == ER_WASM_OP_MEMORY_SIZE) {
        UINT32 memory_index = 0;
        if (er_reader_read_u32_leb(&code, &memory_index) != 0 ||
            memory_index != ER_WASM_MEMORY_INDEX_ZERO ||
            stack_size >= ER_WASM_STACK_MAX) {
          return -1;
        }
        stack[stack_size++] = (INT64)(module->memory_size / ER_WASM_MEMORY_PAGE_BYTES);
      } else if (op == ER_WASM_OP_I64_NE) {
        INT64 left = 0;
        INT64 right = 0;
        if (stack_size < 2) {
          return -1;
        }
        right = stack[--stack_size];
        left = stack[--stack_size];
        stack[stack_size++] = (left != right) ? 1 : 0;
      } else if (op == ER_WASM_OP_I64_EQ) {
        INT64 left = 0;
        INT64 right = 0;
        if (stack_size < 2) {
          return -1;
        }
        right = stack[--stack_size];
        left = stack[--stack_size];
        stack[stack_size++] = (left == right) ? 1 : 0;
      } else if (op == ER_WASM_OP_I64_LT_U) {
        UINT64 left = 0;
        UINT64 right = 0;
        if (stack_size < 2) {
          return -1;
        }
        right = (UINT64)stack[--stack_size];
        left = (UINT64)stack[--stack_size];
        stack[stack_size++] = (left < right) ? 1 : 0;
      } else if (op == ER_WASM_OP_I64_AND) {
        INT64 right = 0;
        INT64 left = 0;
        if (stack_size < 2) {
          return -1;
        }
        right = stack[--stack_size];
        left = stack[--stack_size];
        stack[stack_size++] = left & right;
      } else if (op == ER_WASM_OP_I64_ADD) {
        INT64 right = 0;
        INT64 left = 0;
        if (stack_size < 2) {
          return -1;
        }
        right = stack[--stack_size];
        left = stack[--stack_size];
        stack[stack_size++] = left + right;
      } else if (op == ER_WASM_OP_I32_EQZ) {
        INT64 value = 0;
        if (stack_size < 1) {
          return -1;
        }
        value = stack[--stack_size];
        stack[stack_size++] = (value == 0) ? 1 : 0;
      } else if (op == ER_WASM_OP_CALL) {
        UINT32 type_index_local = 0;
        if (er_reader_read_u32_leb(&code, &target) != 0) {
          return -1;
        }
        if (target >= module->num_funcs) {
          return -1;
        }
        if (!module->function_is_import[target]) {
          return -1;
        }

        type_index_local = module->function_type_indices[target];
        if (type_index_local >= module->num_types) {
          return -1;
        }

        {
          UINT8 import_kind = module->function_import_kind[target];
          UINT8 param_count_call = module->type_params_0[type_index_local];
          UINT8 result_count = module->type_result_count[type_index_local];
          UINT8 result_type = module->type_result_type[type_index_local];

          if (import_kind == ER_IMPORT_KIND_LOG_U64) {
            INT64 value = 0;
            if (param_count_call != 1 || result_count != 0) {
              return -1;
            }
            if (stack_size < 1) {
              return -1;
            }
            if (module->host.log_u64 == 0) {
              return -1;
            }
            value = stack[--stack_size];
            module->host.log_u64(value);
          } else if (import_kind == ER_IMPORT_KIND_LOG_HEX) {
            INT64 value = 0;
            if (param_count_call != 1 || result_count != 0) {
              return -1;
            }
            if (stack_size < 1) {
              return -1;
            }
            if (module->host.log_hex == 0) {
              return -1;
            }
            value = stack[--stack_size];
            module->host.log_hex((UINT64)value);
          } else if (import_kind == ER_IMPORT_KIND_PCI_READ32) {
            INT64 value = 0;
            INT64 bus = 0;
            INT64 dev = 0;
            INT64 func = 0;
            INT64 offset = 0;
            if (param_count_call != ER_WASM_PCI_READ32_PARAM_COUNT || result_count != 1) {
              return -1;
            }
            if (result_type != ER_WASM_VALTYPE_I64) {
              return -1;
            }
            if (stack_size < ER_WASM_PCI_READ32_PARAM_COUNT) {
              return -1;
            }
            if (module->host.pci_read32 == 0) {
              return -1;
            }
            offset = stack[--stack_size];
            func = stack[--stack_size];
            dev = stack[--stack_size];
            bus = stack[--stack_size];

            value = module->host.pci_read32(bus, dev, func, offset);
            if (stack_size >= ER_WASM_STACK_MAX) {
              return -1;
            }
            stack[stack_size++] = value;
          } else if (import_kind == ER_IMPORT_KIND_PCI_WRITE32) {
            INT64 bus = 0;
            INT64 dev = 0;
            INT64 func = 0;
            INT64 offset = 0;
            INT64 value = 0;
            if (param_count_call != ER_WASM_PCI_WRITE32_PARAM_COUNT || result_count != 0) {
              return -1;
            }
            if (stack_size < ER_WASM_PCI_WRITE32_PARAM_COUNT) {
              return -1;
            }
            if (module->host.pci_write32 == 0) {
              return -1;
            }
            value = stack[--stack_size];
            offset = stack[--stack_size];
            func = stack[--stack_size];
            dev = stack[--stack_size];
            bus = stack[--stack_size];
            module->host.pci_write32(bus, dev, func, offset, value);
          } else if (import_kind == ER_IMPORT_KIND_MMIO_MAP) {
            INT64 value = 0;
            INT64 phys = 0;
            INT64 len = 0;
            if (param_count_call != 2 || result_count != 1) {
              return -1;
            }
            if (result_type != ER_WASM_VALTYPE_I64) {
              return -1;
            }
            if (stack_size < 2) {
              return -1;
            }
            if (module->host.mmio_map == 0) {
              return -1;
            }
            len = stack[--stack_size];
            phys = stack[--stack_size];

            value = module->host.mmio_map(phys, len);
            if (stack_size >= ER_WASM_STACK_MAX) {
              return -1;
            }
            stack[stack_size++] = value;
          } else if (import_kind == ER_IMPORT_KIND_MMIO_READ32) {
            INT64 value = 0;
            INT64 handle = 0;
            INT64 offset = 0;
            if (param_count_call != 2 || result_count != 1) {
              return -1;
            }
            if (result_type != ER_WASM_VALTYPE_I64) {
              return -1;
            }
            if (stack_size < 2) {
              return -1;
            }
            if (module->host.mmio_read32 == 0) {
              return -1;
            }
            offset = stack[--stack_size];
            handle = stack[--stack_size];

            value = module->host.mmio_read32(handle, offset);
            if (stack_size >= ER_WASM_STACK_MAX) {
              return -1;
            }
            stack[stack_size++] = value;
          } else if (import_kind == ER_IMPORT_KIND_BUS_EXEC) {
            INT64 value = 0;
            INT64 request_ptr = 0;
            INT64 response_ptr = 0;
            UINT8* request_bytes = 0;
            UINT8* response_bytes = 0;

            if (param_count_call != 2 || result_count != 1) {
              return -1;
            }
            if (result_type != ER_WASM_VALTYPE_I64) {
              return -1;
            }
            if (stack_size < 2) {
              return -1;
            }
            if (module->host.bus_exec == 0) {
              return -1;
            }
            response_ptr = stack[--stack_size];
            request_ptr = stack[--stack_size];
            if (request_ptr < 0 || response_ptr < 0) {
              return -1;
            }
            if (er_wasm_memory_range(module, (UINT64)request_ptr, (UINT32)sizeof(ErBusIoPacket),
                                     &request_bytes) != 0 ||
                er_wasm_memory_range(module, (UINT64)response_ptr, (UINT32)sizeof(ErBusIoPacket),
                                     &response_bytes) != 0) {
              return -1;
            }

            value = module->host.bus_exec((const ErBusIoPacket*)request_bytes,
                                          (ErBusIoPacket*)response_bytes);
            if (stack_size >= ER_WASM_STACK_MAX) {
              return -1;
            }
            stack[stack_size++] = value;
          } else if (import_kind == ER_IMPORT_KIND_RELAY_SEND) {
            INT64 value = 0;
            INT64 ptr = 0;
            INT64 len = 0;
            UINT8* bytes = 0;

            if (param_count_call != 2 || result_count != 1) {
              return -1;
            }
            if (result_type != ER_WASM_VALTYPE_I64) {
              return -1;
            }
            if (stack_size < 2) {
              return -1;
            }
            if (module->host.relay_send == 0) {
              return -1;
            }
            len = stack[--stack_size];
            ptr = stack[--stack_size];
            if (ptr < 0 || len < 0 || (UINT64)len > (UINT64)ER_WASM_U32_MASK) {
              return -1;
            }
            if (er_wasm_memory_window_range(module, (UINT64)ptr, (UINT32)len,
                                            module->linear_memory.relay_outbox_base,
                                            module->linear_memory.relay_outbox_len,
                                            &bytes) != 0) {
              return -1;
            }
            if (er_relay_packet_authorized_for_app((const UINT8*)bytes, (UINT32)len,
                                                   module->host.app_usage,
                                                   module->host.app_budget) == 0u ||
                er_app_usage_charge(module->host.app_usage, module->host.app_budget,
                                    ER_APP_BUDGET_PACKET_BYTE, (UINT64)len) == 0u) {
              return -1;
            }

            value = module->host.relay_send((const UINT8*)bytes, (UINT32)len);
            if (stack_size >= ER_WASM_STACK_MAX) {
              return -1;
            }
            stack[stack_size++] = value;
          } else if (import_kind == ER_IMPORT_KIND_RELAY_RECV) {
            INT64 value = 0;
            INT64 ptr = 0;
            INT64 capacity = 0;
            UINT8* bytes = 0;

            if (param_count_call != 2 || result_count != 1) {
              return -1;
            }
            if (result_type != ER_WASM_VALTYPE_I64) {
              return -1;
            }
            if (stack_size < 2) {
              return -1;
            }
            if (module->host.relay_recv == 0) {
              return -1;
            }
            capacity = stack[--stack_size];
            ptr = stack[--stack_size];
            if (ptr < 0 || capacity < 0 ||
                (UINT64)capacity > (UINT64)ER_WASM_U32_MASK) {
              return -1;
            }
            if (er_wasm_memory_window_range(module, (UINT64)ptr, (UINT32)capacity,
                                            module->linear_memory.relay_inbox_base,
                                            module->linear_memory.relay_inbox_len,
                                            &bytes) != 0) {
              return -1;
            }

            value = module->host.relay_recv(bytes, (UINT32)capacity);
            if (stack_size >= ER_WASM_STACK_MAX) {
              return -1;
            }
            stack[stack_size++] = value;
          } else if (import_kind == ER_IMPORT_KIND_MEMORY_REGION_BASE ||
                     import_kind == ER_IMPORT_KIND_MEMORY_REGION_LEN) {
            INT64 region_id = 0;
            UINT32 region_base = 0u;
            UINT32 region_len = 0u;

            if (param_count_call != 1 || result_count != 1) {
              return -1;
            }
            if (result_type != ER_WASM_VALTYPE_I64) {
              return -1;
            }
            if (stack_size < 1) {
              return -1;
            }
            region_id = stack[--stack_size];
            if (region_id < 0 || (UINT64)region_id > (UINT64)ER_WASM_U32_MASK) {
              return -1;
            }
            if (er_wasm_linear_memory_public_region(&module->linear_memory, (UINT32)region_id,
                                                    &region_base, &region_len) != 0) {
              return -1;
            }
            if (stack_size >= ER_WASM_STACK_MAX) {
              return -1;
            }
            if (import_kind == ER_IMPORT_KIND_MEMORY_REGION_BASE) {
              stack[stack_size++] = (INT64)(UINT64)region_base;
            } else {
              stack[stack_size++] = (INT64)(UINT64)region_len;
            }
          } else if (import_kind == ER_IMPORT_KIND_UI_EMIT) {
            INT64 value = 0;
            INT64 ptr = 0;
            INT64 len = 0;
            UINT8* bytes = 0;
            er_ui_scene_stats_t stats;

            if (param_count_call != 2 || result_count != 1) {
              return -1;
            }
            if (result_type != ER_WASM_VALTYPE_I64) {
              return -1;
            }
            if (stack_size < 2) {
              return -1;
            }
            if (module->host.ui_emit == 0 || module->host.ui_presentation == 0) {
              return -1;
            }
            len = stack[--stack_size];
            ptr = stack[--stack_size];
            if (ptr < 0 || len < 0 || (UINT64)len > (UINT64)ER_WASM_U32_MASK) {
              return -1;
            }
            if (er_wasm_memory_window_range(module, (UINT64)ptr, (UINT32)len,
                                            module->linear_memory.relay_outbox_base,
                                            module->linear_memory.relay_outbox_len,
                                            &bytes) != 0) {
              return -1;
            }
            if (er_wasm_ui_command_stats(bytes, (UINT32)len, &stats) != 0 ||
                er_app_ui_scene_fits_presentation(stats,
                                                  module->host.ui_presentation) == 0u) {
              return -1;
            }

            value = module->host.ui_emit((const UINT8*)bytes, (UINT32)len, &stats);
            if (stack_size >= ER_WASM_STACK_MAX) {
              return -1;
            }
            stack[stack_size++] = value;
          } else {
            return -1;
          }
        }
      } else if (op == ER_WASM_OP_BLOCK) {
        UINT8 block_type = 0;
        if (er_reader_read_u8(&code, &block_type) != 0) {
          return -1;
        }
        UINT32 start_pc = code.ofs;
        if (er_scan_matching_end(code.data, code.size, code.ofs, &matching_end, &matching_else) != 0) {
          return -1;
        }
        (void)block_type;
        if (control_depth >= ER_WASM_MAX_CONTROL_DEPTH) {
          return -1;
        }
        control[control_depth].kind = ER_CONTROL_KIND_BLOCK;
        control[control_depth].start_pc = start_pc;
        control[control_depth].end_pc = matching_end;
        control[control_depth].stack_depth = stack_size;
        ++control_depth;
      } else if (op == ER_WASM_OP_LOOP) {
        UINT8 loop_type = 0;
        if (er_reader_read_u8(&code, &loop_type) != 0) {
          return -1;
        }
        UINT32 start_pc = code.ofs;
        if (er_scan_matching_end(code.data, code.size, code.ofs, &matching_end, &matching_else) != 0) {
          return -1;
        }
        (void)loop_type;
        if (control_depth >= ER_WASM_MAX_CONTROL_DEPTH) {
          return -1;
        }
        control[control_depth].kind = ER_CONTROL_KIND_LOOP;
        control[control_depth].start_pc = start_pc;
        control[control_depth].end_pc = matching_end;
        control[control_depth].stack_depth = stack_size;
        ++control_depth;
      } else if (op == ER_WASM_OP_IF) {
        UINT8 if_type = 0;
        if (er_reader_read_u8(&code, &if_type) != 0) {
          return -1;
        }
        if (control_depth >= ER_WASM_MAX_CONTROL_DEPTH) {
          return -1;
        }
        if (er_scan_matching_end(code.data, code.size, code.ofs, &matching_end, &matching_else) != 0) {
          return -1;
        }
        if (stack_size == 0) {
          return -1;
        }
        i32value = (UINT32)stack[--stack_size];
        if (i32value == 0) {
          if (matching_else != 0) {
            code.ofs = matching_else;
            control[control_depth].kind = ER_CONTROL_KIND_IF;
            control[control_depth].start_pc = code.ofs;
            control[control_depth].end_pc = matching_end;
            control[control_depth].stack_depth = stack_size;
            ++control_depth;
          } else {
            code.ofs = matching_end;
          }
        } else {
          control[control_depth].kind = ER_CONTROL_KIND_IF;
          control[control_depth].start_pc = code.ofs;
          control[control_depth].end_pc = matching_end;
          control[control_depth].stack_depth = stack_size;
          ++control_depth;
          (void)if_type;
          (void)matching_else;
        }
      } else if (op == ER_WASM_OP_ELSE) {
        if (control_depth == 0 || control[control_depth - 1].kind != ER_CONTROL_KIND_IF) {
          return -1;
        }
        code.ofs = control[control_depth - 1].end_pc;
      } else if (op == ER_WASM_OP_BR_IF) {
        if (er_reader_read_u32_leb(&code, &target) != 0) {
          return -1;
        }
        if (stack_size == 0) {
          return -1;
        }
        if (stack[--stack_size] == 0) {
          continue;
        }
        if (target >= control_depth) {
          return -1;
        }
        {
          ErControlFrame* frame = &control[control_depth - 1 - target];
          stack_size = frame->stack_depth;
          if (frame->kind == ER_CONTROL_KIND_LOOP) {
            control_depth = control_depth - target;
            code.ofs = frame->start_pc;
          } else {
            control_depth = control_depth - target - 1;
            code.ofs = frame->end_pc;
          }
        }
      } else if (op == ER_WASM_OP_BR) {
        if (er_reader_read_u32_leb(&code, &target) != 0) {
          return -1;
        }
        if (target >= control_depth) {
          return -1;
        }
        {
          ErControlFrame* frame = &control[control_depth - 1 - target];
          stack_size = frame->stack_depth;
          if (frame->kind == ER_CONTROL_KIND_LOOP) {
            control_depth = control_depth - target;
            code.ofs = frame->start_pc;
          } else {
            control_depth = control_depth - target - 1;
            code.ofs = frame->end_pc;
          }
        }
      } else if (op == ER_WASM_OP_END) {
        if (control_depth == 0) {
          if (stack_size == 0) {
            *result = 0;
            return 0;
          }
          *result = stack[stack_size - 1];
          return 0;
        }
        --control_depth;
      } else if (op == ER_WASM_OP_DROP) {
        if (stack_size == 0) {
          return -1;
        }
        --stack_size;
      } else {
        return -1;
      }
    }
  }

  return -1;
}
