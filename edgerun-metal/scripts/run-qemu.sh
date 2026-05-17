#!/usr/bin/env bash
set -euo pipefail

BUILD_DIR="$(cd "$(dirname "$0")/.." && pwd)/build"
ESP_DIR="${BUILD_DIR}/esp"
QEMU_WIDTH="${QEMU_WIDTH:-1280}"
QEMU_HEIGHT="${QEMU_HEIGHT:-720}"
QEMU_REFRESH="${QEMU_REFRESH:-60}"
QEMU_NATIVE="${QEMU_NATIVE:-0}"
QEMU_CAPTURE="${QEMU_CAPTURE:-${BUILD_DIR}/native-erwire.pcap}"
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

if [[ -z "${OVMF_NATIVE_FIRMWARE:-}" ]]; then
  for candidate in \
    "/usr/share/edk2/x64/OVMF.4m.fd" \
    "/usr/share/edk2-ovmf/x64/OVMF.fd" \
    "/usr/share/OVMF/OVMF.fd" \
    "/usr/share/ovmf/OVMF.fd"
  do
    if [[ -f "$candidate" ]]; then
      OVMF_NATIVE_FIRMWARE="$candidate"
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

if [[ "${QEMU_NATIVE}" == "1" ]]; then
  if [[ ! -f "${OVMF_NATIVE_FIRMWARE}" ]]; then
    echo "Combined OVMF firmware not found. Set OVMF_NATIVE_FIRMWARE for microvm native mode." >&2
    exit 1
  fi
  mkdir -p "$(dirname "${QEMU_CAPTURE}")"
  rm -f "${QEMU_CAPTURE}"
  qemu-system-x86_64 \
    -m 1024 \
    -nodefaults \
    -machine "microvm,acpi=on,pcie=off,graphics=on" \
    -bios "${OVMF_NATIVE_FIRMWARE}" \
    -drive if=none,id=edgerun-esp,format=raw,file=fat:rw:"${ESP_DIR}" \
    -device virtio-blk-device,drive=edgerun-esp \
    -netdev user,id=edgerun0 \
    -device virtio-net-device,netdev=edgerun0,mac=02:21:22:23:24:25 \
    -object "filter-dump,id=edgerun-native-dump,netdev=edgerun0,file=${QEMU_CAPTURE}" \
    -serial mon:stdio
  exit 0
fi

qemu-system-x86_64 \
  -m 1024 \
  -vga none \
  -device "VGA,xres=${QEMU_WIDTH},yres=${QEMU_HEIGHT},refresh_rate=${QEMU_REFRESH}" \
  -drive if=pflash,format=raw,readonly=on,file="${OVMF_CODE}" \
  -drive if=pflash,format=raw,file="${OVMF_VARS_WRITABLE}" \
  -drive format=raw,file=fat:rw:"${ESP_DIR}",media=disk \
  -serial mon:stdio
