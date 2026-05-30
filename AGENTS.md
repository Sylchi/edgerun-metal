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

## Architecture Boundary

The repository has two code worlds separated by a hard boundary:

- **Host-side** — runs on bare metal or Linux userspace. Written in x86_64
  assembly using the project's own DSL (`macros.inc`). Owns the kernel, drivers,
  boot path, PCI, MMIO, serial, TPM, framebuffer, WASM interpreter, render IR,
  UI shell, and all host tooling.
- **App-side** — Zig source compiled to WASM. Runs inside the EdgeRun WASM
  interpreter. Must have zero host assumptions: no syscalls, no libc, no POSIX,
  no platform intrinsics. Authority enters only through explicit EdgeRun
  import contracts backed by requirements and receipts.

## Workspace & Language

- **The project's own language is the x86_64 assembly DSL defined in `asm/x86_64/macros.inc`** — `er_fn`, `er_fnstr`, `er_frame_push`, `er_push_all`, etc. This IS the dogfooding target. All host-side production code must be written in this DSL.
- `asm/x86_64/` — canonical hardware-near implementation, organized by subsystem:
  - Root: `macros.inc`, `wasm_defines.inc`, `entry.asm`, `kernel_main.asm`, `efi_entry.asm`, `linker.ld`, `efi_linker.ld`
  - `drv/` — hardware drivers (serial, i8042, pci, virtio*, xhci, nvme, rtl8125, amdgpu, intel_*, i2c_hid, cros_ec, spi_flash, display, fb_text, etc.)
  - `rt/` — runtime library (runtime.asm, math.asm, ctype.asm, clock.asm, bytes.asm)
  - `crypto/` — blake3, preimage, identity, tor
  - `wasm/` — interpreter + compiler (wasm_interpreter, wasm_decode, wasm_exec, wasm_compiler*)
  - `net/` — net, arp, ipv4, tcp
  - `tpm/` — tpm.asm, tpm_crb.asm, tpm_constants.inc
  - `ui/` — ui_core, render_ir, sw_fb
  - `object/` — object.asm, object_constants.inc
- `asm/test/` — test files. Must be migrated from C to self-hosted ASM runners.
- `asm/arm/pi/` — Raspberry Pi Zero W kernel, mailbox, EMMC, DWC2 USB.
- `asm/host/` — Linux userspace host tools (Pi USB boot, ESP32 serial boot).
- `edgerun-zig/` — app-side Zig frontend (compiles to WASM). DEPRECATED for host paths. Being replaced by the self-hosted WASM compiler (`asm/x86_64/wasm_compiler*.asm`).
- `build.sh` — all build commands.

## External Dependencies (to eliminate)

### Build tools (minimum to bootstrap)
- `yasm` (or `nasm`) — assembler for the DSL. Long-term goal: own assembler.
- `make` — build orchestrator. Long-term goal: own build system.
- `ld` / `objcopy` (binutils) — linker. Long-term goal: own linker.

### Current test-time dependencies (being phased out)
- `cc` (gcc/clang) — used to compile C test harness + link ASM objects into freestanding static binaries.
- C startup crt0 stubs via `-ffreestanding -nostdlib`.
- `zig` — full Zig compiler + std lib (DEPRECATED, remove).

- `qemu-system-x86_64` — kernel test environment.

## Required Commands

All targets are in `build.sh`. No Makefile, no C, no Zig in production paths.

- Full repository check:
  - `./build.sh test` (all ASM tests)
- ASM module tests (builds and runs):
  - `./build.sh test-ctype`
  - `./build.sh test-math`
  - `./build.sh test-runtime`
  - `./build.sh test-serial`
  - `./build.sh test-wasm`
  - `./build.sh test-tpm`
  - `./build.sh test-blake3`
  - `./build.sh test-acpi`
  - `./build.sh test-preimage`
  - `./build.sh test-bytes`
  - `./build.sh test` (all of the above)
- ASM kernel build:
  - `./build.sh kernel`
  - `./build.sh kernel-hello` (build + QEMU launch)
- Clean:
  - `./build.sh clean`
- View targets:
  - `./build.sh help`

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
- **Commit and push all uncommitted work, including other agents' changes, regularly.** An uncommitted change is easily lost (power fail, agent crash) but trivially reverted once committed. A commit is a save, not a contract — `git revert` and `git reset` exist. The cost of losing work is far higher than the cost of reverting a bad commit.
- Use `git add -A` to stage all changes before committing.
- Check `git status --short --branch` before edits, before staging, and before committing.
- If a needed change overlaps another agent's work, stop and coordinate instead of resolving by force.
- Keep commit messages descriptive of what changed and why. Use `wip: checkpoint` for intermediate saves, `task: description` for coherent task commits.
- When changing the output path of a code generator, remove stale build artifacts from the old path. Do not leave orphaned files behind.

## Changelog

See [`CHANGELOG.md`](./CHANGELOG.md) for session history and detailed change logs.
