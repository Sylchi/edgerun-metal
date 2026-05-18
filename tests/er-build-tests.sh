#!/usr/bin/env sh
set -eu

# Purpose:
#   Validate the repository-owned build runner command plan.
# Intention:
#   Keep the internal project-management entrypoint deterministic as Make/CMake
#   orchestration is retired target by target.

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ER_BUILD="${ROOT_DIR}/.build/er-build"

repo_plan=$("$ER_BUILD" --print-plan repo-test)

case "$repo_plan" in
  *"+ clang -std=c11 -Wall -Wextra -Werror -O2 -o .build/repo-check tools/repo-check.c"* ) ;;
  * ) printf 'missing repo-check compile step\n' >&2; exit 1 ;;
esac

case "$repo_plan" in
  *"+ clang -std=c11 -Wall -Wextra -Werror -O2 -o .build/repo-inspect -pthread"* ) ;;
  * ) printf 'missing repo-inspect compile step\n' >&2; exit 1 ;;
esac

case "$repo_plan" in
  *"+ ./tests/er-build-tests.sh"* ) ;;
  * ) printf 'missing er-build self-test step\n' >&2; exit 1 ;;
esac

case "$repo_plan" in
  *"+ ./tests/erwire-decode-tests.sh"* ) ;;
  * ) printf 'missing erwire test step\n' >&2; exit 1 ;;
esac

case "$repo_plan" in
  *"+ ./tests/metal-arch-build-tests.sh"* ) ;;
  * ) printf 'missing metal architecture build test step\n' >&2; exit 1 ;;
esac

crypto_plan=$("$ER_BUILD" --print-plan crypto-test)

case "$crypto_plan" in
  *"cmake"* | *"ninja"* | *"ctest"* )
    printf 'crypto-test plan still depends on external build orchestration\n' >&2
    exit 1
    ;;
  * ) ;;
esac

case "$crypto_plan" in
  *"+ clang -std=c11 -Wall -Wextra -Werror -O2 -o .build/er-build-out/crypto/test_blake3 -Iedgerun-crypto/include edgerun-crypto/tests/test_blake3.c edgerun-crypto/src/er_blake3.c"* ) ;;
  * ) printf 'missing direct crypto test compile step\n' >&2; exit 1 ;;
esac

case "$crypto_plan" in
  *"+ .build/er-build-out/crypto/test_blake3"* ) ;;
  * ) printf 'missing direct crypto test execution step\n' >&2; exit 1 ;;
esac

varfont_plan=$("$ER_BUILD" --print-plan varfont-test)

case "$varfont_plan" in
  *"cmake"* | *"ninja"* | *"ctest"* )
    printf 'varfont-test plan still depends on external build orchestration\n' >&2
    exit 1
    ;;
  * ) ;;
esac

case "$varfont_plan" in
  *"+ clang -std=c11 -Wall -Wextra -Werror -O2 -o .build/er-build-out/varfont/vrfont_tests -ffreestanding -fno-builtin -fno-stack-protector -Ivarfont/include -Iinclude -Ivarfont/src -DVRFONT_PROJECT_ROOT=\"varfont\""* ) ;;
  * ) printf 'missing direct varfont test compile step\n' >&2; exit 1 ;;
esac

case "$varfont_plan" in
  *"varfont/tests/test_runner.c"*"varfont/src/vr_font_atlas.c"*" -lm"* ) ;;
  * ) printf 'missing varfont test source set\n' >&2; exit 1 ;;
esac

case "$varfont_plan" in
  *"+ .build/er-build-out/varfont/vrfont_tests"* ) ;;
  * ) printf 'missing direct varfont test execution step\n' >&2; exit 1 ;;
esac

printf 'er-build tests passed\n'
