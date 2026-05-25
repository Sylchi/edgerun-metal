# edgerun-c

`edgerun-c` is the current EdgeRun implementation workspace. The repository name
is historical: the active core implementation has moved to Zig, while the
BLAKE3 crypto package remains C/CMake.

The project model is documented in [EDGE_MODEL.md](EDGE_MODEL.md). The short
version is that canonical objects, identities, deterministic clock coordinates,
append-only storage, seals, grants, and explicit admission records are the
system boundary. Transport, UI, storage media, and hardware bring-up paths move
or present those records; they do not become authority roots.

## Current Layout

- `edgerun-zig/`: primary implementation workspace.
  - `src/clock.zig`: deterministic epoch coordinates.
  - `src/identity.zig`: canonical identity derivation and identity ids.
  - `src/object.zig`: canonical object bytes, ids, requirements, and
    verification.
  - `src/store.zig`: append-only accepted-object storage and replay state.
  - `src/seal.zig`, `src/sync.zig`, `src/relay.zig`: sealed object movement and
    receipt-shaped transfer paths.
  - `src/wasm/`: deterministic WASM interpreter path used for EdgeRun app
    authoring, parent-visible preview, release, and allocator-scoped execution.
  - `src/tpm.zig`, `src/tls_tpm.zig`, `src/tpm_acpi.zig`: TPM-backed authority
    and TLS-adjacent primitives.
  - `src/ui.zig`, `src/ui_components.zig`, `src/ui_resolver.zig`,
    `src/renderer_*.zig`: current UI core, component, resolver, and renderer
    work.
  - `src/pi_zero_w_v1_1*.zig`, `src/pi_mmc.zig`, `src/bcm2708_usb_boot.zig`,
    `src/pi_usb_*`: Raspberry Pi Zero W v1.1 bring-up and USB boot tooling.
- `edgerun-crypto/`: C/CMake BLAKE3 implementation, tests, and benchmark.
- `edgerun-clock/`, `edgerun-identity/`, `edgerun-object/`,
  `edgerun-storage/`: package shells kept during the C-to-Zig transition. The
  current implementations are the Zig modules listed above.
- `edgerun-metal/`: older C metal primitives still present in the tree. Do not
  treat this as the authoritative core for clock, identity, object, storage, or
  UI work unless the task explicitly targets it.
- `.build/`: local build output. Keep generated artifacts here and out of Git.

## Build And Test

Use the top-level `Makefile` for normal checks:

```sh
make check
make zig-fmt-check
make zig-test
make crypto-test
```

Focused Zig module tests:

```sh
make clock-test
make identity-test
make object-test
make storage-test
make ui-core-test
```

The same Zig steps are available directly through `edgerun-zig/build.zig`:

```sh
zig build --build-file edgerun-zig/build.zig --cache-dir .build/edgerun-zig test
zig build --build-file edgerun-zig/build.zig --cache-dir .build/edgerun-zig clock-test
zig build --build-file edgerun-zig/build.zig --cache-dir .build/edgerun-zig identity-test
zig build --build-file edgerun-zig/build.zig --cache-dir .build/edgerun-zig object-test
zig build --build-file edgerun-zig/build.zig --cache-dir .build/edgerun-zig storage-test
zig build --build-file edgerun-zig/build.zig --cache-dir .build/edgerun-zig ui-core-test
```

Other useful Zig build steps:

```sh
zig build --build-file edgerun-zig/build.zig --cache-dir .build/edgerun-zig sdk-test
zig build --build-file edgerun-zig/build.zig --cache-dir .build/edgerun-zig sdk-cli -- simulate standard
zig build --build-file edgerun-zig/build.zig --cache-dir .build/edgerun-zig component-gallery-test
zig build --build-file edgerun-zig/build.zig --cache-dir .build/edgerun-zig ui-snapshot
zig build --build-file edgerun-zig/build.zig --cache-dir .build/edgerun-zig ui-browser
```

The real TPM check only belongs on a machine with the expected TPM device:

```sh
make zig-real-tpm
```

## Pi Zero W v1.1 Bring-Up

Build the kernel image:

```sh
make pi-zero-w-v1_1-kernel
```

Load over USB:

```sh
make pi-usb-load
```

The Pi USB bring-up path uses the repo-owned Zig host loader and the explicit
boot-firmware exception needed for the Broadcom mask-ROM/GPU boot chain to load
repo-owned `kernel.img` on Pi Zero W v1.1 hardware. That exception does not
permit vendor drivers, protocol stacks, control planes, compatibility layers, or
general binary dependencies.

## Repository Rules

The operational rules for agents and contributors are in [AGENTS.md](AGENTS.md).
The important defaults are:

- No fallbacks, shims, compatibility layers, or hidden alternate paths.
- Warnings are errors; errors are fatal.
- Production code must be freestanding and must not depend on host libc.
- Tests must cover touched behavior.
- Canonical object bytes are the object boundary.
- Prefer deleting stale parallel code over keeping competing implementations.
- Keep one Git repository with no nested `.git` directories or submodules.

When changing core behavior, update the code and tests first. Documentation
should describe the implementation that exists, not an intended parallel design.

## App Authoring Model

EdgeRun apps are meant to author and share other EdgeRun apps. A draft app can
run under the WASM interpreter inside its parent with parent-visible memory for
preview and debugging. Releasing the draft promotes it into canonical app
objects and a manifest; allocator admission then moves memory and storage into
child-owned slices. The parent keeps handles and receipts, not direct memory
visibility, unless the child explicitly shares a view back.

Shared executables are object graphs plus requirements and receipts. They do not
inherit network, storage, device, identity, or parent memory authority. The
recipient user's allocator grants the slices and capabilities needed to run the
app.
