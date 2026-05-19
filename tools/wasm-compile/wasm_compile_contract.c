#include "wasm_compile.h"

/*
 * Purpose:
 *   Reject WAT modules that do not match an admitted EdgeRun app contract.
 * Intention:
 *   Keep compiler output aligned with the metal runtime admission boundary.
 */

typedef struct {
  ErWasmImportKind kind;
  uint32_t param_count;
  uint8_t result_count;
  uint8_t contract_mask;
} ErWcContractImport;

static const ErWcContractImport ERWC_CONTRACT_IMPORTS[] = {
#define ERWC_CONTRACT_IMPORT_ROW(kind, module, field, params, results, contracts) \
  {kind, params, results, contracts},
  ER_WASM_CONTRACT_IMPORTS(ERWC_CONTRACT_IMPORT_ROW)
#undef ERWC_CONTRACT_IMPORT_ROW
};
static const uint32_t ERWC_CONTRACT_IMPORT_COUNT =
  (uint32_t)(sizeof(ERWC_CONTRACT_IMPORTS) / sizeof(ERWC_CONTRACT_IMPORTS[0]));

static uint8_t erwc_contract_mask(ErWasmModuleContract contract) {
  switch (contract) {
    case ER_WASM_MODULE_CONTRACT_UI_APP:
      return ER_WASM_CONTRACT_MASK_UI_APP;
    case ER_WASM_MODULE_CONTRACT_BUS_DRIVER:
      return ER_WASM_CONTRACT_MASK_BUS_DRIVER;
    default:
      return ER_WASM_CONTRACT_MASK_NONE;
  }
}

static const ErWcContractImport* erwc_contract_import(ErWasmImportKind import_kind) {
  for (uint32_t i = 0u; i < ERWC_CONTRACT_IMPORT_COUNT; ++i) {
    //@optimizer-ignore shared Wasm contract ABI table requires indexed row lookup by import kind
    if (ERWC_CONTRACT_IMPORTS[i].kind == import_kind) {
      return &ERWC_CONTRACT_IMPORTS[i];
    }
  }
  return NULL;
}

static int erwc_contract_type_has_i64_params(const ErWcModule* module,
                                             uint32_t type_index,
                                             uint32_t param_count) {
  const ErWcType* type;

  if (module == NULL || type_index >= module->type_count) {
    return -1;
  }
  type = &module->types[type_index];
  if (type->param_count != param_count) {
    return -1;
  }
  for (uint32_t i = 0u; i < param_count; ++i) {
    if (type->params[i] != ERWC_VALTYPE_I64) {
      return -1;
    }
  }
  return 0;
}

static int erwc_contract_type_result(const ErWcModule* module,
                                     uint32_t type_index,
                                     uint8_t result_count,
                                     uint8_t result_type) {
  const ErWcType* type;

  if (module == NULL || type_index >= module->type_count) {
    return -1;
  }
  type = &module->types[type_index];
  if (type->result_count != result_count) {
    return -1;
  }
  if (result_count != ER_WASM_HOSTCALL_NO_RESULTS && type->result_type != result_type) {
    return -1;
  }
  return 0;
}

static int erwc_contract_import_signature(const ErWcModule* module,
                                          ErWasmImportKind import_kind,
                                          uint32_t type_index) {
  const ErWcContractImport* import = erwc_contract_import(import_kind);

  if (import == NULL ||
      erwc_contract_type_has_i64_params(module, type_index, import->param_count) != 0 ||
      erwc_contract_type_result(module, type_index, import->result_count,
                                ERWC_VALTYPE_I64) != 0) {
    return -1;
  }
  return 0;
}

static int erwc_contract_main_valid(const ErWcModule* module) {
  uint32_t main_count = 0u;

  if (module == NULL) {
    return -1;
  }
  for (uint32_t i = 0u; i < module->func_count; ++i) {
    const ErWcFunc* func = &module->funcs[i];
    if (func->exported_main != 0u) {
      ++main_count;
      if (erwc_contract_type_has_i64_params(module, func->type_index,
                                            ER_WASM_HOSTCALL_NO_PARAMS) != 0 ||
          erwc_contract_type_result(module, func->type_index,
                                    ER_WASM_HOSTCALL_I64_RESULTS,
                                    ERWC_VALTYPE_I64) != 0) {
        return -1;
      }
    }
  }
  return main_count == ER_WASM_CONTRACT_REQUIRED_IMPORT_COUNT ? 0 : -1;
}

static ErWasmModuleContract erwc_contract_infer(const ErWcModule* module) {
  uint32_t ui_emit_count = 0u;
  uint32_t bus_exec_count = 0u;

  for (uint32_t i = 0u; i < module->import_count; ++i) {
    switch (module->imports[i].import_kind) {
      case ER_WASM_IMPORT_KIND_UI_EMIT:
        ++ui_emit_count;
        break;
      case ER_WASM_IMPORT_KIND_BUS_EXEC:
        ++bus_exec_count;
        break;
      default:
        break;
    }
  }
  if (ui_emit_count == ER_WASM_CONTRACT_REQUIRED_IMPORT_COUNT && bus_exec_count == 0u) {
    return ER_WASM_MODULE_CONTRACT_UI_APP;
  }
  if (bus_exec_count == ER_WASM_CONTRACT_REQUIRED_IMPORT_COUNT && ui_emit_count == 0u) {
    return ER_WASM_MODULE_CONTRACT_BUS_DRIVER;
  }
  return ER_WASM_MODULE_CONTRACT_NONE;
}

static uint8_t erwc_contract_import_allowed(ErWasmModuleContract contract,
                                            ErWasmImportKind import_kind) {
  const ErWcContractImport* import = erwc_contract_import(import_kind);
  uint8_t contract_mask = erwc_contract_mask(contract);

  return (uint8_t)(import != NULL &&
                   contract_mask != ER_WASM_CONTRACT_MASK_NONE &&
                   (import->contract_mask & contract_mask) != 0u);
}

int erwc_validate_contract(const ErWcModule* module) {
  ErWasmModuleContract contract;

  if (module == NULL ||
      module->memory_pages != ER_WASM_CONTRACT_REQUIRED_MEMORY_PAGES ||
      erwc_contract_main_valid(module) != 0) {
    return -1;
  }

  contract = erwc_contract_infer(module);
  if (contract == ER_WASM_MODULE_CONTRACT_NONE) {
    return -1;
  }

  for (uint32_t i = 0u; i < module->import_count; ++i) {
    const ErWcImport* import = &module->imports[i];
    if (import->import_kind == ER_WASM_IMPORT_KIND_NONE ||
        erwc_contract_import_allowed(contract, import->import_kind) == 0u ||
        erwc_contract_import_signature(module, import->import_kind,
                                       import->type_index) != 0) {
      return -1;
    }
  }
  return 0;
}
