#!/usr/bin/env bash
# EdgeRun build script — explicit, no pattern rules, no Makefile magic.
# Usage:  ./build.sh <target>
# Targets:  kernel  kernel-hello  test  test-*  clean
set -euo pipefail

BUILD_DIR=".build"
ASM_BUILD="${BUILD_DIR}/asm"
ASM_DIR="asm/x86_64"
TEST_DIR="asm/test"
YASM="${YASM:-yasm}"
CC="${CC:-cc}"
ASM_INC="-I asm"
ASM_KERNEL_FMT="elf32"
KERNEL_LD="${ASM_DIR}/linker.ld"
KERNEL_EFI_LD="${ASM_DIR}/efi_linker.ld"
KERNEL_ELF="${ASM_BUILD}/kernel.elf"
KERNEL_EFI="${ASM_BUILD}/kernel.efi"
KERNEL_BIN="${ASM_BUILD}/kernel.bin"
COM1_PORT=0x3f8

# ---- helpers ----
mkdir -p "${ASM_BUILD}"

elf64()   { ${YASM} -f elf64   ${ASM_INC} -o "$2" "$1" && test -f "$2"; }
elf32()   { ${YASM} -f elf32   ${ASM_INC} -o "$2" "$1" && test -f "$2"; }
elf64_h() { ${YASM} -f elf64   ${ASM_INC} -DHOSTED_TEST -o "$2" "$1" && test -f "$2"; }
link_cc() { ${CC} -ffreestanding -nostdlib -static -fno-stack-protector -g -o "$@"; }

# ---- kernel objects (elf32) ----
kobj() { elf32 "${ASM_DIR}/$1" "${ASM_BUILD}/kernel_$1"; }

KERNEL_ASM_SRCS="
	blake3.asm
	bytes.asm
	clock.asm
	ctype.asm
	identity.asm
	math.asm
	runtime.asm
	serial.asm
	tpm.asm
	tpm_crb.asm
	cmos.asm
	i8042.asm
	cros_ec.asm
	dw_i2c.asm
	i2c_hid.asm
	pci.asm
	nvme.asm
	amdgpu.asm
	preimage.asm
	display.asm
	fb_text.asm
	acpi.asm
	xhci.asm
	rtl8125.asm
	bt.asm
	virtio.asm
	virtio_gpu.asm
	virtio_net.asm
	smn.asm
	psp_mailbox.asm
	psp_rom_armor.asm
	spi_flash.asm
	intel_sdhci.asm
	intel_gpu.asm
	net.asm
	arp.asm
	ipv4.asm
	tcp.asm
	entry.asm
"

# ---- shared library objects (elf64, used by tests) ----
SOBJS="
	blake3.o
	acpi.o
	bytes.o
	clock.o
	ctype.o
	identity.o
	math.o
	preimage.o
	render_ir.o
	runtime.o
	serial.o
	sw_fb.o
	wasm_interpreter.o
	wasm_module.o
	wasm_compiler.o
	wasm_compiler_source.o
	ui_core.o
	fb_text.o
	object.o
"

# ---- test_entry.o ----
test_entry() {
	local src="${TEST_DIR}/test_entry.asm"
	local dst="${ASM_BUILD}/test_entry.o"
	if [ ! -f "$dst" ] || [ "$src" -nt "$dst" ] || [ "${ASM_DIR}/macros.inc" -nt "$dst" ]; then
		${YASM} -f elf64 ${ASM_INC} -o "$dst" "$src"
	fi
	echo "  AS  ${dst}"
}

# ---- assemble_shared ----
assemble_shared() {
	local missing=0
	for o in ${SOBJS}; do
		local base="${o%.o}"
		local src="${ASM_DIR}/${base}.asm"
		local dst="${ASM_BUILD}/${o}"
		if [ ! -f "$dst" ] || [ "$src" -nt "$dst" ] || [ "${ASM_DIR}/macros.inc" -nt "$dst" ]; then
			elf64 "$src" "$dst"
			echo "  AS  ${dst}"
		fi
	done
	for o in acpi.o bytes.o blake3.o preimage.o; do
		local base="${o%.o}"
		# these may have extra deps — handled by simple timestamp check above
		:
	done
}

# ---- assemble_kernel ----
assemble_kernel() {
	for src in ${KERNEL_ASM_SRCS}; do
		local base="${src%.asm}"
		local src_path="${ASM_DIR}/${src}"
		local dst="${ASM_BUILD}/kernel_${base}.o"
		if [ ! -f "$dst" ] || [ "$src_path" -nt "$dst" ] || [ "${ASM_DIR}/macros.inc" -nt "$dst" ]; then
			elf32 "$src_path" "$dst"
			echo "  AS  ${dst}"
		fi
	done
	# kernel_main — source name != target
	local km_src="${ASM_DIR}/kernel_main.asm"
	local km_dst="${ASM_BUILD}/kernel_main_elf32.o"
	if [ ! -f "$km_dst" ] || [ "$km_src" -nt "$km_dst" ] || [ "${ASM_DIR}/macros.inc" -nt "$km_dst" ]; then
		elf32 "$km_src" "$km_dst"
		echo "  AS  ${km_dst}"
	fi
}

# ---- assemble_kernel_efi (elf64, for PE32+) ----
assemble_kernel_efi() {
	for src in ${KERNEL_ASM_SRCS}; do
		local base="${src%.asm}"
		local src_path="${ASM_DIR}/${src}"
		if [ "$base" = "entry" ]; then
			src_path="${ASM_DIR}/efi_entry.asm"
		fi
		local dst="${ASM_BUILD}/kernel_efi_${base}.o"
		if [ ! -f "$dst" ] || [ "$src_path" -nt "$dst" ] || [ "${ASM_DIR}/macros.inc" -nt "$dst" ]; then
			elf64 "$src_path" "$dst"
			echo "  AS  ${dst}"
		fi
	done
	# kernel_main as ELF64
	local km_src="${ASM_DIR}/kernel_main.asm"
	local km_dst="${ASM_BUILD}/kernel_main_efi64.o"
	if [ ! -f "$km_dst" ] || [ "$km_src" -nt "$km_dst" ] || [ "${ASM_DIR}/macros.inc" -nt "$km_dst" ]; then
		elf64 "$km_src" "$km_dst"
		echo "  AS  ${km_dst}"
	fi
}

# ---- target helpers ----
# serial_test.o and tpm_test.o need -DHOSTED_TEST
hosted_test_obj() {
	local name="$1"
	local src="${ASM_DIR}/${name}.asm"
	local dst="${ASM_BUILD}/${name}_test.o"
	if [ ! -f "$dst" ] || [ "$src" -nt "$dst" ] || [ "${ASM_DIR}/macros.inc" -nt "$dst" ]; then
		elf64_h "$src" "$dst"
		echo "  AS  ${dst}"
	fi
}

test_via_cc() {
	local name="$1"; shift
	local bin="${ASM_BUILD}/test_${name}"
	local src="${TEST_DIR}/test_${name}.c"
	assemble_shared
	test_entry
	local args=("${ASM_BUILD}/test_entry.o" "${ASM_BUILD}/runtime.o")
	for dep; do
		local d_path="${ASM_BUILD}/${dep}"
		if [ "${dep}" = "serial_test.o" ]; then
			hosted_test_obj "serial"
		elif [ "${dep}" = "tpm_test.o" ]; then
			hosted_test_obj "tpm"
		elif [ "${dep}" = "tpm_crb_test.o" ]; then
			hosted_test_obj "tpm_crb"
		elif [ ! -f "$d_path" ]; then
			local base="${dep%.o}"
			local s="${ASM_DIR}/${base}.asm"
			if [ -f "$s" ]; then
				elf64 "$s" "$d_path"
				echo "  AS  ${d_path}"
			else
				echo "error: missing dependency $dep" >&2
				exit 1
			fi
		fi
		args+=("${d_path}")
	done
	link_cc "$bin" "$src" "${args[@]}"
	echo "  LD  ${bin}"
	if [ -n "${TEST_TIMEOUT:-}" ]; then
		timeout "$TEST_TIMEOUT" "$bin"
	else
		"$bin"
	fi
}

# ---- targets ----
cmd_kernel() {
	assemble_kernel
	local objs=""
	for src in ${KERNEL_ASM_SRCS}; do
		local base="${src%.asm}"
		objs="${objs} ${ASM_BUILD}/kernel_${base}.o"
	done
	objs="${objs} ${ASM_BUILD}/kernel_main_elf32.o"
	ld -m elf_i386 -T "${KERNEL_LD}" -o "${KERNEL_ELF}" ${objs}
	strip --strip-all "${KERNEL_ELF}"
	objcopy -O binary "${KERNEL_ELF}" "${KERNEL_BIN}"
	local esize=$(stat -c '%s' "${KERNEL_ELF}")
	local bsize=$(stat -c '%s' "${KERNEL_BIN}")
	printf 'kernel: %s (%d bytes)\n' "${KERNEL_ELF}" "${esize}"
	printf 'flat:   %s (%d bytes)\n' "${KERNEL_BIN}" "${bsize}"
}

cmd_kernel_hello() {
	cmd_kernel
	qemu-system-x86_64 -machine q35 -display none -serial stdio -no-reboot \
		-kernel "${KERNEL_ELF}" -m 256
}

cmd_kernel_efi() {
	assemble_kernel_efi
	local objs=""
	for src in ${KERNEL_ASM_SRCS}; do
		local base="${src%.asm}"
		objs="${objs} ${ASM_BUILD}/kernel_efi_${base}.o"
	done
	objs="${objs} ${ASM_BUILD}/kernel_main_efi64.o"
	ld -m i386pep -T "${KERNEL_EFI_LD}" --subsystem 10 --image-base 0x100000 \
		-o "${KERNEL_EFI}" ${objs}
	local esize=$(stat -c '%s' "${KERNEL_EFI}")
	printf 'efi:  %s (%d bytes)\n' "${KERNEL_EFI}" "${esize}"
}

cmd_install_efi() {
	cmd_kernel_efi
	local esp="/boot"
	# check with sudo because /boot/EFI is often root-owned
	if ! sudo test -d "${esp}/EFI"; then
		echo "error: ESP not mounted at ${esp}" >&2
		exit 1
	fi
	local efi_dir="${esp}/EFI/edgerun"
	echo "This will:"
	echo "  cp ${KERNEL_EFI} -> ${efi_dir}/bootx64.efi"
	echo "  add UEFI boot entry 'EdgeRun' via efibootmgr"
	read -r -p "Proceed? [y/N] " reply
	case "${reply}" in
		[yY]|[yY][eE][sS]) ;;
		*) echo "abort."; exit 1 ;;
	esac
	sudo mkdir -p "${efi_dir}"
	sudo cp "${KERNEL_EFI}" "${efi_dir}/bootx64.efi"
	if efibootmgr 2>/dev/null | grep -qi 'edgerun'; then
		echo "edgerun boot entry already exists"
	else
		sudo efibootmgr -c -L "EdgeRun" -l "\\EFI\\edgerun\\bootx64.efi" \
			-d /dev/nvme0n1 -p 1 2>&1
	fi
	echo "installed ${KERNEL_EFI} -> ${efi_dir}/bootx64.efi"
	echo "reboot and select 'EdgeRun' from boot menu"
}

cmd_kernel_net() {
	cmd_kernel
	qemu-system-x86_64 -machine q35 -display none -serial stdio \
		-no-reboot -kernel "${KERNEL_ELF}" -m 256 \
		-netdev user,id=net0 \
		-device virtio-net-pci,netdev=net0
}

cmd_kernel_net_tpm() {
	cmd_kernel
	local tpm_sock="/tmp/swtpm-tpm0.sock"
	local tpm_dir="/tmp/swtpm-tpm0"
	mkdir -p "${tpm_dir}"
	rm -f "${tpm_sock}"
	swtpm socket --tpmstate dir="${tpm_dir}" \
		--ctrl type=unixio,path="${tpm_sock}" --tpm2 &
	local swtpm_pid=$!
	while [ ! -S "${tpm_sock}" ]; do sleep 0.1; done
	echo "Running QEMU with swtpm + virtio-net..."
	qemu-system-x86_64 -machine q35 -display none -serial stdio \
		-no-reboot -kernel "${KERNEL_ELF}" -m 256 \
		-chardev socket,id=chrtpm,path="${tpm_sock}" \
		-tpmdev emulator,id=tpm0,chardev=chrtpm \
		-device tpm-crb,tpmdev=tpm0 \
		-netdev user,id=net0 \
		-device virtio-net-pci,netdev=net0 || true
	kill "${swtpm_pid}" 2>/dev/null || true
	wait "${swtpm_pid}" 2>/dev/null || true
	rm -f "${tpm_sock}"
}

cmd_kernel_bt_test() {
	cmd_kernel
	BT_SOCK="/tmp/bt_mock.sock"
	PYTHON="${PYTHON:-python3}"
	rm -f "${BT_SOCK}"
	"${PYTHON}" "tools/bt_mock.py" --socket "${BT_SOCK}" &
	MOCK_PID=$!
	while [ ! -S "${BT_SOCK}" ]; do sleep 0.1; done
	echo "Running QEMU with BT mock on COM2 (Unix)..."
	qemu-system-x86_64 -machine q35 -display none -serial stdio \
		-serial unix:"${BT_SOCK}" \
		-no-reboot -kernel "${KERNEL_ELF}" -m 256 || true
	kill "${MOCK_PID}" 2>/dev/null || true
	wait "${MOCK_PID}" 2>/dev/null || true
	rm -f "${BT_SOCK}"
}

# ---- TPM live test kernel ----
cmd_kernel_tpm_live_test() {
	assemble_kernel
	# Assemble tpm_live_test_main.asm as ELF32 (has [BITS 64] via macros.inc)
	local lt_src="${ASM_DIR}/tpm_live_test_main.asm"
	local lt_dst="${ASM_BUILD}/kernel_tpm_live_test_main_elf32.o"
	elf32 "$lt_src" "$lt_dst"
	echo "  AS  ${lt_dst}"
	# Link with live test main instead of kernel_main_elf32.o
	local objs=""
	for src in ${KERNEL_ASM_SRCS}; do
		local base="${src%.asm}"
		objs="${objs} ${ASM_BUILD}/kernel_${base}.o"
	done
	objs="${objs} ${ASM_BUILD}/kernel_tpm_live_test_main_elf32.o"
	ld -m elf_i386 -T "${KERNEL_LD}" -o "${KERNEL_ELF}" ${objs}
	strip --strip-all "${KERNEL_ELF}"
	objcopy -O binary "${KERNEL_ELF}" "${KERNEL_BIN}"
	local esize=$(stat -c '%s' "${KERNEL_ELF}")
	local bsize=$(stat -c '%s' "${KERNEL_BIN}")
	printf 'kernel: %s (%d bytes)\n' "${KERNEL_ELF}" "${esize}"
	printf 'flat:   %s (%d bytes)\n' "${KERNEL_BIN}" "${bsize}"
}

cmd_kernel_tpm_live_test_qemu() {
	cmd_kernel_tpm_live_test
	local tpm_sock="/tmp/swtpm-tpm0.sock"
	local tpm_dir="/tmp/swtpm-tpm0"
	mkdir -p "${tpm_dir}"
	rm -f "${tpm_sock}"
	swtpm socket --tpmstate dir="${tpm_dir}" \
		--ctrl type=unixio,path="${tpm_sock}" --tpm2 &
	local swtpm_pid=$!
	while [ ! -S "${tpm_sock}" ]; do sleep 0.1; done
	echo "Running QEMU with swtpm + TPM live test..."
	qemu-system-x86_64 -machine q35 -display none -serial stdio \
		-no-reboot -kernel "${KERNEL_ELF}" -m 256 \
		-chardev socket,id=chrtpm,path="${tpm_sock}" \
		-tpmdev emulator,id=tpm0,chardev=chrtpm \
		-device tpm-crb,tpmdev=tpm0 || true
	kill "${swtpm_pid}" 2>/dev/null || true
	wait "${swtpm_pid}" 2>/dev/null || true
	rm -f "${tpm_sock}"
}

cmd_test() {
	cmd_test_ctype
	cmd_test_clock
	cmd_test_math
	cmd_test_runtime
	cmd_test_serial
	cmd_test_tpm
	cmd_test_wasm
	cmd_test_blake3
	cmd_test_acpi
	cmd_test_preimage
	cmd_test_bytes
	cmd_test_identity
	cmd_test_render_ir
	cmd_test_sw_fb
	cmd_test_wasm_compiler
	cmd_test_wasm_pipeline
	cmd_test_object
}

cmd_test_ctype() {
	local src="${TEST_DIR}/test_ctype_self.asm"
	local obj="${ASM_BUILD}/test_ctype_self.o"
	local bin="${ASM_BUILD}/test_ctype"
	if [ ! -f "$obj" ] || [ "$src" -nt "$obj" ] || [ "${ASM_DIR}/macros.inc" -nt "$obj" ]; then
		${YASM} -f elf64 ${ASM_INC} -o "$obj" "$src"
	fi
	local ctype_o="${ASM_BUILD}/ctype.o"
	if [ ! -f "$ctype_o" ]; then
		elf64 "${ASM_DIR}/ctype.asm" "$ctype_o"
	fi
	ld -nostdlib -static -o "$bin" "$obj" "$ctype_o"
	echo "  LD  ${bin}"
	"$bin"
}

cmd_test_sw_fb() {
	local src="${TEST_DIR}/test_sw_fb_self.asm"
	local obj="${ASM_BUILD}/test_sw_fb_self.o"
	local bin="${ASM_BUILD}/test_sw_fb"
	if [ ! -f "$obj" ] || [ "$src" -nt "$obj" ] || [ "${ASM_DIR}/macros.inc" -nt "$obj" ]; then
		${YASM} -f elf64 ${ASM_INC} -o "$obj" "$src"
	fi
	local sw_fb_o="${ASM_BUILD}/sw_fb.o"
	if [ ! -f "$sw_fb_o" ]; then
		elf64 "${ASM_DIR}/sw_fb.asm" "$sw_fb_o"
	fi
	ld -nostdlib -static -o "$bin" "$obj" "$sw_fb_o"
	echo "  LD  ${bin}"
	"$bin"
}

cmd_test_math()     { test_via_cc "math"     "math.o"; }
cmd_test_runtime()  { test_via_cc "runtime"; }
cmd_test_serial()   { test_via_cc "serial"   "serial_test.o"; }
cmd_test_tpm()      { test_via_cc "tpm"      "tpm_test.o" "tpm_crb_test.o"; }
cmd_test_wasm()     { TEST_TIMEOUT=5 test_via_cc "wasm"     "wasm_interpreter.o"; }
cmd_test_wasm_compiler() { TEST_TIMEOUT=10 test_via_cc "wasm_compiler" "wasm_compiler.o" "wasm_compiler_source.o"; }
cmd_test_wasm_pipeline() { TEST_TIMEOUT=5 test_via_cc "wasm_pipeline" "wasm_interpreter.o" "wasm_module.o"; }
cmd_test_blake3()   { test_via_cc "blake3"   "blake3.o"; }
cmd_test_bytes()    { test_via_cc "bytes"    "bytes.o"; }
cmd_test_clock()    { test_via_cc "clock"    "clock.o" "bytes.o"; }
cmd_test_acpi()     { test_via_cc "acpi"     "acpi.o"; }
cmd_test_preimage() { test_via_cc "preimage" "preimage.o" "blake3.o" "clock.o" "bytes.o"; }
cmd_test_identity() { test_via_cc "identity" "identity.o" "blake3.o" "clock.o" "bytes.o"; }
cmd_test_object()   { test_via_cc "object"   "object.o" "preimage.o" "blake3.o" "clock.o" "bytes.o"; }

cmd_test_render_ir() {
	local src="${TEST_DIR}/test_render_ir_self.asm"
	local obj="${ASM_BUILD}/test_render_ir_self.o"
	local bin="${ASM_BUILD}/test_render_ir"
	if [ ! -f "$obj" ] || [ "$src" -nt "$obj" ] || [ "${ASM_DIR}/macros.inc" -nt "$obj" ]; then
		${YASM} -f elf64 ${ASM_INC} -o "$obj" "$src"
	fi
	local render_ir_o="${ASM_BUILD}/render_ir.o"
	if [ ! -f "$render_ir_o" ]; then
		elf64 "${ASM_DIR}/render_ir.asm" "$render_ir_o"
	fi
	local sw_fb_o="${ASM_BUILD}/sw_fb.o"
	if [ ! -f "$sw_fb_o" ]; then
		elf64 "${ASM_DIR}/sw_fb.asm" "$sw_fb_o"
	fi
	ld -nostdlib -static -o "$bin" "$obj" "$render_ir_o" "$sw_fb_o"
	echo "  LD  ${bin}"
	"$bin"
}

# ---- ARM / Pi Zero targets ----
ASM_ARM_DIR="asm/arm/pi"
ARM_AS="${ARM_AS:-arm-none-eabi-as}"
ARM_LD="${ARM_LD:-arm-none-eabi-ld}"
ARM_OBJCOPY="${ARM_OBJCOPY:-arm-none-eabi-objcopy}"
ARM_LD_SCRIPT="${ASM_ARM_DIR}/linker.ld"
PI_BUILD="${BUILD_DIR}/pi"
PI_KERNEL_ELF="${PI_BUILD}/kernel.elf"
PI_KERNEL_IMG="${PI_BUILD}/kernel.img"

# Host USB/serial boot tools
HOST_BUILD="${BUILD_DIR}/host"
PI_USB_BOOT="${HOST_BUILD}/pi_usb_boot_host"
ESP32_BOOT="${HOST_BUILD}/esp32_serial_boot_host"

arm_obj() {
	mkdir -p "${PI_BUILD}"
	${ARM_AS} -mcpu=arm1176jzf-s -I asm -o "$2" "$1"
}

cmd_pi_kernel() {
	mkdir -p "${PI_BUILD}"
	arm_obj "${ASM_ARM_DIR}/start.asm" "${PI_BUILD}/start.o"
	arm_obj "${ASM_ARM_DIR}/emmc.asm" "${PI_BUILD}/emmc.o"
	arm_obj "${ASM_ARM_DIR}/dwc2.asm" "${PI_BUILD}/dwc2.o"
	${ARM_LD} -T "${ARM_LD_SCRIPT}" -o "${PI_KERNEL_ELF}" "${PI_BUILD}/start.o" "${PI_BUILD}/emmc.o" "${PI_BUILD}/dwc2.o"
	${ARM_OBJCOPY} -O binary "${PI_KERNEL_ELF}" "${PI_KERNEL_IMG}"
	local esize=$(stat -c '%s' "${PI_KERNEL_ELF}" 2>/dev/null || echo 0)
	local bsize=$(stat -c '%s' "${PI_KERNEL_IMG}" 2>/dev/null || echo 0)
	printf 'pi-kernel: %s (%d bytes)\n' "${PI_KERNEL_ELF}" "${esize}"
	printf '  img:     %s (%d bytes)\n' "${PI_KERNEL_IMG}" "${bsize}"
}

cmd_pi_usb_boot() {
	mkdir -p "${HOST_BUILD}"
	local src="asm/host/pi_usb_boot_host.asm"
	local obj="${HOST_BUILD}/pi_usb_boot_host.o"
	${YASM} -f elf64 -I asm -o "$obj" "$src"
	ld -o "${PI_USB_BOOT}" "$obj"
	echo "  LD  ${PI_USB_BOOT}"
}

cmd_pi_boot() {
	cmd_pi_kernel
	cmd_pi_usb_boot
	if [ -f "${PI_USB_BOOT}" ]; then
		"${PI_USB_BOOT}" --wait --serve-dir "${PI_BUILD}" --kernel-image "${PI_KERNEL_IMG}"
	fi
}

cmd_esp32_serial_boot() {
	mkdir -p "${HOST_BUILD}"
	local src="asm/host/esp32_serial_boot_host.asm"
	local obj="${HOST_BUILD}/esp32_serial_boot_host.o"
	${YASM} -f elf64 -I asm -o "$obj" "$src"
	ld -o "${ESP32_BOOT}" "$obj"
	echo "  LD  ${ESP32_BOOT}"
}

cmd_clean() {
	rm -rf "${BUILD_DIR}"
}

cmd_help() {
	cat <<'EOF'
EdgeRun build targets:
  kernel              Build kernel.elf + kernel.bin
  kernel-hello        Build kernel + run in QEMU
  kernel-bt-test      Build kernel + run in QEMU with mock BT on COM2
  kernel-net          Build kernel + run in QEMU with virtio-net
  kernel-net-tpm      Build kernel + run in QEMU with swtpm + virtio-net
  kernel-tpm-live-test    Build kernel with TPM live test main
  kernel-tpm-live-test-qemu Build + run in QEMU with swtpm
  kernel-efi          Build kernel.efi (native UEFI PE32+)
  install-efi         Build + install kernel.efi to ESP + add boot entry
  test                Run all assembly tests
  test-ctype          Run ctype test (self-hosted ASM runner)
  test-clock          Run clock test
  test-math           Run math test
  test-runtime        Run runtime test
  test-serial         Run serial test
  test-tpm            Run TPM test
  test-wasm           Run WASM interpreter test
  test-blake3         Run BLAKE3 test
  test-acpi           Run ACPI test
  test-preimage       Run preimage test
  test-bytes          Run bytes test
  test-identity       Run identity test
  test-render-ir      Run render IR test (self-hosted ASM runner)
  test-sw-fb          Run software framebuffer test (self-hosted ASM runner)
  test-wasm-compiler  Run WASM compiler test
  test-wasm-pipeline  Run WASM module pipeline test
  test-object         Run object serialization test
  pi-kernel           Build Pi Zero W kernel.img (ARMv6)
  pi-usb-boot         Build Pi USB boot host tool (x86_64)
  pi-boot             Build + boot Pi Zero via USB
  esp32-serial-boot   Build ESP32 serial boot host tool (x86_64)
  clean               Remove .build/
EOF
}

# ---- dispatch ----
case "${1:-help}" in
	kernel)         cmd_kernel ;;
	kernel-hello)   cmd_kernel_hello ;;
	kernel-bt-test)         cmd_kernel_bt_test ;;
  	kernel-net)             cmd_kernel_net ;;
  	kernel-net-tpm)         cmd_kernel_net_tpm ;;
	kernel-tpm-live-test)   cmd_kernel_tpm_live_test ;;
	kernel-tpm-live-test-qemu) cmd_kernel_tpm_live_test_qemu ;;
  	kernel-efi)     cmd_kernel_efi ;;
 	install-efi)    cmd_install_efi ;;
 	test)           cmd_test ;;
	test-ctype)     cmd_test_ctype ;;
	test-clock)     cmd_test_clock ;;
	test-math)      cmd_test_math ;;
	test-runtime)   cmd_test_runtime ;;
	test-serial)    cmd_test_serial ;;
	test-tpm)       cmd_test_tpm ;;
	test-wasm)      cmd_test_wasm ;;
	test-blake3)    cmd_test_blake3 ;;
	test-acpi)      cmd_test_acpi ;;
	test-preimage)  cmd_test_preimage ;;
	test-bytes)     cmd_test_bytes ;;
	test-identity)  cmd_test_identity ;;
	test-render-ir) cmd_test_render_ir ;;
	test-sw-fb)     cmd_test_sw_fb ;;
	test-wasm-compiler) cmd_test_wasm_compiler ;;
	test-wasm-pipeline) cmd_test_wasm_pipeline ;;
	test-object)    cmd_test_object ;;
	pi-kernel)      cmd_pi_kernel ;;
	pi-usb-boot)       cmd_pi_usb_boot ;;
	pi-boot)           cmd_pi_boot ;;
	esp32-serial-boot) cmd_esp32_serial_boot ;;
	clean)          cmd_clean ;;
	help|--help|-h) cmd_help ;;
	*)
		echo "unknown target: $1" >&2
		echo "usage: ./build.sh <target>" >&2
		cmd_help >&2
		exit 1
		;;
esac
