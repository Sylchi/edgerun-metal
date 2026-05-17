.PHONY: all run clean print-path netboot smoke pci quiet mmio rebuild-profile check test-core log-listen install-log-listen uninstall-log-listen restart-log-listen logs-log-listen status-log-listen install-netboot uninstall-netboot restart-netboot logs-netboot status-netboot

CC = clang
HOST_CC = cc

BUILD_DIR := build
ESP_DIR := $(BUILD_DIR)/esp
EFI_OUT := $(BUILD_DIR)/edgerun-metal.efi
EFI_BOOT := $(ESP_DIR)/EFI/BOOT/BOOTX64.EFI

# Boot profiles are defined in core/efi_main.c:
#   0 = smoke: banner + test Wasm only
#   1 = pci:   PCI scan module
#   2 = quiet: minimal halt-ready boot
#   3 = mmio:  read-only NVIDIA BAR0 probe
ER_BOOT_PROFILE ?= 0

CFLAGS := -std=c11 -Wall -Werror -ffreestanding -fshort-wchar -fno-builtin -fno-stack-protector -mno-red-zone -fuse-ld=lld -target x86_64-pc-windows-msvc \
          -I$(CURDIR)/core -I$(CURDIR) -DER_BOOT_PROFILE=$(ER_BOOT_PROFILE)
LDFLAGS := -nostdlib -Wl,/SUBSYSTEM:EFI_APPLICATION,/ENTRY:efi_main
HOST_CFLAGS := -std=c11 -Wall -Wextra -Werror -O2

SRCS := core/efi_main.c core/er_print.c core/er_gfx_console.c core/er_netlog.c core/wasm_vm.c core/er_pci.c core/er_mmio.c
OBJS := $(patsubst %.c,$(BUILD_DIR)/%.o,$(SRCS))
HDRS := $(wildcard core/*.h)
NETBOOT_SRC := tools/edgerun-netboot/main.c
NETBOOT_BIN := $(BUILD_DIR)/edgerun-netboot
PXE4011_SRC := tools/edgerun-pxe4011/main.c
PXE4011_BIN := $(BUILD_DIR)/edgerun-pxe4011
CORE_TEST_SRC := tests/test_core.c core/er_pci.c core/er_mmio.c core/wasm_vm.c
CORE_TEST_BIN := $(BUILD_DIR)/test-core
IFACE ?=

all: $(EFI_OUT) $(EFI_BOOT)

smoke:
	$(MAKE) rebuild-profile ER_BOOT_PROFILE=0

pci:
	$(MAKE) rebuild-profile ER_BOOT_PROFILE=1

quiet:
	$(MAKE) rebuild-profile ER_BOOT_PROFILE=2

mmio:
	$(MAKE) rebuild-profile ER_BOOT_PROFILE=3

rebuild-profile:
	rm -f $(OBJS) $(EFI_OUT) $(EFI_BOOT)
	$(MAKE) all ER_BOOT_PROFILE=$(ER_BOOT_PROFILE)

netboot: $(NETBOOT_BIN) $(PXE4011_BIN)

check: smoke pci mmio quiet test-core

test-core: $(CORE_TEST_BIN)
	./$(CORE_TEST_BIN)

log-listen:
	./tools/edgerun-log-listen.sh

install-log-listen:
	sudo ./tools/install-log-listen-service.sh

uninstall-log-listen:
	sudo ./tools/uninstall-log-listen-service.sh

restart-log-listen:
	sudo systemctl restart edgerun-log-listen

logs-log-listen:
	sudo journalctl -u edgerun-log-listen -f

status-log-listen:
	systemctl status edgerun-log-listen

install-netboot:
	@if [ -z "$(IFACE)" ]; then \
		echo "IFACE is required: make install-netboot IFACE=<iface>"; \
		exit 1; \
	fi
	sudo ./tools/install-netboot-service.sh $(IFACE)

uninstall-netboot:
	sudo ./tools/uninstall-netboot-service.sh

restart-netboot:
	sudo systemctl restart edgerun-netboot

logs-netboot:
	sudo journalctl -u edgerun-netboot -f

status-netboot:
	systemctl status edgerun-netboot

$(BUILD_DIR)/%.o: %.c $(HDRS)
	mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(EFI_OUT): $(OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^

$(NETBOOT_BIN): $(NETBOOT_SRC)
	mkdir -p $(dir $@)
	$(HOST_CC) $(HOST_CFLAGS) -o $@ $<

$(PXE4011_BIN): $(PXE4011_SRC)
	mkdir -p $(dir $@)
	$(HOST_CC) $(HOST_CFLAGS) -o $@ $<

$(CORE_TEST_BIN): $(CORE_TEST_SRC) $(HDRS)
	mkdir -p $(dir $@)
	$(HOST_CC) $(HOST_CFLAGS) -I$(CURDIR)/core -o $@ $(CORE_TEST_SRC)

$(EFI_BOOT): $(EFI_OUT)
	mkdir -p $(dir $@)
	cp $< $@

run: $(EFI_BOOT)
	./scripts/run-qemu.sh

clean:
	rm -rf $(BUILD_DIR)

print-path:
	@printf '%s\n' "$(abspath $(EFI_BOOT))"
