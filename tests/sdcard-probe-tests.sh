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

"${TOOL_BIN}" --destroy "${IMAGE}" --bytes 1048576 --block-bytes 1048576 \
  >/tmp/sdcard-probe-ok.out 2>&1

for expected in \
  "kind: regular-file" \
  "claimed-bytes: 2097152" \
  "start-bytes: 0" \
  "tested-bytes: 1048576" \
  "write-bytes: 1048576" \
  "verify-bytes: 1048576" \
  "actual-bytes: 1048576" \
  "class-bounds-mb-sec: C2>=2 C4>=4 C6>=6 C10/U1/V10>=10 U3/V30>=30 V60>=60 V90>=90" \
  "observed-sd-speed-class:" \
  "observed-uhs-speed-class:" \
  "observed-video-speed-class:" \
  "write-interpretation:" \
  "status: pass"; do
  if ! grep -q "${expected}" /tmp/sdcard-probe-ok.out; then
    printf 'sdcard-probe missing output: %s\n' "${expected}" >&2
    exit 1
  fi
done

if ! grep -q "checked 1048576 / 1048576 bytes write" \
  /tmp/sdcard-probe-ok.out; then
  printf 'sdcard-probe did not report first span progress\n' >&2
  exit 1
fi

"${TOOL_BIN}" --destroy "${IMAGE}" --start-bytes 1048576 --bytes 1048576 \
  --block-bytes 1048576 >/tmp/sdcard-probe-offset.out 2>&1

for expected in \
  "claimed-bytes: 2097152" \
  "start-bytes: 1048576" \
  "tested-bytes: 1048576" \
  "first-bad-offset: 2097152" \
  "actual-bytes: 1048576" \
  "status: pass"; do
  if ! grep -q "${expected}" /tmp/sdcard-probe-offset.out; then
    printf 'sdcard-probe missing offset output: %s\n' "${expected}" >&2
    exit 1
  fi
done

if "${TOOL_BIN}" --destroy "${IMAGE}" --start-bytes 3 --bytes 1048576 \
  >/tmp/sdcard-probe-start-bad.out 2>/tmp/sdcard-probe-start-bad.err; then
  printf 'sdcard-probe accepted unaligned start offset\n' >&2
  exit 1
fi

if ! grep -q "start offset must be a multiple of block size" \
  /tmp/sdcard-probe-start-bad.err; then
  printf 'sdcard-probe did not explain unaligned start offset\n' >&2
  exit 1
fi

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
