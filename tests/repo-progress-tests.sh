#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
REPO_PROGRESS="${ROOT_DIR}/tools/repo-progress.sh"

plan_output=$("$REPO_PROGRESS" --print-plan edgerun-ui-core)

case "$plan_output" in
  *"+ git status --short --branch"*) ;;
  *) printf 'missing git status step\n' >&2; exit 1 ;;
esac

case "$plan_output" in
  *"+ git diff --stat -- edgerun-ui-core"*) ;;
  *) printf 'missing git diff stat step\n' >&2; exit 1 ;;
esac

case "$plan_output" in
  *"+ git diff --check -- edgerun-ui-core"*) ;;
  *) printf 'missing git diff check step\n' >&2; exit 1 ;;
esac

case "$plan_output" in
  *"+ ./.build/repo-inspect edgerun-ui-core"*) ;;
  *) printf 'missing repo-inspect step\n' >&2; exit 1 ;;
esac

case "$plan_output" in
  *"+ make ui-core-test"*) ;;
  *) printf 'missing ui-core-test step\n' >&2; exit 1 ;;
esac

explicit_output=$("$REPO_PROGRESS" --print-plan docs repo-test)
case "$explicit_output" in
  *"+ make repo-test"*) ;;
  *) printf 'explicit test target was not honored\n' >&2; exit 1 ;;
esac

if "$REPO_PROGRESS" --print-plan docs >/tmp/repo-progress-unknown.out 2>/tmp/repo-progress-unknown.err; then
  printf 'unknown scope without explicit test target unexpectedly succeeded\n' >&2
  exit 1
fi

if ! grep -q 'no default test target for scope docs' /tmp/repo-progress-unknown.err; then
  printf 'unknown scope error did not explain missing default test target\n' >&2
  exit 1
fi

rm -f /tmp/repo-progress-unknown.out /tmp/repo-progress-unknown.err
printf 'repo-progress tests passed\n'
