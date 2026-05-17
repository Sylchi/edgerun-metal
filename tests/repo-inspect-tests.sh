#!/usr/bin/env bash
set -euo pipefail

# Purpose:
#   Smoke-test the C repository inspection tool on a tiny synthetic VFS load.
# Intention:
#   Keep the report contract stable enough to trust in day-to-day repo work.

readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
readonly REPO_INSPECT="${ROOT_DIR}/.build/repo-inspect"
readonly TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

mkdir -p "${TMP_DIR}/pkg"
cat > "${TMP_DIR}/pkg/main.c" <<'C'
static int unused_helper(void) { return 7; }

int main(void) {
  /* TODO: exercise the smell summary. */
  int a = 1;
  int b = 2;
  int c = a + b;
  int d = c + b;
  int e = d + c;
  int f = e + d;
  return f;
}
C
cat > "${TMP_DIR}/pkg/other.c" <<'C'
int other(void) {
  static const char* const names[] = {"zero", "one", "two"};
  int a = 1;
  int b = 2;
  int c = a + b;
  int d = c + b;
  int e = d + c;
  int f = e + d;
  int magic = 42;
  return f + magic + names[1][0];
}
C
mkdir -p "${TMP_DIR}/tests"
cat > "${TMP_DIR}/tests/test_main.c" <<'C'
int test_main_path(void) {
  main();
  return 0;
}
C
printf '\177ELFtest' > "${TMP_DIR}/release.efi"

report="$("${REPO_INSPECT}" "${TMP_DIR}")"

case "${report}" in
  *"files:         3"* ) ;;
  * ) printf 'missing source file count\n%s\n' "${report}" >&2; exit 1 ;;
esac

case "${report}" in
  *"pkg"*"loc"* ) ;;
  * ) printf 'missing package report\n%s\n' "${report}" >&2; exit 1 ;;
esac

case "${report}" in
  *"release.efi"* ) ;;
  * ) printf 'missing binary size report\n%s\n' "${report}" >&2; exit 1 ;;
esac

case "${report}" in
  *"Optimized stripped release sizes"*"original"*"stripped"* ) ;;
  * ) printf 'missing stripped size report\n%s\n' "${report}" >&2; exit 1 ;;
esac

case "${report}" in
  *"unused_helper appears unreferenced"* ) ;;
  * ) printf 'missing dead-code candidate\n%s\n' "${report}" >&2; exit 1 ;;
esac

case "${report}" in
  *"[marker]"* ) ;;
  * ) printf 'missing marker smell\n%s\n' "${report}" >&2; exit 1 ;;
esac

case "${report}" in
  *"Static test coverage proxy"*".    "* | *"Static test coverage proxy"* ) ;;
  * ) printf 'missing coverage section\n%s\n' "${report}" >&2; exit 1 ;;
esac

case "${report}" in
  *"Potential duplication"*".c:"*"resembles"* ) ;;
  * ) printf 'missing duplication candidate\n%s\n' "${report}" >&2; exit 1 ;;
esac

case "${report}" in
  *"package hotspots:"*"nonprod"* ) ;;
  * ) printf 'missing package hotspot summary\n%s\n' "${report}" >&2; exit 1 ;;
esac

case "${report}" in
  *"magic numbers"*"string-indexing"* ) ;;
  * ) printf 'missing magic/string smell summary\n%s\n' "${report}" >&2; exit 1 ;;
esac

case "${report}" in
  *"focused magic-number candidates:"*"focused string-indexing candidates:"* ) ;;
  * ) printf 'missing focused magic/string candidates\n%s\n' "${report}" >&2; exit 1 ;;
esac

case "${report}" in
  *"[magic-number]"*"[string-indexing]"* | *"[string-indexing]"*"[magic-number]"* ) ;;
  * ) printf 'missing magic/string smell details\n%s\n' "${report}" >&2; exit 1 ;;
esac

printf 'repo-inspect tests passed\n'
