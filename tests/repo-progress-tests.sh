#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
REPO_PROGRESS="${ROOT_DIR}/.build/er-build"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM

plan_output=$("$REPO_PROGRESS" --print-plan repo-progress edgerun-ui-core)

case "$plan_output" in
  *"+ git status --short --branch"*) ;;
  *) printf 'missing git status step\n' >&2; exit 1 ;;
esac

case "$plan_output" in
  *"+ git diff --stat -- edgerun-ui-core"*) ;;
  *) printf 'missing git diff stat step\n' >&2; exit 1 ;;
esac

case "$plan_output" in
  *"+ git diff --cached --stat -- edgerun-ui-core"*) ;;
  *) printf 'missing cached git diff stat step\n' >&2; exit 1 ;;
esac

case "$plan_output" in
  *"+ git diff --check -- edgerun-ui-core"*) ;;
  *) printf 'missing git diff check step\n' >&2; exit 1 ;;
esac

case "$plan_output" in
  *"+ git diff --cached --check -- edgerun-ui-core"*) ;;
  *) printf 'missing cached git diff check step\n' >&2; exit 1 ;;
esac

case "$plan_output" in
  *"+ .build/er-build repo-inspect edgerun-ui-core"*) ;;
  *) printf 'missing repo-inspect step\n' >&2; exit 1 ;;
esac

case "$plan_output" in
  *"+ make ui-core-test"*) ;;
  *) printf 'missing ui-core-test step\n' >&2; exit 1 ;;
esac

explicit_output=$("$REPO_PROGRESS" --print-plan repo-progress docs repo-test)
case "$explicit_output" in
  *"+ make repo-test"*) ;;
  *) printf 'explicit test target was not honored\n' >&2; exit 1 ;;
esac

codex_output=$("$REPO_PROGRESS" --print-plan repo-progress codex)
case "$codex_output" in
  *"+ make codex-test"*) ;;
  *) printf 'codex scope did not choose codex-test\n' >&2; exit 1 ;;
esac

font_output=$("$REPO_PROGRESS" --print-plan repo-progress edgerun-ui-core/varfont)
case "$font_output" in
  *"+ make varfont-test"*) ;;
  *) printf 'ui-owned varfont scope did not choose varfont-test\n' >&2; exit 1 ;;
esac

wasm_output=$("$REPO_PROGRESS" --print-plan repo-progress tools/wasm-compile)
case "$wasm_output" in
  *"+ make repo-test"*) ;;
  *) printf 'wasm compiler scope did not choose repo-test\n' >&2; exit 1 ;;
esac

unknown_out="${TMP_DIR}/repo-progress-unknown.out"
unknown_err="${TMP_DIR}/repo-progress-unknown.err"
if "$REPO_PROGRESS" --print-plan repo-progress docs >"$unknown_out" 2>"$unknown_err"; then
  printf 'unknown scope without explicit test target unexpectedly succeeded\n' >&2
  exit 1
fi

if ! grep -q 'no default test target for scope docs' "$unknown_err"; then
  printf 'unknown scope error did not explain missing default test target\n' >&2
  exit 1
fi

printf 'repo-progress tests passed\n'
