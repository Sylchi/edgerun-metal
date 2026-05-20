#!/usr/bin/env bash
set -euo pipefail

# Purpose:
#   Smoke-test the C repository inspection tool on a tiny synthetic VFS load.
# Intention:
#   Keep the report contract stable enough to trust in day-to-day repo work.

readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
readonly TMP_DIR="$(mktemp -d)"
readonly MARKER_TOKEN="TO""DO"

repo_inspect() {
  "${ROOT_DIR}/.build/er-build" repo-inspect "$@"
}

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

mkdir -p "${TMP_DIR}/pkg"
mkdir -p "${TMP_DIR}/.build/generated" "${TMP_DIR}/third_party/vendor" "${TMP_DIR}/ui/shadcn-ui/pkg"
printf 'int generated_build_file(void) { return 1; }\n' > "${TMP_DIR}/.build/generated/generated.c"
printf 'int vendored_file(void) { return 2; }\n' > "${TMP_DIR}/third_party/vendor/vendor.c"
printf 'int vendored_ui_file(void) { return 3; }\n' > "${TMP_DIR}/ui/shadcn-ui/pkg/vendor_ui.c"
cat > "${TMP_DIR}/pkg/main.c" <<C
static int unused_helper(void) { return 7; }

int main(void) {
  /* ${MARKER_TOKEN}: exercise the smell summary. */
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
void* malloc(unsigned long n);
void free(void* p);
void er_mem_copy(unsigned char* dst, const unsigned char* src, unsigned long len);
int render_tile(int x);

static float local_clamp01(float value) {
  if (value < 0.0f) return 0.0f;
  if (value > 1.0f) return 1.0f;
  return value;
}

static float local_clamp(float value, float min_value, float max_value) {
  if (value < min_value) return min_value;
  if (value > max_value) return max_value;
  return value;
}

int other(void) {
  static const char* const names[] = {"zero", "one", "two"};
  unsigned char dst[8];
  unsigned char src[8];
  int a = 1;
  int b = 2;
  int c = a + b;
  int d = c + b;
  int e = d + c;
  int f = e + d;
  int magic = 42;
  for (int y = 0; y < 4; ++y) {
    for (int x = 1; x < 4; ++x) {
      int q = y % x;
      void* p = malloc((unsigned long)x);
      er_mem_copy(dst, src, sizeof(dst));
      f += render_tile(q);
      free(p);
    }
  }
  //@optimizer-ignore bounded render smoke
  for (int x = 0; x < 4; ++x) { render_tile(x); }
  return f + magic + names[1][0];
}
C
cat > "${TMP_DIR}/pkg/ignored.c" <<'C'
//@optimizer-ignore-function verified generated-style schedule
int ignored_block(void) {
  int value = 0;
  for (int y = 0; y < 4; ++y) {
    for (int x = 1; x < 4; ++x) {
      value += (y % x) + 31337;
    }
  }
  return value;
}

int ignored(void) {
  static const char* const labels[] = {"zero", "one"}; //@optimizer-ignore-constant intentional metadata table
  int value = 31337; //@optimizer-ignore protocol example value
  return value + labels[0][0]; //@optimizer-ignore intentional metadata lookup
}
C
cat > "${TMP_DIR}/pkg/ignored_dup.c" <<'C'
//@optimizer-ignore-function intentional duplicate schedule fixture
int ignored_duplicate(void) {
  int a = 1;
  int b = 2;
  int c = a + b;
  int d = c + b;
  int e = d + c;
  int f = e + d;
  return f;
}
C
cat > "${TMP_DIR}/pkg/ignore_misuse.c" <<'C'
//@optimizer-ignore
int missing_reason(void) { return 1234; }

//@optimizer-ignore-begin obsolete block form
int removed_block_form(void) { return 31337; }
//@optimizer-ignore-end
C
cat > "${TMP_DIR}/pkg/enum_only.c" <<'C'
typedef enum {
  EnumZero = 0,
  EnumOne = 1,
  EnumTwo = 2,
  EnumThree = 3,
  EnumFour = 4
} EnumOnly;

typedef struct {
  unsigned char addr[4];
  unsigned char mac[6];
} StructOnly;

typedef union {
  unsigned char bytes[4];
  unsigned int word;
} UnionOnly;
C
mkdir -p "${TMP_DIR}/tests"
cat > "${TMP_DIR}/tests/test_main.c" <<'C'
int test_main_path(void) {
  main();
  return 0;
}
C
printf '\177ELFtest' > "${TMP_DIR}/release.efi"

report="$(repo_inspect --threads 2 "${TMP_DIR}")"
detail_report="$(repo_inspect --threads 2 --details "${TMP_DIR}")"
scoped_tools_report="$(cd "${ROOT_DIR}" && repo_inspect --threads 2 tools)"
scoped_codex_report="$(cd "${ROOT_DIR}" && repo_inspect --threads 2 codex)"
if repo_inspect --threads 0 "${TMP_DIR}" >/dev/null 2>"${TMP_DIR}/invalid_threads.err"; then
  printf 'invalid thread count accepted\n' >&2
  exit 1
fi

case "$(cat "${TMP_DIR}/invalid_threads.err")" in
  *"--threads must be an integer from 1 to 32"* ) ;;
  * ) printf 'missing invalid thread count diagnostic\n' >&2; exit 1 ;;
esac

case "${report}" in
  *"repo-inspect"*"Inventory"*"C files: 7"* ) ;;
  * ) printf 'missing compact source inventory or generated/vendor paths were inspected\n%s\n' "${report}" >&2; exit 1 ;;
esac

case "${detail_report}" in
  *"Details"*"duplicates:"*"findings:"*"[magic-number]"* ) ;;
  * ) printf 'missing detailed finding report\n%s\n' "${detail_report}" >&2; exit 1 ;;
esac

case "${report}" in
  *"top packages:"*"pkg"*"loc"* ) ;;
  * ) printf 'missing package report\n%s\n' "${report}" >&2; exit 1 ;;
esac

case "${report}" in
  *"release.efi"* ) ;;
  * ) printf 'missing binary size report\n%s\n' "${report}" >&2; exit 1 ;;
esac

case "${report}" in
  *"Release binaries"*"original"*"stripped"* ) ;;
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
  *"Tests"*"static proxy"* ) ;;
  * ) printf 'missing coverage section\n%s\n' "${report}" >&2; exit 1 ;;
esac

case "${report}" in
  *"Issues by group"*"duplication:"*".c:"*"resembles"* ) ;;
  * ) printf 'missing grouped duplication candidate\n%s\n' "${report}" >&2; exit 1 ;;
esac

case "${report}" in
  *"CPU cost:"*"nested loops"*"division/modulo"* ) ;;
  * ) printf 'missing grouped CPU cost summary\n%s\n' "${report}" >&2; exit 1 ;;
esac

case "${report}" in
  *"CPU cost:"*"samples:"*"[cpu-nested-loop]"*"[cpu-alloc-in-loop]"* ) ;;
  * ) printf 'missing grouped CPU cost samples\n%s\n' "${report}" >&2; exit 1 ;;
esac

case "${report}" in
  *"hotspots:"*"nonprod"* ) ;;
  * ) printf 'missing compact hotspot summary\n%s\n' "${report}" >&2; exit 1 ;;
esac

case "${report}" in
  *"smells:"*"magic numbers"*"string-indexing"*"math primitives"* ) ;;
  * ) printf 'missing grouped magic/string smell summary\n%s\n' "${report}" >&2; exit 1 ;;
esac

case "${report}" in
  *"focused magic-number candidates:"*"focused string-indexing candidates:"*"focused math primitive candidates:"* ) ;;
  * ) printf 'missing focused magic/string candidates\n%s\n' "${report}" >&2; exit 1 ;;
esac

case "${report}" in
  *"[magic-number]"*"[string-indexing]"*"[math-primitive]"* | *"[math-primitive]"*"[string-indexing]"*"[magic-number]"* ) ;;
  * ) printf 'missing magic/string smell details\n%s\n' "${report}" >&2; exit 1 ;;
esac

case "${report}" in
  *"ignored.c:"* ) printf 'optimizer-ignore line still reported\n%s\n' "${report}" >&2; exit 1 ;;
  * ) ;;
esac

case "${report}" in
  *"ignored_dup.c:"* ) printf 'optimizer-ignore duplicate block still reported\n%s\n' "${report}" >&2; exit 1 ;;
  * ) ;;
esac

case "${report}" in
  *"enum_only.c:"* ) printf 'enum ABI constants reported as smells\n%s\n' "${report}" >&2; exit 1 ;;
  * ) ;;
esac

case "${report}" in
  *"ignore_misuse.c:"*"[ignore-misuse]"* ) ;;
  * ) printf 'missing optimizer ignore misuse report\n%s\n' "${report}" >&2; exit 1 ;;
esac

case "${scoped_tools_report}" in
  *"top packages:"*"tools"*"loc"* ) ;;
  * ) printf 'relative scope prefix was not preserved\n%s\n' "${scoped_tools_report}" >&2; exit 1 ;;
esac

case "${scoped_tools_report}" in
  *"worldview: 0 findings"* ) ;;
  * ) printf 'hosted tools were classified as runtime worldview findings\n%s\n' "${scoped_tools_report}" >&2; exit 1 ;;
esac

case "${scoped_codex_report}" in
  *"worldview: 0 findings"* ) ;;
  * ) printf 'hosted codex support was classified as runtime worldview findings\n%s\n' "${scoped_codex_report}" >&2; exit 1 ;;
esac

printf 'repo-inspect tests passed\n'
