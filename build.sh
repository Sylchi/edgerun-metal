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
KERNEL_ELF="${ASM_BUILD}/kernel.elf"
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
	preimage.asm
	display.asm
	acpi.asm
	xhci.asm
	rtl8125.asm
	bt.asm
	virtio.asm
	virtio_gpu.asm
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
	wasm_compiler.o
	wasm_compiler_source.o
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
	"$bin"
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
	cmd_test_clock
	cmd_test_identity
	cmd_test_render_ir
	cmd_test_sw_fb
	cmd_test_wasm_compiler
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
cmd_test_wasm()     { test_via_cc "wasm"     "wasm_interpreter.o"; }
cmd_test_wasm_compiler() { test_via_cc "wasm_compiler" "wasm_compiler.o" "wasm_compiler_source.o"; }
cmd_test_blake3()   { test_via_cc "blake3"   "blake3.o"; }
cmd_test_acpi()     { test_via_cc "acpi"     "acpi.o"; }
cmd_test_preimage() { test_via_cc "preimage" "blake3.o" "preimage.o" "clock.o" "bytes.o"; }
cmd_test_bytes()    { test_via_cc "bytes"    "bytes.o"; }
cmd_test_clock()    { test_via_cc "clock"    "clock.o" "bytes.o"; }
cmd_test_identity() { test_via_cc "identity" "identity.o" "blake3.o" "clock.o" "bytes.o"; }
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
	ld -nostdlib -static -o "$bin" "$obj" "$render_ir_o"
	echo "  LD  ${bin}"
	"$bin"
}

cmd_clean() {
	rm -rf "${BUILD_DIR}"
}

cmd_help() {
	cat <<'EOF'
EdgeRun build targets:
  kernel         Build kernel.elf + kernel.bin
  kernel-hello   Build kernel + run in QEMU
  kernel-bt-test Build kernel + run in QEMU with mock BT on COM2
  test           Run all assembly tests
  test-ctype     Run ctype test (self-hosted ASM runner)
  test-clock     Run clock test (self-hosted ASM runner)
  test-math      Run math test
  test-runtime   Run runtime test
  test-serial    Run serial test
  test-tpm       Run TPM test
  test-wasm      Run WASM interpreter test
  test-blake3    Run BLAKE3 test
  test-acpi      Run ACPI test
  test-preimage  Run preimage test
  test-bytes     Run bytes test
  test-clock     Run clock test
  test-identity  Run identity test
  test-render-ir Run render IR test
  test-sw-fb     Run software framebuffer test
  test-wasm-compiler Run WASM compiler test
  clean          Remove .build/
EOF
}

# ---- dispatch ----
case "${1:-help}" in
	kernel)         cmd_kernel ;;
	kernel-hello)   cmd_kernel_hello ;;
	kernel-bt-test) cmd_kernel_bt_test ;;
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
	test-clock)     cmd_test_clock ;;
	test-identity)  cmd_test_identity ;;
	test-render-ir) cmd_test_render_ir ;;
	test-sw-fb)     cmd_test_sw_fb ;;
	test-wasm-compiler) cmd_test_wasm_compiler ;;
	clean)          cmd_clean ;;
	help|--help|-h) cmd_help ;;
	*)
		echo "unknown target: $1" >&2
		echo "usage: ./build.sh <target>" >&2
		cmd_help >&2
		exit 1
		;;
esac
