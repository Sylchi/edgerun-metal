#!/usr/bin/env bash
set -euo pipefail

# Purpose:
#   Remove the EdgeRun Metal UDP log listener systemd service.
# Intention:
#   Stop the always-on listener without disturbing shared /opt/edgerun-metal installs.

if [ "$(id -u)" -ne 0 ]; then
  echo "please run this script with sudo"
  exit 1
fi

SERVICE_NAME="edgerun-log-listen"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

systemctl disable --now "${SERVICE_NAME}.service" || true
systemctl stop "${SERVICE_NAME}.service" || true
rm -f "${SERVICE_FILE}"
systemctl daemon-reload

echo "uninstalled ${SERVICE_NAME}"
echo "service removed"
