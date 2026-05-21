.PHONY: all check clean er-build repo-check repo-test repo-check-bin repo-push-check repo-inspect repo-progress repo-agent-swarm erwire-decode erwire-test pi-serial-verify pi-node-update sdcard-probe disk-analyzer pi-usb-boot pi-zero-w-v1_1-ready pi-zero-w-v1_1-usb-boot pi-zero-w-v1_1-update codex-build codex-test crypto-test crypto-bench metal-ui-bench tpm-real-bench-uefi qemu-host-tpm-bench os-user-app-smoke edgerun-metal edgerun-os edgerun-check varfont-test ui-core-test ui-core-snapshot

CC := toolchain/bin/clang
HOST_CC := toolchain/bin/clang
HOST_LDFLAGS :=
HOST_CC_FOR_SUBMAKE := $(if $(findstring /,$(HOST_CC)),$(abspath $(HOST_CC)),$(HOST_CC))
ER_BUILD_BOOTSTRAP := toolchain/bin/er-build
ER_BUILD_STAGED := .build/er-build
ER_BUILD_STAGED_TMP := .build/er-build.tmp

REPO_PROGRESS_SCOPE := edgerun-ui-core
REPO_PROGRESS_TEST :=
USER_APP_PACKAGE_DIR := tests/fixtures/app-package/app
PI_ZERO_W_V1_1_USB_BOOT_DIR := .build/edgerun-metal/pi-zero-w-v1_1/boot
PI_ZERO_W_V1_1_KERNEL := .build/edgerun-metal/pi-zero-w-v1_1/kernel.img
PI_USB_BOOT_DEVICE_ARG := $(if $(PI_USB_DEVICE),--device $(PI_USB_DEVICE),)

all: edgerun-metal

check: repo-check repo-test crypto-test edgerun-check varfont-test ui-core-test

er-build: $(ER_BUILD_BOOTSTRAP)
	mkdir -p .build
	cp $(ER_BUILD_BOOTSTRAP) $(ER_BUILD_STAGED_TMP)
	chmod 755 $(ER_BUILD_STAGED_TMP)
	mv $(ER_BUILD_STAGED_TMP) $(ER_BUILD_STAGED)

repo-check: er-build
	$(ER_BUILD_STAGED) repo-check

repo-test: er-build
	$(ER_BUILD_STAGED) repo-test

repo-check-bin: er-build
	$(ER_BUILD_STAGED) repo-check-bin

repo-push-check: er-build
	$(ER_BUILD_STAGED) repo-push-check

repo-inspect: er-build
	$(ER_BUILD_STAGED) repo-inspect

repo-progress: er-build
	$(ER_BUILD_STAGED) repo-progress $(REPO_PROGRESS_SCOPE) $(REPO_PROGRESS_TEST)

repo-agent-swarm: er-build
	$(ER_BUILD_STAGED) repo-agent-swarm

erwire-decode: er-build
	$(ER_BUILD_STAGED) erwire-decode

erwire-test: er-build
	$(ER_BUILD_STAGED) erwire-test

pi-serial-verify: er-build
	$(ER_BUILD_STAGED) pi-serial-verify

pi-node-update: er-build
	$(ER_BUILD_STAGED) pi-node-update

sdcard-probe: er-build
	$(ER_BUILD_STAGED) sdcard-probe

disk-analyzer: er-build
	$(ER_BUILD_STAGED) disk-analyzer

pi-usb-boot: er-build
	$(ER_BUILD_STAGED) pi-usb-boot

pi-zero-w-v1_1-ready:
	./tools/pi-zero-w-v1_1-bring-up.sh $(PI_ZERO_W_V1_1_READY_ARGS)

pi-zero-w-v1_1-usb-boot: er-build
	$(MAKE) -C edgerun-metal pi-zero-w-v1_1-boot
	$(ER_BUILD_STAGED) pi-usb-boot
	./.build/pi-usb-boot --boot-dir $(PI_ZERO_W_V1_1_USB_BOOT_DIR) $(PI_USB_BOOT_DEVICE_ARG) --verbose

pi-zero-w-v1_1-update: er-build
	test -n "$(PI_UPDATE_IFACE)" || { printf '%s\n' 'PI_UPDATE_IFACE=wlan0 is required for Pi Zero W v1.1 EdgeNet L2 update'; exit 2; }
	$(MAKE) -C edgerun-metal pi-zero-w-v1_1-kernel
	$(ER_BUILD_STAGED) pi-node-update
	./.build/pi-node-update --iface "$(PI_UPDATE_IFACE)" --image "$(PI_ZERO_W_V1_1_KERNEL)"

codex-build:
	$(MAKE) -C codex CC="$(HOST_CC_FOR_SUBMAKE)"

codex-test:
	$(MAKE) -C codex CC="$(HOST_CC_FOR_SUBMAKE)" test

crypto-test: er-build
	$(ER_BUILD_STAGED) crypto-test

crypto-bench: er-build
	$(ER_BUILD_STAGED) crypto-bench

metal-ui-bench:
	$(MAKE) -C edgerun-metal bench-ui-dirty

tpm-real-bench-uefi:
	$(MAKE) -C edgerun-metal tpm-real-bench-uefi

qemu-host-tpm-bench:
	$(MAKE) -C edgerun-metal qemu-host-tpm-bench

os-user-app-smoke: er-build
	$(ER_BUILD_STAGED) app-build $(USER_APP_PACKAGE_DIR)
	$(ER_BUILD_STAGED) app-verify $(USER_APP_PACKAGE_DIR)
	$(ER_BUILD_STAGED) app-run $(USER_APP_PACKAGE_DIR)
	$(MAKE) -C edgerun-metal os
	$(MAKE) -C edgerun-metal bench-ui-dirty

edgerun-metal:
	$(MAKE) -C edgerun-metal

edgerun-os:
	$(MAKE) -C edgerun-metal os

edgerun-check:
	$(MAKE) -C edgerun-metal check

varfont-test: er-build
	$(ER_BUILD_STAGED) varfont-test

ui-core-test: er-build
	$(ER_BUILD_STAGED) ui-core-test

ui-core-snapshot:
	mkdir -p .build/edgerun-ui-core
	cmake -S edgerun-ui-core -B .build/edgerun-ui-core -DER_UI_CORE_BUILD_SNAPSHOT_HOST=ON
	cmake --build .build/edgerun-ui-core --target er_ui_snapshot
	./.build/edgerun-ui-core/er_ui_snapshot --output .build/edgerun-ui-core/snapshot.bmp

clean:
	$(MAKE) -C edgerun-metal clean
	rm -rf .build
