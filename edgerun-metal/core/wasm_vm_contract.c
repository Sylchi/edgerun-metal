#include "wasm_vm_internal.h"

typedef struct {
  UINT8 kind;
  UINT8 param_count;
  UINT8 result_count;
  UINT8 contract_mask;
} ErWasmContractImport;

static const ErWasmContractImport ER_WASM_CONTRACT_IMPORTS[] = {
#define ER_WASM_CONTRACT_IMPORT_ROW(kind, module, field, params, results, contracts) \
  {kind, params, results, contracts},
  ER_WASM_CONTRACT_IMPORTS(ER_WASM_CONTRACT_IMPORT_ROW)
#undef ER_WASM_CONTRACT_IMPORT_ROW
};
static const UINT32 ER_WASM_CONTRACT_IMPORT_COUNT =
  (UINT32)(sizeof(ER_WASM_CONTRACT_IMPORTS) / sizeof(ER_WASM_CONTRACT_IMPORTS[0]));

static UINT8 er_wasm_contract_mask(ErWasmModuleContract contract) {
  switch (contract) {
    case ER_WASM_MODULE_CONTRACT_UI_APP:
      return ER_WASM_CONTRACT_MASK_UI_APP;
    case ER_WASM_MODULE_CONTRACT_BUS_DRIVER:
      return ER_WASM_CONTRACT_MASK_BUS_DRIVER;
    default:
      return ER_WASM_CONTRACT_MASK_NONE;
  }
}

static const ErWasmContractImport* er_wasm_contract_import(UINT8 import_kind) {
  for (UINT32 i = 0u; i < ER_WASM_CONTRACT_IMPORT_COUNT; ++i) {
    if (ER_WASM_CONTRACT_IMPORTS[i].kind == import_kind) {
      return &ER_WASM_CONTRACT_IMPORTS[i];
    }
  }
  return 0;
}

static int er_wasm_contract_type_has_i64_params(const ErWasmModule* module,
                                                UINT32 type_index,
                                                UINT8 param_count) {
  if (type_index >= module->num_types ||
      module->type_params_0[type_index] != param_count) {
    return -1;
  }
  for (UINT32 i = 0u; i < param_count; ++i) {
    if (module->type_param_types[type_index][i] != ER_WASM_VALTYPE_I64) {
      return -1;
    }
  }
  return 0;
}

static int er_wasm_contract_type_result(const ErWasmModule* module,
                                        UINT32 type_index,
                                        UINT8 result_count,
                                        UINT8 result_type) {
  if (type_index >= module->num_types ||
      module->type_result_count[type_index] != result_count) {
    return -1;
  }
  if (result_count != ER_WASM_HOSTCALL_NO_RESULTS &&
      module->type_result_type[type_index] != result_type) {
    return -1;
  }
  return 0;
}

static int er_wasm_contract_import_signature(const ErWasmModule* module,
                                             UINT8 import_kind,
                                             UINT32 type_index) {
  const ErWasmContractImport* import = er_wasm_contract_import(import_kind);

  if (import == 0 ||
      er_wasm_contract_type_has_i64_params(module, type_index, import->param_count) != 0 ||
      er_wasm_contract_type_result(module, type_index, import->result_count,
                                   ER_WASM_VALTYPE_I64) != 0) {
    return -1;
  }
  return 0;
}

static int er_wasm_contract_main_valid(const ErWasmModule* module) {
  UINT32 type_index = 0u;

  if (module->function_has_main == 0u ||
      module->main_index >= module->num_funcs ||
      module->function_is_import[module->main_index] != 0u) {
    return -1;
  }
  type_index = module->function_type_indices[module->main_index];
  if (er_wasm_contract_type_has_i64_params(module, type_index,
                                           ER_WASM_HOSTCALL_NO_PARAMS) != 0 ||
      er_wasm_contract_type_result(module, type_index,
                                   ER_WASM_HOSTCALL_I64_RESULTS,
                                   ER_WASM_VALTYPE_I64) != 0) {
    return -1;
  }
  return 0;
}

static UINT8 er_wasm_contract_import_allowed(ErWasmModuleContract contract,
                                             UINT8 import_kind) {
  const ErWasmContractImport* import = er_wasm_contract_import(import_kind);
  UINT8 contract_mask = er_wasm_contract_mask(contract);

  return (UINT8)(import != 0 &&
                 contract_mask != ER_WASM_CONTRACT_MASK_NONE &&
                 (import->contract_mask & contract_mask) != 0u);
}

static int er_wasm_contract_required_imports(const ErWasmModule* module,
                                             ErWasmModuleContract contract) {
  UINT32 ui_emit_count = 0u;
  UINT32 bus_exec_count = 0u;

  for (UINT32 i = 0u; i < module->num_imports; ++i) {
    switch (module->function_import_kind[i]) {
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

  switch (contract) {
    case ER_WASM_MODULE_CONTRACT_UI_APP:
      return ui_emit_count == ER_WASM_CONTRACT_REQUIRED_IMPORT_COUNT ? 0 : -1;
    case ER_WASM_MODULE_CONTRACT_BUS_DRIVER:
      return bus_exec_count == ER_WASM_CONTRACT_REQUIRED_IMPORT_COUNT ? 0 : -1;
    default:
      return -1;
  }
}

int er_wasm_validate_contract(const ErWasmModule* module,
                              ErWasmModuleContract contract) {
  if (module == 0 ||
      module->memory_min_pages != ER_WASM_CONTRACT_REQUIRED_MEMORY_PAGES ||
      er_wasm_contract_main_valid(module) != 0) {
    return -1;
  }

  for (UINT32 i = 0u; i < module->num_imports; ++i) {
    UINT8 import_kind = module->function_import_kind[i];
    UINT32 type_index = module->function_type_indices[i];

    if (import_kind == ER_WASM_IMPORT_KIND_NONE ||
        er_wasm_contract_import_allowed(contract, import_kind) == 0u ||
        er_wasm_contract_import_signature(module, import_kind, type_index) != 0) {
      return -1;
    }
  }

  return er_wasm_contract_required_imports(module, contract);
}
