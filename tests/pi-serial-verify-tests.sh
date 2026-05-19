#!/usr/bin/env sh
set -eu

# Purpose:
#   Validate manifest-driven Raspberry Pi serial boot log checking.
# Intention:
#   Keep physical board bring-up criteria deterministic and executable.

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUILD_DIR="${ROOT_DIR}/.build/pi-serial-verify-tests"
TOOL_BIN="${BUILD_DIR}/pi-serial-verify"
MANIFEST="${BUILD_DIR}/EDGERUN-PI-ZERO-W-V1_1-BOOT.txt"
SERIAL_LOG="${BUILD_DIR}/serial.log"
BAD_LOG="${BUILD_DIR}/serial-bad.log"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

clang -std=c11 -Wall -Wextra -Werror -O2 -o "$TOOL_BIN" \
  "${ROOT_DIR}/tools/pi-serial-verify/main.c"

if "$TOOL_BIN" >/tmp/pi-serial-verify-usage.out \
  2>/tmp/pi-serial-verify-usage.err; then
  printf 'pi-serial-verify accepted missing arguments\n' >&2
  exit 1
fi

if ! grep -q "usage: pi-serial-verify <manifest> <serial-log>" \
  /tmp/pi-serial-verify-usage.err; then
  printf 'pi-serial-verify usage text is not explicit\n' >&2
  exit 1
fi

cat >"$MANIFEST" <<'EOF_MANIFEST'
board=pi-zero-w-v1_1
serial_expect=EdgeRun Pi Zero W v1.1 ARMv6 boot
serial_expect=board=pi-zero-w-v1_1 radio=cyw43438
serial_expect=alive=0x00000000
EOF_MANIFEST

printf 'noise before\r\nEdgeRun Pi Zero W v1.1 ARMv6 boot\r\nboard=pi-zero-w-v1_1 radio=cyw43438\r\nalive=0x00000000\r\n' \
  >"$SERIAL_LOG"

"$TOOL_BIN" "$MANIFEST" "$SERIAL_LOG" >/tmp/pi-serial-verify-ok.out

if ! grep -q "pi-serial-verify: 3 serial expectations matched" \
  /tmp/pi-serial-verify-ok.out; then
  printf 'pi-serial-verify did not report matched expectations\n' >&2
  exit 1
fi

printf 'EdgeRun Pi Zero W v1.1 ARMv6 boot\nalive=0x00000000\nboard=pi-zero-w-v1_1 radio=cyw43438\n' \
  >"$BAD_LOG"

if "$TOOL_BIN" "$MANIFEST" "$BAD_LOG" >/tmp/pi-serial-verify-bad.out \
  2>/tmp/pi-serial-verify-bad.err; then
  printf 'pi-serial-verify accepted out-of-order serial log\n' >&2
  exit 1
fi

if ! grep -q "missing serial expectation: alive=0x00000000" \
  /tmp/pi-serial-verify-bad.err; then
  printf 'pi-serial-verify did not name missing ordered expectation\n' >&2
  exit 1
fi

printf 'pi serial verify tests passed\n'
