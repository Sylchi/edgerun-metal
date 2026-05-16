#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO_NAME="$(basename "${REPO_DIR}")"

if [ -z "${REPO_DIR}" ] || [ ! -d "${REPO_DIR}" ]; then
  echo "invalid repo path: ${REPO_DIR}"
  exit 1
fi

if ! git -C "${REPO_DIR}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "not a git repository: ${REPO_DIR}"
  exit 1
fi

USER_NAME="${SUDO_USER:-${USER}}"
if [ "${USER_NAME}" = "root" ] && [ -n "${SUDO_USER:-}" ]; then
  USER_NAME="${SUDO_USER}"
fi
USER_HOME="$(getent passwd "${USER_NAME}" | cut -d: -f6)"
if [ -z "${USER_HOME}" ] || [ ! -d "${USER_HOME}" ]; then
  echo "invalid user home for ${USER_NAME}: ${USER_HOME}"
  exit 1
fi

echo "repo path: ${REPO_DIR}"
echo "installing for user: ${USER_NAME}"

ENV_FILE="/etc/edgerun-agent.env"
if [ ! -f "${ENV_FILE}" ]; then
  if [ -w "${ENV_FILE%/*}" ]; then
    echo "creating default ${ENV_FILE}"
    cat >"${ENV_FILE}" <<EOF
EDGERUN_AGENT_REPO=${REPO_DIR}
EDGERUN_AGENT_REMOTE=origin
EDGERUN_AGENT_SOURCE_BRANCH=main
EDGERUN_AGENT_OUTPUT_BRANCH=agent/fw
EDGERUN_AGENT_HOSTNAME=fw
EDGERUN_AGENT_INTERVAL_SEC=60
EDGERUN_AGENT_RUN_SCRIPT=.edgerun/agent/run.sh
EDGERUN_AGENT_OUTPUT_WORKTREE=/tmp/edgerun-agent-output-worktree
EOF
  else
    USER_ENV_DIR="${USER_HOME}/.config/edgerun-agent"
    mkdir -p "${USER_ENV_DIR}"
    ENV_FILE="${USER_ENV_DIR}/edgerun-agent.env"
    if [ ! -f "${ENV_FILE}" ]; then
      echo "creating default ${ENV_FILE}"
      cat >"${ENV_FILE}" <<EOF
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
  fi
fi

TARGET_DIR="${USER_HOME}/.config/systemd/user"
mkdir -p "${TARGET_DIR}"
cat >"${TARGET_DIR}/edgerun-agent.service" <<EOF
[Unit]
Description=EdgeRun development agent
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
EnvironmentFile=${ENV_FILE}
Environment=EDGERUN_AGENT_OUTPUT_WORKTREE=/tmp/edgerun-agent-output-worktree-${USER_NAME}
WorkingDirectory=/opt/edgerun-metal
ExecStart=/opt/edgerun-metal/tools/edgerun-agent/edgerun-agent.sh

[Install]
WantedBy=default.target
EOF

cat >"${TARGET_DIR}/edgerun-agent.timer" <<EOF
[Unit]
Description=Run EdgeRun agent periodically

[Timer]
OnBootSec=30
OnUnitActiveSec=${EDGERUN_AGENT_INTERVAL_SEC:-60}
AccuracySec=5
Persistent=true
Unit=edgerun-agent.service

[Install]
WantedBy=timers.target
EOF

chown -R "${USER_NAME}:${USER_NAME}" "${TARGET_DIR}"
chmod 644 "${TARGET_DIR}/edgerun-agent.service" "${TARGET_DIR}/edgerun-agent.timer"

if ! command -v loginctl >/dev/null 2>&1 || ! loginctl show-user "${USER_NAME}" --property=State --value >/dev/null 2>&1; then
  echo "warning: unable to confirm linger/user bus state for ${USER_NAME}"
else
  loginctl enable-linger "${USER_NAME}" || true
fi

if [ "${USER_NAME}" = "${USER}" ]; then
  systemctl --user daemon-reload
  systemctl --user enable --now edgerun-agent.timer
  systemctl --user start edgerun-agent.service
else
  runuser -l "${USER_NAME}" -c 'systemctl --user daemon-reload'
  runuser -l "${USER_NAME}" -c 'systemctl --user enable --now edgerun-agent.timer'
  runuser -l "${USER_NAME}" -c 'systemctl --user start edgerun-agent.service'
fi

echo
echo "service status:"
if [ "${USER_NAME}" = "${USER}" ]; then
  systemctl --user status edgerun-agent.timer --no-pager
  echo
  echo "recent service log:"
  journalctl --user -u edgerun-agent.service -n 100 --no-pager
else
  runuser -l "${USER_NAME}" -c 'systemctl --user status edgerun-agent.timer --no-pager'
  echo
  echo "recent service log:"
  runuser -l "${USER_NAME}" -c 'journalctl --user -u edgerun-agent.service -n 100 --no-pager'
fi
