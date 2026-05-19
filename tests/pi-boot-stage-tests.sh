#!/usr/bin/env sh
set -eu

# Purpose:
#   Validate the repo-owned Pi Zero 2 W boot staging tool.
# Intention:
#   Keep board boot artifacts explicit, deterministic, and separate from
#   non-owned Raspberry Pi firmware and U-Boot first-stage prerequisites.

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUILD_DIR="${ROOT_DIR}/.build/pi-boot-stage-tests"
TOOL_BIN="${BUILD_DIR}/pi-boot-stage"
PAYLOAD="${BUILD_DIR}/BOOTAA64.EFI"
ZERO_W_PAYLOAD="${BUILD_DIR}/kernel.img"
BOOT_DIR="${BUILD_DIR}/boot"
ZERO_W_BOOT_DIR="${BUILD_DIR}/boot-zero-w"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

clang -std=c11 -Wall -Wextra -Werror -O2 -o "$TOOL_BIN" \
  "${ROOT_DIR}/tools/pi-boot-stage/main.c"

if "$TOOL_BIN" >/tmp/pi-boot-stage-usage.out 2>/tmp/pi-boot-stage-usage.err; then
  printf 'pi-boot-stage accepted missing arguments\n' >&2
  exit 1
fi

if ! grep -q "usage: pi-boot-stage <board> <payload> <output-dir>" \
  /tmp/pi-boot-stage-usage.err; then
  printf 'pi-boot-stage usage text is not explicit\n' >&2
  exit 1
fi

printf 'not-a-directory\n' >"${BUILD_DIR}/not-a-directory"
if "$TOOL_BIN" pi-zero-2w "$PAYLOAD" "${BUILD_DIR}/not-a-directory" \
  >/tmp/pi-boot-stage-file.out 2>/tmp/pi-boot-stage-file.err; then
  printf 'pi-boot-stage accepted a file as output directory\n' >&2
  exit 1
fi

printf 'edgerun-test-payload\n' >"$PAYLOAD"
"$TOOL_BIN" pi-zero-2w "$PAYLOAD" "$BOOT_DIR" >/tmp/pi-boot-stage-run.out

if ! cmp -s "$PAYLOAD" "$BOOT_DIR/EFI/BOOT/BOOTAA64.EFI"; then
  printf 'staged BOOTAA64.EFI does not match input payload\n' >&2
  exit 1
fi

if ! grep -q "kernel=u-boot.bin" "$BOOT_DIR/config.txt"; then
  printf 'config.txt does not name explicit U-Boot kernel\n' >&2
  exit 1
fi

if ! grep -q "owned_payload=EFI/BOOT/BOOTAA64.EFI" \
  "$BOOT_DIR/EDGERUN-PI-ZERO-2W-BOOT.txt"; then
  printf 'boot manifest does not name owned payload\n' >&2
  exit 1
fi

if ! grep -q "required_first_stage=raspberry-pi-firmware" \
  "$BOOT_DIR/EDGERUN-PI-ZERO-2W-BOOT.txt"; then
  printf 'boot manifest does not name Raspberry Pi firmware prerequisite\n' >&2
  exit 1
fi

if ! grep -q "required_first_stage=u-boot.bin" \
  "$BOOT_DIR/EDGERUN-PI-ZERO-2W-BOOT.txt"; then
  printf 'boot manifest does not name U-Boot prerequisite\n' >&2
  exit 1
fi

if ! grep -q "node=erz2w-5:mobile-observer-route-churn-late-admission" \
  "$BOOT_DIR/EDGERUN-PI-ZERO-2W-BOOT.txt"; then
  printf 'boot manifest does not include the sixth Pi node role\n' >&2
  exit 1
fi

printf 'edgerun-armv6-test-payload\n' >"$ZERO_W_PAYLOAD"
"$TOOL_BIN" pi-zero-w-v1_1 "$ZERO_W_PAYLOAD" "$ZERO_W_BOOT_DIR" \
  >/tmp/pi-boot-stage-zero-w-run.out

if ! cmp -s "$ZERO_W_PAYLOAD" "$ZERO_W_BOOT_DIR/kernel.img"; then
  printf 'staged kernel.img does not match input payload\n' >&2
  exit 1
fi

if ! grep -q "arm_64bit=0" "$ZERO_W_BOOT_DIR/config.txt"; then
  printf 'zero w config.txt does not force 32-bit boot\n' >&2
  exit 1
fi

if ! grep -q "kernel=kernel.img" "$ZERO_W_BOOT_DIR/config.txt"; then
  printf 'zero w config.txt does not name owned kernel payload\n' >&2
  exit 1
fi

if ! grep -q "core_freq=250" "$ZERO_W_BOOT_DIR/config.txt"; then
  printf 'zero w config.txt does not pin mini UART core clock\n' >&2
  exit 1
fi

if ! grep -q "board=pi-zero-w-v1_1" \
  "$ZERO_W_BOOT_DIR/EDGERUN-PI-ZERO-W-V1_1-BOOT.txt"; then
  printf 'zero w manifest does not name actual board\n' >&2
  exit 1
fi

if ! grep -q "owned_payload=kernel.img" \
  "$ZERO_W_BOOT_DIR/EDGERUN-PI-ZERO-W-V1_1-BOOT.txt"; then
  printf 'zero w manifest does not name owned kernel payload\n' >&2
  exit 1
fi

if ! grep -q "serial_baud=115200" \
  "$ZERO_W_BOOT_DIR/EDGERUN-PI-ZERO-W-V1_1-BOOT.txt"; then
  printf 'zero w manifest does not name serial baud\n' >&2
  exit 1
fi

if ! grep -q "serial_gpio_tx=14" \
  "$ZERO_W_BOOT_DIR/EDGERUN-PI-ZERO-W-V1_1-BOOT.txt"; then
  printf 'zero w manifest does not name serial TX pin\n' >&2
  exit 1
fi

if ! grep -q "serial_gpio_rx=15" \
  "$ZERO_W_BOOT_DIR/EDGERUN-PI-ZERO-W-V1_1-BOOT.txt"; then
  printf 'zero w manifest does not name serial RX pin\n' >&2
  exit 1
fi

if ! grep -q "serial_expect=EdgeRun Pi Zero W v1.1 ARMv6 boot" \
  "$ZERO_W_BOOT_DIR/EDGERUN-PI-ZERO-W-V1_1-BOOT.txt"; then
  printf 'zero w manifest does not name serial banner expectation\n' >&2
  exit 1
fi

if ! grep -q "serial_expect=peripheral_base=0x20000000" \
  "$ZERO_W_BOOT_DIR/EDGERUN-PI-ZERO-W-V1_1-BOOT.txt"; then
  printf 'zero w manifest does not name peripheral base expectation\n' >&2
  exit 1
fi

if ! grep -q "serial_expect=alive=0x00000000" \
  "$ZERO_W_BOOT_DIR/EDGERUN-PI-ZERO-W-V1_1-BOOT.txt"; then
  printf 'zero w manifest does not name heartbeat expectation\n' >&2
  exit 1
fi

if "$TOOL_BIN" pi-zero-vague "$PAYLOAD" "$BOOT_DIR" \
  >/tmp/pi-boot-stage-bad-board.out 2>/tmp/pi-boot-stage-bad-board.err; then
  printf 'pi-boot-stage accepted unsupported board\n' >&2
  exit 1
fi

if ! grep -q "unsupported board" /tmp/pi-boot-stage-bad-board.err; then
  printf 'pi-boot-stage unsupported board error missing\n' >&2
  exit 1
fi

printf 'pi boot stage tests passed\n'
