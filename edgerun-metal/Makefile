.PHONY: all run run-aarch64 qemu-aarch64-smoke qemu-ephemeral-authority qemu-ephemeral-authority-smoke qemu-swtpm-persistence clean print-path print-config netboot os rebuild-image check test-core bench-ui-dirty tpm-real-bench-uefi wifi-hardware-probe wasm-modules qemu-config-check qemu-aarch64-config-check qemu-swtpm-persistence-config-check pi-zero-2w-uefi pi-zero-2w-boot pi-zero-w-v1_1-kernel pi-zero-w-v1_1-boot

CC := clang
HOST_CC := clang
AR := llvm-ar

ER_METAL_ARCH := x86_64
ER_METAL_BOARD := uefi-generic
BUILD_DIR := ../.build/edgerun-metal
ESP_DIR := $(BUILD_DIR)/esp
EFI_OUT := $(BUILD_DIR)/edgerun-metal.efi
UI_CORE_DIR := ../edgerun-ui-core
VARFONT_DIR := ../edgerun-ui-core/varfont
CRYPTO_DIR := ../edgerun-crypto
GENERATED_DIR := $(BUILD_DIR)/generated
PI_ZERO2W_DEVICE_DIR := devices/pi_zero2w
BCM2708_USB_BOOT_DEVICE_DIR := devices/bcm2708_usb_boot
PI_USB_CONTROL_DEVICE_DIR := devices/pi_usb_control
CYW43438_DEVICE_DIR := devices/cyw43438
IWLWIFI_DEVICE_DIR := devices/iwlwifi
MT7922_DEVICE_DIR := devices/mt7922
RTW89_DEVICE_DIR := devices/rtw89
VIRTIO_DEVICE_DIR := devices/virtio
PS2_KEYBOARD_DEVICE_DIR := devices/ps2_keyboard
PI_ZERO_W_V1_1_DEVICE_DIR := devices/pi_zero_w_v1_1
DEVICE_INCLUDE_DIRS := $(PI_ZERO2W_DEVICE_DIR) $(BCM2708_USB_BOOT_DEVICE_DIR) $(PI_USB_CONTROL_DEVICE_DIR) $(CYW43438_DEVICE_DIR) $(IWLWIFI_DEVICE_DIR) $(MT7922_DEVICE_DIR) $(RTW89_DEVICE_DIR) $(VIRTIO_DEVICE_DIR) $(PS2_KEYBOARD_DEVICE_DIR)
DEVICE_INCLUDE_FLAGS := $(foreach dir,$(DEVICE_INCLUDE_DIRS),-I$(CURDIR)/$(dir))

# ER_BOOT_PROFILE=4 selects the OS path: VirtIO GPU UI runtime, Wasm apps, PS/2 input,
# storage-bound package loading, and relay/device endpoint work.
ER_BOOT_PROFILE := 4
ER_BOOT_EPHEMERAL_AUTHORITY_ENABLED := 0
ER_TPM_REAL_BENCH_ENABLED := 0

ifeq ($(ER_METAL_ARCH),x86_64)
ER_METAL_TARGET := x86_64-pc-windows-msvc
ER_METAL_BOOT_EFI := BOOTX64.EFI
ER_METAL_ARCH_CFLAGS := -mno-red-zone -DER_TARGET_X86_64=1
ER_METAL_CRYPTO_DEFS := -DER_BLAKE3_USE_UPSTREAM_ASM=1
CRYPTO_ASM_SRCS := $(CRYPTO_DIR)/../third_party/blake3/c/blake3_sse2_x86-64_windows_gnu.S
else ifeq ($(ER_METAL_ARCH),aarch64)
ER_METAL_TARGET := aarch64-unknown-windows-msvc
ER_METAL_BOOT_EFI := BOOTAA64.EFI
ER_METAL_ARCH_CFLAGS := -DER_TARGET_AARCH64=1
ER_METAL_CRYPTO_DEFS :=
CRYPTO_ASM_SRCS :=
else ifeq ($(ER_METAL_ARCH),armv6)
ER_METAL_TARGET := armv6-none-eabi
ER_METAL_BOOT_EFI := kernel.img
ER_METAL_ARCH_CFLAGS := -DER_TARGET_ARMV6=1
ER_METAL_CRYPTO_DEFS :=
CRYPTO_ASM_SRCS :=
else
$(error unsupported ER_METAL_ARCH '$(ER_METAL_ARCH)')
endif

ifeq ($(ER_METAL_BOARD),uefi-generic)
ER_METAL_BOARD_BOOT_CHAIN := firmware -> BOOT$(if $(filter x86_64,$(ER_METAL_ARCH)),X64,AA64).EFI
ER_METAL_BOARD_CFLAGS := -DER_BOARD_UEFI_GENERIC=1
else ifeq ($(ER_METAL_BOARD),pi-zero-2w)
ifneq ($(ER_METAL_ARCH),aarch64)
$(error ER_METAL_BOARD=pi-zero-2w requires ER_METAL_ARCH=aarch64)
endif
ER_METAL_BOARD_BOOT_CHAIN := raspberry-pi-firmware -> u-boot-efi -> BOOTAA64.EFI
ER_METAL_BOARD_CFLAGS := -DER_BOARD_PI_ZERO_2W=1
else ifeq ($(ER_METAL_BOARD),pi-zero-w-v1_1)
ifneq ($(ER_METAL_ARCH),armv6)
$(error ER_METAL_BOARD=pi-zero-w-v1_1 requires ER_METAL_ARCH=armv6)
endif
ER_METAL_BOARD_BOOT_CHAIN := raspberry-pi-firmware -> kernel.img
ER_METAL_BOARD_CFLAGS := -DER_BOARD_PI_ZERO_W_V1_1=1
else
$(error unsupported ER_METAL_BOARD '$(ER_METAL_BOARD)')
endif

EFI_BOOT := $(ESP_DIR)/EFI/BOOT/$(ER_METAL_BOOT_EFI)
CFLAGS := -std=c11 -Wall -Werror -ffreestanding -fshort-wchar -fno-builtin -fno-stack-protector -fuse-ld=lld -target $(ER_METAL_TARGET) $(ER_METAL_ARCH_CFLAGS) \
          $(ER_METAL_BOARD_CFLAGS) -I$(CURDIR)/core $(DEVICE_INCLUDE_FLAGS) -I$(CURDIR) -I$(CURDIR)/../include -I$(CURDIR)/$(GENERATED_DIR) -I$(CURDIR)/$(CRYPTO_DIR)/include -I$(CURDIR)/$(UI_CORE_DIR)/include -I$(CURDIR)/$(VARFONT_DIR)/include -DER_BOOT_PROFILE=$(ER_BOOT_PROFILE) -DER_BOOT_EPHEMERAL_AUTHORITY_ENABLED=$(ER_BOOT_EPHEMERAL_AUTHORITY_ENABLED) -DER_TPM_REAL_BENCH_ENABLED=$(ER_TPM_REAL_BENCH_ENABLED)
CRYPTO_CFLAGS := $(CFLAGS) -O3 $(ER_METAL_CRYPTO_DEFS)
LDFLAGS := -nostdlib -Wl,/SUBSYSTEM:EFI_APPLICATION,/ENTRY:efi_main
HOST_CFLAGS := -std=c11 -Wall -Wextra -Werror -O2 -DER_ENABLE_TEST_HOOKS=1 -I$(CURDIR)/core $(DEVICE_INCLUDE_FLAGS) -I$(CURDIR)/../include -I$(CURDIR)/$(GENERATED_DIR) -I$(CURDIR)/$(CRYPTO_DIR)/include -I$(CURDIR)/$(UI_CORE_DIR)/include -I$(CURDIR)/$(VARFONT_DIR)/include
HOST_LDFLAGS :=

ER_TPM_SRCS := core/er_tpm.c core/er_tls_tpm.c core/er_tls.c
CORE_SRCS := core/efi_main.c core/efi_boot_memory.c core/efi_boot_diagnostics.c core/efi_boot_gpu.c core/efi_boot_routes.c core/efi_boot_wasm.c core/efi_boot_input.c core/efi_boot_render.c core/efi_boot_render_state.c core/efi_boot_relay.c core/efi_boot_os.c core/er_boot_admission_record.c core/er_boot_efi_vars.c core/er_boot_config.c core/er_boot_profile.c core/er_boot_services.c core/er_print.c core/er_gfx_console.c core/er_ui_gop_renderer.c core/er_ui_frame_timing.c core/er_ui_wasm_app.c core/er_epoch_clock.c core/er_ephemeral_node.c core/er_freestanding.c core/er_netlog.c core/er_crypto.c core/er_crypto_blake3.c core/er_mem.c core/er_vfs.c core/er_app.c core/er_identity.c core/er_node_control.c core/er_device_identity.c core/er_driver_event.c core/er_driver_policy.c core/er_jurisdiction.c core/er_work_route.c core/er_render_endpoint.c core/er_storage_endpoint.c core/er_seal.c core/er_hw_relay.c core/er_relay_packet.c core/er_ble_adv.c core/er_wifi_burst.c core/er_wifi_l2.c core/er_ieee80211_ap.c core/er_network.c core/er_bus.c core/er_acpi.c core/er_tpm_acpi.c core/er_tpm_bench.c core/erwire.c core/er_native_boot.c core/wasm_vm.c core/wasm_vm_reader.c core/wasm_vm_memory_ui.c core/wasm_vm_contract.c core/wasm_vm_hostcall.c core/wasm_vm_execute.c core/er_pci.c core/er_firmware_loader.c core/er_mmio.c core/er_net_frame.c core/er_native_eth.c
DEVICE_SRCS := $(CYW43438_DEVICE_DIR)/er_cyw43438.c $(BCM2708_USB_BOOT_DEVICE_DIR)/er_bcm2708_usb_boot.c $(PI_USB_CONTROL_DEVICE_DIR)/er_pi_usb_control.c $(PS2_KEYBOARD_DEVICE_DIR)/er_ps2_keyboard.c $(PI_ZERO2W_DEVICE_DIR)/er_pi_zero2w.c $(RTW89_DEVICE_DIR)/er_rtw89.c $(MT7922_DEVICE_DIR)/er_mt7922.c $(IWLWIFI_DEVICE_DIR)/er_iwlwifi.c $(VIRTIO_DEVICE_DIR)/er_virtio.c $(VIRTIO_DEVICE_DIR)/er_virtio_blk.c $(VIRTIO_DEVICE_DIR)/er_virtio_net.c $(VIRTIO_DEVICE_DIR)/er_virtio_gpu.c
SRCS := $(CORE_SRCS) $(DEVICE_SRCS)
UI_SRCS := $(UI_CORE_DIR)/src/er_ui_assets.c $(UI_CORE_DIR)/src/er_ui_components_catalog.c $(UI_CORE_DIR)/src/er_ui_components_catalog_data.c $(UI_CORE_DIR)/src/er_ui_components_contracts.c $(UI_CORE_DIR)/src/er_ui_components_emit.c $(UI_CORE_DIR)/src/er_ui_components_internal.c $(UI_CORE_DIR)/src/er_ui_components_preview.c $(UI_CORE_DIR)/src/er_ui_components_state.c $(UI_CORE_DIR)/src/er_ui_icon.c $(UI_CORE_DIR)/src/er_ui_initial_setup.c $(UI_CORE_DIR)/src/er_ui_ledger_app.c $(UI_CORE_DIR)/src/er_ui_metal.c $(UI_CORE_DIR)/src/er_ui_node.c $(UI_CORE_DIR)/src/er_ui_node_accessibility.c $(UI_CORE_DIR)/src/er_ui_node_layout.c $(UI_CORE_DIR)/src/er_ui_node_render.c $(UI_CORE_DIR)/src/er_ui_node_render_controls.c $(UI_CORE_DIR)/src/er_ui_node_render_conversation.c $(UI_CORE_DIR)/src/er_ui_node_render_panels.c $(UI_CORE_DIR)/src/er_ui_painter.c $(UI_CORE_DIR)/src/er_ui_primitives.c $(UI_CORE_DIR)/src/er_ui_preset_code.c $(UI_CORE_DIR)/src/er_ui_record_codec.c $(UI_CORE_DIR)/src/er_ui_runtime_focus.c $(UI_CORE_DIR)/src/er_ui_runtime_input.c $(UI_CORE_DIR)/src/er_ui_runtime_internal.c $(UI_CORE_DIR)/src/er_ui_runtime_state.c $(UI_CORE_DIR)/src/er_ui_runtime_text.c $(UI_CORE_DIR)/src/er_ui_scene.c $(UI_CORE_DIR)/src/er_ui_shell.c $(UI_CORE_DIR)/src/er_ui_spacing.c $(UI_CORE_DIR)/src/er_ui_theme.c $(UI_CORE_DIR)/src/er_ui_text.c
VARFONT_SRCS := $(VARFONT_DIR)/src/vr_font.c $(VARFONT_DIR)/src/vr_font_utils.c $(VARFONT_DIR)/src/vr_font_axes.c $(VARFONT_DIR)/src/vr_font_cmap.c $(VARFONT_DIR)/src/vr_font_gvar.c $(VARFONT_DIR)/src/vr_font_gvar_apply.c $(VARFONT_DIR)/src/vr_font_kern.c $(VARFONT_DIR)/src/vr_font_tables.c $(VARFONT_DIR)/src/vr_font_shape.c $(VARFONT_DIR)/src/vr_font_raster.c $(VARFONT_DIR)/src/vr_font_raster_geometry.c $(VARFONT_DIR)/src/vr_font_raster_glyph.c $(VARFONT_DIR)/src/vr_font_raster_msdf.c $(VARFONT_DIR)/src/vr_font_raster_outline.c $(VARFONT_DIR)/src/vr_font_raster_storage.c $(VARFONT_DIR)/src/vr_font_atlas.c
CRYPTO_SRCS := $(CRYPTO_DIR)/src/er_blake3.c
OBJS := $(patsubst %.c,$(BUILD_DIR)/%.o,$(SRCS))
ER_TPM_OBJS := $(patsubst %.c,$(BUILD_DIR)/%.o,$(ER_TPM_SRCS))
ER_TPM_LIB := $(BUILD_DIR)/liber_tpm.a
UI_OBJS := $(patsubst $(UI_CORE_DIR)/src/%.c,$(BUILD_DIR)/ui-core/%.o,$(UI_SRCS))
VARFONT_OBJS := $(patsubst $(VARFONT_DIR)/src/%.c,$(BUILD_DIR)/edgerun-ui-core/varfont/%.o,$(VARFONT_SRCS))
CRYPTO_OBJS := $(patsubst $(CRYPTO_DIR)/src/%.c,$(BUILD_DIR)/crypto/%.o,$(CRYPTO_SRCS))
CRYPTO_ASM_OBJS := $(patsubst $(CRYPTO_DIR)/../third_party/blake3/c/%.S,$(BUILD_DIR)/crypto/%.o,$(CRYPTO_ASM_SRCS))
DEVICE_HDRS := $(foreach dir,$(DEVICE_INCLUDE_DIRS),$(wildcard $(dir)/*.h))
HDRS := $(wildcard core/*.h) $(DEVICE_HDRS)
UI_HDRS := $(wildcard $(UI_CORE_DIR)/include/*.h)
VARFONT_HDRS := $(wildcard $(VARFONT_DIR)/include/*.h) $(wildcard $(VARFONT_DIR)/src/*.h)
CRYPTO_HDRS := $(wildcard $(CRYPTO_DIR)/include/*.h)
EMBED_HEADER_SRC := ../tools/embed-header/main.c
EMBED_HEADER_BIN := $(BUILD_DIR)/embed-header
ER_BUILD_BIN := ../.build/er-build
WASM_COMPILE_SRCS := ../tools/wasm-compile/main.c ../tools/wasm-compile/wasm_compile_c.c ../tools/wasm-compile/wasm_compile_common.c ../tools/wasm-compile/wasm_compile_contract.c ../tools/wasm-compile/wasm_compile_emit.c ../tools/wasm-compile/wasm_compile_io.c ../tools/wasm-compile/wasm_compile_module.c ../tools/wasm-compile/wasm_compile_parse.c
WASM_COMPILE_HDRS := ../tools/wasm-compile/wasm_compile.h
WASM_COMPILE_BIN := $(BUILD_DIR)/wasm-compile
WASM_MODULE_HEADERS := $(GENERATED_DIR)/wasm_driver_bus_probe_module.h $(GENERATED_DIR)/wasm_ui_counter_module.h \
                       $(GENERATED_DIR)/wasm_user_app_module.h $(GENERATED_DIR)/app_user_manifest.h \
                       $(GENERATED_DIR)/wasm_c_hostcall_bus_exec_module.h \
                       $(GENERATED_DIR)/wasm_c_hostcall_region_base_module.h \
                       $(GENERATED_DIR)/wasm_c_hostcall_region_len_module.h \
                       $(GENERATED_DIR)/wasm_c_hostcall_ui_emit_module.h
DRIVER_BUS_PROBE_SOURCE := modules/driver_bus_probe/app/app.c
DRIVER_BUS_PROBE_MANIFEST := modules/driver_bus_probe/app/app.manifest
USER_APP_PACKAGE_DIR := ../tests/fixtures/app-package/app
USER_APP_SOURCE := $(USER_APP_PACKAGE_DIR)/app.c
USER_APP_MANIFEST := $(USER_APP_PACKAGE_DIR)/app.manifest
USER_APP_PACKAGE_WASM := $(USER_APP_PACKAGE_DIR)/.build/app.wasm
USER_APP_PACKAGE_IDENTITY := $(USER_APP_PACKAGE_DIR)/.build/package.identity
FONT_HEADER := $(GENERATED_DIR)/font_geist.h
FONT_BAKED_HEADER := $(GENERATED_DIR)/font_geist_baked.h
FONT_SOURCE := $(VARFONT_DIR)/fonts/Geist[wght].ttf
FONT_BAKE_SRC := ../tools/font-bake/main.c
FONT_BAKE_BIN := $(BUILD_DIR)/font-bake
NETBOOT_SRC := ../tools/edgerun-netboot/main.c
NETBOOT_BIN := $(BUILD_DIR)/edgerun-netboot
PXE4011_SRC := ../tools/edgerun-pxe4011/main.c
PXE4011_BIN := $(BUILD_DIR)/edgerun-pxe4011
QEMU_RUN_SRC := ../tools/qemu-run/main.c
QEMU_RUN_BIN := $(BUILD_DIR)/edgerun-qemu-run
WIFI_HW_PROBE_SRC := ../tools/wifi-hardware-probe/main.c
WIFI_HW_PROBE_BIN := $(BUILD_DIR)/wifi-hardware-probe
QEMU_CONFIG := qemu.conf
QEMU_AARCH64_CONFIG := qemu-aarch64.conf
QEMU_AARCH64_SMOKE_CONFIG := qemu-aarch64-smoke.conf
QEMU_AARCH64_BUILD_DIR := $(BUILD_DIR)/aarch64
QEMU_AARCH64_SMOKE_LOG := $(QEMU_AARCH64_BUILD_DIR)/qemu-aarch64-smoke.log
QEMU_AARCH64_SMOKE_TIMEOUT := 30
QEMU_AARCH64_SMOKE_READY := boot services: fatal action=halt
PI_ZERO_2W_BUILD_DIR := ../.build/edgerun-metal/pi-zero-2w
PI_ZERO_2W_EFI_BOOT := $(PI_ZERO_2W_BUILD_DIR)/esp/EFI/BOOT/BOOTAA64.EFI
PI_ZERO_2W_BOOT_DIR := $(PI_ZERO_2W_BUILD_DIR)/boot
PI_ZERO_W_V1_1_BUILD_DIR := ../.build/edgerun-metal/pi-zero-w-v1_1
PI_ZERO_W_V1_1_ENTRY_SRC := $(PI_ZERO_W_V1_1_DEVICE_DIR)/pi_zero_w_v1_1_entry.c
PI_ZERO_W_V1_1_START_SRC := $(PI_ZERO_W_V1_1_DEVICE_DIR)/pi_zero_w_v1_1_start.c
PI_ZERO_W_V1_1_DEVICE_HDRS := $(wildcard $(PI_ZERO_W_V1_1_DEVICE_DIR)/*.h)
PI_ZERO_W_V1_1_CYW43438_HDRS := devices/cyw43438/er_cyw43438_owned_firmware.h
PI_ZERO_W_V1_1_KERNEL := $(PI_ZERO_W_V1_1_BUILD_DIR)/kernel.img
PI_ZERO_W_V1_1_BOOT_DIR := $(PI_ZERO_W_V1_1_BUILD_DIR)/boot
PI_BOOT_STAGE_SRC := ../tools/pi-boot-stage/main.c
PI_BOOT_STAGE_BIN := ../.build/edgerun-metal/pi-boot-stage
QEMU_SMOKE_SRC := ../tools/qemu-smoke.sh
QEMU_SWTPM_PERSIST_CONFIG := qemu-swtpm-persistence.conf
QEMU_SWTPM_PERSIST_SCRIPT := ../tools/qemu-swtpm-persistence.sh
QEMU_SWTPM_PERSIST_DIR := $(BUILD_DIR)/qemu-swtpm-persistence
QEMU_SWTPM_PERSIST_TIMEOUT := 30
QEMU_EPHEMERAL_AUTHORITY_BUILD_DIR := ../.build/edgerun-metal-ephemeral-authority
QEMU_EPHEMERAL_AUTHORITY_LOG := $(QEMU_EPHEMERAL_AUTHORITY_BUILD_DIR)/qemu-ephemeral-authority.log
QEMU_EPHEMERAL_AUTHORITY_TIMEOUT := 30
QEMU_EPHEMERAL_AUTHORITY_READY := ui renderer: wasm app scene rects=1 hits=1 text=1
CORE_TEST_DEVICE_SRCS := $(RTW89_DEVICE_DIR)/er_rtw89.c $(MT7922_DEVICE_DIR)/er_mt7922.c $(IWLWIFI_DEVICE_DIR)/er_iwlwifi.c $(CYW43438_DEVICE_DIR)/er_cyw43438.c $(PI_USB_CONTROL_DEVICE_DIR)/er_pi_usb_control.c $(PS2_KEYBOARD_DEVICE_DIR)/er_ps2_keyboard.c $(PI_ZERO2W_DEVICE_DIR)/er_pi_zero2w.c $(VIRTIO_DEVICE_DIR)/er_virtio.c $(VIRTIO_DEVICE_DIR)/er_virtio_blk.c $(VIRTIO_DEVICE_DIR)/er_virtio_net.c $(VIRTIO_DEVICE_DIR)/er_virtio_gpu.c
CORE_TEST_SRC := tests/test_core.c core/efi_boot_memory.c core/efi_boot_relay.c core/efi_boot_routes.c core/efi_boot_wasm.c core/efi_boot_input.c core/efi_boot_render_state.c core/er_boot_admission_record.c core/er_boot_efi_vars.c core/er_boot_config.c core/er_boot_profile.c core/er_boot_services.c core/er_pci.c core/er_firmware_loader.c core/er_mmio.c core/er_crypto.c core/er_crypto_blake3.c $(CRYPTO_SRCS) core/er_mem.c core/er_vfs.c core/er_app.c core/er_identity.c core/er_node_control.c core/er_device_identity.c core/er_driver_event.c core/er_driver_policy.c core/er_jurisdiction.c core/er_work_route.c core/er_render_endpoint.c core/er_storage_endpoint.c core/er_seal.c $(ER_TPM_SRCS) core/er_hw_relay.c core/er_relay_packet.c core/er_ble_adv.c core/er_wifi_burst.c core/er_wifi_l2.c core/er_ieee80211_ap.c core/er_ephemeral_node.c core/er_network.c core/er_bus.c core/er_acpi.c core/er_tpm_acpi.c core/er_print.c core/er_netlog.c core/er_gfx_console.c core/er_ui_gop_renderer.c core/er_ui_frame_timing.c core/er_ui_wasm_app.c core/er_epoch_clock.c core/erwire.c core/er_native_boot.c core/wasm_vm.c core/wasm_vm_reader.c core/wasm_vm_memory_ui.c core/wasm_vm_contract.c core/wasm_vm_hostcall.c core/wasm_vm_execute.c core/er_net_frame.c core/er_native_eth.c $(CORE_TEST_DEVICE_SRCS) $(UI_SRCS) $(VARFONT_SRCS)
CORE_TEST_FRAGMENT_SRCS := $(wildcard tests/test_core_*.c)
CORE_TEST_BIN := $(BUILD_DIR)/test-core
UI_DIRTY_BENCH_SRC := tools/bench_ui_dirty.c core/efi_boot_render_state.c core/er_mem.c core/er_ui_gop_renderer.c core/er_epoch_clock.c $(UI_CORE_DIR)/src/er_ui_icon.c $(UI_CORE_DIR)/src/er_ui_primitives.c $(UI_CORE_DIR)/src/er_ui_scene.c $(UI_CORE_DIR)/src/er_ui_text.c $(VARFONT_SRCS)
UI_DIRTY_BENCH_BIN := $(BUILD_DIR)/bench-ui-dirty
IFACE :=

all: wasm-modules $(FONT_HEADER) $(FONT_BAKED_HEADER) $(EFI_OUT) $(EFI_BOOT)

os:
	$(MAKE) rebuild-image ER_BOOT_PROFILE=4

rebuild-image:
	rm -f $(OBJS) $(ER_TPM_OBJS) $(ER_TPM_LIB) $(UI_OBJS) $(VARFONT_OBJS) $(CRYPTO_OBJS) $(CRYPTO_ASM_OBJS) $(EFI_OUT) $(EFI_BOOT)
	$(MAKE) all ER_BOOT_PROFILE=$(ER_BOOT_PROFILE)

netboot: $(NETBOOT_BIN) $(PXE4011_BIN)

check: os test-core qemu-config-check

test-core: $(CORE_TEST_BIN)
	./$(CORE_TEST_BIN)

bench-ui-dirty: $(UI_DIRTY_BENCH_BIN)
	./$(UI_DIRTY_BENCH_BIN)

tpm-real-bench-uefi:
	$(MAKE) rebuild-image ER_TPM_REAL_BENCH_ENABLED=1

wifi-hardware-probe: $(WIFI_HW_PROBE_BIN)
	./$(WIFI_HW_PROBE_BIN)

wasm-modules: $(WASM_MODULE_HEADERS)

$(EMBED_HEADER_BIN): $(EMBED_HEADER_SRC)
	mkdir -p $(dir $@)
	$(HOST_CC) $(HOST_CFLAGS) $(HOST_LDFLAGS) -o $@ $<

$(WASM_COMPILE_BIN): $(WASM_COMPILE_SRCS) $(WASM_COMPILE_HDRS)
	mkdir -p $(dir $@)
	$(HOST_CC) $(HOST_CFLAGS) $(HOST_LDFLAGS) -o $@ $(WASM_COMPILE_SRCS)

$(ER_BUILD_BIN): ../tools/er-build/main.c ../tools/er-build/package_identity.c ../tools/er-build/package_identity.h ../edgerun-crypto/src/er_blake3.c ../edgerun-crypto/include/er_blake3.h
	$(MAKE) -C .. er-build

$(USER_APP_PACKAGE_WASM) $(USER_APP_PACKAGE_IDENTITY): $(USER_APP_SOURCE) $(USER_APP_MANIFEST) $(ER_BUILD_BIN)
	cd .. && ./.build/er-build app-build tests/fixtures/app-package/app
	cd .. && ./.build/er-build app-verify tests/fixtures/app-package/app

$(GENERATED_DIR)/driver_bus_probe.wasm: $(DRIVER_BUS_PROBE_SOURCE) $(DRIVER_BUS_PROBE_MANIFEST) $(WASM_COMPILE_BIN)
	mkdir -p $(dir $@)
	$(WASM_COMPILE_BIN) $< $@

$(GENERATED_DIR)/ui_counter.wasm: modules/ui_counter/ui_counter.wat $(WASM_COMPILE_BIN)
	mkdir -p $(dir $@)
	$(WASM_COMPILE_BIN) $< $@

$(GENERATED_DIR)/user_app.wasm: $(USER_APP_PACKAGE_WASM) $(USER_APP_PACKAGE_IDENTITY)
	mkdir -p $(dir $@)
	cp $(USER_APP_PACKAGE_WASM) $@

$(GENERATED_DIR)/c_hostcall_bus_exec.wasm: modules/c_hostcall_bus_exec/c_hostcall_bus_exec.c $(WASM_COMPILE_BIN)
	mkdir -p $(dir $@)
	$(WASM_COMPILE_BIN) $< $@

$(GENERATED_DIR)/c_hostcall_region_base.wasm: modules/c_hostcall_region_base/c_hostcall_region_base.c $(WASM_COMPILE_BIN)
	mkdir -p $(dir $@)
	$(WASM_COMPILE_BIN) $< $@

$(GENERATED_DIR)/c_hostcall_region_len.wasm: modules/c_hostcall_region_len/c_hostcall_region_len.c $(WASM_COMPILE_BIN)
	mkdir -p $(dir $@)
	$(WASM_COMPILE_BIN) $< $@

$(GENERATED_DIR)/c_hostcall_ui_emit.wasm: modules/c_hostcall_ui_emit/c_hostcall_ui_emit.c $(WASM_COMPILE_BIN)
	mkdir -p $(dir $@)
	$(WASM_COMPILE_BIN) $< $@

$(GENERATED_DIR)/wasm_driver_bus_probe_module.h: $(GENERATED_DIR)/driver_bus_probe.wasm $(EMBED_HEADER_BIN)
	$(EMBED_HEADER_BIN) wasm $< $@ WASM_DRIVER_BUS_PROBE_MODULE_H g_edgerun_driver_bus_probe_wasm ER_DRIVER_BUS_PROBE_WASM_SIZE $(DRIVER_BUS_PROBE_SOURCE)

$(GENERATED_DIR)/wasm_ui_counter_module.h: $(GENERATED_DIR)/ui_counter.wasm $(EMBED_HEADER_BIN)
	$(EMBED_HEADER_BIN) wasm $< $@ WASM_UI_COUNTER_MODULE_H g_edgerun_ui_counter_wasm ER_UI_COUNTER_WASM_SIZE modules/ui_counter/ui_counter.wat

$(GENERATED_DIR)/wasm_user_app_module.h: $(GENERATED_DIR)/user_app.wasm $(EMBED_HEADER_BIN)
	$(EMBED_HEADER_BIN) wasm $< $@ WASM_USER_APP_MODULE_H g_edgerun_user_app_wasm ER_USER_APP_WASM_SIZE $(USER_APP_SOURCE)

$(GENERATED_DIR)/app_user_manifest.h: $(USER_APP_MANIFEST) $(EMBED_HEADER_BIN)
	$(EMBED_HEADER_BIN) binary $< $@ APP_USER_MANIFEST_H g_edgerun_user_app_manifest ER_USER_APP_MANIFEST_SIZE

$(GENERATED_DIR)/wasm_c_hostcall_bus_exec_module.h: $(GENERATED_DIR)/c_hostcall_bus_exec.wasm $(EMBED_HEADER_BIN)
	$(EMBED_HEADER_BIN) wasm $< $@ WASM_C_HOSTCALL_BUS_EXEC_MODULE_H g_edgerun_c_hostcall_bus_exec_wasm ER_C_HOSTCALL_BUS_EXEC_WASM_SIZE modules/c_hostcall_bus_exec/c_hostcall_bus_exec.c

$(GENERATED_DIR)/wasm_c_hostcall_region_base_module.h: $(GENERATED_DIR)/c_hostcall_region_base.wasm $(EMBED_HEADER_BIN)
	$(EMBED_HEADER_BIN) wasm $< $@ WASM_C_HOSTCALL_REGION_BASE_MODULE_H g_edgerun_c_hostcall_region_base_wasm ER_C_HOSTCALL_REGION_BASE_WASM_SIZE modules/c_hostcall_region_base/c_hostcall_region_base.c

$(GENERATED_DIR)/wasm_c_hostcall_region_len_module.h: $(GENERATED_DIR)/c_hostcall_region_len.wasm $(EMBED_HEADER_BIN)
	$(EMBED_HEADER_BIN) wasm $< $@ WASM_C_HOSTCALL_REGION_LEN_MODULE_H g_edgerun_c_hostcall_region_len_wasm ER_C_HOSTCALL_REGION_LEN_WASM_SIZE modules/c_hostcall_region_len/c_hostcall_region_len.c

$(GENERATED_DIR)/wasm_c_hostcall_ui_emit_module.h: $(GENERATED_DIR)/c_hostcall_ui_emit.wasm $(EMBED_HEADER_BIN)
	$(EMBED_HEADER_BIN) wasm $< $@ WASM_C_HOSTCALL_UI_EMIT_MODULE_H g_edgerun_c_hostcall_ui_emit_wasm ER_C_HOSTCALL_UI_EMIT_WASM_SIZE modules/c_hostcall_ui_emit/c_hostcall_ui_emit.c

$(FONT_HEADER): $(FONT_SOURCE) $(EMBED_HEADER_BIN)
	mkdir -p $(dir $@)
	$(EMBED_HEADER_BIN) binary "$<" "$@" ER_FONT_GEIST_H g_er_font_geist_ttf ER_FONT_GEIST_TTF_SIZE

$(FONT_BAKE_BIN): $(FONT_BAKE_SRC) $(VARFONT_SRCS) $(VARFONT_HDRS)
	mkdir -p $(dir $@)
	$(HOST_CC) $(HOST_CFLAGS) -I$(CURDIR)/$(VARFONT_DIR)/src $(HOST_LDFLAGS) -o $@ $(FONT_BAKE_SRC) $(VARFONT_SRCS)

$(FONT_BAKED_HEADER): $(FONT_SOURCE) $(FONT_BAKE_BIN)
	$(FONT_BAKE_BIN) "$<" "$@"

$(BUILD_DIR)/%.o: %.c $(HDRS) $(UI_HDRS) $(VARFONT_HDRS) $(CRYPTO_HDRS) $(WASM_MODULE_HEADERS) $(FONT_HEADER) $(FONT_BAKED_HEADER)
	mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/ui-core/%.o: $(UI_CORE_DIR)/src/%.c $(UI_HDRS) $(VARFONT_HDRS)
	mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/edgerun-ui-core/varfont/%.o: $(VARFONT_DIR)/src/%.c $(VARFONT_HDRS)
	mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/crypto/%.o: $(CRYPTO_DIR)/src/%.c $(CRYPTO_HDRS)
	mkdir -p $(dir $@)
	$(CC) $(CRYPTO_CFLAGS) -c $< -o $@

$(BUILD_DIR)/crypto/%.o: $(CRYPTO_DIR)/../third_party/blake3/c/%.S
	mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(ER_TPM_LIB): $(ER_TPM_OBJS)
	mkdir -p $(dir $@)
	rm -f $@
	$(AR) rcs $@ $^

$(EFI_OUT): $(OBJS) $(ER_TPM_LIB) $(UI_OBJS) $(VARFONT_OBJS) $(CRYPTO_OBJS) $(CRYPTO_ASM_OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^

$(NETBOOT_BIN): $(NETBOOT_SRC)
	mkdir -p $(dir $@)
	$(HOST_CC) $(HOST_CFLAGS) $(HOST_LDFLAGS) -o $@ $<

$(PXE4011_BIN): $(PXE4011_SRC)
	mkdir -p $(dir $@)
	$(HOST_CC) $(HOST_CFLAGS) $(HOST_LDFLAGS) -o $@ $<

$(QEMU_RUN_BIN): $(QEMU_RUN_SRC)
	mkdir -p $(dir $@)
	$(HOST_CC) $(HOST_CFLAGS) $(HOST_LDFLAGS) -o $@ $<

$(WIFI_HW_PROBE_BIN): $(WIFI_HW_PROBE_SRC) devices/iwlwifi/er_iwlwifi.h devices/mt7922/er_mt7922.h devices/rtw89/er_rtw89.h
	mkdir -p $(dir $@)
	$(HOST_CC) $(HOST_CFLAGS) $(HOST_LDFLAGS) -o $@ $(WIFI_HW_PROBE_SRC)

$(PI_BOOT_STAGE_BIN): $(PI_BOOT_STAGE_SRC)
	mkdir -p $(dir $@)
	$(HOST_CC) $(HOST_CFLAGS) -DERPBS_PROJECT_ROOT=\"..\" $(HOST_LDFLAGS) -o $@ $<

$(CORE_TEST_BIN): $(CORE_TEST_SRC) $(CORE_TEST_FRAGMENT_SRCS) $(HDRS) $(PI_ZERO_W_V1_1_DEVICE_HDRS) $(UI_HDRS) $(VARFONT_HDRS) $(CRYPTO_HDRS) $(WASM_MODULE_HEADERS) $(FONT_HEADER)
	mkdir -p $(dir $@)
	$(HOST_CC) $(HOST_CFLAGS) $(HOST_LDFLAGS) -o $@ $(CORE_TEST_SRC)

$(UI_DIRTY_BENCH_BIN): $(UI_DIRTY_BENCH_SRC) $(HDRS) $(UI_HDRS) $(VARFONT_HDRS) $(WASM_MODULE_HEADERS) $(FONT_HEADER)
	mkdir -p $(dir $@)
	$(HOST_CC) $(HOST_CFLAGS) $(HOST_LDFLAGS) -o $@ $(UI_DIRTY_BENCH_SRC)

$(EFI_BOOT): $(EFI_OUT)
	mkdir -p $(dir $@)
	cp $< $@

run: $(EFI_BOOT) $(QEMU_RUN_BIN) $(QEMU_CONFIG)
	./$(QEMU_RUN_BIN) $(QEMU_CONFIG) $(abspath $(ESP_DIR))

qemu-config-check: $(EFI_BOOT) $(QEMU_RUN_BIN) $(QEMU_CONFIG)
	./$(QEMU_RUN_BIN) --check $(QEMU_CONFIG) $(abspath $(ESP_DIR))

qemu-ephemeral-authority:
	$(MAKE) rebuild-image ER_BOOT_EPHEMERAL_AUTHORITY_ENABLED=1 BUILD_DIR=$(QEMU_EPHEMERAL_AUTHORITY_BUILD_DIR)
	$(MAKE) $(QEMU_EPHEMERAL_AUTHORITY_BUILD_DIR)/edgerun-qemu-run BUILD_DIR=$(QEMU_EPHEMERAL_AUTHORITY_BUILD_DIR)
	./$(QEMU_EPHEMERAL_AUTHORITY_BUILD_DIR)/edgerun-qemu-run $(QEMU_CONFIG) $(abspath $(QEMU_EPHEMERAL_AUTHORITY_BUILD_DIR)/esp)

qemu-ephemeral-authority-smoke:
	$(MAKE) rebuild-image ER_BOOT_EPHEMERAL_AUTHORITY_ENABLED=1 BUILD_DIR=$(QEMU_EPHEMERAL_AUTHORITY_BUILD_DIR)
	$(MAKE) $(QEMU_EPHEMERAL_AUTHORITY_BUILD_DIR)/edgerun-qemu-run BUILD_DIR=$(QEMU_EPHEMERAL_AUTHORITY_BUILD_DIR)
	$(QEMU_SMOKE_SRC) ./$(QEMU_EPHEMERAL_AUTHORITY_BUILD_DIR)/edgerun-qemu-run $(QEMU_CONFIG) $(abspath $(QEMU_EPHEMERAL_AUTHORITY_BUILD_DIR)/esp) $(QEMU_EPHEMERAL_AUTHORITY_LOG) $(QEMU_EPHEMERAL_AUTHORITY_TIMEOUT) "$(QEMU_EPHEMERAL_AUTHORITY_READY)"

qemu-swtpm-persistence-config-check: $(EFI_BOOT) $(QEMU_RUN_BIN) $(QEMU_SWTPM_PERSIST_CONFIG)
	mkdir -p $(QEMU_SWTPM_PERSIST_DIR)
	./$(QEMU_RUN_BIN) --check $(QEMU_SWTPM_PERSIST_CONFIG) $(abspath $(ESP_DIR))

qemu-swtpm-persistence: $(EFI_BOOT) $(QEMU_RUN_BIN) $(QEMU_SMOKE_SRC) $(QEMU_SWTPM_PERSIST_SCRIPT) $(QEMU_SWTPM_PERSIST_CONFIG)
	$(QEMU_SWTPM_PERSIST_SCRIPT) $(QEMU_SMOKE_SRC) ./$(QEMU_RUN_BIN) $(QEMU_SWTPM_PERSIST_CONFIG) $(abspath $(ESP_DIR)) $(QEMU_SWTPM_PERSIST_DIR) $(QEMU_SWTPM_PERSIST_TIMEOUT)

run-aarch64: $(QEMU_AARCH64_CONFIG)
	$(MAKE) all ER_METAL_ARCH=aarch64 BUILD_DIR=$(QEMU_AARCH64_BUILD_DIR)
	$(MAKE) $(QEMU_AARCH64_BUILD_DIR)/edgerun-qemu-run BUILD_DIR=$(QEMU_AARCH64_BUILD_DIR)
	./$(QEMU_AARCH64_BUILD_DIR)/edgerun-qemu-run $(QEMU_AARCH64_CONFIG) $(abspath $(QEMU_AARCH64_BUILD_DIR)/esp)

qemu-aarch64-config-check: $(QEMU_AARCH64_CONFIG)
	$(MAKE) all ER_METAL_ARCH=aarch64 BUILD_DIR=$(QEMU_AARCH64_BUILD_DIR)
	$(MAKE) $(QEMU_AARCH64_BUILD_DIR)/edgerun-qemu-run BUILD_DIR=$(QEMU_AARCH64_BUILD_DIR)
	./$(QEMU_AARCH64_BUILD_DIR)/edgerun-qemu-run --check $(QEMU_AARCH64_CONFIG) $(abspath $(QEMU_AARCH64_BUILD_DIR)/esp)

qemu-aarch64-smoke: $(QEMU_AARCH64_SMOKE_CONFIG) $(QEMU_SMOKE_SRC)
	$(MAKE) all ER_METAL_ARCH=aarch64 BUILD_DIR=$(QEMU_AARCH64_BUILD_DIR)
	$(MAKE) $(QEMU_AARCH64_BUILD_DIR)/edgerun-qemu-run BUILD_DIR=$(QEMU_AARCH64_BUILD_DIR)
	$(QEMU_SMOKE_SRC) ./$(QEMU_AARCH64_BUILD_DIR)/edgerun-qemu-run $(QEMU_AARCH64_SMOKE_CONFIG) $(abspath $(QEMU_AARCH64_BUILD_DIR)/esp) $(QEMU_AARCH64_SMOKE_LOG) $(QEMU_AARCH64_SMOKE_TIMEOUT) "$(QEMU_AARCH64_SMOKE_READY)"

pi-zero-2w-uefi:
	$(MAKE) all ER_METAL_ARCH=aarch64 ER_METAL_BOARD=pi-zero-2w BUILD_DIR=$(PI_ZERO_2W_BUILD_DIR)

pi-zero-2w-boot: pi-zero-2w-uefi $(PI_BOOT_STAGE_BIN)
	$(PI_BOOT_STAGE_BIN) pi-zero-2w $(PI_ZERO_2W_EFI_BOOT) $(PI_ZERO_2W_BOOT_DIR)

pi-zero-w-v1_1-kernel: $(PI_ZERO_W_V1_1_ENTRY_SRC) $(PI_ZERO_W_V1_1_START_SRC) $(PI_ZERO_W_V1_1_DEVICE_HDRS) $(PI_ZERO_W_V1_1_CYW43438_HDRS)
	mkdir -p $(dir $(PI_ZERO_W_V1_1_KERNEL))
	$(CC) -std=c11 -Wall -Wextra -Werror -ffreestanding -fno-builtin -fno-stack-protector -target armv6-none-eabi -fuse-ld=lld -nostdlib -I$(CURDIR)/core -I$(CURDIR)/$(PI_ZERO_W_V1_1_DEVICE_DIR) -I$(CURDIR)/devices/cyw43438 -I$(CURDIR)/../include -Wl,-Ttext=0x8000 -Wl,--image-base=0x0 -Wl,--oformat,binary -o $(PI_ZERO_W_V1_1_KERNEL) $(PI_ZERO_W_V1_1_ENTRY_SRC) $(PI_ZERO_W_V1_1_START_SRC)

pi-zero-w-v1_1-boot: pi-zero-w-v1_1-kernel $(PI_BOOT_STAGE_BIN)
	$(PI_BOOT_STAGE_BIN) pi-zero-w-v1_1 $(PI_ZERO_W_V1_1_KERNEL) $(PI_ZERO_W_V1_1_BOOT_DIR)

clean:
	rm -rf $(BUILD_DIR)

print-path:
	@printf '%s\n' "$(abspath $(EFI_BOOT))"

print-config:
	@printf 'ER_METAL_ARCH=%s\n' "$(ER_METAL_ARCH)"
	@printf 'ER_METAL_BOARD=%s\n' "$(ER_METAL_BOARD)"
	@printf 'ER_METAL_TARGET=%s\n' "$(ER_METAL_TARGET)"
	@printf 'ER_METAL_BOOT_EFI=%s\n' "$(ER_METAL_BOOT_EFI)"
	@printf 'ER_METAL_BOARD_BOOT_CHAIN=%s\n' "$(ER_METAL_BOARD_BOOT_CHAIN)"
	@printf 'ER_BOOT_EPHEMERAL_AUTHORITY_ENABLED=%s\n' "$(ER_BOOT_EPHEMERAL_AUTHORITY_ENABLED)"
	@printf 'EFI_BOOT=%s\n' "$(abspath $(EFI_BOOT))"
	@printf 'CRYPTO_ASM_SRCS=%s\n' "$(CRYPTO_ASM_SRCS)"
