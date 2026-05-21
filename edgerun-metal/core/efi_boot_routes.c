#include "internal/efi_boot_internal.h"

/*
 * Purpose: prepare deterministic boot-time admitted routes shared by runtime adapters.
 * Intention: keep route fixtures independent from Wasm package loading and firmware globals.
 */

static UINT8 er_ui_boot_route_app_seed(UINT8 seed, UINT32 app_index) {
  return (UINT8)(seed + (UINT8)(app_index * ER_UI_WASM_APP_SEED_STRIDE));
}

static void er_ui_boot_route_fill_nonzero_bytes(UINT8* bytes, UINTN len, UINT8 seed) {
  UINTN i;

  if (bytes == 0) {
    return;
  }
  for (i = 0u; i < len; ++i) {
    bytes[i] = (UINT8)(seed + (UINT8)i);
  }
}

UINT8 er_ui_boot_prepare_storage_retrieve_route(UINT8 route_seed,
                                                UINT32 app_index,
                                                ErAdmittedRoute* out_route) {
  UINT8 base_seed;

  if (out_route == 0) {
    return 0u;
  }
  base_seed = er_ui_boot_route_app_seed(route_seed, app_index);
  er_mem_zero((UINT8*)out_route, (UINTN)sizeof(*out_route));
  out_route->abi_version = ER_WORK_ABI_VERSION;
  out_route->role = ER_NODE_ROLE_STORAGE;
  out_route->department = ER_DEPARTMENT_STORAGE;
  out_route->work_type = ER_WORK_TYPE_OBJECT_RETRIEVE;
  out_route->admitted_budget = ER_UI_WASM_STORAGE_ROUTE_BUDGET;
  er_ui_boot_route_fill_nonzero_bytes(out_route->route_id.bytes, ER_HASH_LEN, base_seed);
  er_ui_boot_route_fill_nonzero_bytes(out_route->request_hash.bytes, ER_HASH_LEN,
                                      (UINT8)(base_seed + ER_UI_WASM_STORAGE_REQUEST_HASH_OFFSET));
  er_ui_boot_route_fill_nonzero_bytes(out_route->admission_hash.bytes, ER_HASH_LEN,
                                      (UINT8)(base_seed + ER_UI_WASM_STORAGE_ADMISSION_HASH_OFFSET));
  er_ui_boot_route_fill_nonzero_bytes(out_route->source_node_id.bytes, ER_NODE_ID_LEN,
                                      (UINT8)(base_seed + ER_UI_WASM_STORAGE_SOURCE_NODE_OFFSET));
  er_ui_boot_route_fill_nonzero_bytes(out_route->target_node_id.bytes, ER_NODE_ID_LEN,
                                      (UINT8)(base_seed + ER_UI_WASM_STORAGE_TARGET_NODE_OFFSET));
  er_ui_boot_route_fill_nonzero_bytes(out_route->relay_node_id.bytes, ER_NODE_ID_LEN,
                                      (UINT8)(base_seed + ER_UI_WASM_STORAGE_RELAY_NODE_OFFSET));
  er_ui_boot_route_fill_nonzero_bytes(out_route->channel_id.bytes, ER_HASH_LEN,
                                      (UINT8)(base_seed + ER_UI_WASM_STORAGE_CHANNEL_ID_OFFSET));
  er_ui_boot_route_fill_nonzero_bytes(out_route->target_route_commitment.bytes, ER_HASH_LEN,
                                      (UINT8)(base_seed + ER_UI_WASM_STORAGE_ROUTE_COMMITMENT_OFFSET));
  return 1u;
}
