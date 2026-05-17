.PHONY: all check clean repo-check repo-test repo-inspect erwire-decode erwire-test crypto-configure crypto-build crypto-test crypto-bench crypto-bench-avx2 crypto-bench-avx512 crypto-bench-avx512-threads crypto-bench-native-threads edgerun-smoke edgerun-pci edgerun-quiet edgerun-ui edgerun-check varfont-configure varfont-build varfont-test ui-core-configure ui-core-build ui-core-test

ifeq ($(origin CC),default)
CC := clang
endif
ifeq ($(origin HOST_CC),undefined)
HOST_CC := clang
endif

CCACHE ?= $(shell command -v ccache 2>/dev/null)
MOLD ?= $(shell command -v mold 2>/dev/null)
CCACHE_PREFIX := $(if $(CCACHE),$(CCACHE),)
HOST_LDFLAGS ?= $(if $(MOLD),-fuse-ld=mold,)
CMAKE_TOOLCHAIN_ARGS := -DCMAKE_C_COMPILER=$(HOST_CC)
ifneq ($(CCACHE),)
CMAKE_TOOLCHAIN_ARGS += -DCMAKE_C_COMPILER_LAUNCHER=$(CCACHE)
endif
ifneq ($(HOST_LDFLAGS),)
CMAKE_TOOLCHAIN_ARGS += -DCMAKE_EXE_LINKER_FLAGS=$(HOST_LDFLAGS)
endif

VARFONT_BUILD_DIR ?= .build/varfont
UI_CORE_BUILD_DIR ?= .build/edgerun-ui-core
CRYPTO_BUILD_DIR ?= .build/edgerun-crypto
CRYPTO_AVX2_BUILD_DIR ?= .build/edgerun-crypto-avx2
CRYPTO_AVX512_BUILD_DIR ?= .build/edgerun-crypto-avx512
CRYPTO_AVX512_THREADS_BUILD_DIR ?= .build/edgerun-crypto-avx512-threads
CRYPTO_NATIVE_THREADS_BUILD_DIR ?= .build/edgerun-crypto-native-threads
VARFONT_CMAKE_GENERATOR ?= Ninja
UI_CORE_CMAKE_GENERATOR ?= Ninja
CRYPTO_CMAKE_GENERATOR ?= Ninja

all: crypto-build edgerun-smoke varfont-build ui-core-build

check: repo-check repo-test crypto-test edgerun-check varfont-test ui-core-test

repo-check:
	./tools/repo-check.sh

repo-test: repo-inspect
	./tests/repo-check-tests.sh
	./tests/repo-inspect-tests.sh
	$(MAKE) erwire-test

repo-inspect:
	mkdir -p .build
	$(CCACHE_PREFIX) $(HOST_CC) -std=c11 -Wall -Wextra -Werror -O2 $(HOST_LDFLAGS) -o .build/repo-inspect tools/repo-inspect.c

erwire-decode:
	mkdir -p .build
	$(CCACHE_PREFIX) $(HOST_CC) -std=c11 -Wall -Wextra -Werror -O2 $(HOST_LDFLAGS) -o .build/erwire-decode tools/erwire-decode.c

erwire-test: erwire-decode
	./tests/erwire-decode-tests.sh

crypto-configure:
	cmake -S edgerun-crypto -B $(CRYPTO_BUILD_DIR) -G "$(CRYPTO_CMAKE_GENERATOR)" $(CMAKE_TOOLCHAIN_ARGS)

crypto-build: crypto-configure
	cmake --build $(CRYPTO_BUILD_DIR)

crypto-test: crypto-build
	ctest --test-dir $(CRYPTO_BUILD_DIR) --output-on-failure

crypto-bench: crypto-build
	cmake --build $(CRYPTO_BUILD_DIR) --target bench

crypto-bench-avx2:
	cmake -S edgerun-crypto -B $(CRYPTO_AVX2_BUILD_DIR) -G "$(CRYPTO_CMAKE_GENERATOR)" $(CMAKE_TOOLCHAIN_ARGS) -DER_CRYPTO_ENABLE_AVX2=ON
	cmake --build $(CRYPTO_AVX2_BUILD_DIR) --target bench

crypto-bench-avx512:
	cmake -S edgerun-crypto -B $(CRYPTO_AVX512_BUILD_DIR) -G "$(CRYPTO_CMAKE_GENERATOR)" $(CMAKE_TOOLCHAIN_ARGS) -DER_CRYPTO_ENABLE_AVX512=ON
	cmake --build $(CRYPTO_AVX512_BUILD_DIR) --target bench

crypto-bench-avx512-threads:
	cmake -S edgerun-crypto -B $(CRYPTO_AVX512_THREADS_BUILD_DIR) -G "$(CRYPTO_CMAKE_GENERATOR)" $(CMAKE_TOOLCHAIN_ARGS) -DER_CRYPTO_ENABLE_AVX512=ON -DER_CRYPTO_ENABLE_THREADS=ON
	cmake --build $(CRYPTO_AVX512_THREADS_BUILD_DIR) --target bench

crypto-bench-native-threads:
	cmake -S edgerun-crypto -B $(CRYPTO_NATIVE_THREADS_BUILD_DIR) -G "$(CRYPTO_CMAKE_GENERATOR)" $(CMAKE_TOOLCHAIN_ARGS) -DER_CRYPTO_ENABLE_AVX512=ON -DER_CRYPTO_ENABLE_THREADS=ON -DER_CRYPTO_ENABLE_NATIVE=ON
	cmake --build $(CRYPTO_NATIVE_THREADS_BUILD_DIR) --target bench

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
	cmake -S varfont -B $(VARFONT_BUILD_DIR) -G "$(VARFONT_CMAKE_GENERATOR)" $(CMAKE_TOOLCHAIN_ARGS)

varfont-build: varfont-configure
	cmake --build $(VARFONT_BUILD_DIR)

varfont-test: varfont-build
	ctest --test-dir $(VARFONT_BUILD_DIR) --output-on-failure

ui-core-configure:
	cmake -S edgerun-ui-core -B $(UI_CORE_BUILD_DIR) -G "$(UI_CORE_CMAKE_GENERATOR)" $(CMAKE_TOOLCHAIN_ARGS)

ui-core-build: ui-core-configure
	cmake --build $(UI_CORE_BUILD_DIR)

ui-core-test: ui-core-build
	ctest --test-dir $(UI_CORE_BUILD_DIR) --output-on-failure

clean:
	$(MAKE) -C edgerun-metal clean
	cmake -E rm -rf .build
