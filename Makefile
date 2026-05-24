.PHONY: all check clean \
	crypto-test crypto-bench \
	clock-test identity-test object-test storage-test sdk-test \
	ui-core-test \
	zig-check zig-fmt-check zig-fmt zig-test zig-real-tpm sdk-cli sdk-bench \
	wayland-window wayland-window-test \
	pi-zero-w-v1_1-kernel pi-zero-w-v1_1-usb-probe pi-usb-host pi-usb-state \
	pi-boot-firmware-check pi-usb-reset-controller pi-usb-dry-run pi-usb-boot-dir \
	pi-usb-load pi-usb-load-probe pi-usb-load-usbflag pi-usb-load-probe-usbflag \
	pi-usb-recover-load pi-usb-recover-load-probe \
	pi-usb-control-host pi-usb-control-dry-run pi-usb-control

BUILD_DIR := .build
CMAKE ?= cmake
CTEST ?= ctest
PI_BOOT_DIR := $(BUILD_DIR)/edgerun-metal/pi-zero-w-v1_1/boot
PI_USB_BOOT_DIR := $(BUILD_DIR)/pi-zero-w-v1_1-usb-boot
PI_USB_XHCI_DEVICE := 0000:c3:00.4

all: check

check: crypto-test clock-test identity-test object-test storage-test sdk-test ui-core-test zig-check

crypto-test:
	$(CMAKE) -S edgerun-crypto -B $(BUILD_DIR)/edgerun-crypto
	$(CMAKE) --build $(BUILD_DIR)/edgerun-crypto --target test_blake3
	$(CTEST) --test-dir $(BUILD_DIR)/edgerun-crypto --output-on-failure

crypto-bench:
	$(CMAKE) -S edgerun-crypto -B $(BUILD_DIR)/edgerun-crypto
	$(CMAKE) --build $(BUILD_DIR)/edgerun-crypto --target bench

clock-test:
	zig build --build-file edgerun-zig/build.zig --cache-dir $(BUILD_DIR)/edgerun-zig clock-test

identity-test:
	zig build --build-file edgerun-zig/build.zig --cache-dir $(BUILD_DIR)/edgerun-zig identity-test

object-test:
	zig build --build-file edgerun-zig/build.zig --cache-dir $(BUILD_DIR)/edgerun-zig object-test

storage-test:
	zig build --build-file edgerun-zig/build.zig --cache-dir $(BUILD_DIR)/edgerun-zig storage-test

sdk-test:
	zig build --build-file edgerun-zig/build.zig --cache-dir $(BUILD_DIR)/edgerun-zig sdk-test

sdk-cli:
	zig build --build-file edgerun-zig/build.zig --cache-dir $(BUILD_DIR)/edgerun-zig sdk-cli -- simulate standard

sdk-bench:
	zig build --build-file edgerun-zig/build.zig --cache-dir $(BUILD_DIR)/edgerun-zig sdk-bench

ui-core-test:
	zig build --build-file edgerun-zig/build.zig --cache-dir $(BUILD_DIR)/edgerun-zig ui-core-test

wayland-window:
	zig build --build-file edgerun-zig/build.zig --cache-dir $(BUILD_DIR)/edgerun-zig wayland-window -- --seconds 5

wayland-window-test:
	zig build --build-file edgerun-zig/build.zig --cache-dir $(BUILD_DIR)/edgerun-zig wayland-window-test

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

pi-boot-firmware-check:
	@test -f "$(PI_BOOT_DIR)/bootcode.bin" || { printf 'missing Pi Zero W boot firmware: %s\n' '$(PI_BOOT_DIR)/bootcode.bin'; exit 1; }
	@test -f "$(PI_BOOT_DIR)/start.elf" || { printf 'missing Pi Zero W boot firmware: %s\n' '$(PI_BOOT_DIR)/start.elf'; exit 1; }
	@test -f "$(PI_BOOT_DIR)/fixup.dat" || { printf 'missing Pi Zero W boot firmware: %s\n' '$(PI_BOOT_DIR)/fixup.dat'; exit 1; }
	@test -f "$(PI_BOOT_DIR)/cmdline.txt" || { printf 'missing Pi Zero W boot firmware: %s\n' '$(PI_BOOT_DIR)/cmdline.txt'; exit 1; }

pi-usb-reset-controller:
	sudo sh -c 'echo "$(PI_USB_XHCI_DEVICE)" > /sys/bus/pci/drivers/xhci_hcd/unbind'
	sleep 3
	sudo sh -c 'echo "$(PI_USB_XHCI_DEVICE)" > /sys/bus/pci/drivers/xhci_hcd/bind'

$(PI_USB_BOOT_DIR)/config.txt: pi-boot-firmware-check
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

pi-usb-load: pi-boot-firmware-check pi-zero-w-v1_1-kernel pi-usb-host
	sudo $(BUILD_DIR)/pi-usb-host/edgerun-pi-usb-boot-host --wait --wait-ms 120000 --serve-dir $(PI_BOOT_DIR) --kernel-image $(BUILD_DIR)/pi-zero-w-v1_1-zig/kernel-padded.img $(PI_BOOT_DIR)/bootcode.bin

pi-usb-load-probe: pi-boot-firmware-check pi-zero-w-v1_1-usb-probe pi-usb-host
	sudo $(BUILD_DIR)/pi-usb-host/edgerun-pi-usb-boot-host --wait --wait-ms 120000 --serve-dir $(PI_BOOT_DIR) --kernel-image $(BUILD_DIR)/pi-zero-w-v1_1-usb-probe/kernel-padded.img $(PI_BOOT_DIR)/bootcode.bin

pi-usb-load-usbflag: pi-boot-firmware-check pi-zero-w-v1_1-kernel pi-usb-host pi-usb-boot-dir
	sudo $(BUILD_DIR)/pi-usb-host/edgerun-pi-usb-boot-host --wait --wait-ms 120000 --serve-dir $(PI_USB_BOOT_DIR) --kernel-image $(BUILD_DIR)/pi-zero-w-v1_1-zig/kernel-padded.img $(PI_USB_BOOT_DIR)/bootcode.bin

pi-usb-load-probe-usbflag: pi-boot-firmware-check pi-zero-w-v1_1-usb-probe pi-usb-host pi-usb-boot-dir
	sudo $(BUILD_DIR)/pi-usb-host/edgerun-pi-usb-boot-host --wait --wait-ms 120000 --serve-dir $(PI_USB_BOOT_DIR) --kernel-image $(BUILD_DIR)/pi-zero-w-v1_1-usb-probe/kernel-padded.img $(PI_USB_BOOT_DIR)/bootcode.bin

pi-usb-recover-load: pi-boot-firmware-check pi-usb-reset-controller pi-usb-load

pi-usb-recover-load-probe: pi-boot-firmware-check pi-usb-reset-controller pi-usb-load-probe

pi-usb-dry-run: pi-boot-firmware-check pi-zero-w-v1_1-kernel
	zig build --build-file edgerun-zig/build.zig --cache-dir $(BUILD_DIR)/edgerun-zig pi-usb-load -- --dry-run --serve-dir $(PI_BOOT_DIR) --kernel-image $(BUILD_DIR)/pi-zero-w-v1_1-zig/kernel.img $(PI_BOOT_DIR)/bootcode.bin

pi-usb-control: pi-usb-control-host
	sudo $(BUILD_DIR)/pi-usb-host/edgerun-pi-usb-control-host --wait-ms 10000 gpio-read 47

pi-usb-control-dry-run:
	zig build --build-file edgerun-zig/build.zig --cache-dir $(BUILD_DIR)/edgerun-zig pi-usb-control -- --dry-run gpio-read 47

clean:
	rm -rf $(BUILD_DIR)
