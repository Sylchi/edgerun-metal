#!/usr/bin/env sh
set -eu

# Purpose:
#   Validate the hosted disk analyzer on a bounded synthetic tree.
# Intention:
#   Keep folder accounting, cache classification, duplicate reporting, and
#   verified hardlink merging covered without scanning the developer's disk.

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUILD_DIR="${ROOT_DIR}/.build/disk-analyzer-tests"
TOOL_BIN="${BUILD_DIR}/disk-analyzer"
TREE="${BUILD_DIR}/tree"

rm -rf "${BUILD_DIR}"
mkdir -p "${TREE}/src/a" "${TREE}/src/b" "${TREE}/proj/node_modules/pkg"

"${CC:-${ROOT_DIR}/toolchain/bin/clang}" -std=c11 -Wall -Wextra -Werror -O2 \
  -I"${ROOT_DIR}/include" \
  -I"${ROOT_DIR}/edgerun-metal/core" \
  -o "${TOOL_BIN}" \
  "${ROOT_DIR}/tools/disk-analyzer/main.c" \
  "${ROOT_DIR}/tools/disk-analyzer/disk_analyzer.c" \
  "${ROOT_DIR}/edgerun-metal/core/er_disk_analyzer.c" \
  "${ROOT_DIR}/edgerun-metal/core/er_mem.c"

printf 'same duplicate payload\n' >"${TREE}/src/a/original.bin"
cp "${TREE}/src/a/original.bin" "${TREE}/src/b/copy.bin"
printf 'different payload\n' >"${TREE}/src/b/other.bin"
printf 'cache bytes\n' >"${TREE}/proj/node_modules/pkg/file.txt"

if "${TOOL_BIN}" --root "${TREE}" --merge-hardlinks \
  >/tmp/disk-analyzer-merge-bad.out 2>/tmp/disk-analyzer-merge-bad.err; then
  printf 'disk-analyzer accepted merge without --yes\n' >&2
  exit 1
fi
if ! grep -q -- "--merge-hardlinks requires --yes" /tmp/disk-analyzer-merge-bad.err; then
  printf 'disk-analyzer did not explain merge confirmation requirement\n' >&2
  exit 1
fi

"${TOOL_BIN}" --root "${TREE}" --top 8 --duplicates 8 --min-dup-size 1 \
  >/tmp/disk-analyzer-report.out

for expected in \
  "disk-analyzer root=${TREE}" \
  "top-folders count=" \
  "cache=node path=${TREE}/proj/node_modules" \
  "duplicate bytes=23 canonical=${TREE}/src/a/original.bin duplicate=${TREE}/src/b/copy.bin" \
  "duplicate-summary candidate-size-groups=1 sampled-files=2"; do
  if ! grep -q "${expected}" /tmp/disk-analyzer-report.out; then
    printf 'disk-analyzer missing output: %s\n' "${expected}" >&2
    exit 1
  fi
done

"${TOOL_BIN}" --root "${TREE}" --top 8 --duplicates 8 --min-dup-size 1 \
  --merge-hardlinks --yes >/tmp/disk-analyzer-merge.out

for expected in \
  "duplicate bytes=23 canonical=${TREE}/src/a/original.bin duplicate=${TREE}/src/b/copy.bin" \
  "merged-hardlinks=1"; do
  if ! grep -q "${expected}" /tmp/disk-analyzer-merge.out; then
    printf 'disk-analyzer missing merge output: %s\n' "${expected}" >&2
    exit 1
  fi
done

inode_a=$(stat -c '%d:%i' "${TREE}/src/a/original.bin")
inode_b=$(stat -c '%d:%i' "${TREE}/src/b/copy.bin")
if [ "${inode_a}" != "${inode_b}" ]; then
  printf 'disk-analyzer did not hardlink duplicate files\n' >&2
  exit 1
fi

printf 'disk-analyzer tests passed\n'
