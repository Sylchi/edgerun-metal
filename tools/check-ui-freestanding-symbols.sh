#!/usr/bin/env bash
set -euo pipefail

# Purpose:
#   Prove the production UI core plus varfont object set does not require host
#   libc or compiler runtime symbols.

readonly ROOT_DIR="$(git rev-parse --show-toplevel)"
readonly BUILD_DIR="${ROOT_DIR}/.build/edgerun-ui-core-freestanding-check"
readonly COMBINED_OBJ="${BUILD_DIR}/er_ui_core_varfont_freestanding.o"

cd "${ROOT_DIR}"

cmake -S edgerun-ui-core -B "${BUILD_DIR}" -G Ninja \
  -DER_UI_CORE_BUILD_TESTS=OFF \
  -DVRFONT_BUILD_HOSTED_TOOLS=OFF >/dev/null
cmake --build "${BUILD_DIR}" >/dev/null

ld.lld -r -o "${COMBINED_OBJ}" \
  "${BUILD_DIR}"/CMakeFiles/er_ui_core.dir/src/*.o \
  "${BUILD_DIR}"/varfont/CMakeFiles/vrfont.dir/src/*.o

if nm -u "${COMBINED_OBJ}" | grep -q .; then
  printf 'freestanding symbol check failed; unresolved symbols:\n' >&2
  nm -u "${COMBINED_OBJ}" >&2
  exit 1
fi

printf 'ui freestanding symbol check passed\n'
