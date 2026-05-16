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

patch_netboot_dhcp_ipv4_options() {
  local file="${REPO_DIR}/tools/edgerun-netboot/main.c"

  if [ ! -f "${file}" ]; then
    log "[agent] DHCP patch: source missing: ${file}"
    return 0
  fi
  if grep -q 'dhcp_append_ipv4' "${file}"; then
    log "[agent] DHCP patch: already present"
    return 0
  fi
  if ! command -v python3 >/dev/null 2>&1; then
    log "[agent] DHCP patch: python3 missing"
    return 1
  fi

  log "[agent] DHCP patch: applying IPv4 option byte-order fix"
  python3 - "$file" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
s = path.read_text()
old = '''static size_t dhcp_append_u32(uint8_t *p, uint8_t code, uint32_t v_host) {
    uint32_t v = htonl(v_host);
    p[0] = code;
    p[1] = 4;
    memcpy(p + 2, &v, 4);
    return 6;
}
'''
new = '''static size_t dhcp_append_u32(uint8_t *p, uint8_t code, uint32_t v_host) {
    uint32_t v = htonl(v_host);
    p[0] = code;
    p[1] = 4;
    memcpy(p + 2, &v, 4);
    return 6;
}

static size_t dhcp_append_ipv4(uint8_t *p, uint8_t code, const char *ip) {
    struct in_addr addr;
    if (inet_pton(AF_INET, ip, &addr) != 1) {
        addr.s_addr = 0u;
    }
    p[0] = code;
    p[1] = 4;
    memcpy(p + 2, &addr.s_addr, 4);
    return 6;
}
'''
if old not in s:
    raise SystemExit('expected dhcp_append_u32 block not found')
s = s.replace(old, new, 1)
s = s.replace('p += dhcp_append_u32(p, DHCP_OPT_SERVER_ID, inet_addr(SERVER_IP));', 'p += dhcp_append_ipv4(p, DHCP_OPT_SERVER_ID, SERVER_IP);')
s = s.replace('p += dhcp_append_u32(p, DHCP_OPT_SUBNET_MASK, inet_addr(SUBNET_MASK));', 'p += dhcp_append_ipv4(p, DHCP_OPT_SUBNET_MASK, SUBNET_MASK);')
s = s.replace('p += dhcp_append_u32(p, DHCP_OPT_ROUTER, inet_addr(ROUTER_IP));', 'p += dhcp_append_ipv4(p, DHCP_OPT_ROUTER, ROUTER_IP);')
s = s.replace('p += dhcp_append_u32(p, DHCP_OPT_DNS, inet_addr(DNS_IP));', 'p += dhcp_append_ipv4(p, DHCP_OPT_DNS, DNS_IP);')
path.write_text(s)
PY

  if git -C "${REPO_DIR}" diff --quiet -- tools/edgerun-netboot/main.c; then
    log "[agent] DHCP patch: no diff after patch"
    return 0
  fi

  log "[agent] DHCP patch: building netboot"
  make -C "${REPO_DIR}" netboot >>"${RUN_LOG}" 2>&1
  git -C "${REPO_DIR}" add tools/edgerun-netboot/main.c
  git -C "${REPO_DIR}" commit -m "netboot: encode DHCP IPv4 options correctly" >>"${RUN_LOG}" 2>&1
  git -C "${REPO_DIR}" push origin main >>"${RUN_LOG}" 2>&1
  log "[agent] DHCP patch: committed and pushed"
}

{
  echo "[agent] starting run at $(date -Is)"
  echo "[agent] repo: ${REPO_DIR}"
} >"${RUN_LOG}"

build_rc=0
if ! patch_netboot_dhcp_ipv4_options; then
  build_rc=1
fi

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
