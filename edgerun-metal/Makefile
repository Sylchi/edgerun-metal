.PHONY: all run clean print-path netboot os rebuild-image check test-core wasm-modules qemu-config-check

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

# ER_BOOT_PROFILE=4 selects the OS path: VirtIO GPU UI runtime, Wasm apps, PS/2 input,
# storage-bound package loading, and relay/device endpoint work.
ER_BOOT_PROFILE ?= 4

CFLAGS := -std=c11 -Wall -Werror -ffreestanding -fshort-wchar -fno-builtin -fno-stack-protector -mno-red-zone -fuse-ld=lld -target x86_64-pc-windows-msvc \
          -I$(CURDIR)/core -I$(CURDIR) -I$(CURDIR)/../include -I$(CURDIR)/$(GENERATED_DIR) -I$(CURDIR)/$(CRYPTO_DIR)/include -I$(CURDIR)/$(UI_CORE_DIR)/include -I$(CURDIR)/$(VARFONT_DIR)/include -DER_BOOT_PROFILE=$(ER_BOOT_PROFILE)
CRYPTO_CFLAGS := $(CFLAGS) -O3 -DER_BLAKE3_USE_UPSTREAM_ASM=1
LDFLAGS := -nostdlib -Wl,/SUBSYSTEM:EFI_APPLICATION,/ENTRY:efi_main
HOST_CFLAGS := -std=c11 -Wall -Wextra -Werror -O2 -DER_ENABLE_TEST_HOOKS=1 -I$(CURDIR)/core -I$(CURDIR)/../include -I$(CURDIR)/$(GENERATED_DIR) -I$(CURDIR)/$(CRYPTO_DIR)/include -I$(CURDIR)/$(UI_CORE_DIR)/include -I$(CURDIR)/$(VARFONT_DIR)/include
HOST_LDFLAGS ?= $(if $(MOLD),-fuse-ld=mold,)

SRCS := core/efi_main.c core/efi_boot_memory.c core/efi_boot_diagnostics.c core/efi_boot_gpu.c core/efi_boot_routes.c core/efi_boot_wasm.c core/efi_boot_render.c core/efi_boot_relay.c core/efi_boot_os.c core/er_boot_profile.c core/er_print.c core/er_gfx_console.c core/er_ui_gop_renderer.c core/er_ui_wasm_app.c core/er_epoch_clock.c core/er_freestanding.c core/er_netlog.c core/er_crypto.c core/er_crypto_blake3.c core/er_mem.c core/er_vfs.c core/er_app.c core/er_identity.c core/er_device_identity.c core/er_work_route.c core/er_render_endpoint.c core/er_storage_endpoint.c core/er_tpm.c core/er_hw_relay.c core/er_relay_packet.c core/er_bus.c core/er_ps2_keyboard.c core/er_acpi.c core/erwire.c core/er_native_boot.c core/wasm_vm.c core/wasm_vm_reader.c core/wasm_vm_memory_ui.c core/wasm_vm_execute.c core/er_pci.c core/er_mmio.c core/er_virtio.c core/er_virtio_net.c core/er_virtio_gpu.c core/er_net_frame.c core/er_native_eth.c
UI_SRCS := $(UI_CORE_DIR)/src/er_ui_assets.c $(UI_CORE_DIR)/src/er_ui_components_catalog.c $(UI_CORE_DIR)/src/er_ui_components_catalog_data.c $(UI_CORE_DIR)/src/er_ui_components_contracts.c $(UI_CORE_DIR)/src/er_ui_components_emit.c $(UI_CORE_DIR)/src/er_ui_components_internal.c $(UI_CORE_DIR)/src/er_ui_components_preview.c $(UI_CORE_DIR)/src/er_ui_components_state.c $(UI_CORE_DIR)/src/er_ui_icon.c $(UI_CORE_DIR)/src/er_ui_initial_setup.c $(UI_CORE_DIR)/src/er_ui_ledger_app.c $(UI_CORE_DIR)/src/er_ui_metal.c $(UI_CORE_DIR)/src/er_ui_node.c $(UI_CORE_DIR)/src/er_ui_node_accessibility.c $(UI_CORE_DIR)/src/er_ui_node_layout.c $(UI_CORE_DIR)/src/er_ui_node_render.c $(UI_CORE_DIR)/src/er_ui_node_render_controls.c $(UI_CORE_DIR)/src/er_ui_node_render_conversation.c $(UI_CORE_DIR)/src/er_ui_node_render_panels.c $(UI_CORE_DIR)/src/er_ui_painter.c $(UI_CORE_DIR)/src/er_ui_primitives.c $(UI_CORE_DIR)/src/er_ui_preset_code.c $(UI_CORE_DIR)/src/er_ui_record_codec.c $(UI_CORE_DIR)/src/er_ui_runtime_focus.c $(UI_CORE_DIR)/src/er_ui_runtime_input.c $(UI_CORE_DIR)/src/er_ui_runtime_internal.c $(UI_CORE_DIR)/src/er_ui_runtime_state.c $(UI_CORE_DIR)/src/er_ui_runtime_text.c $(UI_CORE_DIR)/src/er_ui_scene.c $(UI_CORE_DIR)/src/er_ui_shell.c $(UI_CORE_DIR)/src/er_ui_spacing.c $(UI_CORE_DIR)/src/er_ui_theme.c $(UI_CORE_DIR)/src/er_ui_text.c
VARFONT_SRCS := $(VARFONT_DIR)/src/vr_font.c $(VARFONT_DIR)/src/vr_font_utils.c $(VARFONT_DIR)/src/vr_font_axes.c $(VARFONT_DIR)/src/vr_font_cmap.c $(VARFONT_DIR)/src/vr_font_gvar.c $(VARFONT_DIR)/src/vr_font_gvar_apply.c $(VARFONT_DIR)/src/vr_font_kern.c $(VARFONT_DIR)/src/vr_font_tables.c $(VARFONT_DIR)/src/vr_font_shape.c $(VARFONT_DIR)/src/vr_font_raster.c $(VARFONT_DIR)/src/vr_font_raster_geometry.c $(VARFONT_DIR)/src/vr_font_raster_glyph.c $(VARFONT_DIR)/src/vr_font_raster_msdf.c $(VARFONT_DIR)/src/vr_font_raster_outline.c $(VARFONT_DIR)/src/vr_font_raster_storage.c $(VARFONT_DIR)/src/vr_font_atlas.c
CRYPTO_SRCS := $(CRYPTO_DIR)/src/er_blake3.c
CRYPTO_ASM_SRCS := $(CRYPTO_DIR)/../third_party/blake3/c/blake3_sse2_x86-64_windows_gnu.S
OBJS := $(patsubst %.c,$(BUILD_DIR)/%.o,$(SRCS))
UI_OBJS := $(patsubst $(UI_CORE_DIR)/src/%.c,$(BUILD_DIR)/ui-core/%.o,$(UI_SRCS))
VARFONT_OBJS := $(patsubst $(VARFONT_DIR)/src/%.c,$(BUILD_DIR)/varfont/%.o,$(VARFONT_SRCS))
CRYPTO_OBJS := $(patsubst $(CRYPTO_DIR)/src/%.c,$(BUILD_DIR)/crypto/%.o,$(CRYPTO_SRCS))
CRYPTO_ASM_OBJS := $(patsubst $(CRYPTO_DIR)/../third_party/blake3/c/%.S,$(BUILD_DIR)/crypto/%.o,$(CRYPTO_ASM_SRCS))
HDRS := $(wildcard core/*.h)
UI_HDRS := $(wildcard $(UI_CORE_DIR)/include/*.h)
VARFONT_HDRS := $(wildcard $(VARFONT_DIR)/include/*.h) $(wildcard $(VARFONT_DIR)/src/*.h)
CRYPTO_HDRS := $(wildcard $(CRYPTO_DIR)/include/*.h)
EMBED_HEADER_SRC := tools/embed-header/main.c
EMBED_HEADER_BIN := $(BUILD_DIR)/embed-header
WASM_MODULE_HEADERS := core/wasm_driver_bus_probe_module.h core/wasm_ui_counter_module.h
FONT_HEADER := $(GENERATED_DIR)/font_geist.h
FONT_BAKED_HEADER := $(GENERATED_DIR)/font_geist_baked.h
FONT_SOURCE := $(VARFONT_DIR)/fonts/Geist[wght].ttf
FONT_BAKE_SRC := tools/font-bake/main.c
FONT_BAKE_BIN := $(BUILD_DIR)/font-bake
NETBOOT_SRC := tools/edgerun-netboot/main.c
NETBOOT_BIN := $(BUILD_DIR)/edgerun-netboot
PXE4011_SRC := tools/edgerun-pxe4011/main.c
PXE4011_BIN := $(BUILD_DIR)/edgerun-pxe4011
QEMU_RUN_SRC := tools/qemu-run/main.c
QEMU_RUN_BIN := $(BUILD_DIR)/edgerun-qemu-run
QEMU_CONFIG := qemu.conf
CORE_TEST_SRC := tests/test_core.c core/efi_boot_relay.c core/efi_boot_routes.c core/er_boot_profile.c core/er_pci.c core/er_mmio.c core/er_crypto.c core/er_crypto_blake3.c $(CRYPTO_SRCS) core/er_mem.c core/er_vfs.c core/er_app.c core/er_identity.c core/er_device_identity.c core/er_work_route.c core/er_render_endpoint.c core/er_storage_endpoint.c core/er_tpm.c core/er_hw_relay.c core/er_relay_packet.c core/er_bus.c core/er_ps2_keyboard.c core/er_acpi.c core/er_print.c core/er_netlog.c core/er_gfx_console.c core/er_ui_gop_renderer.c core/er_ui_wasm_app.c core/er_epoch_clock.c core/erwire.c core/er_native_boot.c core/wasm_vm.c core/wasm_vm_reader.c core/wasm_vm_memory_ui.c core/wasm_vm_execute.c core/er_virtio.c core/er_virtio_net.c core/er_virtio_gpu.c core/er_net_frame.c core/er_native_eth.c $(UI_SRCS) $(VARFONT_SRCS)
CORE_TEST_BIN := $(BUILD_DIR)/test-core
IFACE ?=

all: wasm-modules $(FONT_HEADER) $(FONT_BAKED_HEADER) $(EFI_OUT) $(EFI_BOOT)

os:
	$(MAKE) rebuild-image ER_BOOT_PROFILE=4

rebuild-image:
	rm -f $(OBJS) $(UI_OBJS) $(VARFONT_OBJS) $(CRYPTO_OBJS) $(CRYPTO_ASM_OBJS) $(EFI_OUT) $(EFI_BOOT)
	$(MAKE) all ER_BOOT_PROFILE=$(ER_BOOT_PROFILE)

netboot: $(NETBOOT_BIN) $(PXE4011_BIN)

check: os test-core qemu-config-check

test-core: $(CORE_TEST_BIN)
	./$(CORE_TEST_BIN)

wasm-modules: $(WASM_MODULE_HEADERS)

$(EMBED_HEADER_BIN): $(EMBED_HEADER_SRC)
	mkdir -p $(dir $@)
	$(CCACHE_PREFIX) $(HOST_CC) $(HOST_CFLAGS) $(HOST_LDFLAGS) -o $@ $<

$(GENERATED_DIR)/driver_bus_probe.wasm: modules/driver_bus_probe/driver_bus_probe.wat
	mkdir -p $(dir $@)
	wat2wasm $< -o $@

$(GENERATED_DIR)/ui_counter.wasm: modules/ui_counter/ui_counter.wat
	mkdir -p $(dir $@)
	wat2wasm $< -o $@

core/wasm_driver_bus_probe_module.h: $(GENERATED_DIR)/driver_bus_probe.wasm $(EMBED_HEADER_BIN)
	$(EMBED_HEADER_BIN) wasm $< $@ WASM_DRIVER_BUS_PROBE_MODULE_H g_edgerun_driver_bus_probe_wasm ER_DRIVER_BUS_PROBE_WASM_SIZE modules/driver_bus_probe/driver_bus_probe.wat

core/wasm_ui_counter_module.h: $(GENERATED_DIR)/ui_counter.wasm $(EMBED_HEADER_BIN)
	$(EMBED_HEADER_BIN) wasm $< $@ WASM_UI_COUNTER_MODULE_H g_edgerun_ui_counter_wasm ER_UI_COUNTER_WASM_SIZE modules/ui_counter/ui_counter.wat

$(FONT_HEADER): $(FONT_SOURCE) $(EMBED_HEADER_BIN)
	mkdir -p $(dir $@)
	$(EMBED_HEADER_BIN) binary "$<" "$@" ER_FONT_GEIST_H g_er_font_geist_ttf ER_FONT_GEIST_TTF_SIZE

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

$(BUILD_DIR)/crypto/%.o: $(CRYPTO_DIR)/../third_party/blake3/c/%.S
	mkdir -p $(dir $@)
	$(CCACHE_PREFIX) $(CC) $(CFLAGS) -c $< -o $@

$(EFI_OUT): $(OBJS) $(UI_OBJS) $(VARFONT_OBJS) $(CRYPTO_OBJS) $(CRYPTO_ASM_OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^

$(NETBOOT_BIN): $(NETBOOT_SRC)
	mkdir -p $(dir $@)
	$(CCACHE_PREFIX) $(HOST_CC) $(HOST_CFLAGS) $(HOST_LDFLAGS) -o $@ $<

$(PXE4011_BIN): $(PXE4011_SRC)
	mkdir -p $(dir $@)
	$(CCACHE_PREFIX) $(HOST_CC) $(HOST_CFLAGS) $(HOST_LDFLAGS) -o $@ $<

$(QEMU_RUN_BIN): $(QEMU_RUN_SRC)
	mkdir -p $(dir $@)
	$(CCACHE_PREFIX) $(HOST_CC) $(HOST_CFLAGS) $(HOST_LDFLAGS) -o $@ $<

$(CORE_TEST_BIN): $(CORE_TEST_SRC) $(HDRS) $(UI_HDRS) $(VARFONT_HDRS) $(CRYPTO_HDRS) $(WASM_MODULE_HEADERS) $(FONT_HEADER)
	mkdir -p $(dir $@)
	$(CCACHE_PREFIX) $(HOST_CC) $(HOST_CFLAGS) $(HOST_LDFLAGS) -o $@ $(CORE_TEST_SRC)

$(EFI_BOOT): $(EFI_OUT)
	mkdir -p $(dir $@)
	cp $< $@

run: $(EFI_BOOT) $(QEMU_RUN_BIN) $(QEMU_CONFIG)
	./$(QEMU_RUN_BIN) $(QEMU_CONFIG) $(abspath $(ESP_DIR))

qemu-config-check: $(EFI_BOOT) $(QEMU_RUN_BIN) $(QEMU_CONFIG)
	./$(QEMU_RUN_BIN) --check $(QEMU_CONFIG) $(abspath $(ESP_DIR))

clean:
	rm -rf $(BUILD_DIR)

print-path:
	@printf '%s\n' "$(abspath $(EFI_BOOT))"
