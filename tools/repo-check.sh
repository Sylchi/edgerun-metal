#!/usr/bin/env bash
set -euo pipefail

# Purpose:
#   Enforce that this workspace remains one Git repository with source files only.
# Intention:
#   Fail fast when nested repositories, submodule declarations, submodule gitlinks,
#   or tracked generated build artifacts enter the tree.

readonly ROOT_DIR="$(git rev-parse --show-toplevel)"

cd "${ROOT_DIR}"

fail() {
  printf 'repo-check: %s\n' "$1" >&2
  exit 1
}

if find . -path './.git' -prune -o \( -name .git -o -name .gitmodules \) -print -quit | grep -q .; then
  fail 'nested Git metadata is not allowed'
fi

if git ls-files -s | awk '$1 == "160000" { found = 1 } END { exit found ? 0 : 1 }'; then
  fail 'Git submodule entries are not allowed'
fi

if git ls-files '.build/**' 'varfont/build/**' 'edgerun-metal/build/**' | grep -q .; then
  fail 'generated build artifacts must not be tracked'
fi
