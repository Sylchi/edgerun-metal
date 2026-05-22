# edgerun-c

This repository contains one EdgeRun OS and runtime implementation in C. The
top-level directories are cooperating runtime areas, not separate products:

- `edgerun-metal`: the freestanding UEFI OS runtime that boots as
  `BOOTX64.EFI` on x86_64 and `BOOTAA64.EFI` on AArch64, hosts Wasm apps, and
  owns runtime device paths.
- `edgerun-clock`: freestanding deterministic epoch clock shared by identity, object, admission, storage, and wire records.
- `edgerun-crypto`: freestanding cryptographic primitives used by the runtime, tools, and tests, currently centered on BLAKE3 hashing.
- `edgerun-identity`: freestanding routable identity primitives for users, devices, apps, resources, objects, ephemeral actors, and delegated actors.
- `edgerun-node`: the app SDK facade that binds a manifest-declared memory/storage slice at launch and exposes deterministic object, store, load, request, signature, and recursive subapp delegation calls inside that slice.
- `edgerun-object`: canonical object node definitions and validation APIs shared by memory, wire, durable storage, and apps.
- `edgerun-storage`: freestanding append-only content-addressed store and key projection basis.
- `edgerun-ui-core`: the platform-neutral UI scene, component, input, and rendering contract consumed by the metal runtime.
  Its `varfont` subtree owns the freestanding variable-font renderer used by UI text paths.

## Why This Work Exists

EdgeRun is a philosophy of user control over identity and resources before it
is a technology stack. The pieces already exist: public-key identity, measured
boot, signed firmware, local capability systems, encrypted payloads, verifiable
receipts, and resource accounting. The missing step is using those pieces for
the user's advantage instead of using them mainly to protect platform owners,
cloud operators, carriers, vendors, and intermediaries from the user.

EdgeRun is built around sealed, identity-routed work instead of trusted network
sessions. A node's durable protocol identity is its public key. Transport
addresses, including Ethernet MAC addresses, are local delivery locators, not
authority. The packet or work object carries the authority: recipient-bound
encryption, signatures, hashes, admission-defined routes, ordered-channel state,
delivery proofs, and receipts.

That changes what the native runtime needs from hardware. It does not need a
full IP stack, DNS, TLS termination, VPN overlays, service-mesh sidecars, or API
gateway identity assumptions before useful protocol traffic can move. It needs
drivers that can move opaque EdgeRun frames through local devices, starting with
VirtIO networking and direct Ethernet delivery. If a wrong MAC address receives
sealed content, it still cannot decrypt it, authorize it, forge recipient
proofs, or make it payable.

The goal of the metal work is to make user-authored Wasm apps feel native:
beautiful, budgeted UI surfaces; explicit admissions; and relay-routed storage,
rendering, input, and device work. The current boot UI proof can keep multiple
Wasm UI apps resident in isolated preallocated runtime contexts and switch the
active app context from shell selection. App package records now bind app code,
manifests, and UI assets by content object identity instead of labels.
Bounded VFS object packet reassembly now validates loaded object bytes before
they can become runtime input, and app package loading checks those bytes
against package manifests in caller-owned memory. The boot UI app path now uses
the storage-bound package loader before preparing each resident Wasm runtime.
Saved app package sources now bind package launch provenance to admitted
storage-retrieve route ids, and storage-bound package loading rejects retrieved
endpoint responses that do not match those route ids or expected object
identities before bytes can launch. Wasm fixtures can emit render capability
invocation packets through `edgerun.relay/send` under the same outbox, admission,
token, and packet-byte budget checks used for app relay traffic, and render
endpoint capture now accepts those packets only after admission-defined route,
channel envelope, source/target, sequence, and scene hash verification. The
render endpoint can now verify the scene payload hash and decode the payload into
endpoint-owned scene state for a VirtIO GPU renderer endpoint.
Replacing firmware boot-service networking with runtime-owned drivers is the
immediate infrastructure step:

1. Discover PCI/MMIO devices from ACPI and PCI configuration space.
2. Bring up VirtIO queues in freestanding C.
3. Move raw Ethernet frames through the native NIC path.
4. Carry EdgeRun channel/work bytes directly over local L2 frames.
5. Keep IP/UDP as optional transport carriers, not as protocol foundations; TLS uses the TPM-backed path.

This is valuable because it removes duplicated infrastructure from the critical
path. Existing systems often secure pipes: IP endpoints, TLS sessions, proxies,
gateways, meshes, and private-network perimeters. EdgeRun secures the work
itself, so memory, Ethernet, USB, Bluetooth, WebSocket, TCP, files, or future
transports can all move the same verifiable bytes.

## Global Resource Sharing

> "I think compute is going to be the currency of the future."
>
> Sam Altman, [Lex Fridman Podcast #419](https://www.youtube.com/watch?v=jvqFAi7vkBc&t=10s) ([transcript](https://lexfridman.com/sam-altman-2-transcript/))

The larger goal is user-governed global resource sharing. A user should be able
to join a computer, phone, storage device, renderer, or local network link to a
global EdgeRun network without handing authority to a carrier, cloud operator,
VPN, TLS endpoint, or trusted relay.

Each device remains inside its owner's jurisdiction. The owner can decide what
it offers, who may use it, what it costs, and what limits apply. That offer can
be free, paid, reciprocal, or policy-based. Tokens or admissions can represent
scoped rights such as:

- move up to N bytes through this relay
- store up to N sealed object bytes
- use this local Wi-Fi path for N packets
- reserve N CPU, memory, render, or scheduling units
- reach only this route, recipient, role, department, or time window

The token is not control over the device. It is a bounded claim that local
policy may accept, reject, rate-limit, revoke, price, or settle. The device
still governs its own queues, storage, radio, battery, CPU, memory, display,
and user relationships.

The practical path is that every admission authority can issue tokens only up
to the resources it actually governs and can prove. A laptop admission can mint
bounded claims against its measured CPU, disk, Wi-Fi relay, battery budget,
local apps, and local users. A phone admission can mint bounded claims against
its radio, hotspot path, storage, camera, and background scheduling windows.
Those claims are created by deterministic, identity-routed accounting programs
that bind capacity, admission policy, packet cost, work output, proof, and
receipt to the device identity. They are meaningful only where that admission
is accepted. An identity without an accepted admission token can still sign
packets, but it has no right to consume that jurisdiction's resources.

For hardware-backed devices, the proof chain can start below the operating
system. A signed EFI image gives the device owner and admission policy a known
runtime entry point. Secure Boot can refuse unsigned or unauthorized boot code.
Measured boot can extend firmware, EFI image, boot configuration, drivers, and
runtime measurements into TPM PCRs. The device can then produce TPM quotes that
bind those measurements to a device-held attestation key and to an EdgeRun
node identity.

That does not prove an infinite abstract machine; it proves a specific measured
machine state. EdgeRun admission can combine the TPM quote with deterministic
hardware discovery and runtime self-measurement: CPU topology, memory map,
storage device identity and size, NIC identity, accelerator presence, battery
state, queue limits, and booted EdgeRun runtime hash. The admission program can
then mint only the token budget allowed by that measured state and local owner
policy. If the EFI image, boot chain, hardware inventory, or accounting program
changes, the measurements change and old capacity claims stop matching the
admission policy.

The same rule applies at every layer. A storage controller, NIC, GPU, radio,
sensor, VM, app runtime, or scheduler can have its own admission authority and
its own local tokens for the resources it governs. Those subsystem tokens are
not global money; they are proofs that a measured subsystem accepted and
accounted for a bounded amount of work. The device admission can compose those
subsystem claims into device-level capacity. The user admission can then decide
which device-level claims are spendable by local programs, friends, groups, or
external users.

That makes the global question mostly a question of what booted, what measured
itself, and which owner policy admitted it. Mobile platforms already use
hardware-rooted boot chains to decide which software and keys are trusted on a
device. EdgeRun uses the same class of proof for resource accounting, but moves
the governing authority to the user and the user's admissions instead of making
the hardware vendor, app store, carrier, cloud, or network operator the only
root of control.

The useful invariant is:

```text
signed EFI + Secure Boot + TPM measured boot
  -> attested EdgeRun runtime identity
  -> deterministic subsystem inventories
  -> subsystem admissions and local tokens
  -> device admission and composed capacity
  -> user admission policy
  -> bounded spendable resource claims
  -> packet/work proofs and receipts
```

The boot boundary is deliberately split in two. While UEFI Boot Services are
available, EdgeRun may probe firmware tables, inspect PCI/MMIO topology, verify
Secure Boot state, talk to the TPM, read boot configuration from the EFI
partition, and select or create the authority profile for this boot. After
`ExitBootServices`, the runtime must use
only runtime-owned drivers and the selected handoff record; it must not rely on
firmware services for storage, networking, rendering, input, or authority
decisions.

The first boot screen is therefore a setup and handoff surface, not the final
runtime shell. It should show system information, detected devices, TPM
capability facts, Secure Boot state, and available authority profiles. If no
authority exists, setup creates one as a TPM-held persistent authority key.
Mutable configuration lives on the EFI partition: which relay channels are
available, which local interface speaks native EdgeRun frames, which interface
may run regular TCP/IP transport traffic, and which admission public key this
device will do work for, and whether any device firmware may be loaded from the
canonical EFI-partition name `/EFI/firmware/vendorid.deviceid.instance`. The
vendor and device fields are four lowercase hex digits derived from PCI IDs, and
the instance is a decimal firmware part number, for example
`/EFI/firmware/10ec.8922.0` or `/EFI/firmware/8086.2725.1`; users choose whether
that exact device target and instance are enabled, not an arbitrary path.
Firmware loading is disabled unless the selected authority profile names an
explicit device target; there is no compiled-in fallback path.
TPM storage is for keys and hardware-rooted identity material, not relay policy,
drivers, or firmware blobs. If multiple authority profiles exist, the user
selects one before the runtime starts. If Secure Boot or TPM state cannot be
verified, boot fails instead of silently continuing under an ambiguous authority.

The only vendor-binary exception is radio firmware needed to operate a radio
block. For Pi Zero W v1.1, the CYW43438 RAM/NVRAM/CLM files under
`firmware/network/02d0.a9a6.*` may be loaded to run the chip's radio engine.
That exception is not precedent for vendor drivers, host tools, protocol
stacks, closed control planes, compatibility layers, or other blobs; EdgeRun
still owns admission, routing, update framing, and packet formats above the
radio firmware boundary.

The Pi Zero W v1.1 bring-up Wi-Fi baseline is fixed open 2.4 GHz control-plane
association on SSID `EdgeNet`, channel `1`, with DHCP disabled. The AP is only
a radio wire replacement for EdgeRun EtherType `0x88b5` frames; EdgeRun still
does not use WPA enrollment, DHCP leases, IP addressing, TCP, or UDP for native
traffic. TCP/IP can remain a separate transport channel on another interface,
but it is not the foundation for native EdgeRun traffic.

Recipient sealing should be hybrid. Small one-recipient payloads can be sealed
directly to the recipient. Durable objects, large payloads, or anything with
more than one recipient should be encrypted once with a content key, then only
that content key should be wrapped to each recipient and bound to the admission,
route, payload hash, and channel metadata. That keeps relays and storage
opaque, avoids re-encrypting the same object for every route, and lets the same
sealed object move over native EdgeRun channels or TCP/IP transport channels
without changing the object's durable identity.

This makes hardware resources identity-routed and auditable without giving the
TPM, firmware vendor, or network operator authority over the user's device. They
only help prove what code booted and what resources that code measured. Local
admission still decides what is offered, what it costs, who can use it, and how
much capacity can be turned into spendable claims.

Each packet, object, compute slice, storage interval, relay hop, or scheduling
slot can therefore carry a cost before it is admitted. Local programs may spend
tokens created by the same user up to the limits the device owner assigned.

## Canonical Objects

`edgerun-clock` is the deterministic epoch coordinate below identities,
objects, admission, storage, and wire records. Every epoch stamp names the
32-byte identity id of the clock keeper that advanced it, so verifiers know
which clock authority to ask about a claim. Epoch time advances on accepted
state transitions rather than wall-clock trust, giving separate devices a
shared way to compare creation, validity, route, and receipt records.

`edgerun-identity` is the routable naming layer below objects and boundary
crossings. It turns explicit source material into fixed 32-byte identity ids for
users, devices, apps, storage, relays, resources, objects, ephemeral actors, and
delegated actors. It does not decide login state, admission, authority,
signature trust, key unsealing, or transport reachability. A delegated identity
is a new routable identity derived from parent, delegate, and scope identities;
it is not the parent's signing key and does not imply permission by itself.

`edgerun-object` is the public object boundary. It defines the canonical bytes
that can move through memory, over wire routes, and into durable storage without
changing format. An object node contains its epoch stamp, requirement fields,
owner layer identifiers, envelope descriptors, and either inline bytes or child
references. The object id is the BLAKE3 hash of those canonical bytes.
No other subsystem defines an object byte format or object-id scheme; storage,
VFS, relay, sealing, and app SDK code may only carry, validate, or reference
canonical `edgerun-object` ids.

The object layer does not know auth, user sessions, device policy, object
contents, storage tiers, or route admission. Those decisions belong to the
authorities that issue resource grants and to the components that consume the
object. Storage persists canonical bytes; network routes canonical bytes; apps
create and consume canonical bytes. The object API only builds, sizes, hashes,
and verifies the canonical object form so boundary crossings are explicit.
Friends, nearby devices, organizations, apps, or strangers crossing into another
jurisdiction must pay in a token that the destination admission accepts, under
that destination's current price and policy.

There does not need to be one global token or one global operator. Users can
accept tokens from other users, price their own resources against those tokens,
and rebalance by spending the mixed tokens they earn on other people's
resources. External settlement bridges, stablecoins, or swap services can help
when a user wants harder settlement, but they are bridges around local
admission, not the source of authority. The protocol only needs the work claim,
admission, route, proof, receipt, and settlement records to agree on what was
authorized and what was actually delivered.

This means phones can relay packets over open Wi-Fi without first reaching a
global operator network over 4G. Computers can store or relay other users'
sealed data without being able to decrypt it. Any transport can carry packets
because every packet is accounted for by signed intent, scoped admission,
ordered-channel state, payload hashes, transit evidence, delivery proofs, and
receipts.

Global interoperability comes from the shared `edgerun-work` contract. Abuse is
limited by local admission policy and by proof-based accounting: resources are
shared only inside the scope the owner admitted, and payment or credit is owed
only for verified work.

The rough global scale is large enough to matter. IEA estimates data centres
used about 415 TWh in 2024 and may reach about 945 TWh by 2030. IEA also
estimates data transmission networks used about 260-360 TWh in 2022. A simple
current addressable pool for digital infrastructure is therefore about
675-775 TWh/year before end-user devices.

Order-of-magnitude savings if protocol and infrastructure simplification remove
part of that waste:

| Digital infra reduction | Electricity saved today | Value at $0.10/kWh | CO2 avoided at 445 g/kWh |
|---:|---:|---:|---:|
| 1% | 7 TWh/year | $0.7B/year | 3.1 Mt/year |
| 5% | 35 TWh/year | $3.5B/year | 15.6 Mt/year |
| 10% | 70 TWh/year | $7.0B/year | 31.2 Mt/year |
| 20% | 140 TWh/year | $14.0B/year | 62.3 Mt/year |

At 2030 scale, using a 1,250-1,450 TWh/year digital infrastructure pool, a
5-10% reduction is roughly 62-145 TWh/year, or $6.2B-$14.5B/year at
$0.10/kWh. Higher commercial electricity prices or carbon pricing increase the
economic value. These figures are planning estimates, not protocol guarantees;
they explain the size of the prize for deleting avoidable layers.

Primary data references:

- [IEA Energy and AI report](https://www.iea.org/reports/energy-and-ai/executive-summary): data centre electricity demand, 2024 and 2030.
- [IEA Data centres and data transmission networks](https://www.iea.org/energy-system/digitalisation/data-centres-and-data-transmission-networks): network electricity demand.
- [IEA Electricity 2025 emissions](https://www.iea.org/reports/electricity-2025/emissions): 445 g CO2/kWh 2024 global power intensity.

## Repository Layout

```text
.
├── AGENTS.md              repository engineering rules
├── Makefile               root build, test, and check entrypoints
├── codex/                 hosted Codex support library and tests
├── edgerun-clock/         deterministic epoch clock shared across records
├── edgerun-crypto/        freestanding crypto used by the runtime
├── edgerun-identity/      routable identity primitives
├── edgerun-metal/         freestanding UEFI OS runtime and device adapters
├── edgerun-node/          launch-bound app SDK and recursive slice delegation
├── edgerun-object/        canonical object node format
├── edgerun-storage/       append-only content-addressed storage basis
├── edgerun-ui-core/       portable UI scene/component/input runtime
├── firmware/              admitted firmware payloads and provenance notes
├── include/               repository-wide freestanding C headers
├── tests/                 repository maintenance tests
├── third_party/           vendored source
├── tools/                 repository maintenance tools
└── .build/                local generated builds, ignored
```

Generated build output must stay out of source directories. Use `.build/` for
all local build output, including EFI artifacts produced by the metal Makefile.

This is one Git repository. Do not add nested `.git` directories, `.gitmodules`, or submodule gitlinks.

`README.md` is the only first-party documentation surface. `AGENTS.md` is the
agent policy file. Code, tests, generated boot manifests, and hardware output
are the source of truth for subsystem details.

## Runtime Area Notes

`edgerun-metal` is the bootable OS runtime. Real hardware boot is confirmed on
an MSI X570/Ryzen 5600X desktop with an RTX 5060 Ti and PXE/TFTP served from an
Arch Linux laptop at `10.42.0.1`; the client uses `10.42.0.2`. The proven path
is:

```text
firmware -> BOOTX64.EFI -> EdgeRun Metal Core -> Wasm VM -> hostcalls
```

The active OS path is:

```text
os = VirtIO GPU-backed UI runtime, Wasm apps, PS/2 input,
     storage-bound package loading, relay/device endpoints
```

Netboot is support infrastructure. Do not redesign it unless it blocks boot.
The durable runtime work is relay-routed UI, input, storage, driver, and device
traffic through `erwire`.

Networking code lives in `edgerun-metal/core/er_network.c`,
`edgerun-metal/core/er_work_route.c`, `edgerun-metal/core/erwire.c`, and the
carrier implementations. Those files and their tests define current behavior.

Hardware bring-up order:

```text
1. PCI config scan
2. BAR discovery
3. Read-only MMIO mapping
4. ACPI table discovery
5. Interrupts
6. DMA
7. Device endpoint adapters
```

These are adapter-enabling steps. They are not the app or driver ABI. Apps and
drivers talk through `erwire` relay packets; endpoint adapters translate
admitted packets into local hardware operations.

`edgerun-ui-core` owns the portable UI scene, component, input, layout, theme,
asset, and render-budget contracts consumed by the OS runtime. App and shell
surfaces should compose `er_ui_component_*_emit`, `er_ui_*_prompt_emit`, and
layout nodes such as `er_ui_node_row`, `er_ui_node_column`, `er_ui_node_grid`,
`er_ui_node_masonry`, `er_ui_node_bento_grid`, and `er_ui_node_scroll_area`.
Direct `er_ui_scene_push_*` calls are for renderer primitives, component
internals, workspace placement, and reusable component implementation.

`edgerun-ui-core/varfont` provides the freestanding variable-font parser, shaper, rasterizer,
atlas, and UI vertex generation path used by UI text. Production font creation
uses `vr_font_face_create_from_memory`; hosted file loading belongs in tests or
tools before calling the library. CMap support is currently formats 4 and 12;
complex shaping such as GSUB, GPOS, Bidi, and CFF2 is not yet implemented.

`edgerun-crypto` provides freestanding BLAKE3 hashing for the runtime. It does
not depend on the EFI runtime, `ErCryptoProvider`, or libc memory routines.

`edgerun-node` is the app-facing SDK boundary. Users select which apps can run;
each app manifest declares its required memory and storage before launch. The
runtime binds the whole requested slice to the node at launch, with no dynamic
allocation, oversubscription, or runtime quota negotiation. Runtime operations
are deterministic state transitions inside that pre-bound slice. A node can
delegate part of its own slice to child nodes, including apps from other
developers, and those children can repeat the same delegation pattern.

`edgerun-storage` provides the freestanding append-only content-addressed store. Its
record log is the source of truth; blob tables, key projections, content-type
records, index definitions, and sorted prefix scans are rebuilt from
caller-provided arena memory. Storage intentionally does not hide durable read
cost behind an internal blob cache; every blob read reaches the backing IO path
and callers must keep hot working sets in their own explicit memory if they need
that behavior. Storage also does not own durability policy: normal writes update
the configured IO bytes, and callers invoke `er_store_sync` only at explicit
capability or boot-log durability boundaries. Storage is intentionally
content-blind: it does not authenticate callers, authorize keys, parse object
bytes, validate schemas, interpret package formats, or decide whether a blob is
safe to execute or reveal. Callers own admission, signatures, encryption, access
policy, object semantics, and lifecycle policy above this byte store.

Current storage integration work makes `edgerun-storage` the single durable object
system. Device details are selected once at store initialization with a
deterministic block backing profile such as byte log, SD card, NVMe, or custom
block size. Runtime storage-medium initialization first checks the store for the
`medium/init` record; if it is missing, the caller-provided SD/NVMe benchmark
callback must run and the benchmark record becomes the first durable medium fact
projected into the store. External runtime consumers do not receive SD, NVMe, or
packet-slot APIs; they receive only the store API for blobs, content-addressed
objects, and indexes. Store-backed storage endpoint durability has replaced the
old fixed packet-slot path. Apps receive explicit storage allocations as fixed
block ranges on an initialized medium, and allocation preparation rejects byte or
medium overrun before an app can run. End-user storage capabilities must declare
persistence and latency requirements instead of relying on ambient runtime
policy. `erwire` remains the transport. VFS already owns object packetization
between memory and wire packets; durable manifest/chunk admission is still
exposed through the store object helpers and must move behind a VFS/storage
adapter so there is one explicit memory-to-wire, wire-to-memory,
memory-to-durable, and durable-to-memory boundary. Completed VFS payloads are
admitted into `er_store` before package loading, OTA install, or debug-log
retention consumes them. The next implementation steps are:

1. Add the VFS/storage adapter that owns object-to-manifest and
   manifest-to-object transitions.
2. Wire the Pi SD benchmark callback to `er_storage_medium_init_if_needed` before
   opening app storage allocation routes.
3. Add explicit boot-log append and sync calls on top of `er_store`; do not add
   ambient runtime logging or hidden store flushes.
4. Load Wasm app, manifest, UI assets, OTA objects, and Pi debug logs from
   store indexes after first-boot admission of compiled-in or received bytes.

The netboot helper is a host tool that provides DHCP/TFTP for EFI PXE boot. It
listens on UDP 67 and UDP 69, serves `BOOTX64.EFI`, can prepare an interface
with `--setup-iface`, and logs relevant PXE vendor options.

## Required Tools

Use the current system toolchain:

```bash
clang --version
llvm-strip --version
```

The preferred local build tools are:

- `clang` and `lld` for `edgerun-metal`
- `llvm-strip` for repository release-binary size inspection
- repository-owned `tools/wasm-compile` for ERC and low-level WAT metal Wasm
  module fixtures
- repository-owned `tools/er-build` for repository policy, package, crypto, storage, varfont, and UI-core tests
- `rg` for repository search

The root Makefile uses explicit LLVM defaults and does not auto-detect host
accelerators. UEFI/EFI links stay on LLVM `lld`; hosted binaries must remain
outside runtime dependencies.
The repository-owned `tools/er-build` runner is the normal build orchestration
path. The Makefile builds `.build/er-build` and delegates repository policy,
tool, crypto, storage, varfont, and UI-core test targets to it.
`toolchain/bin/` contains tracked, statically linked repository tool seeds used
to create the first `.build/er-build` without rebuilding it from a host compiler.
Compiler and linker calls that still produce new C artifacts remain explicit
until they move behind the repository-owned compiler boundary.

ERC is the current EdgeRun app language. It is EdgeRun C--: a small C-shaped
source format for admitted packages, not hosted C and not a freestanding C
profile. The compiler in `tools/wasm-compile` and contract headers in
`include/` define the accepted surface.

## Common Commands

Build the default freestanding metal image:

```bash
make
```

Runtime code stays freestanding and is pulled into the OS image directly. Normal
repository checks do not use CMake, Ninja, or CTest.

Run all local checks:

```bash
make check
```

Check only repository structure:

```bash
make repo-check
```

Run repository-policy tests:

```bash
make repo-test
```

Build the host-side erwire decoder:

```bash
make erwire-decode
```

The decoder reads raw erwire packets from standard input, prints packet kind/sequence/CRC state, and decodes current log-text and PCI-device payloads. It can also listen directly for firmware UDP packets:

```bash
.build/erwire-decode --udp 9000
```

It is host tooling only; runtime code still emits binary erwire packets without depending on host OS APIs.

Build the `edgerun-metal` OS image:

```bash
make -C edgerun-metal wasm-modules
make edgerun-os
```

Build and test `edgerun-crypto`:

```bash
make crypto-test
```

`crypto-test` is built and run directly by `.build/er-build`; it does not use
CMake, Ninja, or CTest.

Build and test `edgerun-storage`:

```bash
make storage-test
```

`storage-test` is built and run directly by `.build/er-build`; it does not use
CMake, Ninja, or CTest.

External upstream comparison fetches are not repository targets. Any benchmark
source used by a maintained target must be vendored or implemented in-tree.

Build and test `edgerun-ui-core/varfont`:

```bash
make varfont-test
```

`varfont-test` is built and run directly by `.build/er-build`; it does not use
CMake, Ninja, or CTest.

Build and test `edgerun-ui-core`:

```bash
make ui-core-test
```

`ui-core-test` is built and run directly by `.build/er-build`; it does not use
CMake, Ninja, or CTest.

Render the current `edgerun-ui-core` metal surface with no external display
library:

```bash
make ui-core-snapshot
```

The snapshot target writes `.build/edgerun-ui-core/snapshot.bmp` using the
bundled Geist variable font at `edgerun-ui-core/varfont/fonts/Geist[wght].ttf`;
maintained repository targets must not fetch external demo assets at runtime or
during validation.

Build the host-side PXE helper:

```bash
make -C edgerun-metal netboot
```

Build the metal UEFI image for a specific boot architecture:

```bash
make -C edgerun-metal ER_METAL_ARCH=x86_64
make -C edgerun-metal ER_METAL_ARCH=aarch64
make -C edgerun-metal pi-zero-2w-uefi
make -C edgerun-metal pi-zero-w-v1_1-boot
```

The x86_64 removable-media path is `.build/edgerun-metal/esp/EFI/BOOT/BOOTX64.EFI`.
The AArch64 removable-media path for Raspberry Pi 4B UEFI is
`.build/edgerun-metal/aarch64/esp/EFI/BOOT/BOOTAA64.EFI`.
The Pi Zero 2 W U-Boot EFI payload path is
`.build/edgerun-metal/pi-zero-2w/esp/EFI/BOOT/BOOTAA64.EFI`.
The Pi Zero W v1.1 ARMv6 boot tree is
`.build/edgerun-metal/pi-zero-w-v1_1/boot/` and contains the repo-owned
`kernel.img` payload.

Pi Zero W v1.1 SD boot currently requires the Raspberry Pi Zero-family GPU boot
firmware staged from `firmware/raspberry-pi/`: `bootcode.bin`, `start.elf`, and
`fixup.dat`. This is an explicit hardware bring-up exception to let the
Broadcom mask-ROM/GPU boot chain load repo-owned `kernel.img`; it is separate
from the CYW43438 radio firmware exception and does not permit general vendor
drivers, host tools, protocol stacks, or compatibility layers.

The same boot tree can be used on every Pi Zero W v1.1 board in the cluster
proof. Each board derives a boot-local ephemeral node id from the hardcoded
proof admission id and board-local boot nonce material, so no node secret is
stored on the SD card.

```bash
make pi-zero-w-v1_1-boot
```

Build only the repository-owned Raspberry Pi USB boot helper:

```bash
make pi-usb-boot
```

Stage and serve the Pi Zero W v1.1 boot tree over USB:

```bash
make pi-zero-w-v1_1-usb-boot
```

When the Broadcom boot ROM is already visible, pass the exact device node to
avoid racing USB re-enumeration:

```bash
sudo chown "$USER:$USER" /dev/bus/usb/007/005
make pi-zero-w-v1_1-usb-boot PI_USB_DEVICE=/dev/bus/usb/007/005
```

On this bring-up laptop, bus 007/008 can wedge during Raspberry Pi USB boot.
Reset the xHCI controller that owns that root hub before changing boot code
when `lsusb` shows stale state, impossible device state, or child devices fail
to re-enumerate:

```bash
sudo sh -c 'echo 0000:c3:00.4 > /sys/bus/pci/drivers/xhci_hcd/unbind; sleep 3; echo 0000:c3:00.4 > /sys/bus/pci/drivers/xhci_hcd/bind'
```

The Pi Zero W v1.1 open OTA updater is intentionally unauthenticated during
bring-up. Update payloads use `ERWIRE_KIND_VFS_OBJECT_PACKET` and carry the
existing serialized VFS object packet shape: `ErVfsObjectPacketHeader` followed
by `header.bytes_len` object bytes. The receiver validates the VFS packet with
the normal content-addressed hashes, caches packets in the board-local boot
receiver, writes the completed object to the update slot, verifies each written
SD block by reading it back, and marks reboot required.

The Pi Zero W v1.1 SD layout keeps the FAT boot partition below raw firmware
state. The single boot checkpoint block is SD block `131072`; it records the
current image id, boot count, last milestone, step count, live states, and CRC.
The boot-log ring begins at SD block `131073` for `127` blocks. The default
update slot begins at SD block `262144`. The intended live update transport is
CYW43438 vendor radio firmware plus SDIO function-2 SDPCM data carrying EdgeRun
L2 ethertype `0x88b5` erwire frames over the fixed open `EdgeNet` control AP on
channel `1`; DHCP remains disabled because native EdgeRun traffic is not IP.

Send a freshly built `kernel.img` over the Pi Zero W v1.1 EdgeNet L2 receiver
from a Linux interface associated to `EdgeNet`:

```bash
make pi-zero-w-v1_1-update PI_UPDATE_IFACE=wlan0
```

Prepare an interface manually when needed for hosted network helpers:

```bash
sudo ip link set <iface> down
sudo ip addr flush dev <iface>
sudo ip addr add 10.42.0.1/24 dev <iface>
sudo ip link set <iface> up
```

Run the helper from the repository root:

```bash
sudo ./.build/edgerun-metal/edgerun-netboot --iface <iface> --efi .build/edgerun-metal/esp/EFI/BOOT/BOOTX64.EFI
```

If NetworkManager interferes, temporarily disable management for the interface:

```bash
nmcli dev set <iface> managed no
```

Inspect PXE packets:

```bash
sudo tcpdump -i <iface> -n -vvv -s0 'udp port 67 or udp port 68 or udp port 69'
```

Clean generated local output:

```bash
make clean
```

## Rules

`AGENTS.md` is authoritative for engineering behavior. In short:

- warnings are errors
- unsupported states fail immediately
- generated artifacts are not source
- no hidden fallback paths
- preserve public behavior unless the task explicitly changes it

Keep new docs and commands aligned with those rules.
