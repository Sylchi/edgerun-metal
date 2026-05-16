.PHONY: all run clean print-path netboot install-netboot uninstall-netboot restart-netboot logs-netboot status-netboot install-agent install-agent-user uninstall-agent-user run-agent run-agent-user logs-agent logs-agent-user status-agent status-agent-user

CC = clang
HOST_CC = cc

BUILD_DIR := build
ESP_DIR := $(BUILD_DIR)/esp
EFI_OUT := $(BUILD_DIR)/edgerun-metal.efi
EFI_BOOT := $(ESP_DIR)/EFI/BOOT/BOOTX64.EFI

CFLAGS := -std=c11 -Wall -Werror -ffreestanding -fshort-wchar -fno-builtin -fno-stack-protector -mno-red-zone -fuse-ld=lld -target x86_64-pc-windows-msvc \
          -I$(CURDIR)/core -I$(CURDIR)
LDFLAGS := -nostdlib -Wl,/SUBSYSTEM:EFI_APPLICATION,/ENTRY:efi_main
HOST_CFLAGS := -std=c11 -Wall -Wextra -Werror -O2

SRCS := core/efi_main.c core/er_print.c core/wasm_vm.c
OBJS := $(patsubst %.c,$(BUILD_DIR)/%.o,$(SRCS))
HDRS := $(wildcard core/*.h)
NETBOOT_SRC := tools/edgerun-netboot/main.c
NETBOOT_BIN := $(BUILD_DIR)/edgerun-netboot
IFACE ?=

all: $(EFI_OUT) $(EFI_BOOT)

netboot: $(NETBOOT_BIN)

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

install-agent:
	sudo ./tools/edgerun-agent/install-agent-service.sh

uninstall-agent:
	sudo ./tools/edgerun-agent/uninstall-agent-service.sh

install-agent-user:
	./tools/edgerun-agent/install-agent-user-service.sh

uninstall-agent-user:
	./tools/edgerun-agent/uninstall-agent-user-service.sh

run-agent:
	sudo systemctl start edgerun-agent.service

run-agent-user:
	systemctl --user start edgerun-agent.service

logs-agent:
	journalctl -u edgerun-agent.service -f

logs-agent-user:
	journalctl --user -u edgerun-agent.service -f

status-agent:
	systemctl status edgerun-agent.timer edgerun-agent.service --no-pager || true

status-agent-user:
	systemctl --user status edgerun-agent.timer edgerun-agent.service --no-pager || true

$(BUILD_DIR)/%.o: %.c $(HDRS)
	mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c $< -o $@

$(EFI_OUT): $(OBJS)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $^

$(NETBOOT_BIN): $(NETBOOT_SRC)
	mkdir -p $(dir $@)
	$(HOST_CC) $(HOST_CFLAGS) -o $@ $<

$(EFI_BOOT): $(EFI_OUT)
	mkdir -p $(dir $@)
	cp $< $@

run: $(EFI_BOOT)
	./scripts/run-qemu.sh

clean:
	rm -rf $(BUILD_DIR)

print-path:
	@printf '%s\n' "$(abspath $(EFI_BOOT))"
