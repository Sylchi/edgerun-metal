# Wasm Hostcall Coverage Checklist

Source of truth: `include/er_wasm_contract.h`.

Coverage means:

- Declared: the hostcall exists in `ER_WASM_CONTRACT_IMPORTS`.
- Runtime-tested: a Wasm fixture executes the hostcall through the VM.
- Contract-admitted: the call is allowed by an explicit app contract mask.
- C-declared: the owned C frontend parses the import declaration in a test.
- C-called: the owned C frontend emits a call and the generated Wasm is tested.

Current coverage:

| Area | Covered | Percent |
| --- | ---: | ---: |
| Canonical hostcalls declared | 12 / 12 | 100.0% |
| Runtime execution tests | 12 / 12 | 100.0% |
| Contract-admitted user app hostcalls | 4 / 12 | 33.3% |
| C frontend declaration tests | 4 / 12 | 33.3% |
| C frontend call emission tests | 4 / 12 | 33.3% |
| C-generated runtime execution tests | 4 / 12 | 33.3% |

## Hostcall Checklist

| Done | Hostcall | Signature | Contract role | Runtime test | C declaration | C call emission | Next work |
| --- | --- | --- | --- | --- | --- | --- | --- |
| [x] | `edgerun.log/u64` | `(i64) -> void` | not admitted | `test_wasm_log_imports` | expressible, untested | missing | Decide whether this stays internal or is removed. |
| [x] | `edgerun.log/hex` | `(i64) -> void` | not admitted | `test_wasm_log_imports` | expressible, untested | missing | Decide whether this stays internal or is removed. |
| [x] | `edgerun.pci/read32` | `(i64, i64, i64, i64) -> i64` | not admitted | `test_wasm_pci_imports` | expressible, untested | missing | Decide driver contract ownership. |
| [x] | `edgerun.pci/write32` | `(i64, i64, i64, i64, i64) -> void` | not admitted | `test_wasm_pci_imports` | expressible, untested | missing | Decide driver contract ownership. |
| [x] | `edgerun.mmio/map` | `(i64, i64) -> i64` | not admitted | `test_wasm_mmio_imports` | expressible, untested | missing | Decide whether this stays internal or becomes a driver contract call. |
| [x] | `edgerun.mmio/read32` | `(i64, i64) -> i64` | not admitted | `test_wasm_mmio_imports` | expressible, untested | missing | Decide whether this stays internal or becomes a driver contract call. |
| [x] | `edgerun.bus/exec` | `(i64, i64) -> i64` | `BUS_DRIVER` marker | `test_wasm_bus_exec_import` | `tests/wasm-compile-tests.sh` | `tests/wasm-compile-tests.sh` and `test_wasm_c_generated_hostcall_modules` | Add package workflow fixture. |
| [x] | `edgerun.relay/send` | `(i64, i64) -> i64` | not admitted | `test_wasm_relay_imports` | expressible, untested | missing | Decide whether relay access is a user app contract or runtime-owned path. |
| [x] | `edgerun.relay/recv` | `(i64, i64) -> i64` | not admitted | `test_wasm_relay_imports` | expressible, untested | missing | Decide whether relay access is a user app contract or runtime-owned path. |
| [x] | `edgerun.memory/region_base` | `(i64) -> i64` | `UI_APP` support | `test_wasm_public_region_imports` | `tests/wasm-compile-tests.sh` | `tests/wasm-compile-tests.sh` and `test_wasm_c_generated_hostcall_modules` | Add package workflow fixture. |
| [x] | `edgerun.memory/region_len` | `(i64) -> i64` | `UI_APP` support | `test_wasm_public_region_imports` | `tests/wasm-compile-tests.sh` | `tests/wasm-compile-tests.sh` and `test_wasm_c_generated_hostcall_modules` | Add package workflow fixture. |
| [x] | `edgerun.ui/emit` | `(i64, i64) -> i64` | `UI_APP` marker | `test_wasm_ui_emit_import` | `tests/wasm-compile-tests.sh` | `tests/wasm-compile-tests.sh` and `test_wasm_c_generated_hostcall_modules` | Add package workflow fixture. |

## Work To Cross Off Next

- [x] Add runtime fixtures for `edgerun.log/u64` and `edgerun.log/hex`, or remove those hostcalls if they are not part of the OS contract.
- [x] Add runtime fixtures for `edgerun.pci/read32` and `edgerun.pci/write32`.
- [ ] Decide whether `relay`, `mmio`, `pci`, and `log` calls are internal-only or admitted through explicit app contracts.
- [x] Extend the C frontend expression subset from integer returns to admitted i64 hostcall return expressions.
- [ ] Add C declaration tests for every admitted canonical hostcall signature.
- [x] Add C call-emission tests for `bus.exec`, `memory.region_base`, `memory.region_len`, and `ui.emit`.
- [x] Add generated module runtime execution tests for C-emitted hostcall modules.
- [x] Add a package fixture that builds `app/app.c` into `app/.build/app.wasm` using the canonical package layout.
- [ ] Update this checklist whenever `ER_WASM_CONTRACT_IMPORTS` changes.
