#!/usr/bin/env sh
set -eu

# Purpose:
#   Validate architecture selection for the freestanding metal UEFI image.
# Intention:
#   Keep Pi 4B/AArch64 boot artifacts explicit while preserving the x86_64 path.

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

x86_config=$(make -C "$ROOT_DIR/edgerun-metal" --no-print-directory print-config ER_METAL_ARCH=x86_64)

case "$x86_config" in
  *"ER_METAL_TARGET=x86_64-pc-windows-msvc"*) ;;
  *) printf 'x86_64 target triple missing\n' >&2; exit 1 ;;
esac

case "$x86_config" in
  *"ER_METAL_BOOT_EFI=BOOTX64.EFI"*) ;;
  *) printf 'x86_64 boot filename missing\n' >&2; exit 1 ;;
esac

case "$x86_config" in
  *"blake3_sse2_x86-64_windows_gnu.S"*) ;;
  *) printf 'x86_64 crypto assembly source missing\n' >&2; exit 1 ;;
esac

aarch64_config=$(make -C "$ROOT_DIR/edgerun-metal" --no-print-directory print-config ER_METAL_ARCH=aarch64)

case "$aarch64_config" in
  *"ER_METAL_TARGET=aarch64-unknown-windows-msvc"*) ;;
  *) printf 'aarch64 target triple missing\n' >&2; exit 1 ;;
esac

case "$aarch64_config" in
  *"ER_METAL_BOOT_EFI=BOOTAA64.EFI"*) ;;
  *) printf 'aarch64 boot filename missing\n' >&2; exit 1 ;;
esac

case "$aarch64_config" in
  *"ER_METAL_BOARD=uefi-generic"*) ;;
  *) printf 'default board profile missing\n' >&2; exit 1 ;;
esac

case "$aarch64_config" in
  *"CRYPTO_ASM_SRCS="*) ;;
  *) printf 'aarch64 crypto assembly line missing\n' >&2; exit 1 ;;
esac

case "$aarch64_config" in
  *"blake3_sse2_x86-64_windows_gnu.S"*)
    printf 'aarch64 config must not include x86_64 crypto assembly\n' >&2
    exit 1
    ;;
  *) ;;
esac

pi_zero_config=$(make -C "$ROOT_DIR/edgerun-metal" --no-print-directory print-config ER_METAL_ARCH=aarch64 ER_METAL_BOARD=pi-zero-2w)

case "$pi_zero_config" in
  *"ER_METAL_BOARD=pi-zero-2w"*) ;;
  *) printf 'pi zero 2w board profile missing\n' >&2; exit 1 ;;
esac

case "$pi_zero_config" in
  *"ER_METAL_TARGET=aarch64-unknown-windows-msvc"*) ;;
  *) printf 'pi zero 2w target triple missing\n' >&2; exit 1 ;;
esac

case "$pi_zero_config" in
  *"ER_METAL_BOOT_EFI=BOOTAA64.EFI"*) ;;
  *) printf 'pi zero 2w boot filename missing\n' >&2; exit 1 ;;
esac

case "$pi_zero_config" in
  *"ER_METAL_BOARD_BOOT_CHAIN=raspberry-pi-firmware -> u-boot-efi -> BOOTAA64.EFI"*) ;;
  *) printf 'pi zero 2w boot chain missing\n' >&2; exit 1 ;;
esac

if make -C "$ROOT_DIR/edgerun-metal" --no-print-directory print-config ER_METAL_ARCH=x86_64 ER_METAL_BOARD=pi-zero-2w >/tmp/metal-board-invalid.out 2>/tmp/metal-board-invalid.err; then
  printf 'pi zero 2w accepted x86_64 unexpectedly\n' >&2
  exit 1
fi

if ! grep -q "ER_METAL_BOARD=pi-zero-2w requires ER_METAL_ARCH=aarch64" /tmp/metal-board-invalid.err; then
  printf 'pi zero 2w architecture error was not explicit\n' >&2
  exit 1
fi

pi_zero_w_config=$(make -C "$ROOT_DIR/edgerun-metal" --no-print-directory print-config ER_METAL_ARCH=armv6 ER_METAL_BOARD=pi-zero-w-v1_1)

case "$pi_zero_w_config" in
  *"ER_METAL_BOARD=pi-zero-w-v1_1"*) ;;
  *) printf 'pi zero w v1.1 board profile missing\n' >&2; exit 1 ;;
esac

case "$pi_zero_w_config" in
  *"ER_METAL_TARGET=armv6-none-eabi"*) ;;
  *) printf 'pi zero w v1.1 target triple missing\n' >&2; exit 1 ;;
esac

case "$pi_zero_w_config" in
  *"ER_METAL_BOOT_EFI=kernel.img"*) ;;
  *) printf 'pi zero w v1.1 boot filename missing\n' >&2; exit 1 ;;
esac

case "$pi_zero_w_config" in
  *"ER_METAL_BOARD_BOOT_CHAIN=raspberry-pi-firmware -> kernel.img"*) ;;
  *) printf 'pi zero w v1.1 boot chain missing\n' >&2; exit 1 ;;
esac

case "$pi_zero_w_config" in
  *"PI_ZERO_W_V1_1_NODE_INDEX=0"*) ;;
  *) printf 'pi zero w v1.1 default node index missing\n' >&2; exit 1 ;;
esac

case "$pi_zero_w_config" in
  *"PI_ZERO_W_V1_1_NODE_ID=ERZWPI00RELAY001CYW43438ARMV6L2"*) ;;
  *) printf 'pi zero w v1.1 default node identity missing\n' >&2; exit 1 ;;
esac

case "$pi_zero_w_config" in
  *"PI_ZERO_W_V1_1_NODE_ROLE=bootstrap-identity-package-index-serial-first-boot"*) ;;
  *) printf 'pi zero w v1.1 default node role missing\n' >&2; exit 1 ;;
esac

pi_zero_w_node5_config=$(make -C "$ROOT_DIR/edgerun-metal" --no-print-directory print-config ER_METAL_ARCH=armv6 ER_METAL_BOARD=pi-zero-w-v1_1 PI_ZERO_W_V1_1_NODE_INDEX=5)

case "$pi_zero_w_node5_config" in
  *"PI_ZERO_W_V1_1_NODE_ID=ERZWPI05RELAY001CYW43438ARMV6L2"*) ;;
  *) printf 'pi zero w v1.1 node 5 identity missing\n' >&2; exit 1 ;;
esac

case "$pi_zero_w_node5_config" in
  *"PI_ZERO_W_V1_1_NODE_ROLE=mobile-observer-route-churn-late-admission"*) ;;
  *) printf 'pi zero w v1.1 node 5 role missing\n' >&2; exit 1 ;;
esac

if make -C "$ROOT_DIR/edgerun-metal" --no-print-directory print-config ER_METAL_ARCH=aarch64 ER_METAL_BOARD=pi-zero-w-v1_1 >/tmp/metal-zero-w-board-invalid.out 2>/tmp/metal-zero-w-board-invalid.err; then
  printf 'pi zero w v1.1 accepted aarch64 unexpectedly\n' >&2
  exit 1
fi

if ! grep -q "ER_METAL_BOARD=pi-zero-w-v1_1 requires ER_METAL_ARCH=armv6" /tmp/metal-zero-w-board-invalid.err; then
  printf 'pi zero w v1.1 architecture error was not explicit\n' >&2
  exit 1
fi

if make -C "$ROOT_DIR/edgerun-metal" --no-print-directory print-config ER_METAL_ARCH=armv6 ER_METAL_BOARD=pi-zero-w-v1_1 PI_ZERO_W_V1_1_NODE_INDEX=6 >/tmp/metal-zero-w-node-invalid.out 2>/tmp/metal-zero-w-node-invalid.err; then
  printf 'pi zero w v1.1 accepted invalid node index unexpectedly\n' >&2
  exit 1
fi

if ! grep -q "unsupported PI_ZERO_W_V1_1_NODE_INDEX '6'" /tmp/metal-zero-w-node-invalid.err; then
  printf 'pi zero w v1.1 node index error was not explicit\n' >&2
  exit 1
fi

if make -C "$ROOT_DIR/edgerun-metal" --no-print-directory print-config ER_METAL_ARCH=armv7 >/tmp/metal-arch-invalid.out 2>/tmp/metal-arch-invalid.err; then
  printf 'unsupported architecture unexpectedly succeeded\n' >&2
  exit 1
fi

if ! grep -q "unsupported ER_METAL_ARCH 'armv7'" /tmp/metal-arch-invalid.err; then
  printf 'unsupported architecture error was not explicit\n' >&2
  exit 1
fi

rm -f /tmp/metal-arch-invalid.out /tmp/metal-arch-invalid.err
rm -f /tmp/metal-board-invalid.out /tmp/metal-board-invalid.err
rm -f /tmp/metal-zero-w-board-invalid.out /tmp/metal-zero-w-board-invalid.err
rm -f /tmp/metal-zero-w-node-invalid.out /tmp/metal-zero-w-node-invalid.err
printf 'metal architecture build tests passed\n'
