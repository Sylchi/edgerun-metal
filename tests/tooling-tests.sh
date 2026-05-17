#!/usr/bin/env bash
set -euo pipefail

# Purpose:
#   Validate repository-wide operational tooling entrypoints.
# Intention:
#   Keep always-on hardware support commands present, executable, and routed through one implementation.

readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly ROOT_DIR="$(dirname "${SCRIPT_DIR}")"

fail() {
  printf 'tooling-tests: %s\n' "$1" >&2
  exit 1
}

check_executable() {
  local path="$1"

  if [ ! -x "${ROOT_DIR}/${path}" ]; then
    fail "${path} must exist and be executable"
  fi
}

check_executable tools/edgerun-log-listen.sh
check_executable edgerun-metal/tools/edgerun-log-listen.sh
check_executable edgerun-metal/tools/install-log-listen-service.sh
check_executable edgerun-metal/tools/uninstall-log-listen-service.sh

grep -q 'edgerun-metal/tools/edgerun-log-listen.sh' "${ROOT_DIR}/tools/edgerun-log-listen.sh" ||
  fail 'root log listener must delegate to the edgerun-metal listener'

grep -q '^log-listen:' "${ROOT_DIR}/Makefile" ||
  fail 'root Makefile must expose log-listen'

grep -q 'ExecStart=/opt/edgerun-metal/tools/edgerun-log-listen.sh' "${ROOT_DIR}/edgerun-metal/systemd/edgerun-log-listen.service" ||
  fail 'systemd listener service must be tracked'

printf 'tooling tests passed\n'
