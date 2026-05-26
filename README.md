# EdgeRun

EdgeRun is an experiment in making computers trustworthy again.

Today, most apps borrow trust from clouds, app stores, operating systems,
accounts, permissions, and invisible background services. EdgeRun tries a
stricter idea:

```text
If an app does work, it should be able to prove what it used,
what it touched, who allowed it, and what came out.
```

That proof is built from small records: objects, identities, clocks, grants,
sealed messages, and receipts.

## Why This Deserves Attention

EdgeRun is not another app framework. It is a way to run software where authority
is explicit instead of ambient.

- Apps do not automatically inherit your files, network, devices, identity, or
  another app's memory.
- Important data is stored as canonical objects, not vague files or hidden app
  state.
- Work produces receipts, so execution can be replayed, checked, and explained.
- A parent app can help create a child app, but a released child owns its own
  memory unless it explicitly shares something back.
- The same UI is being pushed through browser, CPU, GPU, Wayland, and DRM paths
  instead of becoming five separate app models.
- The project includes real boot, TPM, WASM, rendering, media, and Pi bring-up
  work, not just a whitepaper.

The simple promise is this: software should come with an audit trail ordinary
people can understand.

## The Short Version

EdgeRun treats apps as object graphs plus requirements.

When an app wants to run, the local machine grants exact slices of memory,
storage, identity, and device authority. The app does its work inside those
bounds and emits receipts. Those receipts can explain, in concrete terms, what
was allowed and what happened.

That makes sharing software different. Instead of "install this package and hope
it behaves," the goal is closer to:

```text
Here is the app object.
Here is what it asks for.
Here is what your machine granted.
Here is the receipt for the work it performed.
```

## What Is Real In This Repo

- A Zig core for canonical objects, identities, deterministic clocks,
  append-only storage, sealed movement, grants, manifests, and receipts.
- A deterministic EdgeRun WASM interpreter for running app code without WASI or
  a fake host filesystem.
- App containment tests for host-mediated spawn, reclaim, and child-memory
  boundaries.
- A browser app that embeds repo source as an object, edits it in WASM-owned
  memory, and runs an embedded compiler path toward successor WASM.
- A shared UI/render contract consumed by browser, CPU software rendering,
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
- `edgerun-zig/src/ui_browser.zig`: browser app entry point.
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

Build the browser app:

```sh
zig build --build-file edgerun-zig/build.zig --cache-dir .build/edgerun-zig ui-browser
cd edgerun-zig/zig-out
python3 -m http.server 8765 --bind 127.0.0.1
```

Then open:

```text
http://127.0.0.1:8765/web/index.html
```

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
