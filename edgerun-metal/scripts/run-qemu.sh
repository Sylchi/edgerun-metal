#!/usr/bin/env bash
set -euo pipefail

BUILD_DIR="$(cd "$(dirname "$0")/.." && pwd)/build"
ESP_DIR="${BUILD_DIR}/esp"
QEMU_WIDTH="${QEMU_WIDTH:-1280}"
QEMU_HEIGHT="${QEMU_HEIGHT:-720}"
QEMU_REFRESH="${QEMU_REFRESH:-60}"
QEMU_NATIVE="${QEMU_NATIVE:-0}"
QEMU_TPM="${QEMU_TPM:-0}"
QEMU_VIRTIO_GPU="${QEMU_VIRTIO_GPU:-0}"
QEMU_TPM_PERSIST_STATE="${QEMU_TPM_PERSIST_STATE:-0}"
QEMU_CAPTURE="${QEMU_CAPTURE:-${BUILD_DIR}/native-erwire.pcap}"
QEMU_TPM_STATE_DIR="${QEMU_TPM_STATE_DIR:-${BUILD_DIR}/swtpm-state}"
QEMU_TPM_SOCKET="${QEMU_TPM_SOCKET:-${BUILD_DIR}/swtpm.sock}"
QEMU_TPM_PIDFILE="${QEMU_TPM_PIDFILE:-${BUILD_DIR}/swtpm.pid}"
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
TPM_PID=""
TPM_STATE_OWNED=""
cleanup() {
  if [[ -n "${TPM_PID}" ]]; then
    kill "${TPM_PID}" 2>/dev/null || true
  fi
  rm -f "${OVMF_VARS_WRITABLE}" "${QEMU_TPM_SOCKET}" "${QEMU_TPM_PIDFILE}"
  if [[ -n "${TPM_STATE_OWNED}" ]]; then
    rm -rf "${QEMU_TPM_STATE_DIR}"
  fi
}
trap cleanup EXIT

if [[ ! -f "${ESP_DIR}/EFI/BOOT/BOOTX64.EFI" ]]; then
  echo "Missing ${ESP_DIR}/EFI/BOOT/BOOTX64.EFI. Run make first." >&2
  exit 1
fi

QEMU_TPM_ARGS=()
if [[ "${QEMU_TPM}" == "1" ]]; then
  TPM_WAIT=0
  if [[ "${QEMU_TPM_PERSIST_STATE}" != "1" ]]; then
    QEMU_TPM_STATE_DIR="$(mktemp -d /tmp/edgerun-swtpm-state.XXXXXX)"
    TPM_STATE_OWNED=1
  fi
  mkdir -p "${QEMU_TPM_STATE_DIR}" "$(dirname "${QEMU_TPM_SOCKET}")"
  rm -f "${QEMU_TPM_SOCKET}" "${QEMU_TPM_PIDFILE}"
  swtpm socket \
    --tpm2 \
    --tpmstate "dir=${QEMU_TPM_STATE_DIR}" \
    --ctrl "type=unixio,path=${QEMU_TPM_SOCKET}" \
    --pid "file=${QEMU_TPM_PIDFILE}" \
    --daemon
  TPM_PID="$(cat "${QEMU_TPM_PIDFILE}" 2>/dev/null || true)"
  while [[ "${TPM_WAIT}" -lt 50 ]]; do
    if [[ -S "${QEMU_TPM_SOCKET}" ]]; then
      break
    fi
    TPM_WAIT=$((TPM_WAIT + 1))
    sleep 0.1
  done
  if [[ ! -S "${QEMU_TPM_SOCKET}" ]]; then
    echo "swtpm socket did not become ready: ${QEMU_TPM_SOCKET}" >&2
    exit 1
  fi
  QEMU_TPM_ARGS=(
    -chardev "socket,id=chrtpm,path=${QEMU_TPM_SOCKET}"
    -tpmdev "emulator,id=tpm0,chardev=chrtpm"
    -device "tpm-crb,tpmdev=tpm0"
  )
fi

QEMU_DISPLAY_ARGS=()
if [[ "${QEMU_VIRTIO_GPU}" == "1" ]]; then
  QEMU_DISPLAY_ARGS=(
    -vga none
    -device "virtio-vga,disable-legacy=on,xres=${QEMU_WIDTH},yres=${QEMU_HEIGHT}"
  )
else
  QEMU_DISPLAY_ARGS=(
    -vga none
    -device "VGA,xres=${QEMU_WIDTH},yres=${QEMU_HEIGHT},refresh_rate=${QEMU_REFRESH}"
  )
fi

if [[ "${QEMU_NATIVE}" == "1" ]]; then
  mkdir -p "$(dirname "${QEMU_CAPTURE}")"
  rm -f "${QEMU_CAPTURE}"
  qemu-system-x86_64 \
    -m 1024 \
    "${QEMU_DISPLAY_ARGS[@]}" \
    -drive if=pflash,format=raw,readonly=on,file="${OVMF_CODE}" \
    -drive if=pflash,format=raw,file="${OVMF_VARS_WRITABLE}" \
    -drive format=raw,file=fat:rw:"${ESP_DIR}",media=disk \
    -netdev user,id=edgerun0 \
    -device virtio-net-pci,netdev=edgerun0,mac=02:21:22:23:24:25,disable-legacy=on \
    -object "filter-dump,id=edgerun-native-dump,netdev=edgerun0,file=${QEMU_CAPTURE}" \
    "${QEMU_TPM_ARGS[@]}" \
    -serial mon:stdio
  exit 0
fi

qemu-system-x86_64 \
  -m 1024 \
  "${QEMU_DISPLAY_ARGS[@]}" \
  -drive if=pflash,format=raw,readonly=on,file="${OVMF_CODE}" \
  -drive if=pflash,format=raw,file="${OVMF_VARS_WRITABLE}" \
  -drive format=raw,file=fat:rw:"${ESP_DIR}",media=disk \
  "${QEMU_TPM_ARGS[@]}" \
  -serial mon:stdio
