#!/usr/bin/env bash
# EdgeRun build script — explicit, no pattern rules, no Makefile magic.
# Usage:  ./build.sh <target>
# Targets:  kernel  kernel-hello  test  test-*  clean
set -euo pipefail

# Disable all forms of disk-based caching
export CCACHE_DISABLE=1
export SCCACHE_DISABLE=1
export PYTHONDONTWRITEBYTECODE=1
export CARGO_INCREMENTAL=0
unset CARGO_HOME
unset GOCACHE

BUILD_DIR=".build"
ASM_BUILD="${BUILD_DIR}/kernel"
ASM_DIR="kernel/x86_64"
TEST_DIR="kernel/test"
YASM="${YASM:-yasm}"
ASM_INC="-I kernel"
KERNEL_LD="${ASM_DIR}/linker.ld"
KERNEL_EFI_LD="${ASM_DIR}/efi_linker.ld"
KERNEL_ELF="${ASM_BUILD}/kernel.elf"
KERNEL_EFI="${ASM_BUILD}/kernel.efi"
KERNEL_BIN="${ASM_BUILD}/kernel.bin"
EFI_ESP="${EFI_ESP:-/boot}"
EFI_BOOT_DIR="${EFI_ESP}/EFI/edgerun"
EFI_BOOT_PATH="${EFI_BOOT_DIR}/bootx64.efi"

# ---- helpers ----
mkdir -p "${ASM_BUILD}"

elf64()   { ${YASM} -f elf64   ${ASM_INC} ${ASM_DEFS:-} -o "$2" "$1" && test -f "$2"; }
elf32()   { ${YASM} -f elf32   ${ASM_INC} ${ASM_DEFS:-} -o "$2" "$1" && test -f "$2"; }
elf64_dbg() { ${YASM} -f elf64 ${ASM_INC} ${ASM_DEFS:-} -dX25519_DEBUG -o "$2" "$1" && test -f "$2"; }

# Build object list string from KERNEL_ASM_SRCS with given prefix/suffix
# Usage: kernel_objs <prefix> <suffix> [extra_objects...]
kernel_objs() {
	local prefix="$1" suffix="$2"; shift 2
	local objs=""
	for src in ${KERNEL_ASM_SRCS}; do
		local name="${src%.asm}"; name="${name##*/}"
		objs="${objs} ${ASM_BUILD}/${prefix}_${name}${suffix}"
	done
	for extra; do
		objs="${objs} ${ASM_BUILD}/${extra}"
	done
	echo "${objs}"
}

# ---- kernel objects (elf32) ----
KERNEL_ASM_SRCS="
	crypto/blake3.asm
	rt/bytes.asm
	rt/clock.asm
	rt/ctype.asm
	crypto/identity.asm
	rt/math.asm
	rt/runtime.asm
	../driver/serial.asm
	tpm/tpm.asm
	tpm/tpm_crb.asm
	../driver/cmos.asm
	../driver/i8042.asm
	../driver/cros_ec.asm
	../driver/dw_i2c.asm
	../driver/i2c_hid.asm
	../driver/pci.asm
	../driver/nvme.asm
	../driver/store.asm
	../driver/amdgpu.asm
	crypto/preimage.asm
	../driver/display.asm
	../driver/fb_text.asm
	../driver/acpi.asm
	../driver/portio.asm
	../driver/hda.asm
	../driver/xhci.asm
	../driver/uvc.asm
	../driver/rtl8125.asm
	../driver/rtl8922.asm
	../driver/ax210.asm
	../driver/bt.asm
	../driver/virtio.asm
	../driver/virtio_gpu.asm
	../driver/virtio_net.asm
	../driver/smn.asm
	../driver/psp_mailbox.asm
	../driver/psp_rom_armor.asm
	../driver/spi_flash.asm
	../driver/intel_sdhci.asm
	../driver/intel_gpu.asm
	net/net.asm
	net/arp.asm
	net/ipv4.asm
	net/tcp.asm
	net/http.asm
	crypto/sha256.asm
	crypto/sha3.asm
	crypto/curve25519.asm
	crypto/tor_ntor.asm
	crypto/tor_aes.asm
	crypto/tls.asm
	crypto/tor_cell.asm
	crypto/tor_digest.asm
	crypto/tor_hs.asm
	crypto/tor_hs_app.asm
	crypto/tor.asm
	crypto/local_cell.asm
	crypto/local_route.asm
	crypto/local_circuit.asm
	agent/http_agent.asm
	agent/da.asm
	agent/da_wasm.asm
	agent/input_kbd.asm
	ui/render_ir.asm
	ui/sw_fb.asm
	wasm/wasm_interpreter.asm
	wasm/wasm_compiler.asm
	wasm/wasm_test_data.asm
	wasm/da_wasm_test.asm
	wasm/edgerun_signing_wasm.asm
	entry.asm
"

# ---- assemble_kernel ----
assemble_kernel() {
	for src in ${KERNEL_ASM_SRCS}; do
		local base="${src%.asm}"
		local name="${base##*/}"
		local src_path="${ASM_DIR}/${src}"
		local dst="${ASM_BUILD}/kernel_${name}.o"
		elf32 "$src_path" "$dst"
		echo "  AS  ${dst}"
	done
	# kernel_main — source name != target
	local km_src="${ASM_DIR}/kernel_main.asm"
	local km_dst="${ASM_BUILD}/kernel_main_elf32.o"
	elf32 "$km_src" "$km_dst"
	echo "  AS  ${km_dst}"
}

# ---- assemble_kernel_efi (elf64, for PE32+) ----
assemble_kernel_efi() {
	for src in ${KERNEL_ASM_SRCS}; do
		local base="${src%.asm}"
		local name="${base##*/}"
		local src_path="${ASM_DIR}/${src}"
		if [ "$name" = "entry" ]; then
			src_path="${ASM_DIR}/efi_entry.asm"
		fi
		local dst="${ASM_BUILD}/kernel_efi_${name}.o"
		elf64 "$src_path" "$dst"
		echo "  AS  ${dst}"
	done
	# kernel_main as ELF64
	local km_src="${ASM_DIR}/kernel_main.asm"
	local km_dst="${ASM_BUILD}/kernel_main_efi64.o"
	elf64 "$km_src" "$km_dst"
	echo "  AS  ${km_dst}"
}

# ---- targets ----
cmd_kernel() {
	cmd_signing_wasm
	assemble_kernel
	local objs=$(kernel_objs "kernel" ".o" "kernel_main_elf32.o")
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

cmd_kernel_vnc() {
	cmd_kernel
	qemu-system-x86_64 -machine q35 -vga std -vnc :0 -serial stdio -no-reboot \
		-kernel "${KERNEL_ELF}" -m 256
}

cmd_kernel_efi() {
	cmd_signing_wasm
	assemble_kernel_efi
	local objs=$(kernel_objs "kernel_efi" ".o" "kernel_main_efi64.o")
	ld -m i386pep -T "${KERNEL_EFI_LD}" --subsystem 10 --image-base 0x100000 \
		-o "${KERNEL_EFI}" ${objs}
	local esize=$(stat -c '%s' "${KERNEL_EFI}")
	printf 'efi:  %s (%d bytes)\n' "${KERNEL_EFI}" "${esize}"
	sync_kernel_efi_to_esp
}

sync_kernel_efi_to_esp() {
	if ! sudo -n test -d "${EFI_ESP}/EFI"; then
		echo "error: ESP not mounted at ${EFI_ESP}" >&2
		exit 1
	fi
	sudo -n mkdir -p "${EFI_BOOT_DIR}"
	sudo -n install -m 0644 "${KERNEL_EFI}" "${EFI_BOOT_PATH}"
	sudo -n sync
	echo "installed ${KERNEL_EFI} -> ${EFI_BOOT_PATH}"
}

cmd_install_efi() {
	cmd_kernel_efi
	if efibootmgr 2>/dev/null | grep -qi 'edgerun'; then
		echo "edgerun boot entry already exists"
	else
		sudo -n efibootmgr -c -L "EdgeRun" -l "\\EFI\\edgerun\\bootx64.efi" \
			-d /dev/nvme0n1 -p 1 2>&1
	fi
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
		-netdev user,id=net0,guestfwd=tcp:10.0.2.100:19001-cmd:nc\ 127.0.0.1\ 19001 \
		-device virtio-net-pci,netdev=net0 || true
	kill "${swtpm_pid}" 2>/dev/null || true
	wait "${swtpm_pid}" 2>/dev/null || true
	rm -f "${tpm_sock}"
}

cmd_kernel_net_tor() {
	ASM_DEFS="${ASM_DEFS:-} -dER_KERNEL_TOR_AUTOSTART" cmd_kernel_net_tpm
}

# ---- TPM live test kernel ----
cmd_kernel_tpm_live_test() {
	assemble_kernel
	# Assemble tpm_live_test_main.asm as ELF32 (has [BITS 64] via macros.inc)
	local lt_src="${ASM_DIR}/tpm/tpm_live_test_main.asm"
	local lt_dst="${ASM_BUILD}/kernel_tpm_live_test_main_elf32.o"
	elf32 "$lt_src" "$lt_dst"
	echo "  AS  ${lt_dst}"
	# Link with live test main instead of kernel_main_elf32.o
	local objs=$(kernel_objs "kernel" ".o" "kernel_tpm_live_test_main_elf32.o")
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

# Build a standalone self-hosted ASM test.
# Usage: build_test <obj_name> <asm_src> [<dep_path>...]
# Each dep_path is relative to ASM_DIR (without .asm suffix).
build_test() {
	local name="$1"; shift
	local src="$1"; shift
	local obj="${ASM_BUILD}/${name}.o"
	local bin="${ASM_BUILD}/${name%_self}"
	${YASM} -f elf64 ${ASM_INC} -o "$obj" "$src"
	local extra_o=""
	for dep; do
		local dep_obj="${ASM_BUILD}/${dep##*/}.o"
		local dep_src="${ASM_DIR}/${dep}.asm"
		if [ ! -f "$dep_obj" ]; then
			elf64 "$dep_src" "$dep_obj"
		fi
		extra_o="$extra_o $dep_obj"
	done
	ld -nostdlib -static -o "$bin" "$obj" $extra_o
	echo "  LD  ${bin}"
	"$bin"
}

cmd_test() {
	cmd_test_ctype
	cmd_test_clock
	cmd_test_http
	cmd_test_serial
	cmd_test_cros_ec
	cmd_test_amdgpu
	cmd_test_uvc
	cmd_test_sw_fb
	cmd_test_render_ir
	cmd_test_fe_mul
	cmd_test_spi_flash
	cmd_test_pi_audio
	cmd_test_pi_bt
	cmd_test_pi_gpu
	cmd_test_pi_gpio
	cmd_test_pi_sd
	cmd_test_pi_usb
	cmd_test_pi_wifi_sdio
	cmd_test_sha3
	cmd_test_tls
	cmd_test_tor
	cmd_test_tor_cell
	cmd_test_tor_hs
	cmd_test_tor_hs_app
	cmd_test_local_route
	cmd_test_x25519
	cmd_test_wasm_compiler
	cmd_test_wasm_jit
	cmd_test_recursion_valid
	cmd_test_recursion_invalid
	cmd_test_wasm_float
}

cmd_test_recursion_valid() {
	local name="test_recursion_valid"
	local src="${TEST_DIR}/${name}.asm"
	local obj="${ASM_BUILD}/${name}.o"
	local bin="${ASM_BUILD}/${name}"
	${YASM} -f elf64 ${ASM_INC} -o "$obj" "$src"
	local dep_obj="${ASM_BUILD}/runtime.o"
	if [ ! -f "$dep_obj" ]; then
		elf64 "${ASM_DIR}/rt/runtime.asm" "$dep_obj"
	fi
	ld -T "${TEST_DIR}/test_jit.ld" -nostdlib -static -o "$bin" "$obj" "$dep_obj"
	echo "  LD  ${bin}"
	"$bin"
}

cmd_test_recursion_invalid() {
	local name="test_recursion_invalid"
	local src="${TEST_DIR}/${name}.asm"
	local obj="${ASM_BUILD}/${name}.o"
	local bin="${ASM_BUILD}/${name}"
	${YASM} -f elf64 ${ASM_INC} -o "$obj" "$src"
	local dep_obj="${ASM_BUILD}/runtime.o"
	if [ ! -f "$dep_obj" ]; then
		elf64 "${ASM_DIR}/rt/runtime.asm" "$dep_obj"
	fi
	ld -T "${TEST_DIR}/test_jit.ld" -nostdlib -static -o "$bin" "$obj" "$dep_obj"
	echo "  LD  ${bin}"
	"$bin"
}

cmd_test_wasm_jit() {
	local name="test_wasm_jit_self"
	local src="${TEST_DIR}/${name}.asm"
	local obj="${ASM_BUILD}/${name}.o"
	local bin="${ASM_BUILD}/${name%_self}"
	${YASM} -f elf64 ${ASM_INC} -o "$obj" "$src"
	local dep_obj="${ASM_BUILD}/runtime.o"
	if [ ! -f "$dep_obj" ]; then
		elf64 "${ASM_DIR}/rt/runtime.asm" "$dep_obj"
	fi
	ld -T "${TEST_DIR}/test_jit.ld" -nostdlib -static -o "$bin" "$obj" "$dep_obj"
	echo "  LD  ${bin}"
	"$bin"
}

cmd_test_wasm_compiler() {
	local name="test_wasm_compiler_self"
	local src="${TEST_DIR}/${name}.asm"
	local obj="${ASM_BUILD}/${name}.o"
	local bin="${ASM_BUILD}/${name%_self}"
	${YASM} -f elf64 ${ASM_INC} -o "$obj" "$src"
	local dep_obj="${ASM_BUILD}/runtime.o"
	if [ ! -f "$dep_obj" ]; then
		elf64 "${ASM_DIR}/rt/runtime.asm" "$dep_obj"
	fi
	ld -T "${TEST_DIR}/test_jit.ld" -nostdlib -static -o "$bin" "$obj" "$dep_obj"
	echo "  LD  ${bin}"
	"$bin"
}

cmd_test_ctype() {
	build_test "test_ctype_self" "${TEST_DIR}/test_ctype_self.asm" "rt/ctype"
}

cmd_test_clock() {
	build_test "test_clock_self" "${TEST_DIR}/test_clock_self.asm" "rt/clock" "rt/bytes" "rt/runtime"
}

cmd_test_serial() {
	build_test "test_serial_self" "${TEST_DIR}/test_serial_self.asm" "../driver/serial" "rt/runtime"
}

cmd_test_uvc() {
	local src="${TEST_DIR}/test_uvc_self.asm"
	local obj="${ASM_BUILD}/test_uvc_self.o"
	local stub_src="${TEST_DIR}/stubs_xhci.asm"
	local stub_obj="${ASM_BUILD}/stubs_xhci.o"
	local bin="${ASM_BUILD}/test_uvc"
	${YASM} -f elf64 ${ASM_INC} -o "$obj" "$src"
	${YASM} -f elf64 ${ASM_INC} -o "$stub_obj" "$stub_src"
	local uvc_o="${ASM_BUILD}/uvc.o"
	elf64 "${ASM_DIR}/../driver/uvc.asm" "$uvc_o"
	local xhci_o="${ASM_BUILD}/xhci.o"
	elf64 "${ASM_DIR}/../driver/xhci.asm" "$xhci_o"
	ld -nostdlib -static -o "$bin" "$obj" "$uvc_o" "$xhci_o" "$stub_obj"
	echo "  LD  ${bin}"
	"$bin"
}

cmd_test_http() {
	local src="${TEST_DIR}/test_http_self.asm"
	local obj="${ASM_BUILD}/test_http_self.o"
	local stub_src="${TEST_DIR}/stubs_http.asm"
	local stub_obj="${ASM_BUILD}/stubs_http.o"
	local bin="${ASM_BUILD}/test_http"
	${YASM} -f elf64 ${ASM_INC} -o "$obj" "$src"
	${YASM} -f elf64 ${ASM_INC} -o "$stub_obj" "$stub_src"
	local http_o="${ASM_BUILD}/http.o"
	if [ ! -f "$http_o" ]; then
		elf64 "${ASM_DIR}/net/http.asm" "$http_o"
	fi
	ld -nostdlib -static -o "$bin" "$obj" "$http_o" "$stub_obj"
	echo "  LD  ${bin}"
	"$bin"
}

cmd_test_wasm_float() {
	local name="test_wasm_float"
	local src="${TEST_DIR}/${name}.asm"
	local obj="${ASM_BUILD}/${name}.o"
	local bin="${ASM_BUILD}/${name}"
	${YASM} -f elf64 ${ASM_INC} -o "$obj" "$src"
	local dep_obj="${ASM_BUILD}/runtime.o"
	if [ ! -f "$dep_obj" ]; then
		elf64 "${ASM_DIR}/rt/runtime.asm" "$dep_obj"
	fi
	ld -T "${TEST_DIR}/test_jit.ld" -nostdlib -static -o "$bin" "$obj" "$dep_obj"
	echo "  LD  ${bin}"
	"$bin"
}

cmd_test_sw_fb() {
	build_test "test_sw_fb_self" "${TEST_DIR}/test_sw_fb_self.asm" "ui/sw_fb"
}

cmd_test_render_ir() {
	build_test "test_render_ir_self" "${TEST_DIR}/test_render_ir_self.asm" "ui/render_ir" "ui/sw_fb"
}

cmd_test_fe_mul() {
	local src="${TEST_DIR}/test_fe_mul.asm"
	local obj="${ASM_BUILD}/test_fe_mul.o"
	local stub_src="${TEST_DIR}/stubs_tor_ntor.asm"
	local stub_obj="${ASM_BUILD}/stubs_tor_ntor.o"
	local bin="${ASM_BUILD}/test_fe_mul"
	${YASM} -f elf64 ${ASM_INC} -o "$obj" "$src"
	${YASM} -f elf64 ${ASM_INC} -o "$stub_obj" "$stub_src"
	local tor_ntor_o="${ASM_BUILD}/tor_ntor.o"
	if [ ! -f "$tor_ntor_o" ]; then
		elf64 "${ASM_DIR}/crypto/tor_ntor.asm" "$tor_ntor_o"
	fi
	local runtime_o="${ASM_BUILD}/runtime.o"
	if [ ! -f "$runtime_o" ]; then
		elf64 "${ASM_DIR}/rt/runtime.asm" "$runtime_o"
	fi
	local curve25519_o="${ASM_BUILD}/curve25519.o"
	if [ ! -f "$curve25519_o" ]; then
		elf64 "${ASM_DIR}/crypto/curve25519.asm" "$curve25519_o"
	fi
	ld -nostdlib -static -o "$bin" "$obj" "$curve25519_o" "$tor_ntor_o" "$runtime_o" "$stub_obj"
	echo "  LD  ${bin}"
	"$bin"
}

cmd_test_spi_flash() {
	build_test "test_spi_flash_self" "${TEST_DIR}/test_spi_flash_self.asm"
}

cmd_test_pi_arm() {
	mkdir -p "${PI_BUILD}"
	local name="$1"
	local test_obj="${PI_BUILD}/${name}.o"
	local elf="${PI_BUILD}/${name%_self}.elf"
	shift
	${ARM_AS} -mcpu=arm1176jzf-s -I kernel -o "$test_obj" "${TEST_DIR}/${name}.asm"
	local objs=("$test_obj")
	local src
	for src in "$@"; do
		local obj="${PI_BUILD}/$(basename "${src%.asm}")_${name}.o"
		arm_obj "$src" "$obj"
		objs+=("$obj")
	done
	${ARM_LD} -T "${ARM_LD_SCRIPT}" -o "$elf" "${objs[@]}"
	echo "  LD  ${elf}"
	timeout 8s qemu-system-arm -M raspi0 -semihosting -display none -serial none -kernel "$elf"
}

cmd_test_pi_bt() {
	cmd_test_pi_arm "test_pi_bt_self" "${ASM_ARM_DIR}/bt.asm" "${ASM_ARM_DIR}/gpio.asm"
}

cmd_test_pi_audio() {
	cmd_test_pi_arm "test_pi_audio_self" "${ASM_ARM_DIR}/audio.asm"
}

cmd_test_pi_gpu() {
	cmd_test_pi_arm "test_pi_gpu_self" "${ASM_ARM_DIR}/gpu.asm"
}

cmd_test_pi_wifi_sdio() {
	cmd_test_pi_arm "test_pi_wifi_sdio_self" "${ASM_ARM_DIR}/emmc.asm"
}

cmd_test_pi_gpio() {
	cmd_test_pi_arm "test_pi_gpio_self" "${ASM_ARM_DIR}/gpio.asm"
}

cmd_test_pi_sd() {
	cmd_test_pi_arm "test_pi_sd_self" "${ASM_ARM_DIR}/emmc.asm"
}

cmd_test_pi_usb() {
	cmd_test_pi_arm "test_pi_usb_self" "${ASM_ARM_DIR}/dwc2.asm"
}

cmd_test_cros_ec() {
	local name="test_cros_ec_self"
	local src="${TEST_DIR}/${name}.asm"
	local obj="${ASM_BUILD}/${name}.o"
	local bin="${ASM_BUILD}/${name%_self}"
	${YASM} -f elf64 ${ASM_INC} -o "$obj" "$src"
	local cros_ec_o="${ASM_BUILD}/cros_ec_hosted.o"
	${YASM} -f elf64 ${ASM_INC} -dHOSTED_TEST -o "$cros_ec_o" "${ASM_DIR}/../driver/cros_ec.asm"
	ld -nostdlib -static -o "$bin" "$obj" "$cros_ec_o"
	echo "  LD  ${bin}"
	"$bin"
}

cmd_test_amdgpu() {
	local name="test_amdgpu_self"
	local src="${TEST_DIR}/${name}.asm"
	local obj="${ASM_BUILD}/${name}.o"
	local bin="${ASM_BUILD}/${name%_self}"
	${YASM} -f elf64 ${ASM_INC} -o "$obj" "$src"
	local amdgpu_o="${ASM_BUILD}/amdgpu_hosted.o"
	${YASM} -f elf64 ${ASM_INC} -o "$amdgpu_o" "${ASM_DIR}/../driver/amdgpu.asm"
	ld -nostdlib -static -o "$bin" "$obj" "$amdgpu_o"
	echo "  LD  ${bin}"
	"$bin"
}

cmd_test_tls() {
	local name="test_tls_self"
	local src="${TEST_DIR}/${name}.asm"
	local obj="${ASM_BUILD}/${name}.o"
	local bin="${ASM_BUILD}/${name%_self}"
	${YASM} -f elf64 ${ASM_INC} -o "$obj" "$src"
	local tls_o="${ASM_BUILD}/tls.o"
	elf64 "${ASM_DIR}/crypto/tls.asm" "$tls_o"
	local tor_aes_o="${ASM_BUILD}/tor_aes.o"
	elf64 "${ASM_DIR}/crypto/tor_aes.asm" "$tor_aes_o"
	local runtime_o="${ASM_BUILD}/runtime.o"
	elf64 "${ASM_DIR}/rt/runtime.asm" "$runtime_o"
	ld -nostdlib -static -o "$bin" "$obj" "$tls_o" "$tor_aes_o" "$runtime_o"
	echo "  LD  ${bin}"
	"$bin"
}

cmd_test_sha3() {
	build_test "test_sha3_self" "${TEST_DIR}/test_sha3_self.asm" "crypto/sha3"
}

cmd_test_tor() {
	local name="test_tor_self"
	local src="${TEST_DIR}/${name}.asm"
	local obj="${ASM_BUILD}/${name}.o"
	local bin="${ASM_BUILD}/${name%_self}"
	${YASM} -f elf64 ${ASM_INC} -o "$obj" "$src"
	local tor_aes_o="${ASM_BUILD}/tor_aes.o"
	elf64 "${ASM_DIR}/crypto/tor_aes.asm" "$tor_aes_o"
	local tor_o="${ASM_BUILD}/tor.o"
	elf64 "${ASM_DIR}/crypto/tor.asm" "$tor_o"
	local runtime_o="${ASM_BUILD}/runtime.o"
	elf64 "${ASM_DIR}/rt/runtime.asm" "$runtime_o"
	ld -nostdlib -static -o "$bin" "$obj" "$tor_aes_o" "$tor_o" "$runtime_o"
	echo "  LD  ${bin}"
	"$bin"
}

cmd_test_tor_cell() {
	build_test "test_tor_cell_self" "${TEST_DIR}/test_tor_cell_self.asm" "crypto/tor_cell"
}

cmd_test_tor_hs() {
	build_test "test_tor_hs_self" "${TEST_DIR}/test_tor_hs_self.asm" "crypto/tor_hs" "crypto/sha3" "crypto/tor_aes" "crypto/curve25519" "rt/runtime"
}

cmd_test_tor_hs_app() {
	build_test "test_tor_hs_app_self" "${TEST_DIR}/test_tor_hs_app_self.asm" "crypto/tor_hs_app" "rt/runtime"
}

cmd_test_local_route() {
	build_test "test_local_route_self" "${TEST_DIR}/test_local_route_self.asm" "crypto/local_cell" "crypto/local_route" "crypto/local_circuit" "rt/runtime"
}

cmd_bench_tor() {
	local name="bench_tor"
	local src="${TEST_DIR}/test_tor_self.asm"
	local obj="${ASM_BUILD}/${name}.o"
	local bin="${ASM_BUILD}/${name}"
	${YASM} -f elf64 ${ASM_INC} -dTOR_BENCH -o "$obj" "$src"
	local tor_aes_o="${ASM_BUILD}/tor_aes.o"
	elf64 "${ASM_DIR}/crypto/tor_aes.asm" "$tor_aes_o"
	local tor_o="${ASM_BUILD}/tor.o"
	elf64 "${ASM_DIR}/crypto/tor.asm" "$tor_o"
	local runtime_o="${ASM_BUILD}/runtime.o"
	elf64 "${ASM_DIR}/rt/runtime.asm" "$runtime_o"
	ld -nostdlib -static -o "$bin" "$obj" "$tor_aes_o" "$tor_o" "$runtime_o"
	echo "  LD  ${bin}"
	"$bin"
}

cmd_bench_tor_hs() {
	local name="bench_tor_hs"
	local src="${TEST_DIR}/test_tor_hs_self.asm"
	local obj="${ASM_BUILD}/${name}.o"
	local bin="${ASM_BUILD}/${name}"
	${YASM} -f elf64 ${ASM_INC} -DHS_BENCH -o "$obj" "$src"
	local tor_hs_o="${ASM_BUILD}/tor_hs.o"
	elf64 "${ASM_DIR}/crypto/tor_hs.asm" "$tor_hs_o"
	local sha3_o="${ASM_BUILD}/sha3.o"
	elf64 "${ASM_DIR}/crypto/sha3.asm" "$sha3_o"
	local tor_aes_o="${ASM_BUILD}/tor_aes.o"
	elf64 "${ASM_DIR}/crypto/tor_aes.asm" "$tor_aes_o"
	local curve25519_o="${ASM_BUILD}/curve25519.o"
	elf64 "${ASM_DIR}/crypto/curve25519.asm" "$curve25519_o"
	local runtime_o="${ASM_BUILD}/runtime.o"
	elf64 "${ASM_DIR}/rt/runtime.asm" "$runtime_o"
	ld -nostdlib -static -o "$bin" "$obj" "$tor_hs_o" "$sha3_o" "$tor_aes_o" "$curve25519_o" "$runtime_o"
	echo "  LD  ${bin}"
	"$bin"
}

cmd_test_x25519() {
	local src="${TEST_DIR}/test_x25519.asm"
	local obj="${ASM_BUILD}/test_x25519.o"
	local stub_src="${TEST_DIR}/stubs_tor_ntor.asm"
	local stub_obj="${ASM_BUILD}/stubs_tor_ntor.o"
	local bin="${ASM_BUILD}/test_x25519"
	${YASM} -f elf64 ${ASM_INC} -o "$obj" "$src"
	${YASM} -f elf64 ${ASM_INC} -o "$stub_obj" "$stub_src"
	local tor_ntor_o="${ASM_BUILD}/tor_ntor.o"
	if [ ! -f "$tor_ntor_o" ]; then
		elf64 "${ASM_DIR}/crypto/tor_ntor.asm" "$tor_ntor_o"
	fi
	local runtime_o="${ASM_BUILD}/runtime.o"
	if [ ! -f "$runtime_o" ]; then
		elf64 "${ASM_DIR}/rt/runtime.asm" "$runtime_o"
	fi
	local curve25519_o="${ASM_BUILD}/curve25519.o"
	if [ ! -f "$curve25519_o" ]; then
		elf64 "${ASM_DIR}/crypto/curve25519.asm" "$curve25519_o"
	fi
	ld -nostdlib -static -o "$bin" "$obj" "$curve25519_o" "$tor_ntor_o" "$runtime_o" "$stub_obj"
	echo "  LD  ${bin}"
	"$bin"
}

cmd_test_x25519_debug() {
	local src="${TEST_DIR}/test_x25519.asm"
	local obj="${ASM_BUILD}/test_x25519_debug.o"
	local stub_src="${TEST_DIR}/stubs_tor_ntor.asm"
	local stub_obj="${ASM_BUILD}/stubs_tor_ntor_debug.o"
	local bin="${ASM_BUILD}/test_x25519_debug"
	${YASM} -f elf64 ${ASM_INC} -o "$obj" "$src"
	${YASM} -f elf64 ${ASM_INC} -o "$stub_obj" "$stub_src"
	local tor_ntor_o="${ASM_BUILD}/tor_ntor.o"
	if [ ! -f "$tor_ntor_o" ]; then
		elf64 "${ASM_DIR}/crypto/tor_ntor.asm" "$tor_ntor_o"
	fi
	local runtime_o="${ASM_BUILD}/runtime.o"
	if [ ! -f "$runtime_o" ]; then
		elf64 "${ASM_DIR}/rt/runtime.asm" "$runtime_o"
	fi
	local curve25519_o="${ASM_BUILD}/curve25519_debug.o"
	elf64_dbg "${ASM_DIR}/crypto/curve25519.asm" "$curve25519_o"
	ld -nostdlib -static -o "$bin" "$obj" "$curve25519_o" "$tor_ntor_o" "$runtime_o" "$stub_obj"
	echo "  LD  ${bin}"
	"$bin"
}

cmd_test_bench_render_ir() {
	build_test "bench_render_ir" "${TEST_DIR}/bench_render_ir.asm" "ui/sw_fb" "ui/render_ir"
}

cmd_bench_wasm_jit() {
	local name="bench_wasm_jit"
	local src="${TEST_DIR}/${name}.asm"
	local obj="${ASM_BUILD}/${name}.o"
	local bin="${ASM_BUILD}/${name}"
	${YASM} -f elf64 ${ASM_INC} -o "$obj" "$src"
	local runtime_o="${ASM_BUILD}/runtime.o"
	if [ ! -f "$runtime_o" ]; then
		elf64 "${ASM_DIR}/rt/runtime.asm" "$runtime_o"
	fi
	ld -T "${TEST_DIR}/test_jit.ld" -nostdlib -static -o "$bin" "$obj" "$runtime_o"
	echo "  LD  ${bin}"
	"$bin"
}

cmd_bench_zig_wasm() {
	local zig_src="app/bench/zig_wasm_bench.zig"
	local native_obj="${ASM_BUILD}/zig_wasm_bench_native.o"
	local wasm_bin="${ASM_BUILD}/zig_wasm_bench.wasm"
	local asm_src="${TEST_DIR}/bench_zig_wasm.asm"
	local asm_obj="${ASM_BUILD}/bench_zig_wasm.o"
	local bin="${ASM_BUILD}/bench_zig_wasm"
	zig build-obj -O ReleaseFast -fstrip -target x86_64-linux -femit-bin="$native_obj" "$zig_src"
	zig build-exe -O ReleaseFast -fstrip -target wasm32-freestanding -fno-entry -rdynamic -femit-bin="$wasm_bin" "$zig_src"
	local wasm_abs="${PWD}/${wasm_bin}"
	${YASM} -f elf64 ${ASM_INC} -DZIG_WASM_BENCH_PATH="\"${wasm_abs}\"" -o "$asm_obj" "$asm_src"
	local runtime_o="${ASM_BUILD}/runtime.o"
	if [ ! -f "$runtime_o" ]; then
		elf64 "${ASM_DIR}/rt/runtime.asm" "$runtime_o"
	fi
	ld -T "${TEST_DIR}/test_jit.ld" -nostdlib -static -o "$bin" "$asm_obj" "$native_obj" "$runtime_o"
	echo "  LD  ${bin}"
	"$bin"
	if ! command -v node >/dev/null 2>&1; then
		echo "node is required for bench-zig-wasm V8 comparison" >&2
		return 1
	fi
	local node_bench="${ASM_BUILD}/bench_zig_wasm_node.mjs"
	cat > "$node_bench" <<'EOF'
import { readFileSync } from 'node:fs';

const wasmPath = process.argv[2];
const bytes = readFileSync(wasmPath);
const { instance } = await WebAssembly.instantiate(bytes, {});
const erBench = instance.exports.er_bench;
if (typeof erBench !== 'function') {
  throw new Error('missing er_bench export');
}

let acc = 12345;
for (let i = 0; i < 100000; i += 1) {
  acc = erBench(acc >>> 0) >>> 0;
}

const iters = 5000000;
const start = process.hrtime.bigint();
for (let i = 0; i < iters; i += 1) {
  acc = erBench(acc >>> 0) >>> 0;
}
const elapsed = process.hrtime.bigint() - start;
const nsPerCall = elapsed / BigInt(iters);
console.log(`v8_node_ns: ${nsPerCall.toString()}`);
console.log(`v8_node_result: 0x${(acc >>> 0).toString(16).padStart(8, '0')}`);
EOF
	node "$node_bench" "$wasm_bin"
}

cmd_signing_wasm() {
	local manifest="app/edgerun-signing/Cargo.toml"
	local cargo_target="${BUILD_DIR}/cargo-target"
	local wasm_src="${cargo_target}/wasm32-unknown-unknown/release/edgerun_signing.wasm"
	local wasm_dst="${ASM_BUILD}/edgerun_signing.wasm"
	cargo build --manifest-path "$manifest" --target wasm32-unknown-unknown --release --target-dir "$cargo_target"
	cp "$wasm_src" "$wasm_dst"
	local wsize=$(stat -c '%s' "$wasm_dst")
	printf 'signing-wasm: %s (%d bytes)\n' "$wasm_dst" "$wsize"
}

cmd_lib_tor() {
	local lib_dir="${BUILD_DIR}/lib"
	mkdir -p "${lib_dir}" "${ASM_BUILD}"

	local runtime_o="${ASM_BUILD}/lib_runtime.o"
	local sha256_o="${ASM_BUILD}/lib_sha256.o"
	local sha3_o="${ASM_BUILD}/lib_sha3.o"
	local tor_aes_o="${ASM_BUILD}/lib_tor_aes.o"
	local curve25519_o="${ASM_BUILD}/lib_curve25519.o"
	local tls_o="${ASM_BUILD}/lib_tls.o"
	local tor_ntor_o="${ASM_BUILD}/lib_tor_ntor.o"
	local tor_digest_o="${ASM_BUILD}/lib_tor_digest.o"
	local tor_cell_o="${ASM_BUILD}/lib_tor_cell.o"
	local tor_hs_o="${ASM_BUILD}/lib_tor_hs.o"
	local tor_hs_app_o="${ASM_BUILD}/lib_tor_hs_app.o"
	local tor_o="${ASM_BUILD}/lib_tor.o"

	elf64 "${ASM_DIR}/rt/runtime.asm" "$runtime_o"
	elf64 "${ASM_DIR}/crypto/sha256.asm" "$sha256_o"
	elf64 "${ASM_DIR}/crypto/sha3.asm" "$sha3_o"
	elf64 "${ASM_DIR}/crypto/tor_aes.asm" "$tor_aes_o"
	elf64 "${ASM_DIR}/crypto/curve25519.asm" "$curve25519_o"
	elf64 "${ASM_DIR}/crypto/tls.asm" "$tls_o"
	elf64 "${ASM_DIR}/crypto/tor_ntor.asm" "$tor_ntor_o"
	elf64 "${ASM_DIR}/crypto/tor_digest.asm" "$tor_digest_o"
	elf64 "${ASM_DIR}/crypto/tor_cell.asm" "$tor_cell_o"
	elf64 "${ASM_DIR}/crypto/tor_hs.asm" "$tor_hs_o"
	elf64 "${ASM_DIR}/crypto/tor_hs_app.asm" "$tor_hs_app_o"
	elf64 "${ASM_DIR}/crypto/tor.asm" "$tor_o"

	ar rcs "${lib_dir}/libedgerun_tor_hs.a" \
		"$tor_hs_o" "$sha3_o" "$tor_aes_o" "$curve25519_o" "$runtime_o"
	ar rcs "${lib_dir}/libedgerun_tor_hs_app.a" \
		"$tor_hs_app_o" "$runtime_o"
	ar rcs "${lib_dir}/libedgerun_tor_core.a" \
		"$tor_o" "$tor_cell_o" "$tor_hs_o" "$tor_hs_app_o" \
		"$tls_o" "$sha256_o" "$sha3_o" "$tor_aes_o" \
		"$tor_ntor_o" "$curve25519_o" "$tor_digest_o" "$runtime_o"

	echo "  AR  ${lib_dir}/libedgerun_tor_hs.a"
	echo "  AR  ${lib_dir}/libedgerun_tor_hs_app.a"
	echo "  AR  ${lib_dir}/libedgerun_tor_core.a"
}

cmd_tor_hs_host() {
	cmd_lib_tor
	mkdir -p "${HOST_BUILD}"
	local obj="${HOST_BUILD}/tor_hs_host.o"
	local bin="${HOST_BUILD}/tor_hs_host"
	${YASM} -f elf64 ${ASM_INC} -o "$obj" "${TEST_DIR}/test_tor_hs_self.asm"
	ld -nostdlib -static -o "$bin" "$obj" "${BUILD_DIR}/lib/libedgerun_tor_hs.a"
	echo "  LD  ${bin}"
}

cmd_tor_live_host() {
	cmd_lib_tor
	mkdir -p "${HOST_BUILD}"
	local obj="${HOST_BUILD}/tor_live_host.o"
	local bin="${HOST_BUILD}/tor_live_host"
	${YASM} -f elf64 ${ASM_INC} ${ASM_DEFS:-} -o "$obj" "${TEST_DIR}/test_tor_live_host.asm"
	ld -nostdlib -static -o "$bin" "$obj" "${BUILD_DIR}/lib/libedgerun_tor_core.a"
	echo "  LD  ${bin}"
}

cmd_test_tor_live_host() {
	cmd_tor_live_host
	"${HOST_BUILD}/tor_live_host"
}

# ---- ARM / Pi Zero targets ----
HOST_BUILD="${BUILD_DIR}/host"
PI_BUILD="${BUILD_DIR}/pi"
PI_KERNEL_ELF="${PI_BUILD}/kernel.elf"
PI_KERNEL_IMG="${PI_BUILD}/kernel.img"
PI_USB_BOOT="${HOST_BUILD}/pi_usb_boot"
ASM_ARM_DIR="kernel/arm/pi"
ARM_AS="${ARM_AS:-arm-none-eabi-as}"
ARM_LD="${ARM_LD:-arm-none-eabi-ld}"
ARM_OBJCOPY="${ARM_OBJCOPY:-arm-none-eabi-objcopy}"
ARM_LD_SCRIPT="${ASM_ARM_DIR}/linker.ld"

arm_obj() {
	${ARM_AS} -mcpu=arm1176jzf-s -I kernel -o "$2" "$1"
}

cmd_pi_kernel() {
	mkdir -p "${PI_BUILD}"
	arm_obj "${ASM_ARM_DIR}/start.asm" "${PI_BUILD}/start.o"
	arm_obj "${ASM_ARM_DIR}/emmc.asm" "${PI_BUILD}/emmc.o"
	arm_obj "${ASM_ARM_DIR}/dwc2.asm" "${PI_BUILD}/dwc2.o"
	arm_obj "${ASM_ARM_DIR}/gpio.asm" "${PI_BUILD}/gpio.o"
	arm_obj "${ASM_ARM_DIR}/audio.asm" "${PI_BUILD}/audio.o"
	arm_obj "${ASM_ARM_DIR}/bt.asm" "${PI_BUILD}/bt.o"
	arm_obj "${ASM_ARM_DIR}/gpu.asm" "${PI_BUILD}/gpu.o"
	${ARM_LD} -T "${ARM_LD_SCRIPT}" -o "${PI_KERNEL_ELF}" "${PI_BUILD}/start.o" "${PI_BUILD}/emmc.o" "${PI_BUILD}/dwc2.o" "${PI_BUILD}/gpio.o" "${PI_BUILD}/audio.o" "${PI_BUILD}/bt.o" "${PI_BUILD}/gpu.o"
	${ARM_OBJCOPY} -O binary "${PI_KERNEL_ELF}" "${PI_KERNEL_IMG}"
	local esize=$(stat -c '%s' "${PI_KERNEL_ELF}" 2>/dev/null || echo 0)
	local bsize=$(stat -c '%s' "${PI_KERNEL_IMG}" 2>/dev/null || echo 0)
	printf 'pi-kernel: %s (%d bytes)\n' "${PI_KERNEL_ELF}" "${esize}"
	printf '  img:     %s (%d bytes)\n' "${PI_KERNEL_IMG}" "${bsize}"
}

cmd_pi_usb_boot() {
	mkdir -p "${HOST_BUILD}"
	local src="kernel/host/pi_usb_boot_host.asm"
	local obj="${HOST_BUILD}/pi_usb_boot_host.o"
	${YASM} -f elf64 -I kernel -o "$obj" "$src"
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
	local src="kernel/host/esp32_serial_boot_host.asm"
	local obj="${HOST_BUILD}/esp32_serial_boot_host.o"
	${YASM} -f elf64 -I kernel -o "$obj" "$src"
	ld -o "${HOST_BUILD}/esp32_serial_boot" "$obj"
	echo "  LD  ${obj}"
}

cmd_clean() {
	rm -rf "${BUILD_DIR}"
}

cmd_help() {
	cat <<'EOF'
EdgeRun build targets:
  kernel              Build kernel.elf + kernel.bin
  kernel-hello        Build kernel + run in QEMU (serial)
  kernel-vnc          Build kernel + run in QEMU (VNC :0)
  kernel-net          Build kernel + run in QEMU with virtio-net
  kernel-net-tpm      Build kernel + run in QEMU with swtpm + virtio-net
  kernel-net-tor      Build kernel with Tor autostart + run QEMU net/TPM
  kernel-tpm-live-test    Build kernel with TPM live test main
  kernel-tpm-live-test-qemu Build + run in QEMU with swtpm
  kernel-efi          Build kernel.efi and copy it to the EdgeRun ESP path
  install-efi         Build + install kernel.efi to ESP + add boot entry
  test                Run all self-hosted ASM tests
  test-wasm-compiler  Run host-side WASM compiler self-test
  test-wasm-jit       Run WASM JIT self-test (self-hosted ASM runner)
  test-wasm-float     Run WASM float opcode test (self-hosted ASM runner)
  test-ctype          Run ctype test (self-hosted ASM runner)
  test-clock          Run clock test (self-hosted ASM runner)
  test-http           Run HTTP test (self-hosted ASM runner)
  test-recursion-valid    Run WASM recursion-validation valid-DAG test
  test-recursion-invalid  Run WASM recursion-validation cycle-rejection test
  test-serial         Run serial test (self-hosted ASM runner)
  test-cros-ec        Run Chrome EC memmap parser test (self-hosted ASM)
  test-amdgpu         Run AMDGPU DCN register-plan test (self-hosted ASM)
  test-uvc            Run UVC descriptor parse test (self-hosted ASM runner)
  test-sw-fb          Run software framebuffer test (self-hosted ASM runner)
  test-render-ir      Run render IR test (self-hosted ASM runner)
  test-fe-mul         Run _fe_mul field multiplication test (self-hosted ASM)
  test-spi-flash      Run SPI flash compile-check test (self-hosted ASM)
  test-pi-audio       Run Pi Zero W BCM2835 PWM audio emulator test
  test-pi-bt          Run Pi Zero W CYW43438 Bluetooth UART emulator test
  test-pi-gpu         Run Pi Zero W VideoCore mailbox framebuffer emulator test
  test-pi-gpio        Run Pi Zero W BCM2835 GPIO emulator test
  test-pi-sd          Run Pi Zero W EMMC SD block emulator test
  test-pi-usb         Run Pi Zero W DWC2 USB host init emulator test
  test-pi-wifi-sdio   Run Pi Zero W CYW43438 SDIO probe emulator test
  test-sha3           Run SHA3-256 known-answer tests (self-hosted ASM)
  test-tls            Run TLS ClientHello self-test (self-hosted ASM)
  test-tor            Run Tor AES-128-CTR KAT test (self-hosted ASM)
  test-tor-cell       Run Tor cell EXTEND2 helper test (self-hosted ASM)
  test-tor-hs         Run Tor onion-service message tests (self-hosted ASM)
  test-local-route    Run local cell route queue/dispatch test (self-hosted ASM)
  bench-tor           Run Tor local AES cell latency/throughput benchmark
  bench-tor-hs        Run hidden-service local self-connect benchmark
  test-x25519         Run X25519 scalar mult RFC 7748 test vectors (self-hosted ASM)
  test-bench-render-ir Run render_ir RDTSC benchmark (self-hosted ASM)
  bench-wasm-jit      Run WASM JIT vs native RDTSC benchmark (self-hosted ASM)
  bench-zig-wasm      Compile same Zig code to x86_64 + WASM, then benchmark native/interpreter/JIT
  signing-wasm        Compile Ed25519 signing WASM guest
  lib-tor             Build reusable Tor static archives under .build/lib
  tor-hs-host         Build hosted hidden-service library smoke binary
  tor-live-host       Build hosted live Tor ORPort probe binary
  test-tor-live-host  Build + run hosted live Tor ORPort probe
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
	kernel-vnc)     cmd_kernel_vnc ;;
	kernel-net)     cmd_kernel_net ;;
	kernel-net-tpm) cmd_kernel_net_tpm ;;
	kernel-net-tor) cmd_kernel_net_tor ;;
	kernel-tpm-live-test)   cmd_kernel_tpm_live_test ;;
	kernel-tpm-live-test-qemu) cmd_kernel_tpm_live_test_qemu ;;
	kernel-efi)     cmd_kernel_efi ;;
	install-efi)    cmd_install_efi ;;
	test)           cmd_test ;;
	test-wasm-compiler) cmd_test_wasm_compiler ;;
	test-wasm-jit)  cmd_test_wasm_jit ;;
	test-wasm-float) cmd_test_wasm_float ;;
	test-ctype)     cmd_test_ctype ;;
	test-clock)     cmd_test_clock ;;
	test-http)       cmd_test_http ;;
	test-recursion-valid) cmd_test_recursion_valid ;;
	test-recursion-invalid) cmd_test_recursion_invalid ;;
	test-serial)     cmd_test_serial ;;
	test-cros-ec)    cmd_test_cros_ec ;;
	test-amdgpu)     cmd_test_amdgpu ;;
	test-uvc)        cmd_test_uvc ;;
	test-sw-fb)     cmd_test_sw_fb ;;
	test-render-ir) cmd_test_render_ir ;;
	test-fe-mul)    cmd_test_fe_mul ;;
	test-spi-flash) cmd_test_spi_flash ;;
	test-pi-audio) cmd_test_pi_audio ;;
	test-pi-bt) cmd_test_pi_bt ;;
	test-pi-gpu) cmd_test_pi_gpu ;;
	test-pi-gpio) cmd_test_pi_gpio ;;
	test-pi-sd) cmd_test_pi_sd ;;
	test-pi-usb) cmd_test_pi_usb ;;
	test-pi-wifi-sdio) cmd_test_pi_wifi_sdio ;;
	test-sha3)      cmd_test_sha3 ;;
	test-tls)       cmd_test_tls ;;
	test-tor)       cmd_test_tor ;;
	test-tor-cell)  cmd_test_tor_cell ;;
	test-tor-hs)    cmd_test_tor_hs ;;
	test-tor-hs-app) cmd_test_tor_hs_app ;;
	test-local-route) cmd_test_local_route ;;
	bench-tor)      cmd_bench_tor ;;
	bench-tor-hs)   cmd_bench_tor_hs ;;
	test-x25519)     cmd_test_x25519 ;;
	test-x25519-debug) cmd_test_x25519_debug ;;
	test-bench-render-ir) cmd_test_bench_render_ir ;;
	bench-wasm-jit) cmd_bench_wasm_jit ;;
	bench-zig-wasm) cmd_bench_zig_wasm ;;
	signing-wasm)    cmd_signing_wasm ;;
	lib-tor)         cmd_lib_tor ;;
	tor-hs-host)     cmd_tor_hs_host ;;
	tor-live-host)   cmd_tor_live_host ;;
	test-tor-live-host) cmd_test_tor_live_host ;;
	pi-kernel)      cmd_pi_kernel ;;
	pi-usb-boot)    cmd_pi_usb_boot ;;
	pi-boot)        cmd_pi_boot ;;
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
