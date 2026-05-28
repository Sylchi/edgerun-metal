.PHONY: help all check clean \
	fmt fmt-check test zig-test \
	crypto-test crypto-bench \
	asm-test asm-test-math asm-test-runtime asm-test-serial asm-test-tpm \
	asm-kernel asm-kernel-hello \
	app-runtime pages-site pages-check pages-public-check pages-release \
	wayland-window wayland-window-test \
	ifstatus real-tpm sdk-cli sdk-bench

SHELL := bash
BUILD_DIR := .build
OPT ?= ReleaseFast
ZIG_BUILD := zig build --build-file edgerun-zig/build.zig --cache-dir $(BUILD_DIR)/edgerun-zig -Doptimize=$(OPT)

CMAKE ?= cmake
CTEST ?= ctest

YASM ?= yasm
ASM_BUILD_DIR := $(BUILD_DIR)/asm
ASM_X86_64_DIR := asm/x86_64
ASM_TEST_DIR := asm/test
ASM_INC := -I asm

WAYLAND_WIDTH ?= 1280
WAYLAND_HEIGHT ?= 900
WAYLAND_SECONDS ?= 3600
WAYLAND_PATH ?= /docs

PAGES_SITE_DIR := $(BUILD_DIR)/github-pages
PAGES_BRANCH ?= gh-pages
PAGES_REMOTE ?= origin
PAGES_WORKTREE_DIR := $(BUILD_DIR)/pages-worktree
PAGES_ZIG_OUT := edgerun-zig/zig-out
PAGES_PUBLIC_URL ?= https://sylchi.github.io/edgerun-c/
APP_RUNTIME_WASM := $(PAGES_ZIG_OUT)/bin/edgerun-app-runtime.wasm
FONT_ATLAS_WIDTH := 4096
FONT_ATLAS_HEIGHT := 4096
FONT_ATLAS_CHANNELS := 1
FONT_ATLAS_BYTES := $(shell expr $(FONT_ATLAS_WIDTH) \* $(FONT_ATLAS_HEIGHT) \* $(FONT_ATLAS_CHANNELS))

help:
	@printf '%s\n' \
		'Common targets:' \
		'  make check              fmt-check + tests' \
		'  make fmt                format Zig code' \
		'  make test               run Zig tests' \
		'  make crypto-test        run C BLAKE3 tests' \
		'  make asm-test           run all x86_64 assembly tests' \
		'  make asm-test-math      run assembly math function tests' \
		'  make asm-test-runtime   run assembly runtime/memory tests' \
		'  make asm-test-serial    run assembly serial output tests' \
		'  make asm-kernel         build a bare-metal x86_64 kernel image' \
		'  make app-runtime        build wasm runtime and print artifact sizes' \
		'  make wayland-window     build wasm runtime and open native Wayland host' \
		'  make pages-site         build local GitHub Pages artifact' \
		'  make pages-check        validate local pages artifact' \
		'  make pages-release      publish pages artifact to gh-pages' \
		'  make clean              remove .build'

all: check

check: fmt-check test

fmt:
	zig fmt edgerun-zig

fmt-check:
	zig fmt --check edgerun-zig

test zig-test:
	$(ZIG_BUILD) test

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
	$(ASM_BUILD_DIR)/serial.o

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

$(ASM_BUILD_DIR)/math.o: $(ASM_X86_64_DIR)/math.asm $(ASM_X86_64_DIR)/macros.inc $(ASM_X86_64_DIR)/simd.inc
	@mkdir -p $(ASM_BUILD_DIR)
	$(YASM) -f elf64 $(ASM_INC) $< -o $@ 2>/dev/null && test -f $@

$(ASM_BUILD_DIR)/runtime.o: $(ASM_X86_64_DIR)/runtime.asm $(ASM_X86_64_DIR)/macros.inc
	@mkdir -p $(ASM_BUILD_DIR)
	$(YASM) -f elf64 $(ASM_INC) $< -o $@ 2>/dev/null && test -f $@

$(ASM_BUILD_DIR)/serial.o: $(ASM_X86_64_DIR)/serial.asm $(ASM_X86_64_DIR)/macros.inc
	@mkdir -p $(ASM_BUILD_DIR)
	$(YASM) -f elf64 $(ASM_INC) $< -o $@ 2>/dev/null && test -f $@

$(ASM_BUILD_DIR)/ctype.o: $(ASM_X86_64_DIR)/ctype.asm $(ASM_X86_64_DIR)/macros.inc
	@mkdir -p $(ASM_BUILD_DIR)
	$(YASM) -f elf64 $(ASM_INC) $< -o $@ 2>/dev/null && test -f $@

$(ASM_BUILD_DIR)/serial_test.o: $(ASM_X86_64_DIR)/serial.asm $(ASM_X86_64_DIR)/macros.inc
	@mkdir -p $(ASM_BUILD_DIR)
	$(YASM) -f elf64 $(ASM_INC) -DHOSTED_TEST $< -o $@ 2>/dev/null && test -f $@

$(ASM_BUILD_DIR)/test_entry.o: $(ASM_TEST_DIR)/test_entry.asm
	@mkdir -p $(ASM_BUILD_DIR)
	$(YASM) -f elf64 $(ASM_INC) $< -o $@

$(ASM_BUILD_DIR)/tpm_test.o: $(ASM_X86_64_DIR)/tpm.asm $(ASM_X86_64_DIR)/macros.inc
	@mkdir -p $(ASM_BUILD_DIR)
	$(YASM) -f elf64 $(ASM_INC) -DHOSTED_TEST $< -o $@

$(ASM_BUILD_DIR)/tpm_crb_test.o: $(ASM_X86_64_DIR)/tpm_crb.asm $(ASM_X86_64_DIR)/macros.inc
	@mkdir -p $(ASM_BUILD_DIR)
	$(YASM) -f elf64 $(ASM_INC) -DHOSTED_TEST $< -o $@

$(ASM_BUILD_DIR)/kernel_main.o: $(ASM_X86_64_DIR)/kernel_main.asm $(ASM_X86_64_DIR)/macros.inc
	@mkdir -p $(ASM_BUILD_DIR)
	$(YASM) -f elf64 $(ASM_INC) $< -o $@ 2>/dev/null && test -f $@

# Kernel build: all objects in ELF32 format for QEMU multiboot compatibility.
# The 64-bit code is embedded within the ELF32 container; the 32→64
# transition in entry.asm switches to long mode after multiboot loads us.

$(ASM_BUILD_DIR)/kernel_ctype.o: $(ASM_X86_64_DIR)/ctype.asm $(ASM_X86_64_DIR)/macros.inc
	@mkdir -p $(ASM_BUILD_DIR)
	$(YASM) -f $(ASM_KERNEL_FORMAT) $(ASM_INC) $< -o $@ 2>/dev/null && test -f $@

$(ASM_BUILD_DIR)/kernel_entry.o: $(ASM_X86_64_DIR)/entry.asm $(ASM_X86_64_DIR)/macros.inc
	@mkdir -p $(ASM_BUILD_DIR)
	$(YASM) -f $(ASM_KERNEL_FORMAT) $(ASM_INC) $< -o $@ 2>/dev/null && test -f $@

$(ASM_BUILD_DIR)/kernel_math.o: $(ASM_X86_64_DIR)/math.asm $(ASM_X86_64_DIR)/macros.inc $(ASM_X86_64_DIR)/simd.inc
	@mkdir -p $(ASM_BUILD_DIR)
	$(YASM) -f $(ASM_KERNEL_FORMAT) $(ASM_INC) $< -o $@ 2>/dev/null && test -f $@

$(ASM_BUILD_DIR)/kernel_runtime.o: $(ASM_X86_64_DIR)/runtime.asm $(ASM_X86_64_DIR)/macros.inc
	@mkdir -p $(ASM_BUILD_DIR)
	$(YASM) -f $(ASM_KERNEL_FORMAT) $(ASM_INC) $< -o $@ 2>/dev/null && test -f $@

$(ASM_BUILD_DIR)/kernel_serial.o: $(ASM_X86_64_DIR)/serial.asm $(ASM_X86_64_DIR)/macros.inc
	@mkdir -p $(ASM_BUILD_DIR)
	$(YASM) -f $(ASM_KERNEL_FORMAT) $(ASM_INC) $< -o $@ 2>/dev/null && test -f $@

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

ASM_KERNEL_LD := $(ASM_X86_64_DIR)/linker.ld
ASM_KERNEL_ELF := $(ASM_BUILD_DIR)/kernel.elf
ASM_KERNEL_BIN := $(ASM_BUILD_DIR)/kernel.bin

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

asm-test: asm-test-ctype asm-test-math asm-test-runtime asm-test-serial asm-test-tpm

sdk-cli:
	$(ZIG_BUILD) sdk-cli -- simulate standard

sdk-bench:
	$(ZIG_BUILD) sdk-bench

real-tpm:
	$(ZIG_BUILD) real-tpm

ifstatus:
	$(ZIG_BUILD) ifstatus

app-runtime:
	$(ZIG_BUILD) -Doptimize=$(OPT) app-runtime
	@printf 'font atlas: %sx%s alpha%s = %s bytes\n' '$(FONT_ATLAS_WIDTH)' '$(FONT_ATLAS_HEIGHT)' '$(FONT_ATLAS_CHANNELS)' '$(FONT_ATLAS_BYTES)'
	@stat -c 'wasm runtime: %s bytes (%n)' '$(APP_RUNTIME_WASM)' 2>/dev/null || true

wayland-window: app-runtime
	$(ZIG_BUILD) -Doptimize=$(OPT) wayland-window -- --width $(WAYLAND_WIDTH) --height $(WAYLAND_HEIGHT) --seconds $(WAYLAND_SECONDS) --path $(WAYLAND_PATH)

wayland-window-test:
	$(ZIG_BUILD) wayland-window-test

pages-site: app-runtime
	rm -rf $(PAGES_SITE_DIR)
	mkdir -p $(PAGES_SITE_DIR)/web $(PAGES_SITE_DIR)/bin
	cp pages/index.html $(PAGES_SITE_DIR)/index.html
	cp pages/404.html $(PAGES_SITE_DIR)/404.html
	cp $(PAGES_ZIG_OUT)/web/index.html $(PAGES_SITE_DIR)/web/index.html
	chmod u+w $(PAGES_SITE_DIR)/web/index.html
	python3 -c "from pathlib import Path; p=Path('$(PAGES_SITE_DIR)/web/index.html'); s=p.read_text(); old='A=(e,k)=>{let p=W.er_ui_input_ptr()'; new='A=(e,k)=>{if(!W)return;let p=W.er_ui_input_ptr()'; p.write_text(s if new in s else s.replace(old,new,1)); raise SystemExit(0 if new in p.read_text() else 1)"
	grep -q 'A=(e,k)=>{if(!W)return;' $(PAGES_SITE_DIR)/web/index.html
	cp $(APP_RUNTIME_WASM) $(PAGES_SITE_DIR)/bin/edgerun-app-runtime.wasm
	: > $(PAGES_SITE_DIR)/.nojekyll
	test -f $(PAGES_SITE_DIR)/web/index.html
	test -f $(PAGES_SITE_DIR)/bin/edgerun-app-runtime.wasm
	test -f $(PAGES_SITE_DIR)/index.html
	test -f $(PAGES_SITE_DIR)/404.html

pages-check: pages-site
	python3 tools/pages_check.py --site-dir $(PAGES_SITE_DIR)

pages-public-check:
	python3 tools/pages_check.py --public-url $(PAGES_PUBLIC_URL)

pages-release: pages-site
	@set -euo pipefail; \
		rm -rf "$(PAGES_WORKTREE_DIR)"; \
		if git ls-remote --exit-code --heads "$(PAGES_REMOTE)" "$(PAGES_BRANCH)" >/dev/null 2>&1; then \
			git fetch "$(PAGES_REMOTE)" "$(PAGES_BRANCH)" --prune; \
			git worktree add --detach "$(PAGES_WORKTREE_DIR)" "$(PAGES_REMOTE)/$(PAGES_BRANCH)"; \
		else \
			git worktree add --detach "$(PAGES_WORKTREE_DIR)" $$(git rev-parse HEAD); \
			git -C "$(PAGES_WORKTREE_DIR)" switch --orphan "$(PAGES_BRANCH)"; \
		fi; \
		rsync -a --delete --exclude='.git' "$(PAGES_SITE_DIR)/" "$(PAGES_WORKTREE_DIR)/"; \
		git -C "$(PAGES_WORKTREE_DIR)" add --all; \
		if ! git -C "$(PAGES_WORKTREE_DIR)" diff --cached --quiet; then \
			git -C "$(PAGES_WORKTREE_DIR)" commit -m "Deploy GitHub Pages for $$(git rev-parse --short HEAD)"; \
		fi; \
		git -C "$(PAGES_WORKTREE_DIR)" push "$(PAGES_REMOTE)" "HEAD:$(PAGES_BRANCH)"; \
		git worktree remove "$(PAGES_WORKTREE_DIR)"

clean:
	rm -rf $(BUILD_DIR)
