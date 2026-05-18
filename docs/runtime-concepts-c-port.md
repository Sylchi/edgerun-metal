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
- Admissions are scoped jurisdictions, not global authority. An admission can authorize only the resources, relationships, route scope, budget, and policy window governed by its signer.
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

Human text output remains best-effort early boot logging and is line-buffered before UDP transmission so formatted fragments do not become one packet each. Structured `erwire` relay packets flush pending text first, bypass the text buffer, and use bounded polling before and after transmit so PCI snapshots and other capture records are not normally dropped just because the previous UDP4 transmit has not completed yet. The host decoder still tracks packet sequence gaps because firmware transport is not treated as reliable.

ACPI is the firmware-described hardware topology surface. The executor discovers the RSDP from UEFI configuration tables, prefers XSDT when present and checksum-valid, and enumerates SDT signatures, addresses, lengths, revisions, and checksums. ACPI table bytes are addressed hardware/firmware data; interpretation belongs to later bus/device code. The current parsed tables are FADT for fixed ACPI hardware registers, MADT for APIC/interrupt topology, MCFG for PCIe ECAM configuration-space windows, and HPET for timer MMIO discovery.

## Hardware Buses

Hardware communication uses explicit bus addresses and bounded operation packets. Drivers are WASM apps; the bare-metal executor is not where device policy or driver state lives. A driver app sends a packet that names the bus address, access width, offset, and value, and the executor validates the bounds before performing the transaction.

`ErBusAddress` describes a concrete address on a hardware bus. The first supported bus kinds are PCI config space, MMIO, and x86 I/O ports. PCI config addresses bind bus, device, and function. MMIO addresses bind a physical base, byte length, and BAR index. I/O port addresses bind a base port and byte range.

`ErBusIoOp` describes one 8-bit, 16-bit, or 32-bit operation against an address. `ErBusIoPacket` wraps that operation as a request or response with a packet id and status. Operations are valid only when the width matches the requested access, the offset is aligned for that width, and the transaction stays inside the declared range. The older `ErBusOp32` and `ErBusPacket32` remain as compatibility wrappers for existing 32-bit PCI/MMIO probing.

This byte-capable surface is the shape expected by device drivers. TPM, ACPI-described fixed hardware, controller registers, and legacy I/O devices are all represented as addressed bus bytes/words/dwords instead of host file descriptors, sockets, or OS driver handles.

This layer intentionally does not model capability routes. It is the dumb hardware executor surface: address, operation, result.

## WASM Driver Runtime

Drivers and user-authored apps are WASM modules executed by the metal interpreter. The interpreter owns no device policy; it gives the module bounded linear memory and explicit imports. The bring-up driver import is `edgerun.bus.exec(req_ptr, resp_ptr)`, where both pointers refer to `ErBusIoPacket` records inside the module's linear memory. The executor validates the pointed-to memory ranges, executes the addressed transaction, writes the response packet, and returns a numeric success status.

This lets a NIC driver build descriptor/register transactions as data, pass them to the dumb bus executor, and keep driver state in admitted WASM memory. Device-specific logic remains app code; the executor remains a packet and bus transaction runner.

The durable app boundary is relay send/receive, not direct device access. `edgerun.relay/send(ptr, len)` is valid only for bytes inside the module's declared outbox window and only when the serialized relay packet matches the app identity, admission id, budget token, and packet-byte budget. `edgerun.relay/recv(ptr, capacity)` is valid only for the declared inbox window. This is the path user-authored apps should use for UI render packets, input events, storage/object work, and later driver/device operations.

## Work Concepts

`WorkRequest` is signed intent from a user or app asking to cross an authority boundary. It commits to recipient, work type, department, payload hash, input root, budget, validity, and sequence.

`WorkAdmission` is the policy decision. It commits to the request hash, admitted route, channel, relay path, budget, policy hash, validity, and admission node.

The admission node's authority is jurisdictional. A storage admission governs storage work for its storage domain. A render admission governs render access for a renderer or shell scope. A scheduler admission governs local time and memory slots. A human relationship, group, or organization admission governs access inside that social scope. None of these admissions can authorize a different layer by implication; cross-jurisdiction work must carry the relevant signed intent and admission for the destination authority.

`ChannelEnvelope` carries an admitted packet over a channel. The channel is an abstraction; in this runtime it starts as memory and firmware transports, not OS sockets.

`RelayForwardIntent` is the executor's minimal job record: forward a packet hash from one channel endpoint to another under a route hash and sequence. It does not contain plaintext or policy authority.

`RelayTransitHop` records what a relay forwarded. Relays build a hash chain over packet hash, route hash, channel id, sequence, and previous transit hash.

`CapabilityEnvelope` is the generic operation surface for storage, render, input, object, stream, and future device capabilities. It is always session-bound and carries explicit risk flags. A zero-risk app capability may route sealed data, access admitted in-memory state, or invoke narrow rendering/input/object operations. It must not imply host privilege, raw device authority, plaintext durable storage, unsealed transport, or trust from locality.

## App Concepts

Apps are WASM blobs loaded from content-addressed object storage. `ErAppPackageManifest` binds app code, app manifest, and optional UI asset objects by object id and length; package identity ignores VFS labels. The runtime identity for an executing app is derived from the app object id, manifest object id, admission id, and an instance nonce. This keeps identity tied to admitted execution rather than a host process, path, user account, or filesystem location.

Secure IPC routes bind source app node id, target node id, capability id, route hash, admission id, sequence base, and capability risk flags. Payloads for those routes must be sealed to the recipient capability or app identity before they cross a relay boundary. App IPC route binding rejects nonzero capability risk flags.

`AppBudget` is the pre-execution resource contract. It is set by the user/admission path and commits to CPU step, memory byte, packet byte, storage byte, IPC send, and IPC receive limits. Zero CPU or memory budgets are invalid because they cannot produce a meaningful deterministic execution slot.

`AppUsage` is the accounting record. Charges are explicit and fail closed when they would overflow or exceed the budget. Failed charges do not mutate usage.

`AppScheduleSlot` is the deterministic scheduling input. It binds app node id, admission id, budget id, deterministic tick, sequence, CPU step quanta, and memory byte limit. Scheduling is therefore a replayable protocol decision, not a hidden host behavior.

`AppLaunchAllocation` is the launch-time memory binding. The executor receives a concrete backing memory range, but the app receives an app-local address range starting at `ER_APP_ADDRESS_BASE`. The backing length must exactly match the admitted memory budget; extra memory is not implicitly available and short backing ranges fail. The app address is therefore a deterministic capability of the launch record, not a pointer inherited from the host.

## Render Concepts

Rendering is a budgeted runtime capability, not an unbounded local privilege. User-authored apps submit UI state that resolves through `edgerun-ui-core` components into bounded scene/display-list data. The metal renderer draws that admitted scene to a dumb framebuffer or endpoint-owned VirtIO GPU surface.

Apps cannot draw arbitrary pixels or create arbitrary overlapping windows. They submit predetermined component state, and the shell places that state into admitted layout regions. Transitions are selected from predetermined transition kinds. Overlays are reserved for system prompts, OSD, secure confirmation, and other trusted shell surfaces.

The 4K120 CPU rendering target is a first-class architecture constraint. A 3840x2160 RGBA frame is about 33.2 MiB, and full-screen writes at 120 Hz are about 3.98 GiB/s. That is feasible for simple linear writes on desktop memory, but normal UI must rely on retained scenes, dirty tiles, cached glyphs, and bounded alpha blending. The renderer must account bytes written, dirty tiles, primitive count, glyph count, and app render budgets before accepting work.

See `docs/metal-renderer-4k120.md` for the display architecture.

## VFS Concepts

The VFS is an in-memory object graph, not a filesystem API.

Objects are content-addressed byte ranges. File paths are labels inside a sealed manifest, not host paths. Object packets split bytes into bounded chunks with object id, offset, count, payload hash, and packet id. Loading an object means reassembling the canonical packet sequence into caller-owned memory after validating packet order, offsets, payload hashes, packet ids, object id, and capacity.

Sealing transforms plaintext objects into transport objects. The transform record binds:

- plaintext object id and length
- transport object id and length
- compression kind
- seal kind
- transform hash

The runtime can hold plaintext buffers while work is active, but only sealed transport objects can cross relays or become durable.

## First C Milestone

The completed C foundation is:

- fixed ABI records for work, channel, capability, relay transit, VFS object packet, object label ref, and transform ref
- app package, identity, and IPC route records for content-addressed WASM execution
- `erwire` packet carriage for those records
- memory-only object packet assembly
- bounded object packet reassembly for loaded app/package bytes
- app package ids derived from object ids and lengths rather than labels
- explicit crypto provider hooks for seal/open/hash/sign/verify
- bounded Wasm relay send/receive imports with app identity, admission, token, memory-window, and packet-byte budget checks
- backend-neutral UI scene records, component surfaces, variable-font text quads, and GOP/VirtIO GPU rendering foundations
- concurrent boot-local Wasm UI app contexts with isolated preallocated memory, presentation identity, scene state, and per-runtime `ui_emit` dispatch

The next C milestone is to package user-authored Wasm UI apps as content-addressed input, save and load those app objects through admitted storage work, send admitted scene packets through relay send, verify the route at native ingress, and hand the scene to an endpoint-owned renderer. No host listener, host capture path, host filesystem persistence, or host networking model belongs in the runtime core.
