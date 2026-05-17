# EdgeRun Relay Architecture

Purpose: define the single relay model that apps, UI renderers, Wasm drivers, and hardware adapters use.

Intention: keep EdgeRun as one identity-routed system where local machine boundaries are implementation details, not protocol authority.

## Core Rule

Everything that crosses an execution, display, storage, device, or machine boundary crosses as an admitted erwire relay packet.

There are no separate app IPC, remote UI, driver RPC, storage RPC, or device-control protocols. Those are packet classes carried by erwire, authorized by work/admission records, sealed to the recipient identity, and moved by relay nodes.

## Roles

An EdgeRun node may hold more than one role, but each packet is handled through one explicit role at a time:

- App logic node: executes content-addressed Wasm app code.
- UI renderer node: converts admitted UI scene packets into pixels on a local display backend.
- Input node: sends admitted input events back to an app or shell route.
- Driver node: runs Wasm driver logic and emits device operations as relay work.
- Device endpoint node: owns a local hardware transport such as VirtIO, PCI/MMIO, USB, or GPU queues.
- Storage node: stores and retrieves sealed content-addressed objects.
- Relay node: moves packets between channel endpoints and records transit.

Locality does not grant authority. A driver running on one machine can drive a device attached to another machine only through an admitted route to that device endpoint. An app running on one machine can render on another machine only through an admitted route to that UI renderer endpoint.

## Packet Shape

The shared outer carriage is `erwire`:

```text
erwire header
  kind
  stream id
  sequence
  payload length
  payload crc
payload
```

The payload is one of the runtime records already owned by the C core:

- `WorkRequest`: asks to cross an authority boundary.
- `WorkAdmission`: admits a route, budget, channel, and relay path.
- `ChannelEnvelope`: carries ordered app, UI, driver, input, or storage messages.
- `CapabilityEnvelope`: invokes a session-bound capability such as render, input, object, or device operation.
- `RelayTransitHop`: records that a relay moved a packet.
- VFS object packets: move sealed content-addressed bytes.
- App identity and route-binding packets: bind content-addressed Wasm execution to admitted routes.

The current `ERWIRE_KIND_*` values are therefore not separate protocols. They are packet classes inside one relay protocol.

## UI Relay

Apps do not own framebuffers. They produce admitted UI state.

The app path is:

```text
Wasm app
  -> app state / component state
  -> UI scene or scene-delta payload
  -> CapabilityEnvelope(content=render)
  -> erwire
  -> relay path
  -> UI renderer endpoint
  -> backend-specific renderer
```

The renderer backend can be local GOP, VirtIO GPU, a host window, a browser canvas, or a future hardware GPU path. The app sees only the render capability route. That is what lets the same Wasm UI render locally, remotely, or on several renderers at once: admission gives the app one route per renderer, and the app emits the same scene-class payload to each admitted route.

Input follows the reverse path:

```text
input endpoint
  -> CapabilityEnvelope(content=input)
  -> erwire
  -> relay path
  -> app or shell route
```

The shell owns placement, focus, secure prompts, and compositor policy. Apps submit bounded scenes; renderers draw admitted scenes.

## Driver Relay

Drivers are Wasm modules, not trusted local kernel code. A driver packet has the same authority model as an app packet:

```text
Wasm driver
  -> device operation payload
  -> CapabilityEnvelope(content=control or opaque, risk=raw-device when required)
  -> erwire
  -> relay path
  -> device endpoint
  -> local bus or queue adapter
```

The device endpoint is the only component that touches local hardware registers, DMA rings, or VirtIO queues. It is an adapter from admitted relay packets to a concrete local transport.

This means a VirtIO-net device can act as the first relay ingress while other VirtIO devices are addressed as relay endpoints:

```text
VirtIO net ingress
  -> erwire parse
  -> relay router
  -> VirtIO block endpoint
  -> VirtIO GPU endpoint
```

The same model later extends to PCI/MMIO, USB, NVMe, real NICs, and GPUs. The driver logic can live on another node because its output is not a pointer or host syscall. It is a sealed, admitted device-operation packet.

## Storage Relay

Storage is not a host filesystem API. It is object movement:

```text
object packet / transform packet
  -> erwire
  -> relay path
  -> storage endpoint
```

Only sealed transport objects become durable or cross relays. A storage endpoint can be memory, VirtIO block, NVMe, a remote object service, or any future backend that accepts the same object packet classes.

## Routing Identity

EdgeRun identities are public-key identities. MAC addresses and VirtIO queue addresses are delivery locators for a local hop, not trust roots.

The relay node uses local endpoint addresses to move bytes:

- memory channel
- native Ethernet MAC address
- firmware UDP compatibility endpoint
- VirtIO device type and queue
- future PCI/MMIO/USB endpoints

The packet itself carries authority through recipient-bound sealing, signatures, hashes, route commitments, sequence, and admissions. A wrong local receiver may see bytes but cannot decrypt, authorize, replay into a different route, or produce the expected state transition.

## Code Ownership

The code should stay split by responsibility:

- `erwire`: packet carriage, parse, poll, send.
- `er_work`: identity, work, admission, channel, capability, relay records.
- `er_app`: app identity, app budgets, app IPC route bindings.
- `er_hw_relay`: endpoint encoding and local packet movement.
- `er_relay_router`: deterministic route selection from erwire packet class to relay endpoint.
- `er_native_eth`: native EdgeRun Ethernet transport.
- `er_virtio` and device-specific VirtIO modules: queue and device adapters.
- `wasm_vm`: bounded Wasm execution and hostcall dispatch.
- `edgerun-ui-core`: backend-neutral UI scene records.
- renderer backends: adapt admitted UI scene packets to pixels.

New work should extend one of those surfaces instead of adding a second route, IPC, renderer, or driver protocol.

## Near-Term Proof

The proof that this architecture is real is not a full OS. It is a relay chain in QEMU:

```text
Wasm or host test emits erwire packet
  -> VirtIO net receives EdgeRun EtherType frame
  -> native erwire parser accepts packet
  -> relay router selects endpoint
  -> VirtIO block or VirtIO GPU adapter consumes packet
  -> transit/result packet is emitted back over erwire
```

The first concrete milestones are:

1. Add a native ingress loop that polls `erwire_poll_native_eth`.
2. Convert accepted packets into `ErRelayForwardIntent`.
3. Dispatch storage-class packets to a VirtIO block adapter.
4. Dispatch render-class packets to a VirtIO GPU adapter.
5. Add Wasm hostcalls that send and receive erwire relay packets, replacing direct device hostcalls as the driver/app boundary.
6. Prove one app can render the same UI scene to more than one renderer route.
7. Prove one Wasm driver can submit device work to a device endpoint reached through a relay route.
