.PHONY: all check clean \
	crypto-test crypto-bench \
	clock-test identity-test object-test storage-test \
	varfont-test ui-core-test \
	zig-check zig-fmt-check zig-fmt zig-test zig-real-tpm

BUILD_DIR := .build
CMAKE ?= cmake
CTEST ?= ctest

all: check

check: crypto-test clock-test identity-test object-test storage-test varfont-test ui-core-test zig-check

crypto-test:
	$(CMAKE) -S edgerun-crypto -B $(BUILD_DIR)/edgerun-crypto -DER_CRYPTO_USE_UPSTREAM_BLAKE3_ASM=OFF
	$(CMAKE) --build $(BUILD_DIR)/edgerun-crypto --target test_blake3
	$(CTEST) --test-dir $(BUILD_DIR)/edgerun-crypto --output-on-failure

crypto-bench:
	$(CMAKE) -S edgerun-crypto -B $(BUILD_DIR)/edgerun-crypto -DER_CRYPTO_USE_UPSTREAM_BLAKE3_ASM=OFF
	$(CMAKE) --build $(BUILD_DIR)/edgerun-crypto --target bench

clock-test:
	$(CMAKE) -S edgerun-clock -B $(BUILD_DIR)/edgerun-clock
	$(CMAKE) --build $(BUILD_DIR)/edgerun-clock --target test_clock
	$(CTEST) --test-dir $(BUILD_DIR)/edgerun-clock --output-on-failure

identity-test:
	zig build --build-file edgerun-zig/build.zig --cache-dir $(BUILD_DIR)/edgerun-zig identity-test

object-test:
	zig build --build-file edgerun-zig/build.zig --cache-dir $(BUILD_DIR)/edgerun-zig object-test

storage-test:
	zig build --build-file edgerun-zig/build.zig --cache-dir $(BUILD_DIR)/edgerun-zig storage-test

varfont-test:
	$(CMAKE) -S edgerun-ui-core/varfont -B $(BUILD_DIR)/varfont
	$(CMAKE) --build $(BUILD_DIR)/varfont
	$(CTEST) --test-dir $(BUILD_DIR)/varfont --output-on-failure

ui-core-test:
	$(CMAKE) -S edgerun-ui-core -B $(BUILD_DIR)/edgerun-ui-core
	$(CMAKE) --build $(BUILD_DIR)/edgerun-ui-core
	$(CTEST) --test-dir $(BUILD_DIR)/edgerun-ui-core --output-on-failure

zig-check: zig-fmt-check zig-test

zig-fmt-check:
	zig fmt --check edgerun-zig

zig-fmt:
	zig fmt edgerun-zig

zig-test:
	zig build --build-file edgerun-zig/build.zig --cache-dir $(BUILD_DIR)/edgerun-zig test

zig-real-tpm:
	zig build --build-file edgerun-zig/build.zig --cache-dir $(BUILD_DIR)/edgerun-zig real-tpm

clean:
	rm -rf $(BUILD_DIR)
