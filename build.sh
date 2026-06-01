#!/usr/bin/env bash
# EdgeRun build script — explicit, no pattern rules, no Makefile magic.
# Usage:  ./build.sh <target>
# Targets:  kernel  kernel-hello  test  test-*  clean
set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
SCRIPT_DIR="${SCRIPT_PATH%/*}"
if [ "$SCRIPT_DIR" = "$SCRIPT_PATH" ]; then
	SCRIPT_DIR="."
fi
cd "$SCRIPT_DIR"

# Disable all forms of disk-based caching
export CCACHE_DISABLE=1
export SCCACHE_DISABLE=1
export PYTHONDONTWRITEBYTECODE=1
unset GOCACHE

BUILD_DIR=".build"
ASM_BUILD="${BUILD_DIR}/kernel"
ASM_DIR="kernel/x86_64"
TEST_DIR="kernel/test"
ER_ASM="${ER_ASM:-}"
YASM="${YASM:-yasm}"
ASM_INC="-I kernel"
KERNEL_LD="${ASM_DIR}/linker.ld"
KERNEL_EFI_LD="${ASM_DIR}/efi_linker.ld"
KERNEL_EFI="${ASM_BUILD}/kernel.efi"
KERNEL_BIN="${ASM_BUILD}/kernel.bin"
KERNEL_BOOT="${ASM_BUILD}/boot_loader.bin"
KERNEL_IMG="${ASM_BUILD}/kernel.img"
EFI_ESP="${EFI_ESP:-/boot}"
EFI_BOOT_DIR="${EFI_ESP}/EFI/edgerun"
EFI_BOOT_PATH="${EFI_BOOT_DIR}/bootx64.efi"

# ---- helpers ----
mkdir -p "${ASM_BUILD}"

asm_x86_obj() {
	local format="$1"; shift
	local dst="$1"; shift
	local src="$1"; shift
	local err="${dst}.asm.err"
	local assembler="${ER_ASM:-$YASM}"
	if ! "$assembler" -f "$format" ${ASM_INC} ${ASM_DEFS:-} "$@" -o "$dst" "$src" 2>"$err"; then
		cat "$err" >&2
		rm -f "$err"
		return 1
	fi
	if [ -s "$err" ]; then
		cat "$err" >&2
		if grep -i 'warning:' "$err" >/dev/null 2>&1; then
			rm -f "$err"
			return 1
		fi
	fi
	rm -f "$err"
	test -f "$dst"
}

elf64()   { asm_x86_obj elf64 "$2" "$1"; }
elf32()   { asm_x86_obj elf32 "$2" "$1"; }
elf64_dbg() { asm_x86_obj elf64 "$2" "$1" -dX25519_DEBUG; }

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
	crypto/sha512.asm
	crypto/sha3.asm
	crypto/ed25519.asm
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
	media/av1_bits.asm
	media/vp8.asm
	media/vp9.asm
	media/webp.asm
	media/mp4.asm
	media/av1_obu.asm
	media/av1_ivf.asm
	media/av1_sequence.asm
	media/av1_frame.asm
	media/av1_tile.asm
	media/av1_block.asm
	media/av1_reduced.asm
	agent/http_agent.asm
	agent/da.asm
	agent/da_wasm.asm
	agent/input_kbd.asm
	ui/render_ir.asm
	ui/sw_fb.asm
	wasm/wasm_interpreter.asm
	wasm/wasm_compiler.asm
	wasm/tsx_parser.asm
	wasm/wasm_test_data.asm
	wasm/da_wasm_test.asm
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
	assemble_kernel
	rm -f "${ASM_BUILD}/kernel.elf"
	local objs=$(kernel_objs "kernel" ".o" "kernel_main_elf32.o")
	ld -m elf_i386 -T "${KERNEL_LD}" -o "${KERNEL_BIN}" ${objs}
	local bsize=$(stat -c '%s' "${KERNEL_BIN}")
	printf 'kernel: %s (%d bytes)\n' "${KERNEL_BIN}" "${bsize}"
}

build_current_kernel_boot_image() {
	local bsize=$(stat -c '%s' "${KERNEL_BIN}")
	local sectors=$(( (bsize + 511) / 512 ))
	asm_x86_obj bin "${KERNEL_BOOT}" "${ASM_DIR}/boot_loader.asm" -dKERNEL_SECTORS="${sectors}"
	local lsize=$(stat -c '%s' "${KERNEL_BOOT}")
	if [ "${lsize}" -ne 512 ]; then
		echo "error: boot loader must be exactly 512 bytes" >&2
		exit 1
	fi
	cp "${KERNEL_BOOT}" "${KERNEL_IMG}"
	truncate -s $(( (sectors + 1) * 512 )) "${KERNEL_IMG}"
	dd if="${KERNEL_BIN}" of="${KERNEL_IMG}" bs=512 seek=1 conv=notrunc status=none
	local isize=$(stat -c '%s' "${KERNEL_IMG}")
	printf 'boot:   %s (%d bytes, %d kernel sectors)\n' "${KERNEL_IMG}" "${isize}" "${sectors}"
}

build_kernel_boot_image() {
	cmd_kernel
	build_current_kernel_boot_image
}

cmd_kernel_hello() {
	build_kernel_boot_image
	qemu-system-x86_64 -machine q35 -display none -serial stdio -no-reboot \
		-drive file="${KERNEL_IMG}",format=raw,if=ide,index=0 -m 256
}

cmd_kernel_vnc() {
	build_kernel_boot_image
	qemu-system-x86_64 -machine q35 -vga std -vnc :0 -serial stdio -no-reboot \
		-drive file="${KERNEL_IMG}",format=raw,if=ide,index=0 -m 256
}

cmd_kernel_efi() {
	assemble_kernel_efi
	local objs=$(kernel_objs "kernel_efi" ".o" "kernel_main_efi64.o")
	ld -m i386pep -T "${KERNEL_EFI_LD}" --subsystem 10 --image-base 0x100000 \
		-o "${KERNEL_EFI}" ${objs}
	local esize=$(stat -c '%s' "${KERNEL_EFI}")
	printf 'efi:  %s (%d bytes)\n' "${KERNEL_EFI}" "${esize}"
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
	sync_kernel_efi_to_esp
	cmd_er_efiboot >/dev/null
	local bootnum="${ER_EFI_BOOTNUM:-0ED9}"
	sudo -n "${HOST_BUILD}/er_efiboot" --create-file "$bootnum" EdgeRun '\EFI\edgerun\bootx64.efi'
	sudo -n "${HOST_BUILD}/er_efiboot" --prepend-order "$bootnum"
	echo "installed EdgeRun EFI boot entry Boot${bootnum}"
}

cmd_kernel_net() {
	build_kernel_boot_image
	qemu-system-x86_64 -machine q35 -display none -serial stdio \
		-no-reboot -drive file="${KERNEL_IMG}",format=raw,if=ide,index=0 -m 256 \
		-netdev user,id=net0 \
		-device virtio-net-pci,netdev=net0
}

cmd_kernel_net_tpm() {
	build_kernel_boot_image
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
		-no-reboot -drive file="${KERNEL_IMG}",format=raw,if=ide,index=0 -m 256 \
		-chardev socket,id=chrtpm,path="${tpm_sock}" \
		-tpmdev emulator,id=tpm0,chardev=chrtpm \
		-device tpm-crb,tpmdev=tpm0 \
		-netdev user,id=net0 \
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
	rm -f "${ASM_BUILD}/kernel.elf"
	local objs=$(kernel_objs "kernel" ".o" "kernel_tpm_live_test_main_elf32.o")
	ld -m elf_i386 -T "${KERNEL_LD}" -o "${KERNEL_BIN}" ${objs}
	local bsize=$(stat -c '%s' "${KERNEL_BIN}")
	printf 'kernel: %s (%d bytes)\n' "${KERNEL_BIN}" "${bsize}"
}

cmd_kernel_tpm_live_test_qemu() {
	cmd_kernel_tpm_live_test
	build_current_kernel_boot_image
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
		-no-reboot -drive file="${KERNEL_IMG}",format=raw,if=ide,index=0 -m 256 \
		-chardev socket,id=chrtpm,path="${tpm_sock}" \
		-tpmdev emulator,id=tpm0,chardev=chrtpm \
		-device tpm-crb,tpmdev=tpm0 || true
	kill "${swtpm_pid}" 2>/dev/null || true
	wait "${swtpm_pid}" 2>/dev/null || true
	rm -f "${tpm_sock}"
}

build_flat_kernel_test() {
	local name="$1"; shift
	local main_src="$1"; shift
	local test_dir="${ASM_BUILD}/${name}_flat"
	local kernel_bin="${test_dir}/kernel.bin"
	local boot_bin="${test_dir}/boot_loader.bin"
	local image="${test_dir}/kernel.img"
	local entry_obj="${test_dir}/entry.o"
	local main_obj="${test_dir}/main.o"
	local runtime_obj="${test_dir}/test_flat_runtime.o"
	local need_runtime=0
	for dep; do
		if [ "$dep" = "rt/runtime" ]; then
			need_runtime=1
		fi
	done
	if [ -e "$test_dir" ] && [ ! -d "$test_dir" ]; then
		rm -f "$test_dir"
	fi
	mkdir -p "$test_dir"
	asm_x86_obj elf32 "$entry_obj" "${ASM_DIR}/entry.asm" -DTEST_FLAT_KERNEL
	asm_x86_obj elf32 "$main_obj" "$main_src" -DTEST_FLAT_KERNEL
	if [ "$need_runtime" -eq 1 ]; then
		runtime_obj="${test_dir}/runtime.o"
		elf32 "${ASM_DIR}/rt/runtime.asm" "$runtime_obj"
	else
		asm_x86_obj elf32 "$runtime_obj" "${TEST_DIR}/test_flat_runtime.asm"
	fi
	local extra_o=""
	for dep; do
		if [ "$dep" = "rt/runtime" ]; then
			continue
		fi
		local dep_obj="${test_dir}/${dep##*/}.o"
		local dep_src="${ASM_DIR}/${dep}.asm"
		local dep_defs=()
		case "$dep" in
			test:*)
				local stub_name="${dep#test:}"
				dep_obj="${test_dir}/${stub_name}.o"
				dep_src="${TEST_DIR}/${stub_name}.asm"
				;;
			def:*)
				local dep_spec="${dep#def:}"
				local dep_path="${dep_spec%%:*}"
				local dep_def="${dep_spec#*:}"
				dep_obj="${test_dir}/${dep_path##*/}.o"
				dep_src="${ASM_DIR}/${dep_path}.asm"
				dep_defs=("$dep_def")
				;;
		esac
		asm_x86_obj elf32 "$dep_obj" "$dep_src" -DTEST_FLAT_KERNEL "${dep_defs[@]}"
		extra_o="$extra_o $dep_obj"
	done
	ld -m elf_i386 -T "${KERNEL_LD}" -o "$kernel_bin" "$entry_obj" "$main_obj" "$runtime_obj" $extra_o
	test -s "$kernel_bin"
	local bsize=$(stat -c '%s' "$kernel_bin")
	local sectors=$(( (bsize + 511) / 512 ))
	asm_x86_obj bin "$boot_bin" "${ASM_DIR}/boot_loader.asm" -dKERNEL_SECTORS="${sectors}"
	test -s "$boot_bin"
	cp "$boot_bin" "$image"
	truncate -s $(( (sectors + 1) * 512 )) "$image"
	dd if="$kernel_bin" of="$image" bs=512 seek=1 conv=notrunc status=none
	test -s "$image"
	local qemu_log="${test_dir}/qemu.log"
	local qemu_rc=0
	timeout 10s qemu-system-x86_64 -cpu max -machine pc -display none -serial stdio -no-reboot \
		-device isa-debug-exit,iobase=0xf4,iosize=0x04 \
		-drive file="$image",format=raw,if=ide,index=0 -m 256 >"$qemu_log" 2>&1 </dev/null || qemu_rc=$?
	if [ "$qemu_rc" -ne 1 ]; then
		cat "$qemu_log" >&2
		echo "FAIL ${name}: qemu exit ${qemu_rc}" >&2
		exit 1
	fi
	echo "PASS ${name}"
}

# Build a self-hosted ASM test as a flat bare-metal image.
# Usage: build_test <obj_name> <asm_src> [<dep_path>...]
# Each dep_path is relative to ASM_DIR (without .asm suffix).
build_test() {
	local name="$1"; shift
	local src="$1"; shift
	build_flat_kernel_test "${name%_self}" "$src" "$@"
}

build_test_self() {
	local name="$1"; shift
	build_test "$name" "${TEST_DIR}/${name}.asm" "$@"
}

build_test_stubbed() {
	local name="$1"; shift
	local stub="$1"; shift
	build_flat_kernel_test "${name%_self}" "${TEST_DIR}/${name}.asm" "test:${stub}" "$@"
}

test_registry() {
 cat <<'EOF'
test-registry|unit|build|yes|cmd_test_registry|Validate test registry metadata
test-deps-audit|unit|build|yes|cmd_deps_audit|Validate dependency manifests and tracked binary artifacts
test-x86-asm-boundary|unit|build|yes|cmd_check_x86_asm_boundary|Validate x86 ASM goes through one assembler boundary
test-x86-asm-selector|unit|build|yes|cmd_test_x86_asm_selector|Validate ER_ASM selects a single x86 assembler
test-x86-asm-inventory|unit|build|yes|cmd_test_x86_asm_inventory|Validate x86 ASM syntax inventory generation
test-x86-asm-warning-fatal|unit|build|yes|cmd_test_x86_asm_warning_fatal|Validate x86 ASM warnings fail the build
test-er-asm-parse|unit|build|yes|cmd_test_er_asm_parse|Run owned ASM assembler parser smoke test
test-er-asm-cli|unit|build|yes|cmd_test_er_asm_cli|Validate owned assembler accepts x86 assembler CLI shape
test-er-efiboot|unit|build|yes|cmd_test_er_efiboot|Validate owned EFI variable manager dry-run operations
test-ctype|unit|rt|yes|cmd_test_ctype|Run ctype bare-metal flat-image test
test-clock|unit|rt|yes|cmd_test_clock|Run deterministic clock test
test-identity|unit|crypto|yes|cmd_test_identity|Run identity source test
test-http|unit|net|yes|cmd_test_http|Run HTTP parser/SSE test
test-ipv4|unit|net|yes|cmd_test_ipv4|Run IPv4 receive dispatch test
test-tcp|unit|net|yes|cmd_test_tcp|Run TCP checksum test
test-serial|unit|driver|yes|cmd_test_serial|Run serial driver test
test-cros-ec|unit|driver|yes|cmd_test_cros_ec|Run Chrome EC memmap parser test
test-amdgpu|unit|driver|yes|cmd_test_amdgpu|Run AMDGPU DCN register-plan test
test-uvc|unit|driver|yes|cmd_test_uvc|Run UVC descriptor parser test
test-nvme|unit|driver|yes|cmd_test_nvme|Run NVMe IO command helper test
test-sdhci|unit|driver|yes|cmd_test_sdhci|Run Intel SDHCI command helper test
test-sw-fb|contract|ui|yes|cmd_test_sw_fb|Run software framebuffer test
test-render-ir|contract|ui|yes|cmd_test_render_ir|Run render IR test
test-fe-mul|unit|crypto|yes|cmd_test_fe_mul|Run field multiplication test
test-store|unit|driver|yes|cmd_test_store|Run persistent store replay test
test-spi-flash|unit|driver|yes|cmd_test_spi_flash|Run SPI flash compile check
test-pi-audio|emulator|pi|yes|cmd_test_pi_audio|Run Pi Zero W PWM audio emulator test
test-pi-bt|emulator|pi|yes|cmd_test_pi_bt|Run Pi Zero W CYW43438 Bluetooth UART emulator test
test-pi-gpu|emulator|pi|yes|cmd_test_pi_gpu|Run Pi Zero W VideoCore mailbox framebuffer emulator test
test-pi-gpio|emulator|pi|yes|cmd_test_pi_gpio|Run Pi Zero W GPIO emulator test
test-pi-sd|emulator|pi|yes|cmd_test_pi_sd|Run Pi Zero W EMMC SD block emulator test
test-pi-usb|emulator|pi|yes|cmd_test_pi_usb|Run Pi Zero W DWC2 USB host emulator test
test-pi-wifi-sdio|emulator|pi|yes|cmd_test_pi_wifi_sdio|Run Pi Zero W CYW43438 SDIO probe emulator test
test-sha3|unit|crypto|yes|cmd_test_sha3|Run SHA3-256 known-answer tests
test-sha512|unit|crypto|yes|cmd_test_sha512|Run SHA-512 known-answer tests
test-ed25519|unit|crypto|yes|cmd_test_ed25519|Run Ed25519 ASM helper tests
test-tls|contract|crypto|yes|cmd_test_tls|Run TLS ClientHello self-test
test-tpm|unit|crypto|yes|cmd_test_tpm|Run TPM command builder test
test-tor|contract|crypto|yes|cmd_test_tor|Run Tor AES-128-CTR KAT test
test-tor-cell|contract|crypto|yes|cmd_test_tor_cell|Run Tor cell EXTEND2 helper test
test-tor-hs|contract|crypto|yes|cmd_test_tor_hs|Run Tor onion-service message tests
test-tor-hs-app|contract|crypto|yes|cmd_test_tor_hs_app|Run Tor hidden-service app message tests
test-local-route|contract|route|yes|cmd_test_local_route|Run local cell route queue/dispatch test
test-local-circuit|contract|route|yes|cmd_test_local_circuit|Run local circuit open/send/recv/close test
test-av1-obu|unit|media|yes|cmd_test_av1_obu|Run AV1 OBU header codec test
test-av1-mp4|unit|media|yes|cmd_test_av1_mp4|Run AV1 MP4 container parser test
test-vp8|unit|media|yes|cmd_test_vp8|Run VP8 frame header parser test
test-vp9|unit|media|yes|cmd_test_vp9|Run VP9 uncompressed frame header parser test
test-webp|unit|media|yes|cmd_test_webp|Run WebP container parser test
test-av1-ivf|unit|media|yes|cmd_test_av1_ivf|Run AV1 IVF container parser test
test-av1-sequence|unit|media|yes|cmd_test_av1_sequence|Run AV1 sequence header test
test-av1-frame|unit|media|yes|cmd_test_av1_frame|Run AV1 frame header test
test-av1-tile|unit|media|yes|cmd_test_av1_tile|Run AV1 tile group test
test-av1-block|unit|media|yes|cmd_test_av1_block|Run AV1 block syntax entropy test
test-av1-reduced|contract|media|yes|cmd_test_av1_reduced|Run AV1 reduced-still stream test
test-x25519|unit|crypto|yes|cmd_test_x25519|Run X25519 RFC 7748 vectors
test-x25519-debug|debug|crypto|no|cmd_test_x25519_debug|Run X25519 vectors with debug curve25519 object
test-wasm-compiler|contract|wasm|yes|cmd_test_wasm_compiler|Run host-side WASM compiler self-test
test-wasm-jit|contract|wasm|yes|cmd_test_wasm_jit|Run WASM JIT self-test
test-recursion-valid|contract|wasm|yes|cmd_test_recursion_valid|Run WASM recursion valid-DAG test
test-recursion-invalid|contract|wasm|yes|cmd_test_recursion_invalid|Run WASM recursion cycle-rejection test
test-wasm-float|contract|wasm|yes|cmd_test_wasm_float|Run WASM float opcode test
test-bench-render-ir|bench|ui|no|cmd_test_bench_render_ir|Run render_ir RDTSC benchmark
test-tor-live-host|integration|crypto|no|cmd_test_tor_live_host|Build and run hosted live Tor ORPort probe
test-app|app|app|no|cmd_test_app|Run app-side Zig tests
EOF
}

cmd_test_registry() {
 local count=0 failed=0
 local -A seen=()
 while IFS='|' read -r reg_target reg_category reg_subsystem reg_default reg_runner reg_description; do
  count=$((count + 1))
  if [ -z "$reg_target" ] || [ -z "$reg_category" ] || [ -z "$reg_subsystem" ] || [ -z "$reg_default" ] || [ -z "$reg_runner" ] || [ -z "$reg_description" ]; then
   echo "FAIL test-registry: incomplete entry ${count}" >&2
   failed=1
   continue
  fi
  if [ -n "${seen[$reg_target]:-}" ]; then
   echo "FAIL test-registry: duplicate target ${reg_target}" >&2
   failed=1
  fi
  seen[$reg_target]=1
  case "$reg_default" in
   yes|no) ;;
   *)
    echo "FAIL test-registry: invalid default flag for ${reg_target}: ${reg_default}" >&2
    failed=1
    ;;
  esac
  case "$reg_category" in
   unit|contract|emulator|integration|bench|debug|app) ;;
   *)
    echo "FAIL test-registry: invalid category for ${reg_target}: ${reg_category}" >&2
    failed=1
    ;;
  esac
  if ! declare -F "$reg_runner" >/dev/null; then
   echo "FAIL test-registry: missing runner ${reg_runner} for ${reg_target}" >&2
   failed=1
  fi
 done < <(test_registry)

 if [ "$count" -eq 0 ]; then
  echo "FAIL test-registry: empty registry" >&2
  exit 1
 fi
 if [ "$failed" -ne 0 ]; then
  exit 1
 fi
 printf 'PASS test-registry %d entries\n' "$count"
}

cmd_check_x86_asm_boundary() {
 local line_no=0 in_helper=0 in_boundary_check=0 failed=0
 local line
 while IFS= read -r line; do
  line_no=$((line_no + 1))
  case "$line" in
   asm_x86_obj\(\)\ \{) in_helper=1 ;;
   cmd_check_x86_asm_boundary\(\)\ \{) in_boundary_check=1 ;;
  esac
  case "$line" in
   *'${YASM}'*|*'$YASM'*)
    case "$line" in
     YASM=*) ;;
     *)
      if [ "$in_helper" -ne 1 ] && [ "$in_boundary_check" -ne 1 ]; then
       printf 'FAIL x86-asm-boundary: direct YASM use at build.sh:%d\n' "$line_no" >&2
       failed=1
      fi
      ;;
    esac
    ;;
  esac
  if [ "$in_helper" -eq 1 ] && [ "$line" = "}" ]; then
   in_helper=0
  fi
  if [ "$in_boundary_check" -eq 1 ] && [ "$line" = "}" ]; then
   in_boundary_check=0
  fi
 done < "$0"
 if [ "$failed" -ne 0 ]; then
  exit 1
 fi
 echo "PASS x86-asm-boundary"
}

cmd_test_x86_asm_selector() {
	mkdir -p "${ASM_BUILD}"
	local src="${ASM_BUILD}/x86_asm_selector_probe.asm"
	local ok_asm="${ASM_BUILD}/x86_asm_selector_ok.sh"
	local fail_asm="${ASM_BUILD}/x86_asm_selector_fail.sh"
	local bootstrap_obj="${ASM_BUILD}/x86_asm_selector_bootstrap.o"
	local ok_obj="${ASM_BUILD}/x86_asm_selector_ok.o"
	local fail_obj="${ASM_BUILD}/x86_asm_selector_fail.o"
	local log="${ASM_BUILD}/x86_asm_selector.log"
	local cleanup_files=("$src" "$ok_asm" "$fail_asm" "$bootstrap_obj" "$ok_obj" "$fail_obj" "$log" "${bootstrap_obj}.marker" "${ok_obj}.marker" "${fail_obj}.marker")
	cat > "$src" <<'EOF'
[BITS 64]
section .text
global _start
_start:
    ret
EOF
 cat > "$ok_asm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
out=""
while [ "$#" -gt 0 ]; do
 case "$1" in
  -o)
   shift
   out="$1"
   ;;
 esac
 shift
done
if [ -z "$out" ]; then
 exit 1
fi
printf 'selected\n' > "${out}.marker"
printf 'object\n' > "$out"
EOF
 cat > "$fail_asm" <<'EOF'
#!/usr/bin/env bash
echo "selected assembler failed" >&2
exit 17
EOF
	chmod +x "$ok_asm" "$fail_asm"
	rm -f "$bootstrap_obj" "$ok_obj" "$fail_obj" "$log" "${bootstrap_obj}.marker" "${ok_obj}.marker" "${fail_obj}.marker"
	ER_ASM="" YASM="$ok_asm" asm_x86_obj elf64 "$bootstrap_obj" "$src"
	if [ ! -f "$bootstrap_obj" ] || [ ! -f "${bootstrap_obj}.marker" ]; then
		rm -f "${cleanup_files[@]}"
		echo "FAIL x86-asm-selector: YASM bootstrap assembler was not used" >&2
		exit 1
	fi
	ER_ASM="$ok_asm" asm_x86_obj elf64 "$ok_obj" "$src"
	if [ ! -f "$ok_obj" ] || [ ! -f "${ok_obj}.marker" ]; then
		rm -f "${cleanup_files[@]}"
		echo "FAIL x86-asm-selector: ER_ASM assembler was not used" >&2
		exit 1
	fi
	if ER_ASM="$fail_asm" YASM="$ok_asm" asm_x86_obj elf64 "$fail_obj" "$src" >"$log" 2>&1; then
		cat "$log" >&2
		rm -f "${cleanup_files[@]}"
		echo "FAIL x86-asm-selector: selected assembler failure was ignored" >&2
		exit 1
	fi
	if ! grep 'selected assembler failed' "$log" >/dev/null 2>&1; then
		cat "$log" >&2
		rm -f "${cleanup_files[@]}"
		echo "FAIL x86-asm-selector: selected assembler stderr was not reported" >&2
		exit 1
	fi
	rm -f "${cleanup_files[@]}"
	echo "PASS x86-asm-selector"
}

x86_asm_source_list() {
 find kernel/x86_64 kernel/driver kernel/test kernel/host -type f \( -name '*.asm' -o -name '*.inc' \) ! -name 'test_pi_*' | sort
}

x86_asm_object_source_list() {
 find kernel/x86_64 kernel/driver kernel/test kernel/host -type f -name '*.asm' ! -name 'test_pi_*' | sort
}

cmd_x86_asm_inventory() {
 mkdir -p "${ASM_BUILD}"
 local source_list="${ASM_BUILD}/x86_asm_sources.txt"
 local out="${ASM_BUILD}/x86_asm_inventory.tsv"
 x86_asm_source_list > "$source_list"
 local source_count
 source_count=$(wc -l < "$source_list")
 if [ "$source_count" -eq 0 ]; then
  echo "FAIL x86-asm-inventory: no x86 ASM sources found" >&2
  exit 1
 fi
 {
  printf 'kind\tname\tcount\n'
  printf 'source_files\tx86_asm\t%s\n' "$source_count"
  while IFS= read -r src; do
   awk '
   function trim(s) {
     sub(/^[ \t]+/, "", s)
     sub(/[ \t]+$/, "", s)
     return s
    }
    function is_directive(s) {
     return s == "section" || s == "global" || s == "extern" || s == "default" || s == "bits" ||
            s == "db" || s == "dw" || s == "dd" || s == "dq" ||
            s == "resb" || s == "resw" || s == "resd" || s == "resq" ||
            s == "times" || s == "incbin" || s == "align" || s == "equ" ||
            s == "struc" || s == "endstruc" || s == "istruc" || s == "iend" || s == "at"
    }
    {
     line = $0
     sub(/;.*/, "", line)
     line = trim(line)
     if (line == "") {
      next
     }
     if (line ~ /^\[[Bb][Ii][Tt][Ss][ \t]+/) {
      print "directive\tbits"
      next
     }
     if (line ~ /^[A-Za-z0-9_.$?%]+:[ \t]*/) {
      print "label\tlocal_or_global"
      sub(/^[A-Za-z0-9_.$?%]+:[ \t]*/, "", line)
      line = trim(line)
      if (line == "") {
       next
      }
     }
     if (line ~ /^%[A-Za-z]/) {
      token = line
      sub(/[ \t].*/, "", token)
      print "preproc\t" token
      next
     }
     token = line
     sub(/[ \t].*/, "", token)
     low = tolower(token)
     if (is_directive(low)) {
      print "directive\t" low
      next
     }
     rest = line
     sub(/^[^ \t]+[ \t]+/, "", rest)
     rest_token = rest
     sub(/[ \t].*/, "", rest_token)
     rest_low = tolower(rest_token)
     if (token ~ /^\./ && is_directive(rest_low)) {
      print "label\tlocal_or_global"
      print "directive\t" rest_low
      next
     }
     if (line ~ /^[A-Za-z_.$?][A-Za-z0-9_.$?]*[ \t]+equ[ \t]/) {
      print "directive\tequ"
      next
     }
     if (token ~ /^%[0-9]+$/) {
      print "macro_token\tparameter_mnemonic"
      next
     }
     print "instruction\t" low
    }
   ' "$src"
  done < "$source_list" | sort | uniq -c | awk '{ printf "%s\t%s\t%s\n", $2, $3, $1 }'
 } > "$out"
 cat "$out"
}

cmd_test_x86_asm_inventory() {
 local out
 out=$(cmd_x86_asm_inventory)
 printf '%s\n' "$out" | awk -F '\t' '
  $1 == "source_files" && $2 == "x86_asm" && $3 > 0 { source_seen = 1 }
  $1 == "preproc" && $2 == "%include" && $3 > 0 { include_seen = 1 }
  $1 == "preproc" && $2 == "%macro" && $3 > 0 { macro_seen = 1 }
  $1 == "directive" && $2 == "section" && $3 > 0 { section_seen = 1 }
  $1 == "directive" && $2 == "bits" && $3 > 0 { bits_seen = 1 }
  $1 == "instruction" && $2 == "mov" && $3 > 0 { mov_seen = 1 }
  $1 == "instruction" && ($2 == ".arm" || $2 == ".syntax" || $2 == ".cpu") { arm_seen = 1 }
  END {
   if (!source_seen || !include_seen || !macro_seen || !section_seen || !bits_seen || !mov_seen || arm_seen) {
    exit 1
   }
  }
 '
 echo "PASS x86-asm-inventory"
}

cmd_test_x86_asm_warning_fatal() {
	mkdir -p "${ASM_BUILD}"
	local src="${ASM_BUILD}/x86_asm_warning_probe.asm"
	local obj="${ASM_BUILD}/x86_asm_warning_probe.o"
	local log="${ASM_BUILD}/x86_asm_warning_probe.log"
	local cleanup_files=("$src" "$obj" "$log" "${obj}.asm.err")
	cat > "$src" <<'EOF'
[BITS 64]
section .text
global _start
_start:
    cmp     byte [rax], '\\'
    ret
EOF
	if asm_x86_obj elf64 "$obj" "$src" >"$log" 2>&1; then
		cat "$log" >&2
		rm -f "${cleanup_files[@]}"
		echo "FAIL x86-asm-warning-fatal: warning probe assembled successfully" >&2
		exit 1
	fi
	if ! grep -i 'warning:' "$log" >/dev/null 2>&1; then
		cat "$log" >&2
		rm -f "${cleanup_files[@]}"
		echo "FAIL x86-asm-warning-fatal: warning text not reported" >&2
		exit 1
	fi
	rm -f "${cleanup_files[@]}"
 echo "PASS x86-asm-warning-fatal"
}

cmd_er_asm() {
 mkdir -p "${HOST_BUILD}"
 local src="kernel/host/er_asm.asm"
 local obj="${HOST_BUILD}/er_asm.o"
 local bin="${HOST_BUILD}/er_asm"
 asm_x86_obj elf64 "$obj" "$src"
 ld -nostdlib -static -o "$bin" "$obj"
 echo "  LD  ${bin}"
}

cmd_er_asm_obj() {
 if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: ./build.sh er-asm-obj <source.asm> [out.bin]" >&2
  exit 1
 fi
 local src="$1"
 local out="${2:-}"
 if [ ! -f "$src" ]; then
  echo "error: source not found: ${src}" >&2
  exit 1
 fi
 cmd_er_asm >/dev/null
 if [ -z "$out" ]; then
  mkdir -p "${BUILD_DIR}/er-asm"
  local base="${src##*/}"
  out="${BUILD_DIR}/er-asm/${base%.asm}.bin"
 fi
 "${HOST_BUILD}/er_asm" -f flat -I kernel -o "$out" "$src"
 test -f "$out"
 printf 'er-asm-obj: %s -> %s\n' "$src" "$out"
}

cmd_er_asm_all() {
 cmd_er_asm >/dev/null
 mkdir -p "${BUILD_DIR}/er-asm/all"
 local total=0 passed=0 failed=0
 local fail_log="${BUILD_DIR}/er-asm/all-failures.tsv"
 : > "$fail_log"
 while IFS= read -r src; do
  total=$((total + 1))
  local rel="${src#kernel/}"
  local obj="${BUILD_DIR}/er-asm/all/${rel%.asm}.bin"
  local err="${obj}.err"
  mkdir -p "${obj%/*}"
  if "${HOST_BUILD}/er_asm" -f flat -I kernel -o "$obj" "$src" 2>"$err"; then
   passed=$((passed + 1))
   rm -f "$err"
  else
   failed=$((failed + 1))
   printf '%s\t%s\n' "$src" "$(tr '\n' ' ' < "$err")" >> "$fail_log"
   rm -f "$obj" "$err"
  fi
 done < <(x86_asm_object_source_list)
 printf 'er-asm-all: %d/%d assembled\n' "$passed" "$total"
 if [ "$failed" -ne 0 ]; then
  printf 'er-asm-all: %d failed; see %s\n' "$failed" "$fail_log" >&2
  sed -n '1,20p' "$fail_log" >&2
  exit 1
 fi
}

er_asm_report_ok() {
 local out="$1"
 local require_shape="${2:-basic}"
 awk -F '\t' -v require_shape="$require_shape" '
  $1 == "er_asm_parse" && $2 == "1" { magic = 1 }
  $1 == "lines" && $2 > 0 { lines = 1 }
  $1 == "preproc" && $2 > 0 { preproc = 1 }
  $1 == "directives" && $2 > 0 { directives = 1 }
  END {
   if (!magic || !lines) {
    exit 1
   }
   if (require_shape == "shape" && (!preproc || !directives)) {
    exit 1
   }
  }
 ' "$out"
}

cmd_test_er_asm_parse() {
 cmd_er_asm >/dev/null
 local out="${ASM_BUILD}/er_asm_parse.tsv"
 local count=0
 while IFS= read -r src; do
  "${HOST_BUILD}/er_asm" --parse-only "$src" > "$out"
  er_asm_report_ok "$out"
  count=$((count + 1))
 done < <(x86_asm_source_list)
 "${HOST_BUILD}/er_asm" --parse-only "${ASM_DIR}/macros.inc" > "$out"
 er_asm_report_ok "$out" shape
 if [ "$count" -eq 0 ]; then
  echo "FAIL er-asm-parse: no sources parsed" >&2
  exit 1
 fi
 echo "PASS er-asm-parse ${count} sources"
}

cmd_test_er_asm_cli() {
 cmd_er_asm >/dev/null
 local src="${ASM_BUILD}/er_asm_exit_probe.asm"
 local src_status="${ASM_BUILD}/er_asm_exit_status_probe.asm"
 local src_include="${ASM_BUILD}/er_asm_exit_include_probe.asm"
 local src_local_include="${ASM_BUILD}/er_asm_exit_local_include_probe.asm"
 local src_char="${ASM_BUILD}/er_asm_exit_char_probe.asm"
 local src_64reg="${ASM_BUILD}/er_asm_exit_64reg_probe.asm"
 local src_named="${ASM_BUILD}/er_asm_exit_named_probe.asm"
 local src_long_named="${ASM_BUILD}/er_asm_exit_long_named_probe.asm"
 local src_return_fn="${ASM_BUILD}/er_asm_return_fn_probe.asm"
 local src_zero_fn="${ASM_BUILD}/er_asm_zero_fn_probe.asm"
 local src_identity_fn="${ASM_BUILD}/er_asm_identity_fn_probe.asm"
 local src_local_call="${ASM_BUILD}/er_asm_local_call_probe.asm"
 local src_negative="${ASM_BUILD}/er_asm_negative_probe.asm"
 local src_and_eax="${ASM_BUILD}/er_asm_and_eax_probe.asm"
 local src_and_edx="${ASM_BUILD}/er_asm_and_edx_probe.asm"
 local src_shr_acc="${ASM_BUILD}/er_asm_shr_acc_probe.asm"
 local src_data_dirs="${ASM_BUILD}/er_asm_data_dirs_probe.asm"
 local src_status_macros="${ASM_BUILD}/er_asm_status_macros_probe.asm"
 local src_rel_mem="${ASM_BUILD}/er_asm_rel_mem_probe.asm"
 local src_reg_moves="${ASM_BUILD}/er_asm_reg_moves_probe.asm"
 local src_sized_mem="${ASM_BUILD}/er_asm_sized_mem_probe.asm"
 local src_test_call="${ASM_BUILD}/er_asm_test_call_probe.asm"
 local src_check_zero="${ASM_BUILD}/er_asm_check_zero_probe.asm"
 local src_cmp_below="${ASM_BUILD}/er_asm_cmp_below_probe.asm"
 local src_test_exit_total="${ASM_BUILD}/er_asm_test_exit_total_probe.asm"
 local src_cmos_macros="${ASM_BUILD}/er_asm_cmos_macros_probe.asm"
 local src_cmos_time="${ASM_BUILD}/er_asm_cmos_time_probe.asm"
 local src_define_product="${ASM_BUILD}/er_asm_define_product_probe.asm"
 local local_inc_file="${ASM_BUILD}/local_exit_defs.inc"
 local inc_dir_a="${ASM_BUILD}/er_asm_inc_a"
 local inc_file_a="${inc_dir_a}/exit_more_defs.inc"
 local inc_dir="${ASM_BUILD}/er_asm_inc"
 local inc_file="${inc_dir}/exit_defs.inc"
 local bad_src="${ASM_BUILD}/er_asm_bad_exit_probe.asm"
 local bad_u32_src="${ASM_BUILD}/er_asm_bad_u32_probe.asm"
 local bad_hex_src="${ASM_BUILD}/er_asm_bad_hex_probe.asm"
 local bad_dup_equ_src="${ASM_BUILD}/er_asm_bad_dup_equ_probe.asm"
 local bad_define_tail_src="${ASM_BUILD}/er_asm_bad_define_tail_probe.asm"
 local out="${ASM_BUILD}/er_asm_exit_probe.bin"
 local log="${ASM_BUILD}/er_asm_unsupported.log"
 local cleanup_files=("$src" "$src_status" "$src_include" "$src_local_include" "$src_char" "$src_64reg" "$src_named" "$src_long_named" "$src_return_fn" "$src_zero_fn" "$src_identity_fn" "$src_local_call" "$src_negative" "$src_and_eax" "$src_and_edx" "$src_shr_acc" "$src_data_dirs" "$src_status_macros" "$src_rel_mem" "$src_reg_moves" "$src_sized_mem" "$src_test_call" "$src_check_zero" "$src_cmp_below" "$src_test_exit_total" "$src_cmos_macros" "$src_cmos_time" "$src_define_product" "$local_inc_file" "$bad_src" "$bad_u32_src" "$bad_hex_src" "$bad_dup_equ_src" "$bad_define_tail_src" "$out" "$log")
 cleanup_er_asm_cli() {
  rm -rf "$inc_dir_a"
  rm -rf "$inc_dir"
  rm -f "${cleanup_files[@]}"
 }
 expect_er_asm_reject() {
  local reject_src="$1"
  local reject_label="$2"
  if "${HOST_BUILD}/er_asm" -f flat -I kernel -o "$out" "$reject_src" >"$log" 2>&1; then
   cat "$log" >&2
   cleanup_er_asm_cli
   echo "FAIL er-asm-cli: ${reject_label} assembled" >&2
   exit 1
  fi
  if ! grep -E 'unsupported source shape|assembly failed' "$log" >/dev/null 2>&1; then
   cat "$log" >&2
   cleanup_er_asm_cli
   echo "FAIL er-asm-cli: ${reject_label} did not report cause" >&2
   exit 1
  fi
  rm -f "$out" "$log"
 }
 expect_er_asm_bytes() {
  local bytes_src="$1"
  local expected_hex="$2"
  local bytes_label="$3"
  shift 3
  "${HOST_BUILD}/er_asm" -f flat "$@" -o "$out" "$bytes_src"
  local actual_hex
  actual_hex="$(od -An -tx1 -v "$out" | tr -d ' \n')"
  if [ "$actual_hex" != "$expected_hex" ]; then
   cleanup_er_asm_cli
   echo "FAIL er-asm-cli: ${bytes_label} bytes ${actual_hex}, expected ${expected_hex}" >&2
   exit 1
  fi
  rm -f "$out"
 }
 expect_er_asm_builds() {
  local build_src="$1"
  local build_label="$2"
  "${HOST_BUILD}/er_asm" -f flat -I kernel -o "$out" "$build_src"
  if [ ! -s "$out" ]; then
   cleanup_er_asm_cli
   echo "FAIL er-asm-cli: ${build_label} emitted empty flat binary" >&2
   exit 1
  fi
  rm -f "$out"
 }
 mkdir -p "$inc_dir_a"
 mkdir -p "$inc_dir"
 cat > "$src" <<'EOF'
[BITS 64]
section .text
global _start
_start:
    mov     eax, 60
    xor     edi, edi
    syscall
EOF
 cat > "$inc_file" <<'EOF'
%define SYSCALL_EXIT 0x3c
INCLUDED_STATUS equ 0x2d
EOF
 cat > "$inc_file_a" <<'EOF'
INCLUDED_DELTA equ 3
EOF
 cat > "$local_inc_file" <<'EOF'
%define SYSCALL_EXIT 0x3c
LOCAL_STATUS equ 0x2e
EOF
 cat > "$src_include" <<'EOF'
[BITS 64]
%include "exit_more_defs.inc"
%include "exit_defs.inc"
section .text
global _start
_start:
    mov     eax, SYSCALL_EXIT
    mov     edi, INCLUDED_STATUS
    syscall
EOF
 cat > "$src_local_include" <<'EOF'
[BITS 64]
%include "local_exit_defs.inc"
section .text
global _start
_start:
    mov     eax, SYSCALL_EXIT
    mov     edi, LOCAL_STATUS
    syscall
EOF
 cat > "$src_status" <<'EOF'
[BITS 64]
%define SYSCALL_EXIT 0x3c
STATUS_CODE equ 0x12c
section .text
global _start
_start:
    mov     eax, SYSCALL_EXIT
    mov     edi, STATUS_CODE
    syscall
EOF
 cat > "$src_char" <<'EOF'
[BITS 64]
section .text
global _start
_start:
    mov     eax, 60
    mov     edi, '/'
    syscall
EOF
 cat > "$src_64reg" <<'EOF'
[BITS 64]
section .text
global _start
_start:
    mov     rax, 60
    mov     rdi, '0'
    syscall
EOF
 cat > "$src_named" <<'EOF'
[BITS 64]
section .text
global ermain
ermain:
    mov     eax, 60
    mov     edi, '1'
    syscall
EOF
 cat > "$src_long_named" <<'EOF'
[BITS 64]
section .text
global er_isdigit
er_isdigit:
    mov     eax, 60
    mov     edi, '2'
    syscall
EOF
 cat > "$src_return_fn" <<'EOF'
[BITS 64]
section .text
global er_const
er_const:
    mov     eax, '3'
    ret
EOF
 cat > "$src_zero_fn" <<'EOF'
[BITS 64]
section .text
global er_zero
er_zero:
    xor     eax, eax
    ret
EOF
 cat > "$src_identity_fn" <<'EOF'
[BITS 64]
section .text
global er_identity
er_identity:
    mov     eax, edi
    ret
EOF
 cat > "$src_local_call" <<'EOF'
[BITS 64]
section .text
global _start
_start:
    call    .done
    ret
.done:
    ret
EOF
 cat > "$src_negative" <<'EOF'
[BITS 64]
section .text
global _start
_start:
    mov     eax, -1
    ret
EOF
 cat > "$src_and_eax" <<'EOF'
[BITS 64]
section .text
global _start
_start:
    and     eax, 0x0000FFFF
    ret
EOF
 cat > "$src_and_edx" <<'EOF'
[BITS 64]
section .text
global _start
_start:
    and     edx, 0x55555555
    ret
EOF
 cat > "$src_shr_acc" <<'EOF'
[BITS 64]
section .text
global _start
_start:
    shr     eax, 8
    shr     rax, 32
    ret
EOF
 cat > "$src_data_dirs" <<'EOF'
[BITS 64]
section .data
    dw      0x1234, 5
    dd      0x89abcdef
section .bss
    resb    2
    resw    1
    resd    1
    resq    1
EOF
 cat > "$src_status_macros" <<'EOF'
[BITS 64]
section .text
global _start
_start:
    er_ok
    er_err  12
    ret
EOF
 cat > "$src_rel_mem" <<'EOF'
[BITS 64]
section .data
sym: resd 1
section .text
global _start
_start:
    mov     [rel sym], edi
    inc     dword [rel sym]
EOF
 cat > "$src_reg_moves" <<'EOF'
[BITS 64]
section .text
global _start
_start:
    mov     rsi, rdx
    mov     edx, ecx
    mov     rcx, rdx
    mov     eax, esi
    ret
EOF
 cat > "$src_sized_mem" <<'EOF'
[BITS 64]
section .text
global _start
_start:
    mov     dword [rdx], 0x01020304
    mov     dword [rcx], 0
EOF
 cat > "$src_test_call" <<'EOF'
[BITS 64]
TEST_BSS_TOTAL_PASSED
section .text
global _start
_start:
    TEST_CALL_EAX er_probe, 1, 2
EOF
 cat > "$src_check_zero" <<'EOF'
[BITS 64]
section .text
global _start
_start:
    er_check_zero eax, .done32
    er_check_zero rdx, .done
    ret
.done32:
    ret
.done:
    ret
EOF
 cat > "$src_cmp_below" <<'EOF'
[BITS 64]
section .text
global _start
_start:
    er_cmp_below rcx, r10, .loop
    ret
.loop:
    ret
EOF
 cat > "$src_test_exit_total" <<'EOF'
[BITS 64]
section .text
global _start
_start:
    TEST_EXIT_PASSED_TOTAL
EOF
 cat > "$src_cmos_macros" <<'EOF'
[BITS 64]
section .text
global _start
_start:
    _cmos_out_index dil
    _cmos_in_data
    _cmos_out_data sil
EOF
 cat > "$src_cmos_time" <<'EOF'
[BITS 64]
%define CMOS_RTC_HOUR 0x04
section .text
global _start
_start:
    push    r8
    push    r9
    push    r10
    mov     dil, CMOS_RTC_HOUR
    mov     r8b, al
    mov     r9b, al
    mov     r10b, al
    movzx   edi, r8b
    movzx   edi, r9b
    movzx   edi, r10b
    movzx   eax, r8b
    movzx   eax, r9b
    movzx   eax, r10b
    mov     [r12], ax
    mov     [r13], ax
    mov     [r14], ax
    pop     r10
    pop     r9
    pop     r8
    ret
EOF
 cat > "$src_define_product" <<'EOF'
[BITS 64]
%define MAX_DECODED_OPS 512 * 1024
section .text
global _start
_start:
    mov     eax, MAX_DECODED_OPS
    ret
EOF
 cat > "$bad_src" <<'EOF'
[BITS 64]
section .text
global _start
_start:
    mov     eax, UNKNOWN_CONST
    xor     edi, edi
    syscall
EOF
 cat > "$bad_hex_src" <<'EOF'
[BITS 64]
section .text
global _start
_start:
    mov     eax, 0x100000000
    xor     edi, edi
    syscall
EOF
 cat > "$bad_u32_src" <<'EOF'
[BITS 64]
section .text
global _start
_start:
    mov     eax, 4294967296
    xor     edi, edi
    syscall
EOF
 cat > "$bad_dup_equ_src" <<'EOF'
[BITS 64]
%define SYSCALL_EXIT 0x3c
syscall_exit equ 60
section .text
global _start
_start:
    mov     eax, SYSCALL_EXIT
    xor     edi, edi
    syscall
EOF
 cat > "$bad_define_tail_src" <<'EOF'
[BITS 64]
%define SYSCALL_EXIT 0x3c trailing
section .text
global _start
_start:
    mov     eax, SYSCALL_EXIT
    xor     edi, edi
    syscall
EOF
 expect_er_asm_bytes "$src" "b83c00000031ff0f05" "generated exit" -I "${ASM_DIR}" -DTEST_DEFINE -dTEST_FLAG
 expect_er_asm_bytes "$src_status" "b83c000000bf2c0100000f05" "generated status"
 expect_er_asm_bytes "$src_include" "b83c000000bf2d0000000f05" "included exit" -I "$inc_dir_a" -I "$inc_dir"
 expect_er_asm_bytes "$src_include" "b83c000000bf2d0000000f05" "joined include flag" "-I${inc_dir_a}" "-I${inc_dir}"
 expect_er_asm_bytes "$src_local_include" "b83c000000bf2e0000000f05" "local include"
 expect_er_asm_bytes "$src_char" "b83c000000bf2f0000000f05" "char immediate"
 expect_er_asm_bytes "$src_64reg" "48c7c03c00000048c7c7300000000f05" "64-bit register"
 expect_er_asm_bytes "$src_named" "b83c000000bf310000000f05" "named global"
 expect_er_asm_bytes "$src_long_named" "b83c000000bf320000000f05" "long global"
 expect_er_asm_bytes "$src_return_fn" "b833000000c3" "return function"
 expect_er_asm_bytes "$src_zero_fn" "31c0c3" "zero function"
 expect_er_asm_bytes "$src_identity_fn" "89f8c3" "identity function"
 expect_er_asm_bytes "$src_local_call" "e801000000c3c3" "local call"
 expect_er_asm_bytes "$src_negative" "b8ffffffffc3" "negative immediate"
 expect_er_asm_bytes "$src_and_eax" "25ffff0000c3" "and eax immediate"
 expect_er_asm_bytes "$src_and_edx" "81e255555555c3" "and edx immediate"
 expect_er_asm_bytes "$src_shr_acc" "c1e80848c1e820c3" "shr accumulator immediate"
 expect_er_asm_bytes "$src_data_dirs" "34120500efcdab8900000000000000000000000000000000" "data directives"
 expect_er_asm_bytes "$src_status_macros" "31d2ba0c000000c3" "status macros"
 expect_er_asm_bytes "$src_rel_mem" "00000000893df6ffffffff05f0ffffff" "rel memory ops"
 expect_er_asm_bytes "$src_reg_moves" "4889d689ca4889d189f0c3" "register moves"
 expect_er_asm_bytes "$src_sized_mem" "c70204030201c70100000000" "sized memory immediates"
 expect_er_asm_bytes "$src_cmos_time" "41504151415240b7044188c04188c14188c2410fb6f8410fb6f9410fb6fa410fb6c0410fb6c1410fb6c26641890424664189450066418906415a41594158c3" "cmos time byte and stack ops"
 expect_er_asm_bytes "$src_define_product" "b800000800c3" "define product expression"
 expect_er_asm_builds "$src_test_call" "test call macro"
 expect_er_asm_builds "$src_check_zero" "check zero macro"
 expect_er_asm_builds "$src_cmp_below" "cmp below macro"
 expect_er_asm_builds "$src_test_exit_total" "test exit passed total macro"
 expect_er_asm_builds "$src_cmos_macros" "cmos local macros"
 expect_er_asm_builds "${ASM_DIR}/rt/ctype.asm" "ctype flat binary"
 expect_er_asm_builds "kernel/driver/portio.asm" "portio flat binary"
 expect_er_asm_builds "${ASM_DIR}/wasm/test_table.asm" "test table flat binary"
 expect_er_asm_builds "${ASM_DIR}/rt/math_hash.asm" "math hash flat binary"
 expect_er_asm_builds "kernel/driver/acpi.asm" "acpi flat binary"
 expect_er_asm_reject "$bad_hex_src" "out-of-range hex immediate"
 expect_er_asm_reject "$bad_dup_equ_src" "duplicate equ"
 expect_er_asm_reject "$bad_define_tail_src" "trailing define junk"
 expect_er_asm_reject "$bad_u32_src" "out-of-range u32 immediate"
 expect_er_asm_reject "$bad_src" "wrong instruction sequence"
 expect_er_asm_reject "${ASM_DIR}/macros.inc" "unsupported source"
 cleanup_er_asm_cli
 echo "PASS er-asm-cli"
}

cmd_test_er_efiboot() {
	cmd_er_efiboot >/dev/null
	local tool="${HOST_BUILD}/er_efiboot"
	local guid="8be4df61-93ca-11d2-aa0d-00e098032b8c"
	local db_guid="d719b2cb-3d3a-4596-a3bc-dad00e67656f"
	local out
	out=$("$tool" --dry-run --set-next 0007)
	[ "$out" = "dry-run /sys/firmware/efi/efivars/BootNext-${guid}6 bytes" ] || {
		echo "FAIL er-efiboot set-next dry-run: ${out}" >&2
		return 1
	}
	out=$("$tool" --dry-run --set-order 0007,0001,0002)
	[ "$out" = "dry-run /sys/firmware/efi/efivars/BootOrder-${guid}10 bytes" ] || {
		echo "FAIL er-efiboot set-order dry-run: ${out}" >&2
		return 1
	}
	out=$("$tool" --dry-run --prepend-order 0007)
	[ "$out" = "dry-run /sys/firmware/efi/efivars/BootOrder-${guid}6 bytes" ] || {
		echo "FAIL er-efiboot prepend-order dry-run: ${out}" >&2
		return 1
	}
	out=$("$tool" --dry-run --create-file 0007 EdgeRun '\EFI\edgerun\bootx64.efi')
	[ "$out" = "dry-run /sys/firmware/efi/efivars/Boot0007-${guid}84 bytes" ] || {
		echo "FAIL er-efiboot create-file dry-run: ${out}" >&2
		return 1
	}
	out=$("$tool" --dry-run --read-file 0007)
	[ "$out" = "dry-run /sys/firmware/efi/efivars/Boot0007-${guid}0 bytes" ] || {
		echo "FAIL er-efiboot read-file dry-run: ${out}" >&2
		return 1
	}
	out=$("$tool" --dry-run --delete-file 0007)
	[ "$out" = "dry-run /sys/firmware/efi/efivars/Boot0007-${guid}0 bytes" ] || {
		echo "FAIL er-efiboot delete-file dry-run: ${out}" >&2
		return 1
	}
	out=$("$tool" --dry-run --read-secure SecureBoot)
	[ "$out" = "dry-run /sys/firmware/efi/efivars/SecureBoot-${guid}0 bytes" ] || {
		echo "FAIL er-efiboot read-secure dry-run: ${out}" >&2
		return 1
	}
	out=$("$tool" --dry-run --read-secure db)
	[ "$out" = "dry-run /sys/firmware/efi/efivars/db-${db_guid}0 bytes" ] || {
		echo "FAIL er-efiboot read-secure db dry-run: ${out}" >&2
		return 1
	}
	out=$("$tool" --dry-run --write-auth PK /dev/null)
	[ "$out" = "dry-run /sys/firmware/efi/efivars/PK-${guid}4 bytes" ] || {
		echo "FAIL er-efiboot write-auth dry-run: ${out}" >&2
		return 1
	}
	out=$("$tool" --dry-run --capsule /dev/null)
	[ "$out" = "dry-run /dev/efi_capsule_loader0 bytes" ] || {
		echo "FAIL er-efiboot capsule dry-run: ${out}" >&2
		return 1
	}
	if "$tool" --set-next bad >/dev/null 2>&1; then
		echo "FAIL er-efiboot rejected invalid boot number" >&2
		return 1
	fi
	if "$tool" --dry-run --write-auth SecureBoot /dev/null >/dev/null 2>&1; then
		echo "FAIL er-efiboot rejected unauthenticated secure variable write" >&2
		return 1
	fi
	echo "PASS er-efiboot"
}

cmd_test_list() {
 printf 'target\tcategory\tsubsystem\tdefault\tdescription\n'
 while IFS='|' read -r target category subsystem default runner description; do
  [ -n "$target" ] || continue
  printf '%s\t%s\t%s\t%s\t%s\n' "$target" "$category" "$subsystem" "$default" "$description"
 done < <(test_registry)
}

cmd_test_help() {
 while IFS='|' read -r target category subsystem default runner description; do
  [ -n "$target" ] || continue
  printf '  %-22s [%s/%s] %s\n' "$target" "$category" "$subsystem" "$description"
 done < <(test_registry)
}

cmd_test_registered() {
 local wanted="$1"
 while IFS='|' read -r target category subsystem default runner description; do
  [ -n "$target" ] || continue
  if [ "$target" = "$wanted" ]; then
   test_run_target "$wanted"
   return
  fi
 done < <(test_registry)
 echo "unknown test target: ${wanted}" >&2
 exit 1
}

test_run_target() {
 local wanted="$1"
 while IFS='|' read -r target category subsystem default runner description; do
  [ -n "$target" ] || continue
  if [ "$target" = "$wanted" ]; then
   "$runner"
   return
  fi
 done < <(test_registry)
 echo "unknown test target: ${wanted}" >&2
 exit 1
}

cmd_test_status_one() {
 local wanted="$1"
 local found=0 meta_category="" meta_subsystem="" meta_runner=""
 while IFS='|' read -r target reg_category reg_subsystem reg_default reg_runner reg_description; do
  [ -n "$target" ] || continue
  if [ "$target" = "$wanted" ]; then
   found=1
   meta_category="$reg_category"
   meta_subsystem="$reg_subsystem"
   meta_runner="$reg_runner"
   break
  fi
 done < <(test_registry)
 if [ "$found" -ne 1 ]; then
  echo "unknown test target: ${wanted}" >&2
  exit 1
 fi

 local status_dir="${BUILD_DIR}/test-status"
 mkdir -p "$status_dir"
 local log_path="${status_dir}/${wanted}.log"
 local status="pass"
 if ! "$meta_runner" >"$log_path" 2>&1; then
  status="fail"
 fi
 printf '%s\t%s\t%s\t%s\t%s\n' "$wanted" "$meta_category" "$meta_subsystem" "$status" "$log_path"
 if [ "$status" = "fail" ]; then
  return 1
 fi
}

cmd_test_status() {
 if [ "$#" -gt 0 ]; then
  case "$1" in
   --category)
    if [ "$#" -ne 2 ]; then
     echo "usage: ./build.sh test-status --category <name>" >&2
     exit 1
    fi
    ;;
   --subsystem)
    if [ "$#" -ne 2 ]; then
     echo "usage: ./build.sh test-status --subsystem <name>" >&2
     exit 1
    fi
    ;;
   --core)
    if [ "$#" -ne 1 ]; then
     echo "usage: ./build.sh test-status --core" >&2
     exit 1
    fi
    ;;
  esac
 fi
 printf 'target\tcategory\tsubsystem\tstatus\tlog\n'
 local failed=0
 if [ "$#" -gt 0 ] && [ "$1" = "--category" ]; then
  local wanted_category="$2"
  while IFS='|' read -r target category subsystem default runner description; do
   [ -n "$target" ] || continue
   [ "$default" = "yes" ] || continue
   [ "$category" = "$wanted_category" ] || continue
   cmd_test_status_one "$target" || failed=1
 done < <(test_registry)
 elif [ "$#" -gt 0 ] && [ "$1" = "--subsystem" ]; then
  local wanted_subsystem="$2"
  while IFS='|' read -r target category subsystem default runner description; do
   [ -n "$target" ] || continue
   [ "$default" = "yes" ] || continue
   [ "$subsystem" = "$wanted_subsystem" ] || continue
   cmd_test_status_one "$target" || failed=1
 done < <(test_registry)
 elif [ "$#" -gt 0 ] && [ "$1" = "--core" ]; then
  while IFS='|' read -r target category subsystem default runner description; do
   [ -n "$target" ] || continue
   [ "$default" = "yes" ] || continue
   case "$category" in
    unit|contract) cmd_test_status_one "$target" || failed=1 ;;
   esac
  done < <(test_registry)
 elif [ "$#" -gt 0 ]; then
  local target
  for target in "$@"; do
   cmd_test_status_one "$target" || failed=1
  done
 else
  while IFS='|' read -r target category subsystem default runner description; do
   [ -n "$target" ] || continue
   [ "$default" = "yes" ] || continue
   cmd_test_status_one "$target" || failed=1
  done < <(test_registry)
 fi
 if [ "$failed" -ne 0 ]; then
  exit 1
 fi
}

cmd_test_category() {
 local wanted="$1"
 while IFS='|' read -r target category subsystem default runner description; do
  [ -n "$target" ] || continue
  [ "$category" = "$wanted" ] || continue
  [ "$default" = "yes" ] || continue
  "$runner"
 done < <(test_registry)
}

cmd_test_subsystem() {
 local wanted="$1"
 while IFS='|' read -r target category subsystem default runner description; do
  [ -n "$target" ] || continue
  [ "$subsystem" = "$wanted" ] || continue
  [ "$default" = "yes" ] || continue
  "$runner"
 done < <(test_registry)
}

cmd_test_core() {
 while IFS='|' read -r target category subsystem default runner description; do
  [ -n "$target" ] || continue
  [ "$default" = "yes" ] || continue
  case "$category" in
   unit|contract) "$runner" ;;
  esac
 done < <(test_registry)
}

cmd_test_app() {
  local roots=(
   src/pi_usb_boot_host.zig
   src/pi_usb_control_host.zig
   src/clock.zig
   src/bytes.zig
   src/math.zig
   src/crypto.zig
   src/preimage.zig
   src/identity.zig
   src/seal.zig
   src/kernel_authority_test.zig
   src/object.zig
   src/store.zig
   src/encrypted_chat.zig
   src/app_encrypted_chat.zig
   src/app_pipeline_dashboard.zig
   src/sdk.zig
   src/project_intro_video.zig
   src/media_video_dump.zig
   src/media_test.zig
   src/ui_core_test.zig
   src/ui_codec_test.zig
   src/svg_path_parser.zig
   src/component_gallery_test.zig
   src/jc3248_display_frame.zig
   src/wayland_window_host.zig
   src/drm_gbm_host.zig
  )
 local root
 for root in "${roots[@]}"; do
  (cd app && zig test -ODebug --dep er_std -Mroot="$root" -Mer_std=src/std.zig)
 done
}

cmd_app_ui_wasm() {
 mkdir -p "${BUILD_DIR}/app"
 (cd app && zig build-exe -ODebug \
  -target wasm32-freestanding \
  -fno-entry \
  -fsingle-threaded \
  --export-memory \
  --export=er_ui_wasm_version \
  --export=er_ui_wasm_max_slots \
  --export=er_ui_wasm_slot_count \
  --export=er_ui_wasm_alloc \
  --export=er_ui_wasm_free \
  --export=er_ui_wasm_clear \
  --export=er_ui_wasm_deserialize \
  --export=er_ui_wasm_serialize \
  --export=er_ui_wasm_render \
  --export=er_ui_wasm_measure \
  --export=er_ui_wasm_new_text \
  --export=er_ui_wasm_new_button \
  --export=er_ui_wasm_new_row_item \
  --export=er_ui_wasm_new_badge \
  --export=er_ui_wasm_new_separator \
  --export=er_ui_wasm_new_icon \
  --export=er_ui_wasm_new_checkbox \
  --export=er_ui_wasm_new_input \
  --export=er_ui_wasm_new_slider \
  --export=er_ui_wasm_new_card \
  --dep er_std \
  -Mroot=src/ui_wasm_root.zig \
  -Mer_std=src/std.zig \
  -femit-bin=../${BUILD_DIR}/app/edgerun-ui-components.wasm)
}

cmd_immutable_kernel_gop_smoke_efi() {
 mkdir -p "${BUILD_DIR}/app/immutable-kernel-gop-smoke"
 (cd app && zig build-exe -OReleaseFast \
  -target x86_64-uefi \
  -fstrip \
  --dep er_std \
  -Mroot=src/immutable_kernel_gop_smoke_uefi.zig \
  -Mer_std=src/std.zig \
  -femit-bin=../${BUILD_DIR}/app/immutable-kernel-gop-smoke/BOOTX64.EFI)
}

cmd_sdk_cli() {
 mkdir -p "${BUILD_DIR}/app"
 (cd app && zig build-exe -ODebug \
  --dep er_std \
  -Mroot=src/sdk_cli.zig \
  -Mer_std=src/std.zig \
  -femit-bin=../${BUILD_DIR}/app/edgerun-sdk)
 "${BUILD_DIR}/app/edgerun-sdk"
}

cmd_sdk_bench() {
 mkdir -p "${BUILD_DIR}/app"
 (cd app && zig build-exe -ODebug \
  --dep er_std \
  -Mroot=src/sdk_bench.zig \
  -Mer_std=src/std.zig \
  -femit-bin=../${BUILD_DIR}/app/edgerun-sdk-bench)
 "${BUILD_DIR}/app/edgerun-sdk-bench"
}

cmd_app_exe() {
 local root="$1"
 local out="$2"
 mkdir -p "${BUILD_DIR}/app"
 (cd app && zig build-exe -ODebug \
  --dep er_std \
  -Mroot="$root" \
  -Mer_std=src/std.zig \
  -femit-bin="../${BUILD_DIR}/app/${out}")
 "${BUILD_DIR}/app/${out}"
}

cmd_app_exe_build_only() {
 local root="$1"
 local out="$2"
 mkdir -p "${BUILD_DIR}/app"
 (cd app && zig build-exe -ODebug \
  --dep er_std \
  -Mroot="$root" \
  -Mer_std=src/std.zig \
  -femit-bin="../${BUILD_DIR}/app/${out}")
}

cmd_project_intro_video() {
 cmd_app_exe src/project_intro_video.zig edgerun-project-intro-video
}

cmd_chat_preview() {
 cmd_app_exe src/encrypted_chat_preview.zig edgerun-chat-preview
}

cmd_jc3248_frame() {
 cmd_app_exe src/jc3248_display_frame.zig edgerun-jc3248-frame
}

cmd_build_dashboard() {
 mkdir -p "${BUILD_DIR}/app"
 (cd app && zig build-exe -ODebug \
  --dep er_std \
  -Mroot=src/build_dashboard.zig \
  -Mer_std=src/std.zig \
  -femit-bin="../${BUILD_DIR}/app/edgerun-build-dashboard")
}

cmd_media_video_dump() {
 mkdir -p "${BUILD_DIR}/app"
 (cd app && zig build-exe -ODebug \
  --dep er_std \
  -Mroot=src/media_video_dump.zig \
  -Mer_std=src/std.zig \
  -femit-bin="../${BUILD_DIR}/app/edgerun-media-video-dump")
}

cmd_pi_usb_load() {
 mkdir -p "${BUILD_DIR}/app"
 (cd app && zig build-exe -ODebug \
  --dep er_std \
  -Mroot=src/pi_usb_boot_host.zig \
  -Mer_std=src/std.zig \
  -femit-bin="../${BUILD_DIR}/app/edgerun-pi-usb-boot-host")
}

cmd_pi_usb_control() {
 mkdir -p "${BUILD_DIR}/app"
 (cd app && zig build-exe -ODebug \
  --dep er_std \
  -Mroot=src/pi_usb_control_host.zig \
  -Mer_std=src/std.zig \
  -femit-bin="../${BUILD_DIR}/app/edgerun-pi-usb-control-host")
}

cmd_wayland_window() {
 mkdir -p "${BUILD_DIR}/app"
 (cd app && zig build-exe -ODebug \
  --dep er_std \
  -Mroot=src/wayland_window_host.zig \
  -Mer_std=src/std.zig \
  -femit-bin="../${BUILD_DIR}/app/edgerun-wayland-window")
}

cmd_drm_gbm_window() {
 mkdir -p "${BUILD_DIR}/app"
 (cd app && zig build-exe -ODebug \
  --dep er_std \
  -Mroot=src/drm_gbm_host.zig \
  -Mer_std=src/std.zig \
  -femit-bin="../${BUILD_DIR}/app/edgerun-drm-gbm-window")
}

cmd_ifstatus() {
 mkdir -p "${BUILD_DIR}/app"
 (cd app && zig build-exe -ODebug \
  --dep er_std \
  -Mroot=src/ifstatus.zig \
  -Mer_std=src/std.zig \
  -femit-bin="../${BUILD_DIR}/app/edgerun-ifstatus")
}

cmd_tpm_real_check_build() {
 mkdir -p "${BUILD_DIR}/app"
 (cd app && zig build-exe -ODebug \
  --dep er_std \
  -Mroot=src/tpm_real_check.zig \
  -Mer_std=src/std.zig \
  -femit-bin="../${BUILD_DIR}/app/edgerun-tpm-real-check-zig")
}

cmd_real_tpm() {
 cmd_tpm_real_check_build
 "${BUILD_DIR}/app/edgerun-tpm-real-check-zig"
}

cmd_app() {
 cmd_test_app
 cmd_app_ui_wasm
 cmd_immutable_kernel_gop_smoke_efi
 cmd_sdk_cli
 cmd_sdk_bench
 cmd_app_exe_build_only src/project_intro_video.zig edgerun-project-intro-video
 cmd_app_exe_build_only src/encrypted_chat_preview.zig edgerun-chat-preview
 cmd_app_exe_build_only src/jc3248_display_frame.zig edgerun-jc3248-frame
 cmd_build_dashboard
 cmd_media_video_dump
 cmd_ifstatus
 cmd_pi_usb_load
 cmd_pi_usb_control
 cmd_wayland_window
 cmd_drm_gbm_window
}

cmd_test() {
 while IFS='|' read -r target category subsystem default runner description; do
  [ -n "$target" ] || continue
  [ "$default" = "yes" ] || continue
  "$runner"
 done < <(test_registry)
}

build_test_ldscript() {
	local name="$1"; shift
	local src="${TEST_DIR}/${name}.asm"
	local obj="${ASM_BUILD}/${name}.o"
	local bin="${ASM_BUILD}/${name%_self}"
	asm_x86_obj elf64 "$obj" "$src"
	local dep_obj="${ASM_BUILD}/runtime.o"
	elf64 "${ASM_DIR}/rt/runtime.asm" "$dep_obj"
	ld -T "${TEST_DIR}/test_jit.ld" -nostdlib -static -o "$bin" "$obj" "$dep_obj" "$@"
	echo "  LD  ${bin}"
	"$bin"
}

cmd_test_recursion_valid() {
	build_test_ldscript "test_recursion_valid"
}

cmd_test_recursion_invalid() {
	build_test_ldscript "test_recursion_invalid"
}

cmd_test_wasm_jit() {
	build_test_ldscript "test_wasm_jit_self"
}

cmd_test_wasm_compiler() {
	build_test_ldscript "test_wasm_compiler_self"
}

cmd_test_ctype() {
	build_test_self "test_ctype_self" "rt/ctype"
}

cmd_test_clock() {
	build_test_self "test_clock_self" "rt/clock" "rt/bytes" "rt/runtime"
}

cmd_test_identity() {
	build_test_self "test_identity_self" "crypto/identity" "crypto/blake3" "rt/bytes" "rt/clock" "rt/runtime"
}

cmd_test_serial() {
	build_test_self "test_serial_self" "../driver/serial" "rt/runtime"
}

cmd_test_uvc() {
	build_test_stubbed "test_uvc_self" "stubs_xhci" "../driver/uvc" "../driver/xhci"
}

cmd_test_http() {
	build_test_stubbed "test_http_self" "stubs_http" "net/http"
}

cmd_test_ipv4() {
	build_test_self "test_ipv4_self" "net/ipv4"
}

cmd_test_tcp() {
	build_flat_kernel_test "test_tcp" "${TEST_DIR}/test_tcp_self.asm" "test:stubs_tcp" "net/tcp"
}

cmd_test_store() {
	build_flat_kernel_test "test_store" "${TEST_DIR}/test_store_self.asm" "../driver/store" "rt/runtime" "rt/bytes"
}

cmd_test_sdhci() {
	build_flat_kernel_test "test_sdhci" "${TEST_DIR}/test_sdhci_self.asm" "../driver/intel_sdhci"
}

cmd_test_nvme() {
	build_flat_kernel_test "test_nvme" "${TEST_DIR}/test_nvme_self.asm" "../driver/nvme"
}

cmd_test_wasm_float() {
	build_test_ldscript "test_wasm_float"
}

cmd_test_sw_fb() {
	build_test_self "test_sw_fb_self" "ui/sw_fb"
}

cmd_test_av1_obu() {
	build_test "test_av1_obu_self" "${TEST_DIR}/test_av1_obu_self.asm" "media/av1_obu"
}

cmd_test_av1_mp4() {
	build_test "test_av1_mp4_self" "${TEST_DIR}/test_av1_mp4_self.asm" "media/mp4" "media/av1_obu"
}

cmd_test_vp8() {
	build_test "test_vp8_self" "${TEST_DIR}/test_vp8_self.asm" "media/vp8"
}

cmd_test_vp9() {
	build_test "test_vp9_self" "${TEST_DIR}/test_vp9_self.asm" "media/vp8" "media/vp9"
}

cmd_test_webp() {
	build_test "test_webp_self" "${TEST_DIR}/test_webp_self.asm" "media/webp" "media/vp8"
}

cmd_test_av1_ivf() {
	build_test "test_av1_ivf_self" "${TEST_DIR}/test_av1_ivf_self.asm" "media/av1_ivf"
}

cmd_test_av1_sequence() {
	build_test "test_av1_sequence_self" "${TEST_DIR}/test_av1_sequence_self.asm" "media/av1_bits" "media/av1_sequence"
}

cmd_test_av1_frame() {
	build_test "test_av1_frame_self" "${TEST_DIR}/test_av1_frame_self.asm" "media/av1_bits" "media/av1_sequence" "media/av1_frame"
}

cmd_test_av1_tile() {
	build_test "test_av1_tile_self" "${TEST_DIR}/test_av1_tile_self.asm" "media/av1_bits" "media/av1_tile"
}

cmd_test_av1_block() {
	build_test "test_av1_block_self" "${TEST_DIR}/test_av1_block_self.asm" "media/av1_bits" "media/av1_block"
}

cmd_test_av1_reduced() {
	build_test "test_av1_reduced_self" "${TEST_DIR}/test_av1_reduced_self.asm" "media/av1_bits" "media/av1_obu" "media/av1_ivf" "media/av1_sequence" "media/av1_frame" "media/av1_tile" "media/av1_reduced"
}

cmd_test_render_ir() {
	build_test_self "test_render_ir_self" "ui/render_ir" "ui/sw_fb" "agent/da" "crypto/blake3" "rt/runtime"
}

cmd_test_fe_mul() {
	local src="${TEST_DIR}/test_fe_mul.asm"
	local obj="${ASM_BUILD}/test_fe_mul.o"
 local stub_src="${TEST_DIR}/stubs_tor_ntor.asm"
 local stub_obj="${ASM_BUILD}/stubs_tor_ntor.o"
 local bin="${ASM_BUILD}/test_fe_mul"
 asm_x86_obj elf64 "$obj" "$src"
 asm_x86_obj elf64 "$stub_obj" "$stub_src"
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
	build_test_self "test_spi_flash_self"
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
	build_flat_kernel_test "test_cros_ec" "${TEST_DIR}/test_cros_ec_self.asm" "def:../driver/cros_ec:-dHOSTED_TEST"
}

cmd_test_amdgpu() {
	build_flat_kernel_test "test_amdgpu" "${TEST_DIR}/test_amdgpu_self.asm" "../driver/amdgpu"
}

cmd_test_tls() {
	build_test_self "test_tls_self" "crypto/tls" "crypto/tor_aes" "rt/runtime"
}

cmd_test_tpm() {
	local name="test_tpm_self"
	local obj="${ASM_BUILD}/${name}.o"
	local tpm_obj="${ASM_BUILD}/tpm_test.o"
	local bin="${ASM_BUILD}/${name%_self}"
	asm_x86_obj elf64 "$obj" "${TEST_DIR}/${name}.asm"
	elf64 "${ASM_DIR}/tpm/tpm.asm" "$tpm_obj"
	ld -nostdlib -static -o "$bin" "$obj" "$tpm_obj"
	echo "  LD  ${bin}"
	"$bin"
}

cmd_test_sha3() {
	build_test_self "test_sha3_self" "crypto/sha3"
}

cmd_test_sha512() {
	build_test_self "test_sha512_self" "crypto/sha512"
}

cmd_test_ed25519() {
	build_test_self "test_ed25519_self" "crypto/ed25519" "crypto/sha512" "crypto/curve25519" "rt/runtime"
}

cmd_test_tor() {
	build_test_self "test_tor_self" "crypto/tor_aes" "crypto/tor" "crypto/ed25519" "crypto/sha512" "crypto/curve25519" "crypto/local_cell" "crypto/local_route" "crypto/local_circuit" "rt/runtime"
}

cmd_test_tor_cell() {
	build_test_self "test_tor_cell_self" "crypto/tor_cell"
}

cmd_test_tor_hs() {
	build_test_self "test_tor_hs_self" "crypto/tor_hs" "crypto/sha3" "crypto/tor_aes" "crypto/curve25519" "rt/runtime"
}

cmd_test_tor_hs_app() {
	build_test_self "test_tor_hs_app_self" "crypto/tor_hs_app" "rt/runtime"
}

cmd_test_local_route() {
	build_test_self "test_local_route_self" "crypto/local_cell" "crypto/local_route" "crypto/local_circuit" "rt/runtime"
}

cmd_test_local_circuit() {
	build_test_self "test_local_circuit_self" "crypto/local_cell" "crypto/local_route" "crypto/local_circuit" "rt/runtime"
}

cmd_bench_tor() {
	local name="bench_tor"
	local src="${TEST_DIR}/test_tor_self.asm"
	local obj="${ASM_BUILD}/${name}.o"
	local bin="${ASM_BUILD}/${name}"
	asm_x86_obj elf64 "$obj" "$src" -dTOR_BENCH
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
	asm_x86_obj elf64 "$obj" "$src" -DHS_BENCH
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

build_x25519_test() {
	local name="$1"
	local stub_name="$2"
	local curve_obj_name="$3"
	local curve_builder="$4"
	local obj="${ASM_BUILD}/${name}.o"
 local stub_obj="${ASM_BUILD}/${stub_name}.o"
	local bin="${ASM_BUILD}/${name}"
	asm_x86_obj elf64 "$obj" "${TEST_DIR}/test_x25519.asm"
	asm_x86_obj elf64 "$stub_obj" "${TEST_DIR}/stubs_tor_ntor.asm"
	local tor_ntor_o="${ASM_BUILD}/tor_ntor.o"
	if [ ! -f "$tor_ntor_o" ]; then
		elf64 "${ASM_DIR}/crypto/tor_ntor.asm" "$tor_ntor_o"
	fi
	local runtime_o="${ASM_BUILD}/runtime.o"
	if [ ! -f "$runtime_o" ]; then
		elf64 "${ASM_DIR}/rt/runtime.asm" "$runtime_o"
	fi
	local curve25519_o="${ASM_BUILD}/${curve_obj_name}.o"
	"$curve_builder" "${ASM_DIR}/crypto/curve25519.asm" "$curve25519_o"
	ld -nostdlib -static -o "$bin" "$obj" "$curve25519_o" "$tor_ntor_o" "$runtime_o" "$stub_obj"
	echo "  LD  ${bin}"
	"$bin"
}

cmd_test_x25519() {
	build_x25519_test "test_x25519" "stubs_tor_ntor" "curve25519" "elf64"
}

cmd_test_x25519_debug() {
	build_x25519_test "test_x25519_debug" "stubs_tor_ntor_debug" "curve25519_debug" "elf64_dbg"
}

cmd_test_bench_render_ir() {
	build_test_self "bench_render_ir" "ui/sw_fb" "ui/render_ir"
}

cmd_bench_wasm_jit() {
	local name="bench_wasm_jit"
	local src="${TEST_DIR}/${name}.asm"
	local obj="${ASM_BUILD}/${name}.o"
	local bin="${ASM_BUILD}/${name}"
	asm_x86_obj elf64 "$obj" "$src"
	local runtime_o="${ASM_BUILD}/runtime.o"
	if [ ! -f "$runtime_o" ]; then
		elf64 "${ASM_DIR}/rt/runtime.asm" "$runtime_o"
	fi
	ld -T "${TEST_DIR}/test_jit.ld" -nostdlib -static -o "$bin" "$obj" "$runtime_o"
	echo "  LD  ${bin}"
	"$bin"
}

build_zig_wasm_bench_artifacts() {
	local zig_src="app/bench/zig_wasm_bench.zig"
	local native_obj="${ASM_BUILD}/zig_wasm_bench_native.o"
	local wasm_bin="${ASM_BUILD}/zig_wasm_bench.wasm"
	local asm_src="${TEST_DIR}/bench_zig_wasm.asm"
	local asm_obj="${ASM_BUILD}/bench_zig_wasm.o"
	local bin="${ASM_BUILD}/bench_zig_wasm"
	zig build-obj -O ReleaseFast -fstrip -target x86_64-linux -femit-bin="$native_obj" "$zig_src"
	zig build-exe -O ReleaseFast -fstrip -target wasm32-freestanding -fno-entry -rdynamic -femit-bin="$wasm_bin" "$zig_src"
	local wasm_abs="${PWD}/${wasm_bin}"
	asm_x86_obj elf64 "$asm_obj" "$asm_src" -DZIG_WASM_BENCH_PATH="\"${wasm_abs}\""
	local runtime_o="${ASM_BUILD}/runtime.o"
	if [ ! -f "$runtime_o" ]; then
		elf64 "${ASM_DIR}/rt/runtime.asm" "$runtime_o"
	fi
	ld -T "${TEST_DIR}/test_jit.ld" -nostdlib -static -o "$bin" "$asm_obj" "$native_obj" "$runtime_o"
	echo "  LD  ${bin}"
}

cmd_bench_zig_wasm() {
	build_zig_wasm_bench_artifacts
	local bin="${ASM_BUILD}/bench_zig_wasm"
	"$bin"
}

build_tor_host_objects() {
	mkdir -p "${ASM_BUILD}"
	local runtime_o="${ASM_BUILD}/lib_runtime.o"
	local sha256_o="${ASM_BUILD}/lib_sha256.o"
	local sha3_o="${ASM_BUILD}/lib_sha3.o"
	local tor_aes_o="${ASM_BUILD}/lib_tor_aes.o"
	local curve25519_o="${ASM_BUILD}/lib_curve25519.o"
	local tls_o="${ASM_BUILD}/lib_tls.o"
	local tor_hs_o="${ASM_BUILD}/lib_tor_hs.o"

	elf64 "${ASM_DIR}/rt/runtime.asm" "$runtime_o"
	elf64 "${ASM_DIR}/crypto/sha256.asm" "$sha256_o"
	elf64 "${ASM_DIR}/crypto/sha3.asm" "$sha3_o"
	elf64 "${ASM_DIR}/crypto/tor_aes.asm" "$tor_aes_o"
	elf64 "${ASM_DIR}/crypto/curve25519.asm" "$curve25519_o"
	elf64 "${ASM_DIR}/crypto/tls.asm" "$tls_o"
	elf64 "${ASM_DIR}/crypto/tor_hs.asm" "$tor_hs_o"
}

cmd_tor_hs_host() {
	build_tor_host_objects
	mkdir -p "${HOST_BUILD}"
	local obj="${HOST_BUILD}/tor_hs_host.o"
	local bin="${HOST_BUILD}/tor_hs_host"
	asm_x86_obj elf64 "$obj" "${TEST_DIR}/test_tor_hs_self.asm"
	ld -nostdlib -static -o "$bin" "$obj" \
		"${ASM_BUILD}/lib_tor_hs.o" "${ASM_BUILD}/lib_sha3.o" \
		"${ASM_BUILD}/lib_tor_aes.o" "${ASM_BUILD}/lib_curve25519.o" \
		"${ASM_BUILD}/lib_runtime.o"
	echo "  LD  ${bin}"
}

cmd_tor_live_host() {
	build_tor_host_objects
	mkdir -p "${HOST_BUILD}"
	local obj="${HOST_BUILD}/tor_live_host.o"
	local bin="${HOST_BUILD}/tor_live_host"
	asm_x86_obj elf64 "$obj" "${TEST_DIR}/test_tor_live_host.asm"
	ld -nostdlib -static -o "$bin" "$obj" \
		"${ASM_BUILD}/lib_tls.o" "${ASM_BUILD}/lib_sha256.o" \
		"${ASM_BUILD}/lib_tor_aes.o" "${ASM_BUILD}/lib_curve25519.o" \
		"${ASM_BUILD}/lib_runtime.o"
	echo "  LD  ${bin}"
}

cmd_test_tor_live_host() {
	cmd_tor_live_host
	"${HOST_BUILD}/tor_live_host"
}

# ---- ARM / Pi Zero targets ----
HOST_BUILD="${BUILD_DIR}/host"
PI_BUILD="${BUILD_DIR}/pi"
ESP32S3_BUILD="${BUILD_DIR}/esp32s3/jc3248w535"
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
	asm_x86_obj elf64 "$obj" "$src"
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
	asm_x86_obj elf64 "$obj" "$src"
	ld -o "${HOST_BUILD}/esp32_serial_boot" "$obj"
	echo "  LD  ${obj}"
}

cmd_er_efiboot() {
	mkdir -p "${HOST_BUILD}"
	local src="kernel/host/er_efiboot.asm"
	local obj="${HOST_BUILD}/er_efiboot.o"
	asm_x86_obj elf64 "$obj" "$src"
	ld -o "${HOST_BUILD}/er_efiboot" "$obj"
	echo "  LD  ${HOST_BUILD}/er_efiboot"
}

cmd_jc3248_firmware() {
	mkdir -p "${ESP32S3_BUILD}"
	local src="kernel/esp32s3/jc3248w535/firmware_image.asm"
	local bin="${ESP32S3_BUILD}/firmware.desc.bin"
	asm_x86_obj bin "$bin" "$src"
	local bsize=$(stat -c '%s' "$bin")
	printf 'jc3248-firmware-desc: %s (%d bytes)\n' "$bin" "$bsize"
	if [ "$bsize" -ne 256 ]; then
		echo "error: JC3248 firmware descriptor must be 256 bytes" >&2
		exit 1
	fi
}

cmd_clean() {
	rm -rf "${BUILD_DIR}"
}

cmd_deps_audit() {
	local failed=0
	local prunes=( -path './.git' -o -path './.build' -o -path './app/.zig-cache' -o -path './app/zig-out' )
	local manifests
	manifests=$(find . \( "${prunes[@]}" \) -prune -o -type f \( \
		-name '.gitmodules' -o \
		-name 'build.zig.zon' -o \
		-name 'package.json' -o -name 'package-lock.json' -o -name 'yarn.lock' -o -name 'pnpm-lock.yaml' -o \
		-name 'Cargo.toml' -o -name 'Cargo.lock' -o \
		-name 'go.mod' -o -name 'go.sum' -o \
		-name 'requirements*.txt' -o -name 'pyproject.toml' -o \
		-name 'CMakeLists.txt' -o \
		-name '*.csproj' -o -name 'pom.xml' -o -name 'build.gradle' -o -name 'gradle.lockfile' -o \
		-name 'composer.json' -o -name 'Gemfile' -o -name 'Gemfile.lock' \
		\) -print | sort)
	if [ -n "${manifests}" ]; then
		echo "error: undeclared external dependency manifests found:" >&2
		printf '%s\n' "${manifests}" >&2
		failed=1
	fi

	local nested_git
	nested_git=$(find . -path './.git' -prune -o -name '.git' -print | sort)
	if [ -n "${nested_git}" ]; then
		echo "error: nested git repositories found:" >&2
		printf '%s\n' "${nested_git}" >&2
		failed=1
	fi

	local binaries
	binaries=$(find . \( "${prunes[@]}" \) -prune -o -type f \( \
		-name '*.a' -o -name '*.bin' -o -name '*.clm_blob' -o -name '*.elf' -o \
		-name '*.fw' -o -name '*.hcd' -o -name '*.img' -o -name '*.o' -o \
		-name '*.so' -o -name '*.dylib' -o -name '*.dll' -o \
		-name '*.ucode' -o -name '*.wasm' -o -name '*.jar' -o -name '*.class' -o -name '*.pyc' \
		\) -print | sort | while IFS= read -r path; do
		case "$path" in
			./app/src/gen/icon_asset_pack_index.bin|\
			./app/src/gen/icon_asset_pack_ir.bin|\
			./app/src/gen/icon_names.bin|\
			./kernel/driver/font_atlas.bin|\
			./kernel/driver/font_glyph_table.bin|\
			./kernel/x86_64/wasm/agent_minimal.wasm|\
			./kernel/x86_64/wasm/da_test.wasm|\
			./kernel/x86_64/wasm/test_imports.wasm|\
			./kernel/x86_64/wasm/test_mem.wasm|\
			./kernel/x86_64/wasm/test_mem_noret.wasm|\
			./kernel/x86_64/wasm/test_mem_simple.wasm|\
			./kernel/x86_64/wasm/test_table.wasm|\
			./kernel/x86_64/wasm/test_tblonly.wasm|\
			./kernel/x86_64/wasm/wasm_return42.bin)
				;;
			*)
				printf '%s\n' "$path"
				;;
		esac
	done)
	if [ -n "${binaries}" ]; then
		echo "error: undeclared binary artifacts found:" >&2
		printf '%s\n' "${binaries}" >&2
		failed=1
	fi

	if [ "$failed" -ne 0 ]; then
		return 1
	fi
	echo "PASS deps-audit"
}

cmd_help() {
	cat <<'EOF'
EdgeRun build targets:
  kernel              Build flat x86_64 kernel.bin
  kernel-hello        Build kernel.img and boot it in QEMU (serial)
  kernel-vnc          Build kernel.img and boot it in QEMU (VNC :0)
  kernel-net          Build kernel.img and boot it in QEMU with virtio-net
  kernel-net-tpm      Build kernel.img and boot it in QEMU with swtpm + virtio-net
  kernel-net-tor      Build kernel.img with Tor autostart + boot QEMU net/TPM
  kernel-tpm-live-test    Build kernel with TPM live test main
  kernel-tpm-live-test-qemu Build + run in QEMU with swtpm
  kernel-efi          Build kernel.efi
  install-efi         Build + install kernel.efi to ESP + add boot entry
  test                Run all self-hosted ASM tests
  test-core           Run default unit + contract tests, excluding emulator tests
  test-unit           Run default unit tests
  test-contract       Run default architecture contract tests
  test-emulator       Run default emulator-backed tests
  test-subsystem NAME Run default tests for one subsystem (wasm, route, ui, media, crypto, driver, rt, net, pi)
  test-list           List tests as TSV: target, category, subsystem, default, description
  test-status [TARGET...] Run tests and emit TSV: target, category, subsystem, status, log
  test-status --category NAME Run default tests in one category
  test-status --subsystem NAME Run default tests in one subsystem
  test-status --core    Run default unit + contract tests as TSV status
  deps-audit         Check for undeclared external dependency manifests and blobs
  app                Run owned app build path without app/build.zig
  app-ui-wasm        Build UI WASM directly without app/build.zig
  immutable-kernel-gop-smoke-efi Build UEFI native renderer GOP smoke without app/build.zig
  sdk-cli            Build and run SDK simulation without app/build.zig
  sdk-bench          Build and run SDK benchmark without app/build.zig
  project-intro-video Build and run project intro renderer without app/build.zig
  chat-preview       Build and run chat preview renderer without app/build.zig
  jc3248-frame       Build and run JC3248 frame renderer without app/build.zig
  build-dashboard    Build dashboard renderer without app/build.zig
  media-video-dump   Build media video dump tool without app/build.zig
  ifstatus           Build interface status publisher without app/build.zig
  pi-usb-load        Build Pi USB boot host without app/build.zig
  pi-usb-control     Build Pi USB control host without app/build.zig
  wayland-window     Build Wayland native window host without app/build.zig
  drm-gbm-window     Build DRM/GBM native window host without app/build.zig
  tpm-real-check     Build real TPM checker without app/build.zig
  real-tpm           Build and run real TPM checker against /dev/tpmrm0
  x86-asm-inventory  Emit the x86 ASM syntax inventory used to scope assembler replacement
EOF
 cmd_test_help
 cat <<'EOF'
  bench-tor           Run Tor local AES cell latency/throughput benchmark
  bench-tor-hs        Run hidden-service local self-connect benchmark
  bench-wasm-jit      Run WASM JIT vs native RDTSC benchmark (self-hosted ASM)
  bench-zig-wasm      Compile same Zig code to x86_64 + WASM, then benchmark native/interpreter/JIT
  er-asm              Build owned x86 ASM assembler front-end
  er-asm-obj SRC [O] Assemble one x86 source flat binary with owned er_asm; no yasm fallback
  er-asm-all          Try every x86 .asm source as a flat binary with owned er_asm; no yasm fallback
  tor-hs-host         Build hosted hidden-service library smoke binary
  tor-live-host       Build hosted live Tor ORPort probe binary
  pi-kernel           Build Pi Zero W kernel.img (ARMv6)
  pi-usb-boot         Build Pi USB boot host tool (x86_64)
  pi-boot             Build + boot Pi Zero via USB
  esp32-serial-boot   Build ESP32 serial boot host tool (x86_64)
  er-efiboot          Build repo-owned EFI variable manager
  jc3248-firmware     Build JC3248W535 ESP32-S3 firmware descriptor
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
	test-core)      cmd_test_core ;;
	test-unit)      cmd_test_category unit ;;
	test-contract)  cmd_test_category contract ;;
	test-emulator)  cmd_test_category emulator ;;
	test-subsystem)
		if [ -z "${2:-}" ]; then
			echo "usage: ./build.sh test-subsystem <name>" >&2
			exit 1
		fi
		cmd_test_subsystem "$2"
		;;
	test-list)      cmd_test_list ;;
	test-status)    shift; cmd_test_status "$@" ;;
	deps-audit)     cmd_deps_audit ;;
	app)            cmd_app ;;
	app-ui-wasm)    cmd_app_ui_wasm ;;
	immutable-kernel-gop-smoke-efi) cmd_immutable_kernel_gop_smoke_efi ;;
	sdk-cli)        shift; cmd_sdk_cli "$@" ;;
	sdk-bench)      cmd_sdk_bench ;;
	project-intro-video) cmd_project_intro_video ;;
	chat-preview)   cmd_chat_preview ;;
	jc3248-frame)   cmd_jc3248_frame ;;
	build-dashboard) cmd_build_dashboard ;;
	media-video-dump) cmd_media_video_dump ;;
	ifstatus)       cmd_ifstatus ;;
	pi-usb-load)    cmd_pi_usb_load ;;
	pi-usb-control) cmd_pi_usb_control ;;
	wayland-window) cmd_wayland_window ;;
	drm-gbm-window) cmd_drm_gbm_window ;;
	tpm-real-check) cmd_tpm_real_check_build ;;
	real-tpm)       cmd_real_tpm ;;
	x86-asm-inventory) cmd_x86_asm_inventory ;;
	test-*)         cmd_test_registered "$1" ;;
	bench-tor)      cmd_bench_tor ;;
	bench-tor-hs)   cmd_bench_tor_hs ;;
	bench-wasm-jit) cmd_bench_wasm_jit ;;
	bench-zig-wasm) cmd_bench_zig_wasm ;;
	er-asm)          cmd_er_asm ;;
	er-asm-obj)      shift; cmd_er_asm_obj "$@" ;;
	er-asm-all)      cmd_er_asm_all ;;
	tor-hs-host)     cmd_tor_hs_host ;;
	tor-live-host)   cmd_tor_live_host ;;
	test-tor-live-host) cmd_test_tor_live_host ;;
	pi-kernel)      cmd_pi_kernel ;;
	pi-usb-boot)    cmd_pi_usb_boot ;;
	pi-boot)        cmd_pi_boot ;;
	esp32-serial-boot) cmd_esp32_serial_boot ;;
	er-efiboot)     cmd_er_efiboot ;;
	jc3248-firmware) cmd_jc3248_firmware ;;
	clean)          cmd_clean ;;
	help|--help|-h) cmd_help ;;
	*)
		echo "unknown target: $1" >&2
		echo "usage: ./build.sh <target>" >&2
		cmd_help >&2
		exit 1
		;;
esac
