#!/usr/bin/env sh
set -eu

# Purpose:
#   Verify canonical app packages build through the repository-owned wrapper.
# Intention:
#   Keep user-authored app builds explicit and generated Wasm under package .build/.

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ER_BUILD="${ROOT_DIR}/.build/er-build"
PACKAGE_DIR="${ROOT_DIR}/tests/fixtures/app-package/app"
DRIVER_PACKAGE_DIR="${ROOT_DIR}/edgerun-metal/modules/driver_bus_probe/app"
OUTPUT_WASM="${PACKAGE_DIR}/.build/app.wasm"
OUTPUT_IDENTITY="${PACKAGE_DIR}/.build/package.identity"
HASH_HEX_LEN=64
TMP_DIR=$(mktemp -d)

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

expect_hash_line() {
  key="$1"
  line=$(grep "^${key}=" "${OUTPUT_IDENTITY}")
  hash=${line#*=}
  if [ "${#hash}" -ne "${HASH_HEX_LEN}" ]; then
    printf 'bad hash length for %s\n' "${key}" >&2
    exit 1
  fi
  case "${hash}" in
    *[!0123456789abcdef]* )
      printf 'bad hash encoding for %s\n' "${key}" >&2
      exit 1
      ;;
  esac
}

rm -f "${OUTPUT_WASM}" "${OUTPUT_IDENTITY}"

"${ER_BUILD}" app-build "${PACKAGE_DIR}"
test -f "${OUTPUT_WASM}"
test -f "${OUTPUT_IDENTITY}"
"${ER_BUILD}" app-verify "${PACKAGE_DIR}"
run_output=$("${ER_BUILD}" app-run "${PACKAGE_DIR}")
case "${run_output}" in
  "app-run result=172 ui_emit_count=1 ui_emit_bytes=172 rects=1 hits=1 text=1" ) ;;
  * ) printf 'bad app-run output\n%s\n' "${run_output}" >&2; exit 1 ;;
esac
case "$(od -An -tx1 -N8 "${OUTPUT_WASM}")" in
  *"00 61 73 6d 01 00 00 00"* ) ;;
  * ) printf 'bad package wasm header\n' >&2; exit 1 ;;
esac
grep '^package_identity_v1$' "${OUTPUT_IDENTITY}" >/dev/null
grep '^source=app.c$' "${OUTPUT_IDENTITY}" >/dev/null
grep '^manifest=app.manifest$' "${OUTPUT_IDENTITY}" >/dev/null
grep '^wasm=.build/app.wasm$' "${OUTPUT_IDENTITY}" >/dev/null
grep '^assets=none$' "${OUTPUT_IDENTITY}" >/dev/null
expect_hash_line source_blake3
expect_hash_line manifest_blake3
expect_hash_line wasm_blake3
expect_hash_line package_blake3
cp "${OUTPUT_WASM}" "${TMP_DIR}/first.wasm"
cp "${OUTPUT_IDENTITY}" "${TMP_DIR}/first.identity"

"${ER_BUILD}" app-build "${PACKAGE_DIR}"
cmp "${OUTPUT_WASM}" "${TMP_DIR}/first.wasm"
cmp "${OUTPUT_IDENTITY}" "${TMP_DIR}/first.identity"
"${ER_BUILD}" app-verify "${PACKAGE_DIR}"

GENERATED_USER_APP="${ROOT_DIR}/.build/edgerun-metal/generated/user_app.wasm"
rm -f "${GENERATED_USER_APP}"
make -C "${ROOT_DIR}/edgerun-metal" ../.build/edgerun-metal/generated/user_app.wasm
cmp "${OUTPUT_WASM}" "${GENERATED_USER_APP}"

mkdir "${TMP_DIR}/tampered-source"
cp "${PACKAGE_DIR}/app.c" "${TMP_DIR}/tampered-source/app.c"
cp "${PACKAGE_DIR}/app.manifest" "${TMP_DIR}/tampered-source/app.manifest"
mkdir "${TMP_DIR}/tampered-source/.build"
cp "${OUTPUT_WASM}" "${TMP_DIR}/tampered-source/.build/app.wasm"
cp "${OUTPUT_IDENTITY}" "${TMP_DIR}/tampered-source/.build/package.identity"
printf '\n' >> "${TMP_DIR}/tampered-source/app.c"
if "${ER_BUILD}" app-verify "${TMP_DIR}/tampered-source" >/dev/null 2>&1; then
  printf 'app-verify accepted tampered source\n' >&2
  exit 1
fi

mkdir "${TMP_DIR}/tampered-wasm"
cp "${PACKAGE_DIR}/app.c" "${TMP_DIR}/tampered-wasm/app.c"
cp "${PACKAGE_DIR}/app.manifest" "${TMP_DIR}/tampered-wasm/app.manifest"
mkdir "${TMP_DIR}/tampered-wasm/.build"
cp "${OUTPUT_WASM}" "${TMP_DIR}/tampered-wasm/.build/app.wasm"
cp "${OUTPUT_IDENTITY}" "${TMP_DIR}/tampered-wasm/.build/package.identity"
printf '\000' >> "${TMP_DIR}/tampered-wasm/.build/app.wasm"
if "${ER_BUILD}" app-verify "${TMP_DIR}/tampered-wasm" >/dev/null 2>&1; then
  printf 'app-verify accepted tampered wasm\n' >&2
  exit 1
fi

mkdir "${TMP_DIR}/tampered-identity"
cp "${PACKAGE_DIR}/app.c" "${TMP_DIR}/tampered-identity/app.c"
cp "${PACKAGE_DIR}/app.manifest" "${TMP_DIR}/tampered-identity/app.manifest"
mkdir "${TMP_DIR}/tampered-identity/.build"
cp "${OUTPUT_WASM}" "${TMP_DIR}/tampered-identity/.build/app.wasm"
cp "${OUTPUT_IDENTITY}" "${TMP_DIR}/tampered-identity/.build/package.identity"
printf '\n' >> "${TMP_DIR}/tampered-identity/.build/package.identity"
if "${ER_BUILD}" app-verify "${TMP_DIR}/tampered-identity" >/dev/null 2>&1; then
  printf 'app-verify accepted tampered identity\n' >&2
  exit 1
fi

mkdir "${TMP_DIR}/bad-package"
cp "${PACKAGE_DIR}/app.c" "${TMP_DIR}/bad-package/app.c"
if "${ER_BUILD}" app-build "${TMP_DIR}/bad-package" >/dev/null 2>&1; then
  printf 'app-build accepted missing manifest\n' >&2
  exit 1
fi

mkdir "${TMP_DIR}/bad-manifest"
cp "${PACKAGE_DIR}/app.c" "${TMP_DIR}/bad-manifest/app.c"
sed 's/output=.build\/app.wasm/output=app.wasm/' \
  "${PACKAGE_DIR}/app.manifest" > "${TMP_DIR}/bad-manifest/app.manifest"
if "${ER_BUILD}" app-build "${TMP_DIR}/bad-manifest" >/dev/null 2>&1; then
  printf 'app-build accepted invalid manifest\n' >&2
  exit 1
fi

mkdir "${TMP_DIR}/driver-package"
cat > "${TMP_DIR}/driver-package/app.c" <<'CAPP'
extern i64 bus_exec(i64, i64) __import("edgerun.bus", "exec");
const i64 OUTBOX = 1024;
memory(1);
export i64 main(void) {
  i64 ptr = OUTBOX;
  store32(ptr, 0, 1);
  store32(ptr, 4, 0);
  store32(ptr, 8, 0);
  store32(ptr, 12, 4);
  return bus_exec(ptr, 16);
}
CAPP
cat > "${TMP_DIR}/driver-package/app.manifest" <<'MANIFEST'
contract=bus-driver
memory_pages=1
imports=edgerun.bus/exec
driver_memory_bytes=65536
driver_bus=mmio32:4096:4:read8
source=app.c
output=.build/app.wasm
MANIFEST
"${ER_BUILD}" app-build "${TMP_DIR}/driver-package"
"${ER_BUILD}" app-verify "${TMP_DIR}/driver-package"
grep '^manifest=app.manifest$' "${TMP_DIR}/driver-package/.build/package.identity" >/dev/null
if "${ER_BUILD}" app-run "${TMP_DIR}/driver-package" >/dev/null 2>&1; then
  printf 'app-run accepted bus-driver package\n' >&2
  exit 1
fi

"${ER_BUILD}" app-build "${DRIVER_PACKAGE_DIR}"
"${ER_BUILD}" app-verify "${DRIVER_PACKAGE_DIR}"
grep '^manifest=app.manifest$' "${DRIVER_PACKAGE_DIR}/.build/package.identity" >/dev/null
if "${ER_BUILD}" app-run "${DRIVER_PACKAGE_DIR}" >/dev/null 2>&1; then
  printf 'app-run accepted built-in bus-driver package\n' >&2
  exit 1
fi

mkdir "${TMP_DIR}/driver-bad-policy"
cp "${DRIVER_PACKAGE_DIR}/app.c" "${TMP_DIR}/driver-bad-policy/app.c"
sed 's/driver_bus=mmio32:4096:4:read8/driver_bus=mmio32:8192:4:read8/' \
  "${DRIVER_PACKAGE_DIR}/app.manifest" > "${TMP_DIR}/driver-bad-policy/app.manifest"
if "${ER_BUILD}" app-build "${TMP_DIR}/driver-bad-policy" >/dev/null 2>&1; then
  printf 'app-build accepted bad driver policy\n' >&2
  exit 1
fi

plan=$("${ER_BUILD}" --print-plan app-build "${PACKAGE_DIR}")
case "${plan}" in
  *"+ .build/wasm-compile ${PACKAGE_DIR}/app.c ${PACKAGE_DIR}/.build/app.wasm"* ) ;;
  * ) printf 'missing app-build wasm compile step\n%s\n' "${plan}" >&2; exit 1 ;;
esac

printf 'app-package build tests passed\n'
