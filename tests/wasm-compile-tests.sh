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

cat > "${TMP_DIR}/ui-min.c" <<'CAPP'
extern i64 ui_emit(i64, i64) __import("edgerun.ui", "emit");
memory(1);
export i64 main(void) { return 7; }
CAPP

cat > "${TMP_DIR}/ui-emit-call.c" <<'CAPP'
extern i64 ui_emit(i64, i64) __import("edgerun.ui", "emit");
memory(1);
export i64 main(void) { return ui_emit(0, 0); }
CAPP

cat > "${TMP_DIR}/ui-local-return.c" <<'CAPP'
extern i64 ui_emit(i64, i64) __import("edgerun.ui", "emit");
memory(1);
export i64 main(void) {
  i64 value = 7;
  return value;
}
CAPP

cat > "${TMP_DIR}/ui-local-call.c" <<'CAPP'
extern i64 ui_emit(i64, i64) __import("edgerun.ui", "emit");
memory(1);
export i64 main(void) {
  i64 ptr = 1024;
  i64 len = 172;
  return ui_emit(ptr, len);
}
CAPP

cat > "${TMP_DIR}/ui-region-base-call.c" <<'CAPP'
extern i64 ui_emit(i64, i64) __import("edgerun.ui", "emit");
extern i64 region_base(i64) __import("edgerun.memory", "region_base");
memory(1);
export i64 main(void) { return region_base(0); }
CAPP

cat > "${TMP_DIR}/ui-region-len-call.c" <<'CAPP'
extern i64 ui_emit(i64, i64) __import("edgerun.ui", "emit");
extern i64 region_len(i64) __import("edgerun.memory", "region_len");
memory(1);
export i64 main(void) { return region_len(0); }
CAPP

cat > "${TMP_DIR}/bus-exec-call.c" <<'CAPP'
extern i64 bus_exec(i64, i64) __import("edgerun.bus", "exec");
memory(1);
export i64 main(void) { return bus_exec(0, 0); }
CAPP

compile_twice \
  "${TMP_DIR}/ui-min.c" \
  "${TMP_DIR}/ui-c-a.wasm" \
  "${TMP_DIR}/ui-c-b.wasm"
compile_twice \
  "${TMP_DIR}/ui-emit-call.c" \
  "${TMP_DIR}/ui-emit-call-a.wasm" \
  "${TMP_DIR}/ui-emit-call-b.wasm"
compile_twice \
  "${TMP_DIR}/ui-local-return.c" \
  "${TMP_DIR}/ui-local-return-a.wasm" \
  "${TMP_DIR}/ui-local-return-b.wasm"
compile_twice \
  "${TMP_DIR}/ui-local-call.c" \
  "${TMP_DIR}/ui-local-call-a.wasm" \
  "${TMP_DIR}/ui-local-call-b.wasm"
compile_twice \
  "${TMP_DIR}/ui-region-base-call.c" \
  "${TMP_DIR}/ui-region-base-call-a.wasm" \
  "${TMP_DIR}/ui-region-base-call-b.wasm"
compile_twice \
  "${TMP_DIR}/ui-region-len-call.c" \
  "${TMP_DIR}/ui-region-len-call-a.wasm" \
  "${TMP_DIR}/ui-region-len-call-b.wasm"
compile_twice \
  "${TMP_DIR}/bus-exec-call.c" \
  "${TMP_DIR}/bus-exec-call-a.wasm" \
  "${TMP_DIR}/bus-exec-call-b.wasm"

check_magic "${TMP_DIR}/driver-a.wasm"
check_magic "${TMP_DIR}/ui-a.wasm"
check_magic "${TMP_DIR}/ui-c-a.wasm"
check_magic "${TMP_DIR}/ui-emit-call-a.wasm"
check_magic "${TMP_DIR}/ui-local-return-a.wasm"
check_magic "${TMP_DIR}/ui-local-call-a.wasm"
check_magic "${TMP_DIR}/ui-region-base-call-a.wasm"
check_magic "${TMP_DIR}/ui-region-len-call-a.wasm"
check_magic "${TMP_DIR}/bus-exec-call-a.wasm"

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

cat > "${TMP_DIR}/bad-c-subset.c" <<'CAPP'
extern i64 ui_emit(i64, i64) __import("edgerun.ui", "emit");
memory(1);
export i64 main(void) { return ui_emit(0); }
CAPP

expect_reject "unsupported c expression" \
  "${TMP_DIR}/bad-c-subset.c" \
  "${TMP_DIR}/bad-c-subset.wasm"

cat > "${TMP_DIR}/bad-c-unknown-local.c" <<'CAPP'
extern i64 ui_emit(i64, i64) __import("edgerun.ui", "emit");
memory(1);
export i64 main(void) { return missing; }
CAPP

expect_reject "unknown c local" \
  "${TMP_DIR}/bad-c-unknown-local.c" \
  "${TMP_DIR}/bad-c-unknown-local.wasm"

cat > "${TMP_DIR}/bad-c-duplicate-local.c" <<'CAPP'
extern i64 ui_emit(i64, i64) __import("edgerun.ui", "emit");
memory(1);
export i64 main(void) {
  i64 value = 1;
  i64 value = 2;
  return value;
}
CAPP

expect_reject "duplicate c local" \
  "${TMP_DIR}/bad-c-duplicate-local.c" \
  "${TMP_DIR}/bad-c-duplicate-local.wasm"

printf 'wasm-compile tests passed\n'
