#!/bin/sh
set -eu

build_dir="../.build/edgerun-zig/immutable-kernel-app-runtime"
esp_img="$build_dir/esp.img"
efi_dir="$build_dir/esp/EFI/BOOT"
efi_app="$efi_dir/BOOTX64.EFI"
debug_log="$build_dir/qemu-debug.log"
qemu_display="${EDGERUN_QEMU_DISPLAY:-gtk}"
qemu_timeout="${EDGERUN_QEMU_TIMEOUT:-30}"
ovmf_code="/usr/share/edk2/x64/OVMF_CODE.4m.fd"
ovmf_vars_src="/usr/share/edk2/x64/OVMF_VARS.4m.fd"
ovmf_vars="$build_dir/OVMF_VARS.4m.fd"

mkdir -p "$efi_dir"
zig build --cache-dir ../.build/edgerun-zig immutable-kernel-app-runtime-efi
cp zig-out/immutable-kernel-app-runtime/BOOTX64.EFI.efi "$efi_app"

rm -f "$esp_img" "$debug_log"
dd if=/dev/zero of="$esp_img" bs=1M count=24 status=none
mformat -i "$esp_img" ::
mmd -i "$esp_img" ::/EFI ::/EFI/BOOT
mcopy -i "$esp_img" "$efi_app" ::/EFI/BOOT/BOOTX64.EFI

cp "$ovmf_vars_src" "$ovmf_vars"

set +e
timeout "$qemu_timeout" qemu-system-x86_64 \
  -machine q35 \
  -m 2048 \
  -nodefaults \
  -display "$qemu_display" \
  -serial none \
  -monitor none \
  -no-reboot \
  -device VGA \
  -drive if=pflash,format=raw,readonly=on,file="$ovmf_code" \
  -drive if=pflash,format=raw,file="$ovmf_vars" \
  -drive format=raw,file="$esp_img" \
  -debugcon "file:$debug_log" \
  -global isa-debugcon.iobase=0x402
qemu_status=$?
set -e

if ! grep -q "PASS immutable-kernel-app-runtime-qemu" "$debug_log"; then
  cat "$debug_log"
  exit 1
fi

cat "$debug_log"
if [ "$qemu_status" -ne 0 ] && [ "$qemu_status" -ne 124 ]; then
  exit "$qemu_status"
fi
