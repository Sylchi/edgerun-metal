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
TMP_DIR=$(mktemp -d)

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

rm -f "${OUTPUT_WASM}"

"${ER_BUILD}" app-build "${PACKAGE_DIR}"
test -f "${OUTPUT_WASM}"
case "$(od -An -tx1 -N8 "${OUTPUT_WASM}")" in
  *"00 61 73 6d 01 00 00 00"* ) ;;
  * ) printf 'bad package wasm header\n' >&2; exit 1 ;;
esac
cp "${OUTPUT_WASM}" "${TMP_DIR}/first.wasm"

"${ER_BUILD}" app-build "${PACKAGE_DIR}"
cmp "${OUTPUT_WASM}" "${TMP_DIR}/first.wasm"

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
