# Coherent System Roadmap

Purpose: define the ordered roadmap, milestones, and proof gates for the C
EdgeRun OS/runtime implementation of `edgerun-work` over erwire.

Intention: keep the runtime coherent by forcing app, UI, driver, storage, and
hardware work through content-addressed objects, scoped jurisdictions, admitted
routes, and typed endpoint adapters.

## System Invariants

- One OS/runtime project: `edgerun-metal`, `edgerun-ui-core`, `varfont`, and `edgerun-crypto` are cooperating runtime areas, not independent products.
- One boundary protocol model: `edgerun-work` protocol records carried by erwire.
- One authority model: identity-routed, recipient-sealed, admission-bound work.
- One jurisdiction model: every admission controls only the resources, route scope, budget, and policy window it is authorized to govern.
- One recipient-validation model: relay acceptance never implies recipient acceptance; every destination jurisdiction can reject relayed traffic independently.
- One storage model: content-addressed objects plus VFS labels; labels are manifest names, not authority.
- One UI model: admitted scene/render capability packets, never app-owned framebuffers.
- One app model: content-addressed Wasm packages launched from validated package objects and explicit budgets.
- One driver model: Wasm driver logic sends relay device-operation packets.
- One hardware model: endpoint adapters own local queues, registers, DMA, and firmware compatibility.
- One routing model: signed `WorkAdmission` records define relay paths; relay intents and transit records only move and prove admitted packets.
- One compatibility model: hardware, network, storage, scheduling, user policy, and application layers share record shapes and proofs without sharing authority.

## Authority Rule

No layer may turn its local authority into global authority.

- Hardware adapters may own queues, registers, DMA, and interrupts for admitted endpoint work only.
- Network relays may move packets and produce transit evidence only.
- Storage nodes may verify and store admitted typed object payloads only.
- UI renderers may draw admitted scene/render capability payloads only.
- Apps may accept only work that matches their own admission, capability, state, budget, and sequence rules.
- Drivers may accept only device-operation or completion traffic that matches their own admission, protocol state, budget, and sequence rules.
- Schedulers may allocate local time, memory, and execution slots only.
- Human relationship, group, and organization policy may admit access inside their own social or administrative scope only.
- Settlement may pay verified receipts and proofs only.

The shared contract is what lets these parts interoperate. The admissions remain
scoped to their jurisdictions. A device or relay can move junk toward another
jurisdiction, but that app, driver, renderer, or storage endpoint can reject it
without weakening the transport proof.

## Current Baseline

- `er_work` defines node identities, channel endpoints, work requests, admissions, capability envelopes, and relay transit records.
- `er_app` defines content-addressed Wasm app package manifests, identity, budget, usage, schedule, launch allocation, IPC route binding, and storage-source binding.
- `er_vfs` defines object packets, object labels, transform refs, and bounded object packet reassembly without host filesystem authority.
- `erwire` carries typed packets and can send/parse native EdgeRun Ethernet frames.
- `er_hw_relay` encodes firmware UDP, native Ethernet, and VirtIO endpoints.
- `er_native_boot` can poll native erwire ingress into deterministic accepted, malformed, or empty records, preserve accepted payload bytes, and classify admitted render capability relay packets as native endpoint intents.
- `edgerun-ui-core` provides backend-neutral UI scene, component, input, theme, layout, and render-budget records.
- `varfont` provides freestanding font parsing, shaping, rasterization, atlas, and UI text vertex generation.
- `edgerun-crypto` provides freestanding BLAKE3 hashing used by runtime records and tests.
- `wasm_vm` runs bounded Wasm modules with explicit hostcalls, including bounded `edgerun.relay/send` and `edgerun.relay/recv` imports.
- Relay sends are validated against serialized packet shape, app identity, admission id, budget token, and packet-byte budget before host relay dispatch.
- `er_work` can prepare and validate bounded capability envelope headers, including render capability invocations for app-authored scene payloads.
- `er_render_endpoint` can deterministically capture admitted render capability work, verify scene payload hashes, and decode endpoint-owned UI scenes after route, channel envelope, and render capability header verification.
- Wasm UI app `ui_emit` dispatch passes through render endpoint capture/decode before the OS loop consumes app scene state.
- The OS path can hold multiple Wasm UI apps concurrently as explicit runtime contexts with isolated preallocated memory, presentation identity, scene state, and app-switcher selection.
- App package identity is derived from app code, manifest, and UI asset object ids and lengths. Labels can name those objects inside manifests, but labels do not define package identity.
- VFS object packet reassembly validates packet order, offsets, payload hashes, packet ids, object id, and output capacity before returning loaded bytes.
- App package loading reassembles app code, manifest, and optional UI asset objects into caller-owned buffers and verifies they match the package manifest.
- The boot UI proof routes its embedded Wasm UI app through VFS object packets and storage-bound app package loading before each runtime prepares the module from persistent per-app bytes.
- App package storage sources bind a package id to admitted storage-retrieve route ids for the app, manifest, and optional UI assets.
- Storage endpoint object responses are adapted into package storage objects only when their route id, object id, length, packet list, and caller-owned destination memory satisfy the saved-package source and manifest before bytes can launch.

## Roadmap Target

The near-term target is one OS/runtime proof:

```text
EdgeRun EtherType frame on VirtIO-net
  -> erwire parser
  -> admitted work packet decode
  -> admission-defined route verification
  -> render endpoint scene decode and VirtIO GPU submission
  -> storage endpoint object response path
  -> bounded Wasm app relay receive for input or completion
```

The required invariant is one ingress, one carriage protocol,
admission-defined routes, typed endpoint adapters, and recipient-side validation
at each jurisdiction.

## Milestone 0: Single Roadmap And Documentation Source

Status: active.

Goal: keep planning and workflow documentation from diverging.

Implementation:

- Keep root `README.md` as the only first-party README.
- Keep this file as the roadmap and proof checklist.
- Keep architecture rationale in `docs/relay-architecture.md` and `docs/runtime-concepts-c-port.md`.
- Remove or reduce stale planning notes that repeat milestone lists.
- Keep `repo-check` enforcing the single first-party README rule.

Proof gate:

- `rg --files -g 'README*' -g '!third_party/**' -g '!ui/shadcn-ui/**'` returns only `README.md`.
- `make repo-check repo-test` passes.
- No first-party doc contains a conflicting milestone list.

## Milestone 1: OS-Loop Native Relay Ingress

Status: next implementation slice.

Goal: make the booted OS path poll native VirtIO-net erwire ingress after Boot
Services exit, not only in tests.

Entry criteria:

- VirtIO GPU OS path still boots and renders the first local scene.
- `er_native_boot_poll_relay_ingress` tests cover accepted, malformed, and empty ingress.
- Native Ethernet erwire parsing preserves accepted payload bytes and ingress endpoint metadata.

Implementation:

- Add native ingress state to `er_run_os_path`.
- Configure the PCI VirtIO-net erwire sink on the OS path.
- Poll native ingress from the post-boot OS/input/render loop.
- Convert accepted ingress into a route decode attempt.
- Classify every poll deterministically as none, malformed, unsupported, render intent, storage intent, or relay-forward intent.
- Emit deterministic acknowledgement or transit records for decoded admitted traffic.

Proof gate:

- Core tests cover OS-loop ingress dispatch for none, malformed, unsupported, and accepted packets.
- QEMU pcap shows EdgeRun EtherType `0x88b5` and erwire `ERW1` on VirtIO-net.
- Native run emits a deterministic relay acknowledgement or transit packet after accepted ingress.
- Packet-class matches without a valid admission produce no endpoint intent.

## Milestone 2: Admission-Defined Route Verification

Status: route primitives and first render endpoint-intent selection exist; signed
admission verification and multi-endpoint selection are next.

Goal: no endpoint adapter receives work unless the packet verifies against the
admission-defined route for that jurisdiction.

Entry criteria:

- Milestone 1 poll/dispatch path exists in the OS loop.
- Existing render capability intent tests pass.

Implementation:

- Decode accepted erwire payloads as relay packets carrying `edgerun-work` records.
- Verify `NetworkMessage` department, work type, sender, recipient, first relay, sequence, payload hash, and route commitment against the signed `WorkAdmission` path.
- Verify `CapabilityEnvelope` source, target, content type, risk flags, sequence, and payload hash against the admitted route.
- Verify jurisdiction before producing a local endpoint intent.
- Keep endpoint movement inside `er_hw_relay` or device-specific adapters.
- Reject malformed, stale, unsupported, over-budget, wrong-recipient, and wrong-jurisdiction traffic immediately.

Proof gate:

- Tests prove admitted render capability work produces a render endpoint intent.
- Tests prove admitted storage/object work produces a storage endpoint intent.
- Tests prove a valid admission for one jurisdiction cannot authorize another jurisdiction's endpoint.
- Tests prove malformed or unsupported admitted endpoints are rejected deterministically.
- Tests prove relay acceptance does not imply recipient acceptance.

## Milestone 3: Render Endpoint To VirtIO GPU

Status: render capture, scene hash verification, endpoint-owned scene decode, and
local OS-loop scene consumption exist; native ingress and VirtIO GPU endpoint
submission are next.

Goal: an admitted render capability packet received over erwire becomes an
endpoint-owned scene and is presented through the VirtIO GPU path.

Entry criteria:

- Milestone 2 route verification accepts render capability work.
- `er_render_endpoint_capture` and `er_render_endpoint_decode_scene_payload` tests pass.
- VirtIO GPU framebuffer create, attach, set-scanout, transfer, and flush tests pass.

Implementation:

- Extend endpoint intent data so render intent retains the scene payload needed for endpoint decode.
- Route native render ingress through the same render endpoint capture/decode path used by local Wasm UI app dispatch.
- Submit decoded endpoint-owned scene output through the VirtIO GPU surface path.
- Keep GOP as bootstrap compatibility only.
- Keep apps targeting admitted UI scene packets, not framebuffers.

Proof gate:

- Unit tests feed admitted render capability work through erwire, route verification, render capture, and scene decode.
- Tests reject scene payload hash mismatch, wrong source, wrong target, wrong sequence, wrong department, and wrong risk flags.
- QEMU or host proof shows the same app-authored scene hash before endpoint-specific drawing.
- UI proof renders the scene through the VirtIO GPU endpoint path.

## Milestone 4: Storage Endpoint To Object Runtime

Status: package loading can consume storage-bound object responses after route,
object id, length, packet list, and destination memory validation.

Goal: saved or user-authored app packages load from admitted storage endpoint
responses instead of embedded package packet sources.

Entry criteria:

- Milestone 2 route verification accepts storage/object work.
- App package storage source, storage object, and storage-bound package load tests pass.

Implementation:

- Accept admitted storage/object work at a storage endpoint.
- Start with deterministic acknowledgement or capture after route verification.
- Convert accepted endpoint responses into `ErAppPackageStorageObject` values.
- Replace the embedded package packet source in the boot UI path with endpoint-backed responses that satisfy admitted storage-source route ids and object identities.
- Keep VFS labels as manifest labels only.
- Add VirtIO block queue support only after the object endpoint contract is proven.

Proof gate:

- Unit tests feed admitted object work through erwire and route verification to storage.
- Tests reject wrong route id, wrong object id, wrong object length, packet tampering, packet order errors, output capacity errors, and unexpected assets.
- QEMU proof carries admitted storage work from native ingress to the storage endpoint.
- Later QEMU proof writes and reads the same content-addressed object bytes through VirtIO block.

## Milestone 5: Wasm App Relay Receive Loop

Status: bounded relay send/receive imports, concurrent local Wasm UI app
contexts, content-addressed launch, render relay-send proof, render endpoint
capture, and endpoint-owned scene decode exist.

Goal: apps receive input, completion, or endpoint-result packets through
`edgerun.relay/recv` rather than hidden host-side state.

Entry criteria:

- Milestone 3 render endpoint path can produce deterministic render acceptance or rejection.
- Milestone 4 storage endpoint path can produce deterministic storage acceptance or rejection.
- Existing Wasm relay send/receive bounds tests pass.

Implementation:

- Define the first input/completion packet shape for the boot UI proof.
- Queue endpoint results into each app runtime's declared relay inbox window.
- Feed shell input or endpoint completion packets through `edgerun.relay/recv`.
- Preserve per-app runtime isolation, presentation identity, scene state, and app-switcher selection.
- Charge packet-byte and receive budgets before mutating app-visible inbox state.

Proof gate:

- Wasm fixture receives a completion packet through `edgerun.relay/recv`.
- Wasm fixture receives an input packet through `edgerun.relay/recv`.
- Tests reject wrong target app, insufficient inbox capacity, malformed packet, stale sequence, budget overflow, and over-limit packet bytes.
- Failed receive attempts do not mutate app usage or inbox state.

## Milestone 6: User-Authored App Package Proof

Status: boot-local package-loaded app launch exists; saved package endpoint
integration is pending.

Goal: launch a user-authored Wasm UI app from admitted storage objects and drive
its UI exclusively through relay send/receive.

Entry criteria:

- Milestone 4 storage endpoint responses can load package objects.
- Milestone 5 relay receive loop exists.

Implementation:

- Treat app Wasm, manifest, UI assets, and fonts as content-addressed objects.
- Load package objects from admitted storage responses into caller-owned buffers.
- Launch the app only after package id, object ids, lengths, route ids, and packet hashes validate.
- Emit render scene or scene-delta capability packets through `edgerun.relay/send`.
- Receive input/completion packets through `edgerun.relay/recv`.

Proof gate:

- Tests prove identical package objects produce identical package ids independent of labels.
- Tests prove package launch rejects path-like labels as authority.
- Tests prove tampered manifest bytes, wrong object ids, wrong route ids, and unexpected asset objects fail before runtime launch.
- QEMU proof launches the package and presents its scene through the render endpoint path.

## Milestone 7: Distributed UI

Status: not started.

Goal: prove app logic and UI rendering are location-independent.

Entry criteria:

- Milestone 6 user-authored app proof passes locally.
- Render endpoint route verification handles more than one renderer route.

Implementation:

- Give one app two admitted render routes.
- Emit the same scene payload to both routes.
- Render locally through VirtIO GPU and remotely or virtually through a second renderer endpoint.
- Route input back as ordered input capability packets.
- Keep shell placement and focus policy outside app authority.

Proof gate:

- Both renderer routes receive the same scene hash.
- Local VirtIO GPU render and second endpoint capture/render agree on scene identity.
- Input returns to the app on an ordered input capability route.
- One renderer admission cannot grant focus, placement, or authority for the other renderer.

## Milestone 8: Relay-Native Driver ABI

Status: direct PCI/MMIO hostcalls exist as bring-up scaffolding.

Goal: move durable driver behavior from direct bus hostcalls to admitted relay
device-operation packets.

Entry criteria:

- Milestone 5 relay receive loop exists for completions.
- Device endpoint route verification exists for at least one local hardware queue.

Implementation:

- Run driver logic as Wasm.
- Submit device-operation packets over erwire.
- Execute operations at the device endpoint that owns local hardware queues or registers.
- Return completions over erwire.
- Keep direct PCI/MMIO hostcalls only where explicitly marked as bring-up scaffolding.

Proof gate:

- Driver Wasm emits a device-operation packet without using direct bus hostcalls for its durable ABI.
- Device endpoint executes or captures the operation deterministically.
- Completion packet returns over erwire and is received through `edgerun.relay/recv`.
- The same device-operation packet routes locally or remotely without changing the driver ABI.

## Milestone 9: Runtime-Owned Device Continuity

Status: partial. VirtIO GPU and VirtIO-net paths exist; firmware services still
serve bootstrap roles.

Goal: after Boot Services exit, relay, rendering, storage, input, scheduling,
and app execution continue through runtime-owned devices and explicit minimal
stubs only.

Entry criteria:

- Milestones 1 through 6 pass in QEMU or host deterministic tests.
- Render and storage endpoint adapters no longer depend on firmware networking or host filesystem authority.

Implementation:

- Keep runtime logging independent of firmware networking.
- Keep receive path on VirtIO-net.
- Keep render path on VirtIO GPU.
- Keep storage path as sealed object movement with endpoint adapter ownership.
- Replace or explicitly stub remaining device discovery, memory ownership, interrupts, and timer dependencies.

Proof gate:

- QEMU native proof boots, logs, receives, routes, persists or captures storage, and renders UI without EFI network services.
- No production path depends on host libc, host files, host sockets, or firmware networking for relay operation.
- `make check` passes with warnings as errors.

## Freeze Rule

Do not reintroduce standalone native, TPM, GPU, storage, or networking debug boot
profiles. Device code belongs behind the OS path and relay endpoint adapters.

New work should remove firmware-service dependencies from relay, rendering,
storage, input, scheduling, and app execution instead of adding compatibility
paths.

## Standard Verification

For a focused implementation slice:

```bash
make repo-progress REPO_PROGRESS_SCOPE=edgerun-metal REPO_PROGRESS_TEST=edgerun-check
```

Before committing a completed milestone or proof gate:

```bash
make check
```
