.PHONY: all check clean er-build repo-check repo-test repo-check-bin repo-push-check repo-inspect repo-progress repo-agent-swarm erwire-decode erwire-test pi-serial-verify sdcard-probe pi-usb-boot pi-zero-w-v1_1-usb-boot codex-build codex-test crypto-test metal-ui-bench tpm-real-bench-uefi qemu-host-tpm-bench os-user-app-smoke edgerun-metal edgerun-os edgerun-check varfont-test ui-core-test

CC := toolchain/bin/clang
HOST_CC := toolchain/bin/clang
HOST_LDFLAGS :=
HOST_CC_FOR_SUBMAKE := $(if $(findstring /,$(HOST_CC)),$(abspath $(HOST_CC)),$(HOST_CC))
ER_BUILD_BOOTSTRAP := toolchain/bin/er-build

REPO_PROGRESS_SCOPE := edgerun-ui-core
REPO_PROGRESS_TEST :=
USER_APP_PACKAGE_DIR := tests/fixtures/app-package/app
PI_ZERO_W_V1_1_USB_BOOT_DIR := .build/edgerun-metal/pi-zero-w-v1_1/boot
PI_USB_BOOT_DEVICE_ARG := $(if $(PI_USB_DEVICE),--device $(PI_USB_DEVICE),)

all: edgerun-metal

check: repo-check repo-test crypto-test edgerun-check varfont-test ui-core-test

er-build: $(ER_BUILD_BOOTSTRAP)
	mkdir -p .build
	cp $(ER_BUILD_BOOTSTRAP) .build/er-build
	chmod 755 .build/er-build

repo-check: er-build
	./.build/er-build repo-check

repo-test: er-build
	./.build/er-build repo-test

repo-check-bin: er-build
	./.build/er-build repo-check-bin

repo-push-check: er-build
	./.build/er-build repo-push-check

repo-inspect: er-build
	./.build/er-build repo-inspect

repo-progress: er-build
	./.build/er-build repo-progress $(REPO_PROGRESS_SCOPE) $(REPO_PROGRESS_TEST)

repo-agent-swarm: er-build
	./.build/er-build repo-agent-swarm

erwire-decode: er-build
	./.build/er-build erwire-decode

erwire-test: er-build
	./.build/er-build erwire-test

pi-serial-verify: er-build
	./.build/er-build pi-serial-verify

sdcard-probe: er-build
	./.build/er-build sdcard-probe

pi-usb-boot: er-build
	./.build/er-build pi-usb-boot

pi-zero-w-v1_1-usb-boot: er-build
	$(MAKE) -C edgerun-metal pi-zero-w-v1_1-boot
	./.build/er-build pi-usb-boot
	./.build/pi-usb-boot --boot-dir $(PI_ZERO_W_V1_1_USB_BOOT_DIR) $(PI_USB_BOOT_DEVICE_ARG) --verbose

codex-build:
	$(MAKE) -C codex CC="$(HOST_CC_FOR_SUBMAKE)"

codex-test:
	$(MAKE) -C codex CC="$(HOST_CC_FOR_SUBMAKE)" test

crypto-test: er-build
	./.build/er-build crypto-test

metal-ui-bench:
	$(MAKE) -C edgerun-metal bench-ui-dirty

tpm-real-bench-uefi:
	$(MAKE) -C edgerun-metal tpm-real-bench-uefi

qemu-host-tpm-bench:
	$(MAKE) -C edgerun-metal qemu-host-tpm-bench

os-user-app-smoke: er-build
	./.build/er-build app-build $(USER_APP_PACKAGE_DIR)
	./.build/er-build app-verify $(USER_APP_PACKAGE_DIR)
	./.build/er-build app-run $(USER_APP_PACKAGE_DIR)
	$(MAKE) -C edgerun-metal os
	$(MAKE) -C edgerun-metal bench-ui-dirty

edgerun-metal:
	$(MAKE) -C edgerun-metal

edgerun-os:
	$(MAKE) -C edgerun-metal os

edgerun-check:
	$(MAKE) -C edgerun-metal check

varfont-test: er-build
	./.build/er-build varfont-test

ui-core-test: er-build
	./.build/er-build ui-core-test

clean:
	$(MAKE) -C edgerun-metal clean
	rm -rf .build
