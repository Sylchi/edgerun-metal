# AGENTS.md

## Core Rules

- No fallbacks.
- Warnings are errors.
- Errors are fatal.
- No shortcuts.
- No external dependencies beyond what's required for self-hosted builds.
- All host-side production code is x86_64 assembly using the project's own macro DSL (`macros.inc`).
- No C, no Python, no CMake in host-side production code paths. Existing app-side Zig is transitional legacy code being ported to owned ASM/self-hosted paths; do not add new Zig code.
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
- **App-side** — application logic that runs inside the canonical host-side
  EdgeRun WASM interpreter. Existing Zig app sources are a temporary bootstrap
  surface and must be ported to owned ASM/self-hosted compiler paths to reach
  100% owned code. Do not add new Zig app code. Apps must have zero host
  assumptions: no syscalls, no libc, no POSIX, no platform intrinsics.
  Authority enters only through explicit EdgeRun import contracts backed by
  requirements and receipts.

## Workspace & Language

- **The project is consolidating to owned code on both sides of the boundary:**
  - **Host-side:** x86_64 assembly DSL defined in `kernel/x86_64/macros.inc` — `er_fn`, `er_fnstr`, `er_frame_push`, `er_push_all`, etc. This IS the dogfooding target. All host-side production code must be written in this DSL.
  - **App-side:** Existing Zig source compiled to WASM is legacy bootstrap code. Port app logic, UI contracts, object/grant helpers, media helpers, and host-facing app utilities to owned ASM/self-hosted source-to-WASM paths. Do not add new Zig files, tests, examples, generators, or app features. App-side code must not contain a competing WASM interpreter.
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
- `kernel/test/` — self-hosted ASM test runners and minimal platform stubs.
- `kernel/arm/pi/` — Raspberry Pi Zero W kernel, mailbox, EMMC, DWC2 USB.
- `kernel/host/` — Linux userspace ASM host tools, including `er_build.asm`,
  `er_asm`, `er_obj_body`, `er_obj_wrap`, Pi USB boot, and ESP32 serial boot.
- `kernel/driver/` — hardware drivers (serial, i8042, pci, virtio*, xhci, nvme, rtl8125, amdgpu, intel_*, i2c_hid, cros_ec, spi_flash, display, fb_text, etc.)
- `app/` — transitional app-side Zig frontend and browser-facing app runtime. Treat existing Zig as porting input, not a place for new implementation. App code compiles to WASM and runs on the canonical host-side WASM interpreter/import contract. Do not add an app-side WASM interpreter.

## External Dependencies (to eliminate)

### Build tools (minimum to bootstrap)
- `yasm` (or `nasm`) — assembler for the DSL. Long-term goal: own assembler.
- `ld` / `objcopy` (binutils) — linker. Long-term goal: own linker.

### Current bootstrap dependencies to eliminate
- `zig` — temporary bootstrap compiler for existing app-side code only. It is being eliminated; new Zig code is not allowed.

- `qemu-system-x86_64` and `qemu-system-arm` — emulator test environments.
- `arm-none-eabi-as`, `arm-none-eabi-ld`, `arm-none-eabi-objcopy` — Pi Zero W build/test tools.

## Required Commands

Do not add or expand shell build orchestration. Use the already-built owned
tools in `.build/host/`. If `.build/host/er_build` is missing on a fresh
checkout, bootstrap only the runner directly, then use its registry/object
commands.

```sh
mkdir -p .build/host
yasm -f elf64 -I kernel -o .build/host/er_build.o kernel/host/er_build.asm
ld -nostdlib -static -o .build/host/er_build .build/host/er_build.o
```

Owned runner checks:

```sh
./.build/host/er_build help
./.build/host/er_build test-list
./.build/host/er_build test-registry
./.build/host/er_build test-status
./.build/host/er_build x86-sources
./.build/host/er_build x86-objects
./.build/host/er_build validate-object kernel/test/registry.erobj
```

Source-object editing workflow:

```sh
printf 'replacement text' > .build/host/replacement.txt
./.build/host/er_build replace-range SOURCE.erobj OFFSET DELETE_LEN .build/host/replacement.txt .build/host/source-edited.asm.erobj
./.build/host/er_build validate-object .build/host/source-edited.asm.erobj
```

Source-object inspection workflow:

```sh
./.build/host/er_build view SOURCE.erobj
./.build/host/er_build body-to-file SOURCE.erobj .build/host/source-view.asm
./.build/host/er_build file-to-object .build/host/source-view.asm .build/host/source-edited.asm.erobj
./.build/host/er_build validate-object .build/host/source-edited.asm.erobj
```

Workflow rules:

- `.erobj` files are authoritative build data and source objects.
- Use `view` and `replace-range` for object-first edits. Files materialized under `.build/` are temporary inspection/debug views.
- Do not make `host-tools` rebuilds part of routine work. The goal is to get off host build tools, not preserve a rebuild loop around them.
- After editing `er_build.asm` or `er_asm.asm`, regenerate the matching `.asm.erobj` with `er_build file-to-object` and verify the existing owned tool path directly.
- If a workflow is missing, add an owned `er_build` command or registry object; do not add shell wrappers.

## Host-Side ASM Rules

- All new production code must be written in the project's ASM DSL (`macros.inc`).
- Do not add C test harnesses or C startup bridges.
- Build and link ASM tests directly through owned host tooling and `ld` until
  the repo-owned linker replaces `ld`.
- Keep behavior and tests coherent across `er_build.asm`, registry objects, and
  module-local tests.
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
Local transport cells use the Tor fixed-cell shape defined in
`kernel/x86_64/crypto/local_constants.inc`:
`[circ_id:4][cmd:1][payload:509]` for `LOCAL_CELL_SIZE = 514` bytes.
The cell is the universal IR — input events, network frames, storage requests,
display commands, and agent messages all route through this identity transport.

### Identities
Every process has a 32-byte identity (BLAKE3 hash of binary + TPM measurement).
Every device has a persistent TPM-backed identity. Identity kinds: USER, DEVICE, APP, STORAGE, RELAY, RESOURCE, OBJECT, EPHEMERAL, DELEGATED.

### Authorization & Resource Grants
Resources (RAM, storage, identity access) require a signed user grant.
See [`docs/authorization.md`](docs/authorization.md) for the full architecture:
app manifest → user prompt → signed receipt → TPM-mediated key hierarchy.

Grants are honest allocation contracts, not symbolic permissions over a hidden
shared pool. If an app is granted RAM, durable flush capacity, identity access,
display, input, clock, or Tor role authority, that resource is allocated in full
and owned by the app for the grant. If the grant or capacity is missing, the
capability does not exist. Do not model this as best-effort scheduling,
overcommit, implicit shared caches, passwords, sockets, paths, or ambient auth.

Apps route with the Tor protocol through the device relay and may manage their
own Tor-compatible routing only inside granted resources. App content is sealed
by the app through SDK tooling; user data is sealed for the USER identity;
device data is sealed for the DEVICE identity; object requirements carry who may
move, decrypt, verify, or flush the data.

### Route Table
A fixed-size table (16 entries) maps identity hash → SPSC ring buffer + handler.
- `er_local_route_register(id)` → slot_id
- `er_local_route_lookup(hash)` → slot_id
- `er_local_route_set_handler(slot, handler, flags)` → sync/async handler binding
- `er_local_cell_send_to_slot(slot, cell)` → pushes to identity's incoming ring

### Ring Buffers (Channels)
SPSC lock-free buffers, 64 slots of `LOCAL_CELL_SIZE` bytes each. Producer writes, consumer reads. Non-blocking — returns full/empty immediately.

### Circuits
A circuit caches destination slot_id for fast send.
- `er_local_open_circuit(dest_hash)` → fd
- `er_local_send_cell(fd, cell)` / `er_local_recv_cell(fd, out_cell)`
- `er_local_close_circuit(fd)`

Circuits are kernel-internal authority. `er_local_cell_imports` exposes only
constrained DA imports to WASM apps; raw route, slot, and circuit authority is
not an app import surface.

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
