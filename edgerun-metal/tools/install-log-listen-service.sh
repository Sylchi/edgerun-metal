#!/usr/bin/env bash
set -euo pipefail

# Purpose:
#   Install the EdgeRun Metal UDP log listener as an always-on systemd service.
# Intention:
#   Keep hardware boot logs capturable without changing netboot or firmware code.

if [ "$(id -u)" -ne 0 ]; then
  echo "please run this script with sudo"
  exit 1
fi

SERVICE_NAME="edgerun-log-listen"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_DIR="/opt/edgerun-metal"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

if [ -L "${INSTALL_DIR}" ]; then
  ln -sfn "${REPO_DIR}" "${INSTALL_DIR}"
elif [ -e "${INSTALL_DIR}" ]; then
  echo "/opt/edgerun-metal exists and is not a symlink"
  echo "remove it manually to allow symlink install"
  exit 1
else
  ln -s "${REPO_DIR}" "${INSTALL_DIR}"
fi

cp "${REPO_DIR}/systemd/${SERVICE_NAME}.service" "${SERVICE_FILE}"
chmod 0644 "${SERVICE_FILE}"

systemctl daemon-reload
systemctl enable --now "${SERVICE_NAME}.service"

echo "installed: ${SERVICE_NAME}"
echo "service: ${SERVICE_FILE}"
echo "logs:    journalctl -u ${SERVICE_NAME} -f"
