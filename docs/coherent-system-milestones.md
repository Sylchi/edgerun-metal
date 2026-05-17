# Coherent System Milestones

Purpose: define the ordered implementation checklist and proof artifacts for the unified EdgeRun relay system.

Intention: remove parallel implementations by forcing every app, UI, driver, storage, and hardware path through content-addressed objects and erwire relays.

## System Invariants

- One boundary protocol: erwire.
- One authority model: identity-routed, recipient-sealed, admission-bound work.
- One storage model: content-addressed objects plus VFS labels.
- One UI model: admitted scene/render capability packets, never app-owned framebuffers.
- One driver model: Wasm driver logic sends relay device-operation packets.
- One hardware model: endpoint adapters own local queues, registers, DMA, and firmware compatibility.
- One routing model: relay intents and transit records bind packet hash, route hash, endpoints, and sequence.

## Current Baseline

- `er_work` defines node identities, channel endpoints, work requests, admissions, capability envelopes, and relay transit records.
- `er_app` defines content-addressed Wasm app identity, budget, usage, schedule, launch allocation, and IPC route binding.
- `er_vfs` defines object packets, object labels, and transform refs without host filesystem authority.
- `erwire` carries typed packets and can send/parse native EdgeRun Ethernet frames.
- `er_hw_relay` encodes firmware UDP, native Ethernet, and VirtIO endpoints.
- `er_relay_router` maps storage and render packet classes to VirtIO endpoint intents.
- `edgerun-ui-core` provides backend-neutral UI scene records.
- `wasm_vm` runs bounded Wasm modules with explicit hostcalls.

## Milestone 1: Object-Only Storage Contract

Goal: make it impossible for runtime storage work to look like host file work.

Work:

- Audit runtime code for host path, file, socket, or descriptor concepts outside tools and boot compatibility.
- Keep `er_vfs` labels as manifest labels only.
- Add docs or tests showing labels resolve to object ids, not authority.
- Ensure storage-class routing only accepts object packet, label ref, transform ref, and object capability records.

Proof:

- Host tests reject invalid labels and path traversal.
- Host tests prove identical bytes produce identical object ids independent of label.
- Relay router tests send object packets to storage endpoints and reject log/control packets.

## Milestone 2: Native Relay Ingress

Goal: receive erwire over native VirtIO-net without EFI networking.

Work:

- Poll `erwire_poll_native_eth` from the native profile.
- Build an ingress `ErChannelEndpoint` from the VirtIO-net MAC.
- Reject malformed packets immediately.
- Preserve packet kind, payload, sequence, payload hash inputs, and ingress endpoint.

Proof:

- QEMU pcap contains EdgeRun EtherType `0x88b5` packets.
- Core test covers malformed header, bad length, bad CRC, unsupported kind, and accepted packet.
- Native run emits a deterministic relay-ingress acknowledgement or transit packet.

## Milestone 3: Relay Intent Dispatch

Goal: turn parsed erwire packets into one dispatch path for every endpoint.

Work:

- Add a small dispatcher that consumes `ErRelayForwardIntent`.
- Keep route selection inside `er_relay_router`.
- Keep endpoint movement inside `er_hw_relay` or device-specific adapters.
- Record unsupported endpoint kinds as hard failures, not fallback behavior.

Proof:

- Tests prove storage packets produce VirtIO block intents.
- Tests prove render capability packets produce VirtIO GPU intents.
- Tests prove unsupported packet kinds produce no intent.
- Tests prove malformed endpoint records are rejected.

## Milestone 4: VirtIO Storage Endpoint

Goal: make storage a relay endpoint before making it a full disk driver.

Work:

- Add a VirtIO block endpoint adapter.
- First implementation may capture or acknowledge object packets deterministically.
- Then add minimal VirtIO block request queue submission.
- Keep the adapter object-based; no file paths or filesystem calls.

Proof:

- Unit test feeds an `ErVfsObjectPacket` through erwire and dispatcher to the storage adapter.
- QEMU proof shows net ingress routes storage packet to the block endpoint.
- Later QEMU proof writes and reads the same content-addressed object bytes through VirtIO block.

## Milestone 5: VirtIO Render Endpoint

Goal: make UI rendering a relay endpoint before making it a full compositor.

Work:

- Define the first render payload as a bounded scene or scene-delta capability packet.
- Add a VirtIO GPU endpoint adapter.
- First implementation may capture scene metadata or acknowledge render packets deterministically.
- Then add minimal VirtIO GPU command queue submission.

Proof:

- Unit test feeds render capability packet through erwire and dispatcher to the render adapter.
- QEMU proof shows net ingress routes render packet to the GPU endpoint.
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
