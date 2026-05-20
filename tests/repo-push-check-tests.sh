#!/usr/bin/env bash
set -euo pipefail

# Purpose:
#   Validate the local pushability guard for oversized blobs.
# Intention:
#   Catch remote-rejected commits before the push path.

readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
readonly PUSH_CHECK="${ROOT_DIR}/tools/repo-push-check.sh"
readonly TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

init_repo() {
  local repo_dir="$1"

  mkdir -p "${repo_dir}"
  git -C "${repo_dir}" init --quiet
  git -C "${repo_dir}" config user.email "repo-push-check@example.invalid"
  git -C "${repo_dir}" config user.name "repo-push-check"
  printf 'root\n' > "${repo_dir}/README.md"
  git -C "${repo_dir}" add README.md
  git -C "${repo_dir}" commit --quiet -m root
}

clean_repo="${TMP_DIR}/clean"
init_repo "${clean_repo}"
printf 'small\n' > "${clean_repo}/small.bin"
git -C "${clean_repo}" add small.bin
git -C "${clean_repo}" commit --quiet -m small
(
  cd "${clean_repo}"
  ER_PUSH_CHECK_BASE=HEAD~1 ER_PUSH_BLOB_LIMIT_BYTES=10 "${PUSH_CHECK}" >/dev/null
)

large_repo="${TMP_DIR}/large"
init_repo "${large_repo}"
printf '01234567890\n' > "${large_repo}/large.bin"
git -C "${large_repo}" add large.bin
git -C "${large_repo}" commit --quiet -m large
if (
  cd "${large_repo}"
  ER_PUSH_CHECK_BASE=HEAD~1 ER_PUSH_BLOB_LIMIT_BYTES=10 "${PUSH_CHECK}" >/dev/null 2>&1
); then
  printf 'repo-push-check accepted oversized blob\n' >&2
  exit 1
fi

printf 'repo-push-check tests passed\n'
