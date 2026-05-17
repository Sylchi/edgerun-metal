#!/usr/bin/env bash
set -euo pipefail

BUILD_DIR="$(cd "$(dirname "$0")/.." && pwd)/build"
ESP_DIR="${BUILD_DIR}/esp"
QEMU_WIDTH="${QEMU_WIDTH:-1920}"
QEMU_HEIGHT="${QEMU_HEIGHT:-1080}"
QEMU_REFRESH="${QEMU_REFRESH:-60}"
if [[ -z "${OVMF_CODE:-}" ]]; then
  for candidate in \
    "/usr/share/OVMF/OVMF_CODE.fd" \
    "/usr/share/ovmf/OVMF_CODE.fd" \
    "/usr/share/edk2-ovmf/x64/OVMF_CODE.fd" \
    "/usr/share/edk2-ovmf/OVMF_CODE.4m.fd" \
    "/usr/share/edk2/x64/OVMF_CODE.4m.fd" \
    "/usr/share/qemu/firmware/OVMF_CODE.4m.fd"
  do
    if [[ -f "$candidate" ]]; then
      OVMF_CODE="$candidate"
      break
    fi
  done
fi

if [[ -z "${OVMF_VARS:-}" ]]; then
  for candidate in \
    "/usr/share/OVMF/OVMF_VARS.fd" \
    "/usr/share/ovmf/OVMF_VARS.fd" \
    "/usr/share/edk2-ovmf/x64/OVMF_VARS.fd" \
    "/usr/share/edk2-ovmf/OVMF_VARS.4m.fd" \
    "/usr/share/edk2/x64/OVMF_VARS.4m.fd" \
    "/usr/share/qemu/firmware/OVMF_VARS.4m.fd"
  do
    if [[ -f "$candidate" ]]; then
      OVMF_VARS="$candidate"
      break
    fi
  done
fi

if [[ ! -f "${OVMF_CODE}" ]]; then
  echo "OVMF binary not found. Install edk2-ovmf and set OVMF_CODE/OVMF_VARS." >&2
  exit 1
fi

if [[ ! -f "${OVMF_VARS}" ]]; then
  echo "OVMF vars file not found: ${OVMF_VARS}" >&2
  exit 1
fi

OVMF_VARS_WRITABLE="$(mktemp /tmp/edgerun-ovmf-vars.XXXXXX.fd)"
cp "${OVMF_VARS}" "${OVMF_VARS_WRITABLE}"
trap 'rm -f "${OVMF_VARS_WRITABLE}"' EXIT

if [[ ! -f "${ESP_DIR}/EFI/BOOT/BOOTX64.EFI" ]]; then
  echo "Missing ${ESP_DIR}/EFI/BOOT/BOOTX64.EFI. Run make first." >&2
  exit 1
fi

qemu-system-x86_64 \
  -m 1024 \
  -vga none \
  -device "VGA,xres=${QEMU_WIDTH},yres=${QEMU_HEIGHT},refresh_rate=${QEMU_REFRESH}" \
  -drive if=pflash,format=raw,readonly=on,file="${OVMF_CODE}" \
  -drive if=pflash,format=raw,file="${OVMF_VARS_WRITABLE}" \
  -drive format=raw,file=fat:rw:"${ESP_DIR}",media=disk \
  -serial mon:stdio
