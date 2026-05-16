#!/usr/bin/env bash
set -euo pipefail

if [ "${1:-}" = "" ]; then
  echo "usage: $0 <interface>"
  exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "please run this script with sudo"
  exit 1
fi

IFACE="$1"
FORCE="${FORCE:-0}"
SERVICE_NAME="edgerun-netboot"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="/opt/edgerun-metal"
ENV_FILE="/etc/edgerun-netboot.env"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
NETBOOT_MODE="${EDGERUN_NETBOOT_MODE:-auto}"
HTTP_PORT="${EDGERUN_NETBOOT_HTTP_PORT:-8081}"
MGMT_DHCP="${EDGERUN_NETBOOT_MGMT_DHCP:-0}"
MGMT_IP="${EDGERUN_NETBOOT_MGMT_IP:-10.42.0.10}"
MGMT_MAC="${EDGERUN_NETBOOT_MGMT_MAC:-}"
ALLOW_MAC="${EDGERUN_NETBOOT_ALLOW_MAC:-}"
CLIENT_IP="${EDGERUN_NETBOOT_CLIENT_IP:-10.42.0.2}"
FORCE_HTTP_FOR_PXE="${EDGERUN_NETBOOT_FORCE_HTTP_FOR_PXE:-0}"

if [ -n "${IFACE}" ]; then
  echo "selected interface: ${IFACE}"
fi
if [ "${FORCE}" != "1" ]; then
  read -r -p "Install netboot service for ${IFACE}? [y/N] " answer
  case "${answer}" in
    [yY]|[yY][eE][sS])
      ;;
    *)
      echo "aborted"
      exit 1
      ;;
  esac
fi

cd "${REPO_DIR}"
make
make netboot

if [ -L "${INSTALL_DIR}" ]; then
  ln -sfn "${REPO_DIR}" "${INSTALL_DIR}"
elif [ -e "${INSTALL_DIR}" ]; then
  echo "/opt/edgerun-metal exists and is not a symlink"
  echo "remove it manually to allow symlink install"
  exit 1
else
  ln -s "${REPO_DIR}" "${INSTALL_DIR}"
fi

cat > "${ENV_FILE}" <<EOF
EDGERUN_NETBOOT_IFACE=${IFACE}
EDGERUN_NETBOOT_EFI=${INSTALL_DIR}/build/esp/EFI/BOOT/BOOTX64.EFI
EDGERUN_NETBOOT_MODE=${NETBOOT_MODE}
EDGERUN_NETBOOT_HTTP_PORT=${HTTP_PORT}
EDGERUN_NETBOOT_MGMT_DHCP=${MGMT_DHCP}
EDGERUN_NETBOOT_MGMT_MAC=${MGMT_MAC}
EDGERUN_NETBOOT_MGMT_IP=${MGMT_IP}
EDGERUN_NETBOOT_ALLOW_MAC=${ALLOW_MAC}
EDGERUN_NETBOOT_CLIENT_IP=${CLIENT_IP}
EDGERUN_NETBOOT_FORCE_HTTP_FOR_PXE=${FORCE_HTTP_FOR_PXE}
EOF
chmod 0644 "${ENV_FILE}"

cp "${REPO_DIR}/systemd/edgerun-netboot.service" "${SERVICE_FILE}"
cp "${REPO_DIR}/systemd/edgerun-netboot.env.example" "${ENV_FILE}.example"
chmod 0644 "${ENV_FILE}.example"

if command -v nmcli >/dev/null 2>&1; then
  nmcli dev set "${IFACE}" managed no || true
fi

systemctl daemon-reload
systemctl enable --now "${SERVICE_NAME}.service"

echo "installed: ${SERVICE_NAME}"
echo "service: ${SERVICE_FILE}"
echo "env:    ${ENV_FILE}"
echo "interface: ${IFACE}"
