.PHONY: all check clean er-build repo-check repo-test repo-check-bin repo-inspect repo-progress repo-agent-swarm erwire-decode erwire-test pi-serial-verify sdcard-probe pi-usb-boot codex-build codex-test crypto-test metal-ui-bench os-user-app-smoke edgerun-metal edgerun-os edgerun-check varfont-test ui-core-test

CC := clang
HOST_CC := clang
HOST_LDFLAGS :=
ER_BUILD_BOOTSTRAP := toolchain/bin/er-build

REPO_PROGRESS_SCOPE := edgerun-ui-core
REPO_PROGRESS_TEST :=
USER_APP_PACKAGE_DIR := tests/fixtures/app-package/app

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

codex-build:
	$(MAKE) -C codex CC="$(HOST_CC)"

codex-test:
	$(MAKE) -C codex CC="$(HOST_CC)" test

crypto-test: er-build
	./.build/er-build crypto-test

metal-ui-bench:
	$(MAKE) -C edgerun-metal bench-ui-dirty

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
