#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "please run this script with sudo"
  exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ENV_FILE="/etc/edgerun-agent.env"
SERVICE_NAME="edgerun-agent"
SYSTEMD_DIR="/etc/systemd/system"
SERVICE_FILE="${SYSTEMD_DIR}/${SERVICE_NAME}.service"
TIMER_FILE="${SYSTEMD_DIR}/${SERVICE_NAME}.timer"

if ! git -C "${REPO_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "repo path not valid: ${REPO_DIR}"
  exit 1
fi

echo "repo path: ${REPO_DIR}"
if [ ! -L /opt/edgerun-metal ] && [ ! -d /opt/edgerun-metal ]; then
  ln -s "${REPO_DIR}" /opt/edgerun-metal
elif [ -L /opt/edgerun-metal ]; then
  ln -sfn "${REPO_DIR}" /opt/edgerun-metal
else
  echo "/opt/edgerun-metal exists and is not a symlink; service uses /opt/edgerun-metal"
fi

if [ ! -f "${ENV_FILE}" ]; then
  echo "creating default ${ENV_FILE}"
  cat > "${ENV_FILE}" <<EOF
EDGERUN_AGENT_REPO=${REPO_DIR}
EDGERUN_AGENT_REMOTE=origin
EDGERUN_AGENT_SOURCE_BRANCH=main
EDGERUN_AGENT_OUTPUT_BRANCH=agent/fw
EDGERUN_AGENT_HOSTNAME=fw
EDGERUN_AGENT_INTERVAL_SEC=60
EDGERUN_AGENT_RUN_SCRIPT=.edgerun/agent/run.sh
EDGERUN_AGENT_OUTPUT_WORKTREE=/tmp/edgerun-agent-output-worktree
EOF
fi

echo "installing ${SERVICE_NAME}"
cp "${REPO_DIR}/systemd/edgerun-agent.service" "${SERVICE_FILE}"
cp "${REPO_DIR}/systemd/edgerun-agent.timer" "${TIMER_FILE}"
cp "${REPO_DIR}/systemd/edgerun-agent.env.example" "${ENV_FILE}.example"

systemctl daemon-reload
systemctl enable --now "${SERVICE_NAME}.timer"
systemctl start "${SERVICE_NAME}.service"

echo
echo "service status:"
systemctl status "${SERVICE_NAME}.timer" --no-pager
echo
echo "recent service log:"
journalctl -u "${SERVICE_NAME}.service" -n 100 --no-pager
