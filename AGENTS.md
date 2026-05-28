# AGENTS.md

## Core Rules

- No fallbacks.
- Warnings are errors.
- Errors are fatal.
- No shortcuts.
- No external dependencies beyond what's required for self-hosted builds.
- All production code is x86_64 assembly using the project's own macro DSL (`macros.inc`).
- No Zig, no C, no Python, no CMake in production code paths.
- Host-side test harnesses may temporarily use C for linking purposes, but must be migrated to pure ASM self-hosted runners.
- The permitted vendor binary exceptions are explicit and narrow: device radio firmware needed to operate a radio block, such as CYW43438 RAM/NVRAM/CLM files, and Raspberry Pi Zero-family boot firmware needed for the Broadcom mask-ROM/GPU boot chain to load repo-owned `kernel.img` on Pi Zero W v1.1 bring-up hardware. These exceptions do not permit vendor drivers, host tools, protocol stacks, closed control planes, compatibility layers, or any other vendor blob.
- No ambiguity.
- Tests must cover touched behavior.
- Code must be deterministic.
- No monolithic files.
- Use switch statements and constants for control and value selection.
- No magic numbers.
- Eliminate repetition; refactor repeated logic into utility functions.
- Consolidating and removing code is preferred over adding new code.
- No regressions.
- Generated build artifacts must stay untracked.
- Use `.build/` for local build output.
- Keep this as one Git repository; nested `.git` directories, `.gitmodules`, and submodule gitlinks are not allowed.
- Multiple agents may work in this repository at the same time.
- Stay inside the bounds of the assigned task and owned files.
- Do not create, switch to, or continue work on feature branches unless the user explicitly asks.

## Workspace & Language

- **The project's own language is the x86_64 assembly DSL defined in `asm/x86_64/macros.inc`** — `er_fn`, `er_fnstr`, `er_frame_push`, `er_push_all`, etc. This IS the dogfooding target. All production code must be written in this DSL.
- `asm/x86_64/` — canonical hardware-near implementation of all core modules: math, runtime, serial, ctype, TPM, WASM interpreter, kernel entry, kernel main.
- `asm/test/` — test files. Must be migrated from C to self-hosted ASM runners. Currently C test harnesses provide the `main()` entry point and link against ASM `.o` files for freestanding testing.
- `edgerun-zig/` — DEPRECATED. Being removed as part of the Zig toolchain elimination. Do not add new Zig code.
- `edgerun-crypto/` — C BLAKE3 implementation. Needs to be ported to ASM or replaced with a project-owned implementation.
- `Makefile` — owns x86_64 ASM builds and kernel images.

## External Dependencies (to eliminate)

### Build tools (minimum to bootstrap)
- `yasm` (or `nasm`) — assembler for the DSL. Long-term goal: own assembler.
- `make` — build orchestrator. Long-term goal: own build system.
- `ld` / `objcopy` (binutils) — linker. Long-term goal: own linker.

### Current test-time dependencies (being phased out)
- `cc` (gcc/clang) — used to compile C test harness + link ASM objects into freestanding static binaries.
- C startup crt0 stubs via `-ffreestanding -nostdlib`.
- `zig` — full Zig compiler + std lib (DEPRECATED, remove).
- `cmake` / `ctest` — only needed for edgerun-crypto (remove with C crypto).
- `python3` — only needed for pages tooling.
- `qemu-system-x86_64` — kernel test environment.

## Required Commands

- Full repository check:
  - `make check`
- ASM module tests (builds and runs):
  - `make asm-test-math`
  - `make asm-test-runtime`
  - `make asm-test-serial`
  - `make asm-test-wasm`
  - `make asm-test-tpm`
  - `make asm-test` (all of the above)
- ASM kernel build:
  - `make asm-kernel`
  - `make asm-kernel-hello` (build + QEMU launch)
- Clean:
  - `make clean`

## C To ASM Porting Rules

- All new production code must be written in the project's ASM DSL (`macros.inc`).
- Port existing C test harnesses to pure ASM self-hosted test runners (no `main()` from C).
- When porting, update Makefile rules to assemble and link directly via ld without the C compiler bridge.
- Keep behavior and tests coherent across the Makefile and module-local tests.
- Do not reintroduce C compatibility wrappers or shims at the ASM boundary.
- The WASM interpreter in `asm/x86_64/wasm_interpreter.asm` is the canonical implementation.

## Friction Prevention

- Treat the implementation as the source of truth. Read the actual code before changing docs, roadmap text, or architecture descriptions.
- When the user points to a reference implementation, screenshot, copied text, or another repo, inspect that reference directly and port the relevant behavior instead of approximating it.
- Do not invent parallel systems, alternate terminology, or new architecture when an existing project concept already covers the task.
- For broad prompts such as `continue`, `improve`, `fix`, or `get to work`, choose the highest-impact concrete task, state that task briefly, and execute it through verification.
- Material progress means removing wrong code, reducing real complexity, improving a working path, or making visible/testable behavior better. Avoid tiny cosmetic edits unless they unblock a larger goal.
- Prefer consolidation and deletion over adding another layer. If two files, docs, APIs, or concepts conflict, reconcile them to one canonical version.
- If the task is architectural, update code and tests first; update documentation only after the implemented behavior is clear.
- If the task is documentation, verify the documentation against current code before editing and remove stale/conflicting claims instead of expanding them.
- If the user corrects direction, treat the correction as higher priority than earlier plans and re-read the relevant code before continuing.
- Do not keep retrying a failing build, test, or QEMU run without changing the hypothesis. Capture the specific failure, inspect the responsible code, then make a targeted fix.
- This laptop's USB bus is flaky during hardware bring-up. If USB storage or serial devices appear wedged or report impossible state, reset the affected root hub before changing repo code or assuming the target board failed.
- For the current Pi USB bring-up station, the affected root hub is owned by xHCI PCI device `0000:c3:00.4` and carries USB bus 007/008. Reset it with `sudo sh -c 'echo 0000:c3:00.4 > /sys/bus/pci/drivers/xhci_hcd/unbind; sleep 3; echo 0000:c3:00.4 > /sys/bus/pci/drivers/xhci_hcd/bind'`.
- After a Pi USB root-hub reset, re-run `lsusb` and `chown` the new `/dev/bus/usb/BBB/DDD` Broadcom boot node before running the non-root boot command.

## Enforcement

- Fail fast on unsupported, uncertain, or partial states.
- Do not log, suppress, or downgrade warnings.
- Do not catch and continue; return or abort immediately on failure.
- Do not introduce compatibility layers, shims, or fallback paths.
- Avoid speculative, dynamic, or hidden behavior.
- Prefer editing existing code to simplify or remove duplication instead of appending behavior.
- Preserve existing public behavior and interfaces unless explicitly instructed.
- Keep implementations minimal, explicit, deterministic, and dependency-free.
- Use project-owned primitives for memory, strings, math, and I/O in production paths.
- Keep root documentation and command wrappers current when workflow changes.
- Add tests for new repository tooling and for behavior changes when deterministic tests are possible.
- Document the purpose and intention of new tools, tests, and top-level structure.

## Multi-Agent Safety

- Assume every agent shares the same working tree and current branch.
- Do not switch branches during normal work. Branch switching moves all agents sharing this checkout and can hide or strand their changes.
- Treat unrecognized local changes as another agent's work.
- Do not overwrite, revert, reformat, move, or delete another agent's files unless explicitly instructed.
- Do not run destructive Git commands such as `git reset --hard`, `git checkout --`, `git clean`, or broad restore operations.
- Do not use `git add -A` or broad staging when unrelated changes are present; stage only owned paths.
- Check `git status --short --branch` before edits, before staging, and before committing.
- If a needed change overlaps another agent's work, stop and coordinate instead of resolving by force.
- Keep commits scoped to one coherent task and mention any intentionally touched shared files.

## Session Summary (2026-05-29)

### Session 1 — Build system & test cleanup
- `make check` now includes `asm-test` and `crypto-test` (was Zig-only).
- Added `asm-test-wasm` to the top-level `asm-test` target.
- Removed dead `$(ASM_BUILD_DIR)/kernel_main.o` target and duplicate `ASM_KERNEL_LD/ELF/BIN` variables.
- Created `asm/x86_64/tpm_constants.inc` as canonical source for shared TPM constants; `tpm.asm` and `kernel_main.asm` now use `%include` instead of duplicating `%define`s.
- Removed reference to undefined string `check_tpm_alg_fail_details` in `kernel_main.asm` (pre-existing assembly-time bug that was silently hidden by `2>/dev/null`).
- Factored 3x duplicated `.putchar` (11 lines each) in `serial.asm` into a single `_serial_putchar` helper.
- Replaced 11 repetitive per-file ASM build rules in Makefile with 5 static pattern rules (54 lines → 30 lines).
- Added missing `uint16_t`/`uint32_t`/`uint64_t` typedefs to `asm/test/test_serial.c` (freestanding compilation fix).
- Fixed 3 pre-existing test failures in `test_runtime.c`: line 431 (wrong copy comparison in `memswap zero`), line 438 and 446 (`er_strcmp` on un-null-terminated `er_hex_encode` output → `er_memcmp`).
- All 6 ASM test suites now pass (ctypes, math, runtime, serial, TPM, WASM).

### Session 2 — Driver error-convention standardization
- Audited all 5 driver files (cmos.asm, i8042.asm, cros_ec.asm, dw_i2c.asm, i2c_hid.asm) for return convention; found 3 conflicting patterns (rax-only 0=ok, rax-only 0/-1, unconditional rax=value with no error path).
- Standardized all to **two-register convention**: `rax` = primary value, `rdx` = 0 on success, non-zero error code on failure.
- Added `er_ok`, `er_ret`, `er_err` wrappers in macros.inc for consistent function returns.
- Added error codes to `wasm_constants.inc`: `ERROR_TIMEOUT`=20, `ERROR_IO`=21, `ERROR_NOT_PRESENT`=22, `ERROR_NO_DATA`=23.
- **cros_ec.asm** — fixed critical bug: `er_cros_ec_read_data` conflated timeout (returning 0x00) with valid 0x00 data. Now returns rax=data, rdx=0 on success; rax=0, rdx=ERROR_TIMEOUT on timeout.
- **i2c_hid.asm** — fixed critical bug: `_i2c_hid_read_reg16` used 0xFFFF as error sentinel, but 0xFFFF is a valid register value. Now uses rax+rdx convention.
- **i8042.asm** — `er_i8042_read_scancode` no longer returns ambiguous 0 for both "no data" and "keypress 0". Now returns ERROR_NO_DATA.
- **kernel_main.asm** — all callers changed from `test eax` to `test edx` for error checking.
- **kernel build fixed**: all 15 objects (including TPM, nvme, pci) assemble and link into a 75884-byte kernel ELF. QEMU boots without serial output (pre-existing issue in kernel_main/entry code).
- **nvme.asm**, **pci.asm** — new untracked driver stubs from another agent; both assemble and link cleanly.
- `make check` passes: 7 ASM tests (ctype, math, runtime, serial, TPM, WASM, blake3) + C BLAKE3 via cmake/ctest.

### Known Remainders
- `make asm-kernel-hello` boots QEMU but produces no serial output — kernel_main or entry code may hang before serial init.
- `make check` fails on `zig fmt --check edgerun-zig` (4 unformatted files — out of scope).
- Monolithic files: `wasm_interpreter.asm` (5918 lines), `runtime.asm` (1561 lines), `math.asm` (1121 lines).
- C test harnesses need migration to pure ASM self-hosted runners.
