#include "wasm_compile.h"

/*
 * Purpose:
 *   Reject WAT modules that do not match an admitted EdgeRun app contract.
 * Intention:
 *   Keep compiler output aligned with the metal runtime admission boundary.
 */

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
  if (result_count != ERWC_HOSTCALL_NO_RESULTS && type->result_type != result_type) {
    return -1;
  }
  return 0;
}

static int erwc_contract_import_signature(const ErWcModule* module,
                                          ErWcImportKind import_kind,
                                          uint32_t type_index) {
  uint32_t param_count = ERWC_HOSTCALL_NO_PARAMS;
  uint8_t result_count = ERWC_HOSTCALL_NO_RESULTS;

  switch (import_kind) {
    case ERWC_IMPORT_LOG_U64:
    case ERWC_IMPORT_LOG_HEX:
      param_count = ERWC_HOSTCALL_UNARY_PARAMS;
      result_count = ERWC_HOSTCALL_NO_RESULTS;
      break;
    case ERWC_IMPORT_PCI_READ32:
      param_count = ERWC_PCI_READ32_PARAM_COUNT;
      result_count = ERWC_HOSTCALL_I64_RESULTS;
      break;
    case ERWC_IMPORT_PCI_WRITE32:
      param_count = ERWC_PCI_WRITE32_PARAM_COUNT;
      result_count = ERWC_HOSTCALL_NO_RESULTS;
      break;
    case ERWC_IMPORT_MMIO_MAP:
    case ERWC_IMPORT_MMIO_READ32:
    case ERWC_IMPORT_BUS_EXEC:
    case ERWC_IMPORT_RELAY_SEND:
    case ERWC_IMPORT_RELAY_RECV:
    case ERWC_IMPORT_UI_EMIT:
      param_count = ERWC_HOSTCALL_BINARY_PARAMS;
      result_count = ERWC_HOSTCALL_I64_RESULTS;
      break;
    case ERWC_IMPORT_MEMORY_REGION_BASE:
    case ERWC_IMPORT_MEMORY_REGION_LEN:
      param_count = ERWC_HOSTCALL_UNARY_PARAMS;
      result_count = ERWC_HOSTCALL_I64_RESULTS;
      break;
    default:
      return -1;
  }

  if (erwc_contract_type_has_i64_params(module, type_index, param_count) != 0 ||
      erwc_contract_type_result(module, type_index, result_count, ERWC_VALTYPE_I64) != 0) {
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
                                            ERWC_HOSTCALL_NO_PARAMS) != 0 ||
          erwc_contract_type_result(module, func->type_index,
                                    ERWC_HOSTCALL_I64_RESULTS,
                                    ERWC_VALTYPE_I64) != 0) {
        return -1;
      }
    }
  }
  return main_count == ERWC_CONTRACT_REQUIRED_IMPORT_COUNT ? 0 : -1;
}

static ErWcContract erwc_contract_infer(const ErWcModule* module) {
  uint32_t ui_emit_count = 0u;
  uint32_t bus_exec_count = 0u;

  for (uint32_t i = 0u; i < module->import_count; ++i) {
    switch (module->imports[i].import_kind) {
      case ERWC_IMPORT_UI_EMIT:
        ++ui_emit_count;
        break;
      case ERWC_IMPORT_BUS_EXEC:
        ++bus_exec_count;
        break;
      default:
        break;
    }
  }
  if (ui_emit_count == ERWC_CONTRACT_REQUIRED_IMPORT_COUNT && bus_exec_count == 0u) {
    return ERWC_CONTRACT_UI_APP;
  }
  if (bus_exec_count == ERWC_CONTRACT_REQUIRED_IMPORT_COUNT && ui_emit_count == 0u) {
    return ERWC_CONTRACT_BUS_DRIVER;
  }
  return ERWC_CONTRACT_NONE;
}

static uint8_t erwc_contract_import_allowed(ErWcContract contract,
                                            ErWcImportKind import_kind) {
  switch (contract) {
    case ERWC_CONTRACT_UI_APP:
      switch (import_kind) {
        case ERWC_IMPORT_MEMORY_REGION_BASE:
        case ERWC_IMPORT_MEMORY_REGION_LEN:
        case ERWC_IMPORT_UI_EMIT:
          return 1u;
        default:
          return 0u;
      }
    case ERWC_CONTRACT_BUS_DRIVER:
      switch (import_kind) {
        case ERWC_IMPORT_BUS_EXEC:
          return 1u;
        default:
          return 0u;
      }
    default:
      return 0u;
  }
}

int erwc_validate_contract(const ErWcModule* module) {
  ErWcContract contract;

  if (module == NULL ||
      module->memory_pages != ERWC_CONTRACT_REQUIRED_MEMORY_PAGES ||
      erwc_contract_main_valid(module) != 0) {
    return -1;
  }

  contract = erwc_contract_infer(module);
  if (contract == ERWC_CONTRACT_NONE) {
    return -1;
  }

  for (uint32_t i = 0u; i < module->import_count; ++i) {
    const ErWcImport* import = &module->imports[i];
    if (import->import_kind == ERWC_IMPORT_NONE ||
        erwc_contract_import_allowed(contract, import->import_kind) == 0u ||
        erwc_contract_import_signature(module, import->import_kind,
                                       import->type_index) != 0) {
      return -1;
    }
  }
  return 0;
}
