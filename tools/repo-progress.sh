#!/usr/bin/env sh
set -eu

usage() {
  cat <<'USAGE'
usage: tools/repo-progress.sh [--print-plan] <scope> [test-target]

Runs the standard local progress loop for a repository scope:
  git status --short --branch
  git diff --stat -- <scope>
  git diff --cached --stat -- <scope>
  git diff --check -- <scope>
  git diff --cached --check -- <scope>
  make repo-inspect
  ./.build/repo-inspect <scope>
  make <test-target>

Known scopes choose a deterministic test target when one is not provided:
  edgerun-ui-core -> ui-core-test
  edgerun-ui-core/varfont -> varfont-test
  edgerun-crypto  -> crypto-test
  edgerun-metal   -> edgerun-check
  codex           -> codex-test
USAGE
}

print_plan=false
if [ "${1:-}" = "--print-plan" ]; then
  print_plan=true
  shift
fi

scope="${1:-}"
test_target="${2:-}"

if [ "$scope" = "" ] || [ "$scope" = "-h" ] || [ "$scope" = "--help" ]; then
  usage
  if [ "$scope" = "" ]; then
    exit 2
  fi
  exit 0
fi

if [ "$test_target" = "" ]; then
  case "$scope" in
    edgerun-ui-core) test_target="ui-core-test" ;;
    edgerun-ui-core/varfont) test_target="varfont-test" ;;
    edgerun-crypto) test_target="crypto-test" ;;
    edgerun-metal) test_target="edgerun-check" ;;
    codex) test_target="codex-test" ;;
    *)
      printf 'repo-progress: no default test target for scope %s\n' "$scope" >&2
      printf 'repo-progress: pass an explicit test target\n' >&2
      exit 2
      ;;
  esac
fi

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

run_step() {
  title="$1"
  shift
  printf '\n== %s ==\n' "$title"
  if [ "$print_plan" = true ]; then
    printf '+'
    while [ "$#" -gt 0 ]; do
      printf ' %s' "$1"
      shift
    done
    printf '\n'
  else
    "$@"
  fi
}

run_step "git status" git status --short --branch
run_step "git diff stat: $scope" git diff --stat -- "$scope"
run_step "git cached diff stat: $scope" git diff --cached --stat -- "$scope"
run_step "git diff check: $scope" git diff --check -- "$scope"
run_step "git cached diff check: $scope" git diff --cached --check -- "$scope"
run_step "build repo-inspect" make repo-inspect
run_step "repo-inspect: $scope" ./.build/repo-inspect "$scope"
run_step "test target: $test_target" make "$test_target"
