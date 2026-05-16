#!/usr/bin/env bash
set -euo pipefail

# Purpose:
#   Validate the repository-structure guard used by `make repo-check`.
# Intention:
#   Keep policy checks executable and regression-tested, not only documented.

readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
readonly REPO_CHECK="${ROOT_DIR}/tools/repo-check.sh"
readonly TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

init_repo() {
  local repo_dir="$1"

  mkdir -p "${repo_dir}"
  git -C "${repo_dir}" init --quiet
  printf 'ok\n' > "${repo_dir}/README.md"
  git -C "${repo_dir}" add README.md
}

run_in_repo() {
  local repo_dir="$1"

  (cd "${repo_dir}" && "${REPO_CHECK}")
}

expect_pass() {
  local name="$1"
  local repo_dir="${TMP_DIR}/${name}"

  init_repo "${repo_dir}"
  run_in_repo "${repo_dir}"
}

expect_fail() {
  local name="$1"
  local setup_fn="$2"
  local repo_dir="${TMP_DIR}/${name}"

  init_repo "${repo_dir}"
  "${setup_fn}" "${repo_dir}"

  if run_in_repo "${repo_dir}" >/dev/null 2>&1; then
    printf 'expected failure: %s\n' "${name}" >&2
    exit 1
  fi
}

add_nested_git_dir() {
  local repo_dir="$1"

  mkdir -p "${repo_dir}/vendor/pkg/.git"
}

add_gitmodules_file() {
  local repo_dir="$1"

  printf '[submodule "pkg"]\n\tpath = vendor/pkg\n\turl = https://example.invalid/pkg.git\n' > "${repo_dir}/.gitmodules"
}

add_gitlink() {
  local repo_dir="$1"

  git -C "${repo_dir}" update-index --add --cacheinfo 160000,0123456789012345678901234567890123456789,vendor/pkg
}

add_tracked_build_artifact() {
  local repo_dir="$1"

  mkdir -p "${repo_dir}/.build/out"
  printf 'artifact\n' > "${repo_dir}/.build/out/file.o"
  git -C "${repo_dir}" add -f .build/out/file.o
}

expect_pass clean_repo
expect_fail nested_git_dir add_nested_git_dir
expect_fail gitmodules_file add_gitmodules_file
expect_fail gitlink_entry add_gitlink
expect_fail tracked_build_artifact add_tracked_build_artifact

printf 'repo-check tests passed\n'
