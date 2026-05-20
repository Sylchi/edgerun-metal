#!/usr/bin/env sh
set -eu

# Purpose:
#   Validate the one-command Pi Zero W v1.1 operator bring-up wrapper.
# Intention:
#   Keep the easy path tied to the real boot manifest and serial verifier.

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUILD_DIR="${ROOT_DIR}/.build/pi-zero-w-v1_1-bring-up-tests"
LOG_PATH="${BUILD_DIR}/serial-erwire.bin"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

make -C "$ROOT_DIR/edgerun-metal" pi-zero-w-v1_1-boot >/tmp/pi-zero-w-v1_1-bring-up-build.out
make -C "$ROOT_DIR" pi-serial-verify >/tmp/pi-zero-w-v1_1-bring-up-tool.out
"$ROOT_DIR/tests/pi-serial-verify-tests.sh" >/tmp/pi-zero-w-v1_1-bring-up-fixture.out
cp "${ROOT_DIR}/.build/pi-serial-verify-tests/serial-erwire.bin" "$LOG_PATH"

"$ROOT_DIR/tools/pi-zero-w-v1_1-bring-up.sh" \
  --verify-only \
  --serial /dev/null \
  --serial-log "$LOG_PATH" \
  --capture-seconds 0 \
  >/tmp/pi-zero-w-v1_1-bring-up-ok.out

if ! grep -q "Board is ready." /tmp/pi-zero-w-v1_1-bring-up-ok.out; then
  printf 'bring-up wrapper did not report ready on a valid capture\n' >&2
  exit 1
fi

if "$ROOT_DIR/tools/pi-zero-w-v1_1-bring-up.sh" --verify-only \
  --serial /dev/null \
  --serial-log "$BUILD_DIR/missing.bin" \
  --capture-seconds 0 \
  >/tmp/pi-zero-w-v1_1-bring-up-missing.out \
  2>/tmp/pi-zero-w-v1_1-bring-up-missing.err; then
  printf 'bring-up wrapper accepted missing capture\n' >&2
  exit 1
fi

if ! grep -q "Not ready:" /tmp/pi-zero-w-v1_1-bring-up-missing.err; then
  printf 'bring-up wrapper did not print plain failure text\n' >&2
  exit 1
fi

"$ROOT_DIR/tools/pi-zero-w-v1_1-bring-up.sh" \
  --dry-run \
  --serial-log "$BUILD_DIR/no-serial.bin" \
  --capture-seconds 0 \
  >/tmp/pi-zero-w-v1_1-bring-up-dry-run.out

if ! grep -q "No small serial cable was found" \
  /tmp/pi-zero-w-v1_1-bring-up-dry-run.out; then
  printf 'bring-up wrapper did not explain missing serial cable plainly\n' >&2
  exit 1
fi

if ! make -C "$ROOT_DIR" -n pi-ready | grep -q "pi-zero-w-v1_1-bring-up.sh"; then
  printf 'top-level pi-ready alias does not run the bring-up wrapper\n' >&2
  exit 1
fi

printf 'pi zero w v1.1 bring-up tests passed\n'
