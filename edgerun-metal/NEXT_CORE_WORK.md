# EdgeRun Metal: next core work

The metal core is now an OS runtime for user-authored Wasm apps, not a set of local driver experiments. Netboot, GOP, PCI scans, and direct hostcalls are support surfaces. The product architecture is the `edgerun-work` protocol carried by erwire between apps, UI renderers, input, drivers, storage, and hardware capabilities.

See `../docs/relay-architecture.md` for the cross-project model and `../docs/coherent-system-milestones.md` for the proof checklist.

## Proven baseline

- x86_64 UEFI firmware loads `BOOTX64.EFI`.
- EdgeRun Metal Core starts on real hardware.
- The embedded Wasm VM executes bounded modules.
- PCI config-space and MMIO read hostcall foundations exist.
- VirtIO GPU rendering surfaces exist through `edgerun-ui-core`; GOP is only bootstrap compatibility.
- Native VirtIO-net can submit EdgeRun Ethernet frames with EtherType `0x88b5`.
- `erwire` packets can be parsed from native Ethernet frames.
- Hardware relay endpoints exist for firmware UDP, native Ethernet, and VirtIO queues.
- Native relay ingress polling can produce deterministic ingress records for none, malformed, and accepted packets, preserving the accepted erwire payload bytes for route decoding.
- Wasm modules can call bounded `edgerun.relay/send` and `edgerun.relay/recv` imports through declared inbox/outbox memory windows.
- Relay sends are checked against app source identity, admission id, budget token, packet validity, and packet-byte budget before leaving the VM.
- `edgerun-ui-core`, VirtIO GPU rendering, and `varfont` provide enough UI machinery to target polished app surfaces instead of diagnostic rectangles.
- The OS path can prepare multiple Wasm UI app runtimes at once. Each app has its own preallocated linear memory, presentation identity, scene, and `ui_emit` host context, and the shell app switcher selects which context receives input and contributes scene output.
- `er_app` can build content-addressed app package manifests from VFS object refs for app code, manifests, and UI assets. Package identity is derived from object ids and lengths, not labels.
- `er_vfs` can reassemble canonical object packet sequences into bounded caller-owned memory while validating packet order, offsets, payload hashes, packet ids, object id, and output capacity.
- `er_app` can load app package objects from validated VFS packets into caller-owned buffers, then reject package id mismatches, object id mismatches, tampered object bytes, and unexpected asset payloads.
- The OS boot path packages the embedded Wasm UI app as VFS object packets and loads it through the storage-bound package loader into persistent per-app module buffers before preparing each runtime.
- `er_app` can bind a launchable saved package source to admitted storage-retrieve route ids for the package's app, manifest, and optional UI asset objects.
- `er_app` can load a package from storage-bound object responses only when each retrieved object matches the source's admitted route id.
- `er_app` can adapt typed storage endpoint object responses into package storage objects only when the response route id, object id, object length, packet list, and caller-owned destination memory match the package source and manifest.
- `er_work` can prepare and validate capability envelope headers, and the Wasm relay fixture can emit a render capability invocation through `edgerun.relay/send` under the existing outbox, admission, token, and packet-byte budget checks.
- `er_render_endpoint` can capture admitted render capability work only after the admitted route, channel envelope, render capability header, source/target nodes, sequence, and scene hash line up; it can then verify the scene payload hash and decode the endpoint-owned UI scene.
- Native relay ingress can decode an accepted relay packet against an admitted capability route and classify it as a render endpoint intent, unsupported endpoint work, malformed traffic, or no ingress.

## Architecture rule

Do not add a second app IPC, remote UI, driver RPC, or storage protocol.

Do not add host-like files outside VFS. VFS labels are manifest names for content-addressed objects. They are not paths, authority, durable storage identity, or runtime handles.

Do not let local authority escape its jurisdiction. Hardware code owns local queues and registers, relays own packet movement, storage owns typed object persistence, schedulers own local execution slots, and policy/admission owns only the resources and relationships inside its scope. Compatibility comes from the shared `edgerun-work` records and proofs, not from any one layer becoming a global authority.

All boundary-crossing work must be shaped as:

```text
WorkRequest / WorkAdmission / NetworkMessage / ChannelEnvelope / CapabilityEnvelope / object payload
  -> erwire packet
  -> admission-defined relay route
  -> endpoint adapter
```

Local hostcalls are allowed only as temporary proof scaffolding. The durable app and driver ABI is relay packet send/receive.

## Current target

Make VirtIO-net the first native relay ingress and carry admitted `edgerun-work` packets from user-authored Wasm apps to local endpoint adapters. The first product proof should show an app emitting beautiful UI state through a render capability route, not owning a framebuffer or depending on a special local IPC path.

Target QEMU proof:

```text
EdgeRun EtherType frame on VirtIO-net
  -> erwire parser
  -> work packet decode
  -> admission-defined route verification
  -> assigned render endpoint for admitted UI scene work
  -> assigned storage endpoint for admitted object work
```

The first endpoint adapters may acknowledge or capture packets before they implement full device behavior. The important proof is one ingress, one carriage protocol, admission-defined routes, and typed local endpoint adapters.

## Immediate milestones

### M1: Object-only storage and app packaging contract

Status: package manifest contract, bounded object packet reassembly, and package object loading implemented; storage endpoint integration and broader audit are next.

- Audit runtime surfaces for host path/file/socket/descriptor concepts.
- Keep VFS labels as object labels only.
- Prove labels map to object ids, and object ids do not depend on labels.
- Keep app package identity derived from app, manifest, and UI asset object ids and lengths, never from labels.
- Load package objects through validated object packet reassembly into caller-owned memory before handing bytes to a Wasm runtime.
- Connect admitted storage endpoint responses to package object loading.
- Keep storage work restricted to typed object payloads carried by admitted storage or capability routes.
- Treat user-authored app Wasm, UI assets, fonts, and manifests as content-addressed objects, never host paths.

Proof:

- VFS tests reject traversal and invalid labels.
- VFS tests show same bytes produce same object id with different labels.
- App package tests show same objects with different labels produce the same package id.
- VFS tests reject tampered, out-of-order, or over-capacity object packet loads.
- App package load tests reject package id mismatches, tampered manifest bytes, and unexpected asset objects.
- Route tests start from signed admissions, not packet-class inference.

### M2: Native relay ingress

Status: implemented through payload retention and endpoint-intent decode; OS loop integration and QEMU acknowledgement are next.

- `er_native_boot_poll_relay_ingress` polls `erwire_poll_native_eth`.
- Invalid accepted Ethernet frames are reported as malformed ingress records.
- Accepted packets preserve packet kind, payload bytes, payload length, ingress endpoint, sequence, and packet hash inputs without granting authority from ingress locality.
- Accepted relay packet payloads can now be decoded as admitted render capability endpoint intents.
- Next: call the ingress helper from the OS loop and emit acknowledgement or transit packets from decoded admitted work.

Proof:

- QEMU pcap shows EtherType `0x88b5` and erwire `ERW1`.
- Core tests cover malformed and accepted native erwire packets.
- Core tests cover native ingress statuses for accepted, malformed, and empty polls, including retained payload bytes.
- Core tests cover accepted render capability endpoint-intent decode, unsupported route classification, malformed route rejection, malformed packet rejection, empty ingress, and null output rejection.
- Remaining proof: native run emits a deterministic relay acknowledgement or transit packet.

### M3: Admission-defined route verification

Status: route primitives and first native render endpoint-intent selection implemented; signed admission-record verification, storage intent selection, and OS-loop dispatch are next.

- Decode accepted erwire payloads as relay packets carrying `edgerun-work` records.
- Verify `NetworkMessage` and `CapabilityEnvelope` payloads against a signed `WorkAdmission` path.
- Verify the admission's jurisdiction before producing a local endpoint intent.
- Convert verified admission-defined routes into a local endpoint intent; render capability intent exists first.
- Keep `er_hw_relay` limited to endpoint encoding and movement.
- Reject packet-class matches without a valid admission.

Proof:

- Admitted storage work can produce a VirtIO block intent.
- Admitted render capability work can produce a native render endpoint intent; VirtIO GPU command intent is next.
- A valid admission for one jurisdiction cannot authorize another jurisdiction's endpoint.
- Packet-class matches without a valid admission produce no intent.
- Malformed or unsupported admitted endpoints are rejected deterministically.

### M4: Render adapter

Status: deterministic render capture, scene payload verification, and endpoint-owned scene decode implemented; VirtIO GPU endpoint submission is next.

- Accept admitted render capability work at a render endpoint.
- Deterministically capture scene metadata or scene hashes after admission-defined route verification.
- Connect the captured scene path to the VirtIO GPU endpoint.
- Use the endpoint-owned decoded scene as the render handoff, not app-owned framebuffer memory.
- Keep apps targeting admitted UI scene packets, not framebuffers.

Proof:

- Unit test feeds admitted render capability work through erwire and the route verifier to render.
- QEMU or host proof shows an app-authored scene produces the same scene hash before endpoint-specific drawing.
- Core test verifies scene payload hash mismatch rejection and endpoint-owned scene decode.

### M5: Storage adapter

Status: next.

- Accept admitted storage/object work at the storage endpoint.
- Start with deterministic acknowledgement or capture after admission-defined route verification.
- Then add real VirtIO block request queue support.
- Keep storage as sealed object movement, not a filesystem API.

Proof:

- Unit test feeds admitted object work through erwire and the route verifier to storage.
- QEMU proof carries admitted storage work from net ingress to the VirtIO block endpoint.

### M6: User-authored Wasm UI app proof

Status: relay hostcall foundation, concurrent local Wasm UI app contexts, content-addressed app package records, validated package object loading, boot-local package-loaded app launch, admitted storage-source binding, storage endpoint response adaptation, storage-bound package loading, Wasm render capability relay-send proof, render endpoint capture, endpoint-owned scene decode, and OS loop consumption of endpoint-owned app scenes implemented; relay-ingress route integration and VirtIO GPU endpoint submission are next.

- Keep bounded Wasm imports for relay send/receive as the durable app boundary.
- Keep each loaded app in an explicit runtime context with preallocated memory, presentation identity, scene state, and app-switcher selection.
- Replace the embedded package packet source with real endpoint responses that satisfy the admitted storage-source route ids and object identities for saved user-authored app packages.
- Connect relay ingress to the same render endpoint scene decode path and add VirtIO GPU endpoint submission.
- Feed input or completion packets back through relay receive.
- Move driver modules away from direct PCI/MMIO hostcalls as the durable ABI.
- Keep direct bus hostcalls only for bring-up until relay device endpoints are proven.

Proof:

- Wasm fixture emits an app UI scene or scene-delta capability packet through relay send.
- Wasm fixture receives a completion or input packet through relay receive.
- Tests prove memory bounds, packet bounds, admission/budget checks, and budget failures.

### M7: Distributed UI proof

Status: not started.

- Emit the same UI scene-class packet to two admitted renderer routes.
- Render locally through VirtIO GPU and remotely or virtually through a second renderer endpoint.
- Route input back as input capability packets.

Proof:

- Both renderer routes receive the same scene hash.
- Input returns on an ordered input capability route.

### M8: Remote driver proof

Status: not started.

- Run driver logic as Wasm.
- Submit device-operation packets over erwire.
- Execute the operation at a device endpoint that owns the local hardware queue.
- Return completion over erwire.

Proof:

- The driver uses relay send/receive, not direct bus hostcalls, for its durable ABI.
- The same device-operation packet can route to a local or remote endpoint without changing the driver.

## Freeze rule

Do not reintroduce standalone native, TPM, or GPU debug boot profiles. Device code belongs behind the OS path and relay endpoint adapters.

Exit Boot Services becomes mandatory once the OS path has prepared the memory and runtime-owned devices needed to keep running. New work should remove firmware-service dependencies from relay, rendering, storage, input, scheduling, and app execution instead of adding compatibility paths.
