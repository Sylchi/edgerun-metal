#ifndef ERWC_WASM_COMPILE_H
#define ERWC_WASM_COMPILE_H

#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*
 * Purpose:
 *   Compile the admitted EdgeRun WAT subset into deterministic WebAssembly
 *   binary modules.
 * Intention:
 *   Remove the external WAT compiler dependency while keeping authored modules
 *   inside the exact runtime subset supported by edgerun-metal/core/wasm_vm*.
 */

enum {
  ERWC_MAX_TOKENS = 8192,
  ERWC_MAX_NODES = 4096,
  ERWC_MAX_TYPES = 32,
  ERWC_MAX_FUNCS = 32,
  ERWC_MAX_IMPORTS = 16,
  ERWC_MAX_LOCALS = 32,
  ERWC_MAX_INSTR = 4096,
  ERWC_MAX_BYTES = 65536,
  ERWC_MAX_STRING = 64,
  ERWC_ARGC = 3,
  ERWC_INPUT_ARG = 1,
  ERWC_OUTPUT_ARG = 2,
  ERWC_WASM_PAGE_BYTES = 65536,
  ERWC_CONTRACT_REQUIRED_MEMORY_PAGES = 1,
  ERWC_CONTRACT_REQUIRED_IMPORT_COUNT = 1,
  ERWC_HOSTCALL_NO_PARAMS = 0,
  ERWC_HOSTCALL_UNARY_PARAMS = 1,
  ERWC_HOSTCALL_BINARY_PARAMS = 2,
  ERWC_HOSTCALL_NO_RESULTS = 0,
  ERWC_HOSTCALL_I64_RESULTS = 1,
  ERWC_PCI_READ32_PARAM_COUNT = 4,
  ERWC_PCI_WRITE32_PARAM_COUNT = 5,
  ERWC_TYPE_FORM_FUNC = 0x60,
  ERWC_VALTYPE_I64 = 0x7e,
  ERWC_VALTYPE_I32 = 0x7f,
  ERWC_EXTERNAL_FUNC = 0x00,
  ERWC_SECTION_TYPE = 1,
  ERWC_SECTION_IMPORT = 2,
  ERWC_SECTION_FUNCTION = 3,
  ERWC_SECTION_MEMORY = 5,
  ERWC_SECTION_EXPORT = 7,
  ERWC_SECTION_CODE = 10,
  ERWC_OP_CALL = 0x10,
  ERWC_OP_DROP = 0x1a,
  ERWC_OP_LOCAL_GET = 0x20,
  ERWC_OP_LOCAL_SET = 0x21,
  ERWC_OP_LOCAL_TEE = 0x22,
  ERWC_OP_I32_LOAD = 0x28,
  ERWC_OP_I64_LOAD = 0x29,
  ERWC_OP_I32_STORE = 0x36,
  ERWC_OP_I64_STORE = 0x37,
  ERWC_OP_I32_STORE16 = 0x3b,
  ERWC_OP_I32_CONST = 0x41,
  ERWC_OP_I64_CONST = 0x42,
  ERWC_OP_I32_WRAP_I64 = 0xa7,
  ERWC_OP_END = 0x0b
};

typedef enum {
  ERWC_TOKEN_LPAREN,
  ERWC_TOKEN_RPAREN,
  ERWC_TOKEN_ATOM,
  ERWC_TOKEN_STRING
} ErWcTokenKind;

typedef enum {
  ERWC_CONTRACT_NONE,
  ERWC_CONTRACT_UI_APP,
  ERWC_CONTRACT_BUS_DRIVER
} ErWcContract;

typedef enum {
  ERWC_IMPORT_NONE = 0,
  ERWC_IMPORT_LOG_U64 = 1,
  ERWC_IMPORT_LOG_HEX = 2,
  ERWC_IMPORT_PCI_READ32 = 3,
  ERWC_IMPORT_PCI_WRITE32 = 4,
  ERWC_IMPORT_MMIO_MAP = 5,
  ERWC_IMPORT_MMIO_READ32 = 6,
  ERWC_IMPORT_BUS_EXEC = 7,
  ERWC_IMPORT_RELAY_SEND = 8,
  ERWC_IMPORT_RELAY_RECV = 9,
  ERWC_IMPORT_MEMORY_REGION_BASE = 10,
  ERWC_IMPORT_MEMORY_REGION_LEN = 11,
  ERWC_IMPORT_UI_EMIT = 12
} ErWcImportKind;

typedef struct {
  ErWcTokenKind kind;
  const char* start;
  size_t len;
  unsigned line;
} ErWcToken;

typedef struct {
  int is_list;
  int token;
  int first_child;
  int next_sibling;
} ErWcNode;

typedef struct {
  const char* path;
  uint8_t* bytes;
  size_t len;
} ErWcSource;

typedef struct {
  uint8_t bytes[ERWC_MAX_BYTES];
  size_t len;
} ErWcBuffer;

typedef struct {
  char name[ERWC_MAX_STRING];
  uint8_t params[8];
  uint32_t param_count;
  uint8_t result_type;
  uint8_t result_count;
} ErWcType;

typedef struct {
  char name[ERWC_MAX_STRING];
  uint8_t type;
} ErWcLocal;

typedef struct {
  char name[ERWC_MAX_STRING];
  char module[ERWC_MAX_STRING];
  char field[ERWC_MAX_STRING];
  char type_name[ERWC_MAX_STRING];
  uint32_t type_index;
  uint32_t function_index;
  ErWcImportKind import_kind;
} ErWcImport;

typedef struct {
  char name[ERWC_MAX_STRING];
  char type_name[ERWC_MAX_STRING];
  uint32_t type_index;
  uint32_t function_index;
  uint8_t exported_main;
  ErWcLocal locals[ERWC_MAX_LOCALS];
  uint32_t local_count;
  ErWcBuffer code;
} ErWcFunc;

typedef struct {
  ErWcType types[ERWC_MAX_TYPES];
  uint32_t type_count;
  ErWcImport imports[ERWC_MAX_IMPORTS];
  uint32_t import_count;
  ErWcFunc funcs[ERWC_MAX_FUNCS];
  uint32_t func_count;
  uint32_t memory_pages;
} ErWcModule;

typedef struct {
  ErWcToken tokens[ERWC_MAX_TOKENS];
  uint32_t token_count;
  ErWcNode nodes[ERWC_MAX_NODES];
  uint32_t node_count;
} ErWcParse;

int erwc_fail_path(const char* path, const char* message);
int erwc_usage(const char* program);
int erwc_token_text_equals(const ErWcParse* parse, int token_index, const char* text);
int erwc_node_atom_equals(const ErWcParse* parse, int node_index, const char* text);
int erwc_copy_token_text(const ErWcParse* parse, int node_index, char* dst, size_t dst_len);
int erwc_read_file(const char* path, ErWcSource* source);
int erwc_tokenize(const ErWcSource* source, ErWcParse* parse);
int erwc_parse_tree(ErWcParse* parse);
int erwc_parse_u32_text(const char* text, uint32_t* out_value);
int erwc_node_u32(const ErWcParse* parse, int node_index, uint32_t* out_value);
int erwc_node_i64(const ErWcParse* parse, int node_index, int64_t* out_value);
uint8_t erwc_valtype_from_name(const char* name);
int erwc_find_type(const ErWcModule* module, const char* name, uint32_t* out_index);
int erwc_find_function(const ErWcModule* module, const char* name, uint32_t* out_index);
int erwc_find_local(const ErWcFunc* func, const char* name, uint32_t* out_index);
int erwc_validate_contract(const ErWcModule* module);
int erwc_buffer_push(ErWcBuffer* buffer, uint8_t byte);
int erwc_buffer_append(ErWcBuffer* buffer, const uint8_t* bytes, size_t len);
int erwc_emit_u32_leb(ErWcBuffer* buffer, uint32_t value);
int erwc_emit_i64_leb(ErWcBuffer* buffer, int64_t value);
int erwc_emit_name(ErWcBuffer* buffer, const char* name);
int erwc_build_module(const ErWcParse* parse, int root, ErWcModule* module);
int erwc_emit_wasm(const ErWcModule* module, ErWcBuffer* out);
int erwc_write_file(const char* path, const ErWcBuffer* out);
int erwc_compile_path(const char* input_path, const char* output_path);

#endif
