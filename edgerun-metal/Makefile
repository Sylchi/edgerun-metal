.PHONY: all run clean print-path netboot smoke pci quiet mmio ui rebuild-profile check test-core wasm-modules install-netboot uninstall-netboot restart-netboot logs-netboot status-netboot

CC = clang
HOST_CC ?= clang
CCACHE ?= $(shell command -v ccache 2>/dev/null)
MOLD ?= $(shell command -v mold 2>/dev/null)
CCACHE_PREFIX := $(if $(CCACHE),$(CCACHE),)

BUILD_DIR := build
ESP_DIR := $(BUILD_DIR)/esp
EFI_OUT := $(BUILD_DIR)/edgerun-metal.efi
EFI_BOOT := $(ESP_DIR)/EFI/BOOT/BOOTX64.EFI
UI_CORE_DIR := ../edgerun-ui-core
VARFONT_DIR := ../varfont
CRYPTO_DIR := ../edgerun-crypto
GENERATED_DIR := $(BUILD_DIR)/generated

# Boot profiles are defined in core/efi_main.c:
#   0 = smoke: banner + test Wasm only
#   1 = pci:   PCI scan module
#   2 = quiet: minimal halt-ready boot
#   3 = mmio:  read-only NVIDIA BAR0 probe
#   4 = ui:    GOP-backed UI rectangle scene
ER_BOOT_PROFILE ?= 0

CFLAGS := -std=c11 -Wall -Werror -ffreestanding -fshort-wchar -fno-builtin -fno-stack-protector -mno-red-zone -fuse-ld=lld -target x86_64-pc-windows-msvc \
          -I$(CURDIR)/core -I$(CURDIR) -I$(CURDIR)/$(GENERATED_DIR) -I$(CURDIR)/$(CRYPTO_DIR)/include -I$(CURDIR)/$(UI_CORE_DIR)/include -I$(CURDIR)/$(VARFONT_DIR)/include -DER_BOOT_PROFILE=$(ER_BOOT_PROFILE)
CRYPTO_CFLAGS := $(CFLAGS) -O3
LDFLAGS := -nostdlib -Wl,/SUBSYSTEM:EFI_APPLICATION,/ENTRY:efi_main
HOST_CFLAGS := -std=c11 -Wall -Wextra -Werror -O2 -I$(CURDIR)/core -I$(CURDIR)/$(GENERATED_DIR) -I$(CURDIR)/$(CRYPTO_DIR)/include -I$(CURDIR)/$(UI_CORE_DIR)/include -I$(CURDIR)/$(VARFONT_DIR)/include
HOST_LDFLAGS ?= $(if $(MOLD),-fuse-ld=mold,)

SRCS := core/efi_main.c core/er_print.c core/er_gfx_console.c core/er_ui_gop_renderer.c core/er_freestanding.c core/er_netlog.c core/er_crypto.c core/er_crypto_blake3.c core/er_mem.c core/er_vfs.c core/er_app.c core/er_hw_relay.c core/er_bus.c core/er_acpi.c core/erwire.c core/wasm_vm.c core/er_pci.c core/er_mmio.c
UI_SRCS := $(UI_CORE_DIR)/src/er_ui_primitives.c $(UI_CORE_DIR)/src/er_ui_scene.c $(UI_CORE_DIR)/src/er_ui_painter.c $(UI_CORE_DIR)/src/er_ui_theme.c $(UI_CORE_DIR)/src/er_ui_text.c $(UI_CORE_DIR)/src/er_ui_components.c $(UI_CORE_DIR)/src/er_ui_icon.c $(UI_CORE_DIR)/src/er_ui_metal.c $(UI_CORE_DIR)/src/er_ui_node.c
VARFONT_SRCS := $(VARFONT_DIR)/src/vr_font.c $(VARFONT_DIR)/src/vr_font_utils.c $(VARFONT_DIR)/src/vr_font_shape.c $(VARFONT_DIR)/src/vr_font_raster.c $(VARFONT_DIR)/src/vr_font_atlas.c
CRYPTO_SRCS := $(CRYPTO_DIR)/src/er_blake3.c
OBJS := $(patsubst %.c,$(BUILD_DIR)/%.o,$(SRCS))
UI_OBJS := $(patsubst $(UI_CORE_DIR)/src/%.c,$(BUILD_DIR)/ui-core/%.o,$(UI_SRCS))
VARFONT_OBJS := $(patsubst $(VARFONT_DIR)/src/%.c,$(BUILD_DIR)/varfont/%.o,$(VARFONT_SRCS))
CRYPTO_OBJS := $(patsubst $(CRYPTO_DIR)/src/%.c,$(BUILD_DIR)/crypto/%.o,$(CRYPTO_SRCS))
HDRS := $(wildcard core/*.h)
UI_HDRS := $(wildcard $(UI_CORE_DIR)/include/*.h)
VARFONT_HDRS := $(wildcard $(VARFONT_DIR)/include/*.h) $(wildcard $(VARFONT_DIR)/src/*.h)
CRYPTO_HDRS := $(wildcard $(CRYPTO_DIR)/include/*.h)
WASM_HEADER_GEN := scripts/generate-wasm-header.sh
BIN_HEADER_GEN := scripts/generate-binary-header.sh
WASM_MODULE_HEADERS := core/wasm_test_module.h core/wasm_pci_scan_module.h core/wasm_driver_bus_probe_module.h
FONT_HEADER := $(GENERATED_DIR)/font_geist.h
FONT_BAKED_HEADER := $(GENERATED_DIR)/font_geist_baked.h
FONT_SOURCE := $(VARFONT_DIR)/fonts/Geist[wght].ttf
FONT_BAKE_SRC := tools/font-bake/main.c
FONT_BAKE_BIN := $(BUILD_DIR)/font-bake
NETBOOT_SRC := tools/edgerun-netboot/main.c
NETBOOT_BIN := $(BUILD_DIR)/edgerun-netboot
PXE4011_SRC := tools/edgerun-pxe4011/main.c
PXE4011_BIN := $(BUILD_DIR)/edgerun-pxe4011
CORE_TEST_SRC := tests/test_core.c core/er_pci.c core/er_mmio.c core/er_crypto.c core/er_crypto_blake3.c $(CRYPTO_SRCS) core/er_mem.c core/er_vfs.c core/er_app.c core/er_hw_relay.c core/er_bus.c core/er_acpi.c core/er_netlog.c core/er_ui_gop_renderer.c core/wasm_vm.c $(UI_SRCS) $(VARFONT_SRCS)
CORE_TEST_BIN := $(BUILD_DIR)/test-core
IFACE ?=

all: wasm-modules $(FONT_HEADER) $(FONT_BAKED_HEADER) $(EFI_OUT) $(EFI_BOOT)

smoke:
	$(MAKE) rebuild-profile ER_BOOT_PROFILE=0

pci:
	$(MAKE) rebuild-profile ER_BOOT_PROFILE=1

quiet:
	$(MAKE) rebuild-profile ER_BOOT_PROFILE=2

mmio:
	$(MAKE) rebuild-profile ER_BOOT_PROFILE=3

ui:
	$(MAKE) rebuild-profile ER_BOOT_PROFILE=4

rebuild-profile:
	rm -f $(OBJS) $(UI_OBJS) $(VARFONT_OBJS) $(CRYPTO_OBJS) $(EFI_OUT) $(EFI_BOOT)
	$(MAKE) all ER_BOOT_PROFILE=$(ER_BOOT_PROFILE)

netboot: $(NETBOOT_BIN) $(PXE4011_BIN)

check: smoke pci mmio quiet ui test-core

test-core: $(CORE_TEST_BIN)
	./$(CORE_TEST_BIN)

wasm-modules: $(WASM_MODULE_HEADERS)

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

core/wasm_test_module.h: modules/test_return_123/test_return_123.wat $(WASM_HEADER_GEN)
	$(WASM_HEADER_GEN) $< $@ WASM_TEST_MODULE_H g_edgerun_test_wasm ER_TEST_WASM_SIZE

core/wasm_pci_scan_module.h: modules/pci_scan/pci_scan.wat $(WASM_HEADER_GEN)
	$(WASM_HEADER_GEN) $< $@ WASM_PCI_SCAN_MODULE_H g_edgerun_pci_scan_wasm ER_PCI_SCAN_WASM_SIZE

core/wasm_driver_bus_probe_module.h: modules/driver_bus_probe/driver_bus_probe.wat $(WASM_HEADER_GEN)
	$(WASM_HEADER_GEN) $< $@ WASM_DRIVER_BUS_PROBE_MODULE_H g_edgerun_driver_bus_probe_wasm ER_DRIVER_BUS_PROBE_WASM_SIZE

$(FONT_HEADER): $(FONT_SOURCE) $(BIN_HEADER_GEN)
	$(BIN_HEADER_GEN) "$<" "$@" ER_FONT_GEIST_H g_er_font_geist_ttf ER_FONT_GEIST_TTF_SIZE

$(FONT_BAKE_BIN): $(FONT_BAKE_SRC) $(VARFONT_SRCS) $(VARFONT_HDRS)
	mkdir -p $(dir $@)
	$(CCACHE_PREFIX) $(HOST_CC) $(HOST_CFLAGS) -I$(CURDIR)/$(VARFONT_DIR)/src $(HOST_LDFLAGS) -o $@ $(FONT_BAKE_SRC) $(VARFONT_SRCS)

$(FONT_BAKED_HEADER): $(FONT_SOURCE) $(FONT_BAKE_BIN)
	$(FONT_BAKE_BIN) "$<" "$@"

$(BUILD_DIR)/%.o: %.c $(HDRS) $(UI_HDRS) $(VARFONT_HDRS) $(CRYPTO_HDRS) $(WASM_MODULE_HEADERS) $(FONT_HEADER) $(FONT_BAKED_HEADER)
	mkdir -p $(dir $@)
	$(CCACHE_PREFIX) $(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/ui-core/%.o: $(UI_CORE_DIR)/src/%.c $(UI_HDRS) $(VARFONT_HDRS)
	mkdir -p $(dir $@)
	$(CCACHE_PREFIX) $(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/varfont/%.o: $(VARFONT_DIR)/src/%.c $(VARFONT_HDRS)
	mkdir -p $(dir $@)
	$(CCACHE_PREFIX) $(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/crypto/%.o: $(CRYPTO_DIR)/src/%.c $(CRYPTO_HDRS)
	mkdir -p $(dir $@)
	$(CCACHE_PREFIX) $(CC) $(CRYPTO_CFLAGS) -c $< -o $@

$(EFI_OUT): $(OBJS) $(UI_OBJS) $(VARFONT_OBJS) $(CRYPTO_OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^

$(NETBOOT_BIN): $(NETBOOT_SRC)
	mkdir -p $(dir $@)
	$(CCACHE_PREFIX) $(HOST_CC) $(HOST_CFLAGS) $(HOST_LDFLAGS) -o $@ $<

$(PXE4011_BIN): $(PXE4011_SRC)
	mkdir -p $(dir $@)
	$(CCACHE_PREFIX) $(HOST_CC) $(HOST_CFLAGS) $(HOST_LDFLAGS) -o $@ $<

$(CORE_TEST_BIN): $(CORE_TEST_SRC) $(HDRS) $(UI_HDRS) $(VARFONT_HDRS) $(CRYPTO_HDRS) $(WASM_MODULE_HEADERS) $(FONT_HEADER)
	mkdir -p $(dir $@)
	$(CCACHE_PREFIX) $(HOST_CC) $(HOST_CFLAGS) $(HOST_LDFLAGS) -o $@ $(CORE_TEST_SRC)

$(EFI_BOOT): $(EFI_OUT)
	mkdir -p $(dir $@)
	cp $< $@

run: $(EFI_BOOT)
	./scripts/run-qemu.sh

clean:
	rm -rf $(BUILD_DIR)

print-path:
	@printf '%s\n' "$(abspath $(EFI_BOOT))"
