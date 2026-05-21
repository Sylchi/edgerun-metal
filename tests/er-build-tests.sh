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
  *"+ toolchain/bin/clang -std=c11 -Wall -Wextra -Werror -O2 -o .build/repo-check tools/repo-check.c"* ) ;;
  * ) printf 'missing repo-check compile step\n' >&2; exit 1 ;;
esac

repo_inspect_plan=$("$ER_BUILD" --print-plan repo-inspect codex)
swarm_plan=$("$ER_BUILD" --print-plan repo-agent-swarm --scope codex --concurrency 50)
swarm_limit_plan=$("$ER_BUILD" --print-plan repo-agent-swarm --scope codex --concurrency 10 --limit 10)

case "$repo_inspect_plan" in
  *"+ .build/er-build repo-inspect codex"* ) ;;
  * ) printf 'missing in-process repo-inspect plan\n' >&2; exit 1 ;;
esac

case "$swarm_plan" in
  *"+ make codex-build"* ) ;;
  * ) printf 'missing swarm codex build step\n' >&2; exit 1 ;;
esac

case "$swarm_plan" in
  *"+ repo-inspect analyze --details <in-memory VFS> | <filtered actionable file task queue>"* ) ;;
  * ) printf 'missing swarm repo-inspect queue step\n' >&2; exit 1 ;;
esac

case "$swarm_plan" in
  *"+ .build/codex --memory-only --quiet-agent --minimal-agent --only-file FILE --root . --prompt <one focused file, streamed diffs, 50 concurrent>"* ) ;;
  * ) printf 'missing swarm bounded worker step\n' >&2; exit 1 ;;
esac

case "$swarm_limit_plan" in
  *"+ .build/codex --memory-only --quiet-agent --minimal-agent --only-file FILE --root . --prompt <one focused file, streamed diffs, 10 concurrent, 10 limit>"* ) ;;
  * ) printf 'missing swarm worker limit step\n' >&2; exit 1 ;;
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
  *"+ ./tests/wasm-compile-source-tests.sh"* ) ;;
  * ) printf 'missing wasm compiler source test step\n' >&2; exit 1 ;;
esac

case "$repo_plan" in
  *"+ ./tests/erwire-decode-tests.sh"* ) ;;
  * ) printf 'missing erwire test step\n' >&2; exit 1 ;;
esac

case "$repo_plan" in
  *"+ ./tests/repo-push-check-tests.sh"* ) ;;
  * ) printf 'missing repo push check test step\n' >&2; exit 1 ;;
esac

push_check_plan=$("$ER_BUILD" --print-plan repo-push-check)
case "$push_check_plan" in
  *"+ ./tools/repo-push-check.sh"* ) ;;
  * ) printf 'missing repo-push-check step\n' >&2; exit 1 ;;
esac

case "$repo_plan" in
  *"+ toolchain/bin/clang -std=c11 -Wall -Wextra -Werror -O2 -o .build/erwire-decode -Iinclude tools/erwire-decode.c"* ) ;;
  * ) printf 'missing erwire decoder include path\n' >&2; exit 1 ;;
esac

app_package_plan=$("$ER_BUILD" --print-plan app-build "${ROOT_DIR}/tests/fixtures/app-package/app")

case "$app_package_plan" in
  *"+ toolchain/bin/clang -std=c11 -Wall -Wextra -Werror -O2 -o .build/wasm-compile"*"tools/wasm-compile/wasm_compile_parse.c"* ) ;;
  * ) printf 'missing app-build compiler build step\n' >&2; exit 1 ;;
esac

case "$app_package_plan" in
  *"+ .build/wasm-compile ${ROOT_DIR}/tests/fixtures/app-package/app/app.erc ${ROOT_DIR}/tests/fixtures/app-package/app/.build/app.wasm"* ) ;;
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
  *"+ toolchain/bin/clang -std=c11 -Wall -Wextra -Werror -O2 -o .build/pi-serial-verify tools/pi-serial-verify/main.c"* ) ;;
  * ) printf 'missing pi serial verifier compile step\n' >&2; exit 1 ;;
esac

case "$repo_plan" in
  *"+ toolchain/bin/clang -std=c11 -Wall -Wextra -Werror -O2 -o .build/pi-node-update -Iinclude -Iedgerun-metal/core -Iedgerun-metal/devices/pi_zero_w_v1_1 -Iedgerun-crypto/include tools/pi-node-update/main.c edgerun-metal/devices/pi_zero_w_v1_1/er_pi_zero_w_v1_1_ota.c edgerun-metal/core/er_mem.c edgerun-metal/core/er_vfs.c edgerun-metal/core/er_crypto.c edgerun-metal/core/er_crypto_blake3.c edgerun-metal/core/er_identity.c edgerun-crypto/src/er_blake3.c"* ) ;;
  * ) printf 'missing pi node update compile step\n' >&2; exit 1 ;;
esac

case "$repo_plan" in
  *"+ toolchain/bin/clang -std=c11 -Wall -Wextra -Werror -O2 -o .build/sdcard-probe -Iinclude tools/sdcard-probe/main.c"* ) ;;
  * ) printf 'missing sd card probe compile step\n' >&2; exit 1 ;;
esac

case "$repo_plan" in
  *"+ toolchain/bin/clang -std=c11 -Wall -Wextra -Werror -O2 -o .build/disk-analyzer -Iinclude -Iedgerun-metal/core tools/disk-analyzer/main.c tools/disk-analyzer/disk_analyzer.c tools/disk-analyzer/duplicates.c edgerun-metal/core/er_disk_analyzer.c edgerun-metal/core/er_mem.c"* ) ;;
  * ) printf 'missing disk analyzer compile step\n' >&2; exit 1 ;;
esac

case "$repo_plan" in
  *"+ toolchain/bin/clang -std=c11 -Wall -Wextra -Werror -O2 -o .build/pi-usb-boot tools/pi-usb-boot/main.c"* ) ;;
  * ) printf 'missing pi usb boot compile step\n' >&2; exit 1 ;;
esac

case "$repo_plan" in
  *"+ ./tests/pi-serial-verify-tests.sh"* ) ;;
  * ) printf 'missing pi serial verifier test step\n' >&2; exit 1 ;;
esac

case "$repo_plan" in
  *"+ ./tests/pi-zero-w-v1_1-bring-up-tests.sh"* ) ;;
  * ) printf 'missing pi zero w v1.1 bring-up test step\n' >&2; exit 1 ;;
esac

case "$repo_plan" in
  *"+ ./tests/sdcard-probe-tests.sh"* ) ;;
  * ) printf 'missing sd card probe test step\n' >&2; exit 1 ;;
esac

case "$repo_plan" in
  *"+ ./tests/disk-analyzer-tests.sh"* ) ;;
  * ) printf 'missing disk analyzer test step\n' >&2; exit 1 ;;
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
  *"+ toolchain/bin/clang -std=c11 -Wall -Wextra -Werror -O2 -o .build/er-build-out/crypto/test_blake3 -Iedgerun-crypto/include edgerun-crypto/tests/test_blake3.c edgerun-crypto/src/er_blake3.c"* ) ;;
  * ) printf 'missing direct crypto test compile step\n' >&2; exit 1 ;;
esac

case "$crypto_plan" in
  *"+ .build/er-build-out/crypto/test_blake3"* ) ;;
  * ) printf 'missing direct crypto test execution step\n' >&2; exit 1 ;;
esac

clock_plan=$("$ER_BUILD" --print-plan clock-test)

case "$clock_plan" in
  *"cmake"* | *"ninja"* | *"ctest"* )
    printf 'clock-test plan still depends on external build orchestration\n' >&2
    exit 1
    ;;
  * ) ;;
esac

case "$clock_plan" in
  *"+ toolchain/bin/clang -std=c11 -Wall -Wextra -Werror -O2 -o .build/er-build-out/clock/test_clock -ffreestanding -fno-builtin -fno-stack-protector -Iedgerun-clock/include edgerun-clock/tests/test_clock.c edgerun-clock/src/er_clock.c"* ) ;;
  * ) printf 'missing direct clock test compile step\n' >&2; exit 1 ;;
esac

case "$clock_plan" in
  *"+ .build/er-build-out/clock/test_clock"* ) ;;
  * ) printf 'missing direct clock test execution step\n' >&2; exit 1 ;;
esac

identity_plan=$("$ER_BUILD" --print-plan identity-test)

case "$identity_plan" in
  *"cmake"* | *"ninja"* | *"ctest"* )
    printf 'identity-test plan still depends on external build orchestration\n' >&2
    exit 1
    ;;
  * ) ;;
esac

case "$identity_plan" in
  *"+ toolchain/bin/clang -std=c11 -Wall -Wextra -Werror -O2 -o .build/er-build-out/identity/test_identity -ffreestanding -fno-builtin -fno-stack-protector -Iedgerun-identity/include -Iedgerun-clock/include -Iedgerun-crypto/include edgerun-identity/tests/test_identity.c edgerun-identity/src/er_identity.c edgerun-clock/src/er_clock.c edgerun-crypto/src/er_blake3.c -DER_BLAKE3_NO_SIMD=1"* ) ;;
  * ) printf 'missing direct identity test compile step\n' >&2; exit 1 ;;
esac

case "$identity_plan" in
  *"+ .build/er-build-out/identity/test_identity"* ) ;;
  * ) printf 'missing direct identity test execution step\n' >&2; exit 1 ;;
esac

object_plan=$("$ER_BUILD" --print-plan object-test)

case "$object_plan" in
  *"cmake"* | *"ninja"* | *"ctest"* )
    printf 'object-test plan still depends on external build orchestration\n' >&2
    exit 1
    ;;
  * ) ;;
esac

case "$object_plan" in
  *"+ toolchain/bin/clang -std=c11 -Wall -Wextra -Werror -O2 -o .build/er-build-out/object/test_object -ffreestanding -fno-builtin -fno-stack-protector -Iedgerun-object/include -Iedgerun-clock/include -Iedgerun-crypto/include -Iinclude edgerun-object/tests/test_object.c edgerun-object/src/er_object.c edgerun-clock/src/er_clock.c edgerun-crypto/src/er_blake3.c -DER_BLAKE3_NO_SIMD=1"* ) ;;
  * ) printf 'missing direct object test compile step\n' >&2; exit 1 ;;
esac

case "$object_plan" in
  *"+ .build/er-build-out/object/test_object"* ) ;;
  * ) printf 'missing direct object test execution step\n' >&2; exit 1 ;;
esac

storage_plan=$("$ER_BUILD" --print-plan storage-test)

case "$storage_plan" in
  *"cmake"* | *"ninja"* | *"ctest"* )
    printf 'storage-test plan still depends on external build orchestration\n' >&2
    exit 1
    ;;
  * ) ;;
esac

case "$storage_plan" in
  *"+ toolchain/bin/clang -std=c11 -Wall -Wextra -Werror -O2 -o .build/er-build-out/storage/test_store -Iedgerun-storage/include -Iedgerun-object/include -Iedgerun-identity/include -Iedgerun-clock/include -Iedgerun-crypto/include -Iinclude edgerun-storage/tests/test_store.c edgerun-storage/src/er_store.c edgerun-object/src/er_object.c edgerun-identity/src/er_identity.c edgerun-clock/src/er_clock.c edgerun-crypto/src/er_blake3.c"* ) ;;
  * ) printf 'missing direct storage test compile step\n' >&2; exit 1 ;;
esac

case "$storage_plan" in
  *"+ .build/er-build-out/storage/test_store"* ) ;;
  * ) printf 'missing direct storage test execution step\n' >&2; exit 1 ;;
esac

node_plan=$("$ER_BUILD" --print-plan node-test)

case "$node_plan" in
  *"+ toolchain/bin/clang -std=c11 -Wall -Wextra -Werror -O2 -o .build/er-build-out/node/test_node -Iedgerun-node/include -Iedgerun-storage/include -Iedgerun-object/include -Iedgerun-identity/include -Iedgerun-clock/include -Iedgerun-crypto/include -Iinclude edgerun-node/tests/test_node.c edgerun-node/src/er_node.c edgerun-storage/src/er_store.c edgerun-object/src/er_object.c edgerun-identity/src/er_identity.c edgerun-clock/src/er_clock.c edgerun-crypto/src/er_blake3.c -DER_BLAKE3_NO_SIMD=1"* ) ;;
  * ) printf 'missing direct node test compile step\n' >&2; exit 1 ;;
esac

case "$node_plan" in
  *"+ .build/er-build-out/node/test_node"* ) ;;
  * ) printf 'missing direct node test execution step\n' >&2; exit 1 ;;
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
  *"+ toolchain/bin/clang -std=c11 -Wall -Wextra -Werror -O2 -o .build/er-build-out/varfont/vrfont_tests -ffreestanding -fno-builtin -fno-stack-protector -Iedgerun-ui-core/varfont/include -Iinclude -Iedgerun-ui-core/varfont/src -DVRFONT_PROJECT_ROOT=\"edgerun-ui-core/varfont\""* ) ;;
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

ui_core_plan=$("$ER_BUILD" --print-plan ui-core-test)

case "$ui_core_plan" in
  *"cmake"* | *"ninja"* | *"ctest"* )
    printf 'ui-core-test plan still depends on external build orchestration\n' >&2
    exit 1
    ;;
  * ) ;;
esac

case "$ui_core_plan" in
  *"+ toolchain/bin/clang -std=c11 -Wall -Wextra -Werror -O2 -o .build/er-build-out/ui-core/er_ui_core_tests -ffreestanding -fno-builtin -fno-stack-protector -Iedgerun-ui-core/include -Iedgerun-ui-core/varfont/include -Iedgerun-ui-core/varfont/src -Iinclude -DER_UI_REPO_ROOT=\".\""* ) ;;
  * ) printf 'missing direct ui-core test compile step\n' >&2; exit 1 ;;
esac

case "$ui_core_plan" in
  *"edgerun-ui-core/tests/test_components.c"*"edgerun-ui-core/src/er_ui_components_emit.c"*"edgerun-ui-core/varfont/src/vr_font_atlas.c"*" -lm"* ) ;;
  * ) printf 'missing ui-core test source set\n' >&2; exit 1 ;;
esac

case "$ui_core_plan" in
  *"+ .build/er-build-out/ui-core/er_ui_core_tests"* ) ;;
  * ) printf 'missing direct ui-core test execution step\n' >&2; exit 1 ;;
esac

printf 'er-build tests passed\n'
