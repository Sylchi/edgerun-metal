#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "please run this script with sudo"
  exit 1
fi

SERVICE_NAME="edgerun-agent"
SYSTEMD_DIR="/etc/systemd/system"
SERVICE_FILE="${SYSTEMD_DIR}/${SERVICE_NAME}.service"
TIMER_FILE="${SYSTEMD_DIR}/${SERVICE_NAME}.timer"
ENV_FILE="/etc/edgerun-agent.env"

systemctl disable --now "${SERVICE_NAME}.timer" || true
systemctl stop "${SERVICE_NAME}.service" || true
systemctl disable --now "${SERVICE_NAME}.service" || true

rm -f "${TIMER_FILE}" "${SERVICE_FILE}" "${ENV_FILE}" "${ENV_FILE}.example"
systemctl daemon-reload
echo "uninstalled ${SERVICE_NAME}"
