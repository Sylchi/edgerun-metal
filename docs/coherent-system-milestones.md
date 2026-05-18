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

## Authority Rule

No layer may turn its local authority into global authority.

- Hardware adapters may own queues, registers, DMA, and interrupts for admitted endpoint work only.
- Network relays may move packets and produce transit evidence only.
- Storage nodes may verify and store admitted typed object payloads only.
- UI renderers may draw admitted scene/render capability payloads only.
- Schedulers may allocate local time, memory, and execution slots only.
- Human relationship, group, and organization policy may admit access inside their own social or administrative scope only.
- Settlement may pay verified receipts and proofs only.

The shared contract is what lets these parts interoperate. The admissions remain scoped to their jurisdictions.

## Current Baseline

- `er_work` defines the C mirror of `edgerun-work` node identities, channel endpoints, work requests, admissions, capability envelopes, and relay transit records.
- `er_app` defines content-addressed Wasm app package manifests, identity, budget, usage, schedule, launch allocation, and IPC route binding.
- `er_vfs` defines object packets, object labels, transform refs, and bounded object packet reassembly without host filesystem authority.
- `erwire` carries typed packets and can send/parse native EdgeRun Ethernet frames.
- `er_hw_relay` encodes firmware UDP, native Ethernet, and VirtIO endpoints.
- `er_native_boot` can poll native erwire ingress into deterministic accepted, malformed, or empty records.
- `edgerun-ui-core` provides backend-neutral UI scene records.
- `wasm_vm` runs bounded Wasm modules with explicit hostcalls, including bounded `edgerun.relay/send` and `edgerun.relay/recv` imports.
- Relay sends are validated against serialized packet shape, app identity, admission id, budget token, and packet-byte budget before host relay dispatch.
- `er_work` can prepare and validate bounded capability envelope headers, including render capability invocations for app-authored scene payloads.
- `varfont`, `edgerun-ui-core`, the GOP renderer, and the VirtIO GPU profile provide enough UI/text/rendering foundation for polished app surfaces.
- The boot UI proof can hold multiple Wasm UI apps concurrently as explicit runtime contexts with isolated preallocated memory, presentation identity, scene state, and app-switcher selection.
- App package identity is derived from app code, manifest, and UI asset object ids and lengths. Labels can name those objects inside manifests, but labels do not define package identity.
- VFS object packet reassembly validates packet order, offsets, payload hashes, packet ids, object id, and output capacity before returning loaded bytes.
- App package loading reassembles app code, manifest, and optional UI asset objects into caller-owned buffers and verifies they match the package manifest.
- The boot UI proof now routes its embedded Wasm UI app through VFS object packets and storage-bound app package loading before each runtime prepares the module from persistent per-app bytes.
- App package storage sources bind a package id to admitted storage-retrieve route ids for the app, manifest, and optional UI assets, so saved package launch has a route-provenance contract before endpoint-backed retrieval lands.
- Storage endpoint object responses are adapted into package storage objects only when their route id, object id, length, packet list, and caller-owned destination memory satisfy the saved-package source and manifest before bytes can launch.

## Milestone 1: Object-Only Storage And App Packaging Contract

Goal: make it impossible for runtime storage or app packaging work to look like host file work.

Work:

- Audit runtime code for host path, file, socket, or descriptor concepts outside tools and boot compatibility.
- Keep `er_vfs` labels as manifest labels only.
- Treat user-authored Wasm apps, manifests, UI assets, and fonts as content-addressed objects.
- Prepare app package manifests from object refs, not host paths.
- Reassemble loaded package objects into caller-owned memory from validated object packets.
- Use loaded package objects as the only input shape for launching saved or authored apps.
- Add docs or tests showing labels resolve to object ids, not authority.
- Ensure storage work accepts typed object payloads only when carried by an admitted storage or capability route.

Proof:

- Host tests reject invalid labels and path traversal.
- Host tests prove identical bytes produce identical object ids independent of label.
- Host tests prove identical package objects produce identical package ids independent of labels.
- Host tests reject tampered, out-of-order, and over-capacity object packet loads.
- Host tests reject app package loads with package id mismatches, tampered manifest bytes, or unexpected assets.
- Tests prove app identity and asset references come from object ids, not paths.
- Route tests must start from signed admissions, not packet-class inference.

## Milestone 2: Native Relay Ingress

Goal: receive erwire over native VirtIO-net without EFI networking.

Work:

- Poll `erwire_poll_native_eth` through the native ingress helper.
- Build an ingress `ErChannelEndpoint` from the VirtIO-net MAC.
- Reject malformed packets immediately.
- Preserve packet kind, payload, sequence, payload hash inputs, and ingress endpoint without treating the ingress transport as authority.
- Next: call the helper from the native profile loop.

Proof:

- QEMU pcap contains EdgeRun EtherType `0x88b5` packets.
- Core tests cover accepted packets, malformed packets, and empty polls.
- Remaining proof: native run emits a deterministic relay-ingress acknowledgement or transit packet.

## Milestone 3: Admission-Defined Route Verification

Goal: turn admitted `edgerun-work` traffic into relay intents only after route verification.

Work:

- Decode the payload as the corresponding `edgerun-work` record.
- Verify `NetworkMessage` department, work type, recipient, first relay, and route commitment against the signed admission path.
- Build `ErRelayForwardIntent` only from the verified admission-defined route and local endpoint mapping.
- Reject packet-class matches without a valid admission.
- Keep endpoint movement inside `er_hw_relay` or device-specific adapters.

Proof:

- Tests prove admitted storage work can produce a VirtIO block intent.
- Tests prove admitted render capability work can produce a VirtIO GPU intent.
- Tests prove packet-class matches without a valid admission produce no intent.
- Tests prove malformed or unsupported admitted endpoints are rejected deterministically.

## Milestone 4: VirtIO Storage Endpoint

Goal: make storage a relay endpoint before making it a full disk driver.

Work:

- Add a VirtIO block endpoint adapter behind an admitted storage or object capability route.
- First implementation may capture or acknowledge object packets deterministically.
- Then add minimal VirtIO block request queue submission.
- Keep the adapter object-based; no file paths or filesystem calls.

Proof:

- Unit test feeds admitted storage/object work through erwire and the route verifier to the storage adapter.
- QEMU proof shows net ingress carries admitted storage work to the block endpoint.
- Later QEMU proof writes and reads the same content-addressed object bytes through VirtIO block.

## Milestone 5: VirtIO Render Endpoint

Goal: make UI rendering a relay endpoint before making it a full compositor.

Work:

- Define the first render payload as a bounded scene or scene-delta capability envelope.
- Add a VirtIO GPU endpoint adapter behind an admitted render capability route.
- First implementation may capture scene metadata or acknowledge render packets deterministically.
- Then add minimal VirtIO GPU command queue submission.

Proof:

- Unit test feeds admitted render capability work through erwire and the route verifier to the render adapter.
- QEMU proof shows net ingress carries admitted render work to the GPU endpoint.
- UI proof renders the same scene locally through GOP and through the render endpoint path.

## Milestone 6: Wasm Relay ABI

Goal: make relay send/receive the durable app and driver hostcall surface.

Work:

- Add bounded Wasm imports for relay send and relay receive.
- Charge app packet-byte and IPC budgets for relay traffic.
- Keep direct PCI/MMIO hostcalls only as bring-up scaffolding.
- Move driver fixtures from direct bus operations toward device-operation packets.

Proof:

- Wasm fixture emits an object packet over relay send.
- Wasm fixture emits a render capability packet over relay send.
- Wasm fixture receives a completion or input packet over relay receive.
- Tests prove memory bounds, packet size bounds, and budget failures are fatal.

## Milestone 7: Distributed UI

Goal: prove app logic and UI rendering are location-independent.

Work:

- Give one app two admitted render routes.
- Emit the same scene payload to both routes.
- Route input events back as input capability packets.
- Keep shell placement and focus policy outside app authority.

Proof:

- Test proves both renderer routes receive the same scene hash.
- Local proof renders through GOP.
- QEMU or host proof renders or captures through a second renderer endpoint.
- Input packet returns to the app route with ordered sequence.

## Milestone 8: Remote Driver

Goal: prove driver logic and hardware attachment are location-independent.

Work:

- Run driver logic as Wasm.
- Submit device-operation packets over erwire.
- Execute operations at the device endpoint that owns local hardware.
- Return completions over erwire.

Proof:

- Driver Wasm emits a device-operation packet without direct bus hostcalls.
- Device endpoint executes or captures the operation deterministically.
- Completion packet returns over erwire.
- The same driver packet can be routed locally or through native Ethernet without changing the driver ABI.

## Milestone 9: Exit Boot Services Readiness

Goal: drop EFI Boot Services only after native relay ownership is proven.

Work:

- Native logging works without firmware networking.
- Native receive path works through VirtIO-net.
- Native storage endpoint can persist sealed object packets.
- Native render endpoint can show basic status.
- Device discovery, memory ownership, interrupts, and timers have native replacements or explicit minimal stubs.

Proof:

- QEMU native proof boots, logs, receives, routes, persists or captures storage, and renders or captures UI without using EFI network services.
- No production path depends on host libc, host files, or firmware networking for relay operation.
