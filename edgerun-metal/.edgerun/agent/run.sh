#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUTPUT_DIR="${EDGERUN_AGENT_OUTPUT_DIR:-${REPO_DIR}/agent-output/latest}"
RUN_LOG="${OUTPUT_DIR}/run.log"
JOB_FILE="${REPO_DIR}/.edgerun/agent/jobs/current.env"
JOB_RUNNER="${SCRIPT_DIR}/job-runner.sh"
COLLECT_SCRIPT="${SCRIPT_DIR}/collect.sh"

mkdir -p "${OUTPUT_DIR}"

log() {
  printf '%s\n' "$1" >>"${RUN_LOG}"
}

log_step() {
  local label="$1"
  local rc=0
  shift
  if "$@"; then
    log "${label}: ok"
  else
    rc=$?
    log "${label}: fail rc=${rc}"
  fi
  return ${rc}
}

{
  echo "[agent] starting run at $(date -Is)"
  echo "[agent] repo: ${REPO_DIR}"
} >"${RUN_LOG}"

build_rc=0
if ! (
  cd "${REPO_DIR}"
  log_step "[agent] run: make" make
); then
  build_rc=1
fi
if ! (
  cd "${REPO_DIR}"
  log_step "[agent] run: make netboot" make netboot
); then
  build_rc=1
fi

job_id="none"
job_action="noop"
job_result="no-op"
if [ -f "${JOB_FILE}" ]; then
  if ! log_step "[agent] run: job runner" "${JOB_RUNNER}" "${JOB_FILE}" "${OUTPUT_DIR}"; then
    build_rc=1
  fi
  if [ -f "${OUTPUT_DIR}/job-id.txt" ]; then
    job_id="$(cat "${OUTPUT_DIR}/job-id.txt")"
  fi
  if [ -f "${OUTPUT_DIR}/job-action.txt" ]; then
    job_action="$(cat "${OUTPUT_DIR}/job-action.txt")"
  fi
  if [ -f "${OUTPUT_DIR}/job-result.txt" ]; then
    job_result="$(cat "${OUTPUT_DIR}/job-result.txt")"
  fi
fi

{
  echo "[agent] job id=${job_id}"
  echo "[agent] job action=${job_action}"
  echo "[agent] job result=${job_result}"
  echo "[agent] build_rc=${build_rc}"
} >>"${RUN_LOG}"

collect_rc=0
if [ -x "${COLLECT_SCRIPT}" ]; then
  log_step "[agent] run: collect" "${COLLECT_SCRIPT}" "${OUTPUT_DIR}" || collect_rc=1
else
  log "[agent] collect script missing: ${COLLECT_SCRIPT}"
  collect_rc=1
fi

if [ "${collect_rc}" -ne 0 ]; then
  build_rc=1
fi

exit "${build_rc}"
