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

repo_inspect_plan=$("$ER_BUILD" --print-plan repo-inspect codex)
swarm_plan=$("$ER_BUILD" --print-plan repo-agent-swarm --scope codex --concurrency 50)

case "$repo_inspect_plan" in
  *"+ .build/er-build repo-inspect codex"* ) ;;
  * ) printf 'missing in-process repo-inspect plan\n' >&2; exit 1 ;;
esac

case "$swarm_plan" in
  *"+ make codex-build"* ) ;;
  * ) printf 'missing swarm codex build step\n' >&2; exit 1 ;;
esac

case "$swarm_plan" in
  *"+ .build/er-build repo-inspect --details codex > .build/repo-agent-swarm/issues.txt"* ) ;;
  * ) printf 'missing swarm repo-inspect queue step\n' >&2; exit 1 ;;
esac

case "$swarm_plan" in
  *"+ .build/codex --root . --prompt <one generated prompt per repo-inspect issue, 50 concurrent>"* ) ;;
  * ) printf 'missing swarm bounded worker step\n' >&2; exit 1 ;;
esac

case "$repo_plan" in
  *"+ ./tests/er-build-tests.sh"* ) ;;
  * ) printf 'missing er-build self-test step\n' >&2; exit 1 ;;
esac

case "$repo_plan" in
  *"+ ./tests/app-package-build-tests.sh"* ) ;;
  * ) printf 'missing app package build test step\n' >&2; exit 1 ;;
esac

case "$repo_plan" in
  *"+ ./tests/erwire-decode-tests.sh"* ) ;;
  * ) printf 'missing erwire test step\n' >&2; exit 1 ;;
esac

case "$repo_plan" in
  *"+ clang -std=c11 -Wall -Wextra -Werror -O2 -o .build/erwire-decode -Iinclude tools/erwire-decode.c"* ) ;;
  * ) printf 'missing erwire decoder include path\n' >&2; exit 1 ;;
esac

app_package_plan=$("$ER_BUILD" --print-plan app-build "${ROOT_DIR}/tests/fixtures/app-package/app")

case "$app_package_plan" in
  *"+ clang -std=c11 -Wall -Wextra -Werror -O2 -o .build/wasm-compile"*"tools/wasm-compile/wasm_compile_parse.c"* ) ;;
  * ) printf 'missing app-build compiler build step\n' >&2; exit 1 ;;
esac

case "$app_package_plan" in
  *"+ .build/wasm-compile ${ROOT_DIR}/tests/fixtures/app-package/app/app.c ${ROOT_DIR}/tests/fixtures/app-package/app/.build/app.wasm"* ) ;;
  * ) printf 'missing app-build package compile step\n' >&2; exit 1 ;;
esac

if "$ER_BUILD" --print-plan app-verify "${ROOT_DIR}/tests/fixtures/app-package/app" >/dev/null 2>&1; then
  printf 'app-verify accepted print-plan\n' >&2
  exit 1
fi

case "$repo_plan" in
  *"+ ./tests/metal-arch-build-tests.sh"* ) ;;
  * ) printf 'missing metal architecture build test step\n' >&2; exit 1 ;;
esac

case "$repo_plan" in
  *"+ ./tests/pi-boot-stage-tests.sh"* ) ;;
  * ) printf 'missing pi boot stage test step\n' >&2; exit 1 ;;
esac

case "$repo_plan" in
  *"+ clang -std=c11 -Wall -Wextra -Werror -O2 -o .build/pi-serial-verify tools/pi-serial-verify/main.c"* ) ;;
  * ) printf 'missing pi serial verifier compile step\n' >&2; exit 1 ;;
esac

case "$repo_plan" in
  *"+ clang -std=c11 -Wall -Wextra -Werror -O2 -o .build/sdcard-probe -Iinclude tools/sdcard-probe/main.c"* ) ;;
  * ) printf 'missing sd card probe compile step\n' >&2; exit 1 ;;
esac

case "$repo_plan" in
  *"+ clang -std=c11 -Wall -Wextra -Werror -O2 -o .build/pi-usb-boot tools/pi-usb-boot/main.c"* ) ;;
  * ) printf 'missing pi usb boot compile step\n' >&2; exit 1 ;;
esac

case "$repo_plan" in
  *"+ ./tests/pi-serial-verify-tests.sh"* ) ;;
  * ) printf 'missing pi serial verifier test step\n' >&2; exit 1 ;;
esac

case "$repo_plan" in
  *"+ ./tests/sdcard-probe-tests.sh"* ) ;;
  * ) printf 'missing sd card probe test step\n' >&2; exit 1 ;;
esac

case "$repo_plan" in
  *"+ ./tests/pi-usb-boot-tests.sh"* ) ;;
  * ) printf 'missing pi usb boot test step\n' >&2; exit 1 ;;
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
  *"+ clang -std=c11 -Wall -Wextra -Werror -O2 -o .build/er-build-out/varfont/vrfont_tests -ffreestanding -fno-builtin -fno-stack-protector -Iedgerun-ui-core/varfont/include -Iinclude -Iedgerun-ui-core/varfont/src -DVRFONT_PROJECT_ROOT=\"edgerun-ui-core/varfont\""* ) ;;
  * ) printf 'missing direct varfont test compile step\n' >&2; exit 1 ;;
esac

case "$varfont_plan" in
  *"edgerun-ui-core/varfont/tests/test_runner.c"*"edgerun-ui-core/varfont/src/vr_font_atlas.c"*" -lm"* ) ;;
  * ) printf 'missing varfont test source set\n' >&2; exit 1 ;;
esac

case "$varfont_plan" in
  *"+ .build/er-build-out/varfont/vrfont_tests"* ) ;;
  * ) printf 'missing direct varfont test execution step\n' >&2; exit 1 ;;
esac

printf 'er-build tests passed\n'
