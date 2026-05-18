# EdgeRun Relay Architecture

Purpose: define how the C runtime maps onto the `edgerun-work` relay model that apps, UI renderers, Wasm drivers, and hardware adapters use.

Intention: keep EdgeRun as one identity-routed system where local machine boundaries are implementation details, not protocol authority.

## Core Rule

Everything that crosses an execution, display, storage, device, or machine boundary crosses as admitted `edgerun-work` protocol traffic carried by erwire.

There are no separate app IPC, remote UI, driver RPC, storage RPC, or device-control protocols. Those are `NetworkMessage` and `CapabilityEnvelope` payloads authorized by signed `WorkRequest` and `WorkAdmission` records, sealed or hashed to the recipient identity, and moved by relay nodes.

The transport medium is not protocol authority. Native Ethernet, VirtIO queues, memory channels, TCP, WebSocket, browser workers, and future transports only move the same admitted bytes. Validity comes from identities, signatures, hashes, admission-defined routes, ordered-channel rules, typed payload verification, proofs, receipts, and settlement checks.

Files are not a runtime primitive. The only file-like surface is VFS labeling, and a VFS label is only a manifest name for a content-addressed object. Durable identity is the object hash, transport object hash, transform hash, route hash, and recipient identity. Host paths, process handles, sockets, file descriptors, and kernel objects do not cross the runtime boundary.

## System Contract

`edgerun-work` is the intent and admission contract for a system of systems. It lets hardware adapters, network relays, storage nodes, UI renderers, apps, schedulers, human relationship policy, and settlement logic cooperate without giving any one layer enough authority to control the rest.

The contract has three parts:

- Intent: signed requests and capability envelopes say what a user, app, device, or service is asking to do.
- Jurisdiction: a signed admission says which local authority accepted that intent for its own resources, route scope, budget, and policy window.
- Evidence: ordered messages, transit hashes, delivery proofs, receipts, and typed payload checks prove what happened without trusting the mover.

No admission is global authority. A storage admission can authorize storage work for its storage domain, but it cannot grant UI focus, decrypt user data, spend another budget, select an unrelated relay path, or command hardware outside that jurisdiction. A device admission can authorize local queue, register, DMA, and interrupt work, but it cannot force a driver or app to accept a relayed payload. A driver admission governs the driver's own logic, state, budgets, and accepted device-operation protocol. An app admission governs the app's execution slot, capabilities, state, and accepted input/work protocol. A scheduler admission can allocate time and memory for a local execution slot, but it cannot turn packet movement into user intent. A human relationship or organization policy admission can authorize access within that social scope, but it does not become a device driver or storage root.

Global compatibility comes from every jurisdiction using the same record shapes, identity rules, hashes, ordered channels, and proof surfaces. Local authority remains local; interoperability comes from the shared verification contract.

## Roles

An EdgeRun node is an addressable capability endpoint with an Ed25519 identity. A node may be a whole machine, but it may also be one local or remote capability. Roles are declarations under that same node identity, and each packet is handled through one explicit role at a time:

- App logic node: executes content-addressed Wasm app code.
- UI renderer node: converts admitted UI scene packets into pixels on a local display backend.
- Input node: sends admitted input events back to an app or shell route.
- Driver node: runs Wasm driver logic and emits device operations as relay work.
- Device endpoint node: owns a local hardware transport such as VirtIO, PCI/MMIO, USB, or GPU queues.
- Storage node: stores and retrieves sealed content-addressed objects.
- Relay node: moves packets between channel endpoints and records transit.

Locality does not grant authority. A driver running on one machine can drive a device attached to another machine only through an admitted route to that device capability. An app running on one machine can render on another machine only through an admitted route to that UI renderer capability.

Relay acceptance is not recipient acceptance. A device, NIC, storage endpoint, or
relay can move bytes toward another jurisdiction, but the receiving app, driver,
renderer, or storage authority validates its own admission, capability, budget,
sequence, payload shape, and hash checks before accepting the work. Relaying
junk is a transport event; accepting it is a recipient-jurisdiction decision.

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
- `NetworkMessage`: binds sender, recipient, first relay, department, work type, sequence, payload hash, and signature.
- `ChannelEnvelope`: carries ordered work packets.
- `CapabilityEnvelope`: invokes a session-bound capability such as render, input, object, or device operation.
- `RelayTransitHop`: records that a relay moved a packet.
- VFS object packets: move sealed content-addressed bytes.
- App identity and route-binding packets: bind content-addressed Wasm execution to admitted routes.

The current `ERWIRE_KIND_*` values are carriage classes, not routing authority. New work must prefer decoding the admitted work payload and verifying it against its `WorkAdmission` before choosing a local endpoint adapter.

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

Drivers are Wasm modules with their own jurisdiction, not trusted local kernel
code. A driver packet has the same cross-jurisdiction verification model as an
app packet:

```text
Wasm driver
  -> device operation payload
  -> CapabilityEnvelope(content=control or opaque, risk=raw-device when required)
  -> erwire
  -> relay path
  -> device endpoint
  -> local bus or queue adapter
```

The device endpoint is the only component that touches local hardware registers, DMA rings, or VirtIO queues. It is an adapter from admitted relay packets to a concrete local transport. Its authority ends at the device jurisdiction: it may deliver device bytes or operation results to a driver, but the driver jurisdiction can reject anything that does not match its own protocol state, sequence, budget, or capability expectations.

This means a VirtIO-net device can act as a native relay ingress while other VirtIO devices are local adapters for admitted capability endpoints:

```text
VirtIO net ingress
  -> erwire parse
  -> work packet decode
  -> admission-defined route verification
  -> local endpoint adapter selected from the admitted channel/route
  -> VirtIO block or VirtIO GPU queue only if that endpoint owns the capability
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

VFS labels exist for human and manifest organization:

```text
label
  -> object id
  -> object packets
  -> optional transform ref
  -> sealed transport object
```

The label never becomes authority. A node may use a host filesystem as an adapter later, but the adapter stores and retrieves content-addressed object packets. It must not expose host paths as application authority or relay route identity.

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
- `er_native_eth`: native EdgeRun Ethernet transport.
- `er_virtio` and device-specific VirtIO modules: queue and device adapters.
- `wasm_vm`: bounded Wasm execution and hostcall dispatch.
- `edgerun-ui-core`: backend-neutral UI scene records.
- renderer backends: adapt admitted UI scene packets to pixels.

New work should extend one of those surfaces instead of adding a second route, IPC, renderer, or driver protocol.

## Near-Term Proof

The proof that this architecture is real is not a full OS. It is a user-authored app with a beautiful UI moving through the same relay chain that storage, input, and device work will use:

```text
user-authored Wasm app
  -> admitted render capability packet
  -> erwire packet
  -> VirtIO net receives EdgeRun EtherType frame
  -> native erwire parser accepts packet
  -> work payload is decoded as admitted protocol traffic
  -> admission-defined route is verified
  -> render endpoint captures or draws the scene
  -> transit/result packet is emitted back over erwire
```

The first concrete milestones are:

1. Add OS-loop polling around the existing native ingress helper.
2. Decode accepted packets into `edgerun-work` records and reject packets that are not admitted work traffic.
3. Convert verified admission-defined routes into `ErRelayForwardIntent`.
4. Add an assigned render capability endpoint adapter that can capture scene hashes before drawing.
5. Package and run user-authored Wasm UI apps through relay send/receive, using the existing concurrent runtime-context shape instead of a singleton UI app.
6. Add assigned storage capability endpoint adapters for object payloads so app code, manifests, UI assets, and saved authoring state can be loaded from objects.
7. Prove one app can render the same UI scene to more than one renderer route.
8. Prove one Wasm driver can submit device work to a device endpoint reached through a relay route.

## Coherence Checklist

A new runtime feature fits this architecture only when all answers are explicit:

- What erwire packet kind carries it?
- Which work, channel, capability, object, or transit record is the payload?
- Which identity is the recipient?
- Which signed `WorkRequest` and `WorkAdmission` authorize it?
- Which relay endpoint moves it on the current hop?
- Which component owns local adapter behavior?
- What proof shows the same payload can move locally or remotely without changing protocol?

If a feature needs a host path, host socket, local process id, raw framebuffer pointer, direct driver call, or out-of-band IPC channel in its durable ABI, it is outside the architecture and must be reshaped as relay work first.
