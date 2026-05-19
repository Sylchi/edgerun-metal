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
| Runtime execution tests | 8 / 12 | 66.7% |
| Contract-admitted user app hostcalls | 4 / 12 | 33.3% |
| C frontend declaration tests | 1 / 12 | 8.3% |
| C frontend call emission tests | 0 / 12 | 0.0% |

## Hostcall Checklist

| Done | Hostcall | Signature | Contract role | Runtime test | C declaration | C call emission | Next work |
| --- | --- | --- | --- | --- | --- | --- | --- |
| [ ] | `edgerun.log/u64` | `(i64) -> void` | not admitted | missing | expressible, untested | missing | Add direct execution test or remove if not needed. |
| [ ] | `edgerun.log/hex` | `(i64) -> void` | not admitted | missing | expressible, untested | missing | Add direct execution test or remove if not needed. |
| [ ] | `edgerun.pci/read32` | `(i64, i64, i64, i64) -> i64` | not admitted | missing | expressible, untested | missing | Add direct execution test and decide driver contract ownership. |
| [ ] | `edgerun.pci/write32` | `(i64, i64, i64, i64, i64) -> void` | not admitted | missing | expressible, untested | missing | Add direct execution test and decide driver contract ownership. |
| [x] | `edgerun.mmio/map` | `(i64, i64) -> i64` | not admitted | `test_wasm_mmio_imports` | expressible, untested | missing | Decide whether this stays internal or becomes a driver contract call. |
| [x] | `edgerun.mmio/read32` | `(i64, i64) -> i64` | not admitted | `test_wasm_mmio_imports` | expressible, untested | missing | Decide whether this stays internal or becomes a driver contract call. |
| [x] | `edgerun.bus/exec` | `(i64, i64) -> i64` | `BUS_DRIVER` marker | `test_wasm_bus_exec_import` | expressible, untested | missing | Add C declaration and call-emission tests. |
| [x] | `edgerun.relay/send` | `(i64, i64) -> i64` | not admitted | `test_wasm_relay_imports` | expressible, untested | missing | Decide whether relay access is a user app contract or runtime-owned path. |
| [x] | `edgerun.relay/recv` | `(i64, i64) -> i64` | not admitted | `test_wasm_relay_imports` | expressible, untested | missing | Decide whether relay access is a user app contract or runtime-owned path. |
| [x] | `edgerun.memory/region_base` | `(i64) -> i64` | `UI_APP` support | `test_wasm_public_region_imports` | expressible, untested | missing | Add C declaration and call-emission tests. |
| [x] | `edgerun.memory/region_len` | `(i64) -> i64` | `UI_APP` support | `test_wasm_public_region_imports` | expressible, untested | missing | Add C declaration and call-emission tests. |
| [x] | `edgerun.ui/emit` | `(i64, i64) -> i64` | `UI_APP` marker | `test_wasm_ui_emit_import` | `tests/wasm-compile-tests.sh` | missing | Add C call-emission test for the first real UI app path. |

## Work To Cross Off Next

- [ ] Add runtime fixtures for `edgerun.log/u64` and `edgerun.log/hex`, or remove those hostcalls if they are not part of the OS contract.
- [ ] Add runtime fixtures for `edgerun.pci/read32` and `edgerun.pci/write32`.
- [ ] Decide whether `relay`, `mmio`, `pci`, and `log` calls are internal-only or admitted through explicit app contracts.
- [ ] Extend the C frontend expression subset from integer returns to hostcall expressions.
- [ ] Add C declaration tests for every canonical hostcall signature.
- [ ] Add C call-emission tests for `bus.exec`, `memory.region_base`, `memory.region_len`, and `ui.emit`.
- [ ] Add a package fixture that builds `app/app.c` into `app/.build/app.wasm` using the canonical package layout.
- [ ] Update this checklist whenever `ER_WASM_CONTRACT_IMPORTS` changes.
