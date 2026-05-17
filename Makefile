.PHONY: all check clean repo-check repo-test tooling-test log-listen install-log-listen uninstall-log-listen logs-log-listen status-log-listen edgerun-smoke edgerun-pci edgerun-quiet edgerun-check varfont-configure varfont-build varfont-test ui-core-configure ui-core-build ui-core-test

VARFONT_BUILD_DIR ?= .build/varfont
UI_CORE_BUILD_DIR ?= .build/edgerun-ui-core
VARFONT_CMAKE_GENERATOR ?= Ninja
UI_CORE_CMAKE_GENERATOR ?= Ninja

all: edgerun-smoke varfont-build ui-core-build

check: repo-check repo-test tooling-test edgerun-check varfont-test ui-core-test

repo-check:
	./tools/repo-check.sh

repo-test:
	./tests/repo-check-tests.sh

tooling-test:
	./tests/tooling-tests.sh

log-listen:
	./tools/edgerun-log-listen.sh

install-log-listen:
	$(MAKE) -C edgerun-metal install-log-listen

uninstall-log-listen:
	$(MAKE) -C edgerun-metal uninstall-log-listen

logs-log-listen:
	$(MAKE) -C edgerun-metal logs-log-listen

status-log-listen:
	$(MAKE) -C edgerun-metal status-log-listen

edgerun-smoke:
	$(MAKE) -C edgerun-metal smoke

edgerun-pci:
	$(MAKE) -C edgerun-metal pci

edgerun-quiet:
	$(MAKE) -C edgerun-metal quiet

edgerun-check:
	$(MAKE) -C edgerun-metal check

varfont-configure:
	cmake -S varfont -B $(VARFONT_BUILD_DIR) -G "$(VARFONT_CMAKE_GENERATOR)"

varfont-build: varfont-configure
	cmake --build $(VARFONT_BUILD_DIR)

varfont-test: varfont-build
	ctest --test-dir $(VARFONT_BUILD_DIR) --output-on-failure

ui-core-configure:
	cmake -S edgerun-ui-core -B $(UI_CORE_BUILD_DIR) -G "$(UI_CORE_CMAKE_GENERATOR)"

ui-core-build: ui-core-configure
	cmake --build $(UI_CORE_BUILD_DIR)

ui-core-test: ui-core-build
	ctest --test-dir $(UI_CORE_BUILD_DIR) --output-on-failure

clean:
	$(MAKE) -C edgerun-metal clean
	cmake -E rm -rf .build
