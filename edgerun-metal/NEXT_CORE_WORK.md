# EdgeRun Metal: next core work

The metal core is now a relay runtime, not a local driver experiment. Netboot, GOP, PCI scans, and direct hostcalls are support surfaces. The product architecture is erwire relay between apps, UI renderers, drivers, storage, and hardware endpoints.

See `../docs/relay-architecture.md` for the cross-project model.

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

## Architecture rule

Do not add a second app IPC, remote UI, driver RPC, or storage protocol.

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
  -> VirtIO block endpoint for storage/object packets
  -> VirtIO GPU endpoint for render packets
```

The first endpoint adapters may acknowledge or capture packets before they implement full device behavior. The important proof is one ingress, one erwire protocol, one router, and typed VirtIO endpoints.

## Milestones

### M1: Native relay ingress

Status: next.

- Poll `erwire_poll_native_eth`.
- Reject invalid packets immediately.
- Preserve packet kind, payload, ingress endpoint, sequence, and payload hash inputs for routing.
- Emit deterministic relay intent records.

### M2: VirtIO endpoint dispatch

Status: next.

- Convert `ErRelayForwardIntent` into a device endpoint dispatch.
- Keep `er_hw_relay` limited to endpoint encoding and movement.
- Keep `er_relay_router` limited to packet-class route selection.
- Add test coverage for storage, render, unsupported, and malformed cases.

### M3: Storage adapter

Status: not started.

- Accept storage-class erwire packets at the VirtIO block endpoint.
- Start with deterministic capture or acknowledgement.
- Then add real VirtIO block request queue support.
- Keep storage as sealed object movement, not a filesystem API.

### M4: Render adapter

Status: not started.

- Accept render-class capability packets at the VirtIO GPU endpoint.
- Start with deterministic capture or acknowledgement.
- Then add the smallest VirtIO GPU command queue path.
- Keep apps targeting admitted UI scene packets, not framebuffers.

### M5: Wasm relay hostcalls

Status: not started.

- Add bounded Wasm imports for relay send/receive.
- Move driver modules away from direct PCI/MMIO hostcalls as the durable ABI.
- Keep direct bus hostcalls only for bring-up until relay device endpoints are proven.

### M6: Distributed UI proof

Status: not started.

- Emit the same UI scene-class packet to two admitted renderer routes.
- Render locally through GOP and remotely or virtually through a second renderer endpoint.
- Route input back as input capability packets.

### M7: Remote driver proof

Status: not started.

- Run driver logic as Wasm.
- Submit device-operation packets over erwire.
- Execute the operation at a device endpoint that owns the local hardware queue.
- Return completion over erwire.

## Freeze rule

Do not destabilize the known boot profiles unless a change is directly required for the relay runtime.

Do not call `ExitBootServices` yet. Dropping EFI Boot Services becomes justified when the native relay path owns enough hardware to boot, log, receive, route, and dispatch without firmware services.
