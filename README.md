# edgerun-c

This repository contains one EdgeRun OS and runtime implementation in C. The
top-level directories are cooperating runtime areas, not separate products:

- `edgerun-metal`: the freestanding x86_64 UEFI OS runtime that boots as `BOOTX64.EFI`, hosts Wasm apps, and owns runtime device paths.
- `edgerun-crypto`: freestanding cryptographic primitives used by the runtime, tools, and tests, currently centered on BLAKE3 hashing.
- `varfont`: the freestanding variable-font renderer used by the UI runtime for text shaping, rasterization, atlas output, and test coverage.
- `edgerun-ui-core`: the platform-neutral UI scene, component, input, and rendering contract consumed by the metal runtime.

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
5. Keep IP/UDP/TLS as compatibility bridges only, not as protocol foundations.

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

This makes hardware resources identity-routed and auditable without giving the
TPM, firmware vendor, or network operator authority over the user's device. They
only help prove what code booted and what resources that code measured. Local
admission still decides what is offered, what it costs, who can use it, and how
much capacity can be turned into spendable claims.

Each packet, object, compute slice, storage interval, relay hop, or scheduling
slot can therefore carry a cost before it is admitted. Local programs may spend
tokens created by the same user up to the limits the device owner assigned.
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

Global compatibility comes from the shared `edgerun-work` contract. Abuse is
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
├── agents.md              repository engineering rules
├── docs/                  repository structure and engineering intent
├── tools/                 repository maintenance tools
├── tests/                 repository maintenance tests
├── edgerun-metal/         freestanding UEFI OS runtime and device adapters
├── edgerun-crypto/        freestanding crypto used by the runtime
├── edgerun-ui-core/       portable UI scene/component/input runtime
├── varfont/               variable-font renderer used by UI text paths
└── .build/                local generated builds, ignored
```

Generated build output must stay out of source directories. Use `.build/` for local CMake builds and `edgerun-metal/build/` for EFI artifacts produced by the metal Makefile.

This is one Git repository. Do not add nested `.git` directories, `.gitmodules`, or submodule gitlinks.

`README.md` is the only first-party README. Runtime-area details that affect
commands, behavior, status, or workflow belong here so the repository does not
grow conflicting area READMEs. Deeper architecture and design intent belong in
`docs/`.

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

`varfont` provides the freestanding variable-font parser, shaper, rasterizer,
atlas, and UI vertex generation path used by UI text. Production font creation
uses `vr_font_face_create_from_memory`; hosted file loading belongs in tests or
tools before calling the library. CMap support is currently formats 4 and 12;
complex shaping such as GSUB, GPOS, Bidi, and CFF2 is not yet implemented.

`edgerun-crypto` provides freestanding BLAKE3 hashing for the runtime. It does
not depend on the EFI runtime, `ErCryptoProvider`, or libc memory routines.

The netboot helper is a host tool that provides DHCP/TFTP for EFI PXE boot. It
listens on UDP 67 and UDP 69, serves `BOOTX64.EFI`, can prepare an interface
with `--setup-iface`, and logs relevant PXE vendor options.

## Required Tools

Use the current system toolchain:

```bash
clang --version
cc --version
ccache --version
mold --version
wat2wasm --version
cmake --version
ninja --version
ctest --version
```

The preferred local build tools are:

- `clang` and `lld` for `edgerun-metal`
- `ccache` when available for repeated C builds
- `mold` when available for hosted Linux test/tool executables
- `wat2wasm` for source-first metal Wasm module fixtures
- `CMake` with `Ninja` for `edgerun-crypto`, `varfont`, and `edgerun-ui-core`
- `ctest --output-on-failure` for tests
- `rg` for repository search

The root Makefile auto-detects `ccache` and `mold`. Override with `CCACHE=`,
`MOLD=`, `HOST_CC=`, or `CC=` when a specific environment needs different tools.
UEFI/EFI links stay on LLVM `lld`; `mold` is only used for hosted binaries.

## Common Commands

Build the default freestanding metal image:

```bash
make
```

Hosted CMake builds are for development, testing, and benchmarking only. Runtime
code stays freestanding and is pulled into the OS image directly.

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
cmake -S edgerun-crypto -B .build/edgerun-crypto -G Ninja
cmake --build .build/edgerun-crypto
ctest --test-dir .build/edgerun-crypto --output-on-failure
```

The root Makefile wraps the same flow:

```bash
make crypto-test
```

Run hosted BLAKE3 comparison benchmarks:

```bash
make crypto-bench-sota
```

The benchmark target is hosted-only. It fetches official upstream BLAKE3 into
`.build/blake3-upstream`, prints the upstream commit, and runs matching
freestanding and upstream benchmark paths.

Build and test `varfont`:

```bash
cmake --preset dev -S varfont
cmake --build .build/varfont
ctest --test-dir .build/varfont --output-on-failure
```

The root Makefile wraps the same flow:

```bash
make varfont-test
```

Build and test `edgerun-ui-core`:

```bash
cmake -S edgerun-ui-core -B .build/edgerun-ui-core -G Ninja
cmake --build .build/edgerun-ui-core
ctest --test-dir .build/edgerun-ui-core --output-on-failure
```

The root Makefile wraps the same flow:

```bash
make ui-core-test
```

Run the hosted `varfont` demo when SDL2 and the Geist font are available:

```bash
./.build/varfont/vrfont_demo varfont/fonts/Geist[wght].ttf
```

Download the Geist variable font for hosted demos:

```bash
mkdir -p varfont/fonts
curl -L -o varfont/fonts/Geist[wght].ttf https://raw.githubusercontent.com/vercel/geist-font/main/fonts/Geist/variable/Geist%5Bwght%5D.ttf
```

Build the host-side PXE helper:

```bash
make -C edgerun-metal netboot
```

Prepare an interface manually when needed:

```bash
sudo ip link set <iface> down
sudo ip addr flush dev <iface>
sudo ip addr add 10.42.0.1/24 dev <iface>
sudo ip link set <iface> up
```

Run the helper from `edgerun-metal/`:

```bash
sudo ./build/edgerun-netboot --iface <iface> --efi build/esp/EFI/BOOT/BOOTX64.EFI
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

`agents.md` is authoritative for engineering behavior. In short:

- warnings are errors
- unsupported states fail immediately
- generated artifacts are not source
- no hidden fallback paths
- preserve public behavior unless the task explicitly changes it

Keep new docs and commands aligned with those rules.

Additional intent documents:

- [Repository structure](docs/repository-structure.md)
- [Engineering practices](docs/engineering-practices.md)
- [Relay architecture](docs/relay-architecture.md)
- [Coherent system milestones](docs/coherent-system-milestones.md)
