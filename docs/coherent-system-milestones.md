# Coherent System Milestones

Purpose: define the ordered implementation checklist and proof artifacts for the C runtime's implementation of the `edgerun-work` relay system.

Intention: remove parallel implementations by forcing every app, UI, driver, storage, and hardware path through content-addressed objects and erwire relays.

## System Invariants

- One boundary protocol model: `edgerun-work` protocol records carried by erwire.
- One authority model: identity-routed, recipient-sealed, admission-bound work.
- One jurisdiction model: every admission controls only the resources, route scope, budget, and policy window it is authorized to govern.
- One storage model: content-addressed objects plus VFS labels.
- One UI model: admitted scene/render capability packets, never app-owned framebuffers.
- One driver model: Wasm driver logic sends relay device-operation packets.
- One hardware model: endpoint adapters own local queues, registers, DMA, and firmware compatibility.
- One routing model: signed `WorkAdmission` records define relay paths; relay intents and transit records only move and prove admitted packets.
- One compatibility model: hardware, network, storage, scheduling, user policy, and application layers share record shapes and proofs without sharing authority.
- One recipient-validation model: relay acceptance never implies recipient acceptance; every destination jurisdiction can reject relayed traffic independently.

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

- `er_work` defines the C mirror of `edgerun-work` node identities, channel endpoints, work requests, admissions, capability envelopes, and relay transit records.
- `er_app` defines content-addressed Wasm app package manifests, identity, budget, usage, schedule, launch allocation, and IPC route binding.
- `er_vfs` defines object packets, object labels, transform refs, and bounded object packet reassembly without host filesystem authority.
- `erwire` carries typed packets and can send/parse native EdgeRun Ethernet frames.
- `er_hw_relay` encodes firmware UDP, native Ethernet, and VirtIO endpoints.
- `er_native_boot` can poll native erwire ingress into deterministic accepted, malformed, or empty records, preserve accepted payload bytes, and classify admitted render capability relay packets as native endpoint intents.
- `edgerun-ui-core` provides backend-neutral UI scene records.
- `wasm_vm` runs bounded Wasm modules with explicit hostcalls, including bounded `edgerun.relay/send` and `edgerun.relay/recv` imports.
- Relay sends are validated against serialized packet shape, app identity, admission id, budget token, and packet-byte budget before host relay dispatch.
- `er_work` can prepare and validate bounded capability envelope headers, including render capability invocations for app-authored scene payloads.
- `er_render_endpoint` can deterministically capture admitted render capability work, verify scene payload hashes, and decode endpoint-owned UI scenes after route, channel envelope, and render capability header verification.
- Wasm UI app `ui_emit` dispatch now passes through render endpoint capture/decode before the OS loop consumes app scene state.
- `varfont`, `edgerun-ui-core`, and the VirtIO GPU path provide enough UI/text/rendering foundation for polished app surfaces.
- The OS path can hold multiple Wasm UI apps concurrently as explicit runtime contexts with isolated preallocated memory, presentation identity, scene state, and app-switcher selection.
- App package identity is derived from app code, manifest, and UI asset object ids and lengths. Labels can name those objects inside manifests, but labels do not define package identity.
- VFS object packet reassembly validates packet order, offsets, payload hashes, packet ids, object id, and output capacity before returning loaded bytes.
- App package loading reassembles app code, manifest, and optional UI asset objects into caller-owned buffers and verifies they match the package manifest.
- The boot UI proof now routes its embedded Wasm UI app through VFS object packets and storage-bound app package loading before each runtime prepares the module from persistent per-app bytes.
- App package storage sources bind a package id to admitted storage-retrieve route ids for the app, manifest, and optional UI assets, so saved package launch has a route-provenance contract before endpoint-backed retrieval lands.
- Storage endpoint object responses are adapted into package storage objects only when their route id, object id, length, packet list, and caller-owned destination memory satisfy the saved-package source and manifest before bytes can launch.

## Current Target

The active target is one OS/runtime proof, not independent component
milestones:

```text
EdgeRun EtherType frame on VirtIO-net
  -> erwire parser
  -> admitted work packet decode
  -> admission-defined route verification
  -> render endpoint scene decode and VirtIO GPU submission
  -> storage endpoint object response path
  -> bounded Wasm app relay receive for input or completion
```

The first endpoint adapters may still acknowledge or capture packets before full
device behavior is complete. The required invariant is one ingress, one carriage
protocol, admission-defined routes, and typed endpoint adapters.

## Active Proof Tracks

### P1: Content-Addressed App And Storage Path

Status: package manifests, bounded object packet reassembly, package object
loading, admitted storage-source binding, storage endpoint response adaptation,
and storage-bound package loading are implemented.

Next work:

- Replace embedded package packet sources with real endpoint responses that satisfy admitted storage-source route ids and object identities.
- Keep VFS labels as manifest labels only; labels must never become path authority or package identity.
- Keep app package identity derived from app, manifest, and UI asset object ids and lengths.
- Audit runtime surfaces for host path, file, socket, or descriptor concepts outside tools and boot compatibility.
- Keep storage work restricted to typed object payloads carried by admitted storage or capability routes.

Proof:

- VFS tests reject traversal and invalid labels.
- VFS tests prove identical bytes produce identical object ids independent of label.
- App package tests prove identical objects with different labels produce the same package id.
- VFS tests reject tampered, out-of-order, or over-capacity object packet loads.
- App package load tests reject package id mismatches, tampered manifest bytes, wrong route ids, and unexpected asset objects.

### P2: Native Relay Ingress And Route Dispatch

Status: native ingress polling, accepted-payload retention, malformed/empty
classification, and first render endpoint-intent decode are implemented.

Next work:

- Call the native ingress helper from the OS loop.
- Decode accepted erwire payloads as admitted work packets, not packet-class guesses.
- Verify `NetworkMessage` and `CapabilityEnvelope` payloads against signed `WorkAdmission` records.
- Verify jurisdiction before producing a local endpoint intent.
- Emit deterministic relay acknowledgement or transit records from decoded admitted work.

Proof:

- QEMU pcap shows EtherType `0x88b5` and erwire `ERW1`.
- Core tests cover accepted, malformed, and empty native ingress paths with retained payload bytes.
- Core tests cover render endpoint-intent decode, unsupported route classification, malformed route rejection, malformed packet rejection, empty ingress, and null output rejection.
- Packet-class matches without a valid admission produce no endpoint intent.

### P3: Render Endpoint To VirtIO GPU

Status: deterministic render capture, scene payload hash verification,
endpoint-owned scene decode, and OS-loop consumption of endpoint-owned app
scenes are implemented.

Next work:

- Connect relay ingress to the same render endpoint scene decode path used by local Wasm UI app dispatch.
- Submit decoded endpoint-owned scenes through the VirtIO GPU endpoint.
- Keep GOP as bootstrap compatibility, not the durable renderer architecture.
- Keep apps targeting admitted UI scene packets, never framebuffers.

Proof:

- Unit tests feed admitted render capability work through erwire and route verification into the render endpoint.
- Core tests reject scene payload hash mismatches and verify endpoint-owned scene decode.
- QEMU or host proof shows the same app-authored scene hash before endpoint-specific drawing.
- UI proof renders through the VirtIO GPU endpoint path.

### P4: Storage Endpoint To Object Runtime

Status: package loading can consume storage-bound object responses after route,
object id, length, packet list, and destination memory validation.

Next work:

- Accept admitted storage/object work at the storage endpoint.
- Start with deterministic acknowledgement or capture after admission-defined route verification.
- Connect accepted endpoint responses to saved user-authored app package launch.
- Add VirtIO block queue support after the object endpoint contract is proven.
- Keep storage as sealed object movement, not a filesystem API.

Proof:

- Unit tests feed admitted object work through erwire and route verification to storage.
- QEMU proof carries admitted storage work from native ingress to the storage endpoint.
- Later QEMU proof writes and reads the same content-addressed object bytes through VirtIO block.

### P5: Wasm App Relay Loop

Status: bounded `edgerun.relay/send` and `edgerun.relay/recv`, concurrent local
Wasm UI app contexts, content-addressed package launch, Wasm render capability
relay-send proof, render endpoint capture, and endpoint-owned scene decode are
implemented.

Next work:

- Feed input or completion packets back to apps through relay receive.
- Keep each loaded app in an explicit runtime context with preallocated memory, presentation identity, scene state, and app-switcher selection.
- Move driver modules away from direct PCI/MMIO hostcalls as the durable ABI.
- Keep direct bus hostcalls only for bring-up until relay device endpoints are proven.

Proof:

- Wasm fixture emits an app UI scene or scene-delta capability packet through relay send.
- Wasm fixture receives a completion or input packet through relay receive.
- Tests prove memory bounds, packet bounds, admission checks, token checks, and budget failures.

### P6: Distributed UI

Status: not started.

Next work:

- Emit the same UI scene-class packet to two admitted renderer routes.
- Render locally through VirtIO GPU and remotely or virtually through a second renderer endpoint.
- Route input back as input capability packets.
- Keep shell placement and focus policy outside app authority.

Proof:

- Both renderer routes receive the same scene hash.
- Input returns on an ordered input capability route.

### P7: Remote Driver

Status: not started.

Next work:

- Run driver logic as Wasm.
- Submit device-operation packets over erwire.
- Execute the operation at a device endpoint that owns the local hardware queue.
- Return completions over erwire.

Proof:

- The driver uses relay send/receive, not direct bus hostcalls, for its durable ABI.
- The same device-operation packet can route locally or remotely without changing the driver ABI.

## Freeze Rule

Do not reintroduce standalone native, TPM, GPU, storage, or networking debug boot
profiles. Device code belongs behind the OS path and relay endpoint adapters.

Exit Boot Services becomes mandatory once the OS path has prepared the memory
and runtime-owned devices needed to keep running. New work should remove
firmware-service dependencies from relay, rendering, storage, input, scheduling,
and app execution instead of adding compatibility paths.
