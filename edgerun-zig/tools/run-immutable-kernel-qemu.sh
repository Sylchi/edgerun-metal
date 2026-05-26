#!/bin/sh
set -eu

build_dir="../.build/edgerun-zig/immutable-kernel"
esp_img="$build_dir/esp.img"
efi_dir="$build_dir/esp/EFI/BOOT"
efi_app="$efi_dir/BOOTX64.EFI"
debug_log="$build_dir/qemu-debug.log"
ovmf_code="/usr/share/edk2/x64/OVMF_CODE.4m.fd"
ovmf_vars_src="/usr/share/edk2/x64/OVMF_VARS.4m.fd"
ovmf_vars="$build_dir/OVMF_VARS.4m.fd"

mkdir -p "$efi_dir"
zig build-exe src/immutable_kernel_uefi.zig \
  -target x86_64-uefi \
  -O ReleaseSmall \
  -femit-bin="$efi_app"

rm -f "$esp_img" "$debug_log"
dd if=/dev/zero of="$esp_img" bs=1M count=8 status=none
mformat -i "$esp_img" ::
mmd -i "$esp_img" ::/EFI ::/EFI/BOOT
mcopy -i "$esp_img" "$efi_app" ::/EFI/BOOT/BOOTX64.EFI

cp "$ovmf_vars_src" "$ovmf_vars"

set +e
timeout 15 qemu-system-x86_64 \
  -machine q35 \
  -nodefaults \
  -display none \
  -serial none \
  -monitor none \
  -no-reboot \
  -drive if=pflash,format=raw,readonly=on,file="$ovmf_code" \
  -drive if=pflash,format=raw,file="$ovmf_vars" \
  -drive format=raw,file="$esp_img" \
  -debugcon "file:$debug_log" \
  -global isa-debugcon.iobase=0x402
qemu_status=$?
set -e

if ! grep -q "PASS immutable-kernel-qemu" "$debug_log"; then
  cat "$debug_log"
  exit 1
fi

cat "$debug_log"
if [ "$qemu_status" -ne 0 ] && [ "$qemu_status" -ne 124 ]; then
  exit "$qemu_status"
fi
