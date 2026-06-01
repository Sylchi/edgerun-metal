# EdgeRun

EdgeRun is a self-compiling app system with zero dependency chains.

The repository has two distinct code worlds with a hard boundary:

- **Host-side code** — x86_64 assembly using the project's own macro DSL
  (`kernel/x86_64/macros.inc`). This owns the kernel, drivers, boot path, PCI, MMIO,
  serial, TPM, framebuffer, interrupt management, and the WASM interpreter.
  No C, no Zig, no external runtime. Built with `yasm` + `ld` via `build.sh`.
- **App-side code** — Zig, compiled to WASM, running inside the canonical
  host-side EdgeRun WASM interpreter. Apps must have zero host assumptions:
  no syscalls, no libc, no POSIX, no platform intrinsics. Authority enters
  only through explicit EdgeRun import contracts backed by requirements and
  receipts.
  The Zig toolchain is being removed from production boot paths and retained
  only as an app-authoring frontend until the self-hosted compiler replaces it.

 Current production assets ~5MB expected to shrink while features are added. Goal is simple: computers do what they are good at — deterministically moving bytes. Data is controlled by its real owners. Zero waste. 

No package manager. No npm install. No hidden authority. No cloud compiler. Disk IO is only to store useful work results — everything else is compiled in. If your garbage needs terabytes of storage, good luck getting user permission. Your cache belongs to memory, which is 1000x faster anyway. This philosophy comes from literally creating this same work. A terabyte of disk writes per day is not inevitable — that's just how current compilers work. This repo proves we don't need that way of thinking. Your OS should fit in your NVRAM and shouldn't be able to spy on you. Today we give software authority over everything, then other software tries to claw it back. EdgeRun gives authority to the user.

No web framework. No pile of native dependencies. 

```text
one app
with its own source object
with its own UI system
with its own object store
with its own runtime receipts
that runs through web host, native, CPU, GPU, and real-hardware paths
```

The crazy part is not that it renders a page. The crazy part is that the app can
carry its source as data, edit that source inside its own memory, request a
successor artifact through the explicit build/runtime contract, and keep the
whole chain explainable.

## Why This Deserves Attention

Most software today is a stack of rented trust:

```text
cloud account -> package registry -> OS permissions -> host APIs -> app store -> opaque update
```

EdgeRun is trying to collapse that into something a person can actually reason
about:

```text
Here is the app.
Here is the source object.
Here is the build contract.
Here is what it asks for.
Here is what your machine granted.
Here is the receipt for what happened.
```

That makes the project interesting even before it is finished:

- Apps do not automatically inherit your files, network, devices, identity, or
  another app's memory.
- The UI is built into the system instead of outsourced to a web framework.
- The build path is part of the app loop instead of a separate developer
  machine ritual.
- Important data is stored as canonical objects, not vague files or hidden state.
- Work produces receipts, so execution can be replayed, checked, and explained.
- The same UI is being pushed through web host, CPU, GPU, Wayland, and DRM paths
  instead of becoming five separate app models.
- The codebase includes real boot, TPM, WASM, rendering, media, compiler, and Pi
  bring-up work, not just a whitepaper. Just open the link provided in the repo, open devtools to see nothing else is loaded after the initial load. Page navigation is instant, fonts are compiled in, icons are compiled in, image support is compiled in, video support is compiled in. Browser is just easy way to showcase, runs the same in native and work in progress to run on bare metal and replace your firmware too so you can have minimal amount of unaudited code. 

The promise is simple: an app should be able to carry its own tools, build its
own next version, run wherever it is granted resources, and explain what it did.

## The Short Version

EdgeRun treats apps as self-contained object graphs.

An EdgeRun app can contain source objects, UI components, media,
requirements, and receipts. When it wants to run, the local machine grants exact
slices of memory, storage, identity, and device authority. The app does its work
inside those bounds and emits receipts.

That changes what sharing software can mean. Instead of:

```text
install this and hope
```

the goal is:

```text
run this object
grant these exact resources
verify the receipt
```

## Repository Map

- `kernel/` — host-side code.
  - `kernel/x86_64/` — canonical hardware-near x86_64 ASM implementation: kernel,
    runtime, TPM, identity, BLAKE3, object serialization, network stack, render IR,
    UI shell, WASM interpreter, and WASM JIT/compiler work.
  - `kernel/driver/` — host ASM drivers for serial, PCI, ACPI, NVMe, display,
    virtio, xHCI, RTL8125, AMDGPU, Intel GPU, SPI flash, and related hardware.
  - `kernel/arm/pi/` — Raspberry Pi Zero W v1.1 kernel, VC mailbox, EMMC/SD,
    and DWC2 USB bring-up.
  - `kernel/host/` — x86_64 ASM Linux userspace host tools for Pi USB boot and
    ESP32 serial boot.
  - `kernel/test/` — self-hosted ASM test runners.
- `app/` — app-side Zig frontend. Zig remains an app-authoring path: source is
  compiled to WASM and run by the host-side EdgeRun interpreter/import contract.
  - `app/src/` — app object model, identity, clock, storage, grants, receipts,
    media, UI, UEFI smoke paths, Pi helpers, and host-facing dev tools.
  - `app/src/ui/` — shared app render contract consumed by web, CPU, Wayland,
    GLES, and DRM paths.
- `build.sh` — all build commands. No Makefile for production paths.
- `AGENTS.md` — working agreements, repository rules, and porting constraints.

## What Is Real In This Repo

- `./build.sh test` passes the current default self-hosted ASM test surface:
  runtime, drivers, HTTP/TLS/Tor, identity/local routing, AV1 media paths,
  WASM compiler/JIT, recursion validation, float opcodes, owned assembler smoke
  tests, and Pi emulator checks.
- `./build.sh kernel` builds the x86_64 kernel image with the current host-side
  ASM stack: drivers, TPM, local cells/routes/circuits, DA, WASM interpreter,
  WASM compiler/JIT pieces, Tor pieces, media codecs, and framebuffer/render IR.
- A Zig app-side core exists for canonical objects, identities, deterministic
  clocks, append-only storage, sealed movement, grants, manifests, receipts,
  and UI/component authoring.
- The host-side x86_64 ASM WASM compiler now has tested source-to-WASM slices,
  including the `test-wasm-compiler` path. It is not yet the full app compiler.
- The local cell/router layer is implemented as the kernel identity transport:
  fixed cells, SPSC rings, route registration, async handler polling, circuit
  helpers, and WASM import wrappers.
- The DA has a kernel-side surface registry, layer composition, focus tracking,
  and cell-dispatched surface/app messages. The remaining work is to close the
  full app loop through one canonical object/cell/receipt path.
- Raspberry Pi Zero W v1.1, ESP32 serial boot, AMDGPU, Intel GPU, storage,
  networking, and media paths have real build/test slices, but several still
  need hardware validation or deeper production behavior.

## Current Unification Path

The project is being consolidated around one critical loop:

```text
source object
  -> host-side compiler emits WASM
  -> canonical interpreter/JIT runs it
  -> app communicates by identity-routed cells
  -> DA/storage/network enforce grants
  -> receipts become canonical objects
```

Work that does not advance this loop should delete duplication, remove stale
alternate models, or move behavior behind the existing object/cell/receipt
contracts.

Temporary gaps still present:

- App authoring and the signing WASM guest still use Zig until the host-side
  compiler replaces enough of the source-to-WASM path.
- Some hardware paths are probe/test slices; the kernel should keep one explicit
  path per device class and delete placeholders as real behavior lands.


## Core Model

Everything is an object. Each device, app, allocator, UI surface, and storage instance is its own admission domain. No component has global meaning. No component gets ambient authority because it is a parent, storage layer, UI layer, transport, or device.

Authority is explicit and replayable: `user → machine → allocator → ui → app → storage`.

### Existing Primitives

- **clock** — deterministic epoch coordinates for replay and local admission
- **identity** — stable user, device, app, and delegated identities
- **object** — canonical content-addressed objects, owners, envelopes, child refs, requirements, receipts
- **storage** — append-only accepted-object log, recovery by replay, rebuildable projections
- **crypto** — hashing foundation used by object, identity, and storage

### Objects, Not Files

Nothing is a file. Everything that matters is a content-addressed object. Labels, paths, refs, indexes, and projections are rebuildable conveniences — not truth.

```
If it matters, it is an object.
If it grants authority, it is a receipt object.
If it changes state, it is a deterministic transition object or receipt.
```

### Slices And Ownership

Apps own explicit preallocated memory and storage slices. Sharing is separate from ownership — no share receipt, no access. The allocator records range ownership transitions without needing to read app memory.

### Requirements

`er_object_requirements_t` captures declarative constraints so admission can make deterministic state transitions:

- durability: volatile, durable, replicated
- confidentiality: public, integrity-only, app/user/device/layered private
- portability: machine-bound, user/app/public portable
- integrity: hash-only, signed, sealed
- lifetime: transient, session, cache, retained, pinned
- visibility: private, app namespace, user namespace, public

### Boundary Crossing

Transport is dumb. No object crosses a device boundary unless explicitly public, integrity-only, or sealed for the recipient scope. TLS is not the trust root — the object and receipt chain carry confidentiality, integrity, identity, and replay proof.

---

Detailed UI streaming and relay notes live in
[`app/docs/ui-architecture.md`](app/docs/ui-architecture.md).

## Try The Important Checks

```sh
./build.sh test
./build.sh kernel
```

Focused checks are registry-driven. Use `test-list` to discover the canonical
target names instead of copying a hand-maintained list from this README.

```sh
./build.sh test-list
./build.sh test-status
./build.sh test-status --core
./build.sh test-status test-wasm-jit test-local-route test-tor-hs-app
```

Build the standalone component WASM artifact:

```sh
cd app
zig build --cache-dir ../.build/app ui-components-wasm
```

Open the native UI preview:

```sh
cd app
zig build wayland-window
```

Build and run the main host-side kernel paths:

```sh
./build.sh kernel
./build.sh kernel-hello
./build.sh kernel-efi
./build.sh kernel-net-tpm
./build.sh kernel-tpm-live-test-qemu
```

Pi Zero W v1.1 bring-up:

```sh
./build.sh pi-kernel
./build.sh pi-usb-boot
```

## Working Rule

The repository rule is simple: implementation is truth.

Do not add fallbacks, compatibility shims, hidden alternate paths, or broad
authority. If behavior matters, encode it as deterministic objects, explicit
requirements, and receipts.

Contributor and agent rules are in [AGENTS.md](AGENTS.md).
