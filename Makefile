.PHONY: all check clean repo-check repo-test edgerun-smoke edgerun-pci edgerun-quiet edgerun-check varfont-configure varfont-build varfont-test

VARFONT_BUILD_DIR ?= .build/varfont
VARFONT_CMAKE_GENERATOR ?= Ninja

all: edgerun-smoke varfont-build

check: repo-check repo-test edgerun-check varfont-test

repo-check:
	./tools/repo-check.sh

repo-test:
	./tests/repo-check-tests.sh

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

clean:
	$(MAKE) -C edgerun-metal clean
	cmake -E rm -rf .build
