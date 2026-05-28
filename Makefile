.PHONY: help all check clean \
	fmt fmt-check test zig-test \
	crypto-test crypto-bench \
	app-runtime pages-site pages-check pages-public-check pages-release \
	wayland-window wayland-window-test \
	ifstatus real-tpm sdk-cli sdk-bench

BUILD_DIR := .build
ZIG_BUILD := zig build --build-file edgerun-zig/build.zig --cache-dir $(BUILD_DIR)/edgerun-zig
OPT ?= ReleaseFast

CMAKE ?= cmake
CTEST ?= ctest

WAYLAND_WIDTH ?= 1280
WAYLAND_HEIGHT ?= 900
WAYLAND_SECONDS ?= 3600
WAYLAND_PATH ?= /docs

PAGES_SITE_DIR := $(BUILD_DIR)/github-pages
PAGES_BRANCH ?= gh-pages
PAGES_REMOTE ?= origin
PAGES_WORKTREE_DIR := $(BUILD_DIR)/pages-worktree
PAGES_ZIG_OUT := edgerun-zig/zig-out
PAGES_PUBLIC_URL ?= https://sylchi.github.io/edgerun-c/
APP_RUNTIME_WASM := $(PAGES_ZIG_OUT)/bin/edgerun-app-runtime.wasm
FONT_ATLAS_WIDTH := 4096
FONT_ATLAS_HEIGHT := 4096
FONT_ATLAS_CHANNELS := 1
FONT_ATLAS_BYTES := $(shell expr $(FONT_ATLAS_WIDTH) \* $(FONT_ATLAS_HEIGHT) \* $(FONT_ATLAS_CHANNELS))

help:
	@printf '%s\n' \
		'Common targets:' \
		'  make check              fmt-check + tests' \
		'  make fmt                format Zig code' \
		'  make test               run Zig tests' \
		'  make app-runtime        build wasm runtime and print artifact sizes' \
		'  make wayland-window     build wasm runtime and open native Wayland host' \
		'  make pages-site         build local GitHub Pages artifact' \
		'  make pages-check        validate local pages artifact' \
		'  make pages-release      publish pages artifact to gh-pages' \
		'  make clean              remove .build'

all: check

check: fmt-check test

fmt:
	zig fmt edgerun-zig

fmt-check:
	zig fmt --check edgerun-zig

test zig-test:
	$(ZIG_BUILD) test

crypto-test:
	$(CMAKE) -S edgerun-crypto -B $(BUILD_DIR)/edgerun-crypto
	$(CMAKE) --build $(BUILD_DIR)/edgerun-crypto --target test_blake3
	$(CTEST) --test-dir $(BUILD_DIR)/edgerun-crypto --output-on-failure

crypto-bench:
	$(CMAKE) -S edgerun-crypto -B $(BUILD_DIR)/edgerun-crypto
	$(CMAKE) --build $(BUILD_DIR)/edgerun-crypto --target bench

sdk-cli:
	$(ZIG_BUILD) sdk-cli -- simulate standard

sdk-bench:
	$(ZIG_BUILD) sdk-bench

real-tpm:
	$(ZIG_BUILD) real-tpm

ifstatus:
	$(ZIG_BUILD) ifstatus

app-runtime:
	$(ZIG_BUILD) -Doptimize=$(OPT) app-runtime
	@printf 'font atlas: %sx%s alpha%s = %s bytes\n' '$(FONT_ATLAS_WIDTH)' '$(FONT_ATLAS_HEIGHT)' '$(FONT_ATLAS_CHANNELS)' '$(FONT_ATLAS_BYTES)'
	@stat -c 'wasm runtime: %s bytes (%n)' '$(APP_RUNTIME_WASM)' 2>/dev/null || true

wayland-window: app-runtime
	$(ZIG_BUILD) -Doptimize=$(OPT) wayland-window -- --width $(WAYLAND_WIDTH) --height $(WAYLAND_HEIGHT) --seconds $(WAYLAND_SECONDS) --path $(WAYLAND_PATH)

wayland-window-test:
	$(ZIG_BUILD) wayland-window-test

pages-site: app-runtime
	rm -rf $(PAGES_SITE_DIR)
	mkdir -p $(PAGES_SITE_DIR)/web $(PAGES_SITE_DIR)/bin
	cp pages/index.html $(PAGES_SITE_DIR)/index.html
	cp pages/404.html $(PAGES_SITE_DIR)/404.html
	cp $(PAGES_ZIG_OUT)/web/index.html $(PAGES_SITE_DIR)/web/index.html
	python3 - <<'PY'
from pathlib import Path
path = Path('$(PAGES_SITE_DIR)/web/index.html')
text = path.read_text()
old = 'A=(e,k)=>{let p=W.er_ui_input_ptr()'
new = 'A=(e,k)=>{if(!W)return;let p=W.er_ui_input_ptr()'
if new not in text:
    if old not in text:
        raise SystemExit('generated bootstrap input bridge shape changed')
    text = text.replace(old, new, 1)
path.write_text(text)
PY
	grep -q 'A=(e,k)=>{if(!W)return;' $(PAGES_SITE_DIR)/web/index.html
	cp $(APP_RUNTIME_WASM) $(PAGES_SITE_DIR)/bin/edgerun-app-runtime.wasm
	: > $(PAGES_SITE_DIR)/.nojekyll
	test -f $(PAGES_SITE_DIR)/web/index.html
	test -f $(PAGES_SITE_DIR)/bin/edgerun-app-runtime.wasm
	test -f $(PAGES_SITE_DIR)/index.html
	test -f $(PAGES_SITE_DIR)/404.html

pages-check: pages-site
	python3 tools/pages_check.py --site-dir $(PAGES_SITE_DIR)

pages-public-check:
	python3 tools/pages_check.py --public-url $(PAGES_PUBLIC_URL)

pages-release: pages-site
	@set -euo pipefail; \
		rm -rf "$(PAGES_WORKTREE_DIR)"; \
		if git ls-remote --exit-code --heads "$(PAGES_REMOTE)" "$(PAGES_BRANCH)" >/dev/null 2>&1; then \
			git fetch "$(PAGES_REMOTE)" "$(PAGES_BRANCH)" --prune; \
			git worktree add --detach "$(PAGES_WORKTREE_DIR)" "$(PAGES_REMOTE)/$(PAGES_BRANCH)"; \
		else \
			git worktree add --detach "$(PAGES_WORKTREE_DIR)" $$(git rev-parse HEAD); \
			git -C "$(PAGES_WORKTREE_DIR)" switch --orphan "$(PAGES_BRANCH)"; \
		fi; \
		rsync -a --delete --exclude='.git' "$(PAGES_SITE_DIR)/" "$(PAGES_WORKTREE_DIR)/"; \
		git -C "$(PAGES_WORKTREE_DIR)" add --all; \
		if ! git -C "$(PAGES_WORKTREE_DIR)" diff --cached --quiet; then \
			git -C "$(PAGES_WORKTREE_DIR)" commit -m "Deploy GitHub Pages for $$(git rev-parse --short HEAD)"; \
		fi; \
		git -C "$(PAGES_WORKTREE_DIR)" push "$(PAGES_REMOTE)" "HEAD:$(PAGES_BRANCH)"; \
		git worktree remove "$(PAGES_WORKTREE_DIR)"

clean:
	rm -rf $(BUILD_DIR)
