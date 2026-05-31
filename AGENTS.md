# AGENTS.md

## Core Rules

- No fallbacks.
- Warnings are errors.
- Errors are fatal.
- No shortcuts.
- No external dependencies beyond what's required for self-hosted builds.
- All host-side production code is x86_64 assembly using the project's own macro DSL (`macros.inc`).
- No C, no Python, no CMake in host-side production code paths. App-side code is Zig compiled to WASM — that is the intended workflow.
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
- **Removal-first rule: Before adding any new file, struct, function, or macro, find and remove at least as many lines of existing code without reducing functionality. Refactoring is the default. Addition is the exception. If you cannot find code to remove, you do not understand the existing code well enough to add.**
- **WASM recursion is banned.** All modules are validated at load time: `er_wasm_validate_no_recursion` performs a DFS over the decoded call graph and rejects any module whose direct `call` (opcode 0x10) instructions form a cycle with `ERROR_RECURSION` (31). There is no runtime call-depth check; the static validation is the sole enforcement. `call_indirect` cycles are not detected statically (the table can be modified at runtime) and remain a documented limitation.
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
- **App-side** — Zig source compiled to WASM. Runs inside the canonical
  host-side EdgeRun WASM interpreter. Must have zero host assumptions: no
  syscalls, no libc, no POSIX, no platform intrinsics. Authority enters only
  through explicit EdgeRun import contracts backed by requirements and receipts.

## Workspace & Language

- **The project has two languages, each owning its side of the boundary:**
  - **Host-side:** x86_64 assembly DSL defined in `kernel/x86_64/macros.inc` — `er_fn`, `er_fnstr`, `er_frame_push`, `er_push_all`, etc. This IS the dogfooding target. All host-side production code must be written in this DSL.
  - **App-side:** Zig source compiled to WASM. This is an app-authoring path for application logic that runs inside the host-side WASM interpreter. App-side code must not contain a competing WASM interpreter.
- `kernel/x86_64/` — canonical hardware-near implementation, organized by subsystem:
  - Root: `macros.inc`, `wasm_defines.inc`, `entry.asm`, `kernel_main.asm`, `efi_entry.asm`, `linker.ld`, `efi_linker.ld`
  - `drv/` — hardware drivers
  - `rt/` — runtime library (runtime.asm, math.asm, ctype.asm, clock.asm, bytes.asm)
  - `crypto/` — blake3, preimage, identity, tor, local_cell, local_route, local_circuit
  - `wasm/` — interpreter + compiler
  - `net/` — net, arp, ipv4, tcp
  - `tpm/` — tpm.asm, tpm_crb.asm, tpm_constants.inc
  - `agent/` — agent protocol, display agent (da.asm)
  - `ui/` — ui_core, render_ir, sw_fb
  - `object/` — object.asm, object_constants.inc
- `kernel/test/` — test files. To be migrated from C to self-hosted ASM runners.
- `kernel/arm/pi/` — Raspberry Pi Zero W kernel, mailbox, EMMC, DWC2 USB.
- `kernel/host/` — Linux userspace host tools (Pi USB boot, ESP32 serial boot).
- `kernel/driver/` — hardware drivers (serial, i8042, pci, virtio*, xhci, nvme, rtl8125, amdgpu, intel_*, i2c_hid, cros_ec, spi_flash, display, fb_text, etc.)
- `app/` — app-side Zig frontend and browser-facing app runtime. App code compiles to WASM and runs on the canonical host-side WASM interpreter/import contract. Do not add an app-side WASM interpreter.
- `build.sh` — all build commands.

## External Dependencies (to eliminate)

### Build tools (minimum to bootstrap)
- `yasm` (or `nasm`) — assembler for the DSL. Long-term goal: own assembler.
- `make` — build orchestrator. Long-term goal: own build system.
- `ld` / `objcopy` (binutils) — linker. Long-term goal: own linker.

### Current test-time dependencies (being phased out)
- `cc` (gcc/clang) — used to compile C test harness + link ASM objects into freestanding static binaries.
- C startup crt0 stubs via `-ffreestanding -nostdlib`.
- `zig` — full Zig compiler + std lib (DEPRECATED as host-side build dependency; still needed for app-side Zig→WASM compilation until the self-hosted WASM compiler replaces this path).

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
  - `./build.sh test-wasm-jit`
  - `./build.sh test-wasm-float`
  - `./build.sh test-recursion-valid`
  - `./build.sh test-recursion-invalid`
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
- The WASM interpreter in `kernel/x86_64/wasm/wasm_run.asm` is the canonical implementation.

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

## Routing Model

The kernel routes all inter-process communication by identity using fixed-size cells through SPSC ring buffers.

### Cell Format (Universal IR)
All I/O travels as 256-byte cells: `[circ_id:4][cmd:1][payload:251]`.
The cell is the universal IR — input events, network frames, storage requests, display commands, and agent messages all use it.

### Identities
Every process has a 32-byte identity (BLAKE3 hash of binary + TPM measurement).
Every device has a persistent TPM-backed identity. Identity kinds: USER, DEVICE, APP, STORAGE, RELAY, RESOURCE, OBJECT, EPHEMERAL, DELEGATED.

### Authorization & Resource Grants
Resources (RAM, storage, identity access) require a signed user grant.
See [`docs/authorization.md`](docs/authorization.md) for the full architecture:
app manifest → user prompt → signed receipt → TPM-mediated key hierarchy.

### Route Table
A fixed-size table (16 entries) maps identity hash → SPSC ring buffer + handler.
- `register_handler(id)` → slot_id
- `route_lookup(hash)` → slot_id
- `cell_send_to_slot(slot, cell)` → pushes to identity's incoming ring

### Ring Buffers (Channels)
SPSC lock-free buffers, 64 slots of 256 bytes each. Producer writes, consumer reads. Non-blocking — returns full/empty immediately.

### Circuits
A circuit caches destination slot_id for fast send.
- `open_circuit(dest_hash)` → fd
- `send(fd, cell)` / `recv(fd)` → cell / `close(fd)`

### Agent Dispatch
When a cell arrives for a registered identity, the kernel either synchronously calls the handler (SYNC flag) or leaves it in the ring buffer for the consumer to poll.

### Clock
Every kernel and app instance has a clock providing a verifiable stamp: `[keeper:32][tick:8][slot:8][epoch:8][era:8]`. The kernel clock advances on each pipeline tick. Each app has an independent tick rate adjustment knob — apps can tick at different rates (e.g., every N pipeline ticks, on demand, or in response to cell arrival). Stamps allow apps to sync data and prove recency/ordering. All limits are powers of two for efficient modular arithmetic. Clock boundaries (slot/epoch/era) enable periodic work scheduling without timers.

### Pipeline Model
The main loop (`kernel_main.asm`) is a round-robin pipeline:
  `clock_advance → net_poll → tor_poll → cell_poll → da_tick`
Each stage returns cells processed (0 = idle). The clock advances by 1 per iteration, giving every stage access to the current stamp for ordering and proof.

### Tor Integration
Legacy IP is accessed exclusively through Tor. The exit bridge registers as identity `edgerun.exit`. All IP-bound traffic addresses this identity — no native IP routing, no DNS in the kernel.

### Render IR (Display)
Display commands use a separate push-buffer of float arrays (not cells) for GPU-like batch rendering: rect buffers (15 floats/rect), icon buffers (9 floats/icon), vertex buffers (8 floats/vertex). The DA compositor processes these per frame tick.

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
