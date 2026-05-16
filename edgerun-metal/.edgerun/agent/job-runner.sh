#!/usr/bin/env bash
set -euo pipefail

JOB_FILE="${1:?job file required}"
OUTPUT_DIR="${2:-/tmp/edgerun-agent-job}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
STATE_DIR="${HOME}/.local/state/edgerun-agent/jobs"
mkdir -p "${STATE_DIR}"
mkdir -p "${OUTPUT_DIR}"

JOB_LOG="${OUTPUT_DIR}/job.txt"
JOB_ID_FILE="${OUTPUT_DIR}/job-id.txt"
JOB_ACTION_FILE="${OUTPUT_DIR}/job-action.txt"
JOB_RESULT_FILE="${OUTPUT_DIR}/job-result.txt"

log() {
  printf '%s\n' "$1" | tee -a "${JOB_LOG}"
}

has_bad_chars() {
  local value="$1"
  if [ -z "${value}" ]; then
    return 1
  fi
  if printf '%s' "${value}" | tr -d '\r\n' | grep -Eq '[`;&|$()<>]'; then
    return 0
  fi
  if printf '%s' "${value}" | grep -Eq '\$\('; then
    return 0
  fi
  return 1
}

validate_key_value() {
  local key="$1"
  local value="$2"

  if [ -z "${value}" ]; then
    return 0
  fi
  if has_bad_chars "${value}"; then
    echo "rejected unsafe value for ${key}: ${value}" >&2
    return 1
  fi
  return 0
}

sanitize_mac() {
  local mac="$1"
  if [ -n "${mac}" ] && printf '%s' "${mac}" | grep -Eiq '^[0-9a-f]{2}(:[0-9a-f]{2}){5}$'; then
    return 0
  fi
  return 1
}

sanitize_ipv4() {
  local ip="$1"
  if [ -n "${ip}" ] && printf '%s' "${ip}" | grep -Eoq '^[0-9]{1,3}(\.[0-9]{1,3}){3}$'; then
    return 0
  fi
  return 1
}

sanitize_iface() {
  local iface="$1"
  if [ -n "${iface}" ] && printf '%s' "${iface}" | grep -Eq '^[A-Za-z0-9_.:-]+$'; then
    return 0
  fi
  return 1
}

ensure_mode() {
  local mode="$1"
  [ "${mode}" = "auto" ] || [ "${mode}" = "http" ] || [ "${mode}" = "tftp" ] || return 1
}

ACTION="${ACTION:-noop}"
JOB_ID="no-job-id"
NETBOOT_IFACE=""
NETBOOT_MODE=""
NETBOOT_ALLOW_MAC=""
NETBOOT_CLIENT_IP=""
NETBOOT_MGMT_DHCP=""
NETBOOT_MGMT_MAC=""
NETBOOT_MGMT_IP=""
NETBOOT_HTTP_PORT=""
NETBOOT_FORCE_HTTP_FOR_PXE=""
NETBOOT_EFI=""

while IFS= read -r line || [ -n "${line}" ]; do
  [ -z "${line}" ] && continue
  case "${line}" in
    \#* ) continue ;;
  esac
  if printf '%s' "${line}" | grep -Fq $'\\r'; then
    line="$(printf '%s' "${line}" | tr -d '\r')"
  fi
  case "${line}" in
    *=*)
      key="${line%%=*}"
      value="${line#*=}"
      ;;
    *)
      continue
      ;;
  esac

  case "${key}" in
    JOB_ID)
      validate_key_value "${key}" "${value}" || exit 1
      JOB_ID="${value}"
      ;;
    ACTION)
      validate_key_value "${key}" "${value}" || exit 1
      ACTION="${value}"
      ;;
    NETBOOT_IFACE)
      validate_key_value "${key}" "${value}" || exit 1
      NETBOOT_IFACE="${value}"
      ;;
    NETBOOT_MODE)
      validate_key_value "${key}" "${value}" || exit 1
      NETBOOT_MODE="${value}"
      ;;
    NETBOOT_CLIENT_IP)
      validate_key_value "${key}" "${value}" || exit 1
      NETBOOT_CLIENT_IP="${value}"
      ;;
    NETBOOT_ALLOW_MAC)
      validate_key_value "${key}" "${value}" || exit 1
      NETBOOT_ALLOW_MAC="${value}"
      ;;
    NETBOOT_MGMT_DHCP)
      validate_key_value "${key}" "${value}" || exit 1
      NETBOOT_MGMT_DHCP="${value}"
      ;;
    NETBOOT_MGMT_MAC)
      validate_key_value "${key}" "${value}" || exit 1
      NETBOOT_MGMT_MAC="${value}"
      ;;
    NETBOOT_MGMT_IP)
      validate_key_value "${key}" "${value}" || exit 1
      NETBOOT_MGMT_IP="${value}"
      ;;
    NETBOOT_HTTP_PORT)
      validate_key_value "${key}" "${value}" || exit 1
      NETBOOT_HTTP_PORT="${value}"
      ;;
    NETBOOT_FORCE_HTTP_FOR_PXE)
      validate_key_value "${key}" "${value}" || exit 1
      NETBOOT_FORCE_HTTP_FOR_PXE="${value}"
      ;;
    NETBOOT_EFI)
      validate_key_value "${key}" "${value}" || exit 1
      NETBOOT_EFI="${value}"
      ;;
    *)
      continue
      ;;
  esac
done <"${JOB_FILE}"

if [ -z "${JOB_ID}" ] || [ "${JOB_ID}" = "no-job-id" ]; then
  echo "JOB_ID missing" >&2
  exit 1
fi

case "${ACTION}" in
  noop|collect|build|build-netboot|restart-netboot|set-netboot-env|http-self-test|status)
    ;;
  *)
    echo "unsupported ACTION: ${ACTION}" >&2
    exit 1
    ;;
esac

printf '%s\n' "${JOB_ID}" >"${JOB_ID_FILE}"
printf '%s\n' "${ACTION}" >"${JOB_ACTION_FILE}"

if ! sanitize_iface "${NETBOOT_IFACE}" && [ -n "${NETBOOT_IFACE}" ]; then
  echo "invalid NETBOOT_IFACE" >&2
  exit 1
fi
if [ -n "${NETBOOT_MODE}" ] && ! ensure_mode "${NETBOOT_MODE}"; then
  echo "invalid NETBOOT_MODE=${NETBOOT_MODE}" >&2
  exit 1
fi
if [ -n "${NETBOOT_ALLOW_MAC}" ] && ! sanitize_mac "${NETBOOT_ALLOW_MAC}"; then
  echo "invalid NETBOOT_ALLOW_MAC" >&2
  exit 1
fi
if [ -n "${NETBOOT_CLIENT_IP}" ] && ! sanitize_ipv4 "${NETBOOT_CLIENT_IP}"; then
  echo "invalid NETBOOT_CLIENT_IP" >&2
  exit 1
fi
if [ -n "${NETBOOT_MGMT_DHCP}" ] && [ "${NETBOOT_MGMT_DHCP}" != "0" ] && [ "${NETBOOT_MGMT_DHCP}" != "1" ]; then
  echo "invalid NETBOOT_MGMT_DHCP" >&2
  exit 1
fi
if [ -n "${NETBOOT_MGMT_MAC}" ] && ! sanitize_mac "${NETBOOT_MGMT_MAC}"; then
  echo "invalid NETBOOT_MGMT_MAC" >&2
  exit 1
fi
if [ -n "${NETBOOT_MGMT_IP}" ] && ! sanitize_ipv4 "${NETBOOT_MGMT_IP}"; then
  echo "invalid NETBOOT_MGMT_IP" >&2
  exit 1
fi
if [ -n "${NETBOOT_HTTP_PORT}" ] && ! printf '%s' "${NETBOOT_HTTP_PORT}" | grep -Eq '^[0-9]{1,5}$'; then
  echo "invalid NETBOOT_HTTP_PORT" >&2
  exit 1
fi
if [ -n "${NETBOOT_FORCE_HTTP_FOR_PXE}" ] && [ "${NETBOOT_FORCE_HTTP_FOR_PXE}" != "0" ] && [ "${NETBOOT_FORCE_HTTP_FOR_PXE}" != "1" ]; then
  echo "invalid NETBOOT_FORCE_HTTP_FOR_PXE" >&2
  exit 1
fi

if [ -z "${NETBOOT_HTTP_PORT}" ]; then
  NETBOOT_HTTP_PORT=8081
fi
if [ -z "${NETBOOT_MGMT_DHCP}" ]; then
  NETBOOT_MGMT_DHCP=0
fi
if [ -z "${NETBOOT_FORCE_HTTP_FOR_PXE}" ]; then
  NETBOOT_FORCE_HTTP_FOR_PXE=0
fi

DONE_FILE="${STATE_DIR}/${JOB_ID}.done"
if [ -f "${DONE_FILE}" ]; then
  log "JOB_ID ${JOB_ID} already completed; skipping"
  printf '%s\n' "skipped" >"${JOB_RESULT_FILE}"
  exit 0
fi

job_failed=0
{
  echo "job-id=${JOB_ID}"
  echo "action=${ACTION}"
  echo "mode=${NETBOOT_MODE:-}"
  echo "iface=${NETBOOT_IFACE:-}"
  echo "allow-mac=${NETBOOT_ALLOW_MAC:-}"
  echo "client-ip=${NETBOOT_CLIENT_IP:-}"
  echo "mgmt-dhcp=${NETBOOT_MGMT_DHCP}"
  echo "mgmt-mac=${NETBOOT_MGMT_MAC:-}"
  echo "mgmt-ip=${NETBOOT_MGMT_IP:-}"
  echo "http-port=${NETBOOT_HTTP_PORT}"
  echo "force-http-for-pxe=${NETBOOT_FORCE_HTTP_FOR_PXE}"
  echo "---"
} >"${JOB_LOG}"

cmd_make() {
  (cd "${REPO_DIR}" && make "$@")
}

action_noop() {
  log "noop"
}

action_collect() {
  "${SCRIPT_DIR}/collect.sh" "${OUTPUT_DIR}" >>"${JOB_LOG}" 2>&1
}

action_build() {
  cmd_make >>"${JOB_LOG}" 2>&1
}

action_build_netboot() {
  cmd_make >>"${JOB_LOG}" 2>&1
  cmd_make netboot >>"${JOB_LOG}" 2>&1
}

action_restart_netboot() {
  if ! command -v sudo >/dev/null 2>&1; then
    log "sudo command missing"
    return 1
  fi
  if ! sudo -n systemctl restart edgerun-netboot >>"${JOB_LOG}" 2>&1; then
    log "sudo -n systemctl restart edgerun-netboot failed"
    return 1
  fi
  if ! systemctl status edgerun-netboot --no-pager >>"${JOB_LOG}" 2>&1; then
    log "systemctl status failed"
    return 1
  fi
}

action_set_netboot_env() {
  local temp_env
  temp_env="$(mktemp)"
  {
    echo "EDGERUN_NETBOOT_IFACE=${NETBOOT_IFACE}"
    echo "EDGERUN_NETBOOT_MODE=${NETBOOT_MODE}"
    echo "EDGERUN_NETBOOT_ALLOW_MAC=${NETBOOT_ALLOW_MAC}"
    echo "EDGERUN_NETBOOT_CLIENT_IP=${NETBOOT_CLIENT_IP}"
    echo "EDGERUN_NETBOOT_MGMT_DHCP=${NETBOOT_MGMT_DHCP}"
    echo "EDGERUN_NETBOOT_MGMT_MAC=${NETBOOT_MGMT_MAC}"
    echo "EDGERUN_NETBOOT_MGMT_IP=${NETBOOT_MGMT_IP}"
    echo "EDGERUN_NETBOOT_HTTP_PORT=${NETBOOT_HTTP_PORT}"
    echo "EDGERUN_NETBOOT_FORCE_HTTP_FOR_PXE=${NETBOOT_FORCE_HTTP_FOR_PXE}"
    echo "EDGERUN_NETBOOT_EFI=${NETBOOT_EFI}"
  } >"${temp_env}"
  if ! sudo -n tee /etc/edgerun-netboot.env <"${temp_env}" >"/dev/null"; then
    log "sudo -n tee /etc/edgerun-netboot.env failed"
    rm -f "${temp_env}"
    return 1
  fi
  rm -f "${temp_env}"
  action_restart_netboot
}

action_http_self_test() {
  local dest="/tmp/BOOTX64.EFI"
  if command -v curl >/dev/null 2>&1; then
    if ! curl -f -o "${dest}" "http://10.42.0.1:${NETBOOT_HTTP_PORT}/BOOTX64.EFI" >>"${JOB_LOG}" 2>&1; then
      log "curl http test failed"
      return 1
    fi
  else
    log "curl missing; cannot perform http-self-test"
    return 1
  fi
  if ! cmp -s /opt/edgerun-metal/build/esp/EFI/BOOT/BOOTX64.EFI "${dest}"; then
    log "cmp failed for BOOTX64.EFI"
    return 1
  fi
}

action_status() {
  {
    systemctl status edgerun-netboot --no-pager
    echo "---"
    journalctl -u edgerun-netboot -n 300 --no-pager
    echo "---"
    ip -br addr
    echo "---"
    ss -lntup
    echo "---"
    git -C "${REPO_DIR}" status --short
    echo "---"
    git -C "${REPO_DIR}" branch -vv
  } >>"${JOB_LOG}"
  return 0
}

case "${ACTION}" in
  noop) action_noop ;;
  collect) action_collect ;;
  build) action_build ;;
  build-netboot) action_build_netboot ;;
  restart-netboot) action_restart_netboot ;;
  set-netboot-env) action_set_netboot_env ;;
  http-self-test) action_http_self_test ;;
  status) action_status ;;
esac
job_failed=$?

if [ "${job_failed}" -ne 0 ]; then
  printf '%s\n' "failed" >"${JOB_RESULT_FILE}"
  log "result: failed"
  exit 1
fi

printf '%s\n' "success" >"${JOB_RESULT_FILE}"
log "result: success"
touch "${DONE_FILE}"
exit 0
