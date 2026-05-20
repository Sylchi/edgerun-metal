#!/usr/bin/env bash
set -euo pipefail

# Purpose:
#   Validate the repository-structure guard used by `make repo-check`.
# Intention:
#   Keep policy checks executable and regression-tested, not only documented.

readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
readonly REPO_CHECK="${ROOT_DIR}/.build/repo-check"
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
  local setup_fn="${2:-}"
  local repo_dir="${TMP_DIR}/${name}"

  init_repo "${repo_dir}"
  if [[ -n "${setup_fn}" ]]; then
    "${setup_fn}" "${repo_dir}"
  fi
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

add_nested_readme() {
  local repo_dir="$1"

  mkdir -p "${repo_dir}/docs"
  printf 'conflicting docs\n' > "${repo_dir}/docs/README.md"
  git -C "${repo_dir}" add docs/README.md
}

add_top_level_markdown() {
  local repo_dir="$1"

  printf 'stale status\n' > "${repo_dir}/ROADMAP.md"
  git -C "${repo_dir}" add ROADMAP.md
}

add_agents_policy() {
  local repo_dir="$1"

  printf 'policy\n' > "${repo_dir}/AGENTS.md"
  git -C "${repo_dir}" add AGENTS.md
}

add_allowed_blake3_readme() {
  local repo_dir="$1"

  mkdir -p "${repo_dir}/third_party/blake3"
  printf 'allowed BLAKE3 exception\n' > "${repo_dir}/third_party/blake3/README.md"
  git -C "${repo_dir}" add third_party/blake3/README.md
}

add_unapproved_third_party() {
  local repo_dir="$1"

  mkdir -p "${repo_dir}/third_party/pkg"
  printf 'vendor docs\n' > "${repo_dir}/third_party/pkg/README.md"
  git -C "${repo_dir}" add third_party/pkg/README.md
}

add_vendor_ui_reference() {
  local repo_dir="$1"

  mkdir -p "${repo_dir}/ui/shadcn-ui/pkg"
  printf 'reference ui docs\n' > "${repo_dir}/ui/shadcn-ui/pkg/README.md"
  git -C "${repo_dir}" add ui/shadcn-ui/pkg/README.md
}

add_first_party_fetch_command() {
  local repo_dir="$1"

  printf 'curl %sL https://example.invalid/pkg.tar.gz\n' '-' > "${repo_dir}/fetch.sh"
  git -C "${repo_dir}" add fetch.sh
}

add_vendor_ui_fetch_command() {
  local repo_dir="$1"

  mkdir -p "${repo_dir}/ui/shadcn-ui"
  printf 'pnpm %s\n' 'install' > "${repo_dir}/ui/shadcn-ui/package-notes.txt"
  git -C "${repo_dir}" add ui/shadcn-ui/package-notes.txt
}

add_first_party_openssl_link() {
  local repo_dir="$1"

  mkdir -p "${repo_dir}/codex"
  printf 'LDLIBS ?= -l%s -l%s\n' 'ssl' 'crypto' > "${repo_dir}/codex/Makefile"
  git -C "${repo_dir}" add codex/Makefile
}

add_first_party_openssl_include() {
  local repo_dir="$1"

  mkdir -p "${repo_dir}/codex/src"
  printf '#include <openssl%sssl.h>\n' '/' > "${repo_dir}/codex/src/tls.c"
  git -C "${repo_dir}" add codex/src/tls.c
}

expect_pass clean_repo
expect_pass agents_policy add_agents_policy
expect_pass allowed_blake3_readme add_allowed_blake3_readme
expect_pass vendor_ui_reference add_vendor_ui_reference
expect_pass vendor_ui_fetch_command add_vendor_ui_fetch_command
expect_fail nested_git_dir add_nested_git_dir
expect_fail gitmodules_file add_gitmodules_file
expect_fail gitlink_entry add_gitlink
expect_fail tracked_build_artifact add_tracked_build_artifact
expect_fail nested_readme add_nested_readme
expect_fail top_level_markdown add_top_level_markdown
expect_fail unapproved_third_party add_unapproved_third_party
expect_fail first_party_fetch_command add_first_party_fetch_command
expect_fail first_party_openssl_link add_first_party_openssl_link
expect_fail first_party_openssl_include add_first_party_openssl_include

printf 'repo-check tests passed\n'
