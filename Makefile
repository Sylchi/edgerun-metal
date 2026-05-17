.PHONY: all check clean repo-check repo-test erwire-decode erwire-test edgerun-smoke edgerun-pci edgerun-quiet edgerun-ui edgerun-check varfont-configure varfont-build varfont-test ui-core-configure ui-core-build ui-core-test

VARFONT_BUILD_DIR ?= .build/varfont
UI_CORE_BUILD_DIR ?= .build/edgerun-ui-core
VARFONT_CMAKE_GENERATOR ?= Ninja
UI_CORE_CMAKE_GENERATOR ?= Ninja

all: edgerun-smoke varfont-build ui-core-build

check: repo-check repo-test edgerun-check varfont-test ui-core-test

repo-check:
	./tools/repo-check.sh

repo-test:
	./tests/repo-check-tests.sh
	$(MAKE) erwire-test

erwire-decode:
	mkdir -p .build
	$(CC) -std=c11 -Wall -Wextra -Werror -O2 -o .build/erwire-decode tools/erwire-decode.c

erwire-test: erwire-decode
	./tests/erwire-decode-tests.sh

edgerun-smoke:
	$(MAKE) -C edgerun-metal smoke

edgerun-pci:
	$(MAKE) -C edgerun-metal pci

edgerun-quiet:
	$(MAKE) -C edgerun-metal quiet

edgerun-ui:
	$(MAKE) -C edgerun-metal ui

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
