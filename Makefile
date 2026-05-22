.PHONY: all check clean \
	crypto-test crypto-bench \
	clock-test identity-test object-test storage-test \
	ui-core-test \
	zig-check zig-fmt-check zig-fmt zig-test zig-real-tpm \
	pi-zero-w-v1_1-kernel pi-zero-w-v1_1-usb-probe pi-usb-host pi-usb-state \
	pi-usb-reset-port pi-usb-reset-controller pi-usb-dry-run pi-usb-boot-dir \
	pi-usb-load pi-usb-load-probe pi-usb-load-usbflag pi-usb-load-probe-usbflag \
	pi-usb-recover-load pi-usb-recover-load-probe \
	pi-usb-control-host pi-usb-control-dry-run pi-usb-control

BUILD_DIR := .build
CMAKE ?= cmake
CTEST ?= ctest
PI_BOOT_DIR := $(BUILD_DIR)/edgerun-metal/pi-zero-w-v1_1/boot
PI_USB_BOOT_DIR := $(BUILD_DIR)/pi-zero-w-v1_1-usb-boot

all: check

check: crypto-test clock-test identity-test object-test storage-test ui-core-test zig-check

crypto-test:
	$(CMAKE) -S edgerun-crypto -B $(BUILD_DIR)/edgerun-crypto -DER_CRYPTO_USE_UPSTREAM_BLAKE3_ASM=OFF
	$(CMAKE) --build $(BUILD_DIR)/edgerun-crypto --target test_blake3
	$(CTEST) --test-dir $(BUILD_DIR)/edgerun-crypto --output-on-failure

crypto-bench:
	$(CMAKE) -S edgerun-crypto -B $(BUILD_DIR)/edgerun-crypto -DER_CRYPTO_USE_UPSTREAM_BLAKE3_ASM=OFF
	$(CMAKE) --build $(BUILD_DIR)/edgerun-crypto --target bench

clock-test:
	zig build --build-file edgerun-zig/build.zig --cache-dir $(BUILD_DIR)/edgerun-zig clock-test

identity-test:
	zig build --build-file edgerun-zig/build.zig --cache-dir $(BUILD_DIR)/edgerun-zig identity-test

object-test:
	zig build --build-file edgerun-zig/build.zig --cache-dir $(BUILD_DIR)/edgerun-zig object-test

storage-test:
	zig build --build-file edgerun-zig/build.zig --cache-dir $(BUILD_DIR)/edgerun-zig storage-test

ui-core-test:
	zig build --build-file edgerun-zig/build.zig --cache-dir $(BUILD_DIR)/edgerun-zig ui-core-test

zig-check: zig-fmt-check zig-test

zig-fmt-check:
	zig fmt --check edgerun-zig

zig-fmt:
	zig fmt edgerun-zig

zig-test:
	zig build --build-file edgerun-zig/build.zig --cache-dir $(BUILD_DIR)/edgerun-zig test

zig-real-tpm:
	zig build --build-file edgerun-zig/build.zig --cache-dir $(BUILD_DIR)/edgerun-zig real-tpm

pi-zero-w-v1_1-kernel:
	mkdir -p $(BUILD_DIR)/pi-zero-w-v1_1-zig
	zig build-exe edgerun-zig/src/pi_zero_w_v1_1_kernel.zig -target arm-freestanding-eabi -mcpu=arm1176jzf_s -O ReleaseSmall -femit-bin=$(BUILD_DIR)/pi-zero-w-v1_1-zig/kernel.elf -fno-entry -T edgerun-zig/pi-zero-w-v1_1-kernel.ld
	llvm-objcopy -O binary $(BUILD_DIR)/pi-zero-w-v1_1-zig/kernel.elf $(BUILD_DIR)/pi-zero-w-v1_1-zig/kernel.img
	cp $(BUILD_DIR)/pi-zero-w-v1_1-zig/kernel.img $(BUILD_DIR)/pi-zero-w-v1_1-zig/kernel-padded.img
	truncate -s 65536 $(BUILD_DIR)/pi-zero-w-v1_1-zig/kernel-padded.img

pi-zero-w-v1_1-usb-probe:
	mkdir -p $(BUILD_DIR)/pi-zero-w-v1_1-usb-probe
	zig build-exe edgerun-zig/src/pi_zero_w_v1_1_usb_probe_kernel.zig -target arm-freestanding-eabi -mcpu=arm1176jzf_s -O ReleaseSmall -femit-bin=$(BUILD_DIR)/pi-zero-w-v1_1-usb-probe/kernel.elf -fno-entry -T edgerun-zig/pi-zero-w-v1_1-kernel.ld
	llvm-objcopy -O binary $(BUILD_DIR)/pi-zero-w-v1_1-usb-probe/kernel.elf $(BUILD_DIR)/pi-zero-w-v1_1-usb-probe/kernel.img
	cp $(BUILD_DIR)/pi-zero-w-v1_1-usb-probe/kernel.img $(BUILD_DIR)/pi-zero-w-v1_1-usb-probe/kernel-padded.img
	truncate -s 65536 $(BUILD_DIR)/pi-zero-w-v1_1-usb-probe/kernel-padded.img

pi-usb-host:
	mkdir -p $(BUILD_DIR)/pi-usb-host
	zig build-exe edgerun-zig/src/pi_usb_boot_host.zig --cache-dir $(BUILD_DIR)/edgerun-zig -femit-bin=$(BUILD_DIR)/pi-usb-host/edgerun-pi-usb-boot-host

pi-usb-control-host:
	mkdir -p $(BUILD_DIR)/pi-usb-host
	zig build-exe edgerun-zig/src/pi_usb_control_host.zig --cache-dir $(BUILD_DIR)/edgerun-zig -femit-bin=$(BUILD_DIR)/pi-usb-host/edgerun-pi-usb-control-host

pi-usb-state:
	lsusb -t
	lsusb | grep -E '0a5c:2763|0a5c:2764|4552:5049|Broadcom|BCM2708|BCM2710|Edgerun' || true
	sudo dmesg --ctime | tail -n 40

pi-usb-reset-port:
	printf 1 | sudo tee /sys/devices/pci0000:00/0000:00:08.1/0000:c1:00.3/usb1/1-0:1.0/usb1-port1/disable >/dev/null
	sleep 10
	printf 0 | sudo tee /sys/devices/pci0000:00/0000:00:08.1/0000:c1:00.3/usb1/1-0:1.0/usb1-port1/disable >/dev/null

pi-usb-reset-controller:
	printf '0000:c1:00.3' | sudo tee /sys/bus/pci/drivers/xhci_hcd/unbind >/dev/null
	sleep 2
	printf '0000:c1:00.3' | sudo tee /sys/bus/pci/drivers/xhci_hcd/bind >/dev/null

$(PI_USB_BOOT_DIR)/config.txt: $(PI_BOOT_DIR)/config.txt
	mkdir -p $(PI_USB_BOOT_DIR)
	cp $(PI_BOOT_DIR)/bootcode.bin $(PI_USB_BOOT_DIR)/bootcode.bin
	cp $(PI_BOOT_DIR)/start.elf $(PI_USB_BOOT_DIR)/start.elf
	cp $(PI_BOOT_DIR)/fixup.dat $(PI_USB_BOOT_DIR)/fixup.dat
	cp $(PI_BOOT_DIR)/cmdline.txt $(PI_USB_BOOT_DIR)/cmdline.txt
	printf 'arm_64bit=0\n' > $(PI_USB_BOOT_DIR)/config.txt
	printf 'device_tree=\n' >> $(PI_USB_BOOT_DIR)/config.txt
	printf 'core_freq=250\n' >> $(PI_USB_BOOT_DIR)/config.txt
	printf 'kernel=kernel.img\n' >> $(PI_USB_BOOT_DIR)/config.txt
	printf 'boot_load_flags=1\n' >> $(PI_USB_BOOT_DIR)/config.txt

pi-usb-boot-dir: $(PI_USB_BOOT_DIR)/config.txt

pi-usb-load: pi-zero-w-v1_1-kernel pi-usb-host
	sudo $(BUILD_DIR)/pi-usb-host/edgerun-pi-usb-boot-host --wait --wait-ms 120000 --serve-dir $(PI_BOOT_DIR) --kernel-image $(BUILD_DIR)/pi-zero-w-v1_1-zig/kernel-padded.img $(PI_BOOT_DIR)/bootcode.bin

pi-usb-load-probe: pi-zero-w-v1_1-usb-probe pi-usb-host
	sudo $(BUILD_DIR)/pi-usb-host/edgerun-pi-usb-boot-host --wait --wait-ms 120000 --serve-dir $(PI_BOOT_DIR) --kernel-image $(BUILD_DIR)/pi-zero-w-v1_1-usb-probe/kernel-padded.img $(PI_BOOT_DIR)/bootcode.bin

pi-usb-load-usbflag: pi-zero-w-v1_1-kernel pi-usb-host pi-usb-boot-dir
	sudo $(BUILD_DIR)/pi-usb-host/edgerun-pi-usb-boot-host --wait --wait-ms 120000 --serve-dir $(PI_USB_BOOT_DIR) --kernel-image $(BUILD_DIR)/pi-zero-w-v1_1-zig/kernel-padded.img $(PI_USB_BOOT_DIR)/bootcode.bin

pi-usb-load-probe-usbflag: pi-zero-w-v1_1-usb-probe pi-usb-host pi-usb-boot-dir
	sudo $(BUILD_DIR)/pi-usb-host/edgerun-pi-usb-boot-host --wait --wait-ms 120000 --serve-dir $(PI_USB_BOOT_DIR) --kernel-image $(BUILD_DIR)/pi-zero-w-v1_1-usb-probe/kernel-padded.img $(PI_USB_BOOT_DIR)/bootcode.bin

pi-usb-recover-load: pi-usb-reset-port pi-usb-load

pi-usb-recover-load-probe: pi-usb-reset-port pi-usb-load-probe

pi-usb-dry-run: pi-zero-w-v1_1-kernel
	zig build --build-file edgerun-zig/build.zig --cache-dir $(BUILD_DIR)/edgerun-zig pi-usb-load -- --dry-run --serve-dir $(PI_BOOT_DIR) --kernel-image $(BUILD_DIR)/pi-zero-w-v1_1-zig/kernel.img $(PI_BOOT_DIR)/bootcode.bin

pi-usb-control: pi-usb-control-host
	sudo $(BUILD_DIR)/pi-usb-host/edgerun-pi-usb-control-host --wait-ms 10000 gpio-read 47

pi-usb-control-dry-run:
	zig build --build-file edgerun-zig/build.zig --cache-dir $(BUILD_DIR)/edgerun-zig pi-usb-control -- --dry-run gpio-read 47

clean:
	rm -rf $(BUILD_DIR)
