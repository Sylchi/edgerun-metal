.PHONY: help all check clean \
	crypto-test crypto-bench \
	asm-test asm-test-math asm-test-runtime asm-test-serial asm-test-tpm \
	asm-kernel asm-kernel-hello \
	asm-test-wasm

SHELL := bash
BUILD_DIR := .build

CMAKE ?= cmake
CTEST ?= ctest

YASM ?= yasm
ASM_BUILD_DIR := $(BUILD_DIR)/asm
ASM_X86_64_DIR := asm/x86_64
ASM_TEST_DIR := asm/test
ASM_INC := -I asm


help:
	@printf '%s\n' \
		'Common targets:' \
		'  make check              asm-test + crypto-test' \
		'  make crypto-test        run C BLAKE3 tests' \
		'  make asm-test           run all x86_64 assembly tests' \
		'  make asm-test-math      run assembly math function tests' \
		'  make asm-test-runtime   run assembly runtime/memory tests' \
		'  make asm-test-serial    run assembly serial output tests' \
		'  make asm-kernel         build a bare-metal x86_64 kernel image' \
		'  make clean              remove .build'

all: check

check: asm-test crypto-test

crypto-test:
	$(CMAKE) -S edgerun-crypto -B $(BUILD_DIR)/edgerun-crypto
	$(CMAKE) --build $(BUILD_DIR)/edgerun-crypto --target test_blake3
	$(CTEST) --test-dir $(BUILD_DIR)/edgerun-crypto --output-on-failure

crypto-bench:
	$(CMAKE) -S edgerun-crypto -B $(BUILD_DIR)/edgerun-crypto
	$(CMAKE) --build $(BUILD_DIR)/edgerun-crypto --target bench

ASM_OBJS := \
	$(ASM_BUILD_DIR)/ctype.o \
	$(ASM_BUILD_DIR)/math.o \
	$(ASM_BUILD_DIR)/runtime.o \
	$(ASM_BUILD_DIR)/serial.o \
	$(ASM_BUILD_DIR)/wasm_interpreter.o

ASM_KERNEL_FORMAT := elf32
ASM_KERNEL_OBJS := \
	$(ASM_BUILD_DIR)/kernel_ctype.o \
	$(ASM_BUILD_DIR)/kernel_math.o \
	$(ASM_BUILD_DIR)/kernel_runtime.o \
	$(ASM_BUILD_DIR)/kernel_serial.o \
	$(ASM_BUILD_DIR)/kernel_entry.o \
	$(ASM_BUILD_DIR)/kernel_main_elf32.o

ASM_KERNEL_LD := $(ASM_X86_64_DIR)/linker.ld
ASM_KERNEL_ELF := $(ASM_BUILD_DIR)/kernel.elf
ASM_KERNEL_BIN := $(ASM_BUILD_DIR)/kernel.bin

ASM_TEST_OBJS := \
	$(ASM_BUILD_DIR)/serial_test.o \
	$(ASM_BUILD_DIR)/tpm_test.o \
	$(ASM_BUILD_DIR)/tpm_crb_test.o \
	$(ASM_BUILD_DIR)/test_entry.o

asm-build: $(ASM_OBJS)

# ─── Static pattern rules ─────────────────────────────────────────────

# Standard elf64 objects from asm/x86_64/
STD_ASM_OBJS := $(ASM_BUILD_DIR)/ctype.o $(ASM_BUILD_DIR)/math.o \
	$(ASM_BUILD_DIR)/runtime.o $(ASM_BUILD_DIR)/serial.o \
	$(ASM_BUILD_DIR)/wasm_interpreter.o

$(STD_ASM_OBJS): $(ASM_BUILD_DIR)/%.o: $(ASM_X86_64_DIR)/%.asm $(ASM_X86_64_DIR)/macros.inc
	@mkdir -p $(ASM_BUILD_DIR)
	$(YASM) -f elf64 $(ASM_INC) $< -o $@ 2>/dev/null && test -f $@

$(ASM_BUILD_DIR)/math.o: $(ASM_X86_64_DIR)/simd.inc

# HOSTED_TEST objects from asm/x86_64/ (source named X → X_test.o)
HOSTED_ASM_OBJS := $(ASM_BUILD_DIR)/serial_test.o $(ASM_BUILD_DIR)/tpm_test.o \
	$(ASM_BUILD_DIR)/tpm_crb_test.o

$(HOSTED_ASM_OBJS): $(ASM_BUILD_DIR)/%_test.o: $(ASM_X86_64_DIR)/%.asm $(ASM_X86_64_DIR)/macros.inc
	@mkdir -p $(ASM_BUILD_DIR)
	$(YASM) -f elf64 $(ASM_INC) -DHOSTED_TEST $< -o $@ 2>/dev/null && test -f $@

# test_entry.o from a different source directory
$(ASM_BUILD_DIR)/test_entry.o: $(ASM_TEST_DIR)/test_entry.asm
	@mkdir -p $(ASM_BUILD_DIR)
	$(YASM) -f elf64 $(ASM_INC) $< -o $@

# Kernel objects (elf32) from asm/x86_64/
KERNEL_ASM_OBJS := $(ASM_BUILD_DIR)/kernel_ctype.o $(ASM_BUILD_DIR)/kernel_entry.o \
	$(ASM_BUILD_DIR)/kernel_math.o $(ASM_BUILD_DIR)/kernel_runtime.o \
	$(ASM_BUILD_DIR)/kernel_serial.o

$(KERNEL_ASM_OBJS): $(ASM_BUILD_DIR)/kernel_%.o: $(ASM_X86_64_DIR)/%.asm $(ASM_X86_64_DIR)/macros.inc
	@mkdir -p $(ASM_BUILD_DIR)
	$(YASM) -f $(ASM_KERNEL_FORMAT) $(ASM_INC) $< -o $@ 2>/dev/null && test -f $@

$(ASM_BUILD_DIR)/kernel_math.o: $(ASM_X86_64_DIR)/simd.inc

# kernel_main_elf32.o — source name differs from target, so explicit rule
$(ASM_BUILD_DIR)/kernel_main_elf32.o: $(ASM_X86_64_DIR)/kernel_main.asm $(ASM_X86_64_DIR)/macros.inc
	@mkdir -p $(ASM_BUILD_DIR)
	$(YASM) -f $(ASM_KERNEL_FORMAT) $(ASM_INC) $< -o $@ 2>/dev/null && test -f $@

asm-test-math: $(ASM_BUILD_DIR)/math.o $(ASM_BUILD_DIR)/runtime.o $(ASM_BUILD_DIR)/test_entry.o
	$(CC) -ffreestanding -nostdlib -static -fno-stack-protector -g -o $(ASM_BUILD_DIR)/test_math $(ASM_TEST_DIR)/test_math.c $(ASM_BUILD_DIR)/test_entry.o $(ASM_BUILD_DIR)/runtime.o $(ASM_BUILD_DIR)/math.o
	$(ASM_BUILD_DIR)/test_math

asm-test-runtime: $(ASM_BUILD_DIR)/runtime.o $(ASM_BUILD_DIR)/test_entry.o
	$(CC) -ffreestanding -nostdlib -static -fno-stack-protector -g -o $(ASM_BUILD_DIR)/test_runtime $(ASM_TEST_DIR)/test_runtime.c $(ASM_BUILD_DIR)/test_entry.o $(ASM_BUILD_DIR)/runtime.o
	$(ASM_BUILD_DIR)/test_runtime

asm-test-ctype: $(ASM_BUILD_DIR)/ctype.o $(ASM_BUILD_DIR)/test_entry.o
	$(CC) -ffreestanding -nostdlib -static -fno-stack-protector -g -o $(ASM_BUILD_DIR)/test_ctype $(ASM_TEST_DIR)/test_ctype.c $(ASM_BUILD_DIR)/test_entry.o $(ASM_BUILD_DIR)/ctype.o
	$(ASM_BUILD_DIR)/test_ctype

asm-test-serial: $(ASM_BUILD_DIR)/serial_test.o $(ASM_BUILD_DIR)/runtime.o $(ASM_BUILD_DIR)/test_entry.o
	$(CC) -ffreestanding -nostdlib -static -fno-stack-protector -g -o $(ASM_BUILD_DIR)/test_serial $(ASM_TEST_DIR)/test_serial.c $(ASM_BUILD_DIR)/test_entry.o $(ASM_BUILD_DIR)/serial_test.o $(ASM_BUILD_DIR)/runtime.o
	$(ASM_BUILD_DIR)/test_serial

asm-kernel: $(ASM_KERNEL_OBJS)
	ld -m elf_i386 -T $(ASM_KERNEL_LD) -o $(ASM_KERNEL_ELF) $(ASM_KERNEL_OBJS)
	objcopy -O binary $(ASM_KERNEL_ELF) $(ASM_KERNEL_BIN)
	@printf 'kernel: %s (%d bytes)\n' '$(ASM_KERNEL_ELF)' "$$(stat -c '%s' '$(ASM_KERNEL_ELF)')"
	@printf 'flat:   %s (%d bytes)\n' '$(ASM_KERNEL_BIN)' "$$(stat -c '%s' '$(ASM_KERNEL_BIN)')"

asm-kernel-hello: asm-kernel
	qemu-system-x86_64 \
		-machine q35 \
		-display none \
		-serial stdio \
		-no-reboot \
		-kernel $(ASM_KERNEL_ELF) \
		-m 256

asm-test-tpm: $(ASM_BUILD_DIR)/tpm_test.o $(ASM_BUILD_DIR)/tpm_crb_test.o $(ASM_BUILD_DIR)/runtime.o $(ASM_BUILD_DIR)/test_entry.o
	$(CC) -ffreestanding -nostdlib -static -fno-stack-protector -g -o $(ASM_BUILD_DIR)/test_tpm $(ASM_TEST_DIR)/test_tpm.c $(ASM_BUILD_DIR)/test_entry.o $(ASM_BUILD_DIR)/runtime.o $(ASM_BUILD_DIR)/tpm_test.o $(ASM_BUILD_DIR)/tpm_crb_test.o
	$(ASM_BUILD_DIR)/test_tpm

asm-test-wasm: $(ASM_BUILD_DIR)/wasm_interpreter.o $(ASM_BUILD_DIR)/runtime.o $(ASM_BUILD_DIR)/test_entry.o
	$(CC) -ffreestanding -nostdlib -static -fno-stack-protector -g -o $(ASM_BUILD_DIR)/test_wasm $(ASM_TEST_DIR)/test_wasm.c $(ASM_BUILD_DIR)/test_entry.o $(ASM_BUILD_DIR)/runtime.o $(ASM_BUILD_DIR)/wasm_interpreter.o
	$(ASM_BUILD_DIR)/test_wasm

asm-test: asm-test-ctype asm-test-math asm-test-runtime asm-test-serial asm-test-tpm asm-test-wasm

clean:
	rm -rf $(BUILD_DIR)
