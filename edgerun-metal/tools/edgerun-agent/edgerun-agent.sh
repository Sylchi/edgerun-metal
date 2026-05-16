#!/usr/bin/env bash
set -euo pipefail

LOCK_FILE="${EDGERUN_AGENT_LOCK_FILE:-/run/edgerun-agent.lock}"
if [ ! -w "${LOCK_FILE%/*}" ]; then
  if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -w "${XDG_RUNTIME_DIR}" ]; then
    LOCK_FILE="${XDG_RUNTIME_DIR}/edgerun-agent.lock"
  else
    LOCK_FILE="/tmp/edgerun-agent.lock"
  fi
fi
ENV_FILE="${EDGERUN_AGENT_ENV_FILE:-/etc/edgerun-agent.env}"
if [ ! -f "${ENV_FILE}" ] && [ -f "${HOME}/.config/edgerun-agent/edgerun-agent.env" ]; then
  ENV_FILE="${HOME}/.config/edgerun-agent/edgerun-agent.env"
fi
PUSH_LOG="/tmp/edgerun-agent-push.out"

DIAGNOSE="no"
if [ "${1:-}" = "--diagnose" ]; then
  DIAGNOSE="yes"
fi

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
: "${EDGERUN_AGENT_OUTPUT_WORKTREE:=${EDGERUN_AGENT_WORKTREE_DIR:-/tmp/edgerun-agent-output-worktree}}"
: "${EDGERUN_AGENT_WORKTREE_DIR:=${EDGERUN_AGENT_OUTPUT_WORKTREE}}"

REPO="${EDGERUN_AGENT_REPO}"
REMOTE="${EDGERUN_AGENT_REMOTE}"
SOURCE_BRANCH="${EDGERUN_AGENT_SOURCE_BRANCH}"
OUTPUT_BRANCH="${EDGERUN_AGENT_OUTPUT_BRANCH}"
OUTPUT_WORKTREE="${EDGERUN_AGENT_OUTPUT_WORKTREE}"

REPO="$(cd "${REPO}" && pwd -P)"
if ! git -C "${REPO}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "not a git repo: ${REPO}"
  exit 1
fi
RUN_SCRIPT="${REPO}/${EDGERUN_AGENT_RUN_SCRIPT}"
COLLECT_SCRIPT="${REPO}/.edgerun/agent/collect.sh"
REDACT_SCRIPT="${REPO}/.edgerun/agent/redact.sh"
OUTPUT_DIR="${REPO}/agent-output"
LATEST_DIR="${OUTPUT_DIR}/latest"
HISTORY_DIR="${OUTPUT_DIR}/history/$(date -u +%Y%m%dT%H%M%SZ)"
SUMMARY_FILE="${LATEST_DIR}/summary.txt"
if [ ! -d "${OUTPUT_DIR}" ]; then
  mkdir -p "${OUTPUT_DIR}" || true
fi
if [ ! -w "${OUTPUT_DIR}" ]; then
  OUTPUT_DIR="/tmp/edgerun-agent-output"
  LATEST_DIR="${OUTPUT_DIR}/latest"
  HISTORY_DIR="${OUTPUT_DIR}/history/$(date -u +%Y%m%dT%H%M%SZ)"
  SUMMARY_FILE="${LATEST_DIR}/summary.txt"
fi

TS="$(date -u +%Y%m%dT%H%M%SZ)"
SHORT_SHA="unknown"

git_repo() {
  git -c safe.directory='*' -C "${REPO}" "$@"
}

git_out() {
  git -c safe.directory='*' -C "${OUTPUT_WORKTREE}" "$@"
}

log() {
  printf '%s\n' "$1" | tee -a "${SUMMARY_FILE}"
}

mkdir -p "${OUTPUT_DIR}" "${LATEST_DIR}"

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
log "repo: ${REPO}"

if [ "${DIAGNOSE}" = "yes" ]; then
  log "diagnose=yes"
  {
    echo "whoami: $(whoami)"
    echo "uid_gid: $(id)"
    echo "pwd: $(pwd)"
    echo "REPO: ${REPO}"
    git_repo status --short
    git_repo remote -v
    git_repo branch -vv
    echo "OUT_WT: ${OUTPUT_WORKTREE}"
    if [ -d "${OUTPUT_WORKTREE}" ]; then
      git_out status --short || true
    else
      echo "output worktree missing"
    fi
    echo "ssh_test: $(ssh -T git@github.com 2>&1 | tr -d '\\n' || true)"
    echo "env:"
    env | grep '^EDGERUN_AGENT_' || true
  } >>"${SUMMARY_FILE}"
  cat "${SUMMARY_FILE}"
  exit 0
fi

if [ ! -x "${COLLECT_SCRIPT}" ]; then
  log "ERROR: missing collect script: ${COLLECT_SCRIPT}"
  exit 1
fi

if [ ! -x "${REDACT_SCRIPT}" ]; then
  log "ERROR: missing redact script: ${REDACT_SCRIPT}"
  exit 1
fi

cd "${REPO}"

dirty_state="$(git_repo status --short || true)"
run_allowed="yes"
if [ -n "${dirty_state}" ]; then
  run_allowed="no"
  log "working tree dirty; collect-only mode"
  log "${dirty_state}"
else
  log "working tree clean"
fi

if [ "${run_allowed}" = "yes" ]; then
  if git_repo fetch "${REMOTE}"; then
    if git_repo checkout "${SOURCE_BRANCH}"; then
      if git_repo pull --ff-only "${REMOTE}" "${SOURCE_BRANCH}"; then
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

SHORT_SHA="$(git_repo rev-parse --short "${SOURCE_BRANCH}" 2>/dev/null || echo unknown)"
log "source_sha=${SHORT_SHA}"

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

log "output worktree: ${OUTPUT_WORKTREE}"
if [ -e "${OUTPUT_WORKTREE}" ] && [ ! -d "${OUTPUT_WORKTREE}/.git" ]; then
  rm -rf "${OUTPUT_WORKTREE}"
fi
git_repo worktree prune >/dev/null 2>&1 || true

if ! git_repo show-ref --verify --quiet "refs/heads/${OUTPUT_BRANCH}"; then
  if git_repo show-ref --verify --quiet "refs/remotes/${REMOTE}/${OUTPUT_BRANCH}"; then
    git_repo branch "${OUTPUT_BRANCH}" "refs/remotes/${REMOTE}/${OUTPUT_BRANCH}"
  else
    git_repo branch "${OUTPUT_BRANCH}"
  fi
fi

if [ -d "${OUTPUT_WORKTREE}" ] && [ -d "${OUTPUT_WORKTREE}/.git" ]; then
  if ! git_out rev-parse --show-toplevel >/dev/null 2>&1; then
    git_repo worktree remove --force "${OUTPUT_WORKTREE}" >/dev/null 2>&1 || true
    rm -rf "${OUTPUT_WORKTREE}"
  fi
fi

ensure_worktree() {
  local path="$1"
  mkdir -p "$(dirname "${path}")"
  if ! git_repo worktree add "${path}" "${OUTPUT_BRANCH}" >/dev/null 2>&1; then
    return 1
  fi
}

if [ ! -d "${OUTPUT_WORKTREE}/.git" ]; then
  if ! ensure_worktree "${OUTPUT_WORKTREE}"; then
    log "worktree at ${OUTPUT_WORKTREE} failed; trying fallback"
    OUTPUT_WORKTREE="${OUTPUT_WORKTREE}-fallback"
    if ! ensure_worktree "${OUTPUT_WORKTREE}"; then
      log "error: failed to create output worktree ${OUTPUT_WORKTREE}"
      exit 1
    fi
  fi
fi

if ! git_out rev-parse --show-toplevel >/dev/null 2>&1; then
  log "error: output worktree is not a git repository: ${OUTPUT_WORKTREE}"
  exit 1
fi

if [ -d "${OUTPUT_WORKTREE}/agent-output" ]; then
  rm -rf "${OUTPUT_WORKTREE}/agent-output"
fi
mkdir -p "${OUTPUT_WORKTREE}/agent-output"
if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete "${OUTPUT_DIR}/" "${OUTPUT_WORKTREE}/agent-output/"
else
  rm -rf "${OUTPUT_WORKTREE}/agent-output"
  mkdir -p "${OUTPUT_WORKTREE}"
  cp -a "${OUTPUT_DIR}" "${OUTPUT_WORKTREE}/"
fi

git_out add -- agent-output
if git_out diff --cached --quiet; then
  log "output branch: no changes to commit"
else
  GIT_AUTHOR_NAME="EdgeRun Agent" \
  GIT_AUTHOR_EMAIL="edgerun-agent@localhost" \
  GIT_COMMITTER_NAME="EdgeRun Agent" \
  GIT_COMMITTER_EMAIL="edgerun-agent@localhost" \
  git_out commit --author="EdgeRun Agent <edgerun-agent@localhost>" \
    -m "agent(fw): report ${TS} source ${SHORT_SHA}" -- agent-output
  log "output branch: committed"
  log "committed_files=$(git_out ls-files --stage --cached | wc -l)"
fi

if git_out push "${REMOTE}" "${OUTPUT_BRANCH}:${OUTPUT_BRANCH}" >"${PUSH_LOG}" 2>&1; then
  log "push: ok"
else
  log "push: failed"
  sed -n '1,80p' "${PUSH_LOG}" >>"${SUMMARY_FILE}" 2>/dev/null || true
  {
    echo "git remote -v:"
    git_out remote -v || true
    echo "git branch -vv:"
    git_out branch -vv || true
    echo "git status --short:"
    git_out status --short || true
    echo "git log --oneline -5:"
    git_out log --oneline -5 || true
  } >>"${SUMMARY_FILE}"
fi

rm -f "${PUSH_LOG}"
