#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "please run this script with sudo"
  exit 1
fi

SERVICE_NAME="edgerun-netboot"
INSTALL_DIR="/opt/edgerun-metal"
ENV_FILE="/etc/edgerun-netboot.env"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

systemctl disable --now "${SERVICE_NAME}.service" || true
systemctl stop "${SERVICE_NAME}.service" || true
rm -f "${SERVICE_FILE}" "${ENV_FILE}" "${ENV_FILE}.example"
systemctl daemon-reload

if [ -L "${INSTALL_DIR}" ]; then
  rm -f "${INSTALL_DIR}"
fi

echo "uninstalled ${SERVICE_NAME}"
echo "service and env removed"
