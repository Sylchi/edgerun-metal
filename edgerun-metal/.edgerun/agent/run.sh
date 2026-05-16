#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUTPUT_DIR="${EDGERUN_AGENT_OUTPUT_DIR:-${REPO_DIR}/agent-output/latest}"
COLLECT_SCRIPT="${SCRIPT_DIR}/collect.sh"

mkdir -p "${OUTPUT_DIR}"

{
  echo "[agent] starting build pipeline at $(date -Is)"
  echo "[agent] repo: ${REPO_DIR}"
} | tee -a "${OUTPUT_DIR}/run.log"

cd "${REPO_DIR}"

echo "[agent] running make" | tee -a "${OUTPUT_DIR}/run.log"
make >>"${OUTPUT_DIR}/run.log" 2>&1

echo "[agent] running make netboot" | tee -a "${OUTPUT_DIR}/run.log"
make netboot >>"${OUTPUT_DIR}/run.log" 2>&1

if [ -x "${COLLECT_SCRIPT}" ]; then
  set +e
  "${COLLECT_SCRIPT}" "${OUTPUT_DIR}" >>"${OUTPUT_DIR}/run.log" 2>&1
  collect_rc=$?
  set -e
  echo "[agent] collect rc=${collect_rc}" | tee -a "${OUTPUT_DIR}/run.log"
else
  echo "[agent] collect script missing: ${COLLECT_SCRIPT}" | tee -a "${OUTPUT_DIR}/run.log"
  exit 1
fi
