#!/usr/bin/env sh
set -eu

# Purpose:
#   Validate the one-command Pi Zero W v1.1 operator bring-up wrapper.
# Intention:
#   Keep the easy path tied to the real boot manifest and serial verifier.

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUILD_DIR="${ROOT_DIR}/.build/pi-zero-w-v1_1-bring-up-tests"
LOG_PATH="${BUILD_DIR}/serial-erwire.bin"
LSUSB_PATH="${BUILD_DIR}/lsusb.txt"
USB_BOOT_FAKE="${BUILD_DIR}/pi-usb-boot-fake.sh"
USB_RESET_FAKE="${BUILD_DIR}/pi-usb-reset-fake.sh"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

cat >"$USB_BOOT_FAKE" <<'EOF_USB_BOOT_FAKE'
#!/usr/bin/env sh
set -eu
COUNT_FILE="${PI_USB_BOOT_FAKE_COUNT:?}"
ARGS_FILE="${PI_USB_BOOT_FAKE_ARGS:?}"
count=0
if [ -f "$COUNT_FILE" ]; then
  count=$(cat "$COUNT_FILE")
fi
printf '%s\n' "$@" >"$ARGS_FILE"
if [ "$count" -eq 0 ]; then
  printf '1\n' >"$COUNT_FILE"
  exit 1
fi
printf '2\n' >"$COUNT_FILE"
exit 0
EOF_USB_BOOT_FAKE
chmod 755 "$USB_BOOT_FAKE"

cat >"$USB_RESET_FAKE" <<'EOF_USB_RESET_FAKE'
#!/usr/bin/env sh
set -eu
printf '%s\n' "$1" >"${PI_USB_RESET_FAKE_LOG:?}"
EOF_USB_RESET_FAKE
chmod 755 "$USB_RESET_FAKE"

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

cat >"$LSUSB_PATH" <<'EOF_LSUSB'
Bus 007 Device 005: ID 0a5c:2763 Broadcom Corp. BCM2708 Boot
EOF_LSUSB

PI_USB_BOOT_TOOL="$USB_BOOT_FAKE" \
PI_USB_BOOT_LSUSB_FILE="$LSUSB_PATH" \
PI_USB_BOOT_FAKE_COUNT="$BUILD_DIR/usb-boot-count.txt" \
PI_USB_BOOT_FAKE_ARGS="$BUILD_DIR/usb-boot-args.txt" \
PI_USB_RESET_CMD="$USB_RESET_FAKE" \
PI_USB_RESET_FAKE_LOG="$BUILD_DIR/usb-reset-log.txt" \
  "$ROOT_DIR/tools/pi-zero-w-v1_1-bring-up.sh" \
  --serial-log "$BUILD_DIR/recovered-no-serial.bin" \
  --capture-seconds 0 \
  >/tmp/pi-zero-w-v1_1-bring-up-recovered.out

if ! grep -q "Resetting the Pi USB station." \
  /tmp/pi-zero-w-v1_1-bring-up-recovered.out; then
  printf 'bring-up wrapper did not reset the USB station after boot failure\n' >&2
  exit 1
fi

if ! grep -q -- "--device" "$BUILD_DIR/usb-boot-args.txt" ||
   ! grep -q "/dev/bus/usb/007/005" "$BUILD_DIR/usb-boot-args.txt"; then
  printf 'bring-up wrapper did not pass the discovered Broadcom boot node\n' >&2
  exit 1
fi

if ! grep -q "0000:c3:00.4" "$BUILD_DIR/usb-reset-log.txt"; then
  printf 'bring-up wrapper did not reset the known Pi USB xHCI device\n' >&2
  exit 1
fi

if ! grep -q "Boot files sent. Attach the small serial cable and run make pi-ready again." \
  /tmp/pi-zero-w-v1_1-bring-up-recovered.out; then
  printf 'bring-up wrapper did not print a plain retry instruction after recovery\n' >&2
  exit 1
fi

if ! make -C "$ROOT_DIR" -n pi-ready | grep -q "pi-zero-w-v1_1-bring-up.sh"; then
  printf 'top-level pi-ready alias does not run the bring-up wrapper\n' >&2
  exit 1
fi

if ! make -C "$ROOT_DIR" -n pi-zero-w-v1_1-update PI_UPDATE_IFACE=wlan0 |
  grep -q "pi-node-update --iface"; then
  printf 'pi zero w v1.1 update target does not use the Wi-Fi OTA sender\n' >&2
  exit 1
fi

printf 'pi zero w v1.1 bring-up tests passed\n'
