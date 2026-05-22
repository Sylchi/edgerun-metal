.PHONY: all check clean \
	crypto-test crypto-bench \
	clock-test identity-test object-test storage-test storage-bench \
	varfont-test ui-core-test ui-core-snapshot

BUILD_DIR := .build
CMAKE ?= cmake
CTEST ?= ctest

all: check

check: crypto-test clock-test identity-test object-test storage-test varfont-test ui-core-test

crypto-test:
	$(CMAKE) -S edgerun-crypto -B $(BUILD_DIR)/edgerun-crypto
	$(CMAKE) --build $(BUILD_DIR)/edgerun-crypto --target test_blake3
	$(CTEST) --test-dir $(BUILD_DIR)/edgerun-crypto --output-on-failure

crypto-bench:
	$(CMAKE) -S edgerun-crypto -B $(BUILD_DIR)/edgerun-crypto
	$(CMAKE) --build $(BUILD_DIR)/edgerun-crypto --target bench

clock-test:
	$(CMAKE) -S edgerun-clock -B $(BUILD_DIR)/edgerun-clock
	$(CMAKE) --build $(BUILD_DIR)/edgerun-clock --target test_clock
	$(CTEST) --test-dir $(BUILD_DIR)/edgerun-clock --output-on-failure

identity-test:
	$(CMAKE) -S edgerun-identity -B $(BUILD_DIR)/edgerun-identity
	$(CMAKE) --build $(BUILD_DIR)/edgerun-identity --target test_identity
	$(CTEST) --test-dir $(BUILD_DIR)/edgerun-identity --output-on-failure

object-test:
	$(CMAKE) -S edgerun-object -B $(BUILD_DIR)/edgerun-object
	$(CMAKE) --build $(BUILD_DIR)/edgerun-object --target test_object
	$(CTEST) --test-dir $(BUILD_DIR)/edgerun-object --output-on-failure

storage-test:
	$(CMAKE) -S edgerun-storage -B $(BUILD_DIR)/edgerun-storage
	$(CMAKE) --build $(BUILD_DIR)/edgerun-storage --target test_store
	$(CTEST) --test-dir $(BUILD_DIR)/edgerun-storage --output-on-failure

storage-bench:
	$(CMAKE) -S edgerun-storage -B $(BUILD_DIR)/edgerun-storage
	$(CMAKE) --build $(BUILD_DIR)/edgerun-storage --target bench

varfont-test:
	$(CMAKE) -S edgerun-ui-core/varfont -B $(BUILD_DIR)/varfont
	$(CMAKE) --build $(BUILD_DIR)/varfont
	$(CTEST) --test-dir $(BUILD_DIR)/varfont --output-on-failure

ui-core-test:
	$(CMAKE) -S edgerun-ui-core -B $(BUILD_DIR)/edgerun-ui-core
	$(CMAKE) --build $(BUILD_DIR)/edgerun-ui-core --target er_ui_core_tests
	$(CTEST) --test-dir $(BUILD_DIR)/edgerun-ui-core --output-on-failure

ui-core-snapshot:
	$(CMAKE) -S edgerun-ui-core -B $(BUILD_DIR)/edgerun-ui-core -DER_UI_CORE_BUILD_SNAPSHOT_HOST=ON
	$(CMAKE) --build $(BUILD_DIR)/edgerun-ui-core --target er_ui_snapshot
	$(BUILD_DIR)/edgerun-ui-core/er_ui_snapshot --output $(BUILD_DIR)/edgerun-ui-core/snapshot.bmp

clean:
	rm -rf $(BUILD_DIR)
