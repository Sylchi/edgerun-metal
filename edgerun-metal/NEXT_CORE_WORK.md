# EdgeRun Metal: next core work

The metal core is now a relay runtime, not a local driver experiment. Netboot, GOP, PCI scans, and direct hostcalls are support surfaces. The product architecture is erwire relay between apps, UI renderers, drivers, storage, and hardware endpoints.

See `../docs/relay-architecture.md` for the cross-project model and `../docs/coherent-system-milestones.md` for the proof checklist.

## Proven baseline

- x86_64 UEFI firmware loads `BOOTX64.EFI`.
- EdgeRun Metal Core starts on real hardware.
- The embedded Wasm VM executes bounded modules.
- PCI config-space and MMIO read hostcall foundations exist.
- GOP-backed UI rendering exists through `edgerun-ui-core`.
- Native VirtIO-net can submit EdgeRun Ethernet frames with EtherType `0x88b5`.
- `erwire` packets can be parsed from native Ethernet frames.
- Hardware relay endpoints exist for firmware UDP, native Ethernet, and VirtIO queues.
- Relay routing policy is split into `er_relay_router`.
- Native relay ingress polling can produce deterministic ingress records for none, malformed, unrouted, and routed packets.
- Relay intent dispatch is split into `er_relay_dispatch` and can produce capture records for VirtIO block and VirtIO GPU targets.

## Architecture rule

Do not add a second app IPC, remote UI, driver RPC, or storage protocol.

Do not add host-like files outside VFS. VFS labels are manifest names for content-addressed objects. They are not paths, authority, durable storage identity, or runtime handles.

All boundary-crossing work must be shaped as:

```text
work / channel / capability / object payload
  -> erwire packet
  -> relay route
  -> endpoint adapter
```

Local hostcalls are allowed only as temporary proof scaffolding. The durable app and driver ABI is relay packet send/receive.

## Current target

Make VirtIO-net the first native relay ingress and route erwire packets to other VirtIO endpoints.

Target QEMU proof:

```text
EdgeRun EtherType frame on VirtIO-net
  -> erwire parser
  -> relay router
  -> relay dispatcher
  -> VirtIO block endpoint for storage/object packets
  -> VirtIO GPU endpoint for render packets
```

The first endpoint adapters may acknowledge or capture packets before they implement full device behavior. The important proof is one ingress, one erwire protocol, one router, and typed VirtIO endpoints.

## Immediate milestones

### M1: Object-only storage contract

Status: next.

- Audit runtime surfaces for host path/file/socket/descriptor concepts.
- Keep VFS labels as object labels only.
- Prove labels map to object ids, and object ids do not depend on labels.
- Keep storage routing restricted to object packet, label ref, transform ref, and object capability records.

Proof:

- VFS tests reject traversal and invalid labels.
- VFS tests show same bytes produce same object id with different labels.
- Relay router tests send object packets to storage and reject non-storage packets.

### M2: Native relay ingress

Status: partially implemented; native profile loop and QEMU acknowledgement are next.

- `er_native_boot_poll_relay_ingress` polls `erwire_poll_native_eth`.
- Invalid accepted Ethernet frames are reported as malformed ingress records.
- Accepted packets preserve packet kind, payload length, ingress endpoint, sequence, and packet hash inputs for routing.
- Routed packets emit deterministic relay intent records.
- Next: call the ingress helper from the native profile loop and emit deterministic acknowledgement or transit packets.

Proof:

- QEMU pcap shows EtherType `0x88b5` and erwire `ERW1`.
- Core tests cover malformed and accepted native erwire packets.
- Core tests cover native ingress statuses for routed, malformed, and empty polls.
- Remaining proof: native run emits a deterministic relay acknowledgement or transit packet.

### M3: VirtIO endpoint dispatch

Status: capture-record dispatch implemented; device adapters are next.

- Convert `ErRelayForwardIntent` into a device endpoint dispatch record.
- Keep `er_hw_relay` limited to endpoint encoding and movement.
- Keep `er_relay_router` limited to packet-class route selection.
- Keep `er_relay_dispatch` limited to intent consumption and endpoint classification until device adapters exist.

Proof:

- Storage packets produce VirtIO block intents.
- Render capability packets produce VirtIO GPU intents.
- Unsupported packet classes produce no intent.
- Dispatch tests produce storage and render capture records.
- Dispatch tests report unsupported and malformed endpoint records deterministically.

### M4: Storage adapter

Status: next.

- Accept storage-class erwire packets at the VirtIO block endpoint.
- Start from the existing dispatch capture record and add a storage endpoint adapter.
- Then add real VirtIO block request queue support.
- Keep storage as sealed object movement, not a filesystem API.

Proof:

- Unit test feeds an object packet through erwire and dispatches it to storage.
- QEMU proof routes a net-ingress storage packet to the VirtIO block endpoint.

### M5: Render adapter

Status: next.

- Accept render-class capability packets at the VirtIO GPU endpoint.
- Start from the existing dispatch capture record and add a render endpoint adapter.
- Then add the smallest VirtIO GPU command queue path.
- Keep apps targeting admitted UI scene packets, not framebuffers.

Proof:

- Unit test feeds a render capability packet through erwire and dispatches it to render.
- QEMU proof routes a net-ingress render packet to the VirtIO GPU endpoint.

### M6: Wasm relay hostcalls

Status: not started.

- Add bounded Wasm imports for relay send/receive.
- Move driver modules away from direct PCI/MMIO hostcalls as the durable ABI.
- Keep direct bus hostcalls only for bring-up until relay device endpoints are proven.

Proof:

- Wasm fixture emits object and render packets through relay send.
- Wasm fixture receives a completion or input packet through relay receive.
- Tests prove memory bounds, packet bounds, and budget failures.

### M7: Distributed UI proof

Status: not started.

- Emit the same UI scene-class packet to two admitted renderer routes.
- Render locally through GOP and remotely or virtually through a second renderer endpoint.
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

Do not destabilize the known boot profiles unless a change is directly required for the relay runtime.

Do not call `ExitBootServices` yet. Dropping EFI Boot Services becomes justified when the native relay path owns enough hardware to boot, log, receive, route, and dispatch without firmware services.
