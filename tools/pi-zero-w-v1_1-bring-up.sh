#!/usr/bin/env sh
set -eu

# Purpose:
#   Run the Pi Zero W v1.1 bring-up path as one operator command.
# Intention:
#   Hide protocol details from normal use while still verifying real erwire
#   boot, update, and advertisement packets from the board.

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
NODE_INDEX="${PI_ZERO_W_V1_1_NODE_INDEX:-0}"
NODE_BUILD_DIR="${ROOT_DIR}/.build/edgerun-metal/pi-zero-w-v1_1/erzw-${NODE_INDEX}"
NODE_BUILD_DIR_FOR_MAKE="../.build/edgerun-metal/pi-zero-w-v1_1/erzw-${NODE_INDEX}"
BOOT_DIR="${NODE_BUILD_DIR}/boot"
MANIFEST="${BOOT_DIR}/EDGERUN-PI-ZERO-W-V1_1-BOOT.txt"
DEFAULT_LOG="${ROOT_DIR}/.build/pi-zero-w-v1_1/erzw-${NODE_INDEX}/serial.bin"
USB_BOOT_TOOL="${PI_USB_BOOT_TOOL:-${ROOT_DIR}/.build/pi-usb-boot}"
LSUSB_FILE="${PI_USB_BOOT_LSUSB_FILE:-}"
USB_RESET_DEVICE="${PI_USB_RESET_DEVICE:-0000:c3:00.4}"
USB_RESET_CMD="${PI_USB_RESET_CMD:-}"
SERIAL_DEVICE="${PI_SERIAL_DEVICE:-}"
USB_DEVICE="${PI_USB_DEVICE:-}"
SERIAL_LOG="$DEFAULT_LOG"
CAPTURE_SECONDS="${PI_CAPTURE_SECONDS:-20}"
SKIP_USB=0
VERIFY_ONLY=0
DRY_RUN=0
USB_RESET_DONE=0

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

case "$NODE_INDEX" in
  0|1|2|3|4|5)
    ;;
  *)
    fail "node index must be 0, 1, 2, 3, 4, or 5"
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

read_broadcom_boot_nodes() {
  if [ "$LSUSB_FILE" != "" ]; then
    cat "$LSUSB_FILE"
  else
    lsusb -d 0a5c:2763 || true
  fi
}

pick_usb_device() {
  count=0
  chosen=''
  while IFS= read -r line; do
    set -- $line
    if [ "${1:-}" != "Bus" ] || [ "${3:-}" != "Device" ]; then
      continue
    fi
    bus="$2"
    device="${4:-}"
    device="${device%:}"
    case "$bus:$device" in
      *[!0-9:]*|:|*:|:*)
        continue
        ;;
    esac
    count=$((count + 1))
    chosen="/dev/bus/usb/$bus/$device"
  done <<EOF_USB_NODES
$(read_broadcom_boot_nodes)
EOF_USB_NODES
  if [ "$count" -eq 1 ]; then
    USB_DEVICE="$chosen"
  elif [ "$count" -gt 1 ]; then
    fail "more than one Pi boot device is attached; unplug the extra board and run make pi-ready again"
  fi
}

repair_usb_device_owner() {
  [ "$USB_DEVICE" != "" ] || return 0
  [ -e "$USB_DEVICE" ] || return 0
  if [ ! -r "$USB_DEVICE" ] || [ ! -w "$USB_DEVICE" ]; then
    say "Preparing the Pi USB boot cable."
    sudo chown "$(id -u):$(id -g)" "$USB_DEVICE"
  fi
}

reset_pi_usb_station() {
  say "Resetting the Pi USB station."
  if [ "$USB_RESET_CMD" != "" ]; then
    "$USB_RESET_CMD" "$USB_RESET_DEVICE"
  else
    sudo sh -c "echo $USB_RESET_DEVICE > /sys/bus/pci/drivers/xhci_hcd/unbind; sleep 3; echo $USB_RESET_DEVICE > /sys/bus/pci/drivers/xhci_hcd/bind"
  fi
  USB_RESET_DONE=1
  USB_DEVICE=''
  pick_usb_device
  repair_usb_device_owner
}

build_needed_files() {
  say "Preparing the board image."
  make -C "$ROOT_DIR/edgerun-metal" pi-zero-w-v1_1-boot \
    PI_ZERO_W_V1_1_NODE_INDEX="$NODE_INDEX" \
    PI_ZERO_W_V1_1_BUILD_DIR="$NODE_BUILD_DIR_FOR_MAKE" >/dev/null
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
  "$USB_BOOT_TOOL" $usb_args >/tmp/pi-zero-w-v1_1-usb.out 2>/tmp/pi-zero-w-v1_1-usb.err
}

run_usb_boot_with_recovery() {
  if run_usb_boot; then
    return 0
  fi
  if [ "$DRY_RUN" -ne 0 ] || [ "$USB_RESET_DONE" -ne 0 ]; then
    fail "the board did not accept boot files; unplug it, hold BOOT, plug it back in, then run make pi-ready again"
  fi
  reset_pi_usb_station
  if run_usb_boot; then
    return 0
  fi
  fail "the board still did not accept boot files after the USB station reset; unplug it, hold BOOT, plug it back in, then run make pi-ready again"
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

if [ "$USB_DEVICE" = "" ] && [ "$SKIP_USB" -eq 0 ]; then
  pick_usb_device
fi

if [ "$SKIP_USB" -eq 0 ]; then
  repair_usb_device_owner
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
  run_usb_boot_with_recovery
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
  say "Boot files sent. Attach the small serial cable and run make pi-ready again."
fi
