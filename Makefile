.PHONY: all check clean er-build repo-check repo-test repo-check-bin repo-inspect repo-progress erwire-decode erwire-test codex-build codex-test crypto-configure crypto-build crypto-test crypto-bench crypto-bench-avx2 crypto-bench-avx512 crypto-bench-avx512-threads crypto-bench-native-threads metal-ui-bench edgerun-metal edgerun-os edgerun-check varfont-configure varfont-build varfont-test ui-core-configure ui-core-build ui-core-sdl-configure ui-core-sdl-build ui-core-sdl-run ui-core-sdl-test ui-core-test

CC := clang
HOST_CC := clang
HOST_CXX := clang++
HOST_LDFLAGS :=
CMAKE_TOOLCHAIN_ARGS := -DCMAKE_C_COMPILER=$(HOST_CC)

VARFONT_BUILD_DIR := .build/varfont
UI_CORE_BUILD_DIR := .build/edgerun-ui-core
UI_CORE_SDL_BUILD_DIR := .build/edgerun-ui-core-sdl
CRYPTO_BUILD_DIR := .build/edgerun-crypto
CRYPTO_AVX2_BUILD_DIR := .build/edgerun-crypto-avx2
CRYPTO_AVX512_BUILD_DIR := .build/edgerun-crypto-avx512
CRYPTO_AVX512_THREADS_BUILD_DIR := .build/edgerun-crypto-avx512-threads
CRYPTO_NATIVE_THREADS_BUILD_DIR := .build/edgerun-crypto-native-threads
VARFONT_CMAKE_GENERATOR := Ninja
UI_CORE_CMAKE_GENERATOR := Ninja
CRYPTO_CMAKE_GENERATOR := Ninja
REPO_PROGRESS_SCOPE := edgerun-ui-core
REPO_PROGRESS_TEST :=
PROMPT := Inspect the current workspace status and continue the highest-impact useful task.

all: edgerun-metal

check: repo-check repo-test crypto-test edgerun-check varfont-test ui-core-test

er-build:
	mkdir -p .build
	tmp=".build/er-build.$$$$.tmp"; trap 'rm -f "$$tmp"' EXIT; $(HOST_CC) -std=c11 -Wall -Wextra -Werror -O2 -Iedgerun-crypto/include $(HOST_LDFLAGS) -o "$$tmp" tools/er-build/main.c tools/er-build/package_identity.c edgerun-crypto/src/er_blake3.c; mv "$$tmp" .build/er-build

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

erwire-decode: er-build
	./.build/er-build erwire-decode

erwire-test: er-build
	./.build/er-build erwire-test

codex-build:
	$(MAKE) -C codex CC="$(HOST_CC)"

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

metal-ui-bench:
	$(MAKE) -C edgerun-metal bench-ui-dirty

edgerun-metal:
	$(MAKE) -C edgerun-metal

edgerun-os:
	$(MAKE) -C edgerun-metal os

edgerun-check:
	$(MAKE) -C edgerun-metal check

varfont-configure:
	cmake -S edgerun-ui-core/varfont -B $(VARFONT_BUILD_DIR) -G "$(VARFONT_CMAKE_GENERATOR)" $(CMAKE_TOOLCHAIN_ARGS)

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

ui-core-sdl-run: codex-build ui-core-sdl-build
	$(UI_CORE_SDL_BUILD_DIR)/er_ui_sdl_shell --root "$(CURDIR)" --prompt "$(PROMPT)"

ui-core-sdl-test: ui-core-sdl-configure
	cmake --build $(UI_CORE_SDL_BUILD_DIR)
	ctest --test-dir $(UI_CORE_SDL_BUILD_DIR) --output-on-failure

ui-core-test: ui-core-build
	ctest --test-dir $(UI_CORE_BUILD_DIR) --output-on-failure

clean:
	$(MAKE) -C edgerun-metal clean
	cmake -E rm -rf .build
