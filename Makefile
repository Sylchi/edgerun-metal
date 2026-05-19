.PHONY: all check clean er-build repo-check repo-test repo-check-bin repo-inspect repo-progress erwire-decode erwire-test codex-test crypto-configure crypto-build crypto-test crypto-bench crypto-bench-avx2 crypto-bench-avx512 crypto-bench-avx512-threads crypto-bench-native-threads crypto-bench-sota edgerun-metal edgerun-os edgerun-check varfont-configure varfont-build varfont-test ui-core-configure ui-core-build ui-core-sdl-configure ui-core-sdl-build ui-core-sdl-test ui-core-test

ifeq ($(origin CC),default)
CC := clang
endif
ifeq ($(origin HOST_CC),undefined)
HOST_CC := clang
endif
ifeq ($(origin HOST_CXX),undefined)
HOST_CXX := clang++
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
UI_CORE_SDL_BUILD_DIR ?= .build/edgerun-ui-core-sdl
CRYPTO_BUILD_DIR ?= .build/edgerun-crypto
CRYPTO_AVX2_BUILD_DIR ?= .build/edgerun-crypto-avx2
CRYPTO_AVX512_BUILD_DIR ?= .build/edgerun-crypto-avx512
CRYPTO_AVX512_THREADS_BUILD_DIR ?= .build/edgerun-crypto-avx512-threads
CRYPTO_NATIVE_THREADS_BUILD_DIR ?= .build/edgerun-crypto-native-threads
VARFONT_CMAKE_GENERATOR ?= Ninja
UI_CORE_CMAKE_GENERATOR ?= Ninja
CRYPTO_CMAKE_GENERATOR ?= Ninja
REPO_PROGRESS_SCOPE ?= edgerun-ui-core
REPO_PROGRESS_TEST ?=

all: edgerun-metal

check: repo-check repo-test crypto-test edgerun-check varfont-test ui-core-test

er-build:
	mkdir -p .build
	$(CCACHE_PREFIX) $(HOST_CC) -std=c11 -Wall -Wextra -Werror -O2 $(HOST_LDFLAGS) -o .build/er-build tools/er-build/main.c

repo-check: er-build
	./.build/er-build repo-check

repo-test: er-build
	./.build/er-build repo-test

repo-check-bin: er-build
	./.build/er-build repo-check-bin

repo-inspect: er-build
	./.build/er-build repo-inspect

repo-progress:
	./tools/repo-progress.sh $(REPO_PROGRESS_SCOPE) $(REPO_PROGRESS_TEST)

erwire-decode: er-build
	./.build/er-build erwire-decode

erwire-test: er-build
	./.build/er-build erwire-test

codex-test:
	$(MAKE) -C codex CC="$(HOST_CC)" test

crypto-configure:
	cmake -S edgerun-crypto -B $(CRYPTO_BUILD_DIR) -G "$(CRYPTO_CMAKE_GENERATOR)" $(CMAKE_TOOLCHAIN_ARGS)

crypto-build: crypto-configure
	cmake --build $(CRYPTO_BUILD_DIR)

crypto-test: er-build
	./.build/er-build crypto-test

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

crypto-bench-sota: crypto-bench-avx512 crypto-bench-avx512-threads
	HOST_CC="$(HOST_CC)" HOST_CXX="$(HOST_CXX)" HOST_LDFLAGS="$(HOST_LDFLAGS)" ./tools/bench-blake3-sota.sh

edgerun-metal:
	$(MAKE) -C edgerun-metal

edgerun-os:
	$(MAKE) -C edgerun-metal os

edgerun-check:
	$(MAKE) -C edgerun-metal check

varfont-configure:
	cmake -S varfont -B $(VARFONT_BUILD_DIR) -G "$(VARFONT_CMAKE_GENERATOR)" $(CMAKE_TOOLCHAIN_ARGS)

varfont-build: varfont-configure
	cmake --build $(VARFONT_BUILD_DIR)

varfont-test: er-build
	./.build/er-build varfont-test

ui-core-configure:
	cmake -S edgerun-ui-core -B $(UI_CORE_BUILD_DIR) -G "$(UI_CORE_CMAKE_GENERATOR)" $(CMAKE_TOOLCHAIN_ARGS)

ui-core-build: ui-core-configure
	cmake --build $(UI_CORE_BUILD_DIR)

ui-core-sdl-configure:
	cmake -S edgerun-ui-core -B $(UI_CORE_SDL_BUILD_DIR) -G "$(UI_CORE_CMAKE_GENERATOR)" $(CMAKE_TOOLCHAIN_ARGS) -DER_UI_CORE_BUILD_SDL_HOST=ON

ui-core-sdl-build: ui-core-sdl-configure
	cmake --build $(UI_CORE_SDL_BUILD_DIR) --target er_ui_sdl_shell

ui-core-sdl-test: ui-core-sdl-configure
	cmake --build $(UI_CORE_SDL_BUILD_DIR)
	ctest --test-dir $(UI_CORE_SDL_BUILD_DIR) --output-on-failure

ui-core-test: ui-core-build
	ctest --test-dir $(UI_CORE_BUILD_DIR) --output-on-failure

clean:
	$(MAKE) -C edgerun-metal clean
	cmake -E rm -rf .build
