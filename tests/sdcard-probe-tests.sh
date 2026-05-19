#!/usr/bin/env sh
set -eu

# Purpose:
#   Validate the destructive SD-card probe against a bounded regular-file target.
# Intention:
#   Keep capacity reporting, usage gating, and benchmark output covered without
#   touching real hardware during repository tests.

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUILD_DIR="${ROOT_DIR}/.build/sdcard-probe-tests"
TOOL_BIN="${BUILD_DIR}/sdcard-probe"
IMAGE="${BUILD_DIR}/card.img"

mkdir -p "${BUILD_DIR}"

clang -std=c11 -Wall -Wextra -Werror -O2 \
  -o "${TOOL_BIN}" \
  "${ROOT_DIR}/tools/sdcard-probe/main.c"

if "${TOOL_BIN}" "${IMAGE}" >/tmp/sdcard-probe-usage.out \
  2>/tmp/sdcard-probe-usage.err; then
  printf 'sdcard-probe accepted missing --destroy\n' >&2
  exit 1
fi

if ! grep -q "usage: .* --destroy <device-or-file>" \
  /tmp/sdcard-probe-usage.err; then
  printf 'sdcard-probe usage text is not explicit\n' >&2
  exit 1
fi

rm -f "${IMAGE}"
dd if=/dev/zero of="${IMAGE}" bs=1048576 count=2 >/dev/null 2>&1

"${TOOL_BIN}" --destroy "${IMAGE}" --bytes 1048576 \
  >/tmp/sdcard-probe-ok.out

for expected in \
  "kind: regular-file" \
  "claimed-bytes: 2097152" \
  "tested-bytes: 1048576" \
  "write-bytes: 1048576" \
  "verify-bytes: 1048576" \
  "actual-bytes: 1048576" \
  "class-bounds-mb-sec: C2>=2 C4>=4 C6>=6 C10/U1/V10>=10 U3/V30>=30 V60>=60 V90>=90" \
  "observed-sd-speed-class:" \
  "observed-uhs-speed-class:" \
  "observed-video-speed-class:" \
  "status: pass"; do
  if ! grep -q "${expected}" /tmp/sdcard-probe-ok.out; then
    printf 'sdcard-probe missing output: %s\n' "${expected}" >&2
    exit 1
  fi
done

if "${TOOL_BIN}" --destroy "${IMAGE}" --bytes 3 \
  >/tmp/sdcard-probe-bad.out 2>/tmp/sdcard-probe-bad.err; then
  printf 'sdcard-probe accepted unaligned byte count\n' >&2
  exit 1
fi

if ! grep -q "byte limit must be a multiple of block size" \
  /tmp/sdcard-probe-bad.err; then
  printf 'sdcard-probe did not explain unaligned byte count\n' >&2
  exit 1
fi

printf 'sdcard-probe tests passed\n'
