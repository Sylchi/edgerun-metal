#!/usr/bin/env bash
set -euo pipefail

# Purpose:
#   Smoke-test the repository-owned WAT subset compiler.
# Intention:
#   Keep metal Wasm module generation deterministic and repository-owned.

readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
readonly WASM_COMPILE="${ROOT_DIR}/.build/wasm-compile"
readonly TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

compile_twice() {
  local source="$1"
  local first="$2"
  local second="$3"

  "${WASM_COMPILE}" "${source}" "${first}"
  "${WASM_COMPILE}" "${source}" "${second}"
  cmp "${first}" "${second}"
}

check_magic() {
  local path="$1"

  case "$(od -An -tx1 -N8 "${path}")" in
    *"00 61 73 6d 01 00 00 00"* ) ;;
    * ) printf 'bad wasm header: %s\n' "${path}" >&2; exit 1 ;;
  esac
}

compile_twice \
  "${ROOT_DIR}/edgerun-metal/modules/driver_bus_probe/driver_bus_probe.wat" \
  "${TMP_DIR}/driver-a.wasm" \
  "${TMP_DIR}/driver-b.wasm"
compile_twice \
  "${ROOT_DIR}/edgerun-metal/modules/ui_counter/ui_counter.wat" \
  "${TMP_DIR}/ui-a.wasm" \
  "${TMP_DIR}/ui-b.wasm"

check_magic "${TMP_DIR}/driver-a.wasm"
check_magic "${TMP_DIR}/ui-a.wasm"

expect_reject() {
  local label="$1"
  local source="$2"
  local output="$3"

  if "${WASM_COMPILE}" "${source}" "${output}" >/dev/null 2>&1; then
    printf '%s accepted\n' "${label}" >&2
    exit 1
  fi
}

cat > "${TMP_DIR}/invalid.wat" <<'WAT'
(module
  (type $main_t (func (result i64)))
  (memory 1)
  (func (export "main") (type $main_t) (result i64)
    (i32.add))
)
WAT

expect_reject "unsupported instruction" "${TMP_DIR}/invalid.wat" "${TMP_DIR}/invalid.wasm"

cat > "${TMP_DIR}/bad-contract-none.wat" <<'WAT'
(module
  (type $main_t (func (result i64)))
  (memory 1)
  (func (export "main") (type $main_t) (result i64)
    (i64.const 1))
)
WAT

expect_reject "missing contract import" \
  "${TMP_DIR}/bad-contract-none.wat" \
  "${TMP_DIR}/bad-contract-none.wasm"

cat > "${TMP_DIR}/bad-contract-mixed.wat" <<'WAT'
(module
  (type $ui_emit_t (func (param i64 i64) (result i64)))
  (type $bus_exec_t (func (param i64 i64) (result i64)))
  (type $main_t (func (result i64)))
  (import "edgerun.ui" "emit" (func $ui_emit (type $ui_emit_t)))
  (import "edgerun.bus" "exec" (func $bus_exec (type $bus_exec_t)))
  (memory 1)
  (func (export "main") (type $main_t) (result i64)
    (i64.const 1))
)
WAT

expect_reject "mixed contracts" \
  "${TMP_DIR}/bad-contract-mixed.wat" \
  "${TMP_DIR}/bad-contract-mixed.wasm"

cat > "${TMP_DIR}/bad-contract-signature.wat" <<'WAT'
(module
  (type $ui_emit_t (func (param i32 i64) (result i64)))
  (type $main_t (func (result i64)))
  (import "edgerun.ui" "emit" (func $ui_emit (type $ui_emit_t)))
  (memory 1)
  (func (export "main") (type $main_t) (result i64)
    (i64.const 1))
)
WAT

expect_reject "bad hostcall signature" \
  "${TMP_DIR}/bad-contract-signature.wat" \
  "${TMP_DIR}/bad-contract-signature.wasm"

printf 'wasm-compile tests passed\n'
