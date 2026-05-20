#!/usr/bin/env sh
set -eu

# Purpose:
#   Validate the repository-owned Raspberry Pi USB boot helper.
# Intention:
#   Keep Pi bring-up explicit and fail before hardware access when required
#   boot artifacts are absent.

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUILD_DIR="${ROOT_DIR}/.build/pi-usb-boot-tests"
TOOL_BIN="${BUILD_DIR}/pi-usb-boot"
BOOT_DIR="${BUILD_DIR}/boot"
EMPTY_BOOT_DIR="${BUILD_DIR}/empty-boot"

rm -rf "$BUILD_DIR"
mkdir -p "$BOOT_DIR" "$EMPTY_BOOT_DIR"

clang -std=c11 -Wall -Wextra -Werror -O2 -o "$TOOL_BIN" \
  "${ROOT_DIR}/tools/pi-usb-boot/main.c"

if "$TOOL_BIN" >/tmp/pi-usb-boot-usage.out 2>/tmp/pi-usb-boot-usage.err; then
  printf 'pi-usb-boot accepted missing arguments\n' >&2
  exit 1
fi

if ! grep -q "usage: .*--boot-dir <dir>" /tmp/pi-usb-boot-usage.err; then
  printf 'pi-usb-boot usage text is not explicit\n' >&2
  exit 1
fi

if "$TOOL_BIN" --boot-dir "$EMPTY_BOOT_DIR" --dry-run \
  >/tmp/pi-usb-boot-empty.out 2>/tmp/pi-usb-boot-empty.err; then
  printf 'pi-usb-boot accepted missing bootcode.bin\n' >&2
  exit 1
fi

if ! grep -q "boot directory must contain non-empty bootcode.bin" \
  /tmp/pi-usb-boot-empty.err; then
  printf 'pi-usb-boot did not report missing bootcode.bin\n' >&2
  exit 1
fi

printf 'owned-test-second-stage\n' >"${BOOT_DIR}/bootcode.bin"
printf 'kernel=kernel.img\n' >"${BOOT_DIR}/config.txt"
printf 'owned-test-kernel\n' >"${BOOT_DIR}/kernel.img"

"$TOOL_BIN" --boot-dir "$BOOT_DIR" --dry-run \
  >/tmp/pi-usb-boot-dry-run.out

if ! grep -q "pi-usb-boot: boot directory ready" \
  /tmp/pi-usb-boot-dry-run.out; then
  printf 'pi-usb-boot dry-run did not validate boot directory\n' >&2
  exit 1
fi

printf 'pi-usb-boot tests passed\n'
