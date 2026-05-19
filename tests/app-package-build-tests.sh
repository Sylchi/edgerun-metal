#!/usr/bin/env sh
set -eu

# Purpose:
#   Verify canonical app packages build through the repository-owned wrapper.
# Intention:
#   Keep user-authored app builds explicit and generated Wasm under package .build/.

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ER_BUILD="${ROOT_DIR}/.build/er-build"
PACKAGE_DIR="${ROOT_DIR}/tests/fixtures/app-package/app"
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

plan=$("${ER_BUILD}" --print-plan app-build "${PACKAGE_DIR}")
case "${plan}" in
  *"+ .build/wasm-compile ${PACKAGE_DIR}/app.c ${PACKAGE_DIR}/.build/app.wasm"* ) ;;
  * ) printf 'missing app-build wasm compile step\n%s\n' "${plan}" >&2; exit 1 ;;
esac

printf 'app-package build tests passed\n'
