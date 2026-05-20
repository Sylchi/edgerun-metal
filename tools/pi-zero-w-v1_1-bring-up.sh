#!/usr/bin/env sh
set -eu

# Purpose:
#   Run the Pi Zero W v1.1 bring-up path as one operator command.
# Intention:
#   Hide protocol details from normal use while still verifying real erwire
#   boot, update, and advertisement packets from the board.

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BOOT_DIR="${ROOT_DIR}/.build/edgerun-metal/pi-zero-w-v1_1/boot"
MANIFEST="${BOOT_DIR}/EDGERUN-PI-ZERO-W-V1_1-BOOT.txt"
DEFAULT_LOG="${ROOT_DIR}/.build/pi-zero-w-v1_1/serial.bin"
SERIAL_DEVICE="${PI_SERIAL_DEVICE:-}"
USB_DEVICE="${PI_USB_DEVICE:-}"
SERIAL_LOG="$DEFAULT_LOG"
CAPTURE_SECONDS="${PI_CAPTURE_SECONDS:-20}"
SKIP_USB=0
VERIFY_ONLY=0
DRY_RUN=0

usage() {
  cat >&2 <<EOF_USAGE
usage: $0 [--serial /dev/ttyUSB0] [--usb-device /dev/bus/usb/BBB/DDD] [--serial-log PATH] [--capture-seconds N] [--skip-usb] [--verify-only] [--dry-run]
EOF_USAGE
}

say() {
  printf '%s\n' "$1"
}

fail() {
  printf 'Not ready: %s\n' "$1" >&2
  exit 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --serial)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      SERIAL_DEVICE="$2"
      shift 2
      ;;
    --usb-device)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      USB_DEVICE="$2"
      shift 2
      ;;
    --serial-log)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      SERIAL_LOG="$2"
      shift 2
      ;;
    --capture-seconds)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      CAPTURE_SECONDS="$2"
      shift 2
      ;;
    --skip-usb)
      SKIP_USB=1
      shift
      ;;
    --verify-only)
      VERIFY_ONLY=1
      SKIP_USB=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

case "$CAPTURE_SECONDS" in
  ''|*[!0-9]*)
    fail "capture seconds must be a whole number"
    ;;
esac

pick_serial_device() {
  count=0
  chosen=''
  for candidate in /dev/ttyUSB* /dev/ttyACM*; do
    [ -e "$candidate" ] || continue
    count=$((count + 1))
    chosen="$candidate"
  done
  if [ "$count" -eq 1 ]; then
    SERIAL_DEVICE="$chosen"
  elif [ "$count" -gt 1 ]; then
    fail "more than one small board cable is attached; run PI_SERIAL_DEVICE=/dev/ttyUSB0 make pi-ready"
  fi
}

build_needed_files() {
  say "Preparing the board image."
  make -C "$ROOT_DIR/edgerun-metal" pi-zero-w-v1_1-boot >/dev/null
  make -C "$ROOT_DIR" pi-usb-boot pi-serial-verify >/dev/null
}

start_capture() {
  mkdir -p "$(dirname -- "$SERIAL_LOG")"
  : >"$SERIAL_LOG"
  stty -F "$SERIAL_DEVICE" 115200 raw -echo -ixon -ixoff -crtscts
  cat "$SERIAL_DEVICE" >"$SERIAL_LOG" &
  CAPTURE_PID=$!
}

stop_capture() {
  if [ "${CAPTURE_PID:-}" != "" ]; then
    kill "$CAPTURE_PID" >/dev/null 2>&1 || true
    wait "$CAPTURE_PID" >/dev/null 2>&1 || true
  fi
}

run_usb_boot() {
  usb_args="--boot-dir $BOOT_DIR"
  if [ "$USB_DEVICE" != "" ]; then
    usb_args="$usb_args --device $USB_DEVICE"
  fi
  if [ "$DRY_RUN" -ne 0 ]; then
    usb_args="$usb_args --dry-run"
  fi
  # shellcheck disable=SC2086
  "$ROOT_DIR/.build/pi-usb-boot" $usb_args >/tmp/pi-zero-w-v1_1-usb.out 2>/tmp/pi-zero-w-v1_1-usb.err ||
    fail "the board did not accept boot files; unplug it, hold BOOT, plug it back in, then run the same command"
}

verify_capture() {
  "$ROOT_DIR/.build/pi-serial-verify" "$MANIFEST" "$SERIAL_LOG" >/tmp/pi-zero-w-v1_1-verify.out 2>/tmp/pi-zero-w-v1_1-verify.err ||
    fail "the board did not send its ready signal; check the small serial cable and run the same command again"
}

if [ "$VERIFY_ONLY" -eq 0 ]; then
  build_needed_files
else
  make -C "$ROOT_DIR" pi-serial-verify >/dev/null
fi

if [ "$SERIAL_DEVICE" = "" ]; then
  pick_serial_device
fi

if [ "$SERIAL_DEVICE" = "" ] && [ "$VERIFY_ONLY" -eq 0 ]; then
  say "No small serial cable was found. I can still send the boot files, but I cannot prove the board is ready."
elif [ "$VERIFY_ONLY" -eq 0 ]; then
  [ -e "$SERIAL_DEVICE" ] || fail "the selected small serial cable is not present"
fi

if [ "$SERIAL_DEVICE" != "" ] && [ "$VERIFY_ONLY" -eq 0 ]; then
  start_capture
  trap stop_capture EXIT INT TERM
fi

if [ "$SKIP_USB" -eq 0 ]; then
  say "Sending the board image."
  run_usb_boot
fi

if [ "$VERIFY_ONLY" -ne 0 ]; then
  verify_capture
  say "Board is ready."
  say "Log: $SERIAL_LOG"
elif [ "$SERIAL_DEVICE" != "" ]; then
  say "Waiting for the board to say it is ready."
  sleep "$CAPTURE_SECONDS"
  stop_capture
  verify_capture
  say "Board is ready."
  say "Log: $SERIAL_LOG"
else
  say "Boot files sent. Attach the small serial cable and run: PI_SERIAL_DEVICE=/dev/ttyUSB0 make pi-ready"
fi
