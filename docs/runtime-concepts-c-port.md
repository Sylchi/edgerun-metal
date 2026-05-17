# EdgeRun Runtime Concepts In C

Purpose: define the Rust `edgerun-work` and `edgerun-vfs` concepts that survive in the C runtime.

Intention: keep the C implementation freestanding, relay-oriented, encrypted-by-default, and independent of any host operating system semantics.

## Source Concepts

The source concepts live in:

- `/home/ken/edgerun/crates/protocol/edgerun-work`
- `/home/ken/edgerun/crates/authority/edgerun-vfs`

These are concept sources only. The C runtime owns its ABI, memory model, and implementation.

## Runtime Rules

- The bare metal executor is a relay node. Its job is moving packets between addressed endpoints.
- The relay node does not interpret app data, grant authority, admit work, own trust policy, or hold recipient keys.
- The relay node may store opaque encrypted bytes and forward sealed packets. Storage is just another packet/address operation.
- Data movement happens through admitted work and relay paths.
- A boundary is crossed only through a relay controlled by an admission node.
- Plaintext is an active in-memory state only. It is never a storage or transport format.
- Anything that can persist or leave the local authority boundary is sealed first.
- The host can store data without holding keys. Stored data is content-addressed and encrypted or sealed to the intended recipient.
- Data can be sealed to any recipient identity. The transport only needs routing metadata; it does not need decryption authority.
- Disk, host filesystems, host sockets, system services, and process-local OS privileges are adapters, not runtime concepts.
- The runtime ABI uses fixed-size, endian-explicit records. No C struct is treated as portable raw bytes unless the header explicitly says so.
- Capability access is session-bound and route-bound. Sharing memory, a device, or a machine does not grant authority.
- Apps only receive capabilities that are safe for that app. Capabilities with locality authority, unsealed transport, plaintext durability, raw device access, or host privilege risk are not app capabilities.
- Apps have explicit user/admission-defined budgets before execution. CPU steps, memory bytes, packet bytes, storage bytes, and IPC counts are accounted against those budgets.
- App launch reserves exactly the memory budget before execution. That backing range is bound to the app's deterministic app-local address range.
- There are no opaque system apps. Every app is a content-addressed WASM object with identity, admission, schedule, and budget records.

## Relay Executor

The bare metal executor uses `ER_NODE_ROLE_BARE_METAL_EXECUTOR`, which is an alias for `ER_NODE_ROLE_RELAY`. It is not a compute authority, storage authority, admission authority, or app authority.

The executor handles packet movement:

- receive a packet from an address
- match it to admitted route metadata
- forward it to another address
- optionally store or retrieve opaque sealed bytes by content address
- emit relay transit records for audit/hash-chain continuity

Everything above that belongs outside the executor. Apps, admissions, manifests, capability policy, object sealing, and recipient keys are protocol state carried in packets or held by the parties that own them.

The first hardware-backed channel endpoint is UEFI UDP4. The endpoint address is encoded as IPv4 bytes plus a big-endian UDP port in `ErChannelEndpoint.address`. The default boot relay target is `10.42.0.1:9000`, matching the existing firmware UDP transmit path. This is a real hardware/firmware packet path, but still only a relay path: the executor forwards opaque `erwire` packets and does not gain authority from the NIC, firmware stack, or local machine.

ACPI is the firmware-described hardware topology surface. The executor discovers the RSDP from UEFI configuration tables, prefers XSDT when present and checksum-valid, and enumerates SDT signatures, addresses, lengths, revisions, and checksums. ACPI table bytes are addressed hardware/firmware data; interpretation belongs to later bus/device code. The current parsed tables are FADT for fixed ACPI hardware registers, MADT for APIC/interrupt topology, MCFG for PCIe ECAM configuration-space windows, and HPET for timer MMIO discovery.

## Hardware Buses

Hardware communication uses explicit bus addresses and bounded operation packets.

`ErBusAddress` describes a concrete address on a hardware bus. The first supported bus kinds are PCI config space, MMIO32, and x86 I/O ports. PCI config addresses bind bus, device, and function. MMIO32 addresses bind a physical base, byte length, and BAR index. I/O port addresses bind an aligned 32-bit port.

`ErBusOp32` describes one 32-bit operation against an address. `ErBusPacket32` wraps that operation as a request or response with a packet id and status. Operations are valid only when the offset is aligned and inside the declared range. The executor does not decide policy here; it executes valid addressed hardware packets and reports status.

This layer intentionally does not model capability routes. It is the dumb hardware executor surface: address, operation, result.

## Work Concepts

`WorkRequest` is signed intent from a user or app asking to cross an authority boundary. It commits to recipient, work type, department, payload hash, input root, budget, validity, and sequence.

`WorkAdmission` is the policy decision. It commits to the request hash, admitted route, channel, relay path, budget, policy hash, validity, and admission node.

`ChannelEnvelope` carries an admitted packet over a channel. The channel is an abstraction; in this runtime it starts as memory and firmware transports, not OS sockets.

`RelayForwardIntent` is the executor's minimal job record: forward a packet hash from one channel endpoint to another under a route hash and sequence. It does not contain plaintext or policy authority.

`RelayTransitHop` records what a relay forwarded. Relays build a hash chain over packet hash, route hash, channel id, sequence, and previous transit hash.

`CapabilityEnvelope` is the generic operation surface for storage, render, input, object, stream, and future device capabilities. It is always session-bound and carries explicit risk flags. A zero-risk app capability may route sealed data, access admitted in-memory state, or invoke narrow rendering/input/object operations. It must not imply host privilege, raw device authority, plaintext durable storage, unsealed transport, or trust from locality.

## App Concepts

Apps are WASM blobs loaded from content-addressed object storage. The runtime identity for an executing app is derived from the app object id, manifest hash, admission id, and an instance nonce. This keeps identity tied to admitted execution rather than a host process, path, user account, or filesystem location.

Secure IPC routes bind source app node id, target node id, capability id, route hash, admission id, sequence base, and capability risk flags. Payloads for those routes must be sealed to the recipient capability or app identity before they cross a relay boundary. App IPC route binding rejects nonzero capability risk flags.

`AppBudget` is the pre-execution resource contract. It is set by the user/admission path and commits to CPU step, memory byte, packet byte, storage byte, IPC send, and IPC receive limits. Zero CPU or memory budgets are invalid because they cannot produce a meaningful deterministic execution slot.

`AppUsage` is the accounting record. Charges are explicit and fail closed when they would overflow or exceed the budget. Failed charges do not mutate usage.

`AppScheduleSlot` is the deterministic scheduling input. It binds app node id, admission id, budget id, deterministic tick, sequence, CPU step quanta, and memory byte limit. Scheduling is therefore a replayable protocol decision, not a hidden host behavior.

`AppLaunchAllocation` is the launch-time memory binding. The executor receives a concrete backing memory range, but the app receives an app-local address range starting at `ER_APP_ADDRESS_BASE`. The backing length must exactly match the admitted memory budget; extra memory is not implicitly available and short backing ranges fail. The app address is therefore a deterministic capability of the launch record, not a pointer inherited from the host.

## VFS Concepts

The VFS is an in-memory object graph, not a filesystem API.

Objects are content-addressed byte ranges. File paths are labels inside a sealed manifest, not host paths. Object packets split bytes into bounded chunks with object id, offset, count, payload hash, and packet id.

Sealing transforms plaintext objects into transport objects. The transform record binds:

- plaintext object id and length
- transport object id and length
- compression kind
- seal kind
- transform hash

The runtime can hold plaintext buffers while work is active, but only sealed transport objects can cross relays or become durable.

## First C Milestone

The first C milestone is:

- fixed ABI records for work, channel, capability, relay transit, VFS object packet, file ref, and transform ref
- app identity and IPC route records for content-addressed WASM execution
- `erwire` packet carriage for those records
- memory-only object packet assembly
- explicit crypto provider hooks for seal/open/hash/sign/verify

No host listener, host capture path, host filesystem persistence, or host networking model belongs in the runtime core.
