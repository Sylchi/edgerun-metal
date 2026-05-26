# EdgeRun

EdgeRun is a self-compiling app system with zero dependency chains.

No package manager. No npm install. No WASI filesystem trick. No cloud compiler.
No web framework. No pile of native dependencies.

```text
one app
with its own compiler
with its own UI system
with its own object store
with its own runtime receipts
that runs through web host, native, CPU, GPU, and real-hardware paths
```

The crazy part is not that it renders a page. The crazy part is that the app can
carry its source as data, edit that source inside its own memory, compile the
next app artifact, and keep the whole chain explainable.

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
Here is the compiler object.
Here is what it asks for.
Here is what your machine granted.
Here is the receipt for what happened.
```

That makes the project interesting even before it is finished:

- Apps do not automatically inherit your files, network, devices, identity, or
  another app's memory.
- The UI is built into the system instead of outsourced to a web framework.
- The compiler path is part of the app loop instead of a separate developer
  machine ritual.
- Important data is stored as canonical objects, not vague files or hidden state.
- Work produces receipts, so execution can be replayed, checked, and explained.
- The same UI is being pushed through web host, CPU, GPU, Wayland, and DRM paths
  instead of becoming five separate app models.
- The codebase includes real boot, TPM, WASM, rendering, media, compiler, and Pi
  bring-up work, not just a whitepaper.

The promise is simple: an app should be able to carry its own tools, build its
own next version, run wherever it is granted resources, and explain what it did.

## The Short Version

EdgeRun treats apps as self-contained object graphs.

An EdgeRun app can contain source, compiler bytes, UI components, media,
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

## What Is Real In This Repo

- A Zig core for canonical objects, identities, deterministic clocks,
  append-only storage, sealed movement, grants, manifests, and receipts.
- A deterministic EdgeRun WASM interpreter for running app code without WASI or
  a fake host filesystem.
- App containment tests for host-mediated spawn, reclaim, and child-memory
  boundaries.
- An app runtime that embeds repo source as an object, edits it in WASM-owned
  memory, and runs an embedded compiler path toward successor WASM.
- A shared app render contract consumed by web host, CPU software rendering,
  Wayland, GLES, and DRM/GBM host paths.
- Repo-owned font, SVG icon, image, video, and audio decode/render paths.
- QEMU-smoked immutable-kernel work for boot resources, memory contracts, WASM
  launch, work receipts, registry routing, `ExitBootServices`, and TPM/swtpm
  verification.
- Raspberry Pi Zero W v1.1 kernel and USB boot tooling for real hardware
  bring-up.

The long-form model is in [EDGE_MODEL.md](EDGE_MODEL.md).

## Repository Map

- `edgerun-zig/`: active implementation workspace.
- `edgerun-zig/src/clock.zig`: deterministic clock coordinates.
- `edgerun-zig/src/identity.zig`: user, device, app, and delegated identities.
- `edgerun-zig/src/object.zig`: canonical object bytes, ids, requirements, and
  verification.
- `edgerun-zig/src/store.zig`: accepted-object storage and replay state.
- `edgerun-zig/src/app.zig`: app manifests, execution receipts, and containment
  tests.
- `edgerun-zig/src/wasm/`: deterministic EdgeRun WASM interpreter.
- `edgerun-zig/src/render/`: shared render IR, presentation receipts, software
  and GPU paths.
- `edgerun-zig/src/app_runtime.zig`: app runtime entry point.
- `edgerun-zig/src/content/`: kernel resource inventory, contracts, authority,
  and WASM launch work.
- `edgerun-zig/src/immutable_kernel_*.zig`: QEMU UEFI kernel smokes.
- `edgerun-zig/src/pi_zero_w_v1_1*.zig`: Pi Zero W v1.1 bring-up.
- `edgerun-crypto/`: C/CMake BLAKE3 package.
- `edgerun-clock/`, `edgerun-identity/`, `edgerun-object/`,
  `edgerun-storage/`: transition-era package shells; the current
  implementations are in Zig.

## Try The Important Checks

```sh
make check
```

Focused checks:

```sh
make zig-fmt-check
make zig-test
make crypto-test
make clock-test
make identity-test
make object-test
make storage-test
make ui-core-test
```

Build the app runtime:

```sh
zig build --build-file edgerun-zig/build.zig --cache-dir .build/edgerun-zig app-runtime
cd edgerun-zig/zig-out
python3 -m http.server 8765 --bind 127.0.0.1
```

Then open:

```text
http://127.0.0.1:8765/web/index.html
```

Build the GitHub Pages artifact locally:

```sh
make pages-check
```

The Pages artifact is written to `.build/github-pages`. The GitHub workflow
publishes that directory only after serving the artifact locally and
instantiating the generated runtime WASM through the `/bin/` URL shape that the
browser entry point uses.

Run the main kernel smokes:

```sh
cd edgerun-zig
./tools/run-immutable-kernel-qemu.sh
./tools/run-immutable-kernel-runtime-qemu.sh
./tools/run-immutable-kernel-exit-boot-qemu.sh
./tools/run-immutable-kernel-swtpm-qemu.sh
```

Pi Zero W v1.1 bring-up:

```sh
make pi-zero-w-v1_1-kernel
make pi-usb-load
```

## Working Rule

The repository rule is simple: implementation is truth.

Do not add fallbacks, compatibility shims, hidden alternate paths, or broad
authority. If behavior matters, encode it as deterministic objects, explicit
requirements, and receipts.

Contributor and agent rules are in [AGENTS.md](AGENTS.md).
