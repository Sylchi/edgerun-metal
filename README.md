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
- `AGENTS.md` — working agreements, session history, porting rules.

## What Is Real In This Repo

- A Zig core for canonical objects, identities, deterministic clocks,
  append-only storage, sealed movement, grants, manifests, and receipts.
- A deterministic x86_64 ASM EdgeRun WASM interpreter for running app code
  without WASI or a fake host filesystem.
- A host-side x86_64 ASM WASM compiler emitter. The first committed slice emits
  deterministic exported `i32.const` modules into caller-owned memory and proves
  them through the canonical interpreter.
- App containment tests for host-mediated spawn, reclaim, and child-memory
  boundaries.
- App authoring is converging on host-side compilation to WASM followed by the
  canonical interpreter/JIT path. There is no browser app-runtime contract.
- A shared app render contract consumed by web host, CPU software rendering,
  Wayland, GLES, and DRM/GBM host paths.
- Repo-owned font, SVG icon, image, video, and audio decode/render paths.
- QEMU-smoked immutable-kernel work for boot resources, memory contracts, WASM
  launch, work receipts, registry routing, `ExitBootServices`, and TPM/swtpm
  verification.
- Raspberry Pi Zero W v1.1 kernel and USB boot tooling for real hardware
  bring-up.


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

## UI Streaming Architecture

### Core Principle

If it crosses a device boundary, it is an object.

Everything that moves between devices — IR frames, input events, hit results, image textures, video frames — is a canonical `object.zig` `Kind.bytes` or `Kind.tree` payload.

### Object Types

| What | Object Kind | Body | Reference |
|------|------------|------|-----------|
| App IR frame | `bytes` | `ir.BodyHeader` + float arrays | `render/ir.zig`: `encodeBody` / `applyBody` |
| Composited IR frame | `bytes` | Same format, merged output | `render/compositor.zig`: `compose` |
| Image texture | `bytes` | `ERIMG001` tiled RGBA | `media/image_object.zig` |
| Input event | `bytes` | Binary event record | `app_input_event.zig` |
| Hit result | `bytes` | Hit ID + position + scope | compositor output |

### Pipeline

```
Device A (app host)                          Device B (renderer)
 App produces IR                              receive object
  → ir.encodeBody()       object bytes         → View.decode()
  → object.bytesNode()   ─────────────────→   → applyBody()
                         (BT / WiFi)          → backend renders

 Media decoded locally                        receive image object
  → ERIMG tiles           object body          → ERIMG decode
  → object.bytesNode()   ─────────────────→   → upload as texture
                                               → IR references it
```

### Compositor

The compositor is pure IR-in/IR-out data transformation. No framebuffer, no pixel ops, no software backend dependency. Compiles to WASM.

- Receives serialized IR objects from apps, tagged with a `Layer`
- Merges by fixed Z-order: scrim < menu < popover < modal < toast
- Applies cursor IR based on latest pointer position
- Outputs serialized merged IR object for backends
- Performs hit-testing on the merged spatial layout

### Media As Objects

Images and video frames are decoded on the source device into `ERIMG001` tiled RGBA (`media/runtime_image.zig`), wrapped as `Kind.bytes` objects by `media/image_object.zig`. On the receiver, the body is decoded back into ERIMG tiles, uploaded as a GPU texture, and referenced by `IR.image_vertices`. No raw pixel stream crosses the device boundary.

### Fragmentation

Large payloads use `Kind.tree` — children with offset/len fields provide built-in reassembly:
```
tree object (logical_len = 74 KB)
  ├─ child offset=0    len=256
  ├─ child offset=256  len=256
  └─ ...
```
No separate fragment protocol. See `object.zig`: `Child`, `View.decode`.

### Module Boundaries

| Module | Responsibility | WASM |
|--------|---------------|------|
| `render/ir.zig` | IR types, push functions, body encode/decode | no |
| `render/compositor.zig` | IR merge by layer, overlay system | yes |
| `render/pipeline.zig` | Scene→IR packing, text rasterization, presentation | no |
| `render/backends/` | Pixel-level renderers (sw, gles) | no |
| `media/runtime_image.zig` | ERIMG001 tiled RGBA encode/decode | yes |
| `media/image_object.zig` | ERIMG ↔ object envelope | yes |
| `ui_codec.zig` | ERUI001 component tree decode | yes |
| `ui_renderer.zig` | Component tree → IR (WASM-facing) | yes |
| `app_input_event.zig` | Input event binary format | yes |
| `object.zig` | Canonical object format | yes |
| `runtime/render.zig` | Frame orchestration (scene→IR→render) | no |

---

## UI Relay Architecture

### Domain Separation

UI is not a root authority. It never knows what the objects mean — it renders slots and emits narrow intent receipts. The UI domain and App domain communicate only over a message channel (the "relay"):

```
user hits (x,y)  →  UI emits "slot 7 activated"  →  App resolves to action
app updates      →  App emits scene description   →  UI renders natively
```

### Authority Boundary

```
user → input device → [UI Domain] → relay → [App Domain] → storage/network
                             ↓                         ↓
                      scene renderer              business logic
                      zero authority               full authority
                      no state                      owns state
```

The UI domain renders whatever scene it receives, collects raw input, and has no access to storage, identity keys, or app data. The App domain owns all business logic, state, and data.

### Relay Protocol

Messages are self-contained binary packets with a 12-byte header:

```
Offset  Size  Field
0       4     magic: 0x4552524C ("ERRL")
4       1     version: 0x01
5       1     message_type
6       4     sequence_number
10      2     payload_length
```

| Type | Code | Direction | Payload |
|------|------|-----------|---------|
| SceneUpdate | 0x01 | App → UI | packed Render IR scene |
| InputEvent | 0x02 | UI → App | serialized input events |
| Resize | 0x03 | UI → App | viewport width/height |
| Hover | 0x04 | UI → App | pointer x/y |
| IntentReceipt | 0x05 | UI → App | user intent receipt |
| Ack | 0x80 | bidirectional | acked sequence number |

### Transport Abstraction

The same binary format works over same-process coroutines, serial/UART (HDLC-style 0x7E framing), BLE advertisements (31-byte limit), and TCP/UDP (length-prefixed).

### Multi-Device

A single app broadcasts its scene to multiple UI hosts. Each renders independently. Input from any device flows back to the app. Devices may have different resolutions and input capabilities.

---

## Try The Important Checks

```sh
./build.sh test
```

Focused checks:

```sh
./build.sh test-ctype
./build.sh test-clock
./build.sh test-http
./build.sh test-serial
./build.sh test-sw-fb
./build.sh test-render-ir
./build.sh test-wasm-compiler
./build.sh test-wasm-jit
./build.sh test-wasm-float
./build.sh test-recursion-valid
./build.sh test-recursion-invalid
./build.sh test-fe-mul
./build.sh test-spi-flash
./build.sh test-tor
./build.sh test-x25519
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
