#!/usr/bin/env bash
set -euo pipefail

USER_NAME="${SUDO_USER:-${USER}}"
if [ "${USER_NAME}" = "root" ] && [ -n "${SUDO_USER:-}" ]; then
  USER_NAME="${SUDO_USER}"
fi
USER_HOME="$(getent passwd "${USER_NAME}" | cut -d: -f6)"
if [ -z "${USER_HOME}" ] || [ ! -d "${USER_HOME}" ]; then
  echo "invalid user home for ${USER_NAME}: ${USER_HOME}"
  exit 1
fi

TARGET_DIR="${USER_HOME}/.config/systemd/user"
if [ "${USER_NAME}" = "${USER}" ]; then
  systemctl --user disable --now edgerun-agent.timer || true
  systemctl --user stop edgerun-agent.service || true
else
  runuser -l "${USER_NAME}" -c 'systemctl --user disable --now edgerun-agent.timer' || true
  runuser -l "${USER_NAME}" -c 'systemctl --user stop edgerun-agent.service' || true
fi

rm -f "${TARGET_DIR}/edgerun-agent.service" "${TARGET_DIR}/edgerun-agent.timer" || true

if [ "${USER_NAME}" = "${USER}" ]; then
  systemctl --user daemon-reload || true
else
  runuser -l "${USER_NAME}" -c 'systemctl --user daemon-reload' || true
fi
echo "uninstalled user service for ${USER_NAME}"
