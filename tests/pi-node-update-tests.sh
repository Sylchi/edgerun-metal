#!/usr/bin/env sh
set -eu

# Purpose:
#   Validate the host-side Pi Zero W v1.1 L2 update packet builder.
# Intention:
#   Keep the Wi-Fi updater using existing erwire/VFS object packets.

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUILD_DIR="${ROOT_DIR}/.build/pi-node-update-tests"
TOOL_BIN="${BUILD_DIR}/pi-node-update"
IMAGE="${BUILD_DIR}/kernel.img"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

"${CC:-${ROOT_DIR}/toolchain/bin/clang}" -std=c11 -Wall -Wextra -Werror -O2 \
  -I"${ROOT_DIR}/edgerun-metal/core" \
  -I"${ROOT_DIR}/edgerun-metal/devices/pi_zero_w_v1_1" \
  -I"${ROOT_DIR}/include" \
  -I"${ROOT_DIR}/edgerun-ui-core/include" \
  -I"${ROOT_DIR}/edgerun-crypto/include" \
  -o "$TOOL_BIN" \
  "${ROOT_DIR}/tools/pi-node-update/main.c" \
  "${ROOT_DIR}/edgerun-metal/core/er_vfs.c" \
  "${ROOT_DIR}/edgerun-metal/core/er_crypto.c" \
  "${ROOT_DIR}/edgerun-metal/core/er_crypto_blake3.c" \
  "${ROOT_DIR}/edgerun-metal/core/er_identity.c" \
  "${ROOT_DIR}/edgerun-metal/core/er_mem.c" \
  "${ROOT_DIR}/edgerun-crypto/src/er_blake3.c"

if "$TOOL_BIN" >/tmp/pi-node-update-usage.out \
  2>/tmp/pi-node-update-usage.err; then
  printf 'pi-node-update accepted missing arguments\n' >&2
  exit 1
fi

if ! grep -q "usage: .*--iface <iface> --image <kernel.img>" \
  /tmp/pi-node-update-usage.err; then
  printf 'pi-node-update usage text is not explicit\n' >&2
  exit 1
fi

dd if=/dev/zero of="$IMAGE" bs=1 count=38404 status=none
"$TOOL_BIN" --image "$IMAGE" --dry-run >/tmp/pi-node-update-dry-run.out

if ! grep -q "bytes=38404 packets=38 repeat=1 mode=dry-run" \
  /tmp/pi-node-update-dry-run.out; then
  printf 'pi-node-update dry-run did not report expected packet count\n' >&2
  exit 1
fi

"$TOOL_BIN" --image "$IMAGE" --repeat 2 --dry-run \
  >/tmp/pi-node-update-repeat.out

if ! grep -q "bytes=38404 packets=38 repeat=2 mode=dry-run" \
  /tmp/pi-node-update-repeat.out; then
  printf 'pi-node-update dry-run did not report repeat count\n' >&2
  exit 1
fi

printf 'pi node update tests passed\n'
