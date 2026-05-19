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

cat > "${TMP_DIR}/invalid.wat" <<'WAT'
(module
  (type $main_t (func (result i64)))
  (memory 1)
  (func (export "main") (type $main_t) (result i64)
    (i32.add))
)
WAT

if "${WASM_COMPILE}" "${TMP_DIR}/invalid.wat" "${TMP_DIR}/invalid.wasm" >/dev/null 2>&1; then
  printf 'unsupported instruction accepted\n' >&2
  exit 1
fi

printf 'wasm-compile tests passed\n'
