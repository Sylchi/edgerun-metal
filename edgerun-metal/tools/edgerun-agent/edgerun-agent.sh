#!/usr/bin/env bash
set -euo pipefail

LOCK_FILE="/run/edgerun-agent.lock"
ENV_FILE="/etc/edgerun-agent.env"
PUSH_LOG="/tmp/edgerun-agent-push.out"

exec 9>"${LOCK_FILE}"
if ! flock -n 9; then
  echo "edgerun-agent already running"
  exit 0
fi

if [ -f "${ENV_FILE}" ]; then
  # shellcheck disable=SC1090
  . "${ENV_FILE}"
fi

: "${EDGERUN_AGENT_REPO:=/home/ken/edgerun-c/edgerun-metal}"
: "${EDGERUN_AGENT_REMOTE:=origin}"
: "${EDGERUN_AGENT_SOURCE_BRANCH:=main}"
: "${EDGERUN_AGENT_OUTPUT_BRANCH:=agent/fw}"
: "${EDGERUN_AGENT_HOSTNAME:=fw}"
: "${EDGERUN_AGENT_INTERVAL_SEC:=60}"
: "${EDGERUN_AGENT_RUN_SCRIPT:=.edgerun/agent/run.sh}"
: "${EDGERUN_AGENT_WORKTREE_DIR:=/tmp/edgerun-agent-output-worktree}"

REPO="$(cd "${EDGERUN_AGENT_REPO}" && pwd -P)"
REMOTE="${EDGERUN_AGENT_REMOTE}"
SOURCE_BRANCH="${EDGERUN_AGENT_SOURCE_BRANCH}"
OUTPUT_BRANCH="${EDGERUN_AGENT_OUTPUT_BRANCH}"
RUN_SCRIPT="${REPO}/${EDGERUN_AGENT_RUN_SCRIPT}"
COLLECT_SCRIPT="${REPO}/.edgerun/agent/collect.sh"
REDACT_SCRIPT="${REPO}/.edgerun/agent/redact.sh"
OUTPUT_DIR="${REPO}/agent-output"
LATEST_DIR="${OUTPUT_DIR}/latest"
HISTORY_DIR="${OUTPUT_DIR}/history/$(date -u +%Y%m%dT%H%M%SZ)"
SUMMARY_FILE="${LATEST_DIR}/summary.txt"
WORKTREE_DIR="${EDGERUN_AGENT_WORKTREE_DIR}"

git_safe() {
  local repo_path="$1"
  shift
  git -c safe.directory='*' -C "${repo_path}" "$@"
}

mkdir -p "${LATEST_DIR}"

log() {
  printf '%s\n' "$1" | tee -a "${SUMMARY_FILE}"
}

{
  echo "timestamp=$(date -u +%Y%m%dT%H%M%SZ)"
  echo "hostname=${EDGERUN_AGENT_HOSTNAME}"
  echo "repo=${REPO}"
  echo "remote=${REMOTE}"
  echo "source_branch=${SOURCE_BRANCH}"
  echo "output_branch=${OUTPUT_BRANCH}"
  echo "interval_sec=${EDGERUN_AGENT_INTERVAL_SEC}"
  echo "run_script=${RUN_SCRIPT}"
} >"${SUMMARY_FILE}"

log "starting agent cycle"
log "started_at=$(date -Is)"

if ! git_safe "${REPO}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  log "ERROR: not a git worktree: ${REPO}"
  exit 1
fi

if [ ! -x "${COLLECT_SCRIPT}" ]; then
  log "ERROR: missing collect script: ${COLLECT_SCRIPT}"
  exit 1
fi

if [ ! -x "${REDACT_SCRIPT}" ]; then
  log "ERROR: missing redact script: ${REDACT_SCRIPT}"
  exit 1
fi

cleanup_workspace() {
  if [ -d "${WORKTREE_DIR}" ]; then
    git -C "${REPO}" worktree remove --force "${WORKTREE_DIR}" >/dev/null 2>&1 || true
    rm -rf "${WORKTREE_DIR}"
  fi
  git -C "${REPO}" worktree prune >/dev/null 2>&1 || true
  rm -f "${PUSH_LOG}"
}
trap cleanup_workspace EXIT

cd "${REPO}"

dirty_state="$(git_safe "${REPO}" status --short || true)"
run_allowed="yes"
if [ -n "${dirty_state}" ]; then
  run_allowed="no"
  log "working tree dirty; collect-only mode"
  log "${dirty_state}"
else
  log "working tree clean"
fi

if [ "${run_allowed}" = "yes" ]; then
  if git_safe "${REPO}" fetch "${REMOTE}"; then
    if git_safe "${REPO}" checkout "${SOURCE_BRANCH}"; then
      if git_safe "${REPO}" pull --ff-only "${REMOTE}" "${SOURCE_BRANCH}"; then
        log "sync: pulled ${REMOTE}/${SOURCE_BRANCH}"
      else
        log "sync: pull failed"
      fi
    else
      log "sync: checkout failed ${SOURCE_BRANCH}"
    fi
  else
    log "sync: fetch failed"
  fi
else
  log "sync: skipped due dirty tree"
fi

SOURCE_SHA="$(git_safe "${REPO}" rev-parse --short "${SOURCE_BRANCH}" 2>/dev/null || echo unknown)"
log "source_sha=${SOURCE_SHA}"

if [ ! -f "${RUN_SCRIPT}" ]; then
  log "run script missing: ${RUN_SCRIPT}"
  run_allowed="no"
else
  repo_real="$(realpath -m "${REPO}")"
  run_real="$(realpath -m "${RUN_SCRIPT}")"
  case "${run_real}" in
    "${repo_real}"/* | "${repo_real}")
      ;;
    *)
      log "run script outside repo: ${RUN_SCRIPT}"
      run_allowed="no"
      ;;
  esac
fi

if [ "${run_allowed}" = "yes" ]; then
  log "run: executing ${RUN_SCRIPT}"
  set +e
  EDGERUN_AGENT_OUTPUT_DIR="${LATEST_DIR}" bash "${RUN_SCRIPT}" >"${LATEST_DIR}/run.log" 2>&1
  run_rc=$?
  set -e
  log "run_exit=${run_rc}"
else
  run_rc=0
  log "run: skipped"
  printf '%s\n' "run skipped" >"${LATEST_DIR}/run.log"
fi

set +e
bash "${COLLECT_SCRIPT}" "${LATEST_DIR}" >>"${LATEST_DIR}/run.log" 2>&1
collect_rc=$?
set -e
log "collect_exit=${collect_rc}"

log "redacting outputs"
bash "${REDACT_SCRIPT}" "${LATEST_DIR}"

mkdir -p "${HISTORY_DIR}"
cp -a "${LATEST_DIR}/." "${HISTORY_DIR}/"

log "output worktree: ${WORKTREE_DIR}"
if [ -d "${WORKTREE_DIR}" ]; then
  git_safe "${REPO}" worktree remove --force "${WORKTREE_DIR}" >/dev/null 2>&1 || true
  rm -rf "${WORKTREE_DIR}"
fi

git_safe "${REPO}" worktree add --detach -f "${WORKTREE_DIR}" "${SOURCE_BRANCH}" >/dev/null 2>&1 || true
git_safe "${WORKTREE_DIR}" fetch "${REMOTE}" --prune >/dev/null 2>&1 || true

if git_safe "${WORKTREE_DIR}" rev-parse --verify --quiet "refs/remotes/${REMOTE}/${OUTPUT_BRANCH}" >/dev/null; then
  git_safe "${WORKTREE_DIR}" checkout -B "${OUTPUT_BRANCH}" "${REMOTE}/${OUTPUT_BRANCH}"
else
  git_safe "${WORKTREE_DIR}" checkout -B "${OUTPUT_BRANCH}"
fi

rm -rf "${WORKTREE_DIR}/agent-output"
cp -a "${OUTPUT_DIR}" "${WORKTREE_DIR}/"

git_safe "${WORKTREE_DIR}" add -- agent-output
if git_safe "${WORKTREE_DIR}" diff --cached --quiet; then
  log "output branch: no changes to commit"
else
  git -c safe.directory='*' -C "${WORKTREE_DIR}" -c user.name="EdgeRun Agent" -c user.email="edgerun-agent@localhost" commit --author="EdgeRun Agent <edgerun-agent@localhost>" \
    -m "agent(${EDGERUN_AGENT_HOSTNAME}): report $(date -u +%Y%m%dT%H%M%SZ) source ${SOURCE_SHA}" -- agent-output
  log "output branch: committed"
fi

if git -c safe.directory='*' -C "${WORKTREE_DIR}" push "${REMOTE}" "${OUTPUT_BRANCH}:${OUTPUT_BRANCH}" >"${PUSH_LOG}" 2>&1; then
  log "push: ok"
else
  log "push: failed"
  sed -n '1,40p' "${PUSH_LOG}" >>"${SUMMARY_FILE}" 2>/dev/null || true
fi
